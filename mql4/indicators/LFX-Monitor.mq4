/**
 * Berechnet die Kurse der verfügbaren FX-Indizes, zeigt sie an und zeichnet ggf. deren History auf.
 *
 * Der Index einer Währung ist das geometrische Mittel der Kurse der jeweiligen Vergleichswährungen. Wird er mit einem Multiplikator normalisiert, ändert das den Wert,
 * nicht aber die Form der Indexkurve (z.B. sind USDX und EURX auf 100 und die SierraChart-FX-Indizes auf 1000 normalisiert).
 *
 * LiteForex fügt den Vergleichswährungen eine zusätzliche Konstante 1 hinzu, was die resultierende Indexkurve staucht. In einem autmatisch skalierenden Chart ist die Form
 * jedoch wieder dieselbe. Durch die Konstante ist es möglich, den Index einer Währung über den USD-Index und den USD-Kurs einer Währung zu berechnen, was u.U. schneller und
 * Resourcen sparender sein kann. Die LiteForex-Indizes sind bis auf den NZDLFX also gestauchte FX6-Indizes. Der NZDLFX ist ein reiner FX7-Index.
 *
 *  • geometrisches Mittel: USD-FX6 = (USDCAD * USDCHF * USDJPY * USDAUD * USDEUR * USDGBP         ) ^ 1/6
 *                          USD-FX7 = (USDCAD * USDCHF * USDJPY * USDAUD * USDEUR * USDGBP * USDNZD) ^ 1/7
 *                          NZD-FX7 = (NZDAUD * NZDCAD * NZDCHF * NZDEUR * NZDGBP * NZDJPY * NZDUSD) ^ 1/7
 *
 *  • LiteForex:            USD-LFX = (USDAUD * USDCAD * USDCHF * USDEUR * USDGBP * USDJPY * 1) ^ 1/7
 *                          CHF-LFX = (CHFAUD * CHFCAD * CHFEUR * CHFGBP * CHFJPY * CHFUSD * 1) ^ 1/7
 *                     oder CHF-LFX = USD-LFX / USDCHF
 *                          NZD-LFX = NZD-FX7
 *
 * - Wird eine Handelsposition statt über die direkten Paare über die USD-Crosses abgebildet, erzielt man einen niedrigeren Spread, die Anzahl der Teilpositionen und die
 *   entsprechenden Margin-Requirements sind jedoch höher.
 *
 * - Unterschiede zwischen theoretischer und praktischer Performance von Handelspositionen können vom Position-Sizing (MinLotStep) und bei längerfristigem Handel vom
 *   fehlenden Re-Balancing der Teilpositionen verursacht werden.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern bool   Recording.Enabled = false;                             // default: alle aktiviert, aber kein Recording
extern string _1________________________;
extern bool   AUDLFX.Enabled    = true;
extern bool   CADLFX.Enabled    = true;
extern bool   CHFLFX.Enabled    = true;
extern bool   EURLFX.Enabled    = true;
extern bool   GBPLFX.Enabled    = true;
extern bool   JPYLFX.Enabled    = true;
extern bool   NZDLFX.Enabled    = true;
extern bool   USDLFX.Enabled    = true;
extern string _2________________________;
extern bool   EURX.Enabled      = true;
extern bool   USDX.Enabled      = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlib.mqh>
#include <history.mqh>

#include <remote/functions.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


#property indicator_chart_window


string symbols[] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "EURX", "USDX" };
string names  [] = { "AUD"   , "CAD"   , "CHF"   , "EUR"   , "GBP"   , "JPY"   , "NZD"   , "USD"   , "EURX", "USDX" };
int    digits [] = {        5,        5,        5,        5,        5,        5,        5,        5,      3,      3 };

bool   AUDLFX.IsAvailable;
bool   CADLFX.IsAvailable;
bool   CHFLFX.IsAvailable;
bool   EURLFX.IsAvailable;
bool   GBPLFX.IsAvailable;
bool   JPYLFX.IsAvailable;
bool   NZDLFX.IsAvailable;
bool   USDLFX.IsAvailable;
bool     EURX.IsAvailable;
bool     USDX.IsAvailable;

bool   isEnabled  [];                                                // ob der Index aktiviert ist: entspricht *.Enabled
bool   isAvailable[];                                                // ob der Index verfügbar ist: entspricht *.IsAvailable
double index      [];                                                // aktueller Indexwert
double index.last [];                                                // vorheriger Indexwert

bool   isRecording[];                                                // default: FALSE
int    hSet       [];                                                // HistorySet-Handles
string serverName = "MyFX-Synthetic";                                // Default-Serververzeichnis fürs Recording

#define I_AUDLFX     0                                               // Array-Indizes
#define I_CADLFX     1
#define I_CHFLFX     2
#define I_EURLFX     3
#define I_GBPLFX     4
#define I_JPYLFX     5
#define I_NZDLFX     6
#define I_USDLFX     7
#define I_EURX       8
#define I_USDX       9


// Textlabel für die einzelnen Anzeigen
string labels[];
string label.tradeAccount;
string label.animation;                                              // Ticker-Visualisierung
string label.animation.chars[] = {"|", "/", "—", "\\"};

color  bgColor                = C'212,208,200';
color  fontColor.recordingOn  = Blue;
color  fontColor.recordingOff = Gray;
color  fontColor.notAvailable = Red;
string fontName               = "Tahoma";
int    fontSize               = 10;

int    tickTimerId;                                                  // ID des TickTimers des Charts


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Arraygrößen initialisieren
   int size = ArraySize(symbols);
   ArrayResize(isEnabled  , size);
   ArrayResize(isAvailable, size);
   ArrayResize(index      , size);
   ArrayResize(index.last , size);
   ArrayResize(isRecording, size);
   ArrayResize(hSet       , size);
   ArrayResize(labels     , size);


   // (2) Parameterauswertung
   isEnabled[I_AUDLFX] = AUDLFX.Enabled;
   isEnabled[I_CADLFX] = CADLFX.Enabled;
   isEnabled[I_CHFLFX] = CHFLFX.Enabled;
   isEnabled[I_EURLFX] = EURLFX.Enabled;
   isEnabled[I_GBPLFX] = GBPLFX.Enabled;
   isEnabled[I_JPYLFX] = JPYLFX.Enabled;
   isEnabled[I_NZDLFX] = NZDLFX.Enabled;
   isEnabled[I_USDLFX] = USDLFX.Enabled;
   isEnabled[I_EURX  ] =   EURX.Enabled;
   isEnabled[I_USDX  ] =   USDX.Enabled;

   if (Recording.Enabled) {
      int recordedSymbols;
      isRecording[I_AUDLFX] = AUDLFX.Enabled; recordedSymbols += AUDLFX.Enabled;
      isRecording[I_CADLFX] = CADLFX.Enabled; recordedSymbols += CADLFX.Enabled;
      isRecording[I_CHFLFX] = CHFLFX.Enabled; recordedSymbols += CHFLFX.Enabled;
      isRecording[I_EURLFX] = EURLFX.Enabled; recordedSymbols += EURLFX.Enabled;
      isRecording[I_GBPLFX] = GBPLFX.Enabled; recordedSymbols += GBPLFX.Enabled;
      isRecording[I_JPYLFX] = JPYLFX.Enabled; recordedSymbols += JPYLFX.Enabled;
      isRecording[I_NZDLFX] = NZDLFX.Enabled; recordedSymbols += NZDLFX.Enabled;
      isRecording[I_USDLFX] = USDLFX.Enabled; recordedSymbols += USDLFX.Enabled;
      isRecording[I_EURX  ] =   EURX.Enabled; recordedSymbols +=   EURX.Enabled;
      isRecording[I_USDX  ] =   USDX.Enabled; recordedSymbols +=   USDX.Enabled;

      if (recordedSymbols > 7) {                                     // Je MQL-Modul können maximal 64 Dateien gleichzeitig offen sein (entspricht 7 Instrumenten).
         for (int i=ArraySize(isRecording)-1; i >= 0; i--) {
            if (isRecording[i]) {
               isRecording[i] = false;
               recordedSymbols--;
               if (recordedSymbols <= 7)
                  break;
            }
         }
      }
   }


   // (3) Serververzeichnis für Recording aus Namen des Indikators ableiten
   if (__NAME__ != "LFX-Recorder") {
      string suffix = StringRightFrom(__NAME__, "LFX-Recorder");
      if (!StringLen(suffix))            suffix = __NAME__;
      if (StringStartsWith(suffix, ".")) suffix = StringRight(suffix, -1);
      serverName = serverName +"."+ suffix;
   }


   // (4) Anzeigen initialisieren
   CreateLabels();


   // (5) TradeAccount und Status für Limit-Überwachung initialisieren
   if (!InitTradeAccount())     return(last_error);
   if (!UpdateAccountDisplay()) return(last_error);


   // (6) Limitüberwachung initialisieren
   if (AUDLFX.Enabled) {}     // Anzeige: {Symbol}: [off | n/a]
   if (CADLFX.Enabled) {}     // wenn *.Enabled, aktive Limits anzeigen
   if (CHFLFX.Enabled) {}
   if (EURLFX.Enabled) {}
   if (GBPLFX.Enabled) {}
   if (JPYLFX.Enabled) {}
   if (NZDLFX.Enabled) {}
   if (USDLFX.Enabled) {}
   if (  EURX.Enabled) {}
   if (  USDX.Enabled) {}


   // (7) Chart-Ticker installieren
   if (!This.IsTesting()) /*&&*/ if (!StringStartsWithI(GetServerName(), "MyFX-")) {
      int hWnd    = WindowHandleEx(NULL); if (!hWnd) return(last_error);
      int millis  = 500;
      int timerId = SetupTickTimer(hWnd, millis, NULL);
      if (!timerId) return(catch("onInit(2)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);

   int size = ArraySize(hSet);
   for (int i=0; i < size; i++) {
      if (hSet[i] != 0) {
         if (!HistorySet.Close(hSet[i])) return(!SetLastError(history.GetLastError()));
         hSet[i] = NULL;
      }
   }

   // Chart-Ticker deinstallieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (1 || false)
      UpdateInfos();
   return(last_error);



   // (1) prüfen, ob alle Daten für diesen Index verfügbar sind
   if (USDLFX.Enabled) {
      if (USDLFX.IsAvailable) {
         // Index berechnen
         // Limits prüfen und bei Erreichen Action auslösen
         // Index speichern
      }
      // Index anzeigen:   {Symbol}: [n/a | {value}]
   }

   // (2) regelmäßig prüfen, ob sich die Limite geändert haben (nicht bei jedem Tick)
}


/**
 * Erzeugt und initialisiert die Textlabel der einzelnen Anzeigen.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   // (1) TradeAccount-Label
   label.tradeAccount = __NAME__ +".TradeAccount";
   if (ObjectFind(label.tradeAccount) == 0)
      ObjectDelete(label.tradeAccount);
   if (ObjectCreate(label.tradeAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.tradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.tradeAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (label.tradeAccount, OBJPROP_YDISTANCE, 4);
      ObjectSetText(label.tradeAccount, " ", 1);
      ObjectRegister(label.tradeAccount);
   }
   else GetLastError();


   // (2) Index-Anzeige
   int counter = 10;                                                 // Zählervariable für eindeutige Label, mindestens zweistellig
   // Hintergrund-Rechtecke
   string label = StringConcatenate(__NAME__, ".", counter, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 42);
      ObjectSet    (label, OBJPROP_YDISTANCE, 56);
      ObjectSetText(label, "g", 136, "Webdings", bgColor);
      ObjectRegister(label);
   }
   else GetLastError();

   counter++;
   label = StringConcatenate(__NAME__, ".", counter, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 13);
      ObjectSet    (label, OBJPROP_YDISTANCE, 56);
      ObjectSetText(label, "g", 136, "Webdings", bgColor);
      ObjectRegister(label);
   }
   else GetLastError();

   int   yCoord    = 58;
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);

   // Animation
   counter++;
   label = StringConcatenate(__NAME__, ".", counter, ".Header.animation");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 204   );
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, label.animation.chars[0], fontSize, fontName, fontColor);
      ObjectRegister(label);
      label.animation = label;
   }
   else GetLastError();

   // Recording-Status
   label = StringConcatenate(__NAME__, ".", counter, ".Recording.status");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 19);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
         string text = ifString(Recording.Enabled, "Recording to:  "+ serverName, "Recording:  off");
      ObjectSetText(label, text, fontSize, fontName, fontColor);
      ObjectRegister(label);
   }
   else GetLastError();

   // Datenzeilen
   yCoord += 16;
   for (int i=0; i < ArraySize(symbols); i++) {
      fontColor = ifInt(isRecording[i], fontColor.recordingOn, fontColor.recordingOff);
      counter++;

      // Symbol
      label = StringConcatenate(__NAME__, ".", counter, ".", symbols[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 166          );
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, symbols[i] +":", fontSize, fontName, fontColor);
         ObjectRegister(label);
         labels[i] = label;
      }
      else GetLastError();

      // Index
      label = StringConcatenate(labels[i], ".quote");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 59);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
            text = ifString(!isEnabled[i], "off", "n/a");
         ObjectSetText(label, text, fontSize, fontName, fontColor);
         ObjectRegister(label);
      }
      else GetLastError();

      // Spread
      label = StringConcatenate(labels[i], ".spread");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 19);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         ObjectRegister(label);
      }
      else GetLastError();
   }

   return(catch("CreateLabels(1)"));
}


/**
 * Berechnet die konfigurierten Indizes und zeigt sie an.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateInfos() {
   double audlfx_Bid, audlfx_Ask;
   double cadlfx_Bid, cadlfx_Ask;
   double chflfx_Bid, chflfx_Ask;
   double eurlfx_Bid, eurlfx_Ask;
   double gbplfx_Bid, gbplfx_Ask;
   double jpylfx_Bid, jpylfx_Ask;
   double nzdlfx_Bid, nzdlfx_Ask;
   double usdlfx_Bid, usdlfx_Ask;
   double eurx_Bid,   eurx_Ask;
   double usdx_Bid,   usdx_Ask;


   // USDLFX (als Berechnungsgrundlage für alle anderen Indizes zuerst)
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2;

   isAvailable[I_USDLFX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
   if (isAvailable[I_USDLFX]) {
      index[I_USDLFX] = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
      usdlfx_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
      usdlfx_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
   }

   // AUDLFX
   isAvailable[I_AUDLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_AUDLFX]) {
      index[I_AUDLFX] = index[I_USDLFX] * audusd;
      audlfx_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
      audlfx_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
   }

   // CADLFX
   isAvailable[I_CADLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_CADLFX]) {
      index[I_CADLFX] = index[I_USDLFX] / usdcad;
      cadlfx_Bid      = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
      cadlfx_Ask      = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
   }

   // CHFLFX
   isAvailable[I_CHFLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_CHFLFX]) {
      index[I_CHFLFX] = index[I_USDLFX] / usdchf;
      chflfx_Bid      = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
      chflfx_Ask      = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
   }
   /*
   chfjpy = usdjpy / usdchf
   audchf = audusd * usdchf
   cadchf = usdchf / usdcad
   eurchf = eurusd * usdchf
   gbpchf = gbpusd * usdchf


   CHFLFX: Herleitung der Gleichheit des Index bei Berechnung über USDLFX bzw. die beteiligten Crosses
   ===================================================================================================

            |                   chfjpy                   |
   CHFLFX = | ------------------------------------------ | ^ 1/7
            | audchf * cadchf * eurchf * gbpchf * usdchf |


            |                                (usdjpy/usdchf)                                 |
          = | ------------------------------------------------------------------------------ | ^ 1/7
            | (audusd*usdchf) * (usdchf/usdcad) * (eurusd*usdchf) * (gbpusd*usdchf) * usdchf |


            |                                         usdjpy                                          |
          = | --------------------------------------------------------------------------------------- | ^ 1/7
            | usdchf * audusd * usdchf * (usdchf/usdcad) * eurusd * usdchf * gbpusd * usdchf * usdchf |


            |                                 usdjpy * usdcad                                 |
          = | ------------------------------------------------------------------------------- | ^ 1/7
            | usdchf * audusd * usdchf * usdchf * eurusd * usdchf * gbpusd * usdchf * usdchf  |


            |    1           usdcad * usdjpy      |
          = | -------- * ------------------------ | ^ 1/7
            | usdchf^6   audusd * eurusd * gbpusd |


            |      usdchf * usdcad * usdjpy       |
          = | ----------------------------------- | ^ 1/7
            | usdchf^7 * audusd * eurusd * gbpusd |


            |     1    |         | usdcad * usdchf * usdjpy |
          = | -------- | ^ 1/7 * | ------------------------ | ^ 1/7
            | usdchf^7 |         | audusd * eurusd * gbpusd |


            | usdcad * usdchf * usdjpy |
          = | ------------------------ | ^ 1/7 / usdchf              // der erste Term entspricht dem USDLFX
            | audusd * eurusd * gbpusd |


          =   USDLFX / usdchf
   */

   // EURLFX
   isAvailable[I_EURLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_EURLFX]) {
      index[I_EURLFX] = index[I_USDLFX] * eurusd;
      eurlfx_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
      eurlfx_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
   }

   // GBPLFX
   isAvailable[I_GBPLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_GBPLFX]) {
      index[I_GBPLFX] = index[I_USDLFX] * gbpusd;
      gbplfx_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
      gbplfx_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
   }

   // JPYLFX
   isAvailable[I_JPYLFX] = isAvailable[I_USDLFX];
   if (isAvailable[I_JPYLFX]) {
      index[I_JPYLFX] = 100 * index[I_USDLFX] / usdjpy;
      jpylfx_Bid      = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
      jpylfx_Ask      = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
   }

   // NZDLFX
   double nzdusd_Bid = MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask = MarketInfo("NZDUSD", MODE_ASK), nzdusd = (nzdusd_Bid + nzdusd_Ask)/2;

   isAvailable[I_NZDLFX] = (isAvailable[I_USDLFX] && nzdusd_Bid);
   if (isAvailable[I_NZDLFX]) {
      index[I_NZDLFX] = index[I_USDLFX] * nzdusd;
      nzdlfx_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
      nzdlfx_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
   }
   /*
   usdcad = nzdcad / nzdusd
   usdchf = nzdchf / nzdusd
   usdjpy = nzdjpy / nzdusd
   audusd = audnzd * nzdusd
   eurusd = eurnzd * nzdusd
   gbpusd = gbpnzd * nzdusd


   NZDLFX: Herleitung der Gleichheit von NZDLFX und NZD-FX7
   ========================================================

   NZDLFX =   USDLFX * nzdusd

            | usdcad * usdchf * usdjpy |
          = | ------------------------ | ^ 1/7 * nzdusd
            | audusd * eurusd * gbpusd |


            | usdcad * usdchf * usdjpy |
          = | ------------------------ | ^ 1/7 * (nzdusd^7) ^ 1/7
            | audusd * eurusd * gbpusd |


            | usdcad * usdchf * usdjpy * nzdusd^7 |
          = | ----------------------------------- | ^ 1/7
            |      audusd * eurusd * gbpusd       |


            | (nzdcad/nzdusd) * (nzdchf/nzdusd) * (nzdjpy/nzdusd) * nzdusd^7 |
          = | -------------------------------------------------------------- | ^ 1/7
            |      (audnzd*nzdusd) * (eurnzd*nzdusd) * (gbpnzd*nzdusd)       |


            | (nzdcad/nzdusd) * (nzdchf/nzdusd) * (nzdjpy/nzdusd) * nzdusd^7 |
          = | -------------------------------------------------------------- | ^ 1/7
            |               audnzd * eurnzd * gbpnzd * nzdusd^3              |


            | nzdcad   nzdchf   nzdjpy               nzdusd^7                |
          = | ------ * ------ * ------ * ----------------------------------- | ^ 1/7
            | nzdusd   nzdusd   nzdusd   audnzd * eurnzd * gbpnzd * nzdusd^3 |


            | nzdcad * nzdchf * nzdjpy * nzdusd^7 |
          = | ----------------------------------- | ^ 1/7
            | audnzd * eurnzd * gbpnzd * nzdusd^6 |


            | nzdcad * nzdchf * nzdjpy * nzdusd |
          = | --------------------------------- | ^ 1/7
            |      audnzd * eurnzd * gbpnzd     |


          = NZD-FX7
  */

   // USDX (vor EURX, da USDSEK Berechnungsgrundlage für EURX ist)
   double usdsek_Bid = MarketInfo("USDSEK", MODE_BID), usdsek_Ask = MarketInfo("USDSEK", MODE_ASK), usdsek = (usdsek_Bid + usdsek_Ask)/2;

   isAvailable[I_USDX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
   if (isAvailable[I_USDX]) {
      index[I_USDX] = 50.14348112 * (MathPow(usdcad    , 0.091) * MathPow(usdchf    , 0.036) * MathPow(usdjpy    , 0.136) * MathPow(usdsek    , 0.042)) / (MathPow(eurusd    , 0.576) * MathPow(gbpusd    , 0.119));
      usdx_Bid      = 50.14348112 * (MathPow(usdcad_Bid, 0.091) * MathPow(usdchf_Bid, 0.036) * MathPow(usdjpy_Bid, 0.136) * MathPow(usdsek_Bid, 0.042)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
      usdx_Ask      = 50.14348112 * (MathPow(usdcad_Ask, 0.091) * MathPow(usdchf_Ask, 0.036) * MathPow(usdjpy_Ask, 0.136) * MathPow(usdsek_Ask, 0.042)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
   }
   /*
   USDX = 50.14348112 * EURUSD^-0.576 * USDJPY^0.136 * GBPUSD^-0.119 * USDCAD^0.091 * USDSEK^0.042 * USDCHF^0.036


                        USDCAD^0.091 * USDCHF^0.036 * USDJPY^0.136 * USDSEK^0.042
   USDX = 50.14348112 * ---------------------------------------------------------
                                       EURUSD^0.576 * GBPUSD^0.119
   */

   // EURX
   isAvailable[I_EURX] = (usdchf_Bid&& usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
   if (isAvailable[I_EURX]) {
      double eurchf = usdchf * eurusd;
      double eurgbp = eurusd / gbpusd;
      double eurjpy = usdjpy * eurusd;
      double eursek = usdsek * eurusd;
      index[I_EURX] = 34.38805726 * MathPow(eurchf, 0.1113) * MathPow(eurgbp, 0.3056) * MathPow(eurjpy, 0.1891) * MathPow(eursek, 0.0785) * MathPow(eurusd, 0.3155);
      eurx_Bid      = 0;                  // TODO
      eurx_Ask      = 0;                  // TODO
   }
   /*
   EURX = 34.38805726 * EURCHF^0.1113 * EURGBP^0.3056 * EURJPY^0.1891 * EURSEK^0.0785 * EURUSD^0.3155
   */


   // Fehlerbehandlung
   int error = GetLastError();            // TODO: ERS_HISTORY_UPDATE für welches Symbol,Timeframe ???
   if (error == ERS_HISTORY_UPDATE)                                return(!SetLastError(error));
   if (IsError(error)) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) return(!catch("UpdateInfos(1)", error));


   // Farben definieren
   color fontColor.AUDLFX = ifInt(isRecording[I_AUDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.CADLFX = ifInt(isRecording[I_CADLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.CHFLFX = ifInt(isRecording[I_CHFLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.EURLFX = ifInt(isRecording[I_EURLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.GBPLFX = ifInt(isRecording[I_GBPLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.JPYLFX = ifInt(isRecording[I_JPYLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.NZDLFX = ifInt(isRecording[I_NZDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.USDLFX = ifInt(isRecording[I_USDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.EURX   = ifInt(isRecording[I_EURX  ], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.USDX   = ifInt(isRecording[I_USDX  ], fontColor.recordingOn, fontColor.recordingOff);


   // Index-Anzeige
   string sValue;
   if (AUDLFX.Enabled) { if (isAvailable[I_AUDLFX]) sValue = NumberToStr(NormalizeDouble(index[I_AUDLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_AUDLFX] +".quote",  sValue, fontSize, fontName, fontColor.AUDLFX); }
   if (CADLFX.Enabled) { if (isAvailable[I_CADLFX]) sValue = NumberToStr(NormalizeDouble(index[I_CADLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_CADLFX] +".quote",  sValue, fontSize, fontName, fontColor.CADLFX); }
   if (CHFLFX.Enabled) { if (isAvailable[I_CHFLFX]) sValue = NumberToStr(NormalizeDouble(index[I_CHFLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_CHFLFX] +".quote",  sValue, fontSize, fontName, fontColor.CHFLFX); }
   if (EURLFX.Enabled) { if (isAvailable[I_EURLFX]) sValue = NumberToStr(NormalizeDouble(index[I_EURLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_EURLFX] +".quote",  sValue, fontSize, fontName, fontColor.EURLFX); }
   if (GBPLFX.Enabled) { if (isAvailable[I_GBPLFX]) sValue = NumberToStr(NormalizeDouble(index[I_GBPLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_GBPLFX] +".quote",  sValue, fontSize, fontName, fontColor.GBPLFX); }
   if (JPYLFX.Enabled) { if (isAvailable[I_JPYLFX]) sValue = NumberToStr(NormalizeDouble(index[I_JPYLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_JPYLFX] +".quote",  sValue, fontSize, fontName, fontColor.JPYLFX); }
   if (NZDLFX.Enabled) { if (isAvailable[I_NZDLFX]) sValue = NumberToStr(NormalizeDouble(index[I_NZDLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_NZDLFX] +".quote",  sValue, fontSize, fontName, fontColor.NZDLFX); }
   if (USDLFX.Enabled) { if (isAvailable[I_USDLFX]) sValue = NumberToStr(NormalizeDouble(index[I_USDLFX], 5), ".4'"); else sValue = "n/a"; ObjectSetText(labels[I_USDLFX] +".quote",  sValue, fontSize, fontName, fontColor.USDLFX); }
   if (EURX.Enabled  ) { if (isAvailable[I_EURX  ]) sValue = NumberToStr(NormalizeDouble(index[I_EURX  ], 3), ".2'"); else sValue = "n/a"; ObjectSetText(labels[I_EURX  ] +".quote",  sValue, fontSize, fontName, fontColor.EURX  ); }
   if (USDX.Enabled  ) { if (isAvailable[I_USDX  ]) sValue = NumberToStr(NormalizeDouble(index[I_USDX  ], 3), ".2'"); else sValue = "n/a"; ObjectSetText(labels[I_USDX  ] +".quote",  sValue, fontSize, fontName, fontColor.USDX  ); }

   // Spread-Anzeige
   if (AUDLFX.Enabled) { if (isAvailable[I_AUDLFX]) sValue = "("+ DoubleToStr((audlfx_Ask-audlfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_AUDLFX] +".spread", sValue, fontSize, fontName, fontColor.AUDLFX); }
   if (CADLFX.Enabled) { if (isAvailable[I_CADLFX]) sValue = "("+ DoubleToStr((cadlfx_Ask-cadlfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_CADLFX] +".spread", sValue, fontSize, fontName, fontColor.CADLFX); }
   if (CHFLFX.Enabled) { if (isAvailable[I_CHFLFX]) sValue = "("+ DoubleToStr((chflfx_Ask-chflfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_CHFLFX] +".spread", sValue, fontSize, fontName, fontColor.CHFLFX); }
   if (EURLFX.Enabled) { if (isAvailable[I_EURLFX]) sValue = "("+ DoubleToStr((eurlfx_Ask-eurlfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_EURLFX] +".spread", sValue, fontSize, fontName, fontColor.EURLFX); }
   if (GBPLFX.Enabled) { if (isAvailable[I_GBPLFX]) sValue = "("+ DoubleToStr((gbplfx_Ask-gbplfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_GBPLFX] +".spread", sValue, fontSize, fontName, fontColor.GBPLFX); }
   if (JPYLFX.Enabled) { if (isAvailable[I_JPYLFX]) sValue = "("+ DoubleToStr((jpylfx_Ask-jpylfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_JPYLFX] +".spread", sValue, fontSize, fontName, fontColor.JPYLFX); }
   if (NZDLFX.Enabled) { if (isAvailable[I_NZDLFX]) sValue = "("+ DoubleToStr((nzdlfx_Ask-nzdlfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_NZDLFX] +".spread", sValue, fontSize, fontName, fontColor.NZDLFX); }
   if (USDLFX.Enabled) { if (isAvailable[I_USDLFX]) sValue = "("+ DoubleToStr((usdlfx_Ask-usdlfx_Bid)*10000, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_USDLFX] +".spread", sValue, fontSize, fontName, fontColor.USDLFX); }
   if (EURX.Enabled  ) { if (isAvailable[I_EURX  ]) sValue = "("+ DoubleToStr((  eurx_Ask-  eurx_Bid)*  100, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_EURX  ] +".spread", sValue, fontSize, fontName, fontColor.EURX  ); }
   if (USDX.Enabled  ) { if (isAvailable[I_USDX  ]) sValue = "("+ DoubleToStr((  usdx_Ask-  usdx_Bid)*  100, 1) +")"; else sValue = " ";   ObjectSetText(labels[I_USDX  ] +".spread", sValue, fontSize, fontName, fontColor.USDX  ); }


   // Animation
   static int size = -1; if (size==-1) size = ArraySize(label.animation.chars);
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);
   ObjectSetText(label.animation, label.animation.chars[Tick % size], fontSize, fontName, fontColor);


   // Indizes aufzeichnen
   if (!RecordLfxIndices())
      return(false);

   return(!catch("UpdateInfos(2)"));
}


/**
 * Zeichnet die Daten der LFX-Indizes auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordLfxIndices() {
   if (IsTesting())
      return(true);

   int size = ArraySize(hSet);

   for (int i=0; i < size; i++) {
      if (isRecording[i]) /*&&*/ if (isAvailable[i]) {
         double tickValue     = NormalizeDouble(index[i], digits[i]);
         double lastTickValue = index.last[i];

         // Virtuelle Ticks werden nur dann aufgezeichnet, wenn sich der Indexwert geändert hat.
         bool skipTick = false;
         if (Tick.isVirtual) {
            skipTick = (!lastTickValue || EQ(tickValue, lastTickValue, digits[i]));
            //if (skipTick) debug("RecordLfxIndices(1)  zTick="+ zTick +"  skipping virtual "+ symbols[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +"  lastTick="+ NumberToStr(lastTickValue, "."+ (digits[i]-1) +"'") +"  tick"+ ifString(EQ(tickValue, lastTickValue, digits[i]), "==", "!=") +"lastTick");
         }

         if (!skipTick) {
            if (!lastTickValue) {
               skipTick = true;
               //debug("RecordLfxIndices(2)  zTick="+ zTick +"  skipping first "+ symbols[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +" (no last tick)");
            }
            else if (MathAbs(tickValue/lastTickValue - 1.0) > 0.005) {
               skipTick = true;
               warn("RecordLfxIndices(3)  zTick="+ zTick +"  skipping supposed "+ symbols[i] +" mis-tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +" (lastTick: "+ NumberToStr(lastTickValue, "."+ (digits[i]-1) +"'") +")");
            }
         }

         if (!skipTick) {
            //debug("RecordLfxIndices(4)  zTick="+ zTick +"  recording "+ symbols[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'"));
            if (!hSet[i]) {
               string description = names[i] + ifString(i==I_EURX || i==I_USDX, " Index (ICE)", " Index (LiteForex)");
               int    format      = 400;

               hSet[i] = HistorySet.Get(symbols[i], serverName);
               if (hSet[i] == -1)
                  hSet[i] = HistorySet.Create(symbols[i], description, digits[i], format, serverName);
               if (!hSet[i]) return(!SetLastError(history.GetLastError()));
            }

            int flags = NULL;
            if (!HistorySet.AddTick(hSet[i], Tick.Time, tickValue, flags)) return(!SetLastError(history.GetLastError()));
         }

         index.last[i] = tickValue;
      }
   }
   return(true);
}


/**
 * Aktualisiert die Anzeige des TradeAccounts für die Limitüberwachung.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateAccountDisplay() {
   if (mode.remote) {
      string text = "Limits:  "+ tradeAccount.name +", "+ tradeAccount.company +", "+ tradeAccount.number +", "+ tradeAccount.currency;
      ObjectSetText(label.tradeAccount, text, 8, "Arial Fett", ifInt(tradeAccount.type==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
   }
   else {
      ObjectSetText(label.tradeAccount, " ", 1);
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateAccountDisplay(1)", error));
}
