{{
WWVB Time Data Decoder

V.1.0
Copyright(C)2015, Steven R. Stuart, W8AN, Feb 2015
Terms of use are stated at the end of this file.

This software requires a WWVB 60kHz time receiver module.

The speed of the transmission is 1 baud (1 bit per second) encoded in an RF signal at 60kHz. 
A logic 0 is indicated by the signal going low for 0.2 seconds and high for 0.8 seconds.
A logic 1 goes low for 0.5 seconds and high for 0.5 seconds.
The Sync bit goes low for 0.8 seconds and then high for 0.2 seconds
                                                                             
                ┌── 1 sec ──┐                                                
                                                                           
 Logic 0 bit     200ms pulse      
                                                                           
 Logic 1 bit     500ms pulse      
                                                                           
 Sync bit        800ms pulse

The FRAME BUFFER contains 60 "bits", 1 bit is collected each second.
Bit positions are marked with the data type using the following legend:
   
 P  = Sync pulse
 Mm = Minute 
 Hh = Hour
 Dd = Day of year
 Yy = Year 
 U  = UTI signs
 u  = UT1 corrections
 l  = Leap year/second indicators
 t  = Standard time/Daylight savings time indicators
 r  = Reserved bit
 X  = Buffer overflow position

 Received data is decoded as follows:
 0  = logic low
 1  = logic high
 S  = Sync pulse
 _  = Indeterminate data

 bit positions: 0         1         2         3         4         5         6
                0----+----0----+----0----+----0----+----0----+----0----+----0
 data types:    PMMMrmmmmPrrHHrhhhhPrrDDrDDDDPddddrrUUUPuuuurYYYYPyyyyrllttPX

                                                                                   
}}

OBJ
     rx : "WWVB Receiver"

CON
    _xinfreq    = 5_000_000              '80MHz clkfreq
    _clkmode    = xtal1 + pll16x         'Clock multiplier
     
VAR
    long stack[32] 
    long decoder_cog_id
    byte rx_data_pin

    byte buffer_pointer          'pointer within PULSE_BUFFER                                            
    long pulse_buffer[64]        'circular array of pulse times collected by rx                     
    byte pulse_frame[60]         'the past 60 decoded pulse bits in byte format. 0,1=logic level. 2=sync, 3=indeterminate

PUB Start(data_pin)
''Start the decoder
    rx_data_pin := data_pin
    Stop
    decoder_cog_id := cognew(Decode, @stack[0])                          

PUB Stop
''Shutdown the decoder  
    rx.Stop                 'shutdown the receiver first      
    if decoder_cog_id                                               
        cogstop(cogid)       

CON
    HISTORY_SIZE = 10      'number of historical records    
    INDEX_MINUTE = 0       'array reference
    INDEX_HOUR   = 1       '  "      "                   
    INDEX_DOY    = 2       '  "      " 
    INDEX_YEAR   = 3       '  "      "
    INDEX_ITEMS  = 4       'number of items in array. min,hour,doy,year 
     
VAR
    word history_data[INDEX_ITEMS*HISTORY_SIZE]      'historical list, min,hour,doy,year
    byte frame_ref_bit                               'position of the 2nd of two consecutive sync bits,
                                                     'it marks the first second of each minute
    byte rx_running                                  'receiver cog state
                                                                                                                                                                                                            
PUB Decode | root_time, tsec

  root_time := cnt
  repeat
    waitcnt(root_time += clkfreq/10)     'loop every tenth second
    tsec++                               'tenth_second counter
    if tsec => 10                        'do every second
        tsec := 0
        UpdateClock                      'internal decoder clock
        if rx_running                    'receiver cog running?
            byte[@SECOND]++                         
            if byte[@SECOND] == 60                  
                byte[@SECOND] := 0                  
            ProcessRxData                'update the frame buffer

DAT
    '' The GetClock methods return information from the decoder's running clock.
    '' The time is reliable but not guaranteed.    
    
PUB GetClockHour                ''Hour from the decoder internal clock. 
    return word[@CLOCK_HOUR]
    
PUB GetClockMinute              ''Minute from the decoder internal clock.
    return word[@CLOCK_MIN]
    
PUB GetClockSecond              ''Second from the decoder internal clock.
    return byte[@CLOCK_SEC]
       
