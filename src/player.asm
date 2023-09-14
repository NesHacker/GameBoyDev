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

; The player's horizontal position in world coordinates (12.4 fixed point).
DEF f_playerX EQU $CC02

; THe player's current velocity as an 4.4 fixed point value.
DEF f_playerVelocityX EQU $CC04

; The player's desired velocity as an 4.4 fixed point value.
DEF f_targetVelocityX EQU $CC05

; The player's vertical postion in world coordinates (12.4 fixed point).
DEF f_playerY EQU $CC06

; The player's vertical velocity as an 4.4 fixed point value.
DEF f_playerVelocityY EQU $CC08

; X-coordinate for the player's sprite.
DEF b_spriteX EQU $CC09

; Y-coordinate for the player's sprite.
DEF b_spriteY EQU $CC0A

; X-coordinate for the screen.
DEF f_screenX EQU $CC0B

; Y-coordinate for the screen.
DEF f_screenY EQU $CC0C

DEF b_animationTimer EQU $CC0D
DEF b_animationFrame EQU $CC0E

SECTION "Player", ROM0

; ------------------------------------------------------------------------------
; `func InitializePlayer()`
;
; Initializes the state for the player and sets up sprites for rendering the
; character.
; ------------------------------------------------------------------------------
InitializePlayer::
  DEF INITIAL_STATE equ STATE_IDLE
  DEF INITIAL_HEADING equ HEADING_RIGHT
  DEF INITIAL_X EQU 63
  DEF INITIAL_Y EQU 208
  DEF INITIAL_SCREEN_X EQU 12 ;0
  DEF INITIAL_SCREEN_Y EQU 104 ;112
  DEF INITIAL_SPRITE_Y EQU INITIAL_Y - INITIAL_SCREEN_Y
  DEF INITIAL_SPRITE_X EQU INITIAL_X - INITIAL_SCREEN_X

  ; Initialize Player State
  ld a, INITIAL_STATE
  ld [b_playerState], a
  ld a, INITIAL_HEADING
  ld [b_playerHeading], a
  ld hl, f_playerX
  ld a, INITIAL_X
  ld [hli], a
  ld a, 0
  ld [hli], a
  ld [hli], a ; f_playerVelocityX
  ld [hli], a
  ld [hli], a ; f_targetVelocityX
  ld [hli], a
  ld a, INITIAL_Y
  ld [hli], a
  ld a, 0
  ld [hli], a
  ld [hli], a ; f_playerVelocityY
  ld [hli], a

  ; Initialize the screen position
  ld a, INITIAL_SCREEN_X
  ld [rSCX], a
  ld a, INITIAL_SCREEN_Y
  ld [rSCY], a

  ; Initialize the character sprites
  ld hl, ary_SpriteOAM
  ld a, INITIAL_SPRITE_Y
  ld [b_spriteY], a
  ld [hli], a
  ld a, INITIAL_SPRITE_X
  ld [b_spriteX], a
  ld [hli], a
  ld a, $20
  ld [hli], a
  ld a, 0
  ld [hli], a
  ld a, INITIAL_SPRITE_Y
  ld [hli], a
  ld a, INITIAL_SPRITE_X + 8
  ld [hli], a
  ld a, $22
  ld [hli], a
  ld a, 0
  ld [hli], a


  ; TODO Clean me up
  ld a, 12
  ld [b_animationTimer], a

  ret

; ------------------------------------------------------------------------------
; `func UpdatePlayer()`
;
; Called every frame to update the player state (e.g. position, velcoity, etc.)
; based on button input and world state.
; ------------------------------------------------------------------------------
UpdatePlayer::
  call SetTargetVelocityX
  call AccelerateX
  call ApplyVelocityX

  call UpdateSprite

  ret

; ------------------------------------------------------------------------------
; `func SetTargetVelocityX()`
;
; Sets the horizontal target velocity for the player based on controller input.
; ------------------------------------------------------------------------------
SetTargetVelocityX:
  ; Set default run or walk speed based on if the B button is down
  ld b, $18
  ld a, [b_JoypadDown]
  ld d, a
  and a, BUTTON_B
  jr z, .check_right
  ld b, $28
