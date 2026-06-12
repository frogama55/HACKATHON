// ============================================================
//  SerialManager.pde
//  5台のArduinoとのSerial通信管理
//  （設計書 PBS 2.1.6 / クラス図 図3.3 / 表3.10）
//
//  【設計書の仕様】
//    - masterPort: MasterArduinoとの通信（BPM送信）
//    - slavePorts[]: スレーブ4台との通信（音符データ受信）
//    - serialEvent()で非同期受信
//    - 通信エラー処理（null・空文字チェック）
//
//  【ポート番号の設定方法】
//    1. setup()内で Serial.list() を実行してコンソールで確認
//    2. 各Arduinoを1台ずつ接続しながら番号を特定する
//    3. 下記の PORT_*** 定数を書き換える
// ============================================================

import processing.serial.*;

// ---- ポート名設定（環境に合わせて書き換える）----
// Serial.list() で確認した番号を指定する
// 例: Windows → "COM3" / Mac → "/dev/cu.usbmodem..."
// 暫定: Serial.list()[n] のインデックスで指定
final int PORT_IDX_MASTER  = 0;  // マスターArduino
final int PORT_IDX_PIANO   = 1;  // ピアノスレーブ
final int PORT_IDX_MARIMBA = 2;  // 木琴スレーブ
final int PORT_IDX_FLUTE   = 3;  // フルートスレーブ
final int PORT_IDX_DRUM    = 4;  // ドラムスレーブ

final int BAUD_RATE = 115200;

// ポートオブジェクト
Serial   masterPort;
Serial[] slavePorts = new Serial[4];

void setupSerialChannels() {
  // 利用可能なポート一覧を表示（デバッグ用）
  String[] ports = Serial.list();
  println("=== 利用可能なシリアルポート ===");
  printArray(ports);
  println("================================");

  // ポート数チェック
  if (ports.length < 5) {
    println("[警告] 接続されているポートが5台未満です（現在 " + ports.length + " 台）");
    println("       接続されているポートのみ初期化します");
  }

  // Master
  if (ports.length > PORT_IDX_MASTER) {
    try {
      masterPort = new Serial(this, ports[PORT_IDX_MASTER], BAUD_RATE);
      masterPort.clear();
      println("[Serial] Master  : " + ports[PORT_IDX_MASTER]);
    } catch (Exception e) {
      println("[警告] Master ポートを開けません: " + ports[PORT_IDX_MASTER]
              + " → " + e.getMessage());
      masterPort = null;
    }
  }

  // スレーブ4台
  int[][] slaveConfig = {
    {PORT_IDX_PIANO,   0},
    {PORT_IDX_MARIMBA, 1},
    {PORT_IDX_FLUTE,   2},
    {PORT_IDX_DRUM,    3}
  };
  String[] slaveNames = {"ピアノ", "木琴", "フルート", "ドラム"};

  for (int i = 0; i < slaveConfig.length; i++) {
    int portIdx  = slaveConfig[i][0];
    int slaveIdx = slaveConfig[i][1];
    if (ports.length > portIdx) {
      try {
        slavePorts[slaveIdx] = new Serial(this, ports[portIdx], BAUD_RATE);
        slavePorts[slaveIdx].clear();
        slavePorts[slaveIdx].bufferUntil('\n');
        println("[Serial] " + slaveNames[i] + "スレーブ: " + ports[portIdx]);
      } catch (Exception e) {
        println("[警告] " + slaveNames[i] + "スレーブのポートを開けません: "
                + ports[portIdx] + " → " + e.getMessage());
        slavePorts[slaveIdx] = null;
      }
    } else {
      println("[警告] " + slaveNames[i] + "スレーブのポートが見つかりません");
    }
  }
}

// ----------------------------------------------------------
//  serialEvent: データ受信時に自動呼び出し
//  （HCK02_02.pdeの手法を5ポート対応に拡張）
//
//  どのポートから来たかを判別し、PacketRouterへ渡す
// ----------------------------------------------------------
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if (inString == null) return;

  inString = trim(inString);
  if (inString.length() == 0) return;

  // 通信エラーチェック（設計書 PBS 2.1.6）
  // float変換できない文字列は破棄
  // ここではパース前にルーティングのみ行う
  routePacket(inString, p);
}
