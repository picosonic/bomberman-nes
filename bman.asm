ORG &C000

.ROMSTART

INCLUDE "nesregs.asm"
INCLUDE "consts.asm"
INCLUDE "vars.asm"

.RESET
  SEI

  LDA #0
  STA PPU_CTRL_REG2:STA PPU_CTRL_REG1 ; Reset PPU

  CLD ; NES 6502 does not have BCD-mode, clear the flag in all cases

  LDX #&FF:TXS ; Clear stack

; Add 2 VBlanks, for PPU stabilization
.WAIT_VBLANK1
  LDA PPU_STATUS
  BPL WAIT_VBLANK1

.WAIT_VBLANK2
  LDA PPU_STATUS
  BPL WAIT_VBLANK2

  JMP START

; ---------------------------------------------------------------------------

.NMI
{
  ; Cache A/X/Y registers
  PHA
  TXA:PHA
  TYA:PHA

  LDX #0
  STX FRAMEDONE   ; Cancel waiting for the start of the frame
  STX PPU_SPR_ADDR
  LDA STAGE_STARTED ; Check for level started
  BEQ SEND_SPRITES

  LDA #25     ; Draw a small one at the top right of the screen - OAM - Y position
  STA SPR_TAB ; Apparently used for debugging (forgot to remove)

  LDA #SCORE_1:STA SPR_TAB+1 ; OAM - Tile id
  LDA #0:STA SPR_TAB+2 ; OAM - attributes
  LDA #248:STA SPR_TAB+3 ; OAM - X position

.SEND_SPRITES
  LDA #7:STA PPU_SPR_DMA
  LDX #9:STX TILE_CNT ; Draw tiles from a circular buffer
  BNE DRAW_NEXT_TILE

.DRAW_TILES
  LDA TILE_TAB+2,Y ; Draw new tiles to the end of the buffer, but no more than TILE_CNT pieces
  ORA TILE_TAB,Y

  PHA
  STA PPU_ADDRESS

  LDX TILE_TAB+1,Y:STX PPU_ADDRESS
  LDX TILE_TAB+3,Y
  LDA TILE_MAP,X:STA PPU_DATA
  LDA TILE_MAP+1,X:STA PPU_DATA
  PLA

  STA PPU_ADDRESS

  LDA TILE_TAB+1,Y
  CLC:ADC #32
  STA PPU_ADDRESS

  LDA TILE_MAP+2,X:STA PPU_DATA
  LDA TILE_MAP+3,X:STA PPU_DATA

  LDA #&23
  ORA TILE_TAB,Y

  PHA
  STA PPU_ADDRESS

  LDA TILE_TAB+4,Y:STA PPU_ADDRESS

  TAX
  LDA PPU_DATA
  LDA PPU_DATA
  AND TILE_TAB+6,Y
  ORA TILE_TAB+7,Y
  TAY
  PLA

  STA PPU_ADDRESS
  STX PPU_ADDRESS
  STY PPU_DATA

  LDA #8
  CLC:ADC TILE_CUR
  STA TILE_CUR

  DEC TILE_CNT
  BEQ DRAW_MENU_ARROW

.DRAW_NEXT_TILE
  LDY TILE_CUR
  CPY TILE_PTR
  BNE DRAW_TILES

.DRAW_MENU_ARROW
  LDA INMENU
  BEQ DRAW_ARROW_SKIP

  LDA #&22:LDX #&68
  JSR VRAMADDR

  LDY #&B0
  LDA CURSOR
  BNE DRAW_ARROW_START
  LDY #&40

.DRAW_ARROW_START
  STY PPU_DATA

  LDA #&22:LDX #&70
  JSR VRAMADDR

  LDY #&B0
  LDA CURSOR
  BEQ DRAW_ARROW_CONT
  LDY #&40

.DRAW_ARROW_CONT
  STY PPU_DATA
  JMP UPDATE_FPS
; ---------------------------------------------------------------------------

.DRAW_ARROW_SKIP
  LDA STAGE_STARTED
  BEQ UPDATE_FPS

  LDA TILE_CNT
  CMP #4
  BCC UPDATE_FPS

  LDA #&20:LDX #&4B
  JSR VRAMADDR    ; Y=2, X=11

  LDX #0

.DRAW_SCORE_BLANK
  LDA SCORE,X     ; Skip leading zeroes
  BNE DRAW_SCORE_NUM
  LDA #':' ; Blank character instead of zero
  STA PPU_DATA
  INX
  CPX #7
  BNE DRAW_SCORE_BLANK
  BEQ DRAW_TIMER

.DRAW_SCORE_NUM
  LDA SCORE,X
  CLC:ADC #'0'      ; Number 0...9
  STA PPU_DATA
  INX
  CPX #7
  BNE DRAW_SCORE_NUM

.DRAW_TIMER
  LDA #&20:LDX #&46 ; Y=2, X=6
  JSR VRAMADDR

  ; Check for time overflow
  LDA TIMELEFT
  CMP #255
  BNE TIME_OVERFLOW

  LDA #0

.TIME_OVERFLOW
  JSR DRAW_TIME

.UPDATE_FPS
  LDA PPU_STATUS
  JSR PPU_RESTORE
  INC FRAME_CNT
  LDA IS_SECOND_PASSED
  BEQ TICK_FPS

  INC FPS
  LDA FPS
  CMP #HW_FPS ; Compare frame count with hardware FPS
  BCC TICK_FPS

  LDA #0:STA IS_SECOND_PASSED

.TICK_FPS
  STA FPS ; ** This could be placed prior to the label **

  JSR PAD_READ ; Read gamepad inputs
  JSR APU_PLAY_MELODY ; Play melody
  JSR APU_PLAY_SOUND  ; Play sound

  LDA BOOM_SOUND ; Check if explosion sound effect is playing
  BEQ SET_SCROLL_REG ; Skip if not

  LDA DEMOPLAY ; Check if we're in DEMO mode
  BNE SET_SCROLL_REG ; Skip if we are

  LDA #&E:STA APU_DMC_FREQ_REG ; Disable IRQ/loop, set frequncy to 14 (=72 ~ 24858 Hz)
  LDA #DISABLE:STA BOOM_SOUND ; Stop explosion sound effect from playing
  LDA #lo((BOOMPCM-ROMSTART) / 64):STA APU_DMC_START_REG ; PCM sample address
  LDA #&FF:STA APU_DMC_LEN_REG ; PCM sample length (4081 bytes)
  LDA #&F:STA APU_MASTERCTRL_REG ; Disable DMC
  LDA #&1F:STA APU_MASTERCTRL_REG ; Enable DMC

.SET_SCROLL_REG
  LDA STAGE_STARTED ; Check if stage started
  BEQ LEAVE_NMI ; Leave the NMI if not

  ; Prevent status bar from scrolling
.WAIT_SPR0_HIT
  LDA PPU_STATUS     ; Check for sprite 0 hit (for raster timing)
  AND #&40
  BNE WAIT_SPR0_HIT  ; Keep waiting until not hit

.WAIT_SPR0_MISS
  LDA PPU_STATUS     ; Check for sprite 0 hit
  AND #&40
  BEQ WAIT_SPR0_MISS ; Keep waiting until hit

  ; Set scroll offset
  LDA H_SCROLL:STA PPU_SCROLL_REG ; Set scroll X
  LDA V_SCROLL:STA PPU_SCROLL_REG ; Set scroll Y

.LEAVE_NMI
  LDA #5
  EOR SPR_TAB_TOGGLE
  STA SPR_TAB_TOGGLE

  ; Restore A/X/Y registers
  PLA:TAY
  PLA:TAX
  PLA

  RTI
}

; =============== S U B R O U T I N E =======================================
; Set graphics pointer to absolute address in A:X
.VRAMADDR
{
  STA PPU_ADDRESS
  STX PPU_ADDRESS

  RTS
}

INCLUDE "input.asm"

; =============== S U B R O U T I N E =======================================
.PPU_RESET
{
  JSR PPUD
  JSR VBLD
  LDA #&10:STA LAST_2000:STA PPU_CTRL_REG1
  LDA #0
  STA H_SCROLL
  STA TILE_CUR
  STA TILE_PTR
  STA V_SCROLL

  JSR SPRD        ; Hide sprites
  JSR PPUD
  JSR WAITVBL
  JSR PAL_RESET
}

; =============== S U B R O U T I N E =======================================
; Clear screen
.CLS
{
  ; Set VRAM address to &2000
  LDA #&20:LDX #0
  JSR VRAMADDR

  LDY #8
  LDA #&B0

.CLEAR_NT
  STA PPU_DATA
  DEX
  BNE CLEAR_NT
  DEY
  BNE CLEAR_NT

  ; Set VRAM address to &23C0
  LDA #&23:LDX #&C0
  JSR VRAMADDR

  LDX #&40
  LDA #0

.CLEAR_AT
  STA PPU_DATA
  DEX
  BNE CLEAR_AT

  RTS
}

; =============== S U B R O U T I N E =======================================

.PPUE
{
  JSR VBLD

  JSR WAITVBL

  LDA #&E:JSR WRITE2001

  JSR SENDSPR

  JMP VBLE
}

; =============== S U B R O U T I N E =======================================

; How sprites are drawn.
; In total, there can be up to 16 sprite images in the game (10 monsters, bombermen, and items)
; The sprite image consists of 4 sprites and is 16x16 in size.
; The sprite table is conventionally divided into two parts: for even and odd frames.
; This was done apparently in order to reduce the flickering of sprites.
; The sprite image is drawn in halves (first, the left 8x16, then the right),
; since they are symmetrical.
; The special variable SPR_TAB_TOGGLE takes values 0 -> 5 -> 0 ...
; and thus chooses which half of the SPR_TAB to use for rendering.
; In general, the offset in SPR_TAB for the current sprite image is calculated as follows:
; TEMP = SPR_TAB_INDEX++ + SPR_TAB_TOGGLE   <-- The index starts at 1.
; TEMP = TEMP >= 12 ? TEMP - 10 : TEMP      <-- Limit index to 12
; Y = 16 * TEMP                             <-- multiply by 16 because a metasprite consists of 4 sprites
; Which is a little strange, but what to take, how they did it, and it is.
; For example, there is Bomberman and 10 monsters on the screen. The TEMP value will be
; For even frames: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
; For odd frames: 6, 7, 8, 9, 10, 11, 2, 3, 4, 5, 6
; (For odd frames, the Bomberman sprites will be overwritten by the monster's sprites and as a result,
; the Bomberman picture will flash when there are many sprites on the screen.)

.SENDSPR
{
  LDA #0:STA PPU_SPR_ADDR
  LDA #7:STA PPU_SPR_DMA

  RTS
}

; =============== S U B R O U T I N E =======================================

.PPUD
{
  JSR WAITVBL

  LDA #0

; =============== S U B R O U T I N E =======================================

.^WRITE2001
  STA PPU_CTRL_REG2

.^WRITE2001_2
  STA LAST_2001

  RTS
}

; =============== S U B R O U T I N E =======================================

.SPRE
{
  LDA LAST_2001
  ORA #&10
  BNE WRITE2001_2

; =============== S U B R O U T I N E =======================================
; Hide sprites
.^SPRD
  LDY #&1C
  LDA #248

.SETATTR
  STA SPR_TAB,Y
  STA SPR_TAB+&20,Y
  STA SPR_TAB+&40,Y
  STA SPR_TAB+&60,Y
  STA SPR_TAB+&80,Y
  STA SPR_TAB+&A0,Y
  STA SPR_TAB+&C0,Y
  STA SPR_TAB+&E0,Y
  DEY:DEY:DEY:DEY ; Y = Y - 4
  BPL SETATTR

  RTS
}

; =============== S U B R O U T I N E =======================================
; Wait for vertical blank (top bit of PPU_STATUS)
.WAITVBL
{
  LDA PPU_STATUS
  BMI WAITVBL ; Wait for vblank start (line 241)

.WAITVBL2
  LDA PPU_STATUS
  BPL WAITVBL2 ; Wait for vblank to be cleared

  RTS
}

; =============== S U B R O U T I N E =======================================

.PPU_RESTORE
{
  LDA LAST_2001:STA PPU_CTRL_REG2

  LDA #0:LDX #0
  JSR VRAMADDR

  LDA #0
  STA PPU_SCROLL_REG
  STA PPU_SCROLL_REG

  LDA LAST_2000:STA PPU_CTRL_REG1

  RTS
}

; =============== S U B R O U T I N E =======================================

.VBLE
{
  JSR WAITVBL
  LDA LAST_2000
  ORA #&80
  BNE WRITE2000

; =============== S U B R O U T I N E =======================================

.^VBLD
  LDA LAST_2000
  AND #&7F

.WRITE2000
  STA LAST_2000:STA PPU_CTRL_REG1

  RTS
}

; =============== S U B R O U T I N E =======================================
; Reset the full colour palette
.PAL_RESET
{
  ; Point to palette RAM
  LDA #hi(BASE_PAL):LDX #lo(BASE_PAL)
  JSR VRAMADDR

  ; Copy all palette data
  LDY #32

.loop
  LDA STARTPAL,X
  STA PPU_DATA

  INX
  DEY
  BNE loop

; =============== S U B R O U T I N E =======================================

.^VRAMADDRZ
{
  LDA #hi(BASE_PAL):STA PPU_ADDRESS
  LDA #0:STA PPU_ADDRESS

  STA PPU_ADDRESS
  STA PPU_ADDRESS

  RTS
}

.STARTPAL
  EQUB &19 ; Universal background colour
  EQUB &F,&10,&30  ; Background palette 0
  EQUB &19
  EQUB &16,&26,&36 ; Background palette 1
  EQUB &19
  EQUB &F,&18,&28  ; Background palette 2
  EQUB &19
  EQUB &F,&17,  7  ; Background palette 3
  EQUB &19
  EQUB &30,&21,&26 ; Sprite palette 0
  EQUB &19
  EQUB &F,&26,&30  ; Sprite palette 1
  EQUB &19
  EQUB &F,&15,&30  ; Sprite palette 2
  EQUB &19
  EQUB &F,&21,&30  ; Sprite palette 3
}

; =============== S U B R O U T I N E =======================================
; Wait until nothing pressed on joypad 1
.WAITUNPRESS
{
  LDA JOYPAD1
  BNE WAITUNPRESS ; Keep waiting - something is pressed

  RTS
}

; =============== S U B R O U T I N E =======================================

.START
  LDY #0:STY TEMP_ADDR
  INY:STY TEMP_ADDR+1
  DEY
  TYA
  LDX #7

.CLEAR_WRAM
  STA (TEMP_ADDR),Y
  INY
  BNE CLEAR_WRAM

  INC TEMP_ADDR+1
  DEX
  BNE CLEAR_WRAM

  LDX #0
  LDY SOFT_RESET_FLAG
  CPY #&93
  BNE CLEAR_ZP

  LDY CLEAR_TOPSCORE1
  BNE CLEAR_ZP

  LDY CLEAR_TOPSCORE2
  BNE CLEAR_ZP

  LDX #8

.CLEAR_ZP
  STA 0,X
  INX
  BNE CLEAR_ZP
  LDA #&93:STA SOFT_RESET_FLAG

.RESET_GAME
  JSR PPU_RESET
  LDA #0:STA SPR_TAB_TOGGLE
  JSR APU_RESET   ; Reset APU

  ; Play melody 1
  LDA #1:STA APU_MUSIC

.GAME_MENU
  LDX #&FF:TXS ; Clear stack

  LDA #&F:STA APU_MASTERCTRL_REG

  LDA #0
  STA BOOM_SOUND     ; Stop explosion sound playback
  STA DEMOPLAY       ; Stop demo mode
  STA APU_DISABLE    ; Clear sound disabled flag
  STA STAGE_STARTED  ; Set stage as not started
  STA DEMO_WAIT_HI   ; Clear demo wait timer

  ; Draw the main menu
  JSR DRAWMENU
  JSR VBLE

  ; Record that we are in the menu
  LDA #YES:STA INMENU

  ; Wait until no buttons pressed on gamepad 1
.WAIT_RELEASE
  LDA JOYPAD1
  BNE WAIT_RELEASE

.ADVANCE_FRAME
  LDA #8
  STA DEMO_WAIT_HI

.DEMO_WAIT_LOOP
  JSR NEXTFRAME ; Wait for start of next frame

  LDA JOYPAD1
  AND #PAD_START
  BNE START_PRESSED   ; Check for START being pressed

  LDA JOYPAD1
  AND #PAD_SELECT
  BEQ UPDATE_RAND ; START/SELECT not pressed, so update random number generator seed

  LDA CURSOR      ; Move cursor between START/CONTINUE
  EOR #1
  STA CURSOR

  JSR WAITUNPRESS ; Wait for nothing to be pressed
  JMP ADVANCE_FRAME

; ---------------------------------------------------------------------------

.UPDATE_RAND
  JSR RAND        ; Update random number generator state

  ; Tick the demo wait timer
  DEC DEMO_WAIT_LO
  BNE DEMO_WAIT_LOOP

  DEC DEMO_WAIT_HI
  BNE DEMO_WAIT_LOOP

  INC DEMOPLAY    ; If demo wait time expired, then start the demo

.START_PRESSED
  ; If in demo mode, start/continue playing demo
  LDA DEMOPLAY
  BNE start_gameplay

  ; If on menu check where the cursor is pointing
  LDA CURSOR
  BEQ start_gameplay

  ; Cursor pointing at "CONTINUE" so go to password entry screen
  JSR READ_PASSWORD

.start_gameplay
  ; Record that we are no longer showing the menu
  LDA #NO:STA INMENU

  ; Await button release
  JSR WAITUNPRESS

  ; Initialise number of lives
  LDA #LIVESATSTART-1:STA LIFELEFT

  ; If in demo playback don't check where cursor is
  LDA DEMOPLAY
  BNE skip_cursor

  ; Not in demo, so check if game started from a CONTINUE password
  LDA CURSOR
  BNE initial_setup_done

.skip_cursor
  LDA #MAP_FIRST_LEVEL:STA STAGE ; Set current stage to default starting stage

  ; If in demo playback don't clear score
  LDA DEMOPLAY
  BNE dont_clear_score

  LDX #6
  LDA #0

.CLEAR_SCORE_LOOP
  STA SCORE,X
  DEX
  BPL CLEAR_SCORE_LOOP

.dont_clear_score
  ; Default bomb radius
  LDA #SPR_SIZE:STA BONUS_POWER

  ; Clear bonus items
  LDA #NO
  STA BONUS_BOMBS
  STA BONUS_REMOTE
  STA BONUS_SPEED
  STA BONUS_NOCLIP
  STA BONUS_FIRESUIT
  STA DEBUG

  ; If not in demo playback, don't set up for demo
  LDA DEMOPLAY
  BEQ initial_setup_done

  ; Enhance capabilites for demo playback
  LDA #MAX_BOMB-1:STA BONUS_BOMBS
  LDA #DEMO_BOMB_RANGE*SPR_SIZE:STA BONUS_POWER
  LDA #YES:STA BONUS_REMOTE

  LDA #0
  STA APU_MASTERCTRL_REG
  STA SEED        ; Set random seed to 0 to give consistent demo level map
  STA SEED+1
  STA SEED+2
  STA SEED+3
  STA FRAME_CNT

  ; Set pointer to next DEMO data to read
  LDA #lo(DEMO_KEYDATA+2):STA DEMOKEY_DATA
  LDA #hi(DEMO_KEYDATA+2):STA DEMOKEY_DATA+1

  ; Read first two bits of DEMO data
  LDA DEMO_KEYDATA:STA DEMOKEY_TIMEOUT
  LDA DEMO_KEYDATA+1:STA DEMOKEY_PAD1

.initial_setup_done
  ; Always disable bomb walk and invulnerability 1 at start of each level
  LDA #NO
  STA BONUS_BOMBWALK
  STA INVULNERABLE_TIMER

