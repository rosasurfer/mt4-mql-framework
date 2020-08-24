/**
 * Duel
 *
 * Eye to eye stand winners and losers
 * Hurt by envy, cut by greed
 * Face to face with their own disillusions
 * The scars of old romances still on their cheeks
 *
 *
 * A bi-directional trading system with optional pyramiding, martingale or reverse-martingale position sizing.
 *
 * - If "Pyramid.Multiplier" and "Martingale.Multiplier" both are "0" the EA trades like a regular single-position system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a Martingale system.
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string GridDirection         = "Long | Short | Both";
extern int    GridSize              = 20;
extern string UnitSize              = "0.01* | [L]{double} | auto";  // "{double}"=fix, "L{double}"=compounding or "auto"=externally configured unitsize

extern double Pyramid.Multiplier    = 0;                             // unitsize multiplier on the winning side
extern double Martingale.Multiplier = 0;                             // unitsize multiplier on the losing side

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


#define STRATEGY_ID           105      // unique strategy id


// sequence status values
#define STATUS_UNDEFINED      0
#define STATUS_WAITING        1
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3


// sequence data
int    sequence.id;
string sequence.name = "";
int    sequence.status;
int    sequence.directions;
bool   sequence.isLongDirection;
bool   sequence.isShortDirection;


// order/position management
int long.pendings.ticket [];
int long.positions.ticket[];

int short.pendings.ticket [];
int short.positions.ticket[];


#include <apps/duel/init.mqh>
#include <apps/duel/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {

   if (sequence.status == STATUS_WAITING) {                    // start new sequence
      StartSequence();
   }
   else if (sequence.status == STATUS_PROGRESSING) {           // manage running sequence
      // check pending orders
      // check PL
      // open more pending orders || close all positions
   }
   else if (sequence.status == STATUS_STOPPED) {
   }

   return(last_error);
}


/**
 * Start a new sequence. When called all previous sequence data was reset.
 *
 * @return bool - success status
 */
bool StartSequence() {
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (__LOG()) log("StartSequence(2)  starting new sequence "+ sequence.name +"...");



   // define gridbase
   //gridbase = GetGridbase();
   //startPrice = NormalizeDouble(gridbase, Digits);



   // calculate start equity and unitsize
   //sequence.startEquity   = CalculateStartEquity();
   //sequence.startUnitsize = CalculateUnitSize(sequence.startEquity);

   sequence.status = STATUS_PROGRESSING;


   if (sequence.isLongDirection) {
      // open buy market
      // open buy stop
      // open buy limit
      UpdatePendingOrders();
   }

   if (sequence.isShortDirection) {
      // open sell market
      // open sell stop
      // open sell limit
      UpdatePendingOrders();
   }

   if (__LOG()) log("StartSequence(3)  "+ sequence.name +" sequence started (start price "+ NumberToStr(startPrice, PriceFormat) +", gridbase "+ NumberToStr(gridbase, PriceFormat) +")");
   return(!catch("StartSequence(4)"));
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
                            "UnitSize=",              DoubleQuoteStr(UnitSize),                  ";", NL,
                            "Pyramid.Multiplier=",    NumberToStr(Pyramid.Multiplier, ".1+"),    ";", NL,
                            "Martingale.Multiplier=", NumberToStr(Martingale.Multiplier, ".1+"), ";")
   );
}
