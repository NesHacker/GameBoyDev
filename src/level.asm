INCLUDE "game.inc"

SECTION "Level", ROM0

; ------------------------------------------------------------------------------
; `func LoadLevel()`
;
; Copies level data from the ROM into RAM and initializes level variables.
; ------------------------------------------------------------------------------
LoadLevel::
  ld bc, len_Tileset
  ld de, Tileset
  ld hl, $8000
  call LoadData
  ld bc, len_LevelTilemap
  ld de, LevelTilemap
  ld hl, $9800
  call LoadData
  ld bc, len_LevelData
  ld de, LevelData
  ld hl, ary_LevelData
  call LoadData
  call FindOnigiri
  call InitBackgroundAnimator
  ret

; ------------------------------------------------------------------------------
; `func FindOnigiri()`
;
; Finds the addresses for all background tiles that depict onigiri so they can
; be animated quickly in the main game loop. Normally this list would be
; compiled into the level data prior, but I am just doing something simple here.
; ------------------------------------------------------------------------------
FindOnigiri:
  ld bc, $9800
  ld de, LevelData
  ld hl, ary_Onigiri
.loop
  ld a, [de]
  cp a, 5
  jr nz, .skip
  ld a, b
  ld [hli], a
  ld a, c
  ld [hli], a
.skip
  inc de
  inc bc
  ld a, d
  cp a, HIGH(LevelData + len_LevelData)
  jr nz, .loop
  ld a, e
  cp a, LOW(LevelData + len_LevelData)
  jr nz, .loop
  ret

; ------------------------------------------------------------------------------
; `func InitBackgroundAnimator`
;
; Initializes variables for the level's background animator.
; ------------------------------------------------------------------------------
InitBackgroundAnimator:
  ld a, BgDelay
  ld [b_BgTimer], a
  ret

; ------------------------------------------------------------------------------
; `func AnimateBg()`
;
; Handles timing and updates for background animations.
; ------------------------------------------------------------------------------
AnimateBackground::
  ld a, [b_BgTimer]
  dec a
  ld [b_BgTimer], a
  jp nz, .skip
  ld a, BgDelay
  ld [b_BgTimer], a
  call UpdateOnigiriSprites
.skip
  ret

; ------------------------------------------------------------------------------
; `func UpdateOnigiriSprites`
;
; Animates the onigiri sprites in the background by swapping between the two
; tilesets.
; ------------------------------------------------------------------------------
UpdateOnigiriSprites:
  ld hl, ary_Onigiri
.update_loop
  ld a, [hli]
  or 0
  jr z, .return
  ld d, a
  ld a, [hli]
  ld e, a
  ld a, [de]
  ; This math below looks complex but what it's basically doing is swapping
  ; C <-> E and D <-> F in the low nibble of the tile value. This works out
  ; tiles for each of the frames are two positions away from one another either
  ; direction. This is basically just a bitwise op way to handle an add two and
  ; mod by 4.
  and $0F
  sub $0C
  add 2
  and $03
  add $0C
  ld b, a
  ld a, [de]
  and $F0
  or b
  ld [de], a
  jr .update_loop
.return
  ret
