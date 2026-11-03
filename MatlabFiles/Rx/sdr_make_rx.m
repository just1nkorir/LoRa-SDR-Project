function rx = sdr_make_rx(cfg)
% SDR_MAKE_RX  Create and configure the USRP receiver (NI USRP-2920 / N210).
%
%   rx = sdr_make_rx(cfg);              % cfg.OSR must already equal cfg.sdr.OSR
%   [data, len, overrun] = rx();        % get one frame of samples
%   release(rx)                         % ALWAYS release when done (frees the radio)
%
%   data    : column of cfg.sdr.rxSamplesPerFrame complex samples
%   len     : how many are valid (can be 0 for the first calls - check it)
%   overrun : true if samples were DROPPED because MATLAB did not call rx()
%             fast enough. Dropped samples cut packets, so main_rx counts
%             and logs overruns.
%
% REQUIRES MATLAB with the "Communications Toolbox Support Package for USRP
% Radio". Check the property names against your version with
% "doc comm.SDRuReceiver" the first time you run it.
%
% FIRST TIME: run findsdru in the Command Window. It lists the connected
% radios and their IP addresses; put the right one in cfg.sdr.rxIP.
%
% SAMPLE RATE
%   The radio samples at its 100 MHz master clock and DECIMATES (filters,
%   then keeps 1 in every 'factor' samples): fs = 100e6 / factor. With
%   BW = 125 kHz and OSR = 8: fs = 1 MHz -> factor 100 (from finalize_cfg).
%   The receiver code expects captures at this rate, so cfg.OSR must equal
%   cfg.sdr.OSR - checked below.
%
% GAIN: keep cfg.sdr.rxGain FIXED during a session and log it. RSSI in dBFS
% only means something at a known gain.

    assert(cfg.fs == cfg.sdr.fs, ...
           'cfg.fs (%g) must equal the radio rate cfg.sdr.fs (%g): set cfg.OSR = cfg.sdr.OSR', ...
           cfg.fs, cfg.sdr.fs);
    
    rx = comm.SDRuReceiver( ...
            'Platform',         cfg.sdr.platform, ...
            'IPAddress',        cfg.sdr.rxIP, ...
            'CenterFrequency',  cfg.sdr.centerFreq, ...
            'Gain',             cfg.sdr.rxGain, ...
            'DecimationFactor', cfg.sdr.factor, ...
            'SamplesPerFrame',  cfg.sdr.rxSamplesPerFrame, ...
            'OutputDataType',   'double');
end