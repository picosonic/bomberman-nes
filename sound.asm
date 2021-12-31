; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR APU_PLAY_MELODY

; Stop playback of music
.APU_STOP
{
  LDA #0:STA APU_MUSIC

.^APU_ABORT
  RTS
}

; =============== S U B R O U T I N E =======================================
; Play melody
.APU_PLAY_MELODY
{
  ; If sound disabled, end now
  LDA APU_DISABLE
  BNE APU_ABORT

  ; If no tune currently playing, end now
  LDA APU_MUSIC
  BEQ APU_ABORT

  ; If tune already set up, then continue playing
  BMI UPDATE_MELODY

  ; Set up tune for playback

  ; If tune to play >= number of tunes, stop playback and end now
  CMP #NUM_TUNES+1
  BCS APU_STOP

  ; Cache tune number
  STA APU_TEMP

  ; Set top bit to indicate setup done
  ORA #&80
  STA APU_MUSIC

  ; Make zero-based for offset calculation
  DEC APU_TEMP
  LDA APU_TEMP
  ASL A:ASL A:ASL A ; * 8 for offset into APU_MELODIES_TAB

  ; Copy 6 bytes of APU_MELODIES_TAB to APU_CHANDAT
  TAY
  LDX #0

.loop
  LDA APU_MELODIES_TAB,Y:STA APU_CHANDAT,X
  INY
  INX
  CPX #6
  BNE loop

  ; Copy last 2 bytes of APU_MELODIES_TAB entry
  LDA APU_MELODIES_TAB,Y:STA APU_FLAGS
  LDA APU_MELODIES_TAB+1,Y:STA APU_FLAGS+1

  LDA #0

  STA APU_CNT
  STA APU_CNT+1
  STA APU_CNT+2

  STA byte_D5

  STA byte_CD
  STA byte_CD+1
  STA byte_CD+2

  STA byte_D0
  STA byte_D0+1
  STA byte_D0+2

  LDA #1

  STA byte_B6
  STA byte_B6+1
  STA byte_B6+2

  STA byte_B9
  STA byte_B9+1
  STA byte_B9+2

  STA byte_D6
  STA byte_D6+1
  STA byte_D6+2

  ; Hard code pulse channel sweep to 8 (negate, i.e. disable sweep)
  LDA #8
  STA APU_SWEEP
  STA APU_SWEEP+1

  ; Continue playback
.UPDATE_MELODY
  LDA #2:STA APU_CHAN ; Start at triangle

.NEXT_CHANNEL
  LDX APU_CHAN
  DEC byte_B6,X
  BEQ PLAY_CHANNEL

.^ADVANCE_CHANNEL
  DEC APU_CHAN
  BPL NEXT_CHANNEL

  RTS
}

; ---------------------------------------------------------------------------

.PLAY_CHANNEL
{
  ; X = X * 2
  TXA:ASL A:TAX

  ; Set up APU_PTR
  LDA APU_CHANDAT,X:STA APU_PTR
  LDA APU_CHANDAT+1,X:STA APU_PTR+1

  ; If APU_PTR = &0000 for this channel, move to next channel
  ORA APU_PTR
  BEQ ADVANCE_CHANNEL

  ; Process next action for this channel
  JSR APU_WRITE_REGS

  ; Move to next channel
  JMP ADVANCE_CHANNEL
}

; =============== S U B R O U T I N E =======================================

