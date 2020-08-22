/**
 * Duel
 *
 * Eye to eye stand winners and losers.
 * Hurt by envy, cut by greed.
 * Face to face with their own disillusions.
 * The scars of old romances still on their cheeks.
 *
 * This EA is a bi-directional strategy with optional pyramiding, martingale or reverse-martingale position sizing algorithm.
 *
 * - If "Pyramid.Multiplier" and "Martingale.Multiplier" both are "0" the EA trades like a regular single-entry system.
 * - If "Martingale.Multiplier" is greater than "1" the EA trades on the loosing side like a regular Martingale system.
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double LotSize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

// sequence status values
#define STATUS_UNDEFINED      0
#define STATUS_WAITING        1
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3

// sequence data
int sequence.status;

// order/position management
int long.pendings.ticket [];
int long.positions.ticket[];

int short.pendings.ticket [];
int short.positions.ticket[];


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {

   // start new sequence
   if (sequence.status == STATUS_WAITING) {
      // open pending orders
   }

   // manage positions
   else if (sequence.status == STATUS_PROGRESSING) {
      // check pending orders
      // check total PL
      // close all positions | open more pending orders
   }

   // reset sequence
   else if (sequence.status == STATUS_STOPPED) {
   }

   return(last_error);
}


/**
 * Start a new sequence.
 *
 * @return bool - success status
 */
bool StartSequence() {
   //if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   // open buy market
   // open buy stop
   // open buy limit

   // open sell market
   // open sell stop
   // open sell limit

   sequence.status = STATUS_PROGRESSING;
   return(!catch("StartSequence(2)"));
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
         return(catch("ShowStatus(1)  illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
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
   return(StringConcatenate("LotSize=", NumberToStr(LotSize, ".1+"), ";"));
}
