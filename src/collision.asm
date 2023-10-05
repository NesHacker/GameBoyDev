INCLUDE "game.inc"
INCLUDE "hardware.inc"
INCLUDE "player.inc"

; Temporarily holds background tile column for that contains the player's
; position (the point at the top left of the player sprite).
DEF TileColumn EQU $CBF0

; Temporarily holds background tile column for that contains the player's
; position (the point at the top left of the player sprite).
DEF TileRow EQU $CBF1

; If the player is not colliding this frame this will be set to `0`. If they are
; colliding then it will be set to the level data id for the tile with which
; they are colliding.
DEF CollisionType EQU $CBF2

; X-coordinate of the player bounding box to use when testing collision.
DEF CollisionX EQU $CBF3

; Y-Coordinate of the player bounding box to use when testing collision.
DEF CollisionY EQU $CBF4

; Heading to check when testing collision.
DEF CollisionHeading EQU $CBF5

; Width to use when testing with the player sprite.
Def PlayerWidth EQU $CBF6

; Width and height of the player sprite in pixels (used for AABB collision).
DEF PLAYER_WIDTH EQU 16

; Width and height of a background tile in pixels (used for AABB collision).
DEF TILE_WIDTH EQU 8

SECTION "Collision", ROM0

; ------------------------------------------------------------------------------
; `func CheckCollision()`
;
; Checks level bounadries and performs collision detection.
; ------------------------------------------------------------------------------
CheckCollision::
  ; We can find the "tile position" for the character by dividing the x and y
  ; positions by eight and then rounding down, which can be done by bit shifting
  ; both values 3 positions to the right:
  ;
  ; - TileColumn   = WorldX / 8 = WorldX >> 3
  ; - TileRow      = WorldY / 8 = WorldY >> 3
  ld a, [b_worldX]
  ld [CollisionX], a
  and %1111_1000
  rrca
  rrca
  rrca
  ld [TileColumn], a
  ld a, [b_worldY]
  and %1111_1000
  rrca
  rrca
  rrca
  ld [TileRow], a

  ; Then we calclate the starting address for that particular tile in the level
  ; data using some basic math that's been converted to use bitwise operations
  ; (this makes it easier to do in assembly):
  ;
  ; DataAddress  = LevelData + 32 * TileRow + TileColumn
  ;              = LevelData + (TileRow << 5) + TileColumn
  ;              = LevelData + ((WorldY >> 3) << 5) + (WorldX >> 3)
  ;              = LevelData + ((WorldY & %1111_1000) << 2) + (WorldX >> 3)
  ld a, [b_worldY]    ; de <- 32 * TileRow = WorldY << 2
  ld [CollisionY], a
  and a, %1111_1000
  ld e, a
  ld d, 0
  sla e
  rl d
  sla e
  rl d
  ld a, [TileColumn]  ; de <- de + TileColumn = 32 * TileRow + TileColumn
  add a, e
  ld e, a
  ld a, 0
  adc d
  ld d, a
  ld hl, LevelData    ; hl <- LevelData + 32 * TileRow + TileColumn
  add hl, de

  ; Set d and e to the tile column and row respectively
  ld a, [TileColumn]
  ld d, a
  ld a, [TileRow]
  ld e, a

  ; Test collision based on the current motion state for the player
  ld a, [b_motionState]
  cp STATE_IDLE
  jr nz, :+
  ret
: cp STATE_PIVOT
  jr nz, :+
  ld a, [b_playerHeading]
  xor 1
  ld [CollisionHeading], a
  jr .collision_test
: ld a, [b_playerHeading]
  ld [CollisionHeading], a
.collision_test
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr z, .test_airborne
.grounded
  call TestHorizontal
  jr z, .check_fall
  call MoveHorizontal
  call UpdateHorizontalPosition
  call StopHorizontal
  ld a, STATE_IDLE
  ld [b_motionState], a
.check_fall
  call CheckFall
  ret
.test_airborne:
  call TestHorizontal
  jr z, .test_vertical
  call MoveHorizontal
  call TestPlayerTopTiles
  jr nz, .move_vertical
  call UpdateHorizontalPosition
  call StopHorizontal
  ret
.test_vertical
  call TestVertical
  jr z, .done
.move_vertical
  call MoveVertical
  call StopVertical
  call UpdateVerticalPosition
.done
  ret

