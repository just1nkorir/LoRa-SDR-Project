function cfg = default_cfg()
% DEFAULT_CFG  All parameters for the LoRa-SDR project, in ONE place.
%
%   cfg = default_cfg();                     % get the defaults
%   cfg.SF = 9;  cfg = finalize_cfg(cfg);    % change something, then ALWAYS
%                                            % re-run finalize_cfg
%
% WHY ONE CONFIG STRUCT?
%   Every function takes "cfg" as an input instead of having numbers typed
%   inside it. Change SF, bandwidth or frequency here (or in your script)
%   and every block - TX, RX, radio - sees the same value. TX and RX must
%   agree on almost everything, so a single source of truth avoids a whole
%   class of "it works in simulation but not on the radios" bugs.
%
% ONLY ADD A FIELD WHEN A FUNCTION NEEDS IT. Receiver options (cfg.rx) are
% empty for now and get filled in when you write the RX functions.
%
% MATLAB SYNTAX NOTES
%   - "function cfg = default_cfg()" : a function with no inputs and one
%     output. The file name MUST match the function name.
%   - cfg = struct() : an empty structure. A struct is like a Python
%     dictionary with fixed names: cfg.SF = 7 creates field "SF" holding 7.
%   - cfg.sdr.txGain = 10 : a struct inside a struct (nested), used here to
%     group related settings.
%   - 125e3 is scientific notation: 125 x 10^3 = 125000.
%   - % starts a comment; MATLAB ignores the rest of the line.

    cfg = struct();
    
    % ---------------- LoRa PHY parameters ----------------------------------------
    cfg.SF  = 7;        % Spreading factor, 7..12. Each symbol carries SF bits;
                        % there are N = 2^SF possible symbol values. Higher SF:
                        % longer symbols, more range, slower data rate.
    cfg.BW  = 125e3;    % Bandwidth in Hz: 125e3, 250e3 or 500e3 in real LoRa.
                        % The chirp sweeps from -BW/2 to +BW/2.
    cfg.CR  = 1;        % Coding rate index 1..4 -> code rate 4/(4+CR):
                        % 1 = 4/5, 2 = 4/6, 3 = 4/7, 4 = 4/8 (most protection).
    cfg.OSR = 1;        % Oversampling ratio = samples per chip, so fs = BW*OSR.
                        % 1 is fastest for simulation. The USRP needs a higher
                        % rate (cfg.sdr.OSR); scripts that use the radio set
                        % cfg.OSR = cfg.sdr.OSR.
                        
    % ---------------- Packet structure --------------------------------------------
    cfg.preambleLen = 8;    % Base upchirps at the start: lets the RX detect the
                            % packet and measure timing and CFO.
    cfg.nSyncDown   = 2;    % Downchirps after the preamble: mark where the data
                            % starts (real LoRa uses 2.25; simplified here).
    cfg.payloadLen  = 16;   % Payload bytes (3..255). Test payload layout:
                            %   bytes 1-2  : sequence number (for PER)
                            %   bytes 3-16 : fixed pseudo-random bytes (for BER)
    cfg.crcOn       = true; % Append a 2-byte CRC-16 to the payload.
    cfg.seed        = 1;    % Random seed for the fixed payload bytes. TX and RX
                            % must use the SAME seed, or BER will be nonsense.
                            
    % ---------------- Receiver options (filled in when writing the RX) ------------
    cfg.rx = struct();
    cfg.rx.lpfCutoff     = 0.55;    % low-pass cutoff as a fraction of BW (+-0.55*BW)
    cfg.rx.lpfTapsPerOSR = 16;      % filter length = 16*OSR + 1 taps (129 at OSR 8)
    cfg.rx.detThresh  = 4;          % window peak/average ratio needed to count as
                                    % "chirp present" (noise alone gives ~3-6)
    cfg.rx.minRun     = 5;          % consecutive preamble windows needed to detect
                                    % a packet (must be <= preambleLen - 2)
    cfg.rx.detZeroPad = 4;          % FFT zero-padding in the coarse window scan
    cfg.rx.syncThresh = 6;          % minimum sync score (mean peak/average of the
                                    % last 2 preamble + 2 SFD chirps). Real packets
                                    % score ~15-40; noise ~4.
    
    % ---------------- SDR: NI USRP-2920 (N210 equivalent) --------------------------
    % Only used by the radio functions. Not used in simulation.
    cfg.sdr.platform    = 'N200/N210/USRP2';    % name used by comm.SDRuTransmitter/Receiver
    cfg.sdr.txIP        = '192.168.10.5';       % from the previous student's scripts:
    cfg.sdr.rxIP        = '192.168.11.6';       % confirm on your PCs (ping them)
    cfg.sdr.masterClock = 100e6;                % fixed 100 MHz on the N210/2920
    cfg.sdr.centerFreq  = 915e6;                % Hz. CONFIRM the allowed ISM band and
                                                % maximum power in Colombia with your
                                                % supervisor.
    cfg.sdr.OSR         = 8;                    % fs = 125 kHz * 8 = 1 MHz:
                                                % 100 MHz / 1 MHz = factor 100 (must be
                                                % a whole number - finalize_cfg checks)
    cfg.sdr.txGain      = 10;                   % dB. Start LOW, increase carefully.
    cfg.sdr.rxGain      = 30;                   % dB. Keep it FIXED during a session and
                                                % log it: RSSI depends on it.
    cfg.sdr.amplitude   = 0.7;                  % peak sample amplitude sent to the
                                                % USRP (must be <= 1)
    cfg.sdr.rssiCal_dB  = NaN;                  % RSSI calibration: dBm = dBFS - rxGain + rssiCal_dB
    
    cfg = finalize_cfg(cfg);   % compute the derived values (N, fs, Tsym, ...)
end
