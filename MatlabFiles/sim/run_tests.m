function run_tests()
% RUN_TESTS  Check every function of the project, in chain order.
%
%   Run from anywhere:   run_tests
%
% Each test checks one function against a known answer (the values from
% the function breakdowns). A FAIL line names the function and says what
% went wrong, so you know exactly where to look. Functions later in the
% chain depend on earlier ones, so FIX THE FIRST FAIL FIRST - later fails
% are often just consequences of it.
%
% Takes about a minute (the detection tests build simulated captures).

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'common'), fullfile(root, 'tx'), fullfile(root, 'rx'));
    rand('seed', 1);  randn('seed', 1); %#ok<RAND>   repeatable noise
    
    tests = {
      % ---- common ----
      'default_cfg / finalize_cfg', @t_cfg
      'make_test_payload',          @t_payload
      'crc16',                      @t_crc
      'whiten',                     @t_whiten
      'bytes2nibbles',              @t_b2n
      'nibbles2bytes',              @t_n2b
      'gray_encode / gray_decode',  @t_gray
      'lora_chirp',                 @t_chirp
      % ---- tx ----
      'hamming_encode',             @t_henc
      'interleave',                 @t_inter
      'encode_section',             @t_encsec
      'build_header',               @t_hdr
      'tx_packet',                  @t_txpkt
      'build_frame',                @t_frame
      % ---- rx: decoding ----
      'lora_demodulate',            @t_demod
      'deinterleave',               @t_deinter
      'hamming_decode',             @t_hdec
      'decode_section',             @t_decsec
      'parse_header',               @t_phdr
      'rx_packet',                  @t_rxpkt
      % ---- rx: real captures ----
      'lowpass_fir',                @t_lpf
      'rx_frontend',                @t_front
      'scan_windows',               @t_scan
      'find_runs',                  @t_runs
      'interp_peak',                @t_interp
      'sync_packet',                @t_sync
      'detect_packets',             @t_detect
      'payload_ber',                @t_ber
      'packet_metrics',             @t_metrics
      'process_capture',            @t_process
    };
    
    fprintf('\n');
    nPass = 0;  firstFail = '';
    for k = 1:size(tests, 1)
        name = tests{k, 1};
        try
            tests{k, 2}();
            fprintf('  PASS  %s\n', name);
            nPass = nPass + 1;
        catch err
            fprintf('  FAIL  %-28s %s\n', name, err.message);
            if isempty(firstFail), firstFail = name; end
        end
    end
    fprintf('\n%d / %d tests passed\n', nPass, size(tests, 1));
    if ~isempty(firstFail)
        fprintf('Start with the first failure: %s\n', firstFail);
    end
    fprintf('\n');
end

% ============================== helpers ======================================
function check(cond, varargin)
    % Like assert, but the message says what was expected.
    if ~cond
        error(varargin{:});
    end
end

function c8 = cfg8()
    c8 = default_cfg();  c8.OSR = 8;  c8 = finalize_cfg(c8);
end

function x = add_noise(x, snr_dB, OSR)
    nVar = OSR / 10^(snr_dB/10);
    x = x + sqrt(nVar/2) * (randn(size(x)) + 1j*randn(size(x)));
end

% ================================ common ======================================
function t_cfg()
    cfg = default_cfg();
    check(cfg.N == 128 && cfg.sps == 128 && abs(cfg.Tsym - 1.024e-3) < 1e-12, 'N/sps/Tsym wrong for SF7');
    check(cfg.nSym == 48, 'nSym = %d, expected 48', cfg.nSym);
    c = cfg;  c.SF = 12;  c = finalize_cfg(c);
    check(c.nSym == 33, 'SF12 nSym = %d, expected 33', c.nSym);
    check(cfg.sdr.factor == 100, 'sdr.factor = %g, expected 100', cfg.sdr.factor);
    f = {'lpfCutoff','lpfTapsPerOSR','detThresh','minRun','detZeroPad','syncThresh'};
    for i = 1:numel(f)
        check(isfield(cfg.rx, f{i}), 'cfg.rx.%s missing in default_cfg', f{i});
    end
    f = {'rssiCal_dB','rxSamplesPerFrame','captureSeconds'};
    for i = 1:numel(f)
        check(isfield(cfg.sdr, f{i}), 'cfg.sdr.%s missing in default_cfg', f{i});
    end
