; iNES header
ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
EQUB &01        ; Number of 16KB PRG-ROM banks
EQUB &01        ; Number of 8KB CHR-ROM banks (0 means use CHR-RAM)
EQUB %00000001  ; Flags  6 - Vertical mirroring, no save RAM, no mapper
EQUB %00000000  ; Flags  7 - No special-case flags set, no mapper
EQUB &00        ; Flags  8 - PRG-RAM size in 8KB units
EQUB %00000000  ; Flags  9 - TV system is NTSC

.PADDING
  FOR n, 1, 6
    EQUB &00
  NEXT
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
