INCLUDE "game.inc"
INCLUDE "hardware.inc"
INCLUDE "player.inc"

SECTION "Player", ROM0

; ------------------------------------------------------------------------------
; `func InitializePlayer()`
;
; Initializes the state for the player and sets up sprites for rendering the
; character.
; ------------------------------------------------------------------------------
; TODO This method requires extensive refactoring.
; ------------------------------------------------------------------------------
InitializePlayer::
  ld a, INITIAL_STATE
  ld [bMotionState], a

  ld a, INITIAL_HEADING
  ld [bPlayerHeading], a

  ld hl, fPlayerX

  ld a, INITIAL_X_LO
  ld [hli], a
  ld a, INITIAL_X_HI
  ld [hli], a

  ld a, 0
  ld [hli], a   ; fPlayerVelocityX = 0
  ld [hli], a   ; fTargetVelocityX = 0

  ; fPlayerY
  ld a, INITIAL_Y_LO
  ld [hli], a
  ld a, INITIAL_Y_HI
  ld [hli], a

  ld a, 0
  ld [hli], a ; fPlayerVelocityY


  ld a, INITIAL_SPRITE_X
  ld [bSpriteX], a

  ld a, INITIAL_SPRITE_Y
  ld [bSpriteY], a

  ; Initialize the screen position
  ld a, INITIAL_SCREEN_X
  ld [rSCX], a
  ld a, INITIAL_SCREEN_Y
  ld [rSCY], a

  ; Initialize the character sprites
  ld hl, pSpriteOAM
  ld a, INITIAL_SPRITE_Y
  ld [bSpriteY], a
  ld [hli], a
  ld a, INITIAL_SPRITE_X
  ld [bSpriteX], a
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

  call ResetAnimationTimers

  ld a, 0
  ld [bSlowFallTimer], a

  ret

; ------------------------------------------------------------------------------
; `func ResetAnimationTimers()`
;
; Resets the timer and frames for all character animations (walking, idle, etc.)
; ------------------------------------------------------------------------------
ResetAnimationTimers::
  ld a, INITIAL_WALK_ANIMATION_DELAY
  ld [bAnimationTimer], a
  ld a, 0
  ld [bAnimationFrame], a
  ld a, [idle_timer_durations]
  ld [bIdleTimer], a
  ld a, IDLE_STATE_STILL
  ld [bIdleState], a
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
  call ConvertWorldCoordinates
  call CheckCollision
  call UpdateSprite
  call ScrollScreen
  ret

; ------------------------------------------------------------------------------
; `func UpdateVerticalMotion()`
;
; Updates player state for vertical motion (jumping and falling).
; ------------------------------------------------------------------------------
UpdateVerticalMotion:
  ld a, [bMotionState]
  cp STATE_AIRBORNE
  jr z, .airborne
.check_jump
  ld a, [bJoypadPressed]
  and BUTTON_A
  jr nz, .begin_jump
  ld a, 0
  ld [fPlayerVelocityY], a
  ret
.begin_jump
  ld a, SLOW_FALL_FRAMES
  ld [bSlowFallTimer], a
  ld a, INITIAL_JUMP_VELOCITY
  ld [fPlayerVelocityY], a
  ld a, STATE_AIRBORNE
  ld [bMotionState], a
  ret
.airborne
  call AccelerateY
  call ApplyVelocityY
  ret

; ------------------------------------------------------------------------------
; `func AccelerateY()`
;
; Updates the vertical velocity based on controller input and player state.
; ------------------------------------------------------------------------------
AccelerateY:
  ld b, 5
  ld a, [bSlowFallTimer]
  cp a, 0
  jr z, .decelerate
  dec a
  ld [bSlowFallTimer], a
  cp a, 0
  jr z, .decelerate
  ld a, [bJoypadDown]
  and BUTTON_A
  jr z, .end_slow_fall
  ld b, 1
  jr .decelerate
.end_slow_fall
  ld a, 0
  ld [bSlowFallTimer], a
.decelerate
  ld a, [fPlayerVelocityY]
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
  ld [fPlayerVelocityY], a
  ret

; ------------------------------------------------------------------------------
; `func ApplyVelocityY()`
;
; Applies vertical velocity to move the player through the game world.
; ------------------------------------------------------------------------------
ApplyVelocityY:
  ld a, [fPlayerVelocityY]
  ld hl, fPlayerY
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
  ld c, a
  ld a, 0
  adc [hl]
  ld [hl], a
  ; Check to see if the value exceeds dot 240 and bound accordingly...
  cp a, $0F
  jr z, .check_lo_byte
  jr nc, .bound_above
  ret
.check_lo_byte
  ld a, c
  cp $00
  jr nz, .bound_above
  ret
.bound_above
  ld a, $0F
  ld [hld], a
  ld a, $00
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
  ; For left and top bounding, just check if the result is negative and set the
  ; value to 0 if that is the case.
  and a, %1000_0000
  jr nz, .bound_below
  ret
.bound_below
  ld a, 0
  ld [hld], a
  ld [hl], a
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
  ld a, [bJoypadDown]
  ld d, a
  and a, BUTTON_B
  jr z, .check_right
  ld b, RUN_SPEED