.check_right
  ld a, d
  and a, BUTTON_RIGHT
  jr z, .check_left

  ld a, HEADING_RIGHT
  ld [b_playerHeading], a


  ld a, b
  ld [f_targetVelocityX], a
  ret
.check_left
  ld a, d
  and a, BUTTON_LEFT
  jr z, .zero

  ld a, HEADING_LEFT
  ld [b_playerHeading], a


  ld a, b
  cpl
  inc a
  ld [f_targetVelocityX], a
  ret
.zero
  ld a, 0
  ld [f_targetVelocityX], a
  ret

; ------------------------------------------------------------------------------
; `func AccelerateX()`
;
; Accelerates the current velocity toward the target velocity if the two do not
; match.
; ------------------------------------------------------------------------------
AccelerateX:
  ld a, [f_targetVelocityX]
  ld hl, f_playerVelocityX
  sbc a, [hl]
  jr nz, .check_negative
  ret
.check_negative
  and %1000_0000
  jr z, .positive
.negative
  dec [hl]
  ret
.positive
  inc [hl]
  ret

; ------------------------------------------------------------------------------
; `func ApplyVelocityX()`
;
; Applies the current velocity to the position to move the character.
; ------------------------------------------------------------------------------
ApplyVelocityX:
  ld hl, f_playerX
  ld a, [f_playerVelocityX]
  ld b, a
  and %1000_0000
  jr nz, .negative
.positive
  xor a   ; Fast way to clear the carry flag (vs. scf + ccf)
  ld a, b
  add [hl]
  ld [hli], a
  ld a, 0
  adc [hl]
  ld [hl], a
  ret
.negative
  ld a, b
  cpl
  inc a
  ld b, a
  ld a, [hl]
  sbc b
  ld [hli], a
  ld a, [hl]
  sbc 0
  ld [hl], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateSprite()`
;
; Updates the sprite and graphics based on the player state.
; ------------------------------------------------------------------------------
UpdateSprite:
  ld a, [f_playerX + 1]
  ld b, a
  ld a, [f_playerX]

  srl b
  rr a
  srl b
  rr a
  srl b
  rr a
  srl b
  rr a

  ld [b_spriteX], a
  ld [ary_SpriteOAM + 1], a
  add a, 8
  ld [ary_SpriteOAM + 5], a

  call UpdateAnimationFrame

  ld a, [b_animationFrame]
  sla a
  sla a
  add $20
  ld b, a
  add $02
  ld c, a


  ld a, [b_playerHeading]
  cp HEADING_RIGHT
  jr nz, .face_left
.face_right
  ld a, b
  ld [ary_SpriteOAM + 2], a
  ld a, c
  ld [ary_SpriteOAM + 6], a
  ld a, 0
  ld [ary_SpriteOAM + 3], a
  ld [ary_SpriteOAM + 7], a
  ret
.face_left
  ld a, c
  ld [ary_SpriteOAM + 2], a
  ld a, b
  ld [ary_SpriteOAM + 6], a
  ld a, %0010_0000
  ld [ary_SpriteOAM + 3], a
  ld [ary_SpriteOAM + 7], a
  ret

UpdateAnimationFrame:
  ld a, [f_playerVelocityX]
  or a
  jr nz, .timer
  ld a, [delay_by_velocity]
  ld [b_animationTimer], a
  ret
.timer
  ld a, [b_animationTimer]
  dec a
  jr z, .next_frame
  ld [b_animationTimer], a
  ret
.next_frame
  ld a, [b_animationFrame]
  xor 1
  ld [b_animationFrame], a
  ld a, [f_playerVelocityX]
  ld b, a
  and %1000_0000
  jr z, .lookup
  ld a, b
  cpl
  inc a
  ld b, a
.lookup
  ld a, b
  ld h, 0
  ld l, a
  ld de, delay_by_velocity
  add hl, de
  ld a, [hl]
  ld [b_animationTimer], a
  ret

delay_by_velocity:
DB 12, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10
DB 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7
DB 6, 6, 6, 6, 6, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4
