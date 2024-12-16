.INCLUDE "src/Header.inc"
.INCLUDE "src/SnesInit.asm"
.INCLUDE "src/struct.inc"
.INCLUDE "src/sounds.asm"

; Hardware Registers.
.DEFINE SCREEN_DISPLAY_REGISTER $2100
.DEFINE OAM $2101
.DEFINE OAM_ADDR $2102
.DEFINE OAM_WRITE $2104
.DEFINE BG_MODE $2105
.DEFINE BG_1_ADDR $2107
.DEFINE BG_12_TILE $210b
.DEFINE BG_1_H_SCROLL $210d
.DEFINE BG_1_V_SCROLL $210e
.DEFINE VRAM_INCREMENT $2115
.DEFINE VRAM_ADDR $2116
.DEFINE VRAM_WRITE $2118
.DEFINE CGRAM_ADDR $2121
.DEFINE CGRAM_DATA $2122
.DEFINE MAIN_SCREEN_PARAM $212c
.DEFINE NMI_AND_STUFF $4200
.DEFINE DMA_ENABLE $420b
.DEFINE DMA_PARAM $4300
.DEFINE DMA_B_ADDR $4301
.DEFINE DMA_A_ADDR $4302
.DEFINE DMA_A_BANK $4304
.DEFINE DMA_N $4305

; Vram Locations
.DEFINE MAP_A $4000

; Binary includes
Tiles: .INCBIN "bin/tiles.bin" FSIZE TILES_SIZE
Palette: .INCBIN "bin/tiles.dat" FSIZE PALETTE_SIZE

; Data Registers.
Sin: .DBSIN 0, 63, 5.625, 128, 0

.RAMSECTION "variables" BANK 0 SLOT 1
    sprites INSTANCEOF Sprite 128
    firstDeadSprite DW
    clock DW
    ballPos INSTANCEOF Vector
    ballVel INSTANCEOF Vector
.ENDS

; Makes A 16 bit.
.MACRO A16
    rep #$20
.ENDM

; Makes A 8 bit.
.MACRO A8
    sep #$20
.ENDM

; Makes X,Y 16 bit.
.MACRO Index16
    rep #$10
.ENDM

; Makes X,Y 8 bit.
.MACRO Index8
    sep #$10
.ENDM

; Uses the A register to write a value to somewhere. The value has gotta be a normal value not a memory address or
; something because I have to hard code that fact for some reason.
; TODO: if I use a 1 byte value but the register is in 2 byte mode, does it work right? what should it do?
.MACRO PutA ARGS VALUE, ADDR
    lda #VALUE
    sta ADDR.w
.ENDM

; Uses the Y register to write a value somewhere. The value has gotta be normal.
.MACRO PutY ARGS VALUE, ADDR
    ldy #VALUE
    sty ADDR
.ENDM

; Uses the X register to write a value somewhere. The value has gotta be normal.
.MACRO PutX ARGS VALUE, ADDR
    ldx #VALUE
    stx ADDR
.ENDM

; Transfers data with DMA to somewhere.
; A8  X, Y16 X
; LABEL is the label at which you can find the data.
; OFFSET is the low byte of where to write (high byte being $21).
; SIZE is the amount of data to transfer.
; PARAM is the value to set DMA_PARAM to.
.MACRO Transfer ARGS LABEL, OFFSET, SIZE, PARAM
    PutY SIZE, DMA_N                ; Set amount of data to transfer.
    PutY LABEL, DMA_A_ADDR          ; Set DMA read memory address.
    PutA :LABEL, DMA_A_BANK         ; Set DMA read memory bank.
    PutA PARAM, DMA_PARAM           ; Set DMA transfer params.
    PutA OFFSET, DMA_B_ADDR         ; Set DMA write address to byte in $21 range.
    PutA 1, DMA_ENABLE              ; Enable DMA channel 1.
.ENDM