PUB GetClockDoY                 ''Day of year from the decoder internal clock.
    return word[@CLOCK_DOY]
    
PUB GetClockMonth               ''Month calculated from decoder internal clock    
    return byte[@CLOCK_MONTH]         
    
PUB GetClockDay                 ''Day of month calculated from decoder internal clock
    return byte[@CLOCK_DAY]

PUB GetClockYear                ''Persistent copy of the last valid year reading.
    return word[@CLOCK_YEAR]
    
DAT
    '' WWVB receiver cog control 
    
PUB IsRcvrRunning               ''Tests if receiver cog is up
    return rx_running
                      
PUB StartRcvr                   ''Launch the pulse timing receiver in a cog
    rx_running := rx.Start(rx_data_pin, @pulse_buffer, @buffer_pointer) 

PUB StopRcvr                    ''Shut down the receiver cog
    rx_running := rx.Stop 

DAT
    '' Get methods provide direct access to the latest valid FRAME_BUFFER data
   
PUB GetHour                     ''Last valid hour data received from wwvb 
    return word[@HOUR]
    
PUB GetMinute                   ''Last valid minute data received from wwvb  
    return word[@MINUTE]
    
PUB GetSecond                   ''The expected second. Based on the frame reference bit
    return byte[@SECOND]
    
PUB GetYear                     ''Last valid year data received from wwvb  
    return word[@YEAR]

PUB GetDoY                      ''Last valid day of year data received from wwvb  
    return word[@DOY]
    
PUB GetDstBit                   ''Daylight savings time bit  ''( Description of DST / ST bit usage ) 
    return byte[@DST_V]                                      ''( is at bottom of this file         )

PUB GetStBit                    ''Standard time bit
    return byte[@ST_V]
    
DAT
    '' These methods only return useful data if the wwvb receiver cog is running
      
PUB IsTopOfMinute               ''Boolean indication that the current time is at start of minute.
    return frame_ref_bit == 0   ''Reliability is dependent on valid framing from a good wwvb signal       
                                
PUB GetSync                     ''True if the all the framing sync pulses are in the right places
    return IsSyncValid
    
PUB Quality:level|i
{{
  Returns a value (0-100) based on a calculation of the most recent data receive history.
  0 = no good data received in a long time, 100 = perfect reception for the past 10 minutes.
  Valid data received later in the wwvb frame carries a higher weight because it indicates 
  that the integrity of the frame is intact and not damaged by poor reception and noise.    
}}
    repeat i from 0 to INDEX_ITEMS*HISTORY_SIZE-1 step INDEX_ITEMS
        if history_data[i+INDEX_MINUTE] > 0
            level++
        if history_data[i+INDEX_HOUR] > 0
            level += 2         
        if history_data[i+INDEX_DOY] > 0
            level += 3                 
        if history_data[i+INDEX_YEAR] > 3
            level += 4

DAT
    '' The following public methods are not expected to be used in a time keeping 
    '' application but are provided for testing and demonstration purposes.
    
PUB FrameBufferAddr             ''address of the frame buffer structure
    return @FRAME_BUFFER

PUB GetFramePtr                 ''current bit of the frame that is being received 
    return (60-frame_ref_bit)
    
PUB PulseBufferAddr             ''address of the pulse buffer structure
    return @pulse_buffer

PUB PulseBufferPtrAddr          ''current position of the pointer into the pulse buffer which
    return @buffer_pointer      ''points to the received pulse time one minute ago
  
PUB PulseFrameAddr              ''address of the pulse frame structure
    return @pulse_frame

PUB GetFrameRefBit              ''the position within the pulse frame where the frame begins,
    return frame_ref_bit        ''the "zero" second

PUB HistoryDataAddr             ''address of the history stack array structure
    return @history_data

DAT
    '' END OF PUBLIC METHODS

PRI UpdateClock
{{ 
   This is the decoder internal time clock that is accessible via the GetClock 
   public methods. These clock registers get updated whenever valid wwvb 
   data is received, but provides time information when reception is poor.
   Accuracy is only a second or so
}}
    byte[@CLOCK_SEC]++
    if byte[@CLOCK_SEC] > 59
        byte[@CLOCK_SEC] := 0
        word[@CLOCK_MIN]++
        
    if word[@CLOCK_MIN] > 59
        word[@CLOCK_MIN] := 0
        word[@CLOCK_HOUR]++
        
    if word[@CLOCK_HOUR] > 23
        word[@CLOCK_HOUR] := 0
        word[@CLOCK_DOY]++

