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

  // BPMをMasterへ初期送信
  sendBpmToMaster(currentBpm);

  println("=== AcousticOrchestra 起動完了 ===");
  println("'+'/'-': BPM変更  ↑↓矢印キー: BPM変更");
}


// ----------------------------------------------------------
//  draw: 画面描画（設計書 図3.9 draw()）
//  音声処理はserialEvent()で行うためdrawは描画のみ
// ----------------------------------------------------------
void draw() {
  background(0);

  // 波形モニタ（左ch）
  stroke(180, 220, 140);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 80  + out.left.get(i)  * 50,
         i+1, 80  + out.left.get(i+1)  * 50);
    line(i, 180 + out.right.get(i) * 50,
         i+1, 180 + out.right.get(i+1) * 50);
  }

  // BPM表示
  fill(255);
  noStroke();
  text("BPM: " + (int)currentBpm, 10, 20);

  // ポート接続状態表示
  text("Master : " + (masterPort   != null ? "接続中" : "未接続"), 10, 40);
  text("Piano  : " + (slavePorts[0] != null ? "接続中" : "未接続"), 10, 56);
  text("Marimba: " + (slavePorts[1] != null ? "接続中" : "未接続"), 10, 72);
  text("Flute  : " + (slavePorts[2] != null ? "接続中" : "未接続"), 10, 88);
  text("Drum   : " + (slavePorts[3] != null ? "接続中" : "未接続"), 10, 104);

  // クマアニメーション（設計書 FBS アニメーション機能 / WBS 219）
  updateBear();
  drawBearScene();

  // 操作説明（草地エリア内の下端に表示）
  fill(200);
  noStroke();
  text("+ / ↑ : BPM +10    - / ↓ : BPM -10", 10, 410);
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
