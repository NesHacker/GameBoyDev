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

; Number of frames to allow "slow" falling while holding the A-button.
DEF SLOW_FALL_FRAMES EQU 24

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

; Player's integer x-coordinate in world coordinates.
DEF b_worldX EQU $CC0B

; Player's integer y-coordinate in world coordinates.
DEF b_worldY EQU $CC0C

; Walk/run animation timer.
DEF b_animationTimer EQU $CC0D

; Walk/run animation frame.
DEF b_animationFrame EQU $CC0E

; Idle animation state
DEF b_idleState EQU $CC0F

; Idle animation timer
DEF b_idleTimer EQU $CC10

; Timer used for transitioning from "slow" to "fast" falling.
DEF b_slowFallTimer EQU $CC11