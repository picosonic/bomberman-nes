
; =============== S U B R O U T I N E =======================================
; Read gamepad inputs
; This is done multiple times due to a bug (in NTSC NES) when PCM playback is ongoing
.PAD_READ
{
  ; Read from pad hardware
  JSR PAD_STROBE

  ; Cache what we read from each gamepad
  LDA JOYPAD1:STA PAD1_TEST
  LDA JOYPAD2:STA PAD2_TEST

  ; Read from pad hardware
  JSR PAD_STROBE

  ; If new JOYPAD1 value differs from last one, reset
  LDA JOYPAD1
  CMP PAD1_TEST
  BNE PAD_DRE

  ; If new JOYPAD2 value differes from last one, reset
  LDA JOYPAD2
  CMP PAD2_TEST
  BNE PAD_DRE

  RTS

; ---------------------------------------------------------------------------

  ; Reset both pads to blank
.PAD_DRE
  LDA #0
  STA JOYPAD1:STA JOYPAD2

  RTS
}

; =============== S U B R O U T I N E =======================================
; Read data for pads, one bit at a time
.PAD_STROBE
{
  LDA #1:STA JOYPAD_PORT1 ; Get controller to poll input (set latch)
  LDA #0:STA JOYPAD_PORT1 ; Finish the poll (clear latch)

  ; Read polled data for JOYPAD1, one bit at a time
  TAX
  LDY #8

.JOY1
  TXA:ASL A:TAX ; Advance result output bitfield by 1 bit
  LDA JOYPAD_PORT1
  JSR IS_PRESSED
  BNE JOY1

  STX JOYPAD1 ; Store result

  ; Read polled data for JOYPAD2, one bit at a time
  LDX #0
  LDY #8

.JOY2
  TXA:ASL A:TAX ; Advance result output bitfield by 1 bit
  LDA JOYPAD_PORT2
  JSR IS_PRESSED
  BNE JOY2

  STX JOYPAD2 ; Store result

  RTS
}

; =============== S U B R O U T I N E =======================================
; If current read has any of D0/D1/D2 set, then update bitfield
.IS_PRESSED
{
  AND #3  ; Mask off D0 (NES standard + hardwired controller) / D1 (Famicom expansion port controller)
  BEQ NOT_PRESSED

  INX ; Set a bit within bitfield

.NOT_PRESSED
  DEY ; Move on to next input bit

  RTS
}
