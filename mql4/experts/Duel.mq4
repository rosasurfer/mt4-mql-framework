/**
 * Duel
 *
 * Eye to eye stand winners and losers
 * Hurt by envy, cut by greed
 * Face to face with their own disillusions
 * The scars of old romances still on their cheeks
 *
 *
 * A uni-directional or bi-directional grid with optional pyramiding, martingale or reverse-martingale position sizing.
 *
 * - If both multipliers are "0" the EA trades like a regular single-position system (no grid).
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a Martingale system.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string GridDirection         = "Long | Short | Both*";
extern int    GridSize              = 20;
extern double UnitSize              = 0.01;     // lots at the first grid level

extern double Pyramid.Multiplier    = 1;        // unitsize multiplier on the winning side
extern double Martingale.Multiplier = 1;        // unitsize multiplier on the losing side

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


#define STRATEGY_ID                 105         // unique strategy id
#define SEQUENCE_ID_MIN            1000         // min. sequence id value (at least 4 digits)
#define SEQUENCE_ID_MAX           16383         // max. sequence id value (at most 14 bits: 32767 >> 1)

#define D_LONG    TRADE_DIRECTION_LONG          // 1
#define D_SHORT   TRADE_DIRECTION_SHORT         // 2
#define D_BOTH    TRADE_DIRECTION_BOTH          // 3


// sequence status values
#define STATUS_UNDEFINED              0
#define STATUS_WAITING                1
#define STATUS_PROGRESSING            2
#define STATUS_STOPPED                3

// sequence data
int      sequence.id;
datetime sequence.created;
string   sequence.name = "";                    // "[LSB].{sequence.id}"
bool     sequence.isTest;                       // whether the sequence is a test (a finished test can be loaded into an online chart)
int      sequence.status;
int      sequence.directions;
double   sequence.unitsize;                     // lots at the first grid level
int      sequence.level;                        // current grid level: -n...0...+n
double   sequence.gridbase;
double   sequence.startEquity;

// order management
bool     long.enabled;
int      long.tickets[];

bool     short.enabled;
int      short.tickets[];


#include <apps/duel/init.mqh>
#include <apps/duel/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (sequence.status == STATUS_WAITING) {              // start a new sequence
      StartSequence();
   }
   else if (sequence.status == STATUS_PROGRESSING) {     // manage a running sequence
      if (UpdateStatus()) {                              // check pending orders and PL
         if (IsStopSignal()) StopSequence();             // close all positions
         else                UpdateOrders();             // add/modify pending orders
      }
   }
   else if (sequence.status == STATUS_STOPPED) {
   }
   return(last_error);
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @return bool
 */
bool IsStopSignal() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   return(false);
}


/**
 * Start a new sequence. When called all previous sequence data was reset.
 *
 * @return bool - success status
 */
bool StartSequence() {
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (__LOG()) log("StartSequence(2)  "+ sequence.name +"  starting sequence...");

   if      (sequence.directions == D_LONG)  sequence.gridbase = Ask;
   else if (sequence.directions == D_SHORT) sequence.gridbase = Bid;
   else                                     sequence.gridbase = NormalizeDouble((Bid+Ask)/2, Digits);

   sequence.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   sequence.status      = STATUS_PROGRESSING;

   UpdateOrders();

   if (__LOG()) log("StartSequence(3)  "+ sequence.name +" sequence started (gridbase "+ NumberToStr(sequence.gridbase, PriceFormat) +")");
   return(!catch("StartSequence(4)"));
}


/**
 * Close all open positions, delete pending orders and stop the sequence.
 *
 * @return bool - success status
 */
bool StopSequence() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Update internal order and PL status with current market data.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Update all existing orders and add new or missing ones.
 *
 * @param  int direction [optional] - order direction flags (default: all currently active trade directions)
 *
 * @return bool - success status
 */
bool UpdateOrders(int direction = D_BOTH) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateOrders(1)  "+ sequence.name +" cannot update orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (direction & D_BOTH && 1) {
      if (!UpdateOrders(D_LONG))  return(false);
      if (!UpdateOrders(D_SHORT)) return(false);
      return(true);
   }

   if (direction == D_LONG) {
      if (long.enabled) {
      }
      return(true);
   }

   if (direction == D_SHORT) {
      if (short.enabled) {
      }
      return(true);
   }

   return(!catch("UpdateOrders(2)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Generate a new sequence id. As strategy ids differ multiple strategies may use the same sequence id at the same time.
 *
 * @return int - sequence id between SID_MAX and SID_MAX (1000-16383)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;
   while (id < SEQUENCE_ID_MIN || id > SEQUENCE_ID_MAX) {
      id = MathRand();                                   // TODO: in tester generate consecutive ids
   }                                                     // TODO: test id for uniqueness
   return(id);
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__CHART()) return(error);
   string msg="", sError="";

   switch (sequence.status) {
      case STATUS_UNDEFINED:   msg = "   not initialized"; break;
      case STATUS_WAITING:     msg = "   waiting";         break;
      case STATUS_PROGRESSING: msg = "   progressing";     break;
      case STATUS_STOPPED:     msg = "   stopped";         break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }

   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

   // 4 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, NL, __NAME(), msg, sError);
   if (__CoreFunction == CF_INIT)
      WindowRedraw();

   if (!catch("ShowStatus(2)"))
      return(error);
   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("GridDirection=",         DoubleQuoteStr(GridDirection),             ";", NL,
                            "GridSize=",              GridSize,                                  ";", NL,
                            "UnitSize=",              NumberToStr(UnitSize, ".1+"),              ";", NL,
                            "Pyramid.Multiplier=",    NumberToStr(Pyramid.Multiplier, ".1+"),    ";", NL,
                            "Martingale.Multiplier=", NumberToStr(Martingale.Multiplier, ".1+"), ";")
   );
}
