function cfg = finalize_cfg(cfg)
% FINALIZE_CFG  Check the settings and compute every derived value.
%
%   cfg = finalize_cfg(cfg)
%
% Call it after EVERY change to cfg, e.g.
%   cfg = default_cfg();  cfg.SF = 12;  cfg = finalize_cfg(cfg);
%
% WHY A SEPARATE FUNCTION?
%   Values like N = 2^SF depend on other fields. If you typed N in by hand
%   and later changed SF, N would silently stay wrong. Here they are always
%   recomputed from the base fields, so they can never go out of date.
%
% DERIVED FIELDS
%   N        = 2^SF            number of possible symbol values (FFT size)
%   fs       = BW * OSR        sample rate, samples/s
%   Tsym     = N / BW          symbol duration, s (SF7/125k: 1.024 ms)
%   sps      = N * OSR         samples per symbol
%   n        = 4 + CR          bits per Hamming codeword (5..8)
%   binHz    = BW / N          width of one FFT bin, Hz (SF7/125k: 977 Hz).
%                              A CFO above half a bin breaks demodulation.
%   Rb       = SF*(BW/N)*4/(4+CR)   useful bit rate, bit/s
%   nHdrSym  header symbols  (3-byte header, always coded at CR 4/8)
%   nPaySym  payload symbols (payload + CRC, coded at cfg.CR)
%   nSym     whole packet:   preamble + sync + header + payload
%   airtime_s  packet duration, s
%
% SYNTAX NOTES
%   - assert(condition, message) stops with "message" if the condition is
%     false. Wrong settings fail HERE, loudly, instead of producing strange
%     results ten functions later. %d / %g in the message are filled in
%     with the values that follow, like in fprintf.
%   - ismember(x, list) is true if x is one of the values in list.
%   - ceil rounds UP: ceil(2.1) = 3.
%   - A logical (true/false) used in arithmetic counts as 1/0, so
%     2*cfg.crcOn adds 2 CRC bytes only when crcOn is true.

% ---- checks ----------------------------------------------------------------
assert(ismember(cfg.SF, 7:12), 'SF must be 7..12 (got %g)', cfg.SF);
assert(ismember(cfg.BW, [125e3 250e3 500e3]), 'BW must be 125e3, 250e3 or 500e3 (got %g)', cfg.BW);
assert(ismember(cfg.CR, 1:4), 'CR must be 1..4 (got %g)', cfg.CR);
assert(cfg.OSR >= 1 && cfg.OSR == round(cfg.OSR), 'OSR must be a positive whole number (got %g)', cfg.OSR);
assert(cfg.payloadLen >= 3 && cfg.payloadLen <= 255, ...
       'payloadLen must be 3..255 (2 bytes are the sequence number), got %g', cfg.payloadLen);
assert(cfg.preambleLen >= 6, 'preambleLen should be at least 6 for reliable detection');

% ---- derived values ----------------------------------------------------------
cfg.N     = 2^cfg.SF;
cfg.fs    = cfg.BW * cfg.OSR;
cfg.Tsym  = cfg.N / cfg.BW;
cfg.sps   = cfg.N * cfg.OSR;
cfg.n     = 4 + cfg.CR;
cfg.binHz = cfg.BW / cfg.N;
cfg.Rb    = cfg.SF * (cfg.BW / cfg.N) * 4 / (4 + cfg.CR);

% Packet length in symbols. Each symbol carries SF bits, and every 4 data
% bits become an n-bit codeword. Coding works on blocks of SF codewords,
% which fill exactly n symbols - hence ceil(nibbles/SF) * n.
nHdrNib      = 6;                                       % 3 header bytes = 6 nibbles
cfg.nHdrSym  = ceil(nHdrNib / cfg.SF) * 8;              % header: always CR 4/8
nPayNib      = 2 * (cfg.payloadLen + 2*cfg.crcOn);      % payload + CRC, in nibbles
cfg.nPaySym  = ceil(nPayNib / cfg.SF) * cfg.n;
cfg.nSym     = cfg.preambleLen + cfg.nSyncDown + cfg.nHdrSym + cfg.nPaySym;
cfg.airtime_s = cfg.nSym * cfg.Tsym;

% ---- SDR check: the USRP can only divide its 100 MHz clock by a whole number
if isfield(cfg, 'sdr')
    factor = cfg.sdr.masterClock / (cfg.BW * cfg.sdr.OSR);
    assert(abs(factor - round(factor)) < 1e-9, ...
           'USRP rate factor %g is not a whole number: change cfg.sdr.OSR or BW', factor);
    cfg.sdr.fs     = cfg.BW * cfg.sdr.OSR;              % radio sample rate
    cfg.sdr.factor = round(factor);                     % interpolation/decimation
end
end
