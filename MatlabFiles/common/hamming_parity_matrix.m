function P = hamming_parity_matrix(CR)
% HAMMING_PARITY_MATRIX  Which data bits feed which parity bit (4 x CR).
%
%   P = hamming_parity_matrix(CR)      CR = 1..4  (code rate 4/(4+CR))
%
%   Rows    = data bits d1..d4   (d1 = least significant bit of the nibble)
%   Columns = parity bits p1..pCR
%   P(i,j) = 1  means  data bit i is XOR-ed into parity bit j.
%
%   CR 1 (4/5): p1 = d1^d2^d3^d4                       detects 1 error
%   CR 2 (4/6): p1 = d1^d2^d3,  p2 = d2^d3^d4          detects errors
%   CR 3 (4/7): p1 = d1^d2^d4,  p2 = d1^d3^d4,
%               p3 = d2^d3^d4  (Hamming(7,4))          corrects 1 error
%   CR 4 (4/8): CR 3 + p4 = d1^d2^d3                   corrects 1, detects 2
%
% Shared by hamming_encode (TX) and hamming_decode (RX), so the two can
% never disagree about the rules.
%
% WHY THESE GROUPS (CR 3)
%   Each data bit is in a DIFFERENT combination of at least two parity
%   groups:   d1 -> p1,p2    d2 -> p1,p3    d3 -> p2,p3    d4 -> p1,p2,p3
%   So if one data bit flips, the set of parity checks that fail is unique
%   to that bit - the receiver can tell WHICH bit flipped and flip it back.
%   (A flipped parity bit makes only its own check fail.)
%
% SYNTAX NOTES
%   - Each line inside [ ... ] below is the list of data bits used by ONE
%     parity bit (easy to compare with the rules above). ".'" then
%     transposes, so each of those lines becomes a COLUMN of P.
%   - switch / case runs the branch whose value matches CR.
%   - P4(:, 1:3) : all rows (":"), columns 1 to 3.

%        d1 d2 d3 d4
P4 = [   1  1  0  1;      % p1 = d1 ^ d2 ^ d4
         1  0  1  1;      % p2 = d1 ^ d3 ^ d4
         0  1  1  1;      % p3 = d2 ^ d3 ^ d4
         1  1  1  0 ].';  % p4 = d1 ^ d2 ^ d3

switch CR
    case 1
        P = [1 1 1 1].';              % p1 = d1 ^ d2 ^ d3 ^ d4
    case 2
        P = [1 1 1 0;                 % p1 = d1 ^ d2 ^ d3
             0 1 1 1].';              % p2 = d2 ^ d3 ^ d4
    case 3
        P = P4(:, 1:3);
    case 4
        P = P4;
    otherwise
        error('CR must be 1..4 (got %g)', CR);
end
end
