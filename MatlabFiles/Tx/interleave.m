function S = interleave(C)
% INTERLEAVE  Diagonal interleaver for one block of LoRa codewords.
%
%   S = interleave(C)
%     C : SF x n matrix of bits. Row r = codeword r (n = 4+CR bits each).
%         One block = SF codewords (from SF nibbles).
%     S : n x SF matrix of bits. Row j = the SF bits of transmitted symbol j.
%         So one block of SF codewords becomes n symbols.
%
% WHY INTERLEAVE?
%   A LoRa demodulation error is a WHOLE symbol going wrong (the FFT peak
%   lands in the wrong bin), which corrupts several of its SF bits at once.
%   If those bits all came from the same codeword, the Hamming code (which
%   fixes only 1 bit per codeword) could not repair it. The interleaver
%   gives every symbol exactly ONE bit from EACH codeword, so one bad
%   symbol costs each codeword at most one bit - which CR 4/7 and 4/8 fix.
%
% THE RULE (diagonal / cyclic shift)
%   Symbol j takes bit j of every codeword, starting at codeword j and
%   wrapping around:
%       S(j, i) = C( mod(i + j - 2, SF) + 1 , j )
%   ("-2" and "+1" only because MATLAB counts from 1. In 0-based maths:
%    S[j][i] = C[(i + j) mod SF][j].)
%
%   Picture for SF = 4, n = 5 (letter = codeword, digit = bit number):
%       C = A1 A2 A3 A4 A5          symbol 1 = A1 B1 C1 D1
%           B1 B2 B3 B4 B5          symbol 2 = B2 C2 D2 A2   (rotated by 1)
%           C1 C2 C3 C4 C5          symbol 3 = C3 D3 A3 B3   (rotated by 2)
%           D1 D2 D3 D4 D5          symbol 4 = D4 A4 B4 C4   (rotated by 3)
%                                   symbol 5 = A5 B5 C5 D5   (rotated by 4 = 0)
%   COLUMN j of C (bit j of every codeword) becomes ROW j of S (symbol j),
%   rotated by j-1. The rotation makes the bits of one codeword land at
%   different positions inside different symbols ("diagonal").
%
% NOTE: real LoRa uses the same idea with a slightly different bit order,
% so this is not yet bit-exact with a commercial chip.
%
% SYNTAX NOTES
%   - [SF, n] = size(C) puts the two dimensions of C into two variables.
%   - zeros(n, SF) pre-allocates the output (faster than growing it).
%   - mod(i + j - 2, SF) + 1 wraps the row index around: after row SF
%     comes row 1 again.

[SF, n] = size(C);
S = zeros(n, SF);
for j = 1:n                  % symbol j  <-  bit j of the codewords
    for i = 1:SF             % position i inside symbol j
        r = mod(i + j - 2, SF) + 1;    % which codeword supplies it
        S(j, i) = C(r, j);
    end
end
end
