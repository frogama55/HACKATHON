import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// フルート音色クラス
// - 加算合成（基音 + 2,3,4倍音）でフルートらしい倍音構成
// - ADSR で「フッ」と立ち上がって持続する管楽器の包絡
// - ビブラート（LFOで周波数を微妙に揺らす）
// - ブレスノイズ（息のかすれを薄く加える）
class Flute implements Instrument {
  Oscil  wave;       // メインの音
  ADSR   ampEnv;     // 音量包絡
  Oscil  vibrato;    // ビブラート用LFO（周波数変調）
  Noise  breath;     // ブレスノイズ
  ADSR   breathEnv;  // ブレスノイズ用の包絡

  Flute(float frequency, float amplitude) {
    // 加算合成の倍音比（メモ通り：基音100% / 2倍30% / 3倍5% / 4倍2%）
    float[] amps   = { 1.0f, 0.30f, 0.05f, 0.02f };
    float[] mults  = { 1.0f, 2.0f,  3.0f,  4.0f  };
    float[] phases = { 0.0f, 0.0f,  0.0f,  0.0f  };
    Waveform fluteWave = WavetableGenerator.gen9(4096, mults, amps, phases);

    // メイン音
    wave = new Oscil(frequency, amplitude, fluteWave);

    // ADSR: A=50ms / D=10ms / S=0.85 / R=200ms
    ampEnv = new ADSR(amplitude, 0.050, 0.010, 0.85, 0.200);

    // ビブラート: 5Hz、深さは基本周波数の0.5%程度
    vibrato = new Oscil(5.0, frequency * 0.005, Waves.SINE);
    Summer freqSum = new Summer();
    Constant baseFreq = new Constant(frequency);
    baseFreq.patch(freqSum);
    vibrato.patch(freqSum);
    freqSum.patch(wave.frequency);

    // wave -> ampEnv
    wave.patch(ampEnv);

    // ブレスノイズ（薄く）
    breath = new Noise(amplitude * 0.05, Noise.Tint.WHITE);
    breathEnv = new ADSR(amplitude * 0.05, 0.030, 0.050, 0.30, 0.150);
    breath.patch(breathEnv);
  }

  void noteOn(float duration) {
    ampEnv.noteOn();
    ampEnv.patch(out);
    breathEnv.noteOn();
    breathEnv.patch(out);
  }

  void noteOff() {
    ampEnv.noteOff();
    ampEnv.unpatchAfterRelease(out);
    breathEnv.noteOff();
    breathEnv.unpatchAfterRelease(out);
  }
}

// テスト用：森のくまさん風の主旋律
String[] melody = {
  "C4", "E4", "G4", "E4", "C4", "E4", "G4", "E4",
  "F4", "F4", "F4", "D4", "G4", "G4", "G4", "E4"
};
float[] duration = {
  0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
  0.5, 0.5, 1.0, 1.0, 0.5, 0.5, 1.0, 1.0
};
float[] startTime = {
  0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5,
  4.0, 4.5, 5.0, 6.0, 7.0, 7.5, 8.0, 9.0
};

void setup() {
  size(512, 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
}

void draw() {
  background(0);
  stroke(255);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50  - out.left.get(i)*50,  i+1, 50  - out.left.get(i+1)*50);
    line(i, 150 - out.right.get(i)*50, i+1, 150 - out.right.get(i+1)*50);
  }
  fill(255);
  textSize(14);
  text("p: play melody  /  1-8: single note", 10, 20);
}

void playSong() {
  out.pauseNotes();
  for (int i = 0; i < melody.length; i++) {
    float f = Frequency.ofPitch(melody[i]).asHz();
    out.playNote(startTime[i], duration[i], new Flute(f, 0.5));
  }
  out.resumeNotes();
}

void keyPressed() {
  if (key == 'p') {
    playSong();
    return;
  }
  int idx = key - '1';
  if (idx >= 0 && idx < 8) {
    String[] scale = {"C4","D4","E4","F4","G4","A4","B4","C5"};
    float f = Frequency.ofPitch(scale[idx]).asHz();
    out.playNote(0.0, 1.0, new Flute(f, 0.5));
  }
}
