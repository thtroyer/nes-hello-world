.setcpu "6502"
.MACPACK ca65_generic
.MACPACK ca65_longbranch

PPU_CTRL1 = $2000
PPU_CTRL2 = $2001
PPU_STATUS = $2002
PPU_SPR_ADDR = $2003
PPU_SPR_IO = $2004
PPU_VRAM_ADDR1 = $2005
PPU_VRAM_ADDR2 = $2006
PPU_VRAM_IO = $2007
PPU_OAM_DMA = $4014

CONTROLLER_PORT1 = $4016
CONTROLLER_PORT2 = $4017

CRTL2_GRAYSCALE = 1 ; #%00000001
CRTL2_DISABLE_LEFT_BG_CLIP = 2 ; #%00000010
CRTL2_DISABLE_LEFT_SPR_CLIP = 4 ; #%00000100
CRTL2_BACKGROUND_RENDER = 8 ; #%00001000
CRTL2_SPRITE_RENDER = 16 ; #%00010000
CRTL2_INTENSE_RED = 32 ; #%00100000
CRTL2_INTENSE_GREEN = 64 ; #%01000000
CRTL2_INTENSE_BLUE = 128 ; #%10000000

CRTL1_NMI_ENABLED = 128 ; #%10000000
CRTL1_SPRITES_8x16 = 32 ; #%00100000
CRTL1_BG_PT_ADDR_1 = 16 ; #%00010000
CRTL1_SP_PT_ADDR_1 = 8 ; #%00001000
CRTL1_VRAM_INC =  4 ; #%00000100
CRTL1_BASE_NAMETABLE_2000 = 0 ; #%00000000
CRTL1_BASE_NAMETABLE_2400 = 1 ; #%00000001
CRTL1_BASE_NAMETABLE_2800 = 2 ; #%00000010
CRTL1_BASE_NAMETABLE_2C00 = 3 ; #%00000011

.segment "HEADER"
.byte "NES", $1a
.byte 1 ; PRG-ROM pages (16kb)
.byte $01 ; CHR-ROM pages (8kb)


; Zero page RAM
.segment "ZEROPAGE"
a_latch: .res 1
sprite_x: .res 1
sprite_y: .res 1
controller1: .res 1
pointerHigh: .res 1
pointerLow: .res 1
isInvisible: .res 1

; General RAM
;.segment "BSS"


.segment "CODE"

ReadController:
  lda #$01
  sta CONTROLLER_PORT1 
  lda #$00
  sta CONTROLLER_PORT1 
  ldx #$08

@ReadControllerLoop:
  lda CONTROLLER_PORT1 
  ; use bit shifting to pull lowest bit from controller and put into buttons
  lsr A
  rol controller1
  dex
  bne @ReadControllerLoop
  rts

MoveSpritesUp:
  dec sprite_y
  rts
MoveSpritesDown:
  inc sprite_y
  rts
MoveSpritesLeft:
  dec sprite_x
  rts
MoveSpritesRight:
  inc sprite_x
  rts
ToggleInvisibility:
  lda a_latch
  cmp #01
  beq @Done

  lda #01
  sta a_latch

  lda isInvisible
  cmp #01
  beq @ResetInv
  lda #01
  sta isInvisible
  jmp @Done
@ResetInv:
  lda #00
  sta isInvisible
@Done:
  rts

SetSpritePositions:
  ; sprite data is set up in address space $0200-? and then copied to the PPU later (using OAMDMA register $4014)
  ; See PPU OAM
  ; sprite positions relative to x and y
  lda isInvisible
  cmp #01
  beq @Else

  ; "HELLO" y coord
  lda sprite_y
  sta $0200
  sta $0204
  sta $0208
  sta $020C
  sta $0210
  ; place "WORLD" on another row
  adc #$08
  sta $0214
  sta $0218
  sta $021C
  sta $0220
  sta $0224
  sta $0228

  ; X coordinates for "HELLO WORLD", ofsetting each char and wrapping after O
  clc
  lda sprite_x
  sta $0203
  adc #$08
  sta $0207
  adc #$08
  sta $020B
  adc #$08
  sta $020F
  adc #$08
  sta $0213

  lda sprite_x
  sta $0217
  adc #$08
  sta $021B
  adc #$08
  sta $021F
  adc #$08
  sta $0223
  adc #$08
  sta $0227
  adc #$08
  sta $022B

  jmp @Return
