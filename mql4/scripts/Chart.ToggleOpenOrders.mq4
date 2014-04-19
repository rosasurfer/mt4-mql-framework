/**
 * Blendet die in "remote_positions.ini" eingetragenen offenen LFX-Positionen ein oder aus. Dabei wird nacheinander über alle Abschnitte der .ini-Datei
 * iteriert und jeweils die gefundenen Positionen eines Accounts angezeigt.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/script.mqh>
#include <lfx.mqh>

string currency;                                                     // LFX-Währung


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if      (StringStartsWith(Symbol(), "LFX")) currency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) currency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot display LFX positions:\n"+ Symbol() +" is not an LFX instrument", __NAME__ +"::init()", MB_ICONEXCLAMATION|MB_OK);
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
   // (1) aktuellen Status aus dem Chart auslesen: accountKey  = "" -> Status OFF (momentan keine Anzeige)
   string accountKey = ReadAccountKey();        // accountKey != "" -> Status ON  (momentan Anzeige des angegebenen Accounts)


   // (2) existierende Chart-Marker löschen
   if (accountKey != "") {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "LFXPosition."))
            ObjectDelete(name);
      }
   }


   // (3) .ini-Abschnitt des nächsten anzuzeigenden Accounts suchen
   string file = TerminalPath() +"\\experts\\files\\"+ ShortAccountCompany() +"\\remote_positions.ini";
   string sections[];
   int sectionsSize = GetIniSections(file, sections);

   int pos  = SearchStringArray(sections, accountKey);
   int next = pos + 1;                                               // Zeiger auf den jeweils nächsten Abschnitt setzen

   if (accountKey!="") /*&&*/ if (pos==-1)                           // Ist der AccountKey gesetzt (Status=ON), existiert in der .ini-Datei aber nicht (mehr),
      next = sectionsSize;                                           // Zeiger hinter den letzten Abschnitt setzen, um als nächstes Status=OFF zu aktivieren.
   sectionsSize = ArrayPushString(sections, "");                     // Leerstring (Status=OFF) als letzten Pseudo-Abschnitt hinzufügen


   // (4) nächsten Abschnitt mit aktuellen LFX-Positionen finden und Positionen auslesen
   string   keys[], values[], lastValue;
   int      keysSize, accountNumber, ticket, orderType;
   string   label = "";
   double   units, openEquity, openPrice, stopLoss, takeProfit, closePrice, profit;
   datetime openTime, closeTime, lastUpdate;
   bool     success;

   for (i=next; i < sectionsSize; i++) {
      if (sections[i] == "")
         break;
      Explode(sections[i], ".", values, NULL);
      lastValue = ArrayPopString(values);
      if (!StringIsDigit(lastValue))
         continue;
      accountNumber = StrToInteger(lastValue);
      if (!accountNumber)
         continue;

      success  = false;
      keysSize = GetIniKeys(file, sections[i], keys);

      for (int j=0; j < keysSize; j++) {
         if (StringIsDigit(keys[j])) {
            ticket = StrToInteger(keys[j]);
            if (LFX.GetCurrencyId(ticket) == GetCurrencyId(currency)) {
               int result = LFX.ReadRemotePosition(accountNumber, ticket, label, orderType, units, openTime, openEquity, openPrice, stopLoss, takeProfit, closeTime, closePrice, profit, lastUpdate);
               if (result != 1)                                                        // +1, wenn die Positionsdaten erfolgreich ermittelt wurden
                  return(last_error);                                                  // -1, wenn keine entsprechende Position gefunden wurde
               if (StringIStartsWith(label, currency +"."))                            //  0, Fehler
                  label = StringRight(label, -4);
               openPrice += GetGlobalConfigDouble("LfxChartDeviation", currency, 0);
               if (SetPositionMarker(label, openTime, orderType, units, openPrice) != NO_ERROR)
                  break;
               success = true;
            }
         }
      }
      if (success)
         break;
   }

   // 5) aktuellen AccountKey im Chart speichern
   SaveAccountKey(accountKey);

   return(last_error);
}


/**
 * Speichert den Schlüssel des aktuell angezeigten Accounts im Chart (Format wie Abschnittsname in "remote_positions.ini").
 *
 * @param  string key - Account-Schlüssel oder Leerstring, um den im Chart gespeicherten Schlüssel zu löschen
 *
 * @return int - Fehlerstatus
 */
int SaveAccountKey(string id) {
   string label = __NAME__ +".account";

   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   if (id == "") {                                                   // Leerstring: Label wieder löschen
      ObjectDelete(label) ;
   }
   else {
      ObjectSet(label, OBJPROP_XDISTANCE, -1000);                    // Label in nicht sichtbaren Bereich setzen
      ObjectSetText(label, id, 0);
   }
   return(catch("SaveAccountKey()"));
}


/**
 * Liest den im Chart gespeicherten Schlüssel des aktuell angezeigten Accounts aus.
 *
 * @return string - Account-Schlüssel
 */
string ReadAccountKey() {
   string label = __NAME__ +".account";
   if (ObjectFind(label) != -1)
      return(ObjectDescription(label));
   return("");
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
 * @return int - Fehlerstatus
 */
int SetPositionMarker(string label, datetime openTime, int type, double lots, double openPrice) {
   // Trendline
   string name = StringConcatenate("LFXPosition.", label, ".Line");
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

   return(catch("SetPositionMarker()"));
}
