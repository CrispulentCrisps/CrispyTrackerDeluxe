incsrc "Cobalt-Vars.asm"

arch SPC700

base $0200
DriverStart:
    ;Setup CPU
    mov.b X, #$FF
    mov SP, X

    mov.b SPC_Test, #$0A
    mov.b SPC_Timer1, #$85  ;Set music timer to 60hz
    mov.b SPC_Timer2, #$2C  ;Set effects timer to 180hz
    mov.b SPC_Control, #$7F ;Set timers on
    mov.b SPC_APU0, #$00
    mov.b SPC_APU1, #$00
    mov.b SPC_APU2, #$00
    mov.b SPC_APU3, #$00

    ;Clear ZP
    mov X, #$00
    mov Y, #$F0
    mov A, #$00
    -
    mov.b (X+), A
    dec Y
    bne -

    ;Reset DSP values
    %spc_write(DSP_MVOL_L, $7F)
    %spc_write(DSP_MVOL_R, $7F)
    %spc_write(DSP_EVOL_L, $00)
    %spc_write(DSP_EVOL_R, $00)
    %spc_write(DSP_EFB, $00)
    %spc_write(DSP_EDL, $00)
    %spc_write(DSP_ESA, $00)
    %spc_write(DSP_DIR, !CodeBuffer>>8)
    %spc_write(DSP_PMON, $00)
    %spc_write(DSP_EON, $00)
    %spc_write(DSP_NON, $00)
    %spc_write(DSP_FLG, $20)
    
    if !TRACKER == $00
        ;Set sequence pointers to first order in the table
        nop
        nop
        nop
        nop
        mov.b ZP.PauseFlag, #$01
    else
        mov.b A, #(SfxList)&$FF
        mov.w SfxListStart, A
        mov.b A, #(SfxList>>8)&$FF
        mov.w SfxListStart+1, A
        
        mov.b A, #(InstrumentTable)&$FF
        mov.w InstrumentStart, A
        mov.b A, #(InstrumentTable>>8)&$FF
        mov.w InstrumentStart+1, A
        
        mov.b A, #(OrderTable)&$FF
        mov.w TuneStart, A
        mov.b A, #(OrderTable>>8)&$FF
        mov.w TuneStart+1, A

    endif

    call ReadTuneData

    ;Main Timer loops
MainTimerLoop:
    mov.b A, SPC_Count1                 ;Music timer, set to update once a frame
    beq +
    mov.b A, ZP.PauseFlag
    bne +
    mov.b ZP.ChIndex, #!ChannelCount-1
    call MusicRoutine
    +
    mov.b A, SPC_Count2                 ;Effects timer, set to update 4 times a frame
    beq +
    mov.b ZP.ChIndex, #!Ch_SfxChannels-1
    call EffectsRoutine
    +
    cmp.b ZP.ComCounter, SPC_APU3                   ;Grab main-side counter, skip over if inequal
    beq +
    call CommunicationRoutine
    +
    bra MainTimerLoop


