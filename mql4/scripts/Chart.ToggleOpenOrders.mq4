/**
 * Blendet Markierungen für die aktuell offenen Positionen ein oder aus.
 * In LiteForex-Charts werden die im konfigurierten externen Account gehaltenen Positionen angezeigt.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string accountCompany = "FxPro";
string accountNumber  = "{account-no}";

string currency;                                                     // LFX-Währung


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) +0.1;                 // (int) double
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits +"'";                                // Subpip-PriceFormat

   if (!StringContains(Symbol(), "LFX")) {
      PlaySound("notify.wav");
      MessageBox("Cannot display LFX positions:\n"+ GetSymbolName(Symbol()) +" is not a LFX instrument", __SCRIPT__ +" - init()", MB_ICONEXCLAMATION|MB_OK);
      init_error = ERR_RUNTIME_ERROR;
      return(init_error);
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
int start() {
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);
   // ------------------------


   // (1) Chart nach vorhandenen Markierungen absuchen
   bool markerFound = false;

   for (int i=ObjectsTotal()-1; i >= 0; i--) {
      string name = ObjectName(i);
      if (StringStartsWith(name, "LFXPosition.")) {
         ObjectDelete(name);                                      // alle gefundenen Marker löschen...
         markerFound = true;
      }
   }
   int error = GetLastError();
   if (error == ERR_OBJECT_DOES_NOT_EXIST)
      error = NO_ERROR;

   if (markerFound || error!=NO_ERROR) {
      //debug("start()   chart marker found, positions deleted");
      return(catch("start(1)", error));                           // ...und Rückkehr
   }


   // keine Markierungen gefunden: Positionen anzeigen


   // (2) Einträge des aktuellen Instruments auslesen
   string file    = TerminalPath() +"\\experts\\files\\"+ ShortAccountCompany() +"\\external_positions.ini";
   string section = accountCompany +"."+ accountNumber;
   string keys[], positions[];
   ArrayResize(positions, 0);

   int sizeOfKeys = GetPrivateProfileKeys(file, section, keys);      // Anzahl der Einträge des Abschnitts
   string prefix  = StringConcatenate(currency, ".");

   for (i=0; i < sizeOfKeys; i++) {
      if (StringIStartsWith(keys[i], prefix))
         ArrayPushString(positions, StringConcatenate(keys[i], "|", GetPrivateProfileString(file, section, keys[i], "")));
   }


   // (3) Daten parsen und validieren
   int sizeOfPositions = ArraySize(positions);

   for (i=0; i < sizeOfPositions; i++) {
      string values[];
      if (Explode(positions[i], "|", values, NULL) != 5) {
         catch("start(2)   Invalid ["+ section +"] entry in \""+ file +"\": "+ positions[i], ERR_RUNTIME_ERROR);
         continue;
      }
      // Label
      string label = StringTrim(StringRight(values[0], -StringLen(prefix)));

      // OpenTime
      string value = StringTrim(values[1]);
      if (StringLen(value) == 0) {
         catch("start(3)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      datetime openTime = StrToTime(value);
      if (openTime <= 0) {
         catch("start(4)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      //openTime = GmtToServerTime(openTime);
      if (openTime > TimeCurrent()) {
         catch("start(5)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OperationType
      value = StringToUpper(StringTrim(values[2]));
      if (StringLen(value) == 0) {
         catch("start(6)   Invalid direction type in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      int type;
      switch (StringGetChar(value, 0)) {
         case 'B':
         case 'L': type = OP_BUY;  break;
         case 'S': type = OP_SELL; break;
         default:
            catch("start(7)   Invalid direction type in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
            continue;
      }

      // Lots
      value = StringTrim(values[3]);
      if (StringLen(value) == 0) {
         catch("start(8)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("start(9)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double lots = StrToDouble(value);
      if (LE(lots, 0)) {
         catch("start(10)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OpenPrice
      value = StringTrim(values[4]);
      if (StringLen(value) == 0) {
         catch("start(11)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("start(12)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double openPrice = StrToDouble(value);
      if (LE(openPrice, 0)) {
         catch("start(13)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }


      // (4) Positionen anzeigen
      if (SetPositionMarker(label, openTime, type, lots, openPrice) != NO_ERROR)
         break;
   }
   return(catch("start(14)"));
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
