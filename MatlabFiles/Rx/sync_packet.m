function [s0, cfo_Hz, score, ok] = sync_packet(xf, xd, run, ratU, cfg)
% SYNC_PACKET  One preamble run -> exact packet start and CFO.
%   [s0, cfo_Hz, score, ok] = sync_packet(xf, xd, run, ratU, cfg)
%     xf     : filtered capture at the full rate (cfg.OSR, from rx_frontend)
%     xd     : xf(1:OSR:end), 1 sample per chip (what scan_windows used)
%     run    : [firstWindow, lastWindow] from find_runs
%     ratU   : ratio row from scan_windows (upchirp scan)
%     s0     : full-rate sample index of the first preamble sample
%     cfo_Hz : carrier frequency offset (RX - TX), Hz
%     score  : sync quality (mean peak/average of 4 boundary chirps)
%     ok     : false if this run is not a real packet
%
%   Upchirp windows peak at u = c + tau, downchirp (SFD) windows at
%   v = c - tau  (c = CFO in bins, tau = timing offset in chips), so
%   c = (u+v)/2 and tau = (u-v)/2. The +-1 symbol ambiguity is resolved by
%   scoring 3 candidate starts; then 2 refinements on aligned windows.

    N   = cfg.N;
    OSR = cfg.OSR;
    P   = cfg.preambleLen;
    Zf  = 16;                                   % fine zero-padding
    thr = cfg.rx.detThresh;
    c1  = cfg;  c1.OSR = 1;  c1 = finalize_cfg(c1);
    up1 = lora_chirp(0, c1);
    dn1 = conj(up1);                            % 1-sample-per-chip reference chirps
    s0     = NaN;                               % "failed" defaults
    cfo_Hz = NaN;
    score  = -Inf;
    ok     = false;
    
    % A. u: summed spectrum of the run's windows
    mS = run(1);
    mE = run(2);
    X  = reshape(xd((mS-1)*N + 1 : mE*N), N, mE - mS + 1);
    u  = interp_peak(sum(abs(fft(X .* dn1, Zf*N)).^2, 2)) / Zf;
    
    % B. v: first window near the END of the run (from 1 window before its
    %    end, since the run can swallow the first SFD window) that looks
    %    more like a downchirp than an upchirp
    nWin = floor(numel(xd) / N);
    v  = NaN;
    mD = 0;
    for m = max(mS+1, mE-1) : min(nWin, mE+3) 
        F = abs(fft(xd((m-1)*N + (1:N)) .* up1, Zf*N)).^2;
        r = max(F) / mean(F);
        if r > thr && r > ratU(m)
            v  = interp_peak(F) / Zf;
            mD = m;
            break
        end
    end
    if mD == 0
        return                                  % no SFD: not a packet
    end
    
    % C. solve for CFO (c, bins) and timing (tau, chips)
    s  = mod(u + v, N);
    cA = wrapN(s/2, N);
    cB = wrapN(s/2 + N/2, N);
    if abs(cA) <= abs(cB)
        c = cA;
    else
        c = cB;
    end
    tau = mod(u - c, N);
    
    % D. three candidate starts (+-1 symbol), keep the best
    sfdBase = (mD - 1)*N + 1 - tau;             % an SFD boundary, in xd samples
    for k = -1:1
        cand = round((sfdBase + k*N - P*N - 1) * OSR) + 1;   % packet start, full rate
        sc   = sync_score(xf, cand, c, cfg, up1, dn1);
        if sc > score
            score = sc;
            s0    = cand;
        end
    end
    if ~(score > cfg.rx.syncThresh)
        return                                  % too weak: noise
    end
    
    % E. refine twice, convert to Hz
    for it = 1:2
        [s0, c] = refine_sync(xf, s0, c, cfg, up1, dn1, Zf);
    end
    cfo_Hz = c * cfg.BW / N;
    ok = true;
end

function sc = sync_score(xf, s0, c, cfg, up1, dn1)
    N = cfg.N;  OSR = cfg.OSR;  P = cfg.preambleLen;
    idx = s0 + (0:(P+2)*N - 1) * OSR;            % aligned 1-sample/chip indices, P+2 symbols
    if idx(1) < 1 || idx(end) > numel(xf)
        sc = -Inf;  return                        % runs off the capture
    end
    Y = reshape(xf(idx), N, P + 2);               % one column per symbol
    sc = mean([ratio_near(Y(:,P-1) .* dn1, c), ratio_near(Y(:,P) .* dn1, c), ...
        ratio_near(Y(:,P+1) .* up1, c), ratio_near(Y(:,P+2) .* up1, c)]);
end

function r = ratio_near(d, c)
    N = numel(d);
    F = abs(fft(d)).^2;
    r = max(F(mod(round(c) + (-1:1), N) + 1)) / mean(F);   % max over bins c-1, c, c+1
end

function [s0, c] = refine_sync(xf, s0, c, cfg, up1, dn1, Zf)
    N = cfg.N;  OSR = cfg.OSR;  P = cfg.preambleLen;
    idx = s0 + (0:(P+2)*N - 1) * OSR;
    if idx(1) < 1 || idx(end) > numel(xf), return, end
    Y = reshape(xf(idx), N, P + 2);
    u = interp_peak(sum(abs(fft(Y(:, 1:P)     .* dn1, Zf*N)).^2, 2)) / Zf;   % all P upchirps
    v = interp_peak(sum(abs(fft(Y(:, P+1:P+2) .* up1, Zf*N)).^2, 2)) / Zf;   % both downchirps
    u = c + wrapN(u - c, N);          % unwrap next to the previous estimate
    v = c + wrapN(v - c, N);
    c   = (u + v) / 2;
    tau = (u - v) / 2;                % remaining timing error, chips
    s0  = s0 - round(tau * OSR);      % move the start by that many full-rate samples
end

function y = wrapN(x, N)
    y = mod(x + N/2, N) - N/2;        % into -N/2 .. N/2
end