// ============================================================
// BearAnimation.pde — アニメーションモジュール
// 外部から currentBpm と isPlaying を書き込んで制御する。
// プロジェクトに組み込む際は、このファイルをタブとして追加し、
// メインの draw() で updateBear() と drawBearScene() を呼ぶだけでよい。
// ============================================================

float   currentBpm = 120.0;   // 外部から書き込み可
boolean isPlaying  = false;   // 外部から書き込み可

final float BASE_BPM   = 120.0;  // 基準BPM
final float BASE_SPEED = 5.0;    // BPM120時の木スクロール速度 [px/frame]

float   legAngle = 0;
float[] treeX    = new float[4];
float[] cloudX   = new float[3];

// ---- 初期化（setup()から1回呼ぶ） ---------------------------
void initBear() {
  for (int i = 0; i < treeX.length; i++) treeX[i] = i * 250;
  for (int i = 0; i < cloudX.length; i++) cloudX[i] = i * 300 + 50;
}

// ---- 位置更新（isPlaying=false なら何もしない） -------------
void updateBear() {
  if (!isPlaying) return;
  float spd = BASE_SPEED * (currentBpm / BASE_BPM);
  for (int i = 0; i < cloudX.length; i++) {
    cloudX[i] -= spd * 0.2;
    if (cloudX[i] < -100) cloudX[i] = width + 100;
  }
  for (int i = 0; i < treeX.length; i++) {
    treeX[i] -= spd;
    if (treeX[i] < -100) treeX[i] = width + 100;
  }
  legAngle += spd * 0.05;
}

// ---- 描画（背景は呼び出し側で描くこと） ---------------------
void drawBearScene() {
  noStroke();
  for (int i = 0; i < cloudX.length; i++) drawCloud(cloudX[i], 80 + (i % 2) * 40);
  for (int i = 0; i < treeX.length;  i++) drawTree(treeX[i], 280);
  drawBear(width / 2, 250, legAngle);
}

void drawBear(float x, float y, float angle) {
  fill(139, 69, 19);
  float swing = sin(angle) * 20;
  ellipse(x-20-swing, y+20, 15, 30);
  ellipse(x+20+swing, y+20, 15, 30);
  ellipse(x, y, 90, 60);
  ellipse(x+40, y-20, 50, 50);
  ellipse(x+30, y-40, 15, 15);
  ellipse(x+50, y-40, 15, 15);
  ellipse(x-20+swing, y+20, 15, 30);
  ellipse(x+20-swing, y+20, 15, 30);
  fill(0);
  ellipse(x+50, y-25, 5, 5);
  ellipse(x+60, y-15, 8, 8);
}

void drawTree(float x, float y) {
  fill(139, 69, 19);
  rect(x-10, y-60, 20, 60);
  fill(0, 100, 0);
  ellipse(x, y-80, 80, 80);
}

void drawCloud(float x, float y) {
  fill(255);
  ellipse(x,      y,      60, 60);
  ellipse(x + 30, y + 10, 50, 50);
  ellipse(x - 30, y + 10, 50, 50);
}
