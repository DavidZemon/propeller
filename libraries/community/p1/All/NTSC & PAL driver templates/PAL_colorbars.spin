{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   PAL Colorbar Generator (C) 2009 Eric Ball                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                    TERMS OF USE: Parallax Object Exchange License                                            │                                                            
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

'' Automatic hardware detection for Hydra, Demoboard and Hybrid by Graham Coley

CON

  _CLKMODE = RCSlow     ' Start prop in RCSlow mode internal crystal


PUB main

  HWDetect
  
  COGINIT( COGID, @cogstart, @cogstart )

Pub  HWDetect | HWPins

  clkset(%01101000,  12_000_000)                        ' Set internal oscillator to RCFast and set PLL to start
  waitcnt(cnt+120_000)                                  ' wait approx 10ms at 12mhz for PLL to 'warm up'

' Automatic hardware detection based on the use of pins 12 & 13 which results
' in different input states 
' Demoboard = Video Out
' Hydra = Keyboard Data In & Data Out
' Hybrid = Keyboard Data I/O & Clock I/O  
  
  HWPins := INA[12..13]                                 ' Check state of Pins 12-13

  CASE HWPins
    %00 : clkset( %01101111, 80_000_000 )                          ' Demo Board   80MHz (5MHz PLLx16)  
          ivcfg := %0_11_1_0_1_000_00000000000_001_0_01110000      ' demoboard  
          ifrqa := $0E30_053E                                      ' (4,433,618.75Hz/80MHz)<<32 PAL demoboard & Hydra    
          idira := $0000_7000                                      ' demoboard      
               
    %01 : clkset( %01110110, 80_000_000 )                          ' Hydra        80MHz (10MHz PLLx8)
          ivcfg := %0_10_1_0_1_000_00000000000_011_0_00000111      ' Hydra & Hybrid      
          ifrqa := $0E30_053E                                      ' (4,433,618.75Hz/80MHz)<<32 PAL demoboard & Hydra    
          idira := $0700_0000                                      ' Hydra & Hybrid
          
    %11 : clkset( %01101111, 96_000_000 )                          ' Hybrid       96MHz (6MHz PLLx16)
          ivcfg := %0_10_1_0_1_000_00000000000_011_0_00000111      ' Hydra & Hybrid    
          ifrqa := $0BD2_AF09                                      ' (4,433,618.75Hz/96MHz)<<32 PAL Hybrid   
          idira := $0700_0000                                      ' Hydra & Hybrid      

' PAL (much more than NTSC) seems to be very sensitive slight to changes in the
' color frequency which occur when PLLA drifts due to FRQA not being a power of
' 2 and thus a perfect square wave.  This causes diagonal bands of color shift
' artifacts in the display.  Reducing the number of 1 LSBs in FRQA seems to
' help this problem.

  ifrqa &= $FFFF_FF00    


DAT
{{
The purpose of this code is twofold.  First, it shows the PAL color gamut for
Propeller baseband video.  Second, this code is intended to be a relatively
simple template which may be used by others to develop Propeller video drivers.
Note: this code creates an 25Hz 625 line interlaced display.

Rules for developing video drivers:
1. Start simple.  Hardcode values and static display.
2. Add complexity and changes incrementally.  Verify at each step.
3. If something doesn't work it's either because you have made an incorrect
   assumption or made a coding error.

Video drivers are constrained by WAITVID to WAITVID timing.  In the inner
active display loop, this determines the maximum resolution at a given clock
frequency.  Other WAITVID to WAITVID intervals (e.g. front porch) determine
the minimum clock frequency.
}}
                        ORG     0
cogstart                MOV     VCFG, ivcfg             ' baseband composite mode w/ 2bpp color on appropriate pins 
                        MOV     CTRA, ictra             ' internal PLL mode, PLLA = 16*colorburst frequency
                        MOV     FRQA, ifrqa             ' colorburst frequency   
                        MOV     DIRA, idira             ' enable output on appropriate pins

' Notes:
' - MOVI VCFG, #0 will stop the VSCL counters
' - Since VSCL is initialized to 0, it will take 4096 PLLA before it reloads
'   (This is also enough time for PLLA to stabilize.)

' The big difference between PAL and NTSC is the phase of the color frequency
' is inverted every line. An NTSC TV is happy as long as the colorburst signal
' doesn't change line to line & frame to frame. (Which is easy on the Propeller
' because colorburst is PLLA/16.) But a PAL TV expects the colorburst Phase to
' Alternate every Line or the picture will be black & white or shades of blue
' & gold.

' In this code the phase is based on the LSB of the frame and numline counters.
' If they are the same, then the phase is normal and the color is not changed.
' If they are different, then the phase is inverted and the color is XOR'd with
' $F0. This does mean the value of numline is important - be aware of this if
' you change the number of active lines.

' The frame counter is required because there are an odd number of lines per
' frame.  An even number of lines per frame is possible, but tricky to do with
' an interlaced display.

mainloop                ADD     frame, #1
                        CALL    #serration
                        CALL    #equalizing

                        MOV     numline, #23-5          ' 18 blank lines
blank0                  MOV     VSCL, vsclsync
                        WAITVID sync, #0                ' -40 IRE
                        MOV     VSCL, vsclserr          ' this is longer than 4096 PLLA
                        WAITVID sync, blank             ' 0 IRE
                        MOV     VSCL, vsclhalf          ' so split it into two parts
                        WAITVID sync, blank             ' 0 IRE
                        DJNZ    numline, #blank0

' Officially there are 574 active lines (287 per field), but on a normal TV
' number of these lines are lost to overscan.  240 per field is a more
' realistic amount padded to 287 at the top and bottom.  Remember that numlines
' is used to determine phase.

' The spec says horizontal blanking is only 12us (of 64us) leaving 81% of the
' line for active video, but on a normal TV some of this time is lost to
' overscan. 70% of the line (or 3178 PLLA) is more realistic.

' This demo uses 31 PLLA per pixel (vsclactv).  Decreasing the number of PLLA
' per pixel increases the horizontal resolution.  The maximum horizontal
' resolution is limitted by two factors - CLKFREQ and the number of instruction
' cycles per WAITVID loop, and the composite color demodulator.  Since color
' in NTSC is modulated at 4,433,618.75Hz, pixel frequencies at or near twice
' this frequency (i.e. 8 PLLA) will cause color artifacting.

' Changes to the number of PLLA per pixel and the number of pixels per line
' will also require changes to vsclbp and vsclfp.  

' For an interlaced picture, this is the second, fourth, sixth ... lines.

' I appologise for this not starting with the first line.  But if I did then
' I'd need to start with a halfline, which isn't correct for non-interlaced
' and the the phase calculations for the two fields would not be identical.
                         
                        MOV     numline, #310-23        ' 287 lines of active video
active0                 MOV     VSCL, vsclsync          ' horizontal sync (0H)
                        WAITVID sync, #0                ' -40 IRE
                        MOVS    :loop, #incolors        ' initialize pointer
                        TEST    numline, #1     WC
                        TEST    frame, #1       WZ
        IF_C_EQ_Z       MOV     phase, #0               ' normal V phase
        IF_C_NE_Z       MOV     phase, phaseflip        ' inverted V phase
                        MOV     VSCL, vscls2cb          ' 5.6us 0H to burst
                        WAITVID sync, blank
                        MOV     VSCL, vsclbrst          ' 10 cycles of colorburst
        IF_C_EQ_Z       WAITVID sync, burst0
        IF_C_NE_Z       WAITVID sync, burst1
                        MOV     VSCL, vsclbp            ' backporch 10.5us OH to active video
                        WAITVID sync, blank
                        MOV     count, #(17*6+2)/4      ' number of WAITVIDs
                        MOV     VSCL, vsclactv          ' PLLA per pixel, 4 pixels per frame
:loop                   MOV     outcolor, incolors      ' load colors
                        XOR     outcolor, phase         ' phase change
                        WAITVID outcolor, #%%3210       ' output colors
                        ADD     :loop, #1               ' increment pointer
                        DJNZ    count, #:loop
                        MOV     VSCL, vsclfp            ' front porch 1.5us
                        WAITVID sync, blank
                        DJNZ    numline, #active0

' If you only need 287 lines of resolution, then you can create a
' non-interlaced picture by generating equalizing pulses here then
' JMP #mainloop. However, you have a couple of options:
' 1. Do 4 equalizing pulses (2 lines instead of 5 pulses=2.5 lines) which gives
'    you an even number of lines (312) per frame.  Therefore, you need to
'    remove the frame portion of the phase logic.
' 2. Add an extra halfline and do 5 equalizing pulses for an odd number of
'    lines (313) per frame.
' You also may wish to try removing the "extra PLL" logic from equalizing and
' serration subroutines to see which looks better.

                        CALL    #equalizing
                        CALL    #serration
                        CALL    #equalizing

                        MOV     VSCL, vsclhalf          ' half line
                        WAITVID sync, blank             ' 0 IRE
                        
                        MOV     numline, #335-318       ' 17 blank lines
blank1                  MOV     VSCL, vsclsync
                        WAITVID sync, #0                ' -40 IRE
                        MOV     VSCL, vsclserr          ' this is longer than 4096 PLLA
                        WAITVID sync, blank             ' 0 IRE
                        MOV     VSCL, vsclhalf          ' so split it into two parts
                        WAITVID sync, blank             ' 0 IRE
                        DJNZ    numline, #blank1

' For an interlaced picture, this is the first, third, fifth ... lines.
                         
                        MOV     numline, #622-335       ' 287 lines of active video
active1                 MOV     VSCL, vsclsync          ' horizontal sync (0H)
                        WAITVID sync, #0                ' -40 IRE
                        MOVS    :loop, #incolors
                        TEST    numline, #1     WC      
                        TEST    frame, #1       WZ      
        IF_C_EQ_Z       MOV     phase, #0               ' normal V phase
        IF_C_NE_Z       MOV     phase, phaseflip        ' inverted V phase
                        MOV     VSCL, vscls2cb          ' 5.6us 0H to burst
                        WAITVID sync, blank
                        MOV     VSCL, vsclbrst          ' 10 cycles of colorburst
        IF_C_EQ_Z       WAITVID sync, burst0
        IF_C_NE_Z       WAITVID sync, burst1
                        MOV     VSCL, vsclbp            ' backporch 10.5us OH to active video
                        WAITVID sync, blank
                        MOV     count, #(17*6+2)/4      ' number of WAITVIDs
                        MOV     VSCL, vsclactv          ' PLLA per pixel, 4 pixels per frame
:loop                   MOV     outcolor, incolors      ' load colors
                        XOR     outcolor, phase         ' phase change
                        WAITVID outcolor, #%%3210       ' output colors
                        ADD     :loop, #1               ' increment pointer
                        DJNZ    count, #:loop
                        MOV     VSCL, vsclfp            ' front porch 1.5us
                        WAITVID sync, blank
                        DJNZ    numline, #active1
                         
                        MOV     VSCL, vsclsync          ' half line
                        WAITVID sync, #0                ' -40 IRE
                        MOV     VSCL, vsclserr
                        WAITVID sync, blank

                        CALL    #equalizing
                        JMP     #mainloop

' The PAL colorburst is 283.75 cycles per line + 1 cycle per frame
' This extra cycle per frame is added in here during vsync as 1 extra PLLA
' every other pulse (15 pulses per field = 8 PLLA per field).  This is
' probably not 100% necessary, but looks better on my capture card.

serration               MOV     count, #5               ' 5 serration pulses
:loop                   MOV     VSCL, vsclserr          ' serration pulse (long)
                        TEST    count, #1       WC
               IF_C     ADD     VSCL, #1                ' extra PLLA
                        WAITVID sync, #0                ' -40 IRE
                        MOV     VSCL, vsclsync          ' serration pulse (short)
                        WAITVID sync, blank             ' 0 IRE
                        DJNZ    count, #:loop
serration_ret           RET

equalizing              MOV     count, #5               ' 5 equalizing pulses
:loop                   MOV     VSCL, vscleqlo          ' equalizing pulse (short)
                        WAITVID sync, #0                ' -40 IRE
                        MOV     VSCL, vscleqhi          ' equalizing pulse (long)
                        TEST    count, #1       WC
               IF_NC    ADD     VSCL, #1                ' extra PLLA
                        WAITVID sync, blank             ' 0 IRE
                        DJNZ    count, #:loop
equalizing_ret          RET

' PAL colors are similar to, but not exactly the same as, NTSC due to using
' XOR to invert the colors (e.g. 1 inverts to E instead of F).

incolors                BYTE    $02                                             ' LONG padding
                        BYTE    $07, $06, $05, $04, $03, $02                    ' white to black (6 levels)
                        BYTE    $0B, $0C, $0D, $0E, $8F, $88                    ' 11.25 16 hues, 6 shades/hue
                        BYTE    $1B, $1C, $1D, $1E, $9F, $98                    ' 33.75
                        BYTE    $2B, $2C, $2D, $2E, $AF, $A8                    ' 56.25
                        BYTE    $3B, $3C, $3D, $3E, $BF, $B8                    ' 78.75
                        BYTE    $4B, $4C, $4D, $4E, $CF, $C8                    ' 101.25
                        BYTE    $5B, $5C, $5D, $5E, $DF, $D8                    ' 123.75
                        BYTE    $6B, $6C, $6D, $6E, $EF, $E8                    ' 146.25
                        BYTE    $7B, $7C, $7D, $7E, $FF, $F8                    ' 168.75
                        BYTE    $8B, $8C, $8D, $8E, $0F, $08                    ' 191.25
                        BYTE    $9B, $9C, $9D, $9E, $1F, $18                    ' 213.75
                        BYTE    $AB, $AC, $AD, $AE, $2F, $28                    ' 236.25
                        BYTE    $BB, $BC, $BD, $BE, $3F, $38                    ' 258.75
                        BYTE    $CB, $CC, $CD, $CE, $4F, $48                    ' 281.25
                        BYTE    $DB, $DC, $DD, $DE, $5F, $58                    ' 303.75
                        BYTE    $EB, $EC, $ED, $EE, $6F, $68                    ' 326.25
                        BYTE    $FB, $FC, $FD, $FE, $7F, $78                    ' 348.75
                        BYTE    $02                                             ' LONG padding

numline                 LONG    $0
frame                   LONG    $0
count                   LONG    $0
outcolor                LONG    $0
phase                   LONG    $0

' Other options for sync include $AA5A0200, $AA6A0200, and $9A5A0200.  The
' different values didn't seem to make any difference in my capture card tests.

sync                    LONG    $9A6A0200                                       ' %%0 = -40 IRE, %%1 = 0 IRE, %%2 = even burst, %%3 = odd burst
blank                   LONG    %%1111_1111_1111_1111                           ' 16 pixels color 1
burst0                  LONG    %%2222_2222_2222_2222                           ' 16 pixels color 2
burst1                  LONG    %%3333_3333_3333_3333                           ' 16 pixels color 3
phaseflip               LONG    $F0F0F0F0                                       ' invert hue portion of color

' Note: these values are for European PAL (PAL B/D/G/H/I)
' South American PAL (PAL M/N/Nc) variations have different colorburst frequencies
                         
vsclhalf                LONG    1<<12+2270                                      ' PAL H/2
vsclsync                LONG    1<<12+333                                       ' PAL sync = 4.7us
vsclserr                LONG    1<<12+2270-333                                  ' PAL H/2-sync
vscleqlo                LONG    1<<12+167                                       ' PAL sync/2
vscleqhi                LONG    1<<12+2270-167                                  ' PAL H/2-sync/2
vscls2cb                LONG    1<<12+397-333                                   ' PAL sync to colorburst
vsclbrst                LONG    16<<12+16*10                                    ' PAL 16 PLLA per cycle, 10 cycles of colorburst
vsclbp                  LONG    1<<12+(745-397-16*10)+232                       ' PAL back porch+overscan
vsclactv                LONG    31<<12+31*4                                     ' PAL 31 PLLA per pixel, 4 pixels per frame
vsclfp                  LONG    1<<12+233+106                                   ' PAL overscan+front porch

ivcfg                   LONG    %0_11_1_0_1_000_00000000000_001_0_01110000      ' demoboard
ictra                   LONG    %0_00001_111_00000000_000000_000_000000         ' PAL
idira                   LONG    $0000_7000                                      ' demoboard
ifrqa                   LONG    $0E30_0500                                      ' (4,433,618.75Hz/80MHz)<<32 PAL demoboard & Hydra

{ Change log
2009-06-21    first release to forums.parallax.com
2009-07-16    added WAITVID note, upload to Object Exchange
}    