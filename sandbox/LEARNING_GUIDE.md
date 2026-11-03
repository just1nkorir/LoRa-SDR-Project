# LoRa PHY from scratch: how to build it yourself

The four `.py` files are a reference solution. **Don't read them first.** Work through the stages below,
write each piece yourself, and use my files only to check your numbers. Each stage has a pass/fail test, so you know when it's right.
Everything is plain NumPy; every line translates to MATLAB almost 1:1 (`np.fft.fft` -> `fft`, `np.argmax` -> `max`, `x[idx]` -> `x(idx+1)`).

| File | Stage |
|---|---|
| `lora_phy.py` | 1, 2, 3, 5 (chirps, mod/demod, AWGN, CFO estimator) |
| `sim_ber.py` | 4 (BER vs SNR / SF / BW) |
| `sim_cfo.py` | 5 (CFO impact + estimator accuracy) |
| `sdr_loop.py` | 6 (USRP TX/RX, spectrum, decode; `--simulate` runs without hardware) |

---

## Stage 0: the five numbers you need

- `M = 2^SF` chips per symbol, `SF` bits per symbol.
- Symbol time `Ts = M / BW`. Raw bit rate `Rb = SF * BW / M`.
- Simulate at `fs = BW` (one sample per chip). Sample `n` of the base up-chirp is `exp(j*pi*(n^2/M - n))`; its instantaneous frequency is `n/M - 1/2` cycles/sample, so it sweeps -BW/2 -> +BW/2.
- **Data = cyclic shift.** Symbol `k` is `base[(n+k) mod M]`.
- FFT bin spacing after dechirp is `BW / M` Hz. Keep this in your head; it explains almost every result below.

## Stage 1: modulation

Write `base_upchirp(sf)` and `modulate(symbols, sf)`.
*Check:* plot `np.unwrap(np.angle(x))` -> a parabola; plot its derivative -> a ramp that wraps back when the shift `k` makes it hit +BW/2.

## Stage 2: dechirp + FFT demodulation

Multiply the received block by `conj(base)`, take an `M`-point FFT, `argmax` of the magnitude is `k`.

**Why it works** (derive this on paper, it's two lines): `base[n+k] * conj(base[n]) = const * exp(j*2*pi*k*n/M)`. The chirp cancels and a pure tone at bin `k` remains. The FFT then collects all `M` samples of energy into one bin, which is the processing gain that lets LoRa work below the noise floor.
*Check:* noiseless, all `M` symbols decode correctly.

## Stage 3: AWGN

Complex noise, `sigma^2 = Psig / SNR` split between I and Q. Define SNR **in the sample bandwidth** (here = BW), since that's the convention LoRa datasheets use.
*Check:* measure `mean(abs(noise)^2)` and confirm it matches.

## Stage 4: BER vs SNR, SF and BW

Monte-Carlo loop: random data -> modulate -> AWGN -> demod -> count bit errors; stop at ~150 errors or a max symbol count. Two things to get right:

1. **Gray mapping.** A wrong decision is almost always a neighbouring bin. Without Gray coding one bin error flips many bits; with it, one.
2. **Bandwidth does nothing to BER-vs-SNR**, because with `fs = BW` the SNR already contains it. BW enters through the **noise floor**: `N = -174 dBm/Hz + 10log10(BW) + NF`. So sweep BER against *received power in dBm*, and the curves shift ~3 dB per BW doubling. That's the sensitivity story.

*Expected results (my run):* each +1 SF moves the waterfall ~2.5 dB left (SF7 ~ -9 dB, SF12 ~ -22 dB); BW 125 -> 250 -> 500 kHz costs ~3 dB each. If your curves are not within ~1 dB of these, you have a bug (usually SNR scaling by a factor of 2, or non-unit signal power).

## Stage 5: CFO

**Model:** `rx[n] = tx[n] * exp(j*2*pi*df*n/fs)`.
**Effect:** after dechirp, the tone moves by `d = df*M/BW` bins -> every symbol decodes as `k + round(d)`. Run it uncorrected first and watch BER go to ~0.5.

**Estimator (preamble of 8 identical up-chirps):**
- *Coarse:* argmax bin (+ parabolic interpolation) gives `d` to within a fraction of a bin.
- *Fine:* the peak bin's complex value rotates by `2*pi*d` per symbol, so `angle(sum(conj(y[m]) * y[m+1]))/(2*pi)` gives the fractional part very accurately.
- *Combine:* pick the integer `n` so that `n + frac` is closest to the coarse estimate. (My first version took `argmax + frac` directly; it failed whenever the true offset sat near a bin boundary and left ~1 kHz errors. Reproduce that bug on purpose, it's instructive.)
- Unambiguous range is +/- BW/2.

**Caveat:** this assumes symbol timing is known. In real LoRa, timing offset and CFO both appear as a bin shift in the up-chirps; the standard fix uses the **down-chirps** in the sync header: `CFO = (bin_up + bin_down)/2`, `STO = (bin_up - bin_down)/2`. Implementing that is the natural next exercise.

*Check:* at -6 dB SNR my RMSE is ~5 Hz for SF7/125 kHz with 8 preamble symbols, vs a 976 Hz bin width.

## Stage 6: SDR loop (USRP N2xx)

Things that bite you on real hardware:

- **Sample rate.** N200/N210 can't do 125 kS/s. Run the radio at `OSR * BW` (I use 8x = 1 MS/s) and do `resample_poly` up on TX and down on RX. Your Stage 1-5 code stays unchanged.
- **CFO is not a toy.** Two free-running oscillators of ~1-2 ppm at 915 MHz give a relative offset of order **a few kHz**. At SF7 that is several bins; at SF12 (bin = 30 Hz) it is *hundreds* of bins. A shared 10 MHz reference removes most of it, so measure with and without.
- **Spectrum sanity check** (`plot_spectrum`): you should see a flat ~BW-wide block, a DC/LO spike at the centre, and diagonal lines in the spectrogram. No block = no TX; compressed or spiky block = gain too high.
- **Start safe.** Cable + attenuators (or antennas metres apart), low TX gain, then raise. Check with your host which frequency and power levels you're allowed to use before radiating.
- **Debug order:** `--simulate` first (full chain, no hardware) -> TX only with RX spectrum -> then decode.
- The UHD calls (`send_waveform`, `recv_num_samps`) are written from the 4.x API but untested on hardware by me. If a signature differs, `help(uhd.usrp.MultiUSRP)` is the authority.

## Suggested exercises, in order

1. Reproduce each stage's check *before* looking at my code.
2. Add a fractional-timing offset (`np.interp` / `resample`) and see what it does to the CFO estimate.
3. Implement the up/down-chirp estimator to separate CFO from STO.
4. Add Hamming coding + interleaving and compare coded vs raw BER to the Semtech sensitivity table.
5. Replace `argmax` with an SNR-based symbol-error predictor and plot SER theory vs simulation.
6. In `sdr_loop.py`, sweep TX gain and plot measured BER/SNR; compare against the Stage 4 curves.