; ------------------------------------------------------------------------------
; `func MoveHorizontal()`
;
; Aligns the player's hitbox with the tile grid and moves it left or right in
; an attempt to resolve a collision.
; ------------------------------------------------------------------------------
MoveHorizontal:
  ld a, [CollisionHeading]
  cp 0
  jr nz, .moving_left
.moving_right
  ld a, [TileColumn]
  sla a
  sla a
  sla a
  ld [CollisionX], a
  ret
.moving_left
  ld a, [TileColumn]
  inc a
  sla a
  sla a
  sla a
  inc d
  inc hl
  ld [CollisionX], a
  ret

; ------------------------------------------------------------------------------
; `func StopHorizontal()`
;
; Zeros out the player's horizontal velocity and resets all animation timers.
; ------------------------------------------------------------------------------
StopHorizontal::
  ld a, 0
  ld [f_targetVelocityX], a
  ld [f_playerVelocityX], a
  call ResetAnimationTimers
  ret

; ------------------------------------------------------------------------------
; `func CheckFall()`
;
; Checks the three tiles below the player to determine if they are no longer
; grounded and should begin to fall.
; ------------------------------------------------------------------------------
; TODO Fix falling at right edge bug...
; ------------------------------------------------------------------------------
CheckFall:
  inc e
  inc e
  ld bc, 64
  add hl, bc
  call CheckTileCollision
  jr z, .check_tile_2
  ret
.check_tile_2
  inc d
  inc hl
  call CheckTileCollision
  jr z, .check_tile_3
  ret
.check_tile_3
  inc d
  inc hl
  call CheckTileCollision
  jr z, .set_falling
  ret
.set_falling
  ld a, STATE_AIRBORNE
  ld [b_motionState], a
  ret

; ------------------------------------------------------------------------------
; `func MoveVertical()`
;
; Aligns the player's hitbox with the tile grid and moves it up or down in an
; attempt to resolve a collision.
; ------------------------------------------------------------------------------
MoveVertical:
  ld a, [f_playerVelocityY]
  and %1000_000
  jr nz, .rising
.falling
  ld a, [TileRow]
  sla a
  sla a
  sla a
  ld [CollisionY], a
  ret
.rising
  ld a, [TileRow]
  inc a
  sla a
  sla a
  sla a
  ld [CollisionY], a
  ret

; ------------------------------------------------------------------------------
; `func StopVertical`
;
; Stops the player's movement if they collided with a wall from above or below.
; ------------------------------------------------------------------------------
StopVertical::
  ld a, [f_playerVelocityY]
  and %1000_0000
  jr nz, .rising
.land
  ld [CollisionType], a
  ld a, [TileRow]
  sla a
  sla a
  sla a
  ld [CollisionY], a
  call TestVertical
  jr z, .done
  ld a, [TileRow]
  dec a
  sla a
  sla a
  sla a
  ld [CollisionY], a
