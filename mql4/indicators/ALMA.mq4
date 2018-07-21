/**
 * Multi-color Arnaud Legoux Moving Average
 *
 *
 * @link  http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods           = 38;
extern string MA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern double Distribution.Offset  = 0.85;                           // Gauss'scher Verteilungsoffset: 0..1 (Position des Glockenscheitels)
extern double Distribution.Sigma   = 6.0;                            // Gauss'sches Verteilungs-Sigma       (Steilheit der Glocke)

extern color  Color.UpTrend        = Blue;                           // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend      = Red;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.LineWidth       = 3;

extern int    Max.Values           = 5000;                           // max. number of values to display: -1 = all

extern string __________________________;

extern string Signal.onTrendChange = "auto* | off | on";
extern string Signal.Sound         = "auto* | off | on";
extern string Signal.Mail.Receiver = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver  = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/@Trend.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

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
#property indicator_width3  3
#property indicator_width4  3
#property indicator_width5  3

double bufferMA       [];                                            // vollst. Indikator: unsichtbar (Anzeige im Data window)
double bufferTrend    [];                                            // Trend: +/-         unsichtbar
double bufferUpTrend1 [];                                            // UpTrend-Linie 1:   sichtbar
double bufferDownTrend[];                                            // DownTrend-Linie:   sichtbar (überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                                            // UpTrend-Linie 2:   sichtbar (überlagert DownTrend-Linie)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

double alma.weights[];                                               // Gewichtungen der einzelnen Bars des ALMA's

int    draw.type      = DRAW_LINE;                                   // DRAW_LINE | DRAW_ARROW
int    draw.arrowSize = 1;                                           // default symbol size for Draw.Type="dot"
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
   // MA.Periods
   if (MA.Periods < 2)               return(catch("onInit(3)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.AppliedPrice
   string values[], sValue = StringToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "close";                               // default price type
   if      (StringStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
   else if (StringStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
   else if (StringStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
   else if (StringStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
   else if (StringStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
   else if (StringStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
   else if (StringStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
   else                              return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                              return(catch("onInit(8)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 1)           return(catch("onInit(9)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5)           return(catch("onInit(10)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)              return(catch("onInit(11)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // Signals
   if (!Configure.Signal("ALMA", Signal.onTrendChange, signals))                                                return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
      signal.info = "TrendChange="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms,   "SMS,",   ""), -1);
   }


   // (2) Chart-Legende erzeugen
   string strAppliedPrice = "";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.shortName = "ALMA("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {
       legendLabel  = CreateLegendLabel(ma.shortName);
       ObjectRegister(legendLabel);
   }


   // (3) ALMA-Gewichtungen berechnen
   if (ma.periods > 1)                                                  // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      @ALMA.CalculateWeights(alma.weights, ma.periods, Distribution.Offset, Distribution.Sigma);


   // (4.1) Bufferverwaltung
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // vollst. Indikator: unsichtbar, jedoch Anzeige im Data window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // Trend: +/-         unsichtbar
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // UpTrend-Linie 2:   sichtbar

   // (4.2) Anzeigeoptionen
   IndicatorShortName(ma.shortName);                                    // Context Menu
   string dataName = "ALMA("+ MA.Periods +")";
   SetIndexLabel(MODE_MA,        dataName);                             // Tooltip und Data window
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndicatorStyles();

   return(catch("onInit(12)"));
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   // ggf. Offline-Ticker installieren
   if (signals) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StringCompareI(GetServerName(), "XTrade-Synthetic")) {
      int hWnd    = ec_hChart(__ExecutionContext);
      int millis  = 10000;                                           // alle 10 Sekunden
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
      //debug("afterInit(2)  TickTimer("+ millis +" msec) installed");

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
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }


   // (1) IndicatorBuffer entsprechend ShiftedBars synchronisieren
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (2) Startbar der Berechnung ermitteln
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
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
   // Fazit: weights-Berechnung ist vernachlässigbar, Schwachpunkt ist die verschachtelte Schleife in MA-Berechnung


   // (3) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      // Moving Average
      bufferMA[bar] = 0;
      for (int i=0; i < ma.periods; i++) {
         bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
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
 * Event handler called on BarOpen if trend has changed.
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
      log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // nur Subject (leere Mail)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }
   if (trend == MODE_DOWNTREND) {
      message = ma.shortName +" turned down";
      log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_down));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // nur Subject (leere Mail)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }
   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting indicator styles and levels. Usually styles are
 * applied in init(). However after recompilation styles must be applied in start() to not get ignored.
 */
void SetIndicatorStyles() {
   int width = ifInt(draw.type==DRAW_ARROW, draw.arrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, draw.type, EMPTY, width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",           DoubleQuoteStr(MA.Periods),              "; ",
                            "MA.AppliedPrice=",      DoubleQuoteStr(MA.AppliedPrice),         "; ",

                            "Distribution.Offset=",  NumberToStr(Distribution.Offset, ".1+"), "; ",
                            "Distribution.Sigma=",   NumberToStr(Distribution.Sigma, ".1+"),  "; ",

                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),               "; ",
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),             "; ",
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),               "; ",
                            "Draw.LineWidth=",       Draw.LineWidth,                          "; ",

                            "Max.Values=",           Max.Values,                              "; ",

                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange),    "; ",
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),            "; ",
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver),    "; ",
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),     "; ")
   );
}
