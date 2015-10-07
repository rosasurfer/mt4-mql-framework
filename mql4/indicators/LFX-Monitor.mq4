/**
 * Berechnet die Kurse der momentan verfügbaren LiteForex-Indizes und zeigt sie an. Ein Währungs-Index kann direkt über die Kurse seiner beteiligten
 * Crosses oder über das Verhältnis des USD-Indexes zum USD-Kurs der Währung berechnet werden, beide Werte unterscheiden sich nur im resultierenden
 * Spread. Wird eine Indexposition nicht über seine Crosses (im Durchschnitt höherer Spread), sondern über den USD-Index abgebildet, sind die Anzahl
 * der Teilpositionen und entsprechend die Margin-Requirements höher.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


#property indicator_chart_window


string fontName  = "Tahoma";
int    fontSize  = 10;
color  fontColor = Blue;
color  bgColor   = C'212,208,200';

string lfx.labels    [8];
string lfx.currencies[ ] = { "USD"   , "AUD"   , "CAD"   , "CHF"   , "EUR"   , "GBP"   , "JPY"   , "NZD"    };
string lfx.symbols   [ ] = { "USDLFX", "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "LFXJPY", "NZDLFX" };
int    lfx.digits    [ ] = {        5,        5,        5,        5,        5,        5,        3,        5 };    // LFXJPY = false: wird nicht aufgezeichnet, da das Aufzeichnen
bool   lfx.record    [ ] = {     true,     true,     true,     true,     true,     true,    false,     true };    // aller Indizes das 64-File-Limit eines MQL-Moduls sprengt.
double lfx.usd       [8];                                            // über den USD-Index berechneter LFX-Index je Währung
bool   isLfx.usd     [8];                                            // ob der über den USD-Index berechnete LFX-Index einer Währung verfügbar ist
int    lfx.hSet      [8];                                            // HistorySet-Handles der LFX-Indizes

#define I_USD  0                                                     // Array-Indizes
#define I_AUD  1
#define I_CAD  2
#define I_CHF  3
#define I_EUR  4
#define I_GBP  5
#define I_JPY  6
#define I_NZD  7


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   CreateLabels();

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit(1)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);

   int size = ArraySize(lfx.hSet);
   for (int i=0; i < size; i++) {
      if (lfx.hSet[i] != 0) {
         if (!HistorySet.Close(lfx.hSet[i])) return(!SetLastError(history.GetLastError()));
         lfx.hSet[i] = NULL;
      }
   }
   return(catch("onDeinit(1)"));
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
   int c = 10;                               // Zählervariable für Label, zweistellig

   // Backgrounds
   c++;
   string label = StringConcatenate(__NAME__, ".", c, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 114);
      ObjectSet    (label, OBJPROP_YDISTANCE,  55);
      ObjectSetText(label, "g", 114, "Webdings", bgColor);
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
      ObjectSet    (label, OBJPROP_YDISTANCE, 55);
      ObjectSetText(label, "g", 114, "Webdings", bgColor);
      ObjectRegister(label);
   }
   else GetLastError();

   // Headerzeile
   int col3width = 110;
   int yCoord    =  58;
   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Header.cross");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 44+col3width);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "via crosses", fontSize, fontName, fontColor);
      ObjectRegister(label);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Header.viaUSD");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 44);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "via USDLFX", fontSize, fontName, fontColor);
      ObjectRegister(label);
   }
   else GetLastError();

   // Datenzeilen
   yCoord += 16;
   for (int i=0; i < ArraySize(lfx.currencies); i++) {
      c++;
      // Währung
      label = StringConcatenate(__NAME__, ".", c, ".", lfx.currencies[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 119+col3width);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, lfx.currencies[i] +":", fontSize, fontName, fontColor);
         ObjectRegister(label);
         lfx.labels[i] = label;
      }
      else GetLastError();

      // Index via Crosses
      label = StringConcatenate(lfx.labels[i], ".quote.cross");
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

      // Spread via Crosses
      label = StringConcatenate(lfx.labels[i], ".spread.cross");
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

      // Index via USDLFX
      label = StringConcatenate(lfx.labels[i], ".quote.viaUSD");
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

      // Spread via USD
      label = StringConcatenate(lfx.labels[i], ".spread.viaUSD");
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
 * Berechnet die Indizes über die beteiligten Crosses (???lfx.crs-Variablen) und über den USD-Index (???lfx.usd-Variablen) und zeigt sie an.
 *
 * @return int - Fehlerstatus
 */