.done
  ; TODO Handle other collision types
  ; (e.g. We shouldn't land when falling on a coin...)
  ld a, STATE_IDLE
  ld [b_motionState], a
  ret
.rising
  ld a, 0
  ld [f_playerVelocityY], a
  ret

; ------------------------------------------------------------------------------
; `func TestHorizontal(hl, de)`
;
; Tests collision for the player horizontally.
;
; - `hl` - Address of the of background tile for the player's top-left position.
; - `de` - The column and row for the tile in the background.
; ------------------------------------------------------------------------------
TestHorizontal:
  push hl
  push de
  ld a, 0
  ld [CollisionType], a
  ld a, [CollisionHeading]
  cp HEADING_LEFT
  jr z, .check_tiles
  inc d
  inc hl
  inc d
  inc hl
.check_tiles
  call CheckTileCollision
  jr nz, .collision
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  jr nz, .collision
  jr .return
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr nz, .return
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  jr nz, .collision
  ld a, [b_motionState]
  cp STATE_AIRBORNE
  jr nz, .return
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  jr z, .return
.collision
  ld [CollisionType], a
.return
  pop de
  pop hl
  ret

; ------------------------------------------------------------------------------
; `func TestPlayerTopTiles(hl, de)`
;
; Very similar to `TestVertical` but only tests the top two tiles for the
; player for collision instead of the top three. This is used as a secondary
; check when determining if the player is colliding to the left/right or to the
; top/bottom when airborne.
;
; - `hl` - Address of the of background tile for the player's top-left position.
; - `de` - The column and row for the tile in the background.
; ------------------------------------------------------------------------------
TestPlayerTopTiles:
  ld a, [f_playerVelocityY]
  and %1000_0000
  jr nz, .check_tiles
.moving_down
  inc e
  inc e
  ld bc, 64
  add hl, bc
.check_tiles
  call CheckTileCollision
  jr nz, .collision
  inc d
  inc hl
  call CheckTileCollision
  jr nz, .collision
  ret
.collision
  ld [CollisionType], a

; ------------------------------------------------------------------------------
; `func TestVertical(hl, de)`
;
; Tests collision for the player vertically.
;
; - `hl` - Address of the of background tile for the player's top-left position.
; - `de` - The column and row for the tile in the background.
; ------------------------------------------------------------------------------
TestVertical:
  ld a, [f_playerVelocityY]
  and %1000_0000
  jr nz, .check_tiles
.moving_down
  inc e
  inc e
  ld bc, 64
  add hl, bc
.check_tiles
  call CheckTileCollision
  jr nz, .collision
  inc d
  inc hl
  call CheckTileCollision
  jr nz, .collision
  inc d
  inc hl
  call CheckTileCollision
  jr nz, .collision
  ret
.collision
  ld [CollisionType], a
  ret

; ------------------------------------------------------------------------------
; `func CheckTileCollision(hl, d, e)`
;
; Axis-Aligned Boundry Box (AABB) collision detection for a tile and the player
; sprite. Sets `a` to zero if there is no collision, sets it to the value of the
; tile in level data if there is.
;
; * `hl` - The address to the level data for the tile to check.
; * `d` - The column in the background for the tile.
; * `e` - The row in the background for the tile.
; ------------------------------------------------------------------------------
CheckTileCollision:
  ld a, [hl]
  cp 0
  jr nz, .check_x_axis
  ret
.check_x_axis
  ; b <- tileX = tileCol * 8 = tileCol << 3 = d << 3
  ld a, d
  sla a
  sla a
  sla a
  ld b, a
.check_too_far_left
  ; if (X + 16 < tileX)  -> No Collision
  ld a, [CollisionX]
  ld c, a
  add a, PLAYER_WIDTH
  cp a, b
  jr c, .no_hit
  jr z, .no_hit
.check_too_far_right
  ; if (X + 8 < worldX)   -> No Collision
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr c, .no_hit
.check_y_axis
  ; b <- tileY = tileRow * 8 = tileRow << 3 = e << 3
  ld a, e
  sla a
  sla a
  sla a
  ld b, a
.check_too_far_above
  ; if (Y + 16 < tileY)  -> No Collision
  ld a, [CollisionY]
  ld c, a
  add a, PLAYER_WIDTH
  cp a, b
  jr nc, .check_too_far_below
  ld a, 0
  cp 0
  ret
  ; jr c, .no_hit
  ; jr z, .no_hit
.check_too_far_below
  ; if (Y + 8 < worldY): -> No Collision
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr nc, .collision_detected
.no_hit
  ld a, 0
  cp 0
  ret
.collision_detected
  ; If the above tests failed then we have a collision!
  ld a, [hl]
  cp 0
  ret


; ------------------------------------------------------------------------------
; `func UpdateHorizontalPosition()`
;
; Updates the player's horizontal position after a collision.
; ------------------------------------------------------------------------------
UpdateHorizontalPosition:
  ; Store the value in the world coordinates
  ld a, [CollisionX]
  ld [b_worldX], a
  ; Convert the x-position to 12.4 fixed point and store the value
  ld b, 0
  sla a
  rl b
  sla a
  rl b
  sla a
  rl b
  sla a
  rl b
  ld [f_playerX], a
  ld a, b
  ld [f_playerX + 1], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateVerticalPosition()`
;
; Updates the player's vertical position after a collision.
; ------------------------------------------------------------------------------
UpdateVerticalPosition:
  ; Store the value in the world coordinates
  ld a, [CollisionY]
  ld [b_worldY], a
  ; Convert the x-position to 12.4 fixed point and store the value
  ld b, 0
  sla a
  rl b
  sla a
  rl b
  sla a
  rl b
  sla a
  rl b
  ld [f_playerY], a
  ld a, b
  ld [f_playerY + 1], a
  ret
