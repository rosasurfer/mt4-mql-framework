/**
 * ALMA-MACD
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int Fast.ALMA.Periods =   38;
extern int Slow.ALMA.Periods =  240;
extern int Max.Values        = 2000;                                 // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@ALMA.mqh>

#property indicator_separate_window

#property indicator_buffers 3

#property indicator_width1  1
#property indicator_width2  0
#property indicator_width3  0

#property indicator_color1  Blue


double bufferMACD    [];
double bufferFastALMA[];
double bufferSlowALMA[];

double fast.alma.weights[];                                          // Gewichtungen der einzelnen Bars des ALMA's
double slow.alma.weights[];                                          // Gewichtungen der einzelnen Bars des ALMA's


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // ALMA-Gewichtungen berechnen
   @ALMA.CalculateWeights(fast.alma.weights, Fast.ALMA.Periods);
   @ALMA.CalculateWeights(slow.alma.weights, Slow.ALMA.Periods);

   // Bufferverwaltung
   SetIndexBuffer(0, bufferMACD    );
   SetIndexBuffer(1, bufferFastALMA);
   SetIndexBuffer(2, bufferSlowALMA);

   // Anzeigeoptionen
   string macd.shortName = "ALMACD("+ Fast.ALMA.Periods +","+ Slow.ALMA.Periods +")";
   SetIndexLabel(0, macd.shortName);                                // Tooltip und "Data Window"
   SetIndexLabel(1, NULL          );
   SetIndexLabel(2, NULL          );

   IndicatorShortName(macd.shortName);                               // Context Menu
   IndicatorDigits(2);
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen (size=0 kann bei Terminal-Start auftreten)
   if (!ArraySize(bufferMACD)) return(debug("onTick(1)  size(bufferMACD) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor kompletter Neuberechnung Buffer zurücksetzen (löscht Garbage hinter MaxValues)
   if (!ValidBars) {
      ArrayInitialize(bufferMACD,     EMPTY_VALUE);
      ArrayInitialize(bufferFastALMA, EMPTY_VALUE);
      ArrayInitialize(bufferSlowALMA, EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }


   // (1) IndicatorBuffer entsprechend ShiftedBars synchronisieren
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMACD,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferFastALMA, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferSlowALMA, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (2) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-Slow.ALMA.Periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // (3) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      bufferFastALMA[bar] = 0;
      for (int i=0; i < Fast.ALMA.Periods; i++) {
         bufferFastALMA[bar] += fast.alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);
      }

      bufferSlowALMA[bar] = 0;
      for (i=0; i < Slow.ALMA.Periods; i++) {
         bufferSlowALMA[bar] += slow.alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);
      }

      bufferMACD[bar] = (bufferFastALMA[bar] - bufferSlowALMA[bar])/Pips;
   }
   return(last_error);
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompilation), die erfordern, daß die Styles
 * in der Regel in init(), nach Recompilation jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Blue    );
   SetIndexStyle(1, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexStyle(2, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
}
