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
extern string Timeframe      = "H1 | D1* | ...";      // timeframe to analyze
extern int    Max.InsideBars = 3;                     // max. amount of inside bars to find (-1: all)

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

int    srcTimeframe;                                  // timeframe used for computation
double srcRates[][6];                                 // rates used for computation
int    targetTimeframe;                               // target timeframe
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
   targetTimeframe = StrToPeriod(sValue, F_ERR_INVALID_PARAMETER);
   if (targetTimeframe == -1)                         return(catch("onInit(1)  Invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe), ERR_INVALID_INPUT_PARAMETER));
   if (targetTimeframe < PERIOD_M15)                  return(catch("onInit(2)  Invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe) +" (min. M15)", ERR_INVALID_INPUT_PARAMETER));
   if (targetTimeframe > PERIOD_W1)                   return(catch("onInit(3)  Invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe) +" (max. W1)", ERR_INVALID_INPUT_PARAMETER));
   int validTimeframes[] = { PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4, PERIOD_H6, PERIOD_H8, PERIOD_D1, PERIOD_W1 };
   if (!IntInArray(validTimeframes, targetTimeframe)) return(catch("onInit(4)  Unsupported input parameter Timeframe: "+ DoubleQuoteStr(Timeframe), ERR_INVALID_INPUT_PARAMETER));
   Timeframe    = PeriodDescription(targetTimeframe);
   srcTimeframe = ifInt(targetTimeframe <= PERIOD_H1, targetTimeframe, PERIOD_H1);

   // Max.InsideBars
   if (Max.InsideBars < -1) return(catch("onInit(5)  Invalid input parameter Max.InsideBars: "+ Max.InsideBars, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(Max.InsideBars==-1, INT_MAX, Max.InsideBars);

   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!CopyRates(srcTimeframe, srcRates))
      return(last_error);
   int bars = ArrayRange(srcRates, 0);


   static bool done = false;
   if (!done) {
      done = true;
      debug("onTick(1)  ArrayCopyRates("+ srcTimeframe +") => "+ bars +" bars");

      int findMore = maxInsideBars;

      switch (targetTimeframe) {
         case PERIOD_M15: break;
      }


      // find the specified number of inside bars
      for (int i=2; findMore && i < bars; i++) {
         if (srcRates[i][HIGH] >= srcRates[i-1][HIGH] && srcRates[i][LOW] <= srcRates[i-1][LOW]) {
            if (!MarkInsideBar(srcRates[i-1][TIME], srcRates[i-1][HIGH], srcRates[i-1][LOW]))
               return(last_error);
            findMore--;
         }
      }
   }
   return(last_error);
}


/**
 * Mark the specified inside bar in the chart.
 *
 * @param  datetime time - inside bar open time
 * @param  double   high - inside bar high
 * @param  double   low  - inside bar low
 *
 * @return bool - success status
 */
bool MarkInsideBar(datetime time, double high, double low) {
   datetime openTime  = time;                                  // inside bar open time
   datetime closeTime = openTime + targetTimeframe*MINUTES;    // inside bar close time

   double longTarget1  = high + (high-low);                    // first target level long
   double shortTarget1 = low  - (high-low);                    // first target level short


   // draw vertical line at inside bar open
   // draw horizontal line at target level long
   // draw horizontal line at target level short

   //string format = ifString(targetTimeframe < PERIOD_D1, "%a, %d.%m.%Y %H:%M", "%a, %d.%m.%Y");
   string format = "%a, %d.%m.%Y %H:%M";
   debug("MarkInsideBar(1)  "+ Timeframe +" inside bar at "+ GmtTimeFormat(time, format));
   return(true);
}


/**
 * Copy rates of the specified timeframe to the passed array.
 *
 * @param  int    timeframe - rates timeframe
 * @param  double rates[][] - destination array
 *
 * @return bool - success status; FALSE on ERS_HISTORY_UPDATE
 */
bool CopyRates(int timeframe, double rates[][]) {
   int bars = ArrayCopyRates(rates, NULL, timeframe);

   int error = GetLastError();
   if (error || bars <= 0) error = ifInt(error, error, ERR_RUNTIME_ERROR);
   switch (error) {
      case NO_ERROR:           break;
      case ERS_HISTORY_UPDATE: return(!debug("CopyRates(1)  ArrayCopyRates("+ PeriodDescription(timeframe) +") => "+ bars +" bars", error));
      default:                 return(!catch("CopyRates(2)  ArrayCopyRates("+ PeriodDescription(timeframe) +") => "+ bars +" bars", error));
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
