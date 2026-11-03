"""
lora_phy.py  --  minimal LoRa-style chirp-spread-spectrum PHY (no coding/interleaving/whitening)

Conventions
-----------
* Baseband, complex samples, sampled at fs = BW  (1 sample per chip, "critical sampling").
* M = 2**SF chips per symbol, symbol duration Ts = M / BW.
* A symbol carries SF bits: the value k (0..M-1) is a cyclic shift of the base up-chirp.
* Unit signal power (|x| = 1) so SNR bookkeeping is trivial.
"""
import numpy as np


# ---------------------------------------------------------------- chirps
def base_upchirp(sf):
    """Up-chirp sweeping -BW/2 -> +BW/2 over M samples."""
    M = 1 << sf
    n = np.arange(M)
    return np.exp(1j * np.pi * (n**2 / M - n))


def base_downchirp(sf):
    return np.conj(base_upchirp(sf))


# ---------------------------------------------------------------- gray map
def gray(x):
    x = np.asarray(x)
    return x ^ (x >> 1)

def gray_inv(g):
    g = np.asarray(g)
    s = g.copy()
    sh = g >> 1
    while sh.any():
        s ^= sh
        sh >>= 1
    return s

# ---------------------------------------------------------------- mod / demod
def modulate(symbols, sf):
    """symbols: int array of values in [0, 2**sf). Returns concatenated waveform."""
    M = 1 << sf
    base = base_upchirp(sf)
    print(base)
    n = np.arange(M)
    idx = (n[None, :] + np.asarray(symbols)[:, None]) % M     # cyclic shift by k
    return base[idx].ravel()

def dechirp_fft(rx, sf):
    """Multiply each symbol-length block by the conjugate base chirp, FFT it.
    Returns complex spectra, shape (n_symbols, M)."""
    M = 1 << sf
    blocks = np.asarray(rx)[: (len(rx) // M) * M].reshape(-1, M)
    return np.fft.fft(blocks * base_downchirp(sf)[None, :], axis=1)

def demodulate(rx, sf):
    """Returns (symbol estimates, spectra)."""
    Y = dechirp_fft(rx, sf)
    return np.argmax(np.abs(Y), axis=1), Y

# ---------------------------------------------------------------- channel
def add_awgn(x, snr_db, rng):
    """Add complex AWGN so that (signal power)/(noise power) = snr_db, both in the
    sampling bandwidth (= BW here)."""
    p_sig = np.mean(np.abs(x) ** 2)
    p_noise = p_sig / 10 ** (snr_db / 10)
    noise = np.sqrt(p_noise / 2) * (rng.standard_normal(x.shape) + 1j * rng.standard_normal(x.shape))
    return x + noise

def noise_floor_dbm(bw_hz, nf_db=6.0):
    """Thermal noise power in dBm:  -174 dBm/Hz + 10log10(BW) + receiver noise figure."""
    return -174 + 10 * np.log10(bw_hz) + nf_db

def apply_cfo(x, cfo_hz, fs, phase0=0.0):
    n = np.arange(len(x))
    return x * np.exp(1j * (2 * np.pi * cfo_hz * n / fs + phase0))

# ---------------------------------------------------------------- CFO estimation
def estimate_cfo(preamble_rx, sf, bw):
    """Estimate CFO (Hz) from a received run of identical base up-chirps (symbol value 0),
    assuming symbol timing is already known.

    Dechirping turns a CFO of df Hz into a tone at  d = df*M/BW  bins.
      * coarse part: which FFT bin holds the peak (integer bins)
      * fine part  : phase rotation of that bin from one symbol to the next,
                     = 2*pi*d  (mod 2*pi)  -> fractional bins
    Unambiguous range: +/- BW/2.
    """
    M = 1 << sf
    Y = dechirp_fft(preamble_rx, sf)                    # (n_sym, M)
    mag = np.abs(Y).sum(axis=0)
    k0 = int(np.argmax(mag))                            # coarse: integer bin
    # parabolic interpolation around the peak -> coarse fractional estimate
    a, b, c = mag[(k0 - 1) % M], mag[k0], mag[(k0 + 1) % M]
    d_coarse = k0 + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
    if d_coarse > M / 2:
        d_coarse -= M
    # fine: symbol-to-symbol phase rotation of the peak bin = 2*pi*d (mod 2*pi)
    y = Y[:, k0]
    frac = np.angle(np.sum(np.conj(y[:-1]) * y[1:])) / (2 * np.pi)     # (-0.5, 0.5]
    # pick the integer n so that n + frac is closest to the coarse estimate
    d_bins = frac + np.round(d_coarse - frac)
    return d_bins * bw / M