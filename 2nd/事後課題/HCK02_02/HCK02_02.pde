 import processing.serial.*;
 import ddf.minim.*;
 import ddf.minim.ugens.*;
 float[] arduinoWave;

 Minim minim;
 AudioOutput out;
 Waveform currentWaveform; // 音色格納用変数
Serial port; // シリアルポート
int col; // x座標⽤


void setup(){
// ウィンドウサイズ
size(512, 200);

arduinoWave = new float[512]; //初期化


 // 音色の初期値（ 正弦波）
 currentWaveform = Waves.SINE;
// ポートを初期化
port = new Serial(this, "/dev/cu.usbmodem34B7DA62C5742",921600); //COM3は接続するポート名なので、場合による
// シリアルポートの初期化
port.clear();
}

void draw() {
   
 background(0);
 stroke(255);

 for(int i = 0; i < arduinoWave.length - 1; i++) //ここ。outlengthから変更。
 {
 line( i, 50 + arduinoWave[i]*50, i+1, 50 + arduinoWave[i + 1]*50 );
 line( i, 150 + arduinoWave[i]*50, i+1, 150 + arduinoWave[i + 1]*50 ); //この2行も、arduinowaveに
 }
 }


// データが送信されてきたら呼び出される関数
void serialEvent(Serial p) {
  // シリアルポートから1行（改行まで）読み込む
  String inString = p.readStringUntil('\n');
  
  if (inString != null) {
    inString = trim(inString); // 空白や改行を削除
    
    // 空文字でない場合のみ処理を実行
    if (inString.length() > 0) {
      float newVal = float(inString); // 文字列を数値に変換

      // 【押し出し処理】データを1つずつ左にずらす
      for (int i = 0; i < arduinoWave.length - 1; i++) {
        arduinoWave[i] = arduinoWave[i + 1];
      }

      // 配列の最後（一番右端）に最新の値を代入
      arduinoWave[arduinoWave.length - 1] = newVal;
    }
  }
}
