INCLUDE "game.inc"
INCLUDE "hardware.inc"
INCLUDE "player.inc"

; TODO Unsure if we need this tbh...
DEF CollisionDetected EQU $CBE0

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

; If a collision requires resetting the player's position then this variable
; will hold the new "corrected" x-position for the player.
DEF UpdateX EQU $CBF3

; If a collision requires resetting the player's position then this variable
; will hold the new "corrected" x-position for the player.
DEF UpdateY EQU $CBF4

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

  ; Reset the `CollisionType` (basically, assume we aren't colliding...)
  ld a, 0
  ld [CollisionType], a

  ; Test collision based on the current motion state for the player
  ld a, [b_motionState]
  cp STATE_IDLE
  jr nz, :+
  ret
: cp STATE_WALKING
  jr nz, :+
  ld a, [b_playerHeading]
  jr .test_walk_collision
: cp STATE_PIVOT
  jr nz, :+
  ld a, [b_playerHeading]
  xor 1
  jr .test_walk_collision
: cp STATE_AIRBORNE
  jr nz, .unknown_state
  jr .test_airborne_collision

.unknown_state
  ; This shouldn't be able to happen, but might if there is a bug in any of the
  ; code that sets the player's motion state.
  ret

.test_walk_collision
  call TestHorizontalCollision
  ld a, [CollisionType]
  jr nz, .handle_walk_collision
  ret
.handle_walk_collision
  call UpdatePosition
  ld a, STATE_IDLE
  ld [b_motionState], a
  ld a, 0
  ld [f_targetVelocityX], a
  ld [f_playerVelocityX], a
  call ResetAnimationTimers
  ret

.test_airborne_collision
  ; TODO Implement airborne collision detection...
  ret

; ------------------------------------------------------------------------------
; `func TestHorizontalCollision(a)`
;
; Performs walking and running collision detection.
;
; * `a` - The heading direction to check for the collision test.
; ------------------------------------------------------------------------------
TestHorizontalCollision:
  cp HEADING_LEFT
  jr z, .moving_left
.moving_right
  ; If we are grounded and moving to the right we only need to check the two
  ; tiles to the right of the player for collision (we move a maximum of 2.5
  ; pixels each frame so it is impossible for the player to move past a block
  ; in a single frame).
  inc d                     ; Check collision with (tx + 2, ty)
  inc hl
  inc d
  inc hl
  call CheckTileCollision
  cp 0
  jr nz, .collision_right
  inc e                     ; Check collision with (tx + 2, ty + 1)
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  cp 0
  jr nz, .collision_right
  ret
.collision_right
  ld [CollisionType], a
  ld a, [TileColumn]
  sla a
  sla a
  sla a
  ld [UpdateX], a
  ret
.moving_left
  ; When moving left we need only check the two left tiles of the character's
  ; sprite for collision...
  call CheckTileCollision
  cp 0
  jr nz, .collision_left
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  cp 0
  jr nz, .collision_left
  ret
.collision_left
  ld [CollisionType], a
  ld a, [TileColumn]
  inc a
  sla a
  sla a
  sla a
  ld [UpdateX], a
  ret

; ------------------------------------------------------------------------------
; `func UpdatePosition()`
;
; Updates the player's position after a collision based on the `UpdateX` and
; `UpdateY` variables.
; ------------------------------------------------------------------------------
UpdatePosition:
  ; Store the value in the world coordinates
  ld a, [UpdateX]
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
  ; if (worldX + 16 < tileX)  -> No Collision
  ld a, [b_worldX]
  ld c, a
  add a, PLAYER_WIDTH
  cp a, b
  jr nc, .check_too_far_right
  ld a, 0
  ret
.check_too_far_right
  ; if (tileX + 8 < worldX)   -> No Collision
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr nc, .check_y_axis
  ld a, 0
  ret
.check_y_axis
  ; b <- tileY = tileRow * 8 = tileRow << 3 = e << 3
  ld a, e
  sla a
  sla a
  sla a
  ld b, a
.check_too_far_above
  ; if (worldY + 16 < tileY)  -> No Collision
  ld a, [b_worldY]
  ld c, a
  add a, PLAYER_WIDTH
  cp a, b
  jr nc, .check_too_far_below
  ld a, 0
  ret
.check_too_far_below
  ; if (tileY + 8 < worldY): -> No Collision
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr nc, .collision_detected
  ld a, 0
  ret
.collision_detected
  ; If the above tests failed then we have a collision!
  ld a, [hl]
  ret
