/**
 * Multi-Color/Multi-Timeframe Moving Average mit Hotkey-Steuerung
 *
 *
 * Unterstützte MA-Typen:
 *  • SMA  - Simple Moving Average:          Gewichtung aller Bars gleich
 *  • LWMA - Linear Weighted Moving Average: Gewichtung der Bars nach linearer Funktion
 *  • EMA  - Exponential Moving Average:     Gewichtung der Bars nach Exponentialfunktion
 *  • ALMA - Arnaud Legoux Moving Average:   Gewichtung der Bars nach konfigurierbarer Gaußscher Verteilungsfunktion
 *
 * Nicht mehr unterstützte MA-Typen:
 *  • SMMA - Smoothed Moving Average:        EMA anderer Periode (Relikt aus den 70'ern, läßt sich teilweise schneller als EMA berechnen)
 *  • TMA  - Triangular Moving Average:      doppelter SMA(SMA(n)), also verdoppelte Response-Zeit und verdoppeltes Lag
 *
 * Der Timeframe des Indikators kann zur Verbesserung der Lesbarkeit mit einem Alias konfiguriert werden, z.B.:
 *  • die Konfiguration "3 x D1=>H1"  wird interpretiert als "72 x H1"
 *  • die Konfiguration "2 x D1=>M15" wird interpretiert als "192 x M15"
 *
 * Ist der Timeframe des Indikators mit einem Alias konfiguriert, kann für die Periodenlänge ein gebrochener Wert angegeben werden, wenn die
 * Periodenlänge nach Auflösung des Alias ein ganzzahliger Wert ist, z.B.:
 *  • die Konfiguration "1.5 x D1=>H1" wird interpretiert als "36 x H1"
 *  • die Konfiguration "2.5 x H1=>M5" wird interpretiert als "30 x M5"
 *
 * Zur Berechnung wird immer der konfigurierte Timeframe verwendet, auch bei abweichender Chartperiode.
 *
 * Sind im aktuellen Chart für mehr als einen Indikator Hotkeys zur schnellen Änderung der Indikatorperiode aktiviert, empfängt nur der erste
 * für Hotkeys konfigurierte Indikator die entsprechenden Commands (in der Reihenfolge der Indikatoren im "Indicators List" Window).
 *
 * Im Buffer MovingAverage.MODE_MA stehen die Werte des Moving Average und im Buffer MovingAverage.MODE_TREND Trendrichtung und Trendlänge
 * der jeweiligen Bar zur Verfügung:
 *  • Trendrichtung: positive Werte (+1...+n) für Aufwärtstrends bzw. negative Werte (-1...-n) für Abwärtstrends
 *  • Trendlänge:    der Absolutwert des Trends einer Bar weniger 1 (Distanz dieser Bar vom letzten davor aufgetretenen Trendreversal)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string MA.Periods                 = "200";                    // für einige Timeframes sind gebrochene Werte zulässig (z.B. 1.5 x D1)
extern string MA.Timeframe               = "current";                // Timeframe: [M1|M5|M15,...[=> M1|M5|M15,...]]    ("current"|"" = aktueller Timeframe)
extern string MA.Method                  = "SMA* | LWMA | EMA | ALMA";
extern string MA.AppliedPrice            = "Open | High | Low | Close* | Median | Typical | Weighted";
extern bool   MA.Periods.Hotkeys.Enabled = false;                    // ob Hotkeys zur schnellen Änderung der Periode aktiviert sind

extern color  Color.UpTrend              = DodgerBlue;               // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend            = Orange;

extern int    Max.Values                 = 2000;                     // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung
extern int    Shift.Horizontal.Bars      = 0;                        // horizontale Indikator-Shift in Bars
extern int    Shift.Vertical.Pips        = 0;                        // vertikale Indikator-Shift in Pips

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <iFunctions/@MA.mqh>
#include <iFunctions/@ALMA.mqh>

#define MODE_MA             MovingAverage.MODE_MA                    // Buffer-ID's
#define MODE_TREND          MovingAverage.MODE_TREND                 //
#define MODE_UPTREND1       2                                        // Bei Unterbrechung eines Down-Trends um nur eine Bar wird dieser Up-Trend durch den sich fortsetzenden
#define MODE_DOWNTREND      3                                        // Down-Trendoptisch verdeckt. Um auch solche kurzen Trendwechsel sichtbar zu machen, werden sie zusätzlich
#define MODE_UPTREND2       4                                        // im Buffer MODE_UPTREND2 gespeichert, der im Chart den Buffer MODE_DOWNTREND optisch überlagert.

#define MA_PERIODS_UP       1                                        // Hotkey-Command-IDs
#define MA_PERIODS_DOWN    -1

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                                            // vollst. Indikator (unsichtbar, Anzeige im "Data Window")
double bufferTrend    [];                                            // Trend: +/-        (unsichtbar)
double bufferUpTrend1 [];                                            // UpTrend-Linie 1   (sichtbar)
double bufferDownTrend[];                                            // DownTrend-Linie   (sichtbar, überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                                            // UpTrend-Linie 2   (sichtbar, überlagert DownTrend-Linie)

int    ma.periods;
int    ma.timeframe;
int    ma.method;
int    ma.appliedPrice;

double alma.weights[];                                               // ALMA: Gewichtungen der einzelnen Bars

double shift.vertical;
string legendLabel, legendName;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // (1.1) MA.Timeframe zuerst, da Gültigkeit von MA.Periods davon abhängt
   int    timeframe, timeframeAlias;
   string sValue = StringToUpper(StringTrim(MA.Timeframe));
   if (sValue=="" || sValue=="CURRENT") {
      timeframe    = Period();
      MA.Timeframe = "";
   }
   else {
      string values[];
      if (Explode(sValue, "=>", values, 2) == 1) {
         timeframe = StrToPeriod(sValue);
         if (timeframe == -1)                     return(catch("onInit(1)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         MA.Timeframe = PeriodDescription(timeframe);
      }
      else {
         timeframe      = StrToPeriod(StringTrim(values[1]));
         timeframeAlias = StrToPeriod(StringTrim(values[0]));

         if (timeframe==-1 || timeframeAlias==-1) return(catch("onInit(2)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         if (timeframeAlias < timeframe)          return(catch("onInit(3)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

         if (timeframeAlias > timeframe) {                           // Timeframes > W1 können nicht immer auf einen kleineren Timeframe heruntergerechnet werden
            if (timeframeAlias==PERIOD_MN1 || (timeframeAlias==PERIOD_Q1 && timeframe!=PERIOD_MN1))
                                                  return(catch("onInit(4)   Illegal input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));
            MA.Timeframe = PeriodDescription(timeframeAlias) +"=>"+ PeriodDescription(timeframe);
         }
         else /*timeframeAlias == timeframe*/ {
            timeframeAlias = 0;
            MA.Timeframe   = PeriodDescription(timeframe);
         }
      }
   }
   ma.timeframe = timeframe;

   // (1.2) MA.Periods
   sValue = StringTrim(MA.Periods);
   if (!StringIsNumeric(sValue))                  return(catch("onInit(5)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   double dValue = StrToDouble(sValue);
   if (dValue <= 0)                               return(catch("onInit(6)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));

   if (!timeframeAlias) {
      if (MathModFix(dValue, 1) != 0)             return(catch("onInit(7)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
      ma.periods = MathRound(dValue);
   }
   else {
      // Alias angegeben
     double dMinutes;
     switch (timeframeAlias) {
         case PERIOD_M1 :                                            // kann nicht auftreten
         case PERIOD_MN1: break;                                     // wird vorher abgefangen
         case PERIOD_Q1:                                             // kommt nur in Kombination mit timeframe=PERIOD_MN1 vor
            if (MathModFix(dValue, 1) != 0)       return(catch("onInit(8)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
            ma.periods = Round(dValue) * 3;                          // 3 Monate je Quartal
            break;

         case PERIOD_M5 :
         case PERIOD_M15:
         case PERIOD_M30:
         case PERIOD_H1 :
         case PERIOD_H4 :
         case PERIOD_D1 : dMinutes = dValue * timeframeAlias; break;
         case PERIOD_W1 : dMinutes = dValue * 5 * PERIOD_D1;  break; // 5 Handelstage je Woche
      }
      if (dMinutes != 0) {
         if (MathModFix(dMinutes, 1) != 0)        return(catch("onInit(9)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
         int iMinutes = MathRound(dMinutes);
         if (iMinutes%timeframe != 0)             return(catch("onInit(10)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
         ma.periods = iMinutes/timeframe;
      }
   }
   if (ma.periods < 1)                            return(catch("onInit(11)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   MA.Periods = NumberToStr(dValue, ".+");

   // (1.3) MA.Method
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue   = values[size-1];
   }
   else sValue = MA.Method;
   ma.method = StrToMovAvgMethod(sValue);
   if (ma.method == -1)                           return(catch("onInit(12)   Invalid input parameter MA.Method = \""+ MA.Method +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.Method = MovAvgMethodDescription(ma.method);

   // (1.4) MA.AppliedPrice
   if (Explode(MA.AppliedPrice, "*", values, 2) > 1) {
      size   = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else sValue = MA.AppliedPrice;
   ma.appliedPrice = StrToPriceType(sValue);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                                                  return(catch("onInit(13)   Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // (1.5) Max.Values
   if (Max.Values < -1)                           return(catch("onInit(14)   Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE));

   // (1.6) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompile oder Deserialisierung
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;    // u.U. 0xFF000000 (entspricht Schwarz)


   // (2) Chart-Legende erzeugen
   string sTimeframe="", sAppliedPrice="";
   if (MA.Timeframe != "")             sTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) sAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   legendName  = MA.Method +"("+ MA.Periods + sTimeframe + sAppliedPrice +")";
   legendLabel = CreateLegendLabel(legendName);
   ObjectRegister(legendLabel);


   // (3) ggf. ALMA-Gewichtungen berechnen
   if (ma.method==MODE_ALMA) /*&&*/ if (ma.periods > 1)              // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      @ALMA.CalculateWeights(alma.weights, ma.periods);


   // (4.1) Bufferverwaltung
   SetIndexBuffer(MODE_MA,        bufferMA       );                  // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                  // Trend: +/-         unsichtbar
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                  // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                  // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                  // UpTrend-Linie 2:   sichtbar

   // (4.2) Anzeigeoptionen
   IndicatorShortName(legendName);                                   // für Context Menu
   string dataName = MA.Method +"("+ MA.Periods + sTimeframe +")";
   SetIndexLabel(MODE_MA,        dataName);                          // für Tooltip und "Data Window"
   SetIndexLabel(MODE_TREND,     NULL    );
   SetIndexLabel(MODE_UPTREND1,  NULL    );
   SetIndexLabel(MODE_DOWNTREND, NULL    );
   SetIndexLabel(MODE_UPTREND2,  NULL    );
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(MODE_MA,        0        ); SetIndexShift(MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_TREND,     0        ); SetIndexShift(MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw); SetIndexShift(MODE_UPTREND1,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw); SetIndexShift(MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw); SetIndexShift(MODE_UPTREND2,  Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pip;                       // TODO: Digits/Point-Fehler abfangen

   // (4.4) Styles
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(15)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(bufferMA) == 0)                                        // kann bei Terminal-Start auftreten
      return(SetLastError(ERS_TERMINAL_NOT_YET_READY));

   // vor vollständiger Neuberechnung Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }


   // (1) Änderungen der MA-Periode zur Laufzeit (per Hotkey) erkennen und übernehmen
   if (MA.Periods.Hotkeys.Enabled)
      HandleEvent(EVENT_CHART_CMD);                                     // ChartCommands verarbeiten

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (2) Startbar der Berechnung ermitteln
   int ma.ChangedBars = ChangedBars;
   if (ma.ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ma.ChangedBars = Max.Values;
   int ma.startBar = Min(ma.ChangedBars-1, Bars-ma.periods);
   if (ma.startBar < 0) {
      if (IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // (3) ungültige Bars neuberechnen
   for (int bar=ma.startBar; bar >= 0; bar--) {
      // der eigentliche Moving Average
      if (ma.method == MODE_ALMA) {                                     // ALMA
         bufferMA[bar] = 0;
         for (int i=0; i < ma.periods; i++) {
            bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
      }
      else {                                                            // alle übrigen MA's
         bufferMA[bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
      }
      bufferMA[bar] += shift.vertical;

      // Trend aktualisieren
      @MA.UpdateTrend(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2);
   }


   // (4) Legende aktualisieren
   @MA.UpdateLegend(legendLabel, legendName, Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);
   return(last_error);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand für diesen Indikator eingetroffen ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[], int flags=NULL) {
   if (!IsChart)
      return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME__ +".command";
      mutex = "mutex."+ label;
   }


   // (1) zuerst nur Lesezugriff (unsynchronisiert möglich), um nicht bei jedem Tick das Lock erwerben zu müssen
   if (ObjectFind(label) == 0) {

      // (2) erst, wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
      if (!AquireLock(mutex, true))
         return(!SetLastError(stdlib.GetLastError()));

      // (3) Command auslesen und Command-Object löschen
      ArrayResize(commands, 1);
      commands[0] = ObjectDescription(label);
      ObjectDelete(label);

      // (4) Lock wieder freigeben
      if (!ReleaseLock(mutex))
         return(!SetLastError(stdlib.GetLastError()));

      return(!catch("EventListener.ChartCommand(1)"));
   }
   return(false);
}


/**
 * Handler für ChartCommands.
 *
 * @param  string commands[] - die eingetroffenen Commands
 *
 * @return bool - Erfolgsstatus
 */
bool onChartCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onChartCommand(1)   empty parameter commands = {}"));

   for (int i=0; i < size; i++) {
      if      (commands[i] == "Periods=Up"  ) { if (!ModifyMaPeriods(MA_PERIODS_UP  )) return(false); }
      else if (commands[i] == "Periods=Down") { if (!ModifyMaPeriods(MA_PERIODS_DOWN)) return(false); }
      else
         warn("onChartCommand(2)   unknown chart command \""+ commands[i] +"\"");
   }
   return(!catch("onChartCommand(3)"));
}


/**
 * Erhöht oder verringert den Parameter MA.Periods des Indikators.
 *
 * @param  int direction - Richtungs-ID:  MA_PERIODS_UP|MA_PERIODS_DOWN
 *
 * @return bool - Erfolgsstatus
 */
bool ModifyMaPeriods(int direction) {
   if (direction == MA_PERIODS_DOWN) {
   }
   else if (direction == MA_PERIODS_UP) {
   }
   else warn("ModifyMaPeriods(1)   unknown parameter direction = "+ direction);

   return(true);
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompile), die erfordern, daß die Styles
 * normalerweise in init(), nach Recompile jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
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
   return(StringConcatenate("init()   inputs: ",

                            "MA.Periods=\"",               MA.Periods                           , "\"; ",
                            "MA.Periods.Hotkeys.Enabled=", BoolToStr(MA.Periods.Hotkeys.Enabled), "; ",
                            "MA.Timeframe=\"",             MA.Timeframe                         , "\"; ",
                            "MA.Method=\"",                MA.Method                            , "\"; ",
                            "MA.AppliedPrice=\"",          MA.AppliedPrice                      , "\"; ",

                            "Color.UpTrend=",              ColorToStr(Color.UpTrend)            , "; ",
                            "Color.DownTrend=",            ColorToStr(Color.DownTrend)          , "; ",

                            "Max.Values=",                 Max.Values                           , "; ",
                            "Shift.Horizontal.Bars=",      Shift.Horizontal.Bars                , "; ",
                            "Shift.Vertical.Pips=",        Shift.Vertical.Pips                  , "; ")
   );
}
