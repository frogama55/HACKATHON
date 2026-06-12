// ============================================================
//  SoundSynthesizer.pde
//  全楽器の音色生成・発音
//  （設計書 PBS 2.1.2〜2.1.5 / FBS 1.1〜1.4 / 表3.10）
//
//  【各楽器のADSR設計方針】
//    Piano  : Attack中 / Decay中  / Sustain中  （打鍵後じわっと消える）
//    Marimba: Attack極短/ Decay急峻/ Sustain極低（「コン」と鳴って即消える）
//    Flute  : Attack中 / Decay長  / Sustain高  （息が続く滑らかな音）
//    Drum   : WhiteNoiseベース    / Sustain極低（打撃の破裂音）
// ============================================================

// ----------------------------------------------------------
//  Instrument クラス群（各楽器用）
// ----------------------------------------------------------

// ---- ピアノ ------------------------------------------------
class PianoInstrument implements Instrument {
  Oscil wave;
  Line  attackLine;
  Line  decayLine;
  float maxAmp;
  float sustainLevel;

  final float ATTACK_SEC    = 0.02f;
  final float DECAY_SEC     = 0.5f;
  final float SUSTAIN_RATIO = 0.4f;

  PianoInstrument(float frequency, float amp) {
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
  void noteOff() { wave.unpatch(out); }
}

// ---- 木琴 --------------------------------------------------
// 倍音合成版（基音+2倍音+3倍音+4倍音）+ ADSR エンベロープ
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
    // ADSR(maxAmp, attackSec, decaySec, sustainLevel, releaseSec)
    // Attack: 1ms  Decay: 150ms  Sustain: 0.0  Release: 10ms
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

// ---- フルート ----------------------------------------------
// 設計書: 偶数倍音強調と長いSustainによりフルートらしい滑らかな音色
class FluteInstrument implements Instrument {
  Oscil wave;
  Line  attackLine;
  Line  decayLine;
  float maxAmp;
  float sustainLevel;

  final float ATTACK_SEC    = 0.08f;   // やや長め（息の立ち上がり）
  final float DECAY_SEC     = 0.3f;
  final float SUSTAIN_RATIO = 0.75f;   // 高め（息が続く）

  FluteInstrument(float frequency, float amp) {
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
  void noteOff() { wave.unpatch(out); }
}

// ---- ドラム（スネア）---------------------------------------
// 設計書: WhiteNoiseとADSRでスネアとハイハットの破裂音を生成
class SnareInstrument implements Instrument {
  Noise noise;
  Line  ampEnv;
  float maxAmp;

  final float DECAY_SEC = 0.15f;

  SnareInstrument(float amp) {
    this.maxAmp = amp;
    noise  = new Noise(0, Noise.Tint.WHITE);
    ampEnv = new Line();
    ampEnv.patch(noise.amplitude);
  }
  void noteOn(float duration) {
    ampEnv.activate(DECAY_SEC, maxAmp, 0);
    noise.patch(out);
  }
  void noteOff() { noise.unpatch(out); }
}

// ---- ドラム（ハイハット）-----------------------------------
class HihatInstrument implements Instrument {
  Noise noise;
  Line  ampEnv;
  float maxAmp;

  final float DECAY_SEC = 0.05f;  // スネアより短い

  HihatInstrument(float amp) {
    this.maxAmp = amp;
    noise  = new Noise(0, Noise.Tint.WHITE);
    ampEnv = new Line();
    ampEnv.patch(noise.amplitude);
  }
  void noteOn(float duration) {
    ampEnv.activate(DECAY_SEC, maxAmp, 0);
    noise.patch(out);
  }
  void noteOff() { noise.unpatch(out); }
}


// ----------------------------------------------------------
//  MIDIノート番号 → Hz 変換（共通）
// ----------------------------------------------------------
float midiToFreq(int note) {
  return 440.0 * pow(2.0, (note - 69) / 12.0);
}

// 1スロット（8分音符）の秒数
float slotSec() {
  return 60.0 / currentBpm / 2.0;
}


// ----------------------------------------------------------
//  各楽器の発音関数（PacketRouterから呼ばれる）
// ----------------------------------------------------------

void playPiano(InstrumentVoice v) {
  float freq = midiToFreq(v.noteNumber);
  float amp  = v.soundStrength / 127.0;
  float dur  = v.durationSlots * slotSec();
  out.pauseNotes();
  out.playNote(0, dur, new PianoInstrument(freq, amp));
  out.resumeNotes();
}

void playMarimba(InstrumentVoice v) {
  float freq = midiToFreq(v.noteNumber);
  float amp  = v.soundStrength / 127.0;
  float dur  = v.durationSlots * slotSec();
  out.pauseNotes();
  out.playNote(0, dur, new MarimbaInstrument(freq, amp));
  out.resumeNotes();
}

void playFlute(InstrumentVoice v) {
  float freq = midiToFreq(v.noteNumber);
  float amp  = v.soundStrength / 127.0;
  float dur  = v.durationSlots * slotSec();
  out.pauseNotes();
  out.playNote(0, dur, new FluteInstrument(freq, amp));
  out.resumeNotes();
}

void playDrum(InstrumentVoice v) {
  // ドラムはnoteNumberでスネア/ハイハットを判別
  // 設計書: スネア=38, ハイハット=42 (一般的なGMドラムマップに準拠)
  float amp = v.soundStrength / 127.0;
  float dur = v.durationSlots * slotSec();
  out.pauseNotes();
  if (v.noteNumber == 42) {
    out.playNote(0, dur, new HihatInstrument(amp));
  } else {
    // デフォルトはスネア
    out.playNote(0, dur, new SnareInstrument(amp));
  }
  out.resumeNotes();
}
