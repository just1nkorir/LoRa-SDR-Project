function xf = rx_frontend(x, cfg)
% RX_FRONTEND  Remove DC and low-pass filter a raw capture to the LoRa band.
%   xf = rx_frontend(x, cfg)      cfg at the capture's OSR (8 for the USRP)
%   Output has the same length and timing as x (filter delay removed).
%   Do NOT rescale the amplitude here: RSSI is measured on xf.

    x = double(x(:));
    x = x-mean(x);

    if cfg.OSR == 1
        xf = x;
        return;
    end

    nTaps = cfg.rx.lpfTapsPerOSR * cfg.OSR + 1;
    h = lowpass_fir(cfg.rx.lpfCutoff * cfg.BW, cfg.fs, nTaps);
    D = (nTaps-1)/2;
    y = filter(h, 1, [x; zeros(D, 1)]);
    xf = y(D+1 : end);
end