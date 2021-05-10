; Hardware
HW_FPS = 60

; Tiles
TILE_OFFS = &2000
TILE_WIDTH = 32
TILE_HEIGHT = 30

; Palettes
BASE_PAL = &3F00
BG_PAL_0 = &3F01
BG_PAL_1 = &3F05
BG_PAL_2 = &3F09
BG_PAL_3 = &3F0D
SPR_PAL_0 = &3F11
SPR_PAL_1 = &3F15
SPR_PAL_2 = &3F19
SPR_PAL_3 = &3F1D

; Booleans for flags
NO = 0
YES = 1
DISABLE = 0
ENABLE = 1

; Bonus states
BONUS_NOT_MET = 0
BONUS_ACHIEVED = 1
BONUS_COLLECTED = 2

; Input
PAD_RIGHT  = &01
PAD_LEFT   = &02
PAD_DOWN   = &04
PAD_UP     = &08
PAD_START  = &10
PAD_SELECT = &20
PAD_B      = &40
PAD_A      = &80

; Sprites
SPR_SIZE = 16
SPR_HALFSIZE = SPR_SIZE/2

OAM_CACHE = &0200
OAM_FLIP_NONE = &00
OAM_FLIP_X = &40
OAM_FLIP_Y = &80

; Stage
SECONDSPERLEVEL = 200
SECONDSPERBONUSLEVEL = 30
LIVESATSTART = 3
SCORE_DIGITS = 7

; Maps
MAP_FIRST_LEVEL = 1
MAP_LEVELS = 50

MAP_WIDTH = 32
MAP_HEIGHT = 13

MAP_HERE   = 0
MAP_RIGHT  = 1
MAP_UP     = 2
MAP_LEFT   = 3
MAP_DOWN   = 4

MAP_EMPTY        = 0
MAP_CONCRETE     = 1
MAP_BRICK        = 2
MAP_BOMB         = 3
MAP_HIDDEN_EXIT  = 4
MAP_HIDDEN_BONUS = 5
MAP_BONUS        = 6
MAP_EXIT         = 8

; Bomb related
MAX_BOMB = 10
MAX_BOMB_RANGE = 5
DEMO_BOMB_RANGE = 4
MAX_FIRE = (MAX_BOMB*8)

; Enemy related
MAX_ENEMY = 10

; Gaze directions
GAZE_RIGHT = 1
GAZE_UP = 2
GAZE_LEFT = 3
GAZE_DOWN = 4

; Password related
MAX_PW_CHARS = 20

; Misc
END_OF_STRING = &FF

; Tiles
SOLIDWHITE = &3B
COPYRIGHT = &FE
FULLSTOP = &FD

; Sounc and music related
NUM_TUNES = 10