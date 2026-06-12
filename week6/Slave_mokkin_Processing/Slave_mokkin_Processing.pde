// ============================================================
//  木琴（Marimba）音色モジュール
//  Slave_Marimba.pde
//
//  楽譜: もりのくまさん ハ長調 4/4拍子
//  音色: 正弦波3本（基音 + 2倍音 + 4倍音）倍音合成 + ADSR(Gain + Line2本)
// ============================================================

import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// ----------------------------------------------------------
//  MIDIノート番号
// ----------------------------------------------------------
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
//    小節12(2拍): ド 4分休  ← 弱起に対応する終止小節
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
  A3, REST, A3, B3, A3,

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

  // 【小節11 4拍】ソ ファ ミ レ  (4分×4)
  G4, F4, E4, D4,

  // 【小節12 2拍】ド 4分休  ← 弱起に対応する終止小節
  C4, REST
};

float[] duration_120 = {
  // 弱起: 8分 8分 8分 8分
  0.5f, 0.5f, 0.5f, 0.5f,

  // 小節1: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節2: 4分 8分 8分 8分 8分 → 1+0.5+0.5+0.5+0.5=3 … 4拍に合わせる
  // ラ(4分) 8分休 ラ(8分) シ(8分) ラ(付点4分=1.5) → 1+0.5+0.5+0.5+1.5=4 ✓
  1.0f, 0.5f, 0.5f, 0.5f, 1.5f,

  // 小節3: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節4: 付点4分 8分休 8分 8分 付点4分 → 1.5+0.5+0.5+0.5+1=4 ✓
  1.5f, 0.5f, 0.5f, 0.5f, 1.0f,

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
  1.0f, 0.5f, 0.5f, 0.5f, 1.5f,

  // 小節11: 4分×4
  1.0f, 1.0f, 1.0f, 1.0f,

  // 小節12: 付点2分 + 4分休 → 3+1=4拍 ✓
  3.0f, 1.0f
};

float currentBpm = 120.0;


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

float midiToFreq(int note) {
  return 440.0 * pow(2.0, (note - 69) / 12.0);
}

void playMarimba() {
  out.pauseNotes();
  float startTimeSec = 0.0;
  for (int i = 0; i < pitch.length; i++) {
    float durationSec = duration_120[i] * 60.0 / currentBpm;
    if (pitch[i] != REST) {
      out.playNote(startTimeSec, durationSec,
        new MarimbaInstrument(midiToFreq(pitch[i]), 0.6f));
    }
    startTimeSec += durationSec;
  }
  out.resumeNotes();
}

void setup() {
  size(512, 200);
  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(currentBpm);
  println("pitch: " + pitch.length + "  duration: " + duration_120.length);
  println("'p':試聴  '+':BPM+10  '-':BPM-10");
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
}

void keyPressed() {
  if      (key == 'p') { playMarimba(); }
  else if (key == '+') { currentBpm = min(300, currentBpm + 10); println("BPM: " + currentBpm); }
  else if (key == '-') { currentBpm = max(1,   currentBpm - 10); println("BPM: " + currentBpm); }
}