int UpdateInfos() {
   double usdlfx.crs, usdlfx.crs_Bid, usdlfx.crs_Ask, usdlfx.usd_Bid, usdlfx.usd_Ask;
   double audlfx.crs, audlfx.crs_Bid, audlfx.crs_Ask, audlfx.usd_Bid, audlfx.usd_Ask;
   double cadlfx.crs, cadlfx.crs_Bid, cadlfx.crs_Ask, cadlfx.usd_Bid, cadlfx.usd_Ask;
   double chflfx.crs, chflfx.crs_Bid, chflfx.crs_Ask, chflfx.usd_Bid, chflfx.usd_Ask;
   double eurlfx.crs, eurlfx.crs_Bid, eurlfx.crs_Ask, eurlfx.usd_Bid, eurlfx.usd_Ask;
   double gbplfx.crs, gbplfx.crs_Bid, gbplfx.crs_Ask, gbplfx.usd_Bid, gbplfx.usd_Ask;
   double jpylfx.crs, jpylfx.crs_Bid, jpylfx.crs_Ask, jpylfx.usd_Bid, jpylfx.usd_Ask;
   double nzdlfx.crs, nzdlfx.crs_Bid, nzdlfx.crs_Ask, nzdlfx.usd_Bid, nzdlfx.usd_Ask;

   // USDLFX
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2;

   bool is_usd.crs = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
   if (is_usd.crs) {
      usdlfx.crs     = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
      usdlfx.crs_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
      usdlfx.crs_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);

      lfx.usd[I_USD] = usdlfx.crs;
      usdlfx.usd_Bid = usdlfx.crs_Bid;
      usdlfx.usd_Ask = usdlfx.crs_Ask;
   }
   isLfx.usd[I_USD] = is_usd.crs;

   // AUDLFX
   double audcad_Bid = MarketInfo("AUDCAD", MODE_BID), audcad_Ask = MarketInfo("AUDCAD", MODE_ASK), audcad = (audcad_Bid + audcad_Ask)/2;
   double audchf_Bid = MarketInfo("AUDCHF", MODE_BID), audchf_Ask = MarketInfo("AUDCHF", MODE_ASK), audchf = (audchf_Bid + audchf_Ask)/2;
   double audjpy_Bid = MarketInfo("AUDJPY", MODE_BID), audjpy_Ask = MarketInfo("AUDJPY", MODE_ASK), audjpy = (audjpy_Bid + audjpy_Ask)/2;
   //     audusd_Bid = ...
   double euraud_Bid = MarketInfo("EURAUD", MODE_BID), euraud_Ask = MarketInfo("EURAUD", MODE_ASK), euraud = (euraud_Bid + euraud_Ask)/2;
   double gbpaud_Bid = MarketInfo("GBPAUD", MODE_BID), gbpaud_Ask = MarketInfo("GBPAUD", MODE_ASK), gbpaud = (gbpaud_Bid + gbpaud_Ask)/2;

   bool is_aud.crs = (audcad_Bid && audchf_Bid && audjpy_Bid && audusd_Bid && euraud_Bid && gbpaud_Bid);
   if (is_aud.crs) {
      audlfx.crs     = MathPow((audcad     * audchf     * audjpy     * audusd    ) / (euraud     * gbpaud    ), 1/7.);
      audlfx.crs_Bid = MathPow((audcad_Bid * audchf_Bid * audjpy_Bid * audusd_Bid) / (euraud_Ask * gbpaud_Ask), 1/7.);
      audlfx.crs_Ask = MathPow((audcad_Ask * audchf_Ask * audjpy_Ask * audusd_Ask) / (euraud_Bid * gbpaud_Bid), 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_AUD] = lfx.usd[I_USD] * audusd;
      audlfx.usd_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
      audlfx.usd_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
   }
   isLfx.usd[I_AUD] = is_usd.crs;

   // CADLFX
   double cadchf_Bid = MarketInfo("CADCHF", MODE_BID), cadchf_Ask = MarketInfo("CADCHF", MODE_ASK), cadchf = (cadchf_Bid + cadchf_Ask)/2;
   double cadjpy_Bid = MarketInfo("CADJPY", MODE_BID), cadjpy_Ask = MarketInfo("CADJPY", MODE_ASK), cadjpy = (cadjpy_Bid + cadjpy_Ask)/2;
   //     audcad_Bid = ...
   double eurcad_Bid = MarketInfo("EURCAD", MODE_BID), eurcad_Ask = MarketInfo("EURCAD", MODE_ASK), eurcad = (eurcad_Bid + eurcad_Ask)/2;
   double gbpcad_Bid = MarketInfo("GBPCAD", MODE_BID), gbpcad_Ask = MarketInfo("GBPCAD", MODE_ASK), gbpcad = (gbpcad_Bid + gbpcad_Ask)/2;
   //     usdcad_Bid = ...

   bool is_cad.crs = (cadchf_Bid && cadjpy_Bid && audcad_Bid && eurcad_Bid && gbpcad_Bid && usdcad_Bid);
   if (is_cad.crs) {
      cadlfx.crs       = MathPow((cadchf     * cadjpy    ) / (audcad     * eurcad     * gbpcad     * usdcad    ), 1/7.);
      cadlfx.crs_Bid   = MathPow((cadchf_Bid * cadjpy_Bid) / (audcad_Ask * eurcad_Ask * gbpcad_Ask * usdcad_Ask), 1/7.);
      cadlfx.crs_Ask   = MathPow((cadchf_Ask * cadjpy_Ask) / (audcad_Bid * eurcad_Bid * gbpcad_Bid * usdcad_Bid), 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_CAD] = lfx.usd[I_USD] / usdcad;
      cadlfx.usd_Bid = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
      cadlfx.usd_Ask = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
   }
   isLfx.usd[I_CAD] = is_usd.crs;

   // CHFLFX
   double chfjpy_Bid = MarketInfo("CHFJPY", MODE_BID), chfjpy_Ask = MarketInfo("CHFJPY", MODE_ASK), chfjpy = (chfjpy_Bid + chfjpy_Ask)/2;
   //     audchf_Bid = ...
   //     cadchf_Bid = ...
   double eurchf_Bid = MarketInfo("EURCHF", MODE_BID), eurchf_Ask = MarketInfo("EURCHF", MODE_ASK), eurchf = (eurchf_Bid + eurchf_Ask)/2;
   double gbpchf_Bid = MarketInfo("GBPCHF", MODE_BID), gbpchf_Ask = MarketInfo("GBPCHF", MODE_ASK), gbpchf = (gbpchf_Bid + gbpchf_Ask)/2;
   //     usdchf_Bid = ...
   bool is_chf.crs = (chfjpy_Bid && audchf_Bid && cadchf_Bid && eurchf_Bid && gbpchf_Bid && usdchf_Bid);
   if (is_chf.crs) {
      chflfx.crs     = MathPow(chfjpy     / (audchf     * cadchf     * eurchf     * gbpchf     * usdchf    ), 1/7.);
      chflfx.crs_Bid = MathPow(chfjpy_Bid / (audchf_Ask * cadchf_Ask * eurchf_Ask * gbpchf_Ask * usdchf_Ask), 1/7.);
      chflfx.crs_Ask = MathPow(chfjpy_Ask / (audchf_Bid * cadchf_Bid * eurchf_Bid * gbpchf_Bid * usdchf_Bid), 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_CHF] = lfx.usd[I_USD] / usdchf;
      chflfx.usd_Bid = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
      chflfx.usd_Ask = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
   }
   isLfx.usd[I_CHF] = is_usd.crs;
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
   bool is_eur.crs = (euraud_Bid && eurcad_Bid && eurchf_Bid && eurgbp_Bid && eurjpy_Bid && eurusd_Bid);
   if (is_eur.crs) {
      eurlfx.crs     = MathPow((euraud     * eurcad     * eurchf     * eurgbp     * eurjpy     * eurusd    ), 1/7.);
      eurlfx.crs_Bid = MathPow((euraud_Bid * eurcad_Bid * eurchf_Bid * eurgbp_Bid * eurjpy_Bid * eurusd_Bid), 1/7.);
      eurlfx.crs_Ask = MathPow((euraud_Ask * eurcad_Ask * eurchf_Ask * eurgbp_Ask * eurjpy_Ask * eurusd_Ask), 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_EUR] = lfx.usd[I_USD] * eurusd;
      eurlfx.usd_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
      eurlfx.usd_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
   }
   isLfx.usd[I_EUR] = is_usd.crs;

   // GBPLFX
   //     gbpaud_Bid = ...
   //     gbpcad_Bid = ...
   //     gbpchf_Bid = ...
   double gbpjpy_Bid = MarketInfo("GBPJPY", MODE_BID), gbpjpy_Ask = MarketInfo("GBPJPY", MODE_ASK), gbpjpy = (gbpjpy_Bid + gbpjpy_Ask)/2;
   //     gbpusd_Bid = ...
   //     eurgbp_Bid = ...
   bool is_gbp.crs = (gbpaud_Bid && gbpcad_Bid && gbpchf_Bid && gbpjpy_Bid && gbpusd_Bid && eurgbp_Bid);
   if (is_gbp.crs) {
      gbplfx.crs     = MathPow((gbpaud     * gbpcad     * gbpchf     * gbpjpy     * gbpusd    ) / eurgbp    , 1/7.);
      gbplfx.crs_Bid = MathPow((gbpaud_Bid * gbpcad_Bid * gbpchf_Bid * gbpjpy_Bid * gbpusd_Bid) / eurgbp_Ask, 1/7.);
      gbplfx.crs_Ask = MathPow((gbpaud_Ask * gbpcad_Ask * gbpchf_Ask * gbpjpy_Ask * gbpusd_Ask) / eurgbp_Bid, 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_GBP] = lfx.usd[I_USD] * gbpusd;
      gbplfx.usd_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
      gbplfx.usd_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
   }
   isLfx.usd[I_GBP] = is_usd.crs;

   // JPYLFX
   //     audjpy_Bid = ...
   //     cadjpy_Bid = ...
   //     chfjpy_Bid = ...
   //     eurjpy_Bid = ...
   //     gbpjpy_Bid = ...
   //     usdjpy_Bid = ...
   bool is_jpy.crs = (audjpy_Bid && cadjpy_Bid && chfjpy_Bid && eurjpy_Bid && gbpjpy_Bid && usdjpy_Bid);
   if (is_jpy.crs) {
      jpylfx.crs     = MathPow((audjpy     * cadjpy     * chfjpy     * eurjpy     * gbpjpy     * usdjpy    ), 1/7.);
      jpylfx.crs_Bid = MathPow((audjpy_Bid * cadjpy_Bid * chfjpy_Bid * eurjpy_Bid * gbpjpy_Bid * usdjpy_Bid), 1/7.);
      jpylfx.crs_Ask = MathPow((audjpy_Ask * cadjpy_Ask * chfjpy_Ask * eurjpy_Ask * gbpjpy_Ask * usdjpy_Ask), 1/7.);
   }
   if (is_usd.crs) {
      lfx.usd[I_JPY] = usdjpy / lfx.usd[I_USD];
      jpylfx.usd_Bid = usdjpy_Bid / MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
      jpylfx.usd_Ask = usdjpy_Ask / MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
   }
   isLfx.usd[I_JPY] = is_usd.crs;

   // NZDLFX
   double audnzd_Bid = MarketInfo("AUDNZD", MODE_BID), audnzd_Ask = MarketInfo("AUDNZD", MODE_ASK), audnzd = (audnzd_Bid + audnzd_Ask)/2;
   double eurnzd_Bid = MarketInfo("EURNZD", MODE_BID), eurnzd_Ask = MarketInfo("EURNZD", MODE_ASK), eurnzd = (eurnzd_Bid + eurnzd_Ask)/2;
   double gbpnzd_Bid = MarketInfo("GBPNZD", MODE_BID), gbpnzd_Ask = MarketInfo("GBPNZD", MODE_ASK), gbpnzd = (gbpnzd_Bid + gbpnzd_Ask)/2;
   double nzdcad_Bid = MarketInfo("NZDCAD", MODE_BID), nzdcad_Ask = MarketInfo("NZDCAD", MODE_ASK), nzdcad = (nzdcad_Bid + nzdcad_Ask)/2;
   double nzdchf_Bid = MarketInfo("NZDCHF", MODE_BID), nzdchf_Ask = MarketInfo("NZDCHF", MODE_ASK), nzdchf = (nzdchf_Bid + nzdchf_Ask)/2;
   double nzdjpy_Bid = MarketInfo("NZDJPY", MODE_BID), nzdjpy_Ask = MarketInfo("NZDJPY", MODE_ASK), nzdjpy = (nzdjpy_Bid + nzdjpy_Ask)/2;
   double nzdusd_Bid = MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask = MarketInfo("NZDUSD", MODE_ASK), nzdusd = (nzdusd_Bid + nzdusd_Ask)/2;
   bool is_nzd.crs = (audnzd_Bid && eurnzd_Bid && gbpnzd_Bid && nzdcad_Bid && nzdchf_Bid && nzdjpy_Bid && nzdusd_Bid);
   if (is_nzd.crs) {
      nzdlfx.crs     = MathPow((nzdcad     * nzdchf     * nzdjpy     * nzdusd    ) / (audnzd     * eurnzd     * gbpnzd    ), 1/7.);
      nzdlfx.crs_Bid = MathPow((nzdcad_Bid * nzdchf_Bid * nzdjpy_Bid * nzdusd_Bid) / (audnzd_Ask * eurnzd_Ask * gbpnzd_Ask), 1/7.);
      nzdlfx.crs_Ask = MathPow((nzdcad_Ask * nzdchf_Ask * nzdjpy_Ask * nzdusd_Ask) / (audnzd_Bid * eurnzd_Bid * gbpnzd_Bid), 1/7.);
   }
   if (is_usd.crs && nzdusd_Bid) {
      lfx.usd[I_NZD] = lfx.usd[I_USD] * nzdusd;
      nzdlfx.usd_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
      nzdlfx.usd_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
   }
   isLfx.usd[I_NZD] = (is_usd.crs && nzdusd_Bid);
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


   // Fehlerbehandlung
   int error = GetLastError();                                       // TODO: ERS_HISTORY_UPDATE für welches Symbol,Timeframe ???
   if (error == ERS_HISTORY_UPDATE)                 return(SetLastError(error));
   if (IsError(error) && error!=ERR_UNKNOWN_SYMBOL) return(catch("UpdateInfos(1)", error));


   // Index-Anzeige: direkt
   if (is_usd.crs)       ObjectSetText(lfx.labels[I_USD] +".quote.cross",                NumberToStr(NormalizeDouble(usdlfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_USD] +".quote.cross",   " ", fontSize, fontName);
   if (is_aud.crs)       ObjectSetText(lfx.labels[I_AUD] +".quote.cross",                NumberToStr(NormalizeDouble(audlfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_AUD] +".quote.cross",   " ", fontSize, fontName);
   if (is_cad.crs)       ObjectSetText(lfx.labels[I_CAD] +".quote.cross",                NumberToStr(NormalizeDouble(cadlfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CAD] +".quote.cross",   " ", fontSize, fontName);
   if (is_chf.crs)       ObjectSetText(lfx.labels[I_CHF] +".quote.cross",                NumberToStr(NormalizeDouble(chflfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CHF] +".quote.cross",   " ", fontSize, fontName);
   if (is_eur.crs)       ObjectSetText(lfx.labels[I_EUR] +".quote.cross",                NumberToStr(NormalizeDouble(eurlfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_EUR] +".quote.cross",   " ", fontSize, fontName);
   if (is_gbp.crs)       ObjectSetText(lfx.labels[I_GBP] +".quote.cross",                NumberToStr(NormalizeDouble(gbplfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_GBP] +".quote.cross",   " ", fontSize, fontName);
   if (is_jpy.crs)       ObjectSetText(lfx.labels[I_JPY] +".quote.cross",                NumberToStr(NormalizeDouble(jpylfx.crs, 3), ".2'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_JPY] +".quote.cross",   " ", fontSize, fontName);
   if (is_nzd.crs)       ObjectSetText(lfx.labels[I_NZD] +".quote.cross",                NumberToStr(NormalizeDouble(nzdlfx.crs, 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_NZD] +".quote.cross",   " ", fontSize, fontName);

   // Spread-Anzeige: direkt
   if (is_usd.crs)       ObjectSetText(lfx.labels[I_USD] +".spread.cross",  "("+ DoubleToStr((usdlfx.crs_Ask-usdlfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_USD] +".spread.cross",  " ", fontSize, fontName);
   if (is_aud.crs)       ObjectSetText(lfx.labels[I_AUD] +".spread.cross",  "("+ DoubleToStr((audlfx.crs_Ask-audlfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_AUD] +".spread.cross",  " ", fontSize, fontName);
   if (is_cad.crs)       ObjectSetText(lfx.labels[I_CAD] +".spread.cross",  "("+ DoubleToStr((cadlfx.crs_Ask-cadlfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CAD] +".spread.cross",  " ", fontSize, fontName);
   if (is_chf.crs)       ObjectSetText(lfx.labels[I_CHF] +".spread.cross",  "("+ DoubleToStr((chflfx.crs_Ask-chflfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CHF] +".spread.cross",  " ", fontSize, fontName);
   if (is_eur.crs)       ObjectSetText(lfx.labels[I_EUR] +".spread.cross",  "("+ DoubleToStr((eurlfx.crs_Ask-eurlfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_EUR] +".spread.cross",  " ", fontSize, fontName);
   if (is_gbp.crs)       ObjectSetText(lfx.labels[I_GBP] +".spread.cross",  "("+ DoubleToStr((gbplfx.crs_Ask-gbplfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_GBP] +".spread.cross",  " ", fontSize, fontName);
   if (is_jpy.crs)       ObjectSetText(lfx.labels[I_JPY] +".spread.cross",  "("+ DoubleToStr((jpylfx.crs_Ask-jpylfx.crs_Bid)*  100, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_JPY] +".spread.cross",  " ", fontSize, fontName);
   if (is_nzd.crs)       ObjectSetText(lfx.labels[I_NZD] +".spread.cross",  "("+ DoubleToStr((nzdlfx.crs_Ask-nzdlfx.crs_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_NZD] +".spread.cross",  " ", fontSize, fontName);

   // Index-Anzeige: via USDLFX
   if (isLfx.usd[I_USD]) ObjectSetText(lfx.labels[I_USD] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_USD], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_USD] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_AUD]) ObjectSetText(lfx.labels[I_AUD] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_AUD], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_AUD] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_CAD]) ObjectSetText(lfx.labels[I_CAD] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_CAD], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CAD] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_CHF]) ObjectSetText(lfx.labels[I_CHF] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_CHF], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CHF] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_EUR]) ObjectSetText(lfx.labels[I_EUR] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_EUR], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_EUR] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_GBP]) ObjectSetText(lfx.labels[I_GBP] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_GBP], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_GBP] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_JPY]) ObjectSetText(lfx.labels[I_JPY] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_JPY], 3), ".2'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_JPY] +".quote.viaUSD",  " ", fontSize, fontName);
   if (isLfx.usd[I_NZD]) ObjectSetText(lfx.labels[I_NZD] +".quote.viaUSD",           NumberToStr(NormalizeDouble(lfx.usd[I_NZD], 5), ".4'"), fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_NZD] +".quote.viaUSD",  " ", fontSize, fontName);

   // Spread-Anzeige: via USDLFX
   if (isLfx.usd[I_USD]) ObjectSetText(lfx.labels[I_USD] +".spread.viaUSD", "("+ DoubleToStr((usdlfx.usd_Ask-usdlfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_USD] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_AUD]) ObjectSetText(lfx.labels[I_AUD] +".spread.viaUSD", "("+ DoubleToStr((audlfx.usd_Ask-audlfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_AUD] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_CAD]) ObjectSetText(lfx.labels[I_CAD] +".spread.viaUSD", "("+ DoubleToStr((cadlfx.usd_Ask-cadlfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CAD] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_CHF]) ObjectSetText(lfx.labels[I_CHF] +".spread.viaUSD", "("+ DoubleToStr((chflfx.usd_Ask-chflfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_CHF] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_EUR]) ObjectSetText(lfx.labels[I_EUR] +".spread.viaUSD", "("+ DoubleToStr((eurlfx.usd_Ask-eurlfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_EUR] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_GBP]) ObjectSetText(lfx.labels[I_GBP] +".spread.viaUSD", "("+ DoubleToStr((gbplfx.usd_Ask-gbplfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_GBP] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_JPY]) ObjectSetText(lfx.labels[I_JPY] +".spread.viaUSD", "("+ DoubleToStr((jpylfx.usd_Ask-jpylfx.usd_Bid)*  100, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_JPY] +".spread.viaUSD", " ", fontSize, fontName);
   if (isLfx.usd[I_NZD]) ObjectSetText(lfx.labels[I_NZD] +".spread.viaUSD", "("+ DoubleToStr((nzdlfx.usd_Ask-nzdlfx.usd_Bid)*10000, 1) +")", fontSize, fontName, fontColor); else ObjectSetText(lfx.labels[I_NZD] +".spread.viaUSD", " ", fontSize, fontName);



   // LFX-Indizes aufzeichnen
   if (!RecordLfxIndices())
      return(last_error);

   return(catch("UpdateInfos(2)"));
}


/**
 * Zeichnet die LFX-Indizes auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordLfxIndices() {
   if (IsTesting())
      return(true);

   int size = ArraySize(lfx.hSet);

   for (int i=0; i < size; i++) {
      if (lfx.record[i]) /*&&*/ if (isLfx.usd[i]) {
         if (!lfx.hSet[i]) {
            string symbol      = lfx.symbols   [i];
            string description = lfx.currencies[i] +" Index (LiteForex)";
            int    digits      = lfx.digits    [i];
            int    format      = 400;
            bool   synthetic   = true;

            lfx.hSet[i] = HistorySet.Get(symbol, synthetic);
            if (lfx.hSet[i] == -1)
               lfx.hSet[i] = HistorySet.Create(symbol, description, digits, format, synthetic);
            if (!lfx.hSet[i]) return(!SetLastError(history.GetLastError()));
         }

         int flags;
         //flags = HST_COLLECT_TICKS;
         if (!HistorySet.AddTick(lfx.hSet[i], Tick.Time, lfx.usd[i], flags)) return(!SetLastError(history.GetLastError()));
      }
   }
   return(true);
}
