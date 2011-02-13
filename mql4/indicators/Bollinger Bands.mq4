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


bool init       = false;
int  init_error = NO_ERROR;


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern int    Periods        = 75;           // Anzahl der zu verwendenden Perioden
extern string Timeframe      = "H1";         // zu verwendender Zeitrahmen (M1, M5, M15, M30 etc.)
extern double Deviation      = 1.65;         // Standardabweichung
extern int    MA.Method      = 2;            // MA-Methode, siehe MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA
extern string MA.Method.Help = "1: Simple, 2: Exponential, 3: Smoothed, 4: Linear Weighted";
extern int    Max.Values     = 0;            // Anzahl der maximal zu berechnenden Werte (nochmalige Performancesteigerung)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    period;                                     // Period-Code zum angegebenen Timeframe


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true;
   init_error = NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = stdlib_GetLastError();
      return(init_error);
   }


   // Puffer zuordnen
   SetIndexBuffer(0, UpperBand);
   SetIndexBuffer(1, MovingAvg);
   SetIndexBuffer(2, LowerBand);
   IndicatorDigits(Digits);


   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      if (Bars > 0) {
         ArrayInitialize(UpperBand, EMPTY_VALUE);
         ArrayInitialize(MovingAvg, EMPTY_VALUE);
         ArrayInitialize(LowerBand, EMPTY_VALUE);
      }
   }


   // Parameter überprüfen
   if (Periods < 2) {
      init_error = catch("init()  Invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMVALUE);
      return(init_error);
   }
   period = GetPeriod(Timeframe);
   if (period == 0) {
      init_error = catch("init()  Invalid input parameter Timeframe: \'"+ Timeframe +"\'", ERR_INVALID_INPUT_PARAMVALUE);
      return(init_error);
   }
   switch (MA.Method) {
      case 1: MA.Method = MODE_SMA ; break;
      case 2: MA.Method = MODE_EMA ; break;
      case 3: MA.Method = MODE_SMMA; break;
      case 4: MA.Method = MODE_LWMA; break;
      default:
         init_error = catch("init()  Invalid input parameter MA.Method: "+ MA.Method, ERR_INVALID_INPUT_PARAMVALUE);
         return(init_error);
   }
   if (Deviation < 0 || CompareDoubles(Deviation, 0)) {
      init_error = catch("init()  Invalid input parameter Deviation: "+ Deviation, ERR_INVALID_INPUT_PARAMVALUE);
      return(init_error);
   }
   if (Max.Values < 0) {
      init_error = catch("init()  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE);
      return(init_error);
   }
   else if (Max.Values == 0) {
      Max.Values = Bars;
   }

   // Indikatorlabel setzen
   SetIndexLabel(0, StringConcatenate("UpperBand(", Periods, "x", Timeframe, ")"));
   SetIndexLabel(1, StringConcatenate("MovingAvg(", Periods, "x", Timeframe, ")"));
   SetIndexLabel(2, StringConcatenate("LowerBand(", Periods, "x", Timeframe, ")"));

   // nach Setzen der Label Parameter auf aktuellen Zeitrahmen umrechnen
   if (Period() != period) {
      double minutes = period * Periods;           // Timeframe * Anzahl Bars = Range in Minuten
      Periods = MathRound(minutes/Period());
   }

   // nach Parameteränderung nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS)
      SendFakeTick();

   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != NO_ERROR)                   return(0);
   }
   else if (init_error != NO_ERROR) {               // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != NO_ERROR)                   return(0);
   }


   if (Periods < 2)                             // Abbruch bei Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(0);

   int ValidBars   = IndicatorCounted(),
       iLastIndBar = Bars - Periods,            // Index der letzten Indikator-Bar
       bars,                                    // Anzahl der zu berechnenden Bars
       i, k;

   if (iLastIndBar < 0)
      return(0);                                // Abbruch im Falle Bars < Periods


   // Anzahl der zu berechnenden Bars bestimmen
   if (ValidBars == 0) {
      bars = iLastIndBar + 1;                   // alle
   }
   else {                                       // nur die fehlenden Bars
      bars = ChangedBars;
      if (bars > iLastIndBar + 1)
         bars = iLastIndBar + 1;
      // TODO: Eventhandler integrieren: Update nur bei onNewHigh|onNewLow
   }

   // zu berechnende Bars auf Max.Values begrenzen
   if (bars > Max.Values)
      bars = Max.Values;


   /**
    * MovingAverage und Bänder berechnen
    *
    * Folgende Beobachtungen und Überlegungen wurden für die verschiedenen MA-Methoden gemacht:
    * -----------------------------------------------------------------------------------------
    * 1) Die Ergebnisse von stdDev(appliedPrice=Close) und stdDev(appliedPrice=Median) stimmen zu beinahe 100% überein.
    *
    * 2) Die Ergebnisse von stdDev(appliedPrice=Median) und stdDev(appliedPrice=High|Low) lassen sich durch Anpassung des Faktors Deviation zu 90-95%
    *    in Übereinstimmung bringen.  Der Wert von stdDev(appliedPrice=Close)*1.65 entspricht nahezu dem Wert von stdDev(appliedPrice=High|Low)*1.4.
    *
    * 3) Die Verwendung von appliedPrice=High|Low ist sehr langsam, die von appliedPrice=Close am schnellsten.
    *
    * 4) Zur Performancesteigerung wird appliedPrice=Median verwendet, auch wenn appliedPrice=High|Low geringfügig exakter scheint.  Denn was ist
    *    im Sinne dieses Indikators "exakt"?  Die konkreten, berechneten Werte haben keine tatsächliche Aussagekraft.  Aus diesem Grunde wird ein
    *    weiteres Bollinger-Band auf SMA-Basis verwendet (dessen konkrete Werte ebenfalls keine tatsächliche Aussagekraft haben).  Beide Indikatoren
    *    zusammen dienen zur Orientierung im Trend, "exakt messen" können beide nichts.
    */
   double ma, dev;

   for (i=bars-1; i >= 0; i--) {
      ma  = iMA    (NULL, 0, Periods, 0, MA.Method, PRICE_MEDIAN, i);
      dev = iStdDev(NULL, 0, Periods, 0, MA.Method, PRICE_MEDIAN, i) * Deviation;
      UpperBand[i] = ma + dev;
      MovingAvg[i] = ma;
      LowerBand[i] = ma - dev;
   }

   return(catch("start()"));
}
