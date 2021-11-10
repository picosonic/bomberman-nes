; Game variables

; ---------------------------------------------------------------------------
; Zero Page ($0000-$00FF).
; ---------------------------------------------------------------------------

; 7 bytes BCD
TOPSCORE            = &01

SOFT_RESET_FLAG     = &08
CLEAR_TOPSCORE1     = &09
CLEAR_TOPSCORE2     = &0A
FRAMEDONE           = &0B

LAST_2000           = &0C ; Cache of what was sent to PPU_CTRL_REG1
LAST_2001           = &0D ; Cache of what was sent to PPU_CTRL_REG2

; Scroll offsets
H_SCROLL            = &0E ; Horizontal
V_SCROLL            = &0F ; Vertical

; Joypad bit fields
PAD1_TEST           = &10 ; Cache for multiple reads to work around NTSC bug with PCM playback
PAD2_TEST           = &11 ; Cache as above
JOYPAD1             = &12
JOYPAD2             = &13

TILE_CUR            = &14
TILE_PTR            = &15
TILE_CNT            = &16
TILE_PARAM          = &17

CACHE_X             = &1F ; Cached X position
CACHE_Y             = &20 ; Cached Y position
byte_21             = &21
byte_22             = &22
byte_23             = &23

TEMP_X              = &24
TEMP_Y              = &25

OAM_PTR             = &26 ; Pointer to cache of OAM data

; Bomberman related
BOMBMAN_X           = &28 ; Grid X position
BOMBMAN_U           = &29 ; Offset X
BOMBMAN_Y           = &2A ; Grid Y position
BOMBMAN_V           = &2B ; Offset Y
BOMBMAN_FRAME       = &2C ; Current animation frame

SPR_ATTR_TEMP       = &2D
byte_2E             = &2E ; Bomb/fire related

TEMP_X2             = &2F
TEMP_Y2             = &30
TEMP_A2             = &31

byte_32             = &32
FRAME_CNT           = &33
STAGE_MAP           = &34
byte_36             = &36

BOOM_SOUND          = &38

SPR_TAB_INDEX       = &39
SPR_X               = &3A
SPR_Y               = &3B
SPR_COL             = &3C
SPR_ATTR            = &3D
SPR_ID              = &3E
SPR_SAVEDX          = &3F
SPR_SAVEDY          = &40

; Cache for enemy attributes
M_TYPE              = &41
M_X                 = &42
M_U                 = &43
M_Y                 = &44
M_V                 = &45
M_FRAME             = &46
M_AI_TIMER          = &47
byte_48             = &48
byte_49             = &49
M_FACE              = &4A
byte_4B             = &4B
byte_4C             = &4C
M_ID                = &4D

byte_4E             = &4E
byte_4F             = &4F
byte_50             = &50
byte_51             = &51
byte_52             = &52
byte_53             = &53

; PRNG seed (4 bytes)
SEED                = &54

; Current level (1..50)
STAGE               = &58

; Boolean for DEMO being played
DEMOPLAY            = &59

TEMP_Y3             = &5A
EXIT_ENEMY_TYPE     = &5B
DYING               = &5C ; Boolean, in the process of dying
KILLED              = &5D ; Boolean, have we lost a life on this level
NO_ENEMIES_LEFT     = &5E ; Boolean, when no enemies remain

; Title screen cursor
CURSOR              = &5F ; Boolean, START or CONTINUE menu option

; Indicate if level has been started
STAGE_STARTED       = &60 ; Boolean

; 7 bytes BCD
SCORE               = &61 ; &61..&67

LIFELEFT            = &68
FPS                 = &69
IS_SECOND_PASSED    = &6A
byte_6B             = &6B

; Number of frames @ 60Hz to stay on title screen, counting down to demo start
DEMO_WAIT_HI        = &70
DEMO_WAIT_LO        = &71

; Are we on title screen
INMENU              = &72 ; Boolean

; Bonus item status
BONUS_POWER         = &73 ; Explosion radius in tiles (multiples of 0x10)
BONUS_BOMBS         = &74 ; 0 .. 9, number of extra bombs
BONUS_SPEED         = &75 ; Boolean, normal or fast travel
BONUS_NOCLIP        = &76 ; Boolean, walk through brick walls
BONUS_REMOTE        = &77 ; Boolean, remote detonator
BONUS_BOMBWALK      = &78 ; Boolean, can walk through bombs
BONUS_FIRESUIT      = &79 ; Boolean, invulnerable to explosions

INVULNERABLE_TIMER  = &7A ; Invulnerability to monsters for a short time
LAST_INPUT          = &7B ; Last input bitmask from gamepad
INVULNERABLE        = &7D ; Invulnerable to monsters for this stage (Boolean)
BONUS_ENEMY_TYPE    = &7E

; Password is stored here (20 bytes) .. $92
PW_BUFF             = &7F

; Time in seconds left to play
TIMELEFT            = &93

DEBUG               = &94 ; Shows location of bonus and exit tiles
PW_CXSUM4           = &95 ; Checksum for whole password
MTAB_PTR            = &97 ; Pointer to enemy table
PW_CXSUM1           = &99 ; Checksum for characters 1..4 of password
PW_CXSUM2           = &9A ; Checksum for characters 6..9 of password
PW_CXSUM3           = &9B ; Checksum for characters 11..14 of password

