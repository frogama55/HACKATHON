// ============================================================
//  木琴（Marimba）スレーブ Processing
//  Slave_mokkin_Processing.pde
//
//  楽譜: もりのくまさん ハ長調 4/4拍子
//  音色: 正弦波4本（基音 + 2/3/4倍音）倍音合成 + ADSR
//  受信: Slave Arduino から Serial "noteNumber,durationSlots\n"
//        を受信して1音ずつ発音（設計書 WBS 211-B）
//
//  ['p'] 楽譜全体の手動試聴   ['+'/'-'] BPM変更
// ============================================================

import ddf.minim.*;
import ddf.minim.ugens.*;
import processing.serial.*;

Minim minim;
AudioOutput out;

// ----------------------------------------------------------
//  MIDIノート番号
// ----------------------------------------------------------
final int Fs3 = 54;
final int A3  = 57;
final int B3  = 59;
final int C4  = 60;
final int D4  = 62;
final int Ds4 = 63;  // D#4（レ#）
final int E4  = 64;
final int F4  = 65;
final int Fs4 = 66;  // F#4（ファ#）
final int G4  = 67;
final int Gs4 = 68;  // G#4（ソ#）
final int A4  = 69;
final int B4  = 71;
final int C5  = 72;
final int REST = 0;

// 伴奏（低音部）用ノート番号
final int G2  = 43;
final int C3  = 48;  // ド（1オクターブ下）
final int D3  = 50;  // レ
final int E3  = 52;  // ミ
final int F3  = 53;  // ファ
final int G3  = 55;  // ソ
final int Gs3 = 56;

// ----------------------------------------------------------
//  楽譜（もりのくまさん 主旋律）
//
//  【構成】
//    弱起(2拍): 8分休 ソ ラ シ
//    小節1(4拍): ド↑ ソ ミ ド↓
//    小節2(4拍): ラ 8分休 ラ シ ラ
//    小節3(4拍): ソ ソ# ラ シ
//    小節4(4拍): ド↑ 8分休 ソ ファ# ソ
//    小節5(4拍): ミ 4分休 8分休 ミ レ# ミ
//    小節6(4拍): ド 4分休 8分休 ミ レ ド
//    小節7(4拍): レ 4分休 8分休 ソ ラ ソ
//    小節8(4拍): ミ 4分休 8分休 ソ ラ シ
//    小節9(4拍): ド↑ ソ ミ ド↓
//    小節10(4拍): ラ 8分休 ラ シ ラ
//    小節11(4拍): ソ ファ ミ レ
//    小節12(4拍): ソ ソ# ラ シ
//    小節13(4拍): ド↑ 付点2分 4分休  ← 終止小節
//
//  duration_120: BPM120基準の拍数
//    0.5=8分  1.0=4分  1.5=付点4分  2.0=2分
// ----------------------------------------------------------

int[] pitch = {
  // 【弱起 2拍】8分休 ソ ラ シ
  REST, G4, A4, B4,

  // 【小節1 4拍】ド↑ ソ ミ ド↓  (4分×4)
  C5, G4, E4, C4,

  // 【小節2 4拍】ラ 8分休 ラ シ ラ
  A4, REST, A4, B4, A4,

  // 【小節3 4拍】ソ ソ# ラ シ  (4分×4)
  G4, Gs4, A4, B4,

  // 【小節4 4拍】ド↑ 8分休 ソ ファ# ソ
  C5, REST, G4, Fs4, G4,

  // 【小節5 4拍】ミ 4分休 8分休 ミ レ# ミ
  E4, REST, REST, E4, Ds4, E4,

  // 【小節6 4拍】ド 4分休 8分休 ミ レ ド
  C4, REST, REST, E4, D4, C4,

  // 【小節7 4拍】レ 4分休 8分休 ソ ラ ソ
  D4, REST, REST, G4, A4, G4,

  // 【小節8 4拍】ミ 4分休 8分休 ソ ラ シ
  E4, REST, REST, G4, A4, B4,

  // 【小節9 4拍】ド↑ ソ ミ ド↓  (4分×4)
  C5, G4, E4, C4,

  // 【小節10 4拍】ラ 8分休 ラ シ ラ
  A4, REST, A4, B4, A4,

  // 【小節12 4拍】ソ ソ# ラ シ  (4分×4)
  G4, F4, E4, D4,

  // 【小節13 4拍】ド↑ 付点2分 4分休  ← 終止小節
  C4, REST
};

