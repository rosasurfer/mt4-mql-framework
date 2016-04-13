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
bool NewBar;

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
   CheckNewBar();

   if (NewBar == true) {
      int i = BarCount;

      while (i >=1) {
         Buf1[i] = 0;
         Buf0[i] = 0;
         double blue_signal = iCustom(NULL, 0, "NonLagMA", 1, i);
         double red_signal  = iCustom(NULL, 0, "NonLagMA", 2, i);

         if (blue_signal > 0) /*&&*/ if (iCustom(NULL, 0, "NonLagMA", 1, i+1)==0) {
            FirstBlueSignal = true;
            FirstRedSignal  = false;
            Buf1[i]         = 0;
         }
         if (red_signal > 0) /*&&*/ if (iCustom(NULL, 0, "NonLagMA", 2, i+1)==0) {
            FirstBlueSignal = false;
            FirstRedSignal  = true;
            Buf0[i]         = 0;
         }

         if (FirstBlueSignal) /*&&*/ if (blue_signal > 0) /*&&*/ if (Close[i] < Open[i]) {
            Buf0[i]         = Low[i] - dist*Point;
            Buf1[i]         = 0;
            FirstBlueSignal = false;
            BlueLow         = High[i];
            BlueSignal      = true;
            RedSignal       = false;
            RedHigh         = 10000;

            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp1!=Time[0]) {
               opp1 = Time[0];
               string msg = "Stop Buy Signal: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES);
               Alert(msg);
               //SendNotification(msg);
               //SendMail("NonLagMA Signal", msg);
            }
         }

         if (FirstRedSignal) /*&&*/ if (red_signal > 0) /*&&*/ if (Close[i] > Open[i]) {
            Buf1[i]        = High[i] + dist*Point;
            Buf0[i]        = 0;
            FirstRedSignal = false;
            RedHigh        = Low[i];
            RedSignal      = true;
            BlueSignal     = false;
            BlueLow        = 0;

            if (AlertsAndMessages) /*&&*/ if (i==1) /*&&*/ if (opp2!=Time[0]) {
               opp2 = Time[0];
               msg = "Stop Sell Signal: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES);
               Alert(msg);
               //SendNotification(msg);
               //SendMail("NonLagMA Signal", msg);
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
         if (BlueSignal) /*&&*/ if (Close[i] < Open[i]) /*&&*/ if (High[i] < BlueLow) /*&&*/ if (blue_signal > 0) {
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
               msg = "Stop Buy Signal moved: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES);
               Alert(msg);
               //SendNotification(msg);
               //SendMail("NonLagMA Signal", msg);
            }
         }

         if (RedSignal) /*&&*/ if (Close[i] > Open[i]) /*&&*/ if (Low[i] > RedHigh) /*&&*/ if (red_signal > 0) {
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
               msg = "Stop Sell Signal moved: "+ Symbol() +" - "+ Period() +"min at "+ TimeToStr(TimeCurrent(), TIME_MINUTES);
               Alert(msg);
               //SendNotification(msg);
               //SendMail("NonLagMA Signal", msg);
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
void CheckNewBar() {
   static datetime NewTime = 0;
   NewBar = false;
   if (NewTime != Time[0]) {
      NewTime = Time[0];
      NewBar = true;
   }
}