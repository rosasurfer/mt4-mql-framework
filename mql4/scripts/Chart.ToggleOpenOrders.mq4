/**
 * Aktiviert/deaktiviert die Anzeige der in "remote_positions.ini" gespeicherten offenen LFX-Tickets des aktuellen Accounts.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/script.mqh>
#include <lfx.mqh>


string lfxCurrency;                                                  // aktuelle LFX-Währung
int    lfxCurrencyId;
double lfxChartDeviation;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) LFX-Currency, ID und Chartabweichung setzen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot display LFX orders on a non LFX chart (\""+ Symbol() +"\")", __NAME__, MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   lfxCurrencyId     = GetCurrencyId(lfxCurrency);
   lfxChartDeviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);


   // (2) Remoteaccount-Details ermitteln
   if (!LFX.CheckAccount())
      return(last_error);

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
      // Status ON: offene Orders einlesen und Orders der aktuellen Währung anzeigen
      /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
      int orders = LFX.GetOrders(los);

      for (int i=0; i < orders; i++) {
         if (los.CurrencyId(los, i) == lfxCurrencyId) {              // aktuelle Währung
            string   label     =                 los.Comment  (los, i);
            int      type      =                 los.Type     (los, i);
            double   units     =                 los.Units    (los, i);
            datetime openTime  = GMTToServerTime(los.OpenTime (los, i));
            double   openPrice =                 los.OpenPrice(los, i) + lfxChartDeviation;
            if (!SetOpenOrderMarker(label, type, units, openTime, openPrice))
               break;
         }
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

   return(last_error);
}


/**
 * Zeichnet für die angegebenen Daten einen Positions-Marker in den Chart.
 *
 * @param  string   label
 * @param  int      type
 * @param  double   lots
 * @param  datetime openTime
 * @param  double   openPrice
 *
 * @return bool - Erfolgsstatus
 */
bool SetOpenOrderMarker(string label, int type, double lots, datetime openTime, double openPrice) {
   string name = StringConcatenate("LFX.OpenTicket.", label, ".Line");
   if (ObjectFind(name) > -1)
      ObjectDelete(name);

   if (ObjectCreate(name, OBJ_TREND, 0, D'1970.01.01 00:01', openPrice, openTime, openPrice)) {
      ObjectSet(name, OBJPROP_RAY  , false);
      ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(name, OBJPROP_COLOR, ifInt(type==OP_BUY, Green, Red));
      ObjectSet(name, OBJPROP_BACK , false);
      ObjectSetText(name, StringConcatenate(" ", label, ":  ", NumberToStr(lots, ".+"), " x ", NumberToStr(NormalizeDouble(openPrice, SubPipDigits), SubPipPriceFormat)));
   }
   else GetLastError();

   return(!catch("SetOpenOrderMarker()"));
}