MusicRoutine:
    mov.b ZP.R4, #$00       ;Update output flag
    ;Decrement Speed timer
    mov.b A, ZP.MusTimer
    beq +
    dec.b ZP.MusTimer
    jmp .SkipMusicUpdate
    +

    inc.b ZP.R4

    ;Reset mirrors
    mov.b ZP.KON, #$00
    mov.b ZP.KOFF, #$00
    mov.b ZP.EON, #$00
    mov.b ZP.NON, #$00
    mov.b ZP.PMON, #$00
    
    mov.b X, ZP.MusSpeedSel
    mov.b A, ZP.MusSpeed1+X
    mov.b ZP.MusTimer, A
    eor.b ZP.MusSpeedSel, #$04
    ;Do per-channel operations
    .ChLoop:
    mov.b X, ZP.ChIndex
    mov.b A, X
    asl A
    mov.b ZP.ChIndWord, A

    ;Decrement current timer
    mov A, ZP.ChTimer+X
    beq +
    dec.b ZP.ChTimer+X
    +
    bne .SkipSeqRead
    ;If timer up then read new sequence for given track
    call ReadSeqData
    .SkipSeqRead:

    dec.b ZP.ChIndex
    bpl .ChLoop
    .SkipMusicUpdate:
    
    ;Do SFX routine
    mov.b ZP.ChIndex, #!Ch_SfxChannels-1
    call SFXRoutine

    mov.b A, ZP.R4
    bne +
    jmp .SkipChannelUpdates
    +

    ;Transfer changes to correct registers
    ;Copy over instrument indices and overwrite values with SFX playing
    mov.b X, #!ChannelCount-1
    -
    mov.b A, ZP.ChInst+X
    mov.b ZP.R0+X, A
    dec X
    bpl -

    ;Overwrite music instruments with SFX instruments
    mov.b X, #!Ch_SfxChannels-1
    mov.b Y, #!SfxChannels-1
    -
    mov.b A, ZP.SfxEnable+Y
    beq +
    mov.b A, ZP.ChInst+X
    mov.b ZP.R0-!SfxChannels+X, A
    +
    dec X
    dec Y
    bpl -

    ;Apply changes for given channel
    mov.b X, #!ChannelCount-1
    .InstWrite:
    ;Apply instrument changes
    mov.w A, InstrumentStart
    mov.b ZP.Ptr0, A
    mov.w A, InstrumentStart+1
    mov.b ZP.Ptr0+1, A
    mov.b A, ZP.R0+X
    mov.b Y, #!InstSize           ;Size of instrument structure
    mul YA
    addw YA, ZP.Ptr0        ;Instrument pointer
    movw.b ZP.Ptr0, YA

    mov.b Y, #$03
    mov.b A, X
    xcn
    or.b A, #$07            ;Reverse write loop, start at GAIN
    mov.b SPC_RegADDR, A

    .InstWriteLoop:
    mov.b A, (ZP.Ptr0)+Y
    mov.b SPC_RegData, A
    dec.b SPC_RegADDR
    dec Y
    bpl .InstWriteLoop

    ;Grab flags from current instrument
    mov.b Y, #$04
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.R7, A
    ;Bit test the current flags

    ;Echo
    bbc ZP.R7.0, +
    mov.b A, ZP.EON
    or.w A, BitfieldTable+X
    mov.b ZP.EON, A
    +
    
    ;Noise
    bbc ZP.R7.1, +
    mov.b A, ZP.NON
    or.w A, BitfieldTable+X
    mov.b ZP.NON, A
    +
    
    ;Pitch modulation
    bbc ZP.R7.2, +
    mov.b A, ZP.PMON
    or.w A, BitfieldTable+X
    mov.b ZP.PMON, A
    +

    dec.b X
    bpl .InstWrite

    ;Apply changes to output
    mov.b SPC_RegADDR, #DSP_EON
    mov.b SPC_RegData, ZP.EON
    mov.b SPC_RegADDR, #DSP_NON
    mov.b SPC_RegData, ZP.NON
    mov.b SPC_RegADDR, #DSP_PMON
    mov.b SPC_RegData, ZP.PMON
    
    mov.b SPC_RegADDR, #DSP_KON
    mov.b SPC_RegData, ZP.KON
    mov.b SPC_RegADDR, #DSP_KOF
    mov.b SPC_RegData, ZP.KOFF

    .SkipChannelUpdates:
    ret

    ;
    ;   Note - ZP.R4 is used as an update flag, this means it should NOT be tampered with 
    ;   outisde of the initial INC instruction
    ;
SFXRoutine:
    nop
    .SfxRoutineCheck:
    ;Skip over if SFX is not enabled
    mov.b A, ZP.ChIndex
    setc
    sbc.b A, #!ChannelCount
    mov.b X, A
    mov.b A, ZP.SfxEnable+X
    beq .SkipSfxChannelUpdate
    ;Decrement Speed timer
    mov.b A, ZP.MusTimer+1+X
    beq .ReadSfxSeq
    dec.b ZP.MusTimer+1+X
    bra .SkipSfxChannelUpdate
    .ReadSfxSeq:
    inc.b ZP.R4
    ;Channel timer up, read sequence
    mov.b A, ZP.ChIndex
    asl A
    mov.b ZP.ChIndWord, A
    
    call ReadSeqData
    
    ;Reset timer speed
    mov.b A, ZP.ChIndex
    lsr A
    lsr A
    lsr A
    mov.b X, A
    mov.b Y, A                  ;SFX Channel index
    clrc
    adc.b A, ZP.MusSpeedSel+X
    mov.b X, A
    mov.b A, ZP.MusSpeed1+X
    mov.b ZP.MusTimer+Y, A

    mov.b A, #$04
    eor.b A, ZP.MusSpeedSel+Y
    mov.b ZP.MusSpeedSel+Y, A

    .SkipSfxChannelUpdate:
    dec.b ZP.ChIndex
    mov.b A, #!ChannelCount-1
    cbne ZP.ChIndex, .SfxRoutineCheck
    ret

ReadSeqData:
    .Readloop:
    %ReadSeqVal()
    asl A
    mov.b X, A
    jmp (SequenceCommands+X)