.APU_WRITE_REGS
{
  LDX APU_CHAN
  LDY APU_CNT,X
  LDA (APU_PTR),Y:STA APU_TEMP
  INC APU_CNT,X

  ; Check for top bit being set, if so process as a control byte
  LDA APU_TEMP
  BMI CONTROL_BYTE

  LDA byte_B9,X:STA byte_B6,X
  CPX #2
  BEQ FIX_TRIANGLE

  LSR A
  LSR A
  CMP #&10
  BCC FIX_DELAY

  LDA #&F
  BNE FIX_DELAY

.FIX_TRIANGLE
  ASL A
  BPL FIX_DELAY

  LDA #&7F

.FIX_DELAY
  STA byte_D6,X

  LDA byte_D0,X
  BEQ loc_E57B

  LSR byte_D6,X

.loc_E57B
  LDY APU_CHAN_DIS,X
  BNE ABORT_WRITE

  LDA APU_TEMP
  CMP #0
  BEQ ABORT_WRITE

  TXA:ASL A:ASL A:TAY ; Y = X * 4

  LDA byte_CD,X
  BEQ loc_E59D
  BPL loc_E593

  INC byte_CD,X
  BEQ loc_E59D

.loc_E593
  LDA #&9F
  CPX #2
  BNE loc_E5A1

  LDA #&7F
  BNE loc_E5A1

.loc_E59D
  LDA byte_D6,X
  ORA APU_FLAGS,X

.loc_E5A1
  STA APU_REG_BASE,Y ; Channel - flags

  LDA byte_CD,X
  CMP #2
  BNE loc_E5AB

  RTS
}

; ---------------------------------------------------------------------------
.loc_E5AB
{
  CPX #2
  BCS SET_WAVELEN

  LDA APU_SWEEP,X:STA APU_REG_BASE+1,Y ; Pulse channel - sweep unit (hard coded to 8)

.SET_WAVELEN
  LDA APU_TEMP
  ASL A
  TAX

  LDA WAVELEN_TAB,X:STA APU_REG_BASE+2,Y ; Channel - timer low

  LDA WAVELEN_TAB+1,X
  ORA #8
  STA APU_REG_BASE+3,Y ; Channel - timer high

.^ABORT_WRITE
  RTS
}

