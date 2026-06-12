// ============================================================
// Slave Arduino - 木琴（マリンバ）担当
// 先輩コード（Slave.ino）の形式を踏襲
// MasterからI2C受信 → 演奏開始 → Serialで音符送信
// ============================================================

#include <Wire.h>

// TODO: チームのI2Cアドレス割り当てに合わせて変更
#define SLAVE_ADDR        0x08   // ピアノ=0x08、木琴=0x09（暫定）
#define SERIAL_BAUD       9600
#define DATA_SIZE         5
#define MY_INSTRUMENT_ID  2      // 1=ピアノ, 2=木琴（暫定）

// ------------------------------------------------------------
// 楽譜データ（もりのくまさん / 木琴主旋律 / BPM120）
// pitch    : MIDIノート番号（0 = 休符）
// duration : 音符の長さ（ms）  ※ BPM120固定
// startTime: 曲開始からの絶対発音タイミング（ms）
//
// 【構成】 弱起2拍 + M1〜M10 + M12 + M13（計12小節）
//   各 duration は BPM120 基準（4分音符=500ms, 8分音符=250ms）
// ------------------------------------------------------------
const int SCORE_LENGTH = 61;

const int pitch[] = {
  //  弱起（2拍：8分×4）
  0,  67, 69, 71,

  //  M1（ド↑ ソ ミ ド↓：4分×4）
  72, 67, 64, 60,

  //  M2（ラ 8分休 ラ シ ラ）
  69,  0, 69, 71, 69,

  //  M3（ソ ソ# ラ シ：4分×4）
  67, 68, 69, 71,

  //  M4（ド↑ 8分休 ソ ファ# ソ）
  72,  0, 67, 66, 67,

  //  M5（ミ 4分休 8分休 ミ レ# ミ）
  64,  0,  0, 64, 63, 64,

  //  M6（ド 4分休 8分休 ミ レ ド）
  60,  0,  0, 64, 62, 60,

  //  M7（レ 4分休 8分休 ソ ラ ソ）
  62,  0,  0, 67, 69, 67,

  //  M8（ミ 4分休 8分休 ソ ラ シ）
  64,  0,  0, 67, 69, 71,

  //  M9（ド↑ ソ ミ ド↓：4分×4）
  72, 67, 64, 60,

  //  M10（ラ 8分休 ラ シ ラ）
  69,  0, 69, 71, 69,

  //  M12（ソ ファ ミ レ：4分×4）
  67, 65, 64, 62,

  //  M13（ド↑ 付点2分 + 4分休）
  60,  0
};

const int duration[] = {
  //  弱起
  250, 250, 250, 250,

  //  M1
  500, 500, 500, 500,

  //  M2
  1000, 250, 250, 250, 250,

  //  M3
  500, 500, 500, 500,

  //  M4
  1000, 250, 250, 250, 250,

  //  M5
  500, 500, 250, 250, 250, 250,

  //  M6
  500, 500, 250, 250, 250, 250,

  //  M7
  500, 500, 250, 250, 250, 250,

  //  M8
  500, 500, 250, 250, 250, 250,

  //  M9
  500, 500, 500, 500,

  //  M10
  1000, 250, 250, 250, 250,

  //  M12
  500, 500, 500, 500,

  //  M13
  1500, 500
};

const int startTime[] = {
  //  弱起
     0,  250,  500,  750,

  //  M1
  1000, 1500, 2000, 2500,

  //  M2
  3000, 4000, 4250, 4500, 4750,

  //  M3
  5000, 5500, 6000, 6500,

  //  M4
  7000, 8000, 8250, 8500, 8750,

  //  M5
  9000,  9500, 10000, 10250, 10500, 10750,

  //  M6
  11000, 11500, 12000, 12250, 12500, 12750,

  //  M7
  13000, 13500, 14000, 14250, 14500, 14750,

  //  M8
  15000, 15500, 16000, 16250, 16500, 16750,

  //  M9
  17000, 17500, 18000, 18500,

  //  M10
  19000, 20000, 20250, 20500, 20750,

  //  M12
  21000, 21500, 22000, 22500,

  //  M13
  23000, 24500
};

// ------------------------------------------------------------
// グローバル変数
// ------------------------------------------------------------
volatile byte rxData[DATA_SIZE];
volatile bool dataReceived = false;

bool          isPlaying      = false;
int           scoreIndex     = 0;
unsigned long playStartTime  = 0;

// ------------------------------------------------------------
void setup() {
  Wire.begin(SLAVE_ADDR);
  Wire.onReceive(onReceive);
  Serial.begin(SERIAL_BAUD);
  Serial.println("Slave(Mokkin) ready");
}

void loop() {
  // I2C受信処理
  if (dataReceived) {
    dataReceived = false;

    byte bpm  = rxData[0];
    byte id1  = rxData[2];
    byte id2  = rxData[3];
    byte id3  = rxData[4];

    // 自分のIDが演奏順（ID1/ID2/ID3）のいずれかに含まれていれば演奏開始
    bool myTurn = (id1 == MY_INSTRUMENT_ID) ||
                  (id2 == MY_INSTRUMENT_ID) ||
                  (id3 == MY_INSTRUMENT_ID);

    if (myTurn && !isPlaying) {
      isPlaying     = true;
      scoreIndex    = 0;
      playStartTime = millis();
      Serial.println("START");
    }
  }

  // 演奏中：startTimeを過ぎた音符をSerialへ送信
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
