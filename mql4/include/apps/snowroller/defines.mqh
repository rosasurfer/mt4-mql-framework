/**
 * Common definitions for SnowRoller and the Snowroller scripts.
 *
 * @see  mql4/experts/SnowRoller.mq4
 */

// grid direction types
#define D_LONG   TRADE_DIRECTION_LONG           // 1
#define D_SHORT TRADE_DIRECTION_SHORT           // 2


// sequence status values
#define STATUS_UNDEFINED            0
#define STATUS_WAITING              1
#define STATUS_STARTING             2
#define STATUS_PROGRESSING          3
#define STATUS_STOPPING             4
#define STATUS_STOPPED              5


// start/stop signal types
#define SIGNAL_PRICETIME            1           // a price, time or combined price-time condition
#define SIGNAL_TREND                2
#define SIGNAL_TAKEPROFIT           3
#define SIGNAL_STOPLOSS             4
#define SIGNAL_SESSION_BREAK        5


// SaveStatus() control modes
#define SAVESTATUS_AUTO             0           // status is saved if order data changed
#define SAVESTATUS_ENFORCE          1           // status is always saved
#define SAVESTATUS_SKIP             2           // status is never saved


// event types for SynchronizeStatus()
#define EV_SEQUENCE_START           1
#define EV_SEQUENCE_STOP            2
#define EV_GRIDBASE_CHANGE          3
#define EV_POSITION_OPEN            4
#define EV_POSITION_STOPOUT         5
#define EV_POSITION_CLOSE           6


// start/stop display modes
#define SDM_NONE                    0           // no display
#define SDM_PRICE    SYMBOL_LEFTPRICE
int     startStopDisplayModes[] = {SDM_NONE, SDM_PRICE};


// order display flags (may be combined)
#define ODF_PENDING                 1
#define ODF_OPEN                    2
#define ODF_STOPPEDOUT              4
#define ODF_CLOSED                  8


// order display modes (can't be combined)
#define ODM_NONE                    0           // no display
#define ODM_STOPS                   1           // pendings,       closedBySL
#define ODM_PYRAMID                 2           // pendings, open,             closed
#define ODM_ALL                     3           // pendings, open, closedBySL, closed
int     orderDisplayModes[] = {ODM_NONE, ODM_STOPS, ODM_PYRAMID, ODM_ALL};


// order marker colors
#define CLR_PENDING     DeepSkyBlue
#define CLR_LONG        Blue
#define CLR_SHORT       Red
#define CLR_CLOSE       Orange
