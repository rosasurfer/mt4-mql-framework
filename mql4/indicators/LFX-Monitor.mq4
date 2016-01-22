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


string symbols    [] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "EURX", "USDX" };
string names      [] = { "AUD"   , "CAD"   , "CHF"   , "EUR"   , "GBP"   , "JPY"   , "NZD"   , "USD"   , "EURX", "USDX" };
int    digits     [] = {        5,        5,        5,        5,        5,        5,        5,        5,      3,      3 };

bool   AUDLFX.Available;
bool   CADLFX.Available;
bool   CHFLFX.Available;
bool   EURLFX.Available;
bool   GBPLFX.Available;
bool   JPYLFX.Available;
bool   NZDLFX.Available;
bool   USDLFX.Available;
bool     EURX.Available;
bool     USDX.Available;

bool   isMainIndex    [10];                                          // ob der über die USD-Pairs berechnete Index einer Währung verfügbar ist
double mainIndex      [10];                                          // aktueller Indexwert
double mainIndex.last [10];                                          // vorheriger Indexwert

bool   isCrossIndex   [10];                                          // ob der über die Crosses berechnete Index einer Währung verfügbar ist
double crossIndex     [10];                                          // aktueller Indexwert

bool   recording      [10];                                          // default: FALSE
int    hSet           [10];                                          // HistorySet-Handles
string serverName = "MyFX-Synthetic";                                // default: Serververzeichnis

string labels        [10];
string label.animation;                                              // Ticker-Visualisierung
string label.animation.chars[] = {"|", "/", "—", "\\"};

color  bgColor                = C'212,208,200';
color  fontColor.recordingOn  = Blue;
color  fontColor.recordingOff = Gray;
string fontName               = "Tahoma";
int    fontSize               = 10;

