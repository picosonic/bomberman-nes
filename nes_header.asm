; iNES header
ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
EQUB $01        ; Number of 16KB PRG-ROM banks
EQUB $01        ; Number of 8KB CHR-ROM banks (0 means use CHR-RAM)
EQUB %00000001  ; Flags  6 - Vertical mirroring, no save RAM, no mapper
EQUB %00000000  ; Flags  7 - No special-case flags set, no mapper
EQUB $00        ; Flags  8 - PRG-RAM size in 8KB units
EQUB %00000000  ; Flags  9 - TV system is NTSC
EQUB %00000000  ; Flags 10 - TV system is NTSC, PRG-RAM (&6000-&7FFF) is present, board has no bus conflicts

.PADDING
  FOR n, 1, 5
    EQUB &00
  NEXT
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
