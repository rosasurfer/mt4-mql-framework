/**
 * Inside Bars
 *
 * Marks inside bars and IB 100% extension levels.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = { INIT_TIMEZONE };
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Timeframe                      = "H1";                          // IB timeframe
extern int    NumberOfInsideBars             = 3;                             // number of IBs to display (-1: all)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onInsideBar             = false;
extern string Signal.onInsideBar.Types       = "sound* | alert | mail | telegram";
extern string Signal.SoundFile               = "Inside Bar.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#property indicator_chart_window

int    insideBarTF;                             // IB timeframe to process
int    maxInsideBars;
string labels[];                                // chart object labels

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.telegram;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // Timeframe
   string sValue = Timeframe;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Timeframe", sValue);
   insideBarTF = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
   if (insideBarTF == -1) return(catch("onInit(1)  invalid input parameter Timeframe: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   Timeframe = TimeframeDescription(insideBarTF);
   // NumberOfInsideBars
   int iValue = NumberOfInsideBars;
   if (AutoConfiguration) iValue = GetConfigInt(indicator, "NumberOfInsideBars", iValue);
   if (iValue < -1)     return(catch("onInit(2)  invalid input parameter NumberOfInsideBars: "+ iValue, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(iValue==-1, INT_MAX, iValue);

   // signal configuration
   string signalId = "Signal.onInsideBar", legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onInsideBar)) return(last_error);
   if (Signal.onInsideBar) {
      if (!ConfigureSignalTypes(signalId, Signal.onInsideBar.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.telegram)) {
         return(catch("onInit(3)  invalid input parameter Signal.onInsideBar.Types: "+ DoubleQuoteStr(Signal.onInsideBar.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onInsideBar = (signal.sound || signal.alert || signal.mail || signal.telegram);
      if (Signal.onInsideBar) legendInfo = "  ("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.telegram, "tgm,", ""), -1) +")";
   }
   // Signal.SoundFile
   if (AutoConfiguration) Signal.SoundFile = GetConfigString(indicator, "Signal.SoundFile", Signal.SoundFile);

   // display options
   string label = CreateStatusLabel();
   string fontName = "";                                          // "" => system menu font family
   int    fontSize = 8;                                           // 8  => system menu font size
   string text = WindowExpertName() +": "+ Timeframe + legendInfo;
   ObjectSetText(label, text, fontSize, fontName, Black);         // status display

   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (Symbol() == "BTCUSD.db") debug("onTick(0.1)  Tick.time="+ ifString(Tick.time, TimeToStr(Tick.time), "0"));

   // Simplifying the analysis by using a different than the current timeframe only works with broker-connected symbols.
   // For compatibility with offline charts and/or synthetic symbols, the current chart timeframe must be used. This means
   // signaling for a lower timeframe (e.g. H1) will pause if the chart is switched to a higher timeframe (e.g. H4).
   // Drawing lower timeframe IBs on a higher timeframe chart is not possible, anyway.
   if (Period() > insideBarTF) return(last_error);
   if (ChangedBars < 2)        return(last_error);                // skip regular ticks, they never change IB status

   if (insideBarTF == Period()) {
      CheckSameTimeframeIB();
   }
   else {
      CheckHigherTimeframeIB();
   }
   return(last_error);


   double rates[][6];
   switch (insideBarTF) {
      case PERIOD_M1:  CheckInsideBarsM1();       break;
      case PERIOD_M5:  CheckInsideBarsM5 (rates); break;
      case PERIOD_M15: CheckInsideBarsM15(rates); break;
      case PERIOD_M30: CheckInsideBarsM30(rates); break;
      case PERIOD_H1 : CheckInsideBarsH1 (rates); break;
      case PERIOD_H4 : CheckInsideBarsH4 (rates); break;
      case PERIOD_D1 : CheckInsideBarsD1 (rates); break;
      case PERIOD_W1 : CheckInsideBarsW1 (rates); break;
      case PERIOD_MN1: CheckInsideBarsMN1(rates); break;
   }
}


/**
 * Check current bars for new or changed inside bars of the same timeframe.
 *
 * @return bool - success status
 */
bool CheckSameTimeframeIB() {
   return(true);
}


