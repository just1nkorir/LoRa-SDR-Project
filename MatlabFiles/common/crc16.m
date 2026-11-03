function crc = crc16(bytes)
    poly = hex2dec('1021');
    crc  = hex2dec('FFFF');
    bytes = double(bytes(:).');

    for k = 1:numel(bytes)
        crc = bitxor(crc, bitshift(bytes(k), 8));
        for b = 1:8
            if bitand(crc, 32768)
                crc = bitxor(bitand(bitshift(crc, 1), 65535), poly);
            else
                crc = bitand(bitshift(crc, 1), 65535);
            end
        end
    end
end