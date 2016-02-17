/**
 * Multi-Color/Timeframe Arnaud Legoux Moving Average
 *
 *
 *
 * @link  http://www.arnaudlegoux.com/
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern string MA.Periods            = "200";                         // für einige Timeframes sind gebrochene Werte zulässig (z.B. 1.5 x D1)
extern string MA.Timeframe          = "current";                     // Timeframe: [M1|M5|M15|...], "" = aktueller Timeframe
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

extern double Distribution.Offset   = 0.85;                          // Gauss'scher Verteilungsoffset: 0..1
extern double Distribution.Sigma    = 6.0;                           // Gauss'sches Verteilungs-Sigma (Kurvenhöhe)

extern color  Color.UpTrend         = DodgerBlue;                    // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend       = Orange;

extern int    Max.Values            = 2000;                          // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung
extern int    Shift.Horizontal.Bars = 0;                             // horizontale Shift in Bars
extern int    Shift.Vertical.Pips   = 0;                             // vertikale Shift in Pips

extern bool   Signal.TrendChange    = false;                         // Trendwechsel

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@MA.mqh>
#include <iFunctions/@ALMA.mqh>

#define MODE_MA             MovingAverage.MODE_MA                    // Buffer-ID's
#define MODE_TREND          MovingAverage.MODE_TREND                 //
#define MODE_UPTREND        2                                        //
#define MODE_DOWNTREND      3                                        // Bei Unterbrechung eines Down-Trends um nur eine Bar wird dieser Up-Trend durch den sich fortsetzenden
#define MODE_UPTREND1       MODE_UPTREND                             // Down-Trend optisch verdeckt. Um auch solche kurzen Trendwechsel sichtbar zu machen, werden sie zusätzlich
#define MODE_UPTREND2       4                                        // im Buffer MODE_UPTREND2 gespeichert, der im Chart den Buffer MODE_DOWNTREND optisch überlagert.

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                       // vollst. Indikator: unsichtbar (Anzeige im "Data Window")
double bufferTrend    [];                       // Trend: +/-         unsichtbar
double bufferUpTrend1 [];                       // UpTrend-Linie 1:   sichtbar
double bufferDownTrend[];                       // DownTrend-Linie:   sichtbar (überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                       // UpTrend-Linie 2:   sichtbar (überlagert DownTrend-Linie)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

double alma.weights[];                          // Gewichtungen der einzelnen Bars des ALMA's

double shift.vertical;

string legendLabel;
string ma.shortName;                            // Name für Chart, Data-Window und Kontextmenüs
string signalName;                              // Signalname für Chartanzeige


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // (1.1) MA.Timeframe zuerst, da Gültigkeit von MA.Periods davon abhängt
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "CURRENT")     MA.Timeframe = "";
   if (MA.Timeframe == ""       ) int ma.timeframe = Period();
   else                               ma.timeframe = StrToPeriod(MA.Timeframe);
   if (ma.timeframe == -1)           return(catch("onInit(1)  Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMETER));

   // (1.2) MA.Periods
   string strValue = StringTrim(MA.Periods);
   if (!StringIsNumeric(strValue))   return(catch("onInit(2)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   double dValue = StrToDouble(strValue);
   if (dValue <= 0)                  return(catch("onInit(3)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(dValue, 0.5) != 0) return(catch("onInit(4)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   strValue = NumberToStr(dValue, ".+");
   if (StringEndsWith(strValue, ".5")) {                                // gebrochene Perioden in ganze Bars umrechnen
      switch (ma.timeframe) {
         case PERIOD_M30: dValue *=  2; ma.timeframe = PERIOD_M15; break;
         case PERIOD_H1 : dValue *=  2; ma.timeframe = PERIOD_M30; break;
         case PERIOD_H4 : dValue *=  4; ma.timeframe = PERIOD_H1;  break;
         case PERIOD_D1 : dValue *=  6; ma.timeframe = PERIOD_H4;  break;
         case PERIOD_W1 : dValue *= 30; ma.timeframe = PERIOD_H4;  break;
         default:                    return(catch("onInit(5)  Illegal input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
      }
   }
   switch (ma.timeframe) {                                              // Timeframes > H1 auf H1 umrechnen
      case PERIOD_H4: dValue *=   4; ma.timeframe = PERIOD_H1; break;
      case PERIOD_D1: dValue *=  24; ma.timeframe = PERIOD_H1; break;
      case PERIOD_W1: dValue *= 120; ma.timeframe = PERIOD_H1; break;
   }
   ma.periods = MathRound(dValue);
   if (ma.periods < 2)               return(catch("onInit(6)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (ma.timeframe != Period()) {                                      // angegebenen auf aktuellen Timeframe umrechnen
      double minutes = ma.timeframe * ma.periods;                       // Timeframe * Anzahl Bars = Range in Minuten
      ma.periods = MathRound(minutes/Period());
   }
   MA.Periods = strValue;

   // (1.3) MA.AppliedPrice
   string elems[];
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.AppliedPrice;
   ma.appliedPrice = StrToPriceType(strValue);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                                     return(catch("onInit(7)  Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // (1.4) Max.Values
   if (Max.Values < -1)              return(catch("onInit(8)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // (1.5) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;    // u.U. 0xFF000000 (entspricht Schwarz)

   // (1.6) Signals
   if (Signal.TrendChange) signalName = "Signal.TrendChange=ON";
   else                    signalName = "";


   // (2) Chart-Legende erzeugen
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe != "")             strTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.shortName = "ALMA("+ MA.Periods + strTimeframe + strAppliedPrice +")";
   legendLabel  = CreateLegendLabel(ma.shortName);
   ObjectRegister(legendLabel);


   // (3) ALMA-Gewichtungen berechnen (Laufzeit ist vernachlässigbar, siehe Performancedaten in onTick())
   if (ma.periods > 1)                                                  // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      @ALMA.CalculateWeights(alma.weights, ma.periods, Distribution.Offset, Distribution.Sigma);


   // (4.1) Bufferverwaltung
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // Trend: +/-         unsichtbar
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // UpTrend-Linie 2:   sichtbar

   // (4.2) Anzeigeoptionen
   IndicatorShortName(ma.shortName);                                    // Context Menu
   string dataName = "ALMA("+ MA.Periods + strTimeframe +")";
   SetIndexLabel(MODE_MA,        dataName);                             // Tooltip und "Data Window"
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(MODE_MA,        0        ); SetIndexShift(MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_TREND,     0        ); SetIndexShift(MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw); SetIndexShift(MODE_UPTREND1,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw); SetIndexShift(MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw); SetIndexShift(MODE_UPTREND2,  Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pip;                          // TODO: Digits/Point-Fehler abfangen

   // (4.4) Styles
   SetIndicatorStyles();                                                // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(9)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(bufferMA) == 0)                                        // kann bei Terminal-Start auftreten
      return(debug("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor kompletter Neuberechnung Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (1) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // Laufzeit auf Toshiba Satellite:
   // -------------------------------
   // H1 ::ALMA(7xD1)::onTick()   weights(  168)=0.000 sec   buffer(2000)=0.110 sec   loops=   336.000
   // M30::ALMA(7xD1)::onTick()   weights(  336)=0.000 sec   buffer(2000)=0.250 sec   loops=   672.000
   // M15::ALMA(7xD1)::onTick()   weights(  672)=0.000 sec   buffer(2000)=0.453 sec   loops= 1.344.000
   // M5 ::ALMA(7xD1)::onTick()   weights( 2016)=0.016 sec   buffer(2000)=1.547 sec   loops= 4.032.000
   // M1 ::ALMA(7xD1)::onTick()   weights(10080)=0.000 sec   buffer(2000)=7.110 sec   loops=20.160.000 (20 Mill. Durchläufe)
   //
   // Laufzeit auf Toshiba Portege:
   // -----------------------------
   // H1 ::ALMA(7xD1)::onTick()                              buffer(2000)=0.078 sec
   // M30::ALMA(7xD1)::onTick()                              buffer(2000)=0.156 sec
   // M15::ALMA(7xD1)::onTick()                              buffer(2000)=0.312 sec
   // M5 ::ALMA(7xD1)::onTick()                              buffer(2000)=0.952 sec
   // M1 ::ALMA(7xD1)::onTick()                              buffer(2000)=4.773 sec
   //
   // Fazit: weights-Berechnung ist vernachlässigbar, Schwachpunkt ist die verschachtelte Schleife in bufferMA-Berechnung


   // (2) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      // Moving Average
      bufferMA[bar] = shift.vertical;
      for (int i=0; i < ma.periods; i++) {
         bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
      }

      // Trend aktualisieren
      @MA.UpdateTrend(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2);
   }


   // (3) Legende aktualisieren
   @MA.UpdateLegend(legendLabel, ma.shortName, signalName, Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);


   // (4) Signale: onBarOpen ggf. Trendwechsel detektieren
   int iNulls[];
   if (Signal.TrendChange) /*&&*/ if (EventListener.BarOpen(iNulls, NULL)) {     // aktueller Timeframe
      if      (bufferTrend[1] ==  1) onTrendChange(MODE_UPTREND);
      else if (bufferTrend[1] == -1) onTrendChange(MODE_DOWNTREND);
   }

   /*
   debug("onTick()  trend: "+ _int(bufferTrend[3]) +"  "+ _int(bufferTrend[2]) +"  "+ _int(bufferTrend[1]) +"  "+ _int(bufferTrend[0]));
   onTick()  trend: -6  -7  -8  -9
   onTick()  trend: -6  -7  -8   1
   onTick()  trend: -7  -8   1   2
   onTick()  trend: -7  -8   1   2
   */
   return(last_error);
}


