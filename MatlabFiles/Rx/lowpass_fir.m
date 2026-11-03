function h = lowpass_fir(cutoff_Hz, fs, nTaps)
% LOWPASS_FIR  Windowed-sinc low-pass FIR filter (no toolbox needed).
%   h = lowpass_fir(cutoff_Hz, fs, nTaps)
%     cutoff_Hz : edge of the pass band (Hz)
%     fs        : sample rate (Hz)
%     nTaps     : filter length, ODD so the delay (nTaps-1)/2 is whole
%     h         : column of coefficients, unity gain at 0 Hz
%   The ideal low-pass impulse response is a sinc; we cut it to nTaps
%   samples and multiply by a Hamming window to avoid ripples (= fir1).

    n  = (0:nTaps-1).' - (nTaps-1)/2;            % index centred on 0
    fc = cutoff_Hz / fs;                         % cutoff, cycles per sample
    x  = 2*fc*n;
    s  = sin(pi*x) ./ (pi*x);                    % sinc ...
    s(x == 0) = 1;                               % ... with sinc(0) = 1 (not 0/0)
    w  = 0.54 - 0.46*cos(2*pi*(0:nTaps-1).' / (nTaps-1));   % Hamming window
    h  = 2*fc * s .* w;
    h  = h / sum(h);                             % gain exactly 1 at 0 Hz
end