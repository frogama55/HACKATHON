// ============================================================
// Master Arduino - プロトタイプ（1対1確認用）
// PC5からSerial受信 → I2CでSlaveへ送信
// ============================================================

#include <Wire.h>

#define SLAVE_ADDR  0x08
#define SERIAL_BAUD 9600
#define DATA_SIZE   5

byte sendData[DATA_SIZE] = {120, 4, 1, 0, 0};
// [0] BPM, [1] オクターブ, [2] 楽器ID（1=ピアノ）, [3][4] 未使用

void setup() {
  Wire.begin();
  Serial.begin(SERIAL_BAUD);
  Serial.println("Master ready");
}

void loop() {
  if (Serial.available() > 0) {
    String line = Serial.readStringUntil('\n');
    line.trim();

    int values[DATA_SIZE];
    int idx = 0, start = 0;
    for (int i = 0; i <= (int)line.length() && idx < DATA_SIZE; i++) {
      if (i == (int)line.length() || line[i] == ',') {
        values[idx++] = line.substring(start, i).toInt();
        start = i + 1;
      }
    }

    if (idx == DATA_SIZE) {
      for (int i = 0; i < DATA_SIZE; i++) sendData[i] = (byte)values[i];
      // I2C送信
      Wire.beginTransmission(SLAVE_ADDR);
      for (int i = 0; i < DATA_SIZE; i++) Wire.write(sendData[i]);
      Wire.endTransmission();
      Serial.println("ACK");
    } else {
      Serial.println("ERR");
    }
  }
}
