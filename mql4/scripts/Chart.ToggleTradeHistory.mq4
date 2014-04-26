/**
 * Aktiviert/deaktiviert die Anzeige der geschlossenen LFX-Orders des aktuellen LFX-TradeAccounts.
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
      MessageBox("Cannot display LFX trades on a non LFX chart (\""+ Symbol() +"\")", __NAME__, MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   lfxCurrencyId     = GetCurrencyId(lfxCurrency);
   lfxChartDeviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);


   // (2) TradeAccount-Details ermitteln
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
   // (1) aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !LFX.ReadDisplayStatus();


   if (status) {
      // (2.1) Status ON: alle Tickets des Accounts einlesen
      string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
      string section = lfxAccountCompany +"."+ lfxAccount;
      string keys[];
      int keysSize = GetIniKeys(file, section, keys);

      // (2.2) geschlossene Orders finden und anzeigen
      string   symbol="", label="";
      int      ticket, orderType;
      double   units, openEquity, openPrice, stopLoss, takeProfit, closePrice, profit;
      datetime openTime, closeTime, lastUpdate;

      for (int i=0; i < keysSize; i++) {
         if (StringIsDigit(keys[i])) {
            ticket = StrToInteger(keys[i]);
            if (LFX.CurrencyId(ticket) == lfxCurrencyId) {
               int result = LFX.ReadTicket(ticket, symbol, label, orderType, units, openTime, openEquity, openPrice, stopLoss, takeProfit, closeTime, closePrice, profit, lastUpdate);
               if (result != 1)                                                        // +1, wenn das Ticket erfolgreich gelesen wurden
                  return(last_error);                                                  // -1, wenn das Ticket nicht gefunden wurde
               if (!closeTime)                                                         //  0, falls ein anderer Fehler auftrat
                  continue;            // keine geschlossene Order

               openTime    = GMTToServerTime(openTime);
               openPrice  += lfxChartDeviation;

               closeTime   = GMTToServerTime(closeTime);
               closePrice += lfxChartDeviation;

               if (!SetClosedTradeMarker(ticket, orderType, units, openTime, openPrice, closeTime, closePrice, profit))
                  break;
            }
         }
      }
   }
   else {
      // (3) Status OFF: alle existierenden Chartobjekte geschlossener Tickets löschen
      for (i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "#"))
            ObjectDelete(name);
      }
   }


   // (4) aktuellen Status im Chart speichern
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
      return(!SetLastError(stdlib_GetLastError()));

   if (!ChartMarker.PositionClosed_B(ticket, SubPipDigits, Orange, type, lots, lfxCurrency, openTime, openPrice, closeTime, closePrice))
      return(!SetLastError(stdlib_GetLastError()));
   return(true);
}
