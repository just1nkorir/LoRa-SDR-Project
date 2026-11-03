"""
channel.py -- Channel impairments for baseband simulation
=========================================================
Day 2 (Wed): AWGN.   Day 3 (Thu): carrier frequency offset (CFO).
"""
from __future__ import annotations

import numpy as np


def awgn(x: np.ndarray, snr_db: float, rng: np.random.Generator, osr: int = 1) -> np.ndarray:
    """Add complex white Gaussian noise so that the IN-BAND SNR equals snr_db.

    In-band SNR = signal power / (N0 * BW), which is the "SNR" LoRa datasheets
    quote (e.g. SF12 demodulates down to about -20 dB).

    With oversampling the noise spreads over fs = osr*BW, so the total noise
    power per sample is osr times larger than the in-band noise power:
        sigma^2 = Ps * osr / SNR_linear
    Real and imaginary parts each get sigma^2 / 2.
    """
    ps = np.mean(np.abs(x) ** 2)                       # measured signal power
    sigma2 = ps * osr / (10 ** (snr_db / 10))
    noise = np.sqrt(sigma2 / 2) * (rng.standard_normal(x.shape) + 1j * rng.standard_normal(x.shape))
    return x + noise


def apply_cfo(x: np.ndarray, cfo_hz: float, fs: float, phase0: float = 0.0) -> np.ndarray:
    """Carrier frequency offset: multiply by a rotating phasor.

    Cause in hardware: TX and RX local oscillators are not on exactly the same
    frequency (crystal tolerance in ppm * carrier frequency).
    Example: 5 ppm at 915 MHz = 4.6 kHz.
    """
    n = np.arange(len(x))
    return x * np.exp(1j * (2 * np.pi * cfo_hz * n / fs + phase0))


def ppm_to_hz(ppm: float, f_carrier_hz: float) -> float:
    return ppm * 1e-6 * f_carrier_hz


def noise_floor_dbm(bw_hz: float, nf_db: float = 6.0) -> float:
    """Thermal noise floor: -174 dBm/Hz + 10log10(BW) + receiver noise figure.
    Used to convert SNR to received power (RSSI) when comparing bandwidths."""
    return -174.0 + 10 * np.log10(bw_hz) + nf_db