end

function t_payload()
    cfg = default_cfg();
    p = make_test_payload(0, cfg);
    check(isequal(p, [0 0 98 132 212 8 13 135 171 1 98 17 106 175 150 238]), ...
          'payload(0) = %s', mat2str(p));
    q = make_test_payload(300, cfg);
    check(q(1) == 44 && q(2) == 1 && isequal(q(3:end), p(3:end)), 'seq 300 not stored as 44,1');
end

function t_crc()
    c = crc16(uint8('123456789'));
    check(c == 10673, 'crc16(''123456789'') = %d, expected 10673 (0x29B1)', c);
end

function t_whiten()
    w = whiten([0 0 0 0]);
    check(isequal(w, [255 208 99 1]), 'whiten([0 0 0 0]) = %s, expected [255 208 99 1]', mat2str(w));
    p = make_test_payload(3, default_cfg());
    check(isequal(whiten(whiten(p)), p), 'whiten twice does not give the input back');
end

function t_b2n()
    n = bytes2nibbles([171 18]);
    check(isequal(n, [11 10 2 1]), 'bytes2nibbles([171 18]) = %s, expected [11 10 2 1]', mat2str(n));
    check(isequal(bytes2nibbles([171; 18]), [11 10 2 1]), 'column input should give a row');
    check(isa(n, 'double'), 'output should be double, is %s', class(n));
end

function t_n2b()
    b = nibbles2bytes([11 10 2 1]);
    check(isequal(b, [171 18]), 'nibbles2bytes([11 10 2 1]) = %s, expected [171 18]', mat2str(b));
    p = make_test_payload(7, default_cfg());
    check(isequal(nibbles2bytes(bytes2nibbles(p)), p), 'round trip with bytes2nibbles fails');
end

function t_gray()
    check(isequal(gray_encode(0:7), [0 1 3 2 6 7 5 4]), 'gray_encode(0:7) = %s', mat2str(gray_encode(0:7)));
    check(isequal(gray_decode(0:7), [0 1 3 2 7 6 4 5]), 'gray_decode(0:7) = %s', mat2str(gray_decode(0:7)));
    v = 0:4095;
    check(isequal(gray_encode(gray_decode(v)), v), 'gray_encode(gray_decode(v)) ~= v');
end

function t_chirp()
    cfg = default_cfg();
    x = lora_chirp(0, cfg);
    check(isequal(size(x), [128 1]), 'size %s, expected [128 1] (a column)', mat2str(size(x)));
    check(max(abs(abs(x) - 1)) < 1e-12, 'samples should have magnitude 1');
    y = lora_chirp(37, cfg);
    [~, i] = max(abs(fft(y .* conj(x))));
    check(i - 1 == 37, 'dechirp + FFT of symbol 37 peaks at %d', i - 1);
    c8 = cfg8();  z = lora_chirp(37, c8);
    check(max(abs(z(1:8:end) - y)) < 1e-9, ...
          'OSR 8 chirp sampled every 8th sample differs from OSR 1 chirp (old cumsum version?)');
end

% ================================== tx ==========================================
function t_henc()
    cw = hamming_encode([5 12], 3);
    check(isequal(cw, [1 0 1 0 1 0 1; 0 0 1 1 1 0 0]), 'hamming_encode([5 12],3) = %s', mat2str(cw));
    cw = hamming_encode(0:15, 4);
    check(all(mod(sum(cw, 2), 2) == 0), 'CR 4 codewords should have an even number of 1s');
end

function t_inter()
    C = reshape(1:20, 5, 4).';
    S = interleave(C);
    check(isequal(S, [1 6 11 16; 7 12 17 2; 13 18 3 8; 19 4 9 14; 5 10 15 20]), ...
          'interleave of the numbered matrix is wrong: %s', mat2str(S));
end

