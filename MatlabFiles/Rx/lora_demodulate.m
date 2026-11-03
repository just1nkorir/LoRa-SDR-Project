function [symbols, peakMag] = lora_demodulate(iq, nSymbols, cfg)
% LORA_DEMODULATE  IQ samples -> symbol values, using dechirp + FFT.
%
%   [symbols, peakMag] = lora_demodulate(iq, nSymbols, cfg)
%     iq       : column of samples at ONE sample per chip (cfg.OSR = 1),
%                starting EXACTLY at the first symbol to demodulate
%     nSymbols : how many symbols to demodulate
%     symbols  : row of detected values (0 .. N-1)
%     peakMag  : FFT peak height per symbol (a quality / confidence measure)
%
% WHY DECHIRP + FFT WORKS
%   1. Multiply the received chirp by the CONJUGATE of the base upchirp
%      (= a downchirp). Multiplying complex exponentials ADDS their phases,
%      and conjugating negates a phase, so the rising sweep cancels:
%          exp(j*phi_s(k)) * exp(-j*phi_0(k)) = exp(j*(phi_s(k) - phi_0(k)))
%      What is left is a plain TONE at frequency s * BW/N.
%      (The wrap-around leaves a phase jump that is a whole number of 2*pi
%       at the chip-rate samples, so it disappears.)
%   2. An N-point FFT of a pure tone at s*BW/N has ONE peak, in bin s.
%   3. So: detected symbol = (index of the biggest FFT bin) - 1.
%      ("-1" because MATLAB indexes from 1 but symbol values start at 0.)
%
%   With noise, the FFT gathers all N samples of signal energy into one bin
%   while noise spreads over all bins. That's the "processing gain" of
%   10*log10(N) dB, and why LoRa works BELOW 0 dB SNR.
%
% WHY ONE SAMPLE PER CHIP
%   The USRP capture has 8 samples per chip. Keeping every 8th sample
%   WITHOUT filtering first folds all the out-of-band noise into the band
%   (about 9 dB lost at OSR 8). The front end filters and decimates first,
%   so this function only ever sees 1 sample per chip - checked below.
%
% SYNTAX NOTES
%   - iq(1:L) takes the first L samples; reshape(..., N, nSymbols) cuts
%     them into one column per symbol.
%   - D = X .* down : ".*" is ELEMENT-wise multiply. "down" is N x 1 and X
%     is N x M; MATLAB repeats "down" across all M columns ("implicit
%     expansion", like NumPy broadcasting), so every symbol is dechirped at
%     once.
%   - fft(A) on a matrix computes the FFT of EACH COLUMN.
%   - [m, idx] = max(A) returns the max value AND its row index per column.

    assert(cfg.OSR == 1, ['lora_demodulate expects 1 sample per chip (cfg.OSR = 1). ' ...
           'Filter and decimate the capture first (rx_frontend).']);
    
    N = cfg.N;
    L = nSymbols * N;
    assert(numel(iq) >= L, 'Not enough samples for %d symbols', nSymbols);
    
    X    = reshape(iq(1:L), N, nSymbols);       % one column per symbol
    down = conj(lora_chirp(0, cfg));            % base downchirp
    D    = X .* down;                           % dechirp every column
    F    = abs(fft(D));                         % N x nSymbols magnitudes
    [peakMag, idx] = max(F);                    % strongest bin per column
    symbols = idx - 1;
end