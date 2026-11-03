function bytes = nibbles2bytes(nib)
% NIBBLES2BYTES  Pairs of nibbles (low first) -> bytes. Inverse of bytes2nibbles.
%
%   bytes = nibbles2bytes(nib)
%     nib   : row of nibbles (0..15) in pairs: low, high, low, high, ...
%             (the order bytes2nibbles produces, as in LoRa)
%     bytes : row of bytes (0..255), half as many
%
%   Example:  nibbles2bytes([11 10 2 1])  ->  [171 18]   (B A 2 1 -> 0xAB 0x12)
%
% USED AT THE RECEIVER after decode_section, to turn the decoded nibbles
% of the header and the payload back into bytes.
%
% HOW
%   Each byte = high nibble in bits 4-7, low nibble in bits 0-3:
%       0xAB = 1010 1011 = (A << 4) | B
%   The odd positions nib(1:2:end) are the low nibbles (kept as they are);
%   the even positions nib(2:2:end) are the high nibbles (shifted up by 4).
%   The two halves never overlap, so bitor just puts them side by side
%   (the same as low + 16*high).
%
% SYNTAX NOTES
%   - nib(1:2:end) : every second element starting at 1 (positions 1,3,5,...);
%     nib(2:2:end) : positions 2,4,6,...  ("end" = last position)
%   - bitshift(x, 4) shifts left by 4 bits (= multiply by 16).
%   - bitor(a, b)   : bitwise OR, a bit is 1 if it is 1 in a OR in b.
%   - mod(numel(nib), 2) == 0 checks the count is even (no half bytes).

nib = double(nib(:).');                                   % row, double
assert(mod(numel(nib), 2) == 0, 'Need an even number of nibbles (got %d)', numel(nib));
bytes = bitor(bitshift(nib(2:2:end), 4), nib(1:2:end));   % high << 4 | low
end