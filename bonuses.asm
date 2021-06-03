
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR CHECK_BONUSES

.BONUS_DONE
  RTS

; =============== S U B R O U T I N E =======================================
.CHECK_BONUSES
{
  ; Check how many enemies are left
  LDA ENEMIES_LEFT
  BNE no_fanfare

  ; Check if we've already played the fanfare
  LDA NO_ENEMIES_CELEBRATED
  BNE no_fanfare

  ; Prevent fanfare being played more than once
  INC NO_ENEMIES_CELEBRATED

  ; Play sound 6 (fanfare) to indicate we've just defeated all the enemies
  LDA #6:STA APU_SOUND

.no_fanfare
  LDA BONUS_STATUS
  BEQ check_top_left ; If bonus not achieved yet, check the bonus criteria

  CMP #BONUS_COLLECTED
  BEQ BONUS_DONE

  ; Limit to every other frame
  LDA FRAME_CNT
  AND #1
  BNE no_bonus_timeout

  ; Reduce timer which the bonus is on screen for
  DEC BONUS_TIMER
  BNE no_bonus_timeout

  ; Bonus timer has elapsed, so remove the bonus from the screen
  LDA #BONUS_COLLECTED:STA BONUS_STATUS

.no_bonus_timeout
  JSR sub_CFED
  LDA EXTRA_BONUS_ITEM_X
  CMP BOMBMAN_X
  BNE done

  LDA BOMBMAN_Y
  CMP EXTRA_BONUS_ITEM_Y
  BNE done

  ; Play sound 4
  LDA #4:STA APU_SOUND

  ; Work out score for this bonus item
  LDX BONUS_AVAILABLE
  LDA BONUS_SCORES,X

  ; If < 100 it's * 10,000
  ;   else it's * 100,000
  CMP #100
  BCC low_score

  JSR SCORE_100K ; add high score
  JMP mark_bonus_collected

; ---------------------------------------------------------------------------

.low_score
  JSR SCORE_10K ; add low score

.mark_bonus_collected
  LDA #BONUS_COLLECTED:STA BONUS_STATUS

.done
  RTS
}

; ---------------------------------------------------------------------------
.check_top_left
{
  ; Check for being on left edge
  LDA BOMBMAN_X
  CMP #1
  BNE check_top_right

  ; Check for being on top edge
  LDA BOMBMAN_Y
  CMP #1
  BNE check_bottom_left

  ; We're at the top left
  INC VISITS_TOP_LEFT

  JMP check_bonus_criteria
}

; ---------------------------------------------------------------------------
.check_bottom_left
{
  ; Check got being on bottom edge
  CMP #MAP_HEIGHT-2
  BNE check_top_right

  ; We're at the bottom left
  INC VISITS_BOTTOM_LEFT

  JMP check_bonus_criteria
}

; ---------------------------------------------------------------------------
.check_top_right
{
  ; Check for being on the right edge
  CMP #MAP_WIDTH-3
  BNE check_bonus_criteria

  ; Check for being on the top edge
  LDA BOMBMAN_Y
  CMP #1
  BNE check_bottom_right

  INC VISITS_TOP_RIGHT

  JMP check_bonus_criteria
}

; ---------------------------------------------------------------------------
.check_bottom_right
{
  ; Check got being on bottom edge
  CMP #MAP_HEIGHT-2
  BNE check_bonus_criteria

  INC VISITS_BOTTOM_RIGHT
}

.check_bonus_criteria
{
  ; Check for keeping to edge of level
  LDA BOMBMAN_X
  CMP #1           ; Left edge
  BEQ no_visit_reset
  CMP #MAP_WIDTH-3 ; Right edge (double padded)
  BEQ no_visit_reset

  LDA BOMBMAN_Y
  CMP #1            ; Top edge
  BEQ no_visit_reset
  CMP #MAP_HEIGHT-2 ; Bottom edge
  BEQ no_visit_reset

  ; Reset corner visit counters
  LDA #0
  STA VISITS_TOP_LEFT
  STA VISITS_TOP_RIGHT
  STA VISITS_BOTTOM_LEFT
  STA VISITS_BOTTOM_RIGHT

.no_visit_reset
  LDX BONUS_AVAILABLE
  BEQ BONUS_TARGET            ; 0 "Bonus target"
  DEX:BEQ BONUS_GODDESS_MASK  ; 1 "Goddess mask"
  DEX:BEQ BONUS_NAKAMOTO_SAN  ; 2 "Nakamoto-san"
  DEX:BEQ BONUS_FAMICOM       ; 3 "Famicom"
  DEX:BEQ BONUS_COLA_BOTTLE   ; 4 "Cola bottle"
  DEX:BEQ BONUS_DEZENIMAN_SAN ; 5 "Dezeniman-san"

  RTS
}

