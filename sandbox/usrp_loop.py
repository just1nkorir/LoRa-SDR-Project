"""
usrp_loop.py -- Simple USRP transmit-and-capture loop + spectrum inspection
===========================================================================
Day 3 (Thu).  NOT run on hardware by me: written against the UHD 4.x Python API
(`pip`/apt package `uhd`). Check function names against your installed version.

Setup assumed: two USRP N200/N210, one TX one RX, connected through a CABLE and a
30-40 dB attenuator for the first test (never connect TX straight into RX!).
Each N2xx needs its own IP (default 192.168.10.2 -> change one of them).

Example:
  python usrp_loop.py --tx-args "addr=192.168.10.2" --rx-args "addr=192.168.10.3" \
         --freq 915e6 --sf 7 --bw 125e3 --osr 8 --tx-gain 0 --rx-gain 10

What it does
  1. Builds a LoRa-style frame (preamble + downchirps + payload) + idle gap
  2. TX device sends that frame repeatedly (send_waveform loops the buffer)
  3. RX device captures a block of IQ samples
  4. Saves the capture (.npy) and plots PSD + spectrogram (inspect the spectrum:
     is the signal ~BW wide, centred, not clipped, DC spike/LO leakage visible?)
  5. Finds the burst, runs estimate_cfo() on it
"""
import argparse
import json
import threading
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal

from cfo import estimate_cfo
from lora_phy import LoRaParams, build_frame

N_UP, N_DN = 8, 2


def make_tx_waveform(p, n_payload=20, gap_symbols=20, amp=0.5, seed=0):
    """One frame followed by silence. amp<1 keeps the DAC away from clipping."""
    rng = np.random.default_rng(seed)
    payload = rng.integers(0, p.M, n_payload)
    frame = build_frame(payload, p, N_UP, N_DN)
    wave = np.concatenate([frame, np.zeros(gap_symbols * p.n_sym, complex)])
    return (amp * wave).astype(np.complex64), payload


def find_burst(x, fs, thresh_db=10.0):
    """Energy detector: first sample whose smoothed power is `thresh_db` above the
    noise floor (estimated as the median power). Returns start index or None."""
    win = int(fs * 20e-6) or 1                                   # 20 us moving average
    pw = np.convolve(np.abs(x) ** 2, np.ones(win) / win, mode="same")
    floor = np.median(pw)
    above = np.where(pw > floor * 10 ** (thresh_db / 10))[0]
    return int(above[0]) if len(above) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tx-args", default="addr=192.168.10.2")
    ap.add_argument("--rx-args", default="addr=192.168.10.3")
    ap.add_argument("--freq", type=float, default=915e6)
    ap.add_argument("--sf", type=int, default=7)
    ap.add_argument("--bw", type=float, default=125e3)
    ap.add_argument("--osr", type=int, default=8, help="fs = osr*bw; N2xx needs 100e6/fs integer")
    ap.add_argument("--tx-gain", type=float, default=0.0)
    ap.add_argument("--rx-gain", type=float, default=10.0)
    ap.add_argument("--capture-s", type=float, default=0.5)
    a = ap.parse_args()

    import uhd                                                    # imported late: sim scripts don't need it

    p = LoRaParams(a.sf, a.bw, a.osr)
    wave, payload = make_tx_waveform(p)
    tx = uhd.usrp.MultiUSRP(a.tx_args)
    rx = uhd.usrp.MultiUSRP(a.rx_args)

    # --- TX in a background thread: send_waveform repeats the buffer for `duration` s
    dur = a.capture_s + 1.0
    t_tx = threading.Thread(target=tx.send_waveform,
                            args=(wave, dur, a.freq, p.fs, [0], a.tx_gain))
    t_tx.start()
    time.sleep(0.5)                                               # let TX settle / PLL lock

    # --- RX: blocking capture of N samples
    n = int(a.capture_s * p.fs)
    iq = rx.recv_num_samps(n, a.freq, p.fs, [0], a.rx_gain)[0]
    t_tx.join()

    np.save("results/capture.npy", iq.astype(np.complex64))
    json.dump(dict(freq=a.freq, sf=p.sf, bw=p.bw, fs=p.fs, tx_gain=a.tx_gain,
                   rx_gain=a.rx_gain, time=time.time()), open("results/capture.json", "w"))
    print(f"captured {len(iq)} samples, peak |x| = {np.max(np.abs(iq)):.3f}"
          " (ADC clips near 1.0: lower rx-gain if close)")

    # --- Spectrum inspection
    f, Pxx = signal.welch(iq, p.fs, nperseg=4096, return_onesided=False)
    f, Pxx = np.fft.fftshift(f), np.fft.fftshift(Pxx)
    fig, ax = plt.subplots(1, 2, figsize=(13, 4.5))
    ax[0].plot((f + a.freq) / 1e6, 10 * np.log10(Pxx + 1e-20))
    ax[0].axvspan((a.freq - p.bw / 2) / 1e6, (a.freq + p.bw / 2) / 1e6, alpha=.15, label="expected BW")
    ax[0].set(xlabel="Frequency [MHz]", ylabel="PSD [dB/Hz, uncalibrated]", title="Received spectrum"); ax[0].legend()
    ff, tt, S = signal.spectrogram(iq, p.fs, nperseg=1024, return_onesided=False)
    ax[1].pcolormesh(tt * 1e3, np.fft.fftshift(ff) / 1e3, 10 * np.log10(np.fft.fftshift(S, axes=0) + 1e-20), shading="auto")
    ax[1].set(xlabel="Time [ms]", ylabel="Baseband freq [kHz]", title="Spectrogram (chirps = diagonal lines)")
    plt.tight_layout(); plt.savefig("results/capture_spectrum.png", dpi=130)

    # --- CFO from the captured burst
    s0 = find_burst(iq, p.fs)
    if s0 is None:
        print("no burst found -> check gains / frequency / cabling")
        return
    need = (N_UP + N_DN) * p.n_sym
    cfo = estimate_cfo(iq[s0: s0 + need], p, N_UP, N_DN)
    print(f"burst at sample {s0}; estimated CFO = {cfo:.1f} Hz = {cfo / a.freq * 1e6:.2f} ppm")


if __name__ == "__main__":
    main()
