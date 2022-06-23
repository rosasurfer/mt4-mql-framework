/**
 * Inside Bars
 *
 * Marks inside bars and corresponding projection levels.
 *
 *
 * TODO:
 *  - check bar alignment of all timeframes and use the largest correctly aligned instead of M5
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Timeframe                      = "H1";                          // inside bar timeframe to process
extern int    NumberOfInsideBars             = 1;                             // number of inside bars to display (-1: all)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onInsideBar             = false;
extern bool   Signal.onInsideBar.Sound       = true;
extern bool   Signal.onInsideBar.Popup       = false;
extern bool   Signal.onInsideBar.Mail        = false;
extern bool   Signal.onInsideBar.SMS         = false;

extern string ___b__________________________ = "=== Monitored projection levels in % ===";
extern string InsideBar.ProjectionLevel.1    = "{a non-numeric value disables the level}";
extern string InsideBar.ProjectionLevel.2    = "0%";                          // IB breakout
extern string InsideBar.ProjectionLevel.3    = "50%";                         // projection mid range
extern string InsideBar.ProjectionLevel.4    = "100%";                        // projection full range

extern string ___c__________________________ = "=== Sound alerts ===";        // youngest inside bar only
extern string Sound.onInsideBar              = "Inside Bar.wav";
extern string Sound.onProjectionLevel.1      = "Inside Bar Level 1.wav";
extern string Sound.onProjectionLevel.2      = "Inside Bar Level 2.wav";
extern string Sound.onProjectionLevel.3      = "Inside Bar Level 3.wav";
extern string Sound.onProjectionLevel.4      = "Inside Bar Level 4.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
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

int      timeframe;                                      // IB timeframe to process
int      maxInsideBars;
string   labels[];                                       // chart object labels

bool     signalInsideBar;
bool     signalInsideBar.sound;
bool     signalInsideBar.popup;
bool     signalInsideBar.mail;
string   signalInsideBar.mailSender   = "";
string   signalInsideBar.mailReceiver = "";
bool     signalInsideBar.sms;
string   signalInsideBar.smsReceiver = "";

bool     monitorProjections;                             // projection percentage targets and corresponding price levels
double   projectionTargets[4] = {EMPTY_VALUE, EMPTY_VALUE, EMPTY_VALUE, EMPTY_VALUE};
double   projectionLevels [4];

datetime latestIB.openTime;                              // bar data of the youngest (=latest) inside bar
double   latestIB.high;
double   latestIB.low;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = ProgramName(MODE_NICE);

   // validate inputs
   // Timeframe
   string sValue = ifString(AutoConfiguration, GetConfigString(indicator, "Timeframe", Timeframe), Timeframe);
   timeframe = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
   if (timeframe == -1) return(catch("onInit(1)  invalid input parameter Timeframe: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   Timeframe = TimeframeDescription(timeframe);

   // NumberOfInsideBars
   int iValue = NumberOfInsideBars;
   if (AutoConfiguration) iValue = GetConfigInt(indicator, "NumberOfInsideBars", iValue);
   if (iValue < -1)        return(catch("onInit(2)  invalid input parameter NumberOfInsideBars: "+ iValue, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(iValue==-1, INT_MAX, iValue);

   // signaling
   signalInsideBar       = Signal.onInsideBar;                 // reset global vars when called due to an account change
   signalInsideBar.sound = Signal.onInsideBar.Sound;
   signalInsideBar.popup = Signal.onInsideBar.Popup;
   signalInsideBar.mail  = Signal.onInsideBar.Mail;
   signalInsideBar.sms   = Signal.onInsideBar.SMS;

   string signalId="Signal.onInsideBar", signalInfo="";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalInsideBar)) return(last_error);
   if (signalInsideBar) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalInsideBar.sound))                                                          return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalInsideBar.popup))                                                          return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalInsideBar.mail, signalInsideBar.mailSender, signalInsideBar.mailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalInsideBar.sms, signalInsideBar.smsReceiver))                               return(last_error);
      if (signalInsideBar.sound || signalInsideBar.popup || signalInsideBar.mail || signalInsideBar.sms) {
         signalInfo = "  ("+ StrLeft(ifString(signalInsideBar.sound, "sound,", "") + ifString(signalInsideBar.popup, "popup,", "") + ifString(signalInsideBar.mail, "mail,", "") + ifString(signalInsideBar.sms, "sms,", ""), -1) +")";
      }
      else signalInsideBar = false;
   }

   // projection levels (in percent)
   ArrayInitialize(projectionTargets, EMPTY_VALUE);

   sValue = StrTrim(InsideBar.ProjectionLevel.1);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "InsideBar.ProjectionLevel.1", sValue);
   if (StrEndsWith(sValue, "%")) sValue = StrTrim(StrLeft(sValue, -1));
   if (StrIsNumeric(sValue)) projectionTargets[0] = StrToDouble(sValue);

   sValue = StrTrim(InsideBar.ProjectionLevel.2);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "InsideBar.ProjectionLevel.2", sValue);
   if (StrEndsWith(sValue, "%")) sValue = StrTrim(StrLeft(sValue, -1));
   if (StrIsNumeric(sValue)) projectionTargets[1] = StrToDouble(sValue);

   sValue = StrTrim(InsideBar.ProjectionLevel.3);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "InsideBar.ProjectionLevel.3", sValue);
   if (StrEndsWith(sValue, "%")) sValue = StrTrim(StrLeft(sValue, -1));
   if (StrIsNumeric(sValue)) projectionTargets[2] = StrToDouble(sValue);

   sValue = StrTrim(InsideBar.ProjectionLevel.4);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "InsideBar.ProjectionLevel.4", sValue);
   if (StrEndsWith(sValue, "%")) sValue = StrTrim(StrLeft(sValue, -1));
   if (StrIsNumeric(sValue)) projectionTargets[3] = StrToDouble(sValue);

   monitorProjections = (!IsEmptyValue(projectionTargets[0]) || !IsEmptyValue(projectionTargets[1]) || !IsEmptyValue(projectionTargets[2]) || !IsEmptyValue(projectionTargets[3]));
   // sound files will be validated/checked at runtime

   // display options
   SetIndexLabel(0, NULL);                                     // disable "Data" window display
   string label = CreateStatusLabel();
   string fontName = "";                                       // "" => menu font family
   int    fontSize = 8;                                        // 8  => menu font size
   string text = ProgramName(MODE_NICE) +": "+ Timeframe + signalInfo;
   ObjectSetText(label, text, fontSize, fontName, Black);      // status display

   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double ratesM1[][6], ratesM5[][6];
   int changedBarsM1, changedBarsM5;

   if (!CopyRates(ratesM1, ratesM5, changedBarsM1, changedBarsM5)) return(last_error);

   switch (timeframe) {
      case PERIOD_M1 : CheckInsideBars   (ratesM1, changedBarsM1, PERIOD_M1); break;
      case PERIOD_M5 : CheckInsideBars   (ratesM5, changedBarsM5, PERIOD_M5); break;
      case PERIOD_M15: CheckInsideBarsM15(ratesM5, changedBarsM5);            break;
      case PERIOD_M30: CheckInsideBarsM30(ratesM5, changedBarsM5);            break;
      case PERIOD_H1 : CheckInsideBarsH1 (ratesM5, changedBarsM5);            break;
      case PERIOD_H4 : CheckInsideBarsH4 (ratesM5, changedBarsM5);            break;
      case PERIOD_D1 : CheckInsideBarsD1 (ratesM5, changedBarsM5);            break;
      case PERIOD_W1 : CheckInsideBarsW1 (ratesM5, changedBarsM5);            break;
      case PERIOD_MN1: CheckInsideBarsMN1(ratesM5, changedBarsM5);            break;
   }

   if (latestIB.openTime && monitorProjections) {
      MonitorProjections();
   }
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

   if (timeframe == PERIOD_M1) {
      changed = iCopyRates(ratesM1, NULL, PERIOD_M1);
      if (changed < 0) return(false);
      changedBarsM1 = changed;
   }
   else {
      changed = iCopyRates(ratesM5, NULL, PERIOD_M5);
      if (changed < 0) return(false);
      changedBarsM5 = changed;
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
   // are correctly aligned. On timeframes > M5 this assumption can be wrong (if odd bar alignment).
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
            CreateInsideBar(timeframe, rates[i-1][TIME], rates[i-1][HIGH], rates[i-1][LOW]);
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
         bars = 8;                                                // cover M5 periods of 2 finished M15 bars
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
               CreateInsideBar(PERIOD_M15, ppOpenTimeM15, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_M30)) return(true);                // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 14;                                               // cover M5 periods of 2 finished M30 bars
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
               CreateInsideBar(PERIOD_M30, ppOpenTimeM30, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_H1)) return(true);                 // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 26;                                               // cover M5 periods of 2 finished H1 bars
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
               CreateInsideBar(PERIOD_H1, ppOpenTimeH1, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_H4)) return(true);                 // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 98;                                               // cover M5 periods of 2 finished H4 bars
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
               CreateInsideBar(PERIOD_H4, ppOpenTimeH4, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_D1)) return(true);                 // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 578;                                              // cover M5 periods of 2 finished D1 bars
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
               CreateInsideBar(PERIOD_D1, ppOpenTimeD1, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_W1)) return(true);                 // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 4034;                                             // cover M5 periods of 2 finished W1 bars
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
               CreateInsideBar(PERIOD_W1, ppOpenTimeW1, pHigh, pLow);
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
   int bars = ArrayRange(ratesM5, 0), more;

   if (changedBarsM5 > 1) {                                       // skip regular ticks (they don't change IB status)
      if (changedBarsM5 == 2) {
         if (!IsBarOpen(PERIOD_MN1)) return(true);                // same as changedBarsM5 = 1
         more = 1;                                                // on BarOpen: check the last IB only
         bars = 17858;                                            // cover M5 periods of 2 finished MN1 bars
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
               CreateInsideBar(PERIOD_MN1, ppOpenTimeMN1, pHigh, pLow);
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
 * Draw a new inside bar for the specified data.
 *
 * @param  int      timeframe - inside bar timeframe
 * @param  datetime openTime  - inside bar open time
 * @param  double   high      - inside bar high
 * @param  double   low       - inside bar low
 *
 * @return bool - success status
 */
