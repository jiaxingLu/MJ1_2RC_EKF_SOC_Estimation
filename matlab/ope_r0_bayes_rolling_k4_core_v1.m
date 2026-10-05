function [alphaMean,alphaSD,updatePulse,gateOpen,shadowSOC,windowCount,updateCount] = ...
    ope_r0_bayes_rolling_k4_core_v1(tNow,I_meas,V_meas,fastBandEnable,period_s,reset)
%OPE_R0_BAYES_ROLLING_K4_CORE_V1
% Extension-track SHADOW CANDIDATE: rolling-memory Bayesian R0 updater.
%#codegen
%
% IMPORTANT
%   This is NOT the frozen v1.0 updater and does not replace it.
%   Frozen v1.0 remains:
%       ope_r0_bayes_online_core_v2.m
%
% Candidate change relative to frozen v1.0:
%   posterior uses ONLY the most recent K=4 accepted window likelihoods:
%
%       p_k(alpha) proportional to p0(alpha) *
%           product_{j=max(1,k-3)}^k L_j(alpha)
%
% Everything else is intentionally preserved from frozen v1.0:
%   - alpha grid 0.70:0.0005:1.30
%   - N(1,0.15^2) prior
%   - SOC start band 0.20...0.80
%   - 20-cycle windows
%   - quadratic nuisance projection
%   - min XRMS / min cycles / min samples
%   - robust sigma with 2 mV floor
%   - residual autocorrelation weighting
%   - independent frozen 2RC shadow model
%   - causal previous-window finalization timing
%
% Status:
%   SHADOW CANDIDATE ONLY. Not independently validated for release.

S = coder.load('mj1_v02_model.mat','model');
model = S.model;

MAX_BUF = 256;
N_ALPHA = 1201;
K_MEMORY = 4;

persistent initialized
persistent xShadow IPrev tPrev havePrev
persistent priorLog logPost alphaState alphaSDState
persistent llHist histCount histWrite
persistent tBuf yBuf xBuf nBuf
persistent collecting windowStart windowGate
persistent winCount updCount

if isempty(initialized) || reset > 0.5
    initialized = true;

    xShadow = zeros(3,1);
    IPrev = 0.0;
    tPrev = tNow;
    havePrev = false;

    priorLog = zeros(N_ALPHA,1);
    for j = 1:N_ALPHA
        a = 0.70 + (j-1)*0.0005;
        priorLog(j) = -0.5*((a-1.0)/0.15)^2;
    end

    logPost = priorLog;
    [alphaState,alphaSDState] = posterior_moments(logPost);

    llHist = zeros(N_ALPHA,K_MEMORY);
    histCount = int32(0);
    histWrite = int32(1);

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

startEligible = ...
    xShadow(3) >= 0.20 && ...
    xShadow(3) < 0.80 && ...
    V_meas < 4.2;

windowDuration = 20.0 * period_s;
endRegionReached = xShadow(3) >= 0.80 || V_meas >= 4.2;

% -------------------------------------------------------------------------
% Finalize previous window before current sample is admitted.
% -------------------------------------------------------------------------
if collecting && ( ...
        (isfinite(windowDuration) && windowDuration > 0 && ...
         tNow > windowStart + windowDuration) || ...
        endRegionReached )

    [ll,applied,passed] = ...
        finalize_window_likelihood(tBuf,yBuf,xBuf,nBuf, ...
                                   windowGate,period_s);

    if passed
        gateOpen = 1.0;
    end

    if applied
        % Store the accepted centered log-likelihood in a K=4 ring buffer.
        llHist(:,double(histWrite)) = ll;

        if histCount < K_MEMORY
            histCount = histCount + 1;
        end

        histWrite = histWrite + 1;
        if histWrite > K_MEMORY
            histWrite = int32(1);
        end

        % Rebuild posterior from ORIGINAL prior + currently retained
        % accepted likelihoods. Order does not matter for the sum.
        logPost = priorLog;

        for h = 1:K_MEMORY
            if h <= double(histCount)
                logPost = logPost + llHist(:,h);
            end
        end

        mx = logPost(1);
        for j = 2:N_ALPHA
            if logPost(j) > mx
                mx = logPost(j);
            end
        end

        for j = 1:N_ALPHA
            logPost(j) = logPost(j) - mx;
        end

        [alphaState,alphaSDState] = posterior_moments(logPost);

        updatePulse = 1.0;
        updCount = updCount + 1;
    end

    collecting = false;
    nBuf = int32(0);
    windowGate = true;
