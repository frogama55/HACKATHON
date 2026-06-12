import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*; // 追加:FFT（高速フーリエ変換）を使うためのライブラリ

float[] arduinoWave;
FFT fft; // 追加:FFTオブジェクト

Serial port; // シリアルポート

void setup() {
  size(512, 300); 

  arduinoWave = new float[512]; // FFTを行うため、配列サイズは2の累乗である必要

  // FFTの初期化 (バッファサイズ, サンプリング周波数)
  fft = new FFT(arduinoWave.length, 5000);
  
  // 窓関数（ハミング窓）を適用すると、波形の端の不連続性が軽減され、スペクトルがより綺麗（正確）に表示されます
  fft.window(FFT.HAMMING);

  // ポートを初期化
  port = new Serial(this, "/dev/cu.usbmodem34B7DA62C5742", 921600);
  port.clear();
}

void draw() {
  background(0);
  
  // 1. 生の波形を描画する (今までできていた部分)
  stroke(100); // スペクトルを目立たせるため、波形は少し暗めの色に
  for (int i = 0; i < arduinoWave.length - 1; i++) {
    line(i, 50 + arduinoWave[i] * 20, i + 1, 50 + arduinoWave[i + 1] * 20);
  }

  // 2. スペクトルアナライザを描画する (今回の課題のメイン)
  // arduinoWaveに入っている現在の波形データを使ってFFT解析を実行します
  fft.forward(arduinoWave);

  stroke(0, 255, 0); // スペクトルは緑色で描画
  
  // fft.specSize() は、通常バッファサイズの半分 (512なら257) になります
  // 低音から高音まで、各周波数帯域（バンド）ごとにループを回します
  for (int i = 0; i < fft.specSize(); i++) {
    // getBand(i) で、その周波数帯域の音の大きさ（振幅）を取得します
    float bandAmplitude = fft.getBand(i) * 100;
    line(i * 2, height, i * 2, height - bandAmplitude);
  }
}

// データが送信されてきたら呼び出される関数
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if (inString != null) {
    inString = trim(inString);
    if (inString.length() > 0) {
      float newVal = float(inString);

      // データを1つずつ左にずらす
      for (int i = 0; i < arduinoWave.length - 1; i++) {
        arduinoWave[i] = arduinoWave[i + 1];
      }
      // 配列の最後（一番右端）に最新の値を代入
      arduinoWave[arduinoWave.length - 1] = newVal;
    }
  }
}
