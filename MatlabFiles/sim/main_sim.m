function main_sim()
% MAIN_SIM  Whole system on one computer: TX -> simulated channel -> RX.
%
%   Run from anywhere:   main_sim
%
% For each SF and each SNR in the settings below it
%   1. builds a fake USRP capture: nPkts numbered packets (made with the
%      real TX functions) at random gaps, two packets left out on purpose,
%      a carrier frequency offset, and noise at a KNOWN SNR;
%   2. runs the real receiver on it (process_capture, exactly as main_rx);
%   3. compares with the truth: estimated vs true SNR and CFO, PER, BER.
%
% Results go to data/sim_results.csv (one row per SF/SNR point) and, if
% makePlots = true, two figures:
%   - PER vs SNR per SF        -> receiver sensitivity (compare with the
%                                 LoRa limits: about -7.5 dB SF7,
%                                 -12.5 dB SF9, -20 dB SF12)
%   - estimated vs true SNR    -> validation of the SNR measurement
% Both are the "validate the metrics under known conditions" result for
% the report (plan week 5, Thursday).
%
% Run it again after ANY change to the receiver.
% The PER floor is numel(drop)/nPkts: those packets were never sent.

% ---- paths: common/, tx/, rx/ one level up ----------------------------------
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'common'), fullfile(root, 'tx'), fullfile(root, 'rx'));

% ==== SETTINGS ================================================================
tests = { 7, [5 0 -5 -7 -9];          % SF, list of SNRs (dB) to simulate
          9, [0 -10 -12 -14];
         12, [-15 -18 -20] };
CR        = 1;                        % coding rate index (1 = 4/5)
nPkts     = 12;                       % packets "sent" per point (seq 0..nPkts-1)
drop      = [4 9];                    % seq numbers left out on purpose
cfo_Hz    = 2345;                     % applied carrier frequency offset
makePlots = true;
% ===============================================================================

dataDir = fullfile(root, 'data');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end
outFile = fullfile(dataDir, 'sim_results.csv');

fprintf('\n%4s %8s %8s %6s %6s %7s %9s %9s\n', ...
        'SF', 'SNR_true', 'SNR_est', 'found', 'crcOK', 'PER', 'BER', 'CFO_est');
allRows = [];
for t = 1:size(tests, 1)
    cfg = default_cfg();
    cfg.SF  = tests{t, 1};
    cfg.CR  = CR;
    cfg.OSR = cfg.sdr.OSR;            % like the USRP: 1 MHz
    cfg = finalize_cfg(cfg);
    for snr = tests{t, 2}
        x = sim_capture(cfg, nPkts, snr, cfo_Hz, drop);
        [~, sm] = process_capture(x, cfg);
        fprintf('%4d %8.1f %8.2f %6d %6d %7.3f %9.2e %9.1f\n', cfg.SF, snr, ...
                sm.SNR_mean_dB, sm.nDetected, sm.nCrcOk, sm.PER, sm.BER, sm.CFO_mean_Hz);
        row = struct('date', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
                     'SF', cfg.SF, 'CR', cfg.CR, 'SNR_true_dB', snr, ...
                     'SNR_est_dB', sm.SNR_mean_dB, 'CFO_true_Hz', cfo_Hz, ...
                     'CFO_est_Hz', sm.CFO_mean_Hz, 'nSent', nPkts - numel(drop), ...
                     'nDetected', sm.nDetected, 'nCrcOk', sm.nCrcOk, ...
                     'PER', sm.PER, 'BER', sm.BER);
        log_csv(outFile, row);
        allRows = [allRows, row]; %#ok<AGROW>
    end
end
fprintf('(PER floor %.3f: %d of %d packets left out on purpose)\n', ...
        numel(drop)/nPkts, numel(drop), nPkts);
fprintf('Results appended to %s\n', outFile);

if makePlots
    plot_results(allRows, drop, nPkts);
end
end

% =================================================================================
function x = sim_capture(cfg, nPkts, snr_dB, cfo_Hz, drop)
% Fake capture: numbered packets with random gaps, CFO, noise at snr_dB
% (in-band SNR: signal power / noise power in BW, like the receiver measures).
sps = cfg.sps;
x = zeros(3*sps, 1);                              % quiet lead-in
for s = 0:nPkts-1
    if any(s == drop), continue; end              % "lost" packet
    gap = randi([1 3]) * sps + randi(sps);        % not a whole number of symbols
    iq  = build_frame(tx_packet(make_test_payload(s, cfg), cfg), cfg);
    x   = [x; zeros(gap, 1); iq]; %#ok<AGROW>
end
x = [x; zeros(4*sps, 1)];
x = x .* exp(1j*2*pi*cfo_Hz*(0:numel(x)-1).' / cfg.fs);
nVar = cfg.OSR / 10^(snr_dB/10);                  % chirps have power 1; noise over fs
x = x + sqrt(nVar/2) * (randn(size(x)) + 1j*randn(size(x)));
x = single(0.05 * x);                             % arbitrary level, stored like a capture
end

function plot_results(rows, drop, nPkts)
SFs = unique([rows.SF]);
figure('Name', 'Simulation results');
subplot(1, 2, 1); hold on; grid on;
for sf = SFs
    r = rows([rows.SF] == sf);
    % PER of the packets actually sent (remove the deliberate drops)
    perSent = 1 - [r.nCrcOk] / (nPkts - numel(drop));
    plot([r.SNR_true_dB], max(perSent, 1e-3), '-o', 'DisplayName', sprintf('SF%d', sf));
end
set(gca, 'YScale', 'log'); ylim([1e-3 1]);
xlabel('true SNR (dB)'); ylabel('PER (sent packets)'); title('Sensitivity');
legend('Location', 'southwest');

subplot(1, 2, 2); hold on; grid on;
s = [rows.SNR_true_dB];
plot(s, [rows.SNR_est_dB], 'o');
plot([min(s) max(s)], [min(s) max(s)], 'k--');    % perfect estimate
xlabel('true SNR (dB)'); ylabel('estimated SNR (dB)'); title('SNR estimate');
end
