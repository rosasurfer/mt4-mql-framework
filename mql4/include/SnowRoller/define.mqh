
#define STRATEGY_ID               103                                // eindeutige ID der Strategie (Bereich 101-1023)
#define SID_MIN                  1000                                // Mindestwert für Sequenz-IDs: mindestens 4-stellig
#define SID_MAX                 16383                                // Höchstwert für Sequenz-IDs:  maximal 14 bit (32767 >> 1)


// Griddirection-Types und Flags
#define D_LONG                OP_LONG                                // Types: {0, 1}
#define D_SHORT              OP_SHORT                                //
int     directionFlags[] = {MODE_UPTREND, MODE_DOWNTREND};           // Flags: {1, 2}
string  directionDescr[] = {"Long",       "Short"       };


// Sequenzstatus-Werte
#define STATUS_UNINITIALIZED        0
#define STATUS_WAITING              1
#define STATUS_STARTING             2
#define STATUS_PROGRESSING          3
#define STATUS_STOPPING             4
#define STATUS_STOPPED              5
string  sequenceStatusDescr[] = {"uninitialized", "waiting", "starting", "progressing", "stopping", "stopped"};


// Event-Types für SynchronizeStatus()
#define EV_SEQUENCE_START           1
#define EV_SEQUENCE_STOP            2
#define EV_GRIDBASE_CHANGE          3
#define EV_POSITION_OPEN            4
#define EV_POSITION_STOPOUT         5
#define EV_POSITION_CLOSE           6


// Array-Indizes im Multi-Sequenz-Management
#define I_FROM                      0
#define I_TO                        1
#define I_SIZE                      2

#define I_DIR                       0
#define I_FILE                      1


// Start/StopCondition-PriceTypes
#define SCP_BID                     0
#define SCP_ASK                     1
#define SCP_MEDIAN                  2                                // (Bid+Ask)/2
string  scpDescr[] = {"Bid", "Ask", "Avg"};


// Start/StopDisplay-Modes
#define SDM_NONE                    0                                // - keine Anzeige -
#define SDM_PRICE    SYMBOL_LEFTPRICE                                // Preismarker
int     startStopDisplayModes[] = {SDM_NONE, SDM_PRICE};


// OrderDisplay-Flags
#define ODF_PENDING                 1
#define ODF_OPEN                    2
#define ODF_STOPPEDOUT              4
#define ODF_CLOSED                  8

// OrderDisplay-Modes
#define ODM_NONE                    0                                // - keine Anzeige -
#define ODM_STOPS                   1                                // Pending,       ClosedBySL
#define ODM_PYRAMID                 2                                // Pending, Open,             Closed
#define ODM_ALL                     3                                // Pending, Open, ClosedBySL, Closed
int     orderDisplayModes[] = {ODM_NONE, ODM_STOPS, ODM_PYRAMID, ODM_ALL};

// OrderDisplay-Farben
#define CLR_PENDING                 DeepSkyBlue
#define CLR_LONG                    Blue
#define CLR_SHORT                   Red
#define CLR_CLOSE                   Orange
