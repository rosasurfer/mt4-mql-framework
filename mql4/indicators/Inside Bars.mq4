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
extern string Timeframes     = "W1*, H1, H4, D1...";         // one* or more comma-separated timeframes to analyze
extern int    Max.InsideBars = 3;                        // max. number of inside bars per timeframe to find (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iCopyRates.mqh>
#include <functions/JoinStrings.mqh>

#property indicator_chart_window

#define TIME         0                                   // rates array indexes
#define OPEN         1
#define LOW          2
#define HIGH         3
#define CLOSE        4
#define VOLUME       5

double ratesM1 [][6];                                    // rates for each required timeframe
double ratesM5 [][6];
double ratesM15[][6];
double ratesM30[][6];
double ratesH1 [][6];

int changedBarsM1;                                       // ChangedBars for each required timeframe
int changedBarsM5;
int changedBarsM15;
int changedBarsM30;
int changedBarsH1;

int fTimeframes;                                         // flags of the timeframes to analyze
int maxInsideBars;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Configuration

   // Timeframes
   string sValues[], sValue = Timeframes;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], ",", sValues, NULL);
      ArraySpliceStrings(sValues, 0, size-1);
      size = 1;
   }
   else {
      size = Explode(sValue, ",", sValues, NULL);
   }
   fTimeframes = NULL;
   for (int i=0; i < size; i++) {
      sValue = sValues[i];
      int timeframe = StrToTimeframe(sValue, F_CUSTOM_TIMEFRAME|F_ERR_INVALID_PARAMETER);
      if (timeframe == -1)        return(catch("onInit(1)  Invalid identifier "+ DoubleQuoteStr(sValue) +" in input parameter Timeframes: "+ DoubleQuoteStr(Timeframes), ERR_INVALID_INPUT_PARAMETER));
      if (timeframe > PERIOD_MN1) return(catch("onInit(2)  Unsupported timeframe "+ DoubleQuoteStr(sValue) +" in input parameter Timeframes: "+ DoubleQuoteStr(Timeframes) +" (max. MN1)", ERR_INVALID_INPUT_PARAMETER));
      fTimeframes |= TimeframeFlag(timeframe);
      sValues[i] = TimeframeDescription(timeframe);
   }
   Timeframes = JoinStrings(sValues, ",");

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
   if (!GetRates()) return(last_error);

   static bool done = false;
   if (!done) {
      if (fTimeframes & F_PERIOD_M1  && 1) CheckInsideBarsM1();
      if (fTimeframes & F_PERIOD_M5  && 1) CheckInsideBarsM5();
      if (fTimeframes & F_PERIOD_M15 && 1) CheckInsideBarsM15();
      if (fTimeframes & F_PERIOD_M30 && 1) CheckInsideBarsM30();
      if (fTimeframes & F_PERIOD_H1  && 1) CheckInsideBarsH1();
      if (fTimeframes & F_PERIOD_H2  && 1) CheckInsideBarsH2();
      if (fTimeframes & F_PERIOD_H3  && 1) CheckInsideBarsH3();
      if (fTimeframes & F_PERIOD_H4  && 1) CheckInsideBarsH4();
      if (fTimeframes & F_PERIOD_H6  && 1) CheckInsideBarsH6();
      if (fTimeframes & F_PERIOD_H8  && 1) CheckInsideBarsH8();
      if (fTimeframes & F_PERIOD_D1  && 1) CheckInsideBarsD1();
      if (fTimeframes & F_PERIOD_W1  && 1) CheckInsideBarsW1();
      if (fTimeframes & F_PERIOD_MN1 && 1) CheckInsideBarsMN1();
      done = true;
   }
   return(last_error);

   double dNull[];
   iCopyRates(dNull);
}


