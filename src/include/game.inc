; ------------------------------------------------------------------------------
; `macro WaitForVblank()`
;
; Loops until the LCD enters the vertical blanking period.
; ------------------------------------------------------------------------------
MACRO WaitForVblank
: ld a, [rLY]
  cp a, 144
  jr c, :-
ENDM

; ------------------------------------------------------------------------------
; `macro WaitForVblankEnd()`
;
; Loops until the LCD exits the vertical blanking period.
; ------------------------------------------------------------------------------
MACRO WaitForVblankEnd
: ld a, [rLY]
  cp 144
  jr nc, :-
ENDM

; ------------------------------------------------------------------------------
; `func DMATransfer()`
;
; Transfers sprites from WRAM to VRAM using the DMA.
; ------------------------------------------------------------------------------
DEF DMATransfer EQU $FF80

; ------------------------------------------------------------------------------
; WRAM Variable Locations
; ------------------------------------------------------------------------------

; Bitfield that stores current buttons being pressed on the Game Boy's joypad.
;
; - Bit 0 (`BUTTON_RIGHT`) - Right D-PAD
; - Bit 1 (`BUTTON_LEFT`) - Left D-PAD
; - Bit 2 (`BUTTON_LEFT`) - Up D-PAD
; - Bit 3 (`BUTTON_LEFT`) - Down D-PAD
; - Bit 4 (`BUTTON_A`) - A
; - Bit 5 (`BUTTON_B`) - B
; - Bit 6 (`BUTTON_SELECT`) - Select
; - Bit 7 (`BUTTON_START`) - Start
DEF b_JoypadDown EQU $C020

; Bitfield that stores the buttons that were pressed as of the last joypad read.
;
; - Bit 0 (`BUTTON_RIGHT`) - Right D-PAD
; - Bit 1 (`BUTTON_LEFT`) - Left D-PAD
; - Bit 2 (`BUTTON_LEFT`) - Up D-PAD
; - Bit 3 (`BUTTON_LEFT`) - Down D-PAD
; - Bit 4 (`BUTTON_A`) - A
; - Bit 5 (`BUTTON_B`) - B
; - Bit 6 (`BUTTON_SELECT`) - Select
; - Bit 7 (`BUTTON_START`) - Start
DEF b_JoypadPressed EQU $C021

; Button mask for the right D-PAD button.
DEF BUTTON_RIGHT  EQU 1 << 0

; Button mask for the left D-PAD button.
DEF BUTTON_LEFT   EQU 1 << 1

; Button mask for the up D-PAD button.
DEF BUTTON_UP     EQU 1 << 2

; Button mask for the down D-PAD button.
DEF BUTTON_DOWN   EQU 1 << 3

; Button mask for the A button.
DEF BUTTON_A      EQU 1 << 4

; Button mask for the B button.
DEF BUTTON_B      EQU 1 << 5

; Button mask for the select button.
DEF BUTTON_SELECT EQU 1 << 6

; Button mask for the start button.
DEF BUTTON_START  EQU 1 << 7

; Timer used for the common background tile animator.
DEF b_BgTimer EQU $C080

; Delay in system frames to delay between background animation frames.
DEF BgDelay EQU 18

; WRAM location for Object (Sprite) OAM data that is transferred to VRAM via DMA
; at the end of each frame during the VBLANK period.
DEF ary_SpriteOAM EQU $C100

; Length of the OAM data region, in bytes.
DEF len_SpriteOAM EQU 160

; Array that holds the VRAM addresses for all onigiri sprites in the background.
; This is used to update those sprites when performing background animation.
DEF ary_Onigiri EQU $C300

; WRAM copy of the level data that is used to handle game mechanics and events.
DEF ary_LevelData EQU $D000

; ------------------------------------------------------------------------------
; Data constants
; ------------------------------------------------------------------------------

; Number of bytes in the tileset for the game.
len_Tileset EQU 6144

; Number of bytes in the level's tilemap.
len_LevelTilemap EQU 1024

; Number of bytes int the level data.
len_LevelData EQU 1024
