/**
 * Brackets
 *
 * Marks configurable breakout ranges as they develop and displays range details.
 *
 * TODDO:
 *  - visualization
 *     line length: 60 minutes up to 2 minutes before High/Low
 *     line width:  3
 *     color:       Magenta
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string TimeWindow       = "09:00-10:00";          // server timezone                                                   // TODO: replace by FXT everywhere
extern int    NumberOfBrackets = 1;                      // -1: process all available data

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iCopyRates.mqh>
#include <functions/ParseDateTime.mqh>

#property indicator_chart_window

int    bracketStart;                                     // minutes after Midnight
int    bracketEnd;                                       // ...
int    maxBrackets;

double rates[][6];                                       // rates used for bracket calculation
int    ratesTimeframe;
int    ratesChangedBars;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = ProgramName();

   // validate inputs
   // TimeWindow: 09:00-10:00
   string sValue = TimeWindow;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "TimeWindow", sValue);
   if (!ParseTimeWindow(sValue, bracketStart, bracketEnd, ratesTimeframe)) return(catch("onInit(1)  invalid input parameter TimeWindow: \""+ sValue +"\"", ERR_INVALID_INPUT_PARAMETER));
   ratesTimeframe = Min(ratesTimeframe, PERIOD_M5);      // don't use calculation periods > M5 as some brokers/symbols may provide incorrectly aligned timeframe periods
   if (ratesTimeframe == PERIOD_M1)                                        return(catch("onInit(2)  unsupported TimeWindow: \""+ sValue +"\" (M1 resolution not implemented)", ERR_NOT_IMPLEMENTED));

   // NumberOfBrackets
   int iValue = NumberOfBrackets;
   if (AutoConfiguration) iValue = GetConfigInt(indicator, "NumberOfBrackets", iValue);
   if (iValue < -1)                                                        return(catch("onInit(3)  invalid input parameter NumberOfBrackets: "+ iValue, ERR_INVALID_INPUT_PARAMETER));
   maxBrackets = ifInt(iValue==-1, INT_MAX, iValue);

   SetIndexLabel(0, NULL);                               // disable "Data" window display
   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   ratesChangedBars = iCopyRates(rates, NULL, ratesTimeframe);
   if (ratesChangedBars < 0) return(last_error);

   UpdateBrackets();
   return(last_error);
}


/**
 * Update bracket visualizations.
 *
 * @return bool - success status
 *
 * TODO: all calculations must use FXT times
 */
bool UpdateBrackets() {
   // update bracket calculations
   for (int i=0; i < ratesChangedBars; i++) {
   }

   // update bracket visualization (usually the chart timeframe will be different than the calculation timeframe)
   for (i=0; i < ChangedBars; i++) {
   }





   datetime midnight=Tick.time-Tick.time % DAYS, rangeStart, rangeEnd;

   // recalculate/redraw brackets from young to old
   for (i=0; i < maxBrackets; i++) {
      rangeStart = midnight + bracketStart*MINUTES;
      rangeEnd   = midnight + bracketEnd*MINUTES;
      midnight  -= 1*DAY;

      if (ratesChangedBars > 2) debug("UpdateBrackets(0.2)  ratesChangedBars="+ ratesChangedBars +"  rangeStart="+ TimeToStr(rangeStart, TIME_FULL) +"  rangeEnd="+ TimeToStr(rangeEnd, TIME_FULL));
   }

   //debug("UpdateBrackets(0.1)  ratesChangedBars="+ ratesChangedBars +"  chartChangedBars="+ ChangedBars);
   //static bool done = false;
   //if (!done) debug("UpdateBrackets(0.2)  rangeStart="+ TimeToStr(rangeStart, TIME_FULL) +"  rangeEnd="+ TimeToStr(rangeEnd, TIME_FULL));
   //done = true;

   return(true);
}


/**
 * Parse the given bracket timeframe description and return the resulting bracket parameters.
 *
 * @param  _In_  string timeframe - bracket timeframe description
 * @param  _Out_ int    from      - bracket start time in minutes since Midnight servertime
 * @param  _Out_ int    to        - bracket end time in minutes since Midnight servertime
 * @param  _Out_ int    period    - price period to use for bracket calculations
 *
 * @return bool - success status
 */
bool ParseTimeWindow(string timeframe, int &from, int &to, int &period) {
   if (!StrContains(timeframe, "-")) return(false);
   int result[];

   string sFrom = StrTrim(StrLeftTo(timeframe, "-"));
   if (!ParseDateTime(sFrom, DATE_OPTIONAL, result)) return(false);
   if (result[PT_HAS_DATE] || result[PT_SECOND])     return(false);
   int _from = result[PT_HOUR]*60 + result[PT_MINUTE];

   string sTo = StrTrim(StrRightFrom(timeframe, "-"));
   if (!ParseDateTime(sTo, DATE_OPTIONAL, result)) return(false);
   if (result[PT_HAS_DATE] || result[PT_SECOND])   return(false);
   int _to = result[PT_HOUR]*60 + result[PT_MINUTE];

   if (_from >= _to) return(false);
   from = _from;
   to = _to;

   if      (!(from % PERIOD_H1  + to % PERIOD_H1))  period = PERIOD_H1;
   else if (!(from % PERIOD_M30 + to % PERIOD_M30)) period = PERIOD_M30;
   else if (!(from % PERIOD_M15 + to % PERIOD_M15)) period = PERIOD_M15;
   else if (!(from % PERIOD_M5  + to % PERIOD_M5))  period = PERIOD_M5;
   else                                             period = PERIOD_M1;

   return(true);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("TimeWindow=",       DoubleQuoteStr(TimeWindow), ";", NL,
                            "NumberOfBrackets=", NumberOfBrackets,           ";")
   );
}
