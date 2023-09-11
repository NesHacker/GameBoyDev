INCLUDE "hardware.inc"
INCLUDE "joypad.inc"

DEF mask_JoypadDown EQU $C020
DEF mask_JoypadPressed EQU $C021

DEF i_BgTimer EQU $C080
DEF i_BgFrame EQU $C081
DEF BgDelay EQU 18

DEF ary_SpriteOAM EQU $C100
DEF len_SpriteOAM EQU 160

DEF ary_Onigiri EQU $C300

DEF ary_LevelData EQU $D000

SECTION "Header", ROM0[$100]
  jp Main
  ds $150 - @, 0  ; Header space. RGBFIX requires that it be zero filled.

SECTION "Main", ROM0

; ------------------------------------------------------------------------------
; `func Main()`
;
; Main function for the game. Loads data, initializes RAM, and then enters the
; main game loop.
; ------------------------------------------------------------------------------
Main:
  call SetupGame
.loop
  ld a, [rLY]
  cp 144
  jp nc, .loop
.vblank_wait
  ld a, [rLY]
  cp 144
  jp c, .vblank_wait
  call GameLoop
  jp .loop
GameLoop:
  call AnimateBackground
  call ReadJoypad
  ret

; ------------------------------------------------------------------------------
; `func AnimateBg()`
;
; Handles timing and updates for background animations.
; ------------------------------------------------------------------------------
AnimateBackground:
  ld a, [i_BgTimer]
  dec a
  ld [i_BgTimer], a
  jp nz, .skip
  ld a, BgDelay
  ld [i_BgTimer], a
  ld a, [i_BgFrame]
  xor 1
  ld [i_BgFrame], a
  call UpdateOnigiriSprites
.skip
  ret

; ------------------------------------------------------------------------------
; `func UpdateOnigiriSprites`
;
; Animates the onigiri sprites in the background by swapping between the two
; tilesets.
; ------------------------------------------------------------------------------
UpdateOnigiriSprites:
  ld hl, ary_Onigiri
.update_loop
  ld a, [hli]
  or 0
  jr z, .return
  ld d, a
  ld a, [hli]
  ld e, a
  ld a, [de]
  ; This math below looks complex but what it's basically doing is swapping
  ; C <-> E and D <-> F in the low nibble of the tile value. This works out
  ; tiles for each of the frames are two positions away from one another either
  ; direction. This is basically just a bitwise op way to handle an add two and
  ; mod by 4.
  and $0F
  sub $0C
  add 2
  and $03
  add $0C
  ld b, a
  ld a, [de]
  and $F0
  or b
  ld [de], a
  jr .update_loop
.return
  ret

ReadJoypad:
  ; Read the "down" mask from the last frame
  ld a, [mask_JoypadDown]
  ld c, a
  ; Read the current controller buttons and store them into the "down" mask
  ld a, $20
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]
  and $0F
  ld b, a
  ld a, $10
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  sla a
  sla a
  sla a
  sla a
  or b
  xor $FF
  ld [mask_JoypadDown], a
  ; Update the "just pressed" mask
  ld b, a
  ld a, c
  xor b
  and b
  ld [mask_JoypadPressed], a
  ret

SECTION "Setup", ROM0

; ------------------------------------------------------------------------------
; `func SetupGame()`
;
; Initializes various RAM and register locations prior to game start.
; ------------------------------------------------------------------------------
SetupGame:
  ; Disable audio, wait for a VBLANK, and turn off the LCD
  ld a, 0
  ld [rNR52], a
: ld a, [rLY]
  cp a, 144
  jp c, :-
  ld a, 0
  ld [rLCDC], a

  ; Clear WRAM
  ld bc, $2000
  ld hl, $C000
.clear_loop
  ld a, 0
  ld [hli], a
  dec bc
  ld a, b
  or a, c
  jr nz, .clear_loop

  ; Load the DMA Transfer Routine
  call LoadDMARoutine

  ; Load all level related data
  call LoadLevelData

  ; Intialize the two frame animator for onigiri sprites
  ld a, BgDelay
  ld [i_BgTimer], a
  ld a, 0
  ld [i_BgFrame], a

  ; Clear the Sprite OAM data
  ld a, 0
  ld b, len_SpriteOAM
  ld hl, ary_SpriteOAM
.sprite_clear_loop
  ld [hli], a
  dec b
  jr nz, .sprite_clear_loop

  ; Transfer the sprite data using DMA
  call DMATransfer

  ; Initialize the screen position
  ld a, 112
  ld [rSCY], a

  ; Turn the LCD back on and initialize display registers
  ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_OBJ16
  ld [rLCDC], a
  ld a, %11100100
  ld [rBGP], a
  ld [rOBP0], a
  ld [rOBP1], a
  ret