/**
 * Check rates for M1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM1() {
   int bars = ArrayRange(ratesM1, 0);
   int changedBars = changedBarsM1;
   int more = maxInsideBars;

   for (int i=2; more && i < bars; i++) {
      if (ratesM1[i][HIGH] >= ratesM1[i-1][HIGH] && ratesM1[i][LOW] <= ratesM1[i-1][LOW]) {
         if (!MarkInsideBar(PERIOD_M1, ratesM1[i-1][TIME], ratesM1[i-1][HIGH], ratesM1[i-1][LOW])) return(false);
         more--;
      }
   }
   return(true);
}


/**
 * Check rates for M5 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM5() {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5;
   int more = maxInsideBars;

   for (int i=2; more && i < bars; i++) {
      if (ratesM5[i][HIGH] >= ratesM5[i-1][HIGH] && ratesM5[i][LOW] <= ratesM5[i-1][LOW]) {
         if (!MarkInsideBar(PERIOD_M5, ratesM5[i-1][TIME], ratesM5[i-1][HIGH], ratesM5[i-1][LOW])) return(false);
         more--;
      }
   }
   return(true);
}


/**
 * Check rates for M15 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM15() {
   int bars = ArrayRange(ratesM15, 0);
   int changedBars = changedBarsM15;
   int more = maxInsideBars;

   for (int i=2; more && i < bars; i++) {
      if (ratesM15[i][HIGH] >= ratesM15[i-1][HIGH] && ratesM15[i][LOW] <= ratesM15[i-1][LOW]) {
         if (!MarkInsideBar(PERIOD_M15, ratesM15[i-1][TIME], ratesM15[i-1][HIGH], ratesM15[i-1][LOW])) return(false);
         more--;
      }
   }
   return(true);
}


/**
 * Check rates for M30 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM30() {
   int bars = ArrayRange(ratesM30, 0);
   int changedBars = changedBarsM30;
   int more = maxInsideBars;

   for (int i=2; more && i < bars; i++) {
      if (ratesM30[i][HIGH] >= ratesM30[i-1][HIGH] && ratesM30[i][LOW] <= ratesM30[i-1][LOW]) {
         if (!MarkInsideBar(PERIOD_M30, ratesM30[i-1][TIME], ratesM30[i-1][HIGH], ratesM30[i-1][LOW])) return(false);
         more--;
      }
   }
   return(true);
}


/**
 * Check rates for H1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH1() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;

   for (int i=2; more && i < bars; i++) {
      if (ratesH1[i][HIGH] >= ratesH1[i-1][HIGH] && ratesH1[i][LOW] <= ratesH1[i-1][LOW]) {
         if (!MarkInsideBar(PERIOD_H1, ratesH1[i-1][TIME], ratesH1[i-1][HIGH], ratesH1[i-1][LOW])) return(false);
         more--;
      }
   }
   return(true);
}


/**
 * Check rates for H2 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH2() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int h2   = -1;                                              // H2 bar index

   datetime openTimeH1, openTimeH2, pOpenTimeH2, ppOpenTimeH2;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeH2 = openTimeH1 - (openTimeH1 % (2*HOURS));      // opentime of the containing H2 bar

      if (openTimeH2 == pOpenTimeH2) {                         // the current H1 bar belongs to the same H2 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new H2 bar
         if (h2 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_H2, ppOpenTimeH2, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeH2 = pOpenTimeH2;
         pOpenTimeH2  = openTimeH2;
         pHigh        = high;
         pLow         = low;
         h2++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H3 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH3() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int h3   = -1;                                              // H3 bar index

   datetime openTimeH1, openTimeH3, pOpenTimeH3, ppOpenTimeH3;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeH3 = openTimeH1 - (openTimeH1 % (3*HOURS));      // opentime of the containing H3 bar

      if (openTimeH3 == pOpenTimeH3) {                         // the current H1 bar belongs to the same H3 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new H3 bar
         if (h3 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_H3, ppOpenTimeH3, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeH3 = pOpenTimeH3;
         pOpenTimeH3  = openTimeH3;
         pHigh        = high;
         pLow         = low;
         h3++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H4 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH4() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int h4   = -1;                                              // H4 bar index

   datetime openTimeH1, openTimeH4, pOpenTimeH4, ppOpenTimeH4;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeH4 = openTimeH1 - (openTimeH1 % (4*HOURS));      // opentime of the containing H4 bar

      if (openTimeH4 == pOpenTimeH4) {                         // the current H1 bar belongs to the same H4 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new H4 bar
         if (h4 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_H4, ppOpenTimeH4, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeH4 = pOpenTimeH4;
         pOpenTimeH4  = openTimeH4;
         pHigh        = high;
         pLow         = low;
         h4++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H6 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH6() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int h6   = -1;                                              // H6 bar index

   datetime openTimeH1, openTimeH6, pOpenTimeH6, ppOpenTimeH6;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeH6 = openTimeH1 - (openTimeH1 % (6*HOURS));      // opentime of the containing H6 bar

      if (openTimeH6 == pOpenTimeH6) {                         // the current H1 bar belongs to the same H6 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new H6 bar
         if (h6 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_H6, ppOpenTimeH6, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeH6 = pOpenTimeH6;
         pOpenTimeH6  = openTimeH6;
         pHigh        = high;
         pLow         = low;
         h6++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H8 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsH8() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int h8   = -1;                                              // H8 bar index

   datetime openTimeH1, openTimeH8, pOpenTimeH8, ppOpenTimeH8;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeH8 = openTimeH1 - (openTimeH1 % (8*HOURS));      // opentime of the containing H8 bar

      if (openTimeH8 == pOpenTimeH8) {                         // the current H1 bar belongs to the same H8 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new H8 bar
         if (h8 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_H8, ppOpenTimeH8, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeH8 = pOpenTimeH8;
         pOpenTimeH8  = openTimeH8;
         pHigh        = high;
         pLow         = low;
         h8++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for D1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsD1() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int d1   = -1;                                              // D1 bar index

   datetime openTimeH1, openTimeD1, pOpenTimeD1, ppOpenTimeD1;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeD1 = openTimeH1 - (openTimeH1 % DAY);            // opentime of the containing D1 bar (Midnight)

      if (openTimeD1 == pOpenTimeD1) {                         // the current H1 bar belongs to the same D1 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new D1 bar
         if (d1 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_D1, ppOpenTimeD1, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeD1 = pOpenTimeD1;
         pOpenTimeD1  = openTimeD1;
         pHigh        = high;
         pLow         = low;
         d1++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for W1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsW1() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int w1 = -1;                                                // W1 bar index

   datetime openTimeH1, openTimeD1, openTimeW1, pOpenTimeW1, ppOpenTimeW1;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1 = ratesH1[i][TIME];
      openTimeD1 = openTimeH1 - (openTimeH1 % DAY);            // opentime of the containing D1 bar (Midnight)
      int dow    = TimeDayOfWeekEx(openTimeD1);
      openTimeW1 = openTimeD1 - ((dow+6) % 7) * DAYS;          // opentime of the containing W1 bar (Monday 00:00)

      if (openTimeW1 == pOpenTimeW1) {                         // the current H1 bar belongs to the same W1 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new W1 bar
         if (w1 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_W1, ppOpenTimeW1, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeW1 = pOpenTimeW1;
         pOpenTimeW1  = openTimeW1;
         pHigh        = high;
         pLow         = low;
         w1++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Check rates for MN1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsMN1() {
   int bars = ArrayRange(ratesH1, 0);
   int changedBars = changedBarsH1;
   int more = maxInsideBars;
   int mn1 = -1;                                               // MN1 bar index

   datetime openTimeH1, openTimeD1, openTimeMN1, pOpenTimeMN1, ppOpenTimeMN1;
   double high, pHigh, low, pLow;

   for (int i=0; more && i < bars; i++) {
      openTimeH1  = ratesH1[i][TIME];
      openTimeD1  = openTimeH1 - (openTimeH1 % DAY);           // opentime of the containing D1 bar (Midnight)
      int day = TimeDayEx(openTimeD1);
      openTimeMN1 = openTimeD1 - (day-1);                      // opentime of the containing MN1 bar (1st of month 00:00)

      if (openTimeMN1 == pOpenTimeMN1) {                       // the current H1 bar belongs to the same MN1 bar
         high = MathMax(ratesH1[i][HIGH], high);
         low  = MathMin(ratesH1[i][LOW], low);
      }
      else {                                                   // the current H1 bar belongs to a new MN1 bar
         if (mn1 > 1 && high >= pHigh && low <= pLow) {
            if (!MarkInsideBar(PERIOD_MN1, ppOpenTimeMN1, pHigh, pLow)) return(false);
            more--;
         }
         ppOpenTimeMN1 = pOpenTimeMN1;
         pOpenTimeMN1  = openTimeMN1;
         pHigh         = high;
         pLow          = low;
         mn1++;
         high = ratesH1[i][HIGH];
         low  = ratesH1[i][LOW];
      }
   }
   return(true);
}


/**
 * Mark the specified inside bar in the chart.
 *
 * @param  int      timeframe - timeframe
 * @param  datetime openTime  - bar open time
 * @param  double   high      - bar high
 * @param  double   low       - bar low
 *
 * @return bool - success status
 */
