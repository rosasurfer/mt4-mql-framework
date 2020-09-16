/**
 * Pivot levels
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods          = 2;                      // number of periods to display
extern int    SR.Levels        = 3;                      // number of SR levels per side to display
//     string Timeframe        = "D";                    // pivot timeframe: D1 | W1 | MN

extern color  Color.Resistance = Blue;
extern color  Color.Main       = LimeGreen;
extern color  Color.Support    = Red;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>

#define MODE_R3               0                          // indicator buffer ids
#define MODE_R2               1
#define MODE_R1               2
#define MODE_PP               3
#define MODE_S1               4
#define MODE_S2               5
#define MODE_S3               6

#property indicator_chart_window
#property indicator_buffers   7

#property indicator_width1    1
#property indicator_width2    1
#property indicator_width3    1
#property indicator_width4    2
#property indicator_width5    1
#property indicator_width6    1
#property indicator_width7    1


double R3[], R2[], R1[], PP[], S1[], S2[], S3[];         // display buffers

int pivotPeriods;
int srLevels;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // Periods
   if (Periods < 0)   return(catch("onInit(1)  Invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   pivotPeriods = Periods;

   if (SR.Levels < 0) return(catch("onInit(2)  Invalid input parameter SR.Levels: "+ SR.Levels, ERR_INVALID_INPUT_PARAMETER));
   if (SR.Levels > 3) return(catch("onInit(3)  Invalid input parameter SR.Levels: "+ SR.Levels, ERR_INVALID_INPUT_PARAMETER));
   srLevels = SR.Levels;

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.Resistance == 0xFF000000) Color.Resistance = CLR_NONE;
   if (Color.Main       == 0xFF000000) Color.Main       = CLR_NONE;
   if (Color.Support    == 0xFF000000) Color.Support    = CLR_NONE;

   // (2) indicator buffer management
   SetIndexBuffer(MODE_R3, R3); SetIndexLabel(MODE_R3, NULL);
   SetIndexBuffer(MODE_R2, R2); SetIndexLabel(MODE_R2, NULL);
   SetIndexBuffer(MODE_R1, R1); SetIndexLabel(MODE_R1, NULL);
   SetIndexBuffer(MODE_PP, PP); SetIndexLabel(MODE_PP, NULL);
   SetIndexBuffer(MODE_S1, S1); SetIndexLabel(MODE_S1, NULL);
   SetIndexBuffer(MODE_S2, S2); SetIndexLabel(MODE_S2, NULL);
   SetIndexBuffer(MODE_S3, S3); SetIndexLabel(MODE_S3, NULL);

   SetIndicatorOptions();
   return(catch("onInit(4)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(R3)) return(logInfo("onTick(1)  size(R3) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(R3, EMPTY_VALUE);
      ArrayInitialize(R2, EMPTY_VALUE);
      ArrayInitialize(R1, EMPTY_VALUE);
      ArrayInitialize(PP, EMPTY_VALUE);
      ArrayInitialize(S1, EMPTY_VALUE);
      ArrayInitialize(S2, EMPTY_VALUE);
      ArrayInitialize(S3, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(R3, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(R2, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(R1, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(PP, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(S1, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(S2, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(S3, Bars, ShiftedBars, EMPTY_VALUE);
   }



   // Pivot levels
   iPivotLevel();
   return(last_error);

   double dNull[];
   iPivotLevel_new(NULL, NULL, dNull);
}


/**
 *
 */
int iPivotLevel() {
   int size, time, lastTime;
   int endBars[]; ArrayResize(endBars, 0);   // Endbars der jeweiligen Sessions

   // Die Endbars der Sessions werden noch aus dem aktuellen Chart ausgelesen (funktioniert nur bis PERIOD_H1).
   for (int i=0; i < Bars; i++) {
      time = TimeHour(Time[i]) * HOURS + TimeMinute(Time[i]) * MINUTES + TimeSeconds(Time[i]);   // Sekunden seit Mitternacht
      if (i == 0)
         lastTime = time;

      if (time < 23 * HOURS) {               // 00:00 bis 23:00
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
            if (size > Periods)
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
         if (SR.Levels > 0) {
            R3[n] = r3;
            R2[n] = r2;
            R1[n] = r1;
            S1[n] = s1;
            S2[n] = s2;
            S3[n] = s3;
         }
      }
   }
   return(catch("iPivotLevel(1)"));
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
int iPivotLevel_new(datetime time, int period/*=NULL*/, double &results[]) {
   if (ArraySize(results) != 7)
      return(catch("iPivotLevel_new(1)   invalid parameter results["+ ArrayRange(results, 0) +"]", ERR_INCOMPATIBLE_ARRAYS));

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
         return(catch("iPivotLevel_new(2)   invalid parameter period: "+ period, ERR_INVALID_PARAMETER));
   }

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
   results[MODE_R3] = R3;
   results[MODE_R2] = R2;
   results[MODE_R1] = R1;
   results[MODE_PP] = PP;
   results[MODE_S1] = S1;
   results[MODE_S2] = S2;
   results[MODE_S3] = S3;

   return(catch("iPivotLevel_new(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   SetIndexStyle(MODE_R3, ifInt(srLevels>=3, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Resistance);
   SetIndexStyle(MODE_R2, ifInt(srLevels>=2, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Resistance);
   SetIndexStyle(MODE_R1, ifInt(srLevels>=1, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Resistance);
   SetIndexStyle(MODE_PP,                    DRAW_LINE,             EMPTY, EMPTY, Color.Main      );
   SetIndexStyle(MODE_S1, ifInt(srLevels>=1, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Support   );
   SetIndexStyle(MODE_S2, ifInt(srLevels>=2, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Support   );
   SetIndexStyle(MODE_S3, ifInt(srLevels>=3, DRAW_LINE, DRAW_NONE), EMPTY, EMPTY, Color.Support   );
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = NAME();
   Chart.StoreInt   (name +".input.Periods",          Periods         );
   Chart.StoreInt   (name +".input.SR.Levels",        SR.Levels       );
   Chart.StoreColor (name +".input.Color.Resistance", Color.Resistance);
   Chart.StoreColor (name +".input.Color.Main",       Color.Main      );
   Chart.StoreColor (name +".input.Color.Support",    Color.Support   );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = NAME();
   Chart.RestoreInt  (name +".input.Periods",          Periods         );
   Chart.RestoreInt  (name +".input.SR.Levels",        SR.Levels       );
   Chart.RestoreColor(name +".input.Color.Resistance", Color.Resistance);
   Chart.RestoreColor(name +".input.Color.Main",       Color.Main      );
   Chart.RestoreColor(name +".input.Color.Support",    Color.Support   );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",          Periods,   ";",                    NL,
                            "SR.Levels=",        SR.Levels, ";",                    NL,
                            "Color.Resistance=", ColorToStr(Color.Resistance), ";", NL,
                            "Color.Main=",       ColorToStr(Color.Main),       ";", NL,
                            "Color.Support=",    ColorToStr(Color.Support),    ";")
   );
}
