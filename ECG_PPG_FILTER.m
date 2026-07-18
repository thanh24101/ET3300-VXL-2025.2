% --- 1. ĐỌC DỮ LIỆU TỪ THẺ NHỚ ---
% Đọc ma trận từ file (Cột 1: ECG, Cột 2: PPG)
data_matrix = readmatrix('ecg_hiep_1707.txt'); 
fs = 200; 

% --- CẮT DỮ LIỆU  ---
thoi_gian_bat_dau = 4; 
thoi_gian_ket_thuc = 20; 

% Tính toán vị trí hàng (index) tương ứng với thời gian
idx_start = thoi_gian_bat_dau * fs + 1;
idx_end = thoi_gian_ket_thuc * fs;

% Ghi đè ma trận, chỉ giữ lại phần dữ liệu trong dải đã chọn
data_matrix = data_matrix(idx_start:idx_end, :);

% Trích xuất tín hiệu thô
ecg_raw = 4095 - data_matrix(:, 1); % Kênh 1: Lật tín hiệu ECG 
ppg_raw = data_matrix(:, 2);        % Kênh 2: Tín hiệu PPG hồng ngoại thô

% Tạo trục thời gian tự động khớp với chiều dài dữ liệu mới
N = length(ecg_raw);

% Cộng thêm thời gian bắt đầu để trục X hiển thị đúng mốc 11s - 16s
t = (0:N-1) / fs + thoi_gian_bat_dau;

% --- 2. LUỒNG XỬ LÝ ECG (Luồng gộp) ---
% Lọc Notch [49-51Hz] để cắt nhiễu điện lưới
[b_notch, a_notch] = butter(2, [49 51]/(fs/2), 'stop');
ecg_notch = filtfilt(b_notch, a_notch, ecg_raw);

% Lọc Bandpass [1-40Hz] để cắt nhiễu cơ bắp và trôi đường nền
[b_band, a_band] = butter(4, [1 40]/(fs/2), 'bandpass');
ecg_bp = filtfilt(b_band, a_band, ecg_notch);

% Làm mượt Savitzky-Golay (Tín hiệu ECG Cuối cùng)
ecg_final = sgolayfilt(ecg_bp, 3, 21);

% --- 3. LUỒNG XỬ LÝ PPG ---
% Lọc Bandpass [1-10Hz] bóc tách sóng mạch đập
bpFilt_ppg = designfilt('bandpassiir', 'FilterOrder', 4, ...
         'HalfPowerFrequency1', 1.0, 'HalfPowerFrequency2', 10.0, ...
         'SampleRate', fs, 'DesignMethod', 'butter');

% Tín hiệu PPG Cuối cùng
ppg_final = filtfilt(bpFilt_ppg, ppg_raw);
ppg_final = -ppg_final; % Lật ngược pha để chóp tâm thu vút lên trên

% =========================================================================
% --- 4. VẼ ĐỒ THỊ 4 BẢNG (CHUẨN FORM TRÌNH BÀY BÁO CÁO) ---
% =========================================================================
figure('Name', 'He Thong Đanh Gia Chat Luong Tim Mach', 'NumberTitle', 'off', 'Position', [100 100 1000 600]);

% Tiêu đề tổng (Tự động tính tổng số giây thu thập được)
sgtitle(sprintf('KẾT QUẢ XỬ LÝ TÍN HIỆU (%.1f giây)', t(end)), ...
         'FontSize', 16, 'FontWeight', 'bold');

% --- BẢNG 1: ECG RAW ---
subplot(4, 1, 1);
plot(t, ecg_raw, 'LineWidth', 0.8); % Đỏ sẫm
title('1. ECG RAW (Tín hiệu gốc nhiễu nhiều)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('ADC Value', 'FontWeight', 'bold');
xlim([t(1) t(end)]); grid on; grid minor;

% --- BẢNG 2: ECG FINAL ---
subplot(4, 1, 2);
plot(t, ecg_final, 'LineWidth', 1); % Cam sáng
title('2. ECG (Làm mượt Savitzky-Golay - Kết quả cuối)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Amplitude', 'FontWeight', 'bold');
xlim([t(1) t(end)]); grid on; grid minor;

% --- BẢNG 3: PPG RAW ---
subplot(4, 1, 3);
plot(t, ppg_raw, 'LineWidth', 1); % Xanh lá đậm
title('3. PPG RAW (Tín hiệu hồng ngoại gốc)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Raw Value', 'FontWeight', 'bold');
xlim([t(1) t(end)]); grid on; grid minor;

% --- BẢNG 4: PPG FINAL ---
subplot(4, 1, 4);
plot(t, ppg_final, 'LineWidth', 1); % Xanh lá mạ
title('4. PPG (Đã lọc Bandpass 1-10Hz - Sóng mạch đập)', 'FontSize', 10, 'FontWeight', 'bold');
xlabel('Time (seconds)', 'FontWeight', 'bold', 'FontSize', 11);
ylabel('Amplitude', 'FontWeight', 'bold');
xlim([t(1) t(end)]); grid on; grid minor;