.START_STAGE
  LDA #NO
  STA NO_ENEMIES_CELEBRATED ; Allow all enemies cleared fanfare
  STA BONUS_STATUS ; Set as normal (non-bonus) level
  STA STAGE_STARTED ; Prevent in-game processing

  ; Initialise extra bonus criteria
  STA ENEMIES_DEFEATED ; Enemies defeated
  STA EXIT_DWELL_TIME ; Exit dwell time
  STA ENEMIES_LEFT ; Remaining enemies
  STA VISITS_TOP_LEFT ; Visits to top left square
  STA VISITS_TOP_RIGHT ; Visits to top right square
  STA VISITS_BOTTOM_LEFT ; Visits to bottom left square
  STA VISITS_BOTTOM_RIGHT ; Visits to bottom right square
  STA BRICKS_BLOWN_UP ; Number of bricks blown up
  STA CHAIN_REACTIONS ; Number of chain reactions
  STA KEY_TIMER ; Something pressed on gamepad timer
  STA EXIT_BOMBED_COUNT ; Number of times exit has been bombed

  JSR STAGE_SCREEN ; Show current level number screen, e.g. "STAGE  1"

  ; Play melody 2 to end
  LDA #2:STA APU_MUSIC
  JSR WAITTUNE

  ; Play melody 3
  LDA #3:STA APU_MUSIC

  JSR VBLD
  JSR BUILD_MAP       ; Generate level map
  JSR SPAWN           ; Spawn game entities (also sets stage started to 1)
  JSR PICK_BONUS_ITEM ; Determine which bonus item is available for this level
  JSR PICTURE_ON      ; Turn on screen and display

  ; Set level timer
  LDA #SECONDSPERLEVEL:STA TIMELEFT

  ; Main game loop
.STAGE_LOOP
{
  JSR PAUSED         ; Check for START being pressed, if so pause
  JSR SPRD           ; Hide sprites
  JSR PROCESS_BUTTONS       ; Process button presses
  JSR BOMB_TICK      ; Bomb timer operations and explosion init
  JSR DRAW_BOMBERMAN ; Draw bomberman
  JSR THINK          ; Enemy movements
  JSR BOMB_ANIMATE   ; Animate on-screen bombs
  JSR STAGE_TIMER    ; Tick the stage timer
  JSR CHECK_BONUSES  ; Check bonus criteria

  ; If we've been killed, loose a life
  LDA KILLED
  BNE LOOSE_LIFE

  ; If we're over the exit door and no enemies left, advance to next stage
  LDA NO_ENEMIES_LEFT
  BNE LEVEL_DONE

  ; Limit next function calls to 1 frame out of 4 to slow down explosions
  LDA FRAME_CNT:AND #3:BNE STAGE_LOOP

  JSR DRAW_EXPLOSIONS ; Draw explosions for bombs which are exploding
  JSR EXPLOSION_HIT_DETECTION ; Do collision detection with explosion flames

  JMP STAGE_LOOP ; Go back to start of main game loop
}

; ---------------------------------------------------------------------------

.LOOSE_LIFE
{
  ; If in demo mode, end the demo
  LDA DEMOPLAY
  BNE END_DEMO

  ; Strip bomberman of bonus items
  LDA #NO
  STA BONUS_NOCLIP
  STA BONUS_BOMBWALK
  STA BONUS_REMOTE
  STA BONUS_FIRESUIT
  STA INVULNERABLE_TIMER

  ; Play melody 8 to the end
  LDA #8:STA APU_MUSIC
  JSR WAITTUNE

  ; Loose a life
  DEC LIFELEFT

  ; If we're out of lives, then it's game over
  BMI GAME_OVER

  JMP START_STAGE
}

; ---------------------------------------------------------------------------

.GAME_OVER
{
  LDA #NO:STA STAGE_STARTED

  ; Write "GAME OVER"
  JSR GAME_OVER_SCREEN

  ; Play melody 9
  LDA #9:STA APU_MUSIC

  ; Allow pressing of START to skip melody playback
.GAME_OVER_WAIT
  LDA JOYPAD1
  AND #PAD_START
  BNE GAME_OVER_END

  ; Keep waiting until melody finishes
  LDA APU_MUSIC
  BNE GAME_OVER_WAIT

.GAME_OVER_END
  ; Stop melody playing
  LDA #DISABLE:STA APU_MUSIC

  ; Wait until any key pressed
.WAIT_PRESS
  LDA JOYPAD1
  BEQ WAIT_PRESS

  JMP GAME_MENU
}

; ---------------------------------------------------------------------------

.LEVEL_DONE
{
  LDA DEMOPLAY
  BEQ NEXT_STAGE

.^END_DEMO
  ; Note : In demo mode at this point
  ; Stop melody playing
  LDA #DISABLE:STA APU_MUSIC

  ; Every 4th end to the demo, reset game
  INC DEMO_ENDED
  LDA DEMO_ENDED
  AND #3
  BEQ DO_RESET

  ; Jump back to the game menu
  JMP GAME_MENU
}

; ---------------------------------------------------------------------------

.DO_RESET
{
  JMP RESET_GAME
}

; ---------------------------------------------------------------------------

.NEXT_STAGE
{
  ; Play melody 10 to the end
  LDA #10:STA APU_MUSIC
  JSR WAITTUNE

  ; Gain a life
  INC LIFELEFT

  ; Move on to next stage
  INC STAGE

  LDY #0
  LDA STAGE
  CMP #MAP_LEVELS+1
  BNE SELECT_BONUS_MONSTER ; Select the monster type for the bonus level

  JMP END_GAME
}

; ---------------------------------------------------------------------------

.SELECT_BONUS_MONSTER
{
  INY
  SEC:SBC #5
  BCS SELECT_BONUS_MONSTER

  DEY
  CPY #8
  BCC SELECT_STAGE_TYPE

  LDY #8      ; Type of monster limited to 1 ... 8

.SELECT_STAGE_TYPE
  STY BONUS_ENEMY_TYPE
  ADC #5
  CMP #1
  BEQ START_BONUS_STAGE

  JMP START_STAGE
}

; ---------------------------------------------------------------------------

.START_BONUS_STAGE
{
  LDA #NO:STA STAGE_STARTED
  JSR BONUS_STAGE_SCREEN

  ; Play melody 2 to the end
  LDA #2:STA APU_MUSIC
  JSR WAITTUNE

  JSR VBLD
  JSR BUILD_CONCRETE_WALLS ; Build level
  JSR SPAWN       ; Spawn enemies and bomberman
  JSR PICTURE_ON  ; Turn on screen and sprites
  JSR STAGE_CLEANUP

  ; Play melody 6
  LDA #6:STA APU_MUSIC

  LDA #YES
  STA INVULNERABLE_TIMER
  STA INVULNERABLE

  ; Allow 30 seconds for bonus level
  LDA #SECONDSPERBONUSLEVEL:STA TIMELEFT

.BONUS_STAGE_LOOP
  JSR PAUSED      ; Check for START pressed, if so pause
  LDA TIMELEFT
  BEQ BONUS_STAGE_END ; Check for running out of time

  JSR SPRD                ; Hide sprites
  JSR RESPAWN_BONUS_ENEMY ; Respawn if < 10 enemies
  JSR PROCESS_BUTTONS     ; Process button presses
  JSR BOMB_TICK           ; Bomb timer
  JSR DRAW_BOMBERMAN      ; Draw bomberman
  JSR THINK               ; Enemy AI
  JSR BOMB_ANIMATE        ; Animate on-screen bombs
  JSR BONUS_STAGE_TIMER   ; Tick level time remaining

  ; Limit following functions to every other frame
  LDA FRAME_CNT:AND #1:BNE BONUS_STAGE_LOOP

  JSR DRAW_EXPLOSIONS ; Draw explosions for bombs which are exploding
  JSR EXPLOSION_HIT_DETECTION ; Do collision detection with explosion flames

  JMP BONUS_STAGE_LOOP
}
; ---------------------------------------------------------------------------

.BONUS_STAGE_END
{
  ; Play melody 10 to the end
  LDA #10:STA APU_MUSIC
  JSR WAITTUNE

  LDA #NO
  STA INVULNERABLE
  STA INVULNERABLE_TIMER

  JMP START_STAGE
}

; ---------------------------------------------------------------------------
.END_GAME
{
  JSR PPU_RESET
  JSR DRAW_GAME_COMPLETED
  JSR BUILD_CONCRETE_WALLS ; Reset level map

  LDA #SPR_HALFSIZE
  STA BOMBMAN_U ; Reset bomberman X offset to mid point
  STA BOMBMAN_V ; Reset bomberman Y offset to mid point

  LDA #0
  STA STAGE_STARTED  ; Prevent in-game processing
  STA BOMBMAN_X      ; Position bomberman on far left

  LDA #9:STA BOMBMAN_Y ; Position bomberman 9 rows down

  ; Play melody 7
  LDA #7:STA APU_MUSIC

  JSR SPRE
  JSR VBLE

  .bomberman_run_loop
  {
    JSR NEXTFRAME ; Wait for start of next frame

    LDA #1:STA SPR_TAB_INDEX

    JSR SPRD            ; Hide sprites
    JSR DRAW_BOMBERMAN  ; Draw bomberman

    ; Limit movement to odd frame numbers
    LDA FRAME_CNT
    ROR A
    BCS skip_movement

    JSR MOVE_RIGHT ; Move character right

  .skip_movement
    LDA BOMBMAN_X
    CMP #8
    BNE bomberman_run_loop ; Keep moving until at tile 8 from left, then become "human"
  }

  .human_run_loop
  {
    JSR NEXTFRAME ; Wait for start of next frame
    LDA #1:STA SPR_TAB_INDEX
    JSR SPRD        ; Hide sprites
    JSR DRAW_HUMAN  ; Draw human

    ; Limit movement to odd frame numbers
    LDA FRAME_CNT
    ROR A
    BCS skip_movement

    JSR MOVE_RIGHT

  .skip_movement
    LDA APU_MUSIC
    BNE human_run_loop ; Keep moving until melody 7 has finished playing
  }

  ; Wait for anything to be pressed on gamepad
.WAIT_BUTTON
  LDA JOYPAD1
  BEQ WAIT_BUTTON

  ; Set current stage to first level
  LDA #MAP_FIRST_LEVEL:STA STAGE

  JMP START_STAGE
}

; =============== S U B R O U T I N E =======================================
; Spawn game entities (bomberman and enemies)
.SPAWN
{
  ; Position bomberman in top left corner
  LDA #1
  STA BOMBMAN_X
  STA BOMBMAN_Y

  ; Position in middle of cell
  LDA #SPR_HALFSIZE
  STA BOMBMAN_U
  STA BOMBMAN_V

  LDA #0
  STA BOMBMAN_FRAME
  STA KILLED
  STA DYING
  STA NO_ENEMIES_LEFT

  JSR STAGE_CLEANUP
  JSR SPAWN_MONSTERS
  JSR DRAW_LEVEL_TILES
  JSR WAITVBL
  JSR PAL_RESET

  ; Set the type of monster to emerge from the door if it's bombed, or time runs out
  LDX STAGE
  LDA EXIT_ENEMY_TAB-1,X
  STA EXIT_ENEMY_TYPE

  ; Entity spawning complete, record that the stage has now started
  LDA #YES:STA STAGE_STARTED

  RTS
}

; =============== S U B R O U T I N E =======================================
; Turn on screen and display
.PICTURE_ON
{
  JSR SPRD        ; Send to the screen
  JSR VBLE
  JSR PPUE
  JMP SPRE
}

; =============== S U B R O U T I N E =======================================
; Wait for current melody to finish
.WAITTUNE
{
  LDA APU_MUSIC
  BNE WAITTUNE

  RTS
}

; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR PAUSED

.ABORT_DEMOPLAY
  JMP END_DEMO

; =============== S U B R O U T I N E =======================================
; Check for START being pressed, if so pause and wait for START to be released
.PAUSED
  JSR NEXTFRAME ; Wait for start of next frame
  LDA #1:STA SPR_TAB_INDEX
  LDA JOYPAD1
  AND #PAD_START
  BEQ NOT_PAUSED
  LDA DEMOPLAY
  BNE ABORT_DEMOPLAY

  LDA #YES:STA APU_DISABLE

  ; Play sound 6 (Pause/Unpause)
  LDA #6:STA APU_SOUND

  JSR WAITUNPRESS ; Wait for button to be released

.WAIT_START
  ; Wait for START to be pressed to resume
  LDA JOYPAD1
  AND #PAD_START
  BEQ WAIT_START

  ; Play sound 6 (Pause/Unpause)
  LDA #6:STA APU_SOUND

  LDA #NO:STA APU_DISABLE

  ; Wait for START to be released again
  JSR WAITUNPRESS

  JMP NEXTFRAME ; Wait for start of next frame

; ---------------------------------------------------------------------------

.NOT_PAUSED
  RTS


; =============== S U B R O U T I N E =======================================
; Change the time by 1 second (common level)
.STAGE_TIMER
{
  ; Limit this function to roughly once per second (64 frames)
  LDA FRAME_CNT:AND #&3F:BNE STAGE_TIMER_END

  ; Check for underflow
  LDA TIMELEFT
  CMP #255
  BEQ STAGE_TIMER_END

  ; Reduce time left by 1 second
  DEC TIMELEFT

  ; Continue if some time left
  BNE STAGE_TIMER_END

  ; Out of time
  JSR KILL_ENEMY  ; Remove all enemies from the level

  ; Spawn 10 x enemy type 8 (PONTAN)
  LDA #ENEMY_PONTAN:STA BONUS_ENEMY_TYPE
  JMP RESPAWN_BONUS_ENEMY
; ---------------------------------------------------------------------------

.^STAGE_TIMER_END
  RTS
}

; =============== S U B R O U T I N E =======================================
; Change the time by 1 second (bonus level)
.BONUS_STAGE_TIMER
{
  ; Limit this function to roughly once per second (64 frames)
  LDA FRAME_CNT:AND #&3F:BNE STAGE_TIMER_END

  ; End stage if time run out
  LDA TIMELEFT:BEQ STAGE_TIMER_END

  ; Reduce time left by 1 second
  DEC TIMELEFT

  RTS
}

; =============== S U B R O U T I N E =======================================
; Do collision detection with explosion flames
.EXPLOSION_HIT_DETECTION
{
  LDX #MAX_FIRE-1

.fire_loop
  ; If fire slot not active, move on to next one
  LDA FIRE_ACTIVE,X
  BEQ skip_fire

  ; Check if top bit set
  BPL loc_C688

  ; Clear top bit
  AND #%01111111
  TAY

  LDA FIRE_X,X:STA CACHE_X
  LDA FIRE_Y,X:STA CACHE_Y

  LDA EXPLOSION_FRAMES,Y
  JMP loc_C6DA

; ---------------------------------------------------------------------------

.loc_C688
  LDA FIRE_X,X:STA CACHE_X
  LDA FIRE_Y,X:STA CACHE_Y

  LDA byte_526,X
  AND #%01111000 ; Mask off top bit and bottom three bits
  BEQ skip_fire

  ; Check if top bit set
  LDA byte_526,X
  BPL loc_C6B2

  AND #7
  STA byte_32

  LDA byte_526,X
  LSR A
  AND #%00111100 ; Mask off top two and bottom two bits
  CLC:ADC byte_32
  TAY
  LDA EXPLOSION_FRAMES+27,Y
  JMP loc_C6DA
; ---------------------------------------------------------------------------

.loc_C6B2
  AND #7
  BEQ loc_C6D0

  AND #1
  EOR #1
  STA byte_32

  LDA byte_526,X
  LSR A:LSR A
  AND #%00011110 ; Mask off top three bits and bottom bit
  CLC:ADC byte_32
  CLC:ADC #7
  TAY
  JMP loc_C6D6

; ---------------------------------------------------------------------------
.skip_fire
  JMP next_fire
; ---------------------------------------------------------------------------

.loc_C6D0
  LDA byte_526,X
  LSR A:LSR A:LSR A

.loc_C6D6
  TAY
  LDA EXPLOSION_FRAMES+7,Y

.loc_C6DA
  AND #&FF
  BEQ loc_C753

  JSR DRAW_TILE   ; Add a new tile to TILE_TAB

  LDA DYING
  BNE NO_FIRE_DAMAGE ; Doesn't matter about fire if we're dead

  LDA BONUS_FIRESUIT
  BNE NO_FIRE_DAMAGE ; Firesuit stops us getting hurt by flames

  LDA INVULNERABLE_TIMER
  BNE NO_FIRE_DAMAGE ; Whilst invulnerable, fire doesn't hurt

  LDA BOMBMAN_X
  CMP CACHE_X
  BNE NO_FIRE_DAMAGE ; This flame not at bomberman X position, so no collision

  LDA BOMBMAN_Y
  CMP CACHE_Y
  BNE NO_FIRE_DAMAGE ; This flame not at bomberman Y position, so no collision

  ; Collision between this fire and bomberman, play sound 5
  LDA #5:STA APU_SOUND

  ; Set as DYING by fire
  LDA #1:STA DYING

  LDA #12:STA BOMBMAN_FRAME

.NO_FIRE_DAMAGE
  LDY #MAX_ENEMY-1

.loc_C707
  LDA ENEMY_TYPE,Y
  BEQ loc_C74E

  CMP #9
  BCS loc_C74E

  LDA ENEMY_X,Y
  CMP CACHE_X
  BNE loc_C74E

  LDA ENEMY_Y,Y
  CMP CACHE_Y
  BNE loc_C74E

  INC ENEMIES_DEFEATED

  ; Reset visit counters
  LDA #0
  STA VISITS_TOP_LEFT
  STA VISITS_TOP_RIGHT
  STA VISITS_BOTTOM_LEFT
  STA VISITS_BOTTOM_RIGHT

  LDA #100
  STA byte_5C6,Y

  LDA ENEMY_TYPE,Y
  STA ENEMY_FACE,Y

  LDA IS_SECOND_PASSED
  STA byte_5DA,Y

  INC IS_SECOND_PASSED

  LDA #9
  STA ENEMY_TYPE,Y

  LDA ENEMY_FRAME,Y
  LSR A:LSR A
  AND #7
  CLC:ADC #&20
  STA ENEMY_FRAME,Y

.loc_C74E
  DEY
  BPL loc_C707
  BMI next_fire

.loc_C753
  JSR DRAW_TILE   ; Add a new tile to TILE_TAB

.next_fire
  DEX
  BMI done
  JMP fire_loop ; Too far to branch, so jump to next fire slot
; ---------------------------------------------------------------------------

.done
  RTS

; ---------------------------------------------------------------------------
.EXPLOSION_FRAMES
  EQUB 39,  3,  4,  5,  6,  7,  0 ; Exploding brickwork
  EQUB  0, &B, &C, &D, &E, &D, &C, &B, 0 ; Explosion centre

  EQUB &0F,&10 ; Explosion (h/v) 1
  EQUB &11,&12 ; Explosion (h/v) 2
  EQUB &13,&14 ; Explosion (h/v) 3
  EQUB &15,&16 ; Explosion (h/v) 4
  EQUB &13,&14 ; Explosion (h/v) 3
  EQUB &11,&12 ; Explosion (h/v) 2
  EQUB &0F,&10 ; Explosion (h/v) 1
  EQUB  0,  0  ; Empty space

  EQUB &17,&18,&19,&1A ; Explosion edge (r/t/l/b) 1
  EQUB &1B,&1C,&1D,&1E ; Explosion edge (r/t/l/b) 2
  EQUB &1F,&20,&21,&22 ; Explosion edge (r/t/l/b) 3
  EQUB &23,&24,&25,&26 ; Explosion edge (r/t/l/b) 4
  EQUB &1F,&20,&21,&22 ; Explosion edge (r/t/l/b) 3
  EQUB &1B,&1C,&1D,&1E ; Explosion edge (r/t/l/b) 2
  EQUB &17,&18,&19,&1A ; Explosion edge (r/t/l/b) 1
  EQUB   0,  0,  0,  0 ; Empty space
}

