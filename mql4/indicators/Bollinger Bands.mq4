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

extern string Timeframe      = "H1";         // zu verwendender Zeitrahmen (M1, M5, M15, M30 etc.)
extern int    Periods        = 75;           // Anzahl der zu verwendenden Perioden
extern double Deviation      = 2.0;          // Standardabweichung
extern int    MA.Method      = MODE_SMA;     // MA-Methode, siehe MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA
extern string MA.Method.Help = "0: SMA, 1: EMA, 2: SMMA, 3: LWMA";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    period;                                     // Period-ID zu Timeframe

int error = ERR_NO_ERROR;


/**
 *
 */
int init() {
   // Parameter überprüfen
   period = GetPeriod(Timeframe);
   if (period == 0) {
      error = catch("init()  Invalid input parameter Timeframe: \'"+ Timeframe +"\'", ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (Periods < 2) {
      error = catch("init()  Invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (Deviation < 0 || CompareDoubles(Deviation, 0)) {
      error = catch("init()  Invalid input parameter Deviation: "+ Deviation, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   if (MA.Method != MODE_SMA) if (MA.Method != MODE_EMA) if (MA.Method != MODE_SMMA) if (MA.Method != MODE_LWMA) {
      error = catch("init()  Invalid input parameter MA.Method: "+ MA.Method, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }


   // Puffer zuordnen
   SetIndexBuffer(0, UpperBand);
   SetIndexLabel (0, StringConcatenate("UpperBand(", Periods, "x", Timeframe, ")"));
   SetIndexBuffer(1, MovingAvg);
   SetIndexLabel (1, StringConcatenate("MiddleBand(", Periods, "x", Timeframe, ")"));
   SetIndexBuffer(2, LowerBand);
   SetIndexLabel (2, StringConcatenate("LowerBand(", Periods, "x", Timeframe, ")"));
   IndicatorDigits(Digits);


   // während der Entwicklung Puffer jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }


   // Periodenparameter in aktuellen Zeitrahmen umrechnen
   if (Period() != period) {
      double minutes = period * Periods;           // Timeframe * Anzahl Bars = Range in Minuten
      Periods = MathRound(minutes / Period());
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
   if (error != ERR_NO_ERROR) return(error);    // Abbruch bei Parameterfehlern ...
   if (Periods < 2)           return(0);        // und bei Periods < 2 (möglich bei Umschalten auf größeren Timeframe)
     

   int processedBars = IndicatorCounted(),
       iLastIndBar = Bars - Periods,            // Index der letzten Indikator-Bar
       bars,                                    // Anzahl der zu berechnenden Bars
       i, k;

   if (iLastIndBar < 0)                         // im Falle Bars < Periods
      iLastIndBar = -1;

   if (iLastIndBar == -1)                        
      return(catch("start(1)"));


   // Anzahl der zu berechnenden Bars bestimmen
   if (processedBars == 0) {
      bars = iLastIndBar + 1;                   // alle
   }
   else {                                       // nur die fehlenden Bars
      bars = Bars - processedBars;
      if (bars > iLastIndBar + 1)
         bars = iLastIndBar + 1;
   }


   // Moving Average berechnen
   for (i=0; i < bars; i++) {
      MovingAvg[i] = iMA(NULL, 0, Periods, 0, MA.Method, PRICE_MEDIAN, i);
   }


   // Bänder berechnen
   double ma, diff, sum, deviation;
   i = bars - 1;

   while (i >= 0) {
      sum = 0;
      ma  = MovingAvg[i];
      k   = i + Periods - 1;

      // TODO: Schleifenergebnisse zwischenspeichern (fast nur redundante Durchläufe)
      while (k >= i) {
         diff = (High[k]+Low[k])/2 - ma;        // PRICE_MEDIAN: (HL)/2 = 
         sum += diff * diff;
         k--;
      }
      deviation    = Deviation * MathSqrt(sum/Periods);
      UpperBand[i] = ma + deviation;
      LowerBand[i] = ma - deviation;
      i--;
   }

   return(catch("start(2)"));
}