; ---------------------------------------------------------------------------
; Top bit set indicates control byte
.CONTROL_BYTE
{
  ; If top nibble is &F0 then process as an effect code
  AND #&F0
  CMP #&F0
  BEQ EXEC_EFFECT

  LDA APU_TEMP
  AND #&7F ; Clear top bit
  STA byte_B9,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Top nibble &F0 indicates effect byte
.EXEC_EFFECT
{
  ; Calculate jump table offset
  SEC
  LDA #&FF
  SBC APU_TEMP
  ASL A
  TAY

  LDA MELODY_EFFECT_JUMP_TABLE+1,Y:PHA
  LDA MELODY_EFFECT_JUMP_TABLE,Y:PHA

  RTS
}

; ---------------------------------------------------------------------------
; Jump table for melody effects
.MELODY_EFFECT_JUMP_TABLE
  EQUW MELODY_STOP_MUSIC-1
  EQUW MELODY_RESTART_CHANNEL-1
  EQUW MELODY_SETUP_PAUSE-1
  EQUW MELODY_DO_PAUSE-1
  EQUW MELODY_EFFECT_FB-1
  EQUW MELODY_EFFECT_FA-1
  EQUW MELODY_EFFECT_F9-1
  EQUW MELODY_EFFECT_F8-1

; ---------------------------------------------------------------------------
; Melody effect &FF - stop melody playing
.MELODY_STOP_MUSIC
{
  LDA #0:STA APU_MUSIC

  RTS
}

; ---------------------------------------------------------------------------
; Melody effect &FE - restart current channel
.MELODY_RESTART_CHANNEL
{
  LDA #0:STA APU_CNT,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &FD - set up pause/sustain
.MELODY_SETUP_PAUSE
{
  ; Read next byte in stream
  LDY APU_CNT,X
  LDA (APU_PTR),Y
  
  ; Save byte as timer
  STA APU_PAUSE_TIMER,X

  ; Advance data pointer
  INY
  STY APU_CNT,X

  ; Record this position as the place to hold during the pause
  STY APU_PAUSE_PTR,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &FC - do pause/sustain
.MELODY_DO_PAUSE
{
  ; Decrement pause timer for current channel
  DEC APU_PAUSE_TIMER,X

  ; If timer expired, move on
  BEQ done

  ; Timer still going so maintain position
  LDA APU_PAUSE_PTR,X:STA APU_CNT,X

.done
  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &FB
.MELODY_EFFECT_FB
{
  ; If CD[X]=0 then
  ;   CD[X]=1
  ; else
  ;   CD[X]=2
  LDA byte_CD,X
  BEQ set_to_one

  LDA #2:STA byte_CD,X
  JMP APU_WRITE_REGS
 
; ---------------------------------------------------------------------------

.set_to_one
  LDA #1:STA byte_CD,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &FA
.MELODY_EFFECT_FA
{
  ; CD[X]=&FF
  LDA #&FF:STA byte_CD,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &F9
.MELODY_EFFECT_F9
{
  LDA #&FF:STA byte_D0,X

  JMP APU_WRITE_REGS
}

; ---------------------------------------------------------------------------
; Melody effect &F8
.MELODY_EFFECT_F8
{
  LDA #0:STA byte_D0,X

  JMP APU_WRITE_REGS
}

; =============== S U B R O U T I N E =======================================
; Bring up the state of the APU
.APU_RESET
{
  LDA #0

  STA APU_DMC_RAW_REG

  STA APU_CHAN_DIS
  STA APU_CHAN_DIS+1
  STA APU_CHAN_DIS+2

  STA APU_SQUARE1_REG
  STA APU_SQUARE2_REG
  STA APU_TRIANGLE_REG
  STA APU_NOISE_REG

  LDA #&F:STA APU_MASTERCTRL_REG

  RTS
}

; =============== S U B R O U T I N E =======================================
; Play sound effect
.APU_PLAY_SOUND
{
  LDX #2

.MUTE_CHANNEL
  LDA APU_CHAN_DIS,X
  BEQ MUTE_NEXT_CHAN

  DEC APU_CHAN_DIS,X

.MUTE_NEXT_CHAN
  DEX
  BPL MUTE_CHANNEL

  LDA APU_SOUND   ; Play sound
  BMI UPDATE_SOUND

  CMP #7
  BCS WRONG_SOUND ; >= 7

  CMP #3
  BCS START_SOUND ; >= 3

  LDX APU_PATTERN
  BEQ START_SOUND

  TXA
  ORA #&80
  STA APU_SOUND   ; Play sound
  BNE UPDATE_SOUND

.START_SOUND
  STA APU_PATTERN
  ORA #&80
  STA APU_SOUND   ; Play sound

  LDA #0
  STA APU_SOUND_MOD
  STA APU_SOUND_MOD+1
  STA APU_SOUND_MOD+2

  ; Load up function pointer from jump table
  LDA APU_PATTERN:ASL A:TAX
  LDA MOD_SOUND_TAB+1,X:PHA
  LDA MOD_SOUND_TAB,X:PHA

  RTS
}

; ---------------------------------------------------------------------------

.UPDATE_SOUND
{
  LDA APU_PATTERN
  CMP #7
  BCS WRONG_SOUND

  ; Load up function pointer from jump table
  ASL A:TAX
  LDA CONST_SOUND_TAB+1,X:PHA
  LDA CONST_SOUND_TAB,X:PHA

.^WRONG_SOUND
  RTS
}

; ---------------------------------------------------------------------------

; Jump table for initialisation of sound effect
.MOD_SOUND_TAB
  EQUW APU_RESET-1 ; 0 Reset APU
  EQUW S1_START-1  ; 1 Bomberman footsteps 1 (horizontal)
  EQUW S2_START-1  ; 2 Bomberman footsteps 2 (vertical)
  EQUW S3_START-1  ; 3 Place a bomb
  EQUW S4_START-1  ; 4 Bonus collected
  EQUW S5_START-1  ; 5 Collision between enemy and bomberman
  EQUW S6_START-1  ; 6 Pause/Unpause and all enemies defeated

; Jump table for continuation of sound effect
.CONST_SOUND_TAB
  EQUW WRONG_SOUND-1 ; 0
  EQUW WRONG_SOUND-1 ; 1
  EQUW WRONG_SOUND-1 ; 2
  EQUW S3_UPDATE-1   ; 3
  EQUW S4_UPDATE-1   ; 4
  EQUW WRONG_SOUND-1 ; 5
  EQUW S6_UPDATE-1   ; 6

; ---------------------------------------------------------------------------

; 1/2 = Bomberman footsteps
.S1_START
{
  LDA #4 ; Noise period = 64 (NTSC)
  BNE SETNOISEPERIOD ; Skip S2_START noise period

.^S2_START
  LDA #&C ; Noise period = 762 (NTSC)

.SETNOISEPERIOD
  STA APU_NOISE_REG+2

  LDA #0:STA APU_PATTERN:STA APU_NOISE_REG
  LDA #&10:STA APU_NOISE_REG+3 ; Noise length = 12

  RTS
}

; ---------------------------------------------------------------------------

; 3 = Place a bomb
.S3_START
{
  LDA #&10:STA APU_SOUND_MOD+1
  LDA #1:STA APU_NOISE_REG
  LDA #&F:STA APU_NOISE_REG+2
  LDA #&10:STA APU_NOISE_REG+3
  LDA #&FF:STA APU_SQUARE2_REG
  LDA #&84:STA APU_SQUARE2_REG+1
  LDA #0:STA APU_SQUARE2_REG+2
  LDA #2:STA APU_SQUARE2_REG+3
  LDA #4:STA APU_SDELAY

  RTS
}
; ---------------------------------------------------------------------------

.S3_UPDATE
{
  DEC APU_SDELAY
  BNE done

  LDA #&DF:STA APU_SQUARE2_REG
  LDA #&84:STA APU_SQUARE2_REG+1
  LDA #0:STA APU_SQUARE2_REG+2
  LDA #&81:STA APU_SQUARE2_REG+3
  LDA #0:STA APU_PATTERN

.done
  RTS
}

; ---------------------------------------------------------------------------

; 4 = Bonus collected
.S4_START
{
  LDA #&FF:STA APU_SOUND_MOD+1
  LDA #0:STA APU_SDELAY
  LDA #4:STA APU_SDELAY+1

.^S4_UPDATE
  LDA APU_SDELAY
  BNE S4_PITCH1

  LDA APU_SDELAY+1
  BNE S4_PITCH2

  LDA #0
  STA APU_PATTERN
  STA APU_SOUND_MOD+1

  RTS

; ---------------------------------------------------------------------------

.S4_PITCH2
  DEC APU_SDELAY+1

  LDA #&84:STA APU_SQUARE2_REG
  LDA #&8B:STA APU_SQUARE2_REG+1

  LDX APU_SDELAY+1

  LDA S4_PITCH_TAB,X:STA APU_SQUARE2_REG+2
  LDA #&10:STA APU_SQUARE2_REG+3
  LDA #4:STA APU_SDELAY

.S4_PITCH1
  DEC APU_SDELAY
  RTS

; ---------------------------------------------------------------------------
.S4_PITCH_TAB
  EQUB &65,&87,&B4,&F0
}

; 5 = Collision between enemy and bomberman
.S5_START
{
  LDA #&30:STA APU_SOUND_MOD+1
  LDA #9:STA APU_NOISE_REG
  LDA #7:STA APU_NOISE_REG+2
  LDA #&30:STA APU_NOISE_REG+3
  LDA #&1F:STA APU_SQUARE2_REG
  LDA #&8F:STA APU_SQUARE2_REG+1
  LDA #0:STA APU_SQUARE2_REG+2
  LDA #&33:STA APU_SQUARE2_REG+3
  LDA #0:STA APU_PATTERN

  RTS
}
; ---------------------------------------------------------------------------
; 6 = PAUSE / UNPAUSE

.S6_START
{
  LDA #&1D:STA APU_SDELAY

  LDA #&FF
  STA APU_SOUND_MOD+0
  STA APU_SOUND_MOD+1
  STA APU_SOUND_MOD+2

.^S6_UPDATE
  DEC APU_SDELAY
  BEQ S6_PITCH

  LDA APU_SDELAY
  AND #3
  BNE S6_END

  LDA APU_SDELAY
  LSR A
  LSR A
  AND #1
  TAX

  LDA S6_SQ1MOD_TAB,X:STA APU_SQUARE1_REG+2
  LDA S6_SQ2MOD_TAB,X:STA APU_SQUARE2_REG+2

  LDA #8
  STA APU_SQUARE1_REG
  STA APU_SQUARE2_REG
  STA APU_SQUARE1_REG+1
  STA APU_SQUARE2_REG+1
  STA APU_SQUARE1_REG+3
  STA APU_SQUARE2_REG+3

.S6_END
  RTS

; ---------------------------------------------------------------------------

.S6_PITCH
  LDA #&20
  STA APU_SOUND_MOD+0
  STA APU_SOUND_MOD+1
  STA APU_SOUND_MOD+2

  LDA #0:STA APU_PATTERN

  RTS

; ---------------------------------------------------------------------------
.S6_SQ1MOD_TAB
  EQUB &A9
  EQUB &A0

.S6_SQ2MOD_TAB
  EQUB &6A
  EQUB &64
}

; Wavelength for square wave notes on an NTSC system (triangle wave are one octave lower)
.WAVELEN_TAB
  EQUW    0 ; Silence
  ;       A    Bb     B     C    C#     D    D#     E     F    F#     G    G#   Scientific designation
  EQUW &7F0, &77E, &712, &6AE, &64E, &5F3, &59F, &54D, &501, &4B9, &475, &435 ; Octave 2
  EQUW &3F8, &3BF, &389, &357, &327, &2F9, &2CF, &2A6, &280, &25C, &23A, &21A ; Octave 3
  EQUW &1FC, &1DF, &1C4, &1AB, &193, &17C, &167, &152, &13F, &12D, &11C, &10C ; Octave 4 (With middle C)
  EQUW  &FD,  &EE,  &E1,  &D4,  &C8,  &BD,  &B2,  &A8,  &9F,  &96,  &8D,  &85 ; Octave 5
  EQUW  &7E,  &76,  &70,  &69,  &63,  &5E,  &58,  &53,  &4F,  &4A,  &46,  &42 ; Octave 6
  EQUW  &3E,  &3A,  &37,  &34,  &31,  &2E,  &2B,  &29,  &27,  &24,  &22,  &20 ; Octave 7
  EQUW  &1E,  &1C,  &1B,  &1A                                                 ; Octave 8

.APU_MELODIES_TAB
  EQUW TUNE1_TRI   , TUNE1_SQ2   ,  TUNE1_SQ1, &8080 ; 1: TITLE
  EQUW TUNE2_TRI   , TUNE2_SQ2   ,  TUNE2_SQ1, &4040 ; 2: STAGE_SCREEN
  EQUW            0,            0,  TUNE3_SQ1, &8080 ; 3: STAGE
  EQUW TUNE4_TRI   , TUNE4_SQ2   ,  TUNE4_SQ1, &8080 ; 4: STAGE2
  EQUW TUNE5_TRI   , TUNE5_SQ2   ,  TUNE5_SQ1, &8080 ; 5: GODMODE
  EQUW TUNE6_TRI   , TUNE6_SQ2   ,  TUNE6_SQ1, &8080 ; 6: BONUS
  EQUW TUNE7_TRI   , TUNE7_SQ2   ,  TUNE7_SQ1, &0040 ; 7: FANFARE
  EQUW TUNE8_TRI   , TUNE8_SQ2   ,          0, &8080 ; 8: DIED
  EQUW TUNE9_TRI   , TUNE9_SQ2   , TUNE9_SQ1 , &8080 ; 9: GAMEOVER
  EQUW TUNE7_TRI+55, TUNE7_SQ2+59, TUNE10_SQ1, &0040 ; 10: ???

.TUNE7_TRI
  EQUB &B0,&29,&AA,&29,&86,&29,&A4,&30,&86,&30,&35,&F9,&8C,&2E,&F8,&98
  EQUB &2D,&86,&2D,&2E,&8C,&2D,&C8,&2B,&86,&32,&33,&8C,&32,&B0,&30,&8C
  EQUB   0,&26,&28,&B0,&29,&AA,&29,&86,&29,&A4,&30,&86,&30,&35,&F9,&8C
  EQUB &2E,&F8,&98,&2D,&86,&2D,&2E,&8C,&2D,&2B,&32,&33,&30,  0,&92,&30
  EQUB &83,&32,&34,&8C,&35,  0,&1D,&86,&1D,&1D,&8C,&1D,  0,&98,  0,&FF
.TUNE7_SQ2
  EQUB &B0,&21,&AA,&21,&86,&21,&A4,&2D,&86,&2D,&30,&F9,&8C,&29,&F8,&98
  EQUB &29,&86,&24,&29,&8C,&24,&C8,&27,&86,&2E,&2B,&8C,&2E,&28,&92,&24
  EQUB &86,&24,&8C,&24,&24,&24,&24,&B0,&21,&AA,&21,&86,&21,&A4,&2D,&86
  EQUB &2D,&30,&F9,&8C,&29,&F8,&98,&29,&86,&24,&29,&8C,&29,&26,&2B,&2E
  EQUB &28,  0,&92,&28,&83,&29,&2B,&8C,&2D,  0,&11,&86,&11,&11,&8C,&11
  EQUB   0,&98,  0,&FF
.TUNE7_SQ1
  EQUB &F9,&FD,  2,&98,&1D,&1C,&1A,&18,&FC,&1B,&1A,&18,&16,&18,&18,&1A
  EQUB &1C,&FD,  2,&1D,&1C,&1A,&18,&FC
.TUNE10_SQ1
  EQUB &F8,&8C,&1F,&1D,&1B,&2B,&18,  0,&92,&18,&83,&18,&18,&8C,&29,  0
  EQUB &11,&86,&11,&11,&8C,&11,  0,&98,  0,&FF
.TUNE9_TRI
  EQUB &98,&28,&92,&24,&86,&24,&98,&27,&92,&24,&86,&24,&28,&29,&2A,&2B
  EQUB &F9,&8C,&28,&24,&F8,&98,&22,&29,&28,&92,&24,&86,&24,&98,&27,&92
  EQUB &24,&86,&24,&8C,&22,&84,&21,&20,&1F,&F9,&8C,&22,&23,&F8,&24,  0
  EQUB &98,  0,&FF
.TUNE9_SQ2
  EQUB &E0,  0,&86,&1F,&21,&22,&23,&F9,&8C,&1F,&1C,&F8,&98,&1D,&22,&1F
  EQUB &92,&1C,&86,&1C,&98,&1E,&92,&1B,&86,&1E,&8C,&16,&84,&15,&14,&13
  EQUB &F9,&8C,&16,&17,&F8,&18,  0, &C,  0,&FF
.TUNE9_SQ1
  EQUB &8C,&18,&1F,  0,&1F,&18,&1F,  0,&1F,&18,&1F,  0,&1F,&14,&1B,  0
  EQUB &1B,&18,&1F,  0,&1F,&14,&1B,  0,&1B,&16,&84,&15,&14,&13,&F9,&8C
  EQUB &16,&17,&F8,&18,  0, &C,  0,&FF
.TUNE6_TRI
  EQUB &94,  0,&85,&2C,&2C,&33,&33,&8A,&33,  0,&85,&2C,&2C,&33,&33,&32
  EQUB &32,&30,&30,&2E,&2E,&29,&29,&26,&26,&24,&24,&94,&22,  0,&85,&31
  EQUB &31,&36,&36,&8A,&36,  0,&85,&31,&31,&3A,&3A,&37,&37,&35,&35,&33
  EQUB &33,&31,&31,&30,&30,&2E,&2E,&2C,&2C,&2B,&2B,&FE
.TUNE6_SQ2
  EQUB &94,  0,&85,&24,&24,&30,&30,&8A,&30,  0,&85,&24,&24,&30,&30,&2E
  EQUB &2E,&2D,&2D,&29,&29,&26,&26,&22,&22,&1D,&1D,&94,&1A,  0,&85,&2E
  EQUB &2E,&31,&31,&8A,&31,  0,&85,&2E,&2E,&31,&31,&33,&33,&31,&31,&30
  EQUB &30,&2E,&2E,&2C,&2C,&2B,&2B,&24,&24,&22,&22,&FE
.TUNE6_SQ1
  EQUB &85,&14,&14,&20,&20,&2C,&2C,&20,&20,&14,&14,&20,&20,&2C,&2C,&20
  EQUB &20,&16,&16,&22,&22,&2E,&2E,&22,&22,&16,&16,&22,&22,&16,&16,&22
  EQUB &22,&12,&12,&1E,&1E,&2A,&2A,&1E,&1E,&12,&12,&1E,&1E,&2A,&2A,&1E
  EQUB &1E, &F, &F,&1B,&1B,&27,&27,&1B,&1B, &F, &F,&1B,&1B,&27,&27,&25
  EQUB &25,&FE
.TUNE8_TRI
  EQUB &83,&30,&2B,&24,&1F,&18,&13, &C,  7,&18,&17,&16,&15,&14,&15,&16 
  EQUB &17,&92,&18,&86,&18,&F9,&8C,&1B,&1B,&F8,&98,&18,  0,&FF
.TUNE8_SQ2
  EQUB &98,  0,&83, &C, &B, &A,  9,  8,  9, &A, &B,&92, &C,&86, &C,&F9
  EQUB &8C, &F, &F,&F8,&98, &C,  0,&FF
.TUNE1_TRI
  EQUB &87,&27,&33,&3F,&33,&36,&37,&33,&31,&27,&33,&3F,&33,&36,&37,&33
  EQUB &31,&16,&16,&F9,&8E,&16,&F8,&87,&22,&22,&F9,&8E,&2E, &D, &F,&F8
  EQUB &87,&38,&2E,&33,&38,&FD,  3,&F9,&8E,&37,&33,&32,&33,&F8,&9C,&2E
  EQUB &87,&2C,&2E,&2A,&2B,&8E,  0,&3A,  0,&3A,&87,&33,&33,&F9,&8E,&33
  EQUB &F8,&87,&38,&2E,&33,&38,&FC,&F9,&8E,&37,&F8,&87,&32,&33,&2C,&2E
  EQUB &F9,&8E,&2B,&F8,&87,&2C,&2C,&F9,&8E,&2C,&F8,&87,&2B,&2B,&F9,&8E
  EQUB &2B,&27,&27,  0,&F8,&87,&25,&26,&8E,&27,  0,&9C,  0,&FF
.TUNE1_SQ2
  EQUB &87,&1B,&27,&33,&27,&2A,&2B,&27,&25,&1B,&27,&33,&27,&2A,&2B,&27
  EQUB &25,&13,&13,&F9,&8E,&13,&F8,&87,&1F,&1F,&F9,&8E,&2B,  1,  2,&F8
  EQUB &87,&2C,&22,&27,&2C,&FD,  3,&F9,&8E,&31,&2E,&2A,&2B,&F8,&9C,&25
  EQUB   0,&8E,&27,&22,&25,&2C,&9C,&2B,&87,&35,&22,&30,&33,&FC,&F9,&8E
  EQUB &33,&F8,&87,&2A,&2B,&26,&27,&F9,&8E,&22,&F8,&87,&27,&27,&F9,&8E
  EQUB &27,&F8,&87,&27,&27,&F9,&8E,&27,&1F,&1F,  0,&F8,&87,&19,&1A,&8E
  EQUB &1B,  0,&9C,  0,&FF
.TUNE1_SQ1
  EQUB &87,&1B,&1B,&1B,&1B,&9C,  0,&87,&1B,&1B,&1B,&1B,&9C,  0,&87,&19
  EQUB &19,&F9,&8E,&19,&F8,&87,&25,&25,&F9,&8E,&32,&F8,&B8,  0,&FD,  3
  EQUB &87,&1B,&1B,&F9,&8E,&1B,&1E,&F8,&87,&1F,&22,&27,&1B,&1B,&1B,&1E
  EQUB &F9,&8E,&1F,&F8,&87,&18,&19,&19,&19,&25,&18,&1A,&8E,&16,&87,&25
  EQUB &19,&19,&19,&9C,  0,&FC,&F9,&8E,&2E,&F8,&87,&2D,&2E,&2A,&2B,&27
  EQUB &22,&9C,  0,&87,&23,&23,&F9,&8E,&23,&22,&22,&F8,  0,&87,&19,&1A
  EQUB &8E,&1B,  0,&9C,  0,&FF
.TUNE5_TRI
  EQUB &FD,  2,&90,&25,&88,&27,&29,  0,&29,&2B,  0,&FC,&C0,  0,&88,&22
  EQUB &19,&22,&20,&1F,&19,&1F,&20,&FD,  2,&27,&29,&27,&2A,  0,&29,&27
  EQUB   0,&FC,&C0,  0,&88,&20,&17,&20,&1E,&1D,&17,&1D,&1F,&FE
.TUNE5_SQ2
  EQUB &FD,  2,&90,&22,&88,&24,&26,  0,&26,&27,  0,&FC,&FD,  2,&1B,&13
  EQUB &1B,&19,&18,&13,&18,&19,&FC,&FD,  2,&23,&25,&23,&27,  0,&25,&23
  EQUB   0,&FC,&FD,  2,&19,&11,&19,&17,&16,&11,&16,&19,&FC,&FE
.TUNE5_SQ1
  EQUB &FD,  4,&90,&1B,&1B,&1B,&1B,&FC,&FD,  4,&19,&19,&19,&19,&FC,&FE
.TUNE2_TRI
  EQUB &85,&33,  0,&32,&33,&32,&33,&32,&33,&2E,  0,&2D,&2E,&2D,&2E,&2D
  EQUB &2E,&2B,&2C,&2D,&2E,&2B,&2C,&2D,&2E,&2B,  0,&27,  0,&94,&25,&FF
.TUNE2_SQ2
  EQUB &85,&2B,  0,&2A,&2B,&2A,&2B,&2A,&2B,&27,  0,&26,&27,&26,&27,&26
  EQUB &27,&27,&29,&2A,&2B,&27,&29,&2A,&2B,&27,  0,&1F,  0,&94,&22,&FF
.TUNE2_SQ1
  EQUB &F9,&8A,&1B,&1B,&1F,&22,&1B,&1B,&1F,&22,&F8,&85,&22,&24,&26,&27
  EQUB &22,&24,&26,&27,&F9,&8A,&22,&1B,&F8,&94,&16,&FF
.TUNE4_SQ1
  EQUB &FD,  2,&87,&27,&27,&F9,&8E,&30,&31,&F8,&87,&22,&22,&F9,&8E,&2E
  EQUB &30,&F8,&87,&31,&30,&F9,&8E,&2E,&F8,&FC,&FD,  2,&87,&25,&25,&F9
  EQUB &8E,&2E,&2F,&F8,&87,&20,&20,&F9,&8E,&2C,&2E,&F8,&87,&2F,&2E,&F9
  EQUB &8E,&2C,&F8,&FC,&FE
.TUNE4_TRI
  EQUB &9C,  0,&87,&25,&95,  0,&B8,  0,&9C,  0,&95,&27,&87,&27,&F9,&8E
  EQUB &2C,&2B,&F8,&27,  0,&9C,  0,&87,&23,&95,  0,&B8,  0,&9C,  0,&95
  EQUB &25,&87,&25,&F9,&8E,&2A,&F8,&87,&29,&2A,&8E,&25,  0,&FE
.TUNE4_SQ2
  EQUB &9C,  0,&87,&1D,&95,  0,&B8,  0,&9C,  0,&87,&1D,&95,  0,&B8,  0
  EQUB &9C,  0,&87,&1B,&95,  0,&B8,  0,&9C,  0,&87,&1B,&95,  0,&B8,  0
  EQUB &FE
.TUNE3_SQ1
  EQUB &87,&27,&27,&33,&27,&F9,&8E,&2A,&F8,&87,&2E,&30,&F9,&8E,&31,&31
  EQUB &F8,&30,  0,&87,&25,&25,&31,&25,&F9,&8E,&29,&F8,&87,&2C,&2E,&F9
  EQUB &8E,&2F,&F8,&87,&2E,&2F,&25,&24,&F9,&8E,&25,&F8,&87,&22,&22,&2E
  EQUB &22,&F9,&8E,&2C,&F8,&87,&2B,&2C,&F9,&8E,&22,&2E,&F8,&22,  0,&87
  EQUB &22,&22,&2E,&22,&F9,&8E,&2C,&F8,&87,&2B,&2C,&F9,&8E,&22,&2E,&F8
  EQUB &87,&22,&22,&24,&26,&FE
