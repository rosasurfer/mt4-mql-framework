//+------------------------------------------------------------------+
//|                           NonLagAlerts_Single_v2.4               |
//|                        Copyright 2016 SmoothTrader               |
//|                                                                  |
//+------------------------------------------------------------------+
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern bool AlertsAndMessages = false;
extern int  dist              = 100;     // Distance Arrow is from High or Low
extern int  BarCount          = 200;     // Set how many bars to look back

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>

#define MODE_MA         MovingAverage.MODE_MA
#define MODE_TREND      MovingAverage.MODE_TREND
#define MODE_UPTREND    2
#define MODE_DOWNTREND  3

#property indicator_chart_window
#property indicator_buffers   2
#property indicator_color1    Blue
#property indicator_color2    Red

double RedHigh;
double BlueLow;
double Buf0[];
double Buf1[];

bool FirstBlueSignal = true;
bool FirstRedSignal  = true;
bool BlueSignal      = false;
bool RedSignal       = false;

datetime opp1, opp2;


/**
 *
 */
int onInit() {
   SetIndexBuffer(0, Buf0);
   SetIndexBuffer(1, Buf1);

   SetIndexStyle (0, DRAW_ARROW, STYLE_SOLID, 3);
   SetIndexStyle (1, DRAW_ARROW, STYLE_SOLID, 3);

   SetIndexArrow (0, 225);
   SetIndexArrow (1, 226);
   return(catch("onInit(1)"));
}


/**
 *
 */
int onTick() {
   if (CheckNewBar()) {
      int    cycleLength         = 20;                                  // Cycle.Length
      string filterVersion       = "4";                                 // Filter.Version
      string drawingType         = "Dot";                               // Drawing.Type
      color  colorUpTrend        = CLR_NONE;                            // Color.UpTrend
      color  colorDownTrend      = CLR_NONE;                            // Color.DownTrend
      int    maxValues           = 1000;                                // Max.Values
      int    shiftVerticalPips   = 0;                                   // Shift.Vertical.Pips
      int    shiftHorizontalBars = 0;                                   // Shift.Horizontal.Bars
      string separator           = "";                                  // ________________
      int    superContext        = GetIntsAddress(__ExecutionContext);  // __SuperContext__

      int i = BarCount;

      while (i >= 1) {
         Buf1[i] = 0;
         Buf0[i] = 0;

         double blue_signal   = iCustom(NULL, NULL, "NonLagMA", cycleLength, filterVersion, drawingType, colorUpTrend, colorDownTrend, maxValues, shiftVerticalPips, shiftHorizontalBars, separator, superContext, MODE_UPTREND, i  );
         double blue_signal_1 = iCustom(NULL, NULL, "NonLagMA", cycleLength, filterVersion, drawingType, colorUpTrend, colorDownTrend, maxValues, shiftVerticalPips, shiftHorizontalBars, separator, superContext, MODE_UPTREND, i+1);

         double red_signal    = iCustom(NULL, NULL, "NonLagMA", cycleLength, filterVersion, drawingType, colorUpTrend, colorDownTrend, maxValues, shiftVerticalPips, shiftHorizontalBars, separator, superContext, MODE_DOWNTREND, i  );
         double red_signal_1  = iCustom(NULL, NULL, "NonLagMA", cycleLength, filterVersion, drawingType, colorUpTrend, colorDownTrend, maxValues, shiftVerticalPips, shiftHorizontalBars, separator, superContext, MODE_DOWNTREND, i+1);

         if (blue_signal!=EMPTY_VALUE) /*&&*/ if (blue_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = true;
            FirstRedSignal  = false;
            Buf1[i]         = 0;
         }
         if (red_signal!=EMPTY_VALUE) /*&&*/ if (red_signal_1==EMPTY_VALUE) {
            FirstBlueSignal = false;
            FirstRedSignal  = true;
            Buf0[i]         = 0;
         }

         if (FirstBlueSignal) /*&&*/ if (blue_signal!=EMPTY_VALUE) /*&&*/ if (Close[i] < Open[i]) {
            Buf0[i]         = Low[i] - dist*Point;
            Buf1[i]         = 0;
            FirstBlueSignal = false;
            BlueLow         = High[i];
            BlueSignal      = true;
            RedSignal       = false;
            RedHigh         = 10000;

            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp1!=Time[0]) {
               opp1 = Time[0];
               Alert("Stop Buy Signal: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }

         if (FirstRedSignal) /*&&*/ if (red_signal!=EMPTY_VALUE) /*&&*/ if (Close[i] > Open[i]) {
            Buf1[i]        = High[i] + dist*Point;
            Buf0[i]        = 0;
            FirstRedSignal = false;
            RedHigh        = Low[i];
            RedSignal      = true;
            BlueSignal     = false;
            BlueLow        = 0;

            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp2!=Time[0]) {
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
            Buf0[i]    = Low[i] - dist * Point;
            Buf1[i]    = 0;
            BlueLow    = High[i];
            BlueSignal = true;
            RedSignal  = false;
            RedHigh    = 10000;

            for (int cnt=i+1; cnt < (i+20); cnt++) {
               if (Buf0[cnt] != 0) {
                  Buf0[cnt] = 0;
                  break;
               }
            }
            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp1!=Time[0]) {
               opp1 = Time[0];
               Alert("Stop Buy Signal moved: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES));
            }
         }

         if (RedSignal) /*&&*/ if (Close[i] > Open[i]) /*&&*/ if (Low[i] > RedHigh) /*&&*/ if (red_signal!=EMPTY_VALUE) {
            Buf1[i]    = High[i] + dist * Point;
            Buf0[i]    = 0;
            RedHigh    = Low[i];
            RedSignal  = true;
            BlueSignal = false;
            BlueLow    = 0;

            for (cnt=i+1; cnt < (i+20); cnt++) {
               if (Buf1[cnt] != 0) {
                  Buf1[cnt] = 0;
                  break;
               }
            }
            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp2!=Time[0]) {
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