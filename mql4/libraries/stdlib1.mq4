/**
 * stdlib.mq4
 *
 *
 * Datentypen und Speichergrößen in C, Win32-API (16-bit word size) und MQL:
 * =========================================================================
 *
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |        |                 |              max(hex) |            signed range(dec) |            unsigned range(dec) |       C        |        Win32        |      MQL       |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |  1 bit |                 |                  0x01 |                        0 - 1 |                            0-1 |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        | 1 byte |  8 bit | 2 nibbles       |                  0xFF |                   -128 - 127 |                          0-255 |                |      BYTE,CHAR      |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         | 1 word | 2 byte | 16 bit | HIBYTE + LOBYTE |                0xFFFF |             -32.768 - 32.767 |                       0-65.535 |     short      |   SHORT,WORD,WCHAR  |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         | 1 dword | 2 word | 4 byte | 32 bit | HIWORD + LOWORD |            0xFFFFFFFF |             -2.147.483.648 - |              0 - 4.294.967.295 | int,long,float | BOOL,INT,LONG,DWORD |  bool,char,int |
 * |         |         |        |        |        |                 |                       |              2.147.483.647   |                                |                |    WPARAM,LPARAM    | color,datetime |
 * |         |         |        |        |        |                 |                       |                              |                                |                | (handles, pointers) |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * | 1 qword | 2 dword | 4 word | 8 byte | 64 bit |                 | 0xFFFFFFFF 0xFFFFFFFF | -9.223.372.036.854.775.808 - | 0 - 18.446.744.073.709.551.616 |     double     |  LONGLONG,DWORDLONG |  double,string |
 * |         |         |        |        |        |                 |                       |  9.223.372.036.854.775.807   |                                |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 */
#property library


#include <stddefine.mqh>
#include <timezones.mqh>
#include <win32api.mqh>


/**
 * Initialisierung interner Variablen der Library zur Verbesserung des Debuggings.
 *
 * @param  string scriptName - Name des Scriptes, das die Library lädt
 */
void stdlib_init(string scriptName) {
   __SCRIPT__ = StringConcatenate(scriptName, "::", WindowExpertName());
}


/**
 * Informiert die Library über das Eintreffen eines neuen Ticks. Ermöglicht den Libraray-Funktionen zu erkennen, ob der Aufruf während desselben
 * oder eines neuen Ticks erfolgt (z.B. in EventListenern). Außerdem kann damit in der Library IndicatorCounted() emuliert werden.
 *
 * @param  int validBars - Anzahl der gültigen Bars *oder* Indikatorwerte (je nach Aufrufer)
 */
void stdlib_onTick(int validBars) {
   if (validBars < 0) {
      catch("stdlib_onTick()  invalid parameter validBars = "+ validBars, ERR_INVALID_FUNCTION_PARAMVALUE);
      return;
   }

   Tick++;                          // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   ValidBars   = validBars;
   ChangedBars = Bars - ValidBars;
}


/**
 * Gibt den letzten in dieser Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode zurück.
 *
 * @return int - Fehlercode
 */
int stdlib_GetLastError() {
   int error = last_error;
   last_error = NO_ERROR;
   return(error);
}


/**
 * Gibt den letzten in dieser Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode *nicht* zurück.
 *
 * @return int - Fehlercode
 */
int stdlib_PeekLastError() {
   return(last_error);
}


/**
 * Gibt den vollständigen Dateinamen der lokalen Konfigurationsdatei zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname
 */
string GetLocalConfigPath() {
   static string cache.localConfigPath[];             // timeframe-übergreifenden String-Cache einrichten (ohne Initializer) ...
   if (ArraySize(cache.localConfigPath) == 0) {
      ArrayResize(cache.localConfigPath, 1);
      cache.localConfigPath[0] = "";
   }
   else if (cache.localConfigPath[0] != "")           // ... und möglichst gecachten Wert zurückgeben
      return(cache.localConfigPath[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\metatrader-local-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetShortcutTarget(lnkFile);
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR) {
            catch("GetLocalConfigPath(1)   kernel32::_lcreat()   error creating \""+ iniFile +"\"", ERR_WINDOWS_ERROR);
            return("");
         }
         _lclose(hFile);
      }
   }

   cache.localConfigPath[0] = iniFile;                // Ergebnis cachen

   if (catch("GetLocalConfigPath(2)") != NO_ERROR)
      return("");
   return(iniFile);
}


/**
 * Gibt den vollständigen Dateinamen der globalen Konfigurationsdatei zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname
 */
string GetGlobalConfigPath() {
   static string cache.globalConfigPath[];            // timeframe-übergreifenden String-Cache einrichten (ohne Initializer) ...
   if (ArraySize(cache.globalConfigPath) == 0) {
      ArrayResize(cache.globalConfigPath, 1);
      cache.globalConfigPath[0] = "";
   }
   else if (cache.globalConfigPath[0] != "")          // ... und möglichst gecachten Wert zurückgeben
      return(cache.globalConfigPath[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetShortcutTarget(lnkFile);
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR) {
            catch("GetGlobalConfigPath(1)   kernel32::_lcreat()   error creating \""+ iniFile +"\"", ERR_WINDOWS_ERROR);
            return("");
         }
         _lclose(hFile);
      }
   }

   cache.globalConfigPath[0] = iniFile;               // Ergebnis cachen

   if (catch("GetGlobalConfigPath(2)") != NO_ERROR)
      return("");
   return(iniFile);
}


/**
 * Gibt die eindeutige ID einer Währung zurück.
 *
 * @param  string currency - 3-stelliger Währungsbezeichner
 *
 * @return int - Currency-ID
 */
int GetCurrencyId(string currency) {
   string curr = StringToUpper(currency);

   if (curr == C_AUD) return(CID_AUD);
   if (curr == C_CAD) return(CID_CAD);
   if (curr == C_CHF) return(CID_CHF);
   if (curr == C_CZK) return(CID_CZK);
   if (curr == C_DKK) return(CID_DKK);
   if (curr == C_EUR) return(CID_EUR);
   if (curr == C_GBP) return(CID_GBP);
   if (curr == C_HKD) return(CID_HKD);
   if (curr == C_HRK) return(CID_HRK);
   if (curr == C_HUF) return(CID_HUF);
   if (curr == C_JPY) return(CID_JPY);
   if (curr == C_LTL) return(CID_LTL);
   if (curr == C_LVL) return(CID_LVL);
   if (curr == C_MXN) return(CID_MXN);
   if (curr == C_NOK) return(CID_NOK);
   if (curr == C_NZD) return(CID_NZD);
   if (curr == C_PLN) return(CID_PLN);
   if (curr == C_RUB) return(CID_RUB);
   if (curr == C_SEK) return(CID_SEK);
   if (curr == C_SGD) return(CID_SGD);
   if (curr == C_TRY) return(CID_TRY);
   if (curr == C_USD) return(CID_USD);
   if (curr == C_ZAR) return(CID_ZAR);

   catch("GetCurrencyId()   unknown currency = \""+ currency +"\"", ERR_RUNTIME_ERROR);
   return(0);
}


/**
 * Gibt den 3-stelligen Bezeichner einer Währungs-ID zurück.
 *
 * @param  int id - Währungs-ID
 *
 * @return string - Währungsbezeichner
 */
string GetCurrency(int id) {
   switch (id) {
      case CID_AUD: return(C_AUD);
      case CID_CAD: return(C_CAD);
      case CID_CHF: return(C_CHF);
      case CID_CZK: return(C_CZK);
      case CID_DKK: return(C_DKK);
      case CID_EUR: return(C_EUR);
      case CID_GBP: return(C_GBP);
      case CID_HKD: return(C_HKD);
      case CID_HRK: return(C_HRK);
      case CID_HUF: return(C_HUF);
      case CID_JPY: return(C_JPY);
      case CID_LTL: return(C_LTL);
      case CID_LVL: return(C_LVL);
      case CID_MXN: return(C_MXN);
      case CID_NOK: return(C_NOK);
      case CID_NZD: return(C_NZD);
      case CID_PLN: return(C_PLN);
      case CID_RUB: return(C_RUB);
      case CID_SEK: return(C_SEK);
      case CID_SGD: return(C_SGD);
      case CID_TRY: return(C_TRY);
      case CID_USD: return(C_USD);
      case CID_ZAR: return(C_ZAR);
   }
   catch("GetCurrency()   unknown currency id = "+ id, ERR_RUNTIME_ERROR);
   return("");
}


/**
 * Aktiviert oder deaktiviert Expert Advisers (exakt: aktiviert/deaktiviert den Aufruf der Startfunktion bei Eintreffen von Ticks).
 *
 * @param  bool enable - gewünschter Status
 *
 * @return int - Fehlerstatus
 */
int ToggleEAs(bool enable) {

   // TODO: In EAs und Scripten SendMessage(), in Indikatoren PostMessage() verwenden (Erkennung des Scripttyps über Thread-ID)

   if (enable) {
      if (!IsExpertEnabled()) {
         SendMessageA(GetTerminalWindow(), WM_COMMAND, 33020, 0);
      }
   }
   else {
      if (IsExpertEnabled()) {
         SendMessageA(GetTerminalWindow(), WM_COMMAND, 33020, 0);
      }
   }

   return(catch("ToggleEAs()"));
}


/**
 * Erzeugt und positioniert ein neues Legendenlabel für den angegebenen Namen. Das erzeugte Label hat keinen Text.
 *
 * @param  string name - Indikatorname
 *
 * @return string - vollständiger Name des erzeugten Labels
 */
string CreateLegendLabel(string name) {
   int totalObj = ObjectsTotal(),
       labelObj = ObjectsTotal(OBJ_LABEL);

   string substrings[0], objName;
   int legendLabels, maxLegendId, maxYDistance=2;

   for (int i=0; i < totalObj && labelObj > 0; i++) {
      objName = ObjectName(i);
      if (ObjectType(objName) == OBJ_LABEL) {
         if (StringStartsWith(objName, "Legend.")) {
            legendLabels++;
            Explode(objName, ".", substrings);
            maxLegendId  = MathMax(maxLegendId, StrToInteger(substrings[1]));
            maxYDistance = MathMax(maxYDistance, ObjectGet(objName, OBJPROP_YDISTANCE));
         }
         labelObj--;
      }
   }

   string label = StringConcatenate("Legend.", maxLegendId+1, ".", name);
   if (ObjectFind(label) >= 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER,    CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE,               5);
      ObjectSet(label, OBJPROP_YDISTANCE, maxYDistance+19);
   }
   else GetLastError();
   ObjectSetText(label, " ");

   if (catch("CreateLegendLabel()") != NO_ERROR)
      return("");
   return(label);
}


/**
 * Positioniert die Legende neu (wird nach Entfernen eines Legendenlabels aufgerufen).
 *
 * @return int - Fehlerstatus
 */
int RepositionLegend() {
   int objects = ObjectsTotal(),
       labels  = ObjectsTotal(OBJ_LABEL);

   string legends[];       ArrayResize(legends,    0);   // Namen der gefundenen Label
   int    yDistances[][2]; ArrayResize(yDistances, 0);   // Y-Distance und legends[]-Index, um Label nach Position sortieren zu können

   int legendLabels;

   for (int i=0; i < objects && labels > 0; i++) {
      string objName = ObjectName(i);
      if (ObjectType(objName) == OBJ_LABEL) {
         if (StringStartsWith(objName, "Legend.")) {
            legendLabels++;
            ArrayResize(legends,    legendLabels);
            ArrayResize(yDistances, legendLabels);
            legends   [legendLabels-1]    = objName;
            yDistances[legendLabels-1][0] = ObjectGet(objName, OBJPROP_YDISTANCE);
            yDistances[legendLabels-1][1] = legendLabels-1;
         }
         labels--;
      }
   }

   if (legendLabels > 0) {
      ArraySort(yDistances);
      for (i=0; i < legendLabels; i++) {
         ObjectSet(legends[yDistances[i][1]], OBJPROP_YDISTANCE, 21 + i*19);
      }
   }
   return(catch("RepositionLegend()"));
}


/**
 * Ob ein Tradeserver-Error vorübergehend (temporär) ist oder nicht. Bei einem vorübergehenden Fehler *kann* der erneute Versuch,
 * die Order auszuführen, erfolgreich sein.
 *
 * @param  int error - Fehlercode
 *
 * @return bool
 *
 * @see IsPermanentTradeError()
 */
bool IsTemporaryTradeError(int error) {
   switch (error) {
      // temporary errors
      case ERR_COMMON_ERROR:                 //        2   common error (e.g. manual confirmation was denied)
      case ERR_SERVER_BUSY:                  //        4   trade server is busy
      case ERR_NO_CONNECTION:                //        6   no connection to trade server
      case ERR_TRADE_TIMEOUT:                //      128   trade timeout
      case ERR_INVALID_PRICE:                //      129   invalid price
      case ERR_INVALID_STOPS:                //      130   invalid stop
    //case ERR_MARKET_CLOSED:                //      132   market is closed
      case ERR_PRICE_CHANGED:                //      135   price changed
      case ERR_OFF_QUOTES:                   //      136   off quotes
      case ERR_BROKER_BUSY:                  //      137   broker is busy (never returned error)
      case ERR_REQUOTE:                      //      138   requote
      case ERR_TRADE_CONTEXT_BUSY:           //      146   trade context is busy
         return(true);

      // permanent errors
      case ERR_MARKET_CLOSED:                //      132   market is closed      // temporär ???

      case ERR_NO_RESULT:                    //        1   no result
      case ERR_INVALID_TRADE_PARAMETERS:     //        3   invalid trade parameters
      case ERR_OLD_VERSION:                  //        5   old version of client terminal
      case ERR_NOT_ENOUGH_RIGHTS:            //        7   not enough rights
      case ERR_TOO_FREQUENT_REQUESTS:        // ???    8   too frequent requests
      case ERR_MALFUNCTIONAL_TRADE:          //        9   malfunctional trade operation (never returned error)
      case ERR_ACCOUNT_DISABLED:             //       64   account disabled
      case ERR_INVALID_ACCOUNT:              //       65   invalid account
      case ERR_INVALID_TRADE_VOLUME:         //      131   invalid trade volume
      case ERR_TRADE_DISABLED:               //      133   trading is disabled
      case ERR_NOT_ENOUGH_MONEY:             //      134   not enough money
      case ERR_ORDER_LOCKED:                 //      139   order is locked
      case ERR_LONG_POSITIONS_ONLY_ALLOWED:  //      140   long positions only allowed
      case ERR_TOO_MANY_REQUESTS:            // ???  141   too many requests
      case ERR_TRADE_MODIFY_DENIED:          //      145   modification denied because too close to market
      case ERR_TRADE_EXPIRATION_DENIED:      //      147   expiration settings denied by broker
      case ERR_TRADE_TOO_MANY_ORDERS:        //      148   number of open and pending orders has reached the broker limit
      case ERR_TRADE_HEDGE_PROHIBITED:       //      149   hedging prohibited
      case ERR_TRADE_PROHIBITED_BY_FIFO:     //      150   prohibited by FIFO rules
         return(false);
   }
   return(false);
}


/**
 * Ob ein Tradeserver-Error permanent ist oder nicht. Bei einem permanenten Fehler wird auch der erneute Versuch,
 * die Order auszuführen, fehlschlagen.
 *
 * @param  int error - Fehlercode
 *
 * @return bool
 *
 * @see IsTemporaryTradeError()
 */
bool IsPermanentTradeError(int error) {
   return(!IsTemporaryTradeError(error));
}


/**
 * Vergrößert ein Double-Array und fügt ein weiteres Element an.
 *
 * @param  double& array[] - Double-Array
 * @param  double  value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayPushDouble(double& array[], double value) {
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Vergrößert ein Integer-Array und fügt ein weiteres Element an.
 *
 * @param  int& array[] - Integer-Array
 * @param  int  value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayPushInt(int& array[], int value) {
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Vergrößert ein String-Array und fügt ein weiteres Element an.
 *
 * @param  string& array[] - String-Array
 * @param  string  value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayPushString(string& array[], string value) {
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Double-Arrays umgekehrt ist oder nicht.
 *
 * @param  double& array[] - Double-Array
 *
 * @return bool
 */
bool IsReverseIndexedDoubleArray(double& array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Integer-Arrays umgekehrt ist oder nicht.
 *
 * @param  int& array[] - Integer-Array
 *
 * @return bool
 */
bool IsReverseIndexedIntArray(int& array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen String-Arrays umgekehrt ist oder nicht.
 *
 * @param  string& array[] - String-Array
 *
 * @return bool
 */
bool IsReverseIndexedStringArray(string& array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Double-Arrays um.
 *
 * @param  double& array[] - Double-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedDoubleArray()
 */
bool ReverseDoubleArray(double& array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Integer-Arrays um.
 *
 * @param  int& array[] - Integer-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedIntArray()
 */
bool ReverseIntArray(int& array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Kehrt die Reihenfolge der Elemente eines String-Arrays um.
 *
 * @param  string& array[] - String-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedStringArray()
 */
bool ReverseStringArray(string& array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Win32 structure WIN32_FIND_DATA
 *
 * typedef struct _WIN32_FIND_DATA {
 *    DWORD    dwFileAttributes;          //   4     => wfd[ 0]
 *    FILETIME ftCreationTime;            //   8     => wfd[ 1]
 *    FILETIME ftLastAccessTime;          //   8     => wfd[ 3]
 *    FILETIME ftLastWriteTime;           //   8     => wfd[ 5]
 *    DWORD    nFileSizeHigh;             //   4     => wfd[ 7]
 *    DWORD    nFileSizeLow;              //   4     => wfd[ 8]
 *    DWORD    dwReserved0;               //   4     => wfd[ 9]
 *    DWORD    dwReserved1;               //   4     => wfd[10]
 *    TCHAR    cFileName[MAX_PATH];       // 260     => wfd[11]      A: 260 * 1 byte      W: 260 * 2 byte
 *    TCHAR    cAlternateFileName[14];    //  14     => wfd[76]      A:  14 * 1 byte      W:  14 * 2 byte
 * } WIN32_FIND_DATA, wfd;                // 318 byte = int[80]      2 byte Überhang
 *
 * StructToHexStr(WIN32_FIND_DATA) = 20000000
 *                                   C0235A72 81BDC801
 *                                   00F0D85B C9CBCB01
 *                                   00884084 D32BC101
 *                                   00000000 D2430000 05000000 3FE1807C
 *
 *                                   52686F64 6F64656E 64726F6E 2E626D70 00000000 00000000 00000000 00000000 00000000 00000000
 *                                    R h o d  o d e n  d r o n  . b m p
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000
 *
 *                                   52484F44 4F447E31 2E424D50 00000000
 *                                    R H O D  O D ~ 1  . B M P
 */
int    wfd.FileAttributes            (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0]); }
bool   wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_READONLY      == FILE_ATTRIBUTE_READONLY     ); }
bool   wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_HIDDEN        == FILE_ATTRIBUTE_HIDDEN       ); }
bool   wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SYSTEM        == FILE_ATTRIBUTE_SYSTEM       ); }
bool   wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DIRECTORY     == FILE_ATTRIBUTE_DIRECTORY    ); }
bool   wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ARCHIVE       == FILE_ATTRIBUTE_ARCHIVE      ); }
bool   wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DEVICE        == FILE_ATTRIBUTE_DEVICE       ); }
bool   wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NORMAL        == FILE_ATTRIBUTE_NORMAL       ); }
bool   wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_TEMPORARY     == FILE_ATTRIBUTE_TEMPORARY    ); }
bool   wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SPARSE_FILE   == FILE_ATTRIBUTE_SPARSE_FILE  ); }
bool   wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT); }
bool   wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_COMPRESSED    == FILE_ATTRIBUTE_COMPRESSED   ); }
bool   wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_OFFLINE       == FILE_ATTRIBUTE_OFFLINE      ); }
bool   wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NOT_INDEXED   == FILE_ATTRIBUTE_NOT_INDEXED  ); }
bool   wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ENCRYPTED     == FILE_ATTRIBUTE_ENCRYPTED    ); }
bool   wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_VIRTUAL       == FILE_ATTRIBUTE_VIRTUAL      ); }
string wfd.FileName                  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(StructCharToStr(wfd, 11, 65)); }
string wfd.AlternateFileName         (/*WIN32_FIND_DATA*/ int& wfd[]) { return(StructCharToStr(wfd, 76,  4)); }


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int& wdf[] - WIN32_FIND_DATA structure
 *
 * @return string
 */