function t_encsec()
    s = encode_section([5 12 7 0 15 9 3], 1, 7);
    check(isequal(s, [89 51 70 59 63]), 'encode_section = %s, expected [89 51 70 59 63]', mat2str(s));
    check(numel(encode_section(zeros(1,36), 1, 7)) == 30, 'payload section should be 30 symbols');
end

function t_hdr()
    cfg = default_cfg();
    h = build_header(16, cfg);
    check(isequal(h, [16 17 33]), 'build_header(16) = %s, expected [16 17 33]', mat2str(h));
end

function t_txpkt()
    cfg = default_cfg();
    [s, info] = tx_packet(make_test_payload(0, cfg), cfg);
    check(info.crc == 28529, 'crc = %d, expected 28529', info.crc);
    check(numel(s) == 38, '%d symbols, expected 38', numel(s));
    check(isequal(s(1:8), [20 31 0 0 93 80 127 43]), 'header symbols = %s', mat2str(s(1:8)));
    check(isequal(s(9:13), [109 126 92 33 126]), 'first payload symbols = %s', mat2str(s(9:13)));
end

function t_frame()
    cfg = default_cfg();
    iq = build_frame(tx_packet(make_test_payload(0, cfg), cfg), cfg);
    check(isequal(size(iq), [6144 1]), 'size %s, expected [6144 1]', mat2str(size(iq)));
    d = iq(10*128 + (1:128));
    [~, i] = max(abs(fft(d .* conj(lora_chirp(0, cfg)))));
    check(i - 1 == 20, 'first data chirp demodulates to %d, expected 20', i - 1);
end

% =============================== rx: decoding =====================================
function t_demod()
    cfg = default_cfg();
    s  = tx_packet(make_test_payload(0, cfg), cfg);
    iq = build_frame(s, cfg);
    r  = lora_demodulate(iq(10*128 + 1 : end), numel(s), cfg);
    check(isequal(r, s), 'demodulated symbols differ from sent symbols');
end

function t_deinter()
    C = reshape(1:20, 5, 4).';
    check(isequal(deinterleave(interleave(C)), C), 'deinterleave(interleave(C)) ~= C');
end

function t_hdec()
    nib = [5 12 7 0 15 9 3];
    for cr = 1:4
        [o, nc, nd] = hamming_decode(hamming_encode(nib, cr), cr);
        check(isequal(o, nib) && nc == 0 && nd == 0, 'clean round trip fails at CR %d', cr);
    end
    cw = hamming_encode(nib, 3);  cw(1, 1) = 1 - cw(1, 1);
    [o, nc] = hamming_decode(cw, 3);
    check(isequal(o, nib) && nc == 1, 'flipped d1 at CR 3 not corrected');
    cw = hamming_encode(nib, 4);  cw(1, [1 3]) = 1 - cw(1, [1 3]);
    [~, nc, nd] = hamming_decode(cw, 4);
    check(nc == 0 && nd == 1, 'double error at CR 4 should be detected, not corrected');
end

function t_decsec()
    n = decode_section([89 51 70 59 63], 1, 7);
    check(isequal(n, [5 12 7 0 15 9 3]), 'decode_section = %s', mat2str(n));
    nib = mod(0:35, 16);
    s = encode_section(nib, 3, 7);  s(5) = mod(s(5) + 50, 128);
    o = decode_section(s, 3, 7);
    check(isequal(o(1:36), nib), 'a wrong symbol at CR 3 was not corrected');
end

function t_phdr()
    [h, ok] = parse_header([16 17 33]);
    check(ok && h.payloadLen == 16 && h.CR == 1 && h.crcOn == true, 'parse_header([16 17 33]) wrong');
    check(islogical(h.crcOn), 'crcOn should be true/false (missing "> 0"?)');
    [~, ok] = parse_header([16 17 34]);
    check(~ok, 'bad checksum not rejected');
    [~, ok] = parse_header([16 23 39]);
    check(~ok, 'CR = 7 not rejected');
end

