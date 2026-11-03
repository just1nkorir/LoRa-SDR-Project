"""
LoRa diagonal interleaver demo: shows the matrix and how it is built.

Rule used (from gr-lora_sdr, verify against the source):
    symbol[i][j] = codeword[(i - j - 1) % SF][i]

Usage:  python lora_interleaver_demo.py [SF] [CR]     (defaults: SF=4, CR=1)
"""
import sys
import numpy as np

SF = int(sys.argv[1]) if len(sys.argv) > 1 else 4
CR = int(sys.argv[2]) if len(sys.argv) > 2 else 1
N = 4 + CR  # codeword length = number of symbols in a block


def interleave(cw):
    sym = np.zeros((N, SF), dtype=int)
    for i in range(N):
        for j in range(SF):
            sym[i, j] = cw[(i - j - 1) % SF, i]
    return sym


def deinterleave(sym):
    cw = np.zeros((SF, N), dtype=int)
    for i in range(N):
        for j in range(SF):
            cw[(i - j - 1) % SF, i] = sym[i, j]
    return cw


def show(title, mat, row_label, col_label, width=6):
    print(f"\n{title}")
    print(" " * 6 + "".join(f"{col_label}{c:<{width-1}}" for c in range(mat.shape[1])))
    for r, row in enumerate(mat):
        print(f"{row_label}{r:<4}" + "".join(f"{str(v):<{width}}" for v in row))


print(f"SF = {SF}, CR = 4/{N}  ->  block = {SF} codewords of {N} bits "
      f"-> {N} symbols of {SF} bits")

# ---- 1. Symbolic matrix: which codeword bit is it? -------------------------
names = np.array([[f"c{r}[{i}]" for i in range(N)] for r in range(SF)])
show("STEP 1: codeword matrix (row r = codeword c_r, column i = bit i)",
     names, "c", "bit", width=8)

# ---- 2. Build each symbol with the rule ------------------------------------
print("\nSTEP 2: build each symbol, bit by bit")
print("        rule: symbol[i][j] = c[(i - j - 1) mod SF][bit i]")
for i in range(N):
    print(f"\n  Symbol {i}  (uses column {i})")
    for j in range(SF):
        r = (i - j - 1) % SF
        print(f"    j={j}: row = ({i} - {j} - 1) mod {SF} = {r}  ->  c{r}[{i}]")

# ---- 3. Symbolic symbol matrix ---------------------------------------------
sym_names = np.array([[names[(i - j - 1) % SF, i] for j in range(SF)]
                      for i in range(N)])
show("STEP 3: symbol matrix (row i = symbol i, column j = bit position in symbol)",
     sym_names, "sym", "j", width=8)

# ---- 4. Destination map: where does each codeword bit go? ------------------
dest = np.empty((SF, N), dtype=object)
for i in range(N):
    for j in range(SF):
        dest[(i - j - 1) % SF, i] = f"s{i}.{j}"
show("STEP 4: where each codeword bit ends up (symbol.bitposition)",
     dest, "c", "bit", width=8)

# ---- 5. Numeric example with random bits -----------------------------------
rng = np.random.default_rng(1)
cw = rng.integers(0, 2, size=(SF, N))
sym = interleave(cw)
show("STEP 5a: random codeword bits", cw, "c", "bit", width=4)
show("STEP 5b: interleaved symbols (bits j=0..SF-1 of each symbol)",
     sym, "sym", "j", width=4)
print("\n  Symbol values (j=0 as MSB):",
      [int("".join(map(str, row)), 2) for row in sym])
assert (deinterleave(sym) == cw).all()
print("  Deinterleave(interleave(x)) == x : OK")

# ---- 6. Error test ----------------------------------------------------------
bad = min(2, N - 1)
corrupt = sym.copy()
corrupt[bad] ^= 1  # flip every bit of one symbol
rx = deinterleave(corrupt)
errs = (rx != cw)
show(f"STEP 6: all {SF} bits of symbol {bad} flipped -> error pattern after "
     "deinterleaving (1 = error)", errs.astype(int), "c", "bit", width=4)
print("\n  Errors per codeword:", errs.sum(axis=1).tolist(),
      "(one each, so Hamming CR 4/7 or 4/8 can correct them)")