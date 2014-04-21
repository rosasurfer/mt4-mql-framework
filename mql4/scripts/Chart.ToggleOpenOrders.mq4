/**
 * Blendet die in "remote_positions.ini" gespeicherten offenen LFX-Tickets des aktuellen Accounts ein/aus.
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

int    remoteAccount;                                                // aktueller Remote-Account
string remoteAccountCompany;                                         // Company des Remote-Accounts


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
      MessageBox("Cannot display LFX tickets:\n"+ Symbol() +" is not an LFX instrument", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   lfxCurrencyId     = GetCurrencyId(lfxCurrency);
   lfxChartDeviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);


   // (2) aktuellen Remote-Account und dessen AccountCompany ermitteln
   string section = "LFX";
   string key     = "MRURemoteAccount";
   remoteAccount  = GetLocalConfigInt(section, key, 0);
   if (remoteAccount <= 0) {
      PlaySound("notify.wav");
      string value = GetLocalConfigString(section, key, "");
      if (!StringLen(value)) MessageBox("Missing remote account setting ["+ section +"]->"+ key                      , __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      else                   MessageBox("Invalid remote account setting ["+ section +"]->"+ key +" = \""+ value +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   section = "AccountCompanies";
   key     = remoteAccount;
   remoteAccountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(remoteAccountCompany)) {
      PlaySound("notify.wav");
      MessageBox("Missing account company setting for remote account \""+ key +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
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
   // (1) aktuellen Anzeigestatus aus dem Chart auslesen (ON/OFF) und umschalten
   bool currentStatus = !ReadDisplayStatus();


   if (currentStatus) {
      // (2.1) Status ON: alle Tickets des Accounts einlesen
      string file    = TerminalPath() +"\\experts\\files\\"+ ShortAccountCompany() +"\\remote_positions.ini";
      string section = remoteAccountCompany +"."+ remoteAccount;
      string keys[];
      int keysSize = GetIniKeys(file, section, keys);

      // (2.2) offene LFX-Positionen finden und anzeigen
      string   label = "";
      int      ticket, orderType;
      double   units, openEquity, openPrice, stopLoss, takeProfit, closePrice, profit;
      datetime openTime, closeTime, lastUpdate;

      for (int i=0; i < keysSize; i++) {
         if (StringIsDigit(keys[i])) {
            ticket = StrToInteger(keys[i]);
            if (LFX.GetCurrencyId(ticket) == lfxCurrencyId) {
               int result = LFX.ReadRemotePosition(remoteAccount, ticket, label, orderType, units, openTime, openEquity, openPrice, stopLoss, takeProfit, closeTime, closePrice, profit, lastUpdate);
               if (result != 1)                                                        // +1, wenn die Ticketdaten erfolgreich gelesen wurden
                  return(last_error);                                                  // -1, wenn kein entsprechendes Ticket gefunden wurde
               if (StringIStartsWith(label, lfxCurrency +"."))                         //  0, Fehler
                  label = StringRight(label, -4);
               openPrice += lfxChartDeviation;

               if (!SetPositionMarker(label, openTime, orderType, units, openPrice))
                  break;
            }
         }
      }
   }
   else {
      // (3) Status OFF: alle existierenden Ticket-Chartobjekte löschen
      for (i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "LFX.Position."))
            ObjectDelete(name);
      }
   }


   // (4) aktuellen Status im Chart speichern
   SaveDisplayStatus(currentStatus);

   return(last_error);
}


/**
 * Liest den im Chart gespeicherten aktuellen Anzeigestatus aus.
 *
 * @return bool - Status: ON/OFF
 */
bool ReadDisplayStatus() {
   string label = __NAME__ +".status";
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Speichert den angegebenen Anzeigestatus im Chart.
 *
 * @param  bool status - Status
 *
 * @return int - Fehlerstatus
 */
int SaveDisplayStatus(bool status) {
   string label = __NAME__ +".status";

   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_XDISTANCE, -1000);                   // Label in unsichtbaren Bereich setzen
   ObjectSetText(label, ""+ status, 0);

   return(catch("SaveDisplayStatus()"));
}


/**
 * Zeichnet für die angegebenen Daten einen Position-Marker in den Chart.
 *
 * @param  string   label
 * @param  datetime openTime
 * @param  int      type
 * @param  double   lots
 * @param  double   openPrice
 *
 * @return bool - Erfolgsstatus
 */
int SetPositionMarker(string label, datetime openTime, int type, double lots, double openPrice) {
   string name = StringConcatenate("LFX.Position.", label, ".Line");
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

   return(!catch("SetPositionMarker()"));
}
