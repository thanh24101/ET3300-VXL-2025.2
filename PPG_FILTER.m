% 1. ĐỌC DỮ LIỆU TỪ FILE THÔ (RAW DATA)
data_file = load('ppg_minh_1707_2.txt');

Fs = 200; % Tần số lấy mẫu phần cứng hiện tại
%data_file = data_file(25*Fs : 40*Fs);



red_raw = data_file(:, 1);
%red_raw = red_raw(2*Fs : 10*Fs);
ir_raw = data_file(:, 2);
%ir_raw = ir_raw(2*Fs : 10*Fs);
                 

data=ir_raw;
N = length(ir_raw);       % Đếm tổng số lượng mẫu thu được
t = (0:N-1) / Fs;           % Tự động tạo trục thời gian khớp 100% với dữ liệu

% Thiết lập cửa sổ đồ thị cỡ lớn
figure('Name', 'He Thong Đanh Gia Chat Luong Tim Mach', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

% =========================================================================
% ĐỒ THỊ 1: TÍN HIỆU THÔ (RAW DATA)
% =========================================================================
subplot(3, 1, 1);
plot(t, ir_raw);
title('Tín hiệu PPG Thô - 200Hz', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Thời gian (Giây)');
ylabel('ADC value');
grid on; grid minor;


% =========================================================================
% ĐỒ THỊ 2: LỌC TÍN HIỆU (BUTTERWORTH 1Hz - 10Hz)
% =========================================================================
% Thiết kế bộ lọc IIR dải thông 
bpFilt = designfilt('bandpassiir', 'FilterOrder', 4, ...
         'HalfPowerFrequency1', 1.0, 'HalfPowerFrequency2', 10.0, ...
         'SampleRate', Fs, 'DesignMethod', 'butter');

% Lọc không dịch pha (Zero-phase filtering)
data_filtered = filtfilt(bpFilt, ir_raw);

subplot(3, 1, 2);
plot(t, data_filtered);
title('Tín hiệu sau lọc Bandpass Butterworth Bậc 4 [1Hz - 10Hz]', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Thời gian (Giây)');
ylabel('Biên độ AC');
grid on; grid minor;


% =========================================================================
% ĐỒ THỊ 3: TÍNH NHỊP TIM BẰNG TỰ TƯƠNG QUAN (AUTOCORRELATION)
% =========================================================================
% Chạy hàm tự tương quan trên tín hiệu đã lọc
data_filtered_raw = filtfilt(bpFilt, data);
[autocorrelation_values, lags] = xcorr(data_filtered_raw, 'coeff');

% Cắt bỏ nửa đồ thị âm (chỉ xét độ trễ Lag >= 0)
autocorr_half = autocorrelation_values(lags >= 0);
lags_half = lags(lags >= 0);

% Giới hạn dải quét để không bắt nhầm nhiễu (Giới hạn: 50 -> 150 BPM)
min_lag = round(Fs * 60 / 150); 
max_lag = round(Fs * 60 / 50);  

% Tìm đỉnh cao nhất trong dải sinh lý học
valid_autocorr = autocorr_half(min_lag:max_lag);
[~, max_idx] = max(valid_autocorr);
optimal_lag = min_lag + max_idx - 1;

% Tính toán kết quả cuối cùng
T_heart_cycle = optimal_lag / Fs;
BPM_calculated = round(60 / T_heart_cycle);

subplot(3, 1, 3);
plot(lags_half / Fs, autocorr_half);
hold on;
% Đánh dấu vị trí đỉnh bằng ngôi sao màu đỏ
plot(T_heart_cycle, autocorr_half(optimal_lag+1), 'r*', 'MarkerSize', 10, 'LineWidth', 2);

title(sprintf('Tự tương quan - Nhịp tim: %d BPM', BPM_calculated), 'color','red', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Độ trễ (Giây)');
ylabel('Hệ số tương quan');
grid on;
 

% Tính SpO2:

red_filtered = filtfilt(bpFilt, red_raw);
ir_filtered  = filtfilt(bpFilt, ir_raw);
% DC: Giá trị trung bình của tín hiệu thô
dc_red = mean(red_raw);
dc_ir  = mean(ir_raw);
% AC: Giá trị RMS của tín hiệu đã lọc
ac_red = rms(red_filtered);
ac_ir  = rms(ir_filtered);
% R = (AC_Red / DC_Red) / (AC_IR / DC_IR)
ratio_r = (ac_red / dc_red) / (ac_ir / dc_ir);
% SpO2(%) = -45.06*R^2 + 30.354*R + 94.845
spo2 = -45.06 * (ratio_r^2) + 30.354 * ratio_r + 94.845;
% HIỂN THỊ KẾT QUẢ
fprintf('--- KẾT QUẢ PHÂN TÍCH SpO2 ---\n');
fprintf('Tỉ số R: %.3f\n', ratio_r);
fprintf('Nồng độ SpO2 ước tính: %.1f %%\n', spo2);

% --- VẼ ĐỒ THỊ KIỂM CHỨNG ---
figure;
subplot(2,1,1);
plot(t, red_filtered, 'r'); % Vẽ đường màu đỏ
hold on;                    % Giữ đồ thị lại để vẽ tiếp
plot(t, ir_filtered, 'b');  % Vẽ đường màu xanh
legend('Red Filtered', 'IR Filtered');
title(sprintf('Tín hiệu AC sau lọc - Nồng độ SpO2 ước tính: %.1f %%\n', spo2), 'Color','red');
grid on;
hold off;                   % Giải phóng đồ thị
