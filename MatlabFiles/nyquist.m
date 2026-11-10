Fs = 1000; % Sample rate (Hz)
Fa = 1105; % Input Frequency (Hz)
% Determine Nyquist zones
zone = 1 + floor(Fa / (Fs/2));
alias = mod(Fa, Fs);
if ~mod(zone,2) % 2nd, 4th, 6th, ... Nyquist Zone
     % Its not really a negative amplitude, but it is 180 degrees out
     % of phase, which makes it harder to see on the time domain side,
     % so we cheat to make the graphs look better.
     alias = -(Fs - alias)/Fs;
else % 3rd, 5th, 7th, ... Nyquist Zone
     alias = (alias)/Fs;
end

 % Create the analog/time domain and digital sampling vectors
 N = 2*1/abs(alias) + 1; % Number of Digital samples
 points = 256; % Analog points between digital samples
 analogIndexes = 0:1/points:N-1;
 samplingIndexes = 1:points:length(analogIndexes);
 wave = sin(2*pi*Fa/Fs*analogIndexes);
 % Time axis in units of sample periods (sample n happens at index n)
 t = analogIndexes;

 % The signal the samples really represent after aliasing
 aliasWave = sin(2*pi*alias*t);

 figure;
 plot(t, wave, 'Color', [0.7 0.7 0.7]); hold on;          % analog input (Fa)
 plot(t, aliasWave, 'b', 'LineWidth', 1.5);                % aliased output
 stem(t(samplingIndexes), wave(samplingIndexes), 'r', ...
     'filled', 'LineWidth', 1.2);                          % ADC samples
 hold off; grid on;

 xlabel('Time (sample periods, 1/Fs)');
 ylabel('Amplitude');
 title(sprintf('Fa = %g Hz sampled at Fs = %g Hz  ->  appears as %g Hz (Nyquist zone %d)', ...
     Fa, Fs, abs(alias)*Fs, zone));
 legend('Analog input', 'Aliased output', 'Samples', 'Location', 'best');
 xlim([0 N-1]);