; Loads a palette into cgram using DMA.
; A8 X, Y16 X
; LABEL is the label where the palette data is.
; WRITE_ADDRESS is where to write the data in cgram.
; SIZE is the number of bytes of data we are working with.
.MACRO SetPalette ARGS LABEL, WRITE_ADDR, SIZE
    PutA WRITE_ADDR, CGRAM_ADDR     ; Set CGRAM write location.
    Transfer LABEL, $22, SIZE, 0    ; Start the transfer.
.ENDM

; macro that writes a bunch of tile data into vram using DMA.
; A8 X, Y16 X
.MACRO LoadVRAM ARGS LABEL, WRITE_ADDR, SIZE
    PutA $80, VRAM_INCREMENT        ; Make vram write increment 128 bytes.
    PutY WRITE_ADDR, VRAM_ADDR      ; Set the vram write location.
    Transfer LABEL, $18, SIZE, 1    ; Start the transfer.
.ENDM

; Sets up the map with some crappy test data.
; A8 X, X16 X
.MACRO ConfigureMap
    PutA %11110001, BG_MODE
    PutA (((MAP_A >> 9 & 0xfc) | %01) & $ff), BG_1_ADDR
    PutA %00000000, BG_12_TILE
    PutA 0 BG_1_H_SCROLL
    PutA 0 BG_1_V_SCROLL
    PutA 0, VRAM_INCREMENT
    PutX MAP_A >> 1, VRAM_ADDR
    A16
    ldx #0
    - txa
    and #$f
    sta VRAM_WRITE
    inx
    inx
    cpx #(64 * 32)
    bne -
    A8
.ENDM

; Sets up a crappy test sprite.
; A8 X, X16 X
.MACRO ConfigureSprite
    ldx #0
    - stz sprites, X
    inx
    cpx #_sizeof_sprites
    bne -
    PutA #%10001, MAIN_SCREEN_PARAM      ; Turn on sprites and bg 1.
    PutA #100, sprites.1.pos.y.b
    PutA #0, sprites.1.tile.b
    PutA #%00110000, sprites.1.param.b
    PutY #$100, OAM_ADDR                 ; write to address 0 high table.
    PutA #%00000010, OAM_WRITE           ; give sprite 1 big size.
.ENDM

; Takes the low byte from A and turns it into sin(A) where you can imagine that
; A is divided by 256 and then multiplied by 360. Also the resulting value is
; between -128 and 128 rather than between -1 and 1. The return value stays in A
; and A, X, and Y are all set to 8 bit mode.
.MACRO GetSin
    Index8
    A8
    and #$ff
    lsr           ; we shift right twice because there are only 64 values.
    lsr
    tax
    lda Sin.w, X
.ENDM

; Called on Vblank. Right now it transfers all the sprites into the sprite
; memory thing. This is kinda necessary because we need to upload dead sprites
; too so that it knows not to render them. Anyway as far as I can tell
; performance is fine and we are already transferring all these sprites so that
; is cool as far as I am concerned.
VBlank:
    phy
    php                                         ; Save register config.
    Index16
    PutY 0, OAM_ADDR
    Transfer sprites, $04, _sizeof_sprites, 0
    plp                                         ; restore register config.
    ply
    rti

.bank 0
.section "MainCode"

; Called when the program starts. Can do whatever the hell it wants with the registers of course.
Start:
    SnesInit                                ; Initialize the SNES.
    A8                                      ; Set A to 8 bit and XY to 16.
    Index16
    SetPalette Palette, 0, PALETTE_SIZE
    LoadVRAM Tiles, 0, TILES_SIZE
    ConfigureMap
    ConfigureSprite
    PutA $0f, SCREEN_DISPLAY_REGISTER       ; Turn on screen.
    PutA $80, NMI_AND_STUFF                 ; turn on nmi.
    cli                                     ; Enable Interrupts. 
    ldx #0                                  ; Init X to 0.
    -
    A16
    inc clock.w
    lda clock.w
    GetSin
    sta sprites.1.pos.x.b
    wai                                     ; Then loop eternally.
    jmp -

.ends
