function x = lora_chirp(symbol, cfg)
% LORA_CHIRP  One LoRa upchirp carrying the value "symbol" (0 .. N-1).
%
%   x = lora_chirp(0, cfg)          % base upchirp (used in the preamble)
%   x = conj(lora_chirp(0, cfg))    % base DOWNchirp (conjugate = reversed sweep)
%   x = lora_chirp(37, cfg)         % symbol 37
%
%   x is a column vector of cfg.sps = N*OSR complex samples, |x| = 1.
%
% THE PHYSICS (read this slowly - it is the heart of LoRa)
%   A chirp is a tone whose frequency rises linearly with time. The LoRa
%   chirp sweeps from -BW/2 to +BW/2 in one symbol time Tsym = N/BW.
%
%   To carry a value s, the chirp STARTS at a different frequency:
%       f_start = -BW/2 + s * BW/N
%   It rises at the same rate, and when it hits +BW/2 it WRAPS around to
%   -BW/2 and keeps rising. So every symbol is the same sweep, cyclically
%   shifted in time by s chips. N = 2^SF possible shifts = SF bits.
%
%   Instantaneous frequency at sample k (k = 0, 1, ...):
%       f(k) = BW * ( mod( s/N + k/(N*OSR) , 1 ) - 1/2 )
%         - s/N        : the starting offset (fraction of the band)
%         - k/(N*OSR)  : how far through the symbol we are (0 -> 1)
%         - mod(., 1)  : the wrap-around (keeps the fraction in [0,1))
%         - -1/2, *BW  : maps [0,1) to [-BW/2, +BW/2)
%
%   PHASE is the integral of frequency: phi(t) = 2*pi * integral of f(t) dt.
%   Measuring time in chips, tau = t*BW (tau = k/OSR at sample k), the
%   integral can be done exactly:
%       phi(tau) = 2*pi * ( (s*tau + tau^2/2 - N*max(0, tau-(N-s))) / N - tau/2 )
%         - s*tau/N         : the starting frequency offset
%         - tau^2/(2N)      : the linear sweep (frequency rises -> phase is quadratic)
%         - N*max(0, ...)   : the wrap from +BW/2 back to -BW/2 after N-s chips
%         - tau/2           : the -BW/2 starting point
%       x(k) = exp(1j * phi(k)) = cos(phi) + 1j*sin(phi)   (I + jQ)
%
%   WHY EXACT, NOT A RUNNING SUM: an earlier version added up f/fs sample by
%   sample (cumsum). That small rounding error depends on fs, so a chirp
%   made at OSR = 8 and then sampled once per chip was about 0.44 FFT bin
%   off the OSR = 1 reference chirp. The receiver decimates the 1 MHz USRP
%   capture to one sample per chip, so that offset left almost no timing
%   margin (a 1/4-chip error flipped symbols). With the exact phase, a chirp
%   at any OSR is the same continuous waveform sampled more or less often.
%
% SYNTAX NOTES
%   - (0:L-1).' is a column vector 0,1,...,L-1. ".'" = transpose.
%   - Operations like  tau.^2  apply to every element at once (".^" =
%     element-wise power).
%   - max(0, v) compares 0 with every element of v and keeps the larger.
%   - 1j is the imaginary unit (sqrt(-1)). exp(1j*phi) is a unit-length
%     complex number at angle phi. Real part = I, imaginary part = Q.

    N   = cfg.N;
    OSR = cfg.OSR;
    L   = N * OSR;
    tau = (0:L-1).' / OSR;                       % time in chips
    s   = mod(symbol, N);
    
    phi = 2*pi * ( (s*tau + tau.^2/2 - N*max(0, tau - (N - s))) / N - tau/2 );
    x   = exp(1j * phi);
end