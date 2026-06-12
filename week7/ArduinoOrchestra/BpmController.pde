// ============================================================
//  BpmController.pde
//  演奏制御（BPM・オクターブ・演奏順）管理と Master Serial 送信
//  （設計書 FBS 演奏制御機能 / WBS 211 / 7.3 I2C送信フォーマット）
//
//  【送信フォーマット（設計書 7.3）】
//    "BPM,OCT,ID1,ID2,ID3\n"
//    楽器ID: 0x01=Piano  0x02=Flute  0x03=Marimba  0x00=未選択
//
//  【送信タイミング（設計書 8.2）】
//    'S'キー（暫定）または「送信・開始」ボタン（WBS 212〜214 実装後）
//    BPM・OCT変更だけでは送信しない
//
//  【廣岡担当UIとの連携インターフェース（WBS 212〜214）】
//    addToPlayOrder(int id) : 楽器ボタンクリック時に呼ぶ（WBS 213）
//    resetPlayOrder()       : リセットボタンクリック時に呼ぶ（WBS 214）
//    sendDataToMaster()     : 送信・開始ボタンクリック時に呼ぶ（WBS 212）
// ============================================================

// ---- 楽器ID定数（設計書 7.3） ----
final int ID_PIANO   = 0x01;  // 1番
final int ID_FLUTE   = 0x02;  // 2番
final int ID_MARIMBA = 0x03;  // 3番

// ---- 楽器名（表示・ログ用） ----
final String[] INST_NAMES = {"(未選択)", "Piano", "Flute", "Marimba"};

// ---- 演奏制御状態（廣岡担当UIから参照・更新される） ----
int   currentOctave = 4;            // オクターブ（デフォルト4）
int[] playOrder     = {0, 0, 0};    // 演奏順の楽器ID [1番, 2番, 3番]  0=未選択
int   orderCount    = 0;             // 選択済み楽器数（0〜3）


// ----------------------------------------------------------
//  updateBpm: BPM値を更新（送信は行わない）
// ----------------------------------------------------------
void updateBpm(float newBpm) {
  newBpm = constrain(newBpm, 1, 300);
  if (abs(newBpm - currentBpm) < 0.01) return;
  currentBpm = newBpm;
  println("[BPM] " + (int)currentBpm);
}


// ----------------------------------------------------------
//  sendDataToMaster: 設計書7.3の5byteフォーマットでMasterへ送信
//  "BPM,OCT,ID1,ID2,ID3\n"
//  呼び出し元: 'S'キー（暫定）、または廣岡担当「送信・開始」ボタン
// ----------------------------------------------------------
void sendDataToMaster() {
  if (masterPort == null) {
    println("[送信] masterPort未接続 → スキップ");
    return;
  }
  String packet = int(currentBpm) + ","
                + currentOctave  + ","
                + playOrder[0]   + ","
                + playOrder[1]   + ","
                + playOrder[2]   + "\n";
  masterPort.write(packet);
  println("[送信] → Master: " + trim(packet));
}


// ----------------------------------------------------------
//  addToPlayOrder: 楽器を演奏順に追加
//  廣岡担当の楽器選択ボタン（WBS 213）からも呼ぶ
//  仕様: 同一楽器の2回追加は無効（設計書 8.2）
// ----------------------------------------------------------
void addToPlayOrder(int instrumentId) {
  // 既に選択済みの楽器は無効（設計書 8.2）
  for (int i = 0; i < orderCount; i++) {
    if (playOrder[i] == instrumentId) {
      println("[演奏順] " + INST_NAMES[instrumentId] + " は既に選択済み（スキップ）");
      return;
    }
  }
  if (orderCount >= 3) {
    println("[演奏順] 3楽器すべて選択済み（リセットは 'R' キー）");
    return;
  }
  playOrder[orderCount] = instrumentId;
  orderCount++;
  println("[演奏順] " + orderCount + "番目に "
          + INST_NAMES[instrumentId] + " を追加");
}


// ----------------------------------------------------------
//  resetPlayOrder: 演奏順をリセット
//  廣岡担当のリセットボタン（WBS 214）からも呼ぶ
// ----------------------------------------------------------
void resetPlayOrder() {
  playOrder[0] = 0;
  playOrder[1] = 0;
  playOrder[2] = 0;
  orderCount   = 0;
  println("[演奏順] リセット済み");
}


// ----------------------------------------------------------
//  handleKeyForBpm: キーボード入力処理（Main.pdeから呼ぶ）
//
//  暫定キー割当（WBS 212〜214 のUI実装後は不要になるものあり）
//    + / -   : BPM ±10
//    S       : 送信・開始（暫定）
//    R       : 演奏順リセット（暫定）
//    1 / 2 / 3 : Piano / Flute / Marimba を演奏順に追加（テスト用）
// ----------------------------------------------------------
void handleKeyForBpm(char k) {
  if      (k == '+') updateBpm(currentBpm + 10);
  else if (k == '-') updateBpm(currentBpm - 10);
  else if (k == 's' || k == 'S') sendDataToMaster();
  else if (k == 'r' || k == 'R') resetPlayOrder();
  // テスト用：楽器を演奏順に追加
  else if (k == '1') addToPlayOrder(ID_PIANO);
  else if (k == '2') addToPlayOrder(ID_FLUTE);
  else if (k == '3') addToPlayOrder(ID_MARIMBA);
}

void handleKeyCodeForBpm(int code) {
  if      (code == UP)   updateBpm(currentBpm + 10);
  else if (code == DOWN) updateBpm(currentBpm - 10);
}