SequenceCommands:
    dw Com_Sleep        ;$00
    dw Com_Jump         ;$01
    dw Com_Break        ;$02
    dw Com_Inst         ;$03
    dw Com_Pitch        ;$04
    dw Com_Volume       ;$05
    dw Com_Speed1       ;$06
    dw Com_Speed2       ;$07
    dw Com_Vibrato      ;$08
    dw Com_Portamento   ;$09
    dw Com_VolumeSlide  ;$0A
    dw Com_NoiseVal     ;$0B
    dw $0000            ;$0C
    dw $0000            ;$0D
    dw $0000            ;$0E
    dw $0000            ;$0F
    dw $0000            ;$10
    dw $0000            ;$11
    dw $0000            ;$12
    dw $0000            ;$13
    dw $0000            ;$14
    dw $0000            ;$15
    dw $0000            ;$16
    dw $0000            ;$17
    dw $0000            ;$18
    dw $0000            ;$19
    dw $0000            ;$1A
    dw $0000            ;$1B
    dw $0000            ;$1C
    dw $0000            ;$1D
    dw $0000            ;$1E
    dw Com_SfxEnd       ;$1F

    ;
    ;   Description:
    ;       Sets a sleep timer, this forces the given channel sequence stream to wait N frames before beginning the next sequence read
    ;
    ;   Assumptions:
    ;       This command is a Termination command, meaning the sequence will stop reading once this command is executed
    ;       Due to this, it is best to have this be at the end of a given sequence stream
    ;
Com_Sleep:
    %ReadSeqVal()
    mov.b X, ZP.ChIndex
    mov.b ZP.ChTimer+X, A
    ret
    
    ;
    ;   Description:
    ;       Sets the order read for the current channel sequence stream
    ;
    ;   Assumptions:
    ;       This command is a Termination command, meaning the sequence will stop reading once this command is executed
    ;       Due to this, it is best to have this be at the end of a given sequence stream
    ;
Com_Jump:
    %ReadSeqVal()
    mov.b ZP.R0, A
    mov.b ZP.ChOrder+X, A
    %ReadSeqVal()
    mov.b ZP.R1, A
    mov.b ZP.ChOrder+1+X, A
    
    mov.b A, X
    mov.b Y, A
    mov.b A, (ZP.R0)+Y
    mov.b ZP.ChSeq+X, A
    inc Y
    mov.b A, (ZP.R0)+Y
    mov.b ZP.ChSeq+1+X, A
    ret

    ;
    ;   Description:
    ;       Increments order position by 1 [16 bytes]
    ;
    ;   Assumptions:
    ;       This command is a Termination command, meaning the sequence will stop reading once this command is executed
    ;       Due to this, it is best to have this be at the end of a given sequence stream
    ;
Com_Break:
    mov.b X, ZP.ChIndWord

    mov.b A, ZP.ChOrder+X
    clrc
    adc.b A, #$10               ;Order size
    bcc +
    inc.b ZP.ChOrder+1+X
    +
    mov.b ZP.ChOrder+X, A
    
    mov.b A, ZP.ChOrder+X
    mov.b ZP.R0, A
    mov.b A, ZP.ChOrder+1+X
    mov.b ZP.R1, A

    mov.b Y, #$00
    mov.b A, (ZP.R0)+Y
    mov.b ZP.ChSeq+X, A
    inc Y
    mov.b A, (ZP.R0)+Y
    mov.b ZP.ChSeq+1+X, A
    ret

Com_Inst:
    %ReadSeqVal()
    mov.b X, ZP.ChIndex
    mov.b ZP.ChInst+X, A
    jmp ReadSeqData

Com_Pitch:
    %ReadSeqVal()
    mov.b ZP.ChPitch+X, A
    %ReadSeqVal()
    mov.b ZP.ChPitch+1+X, A
    
    mov.b A, ZP.ChIndex
    bbc ZP.ChIndex.3, +
    setc
    sbc.b A, #!SfxChannels
    +
    mov X, A
    mov.b A, ZP.KON
    or.w A, BitfieldTable+X
    mov.b ZP.KON, A
    jmp ReadSeqData

Com_Volume:
    %ReadSeqVal()
    mov.b ZP.ChVol+X, A
    %ReadSeqVal()
    mov.b ZP.ChVol+1+X, A
    jmp ReadSeqData

Com_Speed1:
    %ReadSeqVal()
    %IsSfx()
    mov.b ZP.MusSpeed1+X, A
    jmp ReadSeqData

Com_Speed2:
    %ReadSeqVal()
    %IsSfx()
    mov.b ZP.MusSpeed2+X, A
    jmp ReadSeqData

Com_Vibrato:
    %ReadSeqVal()
    mov.b X, ZP.ChIndex
    mov.b ZP.ChVibVal+X, A
    mov.b A, #$00
    mov.b ZP.ChVibPhase+X, A
    jmp ReadSeqData
    
Com_Portamento:
    %ReadSeqVal()
    mov.b X, ZP.ChIndex
    mov.b ZP.ChPortVal+X, A
    jmp ReadSeqData

