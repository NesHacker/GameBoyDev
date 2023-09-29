INCLUDE "game.inc"
INCLUDE "hardware.inc"

; ------------------------------------------------------------------------------
; Constants and macros.
; ------------------------------------------------------------------------------

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

; Vertical velocity to apply right at the start of a jump
DEF INITIAL_JUMP_VELOCITY EQU $C8

; Maximum speed the character can fall
DEF MAX_FALL_SPEED EQU $40

; First state for handling the idle animation
DEF IDLE_STATE_STILL EQU 0

; Second state for handling the idle animation
DEF IDLE_STATE_BLINK EQU 1

; Third state for handling the idle animation
DEF IDLE_STATE_STILL2 EQU 2

; Last state for handling the idle animation
DEF IDLE_STATE_BLINK2 EQU 3

; ------------------------------------------------------------------------------
; Variable memory locations.
; ------------------------------------------------------------------------------

; The state of the player.
;
; * `STATE_IDLE` - State for when the player is not actively moving.
; * `STATE_WALKING` - Motion state that denotes the player is walking.
; * `STATE_RUNNING` - Motion state for when the player is running.
; * `STATE_PIVOT` - Motion state used to indicate the player is pivoting while
;   changing direction.
; * `STATE_AIRBORNE` - Motion state to denote that the player is airborne.
DEF b_motionState EQU $CC00

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

; Walk/run animation timer.
DEF b_animationTimer EQU $CC0D

; Walk/run animation frame.
DEF b_animationFrame EQU $CC0E

; Idle animation state
DEF b_idleState EQU $CC0F

; Idle animation timer
DEF b_idleTimer EQU $CC10

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
  DEF INITIAL_X_LO EQU $F0
  DEF INITIAL_X_HI EQU $03

  DEF INITIAL_Y EQU 208
  DEF INITIAL_Y_HI EQU $0D
  DEF INITIAL_Y_LO EQU $00

  DEF INITIAL_SCREEN_X EQU 12 ;0
  DEF INITIAL_SCREEN_Y EQU 104 ;112
  DEF INITIAL_SPRITE_Y EQU INITIAL_Y - INITIAL_SCREEN_Y
  DEF INITIAL_SPRITE_X EQU INITIAL_X - INITIAL_SCREEN_X

  ; Initialize Player State
  ld a, INITIAL_STATE
  ld [b_motionState], a

  ld a, INITIAL_HEADING
  ld [b_playerHeading], a

  ld hl, f_playerX

  ld a, INITIAL_X_LO
  ld [hli], a
  ld a, INITIAL_X_HI
  ld [hli], a

  ld a, 0
  ld [hli], a   ; f_playerVelocityX = 0
  ld [hli], a   ; f_targetVelocityX = 0

  ; f_playerY
  ld a, INITIAL_Y_LO
  ld [hli], a
  ld a, INITIAL_Y_HI
  ld [hli], a

  ld a, 0
  ld [hli], a ; f_playerVelocityY


  ld a, INITIAL_SPRITE_X
  ld [b_spriteX], a

  ld a, INITIAL_SPRITE_Y
  ld [b_spriteY], a


  ; TODO Init fixed point screen coordinates


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

  ; Initialize the idle timer and state
  ld a, [idle_timer_durations]
  ld [b_idleTimer], a
  ld a, IDLE_STATE_STILL
  ld [b_idleState], a

  ret

; ------------------------------------------------------------------------------
; `func UpdatePlayer()`
;
; Called every frame to update the player state (e.g. position, velcoity, etc.)
; based on button input and world state.
; ------------------------------------------------------------------------------
UpdatePlayer::
  call UpdateVerticalMotion
  call SetTargetVelocityX
  call AccelerateX
  call ApplyVelocityX
  call UpdateSprite
  ret

; ------------------------------------------------------------------------------
; `func UpdateVerticalMotion()`
;
; Updates player state for vertical motion (jumping and falling).
; ------------------------------------------------------------------------------
UpdateVerticalMotion:
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr z, .airborne
.check_jump
  ld a, [b_JoypadPressed]
  and BUTTON_A
  jr nz, .begin_jump
  ld a, 0
  ld [f_playerVelocityY], a
  ret
.begin_jump
  ld a, INITIAL_JUMP_VELOCITY
  ld [f_playerVelocityY], a
  ld a, STATE_AIRBORNE
  ld [b_motionState], a
  ret
.airborne
  call AccelerateY
  call ApplyVelocityY
  call BoundPositionY
  ret

; ------------------------------------------------------------------------------
; `func AccelerateY()`
;
; Updates the vertical velocity based on controller input and player state.
; ------------------------------------------------------------------------------
AccelerateY:
  ld b, 5
  ld a, [f_playerVelocityY]
  cp $E0
  jr nc, .decelerate
  ld a, [b_JoypadDown]
  and BUTTON_A
  jr z, .decelerate
  ld b, 1
