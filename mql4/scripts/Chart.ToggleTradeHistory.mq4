/**
 * Aktiviert/deaktiviert die Anzeige der geschlossenen LFX-Orders des aktuellen LFX-TradeAccounts.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>

#include <win32api.mqh>
#include <LFX/functions.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


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
      MessageBox("Cannot display LFX trades on a non LFX chart (\""+ Symbol() +"\")", __NAME__, MB_ICONSTOP|MB_OK);
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
      // Status ON: geschlossene Orders einlesen anzeigen
      /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
      int orders = LFX.GetOrders(lfxCurrency, OF_CLOSED, los);
      if (orders < 0)
         return(last_error);

      for (int i=0; i < orders; i++) {
         int      ticket     =                     los.Ticket       (los, i);
         int      type       =                     los.Type         (los, i);
         double   units      =                     los.Units        (los, i);
         datetime openTime   =     GMTToServerTime(los.OpenTime     (los, i));
         double   openPrice  =                     los.OpenPriceLfx (los, i);
         datetime closeTime  = GMTToServerTime(Abs(los.CloseTime    (los, i)));
         double   closePrice =                     los.ClosePriceLfx(los, i);
         double   profit     =                     los.Profit       (los, i);

         if (!SetClosedTradeMarker(ticket, type, units, openTime, openPrice, closeTime, closePrice, profit))
            break;
      }
      ArrayResize(los, 0);
   }
   else {
      // Status OFF: Chartobjekte geschlossener Orders löschen
      for (i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "#"))
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
 * @param  int      ticket
 * @param  int      type
 * @param  double   lots
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   profit
 *
 * @return bool - Erfolgsstatus
 */
bool SetClosedTradeMarker(int ticket, int type, double lots, datetime openTime, double openPrice, datetime closeTime, double closePrice, double profit) {
   color  markerColor = ifInt(type==OP_BUY, Blue, Red);
   string comment     = "Profit: "+ DoubleToStr(profit, 2);

   if (!ChartMarker.OrderSent_B(ticket, SubPipDigits, markerColor, type, lots, lfxCurrency, openTime, openPrice, NULL, NULL, comment))
      return(!SetLastError(stdlib.GetLastError()));

   if (!ChartMarker.PositionClosed_B(ticket, SubPipDigits, Orange, type, lots, lfxCurrency, openTime, openPrice, closeTime, closePrice))
      return(!SetLastError(stdlib.GetLastError()));
   return(true);
}