bool CreateInsideBar(int timeframe, datetime openTime, double high, double low) {
   datetime chartOpenTime = openTime;
   int chartOffset = iBarShiftNext(NULL, NULL, openTime);         // offset of the first matching chart bar
   if (chartOffset >= 0) chartOpenTime = Time[chartOffset];

   datetime closeTime   = openTime + timeframe*MINUTES;
   double   barSize     = (high-low);
   double   longTarget  = NormalizeDouble(high + barSize, Digits);
   double   shortTarget = NormalizeDouble(low  - barSize, Digits);
   string   sOpenTime   = GmtTimeFormat(openTime, "%d.%m.%Y %H:%M");
   string   sTimeframe  = TimeframeDescription(timeframe);
   static int counter = 0; counter++;

   // vertical line at IB open
   string label = sTimeframe +" inside bar: "+ NumberToStr(high, PriceFormat) +"-"+ NumberToStr(low, PriceFormat) +" (size "+ DoubleToStr(barSize/Pip, Digits & 1) +") ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longTarget, chartOpenTime, shortTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("CreateInsideBar(1)  label="+ DoubleQuoteStr(label), GetLastError());

   // horizontal line at long projection
   label = sTimeframe +" inside bar: +100 = "+ NumberToStr(longTarget, PriceFormat) +" ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, longTarget, closeTime, longTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      ObjectSetText (label, " "+ sTimeframe);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("CreateInsideBar(2)  label="+ DoubleQuoteStr(label), GetLastError());

   // horizontal line at short projection
   label = sTimeframe +" inside bar: -100 = "+ NumberToStr(shortTarget, PriceFormat) +" ["+ counter +"]";
   if (ObjectCreate (label, OBJ_TREND, 0, chartOpenTime, shortTarget, closeTime, shortTarget)) {
      ObjectSet     (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet     (label, OBJPROP_COLOR, Blue);
      ObjectSet     (label, OBJPROP_RAY,   false);
      ObjectSet     (label, OBJPROP_BACK,  true);
      RegisterObject(label);
      ArrayPushString(labels, label);
   } else debug("CreateInsideBar(3)  label="+ DoubleQuoteStr(label), GetLastError());


   if (!IsSuperContext()) {
      // store data of the youngest inside bar for monitoring of projection levels
      if (openTime > latestIB.openTime) {
         latestIB.openTime = openTime;
         latestIB.high     = high;
         latestIB.low      = low;
         ArrayInitialize(projectionLevels, NULL);
      }

      // signal new inside bars
      if (signalInsideBar) /*&&*/ if (IsBarOpen(timeframe)) {
         return(onInsideBar(timeframe, closeTime, high, low));
      }
   }
   return(true);
}


/**
 * Signal event handler for new inside bars.
 *
 * @param  int      timeframe - inside bar timeframe
 * @param  datetime closeTime - inside bar close time
 * @param  double   high      - inside bar high
 * @param  double   low       - inside bar low
 *
 * @return bool - success status
 */
bool onInsideBar(int timeframe, datetime closeTime, double high, double low) {
   if (!signalInsideBar) return(false);
   if (ChangedBars > 2)  return(false);

   string sTimeframe = TimeframeDescription(timeframe);
   string sBarHigh   = NumberToStr(high, PriceFormat);
   string sBarLow    = NumberToStr(low, PriceFormat);
   string sBarTime   = TimeToStr(closeTime, TIME_DATE|TIME_MINUTES);
   string sLocalTime = "("+ GmtTimeFormat(TimeLocal(), "%a, %d.%m.%Y %H:%M:%S") +", "+ GetAccountAlias() +")";
   string message    = "new "+ sTimeframe +" inside bar";

   if (IsLogInfo()) logInfo("onInsideBar(1)  "+ message +" at "+ sBarTime +"  H="+ sBarHigh +"  L="+ sBarLow);
   message = Symbol() +": "+ message;

   int error = NO_ERROR;
   if (signalInsideBar.popup)          Alert(message);
   if (signalInsideBar.sound) error |= PlaySoundEx(Sound.onInsideBar);
   if (signalInsideBar.mail)  error |= !SendEmail(signalInsideBar.mailSender, signalInsideBar.mailReceiver, message, message + NL + sLocalTime);
   if (signalInsideBar.sms)   error |= !SendSMS(signalInsideBar.smsReceiver, message + NL + sLocalTime);

   if (This.IsTesting()) Tester.Pause();
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
 * Monitor projection levels for the globally stored inside bar.
 *
 * @return bool - success status
 */
bool MonitorProjections() {
   static bool done = false; if (!done) {
      //debug("MonitorProjections(0.1)  "+ PeriodDescription(timeframe) +" IB: T="+ TimeToStr(latestIB.openTime, TIME_DATE|TIME_MINUTES) +"  H="+ NumberToStr(latestIB.high, PriceFormat) +"  L="+ NumberToStr(latestIB.low, PriceFormat));
      done = true;
   }
   return(true);
}


/**
 * Create a text label for the indicator status.
 *
 * @return string - the label or an empty string in case of errors
 */
string CreateStatusLabel() {
   string label = "rsf."+ ProgramName(MODE_NICE) +".status["+ __ExecutionContext[EC.pid] +"]";

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
   return(StringConcatenate("Timeframe=",                   DoubleQuoteStr(Timeframe),                   ";", NL,
                            "NumberOfInsideBars=",          NumberOfInsideBars,                          ";", NL,
                            "Signal.onInsideBar=",          BoolToStr(Signal.onInsideBar),               ";", NL,
                            "Signal.onInsideBar.Sound=",    BoolToStr(Signal.onInsideBar.Sound),         ";", NL,
                            "Signal.onInsideBar.Popup=",    BoolToStr(Signal.onInsideBar.Popup),         ";", NL,
                            "Signal.onInsideBar.Mail=",     BoolToStr(Signal.onInsideBar.Mail),          ";", NL,
                            "Signal.onInsideBar.SMS=",      BoolToStr(Signal.onInsideBar.SMS),           ";", NL,

                            "InsideBar.ProjectionLevel.1=", DoubleQuoteStr(InsideBar.ProjectionLevel.1), ";", NL,
                            "InsideBar.ProjectionLevel.2=", DoubleQuoteStr(InsideBar.ProjectionLevel.2), ";", NL,
                            "InsideBar.ProjectionLevel.3=", DoubleQuoteStr(InsideBar.ProjectionLevel.3), ";", NL,
                            "InsideBar.ProjectionLevel.4=", DoubleQuoteStr(InsideBar.ProjectionLevel.4), ";", NL,

                            "Sound.onInsideBar=",           DoubleQuoteStr(Sound.onInsideBar),           ";", NL,
                            "Sound.onProjectionLevel.1=",   DoubleQuoteStr(Sound.onProjectionLevel.1),   ";", NL,
                            "Sound.onProjectionLevel.2=",   DoubleQuoteStr(Sound.onProjectionLevel.2),   ";", NL,
                            "Sound.onProjectionLevel.3=",   DoubleQuoteStr(Sound.onProjectionLevel.3),   ";", NL,
                            "Sound.onProjectionLevel.4=",   DoubleQuoteStr(Sound.onProjectionLevel.4),   ";")
   );
}
