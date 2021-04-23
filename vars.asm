; Game variables

; Zero Page ($0000-$00FF).

; 7 bytes BCD
TOPSCORE            = &01

SOFT_RESET_FLAG     = &08
CLEAR_TOPSCORE1     = &09
CLEAR_TOPSCORE2     = &0A
FRAMEDONE           = &0B
LAST_2000           = &0C
LAST_2001           = &0D
H_SCROLL            = &0E
V_SCROLL            = &0F
PAD1_TEST           = &10
PAD2_TEST           = &11
JOYPAD1             = &12
JOYPAD2             = &13
TILE_CUR            = &14
TILE_PTR            = &15
TILE_CNT            = &16

byte_17             = &17
byte_18             = &18
byte_19             = &19
byte_1A             = &1A
byte_1B             = &1B
byte_1C             = &1C
byte_1D             = &1D
byte_1E             = &1E
byte_1F             = &1F
byte_20             = &20
byte_21             = &21
byte_22             = &22
byte_23             = &23
TEMP_X              = &24
TEMP_Y              = &25
word_26             = &26

BOMBMAN_X           = &28
BOMBMAN_U           = &29
BOMBMAN_Y           = &2A
BOMBMAN_V           = &2B
BOMBMAN_FRAME       = &2C

SPR_ATTR_TEMP       = &2D
byte_2E             = &2E

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

M_TYPE              = &41
M_X                 = &42
M_U                 = &43
M_Y                 = &44
M_V                 = &45
M_FRAME             = &46
byte_47             = &47
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

SEED                = &54
STAGE               = &58
DEMOPLAY            = &59
byte_5A             = &5A
EXIT_ENEMY_TYPE     = &5B
byte_5C             = &5C
byte_5D             = &5D
byte_5E             = &5E

; Title screen cursor, either 0 or 1
CURSOR              = &5F

STAGE_STARTED       = &60

; 7 bytes BCD
SCORE               = &61

LIFELEFT            = &68
FPS                 = &69
IS_SECOND_PASSED    = &6A
byte_6B             = &6B

; Number of frames @ 60Hz to stay on title screen, counting down to demo start
DEMO_WAIT_HI        = &70
DEMO_WAIT_LO        = &71

; Are we on title screen 0 or 1
INMENU              = &72

BONUS_POWER         = &73
BONUS_BOMBS         = &74
BONUS_SPEED         = &75
BONUS_NOCLIP        = &76
BONUS_REMOTE        = &77
BONUS_BOMBWALK      = &78
BONUS_FIRESUIT      = &79

INVUL_UNK1          = &7A
LAST_INPUT          = &7B
INVUL_UNK2          = &7D
BONUS_ENEMY_TYPE    = &7E

; Password is stored here (20 bytes) .. $92
PW_BUFF             = &7F

; Time in seconds left to play
TIMELEFT            = &93

DEBUG               = &94
byte_95             = &95
MTAB_PTR            = &97 ; Pointer to enemy table
byte_99             = &99
byte_9A             = &9A
byte_9B             = &9B
ENEMIES_LEFT        = &9C
BONUS_AVAILABLE     = &9D
ENEMIES_DEFEATED    = &9E
byte_9F             = &9F
VISITS_TOP_LEFT     = &A0
VISITS_TOP_RIGHT    = &A1
VISITS_BOTTOM_LEFT  = &A2
VISITS_BOTTOM_RIGHT = &A3
BRICKS_BLOWN_UP     = &A4
CHAIN_REACTIONS     = &A5
byte_A6             = &A6
byte_A7             = &A7
byte_A8             = &A8
byte_A9             = &A9
byte_AA             = &AA
byte_AB             = &AB

DEMOKEY_DATA        = &AC ; Pointer to DEMO timeout/pad data
DEMOKEY_TIMEOUT     = &AE ; Current DEMO key timeout
DEMOKEY_PAD1        = &AF ; Current DEMO pad state

byte_B0             = &B0
NO_ENEMIES_CELEBRATED = &B1

APU_DISABLE         = &B2
APU_CHAN            = &B3
APU_TEMP            = &B4
APU_MUSIC           = &B5

; ?? for each of the 3 channels
byte_B6             = &B6

; ?? for each of the 3 channels
byte_B9             = &B9

APU_CHANDAT         = &BC

unk_BD              = &BD
unk_C0              = &C0

APU_PTR             = &C2

; Counters for each of the 3 channels through their respective melody data
APU_CNT             = &C4

; Melody data counter when in sustain for each of the 3 channels
unk_C7              = &C7

; Sustain countdown for each of the 3 channels
unk_CA              = &CA

; ?? for each of the 3 channels
byte_CD             = &CD

; ?? (FF or 00) for each of the 3 channels
byte_D0             = &D0

; Cache for second and third bytes from melody table
byte_D3             = &D3
byte_D4             = &D4

byte_D5             = &D5

; ?? for each of the 3 channels
byte_D6             = &D6

; Hard coded to 08 for each of the 2 pulse channels to disable sweep
APU_SWEEP           = &D9

SPR_TAB_TOGGLE      = &DB

; Used for BONUS_POWER calculations with resume codes
BOMB_PWR             = &DC

; Used for low byte of STAGE in resume codes
STAGE_LO             = &DD
; Used for high byte of STAGE in resume codes
STAGE_HI             = &DE

APU_SOUND           = &DF
APU_PATTERN         = &E0
TEMP_ADDR           = &E0
APU_CHAN_DIS        = &E1
APU_SOUND_MOD       = &E1
APU_SDELAY          = &E4

; Lower memory ($0100-$07FF).
password_buffer    = &0180
stage_buffer        = &0200

; Bomb vars (up to 10 bombs)
BOMB_ACTIVE         = &03A0
BOMB_X              = &03AA
BOMB_Y              = &03B4
BOMB_TIME_LEFT      = &03BE
BOMB_UNUSED         = &03C8
BOMB_TIME_ELAPSED   = &03D2

; Fire vars (up to 80 flames)
FIRE_ACTIVE         = &03E6
FIRE_X              = &0436
FIRE_Y              = &0486
byte_4D6            = &04D6
byte_526            = &0526

ENEMY_TYPE          = &0576
ENEMY_X             = &0580
ENEMY_U             = &058A
ENEMY_Y             = &0594
ENEMY_V             = &059E
ENEMY_FRAME         = &05A8
byte_5B2            = &05B2
byte_5BC            = &05BC
byte_5C6            = &05C6
ENEMY_FACE          = &05D0
byte_5DA            = &05DA
byte_5E4            = &05E4

TILE_TAB            = &0600

SPR_TAB             = &0700