.decelerate
  ld a, [f_playerVelocityY]
  add a, b
  ld c, a
  and %1000_0000
  jr nz, .store_velocity
.check_falling_speed
  ld a, c
  cp MAX_FALL_SPEED
  jr c, .store_velocity
  ld c, MAX_FALL_SPEED
.store_velocity
  ld a, c
  ld [f_playerVelocityY], a
  ret

; ------------------------------------------------------------------------------
; `func ApplyVelocityY()`
;
; Applies vertical velocity to move the player through the game world.
; ------------------------------------------------------------------------------
ApplyVelocityY:
  ld a, [f_playerVelocityY]
  ld hl, f_playerY
  jp ApplyVelocity

; ------------------------------------------------------------------------------
; Bounds the player's vertical position.
; ------------------------------------------------------------------------------
BoundPositionY:
  ; Convert 12.4 fixed point into world coordinates
  ld a, [f_playerY + 1]
  ld b, a
  ld a, [f_playerY]
  srl b
  rr a
  srl b
  rr a
  srl b
  rr a
  srl b
  rr a
  cp INITIAL_Y
  jr nc, .land
  ; TODO: This will need to change with screen scrolling
  sub INITIAL_SCREEN_Y
  ld [b_spriteY], a
  ret
.land
  ld a, INITIAL_SPRITE_Y
  ld [b_spriteY], a
  ld a, INITIAL_Y_LO
  ld [f_playerY], a
  ld a, INITIAL_Y_HI
  ld [f_playerY+1], a
  ld a, STATE_IDLE
  ld [b_motionState], a
  ret


; ------------------------------------------------------------------------------
; `func SetTargetVelocityX()`
;
; Sets the horizontal target velocity for the player based on controller input.
; ------------------------------------------------------------------------------
SetTargetVelocityX:
  DEF WALK_SPEED EQU $18
  DEF RUN_SPEED EQU $28

  ; Set default run or walk speed based on if the B button is down
  ld b, WALK_SPEED
  ld a, [b_JoypadDown]
  ld d, a
  and a, BUTTON_B
  jr z, .check_right
  ld b, RUN_SPEED
.check_right
  ld a, d
  and a, BUTTON_RIGHT
  jr z, .check_left
  ld a, b
  ld [f_targetVelocityX], a
  ret
.check_left
  ld a, d
  and a, BUTTON_LEFT
  jr z, .zero
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
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr nz, .accelerate
.airborne
  ld a, [f_targetVelocityX]
  or 0
  jr nz, .check_directional_velocity
  ret
.check_directional_velocity
  ld a, [f_targetVelocityX]
  ld c, a
  ld a, [f_playerVelocityX]
  ld b, a
  and %1000_0000
  ld a, b
  jr nz, .handle_negative
.handle_positive
  cp c
  jr nc, .accelerate
  ret
.handle_negative
  cp c
  jr c, .accelerate
  ret
.accelerate
  ld a, [f_playerVelocityX]
  ld hl, f_targetVelocityX
  sub a, [hl]
  jr nz, .check_sign
  ret
.check_sign
  ld hl, f_playerVelocityX
  and %1000_0000
  jr z, .decrement
  inc [hl]
  ret
.decrement
  dec [hl]
  ret

; ------------------------------------------------------------------------------
; `func ApplyVelocityX()`
;
; Applies the current velocity to the position to move the character.
; ------------------------------------------------------------------------------
ApplyVelocityX:
  ld a, [f_playerVelocityX]
  ld hl, f_playerX
  jp ApplyVelocity

; ------------------------------------------------------------------------------
; `func ApplyVelocity(a, hl)`
;
; Applies the given velocity to the given position state variable.
;
; - Param `a` - The velocity to apply.
; - Param `hl` - Address for the position variable to modify.
; ------------------------------------------------------------------------------
ApplyVelocity:
  ld b, a
  cp a, 0
  jr nz, .check_negative
  ret
.check_negative
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
  call UpdateMotionState
  call UpdateAnimationFrame
  call UpdateHeading
  call UpdateIdleState
  call UpdateSpriteTiles
  call UpdateSpritePosition
  ret

; ------------------------------------------------------------------------------
; `func UpdateSpritePosition()`
;
; Updates the player sprite position on the screen.
; ------------------------------------------------------------------------------
UpdateSpritePosition:
  ld a, [b_spriteY]
  ld [ary_SpriteOAM], a
  ld [ary_SpriteOAM + 4], a
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
  ret

