INCLUDE "hardware.inc"

; Address for the first byte of level data in RAM
DEF ary_LevelData EQU $D000

SECTION "Header", ROM0[$100]
	jp Main
	ds $150 - @, 0	; Header space. RGBFIX requires that it be zero filled.

SECTION "Main", ROM0
; ------------------------------------------------------------------------------
; `func Main()`
;
; Main function for the game. Loads data, initializes RAM, and then enters the
; main game loop.
; ------------------------------------------------------------------------------
Main:
	call SetupGame
.gameloop
	jp .gameloop

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

	; Load all level related data
	call LoadLevelData

	; Initialize the screen position
	ld a, 112
	ld [rSCY], a

	; Turn the LCD back on and initialize display registers
	ld a, LCDCF_ON | LCDCF_BGON
	ld [rLCDC], a
	ld a, %11100100
	ld [rBGP], a
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
	ret

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