; =============== S U B R O U T I N E =======================================
; Draw explosions
.DRAW_EXPLOSIONS
{
  LDX #MAX_FIRE-1

.loc_C79F
  LDA FIRE_ACTIVE,X
  BNE loc_C7A7

.loc_C7A4
  JMP loc_C8A6
; ---------------------------------------------------------------------------

.loc_C7A7
  PHA
  LDY FIRE_Y,X:STY CACHE_Y
  JSR FIX_STAGE_PTR   ; Set pointer to level data
  LDY FIRE_X,X:STY CACHE_X
  PLA

  BPL loc_C7CB

  INC FIRE_ACTIVE,X
  LDA FIRE_ACTIVE,X
  CMP #&87
  BNE loc_C7A4

  LDA #MAP_EMPTY
  STA FIRE_ACTIVE,X
  STA (STAGE_MAP),Y
  BEQ loc_C7A4

.loc_C7CB
  LDA (STAGE_MAP),Y
  TAY
  BEQ loc_C838

  CPY #MAP_BRICK
  BNE loc_C7DE

  INC BRICKS_BLOWN_UP

  LDA #&80:STA FIRE_ACTIVE,X

  JMP loc_C8A6
; ---------------------------------------------------------------------------

.loc_C7DE
  CPY #MAP_BOMB
  BNE loc_C7EE

  LDA byte_4D6,X
  ORA #&10
  LDY CACHE_X
  STA (STAGE_MAP),Y

  JMP loc_C830
; ---------------------------------------------------------------------------

.loc_C7EE
  CPY #MAP_HIDDEN_EXIT ; Was this the hidden exit door?
  BNE loc_C800

  LDY CACHE_X
  LDA #MAP_EXIT ; Place exit door here
  STA (STAGE_MAP),Y

  LDA #&28
  JSR DRAW_TILE   ; Add a new tile to TILE_TAB
  JMP loc_C830
; ---------------------------------------------------------------------------

.loc_C800
  CPY #MAP_HIDDEN_BONUS ; Was this a hidden bonus?
  BNE loc_C815
  LDY CACHE_X
  LDA #MAP_BONUS ; Place bonus here
  STA (STAGE_MAP),Y

  LDA #&28
  CLC:ADC EXIT_ENEMY_TYPE
  JSR DRAW_TILE   ; Add a new tile to TILE_TAB
  JMP loc_C830
; ---------------------------------------------------------------------------

.loc_C815
  CPY #MAP_EXIT ; Was this an exit door?
  BEQ loc_C828

  CPY #MAP_BONUS ; Was this a bonus item?
  BNE loc_C830

  LDY CACHE_X
  LDA #MAP_EMPTY ; Remove from map
  STA (STAGE_MAP),Y

  JSR DRAW_TILE   ; Add a new tile to TILE_TAB
  DEC EXIT_BOMBED_COUNT

.loc_C828
  INC EXIT_BOMBED_COUNT
  JSR SPAWN_EXIT_MONSTERS ; Spawn exit enemies in all available slots
  JMP loc_C830

.loc_C830
  LDA #NO:STA FIRE_ACTIVE,X

.loc_C835
  JMP loc_C8A6
; ---------------------------------------------------------------------------

.loc_C838
  LDA byte_526,X
  CLC:ADC #8
  STA byte_526,X

  AND #&7F
  CMP #&48
  BCS loc_C7EE

  LDA byte_4D6,X:STA byte_36

  AND #7
  BEQ loc_C835

  TAY
  LDA #0:STA byte_4D6,X
  
  LDA FIRE_X,X
  CLC:ADC FIRE_X_OFFSET,Y
  STA CACHE_X

  LDA FIRE_Y,X
  CLC:ADC FIRE_Y_OFFSET,Y
  STA CACHE_Y

  LDY #MAX_FIRE-1
  JSR FIND_FIRE_SLOT
  BNE loc_C8A6

  LDA CACHE_X:STA FIRE_X,Y
  LDA CACHE_Y:STA FIRE_Y,Y
  LDA #1:STA FIRE_ACTIVE,Y

  LDA byte_36
  AND #7
  STA byte_526,Y

  LDA byte_36
  CLC:ADC #SPR_SIZE
  CMP BONUS_POWER
  BCC loc_C89E

  LDA #NO
  STA FIRE_ACTIVE,Y

  LDA byte_526,X
  ORA #&80
  STA byte_526,X

  JMP loc_C8A1
; ---------------------------------------------------------------------------

.loc_C89E
  STA byte_4D6,Y

.loc_C8A1
  LDA #0
  STA byte_4D6,X

.loc_C8A6
  DEX
  BMI done

  JMP loc_C79F
; ---------------------------------------------------------------------------

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Loop through all available monster slots and spawn exit enemies in each empty one
.SPAWN_EXIT_MONSTERS
{
  LDY #MAX_ENEMY-1

.loop
  LDA ENEMY_TYPE,Y
  BNE skip_enemy

  LDA EXIT_ENEMY_TYPE
  STA ENEMY_TYPE,Y
  STA ENEMY_FRAME,Y

  ; Position X and Y offsets in centre of sprite cell
  LDA #SPR_HALFSIZE
  STA ENEMY_U,Y
  STA ENEMY_V,Y

  ; Set enemy face to a random number between 1 and 4
  JSR RAND
  AND #3
  CLC:ADC #1
  STA ENEMY_FACE,Y

  LDA CACHE_X:STA ENEMY_X,Y
  LDA CACHE_Y:STA ENEMY_Y,Y

  LDA #0
  STA byte_5DA,Y
  STA byte_5C6,Y
  STA byte_5E4,Y

  LDA #&1E
  STA ENEMY_AI_TIMER,Y

.skip_enemy
  DEY
  BPL loop

  RTS
}

; =============== S U B R O U T I N E =======================================
; If the number of monsters in the bonus level is less than 10, then add more
.RESPAWN_BONUS_ENEMY
{
  LDY #MAX_ENEMY-1

.SPAWN_BMONSTR
  LDA ENEMY_TYPE,Y
  BNE NEXT_BMONSTR

  LDA BONUS_ENEMY_TYPE
  STA ENEMY_TYPE,Y

  SEC:SBC #1
  ASL A:ASL A
  STA ENEMY_FRAME,Y

  ; Position X and Y offsets in centre of sprite cell
  LDA #SPR_HALFSIZE
  STA ENEMY_U,Y
  STA ENEMY_V,Y

  ; Set enemy face to a random number between 1 and 4
  JSR RAND
  AND #3
  CLC:ADC #1
  STA ENEMY_FACE,Y

  STY TEMP_Y3
  JSR RAND_COORDS

  LDY TEMP_Y3
  LDA TEMP_X:STA ENEMY_X,Y
  LDA TEMP_Y:STA ENEMY_Y,Y

  LDA #0
  STA byte_5DA,Y
  STA byte_5C6,Y
  STA byte_5E4,Y

  LDA #&1E
  STA ENEMY_AI_TIMER,Y

.NEXT_BMONSTR
  DEY
  BPL SPAWN_BMONSTR
  RTS
}

; =============== S U B R O U T I N E =======================================
; Detonate all active bombs
.DETONATE
{
  LDX #MAX_BOMB-1

.DETONATE_LOOP
  LDA BOMB_ACTIVE,X
  BEQ DETONATE_NEXT

  ; Create pointer to map row where this bomb is
  LDY BOMB_Y,X
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  STY CACHE_Y
  LDY BOMB_X,X:STY CACHE_X

  LDA #0
  JSR sub_C9B6
  JSR PLAY_BOOM_SOUND ; Play explosion sound

  ; Remove from map
  LDA #MAP_EMPTY:STA (STAGE_MAP),Y

  LDA #DISABLE:STA BOMB_ACTIVE,X

  RTS
; ---------------------------------------------------------------------------

.DETONATE_NEXT
  DEX
  BPL DETONATE_LOOP

  RTS
}

; =============== S U B R O U T I N E =======================================
; Bomb timer operation and explosion inititation
.BOMB_TICK
{
  ; Process all of the bombs
  LDX #MAX_BOMB-1

.BOMB_TICK_LOOP
  ; If this bomb slot is not active, move to next slot
  LDA BOMB_ACTIVE,X
  BEQ BOMB_TICK_NEXT

  ; Create pointer to bomb row within level map
  LDY BOMB_Y,X
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  ; Check for this bomb still on map
  STY CACHE_Y
  LDY BOMB_X,X:STY CACHE_X
  LDA (STAGE_MAP),Y
  CMP #MAP_BOMB
  BNE _not_bomb

  ; Bomb is still on map, so increment bomb placement timer
  INC BOMB_TIME_ELAPSED,X

  ; Check if we have the remote detonator, if so don't reduce fuse timer and move to next bomb slot
  LDA BONUS_REMOTE
  BNE BOMB_TICK_NEXT ; *** Should BNE to BOMB_TICK_END

  ; Reduce bomb fuse timer, if not 0 then move on to next bomb slot
  DEC BOMB_TIME_LEFT,X
  BNE BOMB_TICK_NEXT

  ; At this point the bomb will explode because the fuse has run out

  LDA #0

._not_bomb
  AND #7
  JSR sub_C9B6

  LDA CHAIN_REACTIONS
  CMP #&FF
  BEQ _not_chain_reaction

  INC CHAIN_REACTIONS

._not_chain_reaction
  JSR PLAY_BOOM_SOUND ; Play explosion sound

  ; Remove from map
  LDA #MAP_EMPTY:STA (STAGE_MAP),Y

  ; Set this bomb slot as inactive
  LDA #DISABLE:STA BOMB_ACTIVE,X

  ; Move on to next bomb slot
.BOMB_TICK_NEXT
  DEX
  BPL BOMB_TICK_LOOP

.^BOMB_TICK_END
  RTS
}

; =============== S U B R O U T I N E =======================================
;  A = character from MAP
.sub_C9B6
{
  ; Cache X and Y regs
  STX TEMP_X2
  STY TEMP_Y2

  TAY
  LDA byte_C9DE,Y ; Load from lookup table
  STA byte_2E

  LDA #MAP_RIGHT:JSR sub_C9E3
  LDA #MAP_UP:JSR sub_C9E3
  LDA #MAP_LEFT:JSR sub_C9E3
  LDA #MAP_DOWN:JSR sub_C9E3
  LDA #MAP_HERE:JSR sub_C9E3

  ; Restore X and Y regs
  LDX TEMP_X2
  LDY TEMP_Y2

  RTS

; ---------------------------------------------------------------------------
.byte_C9DE
  EQUB &FF ; 0 Empty
  EQUB  3  ; 1 Concrete
  EQUB  4  ; 2 Brick
  EQUB  1  ; 3 Bomb
  EQUB  2  ; 4 Hidden exit
}

; =============== S U B R O U T I N E =======================================
.sub_C9E3
{
  CMP byte_2E
  BEQ BOMB_TICK_END

  STA TEMP_A2 ; Cache A

  TAX
  LDY #MAX_FIRE-1
  JSR FIND_FIRE_SLOT
  BMI done

  LDA CACHE_Y
  CLC:ADC FIRE_Y_OFFSET,X
  STA FIRE_Y,Y

  LDA CACHE_X
  CLC:ADC FIRE_X_OFFSET,X
  STA FIRE_X,Y

  LDA TEMP_A2 ; Restore A

  STA byte_4D6,Y
  STA byte_526,Y

  LDA #1:STA FIRE_ACTIVE,Y

.done
  RTS
}

; ---------------------------------------------------------------------------
.FIRE_Y_OFFSET
  EQUB   0,  0,&FF,  0,  1 ; Y offsets (centre/right/up/left/down)
.FIRE_X_OFFSET
  EQUB   0,  1,  0,&FF,  0 ; X offsets (centre/right/up/left/down)

; =============== S U B R O U T I N E =======================================
; Draw animation of the bombs
.BOMB_ANIMATE
{
  LDX #MAX_BOMB-1

.BOMB_ANIM_LOOP
  ; Skip inactive bombs
  LDA BOMB_ACTIVE,X:BEQ BOMB_ANIM_NEXT

  LDA BOMB_X,X:STA CACHE_X
  LDA BOMB_Y,X:STA CACHE_Y

  LDA BOMB_TIME_ELAPSED,X
  AND #&F     ; Animation delay
  BNE BOMB_ANIM_NEXT

  LDA BOMB_TIME_ELAPSED,X
  LSR A:LSR A:LSR A:LSR A ; A = A / 16
  AND #3
  TAY
  LDA BOMB_ANIM,Y ; Selection animation frame from table
  JSR DRAW_TILE   ; Add to TILE_TAB

.BOMB_ANIM_NEXT
  DEX
  BPL BOMB_ANIM_LOOP

  RTS

; ---------------------------------------------------------------------------
.BOMB_ANIM
  EQUB   9, &A,  9,  8
}

; =============== S U B R O U T I N E =======================================
; Generate a level stage
.BUILD_MAP
{
  JSR BUILD_CONCRETE_WALLS ; Create a clean level

  ; Randomly place exit door (hidden by brick)
  JSR RAND_COORDS:LDA #MAP_HIDDEN_EXIT:STA (STAGE_MAP),Y

  ; Randomly place bonus item (hidden by brick)
  JSR RAND_COORDS:LDA #MAP_HIDDEN_BONUS:STA (STAGE_MAP),Y

  ; Calculate number of bricks to add as (STAGE*2) + 50
  LDA #50
  CLC:ADC STAGE
  CLC:ADC STAGE
  STA CACHE_X

.NEXT_BRICK
  ; Randomly place a brick
  JSR RAND_COORDS:LDA #MAP_BRICK:STA (STAGE_MAP),Y

  ; Loop if more bricks to place
  DEC CACHE_X:BNE NEXT_BRICK

  RTS
}

; =============== S U B R O U T I N E =======================================
; Reset level map to just the concrete walls
.BUILD_CONCRETE_WALLS
{
  LDA #lo(stage_buffer)
  STA STAGE_MAP
  LDA #hi(stage_buffer)
  STA STAGE_MAP+1

  LDY #0

  LDX #&00:JSR STAGE_ROW ; Top wall

  FOR n, 1, (MAP_HEIGHT-3)/2
    LDX #MAP_WIDTH:JSR STAGE_ROW ; Blank row
    LDX #MAP_WIDTH*2:JSR STAGE_ROW ; Alternate concrete
  NEXT

  LDX #MAP_WIDTH:JSR STAGE_ROW ; Blank row
  LDX #&00 ; Bottom wall

  ; =============== S U B R O U T I N E =======================================
  .STAGE_ROW
  {
    LDA #MAP_WIDTH:STA TEMP_X

  .STAGE_CELL
    LDA STAGE_ROWS,X:STA (STAGE_MAP),Y

    INC STAGE_MAP

    ; Check for page overflow
    BNE HI_PART
    INC STAGE_MAP+1

  .HI_PART
    INX
    DEC TEMP_X
    BNE STAGE_CELL

    RTS
  }

}

; =============== S U B R O U T I N E =======================================
; Get random coordinates within the stage map to an empty square
.RAND_COORDS
{
  ; Generate next number from PRNG
  JSR RAND

  ; Divide by 4
  ROR A:ROR A

  ; Limit to 0..31
  AND #&1F

  ; 0 is no good (it's the stage border), so try again
  BEQ RAND_COORDS

  ; Store result as temporary X position
  STA TEMP_X

.generate_Y
  ; Generate next number from PRNG
  JSR RAND

  ; Divide by 8
  ROR A:ROR A:ROR A

  ; Limit to 0..15
  AND #&F

  ; 0 is no good (it's the stage border), so try again
  BEQ generate_Y

  ; If it's greater than the map height, try again
  CMP #MAP_HEIGHT-1
  BCS generate_Y

  ; Store result as temporary Y position
  STA TEMP_Y
  TAY

  ; Set up pointer to this X,Y position within the stage map
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY TEMP_X
  LDA (STAGE_MAP),Y

  ; Start all over again if the map is not empty at this location
  BNE RAND_COORDS

  ; Also make sure that this location is not within 3 squares of the top left (where bomberman spawns)
  ; otherwise bomberman may be trapped
  CPY #3 ; Check X position
  BCS done

  LDA TEMP_Y ; Check Y position
  CMP #3
  BCC RAND_COORDS

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
.DRAW_LEVEL_TILES
{
  JSR PPUD

  LDA #0:STA CACHE_Y ; Set Y position to 0

  ; Set up pointer
  LDA #lo(OAM_CACHE):STA OAM_PTR
  LDA #hi(OAM_CACHE):STA OAM_PTR+1

  LDY #0

.loop_y
  LDA #0:STA CACHE_X ; Set X position to 0

.loop_x
  ; If debug enabled, show hidden tiles, otherwise hidden tiles become brick wall
  LDA DEBUG
  BEQ debug_off

  LDA (OAM_PTR),Y
  JMP show_tile_normally
; ---------------------------------------------------------------------------

.debug_off
  ; If tile is a hidden one, show as brick wall instead
  LDA (OAM_PTR),Y
  CMP #MAP_HIDDEN_EXIT
  BEQ show_tile_as_brick

  CMP #MAP_HIDDEN_BONUS
  BNE show_tile_normally

.show_tile_as_brick
  LDA #MAP_BRICK

.show_tile_normally
  JSR sub_CB4E
  INY
  BNE same_page

  INC OAM_PTR+1

.same_page
  INC CACHE_X
  LDA CACHE_X
  AND #MAP_WIDTH
  BEQ loop_x

  INC CACHE_Y
  LDA CACHE_Y
  CMP #MAP_HEIGHT
  BNE loop_y

  JSR TIME_AND_LIFE   ; Draw the lines "TIME" and "LEFT XX" in the status bar
  JMP PPU_RESTORE
}

; =============== S U B R O U T I N E =======================================
.sub_CB4E
{
  ; Cache Y
  STY TEMP_Y

  JSR sub_D924

  ; Copy 8 bytes from TILE_PARAM to TILE_TAB
  LDX #0

.loop
  LDA TILE_PARAM,X:STA TILE_TAB,X

  INX
  CPX #8
  BNE loop

  JSR sub_CB65

  ; Restore Y
  LDY TEMP_Y

  RTS
}

; =============== S U B R O U T I N E =======================================
.sub_CB65
{
  LDA TILE_TAB+2
  ORA TILE_TAB

  PHA
  STA PPU_ADDRESS
  LDX TILE_TAB+1:STX PPU_ADDRESS
  LDX TILE_TAB+3
  LDA TILE_MAP,X:STA PPU_DATA
  LDA TILE_MAP+1,X:STA PPU_DATA
  PLA

  STA PPU_ADDRESS

  LDA TILE_TAB+1
  CLC:ADC #&20
  STA PPU_ADDRESS

  LDA TILE_MAP+2,X:STA PPU_DATA
  LDA TILE_MAP+3,X:STA PPU_DATA

  LDA #&23
  ORA TILE_TAB

  PHA
  STA PPU_ADDRESS
  LDA TILE_TAB+4:STA PPU_ADDRESS
  TAX
  LDA PPU_DATA
  LDA PPU_DATA
  AND TILE_TAB+6
  ORA TILE_TAB+7
  TAY
  PLA

  STA PPU_ADDRESS
  STX PPU_ADDRESS
  STY PPU_DATA

  RTS
}

; =============== S U B R O U T I N E =======================================
.STAGE_CLEANUP
{
  LDX #MAX_BOMB-1
  LDA #NO

.CLEAN_BOMBS
  STA BOMB_ACTIVE,X
  DEX
  BPL CLEAN_BOMBS

  LDX #MAX_FIRE-1

.CLEAN_EXPLO
  STA FIRE_ACTIVE,X
  DEX
  BPL CLEAN_EXPLO

; =============== S U B R O U T I N E =======================================
; Remove all monsters from the stage
.^KILL_ENEMY
  LDA #ENEMY_NONE
  LDX #MAX_ENEMY-1

.KILL_LOOP
  STA ENEMY_TYPE,X
  DEX
  BPL KILL_LOOP

  RTS
}

; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR FIND_FIRE_SLOT
.next_fire_slot
{
  DEY
  BMI done

; =============== S U B R O U T I N E =======================================

.^FIND_FIRE_SLOT
  LDA FIRE_ACTIVE,Y
  BNE next_fire_slot

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Create pointer to row specified in Y within level map
.FIX_STAGE_PTR
{
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  RTS
}

; =============== S U B R O U T I N E =======================================
; Play explosion sound
.PLAY_BOOM_SOUND
{
  LDA #1:STA BOOM_SOUND

  RTS
}

; =============== S U B R O U T I N E =======================================
; Wait for start of next frame (triggered by NMI)
.NEXTFRAME
{
  LDA FRAMEDONE
  BNE NEXTFRAME

  LDA #1:STA FRAMEDONE

  RTS
}

; ---------------------------------------------------------------------------
.EXIT_ENEMY_TAB
  EQUB   2,  1,  5,  3,  1,  1,  2,  5,  6,  4 ; This table contains the type of monsters that emerge from the door after it's bombed
  EQUB   1,  1,  5,  6,  2,  4,  1,  6,  1,  5 ; one for each of the 50 levels
  EQUB   6,  5,  1,  5,  6,  8,  2,  1,  5,  7
  EQUB   4,  1,  5,  8,  6,  7,  5,  2,  4,  8
  EQUB   5,  4,  6,  5,  8,  4,  6,  5,  7,  8

; =============== S U B R O U T I N E =======================================
; Pressing the buttons
.PROCESS_BUTTONS
{
  ; Skip if we have INVULNERABLE
  LDA INVULNERABLE
  BNE skip_invulnerable_timeout

  ; Skip if we don't have INVULNERABLE_TIMER
  LDA INVULNERABLE_TIMER
  BEQ skip_invulnerable_timeout

  ; Limit check to once every 8 frames
  LDA FRAME_CNT
  AND #7
  BNE skip_invulnerable_timeout

  ; Reduce INVULNERABLE_TIMER timer
  DEC INVULNERABLE_TIMER
  BNE skip_invulnerable_timeout

  ; INVULNERABLE_TIMER has now expired and is now 0

  ; Play melody 3 (normal stage melody)
  LDA #3:STA APU_MUSIC

.skip_invulnerable_timeout
  ; If not dead, allow movement
  LDA DYING
  BEQ PROCESS_BOMBERMAN_MOVEMENTS

  ; Death animation
  LDA FRAME_CNT
  AND #&F
  BNE done

  INC BOMBMAN_FRAME
  LDA BOMBMAN_FRAME
  CMP #20
  BNE done

  LDA #YES:STA KILLED

.done
  RTS
}

; ---------------------------------------------------------------------------

.PROCESS_BOMBERMAN_MOVEMENTS
{
  LDA BOMBMAN_U
  CMP #SPR_HALFSIZE
  BNE loc_CCA4

  LDA BOMBMAN_V
  CMP #SPR_HALFSIZE
  BNE loc_CCA4

  LDY BOMBMAN_Y:STY CACHE_Y

  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X:STY CACHE_X

  LDA (STAGE_MAP),Y
  CMP #MAP_EXIT
  BEQ over_exit

  CMP #MAP_BONUS
  BNE loc_CCA4

  ; Clear the map here
  LDA #MAP_EMPTY:STA (STAGE_MAP),Y

  JSR DRAW_TILE   ; Add to TILE_TAB

  JMP loc_CEE9
}

; ---------------------------------------------------------------------------

.over_exit
{
  INC EXIT_DWELL_TIME

  LDA #0:STA KEY_TIMER

  LDA ENEMIES_LEFT
  BNE loc_CCA4

  LDA #1:STA NO_ENEMIES_LEFT

.^sub_done
  RTS
}

; ---------------------------------------------------------------------------

.loc_CCA4
{
  LDA BONUS_SPEED
  BNE FAST_MOVE
  LDA FRAME_CNT
  AND #3      ; Without fast move, slow to a quarter of the speed
  BEQ sub_done

.FAST_MOVE
  JSR GET_INPUT   ; Return to A to set the buttons P1 | P2
  BNE CASE_RIGHT

  STA KEY_TIMER ; Nothing pressed, so reset key timer
  STA LAST_INPUT

.CASE_RIGHT
  TAX
  AND #PAD_RIGHT      ; Right
  BEQ CASE_LEFT
  JSR MOVE_RIGHT

.CASE_LEFT
  TXA
  AND #PAD_LEFT       ; Left
  BEQ CASE_UP
  JSR MOVE_LEFT

.CASE_UP
  TXA
  AND #PAD_UP         ; Up
  BEQ CASE_DOWN
  JSR MOVE_UP

.CASE_DOWN
  TXA
  AND #PAD_DOWN       ; Down
  BEQ CASE_ACTION
  JSR MOVE_DOWN

.CASE_ACTION
  TXA
  AND #PAD_A ; A
  BNE CASE_A
  LDA BONUS_REMOTE    ; Use remote detonator (if you have it)
  BEQ CASE_NOTHING
  LDA LAST_INPUT
  BNE CASE_NOTHING
  TXA
  AND #PAD_B ; B
  BEQ CASE_NOTHING
  STA LAST_INPUT
  JSR DETONATE    ; Explode the bombs

.^CASE_NOTHING
  RTS
}

; ---------------------------------------------------------------------------

.CASE_A
{
  LDY BOMBMAN_Y

  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X
  LDA (STAGE_MAP),Y
  BNE CASE_NOTHING    ; Don't allow bomb placement if map is not empty here

  JSR ADJUST_BOMBMAN_HPOS ; Adjust bomberman horizontal position
  JSR ADJUST_BOMBMAN_VPOS ; Adjust bomberman vertical position

  LDX BONUS_BOMBS

.CHECK_AMMO_LEFT
  LDA BOMB_ACTIVE,X
  BEQ PLACE_BOMB

  DEX
  BPL CHECK_AMMO_LEFT

  RTS
}

; ---------------------------------------------------------------------------

.PLACE_BOMB
{
  ; Place a bomb on the map
  LDA #MAP_BOMB:STA (STAGE_MAP),Y

  ; Save current bomberman X,Y and bomb X,Y
  LDA BOMBMAN_X:STA BOMB_X,X
  LDA BOMBMAN_Y:STA BOMB_Y,X

  ; Initalise bomb vars
  LDA #0:STA BOMB_TIME_ELAPSED,X
  LDA #0:STA BOMB_UNUSED,X
  LDA #160:STA BOMB_TIME_LEFT,X

  ; Set bomb as enabled
  LDA #ENABLE:STA BOMB_ACTIVE,X

  ; Play sound 3
  LDA #3:STA APU_SOUND

  RTS
}

; =============== S U B R O U T I N E =======================================
; Move bomberman down
.MOVE_DOWN
{
  ; Check for movement outside cell
  LDA BOMBMAN_V
  CMP #SPR_HALFSIZE
  BCS advance_cell

  INC BOMBMAN_V
  JMP done
; ---------------------------------------------------------------------------

.advance_cell
  LDY BOMBMAN_Y
  INY
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X
  JSR IS_SOLID
  BNE done

  JSR ADJUST_BOMBMAN_HPOS ; Adjust bomberman horizontal position
  INC BOMBMAN_V
  LDA BOMBMAN_V
  CMP #SPR_SIZE
  BNE done

  LDA #0:STA BOMBMAN_V
  INC BOMBMAN_Y

.done
  LDA #4
  LDY #7
  JMP bomberman_movement_animation
}

; =============== S U B R O U T I N E =======================================
; Move bomberman up
.MOVE_UP
{
  LDA BOMBMAN_V
  CMP #SPR_HALFSIZE+1
  BCC advance_cell

  DEC BOMBMAN_V
  JMP done
; ---------------------------------------------------------------------------

.advance_cell
  LDY BOMBMAN_Y
  DEY
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X
  JSR IS_SOLID
  BNE done

  JSR ADJUST_BOMBMAN_HPOS ; Adjust bomberman horizontal position
  DEC BOMBMAN_V
  BPL done

  LDA #SPR_SIZE-1:STA BOMBMAN_V
  DEC BOMBMAN_Y

.done
  LDA #8
  LDY #&B
  JMP bomberman_movement_animation
}

; =============== S U B R O U T I N E =======================================
; Move bomberman left
.MOVE_LEFT
{
  LDA BOMBMAN_U
  CMP #SPR_HALFSIZE+1
  BCC advance_cell

  DEC BOMBMAN_U
  JMP done
; ---------------------------------------------------------------------------

.advance_cell
  LDY BOMBMAN_Y
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X
  DEY
  JSR IS_SOLID
  BNE done

  JSR ADJUST_BOMBMAN_VPOS ; Adjust bomberman vertical position
  DEC BOMBMAN_U
  BPL done

  LDA #SPR_SIZE-1:STA BOMBMAN_U
  DEC BOMBMAN_X

.done
  LDA #OAM_FLIP_NONE ; Show sprite normally (not flipped horizontally)
  JMP SET_OAM_ATTR
}

; =============== S U B R O U T I N E =======================================
; Move bomberman right
.MOVE_RIGHT
{
  LDA BOMBMAN_U
  CMP #SPR_HALFSIZE
  BCS advance_cell

  INC BOMBMAN_U
  JMP done
; ---------------------------------------------------------------------------

.advance_cell
  LDY BOMBMAN_Y
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY BOMBMAN_X
  INY
  JSR IS_SOLID
  BNE done

  JSR ADJUST_BOMBMAN_VPOS ; Adjust bomberman vertical position
  INC BOMBMAN_U
  LDA BOMBMAN_U
  CMP #SPR_SIZE
  BNE done

  LDA #0:STA BOMBMAN_U
  INC BOMBMAN_X

.done
  LDA #OAM_FLIP_X ; Flip sprite horizontally

.^SET_OAM_ATTR
  STA SPR_ATTR_TEMP
  LDA #0
  LDY #3
  JMP bomberman_movement_animation
}

; ---------------------------------------------------------------------------
  EQUB &60 ; ? Is this a rogue RTS ?

; =============== S U B R O U T I N E =======================================
; Adjust bomberman horizontal position
.ADJUST_BOMBMAN_HPOS
{
  LDA BOMBMAN_U
  CMP #SPR_HALFSIZE
  BCC ADJUST_RIGHT
  BEQ DONT_ADJUST
  DEC BOMBMAN_U

  RTS
; ---------------------------------------------------------------------------

.ADJUST_RIGHT
  INC BOMBMAN_U
  RTS
; ---------------------------------------------------------------------------

.DONT_ADJUST
  RTS
}

; =============== S U B R O U T I N E =======================================
; Adjust bomberman vertical position
.ADJUST_BOMBMAN_VPOS
{
  LDA BOMBMAN_V
  CMP #SPR_HALFSIZE
  BCC ADJUST_DOWN
  BEQ DONT_ADJUST2
  DEC BOMBMAN_V

  RTS
; ---------------------------------------------------------------------------

.ADJUST_DOWN
  INC BOMBMAN_V
  RTS
; ---------------------------------------------------------------------------

.DONT_ADJUST2
  RTS
}

; ---------------------------------------------------------------------------
; Bomberman animation frame advance
.bomberman_movement_animation
{
  ; Limit to once per 4 frames @ 60Hz
  PHA
  LDA FRAME_CNT
  AND #3
  CMP #2
  BNE loc_CE59

  LDA FRAME_CNT ; Not required
  PLA

  INC KEY_TIMER ; Count 

  INC BOMBMAN_FRAME
  CMP BOMBMAN_FRAME
  BCC loc_CE45

  STA BOMBMAN_FRAME
  RTS
}

; ---------------------------------------------------------------------------

.loc_CE45
{
  CPY BOMBMAN_FRAME
  BCC PLAY_FOOTSTEP_SOUND

  RTS
}

; ---------------------------------------------------------------------------

.PLAY_FOOTSTEP_SOUND
{
  STA BOMBMAN_FRAME
  CMP #4 ; If frame < 4, it's horizontal
  BCC HORIZ_FOOTSTEP

  LDA #2 ; Vertical movement
  BNE PLAY_SOUND

.HORIZ_FOOTSTEP
  LDA #1 ; Horizontal movement

.PLAY_SOUND
  STA APU_SOUND ; Play footstep sound 1 or 2 depending on bomberman animation frame

  RTS
}

; ---------------------------------------------------------------------------

.loc_CE59
{
  PLA

.^INCORRECT_FRAMENUM
  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw bomberman
.DRAW_BOMBERMAN
{
  LDA BOMBMAN_FRAME
  CMP #19
  BCS INCORRECT_FRAMENUM

  LDA SPR_ATTR_TEMP:STA SPR_ATTR
  LDY #0:STY SPR_COL

  LDA BOMBMAN_X
  CMP #8
  BCC DONT_SCROLL

  LDY #&F0
  CMP #23
  BCS DONT_SCROLL

  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_U
  SEC:SBC #&80
  TAY

.DONT_SCROLL
  STY H_SCROLL
  LDA BOMBMAN_X
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_U
  SEC:SBC #8
  SBC H_SCROLL
  STA SPR_X

  LDA BOMBMAN_Y
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_V
  ADC #23
  STA SPR_Y

  LDX BOMBMAN_FRAME
  LDA BOMBER_ANIM,X
  JMP SPR_DRAW
}

; =============== S U B R O U T I N E =======================================
.DRAW_HUMAN
{
  LDA SPR_ATTR_TEMP:STA SPR_ATTR
  LDY #3:STY SPR_COL

  LDA BOMBMAN_X
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_U
  SEC:SBC #8
  STA SPR_X

  LDA BOMBMAN_Y
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_V
  ADC #23    ; Move down a bit
  STA SPR_Y

  LDX BOMBMAN_FRAME
  LDA HUMAN_ANIM,X

  JMP SPR_DRAW
}

; ---------------------------------------------------------------------------
.HUMAN_ANIM
  ; Game completed human walk animation
  EQUB &10,&11,&12,&11

.BOMBER_ANIM
  ; Walk left/right
  EQUB 0,  1,  2,  1
  ; Walk down
  EQUB 3,  4,  5,  4
  ; Walk up
  EQUB 6,  7,  8,  7
  ; Explode
  EQUB 9, 10, 11, 12, 13, 14, 15

; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR PROCESS_BUTTONS
.loc_CEE9
{
  ; Play sound 4
  LDA #4:STA APU_SOUND

  LDA #10 ; Score 1,000
  JSR SCORE_100

  LDX EXIT_ENEMY_TYPE
  DEX:BEQ powerup_bomb ; 1 Valcom (Balloon)
  DEX:BEQ powerup_power ; 2 O'Neal (Onion)
  DEX:BEQ powerup_speed ; 3 Dahl (Barrel)
  DEX:BEQ powerup_noclip ; 4 Minvo (Happy face)
  DEX:BEQ powerup_detonator ; 5 Doria (Blob)
  DEX:BEQ powerup_bombwalk ; 6 Ovape (Ghost)
  DEX:BEQ powerup_firesuit ; 7 Pass (Tiger)
  DEX:BEQ powerup_questionmark ; 8 Pontan (Coin)

  RTS
}

; ---------------------------------------------------------------------------

.powerup_bomb
{
  ; Prevent more than 10 bombs
  LDA BONUS_BOMBS
  CMP #MAX_BOMB-1
  BEQ done

  ; Increment available bombs
  INC BONUS_BOMBS

.done
  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_power
{
  ; Prevent bomb range exceeding 5 squares
  LDA BONUS_POWER
  CMP #MAX_BOMB_RANGE*SPR_SIZE
  BEQ done

  ; Increase bomb range by 1 square
  CLC:ADC #SPR_SIZE:STA BONUS_POWER

.done
  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_speed
{
  ; Enable speed walking (4x faster)
  LDA #ENABLE:STA BONUS_SPEED

  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_noclip
{
  ; Enable noclip (walk through brick walls)
  LDA #ENABLE:STA BONUS_NOCLIP

  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_detonator
{
  ; Enable remote detonator
  LDA #ENABLE:STA BONUS_REMOTE

  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_bombwalk
{
  ; Enable walking through bombs
  LDA #ENABLE:STA BONUS_BOMBWALK

  ; Play powerup collected melody
  LDA #4:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_firesuit
{
  ; Enable firesuit (flames from explosions don't hurt)
  LDA #ENABLE:STA BONUS_FIRESUIT

  ; Play special powerup collected melody
  LDA #5:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------

.powerup_questionmark
{
  ; Enable invulnerability timer (~34 seconds @ 60Hz)
  LDA #&FF:STA INVULNERABLE_TIMER

  ; Play special powerup collected melody
  LDA #5:STA APU_MUSIC

  RTS
}

; =============== S U B R O U T I N E =======================================
; Check map for current tile being "solid"
;   Sets the zero flag to 1 for solid, or 0 for not solid
.IS_SOLID
{
  LDA (STAGE_MAP),Y
  BEQ done ; Empty space

  ; Exit door can always be walked on
  CMP #MAP_EXIT
  BEQ done

  ; Bonus items need to be not solid so we can collect them
  CMP #MAP_BONUS
  BEQ done

  ; For bricks and items hidden behind bricks, a further check for noclip powerup is needed
  CMP #MAP_BRICK
  BEQ CHECK_NOCLIP

  CMP #MAP_HIDDEN_EXIT
  BEQ CHECK_NOCLIP

  CMP #MAP_HIDDEN_BONUS
  BEQ CHECK_NOCLIP

  ; For bombs a further check for bombwalk powerup is needed
  CMP #MAP_BOMB
  BEQ CHECK_BOMBWALK

.done
  RTS
; ---------------------------------------------------------------------------

  .CHECK_NOCLIP
  {
    LDA BONUS_NOCLIP:EOR #1

    RTS
  }
; ---------------------------------------------------------------------------

  .CHECK_BOMBWALK
  {
    LDA BONUS_BOMBWALK:EOR #1

    RTS
  }
}

; =============== S U B R O U T I N E =======================================
; Return to A to set the buttons P1 | P2
.GET_INPUT
{
  ; If in demo mode, read the next key from demo data, otherwise read the pads
  LDA DEMOPLAY
  BEQ NOT_DEMO

  ; Decrease timer, then advance to next pad state upon timeout
  LDA DEMOKEY_PAD1
  DEC DEMOKEY_TIMEOUT
  BNE SKIP_DEMO_KEY

  ; Get next timer and pad state from demo data
  PHA
  LDY #0
  LDA (DEMOKEY_DATA),Y:STA DEMOKEY_TIMEOUT
  JSR DEMO_GETNEXT
  LDA (DEMOKEY_DATA),Y:STA DEMOKEY_PAD1
  JSR DEMO_GETNEXT
  PLA

  ; Wait for timer to elapse before getting next demo padstate
.SKIP_DEMO_KEY
  RTS

; ---------------------------------------------------------------------------

  ; Not in demo mode, so read (and combine) actual pads
.NOT_DEMO
  LDA JOYPAD1
  ORA JOYPAD2

  RTS
}

; =============== S U B R O U T I N E =======================================
; Read next byte from DEMO input data
.DEMO_GETNEXT
{
  ; Advance pointer (lo)
  INC DEMOKEY_DATA
  ; Check for overflow to next memory page
  BNE DEMO_GETNEXT_HI

  ; Advance pointer (hi)
  INC DEMOKEY_DATA+1

.DEMO_GETNEXT_HI
  RTS
}

; =============== S U B R O U T I N E =======================================
; Enemy AI
.THINK
{
  LDA #0:STA ENEMIES_LEFT
  LDA #&C0:STA byte_6B

  LDX #MAX_ENEMY-1

.THINK_LOOP
  LDA ENEMY_TYPE,X
  BEQ THINK_NEXT

  CMP #9
  BCS loc_CFC5

  INC ENEMIES_LEFT

.loc_CFC5
  LDY ENEMY_AI_TIMER,X
  BEQ loc_CFCF

  DEC ENEMY_AI_TIMER,X
  BNE THINK_NEXT

.loc_CFCF
  ASL A
  TAY
  JSR ENEMY_SAVE ; Cache current monster attributes

  ; Use THINK_PROC jump table, but return to RETURN_POINT afterwards
  LDA #hi(RETURN_POINT-1):PHA
  LDA #lo(RETURN_POINT-1):PHA
  LDA THINK_PROC-1,Y:PHA
  LDA THINK_PROC-2,Y:PHA

  RTS

; ---------------------------------------------------------------------------
.RETURN_POINT 
  JSR ENEMY_LOAD ; Restore current monster attributes after THINK proc
  JSR loc_D006

.THINK_NEXT
  DEX
  BPL THINK_LOOP

.^THINK_END
  RTS
}

; =============== S U B R O U T I N E =======================================
.sub_CFED
{
  LDA BONUS_AVAILABLE
  CLC:ADC #&2C
  STA M_FRAME

  LDA EXTRA_BONUS_ITEM_X:STA M_X
  LDA EXTRA_BONUS_ITEM_Y:STA M_Y

  LDA #SPR_HALFSIZE
  STA M_U
  STA M_V

  LDA #0
  BEQ loc_D010

.^loc_D006
  LDA M_TYPE
  BEQ THINK_END

  CMP #11
  BEQ loc_D08C

  LDA byte_48

.loc_D010
  STA SPR_ATTR

  LDY #0:STY byte_50

  LDA M_X
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  ROL byte_50
  CLC:ADC M_U
  STA byte_4F

  LDA byte_50
  ADC #0
  STA byte_50

  LDA byte_4F
  SEC:SBC #8
  STA byte_4F

  LDA byte_50
  SBC #0
  STA byte_50

  LDA byte_4F
  SEC:SBC H_SCROLL
  STA byte_4F

  LDA byte_50
  SBC #0
  BNE done

  LDA byte_4F
  CMP #&F8
  BCS done

  STA SPR_X
  LDA M_Y
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC M_V
  ADC #&17
  STA SPR_Y
  LDY M_FRAME
  LDA MONSTER_ATTR,Y:STA SPR_COL
  LDA MONSTER_TILE,Y
  JSR SPR_DRAW

  LDA M_FRAME
  CMP #&20
  BCS done

  ; No need to do collision detection if we're already dead
  LDA DYING
  BNE done

  ; Check for invulnerability
  LDA INVULNERABLE_TIMER
  BNE done

  ; Compare monster X with our X
  LDA M_X
  CMP BOMBMAN_X
  BNE done

  ; Compare monster Y with our Y
  LDA M_Y
  CMP BOMBMAN_Y
  BNE done

  ; At this point, we don't have invulnerability and have collided with a monster

  ; Play sound 5
  LDA #5:STA APU_SOUND

  ; Mark as DYING by monster
  LDA #1:STA DYING

  ; Start death animation
  LDA #12:STA BOMBMAN_FRAME

.done
  RTS
}

; ---------------------------------------------------------------------------

.loc_D08C
  TXA
  PHA
  LDA #0
  STA SPR_ATTR

  LDY #0
  STY byte_50

  LDA M_X
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  ROL byte_50
  CLC:ADC M_U
  STA byte_4F

  LDA byte_50
  ADC #0
  STA byte_50

  LDA byte_4F
  SEC:SBC #8
  STA byte_4F

  LDA byte_50
  SBC #0
  STA byte_50

  LDA byte_4F
  SEC:SBC H_SCROLL
  STA byte_4F

  LDA byte_50
  SBC #0
  BNE loc_D0F7

  LDA byte_4F
  CMP #&F8
  BCS loc_D0F7

  STA SPR_X

  LDA M_Y
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC M_V
  ADC #&1B
  STA SPR_Y

  LDA byte_4B
  CLC:ADC M_FACE
  CMP #&10
  BCC loc_D0E3

  LDA #&10

.loc_D0E3
  ; Multiply A by 3, then store in X to be used for indexing score sprite lookup table
  STA TEMP_X
  ASL A
  CLC:ADC TEMP_X
  TAX

  LDY byte_6B

  ; Draw up to 3 mini tiles to represent the score
  JSR DRAW_SCORE_TILE
  JSR DRAW_SCORE_TILE
  JSR DRAW_SCORE_TILE

  STY byte_6B

.loc_D0F7
  PLA
  TAX

  RTS


; =============== S U B R O U T I N E =======================================
.DRAW_SCORE_TILE
{
  ; If next tile to draw is null, skip it
  LDA SCORE_TILES,X
  BEQ no_draw

  PHA
  LDA SPR_Y:STA SPR_TAB,Y ; OAM - sprite Y position
  INY
  PLA

  STA SPR_TAB,Y ; OAM - tile index number

  INY
  LDA #%00000001:STA SPR_TAB,Y ; OAM - attributes

  INY
  LDA SPR_X:STA SPR_TAB,Y ; OAM - sprite X position

  INY
  CLC:ADC #8
  STA SPR_X

.no_draw
  INX
  INY:DEY
  BNE done

.SCORE_TILES ; Label is here to skip over 0th entry
  LDY #&FC

.done
  RTS

; ---------------------------------------------------------------------------
  ; Score tiles
  EQUB SCORE_1,SCORE_00,  0 ; 1 - 100
  EQUB SCORE_2,SCORE_00,  0 ; 2 - 200
  EQUB SCORE_4,SCORE_00,  0 ; 3 - 400
  EQUB SCORE_8,SCORE_00,  0 ; 4 - 800
  EQUB SCORE_10,SCORE_00,  0 ; 5 - 1,000
  EQUB SCORE_20,SCORE_00,  0 ; 6 - 2,000
  EQUB SCORE_40,SCORE_00,  0 ; 7 - 4,000
  EQUB SCORE_80,SCORE_00,  0 ; 8 - 8,000

  EQUB SCORE_1,SCORE_00,SCORE_00 ; 9 - 10,000
  EQUB SCORE_2,SCORE_00,SCORE_00 ; 10 - 20,000
  EQUB SCORE_4,SCORE_00,SCORE_00 ; 11 - 40,000
  EQUB SCORE_8,SCORE_00,SCORE_00 ; 12 - 80,000
  EQUB SCORE_10,SCORE_00,SCORE_00 ; 13 - 100,000
  EQUB SCORE_20,SCORE_00,SCORE_00 ; 14 - 200,000
  EQUB SCORE_40,SCORE_00,SCORE_00 ; 15 - 400,000
  EQUB SCORE_80,SCORE_00,SCORE_00 ; 16 - 800,000
}

.MONSTER_TILE
  ; Animation sprites (one set for each of the 8 monsters)
  EQUB &18,&19,&1A,&19 ; Valcom (Balloon)
  EQUB &1C,&1D,&1E,&1D ; O'Neal (Onion)
  EQUB &20,&21,&22,&21 ; Dahl (Barrel)
  EQUB &24,&25,&26,&25 ; Minvo (Happy face)
  EQUB &28,&29,&2A,&29 ; Doria (Blob)
  EQUB &2C,&2D,&2E,&2D ; Ovape (Ghost)
  EQUB &30,&31,&32,&31 ; Pass (Tiger)
  EQUB &34,&35,&36,&35 ; Pontan (Coin)

  ; First death sprite (one for each of the 8 monsters)
  EQUB &1B,&1F,&23,&27,&2B,&2F,&33,&37

  ; Rest of monster death animation sprites
  EQUB &14,&15,&16,&17

  ; Extra bonus items
  EQUB &38,&39,&3A,&3B,&3C,&3D

.MONSTER_ATTR
  EQUB   1,  1,  1,  1,  3,  3,  3,  3,  2,  2,  2,  2,  1,  1,  1,  1
  EQUB   3,  3,  3,  3,  2,  2,  2,  2,  1,  1,  1,  1,  1,  2,  1,  2
  EQUB   1,  3,  2,  1,  3,  2,  1,  1,  1,  1,  1,  1,  1,  0,  1,  2
  EQUB   3

.MONSTER_SCORES
  ; Scores for killing monsters
  EQUB   1 ; 100
  EQUB   1 ; 100 - Valcom
  EQUB   2 ; 200 - O'Neal
  EQUB   4 ; 400 - Dahl
  EQUB   8 ; 800 - Minvo
  EQUB  10 ; 1,000 - Ovape
  EQUB  20 ; 2,000 - Doria
  EQUB  40 ; 4,000 - Pass
  EQUB  80 ; 8,000 - Pontan
  EQUB 100 ; 10,000
  EQUB 200 ; 20,000

  ; Score multipliers ( * 20,000 )
  EQUB   2 ; 40,000
  EQUB   4 ; 80,000
  EQUB   5 ; 100,000
  EQUB  10 ; 200,000
  EQUB  20 ; 400,000
  EQUB  40 ; 800,000 (max score)

; =============== S U B R O U T I N E =======================================
; Cache monster[X] attributes to zero page
.ENEMY_SAVE
{
  STX M_ID

  LDA ENEMY_TYPE,X:STA M_TYPE
  LDA ENEMY_X,X:STA M_X
  LDA ENEMY_U,X:STA M_U
  LDA ENEMY_Y,X:STA M_Y
  LDA ENEMY_V,X:STA M_V
  LDA ENEMY_FRAME,X:STA M_FRAME
  LDA ENEMY_AI_TIMER,X:STA M_AI_TIMER
  LDA byte_5BC,X:STA byte_48
  LDA byte_5C6,X:STA byte_49
  LDA ENEMY_FACE,X:STA M_FACE
  LDA byte_5DA,X:STA byte_4B
  LDA byte_5E4,X:STA byte_4C

  RTS
}

; =============== S U B R O U T I N E =======================================
; Restore monster[X] attributes from zero page
.ENEMY_LOAD
{
  LDX M_ID

  LDA M_TYPE:STA ENEMY_TYPE,X
  LDA M_X:STA ENEMY_X,X
  LDA M_U:STA ENEMY_U,X
  LDA M_Y:STA ENEMY_Y,X
  LDA M_V:STA ENEMY_V,X
  LDA M_FRAME:STA ENEMY_FRAME,X
  LDA M_AI_TIMER:STA ENEMY_AI_TIMER,X
  LDA byte_48:STA byte_5BC,X
  LDA byte_49:STA byte_5C6,X
  LDA M_FACE:STA ENEMY_FACE,X
  LDA byte_4B:STA byte_5DA,X
  LDA byte_4C:STA byte_5E4,X

  RTS
}

; ---------------------------------------------------------------------------
; Jump table
.THINK_PROC
  EQUW THINK_0-1 ; Valcom (Balloon)
  EQUW THINK_1-1 ; O'Neal (Onion)
  EQUW THINK_2-1 ; Dahl (Barrel)
  EQUW THINK_3-1 ; Minvo (Happy face)
  EQUW THINK_4-1 ; Doria (Blob)
  EQUW THINK_5-1 ; Ovape (Ghost)
  EQUW THINK_6-1 ; Pass (Tiger)
  EQUW THINK_7-1 ; Pontan (Coin)
  EQUW THINK_8-1
  EQUW THINK_9-1
  EQUW THINK_A-1

; ---------------------------------------------------------------------------

.THINK_A
{
  DEC byte_49
  BNE think_done

  LDA #0:STA M_TYPE

  RTS
}

; ---------------------------------------------------------------------------

.THINK_9
{
  DEC byte_49
  BNE think_done

  LDA #10:STA byte_49

  INC M_FRAME
  LDA M_FRAME
  CMP #44
  BNE think_done

  LDA byte_4B
  CLC:ADC M_FACE
  TAY
  CPY #11
  BCC add_score_hundreds ; If < 11 add score from MONSTER_SCORES

  CPY #16
  BCC add_score_multiple ; If < 16 add 20,000 * MONSTER_SCORES to score

  ; If >=16 add max score (800,000)
  LDY #16

.add_score_multiple
  LDA MONSTER_SCORES,Y
  TAX

.score_multiply
  LDA #200:JSR SCORE_100 ; Score 20,000
  DEX
  BNE score_multiply

  JMP loc_D29A
; ---------------------------------------------------------------------------

.add_score_hundreds
  LDA MONSTER_SCORES,Y ; Get score (in hundreds)
  JSR SCORE_100

.loc_D29A
  LDA #11:STA M_TYPE
  LDA #100:STA byte_49

.^think_done
  RTS
}

; ---------------------------------------------------------------------------
.THINK_8
{
  DEC byte_49
  BNE done

  LDA #10:STA M_TYPE
  LDA #40:STA M_FRAME
  LDA #20:STA byte_49

.done
  RTS
}

; ---------------------------------------------------------------------------

.done_think_4
  RTS

; ---------------------------------------------------------------------------

.THINK_4
{
  LDA #&10 ; Doria
  LDY #&13

  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

  LDA FRAME_CNT
  AND #3
  BNE done_think_4

  JMP loc_D310
}

; ---------------------------------------------------------------------------

.done_think_2
  RTS

; ---------------------------------------------------------------------------
.THINK_2
{
  LDA #8 ; Dahl
  LDY #&B

  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

  LDA FRAME_CNT
  AND #3
  BEQ done_think_2

  DEC byte_4C
  LDA byte_4C
  CMP #&96
  BCS loc_D2E4

  JSR TURN_HORIZONTALLY

.loc_D2E4
  JMP loc_D33F
}

; ---------------------------------------------------------------------------

.done_think_1
  RTS

; ---------------------------------------------------------------------------
.THINK_1
{
  LDA #4 ; O'Neal
  LDY #7

  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

  LDA FRAME_CNT
  AND #3
  BEQ done_think_1

  DEC byte_4C
  LDA byte_4C
  CMP #&96
  BCS loc_D303

  JSR TURN_VERTICALLY

.loc_D303
  JMP loc_D33F
}

; ---------------------------------------------------------------------------
.THINK_3
{
  LDA #&C ; Minvo
  LDY #&F

  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

.^loc_D310
  DEC byte_4C
  LDA byte_4C
  CMP #200
  JMP loc_D337
}

; ---------------------------------------------------------------------------

.THINK_SKIP
  RTS

; ---------------------------------------------------------------------------

.THINK_5
{
  LDA #20 ; Ovape
  LDY #23

  JMP loc_D325
}

; ---------------------------------------------------------------------------
.THINK_0
{
  LDA #0 ; Valcom
  LDY #3

.^loc_D325
  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

  LDA FRAME_CNT
  AND #1
  BEQ THINK_SKIP

  DEC byte_4C
  LDA byte_4C
  CMP #20

.^loc_D337
  BCS loc_D33F

  JSR TURN_VERTICALLY
  JSR TURN_HORIZONTALLY

.^loc_D33F
  LDA byte_49
  BEQ loc_D365

  DEC byte_49
  LDA M_FACE

  JSR STEP_MONSTER
  BEQ done ; No collision

  ; Something was hit
  CMP #3
  BCC loc_D360

  LDY M_FACE
  LDA byte_D412,Y:STA M_FACE
  LDA #0:STA byte_4C
  LDA #&60:STA byte_49

  RTS

; ---------------------------------------------------------------------------

.loc_D360
  LDA #0:STA byte_49

.done
  RTS
; ---------------------------------------------------------------------------

.loc_D365
  JSR RAND

  PHA
  AND #&18
  ASL A:ASL A ; A = A * 4
  CLC:ADC #&20
  STA byte_49
  PLA

  ROL A:ROL A:ROL A ; A = A << 3
  AND #3
  CLC:ADC #1
  STA M_FACE

  RTS
}

; =============== S U B R O U T I N E =======================================
.sub_D37E
{
  LDY #0
  LDA M_FACE
  CMP #3
  BCC done

  LDY #&40

.done
  STY byte_48

  RTS
}

; ---------------------------------------------------------------------------
.THINK_7
{
  LDA #&1C ; Pontan
  LDY #&1F

  JSR ENEMY_ADVANCE_FRAME

  LDY #0
  LDA M_FRAME
  CMP #&1D
  BNE loc_D39C

  LDY #&40

.loc_D39C
  STY byte_48
  JMP loc_D3AB
}

; ---------------------------------------------------------------------------
.THINK_6
{
  LDA #&18 ; Pass
  LDY #&1B

  JSR ENEMY_ADVANCE_FRAME
  JSR sub_D37E

.^loc_D3AB
  LDA byte_4C
  BEQ loc_D3B4

  DEC byte_4C
  BNE loc_D3BA

  RTS
; ---------------------------------------------------------------------------

.loc_D3B4
  JSR TURN_VERTICALLY
  JSR TURN_HORIZONTALLY

.loc_D3BA
  LDA M_FACE
  ASL A
  ORA byte_4B
  TAY
  LDA byte_D412+5,Y:STA byte_53
  TAY
  LDA byte_D412+&F,Y:STA byte_52
  JSR sub_D454
  AND byte_52
  BEQ loc_D3E0

  LDA byte_53:STA M_FACE

  LDA #1
  EOR byte_4B
  STA byte_4B

  LDA #0:STA byte_49

.loc_D3E0
  INC byte_49
  LDA byte_49
  CMP #&1F
  BCC loc_D3EE

  LDA #1
  EOR byte_4B
  STA byte_4B

.loc_D3EE
  LDA M_FACE
  JSR STEP_MONSTER
  BEQ done ; No collision

  ; Something was hit
  CMP #3
  BCS loc_D406

  INC M_FACE
  LDA M_FACE
  CMP #5
  BNE done

  LDA #1
  STA M_FACE

.done
  RTS
; ---------------------------------------------------------------------------

.loc_D406
  LDA #&60:STA byte_4C
  LDY M_FACE
  LDA byte_D412,Y:STA M_FACE

  RTS
}

; ---------------------------------------------------------------------------
.byte_D412
  EQUB   0,  3,  4,  1,  2
  EQUB   1,  4,  4,  2,  1,  3,  2,  4,  3,  1
  EQUB   0,  1,  2,  4,  8

; =============== S U B R O U T I N E =======================================
.TURN_HORIZONTALLY
{
  LDA DYING
  BNE NO_VTURN

  LDA M_Y
  CMP BOMBMAN_Y
  BNE NO_VTURN    ; IF BY != MY, then return
  
  LDA M_X
  CMP BOMBMAN_X
  LDA #1
  BCC FACE_RIGHT  ; IF BX > MX, go right, otherwise go left
  
  LDA #3

.FACE_RIGHT
  STA M_FACE

.^NO_VTURN
  RTS
}

; =============== S U B R O U T I N E =======================================
.TURN_VERTICALLY
{
  LDA DYING
  BNE NO_VTURN

  LDA M_X
  CMP BOMBMAN_X
  BNE NO_HTURN    ; IF BX != MX, then return
  
  LDA M_Y
  CMP BOMBMAN_Y
  LDA #4
  BCC FACE_DOWN   ; IF BY > MY, then go down, otherwise go up
  
  LDA #2

.FACE_DOWN
  STA M_FACE

.NO_HTURN
  RTS
}

; =============== S U B R O U T I N E =======================================
.sub_D454
{
  LDA #0:STA byte_51

  LDA M_U
  CMP #SPR_HALFSIZE
  BNE loc_D462

  LDA M_V
  CMP #SPR_HALFSIZE

.loc_D462
  BNE loc_D4BD

  LDY M_Y
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY M_X
  INY
  JSR ENEMY_COLLISION
  BNE loc_D47C

  LDA #1:STA byte_51

.loc_D47C
  DEY
  DEY

  JSR ENEMY_COLLISION
  BNE loc_D489

  LDA #4
  ORA byte_51
  STA byte_51

.loc_D489
  LDY M_Y
  DEY
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY M_X
  JSR ENEMY_COLLISION
  BNE loc_D4A3
  LDA #2
  ORA byte_51
  STA byte_51

.loc_D4A3
  LDY M_Y
  INY
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  LDY M_X
  JSR ENEMY_COLLISION
  BNE loc_D4BD
  LDA #8
  ORA byte_51
  STA byte_51

.loc_D4BD
  LDA byte_51

.^enemy_collision_done
  RTS
}

; =============== S U B R O U T I N E =======================================
.ENEMY_COLLISION
{
  ; Look what's here on the map
  LDA (STAGE_MAP),Y

  ; Is it empty?
  BEQ enemy_collision_done

  ; Is it an exit door?
  CMP #MAP_EXIT
  BEQ enemy_collision_done

  ; Is it a bonus item?
  CMP #MAP_BONUS
  BEQ enemy_collision_done

  ; Is is a brick wall?
  CMP #MAP_BRICK
  BEQ BRICK_WALL

  RTS
}

; ---------------------------------------------------------------------------

.BRICK_WALL
{
  LDA M_TYPE

  CMP #ENEMY_DORIA      ; Enemies 5/6/8 (Doria/Ovape/Pontan) can walk through brick walls
  BEQ enemy_collision_done

  CMP #ENEMY_OVAPE
  BEQ enemy_collision_done

  CMP #ENEMY_PONTAN

  RTS
}

; =============== S U B R O U T I N E =======================================
; Take a step with this enemy (gaze direction in A)
.STEP_MONSTER
{
  LDX #MAP_EMPTY:STX ENEMY_HIT

  ; Check for looking right
  TAX
  CMP #GAZE_RIGHT
  BNE CASE_NOT_RIGHT

  JSR STEP_ENEMY_RIGHT

  ; Check for looking left
.CASE_NOT_RIGHT
  TXA
  CMP #GAZE_LEFT
  BNE CASE_NOT_LEFT

  JSR STEP_ENEMY_LEFT

  ; Check for looking up
.CASE_NOT_LEFT
  TXA
  CMP #GAZE_UP
  BNE CASE_NOT_UP

  JSR STEP_ENEMY_UP

  ; Check for looking down
.CASE_NOT_UP
  TXA
  CMP #GAZE_DOWN
  BNE done

  JSR STEP_ENEMY_DOWN

.done
  LDA ENEMY_HIT

  RTS
}

; =============== S U B R O U T I N E =======================================
; Move enemy downwards
.STEP_ENEMY_DOWN
{
  ; If vertical offset < half sprite, then increment, otherwise move down to next cell
  LDA M_V
  CMP #SPR_HALFSIZE
  BCS next_cell

  INC M_V

  RTS
; ---------------------------------------------------------------------------

.next_cell
  ; See what's on the map one cell below
  LDY M_Y
  INY

  ; Set pointer to potential new cell
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  ; Do a collision detect with that new cell
  LDY M_X
  JSR ENEMY_COLLISION

  ; If we can't move to new cell, record what stopped us and finish here
  BNE enemy_step_done

  ; We can move here, so make sure we are aligned horizontally
  JSR ADJUST_ENEMY_HPOS

  ; Increment Y offset
  INC M_V

  ; If offset not overflowed, finish here
  LDA M_V
  CMP #SPR_SIZE
  BNE done

  ; Move into next cell
  LDA #0:STA M_V
  INC M_Y

.done
  RTS

; ---------------------------------------------------------------------------

.^enemy_step_done
  ; Cache what entity stopped enemy moving
  STA ENEMY_HIT

  RTS
}

; =============== S U B R O U T I N E =======================================
; Move enemy upwards
.STEP_ENEMY_UP
{
  ; If vertical offset >= half sprite, then decrement, otherwise move up to next cell
  LDA M_V
  CMP #SPR_HALFSIZE+1
  BCC next_cell

  DEC M_V

  RTS

; ---------------------------------------------------------------------------

.next_cell
  ; See what's on the map one cell above
  LDY M_Y
  DEY

  ; Set pointer to potential new cell
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  ; Do a collision detect with that new cell
  LDY M_X
  JSR ENEMY_COLLISION

  ; If we can't move here, record what stopped us and finish
  BNE enemy_step_done

  JSR ADJUST_ENEMY_HPOS

  ; Move offset upwards
  DEC M_V

  ; If new offset >= 0 then finish here
  BPL done

  ; Move up one cell and set offset to bottom
  LDA #SPR_SIZE-1:STA M_V
  DEC M_Y

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Move enemy left
.STEP_ENEMY_LEFT
{
  ; If horizontal offset >= half sprite, then decrement, otherwise move left to next cell
  LDA M_U
  CMP #SPR_HALFSIZE+1
  BCC next_cell

  DEC M_U

  RTS
; ---------------------------------------------------------------------------

.next_cell
  ; See what's on the map one cell left
  LDY M_Y

  ; Set pointer to potential new cell
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  ; Do a collision detect with that new cell
  LDY M_X
  DEY
  JSR ENEMY_COLLISION

  ; If we can't move here, record what stopped us and finish
  BNE enemy_step_done

  JSR ADJUST_ENEMY_VPOS

  ; Move offset left
  DEC M_U

  ; If new offset >= 0 then finish here
  BPL done

  ; Move left one cell and set offset to right
  LDA #SPR_SIZE-1:STA M_U
  DEC M_X

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Move enemy right
.STEP_ENEMY_RIGHT
{
  ; If horizontal offset < half sprite, then increment, otherwise move right to next cell
  LDA M_U
  CMP #SPR_HALFSIZE
  BCS next_cell

  INC M_U

  RTS
; ---------------------------------------------------------------------------

.next_cell
  ; See what's on the map one cell right
  LDY M_Y

  ; Set pointer to potential new cell
  LDA MULT_TABY,Y:STA STAGE_MAP
  LDA MULT_TABX,Y:STA STAGE_MAP+1

  ; Do a collision detect with that new cell
  LDY M_X
  INY
  JSR ENEMY_COLLISION

  ; If we can't move to new cell, record what stopped us and finish here
  BNE enemy_step_done

  ; We can move here, so make sure we are aligned vertically
  JSR ADJUST_ENEMY_VPOS

  ; Increment X offset
  INC M_U

  ; If offset not overflowed, finish here
  LDA M_U
  CMP #SPR_SIZE
  BNE done

  ; Move into next cell
  LDA #0:STA M_U
  INC M_X

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Advance enemy horizontal offset position up to half sprite width
.ADJUST_ENEMY_HPOS
{
  LDA M_U
  CMP #SPR_HALFSIZE
  BCC under_threshold
  BEQ at_threshold

  ; Over so decrement
  DEC M_U

  RTS
; ---------------------------------------------------------------------------

.under_threshold
  INC M_U

  RTS ; *** Not needed ***
; ---------------------------------------------------------------------------

.at_threshold
  RTS
}

; =============== S U B R O U T I N E =======================================
; Advance enemy vertical offset position up to half sprite height
.ADJUST_ENEMY_VPOS
{
  LDA M_V
  CMP #SPR_HALFSIZE
  BCC under_threshold
  BEQ at_threshold

  ; Over so decrement
  DEC M_V

  RTS
; ---------------------------------------------------------------------------

.under_threshold
  INC M_V

  RTS ; *** Not needed ***
; ---------------------------------------------------------------------------

.at_threshold
  RTS
}

; =============== S U B R O U T I N E =======================================
; Advance enemy animation frame
; A = minimum frame number, Y = maximum frame number
.ENEMY_ADVANCE_FRAME
{
  ; Limit to once every 8 frames (7.5/sec @ 60Hz)
  PHA
  LDA FRAME_CNT
  AND #7
  BNE done
  PLA

  ; Advance frame
  INC M_FRAME

  ; Check for current frame being prior to first frame
  CMP M_FRAME
  BCC compare_to_end

.restart_animation
  STA M_FRAME ; Reset animation to first frame

  RTS

; ---------------------------------------------------------------------------

.compare_to_end
  ; Check for current frame being past last frame
  CPY M_FRAME
  BCC restart_animation

  RTS

; ---------------------------------------------------------------------------

.done
  PLA

  RTS
}

; =============== S U B R O U T I N E =======================================
.SPR_DRAW
{
  STX SPR_SAVEDX
  STY SPR_SAVEDY

  ASL A
  PHA
  AND #&E
  STA SPR_ID
  PLA

  ASL A
  AND #&E0
  ORA SPR_ID
  STA SPR_ID

  LDA SPR_TAB_INDEX
  INC SPR_TAB_INDEX
  CLC:ADC SPR_TAB_TOGGLE
  CMP #12
  BCC INDEX_UNBOUND

  SBC #10

.INDEX_UNBOUND
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  TAY
  LDA SPR_ATTR ; Check for horizontal flip
  BNE loc_D622

  ; Going left (not flipped)
  JSR SPR_WRITE_OBJ_HALF ; Writes one of the halves (8x16) of the sprite
  INC SPR_ID

  JMP loc_D629
; ---------------------------------------------------------------------------

.loc_D622
  ; Going right (horizontally flipped)
  INC SPR_ID
  JSR SPR_WRITE_OBJ_HALF ; Writes one of the halves (8x16) of the sprite
  DEC SPR_ID

.loc_D629
  ; Other half
  JSR SPR_WRITE_OBJ_HALF ; Writes one of the halves (8x16) of the sprite

  LDX SPR_SAVEDX
  LDY SPR_SAVEDY

  RTS
}

; =============== S U B R O U T I N E =======================================
.SPR_WRITE_OBJ_HALF
{
  ; Upper half of sprite
  LDA SPR_Y ; OAM byte 0 (Y position)
  STA SPR_TAB,Y

  LDA SPR_ID
  PHA
  STA SPR_TAB+1,Y ; OAM byte 1 (Tile index)

  LDA SPR_COL
  ORA SPR_ATTR
  STA SPR_TAB+2,Y ; ; OAM byte 2 (Attributes - Palette 00..03/Priority 20/H-flip 40/V-flip 80)

  LDA SPR_X
  STA SPR_TAB+3,Y ; OAM byte 3 (X position)

  ; Lower half of sprite
  LDA SPR_Y
  CLC:ADC #8
  STA SPR_TAB+4,Y ; Y position + 8 (below)

  PLA
  CLC:ADC #16
  STA SPR_TAB+5,Y ; Tile index + 16

  LDA SPR_COL
  ORA SPR_ATTR
  STA SPR_TAB+6,Y ; Attributes

  LDA SPR_X
  STA SPR_TAB+7,Y ; X position

  ; Y = Y + 8
  TYA
  CLC:ADC #8
  TAY

  ; SPR_X = SPR_X + 8
  LDA SPR_X
  CLC:ADC #8
  STA SPR_X

  RTS
}

; =============== S U B R O U T I N E =======================================
.RAND
{
  LDA SEED
  ROL A:ROL A
  EOR #&41
  ROL A:ROL A
  EOR #&93
  ADC SEED+1
  STA SEED

  ROL A:ROL A
  EOR #&12
  ROL A:ROL A
  ADC SEED+2
  STA SEED+1

  ADC SEED
  INC SEED+2
  BNE RAND2

  PHA
  LDA SEED+3
  CLC:ADC #&1D
  STA SEED+3
  PLA

.RAND2
  EOR SEED+3
  RTS
}

; =============== S U B R O U T I N E =======================================
.SPAWN_MONSTERS
{
  ; Set pointer into monster tab based on the current level
  LDA STAGE
  CMP #(MAP_LEVELS/2)+1
  BCC early_levels

  SBC #(MAP_LEVELS/2)
  LDX #lo(MONSTER_TAB2)
  LDY #hi(MONSTER_TAB2)
  BNE save_pointer

.early_levels
  LDX #lo(MONSTER_TAB)
  LDY #hi(MONSTER_TAB)

.save_pointer
  STX MTAB_PTR
  STY MTAB_PTR+1

  SEC:SBC #1
  ASL A
  STA TEMP_X

  ASL A:ASL A
  CLC:ADC TEMP_X
  TAY
  LDX #MAX_ENEMY-1

.enemy_loop
  LDA (MTAB_PTR),Y:STA ENEMY_TYPE,X
  BEQ next_enemy

  SEC:SBC #1
  ASL A:ASL A
  STA ENEMY_FRAME,X

  ; Position X and Y offsets in centre of sprite cell
  LDA #SPR_HALFSIZE
  STA ENEMY_U,X
  STA ENEMY_V,X

  ; Set enemy face to a random number between 1 and 4
  JSR RAND
  AND #3
  CLC:ADC #1
  STA ENEMY_FACE,X

  ; Cache Y
  STY TEMP_Y3

  ; Find an X coordinate >= 5
.newxcoord
  JSR RAND_COORDS
  LDA TEMP_X
  CMP #5
  BCC newxcoord

  ; Save the new X coordinate
  STA ENEMY_X,X

  LDA TEMP_Y:STA ENEMY_Y,X

  LDA #0
  STA ENEMY_AI_TIMER,X
  STA byte_5DA,X
  STA byte_5C6,X
  STA byte_5E4,X

  ; Restore Y
  LDY TEMP_Y3

.next_enemy
  INY
  DEX
  BPL enemy_loop

  RTS
}

; ---------------------------------------------------------------------------
; Table of monster types for every one of the 50 levels
; On each stage, there is up to 10 monsters
.MONSTER_TAB
  EQUB    1, 1, 1, 1, 1, 1, 0, 0, 0, 0
  EQUB    1, 1, 1, 2, 2, 2, 0, 0, 0, 0
  EQUB    1, 1, 2, 2, 3, 3, 0, 0, 0, 0
  EQUB    1, 2, 3, 3, 4, 4, 0, 0, 0, 0
  EQUB    2, 2, 2, 2, 3, 3, 3, 0, 0, 0
  EQUB    2, 2, 3, 3, 3, 4, 4, 0, 0, 0
  EQUB    2, 2, 3, 3, 3, 5, 5, 0, 0, 0
  EQUB    2, 3, 3, 4, 4, 4, 4, 0, 0, 0
  EQUB    2, 3, 4, 4, 4, 4, 6, 0, 0, 0
  EQUB    2, 3, 4, 5, 6, 6, 6, 0, 0, 0
  EQUB    2, 3, 3, 4, 4, 4, 5, 6, 0, 0
  EQUB    2, 3, 4, 5, 6, 6, 6, 6, 0, 0
  EQUB    3, 3, 3, 4, 4, 4, 6, 6, 0, 0
  EQUB    5, 5, 5, 5, 5, 5, 5, 7, 0, 0
  EQUB    3, 4, 4, 4, 6, 6, 6, 7, 0, 0
  EQUB    4, 4, 4, 6, 6, 6, 6, 7, 0, 0
  EQUB    3, 3, 3, 3, 3, 6, 6, 7, 0, 0
  EQUB    1, 1, 1, 2, 2, 2, 7, 7, 0, 0
  EQUB    1, 2, 3, 3, 3, 5, 7, 7, 0, 0
  EQUB    2, 3, 4, 5, 6, 6, 7, 7, 0, 0
  EQUB    5, 5, 5, 6, 6, 6, 6, 7, 7, 0
  EQUB    3, 3, 3, 3, 4, 4, 4, 6, 7, 0
  EQUB    3, 3, 4, 4, 5, 5, 6, 6, 7, 0
  EQUB    3, 4, 5, 6, 6, 5, 6, 6, 7, 0
  EQUB    2, 2, 3, 4, 5, 5, 6, 6, 7, 0
.MONSTER_TAB2
  EQUB    1, 2, 3, 4, 5, 5, 6, 6, 7, 0
  EQUB    1, 2, 6, 6, 6, 5, 6, 6, 7, 0
  EQUB    2, 3, 3, 3, 4, 4, 4, 6, 7, 0
  EQUB    5, 5, 5, 5, 5, 6, 7, 6, 7, 0
  EQUB    3, 3, 3, 4, 4, 5, 5, 6, 7, 0
  EQUB    2, 2, 3, 3, 4, 4, 5, 5, 6, 6
  EQUB    2, 3, 4, 4, 4, 6, 6, 6, 6, 7
  EQUB    3, 3, 4, 4, 5, 6, 6, 7, 6, 7
  EQUB    3, 3, 4, 4, 4, 6, 6, 7, 6, 7
  EQUB    3, 3, 4, 5, 0, 6, 6, 7, 6, 7
  EQUB    3, 3, 4, 4, 6, 6, 7, 6, 7, 7
  EQUB    3, 3, 4, 5, 6, 6, 7, 6, 7, 7
  EQUB    3, 3, 4, 4, 6, 6, 7, 6, 7, 7
  EQUB    3, 4, 5, 5, 6, 7, 6, 7, 7, 7
  EQUB    3, 4, 4, 6, 6, 7, 6, 7, 7, 7
  EQUB    3, 4, 5, 6, 6, 6, 7, 7, 7, 7
  EQUB    4, 5, 6, 6, 7, 6, 7, 7, 7, 7
  EQUB    4, 5, 6, 7, 6, 7, 7, 7, 7, 7
  EQUB    4, 5, 6, 7, 6, 7, 7, 7, 7, 7
  EQUB    5, 6, 5, 6, 7, 7, 7, 7, 7, 7
  EQUB    5, 6, 5, 6, 7, 7, 7, 7, 7, 7
  EQUB    6, 5, 5, 6, 7, 7, 7, 7, 7, 7
  EQUB    6, 5, 6, 7, 7, 7, 7, 7, 7, 8
  EQUB    5, 5, 6, 7, 7, 7, 7, 7, 7, 8
  EQUB    5, 5, 6, 7, 7, 7, 7, 7, 8, 8

; =============== S U B R O U T I N E =======================================
; Add a new tile to TILE_TAB
.DRAW_TILE
{
  STX TEMP_X
  STY TEMP_Y

  PHA

.loop
  LDA TILE_CUR
  SEC:SBC TILE_PTR
  CMP #8
  BEQ loop

  PLA

  JSR sub_D924

  LDY TILE_PTR
  LDX #0

.COPY_TILE
  LDA TILE_PARAM,X:STA TILE_TAB,Y

  INY
  INX
  CPX #8
  BNE COPY_TILE

  STY TILE_PTR

  LDX TEMP_X
  LDY TEMP_Y

  RTS
}

; =============== S U B R O U T I N E =======================================
.sub_D924
{
  TAY ; Cache sprite number
  ASL A:ASL A ; A = A * 4
  STA TILE_PARAM+3

  ; Get palette for this sprite
  LDA TILE_PALETTE,Y:STA TILE_PARAM+7

  ; If X position >=16 (on right of map), shift Y down by 4 and subtract 16 from X
  LDY #0
  LDA CACHE_X
  CMP #16
  BCC left_of_screen

  LDY #4
  SBC #16

.left_of_screen
  STY TILE_PARAM
  ASL A
  STA byte_21

  LDA CACHE_Y
  CLC:ADC #2
  ASL A
  STA byte_22

  AND #&FC
  ASL A
  STA TILE_PARAM+4

  LDA byte_21
  LSR A:LSR A ; A = A / 4
  CLC:ADC TILE_PARAM+4
  CLC:ADC #&C0
  STA TILE_PARAM+4

  LDA #&23:STA TILE_PARAM+5

  LDA #2
  AND byte_22
  STA byte_23

  LDA byte_21
  AND #3
  LSR A
  CLC:ADC byte_23
  ASL A

  PHA
  LDA #&FC:STA TILE_PARAM+6
  PLA

  TAX
  BEQ loc_D97C

.loc_D974
  ASL TILE_PARAM+7
  SEC:ROL TILE_PARAM+6
  DEX
  BNE loc_D974

.loc_D97C
  LDA #1:STA TILE_PARAM+2
  LDA byte_22
  LDX #5

.loc_D984
  ASL A
  ROL TILE_PARAM+2
  DEX
  BNE loc_D984

  CLC:ADC byte_21
  STA TILE_PARAM+1
  BCC done

  INC TILE_PARAM+2

.done
  RTS

; ---------------------------------------------------------------------------
.TILE_PALETTE
  EQUB   0 ; 0 Empty space
  EQUB   0 ; 1 Concrete block

  ; Palettes for brick walls
  EQUB   0 ; 2
  EQUB   1 ; 3
  EQUB   1 ; 4
  EQUB   1 ; 5
  EQUB   1 ; 6
  EQUB   1 ; 7

  ; Palettes for bombs
  EQUB   0 ; 8
  EQUB   0 ; 9
  EQUB   0 ; 10

  ; Palletes for explosions
  EQUB   1 ; 11
  EQUB   1 ; 12
  EQUB   1 ; 13
  EQUB   1 ; 14
  EQUB   1 ; 15
  EQUB   1 ; 16
  EQUB   1 ; 17
  EQUB   1 ; 18
  EQUB   1 ; 19
  EQUB   1 ; 20
  EQUB   1 ; 21
  EQUB   1 ; 22
  EQUB   1 ; 23
  EQUB   1 ; 24
  EQUB   1 ; 25
  EQUB   1 ; 26
  EQUB   1 ; 27
  EQUB   1 ; 28
  EQUB   1 ; 29
  EQUB   1 ; 30
  EQUB   1 ; 31
  EQUB   1 ; 32
  EQUB   1 ; 33
  EQUB   1 ; 34
  EQUB   1 ; 35
  EQUB   1 ; 36
  EQUB   1 ; 37
  EQUB   1 ; 38

  EQUB   1 ; 39 Brick wall
  EQUB   3 ; 40 Exit door

  ; Palette for exit enemy types
  EQUB   2 ; 41 - 1 Valcom (Balloon)
  EQUB   2 ; 42 - 2 O'Neal (Onion)
  EQUB   2 ; 43 - 3 Dahl (Barrel)
  EQUB   2 ; 44 - 4 Minvo (Happy face)
  EQUB   2 ; 45 - 5 Doria (Blob)
  EQUB   2 ; 46 - 6 Ovape (Ghost)
  EQUB   2 ; 47 - 7 Pass (Tiger)
  EQUB   2 ; 48 - 8 Pontan (Coin)

  EQUB   3 ; 49
}

; Table for the 4 tile ids used to make a sprite
.TILE_MAP
  EQUB &5F,&5F,&5F,&5F ;  0 Empty space
  EQUB &64,&65,&66,&67 ;  1 Concrete block
  EQUB &68,&69,&6A,&6B ;  2 Brick wall
  EQUB &6C,&6D,&6E,&6F ;  3 Brick wall 2
  EQUB &70,&71,&72,&73 ;  4 Brick wall 3
  EQUB &74,&75,&76,&77 ;  5 Brick wall 4
  EQUB &78,&79,&7A,&7B ;  6 Brick wall 5
  EQUB &7C,&7D,&7E,&7F ;  7 Brick wall 6
  EQUB &80,&81,&82,&83 ;  8 Bomb 1
  EQUB &84,&85,&86,&87 ;  9 Bomb 2
  EQUB &88,&89,&8A,&8B ; 10 Bomb 3
  EQUB &8C,&8D,&8E,&8F ; 11 Explosion centre 1
  EQUB &90,&91,&92,&93 ; 12 Explosion centre 2
  EQUB &94,&95,&96,&97 ; 13 Explosion centre 3
  EQUB &98,&99,&9A,&9B ; 14 Explosion centre 4
  EQUB &20,&20,&21,&21 ; 15 Explosion horizontal 1
  EQUB &22,&23,&22,&23 ; 16 Explosion vertical 1
  EQUB &24,&24,&25,&25 ; 17 Explosion horizontal 2
  EQUB &26,&27,&26,&27 ; 18 Explosion vertical 2
  EQUB &28,&28,&29,&29 ; 19 Explosion horizontal 3
  EQUB &2A,&2B,&2A,&2B ; 20 Explosion vertical 3
  EQUB &2C,&2C,&2D,&2D ; 21 Explosion horizontal 4
  EQUB &2E,&2F,&2E,&2F ; 22 Explosion vertical 4
  EQUB &20,&9D,&21,&9F ; 23 Explosion horizontal right edge 1
  EQUB &9C,&9D,&22,&23 ; 24 Explosion vertical top edge 1
  EQUB &9C,&20,&9E,&21 ; 25 Explosion horizontal left edge 1
  EQUB &22,&23,&9E,&9F ; 26 Explosion vertical bottom edge 1
  EQUB &24,&A1,&25,&A3 ; 27 Explosion horizontal right edge 2
  EQUB &A0,&A1,&26,&27 ; 28 Explosion vertical top edge 2
  EQUB &A0,&24,&A2,&25 ; 29 Explosion horizontal left edge 2
  EQUB &26,&27,&A2,&A3 ; 30 Explosion vertical bottom edge 2
  EQUB &28,&A5,&29,&A7 ; 31 Explosion horizontal right edge 3
  EQUB &A4,&A5,&2A,&2B ; 32 Explosion vertical top edge 3
  EQUB &A4,&28,&A6,&29 ; 33 Explosion horizontal left edge 3
  EQUB &2A,&2B,&A6,&A7 ; 34 Explosion vertical bottom edge 3
  EQUB &2C,&A9,&2D,&AB ; 35 Explosion horizontal right edge 4
  EQUB &A8,&A9,&2E,&2F ; 36 Explosion vertical top edge 4
  EQUB &A8,&2C,&AA,&2D ; 37 Explosion horizontal left edge 4
  EQUB &2E,&2F,&AA,&AB ; 38 Explosion vertical bottom edge 4
  EQUB &68,&69,&6A,&6B ; 39 Brick wall
  EQUB &3C,&3D,&3E,&3F ; 40 Exit door
  EQUB   0,  1,&10,&11 ; 41 Bonus item bomb (increase bombs)
  EQUB   2,  3,&12,&13 ; 42 Bonus item flame (increase explosion radius)
  EQUB   4,  5,&14,&15 ; 43 Bonus item skates (4x speed mode)
  EQUB   6,  7,&16,&17 ; 44 Bonus item walk through walls (no clip walls)
  EQUB   8,  9,&18,&19 ; 45 Bonus item remote (detonator)
  EQUB  &A, &B,&1A,&1B ; 46 Bonus item bomb walk (no clip bombs)
  EQUB  &C, &D,&1C,&1D ; 47 Bonus item fire suit (explosions don't hurt)
  EQUB  &E, &F,&1E,&1F ; 48 Bonus item question mark (invulnerability 1)
  EQUB &68,&69,&6A,&6B ; 49 Brick wall

; =============== S U B R O U T I N E =======================================
; Password entry screen
.READ_PASSWORD
{
  JSR PPUD
  JSR VBLD
  JSR SETSTAGEPAL

  LDA #0
  STA STAGE_STARTED
  STA INMENU
  STA APU_MUSIC

  ; Print "ENTER SECRET CODE" for password prompt
  LDY #(PASSWORD_PROMPT-STRING_TABLE)
  LDA #&20:LDX #&E7 ; Position cursor for write
  JSR PRINT_ASCIIZ

  JSR PPUE

  LDA #6:STA CACHE_X   ; X coordinate for password input
  LDA #':':STA CACHE_Y ; Set current char to "blank"

  LDY #0 ; Set current password length

.pw_await_keypress
  JSR WAITVBL

  ; Set screen position where next character will be written
  LDA #&22:LDX CACHE_X
  JSR VRAMADDR

  ; Write current character
  LDA CACHE_Y:STA PPU_DATA

  JSR PPU_RESTORE

  LDX #PW_CURSOR_FLASH_SPEED ; Cursor flashing speed in frames (off)

.cursor_off_loop
  JSR WAITVBL

  ; Check for A button or direction buttons being pressed
  LDA JOYPAD1
  AND #(PAD_A + PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT)
  BNE pw_keypress

  DEX
  BNE cursor_off_loop

  JSR WAITVBL

  ; Set screen position where next character will be written
  LDA #&22:LDX CACHE_X
  JSR VRAMADDR

  LDA #SOLIDWHITE:STA PPU_DATA

  JSR PPU_RESTORE

  LDX #PW_CURSOR_FLASH_SPEED ; Cursor flashing speed in frames (on)

.cursor_on_loop
  JSR WAITVBL

  ; Check for something being pressed on JOYPAD 1
  LDA JOYPAD1
  AND #(PAD_A + PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT)
  BNE pw_keypress ; Branch if A/Up/Down/Left/Right is pressed

  DEX
  BNE cursor_on_loop

  JMP pw_await_keypress

; ---------------------------------------------------------------------------
; Keypress on password screen handler

.pw_keypress
  BMI pw_handle_a_button ; Branch if A button pressed (select character)

  PHA
  LDA #&12:STA APU_SQUARE1_REG+3 ; Make a sound (low tone)
  PLA

  CMP #PAD_RIGHT
  BEQ pw_handle_right_button ; Branch if Right button pressed (next char)

  ; Handle Up/Down/Left key presses (previous char)

  LDA CACHE_Y
  CMP #':'
  BNE pw_char_not_blank ; Branch if current char is not "blank"

  ; Nothing entered yet for this char, so wrap round
  LDA #PW_LAST_CHAR+1:STA CACHE_Y ; Set current char to one more than the last valid char

.pw_char_not_blank
  LDA CACHE_Y
  CMP #PW_FIRST_CHAR
  BEQ pw_wrap_to_end ; Branch if current char is "A" to wrap

  DEC CACHE_Y ; Set current char to one less alphabetically
  JMP pw_no_wrap_left
; ---------------------------------------------------------------------------

.pw_wrap_to_end
  LDA #PW_LAST_CHAR:STA CACHE_Y ; Set current char to "P" (wrap around)

.pw_no_wrap_left
  JSR WAITUNPRESS ; Wait for button release
  JMP pw_await_keypress ; Jump back to read next character

; ---------------------------------------------------------------------------
; Handler for Right button press on password screen (next char)
.pw_handle_right_button
  LDA CACHE_Y
  CMP #':' ; Branch if current char is not "blank"
  BNE pw_char_not_blank2

  ; Nothing entered yet for this char, so wrap round
  LDA #PW_FIRST_CHAR-1:STA CACHE_Y ; Set current char to one before "A"

.pw_char_not_blank2
  LDA CACHE_Y
  CMP #PW_LAST_CHAR
  BEQ pw_wrap_to_start ; Branch if current char is "P" (last available char)

  INC CACHE_Y ; Set current char to one more alphabetically
  JMP pw_no_wrap_right
; ---------------------------------------------------------------------------

.pw_wrap_to_start
  LDA #PW_FIRST_CHAR:STA CACHE_Y ; Set current char to "A" (wrap around)

.pw_no_wrap_right
  JSR WAITUNPRESS ; Wait for button release

.pw_read_next
  JMP pw_await_keypress ; Jump back to read next character

; ---------------------------------------------------------------------------
; Handler for A button press on password screen
.pw_handle_a_button
  LDA #&11:STA APU_SQUARE1_REG+3 ; Make a sound (high tone)

  LDA CACHE_Y
  CMP #':'
  BEQ pw_read_next ; Branch if current char is "blank"

  AND #&F
  TAX             ; X = current char & 0x0F
  LDA PW_DECODE_TABLE,X ; Use lookup for current char
  STA PW_BUFF,Y    ; Store this in 0x7F to 0x92
  JSR WAITVBL

  ; Set screen position for next character to be written
  LDA #&22:LDX CACHE_X
  JSR VRAMADDR

  ; Draw current char to screen
  LDA CACHE_Y:STA PPU_DATA

  JSR PPU_RESTORE

  ; Reset current char to "blank"
  LDA #':':STA CACHE_Y

  ; Advance X position
  INC CACHE_X

  ; Increase length of password counter
  INY

  CPY #PW_MAX_CHARS
  BEQ validate_password ; Branch if we have 20 characters

  JSR WAITUNPRESS ; Wait for button release
  JMP pw_await_keypress ; Jump back to read next character

; ---------------------------------------------------------------------------
; Handler for 20 chars of password being entered

.validate_password
  LDX #0:STX SEED ; Clear PRNG seed[0], as this is used during decode

.pw_decode_loop
  LDA PW_BUFF,X ; Load password[X]

  PHA
  CLC:ADC #7
  CLC:ADC SEED
  AND #&F       ; Clear upper nibble
  STA PW_BUFF,X ; Save decoded char back to password[X]
  PLA

  STA SEED
  INX
  CPX #PW_MAX_CHARS
  BNE pw_decode_loop ; Loop for 20 characters

  LDX #0

.pw_cxsums_validation_loop
  LDY #4
  LDA #0

.pw_cxsum_calc_loop
  CLC:ADC PW_BUFF,X
  INX
  DEY
  BNE pw_cxsum_calc_loop ; Loop until Y=0 (4 times)

  AND #&F
  CMP PW_BUFF,X
  BNE start_over ; Branch if password[X] != A

  INX
  CPX #&F
  BNE pw_cxsums_validation_loop ; Branch if X != $F

  ; Validate final checksum

  LDA PW_BUFF+4 ; Load password[4] (checksum 1)
  ASL A
  STA CACHE_X

  LDA PW_BUFF+9 ; Load password[9] (checksum 2)
  ASL A
  CLC:ADC CACHE_X
  STA CACHE_X

  LDA PW_BUFF+14 ; Load password[14] (checksum 3)
  ASL A
  CLC:ADC CACHE_X

  LDX #4

.pw_final_cxsum_calc_loop
  CLC:ADC PW_BUFF+14,X
  DEX
  BNE pw_final_cxsum_calc_loop

  ; Compare generated final checksum with last char of password
  AND #&F
  CMP PW_BUFF+(PW_MAX_CHARS-1)
  BEQ valid_password ; Branch if password[19] (checksum 4) = A

.start_over
  JMP READ_PASSWORD ; Read password all over again (as this one is not valid)

; ---------------------------------------------------------------------------
; Valid password has been entered

.valid_password
  LDX #0
  LDY #0

.extract_password_data_loop
  JSR _get_pass_data_var_addr
  LDA PW_BUFF,Y
  STY TEMP_Y

  ; Clear password data address offset
  LDY #0:STA (STAGE_MAP),Y

  LDY TEMP_Y
  INY
  CPY #PW_MAX_CHARS
  BNE extract_password_data_loop

  ; Determine bomb radius (move lower nibble to upper one)
  LDA BOMB_PWR:ASL A:ASL A:ASL A:ASL A
  STA BONUS_POWER

  ; Determine stage number (Combine hi and lo nibble BCD values)
  LDA STAGE_HI:ASL A:ASL A:ASL A:ASL A:ORA STAGE_LO
  STA STAGE

  RTS
}

; =============== S U B R O U T I N E =======================================
.DRAW_GAME_COMPLETED
{
  JSR PPUD
  JSR VBLD
  JSR SETSTAGEPAL

  ; Set sprite palette
  LDA #6
  JSR SETSPR3PAL

  ; Print the 7 game completed lines of text
  LDY #0
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ
  JSR PRINT_XY_ASCIIZ

  ; Draw a row of 16 bricks
  LDA #&A:STA CACHE_Y ; Y position
  LDA #0:STA CACHE_X ; X position

.loop
  LDA #&31
  JSR sub_CB4E

  ; Increment X position
  INC CACHE_X
  LDA CACHE_X
  CMP #16
  BNE loop

  JSR VBLE
  JMP PPUE
}

; ---------------------------------------------------------------------------
; Print ASCIIZ string with A:X screen location prefix
.PRINT_XY_ASCIIZ
{
  ; Get the screen location first
  LDA STRING_TABLE,Y:INY
  LDX STRING_TABLE,Y:INY

; =============== S U B R O U T I N E =======================================
.^PRINT_ASCIIZ
  JSR VRAMADDR

.loop
  LDA STRING_TABLE,Y
  INY
  CMP #0 ; Check for null terminator
  BEQ done

  STA PPU_DATA ; Write character to screen
  JMP loop

; ---------------------------------------------------------------------------

.done
  RTS
}

; ---------------------------------------------------------------------------

.STRING_TABLE
  EQUB &20, &88
  EQUS "CONGRATULATIONS", 0

  EQUB &20, &E4
  EQUS "YOU:HAVE:SUCCEEDED:IN", 0

  EQUB &21, &22
  EQUS "HELPING:BOMBERMAN:TO:BECOME", 0

  EQUB &21, &62
  EQUS "A:HUMAN:BEING", 0

  EQUB &21, &A4
  EQUS "MAYBE:YOU:CAN:RECOGNIZE:HIM", 0

  EQUB &21, &E2
  EQUS "IN:ANOTHER:HUDSON:SOFT:GAME", 0

  EQUB &22, &4B
  EQUS "GOOD:BYE", 0

.PASSWORD_PROMPT
  EQUS "ENTER:SECRET:CODE", 0

; =============== S U B R O U T I N E =======================================
; Set sprite 3 palette to entry given in A
.SETSPR3PAL
{
  PHA
  JSR WAITVBL

  ; Point to sprite palette 3 RAM
  LDA #hi(SPR_PAL_3-1):LDX #lo(SPR_PAL_3-1)
  JSR VRAMADDR

  PLA

  ; Point to correct palette entry
  ASL A:ASL A ; A = A * 4
  TAX

  ; Copy 4 bytes to palette RAM
  LDY #4

.loop
  LDA game_over_palette,X
  STA PPU_DATA
  INX
  DEY
  BNE loop

  JMP VRAMADDRZ

; ---------------------------------------------------------------------------
.game_over_palette
  EQUB  &F,  0,  0,  0    ; 0
  EQUB  &F,  0,  0,  0    ; 1
  EQUB  &F,  0,  0,  0    ; 2
  EQUB  &F,  0,  0,  0    ; 3
  EQUB  &F,  0,  0,  0    ; 4
  EQUB  &F,  0,  0,  0    ; 5

  EQUB  &F, &15, &36, &21 ; 6 - Only this one seems to be used
  ;         Pink Sand Blue
}

; =============== S U B R O U T I N E =======================================
.GAME_OVER_SCREEN
{
  JSR PPUD
  JSR VBLD

  ; Change palette
  JSR SETSTAGEPAL

  ; Set screen pointer for next character to write
  LDA #&21:LDX #&EA
  JSR VRAMADDR

  ; Print "GAME OVER"
  LDX #8

.loop
  LDA aRevoEmag,X ; "REVO:EMAG" ("GAME OVER" backwards)
  STA PPU_DATA
  DEX
  BPL loop

  ; Generate and print password
  JSR GENERATE_PASSWORD

  JSR VBLE
  JMP PPUE

; ---------------------------------------------------------------------------
.aRevoEmag
  EQUS "REVO:EMAG"
}

; =============== S U B R O U T I N E =======================================
; Add score (with * 100,000)
.SCORE_100K
{
  ; Cache X and Y
  STX TEMP_X
  STY TEMP_Y

  ; If we're in DEMO mode, skip scoring
  LDX DEMOPLAY
  BNE done

  ; Add from position 3
  LDX #3
  BNE add_to_score

; =============== S U B R O U T I N E =======================================
; Add score (with * 10,000)
.^SCORE_10K
  ; Cache X and Y
  STX TEMP_X
  STY TEMP_Y

  ; If we're in DEMO mode, skip scoring
  LDX DEMOPLAY
  BNE done

  ; Add from position 4
  LDX #4
  BNE add_to_score

; =============== S U B R O U T I N E =======================================
; Add score (with * 100)
.^SCORE_100
  ; Cache X and Y
  STX TEMP_X
  STY TEMP_Y

  ; If we're in DEMO mode, skip scoring
  LDX DEMOPLAY
  BNE done

  ; Add from position 6
  LDX #6

; ---------------------------------------------------------------------------

; Actually add to the BCD score
.add_to_score
  LDY #0
  CLC:ADC SCORE,X

; While > 10 at this position, count how many 10s (into Y)
.over_ten
  STA SCORE,X
  LDA SCORE,X
  SEC:SBC #10 ; Subtract 10
  BCC in_BCD_range ; If it was < 10 we're done
  INY ; Count an overflow
  BNE over_ten

; Check how much overflowed
.in_BCD_range
  CPY #0
  BEQ no_overflow

  TYA ; Carry # overflows
  DEX ; Move up to next digit column
  BPL add_to_score

  ; We've run out of digits in the score so set to 9 in first column
  LDA #9:STA SCORE

; No more overflows occured
.no_overflow
  LDX #0

; Check if this is higher than top score
.check_score_digit
  LDA SCORE,X
  CMP TOPSCORE,X
  BCC done ; current score digit < top score digit, so skip checking rest

  BNE new_high_score
  INX
  CPX #SCORE_DIGITS+1 ; Check all 7 digits against top score
  BNE check_score_digit

.new_high_score
  LDX #SCORE_DIGITS-1

.update_top_score
  LDA SCORE,X
  STA TOPSCORE,X
  DEX
  BPL update_top_score

.done
  ; Restore X and Y
  LDX TEMP_X
  LDY TEMP_Y

  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw the lines "TIME" and "LEFT XX" in the status bar
.TIME_AND_LIFE
{
  ; Draw status bar background
  ; Set screen pointer for next character to write
  LDA #&20:LDX #0
  JSR VRAMADDR

  LDX #&80
  LDA #':'

.space_loop
  STA PPU_DATA
  DEX
  BNE space_loop

  ; Draw "time" text (time value is drawn elsewhere)
  ; Set screen pointer for next character to write
  LDA #&20:LDX #&41
  JSR VRAMADDR

  LDX #3

.time_loop
  LDA aEmit,X     ; "EMIT" ("TIME" backwards)
  STA PPU_DATA
  DEX
  BPL time_loop

  LDA #':'       ;  These 2 lines are not needed
  STA PPU_DATA   ;

  ; Draw trailing zeroes of score (as it's always a multiple of 100)
  ; Set screen pointer for next character to write
  LDA #&20:LDX #&52
  JSR VRAMADDR

  ; Print two "0" characters
  LDA #'0'
  STA PPU_DATA
  STA PPU_DATA

  ; Draw "left" text
  ; Set screen pointer for next character to write
  LDA #&20:LDX #&58
  JSR VRAMADDR

  LDX #3

.left_loop
  LDA aTfel,X     ; "TFEL" ("LEFT" backwards)
  STA PPU_DATA
  DEX
  BPL left_loop

  ; Draw the number of extra lives remaining (with leading spaces)
  LDA LIFELEFT
  JMP PUTNUMBER   ; Print 2-digit number in A

; ---------------------------------------------------------------------------
.aEmit
  EQUS "EMIT"
.aTfel
  EQUS "TFEL"
}

; =============== S U B R O U T I N E =======================================
.STAGE_SCREEN
{
  JSR PPUD
  JSR VBLD
  LDA #0:STA H_SCROLL
  JSR SETSTAGEPAL

  ; Set screen pointer for next character to write
  LDA #&21:LDX #&EA
  JSR VRAMADDR

  LDX #4

.PUT_STAGE_STR
  LDA aEgats,X    ; "EGATS" ("STAGE" backwards)
  STA PPU_DATA
  DEX
  BPL PUT_STAGE_STR

  ; Set screen pointer for next character to write
  LDA #&21:LDX #&F0
  JSR VRAMADDR

  LDA STAGE
  JSR PUTNUMBER   ; Print number in A

  JSR VBLE
  JMP PPUE

; ---------------------------------------------------------------------------
.aEgats
  EQUS "EGATS"
}

; =============== S U B R O U T I N E =======================================
.BONUS_STAGE_SCREEN
{
  JSR PPUD
  JSR VBLD
  LDA #0
  STA H_SCROLL
  JSR SETSTAGEPAL

  ; Set screen pointer for next character to write
  LDA #&21:LDX #&EA
  JSR VRAMADDR

  LDX #&A

.PUT_BONUS_MSG
  LDA aEgatsSunob,X   ; "EGATS:SUNOB" ("BONUS STAGE" backwards)
  STA PPU_DATA
  DEX
  BPL PUT_BONUS_MSG

  JSR VBLE
  JMP PPUE

; ---------------------------------------------------------------------------
.aEgatsSunob
  EQUS "EGATS:SUNOB"
}

; =============== S U B R O U T I N E =======================================
.DRAWMENU
{
  JSR PPUD
  JSR CLS
  JSR WAITVBL

  ; Point to palette RAM
  LDA #hi(BASE_PAL):LDX #lo(BASE_PAL)
  JSR VRAMADDR

  LDX #0

  ; Set up all 4 background palettes from MENU set
.pal_loop
  LDA MENUPAL,X:STA PPU_DATA

  INX
  CPX #&10
  BNE pal_loop

  JSR VRAMADDRZ
  JSR DRAWMENUTEXT    ; Write text in menus (author's rights, license)

  ; Set screen pointer for next character to write
  LDA #&20:LDX #0
  JSR VRAMADDR

  LDX #(HW_SCREEN_X/TILE_SIZE)*2 ; blank row above game logo
  LDA #&B0 ; Blank tile

.blank_loop
  STA PPU_DATA
  DEX
  BNE blank_loop

  LDX #0

.logo_top_loop
  LDA MAINMENU_HI,X:STA PPU_DATA
  INX
  BNE logo_top_loop

.logo_bottom_loop
  LDA MAINMENU_LO,X:STA PPU_DATA
  INX
  BNE logo_bottom_loop

  ; Set screen pointer for next character to write
  LDA #&22:LDX #&AE
  JSR VRAMADDR

  LDX #0

  ; Print top score
.print_leading_spaces
  LDA TOPSCORE,X
  BNE print_digits

  LDA #':':STA PPU_DATA ; Print a space
  INX
  CPX #7
  BNE print_leading_spaces

  BEQ top_score_done

.print_digits
  LDA TOPSCORE,X
  CLC:ADC #'0'
  STA PPU_DATA
  INX
  CPX #7
  BNE print_digits

.top_score_done
  ; Print two trailing "0" characters as scores are multiples of 100
  LDA #'0'
  STA PPU_DATA
  STA PPU_DATA

  ; Set pointer to PPU attributes nametable
  LDA #hi(PPU_ATTR_TABLE):LDX #lo(PPU_ATTR_TABLE)
  JSR VRAMADDR

  ; Assign palette for "BOMBERMAN" title logo
  LDX #&20
  LDA #%00000000 ; Palette 0 for whole block

.title_attr_loop
  STA PPU_DATA
  DEX
  BNE title_attr_loop

  ; Assign palette for bottom of "BOMBERMAN" and ">START  CONTINUE" option text
  LDX #&08
  LDA #%01010000 ; Palette 0 for top half and 1 for bottom half

.option_attr_loop
  STA PPU_DATA
  DEX
  BNE option_attr_loop

  ; Assign palette for trademarks and license text
  LDX #&18
  LDA #%01010101 ; Palette 1 for whole block

.license_attr_loop
  STA PPU_DATA
  DEX
  BNE license_attr_loop

  JSR PPU_RESTORE
  JSR VBLE

  JMP PPUE
}

; =============== S U B R O U T I N E =======================================
.SETSTAGEPAL
{
  LDA #0:STA H_SCROLL

  JSR WAITVBL

  ; Point to palette RAM
  LDA #hi(BASE_PAL):LDX #lo(BASE_PAL)
  JSR VRAMADDR

  ; Set up all 4 background palettes from STAGE set
  LDX #0

.loop
  LDA STAGEPAL,X:STA PPU_DATA

  INX
  CPX #PAL_SIZE
  BNE loop

  JSR VRAMADDRZ

  JMP CLS
}

; =============== S U B R O U T I N E =======================================
.DRAW_TIME
{
  LDY #'0'
  SEC

  ; Number of hundreds in Y
.loop_hundreds
  SBC #100
  BCC DONE_HUNDREDS

  INY
  BNE loop_hundreds

.DONE_HUNDREDS
  ADC #100
  CPY #'0'
  BNE three_digits

  LDY #':' ; This is a space
  STY PPU_DATA

  ; =============== S U B R O U T I N E =======================================
  ; Print 2-digit number in A.
  .^PUTNUMBER
  {
    LDY #'0'
    SEC         ; Convert to number 0 to 9

  .TENS
    SBC #10     ; Number of tens in Y
    BCC DONE_TENS

    INY
    BNE TENS     ; Number of tens in Y

  .DONE_TENS
    ADC #':'
    CPY #'0'      ; If the number is single-digit (from 0 to 9) add leading space
    BNE PUTNUMB2

    LDY #':' ; This is a space

  .PUTNUMB2
    STY PPU_DATA
    STA PPU_DATA

    RTS
  }
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR DRAW_TIME

.three_digits
  STY PPU_DATA
  LDY #'0'
  SEC

.TENS2
  SBC #10
  BCC DONE_TENS2

  INY
  BNE TENS2

.DONE_TENS2
  ADC #':'
  STY PPU_DATA
  STA PPU_DATA

  RTS
}

; ---------------------------------------------------------------------------
.STAGEPAL
  EQUB  &F,  0, &F,&30  ; S0 /      GREY  BLACK WHITE

.MENUPAL
  EQUB  &F,  5,&30,&28  ; S1 / M0   PINK  WHITE GOLD
  EQUB  &F,  0, &F,&30  ; S2 / M1   GREY  BLACK WHITE
  EQUB  &F,  6,&26,&37  ; S3 / M2   RED   CORAL GREY
  EQUB  &F, &F, &F, &F  ;    / M3   BLACK BLACK BLACK

.PW_DECODE_TABLE
  EQUB  5 ; P
  EQUB  0 ; A
  EQUB  9 ; B
  EQUB  4 ; C
  EQUB &D ; D
  EQUB  7 ; E
  EQUB  2 ; F
  EQUB  6 ; G
  EQUB &A ; H
  EQUB &F ; I
  EQUB &C ; J
  EQUB  3 ; K
  EQUB  8 ; L
  EQUB &B ; M
  EQUB &E ; N
  EQUB  1 ; O

.MAINMENU_HI
  EQUB &B0,&B0,&DF,&C0,&C1,&C1,&C2,&C0,&C1,&C1,&C1,&C2,&C0,&B6,&E9,&B8
  EQUB &C2,&C0,&C1,&C1,&C2,&C0,&C1,&C1,&C2,&C0,&C1,&C1,&C2,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&C1,&D9,&D3,&B3,&C1,&D9,&CB,&D3,&B3,&C1,&C5,&C6,&C1
  EQUB &B3,&C1,&D9,&D3,&B3,&C1,&D9,&CB,&CB,&C1,&D9,&D3,&B3,&EE,&F8,&B0
  EQUB &B0,&B0,&DF,&C1,&D0,&D1,&D2,&C1,&CF,&E9,&C4,&B3,&C1,&D5,&D6,&D7
  EQUB &B3,&C1,&D0,&D1,&D2,&C1,&D0,&DC,&E9,&C1,&D0,&D1,&D2,&EB,&F8,&B0
  EQUB &B0,&B0,&DF,&C1,&E0,&E1,&E2,&C1,&CF,&E9,&C4,&B3,&C1,&B7,&E6,&E7
  EQUB &B3,&C1,&E0,&E1,&E2,&C1,&E0,&F5,&EC,&C1,&E0,&E1,&E2,&EF,&F8,&B0
  EQUB &B0,&B0,&DF,&C1,&E8,&DA,&B3,&C1,&CF,&E9,&C4,&B3,&C1,&CF,&E5,&F0
  EQUB &B3,&C1,&E8,&DA,&B3,&C1,&E8,&DB,&ED,&C1,&E8,&DA,&B3,&EB,&F8,&B0
  EQUB &B0,&B0,&DF,&C1,&B5,&E3,&B3,&C1,&B5,&E9,&E3,&B3,&C1,&CF,&E9,&C4
  EQUB &B3,&C1,&B5,&E3,&B3,&C1,&B5,&E9,&E9,&C1,&CF,&C4,&B3,&EB,&F8,&B0
  EQUB &B0,&B0,&DF,&B1,&C1,&F1,&C3,&C7,&C1,&C1,&F1,&C3,&B4,&CF,&E9,&B2
  EQUB &C3,&C7,&C1,&F1,&C3,&C7,&C1,&C1,&C3,&B4,&CF,&B2,&C3,&EB,&F8,&B0
  EQUB &B0,&B0,&DF,&CA,&CB,&CB,&CB,&CE,&CB,&CB,&CB,&CB,&CE,&D8,&E9,&E9
  EQUB &EA,&CE,&CB,&CB,&CB,&CE,&CB,&CB,&CB,&CE,&D8,&E9,&EA,&CD,&F8,&B0

.MAINMENU_LO
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C0,&B6,&E9,&B8,&C2,&C0
  EQUB &C1,&C1,&C2,&C0,&BC,&E4,&C2,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C1,&C5,&C6,&C1,&B3,&C1
  EQUB &D9,&D3,&B3,&C1,&BD,&C4,&B3,&EE,&FB,&FC,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C1,&D5,&D6,&D7,&B3,&C1
  EQUB &D0,&D1,&B3,&C1,&BE,&F2,&B3,&EB,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C1,&B7,&E6,&E7,&B3,&C1
  EQUB &E0,&E1,&B3,&C1,&B9,&BF,&B3,&EB,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C1,&CF,&E5,&F0,&B3,&C1
  EQUB &E8,&DA,&B3,&C1,&BB,&C8,&B3,&EB,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&C1,&CF,&E9,&C4,&B3,&C1
  EQUB &CF,&C4,&B3,&C1,&C9,&C1,&B3,&EB,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&D4,&CF,&E9,&B2,&C3,&B4
  EQUB &CF,&B2,&C3,&B4,&CF,&BA,&C3,&EB,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0
  EQUB &B0,&B0,&DF,&E9,&E9,&E9,&E9,&E9,&E9,&E9,&CA,&D8,&E9,&E9,&EA,&CE
  EQUB &D8,&E9,&EA,&CE,&D8,&F3,&CB,&CD,&E9,&E9,&E9,&E9,&E9,&E9,&F8,&B0

  EQUB &B0
  EQUB &B0
  EQUB &F4
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9
  EQUB &F9

; =============== S U B R O U T I N E =======================================
; Write text in menus (author's rights, license)
.DRAWMENUTEXT
{
  LDY #0

  LDX #5 ; Number of strings to draw

.NEXTSTRING
  JSR NEXTCHAR:STA PPU_ADDRESS
  JSR NEXTCHAR:STA PPU_ADDRESS

.CONTINUEDRAW
  JSR NEXTCHAR

  ; Check for end of string
  CMP #END_OF_STRING
  BEQ BREAKDRAW

  STA PPU_DATA
  BNE CONTINUEDRAW

.BREAKDRAW
  DEX
  BNE NEXTSTRING

  RTS
}

; =============== S U B R O U T I N E =======================================
; Read next character from MENUTEXT
.NEXTCHAR
{
  LDA MENUTEXT,Y
  INY

  RTS
}

; ---------------------------------------------------------------------------
.MENUTEXT
  EQUB &22, &69
  EQUS "START",&B0,&B0,&B0,"CONTINUE"
  EQUB END_OF_STRING

  EQUB &22, &AA
  EQUS "TOP"
  EQUB END_OF_STRING

  EQUB &22, &E3
  EQUS "TM",&B0,"AND",&B0,COPYRIGHT,&B0,"1987",&B0,"HUDSON",&B0,"SOFT"
  EQUB END_OF_STRING

  EQUB &23, &2A
  EQUS "LICENSED",&B0,"BY"
  EQUB END_OF_STRING

  EQUB &23, &64
  EQUS "NINTENDO",&B0,"OF",&B0,"AMERICA",&B0,"INC",FULLSTOP
  EQUB END_OF_STRING

; Tile ids used on stage rows
.STAGE_ROWS
  EQUB   1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
  EQUB   1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1
  EQUB   1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  1

; Multiplication tables to find offset within stage map buffer
.MULT_TABY
  EQUB lo(stage_buffer+(MAP_WIDTH*0)),lo(stage_buffer+(MAP_WIDTH*1)),lo(stage_buffer+(MAP_WIDTH*2)),lo(stage_buffer+(MAP_WIDTH*3))
  EQUB lo(stage_buffer+(MAP_WIDTH*4)),lo(stage_buffer+(MAP_WIDTH*5)),lo(stage_buffer+(MAP_WIDTH*6)),lo(stage_buffer+(MAP_WIDTH*7))
  EQUB lo(stage_buffer+(MAP_WIDTH*8)),lo(stage_buffer+(MAP_WIDTH*9)),lo(stage_buffer+(MAP_WIDTH*10)),lo(stage_buffer+(MAP_WIDTH*11))
  EQUB lo(stage_buffer+(MAP_WIDTH*12))
.MULT_TABX
  EQUB hi(stage_buffer+(MAP_WIDTH*0)),hi(stage_buffer+(MAP_WIDTH*1)),hi(stage_buffer+(MAP_WIDTH*2)),hi(stage_buffer+(MAP_WIDTH*3))
  EQUB hi(stage_buffer+(MAP_WIDTH*4)),hi(stage_buffer+(MAP_WIDTH*5)),hi(stage_buffer+(MAP_WIDTH*6)),hi(stage_buffer+(MAP_WIDTH*7))
  EQUB hi(stage_buffer+(MAP_WIDTH*8)),hi(stage_buffer+(MAP_WIDTH*9)),hi(stage_buffer+(MAP_WIDTH*10)),hi(stage_buffer+(MAP_WIDTH*11))
  EQUB hi(stage_buffer+(MAP_WIDTH*12))

; =============== S U B R O U T I N E =======================================
; Generate a 20 character resume password
.GENERATE_PASSWORD
{
  ; Shift high nibble to low nibble for bomb radius
  LDA BONUS_POWER
  LSR A:LSR A:LSR A:LSR A
  STA BOMB_PWR

  ; Split stage number into high and low nibbles
  LDA STAGE
  AND #&F
  STA STAGE_LO

  LDA STAGE
  LSR A:LSR A:LSR A:LSR A
  STA STAGE_HI

  ; Calculate first 3 checksums
  LDY #0
  LDX #0
  LDA #3
  STA CACHE_X

.loop
  JSR calc_cxsum
  JSR _get_pass_data_var_addr

  LDA TEMP_X:STA (STAGE_MAP),Y

  DEC CACHE_X
  BNE loop

  JSR calc_cxsum

  ; Add checksum 1*2
  LDA PW_CXSUM1
  ASL A
  CLC:ADC TEMP_X
  STA TEMP_X

  ; Add checksum 2*2
  LDA PW_CXSUM2
  ASL A
  CLC:ADC TEMP_X
  STA TEMP_X

  ; Add checksum 3*2
  LDA PW_CXSUM3
  ASL A
  CLC:ADC TEMP_X
  STA PW_CXSUM4 ; Save checksum result as checksum 4

  LDY #0:STY SEED
  LDX #0

.encode_loop
  JSR _get_pass_data_var_addr
  LDA (STAGE_MAP),Y
  AND #&F
  SEC:SBC SEED
  SEC:SBC #7
  AND #&F
  STA password_buffer,X
  STA SEED
  CPX #PW_MAX_CHARS*2
  BNE encode_loop

  ; Set screen position to write next character to
  LDA #&23:LDX #6
  JSR VRAMADDR

  LDX #2 ; Skip first char

.pw_print_loop
  LDA password_buffer,X:TAY
  LDA PW_TRANSLATE_TABLE,Y ; "AOFKCPGELBHMJDNI"
  STA PPU_DATA

  INX:INX
  CPX #(PW_MAX_CHARS+1)*2
  BNE pw_print_loop

  RTS
}

; =============== S U B R O U T I N E =======================================
; Calculate a checksum from 4 data bytes
.calc_cxsum
{
  LDA #4:STA CACHE_Y
  LDA #0:STA TEMP_X

.loop
  JSR _get_pass_data_var_addr

  LDA (STAGE_MAP),Y
  CLC:ADC TEMP_X
  STA TEMP_X

  DEC CACHE_Y
  BNE loop

  RTS
}

; =============== S U B R O U T I N E =======================================
; Point to the Xth password data variable (using STAGE_MAP)
._get_pass_data_var_addr
{
  LDA _pass_data_vars,X:STA STAGE_MAP
  INX

  LDA _pass_data_vars,X:STA STAGE_MAP+1
  INX

  RTS

  ; ---------------------------------------------------------------------------
  ; Memory locations for each variable encoded into the password
._pass_data_vars
  EQUW   SCORE+6,  BONUS_REMOTE,  STAGE_LO,  SCORE,  PW_CXSUM1,  SCORE+5,  BOMB_PWR,  SCORE+3,  BONUS_FIRESUIT,  PW_CXSUM2
  EQUW   BONUS_BOMBS,  SCORE+2,  BONUS_SPEED,  SCORE+1,  PW_CXSUM3,  SCORE+4,  DEBUG,  STAGE_HI,  BONUS_NOCLIP,  PW_CXSUM4
}

; Password translate table
.PW_TRANSLATE_TABLE
  EQUS "AOFKCPGELBHMJDNI"

INCLUDE "bonuses.asm"
INCLUDE "sound.asm"

; Timeout and gamepad state value pairs for DEMO {TIMEOUT, PAD1_STATE} ...
.DEMO_KEYDATA
  EQUB &3D,  1,  3,&81,  3,&80,&1B,  4,  6,&84,&1B,  4,  2,  5,&34,  1,  8,&41,&13,  1
  EQUB   1,  0,  6,  1,  1,  0, &F,  1,  1,  0,  3,  1,  1,  0,&11,  1,  6,&81,&1B,  1
  EQUB   3,&81, &E,  1,&1A,  0,&11,  1,  5,&81,&16,  1,  2,  0,  1,  1,&11,  4,&10,  0
  EQUB &10,&40,&10,  0,  2,  4,  1,  0,  1,  4,  1,  0, &E,  4,  1,  0,  2,  4,  1,  0
  EQUB   1,  4,&38,  0,&1A,  4,  3,  0,  4,  2,  1,  0,  4,&80,  9,  0,&16,  2,  2,  0
  EQUB   2,  4,  5,  2,  1,  0,&15,  4,&3A,  0, &A,&40,&17,  0, &D,  4,  2,  0,  6,&80
  EQUB   6,  0,&1D,  8,  1,  0, &C,  1,  2,  0,  9,&40, &A,  0,&28,  2,  1,  0,&20,  2
  EQUB &1E,  4,  2,&84,  5,&80,&5D,  1,  6,  0,&1D,  2,&21,  8,  4,  0,  6,&80,  3,  0
  EQUB &1A,  2,  2,  0, &F,  8,  2,  0,  9,&40,  8,  0,  8,&40,&14,  0, &F,  8,  1,  0
  EQUB  &D,  8,  1,  0,  1,  8,  1,  0,&11,  8,  2,  0,&1E,  1,  6,&81,&15,  1,  5,&81
  EQUB &19,  1,  6,&81,  6,  0,&1C,  4,  6,&84,  1,&81,  1,  1,  3,  0,&1B,  1,  1,  0
  EQUB  &E,  8,  1,&48,  8,&40,&17,  0, &D,  4,  1,&84,  6,&80,  2,  0,&1E,  2,  4,&82
  EQUB   1,&80,  1,  0,&1F,  4,  5,&84,&1E,  4,  4,&84,  2,&80,&1C,  2,  2,  0, &F,  8
  EQUB   1,  0,  9,&40,&11,  0, &F,  4,  1,  5,  1,  0,  4,  1,  9,&81,&14,  1,  6,&81
  EQUB &19,  1,  1,  0, &E,  8,  3,&48,  1,  0,  6,&40,&14,  0,  6,&80,  2,&88,  4,  8
  EQUB   1,  0,  8,  8,  1,  0,  3,  8,  2,&88,  1,  0,  2,&88,  1,  0,&14,  8,  5,&88
  EQUB   4,  8,  2,  0,&1B,  1,  7,&81,&18,  1,  6,&81,&15,  1,  2,  9,&10,  8, &A,&40
  EQUB &1A,  0, &A,  4,  1,  0,  6,  4,  1,  0,&1E,  2,  6,  0,&10,  8,  3,&84
  
.PADDING
  FOR n, 1, &F000-PADDING
    EQUB &FF
  NEXT

; NOTE : PCM address must a multiple of 64
ORG     &F000
.BOOMPCM
INCBIN "boom.bin"

.DUMMY
  FOR n, 1, &FFF9-DUMMY
    EQUB &FF
  NEXT

; ---------------------------------------------------------------------------

.IRQ
  RTI

; ---------------------------------------------------------------------------

  EQUW NMI
  EQUW RESET
  EQUW IRQ
; end of 'ROM'

.ROMEND

SAVE "bomberman", ROMSTART, ROMEND
