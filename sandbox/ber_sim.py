"""
ber_sim.py -- BER vs SNR for different spreading factors and bandwidths
=======================================================================
Day 2 (Wed).   Usage:   python ber_sim.py            (full run, a few minutes)
                        python ber_sim.py --quick    (fast sanity run)

Two things to understand about the results:

1. In the *normalised* baseband model, BER vs in-band SNR depends ONLY on SF.
   BW cancels out: a symbol has M*osr samples, noise power scales with BW, and
   the processing gain is M = 2^SF either way. So the three bandwidth curves in
   figure 1 lie on top of each other -- that's a correct result, not a bug.

2. Bandwidth matters through the noise floor: N = -174 + 10log10(BW) + NF.
   Doubling BW raises the noise floor 3 dB, so sensitivity gets 3 dB worse.
   Figure 2 therefore plots BER vs RECEIVED POWER, where the BW curves separate.
"""
from __future__ import annotations

import argparse
import csv
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from channel import awgn, noise_floor_dbm
from lora_phy import LoRaParams, demodulate, gray_decode, gray_encode, modulate, symbols_to_bits


def simulate_ber(sf, bw, snr_db, rng, osr=1, target_bit_errors=200, max_symbols=40_000):
    """Monte-Carlo BER/SER at one operating point.

    Stops when `target_bit_errors` errors were collected (enough for a ~10 %
    confidence interval) or `max_symbols` were simulated (sets the BER floor).
    """
    p = LoRaParams(sf, bw, osr)
    batch = max(16, 2 ** 19 // p.n_sym)           # keep memory use ~constant for all SF
    n_sym = n_bit_err = n_sym_err = 0
    while n_bit_err < target_bit_errors and n_sym < max_symbols:
        data = rng.integers(0, p.M, batch)                       # information symbols
        tx = modulate(gray_decode(data), p)                      # inverse-Gray -> chirp
        rx = awgn(tx, snr_db, rng, osr)                          # channel
        data_hat = gray_encode(demodulate(rx, p))                # dechirp+FFT -> Gray
        n_sym_err += int(np.count_nonzero(data != data_hat))
        diff = symbols_to_bits(data ^ data_hat, sf)              # XOR -> bit errors
        n_bit_err += int(diff.sum())
        n_sym += batch
    return n_bit_err / (n_sym * sf), n_sym_err / n_sym, n_sym


def snr_grid(sf):
    """SNR sweep centred on the approximate demodulation threshold:
    about -7.5 dB at SF7, then 2.5 dB lower for every extra SF."""
    centre = -7.5 - 2.5 * (sf - 7)
    return np.arange(centre - 4.0, centre + 3.01, 0.5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--nf", type=float, default=6.0, help="receiver noise figure [dB]")
    a = ap.parse_args()

    sfs = [7, 8, 9, 10, 11, 12] if not a.quick else [7, 9]
    bws = [125e3, 250e3, 500e3]
    max_sym = 40_000 if not a.quick else 3_000
    rng = np.random.default_rng(1)
    rows = []

    t0 = time.time()
    for sf in sfs:
        for bw in bws:
            for snr in snr_grid(sf):
                ber, ser, n = simulate_ber(sf, bw, snr, rng, max_symbols=max_sym)
                rows.append((sf, bw, snr, ber, ser, n))
            print(f"SF{sf} BW{bw/1e3:.0f}k done  ({time.time()-t0:.0f}s)")

    with open("results/ber_vs_snr.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sf", "bw_hz", "snr_db", "ber", "ser", "n_symbols"])
        w.writerows(rows)
    R = np.array(rows)

    floor = 0.5 / (max_sym * 12)                  # plot zero-error points at this floor
    # ---- Figure 1: BER vs SNR, colour = SF, marker = BW (curves overlap by design)
    fig, ax = plt.subplots(1, 2, figsize=(13, 5))
    cmap = plt.get_cmap("viridis")
    for i, sf in enumerate(sfs):
        for bw, mk in zip(bws, "os^"):
            m = (R[:, 0] == sf) & (R[:, 1] == bw)
            ax[0].semilogy(R[m, 2], np.maximum(R[m, 3], floor), mk + "-", ms=4, lw=1,
                           color=cmap(i / max(1, len(sfs) - 1)),
                           label=f"SF{sf}" if bw == bws[0] else None)
    ax[0].set(xlabel="In-band SNR [dB]", ylabel="BER", ylim=(floor, 1),
              title="BER vs SNR (markers = 125/250/500 kHz overlap)")
    ax[0].grid(True, which="both", alpha=.3); ax[0].legend()

    # ---- Figure 2: BER vs received power -> BW shifts the curve by 10log10(BW ratio)
    for sf, col in zip(sfs[:1] + sfs[-1:], ["tab:blue", "tab:red"]):
        for bw, ls in zip(bws, ["-", "--", ":"]):
            m = (R[:, 0] == sf) & (R[:, 1] == bw)
            prx = R[m, 2] + noise_floor_dbm(bw, a.nf)
            ax[1].semilogy(prx, np.maximum(R[m, 3], floor), ls, color=col,
                           label=f"SF{sf}, {bw/1e3:.0f} kHz")
    ax[1].set(xlabel="Received power [dBm]", ylabel="BER", ylim=(floor, 1),
              title=f"BER vs received power (NF={a.nf:.0f} dB)")
    ax[1].grid(True, which="both", alpha=.3); ax[1].legend()
    plt.tight_layout(); plt.savefig("results/ber_vs_snr.png", dpi=130)
    print("saved results/ber_vs_snr.png and .csv")


if __name__ == "__main__":
    main()
