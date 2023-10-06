INCLUDE "collision.inc"
INCLUDE "game.inc"
INCLUDE "hardware.inc"
INCLUDE "player.inc"

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
  ; - bTileColumn   = WorldX / 8 = WorldX >> 3
  ; - bTileRow      = WorldY / 8 = WorldY >> 3
  ld a, [bWorldX]
  ld [bCollisionX], a
  and %1111_1000
  rrca
  rrca
  rrca
  ld [bTileColumn], a
  ld a, [bWorldY]
  and %1111_1000
  rrca
  rrca
  rrca
  ld [bTileRow], a
  ; Then we calclate the starting address for that particular tile in the level
  ; data using some basic math that's been converted to use bitwise operations
  ; (this makes it easier to do in assembly):
  ;
  ; DataAddress  = LevelData + 32 * bTileRow + bTileColumn
  ;              = LevelData + (bTileRow << 5) + bTileColumn
  ;              = LevelData + ((WorldY >> 3) << 5) + (WorldX >> 3)
  ;              = LevelData + ((WorldY & %1111_1000) << 2) + (WorldX >> 3)
  ld a, [bWorldY]    ; de <- 32 * bTileRow = WorldY << 2
  ld [bCollisionY], a
  and a, %1111_1000
  ld e, a
  ld d, 0
  sla e
  rl d
  sla e
  rl d
  ld a, [bTileColumn]  ; de <- de + bTileColumn = 32 * bTileRow + bTileColumn
  add a, e
  ld e, a
  ld a, 0
  adc d
  ld d, a
  ld hl, $9800        ; Store the address to the graphics tile in the tilemap
  add hl, de
  ld a, h
  ld [pTileMapAddress], a
  ld a, l
  ld [pTileMapAddress + 1], a
  ld hl, LevelData    ; hl <- LevelData + 32 * bTileRow + bTileColumn
  add hl, de
  ; Set d and e to the tile column and row respectively
  ld a, [bTileColumn]
  ld d, a
  ld a, [bTileRow]
  ld e, a
  ; Test collision based on the current motion state for the player
  ld a, [bMotionState]
  cp STATE_IDLE
  jr nz, :+
  ret
: cp STATE_PIVOT
  jr nz, :+
  ld a, [bPlayerHeading]
  xor 1
  ld [bCollisionHeading], a
  jr .collision_test
: ld a, [bPlayerHeading]
  ld [bCollisionHeading], a
.collision_test
  ld a, [bMotionState]
  cp STATE_AIRBORNE
  jr z, .test_airborne
  call CheckGroundedCollision
  call CheckFall
  ret
.test_airborne:
  call CheckAirborneCollision
  ret

; ------------------------------------------------------------------------------
; `func CheckGroundedCollision()`
;
; Checks collision when the player is grounded.
; ------------------------------------------------------------------------------
CheckGroundedCollision:
  call TestHorizontal
  jr nz, .handle_collision
  ret
.handle_collision:
  jr z, .return
  call MoveHorizontal
  call UpdateHorizontalPosition
  call StopHorizontal
  ld a, STATE_IDLE
  ld [bMotionState], a
.return
  ret

; ------------------------------------------------------------------------------
; `func CheckAirborneCollision()`
;
; Checks collision when the player is airborne.
; ------------------------------------------------------------------------------
CheckAirborneCollision:
  call TestHorizontal
  jr z, .test_vertical
  jr z, .return
  call MoveHorizontal
  call TestPlayerTopTiles
  jr nz, .move_vertical
  call UpdateHorizontalPosition
  call StopHorizontal
  ret
.test_vertical
  call TestVertical
  jr z, .return
.move_vertical
  jr z, .return
  call MoveVertical
  call StopVertical
  call UpdateVerticalPosition
.return
  ret

; ------------------------------------------------------------------------------
; `func MoveHorizontal()`
;
; Aligns the player's hitbox with the tile grid and moves it left or right in
; an attempt to resolve a collision.
; ------------------------------------------------------------------------------
MoveHorizontal:
  ld a, [bCollisionHeading]
  cp 0
  jr nz, .moving_left
.moving_right
  ld a, [bTileColumn]
  sla a
  sla a
  sla a
  ld [bCollisionX], a
  ret
.moving_left
  ld a, [bTileColumn]
  inc a
  sla a
  sla a
  sla a
  inc d
  inc hl
  ld [bCollisionX], a
  ret

; ------------------------------------------------------------------------------
; `func StopHorizontal()`
;
; Zeros out the player's horizontal velocity and resets all animation timers.
; ------------------------------------------------------------------------------
StopHorizontal::
  ld a, 0
  ld [fTargetVelocityX], a
  ld [fPlayerVelocityX], a
  call ResetAnimationTimers
  ret

; ------------------------------------------------------------------------------
; `func CheckFall()`
;
; Checks the three tiles below the player to determine if they are no longer
; grounded and should begin to fall.
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
  ld [bMotionState], a
  ret

; ------------------------------------------------------------------------------
; `func MoveVertical()`
;
; Aligns the player's hitbox with the tile grid and moves it up or down in an
; attempt to resolve a collision.
; ------------------------------------------------------------------------------
MoveVertical:
  ld a, [fPlayerVelocityY]
  and %1000_000
  jr nz, .rising