bool MarkInsideBar(int timeframe, datetime openTime, double high, double low) {
   datetime chartOpenTime = openTime;
   int chartOffset = iBarShiftNext(NULL, NULL, openTime);            // offset of the first matching chart bar
   if (chartOffset >= 0) chartOpenTime = Time[chartOffset];

   datetime closeTime   = openTime + timeframe*MINUTES;
   double   barSize     = (high-low);
   double   longLevel1  = NormalizeDouble(high + barSize, Digits);
   double   shortLevel1 = NormalizeDouble(low  - barSize, Digits);
   string   sOpenTime   = GmtTimeFormat(openTime, "%d.%m.%Y %H:%M");
   string   sTimeframe  = TimeframeDescription(timeframe);

   // draw vertical line at IB open
   string label = sTimeframe +" inside bar: "+ NumberToStr(high, PriceFormat) +"-"+ NumberToStr(low, PriceFormat) +" (size "+ DoubleToStr(barSize/Pip, Digits & 1) +")";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longLevel1, chartOpenTime, shortLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
   } else debug("MarkInsideBar(1)", GetLastError());

   // draw horizontal line at long level 1
   label = sTimeframe +" inside bar: +100 = "+ NumberToStr(longLevel1, PriceFormat);
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longLevel1, closeTime, longLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectSetText (label, " "+ sTimeframe);
      RegisterObject(label);
   } else debug("MarkInsideBar(2)", GetLastError());

   // draw horizontal line at short level 1
   label = sTimeframe +" inside bar: -100 = "+ NumberToStr(shortLevel1, PriceFormat);
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, shortLevel1, closeTime, shortLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
   } else debug("MarkInsideBar(3)", GetLastError());

   string format = ifString(timeframe < PERIOD_D1, "%a, %d.%m.%Y %H:%M", "%a, %d.%m.%Y");    // "%a, %d.%m.%Y %H:%M:%S"
   debug("MarkInsideBar(4)  "+ sTimeframe +" at "+ GmtTimeFormat(openTime, format));
   return(true);
}


