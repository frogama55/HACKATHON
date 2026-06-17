#include <Wire.h>

void setup() {
  Serial.begin(9600);
  Wire.begin(0x08);
  Wire.onReceive(onReceive);
  Serial.println("Slave ready");
}

void loop() {}

void onReceive(int n) {
  Serial.println("received!");
}