"""
experiment_config.py -- Experiment design for the range / BER campaign
=======================================================================
Day 4 (Fri).  One place that defines WHAT is measured, so TX script, RX script and
analysis script all agree.  Import it, never re-type these numbers.

Packet structure (symbol-level, all LoRa-style chirps)
------------------------------------------------------
| 8 upchirps | 2 downchirps | 4 header symbols | 64 payload symbols | gap |
   preamble      SFD            packet id        known pseudo-random   idle
  (detect, CFO,  (timing vs     (16 bit ->        data, seeded by id
   SNR estimate)  CFO split)     4 x SF-bit)      -> RX can regenerate it
The RX does not need to "decode" to count errors: it reads the packet id from the
header, regenerates the payload with the same seed, and compares symbol by symbol.
"""
from dataclasses import dataclass, field

import numpy as np

from lora_phy import LoRaParams, build_frame, demodulate, gray_decode, gray_encode, symbols_to_bits


@dataclass
class Experiment:
    carrier_hz: float = 915e6                       # ISM band used in Colombia (902-928 MHz): confirm locally
    sfs: tuple = (7, 9, 12)                          # fast / medium / long-range
    bws: tuple = (125e3, 500e3)                      # narrow vs wide; add 250e3 if time allows
    osr: int = 8                                     # fs = 8*BW  (1 MS/s for 125 kHz)
    distances_m: tuple = (0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000)
    #   0 m = cabled bench run with step attenuators: calibrates BER-vs-SNR on real
    #   hardware and must match ber_sim.py before trusting any over-the-air numbers.
    packets_per_point: int = 200                     # 200*64*SF bits -> BER floor ~1e-5 at SF7
    n_up: int = 8
    n_down: int = 2
    n_header: int = 4
    n_payload: int = 64
    gap_symbols: int = 20
    tx_power_dbm: float = 14.0                       # record the CALIBRATED value, not the gain setting
    log_fields: tuple = ("pkt_id", "sf", "bw", "distance_m", "rssi_dbm", "snr_db",
                         "cfo_hz", "detected", "sym_errors", "bit_errors", "timestamp",
                         "tx_gain", "rx_gain", "temperature_c", "gps_lat", "gps_lon")

    def sweep(self):
        """Order of runs: loop distance OUTERMOST so you only walk to each site once,
        and inside it every (SF, BW) pair. Randomise the SF/BW order per site to
        avoid correlating configuration with slow channel changes (weather, traffic)."""
        rng = np.random.default_rng(0)
        for d in self.distances_m:
            combos = [(sf, bw) for sf in self.sfs for bw in self.bws]
            rng.shuffle(combos)
            for sf, bw in combos:
                yield d, sf, bw


def payload_symbols(pkt_id: int, p: LoRaParams, n: int) -> np.ndarray:
    """Known pseudo-random payload; seed = packet id, so TX and RX agree."""
    return np.random.default_rng(pkt_id).integers(0, p.M, n)


def header_symbols(pkt_id: int, p: LoRaParams, n_header: int) -> np.ndarray:
    """Packet id (16 bit) split into n_header chunks of SF bits (MSB first)."""
    bits = [(pkt_id >> i) & 1 for i in range(15, -1, -1)]
    bits += [0] * (n_header * p.sf - 16)
    return np.array([int("".join(map(str, bits[i * p.sf:(i + 1) * p.sf])), 2)
                     for i in range(n_header)])


def header_to_id(symbols: np.ndarray, p: LoRaParams) -> int:
    bits = "".join(format(int(s), f"0{p.sf}b") for s in symbols)
    return int(bits[:16], 2)


def make_packet(pkt_id: int, p: LoRaParams, cfg: Experiment) -> np.ndarray:
    data = np.concatenate([header_symbols(pkt_id, p, cfg.n_header),
                           payload_symbols(pkt_id, p, cfg.n_payload)])
    frame = build_frame(gray_decode(data), p, cfg.n_up, cfg.n_down)
    return np.concatenate([frame, np.zeros(cfg.gap_symbols * p.n_sym, complex)])


if __name__ == "__main__":
    cfg = Experiment()
    runs = list(cfg.sweep())
    p = LoRaParams(9, 125e3, cfg.osr)
    pkt = make_packet(1234, p, cfg)
    # loop-back test: demodulate our own packet and recover id + payload
    body = pkt[(cfg.n_up + cfg.n_down) * p.n_sym:][: (cfg.n_header + cfg.n_payload) * p.n_sym]
    rx = gray_encode(demodulate(body, p))
    assert header_to_id(rx[: cfg.n_header], p) == 1234
    assert np.array_equal(rx[cfg.n_header:], payload_symbols(1234, p, cfg.n_payload))
    print("packet loop-back OK")
    print(f"{len(runs)} (distance, SF, BW) points, "
          f"{len(runs) * cfg.packets_per_point} packets total")
    for sf in cfg.sfs:
        for bw in cfg.bws:
            q = LoRaParams(sf, bw, cfg.osr)
            t = (cfg.n_up + cfg.n_down + cfg.n_header + cfg.n_payload + cfg.gap_symbols) * q.t_sym
            print(f"SF{sf:2d} BW{bw/1e3:4.0f}k  symbol {q.t_sym*1e3:7.3f} ms  "
                  f"packet cycle {t:6.2f} s  -> {cfg.packets_per_point*t/60:5.1f} min/point")
