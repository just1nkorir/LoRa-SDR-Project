"""
cfo.py -- Carrier-frequency-offset estimator for the LoRa-style preamble
========================================================================
Day 3 (Thu).

Why CFO matters in CSS
----------------------
After dechirping, a CFO of f_off moves the FFT peak by f_off / bin_hz bins
(bin_hz = BW / 2^SF).  The receiver cannot tell that apart from a different
symbol value, so an uncorrected *integer* part of the offset gives wrong symbols,
and the *fractional* part (between bins) costs SNR.
Rule of thumb: 5 ppm @ 915 MHz = 4.6 kHz = ~5 bins at SF7/125 kHz, ~150 bins at SF12.

Estimator (two stages)
----------------------
Frame = [n_up identical upchirps | n_down downchirps | ...]

1. FINE (fractional part, modulo one bin):
   Dechirp consecutive preamble upchirps. Their peak-bin values differ only by a
   phase rotation 2*pi*f_off*T_sym (the symbols are identical, only the carrier
   moved on). So  angle( sum_i Z[i+1] * conj(Z[i]) ) / (2*pi)  = f_off * T_sym
   = CFO in bins, but only modulo 1 bin (phase wraps) -> range +/-0.5 bin, very accurate.

2. COARSE (integer number of bins):
   - upchirp peak bin   b_up   =  cfo_bins + timing_offset_bins
   - downchirp peak bin b_down =  cfo_bins - timing_offset_bins
   so (b_up + b_down)/2 = cfo_bins : timing offset cancels. Accurate to ~1 bin.

3. COMBINE: cfo_bins = n + frac, with n the integer that makes it closest to the
   coarse estimate.   Total range: +/- fs/2 (full Nyquist range of the capture).
"""
from __future__ import annotations

import numpy as np

from lora_phy import LoRaParams, base_downchirp, base_upchirp


PAD = 4   # zero-padding factor for the COARSE peak search (resolution = 1/PAD bin)


def _coarse_bins(dechirped: np.ndarray, N: int) -> float:
    """Peak position (in bins, signed, fractional) of the energy summed over all
    symbols. Zero-padding the FFT PAD times gives ~1/PAD-bin resolution.
    Why: if the coarse estimate were only accurate to +/-0.5 bin, then whenever the
    true CFO sits near a half-bin the integer decision below could flip and give a
    full-bin error. With +/-1/PAD accuracy that ambiguity disappears."""
    P = (np.abs(np.fft.fft(dechirped, n=PAD * N, axis=1)) ** 2).sum(axis=0)
    k = int(np.argmax(P))
    if k >= PAD * N // 2:                      # upper half of FFT = negative frequencies
        k -= PAD * N
    return k / PAD


def estimate_cfo(rx: np.ndarray, p: LoRaParams, n_up: int = 8, n_down: int = 2) -> float:
    """Return the estimated CFO in Hz. `rx` must start at the first preamble symbol
    (timing is assumed known to within a fraction of a symbol)."""
    N = p.n_sym
    ups = rx[: n_up * N].reshape(n_up, N)
    dns = rx[n_up * N: (n_up + n_down) * N].reshape(n_down, N)

    # --- dechirp: upchirps * conj(upchirp);  downchirps * upchirp
    du = ups * base_downchirp(p)[None, :]
    dd = dns * base_upchirp(p)[None, :]

    # --- COARSE: (peak_up + peak_down)/2 cancels the timing offset
    coarse = 0.5 * (_coarse_bins(du, N) + _coarse_bins(dd, N))     # in bins

    # --- FINE: phase advance between consecutive upchirps at the peak bin.
    # Y_{i+1}[k] = Y_i[k] * exp(j*2*pi*f_off*T_sym) for ANY bin k, so we simply use
    # the bin nearest to the coarse estimate (highest SNR).
    k = int(round(coarse)) % N
    Z = np.fft.fft(du, axis=1)[:, k]
    frac = np.angle(np.sum(Z[1:] * np.conj(Z[:-1]))) / (2 * np.pi)   # in (-0.5, 0.5]

    # --- COMBINE: integer n such that n + frac is closest to the coarse value
    n = np.round(coarse - frac)
    return float((n + frac) * p.bin_hz)
