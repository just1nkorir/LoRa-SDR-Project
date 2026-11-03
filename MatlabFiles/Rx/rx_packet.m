function out = rx_packet(iq, cfg)
% RX_PACKET  One aligned, CFO-corrected packet -> payload bytes + checks.
%
%   out = rx_packet(iq, cfg)          cfg with OSR = 1
%     iq  : samples at 1 sample/chip, starting EXACTLY at the first
%           preamble chirp, with the CFO already removed
%     out : .hdrOk      header valid
%           .crcOk      payload CRC matches (the packet is good)
%           .payload    decoded bytes ([] if the header failed)
%           .hdr        header fields (.payloadLen, .CR, .crcOn)
%           .symbols    all detected symbols (header + payload)
%           .nCorrected Hamming corrections (header + payload)
%
% STEPS (tx_packet in reverse)
%   1. skip preamble + sync
%   2. header: demodulate -> decode (CR 4) -> bytes -> parse; stop if invalid
%   3. payload size FROM THE HEADER (length, CR), not from cfg
%   4. payload: demodulate -> decode (header's CR) -> bytes
%   5. de-whiten the payload (not the CRC), recompute and compare the CRC

    out = struct('hdrOk', false, 'crcOk', false, 'payload', [], 'hdr', [], ...
                 'symbols', [], 'nCorrected', 0);
    assert(cfg.OSR == 1, 'rx_packet expects 1 sample per chip (cfg.OSR = 1)');
    iq = iq(:);
    
    % 1. skip preamble + sync
    pos = (cfg.preambleLen + cfg.nSyncDown) * cfg.N;
    iq  = iq(pos+1 : end);
    
    % 2. header
    hdrSym = lora_demodulate(iq, cfg.nHdrSym, cfg);
    [hnib, st1] = decode_section(hdrSym, 4, cfg.SF);
    hbytes = nibbles2bytes(hnib(1:6));
    [hdr, ok] = parse_header(hbytes);
    out.hdr        = hdr;
    out.hdrOk      = ok;
    out.symbols    = hdrSym;
    out.nCorrected = st1.nCorrected;
    if ~ok
        return                                      % can't trust length or CR
    end
    
    % 3. payload size from the header
    nBytes  = hdr.payloadLen + 2 * hdr.crcOn;        % payload (+ 2 CRC bytes)
    nNib    = 2 * nBytes;
    nPaySym = ceil(nNib / cfg.SF) * (4 + hdr.CR);
    iq = iq(cfg.nHdrSym * cfg.N + 1 : end);          % drop the header samples
    if numel(iq) < nPaySym * cfg.N
        return                                      % packet cut short
    end
    
    % 4. payload
    paySym = lora_demodulate(iq, nPaySym, cfg);
    [pnib, st2] = decode_section(paySym, hdr.CR, cfg.SF);
    bytes = nibbles2bytes(pnib(1:nNib));             % drop the padding
    out.symbols    = [hdrSym, paySym];
    out.nCorrected = st1.nCorrected + st2.nCorrected;
    
    % 5. de-whiten, check CRC
    payload = whiten(bytes(1:hdr.payloadLen));       % de-whiten = whiten again
    if hdr.crcOn
        crcRx     = bytes(end-1) + 256 * bytes(end); % low + 256 x high
        out.crcOk = (crcRx == crc16(payload));
    else
        out.crcOk = true;
    end
    out.payload = payload;
end