PRI AdjustClockSecs
{{
   Sync internal clock second to wwvb when more than 1 second apart
}}
    if (byte[@SECOND] < (byte[@CLOCK_SEC]-1)) or (byte[@SECOND] > (byte[@CLOCK_SEC]+1))
        byte[@CLOCK_SEC] := byte[@SECOND] 

DAT
{{
    CLOCK_name  registers keep persistent time data when wwvb reception is poor
}}
    CLOCK_YEAR    word    0    'These time registers are updated by the data decoded from   
    CLOCK_DOY     word    0    'the receiver when that data is thought to be valid.         
    CLOCK_HOUR    word    0    'Otherwise they are incremented in a timely fashion to       
    CLOCK_MIN     word    0    'provide current time information to any calling process.    
    CLOCK_SEC     byte    0                                                                 

    CLOCK_MONTH   byte    0    'Date is calculated from the clock register: CLOCK_DOY
    CLOCK_DAY     byte    0

PRI GregorianDate|day_number, current_month
{{                                                        
    Converts day of year to month and day                 
}}
    current_month := 0
    day_number := word[@DOY]
    IsLeapYear       'use the side effect that sets number of Feb days in MONTHS register
        
    repeat while day_number > byte[@MONTHS][current_month-1]
        day_number -= byte[@MONTHS][current_month-1]
        current_month++

    byte[@CLOCK_MONTH] := current_month
    byte[@CLOCK_DAY] := day_number
     
PRI MakeHistory|row,col  
{{    
    Historical data contains the past several valid data reads, most current at top of stack.
    All columns of data are moved down the stack, oldest falls off, discarded.
    Then fresh data are saved to the top of stack, invalid data is zero. 
    
    Stack arrangement:      min hour doy year                
                        i  ┌──────────────────                                     
                        n 0|  0   1   2    3   ◀─ top of stack, recent data                    
                        d 1|  4   5   6    7                                       
                        e 2|  8   9  10   11   ◀─ older data                                    
                        x :|  :   :   :    :   
}}
    repeat row from HISTORY_SIZE-1 to 1     'start at bottom row, roll prev row down
        repeat col from 0 to INDEX_ITEMS-1
            history_data[row * INDEX_ITEMS + col] := history_data[(row-1) * INDEX_ITEMS + col]
              
    repeat col from INDEX_MINUTE to INDEX_YEAR      'store fresh data at top 
        if IsMinuteValid
            history_data[INDEX_MINUTE] := word[@MINUTE]
        else
            history_data[INDEX_MINUTE] := 0
        if IsHourValid
            history_data[INDEX_HOUR] := word[@HOUR]
        else
            history_data[INDEX_HOUR] := 0
        if IsDoYValid
            history_data[INDEX_DOY] := word[@DOY]
        else
            history_data[INDEX_DOY] := 0
        if IsYearValid
            history_data[INDEX_YEAR] := word[@YEAR]
        else
            history_data[INDEX_YEAR] := 0
    