/**
 * Check bars for new or changed inside bars of a higher timeframe.
 *
 * @return bool - success status
 */
bool CheckHigherTimeframeIB() {
   int more, bars;

   if (Symbol() == "BTCUSD.db") insideBarTF = 2;

   if (ChangedBars == 2) {
      if (Symbol() == "BTCUSD.db") debug("CheckHigherTimeframeIB(0.1)");
      if (!IsBarOpen(insideBarTF)) return(!last_error);              // if not BarOpen, it's the same as ChangedBars = 1
      if (Symbol() == "BTCUSD.db") debug("CheckHigherTimeframeIB(0.2)");
      more = 1;                                                      // if BarOpen: check the finished HigherTF bar only
      bars = 1 + 2 * insideBarTF/Period();                           // cover LowerTF bars of 2 finished HigherTF bars,
      if (Symbol() == "BTCUSD.db") debug("CheckHigherTimeframeIB(0.3)  BarOpen("+ TimeframeDescription(insideBarTF) +")");
   }                                                                 // that's current bar + actual IB + preceding outside bar
   else {
      DeleteInsideBars(insideBarTF);                                 // on init() or additional data: delete all existing IBs
      more = maxInsideBars;                                          // re-check for the configured number of IBs
      bars = Bars;
   }

   datetime htf0Time, htf1Time, htf2Time;
   double htf1High, htf1Low, htf2High, htf2Low;
   int bar1From, bar1To, bar2From, bar2To;

   // inspect current chart bars
   for (int bar=0; bar < bars; bar++) {
      // resolve htfTime[0]: current HTF bar
      if (!htf0Time) {
         htf0Time = Time[bar] - Time[bar] % (insideBarTF * MINUTES);
         bar = iBarShiftNext(NULL, NULL, htf0Time);                  // offset of the corresponding chart bar
         if (bar < 0)            return(!catch("CheckHigherTimeframeIB(1)  chart bar for htfTime[0]="+ TimeToStr(htf0Time) +" not found", ERR_ILLEGAL_STATE));
         if (bar == EMPTY_VALUE) return(false);
         bar++;
         if (bar >= bars) break;
         bar1To = bar;
      }

      // resolve htfTime[1]: the next possible inside bar
      if (!htf1Time) {
         htf1Time = Time[bar] - Time[bar] % (insideBarTF * MINUTES);
         bar = iBarShiftNext(NULL, NULL, htf1Time);                  // offset of the corresponding chart bar
         if (bar < 0)            return(!catch("CheckHigherTimeframeIB(2)  chart bar for htfTime[1]="+ TimeToStr(htf1Time) +" not found", ERR_ILLEGAL_STATE));
         if (bar == EMPTY_VALUE) return(false);
         bar1From = bar;
         bar++;
         if (bar >= bars) break;
      }

      // resolve htfTime[2]: the next possible outside bar
      bar2To   = bar;
      htf2Time = Time[bar] - Time[bar] % (insideBarTF * MINUTES);
      bar = iBarShiftNext(NULL, NULL, htf2Time);                     // offset of the corresponding chart bar
      if (bar < 0)            return(!catch("CheckHigherTimeframeIB(3)  chart bar for htfTime[2]="+ TimeToStr(htf2Time) +" not found", ERR_ILLEGAL_STATE));
      if (bar == EMPTY_VALUE) return(false);
      bar2From = bar;

      // resolve high/low of htf[1] and htf[2]
      if (!htf1High) htf1High = High[iHighest(NULL, NULL, MODE_HIGH, bar1From-bar1To+1, bar1To)];
      if (!htf1Low)  htf1Low  = Low [iLowest (NULL, NULL, MODE_LOW,  bar1From-bar1To+1, bar1To)];

      htf2High = High[iHighest(NULL, NULL, MODE_HIGH, bar2From-bar2To+1, bar2To)];
      htf2Low  = Low [iLowest (NULL, NULL, MODE_LOW,  bar2From-bar2To+1, bar2To)];

      // resolve the actual inside bar status
      if (htf2High >= htf1High && htf2Low <= htf1Low) {
         if (Symbol() == "BTCUSD.db") {
            if (ValidBars > 0) {
               debug("CheckHigherTimeframeIB(0.4)  calling CreateInsideBar()...");
            }
         }
         else {
            CreateInsideBar(insideBarTF, htf1Time, htf1High, htf1Low);
         }
         more--;
         if (!more) break;
      }

      // prepare next iteration
      htf0Time = htf1Time;
      htf1Time = htf2Time;
      bar1To   = bar2To;
      bar1From = bar2From;
      htf1High = htf2High;
      htf1Low  = htf2Low;
   }
   return(!catch("CheckHigherTimeframeIB(4)"));




   // --- old ---------------------------------------------------------------------------------------------------------------
   datetime openTimeHtf, pOpenTimeHtf, ppOpenTimeHtf;                // prevOpenTimeHtf/prevPrevOpenTimeHtf
   double high, pHigh, low, pLow;                                    // high/prevHigh, low/prevLow
   int htfBar = -1;

   for (bar=0; bar < bars; bar++) {
      openTimeHtf = Time[bar] - Time[bar] % (insideBarTF * MINUTES); // opentime of the HigherTF bar

      if (openTimeHtf == pOpenTimeHtf) {                             // same HigherTF bar
         high = MathMax(High[bar], high);
         low  = MathMin(Low [bar], low);
      }
      else {                                                         // new (older) HigherTF bar
         if (htfBar > 1 && high >= pHigh && low <= pLow) {
            CreateInsideBar(insideBarTF, ppOpenTimeHtf, pHigh, pLow);
            more--;
            if (!more) break;
         }
         htfBar++;
         ppOpenTimeHtf = pOpenTimeHtf;
         pOpenTimeHtf  = openTimeHtf;
         pHigh         = high;
         pLow          = low;
         high          = High[bar];
         low           = Low [bar];
      }
   }
   return(true);
}



