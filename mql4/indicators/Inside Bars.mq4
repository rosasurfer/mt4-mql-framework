/**
 * Inside Bars
 *
 * Marks inside bars and the corresponding projection levels of the specified timeframes in the chart.
 *
 *
 * TODO:
 *  - check bar alignment of all timeframes and use the largest correctly aligned one (instead of always using M5)
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Timeframes         = "H1";                 // one or more timeframes to analyze, separated by comma
extern int    Max.InsideBars     = 1;                    // max. number of inside bars per timeframe to find (-1: all)
extern string ___a__________________________;

extern string Signal.onInsideBar = "on | off | auto*";
extern string Signal.Sound       = "on | off | auto*";
extern string Signal.Mail        = "on | off | auto*";
extern string Signal.SMS         = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iCopyRates.mqh>
#include <functions/IsBarOpen.mqh>

#property indicator_chart_window

#define TIME      0                                      // rates array indexes
#define OPEN      1
#define LOW       2
#define HIGH      3
#define CLOSE     4
#define VOLUME    5

int    fTimeframes;                                      // flags of the timeframes to analyze
int    maxInsideBars;

string labels[];                                         // object labels of existing IB chart markers

bool   signals;
bool   signal.sound;
string signal.sound.file = "Siren.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";
string signal.info = "";                                 // additional chart legend info


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
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
      int timeframe = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
      if (timeframe == -1)  return(catch("onInit(1)  invalid identifier "+ DoubleQuoteStr(sValue) +" in input parameter Timeframes: "+ DoubleQuoteStr(Timeframes), ERR_INVALID_INPUT_PARAMETER));
      fTimeframes |= TimeframeFlag(timeframe);
      sValues[i] = TimeframeDescription(timeframe);
   }
   Timeframes = JoinStrings(sValues, ",");

   // Max.InsideBars
   if (Max.InsideBars < -1) return(catch("onInit(2)  invalid input parameter Max.InsideBars: "+ Max.InsideBars, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(Max.InsideBars==-1, INT_MAX, Max.InsideBars);

   // signaling
   string signalInfo = "";
   if (!ConfigureSignals("Inside Bars", Signal.onInsideBar, signals))                                    return(last_error);
   if (signals) {
      if (!ConfigureSignalsBySound(Signal.Sound, signal.sound                                         )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail,  signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,   signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signalInfo = "  ("+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1) +")";
      }
      else signals = false;
   }

   // display options
   SetIndexLabel(0, NULL);                                     // disable "Data" window display
   string label = CreateStatusLabel();
   string fontName = "";                                       // "" => menu font family
   int    fontSize = 8;                                        // 8  => menu font size
   string text = ProgramName() +": "+ Timeframes + signalInfo;
   ObjectSetText(label, text, fontSize, fontName, Black);      // status display

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double ratesM1[][6], ratesM5[][6];
   int changedBarsM1, changedBarsM5;

   //if (IsBarOpen(PERIOD_M1))  debug("onTick(0.1)   BarOpen(M1) = 1");
   //if (IsBarOpen(PERIOD_M5))  debug("onTick(0.2)   BarOpen(M5) = 1");
   //if (IsBarOpen(PERIOD_M15)) debug("onTick(0.3)   BarOpen(M15) = 1");

   if (!CopyRates(ratesM1, ratesM5, changedBarsM1, changedBarsM5)) return(last_error);

   if (fTimeframes & F_PERIOD_M1  && 1) CheckInsideBars(ratesM1, changedBarsM1, PERIOD_M1);
   if (fTimeframes & F_PERIOD_M5  && 1) CheckInsideBars(ratesM5, changedBarsM5, PERIOD_M5);
   if (fTimeframes & F_PERIOD_M15 && 1) CheckInsideBarsM15(ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_M30 && 1) CheckInsideBarsM30(ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_H1  && 1) CheckInsideBarsH1 (ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_H4  && 1) CheckInsideBarsH4 (ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_D1  && 1) CheckInsideBarsD1 (ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_W1  && 1) CheckInsideBarsW1 (ratesM5, changedBarsM5);
   if (fTimeframes & F_PERIOD_MN1 && 1) CheckInsideBarsMN1(ratesM5, changedBarsM5);

   return(last_error);
}


/**
 * Copy rates and get the number of changed bars per required timeframe.
 *
 * @param  _Out_ double &ratesM1[][]   - array receiving the M1 rates
 * @param  _Out_ double &ratesM5[][]   - array receiving the M5 rates
 * @param  _Out_ int    &changedBarsM1 - variable receiving the number of changed M1 bars
 * @param  _Out_ int    &changedBarsM5 - variable receiving the number of changed M5 bars
 *
 * @return bool - success status
 */
