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
      if (orders < 0)
         return(last_error);

      for (int i=0; i < orders; i++) {
         string   label     =                     los.Comment     (los, i);
         int      type      =                     los.Type        (los, i);
         double   units     =                     los.Units       (los, i);
         datetime openTime  = GMTToServerTime(Abs(los.OpenTime    (los, i)));
         double   openPrice =                     los.OpenPriceLfx(los, i);
         if (!SetOpenOrderMarker(label, type, units, openTime, openPrice))
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
 * Zeichnet für die angegebenen Daten einen Positions-Marker in den Chart.
 *
 * @param  string   label
 * @param  int      type
 * @param  double   units
 * @param  datetime openTime
 * @param  double   openPrice
 *
 * @return bool - Erfolgsstatus
 */
bool SetOpenOrderMarker(string label, int type, double units, datetime openTime, double openPrice) {
   string name = StringConcatenate("LFX.OpenTicket.", label, ".Line");
   if (ObjectFind(name) > -1)
      ObjectDelete(name);

   if (ObjectCreate(name, OBJ_TREND, 0, D'1970.01.01 00:01', openPrice, openTime, openPrice)) {
      ObjectSet(name, OBJPROP_RAY  , false);
      ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(name, OBJPROP_COLOR, ifInt(IsLongTradeOperation(type), Green, Red));
      ObjectSet(name, OBJPROP_BACK , false);
      ObjectSetText(name, StringConcatenate(" ", label, ":  ", NumberToStr(units, ".+"), " x ", NumberToStr(openPrice, SubPipPriceFormat)));
   }
   else GetLastError();

   return(!catch("SetOpenOrderMarker()"));
}
