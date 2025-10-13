hirom

incsrc "hardware.asm"           ;Include namespace HW which contains names for each memory and register addr in the SNES
incsrc "65C816-Vars.asm"

arch 65816

org !EntryBank

Reset:
    sei
    stz.w HW_NMITIMEN               ;Store 0 in HW_NMITIMEN
    stz.w HW_HDMAEN                 ;Store 0 in HW_HDMAEN
    clc
    xce
    rep #$FF
    ldx.w #$01FF
    txs

    jml MainCode

org !CodeBank

MainCode:

    sep #$20
    stz.b MZP.Counter

    jsr LoadMusic

    ldx.w #$003F
    -
    jml +
    +
    dex
    bpl -

    ;jsr LoadTune
    jsr PlaySfx

    -
    jmp -

NMIHandler:
    rti

PlaySfx:
    sep #$20            ;Send Play SFX command over
    lda.b #$02          ;Play SFX
    sta.w HW_APUI00
    lda.b #$00          ;SFX index
    sta.w HW_APUI01
    lda.b MZP.Counter   ;Wait for SPC side to catch up
    -
    cmp.w HW_APUI03
    bne -
    inc
    sta.w HW_APUI03
    sta.b MZP.Counter   ;Send timer over
    rts

LoadTune:
    php
    phb
    sep #$20                        ;Grab tune bank
    lda.b #bank(TuneData)
    pha
    plb
    
    sep #$20
    lda.b #$01                      ;Send Load tune command
    sta.w HW_APUI00

    rep #$10
    rep #$20
    lda.w #TuneDataEnd-TuneData     ;Send length of data over to APU
    sta.l HW_APUI01
    tay                             ;Set Y to length of data to send
    ldx.w #$0000
    sep #$20
    lda.b #$FF
    sta.l HW_APUI03                 ;Set driver counter to APU-3
    lda.b #$00
    sta.b MZP.R0                    ;Set rolling counter to $00
    -
    lda.l HW_APUI03
    inc
    bne -                           ;Wait for APU-3 to return a 0 byte, meaning we are ready for transfer

    ;Tune loading loop
    -
    rep #$20
    lda.w TuneData, X               ;Send lo word
    sta.l HW_APUI00
    inx
    inx
    lda.w TuneData, X               ;Send hi word
    sta.l HW_APUI02
    inx
    inx
    sep #$20
    --
    lda.l HW_APUI03                 ;Wait for APU-3 rolling counter to be inequal, meaning the next byte is to be read
    cmp.b MZP.R0
    beq --
    sta.b MZP.R0                    ;Set rolling counter to current APU-3 counter
    rep #$20
    tya
    sec
    sbc.w #$0004                    ;Subtract index by 4, break out if counter has underflowed
    tay
    bcs -
    ;Exit out of the routine
    plb
    plp
    rts

TuneData:
for i = 0..$1000
    dw !i
endfor
TuneDataEnd:

LoadMusic:
    php
    rep #$10
    sep #$20
    lda.b #$AA
    sta.w HW_APUI00
    lda.b #$BB
    sta.w HW_APUI01

    ldx.w #DriverCode
    stx.b MZP.Ptr0
    lda.b #bank(DriverCode)
    sta.b MZP.Ptr0+2

    .CheckPorts:
    lda.w HW_APUI00
    cmp.b #$AA
    bne .CheckPorts

    lda.w HW_APUI01
    cmp.b #$BB
    bne .CheckPorts

    rep #$21
    lda.w #DriverStart
    sta.w HW_APUI02
    sep #$20

    lda.b #$CC
    sta.w HW_APUI01
    sta.w HW_APUI00
    
    ;Check APU0 is $CC
    -
    cmp.w HW_APUI00
    bne -

    ldx.w #DriverEnd-DriverStart

    stz.b MZP.R0
    sep #$20
    .TransferLoop:
    lda.b [MZP.Ptr0]
    sta.w HW_APUI01
    lda.b MZP.R0
    sta.w HW_APUI00
    
    ;Check if counter has changed
    -
    lda.w HW_APUI00
    cmp.b MZP.R0
    bne -
    inc.b MZP.R0
    rep #$20
    inc.b MZP.Ptr0
    sep #$20
    dex
    bne .TransferLoop
    
    inc.b MZP.R0
    inc.b MZP.R0
    lda.b MZP.R0
    sta.w HW_APUI00
    
    ldx.w #$0200                ;Start of driver memory
    stx.w HW_APUI02

    lda.b #$00
    sta.w HW_APUI01

    .WaitCheck:
    lda.w HW_APUI00             ;Make sure SPC has aknowledged finished transfer
    bne .WaitCheck
    plp
    rts

org $FFC0
db "Cobalt driver program"
db $11  ;ROM type, FAST-Rom
db $00  ;
db $00, $00, $00, $00, $00, $00, $00, $00, $00

dw $FFFF                        ;Vector table
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw NMIHandler
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw $FFFF
dw Reset
dw $FFFF

org !MusicBank
DriverCode:
incsrc "Cobalt.asm"