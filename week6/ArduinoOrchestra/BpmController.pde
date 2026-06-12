// ============================================================
//  BpmController.pde
//  BPM管理・キー入力・MasterへのSerial送信
//  （設計書 PBS 2.1.1 / FBS 1.5 / 表3.10）
//
//  【設計書の仕様】
//    - キーボード入力でBPMを変更
//    - BPM範囲制限: 1〜300
//    - 変更時のみMaster ArduinoへSerial送信
//    - BPM表示UIを更新
// ============================================================

// BPMはMain.pdeで宣言したグローバル変数 currentBpm を参照

void updateBpm(float newBpm) {
  // 範囲制限（設計書: 1〜300）
  newBpm = constrain(newBpm, 1, 300);

  // 変化がない場合は送信しない（設計書: 変更時のみ送信）
  if (abs(newBpm - currentBpm) < 0.01) return;

  currentBpm = newBpm;
  println("[BPM] " + (int)currentBpm);

  // Master ArduinoへBPMをSerial送信（設計書 FBS 1.5）
  sendBpmToMaster(currentBpm);
}

void sendBpmToMaster(float bpm) {
  // masterPortはSerialManager.pdeで宣言
  if (masterPort == null) {
    println("[BPM送信] masterPort未接続");
    return;
  }
  // BPMを文字列で送信（改行区切り）
  // Arduinoのreceivion処理に合わせてint値を送る
  masterPort.write(int(bpm) + "\n");
  println("[BPM送信] → Master: " + int(bpm));
}

// キーボード入力処理（Main.pdeのkeyPressed()から呼ぶ）
void handleKeyForBpm(char k) {
  // 上矢印 or 'u': BPM+10
  // 下矢印 or 'd': BPM-10
  // 数字キー: そのままBPM指定（今回は省略、必要に応じて拡張）
  if (k == 'u' || k == CODED) return;  // CODED（矢印）はkeyPressed側で処理

  if (k == '+') updateBpm(currentBpm + 10);
  else if (k == '-') updateBpm(currentBpm - 10);
}

// 矢印キー対応（Main.pdeのkeyPressed()からkeyCodeで呼ぶ）
void handleKeyCodeForBpm(int code) {
  if      (code == UP)   updateBpm(currentBpm + 10);
  else if (code == DOWN) updateBpm(currentBpm - 10);
}
