/**
 * Berechnet die Kurse der verfügbaren LFX-Indizes, zeigt sie an und zeichnet ggf. deren History auf.
 *
 * Die mathematische Formel für den Index einer Währung ist das geometrische Mittel der Kurse der jeweiligen Vergleichswährungen. LiteForex benutzt sieben Vergleichs-
 * währungen, wovon eine imaginär und ihr Kurs immer 1.0 ist. Das vereinfacht die (fehlerhafte) Berechnung zusätzlicher Indizes, macht ihre Abbildung als Handelsposition
 * jedoch komplizierter. Letztlich dienen sie der Trendanalyse, weder können noch sollen sie für absolute oder Vergleiche untereinander geeignet sein.
 *
 *  • Korrekt:   USD-Index = (USDCAD * USDCHF * USDJPY * USDAUD * USDEUR * USDGBP)          ^ 1/6
 *               NZD-Index = (NZDAUD * NZDCAD * NZDCHF * NZDEUR * NZDGBP * NZDJPY * NZDUSD) ^ 1/7
 *
 *  • LiteForex: USD-Index = (USDAUD * USDCAD * USDCHF * USDEUR * USDGBP * USDJPY *  0.68 * USDNZD ) ^ 1/7
 *               NZD-Index = USD-Index * USDNZD                                                    // einfach, jedoch nicht korrekt (obwohl einfach zu korrigieren)
 *               ...
 *
 * - Wird eine Handelsposition statt über die direkten über die USD-Crosses abgebildet (niedrigerer Spread), sind die Anzahl der Teilpositionen und entsprechend die
 *   Margin-Requirements höher.
 *
 * - Unterschiede zwischen theoretischer und praktischer Performance von Handelspositionen werden vom Position-Sizing (MinLotStep) und bei längerfristigem Handel vom
 *   fehlenden Index-Rebalancing verursacht.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern bool   Recording.Enabled = false;                             // default: kein Recording
extern string _1________________________;
extern bool   AUD.Enabled       = true;
extern bool   CAD.Enabled       = true;
extern bool   CHF.Enabled       = true;
extern bool   EUR.Enabled       = true;
extern bool   GBP.Enabled       = true;
extern bool   JPY.Enabled       = true;
extern bool   NZD.Enabled       = true;
extern bool   USD.Enabled       = true;
extern string _2________________________;
extern bool   EURX.Enabled      = true;
extern bool   USDX.Enabled      = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


#property indicator_chart_window


string symbols    [] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "EURX", "USDX" };
string names      [] = { "AUD"   , "CAD"   , "CHF"   , "EUR"   , "GBP"   , "JPY"   , "NZD"   , "USD"   , "EURX", "USDX" };
int    digits     [] = {        5,        5,        5,        5,        5,        5,        5,        5,      3,      3 };

bool   isMainIndex   [10];                                           // ob der über die Haupt-Pairs berechnete Index einer Währung verfügbar ist
double mainIndex     [10];                                           // aktueller Indexwert
double mainIndex.last[10];                                           // vorheriger Indexwert für RecordLfxIndices()

bool   recording     [10];                                           // default: FALSE
int    hSet          [10];                                           // HistorySet-Handles der Indizes

string labels        [10];                                           // Label für Visualisierung
string label.animation;
string label.animation.chars[] = {"|", "/", "—", "\\"};

string fontName  = "Tahoma";
int    fontSize  = 10;
color  fontColor = Blue;
color  bgColor   = C'212,208,200';

int    tickTimerId;                                                  // ID des TickTimers des Charts


#define I_AUD   0                                                    // Array-Indizes
#define I_CAD   1
#define I_CHF   2
#define I_EUR   3
#define I_GBP   4
#define I_JPY   5
#define I_NZD   6
#define I_USD   7
#define I_EUX   8
#define I_USX   9


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parameterauswertung
   if (Recording.Enabled) {
      int count;
      recording[I_AUD] = AUD.Enabled;  count += AUD.Enabled;
      recording[I_CAD] = CAD.Enabled;  count += CAD.Enabled;
      recording[I_CHF] = CHF.Enabled;  count += CHF.Enabled;
      recording[I_EUR] = EUR.Enabled;  count += EUR.Enabled;
      recording[I_GBP] = GBP.Enabled;  count += GBP.Enabled;
      recording[I_JPY] = JPY.Enabled;  count += JPY.Enabled;
      recording[I_NZD] = NZD.Enabled;  count += NZD.Enabled;
      recording[I_USD] = USD.Enabled;  count += USD.Enabled;
      recording[I_EUX] = EURX.Enabled; count += EURX.Enabled;
      recording[I_USX] = USDX.Enabled; count += USDX.Enabled;

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

   // (2) Anzeige erzeugen und Datenanzeige ausschalten
   CreateLabels();
   SetIndexLabel(0, NULL);

   // (3) Chart-Ticker aktivieren
   if (!This.IsTesting() && GetServerName()!="MyFX-Synthetic") {
      int hWnd   = WindowHandleEx(NULL); if (!hWnd) return(last_error);
      int millis = 500;

    //int timerId = SetupTickTimer(hWnd, millis, NULL);
    //if (!timerId) return(catch("onInit(1)->SetupTickTimer(hWnd="+ hWnd +", millis="+ millis +", flags=NULL) failed", ERR_RUNTIME_ERROR));

      int timerId = SetupTimedTicks(hWnd, Round(millis/1.56));
      if (!timerId) return(catch("onInit(1)->SetupTimedTicks(hWnd="+ hWnd +", millis="+ millis +") failed", ERR_RUNTIME_ERROR));

      tickTimerId = timerId;
   }
   return(catch("onInit(2)"));
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

   // einen laufenden Chart-Ticker wieder deaktivieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
    //if (!RemoveTickTimer(id))  return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
      if (!RemoveTimedTicks(id)) return(catch("onDeinit(1)->RemoveTimedTicks(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
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
}


/**
 * Erzeugt die Textlabel.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   int c = 10;                               // Zählervariable für Label, mindestens zweistellig

   // Backgrounds
   c++;
   string label = StringConcatenate(__NAME__, ".", c, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 90);
      ObjectSet    (label, OBJPROP_YDISTANCE, 56);
      ObjectSetText(label, "g", 136, "Webdings", bgColor);
      ObjectRegister(label);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Background");
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

   // Headerzeile
   int col3width = 110;
   int yCoord    =  58;
   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Header.animation");
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

   label = StringConcatenate(__NAME__, ".", c, ".Header.cross");
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

   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Header.main");
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
      c++;
      // Währung
      label = StringConcatenate(__NAME__, ".", c, ".", names[i]);
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
   double usdlfx.crs, usdlfx.crs_Bid, usdlfx.crs_Ask, usdlfx.main_Bid, usdlfx.main_Ask;
   double audlfx.crs, audlfx.crs_Bid, audlfx.crs_Ask, audlfx.main_Bid, audlfx.main_Ask;
   double cadlfx.crs, cadlfx.crs_Bid, cadlfx.crs_Ask, cadlfx.main_Bid, cadlfx.main_Ask;
   double chflfx.crs, chflfx.crs_Bid, chflfx.crs_Ask, chflfx.main_Bid, chflfx.main_Ask;
   double eurlfx.crs, eurlfx.crs_Bid, eurlfx.crs_Ask, eurlfx.main_Bid, eurlfx.main_Ask;
   double gbplfx.crs, gbplfx.crs_Bid, gbplfx.crs_Ask, gbplfx.main_Bid, gbplfx.main_Ask;
   double jpylfx.crs, jpylfx.crs_Bid, jpylfx.crs_Ask, jpylfx.main_Bid, jpylfx.main_Ask;
   double nzdlfx.crs, nzdlfx.crs_Bid, nzdlfx.crs_Ask, nzdlfx.main_Bid, nzdlfx.main_Ask;
   double                                             usdx.main_Bid,   usdx.main_Ask;
   double                                             eurx.main_Bid,   eurx.main_Ask;


   // USDLFX
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2;

   bool is_usdlfx.crs = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
   if (is_usdlfx.crs) {
      usdlfx.crs     = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
      usdlfx.crs_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
      usdlfx.crs_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);

      mainIndex[I_USD] = usdlfx.crs;
      usdlfx.main_Bid  = usdlfx.crs_Bid;
      usdlfx.main_Ask  = usdlfx.crs_Ask;
   }
   isMainIndex[I_USD] = is_usdlfx.crs;

   // AUDLFX
   double audcad_Bid = MarketInfo("AUDCAD", MODE_BID), audcad_Ask = MarketInfo("AUDCAD", MODE_ASK), audcad = (audcad_Bid + audcad_Ask)/2;
   double audchf_Bid = MarketInfo("AUDCHF", MODE_BID), audchf_Ask = MarketInfo("AUDCHF", MODE_ASK), audchf = (audchf_Bid + audchf_Ask)/2;
   double audjpy_Bid = MarketInfo("AUDJPY", MODE_BID), audjpy_Ask = MarketInfo("AUDJPY", MODE_ASK), audjpy = (audjpy_Bid + audjpy_Ask)/2;
   //     audusd_Bid = ...
   double euraud_Bid = MarketInfo("EURAUD", MODE_BID), euraud_Ask = MarketInfo("EURAUD", MODE_ASK), euraud = (euraud_Bid + euraud_Ask)/2;
   double gbpaud_Bid = MarketInfo("GBPAUD", MODE_BID), gbpaud_Ask = MarketInfo("GBPAUD", MODE_ASK), gbpaud = (gbpaud_Bid + gbpaud_Ask)/2;

   bool is_audlfx.crs = (audcad_Bid && audchf_Bid && audjpy_Bid && audusd_Bid && euraud_Bid && gbpaud_Bid);
   if (is_audlfx.crs) {
      audlfx.crs     = MathPow((audcad     * audchf     * audjpy     * audusd    ) / (euraud     * gbpaud    ), 1/7.);
      audlfx.crs_Bid = MathPow((audcad_Bid * audchf_Bid * audjpy_Bid * audusd_Bid) / (euraud_Ask * gbpaud_Ask), 1/7.);
      audlfx.crs_Ask = MathPow((audcad_Ask * audchf_Ask * audjpy_Ask * audusd_Ask) / (euraud_Bid * gbpaud_Bid), 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_AUD] = mainIndex[I_USD] * audusd;
      audlfx.main_Bid  = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
      audlfx.main_Ask  = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
   }
   isMainIndex[I_AUD] = isMainIndex[I_USD];

   // CADLFX
   double cadchf_Bid = MarketInfo("CADCHF", MODE_BID), cadchf_Ask = MarketInfo("CADCHF", MODE_ASK), cadchf = (cadchf_Bid + cadchf_Ask)/2;
   double cadjpy_Bid = MarketInfo("CADJPY", MODE_BID), cadjpy_Ask = MarketInfo("CADJPY", MODE_ASK), cadjpy = (cadjpy_Bid + cadjpy_Ask)/2;
   //     audcad_Bid = ...
   double eurcad_Bid = MarketInfo("EURCAD", MODE_BID), eurcad_Ask = MarketInfo("EURCAD", MODE_ASK), eurcad = (eurcad_Bid + eurcad_Ask)/2;
   double gbpcad_Bid = MarketInfo("GBPCAD", MODE_BID), gbpcad_Ask = MarketInfo("GBPCAD", MODE_ASK), gbpcad = (gbpcad_Bid + gbpcad_Ask)/2;
   //     usdcad_Bid = ...

   bool is_cadlfx.crs = (cadchf_Bid && cadjpy_Bid && audcad_Bid && eurcad_Bid && gbpcad_Bid && usdcad_Bid);
   if (is_cadlfx.crs) {
      cadlfx.crs       = MathPow((cadchf     * cadjpy    ) / (audcad     * eurcad     * gbpcad     * usdcad    ), 1/7.);
      cadlfx.crs_Bid   = MathPow((cadchf_Bid * cadjpy_Bid) / (audcad_Ask * eurcad_Ask * gbpcad_Ask * usdcad_Ask), 1/7.);
      cadlfx.crs_Ask   = MathPow((cadchf_Ask * cadjpy_Ask) / (audcad_Bid * eurcad_Bid * gbpcad_Bid * usdcad_Bid), 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_CAD] = mainIndex[I_USD] / usdcad;
      cadlfx.main_Bid  = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
      cadlfx.main_Ask  = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
   }
   isMainIndex[I_CAD] = isMainIndex[I_USD];

   // CHFLFX
   double chfjpy_Bid = MarketInfo("CHFJPY", MODE_BID), chfjpy_Ask = MarketInfo("CHFJPY", MODE_ASK), chfjpy = (chfjpy_Bid + chfjpy_Ask)/2;
   //     audchf_Bid = ...
   //     cadchf_Bid = ...
   double eurchf_Bid = MarketInfo("EURCHF", MODE_BID), eurchf_Ask = MarketInfo("EURCHF", MODE_ASK), eurchf = (eurchf_Bid + eurchf_Ask)/2;
   double gbpchf_Bid = MarketInfo("GBPCHF", MODE_BID), gbpchf_Ask = MarketInfo("GBPCHF", MODE_ASK), gbpchf = (gbpchf_Bid + gbpchf_Ask)/2;
   //     usdchf_Bid = ...
   bool is_chflfx.crs = (chfjpy_Bid && audchf_Bid && cadchf_Bid && eurchf_Bid && gbpchf_Bid && usdchf_Bid);
   if (is_chflfx.crs) {
      chflfx.crs     = MathPow(chfjpy     / (audchf     * cadchf     * eurchf     * gbpchf     * usdchf    ), 1/7.);
      chflfx.crs_Bid = MathPow(chfjpy_Bid / (audchf_Ask * cadchf_Ask * eurchf_Ask * gbpchf_Ask * usdchf_Ask), 1/7.);
      chflfx.crs_Ask = MathPow(chfjpy_Ask / (audchf_Bid * cadchf_Bid * eurchf_Bid * gbpchf_Bid * usdchf_Bid), 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_CHF] = mainIndex[I_USD] / usdchf;
      chflfx.main_Bid  = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
      chflfx.main_Ask  = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
   }
   isMainIndex[I_CHF] = isMainIndex[I_USD];
   /*
   chfjpy = usdjpy / usdchf
   audchf = audusd * usdchf
   cadchf = usdchf / usdcad
   eurchf = eurusd * usdchf
   gbpchf = gbpusd * usdchf

            |                       chfjpy                        |
   CHFLFX = | --------------------------------------------------- | ^ 1/7
            |     audchf * cadchf * eurchf * gbpchf * usdchf      |


            |                                  (usdjpy/usdchf)                                     |
          = | ------------------------------------------------------------------------------------ | ^ 1/7
            | (audusd * usdchf) * (usdchf/usdcad) * (eurusd * usdchf) * (gbpusd * usdchf) * usdchf |


            |                                         usdjpy                                          |
          = | --------------------------------------------------------------------------------------- | ^ 1/7
            | usdchf * audusd * usdchf * (usdchf/usdcad) * eurusd * usdchf * gbpusd * usdchf * usdchf |


            |    1           usdcad * usdjpy      |
          = | -------- * ------------------------ | ^ 1/7
            | usdchf^6   audusd * eurusd * gbpusd |


            |      usdcad * usdchf * usdjpy       |
          = | ----------------------------------- | ^ 1/7
            | usdchf^7 * audusd * eurusd * gbpusd |


            |     1    |         | usdcad * usdchf * usdjpy |
          = | -------- | ^ 1/7 * | ------------------------ | ^ 1/7
            | usdchf^7 |         | audusd * eurusd * gbpusd |


            | usdcad * usdchf * usdjpy |
          = | ------------------------ | ^ 1/7 / usdchf
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
   bool is_eurlfx.crs = (euraud_Bid && eurcad_Bid && eurchf_Bid && eurgbp_Bid && eurjpy_Bid && eurusd_Bid);
   if (is_eurlfx.crs) {
      eurlfx.crs     = MathPow((euraud     * eurcad     * eurchf     * eurgbp     * eurjpy     * eurusd    ), 1/7.);
      eurlfx.crs_Bid = MathPow((euraud_Bid * eurcad_Bid * eurchf_Bid * eurgbp_Bid * eurjpy_Bid * eurusd_Bid), 1/7.);
      eurlfx.crs_Ask = MathPow((euraud_Ask * eurcad_Ask * eurchf_Ask * eurgbp_Ask * eurjpy_Ask * eurusd_Ask), 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_EUR] = mainIndex[I_USD] * eurusd;
      eurlfx.main_Bid  = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
      eurlfx.main_Ask  = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
   }
   isMainIndex[I_EUR] = isMainIndex[I_USD];

   // GBPLFX
   //     gbpaud_Bid = ...
   //     gbpcad_Bid = ...
   //     gbpchf_Bid = ...
   double gbpjpy_Bid = MarketInfo("GBPJPY", MODE_BID), gbpjpy_Ask = MarketInfo("GBPJPY", MODE_ASK), gbpjpy = (gbpjpy_Bid + gbpjpy_Ask)/2;
   //     gbpusd_Bid = ...
   //     eurgbp_Bid = ...
   bool is_gbplfx.crs = (gbpaud_Bid && gbpcad_Bid && gbpchf_Bid && gbpjpy_Bid && gbpusd_Bid && eurgbp_Bid);
   if (is_gbplfx.crs) {
      gbplfx.crs     = MathPow((gbpaud     * gbpcad     * gbpchf     * gbpjpy     * gbpusd    ) / eurgbp    , 1/7.);
      gbplfx.crs_Bid = MathPow((gbpaud_Bid * gbpcad_Bid * gbpchf_Bid * gbpjpy_Bid * gbpusd_Bid) / eurgbp_Ask, 1/7.);
      gbplfx.crs_Ask = MathPow((gbpaud_Ask * gbpcad_Ask * gbpchf_Ask * gbpjpy_Ask * gbpusd_Ask) / eurgbp_Bid, 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_GBP] = mainIndex[I_USD] * gbpusd;
      gbplfx.main_Bid  = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
      gbplfx.main_Ask  = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
   }
   isMainIndex[I_GBP] = isMainIndex[I_USD];

   // JPYLFX
   //     audjpy_Bid = ...
   //     cadjpy_Bid = ...
   //     chfjpy_Bid = ...
   //     eurjpy_Bid = ...
   //     gbpjpy_Bid = ...
   //     usdjpy_Bid = ...
   bool is_jpylfx.crs = (audjpy_Bid && cadjpy_Bid && chfjpy_Bid && eurjpy_Bid && gbpjpy_Bid && usdjpy_Bid);
   if (is_jpylfx.crs) {
      jpylfx.crs     = 100 * MathPow(1 / (audjpy     * cadjpy     * chfjpy     * eurjpy     * gbpjpy     * usdjpy    ), 1/7.);
      jpylfx.crs_Bid = 100 * MathPow(1 / (audjpy_Ask * cadjpy_Ask * chfjpy_Ask * eurjpy_Ask * gbpjpy_Ask * usdjpy_Ask), 1/7.);
      jpylfx.crs_Ask = 100 * MathPow(1 / (audjpy_Bid * cadjpy_Bid * chfjpy_Bid * eurjpy_Bid * gbpjpy_Bid * usdjpy_Bid), 1/7.);
   }
   if (isMainIndex[I_USD]) {
      mainIndex[I_JPY] = 100 * mainIndex[I_USD] / usdjpy;
      jpylfx.main_Bid  = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
      jpylfx.main_Ask  = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
   }
   isMainIndex[I_JPY] = isMainIndex[I_USD];

   // NZDLFX
   double audnzd_Bid = MarketInfo("AUDNZD", MODE_BID), audnzd_Ask = MarketInfo("AUDNZD", MODE_ASK), audnzd = (audnzd_Bid + audnzd_Ask)/2;
   double eurnzd_Bid = MarketInfo("EURNZD", MODE_BID), eurnzd_Ask = MarketInfo("EURNZD", MODE_ASK), eurnzd = (eurnzd_Bid + eurnzd_Ask)/2;
   double gbpnzd_Bid = MarketInfo("GBPNZD", MODE_BID), gbpnzd_Ask = MarketInfo("GBPNZD", MODE_ASK), gbpnzd = (gbpnzd_Bid + gbpnzd_Ask)/2;
   double nzdcad_Bid = MarketInfo("NZDCAD", MODE_BID), nzdcad_Ask = MarketInfo("NZDCAD", MODE_ASK), nzdcad = (nzdcad_Bid + nzdcad_Ask)/2;
   double nzdchf_Bid = MarketInfo("NZDCHF", MODE_BID), nzdchf_Ask = MarketInfo("NZDCHF", MODE_ASK), nzdchf = (nzdchf_Bid + nzdchf_Ask)/2;
   double nzdjpy_Bid = MarketInfo("NZDJPY", MODE_BID), nzdjpy_Ask = MarketInfo("NZDJPY", MODE_ASK), nzdjpy = (nzdjpy_Bid + nzdjpy_Ask)/2;
   double nzdusd_Bid = MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask = MarketInfo("NZDUSD", MODE_ASK), nzdusd = (nzdusd_Bid + nzdusd_Ask)/2;
   bool is_nzdlfx.crs = (audnzd_Bid && eurnzd_Bid && gbpnzd_Bid && nzdcad_Bid && nzdchf_Bid && nzdjpy_Bid && nzdusd_Bid);
   if (is_nzdlfx.crs) {
      nzdlfx.crs     = MathPow((nzdcad     * nzdchf     * nzdjpy     * nzdusd    ) / (audnzd     * eurnzd     * gbpnzd    ), 1/7.);
      nzdlfx.crs_Bid = MathPow((nzdcad_Bid * nzdchf_Bid * nzdjpy_Bid * nzdusd_Bid) / (audnzd_Ask * eurnzd_Ask * gbpnzd_Ask), 1/7.);
      nzdlfx.crs_Ask = MathPow((nzdcad_Ask * nzdchf_Ask * nzdjpy_Ask * nzdusd_Ask) / (audnzd_Bid * eurnzd_Bid * gbpnzd_Bid), 1/7.);
   }
   if (isMainIndex[I_USD] && nzdusd_Bid) {
      mainIndex[I_NZD] = mainIndex[I_USD] * nzdusd;
      nzdlfx.main_Bid  = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
      nzdlfx.main_Ask  = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
   }
   isMainIndex[I_NZD] = (isMainIndex[I_USD] && nzdusd_Bid);
   /*
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


            | (nzdcad/nzdusd) * (nzdchf/nzdusd) * nzdjpy/nzdusd * nzdusd^7 |
          = | ------------------------------------------------------------ | ^ 1/7
            |   (audnzd * nzdusd) * (eurnzd * nzdusd) * (gbpnzd * nzdusd)  |


            | (nzdcad/nzdusd) * (nzdchf/nzdusd) * nzdjpy/nzdusd * nzdusd^7 |
          = | ------------------------------------------------------------ | ^ 1/7
            |              audnzd * eurnzd * gbpnzd * nzdusd^3             |


            | nzdcad   nzdchf   nzdjpy               nzdusd^7                |
          = | ------ * ------ * ------ * ----------------------------------- | ^ 1/7
            | nzdusd   nzdusd   nzdusd   audnzd * eurnzd * gbpnzd * nzdusd^3 |


            | nzdcad * nzdchf * nzdjpy * nzdusd^7 |
          = | ----------------------------------- | ^ 1/7
            | audnzd * eurnzd * gbpnzd * nzdusd^6 |


            | nzdcad * nzdchf * nzdjpy * nzdusd |
          = | --------------------------------- | ^ 1/7
            |      audnzd * eurnzd * gbpnzd     |
   */

   // USDX
   //     usdcad_Bid = ...
   //     usdchf_Bid = ...
   //     usdjpy_Bid = ...
   double usdsek_Bid = MarketInfo("USDSEK", MODE_BID), usdsek_Ask = MarketInfo("USDSEK", MODE_ASK), usdsek = (usdsek_Bid + usdsek_Ask)/2;
   //     eurusd_Bid = ...
   //     gbpusd_Bid = ...
   bool is_usdx.crs = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
   if (is_usdx.crs) {
      mainIndex[I_USX] = 50.14348112 * (MathPow(usdcad    , 0.091) * MathPow(usdchf    , 0.036) * MathPow(usdjpy    , 0.136) * MathPow(usdsek    , 0.042)) / (MathPow(eurusd    , 0.576) * MathPow(gbpusd    , 0.119));
      usdx.main_Bid    = 50.14348112 * (MathPow(usdcad_Bid, 0.091) * MathPow(usdchf_Bid, 0.036) * MathPow(usdjpy_Bid, 0.136) * MathPow(usdsek_Bid, 0.042)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
      usdx.main_Ask    = 50.14348112 * (MathPow(usdcad_Ask, 0.091) * MathPow(usdchf_Ask, 0.036) * MathPow(usdjpy_Ask, 0.136) * MathPow(usdsek_Ask, 0.042)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
   }
   isMainIndex[I_USX] = is_usdx.crs;
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

   bool is_eurx.crs = (eurchf_Bid && eurgbp_Bid && eurjpy_Bid && eursek_Bid && eurusd_Bid);
   if (is_eurx.crs) {
      mainIndex[I_EUX] = 34.38805726 * MathPow(eurchf    , 0.1113) * MathPow(eurgbp    , 0.3056) * MathPow(eurjpy    , 0.1891) * MathPow(eursek    , 0.0785) * MathPow(eurusd    , 0.3155);
      eurx.main_Bid    = 34.38805726 * MathPow(eurchf_Bid, 0.1113) * MathPow(eurgbp_Bid, 0.3056) * MathPow(eurjpy_Bid, 0.1891) * MathPow(eursek_Bid, 0.0785) * MathPow(eurusd_Bid, 0.3155);
      eurx.main_Ask    = 34.38805726 * MathPow(eurchf_Ask, 0.1113) * MathPow(eurgbp_Ask, 0.3056) * MathPow(eurjpy_Ask, 0.1891) * MathPow(eursek_Ask, 0.0785) * MathPow(eurusd_Ask, 0.3155);
   }
   isMainIndex[I_EUX] = is_eurx.crs;
   /*
   EURX = 34.38805726 * EURCHF^0.1113 * EURGBP^0.3056 * EURJPY^0.1891 * EURSEK^0.0785 * EURUSD^0.3155
   */


   // Fehlerbehandlung
   int error = GetLastError();                                     // TODO: ERS_HISTORY_UPDATE für welches Symbol,Timeframe ???
   if (error == ERS_HISTORY_UPDATE)                                return(!SetLastError(error));
   if (IsError(error)) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) return(!catch("UpdateInfos(1)", error));


   // Cross-Indizes
   string sValue            = "-";                                                                                                                       ObjectSetText(labels[I_USD] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!AUD.Enabled) sValue = "off"; else if (is_audlfx.crs) sValue = NumberToStr(NormalizeDouble(audlfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_AUD] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!CAD.Enabled) sValue = "off"; else if (is_cadlfx.crs) sValue = NumberToStr(NormalizeDouble(cadlfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_CAD] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!CHF.Enabled) sValue = "off"; else if (is_chflfx.crs) sValue = NumberToStr(NormalizeDouble(chflfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_CHF] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!EUR.Enabled) sValue = "off"; else if (is_eurlfx.crs) sValue = NumberToStr(NormalizeDouble(eurlfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_EUR] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!GBP.Enabled) sValue = "off"; else if (is_gbplfx.crs) sValue = NumberToStr(NormalizeDouble(gbplfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_GBP] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!JPY.Enabled) sValue = "off"; else if (is_jpylfx.crs) sValue = NumberToStr(NormalizeDouble(jpylfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_JPY] +".quote.cross",  sValue, fontSize, fontName, fontColor);
   if (!NZD.Enabled) sValue = "off"; else if (is_nzdlfx.crs) sValue = NumberToStr(NormalizeDouble(nzdlfx.crs, 5), ".4'"); else sValue = " ";             ObjectSetText(labels[I_NZD] +".quote.cross",  sValue, fontSize, fontName, fontColor);
                     sValue = "-";                                                                                                                       ObjectSetText(labels[I_USX] +".quote.cross",  sValue, fontSize, fontName, fontColor);
                     sValue = "-";                                                                                                                       ObjectSetText(labels[I_EUX] +".quote.cross",  sValue, fontSize, fontName, fontColor);

   // Cross-Spreads
                                       sValue = " ";                                                                                                     ObjectSetText(labels[I_USD] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!AUD.Enabled || !is_audlfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((audlfx.crs_Ask-audlfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_AUD] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!CAD.Enabled || !is_cadlfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((cadlfx.crs_Ask-cadlfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_CAD] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!CHF.Enabled || !is_chflfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((chflfx.crs_Ask-chflfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_CHF] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!EUR.Enabled || !is_eurlfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((eurlfx.crs_Ask-eurlfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_EUR] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!GBP.Enabled || !is_gbplfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((gbplfx.crs_Ask-gbplfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_GBP] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!JPY.Enabled || !is_jpylfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((jpylfx.crs_Ask-jpylfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_JPY] +".spread.cross", sValue, fontSize, fontName, fontColor);
   if (!NZD.Enabled || !is_nzdlfx.crs) sValue = " "; else sValue = "("+ DoubleToStr((nzdlfx.crs_Ask-nzdlfx.crs_Bid)*10000, 1) +")";                      ObjectSetText(labels[I_NZD] +".spread.cross", sValue, fontSize, fontName, fontColor);
                                       sValue = " ";                                                                                                     ObjectSetText(labels[I_USX] +".spread.cross", sValue, fontSize, fontName, fontColor);
                                       sValue = " ";                                                                                                     ObjectSetText(labels[I_EUX] +".spread.cross", sValue, fontSize, fontName, fontColor);

   // Main-Indizes
   if (!USD.Enabled ) sValue = "off"; else if (isMainIndex[I_USD]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_USD], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_USD] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!AUD.Enabled ) sValue = "off"; else if (isMainIndex[I_AUD]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_AUD], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_AUD] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!CAD.Enabled ) sValue = "off"; else if (isMainIndex[I_CAD]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_CAD], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_CAD] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!CHF.Enabled ) sValue = "off"; else if (isMainIndex[I_CHF]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_CHF], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_CHF] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!EUR.Enabled ) sValue = "off"; else if (isMainIndex[I_EUR]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_EUR], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_EUR] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!GBP.Enabled ) sValue = "off"; else if (isMainIndex[I_GBP]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_GBP], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_GBP] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!JPY.Enabled ) sValue = "off"; else if (isMainIndex[I_JPY]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_JPY], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_JPY] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!NZD.Enabled ) sValue = "off"; else if (isMainIndex[I_NZD]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_NZD], 5), ".4'"); else sValue = " "; ObjectSetText(labels[I_NZD] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!USDX.Enabled) sValue = "off"; else if (isMainIndex[I_USX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_USX], 3), ".2'"); else sValue = " "; ObjectSetText(labels[I_USX] +".quote.main",   sValue, fontSize, fontName, fontColor);
   if (!EURX.Enabled) sValue = "off"; else if (isMainIndex[I_EUX]) sValue = NumberToStr(NormalizeDouble(mainIndex[I_EUX], 3), ".2'"); else sValue = " "; ObjectSetText(labels[I_EUX] +".quote.main",   sValue, fontSize, fontName, fontColor);

   // Main-Spreads
   if (!USD.Enabled  || !isMainIndex[I_USD]) sValue = " "; else sValue = "("+ DoubleToStr((usdlfx.main_Ask-usdlfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_USD] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!AUD.Enabled  || !isMainIndex[I_AUD]) sValue = " "; else sValue = "("+ DoubleToStr((audlfx.main_Ask-audlfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_AUD] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!CAD.Enabled  || !isMainIndex[I_CAD]) sValue = " "; else sValue = "("+ DoubleToStr((cadlfx.main_Ask-cadlfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_CAD] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!CHF.Enabled  || !isMainIndex[I_CHF]) sValue = " "; else sValue = "("+ DoubleToStr((chflfx.main_Ask-chflfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_CHF] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!EUR.Enabled  || !isMainIndex[I_EUR]) sValue = " "; else sValue = "("+ DoubleToStr((eurlfx.main_Ask-eurlfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_EUR] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!GBP.Enabled  || !isMainIndex[I_GBP]) sValue = " "; else sValue = "("+ DoubleToStr((gbplfx.main_Ask-gbplfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_GBP] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!JPY.Enabled  || !isMainIndex[I_JPY]) sValue = " "; else sValue = "("+ DoubleToStr((jpylfx.main_Ask-jpylfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_JPY] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!NZD.Enabled  || !isMainIndex[I_NZD]) sValue = " "; else sValue = "("+ DoubleToStr((nzdlfx.main_Ask-nzdlfx.main_Bid)*10000, 1) +")";              ObjectSetText(labels[I_NZD] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!USDX.Enabled || !isMainIndex[I_USX]) sValue = " "; else sValue = "("+ DoubleToStr((  usdx.main_Ask-  usdx.main_Bid)*  100, 1) +")";              ObjectSetText(labels[I_USX] +".spread.main",  sValue, fontSize, fontName, fontColor);
   if (!EURX.Enabled || !isMainIndex[I_EUX]) sValue = " "; else sValue = "("+ DoubleToStr((  eurx.main_Ask-  eurx.main_Bid)*  100, 1) +")";              ObjectSetText(labels[I_EUX] +".spread.main",  sValue, fontSize, fontName, fontColor);

   // Animation
   static int size, char=-1; if (char == -1) size = ArraySize(label.animation.chars);
   char = Tick % size;
   ObjectSetText(label.animation, label.animation.chars[char], fontSize, fontName, fontColor);


   // LFX-Indizes aufzeichnen
   if (!RecordLfxIndices())
      return(false);

   return(!catch("UpdateInfos(2)"));
}


/**
 * Zeichnet die LFX-Indizes auf.
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

         // Virtuelle Ticks werden nur aufgezeichnet, wenn sich der Indexwert geändert hat.
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
               string description = names[i] + ifString(i==I_EUX || i==I_USX, " Index (ICE)", " Index (LiteForex)");
               int    format      = 400;
               bool   synthetic   = true;

               hSet[i] = HistorySet.Get(symbols[i], synthetic);
               if (hSet[i] == -1)
                  hSet[i] = HistorySet.Create(symbols[i], description, digits[i], format, synthetic);
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