Com_VolumeSlide:
    %ReadSeqVal()
    mov.b X, ZP.ChIndex
    mov.b ZP.ChVolSlideVal+X, A
    jmp ReadSeqData
    
Com_NoiseVal:
    mov.b SPC_RegADDR, #DSP_FLG
    mov.b A, SPC_RegData
    and.b A, #$E0
    mov.b ZP.R0, A
    %ReadSeqVal()
    or.b A, ZP.R0
    mov.b SPC_RegData, A
    jmp ReadSeqData

Com_SfxEnd:
    mov.b A, ZP.ChIndex
    setc
    sbc.b A, #!ChannelCount
    mov X, A
    mov.b A, #$00
    mov.b ZP.SfxEnable+X, A
    ret

    ;
    ;   Communication routine
    ;       Non-zero command is sent via SPC_APU0
    ;       Zero command send back to CPU
    ;       Once command has been read in it will send back the same command value
    ;       that was put into SPC_APU0
    ;
CommunicationRoutine:
    mov.b A, SPC_APU0
    inc.b ZP.ComCounter
    mov.b HW_APUI03, ZP.ComCounter
    dec.b A
    asl A
    mov.b X, A
    jmp (ProComActions+X)
ComReturn:
    ret

ProComActions:
    dw ProCom_Load
    dw ProCom_PlaySFX
    dw ProCom_FadeTune
    dw ProCom_SetMaster

    ;
    ;   Tune loader routine:
    ;
    ;       Setup:
    ;           The driver will send $FF to APU03 to request a word of data from the
    ;           main CPU, it will then send $00 back to wait while it transfer the word
    ;
ProCom_Load:
    %spc_write(DSP_FLG, $E0)
    mov.b SPC_Control, #$00
    ;Initialise absolute moves with tune starting address
    mov.b A, TuneStart
    mov.b Y, TuneStart+1
    movw.b ZP.R5, YA
    mov.w .Mov0+1, A
    mov.w .Mov0+2, Y
    mov.w .Mov1+1, A
    mov.w .Mov1+2, Y
    mov.w .Mov2+1, A
    mov.w .Mov2+2, Y
    mov.w .Mov3+1, A
    mov.w .Mov3+2, Y
    
    mov.b ZP.R2, #$00
    mov.b ZP.R3, #$04
    mov.b X, #$00

    ;Make sure both sides are ready for transfer
    mov.b ZP.R0, SPC_APU1
    mov.b ZP.R1, SPC_APU2
    mov.b SPC_APU3, #$FF    ;Start transfer

    .TransferLoop:
    mov.b A, SPC_APU0       ;3 cycles
    .Mov0:
    mov.w .Mov0+X, A          ;5 cycles
    inc X

    mov.b A, SPC_APU1       ;3 cycles
    .Mov1:
    mov.w .Mov1+X, A        ;5 cycles
    inc X

    mov.b A, SPC_APU2       ;3 cycles
    .Mov2:
    mov.w .Mov2+X, A          ;5 cycles
    inc X

    mov.b A, SPC_APU3       ;3 cycles
    .Mov3:
    mov.w .Mov3+X, A        ;5 cycles
    inc X
    mov.b SPC_APU3, X       ;4 cycles
    
    bne +
    inc.w .Mov0+2           ;3 cycles
    inc.w .Mov1+2           ;3 cycles
    inc.w .Mov2+2           ;3 cycles
    inc.w .Mov3+2           ;3 cycles
    +
    
    setc                    ;1 cycle
    sbc.b ZP.R0, #$04       ;6 cycles
    bcs .TransferLoop       ;2/4 cycles
    sbc.b ZP.R1, #$00       ;6 cycles
    bcs .TransferLoop       ;2/4 cycles
    .TransferFinished:
    ;Tune now loaded, read header information to setup tune

    jmp ComReturn

ProCom_PlaySFX:
    ;Find tune index, APU-1 will be the tune index
    mov.b X, #$00
    mov.w A, SfxListStart
    mov.b ZP.Ptr0, A
    mov.w A, SfxListStart+1
    mov.b ZP.Ptr0+1, A

    mov.b Y, #$00
    mov.b A, SPC_APU1
    asl A
    bcc +
    inc Y
    +
    addw YA, ZP.Ptr0
    movw ZP.Ptr0, YA

    ;Construct pointer to list item
    mov.b Y, #$00
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.R0, A
    inc Y
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.R1, A

    movw YA, ZP.R0
    movw ZP.Ptr0, YA

    mov.b Y, #$00
    ;Decode SFX Header
    ;Channel offset
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.R0, A
    inc Y
    
    ;Channel count
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.R1, A
    mov.b ZP.R2, A
    inc Y
    
    ;Initial speed 1
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.MusSpeed1+1+X, A   ;Offset by 1 to skip music speed setting
    inc Y
    
    ;Initial speed 2
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.MusSpeed2+1+X, A   ;Offset by 1 to skip music speed setting
    inc Y

    ;Setup SFX sequence
    mov.b X, #ZP.ChSeq+(!ChannelCount*2)
    -
    mov.b A, (ZP.Ptr0)+Y
    mov.b (X+), A
    inc Y
    mov.b A, (ZP.Ptr0)+Y
    mov.b (X+), A
    inc Y
    dec.b ZP.R1
    bpl -
    
    ;Enable SFX channels
    mov.b X, #ZP.SfxEnable
    mov.b A, #$01
    -
    mov.b (X+), A
    dec.b ZP.R2
    bpl -

    jmp ComReturn

