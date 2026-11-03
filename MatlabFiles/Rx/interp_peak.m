function k = interp_peak(S)
% INTERP_PEAK  Fractional (0-based) position of the maximum of a spectrum.
%   k = interp_peak(S)
%   Fits a parabola through the highest sample and its two neighbours
%   (circular: the spectrum wraps around) and returns where its top is.
%   Result is in 0 .. numel(S); divide by Z for a Z-times zero-padded FFT.
%   interp_peak([1 4 9 4 1]) -> 2

    L = numel(S);
    [~, i] = max(S);
    b = S(i);                         % peak
    a = S(mod(i-2, L) + 1);           % left neighbour  (wraps)
    g = S(mod(i,   L) + 1);           % right neighbour (wraps)
    den = a - 2*b + g;
    p = 0;
    if den ~= 0
        p = 0.5 * (a - g) / den;      % offset of the parabola's top, -0.5..0.5
    end
    k = mod(i - 1 + p, L);            % 0-based, wrapped into 0..L
end