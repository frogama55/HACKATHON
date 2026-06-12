/**
 * ============================================================
 * Flute Synthesis v2 — Processing + Minim
 * ============================================================
 *
 * 【v1 からの改良点（実測ベース）】
 * Philharmonia Orchestra のフルート音源 C4〜C5 を FFT解析し、
 * 倍音比/ADSR/ビブラート/ブレスノイズを音域別に決定した。
 * 詳細は計測結果.md を参照。
 *
 * 1. 周波数帯域別の倍音構造モデリング
 *    - 低音 (C4〜E4) は H2/H3/H4 が基音より大きい (H4=2.07)
 *    - 中低音 (F4〜G4) は H4 だけ局所突出
 *    - 中音 (A4〜C5) は基音主体、H3 が局所ピーク
 *    - v1 の固定値 {1.0, 0.30, 0.05, 0.02} はどの音域にも合わない
 *
 * 2. 周波数依存ブレスノイズ
 *    - 低音は息ノイズが支配的 (C4=60.9%、平均25.7%)
 *    - 高音側ほどクリーンに (G4=0.8%、平均3.2%)
 *    - v1 は固定 5%
 *
 * 3. 周波数依存 ADSR
 *    - 低音は Attack が長く (447ms)、ふっと立ち上がる
 *    - 中音は Sustain が高い (0.76) でロングトーンらしさ
 *    - v1 は固定 A=50ms/D=10ms/S=0.85/R=200ms
 *
 * 4. 周波数依存ビブラート
 *    - レート 5.0〜5.3Hz (一般的フルートと一致)
 *    - 深さは低音ほど深い (±2.05%) → 高音は浅め (±1.32%)
 *    - v1 は固定 5Hz, ±0.5%
 *
 * 【聴感調整1】低音帯の倍音比を最大値で正規化
 *    実測の低音 {1.0, 1.30, 1.40, 2.07} をそのまま加算合成すると、
 *    サイン波4本では脳が一番大きい H4 をピッチとして聞いてしまい、
 *    ドレミがずれて聞こえた。実録音では息ノイズ・打音・反響が
 *    弱い基音を「補完」してくれるが、本合成にはそれが無い。
 *    対策: 低音帯のみ 2.07 で割って正規化 → {1.0, 0.63, 0.68, 1.00}
 *    倍音バランス(形)は保ちつつ、基音がピッチ知覚を担うようにした。
 *
 * 【聴感調整2】低音のブレスノイズ量を抑える
 *    実測の低音ノイズ比 25.7% (C4単体では60.9%) をそのまま使うと、
 *    ドレミ演奏中ずっと「サー」というホワイトノイズが鳴って耳障り。
 *    実録音は息音の倍音や帯域偏りで馴染むが、ホワイトノイズ加算では
 *    高域までベタッと乗るので目立つ。
 *    対策: NOISE[低音] を 0.257 → 0.08 に下げる (v1の0.05に近い値)
 *
 * 【聴感調整3】ブレスノイズの ADSR を持続させない
 *    元設定 (D=0.050, S=0.30) ではノイズが音全体に持続していた。
 *    対策: D=0.100, S=0.05 に変更し、ノイズはアタック直後に
 *    ほぼ消える「息の吹き始め」だけの音にする。
 *
 * 【聴感調整4】ブレスノイズの尾を完全に消す
 *    調整3 (S=0.05) でも 5% のノイズが演奏中ずっと薄く残り、
 *    ドレミの後ろに「サー…」が聞こえてしまった。
 *    対策: S=0.00 / R=0.050 に変更し、アタック直後の
 *    「フッ」だけにして持続成分を完全に断つ。
 *
 * 【聴感調整5】低音ビブラートを浅く (横揺れ感の解消)
 *    実測 ±2.05% (約35セント = 半音の1/3) は深すぎて、
 *    ドレミの音程が「横に広がる」ように聞こえた。
 *    対策: VDEP[低音] 0.0205 → 0.0080 (±0.8% ≒ 14セント)
 *    中低音と同等のおとなしいビブラートに。
 *
 * 【聴感調整6】低音ノイズを更に削減 (連打時の残響感)
 *    調整4 で持続ノイズは消したが、ドレミ (0.5秒間隔) の連続演奏で
 *    毎回のアタック「フッ」が累積して、なお背景にノイズを感じた。
 *    対策: NOISE[低音] 0.08 → 0.03 (中低音と同レベル)
 */

