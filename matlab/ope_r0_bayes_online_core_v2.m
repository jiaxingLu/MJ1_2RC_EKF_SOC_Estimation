function [alphaMean,alphaSD,updatePulse,gateOpen,shadowSOC,windowCount,updateCount] = ...
    ope_r0_bayes_online_core_v2(tNow,I_meas,V_meas,fastBandEnable,period_s,reset)
%OPE_R0_BAYES_ONLINE_CORE Sample-by-sample gated Bayesian R0 updater core.
%#codegen
%
% This function implements the OPE-A1-4 windowed Bayesian R0 logic in a
% causal streaming form. It is intentionally independent of the EKF.
%
% INPUTS
%   tNow            current absolute experiment time [s]
%   I_meas          current sample [A]
%   V_meas          voltage sample [V]
%   fastBandEnable  external excitation-band gate (0/1)
%   period_s        current excitation period estimate/command [s]
%   reset           reset persistent updater state (0/1)
%
% OUTPUTS
%   alphaMean       current posterior mean of alpha_R0
%   alphaSD         current posterior standard deviation
%   updatePulse     1 only on a sample where the PREVIOUS window updates
%                   the posterior; the new alpha is available on this sample
%   gateOpen        1 when that completed window passed all update gates
%   shadowSOC       SOC of the updater's independent frozen 2RC shadow model
%   windowCount     number of windows started
%   updateCount     number of Bayesian updates applied
%
% CAUSALITY
% A completed window is finalized only when the NEXT sample arrives beyond
% the previous window end. Therefore data from a window cannot change alpha
% inside that same window.
%
% PARAMETERIZATION
%   R0*(SOC) = alpha_R0 * R0_base(SOC)
%
% FROZEN BAYESIAN CONFIG
%   alpha grid      : 0.70:0.0005:1.30
%   prior           : N(1,0.15^2), truncated by grid
%   SOC start band  : 0.20...0.80 (lower bound is start-only)
%   min XRMS        : 5 mV
%   min cycles      : 10
%   min samples     : 50
%   window duration : 20 excitation cycles
%   sigma floor     : 2 mV
%
% NOTE
% fastBandEnable / period_s are treated as outputs of the excitation-gate
% layer. This core does not yet estimate frequency autonomously.

S = coder.load('mj1_v02_model.mat','model');
model = S.model;

MAX_BUF = 256;
N_ALPHA = 1201;

persistent initialized
persistent xShadow IPrev tPrev havePrev
persistent logPost alphaState alphaSDState
persistent tBuf yBuf xBuf nBuf
persistent collecting windowStart windowGate
persistent winCount updCount

if isempty(initialized) || reset > 0.5
    initialized = true;

    xShadow = zeros(3,1);
    IPrev = 0.0;
    tPrev = tNow;
    havePrev = false;

    logPost = zeros(N_ALPHA,1);
    for j = 1:N_ALPHA
        a = 0.70 + (j-1)*0.0005;
        logPost(j) = -0.5*((a-1.0)/0.15)^2;
    end

    [alphaState,alphaSDState] = posterior_moments(logPost);

    tBuf = zeros(MAX_BUF,1);
    yBuf = zeros(MAX_BUF,1);
    xBuf = zeros(MAX_BUF,1);
    nBuf = int32(0);

    collecting = false;
    windowStart = tNow;
    windowGate = true;

    winCount = int32(0);
    updCount = int32(0);
end

updatePulse = 0.0;
gateOpen = 0.0;

% -------------------------------------------------------------------------
% Propagate independent frozen shadow model from previous sample -> current.
% This matches frozen_predictors(): sample k voltage uses x(k), while x(k+1)
% is propagated using I(k) and dt(k).
% -------------------------------------------------------------------------
if havePrev
    dt = tNow - tPrev;
    if dt > 0
        xShadow = stateFcn(xShadow,IPrev,dt,model);
    end
end

p = getParams(model,xShadow(3));
baseNoR0 = p.OCV + xShadow(1) + xShadow(2);
xR0now = p.R0 * I_meas;
yNow = V_meas - baseNoR0;

% Window START eligibility.
% IMPORTANT:
% The lower SOC bound is a START gate only. Once a window has started,
% fast AC ripple is allowed to move the shadow SOC slightly below 20%
% without terminating that window. This exactly matches OPE-A1-4.
startEligible = ...
    xShadow(3) >= 0.20 && ...
    xShadow(3) < 0.80 && ...
    V_meas < 4.2;

windowDuration = 20.0 * period_s;

% -------------------------------------------------------------------------
% Finalize the PREVIOUS window before the current sample is admitted when:
%   1) its intended duration has elapsed, OR
%   2) the upper SOC limit / 4.2-V terminal condition has been reached.
%
% Deliberately DO NOT close a running window for a transient dip below 20%.
% -------------------------------------------------------------------------
endRegionReached = xShadow(3) >= 0.80 || V_meas >= 4.2;

