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

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/myfx/LFX_ORDER.mqh>
#include <core/script.ParameterProvider.mqh>


#property indicator_chart_window


string symbols     [] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "EURX", "USDX" };
string names       [] = { "AUD"   , "CAD"   , "CHF"   , "EUR"   , "GBP"   , "JPY"   , "NZD"   , "USD"   , "EURX", "USDX" };
int    digits      [] = { 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 3     , 3      };
double pipSizes    [] = { 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.01  , 0.01   };
string priceFormats[] = { "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.2'", "R.2'" };

bool   isEnabled   [];                                               // ob der Index aktiviert ist: entspricht *.Enabled
bool   isAvailable [];                                               // ob der Indexwert verfügbar ist
double index.bid   [];                                               // Bid des aktuellen Indexwertes
double index.ask   [];                                               // Ask des aktuellen Indexwertes
double index.median[];                                               // Median des aktuellen Indexwertes
double last.median [];                                               // vorheriger Indexwert (Median)

bool   isRecording [];                                               // default: FALSE
int    hSet        [];                                               // HistorySet-Handles
string serverName = "MyFX-Synthetic";                                // Default-Serververzeichnis fürs Recording

int   AUDLFX.orders[][LFX_ORDER.intSize];                            // Array von LFX-Orders
int   CADLFX.orders[][LFX_ORDER.intSize];
int   CHFLFX.orders[][LFX_ORDER.intSize];
int   EURLFX.orders[][LFX_ORDER.intSize];
int   GBPLFX.orders[][LFX_ORDER.intSize];
int   JPYLFX.orders[][LFX_ORDER.intSize];
int   NZDLFX.orders[][LFX_ORDER.intSize];
int   USDLFX.orders[][LFX_ORDER.intSize];
int     EURX.orders[][LFX_ORDER.intSize];
int     USDX.orders[][LFX_ORDER.intSize];

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
   ArrayResize(isEnabled   , size);
   ArrayResize(isAvailable , size);
   ArrayResize(index.bid   , size);
   ArrayResize(index.ask   , size);
   ArrayResize(index.median, size);
   ArrayResize(last.median , size);
   ArrayResize(isRecording , size);
   ArrayResize(hSet        , size);
   ArrayResize(labels      , size);


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


   // (6) Limit-Orders einlesen und Limitüberwachung initialisieren
   if (AUDLFX.Enabled) if (LFX.GetOrders(C_AUD, OF_PENDINGORDER|OF_PENDINGPOSITION, AUDLFX.orders) < 0) return(last_error);
   if (CADLFX.Enabled) if (LFX.GetOrders(C_CAD, OF_PENDINGORDER|OF_PENDINGPOSITION, CADLFX.orders) < 0) return(last_error);
   if (CHFLFX.Enabled) if (LFX.GetOrders(C_CHF, OF_PENDINGORDER|OF_PENDINGPOSITION, CHFLFX.orders) < 0) return(last_error);
   if (EURLFX.Enabled) if (LFX.GetOrders(C_EUR, OF_PENDINGORDER|OF_PENDINGPOSITION, EURLFX.orders) < 0) return(last_error);
   if (GBPLFX.Enabled) if (LFX.GetOrders(C_GBP, OF_PENDINGORDER|OF_PENDINGPOSITION, GBPLFX.orders) < 0) return(last_error);
   if (JPYLFX.Enabled) if (LFX.GetOrders(C_JPY, OF_PENDINGORDER|OF_PENDINGPOSITION, JPYLFX.orders) < 0) return(last_error);
   if (NZDLFX.Enabled) if (LFX.GetOrders(C_NZD, OF_PENDINGORDER|OF_PENDINGPOSITION, NZDLFX.orders) < 0) return(last_error);
   if (USDLFX.Enabled) if (LFX.GetOrders(C_USD, OF_PENDINGORDER|OF_PENDINGPOSITION, USDLFX.orders) < 0) return(last_error);
   //if (EURX.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION,   EURX.orders) < 0) return(last_error);
   //if (USDX.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION,   USDX.orders) < 0) return(last_error);

   if (ArrayRange(AUDLFX.orders, 0) != 0) debug("onInit(1)  AUDLFX limit orders: "+ ArrayRange(AUDLFX.orders, 0));
   if (ArrayRange(CADLFX.orders, 0) != 0) debug("onInit(1)  CADLFX limit orders: "+ ArrayRange(CADLFX.orders, 0));
   if (ArrayRange(CHFLFX.orders, 0) != 0) debug("onInit(1)  CHFLFX limit orders: "+ ArrayRange(CHFLFX.orders, 0));
   if (ArrayRange(EURLFX.orders, 0) != 0) debug("onInit(1)  EURLFX limit orders: "+ ArrayRange(EURLFX.orders, 0));
   if (ArrayRange(GBPLFX.orders, 0) != 0) debug("onInit(1)  GBPLFX limit orders: "+ ArrayRange(GBPLFX.orders, 0));
   if (ArrayRange(JPYLFX.orders, 0) != 0) debug("onInit(1)  JPYLFX limit orders: "+ ArrayRange(JPYLFX.orders, 0));
   if (ArrayRange(NZDLFX.orders, 0) != 0) debug("onInit(1)  NZDLFX limit orders: "+ ArrayRange(NZDLFX.orders, 0));
   if (ArrayRange(USDLFX.orders, 0) != 0) debug("onInit(1)  USDLFX limit orders: "+ ArrayRange(USDLFX.orders, 0));
   if (ArrayRange(  EURX.orders, 0) != 0) debug("onInit(1)    EURX limit orders: "+ ArrayRange(  EURX.orders, 0));
   if (ArrayRange(  USDX.orders, 0) != 0) debug("onInit(1)    USDX limit orders: "+ ArrayRange(  USDX.orders, 0));


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
   QC.StopChannels();
   QC.StopScriptParameterSender();

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
   if (1 && 1) {
      if (!CalculateIndices())   return(last_error);
      if (!ProcessAllLimits())   return(last_error);
      if (!UpdateIndexDisplay()) return(last_error);

      if (Recording.Enabled) {
         if (!RecordIndices())   return(last_error);
      }
   }
   return(last_error);

   // TODO: regelmäßig prüfen, ob sich die Limite geändert haben (nicht bei jedem Tick)
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
      ObjectSet    (label, OBJPROP_XDISTANCE, 41);
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
 * Berechnet die konfigurierten Indizes.
 *
 * @return bool - Erfolgsstatus
 */