bool CopyRates(double &ratesM1[][], double &ratesM5[][], int &changedBarsM1, int &changedBarsM5) {
   int changed;

   if (fTimeframes & F_PERIOD_M1 && 1) {
      changed = iCopyRates(ratesM1, NULL, PERIOD_M1);
      if (changed < 0) return(false);
      changedBarsM1 = changed;
      //debug("GetRates(1)  M1: "+ changed +" of "+ ArrayRange(ratesM1, 0) +" bars changed");
   }

   if (fTimeframes & (F_PERIOD_M5|F_PERIOD_M15|F_PERIOD_M30|F_PERIOD_H1|F_PERIOD_H4|F_PERIOD_D1|F_PERIOD_W1|F_PERIOD_MN1) && 1) {
      changed = iCopyRates(ratesM5, NULL, PERIOD_M5);
      if (changed < 0) return(false);
      changedBarsM5 = changed;
      //debug("GetRates(2)  M5: "+ changed +" of "+ ArrayRange(ratesM5, 0) +" bars changed");
   }
   return(true);
}


/**
 * Check the specified rates array for new or changed inside bars.
 *
 * @param  double rates[][]   - rates array
 * @param  int    changedBars - number of changed bars in the rates array
 * @param  int    timeframe   - timeframe of the rates array
 *
 * @return bool - success status
 */
bool CheckInsideBars(double rates[][], int changedBars, int timeframe) {
   // The logic for periods M1 and M5 operates directly on the corresponding rates. It assumes that bars of those timeframes
   // are aligned correctly by the broker. On timeframes >= M15 this assumption can be wrong (odd bar alignment).
   int bars = ArrayRange(rates, 0), more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 3;
      }
      else {
         DeleteInsideBars(timeframe);                             // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      for (int i=2; i < bars; i++) {
         if (rates[i][HIGH] >= rates[i-1][HIGH] && rates[i][LOW] <= rates[i-1][LOW]) {
            MarkInsideBar(timeframe, rates[i-1][TIME], rates[i-1][HIGH], rates[i-1][LOW]);
            more--;
            if (!more) break;
         }
      }
   }
   return(true);
}


