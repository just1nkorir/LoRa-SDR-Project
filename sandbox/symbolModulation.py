import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import spectrogram

SF, BW = 7, 125e3
N = 2**SF            # samples per symbol at fs = BW
Ts = N / BW

def chirp(osr=1, up=True):
    """Base chirp sampled at fs = osr*BW."""
    fs = osr * BW
    t = np.arange(int(Ts * fs)) / fs
    k = BW / Ts                      # sweep rate (Hz/s)
    phase = 2*np.pi * (-BW/2 * t + 0.5 * k * t**2)
    c = np.exp(1j * phase)
    return c if up else np.conj(c)

# --- 1. Spectrograms of up/down chirps (oversample so the sweep is visible)
osr = 8
fs = osr * BW
fig, ax = plt.subplots(1, 2, figsize=(10, 4))
for a, up in zip(ax, [True, False]):
    x = np.tile(chirp(osr, up), 4)   # a few repeats
    f, t, S = spectrogram(x, fs=fs, nperseg=64, noverlap=56,
                          return_onesided=False)
    a.pcolormesh(t*1e3, np.fft.fftshift(f)/1e3,
                 10*np.log10(np.fft.fftshift(S, axes=0)+1e-12), shading="auto")
    a.set_title("Up-chirp" if up else "Down-chirp")
    a.set_xlabel("ms"); a.set_ylabel("kHz")
plt.show()

# --- 2. Modulate / demodulate (critically sampled, fs = BW)
base_up = chirp(1, True)

def modulate(k):
    return np.roll(base_up, -k)      # cyclic shift by k

def demodulate(sym):
    dechirped = sym * np.conj(base_up)   # multiply by base downchirp
    return np.argmax(np.abs(np.fft.fft(dechirped)))

# test
for k in [0, 5, 37, N-1]:
    assert demodulate(modulate(k)) == k

# with noise
rng = np.random.default_rng(0)
errs = 0
for _ in range(2000):
    k = rng.integers(N)
    noise = (rng.normal(size=N) + 1j*rng.normal(size=N)) * 10**(-(-10)/20)/np.sqrt(2)  # ~ -10 dB SNR
    errs += demodulate(modulate(k) + noise) != k
print("SER at -10 dB SNR:", errs/2000)