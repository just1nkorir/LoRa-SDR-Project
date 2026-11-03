function [bin, ratio] = scan_windows(xd, ref, Z)
% SCAN_WINDOWS  Dechirp + FFT every 1-symbol window: peak bin and strength.
%   [bin, ratio] = scan_windows(xd, ref, Z)
%     xd    : capture at 1 sample per chip (column)
%     ref   : N x 1 reference: conj(upchirp) to find UPchirps,
%             the upchirp itself to find DOWNchirps
%     Z     : FFT zero-padding factor (bins come out in steps of 1/Z)
%     bin   : row, peak bin of each window (0 .. N - 1/Z)
%     ratio : row, peak power / mean power of each window
%   Windows inside a preamble all peak in the SAME bin with a high ratio.

    N    = numel(ref);
    nWin = floor(numel(xd) / N);                 % whole windows only
    X    = reshape(xd(1 : nWin*N), N, nWin);     % column w = window w
    F    = abs(fft(X .* ref, Z*N)).^2;           % dechirp, zero-padded FFT, power
    [m, i] = max(F);                             % peak per column
    bin   = (i - 1) / Z;                         % back to normal bin units
    ratio = m ./ mean(F);
end