/**
 * Check rates for M15 inside bars. Operates on M5 rates as M15 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsM15(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_M15)) return(true);                // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 7;                                                // cover M5 periods of 2 finished M15 bars
      }
      else {
         DeleteInsideBars(PERIOD_M15);                            // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeM15, pOpenTimeM15, ppOpenTimeM15;
      double high, pHigh, low, pLow;

      for (int i, m15=-1; i < bars; i++) {                        // m15: M15 bar index
         openTimeM5  = ratesM5[i][TIME];
         openTimeM15 = openTimeM5 - (openTimeM5 % (15*MINUTES));  // opentime of the corresponding M15 bar

         if (openTimeM15 == pOpenTimeM15) {                       // the current M5 bar belongs to the same M30 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {
            if (m15 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_M15, ppOpenTimeM15, pHigh, pLow);
               more--;
               if (!more) break;
            }
            m15++;
            ppOpenTimeM15 = pOpenTimeM15;
            pOpenTimeM15  = openTimeM15;
            pHigh         = high;
            pLow          = low;
            high          = ratesM5[i][HIGH];
            low           = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for M30 inside bars. Operates on M5 rates as M30 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsM30(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_M30)) return(true);                // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 13;                                               // cover M5 periods of 2 finished M30 bars
      }
      else {
         DeleteInsideBars(PERIOD_M30);                            // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeM30, pOpenTimeM30, ppOpenTimeM30;
      double high, pHigh, low, pLow;

      for (int i, m30=-1; i < bars; i++) {                        // m30: M30 bar index
         openTimeM5  = ratesM5[i][TIME];
         openTimeM30 = openTimeM5 - (openTimeM5 % (30*MINUTES));  // opentime of the corresponding M30 bar

         if (openTimeM30 == pOpenTimeM30) {                       // the current M5 bar belongs to the same M30 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {
            if (m30 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_M30, ppOpenTimeM30, pHigh, pLow);
               more--;
               if (!more) break;
            }
            m30++;
            ppOpenTimeM30 = pOpenTimeM30;
            pOpenTimeM30  = openTimeM30;
            pHigh         = high;
            pLow          = low;
            high          = ratesM5[i][HIGH];
            low           = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for H1 inside bars. Operates on M5 rates as H1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsH1(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_H1)) return(true);                 // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 25;                                               // cover M5 periods of 2 finished H1 bars
      }
      else {
         DeleteInsideBars(PERIOD_H1);                             // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeH1, pOpenTimeH1, ppOpenTimeH1;
      double high, pHigh, low, pLow;

      for (int i, h1=-1; i < bars; i++) {                         // h1: H1 bar index
         openTimeM5 = ratesM5[i][TIME];
         openTimeH1 = openTimeM5 - (openTimeM5 % HOUR);           // opentime of the corresponding H1 bar

         if (openTimeH1 == pOpenTimeH1) {                         // the current M5 bar belongs to the same H1 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {
            if (h1 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_H1, ppOpenTimeH1, pHigh, pLow);
               more--;
               if (!more) break;
            }
            h1++;
            ppOpenTimeH1 = pOpenTimeH1;
            pOpenTimeH1  = openTimeH1;
            pHigh        = high;
            pLow         = low;
            high         = ratesM5[i][HIGH];
            low          = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for H4 inside bars. Operates on M5 rates as H4 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsH4(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_H4)) return(true);                 // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 97;                                               // cover M5 periods of 2 finished H4 bars
      }
      else {
         DeleteInsideBars(PERIOD_H4);                             // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeH4, pOpenTimeH4, ppOpenTimeH4;
      double high, pHigh, low, pLow;

      for (int i, h4=-1; i < bars; i++) {                         // h4: H4 bar index
         openTimeM5 = ratesM5[i][TIME];
         openTimeH4 = openTimeM5 - (openTimeM5 % (4*HOURS));      // opentime of the corresponding H4 bar

         if (openTimeH4 == pOpenTimeH4) {                         // the current H1 bar belongs to the same H4 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {                                                   // the current H1 bar belongs to a new H4 bar
            if (h4 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_H4, ppOpenTimeH4, pHigh, pLow);
               more--;
               if (!more) break;
            }
            h4++;
            ppOpenTimeH4 = pOpenTimeH4;
            pOpenTimeH4  = openTimeH4;
            pHigh        = high;
            pLow         = low;
            high         = ratesM5[i][HIGH];
            low          = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for D1 inside bars. Operates on M5 rates as D1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsD1(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_D1)) return(true);                 // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 577;                                              // cover M5 periods of 2 finished D1 bars
      }
      else {
         DeleteInsideBars(PERIOD_D1);                             // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeD1, pOpenTimeD1, ppOpenTimeD1;
      double high, pHigh, low, pLow;

      for (int i, d1=-1; i < bars; i++) {                         // d1: D1 bar index
         openTimeM5 = ratesM5[i][TIME];
         openTimeD1 = openTimeM5 - (openTimeM5 % DAY);            // opentime of the corresponding D1 bar (Midnight)

         if (openTimeD1 == pOpenTimeD1) {                         // the current H1 bar belongs to the same D1 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {                                                   // the current H1 bar belongs to a new D1 bar
            if (d1 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_D1, ppOpenTimeD1, pHigh, pLow);
               more--;
               if (!more) break;
            }
            d1++;
            ppOpenTimeD1 = pOpenTimeD1;
            pOpenTimeD1  = openTimeD1;
            pHigh        = high;
            pLow         = low;
            high         = ratesM5[i][HIGH];
            low          = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for W1 inside bars. Operates on M5 rates as W1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsW1(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_W1)) return(true);                 // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 4033;                                             // cover M5 periods of 2 finished W1 bars
      }
      else {
         DeleteInsideBars(PERIOD_W1);                             // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeD1, openTimeW1, pOpenTimeW1, ppOpenTimeW1;
      double high, pHigh, low, pLow;

      for (int i, w1=-1; i < bars; i++) {                         // w1: W1 bar index
         openTimeM5 = ratesM5[i][TIME];
         openTimeD1 = openTimeM5 - (openTimeM5 % DAY);            // opentime of the corresponding D1 bar (Midnight)
         int dow    = TimeDayOfWeekEx(openTimeD1);
         openTimeW1 = openTimeD1 - ((dow+6) % 7) * DAYS;          // opentime of the corresponding W1 bar (Monday 00:00)

         if (openTimeW1 == pOpenTimeW1) {                         // the current H1 bar belongs to the same W1 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {                                                   // the current H1 bar belongs to a new W1 bar
            if (w1 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_W1, ppOpenTimeW1, pHigh, pLow);
               more--;
               if (!more) break;
            }
            w1++;
            ppOpenTimeW1 = pOpenTimeW1;
            pOpenTimeW1  = openTimeW1;
            pHigh        = high;
            pLow         = low;
            high         = ratesM5[i][HIGH];
            low          = ratesM5[i][LOW];
         }
      }
   }
   return(true);
}


/**
 * Check rates for MN1 inside bars. Operates on M5 rates as MN1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][]   - M5 rates array
 * @param  int    changedBarsM5 - number of changed M5 bars
 *
 * @return bool - success status
 */