ProCom_FadeTune:

    jmp ComReturn

ProCom_SetMaster:

    jmp ComReturn

EffectsRoutine:
    nop
    .FxLoop:
    mov.b A, ZP.ChIndex
    asl A
    mov.b X, A
    mov.b ZP.ChIndWord, A
    
    ;Setup temporary values to process
    mov.b A, ZP.ChPitch+X
    mov.b ZP.OutPitch, A
    mov.b A, ZP.ChPitch+1+X
    mov.b ZP.OutPitch+1, A

    mov.b A, ZP.ChVol+X
    mov.b ZP.OutVol, A
    mov.b A, ZP.ChVol+1+X
    mov.b ZP.OutVol+1, A

    ;--------------------;
    ;     Portamento     ;
    ;--------------------;
    mov.b ZP.R1, #$00
    mov.b X, ZP.ChIndex
    mov.b A, ZP.ChPortVal+X
    asl A
    bcc +
    eor.b ZP.R1, #$FF
    inc.b ZP.R1
    +
    mov.b ZP.R0, A

    mov.b X, ZP.ChIndWord
    mov.b A, ZP.ChPitch+1+X
    mov.b Y, A
    mov.b A, ZP.ChPitch+X
    addw YA, ZP.R0
        
    mov.b X, ZP.ChIndWord
    mov.b ZP.ChPitch+X, A
    mov.b ZP.ChPitch+1+X, Y

    ;-----------------;
    ;     Vibrato     ;
    ;-----------------;
    clrc
    mov.b X, ZP.ChIndex
    mov.b A, ZP.ChVibVal+X
    and.b A, #$0F
    adc.b A, ZP.ChVibPhase+X
    mov.b ZP.ChVibPhase+X, A
    mov.b Y, A
    mov.w A, SineTable+Y
    mov.b Y, A
    mov.b A, ZP.ChVibVal+X
    and.b A, #$F0
    xcn
    mul YA
    addw YA, ZP.OutPitch
    movw ZP.OutPitch, YA

    ;-----------------------;
    ;     Volume slides     ;
    ;-----------------------;
    ;mov.b A, ZP.ChVolSlideCnt+X
    ;beq +
    ;+
    ;mov.b ZP.ChVolSlideCnt+X, A
    ;dec.b ZP.ChVolSlideCnt+X
    ;beq +
    ;jmp .SkipVolSlide
    ;+
    ;mov.b A, ZP.ChVolSlideVal+X
    ;and.b A, #$0F
    ;mov.b ZP.ChVolSlideCnt+X, A
    ;mov.b A, ZP.ChVolSlideVal+X
    ;and.b A, #$F0
    ;bpl +
    ;or.b A, #$0F
    ;+
    ;xcn
    ;mov.b ZP.R0, A
    ;mov1.b ZP.R0.7
    ;notc
    ;mov1.b .SignCheck_L.5, C
    ;
    ;mov.b Y, ZP.ChIndWord
    ;mov.b A, ZP.ChVol+Y
    ;clrc
    ;adc.b A, ZP.R0
    ;beq .ZeroVolume_L
    ;.SignCheck_L:
    ;bcs .ZeroVolume_L
    ;bra +
    ;.ZeroVolume_L:
    ;mov.b A, #$00
    ;mov.b ZP.ChVolSlideVal+X, A
    ;bra .SetVol_L
    ;+
    ;bvc .MaxVol_L
    ;bbs ZP.R0.7, .MinVolSet_L
    ;;Max [positive] volume setting
    ;mov.b A, #$00
    ;mov.b ZP.ChVolSlideVal+X, A
    ;mov.b A, #$7F
    ;bra .SetVol_L
    ;.MinVolSet_L:
    ;;Min [negative] volume setting
    ;mov.b A, #$00
    ;mov.b ZP.ChVolSlideVal+X, A
    ;mov.b A, #$80
    ;.MaxVol_L:
    ;
    ;.SetVol_L:
    ;mov.b ZP.ChVol+Y, A


    mov.b ZP.R4, #$00           ;Channel signs
    mov.b A, X
    asl A
    mov.b Y, A
    mov.b Y, ZP.ChIndWord
    mov.b A, ZP.ChVol+Y
    bpl +
    or.b ZP.R4, #$01
    eor.b A, #$FF
    inc A
    +
    mov.b ZP.R0, A
    mov.b A, ZP.ChVol+1+Y
    bpl +
    or.b ZP.R4, #$02
    eor.b A, #$FF
    inc A
    +
    mov.b ZP.R1, A
    mov.b ZP.R2, #$00           ;Volume slide sign
    mov.b A, ZP.ChVolSlideVal+X
    beq .SkipVolSlide
    bmi +
    inc.b ZP.R2
    bra .SkipVolSlideDelta
    +
    dec.b ZP.R2
    .SkipVolSlideDelta:
    mov.b A, ZP.R0
    clrc
    adc.b A, ZP.R2
    bpl .SkipClampL
    bbs ZP.R2.7, ++
    mov.b A, #$7F
    bra .SkipClampL
    ++
    mov.b A, #$00
    .SkipClampL:
    mov.b ZP.R0, A
    
    mov.b A, ZP.R1
    clrc
    adc.b A, ZP.R2
    bpl .SkipClampR
    bbs ZP.R2.7, ++
    mov.b A, #$7F
    bra .SkipClampR
    ++
    mov.b A, #$00
    .SkipClampR:
    mov.b ZP.R1, A
    ;Set channel volume
    bbc ZP.R4.0, +
    eor.b ZP.R0, #$FF
    inc.b ZP.R0
    +
    
    bbc ZP.R4.1, +
    eor.b ZP.R1, #$FF
    inc.b ZP.R1
    +
    
    mov.b A, ZP.R0
    mov.b ZP.ChVol+Y, A
    mov.b A, ZP.R1
    mov.b ZP.ChVol+1+Y, A
    .SkipVolSlide:

    ;Check if currently on SFX, X holds the effective channel index
    mov.b A, ZP.ChIndex
    bbc ZP.ChIndex.3, +
    setc
    sbc.b A, #!SfxChannels
    +
    mov.b X, A              ;Music channel index

    mov.b A, ZP.ChIndex
    setc
    sbc.b A, #!ChannelCount
    bcc .CheckSfxOverwrite          ;Write registers if not SFX channel
    mov.b Y, A              ;Sfx channel index, skip over if < SFX channels
    mov.b A, ZP.SfxEnable+Y
    ;Skip output if SFX is not enabled
    beq .SkipOutput
    .CheckSfxOverwrite:
    clrc
    adc.b A, #!SfxChannels
    bmi .RegWrites
    mov.b Y, A              ;Sfx channel index, skip over if < SFX channels
    mov.b A, ZP.SfxEnable+Y
    bne .SkipOutput
    .RegWrites:
    ;Output processed pitch and volume into the corresponding channel
    mov.b A, X
    xcn
    mov.b SPC_RegADDR, A
    mov.b SPC_RegData, ZP.OutVol
    inc.b SPC_RegADDR
    mov.b SPC_RegData, ZP.OutVol+1
    
    inc.b SPC_RegADDR
    mov.b SPC_RegData, ZP.OutPitch
    inc.b SPC_RegADDR
    mov.b SPC_RegData, ZP.OutPitch+1

    .SkipOutput:
    dec.b ZP.ChIndex
    bmi +
    jmp .FxLoop
    +
    ret

    ;
    ;   Reads tune and assosiated header data
    ;       Will set the echo registers
    ;       Will set the order and sequence for each channel
    ;