float[] duration_120 = {
  // 弱起: 8分 8分 8分 8分
  0.5f, 0.5f, 0.5f, 0.5f,

  // 小節1: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節2: 4分 8分 8分 8分 8分 → 1+0.5+0.5+0.5+0.5=3 … 4拍に合わせる
  // ラ(4分) 8分休 ラ(8分) シ(8分) ラ(付点4分=1.5) → 1+0.5+0.5+0.5+1.5=4 ✓
  2.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節3: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節4: 付点4分 8分休 8分 8分 付点4分 → 1.5+0.5+0.5+0.5+1=4 ✓
  2.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節5: 4分 4分休 8分休 8分 8分 8分 → 1+1+0.5+0.5+0.5+0.5=4 ✓
  1.0f, 1.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節6: 同上
  1.0f, 1.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節7: 同上
  1.0f, 1.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節8: 同上
  1.0f, 1.0f, 0.5f, 0.5f, 0.5f, 0.5f,

  // 小節9: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節10: 小節2と同型
  2.0f, 0.5f, 0.5f, 0.5f, 0.5f,

// 小節12: 4分×4 → 4拍 ✓
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節13: 付点2分 + 4分休 → 3+1=4拍 ✓
  3.0f, 1.0f
};


// ----------------------------------------------------------
//  楽譜（もりのくまさん 伴奏・低音部）
//
//  【構成】楽譜.pdf 低音部譜（ヘ音記号）より
//    全て4分音符（1拍）単位  ，=休符  /=小節区切り（コメント参考用）
//    和音コード進行: C(ド) / F(ファ) / G(ソ)  13小節 × 4拍 = 52拍
//
//  【主旋律との時刻関係】
//    先頭の2拍休符が主旋律の弱起（アウフタクト）と同期する
//    → 伴奏小節n（n=1〜13）= 主旋律Mn が完全に一致
//
//    弱起 (2拍): 休 休
//    小節1 (4拍): ド 休 ド 休   ← 主旋律M1: ド↑ソミド↓
//    小節2 (4拍): ファ ラ シ ラ   ← 主旋律M2: ラ(休)ラシラ
//    小節3 (4拍): ソ ファ ミ レ   ← 主旋律M3: ソソ#ラシ
//    小節4 (4拍): ド（高）休 休 休 ← 主旋律M4: ド↑(休)ソファ#ソ
//    小節5 (4拍): ド 休 ド 休   ← 主旋律M5〜M6
//    小節6 (4拍): ド 休 ド 休
//    小節7 (4拍): ソ 休 ソ 休   ← 主旋律M7
//    小節8 (4拍): ド 休 ド 休   ← 主旋律M8
//    小節9 (4拍): ド 休 ド 休   ← 主旋律M9
//    小節10(4拍): ファ ファ 休 休  ← 主旋律M10
//    小節11(4拍): ソ 休 ソ 休   ← 主旋律M11
//    小節12(4拍): ド 休 休 休   ← 主旋律M12: ソソ#ラシ
//    小節13(4拍): ド 休 休 休   ← 主旋律M13: 高いド（終止）
// ----------------------------------------------------------

