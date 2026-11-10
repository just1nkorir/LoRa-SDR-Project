function main_rx()
% MAIN_RX  LoRa receiver: capture from the RX USRP, decode, measure, log.
%
%   Run on the RX PC while main_tx is sending:   main_rx
%   One run = one test point (one distance, one SF/BW/CR setting).
%
% WHAT IT DOES
%   1. captures cfg.sdr.captureSeconds of IQ samples from the radio
%   2. SAVES the raw capture to data/ - so it can be re-analysed later
%      (after a receiver fix) without repeating the field work
%   3. process_capture: detect every packet, decode, SNR/RSSI/CFO/BER/PER
%   4. appends one row per packet to data/packets.csv and one summary row
%      to data/sessions.csv, together with the metadata below
%   5. prints the summary, so you can judge the test point on the spot
%
% EDIT THE METADATA BLOCK BEFORE EVERY RUN - the CSV is only as useful as
% the notes in it (distance, site, heights, line of sight, ...).
%
% No radio at hand? Set useRadio = false: it builds a fake capture from the
% packets main_tx saved in its dry run (data/tx_dryrun.mat), adds a CFO
% and noise, and runs everything else exactly as with the radio.
%
% It is a function (not a script) so that onCleanup can release the radio
% even if you stop it with Ctrl+C or it crashes.

% ---- paths: common/ and rx/ next to this file -----------------------------
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'common'), fullfile(root, 'rx'));
    
% ==== PHY SETTINGS: MUST MATCH main_tx =======================================
    cfg = default_cfg();
    cfg.SF  = 7;
    cfg.BW  = 125e3;
    cfg.CR  = 1;                          % 1 = 4/5 ... 4 = 4/8
    cfg.sdr.rxGain = 10;                  % dB - keep FIXED for a whole series
    cfg.sdr.captureSeconds = 12;
    useRadio = true;                      % false = dry run from data/tx_dryrun.mat
    
% ==== METADATA FOR THIS TEST POINT (EDIT EVERY RUN) =========================
    meta.date        = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    meta.site        = 'lab';             % e.g. 'campus roof -> water tower'
    meta.distance_m  = 0;
    meta.tx_gain_dB  = 10;                % what main_tx used
    meta.rx_gain_dB  = cfg.sdr.rxGain;
    meta.los         = 1;                 % line of sight: 1 = yes, 0 = no
    meta.tx_height_m = NaN;
    meta.rx_height_m = NaN;
    meta.note        = 'bench test, cable + attenuators';
    % =============================================================================
    
    cfg.OSR = cfg.sdr.OSR;                % captures arrive at the radio rate (1 MHz)
    cfg = finalize_cfg(cfg);
    dataDir = fullfile(root, 'data');
    if ~exist(dataDir, 'dir'), mkdir(dataDir); end
    
    fprintf('\n=== LoRa RX ===\n');
    fprintf('SF%d, BW %g kHz, CR 4/%d, %.3f MHz, RX gain %g dB\n', cfg.SF, ...
            cfg.BW/1e3, 4 + cfg.CR, cfg.sdr.centerFreq/1e6, cfg.sdr.rxGain);
    
    % ---- 1. capture ---------------------------------------------------------------
    if useRadio
        [buf, nOver] = capture_radio(cfg);
    else
        [buf, nOver] = capture_dryrun(cfg, dataDir);
    end
    
    % ---- 2. save the raw capture ------------------------------------------------------
    fname = fullfile(dataDir, sprintf('cap_%s_SF%d_%gm.mat', ...
                     datestr(now, 'yyyymmdd_HHMMSS'), cfg.SF, meta.distance_m));
    save(fname, 'buf', 'cfg', 'meta');
    fprintf('Raw capture saved: %s\n', fname);
    
    % ---- 3. process ---------------------------------------------------------------------
    fprintf('Processing...\n');
    [res, sm] = process_capture(buf, cfg);
    
    % ---- 4. log ---------------------------------------------------------------------------
    meta.radio        = double(useRadio);
    meta.capture_file = fname;
    meta.overruns     = nOver;
    phy = struct('SF', cfg.SF, 'BW', cfg.BW, 'CR', cfg.CR, ...
                 'payloadLen', cfg.payloadLen, 'fc_Hz', cfg.sdr.centerFreq);
    for k = 1:numel(res)
        log_csv(fullfile(dataDir, 'packets.csv'), meta, phy, res(k));
    end
    log_csv(fullfile(dataDir, 'sessions.csv'), meta, phy, sm);
    
    % ---- 5. show ------------------------------------------------------------------------------
    print_summary(sm);
    if nOver > 0
        fprintf('WARNING: %d overruns - samples were dropped, some packets may be cut.\n\n', nOver);
    end
end

function [buf, nOver] = capture_radio(cfg)
% Collect cfg.sdr.captureSeconds of samples, frame by frame, from the USRP.
    rx = sdr_make_rx(cfg);
    cleanup = onCleanup(@() release_radio(rx)); %#ok<NASGU>  runs on exit / Ctrl+C
    
    Ncap = round(cfg.sdr.captureSeconds * cfg.fs);
    buf  = complex(zeros(Ncap, 1, 'single'));        % single: half the memory of double
    idx  = 1;
    nOver = 0;
    fprintf('Capturing %.1f s from %s ...\n', cfg.sdr.captureSeconds, cfg.sdr.rxIP);
    while idx <= Ncap
        [d, len, over] = rx();
        nOver = nOver + double(over);
        if len > 0                                   % the first calls can return nothing
            n = min(len, Ncap - idx + 1);            % don't overfill the buffer
            buf(idx : idx+n-1) = d(1:n);
            idx = idx + n;
        end
    end
    fprintf('Capture done (%d overruns).\n', nOver);
end

function [buf, nOver] = capture_dryrun(cfg, dataDir)
% Fake capture from main_tx's dry-run packets: random start, CFO, noise.
    f = fullfile(dataDir, 'tx_dryrun.mat');
    assert(exist(f, 'file') == 2, 'No %s - run main_tx with useRadio = false first', f);
    d = load(f);
    assert(d.cfg.SF == cfg.SF && d.cfg.CR == cfg.CR && d.cfg.BW == cfg.BW, ...
           'tx_dryrun.mat was made with different SF/BW/CR than main_rx uses');
    x = double(cell2mat(d.dryFrames(:)));
    x = x(round(0.3 * numel(d.dryFrames{1})) : end);          % start mid-packet, like a real RX
    cfo = -90;  snr_dB = 60;                                % made-up but realistic
    x = x .* exp(1j*2*pi*cfo*(0:numel(x)-1).' / cfg.fs);
    nVar = cfg.OSR * cfg.sdr.amplitude^2 / 10^(snr_dB/10);     % noise power over the full 1 MHz
    x = x + sqrt(nVar/2) * (randn(size(x)) + 1j*randn(size(x)));
    buf = single(0.05 * x);                                   % arbitrary level, like a real capture
    nOver = 0;
    fprintf('DRY RUN: fake capture of %.1f s (CFO %g Hz, SNR %g dB)\n', ...
            numel(buf)/cfg.fs, cfo, snr_dB);
end

function release_radio(rx)
    release(rx);
    fprintf('Radio released.\n');
end