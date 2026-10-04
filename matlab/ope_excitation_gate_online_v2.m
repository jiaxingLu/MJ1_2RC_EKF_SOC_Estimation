function [fastBandEnable,period_s,signalRMS,fastPowerFraction,peakConcentration,omegaTau] = ...
    ope_excitation_gate_online_v2(I_meas,tauFastRef_s,reset)
%OPE_EXCITATION_GATE_ONLINE_V2 Autonomous fast-excitation detector.
%#codegen
%
% Purpose:
%   Detect whether the recent current contains a sufficiently strong,
%   concentrated periodic component above the fast-RC corner frequency.
%
% Inputs
%   I_meas        current sample [A], sampled at 1 s
%   tauFastRef_s  validated fast-branch time constant reference [s]
%   reset         reset persistent state (0/1)
%
% Outputs
%   fastBandEnable      0/1 gate
%   period_s            estimated dominant fast period [s]
%   signalRMS           detrended current RMS [A]
%   fastPowerFraction   spectral power fraction in 3...25 s band
%   peakConcentration   dominant-bin fraction of fast-band power
%   omegaTau            2*pi*tauFastRef_s/period_s
%
% Design
%   - fixed 128-s current buffer
%   - linear detrend
%   - manual DFT, no DSP toolbox
%   - search band: periods 3...25 s
%   - 17-point local frequency refinement around coarse DFT peak
%   - evaluate every 8 samples after buffer fills
%   - 3 positive evaluations required to OPEN
%   - 3 negative evaluations required to CLOSE
%
% Thresholds
%   detrended RMS       >= 0.15 A
%   fastPowerFraction   >= 0.55
%   peakConcentration   >= 0.20
%   omegaTau            >= 1
%
% LIMITATION
%   This detector is validated for periodic/sinusoidal excitation. It is not
%   a general drive-cycle persistent-excitation metric.

N = 128;
EVAL_STEP = 8;

persistent buf nSeen writeIdx samplesSinceEval
persistent gateState posCount negCount
persistent periodState rmsState fastFracState peakConcState omegaTauState

if isempty(nSeen) || reset > 0.5
    buf = zeros(N,1);
    nSeen = int32(0);
    writeIdx = int32(1);
    samplesSinceEval = int32(0);

    gateState = 0.0;
    posCount = int32(0);
    negCount = int32(0);

    periodState = NaN;
    rmsState = 0.0;
    fastFracState = 0.0;
    peakConcState = 0.0;
    omegaTauState = 0.0;
end

buf(double(writeIdx)) = I_meas;
writeIdx = writeIdx + 1;
if writeIdx > N
    writeIdx = int32(1);
end

if nSeen < N
    nSeen = nSeen + 1;
end

samplesSinceEval = samplesSinceEval + 1;