int[] bassPitch = {
  // 弱起（2拍休符: 主旋律のアウフタクトと同期）
  REST, REST,

  // 小節1 (= 主旋律M1): ド、ド、
  C3, C3, E3, E3,

  // 小節2 (= 主旋律M2): ファラシラ
  F3, F3, Fs3, Fs3,

  // 小節3 (= 主旋律M3): ソファミレ
  G3, F3, E3, D3,

  // 小節4 (= 主旋律M4): ド（高い方=C4）、、、
  C3, REST, REST, REST,

  // 小節5 (= 主旋律M5): ド、ド、
  C3, G2, C3, G2,

  // 小節6 (= 主旋律M6): ド、ド、
  C3, G2, C3, G2,

  // 小節7 (= 主旋律M7): ソ、ソ、
  D3, G2, D3, G2,

  // 小節8 (= 主旋律M8): ド、ド、
  C3, G2, C3, G2,

  // 小節9 (= 主旋律M9): ド、ド、
  C3, C3, E3, E3,

  // 小節10 (= 主旋律M10): ファファ、、
  F3, F3, Fs3, Fs3,


  // 小節12 (= 主旋律M12: ソソ#ラシ): ド、、、
  G3, Gs3, A3, B3,

  // 小節13 (= 主旋律M13: 高いド 終止): ド、、、
  C4, REST, REST, REST
};

// 全て4分音符（1拍）: 弱起2拍 + 小節12本×4拍 = 50拍
float[] bassDuration_120 = {
  1.0f, 1.0f,              // 弱起
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節1
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節2
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節3
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節4
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節5
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節6
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節7
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節8
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節9
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節10
  1.0f, 1.0f, 1.0f, 1.0f,  // 小節12
  1.0f, 1.0f, 1.0f, 1.0f   // 小節13
};

float currentBpm = 120.0;

// ----------------------------------------------------------
//  シリアル通信設定（設計書 WBS 211-B）
//  Slave Arduino（木琴担当）との Serial ポートを管理する
// ----------------------------------------------------------
Serial slavePort;                    // Slave Arduino との Serial オブジェクト
final int  SERIAL_PORT_IDX = 0;     // ポートインデックス（環境に合わせて変更）
final int  SERIAL_BAUD     = 9600;   // slave.ino に合わせて統一


// ----------------------------------------------------------
//  MarimbaInstrument（倍音合成版 v4 / ADSR方式）
//
//  【構成】
//    osc1: 基音  × 1.0  振幅50%
//    osc2: 2倍音 × 2.0  振幅10%
//    osc3: 3倍音 × 3.0  振幅10%
//    osc4: 4倍音 × 4.0  振幅35%  ← 木琴特有の明るい高音感
//    4本を Summer → ADSR → out の順でパッチ
//
//  【エンベロープ（ADSR クラス使用）】
//    Attack:   1ms（ほぼ瞬時・鳴った瞬間が最大音量）
//    Decay:  150ms（すぐ消える）
//    Sustain:  0.0（完全にゼロ）
//    Release:  10ms（noteOff 後の短い後処理）
//
//  【Gain+Line 方式を廃止した理由】
//    Line.activate() 完了後も最終値を出力し続ける仕様のため、
//    複数の Line が UGenInput に混入すると音が永続していた。
//    ADSR は noteOn()/noteOff() に完全対応しており、この問題が起きない。
// ----------------------------------------------------------
class MarimbaInstrument implements Instrument {
  Oscil  osc1, osc2, osc3, osc4;
  Summer summer;
  ADSR   adsr;

  MarimbaInstrument(float frequency, float amp) {
    osc1 = new Oscil(frequency * 1.0f, 0.50f, Waves.SINE);
    osc2 = new Oscil(frequency * 2.0f, 0.10f, Waves.SINE);
    osc3 = new Oscil(frequency * 3.0f, 0.10f, Waves.SINE);
    osc4 = new Oscil(frequency * 4.0f, 0.35f, Waves.SINE);

    summer = new Summer();
    osc1.patch(summer);
    osc2.patch(summer);
    osc3.patch(summer);
    osc4.patch(summer);

    // ADSR(maxAmplitude, attackTime, decayTime, sustainLevel, releaseTime)
    // Attack:   1ms  （打鍵の鋭さ・瞬時に最大音量）
    // Decay:  150ms  （音色のデジタル感を抑えた自然な減衰）
    // Sustain:  0.0  （打楽器なのでサステインなし）
    // Release: 10ms  （noteOff 後の短い後処理）
    adsr = new ADSR(amp, 0.001f, 0.15f, 0.0f, 0.01f);
    summer.patch(adsr);
  }

