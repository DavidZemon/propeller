{{
SLED-C4 Display Driver  Demo
Richard Levergood
December 2011
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  sledtxpin = 0     ' Serial line to SLED
  sledrxpin = 1     ' AUX line frm SLED
  baud0 = 9600      ' pin 3 must be pulled high   
  baud1 = 19200     ' pin 3 must be pulled low     
  mode = %0000      ' invert rx mode

OBJ
  Sled : "ral_SLEDC4_10"
 
VAR
  long counter  

PUB main  
  Sled.start(sledrxpin,sledtxpin,mode,baud1)

''initialize SLED-C4.  CAUTION - use sparingly, writes to display EEPROM  
''sets power-up brightness, spalsh characters, decimal points.
''remove  
''  Sled.Powerup(40, Sled#Six)  
''  pause(1000)

''set decimal points  
  Sled.Decpoints(2)                              
  pause(10)

''count up in decimal mode
  repeat counter from 0 to 1000    
    Sled.Dmode(counter)
    pause(10)

''enter sleep mode 
  Sled.Sleep                                
  pause(500)

''wake up  
  Sled.Wake(SLEDtxpin)                      
   
''set decimal points  
  Sled.Decpoints(0)
  pause(10)

''display custom characters using cmode 
  Sled.Cmode(Sled#One, Sled#Two, Sled#Three, Sled#Four)
  pause(1000)

''clear display 
  Sled.Clear                  
  pause(1000)

''display decimal value with blanked leading digit
  repeat counter from 0 to 9999
    Sled.Dmodeblank(counter)
    pause(10)
  pause(1000)

''display custom characters using cmode 
  Sled.Cmode(Sled#Eight, Sled#Eight, Sled#Eight, Sled#Eight)
  pause(1000)
 
''set decimal points  
  Sled.Decpoints(15)
  pause(1000)
  
PUB Pause(DelayMS)
'' Pause execution in milliseconds.
'' Duration = number of milliseconds to delay
  waitcnt(clkfreq / 1000 * DelayMS + cnt)  '  Wait for DelayMS cycles

DAT

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
       