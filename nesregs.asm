; Picture processing unit
PPU_CTRL_REG1       = &2000 ; NMI / PPU master or slave / sprite height / bg tile, sprite tile, nametable select
PPU_CTRL_REG2       = &2001 ; Colour emphasis / sprite, bg enable / sprite, bg left column / greyscale
PPU_STATUS          = &2002 ; VBLANK / sprite 0 hit / sprite overflow
PPU_SPR_ADDR        = &2003 ; OAM address
PPU_SPR_DATA        = &2004 ; OAM data
PPU_SCROLL_REG      = &2005 ; For writing both scroll X then scroll Y
PPU_ADDRESS         = &2006 ; For writing 2-byte PPU VRAM address
PPU_DATA            = &2007 ; Read/write PPU VRAM (includes address auto-increment)
PPU_ATTR_TABLE      = &23C0 ; Background palette attribute table for nametable

; Audio processing unit
APU_REG_BASE        = &4000 ; Shortcut used with indexed addressing
APU_SQUARE1_REG     = &4000 ; Pulse channel 1 base
APU_SQUARE2_REG     = &4004 ; Pulse channel 2 base
APU_TRIANGLE_REG    = &4008 ; Triangle channel base
APU_NOISE_REG       = &400C ; Noise channel base
APU_DMC_FREQ_REG    = &4010 ; Delta modulation channel (for 7-bit PCM), play mode and frequency
APU_DMC_RAW_REG     = &4011 ; DMC 7-bit DAC
APU_DMC_START_REG   = &4012 ; DMC start of waveform at address &C000 + &40*&xx
APU_DMC_LEN_REG     = &4013 ; DMC length of waveform is &10*&xx + 1 bytes (128*&xx + 8 samples)
APU_MASTERCTRL_REG  = &4015 ; Enable/disable APU channels

; OAM
PPU_SPR_DMA         = &4014 ; OAM DMA

; I/O
JOYPAD_PORT1        = &4016
JOYPAD_PORT2        = &4017