if collecting && ( ...
        (isfinite(windowDuration) && windowDuration > 0 && ...
         tNow > windowStart + windowDuration) || ...
        endRegionReached )

    [logPost,alphaState,alphaSDState,applied,passed] = ...
        finalize_window(tBuf,yBuf,xBuf,nBuf,windowGate,period_s,logPost);

    if passed
        gateOpen = 1.0;
    end
    if applied
        updatePulse = 1.0;
        updCount = updCount + 1;
    end

    collecting = false;
    nBuf = int32(0);
    windowGate = true;
end

% Output posterior AFTER any previous-window update, before current sample
% contributes to a new/current window.
alphaMean = alphaState;
alphaSD = alphaSDState;

% -------------------------------------------------------------------------
% Start / fill current window.
% -------------------------------------------------------------------------
if startEligible && ~collecting
    collecting = true;
    windowStart = tNow;
    nBuf = int32(0);
    windowGate = true;
    winCount = winCount + 1;
end

if collecting && ~endRegionReached
    if nBuf < MAX_BUF
        nBuf = nBuf + 1;
        idx = double(nBuf);
        tBuf(idx) = tNow;
        yBuf(idx) = yNow;
        xBuf(idx) = xR0now;
        windowGate = windowGate && (fastBandEnable > 0.5);
    end
end

% Store previous measurement timing/current for next shadow transition.
IPrev = I_meas;
tPrev = tNow;
havePrev = true;

shadowSOC = xShadow(3);
windowCount = double(winCount);
updateCount = double(updCount);

end

% =========================================================================
% Finalize one completed/noncompleted window
% =========================================================================
function [logPost,alphaMean,alphaSD,applied,gatePassed] = ...
    finalize_window(tBuf,yBuf,xBuf,nBuf,windowGate,period_s,logPost)

MIN_SAMPLES = 50;
MIN_CYCLES = 10.0;
MIN_XRMS = 0.005;
SIGMA_FLOOR = 0.002;
N_ALPHA = 1201;

applied = false;
gatePassed = false;

n = double(nBuf);

if n < 3 || ~isfinite(period_s) || period_s <= 0
    [alphaMean,alphaSD] = posterior_moments(logPost);
    return
end

duration = tBuf(n) - tBuf(1);
cycles = duration / period_s;

% Quadratic nuisance projection: B=[1,tn,tn^2]
tMean = 0.0;
for k=1:n
    tMean = tMean + tBuf(k);
end
tMean = tMean/n;

spanT = max(tBuf(1:n)) - min(tBuf(1:n));
if spanT <= eps
    [alphaMean,alphaSD] = posterior_moments(logPost);
    return
end

M = zeros(3,3);
cy = zeros(3,1);
cx = zeros(3,1);

for k=1:n
    tn = 2.0*(tBuf(k)-tMean)/spanT;
    b1 = 1.0;
    b2 = tn;
    b3 = tn*tn;

    M(1,1)=M(1,1)+b1*b1;
    M(1,2)=M(1,2)+b1*b2;
    M(1,3)=M(1,3)+b1*b3;
    M(2,1)=M(2,1)+b2*b1;
    M(2,2)=M(2,2)+b2*b2;
    M(2,3)=M(2,3)+b2*b3;
    M(3,1)=M(3,1)+b3*b1;
    M(3,2)=M(3,2)+b3*b2;
    M(3,3)=M(3,3)+b3*b3;

    cy(1)=cy(1)+b1*yBuf(k);
    cy(2)=cy(2)+b2*yBuf(k);
    cy(3)=cy(3)+b3*yBuf(k);

    cx(1)=cx(1)+b1*xBuf(k);
    cx(2)=cx(2)+b2*xBuf(k);
    cx(3)=cx(3)+b3*xBuf(k);
end

betaY = M\cy;
betaX = M\cx;

yRes = zeros(256,1);
xRes = zeros(256,1);

xSq = 0.0;
xTx = 0.0;
xTy = 0.0;
yTy = 0.0;

for k=1:n
    tn = 2.0*(tBuf(k)-tMean)/spanT;
    yhat = betaY(1)+betaY(2)*tn+betaY(3)*tn*tn;
    xhat = betaX(1)+betaX(2)*tn+betaX(3)*tn*tn;

    yr = yBuf(k)-yhat;
    xr = xBuf(k)-xhat;

    yRes(k)=yr;
    xRes(k)=xr;

    xSq=xSq+xr*xr;
    xTx=xTx+xr*xr;
    xTy=xTy+xr*yr;
    yTy=yTy+yr*yr;
end

xRms = sqrt(xSq/n);

samplePass = n >= MIN_SAMPLES;
cyclePass = cycles >= MIN_CYCLES;
infoPass = xRms >= MIN_XRMS;

gatePassed = windowGate && samplePass && cyclePass && infoPass;

if ~gatePassed
    [alphaMean,alphaSD] = posterior_moments(logPost);
    return
end

alphaOLS = xTy/max(xTx,eps);

r = zeros(256,1);
for k=1:n
    r(k)=yRes(k)-alphaOLS*xRes(k);
end

sigmaV = robust_sigma_fixed(r,n,SIGMA_FLOOR);