.falling
  ld a, [bTileRow]
  sla a
  sla a
  sla a
  ld [bCollisionY], a
  ret
.rising
  ld a, [bTileRow]
  inc a
  sla a
  sla a
  sla a
  ld [bCollisionY], a
  ret

; ------------------------------------------------------------------------------
; `func StopVertical`
;
; Stops the player's movement if they collided with a wall from above or below.
; ------------------------------------------------------------------------------
StopVertical::
  ld a, [fPlayerVelocityY]
  and %1000_0000
  jr nz, .rising
.land
  ld [bCollisionType], a
  ld a, [bTileRow]
  sla a
  sla a
  sla a
  ld [bCollisionY], a
  call TestVertical
  jr z, .done
  ld a, [bTileRow]
  dec a
  sla a
  sla a
  sla a
  ld [bCollisionY], a
.done
  ld a, STATE_IDLE
  ld [bMotionState], a
  ret
.rising
  ld a, 0
  ld [fPlayerVelocityY], a
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
  ld [bCollisionType], a
  ld a, [bCollisionHeading]
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
  ld a, [bMotionState]
  cp STATE_AIRBORNE
  jr nz, .return
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  jr nz, .collision
  ld a, [bMotionState]
  cp STATE_AIRBORNE
  jr nz, .return
  inc e
  ld bc, 32
  add hl, bc
  call CheckTileCollision
  jr z, .return
.collision
  ld [bCollisionType], a
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
  ld a, [fPlayerVelocityY]
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
  ld [bCollisionType], a

; ------------------------------------------------------------------------------
; `func TestVertical(hl, de)`
;
; Tests collision for the player vertically.
;
; - `hl` - Address of the of background tile for the player's top-left position.
; - `de` - The column and row for the tile in the background.
; ------------------------------------------------------------------------------
TestVertical:
  ld a, [fPlayerVelocityY]
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
  ld [bCollisionType], a
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
  ld a, [bCollisionX]
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
  ; b <- tileY = bTileRow * 8 = bTileRow << 3 = e << 3
  ld a, e
  sla a
  sla a
  sla a
  ld b, a
.check_too_far_above
  ; if (Y + 16 < tileY)  -> No Collision
  ld a, [bCollisionY]
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
  cp TILE_COIN
  jr nz, .non_coin
  call CollectCoin
  ; Indicate that this should be treated as an open tile for movement collision
  ld a, 0
  cp 0
  ret
.non_coin
  cp TILE_OPEN
  ret

; ------------------------------------------------------------------------------
; `func CollectCoin()`
;
; Collects coins and clears them from the background. Note this doesn't clear
; the level data associated with coins.
; ------------------------------------------------------------------------------
CollectCoin:
  ; Find the address in the tilemap for the column and row of the coin tile
  push hl
  ld a, [pTileMapAddress]
  ld h, a
  ld a, [pTileMapAddress + 1]
  ld l, a
  ld a, [bTileColumn]
  ld b, a
  ld a, d
  sub a, b
: cp 0
  jr z, .update_row
  inc hl
  dec a
  jr :-
.update_row
  ld a, [bTileRow]
  ld b, a
  ld a, b
  sub a, b
  ld bc, 32
: cp 0
  jr z, .check_coin_tile
  add hl, bc
  jr :-
  ; Based on the tile found at the address, clear the coin tiles in both the
  ; level graphics and level data.
.check_coin_tile
  ld a, [hl]
  cp $88
  jr z, .top_left
  cp $89
  jr z, .top_right
  cp $98
  jr z, .bottom_left
  cp $99
  jr z, .bottom_right
  jr .return
.top_left
  call ClearCoinTiles
  jr .return
.top_right
  dec hl
  call ClearCoinTiles
  jr .return
.bottom_left
  ld bc, $FFE0 ; -32
  add hl, bc
  call ClearCoinTiles
  jr .return
.bottom_right
  ld bc, $FFE0 ; -32
  add hl, bc
  dec hl
  call ClearCoinTiles
.return
  pop hl
  ret

; ------------------------------------------------------------------------------
; `func ClearCoinTiles(hl)`
;
; Clears four tiles starting at address `hl`.
; ------------------------------------------------------------------------------
ClearCoinTiles:
  ld a, 0
  ld [hli], a
  ld [hld], a
  ld bc, 32
  add hl, bc
  ld [hli], a
  ld [hl], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateHorizontalPosition()`
;
; Updates the player's horizontal position after a collision.
; ------------------------------------------------------------------------------
UpdateHorizontalPosition:
  ; Store the value in the world coordinates
  ld a, [bCollisionX]
  ld [bWorldX], a
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
  ld [fPlayerX], a
  ld a, b
  ld [fPlayerX + 1], a
  ret

; ------------------------------------------------------------------------------
; `func UpdateVerticalPosition()`
;
; Updates the player's vertical position after a collision.
; ------------------------------------------------------------------------------
UpdateVerticalPosition:
  ; Store the value in the world coordinates
  ld a, [bCollisionY]
  ld [bWorldY], a
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
  ld [fPlayerY], a
  ld a, b
  ld [fPlayerY + 1], a
  ret
