function [symbols, info] = tx_packet(payload, cfg)
% TX_PACKET  Payload bytes -> all symbols of one packet (header + payload).
%   [symbols, info] = tx_packet(make_test_payload(0, cfg), cfg)
%   symbols: header symbols (CR 4/8) followed by payload+CRC symbols (cfg.CR)
%   info:    intermediate results, for debugging

    payload = double(payload(:).');
    
    % 1-2. CRC on the ORIGINAL payload, low byte first
    if cfg.crcOn
        crc      = crc16(payload);
        crcBytes = [mod(crc, 256), floor(crc / 256)];
    else
        crc      = [];
        crcBytes = [];
    end
    
    % 3-4. whiten the payload (not the CRC), then append the CRC
    whitened  = whiten(payload);
    dataBytes = [whitened, crcBytes];
    
    % 5. header
    hdr = build_header(numel(payload), cfg);
    
    % 6. encode both sections (header always CR 4/8)
    hdrSymbols = encode_section(bytes2nibbles(hdr),       4,      cfg.SF);
    paySymbols = encode_section(bytes2nibbles(dataBytes), cfg.CR, cfg.SF);
    
    % 7. join
    symbols = [hdrSymbols, paySymbols];
    
    % 8. debug info
    info.crc        = crc;
    info.whitened   = whitened;
    info.dataBytes  = dataBytes;
    info.hdr        = hdr;
    info.hdrSymbols = hdrSymbols;
    info.paySymbols = paySymbols;
end