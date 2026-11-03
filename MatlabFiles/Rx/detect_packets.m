function pk = detect_packets(xf, cfg)
% DETECT_PACKETS  Find every LoRa packet in a capture: start sample and CFO.
%
%   pk = detect_packets(xf, cfg)          cfg at the capture's OSR (8)
%     xf : filtered capture at the full rate (from rx_frontend)
%     pk : struct array, one element per packet found, in time order:
%          pk(k).start   full-rate sample index of the FIRST preamble sample
%          pk(k).cfo_Hz  carrier frequency offset (RX - TX), Hz
%          pk(k).score   sync quality (bigger = more convincing)
%     numel(pk) = number of packets; [pk.start] = all starts as one row.
%
% THE PIPELINE
%   1. xd = every OSR-th sample of xf -> 1 sample per chip (any phase is
%      fine here; sync_packet finds the exact timing later)
%   2. scan_windows : dechirp + FFT of every 1-symbol window
%                     -> peak bin and peak/average ratio per window
%   3. find_runs    : >= cfg.rx.minRun strong windows in the same bin
%                     = candidate preambles
%   4. sync_packet  : for each run, the up/down-chirp trick gives the exact
%                     start and the CFO; runs without an SFD, or with a
%                     weak sync score, are rejected (ok = false)
%   5. remove duplicates: one preamble split into two runs gives two
%      detections less than half a symbol apart -> keep the better score
%
% NOT HANDLED HERE: "ghosts" - runs of repeated DATA symbols inside a real
% packet can look like a preamble + SFD. They are removed in
% process_capture: once a packet decodes, detections inside it are ignored.
%
% SETTINGS (cfg.rx): detZeroPad, detThresh, minRun, syncThresh
%
% SYNTAX NOTES
%   - struct('start', {}, ...) : a struct array with ZERO elements but these
%     fields, so "no packets found" is still a valid result.
%   - pk(end+1) = struct(...) appends one element.
%   - size(runs, 1) is the number of rows (= number of runs).
%   - [~, order] = sort(v) : the order that sorts v; pk(order) reorders pk.
%   - find(v, 1, 'last') : position of the last true element of v.
%   - pk(keep) with a true/false row keeps the "true" elements
%     (logical indexing).

    pk = struct('start', {}, 'cfo_Hz', {}, 'score', {});
    
    % 1. 1 sample per chip + reference downchirp
    c1  = cfg;
    c1.OSR = 1;
    c1  = finalize_cfg(c1);
    dn1 = conj(lora_chirp(0, c1));
    xd  = xf(1 : cfg.OSR : end);
    
    % 2-3. coarse scan, candidate preambles
    [bin, ratio] = scan_windows(xd, dn1, cfg.rx.detZeroPad);
    runs = find_runs(bin, ratio, cfg.N, cfg.rx.detThresh, cfg.rx.minRun);
    
    % 4. sync each run, keep the real packets
    for k = 1:size(runs, 1)
        [s0, cfo, sc, ok] = sync_packet(xf, xd, runs(k, :), ratio, cfg);
        if ok
            pk(end + 1) = struct('start', s0, 'cfo_Hz', cfo, 'score', sc); %#ok<AGROW>
        end
    end
    
    % 5. remove duplicates (same packet found twice)
    if numel(pk) > 1
        [~, order] = sort([pk.start]);           % time order
        pk   = pk(order);
        keep = true(1, numel(pk));
        for i = 2:numel(pk)
            j = find(keep(1:i-1), 1, 'last');    % the last packet still kept
            if abs(pk(i).start - pk(j).start) < cfg.sps / 2
                if pk(i).score > pk(j).score
                    keep(j) = false;             % new one is better: drop the old
                else
                    keep(i) = false;             % old one is better: drop the new
                end
            end
        end
        pk = pk(keep);                           % keep the "true" ones
    end
end