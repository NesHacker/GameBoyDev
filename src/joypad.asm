INCLUDE "game.inc"
INCLUDE "hardware.inc"

SECTION "Joypad", ROM0

; ------------------------------------------------------------------------------
; `func ReadJoypad`
;
; Reads the joypad buttons and saves their values to `b_JoypadDown`. Also
; records which buttons were pressed as of this call to `b_JoypadPressed`.
; ------------------------------------------------------------------------------
ReadJoypad::
  ; Read the "down" mask from the last frame
  ld a, [b_JoypadDown]
  ld c, a
  ; Read the current controller buttons and store them into the "down" mask
  ld a, $20
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]
  and $0F
  ld b, a
  ld a, $10
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]
  sla a
  sla a
  sla a
  sla a
  or b
  xor $FF
  ld [b_JoypadDown], a
  ; Update the "just pressed" mask
  ld b, a
  ld a, c
  xor b
  and b
  ld [b_JoypadPressed], a
  ret

; ------------------------------------------------------------------------------
; `func FreeMoveCamera()`
;
; Tests the joypad masks by moving the viewport in response to d-pad input.
; ------------------------------------------------------------------------------
FreeMoveCamera::
  ld hl, rSCX
  ld a, [b_JoypadDown]
  ld b, a
  and BUTTON_RIGHT
  jr z, .check_left
  inc [hl]
  inc [hl]
  jr .check_up
.check_left
  ld a, b
  and BUTTON_LEFT
  jr z, .check_up
  dec [hl]
  dec [hl]
.check_up
  ld hl, rSCY
  ld a, b
  and BUTTON_UP
  jr z, .check_down
  ld a, [rSCY]
  cp 0
  jr z, .done
  dec [hl]
  dec [hl]
  jr .done
.check_down
  ld a, b
  and BUTTON_DOWN
  jr z, .done
  ld a, [rSCY]
  cp 112
  jr z, .done
  inc [hl]
  inc [hl]
.done
  ret
