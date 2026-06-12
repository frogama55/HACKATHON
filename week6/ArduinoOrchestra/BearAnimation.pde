// ============================================================
//  BearAnimation.pde
//  BPM連動クマ走りアニメーション
//  （設計書 FBS アニメーション機能 / WBS 219 / テスト項目 314）
//
//  【仕様】
//    ・BPM=120（BASE_BPM_ANIM）を基準速度とする
//    ・speedMultiplier = currentBpm / BASE_BPM_ANIM に比例して
//      移動速度・足アニメーション速度が変化する
//    ・クマは画面左端外（x=-70）から右端外（x=width+70）まで走り，
//      右端を超えると左端に戻る（ループ）
//    ・足の往復はsin波で表現；前後脚はPI差の逆位相で自然な走り
//
//  【座標基準】
//    drawBear(x, y) の x,y は「足元（地面接触点）」を指す
//    胴体中心は y-25, 頭中心は y-40, 耳天頂は y≈-61
// ============================================================

float bearX         = -70.0f;  // クマX座標（胴体中心付近）
float bearAnimPhase = 0.0f;    // 脚アニメーション位相 [rad]

final float BEAR_Y        = 360.0f;  // 足元Y座標（地面）
final float BASE_BPM_ANIM = 120.0f;  // 基準BPM
final float BASE_SPEED    = 2.5f;    // BPM120時の移動速度 [px/frame]
final float BASE_PHASE    = 0.13f;   // BPM120時の位相進み [rad/frame]
//  BPM120・60fps時: 0.13*60=7.8 rad/s → 一歩=2π/7.8≈0.81s ≈ 1拍


// ----------------------------------------------------------
//  updateBear: draw()から毎フレーム呼び出す（位置・位相の更新）
// ----------------------------------------------------------
void updateBear() {
  float mult    = currentBpm / BASE_BPM_ANIM;
  bearX         += BASE_SPEED * mult;
  bearAnimPhase += BASE_PHASE * mult;
  if (bearX > width + 70) bearX = -70;
}


// ----------------------------------------------------------
//  drawBearScene: 草地背景・地面ライン・クマ本体をまとめて描画
//  draw() の末尾（テキスト描画の前）から呼ぶ
// ----------------------------------------------------------
void drawBearScene() {
  pushStyle();

  // 草地エリアの背景（BEAR_Y-65 〜 画面下端）
  noStroke();
  fill(15, 50, 15);
  rect(0, BEAR_Y - 65, width, height - (BEAR_Y - 65));

  // 地面ライン（草の色で1本）
  stroke(100, 180, 80);
  strokeWeight(2);
  line(0, BEAR_Y, width, BEAR_Y);

  // クマ本体
  drawBear(bearX, BEAR_Y);

  popStyle();
}


// ----------------------------------------------------------
//  drawBear: クマ1体を描画
//    x, y : 足元（地面接触点）座標
//    クマは右向き（右方向へ走る）
// ----------------------------------------------------------
void drawBear(float x, float y) {
  pushMatrix();
  translate(x, y);   // ローカル原点 = 足元（地面）

  // ---- 脚スイング量（正弦波） ----
  // 前後脚はPI差（逆位相）で対角の脚が同時に前に出るトロット
  float swingF = sin(bearAnimPhase)      * 17.0f;  // 前脚
  float swingB = sin(bearAnimPhase + PI) * 17.0f;  // 後脚

  // ---- 色 ----
  color furBase  = color(139,  90, 43);   // 胴体・頭・脚
  color furBelly = color(195, 145, 80);   // 腹部・足先
  color furInner = color(215, 165, 115);  // 耳の内側
  color noseDark = color( 60,  30,  8);   // 鼻・口

  // ---- 影（地面に映る楕円）----
  noStroke();
  fill(0, 0, 0, 50);
  ellipse(5, -3, 58, 10);

  // ---- 後ろ脚（胴体より先に描いて「後ろに隠れた」ように見せる）----
  strokeCap(ROUND);
  strokeWeight(9);
  stroke(furBase);
  line(-10, -13, -10 + swingB, 0);  // 後左脚
  line(  2, -12,   2 + swingB, 0);  // 後右脚
  // 足先（丸く）
  strokeWeight(13);
  stroke(furBelly);
  point(-10 + swingB, 0);
  point(  2 + swingB, 0);

  // ---- 胴体（横長楕円）----
  noStroke();
  fill(furBase);
  ellipse(0, -25, 52, 28);
  // 腹部ハイライト
  fill(furBelly);
  ellipse(0, -23, 30, 15);

  // ---- 頭（右側＋やや上：右向きに走る構図）----
  fill(furBase);
  ellipse(23, -41, 34, 30);

  // ---- 耳 ----
  fill(furBase);
  ellipse(13, -55, 16, 16);
  ellipse(31, -54, 16, 16);
  fill(furInner);
  ellipse(13, -55,  9,  9);
  ellipse(31, -54,  9,  9);

  // ---- 目 ----
  fill(20);
  ellipse(18, -43, 5, 5);
  ellipse(30, -43, 5, 5);
  // ハイライト
  fill(255, 255, 255, 210);
  ellipse(19, -44, 2, 2);
  ellipse(31, -44, 2, 2);

  // ---- 鼻 ----
  fill(noseDark);
  ellipse(25, -35, 10, 7);

  // ---- 口 ----
  stroke(noseDark);
  strokeWeight(1.5f);
  noFill();
  arc(25, -30, 8, 5, 0.1f, PI - 0.1f);

  // ---- 前脚（胴体より後に描いて「手前に出た」ように見せる）----
  strokeCap(ROUND);
  strokeWeight(9);
  stroke(furBase);
  line(-3, -13, -3 + swingF, 0);   // 前左脚
  line( 9, -12,  9 + swingF, 0);   // 前右脚
  // 足先（丸く）
  strokeWeight(13);
  stroke(furBelly);
  point(-3 + swingF, 0);
  point( 9 + swingF, 0);

  popMatrix();
}
