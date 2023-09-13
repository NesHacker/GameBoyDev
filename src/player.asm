INCLUDE "game.inc"
INCLUDE "hardware.inc"

; Player state when the character is idle.
DEF STATE_IDLE EQU 0

; Player state when the chatacter is walking.
DEF STATE_WALKING EQU 1

; Player state when the character is running (similar to P-speed in SMB3)
DEF STATE_RUNNING EQU 2

; Player state when the character is pivoting while changing directions on the
; ground.
DEF STATE_PIVOT EQU 3

; Player state when the character is jumping or falling.
DEF STATE_AIRBORNE EQU 4

; Represent the player facing right on the screen.
DEF HEADING_RIGHT EQU 0

; Represents the player facing the left on the screen.
DEF HEADING_LEFT EQU 1

; The state of the player (idle, running, airborne, etc.)
DEF b_playerState EQU $CC00

; The direction the player is facing.
DEF b_playerHeading EQU $CC01

; The player's horizontal position in world coordinates.
DEF f_playerX EQU $CC02

; THe player's current velocity as an 8.8 fixed point value.
DEF f_playerVelocityX EQU $CC04

; The player's desired velocity as an 8.8 fixed point value.
DEF f_targetVelocityX EQU $CC06

; The player's vertical postion in world coordinates.
DEF f_playerY EQU $CC08

; The player's vertical velocity as an 8.8 fixed point value.
DEF f_playerVelocityY EQU $CC0A

; X-coordinate for the player's sprite.
DEF b_spriteX           EQU $CC0C

; Y-coordinate for the player's sprite.
DEF b_spriteY           EQU $CC0D

SECTION "Player", ROM0

; ------------------------------------------------------------------------------
; `func InitializePlayer()`
;
; Initializes the state for the player and sets up sprites for rendering the
; character.
; ------------------------------------------------------------------------------
InitializePlayer::
  DEF INITIAL_Y EQU 96
  DEF INITIAL_X EQU 28

  ld hl, ary_SpriteOAM

  ld a, INITIAL_Y
  ld [hli], a
  ld a, INITIAL_X
  ld [hli], a
  ld a, $20
  ld [hli], a
  ld a, 0
  ld [hli], a

  ld a, INITIAL_Y
  ld [hli], a
  ld a, INITIAL_X + 8
  ld [hli], a
  ld a, $22
  ld [hli], a
  ld a, 0
  ld [hli], a

  ret

; ------------------------------------------------------------------------------
; `func UpdatePlayer()`
;
; Called every frame to update the player state (e.g. position, velcoity, etc.)
; based on button input and world state.
; ------------------------------------------------------------------------------
UpdatePlayer::
  ret