PRI ProcessRxData | minute_flag, frame_ptr, upd[INDEX_ITEMS], i 
{
 Process Received Data
}        
    FillPulseFrame(buffer_pointer-1)     'fill the pulse_frame with coded pulse types from
                                         'the last 60 pulse times heard on the receiver                                
    frame_ref_bit := FindFrameRefBit     'find the frame reference bit in the pulse_frame
                                         'returns -1 when not found
    if frame_ref_bit => 0                'when the frame reference bit is found                                               
        FillFrameBuffer(frame_ref_bit)   'fill the frame buffer with char codes                                                                                                 
        frame_ptr := 60-frame_ref_bit    'set pointer to the current position in the frame                  '
    else
        frame_ptr := -1                  'prevent time data updates if frame_ref_bit isnt found                                    
                                                                                                                         
    if frame_ref_bit == 0                'Actions at the top of the minute                                        
         if minute_flag == false                                                             
              minute_flag := true        'so we only do this once per minute
             byte[@SECOND] := 1          'we have just decoded the first second so adjust
              MakeHistory                'push time readings into stack
              repeat i from INDEX_MINUTE to INDEX_YEAR
                  upd[i] := false        'reset the update flags
    else                                                                                           
        minute_flag := false             'top of minute is over                                                                                                 
                                                                                                                     
    if frame_ref_bit == 30               'Actions at the bottom of the minute                                                
                                         'adj secs here to avoid causing minute counter error
        if IsSyncValid                   'if all the frame pulses are in the right place
            AdjustClockSecs              'we are confident that the SECOND counter is correct                                                                                                                                                                               
                                         'so sync the internal clock seconds              
     '' Update the time data
                                          
    if (frame_ptr == 11) and (!upd[INDEX_MINUTE]) and IsMinuteValid                                                                                                          
        upd[INDEX_MINUTE] := true         'set a flag so we update only once per frame                                                                                     
        ReadMinute                        'sets MINUTE     
        word[@CLOCK_MIN] := word[@MINUTE] 'sync internal clock minute
                                                                                                                                                                     
    if (frame_ptr == 21) and (!upd[INDEX_HOUR]) and IsHourValid                                                                                                              
        upd[INDEX_HOUR] := true                                                                                              
        ReadHour        'sets HOUR   
        word[@CLOCK_HOUR] := word[@HOUR]

    if (frame_ptr == 35) and (!upd[INDEX_DOY]) and IsDoYValid                                                                                                             
        upd[INDEX_DOY] := true                                                                                              
        ReadDoY         'sets DOY
        word[@CLOCK_DOY] := word[@DOY]
        if IsLeapValid                                                                                                                                                        
            GregorianDate   'reads CLOCK_DOY, sets CLOCK_MONTH and CLOCK_DAY

    if (frame_ptr == 55) and (!upd[INDEX_YEAR]) and IsYearValid                                                                                                              
        upd[INDEX_YEAR] := true                                                                                              
        ReadYear        'sets YEAR
        word[@CLOCK_YEAR] := word[@YEAR]                                                                               

PRI FillFrameBuffer(pulse_frame_position)|bit
{{
  Replace all FRAME_BUFFER chars with the data from the pulse_frame
}}
  repeat bit from 0 to 59      
      byte[@FRAME_BUFFER][bit] := FrameBitType(pulse_frame[pulse_frame_position])      
      pulse_frame_position++
      if pulse_frame_position > 59
          pulse_frame_position := 0

PRI FrameBitType(type):name
{{
  Return the text representation of the bit type
}}
  case type
      0: name := "0"       'logic 0
      1: name := "1"       'logic 1
      2: name := "S"       'sync
      other: name := "_"   'unknown   

PRI FillPulseFrame(rx_bit_position)|read_position, i
{{
  Load the pulse_frame with type coded data from the past 60 received bits 
  rx_bit_position is the PulseReceiver's current buffer_pointer position
}}
  ''Go 60 bits back from the PulseReceiver position
  if rx_bit_position < 60
       read_position := rx_bit_position + 4
  else
       read_position := rx_bit_position - 60

  ''Fill the pulse_frame with the last 60 type coded bits
  repeat i from 0 to 59 
      pulse_frame[i] := GetPulseType(pulse_buffer[read_position]) 'put type 0-3 into pulse_frame
      read_position++
      if read_position > 63   'buffer wrap around        
          read_position:= 0  

PRI FindFrameRefBit:start_bit|found_flag,i,j
{{
   Return the position of the Frame Reference Bit in the pulse_frame array
   Return -1 if none or more than 1 FRB was found
   The Frame Reference Bit is the second of two consecutive sync bits  
}}
    start_bit := -1           'default to no FRB position
    found_flag := false       'until we know better
    
    repeat i from 0 to 59     'position to test 
        j := i+1              'and the position beside it  
        if j > 59             'wrap around
            j := 0                
        if (pulse_frame[i] == 2) and (pulse_frame[j] == 2) 'possible FRB found
            if found_flag               'found more than one FRB?  
                start_bit := -1         'return invalid data value
                return
            found_flag := true          'found one
            start_bit := j              'position where found 

