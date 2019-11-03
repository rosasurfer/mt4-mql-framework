
#define STRATEGY_ID               103              // unique strategy id (between 101-1023)
#define SID_MIN                  1000              // min. sequence id value (at least 4 digits)
#define SID_MAX                 16383              // max. sequence id value (at most 14 bits which is "32767 >> 1")


// grid direction types
#define D_LONG                OP_LONG              // 0
#define D_SHORT              OP_SHORT              // 1
string  directionDescr[] = {"Long", "Short"};


// sequence status values
#define STATUS_UNDEFINED            0
#define STATUS_WAITING              1
#define STATUS_STARTING             2
#define STATUS_PROGRESSING          3
#define STATUS_STOPPING             4
#define STATUS_STOPPED              5
string  sequenceStatusDescr[] = {"undefined", "waiting", "starting", "progressing", "stopping", "stopped"};


// stop condition types
#define STOP_PRICE                  1
#define STOP_TIME                   2
#define STOP_SESSIONBREAK           3
#define STOP_TP                     4
#define STOP_SL                     5
#define STOP_TREND                  6


// event types for SynchronizeStatus()
#define EV_SEQUENCE_START           1
#define EV_SEQUENCE_STOP            2
#define EV_GRIDBASE_CHANGE          3
#define EV_POSITION_OPEN            4
#define EV_POSITION_STOPOUT         5
#define EV_POSITION_CLOSE           6


// start/stop display modes
#define SDM_NONE                    0              // no display
#define SDM_PRICE    SYMBOL_LEFTPRICE
int     startStopDisplayModes[] = {SDM_NONE, SDM_PRICE};


// order display flags (may be combined)
#define ODF_PENDING                 1
#define ODF_OPEN                    2
#define ODF_STOPPEDOUT              4
#define ODF_CLOSED                  8


// order display modes (can't be combined)
#define ODM_NONE                    0              // no display
#define ODM_STOPS                   1              // pendings,       closedBySL
#define ODM_PYRAMID                 2              // pendings, open,             closed
#define ODM_ALL                     3              // pendings, open, closedBySL, closed
int     orderDisplayModes[] = {ODM_NONE, ODM_STOPS, ODM_PYRAMID, ODM_ALL};


// order display colors
#define CLR_PENDING                 DeepSkyBlue
#define CLR_LONG                    Blue
#define CLR_SHORT                   Red
#define CLR_CLOSE                   Orange