; ------------------------------------------------------------------------------
; `func LoadData(bc, de, hl)`
;
; This function loads data directly from the ROM into RAM using three 16-bit
; registers:
;
; - `bc` - The number of bytes to load
; - `de` - The start address for retrieving the bytes from the ROM
; - `hl` - The start address for storing the bytes in RAM
; ------------------------------------------------------------------------------
LoadData:
  ld a, [de]
  ld [hli], a
  inc de
  dec bc
  ld a, b
  or a, c
  jp nz, LoadData
  ret

; ------------------------------------------------------------------------------
; `func LoadLevelData()`
;
; Copies level data from the ROM into working and video RAM.
; ------------------------------------------------------------------------------
LoadLevelData:
  ld bc, len_Tileset
  ld de, Tileset
  ld hl, $8000
  call LoadData
  ld bc, len_LevelTilemap
  ld de, LevelTilemap
  ld hl, $9800
  call LoadData
  ld bc, len_LevelData
  ld de, LevelData
  ld hl, ary_LevelData
  call LoadData
  call FindOnigiri
  ret

; ------------------------------------------------------------------------------
; `func FindOnigiri()`
;
; Finds the addresses for all background tiles that depict onigiri so they can
; be animated quickly in the main game loop. Normally this list would be
; compiled into the level data prior, but I am just doing something simple here.
; ------------------------------------------------------------------------------
FindOnigiri:
  ld bc, $9800
  ld de, LevelData
  ld hl, ary_Onigiri
.loop
  ld a, [de]
  cp a, 5
  jr nz, .skip
  ld a, b
  ld [hli], a
  ld a, c
  ld [hli], a
.skip
  inc de
  inc bc
  ld a, d
  cp a, HIGH(LevelData + len_LevelData)
  jr nz, .loop
  ld a, e
  cp a, LOW(LevelData + len_LevelData)
  jr nz, .loop
  ret

; ------------------------------------------------------------------------------
; `func DMATransfer()`
;
; Transfers sprites from WRAM to VRAM using the DMA.
; ------------------------------------------------------------------------------
DEF DMATransfer EQU $FF80

; ------------------------------------------------------------------------------
; `func LoadDMARoutine()`
;
; Loads the DMA transfer routine into memory starting at address $FF80. For
; more information see the explanation in the documentation for the
; `DMATransferRoutine` function below.
; ------------------------------------------------------------------------------
LoadDMARoutine:
  ld b, DMATransferRoutineEnd - DMATransferRoutine
  ld de, DMATransferRoutine
  ld hl, DMATransfer
.load_loop
  ld a, [de]
  inc de
  ld [hli], a
  dec b
  jr nz, .load_loop
  ret

; ------------------------------------------------------------------------------
; `func DMATransferRoutine()`
;
; This is the DMA transfer routine used to quickly copy sprite object data from
; working RAM to video RAM.
;
; **IMPORTANT:** This routine should not be called directly, in order to prevent
; bus conflicts the Game Boy only executes instructions between $FF80-$FFFE
; during a DMA transfer. As such this routine is copied to that memory region
; and you should call it using the `DMATransfer` routine label instead.
; ------------------------------------------------------------------------------
DMATransferRoutine:
  di
  ld a, $C1
  ld [rDMA], a
  ld a, 40
.wait_loop
  dec a
  jr nz, .wait_loop
  ei
  ret
DMATransferRoutineEnd:

SECTION "Tile data", ROM0

; ------------------------------------------------------------------------------
; `binary data Tileset`
;
; This is the tileset data for the game. Since it is just a demo, I was able to
; fit all the graphics I need into the GameBoy's 6144 byte character RAM region.
; Bigger games will need to swap out graphics during runtime based on what needs
; to be rendered at a given time.
; ------------------------------------------------------------------------------
Tileset: INCBIN "tileset.gb"
len_Tileset EQU 6144

; ------------------------------------------------------------------------------
; `binary data LevelTilemap`
;
; This is the 32 x 32 tile data for the background tiles representing the game's
; level. For this project I kept things simple by using the binary tilemap data
; directly. In more advanced projects one would have much larger runs of data
; representing levels and use an encoding scheme (e.g. run-length encoding) to
; minimize ROM data usage.
; ------------------------------------------------------------------------------
LevelTilemap: INCBIN "level.tilemap"
len_LevelTilemap EQU 1024

; ------------------------------------------------------------------------------
; `binary data LevelData`
;
; This contains the data that detemines how each tile in the level acts in terms
; of gameplay. For the demo there are eight types of tiles:
;
; - `0`: open space
; - `1`: obstruction (ground, pips, unbreakable blocks, etc.)
; - `2`: platform top
; - `3`: pipe top
; - `4`: breakable bricks
; - `5`: onigiri
; - `6`: coins
; - `7`: switch blocks
; ------------------------------------------------------------------------------
LevelData: INCBIN "level-data.tilemap"
len_LevelData EQU 1024
