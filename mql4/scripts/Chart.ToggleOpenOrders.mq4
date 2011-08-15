/**
 * Zeigt in LiteForex-Charts in anderen Accounts gehalte offene LFX-Positionen an.
 */
#include <stdlib.mqh>
#include <win32api.mqh>

//#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Account.Company = "Alpari";
extern string Account.Number  = "8188497";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string currency;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) + 0.1;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   if (!StringContains(Symbol(), "LFX")) {
      PlaySound("notify.wav");
      MessageBox("Cannot load LFX positions.\n("+ GetSymbolName(Symbol()) +" is not a LFX index)", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
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


   // (1) Einträge des aktuellen Instruments auslesen
   string file    = TerminalPath() +"\\experts\\files\\"+ GetShortAccountCompany() +"\\external_positions.ini";
   string section = Account.Company +"."+ Account.Number;
   string keys[], positions[];
   ArrayResize(positions, 0);

   int sizeOfKeys = GetPrivateProfileKeys(file, section, keys);      // Anzahl der Einträge des Abschnitts
   string prefix  = StringConcatenate(currency, ".");

   for (int i=0; i < sizeOfKeys; i++) {
      if (StringIStartsWith(keys[i], prefix))
         ArrayPushString(positions, StringConcatenate(keys[i], "|", GetPrivateProfileString(file, section, keys[i], "")));
   }


   // (2) Daten parsen und validieren
   int sizeOfPositions = ArraySize(positions);

   for (i=0; i < sizeOfPositions; i++) {
      string values[];
      if (Explode(positions[i], "|", values, NULL) != 5) {
         catch("start(1)   Invalid ["+ section +"] entry in \""+ file +"\": "+ positions[i], ERR_RUNTIME_ERROR);
         continue;
      }
      // Label
      string label = StringTrim(values[0]);

      // OpenTime
      string value = StringTrim(values[1]);
      if (StringLen(value) == 0) {
         catch("start(2)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      datetime openTime = StrToTime(value);
      if (openTime <= 0) {
         catch("start(3)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      openTime = GmtToServerTime(openTime);
      if (openTime > TimeCurrent()) {
         catch("start(4)   Invalid open time value in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OperationType
      value = StringToUpper(StringTrim(values[2]));
      if (StringLen(value) == 0) {
         catch("start(5)   Invalid direction type in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      int type;
      switch (StringGetChar(value, 0)) {
         case 'B': type = OP_BUY;  break;
         case 'S': type = OP_SELL; break;
         default:
            catch("start(6)   Invalid direction type in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
            continue;
      }

      // Lots
      value = StringTrim(values[3]);
      if (StringLen(value) == 0) {
         catch("start(7)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("start(8)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double lots = StrToDouble(value);
      if (LE(lots, 0)) {
         catch("start(9)   Invalid lot size in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }

      // OpenPrice
      value = StringTrim(values[4]);
      if (StringLen(value) == 0) {
         catch("start(10)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      if (!StringIsNumeric(value)) {
         catch("start(11)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }
      double openPrice = StrToDouble(value);
      if (LE(openPrice, 0)) {
         catch("start(12)   Invalid open price in ["+ section +"] "+ keys[i] +": \""+ GetPrivateProfileString(file, section, keys[i], "") +"\"", ERR_RUNTIME_ERROR);
         continue;
      }


      // (3) Positionen anzeigen
      if (SetPositionMarker(label, openTime, type, lots, openPrice) != NO_ERROR)
         break;
   }
   return(catch("start(13)"));
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
   string arrow = StringConcatenate(label, ": ", ifString(type==OP_BUY, "Buy", "Sell"), " ", NumberToStr(lots, ".+"), " lots at ", NumberToStr(openPrice, PriceFormat));

   if (ObjectFind(arrow) > -1)
      ObjectDelete(arrow);
   if (ObjectCreate(arrow, OBJ_ARROW, 0, openTime, openPrice)) {
      ObjectSet(arrow, OBJPROP_ARROWCODE, 1);
      ObjectSet(arrow, OBJPROP_COLOR, ifInt(type==OP_BUY, Blue, Red));
   }
   else GetLastError();

   return(catch("SetPositionMarker()"));
}
