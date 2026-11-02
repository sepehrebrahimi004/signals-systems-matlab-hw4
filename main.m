%MAIN  Signals & Systems - MATLAB homework 4: speech spectrogram, moving-average
%      filtering and a scalar Kalman filter for denoising.
%
%   The assignment recorded 10 s from the microphone. To make the script
%   reproducible, it uses MATLAB's built-in speech sample (the word "MATLAB",
%   load mtlb) by default; set RECORD = true to record your own voice.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));
rng(4);
RECORD = false;

%% A  Recording and spectrogram
if RECORD
    Fs = 44100;
    rec = audiorecorder(Fs, 16, 1);
    disp('recording 10 s ...'); recordblocking(rec, 10);
    x = getaudiodata(rec);
else
    s = load('mtlb');                     % speech sample shipped with MATLAB
    x = s.mtlb;  Fs = s.Fs;
end
x = x(:) / max(abs(x));
fig = figure('Visible', 'off', 'Position', [100 100 900 420]);
spectrogram(x, hamming(256), 192, 512, Fs, 'yaxis');
title('Spectrogram of the speech sample ("MATLAB")');
save_figure(fig, 'a_spectrogram');

%% B  Moving-average filter (N = 50)
N = 50;
b = ones(1, N)/N;
y_ma = filter(b, 1, x);
[H, f] = freqz(b, 1, 2048, Fs);
fig = figure('Visible', 'off', 'Position', [100 100 1000 380]);
subplot(1, 2, 1); plot(f, 20*log10(abs(H))); grid on; ylim([-60 3]);
xline(Fs/N, 'r--', sprintf('first null F_s/N = %.0f Hz', Fs/N));
xlabel('frequency (Hz)'); ylabel('dB'); title(sprintf('Moving average, N = %d: a low-pass (sinc-shaped) filter', N));
subplot(1, 2, 2); t = (0:numel(x)-1)/Fs;
plot(t, x, t, y_ma); grid on; xlabel('time (s)'); legend('speech', 'filtered');
title('Most of the speech band (> 150 Hz) is removed');
save_figure(fig, 'b_moving_average');

%% C  AWGN at 10 dB and a scalar Kalman filter
g = awgn(x, 10, 'measured');
snr_db = @(ref, est) 10*log10(sum(ref.^2) / sum((ref - est).^2));

kalman = @(z, Q, R) scalar_kalman(z, Q, R);
Qs = logspace(-6, -1, 26);
R = var(g - x);                                   % measurement-noise variance
snr_k = arrayfun(@(Q) snr_db(x, kalman(g, Q, R)), Qs);
[best, ib] = max(snr_k);
xk = kalman(g, Qs(ib), R);
xk_orig = kalman(g, 1e-5, 0.01);                  % the tuning used in the original report

fprintf('C  noisy input SNR            %.1f dB\n', snr_db(x, g));
fprintf('   Kalman, original Q, R       %.1f dB\n', snr_db(x, xk_orig));
fprintf('   Kalman, best Q = %.1e       %.1f dB\n', Qs(ib), best);
fprintf('   moving average (N = 50)     %.1f dB\n', snr_db(x, filter(b, 1, g)));

fig = figure('Visible', 'off', 'Position', [100 100 1000 380]);
subplot(1, 2, 1); semilogx(Qs, snr_k, 'o-'); grid on; hold on;
yline(snr_db(x, g), 'k--', 'noisy input');
xlabel('process-noise variance Q'); ylabel('output SNR (dB)');
title('Kalman filter: Q trades noise removal against lag');
subplot(1, 2, 2); seg = round(0.4*Fs):round(0.45*Fs);
plot(t(seg), g(seg), 'Color', [0.7 0.7 0.7]); hold on;
plot(t(seg), x(seg), 'k', t(seg), xk(seg), 'r', 'LineWidth', 1.2); grid on;
legend('noisy', 'clean', 'Kalman (best Q)'); xlabel('time (s)'); title('50 ms of the signal');
save_figure(fig, 'c_kalman');

function xh = scalar_kalman(z, Q, R)
%SCALAR_KALMAN  Random-walk model x_k = x_{k-1} + w (var Q), z_k = x_k + v (var R).
    xh = zeros(size(z));
    P = 1;
    for k = 2:numel(z)
        P = P + Q;                         % predict
        K = P / (P + R);                   % gain
        xh(k) = xh(k-1) + K*(z(k) - xh(k-1));
        P = (1 - K) * P;                   % update
    end
end
