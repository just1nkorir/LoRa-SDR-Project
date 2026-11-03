function [symbols, dbg] = encode_section(nib, CR, SF)
% ENCODE_SECTION  Nibbles -> LoRa symbol values (Hamming, interleave, Gray).
%
%   symbols = encode_section(nib, CR, SF)
%     nib     : row of nibbles (0..15), any number of them
%     CR      : coding rate index 1..4 (codewords of 4+CR bits)
%     SF      : spreading factor (bits per symbol)
%     symbols : row of symbol values 0..2^SF-1, ready for lora_chirp
%     dbg     : intermediate results, for checking and teaching
%
%   Example:  encode_section([5 12 7 0 15 9 3], 1, 7)  ->  [89 51 70 59 63]
%
% Used twice per packet: once for the header (always CR = 4, the strongest
% code) and once for the payload + CRC (cfg.CR). That is why CR and SF are
% inputs instead of being read from cfg.
%
% THE FIVE STEPS
%   1. Pad with zero nibbles to a whole number of blocks. The interleaver
%      takes exactly SF codewords at a time, so the count must be a
%      multiple of SF:   nBlocks = ceil(K / SF)
%   2. Hamming-encode every nibble:   (nBlocks*SF) x n bit matrix, n = 4+CR
%   3. For each block of SF codewords: interleave -> n x SF bits
%      (n symbols of SF bits each)
%   4. Turn each symbol's SF bits into a number. Bit position 1 is the
%      least significant (weights 1, 2, 4, ..., 2^(SF-1)).
%   5. gray_decode every value -> the symbol actually sent. (The receiver
%      applies gray_encode, so a one-bin error costs only one bit.)
%
%   Size: nBlocks blocks x n symbols = nBlocks*(4+CR) symbols in total.
%   16-byte payload + 2 CRC bytes = 36 nibbles at SF7, CR 4/5:
%   ceil(36/7) = 6 blocks x 5 = 30 symbols.
%
% SYNTAX NOTES
%   - [nib, zeros(1, m)] appends m zeros to the end of the row nib.
%   - cw(rows, :) takes the listed rows and all columns.
%   - S * weights is a matrix product: (n x SF) * (SF x 1) = n x 1, so
%     entry j = sum over i of S(j,i) * 2^(i-1) = symbol j's bits as a number.
%   - values(idx) = ... writes into the listed positions of values.

n       = 4 + CR;
nib     = double(nib(:).');                          % row, double
K       = numel(nib);
nBlocks = ceil(K / SF);

% 1. pad
nib = [nib, zeros(1, nBlocks*SF - K)];

% 2. Hamming
cw = hamming_encode(nib, CR);                        % (nBlocks*SF) x n

% 3 + 4. interleave each block, bits -> numbers
weights = (2.^(0:SF-1)).';                           % SF x 1: [1; 2; 4; ...]
values  = zeros(1, nBlocks * n);                     % pre-allocate
for blk = 1:nBlocks
    rows = (blk-1)*SF + (1:SF);                      % codewords of this block
    S    = interleave(cw(rows, :));                  % n x SF bits
    idx  = (blk-1)*n + (1:n);                        % where its n symbols go
    values(idx) = (S * weights).';                   % n numbers, as a row
end

% 5. Gray
symbols = gray_decode(values);

dbg.paddedNibbles = nib;
dbg.codewords     = cw;
dbg.values        = values;                          % before Gray
end