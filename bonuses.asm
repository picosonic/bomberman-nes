
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR CHECK_BONUSES

.locret_E398
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
  BEQ loc_E3E7 ; If bonus not achieved yet, check the bonus criteria

  CMP #2
  BEQ locret_E398

  ; Limit to every other frame
  LDA FRAME_CNT
  AND #1
  BNE loc_E3BD

  ; Reduce timer which the bonus is on screen for
  DEC BONUS_TIMER
  BNE loc_E3BD

  ; Bonus timer has elapsed, so remove the bonus from the screen
  LDA #BONUS_COLLECTED:STA BONUS_STATUS

.loc_E3BD
  JSR sub_CFED
  LDA EXTRA_BONUS_ITEM_X
  CMP BOMBMAN_X
  BNE done

  LDA BOMBMAN_Y
  CMP EXTRA_BONUS_ITEM_Y
  BNE done

  ; Play sound 4
  LDA #4:STA APU_SOUND

  LDX BONUS_AVAILABLE
  LDA BONUS_SCORES,X
  CMP #100
  BCC loc_E3DF
  JSR loc_DD6B
  JMP loc_E3E2

; ---------------------------------------------------------------------------

.loc_E3DF
  JSR sub_DD77

.loc_E3E2
  LDA #BONUS_COLLECTED:STA BONUS_STATUS

.done
  RTS
}

; ---------------------------------------------------------------------------

.loc_E3E7
{
  LDA BOMBMAN_X
  CMP #1
  BNE loc_E401
  LDA BOMBMAN_Y
  CMP #1
  BNE loc_E3F8
  INC VISITS_TOP_LEFT
  JMP loc_E416
}

; ---------------------------------------------------------------------------

.loc_E3F8
{
  CMP #&B
  BNE loc_E401
  INC VISITS_BOTTOM_LEFT
  JMP loc_E416
}

; ---------------------------------------------------------------------------

.loc_E401
{
  CMP #&1D
  BNE loc_E416
  LDA BOMBMAN_Y
  CMP #1
  BNE loc_E410
  INC VISITS_TOP_RIGHT
  JMP loc_E416
}

; ---------------------------------------------------------------------------

.loc_E410
{
  CMP #&B
  BNE loc_E416
  INC VISITS_BOTTOM_RIGHT

.^loc_E416
  LDA BOMBMAN_X
  CMP #1
  BEQ loc_E434
  CMP #&1D
  BEQ loc_E434
  LDA BOMBMAN_Y
  CMP #1
  BEQ loc_E434
  CMP #&B
  BEQ loc_E434

  ; Reset corner visit counters
  LDA #0
  STA VISITS_TOP_LEFT
  STA VISITS_TOP_RIGHT
  STA VISITS_BOTTOM_LEFT
  STA VISITS_BOTTOM_RIGHT

.loc_E434
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
.BONUS_TARGET ; 9D = 0 "Bonus target"
{
  LDA ENEMIES_DEFEATED
  BNE BONUS_CHECKED ; Skip if any enemies killed

  LDA EXIT_DWELL_TIME
  BEQ BONUS_CHECKED ; Skip if not over exit door

.^PLACE_BONUS
  LDA BONUS_STATUS
  BNE BONUS_CHECKED ; Skip if bonus already achieved

  ; Mark bonus has been achieved and set timer (8.5s @ 60Hz)
  LDA #BONUS_ACHIEVED:STA BONUS_STATUS
  LDA #0:STA BONUS_TIMER

  JSR RAND_COORDS ; Place bonus item randomly

  ; Remember where we placed the bonus item
  LDA TEMP_X:STA EXTRA_BONUS_ITEM_X
  LDA TEMP_Y:STA EXTRA_BONUS_ITEM_Y

.^BONUS_CHECKED
  RTS
}

; ---------------------------------------------------------------------------

; Defeat every enemy and circle the outer ring of the level
.BONUS_GODDESS_MASK ; 9D = 1 "Goddess mask"
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
.BONUS_NAKAMOTO_SAN ; 9D = 2 "Nakamoto-san"
{
  LDA ENEMIES_LEFT
  BNE BONUS_CHECKED ; Skip if any enemies left

  LDA BRICKS_BLOWN_UP
  BEQ PLACE_BONUS ; Place bonus if no bricks blown up

  RTS
}
; ---------------------------------------------------------------------------

; Create 248 or more chain reactions with your bombs (one chain reaction = one bomb detonating another)
.BONUS_FAMICOM ; 9D = 3 "Famicom"
{
  LDA CHAIN_REACTIONS
  CMP #248
  BCS PLACE_BONUS ; Place bonus if 248 or more chain reactions

  RTS
}

; ---------------------------------------------------------------------------

; Reveal the exit, walk over it, and don't let go of the d pad for at least 16.5 seconds [while making sure not to defeat any enemies]
.BONUS_COLA_BOTTLE ; 9D = 4 "Cola bottle"
{
  LDA EXIT_DWELL_TIME
  BEQ BONUS_CHECKED ; Skip if 9F = 0

  LDA byte_A6
  CMP #248
  BCS PLACE_BONUS ; Place bonus if A6 >= 248

  RTS
}

; ---------------------------------------------------------------------------

; Destroy every wall and bomb the exit thrice while making sure not to defeat any enemies (including those that come out of the door)
.BONUS_DEZENIMAN_SAN ; 9D = 5 "Dezeniman-san"
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