PRI GetPulseType(pulse_width):type
{{
  Estimate the pulse type based on a range of pulse_width time values 
  logic 0 is type 0, logic 1 is type 1
  sync bit is type 2
  error is type 3
}}
    case pulse_width                                                                                                                       
       19_000_000..22_000_000:               '190ms-220ms assume it's a logic 0 - 200ms optimal                                                          
           type := 0                                                                                             
       40_000_000..60_000_000:               '400ms-600ms assume it's a logic 1 - 500ms optimal                                                                           
           type := 1                                                                                                                                                                       
       70_000_000..90_000_000:               '700ms-900ms assume it's a frame sync pulse - 800ms optimal                                                                   
           type := 2 'sync                                                                                                                                                                          
       other:                                'unreadable, noise, or static                                                                                                               
           type := 3 'error                                                                                               
                                                                                                                                                 
PRI ReadMinute
{{
    Calculate and store based on the "bit" chars in the frame_buffer
}}
    word[@MINUTE] := DataBit(@M_40)*40
    word[@MINUTE] += DataBit(@M_20)*20
    word[@MINUTE] += DataBit(@M_10)*10
    word[@MINUTE] += DataBit(@M_8)*8
    word[@MINUTE] += DataBit(@M_4)*4
    word[@MINUTE] += DataBit(@M_2)*2
    word[@MINUTE] += DataBit(@M_1)
    
DAT
    MINUTE  word  0

PRI ReadHour

    word[@HOUR] := DataBit(@H_20)*20
    word[@HOUR] += DataBit(@H_10)*10
    word[@HOUR] += DataBit(@H_8)*8
    word[@HOUR] += DataBit(@H_4)*4
    word[@HOUR] += DataBit(@H_2)*2
    word[@HOUR] += DataBit(@H_1)

DAT
    HOUR  word  0
       
PRI ReadYear 

    word[@YEAR] := DataBit(@Y_80)*80
    word[@YEAR] += DataBit(@Y_40)*40
    word[@YEAR] += DataBit(@Y_20)*20
    word[@YEAR] += DataBit(@Y_10)*10
    word[@YEAR] += DataBit(@Y_8)*8
    word[@YEAR] += DataBit(@Y_4)*4
    word[@YEAR] += DataBit(@Y_2)*2
    word[@YEAR] += DataBit(@Y_1)
    word[@YEAR] += EPOCH

CON
    EPOCH  =  2000
         
DAT
    YEAR  word  0

PRI ReadDoY     'day of year

    word[@DOY] := DataBit(@DOY_200)*200
    word[@DOY] += DataBit(@DOY_100)*100
    word[@DOY] += DataBit(@DOY_80)*80
    word[@DOY] += DataBit(@DOY_40)*40
    word[@DOY] += DataBit(@DOY_20)*20
    word[@DOY] += DataBit(@DOY_10)*10
    word[@DOY] += DataBit(@DOY_8)*8
    word[@DOY] += DataBit(@DOY_4)*4
    word[@DOY] += DataBit(@DOY_2)*2
    word[@DOY] += DataBit(@DOY_1)*1

DAT
    DOY  word  0

PRI ReadDST
{{
    Just convert the DST and ST frame_buffer chars to digits
}}
    byte[@DST_V] := DataBit(@DST)  
    byte[@ST_V] := DataBit(@ST)
    
DAT
    DST_V  byte  0
    ST_V   byte  0
    
PRI IsLeapYear

    if byte[@LEAPYEAR] == "1" 
        byte[@MONTHS][1] := 29
        return TRUE
               
    elseif byte[@LEAPYEAR] == "0"
        byte[@MONTHS][1] := 28

    return FALSE

DAT
    MONTHS  byte  31,28,31,30,31,30,31,31,30,31,30,31    'days in months

PRI DataBit(frame_bit)
{{
    Return numeric value of a "bit" char from the frame_buffer
}}
    if byte[frame_bit] == "1"      
        return 1        
    else
        return 0 
          
