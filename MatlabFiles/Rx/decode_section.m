function [nib, st] = decode_section(symbols, CR, SF)
% DECODE_SECTION  LoRa symbol values -> nibbles (Gray, de-interleave, Hamming).
%
%   [nib, st] = decode_section(symbols, CR, SF)
%     symbols : row of detected symbol values (0..2^SF-1), from lora_demodulate
%     CR      : coding rate index used at the TX (4 for the header, cfg.CR
%               for the payload)
%     SF      : spreading factor
%     nib     : row of nibbles (0..15), INCLUDING the zero padding the TX
%               added: nBlocks*SF of them. The caller trims it to the real
%               length (6 for the header, 2*bytes for the payload).
%     st      : st.nCorrected = codewords with one bit fixed
%               st.nDetected  = codewords with an error that could not be fixed
%
%   Example:  decode_section([89 51 70 59 63], 1, 7)  ->  [5 12 7 0 15 9 3]
%
% MIRROR OF encode_section, steps in reverse:
%   TX: nibbles -> pad -> hamming_encode -> interleave -> bits->values -> gray_decode
%   RX: symbols -> gray_encode -> values->bits -> deinterleave -> hamming_decode
%
%   1. gray_encode: a one-bin FFT error (s+-1) becomes a one-bit error.
%   2. Blocks: every n = 4+CR symbols form one block (SF codewords).
%   3. Per block: split each value into SF bits (n x SF), de-interleave
%      (-> SF x n codewords) and store them in cw.
%   4. hamming_decode all codewords at once.
%
% SYNTAX NOTES
%   - assert(cond, msg, ...) stops with msg if cond is false; %d is replaced
%     by the values that follow.
%   - values(idx) picks several elements at once (idx is a vector).
%   - v(:) ./ 2.^(0:SF-1): column ./ row -> n x SF grid (implicit expansion);
%     floor + mod 2 then gives bit i of value j, least significant first.
%   - cw(rows, :) = C fills rows "rows", all columns, with the block C.

    values  = gray_encode(symbols);
    n       = 4 + CR;
    nBlocks = numel(symbols) / n;
    assert(nBlocks == round(nBlocks) && nBlocks > 0, ...
           'Number of symbols (%d) is not a multiple of %d (4+CR)', numel(symbols), n);
    
    cw = zeros(nBlocks * SF, n);                     % all codewords, one per row
    for blk = 1:nBlocks
        idx  = (blk - 1) * n + (1:n);                % this block's n symbols
        v    = values(idx);
        S    = mod(floor(v(:) ./ 2.^(0:SF-1)), 2);   % n x SF bits
        C    = deinterleave(S);                      % SF x n: SF codewords
        rows = (blk - 1) * SF + (1:SF);              % this block's rows in cw
        cw(rows, :) = C;
    end
    
    [nib, st.nCorrected, st.nDetected] = hamming_decode(cw, CR);
end