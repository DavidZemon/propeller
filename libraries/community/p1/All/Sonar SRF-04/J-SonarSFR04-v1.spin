{{
***************************************
*    SRF04 Sonar Object V1.0          *
* Author:  Jan Balewski               *
* See end of file for terms of use.   *    
* Started: 05-0-2008                  *
***************************************

Interface to SRF-04 sensor and measure its ultrasonic travel time.  Measurements is in cm units.
Method requires 2 parameters, PinInp to trigger sonar and , PinOut  connected to the SRF04 signal line.

  ┌───────────────────┐
  │┌───┐         ┌───┐│    Connection To Propeller
  ││ ‣ │  SRF-04 │ ‣ ││    Remember SRF-04 Requires
  │└───┘         └───┘│    +5V Power Supply
  │ GND  out   inp +5V│
  └───┬───┬─────┬───┬─┘    
          1K    │      
          ┴     ┴  └┘      
   PINS:echo  burst
    
}}

CON
  TO_CM = 4900  ' Centimeters @ 80 MHz
   state = 1                                                                                 
                                                                                 
PUB distance(pin1, pin2) | Duration 
{{
  Reads duration of Pulse on pin2 defined for state, returns duration in 1/clkFreq increments - 12.5nS at 80MHz
  Note: Absence of pulse can cause cog lockup if watchdog is not used 
}}

{ it was so simple in basic-stamp :)
  PULSOUT pin1, 5 ' 10us init pulse
  OUTPUT 1 ' dummy delay
  PULSIN pin2,1,xRaw
  xWord=xRaw/80 ' now in cm
}
  dira[pin1]~~   ' Set to output
  DIRA[pin2]~    ' Set as input

  outa[pin1]:=0
  waitcnt(500 + cnt) 
  !outa[pin1]
  waitcnt(500 + cnt) 
  !outa[pin1]
  waitcnt(500 + cnt) 

  ctra := 0
  if state == 1
    ctra := (%11010 << 26 ) | (%001 << 23) | (0 << 9) | (PIN2) ' set up counter, A level count
  else
    ctra := (%10101 << 26 ) | (%001 << 23) | (0 << 9) | (PIN2) ' set up counter, !A level count
  frqa := 1
  waitpne(State << pin2, |< Pin2, 0)                       ' Wait for opposite state ready
  phsa:=0                                                  ' Clear count
  waitpeq(State << pin2, |< Pin2, 0)                       ' wait for pulse
  waitpne(State << pin2, |< Pin2, 0)                       ' Wait for pulse to end
  Duration := phsa                                         ' Return duration as counts
  ctra :=0                                                 ' stop counter
  return Duration/4900
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