/**
 * Check the current timeseries for new or changed M1 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM1() {
   int bars=Bars, more;

   if (ChangedBars == 2) {
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 3;
   }
   else {
      DeleteInsideBars(insideBarTF);                              // on init() or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   for (int i=2; i < bars; i++) {
      if (High[i] >= High[i-1] && Low[i] <= Low[i-1]) {
         CreateInsideBar(insideBarTF, Time[i-1], High[i-1], Low[i-1]);
         more--;
         if (!more) break;
      }
   }
   return(true);
}


/**
 * Check the current timeseries for new or changed M5 inside bars.
 *
 * @return bool - success status
 */
bool CheckInsideBarsM5(double rates[][]) {
   int bars=Bars, more;

   if (ChangedBars == 2) {
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 3;
   }
   else {
      DeleteInsideBars(insideBarTF);                              // on init() or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   for (int i=2; i < bars; i++) {
      if (High[i] >= High[i-1] && Low[i] <= Low[i-1]) {
         CreateInsideBar(insideBarTF, Time[i-1], High[i-1], Low[i-1]);
         more--;
         if (!more) break;
      }
   }
   return(true);
}


/**
 * Check rates for M15 inside bars. Operates on M5 rates as M15 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsM15(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_M15)) return(!last_error);            // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 8;                                                   // cover M5 periods of 2 finished M15 bars
   }
   else {
      DeleteInsideBars(PERIOD_M15);                               // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeM15, pOpenTimeM15, ppOpenTimeM15;
   double high, pHigh, low, pLow;

   for (int i, m15=-1; i < bars; i++) {                           // m15: M15 bar index
      openTimeM5  = ratesM5[i][BAR400_TIME];
      openTimeM15 = openTimeM5 - (openTimeM5 % (15*MINUTES));     // opentime of the corresponding M15 bar

      if (openTimeM15 == pOpenTimeM15) {                          // the current M5 bar belongs to the same M30 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW], low);
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
         high          = ratesM5[i][BAR400_HIGH];
         low           = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for M30 inside bars. Operates on M5 rates as M30 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsM30(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_M30)) return(!last_error);            // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 14;                                                  // cover M5 periods of 2 finished M30 bars
   }
   else {
      DeleteInsideBars(PERIOD_M30);                               // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeM30, pOpenTimeM30, ppOpenTimeM30;
   double high, pHigh, low, pLow;

   for (int i, m30=-1; i < bars; i++) {                           // m30: M30 bar index
      openTimeM5  = ratesM5[i][BAR400_TIME];
      openTimeM30 = openTimeM5 - openTimeM5 % (30 * MINUTES);     // opentime of the corresponding M30 bar

      if (openTimeM30 == pOpenTimeM30) {                          // the current M5 bar belongs to the same M30 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
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
         high          = ratesM5[i][BAR400_HIGH];
         low           = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H1 inside bars. Operates on M5 rates as H1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsH1(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_H1)) return(!last_error);             // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 26;                                                  // cover M5 periods of 2 finished H1 bars
   }
   else {
      DeleteInsideBars(PERIOD_H1);                                // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeH1, pOpenTimeH1, ppOpenTimeH1;
   double high, pHigh, low, pLow;

   for (int i, h1=-1; i < bars; i++) {                            // h1: H1 bar index
      openTimeM5 = ratesM5[i][BAR400_TIME];
      openTimeH1 = openTimeM5 - (openTimeM5 % HOUR);              // opentime of the corresponding H1 bar

      if (openTimeH1 == pOpenTimeH1) {                            // the current M5 bar belongs to the same H1 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
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
         high         = ratesM5[i][BAR400_HIGH];
         low          = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for H4 inside bars. Operates on M5 rates as H4 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsH4(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_H4)) return(!last_error);             // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 98;                                                  // cover M5 periods of 2 finished H4 bars
   }
   else {
      DeleteInsideBars(PERIOD_H4);                                // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeH4, pOpenTimeH4, ppOpenTimeH4;
   double high, pHigh, low, pLow;

   for (int i, h4=-1; i < bars; i++) {                            // h4: H4 bar index
      openTimeM5 = ratesM5[i][BAR400_TIME];
      openTimeH4 = openTimeM5 - openTimeM5 % (4 * HOURS);         // opentime of the corresponding H4 bar

      if (openTimeH4 == pOpenTimeH4) {                            // the current H1 bar belongs to the same H4 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
      }
      else {                                                      // the current H1 bar belongs to a new H4 bar
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
         high         = ratesM5[i][BAR400_HIGH];
         low          = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for D1 inside bars. Operates on M5 rates as D1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsD1(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_D1)) return(!last_error);             // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 578;                                                 // cover M5 periods of 2 finished D1 bars
   }
   else {
      DeleteInsideBars(PERIOD_D1);                                // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeD1, pOpenTimeD1, ppOpenTimeD1;
   double high, pHigh, low, pLow;

   for (int i, d1=-1; i < bars; i++) {                            // d1: D1 bar index
      openTimeM5 = ratesM5[i][BAR400_TIME];
      openTimeD1 = openTimeM5 - openTimeM5 % DAY;                 // opentime of the corresponding D1 bar (Midnight)

      if (openTimeD1 == pOpenTimeD1) {                            // the current H1 bar belongs to the same D1 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
      }
      else {                                                      // the current H1 bar belongs to a new D1 bar
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
         high         = ratesM5[i][BAR400_HIGH];
         low          = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for W1 inside bars. Operates on M5 rates as W1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsW1(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_W1)) return(!last_error);             // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 4034;                                                // cover M5 periods of 2 finished W1 bars
   }
   else {
      DeleteInsideBars(PERIOD_W1);                                // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeD1, openTimeW1, pOpenTimeW1, ppOpenTimeW1;
   double high, pHigh, low, pLow;

   for (int i, w1=-1; i < bars; i++) {                            // w1: W1 bar index
      openTimeM5 = ratesM5[i][BAR400_TIME];
      openTimeD1 = openTimeM5 - openTimeM5 % DAY;                 // opentime of the corresponding D1 bar (Midnight)
      int dow    = TimeDayOfWeek(openTimeD1);
      openTimeW1 = openTimeD1 - ((dow+6) % 7) * DAYS;             // opentime of the corresponding W1 bar (Monday 00:00)

      if (openTimeW1 == pOpenTimeW1) {                            // the current H1 bar belongs to the same W1 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
      }
      else {                                                      // the current H1 bar belongs to a new W1 bar
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
         high         = ratesM5[i][BAR400_HIGH];
         low          = ratesM5[i][BAR400_LOW];
      }
   }
   return(true);
}


/**
 * Check rates for MN1 inside bars. Operates on M5 rates as MN1 bars may be unevenly aligned.
 *
 * @param  double ratesM5[][] - M5 rates array
 *
 * @return bool - success status
 */
