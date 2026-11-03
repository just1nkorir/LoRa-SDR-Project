function nib = bytes2nibbles(bytes)
    bytes = double(bytes(:));
    nib = [bitand(bytes, 15), bitshift(bytes, -4)].';
    nib = nib(:).';
end