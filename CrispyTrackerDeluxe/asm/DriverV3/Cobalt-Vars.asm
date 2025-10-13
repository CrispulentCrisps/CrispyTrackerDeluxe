incsrc "spc700.asm"
incsrc "dsp.asm"

!TRACKER =    $01

!CodeBuffer = $0A00                 ;Section of bytes to fill

!ChannelCount = 8
!SfxChannels = 3
!MusSfx = 1+!SfxChannels
!Ch_SfxChannels = (!ChannelCount+!SfxChannels)

struct ZP $0000
.Ptr0           skip 2                  ;General purpose pointer
.Ptr1           skip 2                  ;General purpose pointer
.Ptr2           skip 2                  ;General purpose pointer
.Ptr3           skip 2                  ;General purpose pointer
.R0             skip 1                  ;Scratch memory
.R1             skip 1                  ;Scratch memory
.R2             skip 1                  ;Scratch memory
.R3             skip 1                  ;Scratch memory
.R4             skip 1                  ;Scratch memory
.R5             skip 1                  ;Scratch memory
.R6             skip 1                  ;Scratch memory
.R7             skip 1                  ;Scratch memory

.ChSeq          skip 2*!Ch_SfxChannels  ;Pointer for current channel data
.ChOrder        skip 2*!ChannelCount    ;Pointer for current channel position in order table
.ChVol          skip 2*!Ch_SfxChannels  ;Volume of current channel
.ChPitch        skip 2*!Ch_SfxChannels  ;Pitch of current channel
.ChInst         skip !Ch_SfxChannels    ;Current channel instrument
.ChTimer        skip !Ch_SfxChannels    ;Current channel timer
.ChVibVal       skip !Ch_SfxChannels    ;Channel vibrato value [xy, x - depth, y - speed]
.ChVibPhase     skip !Ch_SfxChannels    ;Channel vibrato sine phase
.ChPortVal      skip !Ch_SfxChannels    ;Channel portamento
.ChVolSlideVal  skip !Ch_SfxChannels    ;Channel volume slide [wait 0x frames before volume change]
.ChVolSlideCnt  skip !Ch_SfxChannels    ;Timer to wait N frames before the volume slide

.ChIndex        skip 1                  ;Current channel index
.KON            skip 1                  ;KON state
.KOFF           skip 1                  ;KOFF state
.EON            skip 1                  ;Echo status
.NON            skip 1                  ;Noise status
.PMON           skip 1                  ;Pitch modulation status
.MusSpeed1      skip !MusSfx            ;Delay time for music track
.MusSpeed2      skip !MusSfx            ;Delay time for music track
.MusSpeedSel    skip !MusSfx            ;Which speed to use for music
.MusTimer       skip !MusSfx            ;Timer for frames to wait before next row

.SfxEnable      skip !SfxChannels       ;Flag for which SFX is enable

.PauseFlag      skip 1                  ;Flag to pause music

.OutPitch       skip 2                  ;Output pitch in effects routine
.OutVol         skip 2                  ;Output volume in effects routine

.ChIndWord      skip 1                  ;Channel index word sized

.ComCounter     skip 1                  ;Rolling counter for communication routine
endstruct

assert sizeof(ZP) < $F0

TuneStart =         $00F8               ;Pointer to start of tune in memory
InstrumentStart =   $01EC               ;Start of instrument data
SfxListStart =      $01EE               ;Start of SFX memory

;
;   Header information for a given tune
;       Will be placed at the start of a given file, intended to be loaded before the start of order memory
;
struct Music_Header $FFF0
.EchoDelay      skip 1                  ;Echo delay value
.EchoFeedback   skip 1                  ;Echo feecback
.EchoVol        skip 2                  ;Echo volume
.EchoCoeff      skip 8                  ;Echo coeffecients
.InitSpeed      skip 2                  ;Initial track speed
endstruct

struct Sfx_Header $FFE0
.ChannelOff     skip 1                  ;Sfx channel slot
.ChannelCount   skip 1                  ;How many channels the SFX
.InitSpeed      skip 2                  ;Initial track speed
.SfxStartPtr    skip 6                  ;List of SFX starting pointers
endstruct

;Music commands
!COM_SLEEP  =       $00     ;Sets a channel to wait N timer passes
!COM_JUMP  =        $01     ;Jumps a channel's order position to a new position
!COM_BREAK =        $02     ;Advance order by 1 position
!COM_INST =         $03     ;Sets the instrument values for a given channel
!COM_PITCH =        $04     ;Plays an absolute pitch
!COM_VOLUME =       $05     ;Sets the volume of a given channel
!COM_SPEED1 =       $06     ;Sets the frame wait for every sleep decrement
!COM_SPEED2 =       $07     ;Sets the frame wait for every sleep decrement
!COM_VIBRATO =      $08     ;Sets the vibrato for a given channel
!COM_PORTAMENTO =   $09     ;Sets the portamento for a given channel
!COM_VOLSLIDE =     $0A     ;Sets the volume slide for a given channel
!COM_NOISEVAL =     $0B     ;Set noise val in flag register
!COM_TREMOLANDO =   $0C     ;Sets the tremolando for a given channel
!COM_PANBRELLO =    $0D     ;Sets the panbrello for a given channel

!COM_SFXEND =       $1F     ;Set SFX flag off channel
!COM_NOTE =         $20     ;Any value $20 and above is interpreted as a note based off of note tables

!PRoCom_NULL =      $00     ;Null value, any value that's 0 is ignored in the communication routine
!PRoCom_LOAD =      $01     ;Sets the IPL loader up
!PRoCom_PLAYSFX =   $02     ;Play SFX out of a specific channel
!PRoCom_FADETUNE =  $03     ;Play SFX out of a specific channel
!PRoCom_SETMASTER = $04     ;Sets the master volume for the track

macro WriteCom(Com)
    db <Com>
endmacro

macro WriteComByte(Com, Val)
    db <Com>
    db <Val>
endmacro

macro WriteComWord(Com, Val)
    db <Com>
    dw <Val>
endmacro

;
;   Flags: ---- -PNE
;                ||Echo
;                |Noise
;                Pitch mod
;
!InstSize = $05
macro WriteInstrument(Srcn, ADSR1, ADSR2, GAIN, Flags)
    db <Srcn>
    db <ADSR1>
    db <ADSR2>
    db <GAIN>
    db <Flags>
endmacro

macro ReadSeqVal()
    mov.b X, ZP.ChIndWord
    mov.b A, (ZP.ChSeq+X)
    inc.b ZP.ChSeq+X
    bne +
    inc.b ZP.ChSeq+1+X
    +
endmacro

macro IsSfx()
    push A
    mov.b A, ZP.ChIndex
    lsr A
    lsr A
    lsr A
    mov.b X, A
    pop A
endmacro