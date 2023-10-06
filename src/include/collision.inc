; ------------------------------------------------------------------------------
; Variables
; ------------------------------------------------------------------------------

; Temporarily holds background tile column for that contains the player's
; position (the point at the top left of the player sprite).
DEF bTileColumn EQU $CBF0

; Temporarily holds background tile column for that contains the player's
; position (the point at the top left of the player sprite).
DEF bTileRow EQU $CBF1

; If the player is not colliding this frame this will be set to `0`. If they are
; colliding then it will be set to the level data id for the tile with which
; they are colliding.
DEF bCollisionType EQU $CBF2

; X-coordinate of the player bounding box to use when testing collision.
DEF bCollisionX EQU $CBF3

; Y-Coordinate of the player bounding box to use when testing collision.
DEF bCollisionY EQU $CBF4

; Heading to check when testing collision.
DEF bCollisionHeading EQU $CBF5

; Address to the player's current tile in the graphics tilemap (2 bytes).
DEF pTileMapAddress EQU $CBF6

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------

; Width and height of the player sprite in pixels (used for AABB collision).
DEF PLAYER_WIDTH EQU 16

; Width and height of a background tile in pixels (used for AABB collision).
DEF TILE_WIDTH EQU 8

; Value for data tiles that represent open space.
DEF TILE_OPEN EQU 0

; Value for data tiles that are impassible.
DEF TILE_IMPASSIBLE EQU 1

; Value for data tiles that are coins.
DEF TILE_COIN EQU 2