int    tickTimerId;                                                  // ID des TickTimers des Charts


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


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) TradeAccount und Status initialisieren
   if (!InitTradeAccount())
      return(last_error);
   debug("onInit(1)  tradeAccount="+ tradeAccount.company +":"+ tradeAccount.number +"  mode.intern="+ mode.intern +"  mode.extern="+ mode.extern +"  mode.remote="+ mode.remote);


   // (2) Serververzeichnis für Historydateien definieren
   if (__NAME__ != "LFX-Recorder") {
      string suffix = StringRightFrom(__NAME__, "LFX-Recorder");
      if (!StringLen(suffix))            suffix = __NAME__;
      if (StringStartsWith(suffix, ".")) suffix = StringRight(suffix, -1);
      serverName = serverName +"."+ suffix;
   }


   // (3) Parameterauswertung
   if (Recording.Enabled) {
      int count;
      recording[I_AUDLFX] = AUDLFX.Enabled; count += AUDLFX.Enabled;
      recording[I_CADLFX] = CADLFX.Enabled; count += CADLFX.Enabled;
      recording[I_CHFLFX] = CHFLFX.Enabled; count += CHFLFX.Enabled;
      recording[I_EURLFX] = EURLFX.Enabled; count += EURLFX.Enabled;
      recording[I_GBPLFX] = GBPLFX.Enabled; count += GBPLFX.Enabled;
      recording[I_JPYLFX] = JPYLFX.Enabled; count += JPYLFX.Enabled;
      recording[I_NZDLFX] = NZDLFX.Enabled; count += NZDLFX.Enabled;
      recording[I_USDLFX] = USDLFX.Enabled; count += USDLFX.Enabled;
      recording[I_EURX  ] =   EURX.Enabled; count +=   EURX.Enabled;
      recording[I_USDX  ] =   USDX.Enabled; count +=   USDX.Enabled;

      if (count > 7) {                                               // Je MQL-Modul können maximal 64 Dateien gleichzeitig offen sein (entspricht 7 Instrumenten).
         for (int i=ArraySize(recording)-1; i >= 0; i--) {
            if (recording[i]) {
               recording[i] = false;
               count--;
               if (count <= 7)
                  break;
            }
         }
      }
   }


   // (4) Chart-Ticker installieren
   if (!This.IsTesting()) /*&&*/ if (!StringStartsWithI(GetServerName(), "MyFX-")) {
      int hWnd    = WindowHandleEx(NULL); if (!hWnd) return(last_error);
      int millis  = 500;
      int timerId = SetupTickTimer(hWnd, millis, NULL);
      if (!timerId) return(catch("onInit(2)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }


   // (5) Chartanzeige erzeugen, Indikator-Datenanzeige ausschalten
   CreateLabels();
   SetIndexLabel(0, NULL);
   return(catch("onInit(3)"));

   // für alle konfigurierten Indizes
   int sizeIndizes;
   for (i=0; i < sizeIndizes; i++) {
      // Statusanzeige initialisieren
   }
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
   UpdateInfos();
   return(last_error);



   // (1) onInit()
   if (AUDLFX.Enabled) {}     // Index anzeigen: {Symbol}: [off | n/a]
   if (CADLFX.Enabled) {}     // aktive Limits anzeigen
   if (CHFLFX.Enabled) {}
   if (EURLFX.Enabled) {}
   if (GBPLFX.Enabled) {}
   if (JPYLFX.Enabled) {}
   if (NZDLFX.Enabled) {}
   if (USDLFX.Enabled) {}
   if (  EURX.Enabled) {}
   if (  USDX.Enabled) {}


   // (2) onTick()
   // (2.1) prüfen, ob alle Daten für diesen Index verfügbar sind
   if (AUDLFX.Enabled) {
      if (AUDLFX.Available) {
         // Index berechnen
         // Limits prüfen und bei Erreichen Action auslösen
         // Index speichern
         // Index anzeigen:   {Symbol}: {value}
      }
      else {
         // Index anzeigen:   {Symbol}: n/a
      }
   }

   // (2.2) regelmäßig prüfen, ob sich die Limite geändert haben (nicht bei jedem Tick)
}


/**
 * Erzeugt die Textlabel.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   int counter = 10;                                                 // Zählervariable für eindeutige Label, mindestens zweistellig

   // Hintergrund-Rechtecke
   counter++;
   string label = StringConcatenate(__NAME__, ".", counter, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 76);
      ObjectSet    (label, OBJPROP_YDISTANCE, 56);
      ObjectSetText(label, "g", 146, "Webdings", bgColor);
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
      ObjectSetText(label, "g", 146, "Webdings", bgColor);
      ObjectRegister(label);
   }
   else GetLastError();

   int   col3width = 110;
   int   yCoord    =  58;
   color fontColor =  ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);


   // Recording-Status
   counter++;
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


   // Spaltenköpfe
   yCoord += 16;
   counter++;
   label = StringConcatenate(__NAME__, ".", counter, ".Header.animation");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 132+col3width);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, label.animation.chars[0], fontSize, fontName, fontColor);
      ObjectRegister(label);
      label.animation = label;
   }
   else GetLastError();

   label = StringConcatenate(__NAME__, ".", counter, ".Header.cross");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 69+col3width);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "cross", fontSize, fontName, fontColor);
      ObjectRegister(label);
   }
   else GetLastError();

   counter++;
   label = StringConcatenate(__NAME__, ".", counter, ".Header.main");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 69);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "main", fontSize, fontName, fontColor);
      ObjectRegister(label);
   }
   else GetLastError();


   // Datenzeilen
   yCoord += 16;
   for (int i=0; i < ArraySize(symbols); i++) {
      fontColor = ifInt(recording[i], fontColor.recordingOn, fontColor.recordingOff);
      counter++;

      // Währung
      label = StringConcatenate(__NAME__, ".", counter, ".", names[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 119+col3width);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, names[i] +":", fontSize, fontName, fontColor);
         ObjectRegister(label);
         labels[i] = label;
      }
      else GetLastError();

      // Cross-Index
      label = StringConcatenate(labels[i], ".quote.cross");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 59+col3width);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         ObjectRegister(label);
      }
      else GetLastError();

      // Cross-Spread
      label = StringConcatenate(labels[i], ".spread.cross");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 19+col3width);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         ObjectRegister(label);
      }
      else GetLastError();

      // Main-Index
      label = StringConcatenate(labels[i], ".quote.main");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 59);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         ObjectRegister(label);
      }
      else GetLastError();

      // Main-Spread
      label = StringConcatenate(labels[i], ".spread.main");
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
   double                                 usdlfx.main_Bid, usdlfx.main_Ask;
   double audlfx.crs_Bid, audlfx.crs_Ask, audlfx.main_Bid, audlfx.main_Ask;
   double cadlfx.crs_Bid, cadlfx.crs_Ask, cadlfx.main_Bid, cadlfx.main_Ask;
   double chflfx.crs_Bid, chflfx.crs_Ask, chflfx.main_Bid, chflfx.main_Ask;
   double eurlfx.crs_Bid, eurlfx.crs_Ask, eurlfx.main_Bid, eurlfx.main_Ask;
   double gbplfx.crs_Bid, gbplfx.crs_Ask, gbplfx.main_Bid, gbplfx.main_Ask;
   double jpylfx.crs_Bid, jpylfx.crs_Ask, jpylfx.main_Bid, jpylfx.main_Ask;
   double nzdlfx.crs_Bid, nzdlfx.crs_Ask, nzdlfx.main_Bid, nzdlfx.main_Ask;
   double                                 usdx.main_Bid,   usdx.main_Ask;
   double eurx.crs_Bid,   eurx.crs_Ask,   eurx.main_Bid,   eurx.main_Ask;


   // USDLFX
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2;

   isMainIndex[I_USDLFX]  = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_USDLFX] = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
      usdlfx.main_Bid     = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
      usdlfx.main_Ask     = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
   }
   isCrossIndex[I_USDLFX] = false;

   // AUDLFX
   double audcad_Bid = MarketInfo("AUDCAD", MODE_BID), audcad_Ask = MarketInfo("AUDCAD", MODE_ASK), audcad = (audcad_Bid + audcad_Ask)/2;
   double audchf_Bid = MarketInfo("AUDCHF", MODE_BID), audchf_Ask = MarketInfo("AUDCHF", MODE_ASK), audchf = (audchf_Bid + audchf_Ask)/2;
   double audjpy_Bid = MarketInfo("AUDJPY", MODE_BID), audjpy_Ask = MarketInfo("AUDJPY", MODE_ASK), audjpy = (audjpy_Bid + audjpy_Ask)/2;
   //     audusd_Bid = ...
   double euraud_Bid = MarketInfo("EURAUD", MODE_BID), euraud_Ask = MarketInfo("EURAUD", MODE_ASK), euraud = (euraud_Bid + euraud_Ask)/2;
   double gbpaud_Bid = MarketInfo("GBPAUD", MODE_BID), gbpaud_Ask = MarketInfo("GBPAUD", MODE_ASK), gbpaud = (gbpaud_Bid + gbpaud_Ask)/2;

   isCrossIndex[I_AUDLFX]  = (audcad_Bid && audchf_Bid && audjpy_Bid && audusd_Bid && euraud_Bid && gbpaud_Bid);
   if (isCrossIndex[I_AUDLFX]) {
      crossIndex[I_AUDLFX] = MathPow((audcad     * audchf     * audjpy     * audusd    ) / (euraud     * gbpaud    ), 1/7.);
      audlfx.crs_Bid       = MathPow((audcad_Bid * audchf_Bid * audjpy_Bid * audusd_Bid) / (euraud_Ask * gbpaud_Ask), 1/7.);
      audlfx.crs_Ask       = MathPow((audcad_Ask * audchf_Ask * audjpy_Ask * audusd_Ask) / (euraud_Bid * gbpaud_Bid), 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_AUDLFX]  = mainIndex[I_USDLFX] * audusd;
      audlfx.main_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
      audlfx.main_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
   }
   isMainIndex[I_AUDLFX]   = isMainIndex[I_USDLFX];

   // CADLFX
   double cadchf_Bid = MarketInfo("CADCHF", MODE_BID), cadchf_Ask = MarketInfo("CADCHF", MODE_ASK), cadchf = (cadchf_Bid + cadchf_Ask)/2;
   double cadjpy_Bid = MarketInfo("CADJPY", MODE_BID), cadjpy_Ask = MarketInfo("CADJPY", MODE_ASK), cadjpy = (cadjpy_Bid + cadjpy_Ask)/2;
   //     audcad_Bid = ...
   double eurcad_Bid = MarketInfo("EURCAD", MODE_BID), eurcad_Ask = MarketInfo("EURCAD", MODE_ASK), eurcad = (eurcad_Bid + eurcad_Ask)/2;
   double gbpcad_Bid = MarketInfo("GBPCAD", MODE_BID), gbpcad_Ask = MarketInfo("GBPCAD", MODE_ASK), gbpcad = (gbpcad_Bid + gbpcad_Ask)/2;
   //     usdcad_Bid = ...

   isCrossIndex[I_CADLFX]  = (cadchf_Bid && cadjpy_Bid && audcad_Bid && eurcad_Bid && gbpcad_Bid && usdcad_Bid);
   if (isCrossIndex[I_CADLFX]) {
      crossIndex[I_CADLFX] = MathPow((cadchf     * cadjpy    ) / (audcad     * eurcad     * gbpcad     * usdcad    ), 1/7.);
      cadlfx.crs_Bid       = MathPow((cadchf_Bid * cadjpy_Bid) / (audcad_Ask * eurcad_Ask * gbpcad_Ask * usdcad_Ask), 1/7.);
      cadlfx.crs_Ask       = MathPow((cadchf_Ask * cadjpy_Ask) / (audcad_Bid * eurcad_Bid * gbpcad_Bid * usdcad_Bid), 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_CADLFX]  = mainIndex[I_USDLFX] / usdcad;
      cadlfx.main_Bid      = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
      cadlfx.main_Ask      = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
   }
   isMainIndex[I_CADLFX]   = isMainIndex[I_USDLFX];

   // CHFLFX
   double chfjpy_Bid = MarketInfo("CHFJPY", MODE_BID), chfjpy_Ask = MarketInfo("CHFJPY", MODE_ASK), chfjpy = (chfjpy_Bid + chfjpy_Ask)/2;
   //     audchf_Bid = ...
   //     cadchf_Bid = ...
   double eurchf_Bid = MarketInfo("EURCHF", MODE_BID), eurchf_Ask = MarketInfo("EURCHF", MODE_ASK), eurchf = (eurchf_Bid + eurchf_Ask)/2;
   double gbpchf_Bid = MarketInfo("GBPCHF", MODE_BID), gbpchf_Ask = MarketInfo("GBPCHF", MODE_ASK), gbpchf = (gbpchf_Bid + gbpchf_Ask)/2;
   //     usdchf_Bid = ...

   isCrossIndex[I_CHFLFX]  = (chfjpy_Bid && audchf_Bid && cadchf_Bid && eurchf_Bid && gbpchf_Bid && usdchf_Bid);
   if (isCrossIndex[I_CHFLFX]) {
      crossIndex[I_CHFLFX] = MathPow(chfjpy     / (audchf     * cadchf     * eurchf     * gbpchf     * usdchf    ), 1/7.);
      chflfx.crs_Bid       = MathPow(chfjpy_Bid / (audchf_Ask * cadchf_Ask * eurchf_Ask * gbpchf_Ask * usdchf_Ask), 1/7.);
      chflfx.crs_Ask       = MathPow(chfjpy_Ask / (audchf_Bid * cadchf_Bid * eurchf_Bid * gbpchf_Bid * usdchf_Bid), 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_CHFLFX]  = mainIndex[I_USDLFX] / usdchf;
      chflfx.main_Bid      = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
      chflfx.main_Ask      = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
   }
   isMainIndex[I_CHFLFX]   = isMainIndex[I_USDLFX];
   /*
   chfjpy = usdjpy / usdchf
   audchf = audusd * usdchf
   cadchf = usdchf / usdcad
   eurchf = eurusd * usdchf
   gbpchf = gbpusd * usdchf


   CHFLFX: Herleitung der Gleichheit der Berechnung des Index über USDLFX und über die beteiligten Crosses
   =======================================================================================================

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
   //     euraud_Bid = ...
   //     eurcad_Bid = ...
   //     eurchf_Bid = ...
   double eurgbp_Bid = MarketInfo("EURGBP", MODE_BID), eurgbp_Ask = MarketInfo("EURGBP", MODE_ASK), eurgbp = (eurgbp_Bid + eurgbp_Ask)/2;
   double eurjpy_Bid = MarketInfo("EURJPY", MODE_BID), eurjpy_Ask = MarketInfo("EURJPY", MODE_ASK), eurjpy = (eurjpy_Bid + eurjpy_Ask)/2;
   //     eurusd_Bid = ...

   isCrossIndex[I_EURLFX]  = (euraud_Bid && eurcad_Bid && eurchf_Bid && eurgbp_Bid && eurjpy_Bid && eurusd_Bid);
   if (isCrossIndex[I_EURLFX]) {
      crossIndex[I_EURLFX] = MathPow((euraud     * eurcad     * eurchf     * eurgbp     * eurjpy     * eurusd    ), 1/7.);
      eurlfx.crs_Bid       = MathPow((euraud_Bid * eurcad_Bid * eurchf_Bid * eurgbp_Bid * eurjpy_Bid * eurusd_Bid), 1/7.);
      eurlfx.crs_Ask       = MathPow((euraud_Ask * eurcad_Ask * eurchf_Ask * eurgbp_Ask * eurjpy_Ask * eurusd_Ask), 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_EURLFX]  = mainIndex[I_USDLFX] * eurusd;
      eurlfx.main_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
      eurlfx.main_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
   }
   isMainIndex[I_EURLFX]   = isMainIndex[I_USDLFX];

   // GBPLFX
   //     gbpaud_Bid = ...
   //     gbpcad_Bid = ...
   //     gbpchf_Bid = ...
   double gbpjpy_Bid = MarketInfo("GBPJPY", MODE_BID), gbpjpy_Ask = MarketInfo("GBPJPY", MODE_ASK), gbpjpy = (gbpjpy_Bid + gbpjpy_Ask)/2;
   //     gbpusd_Bid = ...
   //     eurgbp_Bid = ...

   isCrossIndex[I_GBPLFX]  = (gbpaud_Bid && gbpcad_Bid && gbpchf_Bid && gbpjpy_Bid && gbpusd_Bid && eurgbp_Bid);
   if (isCrossIndex[I_GBPLFX]) {
      crossIndex[I_GBPLFX] = MathPow((gbpaud     * gbpcad     * gbpchf     * gbpjpy     * gbpusd    ) / eurgbp    , 1/7.);
      gbplfx.crs_Bid       = MathPow((gbpaud_Bid * gbpcad_Bid * gbpchf_Bid * gbpjpy_Bid * gbpusd_Bid) / eurgbp_Ask, 1/7.);
      gbplfx.crs_Ask       = MathPow((gbpaud_Ask * gbpcad_Ask * gbpchf_Ask * gbpjpy_Ask * gbpusd_Ask) / eurgbp_Bid, 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_GBPLFX]  = mainIndex[I_USDLFX] * gbpusd;
      gbplfx.main_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
      gbplfx.main_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
   }
   isMainIndex[I_GBPLFX]   = isMainIndex[I_USDLFX];

   // JPYLFX
   //     audjpy_Bid = ...
   //     cadjpy_Bid = ...
   //     chfjpy_Bid = ...
   //     eurjpy_Bid = ...
   //     gbpjpy_Bid = ...
   //     usdjpy_Bid = ...

   isCrossIndex[I_JPYLFX]  = (audjpy_Bid && cadjpy_Bid && chfjpy_Bid && eurjpy_Bid && gbpjpy_Bid && usdjpy_Bid);
   if (isCrossIndex[I_JPYLFX]) {
      crossIndex[I_JPYLFX] = 100 * MathPow(1 / (audjpy     * cadjpy     * chfjpy     * eurjpy     * gbpjpy     * usdjpy    ), 1/7.);
      jpylfx.crs_Bid       = 100 * MathPow(1 / (audjpy_Ask * cadjpy_Ask * chfjpy_Ask * eurjpy_Ask * gbpjpy_Ask * usdjpy_Ask), 1/7.);
      jpylfx.crs_Ask       = 100 * MathPow(1 / (audjpy_Bid * cadjpy_Bid * chfjpy_Bid * eurjpy_Bid * gbpjpy_Bid * usdjpy_Bid), 1/7.);
   }
   if (isMainIndex[I_USDLFX]) {
      mainIndex[I_JPYLFX]  = 100 * mainIndex[I_USDLFX] / usdjpy;
      jpylfx.main_Bid      = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
      jpylfx.main_Ask      = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
   }
   isMainIndex[I_JPYLFX]   = isMainIndex[I_USDLFX];

   // NZDLFX
   double audnzd_Bid = MarketInfo("AUDNZD", MODE_BID), audnzd_Ask = MarketInfo("AUDNZD", MODE_ASK), audnzd = (audnzd_Bid + audnzd_Ask)/2;
   double eurnzd_Bid = MarketInfo("EURNZD", MODE_BID), eurnzd_Ask = MarketInfo("EURNZD", MODE_ASK), eurnzd = (eurnzd_Bid + eurnzd_Ask)/2;
   double gbpnzd_Bid = MarketInfo("GBPNZD", MODE_BID), gbpnzd_Ask = MarketInfo("GBPNZD", MODE_ASK), gbpnzd = (gbpnzd_Bid + gbpnzd_Ask)/2;
   double nzdcad_Bid = MarketInfo("NZDCAD", MODE_BID), nzdcad_Ask = MarketInfo("NZDCAD", MODE_ASK), nzdcad = (nzdcad_Bid + nzdcad_Ask)/2;
   double nzdchf_Bid = MarketInfo("NZDCHF", MODE_BID), nzdchf_Ask = MarketInfo("NZDCHF", MODE_ASK), nzdchf = (nzdchf_Bid + nzdchf_Ask)/2;
   double nzdjpy_Bid = MarketInfo("NZDJPY", MODE_BID), nzdjpy_Ask = MarketInfo("NZDJPY", MODE_ASK), nzdjpy = (nzdjpy_Bid + nzdjpy_Ask)/2;
   double nzdusd_Bid = MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask = MarketInfo("NZDUSD", MODE_ASK), nzdusd = (nzdusd_Bid + nzdusd_Ask)/2;

   isCrossIndex[I_NZDLFX]  = (audnzd_Bid && eurnzd_Bid && gbpnzd_Bid && nzdcad_Bid && nzdchf_Bid && nzdjpy_Bid && nzdusd_Bid);
   if (isCrossIndex[I_NZDLFX]) {
      crossIndex[I_NZDLFX] = MathPow((nzdcad     * nzdchf     * nzdjpy     * nzdusd    ) / (audnzd     * eurnzd     * gbpnzd    ), 1/7.);
      nzdlfx.crs_Bid       = MathPow((nzdcad_Bid * nzdchf_Bid * nzdjpy_Bid * nzdusd_Bid) / (audnzd_Ask * eurnzd_Ask * gbpnzd_Ask), 1/7.);
      nzdlfx.crs_Ask       = MathPow((nzdcad_Ask * nzdchf_Ask * nzdjpy_Ask * nzdusd_Ask) / (audnzd_Bid * eurnzd_Bid * gbpnzd_Bid), 1/7.);
   }
   if (isMainIndex[I_USDLFX] && nzdusd_Bid) {
      mainIndex[I_NZDLFX]  = mainIndex[I_USDLFX] * nzdusd;
      nzdlfx.main_Bid      = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
      nzdlfx.main_Ask      = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
   }
   isMainIndex[I_NZDLFX]   = (isMainIndex[I_USDLFX] && nzdusd_Bid);
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

   // USDX
   //     usdcad_Bid = ...
   //     usdchf_Bid = ...
   //     usdjpy_Bid = ...
   double usdsek_Bid = MarketInfo("USDSEK", MODE_BID), usdsek_Ask = MarketInfo("USDSEK", MODE_ASK), usdsek = (usdsek_Bid + usdsek_Ask)/2;
   //     eurusd_Bid = ...
   //     gbpusd_Bid = ...

   isMainIndex[I_USDX]  = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
   if (isMainIndex[I_USDX]) {
      mainIndex[I_USDX] = 50.14348112 * (MathPow(usdcad    , 0.091) * MathPow(usdchf    , 0.036) * MathPow(usdjpy    , 0.136) * MathPow(usdsek    , 0.042)) / (MathPow(eurusd    , 0.576) * MathPow(gbpusd    , 0.119));
      usdx.main_Bid     = 50.14348112 * (MathPow(usdcad_Bid, 0.091) * MathPow(usdchf_Bid, 0.036) * MathPow(usdjpy_Bid, 0.136) * MathPow(usdsek_Bid, 0.042)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
      usdx.main_Ask     = 50.14348112 * (MathPow(usdcad_Ask, 0.091) * MathPow(usdchf_Ask, 0.036) * MathPow(usdjpy_Ask, 0.136) * MathPow(usdsek_Ask, 0.042)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
   }
   isCrossIndex[I_USDX] = false;
   /*
   USDX = 50.14348112 * EURUSD^-0.576 * USDJPY^0.136 * GBPUSD^-0.119 * USDCAD^0.091 * USDSEK^0.042 * USDCHF^0.036


                        USDCAD^0.091 * USDCHF^0.036 * USDJPY^0.136 * USDSEK^0.042
   USDX = 50.14348112 * ---------------------------------------------------------
                                       EURUSD^0.576 * GBPUSD^0.119
   */

   // EURX
   //     eurchf_Bid = ...
   //     eurgbp_Bid = ...
   //     eurjpy_Bid = ...
   double eursek_Bid = MarketInfo("EURSEK", MODE_BID), eursek_Ask = MarketInfo("EURSEK", MODE_ASK), eursek = (eursek_Bid + eursek_Ask)/2;
   //     eurusd_Bid = ...

   isCrossIndex[I_EURX]  = (eurchf_Bid && eurgbp_Bid && eurjpy_Bid && eursek_Bid && eurusd_Bid);
   if (isCrossIndex[I_EURX]) {
      crossIndex[I_EURX] = 34.38805726 * MathPow(eurchf    , 0.1113) * MathPow(eurgbp    , 0.3056) * MathPow(eurjpy    , 0.1891) * MathPow(eursek    , 0.0785) * MathPow(eurusd    , 0.3155);
      eurx.crs_Bid       = 34.38805726 * MathPow(eurchf_Bid, 0.1113) * MathPow(eurgbp_Bid, 0.3056) * MathPow(eurjpy_Bid, 0.1891) * MathPow(eursek_Bid, 0.0785) * MathPow(eurusd_Bid, 0.3155);
      eurx.crs_Ask       = 34.38805726 * MathPow(eurchf_Ask, 0.1113) * MathPow(eurgbp_Ask, 0.3056) * MathPow(eurjpy_Ask, 0.1891) * MathPow(eursek_Ask, 0.0785) * MathPow(eurusd_Ask, 0.3155);
   }
   if (isMainIndex[I_USDX]) {
      eurchf = usdchf * eurusd;
      eurgbp = eurusd / gbpusd;
      eurjpy = usdjpy * eurusd;
      eursek = usdsek * eurusd;
      mainIndex[I_EURX]  = 34.38805726 * MathPow(eurchf    , 0.1113) * MathPow(eurgbp    , 0.3056) * MathPow(eurjpy    , 0.1891) * MathPow(eursek    , 0.0785) * MathPow(eurusd    , 0.3155);
      eurx.main_Bid      = 0; //34.38805726 * MathPow(eurchf_Bid, 0.1113) * MathPow(eurgbp_Bid, 0.3056) * MathPow(eurjpy_Bid, 0.1891) * MathPow(eursek_Bid, 0.0785) * MathPow(eurusd_Bid, 0.3155);
      eurx.main_Ask      = 0; //34.38805726 * MathPow(eurchf_Ask, 0.1113) * MathPow(eurgbp_Ask, 0.3056) * MathPow(eurjpy_Ask, 0.1891) * MathPow(eursek_Ask, 0.0785) * MathPow(eurusd_Ask, 0.3155);
   }
   isMainIndex[I_EURX]   = isMainIndex[I_USDX];
   /*
   EURX = 34.38805726 * EURCHF^0.1113 * EURGBP^0.3056 * EURJPY^0.1891 * EURSEK^0.0785 * EURUSD^0.3155
   */


   // Fehlerbehandlung
   int error = GetLastError();                                     // TODO: ERS_HISTORY_UPDATE für welches Symbol,Timeframe ???
   if (error == ERS_HISTORY_UPDATE)                                return(!SetLastError(error));
   if (IsError(error)) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) return(!catch("UpdateInfos(1)", error));


   // Farben definieren
   color fontColor.USDLFX = ifInt(recording[I_USDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.AUDLFX = ifInt(recording[I_AUDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.CADLFX = ifInt(recording[I_CADLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.CHFLFX = ifInt(recording[I_CHFLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.EURLFX = ifInt(recording[I_EURLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.GBPLFX = ifInt(recording[I_GBPLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.JPYLFX = ifInt(recording[I_JPYLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.NZDLFX = ifInt(recording[I_NZDLFX], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.USDX   = ifInt(recording[I_USDX  ], fontColor.recordingOn, fontColor.recordingOff);
   color fontColor.EURX   = ifInt(recording[I_EURX  ], fontColor.recordingOn, fontColor.recordingOff);


   // Anzeige Cross-Indizes
   string sValue               = "-";                                                                                                                              ObjectSetText(labels[I_USDLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.USDLFX);
   if (!AUDLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_AUDLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_AUDLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_AUDLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.AUDLFX);
   if (!CADLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_CADLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_CADLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_CADLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.CADLFX);
   if (!CHFLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_CHFLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_CHFLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_CHFLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.CHFLFX);
   if (!EURLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_EURLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_EURLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_EURLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.EURLFX);
   if (!GBPLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_GBPLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_GBPLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_GBPLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.GBPLFX);
   if (!JPYLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_JPYLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_JPYLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_JPYLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.JPYLFX);
   if (!NZDLFX.Enabled) sValue = "off"; else if (isCrossIndex[I_NZDLFX]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_NZDLFX], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_NZDLFX] +".quote.cross",  sValue, fontSize, fontName, fontColor.NZDLFX);
                        sValue = "-";                                                                                                                              ObjectSetText(labels[I_USDX  ] +".quote.cross",  sValue, fontSize, fontName, fontColor.USDX  );
   if (  !EURX.Enabled) sValue = "off"; else if (isCrossIndex[I_EURX  ]) sValue = NumberToStr(NormalizeDouble(crossIndex[I_EURX  ], 3), ".2'"); else sValue = " "; ObjectSetText(labels[I_EURX  ] +".quote.cross",  sValue, fontSize, fontName, fontColor.EURX  );

   // Anzeige Cross-Spreads
                                                   sValue = " ";                                                                                                   ObjectSetText(labels[I_USDLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.USDLFX);
   if (!AUDLFX.Enabled || !isCrossIndex[I_AUDLFX]) sValue = " "; else sValue = "("+ DoubleToStr((audlfx.crs_Ask-audlfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_AUDLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.AUDLFX);
   if (!CADLFX.Enabled || !isCrossIndex[I_CADLFX]) sValue = " "; else sValue = "("+ DoubleToStr((cadlfx.crs_Ask-cadlfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_CADLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.CADLFX);
   if (!CHFLFX.Enabled || !isCrossIndex[I_CHFLFX]) sValue = " "; else sValue = "("+ DoubleToStr((chflfx.crs_Ask-chflfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_CHFLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.CHFLFX);
   if (!EURLFX.Enabled || !isCrossIndex[I_EURLFX]) sValue = " "; else sValue = "("+ DoubleToStr((eurlfx.crs_Ask-eurlfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_EURLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.EURLFX);
   if (!GBPLFX.Enabled || !isCrossIndex[I_GBPLFX]) sValue = " "; else sValue = "("+ DoubleToStr((gbplfx.crs_Ask-gbplfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_GBPLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.GBPLFX);
   if (!JPYLFX.Enabled || !isCrossIndex[I_JPYLFX]) sValue = " "; else sValue = "("+ DoubleToStr((jpylfx.crs_Ask-jpylfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_JPYLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.JPYLFX);
   if (!NZDLFX.Enabled || !isCrossIndex[I_NZDLFX]) sValue = " "; else sValue = "("+ DoubleToStr((nzdlfx.crs_Ask-nzdlfx.crs_Bid)*10000, 1) +")";                    ObjectSetText(labels[I_NZDLFX] +".spread.cross", sValue, fontSize, fontName, fontColor.NZDLFX);
                                                   sValue = " ";                                                                                                   ObjectSetText(labels[I_USDX  ] +".spread.cross", sValue, fontSize, fontName, fontColor.USDX  );
   if (  !EURX.Enabled || !isCrossIndex[I_EURX  ]) sValue = " "; else sValue = "("+ DoubleToStr((  eurx.crs_Ask-  eurx.crs_Bid)*  100, 1) +")";                    ObjectSetText(labels[I_EURX  ] +".spread.cross", sValue, fontSize, fontName, fontColor.EURX  );

   // Anzeige Main-Indizes
   if (!USDLFX.Enabled) sValue = "off"; else if (isMainIndex[I_USDLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_USDLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_USDLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.USDLFX);
   if (!AUDLFX.Enabled) sValue = "off"; else if (isMainIndex[I_AUDLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_AUDLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_AUDLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.AUDLFX);
   if (!CADLFX.Enabled) sValue = "off"; else if (isMainIndex[I_CADLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_CADLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_CADLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.CADLFX);
   if (!CHFLFX.Enabled) sValue = "off"; else if (isMainIndex[I_CHFLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_CHFLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_CHFLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.CHFLFX);
   if (!EURLFX.Enabled) sValue = "off"; else if (isMainIndex[I_EURLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_EURLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_EURLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.EURLFX);
   if (!GBPLFX.Enabled) sValue = "off"; else if (isMainIndex[I_GBPLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_GBPLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_GBPLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.GBPLFX);
   if (!JPYLFX.Enabled) sValue = "off"; else if (isMainIndex[I_JPYLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_JPYLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_JPYLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.JPYLFX);
   if (!NZDLFX.Enabled) sValue = "off"; else if (isMainIndex[I_NZDLFX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_NZDLFX], 5), ".4'"); else sValue = " ";   ObjectSetText(labels[I_NZDLFX] +".quote.main",   sValue, fontSize, fontName, fontColor.NZDLFX);
   if (  !USDX.Enabled) sValue = "off"; else if (isMainIndex[I_USDX  ]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_USDX  ], 3), ".2'"); else sValue = " ";   ObjectSetText(labels[I_USDX  ] +".quote.main",   sValue, fontSize, fontName, fontColor.USDX  );
   if (  !EURX.Enabled) sValue = "off"; else if (isMainIndex[I_EURX  ]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_EURX  ], 3), ".2'"); else sValue = " ";   ObjectSetText(labels[I_EURX  ] +".quote.main",   sValue, fontSize, fontName, fontColor.EURX  );

   // Anzeige Main-Spreads
   if (!USDLFX.Enabled || !isMainIndex[I_USDLFX]) sValue = " "; else sValue = "("+ DoubleToStr((usdlfx.main_Ask-usdlfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_USDLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.USDLFX);
   if (!AUDLFX.Enabled || !isMainIndex[I_AUDLFX]) sValue = " "; else sValue = "("+ DoubleToStr((audlfx.main_Ask-audlfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_AUDLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.AUDLFX);
   if (!CADLFX.Enabled || !isMainIndex[I_CADLFX]) sValue = " "; else sValue = "("+ DoubleToStr((cadlfx.main_Ask-cadlfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_CADLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.CADLFX);
   if (!CHFLFX.Enabled || !isMainIndex[I_CHFLFX]) sValue = " "; else sValue = "("+ DoubleToStr((chflfx.main_Ask-chflfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_CHFLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.CHFLFX);
   if (!EURLFX.Enabled || !isMainIndex[I_EURLFX]) sValue = " "; else sValue = "("+ DoubleToStr((eurlfx.main_Ask-eurlfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_EURLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.EURLFX);
   if (!GBPLFX.Enabled || !isMainIndex[I_GBPLFX]) sValue = " "; else sValue = "("+ DoubleToStr((gbplfx.main_Ask-gbplfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_GBPLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.GBPLFX);
   if (!JPYLFX.Enabled || !isMainIndex[I_JPYLFX]) sValue = " "; else sValue = "("+ DoubleToStr((jpylfx.main_Ask-jpylfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_JPYLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.JPYLFX);
   if (!NZDLFX.Enabled || !isMainIndex[I_NZDLFX]) sValue = " "; else sValue = "("+ DoubleToStr((nzdlfx.main_Ask-nzdlfx.main_Bid)*10000, 1) +")";                   ObjectSetText(labels[I_NZDLFX] +".spread.main",  sValue, fontSize, fontName, fontColor.NZDLFX);
   if (  !USDX.Enabled || !isMainIndex[I_USDX  ]) sValue = " "; else sValue = "("+ DoubleToStr((  usdx.main_Ask-  usdx.main_Bid)*  100, 1) +")";                   ObjectSetText(labels[I_USDX  ] +".spread.main",  sValue, fontSize, fontName, fontColor.USDX  );
   if (true                                     ) sValue = " "; else sValue = "("+ DoubleToStr((  eurx.main_Ask-  eurx.main_Bid)*  100, 1) +")";                   ObjectSetText(labels[I_EURX  ] +".spread.main",  sValue, fontSize, fontName, fontColor.EURX  );

   // Animation
   static int size = -1; if (size==-1) size = ArraySize(label.animation.chars);
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);
   ObjectSetText(label.animation, label.animation.chars[Tick % size], fontSize, fontName, fontColor);


   // LFX-Indizes aufzeichnen
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
      if (recording[i]) /*&&*/ if (isMainIndex[i]) {
         double tickValue     = NormalizeDouble(mainIndex     [i], digits[i]);
         double lastTickValue =                 mainIndex.last[i];

         // Virtuelle Ticks werden nur dann aufgezeichnet, wenn sich der Indexwert geändert hat.
         bool skipTick = false;
         if (Tick.isVirtual) {
            skipTick = (!lastTickValue || EQ(tickValue, lastTickValue, digits[i]));
            //if (skipTick) debug("RecordLfxIndices(1)  zTick="+ zTick +"  skipping virtual "+ names[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +"  lastTick="+ NumberToStr(lastTickValue, "."+ (digits[i]-1) +"'") +"  tick"+ ifString(EQ(tickValue, lastTickValue, digits[i]), "==", "!=") +"lastTick");
         }

         if (!skipTick) {
            if (!lastTickValue) {
               skipTick = true;
               //debug("RecordLfxIndices(2)  zTick="+ zTick +"  skipping first "+ names[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +" (no last tick)");
            }
            else if (MathAbs(tickValue/lastTickValue - 1.0) > 0.005) {
               skipTick = true;
               warn("RecordLfxIndices(3)  zTick="+ zTick +"  skipping supposed "+ names[i] +" mis-tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'") +" (lastTick: "+ NumberToStr(lastTickValue, "."+ (digits[i]-1) +"'") +")");
            }
         }

         if (!skipTick) {
            //debug("RecordLfxIndices(4)  zTick="+ zTick +"  recording "+ names[i] +" tick "+ NumberToStr(tickValue, "."+ (digits[i]-1) +"'"));
            if (!hSet[i]) {
               string description = names[i] + ifString(i==I_EURX || i==I_USDX, " Index (ICE)", " Index (LiteForex)");
               int    format      = 400;

               hSet[i] = HistorySet.Get(symbols[i], serverName);
               if (hSet[i] == -1)
                  hSet[i] = HistorySet.Create(symbols[i], description, digits[i], format, serverName);
               if (!hSet[i]) return(!SetLastError(history.GetLastError()));
            }

            int flags;// = HST_COLLECT_TICKS;
            if (!HistorySet.AddTick(hSet[i], Tick.Time, tickValue, flags)) return(!SetLastError(history.GetLastError()));
         }

         mainIndex.last[i] = tickValue;
      }
   }
   return(true);
}

