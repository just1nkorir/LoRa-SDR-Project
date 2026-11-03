function hdr = build_header(payloadLen, cfg)
% BUILD_HEADER  3-byte header: [length, flags, checksum].
%   byte 1: payload length (1..255)
%   byte 2: CR in bits 0-2, +16 if the CRC is on
%   byte 3: (byte1 + byte2) mod 256
%   build_header(16, default_cfg())  ->  [16 17 33]

    assert(payloadLen >= 1 && payloadLen <= 255, 'payloadLen must be 1..255');
    flags = cfg.CR + 16 * double(cfg.crcOn);
    hdr   = [payloadLen, flags, mod(payloadLen + flags, 256)];
end