bool CheckInsideBarsMN1(double ratesM5[][], int changedBarsM5) {
   int bars = ArrayRange(ratesM5, 0);
   int changedBars = changedBarsM5, more;

   if (changedBars > 1) {                                         // skip regular ticks (they don't change IB status)
      if (changedBars == 2) {
         if (!IsBarOpen(PERIOD_MN1)) return(true);                // same as changedBars = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 17569;                                            // cover M5 periods of 2 finished MN1 bars
      }
      else {
         DeleteInsideBars(PERIOD_MN1);                            // on data pumping: delete all existing bars
         more = maxInsideBars;                                    // check the configured number of IBs
      }

      datetime openTimeM5, openTimeD1, openTimeMN1, pOpenTimeMN1, ppOpenTimeMN1;
      double high, pHigh, low, pLow;

      for (int i, mn1=-1; i < bars; i++) {                        // mn1: MN1 bar index
         openTimeM5 = ratesM5[i][TIME];
         openTimeD1 = openTimeM5 - (openTimeM5 % DAY);            // opentime of the corresponding D1 bar (Midnight)
         int day = TimeDayEx(openTimeD1);
         openTimeMN1 = openTimeD1 - (day-1) * DAYS;               // opentime of the corresponding MN1 bar (1st of month 00:00)

         if (openTimeMN1 == pOpenTimeMN1) {                       // the current H1 bar belongs to the same MN1 bar
            high = MathMax(ratesM5[i][HIGH], high);
            low  = MathMin(ratesM5[i][LOW], low);
         }
         else {                                                   // the current H1 bar belongs to a new MN1 bar
            if (mn1 > 1 && high >= pHigh && low <= pLow) {
               MarkInsideBar(PERIOD_MN1, ppOpenTimeMN1, pHigh, pLow);
               more--;
               if (!more) break;
            }
            mn1++;
            ppOpenTimeMN1 = pOpenTimeMN1;
            pOpenTimeMN1  = openTimeMN1;
            pHigh         = high;
            pLow          = low;
            high          = ratesM5[i][HIGH];
            low           = ratesM5[i][LOW];
         }
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
   int chartOffset = iBarShiftNext(NULL, NULL, openTime);         // offset of the first matching chart bar
   if (chartOffset >= 0) chartOpenTime = Time[chartOffset];

   datetime closeTime   = openTime + timeframe*MINUTES;
   double   barSize     = (high-low);
   double   longLevel1  = NormalizeDouble(high + barSize, Digits);
   double   shortLevel1 = NormalizeDouble(low  - barSize, Digits);
   string   sOpenTime   = GmtTimeFormat(openTime, "%d.%m.%Y %H:%M");
   string   sTimeframe  = TimeframeDescription(timeframe);
   static int counter = 0; counter++;

   // draw vertical line at IB open
   string label = sTimeframe +" inside bar: "+ NumberToStr(high, PriceFormat) +"-"+ NumberToStr(low, PriceFormat) +" (size "+ DoubleToStr(barSize/Pip, Digits & 1) +") ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longLevel1, chartOpenTime, shortLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("MarkInsideBar(1)  label="+ DoubleQuoteStr(label), GetLastError());

   // draw horizontal line at long level 1
   label = sTimeframe +" inside bar: +100 = "+ NumberToStr(longLevel1, PriceFormat) +" ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longLevel1, closeTime, longLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectSetText (label, " "+ sTimeframe);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("MarkInsideBar(2)  label="+ DoubleQuoteStr(label), GetLastError());

   // draw horizontal line at short level 1
   label = sTimeframe +" inside bar: -100 = "+ NumberToStr(shortLevel1, PriceFormat) +" ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, shortLevel1, closeTime, shortLevel1)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("MarkInsideBar(3)  label="+ DoubleQuoteStr(label), GetLastError());

   // signal new inside bars
   if (!IsSuperContext() && IsBarOpen(timeframe) && signals)
      return(onInsideBar(timeframe));
   return(true);
}


/**
 * Signal event handler for new inside bars.
 *
 * @param  int timeframe
 *
 * @return bool - success status
 */
bool onInsideBar(int timeframe) {
   string message     = TimeframeDescription(timeframe) +" inside bar at "+ NumberToStr((Bid+Ask)/2, PriceFormat);
   string accountTime = "("+ GmtTimeFormat(TimeLocal(), "%a, %d.%m.%Y %H:%M:%S") +", "+ GetAccountAlias() +")";

   if (IsLogInfo()) logInfo("onInsideBar(1)  "+ message);
   message = Symbol() +": "+ message;

   int error = 0;
   if (signal.sound) error |= !PlaySoundEx(signal.sound.file);
   if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message + NL + accountTime);
   if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message + NL + accountTime);
   return(!error);
}


