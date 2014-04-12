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
   string account = ReadAccountKey();           // accountKey != "" -> Status ON  (momentan Anzeige des angegebenen Accounts)


   // (2) existierende Chart-Marker löschen
   if (account != "") {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "LFXPosition."))
            ObjectDelete(name);
      }
   }


   // (3) .ini-Abschnitt des nächsten anzuzeigenden Accounts suchen
   string file = TerminalPath() +"\\experts\\files\\"+ ShortAccountCompany() +"\\remote_positions.ini";
   string sections[];
   int sectionsSize = GetIniSectionNames(file, sections);

   int pos  = SearchStringArray(sections, account);
   int next = pos + 1;                                               // Zeiger auf den jeweils nächsten Abschnitt setzen

   if (account!="") /*&&*/ if (pos==-1)                              // Ist der AccountKey gesetzt (Status=ON), existiert in der .ini-Datei aber nicht (mehr),
      next = sectionsSize;                                           // Zeiger hinter den letzten Abschnitt setzen, um als nächstes Status=OFF zu aktivieren.
   sectionsSize = ArrayPushString(sections, "");                     // Leerstring (Status=OFF) als letzten Pseudo-Abschnitt hinzufügen

   // über verbleibende Abschnitte iterieren, nächsten Abschnitt mit Schlüssel der aktuellen LFX-Währung finden und Positionen auslesen
   string prefix = StringConcatenate(currency, ".");
   string keys[], positions[];

   for (i=next; i < sectionsSize; i++) {
      account = sections[i];
      if (account == "")
         break;
      ArrayResize(positions, 0);
      int keysSize = GetIniKeys(file, account, keys);

      for (int j=0; j < keysSize; j++) {
         if (StringIStartsWith(keys[j], prefix))
            ArrayPushString(positions, StringConcatenate(keys[j], "|", GetIniString(file, account, keys[j], "")));
      }
      if (ArraySize(positions) > 0)
         break;
   }


   // 4) Positionsdaten parsen, validieren und Chart-Marker setzen
   int positionsSize = ArraySize(positions);

   for (i=0; i < positionsSize; i++) {
      string values[];
      if (Explode(positions[i], "|", values, NULL) != 5) {
         catch("onStart(1)   invalid ["+ account +"] entry in \""+ file +"\": "+ positions[i], ERR_RUNTIME_ERROR);
         continue;
      }
      // Label
      string label = StringTrim(StringRight(values[0], -StringLen(prefix)));

      // OpenTime
      string value = StringTrim(values[1]);
      if (StringLen(value) == 0) {
         catch("onStart(2)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      if     (!StringIsDigit(value)) datetime openTime = StrToTime(value);
      else if (!StrToInteger(value))          openTime = 0;
      else {
         catch("onStart(3)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (openTime <= 0) {
         catch("onStart(3)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      openTime = GMTToServerTime(openTime);
      if (openTime > TimeCurrent()) {
         catch("onStart(4)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OperationType
      value = StringToUpper(StringTrim(values[2]));
      if (StringLen(value) == 0) {
         catch("onStart(5)   invalid direction in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      int type;
      switch (StringGetChar(value, 0)) {
         case 'B':
         case 'L': type = OP_BUY;  break;
         case 'S': type = OP_SELL; break;
         default:
            catch("onStart(6)   invalid direction in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
            continue;
      }

      // Lots
      value = StringTrim(values[3]);
      if (StringLen(value) == 0) {
         catch("onStart(7)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("onStart(8)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double lots = StrToDouble(value);
      if (LE(lots, 0)) {
         catch("onStart(9)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OpenPrice
      value = StringTrim(values[4]);
      if (StringLen(value) == 0) {
         catch("onStart(10)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("onStart(11)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double openPrice = StrToDouble(value);
      if (LE(openPrice, 0)) {
         catch("onStart(12)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetIniString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // Marker setzen
      if (SetPositionMarker(label, openTime, type, lots, openPrice) != NO_ERROR)
         break;
   }


   // 5) aktuellen Status im Chart speichern
   SaveAccountKey(account);

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
