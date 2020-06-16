/**
 * Inside Bars (work in progress)
 *
 *
 * Marks inside bars and SR levels of the specified timeframes in the chart. Additionally to the standard MT4 timeframes the
 * indicator supports the timeframes H2, H3, H6 and H8.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration  = "manual | auto*";
extern string Timeframe      = "H1";                  // timeframes to analyze
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
   targetTimeframe = StrToPeriod(sValue, F_CUSTOM_TIMEFRAME|F_ERR_INVALID_PARAMETER);
   if (targetTimeframe == -1)        return(catch("onInit(1)  Invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe), ERR_INVALID_INPUT_PARAMETER));
   if (targetTimeframe > PERIOD_MN1) return(catch("onInit(2)  Unsupported parameter Timeframe: "+ DoubleQuoteStr(Timeframe) +" (max. MN1)", ERR_INVALID_INPUT_PARAMETER));
   Timeframe    = PeriodDescription(targetTimeframe);
   srcTimeframe = ifInt(targetTimeframe < PERIOD_H1, targetTimeframe, PERIOD_H1);

   // Max.InsideBars
   if (Max.InsideBars < -1) return(catch("onInit(3)  Invalid input parameter Max.InsideBars: "+ Max.InsideBars, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(Max.InsideBars==-1, INT_MAX, Max.InsideBars);

   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!CopyRates(srcTimeframe, srcRates))
      return(last_error);
   int bars=ArrayRange(srcRates, 0), findMore=maxInsideBars;

   static bool done = false;
   if (!done) {
      done = true;
      debug("onTick(1)  CopyRates("+ srcTimeframe +") => "+ bars +" bars");

      // find the specified number of inside bars
      switch (targetTimeframe) {
         case PERIOD_M1:
         case PERIOD_M5:
         case PERIOD_M15:
         case PERIOD_M30:
         case PERIOD_H1:
            for (int i=2; findMore && i < bars; i++) {
               if (srcRates[i][HIGH] >= srcRates[i-1][HIGH] && srcRates[i][LOW] <= srcRates[i-1][LOW]) {
                  if (!MarkInsideBar(srcRates[i-1][TIME], srcRates[i-1][HIGH], srcRates[i-1][LOW]))
                     return(last_error);
                  findMore--;
               }
            }
            break;

         case PERIOD_H2:
         case PERIOD_H3:
         case PERIOD_H4:
         case PERIOD_H6:
         case PERIOD_H8:
         case PERIOD_D1:
         case PERIOD_W1:
         case PERIOD_MN1:
         default:
            catch("onTick(2)  inside bar timeframe "+ Timeframe +" not yet supported", ERR_NOT_IMPLEMENTED);
            break;
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
   datetime openTime  = time;                                        // IB open time
   datetime closeTime = openTime + targetTimeframe*MINUTES;          // IB close time
   double barSize     = (high-low);
   double longTarget  = NormalizeDouble(high + barSize, Digits);     // first long target
   double shortTarget = NormalizeDouble(low  - barSize, Digits);     // first short target
   string sOpenTime   = GmtTimeFormat(openTime, "%d.%m.%Y %H:%M");

   // draw vertical line at IB open
   string label = Timeframe +" inside bar: "+ NumberToStr(high, PriceFormat) +"-"+ NumberToStr(low, PriceFormat) +" (size "+ DoubleToStr(barSize/Pip, Digits & 1) +")";
   if (ObjectCreate (label, OBJ_TREND, 0, openTime, longTarget, openTime, shortTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectRegister(label);
   } else debug("MarkInsideBar(1)", GetLastError());

   // draw horizontal line at long target
   label = Timeframe +" inside bar: +100 = "+ NumberToStr(longTarget, PriceFormat);
   if (ObjectCreate (label, OBJ_TREND, 0, openTime, longTarget, closeTime, longTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectRegister(label);
   } else debug("MarkInsideBar(2)", GetLastError());

   // draw horizontal line at short target
   label = Timeframe +" inside bar: -100 = "+ NumberToStr(shortTarget, PriceFormat);
   if (ObjectCreate (label, OBJ_TREND, 0, openTime, shortTarget, closeTime, shortTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectRegister(label);
   } else debug("MarkInsideBar(3)", GetLastError());


   string format = "%a, %d.%m.%Y %H:%M";  // ifString(targetTimeframe < PERIOD_D1, "%a, %d.%m.%Y %H:%M", "%a, %d.%m.%Y");
   debug("MarkInsideBar(4)  "+ Timeframe +" IB at "+ GmtTimeFormat(time, format) +"  L="+ NumberToStr(longTarget, PriceFormat) +"  S="+ NumberToStr(shortTarget, PriceFormat));

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
      case ERS_HISTORY_UPDATE: return(!debug("CopyRates(1)->ArrayCopyRates("+ PeriodDescription(timeframe) +") => "+ bars +" bars copied", error));
      default:                 return(!catch("CopyRates(2)->ArrayCopyRates("+ PeriodDescription(timeframe) +") => "+ bars +" bars copied", error));
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