ReadTuneData:
    ;Reset register state
    %spc_write(DSP_FLG, $E0)
    %spc_write(DSP_EDL, $00)
    %spc_write(DSP_EON, $00)
    %spc_write(DSP_NON, $00)
    %spc_write(DSP_PMON, $00)
    mov.b ZP.EON, #$00
    mov.b ZP.NON, #$00
    mov.b ZP.PMON, #$00

    mov.b ZP.R7, #$20           ;Echo flag write, by default off
    mov.w A, TuneStart
    mov.b ZP.Ptr0, A
    mov.w A, TuneStart+1
    mov.b ZP.Ptr0+1, A
    mov.b Y, #$00
    ;Read header in

    ;Delay value
    mov.b A, (ZP.Ptr0)+Y
    beq .SkipEchoSet
    inc.b Y
    mov.b ZP.R7, #$00           ;If delay is > 0 then echo flag write should be on
    mov.b SPC_RegADDR, #DSP_EDL
    mov.b SPC_RegData, A
    asl A
    mov.b ZP.R3, A
    asl A
    asl A
    mov.b ZP.R2, A
    mov.b A, #$00
    setc
    sbc.b A, ZP.R2
    mov.b SPC_RegADDR, #DSP_ESA
    mov.b SPC_RegData, A
    mov.b ZP.R2, A
    
    ;Echo feedback
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b SPC_RegADDR, #DSP_EFB
    mov.b SPC_RegData, A
    
    ;Echo volume
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b SPC_RegADDR, #DSP_EVOL_L
    mov.b SPC_RegData, A
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b SPC_RegADDR, #DSP_EVOL_R
    mov.b SPC_RegData, A

    ;Echo coeffecients
    mov.b ZP.R1, #DSP_C0
    .CoeffLoop:
    mov.b A, ZP.R1
    mov.b SPC_RegADDR, A
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b SPC_RegData, A
    clrc
    adc.b ZP.R1, #$10
    bpl .CoeffLoop

    ;Clear out Echo memory
    mov.b Y, #$00
    mov.b X, #$00
    clrc
    mov.b A, ZP.R2
    mov.w .EchoPtr0+2, A
    adc.b A, ZP.R3
    mov.w .EchoPtr1+2, A
    adc.b A, ZP.R3
    mov.w .EchoPtr2+2, A
    adc.b A, ZP.R3
    mov.w .EchoPtr3+2, A
    mov.b A, #$00
    .EchoClearLoop:
    .EchoPtr0:
    mov.w $0000+X, A
    .EchoPtr1:
    mov.w $0000+X, A
    .EchoPtr2:
    mov.w $0000+X, A
    .EchoPtr3:
    mov.w $0000+X, A
    inc.b X
    bne .EchoClearLoop
    inc.w .EchoPtr0+2
    inc.w .EchoPtr1+2
    inc.w .EchoPtr2+2
    inc.w .EchoPtr3+2
    bne .EchoClearLoop

    .SkipEchoSet:
    mov.b Y, #$0C
    ;Speed values
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b ZP.MusSpeed1, A
    mov.b A, (ZP.Ptr0)+Y
    inc.b Y
    mov.b ZP.MusSpeed2, A
    clrc
    adc.b ZP.Ptr0, #sizeof(Music_Header)
    bcc +
    inc.b ZP.Ptr0+1
    +

    ;Set sequence data
    mov.b Y, #(!ChannelCount*2)-1
    -
    mov.b A, (ZP.Ptr0)+Y
    mov.b ZP.ChSeq+Y, A
    dec Y
    bpl -
    
    mov.b ZP.R0, #$00
    mov.b ZP.R1, #$00
    mov.b X, #(!ChannelCount-1)*2
    -
    mov.b Y, #$00
    mov.b ZP.R0, X
    movw.b YA, ZP.R0
    addw.b YA, ZP.Ptr0
    mov.b ZP.ChOrder+1+X, Y
    mov.b ZP.ChOrder+X, A
    dec X
    dec X
    bpl -
    mov.b SPC_RegADDR, #DSP_FLG
    mov.b SPC_RegData, ZP.R7

    ret

    ;u8 32 * sin(t * 2PI);
