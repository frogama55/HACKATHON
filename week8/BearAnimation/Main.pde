// ============================================================
// Main.pde — 統合時の仮ホスト（UI入力は別スケッチが担当）
// 統合先では setup/draw をそちらに移し、このファイルは削除する。
// currentBpm と isPlaying を外部から書き込むだけでアニメが動く。
// ============================================================

void setup() {
  size(800, 400);
  noStroke();
  initBear();
}

void draw() {
  background(135, 206, 235);  // 空
  fill(34, 139, 34);
  rect(0, 280, width, 120);   // 地面

  updateBear();
  drawBearScene();
}
