# LoRa-style PHY: simulation + SDR (week plan)

Python 3.10+, `numpy scipy matplotlib`; `uhd` (UHD Python bindings) only for `usrp_loop.py`.

| Day | Task | File | Run |
|-----|------|------|-----|
| Tue | Symbol modulation + dechirp/FFT demodulation | `lora_phy.py` | `python lora_phy.py` (self-test) |
| Wed | AWGN channel; BER vs SNR for SF / BW | `channel.py`, `ber_sim.py` | `python ber_sim.py` |
| Thu | CFO simulation + estimator | `cfo.py`, `cfo_sim.py` | `python cfo_sim.py` |
| Thu | SDR transmit/capture + spectrum | `usrp_loop.py` | see header of the file |
| Fri | Experiment design, cleanup, review | `experiment_config.py` | `python experiment_config.py` |

Outputs go to `results/` (PNG + CSV).

## Sanity checks (what "correct" looks like)
- Noiseless round trip for SF7-12 (and osr 1 and 4) -> `lora_phy.py` self-test passes.
- BER waterfall near -8 dB at SF7, about 2.5 dB lower per extra SF.
- BER vs SNR identical for all BW (normalised model); curves separate vs received power.
- CFO estimator: no outliers above about -10 dB SNR at SF7; RMSE of a few Hz at 0 dB.
- Uncorrected CFO >= 1 bin -> BER 15-30 %; corrected -> ~0.
- First hardware run: spectrum ~BW wide, centred, DC/LO spike visible, peak |x| well below 1.0
  (otherwise lower gain). Cabled with attenuator first; compare measured BER-vs-SNR with `ber_sim.py`.

## Known simplifications (mention to supervisor)
- No FEC, whitening, interleaving, explicit header, CRC (raw modulation BER on purpose).
- CFO estimator assumes timing is known to under a symbol; no sampling-clock offset (SFO) model.
- Frame sync in `usrp_loop.py` is a crude energy detector. A proper detector is the next step.
- AWGN only: no fading/multipath yet.

## Friday review: agenda for supervisor
1. Show: BER vs SNR (fig), CFO estimator (fig), captured spectrum (fig).
2. Decide: SF/BW grid, distance list, packets per point, TX power calibration method.
3. Open questions: daughterboard model + gain range, antenna/height, legal TX power/band in Colombia,
   comparison against a commercial LoRa card (which model, same SF/BW?), GPS logging.
4. Next week: frame synchronisation (STO), packet-level RX script, bench BER calibration with attenuators.
