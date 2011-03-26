/**
 *
 */
#include <stdlib.mqh>


#property indicator_chart_window


string fontName  = "Tahoma";
int    fontSize  = 10;
color  fontColor = Blue;
color  bgColor   = C'212,208,200';

string symbols[] = {"USDLFX","GBPLFX","CHFLFX","CADLFX","AUDLFX","EURLFX","JPYLFX"};
string labels[];

#define USDLFX  0
#define GBPLFX  1
#define CHFLFX  2
#define CADLFX  3
#define AUDLFX  4
#define EURLFX  5
#define JPYLFX  6


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   CreateLabels();
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   ValidBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else                                               ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // nach Terminal-Start Abschluß der Initialisierung überprüfen
   if (Bars == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   static int error = NO_ERROR;

   if (error==NO_ERROR || error==ERR_HISTORY_UPDATE)
      error = UpdateInfos();

   return(catch("start()"));
}


/**
 *
 */
int CreateLabels() {
   string expertName = WindowExpertName();
   int c = 10;

   // Background
   c++;
   string label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, 130);
      ObjectSet(label, OBJPROP_YDISTANCE, 130);
      ObjectSetText(label, "g", 92, "Webdings", bgColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, 110);
      ObjectSet(label, OBJPROP_YDISTANCE, 130);
      ObjectSetText(label, "g", 92, "Webdings", bgColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Textlabel
   int yCoord = 134;
   for (int i=0; i < ArraySize(symbols); i++) {
      c++;
      label = StringConcatenate(expertName, ".", c, ".", StringLeft(symbols[i], 3));
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  216);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, StringLeft(symbols[i], 3) +":", fontSize, fontName, fontColor);
         RegisterChartObject(label, labels);
         symbols[i] = label;
      }
      else GetLastError();

      label = StringConcatenate(label, ".quote");
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  156);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         RegisterChartObject(label, labels);
      }
      else GetLastError();

      label = StringConcatenate(label, ".spread");
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  116);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }

   return(catch("CreateLabels()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int UpdateInfos() {
   int error;

   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(1) USDCHF", error));
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(2) USDJPY", error));
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(3) USDCAD", error));
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(4) EURUSD", error));
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(5) GBPUSD", error));
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(6) AUDUSD", error));

   //double gbpchf_Bid = MarketInfo("GBPCHF", MODE_BID), gbpchf_Ask = MarketInfo("GBPCHF", MODE_ASK), gbpchf = (gbpchf_Bid + gbpchf_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(7) GBPCHF", error));
   //double gbpcad_Bid = MarketInfo("GBPCAD", MODE_BID), gbpcad_Ask = MarketInfo("GBPCAD", MODE_ASK), gbpcad = (gbpcad_Bid + gbpcad_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(8) GBPCAD", error));
   //double gbpaud_Bid = MarketInfo("GBPAUD", MODE_BID), gbpaud_Ask = MarketInfo("GBPAUD", MODE_ASK), gbpaud = (gbpaud_Bid + gbpaud_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(9) GBPAUD", error));
   //double gbpjpy_Bid = MarketInfo("GBPJPY", MODE_BID), gbpjpy_Ask = MarketInfo("GBPJPY", MODE_ASK), gbpjpy = (gbpjpy_Bid + gbpjpy_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(10) GBPJPY", error));
   //double eurgbp_Bid = MarketInfo("EURGBP", MODE_BID), eurgbp_Ask = MarketInfo("EURGBP", MODE_ASK), eurgbp = (eurgbp_Bid + eurgbp_Ask)/2; error = GetLastError(); if (error != NO_ERROR) return(catch("UpdateInfos(11) EURGBP", error));

   double usdlfx     = MathPow((usdchf     * usdjpy     * usdcad    ) / (eurusd     * gbpusd     * audusd    ), 1/7.0);
   double usdlfx_Bid = MathPow((usdchf_Bid * usdjpy_Bid * usdcad_Bid) / (eurusd_Ask * gbpusd_Ask * audusd_Ask), 1/7.0);
   double usdlfx_Ask = MathPow((usdchf_Ask * usdjpy_Ask * usdcad_Ask) / (eurusd_Bid * gbpusd_Bid * audusd_Bid), 1/7.0);

   double gbplfx     = usdlfx * gbpusd;
   //double gbplfx_Bid = MathPow(gbpusd_Bid * gbpchf_Bid * gbpcad_Bid * gbpaud_Bid * gbpjpy_Bid / eurgbp_Ask, 1/7.0);
   //double gbplfx_Ask = MathPow(gbpusd_Ask * gbpchf_Ask * gbpcad_Ask * gbpaud_Ask * gbpjpy_Ask / eurgbp_Bid, 1/7.0);

   double chflfx = usdlfx / usdchf;
   double cadlfx = usdlfx / usdcad;
   double audlfx = usdlfx * audusd;
   double eurlfx = usdlfx * eurusd;
   double jpylfx = usdjpy / usdlfx;

   ObjectSetText(symbols[USDLFX] +".quote", NumberToStr(NormalizeDouble(usdlfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[GBPLFX] +".quote", NumberToStr(NormalizeDouble(gbplfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[CHFLFX] +".quote", NumberToStr(NormalizeDouble(chflfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[CADLFX] +".quote", NumberToStr(NormalizeDouble(cadlfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[AUDLFX] +".quote", NumberToStr(NormalizeDouble(audlfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[EURLFX] +".quote", NumberToStr(NormalizeDouble(eurlfx, 5), ".4'"), fontSize, fontName, fontColor);
   ObjectSetText(symbols[JPYLFX] +".quote", NumberToStr(NormalizeDouble(jpylfx, 3), ".2'"), fontSize, fontName, fontColor);

   ObjectSetText(symbols[USDLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((usdlfx_Ask-usdlfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   //ObjectSetText(symbols[GBPLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((gbplfx_Ask-gbplfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);

   error = GetLastError();
   if (error == ERR_HISTORY_UPDATE)
      return(error);
   return(catch("UpdateInfos(12)", error));
}

