/**
 * Bollinger-Bands-Indikator
 */

#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 C'102,135,232'
#property indicator_color2 C'163,183,241'
#property indicator_color3 C'102,135,232'

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DOT
#property indicator_style3 STYLE_SOLID


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern string Timeframe      = "H1";         // zu verwendender Zeitrahmen (M1, M5, M15, M30 etc.)
extern int    Periods        = 75;           // Anzahl der zu verwendenden Perioden
extern double Deviation      = 1.65;         // Standardabweichung
extern int    MA.Method      = 2;            // MA-Methode, siehe MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA
extern string MA.Method.Help = "1: Simple, 2: Exponential, 3: Smoothed, 4: Linear Weighted";
extern int    Max.Values     = 0;            // Anzahl der maximal zu berechnenden Werte (nochmalige Performancesteigerung)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    period;                                     // Period-Code zum angegebenen Timeframe

int error = ERR_NO_ERROR;


/**
 *
 */
int init() {
   // Puffer zuordnen
   SetIndexBuffer(0, UpperBand);
   SetIndexBuffer(1, MovingAvg);
   SetIndexBuffer(2, LowerBand);
   IndicatorDigits(Digits);


   // während der Entwicklung Puffer jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }


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
   switch (MA.Method) {
      case 1: MA.Method = MODE_SMA ; break;
      case 2: MA.Method = MODE_EMA ; break;
      case 3: MA.Method = MODE_SMMA; break;
      case 4: MA.Method = MODE_LWMA; break;
      default: 
         error = catch("init()  Invalid input parameter MA.Method: "+ MA.Method, ERR_INVALID_INPUT_PARAMVALUE);
         return(error);
   }
   if (Max.Values < 0) {
      error = catch("init()  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE);
      return(error);
   }
   else if (Max.Values == 0) {
      Max.Values = Bars;
   }


   // Indikatorlabel setzen
   SetIndexLabel (0, StringConcatenate("UpperBand(", Periods, "x", Timeframe, ")"));
   SetIndexLabel (1, NULL);
   SetIndexLabel (2, StringConcatenate("LowerBand(", Periods, "x", Timeframe, ")"));


   // nach Setzen der Label Parameter auf aktuellen Zeitrahmen umrechnen
   if (Period() != period) {
      double minutes = period * Periods;           // Timeframe * Anzahl Bars = Range in Minuten
      Periods = MathRound(minutes/Period());
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
   if (Periods < 2)           return(0);        // und bei Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
     

   int processedBars = IndicatorCounted(),
       iLastIndBar   = Bars - Periods,          // Index der letzten Indikator-Bar
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
      // TODO: Eventhandler integrieren: Update nur bei onNewHigh|onNewLow
   }

   // Werte auf Max.Values begrenzen
   if (bars > Max.Values)
      bars = Max.Values;
   

   /**
    * MovingAverage und Bänder berechnen
    *
    * Folgenden Beobachtungen und Überlegungen gelten für alle MA-Methoden:
    * ---------------------------------------------------------------------
    * 1) Die Ergebnisse von stdDev(appliedPrice=Close) und stdDev(appliedPrice=Median) sind nahezu 100% identisch.
    *
    * 2) Die Ergebnisse von stdDev(appliedPrice=Close) und stdDev(appliedPrice=High|Low) lassen sich durch Anpassung des Faktors Deviation zu 90-95%
    *    identisch machen.  1.65 * stdDev(appliedPrice=Close) entspricht nahezu 1.4 * stdDev(appliedPrice=High|Low).
    *
    * 3) Die Verwendung von appliedPrice=High|Low ist sehr langsam, appliedPrice=Close ist immer am schnellsten.
    *
    * 4) Zur Performancesteigerung wird appliedPrice=Median verwendet, auch wenn appliedPrice=High|Low geringfügig exakter scheint.  Denn was ist
    *    im Sinne dieses Indikators "exakt"?  Die konkreten berechneten Werte haben keine tatsächliche Aussagekraft.  Aus diesem Grunde wird ein 
    *    weiteres Bollinger-Band auf SMA-Basis verwendet (dessen konkrete Werte ebenfalls keine tatsächliche Aussagekraft haben).  Beide Indikatoren
    *    zusammen dienen zur Orientierung im Trend, "exakt messen" können beide nichts.
    */
   double ma, dev;
   //int ticks = GetTickCount();

   for (i=bars-1; i >= 0; i--) {
      ma  = iMA(NULL, 0, Periods, 0, MA.Method, PRICE_MEDIAN, i);
      dev = iStdDev(NULL, 0, Periods, 0, MA.Method, PRICE_MEDIAN, i) * Deviation;
      UpperBand[i] = ma + dev;
      MovingAvg[i] = ma;
      LowerBand[i] = ma - dev;
   }
   
   //if (bars > 1) Print("start()   Bars: "+ Bars +"   processedBars: "+ processedBars +"   calculated bars: "+ bars +"   used time: "+ (GetTickCount()-ticks) +" ms");

   return(catch("start(2)"));
}

