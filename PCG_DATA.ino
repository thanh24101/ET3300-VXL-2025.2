#include <driver/i2s.h>

// Định nghĩa các chân I2S
#define I2S_WS 15
#define I2S_SCK 14
#define I2S_SD 32

// Định nghĩa thông số lấy mẫu
#define I2S_PORT I2S_NUM_0
#define SAMPLE_RATE 4000 // Tần số 8kHz phù hợp cho PCG

void i2s_install() {
  const i2s_config_t i2s_config = {
    .mode = i2s_mode_t(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT, // Đọc 32-bit để chứa dữ liệu 24-bit
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,  // Chỉ đọc kênh trái
    .communication_format = i2s_comm_format_t(I2S_COMM_FORMAT_STAND_I2S),
    .intr_alloc_flags = 0, 
    .dma_buf_count = 8,
    .dma_buf_len = 64,
    .use_apll = false
  };

  i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
}

void i2s_setpin() {
  const i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_SCK,
    .ws_io_num = I2S_WS,
    .data_out_num = -1, // Không dùng đầu ra
    .data_in_num = I2S_SD
  };

  i2s_set_pin(I2S_PORT, &pin_config);
}

void setup() {
  // Tăng tốc độ Baudrate lên rất cao
  Serial.begin(921600); 
  delay(1000);
  
  i2s_install();
  i2s_setpin();
  i2s_start(I2S_PORT);
}

void loop() {
  int32_t sample = 0;
  size_t bytes_read = 0;

  i2s_read(I2S_PORT, &sample, sizeof(sample), &bytes_read, portMAX_DELAY);

  if (bytes_read > 0) {
    sample = sample >> 8;
    // In trực tiếp số nguyên để tiết kiệm thời gian xử lý
    Serial.println(sample); 
  }
}