if nSeen >= N && samplesSinceEval >= EVAL_STEP
    samplesSinceEval = int32(0);

    % Reconstruct chronological buffer, oldest -> newest.
    x = zeros(N,1);
    if writeIdx == 1
        x(:) = buf(:);
    else
        first = double(writeIdx);
        n1 = N-first+1;
        x(1:n1) = buf(first:N);
        x(n1+1:N) = buf(1:first-1);
    end

    % Linear detrend x(n) = a + b*n.
    sx = 0.0;
    snx = 0.0;
    sn = 0.0;
    sn2 = 0.0;

    for k=1:N
        nk = double(k-1);
        sx = sx + x(k);
        snx = snx + nk*x(k);
        sn = sn + nk;
        sn2 = sn2 + nk*nk;
    end

    den = N*sn2-sn*sn;
    if den > eps
        b = (N*snx-sn*sx)/den;
        a = (sx-b*sn)/N;
    else
        a = sx/N;
        b = 0.0;
    end

    xd = zeros(N,1);
    sq = 0.0;
    for k=1:N
        nk = double(k-1);
        xd(k) = x(k)-(a+b*nk);
        sq = sq+xd(k)*xd(k);
    end

    signalR = sqrt(sq/N);

    % Manual positive-frequency DFT powers, k=1..N/2.
    % MATLAB DFT bin index m corresponds to f=m/N Hz at Fs=1 Hz.
    pwr = zeros(N/2,1);

    for m=1:N/2
        re = 0.0;
        im = 0.0;
        for k=1:N
            ang = -2.0*pi*double(m)*double(k-1)/double(N);
            re = re + xd(k)*cos(ang);
            im = im + xd(k)*sin(ang);
        end
        pwr(m)=re*re+im*im;
    end

    totalP = 0.0;
    for m=1:N/2
        totalP = totalP+pwr(m);
    end

    % Fast search band: 3 <= period <= 25 s.
    mMin = ceil(N/25.0);   % >=0.04 Hz
    mMax = floor(N/3.0);   % <=0.333 Hz
    mMin = max(mMin,1);
    mMax = min(mMax,N/2);

    fastP = 0.0;
    peakP = -1.0;
    mPeak = mMin;

    for m=mMin:mMax
        fastP = fastP+pwr(m);
        if pwr(m)>peakP
            peakP=pwr(m);
            mPeak=m;
        end
    end

    if totalP > eps
        fastFrac = fastP/totalP;
    else
        fastFrac = 0.0;
    end

    if fastP > eps
        peakConc = peakP/fastP;
    else
        peakConc = 0.0;
    end

    % ---------------------------------------------------------------------
    % Local fine-frequency refinement around the coarse DFT peak.
    %
    % Why:
    % A 128-s DFT has bin spacing 1/128 = 0.0078125 Hz. Near the fast-RC
    % corner (about 0.0492 Hz here), simple three-bin quadratic interpolation
    % biased a true 20-s sinusoid toward about 20.9 s. That was sufficient to
    % flip omega*tau from just above 1 to just below 1.
    %
    % Keep the toolbox-free coarse DFT for robust band selection, then search
    % only +/- one coarse bin around mPeak using 17 direct periodogram points.
    % This adds modest computation and removes the corner-frequency bias
    % without changing the amplitude/power/concentration gates.
    % ---------------------------------------------------------------------
    fCoarse = double(mPeak)/double(N);
    fLo = max(1.0/25.0, fCoarse-1.0/double(N));
    fHi = min(1.0/3.0,  fCoarse+1.0/double(N));

    bestFinePower = -1.0;
    fPeak = fCoarse;

    N_FINE = 17;

    for r=1:N_FINE
        if N_FINE>1
            fTest = fLo + (fHi-fLo)*double(r-1)/double(N_FINE-1);
        else
            fTest = fCoarse;
        end

        reFine = 0.0;
        imFine = 0.0;

        for k=1:N
            angFine = -2.0*pi*fTest*double(k-1);
            reFine = reFine + xd(k)*cos(angFine);
            imFine = imFine + xd(k)*sin(angFine);
        end

        finePower = reFine*reFine + imFine*imFine;

        if finePower > bestFinePower
            bestFinePower = finePower;
            fPeak = fTest;
        end
    end

    if fPeak>0
        periodEst=1.0/fPeak;
        omegaTauEst=2.0*pi*tauFastRef_s/periodEst;
    else
        periodEst=NaN;
        omegaTauEst=0.0;
    end

    candidate = ...
        signalR >= 0.15 && ...
        fastFrac >= 0.55 && ...
        peakConc >= 0.20 && ...
        omegaTauEst >= 1.0;

    if candidate
        posCount=posCount+1;
        negCount=int32(0);
    else
        negCount=negCount+1;
        posCount=int32(0);
    end

    if gateState < 0.5 && posCount >= 3
        gateState=1.0;
    elseif gateState > 0.5 && negCount >= 3
        gateState=0.0;
    end

    periodState=periodEst;
    rmsState=signalR;
    fastFracState=fastFrac;
    peakConcState=peakConc;
    omegaTauState=omegaTauEst;
end

fastBandEnable=gateState;
period_s=periodState;
signalRMS=rmsState;
fastPowerFraction=fastFracState;
peakConcentration=peakConcState;
omegaTau=omegaTauState;
end
