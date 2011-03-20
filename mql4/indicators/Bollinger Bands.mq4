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


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    Periods        = 75;           // Anzahl der zu verwendenden Perioden
extern string Timeframe      = "H1";         // zu verwendender Zeitrahmen (M1, M5, M15, M30 etc.)
extern double Deviation      = 1.65;         // Standardabweichung
extern int    MA.Method      = 2;            // MA-Methode, siehe MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA
//extern string MA.Method.Help = "1: Simple, 2: Exponential, 3: Smoothed, 4: Linear Weighted";
extern string MA.Method.Help = "SMA | EMA | SMMA | LWMA";
extern int    Max.Values     = 0;            // Anzahl der maximal zu berechnenden Werte (nochmalige Performancesteigerung)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    period;                                     // Period-Code zum angegebenen Timeframe


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // Puffer zuordnen
   SetIndexBuffer(0, UpperBand);
   SetIndexBuffer(1, MovingAvg);
   SetIndexBuffer(2, LowerBand);
   IndicatorDigits(Digits);

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
      case 1: MA.Method = MODE_SMA;  break;
      case 2: MA.Method = MODE_EMA;  break;
      case 3: MA.Method = MODE_SMMA; break;
      case 4: MA.Method = MODE_LWMA; break;
      default:
         init_error = catch("init()  Invalid input parameter MA.Method: "+ MA.Method, ERR_INVALID_INPUT_PARAMVALUE);
         return(init_error);
   }
   if (Deviation <= 0) {
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

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   ValidBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else                                               ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // nach Terminal-Start Abschluß der Initialisierung überprüfen
   if (Bars == 0 || ArraySize(UpperBand) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }

   if (Periods < 2)                             // Abbruch bei Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(0);

   int iLastIndBar = Bars - Periods,            // Index der letzten Indikator-Bar
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