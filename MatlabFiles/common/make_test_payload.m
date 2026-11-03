function payload = make_test_payload(seq, cfg)
% MAKE_TEST_PAYLOAD  The test payload: sequence number + fixed known bytes.
%
%   payload = make_test_payload(seq, cfg)
%     seq     : packet number, 0..65535 (wraps around after that)
%     cfg     : config struct (uses cfg.payloadLen and cfg.seed)
%     payload : 1 x cfg.payloadLen row of byte values (0..255)
%
%   byte:   1        2        3 ............ payloadLen
%         [seq low][seq high][ fixed pseudo-random bytes ]
%
%   Example:  p = make_test_payload(300, cfg);
%             p(1) + 256*p(2)        % -> 300
%
% WHY THIS LAYOUT
%   - Bytes 3..end are the SAME in every packet, so the receiver knows them
%     in advance and can count wrong bits -> BER.
%   - Bytes 1-2 count up, so gaps in the received numbers are lost
%     packets -> PER. Two bytes count to 65535, more than a session sends.
%
% WHY OUR OWN RANDOM GENERATOR (and not randi)
%   randi gives DIFFERENT numbers in MATLAB and Octave for the same seed,
%   and could change between MATLAB versions. Then a capture analysed on
%   another computer would be compared against the wrong reference. A
%   generator written out in full gives the same bytes everywhere - even on
%   a microcontroller driving the commercial LoRa modules in week 8.
%   It also leaves MATLAB's own random generator untouched, so calling this
%   does not change the noise in your simulations.
%
%   The generator is the "minimal standard" Park-Miller LCG:
%       x(k+1) = 16807 * x(k)  mod  (2^31 - 1)
%   x stays below 2^31, and 16807 * 2^31 < 2^53, so every step is exact in
%   double precision (no rounding). Each byte is the TOP 8 of x's 31 bits
%   (the top bits of an LCG are more random than the bottom ones).
%
% SYNTAX NOTES
%   - zeros(1, L) makes a 1 x L row of zeros (pre-allocated output).
%   - mod(a, m) is the remainder of a / m, always in 0..m-1.
%   - floor rounds DOWN: floor(x / 2^23) drops the lowest 23 bits of x,
%     keeping the top 8 (31 - 23 = 8), i.e. a value 0..255.
%   - for i = 3:L loops i = 3, 4, ..., L (bytes 1 and 2 are the seq).

L = cfg.payloadLen;
assert(L >= 3, 'payloadLen must be >= 3 (2 bytes are the sequence number)');
assert(cfg.seed >= 1 && cfg.seed < 2^31 - 1 && cfg.seed == round(cfg.seed), ...
       'cfg.seed must be a whole number between 1 and 2^31-2');

payload = zeros(1, L);

% ---- bytes 1-2: sequence number, low byte first ----------------------------
s = mod(seq, 65536);               % wrap around after 65535
payload(1) = mod(s, 256);          % low byte  (s = 300 -> 44)
payload(2) = floor(s / 256);       % high byte (s = 300 -> 1);  1*256 + 44 = 300

% ---- bytes 3..L: fixed pseudo-random bytes from the seed --------------------
x = cfg.seed;
for k = 1:10                       % warm-up: with a small seed (e.g. 1) the
    x = mod(16807 * x, 2^31 - 1);  % first outputs are tiny (16807, ...), so
end                                % the first bytes would always be 0
for i = 3:L
    x = mod(16807 * x, 2^31 - 1);  % next generator state
    payload(i) = floor(x / 2^23);  % top 8 bits -> 0..255
end
end
