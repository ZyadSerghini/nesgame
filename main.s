; =========================
; iNES HEADER
; =========================
.segment "HEADER"

.byte "NES", $1A
.byte 2              ; 32KB PRG
.byte 1              ; 8KB CHR
.byte $00
.byte $00
.byte 0,0,0,0,0,0,0,0


; =========================
; ZEROPAGE
; =========================
.segment "ZEROPAGE"

frame_ready: .res 1
player_x:    .res 1
player_y:    .res 1
player_vy:   .res 1
buttons:     .res 1


; =========================
; REQUIRED
; =========================
.segment "STARTUP"


; =========================
; RAM (OAM buffer at $0200)
; =========================
.segment "BSS"

oam = $0200

;CONSTANTS

BG_SKY = $20
BG_GROUND = $21


; =========================
; CODE
; =========================
.segment "CODE"

; =========================
; PALETTE
; =========================
palette:
.byte $0D,$06,$15,$26
.byte $0F,$00,$00,$00
.byte $0F,$00,$00,$00
.byte $0F,$00,$00,$00

palette_bg:
.byte $0F,$2C,$2A,$05
.byte $0F,$00,$00,$00
.byte $0F,$00,$00,$00
.byte $0F,$00,$00,$00

; -------------------------
; Controller routines
; -------------------------
read_controller:
    lda #1
    sta $4016
    lda #0
    sta $4016

    lda #0
    sta buttons

    ldx #8
read_loop:
    lda $4016
    lsr a
    rol buttons
    dex
    bne read_loop
    rts


; -------------------------
; NMI
; -------------------------
nmi:
    lda #$00
    sta $2003

    lda #$02        ; page $0200
    sta $4014       ; DMA transfer

    inc frame_ready
    rti


; -------------------------
; RESET
; -------------------------
reset:
    sei
    cld

    ldx #$FF
    txs

; Wait for PPU
vblank1:
    bit $2002
    bpl vblank1

vblank2:
    bit $2002
    bpl vblank2

; -------------------------
; Load sprite palette ($3F10)
; -------------------------
    lda $2002 ; Reset latch

    lda #$3F
    sta $2006
    lda #$10
    sta $2006

    ldx #0
load_palette:
    lda palette, x
    sta $2007
    inx
    cpx #$10
    bne load_palette

;background

lda $2002
lda #$3F
sta $2006
lda #$00
sta $2006

ldx #0
bg_palette:
    lda palette_bg, x
    sta $2007
    inx
    cpx #$10
    bne bg_palette

lda $2002
lda #$20
sta $2006
lda #$00
sta $2006

; fill 30 rows (32 tiles each)

ldy #30
row_loop:
    ldx #32
col_loop:
    lda #BG_SKY
    sta $2007
    dex
    bne col_loop

    dey
    bne row_loop

; Enable NMI + rendering
    lda #%10000000
    sta $2000

    lda #%00011110
    sta $2001

; Init variables
    lda #0
    sta frame_ready

    lda #$80
    sta player_x
    sta player_y

    lda #0
    sta player_vy

; Clear OAM
    lda #$FF
    ldx #0
clear_oam:
    sta oam, x
    inx
    bne clear_oam


; -------------------------
; MAIN LOOP
; -------------------------
forever:

wait_frame:
    lda frame_ready
    beq wait_frame

    lda #0
    sta frame_ready

    jsr read_controller

; RIGHT
    lda buttons
    and #%00000001
    beq not_right
    inc player_x
not_right:

; LEFT
    lda buttons
    and #%00000010
    beq not_left
    dec player_x
not_left:

; JUMP
    lda buttons
    and #%10000000
    beq no_jump

    lda player_y
    cmp #$A0
    bne no_jump

    lda #$F8
    sta player_vy
no_jump:

; GRAVITY
    lda player_vy
    clc
    adc #1
    sta player_vy

; APPLY Y
    lda player_y
    clc
    adc player_vy
    sta player_y

; GROUND
    lda player_y
    cmp #$A0
    bcc in_air

    lda #$A0
    sta player_y

    lda #0
    sta player_vy
in_air:

; -------------------------
; SPRITE (OAM)
; -------------------------
    lda player_y
    sta oam

    lda #$00
    sta oam+1

    lda #%00000000
    sta oam+2

    lda player_x
    sta oam+3

    jmp forever


; =========================
; VECTORS
; =========================
.segment "VECTORS"

.addr nmi
.addr reset
.addr 0

; =========================
; CHR (solid square tile)
; =========================
.segment "CHARS"

.incbin "graphics.chr"