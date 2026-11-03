function [res, summary] = process_capture(x, cfg)
% PROCESS_CAPTURE  Raw capture -> one result row per packet + a session summary.
%
%   [res, summary] = process_capture(x, cfg)        cfg at the capture's OSR (8)
%     x       : raw complex capture at cfg.fs
%     res     : struct array, one element per detected packet:
%               .t_s            packet start time in the capture (s)
%               .seq            sequence number (NaN unless the CRC passed)
%               .hdrOk / .crcOk header valid / packet correct
%               .bitErr / .bits / .BER   bit errors in the known payload part
%               .nCorrected     Hamming corrections
%               .SNR_dB .RSSI_dBFS .sigPow_dBFS .RSSI_dBm .noise_dBFS
%               .CFO_Hz .syncScore
%     summary : counts, sequence range, PER, BER, mean SNR/RSSI/CFO
%
% PIPELINE
%   rx_frontend -> detect_packets -> noise floor (gaps between packets)
%   per packet: ghost check -> align (every OSR-th sample from the exact
%   start) -> remove CFO -> rx_packet -> payload_ber -> packet_metrics
%
% GHOSTS: runs of repeated data symbols inside a packet can be detected as
% packets. Once a packet's header decodes, detections that start before its
% end are ignored (summary.nGhost counts them).
%
% DEFINITIONS (for the methodology section)
%   PER = 1 - (CRC-good packets) / (last seq - first seq + 1)
%   BER = total bit errors / total bits, over packets with a valid header
%   SNR, RSSI, CFO: means over CRC-good packets
    N = cfg.N;
    OSR = cfg.OSR;
    P = cfg.preambleLen;
    sps = cfg.sps;
    c1 = cfg;
    c1.OSR = 1;
    c1 = finalize_cfg(c1);
    xf = rx_frontend(x, cfg);
    pk = detect_packets(xf, cfg);
    noise_dBFS = noise_floor(xf, [pk.start], cfg);

    res = struct('t_s',{}, 'seq',{}, 'hdrOk',{}, 'crcOk',{}, 'bitErr',{}, 'bits',{}, ...
             'BER',{}, 'nCorrected',{}, 'SNR_dB',{}, 'RSSI_dBFS',{}, ...
             'sigPow_dBFS',{}, 'RSSI_dBm',{}, 'noise_dBFS',{}, 'CFO_Hz',{}, ...
             'syncScore',{});

    Lmax = (cfg.nSym + 8) * N;
    busyUntil = 0;
    nGhost = 0;
    for k = 1:numel(pk)
        s0 = pk(k).start;
        if s0 <= busyUntil
            nGhost = nGhost + 1;
            continue;
        end
        
        idx = s0 + (0:Lmax-1)*OSR;
        idx = idx(idx <= numel(xf));
        if s0 < 1 || numel(idx) < (P + cfg.nSyncDown + cfg.nHdrSym) * N
            continue                                      % cut off by the capture edge
        end

        y = xf(idx);
        y = y .* exp(-1j*2*pi*pk(k).cfo_Hz * (0:numel(y)-1).' /cfg.BW);

        out = rx_packet(y, c1);
        hdrOk = out.hdrOk && numel(out.payload) == cfg.payloadLen;

        r.t_s = (s0 - 1)/cfg.fs;
        r.seq = NaN;
        r.hdrOk = hdrOk;
        r.crcOk = hdrOk && out.crcOk;
        r.bitErr = NaN;
        r.bits = NaN;
        r.BER = NaN;
        nSym = cfg.nSym;
        
        if hdrOk
            [r.bitErr, r.bits] = payload_ber(out.payload, cfg);
            r.BER     = r.bitErr / r.bits;
            nSym      = P + cfg.nSyncDown + numel(out.symbols);
            busyUntil = s0 + nSym * sps;                 % detections before this are ghosts
        end
        if r.crcOk
            r.seq = out.payload(1) + 256 * out.payload(2);
        end

        r.nCorrected = out.nCorrected;
        m = packet_metrics(xf, y, s0, nSym, noise_dBFS, cfg);
        r.SNR_dB      = m.SNR_dB;
        r.RSSI_dBFS   = m.RSSI_dBFS;
        r.sigPow_dBFS = m.sigPow_dBFS;
        r.RSSI_dBm    = m.RSSI_dBm;
        r.noise_dBFS  = noise_dBFS;
        r.CFO_Hz      = pk(k).cfo_Hz;
        r.syncScore   = pk(k).score;
        res(end+1) = r;
    end
    summary = summarize(res, nGhost, noise_dBFS, numel(x) / cfg.fs);     % Part 5
end

function nf = noise_floor(xf, starts, cfg)
    sps  = cfg.sps;
    nBlk = floor(numel(xf) / sps);
    blkP = mean(abs(reshape(xf(1:nBlk*sps), sps, nBlk)).^2, 1);    % power of each block
    busy = false(1, nBlk);
    for s = starts
        b1 = floor((s - 1) / sps);                       % 1 block margin before
        b2 = ceil((s + cfg.nSym*sps) / sps) + 1;         % and after
        busy(max(1, b1) : min(nBlk, b2)) = true;
    end
    if sum(~busy) >= 4
        nf = 10*log10(median(blkP(~busy)) + eps);
    else
        nf = NaN;                                        % no quiet gaps to measure
    end
end

function sm = summarize(res, nGhost, noise_dBFS, capture_s)
    sm.capture_s = capture_s;
    sm.nDetected = numel(res);
    sm.nGhost    = nGhost;
    sm.nHdrOk    = sum([res.hdrOk]);
    sm.nCrcOk    = sum([res.crcOk]);
    
    % PER from sequence numbers
    good = [res.crcOk];
    seqs = unique([res(good).seq]);                      % sorted, no repeats
    if isempty(seqs)
        sm.seqFirst = NaN;  sm.seqLast = NaN;  sm.nExpected = NaN;  sm.PER = NaN;
    else
        sm.seqFirst  = seqs(1);
        sm.seqLast   = seqs(end);
        sm.nExpected = seqs(end) - seqs(1) + 1;
        sm.PER       = 1 - numel(seqs) / sm.nExpected;
    end
    
    % BER: total errors / total bits, over packets with a good header
    hdr = [res.hdrOk];
    sm.bitErr = sum([res(hdr).bitErr]);
    sm.bits   = sum([res(hdr).bits]);
    if sm.bits > 0, sm.BER = sm.bitErr / sm.bits; else, sm.BER = NaN; end
    
    % means over good packets
    sm.SNR_mean_dB    = mean_or_nan([res(good).SNR_dB]);
    sm.RSSI_mean_dBFS = mean_or_nan([res(good).RSSI_dBFS]);
    sm.RSSI_mean_dBm  = mean_or_nan([res(good).RSSI_dBm]);
    sm.noise_dBFS     = noise_dBFS;
    sm.CFO_mean_Hz    = mean_or_nan([res(good).CFO_Hz]);
    if sum(good) > 1
        sm.CFO_std_Hz = std([res(good).CFO_Hz]);
    else
        sm.CFO_std_Hz = NaN;
    end
end

function v = mean_or_nan(x)
    if isempty(x)
        v = NaN; 
    else 
        v = mean(x); 
    end
end