DAT
    FRAME_BUFFER
    P_R            byte    "_"        '0  Frame Reference Bit, Pr
    M_40           byte    "_"        '1  Minutes 40
    M_20           byte    "_"        '2  Minutes 20
    M_10           byte    "_"        '3  Minutes 10
    R_1            byte    "_"        '4  (reserved)  R1
    M_8            byte    "_"        '5  Minutes 8
    M_4            byte    "_"        '6  Minutes 4
    M_2            byte    "_"        '7  Minutes 2
    M_1            byte    "_"        '8  Minutes 1
    P_1            byte    "_"        '9  Position Marker 1, P1
    R_2            byte    "_"        '10 (reserved)  R2
    R_3            byte    "_"        '11 (reserved)  R3
    H_20           byte    "_"        '12 Hours 20
    H_10           byte    "_"        '13 Hours 10
    R_4            byte    "_"        '14 (reserved)  R4
    H_8            byte    "_"        '15 Hours 8
    H_4            byte    "_"        '16 Hours 4
    H_2            byte    "_"        '17 Hours 2
    H_1            byte    "_"        '18 Hours 1
    P_2            byte    "_"        '19 Position Marker 2, P2
    R_5            byte    "_"        '20 (reserved)  R5
    R_6            byte    "_"        '21 (reserved)  R6
    DOY_200        byte    "_"        '22 Day of Year 200
    DOY_100        byte    "_"        '23 Day of Year 100
    R_7            byte    "_"        '24 (reserved)  R7
    DOY_80         byte    "_"        '25 Day of Year 80
    DOY_40         byte    "_"        '26 Day of Year 40
    DOY_20         byte    "_"        '27 Day of Year 20
    DOY_10         byte    "_"        '28 Day of Year 10
    P_3            byte    "_"        '29 Position Marker 3, P3
    DOY_8          byte    "_"        '30 Day of Year 8
    DOY_4          byte    "_"        '31 Day of Year 4
    DOY_2          byte    "_"        '32 Day of Year 2
    DOY_1          byte    "_"        '33 Day of Year 1
    R_8            byte    "_"        '34 (reserved)  R8
    R_9            byte    "_"        '35 (reserved)  R9
                   byte    "_"        '36 UTI Sign +
                   byte    "_"        '37 UTI Sign -
                   byte    "_"        '38 UTI Sign +
    P_4            byte    "_"        '39 Position Marker 4, P4 
                   byte    "_"        '40 UT1 Correction, 0.8s
                   byte    "_"        '41 UT1 Correction, 0.4s
                   byte    "_"        '42 UT1 Correction, 0.2s
                   byte    "_"        '43 UT1 Correction, 0.1s
    R_10           byte    "_"        '44 (reserved)  R10
    Y_80           byte    "_"        '45 Year 80
    Y_40           byte    "_"        '46 Year 40
    Y_20           byte    "_"        '47 Year 20
    Y_10           byte    "_"        '48 Year 10
    P_5            byte    "_"        '49 Position Marker 5, P5
    Y_8            byte    "_"        '50 Year 8
    Y_4            byte    "_"        '51 Year 4
    Y_2            byte    "_"        '52 Year 2
    Y_1            byte    "_"        '53 Year 1
    R_11           byte    "_"        '54 (reserved)  R11
    LEAPYEAR       byte    "_"        '55 Leap Year Indicator
    LEAPSEC        byte    "_"        '56 Leap Second Warning
    DST            byte    "_"        '57 Daylight Savings Time
    ST             byte    "_"        '58 Daylight Savings Time
    P_0            byte    "_"        '59 Frame Reference Bit, P0
                   byte     0         'Frame string terminator

DAT
    SECOND         byte     0     

PRI IsMinuteValid

    if !SyncCheck(@P_R)  'test the framing pulses 
        return FALSE
    if !SyncCheck(@P_1) 
        return FALSE
        
    if !DataValid(@M_40) 'test the data values
        return FALSE
    if !DataValid(@M_20)  
        return FALSE
    if !DataValid(@M_10) 
        return FALSE
    if !DataValid(@M_8) 
        return FALSE
    if !DataValid(@M_4) 
        return FALSE
    if !DataValid(@M_2) 
        return FALSE
    if !DataValid(@M_1) 
        return FALSE
        
    return TRUE          'test passed

PRI IsHourValid

    if !SyncCheck(@P_1)   
        return FALSE
    if !SyncCheck(@P_2) 
        return FALSE
        
    if !DataValid(@H_20)  
        return FALSE
    if !DataValid(@H_10)
        return FALSE
    if !DataValid(@H_8) 
        return FALSE
    if !DataValid(@H_4) 
        return FALSE
    if !DataValid(@H_2) 
        return FALSE
    if !DataValid(@H_1) 
        return FALSE

    return TRUE
    
