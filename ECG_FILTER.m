% --- 1. ĐỌC DỮ LIỆU VÀ LẬT TÍN HIỆU ---
data = load('ecg_hiep_1707.txt'); 
data = 4095 - data; % Lật ngược tín hiệu do cắm ngược dây đo
fs = 200; 
%data = data(1*fs : 6*fs);
t = (0:length(data)-1) / fs ; 

% --- 2. XỬ LÝ KÊNH 2: BANDPASS & BANDSTOP (NOTCH) ---
[b_notch, a_notch] = butter(2, [49 51]/(fs/2), 'stop');
ecg_notch = filtfilt(b_notch, a_notch, data);

[b_band, a_band] = butter(4, [1 40]/(fs/2), 'bandpass');
ecg_bandpass = filtfilt(b_band, a_band, ecg_notch);

% --- 3. XỬ LÝ KÊNH 3: SAVITZKY-GOLAY ---
ecg_savgol = sgolayfilt(ecg_bandpass, 3, 21);

% --- 4. THUẬT TOÁN TÌM ĐỈNH & TÍNH NHỊP TIM (BPM) ---
% Tính ngưỡng: Chỉ bắt các đỉnh cao hơn 40% so với đỉnh cao nhất (loại bỏ sóng T, P)
nguong_cao = 0.4 * max(ecg_savgol); 

% Khoảng cách tối thiểu: 0.4 giây giữa 2 nhịp (chống nhiễu bắt nhầm 2 đỉnh liền nhau)
khoang_cach_min = 0.4 * fs; 

% Dò đỉnh bằng findpeaks
[pks, locs] = findpeaks(ecg_savgol, 'MinPeakHeight', nguong_cao, 'MinPeakDistance', khoang_cach_min);

% Tính BPM
RR_intervals = diff(locs) / fs; % Mảng thời gian giữa các đỉnh (tính bằng giây)
mean_RR = mean(RR_intervals);   % Thời gian trung bình của 1 nhịp
BPM = round(60 / mean_RR);      % Quy đổi ra Nhịp/Phút

% --- 5. VẼ ĐỒ THỊ 3 KÊNH (CÓ UPDATE MARKER VÀ BPM) ---
figure('Name', 'He Thong Đanh Gia Chat Luong Tim Mach', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

% Kênh 1
subplot(3, 1, 1);
plot(t, data, 'Color', '#4682B4'); 
title('Kênh 1: ECG raw');
ylabel('Amplitude'); grid on;

% Kênh 2
subplot(3, 1, 2);
plot(t, ecg_bandpass, 'Color', '#4682B4');
title('Kênh 2: Lọc Passband [1-40] Hz + Bandstop [49-51] Hz');
ylabel('Amplitude'); grid on;

% Kênh 3 (Vẽ sóng + Chấm đỏ + In tiêu đề BPM)
subplot(3, 1, 3);
plot(t, ecg_savgol, 'Color', '#4682B4');
hold on;
% Lấy tọa độ thời gian t(locs) và độ cao đỉnh (pks) để vẽ chấm tròn đỏ
plot(t(locs), pks, 'ro', 'MarkerFaceColor', 'red', 'MarkerSize', 5); 
hold off;

% In kết quả BPM thẳng lên tiêu đề với font chữ nổi bật
title_str = sprintf('Kênh 3: Lọc SavGol - Nhịp tim trung bình: %d BPM', BPM);
title(title_str, 'Color', 'red', 'FontWeight', 'bold', 'FontSize', 11);
xlabel('Time (s)'); 
ylabel('Amplitude'); grid on;