function t_rxpkt()
    cfg = default_cfg();
    p  = make_test_payload(5, cfg);
    iq = build_frame(tx_packet(p, cfg), cfg);
    out = rx_packet(iq, cfg);
    check(out.hdrOk && out.crcOk && isequal(out.payload, p), 'clean packet not decoded');
    out = rx_packet(add_noise(iq, -5, 1), cfg);
    check(out.crcOk && isequal(out.payload, p), 'packet at -5 dB SNR not decoded');
    out = rx_packet(randn(6144, 1) + 1j*randn(6144, 1), cfg);
    check(~out.crcOk, 'pure noise should not give a good packet');
    out = rx_packet(iq(1:3000), cfg);
    check(~out.crcOk, 'cut-off packet should fail cleanly');
end

% ============================ rx: real captures ===================================
function t_lpf()
    h = lowpass_fir(0.55*125e3, 1e6, 129);
    check(numel(h) == 129, '%d taps, expected 129', numel(h));
    check(~any(isnan(h)), 'filter contains NaN (sinc(0) not set to 1 after the division?)');
    check(abs(sum(h) - 1) < 1e-9, 'sum(h) = %g, expected 1', sum(h));
end

function t_front()
    c8 = cfg8();
    t = (0:9999).' / c8.fs;
    x = exp(1j*2*pi*30e3*t) + exp(1j*2*pi*200e3*t) + 0.5;
    y = rx_frontend(x, c8);
    check(numel(y) == numel(x), 'output length changed');
    P = mean(abs(y(500:end-500)).^2);
    check(abs(P - 1) < 0.05, 'output power %.3f, expected ~1 (only the 30 kHz tone)', P);
    cfg = default_cfg();  p = make_test_payload(1, cfg);
    x8 = build_frame(tx_packet(p, c8), c8);
    xf = rx_frontend(x8, c8);
    out = rx_packet(xf(1:8:end), cfg);
    check(out.crcOk, 'filtered + decimated frame does not decode (filter delay not removed?)');
end

