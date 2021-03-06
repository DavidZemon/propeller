'Test of SPIN driver for Sparkfun's Graphical LCD 160x128 Huge Display
'Copyright 2008 Raymond Allen
' Bignum procedures added by Massimo De Marchi
' demo showing the use of the big fonts
' thanks to Raymond for providing the code and the license
' updating of the screen can be slow, with double buffering the problem is reduced
' just remember to commit..
' commit function is present on both objects, for compatibility
' this way it is possible to choose between the two options
' just changing the object name  
' Version 1.10 Feb 16th 2010
''*  See end of file for terms of use.   *  
 

CON  'Constants Section

  _clkmode = xtal1 + pll16x      'using 5 MHz crystal in pll16x mode
  _xinfreq = 5_000_000           'to achieve 80 Mhz clock frequency

VAR
 

  
OBJ  'Objects Section
  lcd:"HugeLcdDriver1.10_db"
  num2:"simple_numbers"

  
PUB Main|i , j, time

    ' pin 20 is the backlight driver
  'Start the lcd driver
  lcd.Start   'You must manually set pin Numbers in the driver at this time!!!!
  
  j:=0


  waitcnt(clkfreq/5+cnt)

  

  

  repeat
      lcd.blon
      lcd.cls
      lcd.goto(3,0)
      lcd.str(string("original demo")) 
      lcd.goto(10,2)
      lcd.putc("X")
       
      'Type some text
      lcd.goto(0,5)
      lcd.str(String("Hello there."))
       
      'Put out text with a number
      lcd.goto(5,7)
      lcd.str(string("Voltage= "))
      lcd.str(string(49))
      lcd.str(string( " kV"))
       
      'Show a number in hex and binary
      i:=cnt 'using cnt as the number to show
      'Show hex
      lcd.goto(0,9)
      lcd.str(string("CNT hex= $"))
      lcd.str(num2.hex(i,8))
      'Show binary
      lcd.goto(0,11)
      lcd.str(string("bin="))
      lcd.goto(0,12)
      lcd.str(string("%"))
      lcd.str(num2.bin(i>>16,16))
      lcd.goto(1,13)
      lcd.str(num2.bin(i,16))
       
      'Move and size the cursor
      lcd.setcursorsize(8)
      lcd.movecursor(16,13)
       
       
      'Draw a horizontal line
      repeat i from 0 to lcd#xPixels-1
        lcd.SetPixel(i,9)
       
      'draw a slanted line
      repeat i from 0 to lcd#yPixels
        lcd.SetPixel(i,i)
       
      'Clear a pixel where those lines cross
      lcd.ClearPixel(9,9)
      lcd.commit

      waitcnt(clkfreq+cnt)
      
      ' end of the first part of the demo, the original part

      lcd.cls_inverted
      lcd.goto(3,0)
      lcd.str(string("modified demo")) 
      lcd.goto(10,2)
      lcd.putc("X")
       
      'Type some text
      lcd.goto(0,5)
      lcd.str(String("Hello there."))
       
      'Put out text with a number
      lcd.goto(5,7)
      lcd.str(string("Voltage= "))
      lcd.str(string(49))
      lcd.str(string( " kV"))
       
      'Show a number in hex and binary
      i:=cnt 'using cnt as the number to show
      'Show hex
      lcd.goto(0,9)
      lcd.str(string("CNT hex= $"))
      lcd.str(num2.hex(i,8))
      'Show binary
      lcd.goto(0,11)
      lcd.str(string("bin="))
      lcd.goto(0,12)
      lcd.str(string("%"))
      lcd.str(num2.bin(i>>16,16))
      lcd.goto(1,13)
      lcd.str(num2.bin(i,16))
       
      'Move and size the cursor
      lcd.setcursorsize(8)
      lcd.movecursor(16,13)
       
       
      'Draw a horizontal line
      repeat i from 0 to lcd#xPixels-1
        lcd.clearPixel(i,9)
       
      'draw a slanted line
      repeat i from 0 to lcd#yPixels
        lcd.clearPixel(i,i)
       
      'Clear a pixel where those lines cross
      lcd.togglePixel(9,9)
      lcd.commit
      waitcnt(clkfreq+cnt)

      '' big fonts
      lcd.cls
      'Draw a horizontal line
      repeat i from 0 to lcd#xPixels-1
        lcd.togglePixel(i,8)
      lcd.bigstring(string("BIG FONTS!"),0,1,false)
      lcd.bigstring(string("→↑   "),0,2,true)
      lcd.bigstring(num2.dec(12345),0,3,false)
      lcd.smalldot(4,3)
      lcd.goto(1,0)

      lcd.str(string("PARALLAX BIG FONTS"))

      lcd.commit 
      waitcnt(clkfreq+cnt)
      
      lcd.bloff
      waitcnt(clkfreq+cnt)

{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
      