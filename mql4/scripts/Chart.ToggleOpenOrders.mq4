/**
 * Blendet die aktuell offenen Positionen ein oder aus.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


string currency;                                                     // LFX-Währung


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (IsError(onInit(T_SCRIPT)))
      return(last_error);

   PriceFormat = "."+ PipDigits +"'";                                // immer Subpip-PriceFormat

   if (!StringContains(Symbol(), "LFX")) {
      PlaySound("notify.wav");
      MessageBox("Cannot display LFX positions:\n"+ GetSymbolName(Symbol()) +" is not a LFX instrument", __SCRIPT__ +" - init()", MB_ICONEXCLAMATION|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }

   if (StringStartsWith(Symbol(), "LFX")) currency = StringRight(Symbol(), -3);
   else                                   currency = StringLeft (Symbol(), -3);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // 1) aktuellen Status bestimmen: off/on und welcher Account
   string account = ReadAccountId();
   //debug("onStart()   last account = \""+ account +"\"");


   // 2) aktuell angezeigte Marker löschen
   if (account != "") {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "LFXPosition."))
            ObjectDelete(name);
      }
   }


   // 3) Abschnitt des nächsten anzuzeigenden Accounts bestimmen
   string file = TerminalPath() +"\\experts\\files\\"+ ShortAccountCompany() +"\\remote_positions.ini";
   string sections[];
   int sizeOfSections = GetPrivateProfileSectionNames(file, sections);
   //debug("onStart()   found "+ sizeOfSections +" sections = "+ StringArrayToStr(sections, NULL));

   int index = ArraySearchString(account, sections);
   int next  = index + 1;                                            // Zeiger auf nächsten Abschnitt setzen

   if (account!="") /*&&*/ if (index==-1)                            // Ist Status ON und der aktuelle Abschnitt existiert in der Konfiguration nicht,
      next = sizeOfSections;                                         // dann Zeiger auf eins hinter den letzten Abschnitt setzen.
   sizeOfSections = ArrayPushString(sections, "");                   // Leerstring (= Status OFF) als letzten 'Abschnitt' hinzufügen
   //debug("onStart()   next section=\""+ sections[next] +"\"   sections="+ StringArrayToStr(sections, NULL));

   // über verbleibende Abschnitte iterieren, nächsten Abschnitt mit mindestens einem Schlüssel des aktuellen Instruments finden und Positionen auslesen
   string prefix = StringConcatenate(currency, ".");
   string keys[], positions[];

   for (i=next; i < sizeOfSections; i++) {
      account = sections[i];
      if (account == "")
         break;
      ArrayResize(positions, 0);
      int sizeOfKeys = GetPrivateProfileKeys(file, account, keys);   // Anzahl der Einträge des Abschnitts

      for (int j=0; j < sizeOfKeys; j++) {
         if (StringIStartsWith(keys[j], prefix))
            ArrayPushString(positions, StringConcatenate(keys[j], "|", GetPrivateProfileString(file, account, keys[j], "")));
      }
      if (ArraySize(positions) > 0)
         break;
   }


   // 4) Positionsdaten parsen, validieren und Marker setzen
   int sizeOfPositions = ArraySize(positions);

   for (i=0; i < sizeOfPositions; i++) {
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
         catch("onStart(2)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      datetime openTime = StrToTime(value);
      if (openTime <= 0) {
         catch("onStart(3)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      openTime = GMTToServerTime(openTime);
      if (openTime > TimeCurrent()) {
         catch("onStart(4)   invalid open time in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OperationType
      value = StringToUpper(StringTrim(values[2]));
      if (StringLen(value) == 0) {
         catch("onStart(5)   invalid direction in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      int type;
      switch (StringGetChar(value, 0)) {
         case 'B':
         case 'L': type = OP_BUY;  break;
         case 'S': type = OP_SELL; break;
         default:
            catch("onStart(6)   invalid direction in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
            continue;
      }

      // Lots
      value = StringTrim(values[3]);
      if (StringLen(value) == 0) {
         catch("onStart(7)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("onStart(8)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double lots = StrToDouble(value);
      if (LE(lots, 0)) {
         catch("onStart(9)   invalid lot size in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OpenPrice
      value = StringTrim(values[4]);
      if (StringLen(value) == 0) {
         catch("onStart(10)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("onStart(11)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double openPrice = StrToDouble(value);
      if (LE(openPrice, 0)) {
         catch("onStart(12)   invalid open price in ["+ account +"] "+ values[0] +": \""+ GetPrivateProfileString(file, account, values[0], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // Marker setzen
      if (SetPositionMarker(label, openTime, type, lots, openPrice) != NO_ERROR)
         break;
   }


   // 5) aktuellen Status im Chart speichern
   SaveAccountId(account);

   return(catch("onStart(13)"));
}


/**
 * Speichert den Abschnittsnamen des aktuell angezeigten Accounts im Chart.
 *
 * @param  string id - Accountbezeichner (aktueller Abschnittsname der Konfigurationsdatei);
 *                     wenn Leerstring, wird ein gespeicherter Name gelöscht
 *
 * @return int - Fehlerstatus
 */
int SaveAccountId(string id) {
   string label = __SCRIPT__ +".account";

   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   if (id == "") {                                             // wenn id == "", wird das Label gelöscht
      ObjectDelete(label) ;
      return(catch("SaveAccount(1)"));
   }

   ObjectSet(label, OBJPROP_XDISTANCE, -1000);                 // Label in nicht sichtbaren Bereich setzen
   ObjectSetText(label, id, 0);

   return(catch("SaveAccount(2)"));
}


/**
 * Liest den im Chart gespeicherten Abschnittsnamen des aktuell angezeigten Accounts aus.
 *
 * @return string - Name
 */
string ReadAccountId() {
   string label = __SCRIPT__ +".account";
   if (ObjectFind(label) != -1)
      return(ObjectDescription(label));
   return("");
}


/**
 * Zeichnet für die angegebenen Daten einen Position-Marker in den Chart.
 *
 * @param string   label
 * @param datetime openTime
 * @param int      type
 * @param double   lots
 * @param double   openPrice
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
      ObjectSet(name, OBJPROP_BACK , true);                                                                                            // immer Subpips verwenden
      ObjectSetText(name, StringConcatenate(" ", label, ":  (", NumberToStr(lots, ".1+"), ")  ", NumberToStr(NormalizeDouble(openPrice, Digits|1), PriceFormat)));
   }
   else GetLastError();

   return(catch("SetPositionMarker()"));
}
