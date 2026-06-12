// ============================================================
//  木琴スレーブ用 シリアル通信モジュール
//  SerialReceiver_Marimba.pde
//
//  【役割】
//    ArduinoスレーブからSerial送信された音符データを受け取り、
//    木琴音色で発音する。
//
//  【設計書との対応】
//    FBS 4.1  Arduino データ受信  → serialEvent()
//    FBS 4.2  MIDI Hz変換        → midiToFreq()
//    FBS 4.3  各楽器音色生成      → playMarimba()
//    PBS 2.1.6 Serial通信モジュール → serialEvent()
//    PBS 2.3.5 スレーブ共通処理   → Arduinoが送信する側
//
//  【パケット仕様（設計書 3.3.3.4 より）】
//    Arduinoスレーブが送信するフォーマット:
//      "noteNumber,soundStrength,durationSlots\n"
//    例: "60,100,2\n"
//      noteNumber   : MIDIノート番号 (0〜127)
//      soundStrength: 音量 (0〜127) ← 設計書では変化なし固定想定
//      durationSlots: 8分音符スロット数 (1スロット=8分音符1個)
//
//  【BPM連携】
//    currentBpmはBPM制御モジュール(BpmController.pde)と共有変数。
//    今回はこのファイル内に暫定的に定義する。
//
//  【ポート番号について】
//    setup()内のポート番号を環境に合わせて変更すること。
//    Windowsなら "COM3" 等、Macなら "/dev/cu.usbmodem..." 等。
// ============================================================

import processing.serial.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

// ----------------------------------------------------------
//  シリアル通信
// ----------------------------------------------------------
Serial port;

// 受信バッファ（念のため複数行に備える）
String receivedPacket = "";

// ----------------------------------------------------------
//  Minim（音声出力）
// ----------------------------------------------------------
Minim minim;
AudioOutput out;

// ----------------------------------------------------------
//  BPM（BpmController.pde と共有する想定。暫定でここに定義）
//  Arduinoが送信するdurationSlotsをミリ秒に換算するために使う
// ----------------------------------------------------------
float currentBpm = 120.0;

// 1スロット（8分音符）のミリ秒
// BPM120なら: 60000ms / 120拍 / 2スロット = 250ms
float slotMs() {
  return 60000.0 / currentBpm / 2.0;
}


// ----------------------------------------------------------
//  MarimbaInstrument（木琴音色）
//  正弦波(Waves.SINE) + Line2本(Attack/Decay)
// ----------------------------------------------------------
class MarimbaInstrument implements Instrument {
  Oscil wave;
  Line  attackLine;
  Line  decayLine;
  float maxAmp;
  float sustainLevel;

  final float ATTACK_SEC    = 0.005f;
  final float DECAY_SEC     = 0.15f;
  final float SUSTAIN_RATIO = 0.05f;

  MarimbaInstrument(float frequency, float amp) {
    this.maxAmp       = amp;
    this.sustainLevel = amp * SUSTAIN_RATIO;
    wave       = new Oscil(frequency, 0, Waves.SINE);
    attackLine = new Line();
    decayLine  = new Line();
    attackLine.patch(wave.amplitude);
  }

  void noteOn(float duration) {
    attackLine.activate(ATTACK_SEC, 0, maxAmp);
    decayLine.activate(DECAY_SEC, maxAmp, sustainLevel);
    decayLine.patch(wave.amplitude);
    wave.patch(out);
  }

  void noteOff() {
    wave.unpatch(out);
  }
}

// MIDIノート番号 → Hz
float midiToFreq(int note) {
  return 440.0 * pow(2.0, (note - 69) / 12.0);
}


// ----------------------------------------------------------
//  発音関数（Arduinoから受け取った1音分を鳴らす）
//
//  引数:
//    noteNumber   : MIDIノート番号
//    soundStrength: 0〜127（設計書仕様。0.0〜1.0に正規化して使う）
//    durationSlots: 8分音符スロット数
// ----------------------------------------------------------
void playOneNote(int noteNumber, int soundStrength, int durationSlots) {
  float freqHz      = midiToFreq(noteNumber);
  float amp         = soundStrength / 127.0;   // 0〜127 → 0.0〜1.0
  float durationSec = (durationSlots * slotMs()) / 1000.0;  // ms → 秒

  out.pauseNotes();
  out.playNote(0, durationSec, new MarimbaInstrument(freqHz, amp));
  out.resumeNotes();
}


// ----------------------------------------------------------
//  シリアル受信（HCK02_02 の serialEvent をベースに改良）
//
//  受信フォーマット: "noteNumber,soundStrength,durationSlots\n"
//  例: "60,100,2\n"
//
//  処理の流れ（HCK02_02との対応）:
//    p.readStringUntil('\n') → 改行まで読む（HCK02_02と同じ）
//    trim()                  → 空白・改行除去（HCK02_02と同じ）
//    split(',')              → カンマ区切りで分割（今回の追加）
//    playOneNote()           → 発音（今回の追加）
// ----------------------------------------------------------
void serialEvent(Serial p) {
  // 改行('\n')まで読み込む（HCK02_02.pde の手法と同じ）
  String inString = p.readStringUntil('\n');

  if (inString == null) return;

  inString = trim(inString);  // 空白・改行を除去
  if (inString.length() == 0) return;

  // デバッグ: 受信内容をコンソールに表示
  println("[Serial受信] " + inString);

  // カンマ区切りでパース（設計書 PacketRouter.parseNotePacket に対応）
  String[] parts = split(inString, ',');

  // パケット形式チェック（3要素であること）
  if (parts.length != 3) {
    println("[警告] 不正なパケット形式: " + inString);
    return;
  }

  // 文字列 → 数値変換（変換失敗時は0になる）
  int noteNumber    = int(parts[0]);
  int soundStrength = int(parts[1]);
  int durationSlots = int(parts[2]);

  // 範囲チェック
  if (noteNumber < 0 || noteNumber > 127) {
    println("[警告] noteNumber範囲外: " + noteNumber);
    return;
  }
  if (durationSlots <= 0) {
    println("[警告] durationSlots不正: " + durationSlots);
    return;
  }

  // 発音
  playOneNote(noteNumber, soundStrength, durationSlots);
}


// ----------------------------------------------------------
//  setup / draw
// ----------------------------------------------------------
void setup() {
  size(512, 200);

  // Minim初期化
  minim = new Minim(this);
  out   = minim.getLineOut();

  // ポート初期化
  // ※ポート名は環境に合わせて変更すること
  // Macの場合:  "/dev/cu.usbmodem..." など
  // Windowsの場合: "COM3" など
  // 利用可能なポート一覧を確認するには下記のコードを一度実行:
  //   printArray(Serial.list());
  String portName = Serial.list()[0];  // 暫定: 最初に見つかったポート
  println("接続するポート: " + portName);

  port = new Serial(this, portName, 115200);
  port.clear();
  port.bufferUntil('\n');  // 改行まで溜めてからserialEventを発火させる

  println("シリアル通信開始。Arduinoからのデータ待機中...");
}

void draw() {
  background(0);
  stroke(180, 220, 140);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50  + out.left.get(i)*50,  i+1, 50  + out.left.get(i+1)*50);
    line(i, 150 + out.right.get(i)*50, i+1, 150 + out.right.get(i+1)*50);
  }
  fill(180, 220, 140);
  noStroke();
  text("BPM: " + (int)currentBpm, 10, 20);
  text("ポート: " + (port != null ? "接続中" : "未接続"), 10, 40);
}