/**
 * Get rates and number of changed bars per required timeframe.
 *
 * @return bool - success status
 */
bool GetRates() {
   int changed;

   if (fTimeframes & F_PERIOD_M1 && 1) {
      changed = iCopyRates(ratesM1, NULL, PERIOD_M1);
      if (changed < 0) return(false);
      changedBarsM1 = changed;
      //debug("GetRates(1)  M1 => "+ changed +" of "+ ArrayRange(ratesM1, 0) +" bars changed");
   }

   if (fTimeframes & F_PERIOD_M5 && 1) {
      changed = iCopyRates(ratesM5, NULL, PERIOD_M5);
      if (changed < 0) return(false);
      changedBarsM5 = changed;
      //debug("GetRates(2)  M5 => "+ changed +" of "+ ArrayRange(ratesM5, 0) +" bars changed");
   }

   if (fTimeframes & F_PERIOD_M15 && 1) {
      changed = iCopyRates(ratesM15, NULL, PERIOD_M15);
      if (changed < 0) return(false);
      changedBarsM15 = changed;
      //debug("GetRates(3)  M15 => "+ changed +" of "+ ArrayRange(ratesM15, 0) +" bars changed");
   }

   if (fTimeframes & F_PERIOD_M30 && 1) {
      changed = iCopyRates(ratesM30, NULL, PERIOD_M30);
      if (changed < 0) return(false);
      changedBarsM30 = changed;
      //debug("GetRates(4)  M30 => "+ changed +" of "+ ArrayRange(ratesM30, 0) +" bars changed");
   }

   if (fTimeframes & (F_PERIOD_H1|F_PERIOD_H2|F_PERIOD_H3|F_PERIOD_H4|F_PERIOD_H6|F_PERIOD_H8|F_PERIOD_D1|F_PERIOD_W1|F_PERIOD_MN1) && 1) {
      changed = iCopyRates(ratesH1, NULL, PERIOD_H1);
      if (changed < 0) return(false);
      changedBarsH1 = changed;
      //debug("GetRates(5)  H1 => "+ changed +" of "+ ArrayRange(ratesH1, 0) +" bars changed");
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
                            "Timeframes=",     DoubleQuoteStr(Timeframes),    ";", NL,
                            "Max.InsideBars=", Max.InsideBars,                ";")
   );
}