string wdf.FileAttributesToStr(/*WIN32_FIND_DATA*/ int& wdf[]) {
   string result = "";
   int flags = wfd.FileAttributes(wdf);

   if (flags & FILE_ATTRIBUTE_READONLY      == FILE_ATTRIBUTE_READONLY     ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_READONLY"     );
   if (flags & FILE_ATTRIBUTE_HIDDEN        == FILE_ATTRIBUTE_HIDDEN       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_HIDDEN"       );
   if (flags & FILE_ATTRIBUTE_SYSTEM        == FILE_ATTRIBUTE_SYSTEM       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_SYSTEM"       );
   if (flags & FILE_ATTRIBUTE_DIRECTORY     == FILE_ATTRIBUTE_DIRECTORY    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_DIRECTORY"    );
   if (flags & FILE_ATTRIBUTE_ARCHIVE       == FILE_ATTRIBUTE_ARCHIVE      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_ARCHIVE"      );
   if (flags & FILE_ATTRIBUTE_DEVICE        == FILE_ATTRIBUTE_DEVICE       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_DEVICE"       );
   if (flags & FILE_ATTRIBUTE_NORMAL        == FILE_ATTRIBUTE_NORMAL       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_NORMAL"       );
   if (flags & FILE_ATTRIBUTE_TEMPORARY     == FILE_ATTRIBUTE_TEMPORARY    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_TEMPORARY"    );
   if (flags & FILE_ATTRIBUTE_SPARSE_FILE   == FILE_ATTRIBUTE_SPARSE_FILE  ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_SPARSE_FILE"  );
   if (flags & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT) result = StringConcatenate(result, " | FILE_ATTRIBUTE_REPARSE_POINT");
   if (flags & FILE_ATTRIBUTE_COMPRESSED    == FILE_ATTRIBUTE_COMPRESSED   ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_COMPRESSED"   );
   if (flags & FILE_ATTRIBUTE_OFFLINE       == FILE_ATTRIBUTE_OFFLINE      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_OFFLINE"      );
   if (flags & FILE_ATTRIBUTE_NOT_INDEXED   == FILE_ATTRIBUTE_NOT_INDEXED  ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_NOT_INDEXED"  );
   if (flags & FILE_ATTRIBUTE_ENCRYPTED     == FILE_ATTRIBUTE_ENCRYPTED    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_ENCRYPTED"    );
   if (flags & FILE_ATTRIBUTE_VIRTUAL       == FILE_ATTRIBUTE_VIRTUAL      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_VIRTUAL"      );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Win32 structure FILETIME
 *
 * typedef struct _FILETIME {
 *    DWORD dwLowDateTime;
 *    DWORD dwHighDateTime;
 * } FILETIME, ft;
 *
 * StructToHexStr(FILETIME) =
 */


/**
 * Win32 structure PROCESS_INFORMATION
 *
 * typedef struct _PROCESS_INFORMATION {
 *    HANDLE hProcess;
 *    HANDLE hThread;
 *    DWORD  dwProcessId;
 *    DWORD  dwThreadId;
 * } PROCESS_INFORMATION, pi;       // = 16 byte = int[4]
 *
 * StructToHexStr(PROCESS_INFORMATION) = 68020000 74020000 D40E0000 B80E0000
 */
int pi.hProcess (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[0]); }
int pi.hThread  (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[1]); }
int pi.ProcessId(/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[2]); }
int pi.ThreadId (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[3]); }


/**
 * Win32 structure SECURITY_ATTRIBUTES
 *
 * typedef struct _SECURITY_ATTRIBUTES {
 *    DWORD  nLength;
 *    LPVOID lpSecurityDescriptor;
 *    BOOL   bInheritHandle;
 * } SECURITY_ATTRIBUTES, sa;       // = 12 byte = int[3]
 *
 * StructToHexStr(SECURITY_ATTRIBUTES) = 0C000000 00000000 00000000
 */
int  sa.Length            (/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[0]); }
int  sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[1]); }
bool sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[2] != 0); }


/**
 * Win32 structure STARTUPINFO
 *
 * typedef struct _STARTUPINFO {
 *    DWORD  cb;                        =>  si[ 0]
 *    LPTSTR lpReserved;                =>  si[ 1]
 *    LPTSTR lpDesktop;                 =>  si[ 2]
 *    LPTSTR lpTitle;                   =>  si[ 3]
 *    DWORD  dwX;                       =>  si[ 4]
 *    DWORD  dwY;                       =>  si[ 5]
 *    DWORD  dwXSize;                   =>  si[ 6]
 *    DWORD  dwYSize;                   =>  si[ 7]
 *    DWORD  dwXCountChars;             =>  si[ 8]
 *    DWORD  dwYCountChars;             =>  si[ 9]
 *    DWORD  dwFillAttribute;           =>  si[10]
 *    DWORD  dwFlags;                   =>  si[11]
 *    WORD   wShowWindow;               =>  si[12]
 *    WORD   cbReserved2;               =>  si[12]
 *    LPBYTE lpReserved2;               =>  si[13]
 *    HANDLE hStdInput;                 =>  si[14]
 *    HANDLE hStdOutput;                =>  si[15]
 *    HANDLE hStdError;                 =>  si[16]
 * } STARTUPINFO, si;       // = 68 byte = int[17]
 *
 * StructToHexStr(STARTUPINFO) = 44000000 103E1500 703E1500 D83D1500 00000000 00000000 00000000 00000000 00000000 00000000 00000000 010E0000 03000000 00000000 41060000 01000100 00000000
 */
int si.cb            (/*STARTUPINFO*/ int& si[]) { return(si[ 0]); }
int si.Desktop       (/*STARTUPINFO*/ int& si[]) { return(si[ 2]); }
int si.Title         (/*STARTUPINFO*/ int& si[]) { return(si[ 3]); }
int si.X             (/*STARTUPINFO*/ int& si[]) { return(si[ 4]); }
int si.Y             (/*STARTUPINFO*/ int& si[]) { return(si[ 5]); }
int si.XSize         (/*STARTUPINFO*/ int& si[]) { return(si[ 6]); }
int si.YSize         (/*STARTUPINFO*/ int& si[]) { return(si[ 7]); }
int si.XCountChars   (/*STARTUPINFO*/ int& si[]) { return(si[ 8]); }
int si.YCountChars   (/*STARTUPINFO*/ int& si[]) { return(si[ 9]); }
int si.FillAttribute (/*STARTUPINFO*/ int& si[]) { return(si[10]); }
int si.Flags         (/*STARTUPINFO*/ int& si[]) { return(si[11]); }
int si.ShowWindow    (/*STARTUPINFO*/ int& si[]) { return(si[12] & 0xFFFF); }
int si.hStdInput     (/*STARTUPINFO*/ int& si[]) { return(si[14]); }
int si.hStdOutput    (/*STARTUPINFO*/ int& si[]) { return(si[15]); }
int si.hStdError     (/*STARTUPINFO*/ int& si[]) { return(si[16]); }

int si.setCb         (/*STARTUPINFO*/ int& si[], int size   ) { si[ 0] =  size; }
int si.setFlags      (/*STARTUPINFO*/ int& si[], int flags  ) { si[11] = flags; }
int si.setShowWindow (/*STARTUPINFO*/ int& si[], int cmdShow) { si[12] = (si[12] & 0xFFFF0000) + (cmdShow & 0xFFFF); }


/**
 * Gibt die lesbare Version eines STARTUPINFO-Flags zurück.
 *
 * @param  int& si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.FlagsToStr(/*STARTUPINFO*/ int& si[]) {
   string result = "";
   int flags = si.Flags(si);

   if (flags & STARTF_FORCEONFEEDBACK  == STARTF_FORCEONFEEDBACK ) result = StringConcatenate(result, " | STARTF_FORCEONFEEDBACK" );
   if (flags & STARTF_FORCEOFFFEEDBACK == STARTF_FORCEOFFFEEDBACK) result = StringConcatenate(result, " | STARTF_FORCEOFFFEEDBACK");
   if (flags & STARTF_PREVENTPINNING   == STARTF_PREVENTPINNING  ) result = StringConcatenate(result, " | STARTF_PREVENTPINNING"  );
   if (flags & STARTF_RUNFULLSCREEN    == STARTF_RUNFULLSCREEN   ) result = StringConcatenate(result, " | STARTF_RUNFULLSCREEN"   );
   if (flags & STARTF_TITLEISAPPID     == STARTF_TITLEISAPPID    ) result = StringConcatenate(result, " | STARTF_TITLEISAPPID"    );
   if (flags & STARTF_TITLEISLINKNAME  == STARTF_TITLEISLINKNAME ) result = StringConcatenate(result, " | STARTF_TITLEISLINKNAME" );
   if (flags & STARTF_USECOUNTCHARS    == STARTF_USECOUNTCHARS   ) result = StringConcatenate(result, " | STARTF_USECOUNTCHARS"   );
   if (flags & STARTF_USEFILLATTRIBUTE == STARTF_USEFILLATTRIBUTE) result = StringConcatenate(result, " | STARTF_USEFILLATTRIBUTE");
   if (flags & STARTF_USEHOTKEY        == STARTF_USEHOTKEY       ) result = StringConcatenate(result, " | STARTF_USEHOTKEY"       );
   if (flags & STARTF_USEPOSITION      == STARTF_USEPOSITION     ) result = StringConcatenate(result, " | STARTF_USEPOSITION"     );
   if (flags & STARTF_USESHOWWINDOW    == STARTF_USESHOWWINDOW   ) result = StringConcatenate(result, " | STARTF_USESHOWWINDOW"   );
   if (flags & STARTF_USESIZE          == STARTF_USESIZE         ) result = StringConcatenate(result, " | STARTF_USESIZE"         );
   if (flags & STARTF_USESTDHANDLES    == STARTF_USESTDHANDLES   ) result = StringConcatenate(result, " | STARTF_USESTDHANDLES"   );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Gibt die lesbare Konstante einer STARTUPINFO ShowWindow command ID zurück.
 *
 * @param  int& si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.ShowWindowToStr(/*STARTUPINFO*/ int& si[]) {
   switch (si.ShowWindow(si)) {
      case SW_HIDE           : return("SW_HIDE"           );
      case SW_SHOWNORMAL     : return("SW_SHOWNORMAL"     );
      case SW_SHOWMINIMIZED  : return("SW_SHOWMINIMIZED"  );
      case SW_SHOWMAXIMIZED  : return("SW_SHOWMAXIMIZED"  );
      case SW_SHOWNOACTIVATE : return("SW_SHOWNOACTIVATE" );
      case SW_SHOW           : return("SW_SHOW"           );
      case SW_MINIMIZE       : return("SW_MINIMIZE"       );
      case SW_SHOWMINNOACTIVE: return("SW_SHOWMINNOACTIVE");
      case SW_SHOWNA         : return("SW_SHOWNA"         );
      case SW_RESTORE        : return("SW_RESTORE"        );
      case SW_SHOWDEFAULT    : return("SW_SHOWDEFAULT"    );
      case SW_FORCEMINIMIZE  : return("SW_FORCEMINIMIZE"  );
   }
   return("");
}


/**
 * Win32 structure SYSTEMTIME
 *
 * typedef struct _SYSTEMTIME {
 *    WORD wYear;
 *    WORD wMonth;
 *    WORD wDayOfWeek;
 *    WORD wDay;
 *    WORD wHour;
 *    WORD wMinute;
 *    WORD wSecond;
 *    WORD wMilliseconds;
 * } SYSTEMTIME, st;       // = 16 byte = int[4]
 *
 * StructToHexStr(SYSTEMTIME) = DB070100 06000F00 12003600 05000A03
 */
int st.Year     (/*SYSTEMTIME*/ int& st[]) { return(st[0] &  0x0000FFFF); }
int st.Month    (/*SYSTEMTIME*/ int& st[]) { return(st[0] >> 16        ); }
int st.DayOfWeek(/*SYSTEMTIME*/ int& st[]) { return(st[1] &  0x0000FFFF); }
int st.Day      (/*SYSTEMTIME*/ int& st[]) { return(st[1] >> 16        ); }
int st.Hour     (/*SYSTEMTIME*/ int& st[]) { return(st[2] &  0x0000FFFF); }
int st.Minute   (/*SYSTEMTIME*/ int& st[]) { return(st[2] >> 16        ); }
int st.Second   (/*SYSTEMTIME*/ int& st[]) { return(st[3] &  0x0000FFFF); }
int st.MilliSec (/*SYSTEMTIME*/ int& st[]) { return(st[3] >> 16        ); }


/**
 * Win32 structure TIME_ZONE_INFORMATION
 *
 * typedef struct _TIME_ZONE_INFORMATION {
 *    LONG       Bias;                //     4     => tzi[ 0]     Formeln:               GMT = UTC
 *    WCHAR      StandardName[32];    //    64     => tzi[ 1]     --------              Bias = -Offset
 *    SYSTEMTIME StandardDate;        //    16     => tzi[17]               LocalTime + Bias = GMT        (LocalTime -> GMT)
 *    LONG       StandardBias;        //     4     => tzi[21]                   GMT + Offset = LocalTime  (GMT -> LocalTime)
 *    WCHAR      DaylightName[32];    //    64     => tzi[22]
 *    SYSTEMTIME DaylightDate;        //    16     => tzi[38]
 *    LONG       DaylightBias;        //     4     => tzi[42]
 * } TIME_ZONE_INFORMATION, tzi;      // = 172 byte = int[43]
 *
 * StructToHexStr(TIME_ZONE_INFORMATION) = 88FFFFFF
 *                                         47005400 42002000 4E006F00 72006D00 61006C00 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    N   o    r   m    a   l    z   e    i   t
 *                                         00000A00 00000500 04000000 00000000
 *                                         00000000
 *                                         47005400 42002000 53006F00 6D006D00 65007200 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    S   o    m   m    e   r    z   e    i   t
 *                                         00000300 00000500 03000000 00000000
 *                                         C4FFFFFF
 */
int    tzi.Bias        (/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[0]); }                               // Bias in Minuten
string tzi.StandardName(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(StructWCharToStr(tzi, 1, 16)); }
void   tzi.StandardDate(/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]) { ArrayCopy(st, tzi, 0, 17, 4); }
int    tzi.StandardBias(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[21]); }                              // Bias in Minuten
string tzi.DaylightName(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(StructWCharToStr(tzi, 22, 16)); }
void   tzi.DaylightDate(/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]) { ArrayCopy(st, tzi, 0, 38, 4); }
int    tzi.DaylightBias(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[42]); }                              // Bias in Minuten


/**
 * Gibt den Inhalt einer Structure als hexadezimalen String zurück.
 *
 * @param  int& lpStruct[]
 *
 * @return string
 */
string StructToHexStr(int& lpStruct[]) {
   string result = "";
   int size = ArraySize(lpStruct);

   // Structs werden in MQL mit Hilfe von Integer-Arrays nachgebildet. Integers sind interpretierte binäre Werte (Reihenfolge von HIBYTE, LOBYTE, HIWORD, LOWORD).
   // Diese Interpretation muß wieder rückgängig gemacht werden.
   for (int i=0; i < size; i++) {
      string hex   = IntToHexStr(lpStruct[i]);
      string byte1 = StringSubstr(hex, 6, 2);
      string byte2 = StringSubstr(hex, 4, 2);
      string byte3 = StringSubstr(hex, 2, 2);
      string byte4 = StringSubstr(hex, 0, 2);
      result = StringConcatenate(result, " ", byte1, byte2, byte3, byte4);
   }

   if (size > 0)
      result = StringSubstr(result, 1);

   if (catch("StructToHexStr()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den Inhalt einer Structure als lesbaren String zurück. Nicht darstellbare Zeichen werden als Punkt "." dargestellt.
 * Nützlich, um im Struct enthaltene Strings schnell identifizieren zu können.
 *
 * @param  int& lpStruct[]
 *
 * @return string
 */
string StructToStr(int& lpStruct[]) {
   string result = "";
   int size = ArraySize(lpStruct);

   for (int i=0; i < size; i++) {
      string strInt = "0000";
      int value, shift=24, integer=lpStruct[i];

      // Structs werden in MQL mit Hilfe von Integer-Arrays nachgebildet. Integers sind interpretierte binäre Werte (Reihenfolge von HIBYTE, LOBYTE, HIWORD, LOWORD).
      // Diese Interpretation muß wieder rückgängig gemacht werden.
      for (int n=0; n < 4; n++) {
         value = (integer >> shift) & 0xFF;                                // Integer in Bytes zerlegen
         if (value < 0x20) strInt = StringSetChar(strInt, 3-n, '.');
         else              strInt = StringSetChar(strInt, 3-n, value);     // jedes Byte an der richtigen Stelle darstellen
         shift -= 8;
      }
      result = StringConcatenate(result, strInt);
   }

   if (catch("StructToStr()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den in einer Structure im angegebenen Bereich gespeicherten und mit einem NULL-Character terminierten ANSI-String zurück.
 *
 * @param  int& lpStruct[] - Structure
 * @param  int  from       - Index des ersten Integers der Charactersequenz
 * @param  int  len        - Anzahl der Integers des im Struct für die Charactersequenz reservierten Bereiches
 *
 * @return string
 *
 *
 * NOTE: Zur Zeit arbeitet diese Funktion nur mit Charactersequenzen, die an Integer-Boundaries beginnen und enden.
 * ----
 */
string StructCharToStr(int& lpStruct[], int from, int len) {
   if (from < 0)
      return(catch("StructCharToStr(1)  invalid parameter from = "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   int to = from+len, size=ArraySize(lpStruct);
   if (to > size)
      return(catch("StructCharToStr(2)  invalid parameter len = "+ len, ERR_INVALID_FUNCTION_PARAMVALUE));

   string result = "";

   for (int i=from; i < to; i++) {
      int byte, shift=0, integer=lpStruct[i];

      for (int n=0; n < 4; n++) {
         byte = (integer >> shift) & 0xFF;
         if (byte == 0)                                        // termination character (0x00)
            break;
         result = StringConcatenate(result, CharToStr(byte));
         shift += 8;
      }
      if (byte == 0)
         break;
   }

   if (catch("StructCharToStr(3)") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den in einer Structure im angegebenen Bereich gespeicherten mit einem NULL-Character terminierten WCHAR-String zurück (Multibyte-Characters).
 *
 * @param  int& lpStruct[] - Structure
 * @param  int  from       - Index des ersten Integers der Charactersequenz
 * @param  int  len        - Anzahl der Integers des im Struct für die Charactersequenz reservierten Bereiches
 *
 * @return string
 *
 *
 * NOTE: Zur Zeit arbeitet diese Funktion nur mit Charactersequenzen, die an Integer-Boundaries beginnen und enden.
 * ----
 */
string StructWCharToStr(int& lpStruct[], int from, int len) {
   if (from < 0)
      return(catch("StructWCharToStr(1)  invalid parameter from = "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   int to = from+len, size=ArraySize(lpStruct);
   if (to > size)
      return(catch("StructWCharToStr(2)  invalid parameter len = "+ len, ERR_INVALID_FUNCTION_PARAMVALUE));

   string result = "";

   for (int i=from; i < to; i++) {
      string strChar;
      int word, shift=0, integer=lpStruct[i];

      for (int n=0; n < 2; n++) {
         word = (integer >> shift) & 0xFFFF;
         if (word == 0)                                        // termination character (0x00)
            break;
         int byte1 = (word >> 0) & 0xFF;
         int byte2 = (word >> 8) & 0xFF;

         if (byte1!=0 && byte2==0) strChar = CharToStr(byte1);
         else                      strChar = "?";              // multi-byte character
         result = StringConcatenate(result, strChar);
         shift += 16;
      }
      if (word == 0)
         break;
   }

   if (catch("StructWCharToStr(3)") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Konvertiert einen String-Buffer in ein String-Array.
 *
 * @param  int&    buffer[]  - Buffer mit durch NULL-Zeichen getrennten Strings, terminiert durch ein weiteres NULL-Zeichen
 * @param  string& results[] - Ergebnisarray
 *
 * @return int - Anzahl der konvertierten Strings
 */
int StringBufferToArray(int& buffer[], string& results[]) {
   int  bufferSize = ArraySize(buffer);
   bool separator  = true;

   ArrayResize(results, 0);
   int resultSize = 0;

   for (int i=0; i < bufferSize; i++) {
      int value, shift=0, integer=buffer[i];

      // Die Reihenfolge von HIBYTE, LOBYTE, HIWORD und LOWORD eines Integers muß in die eines Strings konvertiert werden.
      for (int n=0; n < 4; n++) {
         value = (integer >> shift) & 0xFF;           // Integer in Bytes zerlegen

         if (value != 0x00) {                         // kein Trennzeichen, Character in Array ablegen
            if (separator) {
               resultSize++;
               ArrayResize(results, resultSize);
               results[resultSize-1] = "";
               separator = false;
            }
            results[resultSize-1] = StringConcatenate(results[resultSize-1], CharToStr(value));
         }
         else {                                       // Trennzeichen
            if (separator) {                          // 2 Trennzeichen = Separator + Terminator, beide Schleifen verlassen
               i = bufferSize;
               break;
            }
            separator = true;
         }
         shift += 8;
      }
   }

   if (catch("StringBufferToArray()") != NO_ERROR)
      return(0);
   return(ArraySize(results));
}


/**
 * Ermittelt den vollständigen Dateipfad der Zieldatei, auf die ein Windows-Shortcut (.lnk-File) zeigt.
 *
 * @return string lnkFile - Pfadangabe zum Shortcut
 *
 * @return string - Dateipfad der Zieldatei
 */
string GetShortcutTarget(string lnkFile) {
   /**
    * --------------------------------------------------------------------------
    *  How to read the target's path from a .lnk-file:
    * --------------------------------------------------------------------------
    *  Problem:
    *
    *     The COM interface to shell32.dll IShellLink::GetPath() fails!
    *
    *  Solution:
    *
    *    We need to parse the file manually. The path can be found like shown
    *    here.  If the shell item id list is not present (as signaled in flags),
    *    we have to assume A = -6.
    *
    *   +-----------------+----------------------------------------------------+
    *   |     Byte-Offset | Description                                        |
    *   +-----------------+----------------------------------------------------+
    *   |               0 | 'L' (magic value)                                  |
    *   +-----------------+----------------------------------------------------+
    *   |            4-19 | GUID                                               |
    *   +-----------------+----------------------------------------------------+
    *   |           20-23 | shortcut flags                                     |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | ...                                                |
    *   +-----------------+----------------------------------------------------+
    *   |           76-77 | A (16 bit): size of shell item id list, if present |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | shell item id list, if present                     |
    *   +-----------------+----------------------------------------------------+
    *   |      78 + 4 + A | B (32 bit): size of file location info             |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | file location info                                 |
    *   +-----------------+----------------------------------------------------+
    *   |      78 + A + B | C (32 bit): size of local volume table             |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | local volume table                                 |
    *   +-----------------+----------------------------------------------------+
    *   |  78 + A + B + C | target path string (ending with 0x00)              |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | ...                                                |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | 0x00                                               |
    *   +-----------------+----------------------------------------------------+
    *
    *  @see http://www.codeproject.com/KB/shell/ReadLnkFile.aspx
    * --------------------------------------------------------------------------
    */
   if (StringLen(lnkFile) < 4 || StringRight(lnkFile, 4)!=".lnk") {
      catch("GetShortcutTarget(1)  invalid parameter lnkFile = \""+ lnkFile +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   // --------------------------------------------------------------------------
   // Get the .lnk-file content:
   // --------------------------------------------------------------------------
   int hFile = _lopen(string lnkFile, OF_READ);
   if (hFile == HFILE_ERROR) {                     // kernel32::GetLastError() ist nicht erreichbar, Existenz daher manuell prüfen
      if (IsFile(lnkFile)) catch("GetShortcutTarget(2)  access denied to \""+ lnkFile +"\"", ERR_CANNOT_OPEN_FILE);
      else                 catch("GetShortcutTarget(3)  file not found: \""+ lnkFile +"\"", ERR_CANNOT_OPEN_FILE);
      return("");
   }
   int fileSize = GetFileSize(hFile, NULL);
   int ints     = MathCeil(fileSize/4.0);          // noch keinen Weg gefunden, Strings mit 0-Bytes einzulesen, daher int-Array als Buffer
   int buffer[]; ArrayResize(buffer, ints);        // buffer[] ist maximal 3 Bytes größer als notwendig

   int bytes = _lread(hFile, buffer, ints * 4);    // 1 Integer = 4 Bytes
   _lclose(hFile);

   if (bytes != fileSize) {
      catch("GetShortcutTarget(4)  error reading \""+ lnkFile +"\"", ERR_WINDOWS_ERROR);
      return("");
   }
   if (bytes < 24) {
      catch("GetShortcutTarget(5)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   int charsSize = bytes;
   int chars[]; ArrayResize(chars, charsSize);     // int-Array in char-Array umwandeln
   for (int i, n=0; i < ints; i++) {
      for (int shift=0; shift < 32 && n < charsSize; shift+=8, n++) {
         chars[n] = (buffer[i] >> shift) & 0xFF;
      }
   }

   // --------------------------------------------------------------------------
   // Check the magic value (first byte) and the GUID (16 byte from 5th byte):
   // --------------------------------------------------------------------------
   // The GUID is telling the version of the .lnk-file format. We expect the
   // following GUID (hex): 01 14 02 00 00 00 00 00 C0 00 00 00 00 00 00 46.
   // --------------------------------------------------------------------------
   if (chars[0] != 'L') {                          // test the magic value
      catch("GetShortcutTarget(6)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   if (chars[ 4] != 0x01 ||                        // test the GUID
       chars[ 5] != 0x14 ||
       chars[ 6] != 0x02 ||
       chars[ 7] != 0x00 ||
       chars[ 8] != 0x00 ||
       chars[ 9] != 0x00 ||
       chars[10] != 0x00 ||
       chars[11] != 0x00 ||
       chars[12] != 0xC0 ||
       chars[13] != 0x00 ||
       chars[14] != 0x00 ||
       chars[15] != 0x00 ||
       chars[16] != 0x00 ||
       chars[17] != 0x00 ||
       chars[18] != 0x00 ||
       chars[19] != 0x46) {
      catch("GetShortcutTarget(7)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   // --------------------------------------------------------------------------
   // Get the flags (4 byte from 21st byte) and
   // --------------------------------------------------------------------------
   // Check if it points to a file or directory.
   // --------------------------------------------------------------------------
   // Flags (4 byte little endian):
   //        Bit 0 -> has shell item id list
   //        Bit 1 -> points to file or directory
   //        Bit 2 -> has description
   //        Bit 3 -> has relative path
   //        Bit 4 -> has working directory
   //        Bit 5 -> has commandline arguments
   //        Bit 6 -> has custom icon
   // --------------------------------------------------------------------------
   int dwFlags  = chars[20];
       dwFlags |= chars[21] <<  8;
       dwFlags |= chars[22] << 16;
       dwFlags |= chars[23] << 24;

   bool hasShellItemIdList = (dwFlags & 0x00000001 == 0x00000001);
   bool pointsToFileOrDir  = (dwFlags & 0x00000002 == 0x00000002);

   if (!pointsToFileOrDir) {
      log("GetShortcutTarget(8)  shortcut target is not a file or directory: \""+ lnkFile +"\"");
      return("");
   }

   // --------------------------------------------------------------------------
   // Shell item id list (starts at offset 76 with 2 byte length):
   // --------------------------------------------------------------------------
   int A = -6;
   if (hasShellItemIdList) {
      i = 76;
      if (charsSize < i+2) {
         catch("GetShortcutTarget(9)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
         return("");
      }
      A  = chars[76];               // little endian format
      A |= chars[77] << 8;
   }

   // --------------------------------------------------------------------------
   // File location info:
   // --------------------------------------------------------------------------
   // Follows the shell item id list and starts with 4 byte structure length,
   // followed by 4 byte offset.
   // --------------------------------------------------------------------------
   i = 78 + 4 + A;
   if (charsSize < i+4) {
      catch("GetShortcutTarget(10)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   int B  = chars[i];       i++;    // little endian format
       B |= chars[i] <<  8; i++;
       B |= chars[i] << 16; i++;
       B |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local volume table:
   // --------------------------------------------------------------------------
   // Follows the file location info and starts with 4 byte table length for
   // skipping the actual table and moving to the local path string.
   // --------------------------------------------------------------------------
   i = 78 + A + B;
   if (charsSize < i+4) {
      catch("GetShortcutTarget(11)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   int C  = chars[i];       i++;    // little endian format
       C |= chars[i] <<  8; i++;
       C |= chars[i] << 16; i++;
       C |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local path string (ending with 0x00):
   // --------------------------------------------------------------------------
   i = 78 + A + B + C;
   if (charsSize < i+1) {
      catch("GetShortcutTarget(12)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   string target = "";
   for (; i < charsSize; i++) {
      if (chars[i] == 0x00)
         break;
      target = StringConcatenate(target, CharToStr(chars[i]));
   }
   if (StringLen(target) == 0) {
      catch("GetShortcutTarget(13)  invalid target in .lnk-file \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   // --------------------------------------------------------------------------
   // Convert the target path into the long filename format:
   // --------------------------------------------------------------------------
   // GetLongPathNameA() fails if the target file doesn't exist!
   // --------------------------------------------------------------------------
   string lfnBuffer[1]; lfnBuffer[0] = StringConcatenate(MAX_STRING_LITERAL, ".....");    // 255 + 5 = MAX_PATH

   if (!GetLongPathNameA(target, lfnBuffer[0], MAX_PATH))
      return(target);                                                                     // file doesn't exist
   target = lfnBuffer[0];

   //debug("GetShortcutTarget()   chars = "+ ArraySize(chars) +"   A = "+ A +"   B = "+ B +"   C = "+ C +"   target = "+ target);

   if (catch("GetShortcutTarget(14)") != NO_ERROR)
      return("");
   return(target);
}


/**
 * Schickt per PostMessage() einen einzelnen Fake-Tick an den aktuellen Chart.
 *
 * @param  bool sound - ob der Tick akustisch bestätigt werden soll oder nicht (default: nein)
 *
 * @return int - Fehlerstatus (-1, wenn das Script im Backtester läuft und WindowHandle() nicht benutzt werden kann)
 */
int SendTick(bool sound=false) {
   if (IsTesting())
      return(-1);

   if (WM_MT4 == 0)                                                        // @see <stddefine.mqh>
      WM_MT4 = RegisterWindowMessageA("MetaTrader4_Internal_Message");

   int hWnd = WindowHandle(Symbol(), Period());
   if (hWnd <= 0)
      return(catch("SendTick(1)   unable to get WindowHandle("+ Symbol() +", "+ PeriodToStr(Period()) +") => "+ hWnd, ERR_RUNTIME_ERROR));
   PostMessageA(hWnd, WM_MT4, 2, 1);

   if (sound)
      PlaySound("tick1.wav");

   return(catch("SendTick()"));
}


/**
 * Gibt das für den aktuellen Chart verwendete Kurshistory-Verzeichnis zurück (Tradeserver-Verzeichnis).  Der Name dieses Verzeichnisses ist bei bestehender
 * Verbindung identisch mit dem Rückgabewert von AccountServer(), läßt sich mit dieser Funktion aber auch ohne Verbindung und bei Accountwechsel zuverlässig
 * ermitteln.
 *
 * @return string
 */
string GetTradeServerDirectory() {
   // Das Tradeserververzeichnis wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen
   // die Rückgabewerte der MQL-Accountfunktionen evt. schon auf den neuen Account, der aktuelle Tick gehört aber noch zum alten Chart (mit den alten Bars).
   // Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Verzeichnis befinden.

   static string cache.directory[];
   static int    lastTick;                                           // Erkennung von Mehrfachaufrufen während eines Ticks

   // 1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (ValidBars == 0) /*&&*/ if (Tick != lastTick)
      ArrayResize(cache.directory, 0);
   lastTick = Tick;

   // 2) wenn Wert im Cache, gecachten Wert zurückgeben
   if (ArraySize(cache.directory) > 0)
      return(cache.directory[0]);

   // 3.1) Wert ermitteln
   string serverDirectory = AccountServer();

   // 3.2) wenn AccountServer() == "", Verzeichnis manuell ermitteln
   if (StringLen(serverDirectory) == 0) {
      // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
      string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");
      int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
      if (hFile < 0) {                                               // u.a. wenn das Serververzeichnis noch nicht existiert
         catch("GetTradeServerDirectory(1)  FileOpenHistory(\""+ fileName +"\")");
         return("");
      }
      FileClose(hFile);

      // Datei suchen und Tradeserver-Pfad auslesen
      string pattern = StringConcatenate(TerminalPath(), "\\history\\*");
      int /*WIN32_FIND_DATA*/ wfd[80];

      int hFindDir = FindFirstFileA(pattern, wfd), result=hFindDir;
      while (result > 0) {
         if (wfd.FileAttribute.Directory(wfd)) {
            string name = wfd.FileName(wfd);
            if (name != ".") /*&&*/ if (name != "..") {
               pattern = StringConcatenate(TerminalPath(), "\\history\\", name, "\\", fileName);
               int hFindFile = FindFirstFileA(pattern, wfd);
               if (hFindFile != INVALID_HANDLE_VALUE) {              // hier müßte eigentlich auf ERR_FILE_NOT_FOUND geprüft werden, doch MQL kann es nicht
                  //debug("FindTradeServerDirectory()   file = "+ pattern +"   found");

                  FindClose(hFindFile);
                  serverDirectory = name;
                  if (!DeleteFileA(pattern))                         // tmp. Datei per Win-API löschen (MQL kann es im History-Verzeichnis nicht)
                     return(catch("GetTradeServerDirectory(2)   kernel32::DeleteFile(\""+ pattern +"\") => FALSE", ERR_WINDOWS_ERROR));
                  break;
               }
            }
         }
         result = FindNextFileA(hFindDir, wfd);
      }
      if (result == INVALID_HANDLE_VALUE) {
         catch("GetTradeServerDirectory(3)  kernel32::FindFirstFile(\""+ pattern +"\") => INVALID_HANDLE_VALUE", ERR_WINDOWS_ERROR);
         return("");
      }
      FindClose(hFindDir);
      //debug("GetTradeServerDirectory()   resolved serverDirectory = \""+ serverDirectory +"\"");
   }

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetTradeServerDirectory(4)", error);
      return("");
   }
   if (serverDirectory == "") {
      catch("GetTradeServerDirectory(5)  cannot find trade server directory", ERR_RUNTIME_ERROR);
      return("");
   }

   // 3.3) Wert cachen
   ArrayResize(cache.directory, 1);
   cache.directory[0] = serverDirectory;

   return(serverDirectory);
}


/**
 * Gibt den Kurznamen der Firma des aktuellen Accounts zurück. Der Name wird aus dem Namen des Account-Servers und
 * nicht aus dem Rückgabewert von AccountCompany() ermittelt.
 *
 * @return string - Kurzname
 */
string GetShortAccountCompany() {
   string server=StringToLower(GetTradeServerDirectory());

   if      (StringStartsWith(server, "alpari-"            )) return("Alpari"          );
   else if (StringStartsWith(server, "alparibroker-"      )) return("Alpari"          );
   else if (StringStartsWith(server, "alpariuk-"          )) return("Alpari"          );
   else if (StringStartsWith(server, "alparius-"          )) return("Alpari"          );
   else if (StringStartsWith(server, "apbgtrading-"       )) return("APBG"            );
   else if (StringStartsWith(server, "atcbrokers-"        )) return("ATC Brokers"     );
   else if (StringStartsWith(server, "atcbrokersest-"     )) return("ATC Brokers"     );
   else if (StringStartsWith(server, "broco-"             )) return("BroCo"           );
   else if (StringStartsWith(server, "brocoinvestments-"  )) return("BroCo"           );
   else if (StringStartsWith(server, "dukascopy-"         )) return("Dukascopy"       );
   else if (StringStartsWith(server, "easyforex-"         )) return("EasyForex"       );
   else if (StringStartsWith(server, "forex-"             )) return("Forex Ltd"       );
   else if (StringStartsWith(server, "forexbaltic-"       )) return("FB Capital"      );
   else if (StringStartsWith(server, "fxpro.com-"         )) return("FxPro"           );
   else if (StringStartsWith(server, "fxdd-"              )) return("FXDD"            );
   else if (StringStartsWith(server, "inovatrade-"        )) return("InovaTrade"      );
   else if (StringStartsWith(server, "investorseurope-"   )) return("Investors Europe");
   else if (StringStartsWith(server, "londoncapitalgr-"   )) return("London Capital"  );
   else if (StringStartsWith(server, "londoncapitalgroup-")) return("London Capital"  );
   else if (StringStartsWith(server, "mbtrading-"         )) return("MB Trading"      );
   else if (StringStartsWith(server, "sig-"               )) return("SIG"             );
   else if (StringStartsWith(server, "teletrade-"         )) return("TeleTrade"       );

   return(AccountCompany());
}


/**
 * Führt eine Anwendung aus und wartet, bis sie beendet ist.
 *
 * @param  string cmdLine - Befehlszeile
 * @param  int    cmdShow - ShowWindow() command id
 *
 * @return int - Fehlerstatus
 */
int WinExecAndWait(string cmdLine, int cmdShow) {
   int /*STARTUPINFO*/ si[17]; ArrayInitialize(si, 0);
      si.setCb        (si, 68);
      si.setFlags     (si, STARTF_USESHOWWINDOW);
      si.setShowWindow(si, cmdShow);
   int /*PROCESS_INFORMATION*/ pi[4]; ArrayInitialize(pi, 0);

   if (!CreateProcessA(NULL, cmdLine, NULL, NULL, false, 0, NULL, NULL, si, pi))
      return(catch("WinExecAndWait(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   int result = WaitForSingleObject(pi.hProcess(pi), INFINITE);

   if (result != WAIT_OBJECT_0) {
      if (result == WAIT_FAILED) catch("WinExecAndWait(2)   WaitForSingleObject() => WAIT_FAILED", ERR_WINDOWS_ERROR);
      else                       log("WinExecAndWait()   WaitForSingleObject() => "+ WaitForSingleObjectValueToStr(result));
   }

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("WinExecAndWait(3)"));
}


/**
 * Liest eine Datei zeilenweise (ohne Zeilenende-Zeichen) in ein Array ein.
 *
 * @param  string  filename       - Dateiname mit zu "{terminal-path}\experts\files" relativer Pfadangabe
 * @param  string& lpResult[]     - Zeiger auf ein Ergebnisarray für die Zeilen der Datei
 * @param  bool    skipEmptyLines - ob leere Zeilen übersprungen werden sollen oder nicht (default: FALSE)
 *
 * @return int - Anzahl der eingelesenen Zeilen oder -1, falls ein Fehler auftrat
 */
int FileReadLines(string filename, string& lpResult[], bool skipEmptyLines=false) {
   int fieldSeparator = '\t';

   // Datei öffnen
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, fieldSeparator);  // FileOpen() erwartet Pfadangabe relativ zu .\experts\files
   if (hFile < 0) {
      catch("FileReadLines(1)   FileOpen(filenname=\""+ filename +"\")", GetLastError());
      return(-1);
   }


   // Schnelle Rückkehr bei leerer Datei
   if (FileSize(hFile) == 0) {
      FileClose(hFile);
      ArrayResize(lpResult, 0);
      return(ifInt(catch("FileReadLines(2)")==NO_ERROR, 0, -1));
   }


   // Datei zeilenweise einlesen
   bool newLine=true, blankLine=false, lineEnd=true;
   string line, lines[]; ArrayResize(lines, 0);                         // Zwischenspeicher für gelesene Zeilen
   int i = 0;                                                           // Zeilenzähler

   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                                    // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                              // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
      }

      // Zeile auslesen
      string value = FileReadString(hFile);

      // auf Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                                 // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                                        // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
            }
         }
      }

      // Leerzeilen ggf. überspringen
      if (blankLine) /*&&*/ if (skipEmptyLines)
         continue;

      // Wert in neuer Zeile speichern oder vorherige Zeile aktualisieren
      if (newLine) {
         i++;
         ArrayResize(lines, i);
         lines[i-1] = value;
         //log("FileReadLines()   new line = \""+ lines[i-1] +"\"");
      }
      else {
         lines[i-1] = StringConcatenate(lines[i-1], CharToStr(fieldSeparator), value);
         //log("FileReadLines()   updated line = \""+ lines[i-1] +"\"");
      }
   }

   // Dateiende hat ERR_END_OF_FILE ausgelöst
   int error = GetLastError();
   if (error!=ERR_END_OF_FILE) /*&&*/ if (error!=NO_ERROR) {
      FileClose(hFile);
      catch("FileReadLines(2)", error);
      return(-1);
   }

   // Datei schließen
   FileClose(hFile);

   // Zeilen in Ergebnisarray kopieren
   ArrayResize(lpResult, i);
   if (i > 0)
      ArrayCopy(lpResult, lines);

   return(ifInt(catch("FileReadLines(3)")==NO_ERROR, i, -1));
}


/**
 * Gibt die lesbare Version eines Rückgabewertes von WaitForSingleObject() zurück.
 *
 * @param  int value - Rückgabewert
 *
 * @return string
 */
string WaitForSingleObjectValueToStr(int value) {
   switch (value) {
      case WAIT_FAILED   : return("WAIT_FAILED"   );
      case WAIT_ABANDONED: return("WAIT_ABANDONED");
      case WAIT_OBJECT_0 : return("WAIT_OBJECT_0" );
      case WAIT_TIMEOUT  : return("WAIT_TIMEOUT"  );
   }
   return("");
}


/**
 * Gibt für ein broker-spezifisches Symbol das Standardsymbol zurück.
 * (z.B. GetStandardSymbol("EURUSDm") => "EURUSD")
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - Standardsymbol oder der übergebene Ausgangswert, wenn das Brokersymbol unbekannt ist
 *
 *
 * NOTE:
 * -----
 * Alias für GetStandardSymbolDefault(symbol, symbol)
 *
 * @see GetStandardSymbolStrict()
 * @see GetStandardSymbolDefault()
 */
string GetStandardSymbol(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetStandardSymbol()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }
   return(GetStandardSymbolDefault(symbol, symbol));
}


/**
 * Gibt für ein broker-spezifisches Symbol das Standardsymbol oder den angegebenen Alternativwert zurück.
 * (z.B. GetStandardSymbolDefault("EURUSDm") => "EURUSD")
 *
 * @param  string symbol   - broker-spezifisches Symbol
 * @param  string altValue - alternativer Rückgabewert, falls kein Standardsymbol gefunden wurde
 *
 * @return string - Ergebnis
 *
 *
 * NOTE:
 * -----
 * Im Unterschied zu GetStandardSymbolStrict() erlaubt diese Funktion die bequeme Angabe eines Alternativwertes, läßt jedoch nicht mehr so
 * einfach erkennen, ob ein Standardsymbol gefunden wurde oder nicht.
 *
 * @see GetStandardSymbolStrict()
 */
string GetStandardSymbolDefault(string symbol, string altValue="") {
   if (StringLen(symbol) == 0) {
      catch("GetStandardSymbolDefault()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   string value = GetStandardSymbolStrict(symbol);

   if (StringLen(value) == 0)
      value = altValue;

   return(value);
}


/**
 * Gibt für ein broker-spezifisches Symbol das Standardsymbol zurück.
 * (z.B. GetStandardSymbolStrict("EURUSDm") => "EURUSD")
 *
 * @param  string symbol   - broker-spezifisches Symbol
 *
 * @return string - Standardsymbol oder Leerstring, wenn kein Standardsymbol gefunden wurde.
 *
 *
 * @see GetStandardSymbolDefault() - für die Angabe eines Alternativwertes, wenn kein Standardsymbol gefunden wurde
 */
string GetStandardSymbolStrict(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetStandardSymbolStrict()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   symbol = StringToUpper(symbol);

   if      (StringEndsWith(symbol, "_ASK")) symbol = StringLeft(symbol, -4);
   else if (StringEndsWith(symbol, "_AVG")) symbol = StringLeft(symbol, -4);

   switch (StringGetChar(symbol, 0)) {
      case '#': if (symbol == "#DAX.XEI" ) return("#DAX.X");
                if (symbol == "#DJI.XDJ" ) return("#DJI.X");
                if (symbol == "#DJT.XDJ" ) return("#DJT.X");
                if (symbol == "#SPX.X.XP") return("#SPX.X");
                break;

      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9': break;

      case 'A': if (StringStartsWith(symbol, "AUDCAD")) return("AUDCAD");
                if (StringStartsWith(symbol, "AUDCHF")) return("AUDCHF");
                if (StringStartsWith(symbol, "AUDDKK")) return("AUDDKK");
                if (StringStartsWith(symbol, "AUDJPY")) return("AUDJPY");
                if (StringStartsWith(symbol, "AUDLFX")) return("AUDLFX");
                if (StringStartsWith(symbol, "AUDNZD")) return("AUDNZD");
                if (StringStartsWith(symbol, "AUDPLN")) return("AUDPLN");
                if (StringStartsWith(symbol, "AUDSGD")) return("AUDSGD");
                if (StringStartsWith(symbol, "AUDUSD")) return("AUDUSD");
                break;

      case 'B': break;

      case 'C': if (StringStartsWith(symbol, "CADCHF")) return("CADCHF");
                if (StringStartsWith(symbol, "CADJPY")) return("CADJPY");
                if (StringStartsWith(symbol, "CADLFX")) return("CADLFX");
                if (StringStartsWith(symbol, "CADSGD")) return("CADSGD");
                if (StringStartsWith(symbol, "CHFJPY")) return("CHFJPY");
                if (StringStartsWith(symbol, "CHFLFX")) return("CHFLFX");
                if (StringStartsWith(symbol, "CHFSGD")) return("CHFSGD");
                break;

      case 'D': break;

      case 'E': if (StringStartsWith(symbol, "EURAUD")) return("EURAUD");
                if (StringStartsWith(symbol, "EURCAD")) return("EURCAD");
                if (StringStartsWith(symbol, "EURCCK")) return("EURCZK");
                if (StringStartsWith(symbol, "EURCZK")) return("EURCZK");
                if (StringStartsWith(symbol, "EURCHF")) return("EURCHF");
                if (StringStartsWith(symbol, "EURDKK")) return("EURDKK");
                if (StringStartsWith(symbol, "EURGBP")) return("EURGBP");
                if (StringStartsWith(symbol, "EURHKD")) return("EURHKD");
                if (StringStartsWith(symbol, "EURHUF")) return("EURHUF");
                if (StringStartsWith(symbol, "EURJPY")) return("EURJPY");
                if (StringStartsWith(symbol, "EURLFX")) return("EURLFX");
                if (StringStartsWith(symbol, "EURLVL")) return("EURLVL");
                if (StringStartsWith(symbol, "EURMXN")) return("EURMXN");
                if (StringStartsWith(symbol, "EURNOK")) return("EURNOK");
                if (StringStartsWith(symbol, "EURNZD")) return("EURNZD");
                if (StringStartsWith(symbol, "EURPLN")) return("EURPLN");
                if (StringStartsWith(symbol, "EURRUB")) return("EURRUB");
                if (StringStartsWith(symbol, "EURRUR")) return("EURRUB");
                if (StringStartsWith(symbol, "EURSEK")) return("EURSEK");
                if (StringStartsWith(symbol, "EURSGD")) return("EURSGD");
                if (StringStartsWith(symbol, "EURTRY")) return("EURTRY");
                if (StringStartsWith(symbol, "EURUSD")) return("EURUSD");
                if (StringStartsWith(symbol, "EURZAR")) return("EURZAR");
                if (symbol == "ECX" )                   return("EURX"  );
                if (symbol == "EURX")                   return("EURX"  );
                break;

      case 'F': break;

      case 'G': if (StringStartsWith(symbol, "GBPAUD")) return("GBPAUD");
                if (StringStartsWith(symbol, "GBPCAD")) return("GBPCAD");
                if (StringStartsWith(symbol, "GBPCHF")) return("GBPCHF");
                if (StringStartsWith(symbol, "GBPDKK")) return("GBPDKK");
                if (StringStartsWith(symbol, "GBPJPY")) return("GBPJPY");
                if (StringStartsWith(symbol, "GBPLFX")) return("GBPLFX");
                if (StringStartsWith(symbol, "GBPNOK")) return("GBPNOK");
                if (StringStartsWith(symbol, "GBPNZD")) return("GBPNZD");
                if (StringStartsWith(symbol, "GBPRUB")) return("GBPRUB");
                if (StringStartsWith(symbol, "GBPRUR")) return("GBPRUB");
                if (StringStartsWith(symbol, "GBPSEK")) return("GBPSEK");
                if (StringStartsWith(symbol, "GBPUSD")) return("GBPUSD");
                if (StringStartsWith(symbol, "GBPZAR")) return("GBPZAR");
                if (symbol == "GOLD"    )               return("XAUUSD");
                if (symbol == "GOLDEURO")               return("XAUEUR");
                break;

      case 'H': if (StringStartsWith(symbol, "HKDJPY")) return("HKDJPY");
                break;

      case 'I':
      case 'J':
      case 'K': break;

      case 'L': if (StringStartsWith(symbol, "LFXJPY")) return("LFXJPY");
                break;

      case 'M': if (StringStartsWith(symbol, "MXNJPY")) return("MXNJPY");
                break;

      case 'N': if (StringStartsWith(symbol, "NOKJPY")) return("NOKJPY");
                if (StringStartsWith(symbol, "NOKSEK")) return("NOKSEK");
                if (StringStartsWith(symbol, "NZDCAD")) return("NZDCAD");
                if (StringStartsWith(symbol, "NZDCHF")) return("NZDCHF");
                if (StringStartsWith(symbol, "NZDJPY")) return("NZDJPY");
                if (StringStartsWith(symbol, "NZDLFX")) return("NZDLFX");
                if (StringStartsWith(symbol, "NZDSGD")) return("NZDSGD");
                if (StringStartsWith(symbol, "NZDUSD")) return("NZDUSD");
                break;

      case 'O':
      case 'P':
      case 'Q': break;

      case 'S': if (StringStartsWith(symbol, "SEKJPY")) return("SEKJPY");
                if (StringStartsWith(symbol, "SGDJPY")) return("SGDJPY");
                if (symbol == "SILVER"    )             return("XAGUSD");
                if (symbol == "SILVEREURO")             return("XAGEUR");
                break;

      case 'T': break;

      case 'U': if (StringStartsWith(symbol, "USDCAD")) return("USDCAD");
                if (StringStartsWith(symbol, "USDCHF")) return("USDCHF");
                if (StringStartsWith(symbol, "USDCCK")) return("USDCZK");
                if (StringStartsWith(symbol, "USDCZK")) return("USDCZK");
                if (StringStartsWith(symbol, "USDDKK")) return("USDDKK");
                if (StringStartsWith(symbol, "USDHKD")) return("USDHKD");
                if (StringStartsWith(symbol, "USDHRK")) return("USDHRK");
                if (StringStartsWith(symbol, "USDHUF")) return("USDHUF");
                if (StringStartsWith(symbol, "USDJPY")) return("USDJPY");
                if (StringStartsWith(symbol, "USDLFX")) return("USDLFX");
                if (StringStartsWith(symbol, "USDLTL")) return("USDLTL");
                if (StringStartsWith(symbol, "USDLVL")) return("USDLVL");
                if (StringStartsWith(symbol, "USDMXN")) return("USDMXN");
                if (StringStartsWith(symbol, "USDNOK")) return("USDNOK");
                if (StringStartsWith(symbol, "USDPLN")) return("USDPLN");
                if (StringStartsWith(symbol, "USDRUB")) return("USDRUB");
                if (StringStartsWith(symbol, "USDRUR")) return("USDRUB");
                if (StringStartsWith(symbol, "USDSEK")) return("USDSEK");
                if (StringStartsWith(symbol, "USDSGD")) return("USDSGD");
                if (StringStartsWith(symbol, "USDTRY")) return("USDTRY");
                if (StringStartsWith(symbol, "USDZAR")) return("USDZAR");
                if (symbol == "USDX")                   return("USDX"  );
                break;

      case 'V':
      case 'W': break;

      case 'X': if (StringStartsWith(symbol, "XAGEUR")) return("XAGEUR");
                if (StringStartsWith(symbol, "XAGUSD")) return("XAGUSD");
                if (StringStartsWith(symbol, "XAUEUR")) return("XAUEUR");
                if (StringStartsWith(symbol, "XAUUSD")) return("XAUUSD");
                break;

      case 'Y':
      case 'Z': break;

      case '_': if (symbol == "_DJI"   ) return("#DJI.X"  );
                if (symbol == "_DJT"   ) return("#DJT.X"  );
                if (symbol == "_N225"  ) return("#NIK.X"  );
                if (symbol == "_NQ100" ) return("#N100.X" );
                if (symbol == "_NQCOMP") return("#NCOMP.X");
                if (symbol == "_SP500" ) return("#SPX.X"  );
                break;
   }

   return("");
}


/**
 * Gibt den Kurznamen eines Symbols zurück.
 * (z.B. GetSymbolName("EURUSD") => "EUR/USD")
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - Kurzname oder der übergebene Ausgangswert, wenn das Symbol unbekannt ist
 *
 *
 * NOTE:
 * -----
 * Alias für GetSymbolNameDefault(symbol, symbol)
 *
 * @see GetSymbolNameStrict()
 * @see GetSymbolNameDefault()
 */
string GetSymbolName(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolName()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }
   return(GetSymbolNameDefault(symbol, symbol));
}


/**
 * Gibt den Kurznamen eines Symbols zurück oder den angegebenen Alternativwert, wenn das Symbol unbekannt ist.
 * (z.B. GetSymbolNameDefault("EURUSD") => "EUR/USD")
 *
 * @param  string symbol   - Symbol
 * @param  string altValue - alternativer Rückgabewert
 *
 * @return string - Ergebnis
 *
 * @see GetSymbolNameStrict()
 */
string GetSymbolNameDefault(string symbol, string altValue="") {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolNameDefault()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   string value = GetSymbolNameStrict(symbol);

   if (StringLen(value) == 0)
      value = altValue;

   return(value);
}


/**
 * Gibt den Kurznamen eines Symbols zurück.
 * (z.B. GetSymbolNameStrict("EURUSD") => "EUR/USD")
 *
 * @param  string symbol - Symbol
 *
 * @return string - Kurzname oder Leerstring, wenn das Symbol unbekannt ist
 */
string GetSymbolNameStrict(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolNameStrict()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   symbol = GetStandardSymbolStrict(symbol);
   if (StringLen(symbol) == 0)
      return("");

   if (symbol == "#DAX.X"  ) return("DAX"      );
   if (symbol == "#DJI.X"  ) return("DJIA"     );
   if (symbol == "#DJT.X"  ) return("DJTA"     );
   if (symbol == "#N100.X" ) return("N100"     );
   if (symbol == "#NCOMP.X") return("NCOMP"    );
   if (symbol == "#NIK.X"  ) return("Nikkei"   );
   if (symbol == "#SPX.X"  ) return("SP500"    );
   if (symbol == "AUDCAD"  ) return("AUD/CAD"  );
   if (symbol == "AUDCHF"  ) return("AUD/CHF"  );
   if (symbol == "AUDDKK"  ) return("AUD/DKK"  );
   if (symbol == "AUDJPY"  ) return("AUD/JPY"  );
   if (symbol == "AUDLFX"  ) return("AUD-Index");
   if (symbol == "AUDNZD"  ) return("AUD/NZD"  );
   if (symbol == "AUDPLN"  ) return("AUD/PLN"  );
   if (symbol == "AUDSGD"  ) return("AUD/SGD"  );
   if (symbol == "AUDUSD"  ) return("AUD/USD"  );
   if (symbol == "CADCHF"  ) return("CAD/CHF"  );
   if (symbol == "CADJPY"  ) return("CAD/JPY"  );
   if (symbol == "CADLFX"  ) return("CAD-Index");
   if (symbol == "CADSGD"  ) return("CAD/SGD"  );
   if (symbol == "CHFJPY"  ) return("CHF/JPY"  );
   if (symbol == "CHFLFX"  ) return("CHF-Index");
   if (symbol == "CHFSGD"  ) return("CHF/SGD"  );
   if (symbol == "EURAUD"  ) return("EUR/AUD"  );
   if (symbol == "EURCAD"  ) return("EUR/CAD"  );
   if (symbol == "EURCHF"  ) return("EUR/CHF"  );
   if (symbol == "EURCZK"  ) return("EUR/CZK"  );
   if (symbol == "EURDKK"  ) return("EUR/DKK"  );
   if (symbol == "EURGBP"  ) return("EUR/GBP"  );
   if (symbol == "EURHKD"  ) return("EUR/HKD"  );
   if (symbol == "EURHUF"  ) return("EUR/HUF"  );
   if (symbol == "EURJPY"  ) return("EUR/JPY"  );
   if (symbol == "EURLFX"  ) return("EUR-Index");
   if (symbol == "EURLVL"  ) return("EUR/LVL"  );
   if (symbol == "EURMXN"  ) return("EUR/MXN"  );
   if (symbol == "EURNOK"  ) return("EUR/NOK"  );
   if (symbol == "EURNZD"  ) return("EUR/NZD"  );
   if (symbol == "EURPLN"  ) return("EUR/PLN"  );
   if (symbol == "EURRUB"  ) return("EUR/RUB"  );
   if (symbol == "EURSEK"  ) return("EUR/SEK"  );
   if (symbol == "EURSGD"  ) return("EUR/SGD"  );
   if (symbol == "EURTRY"  ) return("EUR/TRY"  );
   if (symbol == "EURUSD"  ) return("EUR/USD"  );
   if (symbol == "EURX"    ) return("EUR-Index");
   if (symbol == "EURZAR"  ) return("EUR/ZAR"  );
   if (symbol == "GBPAUD"  ) return("GBP/AUD"  );
   if (symbol == "GBPCAD"  ) return("GBP/CAD"  );
   if (symbol == "GBPCHF"  ) return("GBP/CHF"  );
   if (symbol == "GBPDKK"  ) return("GBP/DKK"  );
   if (symbol == "GBPJPY"  ) return("GBP/JPY"  );
   if (symbol == "GBPLFX"  ) return("GBP-Index");
   if (symbol == "GBPNOK"  ) return("GBP/NOK"  );
   if (symbol == "GBPNZD"  ) return("GBP/NZD"  );
   if (symbol == "GBPRUB"  ) return("GBP/RUB"  );
   if (symbol == "GBPSEK"  ) return("GBP/SEK"  );
   if (symbol == "GBPUSD"  ) return("GBP/USD"  );
   if (symbol == "GBPZAR"  ) return("GBP/ZAR"  );
   if (symbol == "HKDJPY"  ) return("HKD/JPY"  );
   if (symbol == "LFXJPY"  ) return("JPY-Index");
   if (symbol == "MXNJPY"  ) return("MXN/JPY"  );
   if (symbol == "NOKJPY"  ) return("NOK/JPY"  );
   if (symbol == "NOKSEK"  ) return("NOK/SEK"  );
   if (symbol == "NZDCAD"  ) return("NZD/CAD"  );
   if (symbol == "NZDCHF"  ) return("NZD/CHF"  );
   if (symbol == "NZDJPY"  ) return("NZD/JPY"  );
   if (symbol == "NZDLFX"  ) return("NZD-Index");
   if (symbol == "NZDSGD"  ) return("NZD/SGD"  );
   if (symbol == "NZDUSD"  ) return("NZD/USD"  );
   if (symbol == "SEKJPY"  ) return("SEK/JPY"  );
   if (symbol == "SGDJPY"  ) return("SGD/JPY"  );
   if (symbol == "USDCAD"  ) return("USD/CAD"  );
   if (symbol == "USDCHF"  ) return("USD/CHF"  );
   if (symbol == "USDCZK"  ) return("USD/CZK"  );
   if (symbol == "USDDKK"  ) return("USD/DKK"  );
   if (symbol == "USDHKD"  ) return("USD/HKD"  );
   if (symbol == "USDHRK"  ) return("USD/HRK"  );
   if (symbol == "USDHUF"  ) return("USD/HUF"  );
   if (symbol == "USDJPY"  ) return("USD/JPY"  );
   if (symbol == "USDLFX"  ) return("USD-Index");
   if (symbol == "USDLTL"  ) return("USD/LTL"  );
   if (symbol == "USDLVL"  ) return("USD/LVL"  );
   if (symbol == "USDMXN"  ) return("USD/MXN"  );
   if (symbol == "USDNOK"  ) return("USD/NOK"  );
   if (symbol == "USDPLN"  ) return("USD/PLN"  );
   if (symbol == "USDRUB"  ) return("USD/RUB"  );
   if (symbol == "USDSEK"  ) return("USD/SEK"  );
   if (symbol == "USDSGD"  ) return("USD/SGD"  );
   if (symbol == "USDTRY"  ) return("USD/TRY"  );
   if (symbol == "USDX"    ) return("USD-Index");
   if (symbol == "USDZAR"  ) return("USD/ZAR"  );
   if (symbol == "XAGEUR"  ) return("XAG/EUR"  );
   if (symbol == "XAGUSD"  ) return("XAG/USD"  );
   if (symbol == "XAUEUR"  ) return("XAU/EUR"  );
   if (symbol == "XAUUSD"  ) return("XAU/USD"  );

   return("");
}


/**
 * Gibt den Langnamen eines Symbols zurück.
 * (z.B. GetSymbolLongName("EURUSD") => "EUR/USD")
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - Langname oder der übergebene Ausgangswert, wenn kein Langname gefunden wurde
 *
 *
 * NOTE:
 * -----
 * Alias für GetSymbolLongNameDefault(symbol, symbol)
 *
 * @see GetSymbolLongNameStrict()
 * @see GetSymbolLongNameDefault()
 */
string GetSymbolLongName(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolLongName()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }
   return(GetSymbolLongNameDefault(symbol, symbol));
}


/**
 * Gibt den Langnamen eines Symbols zurück oder den angegebenen Alternativwert, wenn kein Langname gefunden wurde.
 * (z.B. GetSymbolLongNameDefault("USDLFX") => "USD-Index (LiteForex)")
 *
 * @param  string symbol   - Symbol
 * @param  string altValue - alternativer Rückgabewert
 *
 * @return string - Ergebnis
 */
string GetSymbolLongNameDefault(string symbol, string altValue="") {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolLongNameDefault()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   string value = GetSymbolLongNameStrict(symbol);

   if (StringLen(value) == 0)
      value = altValue;

   return(value);
}


/**
 * Gibt den Langnamen eines Symbols zurück.
 * (z.B. GetSymbolLongNameStrict("USDLFX") => "USD-Index (LiteForex)")
 *
 * @param  string symbol - Symbol
 *
 * @return string - Langname oder Leerstring, wenn das Symnol unbekannt ist oder keinen Langnamen hat
 */
string GetSymbolLongNameStrict(string symbol) {
   if (StringLen(symbol) == 0) {
      catch("GetSymbolLongNameStrict()   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   symbol = GetStandardSymbolStrict(symbol);

   if (StringLen(symbol) == 0)
      return("");

   if (symbol == "#DJI.X"  ) return("Dow Jones Industrial"    );
   if (symbol == "#DJT.X"  ) return("Dow Jones Transportation");
   if (symbol == "#N100.X" ) return("Nasdaq 100"              );
   if (symbol == "#NCOMP.X") return("Nasdaq Composite"        );
   if (symbol == "#NIK.X"  ) return("Nikkei 225"              );
   if (symbol == "#SPX.X"  ) return("S&P 500"                 );
   if (symbol == "AUDLFX"  ) return("AUD-Index (LiteForex)"   );
   if (symbol == "CADLFX"  ) return("CAD-Index (LiteForex)"   );
   if (symbol == "CHFLFX"  ) return("CHF-Index (LiteForex)"   );
   if (symbol == "EURLFX"  ) return("EUR-Index (LiteForex)"   );
   if (symbol == "EURX"    ) return("EUR-Index (CME)"         );
   if (symbol == "GBPLFX"  ) return("GBP-Index (LiteForex)"   );
   if (symbol == "LFXJPY"  ) return("1/JPY-Index (LiteForex)" );
   if (symbol == "NZDLFX"  ) return("NZD-Index (LiteForex)"   );
   if (symbol == "USDLFX"  ) return("USD-Index (LiteForex)"   );
   if (symbol == "USDX"    ) return("USD-Index (CME)"         );
   if (symbol == "XAGEUR"  ) return("Silver/EUR"              );
   if (symbol == "XAGUSD"  ) return("Silver/USD"              );
   if (symbol == "XAUEUR"  ) return("Gold/EUR"                );
   if (symbol == "XAUUSD"  ) return("Gold/USD"                );

   string prefix = StringLeft(symbol, -3);
   string suffix = StringRight(symbol, 3);

   if      (suffix == ".AB") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Balance" ));
   else if (suffix == ".EQ") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Equity"  ));
   else if (suffix == ".LV") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Leverage"));
   else if (suffix == ".PL") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Profit/Loss"     ));
   else if (suffix == ".FM") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Free Margin"     ));
   else if (suffix == ".UM") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Used Margin"     ));

   return("");
}


/**
 *
 */
void trace(string script, string function) {
   string stack[];
   int    stackSize = ArraySize(stack);

   if (script != "-1") {
      ArrayResize(stack, stackSize+1);
      stack[stackSize] = StringConcatenate(script, "::", function);
   }
   else if (stackSize > 0) {
      ArrayResize(stack, stackSize-1);
   }

   Print("trace()    ", script, "::", function, "   stackSize=", ArraySize(stack));
}


/**
 * Konvertiert einen Boolean in den String "true" oder "false".
 *
 * @param  bool value
 *
 * @return string
 */
string BoolToStr(bool value) {
   if (value)
      return("true");
   return("false");
}


/**
 * Konvertiert ein Boolean-Array in einen lesbaren String.
 *
 * @param  bool   array[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string
 */
string BoolArrayToStr(bool& array[], string separator=", ") {
   if (ArraySize(array) == 0)
      return("{}");
   if (separator == "0")   // NULL
      separator = ", ";
   return(StringConcatenate("{", JoinBools(array, separator), "}"));
}


/**
 * Gibt die aktuelle Zeit in GMT zurück (entspricht UTC).
 *
 * @return datetime - Timestamp oder -1, falls ein Fehler auftrat
 */
datetime TimeGMT() {
   int /*SYSTEMTIME*/ st[4];     // struct SYSTEMTIME = 16 byte
   GetSystemTime(st);

   int year  = st.Year(st);
   int month = st.Month(st);
   int day   = st.Day(st);
   int hour  = st.Hour(st);
   int min   = st.Minute(st);
   int sec   = st.Second(st);

   string strTime = StringConcatenate(year, ".", month, ".", day, " ", hour, ":", min, ":", sec);
   datetime time  = StrToTime(strTime);

   //Print("TimeGMT()   strTime = "+ strTime +"    StrToTime(strTime) = "+ TimeToStr(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("TimeGMT()", error);
      return(-1);
   }
   return(time);
}


/**
 * Inlined conditional String-Statement.
 *
 * @param  bool   condition
 * @param  string thenValue
 * @param  string elseValue
 *
 * @return string
 */
string ifString(bool condition, string thenValue, string elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Integer-Statement.
 *
 * @param  bool condition
 * @param  int  thenValue
 * @param  int  elseValue
 *
 * @return int
 */
int ifInt(bool condition, int thenValue, int elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Double-Statement.
 *
 * @param  bool   condition
 * @param  double thenValue
 * @param  double elseValue
 *
 * @return double
 */
double ifDouble(bool condition, double thenValue, double elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Gibt die Anzahl der Dezimal- bzw. Nachkommastellen eines Zahlenwertes zurück.
 *
 * @param  double number
 *
 * @return int - Anzahl der Nachkommastellen, höchstens jedoch 8
 */
int CountDecimals(double number) {
   string str = number;
   int dot    = StringFind(str, ".");

   for (int i=StringLen(str)-1; i > dot; i--) {
      if (StringGetChar(str, i) != '0')
         break;
   }
   return(i - dot);
}


/**
 * Gibt den Divisionsrest zweier Doubles zurück (fehlerbereinigter Ersatz für MathMod()).
 *
 * @param  double a
 * @param  double b
 *
 * @return double - Divisionsrest
 */
double MathModFix(double a, double b) {
   double remainder = MathMod(a, b);
   if (EQ(remainder, b))
      remainder = 0;
   return(remainder);
}


/**
 * Ob ein String mit dem angegebenen Teilstring beginnt. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object - zu prüfender String
 * @param  string prefix - Substring
 *
 * @return bool
 */
bool StringStartsWith(string object, string prefix) {
   if (StringLen(prefix) == 0) {
      catch("StringStartsWith()   empty prefix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(object, prefix) == 0);
}


/**
 * Ob ein String mit dem angegebenen Teilstring beginnt. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object - zu prüfender String
 * @param  string prefix - Substring
 *
 * @return bool
 */
bool StringIStartsWith(string object, string prefix) {
   if (StringLen(prefix) == 0) {
      catch("StringIStartsWith()   empty prefix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(StringToUpper(object), StringToUpper(prefix)) == 0);
}


/**
 * Ob ein String mit dem angegebenen Teilstring endet. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object  - zu prüfender String
 * @param  string postfix - Substring
 *
 * @return bool
 */
bool StringEndsWith(string object, string postfix) {
   int lenPostfix = StringLen(postfix);
   if (lenPostfix == 0) {
      catch("StringEndsWith()   empty postfix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(object, postfix) == StringLen(object)-lenPostfix);
}


/**
 * Ob ein String mit dem angegebenen Teilstring endet. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object  - zu prüfender String
 * @param  string postfix - Substring
 *
 * @return bool
 */
bool StringIEndsWith(string object, string postfix) {
   int lenPostfix = StringLen(postfix);
   if (lenPostfix == 0) {
      catch("StringIEndsWith()   empty postfix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(StringToUpper(object), StringToUpper(postfix)) == StringLen(object)-lenPostfix);
}


/**
 * Gibt einen linken Teilstring eines Strings zurück.
 *
 * Ist N positiv, gibt StringLeft() die N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StringLeft("ABCDEFG",  2)  =>  "AB"
 *
 * Ist N negativ, gibt StringLeft() alle außer den N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StringLeft("ABCDEFG", -2)  =>  "ABCDE"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StringLeft(string value, int n) {
   if      (n > 0) return(StringSubstr(value, 0, n));
   else if (n < 0) return(StringSubstrFix(value, 0, StringLen(value)+n));
   return("");
}


/**
 * Gibt einen rechten Teilstring eines Strings zurück.
 *
 * Ist N positiv, gibt StringRight() die N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StringRight("ABCDEFG",  2)  =>  "FG"
 *
 * Ist N negativ, gibt StringRight() alle außer den N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StringRight("ABCDEFG", -2)  =>  "CDEFG"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StringRight(string value, int n) {
   if      (n > 0) return(StringSubstr(value, StringLen(value)-n));
   else if (n < 0) return(StringSubstr(value, -n));
   return("");
}


/**
 * Bugfix für StringSubstr(string, start, length=0), die MQL-Funktion gibt für length=0 Unfug zurück.
 * Ermöglicht die Angabe negativer Werte für start und length
 *
 * @param  string object
 * @param  int    start  - wenn negativ, Startindex vom Ende des Strings
 * @param  int    length - wenn negativ, Anzahl der zurückzugebenden Zeichen links vom Startindex
 *
 * @return string
 */
string StringSubstrFix(string object, int start, int length=EMPTY_VALUE) {
   if (length == 0)
      return("");

   if (start < 0)
      start = MathMax(0, start + StringLen(object));

   if (length < 0) {
      start += 1 + length;
      length = MathAbs(length);
   }
   return(StringSubstr(object, start, length));
}


/**
 * Ersetzt in einem String alle Vorkommen eines Substrings durch einen anderen String (arbeitet nicht rekursiv).
 *
 * @param  string object  - Ausgangsstring
 * @param  string search  - Suchstring
 * @param  string replace - Ersatzstring
 *
 * @return string
 */
string StringReplace(string object, string search, string replace) {
   if (StringLen(object) == 0) return(object);
   if (StringLen(search) == 0) return(object);

   int startPos = 0;
   int foundPos = StringFind(object, search, startPos);
   if (foundPos == -1) return(object);

   string result = "";

   while (foundPos > -1) {
      result   = StringConcatenate(result, StringSubstrFix(object, startPos, foundPos-startPos), replace);
      startPos = foundPos + StringLen(search);
      foundPos = StringFind(object, search, startPos);
   }
   result = StringConcatenate(result, StringSubstr(object, startPos));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("StringReplace()", error);
      return("");
   }
   return(result);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerPrevSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   datetime serverStart   = EasternToServerTime(previousStart);
   //Print("GetServerPrevSessionStartTime()  serverTime: "+ TimeToStr(serverTime) +"   previousStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerPrevSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousEnd = GetEasternPrevSessionEndTime(easternTime);
   datetime serverEnd   = EasternToServerTime(previousEnd);
   //Print("GetServerPrevSessionEndTime()  serverTime: "+ TimeToStr(serverTime) +"   previousEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1)  return(EMPTY_VALUE);

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == -1) return(-1);

   datetime serverStart = EasternToServerTime(easternStart);
   //Print("GetServerSessionStartTime()  time: "+ TimeToStr(serverTime) +"   serverSessionStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime easternEnd = GetEasternSessionEndTime(easternTime);
   if (easternEnd == EMPTY_VALUE) return(EMPTY_VALUE);
   if (easternEnd == -1)          return(-1);

   datetime serverEnd = EasternToServerTime(easternEnd);
    //Print("GetServerSessionEndTime()  time: "+ TimeToStr(serverTime) +"   serverEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerNextSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerNextSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextStart   = GetEasternNextSessionStartTime(easternTime);
   datetime serverStart = EasternToServerTime(nextStart);
   //Print("GetServerNextSessionStartTime()  serverTime: "+ TimeToStr(serverTime) +"   nextStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerNextSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerNextSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextEnd   = GetEasternNextSessionEndTime(easternTime);
   datetime serverEnd = EasternToServerTime(nextEnd);
   //Print("GetServerNextSessionEndTime()  serverTime: "+ TimeToStr(serverTime) +"   nextEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtPrevSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtPrevSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   datetime gmtStart      = EasternToGMT(previousStart);
   //Print("GetGmtPrevSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   previousStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtPrevSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtPrevSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousEnd = GetEasternPrevSessionEndTime(easternTime);
   datetime gmtEnd      = EasternToGMT(previousEnd);
   //Print("GetGmtPrevSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   previousEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1)  return(EMPTY_VALUE);

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == -1) return(-1);

   datetime gmtStart = EasternToGMT(easternStart);
   //Print("GetGmtSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   gmtStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime easternEnd = GetEasternSessionEndTime(easternTime);
   if (easternEnd == -1)  return(-1);

   datetime gmtEnd = EasternToGMT(easternEnd);
   //Print("GetGmtSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   gmtEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtNextSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtNextSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextStart = GetEasternNextSessionStartTime(easternTime);
   datetime gmtStart  = EasternToGMT(nextStart);
   //Print("GetGmtNextSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   nextStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtNextSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtNextSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextEnd = GetEasternNextSessionEndTime(easternTime);
   datetime gmtEnd  = EasternToGMT(nextEnd);
   //Print("GetGmtNextSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   nextEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternPrevSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternPrevSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // aktuellen Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime currentStart = easternTime -(hour+7)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);    // Time -hours -7h => 17:00 am vorherigen Tag
   if (hour >= 17)
      currentStart += 1*DAY;
   datetime previousStart = currentStart - 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(previousStart);
   if      (dow == FRIDAY  ) previousStart -= 1*DAY;
   else if (dow == SATURDAY) previousStart -= 2*DAYS;
   //Print("GetEasternPrevSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   previousStart: "+ TimeToStr(previousStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(previousStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternPrevSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternPrevSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   if (previousStart == EMPTY_VALUE) return(EMPTY_VALUE);

   datetime previousEnd = previousStart + 1*DAY;
   //Print("GetEasternPrevSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   previousEnd: "+ TimeToStr(previousEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(previousEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // aktuellen Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime easternStart = easternTime + (17-hour)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);     // Time -hour +17h => 17:00
   if (hour < 17)
      easternStart -= 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(easternStart);
   if (dow == FRIDAY  ) return(-1);
   if (dow == SATURDAY) return(-1);
   //Print("GetEasternSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   sessionStart: "+ TimeToStr(easternStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(easternStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == EMPTY_VALUE) return(EMPTY_VALUE);
   if (easternStart == -1)          return(-1);

   datetime easternEnd = easternStart + 1*DAY;
   //Print("GetEasternSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   sessionEnd: "+ TimeToStr(easternEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(easternEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternNextSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternNextSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // nächsten Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime nextStart = easternTime + (17-hour)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);     // Time -hours +17h => 17:00
   if (hour >= 17)
      nextStart += 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(nextStart);
   if      (dow == FRIDAY  ) nextStart += 2*DAYS;
   else if (dow == SATURDAY) nextStart += 1*DAY;
   //Print("GetEasternNextSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   nextStart: "+ TimeToStr(nextStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(nextStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternNextSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternNextSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime nextStart = GetEasternNextSessionStartTime(easternTime);
   if (nextStart == EMPTY_VALUE) return(EMPTY_VALUE);

   datetime nextEnd = nextStart + 1*DAY;
   //Print("GetEasternNextSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   nextEnd: "+ TimeToStr(nextEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(nextEnd);
}


/**
 * Korrekter Vergleich zweier Doubles auf "Lower-Then": (double1 < double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool LT(double double1, double double2) {
   if (EQ(double1, double2))
      return(false);
   return(double1 < double2);
}


/**
 * Korrekter Vergleich zweier Doubles auf "Lower-Or-Equal": (double1 <= double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool LE(double double1, double double2) {
   if (double1 < double2)
      return(true);
   return(EQ(double1, double2));

}


/**
 * Korrekter Vergleich zweier Doubles auf Gleichheit "Equal": (double1 == double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool EQ(double double1, double double2) {
   double diff = double1 - double2;

   if (diff < 0)                             // Wir prüfen die Differenz anhand der 14. Nachkommastelle und nicht wie
      diff = -diff;                          // die Original-MetaQuotes-Funktion anhand der 8. (benutzt NormalizeDouble()).

   return(diff <= 0.00000000000001);         // siehe auch: NormalizeDouble() in MQL.doc
}


/**
 * Korrekter Vergleich zweier Doubles auf Ungleichheit "Not-Equal": (double1 != double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool NE(double double1, double double2) {
   return(!EQ(double1, double2));

}


/**
 * Korrekter Vergleich zweier Doubles auf "Greater-Or-Equal": (double1 >= double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool GE(double double1, double double2) {
   if (double1 > double2)
      return(true);
   return(EQ(double1, double2));

}


/**
 * Korrekter Vergleich zweier Doubles auf "Greater-Then": (double1 > double2)
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool
 */
bool GT(double double1, double double2) {
   if (EQ(double1, double2))
      return(false);
   return(double1 > double2);
}


/**
 * Korrekter Vergleich zweier Doubles.
 *
 * MetaQuotes-Alias für EQ()
 */
bool CompareDoubles(double double1, double double2) {
   return(EQ(double1, double2));
}


/**
 * Gibt die hexadezimale Representation eines Integers zurück.
 *
 * @param  int i - Integer
 *
 * @return string - hexadezimaler Wert
 *
 * TODO: kann keine negativen Zahlen verarbeiten (gibt 0 zurück)
 */
string DecimalToHex(int i) {
   static string hexValues = "0123456789ABCDEF";
   string result = "";

   int a = i % 16;   // a = Divisionsrest
   int b = i / 16;   // b = ganzes Vielfaches

   if (b > 15) result = StringConcatenate(DecimalToHex(b), StringSubstr(hexValues, a, 1));
   else        result = StringConcatenate(StringSubstr(hexValues, b, 1), StringSubstr(hexValues, a, 1));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("DecimalToHex()", error);
      return("");
   }
   return(result);
}


/**
 * Gibt die nächstkleinere Periode der angegebenen Periode zurück.
 *
 * @param  int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - nächstkleinere Periode oder der ursprüngliche Wert, wenn keine kleinere Periode existiert
 */
int DecreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M1 );
      case PERIOD_M5 : return(PERIOD_M1 );
      case PERIOD_M15: return(PERIOD_M5 );
      case PERIOD_M30: return(PERIOD_M15);
      case PERIOD_H1 : return(PERIOD_M30);
      case PERIOD_H4 : return(PERIOD_H1 );
      case PERIOD_D1 : return(PERIOD_H4 );
      case PERIOD_W1 : return(PERIOD_D1 );
      case PERIOD_MN1: return(PERIOD_W1 );
   }

   catch("DecreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Konvertiert einen Double in einen String und entfernt abschließende Nullstellen.
 *
 * @param  double value - Double
 *
 * @return string
 */
string DoubleToStrTrim(double value) {
   string result = value;

   int digits = MathMax(1, CountDecimals(value));  // mindestens eine Dezimalstelle wird erhalten

   if (digits < 8)
      result = StringLeft(result, digits-8);

   return(result);
}


/**
 * Konvertiert die angegebene New Yorker Zeit nach GMT (UTC).
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime EasternToGMT(datetime easternTime) {
   if (easternTime < 1) {
      catch("EasternToGMT(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);
   if (easternToGmtOffset == EMPTY_VALUE)
      return(-1);

   datetime gmtTime = easternTime - easternToGmtOffset;

   //Print("EasternToGMT()    ET: "+ TimeToStr(easternTime) +"     GMT offset: "+ (easternToGmtOffset/HOURS) +"     GMT: "+ TimeToStr(gmtTime));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EasternToGMT(2)", error);
      return(-1);
   }
   return(gmtTime);
}


/**
 * Konvertiert die angegebene New Yorker Zeit (Eastern Time) nach Tradeserver-Zeit.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime EasternToServerTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("EasternToServerTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   string zone = GetTradeServerTimezone();
   if (zone == "")
      return(-1);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "America/New_York")
      return(easternTime);

   // Offset Eastern zu GMT
   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);

   // Offset GMT zu Tradeserver
   int gmtToServerTimeOffset;
   if (zone != "GMT")
      gmtToServerTimeOffset = GetGmtToServerTimeOffset(easternTime - easternToGmtOffset);
   datetime serverTime = easternTime - easternToGmtOffset - gmtToServerTimeOffset;

   //Print("EasternToServerTime()    ET: "+ TimeToStr(easternTime) +"     server: "+ TimeToStr(serverTime));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EasternToServerTime(2)", error);
      return(-1);
   }
   return(serverTime);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein Event des angegebenen Typs aufgetreten ist.
 *
 * @param  int  event       - Event
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener(int event, int& lpResults[], int flags=0) {
   switch (event) {
      case EVENT_BAR_OPEN       : return(EventListener.BarOpen       (lpResults, flags));
      case EVENT_ORDER_PLACE    : return(EventListener.OrderPlace    (lpResults, flags));
      case EVENT_ORDER_CHANGE   : return(EventListener.OrderChange   (lpResults, flags));
      case EVENT_ORDER_CANCEL   : return(EventListener.OrderCancel   (lpResults, flags));
      case EVENT_POSITION_OPEN  : return(EventListener.PositionOpen  (lpResults, flags));
      case EVENT_POSITION_CLOSE : return(EventListener.PositionClose (lpResults, flags));
      case EVENT_ACCOUNT_CHANGE : return(EventListener.AccountChange (lpResults, flags));
      case EVENT_ACCOUNT_PAYMENT: return(EventListener.AccountPayment(lpResults, flags));
      case EVENT_HISTORY_CHANGE : return(EventListener.HistoryChange (lpResults, flags));
   }

   catch("EventListener()  invalid parameter event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(false);
}


/**
 * Prüft unabhängig von der aktuell gewählten Chartperiode, ob der aktuelle Tick im angegebenen Zeitrahmen ein BarOpen-Event auslöst.
 *
 * @param  int& lpResults[] - Zielarray für die Flags der Timeframes, in denen das Event aufgetreten ist (mehrere sind möglich)
 * @param  int  flags       - ein oder mehrere Timeframe-Flags (default: Flag der aktuellen Chartperiode)
 *
 * @return bool - Ergebnis
 */
bool EventListener.BarOpen(int& lpResults[], int flags=0) {
   ArrayResize(lpResults, 1);
   lpResults[0] = 0;

   int currentPeriodFlag = GetPeriodFlag(Period());
   if (flags == 0)
      flags = currentPeriodFlag;

   // Die aktuelle Periode wird mit einem einfachen und schnelleren Algorythmus geprüft.
   if (flags & currentPeriodFlag != 0) {
      static datetime lastOpenTime = 0;
      if (lastOpenTime != 0) if (lastOpenTime != Time[0])
         lpResults[0] |= currentPeriodFlag;
      lastOpenTime = Time[0];
   }

   // Prüfungen für andere als die aktuelle Chartperiode
   else {
      static datetime lastTick   = 0;
      static int      lastMinute = 0;

      datetime tick = MarketInfo(Symbol(), MODE_TIME);      // nur Sekundenauflösung
      int minute;

      // PERIODFLAG_M1
      if (flags & PERIODFLAG_M1 != 0) {
         if (lastTick == 0) {
            lastTick   = tick;
            lastMinute = TimeMinute(tick);
            //Print("EventListener.BarOpen(M1)   initialisiert   lastTick: ", TimeToStr(lastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", lastMinute, ")");
         }
         else if (lastTick != tick) {
            minute = TimeMinute(tick);
            if (lastMinute < minute)
               lpResults[0] |= PERIODFLAG_M1;
            //Print("EventListener.BarOpen(M1)   prüfe   alt: ", TimeToStr(lastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", lastMinute, ")   neu: ", TimeToStr(tick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", minute, ")");
            lastTick   = tick;
            lastMinute = minute;
         }
         //else Print("EventListener.BarOpen(M1)   zwei Ticks in derselben Sekunde");
      }
   }

   // TODO: verbleibende Timeframe-Flags verarbeiten
   if (false) {
      if (flags & PERIODFLAG_M5  != 0) lpResults[0] |= PERIODFLAG_M5 ;
      if (flags & PERIODFLAG_M15 != 0) lpResults[0] |= PERIODFLAG_M15;
      if (flags & PERIODFLAG_M30 != 0) lpResults[0] |= PERIODFLAG_M30;
      if (flags & PERIODFLAG_H1  != 0) lpResults[0] |= PERIODFLAG_H1 ;
      if (flags & PERIODFLAG_H4  != 0) lpResults[0] |= PERIODFLAG_H4 ;
      if (flags & PERIODFLAG_D1  != 0) lpResults[0] |= PERIODFLAG_D1 ;
      if (flags & PERIODFLAG_W1  != 0) lpResults[0] |= PERIODFLAG_W1 ;
      if (flags & PERIODFLAG_MN1 != 0) lpResults[0] |= PERIODFLAG_MN1;
   }

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.BarOpen()", error);
      return(false);
   }
   return(lpResults[0] != 0);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderChange-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderChange(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderChange()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderPlace-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderPlace(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderPlace()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderCancel-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderCancel(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderCancel()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionOpen-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int& lpTickets[] - Zielarray für Ticketnummern neu geöffneter Positionen
 * @param  int  flags       - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                            (default: 0)
 * @return bool - Ergebnis
 */
bool EventListener.PositionOpen(int& lpTickets[], int flags=0) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(lpTickets) > 0)
      ArrayResize(lpTickets, 0);

   static int      accountNumber[1];
   static datetime accountInitTime[1];                      // GMT-Zeit
   static int      knownPendings[][2];                      // die bekannten pending Orders und ihr Typ
   static int      knownPositions[];                        // die bekannten Positionen

   if (accountNumber[0] == 0) {                             // 1. Aufruf
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      //Print("EventListener.PositionOpen()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, GMT-Zeit: "+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   }
   else if (accountNumber[0] != account) {                  // Aufruf nach Accountwechsel zur Laufzeit: bekannte Positionen löschen
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      ArrayResize(knownPendings, 0);
      ArrayResize(knownPositions, 0);
      //Print("EventListener.PositionOpen()   Account "+ account +" nach Accountwechsel initialisiert, GMT-Zeit: "+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   }

   int orders = OrdersTotal();

   // pending Orders und offene Positionen überprüfen
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      int n, pendings, positions, type=OrderType(), ticket=OrderTicket();

      // pending Orders überprüfen und ggf. aktualisieren
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP) {
         pendings = ArrayRange(knownPendings, 0);
         for (n=0; n < pendings; n++)
            if (knownPendings[n][0] == ticket)              // bekannte pending Order
               break;
         if (n < pendings) continue;

         ArrayResize(knownPendings, pendings+1);            // neue (unbekannte) pending Order
         knownPendings[pendings][0] = ticket;
         knownPendings[pendings][1] = type;
         //Print("EventListener.PositionOpen()   pending order #", ticket, " added: ", OperationTypeDescription(type));
      }

      // offene Positionen überprüfen und ggf. aktualisieren
      else if (type==OP_BUY || type==OP_SELL) {
         positions = ArraySize(knownPositions);
         for (n=0; n < positions; n++)
            if (knownPositions[n] == ticket)                // bekannte Position
               break;
         if (n < positions) continue;

         // Die offenen Positionen stehen u.U. (z.B. nach Accountwechsel) erst nach einigen Ticks zur Verfügung. Daher müssen
         // neue Positionen zusätzlich anhand ihres OrderOpen-Timestamps auf ihren jeweiligen Status überprüft werden.

         // neue (unbekannte) Position: prüfen, ob sie nach Accountinitialisierung geöffnet wurde (= wirklich neu ist)
         if (accountInitTime[0] <= ServerToGMT(OrderOpenTime())) {
            // ja, in flags angegebene Orderkriterien prüfen
            int event = 1;
            pendings = ArrayRange(knownPendings, 0);

            if (flags & OFLAG_CURRENTSYMBOL != 0)   event &= (OrderSymbol()==Symbol())+0;    // MQL kann Booleans für Binärops. nicht casten
            if (flags & OFLAG_BUY           != 0)   event &= (type==OP_BUY )+0;
            if (flags & OFLAG_SELL          != 0)   event &= (type==OP_SELL)+0;
            if (flags & OFLAG_MARKETORDER   != 0) {
               for (int z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                         // Order war pending
                     break;                         event &= (z==pendings)+0;
            }
            if (flags & OFLAG_PENDINGORDER  != 0) {
               for (z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                         // Order war pending
                     break;                         event &= (z<pendings)+0;
            }

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1) {
               ArrayResize(lpTickets, ArraySize(lpTickets)+1);
               lpTickets[ArraySize(lpTickets)-1] = ticket;
            }
         }

         ArrayResize(knownPositions, positions+1);
         knownPositions[positions] = ticket;
         //Print("EventListener.PositionOpen()   position #", ticket, " added: ", OperationTypeDescription(type));
      }
   }

   bool eventStatus = (ArraySize(lpTickets) > 0);
   //Print("EventListener.PositionOpen()   eventStatus: "+ eventStatus);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.PositionOpen()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionClose-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int& lpTickets[] - Zielarray für Ticket-Nummern geschlossener Positionen
 * @param  int  flags       - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                            (default: 0)
 * @return bool - Ergebnis
 */
bool EventListener.PositionClose(int& lpTickets[], int flags=0) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(lpTickets) > 0)
      ArrayResize(lpTickets, 0);

   static int accountNumber[1];
   static int knownPositions[];                                  // bekannte Positionen
          int noOfKnownPositions = ArraySize(knownPositions);

   if (accountNumber[0] == 0) {
      accountNumber[0] = account;
      //Print("EventListener.PositionClose()   Account "+ account +" nach 1. Lib-Aufruf initialisiert");
   }
   else if (accountNumber[0] != account) {
      accountNumber[0] = account;
      ArrayResize(knownPositions, 0);
      //Print("EventListener.PositionClose()   Account "+ account +" nach Accountwechsel initialisiert");
   }
   else {
      // alle beim letzten Aufruf offenen Positionen prüfen
      for (int i=0; i < noOfKnownPositions; i++) {
         if (!OrderSelect(knownPositions[i], SELECT_BY_TICKET)) {
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            catch("EventListener.PositionClose(1)   account "+ account +" ("+ AccountNumber() +"): error selecting position #"+ knownPositions[i] +", check your History tab filter settings", error);
            // TODO: bei offenen Orders in einem Account und dem ersten Login in einen neuen Account crasht alles (erster Login dauert länger)
            return(false);
         }

         if (OrderCloseTime() > 0) {   // Position geschlossen, in flags angegebene Orderkriterien prüfen
            int    event=1, type=OrderType();
            bool   pending;
            string comment = StringToLower(StringTrim(OrderComment()));

            if      (StringStartsWith(comment, "so:" )) pending = true;                      // Margin Stopout, wie pending behandeln
            else if (StringEndsWith  (comment, "[tp]")) pending = true;
            else if (StringEndsWith  (comment, "[sl]")) pending = true;
            else if (OrderTakeProfit() > 0) {
               if      (type == OP_BUY )                        pending = (OrderClosePrice() >= OrderTakeProfit());
               else if (type == OP_SELL)                        pending = (OrderClosePrice() <= OrderTakeProfit());
            }

            if (flags & OFLAG_CURRENTSYMBOL != 0) event &= (OrderSymbol()==Symbol())+0;      // MQL kann Booleans für Binärops. nicht casten
            if (flags & OFLAG_BUY           != 0) event &= (type==OP_BUY )+0;
            if (flags & OFLAG_SELL          != 0) event &= (type==OP_SELL)+0;
            if (flags & OFLAG_MARKETORDER   != 0) event &= (!pending)+0;
            if (flags & OFLAG_PENDINGORDER  != 0) event &= ( pending)+0;

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1) {
               ArrayResize(lpTickets, ArraySize(lpTickets)+1);
               lpTickets[ArraySize(lpTickets)-1] = knownPositions[i];
            }
         }
      }
   }


   // offene Positionen jedes mal neu einlesen (löscht auch vorher gespeicherte und jetzt ggf. geschlossene Positionen)
   if (noOfKnownPositions > 0) {
      ArrayResize(knownPositions, 0);
      noOfKnownPositions = 0;
   }
   int orders = OrdersTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         noOfKnownPositions++;
         ArrayResize(knownPositions, noOfKnownPositions);
         knownPositions[noOfKnownPositions-1] = OrderTicket();
         //Print("EventListener.PositionClose()   open position #", ticket, " added: ", OperationTypeDescription(OrderType()));
      }
   }

   bool eventStatus = (ArraySize(lpTickets) > 0);
   //Print("EventListener.PositionClose()   eventStatus: "+ eventStatus);

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.PositionClose(2)", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountPayment-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.AccountPayment(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.AccountPayment()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein HistoryChange-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.HistoryChange(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.HistoryChange()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountChange-Event aufgetreten ist.
 * Beim Start des Terminals und während eines Accountwechsels treten in der Initialiserungsphase "Ticks" mit AccountNumber() == 0 auf. Diese fehlerhaften Aufrufe des Terminals
 * werden nicht als Accountwechsel im Sinne dieses Listeners interpretiert.
 *
 * @param  int& lpResults[] - eventspezifische Detailinfos: { last_account_number, current_account_number, current_account_init_servertime }
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.AccountChange(int& lpResults[], int flags=0) {
   static int accountData[3];                         // { last_account_number, current_account_number, current_account_init_servertime }

   bool eventStatus = false;
   int  account = AccountNumber();

   if (account != 0) {                                // AccountNumber() == 0 ignorieren
      if (accountData[1] == 0) {                      // 1. Lib-Aufruf
         accountData[0] = 0;
         accountData[1] = account;
         accountData[2] = GmtToServerTime(TimeGMT());
         //Print("EventListener.AccountChange()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      }
      else if (accountData[1] != account) {           // Aufruf nach Accountwechsel zur Laufzeit
         accountData[0] = accountData[1];
         accountData[1] = account;
         accountData[2] = GmtToServerTime(TimeGMT());
         //Print("EventListener.AccountChange()   Account "+ account +" nach Accountwechsel initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
         eventStatus = true;
      }
   }
   //Print("EventListener.AccountChange()   eventStatus: "+ eventStatus);

   if (ArraySize(lpResults) != 3)
      ArrayResize(lpResults, 3);
   ArrayCopy(lpResults, accountData);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.AccountChange()", error);
      return(false);
   }
   return(eventStatus);
}


double EventTracker.bandLimits[3];


/**
 * Gibt die aktuellen BollingerBand-Limite des EventTrackers zurück (aus Performancegründen sind sie timeframe-übergreifend
 * in der Library gespeichert).
 *
 * @param  double& lpResults[3] - Zeiger auf Array für die Ergebnisse { UPPER_VALUE, MA_VALUE, LOWER_VALUE }
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die Daten erfolgreich gelesen wurden,
 *                               FALSE bei nicht existierenden Daten
 */
bool EventTracker.GetBandLimits(double& lpResults[]) {
   lpResults[0] = EventTracker.bandLimits[0];
   lpResults[1] = EventTracker.bandLimits[1];
   lpResults[2] = EventTracker.bandLimits[2];

   if (EventTracker.bandLimits[0]!=0) /*&&*/ if (EventTracker.bandLimits[1]!=0) /*&&*/ if (EventTracker.bandLimits[2]!=0)
      return(true);
   return(false);
}


/**
 * Setzt die aktuellen BollingerBand-Limite des EventTrackers (aus Performancegründen sind sie timeframe-übergreifend
 * in der Library gespeichert).
 *
 * @param  double& lpLimits[3] - Array mit den aktuellen Limiten { UPPER_VALUE, MA_VALUE, LOWER_VALUE }
 *
 * @return int - Fehlerstatus
 */
int EventTracker.SetBandLimits(double& lpLimits[]) {
   EventTracker.bandLimits[0] = lpLimits[0];
   EventTracker.bandLimits[1] = lpLimits[1];
   EventTracker.bandLimits[2] = lpLimits[2];
   return(0);
}


double EventTracker.gridLimit.High,       // sind Timeframe-übergreifend gespeichert
       EventTracker.gridLimit.Low;


/**
 * Gibt die in der Library gespeicherten Grid-Limite des EventTrackers zurück.
 *
 * @param  double& lpLimits[2] - Zeiger auf Array für die zu speichernden Limite { LOWER_LIMIT, UPPER_LIMIT }
 *
 * @return bool - TRUE, wenn Daten in der Library gespeichert waren; FALSE andererseits
 */
bool EventTracker.GetGridLimits(double& lpLimits[]) {
   if (ArraySize(lpLimits) != 2)
      return(catch("EventTracker.GetGridLimits()   illegal parameter limits = "+ DoubleArrayToStr(lpLimits), ERR_INCOMPATIBLE_ARRAYS));

   if (EQ(EventTracker.gridLimit.High, 0)) return(false);
   if (EQ(EventTracker.gridLimit.Low , 0)) return(false);

   lpLimits[0] = EventTracker.gridLimit.Low;
   lpLimits[1] = EventTracker.gridLimit.High;

   return(true);
}


/**
 * Speichert die übergebenen Grid-Limite des EventTrackers in der Library (timeframe-übergreifend).
 *
 * @param  double upperLimit - oberes Limit
 * @param  double lowerLimit - unteres Limit
 *
 * @return int - Fehlerstatus
 */
int EventTracker.SaveGridLimits(double upperLimit, double lowerLimit) {
   if (EQ(upperLimit, 0)) return(catch("EventTracker.SaveGridLimits()  illegal parameter upperLimit = "+ upperLimit, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (EQ(lowerLimit, 0)) return(catch("EventTracker.SaveGridLimits()  illegal parameter lowerLimit = "+ lowerLimit, ERR_INVALID_FUNCTION_PARAMVALUE));

   EventTracker.gridLimit.High = upperLimit;
   EventTracker.gridLimit.Low  = lowerLimit;

   return(0);
}


/**
 * Zerlegt einen String in Teilstrings.
 *
 * @param  string  object      - zu zerlegender String
 * @param  string  separator   - Trennstring
 * @param  string& lpResults[] - Zielarray für die Teilstrings
 * @param  int     limit       - maximale Anzahl von Teilstrings (default: kein Limit)
 *
 * @return int - Anzahl der Teilstrings oder -1, wennn ein Fehler auftrat
 */
int Explode(string object, string separator, string& lpResults[], int limit=NULL) {
   int lenObject    = StringLen(object),
       lenSeparator = StringLen(separator);

   if (lenObject == 0) {                     // Leerstring
      ArrayResize(lpResults, 1);
      lpResults[0] = object;
   }
   else if (separator == "") {               // String in einzelne Zeichen zerlegen
      if (limit==NULL || limit > lenObject)
         limit = lenObject;
      ArrayResize(lpResults, limit);

      for (int i=0; i < limit; i++) {
         lpResults[i] = StringSubstr(object, i, 1);
      }
   }
   else {                                    // String in Substrings zerlegen
      int size, pos;
      i = 0;

      while (i < lenObject) {
         ArrayResize(lpResults, size+1);

         pos = StringFind(object, separator, i);
         if (limit == size+1)
            pos = -1;
         if (pos == -1) {
            lpResults[size] = StringSubstr(object, i);
            break;
         }
         else if (pos == i) {
            lpResults[size] = "";
         }
         else {
            lpResults[size] = StringSubstrFix(object, i, pos-i);
         }
         size++;
         i = pos + lenSeparator;
      }

      if (i == lenObject) {                  // bei abschließendem Separator Substrings mit Leerstring beenden
         ArrayResize(lpResults, size+1);
         lpResults[size] = "";               // TODO: !!! Wechselwirkung zwischen Limit und Separator am Ende überprüfen
      }
   }

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("Explode()", error);
      return(-1);
   }
   return(ArraySize(lpResults));
}


/**
 * Liest die History eines Accounts aus dem Dateisystem in das angegebene Array ein (Daten werden als Strings gespeichert).
 *
 * @param  int     account                      - Account-Nummer
 * @param  string& lpResults[][HISTORY_COLUMNS] - Zeiger auf Ergebnisarray
 *
 * @return int - Fehlerstatus
 */
int GetAccountHistory(int account, string& lpResults[][HISTORY_COLUMNS]) {
   if (ArrayRange(lpResults, 1) != HISTORY_COLUMNS)
      return(catch("GetAccountHistory(1)   invalid parameter lpResults["+ ArrayRange(lpResults, 0) +"]["+ ArrayRange(lpResults, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int    cache.account[1];
   string cache[][HISTORY_COLUMNS];

   ArrayResize(lpResults, 0);

   // Daten nach Möglichkeit aus dem Cache liefern
   if (cache.account[0] == account) {
      ArrayCopy(lpResults, cache);
      log("GetAccountHistory()   delivering "+ ArrayRange(cache, 0) +" history entries for account "+ account +" from cache");
      return(catch("GetAccountHistory(2)"));
   }

   // Cache-Miss, History-Datei auslesen
   string header[HISTORY_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment" };

   string filename = GetShortAccountCompany() +"/"+ account + "_account_history.csv";
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (hFile < 0) {
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE)
         return(error);
      return(catch("GetAccountHistory(3)   FileOpen(\""+ filename +"\")", error));
   }

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true;
   int    lines=0, row=-2, col=-1;
   string result[][HISTORY_COLUMNS]; ArrayResize(result, 0);   // tmp. Zwischenspeicher für ausgelesene Daten

   // Daten feldweise einlesen und Zeilen erkennen
   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                           // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                     // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
         col = -1;                                             // Spaltenindex vor der ersten Spalte (erste Spalte = 0)
      }

      // nächstes Feld auslesen
      value = FileReadString(hFile);

      // auf Leerzeilen, Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                        // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                               // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
            }
         }
         lines++;
      }

      // Leerzeilen überspringen
      if (blankLine)
         continue;

      value = StringTrim(value);

      // Kommentarzeilen überspringen
      if (newLine) /*&&*/ if (StringGetChar(value, 0)=='#')
         continue;

      // Zeilen- und Spaltenindex aktualisieren und Bereich überprüfen
      col++;
      if (lineEnd) /*&&*/ if (col!=HISTORY_COLUMNS-1) {
         error = catch("GetAccountHistory(4)   data format error in \""+ filename +"\", column count in line "+ lines +" is not "+ HISTORY_COLUMNS, ERR_RUNTIME_ERROR);
         break;
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            error = catch("GetAccountHistory(5)   data format error in \""+ filename +"\", unexpected column header \""+ value +"\"", ERR_RUNTIME_ERROR);
            break;
         }
         continue;            // jmp
      }

      // Ergebnisarray vergrößern und Rohdaten speichern (als String)
      if (newLine)
         ArrayResize(result, row+1);
      result[row][col] = value;
   }

   // Hier hat entweder ein Formatfehler ERR_RUNTIME_ERROR (bereits gemeldet) oder das Dateiende END_OF_FILE ausgelöst.
   if (error == NO_ERROR) {
      error = GetLastError();
      if (error == ERR_END_OF_FILE) {
         error = NO_ERROR;
      }
      else {
         catch("GetAccountHistory(6)", error);
      }
   }

   // vor evt. Fehler-Rückkehr auf jeden Fall Datei schließen
   FileClose(hFile);

   if (error != NO_ERROR)     // ret
      return(error);


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) > 0) {       // "leere" Historydaten nicht cachen (falls Datei noch erstellt wird)
      ArrayCopy(lpResults, result);

      cache.account[0] = account;
      ArrayResize(cache, 0);
      ArrayCopy(cache, result);
      //log("GetAccountHistory()   caching "+ ArrayRange(cache, 0) +" history entries for account "+ account);
   }

   return(catch("GetAccountHistory(7)"));
}


/**
 * Gibt die aktuelle Account-Nummer zurück (unabhängig von einer Connection zum Tradeserver).
 *
 * @return int - Account-Nummer (positiver Wert) oder 0, falls ein Fehler aufgetreten ist.
 *
 *
 * NOTE:
 * ----
 * Während des Terminalstarts kann der Fehler ERR_TERMINAL_NOT_YET_READY auftreten.
 */
int GetAccountNumber() {
   int account = AccountNumber();

   if (account == 0) {                                // ohne Connection Titelzeile des Hauptfensters auswerten
      string title = GetWindowText(GetTerminalWindow());
      if (title == "") {
         last_error = ERR_TERMINAL_NOT_YET_READY;
         return(0);
      }

      int pos = StringFind(title, ":");
      if (pos < 1) {
         catch("GetAccountNumber(1)   account number separator not found in top window title \""+ title +"\"", ERR_RUNTIME_ERROR);
         return(0);
      }

      string strAccount = StringLeft(title, pos);
      if (!StringIsDigit(strAccount)) {
         catch("GetAccountNumber(2)   account number in top window title contains non-digit characters: "+ strAccount, ERR_RUNTIME_ERROR);
         return(0);
      }

      account = StrToInteger(strAccount);
   }

   if (catch("GetAccountNumber(3)") != NO_ERROR)
      return(0);
   return(account);
}


/**
 * Gibt den durchschnittlichen Spread des angegebenen Instruments zurück.
 *
 * @param  string symbol - Instrument
 *
 * @return double - Spread
 */
double GetAverageSpread(string symbol) {
   if      (symbol == "EURUSD") return(0.0001 );
   else if (symbol == "GBPJPY") return(0.05   );
   else if (symbol == "GBPCHF") return(0.0004 );
   else if (symbol == "GBPUSD") return(0.00012);
   else if (symbol == "USDCAD") return(0.0002 );
   else if (symbol == "USDCHF") return(0.0001 );

   //spread = MarketInfo(symbol, MODE_POINT) * MarketInfo(symbol, MODE_SPREAD); // aktueller Spread in Points
   catch("GetAverageSpread()  average spread for "+ symbol +" not found", ERR_UNKNOWN_SYMBOL);
   return(0);
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Ergebnisarrays (aufsteigend nach Zeitpunkt sortiert).
 *
 * @param  int       account    - Account-Nummer
 * @param  datetime& lpTimes[]  - Zeiger auf Ergebnisarray für die Zeitpunkte der Balanceänderung
 * @param  double&   lpValues[] - Zeiger auf Ergebnisarray der entsprechenden Balancewerte
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime& lpTimes[], double& lpValues[]) {
   int      cache.account[1];
   datetime cache.times[];
   double   cache.values[];

   ArrayResize(lpTimes,  0);
   ArrayResize(lpValues, 0);

   // Daten nach Möglichkeit aus dem Cache liefern       TODO: paralleles Cachen mehrerer Wertereihen ermöglichen
   if (cache.account[0] == account) {
      /**
       * TODO: Fehler tritt nach Neustart auf, wenn Balance-Indikator geladen ist und AccountNumber() noch 0 zurückgibt
       *
       * stdlib: Error: incorrect start position 0 for ArrayCopy function
       * stdlib: Log:   Balance::stdlib::GetBalanceHistory()   delivering 0 balance values for account 0 from cache
       * stdlib: Alert: ERROR:   AUDUSD,M15::Balance::stdlib::GetBalanceHistory(1)  [4051 - invalid function parameter value]
       */
      ArrayCopy(lpTimes , cache.times);
      ArrayCopy(lpValues, cache.values);
      log("GetBalanceHistory()   delivering "+ ArraySize(cache.times) +" balance values for account "+ account +" from cache");
      return(catch("GetBalanceHistory(1)"));
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (error == ERR_CANNOT_OPEN_FILE) return(catch("GetBalanceHistory(2)", error));
   if (error != NO_ERROR            ) return(catch("GetBalanceHistory(3)"));

   // Balancedatensätze einlesen und auswerten (History ist nach CloseTime sortiert)
   datetime time, lastTime;
   double   balance, lastBalance;
   int n, size=ArrayRange(data, 0);

   if (size == 0)
      return(catch("GetBalanceHistory(4)"));

   for (int i=0; i<size; i++) {
      balance = StrToDouble (data[i][AH_BALANCE       ]);
      time    = StrToInteger(data[i][AH_CLOSETIMESTAMP]);

      // der erste Datensatz wird immer geschrieben...
      if (i == 0) {
         ArrayResize(lpTimes,  n+1);
         ArrayResize(lpValues, n+1);
         lpTimes [n] = time;
         lpValues[n] = balance;
         n++;                                // n: Anzahl der existierenden Ergebnisdaten => ArraySize(lpTimes)
      }
      else if (balance != lastBalance) {
         // ... alle weiteren nur, wenn die Balance sich geändert hat
         if (time == lastTime) {             // Existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            lpValues[n-1] = balance;         // wird der letzte Wert nur mit dem aktuellen überschrieben.
         }
         else {
            ArrayResize(lpTimes,  n+1);
            ArrayResize(lpValues, n+1);
            lpTimes [n] = time;
            lpValues[n] = balance;
            n++;
         }
      }
      lastTime    = time;
      lastBalance = balance;
   }

   // Daten cachen
   cache.account[0] = account;
   ArrayResize(cache.times,  0); ArrayCopy(cache.times,  lpTimes );
   ArrayResize(cache.values, 0); ArrayCopy(cache.values, lpValues);
   log("GetBalanceHistory()   caching "+ ArraySize(lpTimes) +" balance values for account "+ account);

   return(catch("GetBalanceHistory(5)"));
}


/**
 * Gibt den Rechnernamen des laufenden Systems zurück.
 *
 * @return string - Name
 */
string GetComputerName() {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // Zeigerproblematik (siehe MetaTrader.doc)
   int lpBufferSize[1]; lpBufferSize[0] = StringLen(buffer[0]);

   if (!GetComputerNameA(buffer[0], lpBufferSize)) {
      catch("GetComputerName(1)   kernel32::GetComputerName(buffer, "+ lpBufferSize[0] +") = FALSE", ERR_WINDOWS_ERROR);
      return("");
   }

   if (catch("GetComputerName(2)") != NO_ERROR)
      return("");
   return(buffer[0]);
}


/**
 * Gibt einen Konfigurationswert als Boolean zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetConfigBool(string section, string key, bool defaultValue=false) {
   string strDefault = defaultValue;
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // Zeigerproblematik (siehe MetaTrader.doc)
   int bufferSize = StringLen(buffer[0]);

   // zuerst globale, dann lokale Config auslesen                             // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, strDefault, buffer[0], bufferSize, GetGlobalConfigPath());
   GetPrivateProfileStringA(section, key, buffer[0] , buffer[0], bufferSize, GetLocalConfigPath());

   buffer[0] = StringToLower(buffer[0]);
   bool result = true;

   if (buffer[0]!="1") /*&&*/ if (buffer[0]!="true") /*&&*/ if (buffer[0]!="yes") /*&&*/ if (buffer[0]!="on") {
      result = false;
   }

   if (catch("GetConfigBool()") != NO_ERROR)
      return(false);
   return(result);
}


/**
 * Gibt einen Konfigurationswert als Double zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetConfigDouble(string section, string key, double defaultValue=0) {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // Zeigerproblematik (siehe MetaTrader.doc)
   int bufferSize = StringLen(buffer[0]);

   // zuerst globale, dann lokale Config auslesen                             // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], bufferSize, GetGlobalConfigPath());
   GetPrivateProfileStringA(section, key, buffer[0]                   , buffer[0], bufferSize, GetLocalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (catch("GetConfigDouble()") != NO_ERROR)
      return(0);
   return(result);
}


/**
 * Gibt einen Konfigurationswert als Integer zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetConfigInt(string section, string key, int defaultValue=0) {
   // zuerst globale, dann lokale Config auslesen
   int result = GetPrivateProfileIntA(section, key, defaultValue, GetGlobalConfigPath());    // gibt auch negative Werte richtig zurück
       result = GetPrivateProfileIntA(section, key, result      , GetLocalConfigPath());

   if (catch("GetConfigInt()") != NO_ERROR)
      return(0);
   return(result);
}


/**
 * Gibt einen Konfigurationswert als String zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetConfigString(string section, string key, string defaultValue="") {
   // zuerst globale, dann lokale Config auslesen
   string value = GetPrivateProfileString(GetGlobalConfigPath(), section, key, defaultValue);
          value = GetPrivateProfileString(GetLocalConfigPath() , section, key, value       );

   return(value);
}


/**
 * Gibt den Offset der angegebenen New Yorker Zeit (Eastern Time) zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetEasternToGmtOffset(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternToGmtOffset(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(easternTime)-1970;

   // New York                                      GMT-0500,GMT-0400
   if      (easternTime < EDT_transitions[year][0]) offset = -5 * HOURS;
   else if (easternTime < EDT_transitions[year][1]) offset = -4 * HOURS;
   else                                             offset = -5 * HOURS;

   if (catch("GetEasternToGmtOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);
   return(offset);
}


/**
 * Gibt den Offset der angegebenen New Yorker Zeit (Eastern Time) zu Tradeserver-Zeit zurück.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetEasternToServerTimeOffset(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternToServerTimeOffset(1)   invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetTradeServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "America/New_York")
      return(0);

   // Offset Eastern zu GMT
   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);

   // Offset GMT zu Tradeserver
   int gmtToServerTimeOffset;
   if (zone != "GMT")
      gmtToServerTimeOffset = GetGmtToServerTimeOffset(easternTime - easternToGmtOffset);

   if (catch("GetEasternToServerTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(easternToGmtOffset + gmtToServerTimeOffset);
}


/**
 * Gibt einen globalen Konfigurationswert als Boolean zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue=false) {
   string strDefault = defaultValue;
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)
                                                                                 // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, strDefault, buffer[0], StringLen(buffer[0]), GetGlobalConfigPath());

   buffer[0] = StringToLower(buffer[0]);
   bool result = true;

   if (buffer[0]!="1") /*&&*/ if (buffer[0]!="true") /*&&*/ if (buffer[0]!="yes") /*&&*/ if (buffer[0]!="on") {
      result = false;
   }

   if (catch("GetGlobalConfigBool()") != NO_ERROR)
      return(false);
   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als Double zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetGlobalConfigDouble(string section, string key, double defaultValue=0) {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)
                                                                                 // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], StringLen(buffer[0]), GetGlobalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (catch("GetGlobalConfigDouble()") != NO_ERROR)
      return(0);
   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als Integer zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetGlobalConfigInt(string section, string key, int defaultValue=0) {
   int result = GetPrivateProfileIntA(section, key, defaultValue, GetGlobalConfigPath());    // gibt auch negative Werte richtig zurück

   if (catch("GetGlobalConfigInt()") != NO_ERROR)
      return(0);
   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als String zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetGlobalConfigString(string section, string key, string defaultValue="") {
   return(GetPrivateProfileString(GetGlobalConfigPath(), section, key, defaultValue));
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zu New Yorker Zeit (Eastern Time) zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 *
 * NOTE:    Parameter ist ein GMT-Zeitpunkt, das Ergebnis ist daher der entgegengesetzte Wert des Offsets von Eastern Time zu GMT.
 * -----
 */
int GetGmtToEasternTimeOffset(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtToEasternTimeOffset(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(gmtTime)-1970;

   // New York                                  GMT-0500[,GMT-0400]
   if      (gmtTime < EDT_transitions[year][2]) offset = 5 * HOURS;
   else if (gmtTime < EDT_transitions[year][3]) offset = 4 * HOURS;
   else                                         offset = 5 * HOURS;

   if (catch("GetGmtToEasternTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zur Tradeserver-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 *
 * NOTE:    Parameter ist ein GMT-Zeitpunkt, das Ergebnis ist daher der entgegengesetzte Wert des Offsets von Tradeserver-Zeit zu GMT.
 * -----
 */
int GetGmtToServerTimeOffset(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtToServerTimeOffset(1)   invalid parameter gmtTime = "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string timezone = GetTradeServerTimezone();
   if (timezone == "")
      return(EMPTY_VALUE);
   int offset, year = TimeYear(gmtTime)-1970;

   if (timezone == "Europe/Kiev") {              // GMT+0200,GMT+0300
      if      (gmtTime < EEST_transitions[year][2]) offset = -2 * HOURS;
      else if (gmtTime < EEST_transitions[year][3]) offset = -3 * HOURS;
      else                                          offset = -2 * HOURS;
   }

   else if (timezone == "Europe/Berlin") {       // GMT+0100,GMT+0200
      if      (gmtTime < CEST_transitions[year][2]) offset = -1 * HOUR;
      else if (gmtTime < CEST_transitions[year][3]) offset = -2 * HOURS;
      else                                          offset = -1 * HOUR;
   }
                                                 // GMT+0000
   else if (timezone == "GMT")                      offset =  0;

   else if (timezone == "Europe/London") {       // GMT+0000,GMT+0100
      if      (gmtTime < BST_transitions[year][2])  offset =  0;
      else if (gmtTime < BST_transitions[year][3])  offset = -1 * HOUR;
      else                                          offset =  0;
   }

   else if (timezone == "America/New_York") {    // GMT-0500,GMT-0400
      if      (gmtTime < EDT_transitions[year][2])  offset = 5 * HOURS;
      else if (gmtTime < EDT_transitions[year][3])  offset = 4 * HOURS;
      else                                          offset = 5 * HOURS;
   }

   else {
      catch("GetGmtToServerTimeOffset(2)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG);
      return(EMPTY_VALUE);
   }

   if (catch("GetGmtToServerTimeOffset(3)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


/**
 * Gibt einen Wert des angegebenen Abschnitts einer .ini-Datei als String zurück.
 *
 * @param  string fileName     - Name der .ini-Datei
 * @param  string section      - Abschnittsname
 * @param  string key          - Schlüsselname
 * @param  string defaultValue - Rückgabewert, falls kein Wert gefunden wurde
 *
 * @return string
 */
string GetPrivateProfileString(string fileName, string section, string key, string defaultValue="") {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)
   int bufferSize = StringLen(buffer[0]);

   int result = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (result == bufferSize-1) {
      buffer[0]  = StringConcatenate(buffer[0], MAX_STRING_LITERAL);
      bufferSize = StringLen(buffer[0]);
      result     = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);
   }

   if (catch("GetPrivateProfileString()") != NO_ERROR)
      return("");
   return(buffer[0]);
}


/**
 * Gibt einen lokalen Konfigurationswert als Boolean zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue=false) {
   string strDefault = defaultValue;
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)
                                                                                 // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, strDefault, buffer[0], StringLen(buffer[0]), GetLocalConfigPath());

   buffer[0] = StringToLower(buffer[0]);
   bool result = true;

   if (buffer[0]!="1") /*&&*/ if (buffer[0]!="true") /*&&*/ if (buffer[0]!="yes") /*&&*/ if (buffer[0]!="on") {
      result = false;
   }

   if (catch("GetLocalConfigBool()") != NO_ERROR)
      return(false);
   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als Double zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetLocalConfigDouble(string section, string key, double defaultValue=0) {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)
                                                                                 // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], StringLen(buffer[0]), GetLocalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (catch("GetLocalConfigDouble()") != NO_ERROR)
      return(0);
   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als Integer zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetLocalConfigInt(string section, string key, int defaultValue=0) {
   int result = GetPrivateProfileIntA(section, key, defaultValue, GetLocalConfigPath());     // gibt auch negative Werte richtig zurück

   if (catch("GetLocalConfigInt()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als String zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetLocalConfigString(string section, string key, string defaultValue="") {
   return(GetPrivateProfileString(GetLocalConfigPath(), section, key, defaultValue));
}


/**
 * Gibt den Wochentag des angegebenen Zeitpunkts zurück.
 *
 * @param  datetime time - Zeitpunkt
 * @param  bool     long - TRUE, um die Langform zurückzugeben (default)
 *                         FALSE, um die Kurzform zurückzugeben
 *
 * @return string - Wochentag
 */
string GetDayOfWeek(datetime time, bool long=true) {
   if (time < 1) {
      catch("GetDayOfWeek(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   static string weekDays[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};

   string day = weekDays[TimeDayOfWeek(time)];

   if (!long)
      day = StringSubstr(day, 0, 3);

   return(day);
}


/**
 * Gibt die Beschreibung eines MQL-Fehlercodes zurück.
 *
 * @param  int error - MQL-Fehlercode
 *
 * @return string
 */
string ErrorDescription(int error) {
   switch (error) {
      case NO_ERROR                       : return("no error"                                                      ); //    0

      // trade server errors
      case ERR_NO_RESULT                  : return("no result"                                                     ); //    1
      case ERR_COMMON_ERROR               : return("common error"                                                  ); //    2    manual confirmation was denied
      case ERR_INVALID_TRADE_PARAMETERS   : return("invalid trade parameters"                                      ); //    3
      case ERR_SERVER_BUSY                : return("trade server is busy"                                          ); //    4
      case ERR_OLD_VERSION                : return("old version of client terminal"                                ); //    5
      case ERR_NO_CONNECTION              : return("no connection to trade server"                                 ); //    6
      case ERR_NOT_ENOUGH_RIGHTS          : return("not enough rights"                                             ); //    7
      case ERR_TOO_FREQUENT_REQUESTS      : return("too frequent requests"                                         ); //    8
      case ERR_MALFUNCTIONAL_TRADE        : return("malfunctional trade operation"                                 ); //    9    never returned error
      case ERR_ACCOUNT_DISABLED           : return("account disabled"                                              ); //   64
      case ERR_INVALID_ACCOUNT            : return("invalid account"                                               ); //   65
      case ERR_TRADE_TIMEOUT              : return("trade timeout"                                                 ); //  128
      case ERR_INVALID_PRICE              : return("invalid price"                                                 ); //  129
      case ERR_INVALID_STOPS              : return("invalid stop"                                                  ); //  130
      case ERR_INVALID_TRADE_VOLUME       : return("invalid trade volume"                                          ); //  131
      case ERR_MARKET_CLOSED              : return("market is closed"                                              ); //  132
      case ERR_TRADE_DISABLED             : return("trading is disabled"                                           ); //  133
      case ERR_NOT_ENOUGH_MONEY           : return("not enough money"                                              ); //  134
      case ERR_PRICE_CHANGED              : return("price changed"                                                 ); //  135
      case ERR_OFF_QUOTES                 : return("off quotes"                                                    ); //  136
      case ERR_BROKER_BUSY                : return("broker is busy (never returned error)"                         ); //  137
      case ERR_REQUOTE                    : return("requote"                                                       ); //  138
      case ERR_ORDER_LOCKED               : return("order is locked"                                               ); //  139
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("long positions only allowed"                                   ); //  140
      case ERR_TOO_MANY_REQUESTS          : return("too many requests"                                             ); //  141
      case ERR_TRADE_MODIFY_DENIED        : return("modification denied because too close to market"               ); //  145
      case ERR_TRADE_CONTEXT_BUSY         : return("trade context is busy"                                         ); //  146
      case ERR_TRADE_EXPIRATION_DENIED    : return("expiration settings denied by broker"                          ); //  147
      case ERR_TRADE_TOO_MANY_ORDERS      : return("number of open and pending orders has reached the broker limit"); //  148
      case ERR_TRADE_HEDGE_PROHIBITED     : return("hedging prohibited"                                            ); //  149
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("prohibited by FIFO rules"                                      ); //  150

      // runtime errors
      case ERR_RUNTIME_ERROR              : return("runtime error"                                                 ); // 4000    common runtime error (no mql error)
      case ERR_WRONG_FUNCTION_POINTER     : return("wrong function pointer"                                        ); // 4001
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("array index out of range"                                      ); // 4002
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("no memory for function call stack"                             ); // 4003
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("recursive stack overflow"                                      ); // 4004
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("not enough stack for parameter"                                ); // 4005
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("no memory for parameter string"                                ); // 4006
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("no memory for temp string"                                     ); // 4007
      case ERR_NOT_INITIALIZED_STRING     : return("not initialized string"                                        ); // 4008
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("not initialized string in array"                               ); // 4009
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("no memory for string in array"                                 ); // 4010
      case ERR_TOO_LONG_STRING            : return("string too long"                                               ); // 4011
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("remainder from division by zero"                               ); // 4012
      case ERR_ZERO_DIVIDE                : return("division by zero"                                              ); // 4013
      case ERR_UNKNOWN_COMMAND            : return("unknown command"                                               ); // 4014
      case ERR_WRONG_JUMP                 : return("wrong jump (never generated error)"                            ); // 4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("array not initialized"                                         ); // 4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("DLL calls are not allowed"                                     ); // 4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("cannot load library"                                           ); // 4018
      case ERR_CANNOT_CALL_FUNCTION       : return("cannot call function"                                          ); // 4019
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("expert function calls are not allowed"                         ); // 4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("not enough memory for temp string returned from function"      ); // 4021
      case ERR_SYSTEM_BUSY                : return("system busy"                                                   ); // 4022    never generated error
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("invalid function parameter count"                              ); // 4050    invalid parameters count
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("invalid function parameter value"                              ); // 4051    invalid parameter value
      case ERR_STRING_FUNCTION_INTERNAL   : return("string function internal error"                                ); // 4052
      case ERR_SOME_ARRAY_ERROR           : return("array error"                                                   ); // 4053    some array error
      case ERR_INCORRECT_SERIESARRAY_USING: return("incorrect series array using"                                  ); // 4054
      case ERR_CUSTOM_INDICATOR_ERROR     : return("custom indicator error"                                        ); // 4055    custom indicator error
      case ERR_INCOMPATIBLE_ARRAYS        : return("incompatible arrays"                                           ); // 4056    incompatible arrays
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                             ); // 4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                                     ); // 4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTING: return("function not allowed in test mode"                             ); // 4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                        ); // 4060
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                               ); // 4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                                     ); // 4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                                    ); // 4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                                     ); // 4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                      ); // 4065
      case ERR_HISTORY_UPDATE             : return("requested history data in update state"                        ); // 4066    history in update state
      case ERR_TRADE_ERROR                : return("error in trading function"                                     ); // 4067    error in trading function
      case ERR_END_OF_FILE                : return("end of file"                                                   ); // 4099    end of file
      case ERR_SOME_FILE_ERROR            : return("file error"                                                    ); // 4100    some file error
      case ERR_WRONG_FILE_NAME            : return("wrong file name"                                               ); // 4101
      case ERR_TOO_MANY_OPENED_FILES      : return("too many opened files"                                         ); // 4102
      case ERR_CANNOT_OPEN_FILE           : return("cannot open file"                                              ); // 4103
      case ERR_INCOMPATIBLE_FILEACCESS    : return("incompatible file access"                                      ); // 4104
      case ERR_NO_ORDER_SELECTED          : return("no order selected"                                             ); // 4105
      case ERR_UNKNOWN_SYMBOL             : return("unknown symbol"                                                ); // 4106
      case ERR_INVALID_PRICE_PARAM        : return("invalid price parameter for trade function"                    ); // 4107
      case ERR_INVALID_TICKET             : return("invalid ticket"                                                ); // 4108
      case ERR_TRADE_NOT_ALLOWED          : return("live trading is not enabled"                                   ); // 4109
      case ERR_LONGS_NOT_ALLOWED          : return("long trades are not enabled"                                   ); // 4110
      case ERR_SHORTS_NOT_ALLOWED         : return("short trades are not enabled"                                  ); // 4111
      case ERR_OBJECT_ALREADY_EXISTS      : return("object already exists"                                         ); // 4200
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("unknown object property"                                       ); // 4201
      case ERR_OBJECT_DOES_NOT_EXIST      : return("object doesn't exist"                                          ); // 4202
      case ERR_UNKNOWN_OBJECT_TYPE        : return("unknown object type"                                           ); // 4203
      case ERR_NO_OBJECT_NAME             : return("no object name"                                                ); // 4204
      case ERR_OBJECT_COORDINATES_ERROR   : return("object coordinates error"                                      ); // 4205
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("no specified subwindow"                                        ); // 4206
      case ERR_SOME_OBJECT_ERROR          : return("object error"                                                  ); // 4207

      // custom errors
      case ERR_WINDOWS_ERROR              : return("Windows error"                                                 ); // 5000
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("function not implemented"                                      ); // 5001
      case ERR_INVALID_INPUT_PARAMVALUE   : return("invalid input parameter value"                                 ); // 5002
      case ERR_INVALID_CONFIG_PARAMVALUE  : return("invalid configuration parameter value"                         ); // 5003
      case ERR_TERMINAL_NOT_YET_READY     : return("terminal not yet ready"                                        ); // 5004
      case ERR_INVALID_TIMEZONE_CONFIG    : return("invalid or missing timezone configuration"                     ); // 5005
      case ERR_MARKETINFO_UPDATE          : return("requested market info data in update state"                    ); // 5006
      case ERR_FILE_NOT_FOUND             : return("file not found"                                                ); // 5007
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Konstante eines MQL-Fehlercodes zurück.
 *
 * @param  int error - MQL-Fehlercode
 *
 * @return string
 */
string ErrorToStr(int error) {
   switch (error) {
      case NO_ERROR                       : return("NO_ERROR"                       ); //    0

      // trade server errors
      case ERR_NO_RESULT                  : return("ERR_NO_RESULT"                  ); //    1
      case ERR_COMMON_ERROR               : return("ERR_COMMON_ERROR"               ); //    2
      case ERR_INVALID_TRADE_PARAMETERS   : return("ERR_INVALID_TRADE_PARAMETERS"   ); //    3
      case ERR_SERVER_BUSY                : return("ERR_SERVER_BUSY"                ); //    4
      case ERR_OLD_VERSION                : return("ERR_OLD_VERSION"                ); //    5
      case ERR_NO_CONNECTION              : return("ERR_NO_CONNECTION"              ); //    6
      case ERR_NOT_ENOUGH_RIGHTS          : return("ERR_NOT_ENOUGH_RIGHTS"          ); //    7
      case ERR_TOO_FREQUENT_REQUESTS      : return("ERR_TOO_FREQUENT_REQUESTS"      ); //    8
      case ERR_MALFUNCTIONAL_TRADE        : return("ERR_MALFUNCTIONAL_TRADE"        ); //    9
      case ERR_ACCOUNT_DISABLED           : return("ERR_ACCOUNT_DISABLED"           ); //   64
      case ERR_INVALID_ACCOUNT            : return("ERR_INVALID_ACCOUNT"            ); //   65
      case ERR_TRADE_TIMEOUT              : return("ERR_TRADE_TIMEOUT"              ); //  128
      case ERR_INVALID_PRICE              : return("ERR_INVALID_PRICE"              ); //  129
      case ERR_INVALID_STOPS              : return("ERR_INVALID_STOPS"              ); //  130
      case ERR_INVALID_TRADE_VOLUME       : return("ERR_INVALID_TRADE_VOLUME"       ); //  131
      case ERR_MARKET_CLOSED              : return("ERR_MARKET_CLOSED"              ); //  132
      case ERR_TRADE_DISABLED             : return("ERR_TRADE_DISABLED"             ); //  133
      case ERR_NOT_ENOUGH_MONEY           : return("ERR_NOT_ENOUGH_MONEY"           ); //  134
      case ERR_PRICE_CHANGED              : return("ERR_PRICE_CHANGED"              ); //  135
      case ERR_OFF_QUOTES                 : return("ERR_OFF_QUOTES"                 ); //  136
      case ERR_BROKER_BUSY                : return("ERR_BROKER_BUSY"                ); //  137
      case ERR_REQUOTE                    : return("ERR_REQUOTE"                    ); //  138
      case ERR_ORDER_LOCKED               : return("ERR_ORDER_LOCKED"               ); //  139
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("ERR_LONG_POSITIONS_ONLY_ALLOWED"); //  140
      case ERR_TOO_MANY_REQUESTS          : return("ERR_TOO_MANY_REQUESTS"          ); //  141
      case ERR_TRADE_MODIFY_DENIED        : return("ERR_TRADE_MODIFY_DENIED"        ); //  145
      case ERR_TRADE_CONTEXT_BUSY         : return("ERR_TRADE_CONTEXT_BUSY"         ); //  146
      case ERR_TRADE_EXPIRATION_DENIED    : return("ERR_TRADE_EXPIRATION_DENIED"    ); //  147
      case ERR_TRADE_TOO_MANY_ORDERS      : return("ERR_TRADE_TOO_MANY_ORDERS"      ); //  148
      case ERR_TRADE_HEDGE_PROHIBITED     : return("ERR_TRADE_HEDGE_PROHIBITED"     ); //  149
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("ERR_TRADE_PROHIBITED_BY_FIFO"   ); //  150

      // runtime errors
      case ERR_RUNTIME_ERROR              : return("ERR_RUNTIME_ERROR"              ); // 4000
      case ERR_WRONG_FUNCTION_POINTER     : return("ERR_WRONG_FUNCTION_POINTER"     ); // 4001
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("ERR_ARRAY_INDEX_OUT_OF_RANGE"   ); // 4002
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("ERR_NO_MEMORY_FOR_CALL_STACK"   ); // 4003
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("ERR_RECURSIVE_STACK_OVERFLOW"   ); // 4004
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("ERR_NOT_ENOUGH_STACK_FOR_PARAM" ); // 4005
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("ERR_NO_MEMORY_FOR_PARAM_STRING" ); // 4006
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("ERR_NO_MEMORY_FOR_TEMP_STRING"  ); // 4007
      case ERR_NOT_INITIALIZED_STRING     : return("ERR_NOT_INITIALIZED_STRING"     ); // 4008
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("ERR_NOT_INITIALIZED_ARRAYSTRING"); // 4009
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("ERR_NO_MEMORY_FOR_ARRAYSTRING"  ); // 4010
      case ERR_TOO_LONG_STRING            : return("ERR_TOO_LONG_STRING"            ); // 4011
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("ERR_REMAINDER_FROM_ZERO_DIVIDE" ); // 4012
      case ERR_ZERO_DIVIDE                : return("ERR_ZERO_DIVIDE"                ); // 4013
      case ERR_UNKNOWN_COMMAND            : return("ERR_UNKNOWN_COMMAND"            ); // 4014
      case ERR_WRONG_JUMP                 : return("ERR_WRONG_JUMP"                 ); // 4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("ERR_NOT_INITIALIZED_ARRAY"      ); // 4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("ERR_DLL_CALLS_NOT_ALLOWED"      ); // 4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("ERR_CANNOT_LOAD_LIBRARY"        ); // 4018
      case ERR_CANNOT_CALL_FUNCTION       : return("ERR_CANNOT_CALL_FUNCTION"       ); // 4019
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("ERR_EXTERNAL_CALLS_NOT_ALLOWED" ); // 4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("ERR_NO_MEMORY_FOR_RETURNED_STR" ); // 4021
      case ERR_SYSTEM_BUSY                : return("ERR_SYSTEM_BUSY"                ); // 4022
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("ERR_INVALID_FUNCTION_PARAMSCNT" ); // 4050
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("ERR_INVALID_FUNCTION_PARAMVALUE"); // 4051
      case ERR_STRING_FUNCTION_INTERNAL   : return("ERR_STRING_FUNCTION_INTERNAL"   ); // 4052
      case ERR_SOME_ARRAY_ERROR           : return("ERR_SOME_ARRAY_ERROR"           ); // 4053
      case ERR_INCORRECT_SERIESARRAY_USING: return("ERR_INCORRECT_SERIESARRAY_USING"); // 4054
      case ERR_CUSTOM_INDICATOR_ERROR     : return("ERR_CUSTOM_INDICATOR_ERROR"     ); // 4055
      case ERR_INCOMPATIBLE_ARRAYS        : return("ERR_INCOMPATIBLE_ARRAYS"        ); // 4056
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("ERR_GLOBAL_VARIABLES_PROCESSING"); // 4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("ERR_GLOBAL_VARIABLE_NOT_FOUND"  ); // 4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTING: return("ERR_FUNC_NOT_ALLOWED_IN_TESTING"); // 4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("ERR_FUNCTION_NOT_CONFIRMED"     ); // 4060
      case ERR_SEND_MAIL_ERROR            : return("ERR_SEND_MAIL_ERROR"            ); // 4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("ERR_STRING_PARAMETER_EXPECTED"  ); // 4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("ERR_INTEGER_PARAMETER_EXPECTED" ); // 4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("ERR_DOUBLE_PARAMETER_EXPECTED"  ); // 4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("ERR_ARRAY_AS_PARAMETER_EXPECTED"); // 4065
      case ERR_HISTORY_UPDATE             : return("ERR_HISTORY_UPDATE"             ); // 4066
      case ERR_TRADE_ERROR                : return("ERR_TRADE_ERROR"                ); // 4067
      case ERR_END_OF_FILE                : return("ERR_END_OF_FILE"                ); // 4099
      case ERR_SOME_FILE_ERROR            : return("ERR_SOME_FILE_ERROR"            ); // 4100
      case ERR_WRONG_FILE_NAME            : return("ERR_WRONG_FILE_NAME"            ); // 4101
      case ERR_TOO_MANY_OPENED_FILES      : return("ERR_TOO_MANY_OPENED_FILES"      ); // 4102
      case ERR_CANNOT_OPEN_FILE           : return("ERR_CANNOT_OPEN_FILE"           ); // 4103
      case ERR_INCOMPATIBLE_FILEACCESS    : return("ERR_INCOMPATIBLE_FILEACCESS"    ); // 4104
      case ERR_NO_ORDER_SELECTED          : return("ERR_NO_ORDER_SELECTED"          ); // 4105
      case ERR_UNKNOWN_SYMBOL             : return("ERR_UNKNOWN_SYMBOL"             ); // 4106
      case ERR_INVALID_PRICE_PARAM        : return("ERR_INVALID_PRICE_PARAM"        ); // 4107
      case ERR_INVALID_TICKET             : return("ERR_INVALID_TICKET"             ); // 4108
      case ERR_TRADE_NOT_ALLOWED          : return("ERR_TRADE_NOT_ALLOWED"          ); // 4109
      case ERR_LONGS_NOT_ALLOWED          : return("ERR_LONGS_NOT_ALLOWED"          ); // 4110
      case ERR_SHORTS_NOT_ALLOWED         : return("ERR_SHORTS_NOT_ALLOWED"         ); // 4111
      case ERR_OBJECT_ALREADY_EXISTS      : return("ERR_OBJECT_ALREADY_EXISTS"      ); // 4200
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("ERR_UNKNOWN_OBJECT_PROPERTY"    ); // 4201
      case ERR_OBJECT_DOES_NOT_EXIST      : return("ERR_OBJECT_DOES_NOT_EXIST"      ); // 4202
      case ERR_UNKNOWN_OBJECT_TYPE        : return("ERR_UNKNOWN_OBJECT_TYPE"        ); // 4203
      case ERR_NO_OBJECT_NAME             : return("ERR_NO_OBJECT_NAME"             ); // 4204
      case ERR_OBJECT_COORDINATES_ERROR   : return("ERR_OBJECT_COORDINATES_ERROR"   ); // 4205
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("ERR_NO_SPECIFIED_SUBWINDOW"     ); // 4206
      case ERR_SOME_OBJECT_ERROR          : return("ERR_SOME_OBJECT_ERROR"          ); // 4207

      // custom errors
      case ERR_WINDOWS_ERROR              : return("ERR_WINDOWS_ERROR"              ); // 5000
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("ERR_FUNCTION_NOT_IMPLEMENTED"   ); // 5001
      case ERR_INVALID_INPUT_PARAMVALUE   : return("ERR_INVALID_INPUT_PARAMVALUE"   ); // 5002
      case ERR_INVALID_CONFIG_PARAMVALUE  : return("ERR_INVALID_CONFIG_PARAMVALUE"  ); // 5003
      case ERR_TERMINAL_NOT_YET_READY     : return("ERR_TERMINAL_NOT_YET_READY"     ); // 5004
      case ERR_INVALID_TIMEZONE_CONFIG    : return("ERR_INVALID_TIMEZONE_CONFIG"    ); // 5005
      case ERR_MARKETINFO_UPDATE          : return("ERR_MARKETINFO_UPDATE"          ); // 5006
      case ERR_FILE_NOT_FOUND             : return("ERR_FILE_NOT_FOUND"             ); // 5007
   }
   return(error);
}


/**
 * Gibt die lesbare Beschreibung eines ShellExecute() oder ShellExecuteEx()-Fehlercodes zurück.
 *
 * @param  int error - ShellExecute-Fehlercode
 *
 * @return string
 */
string ShellExecuteErrorToStr(int error) {
   switch (error) {
      case 0                     : return("Out of memory or resources."                        );
      case ERROR_BAD_FORMAT      : return("Incorrect file format."                             );
      case SE_ERR_FNF            : return("File not found."                                    );
      case SE_ERR_PNF            : return("Path not found."                                    );
      case SE_ERR_ACCESSDENIED   : return("Access denied."                                     );
      case SE_ERR_OOM            : return("Out of memory."                                     );
      case SE_ERR_SHARE          : return("A sharing violation occurred."                      );
      case SE_ERR_ASSOCINCOMPLETE: return("File association information incomplete or invalid.");
      case SE_ERR_DDETIMEOUT     : return("DDE operation timed out."                           );
      case SE_ERR_DDEFAIL        : return("DDE operation failed."                              );
      case SE_ERR_DDEBUSY        : return("DDE operation is busy."                             );
      case SE_ERR_NOASSOC        : return("File association information not available."        );
      case SE_ERR_DLLNOTFOUND    : return("Dynamic-link library not found."                    );
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Version eines Events zurück.
 *
 * @param  int event - Event
 *
 * @return string
 */
string EventToStr(int event) {
   switch (event) {
      case EVENT_BAR_OPEN       : return("BarOpen"       );
      case EVENT_ORDER_PLACE    : return("OrderPlace"    );
      case EVENT_ORDER_CHANGE   : return("OrderChange"   );
      case EVENT_ORDER_CANCEL   : return("OrderCancel"   );
      case EVENT_POSITION_OPEN  : return("PositionOpen"  );
      case EVENT_POSITION_CLOSE : return("PositionClose" );
      case EVENT_ACCOUNT_CHANGE : return("AccountChange" );
      case EVENT_ACCOUNT_PAYMENT: return("AccountPayment");
      case EVENT_HISTORY_CHANGE : return("HistoryChange" );
   }

   catch("EventToStr()   unknown event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Offset der angegebenen lokalen Zeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime localTime - Zeitpunkt lokaler Zeit (default: aktuelle Zeit)
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetLocalToGmtOffset(datetime localTime=-1) {
   if (localTime != -1) {
      catch("GetLocalToGmtOffset()   support for parameter 'localTime' not yet implemented", ERR_RUNTIME_ERROR);
      return(EMPTY_VALUE);
   }

   int /*TIME_ZONE_INFORMATION*/ tzi[43];       // struct TIME_ZONE_INFORMATION = 172 byte
   int type = GetTimeZoneInformation(tzi);

   int offset = 0;

   if (type != TIME_ZONE_ID_UNKNOWN) {
      offset = tzi.Bias(tzi);
      if (type == TIME_ZONE_ID_DAYLIGHT)
         offset += tzi.DaylightBias(tzi);
      offset *= -60;
   }

   //Print("GetLocalToGmtOffset()   difference between local and GMT is: ", (offset/MINUTES), " minutes");

   if (catch("GetLocalToGmtOffset()") != NO_ERROR)
      return(EMPTY_VALUE);
   return(offset);
}


/**
 * Gibt die lesbare Konstante einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MovingAverageToStr(int method) {
   switch (method) {
      case MODE_SMA : return("MODE_SMA" );
      case MODE_EMA : return("MODE_EMA" );
      case MODE_SMMA: return("MODE_SMMA");
      case MODE_LWMA: return("MODE_LWMA");
      case MODE_ALMA: return("MODE_ALMA");
   }
   catch("MovingAverageToStr()  invalid paramter method = "+ method, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Beschreibung einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MovingAverageDescription(int method) {
   switch (method) {
      case MODE_SMA : return("SMA" );
      case MODE_EMA : return("EMA" );
      case MODE_SMMA: return("SMMA");
      case MODE_LWMA: return("LWMA");
      case MODE_ALMA: return("ALMA");
   }
   catch("MovingAverageDescription()  invalid paramter method = "+ method, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die numerische Konstante einer MovingAverage-Methode zurück.
 *
 * @param  string method - MA-Methode: [MODE_][SMA|EMA|SMMA|LWMA]
 *
 * @return int - MA-Konstante
 */
int MovingAverageToId(string method) {
   string value = StringToUpper(method);

   if (StringStartsWith(value, "MODE_"))
      value = StringRight(value, -5);

   if (value == "SMA" ) return(MODE_SMA );
   if (value == "EMA" ) return(MODE_EMA );
   if (value == "SMMA") return(MODE_SMMA);
   if (value == "LWMA") return(MODE_LWMA);
   if (value == "ALMA") return(MODE_ALMA);

   catch("MovingAverageToId()  invalid parameter method = \""+ method +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
   return(-1);
}


/**
 * Gibt die lesbare Konstante einer MessageBox-Command-ID zurück.
 *
 * @param  int cmd - Command-ID (entspricht dem gedrückten Messagebox-Button)
 *
 * @return string
 */
string MessageBoxCmdToStr(int cmd) {
   switch (cmd) {
      case IDOK      : return("IDOK"      );
      case IDCANCEL  : return("IDCANCEL"  );
      case IDABORT   : return("IDABORT"   );
      case IDRETRY   : return("IDRETRY"   );
      case IDIGNORE  : return("IDIGNORE"  );
      case IDYES     : return("IDYES"     );
      case IDNO      : return("IDNO"      );
      case IDCLOSE   : return("IDCLOSE"   );
      case IDHELP    : return("IDHELP"    );
      case IDTRYAGAIN: return("IDTRYAGAIN");
      case IDCONTINUE: return("IDCONTINUE");
   }
   catch("MessageBoxCmdToStr()  unknown message box command = "+ cmd, ERR_RUNTIME_ERROR);
   return("");
}


/**
 * Ob der übergebene Parameter ein gültiger Tradeserver-Operationtype ist.
 *
 * @param  int value - zu prüfender Wert
 *
 * @return bool
 */
bool IsTradeOperationType(int value) {
   switch (value) {
      case OP_BUY:
      case OP_SELL:
      case OP_BUYLIMIT:
      case OP_SELLLIMIT:
      case OP_BUYSTOP:
      case OP_SELLSTOP:
         return(true);
   }
   return(false);
}


/**
 * Gibt die lesbare Konstante eines Operation-Types zurück.
 *
 * @param  int type - Operation-Type
 *
 * @return string
 */
string OperationTypeToStr(int type) {
   switch (type) {
      case OP_BUY      : return("OP_BUY"      );
      case OP_SELL     : return("OP_SELL"     );
      case OP_BUYLIMIT : return("OP_BUYLIMIT" );
      case OP_SELLLIMIT: return("OP_SELLLIMIT");
      case OP_BUYSTOP  : return("OP_BUYSTOP"  );
      case OP_SELLSTOP : return("OP_SELLSTOP" );
      case OP_BALANCE  : return("OP_BALANCE"  );
      case OP_CREDIT   : return("OP_CREDIT"   );
   }
   catch("OperationTypeToStr()  invalid parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die Beschreibung eines Operation-Types zurück.
 *
 * @param  int type - Operation-Type
 *
 * @return string
 */
string OperationTypeDescription(int type) {
   switch (type) {
      case OP_BUY      : return("Buy"       );
      case OP_SELL     : return("Sell"      );
      case OP_BUYLIMIT : return("Buy Limit" );
      case OP_SELLLIMIT: return("Sell Limit");
      case OP_BUYSTOP  : return("Stop Buy"  );
      case OP_SELLSTOP : return("Stop Sell" );
      case OP_BALANCE  : return("Balance"   );
      case OP_CREDIT   : return("Credit"    );
   }
   catch("OperationTypeDescription()  invalid parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Konstante eines Price-Identifiers zurück.
 *
 * @param  int appliedPrice - Price-Typ, siehe: iMA(symbol, timeframe, period, ma_shift, ma_method, int *APPLIED_PRICE*, bar)
 *
 * @return string
 */
string AppliedPriceToStr(int appliedPrice) {
   switch (appliedPrice) {
      case PRICE_CLOSE   : return("PRICE_CLOSE"   );     // Close price
      case PRICE_OPEN    : return("PRICE_OPEN"    );     // Open price
      case PRICE_HIGH    : return("PRICE_HIGH"    );     // High price
      case PRICE_LOW     : return("PRICE_LOW"     );     // Low price
      case PRICE_MEDIAN  : return("PRICE_MEDIAN"  );     // Median price:         (High+Low)/2
      case PRICE_TYPICAL : return("PRICE_TYPICAL" );     // Typical price:        (High+Low+Close)/3
      case PRICE_WEIGHTED: return("PRICE_WEIGHTED");     // Weighted close price: (High+Low+Close+Close)/4
   }

   catch("AppliedPriceToStr()  invalid parameter appliedPrice = "+ appliedPrice, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Version eines Price-Identifiers zurück.
 *
 * @param  int appliedPrice - Price-Typ, siehe: iMA(symbol, timeframe, period, ma_shift, ma_method, int *APPLIED_PRICE*, bar)
 *
 * @return string
 */
string AppliedPriceDescription(int appliedPrice) {
   switch (appliedPrice) {
      case PRICE_CLOSE   : return("Close"   );     // Close price
      case PRICE_OPEN    : return("Open"    );     // Open price
      case PRICE_HIGH    : return("High"    );     // High price
      case PRICE_LOW     : return("Low"     );     // Low price
      case PRICE_MEDIAN  : return("Median"  );     // Median price:         (High+Low)/2
      case PRICE_TYPICAL : return("Typical" );     // Typical price:        (High+Low+Close)/3
      case PRICE_WEIGHTED: return("Weighted");     // Weighted close price: (High+Low+Close+Close)/4
   }

   catch("AppliedPriceDescription()  invalid parameter appliedPrice = "+ appliedPrice, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Integer-Wert einer Timeframe-Bezeichnung zurück.
 *
 * @param  string timeframe - M1, M5, M15, M30 etc.
 *
 * @return int - Timeframe-Code oder 0, wenn die Bezeichnung ungültig ist
 */
int StringToPeriod(string timeframe) {
   timeframe = StringToUpper(timeframe);

   if (timeframe == "M1" ) return(PERIOD_M1 );     //     1  1 minute
   if (timeframe == "M5" ) return(PERIOD_M5 );     //     5  5 minutes
   if (timeframe == "M15") return(PERIOD_M15);     //    15  15 minutes
   if (timeframe == "M30") return(PERIOD_M30);     //    30  30 minutes
   if (timeframe == "H1" ) return(PERIOD_H1 );     //    60  1 hour
   if (timeframe == "H4" ) return(PERIOD_H4 );     //   240  4 hour
   if (timeframe == "D1" ) return(PERIOD_D1 );     //  1440  daily
   if (timeframe == "W1" ) return(PERIOD_W1 );     // 10080  weekly
   if (timeframe == "MN1") return(PERIOD_MN1);     // 43200  monthly

   log("StringToPeriod()  invalid parameter timeframe = \""+ timeframe +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Gibt die lesbare Version eines Timeframe-Codes zurück.
 *
 * @param  int period - Timeframe-Code bzw. Anzahl der Minuten je Chart-Bar (default: aktuelle Periode)
 *
 * @return string
 */
string PeriodToStr(int period=0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return("M1" );     //     1  1 minute
      case PERIOD_M5 : return("M5" );     //     5  5 minutes
      case PERIOD_M15: return("M15");     //    15  15 minutes
      case PERIOD_M30: return("M30");     //    30  30 minutes
      case PERIOD_H1 : return("H1" );     //    60  1 hour
      case PERIOD_H4 : return("H4" );     //   240  4 hour
      case PERIOD_D1 : return("D1" );     //  1440  daily
      case PERIOD_W1 : return("W1" );     // 10080  weekly
      case PERIOD_MN1: return("MN1");     // 43200  monthly
   }

   catch("PeriodToStr()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt das Timeframe-Flag der angegebenen Chartperiode zurück.
 *
 * @param  int period - Timeframe-Identifier (default: Periode des aktuellen Charts)
 *
 * @return int - Timeframe-Flag
 */
int GetPeriodFlag(int period=0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIODFLAG_M1 );
      case PERIOD_M5 : return(PERIODFLAG_M5 );
      case PERIOD_M15: return(PERIODFLAG_M15);
      case PERIOD_M30: return(PERIODFLAG_M30);
      case PERIOD_H1 : return(PERIODFLAG_H1 );
      case PERIOD_H4 : return(PERIODFLAG_H4 );
      case PERIOD_D1 : return(PERIODFLAG_D1 );
      case PERIOD_W1 : return(PERIODFLAG_W1 );
      case PERIOD_MN1: return(PERIODFLAG_MN1);
   }

   catch("GetPeriodFlag()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Gibt die lesbare Version eines Timeframe-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener Timeframe-Flags
 *
 * @return string
 */
string PeriodFlagToStr(int flags) {
   string result = "";

   if (flags & PERIODFLAG_M1  != 0) result = StringConcatenate(result, " | M1" );
   if (flags & PERIODFLAG_M5  != 0) result = StringConcatenate(result, " | M5" );
   if (flags & PERIODFLAG_M15 != 0) result = StringConcatenate(result, " | M15");
   if (flags & PERIODFLAG_M30 != 0) result = StringConcatenate(result, " | M30");
   if (flags & PERIODFLAG_H1  != 0) result = StringConcatenate(result, " | H1" );
   if (flags & PERIODFLAG_H4  != 0) result = StringConcatenate(result, " | H4" );
   if (flags & PERIODFLAG_D1  != 0) result = StringConcatenate(result, " | D1" );
   if (flags & PERIODFLAG_W1  != 0) result = StringConcatenate(result, " | W1" );
   if (flags & PERIODFLAG_MN1 != 0) result = StringConcatenate(result, " | MN1");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Gibt die Zeitzone des aktuellen Tradeservers zurück.
 *
 * @return string - Zeitzonen-Identifier nach "Olson" TZ Database
 *
 * @see http://en.wikipedia.org/wiki/Tz_database
 */
string GetTradeServerTimezone() {
   // Die Timezone-ID wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen die
   // Rückgabewerte der MQL-Accountfunktionen evt. schon auf den neuen Account, der aktuelle Tick gehört aber noch zum alten Chart (mit den alten Bars).
   // Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Chart mit ggf. neuer Zeitzone befinden.

   static string cache.timezone[];
   static int    lastTick;                               // Erkennung von Mehrfachaufrufen während eines Ticks

   // 1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (ValidBars == 0) /*&&*/ if (Tick != lastTick)
      ArrayResize(cache.timezone, 0);
   lastTick = Tick;

   // 2) wenn Wert im Cache, gecachten Wert zurückgeben
   if (ArraySize(cache.timezone) > 0)
      return(cache.timezone[0]);

   // 3) Timezone-ID ermitteln
   string timezone, directory=StringToLower(GetTradeServerDirectory());

   if      (StringStartsWith(directory, "alpari-"            )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "alparibroker-"      )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "alpariuk-"          )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "alparius-"          )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "apbgtrading-"       )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "atcbrokers-"        )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "atcbrokersest-"     )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "broco-"             )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "brocoinvestments-"  )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "dukascopy-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "easyforex-"         )) timezone = "GMT";
   else if (StringStartsWith(directory, "forex-"             )) timezone = "GMT";
   else if (StringStartsWith(directory, "fxpro.com-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "fxdd-"              )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "inovatrade-"        )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "investorseurope-"   )) timezone = "Europe/London";
   else if (StringStartsWith(directory, "londoncapitalgr-"   )) timezone = "GMT";
   else if (StringStartsWith(directory, "londoncapitalgroup-")) timezone = "GMT";
   else if (StringStartsWith(directory, "mbtrading-"         )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "sig-"               )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "teletrade-"         )) timezone = "Europe/Berlin";
   else {
      timezone = GetGlobalConfigString("Timezones", directory, "");
      if (timezone == "") {
         catch("GetTradeServerTimezone(1)  missing timezone configuration for trade server \""+ GetTradeServerDirectory() +"\"", ERR_INVALID_TIMEZONE_CONFIG);
         return("");
      }
   }

   // 4) Timezone-ID cachen
   ArrayResize(cache.timezone, 1);
   cache.timezone[0] = timezone;

   if (catch("GetTradeServerTimezone(2)") != NO_ERROR)
      return("");
   return(timezone);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu New Yorker Zeit (Eastern Time) zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToEasternTimeOffset(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerToEasternTimeOffset(1)   invalid parameter serverTime = "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetTradeServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "America/New_York")
      return(0);

   // Offset Server zu GMT
   int serverToGmtOffset;
   if (zone != "GMT")
      serverToGmtOffset = GetServerToGmtOffset(serverTime);

   // Offset GMT zu Eastern Time
   int gmtToEasternTimeOffset = GetGmtToEasternTimeOffset(serverTime - serverToGmtOffset);

   if (catch("GetServerToEasternTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(serverToGmtOffset + gmtToEasternTimeOffset);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToGmtOffset(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerToGmtOffset(1)   invalid parameter serverTime = "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetTradeServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);
   int offset, year = TimeYear(serverTime)-1970;

   if (zone == "Europe/Kiev") {                     // GMT+0200,GMT+0300
      if      (serverTime < EEST_transitions[year][0]) offset = 2 * HOURS;
      else if (serverTime < EEST_transitions[year][1]) offset = 3 * HOURS;
      else                                             offset = 2 * HOURS;
   }

   else if (zone == "Europe/Berlin") {              // GMT+0100,GMT+0200
      if      (serverTime < CEST_transitions[year][0]) offset = 1 * HOURS;
      else if (serverTime < CEST_transitions[year][1]) offset = 2 * HOURS;
      else                                             offset = 1 * HOURS;
   }
                                                    // GMT+0000
   else if (zone == "GMT")                             offset = 0;

   else if (zone == "Europe/London") {              // GMT+0000,GMT+0100
      if      (serverTime < BST_transitions[year][0])  offset = 0;
      else if (serverTime < BST_transitions[year][1])  offset = 1 * HOUR;
      else                                             offset = 0;
   }

   else if (zone == "America/New_York") {           // GMT-0500,GMT-0400
      if      (serverTime < EDT_transitions[year][0])  offset = -5 * HOURS;
      else if (serverTime < EDT_transitions[year][1])  offset = -4 * HOURS;
      else                                             offset = -5 * HOURS;
   }

   else {
      catch("GetServerToGmtOffset(2)  unknown timezone \""+ zone +"\"", ERR_INVALID_TIMEZONE_CONFIG);
      return(EMPTY_VALUE);
   }

   if (catch("GetServerToGmtOffset(3)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


int hWndTerminal;                               // überlebt Timeframe-Wechsel


/**
 * Gibt das Handle des Hauptfensters des MetaTrader-Terminals zurück.
 *
 * @return int - Handle oder 0, falls ein Fehler auftrat
 */
int GetTerminalWindow() {
   if (hWndTerminal != 0)
      return(hWndTerminal);

   // TODO: in Indicator::init() ist WindowHandle() unbrauchbar
   int hWndParent = WindowHandle(Symbol(), Period());
   if (hWndParent == 0)
      return(0);

   while (hWndParent != 0) {
      int hWndChild  = hWndParent;
      hWndParent = GetParent(hWndChild);
   }
   hWndTerminal = hWndChild;

   if (catch("GetTerminalWindow()") != NO_ERROR)
      return(0);
   return(hWndTerminal);
}


/**
 * Gibt die Beschreibung eines UninitializeReason-Codes zurück (siehe UninitializeReason()).
 *
 * @param  int reason - Code
 *
 * @return string
 */
string UninitializeReasonDescription(int reason) {
   switch (reason) {
      case REASON_APPEXIT    : return("application exit"                      );
      case REASON_REMOVE     : return("expert or indicator removed from chart");
      case REASON_RECOMPILE  : return("expert or indicator recompiled"        );
      case REASON_CHARTCHANGE: return("symbol or timeframe changed"           );
      case REASON_CHARTCLOSE : return("chart closed"                          );
      case REASON_PARAMETERS : return("input parameters changed"              );
      case REASON_ACCOUNT    : return("account changed"                       );
   }

   catch("UninitializeReasonDescription()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Konstante eines UninitializeReason-Codes zurück (siehe UninitializeReason()).
 *
 * @param  int reason - Code
 *
 * @return string
 */
string UninitializeReasonToStr(int reason) {
   switch (reason) {
      case REASON_APPEXIT    : return("REASON_APPEXIT"    );
      case REASON_REMOVE     : return("REASON_REMOVE"     );
      case REASON_RECOMPILE  : return("REASON_RECOMPILE"  );
      case REASON_CHARTCHANGE: return("REASON_CHARTCHANGE");
      case REASON_CHARTCLOSE : return("REASON_CHARTCLOSE" );
      case REASON_PARAMETERS : return("REASON_PARAMETERS" );
      case REASON_ACCOUNT    : return("REASON_ACCOUNT"    );
   }

   catch("UninitializeReasonToStr()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Text der Titelbar des angegebenen Fensters zurück (wenn es einen hat).  Ist das angegebene Fenster ein Windows-Control,
 * wird dessen Text zurückgegeben.
 *
 * @param  int hWnd - Handle des Fensters oder Controls
 *
 * @return string - Text
 */
string GetWindowText(int hWnd) {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // Zeigerproblematik (siehe MetaTrader.doc)

   GetWindowTextA(hWnd, buffer[0], StringLen(buffer[0]));

   if (catch("GetWindowText()") != NO_ERROR)
      return("");
   return(buffer[0]);
}


/**
 * Konvertiert die angegebene GMT-Zeit (UTC) nach Eastern Time (New Yorker Zeit).
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls ein Fehler auftrat
 */
datetime GmtToEasternTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GmtToEasternTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int gmtToEasternTimeOffset = GetGmtToEasternTimeOffset(gmtTime);  // Offset von GMT zu New Yorker Zeit
   if (gmtToEasternTimeOffset == EMPTY_VALUE)
      return(-1);

   datetime easternTime = gmtTime - gmtToEasternTimeOffset;

   //Print("GmtToEasternTime()    GMT: "+ TimeToStr(gmtTime) +"     ET offset: "+ (gmtToEasternTimeOffset/HOURS) +"     ET: "+ TimeToStr(easternTime));

   if (catch("GmtToEasternTime(2)") != NO_ERROR)
      return(-1);
   return(easternTime);
}


/**
 * Konvertiert die angegebene GMT-Zeit (UTC) nach Tradeserver-Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GmtToServerTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GmtToServerTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (GetTradeServerTimezone() == "GMT")
      return(gmtTime);

   int gmtToServerTimeOffset = GetGmtToServerTimeOffset(gmtTime);
   if (gmtToServerTimeOffset == EMPTY_VALUE)
      return(-1);

   datetime serverTime = gmtTime - gmtToServerTimeOffset;

   //Print("GmtToServerTime()    GMT: "+ TimeToStr(gmtTime) +"     server offset: "+ (gmtToServerTimeOffset/HOURS) +"     server: "+ TimeToStr(serverTime));

   if (catch("GmtToServerTime(2)") != NO_ERROR)
      return(-1);
   return(serverTime);
}


/**
 * Berechnet den Balancewert eines Accounts am angegebenen Offset des aktuellen Charts und schreibt ihn in das Ergebnisarray.
 *
 * @param  int     account  - Account, für den der Wert berechnet werden soll
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (z.B. Indikatorpuffer)
 * @param  int     bar      - Barindex des zu berechnenden Wertes (Chart-Offset)
 *
 * @return int - Fehlerstatus
 */
int iAccountBalance(int account, double& lpBuffer[], int bar) {

   // TODO: Berechnung einzelner Bar implementieren (zur Zeit wird der Indikator hier noch komplett neuberechnet)

   if (iAccountBalanceSeries(account, lpBuffer) == ERR_HISTORY_UPDATE) {
      catch("iAccountBalance(1)");
      return(ERR_HISTORY_UPDATE);
   }

   return(catch("iAccountBalance(2)"));
}


/**
 * Berechnet den Balanceverlauf eines Accounts für alle Bars des aktuellen Charts und schreibt die Werte in das angegebene Zielarray.
 *
 * @param  int     account  - Account-Nummer
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (z.B. Indikatorpuffer)
 *
 * @return int - Fehlerstatus
 */
int iAccountBalanceSeries(int account, double& lpBuffer[]) {
   if (ArraySize(lpBuffer) != Bars) {
      ArrayResize(lpBuffer, Bars);
      ArrayInitialize(lpBuffer, EMPTY_VALUE);
   }

   // Balance-History holen
   datetime times []; ArrayResize(times , 0);
   double   values[]; ArrayResize(values, 0);

   int error = GetBalanceHistory(account, times, values);   // aufsteigend nach Zeit sortiert (in times[0] stehen die ältesten Werte)
   if (error != NO_ERROR) {
      catch("iAccountBalanceSeries(1)");
      return(error);
   }

   int bar, lastBar, historySize=ArraySize(values);

   // Balancewerte für Bars des aktuellen Charts ermitteln und ins Ergebnisarray schreiben
   for (int i=0; i < historySize; i++) {
      // Barindex des Zeitpunkts berechnen
      bar = iBarShiftNext(NULL, 0, times[i]);
      if (bar == EMPTY_VALUE)                               // ERR_HISTORY_UPDATE ?
         return(stdlib_GetLastError());
      if (bar == -1)                                        // dieser und alle folgenden Werte sind zu neu für den Chart
         break;

      // Lücken mit vorherigem Balancewert füllen
      if (bar < lastBar-1) {
         for (int z=lastBar-1; z > bar; z--) {
            lpBuffer[z] = lpBuffer[lastBar];
         }
      }

      // aktuellen Balancewert eintragen
      lpBuffer[bar] = values[i];
      lastBar = bar;
   }

   // Ergebnisarray bis zur ersten Bar mit dem letzten bekannten Balancewert füllen
   for (bar=lastBar-1; bar >= 0; bar--) {
      lpBuffer[bar] = lpBuffer[lastBar];
   }

   return(catch("iAccountBalanceSeries(2)"));
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die letzte vorherige existierende Bar zurück.
 *
 * @param  string   symbol - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param  int      period - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param  datetime time   - Zeitpunkt
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu alt für den Chart);
 *               EMPTY_VALUE, wenn ein Fehler aufgetreten ist
 *
 * NOTE:  Kann ERR_HISTORY_UPDATE auslösen.
 * ----
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int period/*=0*/, datetime time) {
   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();

   if (time < 1) {
      catch("iBarShiftPrevious(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // Datenreihe holen
   datetime times[];
   int bars  = ArrayCopySeries(times, MODE_TIME, symbol, period);
   int error = GetLastError();                              // ERR_HISTORY_UPDATE ???

   if (error == NO_ERROR) {
      // Bars überprüfen
      if (time < times[bars-1]) {
         int bar = -1;                                      // Zeitpunkt ist zu alt für den Chart
      }
      else {
         bar   = iBarShift(symbol, period, time);
         error = GetLastError();                            // ERR_HISTORY_UPDATE ???
      }
   }

   if (error != NO_ERROR) {
      last_error = error;
      if (error != ERR_HISTORY_UPDATE)
         catch("iBarShiftPrevious(2)", error);
      return(EMPTY_VALUE);
   }
   return(bar);
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die nächste existierende Bar zurück.
 *
 * @param  string   symbol - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param  int      period - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param  datetime time   - Zeitpunkt
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu jung für den Chart);
 *               EMPTY_VALUE, wenn ein Fehler aufgetreten ist
 *
 * NOTE:    Kann ERR_HISTORY_UPDATE auslösen.
 * ----
 */
int iBarShiftNext(string symbol/*=NULL*/, int period/*=0*/, datetime time) {
   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();

   if (time < 1) {
      catch("iBarShiftNext(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int bar   = iBarShift(symbol, period, time, true);
   int error = GetLastError();                              // ERR_HISTORY_UPDATE ???

   if (error==NO_ERROR) if (bar==-1) {                      // falls die Bar nicht existiert und auch kein Update läuft
      // Datenreihe holen
      datetime times[];
      int bars = ArrayCopySeries(times, MODE_TIME, symbol, period);
      error = GetLastError();                               // ERR_HISTORY_UPDATE ???

      if (error == NO_ERROR) {
         // Bars überprüfen
         if (time < times[bars-1])                          // Zeitpunkt ist zu alt für den Chart, die älteste Bar zurückgeben
            bar = bars-1;

         else if (time < times[0]) {                        // Kurslücke, die nächste existierende Bar zurückgeben
            bar   = iBarShift(symbol, period, time) - 1;
            error = GetLastError();                         // ERR_HISTORY_UPDATE ???
         }
         //else: (time > times[0]) => bar=-1                // Zeitpunkt ist zu neu für den Chart, bar bleibt -1
      }
   }

   if (error != NO_ERROR) {
      last_error = error;
      if (error != ERR_HISTORY_UPDATE)
         catch("iBarShiftNext(2)", error);
      return(EMPTY_VALUE);
   }
   return(bar);
}


/**
 * Gibt die nächstgrößere Periode der angegebenen Periode zurück.
 *
 * @param  int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - Nächstgrößere Periode oder der ursprüngliche Wert, wenn keine größere Periode existiert.
 */
int IncreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M5 );
      case PERIOD_M5 : return(PERIOD_M15);
      case PERIOD_M15: return(PERIOD_M30);
      case PERIOD_M30: return(PERIOD_H1 );
      case PERIOD_H1 : return(PERIOD_H4 );
      case PERIOD_H4 : return(PERIOD_D1 );
      case PERIOD_D1 : return(PERIOD_W1 );
      case PERIOD_W1 : return(PERIOD_MN1);
      case PERIOD_MN1: return(PERIOD_MN1);
   }

   catch("IncreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Verbindet die Werte eines Boolean-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  bool   values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinBools(bool& values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (values[i]) strings[i] = "true";
      else           strings[i] = "false";
   }

   return(JoinStrings(strings, separator));
}


/**
 * Verbindet die Werte eines Double-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  double values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinDoubles(double& values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = FormatNumber(values[i], ".1+");
   }

   return(JoinStrings(strings, separator));
}


/**
 * Konvertiert ein Double-Array in einen lesbaren String.
 *
 * @param  double array[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string
 */
string DoubleArrayToStr(double& array[], string separator=", ") {
   if (ArraySize(array) == 0)
      return("{}");
   if (separator == "0")   // NULL
      separator = ", ";
   return(StringConcatenate("{", JoinDoubles(array, separator), "}"));
}


/**
 * Verbindet die Werte eines Integer-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  int    values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinInts(int& values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = values[i];
   }

   return(JoinStrings(strings, separator));
}


/**
 * Konvertiert ein Integer-Array in einen lesbaren String.
 *
 * @param  int    array[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string
 */
string IntArrayToStr(int& array[][], string separator=", ") {
   if (separator == "0")   // NULL
      separator = ", ";

   int dimensions = ArrayDimension(array);

   // ein-dimensionales Array
   if (dimensions == 1) {
      if (ArraySize(array) == 0)
         return("{}");
      return(StringConcatenate("{", JoinInts(array, separator), "}"));
   }

   // zwei-dimensionales Array
   if (dimensions == 2) {
      int size1=ArrayRange(array, 0), size2=ArrayRange(array, 1);
      if (size2 == 0)
         return("{}");

      string strTmp[]; ArrayResize(strTmp, size1);
      int    iTmp[];   ArrayResize(iTmp,   size2);

      for (int i=0; i < size1; i++) {
         for (int z=0; z < size2; z++) {
            iTmp[z] = array[i][z];
         }
         strTmp[i] = IntArrayToStr(iTmp);
      }
      return(StringConcatenate("{", JoinStrings(strTmp, separator), "}"));
   }

   // multi-dimensional
   return("{too many dimensions}");
}


/**
 * Verbindet die Werte eines Stringarrays unter Verwendung des angegebenen Separators.
 *
 * @param  string values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinStrings(string& values[], string separator) {
   string result = "";

   int size = ArraySize(values);

   for (int i=1; i < size; i++) {
      result = StringConcatenate(result, separator, values[i]);
   }
   if (size > 0)
      result = StringConcatenate(values[0], result);

   if (catch("JoinStrings()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Konvertiert ein String-Array in einen lesbaren String.
 *
 * @param  string array[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string
 */
string StringArrayToStr(string& array[], string separator=", ") {
   if (ArraySize(array) == 0)
      return("{}");
   
   if (separator == "0")   // NULL
      separator = ", ";
   
   return(StringConcatenate("{\"", JoinStrings(array, StringConcatenate("\"", separator, "\"")), "\"}"));
}


/**
 * Durchsucht ein Integer-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  int needle     - zu suchender Wert
 * @param  int haystack[] - zu durchsuchendes Array
 *
 * @return int - Index des Wertes oder -1, wenn der Wert im Array nicht enthalten ist
 */
int ArraySearchInt(int needle, int &haystack[]) {
   if (ArrayDimension(haystack) > 1) {
      catch("ArraySearchInt()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS);
      return(-1);
   }
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(-1);
}


/**
 * Prüft, ob ein Integer in einem Array enthalten ist.
 *
 * @param  int needle     - zu suchender Wert
 * @param  int haystack[] - zu durchsuchendes Array
 *
 * @return bool
 */
bool IntInArray(int needle, int &haystack[]) {
   return(ArraySearchInt(needle, haystack) > -1);
}


/**
 * Durchsucht ein Double-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  double needle     - zu suchender Wert
 * @param  double haystack[] - zu durchsuchendes Array
 *
 * @return int - Index des Wertes oder -1, wenn der Wert im Array nicht enthalten ist
 */
int ArraySearchDouble(double needle, double &haystack[]) {
   if (ArrayDimension(haystack) > 1) {
      catch("ArraySearchDouble()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS);
      return(-1);
   }
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (EQ(haystack[i], needle))
         return(i);
   }
   return(-1);
}


/**
 * Prüft, ob ein Double in einem Array enthalten ist.
 *
 * @param  double needle     - zu suchender Wert
 * @param  double haystack[] - zu durchsuchendes Array
 *
 * @return bool
 */
bool DoubleInArray(double needle, double &haystack[]) {
   return(ArraySearchDouble(needle, haystack) > -1);
}


/**
 * Durchsucht ein String-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  string needle     - zu suchender Wert
 * @param  string haystack[] - zu durchsuchendes Array
 *
 * @return int - Index des Wertes oder -1, wenn der Wert im Array nicht enthalten ist
 */
int ArraySearchString(string needle, string &haystack[]) {
   if (ArrayDimension(haystack) > 1) {
      catch("ArraySearchString()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS);
      return(-1);
   }
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(-1);
}


/**
 * Prüft, ob ein String in einem Array enthalten ist.
 *
 * @param  string needle     - zu suchender Wert
 * @param  string haystack[] - zu durchsuchendes Array
 *
 * @return bool
 */
bool StringInArray(string needle, string &haystack[]) {
   return(ArraySearchString(needle, haystack) > -1);
}


/**
 *
 *
abstract*/ int onBarOpen(int details[]) {
   return(catch("onBarOpen()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderPlace(int details[]) {
   return(catch("onOrderPlace()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderChange(int details[]) {
   return(catch("onOrderChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderCancel(int details[]) {
   return(catch("onOrderCancel()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param  int tickets[] - Tickets der neuen Positionen
 *
 * @return int - Fehlerstatus
 *
abstract*/ int onPositionOpen(int tickets[]) {
   return(catch("onPositionOpen()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onPositionClose(int details[]) {
   return(catch("onPositionClose()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onAccountChange(int details[]) {
   return(catch("onAccountChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onAccountPayment(int details[]) {
   return(catch("onAccountPayment()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onHistoryChange(int details[]) {
   return(catch("onHistoryChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Fügt das angegebene Objektlabel den bereits gespeicherten Labels hinzu.
 *
 * @param  string  label       - zu speicherndes Label
 * @param  string& lpObjects[] - Array mit bereits gespeicherten Labels
 *
 * @return int - Fehlerstatus
 */
int RegisterChartObject(string label, string& lpObjects[]) {
   int size = ArraySize(lpObjects);
   ArrayResize(lpObjects, size+1);
   lpObjects[size] = label;
   return(0);
}


/**
 * Entfernt die Objekte mit den angegebenen Labels aus dem aktuellen Chart.
 *
 * @param  string& lpLabels[] - Array mit Objektlabels
 *
 * @return int - Fehlerstatus
 */
int RemoveChartObjects(string& lpLabels[]) {
   int size = ArraySize(lpLabels);
   if (size == 0)
      return(NO_ERROR);

   for (int i=0; i < size; i++) {
      ObjectDelete(lpLabels[i]);
   }
   ArrayResize(lpLabels, 0);

   int error = GetLastError();
   if (error == ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("RemoveChartObjects()", error));
}


/**
 * Schickt eine SMS an die angegebene Telefonnummer.
 *
 * @param  string receiver - Telefonnummer des Empfängers (internationales Format: 49123456789)
 * @param  string message  - Text der SMS
 *
 * @return int - Fehlerstatus
 */
int SendTextMessage(string receiver, string message) {
   if (!StringIsDigit(receiver))
      return(catch("SendTextMessage(1)   invalid parameter receiver: "+ receiver, ERR_INVALID_FUNCTION_PARAMVALUE));

   // TODO: Gateway-Zugangsdaten auslagern

   // Befehlszeile für Shellaufruf zusammensetzen
   string url          = "https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={id}&to="+ receiver +"&text="+ UrlEncode(message);
   string filesDir     = TerminalPath() +"\\experts\\files";
   string time         = StringReplace(StringReplace(TimeToStr(TimeLocal(), TIME_DATE|TIME_MINUTES|TIME_SECONDS), ".", "-"), ":", ".");
   string responseFile = filesDir +"\\sms_"+ time +"_"+ GetCurrentThreadId() +".response";
   string logFile      = filesDir +"\\sms.log";
   string cmdLine      = "wget.exe -b --no-check-certificate \""+ url +"\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";

   int error = WinExec(cmdLine, SW_HIDE);       // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("SendTextMessage(1)  execution of \""+ cmdLine +"\" failed with error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WINDOWS_ERROR));

   /**
    * TODO: Fehlerauswertung nach dem Versand
    *
    * --2011-03-23 08:32:06--  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={id}&to={receiver}&text={text}
    * Resolving api.clickatell.com... failed: Unknown host.
    * wget: unable to resolve host address `api.clickatell.com'
    */

   return(catch("SendTextMessage(2)"));
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach Eastern Time (New Yorker Zeit).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls ein Fehler auftrat
 */
datetime ServerToEasternTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("ServerToEasternTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (GetTradeServerTimezone() == "America/New_York")
      return(serverTime);

   datetime gmtTime = ServerToGMT(serverTime);
   if (gmtTime == -1)
      return(-1);

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1)
      return(-1);

   //Print("ServerToEasternTime()    server: "+ TimeToStr(serverTime) +"     GMT: "+ TimeToStr(gmtTime) +"     ET: "+ TimeToStr(easternTime));

   if (catch("ServerToEasternTime(2)") != NO_ERROR)
      return(-1);
   return(easternTime);
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach GMT (UTC).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime ServerToGMT(datetime serverTime) {
   if (serverTime < 1) {
      catch("ServerToGMT(1)   invalid parameter serverTime = "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (GetTradeServerTimezone() == "GMT")
      return(serverTime);

   int serverToGmtOffset = GetServerToGmtOffset(serverTime);
   if (serverToGmtOffset == EMPTY_VALUE)
      return(-1);

   datetime gmtTime = serverTime - serverToGmtOffset;
   if (gmtTime < 0) {
      catch("ServerToGMT(2)   invalid parameter serverTime = "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   //Print("ServerToGMT()    server: "+ TimeToStr(serverTime) +"     GMT offset: "+ (serverToGmtOffset/HOURS) +"     GMT: "+ TimeToStr(gmtTime));

   if (catch("ServerToGMT(3)") != NO_ERROR)
      return(-1);
   return(gmtTime);
}


/**
 * Setzt den Text der Titelbar des angegebenen Fensters (wenn es eine hat). Ist das agegebene Fenster ein Control, wird dessen Text geändert.
 *
 * @param  int    hWnd - Handle des Fensters
 * @param  string text - Text
 *
 * @return int - Fehlerstatus
 */
int SetWindowText(int hWnd, string text) {
   if (!SetWindowTextA(hWnd, text))
      return(catch("SetWindowText()   user32.SetWindowText(hWnd="+ hWnd +", lpString=\""+ text +"\") => FALSE", ERR_WINDOWS_ERROR));

   return(0);
}


/**
 * Prüft, ob ein String einen Substring enthält.  Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object    - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StringContains(string object, string substring) {
   if (StringLen(substring) == 0) {
      catch("StringContains()   empty substring \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(object, substring) != -1);
}


/**
 * Prüft, ob ein String einen Substring enthält.  Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object    - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StringIContains(string object, string substring) {
   if (StringLen(substring) == 0) {
      catch("StringIContains()   empty substring \"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   return(StringFind(StringToUpper(object), StringToUpper(substring)) != -1);
}


/**
 * Vergleicht zwei Strings ohne Berücksichtigung der Groß-/Kleinschreibung.
 *
 * @param  string string1
 * @param  string string2
 *
 * @return bool
 */
bool StringICompare(string string1, string string2) {
   return(StringToUpper(string1) == StringToUpper(string2));
}


/**
 * Prüft, ob ein String nur Ziffern enthält.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StringIsDigit(string value) {
   int chr, len=StringLen(value);

   if (len == 0)
      return(false);

   for (int i=0; i < len; i++) {
      chr = StringGetChar(value, i);
      if (chr < '0') return(false);
      if (chr > '9') return(false);       // Conditions für MQL optimiert
   }

   return(true);
}


/**
 * Prüft, ob ein String einen gültigen numerischen Wert darstellt (Zeichen 0123456789.-)
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StringIsNumeric(string value) {
   int chr, len=StringLen(value);

   if (len == 0)
      return(false);

   bool period = false;

   for (int i=0; i < len; i++) {
      chr = StringGetChar(value, i);

      if (chr == '-') {
         if (i != 0) return(false);
         continue;
      }
      if (chr == '.') {
         if (period) return(false);
         period = true;
         continue;
      }
      if (chr < '0') return(false);
      if (chr > '9') return(false);       // Conditions für MQL optimiert
   }

   return(true);
}


/**
 * Prüft, ob ein String einen gültigen Integer darstellt.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StringIsInteger(string value) {
   return(value == StringConcatenate("", StrToInteger(value)));
}


/**
 * Durchsucht einen String vom Ende aus nach einem Substring und gibt dessen Position zurück.
 *
 * @param  string object - zu durchsuchender String
 * @param  string search - zu suchender Substring
 *
 * @return int - letzte Position des Substrings oder -1, wenn der Substring nicht gefunden wurde
 */
int StringFindR(string object, string search) {
   int lenObject = StringLen(object),
       lastFound  = -1,
       result     =  0;

   for (int i=0; i < lenObject; i++) {
      result = StringFind(object, search, i);
      if (result == -1)
         break;
      lastFound = result;
   }

   if (catch("StringFindR()") != NO_ERROR)
      return(-1);
   return(lastFound);
}


/**
 * Konvertiert einen String in Kleinschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StringToLower(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      (64 < char && char < 91)              result = StringSetChar(result, i, char+32);
      //else if (char==138 || char==140 || char==142) result = StringSetChar(result, i, char+16);
      //else if (char==159)                           result = StringSetChar(result, i,     255);  // Ÿ -> ÿ
      //else if (191 < char && char < 223)            result = StringSetChar(result, i, char+32);

      // für MQL optimierte Version
      if      (char == 138)                 result = StringSetChar(result, i, char+16);
      else if (char == 140)                 result = StringSetChar(result, i, char+16);
      else if (char == 142)                 result = StringSetChar(result, i, char+16);
      else if (char == 159)                 result = StringSetChar(result, i,     255);   // Ÿ -> ÿ
      else if (char < 91) { if (char >  64) result = StringSetChar(result, i, char+32); }
      else if (191 < char)  if (char < 223) result = StringSetChar(result, i, char+32);
   }

   if (catch("StringToLower()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Konvertiert einen String in Großschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StringToUpper(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      (96 < char && char < 123)             result = StringSetChar(result, i, char-32);
      //else if (char==154 || char==156 || char==158) result = StringSetChar(result, i, char-16);
      //else if (char==255)                           result = StringSetChar(result, i,     159);  // ÿ -> Ÿ
      //else if (char > 223)                          result = StringSetChar(result, i, char-32);

      // für MQL optimierte Version
      if      (char == 255)                 result = StringSetChar(result, i,     159);   // ÿ -> Ÿ
      else if (char  > 223)                 result = StringSetChar(result, i, char-32);
      else if (char == 158)                 result = StringSetChar(result, i, char-16);
      else if (char == 156)                 result = StringSetChar(result, i, char-16);
      else if (char == 154)                 result = StringSetChar(result, i, char-16);
      else if (char  >  96) if (char < 123) result = StringSetChar(result, i, char-32);
   }

   if (catch("StringToUpper()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Trimmt einen String beidseitig.
 *
 * @param  string value
 *
 * @return string
 */
string StringTrim(string value) {
   return(StringTrimLeft(StringTrimRight(value)));
}


/**
 * URL-kodiert einen String.  Leerzeichen werden als "+"-Zeichen kodiert.
 *
 * @param  string value
 *
 * @return string - URL-kodierter String
 */
string UrlEncode(string value) {
   int char, len=StringLen(value);
   string charStr, result="";

   for (int i=0; i < len; i++) {
      charStr = StringSubstr(value, i, 1);
      char    = StringGetChar(charStr, 0);

      if ((47 < char && char < 58) || (64 < char && char < 91) || (96 < char && char < 123))
         result = StringConcatenate(result, charStr);
      else if (char == 32)
         result = StringConcatenate(result, "+");
      else
         result = StringConcatenate(result, "%", DecimalToHex(char));
   }

   if (catch("UrlEncode()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Alias für IntToHexStr()
 *
 * Konvertiert einen Integer in seine hexadezimale Representation.
 */
string IntegerToHexStr(int integer) {
   return(IntToHexStr(integer));
}


/**
 * Prüft, ob der angegebene Name eine existierende und normale Datei ist (kein Verzeichnis).
 *
 * @return string pathName - Pfadangabe
 *
 * @return bool
 */
bool IsFile(string pathName) {
   bool result = false;

   if (StringLen(pathName) > 0) {
      int /*WIN32_FIND_DATA*/ wfd[80];

      int hSearch = FindFirstFileA(pathName, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {          // TODO: konkreten Fehler prüfen
         FindClose(hSearch);
         result = !wfd.FileAttribute.Directory(wfd);
      }
   }

   catch("IsFile()");
   return(result);
}


/**
 * Prüft, ob der angegebene Name ein existierendes Verzeichnis ist (keine normale Datei).
 *
 * @return string pathName - Pfadangabe
 *
 * @return bool
 */
bool IsDirectory(string pathName) {
   bool result = false;

   if (StringLen(pathName) > 0) {
      int /*WIN32_FIND_DATA*/ wfd[80];

      int hSearch = FindFirstFileA(pathName, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {
         FindClose(hSearch);
         result = wfd.FileAttribute.Directory(wfd);
      }
   }

   catch("IsDirectory()");
   return(result);
}


/**
 * Konvertiert einen Integer in seine hexadezimale Representation.
 *
 * @param  string value
 *
 * @return string
 *
 * Beispiel: IntToHexStr(2026701066) => "78CD010A"
 */
string IntToHexStr(int integer) {
   string result = "00000000";
   int value, shift = 28;

   for (int i=0; i < 8; i++) {
      value = (integer >> shift) & 0x0F;
      if (value < 10) result = StringSetChar(result, i,  value     +'0');  // 0x30 = '0'        // Integer in Nibbles zerlegen und jedes
      else            result = StringSetChar(result, i, (value-10) +'A');  // 0x41 = 'A'        // einzelne Nibble hexadezimal darstellen
      shift -= 4;
   }
   return(result);
}


/**
 * Konvertiert drei R-G-B-Farbwerte in eine Farbe.
 *
 * @param  int red   - Rotanteil (0-255)
 * @param  int green - Grünanteil (0-255)
 * @param  int blue  - Blauanteil (0-255)
 *
 * @return color - Farbe oder -1, wenn ein Fehler auftrat
 *
 * Beispiel: RGB(255, 255, 255) => 0x00FFFFFF (weiß)
 */
color RGB(int red, int green, int blue) {
   if (0 <= red && red <= 255) {
      if (0 <= green && green <= 255) {
         if (0 <= blue && blue <= 255) {
            return(red + green<<8 + blue<<16);
         }
         else catch("RGB(1)  invalid parameter blue = "+ blue, ERR_INVALID_FUNCTION_PARAMVALUE);
      }
      else catch("RGB(2)  invalid parameter green = "+ green, ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   else catch("RGB(3)  invalid parameter red = "+ red, ERR_INVALID_FUNCTION_PARAMVALUE);

   return(-1);
}


/**
 * Konvertiert eine Farbe in ihre HTML-Repräsentation.
 *
 * @param  color rgb
 *
 * @return string - HTML-Farbwert
 *
 * Beispiel: ColorToHtmlStr(C'255,255,255') => "#FFFFFF"
 */
string ColorToHtmlStr(color rgb) {
   int red   = rgb & 0x0000FF;
   int green = rgb & 0x00FF00;
   int blue  = rgb & 0xFF0000;

   int value = red<<16 + green + blue>>16;   // rot und blau vertauschen, um IntToHexStr() benutzen zu können

   return(StringConcatenate("#", StringRight(IntToHexStr(value), 6)));
}


/**
 * Konvertiert eine Farbe in ihre RGB-Repräsentation.
 *
 * @param  color rgb
 *
 * @return string
 *
 * Beispiel: ColorToRGBStr(White) => "255,255,255"
 */
string ColorToRGBStr(color rgb) {
   int red   = rgb     & 0xFF;
   int green = rgb>> 8 & 0xFF;
   int blue  = rgb>>16 & 0xFF;

   return(StringConcatenate(red, ",", green, ",", blue));
}


/**
 * Konvertiert drei RGB-Farbwerte in den HSV-Farbraum (Hue-Saturation-Value).
 *
 * @param  int     red     - Rotanteil  (0-255)
 * @param  int     green   - Grünanteil (0-255)
 * @param  int     blue    - Blauanteil (0-255)
 * @param  double& lpHSV[] - Zeiger auf Array zur Aufnahme der HSV-Werte
 *
 * @return int - Fehlerstatus
 */
int RGBValuesToHSVColor(int red, int green, int blue, double& lpHSV[]) {
   return(RGBToHSVColor(RGB(red, green, blue), lpHSV));
}


/**
 * Konvertiert eine RGB-Farbe in den HSV-Farbraum (Hue-Saturation-Value).
 *
 * @param  color   rgb     - Farbe
 * @param  double& lpHSV[] - Zeiger auf Array zur Aufnahme der HSV-Werte
 *
 * @return int - Fehlerstatus
 */
int RGBToHSVColor(color rgb, double& lpHSV[]) {
   int red   = rgb     & 0xFF;
   int green = rgb>> 8 & 0xFF;
   int blue  = rgb>>16 & 0xFF;

   double r=red/255.0, g=green/255.0, b=blue/255.0;      // scale to unity (0-1)

   double dMin   = MathMin(r, MathMin(g, b)); int iMin   = MathMin(red, MathMin(green, blue));
   double dMax   = MathMax(r, MathMax(g, b)); int iMax   = MathMax(red, MathMax(green, blue));
   double dDelta = dMax - dMin;               int iDelta = iMax - iMin;

   double hue, sat, val=dMax;

   if (iDelta == 0) {
      hue = 0;
      sat = 0;
   }
   else {
      sat = dDelta / dMax;
      double del_R = ((dMax-r)/6 + dDelta/2) / dDelta;
      double del_G = ((dMax-g)/6 + dDelta/2) / dDelta;
      double del_B = ((dMax-b)/6 + dDelta/2) / dDelta;

      if      (red   == iMax) { hue =         del_B - del_G; }
      else if (green == iMax) { hue = 1.0/3 + del_R - del_B; }
      else if (blue  == iMax) { hue = 2.0/3 + del_G - del_R; }

      if      (hue < 0) { hue += 1; }
      else if (hue > 1) { hue -= 1; }
   }

   if (ArraySize(lpHSV) != 3)
      ArrayResize(lpHSV, 3);

   lpHSV[0] = hue * 360;
   lpHSV[1] = sat;
   lpHSV[2] = val;

   return(catch("RGBToHSVColor()"));
}


/**
 * Umrechnung einer Farbe aus dem HSV- in den RGB-Farbraum.
 *
 * @param  double hsv - HSV-Farbwerte
 *
 * @return color - Farbe oder -1, wenn ein Fehler auftrat
 */
color HSVToRGBColor(double hsv[3]) {
   if (ArrayDimension(hsv) != 1)
      return(catch("HSVToRGBColor(1)   illegal parameter hsv = "+ DoubleArrayToStr(hsv), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(hsv) != 3)
      return(catch("HSVToRGBColor(2)   illegal parameter hsv = "+ DoubleArrayToStr(hsv), ERR_INCOMPATIBLE_ARRAYS));

   return(HSVValuesToRGBColor(hsv[0], hsv[1], hsv[2]));
}


/**
 * Konvertiert drei HSV-Farbwerte in eine RGB-Farbe.
 *
 * @param  double hue        - Farbton    (0.0 - 360.0)
 * @param  double saturation - Sättigung  (0.0 - 1.0)
 * @param  double value      - Helligkeit (0.0 - 1.0)
 *
 * @return color - Farbe oder -1, wenn ein Fehler auftrat
 */
color HSVValuesToRGBColor(double hue, double saturation, double value) {
   if (hue < 0.0 || hue > 360.0) {
      catch("HSVValuesToRGBColor(1)  invalid parameter hue = "+ NumberToStr(hue, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (saturation < 0.0 || saturation > 1.0) {
      catch("HSVValuesToRGBColor(2)  invalid parameter saturation = "+ NumberToStr(saturation, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (value < 0.0 || value > 1.0) {
      catch("HSVValuesToRGBColor(3)  invalid parameter value = "+ NumberToStr(value, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   double red, green, blue;

   if (EQ(saturation, 0)) {
      red   = value;
      green = value;
      blue  = value;
   }
   else {
      double h  = hue / 60;                           // h = hue / 360 * 6
      int    i  = MathFloor(h);
      double f  = h - i;                              // f(ract) = MathMod(h, 1)
      double d1 = value * (1 - saturation        );
      double d2 = value * (1 - saturation *    f );
      double d3 = value * (1 - saturation * (1-f));

      if      (i == 0) { red = value; green = d3;    blue = d1;    }
      else if (i == 1) { red = d2;    green = value; blue = d1;    }
      else if (i == 2) { red = d1;    green = value; blue = d3;    }
      else if (i == 3) { red = d1;    green = d2;    blue = value; }
      else if (i == 4) { red = d3;    green = d1;    blue = value; }
      else             { red = value; green = d1;    blue = d2;    }
   }

   int r = MathRound(red   * 255);
   int g = MathRound(green * 255);
   int b = MathRound(blue  * 255);

   color rgb = r + g<<8 + b<<16;

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("HSVValuesToRGBColor(4)", error);
      return(-1);
   }
   return(rgb);
}


/**
 * Modifiziert die HSV-Werte einer Farbe.
 *
 * @param  color  rgb            - zu modifizierende Farbe
 * @param  double mod_hue        - Änderung des Farbtons: +/-360.0°
 * @param  double mod_saturation - Änderung der Sättigung in %
 * @param  double mod_value      - Änderung der Helligkeit in %
 *
 * @return color - modifizierte Farbe oder -1, wenn ein Fehler auftrat
 *
 * Beispiel:
 * ---------
 *   C'90,128,162' wird um 30% aufgehellt
 *   Color.ModifyHSV(C'90,128,162', NULL, NULL, 30) => C'119,168,212'
 */
color Color.ModifyHSV(color rgb, double mod_hue, double mod_saturation, double mod_value) {
   if (0 <= rgb) {
      if (-360 <= mod_hue && mod_hue <= 360) {
         if (-100 <= mod_saturation) {
            if (-100 <= mod_value) {
               // nach HSV konvertieren
               double hsv[]; RGBToHSVColor(rgb, hsv);

               // Farbton anpassen
               if (NE(mod_hue, 0)) {
                  hsv[0] += mod_hue;
                  if      (hsv[0] <   0) hsv[0] += 360;
                  else if (hsv[0] > 360) hsv[0] -= 360;
               }

               // Sättigung anpassen
               if (NE(mod_saturation, 0)) {
                  hsv[1] = hsv[1] * (1 + mod_saturation/100);
                  if (hsv[1] > 1)
                     hsv[1] = 1;    // mehr als 100% geht nicht
               }

               // Helligkeit anpassen (modifiziert HSV.value *und* HSV.saturation)
               if (NE(mod_value, 0)) {

                  // TODO: HSV.sat und HSV.val zu gleichen Teilen ändern

                  hsv[2] = hsv[2] * (1 + mod_value/100);
                  if (hsv[2] > 1)
                     hsv[2] = 1;
               }

               // zurück nach RGB konvertieren
               color result = HSVValuesToRGBColor(hsv[0], hsv[1], hsv[2]);

               int error = GetLastError();
               if (error != NO_ERROR) {
                  catch("Color.ModifyHSV(1)", error);
                  return(-1);
               }
               return(result);
            }
            else catch("Color.ModifyHSV(2)  invalid parameter mod_value = "+ NumberToStr(mod_value, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
         }
         else catch("Color.ModifyHSV(3)  invalid parameter mod_saturation = "+ NumberToStr(mod_saturation, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      }
      else catch("Color.ModifyHSV(4)  invalid parameter mod_hue = "+ NumberToStr(mod_hue, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   else catch("Color.ModifyHSV(5)  invalid parameter rgb = "+ rgb, ERR_INVALID_FUNCTION_PARAMVALUE);

   return(-1);
}


/**
 * Konvertiert einen Double in einen String mit bis zu 16 Nachkommastellen.
 *
 * @param double value  - zu konvertierender Wert
 * @param int    digits - Anzahl von Nachkommastellen
 *
 * @return string
 */
string DoubleToStrEx(double value, int digits) {
   if (digits < 0 || digits > 16) {
      catch("DoubleToStrEx()  illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }
   /*
   double decimals[17] = { 1.0,     // Der Compiler interpretiert über mehrere Zeilen verteilte Array-Initializer
                          10.0,     // als in einer Zeile stehend und gibt bei Fehlern falsche Zeilennummern zurück.
                         100.0,
                        1000.0,
                       10000.0,
                      100000.0,
                     1000000.0,
                    10000000.0,
                   100000000.0,
                  1000000000.0,
                 10000000000.0,
                100000000000.0,
               1000000000000.0,
              10000000000000.0,
             100000000000000.0,
            1000000000000000.0,
           10000000000000000.0 };
   */
   double decimals[17] = { 1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0, 1000000000.0, 10000000000.0, 100000000000.0, 1000000000000.0, 10000000000000.0, 100000000000000.0, 1000000000000000.0, 10000000000000000.0 };

   bool isNegative = false;
   if (value < 0.0) {
      isNegative = true;
      value = -value;
   }

   double integer    = MathFloor(value);
   string strInteger = DoubleToStr(integer + 0.1, 0);

   double remainder    = MathRound((value-integer) * decimals[digits]);
   string strRemainder = "";

   for (int i=0; i < digits; i++) {
      double fraction  = MathFloor(remainder/10);
      int    digit     = MathRound(remainder - fraction*10) + 0.1;
      strRemainder = digit + strRemainder;
      remainder    = fraction;
   }

   string result = strInteger;

   if (digits > 0)
      result = StringConcatenate(result, ".", strRemainder);

   if (isNegative)
      result = StringConcatenate("-", result);

   return(result);
}


/**
 * MetaQuotes-Alias für DoubleToStrEx()
 *
 * Konvertiert einen Double in einen String mit bis zu 16 Nachkommastellen.
 */
string DoubleToStrMorePrecision(double number, int precision) {
   return(DoubleToStrEx(number, precision));
}


// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //
//                                                                                    //
// MQL Utility Funktionen                                                             //
//                                                                                    //
// @see http://www.forexfactory.com/showthread.php?p=2695655                          //
//                                                                                    //
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * Returns a numeric value rounded to the specified number of decimals - works around a precision bug in MQL4.
 *
 * @param  double number
 * @param  int    decimals
 *
 * @return double - rounded value
 */
double MathRoundFix(double number, int decimals) {
   // TODO: Verarbeitung negativer decimals prüfen

   double operand = MathPow(10, decimals);
   return(MathRound(number*operand + MathSign(number)*0.000000000001) / operand);
}


/**
 * Returns the sign of a number.
 *
 * @param  double number
 *
 * @return int - sign (-1, 0, +1)
 */
int MathSign(double number) {
   if      (number > 0) return( 1);
   else if (number < 0) return(-1);
   return(0);
}


/**
 * Repeats a string.
 *
 * @param  string input - The string to be repeated.
 * @param  int    times - Number of times the input string should be repeated.
 *
 * @return string - the repeated string
 */
string StringRepeat(string input, int times) {
   if (times < 0) {
      catch("StringRepeat()  invalid parameter times: "+ times, ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   if (StringLen(input) == 0) return("");
   if (times ==  0)           return("");

   string output = input;
   for (int i=1; i < times; i++) {
      output = StringConcatenate(output, input);
   }
   return(output);
}


/**
 * Alias für NumberToStr().
 */
string FormatNumber(double number, string mask) {
   return(NumberToStr(number, mask));
}


/**
 * Formatiert einen numerischen Wert im angegebenen Format und gibt den resultierenden String zurück.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of the decimal point.
 *
 * Mask parameters:
 *
 *   n        = number of digits to the left of the decimal point, e.g. FormatNumber(123.456, "5") => "123"
 *   n.d      = number of left and right digits, e.g. FormatNumber(123.456, "5.2") => "123.45"
 *   n.       = number of left and all right digits, e.g. FormatNumber(123.456, "2.") => "23.456"
 *    .d      = all left and number of right digits, e.g. FormatNumber(123.456, ".2") => "123.45"
 *    .d'     = all left and number of right digits plus 1 additional subpip digit, e.g. FormatNumber(123.45678, ".4'") => "123.4567'8"
 *    .d+     = + anywhere right of .d in mask: all left and minimum number of right digits, e.g. FormatNumber(123.456, ".2+") => "123.456"
 *  +n.d      = + anywhere left of n. in mask: plus sign for positive values
 *    R       = round result in the last displayed digit, e.g. FormatNumber(123.456, "R3.2") => "123.46", e.g. FormatNumber(123.7, "R3") => "124"
 *    ;       = Separatoren tauschen (Europäisches Format), e.g. FormatNumber(123456.789, "6.2;") => "123456,78"
 *    ,       = Tausender-Separatoren einfügen, e.g. FormatNumber(123456.789, "6.2,") => "123,456.78"
 *    ,<char> = Tausender-Separatoren einfügen und auf <char> setzen, e.g. FormatNumber(123456.789, ", 6.2") => "123 456.78"
 *
 * @param  double number
 * @param  string mask
 *
 * @return string - formatierter String
 */
string NumberToStr(double number, string mask) {
   if (number == EMPTY_VALUE)
      number = 0;

   // === Beginn Maske parsen ===
   int maskLen = StringLen(mask);

   // zu allererst Separatorenformat erkennen
   bool swapSeparators = (StringFind(mask, ";")  > -1);
      string sepThousand=",", sepDecimal=".";
      if (swapSeparators) {
         sepThousand = ".";
         sepDecimal  = ",";
      }
      int sepPos = StringFind(mask, ",");
   bool separators = (sepPos  > -1);
      if (separators) if (sepPos+1 < maskLen) {
         sepThousand = StringSubstr(mask, sepPos+1, 1);  // user-spezifischen 1000-Separator auslesen und aus Maske löschen
         mask        = StringConcatenate(StringSubstr(mask, 0, sepPos+1), StringSubstr(mask, sepPos+2));
      }

   // white space entfernen
   mask    = StringReplace(mask, " ", "");
   maskLen = StringLen(mask);

   // Position des Dezimalpunktes
   int  dotPos   = StringFind(mask, ".");
   bool dotGiven = (dotPos > -1);
   if (!dotGiven)
      dotPos = maskLen;

   // Anzahl der linken Stellen
   int char, nLeft;
   bool nDigit;
   for (int i=0; i < dotPos; i++) {
      char = StringGetChar(mask, i);
      if ('0' <= char) if (char <= '9') {    // (0 <= char && char <= 9)
         nLeft = 10*nLeft + char-'0';
         nDigit = true;
      }
   }
   if (!nDigit) nLeft = -1;

   // Anzahl der rechten Stellen
   int nRight, nSubpip;
   if (dotGiven) {
      nDigit = false;
      for (i=dotPos+1; i < maskLen; i++) {
         char = StringGetChar(mask, i);
         if ('0' <= char && char <= '9') {   // (0 <= char && char <= 9)
            nRight = 10*nRight + char-'0';
            nDigit = true;
         }
         else if (nDigit && char == 39) {    // 39 => '
            nSubpip = nRight;
            continue;
         }
         else {
            if  (char == '+') nRight = MathMax(nRight+(nSubpip > 0), CountDecimals(number));
            else if (!nDigit) nRight = CountDecimals(number);
            break;
         }
      }
      if (nDigit) {
         if (nSubpip >  0) nRight++;
         if (nSubpip == 8) nSubpip = 0;
         nRight = MathMin(nRight, 8);
      }
   }

   // Vorzeichen
   string leadSign = "";
   if (number < 0) {
      leadSign = "-";
   }
   else if (number > 0) {
      int pos = StringFind(mask, "+");
      if (-1 < pos) if (pos < dotPos)        // (-1 < pos && pos < dotPos)
         leadSign = "+";
   }

   // übrige Modifier
   bool round = (StringFind(mask, "R")  > -1);
   //
   // === Ende Maske parsen ===

   // === Beginn Wertverarbeitung ===
   // runden
   if (round)
      number = MathRoundFix(number, nRight);
   string outStr = number;

   // negatives Vorzeichen entfernen (ist in leadSign gespeichert)
   if (number < 0)
      outStr = StringSubstr(outStr, 1);

   // auf angegebene Länge kürzen
   int dLeft = StringFind(outStr, ".");
   if (nLeft == -1) nLeft = dLeft;
   else             nLeft = MathMin(nLeft, dLeft);
   outStr = StringSubstrFix(outStr, StringLen(outStr)-9-nLeft, nLeft+(nRight>0)+nRight);

   // Dezimal-Separator anpassen
   if (swapSeparators)
      outStr = StringSetChar(outStr, nLeft, StringGetChar(sepDecimal, 0));

   // 1000er-Separatoren einfügen
   if (separators) {
      string out1;
      i = nLeft;
      while (i > 3) {
         out1 = StringSubstrFix(outStr, 0, i-3);
         if (StringGetChar(out1, i-4) == ' ')
            break;
         outStr = StringConcatenate(out1, sepThousand, StringSubstr(outStr, i-3));
         i -= 3;
      }
   }

   // Subpip-Separator einfügen
   if (nSubpip > 0)
      outStr = StringConcatenate(StringLeft(outStr, nSubpip-nRight), "'", StringRight(outStr, nRight-nSubpip));

   // Vorzeichen etc. anfügen
   outStr = StringConcatenate(leadSign, outStr);

   //Print("NumberToStr(double="+ DoubleToStr(number, 8) +", mask="+ mask +")    nLeft="+ nLeft +"    dLeft="+ dLeft +"    nRight="+ nRight +"    nSubpip="+ nSubpip +"    outStr=\""+ outStr +"\"");

   if (catch("NumberToStr()") != NO_ERROR)
      return("");
   return(outStr);
}


/**
 * TODO: Zur Zeit werden nur Market-Orders unterstützt !!!
 *
 * Drop-in-Ersatz für und erweiterte Version von OrderSend(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  string   symbol      - Symbol des Instruments          (default: aktuelles Instrument)
 * @param  int      type        - Operation type: [OP_BUY|OP_SELL|OP_BUYLIMIT|OP_SELLLIMIT|OP_BUYSTOP|OP_SELLSTOP]
 * @param  double   lots        - Transaktionsvolumen in Lots
 * @param  double   price       - Preis (nur bei pending Orders)
 * @param  int      slippage    - akzeptable Slippage in Points   (default: 0          )
 * @param  double   stopLoss    - StopLoss-Level                  (default: - kein -   )
 * @param  double   takeProfit  - TakeProfit-Level                (default: - kein -   )
 * @param  string   comment     - Orderkommentar, max. 27 Zeichen (default: - kein -   )
 * @param  int      magicNumber - MagicNumber                     (default: 0          )
 * @param  datetime expires     - Gültigkeit der Order            (default: GTC        )
 * @param  color    markerColor - Farbe des Chartmarkers          (default: kein Marker)
 *
 * @return int - Ticket-Nummer oder -1, wenn ein Fehler auftrat
 */
int OrderSendEx(string symbol/*=NULL*/, int type, double lots, double price=0, int slippage=0, double stopLoss=0, double takeProfit=0, string comment="", int magicNumber=0, datetime expires=0, color markerColor=CLR_NONE) {
   // -- Beginn Parametervalidierung --
   // symbol
   if (symbol == "0")         // = NULL
      symbol = Symbol();
   int    digits  = MarketInfo(symbol, MODE_DIGITS);
   double minLot  = MarketInfo(symbol, MODE_MINLOT);
   double maxLot  = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);
   int error  = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderSendEx(1)   symbol=\""+ symbol +"\"", error);
      return(-1);
   }
   // type
   if (!IsTradeOperationType(type)) {
      catch("OrderSendEx(2)   invalid parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // lots
   if (LT(lots, minLot)) {
      catch("OrderSendEx(3)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (GT(lots, maxLot)) {
      catch("OrderSendEx(4)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (NE(MathModFix(lots, lotStep), 0)) {
      catch("OrderSendEx(5)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0)) {
      catch("OrderSendEx(6)   illegal parameter price = "+ NumberToStr(price, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // slippage
   if (slippage < 0) {
      catch("OrderSendEx(7)   illegal parameter slippage = "+ slippage, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // stopLoss
   if (NE(stopLoss, 0)) {
      catch("OrderSendEx(8)   submission of stoploss orders is not implemented", ERR_FUNCTION_NOT_IMPLEMENTED);
      return(-1);
   }
   stopLoss = NormalizeDouble(stopLoss, digits);
   // takeProfit
   if (NE(takeProfit, 0)) {
      catch("OrderSendEx(9)   submission of take-profit orders is not implemented", ERR_FUNCTION_NOT_IMPLEMENTED);
      return(-1);
   }
   takeProfit = NormalizeDouble(takeProfit, digits);
   // comment
   if (StringLen(comment) > 27) {
      catch("OrderSendEx(10)   too long parameter comment = \""+ comment +"\" (max. 27 chars)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // expires
   if (expires!= 0 && expires <= TimeCurrent()) {
      catch("OrderSendEx(11)   illegal parameter expires = "+ ifString(expires < 0, expires, TimeToStr(expires, TIME_DATE|TIME_MINUTES|TIME_SECONDS)), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // markerColor
   if (markerColor < CLR_NONE) {       // CLR_NONE: -1
      catch("OrderSendEx(12)   illegal parameter markerColor = "+ markerColor, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   // -- Ende Parametervalidierung --


   // Endlosschleife, bis Order ausgeführt wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      if (IsTradeContextBusy()) {
         log("OrderSendEx()   trade context busy, waiting...");
      }
      else {
         if      (type == OP_BUY ) price = MarketInfo(symbol, MODE_ASK);
         else if (type == OP_SELL) price = MarketInfo(symbol, MODE_BID);
         price    = NormalizeDouble(price, digits);
         int time = GetTickCount();

         int ticket = OrderSend(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor);
         if (ticket > 0) {
            // ausführliche Logmessage generieren
            PlaySound("OrderOk.wav");
            log("OrderSendEx()   opened "+ OrderSendEx.LogMessage(ticket, type, lots, price, digits, GetTickCount()-time));
            catch("OrderSendEx(13)");
            return(ticket);                        // regular exit
         }
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))        // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;
         Alert("OrderSendEx()   temporary trade error "+ ErrorToStr(error) +", retrying...");    // Alert() nach Fertigstellung durch log() ersetzen
      }
      error = NO_ERROR;
      Sleep(300);                                  // 0.3 Sekunden warten
   }

   catch("OrderSendEx(14)   permanent trade error", error);
   return(-1);
}


/**
 * Generiert eine ausführliche Logmessage für eine erfolgreich abgeschickte oder ausgeführte Order.
 *
 * @param  int    ticket  - Ticket-Nummer der Order
 * @param  int    type    - gewünschter Ordertyp
 * @param  double lots    - gewünschtes Ordervolumen
 * @param  double price   - gewünschter Orderpreis
 * @param  int    digits  - Nachkommastellen des Ordersymbols
 * @param  int    time    - zur Orderausführung benötigte Zeit
 *
 * @return string - Logmessage
 */
/*private*/ string OrderSendEx.LogMessage(int ticket, int type, double lots, double price, int digits, int time) {
   int    pipDigits   = digits & (~1);
   double pip         = 1/MathPow(10, pipDigits);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderSendEx.LogMessage(1)   error selecting ticket #"+ ticket, error);
      return("");
   }

   string strType = OperationTypeDescription(OrderType());
   if (type != OrderType())
      strType = StringConcatenate(strType, " (instead of ", OperationTypeDescription(type), ")");

   string strLots = NumberToStr(OrderLots(), ".+");
   if (NE(lots, OrderLots()))
      strLots = StringConcatenate(strLots, " (instead of ", NumberToStr(lots, ".+"), ")");

   string strPrice = NumberToStr(OrderOpenPrice(), priceFormat);
   if (type == OrderType()) {
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         if (NE(price, OrderOpenPrice())) {
            string strSlippage = NumberToStr(MathAbs(OrderOpenPrice()-price)/pip, ".+");
            bool plus = GT(OrderOpenPrice(), price);
            if ((OrderType()==OP_BUY && plus) || (OrderType()==OP_SELL && !plus)) strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip slippage)");
            else                                                                  strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip positive slippage)");
         }
      }
      else if (NE(price, OrderOpenPrice())) {
         strPrice = StringConcatenate(strPrice, " (instead of ", NumberToStr(price, priceFormat), ")");
      }
   }

   string message = StringConcatenate("#", ticket, " ", strType, " ", strLots, " ", OrderSymbol(), " at ", strPrice);
   if (OrderMagicNumber() !=  0) message = StringConcatenate(message, ", magic=", OrderMagicNumber());
   if (OrderComment()     != "") message = StringConcatenate(message, ", comment=\"", OrderComment(), "\"");
                                 message = StringConcatenate(message, ", used time: ", time, " ms");

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderSendEx.LogMessage(2)", error);
      return("");
   }
   return(message);
}


/**
 * Drop-in-Ersatz für und erweiterte Version von OrderClose(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  int    ticket      - Ticket-Nr. der zu schließenden Position
 * @param  double lots        - zu schließendes Volumen in Lots         (default: 0 = komplette Position)
 * @param  double price       - Preis                                   (wird ignoriert                 )
 * @param  int    slippage    - akzeptable Slippage in Points           (default: 0                     )
 * @param  color  markerColor - Farbe des Chart-Markers                 (default: kein Marker           )
 *
 * @return bool - Erfolgsstatus
 */
bool OrderCloseEx(int ticket, double lots=0, double price=0, int slippage=0, color markerColor=CLR_NONE) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderCloseEx(1)   invalid parameter ticket = "+ ticket, error);
      return(false);
   }
   if (OrderCloseTime() != 0) {
      catch("OrderCloseEx(2)   ticket #"+ ticket +" is already closed", ERR_TRADE_ERROR);
      return(false);
   }
   if (OrderType()!=OP_BUY && OrderType()!=OP_SELL) {
      catch("OrderCloseEx(3)   ticket #"+ ticket +" is not an open position", ERR_TRADE_ERROR);
      return(false);
   }
   // lots
   int    digits  = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double minLot  = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderCloseEx(4)   symbol=\""+ OrderSymbol() +"\"", error);
      return(false);
   }
   if (EQ(lots, 0)) {
      lots = OrderLots();
   }
   else if (NE(lots, OrderLots())) {
      if (LT(lots, minLot)) {
         catch("OrderCloseEx(5)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (GT(lots, OrderLots())) {
         catch("OrderCloseEx(6)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (OpenLots="+ NumberToStr(OrderLots(), ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (NE(MathModFix(lots, lotStep), 0)) {
         catch("OrderCloseEx(7)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
   }
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0)) {
      catch("OrderCloseEx(8)   illegal parameter price = "+ NumberToStr(price, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   // slippage
   if (slippage < 0) {
      catch("OrderCloseEx(9)   illegal parameter slippage = "+ slippage, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   // markerColor
   if (markerColor < 0) {
      catch("OrderCloseEx(10)   illegal parameter markerColor = "+ markerColor, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   // -- Ende Parametervalidierung --


   // Endlosschleife, bis Position geschlossen wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      if (IsTradeContextBusy()) {
         log("OrderSendEx()   trade context busy, waiting...");
      }
      else {
         price = NormalizeDouble(MarketInfo(OrderSymbol(), ifInt(OrderType()==OP_BUY, MODE_BID, MODE_ASK)), digits);
         int time = GetTickCount();

         if (OrderClose(ticket, lots, price, slippage, markerColor)) {
            // ausführliche Logmessage generieren
            PlaySound("OrderOk.wav");
            log("OrderCloseEx()   closed "+ OrderCloseEx.LogMessage(ticket, lots, price, digits, GetTickCount()-time));
            return(catch("OrderCloseEx(11)")==NO_ERROR);    // regular exit
         }
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                 // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;
         Alert("OrderCloseEx()   temporary trade error "+ ErrorToStr(error) +", retrying...");    // Alert() nach Fertigstellung durch log() ersetzen
      }
      error = NO_ERROR;
      Sleep(300);                                           // 0.3 Sekunden warten
   }

   catch("OrderCloseEx(12)   permanent trade error", error);
   return(false);
}


/**
 *
 */
/*private*/ string OrderCloseEx.LogMessage(int ticket, double lots, double price, int digits, int time) {
   int    pipDigits   = digits & (~1);
   double pip         = 1/MathPow(10, pipDigits);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   // TODO: Logmessage bei partiellem Close anpassen (geschlossenes Volumen, verbleibendes Ticket#)

   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderCloseEx.LogMessage(1)   error selecting ticket #"+ ticket, error);
      return("");
   }

   string strType = OperationTypeDescription(OrderType());
   string strLots = NumberToStr(OrderLots(), ".+");

   string strPrice = NumberToStr(OrderClosePrice(), priceFormat);
   if (NE(price, OrderClosePrice())) {
      string strSlippage = NumberToStr(MathAbs(OrderClosePrice()-price)/pip, ".+");
      bool plus = GT(OrderClosePrice(), price);
      if ((OrderType()==OP_BUY && !plus) || (OrderType()==OP_SELL && plus)) strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip slippage)");
      else                                                                  strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip positive slippage)");
   }

   string message = StringConcatenate("#", ticket, " ", strType, " ", strLots, " ", OrderSymbol(), " at ", strPrice, ", used time: ", time, " ms");

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderCloseEx.LogMessage(2)", error);
      return("");
   }
   return(message);
}














// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * This formats a number (int or double) into a string, performing alignment, rounding, inserting commas (0,000,000 etc), floating signs, currency symbols, and so forth, according to the instructions provided in the 'mask'.
 *
 * The basic mask is "n" or "n.d" where n is the number of digits to the left of the decimal point, and d the number to the right,
 * e.g. NumberToStr(123.456,"5") will return "<space><space>123"
 * e.g. NumberToStr(123.456,"5.2") will return "<space><space>123.45"
 *
 * Other characters that may be used in the mask:
 *
 *    - Including a "-" anywhere to the left of "n.d" will cause a floating minus symbol to be included to the left of the number, if the nunber is negative; no symbol if positive
 *    - Including a "+" anywhere to the left of "n.d" will cause a floating plus or minus symbol to be included, to the left of the number
 *    - Including a "-" anywhere to the right of "n.d" will cause a minus to be included at the right of the number, e.g. NumberToStr(-123.456,"3.2-") will return "123.46-"
 *    - Including a "(" or ")" anywhere in the mask will cause any negative number to be enclosed in parentheses
 *    - Including an "R" or "r" anywhere in the mask will cause rounding, e.g. NumberToStr(123.456,"R3.2") will return "123.46"; e.g. NumberToStr(123.7,"R3") will return "124"
 *    - Including a "$", "€", "£" or "¥" anywhere in the mask will cause the designated floating currency symbol to be included, to the left of the number
 *    - Including a "," anywhere in the mask will cause commas to be inserted between every 3 digits, to separate thousands, millions, etc at the left of the number, e.g. NumberToStr(123456.789,",6.3") will return "123,456.789"
 *    - Including a "Z" or "z" anywhere in the mask will cause zeros (instead of spaces) to be used to fill any unused places at the left of the number, e.g. NumberToStr(123.456,"Z5.2") will return "00123.45"
 *    - Including a "B" or "b" anywhere in the mask ("blank if zero") will cause the entire output to be blanks, if the value of the number is zero
 *    - Including a "*" anywhere in the mask will cause an asterisk to be output, if overflow occurs (the value of n in "n.d" is too small to allow the number to be output in full)
 *    - Including a "L" or "l" anywhere in the mask will cause the output to be left aligned in the output field, e.g. NumberToStr(123.456,"L5.2") will return "123.45<space><space>"
 *    - Including a "T" or "t" anywhere in the mask will cause the output to be left aligned in the output field, and trailing spaces trimmed e.g. NumberToStr(123.456,"T5.2") will return "123.45"
 *    - Including a ";" anywhere in the mask will cause decimal point and comma to be juxtaposed, e.g. NumberToStr(123456.789,";,6.3") will return "123.456,789"
 *
 * ==================================================================================================================================================================
 *
 * Formats a number using a mask, and returns the resulting string
 *
 * Mask parameters:
 * n = number of digits to output, to the left of the decimal point
 * n.d = output n digits to left of decimal point; d digits to the right
 * -n.d = floating minus sign at left of output
 * n.d- = minus sign at right of output
 * +n.d = floating plus/minus sign at left of output
 * ( or ) = enclose negative number in parentheses
 * $ or £ or ¥ or € = include floating currency symbol at left of output
 * % = include trailing % sign
 * , = use commas to separate thousands
 * Z or z = left fill with zeros instead of spaces
 * R or r = round result in rightmost displayed digit
 * B or b = blank entire field if number is 0
 * * = show asterisk in leftmost position if overflow occurs
 * ; = switch use of comma and period (European format)
 * L or l = left align final string
 * T ot t = trim end result
 */
string orig_NumberToStr(double n, string mask) {
   if (MathAbs(n) == EMPTY_VALUE)
      n = 0;

   mask = StringToUpper(mask);
   int dotadj = 0;
   int dot    = StringFind(mask, ".");
   if (dot < 0) {
      dot    = StringLen(mask);
      dotadj = 1;
   }

   int nleft  = 0;
   int nright = 0;

   for (int i=0; i < dot; i++) {
      string char = StringSubstr(mask, i, 1);
      if (char >= "0" && char <= "9")
         nleft = 10*nleft + StrToInteger(char);
   }
   if (dotadj == 0) {
      for (i=dot+1; i <= StringLen(mask); i++) {
         char = StringSubstr(mask, i, 1);
         if (char >= "0" && char <= "9")
            nright = 10*nright + StrToInteger(char);
      }
   }
   nright = MathMin(nright, 7);

   if (dotadj == 1) {
      for (i=0; i < StringLen(mask); i++) {
         char = StringSubstr(mask, i, 1);
         if (char >= "0" && char <= "9") {
            dot = i;
            break;
         }
      }
   }

   string csym = "";
   if (StringFind(mask, "$") > -1) csym = "$";
   if (StringFind(mask, "£") > -1) csym = "£";
   if (StringFind(mask, "€") > -1) csym = "€";
   if (StringFind(mask, "¥") > -1) csym = "¥";

   string leadsign  = "";
   string trailsign = "";

   if (StringFind(mask, "+") > -1 && StringFind(mask, "+") < dot) {
      leadsign = " ";
      if (n > 0) leadsign = "+";
      if (n < 0) leadsign = "-";
   }
   if (StringFind(mask, "-") > -1 && StringFind(mask, "-") < dot) {
      if (n < 0) leadsign = "-";
      else       leadsign = " ";
   }
   if (StringFind(mask, "-") > -1 && StringFind(mask, "-") > dot) {
      if (n < 0) trailsign = "-";
      else       trailsign = " ";
   }
   if (StringFind(mask, "(") > -1 || StringFind(mask, ")") > -1) {
      leadsign  = " ";
      trailsign = " ";
      if (n < 0) {
         leadsign  = "(";
         trailsign = ")";
      }
   }
   if (StringFind(mask, "%") > -1)
      trailsign = "%" + trailsign;

   bool comma = (StringFind(mask, ",") > -1);
   bool zeros = (StringFind(mask, "Z") > -1);
   bool blank = (StringFind(mask, "B") > -1);
   bool round = (StringFind(mask, "R") > -1);
   bool overf = (StringFind(mask, "*") > -1);
   bool lftsh = (StringFind(mask, "L") > -1);
   bool swtch = (StringFind(mask, ";") > -1);
   bool trimf = (StringFind(mask, "T") > -1);

   if (round)
      n = MathRoundFix(n, nright);
   string outstr = n;

   int dleft = 0;
   for (i=0; i < StringLen(outstr); i++) {
      char = StringSubstr(outstr, i, 1);
      if (char >= "0" && char <= "9")
         dleft++;
      if (char == ".")
         break;
   }

   // Insert fill characters.......
   if (zeros) string fill = "0";
   else              fill = " ";
   if (n < 0) outstr = "-" + StringRepeat(fill, nleft-dleft) + StringSubstr(outstr, 1);
   else       outstr = StringRepeat(fill, nleft-dleft) + outstr;
   outstr = StringSubstrFix(outstr, StringLen(outstr)-9-nleft, nleft+1+nright-dotadj);

   // Insert the commas.......
   if (comma) {
      bool digflg = false;
      bool stpflg = false;
      string out1 = "";
      string out2 = "";
      for (i=0; i < StringLen(outstr); i++) {
         char = StringSubstr(outstr, i, 1);
         if (char == ".")
            stpflg = true;
         if (!stpflg && (nleft-i==3 || nleft-i==6 || nleft-i==9)) {
            if (digflg) out1 = out1 +",";
            else        out1 = out1 +" ";
         }
         out1 = out1 + char;
         if (char >= "0" && char <= "9")
            digflg = true;
      }
      outstr = out1;
   }

   // Add currency symbol and signs........
   outstr = csym + leadsign + outstr + trailsign;

   // 'Float' the currency symbol/sign.......
   out1 = "";
   out2 = "";
   bool fltflg = true;
   for (i=0; i < StringLen(outstr); i++) {
      char = StringSubstr(outstr, i, 1);
      if (char >= "0" && char <= "9")
         fltflg = false;
      if ((char==" " && fltflg) || (blank && n==0)) out1 = out1 + " ";
      else                                          out2 = out2 + char;
   }
   outstr = out1 + out2;

   // Overflow........
   if (overf && dleft > nleft)
      outstr = "*" + StringSubstr(outstr, 1);

   // Left shift.......
   if (lftsh) {
      int len = StringLen(outstr);
      outstr = StringTrimLeft(outstr);
      outstr = outstr + StringRepeat(" ", len-StringLen(outstr));
   }

   // Switch period and comma.......
   if (swtch) {
      out1 = "";
      for (i=0; i < StringLen(outstr); i++) {
         char = StringSubstr(outstr, i, 1);
         if      (char == ".") out1 = out1 +",";
         else if (char == ",") out1 = out1 +".";
         else                  out1 = out1 + char;
      }
      outstr = out1;
   }

   if (trimf)
      outstr = StringTrim(outstr);
   return(outstr);
}


/**
 * Returns the numeric value for an MQL4 color descriptor string.
 *
 *  Usage: StrToColor("Aqua")       => 16776960
 *  or:    StrToColor("0,255,255")  => 16776960  i.e. StrToColor("<red>,<green>,<blue>")
 *  or:    StrToColor("r0g255b255") => 16776960  i.e. StrToColor("r<nnn>g<nnn>b<nnn>")
 *  or:    StrToColor("0xFFFF00")   => 16776960  i.e. StrToColor("0xbbggrr")
 */
int StrToColor(string str) {
   str = StringToLower(str);

   if (str == "aliceblue"        ) return(0xFFF8F0);
   if (str == "antiquewhite"     ) return(0xD7EBFA);
   if (str == "aqua"             ) return(0xFFFF00);
   if (str == "aquamarine"       ) return(0xD4FF7F);
   if (str == "beige"            ) return(0xDCF5F5);
   if (str == "bisque"           ) return(0xC4E4FF);
   if (str == "black"            ) return(0x000000);
   if (str == "blanchedalmond"   ) return(0xCDEBFF);
   if (str == "blue"             ) return(0xFF0000);
   if (str == "blueviolet"       ) return(0xE22B8A);
   if (str == "brown"            ) return(0x2A2AA5);
   if (str == "burlywood"        ) return(0x87B8DE);
   if (str == "cadetblue"        ) return(0xA09E5F);
   if (str == "chartreuse"       ) return(0x00FF7F);
   if (str == "chocolate"        ) return(0x1E69D2);
   if (str == "coral"            ) return(0x507FFF);
   if (str == "cornflowerblue"   ) return(0xED9564);
   if (str == "cornsilk"         ) return(0xDCF8FF);
   if (str == "crimson"          ) return(0x3C14DC);
   if (str == "darkblue"         ) return(0x8B0000);
   if (str == "darkgoldenrod"    ) return(0x0B86B8);
   if (str == "darkgray"         ) return(0xA9A9A9);
   if (str == "darkgreen"        ) return(0x006400);
   if (str == "darkkhaki"        ) return(0x6BB7BD);
   if (str == "darkolivegreen"   ) return(0x2F6B55);
   if (str == "darkorange"       ) return(0x008CFF);
   if (str == "darkorchid"       ) return(0xCC3299);
   if (str == "darksalmon"       ) return(0x7A96E9);
   if (str == "darkseagreen"     ) return(0x8BBC8F);
   if (str == "darkslateblue"    ) return(0x8B3D48);
   if (str == "darkslategray"    ) return(0x4F4F2F);
   if (str == "darkturquoise"    ) return(0xD1CE00);
   if (str == "darkviolet"       ) return(0xD30094);
   if (str == "deeppink"         ) return(0x9314FF);
   if (str == "deepskyblue"      ) return(0xFFBF00);
   if (str == "dimgray"          ) return(0x696969);
   if (str == "dodgerblue"       ) return(0xFF901E);
   if (str == "firebrick"        ) return(0x2222B2);
   if (str == "forestgreen"      ) return(0x228B22);
   if (str == "gainsboro"        ) return(0xDCDCDC);
   if (str == "gold"             ) return(0x00D7FF);
   if (str == "goldenrod"        ) return(0x20A5DA);
   if (str == "gray"             ) return(0x808080);
   if (str == "green"            ) return(0x008000);
   if (str == "greenyellow"      ) return(0x2FFFAD);
   if (str == "honeydew"         ) return(0xF0FFF0);
   if (str == "hotpink"          ) return(0xB469FF);
   if (str == "indianred"        ) return(0x5C5CCD);
   if (str == "indigo"           ) return(0x82004B);
   if (str == "ivory"            ) return(0xF0FFFF);
   if (str == "khaki"            ) return(0x8CE6F0);
   if (str == "lavender"         ) return(0xFAE6E6);
   if (str == "lavenderblush"    ) return(0xF5F0FF);
   if (str == "lawngreen"        ) return(0x00FC7C);
   if (str == "lemonchiffon"     ) return(0xCDFAFF);
   if (str == "lightblue"        ) return(0xE6D8AD);
   if (str == "lightcoral"       ) return(0x8080F0);
   if (str == "lightcyan"        ) return(0xFFFFE0);
   if (str == "lightgoldenrod"   ) return(0xD2FAFA);
   if (str == "lightgray"        ) return(0xD3D3D3);
   if (str == "lightgreen"       ) return(0x90EE90);
   if (str == "lightpink"        ) return(0xC1B6FF);
   if (str == "lightsalmon"      ) return(0x7AA0FF);
   if (str == "lightseagreen"    ) return(0xAAB220);
   if (str == "lightskyblue"     ) return(0xFACE87);
   if (str == "lightslategray"   ) return(0x998877);
   if (str == "lightsteelblue"   ) return(0xDEC4B0);
   if (str == "lightyellow"      ) return(0xE0FFFF);
   if (str == "lime"             ) return(0x00FF00);
   if (str == "limegreen"        ) return(0x32CD32);
   if (str == "linen"            ) return(0xE6F0FA);
   if (str == "magenta"          ) return(0xFF00FF);
   if (str == "maroon"           ) return(0x000080);
   if (str == "mediumaquamarine" ) return(0xAACD66);
   if (str == "mediumblue"       ) return(0xCD0000);
   if (str == "mediumorchid"     ) return(0xD355BA);
   if (str == "mediumpurple"     ) return(0xDB7093);
   if (str == "mediumseagreen"   ) return(0x71B33C);
   if (str == "mediumslateblue"  ) return(0xEE687B);
   if (str == "mediumspringgreen") return(0x9AFA00);
   if (str == "mediumturquoise"  ) return(0xCCD148);
   if (str == "mediumvioletred"  ) return(0x8515C7);
   if (str == "midnightblue"     ) return(0x701919);
   if (str == "mintcream"        ) return(0xFAFFF5);
   if (str == "mistyrose"        ) return(0xE1E4FF);
   if (str == "moccasin"         ) return(0xB5E4FF);
   if (str == "navajowhite"      ) return(0xADDEFF);
   if (str == "navy"             ) return(0x800000);
   if (str == "none"             ) return(      -1);
   if (str == "oldlace"          ) return(0xE6F5FD);
   if (str == "olive"            ) return(0x008080);
   if (str == "olivedrab"        ) return(0x238E6B);
   if (str == "orange"           ) return(0x00A5FF);
   if (str == "orangered"        ) return(0x0045FF);
   if (str == "orchid"           ) return(0xD670DA);
   if (str == "palegoldenrod"    ) return(0xAAE8EE);
   if (str == "palegreen"        ) return(0x98FB98);
   if (str == "paleturquoise"    ) return(0xEEEEAF);
   if (str == "palevioletred"    ) return(0x9370DB);
   if (str == "papayawhip"       ) return(0xD5EFFF);
   if (str == "peachpuff"        ) return(0xB9DAFF);
   if (str == "peru"             ) return(0x3F85CD);
   if (str == "pink"             ) return(0xCBC0FF);
   if (str == "plum"             ) return(0xDDA0DD);
   if (str == "powderblue"       ) return(0xE6E0B0);
   if (str == "purple"           ) return(0x800080);
   if (str == "red"              ) return(0x0000FF);
   if (str == "rosybrown"        ) return(0x8F8FBC);
   if (str == "royalblue"        ) return(0xE16941);
   if (str == "saddlebrown"      ) return(0x13458B);
   if (str == "salmon"           ) return(0x7280FA);
   if (str == "sandybrown"       ) return(0x60A4F4);
   if (str == "seagreen"         ) return(0x578B2E);
   if (str == "seashell"         ) return(0xEEF5FF);
   if (str == "sienna"           ) return(0x2D52A0);
   if (str == "silver"           ) return(0xC0C0C0);
   if (str == "skyblue"          ) return(0xEBCE87);
   if (str == "slateblue"        ) return(0xCD5A6A);
   if (str == "slategray"        ) return(0x908070);
   if (str == "snow"             ) return(0xFAFAFF);
   if (str == "springgreen"      ) return(0x7FFF00);
   if (str == "steelblue"        ) return(0xB48246);
   if (str == "tan"              ) return(0x8CB4D2);
   if (str == "teal"             ) return(0x808000);
   if (str == "thistle"          ) return(0xD8BFD8);
   if (str == "tomato"           ) return(0x4763FF);
   if (str == "turquoise"        ) return(0xD0E040);
   if (str == "violet"           ) return(0xEE82EE);
   if (str == "wheat"            ) return(0xB3DEF5);
   if (str == "white"            ) return(0xFFFFFF);
   if (str == "whitesmoke"       ) return(0xF5F5F5);
   if (str == "yellow"           ) return(0x00FFFF);
   if (str == "yellowgreen"      ) return(0x32CD9A);

   int t1 = StringFind(str, ",", 0);
   int t2 = StringFind(str, ",", t1+1);

   if (t1>0 && t2>0) {
      int red   = StrToInteger(StringSubstrFix(str, 0, t1));
      int green = StrToInteger(StringSubstrFix(str, t1+1, t2-1));
      int blue  = StrToInteger(StringSubstr(str, t2+1));
      return(blue*256*256 + green*256 + red);
   }

   if (StringSubstr(str, 0, 2) == "0x") {
      string cnvstr = "0123456789abcdef";
      string seq    = "234567";
      int    retval = 0;
      for (int i=0; i < 6; i++) {
         int pos = StrToInteger(StringSubstr(seq, i, 1));
         int val = StringFind(cnvstr, StringSubstr(str, pos, 1), 0);
         if (val < 0)
            return(val);
         retval = retval * 16 + val;
      }
      return(retval);
   }

   string cclr = "", tmp = "";
   red   = 0;
   blue  = 0;
   green = 0;

   if (StringFind("rgb", StringSubstr(str, 0, 1)) >= 0) {
      for (i=0; i < StringLen(str); i++) {
         tmp = StringSubstr(str, i, 1);
         if (StringFind("rgb", tmp, 0) >= 0)
            cclr = tmp;
         else {
            if (cclr == "b") blue  = blue  * 10 + StrToInteger(tmp);
            if (cclr == "g") green = green * 10 + StrToInteger(tmp);
            if (cclr == "r") red   = red   * 10 + StrToInteger(tmp);
         }
      }
      return(blue*256*256 + green*256 + red);
   }

   return(0);
}


/**
 * Converts a timeframe string to its MT4-numeric value
 * Usage:   int x=StrToTF("M15")   returns x=15
 */
int StrToTF(string str) {
   str = StringToUpper(str);
   if (str == "M1" ) return(    1);
   if (str == "M5" ) return(    5);
   if (str == "M15") return(   15);
   if (str == "M30") return(   30);
   if (str == "H1" ) return(   60);
   if (str == "H4" ) return(  240);
   if (str == "D1" ) return( 1440);
   if (str == "W1" ) return(10080);
   if (str == "MN" ) return(43200);
   return(0);
}


/**
 * Converts a MT4-numeric timeframe to its descriptor string
 * Usage:   string s=TFToStr(15) returns s="M15"
 */
string TFToStr(int tf) {
   switch (tf) {
      case     1: return("M1" );
      case     5: return("M5" );
      case    15: return("M15");
      case    30: return("M30");
      case    60: return("H1" );
      case   240: return("H4" );
      case  1440: return("D1" );
      case 10080: return("W1" );
      case 43200: return("MN" );
   }
   return(0);
}


/**
 * Prepends occurrences of the string STR2 to the string STR to make a string N characters long
 * Usage:    string x=StringLeftPad("ABCDEFG",9," ")  returns x = "  ABCDEFG"
 */
string StringLeftPad(string str, int n, string str2) {
   return(StringRepeat(str2, n-StringLen(str)) + str);
}


/**
 * Appends occurrences of the string STR2 to the string STR to make a string N characters long
 * Usage:    string x=StringRightPad("ABCDEFG",9," ")  returns x = "ABCDEFG  "
 */
string StringRightPad(string str, int n, string str2) {
   return(str + StringRepeat(str2, n-StringLen(str)));
}


/**
 *
 */
string StringReverse(string str) {
   string outstr = "";
   for (int i=StringLen(str)-1; i >= 0; i--) {
      outstr = outstr + StringSubstr(str,i,1);
   }
   return(outstr);
}


/**
 *
 */
string StringLeftExtract(string str, int n, string str2, int m) {
   if (n > 0) {
      int j = -1;
      for (int i=1; i <= n; i++) {
         j = StringFind(str, str2, j+1);
      }
      if (j > 0)
         return(StringLeft(str, j+m));
   }

   if (n < 0) {
      int c = 0;
      j = 0;
      for (i=StringLen(str)-1; i >= 0; i--) {
         if (StringSubstrFix(str, i, StringLen(str2)) == str2) {
            c++;
            if (c == -n) {
               j = i;
               break;
            }
         }
      }
      if (j > 0)
         return(StringLeft(str, j+m));
   }
   return("");
}


/**
 *
 */
string StringRightExtract(string str, int n, string str2, int m) {
   if (n > 0) {
      int j = -1;
      for (int i=1; i <= n; i++) {
         j=StringFind(str,str2,j+1);
      }
      if (j > 0)
         return(StringRight(str, StringLen(str)-j-1+m));
   }

   if (n < 0) {
      int c = 0;
      j = 0;
      for (i=StringLen(str)-1; i >= 0; i--) {
         if (StringSubstrFix(str, i, StringLen(str2)) == str2) {
            c++;
            if (c == -n) {
               j = i;
               break;
            }
         }
      }
      if (j > 0)
         return(StringRight(str, StringLen(str)-j-1+m));
   }
   return("");
}


/**
 * Returns the number of occurrences of STR2 in STR
 * Usage:   int x = StringFindCount("ABCDEFGHIJKABACABB","AB")   returns x = 3
 */
int StringFindCount(string str, string str2) {
   int c = 0;
   for (int i=0; i < StringLen(str); i++) {
      if (StringSubstrFix(str, i, StringLen(str2)) == str2)
         c++;
   }
   return(c);
}


/**
 *
 */
double MathInt(double n, int d) {
   return(MathFloor(n*MathPow(10, d) + 0.000000000001) / MathPow(10, d));
}


/**
 * Converts a datetime value to a formatted string, according to the instructions in the 'mask'.
 *
 *    - A "d" in the mask will cause a 1-2 digit day-of-the-month to be inserted in the output, at that point
 *    - A "D" in the mask will cause a 2 digit day-of-the-month to be inserted in the output, at that point
 *    - A "m" in the mask will cause a 1-2 digit month number to be inserted in the output, at that point
 *    - A "M" in the mask will cause a 2 digit month number to be inserted in the output, at that point
 *    - A "y" in the mask will cause a 2 digit year to be inserted in the output, at that point
 *    - A "Y" in the mask will cause a 4 digit (Y2K compliant) year to be inserted in the output, at that point
 *    - A "W" in the mask will cause a day-of-the week ("Monday", "Tuesday", etc) description to be inserted in the output, at that point
 *    - A "w" in the mask will cause an abbreviated day-of-the week ("Mon", "Tue", etc) description to be inserted in the output, at that point
 *    - A "N" in the mask will cause a month name ("January", "February", etc) to be inserted in the output, at that point
 *    - A "n" in the mask will cause an abbreviated month name ("Jan", "Feb", etc) to be inserted in the output, at that point
 *    - A "h" in the mask will cause the hour-of-the-day to be inserted in the output, as 1 or 2 digits, at that point
 *    - A "H" in the mask will cause the hour-of-the-day to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - An "I" or "i" in the mask will cause the minutes to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - A "S" or "s" in the mask will cause the seconds to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - An "a" in the mask will cause a 12-hour version of the time to be displayed, with "am" or "pm" at that point
 *    - An "A" in the mask will cause a 12-hour version of the time to be displayed, with "AM" or "PM" at that point
 *    - A "T" in the mask will cause "st" "nd" rd" or "th" to be inserted at that point, depending on the day of the month e.g. 13th, 22nd, etc
 *    - All other characters in the mask will be output, as is
 *
 * Examples: if date is June 04, 2009, then:
 *
 *    - DateToStr(date, "w m/d/Y") will output "Thu 6/4/2009"
 *    - DateToStr(date, "Y-MD") will output "2009-0604"
 *    - DateToStr(date, "d N, Y is a W") will output "4 June, 2009 is a Thursday"
 *    - DateToStr(date, "W D`M`y = W") will output "Thursday 04`06`09 = Thursday"
 */
string DateToStr(datetime mt4date, string mask) {
   int dd  = TimeDay(mt4date);
   int mm  = TimeMonth(mt4date);
   int yy  = TimeYear(mt4date);
   int dw  = TimeDayOfWeek(mt4date);
   int hr  = TimeHour(mt4date);
   int min = TimeMinute(mt4date);
   int sec = TimeSeconds(mt4date);
   int h12 = 12;
   if      (hr > 12) h12 = hr - 12;
   else if (hr >  0) h12 = hr;

   string ampm = "am";
   if (hr > 12)
      ampm = "pm";

   switch (dd % 10) {
      case 1: string d10 = "st"; break;
      case 2:        d10 = "nd"; break;
      case 3:        d10 = "rd"; break;
      default:       d10 = "th";
   }
   if (dd > 10 && dd < 14)
      d10 = "th";

   string mth[12] = { "January","February","March","April","May","June","July","August","September","October","November","December" };
   string dow[ 7] = { "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday" };

   string outdate = "";

   for (int i=0; i < StringLen(mask); i++) {
      string char = StringSubstr(mask, i, 1);
      if      (char == "d")                outdate = outdate + StringTrim(NumberToStr(dd, "2"));
      else if (char == "D")                outdate = outdate + StringTrim(NumberToStr(dd, "Z2"));
      else if (char == "m")                outdate = outdate + StringTrim(NumberToStr(mm, "2"));
      else if (char == "M")                outdate = outdate + StringTrim(NumberToStr(mm, "Z2"));
      else if (char == "y")                outdate = outdate + StringTrim(NumberToStr(yy, "2"));
      else if (char == "Y")                outdate = outdate + StringTrim(NumberToStr(yy, "4"));
      else if (char == "n")                outdate = outdate + StringSubstr(mth[mm-1], 0, 3);
      else if (char == "N")                outdate = outdate + mth[mm-1];
      else if (char == "w")                outdate = outdate + StringSubstr(dow[dw], 0, 3);
      else if (char == "W")                outdate = outdate + dow[dw];
      else if (char == "h")                outdate = outdate + StringTrim(NumberToStr(h12, "2"));
      else if (char == "H")                outdate = outdate + StringTrim(NumberToStr(hr, "Z2"));
      else if (StringToUpper(char) == "I") outdate = outdate + StringTrim(NumberToStr(min, "Z2"));
      else if (StringToUpper(char) == "S") outdate = outdate + StringTrim(NumberToStr(sec, "Z2"));
      else if (char == "a")                outdate = outdate + ampm;
      else if (char == "A")                outdate = outdate + StringToUpper(ampm);
      else if (StringToUpper(char) == "T") outdate = outdate + d10;
      else                                 outdate = outdate + char;
   }
   return(outdate);
}


/**
 * Returns the base 10 version of a number in another base
 * Usage:   int x=BaseToNumber("DC",16)   returns x=220
 */
int BaseToNumber(string str, int base) {
   str = StringToUpper(str);
   string cnvstr = "0123456789ABCDEF";
   int    retval = 0;
   for (int i=0; i < StringLen(str); i++) {
      int val = StringFind(cnvstr, StringSubstr(str, i, 1), 0);
      if (val < 0)
         return(val);
      retval = retval * base + val;
   }
   return(retval);
}


/**
 * Converts a base 10 number to another base, left-padded with zeros
 * Usage:   int x=BaseToNumber(220,16,4)   returns x="00DC"
 */
string NumberToBase(int n, int base, int pad) {
   string cnvstr = "0123456789ABCDEF";
   string outstr = "";
   while (n > 0) {
      int x = n % base;
      outstr = StringSubstr(cnvstr, x, 1) + outstr;
      n /= base;
   }
   x = StringLen(outstr);
   if (x < pad)
      outstr = StringRepeat("0", pad-x) + outstr;
   return(outstr);
}