function [res, sm] = reprocess_capture(fname, writeLog)
% REPROCESS_CAPTURE  Re-decode a saved capture - no radio needed.
%
%   reprocess_capture('data/cap_20261110_103000_SF7_500m.mat')
%   [res, sm] = reprocess_capture(fname)          % also return the results
%   reprocess_capture(fname, true)                % and log them (see below)
%
% Use it to:
%   - look at a capture again at your desk (e.g. one that failed in the field)
%   - recompute results after IMPROVING THE RECEIVER: every capture saved by
%     main_rx can be decoded again with the new code, without repeating the
%     field work
%
% RECEIVER SETTINGS: the capture's own cfg (SF, BW, CR, gains, ...) is used,
% but cfg.rx (detection/filter settings) is taken from the CURRENT
% default_cfg, so a tuned threshold takes effect on old captures too.
%
% LOGGING: off by default (just prints). With writeLog = true the rows go to
% data/packets_reprocessed.csv and data/sessions_reprocessed.csv - separate
% files, so the original field log is never duplicated or overwritten.

if nargin < 2
    writeLog = false;                     % nargin = number of inputs given
end

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'common'), fullfile(root, 'rx'));

S   = load(fname);                        % buf, cfg, meta (saved by main_rx)
cfg = S.cfg;
d   = default_cfg();
cfg.rx = d.rx;                            % current receiver settings
cfg = finalize_cfg(cfg);

fprintf('\nReprocessing %s\n', fname);
fprintf('SF%d, BW %g kHz, CR 4/%d, recorded %s at %g m (%s)\n', cfg.SF, ...
        cfg.BW/1e3, 4 + cfg.CR, S.meta.date, S.meta.distance_m, S.meta.site);

[res, sm] = process_capture(S.buf, cfg);
print_summary(sm);

if writeLog
    dataDir = fullfile(root, 'data');
    meta = S.meta;
    meta.capture_file = fname;
    meta.reprocessed  = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    phy = struct('SF', cfg.SF, 'BW', cfg.BW, 'CR', cfg.CR, ...
                 'payloadLen', cfg.payloadLen, 'fc_Hz', cfg.sdr.centerFreq);
    for k = 1:numel(res)
        log_csv(fullfile(dataDir, 'packets_reprocessed.csv'), meta, phy, res(k));
    end
    log_csv(fullfile(dataDir, 'sessions_reprocessed.csv'), meta, phy, sm);
    fprintf('Logged to data/*_reprocessed.csv\n');
end
end