@Else:
  ; todo: update
  lda #$FF
  sta $0200
  sta $0204
  sta $0208
  lda #$FF
  sta $0203
  clc
  adc #$08
  sta $0207
  adc #$08
  sta $020B

@Return:
  rts

SetUpVariables:
  lda #$00
  sta isInvisible
  rts

CopySpritesToPpu:
  ;; copy sprites back to PPU as the PPU forgets them every cycle.
  ; write address $0200 to PPU for DMA sprite transfer

  lda #$00
  sta PPU_SPR_ADDR
  lda #$02
  sta PPU_OAM_DMA 
  rts

HandleControllerInput:
  jsr ReadController

  ;button bit order:
  ; A B select start up down left right
  lda controller1
  and #%00001000
  cmp #%00001000
  bne @SkipUp
  jsr MoveSpritesUp
@SkipUp:

  lda controller1
  and #%00000100
  cmp #%00000100
  bne @SkipDown
  jsr MoveSpritesDown
@SkipDown:

  lda controller1
  and #%00000010
  cmp #%00000010
  bne @SkipLeft
  jsr MoveSpritesLeft
@SkipLeft:

  lda controller1
  and #%00000001
  cmp #%00000001
  bne @SkipRight
  jsr MoveSpritesRight
@SkipRight:

  lda controller1
  and #%10000000
  cmp #%10000000
  jne @SkipA 
  jsr ToggleInvisibility
  jmp @DoneA
@SkipA:
  lda #00
  sta a_latch

@DoneA:
  rts

VBlankCycle:
  lda PPU_STATUS 
  bpl VBlankCycle
  rts


ResetHandler:
  sei
  cld
  .repeat 3
  jsr VBlankCycle
  .endrep

  lda #$80
  sta sprite_x
  sta sprite_y

LoadPalettes:
  lda PPU_STATUS 
  lda #$3F
  sta PPU_VRAM_ADDR2 
  lda #$00
  sta PPU_VRAM_ADDR2 

  ldx #$00
@LoadPalettesLoop:
  lda Palettes, x
  sta PPU_VRAM_IO 
  inx
  ; 32 bytes (0x20)
  cpx #$20
  bne @LoadPalettesLoop

LoadSprites:
  ldx #$00
@LoadSpritesLoop:
  lda Sprites, x
  sta $0200, x
  inx
  cpx #$40 ; todo make sure this is big enough to fix all sprites
  bne @LoadSpritesLoop

LoadBackground:
  lda PPU_STATUS
  lda #$20
  sta $2006
  lda #$00
  sta $2006

  lda #>Background
  sta pointerLow
  lda #<Background 
  sta pointerHigh

; Need to copy 930 (0x3A2) bytes to PPU
; 3*255(0xFF) with 165 (0xA5) remainder
  ldx #$00
@OUTER_LOOP:
  cpx #$03
  bcs @LAST_LOOP
  ldy #$00
@INNER_LOOP:
  lda (pointerHigh), Y
  sta PPU_VRAM_IO 
  iny
  bne @INNER_LOOP
  inx
  inc pointerLow
  jmp @OUTER_LOOP
@LAST_LOOP:
  lda (pointerHigh), Y
  sta PPU_VRAM_IO 
  iny
  cpy #$A5
  bcc @LAST_LOOP

