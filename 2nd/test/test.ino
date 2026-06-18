//書き写し。デジタル通信のため、アナログではなくデジタルピンを使用。
#define LED_ID 13
//LEDのポート
void setup(){
  //出力設定
  pinMode(LED_ID,OUTPUT);
}

void loop(){
  //HIGHを指定してLEDを点灯
  digitalWrite(LED_ID, HIGH);
  delay(1000); //1秒待つ
  //LOWを指定してLEDを消灯
  digitalWrite(LED_ID, LOW);
  delay(500); //500ms待つ
}