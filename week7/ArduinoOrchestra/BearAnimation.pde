// ============================================================
//  BearAnimation.pde  v2 （背景スクロール方式）
//  BPM連動クマ走りアニメーション
//  （設計書 FBS アニメーション機能 / WBS 219 / テスト項目 315）
//
//  【v1 → v2 変更点】
//    v1: クマが左から右へ横移動する方式
//    v2: クマを画面中央に固定し，背景（木・雲）を左スクロールさせる
//        ことで「走っているように見せる」方式に変更
//
//  【速度制御】
//    speedMult   = currentBpm / BASE_BPM_ANIM
//    木スクロール = BASE_SPEED × speedMult  [px/frame]
//    雲スクロール = 木速度 × 0.3  （パラレックス効果）
//    脚位相進み   = BASE_PHASE × speedMult  [rad/frame]
//
//  【Main.pde との接続】
//    draw() 内から updateBear() → drawBearScene() の順で呼ぶだけでよい
//    setup() 側の変更は不要（初回 updateBear() 呼び出し時に自動初期化）
// ============================================================

// ---- アニメーション状態 ----
float   bearAnimPhase  = 0.0f;
boolean bearSceneReady = false;

// ---- 背景オブジェクト配列 ----
final int NUM_TREES  = 5;
final int NUM_CLOUDS = 4;
float[] treeX     = new float[NUM_TREES];
float[] treeScale = new float[NUM_TREES];  // 木ごとに大きさを変える
float[] cloudX    = new float[NUM_CLOUDS];
float[] cloudY    = new float[NUM_CLOUDS];

// ---- 定数 ----
final float GROUND_Y      = 295.0f;  // 地平線Y座標（空と草原の境界）
final float BEAR_FOOT_Y   = 355.0f;  // クマ足元Y（地面より少し奥）
final float BASE_BPM_ANIM = 120.0f;  // 基準BPM
final float BASE_SPEED    = 3.0f;    // BPM120時の背景移動速度 [px/frame]
final float BASE_PHASE    = 0.13f;   // BPM120時の脚位相進み [rad/frame]


// ----------------------------------------------------------
//  initBearScene: 背景オブジェクトの初期位置を設定
//  width が確定している draw() 内から初回呼び出し
// ----------------------------------------------------------
void initBearScene() {
  for (int i = 0; i < NUM_TREES; i++) {
    treeX[i]    = i * (width / (float)NUM_TREES);
    treeScale[i] = 0.75f + (i % 3) * 0.2f;  // 0.75 / 0.95 / 1.15 の3段階
  }
  for (int i = 0; i < NUM_CLOUDS; i++) {
    cloudX[i] = i * (width / (float)NUM_CLOUDS) + 40;
    cloudY[i] = 50 + (i % 3) * 28;  // 縦方向に少しずらす
  }
  bearSceneReady = true;
}


// ----------------------------------------------------------
//  updateBear: draw() から毎フレーム呼び出す
//  背景オブジェクトの座標と脚位相を更新する
// ----------------------------------------------------------
void updateBear() {
  if (!bearSceneReady) initBearScene();

  float mult = currentBpm / BASE_BPM_ANIM;
  float spd  = BASE_SPEED * mult;

  // 脚アニメーション位相
  bearAnimPhase += BASE_PHASE * mult;

  // 木を左スクロール（画面外に出たら右端から再登場）
  for (int i = 0; i < NUM_TREES; i++) {
    treeX[i] -= spd;
    if (treeX[i] < -90) treeX[i] = width + 90;
  }

  // 雲を左スクロール（木より遅め → パラレックス効果）
  for (int i = 0; i < NUM_CLOUDS; i++) {
    cloudX[i] -= spd * 0.3f;
    if (cloudX[i] < -120) cloudX[i] = width + 120;
  }
}


// ----------------------------------------------------------
//  drawBearScene: 空・雲・草原・木・クマをまとめて描画
//  【描画順の注意】
//  この関数はフル背景（空〜草原）を塗りつぶすため，
//  Main.pde の draw() では background() の直後（最初）に呼び出す。
//  波形モニタ・ステータステキストはこの後に描画することで
//  背景の上に重ねて表示される。
// ----------------------------------------------------------
void drawBearScene() {
  pushStyle();

  // --- 空 ---
  noStroke();
  fill(100, 160, 225);
  rect(0, 0, width, GROUND_Y);

  // --- 雲 ---
  for (int i = 0; i < NUM_CLOUDS; i++) {
    drawCloud(cloudX[i], cloudY[i]);
  }

  // --- 草原（地面） ---
  noStroke();
  fill(45, 130, 45);
  rect(0, GROUND_Y, width, height - GROUND_Y);

  // --- 地平線ライン ---
  stroke(120, 200, 80);
  strokeWeight(2);
  line(0, GROUND_Y, width, GROUND_Y);

  // --- 木 ---
  for (int i = 0; i < NUM_TREES; i++) {
    drawTree(treeX[i], GROUND_Y, treeScale[i]);
  }

  // --- クマ（画面中央に固定） ---
  drawBear(width / 2.0, BEAR_FOOT_Y);

  popStyle();
}