; ---------------------------------------------------------------------------
; Reveal the exit and walk over it without defeating any enemies
.BONUS_TARGET ; 0 "Bonus target"
{
  LDA ENEMIES_DEFEATED
  BNE BONUS_CHECKED ; Skip if any enemies killed

  LDA EXIT_DWELL_TIME
  BEQ BONUS_CHECKED ; Skip if not over exit door
}

.PLACE_BONUS
{
  LDA BONUS_STATUS
  BNE BONUS_CHECKED ; Skip if bonus already achieved

  ; Mark bonus has been achieved and set timer (8.5s @ 60Hz)
  LDA #BONUS_ACHIEVED:STA BONUS_STATUS
  LDA #0:STA BONUS_TIMER

  JSR RAND_COORDS ; Place bonus item randomly

  ; Remember where we placed the bonus item
  LDA TEMP_X:STA EXTRA_BONUS_ITEM_X
  LDA TEMP_Y:STA EXTRA_BONUS_ITEM_Y
}

.BONUS_CHECKED
  RTS

; ---------------------------------------------------------------------------
; Defeat every enemy and circle the outer ring of the level
.BONUS_GODDESS_MASK ; 1 "Goddess mask"
{
  LDA ENEMIES_LEFT
  BNE BONUS_CHECKED ; Skip if any enemies left

  LDA VISITS_TOP_LEFT
  BEQ BONUS_CHECKED ; Skip if not visited top left

  LDA VISITS_TOP_RIGHT
  BEQ BONUS_CHECKED ; Skip if not visited top right

  LDA VISITS_BOTTOM_LEFT
  BEQ BONUS_CHECKED ; Skip if not visited bottom left

  LDA VISITS_BOTTOM_RIGHT
  BNE PLACE_BONUS ; Place bonus if bottom right visited

  RTS
}

; ---------------------------------------------------------------------------
; Kill every enemy without blowing up any walls
.BONUS_NAKAMOTO_SAN ; 2 "Nakamoto-san"
{
  LDA ENEMIES_LEFT
  BNE BONUS_CHECKED ; Skip if any enemies left

  LDA BRICKS_BLOWN_UP
  BEQ PLACE_BONUS ; Place bonus if no bricks blown up

  RTS
}

; ---------------------------------------------------------------------------
; Create 248 or more chain reactions with your bombs (one chain reaction = one bomb detonating another)
.BONUS_FAMICOM ; 3 "Famicom"
{
  LDA CHAIN_REACTIONS
  CMP #248
  BCS PLACE_BONUS ; Place bonus if 248 or more chain reactions

  RTS
}

; ---------------------------------------------------------------------------
; Reveal the exit, walk over it, and don't let go of the d pad for at least 16.5 seconds [while making sure not to defeat any enemies]
.BONUS_COLA_BOTTLE ; 4 "Cola bottle"
{
  LDA EXIT_DWELL_TIME
  BEQ BONUS_CHECKED ; Skip if exit dwell time is 0

  LDA KEY_TIMER
  CMP #248
  BCS PLACE_BONUS ; Place bonus if A6 >= 248

  RTS
}

; ---------------------------------------------------------------------------
; Destroy every wall and bomb the exit thrice while making sure not to defeat any enemies (including those that come out of the door)
.BONUS_DEZENIMAN_SAN ; 5 "Dezeniman-san"
{
  LDA ENEMIES_DEFEATED
  BNE BONUS_CHECKED ; Skip if any enemies have been killed

  LDA STAGE:ASL A:CLC:ADC #50
  CMP BRICKS_BLOWN_UP
  BEQ no_more_bricks ; Branch if bricks blown up = (STAGE * 2) + 50
  BCS BONUS_CHECKED ; Skip if bricks blown up >= above

.no_more_bricks
  LDA EXIT_BOMBED_COUNT
  CMP #3
  BEQ PLACE_BONUS ; Place bonus if exit bombed 3 times

  RTS
}

; =============== S U B R O U T I N E =======================================
; Calculate which bonus item can be achieved for current level
.PICK_BONUS_ITEM
{
  LDA STAGE
  AND #7
  CMP #6
  BCC set_bonus ; IF (STAGE & 7) < 6 skip

  AND #1 ; Restrict bonus item to 0 or 1

.set_bonus
  STA BONUS_AVAILABLE

  RTS
}

; ---------------------------------------------------------------------------
; Scores for collecting bonus items
;   multiplied by 10,000 for those < 100
;   multiplied by 100,000 for those >= 100
.BONUS_SCORES
  EQUB   1 ; Bonus target (* 10,000 = 10,000)
  EQUB   2 ; Goddess mask (* 10,000 = 20,000)
  EQUB 100 ; Nakamoto-san (* 100,000 = 10,000,000)
  EQUB  50 ; Famicom (* 10,000 = 500,000)
  EQUB   3 ; Cola bottle (* 10,000 = 30,000)
  EQUB 200 ; Dezeniman-san (* 100,000 = 20,000,000)
