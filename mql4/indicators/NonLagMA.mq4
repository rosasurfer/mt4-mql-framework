/**
 * Low-lag multi-color moving average
 *
 * This indicator uses the formula of version 4. The MA using the formula of version 7 reacts a tiny bit slower than this one
 * and is probably more correct (because more recent). However trend changes indicated by both formulas are identical in
 * 99.9% of all observed cases.
 *
 *
 * @see  version 4.0: http://www.forexfactory.com/showthread.php?t=571026
 * @see  version 7.1: http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm
 * @see  version 7.1: http://www.mql5.com/en/forum/175037/page36#comment_4583645
 * @see  version 7.8: http://www.mql5.com/en/forum/175037/page62#comment_4583907
 * @see  version 7.9: http://www.mql5.com/en/forum/175037/page75#comment_4584032
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Cycle.Length          = 20;

extern color  Color.UpTrend         = RoyalBlue;                                          // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend       = Red;
extern string Draw.Type             = "Line | Dot*";
extern int    Draw.LineWidth        = 2;

extern int    Max.Values            = 5000;                                               // max. number of values to display: -1 = all

extern string __________________________;

extern string Signal.onTrendChange  = "auto* | off | on";
extern string Signal.Sound          = "auto* | off | on";
extern string Signal.Mail.Receiver  = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver   = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@NLMA.mqh>
#include <functions/@Trend.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#define MODE_MA               MovingAverage.MODE_MA                  // Buffer-ID's
#define MODE_TREND            MovingAverage.MODE_TREND               //
#define MODE_UPTREND          2                                      //
#define MODE_DOWNTREND        3                                      // Draw.Type=Line: Bei Unterbrechung eines Down-Trends um nur eine Bar wird dieser Up-Trend durch den sich
#define MODE_UPTREND1         MODE_UPTREND                           // fortsetzenden Down-Trend optisch verdeckt. Um auch solche kurzen Trendwechsel sichtbar zu machen, werden sie
#define MODE_UPTREND2         4                                      // zusätzlich im Buffer MODE_UPTREND2 gespeichert, der im Chart den Buffer MODE_DOWNTREND optisch überlagert.

#property indicator_chart_window
#property indicator_buffers   5                                      // configurable buffers (input dialog)
int       allocated_buffers = 5;                                     // used buffers

#property indicator_width1    0
#property indicator_width2    0
#property indicator_width3    1
#property indicator_width4    1
#property indicator_width5    1

double bufferMA       [];                                            // vollst. Indikator: unsichtbar (Anzeige im Data window)
double bufferTrend    [];                                            // Trend: +/-         unsichtbar
double bufferUpTrend1 [];                                            // UpTrend-Linie 1:   sichtbar
double bufferDownTrend[];                                            // DownTrend-Linie:   sichtbar (überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                                            // UpTrend-Linie 2:   sichtbar (überlagert DownTrend-Linie)

int    cycles = 4;
int    cycleLength;
int    cycleWindowSize;

double ma.weights[];                                                 // Gewichtungen der einzelnen Bars des MA's

int    draw.type;                                                    // DRAW_LINE | DRAW_ARROW
int    draw.arrow.size = 1;
int    maxValues;                                                    // Höchstanzahl darzustellender Werte
string legendLabel;
string ma.shortName;                                                 // Name für Chart, Data window und Kontextmenüs

bool   signals;

bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";

bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";

bool   signal.sms;
string signal.sms.receiver = "";

string signal.info = "";                                             // Infotext in der Chartlegende

int    tickTimerId;                                                  // ID eines ggf. installierten Offline-Tickers


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // (1.1) Cycle.Length
   if (Cycle.Length < 2)   return(catch("onInit(1)  Invalid input parameter Cycle.Length = "+ Cycle.Length, ERR_INVALID_INPUT_PARAMETER));
   cycleLength     = Cycle.Length;
   cycleWindowSize = cycles*cycleLength + cycleLength-1;

   // (1.2) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;    // u.U. 0xFF000000 (entspricht Schwarz)

   // (1.3) Draw.Type
   string elems[], sValue=StringToLower(Draw.Type);
   if (Explode(sValue, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(2)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // (1.4) Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(3)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // (1.5) Max.Values
   if (Max.Values < -1)    return(catch("onInit(5)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // (1.6) Signale
   if (!Configure.Signal("NonLagMA", Signal.onTrendChange, signals))                                            return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
      signal.info = "TrendChange="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms,   "SMS,",   ""), -1);
   }


   // (2) Chart-Legende erzeugen
   ma.shortName = __NAME__ +"("+ cycleLength +")";
   if (!IsSuperContext()) {
       legendLabel  = CreateLegendLabel(ma.shortName);
       ObjectRegister(legendLabel);
   }


   // (3) MA-Gewichtungen berechnen
   @NLMA.CalculateWeights(ma.weights, cycles, cycleLength);


   // (4.1) Bufferverwaltung
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // vollst. Indikator: unsichtbar (Anzeige im Data window)
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // Trend: +/-         unsichtbar
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // UpTrend-Linie 2:   sichtbar

   // (4.2) Anzeigeoptionen
   IndicatorShortName(ma.shortName);                                    // Context Menu
   SetIndexLabel(MODE_MA,        ma.shortName);                         // Tooltip und Data window
   SetIndexLabel(MODE_TREND,     NULL        );
   SetIndexLabel(MODE_UPTREND1,  NULL        );
   SetIndexLabel(MODE_DOWNTREND, NULL        );
   SetIndexLabel(MODE_UPTREND2,  NULL        );
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   // im synthetischen Chart Ticker installieren, weil u.U. keiner läuft (z.B. wenn ChartInfos nicht geladen sind)
   if (signals) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StringCompareI(GetServerName(), "XTrade-Synthetic")) {
      int hWnd    = ec_hChart(__ExecutionContext);
      int millis  = 10000;                                           // nur alle 10 Sekunden (konservativ, auf VPS ohne ChartInfos ausreichend)
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Status des Offline-Tickers im Chart anzeigen
      string label = __NAME__+".Status";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings: runder Marker, grün="Online"
         ObjectRegister(label);
      }
   }
   return(catch("afterInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // ggf. Offline-Ticker deinstallieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(2)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (!ArraySize(bufferMA))                                            // kann bei Terminal-Start auftreten
      return(log("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }


   // (1) synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (2) Startbar ermitteln
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-cycleWindowSize);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Fehler setzen, jedoch keine Rückkehr, damit Legende aktualisiert werden kann
   }


   // (3) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      bufferMA[bar] = 0;

      // Moving Average
      for (int i=0; i < cycleWindowSize; i++) {
         bufferMA[bar] += ma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_CLOSE, bar+i);
      }

      // Trend aktualisieren
      @Trend.UpdateDirection(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, draw.type, true, true, SubPipDigits);
   }


   if (!IsSuperContext()) {
      // (4) Legende aktualisieren
      @Trend.UpdateLegend(legendLabel, ma.shortName, signal.info, Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);


      // (5) Signale: Trendwechsel signalisieren
      if (signals) /*&&*/ if (EventListener.BarOpen()) {                // aktueller Timeframe
         if      (bufferTrend[1] ==  1) onTrendChange(MODE_UPTREND  );
         else if (bufferTrend[1] == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);
}


/**
 * Event handler, called on BarOpen if trend has changed.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message = "";
   int    success = 0;

   if (trend == MODE_UPTREND) {
      message = ma.shortName +" turned up";
      if (__LOG) log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // nur Subject (leerer Mail-Body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }
   if (trend == MODE_DOWNTREND) {
      message = ma.shortName +" turned down";
      if (__LOG) log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_down));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // nur Subject (leerer Mail-Body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }
   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   int drawWidth = ifInt(draw.type==DRAW_ARROW, draw.arrow.size, Draw.LineWidth);
   int drawType  = ifInt(draw.type==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY);

   SetIndexStyle(MODE_UPTREND1,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, drawType,  EMPTY, drawWidth, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input:",                                                            NL,

                            "Cycle.Length=",          Cycle.Length,                         ";", NL,

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend),          ";", NL,
                            "Draw.Type=",             DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.LineWidth=",        Draw.LineWidth,                       ";", NL,

                            "Max.Values=",            Max.Values,                           ";", NL,

                            "Signal.onTrendChange=",  DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",          DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=",  DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",   DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}
