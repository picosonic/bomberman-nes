PPU_CTRL_REG1       = &2000 ; NMI / PPU master or slave / sprite height / bg tile, sprite tile, nametable select
PPU_CTRL_REG2       = &2001 ; Colour emphasis / sprite, bg enable / sprite, bg left column / greyscale
PPU_STATUS          = &2002 ; VBLANK / sprite 0 hit / sprite overflow
PPU_SPR_ADDR        = &2003 ; OAM address
PPU_SPR_DATA        = &2004 ; OAM data
PPU_SCROLL_REG      = &2005 ; For writing both scroll X then scroll Y
PPU_ADDRESS         = &2006 ; For writing 2-byte PPU VRAM address
PPU_DATA            = &2007 ; Read/write PPU VRAM (includes address auto-increment)

APU_REG_BASE        = &4000 ; Shortcut used with indexed addressing
APU_SQUARE1_REG     = &4000 ; Pulse channel 1 base
APU_SQUARE2_REG     = &4004 ; Pulse channel 2 base
APU_TRIANGLE_REG    = &4008 ; Triangle channel base
APU_NOISE_REG       = &400C ; Noise channel base
APU_DELTA_REG       = &4010 ; Delta modulation channel (for 7 bit PCM)
APU_MASTERCTRL_REG  = &4015 ; Enable/disable APU channels

PPU_SPR_DMA         = &4014 ; OAM DMA

JOYPAD_PORT1        = &4016
JOYPAD_PORT2        = &4017