end

% Posterior after any previous-window update.
alphaMean = alphaState;
alphaSD = alphaSDState;

% -------------------------------------------------------------------------
% Start/fill current window.
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

IPrev = I_meas;
tPrev = tNow;
havePrev = true;

shadowSOC = xShadow(3);
windowCount = double(winCount);
updateCount = double(updCount);

end


% =========================================================================
function [ll,applied,gatePassed] = ...
    finalize_window_likelihood(tBuf,yBuf,xBuf,nBuf,windowGate,period_s)

MIN_SAMPLES = 50;
MIN_CYCLES = 10.0;
MIN_XRMS = 0.005;
SIGMA_FLOOR = 0.002;
N_ALPHA = 1201;

ll = zeros(N_ALPHA,1);
applied = false;
gatePassed = false;

n = double(nBuf);

if n < 3 || ~isfinite(period_s) || period_s <= 0
    return
end

duration = tBuf(n) - tBuf(1);
cycles = duration / period_s;

% Quadratic nuisance projection B=[1,tn,tn^2]
tMean = 0.0;
for k = 1:n
    tMean = tMean + tBuf(k);
end
tMean = tMean/n;

spanT = max(tBuf(1:n)) - min(tBuf(1:n));

if spanT <= eps
    return
end

M = zeros(3,3);
cy = zeros(3,1);
cx = zeros(3,1);

for k = 1:n
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

for k = 1:n
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
    return
end

alphaOLS = xTy/max(xTx,eps);

r = zeros(256,1);
for k = 1:n
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

for j = 1:N_ALPHA
    a = 0.70 + (j-1)*0.0005;
    sse = yTy - 2.0*a*xTy + a*a*xTx;

    ll(j) = -0.5*weight*sse/(sigmaV*sigmaV);

    if ll(j) > maxLL
        maxLL = ll(j);
    end
end

% Center each retained likelihood before storing.
for j = 1:N_ALPHA
    ll(j) = ll(j)-maxLL;
end

applied = true;

end


% =========================================================================
function [mu,sd] = posterior_moments(logPost)

N_ALPHA = 1201;

mx=logPost(1);
for j=2:N_ALPHA
    if logPost(j)>mx
        mx=logPost(j);
    end
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
function s = robust_sigma_fixed(r,n,floorV)

tmp=zeros(256,1);
for k=1:n
    tmp(k)=r(k);
end

med=median_fixed(tmp,n);

adev=zeros(256,1);
for k=1:n
    adev(k)=abs(r(k)-med);
end

mad=median_fixed(adev,n);

s=1.4826*mad;

if ~isfinite(s) || s<floorV
    s=floorV;
end

end


% =========================================================================
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
function tau = integrated_autocorr_fixed(r,n,maxLag)

rMean=0.0;
for k=1:n
    rMean=rMean+r(k);
end
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


% =========================================================================
function p = getParams(model,soc)

z=min(max(soc,model.socMin),model.socMax);

p.OCV=lutLinear(model.soc,model.ocv,z);
p.R0=lutLinear(model.soc,model.R0,z);
p.R1=lutLinear(model.soc,model.R1,z);
p.C1=lutLinear(model.soc,model.C1,z);
p.R2=lutLinear(model.soc,model.R2,z);
p.C2=lutLinear(model.soc,model.C2,z);

end


% =========================================================================
function y = lutLinear(bp,tableData,z)

n=numel(bp);

if z<=bp(1)
    y=tableData(1);
    return
end

if z>=bp(n)
    y=tableData(n);
    return
end

y=tableData(n);

for k=1:n-1
    if z<=bp(k+1)
        a=(z-bp(k))/(bp(k+1)-bp(k));
        y=tableData(k)+a*(tableData(k+1)-tableData(k));
        return
    end
end

end
