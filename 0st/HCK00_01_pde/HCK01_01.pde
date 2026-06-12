void setup(){  //　初期化、一度だけ実行
  size(480, 120);  //実行ウィンドウサイズ(幅、高さ)単位はピクセル。
}

void draw() { // 一秒間に60回、繰り返し実行、アニメーションを描画
  if (mousePressed) { // mousePressed：マウス押されたらtrue
    fill(0); //　数字で色指定
  } else {
    fill(255);// 数字で色指定
  }
  ellipse(mouseX, mouseY, 80, 80); //座標、幅、高さを指定して円を描く。mouseXとYでマウスの場所を指定
 }
