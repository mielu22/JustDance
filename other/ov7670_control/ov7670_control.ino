/*
   Wire - I2C Scanner
   The WeMos D1 Mini I2C bus uses pins:
   D1 = SCL
   D2 = SDA
*/

#include <Wire.h>

/*These are settings some of which have been found empirically and/or found 
from random internet sites. When you see that there's a "magic" number it 
isn't a magic number like in comp sci or something...it just means we have 
no idea why this register value seems to help since the data sheet doesn't 
give a ton of guidance.  I'm sure there's rational explanations for many of 
these numbers, but sometimes I've just got bills to pay and life to live 
and don't have time to figure out why. You know the deal.
*/

const byte ADDR = 0x21; //name of the camera on I2C

uint8_t settings[][2] = {
//{addr, value}, //dscription
  {0x12, 0x80}, //reset
  {0x01, 0x80}, //blue gain (default 80)
  {0x02, 0xFF}, //red gain  (default 80)
  {0x6A, 0x00}, //green gain -- want it low
  {0xFF, 0xF0}, //delay
  {0x12, 0x14}, // COM7,     set RGB color output (QVGA and test pattern 0x6...for RGB video 0x4)
  {0x11, 0x80}, // CLKRC     internal PLL matches input clock
  {0x0C, 0x00}, // COM3,     default settings
  {0x3E, 0x00}, // COM14,    no scaling, normal pclock
  {0x04, 0x00}, // COM1,     disable CCIR656
  {0x40, 0xD0}, //COM15,     RGB565, full output range
  {0x3A, 0x04}, //TSLB       set correct output data sequence (magic)
  {0x14, 0x18}, //COM9       MAX AGC value x4
  {0x4C, 0x00}, //DNSTH      de-noise strength
  {0x4F, 0xB3}, //MTX1       all of these are magical matrix coefficients
  {0x50, 0xB3}, //MTX2
  {0x51, 0x00}, //MTX3
  {0x52, 0x3D}, //MTX4
  {0x53, 0xA7}, //MTX5
  {0x54, 0xE4}, //MTX6
  {0x58, 0x9E}, //MTXS
  {0x3D, 0xC0}, //COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
  {0x17, 0x14}, //HSTART     start high 8 bits
  {0x18, 0x02}, //HSTOP      stop high 8 bits //these kill the odd colored line
  {0x32, 0x80}, //HREF       edge offset
  {0x19, 0x03}, //VSTART     start high 8 bits
  {0x1A, 0x7B}, //VSTOP      stop high 8 bits
  {0x03, 0x0A}, //VREF       vsync edge offset
  {0x0F, 0x41}, //COM6       reset timings
  {0x1E, 0x20}, //MVFP       disable mirror / flip //might have magic value of 03
  {0x33, 0x0B}, //CHLF       //magic value from the internet
  {0x3C, 0x78}, //COM12      no HREF when VSYNC low
  {0x69, 0x00}, //GFIX       fix gain control
  {0x74, 0x00}, //REG74      Digital gain control
  {0xB0, 0x84}, //RSVD       magic value from the internet *required* for good color
  {0xB1, 0x0C}, //ABLC1
  {0xB2, 0x0E}, //RSVD       more magic internet values
  {0xB3, 0x80}, //THL_ST
  //begin mystery scaling numbers. Thanks, internet!
  {0x70, 0x3A},
  {0x71, 0x35},
  {0x72, 0x11},
  {0x73, 0xF0},
  {0xA2, 0x02},
  //gamma curve values
    {0x7A, 0x20},
    {0x7B, 0x10},
    {0x7C, 0x1E},
    {0x7D, 0x35},
    {0x7E, 0x5A},
    {0x7F, 0x69},
    {0x80, 0x76},
    {0x81, 0x80},
    {0x82, 0x88},
    {0x83, 0x8F},
    {0x84, 0x96},
    {0x85, 0xA3},
    {0x86, 0xAF},
    {0x87, 0xC4},
    {0x88, 0xD7},
    {0x89, 0xE8},
  //AGC and AEC
    {0x13, 0xE0}, //COM8, disable AGC / AEC
    {0x00, 0x00}, //set gain reg to 0 for AGC
    {0x10, 0x00}, //set ARCJ reg to 0
    {0x0D, 0x40}, //magic reserved bit for COM4
    {0x14, 0x18}, //COM9, 4x gain + magic bit
    {0xA5, 0x05}, // BD50MAX
    {0xAB, 0x07}, //DB60MAX
    {0x24, 0x95}, //AGC upper limit
    {0x25, 0x33}, //AGC lower limit
    {0x26, 0xE3}, //AGC/AEC fast mode op region
    {0x9F, 0x78}, //HAECC1
    {0xA0, 0x68}, //HAECC2
    {0xA1, 0x03}, //magic
    {0xA6, 0xD8}, //HAECC3
    {0xA7, 0xD8}, //HAECC4
    {0xA8, 0xF0}, //HAECC5
    {0xA9, 0x90}, //HAECC6
    {0xAA, 0x94}, //HAECC7
    {0x13, 0xE7} //COM8, enable AGC //AEC (was 0xe5) (try this at 0xe7)

}; 
uint8_t output_state;

void setup()
{
  Wire.begin();
  Serial.begin(115200);
  Serial.println("Starting");
  delay(1000);
  Wire.beginTransmission(ADDR);
  Wire.write(0x0A);
  Wire.requestFrom(ADDR, 2);
  byte LSB = Wire.read();
  byte MSB = Wire.read();
  uint16_t val = ((MSB << 8) | LSB);
  Wire.endTransmission();
  Serial.println(val);
  for (int i = 0; i < sizeof(settings) / 2; i++) {
    Wire.beginTransmission(ADDR);
    Wire.write(settings[i][0]);
    Wire.write(settings[i][1]);
    //    Wire.write(RegValues[i][1]);
    //    Wire.write(RegValues[i][2]);
    Wire.endTransmission();
  }
  //  Wire.write(0x12);
  //  Wire.write(0x4);
  Serial.println("OV7670 Setup Done");
  pinMode(4, INPUT_PULLUP);
  output_state = 0;
}


void loop()
{

}


void writeByte(uint8_t target_reg, uint8_t val) {
  Wire.beginTransmission(ADDR);
  Wire.write(target_reg);
  Wire.write(val);
  Wire.endTransmission();
}

void readBytes(uint8_t target_reg, uint8_t* val_out, uint8_t num_bytes) {
  Wire.beginTransmission(ADDR);
  Wire.write(target_reg);
  Wire.requestFrom(ADDR, num_bytes);
  uint8_t* ptr_to_out;
  ptr_to_out = val_out;
  for (int i = 0; i < num_bytes; i++) {
    *ptr_to_out = Wire.read();
    ptr_to_out++;
  }
}
