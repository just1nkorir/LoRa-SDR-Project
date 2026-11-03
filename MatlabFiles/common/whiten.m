function out = whiten(bytes)
    bytes = double(bytes);
    out = zeros(size(bytes));
    state = 255;

    for k = 1:numel(bytes)
        w = 0;
        for b = 0:7
            outBit = bitget(state, 1);              % lowest bit = output
            w = w + outBit * 2^b;                   % place it at position b
            fb = xor(xor(bitget(state,1), bitget(state,3)), ...   % "..." continues
                xor(bitget(state,4), bitget(state,5)));      % the line
            state = bitshift(state, -1) + 128 * fb;
        end
        out(k) = bitxor(bytes(k), w);
    end
end