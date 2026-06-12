// ============================================================
//  Main.pde
//  全体の起点（設計書 PBS 2.1 / 表3.6 / 図3.9）
//
//  【ファイル構成（設計書 図3.2）】
//    Main.pde            ← このファイル（初期化・描画・キー入力）
//    BpmController.pde   ← BPM変更・Master送信
//    SerialManager.pde   ← 5台のSerial管理・serialEvent
//    PacketRouter.pde    ← パケット解析・楽器振り分け
//    SoundSynthesizer.pde← 全楽器の音色生成
//    InstrumentVoice.pde ← 音符データ構造体
//
//  【起動手順】
//    1. Arduino5台をUSBハブ経由でPCに接続
//    2. SerialManager.pde の PORT_IDX_*** を環境に合わせて設定
//    3. このスケッチを実行
//    4. Arduinoがリセットされ演奏開始
//    5. '+'/'-' キーでBPMを変更
// ============================================================

import ddf.minim.*;
import ddf.minim.ugens.*;

// ----------------------------------------------------------
//  グローバル変数（全ファイルから参照される）
// ----------------------------------------------------------
Minim       minim;
AudioOutput out;
float       currentBpm = 120.0;  // BpmController・SoundSynthesizerと共有


// ----------------------------------------------------------
//  setup: 初期化（設計書 図3.9 setup()）
// ----------------------------------------------------------
void setup() {
  size(512, 420);
  textSize(13);

  // Minim初期化
  minim = new Minim(this);
  out   = minim.getLineOut();

  // Serialポート初期化（SerialManager.pde）
  setupSerialChannels();

  // 起動時は自動送信しない（設計書 8.2: 送信は「送信・開始」ボタン押下時）
  println("=== AcousticOrchestra 起動完了 ===");
  println("'+'/'-'↑↓: BPM変更  1/2/3: 演奏順選択  S: 送信・開始  R: 演奏順リセット");
}


// ----------------------------------------------------------
//  draw: 画面描画（設計書 図3.9 draw()）
//  音声処理はserialEvent()で行うためdrawは描画のみ
// ----------------------------------------------------------
void draw() {
  background(0);

  // --- 1. クマアニメーション（背景として最初に描画）---
  // v2: フル背景（空・雲・草原・木）を塗るため，他の描画より先に呼ぶ
  // テキスト・波形はこの上に重ねて表示される
  updateBear();
  drawBearScene();

  // --- 2. 波形モニタ（左ch）---
  stroke(180, 220, 140);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 80  + out.left.get(i)  * 50,
         i+1, 80  + out.left.get(i+1)  * 50);
    line(i, 180 + out.right.get(i) * 50,
         i+1, 180 + out.right.get(i+1) * 50);
  }

  // --- 3. ステータス表示（背景・波形の上に重ねる）---
  // 半透明の背景帯で視認性を確保
  noStroke();
  fill(0, 0, 0, 140);
  rect(0, 0, 210, 135);

  fill(255);
  text("BPM: " + (int)currentBpm + "   OCT: " + currentOctave, 10, 20);
  text("Master : " + (masterPort    != null ? "接続中" : "未接続"), 10, 40);
  text("Piano  : " + (slavePorts[0] != null ? "接続中" : "未接続"), 10, 56);
  text("Marimba: " + (slavePorts[1] != null ? "接続中" : "未接続"), 10, 72);
  text("Flute  : " + (slavePorts[2] != null ? "接続中" : "未接続"), 10, 88);
  text("Drum   : " + (slavePorts[3] != null ? "接続中" : "未接続"), 10, 104);

  fill(200, 200, 100);
  text("演奏順: " + INST_NAMES[playOrder[0]]
              + " → " + INST_NAMES[playOrder[1]]
              + " → " + INST_NAMES[playOrder[2]], 10, 122);

  // --- 4. 操作説明（最前面）---
  noStroke();
  fill(0, 0, 0, 140);
  rect(0, 400, width, 20);
  fill(200);
  text("+ / ↑ : BPM+10   - / ↓ : BPM-10   1/2/3: 演奏順選択   S: 送信・開始   R: リセット", 10, 415);
}


// ----------------------------------------------------------
//  キー入力（設計書 FBS 1.5 テンポ変更機能）
// ----------------------------------------------------------
void keyPressed() {
  if (key == CODED) {
    handleKeyCodeForBpm(keyCode);  // 矢印キー
  } else {
    handleKeyForBpm(key);           // +/- キー
  }
}
