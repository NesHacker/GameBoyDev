SECTION "Game Data", ROM0

; ------------------------------------------------------------------------------
; `binary data Tileset`
;
; This is the tileset data for the game. Since it is just a demo, I was able to
; fit all the graphics I need into the GameBoy's 6144 byte character RAM region.
; Bigger games will need to swap out graphics during runtime based on what needs
; to be rendered at a given time.
; ------------------------------------------------------------------------------
Tileset:: INCBIN "tileset.gb"

; ------------------------------------------------------------------------------
; `binary data LevelTilemap`
;
; This is the 32 x 32 tile data for the background tiles representing the game's
; level. For this project I kept things simple by using the binary tilemap data
; directly. In more advanced projects one would have much larger runs of data
; representing levels and use an encoding scheme (e.g. run-length encoding) to
; minimize ROM data usage.
; ------------------------------------------------------------------------------
LevelTilemap:: INCBIN "level.tilemap"

; ------------------------------------------------------------------------------
; `binary data LevelData`
;
; This contains the data that detemines how each tile in the level acts in terms
; of gameplay. For the demo there are eight types of tiles:
;
; - `0`: open space
; - `1`: obstruction (ground, pips, unbreakable blocks, etc.)
; - `2`: platform top
; - `3`: pipe top
; - `4`: breakable bricks
; - `5`: onigiri
; - `6`: coins
; - `7`: switch blocks
; ------------------------------------------------------------------------------
LevelData:: INCBIN "level-data.tilemap"
