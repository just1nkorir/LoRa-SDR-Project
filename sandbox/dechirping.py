import numpy as np

SF = 7; N = 2**SF; k = 37; snr_db = -5
n = np.arange(N)

base = np.exp(1j*np.pi*n**2/N)                    # base upchirp (BW = fs)
sym  = np.exp(1j*2*np.pi*k*n/N) * base            # shifted chirp = symbol k

sigma2 = 10**(-snr_db/10)
noise = np.sqrt(sigma2/2)*(np.random.randn(N) + 1j*np.random.randn(N))
rx = sym + noise

dechirped = rx * np.conj(base)
spectrum = np.abs(np.fft.fft(dechirped))**2
print("Detected symbol:", np.argmax(spectrum))    # should be 37