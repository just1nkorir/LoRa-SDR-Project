nMax = 9;          % avoid naming a variable "max" (it hides the built-in max())
fs   = 1000;
N    = 5000;
f0   = 2;          % fundamental frequency in Hz

scope = timescope('SampleRate', fs, ...
                  'TimeSpanSource', 'property', ...
                  'TimeSpan', N/fs, ...
                  'YLimits', [-1.5 1.5], ...
                  'Title', 'Square wave from odd harmonics');

wavesum = zeros(N,1);
for i = 1:2:nMax
    % dsp.SineWave(Amplitude, Frequency[Hz], PhaseOffset, ...)
    wave = dsp.SineWave(1/i, i*f0, 0, ...
        'SamplesPerFrame', N, 'SampleRate', fs);
    wavesum = wavesum + wave();

    reset(scope);          % redraw the same time window each pass
    scope(wavesum);        % wavesum is a variable, so no ()
    pause(0.5);
end