PPU_SETUP:
  ;; Still can't get these to work correctly yet.
  ;; I must be misunderstanding how constants are used in CA65
  ;lda #%00000000
  ;ora CRTL1_NMI_ENABLED
  ;;ora CRTL1_SPRITES_8x16
  ;ora CRTL1_BG_PT_ADDR_1
  ;;ora CRTL1_SP_PT_ADDR_1
  ;;ora CRTL1_VRAM_INC
  ;;ora CRTL1_BASE_NAMETABLE_2000
  ;;ora CRTL1_BASE_NAMETABLE_2400
  ;;ora CRTL1_BASE_NAMETABLE_2800
  ;;ora CRTL1_BASE_NAMETABLE_2C00
  lda #%10010000
  sta PPU_CTRL1 

EnableSprites:
  ;lda #%00000000
  ;;ora CRTL2_GRAYSCALE
  ;ora CRTL2_DISABLE_LEFT_BG_CLIP
  ;ora CRTL2_DISABLE_LEFT_SPR_CLIP
  ;ora CRTL2_BACKGROUND_RENDER
  ;ora CRTL2_SPRITE_RENDER
  ;;ora CRTL2_INTENSE_RED
  ;;ora CRTL2_INTENSE_GREEN
  ;;ora CRTL2_INTENSE_BLUE
  ;;lda #%00011110
  ;sta PPU_CTRL2 
  ;rts
  lda #%00011110
  sta PPU_CTRL2

GameLoop:
  jmp GameLoop

VBlankHandler:
  jsr HandleControllerInput
  jsr SetSpritePositions
  ;jsr SetUpVariables
  jsr CopySpritesToPpu

  lda #%10010000
  sta PPU_CTRL1 
  lda #%10010000
  sta PPU_CTRL1 

  lda #%00011110
  sta PPU_CTRL2

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  ;lda #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ;sta PPU_CTRL1 
  ;lda #%00011110   ; enable sprites, enable background, no clipping on left side
  ;sta PPU_CTRL2
  lda #$00        ;;tell the ppu there is no background scrolling
  sta PPU_VRAM_ADDR1 
  sta PPU_VRAM_ADDR1 

  rti

Background:
  ; These are references to tiles in hello.chr
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$40,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31,$41,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$30,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$32,$10
  .byte $10,$43,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$42,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10

attribute:
  ; PPU attribute table, for applying palettes to background.
  ; reference here: https://wiki.nesdev.com/w/index.php/PPU_attribute_tables
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55

Palettes:
  ; each palette consists of 4 bytes, starting with $0F (transparent)
  ; colors are defined in the PPU and are looked up by bytes. No RGB here.

  ; 4 background palettes, referenced in PPU attribute table ?
  .byte $0F,$2D,$3D,$30
  .byte $0F,$2D,$3D,$30
  .byte $0F,$2D,$3D,$30
  .byte $0F,$2D,$3D,$30

  ; 4 sprite palettes, referenced below in sprite attribute column
  .byte $0F,$0A,$0F,$19
  .byte $0F,$02,$0F,$12
  .byte $0F,$2D,$0F,$20
  .byte $0F,$02,$0F,$3C

Sprites:
  ; Sprite data (how many can I put here?)
  ; Y coord (vertical), tile selection, attribute (palette), X coordinate (horizontal)
  .byte $00, $00, $00, $00 ; H sprite
  .byte $00, $01, $00, $00 ; E sprite
  .byte $00, $02, $00, $00 ; L sprite
  .byte $00, $02, $00, $00 ; L sprite
  .byte $00, $03, $00, $00 ; O sprite

  .byte $00, $10, $01, $00 ; W sprite
  .byte $00, $03, $01, $00 ; O sprite
  .byte $00, $11, $01, $00 ; R sprite
  .byte $00, $02, $01, $00 ; L sprite
  .byte $00, $12, $01, $00 ; D sprite
  .byte $00, $13, $02, $00 ; ! sprite

.segment "VECTORS"
.word VBlankHandler, ResetHandler

.segment "CHRROM"
.incbin "hello.chr"
