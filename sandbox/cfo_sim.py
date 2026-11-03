"""
cfo_sim.py -- Simulate CFO, test the estimator, show the BER impact
===================================================================
Day 3 (Thu).   python cfo_sim.py
Figure 1: estimator RMSE and outlier rate vs SNR.
Figure 2: BER vs CFO with and without correction.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from cfo import estimate_cfo
from channel import apply_cfo, awgn, ppm_to_hz
from lora_phy import LoRaParams, build_frame, demodulate, gray_decode, gray_encode, symbols_to_bits

rng = np.random.default_rng(3)
N_UP, N_DN = 8, 2


def one_trial(p, snr_db, cfo_hz, n_payload=0):
    """Build frame -> apply CFO -> add noise. Returns (rx, data symbols)."""
    data = rng.integers(0, p.M, n_payload)
    tx = build_frame(gray_decode(data), p, N_UP, N_DN)
    rx = awgn(apply_cfo(tx, cfo_hz, p.fs, rng.uniform(0, 2 * np.pi)), snr_db, rng, p.osr)
    return rx, data


def estimator_accuracy(sf=7, bw=125e3, trials=300):
    p = LoRaParams(sf, bw)
    snrs = np.arange(-20, 6, 2.0)
    rmse, outl = [], []
    # draw CFO from +/-20 ppm at 915 MHz (+/-18.3 kHz): realistic for cheap crystals
    lim = ppm_to_hz(20, 915e6)
    for snr in snrs:
        err = []
        for _ in range(trials):
            f = rng.uniform(-lim, lim)
            rx, _ = one_trial(p, snr, f)
            err.append((estimate_cfo(rx, p, N_UP, N_DN) - f) / p.bin_hz)   # error in bins
        err = np.array(err)
        bad = np.abs(err) > 0.5                  # integer-bin mistake = "outlier"
        outl.append(bad.mean())
        rmse.append(np.sqrt(np.mean(err[~bad] ** 2)) if (~bad).any() else np.nan)
    return p, snrs, np.array(rmse), np.array(outl)


def ber_vs_cfo(sf=7, bw=125e3, snr_db=-3.0, trials=40, n_payload=100):
    p = LoRaParams(sf, bw)
    cfo_bins = np.arange(-4, 4.01, 0.25)
    ber_raw, ber_cor = [], []
    pre = (N_UP + N_DN) * p.n_sym
    for cb in cfo_bins:
        f = cb * p.bin_hz
        e_raw = e_cor = 0
        for _ in range(trials):
            rx, data = one_trial(p, snr_db, f, n_payload)
            # (a) no correction: demodulate payload directly
            hat = gray_encode(demodulate(rx[pre:], p))
            e_raw += symbols_to_bits(data ^ hat, sf).sum()
            # (b) estimate from preamble, de-rotate whole frame, then demodulate
            f_hat = estimate_cfo(rx, p, N_UP, N_DN)
            rx_c = rx * np.exp(-2j * np.pi * f_hat * np.arange(len(rx)) / p.fs)
            hat = gray_encode(demodulate(rx_c[pre:], p))
            e_cor += symbols_to_bits(data ^ hat, sf).sum()
        tot = trials * n_payload * sf
        ber_raw.append(e_raw / tot); ber_cor.append(e_cor / tot)
    return cfo_bins, np.array(ber_raw), np.array(ber_cor)


if __name__ == "__main__":
    p, snrs, rmse, outl = estimator_accuracy()
    cb, raw, cor = ber_vs_cfo()
    fig, ax = plt.subplots(1, 3, figsize=(16, 4.6))
    ax[0].semilogy(snrs, rmse * p.bin_hz, "o-")
    ax[0].set(xlabel="SNR [dB]", ylabel="RMSE of non-outlier estimates [Hz]",
              title=f"CFO estimator accuracy (SF{p.sf}, {p.bw/1e3:.0f} kHz)")
    ax[1].semilogy(snrs, np.maximum(outl, 1e-3), "o-")
    ax[1].set(xlabel="SNR [dB]", ylabel="P(error > 0.5 bin)", title="Outlier (integer-bin) rate")
    ax[2].semilogy(cb, np.maximum(raw, 1e-5), "o-", label="no correction")
    ax[2].semilogy(cb, np.maximum(cor, 1e-5), "s-", label="estimate + correct")
    ax[2].set(xlabel="True CFO [bins]", ylabel="BER", title="BER vs CFO @ SNR = -3 dB"); ax[2].legend()
    for a in ax: a.grid(True, which="both", alpha=.3)
    plt.tight_layout(); plt.savefig("results/cfo_sim.png", dpi=130)
    print("bin width = %.1f Hz" % p.bin_hz)
    for s, r, o in zip(snrs, rmse, outl):
        print(f"SNR {s:6.1f} dB  RMSE {r*p.bin_hz:7.2f} Hz   outliers {o:5.1%}")
    print("saved results/cfo_sim.png")