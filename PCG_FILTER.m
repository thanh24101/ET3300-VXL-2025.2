%% 1. ĐỌC DỮ LIỆU VÀ TIỀN XỬ LÝ
FILENAME = 'pcg_minh_1707.txt'; % Tên file log dữ liệu thu từ ESP32 qua Tera Term
Fs = 4000;                % Tần số lấy mẫu (8kHz)

% Kiểm tra tính hợp lệ của file
if ~exist(FILENAME, 'file')
    error('Không tìm thấy file "%s". Hãy đảm bảo file cùng thư mục với script này.', FILENAME);
end

% Đọc dữ liệu
raw_data = readmatrix(FILENAME);
%raw_data = raw_data(1*Fs : 7*Fs);
N = length(raw_data);
t = (0:N-1) / Fs;

% Khử thành phần một chiều (DC Offset) và nhiễu trôi đường nền
detrended_signal = detrend(raw_data - mean(raw_data));
% Chuẩn hóa biên độ tín hiệu gốc về khoảng [-1, 1]
detrended_signal = detrended_signal / max(abs(detrended_signal));

%% 2. LUỒNG 1: PHÂN TÍCH NHỊP TIM S1, S2 (Dải 20Hz - 200Hz)
% Thiết kế bộ lọc Butterworth dải thông bậc 4
Wn_low = [20, 200] / (Fs / 2);
[b_low, a_low] = butter(4, Wn_low, 'bandpass');
sig_S1S2 = filtfilt(b_low, a_low, detrended_signal);
sig_S1S2 = sig_S1S2 / max(abs(sig_S1S2)); % Chuẩn hóa

% Trích xuất đường bao năng lượng Shannon
epsilon = 1e-10;
shannon_energy = -(sig_S1S2.^2) .* log(sig_S1S2.^2 + epsilon);

% Làm mịn đường bao bằng Moving Average (Cửa sổ 30ms)
window_len = round((30 / 1000) * Fs);
b_smooth = ones(1, window_len) / window_len;
envelope = filtfilt(b_smooth, 1, shannon_energy);
envelope = envelope / max(envelope);

% TÌM ĐỈNH (PEAK DETECTION) để đếm nhịp và nhận diện S3/S4
% Ngưỡng chiều cao 20%, khoảng cách giữa 2 đỉnh tối thiểu 0.15s
[pks, locs] = findpeaks(envelope, t, 'MinPeakHeight', 0.2, 'MinPeakDistance', 0.15);
num_peaks = length(pks);
recording_time = t(end);
peaks_per_sec = num_peaks / recording_time;

%% 3. LUỒNG 2: TÌM TẠP ÂM BỆNH LÝ MURMUR (Dải 200Hz - 600Hz)
Wn_high = [200, 600] / (Fs / 2);
[b_high, a_high] = butter(4, Wn_high, 'bandpass');
sig_murmur = filtfilt(b_high, a_high, detrended_signal);

% Định lượng năng lượng nhiễu bệnh lý: Tính tỷ lệ RMS
rms_murmur = rms(sig_murmur);
rms_normal = rms(sig_S1S2);
murmur_ratio = rms_murmur / rms_normal;

BPM_calculated = round((60*num_peaks/2)/recording_time);

%% 4. LOGIC CHẨN ĐOÁN (DECISION TREE)
% Cài đặt các ngưỡng chẩn đoán (Cần vi chỉnh khi test thực tế)
MURMUR_THRESHOLD = 0.15;  % Năng lượng cao tần > 15% là có tiếng thổi
MAX_NORMAL_PEAKS = 4.0;   % > 4 đỉnh/giây là có thể xuất hiện S3/S4
MIN_NORMAL_PEAKS = 1.5;   % < 1.5 đỉnh/giây là nhịp quá chậm hoặc đo lỗi

disp('==================================================');
disp('    BÁO CÁO ĐÁNH GIÁ CHẤT LƯỢNG TIM MẠCH (PCG)    ');
disp('==================================================');
fprintf('Thời gian đo: %.2f giây\n', recording_time);
fprintf('Tổng số đỉnh phát hiện được: %d đỉnh\n', num_peaks);
fprintf('Tỷ lệ năng lượng tạp âm (200-600Hz): %.2f%%\n', murmur_ratio * 100);
disp('--------------------------------------------------');
disp('KẾT LUẬN CHẨN ĐOÁN:');

diagnosis_title = '';

if murmur_ratio > MURMUR_THRESHOLD
    disp(' [CẢNH BÁO] Phát hiện dải nhiễu tần số cao bất thường!');
    disp(' -> Nghi ngờ: Có tiếng thổi ở tim (Murmur) - Dấu hiệu hẹp/hở van tim.');
    diagnosis_title = 'BẤT THƯỜNG (Tiếng thổi van tim)';
elseif peaks_per_sec > MAX_NORMAL_PEAKS
    disp(' [CẢNH BÁO] Số lượng đỉnh dao động quá lớn!');
    disp(' -> Nghi ngờ: Xuất hiện nhịp ngựa phi (S3/S4) hoặc nhịp tim cực nhanh.');
    diagnosis_title = 'BẤT THƯỜNG (Có S3/S4 hoặc Nhịp nhanh)';
elseif peaks_per_sec < MIN_NORMAL_PEAKS
    disp(' [LỖI] Tín hiệu quá thưa thớt!');
    disp(' -> Hãy kiểm tra lại vị trí đặt cảm biến hoặc lực ép mặt ống nghe.');
    diagnosis_title = 'KHÔNG THỂ KẾT LUẬN (Tín hiệu yếu)';
else
    disp(' [TỐT] Tín hiệu tim mạch ổn định.');
    disp(' -> Chu kỳ âm S1, S2 rõ nét, không phát hiện dải tạp âm bệnh lý.');
    diagnosis_title = 'BÌNH THƯỜNG (Khỏe mạnh)';
end
disp('==================================================');

%% 5. VẼ ĐỒ THỊ TRỰC QUAN (3 SUBPLOTS)
figure('Name', 'Hệ thống Đánh giá PCG Toàn diện', 'NumberTitle', 'off', 'Position', [100 100 1000 600]);

% Đồ thị 1: Tín hiệu thô ban đầu
subplot(3, 1, 1);
plot(t, raw_data);
title('1. Tín hiệu thô ban đầu (Raw Signal)');
xlabel('Thời gian (giây)'); ylabel('Biên độ chuẩn hóa');
grid on; xlim([0 t(end)]); 

% Đồ thị 2: Phân tích S1, S2 và đường bao Shannon
subplot(3, 1, 2);
plot(t, sig_S1S2); hold on;
plot(t, envelope);
plot(locs, pks, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
title(sprintf('2. Phân tích Nhịp Tim (Dải 20-200Hz): %d BPM - Kết luận: %s', BPM_calculated, diagnosis_title), 'Color','red');
xlabel('Thời gian (giây)'); ylabel('Biên độ chuẩn hóa');
legend('Tín hiệu 20-200Hz', 'Đường bao Shannon', 'Các đỉnh được nhận diện', 'Location', 'northeast');
grid on; xlim([0 t(end)]); 

% Đồ thị 3: Dải tạp âm bệnh lý
subplot(3, 1, 3);
plot(t, sig_murmur);
title(sprintf('3. Phân tích Tạp Âm Bệnh Lý (Dải 200-600Hz) - Tỷ lệ năng lượng: %.2f%%', murmur_ratio * 100));
xlabel('Thời gian (giây)'); ylabel('Biên độ chuẩn hóa');
grid on; xlim([0 t(end)]); ylim([-0.5 0.5]);
