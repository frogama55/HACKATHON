// ============================================================
// Controller.pde - プロトタイプ（PC5用）
// Enterキーで送信するだけ
// ============================================================

import processing.serial.*;

Serial masterPort;

void setup() {
  size(300, 150);
  printArray(Serial.list());
  // ★ ポート番号を環境に合わせて変更
  masterPort = new Serial(this, Serial.list()[3], 9600);
  masterPort.bufferUntil('\n');
  println("Enterキーで送信");
}

void draw() {
  background(30);
  fill(255);
  textAlign(CENTER);
  textSize(15);
  text("Enterキーで演奏開始", width/2, height/2);
}

void keyPressed() {
  if (key == ENTER || key == RETURN) {
    // BPM=120, OCT=4, ID1=1（ピアノ）, ID2=0, ID3=0
    masterPort.write("120,4,1,0,0\n");
    println("送信: 120,4,1,0,0");
  }
}

void serialEvent(Serial p) {
  String line = trim(p.readStringUntil('\n'));
  if (line != null) println("Master: " + line);
}