/**
 * Eventhandler, der aufgerufen wird, wenn nach bei BarOpen ein Trendwechsel stattgefunden hat.
 *
 * @return bool - Erfolgsstatus
 */
bool onTrendChange(int trend) {
   if (trend == MODE_UPTREND) {
      PlaySoundEx("Signal-Up.wav");
      log("onTrendChange(1)  "+ ma.shortName +" trend change: up");
   }
   else if (trend == MODE_DOWNTREND) {
      PlaySoundEx("Signal-Down.wav");
      log("onTrendChange(2)  "+ ma.shortName +" trend change: down");
   }

   else return(catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
   return(true);
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompilation), die erfordern, daß die Styles
 * in der Regel in init(), nach Recompilation jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(MODE_DOWNTREND, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
   SetIndexStyle(MODE_UPTREND2,  DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "MA.Periods=\"",          MA.Periods                             , "\"; ",
                            "MA.Timeframe=\"",        MA.Timeframe                           , "\"; ",
                            "MA.AppliedPrice=\"",     MA.AppliedPrice                        , "\"; ",

                            "Distribution.Offset=",   NumberToStr(Distribution.Offset, ".1+"), "; ",
                            "Distribution.Sigma=",    NumberToStr(Distribution.Sigma, ".1+") , "; ",

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend)              , "; ",
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend)            , "; ",

                            "Max.Values=",            Max.Values                             , "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars                  , "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips                    , "; ")
   );
}
