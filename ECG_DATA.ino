const int ECG_PIN = 35; // Sử dụng chân 35 tối ưu cho ADC1

// Khởi tạo con trỏ cấu hình Timer
hw_timer_t * timer = NULL;
volatile bool sampleFlag = false; 

// Hàm ngắt (Core v3 khuyến khích dùng ARDUINO_ISR_ATTR thay vì IRAM_ATTR)
void ARDUINO_ISR_ATTR onTimer() {
  sampleFlag = true; 
}

void setup() {
  Serial.begin(115200);
  pinMode(ECG_PIN, INPUT);

  // --- CẤU HÌNH TIMER CHO ESP32 CORE V3.x ---
  
  // 1. Khởi tạo Timer với tần số 1.000.000 Hz (1 MHz) -> Tương đương 1 tick = 1 micro-giây
  timer = timerBegin(1000000); 
  
  // 2. Gắn hàm ngắt vào Timer (Cấu trúc mới chỉ cần 2 tham số)
  timerAttachInterrupt(timer, &onTimer); 
  
  // 3. Cài đặt báo thức (Alarm): 5000 tick (tức 5ms), true (tự động lặp lại), 0 (reset về 0)
  timerAlarm(timer, 5000, true, 0); 
}

void loop() {
  if (sampleFlag) {
    sampleFlag = false; // Tắt cờ chờ chu kỳ sau
    
    // Đọc ADC và gửi dữ liệu ngay lập tức
    int ecgValue = analogRead(ECG_PIN);
    Serial.println(ecgValue);
  }
}