SineTable:
    db $20,$21,$22,$22,$23,$24,$25,$25,$26,$27
    db $28,$29,$29,$2A,$2B,$2C,$2C,$2D,$2E,$2E
    db $2F,$30,$30,$31,$32,$32,$33,$34,$34,$35
    db $35,$36,$37,$37,$38,$38,$39,$39,$3A,$3A
    db $3B,$3B,$3B,$3C,$3C,$3D,$3D,$3D,$3E,$3E
    db $3E,$3E,$3F,$3F,$3F,$3F,$3F,$40,$40,$40
    db $40,$40,$40,$40,$40,$40,$40,$40,$40,$40
    db $40,$40,$3F,$3F,$3F,$3F,$3F,$3E,$3E,$3E
    db $3E,$3D,$3D,$3D,$3C,$3C,$3B,$3B,$3B,$3A
    db $3A,$39,$39,$38,$38,$37,$37,$36,$35,$35
    db $34,$34,$33,$32,$32,$31,$30,$30,$2F,$2E
    db $2E,$2D,$2C,$2C,$2B,$2A,$29,$29,$28,$27
    db $26,$25,$25,$24,$23,$22,$22,$21,$20,$1F
    db $1E,$1E,$1D,$1C,$1B,$1B,$1A,$19,$18,$17
    db $17,$16,$15,$14,$14,$13,$12,$12,$11,$10
    db $10,$0F,$0E,$0E,$0D,$0C,$0C,$0B,$0B,$0A
    db $09,$09,$08,$08,$07,$07,$06,$06,$05,$05
    db $05,$04,$04,$03,$03,$03,$02,$02,$02,$02
    db $01,$01,$01,$01,$01,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $01,$01,$01,$01,$01,$02,$02,$02,$02,$03
    db $03,$03,$04,$04,$05,$05,$05,$06,$06,$07
    db $07,$08,$08,$09,$09,$0A,$0B,$0B,$0C,$0C
    db $0D,$0E,$0E,$0F,$10,$10,$11,$12,$12,$13
    db $14,$14,$15,$16,$17,$17,$18,$19,$1A,$1B
    db $1B,$1C,$1D,$1E,$1E,$1F

