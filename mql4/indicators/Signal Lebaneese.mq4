/**
 * Analysiert die History und markiert im Chart Entry- und Exit-Signale des Systems "Trend catching with NonLagDot indicator" von Lebaneese.
 *
 * @see  http://www.forexfactory.com/showthread.php?t=571026
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int  Max.Bars = 100;                        // Höchstanzahl zu analysierender Bars: -1 = keine Begrenzung
extern bool Alerts   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iCustom/icNonLagMA.mqh>


// Zugriff auf NonLagMA-Buffer
#define MODE_MA            MovingAverage.MODE_MA
#define MODE_TREND         MovingAverage.MODE_TREND

int    maxBars;                                    // Höchstanzahl im Chart zu analysierender Bars

int    nlma.cycles;                                // NonLagMA-Parameter
int    nlma.cycleLength;                           // ...
int    nlma.cycleWindowSize;                       // ...
string nlma.filterVersion;                         // ...
int    nlma.maxValues;                             // ...


// Farben für Orderanzeige
#define CLR_OPEN_LONG      C'0,0,254'              // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT     C'254,0,0'              // Red  - rgb(1,1,1)
#define CLR_OPEN_STOPLOSS  Red
#define CLR_CLOSE          Orange


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung: Max.Bars
   if (Max.Bars < -1) return(catch("onInit(1)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxBars = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);


   // (2) NonLagMA-Parameter initialisieren
   nlma.cycles          =  4;
   nlma.cycleLength     = 20;
   nlma.cycleWindowSize = nlma.cycles*nlma.cycleLength + nlma.cycleLength-1;
   nlma.filterVersion   = "4";
   nlma.maxValues       = maxBars + 10;            // sicherheitshalber ein paar Bars mehr, damit auch der älteste Trendwechsel korrekt detektiert wird


   SetIndexLabel(0, NULL);                         // Datenanzeige ausschalten
   return(catch("onInit(2)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) Startbar ermitteln
   int bars     = Min(ChangedBars, Max.Bars);
   int startBar = Min(bars-1, Bars-nlma.cycleWindowSize);
   if (startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Fehler setzen, jedoch keine Rückkehr, damit ggf. Legende aktualisiert werden kann
   }

   int    long.retracement       = 0;
   double long.retracement.high;
   double long.retracement.low   = INT_MAX;
   bool   long.signal            = false;

   int    short.retracement      = 0;
   double short.retracement.high = INT_MIN;
   double short.retracement.low;
   bool   short.signal           = false;

   bool   trendInitialized       = false;


   // (2) ungültige Bars neu analysieren
   for (int bar=startBar; bar >= 0; bar--) {
      int trend = icNonLagMA(NULL, nlma.cycleLength, nlma.filterVersion, nlma.maxValues, MODE_TREND, bar);

      // (2.1) vor kompletter Neuberechnung ersten Trendwechsel abwarten
      if (!ValidBars) {
         if (!trendInitialized) /*&&*/ if (Abs(trend) != 1)
            continue;
         trendInitialized = true;
      }

      // (2.2) Trend analysieren
      if (trend > 0) {
         if (long.signal) continue;
         if (short.signal) {                                         // Short-Position schließen
            short.signal = false;
            debug("onTick(2)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  short.signal.close");
         }
         short.retracement      = 0;                                 // DownTrend-Status zurücksetzen
         short.retracement.high = INT_MIN;

         if (trend >= 2) {
            if (long.retracement!=0) {
               if (GT(High[bar], long.retracement.high, Digits)) {   // auf Retracement-Break testen
                  long.signal = true;
                  MarkOpen(OP_LONG, Time[bar], long.retracement.high);
                  debug("onTick(3)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  long.signal.open");
                  continue;
               }
            }
            if (LT(Close[bar], Open[bar], Digits)) {                 // auf weiteres Retracement testen
               if (LT(Low[bar], long.retracement.low, Digits)) {
                  long.retracement++;
                  long.retracement.high = High[bar];
                  long.retracement.low  = Low [bar];
                  debug("onTick(4)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  long.retracement ="+ StringPadRight(long.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
               }
            }
         }
      }

      else if (trend < 0) {
         if (short.signal) continue;
         if (long.signal) {                                          // Long-Position schließen
            long.signal = false;
            debug("onTick(5)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  long.signal.close");
         }
         long.retracement     = 0;                                   // UpTrend-Status zurücksetzen
         long.retracement.low = INT_MAX;

         if (trend <= -2) {
            if (short.retracement!=0) {
               if (LT(Low[bar], short.retracement.low, Digits)) {    // auf Retracement-Break testen
                  short.signal = true;
                  MarkOpen(OP_SHORT, Time[bar], short.retracement.low);
                  debug("onTick(6)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  short.signal.open");
                  continue;
               }
            }
            if (GT(Close[bar], Open[bar], Digits)) {                 // auf weiteres Retracement testen
               if (GT(High[bar], short.retracement.high, Digits)) {
                  short.retracement++;
                  short.retracement.high = High[bar];
                  short.retracement.low  = Low [bar];
                  debug("onTick(7)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  short.retracement="+ StringPadRight(short.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
               }
            }
         }
      }
   }

   return(catch("onTick(8)"));
}


/**
 *
 */
void MarkOpen(int direction, datetime time, double price) {
   static int counter = 0;
   counter++;

   if (direction == OP_LONG) {
      string label = StringConcatenate("#", counter, " Buy at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_LONG   );
         ObjectRegister(label);
      }
      return;
   }

   if (direction == OP_SHORT) {
      label = StringConcatenate("#", counter, " Sell at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_SHORT  );
         ObjectRegister(label);
      }
      return;
   }

   catch("MarkOpen(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}