.check_right
  ld a, d
  and a, BUTTON_RIGHT
  jr z, .check_left
  ld a, b
  ld [fTargetVelocityX], a
  ret
.check_left
  ld a, d
  and a, BUTTON_LEFT
  jr z, .zero
  ld a, b
  cpl
  inc a
  ld [fTargetVelocityX], a
  ret
.zero
  ld a, 0
  ld [fTargetVelocityX], a
  ret

; ------------------------------------------------------------------------------
; `func AccelerateX()`
;
; Accelerates the current velocity toward the target velocity if the two do not
; match.
; ------------------------------------------------------------------------------
AccelerateX:
  ld a, [bMotionState]
  cp STATE_IDLE
  jr nz, .accelerate
.airborne
  ld a, [fTargetVelocityX]
  or 0
  jr nz, .check_directional_velocity
  ret
.check_directional_velocity
  ld a, [fTargetVelocityX]
  ld c, a
  ld a, [fPlayerVelocityX]
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
  ld a, [fPlayerVelocityX]
  ld hl, fTargetVelocityX
  sub a, [hl]
  jr nz, .check_sign
  ret
.check_sign
  ld hl, fPlayerVelocityX
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
  ld a, [fPlayerVelocityX]
  ld hl, fPlayerX
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
  ld c, a
  ld a, 0
  adc [hl]
  ld [hl], a
  ; Check to see if the value exceeds dot 240 and bound accordingly...
  cp a, $0F
  jr z, .check_lo_byte
  jr nc, .bound_above
  ret
.check_lo_byte
  ld a, c
  cp $00
  jr nz, .bound_above
  ret
.bound_above
  ld a, $0F
  ld [hld], a
  ld a, $00
  ld [hl], a
  call StopHorizontal
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
  ; For left and top bounding, just check if the result is negative and set the
  ; value to 0 if that is the case.
  and a, %1000_0000
  jr nz, .bound_below
  ret
.bound_below
  ld a, 0
  ld [hld], a
  ld [hl], a
  call StopHorizontal
  ret

; ------------------------------------------------------------------------------
; `func ConvertWorldCoordinates()`
;
; Converts 12.4 fixed point player coordinates into integer world coordinates
; for use when rendering the game's graphics.
; ------------------------------------------------------------------------------
ConvertWorldCoordinates::
  ld hl, fPlayerX
  call FixedPointToInt
  ld [bWorldX], a
  ld hl, fPlayerY
  call FixedPointToInt
  ld [bWorldY], a
  ret

; ------------------------------------------------------------------------------
; `func FixedPointToInt(hl)`
;
; Converts a 12.4 fixed point value to an 8-bit integer and stores the result in
; the `a` register.
;
; - Param `hl` - The address to the low byte of the 12.4 fixed point value to be
;   converted.
; - Return `a` - The converted value.
; ------------------------------------------------------------------------------
FixedPointToInt:
  inc hl
  ld a, [hld]
  ld b, a
  ld a, [hl]
  srl b
  rr a
  srl b
  rr a
  srl b
  rr a
  srl b
  rr a
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
; `func UpdateMotionState()`
;
; Updates the motion state based on target and current velocity.
; ------------------------------------------------------------------------------
UpdateMotionState:
  ld a, [bMotionState]
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
  ld a, [fTargetVelocityX]
  ld hl, fPlayerVelocityX
  cp a, [hl]
  jr nz, .accelerating
.steady
  cp a, 0
  jr nz, .walk
.still
  ld a, STATE_IDLE
  ld [bMotionState], a
  ret
.accelerating
  ld a, [bJoypadDown]
  ld b, a
  ld a, BUTTON_LEFT
  or BUTTON_RIGHT
  and b
  jr z, .walk
  ld a, [fTargetVelocityX]
  and %1000_0000
  ld b, a
  ld a, [fPlayerVelocityX]
  and %1000_0000
  cp a, b
  jr z, .walk
.pivot
  ld a, STATE_PIVOT
  ld [bMotionState], a
  ret
.walk
  ld a, STATE_WALKING
  ld [bMotionState], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateAnimationFrame()`
;
; Updates the animation frame based on motion state and velocity.
; ------------------------------------------------------------------------------
UpdateAnimationFrame:
  ld a, [fPlayerVelocityX]
  or a
  jr nz, .timer
  ld a, [delay_by_velocity]
  ld [bAnimationTimer], a
  ret
.timer
  ld a, [bAnimationTimer]
  dec a
  jr z, .next_frame
  ld [bAnimationTimer], a
  ret
.next_frame
  ld a, [bAnimationFrame]
  xor 1
  ld [bAnimationFrame], a
  ld a, [fPlayerVelocityX]
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
  ld [bAnimationTimer], a
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
  ld a, [fTargetVelocityX]
  cp 0
  jr nz, .check_heading
  ret
.check_heading
  rlc a
  and 1
  ld b, a
  ld a, [bPlayerHeading]
  cp b
  jr nz, .update_heading
  ret
.update_heading
  ld a, b
  ld [bPlayerHeading], a
  ld a, [pSpriteOAM + 3]
  xor %0010_0000
  ld [pSpriteOAM + 3], a
  ld [pSpriteOAM + 7], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateIdleState()`
