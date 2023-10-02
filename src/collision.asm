INCLUDE "game.inc"
INCLUDE "hardware.inc"
INCLUDE "player.inc"

DEF CollisionFound EQU $CBE0

DEF Debug1 EQU $CBF0
DEF Debug2 EQU $CBF2

; ld a, l
; ld [Debug1], a
; ld a, h
; ld [Debug1+1], a

; ld a, LOW(LevelData)
; ld [Debug2], a
; ld a, HIGH(LevelData)
; ld [Debug2+1], a



SECTION "Collision", ROM0

; ------------------------------------------------------------------------------
; `func CheckCollision()`
;
; Checks level bounadries and performs collision detection.
; ------------------------------------------------------------------------------
CheckCollision::
  ; Calculate the starting address for the nine tiles to check for collision.sss

  ; TileColumn   = WorldX / 8 = WorldX >> 3
  ; TileRow      = WorldY / 8 = WorldY >> 3
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

  ld a, [b_worldX]    ; a <- TileColumn = WorldX / 8 = WorldX >> 3
  and %1111_1000
  rrca
  rrca
  rrca

  add a, e            ; de <- de + TileColumn = 32 * TileRow + TileColumn
  ld e, a
  ld a, 0
  adc d
  ld d, a

  ld hl, LevelData    ; hl <- LevelData + 32 * TileRow + TileColumn
  add hl, de

  ; Repurpose d and e to store the column and row numbers for the tile being
  ; currently checked for collions
  ld a, [b_worldX]    ; d <- TileColumn = WorldX / 8 = WorldX >> 3
  and %1111_1000
  rrca
  rrca
  rrca
  ld d, a

  ld a, [b_worldY]    ; e <- TileRow = WorldY / 8 = WorldY >> 3
  and %1111_1000
  rrca
  rrca
  rrca
  ld e, a

  ; TODO Temporary checking code (can remove later if not useful)
  ld a, 0
  ld [CollisionFound], a

  ; Check the nine potentially overlapping tiles in the level data to see if a
  ; has occurred.
  ;
  ; Note: if a collision occurs then the `CheckTileCollision` function will jump
  ; directly into `ResolveCollision`, which will handle the paticular type of
  ; collision and finally return back to the original caller of `CheckCollision`
  ; (thus ending the execution of this routine).

  call CheckTileCollision   ; Tile 1 - (row, col)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 2 - (row, col + 1)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 3 - (row, col + 2)

  ; For the 4th tile we need to move down one row and back to the original
  ; column. This is the same as adding 32 and subtracting 2 from the DataAddress
  ; which when combined gives us: +32 - 2 = +30

  dec d
  dec d
  inc e
  ld bc, 30
  add hl, bc
  call CheckTileCollision   ; Tile 4 - (row + 1, col)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 5 - (row + 1, col + 1)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 6 - (row + 1, col + 2)

  dec d
  dec d
  inc e
  ld bc, 30
  add hl, bc
  call CheckTileCollision   ; Tile 7 - (row + 2, col)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 8 - (row + 2, col + 1)

  inc d
  inc hl
  call CheckTileCollision   ; Tile 9 - (row + 2, col + 2)

  ret

; ------------------------------------------------------------------------------
; `func CheckTileCollision(hl, d, e)`
;
; Axis-Aligned Boundry Box (AABB) collision detection for a tile and the player
; sprite.
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

  ; TODO: Need to differentiate between each of the collision types, for now
  ;       just assume that a non-zero value means "obstruction".

  ; For this I use a simple AABB (Axis-Aligned Bounding Box) collision test
  ; against the 16x16 box surrounding the player sprite and the 8x8 tile we are
  ; currently testing.

  DEF PLAYER_WIDTH EQU 16
  DEF TILE_WIDTH EQU 8

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
  ret

  ; if (tileX + 8 < worldX)   -> No Collision
.check_too_far_right
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr nc, .check_y_axis
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
  ret

.check_too_far_below
  ; if (tileY + 8 < worldY): -> No Collision
  ld a, b
  add a, TILE_WIDTH
  cp a, c
  jr nc, .collision_detected
  ret

.collision_detected
  ; If the above tests failed then we have a collision!
  ld a, 1
  ld [CollisionFound], a
  ; Return two levels up the stack
  pop af
  ret
