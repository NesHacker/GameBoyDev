INCLUDE "game.inc"
INCLUDE "hardware.inc"

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

; ------------------------------------------------------------------------------
; `func GameLoop()`
;
; The main loop for the game that handles all logic and rendering.
; ------------------------------------------------------------------------------
GameLoop:
  WaitForVblank
  call ReadJoypad
  call UpdatePlayer
  call AnimateBackground
  ; call FreeMoveCamera

  call DMATransfer
  WaitForVblankEnd
  jp GameLoop

; ------------------------------------------------------------------------------
; `func SetupGame()`
;
; Initializes various RAM and register locations prior to game start.
; ------------------------------------------------------------------------------
SetupGame:
  ; Disable audio (no music for this game, sorry!)
  ld a, 0
  ld [rNR52], a
  ; Disable the LCD
  WaitForVblank
  ld a, 0
  ld [rLCDC], a
  ; Call various initialization routines
  call ClearWRAM
  call WriteDMARoutine
  call LoadLevel
  call InitializePlayer

  ; Transfer the sprite data using DMA
  call DMATransfer

  ; Initialize the background and sprite palettes
  ld a, %11100100
  ld [rBGP], a
  ld [rOBP0], a
  ld [rOBP1], a
  ; Set up the LCD and start rendering
  ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_OBJ16
  ld [rLCDC], a
  ret

; ------------------------------------------------------------------------------
; `func ClearWRAM()`
;
; Clears all working RAM from `$C000` through `$DFFF` by setting each byte to 0.
; ------------------------------------------------------------------------------
ClearWRAM:
  ld bc, $2000
  ld hl, $C000
.clear_loop
  ld a, 0
  ld [hli], a
  dec bc
  ld a, b
  or a, c
  jr nz, .clear_loop
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
LoadData::
  ld a, [de]
  ld [hli], a
  inc de
  dec bc
  ld a, b
  or a, c
  jp nz, LoadData
  ret

; ------------------------------------------------------------------------------
; `func WriteDMARoutine()`
;
; Writes the DMA transfer routine into memory starting at address $FF80. For
; more information see the explanation in the documentation for the
; `DMATransferRoutine` function below.
; ------------------------------------------------------------------------------
WriteDMARoutine:
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
