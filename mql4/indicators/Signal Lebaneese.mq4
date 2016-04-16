/**
 * Markiert im Chart Entry- und Exit-Signale des Systems "Trend catching with NonLagDot indicator" von Lebaneese.
 *
 * @see  http://www.forexfactory.com/showthread.php?t=571026
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int  Max.Bars = 500;            // how many bars to look back
extern bool Alerts   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#define MODE_MA      MovingAverage.MODE_MA
#define MODE_TREND   MovingAverage.MODE_TREND


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Validierung: Max.Bars
   if (Max.Bars < -1) return(catch("onInit(1)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));

   SetIndexLabel(0, NULL);                   // Datenanzeige ausschalten
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
 *
 */
int onTick() {






   if (CheckNewBar()) {
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

      int dist = 100;     // Distance Arrow is from High or Low

      int i = Max.Bars;

      while (i >= 1) {
         Signal.Short[i] = 0;
         Signal.Long[i] = 0;

         double blue_signal   = iCustom(NULL, NULL, "NonLagMA", MODE_UPTREND, i  );
         double blue_signal_1 = iCustom(NULL, NULL, "NonLagMA", MODE_UPTREND, i+1);

         double red_signal    = iCustom(NULL, NULL, "NonLagMA", MODE_DOWNTREND, i  );
         double red_signal_1  = iCustom(NULL, NULL, "NonLagMA", MODE_DOWNTREND, i+1);

         if (blue_signal!=EMPTY_VALUE) /*&&*/ if (blue_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = true;
            FirstRedSignal  = false;
            Signal.Short[i]         = 0;
         }
         if (red_signal!=EMPTY_VALUE) /*&&*/ if (red_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = false;
            FirstRedSignal  = true;
            Signal.Long[i]         = 0;
         }

         if (FirstBlueSignal) /*&&*/ if (blue_signal!=EMPTY_VALUE) /*&&*/ if (Close[i] < Open[i]) {
            Signal.Long[i]         = Low[i] - dist*Point;
            Signal.Short[i]         = 0;
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
            Signal.Short[i]        = High[i] + dist*Point;
            Signal.Long[i]        = 0;
            FirstRedSignal = false;
            RedHigh        = Low[i];
            RedSignal      = true;
            BlueSignal     = false;
            BlueLow        = 0;

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
            Signal.Long[i]    = Low[i] - dist * Point;
            Signal.Short[i]    = 0;
            BlueLow    = High[i];
            BlueSignal = true;
            RedSignal  = false;
            RedHigh    = 10000;

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
            Signal.Short[i]    = High[i] + dist * Point;
            Signal.Long[i]    = 0;
            RedHigh    = Low[i];
            RedSignal  = true;
            BlueSignal = false;
            BlueLow    = 0;

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