; ------------------------------------------------------------------------------
; `func UpdateMotionState()`
;
; Updates the motion state based on target and current velocity.
; ------------------------------------------------------------------------------
UpdateMotionState:
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr nz, .grounded
.airborne
  ret
.grounded
  ; If T = V:
  ;   // Steady motion
  ;   If T == 0: STILL
  ;   Else: WALK
  ; If T <> V:
  ;   // Accelerating
  ;   If <- or -> being pressed:
  ;     If T > 0 && V < 0: PIVOT
  ;     If T < 0 && V > 0: PIVOT
  ;   Else: WALK
  ld a, [f_targetVelocityX]
  ld hl, f_playerVelocityX
  cp a, [hl]
  jr nz, .accelerating
.steady
  cp a, 0
  jr nz, .walk
.still
  ld a, STATE_IDLE
  ld [b_motionState], a
  ret
.accelerating
  ld a, [b_JoypadDown]
  ld b, a
  ld a, BUTTON_LEFT
  or BUTTON_RIGHT
  and b
  jr z, .walk
  ld a, [f_targetVelocityX]
  and %1000_0000
  ld b, a
  ld a, [f_playerVelocityX]
  and %1000_0000
  cp a, b
  jr z, .walk
.pivot
  ld a, STATE_PIVOT
  ld [b_motionState], a
  ret
.walk
  ld a, STATE_WALKING
  ld [b_motionState], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateAnimationFrame()`
;
; Updates the animation frame based on motion state and velocity.
; ------------------------------------------------------------------------------
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

; ------------------------------------------------------------------------------
; `func UpdateHeading()`
;
; Updates the player's heading based on current velocity.
; ------------------------------------------------------------------------------
UpdateHeading:
  ld a, [f_targetVelocityX]
  cp 0
  jr nz, .check_heading
  ret
.check_heading
  rlc a
  and 1
  ld b, a
  ld a, [b_playerHeading]
  cp b
  jr nz, .update_heading
  ret
.update_heading
  ld a, b
  ld [b_playerHeading], a
  ld a, [ary_SpriteOAM + 3]
  xor %0010_0000
  ld [ary_SpriteOAM + 3], a
  ld [ary_SpriteOAM + 7], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateIdleState()`
;
; Updates the idle animation state based on the motion state and timers.
; ------------------------------------------------------------------------------
UpdateIdleState:
  ld a, [b_motionState]
  cp STATE_IDLE
  jr z, .update_timer
  ld a, [idle_timer_durations]
  ld [b_idleTimer], a
  ld a, IDLE_STATE_STILL
  ld [b_idleState], a
  ret
.update_timer
  ld a, [b_idleTimer]
  dec a
  jr z, .update_state
  ld [b_idleTimer], a
  ret
.update_state
  ld a, [b_idleState]
  inc a
  cp 4
  jr nz, .set_state
  ld a, 0
.set_state
  ld [b_idleState], a
  ld l, a
  ld h, 0
  ld de, idle_timer_durations
  add hl, de
  ld a, [hl]
  ld [b_idleTimer], a
  ret

idle_timer_durations:
  DB 245, 10, 10, 10

; ------------------------------------------------------------------------------
; `func UpdateSpriteTiles()`
;
; Updates the player sprite tiles based the current motion and animation state.
; ------------------------------------------------------------------------------
UpdateSpriteTiles:
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr z, .airborne
  cp STATE_PIVOT
  jr z, .pivot
  cp STATE_WALKING
  jr z, .walk
.still
  ld a, [b_idleState]
  sla a
  sla a
  ld b, a
  ld a, [b_playerHeading]
  add b
  ld de, idle_tiles
  jr .set_tiles
  ret
.airborne
  ld a, [b_playerHeading]
  ld de, jumping_tiles
  jr .set_tiles
  ret
.walk
  ld a, [b_animationFrame]
  sla a
  sla a
  ld b, a
  ld a, [b_playerHeading]
  add b
  ld de, walk_tiles
  jr .set_tiles
  ret
.pivot
  ld a, [b_playerHeading]
  ld de, pivot_tiles
.set_tiles
  ld l, a
  ld h, 0
  add hl, de
  ld a, [hl]
  ld [ary_SpriteOAM + 2], a
  inc hl
  inc hl
  ld a, [hl]
  ld [ary_SpriteOAM + 6], a
  ret

jumping_tiles:
  DB $28, $2A, $2A, $28
pivot_tiles:
  DB $38, $3A, $3A, $38
walk_tiles:
  DB $20, $22, $22, $20
  DB $24, $26, $26, $24
idle_tiles:
  DB $20, $22, $22, $20
  DB $3C, $3E, $3E, $3C
  DB $20, $22, $22, $20
  DB $3C, $3E, $3E, $3C
