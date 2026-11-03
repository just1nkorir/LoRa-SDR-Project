function [nErr, nBits] = payload_ber(rxPayload, cfg)
% PAYLOAD_BER  Count bit errors in the known part of a test payload.
%
%   [nErr, nBits] = payload_ber(rxPayload, cfg)
%     rxPayload : decoded payload bytes (cfg.payloadLen of them)
%     nErr      : number of wrong bits in bytes 3..end
%     nBits     : number of bits compared = 8*(payloadLen - 2)
%   BER of one packet = nErr / nBits. For a session, ADD UP nErr and nBits
%   over all packets first and divide once (each bit counts equally).
%
% The reference is make_test_payload: bytes 3..end are the same in every
% packet (from cfg.seed), so the receiver can regenerate them. Bytes 1-2
% (the sequence number) are not known in advance and are skipped.
%
% SYNTAX NOTES
%   - bitxor(a, b) gives a 1 at every bit where a and b differ.
%   - bitget(d, k) gives bit k (1 = lowest) of every element of d; summing
%     over k = 1..8 counts all the 1s, i.e. all the wrong bits.

    ref = make_test_payload(0, cfg);
    assert(numel(rxPayload) == numel(ref), ...
           'payload has %d bytes, expected %d (bad header?)', numel(rxPayload), numel(ref));
    
    a = double(rxPayload(:).');                % row, double
    a = a(3:end);                              % skip the sequence number
    b = double(ref(3:end));
    d = bitxor(a, b);                          % 1 = wrong bit
    
    nErr = 0;
    for bit = 1:8
        nErr = nErr + sum(bitget(d, bit));
    end
    nBits = 8 * numel(d);
end