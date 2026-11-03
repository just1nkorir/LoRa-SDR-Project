function [nib, nCorrected, nDetected] = hamming_decode(cw, CR)
% HAMMING_DECODE  (4+CR)-bit codewords -> nibbles, correcting errors where possible.
%
%   [nib, nCorrected, nDetected] = hamming_decode(cw, CR)
%     cw         : K x (4+CR) matrix of bits [d1..d4 p1..pCR], one codeword per row
%     nib        : 1 x K nibbles (0..15)
%     nCorrected : codewords that had one bit flipped back
%     nDetected  : codewords with an error that could NOT be fixed
%
% THE SYNDROME
%   Recompute the parity bits from the received data bits and compare them
%   with the received parity bits:
%       syndrome = received parity XOR recomputed parity      (1 x CR bits)
%   - all zeros        -> no error seen
%   - matches the "signature" of one bit (CR 3, 4) -> that bit is wrong: flip it
%   - anything else    -> error detected, cannot correct
%
% SIGNATURES (the columns of H = [P.', eye(CR)])
%   The syndrome a single error at bit i would cause:
%   - data bit i flipped   -> breaks the parity checks that use it = row i of P
%   - parity bit j flipped -> breaks only check j = a single 1 at position j
%   CR 3: d1=110 d2=101 d3=011 d4=111 p1=100 p2=010 p3=001 (all different)
%   CR 1, 2: signatures are not all different, so we only detect.
%   CR 4: a double error gives a syndrome that matches no signature, so it is
%   detected instead of being "fixed" into the wrong nibble.
%
% SYNTAX NOTES
%   - eye(CR) is the CR x CR identity matrix (1s on the diagonal).
%   - H(:, i).' takes column i of H and makes it a row (same shape as s).
%   - isequal(a, b) is true if both have the same size and values.
%   - any(s) is true if s has at least one non-zero element.
%   - 1 - c(i) flips a bit (1 -> 0, 0 -> 1).
%   - break leaves the innermost for loop early.
%   - c(1:4) * [1; 2; 4; 8] turns the 4 data bits into the nibble value.

    P = hamming_parity_matrix(CR);
    H = [P.', eye(CR)];                 % CR x (4+CR): column i = signature of bit i
    K = size(cw, 1);
    nib = zeros(1, K);
    nCorrected = 0;
    nDetected  = 0;
    
    for k = 1:K
        c = cw(k, :);
        d = c(1:4);
        s = mod(c(5:end) + d * P, 2);   % syndrome: received XOR recomputed parity
        if any(s)
            fixed = false;
            if CR >= 3
                for i = 1:(4 + CR)
                    if isequal(s, H(:, i).')
                        c(i)  = 1 - c(i);   % flip the faulty bit
                        fixed = true;
                        break
                    end
                end
            end
            if fixed
                nCorrected = nCorrected + 1;
            else
                nDetected = nDetected + 1;
            end
        end
        nib(k) = c(1:4) * [1; 2; 4; 8];    % (corrected) data bits -> nibble
    end
end