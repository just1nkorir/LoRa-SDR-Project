function runs = find_runs(bin, ratio, N, thr, minRun)
% FIND_RUNS  Find preamble candidates: runs of strong windows in the same bin.
%   runs = find_runs(bin, ratio, N, thr, minRun)
%     bin, ratio : rows from scan_windows
%     N          : number of bins (2^SF), for wrap-around
%     thr        : minimum ratio for a window to count (e.g. 4)
%     minRun     : minimum run length in windows (e.g. 5)
%     runs       : K x 2, one run per row: [firstWindow, lastWindow]
%   A run continues while windows are strong and within 2 bins of the
%   STRONGEST window so far (the most reliable bin estimate - the first
%   window may be a noisy partial one); ONE weak/off window may be skipped
%   (low-SNR robustness).

    nWin = numel(bin);
    good = ratio > thr;
    runs = zeros(0, 2);
    m = 1;
    while m <= nWin
        if ~good(m)
            m = m + 1;
            continue                                   % weak window: move on
        end
        s = m;                                         % run starts here
        ref = m;
        j = m + 1;
        while j <= nWin
            if good(j) && circ_dist(bin(j), bin(ref), N) <= 2
                m = j;                                 % extend by one
                j = j + 1;
            elseif j + 1 <= nWin && good(j+1) && circ_dist(bin(j+1), bin(ref), N) <= 2
                m = j + 1;                             % jump over one bad window
                j = j + 2;
            else
                break                                  % run ended
            end

            if ratio(m) > ratio(ref)
                ref = m;                    % strongest window so far = best bin reference
            end
        end
        if m - s + 1 >= minRun
            runs(end+1, :) = [s, m]; %#ok<AGROW>
        end
        m = m + 1;                                     % continue after the run
    end
end

function d = circ_dist(a, b, N)
% Distance between two bins on a circle of N bins (bin N-0.5 is next to 0).
    d = abs(mod(a - b + N/2, N) - N/2);
end