; Extra bonus item criteria
ENEMIES_LEFT        = &9C
BONUS_AVAILABLE     = &9D
ENEMIES_DEFEATED    = &9E
EXIT_DWELL_TIME     = &9F ; How long we are over exit tile for
VISITS_TOP_LEFT     = &A0
VISITS_TOP_RIGHT    = &A1
VISITS_BOTTOM_LEFT  = &A2
VISITS_BOTTOM_RIGHT = &A3
BRICKS_BLOWN_UP     = &A4
CHAIN_REACTIONS     = &A5
KEY_TIMER           = &A6 ; How long at least one key is pressed for
EXIT_BOMBED_COUNT   = &A7
BONUS_STATUS        = &A8 ; 0 = Criteria not met / 1 = Achieved / 2 = Collected
BONUS_TIMER         = &A9 ; Time which the bonus is on screen for
EXTRA_BONUS_ITEM_X  = &AA ; X position where extra bonus is placed
EXTRA_BONUS_ITEM_Y  = &AB ; Y position where extra bonus is placed

DEMOKEY_DATA        = &AC ; Pointer to DEMO timeout/pad data
DEMOKEY_TIMEOUT     = &AE ; Current DEMO key timeout
DEMOKEY_PAD1        = &AF ; Current DEMO pad state

DEMO_ENDED          = &B0 ; Count of times the demo has ended
NO_ENEMIES_CELEBRATED = &B1 ; Boolean

; Audio related
APU_DISABLE         = &B2 ; Boolean to keep track of music being disabled when paused
APU_CHAN            = &B3 ; Current audio channel
APU_TEMP            = &B4
APU_MUSIC           = &B5 ; Currently selected melody (top bit set once initialised)
byte_B6             = &B6 ; ?? for each of the 3 channels
byte_B9             = &B9 ; ?? for each of the 3 channels
APU_CHANDAT         = &BC ; 6 bytes of current melody/channel data
APU_PTR             = &C2 ; Pointer to position in current melody data
APU_CNT             = &C4 ; Counters for each of the 3 channels through their respective melody data
APU_PAUSE_PTR       = &C7 ; Melody data counter when in sustain for each of the 3 channels
APU_PAUSE_TIMER     = &CA ; Sustain countdown for each of the 3 channels
byte_CD             = &CD ; ?? for each of the 3 channels
byte_D0             = &D0 ; ?? (FF or 00) for each of the 3 channels
APU_FLAGS           = &D3 ; Cache for seventh and eighth bytes from melody table
byte_D5             = &D5
byte_D6             = &D6 ; ?? for each of the 3 channels
APU_SWEEP           = &D9 ; Hard coded to 08 for both of the pulse channels to disable sweep

SPR_TAB_TOGGLE      = &DB

; Used for BONUS_POWER calculations with resume codes
BOMB_PWR            = &DC

; Used for low byte of STAGE in resume codes
STAGE_LO            = &DD
; Used for high byte of STAGE in resume codes
STAGE_HI            = &DE

APU_SOUND           = &DF
APU_PATTERN         = &E0
TEMP_ADDR           = &E0
APU_CHAN_DIS        = &E1
APU_SOUND_MOD       = &E1
APU_SDELAY          = &E4

; ---------------------------------------------------------------------------
; Lower memory ($0100-$07FF).
; ---------------------------------------------------------------------------
password_buffer     = &0180
stage_buffer        = &0200

; Bomb vars (up to 10 bombs)
BOMB_ACTIVE         = &03A0 ; Boolean
BOMB_X              = &03AA ; Grid X position
BOMB_Y              = &03B4 ; Grid Y position
BOMB_TIME_LEFT      = &03BE ; No. frames until explosion (starts at 160 ~ 2.66s @ 60Hz)
BOMB_UNUSED         = &03C8 ; Set to 0, but never read
BOMB_TIME_ELAPSED   = &03D2 ; No. frames since placement, used for animation (every 16 frames)

; Fire vars (up to 80 flames)
FIRE_ACTIVE         = &03E6 ; 0 = inactive, >0 = no. frames flame has been active
FIRE_X              = &0436 ; Grid X position
FIRE_Y              = &0486 ; Grid Y position
byte_4D6            = &04D6
byte_526            = &0526

; Enemy vars (up to 10 enemies)
ENEMY_TYPE          = &0576 ; Type of enemy (8 types)
ENEMY_X             = &0580 ; Grid X position
ENEMY_U             = &058A ; Offset X
ENEMY_Y             = &0594 ; Grid Y position
ENEMY_V             = &059E ; Offset Y
ENEMY_FRAME         = &05A8 ; Current animation frame
ENEMY_AI_TIMER      = &05B2 ; No. frames until next AI call (half second apart)
byte_5BC            = &05BC
byte_5C6            = &05C6
ENEMY_FACE          = &05D0
byte_5DA            = &05DA
byte_5E4            = &05E4

; ?? 18 bytes unaccounted for

TILE_TAB            = &0600

SPR_TAB             = &0700
