// ============================================================
// Slave Arduino - プロトタイプ（ピアノ1台用）
// MasterからI2C受信 → 演奏開始 → Serialで音符送信
// ============================================================

#include <Wire.h>

#define SLAVE_ADDR        0x08
#define SERIAL_BAUD       9600
#define DATA_SIZE         5
#define MY_INSTRUMENT_ID  1   // ピアノ固定

// ------------------------------------------------------------
// 楽譜データ（森のくまさん / ピアノ主旋律 / BPM120）
// pitch: MIDIノート番号（0 = 休符）
// duration: 音符の長さ（ms）
// startTime: 曲開始からの絶対発音タイミング（ms）
// ------------------------------------------------------------
const int SCORE_LENGTH = 29;

const int pitch[] = {
  0, 67, 69, 71, 72, 67, 64, 60, 69,
  0, 69, 71, 69, 67, 65, 64, 62, 60,
  0, 67, 66, 67, 64,  0,  0, 64, 63, 64, 50
};

const int duration[] = {
  250, 250, 250, 250, 500, 500, 500, 500, 1000,
  250, 250, 250, 250, 500, 500, 500, 500, 1000,
  250, 250, 250, 250, 500, 500,
  250, 250, 250, 250, 500, 500, 250
};

const int startTime[] = {
     0,  250,  500,  750, 1000, 1500, 2000, 2500, 3000,
  4000, 4250, 4500, 4750, 5000, 5500, 6000, 6500, 7000,
  8000, 8250, 8500, 8750, 9000, 9500,
  10000, 10250, 10500, 10750, 11000, 11500
};

// ------------------------------------------------------------
// グローバル変数
// ------------------------------------------------------------
volatile byte rxData[DATA_SIZE];
volatile bool dataReceived = false;

bool  isPlaying      = false;
int   scoreIndex     = 0;
unsigned long playStartTime = 0;  // 演奏開始時刻

// ------------------------------------------------------------
void setup() {
  Wire.begin(SLAVE_ADDR);
  Wire.onReceive(onReceive);
  Serial.begin(SERIAL_BAUD);
  Serial.println("Slave ready");
}

void loop() {
  // I2C受信処理
  if (dataReceived) {
    dataReceived = false;

    byte id1 = rxData[2];

    if (id1 == MY_INSTRUMENT_ID && !isPlaying) {
      isPlaying     = true;
      scoreIndex    = 0;
      playStartTime = millis();
      Serial.println("START");
    }
  }

  // 演奏中：発音タイミングが来た音符をSerialへ送信
  if (isPlaying && scoreIndex < SCORE_LENGTH) {
    unsigned long elapsed = millis() - playStartTime;

    if (elapsed >= (unsigned long)startTime[scoreIndex]) {
      // 休符（pitch==0）は送信せずスキップ
      if (pitch[scoreIndex] != 0) {
        Serial.print(pitch[scoreIndex]);
        Serial.print(",");
        Serial.println(duration[scoreIndex]);
      }
      scoreIndex++;

      // 全音符送信完了
      if (scoreIndex >= SCORE_LENGTH) {
        isPlaying = false;
        Serial.println("END");
      }
    }
  }
}

void onReceive(int numBytes) {
  if (numBytes == DATA_SIZE) {
    for (int i = 0; i < DATA_SIZE; i++) rxData[i] = Wire.read();
    dataReceived = true;
  } else {
    while (Wire.available()) Wire.read();
  }
}
