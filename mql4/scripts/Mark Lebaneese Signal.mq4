/**
 * Mark entry and exit signals of the "Lebaneese" strategy.
 *
 *
 * Interim results
 * ---------------
 *  • Open/Close on NonLagMA trend change, no stoploss:
 *    EURUSD,M1 ::Signal Lebaneese::onTick()  bars=10000   min=  -53.1   max=  80.1   profit=  -36.7
 *    EURUSD,M5 ::Signal Lebaneese::onTick()  bars=10000   min= -338.0   max=  -5.9   profit= -320.9
 *    EURUSD,M15::Signal Lebaneese::onTick()  bars=10000   min= -107.0   max= 488.7   profit=  335.9
 *    EURUSD,M30::Signal Lebaneese::onTick()  bars=10000   min= -408.6   max= 241.4   profit= -252.9
 *    EURUSD,H1 ::Signal Lebaneese::onTick()  bars=10000   min= -244.6   max= 841.5   profit=  -65.3
 *    EURUSD,H4 ::Signal Lebaneese::onTick()  bars=10000   min=-2857.4   max=1660.5   profit= -892.4   (800 trades)
 *    EURUSD,D1 ::Signal Lebaneese::onTick()  bars=6969    min=-3548.0   max=1254.0   profit=-2057.5
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int  Max.Bars = 1000;                       // Höchstanzahl zu analysierender Bars: -1 = keine Begrenzung
extern bool Alerts   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <iCustom/icNonLagMA.mqh>


// Zugriff auf NonLagMA-Buffer
#define MODE_MA            MovingAverage.MODE_MA
#define MODE_TREND         MovingAverage.MODE_TREND

int    maxBars;                                    // Höchstanzahl im Chart zu analysierender Bars

int    nlma.cycles;                                // NonLagMA-Parameter
int    nlma.cycleLength;                           // ...
int    nlma.cycleWindowSize;                       // ...
int    nlma.maxValues;                             // ...


double profit = 0;                                 // P/L aller geschlossenen Positionen in Pips
double profit.min = INT_MAX;                       // niedrigster registrierter P/L
double profit.max = INT_MIN;                       // höchster registrierter P/L


// Farben für Orderanzeige
#define CLR_OPEN_LONG      C'0,0,254'              // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT     C'254,0,0'              // Red  - rgb(1,1,1)
#define CLR_OPEN_STOPLOSS  Red
#define CLR_CLOSE          Orange
#define CLR_CLOSED_LONG    Blue
#define CLR_CLOSED_SHORT   Red


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
   nlma.maxValues       = maxBars + 50;            // sicherheitshalber ein paar Bars mehr, damit auch der älteste Trendwechsel korrekt detektiert wird


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
   int bars     = Min(ChangedBars, maxBars);
   int startBar = Min(bars-1, Bars-nlma.cycleWindowSize);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Fehler setzen, jedoch keine Rückkehr, damit ggf. Legende aktualisiert werden kann
   }

   bool     trendInitialized = false;

   bool     long.position = false;
   datetime long.position.time;
   double   long.position.price;

   bool     short.position = false;
   datetime short.position.time;
   double   short.position.price;

   int      long.retracement = 0;
   double   long.retracement.high;
   double   long.retracement.low = INT_MAX;

   int      short.retracement = 0;
   double   short.retracement.high = INT_MIN;
   double   short.retracement.low;


   // (2) Bars analysieren
   for (int bar=startBar; bar >= 0; bar--) {
      int trend = icNonLagMA(NULL, nlma.cycleLength, nlma.maxValues, MODE_TREND, bar);

      // (2.1) vor kompletter Neuberechnung ersten Trendwechsel abwarten
      if (!ValidBars) {
         if (!trendInitialized) /*&&*/ if (Abs(trend) != 1)
            continue;
         trendInitialized = true;
      }

      // (2.2) noch vor Trendanalyse auf Retracement-Breaks testen
      if (long.retracement && !long.position) {                         // der zusätzliche Test (Low <= retracement.high) filtert unmögliche Fills bei Gaps
         if (LE(Low[bar], long.retracement.high, Digits) && GT(High[bar], long.retracement.high, Digits)) {
            long.position       = true;
            long.position.time  = Time[bar];
            long.position.price = long.retracement.high;
            MarkOpen(OP_LONG, long.position.time, long.position.price);
            //debug("onTick(2)  bar="+ StringPadRight(bar, 2) +"  retracement.break  long.position.open");
         }
      }
      if (short.retracement && !short.position) {                       // der zusätzliche Test (High >= retracement.low) filtert unmögliche Fills bei Gaps
         if (GE(High[bar], short.retracement.low, Digits) && LT(Low[bar], short.retracement.low, Digits)) {
            short.position       = true;
            short.position.time  = Time[bar];
            short.position.price = short.retracement.low;
            MarkOpen(OP_SHORT, short.position.time, short.position.price);
            //debug("onTick(3)  bar="+ StringPadRight(bar, 2) +"  retracement.break  short.position.open");
         }
      }

      // (2.3) Trend analysieren
      if (trend > 0) {
         if (long.position) continue;
         if (short.position) {                                          // Short-Position schließen
            short.position = false;
            MarkClose(OP_SHORT, short.position.time, short.position.price, Time[bar], Close[bar]);
            //debug("onTick(4)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  short.position.close");
         }
         short.retracement      = 0;                                    // DownTrend-Status zurücksetzen
         short.retracement.high = INT_MIN;

         if (trend >= 2) {
            if (LT(Close[bar], Open[bar], Digits)) {                    // auf neues Retracement testen
               long.retracement++;
               long.retracement.high = High[bar];
               long.retracement.low  = Low [bar];
               //debug("onTick(5)  bar="+ StringPadRight(bar, 2) +"  upTrend  ="+ StringPadLeft(trend, 3) +"  long.retracement ="+ StringPadRight(long.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
            }
         }
      }

      else if (trend < 0) {
         if (short.position) continue;
         if (long.position) {                                           // Long-Position schließen
            long.position = false;
            MarkClose(OP_LONG, long.position.time, long.position.price, Time[bar], Close[bar]);
            //debug("onTick(6)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  long.position.close");
         }
         long.retracement     = 0;                                      // UpTrend-Status zurücksetzen
         long.retracement.low = INT_MAX;

         if (trend <= -2) {
            if (GT(Close[bar], Open[bar], Digits)) {                    // auf neues Retracement testen
               short.retracement++;
               short.retracement.high = High[bar];
               short.retracement.low  = Low [bar];
               //debug("onTick(7)  bar="+ StringPadRight(bar, 2) +"  downTrend="+ StringPadLeft(trend, 3) +"  short.retracement="+ StringPadRight(short.retracement, 2) +"  H="+ NumberToStr(High[bar], PriceFormat) +"  L="+ NumberToStr(Low[bar], PriceFormat));
            }
         }
      }
   }


   // Profit loggen
   if (!ValidBars) debug("onTick(8)  bars="+ StringPadRight(bars, 5) +"   min="+ DoubleToStr(profit.min, 1) +"   max="+ DoubleToStr(profit.max, 1) +"   profit="+ DoubleToStr(profit, 1));

   return(catch("onTick(9)"));
}