  void noteOn(float duration) {
    adsr.patch(out);
    adsr.noteOn();
  }

  void noteOff() {
    adsr.noteOff();
    adsr.unpatch(out);
  }
}


// ----------------------------------------------------------
//  MarimbaBasInstrument（伴奏・低音部用）
//
//  【主旋律 MarimbaInstrument との違い】
//    低音域（C3〜G3）で高次倍音が多いと主旋律と混濁するため，
//    基音（70%）と2倍音（20%）のみ使用し，3・4倍音を省く．
//    Decay を 200ms に延ばしてやや温かみのある低音感を出す．
//    音量は主旋律と同じ 0.6 を標準とする．
// ----------------------------------------------------------
class MarimbaBasInstrument implements Instrument {
  Oscil  osc1, osc2;
  Summer summer;
  ADSR   adsr;

  MarimbaBasInstrument(float frequency, float amp) {
    osc1 = new Oscil(frequency * 1.0f, 0.70f, Waves.SINE);  // 基音 70%
    osc2 = new Oscil(frequency * 2.0f, 0.20f, Waves.SINE);  // 2倍音 20%

    summer = new Summer();
    osc1.patch(summer);
    osc2.patch(summer);

    // ADSR(maxAmplitude, attackTime, decayTime, sustainLevel, releaseTime)
    // Attack: 1ms  Decay: 200ms（主旋律より長めで温かみのある低音）
    // Sustain: 0.0  Release: 10ms
    adsr = new ADSR(amp, 0.001f, 0.20f, 0.0f, 0.01f);
    summer.patch(adsr);
  }

  void noteOn(float duration) {
    adsr.patch(out);
    adsr.noteOn();
  }

  void noteOff() {
    adsr.noteOff();
    adsr.unpatch(out);
  }
}

float midiToFreq(int note) {
  return 440.0 * pow(2.0, (note - 69) / 12.0);
}

void playMarimba() {
  out.pauseNotes();

  float beatSec = 60.0 / currentBpm;   // 4分音符1拍の秒数

  // --- 主旋律（t=0 から開始，伴奏と同期）---
  //   伴奏の先頭2拍休符（弱起）と主旋律の弱起が同時に始まり，
  //   伴奏小節n = 主旋律Mn が完全に一致する
  float melodyTime = 0.0;
  for (int i = 0; i < pitch.length; i++) {
    float durationSec = duration_120[i] * beatSec;
    if (pitch[i] != REST) {
      out.playNote(melodyTime, durationSec,
        new MarimbaInstrument(midiToFreq(pitch[i]), 0.6f));
    }
    melodyTime += durationSec;
  }

  // --- 伴奏（低音部）: t=0 から開始 ---
  float bassTime = 0.0;
  for (int j = 0; j < bassPitch.length; j++) {
    float durationSec = bassDuration_120[j] * beatSec;
    if (bassPitch[j] != REST) {
      out.playNote(bassTime, durationSec,
        new MarimbaBasInstrument(midiToFreq(bassPitch[j]), 0.6f));
    }
    bassTime += durationSec;
  }

  out.resumeNotes();
}


