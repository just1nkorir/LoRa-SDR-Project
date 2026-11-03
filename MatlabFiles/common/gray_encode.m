function g = gray_encode(b)
    g = bitxor(b, bitshift(b, -1));
end