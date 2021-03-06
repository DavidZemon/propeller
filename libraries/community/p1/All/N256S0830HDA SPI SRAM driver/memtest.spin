{{ MemTest
        Tim Moore 2008
}}
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

OBJ 
                                                        '1 Cog here 
  sram1         : "spisram1"                            '1 COG
  sram2         : "spisram2"                            '1 COG
  sram4         : "spisram4"                            '1 COG
  sram8         : "spisram8"                            '1 COG                  - NOT YET WORKING
  
  uarts         : "pcFullDuplexSerial4FC"               '1 COG for 4 serial ports

  config        : "config"                              'no COG required

VAR
  long  buffer[64]
  long  obuffer[64]
        
Pub Start | i,count,same,starttime,wtotal,rtotal,size
  config.Init(@pininfo,0)                               'initialize config setup

  longfill(@buffer,$AAAAAAAA,32)
  waitcnt(clkfreq*3 + cnt)                              'delay for debugging
  
  uarts.Init
  uarts.AddPort(0,config.GetPin(CONFIG#DEBUG_RX),config.GetPin(CONFIG#DEBUG_TX),{
}   UARTS#PINNOTUSED,UARTS#PINNOTUSED,UARTS#DEFAULTTHRESHOLD, {
}   UARTS#NOMODE,UARTS#BAUD115200)                      'Add debug port
  uarts.Start                                           'Start the ports
  
  uarts.str(0,string("Memtest V1.0",13))

  if config.GetPin(CONFIG#SPISRAM_D7) <> -1             'SPI-SRAM x8  
    sram8.Start(config.GetPin(CONFIG#SPISRAM_D0),config.GetPin(CONFIG#SPISRAM_SCK))
    size := 8
  elseif config.GetPin(CONFIG#SPISRAM_D3) <> -1         'SPI-SRAM x4
    sram4.Start(config.GetPin(CONFIG#SPISRAM_D0),config.GetPin(CONFIG#SPISRAM_SCK))
    size := 4
  elseif config.GetPin(CONFIG#SPISRAM_D1) <> -1         'SPI-SRAM x2
    sram2.Start(config.GetPin(CONFIG#SPISRAM_D0),config.GetPin(CONFIG#SPISRAM_SCK))
    size := 2
  elseif config.GetPin(CONFIG#SPISRAM_D0) <> -1         'SPI-SRAM x1
    sram1.Start(config.GetPin(CONFIG#SPISRAM_D0),config.GetPin(CONFIG#SPISRAM_SCK))
    size := 1

  uarts.str(0,string("SRAM started, size:"))
  uarts.dec(0,size)
  uarts.tx(0,13)
  
  waitcnt(clkfreq/2 + cnt)                              'delay for debugging

  repeat i from 0 to 63
    obuffer[i] := i

  wtotal := 0
  rtotal := 0
  repeat
    if (count & $ff) == 0
      uarts.str(0,string("test "))
      uarts.dec(0,count)
      uarts.tx(0," ")
      uarts.dec(0,rtotal)
      uarts.tx(0," ")
      uarts.dec(0,wtotal)
      uarts.tx(0,13)

    starttime := cnt
    case size
      1:    
        sram1.Write(0,@obuffer,64)
      2:    
        sram2.Write(0,@obuffer,64)
      4:    
        sram4.Write(0,@obuffer,64)
      8:    
        sram8.Write(0,@obuffer,64)
    wtotal += cnt - starttime     
    starttime := cnt    
    case size
      1:    
        sram1.Read(8,@buffer+8,62)                      'read offset by 8 to check addressing is working
      2:    
        sram2.Read(4,@buffer+8,62)                      'read offset by 4 to check addressing is working
      4:    
        sram4.Read(2,@buffer+8,62)                      'read offset by 2 to check addressing is working
      8:    
        sram8.Read(1,@buffer+8,62)                      'read offset by 1 to check addressing is working
    rtotal += cnt - starttime     

    same := 1
    repeat i from 2 to 63
      if obuffer[i] <> buffer[i]
        same := 0
        quit
    if same == 0             
      repeat i from 0 to 63
        uarts.hex(0, obuffer[i],8)
        uarts.tx(0," ")
      uarts.tx(0,":")
      repeat i from 0 to 63
        uarts.hex(0, buffer[i],8)
        uarts.tx(0," ")
      uarts.tx(0,13)
    repeat i from 0 to 63
      obuffer[i] += 64
    count++

DAT
'pin configuration table for this project
pininfo
'              word CONFIG#NOT_USED              'pin 0
              word CONFIG#SPISRAM_D0            'pin 0
'              word CONFIG#NOT_USED              'pin 1
'              word CONFIG#SPISRAM_D0            'pin 1
              word CONFIG#SPISRAM_D1            'pin 1
'              word CONFIG#NOT_USED              'pin 2
'              word CONFIG#SPISRAM_D0            'pin 2
              word CONFIG#SPISRAM_D2            'pin 2
'              word CONFIG#NOT_USED              'pin 3
'              word CONFIG#SPISRAM_D0            'pin 3
'              word CONFIG#SPISRAM_D1            'pin 3
              word CONFIG#SPISRAM_D3            'pin 3
              word CONFIG#NOT_USED              'pin 4
              word CONFIG#NOT_USED              'pin 5
              word CONFIG#NOT_USED              'pin 6
              word CONFIG#NOT_USED              'pin 7
              word CONFIG#SPISRAM_SCK           'pin 8
              word CONFIG#SPISRAM_CS            'pin 9
              word CONFIG#NOT_USED              'pin 10
              word CONFIG#NOT_USED              'pin 11
              word CONFIG#NOT_USED              'pin 12
              word CONFIG#NOT_USED              'pin 13
              word CONFIG#NOT_USED              'pin 14
              word CONFIG#NOT_USED              'pin 15
              word CONFIG#VGA1                  'pin 16
              word CONFIG#VGA1                  'pin 17
              word CONFIG#VGA1                  'pin 18
              word CONFIG#VGA1                  'pin 19
              word CONFIG#VGA1                  'pin 20
              word CONFIG#VGA1                  'pin 21
              word CONFIG#VGA1                  'pin 22
              word CONFIG#VGA1                  'pin 23
              word CONFIG#MOUSE1_DATA           'pin 24
              word CONFIG#MOUSE1_CLK            'pin 25
              word CONFIG#KEYBOARD1_DATA        'pin 26
              word CONFIG#KEYBOARD1_CLK         'pin 27
              word CONFIG#I2C_SCL1              'pin 28
              word CONFIG#I2C_SDA1              'pin 29
              word CONFIG#DEBUG_TX              'pin 30
              word CONFIG#DEBUG_RX              'pin 31
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