/**
 *
 */
void MarkOpen(int direction, datetime time, double price) {
   static int counter = 0;
   counter++;

   if (direction == OP_LONG) {
      string label = StringConcatenate("#", counter, " buy at ", NumberToStr(price, PriceFormat));
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
      label = StringConcatenate("#", counter, " sell at ", NumberToStr(price, PriceFormat));
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


/**
 *
 */
void MarkClose(int direction, datetime time1, double price1, datetime time2, double price2) {
   int markerColors[] = {CLR_CLOSED_LONG, CLR_CLOSED_SHORT};
   int lineColors  [] = {Blue, Red};

   static int counter = 0;
   counter++;

   string sOpenPrice  = NumberToStr(price1, PriceFormat);
   string sClosePrice = NumberToStr(price2, PriceFormat);


   if (direction == OP_LONG) {
      profit    += (price2 - price1)/Pips;
      profit.min = MathMin(profit, profit.min);
      profit.max = MathMax(profit, profit.max);

      // Verbindungslinie
      string lineLabel = StringConcatenate("#", counter, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, time1, price1, time2, price2)) {
         ObjectSet(lineLabel, OBJPROP_RAY  , false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK , true                 );
         ObjectRegister(lineLabel);
      }

      // Close-Marker
      string closeLabel = StringConcatenate("#", counter, " close buy at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, time2, price2)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
         ObjectRegister(closeLabel);
      }
      return;
   }


   if (direction == OP_SHORT) {
      profit += (price1 - price2)/Pips;

      // Verbindungslinie
      lineLabel = StringConcatenate("#", counter, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, time1, price1, time2, price2)) {
         ObjectSet(lineLabel, OBJPROP_RAY  , false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK , true                 );
         ObjectRegister(lineLabel);
      }

      // Close-Marker
      closeLabel = StringConcatenate("#", counter, " close sell at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, time2, price2)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
         ObjectRegister(closeLabel);
      }
      return;
   }

   catch("MarkClose(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}
