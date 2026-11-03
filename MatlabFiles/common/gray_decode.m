function b = gray_decode(g)
% GRAY_DECODE  Gray code -> ordinary binary (inverse of gray_encode).
%
%   b = gray_decode(g)          works on a whole vector at once
%   gray_decode(0:7)  ->  [0 1 3 2 7 6 4 5]
%
% USED AT THE TRANSMITTER (the name describes the maths, not the side):
%   TX:  interleaver value v  --gray_decode-->  symbol s  (sent as a chirp)
%   RX:  detected symbol s'   --gray_encode-->  value v'  (to de-interleaver)
%   The RX step must be gray_encode, because only binary->Gray has the
%   property "neighbouring numbers -> one bit apart": a one-bin FFT error
%   (s' = s+-1) then costs ONE bit, which Hamming can fix. The TX applies
%   the inverse in advance, so that with no errors v' = v exactly.
%
% THE ALGORITHM
%   Each binary bit = XOR of the Gray bit at that position and ALL Gray bits
%   above it. Doing that for every bit at once:
%       b = g XOR (g>>1) XOR (g>>2) XOR (g>>3) XOR ...
%   Keep shifting right and XOR-ing in until the shifted value is zero.
%
%   Example g = 6 = 110:
%       b = 110
%       XOR 011 (g>>1)  -> 101
%       XOR 001 (g>>2)  -> 100
%       g>>3 = 000 -> stop.     b = 100 = 4.   Check: gray_encode(4) = 6.
%
% SYNTAX NOTES
%   - bitshift(x, -1) shifts every element RIGHT by one bit (x/2 rounded down).
%   - bitxor works element by element on whole vectors ("vectorised").
%   - while any(shift(:)) : keep looping while ANY element still has bits
%     left. ("while shift" on a vector would stop as soon as ONE element
%     reached zero - too early for the others.) Extra XORs with 0 change
%     nothing, so running until all are zero is safe.

g     = double(g);
b     = g;
shift = bitshift(g, -1);          % g >> 1
while any(shift(:))
    b     = bitxor(b, shift);     % XOR in the current shift
    shift = bitshift(shift, -1);  % then shift one more place
end
end