import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 音域判定: 0=低音(C4〜E4), 1=中低音(F4〜G4), 2=中音(A4〜C5)
int getRegister(float freq) {
  if (freq < 340) return 0;
  if (freq < 410) return 1;
  return 2;
}

class Flute implements Instrument {
  Oscil wave, vibrato;
  ADSR  ampEnv, breathEnv;
  Noise breath;

  Flute(float frequency, float amplitude) {
    int reg = getRegister(frequency);

    // 帯域別パラメータ（FFT実測ベース）
    float[][] AMPS = {
      {1.0f, 0.63f, 0.68f, 1.00f},  // 低音 (実測 {1,1.30,1.40,2.07} を 2.07 で正規化)
      {1.0f, 0.85f, 0.79f, 0.98f},  // 中低音
      {1.0f, 0.38f, 0.71f, 0.09f}   // 中音
    };
    float[] ATK   = {0.447f, 0.412f, 0.303f};
    float[] DEC   = {0.103f, 0.055f, 0.027f};
    float[] SUS   = {0.59f,  0.61f,  0.76f };
    float[] REL   = {0.078f, 0.085f, 0.112f};
    float[] VRATE = {5.0f,   5.1f,   5.3f  };
    float[] VDEP  = {0.0080f,0.0079f,0.0132f};
    float[] NOISE = {0.03f, 0.013f, 0.032f};

    float[] mults  = {1.0f, 2.0f, 3.0f, 4.0f};
    float[] phases = {0, 0, 0, 0};
    Waveform fluteWave = WavetableGenerator.gen9(4096, mults, AMPS[reg], phases);

    // メイン音 + ADSR
    wave   = new Oscil(frequency, amplitude, fluteWave);
    ampEnv = new ADSR(amplitude, ATK[reg], DEC[reg], SUS[reg], REL[reg]);

    // ビブラート（LFO で周波数変調）
    vibrato = new Oscil(VRATE[reg], frequency * VDEP[reg], Waves.SINE);
    Summer freqSum = new Summer();
    new Constant(frequency).patch(freqSum);
    vibrato.patch(freqSum);
    freqSum.patch(wave.frequency);
    wave.patch(ampEnv);

    // ブレスノイズ（帯域別の比率）
    breath    = new Noise(amplitude * NOISE[reg], Noise.Tint.WHITE);
    breathEnv = new ADSR(amplitude * NOISE[reg], 0.030, 0.080, 0.00, 0.050);
    breath.patch(breathEnv);
  }

  void noteOn(float duration) {
    ampEnv.noteOn();    ampEnv.patch(out);
    breathEnv.noteOn(); breathEnv.patch(out);
  }
  void noteOff() {
    ampEnv.noteOff();    ampEnv.unpatchAfterRelease(out);
    breathEnv.noteOff(); breathEnv.unpatchAfterRelease(out);
  }
}

// 森のくまさん（C4〜G4）
String[] melody = {
  "C4","E4","G4","E4","C4","E4","G4","E4",
  "F4","F4","F4","D4","G4","G4","G4","E4"
};
float[] duration  = {0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0.5,0.5,1.0,1.0};
float[] startTime = {0.0,0.5,1.0,1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,6.0,7.0,7.5,8.0,9.0};

void setup() {
  size(512, 200);
  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(120);
}

void draw() {
  background(0);
  stroke(255);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50  - out.left.get(i)*50,  i+1, 50  - out.left.get(i+1)*50);
    line(i, 150 - out.right.get(i)*50, i+1, 150 - out.right.get(i+1)*50);
  }
  fill(255); textSize(14);
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
  if (key == 'p') { playSong(); return; }
  int idx = key - '1';
  if (idx >= 0 && idx < 8) {
    String[] scale = {"C4","D4","E4","F4","G4","A4","B4","C5"};
    float f = Frequency.ofPitch(scale[idx]).asHz();
    out.playNote(0.0, 1.0, new Flute(f, 0.5));
  }
}
