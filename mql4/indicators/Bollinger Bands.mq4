/**
 * Bollinger-Bands-Indikator
 */

#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 C'102,135,232'
#property indicator_color2 C'102,135,232'
#property indicator_color3 C'102,135,232'

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DOT
#property indicator_style3 STYLE_SOLID


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern string BB.Timeframe = "H1";        // zu verwendender Zeitrahmen (M1, M5, M15, M30 etc.)
extern int    BB.Periods   = 75;          // Anzahl der zu verwendenden Perioden
extern int    BB.MA.Method = MODE_SMA;    // MA-Methode (MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA)
extern double BB.Deviation = 2.0;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    period;                                     // Period-ID zu BB.Timeframe

int error = ERR_NO_ERROR;


/**
 *
 */
int init() {
   // Parameter überprüfen
   period = GetPeriod(BB.Timeframe);
   if (period == 0) {
      error = catch("init()  Invalid input parameter BB.Timeframe: \'"+ BB.Timeframe +"\'", ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (BB.Periods < 2) {
      error = catch("init()  Invalid input parameter BB.Periods: "+ BB.Periods, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (BB.MA.Method != MODE_SMA) if (BB.MA.Method != MODE_EMA) if (BB.MA.Method != MODE_SMMA) if (BB.MA.Method != MODE_LWMA) {
      error = catch("init()  Invalid input parameter BB.MA.Method: "+ BB.MA.Method, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (BB.Deviation < 0 || CompareDoubles(BB.Deviation, 0)) {
      error = catch("init()  Invalid input parameter BB.Deviation: "+ BB.Deviation, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }


   // Puffer zuordnen
   SetIndexBuffer(0, UpperBand);
   SetIndexLabel (0, StringConcatenate("UpperBand(", BB.Periods, ")"));
   SetIndexBuffer(1, MovingAvg);
   SetIndexLabel (1, StringConcatenate("MiddleBand(", BB.Periods, ")"));
   SetIndexBuffer(2, LowerBand);
   SetIndexLabel (2, StringConcatenate("LowerBand(", BB.Periods, ")"));
   IndicatorDigits(Digits);


   // während der Entwicklung Puffer jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }


   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 *
 */
int start() {
   // Abbruch bei Parameterfehlern
   if (error != ERR_NO_ERROR)
      return(error);


   int processedBars = IndicatorCounted(),
       iLastIndBar = Bars - BB.Periods,      // Index der letzten Indikator-Bar
       bars,                                 // Anzahl der zu berechnenden Bars
       i, k;

   if (iLastIndBar < 0)                      // im Falle Bars < BB.Period
      iLastIndBar = -1;

   if (iLastIndBar == -1)                        
      return(catch("start(1)"));


   // Anzahl der zu berechnenden Bars bestimmen
   if (processedBars == 0) {
      bars = iLastIndBar + 1;                // alle
   }
   else {                                    // nur fehlende Bars
      bars = Bars - processedBars;
      if (bars > iLastIndBar + 1)
         bars = iLastIndBar + 1;
   }


   // Moving Average berechnen
   for (i=0; i < bars; i++) {
      MovingAvg[i] = iMA(NULL, 0, BB.Periods, 0, BB.MA.Method, PRICE_MEDIAN, i);
   }


   // Bänder berechnen
   double ma, diff, sum, deviation;
   i = bars - 1;

   while (i >= 0) {
      sum = 0;
      ma  = MovingAvg[i];
      k   = i + BB.Periods - 1;

      // TODO: Schleifenergebnisse zwischenspeichern (fast nur redundante Durchläufe)
      while (k >= i) {
         diff = (High[k]+Low[k])/2 - ma;        // PRICE_MEDIAN: (HL)/2 = 
         sum += diff * diff;
         k--;
      }
      deviation    = BB.Deviation * MathSqrt(sum/BB.Periods);
      UpperBand[i] = ma + deviation;
      LowerBand[i] = ma - deviation;
      i--;
   }

   return(catch("start(2)"));
}