// ----------------------------------------------------------
//  serialEvent: Slave Arduinoから音符パケットを受信して発音
//  （設計書 WBS 211 / SlaveProcessing仕様）
//
//  【受信フォーマット】"noteNumber,duration_ms\n"
//    noteNumber  : MIDIノート番号（0=REST，21〜108が有効）
//    duration_ms : 音符の長さ（ミリ秒，BPM120固定）
//  【Duration変換】durationSec = duration_ms / 1000.0
//  【振幅】velocity未送信のため 0.8 固定
//
//  ※ 先輩コード（Slave.ino）の2フィールド形式に合わせた実装
// ----------------------------------------------------------
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if (inString == null) return;
  inString = trim(inString);
  if (inString.length() == 0) return;

  // "START" / "END" などの制御文字列はスキップ
  if (!inString.contains(",")) {
    println("[Marimba] 制御メッセージ: " + inString);
    return;
  }

  String[] parts = split(inString, ',');
  if (parts.length != 2) {
    println("[Marimba] 不正パケット（フィールド数≠2）: " + inString);
    return;
  }

  int noteNumber  = int(trim(parts[0]));
  int duration_ms = int(trim(parts[1]));

  // 休符（noteNumber == 0）は無音・発音しない（Arduinoは送らないが念のため）
  if (noteNumber == REST) return;

  // 範囲チェック
  if (noteNumber < 21 || noteNumber > 108) {
    println("[Marimba] noteNumber範囲外: " + noteNumber);
    return;
  }
  if (duration_ms <= 0) {
    println("[Marimba] duration_ms不正: " + duration_ms);
    return;
  }

  // ms → 秒 変換 / 振幅は固定（velocity未送信）
  float durationSec = duration_ms / 1000.0f;
  float freq        = midiToFreq(noteNumber);
  float amp         = 0.8f;

  out.pauseNotes();
  out.playNote(0, durationSec, new MarimbaInstrument(freq, amp));
  out.resumeNotes();

  println("[Marimba] note=" + noteNumber
          + "  dur=" + duration_ms + "ms"
          + "  (" + nf(durationSec, 1, 3) + "s)");
}


void setup() {
  size(512, 200);
  textSize(13);
  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(currentBpm);

  // シリアルポート初期化（設計書 WBS 211-B）
  String[] ports = Serial.list();
  println("=== シリアルポート一覧 ===");
  printArray(ports);
  if (ports.length > SERIAL_PORT_IDX) {
    slavePort = new Serial(this, ports[SERIAL_PORT_IDX], SERIAL_BAUD);
    slavePort.bufferUntil('\n');   // 改行まで溜めてからserialEventを発火
    println("[Serial] 木琴Slave接続: " + ports[SERIAL_PORT_IDX]);
  } else {
    println("[警告] シリアルポートが見つかりません（Arduino未接続？）");
    println("       手動試聴は 'p' キーで可能");
  }

  println("=== 木琴スレーブ Processing 起動 ===");
  println("'p': 楽譜全体試聴  '+'/'-': BPM変更  (Arduinoからは自動受信)");
}

void draw() {
  background(0);

  // 波形モニタ
  stroke(180, 220, 140);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50  + out.left.get(i)*50,  i+1, 50  + out.left.get(i+1)*50);
    line(i, 150 + out.right.get(i)*50, i+1, 150 + out.right.get(i+1)*50);
  }

  noStroke();
  // Arduino接続状態表示（緑=接続中 / 赤=未接続）
  fill(slavePort != null ? color(100, 220, 100) : color(220, 100, 100));
  text("Arduino: " + (slavePort != null ? "接続中" : "未接続"), 10, 16);
  // BPM表示
  fill(180, 220, 140);
  text("BPM: " + (int)currentBpm, 10, 32);
  // 操作説明
  fill(100);
  text("'p': 楽譜試聴テスト   '+'/'-': BPM ±10", 10, 190);
}

void keyPressed() {
  if      (key == 'p') { playMarimba(); }
  else if (key == '+') { currentBpm = min(300, currentBpm + 10); println("BPM: " + currentBpm); }
  else if (key == '-') { currentBpm = max(1,   currentBpm - 10); println("BPM: " + currentBpm); }
}
