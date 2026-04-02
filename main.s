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

frame_ready: .res 1 ; has a new frame started?
player_x:    .res 1
player_y:    .res 1
player_vy:   .res 1
sprite_offset: .res 1
buttons:     .res 1

frame_counter: .res 1

ptr_lo:      .res 1
ptr_hi:      .res 1


; =========================
; REQUIRED
; =========================
.segment "STARTUP"


; =========================
; RAM (OAM buffer at $0200)
; =========================
.segment "BSS"

oam = $0200


; =========================
; CODE
; =========================
.segment "CODE"

; =========================
; PALETTES
; =========================
palette:
.byte $0D,$06,$15,$26
.byte $0D,$07,$15,$26
.byte $0F,$00,$00,$00
.byte $0F,$00,$00,$00

palette_bg:
.byte $21,$09,$06,$27 ; FIXED universal color
.byte $0F,$30,$21,$00
.byte $0F,$09,$06,$15
.byte $0F,$09,$15,$27


; -------------------------
; Controller
; -------------------------
read_controller:
    ; reset controller
    lda #1
    sta $4016 ; takes a snapshot of all current button states
    lda #0
    sta $4016 ; starts sending those buttoms one by one

    ; clear previous input
    lda #0
    sta buttons

    ; set loop counter
    ldx #8

read_loop:
    lda $4016
    lsr a ;shifts a to the right, bit 0 goes to carry flag
    rol buttons ;shift left w/ carry: carry goes to bit 0 and everything gets shifted to the left
    dex
    bne read_loop
    rts


; -------------------------
; NMI
; -------------------------
nmi:
    ; start writing sprites in the OAM at index 0
    lda #$00 
    sta $2003 

    ; copy 256 bytes from CPU RAM to VRAM ($02 -> $0200, NES copies from $0200 to $02FF)
    lda #$02 ; 
    sta $4014 ; DMA trigger for sprites

    inc frame_ready
    rti ; return from interrupt


; -------------------------
; RESET
; -------------------------
reset:
    sei ; disable interrupts
    cld ; disable decimal mode

    ldx #$FF ; prepare stack pointer value, load x register to $FF 
    txs ; transfer X to stack pointer (initialize it)
    ; stack pointer goes from $0100 to $01FF

; Wait for PPU
vblank1:
    bit $2002 ; copies bit 7 to N flag and bit 6 to V flag, if Vblank active N = 1, N = 0 otherwise
    bpl vblank1 ;branches if N = 0
    ; $2002 = PPU status register, bit 7 = Vblank flag

vblank2:
    ; second check to make sure PPU is fully initialized and safe to use
    bit $2002
    bpl vblank2


; -------------------------
; Load sprite palette
; -------------------------
    lda $2002 ; resets PPU latch (first read = high byte, second = low byte)

    ; set VRAM address to $3F10, next read/write action should occur there
    lda #$3F
    sta $2006
    lda #$10
    sta $2006

    ldx #0
load_palette:
    lda palette, x ; loads A with palette address + offset x
    sta $2007 ; sends A to current PPU address
    inx
    cpx #$10
    bne load_palette


; -------------------------
; Load background palette
; -------------------------
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


; -------------------------
; Load nametable
; -------------------------
    ; stores low byte of nametable address
    lda #<nametable
    sta ptr_lo
    ; stores high byte of nametable address
    lda #>nametable
    sta ptr_hi

    lda $2002 ; resets PPU latch

    ; sets PPU internal address (VRAM) to $2006
    lda #$20
    sta $2006
    lda #$00
    sta $2006

    ldy #$00
    ldx #$04          ; 1024 bytes

; copies 1024 bytes of nametable to VRAM
load_nt:
    lda (ptr_lo), y
    sta $2007 ; write to VRAM
    iny
    bne load_nt

    inc ptr_hi
    dex
    bne load_nt


; -------------------------
; Enable rendering
; -------------------------

    ; PPU control (rendering params)
    lda #%10010000
    sta $2000

    ; bit 7 = Generate NMI at start of VBlank (1 = enabled)
    ; bit 6 = PPU master/slave select, irrelevant here (0 = disabled)
    ; bit 5 = sprite size [8x8/8x16] (0 = 8x8)
    ; bit 4 = background pattern table address [$0000/$1000] (1 = $1000)
    ; bit 3 = sprite pattern table address [$0000/$1000] (0 = $0000)
    ; bit 2 = VRAM address increment after read/write PPU data at address $2007 [increment by 1/32] (0 = increment by 1)
    ; bit 1-0 = base nametable address [$2000/$2400/$2800/$2C00] (00 = $2000)

    ; PPU mask
    lda #%00011110
    sta $2001

    ; bit 7-5 = color effects (0 = off, no color emphasis)
    ; bit 4 = show sprites (1 = on)
    ; bit 3 = show background
    ; bit 2 = show sprites in leftmost 8px
    ; bit 1 = show background in leftmost 8 px
    ; bit 0 = grayscale (0 = off)


; -------------------------
; Init variables
; -------------------------
    lda #0
    sta frame_ready

    lda #$80
    sta player_x
    sta player_y

    lda #0
    sta player_vy

    lda #0
    sta sprite_offset


; -------------------------
; Clear OAM
; -------------------------
    lda #$FF
    ldx #0
; clear all sprite entries in OAM
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
    beq wait_frame ; stops when frame_ready == 1 

    ; resets frame_ready to 0
    lda #0
    sta frame_ready

    jsr read_controller

    lda frame_counter
    clc
    adc #1
    sta frame_counter

    cmp #15
    bne input

    lda #0
    sta frame_counter

    lda sprite_offset
    clc
    adc #2

    cmp #8
    bne incr_sprite_offset
    lda #0

    incr_sprite_offset:
        sta sprite_offset

input:
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
    cmp #$B5 ; compares to Y position on the ground
    bne no_jump

    lda #$F8 ; sets player's velocity to -8 (unsigned)
    sta player_vy
no_jump:


; GRAVITY (velocity += 1 every frame)
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
    cmp #$B5
    bcc in_air

    lda #$B5
    sta player_y

    lda #0
    sta player_vy
in_air:


; -------------------------
; SPRITE
; -------------------------
    ldx #0
    head_sprite_load:
        txa
        asl a
        asl a
        tay        ; Y = X * 4 (OAM offset)

        ; Y position
        lda player_y
        sta oam, y

        ; tile
        txa
        sta oam+1, y

        ; properties
        lda #%00000000
        sta oam+2, y

        ; x-position

        txa
        asl
        asl
        asl
        clc
        adc player_x
        sta oam+3, y

        inx
        cpx #2
        bne head_sprite_load
    
    ldx #0
    body_sprite_load:
        txa
        asl a
        asl a
        tay        ; Y = X * 4 (OAM offset)

        ; Y position
        lda player_y
        clc
        adc #8
        sta oam+8, y

        ; tile
        txa
        clc
        adc sprite_offset
        clc
        adc #$10
        sta oam+9, y

        ; properties
        lda #%00000001
        sta oam+10, y

        ; x-position

        txa
        asl
        asl
        asl
        clc
        adc player_x
        sta oam+11, y

        inx
        cpx #2
        bne body_sprite_load


    jmp forever


; =========================
; VECTORS
; =========================
.segment "VECTORS"

.addr nmi
.addr reset
.addr 0


; =========================
; NAMETABLE DATA
; =========================
.segment "RODATA"

nametable:
.incbin "nametable.nam"


; =========================
; CHR
; =========================
.segment "CHARS"

.incbin "graphics.chr"