bool CalculateIndices() {
   double usdcad_Bid=MarketInfo("USDCAD", MODE_BID), usdcad_Ask=MarketInfo("USDCAD", MODE_ASK), usdcad=(usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid=MarketInfo("USDCHF", MODE_BID), usdchf_Ask=MarketInfo("USDCHF", MODE_ASK), usdchf=(usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid=MarketInfo("USDJPY", MODE_BID), usdjpy_Ask=MarketInfo("USDJPY", MODE_ASK), usdjpy=(usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid=MarketInfo("AUDUSD", MODE_BID), audusd_Ask=MarketInfo("AUDUSD", MODE_ASK), audusd=(audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid=MarketInfo("EURUSD", MODE_BID), eurusd_Ask=MarketInfo("EURUSD", MODE_ASK), eurusd=(eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid=MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask=MarketInfo("GBPUSD", MODE_ASK), gbpusd=(gbpusd_Bid + gbpusd_Ask)/2;


   // (1) LFX-Indizes: USDLFX immer und zuerst, da Berechnungsgrundlage für die anderen Indizes
   isAvailable[I_USDLFX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
   if (isAvailable[I_USDLFX]) {
      last.median [I_USDLFX] = index.median[I_USDLFX];
      index.median[I_USDLFX] = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
      index.bid   [I_USDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
      index.ask   [I_USDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
   }

   if (AUDLFX.Enabled) {
      isAvailable[I_AUDLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_AUDLFX]) {
         last.median [I_AUDLFX] = index.median[I_AUDLFX];
         index.median[I_AUDLFX] = index.median[I_USDLFX] * audusd;
         index.bid   [I_AUDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
         index.ask   [I_AUDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
      }
   }

   if (CADLFX.Enabled) {
      isAvailable[I_CADLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_CADLFX]) {
         last.median [I_CADLFX] = index.median[I_CADLFX];
         index.median[I_CADLFX] = index.median[I_USDLFX] / usdcad;
         index.bid   [I_CADLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
         index.ask   [I_CADLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
      }
   }

   if (CHFLFX.Enabled) {
      isAvailable[I_CHFLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_CHFLFX]) {
         last.median [I_CHFLFX] = index.median[I_CHFLFX];
         index.median[I_CHFLFX] = index.median[I_USDLFX] / usdchf;
         index.bid   [I_CHFLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
         index.ask   [I_CHFLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
      }
   }

   if (EURLFX.Enabled) {
      isAvailable[I_EURLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_EURLFX]) {
         last.median [I_EURLFX] = index.median[I_EURLFX];
         index.median[I_EURLFX] = index.median[I_USDLFX] * eurusd;
         index.bid   [I_EURLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
         index.ask   [I_EURLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
      }
   }

   if (GBPLFX.Enabled) {
      isAvailable[I_GBPLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_GBPLFX]) {
         last.median [I_GBPLFX] = index.median[I_GBPLFX];
         index.median[I_GBPLFX] = index.median[I_USDLFX] * gbpusd;
         index.bid   [I_GBPLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
         index.ask   [I_GBPLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
      }
   }

   if (JPYLFX.Enabled) {
      isAvailable[I_JPYLFX] = isAvailable[I_USDLFX];
      if (isAvailable[I_JPYLFX]) {
         last.median [I_JPYLFX] = index.median[I_JPYLFX];
         index.median[I_JPYLFX] = 100 * index.median[I_USDLFX] / usdjpy;
         index.bid   [I_JPYLFX] = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
         index.ask   [I_JPYLFX] = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
      }
   }

   if (NZDLFX.Enabled) {
      double nzdusd_Bid=MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask=MarketInfo("NZDUSD", MODE_ASK), nzdusd=(nzdusd_Bid + nzdusd_Ask)/2;
      isAvailable[I_NZDLFX] = (isAvailable[I_USDLFX] && nzdusd_Bid);
      if (isAvailable[I_NZDLFX]) {
         last.median [I_NZDLFX] = index.median[I_NZDLFX];
         index.median[I_NZDLFX] = index.median[I_USDLFX] * nzdusd;
         index.bid   [I_NZDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
         index.ask   [I_NZDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
      }
   }


   double usdsek_Bid = MarketInfo("USDSEK", MODE_BID), usdsek_Ask = MarketInfo("USDSEK", MODE_ASK), usdsek = (usdsek_Bid + usdsek_Ask)/2;


   // (2) ICE-Indizes
   if (EURX.Enabled) {
      isAvailable[I_EURX] = (usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
      if (isAvailable[I_EURX]) {
         double eurchf = usdchf * eurusd;
         double eurgbp = eurusd / gbpusd;
         double eurjpy = usdjpy * eurusd;
         double eursek = usdsek * eurusd;
         //             EURX  = 34.38805726 * EURUSD^0.3155 * EURGBP^0.3056 * EURJPY^0.1891 * EURCHF^0.1113 * EURSEK^0.0785
         last.median [I_EURX] = index.median[I_EURX];
         index.median[I_EURX] = 34.38805726 * MathPow(eurusd, 0.3155) * MathPow(eurgbp, 0.3056) * MathPow(eurjpy, 0.1891) * MathPow(eurchf, 0.1113) * MathPow(eursek, 0.0785);
         index.bid   [I_EURX] = 0;                  // TODO
         index.ask   [I_EURX] = 0;                  // TODO
      }
   }

   if (USDX.Enabled) {
      isAvailable[I_USDX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
      if (isAvailable[I_USDX]) {
         //             USDX  = 50.14348112 * EURUSD^-0.576 * USDJPY^0.136 * GBPUSD^-0.119 * USDCAD^0.091 * USDSEK^0.042 * USDCHF^0.036
         last.median [I_USDX] = index.median[I_USDX];
         index.median[I_USDX] = 50.14348112 * (MathPow(usdjpy    , 0.136) * MathPow(usdcad    , 0.091) * MathPow(usdsek    , 0.042) * MathPow(usdchf    , 0.036)) / (MathPow(eurusd    , 0.576) * MathPow(gbpusd    , 0.119));
         index.bid   [I_USDX] = 50.14348112 * (MathPow(usdjpy_Bid, 0.136) * MathPow(usdcad_Bid, 0.091) * MathPow(usdsek_Bid, 0.042) * MathPow(usdchf_Bid, 0.036)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
         index.ask   [I_USDX] = 50.14348112 * (MathPow(usdjpy_Ask, 0.136) * MathPow(usdcad_Ask, 0.091) * MathPow(usdsek_Ask, 0.042) * MathPow(usdchf_Ask, 0.036)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
      }
   }


   // (3) Fehlerbehandlung
   int error = GetLastError(); if (!error) return(true);

   debug("CalculateIndices(1)", error);
   if (error == ERR_SYMBOL_NOT_AVAILABLE)  return(true);
   if (error == ERS_HISTORY_UPDATE      )  return(!SetLastError(error)); // = true

   return(!catch("CalculateIndices(2)", error));

   /*
   Herleitung der Übereinstimmung eines über den USDLFX oder die beteiligten Crosses berechneten LFX-Index
   =======================================================================================================
   chfjpy = usdjpy / usdchf
   audchf = audusd * usdchf
   cadchf = usdchf / usdcad
   eurchf = eurusd * usdchf
   gbpchf = gbpusd * usdchf

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


   Herleitung der Übereinstimmung von NZDLFX und NZD-FX7
   =====================================================
   usdcad = nzdcad / nzdusd
   usdchf = nzdchf / nzdusd
   usdjpy = nzdjpy / nzdusd
   audusd = audnzd * nzdusd
   eurusd = eurnzd * nzdusd
   gbpusd = gbpnzd * nzdusd


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
}


/**
 * Prüft die aktiven Limite aller Symbole.
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessAllLimits() {
   // Nur die LimitOrders, deren entsprechender Indexwert sich geändert hat, werden geprüft.

   // LFX-Indizes
   if (isAvailable[I_AUDLFX]) if (!EQ(index.median[I_AUDLFX], last.median[I_AUDLFX], digits[I_AUDLFX])) if (!ProcessLimits(AUDLFX.orders, I_AUDLFX)) return(false);
   if (isAvailable[I_CADLFX]) if (!EQ(index.median[I_CADLFX], last.median[I_CADLFX], digits[I_CADLFX])) if (!ProcessLimits(CADLFX.orders, I_CADLFX)) return(false);
   if (isAvailable[I_CHFLFX]) if (!EQ(index.median[I_CHFLFX], last.median[I_CHFLFX], digits[I_CHFLFX])) if (!ProcessLimits(CHFLFX.orders, I_CHFLFX)) return(false);
   if (isAvailable[I_EURLFX]) if (!EQ(index.median[I_EURLFX], last.median[I_EURLFX], digits[I_EURLFX])) if (!ProcessLimits(EURLFX.orders, I_EURLFX)) return(false);
   if (isAvailable[I_GBPLFX]) if (!EQ(index.median[I_GBPLFX], last.median[I_GBPLFX], digits[I_GBPLFX])) if (!ProcessLimits(GBPLFX.orders, I_GBPLFX)) return(false);
   if (isAvailable[I_JPYLFX]) if (!EQ(index.median[I_JPYLFX], last.median[I_JPYLFX], digits[I_JPYLFX])) if (!ProcessLimits(JPYLFX.orders, I_JPYLFX)) return(false);
   if (isAvailable[I_NZDLFX]) if (!EQ(index.median[I_NZDLFX], last.median[I_NZDLFX], digits[I_NZDLFX])) if (!ProcessLimits(NZDLFX.orders, I_NZDLFX)) return(false);
   if (isAvailable[I_USDLFX]) if (!EQ(index.median[I_USDLFX], last.median[I_USDLFX], digits[I_USDLFX])) if (!ProcessLimits(USDLFX.orders, I_USDLFX)) return(false);

   // ICE-Indizes
   if (isAvailable[I_EURX  ]) if (!EQ(index.median[I_EURX  ], last.median[I_EURX  ], digits[I_EURX  ])) if (!ProcessLimits(EURX.orders,   I_EURX)  ) return(false);
   if (isAvailable[I_USDX  ]) if (!EQ(index.median[I_USDX  ], last.median[I_USDX  ], digits[I_USDX  ])) if (!ProcessLimits(USDX.orders,   I_USDX)  ) return(false);

   return(true);
}


/**
 * Prüft die aktiven Limite der übergebenen Orders und verschickt bei Erreichen entsprechende TradeCommands.
 *
 * @param  _In_Out_ LFX_ORDER orders[]  - Array von LFX_ORDERs
 * @param  _In_     int       symbolIdx - Index des Symbols des Orderdatensatzes (entspricht dem Index in den übrigen globalen Arrays)
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessLimits(/*LFX_ORDER*/int orders[][], int symbolIdx) {
   int size = ArrayRange(orders, 0);

   // Ursprünglich enthält orders[] nur PendingOrders und PendingPositions, nach Limitausführung können das offene oder geschlossene Positionen werden.
   for (int i=0; i < size; i++) {
      if (!los.IsPendingOrder(orders, i)) /*&&*/ if (!los.IsPendingPosition(orders, i))
         continue;

      // Limite gegen Median-Preis prüfen und keine Prüfung von Profit-Beträgen
      int result = LFX.CheckLimits(orders, i, index.median[symbolIdx], index.median[symbolIdx], EMPTY_VALUE); if (!result) return(false);
      if (result == NO_LIMIT_TRIGGERED)
         continue;

      // Order ausführen
      if (LFX.ExecuteLimitOrder(lfxOrders, i, result)) return(false);
   }
   return(true);
}


/**
 * Aktualisiert die Index-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateIndexDisplay() {
   //if (!IsChartVisible()) return(true);                            // TODO: Anzeige nur dann aktualisieren, wenn der Chart sichtbar ist.

   // Animation
   int   chars     = ArraySize(label.animation.chars);
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);
   ObjectSetText(label.animation, label.animation.chars[Tick % chars], fontSize, fontName, fontColor);

   // Werte
   int    size = ArraySize(symbols);
   string sIndex, sSpread;

   for (int i=0; i < size; i++) {
      if (isEnabled[i]) {
         if (isAvailable[i]) {
            sIndex  = NumberToStr(NormalizeDouble(index.median[i], digits[i]), priceFormats[i]);
            sSpread = "("+ DoubleToStr((index.ask[i]-index.bid[i])/pipSizes[i], 1) +")";
         }
         else {
            sIndex  = "n/a";
            sSpread = " ";
         }
         fontColor = ifInt(isRecording[i], fontColor.recordingOn, fontColor.recordingOff);
         ObjectSetText(labels[i] +".quote",  sIndex,  fontSize, fontName, fontColor);
         ObjectSetText(labels[i] +".spread", sSpread, fontSize, fontName, fontColor);
      }
   }
   return(!catch("UpdateIndexDisplay(1)"));
}


/**
 * Zeichnet die Daten der LFX-Indizes auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordIndices() {
   int size = ArraySize(symbols);

   for (int i=0; i < size; i++) {
      if (isRecording[i] && isAvailable[i]) {
         double value     = NormalizeDouble(index.median[i], digits[i]);
         double lastValue = last.median[i];

         // Virtuelle Ticks werden nur aufgezeichnet, wenn sich der Indexwert geändert hat.
         bool skipTick = false;
         if (Tick.isVirtual) {
            skipTick = (!lastValue || EQ(value, lastValue, digits[i]));
            //if (skipTick) debug("RecordIndices(1)  zTick="+ zTick +"  skipping virtual "+ symbols[i] +" tick "+ NumberToStr(value, "."+ (digits[i]-1) +"'") +"  lastTick="+ NumberToStr(lastValue, "."+ (digits[i]-1) +"'") +"  tick"+ ifString(EQ(value, lastValue, digits[i]), "==", "!=") +"lastTick");
         }

         if (!skipTick) {
            if (!lastValue) {
               skipTick = true;
               //debug("RecordIndices(2)  zTick="+ zTick +"  skipping first "+ symbols[i] +" tick "+ NumberToStr(value, "."+ (digits[i]-1) +"'") +" (no last tick)");
            }
            else if (MathAbs(value/lastValue - 1.0) > 0.005) {
               skipTick = true;
               warn("RecordIndices(3)  zTick="+ zTick +"  skipping supposed "+ symbols[i] +" mis-tick "+ NumberToStr(value, "."+ (digits[i]-1) +"'") +" (lastTick: "+ NumberToStr(lastValue, "."+ (digits[i]-1) +"'") +")");
            }
         }

         if (!skipTick) {
            //debug("RecordIndices(4)  zTick="+ zTick +"  recording "+ symbols[i] +" tick "+ NumberToStr(value, "."+ (digits[i]-1) +"'"));
            if (!hSet[i]) {
               string description = names[i] + ifString(i==I_EURX || i==I_USDX, " Index (ICE)", " Index (LiteForex)");
               int    format      = 400;

               hSet[i] = HistorySet.Get(symbols[i], serverName);
               if (hSet[i] == -1)
                  hSet[i] = HistorySet.Create(symbols[i], description, digits[i], format, serverName);
               if (!hSet[i]) return(!SetLastError(history.GetLastError()));
            }

            int flags = NULL;
            if (!HistorySet.AddTick(hSet[i], Tick.Time, value, flags)) return(!SetLastError(history.GetLastError()));
         }
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
