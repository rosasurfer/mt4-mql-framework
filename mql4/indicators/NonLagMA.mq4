//+------------------------------------------------------------------+
//|                                                  NonLagMA_v4.mq4 |
//|                                Copyright © 2006, TrendLaboratory |
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |
//|                                   E-mail: igorad2003@yahoo.co.uk |
//+------------------------------------------------------------------+
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int Cycle.Length = 20;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <iFunctions/@ZLMA.mqh>

#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 Yellow
#property indicator_width1 1
#property indicator_color2 RoyalBlue
#property indicator_width2 1
#property indicator_color3 Red
#property indicator_width3 1


double MABuffer[];                              // indicator buffers
double UpBuffer[];
double DnBuffer[];
double trend[];

int    cycles = 4;
int    cycleLength;
int    cycleWindowSize;

double zlma.weights4[];                         // Gewichtungen der einzelnen Bars des ZLMA's
double zlma.weights7[];                         // Gewichtungen der einzelnen Bars des ZLMA's


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   cycleLength     = Cycle.Length;
   cycleWindowSize = cycles*cycleLength + cycleLength-1;

   // Bufferverwaltung
   IndicatorBuffers(4);
   SetIndexBuffer(0, MABuffer);
   SetIndexBuffer(1, UpBuffer);
   SetIndexBuffer(2, DnBuffer);
   SetIndexBuffer(3, trend   );

   // Anzeigeoptionen
   string indicatorName = __NAME__ +"("+ cycleLength +")";
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, indicatorName);
   SetIndexLabel(1, NULL         );
   SetIndexLabel(2, NULL         );
   IndicatorDigits(MarketInfo(Symbol(), MODE_DIGITS));

   SetIndexDrawBegin(0, (cycles+1) * cycleLength);
   SetIndexDrawBegin(1, (cycles+1) * cycleLength);
   SetIndexDrawBegin(2, (cycles+1) * cycleLength);

   // Styles setzen: Workaround um diverse Terminalbugs (siehe dort)
   SetIndicatorStyles();

   // (3) ZLMA-Gewichtungen berechnen
   @ZLMA.CalculateWeights(zlma.weights4, zlma.weights7, cycles, cycleLength);

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


   // (1) Startbar der Berechnung ermitteln
   int startBar = Min(ChangedBars-1, Bars-cycleWindowSize-1);
   if (startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // (2) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      double zlma4=0, zlma7=0;

      // Moving Average
      for (int i=0; i < cycleWindowSize; i++) {
         zlma4 += zlma.weights4[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);
         zlma7 += zlma.weights7[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);
      }
      MABuffer[bar] = zlma4;
      //if (bar>=startBar-10 && bar > 2) debug("onTick()  bar="+ bar +"  zlma4="+ zlma4 +"  zlma7="+ zlma7);


      // Trend aktualisieren
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
