function tx = sdr_make_tx(cfg)
% SDR_MAKE_TX  Create and configure the USRP transmitter (NI USRP-2920 / N210).
%
%   tx = sdr_make_tx(cfg);      % cfg.OSR must already equal cfg.sdr.OSR
%   tx(samples)                 % send a column of complex samples, |x| <= 1
%   release(tx)                 % ALWAYS release when done (frees the radio)
%
% REQUIRES MATLAB with the "Communications Toolbox Support Package for USRP
% Radio". Check the property names against your version with
% "doc comm.SDRuTransmitter" the first time you run it.
%
% FIRST TIME: run findsdru in the Command Window. It lists the connected
% radios and their IP addresses; put the right one in cfg.sdr.txIP.
%
% SAMPLE RATE
%   The radio has a fixed 100 MHz master clock and divides it by an
%   INTERPOLATION factor: fs = 100e6 / factor. With BW = 125 kHz and
%   OSR = 8: fs = 1 MHz -> factor 100 (computed in finalize_cfg).
%   The packet's samples must be built at the SAME rate, so cfg.OSR must
%   equal cfg.sdr.OSR - checked below.
%
% CONTINUOUS MODE
%   main_tx calls tx(frame) once per packet. If MATLAB is briefly too slow
%   to feed the radio, there is a gap ("underrun"); tx() returns true then.
%   Between packets that only adds silence, which is harmless.
%
% SYNTAX NOTES
%   - comm.SDRuTransmitter('Name', value, ...) creates a "System object".
%     Configure it once, then CALL it like a function: tx(samples).

    assert(cfg.fs == cfg.sdr.fs, ...
           'cfg.fs (%g) must equal the radio rate cfg.sdr.fs (%g): set cfg.OSR = cfg.sdr.OSR', ...
           cfg.fs, cfg.sdr.fs);
    
    tx = comm.SDRuTransmitter( ...
            'Platform',            cfg.sdr.platform, ...
            'IPAddress',           cfg.sdr.txIP, ...
            'CenterFrequency',     cfg.sdr.centerFreq, ...
            'Gain',                cfg.sdr.txGain, ...
            'InterpolationFactor', cfg.sdr.factor);
end