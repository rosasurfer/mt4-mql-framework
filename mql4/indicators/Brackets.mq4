/**
 * Bracket indicator
 *
 * Marks configurable breakout ranges and displays range details.
 *
 * TODDO: input TimeWindow must support timezone ids (09:00-09:30 NY, 09:15-09:30 FF)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string TimeWindow       = "09:00-10:00";          // server timezone
extern int    NumberOfBrackets = 1;                      // -1: process all available data
extern color  BracketsColor    = Magenta;                //

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iCopyRates.mqh>
#include <functions/ParseDateTime.mqh>

#property indicator_chart_window

int    bracketStart;                                     // minutes after Midnight
int    bracketEnd;                                       // ...
int    maxBrackets;

double rates[][6];                                       // rates used for bracket calculation
int    ratesTimeframe;
int    changedRateBars;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator=ProgramName(), section=indicator, stdSymbol=StdSymbol();

   // validate inputs
   // TimeWindow: 09:00-10:00
   string sValue = TimeWindow;
   if (AutoConfiguration) {
      if      (IsConfigKey(section, Symbol() +".TimeWindow"))  sValue = GetConfigString(section, Symbol() +".TimeWindow", sValue);
      else if (IsConfigKey(section, stdSymbol +".TimeWindow")) sValue = GetConfigString(section, stdSymbol +".TimeWindow", sValue);
      else                                                     sValue = GetConfigString(section, "TimeWindow", sValue);
   }
   if (!ParseTimeWindow(sValue, bracketStart, bracketEnd, ratesTimeframe)) return(catch("onInit(1)  invalid input parameter TimeWindow: \""+ sValue +"\"", ERR_INVALID_INPUT_PARAMETER));
   TimeWindow = sValue;
   ratesTimeframe = Min(ratesTimeframe, PERIOD_M5);                        // don't use calculation periods > M5 as some brokers/symbols may provide incorrectly aligned timeframe periods
   if (ratesTimeframe == PERIOD_M1)                                        return(catch("onInit(2)  unsupported TimeWindow: \""+ sValue +"\" (M1 resolution not implemented)", ERR_NOT_IMPLEMENTED));

   // NumberOfBrackets
   int iValue = NumberOfBrackets;
   if (AutoConfiguration) {
      if      (IsConfigKey(section, Symbol() +".NumberOfBrackets"))  iValue = GetConfigInt(section, Symbol() +".NumberOfBrackets", iValue);
      else if (IsConfigKey(section, stdSymbol +".NumberOfBrackets")) iValue = GetConfigInt(section, stdSymbol +".NumberOfBrackets", iValue);
      else                                                           iValue = GetConfigInt(section, "NumberOfBrackets", iValue);
   }
   if (iValue < -1)                                                        return(catch("onInit(3)  invalid input parameter NumberOfBrackets: "+ iValue, ERR_INVALID_INPUT_PARAMETER));
   NumberOfBrackets = iValue;
   maxBrackets = ifInt(iValue==-1, INT_MAX, iValue);

   // BracketsColor
   if (BracketsColor == 0xFF000000) BracketsColor = CLR_NONE;              // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) {
      BracketsColor = GetConfigColor(indicator, "BracketsColor", BracketsColor);
   }

   SetIndexLabel(0, NULL);                                                 // disable "Data" window display
   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   changedRateBars = iCopyRates(rates, NULL, ratesTimeframe);
   if (changedRateBars < 0) return(last_error);

   UpdateBrackets();
   return(last_error);
}


/**
 * Update bracket visualizations.
 *
 * @return bool - success status
 */
