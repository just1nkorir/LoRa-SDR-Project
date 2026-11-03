function [hdr, ok] = parse_header(bytes)
% PARSE_HEADER  3 header bytes -> fields + validity check (mirror of build_header).
%   [hdr, ok] = parse_header(bytes)
%     bytes : [length, flags, checksum]
%     hdr   : .payloadLen, .CR (1..4), .crcOn (true/false)
%     ok    : true if the checksum matches AND the fields make sense
%   parse_header([16 17 33])  ->  payloadLen 16, CR 1, crcOn true, ok true

    hdr.payloadLen = bytes(1);
    hdr.CR         = bitand(bytes(2), 7);          % bits 0-2
    hdr.crcOn      = bitand(bytes(2), 16) > 0;     % bit 4 -> true/false
    ok = (mod(bytes(1) + bytes(2), 256) == bytes(3)) && ...
         hdr.CR >= 1 && hdr.CR <= 4 && hdr.payloadLen >= 1;
end