// ----------------------------------------------------------
//  drawCloud: 雲を楕円3つで描画
// ----------------------------------------------------------
void drawCloud(float x, float y) {
  noStroke();
  fill(255, 255, 255, 205);
  ellipse(x,       y,      68, 44);
  ellipse(x + 34,  y + 11, 54, 36);
  ellipse(x - 34,  y + 11, 54, 36);
}


// ----------------------------------------------------------
//  drawTree: 木（幹＋葉2段）を描画
//    x, y : 幹の根元座標
//    sc   : スケール係数（大きさのバリエーション）
// ----------------------------------------------------------
void drawTree(float x, float y, float sc) {
  pushMatrix();
  translate(x, y);
  noStroke();

  // 幹
  fill(100, 65, 25);
  rectMode(CENTER);
  rect(0, -28 * sc, 14 * sc, 55 * sc);

  // 葉（下段）
  fill(30, 115, 30);
  ellipse(0, -78 * sc, 72 * sc, 65 * sc);

  // 葉（上段・明るめ）
  fill(50, 145, 50);
  ellipse(0, -100 * sc, 50 * sc, 50 * sc);

  rectMode(CORNER);  // デフォルトに戻す
  popMatrix();
}


// ----------------------------------------------------------
//  drawBear: クマ1体を描画（v1から引き継ぎ）
//    x, y : 足元（地面接触点）座標
//    クマは右向き（走っている向き）
// ----------------------------------------------------------
void drawBear(float x, float y) {
  pushMatrix();
  translate(x, y);  // ローカル原点 = 足元

  // 脚スイング量（前後脚を逆位相にしてトロット走行を表現）
  float swingF = sin(bearAnimPhase)      * 17.0f;  // 前脚
  float swingB = sin(bearAnimPhase + PI) * 17.0f;  // 後脚

  // 色定義
  color furBase  = color(139,  90, 43);
  color furBelly = color(195, 145, 80);
  color furInner = color(215, 165, 115);
  color noseDark = color( 60,  30,  8);

  // 影
  noStroke();
  fill(0, 0, 0, 50);
  ellipse(5, -3, 58, 10);

  // 後ろ脚（胴体より先に描くことで「奥側」に見える）
  strokeCap(ROUND);
  strokeWeight(9);
  stroke(furBase);
  line(-10, -13, -10 + swingB, 0);
  line(  2, -12,   2 + swingB, 0);
  strokeWeight(13);
  stroke(furBelly);
  point(-10 + swingB, 0);
  point(  2 + swingB, 0);

  // 胴体
  noStroke();
  fill(furBase);
  ellipse(0, -25, 52, 28);
  fill(furBelly);
  ellipse(0, -23, 30, 15);

  // 頭（右側＋やや上：右向きに走る構図）
  fill(furBase);
  ellipse(23, -41, 34, 30);

  // 耳
  fill(furBase);
  ellipse(13, -55, 16, 16);
  ellipse(31, -54, 16, 16);
  fill(furInner);
  ellipse(13, -55,  9,  9);
  ellipse(31, -54,  9,  9);

  // 目
  fill(20);
  ellipse(18, -43, 5, 5);
  ellipse(30, -43, 5, 5);
  fill(255, 255, 255, 210);
  ellipse(19, -44, 2, 2);
  ellipse(31, -44, 2, 2);

  // 鼻
  fill(noseDark);
  ellipse(25, -35, 10, 7);

  // 口
  stroke(noseDark);
  strokeWeight(1.5f);
  noFill();
  arc(25, -30, 8, 5, 0.1f, PI - 0.1f);

  // 前脚（胴体の後に描くことで「手前側」に見える）
  strokeCap(ROUND);
  strokeWeight(9);
  stroke(furBase);
  line(-3, -13, -3 + swingF, 0);
  line( 9, -12,  9 + swingF, 0);
  strokeWeight(13);
  stroke(furBelly);
  point(-3 + swingF, 0);
  point( 9 + swingF, 0);

  popMatrix();
}
