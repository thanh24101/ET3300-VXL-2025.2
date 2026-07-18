#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include "MAX30105.h"

// --- CẤU HÌNH CHÂN ---
const int ECG_PIN = 35;  // ADC đọc tín hiệu thô từ AD8232
const int CS_PIN = 5;    // Chân Chip Select cho thẻ nhớ SD

// --- KHỞI TẠO ĐỐI TƯỢNG ---
MAX30105 particleSensor;
File dataFile;           // Đối tượng quản lý file thẻ nhớ

// --- BIẾN TOÀN CỤC ---
hw_timer_t * timer = NULL;
volatile bool sampleFlag = false; 
int flushCounter = 0;    // Biến đếm để lưu file định kỳ
long lastPPGValue = 0;   // Lưu giá trị PPG gần nhất để đồng bộ

// Hàm ngắt Timer
void ARDUINO_ISR_ATTR onTimer() {
  sampleFlag = true; 
}

void setup() {
  Serial.begin(115200);
  pinMode(ECG_PIN, INPUT);

  // --- 1. KHỞI TẠO MAX30102 (Ép xung I2C_SPEED_FAST 400kHz) ---
  Serial.print("Khởi tạo MAX30102...");
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println(" Lỗi! Không tìm thấy MAX30102!");
    while (1);
  }
  
  // Cấu hình tần số 200Hz cho cảm biến
  byte ledBrightness = 0x1F; // 50mA
  byte sampleAverage = 1;    // Tắt trung bình
  byte ledMode = 2;          // Red + IR
  int sampleRate = 200;      // Tần số 200Hz
  int pulseWidth = 411;      // Độ rộng xung
  int adcRange = 4096;       // Thang đo ADC
  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.clearFIFO(); 
  Serial.println(" Thành công!");

  // --- 2. KHỞI TẠO THẺ NHỚ SD ---
  Serial.print("Khởi tạo thẻ nhớ SD...");
  if (!SD.begin(CS_PIN)) {
    Serial.println(" Lỗi! Không tìm thấy thẻ nhớ.");
    while (1);
  }
  
  dataFile = SD.open("/ecg_ppg_sync.txt", FILE_WRITE);
  if (!dataFile) {
    Serial.println("Lỗi! Không thể tạo file trên thẻ.");
    while(1);
  }
  dataFile.println("ECG,PPG"); 
  dataFile.flush(); 
  Serial.println(" Thẻ nhớ OK! Bắt đầu thu thập dữ liệu...");

  // --- 3. CẤU HÌNH TIMER 5ms (200Hz) ---
  timer = timerBegin(1000000); 
  timerAttachInterrupt(timer, &onTimer); 
  timerAlarm(timer, 5000, true, 0); 
}

void loop() {
  // 1. Liên tục cập nhật dữ liệu từ MAX30102 vào bộ đệm của ESP32
  // Lưu ý: Lệnh này giao tiếp I2C, không được đặt trong hàm ngắt ISR
  particleSensor.check();

  // 2. Kích hoạt lấy mẫu đồng bộ khi đến chu kỳ 5ms
  if (sampleFlag) {
    sampleFlag = false; // Reset cờ
    
    // BƯỚC 1: Đọc tín hiệu điện tim ECG ngay lập tức
    int ecgValue = analogRead(ECG_PIN);
    
    // BƯỚC 2: Rút tín hiệu quang thể tích PPG từ FIFO
    if (particleSensor.available()) {
      long irValue = particleSensor.getFIFOIR(); // Đọc kênh IR (hồng ngoại dâm xuyên sâu nhất)
      // Loại bỏ rác nếu ngón tay nhấc ra khỏi cảm biến (giá trị < 50000)
      lastPPGValue = (irValue > 50000) ? irValue : 0; 
      
      particleSensor.nextSample(); // Xóa mẫu cũ, chuẩn bị hứng mẫu mới
    }
    
    // BƯỚC 3: Ghi đồng thời vào bộ đệm thẻ nhớ
    dataFile.print(ecgValue);
    dataFile.print(",");
    dataFile.println(lastPPGValue);
    
    // BƯỚC 4: In ra Serial Plotter (Tùy chọn để xem lúc test)
    // Nếu dữ liệu in ra nhảy quá nhanh gây giật lag MATLAB/Serial, bố có thể comment 3 dòng dưới lại
    Serial.print(ecgValue);
    Serial.print(",");
    Serial.println(lastPPGValue);

    // BƯỚC 5: Cứ 200 mẫu (1 giây), ép lưu thẳng xuống lõi thẻ nhớ
    flushCounter++;
    if (flushCounter >= 200) {
      dataFile.flush(); 
      flushCounter = 0;
    }
  }
}
