/**
 * Analysiert die History und markiert im Chart Entry- und Exit-Signale des Systems "Trend catching with NonLagDot indicator" von Lebaneese.
 *
 * @see  http://www.forexfactory.com/showthread.php?t=571026
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int  Max.Bars = 100;                        // Höchstanzahl zu analysierender Bars: -1 = keine Begrenzung
extern bool Alerts   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iCustom/icNonLagMA.mqh>

#define MODE_MA      MovingAverage.MODE_MA
#define MODE_TREND   MovingAverage.MODE_TREND

int    maxBars;                                    // Höchstanzahl im Chart zu analysierender Bars

int    nlma.cycles;                                // NonLagMA-Parameter
int    nlma.cycleLength;                           // ...
int    nlma.cycleWindowSize;                       // ...
string nlma.filterVersion;                         // ...
int    nlma.maxValues;                             // ...


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung: Max.Bars
   if (Max.Bars < -1) return(catch("onInit(1)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxBars = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);


   // (2) NonLagMA-Parameter initialisieren
   nlma.cycles          =  4;
   nlma.cycleLength     = 20;
   nlma.cycleWindowSize = nlma.cycles*nlma.cycleLength + nlma.cycleLength-1;
   nlma.filterVersion   = "4";
   nlma.maxValues       = maxBars + 10;            // sicherheitshalber ein paar Bars mehr, damit auch der älteste Trendwechsel korrekt detektiert wird


   SetIndexLabel(0, NULL);                         // Datenanzeige ausschalten
   return(catch("onInit(2)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) Startbar ermitteln
   int bars     = Min(ChangedBars, Max.Bars);
   int startBar = Min(bars-1, Bars-nlma.cycleWindowSize);
   if (startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Fehler setzen, jedoch keine Rückkehr, damit ggf. Legende aktualisiert werden kann
   }

   int    long.retracement       = 0;
   double long.retracement.high;
   double long.retracement.low   = INT_MAX;
   bool   long.signal            = false;

   int    short.retracement      = 0;
   double short.retracement.high = NULL;
   double short.retracement.low;
   bool   short.signal           = false;


   // (2) ungültige Bars neu analysieren
   for (int bar=startBar; bar >= 0; bar--) {
      int trend = icNonLagMA(NULL, nlma.cycleLength, nlma.filterVersion, nlma.maxValues, MODE_TREND, bar);

      if (trend > 0) {
         short.retracement = 0;
         if (trend >= 2) {
            if (long.retracement!=0) {
               // looking for a retracement break
               //if (signal) {
               //   long.signal = true;
               //   continue;
               //}
            }
            // no break, looking for further long retracements
            if (LT(Close[bar], Open[bar], Digits)) {
               if (LT(Low[bar], long.retracement.low, Digits)) {
                  long.retracement++;
                  long.retracement.high = High[bar];
                  long.retracement.low  = Low [bar];
                  debug("onTick(2)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  long.retracement ="+ StringPadRight(long.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
               }
            }
         }
      }
      else if (trend < 0) {
         long.retracement = 0;
         if (trend <= -2) {
            if (short.retracement!=0) {
               // looking for a retracement break
               //if (signal) {
               //   short.signal = true;
               //   continue;
               //}
            }
            // no break, looking for further short retracements
            if (GT(Close[bar], Open[bar], Digits)) {
               if (GT(High[bar], short.retracement.high, Digits)) {
                  short.retracement++;
                  short.retracement.high = High[bar];
                  short.retracement.low  = Low [bar];
                  debug("onTick(3)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  short.retracement="+ StringPadRight(short.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
               }
            }
         }
      }
   }

   return(catch("onTick(8)"));




   if (false && CheckNewBar()) {
      #define MODE_UPTREND    2
      #define MODE_DOWNTREND  3

      bool     FirstBlueSignal = true;
      bool     FirstRedSignal  = true;
      bool     BlueSignal      = false;
      bool     RedSignal       = false;
      double   RedHigh;
      double   BlueLow;
      datetime opp1;
      datetime opp2;

      double   Signal.Long [];
      double   Signal.Short[];

      int i = maxBars;

      while (i >= 1) {
         Signal.Short[i] = 0;
         Signal.Long [i] = 0;

         double blue_signal   = iCustom(NULL, NULL, "NonLagMA", MODE_UPTREND, i  );
         double blue_signal_1 = iCustom(NULL, NULL, "NonLagMA", MODE_UPTREND, i+1);

         double red_signal    = iCustom(NULL, NULL, "NonLagMA", MODE_DOWNTREND, i  );
         double red_signal_1  = iCustom(NULL, NULL, "NonLagMA", MODE_DOWNTREND, i+1);

         if (blue_signal!=EMPTY_VALUE) /*&&*/ if (blue_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = true;
            FirstRedSignal  = false;
            Signal.Short[i] = 0;
         }
         if (red_signal!=EMPTY_VALUE) /*&&*/ if (red_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = false;
            FirstRedSignal  = true;
            Signal.Long[i]  = 0;
         }

         if (FirstBlueSignal) /*&&*/ if (blue_signal!=EMPTY_VALUE) /*&&*/ if (Close[i] < Open[i]) {
            Signal.Long [i] = Low[i] - 10*Pips;
            Signal.Short[i] = 0;
            FirstBlueSignal = false;
            BlueLow         = High[i];
            BlueSignal      = true;
            RedSignal       = false;
            RedHigh         = 10000;

            if (Alerts) /*&&*/ if (i==1) /*&&*/ if (opp1!=Time[0]) {
               opp1 = Time[0];
               Alert("Stop Buy Signal: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }

         if (FirstRedSignal) /*&&*/ if (red_signal!=EMPTY_VALUE) /*&&*/ if (Close[i] > Open[i]) {
            Signal.Short[i] = High[i] + 10*Pips;
            Signal.Long [i] = 0;
            FirstRedSignal  = false;
            RedHigh         = Low[i];
            RedSignal       = true;
            BlueSignal      = false;
            BlueLow         = 0;

            if (Alerts) /*&&*/ if (i==1) /*&&*/ if (opp2!=Time[0]) {
               opp2 = Time[0];
               Alert("Stop Sell Signal: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }

         if (BlueSignal) /*&&*/ if (High[i] > BlueLow) {
            BlueSignal = false;
            BlueLow    = 0;
         }
         if (RedSignal) /*&&*/ if (Low[i] < RedHigh) {
            RedSignal = false;
            RedHigh   = 10000;
         }
         if (BlueSignal) /*&&*/ if (Close[i] < Open[i]) /*&&*/ if (High[i] < BlueLow) /*&&*/ if (blue_signal!=EMPTY_VALUE) {
            Signal.Long [i] = Low[i] - 10*Pips;
            Signal.Short[i] = 0;
            BlueLow         = High[i];
            BlueSignal      = true;
            RedSignal       = false;
            RedHigh         = 10000;

            for (int cnt=i+1; cnt < (i+20); cnt++) {
               if (Signal.Long[cnt] != 0) {
                  Signal.Long[cnt] = 0;
                  break;
               }
            }
            if (Alerts) /*&&*/ if (i==1) /*&&*/ if (opp1!=Time[0]) {
               opp1 = Time[0];
               Alert("Stop Buy Signal moved: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }

         if (RedSignal) /*&&*/ if (Close[i] > Open[i]) /*&&*/ if (Low[i] > RedHigh) /*&&*/ if (red_signal!=EMPTY_VALUE) {
            Signal.Short[i] = High[i] + 10*Pips;
            Signal.Long [i] = 0;
            RedHigh         = Low[i];
            RedSignal       = true;
            BlueSignal      = false;
            BlueLow         = 0;

            for (cnt=i+1; cnt < (i+20); cnt++) {
               if (Signal.Short[cnt] != 0) {
                  Signal.Short[cnt] = 0;
                  break;
               }
            }
            if (Alerts) /*&&*/ if (i==1) /*&&*/ if (opp2!=Time[0]) {
               opp2 = Time[0];
               Alert("Stop Sell Signal moved: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }
         i--;
      }
   }
   return(catch("onTick(1)"));
}


/**
 *
 */
bool CheckNewBar() {
   // Non-sense
   static datetime lastTime = 0;
   bool result = (Time[0] != lastTime);
   lastTime = Time[0];
   return(result);
}