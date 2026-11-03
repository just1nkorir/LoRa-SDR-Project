function print_summary(sm)
% PRINT_SUMMARY  Print the summary struct from process_capture (screen only).
%   print_summary(sm)
%   Shows the session's results in the Command Window so you can judge a test
%   point in the field. It saves nothing - logging is done by log_csv in main_rx.
%
% SYNTAX NOTES
%   - fprintf(format, values...): each %... placeholder is filled by the next
%     value. %d whole number, %.2f two decimals, %.2e scientific, %g short
%     general form (also prints NaN cleanly). \n = new line.

    fprintf('\n---- capture summary (%.1f s) ----\n', sm.capture_s);
    fprintf('Packets detected    : %d  (header OK %d, CRC OK %d, ghosts ignored %d)\n', ...
            sm.nDetected, sm.nHdrOk, sm.nCrcOk, sm.nGhost);
    fprintf('Sequence numbers   : %g .. %g  (%g expected)\n', ...
            sm.seqFirst, sm.seqLast, sm.nExpected);
    fprintf('PER                : %.4f\n', sm.PER);
    fprintf('BER                : %.2e  (%d errors / %d bits)\n', sm.BER, sm.bitErr, sm.bits);
    fprintf('SNR (mean)         : %.2f dB\n', sm.SNR_mean_dB);
    fprintf('RSSI (mean)        : %.2f dBFS  (%.2f dBm if calibrated)\n', ...
            sm.RSSI_mean_dBFS, sm.RSSI_mean_dBm);
    fprintf('Noise floor        : %.2f dBFS\n', sm.noise_dBFS);
    fprintf('CFO                : %.1f Hz (std %.1f Hz)\n\n', sm.CFO_mean_Hz, sm.CFO_std_Hz);
end