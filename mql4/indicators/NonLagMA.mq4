//+------------------------------------------------------------------+
//|                                                  NonLagDOT.mq4 |
//|                                Copyright © 2006, TrendLaboratory |
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |
//|                                   E-mail: igorad2003@yahoo.co.uk |
//+------------------------------------------------------------------+
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int MA.Periods = 20;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>

#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 Yellow
#property indicator_width1 1
#property indicator_color2 RoyalBlue
#property indicator_width2 1
#property indicator_color3 Red
#property indicator_width3 1


double MABuffer[];         // indicator buffers
double UpBuffer[];
double DnBuffer[];
double trend[];

int    Cycles = 4;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Bufferverwaltung
   IndicatorBuffers(4);
   SetIndexBuffer(0, MABuffer);
   SetIndexBuffer(1, UpBuffer);
   SetIndexBuffer(2, DnBuffer);
   SetIndexBuffer(3, trend   );

   // Anzeigeoptionen
   string indicatorName = __NAME__ +"("+ MA.Periods +")";
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, indicatorName);
   SetIndexLabel(1, NULL         );
   SetIndexLabel(2, NULL         );
   IndicatorDigits(MarketInfo(Symbol(), MODE_DIGITS));

   SetIndexDrawBegin(0, (Cycles+1) * MA.Periods);
   SetIndexDrawBegin(1, (Cycles+1) * MA.Periods);
   SetIndexDrawBegin(2, (Cycles+1) * MA.Periods);

   // Styles setzen: Workaround um diverse Terminalbugs (siehe dort)
   SetIndicatorStyles();
   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(MABuffer) == 0)                                        // kann bei Terminal-Start auftreten
      return(debug("onTick(1)  size(MABuffer) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor kompletter Neuberechnung Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(MABuffer, EMPTY_VALUE);
      ArrayInitialize(UpBuffer, EMPTY_VALUE);
      ArrayInitialize(DnBuffer, EMPTY_VALUE);
      ArrayInitialize(trend,              0);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   double alpha, t, g, Weight, Sum;
   double Coeff = 3 * Math.PI;
   int    Phase = MA.Periods - 1;
   int    Len   = Cycles*MA.Periods + Phase;

   int startBar = Min(ChangedBars-1, Bars-Len-1);
   if (startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }

   for (int bar=startBar; bar >= 0; bar--) {
      Weight=0; Sum=0; t=0;

      for (int i=0; i <= Len-1; i++) {
         g = 1/(t*Coeff + 1);
         if (t <= 0.5)
            g = 1;
         alpha = g * MathCos(t * Math.PI);

         Weight += alpha;
         Sum    += alpha * iMA(NULL, 0, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);

         if      (t < 1)     t +=  1./(Phase-1);
         else if (t < Len-1) t += (2.*Cycles-1)/(MA.Periods*Cycles-1);
      }
      if (Weight != 0) MABuffer[bar] = Sum/Weight;

      trend[bar] = trend[bar+1];

      if (MABuffer[bar]-MABuffer[bar+1] > 0) {
         trend   [bar] = 1;
         UpBuffer[bar] = MABuffer[bar];
         DnBuffer[bar] = 0;
      }
      if (MABuffer[bar]-MABuffer[bar+1] < 0) {
         trend   [bar] = -1;
         UpBuffer[bar] = 0;
         DnBuffer[bar] = MABuffer[bar];
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompilation), die erfordern, daß die Styles
 * in der Regel in init(), nach Recompilation jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexStyle(2, DRAW_ARROW);

   SetIndexArrow(0, 159);
   SetIndexArrow(1, 159);
   SetIndexArrow(2, 159);
}
