function m = packet_metrics(xf, y, s0, nSym, noise_dBFS, cfg)
% PACKET_METRICS  SNR and RSSI of one received packet.
%
%   m = packet_metrics(xf, y, s0, nSym, noise_dBFS, cfg)
%     xf         : filtered full-rate capture (rx_frontend)
%     y          : the packet at 1 sample/chip, aligned and CFO-corrected
%                  (y(1) = first preamble sample)
%     s0         : packet start in xf (full-rate sample index)
%     nSym       : packet length in symbols
%     noise_dBFS : noise floor of the capture (NaN if unknown)
%     cfg        : capture config (OSR 8)
%     m          : .SNR_dB       in-band SNR (signal / noise power in BW)
%                  .RSSI_dBFS    total in-band power during the packet
%                  .sigPow_dBFS  RSSI with the noise floor removed
%                  .RSSI_dBm     calibrated RSSI (NaN until rssiCal_dB is set)
%
% SNR (from the preamble: every chirp dechirps to bin 0 after CFO removal)
%   peak bin ~ N^2*A^2 + N*s2,  other bins ~ N*s2  ->  Pn = mean(other bins)
%   SNR = A^2/s2 = (peak - Pn) / (N*Pn), summed over all P preamble chirps.
%   Bins -1, 0, +1 count as peak (sub-chip timing error spreads the tone).
%   Same definition commercial LoRa chips report (in-band SNR).
%
% RSSI: mean power of xf over the packet only, in dBFS.
%   Calibration (once, at the bench): known power P_known into the RX at
%   gain G reads RSSI_dBFS  ->  cfg.sdr.rssiCal_dB = P_known - (RSSI_dBFS - G)
%
% SYNTAX NOTES
%   - sum(sum(A)) adds every element; noiseF(pk, :) = [] deletes those rows.
%   - eps (~2e-16) keeps log10 away from 0 or negative values.
%   - 10^(dB/10) converts dB to linear power (subtract powers only in linear).

    N  = cfg.N;
    P  = cfg.preambleLen;
    c1 = cfg;  c1.OSR = 1;  c1 = finalize_cfg(c1);
    dn = conj(lora_chirp(0, c1));
    
    % ---- SNR from the preamble -----------------------------------------------
    X  = reshape(y(1 : P*N), N, P);
    F  = abs(fft(X .* dn)).^2;                    % N x P
    pk = [N, 1, 2];                               % bins -1, 0, +1
    sigE   = sum(sum(F(pk, :)));
    noiseF = F;
    noiseF(pk, :) = [];
    Pn     = mean(noiseF(:));                     % noise per bin
    sigOnly = sigE - 3 * P * Pn;                  % remove the noise in the 3 peak bins
    m.SNR_dB = 10*log10(max(sigOnly, eps) / (N * P * Pn));
    
    % ---- RSSI over the packet --------------------------------------------------
    i1 = max(1, s0);
    i2 = min(numel(xf), s0 + nSym*cfg.sps - 1);
    pw = mean(abs(xf(i1:i2)).^2);
    m.RSSI_dBFS = 10*log10(pw + eps);
    if isnan(noise_dBFS)
        m.sigPow_dBFS = NaN;
    else
        m.sigPow_dBFS = 10*log10(max(pw - 10^(noise_dBFS/10), eps));
    end
    m.RSSI_dBm = m.RSSI_dBFS - cfg.sdr.rxGain + cfg.sdr.rssiCal_dB;
end