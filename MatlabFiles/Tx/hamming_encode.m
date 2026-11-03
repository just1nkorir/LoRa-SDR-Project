function cw = hamming_encode(nib, CR)
% HAMMING_ENCODE  Add CR parity bits to every 4-bit nibble.
%
%   cw = hamming_encode(nib, CR)
%     nib : vector of nibbles (0..15)
%     CR  : 1..4 -> each codeword has 4 + CR bits
%     cw  : K x (4+CR) matrix of 0/1, one ROW per nibble:
%           [ d1 d2 d3 d4 | p1 .. pCR ]    (d1 = least significant bit)
%
%   Example:  hamming_encode(5, 3)  ->  [1 0 1 0 1 0 1]
%             5 = 0101 -> d = 1 0 1 0 (read from the right)
%             p1 = d1^d2^d4 = 1, p2 = d1^d3^d4 = 0, p3 = d2^d3^d4 = 1
%
% HOW
%   1. d: K x 4 matrix of data bits. Column i = bit i of every nibble.
%   2. p = mod(d * P, 2): ALL parity bits of ALL nibbles in one line.
%      d * P is a matrix product: entry (k,j) adds up the data bits of
%      nibble k that parity bit j uses (P has 1s exactly there).
%      mod 2 of a sum of bits = 1 if the sum is odd = XOR of those bits.
%   3. cw = [d, p]: data bits, then parity bits, side by side.
%
% The data bits stay unchanged in the codeword (a "systematic" code), so
% the receiver can read them directly and use the parity bits only to
% check and repair them.
%
% SYNTAX NOTES
%   - nib(:) makes a K x 1 column; bitget(x, i) is bit i of x (1 = lowest).
%   - d(:, i) = ... fills column i (":" = all rows).
%   - "*" is the MATRIX product (K x 4 times 4 x CR -> K x CR);
%     ".*" would multiply element by element - not what we want here.
%   - [d, p] joins matrices side by side (they need the same number of rows).

nib = double(nib(:));                       % K x 1, double
assert(all(nib >= 0 & nib <= 15 & nib == round(nib)), 'nibbles must be 0..15');
K   = numel(nib);

% 1. data bits
d = zeros(K, 4);
for i = 1:4
    d(:, i) = bitget(nib, i);               % bit i of every nibble
end

% 2. parity bits
P = hamming_parity_matrix(CR);              % 4 x CR
p = mod(d * P, 2);                          % K x CR

% 3. codewords
cw = [d, p];                                % K x (4+CR)
end