bool UpdateBrackets() {
   double brackets[][4];

   #define I_STARTTIME  0
   #define I_ENDTIME    1
   #define I_HIGH       2
   #define I_LOW        3

   // re-calculate brackets
   if (changedRateBars > 2) {                                                                            // skip single ticks
      ArrayResize(brackets, maxBrackets);
      ArrayInitialize(brackets, NULL);

      int i=0, fromBar, toBar, highBar, lowBar;
      datetime opentime=rates[0][BAR.time], midnight=opentime - opentime%DAYS + 1*DAY, rangeStart, rangeEnd;
      //debug("UpdateBrackets(0.1)  Tick="+ Ticks +"  changedRateBars="+ changedRateBars +"  rates[0]="+ GmtTimeFormat(opentime, "%a, %Y.%m.%d %H:%M"));

      while (i < maxBrackets) {
         midnight  -= 1*DAY;
         rangeStart = midnight + bracketStart*MINUTES;
         rangeEnd   = midnight + bracketEnd*MINUTES;
         fromBar    = iBarShiftNext    (NULL, ratesTimeframe, rangeStart); if (fromBar == -1) continue;  // no such data (rangeStart too young)
         toBar      = iBarShiftPrevious(NULL, ratesTimeframe, rangeEnd-1); if (toBar   == -1) break;     // no such data (rangeEnd too old)
         if (fromBar < toBar) continue;                                                                  // no such data (gap in rates)

         highBar = iHighest(NULL, ratesTimeframe, MODE_HIGH, fromBar-toBar+1, toBar);
         lowBar  = iLowest (NULL, ratesTimeframe, MODE_LOW,  fromBar-toBar+1, toBar);

         brackets[i][I_STARTTIME] = rangeStart;
         brackets[i][I_ENDTIME  ] = rangeEnd;
         brackets[i][I_HIGH     ] = rates[highBar][BAR.high];
         brackets[i][I_LOW      ] = rates[lowBar ][BAR.low ];

         //debug("UpdateBrackets(0.2)  Tick="+ Ticks +"  bracket from["+ fromBar +"]="+ GmtTimeFormat(rates[fromBar][BAR.time], "%a, %Y.%m.%d %H:%M") +"  to["+ toBar +"]="+ GmtTimeFormat(rates[toBar][BAR.time], "%a, %Y.%m.%d %H:%M"));
         i++;
      }
      if (i < maxBrackets) ArrayResize(brackets, i);
   }

   // update bracket visualization
   if (changedRateBars > 2) {
      int size=ArrayRange(brackets, 0), pid=__ExecutionContext[EC.pid];
      datetime chartStart, chartEnd;
      double high, low;
      string label = "";

      for (i=0; i < size; i++) {
         rangeStart = brackets[i][I_STARTTIME];
         rangeEnd   = brackets[i][I_ENDTIME];
         high       = brackets[i][I_HIGH];
         low        = brackets[i][I_LOW];
         chartStart = rangeStart;
         chartEnd   = Min(rangeEnd-1, Tick.time);

         // high
         label = "Bracket high "+ TimeWindow +" "+ NumberToStr(high, PriceFormat) +" ["+ i +"]["+ pid +"]";
         if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_TREND, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet(label, OBJPROP_TIME1,  chartStart);
         ObjectSet(label, OBJPROP_PRICE1, high);
         ObjectSet(label, OBJPROP_TIME2,  chartEnd);
         ObjectSet(label, OBJPROP_PRICE2, high);
         ObjectSet(label, OBJPROP_STYLE,  STYLE_SOLID);
         ObjectSet(label, OBJPROP_WIDTH,  3);
         ObjectSet(label, OBJPROP_COLOR,  BracketsColor);
         ObjectSet(label, OBJPROP_RAY,    false);
         ObjectSet(label, OBJPROP_BACK,   false);

         // low
         label = "Bracket low "+ TimeWindow +" "+ NumberToStr(low, PriceFormat) +" ["+ i +"]["+ pid +"]";
         if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_TREND, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet(label, OBJPROP_TIME1,  chartStart);
         ObjectSet(label, OBJPROP_PRICE1, low);
         ObjectSet(label, OBJPROP_TIME2,  chartEnd);
         ObjectSet(label, OBJPROP_PRICE2, low);
         ObjectSet(label, OBJPROP_STYLE,  STYLE_SOLID);
         ObjectSet(label, OBJPROP_WIDTH,  3);
         ObjectSet(label, OBJPROP_COLOR,  BracketsColor);
         ObjectSet(label, OBJPROP_RAY,    false);
         ObjectSet(label, OBJPROP_BACK,   false);
      }
   }
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
                            "NumberOfBrackets=", NumberOfBrackets,           ";", NL,
                            "BracketsColor=",    ColorToStr(BracketsColor),  ";")
   );
}
