function main_tx()
% MAIN_TX  LoRa transmitter: send numbered test packets from the TX USRP.
%
%   Run on the TX PC:   main_tx        (or press Run in the editor)
%   Stop early:         Ctrl+C         (the radio is still released safely)
%
% WHAT IT DOES
%   For seq = 0, 1, 2, ... until the time is up:
%       payload  = make_test_payload(seq)      sequence number + known bytes
%       symbols  = tx_packet(payload)          CRC, whitening, header, coding
%       iq       = build_frame(symbols)        preamble + sync + data chirps
%       send     [iq * amplitude ; silence]    one packet + a gap
%   Then it logs the session (settings, packets sent) to data/tx_sessions.csv.
%
% BEFORE RUNNING
%   - The PHY settings (SF, BW, CR) MUST be identical in main_rx.
%   - Check cfg.sdr.txIP and the frequency/power with your supervisor.
%   - Bench tests: TX -> cable -> attenuators (e.g. 60 dB) -> RX. Never
%     connect the two radios directly.
%   - No radio at hand? Set useRadio = false: it builds 20 packets without
%     sending, checks them, and saves them to data/tx_dryrun.mat (useful
%     later for testing the receiver in simulation).
%
% It is a function (not a script) so that onCleanup can release the radio
% even if you stop it with Ctrl+C or it crashes.

    % ---- paths: common/ and tx/ next to this file ----------------------------
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'common'), fullfile(root, 'tx'));
    
    % ==== SETTINGS FOR THIS RUN ================================================
    cfg = default_cfg();
    cfg.SF  = 7;                    % \
    cfg.BW  = 125e3;                %  > MUST match main_rx
    cfg.CR  = 1;                    % /   (1 = 4/5 ... 4 = 4/8)
    cfg.sdr.txGain = 10;            % dB - start low
    duration_s = 60;                % how long to keep sending
    maxPackets = Inf;               % or a number, e.g. 500, to stop earlier
    gap_s      = 0.05;              % silence between packets (s). Also gives the
                                    % receiver a quiet stretch to measure noise.
    useRadio   = true;              % false = dry run without the USRP
    % ===========================================================================
    
    cfg.OSR = cfg.sdr.OSR;          % build packets at the radio's rate (1 MHz)
    cfg = finalize_cfg(cfg);
    
    gap = zeros(round(gap_s * cfg.fs), 1);
    fprintf('\n=== LoRa TX ===\n');
    fprintf('SF%d, BW %g kHz, CR 4/%d, %d-byte payload, %.3f MHz\n', cfg.SF, ...
            cfg.BW/1e3, 4 + cfg.CR, cfg.payloadLen, cfg.sdr.centerFreq/1e6);
    fprintf('Packet %.1f ms + gap %.0f ms -> about %.1f packets/s\n', ...
            cfg.airtime_s*1e3, gap_s*1e3, 1/(cfg.airtime_s + gap_s));
    
    % ---- radio ------------------------------------------------------------------
    if useRadio
        tx = sdr_make_tx(cfg);
        cleanup = onCleanup(@() release_radio(tx)); %#ok<NASGU>  runs on exit/Ctrl+C
        fprintf('Radio %s ready, gain %g dB. Sending for %g s...\n', ...
                cfg.sdr.txIP, cfg.sdr.txGain, duration_s);
    else
        maxPackets = min(maxPackets, 20);
        dryFrames  = cell(1, maxPackets);
        fprintf('DRY RUN (no radio): building %d packets...\n', maxPackets);
    end
    
    % ---- transmit loop ------------------------------------------------------------
    seq = 0;  nUnder = 0;  t0 = tic;
    while seq < maxPackets && (~useRadio || toc(t0) < duration_s)
        payload = make_test_payload(seq, cfg);
        symbols = tx_packet(payload, cfg);
        iq      = build_frame(symbols, cfg);                 % |iq| = 1
        frame   = complex([iq * cfg.sdr.amplitude; gap]);    % scale, add silence
    
        if useRadio
            nUnder = nUnder + double(tx(frame));             % true = underrun
        else
            dryFrames{seq + 1} = single(frame);
        end
    
        seq = seq + 1;
        if mod(seq, 50) == 0
            fprintf('  %d packets sent (%.0f s)\n', seq, toc(t0));
        end
    end
    
    elapsed = toc(t0);
    fprintf('Done: %d packets (seq 0..%d) in %.1f s, %d underruns\n', ...
            seq, seq - 1, elapsed, nUnder);
    
    % ---- dry run: check and save ----------------------------------------------------
    dataDir = fullfile(root, 'data');
    if ~exist(dataDir, 'dir')
        mkdir(dataDir); 
    end

    if ~useRadio
        expected = numel(gap) + cfg.nSym * cfg.sps;
        assert(all(cellfun(@numel, dryFrames) == expected), 'frame length mismatch');
        assert(max(abs(dryFrames{1})) <= 1, 'samples exceed full scale');
        save(fullfile(dataDir, 'tx_dryrun.mat'), 'dryFrames', 'cfg', 'gap_s');
        fprintf('Dry run OK: %d frames of %d samples saved to data/tx_dryrun.mat\n', ...
                seq, expected);
    end
    
    % ---- log the session ----------------------------------------------------------------
    row = struct('date', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
                 'radio', double(useRadio), 'SF', cfg.SF, 'BW', cfg.BW, ...
                 'CR', cfg.CR, 'payloadLen', cfg.payloadLen, ...
                 'fc_Hz', cfg.sdr.centerFreq, 'txGain_dB', cfg.sdr.txGain, ...
                 'gap_s', gap_s, 'nPackets', seq, 'elapsed_s', elapsed, ...
                 'underruns', nUnder);
    log_csv(fullfile(dataDir, 'tx_sessions.csv'), row);
end

% ==============================================================================
function release_radio(tx)
    release(tx);
    fprintf('Radio released.\n');
end