PRI IsYearValid

    if !SyncCheck(@P_4)  
        return FALSE
    if !SyncCheck(@P_5) 
        return FALSE
    if !SyncCheck(@P_0) 
        return FALSE
        
    if !DataValid(@Y_80) 
        return FALSE
    if !DataValid(@Y_40)
        return FALSE
    if !DataValid(@Y_20)
        return FALSE
    if !DataValid(@Y_10)
        return FALSE
    if !DataValid(@Y_8) 
        return FALSE
    if !DataValid(@Y_4) 
        return FALSE
    if !DataValid(@Y_2) 
        return FALSE
    if !DataValid(@Y_1) 
        return FALSE

    return TRUE

PRI IsDoYValid

    if !SyncCheck(@P_2)   
        return FALSE
    if !SyncCheck(@P_3) 
        return FALSE
    if !SyncCheck(@P_4) 
        return FALSE
        
    if !DataValid(@DOY_200)
        return FALSE
    if !DataValid(@DOY_100)
        return FALSE
    if !DataValid(@DOY_80)
        return FALSE
    if !DataValid(@DOY_40)
        return FALSE
    if !DataValid(@DOY_20)
        return FALSE
    if !DataValid(@DOY_10)
        return FALSE
    if !DataValid(@DOY_8) 
        return FALSE
    if !DataValid(@DOY_4) 
        return FALSE
    if !DataValid(@DOY_2) 
        return FALSE
    if !DataValid(@DOY_1) 
        return FALSE

    return TRUE

PRI IsDSTValid

    if !SyncCheck(@P_5)   
        return FALSE
    if !SyncCheck(@P_0) 
        return FALSE

    if !DataValid(@DST)
        return FALSE
    if !DataValid(@ST) 
        return FALSE

    return TRUE

PRI IsLeapValid

    if !SyncCheck(@P_5)   
        return FALSE
    if !SyncCheck(@P_0) 
        return FALSE

    if !DataValid(@LEAPYEAR)
        return FALSE
    if !DataValid(@LEAPSEC) 
        return FALSE

    return TRUE

PRI IsSyncValid 

    if !SyncCheck(@P_1) 
        return FALSE
    if !SyncCheck(@P_2) 
        return FALSE
    if !SyncCheck(@P_3) 
        return FALSE
    if !SyncCheck(@P_4) 
        return FALSE
    if !SyncCheck(@P_5)
        return FALSE
    if !SyncCheck(@P_0) 
        return FALSE

    return TRUE

PRI DataValid(frame_bit)
{{
    Check if frame bit appears to be decoded properly
}}
    if byte[frame_bit] == "0"            
        return TRUE
    if byte[frame_bit] == "1"             
        return TRUE
           
    return FALSE

PRI SyncCheck(frame_bit)
{{
    Check if sync bit appears to be decoded properly 
}}
    if byte[frame_bit] == "S"              
        return TRUE

    return FALSE

DAT
{{
   Daylight saving time (DST) and standard time (ST) information is transmitted at seconds 57 and 58.
   When ST is in effect, bits 57 and 58 are set to 0.
   When DST is in effect, bits 57 and 58 are set to 1.
   On the day of a change from ST to DST bit 57 changes from 0 to 1 at 0000 UTC,
    and bit 58 changes from 0 to 1 exactly 24 hours later.
   On the day of a change from DST back to ST bit 57 changes from 1 to 0 at 0000 UTC,
    and bit 58 changes from 1 to 0 exactly 24 hours later.
   http://tf.nist.gov/general/pdf/1383.pdf
                     
    DST ST    bits                                                       
    --- ---                                                      
     0   0    Standard Time                                      
     1   0    Day of change ST ──▶ DST                           
     1   1    Daylight Savings Time                              
     0   1    Day of change DST ──▶ ST       
}}
DAT
{{
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                             TERMS OF USE: MIT License                                         │                                                                           
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated   │
│documentation files (the "Software"), to deal in the Software without restriction, including without limitation│
│the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,   │
│and to permit persons to whom the Software is furnished to do so, subject to the following conditions:         │                                                         │
│                                                                                                               │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions  │
│of the Software.                                                                                               │
│                                                                                                               │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED  │
│TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL  │
│THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF  │
│CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       │
│DEALINGS IN THE SOFTWARE.                                                                                      │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}                      