/**
 * Delete inside bar markers of the specified timeframe from the chart.
 *
 * @param  int timeframe
 *
 * @return bool - success status
 */
bool DeleteInsideBars(int timeframe) {
   string prefix = TimeframeDescription(timeframe) +" inside bar";
   int size = ArraySize(labels);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWith(labels[i], prefix)) {
         if (!ObjectDelete(labels[i])) {
            int error = GetLastError();
            if (error != ERR_OBJECT_DOES_NOT_EXIST) return(!catch("DeleteInsideBars(2)->ObjectDelete(label="+ DoubleQuoteStr(labels[i]) +")", intOr(error, ERR_RUNTIME_ERROR)));
         }
         ArraySpliceStrings(labels, i, 1);
      }
   }
   return(true);
}


/**
 * Create a text label for the indicator status.
 *
 * @return string - the label or an empty string in case of errors
 */
string CreateStatusLabel() {
   string label = "rsf."+ ProgramName() +".status["+ __ExecutionContext[EC.pid] +"]";

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 500);            // the SuperBars label starts at xDist=300
      ObjectSet    (label, OBJPROP_YDISTANCE,   3);
      ObjectSetText(label, " ", 1);
      RegisterObject(label);
   }

   if (!catch("CreateStatusLabel(1)"))
      return(label);
   return("");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Timeframes=",         DoubleQuoteStr(Timeframes),         ";", NL,
                            "Max.InsideBars=",     Max.InsideBars,                     ";", NL,
                            "Signal.onInsideBar=", DoubleQuoteStr(Signal.onInsideBar), ";", NL,
                            "Signal.Sound=",       DoubleQuoteStr(Signal.Sound),       ";", NL,
                            "Signal.Mail=",        DoubleQuoteStr(Signal.Mail),        ";", NL,
                            "Signal.SMS=",         DoubleQuoteStr(Signal.SMS),         ";")


   );
}
