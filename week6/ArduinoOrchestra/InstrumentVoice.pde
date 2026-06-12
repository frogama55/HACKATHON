// ============================================================
//  InstrumentVoice.pde
//  音符データの共通データ構造（設計書 PBS 2.1 / クラス図 図3.3）
//
//  Arduinoスレーブから受信した1音分のデータを保持する。
//  パケット内部に楽器識別情報は持たない（受信ポートで判別）。
// ============================================================

class InstrumentVoice {
  int noteNumber;    // MIDIノート番号 (0〜127)
  int soundStrength; // 音量 (0〜127)  ※設計書では固定値想定
  int durationSlots; // 8分音符スロット数

  InstrumentVoice(int noteNumber, int soundStrength, int durationSlots) {
    this.noteNumber    = noteNumber;
    this.soundStrength = soundStrength;
    this.durationSlots = durationSlots;
  }

  // デバッグ用文字列
  String toString() {
    return "note=" + noteNumber + " vel=" + soundStrength + " slots=" + durationSlots;
  }
}
