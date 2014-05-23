/**
 * Aktiviert/deaktiviert die Anzeige der offenen LFX-Orders des aktuellen LFX-TradeAccounts.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <win32api.mqh>
#include <LFX/functions.mqh>
#include <structs/LFX_ORDER.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // LFX-Currency setzen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot display LFX orders on a non LFX chart (\""+ Symbol() +"\")", __NAME__, MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   return(catch("onInit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !LFX.ReadDisplayStatus();

   if (status) {
      // Status ON: offene Orders einlesen und anzeigen
      /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
      int orders = LFX.GetOrders(lfxCurrency, OF_OPEN, los);

      for (int i=0; i < orders; i++) {
         if (!ShowOpenOrder(los, i))
            break;
      }
      ArrayResize(los, 0);
   }
   else {
      // Status OFF: alle existierenden Chartobjekte offener Orders löschen
      for (i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "LFX.OpenTicket."))
            ObjectDelete(name);
      }
   }

   // aktuellen Status im Chart speichern
   LFX.SaveDisplayStatus(status);

   if (This.IsTesting())
      WindowRedraw();
   return(last_error);
}


/**
 * Zeigt die angegebene LFX_ORDER an.
 *
 * @param  LFX_ORDER los[] - eine einzelne LFX_ORDER oder ein LFX_ORDER-Array
 * @param  int       index - Arrayindex der zu speichernden Order, wenn los[] ein LFX_ORDER-Array ist.
 *                           Wird ignoriert, wenn los[] eine einzelne LFX_ORDER ist.
 *
 * @return bool - Erfolgsstatus
 */
bool ShowOpenOrder(/*LFX_ORDER*/int los[], int index=NULL) {
   // (1) übergebene Order in eine einzelne Order umkopieren (Parameter los[] kann unterschiedliche Dimensionen haben)
   int dims = ArrayDimension(los); if (dims > 2)   return(!catch("ShowOpenOrder(1)   invalid dimensions of parameter los = "+ dims, ERR_INCOMPATIBLE_ARRAYS));

   /*LFX_ORDER*/int lo[]; ArrayResize(lo, LFX_ORDER.intSize);
   if (dims == 1) {
      // Parameter los[] ist einzelne Order
      if (ArrayRange(los, 0) != LFX_ORDER.intSize) return(!catch("ShowOpenOrder(2)   invalid size of parameter los["+ ArrayRange(los, 0) +"]", ERR_INCOMPATIBLE_ARRAYS));
      ArrayCopy(lo, los);
   }
   else {
      // Parameter los[] ist Order-Array
      if (ArrayRange(los, 1) != LFX_ORDER.intSize) return(!catch("ShowOpenOrder(3)   invalid size of parameter los["+ ArrayRange(los, 0) +"]["+ ArrayRange(los, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));
      int losSize = ArrayRange(los, 0);
      if (index < 0 || index > losSize-1)          return(!catch("ShowOpenOrder(4)   invalid parameter index = "+ index, ERR_ARRAY_INDEX_OUT_OF_RANGE));
      CopyMemory(GetIntsAddress(los)+ index*LFX_ORDER.intSize*4, GetIntsAddress(lo), LFX_ORDER.intSize*4);
   }


   // (2) Order anzeigen
   string   comment    =                     lo.Comment      (lo);
   int      type       =                     lo.Type         (lo);
   double   units      =                     lo.Units        (lo);
   datetime openTime   = GMTToServerTime(Abs(lo.OpenTime     (lo)));
   double   openPrice  =                     lo.OpenPriceLfx (lo);
   bool     isSL       =                    (lo.StopLossLfx  (lo) != 0);
   bool     isTP       =                    (lo.TakeProfitLfx(lo) != 0);

   string label = StringConcatenate("LFX.OpenTicket.", comment, ".Line");
   string text  = StringConcatenate(" ", comment, ":  ", NumberToStr(units, ".+"), " x ", NumberToStr(openPrice, SubPipPriceFormat));
      if (isTP) text = StringConcatenate(text, ",  TP: ", NumberToStr(lo.TakeProfitLfx(lo), SubPipPriceFormat));
      if (isSL) text = StringConcatenate(text, ",  SL: ", NumberToStr(lo.StopLossLfx  (lo), SubPipPriceFormat));

   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, D'1970.01.01 00:01', openPrice, openTime, openPrice)) {
      ObjectSet(label, OBJPROP_RAY  , false);
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR, ifInt(IsLongTradeOperation(type), Green, Red));
      ObjectSet(label, OBJPROP_BACK , false);
      ObjectSetText(label, text);
   }
   else GetLastError();

   ArrayResize(lo, 0);
   return(!catch("ShowOpenOrder(5)"));
}
