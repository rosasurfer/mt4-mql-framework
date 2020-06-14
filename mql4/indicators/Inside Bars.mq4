/**
 * Inside Bars (work in progress)
 *
 *
 * Marks inside bars and SR levels of the specified timeframes in the chart.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration  = "manual | auto*";
extern string Timeframe      = "H1* | ...";           // timeframe to analyze
extern int    Max.InsideBars = 10;                    // max. amount of inside bars to find (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

#define TIME         0                                // rates array indexes
#define OPEN         1
#define LOW          2
#define HIGH         3
#define CLOSE        4
#define VOLUME       5

int    timeframe;                                     // target timeframe
double rates[][6];                                    // target rates
int    maxInsideBars;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Configuration                                   // TODO

   // Timeframe
   string sValues[], sValue = Timeframe;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   timeframe = StrToPeriod(sValue, F_ERR_INVALID_PARAMETER);
   if (timeframe == -1)     return(catch("onInit(1)  Invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe), ERR_INVALID_INPUT_PARAMETER));
   Timeframe = PeriodDescription(timeframe);

   // Max.InsideBars
   if (Max.InsideBars < -1) return(catch("onInit(2)  Invalid input parameter Max.InsideBars: "+ Max.InsideBars, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(Max.InsideBars==-1, INT_MAX, Max.InsideBars);

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!CopyRates(rates, timeframe))
      return(last_error);
   int bars = ArrayRange(rates, 0);


   static bool done = false;
   if (!done) {
      debug("onTick(1)  ArrayCopyRates("+ Timeframe +") => "+ bars +" bars");

      int findMore = maxInsideBars;

      // find the specified number of inside bars
      for (int i=2; findMore && i < bars; i++) {
         if (rates[i][HIGH] >= rates[i-1][HIGH] && rates[i][LOW] <= rates[i-1][LOW]) {
            debug("onTick(2)  "+ Timeframe +" inside bar at "+ GmtTimeFormat(rates[i-1][TIME], "%a, %d.%m.%Y %H:%M"));
            findMore--;
         }
      }
      done = true;
   }
   return(last_error);
}


/**
 * Copy rates of the specified timeframe to the passed destination array.
 *
 * @param  double rates[][] - destination array
 * @param  int    timeframe - rates timeframe
 *
 * @return bool - success status; FALSE on ERS_HISTORY_UPDATE
 */
bool CopyRates(double rates[][], int timeframe) {
   int bars = ArrayCopyRates(rates, NULL, timeframe);

   int error = GetLastError();
   if (error || bars <= 0) error = ifInt(error, error, ERR_RUNTIME_ERROR);
   switch (error) {
      case NO_ERROR:           break;
      case ERS_HISTORY_UPDATE: return(!debug("CopyRates(1)  ArrayCopyRates("+ Timeframe +") => "+ bars +" bars", error));
      default:                 return(!catch("CopyRates(2)  ArrayCopyRates("+ Timeframe +") => "+ bars +" bars", error));
   }
   return(true);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Configuration=",  DoubleQuoteStr(Configuration), ";", NL,
                            "Timeframe=",      DoubleQuoteStr(Timeframe),     ";", NL,
                            "Max.InsideBars=", Max.InsideBars,                ";")
   );
}