dtMean = duration/max(n-1,1);
maxLag = round(3.0*period_s/max(dtMean,eps));
maxLag = min(maxLag,floor(n/4));
maxLag = max(maxLag,1);

tauInt = integrated_autocorr_fixed(r,n,maxLag);
weight = 1.0/tauInt;

maxLL = -inf;
ll = zeros(N_ALPHA,1);

for j=1:N_ALPHA
    a = 0.70 + (j-1)*0.0005;
    sse = yTy - 2.0*a*xTy + a*a*xTx;
    ll(j) = -0.5*weight*sse/(sigmaV*sigmaV);
    if ll(j)>maxLL, maxLL=ll(j); end
end

for j=1:N_ALPHA
    logPost(j)=logPost(j)+(ll(j)-maxLL);
end

% Recenter log posterior numerically.
mx=logPost(1);
for j=2:N_ALPHA
    if logPost(j)>mx, mx=logPost(j); end
end
for j=1:N_ALPHA
    logPost(j)=logPost(j)-mx;
end

[alphaMean,alphaSD] = posterior_moments(logPost);
applied = true;

end

% =========================================================================
% Posterior moments
% =========================================================================
function [mu,sd] = posterior_moments(logPost)
N_ALPHA = 1201;

mx=logPost(1);
for j=2:N_ALPHA
    if logPost(j)>mx, mx=logPost(j); end
end

sw=0.0;
swa=0.0;

for j=1:N_ALPHA
    a=0.70+(j-1)*0.0005;
    w=exp(logPost(j)-mx);
    sw=sw+w;
    swa=swa+w*a;
end

mu=swa/sw;

sv=0.0;
for j=1:N_ALPHA
    a=0.70+(j-1)*0.0005;
    w=exp(logPost(j)-mx);
    d=a-mu;
    sv=sv+w*d*d;
end

sd=sqrt(sv/sw);
end

% =========================================================================
% Robust sigma with fixed-size insertion-sort median
% =========================================================================
function s = robust_sigma_fixed(r,n,floorV)
tmp=zeros(256,1);
for k=1:n, tmp(k)=r(k); end
med=median_fixed(tmp,n);

adev=zeros(256,1);
for k=1:n, adev(k)=abs(r(k)-med); end
mad=median_fixed(adev,n);

s=1.4826*mad;
if ~isfinite(s) || s<floorV, s=floorV; end
end

function m = median_fixed(x,n)
tmp=x;

for i=2:n
    key=tmp(i);
    j=i-1;
    while j>=1 && tmp(j)>key
        tmp(j+1)=tmp(j);
        j=j-1;
    end
    tmp(j+1)=key;
end

if mod(n,2)==1
    m=tmp((n+1)/2);
else
    m=0.5*(tmp(n/2)+tmp(n/2+1));
end
end

% =========================================================================
% Integrated autocorrelation time
% =========================================================================
function tau = integrated_autocorr_fixed(r,n,maxLag)
rMean=0.0;
for k=1:n, rMean=rMean+r(k); end
rMean=rMean/n;

den=0.0;
for k=1:n
    d=r(k)-rMean;
    den=den+d*d;
end

if den<=eps
    tau=1.0;
    return
end

rhoSum=0.0;

for lag=1:maxLag
    num=0.0;
    for k=1:n-lag
        num=num+(r(k)-rMean)*(r(k+lag)-rMean);
    end

    rho=num/den;

    if ~isfinite(rho) || rho<=0
        break
    end

    rhoSum=rhoSum+rho;
end

tau=max(1.0,1.0+2.0*rhoSum);
end

% =========================================================================
% Frozen 2RC shadow state transition / LUT
% =========================================================================
function xNext = stateFcn(x,currentA,dt,model)
p=getParams(model,x(3));

tau1=p.R1*p.C1;
tau2=p.R2*p.C2;

a1=exp(-dt/tau1);
a2=exp(-dt/tau2);

b1=p.R1*(1-a1);
b2=p.R2*(1-a2);

xNext=zeros(3,1);
xNext(1)=a1*x(1)+b1*currentA;
xNext(2)=a2*x(2)+b2*currentA;
xNext(3)=x(3)+currentA*dt/(3600*model.qRefAh);
end

function p = getParams(model,soc)
z=min(max(soc,model.socMin),model.socMax);

p.OCV=lutLinear(model.soc,model.ocv,z);
p.R0=lutLinear(model.soc,model.R0,z);
p.R1=lutLinear(model.soc,model.R1,z);
p.C1=lutLinear(model.soc,model.C1,z);
p.R2=lutLinear(model.soc,model.R2,z);
p.C2=lutLinear(model.soc,model.C2,z);
end

function y = lutLinear(bp,tableData,z)
n=numel(bp);

if z<=bp(1), y=tableData(1); return; end
if z>=bp(n), y=tableData(n); return; end

y=tableData(n);

for k=1:n-1
    if z<=bp(k+1)
        a=(z-bp(k))/(bp(k+1)-bp(k));
        y=tableData(k)+a*(tableData(k+1)-tableData(k));
        return
    end
end
end
