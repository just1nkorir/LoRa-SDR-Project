function C = deinterleave(S)
% DEINTERLEAVE  Inverse of interleave.m.
%
%   C = deinterleave(S)
%     S : n x SF matrix, row j = bits of received symbol j
%     C : SF x n matrix, row r = codeword r
%
% We apply exactly the same index rule as the interleaver, but with the
% assignment reversed:  TX did  S(j,i) = C(r,j);  RX does  C(r,j) = S(j,i).
% Since that rule visits every (r, j) pair exactly once, this recovers C.
    [n, SF] = size(S);
    C = zeros(SF, n);
    for j = 1:n
        for i = 1:SF
            C(mod(i + j - 2, SF) + 1, j) = S(j, i);
        end
    end
end