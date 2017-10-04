/**
 * Pivot-Level
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int    PivotPeriods        = 1;                   // Anzahl der anzuzeigenden Perioden
extern string PivotTimeframe      = "D";                 // Pivotlevel-Timeframe [D(aily) | W(eekly) | M(onthly)]
extern bool   Show.SR.Level       = true;                // Anzeige der Support-/Resistance-Level
extern bool   Show.Next.Pivot     = false;               // Anzeige des vorausberechneten Pivot-Points der nächsten Periode
extern bool   Show.HigherTF.Pivot = false;               // Anzeige des Pivot-Points des nächsthöheren Timeframes

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>

#property indicator_buffers 7

#property indicator_color1  Blue
#property indicator_color2  Blue
#property indicator_color3  Blue
#property indicator_color4  Green
#property indicator_width4  2
#property indicator_color5  Red
#property indicator_color6  Red
#property indicator_color7  Red

double R3[], R2[], R1[], PP[], S1[], S2[], S3[];         // Pivotlevel-Puffer
int    iPivotTimeframe;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // ERS_TERMINAL_NOT_READY abfangen
   if (!GetAccountNumber()) return(last_error);

   // Puffer zuordnen
   SetIndexBuffer(0, R3);
   SetIndexBuffer(1, R2);
   SetIndexBuffer(2, R1);
   SetIndexBuffer(3, PP);
   SetIndexBuffer(4, S1);
   SetIndexBuffer(5, S2);
   SetIndexBuffer(6, S3);

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   SetIndexLabel(3, NULL);
   SetIndexLabel(4, NULL);
   SetIndexLabel(5, NULL);
   SetIndexLabel(6, NULL);

   // Konfiguration auswerten
   if (PivotPeriods < 0) return(catch("onInit(1)   Invalid input parameter PivotPeriods: "+ PivotPeriods, ERR_INVALID_INPUT_PARAMETER));

   if (!PivotPeriods)
      Show.SR.Level = false;

   if      (PivotTimeframe == "D") iPivotTimeframe = PERIOD_D1;
   else if (PivotTimeframe == "W") iPivotTimeframe = PERIOD_W1;
   else if (PivotTimeframe == "M") iPivotTimeframe = PERIOD_MN1;
   else                  return(catch("onInit(2)   Invalid input parameter PivotTimeframe = \""+ PivotTimeframe +"\"", ERR_INVALID_INPUT_PARAMETER));

   return(catch("onInit(3)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(R3) == 0)                                           // kann bei Terminal-Start auftreten
      return(debug("onTick(1)  size(R3) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor kompletter Neuberechnung Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(R3, EMPTY_VALUE);
      ArrayInitialize(R2, EMPTY_VALUE);
      ArrayInitialize(R1, EMPTY_VALUE);
      ArrayInitialize(PP, EMPTY_VALUE);
      ArrayInitialize(S1, EMPTY_VALUE);
      ArrayInitialize(S2, EMPTY_VALUE);
      ArrayInitialize(S3, EMPTY_VALUE);
   }

   // Pivot levels
   iPivotLevel_alt();

   return(last_error);
}


/**
 * Berechnet die Pivotlevel des aktuellen Instruments zum angegebenen Zeitpunkt.
 *
 * @param  datetime time      - Zeitpunkt der zu berechnenden Werte
 * @param  int      period    - Pivot-Periode: PERIOD_M1 | PERIOD_M5 | PERIOD_M15... (default: aktuelle Periode)
 * @param  double   results[] - Ergebnis-Array
 *
 * @return int - Fehlerstatus
 */
