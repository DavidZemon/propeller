{{┌────────────────────────────────────--------------┐
  │ "CANbus Loopback demo JT2.spin"                  │
  │ Derivative work from original demo by Chris Gadd | 
  │ Original demo copyright (c) 2015 Chris Gadd      │
  │ See end of file for terms of use.                |
  │ Demo simplified and comments added by            |
  | Jon Titus, 06-03-2016                            |
  └────────────────────────────────────--------------┘
  For this demo, place a pull-up resistor on the Tx_pin, and connect the Tx_pin to the Rx_pin.
  The writer object transmits a bitstream containing ID, data length, and data to the reader.
  The reader object receives and decodes the bitstream, and displays it on a serial terminal at 115_200bps
}}
CON
  _clkmode = xtal1 + pll16x                             ' Standard 16x clock freq: 80 MHz
  _xinfreq = 5_000_000                                  ' 5 MHz crystal frequency

  Rx_pin  = 25                                          ' CAN-controller transmitter-output pin
  Tx_pin  = 24                                          ' CAN-controller receiver-input pin
  bitrate = 1_000_000                                   ' CAN data rate, 1M bits/sec.
  Sync_pin = 7                                          ' An I/O pin used for multicore communication
                                                        ' Make no connection to this pin!
                                                        
VAR
  long  ident                                           ' Declare ident as a "long"
  byte  Numb_Bytes_to_Send, tx_data[8]                  ' Declare data-length as a byte and an array of
                                                        ' eight bytes maximum to send
OBJ
  writer   : "CANbus writer 1Mbps"                      ' Standalone writer, good up to 1Mbps
  reader   : "CANbus reader 1Mbps"                      ' Standalone reader, good up to 1Mpbs, requires 2 cogs and
                                                        ' an I/O pin for synchronizing cogs
  fds      : "FullDuplexSerial"                         ' Define FDS as full-duplex serial connection with
                                                        ' Parallax serial terminal window (press F12 to start)
                                                      
PUB Main                                                ' This is the main program. It uses private methods
  tx_data[0] := $55                                     ' Five bytes of sample data to transmit.
  tx_data[1] := $AA
  tx_data[2] := $FF
  tx_data[3] := $12
  tx_data[4] := $34
  tx_data[5] := $00
  tx_data[6] := $00
  tx_data[7] := $00

  CANbus_RW                                             ' Call this method (below) to demonstrate use of the 
                                                        ' separate CAN reader and writer objects

PRI CANbus_RW                                           ' "Private" methods start here
                                                        '
  reader.loopback(true)                                 ' Set Loopback to true for this demo. Otherwise, set
                                                        ' loopback to false for normal operation. 
  reader.start(rx_pin, tx_pin, Sync_pin, bitrate)       ' Use I/O pin P7 for sync between XMTR and RCVR
                                                        ' leave this pin unconnected.
  writer.Start(rx_pin, tx_pin, bitrate)                 ' Set up writer with preset CAN-controller pins and
                                                        ' bit rate
  fds.Start(31, 30, 0, 115200)                          ' Start serial I/O from Propeller to PC via USB port 
  waitcnt(cnt + clkfreq)                                ' Short delay here
  fds.Tx(16)                                            ' Clear PST display, ASCII 16

  ident := $001                                         ' Start with ID = $001 (Do not use ID $000!)
  Numb_Bytes_to_Send := 5                               ' This example sends five bytes                                               

  repeat                                                ' Repeat this loop "forever"                                                
      waitcnt(cnt + clkfreq / 20)                       ' Short delay
      writer.SendStr(ident, @Numb_Bytes_to_Send)        ' Send a normal message with 11 ID bits
                                                        ' Include pointer to number of bytes to send.                                                    
      CheckReader                                       ' Check the reader for new data in CheckReader method.
    
PRI CheckReader | a                                     ' Define "a" as a local variavle
  if reader.ID                                          ' If ID was received (true), proceed
    fds.Hex(reader.ID, 3)                               ' Display ID value as 3 hex characters
    fds.Str(string("  "))                               ' Include 2 spaces 
    a := reader.DataAddress                             ' Get the address for the start of data-byte array
      repeat byte[a++]                                  ' The first byte contains the string length,
                                                        ' then increment value in "a," the index into the array 
        fds.Hex(byte[a++], 2)                           ' Display bytes as 2 hex values and increment address
        fds.Tx(" ")                                     ' Include a space
    fds.Tx($0D)                                         ' "Carriage return" for a new line                                                                                                            
    reader.NextID                                       ' Clear current ID buffer and advance to next
    return true                                         ' Return true (non zero) to indicate success
   
{{ ----------end of program: CANbus Loopback demo JT.spin----------}}
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