// ============================================================
//  PacketRouter.pde
//  受信データの解析と楽器ごとの振り分け
//  （設計書 PBS 2.1 / クラス図 図3.3 / 表3.10）
//
//  【設計書の仕様】
//    - 受信パケットをパースしInstrumentVoiceに変換
//    - 受信元ポートで楽器を判別（パケット内に楽器IDは持たない）
//    - 各楽器のplay関数へ振り分ける
//
//  【パケット仕様（設計書 3.3.3.3 sendNoteDataToProcessing より）】
//    フォーマット: "noteNumber,soundStrength,durationSlots\n"
//    例: "60,100,2\n"
// ============================================================

// ----------------------------------------------------------
//  parseNotePacket: 受信文字列 → InstrumentVoice
// ----------------------------------------------------------
InstrumentVoice parseNotePacket(String packet) {
  String[] parts = split(packet, ',');

  if (parts.length != 3) {
    println("[PacketRouter] 不正なパケット: " + packet);
    return null;
  }

  int noteNumber    = int(trim(parts[0]));
  int soundStrength = int(trim(parts[1]));
  int durationSlots = int(trim(parts[2]));

  // 範囲チェック（設計書 3.4.2 例外処理）
  if (noteNumber < 0 || noteNumber > 127) {
    println("[PacketRouter] noteNumber範囲外: " + noteNumber);
    return null;
  }
  if (durationSlots <= 0) {
    println("[PacketRouter] durationSlots不正: " + durationSlots);
    return null;
  }

  return new InstrumentVoice(noteNumber, soundStrength, durationSlots);
}

// ----------------------------------------------------------
//  routePacket: 受信元ポートで楽器を判別して発音関数へ振り分け
//  （設計書: 受信ポートによって楽器種別を判別する設計）
// ----------------------------------------------------------
void routePacket(String packet, Serial sourcePort) {
  InstrumentVoice voice = parseNotePacket(packet);
  if (voice == null) return;

  println("[PacketRouter] " + voice.toString());

  if      (sourcePort == slavePorts[0]) playPiano(voice);
  else if (sourcePort == slavePorts[1]) playMarimba(voice);
  else if (sourcePort == slavePorts[2]) playFlute(voice);
  else if (sourcePort == slavePorts[3]) playDrum(voice);
  else    println("[PacketRouter] 未知のポートからの受信");
}