BitfieldTable:
    db $01
    db $02
    db $04
    db $08
    db $10
    db $20
    db $40
    db $80

fill !CodeBuffer-pc()
assert pc() == !CodeBuffer

;-------------------;
;   In driver data  ;
;-------------------;

DirTable:                          ;These are just for debugging purposes
;Test sine+saw sample + dir page
db $08,(!CodeBuffer>>8),$08,(!CodeBuffer>>8),$23,(!CodeBuffer>>8),$23,(!CodeBuffer>>8)

SampleTable:                        ;These are just for debugging purposes
db $84, $17, $45, $35, $22, $22, $31, $21, $10, $68, $01, $21, $0D, $01, $08, $0B, $C3, $3E, $5B, $09, $8B, $D7
db $B1, $E0, $BC, $AF, $78
db $B8, $87, $1F, $00, $F1, $0F, $1F, $00, $00, $8F, $E1, $13, $12, $2D, $52, $14, $10, $F7

InstrumentTable:
    %WriteInstrument($00, $9F, $F2, $7F, $00)
    %WriteInstrument($01, $FF, $EA, $60, $01)

SfxPatterns:
    .Sfx_0_0:
        %WriteComByte(!COM_SPEED1, $0C)
        %WriteComByte(!COM_SPEED2, $0C)
        %WriteComByte(!COM_INST, $01)
        %WriteComWord(!COM_VOLUME, $7F7F)
        %WriteComWord(!COM_PITCH, $0400)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0500)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0600)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0700)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0800)
        %WriteComByte(!COM_SLEEP, $10)
        %WriteCom(!COM_SFXEND)


SfxData:
    .Sfx0_0:
    ;Header data
    db $01                  ;Channel offset [starting in channel 7]
    db $00                  ;Channel number [1 channel playing]
    dw $0608                ;Initial speed
    dw SfxPatterns_Sfx_0_0  ;Sfx data pointer

;List of pointers to the start of SFX files
SfxList:
    dw SfxData_Sfx0_0

;-------------------;
;   Tune specific   ;
;-------------------;

OrderTable:
    ;Header
    db $06                                      ;Echo delay
    db $70                                      ;Echo feedback
    dw $4040                                    ;Echo volume L/R
    db $40, $20, $10, $08, $04, $02, $01, $00   ;Echo coeff
    db $04                                      ;Music speed 1
    db $08                                      ;Music speed 2
    ;Order 0
    .Order0:
        dw PatternMem_Pattern_0
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2

    .Order1:
        dw PatternMem_Pattern_1
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2
        dw PatternMem_Pattern_2

PatternMem:
    .Pattern_0:
        %WriteComByte(!COM_NOISEVAL, $0C)
        %WriteComByte(!COM_VIBRATO, $00)
        %WriteComByte(!COM_SPEED1, $06)
        %WriteComByte(!COM_SPEED2, $06)
        %WriteComWord(!COM_VOLUME, $4040)
        %WriteComByte(!COM_INST, $00)
        %WriteComWord(!COM_PITCH, $0200)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0400)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $0C00)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteComWord(!COM_PITCH, $1000)
        %WriteComByte(!COM_SLEEP, $08)
        %WriteCom(!COM_BREAK)
    .Pattern_1:
        %WriteComByte(!COM_INST, $01)
        %WriteComWord(!COM_PITCH, $1600)
        %WriteComByte(!COM_SLEEP, $04)
        %WriteComByte(!COM_VIBRATO, $4C)
        %WriteComByte(!COM_SLEEP, $10)
        %WriteComByte(!COM_VIBRATO, $FF)
        %WriteComByte(!COM_SLEEP, $10)
        %WriteComWord(!COM_JUMP, OrderTable_Order0)
    .Pattern_2:
        %WriteComByte(!COM_INST, $00)
        %WriteComWord(!COM_VOLUME, $0000)
        %WriteComByte(!COM_SLEEP, $01)
        %WriteComWord(!COM_JUMP, OrderTable_Order0)
    .Pattern_3:
        %WriteComByte(!COM_VOLSLIDE, $F2)
        %WriteComByte(!COM_SPEED2, $0C)
        %WriteComByte(!COM_SPEED2, $0C)
        %WriteComByte(!COM_INST, $00)
        %WriteComWord(!COM_VOLUME, $7F80)
        %WriteComWord(!COM_PITCH, $0C00)
        %WriteComByte(!COM_SLEEP, $10)
        %WriteComWord(!COM_JUMP, OrderTable_Order0)

DriverEnd:
