{{
x_Main.spin
┌────────────────────────────────────┐
│   Copyright (c) 2009 Carl Jacobs   │
│ (See end of file for terms of use) │
└────────────────────────────────────┘

x_Main is our object loader. This file will load all of our objects into high
memory. 
}}

CON
  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000

  RxPin         = 31                                              
  TxPin         = 30                                              
  BaudRate      = 19200

  I2C_SDA       = 29
  I2C_SCL       = 28

OBJ
  ser  : "Simple_Serial"         'Give the user some feedback
  ee   : "x_Saver"               'This object does the EEPROM stuff

  ob1  : "x_JDCogSerial_pasm"    'The PASM part of the object
' ob2  : "x_MyObject_pasm" 

PUB Init | ptr, addr
  { Initialise the I2C port }
  ee.Init(I2C_SCL, I2C_SDA)
  { Load and start the serial port }
  ser.Start(RxPin, TxPin, BaudRate)
  { Continuously spit out the verification messages, otherwise we might miss it }  
  repeat
    ser.Rx
    ser.Str(string(13,10,"Load and Verify High EEPROM",13,10))
    
    { Repeat the following sequence for every object to go into high EEPROM }
    ser.Str(string("->JDCogSerial "))
    if ob1.Verify
      Verified
    else
      Loading
      ob1.Write

{
    ser.Str(string("->MyObject "))
    if ob2.Verify
      Verified
    else
      Loading
      ob2.Write
}

PRI Verified
  Ser.Str(string("Verified!",13,10))
  
PRI Loading
  Ser.Str(string("Loading . . .",13,10))


{{
 ───────────────────────────────────────────────────────────────────────────
                Terms of use: MIT License                                   
 ─────────────────────────────────────────────────────────────────────────── 
   Permission is hereby granted, free of charge, to any person obtaining a  
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation 
  the rights to use, copy, modify, merge, publish, distribute, sublicense,  
    and/or sell copies of the Software, and to permit persons to whom the   
    Software is furnished to do so, subject to the following conditions:    
                                                                            
   The above copyright notice and this permission notice shall be included  
           in all copies or substantial portions of the Software.           
                                                                            
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER   
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     
                       DEALINGS IN THE SOFTWARE.                            
 ─────────────────────────────────────────────────────────────────────────── 
}}  