bool CheckInsideBarsMN1(double ratesM5[][]) {
   int bars = ArrayRange(ratesM5, 0), more;

   if (ChangedBars == 2) {
      if (!IsBarOpen(PERIOD_MN1)) return(!last_error);            // same as changedBars = 1
      more = 1;                                                   // on BarOpen: check the last IB only
      bars = 17858;                                               // cover M5 periods of 2 finished MN1 bars
   }
   else {
      DeleteInsideBars(PERIOD_MN1);                               // on init or data pumping: delete all existing bars
      more = maxInsideBars;                                       // check the configured number of IBs
   }

   datetime openTimeM5, openTimeD1, openTimeMN1, pOpenTimeMN1, ppOpenTimeMN1;
   double high, pHigh, low, pLow;

   for (int i, mn1=-1; i < bars; i++) {                           // mn1: MN1 bar index
      openTimeM5 = ratesM5[i][BAR400_TIME];
      openTimeD1 = openTimeM5 - openTimeM5 % DAY;                 // opentime of the corresponding D1 bar (Midnight)
      openTimeMN1 = openTimeD1 - (TimeDay(openTimeD1)-1) * DAYS;  // opentime of the corresponding MN1 bar (1st of month 00:00)

      if (openTimeMN1 == pOpenTimeMN1) {                          // the current H1 bar belongs to the same MN1 bar
         high = MathMax(ratesM5[i][BAR400_HIGH], high);
         low  = MathMin(ratesM5[i][BAR400_LOW ], low);
      }
      else {                                                      // the current H1 bar belongs to a new MN1 bar
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
         high          = ratesM5[i][BAR400_HIGH];
         low           = ratesM5[i][BAR400_LOW];
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
   int chartOffset = iBarShiftNext(NULL, NULL, openTime);      // offset of the first matching chart bar
   if (chartOffset < 0) return(true);                          // no chart data yet available: skip the inside bar, it will be drawn after chart bars arrived
   chartOpenTime = Time[chartOffset];

   datetime closeTime = openTime + timeframe * MINUTES;
   if (timeframe == PERIOD_MN1) {
      closeTime = openTime + 28 * DAYS;
      while (TimeMonth(openTime) == TimeMonth(closeTime)) {
         closeTime += DAY;
      }
   }
   double   barSize     = (high-low);
   double   longTarget  = NormalizeDouble(high + barSize, Digits);
   double   shortTarget = NormalizeDouble(low  - barSize, Digits);
   string   sOpenTime   = GmtTimeFormat(openTime, "%d.%m.%Y %H:%M");
   string   sTimeframe  = TimeframeDescription(timeframe);
   static int counter = 0; counter++;

   // vertical line at IB open
   string label = StringConcatenate(sTimeframe, " inside bar: ", NumberToStr(high, PriceFormat), "-", NumberToStr(low, PriceFormat), " (", NumberToStr(barSize/pUnit, pUnitFormat), ") [", counter, "]");
   if (ObjectFind(label) != -1) ObjectDelete(label);
   if (ObjectCreateRegister(label, OBJ_TREND, 0, chartOpenTime, longTarget, chartOpenTime, shortTarget)) {
      ObjectSet      (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet      (label, OBJPROP_COLOR, Blue);
      ObjectSet      (label, OBJPROP_RAY,   false);
      ObjectSet      (label, OBJPROP_BACK,  false);// in old builds FALSE, in new builds TRUE (different overlay logic with grid separators)
      ArrayPushString(labels, label);
   }

   // horizontal line at long projection
   label = sTimeframe +" inside bar: +100% = "+ NumberToStr(longTarget, PriceFormat) +" ["+ counter +"]";
   if (ObjectFind(label) != -1) ObjectDelete(label);
   if (ObjectCreateRegister(label, OBJ_TREND, 0, chartOpenTime, longTarget, closeTime, longTarget)) {
      ObjectSet      (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet      (label, OBJPROP_COLOR, Blue);
      ObjectSet      (label, OBJPROP_RAY,   false);
      ObjectSet      (label, OBJPROP_BACK,  true);
      ObjectSetText  (label, " "+ sTimeframe);
      ArrayPushString(labels, label);
   }

   // horizontal line at short projection
   label = sTimeframe +" inside bar: -100% = "+ NumberToStr(shortTarget, PriceFormat) +" ["+ counter +"]";
   if (ObjectFind(label) != -1) ObjectDelete(label);
   if (ObjectCreateRegister(label, OBJ_TREND, 0, chartOpenTime, shortTarget, closeTime, shortTarget)) {
      ObjectSet      (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet      (label, OBJPROP_COLOR, Blue);
      ObjectSet      (label, OBJPROP_RAY,   false);
      ObjectSet      (label, OBJPROP_BACK,  true);
      ArrayPushString(labels, label);
   }

   // signal new inside bars
   if (!__isSuperContext && Signal.onInsideBar) {
      if (IsBarOpen(timeframe)) {
         return(onInsideBar(timeframe, closeTime, high, low));
      }
      if (last_error != 0) {
         return(false);
      }
   }
   return(!catch("CreateInsideBar(1)"));
}


/**
 * Event handler for new inside bars.
 *
 * @param  int      timeframe - inside bar timeframe
 * @param  datetime closeTime - inside bar close time
 * @param  double   high      - inside bar high
 * @param  double   low       - inside bar low
 *
 * @return bool - success status
 */
bool onInsideBar(int timeframe, datetime closeTime, double high, double low) {
   if (!Signal.onInsideBar) return(false);
   if (ChangedBars > 2)     return(false);

   // skip the signal if it was already handled elsewhere
   string sPeriod    = PeriodDescription();
   string sTimeframe = TimeframeDescription(timeframe);
   string eventName  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ WindowExpertName() +".onInsideBar("+ sTimeframe +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1   = sTimeframe +" inside bar (market: "+ NumberToStr(Bid, PriceFormat) +")";
   string message2   = Symbol() +": "+ message1;
   string localTime  = TimeToStr(TimeLocalEx("onInsideBar(1)"), TIME_MINUTES|TIME_SECONDS);
   string alias      = GetAccountAlias();

   int hWndTerminal = GetTerminalMainWindow(), hWndDesktop = GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onInsideBar(2)  "+ message1);
   }

   // sound: once per system
   if (signal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(Signal.SoundFile);
   }

   // alert: once per terminal
   if (signal.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ alias +")");
   }

   // telegram: once per system
   if (signal.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ alias +")");
   }
   return(!catch("onInsideBar(3)"));
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
            if (error != ERR_OBJECT_DOES_NOT_EXIST) return(!catch("DeleteInsideBars(1)->ObjectDelete(label=\""+ labels[i] +"\")", intOr(error, ERR_RUNTIME_ERROR)));
         }
         ArraySpliceStrings(labels, i, 1);
      }
   }
   return(true);
}


/**
 * Create a text label for the indicator status.
 *
 * @return string - created label or an empty string in case of errors
 */
string CreateStatusLabel() {
   string label = "rsf."+ WindowExpertName() +".status["+ __ExecutionContext[EC.pid] +"]";

   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return("");
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 500);            // the SuperBars label starts at xDist=300
   ObjectSet    (label, OBJPROP_YDISTANCE,   3);
   ObjectSetText(label, " ", 1);

   if (!catch("CreateStatusLabel(1)"))
      return(label);
   return("");
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "Timeframe=",                DoubleQuoteStr(Timeframe),                ";", NL,
      "NumberOfInsideBars=",       NumberOfInsideBars,                       ";", NL,

      "Signal.onInsideBar=",       BoolToStr(Signal.onInsideBar),            ";", NL,
      "Signal.onInsideBar.Types=", DoubleQuoteStr(Signal.onInsideBar.Types), ";", NL,
      "Signal.SoundFile=",         DoubleQuoteStr(Signal.SoundFile),         ";"
   ));
}