int iPivotLevel(datetime time, int period/*=NULL*/, double &results[]) {
   if (ArraySize(results) != 7)
      return(catch("iPivotLevel(1)   invalid parameter results["+ ArrayRange(results, 0) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int startBar, endBar, highBar, lowBar, closeBar;

   if (!period)
      period = PERIOD_D1;


   // Start- und Endbar der vorangegangenen Periode ermitteln
   switch (period) {
      case PERIOD_D1:
         if (Period() <= PERIOD_H1) period = Period();                     // zur Berechnung wird nach Möglichkeit die Chartperiode verwendet,
         else                       period = PERIOD_H1;                    // um ERS_HISTORY_UPDATE zu vermeiden

         // Start- und Endbar der vorangegangenen Session ermitteln
         datetime endTime = GetPrevSessionEndTime.srv(time);
         endBar   = iBarShiftPrevious(NULL, period, endTime-1*SECOND);     // TODO: endBar kann WE-Bar sein
         startBar = iBarShiftNext(NULL, period, GetSessionStartTime.srv(iTime(NULL, period, endBar)));
         break;                                                            // TODO: iBarShift() und iTime() auf ERS_HISTORY_UPDATE prüfen

      default:
         return(catch("iPivotLevel(2)   invalid parameter period: "+ period, ERR_INVALID_PARAMETER));
   }
   //debug("iPivotLevel() for '"+ TimeToStr(time) +"'   start bar: '"+ TimeToStr(iTime(NULL, period, startBar)) +"'   end bar: '"+ TimeToStr(iTime(NULL, period, endBar)) +"'");


   // Barpositionen von H-L-C bestimmen
   if (startBar == endBar) {
      highBar = startBar;
      lowBar  = startBar;
   }
   else {
      highBar = iHighest(NULL, period, MODE_HIGH, startBar-endBar, endBar);
      lowBar  = iLowest (NULL, period, MODE_LOW , startBar-endBar, endBar);
   }
   closeBar = endBar;


   // H-L-C ermitteln
   double H = iHigh (NULL, period, highBar ),
          L = iLow  (NULL, period, lowBar  ),
          C = iClose(NULL, period, closeBar);


   // Pivotlevel berechnen
   double PP = (H + L + C)/3,          // Pivot   aka Typical-Price
          R1 = 2 * PP - L,             // Pivot + Previous-Low-Distance
          R2 = PP + (H - L),           // Pivot + Previous-Range
          R3 = R1 + (H - L),           // R1    + Previous-Range
          S1 = 2 * PP - H,
          S2 = PP - (H - L),
          S3 = S1 - (H - L);


   // Ergebnisse in Zielarray schreiben
   results[PIVOT_R3] = R3;
   results[PIVOT_R2] = R2;
   results[PIVOT_R1] = R1;
   results[PIVOT_PP] = PP;
   results[PIVOT_S1] = S1;
   results[PIVOT_S2] = S2;
   results[PIVOT_S3] = S3;

   //debug("iPivotLevel() for '"+ TimeToStr(time) +"'   R3: "+ DoubleToStr(R3, Digits) +"   R2: "+ DoubleToStr(R2, Digits) +"   R1: "+ DoubleToStr(R1, Digits) +"   PP: "+ DoubleToStr(PP, Digits) +"   S1: "+ DoubleToStr(S1, Digits) +"   S2: "+ DoubleToStr(S2, Digits) +"   S3: "+ DoubleToStr(S3, Digits));
   return(catch("iPivotLevel(3)"));
}


/**
 *
 */
int iPivotLevel_alt() {
   int size, time, lastTime;
   int endBars[]; ArrayResize(endBars, 0);   // Endbars der jeweiligen Sessions

   // Die Endbars der Sessions werden noch aus dem aktuellen Chart ausgelesen (funktioniert nur bis PERIOD_H1).
   for (int i=0; i < Bars; i++) {
      time = TimeHour(Time[i]) * HOURS + TimeMinute(Time[i]) * MINUTES + TimeSeconds(Time[i]);   // Sekunden seit Mitternacht
      if (i == 0)
         lastTime = time;

      if (time < 23 * HOURS) {   // 00:00 bis 23:00
         bool resize = false;
         if (lastTime >= 23 * HOURS)
            resize = true;

         if (i > 0) {
            if (TimeDayOfYear(Time[i]) != TimeDayOfYear(Time[i-1]))
               resize = true;
         }

         if (resize) {
            size = ArrayResize(endBars, size+1);
            endBars[size-1] = i;
            if (size > PivotPeriods)
               break;
         }
      }
      lastTime = time;
   }

   // Für jede Session H-L-C ermitteln, Pivots berechnen und einzeichnen
   int    highBar, lowBar, closeBar;
   double H, L, C, r3, r2, r1, pp, s1, s2, s3;

   for (i=0; i < size-1; i++) {
      // Positionen von H-L-C bestimmen
      closeBar = endBars[i];
      highBar  = iHighest(NULL, NULL, MODE_HIGH, endBars[i+1]-closeBar, closeBar);
      lowBar   = iLowest (NULL, NULL, MODE_LOW , endBars[i+1]-closeBar, closeBar);

      H = iHigh (NULL, NULL, highBar );
      L = iLow  (NULL, NULL, lowBar  );
      C = iClose(NULL, NULL, closeBar);

      // Pivotlevel berechnen
      pp = (H + L + C)/3;
      r1 = 2 * pp - L;
      r2 = pp + (H - L);
      r3 = r1 + (H - L);
      s1 = 2 * pp - H;
      s2 = pp - (H - L);
      s3 = s1 - (H - L);

      // berechnete Werte in Anzeigebuffer schreiben
      int n = 0;
      if (i > 0)
         n = endBars[i-1];
      for (; n < closeBar; n++) {
         PP[n] = pp;
         if (Show.SR.Level) {
            R3[n] = r3;
            R2[n] = r2;
            R1[n] = r1;
            S1[n] = s1;
            S2[n] = s2;
            S3[n] = s3;
         }
      }
   }

   return(catch("iPivotLevel_alt()"));
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   double dNulls[];
   iPivotLevel(NULL, NULL, dNulls);
   iPivotLevel_alt();
}