;
; Updates the idle animation state based on the motion state and timers.
; ------------------------------------------------------------------------------
UpdateIdleState:
  ld a, [bMotionState]
  cp STATE_IDLE
  jr z, .update_timer
  ld a, [idle_timer_durations]
  ld [bIdleTimer], a
  ld a, IDLE_STATE_STILL
  ld [bIdleState], a
  ret
.update_timer
  ld a, [bIdleTimer]
  dec a
  jr z, .update_state
  ld [bIdleTimer], a
  ret
.update_state
  ld a, [bIdleState]
  inc a
  cp 4
  jr nz, .set_state
  ld a, 0
.set_state
  ld [bIdleState], a
  ld l, a
  ld h, 0
  ld de, idle_timer_durations
  add hl, de
  ld a, [hl]
  ld [bIdleTimer], a
  ret

idle_timer_durations:
  DB 245, 10, 10, 10

; ------------------------------------------------------------------------------
; `func UpdateSpriteTiles()`
;
; Updates the player sprite tiles based the current motion and animation state.
; ------------------------------------------------------------------------------
UpdateSpriteTiles:
  ld a, [bMotionState]
  cp STATE_AIRBORNE
  jr z, .airborne
  cp STATE_PIVOT
  jr z, .pivot
  cp STATE_WALKING
  jr z, .walk
.still
  ld a, [bIdleState]
  sla a
  sla a
  ld b, a
  ld a, [bPlayerHeading]
  add b
  ld de, idle_tiles
  jr .set_tiles
  ret
.airborne
  ld a, [bPlayerHeading]
  ld de, jumping_tiles
  jr .set_tiles
  ret
.walk
  ld a, [bAnimationFrame]
  sla a
  sla a
  ld b, a
  ld a, [bPlayerHeading]
  add b
  ld de, walk_tiles
  jr .set_tiles
  ret
.pivot
  ld a, [bPlayerHeading]
  ld de, pivot_tiles
.set_tiles
  ld l, a
  ld h, 0
  add hl, de
  ld a, [hl]
  ld [pSpriteOAM + 2], a
  inc hl
  inc hl
  ld a, [hl]
  ld [pSpriteOAM + 6], a
  ret

; ------------------------------------------------------------------------------
; TODO Document each of these tables.
; ------------------------------------------------------------------------------
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

; ------------------------------------------------------------------------------
; `func UpdateSpritePosition()`
;
; Updates the player sprite position on the screen.
; ------------------------------------------------------------------------------
UpdateSpritePosition:
  ; Basic Vertical Positioning.
  ld a, [bWorldY]
  ld b, a
  cp SCROLL_START_Y
  jr c, .set_y
.check_scrolling_y
  cp 184
  jr nc, .max_scroll_y
  ld a, SCROLL_START_Y
  jr .set_y
.max_scroll_y
  ld a, b
  sub a, MAX_SCROLL_Y
.set_y
  ; Add a +16 dot offset due to how sprites are rendered
  ld b, $10
  add a, b
  ld [bSpriteY], a
  ld a, [bSpriteY]
  ld [pSpriteOAM], a
  ld [pSpriteOAM + 4], a
  ; Basic Horizontal Positioning.
  ld a, [bWorldX]
  ld b, a
  cp 80
  jr c, .set_x
.check_scrolling
  cp 256 - SCROLL_START_X
  jr nc, .max_scroll
  ld a, SCROLL_START_X
  jr .set_x
.max_scroll
  ld a, b
  sub a, MAX_SCROLL_X
.set_x
  ld b, 8  ; This adds a +8 dot offset to account for how sprites are rendered.
  add a, b
  ld [bSpriteX], a
  ld [pSpriteOAM + 1], a
  add a, 8
  ld [pSpriteOAM + 5], a
  ret

; ------------------------------------------------------------------------------
; `func ScrollScreen()`
;
; Calculates and handles screen scrolling based on the player's position in the
; game world.
; ------------------------------------------------------------------------------
ScrollScreen:
  ; Horizontal scrolling
  ld hl, rSCX
  ld b, 0
  ld a, [bWorldX]
  cp SCROLL_START_X
  jr c, .set_scroll_x
.check_scrolling_x
  cp 256 - SCROLL_START_X
  jr nc, .max_scroll_x
  sub SCROLL_START_X
  ld b, a
  jr .set_scroll_x
.max_scroll_x
  ld b, MAX_SCROLL_X
.set_scroll_x
  ld [hl], b
  ; Vertical scrolling
  ld hl, rSCY
  ld b, 0
  ld a, [bWorldY]
  cp SCROLL_START_Y
  jr c, .set_scroll_y
.check_scrolling_y
  cp 256 - SCROLL_START_Y
  jr nc, .max_scroll_y
  sub SCROLL_START_Y
  ld b, a
  jr .set_scroll_y
.max_scroll_y
  ld b, MAX_SCROLL_Y
.set_scroll_y
  ld [hl], b
  ret
