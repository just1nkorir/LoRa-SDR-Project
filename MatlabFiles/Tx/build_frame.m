function iq = build_frame(symbols, cfg)
% BUILD_FRAME  Preamble + sync downchirps + data chirps = one transmit frame.
%
%   iq = build_frame(symbols, cfg)
%     symbols : row of symbol values from tx_packet (header + payload)
%     iq      : column of complex samples, cfg.nSym * cfg.sps long, |iq| = 1
%
%   [ up up up ... up ][ down down ][ data 1 ][ data 2 ] ...
%     preambleLen        nSyncDown
%
%   - Preamble (repeated base upchirps): lets the receiver detect that a
%     packet is coming and measure timing and frequency offset.
%   - Sync downchirps: mark where the data starts. Together with the
%     upchirps they let the receiver separate timing from CFO.
%   - Data: one chirp per symbol.
%   No amplitude scaling here: that is done just before sending to the USRP.
%
% SYNTAX NOTES
%   - conj(up) flips the sign of the phase: a rising sweep becomes falling.
%   - repmat(up, cfg.preambleLen, 1) stacks the column "up" on top of itself
%     preambleLen times (that many copies down, 1 across).
%   - X(:, m) = ... fills column m; X(:) then reads X column by column,
%     so chirp 1 comes first, then chirp 2, ...
%   - [a; b; c] stacks columns vertically.

up   = lora_chirp(0, cfg);
down = conj(up);

M = numel(symbols);
X = zeros(cfg.sps, M);                  % one column per data chirp
for m = 1:M
    X(:, m) = lora_chirp(symbols(m), cfg);
end

iq = [repmat(up,   cfg.preambleLen, 1);
      repmat(down, cfg.nSyncDown,   1);
      X(:)];
end