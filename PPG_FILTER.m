#include <Wire.h>
#include "MAX30105.h"

MAX30105 particleSensor;

void setup() {
  // Tăng tốc độ Baudrate để tránh nghẽn dữ liệu khi truyền về máy tính
  Serial.begin(115200); 
  
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("Loi: Khong tim thay MAX30102!");
    while (1);
  }

  // --- CẤU HÌNH TẦN SỐ 200Hz ---
  byte ledBrightness = 0x1F; // 50mA
  byte sampleAverage = 1;    // SMPAVE = 0 (tắt trung bình để lấy dữ liệu thô nhất)
  byte ledMode = 2;          // Red + IR
  int sampleRate = 200;      // Tần số 200Hz
  int pulseWidth = 411;      // Độ rộng xung
  int adcRange = 4096;       // Thang đo ADC

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.clearFIFO(); 
}

void loop() {
  // Kiểm tra dữ liệu trong bộ đệm FIFO
  particleSensor.check();

  while (particleSensor.available()) {
    // Lấy giá trị IR thô từ FIFO
    
    long irValue = particleSensor.getFIFOIR();   // Đọc kênh IR
    long redValue = particleSensor.getFIFORed(); // Đọc kênh Đỏ

  
    
    // Chỉ truyền dữ liệu về máy tính khi có ngón tay đặt lên cảm biến
    if (irValue > 50000) {
      // Gửi cả 2 giá trị này về máy tính (ví dụ cách nhau bằng dấu phẩy)
        Serial.print(redValue);
        Serial.print(",");
        Serial.println(irValue);
    }
    
    particleSensor.nextSample();
  }
}