function [x, xf, xd, start] = one_packet_capture()
    cfg = default_cfg();  c8 = cfg8();
    fr = build_frame(tx_packet(make_test_payload(3, cfg), c8), c8);
    x  = [zeros(2345, 1); fr; zeros(5000, 1)];
    x  = x .* exp(1j*2*pi*2500*(0:numel(x)-1).' / c8.fs);
    x  = add_noise(x, 0, 8);
    xf = rx_frontend(x, c8);
    xd = xf(1:8:end);
    start = 2346;
end

function t_scan()
    cfg = default_cfg();
    fr = build_frame(tx_packet(make_test_payload(0, cfg), cfg), cfg);
    x  = [zeros(300, 1); fr; zeros(500, 1)];
    x  = x + 1e-3 * (randn(size(x)) + 1j*randn(size(x)));
    [b, r] = scan_windows(x, conj(lora_chirp(0, cfg)), 4);
    check(all(abs(b(4:10) - 84) < 0.5), 'preamble windows 4-10 should peak at bin 84, got %s', mat2str(b(4:10)));
    check(all(r(4:10) > 100), 'preamble windows should have ratio ~128');
    [b2, ~] = scan_windows(x, lora_chirp(0, cfg), 4);
    check(abs(b2(12) - 44) < 0.5, 'SFD window 12 should peak at bin 44, got %g', b2(12));
end

function t_runs()
    cfg = default_cfg();
    fr = build_frame(tx_packet(make_test_payload(0, cfg), cfg), cfg);
    x  = [zeros(300, 1); fr; zeros(500, 1)];
    x  = x + 1e-3 * (randn(size(x)) + 1j*randn(size(x)));
    [b, r] = scan_windows(x, conj(lora_chirp(0, cfg)), 4);
    runs = find_runs(b, r, 128, 4, 5);
    % (a later run inside the payload is a possible ghost - only the first matters here)
    check(~isempty(runs) && isequal(runs(1, :), [3 11]), 'first run = %s, expected [3 11]', mat2str(runs));
    r(7) = 1;
    runs = find_runs(b, r, 128, 4, 5);
    check(isequal(runs(1, :), [3 11]), 'one weak window should be skipped, not split the run');
    check(isequal(find_runs([127.5 0.25 127.75 0 0.5], 50*ones(1,5), 128, 4, 5), [1 5]), ...
          'wrap-around (bin 127.5 next to 0.25) not handled');
end

function t_interp()
    check(abs(interp_peak([1 4 9 4 1]) - 2) < 1e-12, 'symmetric peak should give 2');
    k = 0:4;
    check(abs(interp_peak(10 - (k - 2.3).^2) - 2.3) < 1e-9, 'parabola peak should give 2.3');
    check(abs(interp_peak([9.91 8.31 1 1 9.51]) - 4.7) < 1e-9, 'wrap-around should give 4.7');
end

function t_sync()
    c8 = cfg8();  cfg = default_cfg();
    [~, xf, xd, start] = one_packet_capture();
    [b, r] = scan_windows(xd, conj(lora_chirp(0, cfg)), 4);
    runs = find_runs(b, r, 128, 4, 5);
    check(~isempty(runs), 'no run found');
    [s0, cfo, ~, ok] = sync_packet(xf, xd, runs(1, :), r, c8);
    check(ok, 'sync_packet rejected a real packet');
    check(s0 == start, 'start %d, expected %d (check the tau line)', s0, start);
    check(abs(cfo - 2500) < 50, 'CFO %.0f Hz, expected ~2500', cfo);
end

function t_detect()
    cfg = default_cfg();  c8 = cfg8();
    x = zeros(3000, 1);  st = zeros(1, 3);
    for s = 0:2
        st(s+1) = numel(x) + 1;
        x = [x; build_frame(tx_packet(make_test_payload(s, cfg), c8), c8); zeros(20000 + 777*s, 1)]; %#ok<AGROW>
    end
    x = x .* exp(1j*2*pi*1800*(0:numel(x)-1).' / c8.fs);
    x = add_noise(x, 0, 8);
    pk = detect_packets(rx_frontend(x, c8), c8);
    check(all(ismember(st, [pk.start])), 'not all 3 packets found at their exact start');
end

function t_ber()
    cfg = default_cfg();
    p = make_test_payload(300, cfg);
    [e, n] = payload_ber(p, cfg);
    check(e == 0 && n == 112, 'clean payload: %d errors / %d bits, expected 0 / 112', e, n);
    q = p;  q(5) = bitxor(q(5), 3);
    check(payload_ber(q, cfg) == 2, 'two flipped bits not counted');
    q = p;  q(1:2) = [99 99];
    check(payload_ber(q, cfg) == 0, 'sequence-number bytes should not be compared');
end

function t_metrics()
    cfg = default_cfg();  c8 = cfg8();
    fr = build_frame(tx_packet(make_test_payload(0, cfg), c8), c8);
    x  = 0.1 * add_noise(fr, 0, 8);
    xf = rx_frontend(x, c8);
    m  = packet_metrics(xf, xf(1:8:end), 1, cfg.nSym, NaN, c8);
    check(abs(m.SNR_dB) < 1, 'SNR estimate %.2f dB, true 0 dB', m.SNR_dB);
    check(isfinite(m.RSSI_dBFS), 'RSSI_dBFS is NaN (overwritten by the dBm line?)');
    check(isfield(m, 'RSSI_dBm'), 'field RSSI_dBm missing');
end

function t_process()
    cfg = default_cfg();  c8 = cfg8();
    x = zeros(3000, 1);
    for s = [0 1 3 4 5]
        x = [x; build_frame(tx_packet(make_test_payload(s, cfg), c8), c8); zeros(20000 + 777*s, 1)]; %#ok<AGROW>
    end
    x = x .* exp(1j*2*pi*1800*(0:numel(x)-1).' / c8.fs);
    x = 0.05 * add_noise(x, 0, 8);
    [res, sm] = process_capture(x, c8);
    got = [res([res.crcOk]).seq];
    check(isequal(sort(got), [0 1 3 4 5]), 'decoded seqs %s, expected [0 1 3 4 5]', mat2str(got));
    check(abs(sm.PER - 1/6) < 1e-9, 'PER %.3f, expected 0.167', sm.PER);
    check(sm.BER == 0, 'BER %g, expected 0', sm.BER);
    check(abs(sm.SNR_mean_dB) < 1, 'mean SNR %.2f dB, expected ~0', sm.SNR_mean_dB);
end