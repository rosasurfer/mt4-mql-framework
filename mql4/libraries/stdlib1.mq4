/**
 * Datentypen und Speichergrößen in C, Win32-API (16-bit word size) und MQL:
 * =========================================================================
 *
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |        |                 |              max(hex) |            signed range(dec) |            unsigned range(dec) |       C        |        Win32        |      MQL       |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |  1 bit |                 |                  0x01 |                      0 ... 1 |                        0 ... 1 |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        | 1 byte |  8 bit | 2 nibbles       |                  0xFF |                 -128 ... 127 |                      0 ... 255 |                |      BYTE,CHAR      |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         | 1 word | 2 byte | 16 bit | HIBYTE + LOBYTE |                0xFFFF |           -32.768 ... 32.767 |                   0 ... 65.535 |     short      |   SHORT,WORD,WCHAR  |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         | 1 dword | 2 word | 4 byte | 32 bit | HIWORD + LOWORD |            0xFFFFFFFF |               -2.147.483.648 |                              0 | int,long,float | BOOL,INT,LONG,DWORD |  bool,char,int |
 * |         |         |        |        |        |                 |                       |                2.147.483.647 |                  4.294.967.295 |                |    WPARAM,LPARAM    | color,datetime |
 * |         |         |        |        |        |                 |                       |                              |                                |                | (handles, pointers) |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * | 1 qword | 2 dword | 4 word | 8 byte | 64 bit |                 | 0xFFFFFFFF 0xFFFFFFFF |   -9.223.372.036.854.775.808 |                              0 |     double     |  LONGLONG,DWORDLONG |  double,string | MQL-double: 53 bit Mantisse (Integers bis 53 bit ohne Genauigkeitsverlust)
 * |         |         |        |        |        |                 |                       |    9.223.372.036.854.775.807 |     18.446.744.073.709.551.616 |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 */
#property library
#property stacksize  32768


#include <types.mqh>
int         __TYPE__ = T_LIBRARY;
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <timezones.mqh>
#include <win32api.mqh>


#import "stdlib2.ex4"
   int GetPrivateProfileKeys.2(string fileName, string section, string keys[]);
#import


/**
 * Initialisierung der Library. Informiert die Library über das Aufrufen der init()-Funktion des laufenden Programms.
 *
 * @param  int    type               - Programmtyp
 * @param  string name               - Programmname
 * @param  int    whereami           - ID der vom Terminal ausgeführten Basis-Function: FUNC_INIT | FUNC_START | FUNC_DEINIT
 * @param  int    initFlags          - durchzuführende Initialisierungstasks (default: keine)
 * @param  int    uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int stdlib_init(int type, string name, int whereami, int initFlags, int uninitializeReason) { /*throws ERR_TERMINAL_NOT_YET_READY*/
   __TYPE__                      |= type;
   __NAME__                       = StringConcatenate(name, "::", WindowExpertName());
   __WHEREAMI__                   = whereami;
   __LOG_INSTANCE_ID              = initFlags & LOG_INSTANCE_ID;
   __LOG_PER_INSTANCE             = initFlags & LOG_PER_INSTANCE;
   bool _INIT_TIMEZONE            = initFlags & INIT_TIMEZONE;
   bool _INIT_TICKVALUE           = initFlags & INIT_TICKVALUE;
   bool _INIT_BARS_ON_HIST_UPDATE = initFlags & INIT_BARS_ON_HIST_UPDATE;

   if (__STATUS__CANCELLED) return(NO_ERROR);

   prev_error = last_error;
   last_error = NO_ERROR;                                                     // last_error sichern und zurücksetzen

   if (This.IsTesting())
      __LOG = (__LOG && GetGlobalConfigBool(name, "Logger.Tester", true));


   // (1) globale Variablen re-initialisieren
   PipDigits   = Digits & (~1);
   PipPoints   = Round(MathPow(10, Digits-PipDigits)); PipPoint = PipPoints;
   Pip         =     1/MathPow(10, PipDigits);         Pips     = Pip;
   PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));
   TickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);

   int error = GetLastError();                                                // Symbol nicht subscribed (Start, Account- oder Templatewechsel),
   if (error == ERR_UNKNOWN_SYMBOL) {                                         // das Symbol kann später evt. noch "auftauchen"
      debug("stdlib_init()   ERR_TERMINAL_NOT_YET_READY (MarketInfo() => ERR_UNKNOWN_SYMBOL)");
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   }
   if (IsError(error))        return(catch("stdlib_init(1)", error));
   if (TickSize < 0.00000001) return(catch("stdlib_init(2)   TickSize = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKET_DATA));


   // (2) Interne Variablen, die später u.U. nicht mehr ermittelbar sind, zu Beginn bestimmen und cachen
   if (GetApplicationMainWindow() == 0)                                       // Programme können noch laufen, wenn das Hauptfenster bereits nicht mehr existiert
      return(last_error);                                                     // (z.B. im Tester bei Shutdown).
   if (GetUIThreadId() == 0)                                                  // GetUIThreadId() ist auf ein gültiges Hauptfenster-Handle angewiesen; siehe GetApplicationMainWindow()
      return(last_error);


   // (3) User-spezifische Init-Tasks ausführen
   if (_INIT_TIMEZONE) {                                                      // Zeitzonen-Konfiguration überprüfen
      if (GetServerTimezone() == "")
         return(last_error);
   }


   // (4) für EA's durchzuführende globale Initialisierungen
   if (IsExpert()) {                                                          // nach Neuladen Orderkontext der Library wegen Bug ausdrücklich zurücksetzen (siehe MQL.doc)
      int reasons[] = { REASON_ACCOUNT, REASON_REMOVE, REASON_UNDEFINED, REASON_CHARTCLOSE };
      if (IntInArray(reasons, uninitializeReason))
         OrderSelect(0, SELECT_BY_TICKET);

      if (IsTesting()) {                                                      // nur im Tester
         error = ResetLastError();
         int hWndTester = GetTesterWindow();                                  // Titelzeile des Testers zurücksetzen (ist u.U. noch vom letzten Test modifiziert)
         if (hWndTester == 0) {
            if (IsLastError())
               return(last_error);
         }                                                                    // TODO: Warten, bis die Titelzeile gesetzt ist (der startende Test kann die Abarbeitung
         else if (!SetWindowTextA(hWndTester, "Tester"))                      //       der MessageQueue des UI-Threads wesentlich verzögern).
            return(catch("stdlib_init(3) ->user32::SetWindowTextA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
         SetLastError(error);

         if (GetAccountNumber() == 0) {                                       // Accountnummer ermitteln und cachen, da der spätere Aufruf den UI-Thread blockieren *kann*.
            if (last_error == ERR_TERMINAL_NOT_YET_READY)
               debug("stdlib_init()   ERR_TERMINAL_NOT_YET_READY (GetAccountNumber() = 0)");
            return(last_error);
         }
      }
   }

   return(catch("stdlib_init(4)"));
}


/**
 * Informiert die Library über das Aufrufen der start()-Funktion des laufenden Programms. Durch Übergabe des aktuellen Ticks kann die Library später erkennen,
 * ob verschiedene Funktionsaufrufe während desselben oder unterschiedlicher Ticks erfolgen.
 *
 * @param  int tick        - Tickzähler (synchronisiert den Tickzähler des aufrufenden Programms mit dem der Library)
 * @param  int validBars   - Anzahl der seit dem letzten Tick unveränderten Bars oder -1, wenn die Funktion nicht aus einem Indikator aufgerufen wird
 * @param  int changedBars - Anzahl der seit dem letzten Tick geänderten Bars oder -1, wenn die Funktion nicht aus einem Indikator aufgerufen wird
 *
 * @return int - Fehlerstatus
 */
int stdlib_start(int tick, int validBars, int changedBars) {
   __WHEREAMI__ = FUNC_START;
   Tick         = tick;                                              // der konkrete Wert hat keine Bedeutung
   Ticks        = Tick;
   ValidBars    = validBars;
   ChangedBars  = changedBars;
   return(NO_ERROR);
}


/**
 * Deinitialisierung der Library. Informiert die Library über das Aufrufen der deinit()-Funktion des laufenden Programms.
 *
 * @param  int deinitFlags        - durchzuführende Deinitialisierungstasks (default: keine)
 * @param  int uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int stdlib_deinit(int deinitFlags, int uninitializeReason) {
   __WHEREAMI__ = FUNC_DEINIT;

   int error = NO_ERROR;

   if (!ReleaseLocks(true))
      error = last_error;
   return(error);
}


// Laufzeitfunktionen
int onInit()                  { return(NO_ERROR); }
int onInitUndefined()         { return(NO_ERROR); }
int onInitChartClose()        { return(NO_ERROR); }
int onInitRecompile()         { return(NO_ERROR); }
int onInitRemove()            { return(NO_ERROR); }
int onInitParameterChange()   { return(NO_ERROR); }
int onInitChartChange()       { return(NO_ERROR); }
int onInitAccountChange()     { return(_int(IsExpert(), catch("onInitAccountChange()", ERR_RUNTIME_ERROR), NO_ERROR)); }
int afterInit()               { return(NO_ERROR); }

int onStart()                 { return(NO_ERROR); }
int onTick()                  { return(NO_ERROR); }

int onDeinit()                { return(NO_ERROR); }
int onDeinitUndefined()       { return(NO_ERROR); }
int onDeinitChartClose()      { return(NO_ERROR); }
int onDeinitRemove()          { return(NO_ERROR); }
int onDeinitRecompile()       { return(NO_ERROR); }
int onDeinitParameterChange() { return(NO_ERROR); }
int onDeinitChartChange()     { return(NO_ERROR); }
int onDeinitAccountChange()   { return(_int(IsExpert(), catch("onDeinitAccountChange()", ERR_RUNTIME_ERROR), NO_ERROR)); }
int afterDeinit()             { return(NO_ERROR); }


// abstrakte Eventhandler (müssen bei Verwendung implementiert werden)
/*abstract*/ int onBarOpen        (int    data[]) { return(catch("onBarOpen()",         ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onAccountChange  (int    data[]) { return(catch("onAccountChange()",   ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onAccountPayment (int    data[]) { return(catch("onAccountPayment()",  ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onOrderPlace     (int    data[]) { return(catch("onOrderPlace()",      ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onOrderChange    (int    data[]) { return(catch("onOrderChange()",     ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onOrderCancel    (int    data[]) { return(catch("onOrderCancel()",     ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onPositionOpen   (int    data[]) { return(catch("onPositionOpen()",    ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onPositionClose  (int    data[]) { return(catch("onPositionClose()",   ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onChartCommand   (string data[]) { return(catch("onChartCommand()",    ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onInternalCommand(string data[]) { return(catch("onInternalCommand()", ERR_FUNCTION_NOT_IMPLEMENTED)); }
/*abstract*/ int onExternalCommand(string data[]) { return(catch("onExternalCommand()", ERR_FUNCTION_NOT_IMPLEMENTED)); }


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode zurück.
 *
 * @return int - Fehlerstatus
 */
int stdlib_GetLastError() {
   int error = last_error;
   last_error = NO_ERROR;
   return(error);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode *nicht* zurück.
 *
 * @return int - Fehlerstatus
 */
int stdlib_PeekLastError() {
   return(last_error);
}


/**
 * Setzt bzw. gibt die aktuelle Instanz-ID zurück.
 *
 * @param  int id - neue Instanz-ID
 *
 * @return int - Instanz-ID
 */
int InstanceId(int id) {
   static int static.result;                                         // ohne Initializer (@see MQL.doc)
   if (id != NULL)
      static.result = id;
   return(static.result);
}


string lock.names   [];                                              // Namen der Locks, die vom aktuellen Programm gehalten werden
int    lock.counters[];                                              // Anzahl der akquirierten Locks je Name


/**
 * Wartet solange, bis das Lock mit dem angegebenen Namen erworben wurde.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 *
 * @return bool - Erfolgsstatus
 */
bool AquireLock(string mutexName) {
   if (StringLen(mutexName) == 0)
      return(_false(catch("AquireLock(1)   illegal parameter mutexName = \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));


   // (1) check, if we already own that lock
   int i = SearchStringArray(lock.names, mutexName);
   if (i > -1) {
      //debug("AquireLock()   already own lock for mutex \""+ mutexName +"\"");
      lock.counters[i]++;
      return(true);
   }


   datetime now, startTime=GetTickCount();
   int      error, duration, seconds=1;
   string   globalVarName = mutexName;
   if (This.IsTesting())
      globalVarName = StringConcatenate("tester.", mutexName);


   // (2) no, run until the lock is aquired
   while (true) {
      // try to get it
      if (GlobalVariableSetOnCondition(globalVarName, 1, 0)) {
         //debug("AquireLock()   got the lock");
         ArrayPushString(lock.names, mutexName);
         ArrayPushInt   (lock.counters,      1);
         return(true);
      }
      error = GetLastError();

      // create the mutex if it doesn't exist
      if (error == ERR_GLOBAL_VARIABLE_NOT_FOUND) {
         if (GlobalVariableSet(globalVarName, 0) == 0) {
            error = GetLastError();
            if (IsNoError(error))
               error = ERR_RUNTIME_ERROR;
            return(_false(catch("AquireLock(2)   failed to create mutex \""+ mutexName +"\"", error)));
         }
         continue;
      }
      else if (IsError(error)) {
         return(_false(catch("AquireLock(3)   failed to get lock for mutex \""+ mutexName +"\"", error)));
      }

      if (IsStopped())
         return(_false(warn("AquireLock(4)   did not get lock for mutex \""+ mutexName +"\", stopping...")));

      // warn every second and cancel after 10 seconds
      duration = GetTickCount() - startTime;
      if (duration >= seconds*1000) {
         if (seconds >= 10)
            return(_false(catch("AquireLock(5)   failed to get lock for mutex \""+ mutexName +"\" after "+ DoubleToStr(duration/1000.0, 3) +" sec., giving up", ERR_RUNTIME_ERROR)));
         warn("AquireLock(6)   did not get lock for mutex \""+ mutexName +"\" after "+ DoubleToStr(duration/1000.0, 3) +" sec., retrying...");
         seconds++;
      }

      debug("AquireLock()   did not get lock for mutex \""+ mutexName +"\", retrying...");
      if      (IsScript())                 Sleep(100);
      else if (IsExpert() && !IsTesting()) Sleep(100);
      else                                 SleepEx(100, true);       // Expert im Tester oder Indicator
   }

   return(_false(catch("AquireLock(7)", ERR_WRONG_JUMP)));
}



/**
 * Gibt das gehaltene Lock mit dem angegebenen Namen wieder frei.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 *
 * @return bool - Erfolgsstatus
 */
bool ReleaseLock(string mutexName) {
   if (StringLen(mutexName) == 0)
      return(_false(catch("ReleaseLock(1)   illegal parameter mutexName = \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   // check, if we indeed own that lock
   int i = SearchStringArray(lock.names, mutexName);
   if (i == -1)
      return(_false(catch("ReleaseLock(2)   do not own a lock for mutex \""+ mutexName +"\"", ERR_RUNTIME_ERROR)));

   // we do, decrease the counter
   lock.counters[i]--;

   // remove it, if counter is zero
   if (lock.counters[i] == 0) {
      ArraySpliceStrings(lock.names,    i, 1);
      ArraySpliceInts   (lock.counters, i, 1);

      string globalVarName = mutexName;
      if (This.IsTesting())
         globalVarName = StringConcatenate("tester.", mutexName);

      if (GlobalVariableSet(globalVarName, 0) == 0) {
         int error = GetLastError();
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         return(_false(catch("ReleaseLock(3)   failed to reset mutex \""+ mutexName +"\"", error)));
      }
   }
   return(true);
}


/**
 * Gibt alle noch gehaltenen Locks frei.
 *
 * @param  bool warn - ob für jedes gehaltene Lock eine Warnung ausgegeben werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
/*private*/ bool ReleaseLocks(bool warn=false) {
   int error, size=ArraySize(lock.names);

   if (size > 0) {
      for (int i = size-1; i>=0; i--) {
         if (warn)
            warn("ReleaseLocks()   unreleased lock found for mutex \""+ lock.names[i] +"\"");

         if (!ReleaseLock(lock.names[i]))
            error = last_error;
      }
   }
   return(IsNoError(error));
}


/**
 * Hinterlegt in der Message-Queue des aktuellen Charts eine Nachricht zum Aufruf des Input-Dialogs des EA's.
 *
 * @return int - Fehlerstatus
 */
int Chart.Expert.Properties() {
   if (This.IsTesting())
      return(catch("Chart.Expert.Properties(1)", ERR_FUNC_NOT_ALLOWED_IN_TESTER));

   int hWnd = WindowHandle(Symbol(), NULL);
   if (hWnd == 0)
      return(catch("Chart.Expert.Properties(2) ->WindowHandle() = "+ hWnd, ERR_RUNTIME_ERROR));

   if (!PostMessageA(hWnd, WM_COMMAND, ID_CHART_EXPERT_PROPERTIES, 0))
      return(catch("Chart.Expert.Properties(3) ->user32::PostMessageA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   return(NO_ERROR);
}


/**
 * Pausiert den Tester. Der Aufruf ist nur aus einem Expert im Tester möglich.
 *
 * @return int - Fehlerstatus
 */
int Tester.Pause() {
   if (    !IsExpert())             return(catch("Tester.Pause()   experts only function", ERR_FUNC_NOT_ALLOWED));
   if (!IsVisualMode())             return(NO_ERROR);                // skipping
   if (IsStopped())                 return(NO_ERROR);                // skipping (nach Klick auf "Stop" ist weder in start() noch in deinit() das IsStopped()-Flag gesetzt)
   if (__WHEREAMI__ == FUNC_DEINIT) return(NO_ERROR);                // skipping

   // Der Tester läuft, ansonsten würde dieser Code nicht ausgeführt.

   int hWndMain = GetApplicationMainWindow();
   if (hWndMain == 0)
      return(0);

   SendMessageA(hWndMain, WM_COMMAND, ID_TESTER_PAUSERESUME, 0);
   return(NO_ERROR);
}


/**
 * Gibt die hexadezimale Repräsentation eines Strings zurück.
 *
 * @param  string value - Ausgangswert
 *
 * @return string - Hex-String
 */
string StringToHexStr(string value) {
   value = StringConcatenate(value, "");                             // NULL-Pointer abfangen

   string result = "";
   int len = StringLen(value);

   for (int i=0; i < len; i++) {
      result = StringConcatenate(result, CharToHexStr(StringGetChar(value, i)));
   }

   return(result);
}


/**
 * Gibt die lesbare Konstante einer Root-Function ID zurück.
 *
 * @param  int id
 *
 * @return string
 */
string __whereamiToStr(int id) {
   switch (id) {
      case FUNC_INIT  : return("FUNC_INIT"  );
      case FUNC_START : return("FUNC_START" );
      case FUNC_DEINIT: return("FUNC_DEINIT");
   }
   return("unknown ("+ id +")");
}


/**
 * Lädt einen Cursor anhand einer Resource-ID und gibt sein Handle zurück.
 *
 * Alias für LoadCursorById()
 */
int LoadCursor(int hInstance, int resourceId) {
   return(LoadCursorById(hInstance, resourceId));
}


/**
 * Lädt einen Cursor anhand einer Resource-ID und gibt sein Handle zurück.
 *
 * @param  int hInstance  - Application instance handle
 * @param  int resourceId - cursor ID
 *
 * @return int - Cursor-Handle oder NULL, falls ein Fehler auftrat
 */
int LoadCursorById(int hInstance, int resourceId) {
   if (resourceId & 0xFFFF0000 != 0)                                 // High-Word testen, @see  MAKEINTRESOURCE(wInteger)
      catch("LoadCursorById()  illegal parameter resourceId = 0x"+ IntToHexStr(resourceId) +" (must be lower then 0x00010000)", ERR_INVALID_FUNCTION_PARAMVALUE);

   int hCursor = LoadCursorW(hInstance, resourceId);

   if (hCursor == 0)
      catch("LoadCursorById() ->user32::LoadCursorW()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   return(hCursor);
}


/**
 * Lädt einen Cursor anhand seines Namens und gibt sein Handle zurück.
 *
 * @param  int    hInstance  - Application instance handle
 * @param  string cursorName - Name
 *
 * @return int - Cursor-Handle oder NULL, falls ein Fehler auftrat
 */
int LoadCursorByName(int hInstance, string cursorName) {
   int hCursor = LoadCursorA(hInstance, cursorName);

   if (hCursor == 0)
      catch("LoadCursorByName() ->user32::LoadCursorA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   return(hCursor);
}


/**
 * Gibt die lesbare Repräsentation einer execution-Struktur zurück.
 *
 * @param  double execution[] - Struktur
 * @param  bool   debugOutput - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string ExecutionToStr(double execution[], bool debugOutput=false) {
   string debugOut[], strings[]; ArrayResize(strings, 0);

   int size = ArraySize(execution);
   if (size % 9 != 0)
      return(_empty(catch("ExecutionToStr()   illegal size of execution[] = "+ size, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Anzahl der Datensätze im Array ermitteln
   int tickets = size / 9;

   for (int i=0; i < tickets; i++) {
      datetime time       = Round(execution[9*i+EXEC_TIME      ]);
      double   price      =       execution[9*i+EXEC_PRICE     ];
      double   swap       =       execution[9*i+EXEC_SWAP      ];
      double   commission =       execution[9*i+EXEC_COMMISSION];
      double   profit     =       execution[9*i+EXEC_PROFIT    ];
      double   duration   =       execution[9*i+EXEC_DURATION  ];
      int      requotes   = Round(execution[9*i+EXEC_REQUOTES  ]);
      double   slippage   =       execution[9*i+EXEC_SLIPPAGE  ];
      int      ticket     = Round(execution[9*i+EXEC_TICKET    ]);

      ArrayPushString(strings, (i+1) +"=EXEC_TIME=>"      +    ifString(time==0, 0, TimeToStr(time, TIME_FULL)));
      ArrayPushString(strings,         "EXEC_PRICE=>"     + NumberToStr(price,      ".+")                      );
      ArrayPushString(strings,         "EXEC_SWAP=>"      + NumberToStr(swap,       ".2")                      );
      ArrayPushString(strings,         "EXEC_COMMISSION=>"+ NumberToStr(commission, ".2")                      );
      ArrayPushString(strings,         "EXEC_PROFIT=>"    + NumberToStr(profit,     ".2")                      );
      ArrayPushString(strings,         "EXEC_DURATION=>"  + NumberToStr(duration,   ".3")                      );
      ArrayPushString(strings,         "EXEC_REQUOTES=>"  +             requotes                               );
      ArrayPushString(strings,         "EXEC_SLIPPAGE=>"  + NumberToStr(slippage,   ".1")                      );
      ArrayPushString(strings,         "EXEC_TICKET=>"    +             ticket                                 );

      if (debugOutput) {
         ArrayResize(debugOut, 0);
         ArrayCopy(debugOut, strings, 0, 9*i);
         debug("ExecutionToStr()    "+ JoinStrings(debugOut, ", "));
      }
   }

   if (IsError(catch("ExecutionToStr()")))
      return("");
   return(StringConcatenate("{", JoinStrings(strings, ", "), "}"));
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zu FXT (Forex Standard Time) zurück (entgegengesetzter Wert des Offsets von FXT zu GMT).
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetGMTToFXTOffset(datetime gmtTime) {
   if (gmtTime < 0) {
      catch("GetGMTToFXTOffset()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(gmtTime)-1970;

   // FXT                                       GMT+0200,GMT+0300
   if      (gmtTime < FXT_transitions[year][2]) offset = -2 * HOURS;
   else if (gmtTime < FXT_transitions[year][3]) offset = -3 * HOURS;
   else                                         offset = -2 * HOURS;

   return(offset);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu FXT (Forex Standard Time) zurück (positive Werte für östlich von FXT liegende Zeitzonen).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToFXTOffset(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0) {
      catch("GetServerToFXTOffset()   invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetServerTimezone();
   if (StringLen(zone) == 0)
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Tradeserver unter FXT läuft
   if (zone == "FXT")
      return(0);

   // Offset Server zu GMT
   int offset1;
   if (zone != "GMT") {
      offset1 = GetServerToGMTOffset(serverTime);
      if (offset1 == EMPTY_VALUE)
         return(EMPTY_VALUE);
   }

   // Offset GMT zu FXT
   int offset2 = GetGMTToFXTOffset(serverTime - offset1);
   if (offset2 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   return(offset1 + offset2);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu GMT (Greenwich Mean Time) zurück (positive Werte für östlich von Greenwich liegende Zeitzonen).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToGMTOffset(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0) {
      catch("GetServerToGMTOffset(1)   invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string timezone = GetServerTimezone();
   if (StringLen(timezone) == 0)
      return(EMPTY_VALUE);

   if (timezone == "Alpari") {
      if (serverTime < D'2012.04.01 00:00:00') timezone = "Europe/Berlin";
      else                                     timezone = "Europe/Kiev";
   }

   int offset, year = TimeYear(serverTime)-1970;

   if (timezone == "Europe/Minsk") {                // GMT+0200,GMT+0300
      if      (serverTime < EMST_transitions[year][0]) offset = 2 * HOURS;
      else if (serverTime < EMST_transitions[year][1]) offset = 3 * HOURS;
      else                                             offset = 2 * HOURS;
   }
   else if (timezone == "Europe/Kiev") {            // GMT+0200,GMT+0300
      if      (serverTime < EEST_transitions[year][0]) offset = 2 * HOURS;
      else if (serverTime < EEST_transitions[year][1]) offset = 3 * HOURS;
      else                                             offset = 2 * HOURS;
   }
   else if (timezone == "FXT") {                    // GMT+0200,GMT+0300
      if      (serverTime < FXT_transitions[year][0])  offset = 2 * HOURS;
      else if (serverTime < FXT_transitions[year][1])  offset = 3 * HOURS;
      else                                             offset = 2 * HOURS;
   }
   else if (timezone == "Europe/Berlin") {          // GMT+0100,GMT+0200
      if      (serverTime < CEST_transitions[year][0]) offset = 1 * HOURS;
      else if (serverTime < CEST_transitions[year][1]) offset = 2 * HOURS;
      else                                             offset = 1 * HOURS;
   }
   else if (timezone == "GMT") {                    // GMT+0000
                                                       offset = 0;
   }
   else if (timezone == "Europe/London") {          // GMT+0000,GMT+0100
      if      (serverTime < BST_transitions[year][0])  offset = 0;
      else if (serverTime < BST_transitions[year][1])  offset = 1 * HOUR;
      else                                             offset = 0;
   }
   else if (timezone == "America/New_York") {       // GMT-0500,GMT-0400
      if      (serverTime < EDT_transitions[year][0])  offset = -5 * HOURS;
      else if (serverTime < EDT_transitions[year][1])  offset = -4 * HOURS;
      else                                             offset = -5 * HOURS;
   }
   else {
      catch("GetServerToGMTOffset(2)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG);
      return(EMPTY_VALUE);
   }

   return(offset);
}


/**
 * Dropin-Ersatz für PlaySound()
 *
 * Spielt ein Soundfile ab, auch wenn dies im aktuellen Kontext des Terminals (z.B. im Tester) nicht unterstützt wird.
 *
 * @param string soundfile
 *
 * @return int - Fehlerstatus
 */
int ForceSound(string soundfile) {
   if (!IsTesting()) {
      PlaySound(soundfile);
   }
   else {
      soundfile = StringConcatenate(TerminalPath(), "\\sounds\\", soundfile);
      PlaySoundA(soundfile, NULL, SND_FILENAME|SND_ASYNC);
   }
   return(NO_ERROR);
}


/**
 * Dropin-Ersatz für MessageBox()
 *
 * Zeigt eine MessageBox an, auch wenn dies im aktuellen Kontext des Terminals (z.B. im Tester oder in Indikatoren) nicht unterstützt wird.
 *
 * @param string caption
 * @param string message
 * @param int    flags
 *
 * @return int - Tastencode
 */
int ForceMessageBox(string caption, string message, int flags=MB_OK) {
   string prefix = StringConcatenate(Symbol(), ",", PeriodDescription(NULL));

   if (!StringContains(caption, prefix))
      caption = StringConcatenate(prefix, " - ", caption);

   int button;

   if (!IsTesting() && !IsIndicator()) button = MessageBox(message, caption, flags);
   else                                button = MessageBoxA(NULL, message, caption, flags);  // TODO: hWndOwner fixen

   return(button);
}


/**
 * Gibt die Namen aller Abschnitte einer ini-Datei zurück.
 *
 * @param  string fileName - Name der ini-Datei (wenn NULL, wird WIN.INI durchsucht)
 * @param  string names[]  - Array zur Aufnahme der gefundenen Abschnittsnamen
 *
 * @return int - Anzahl der gefundenen Abschnitte oder -1, falls ein Fehler auftrat
 */
int GetPrivateProfileSectionNames(string fileName, string names[]) {
   int bufferSize = 200;
   int buffer[]; InitializeBuffer(buffer, bufferSize);

   int chars = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeBuffer(buffer, bufferSize);
      chars = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);
   }

   int length;
   if (chars == 0) length = ArrayResize(names, 0);                   // keine Sections gefunden (File nicht gefunden oder leer)
   else            length = ExplodeStrings(buffer, names);

   if (IsError(catch("GetPrivateProfileSectionNames")))
      return(-1);
   return(length);
}


/**
 * Gibt die Namen aller Einträge eines Abschnitts einer ini-Datei zurück.
 *
 * @param  string fileName - Name der ini-Datei
 * @param  string section  - Name des Abschnitts
 * @param  string keys[]   - Array zur Aufnahme der gefundenen Schlüsselnamen
 *
 * @return int - Anzahl der gefundenen Schlüssel oder -1, falls ein Fehler auftrat
 */
int GetPrivateProfileKeys(string fileName, string section, string keys[]) {
   return(GetPrivateProfileKeys.2(fileName, section, keys));
}


/**
 * Löscht einen einzelnen Eintrag einer ini-Datei.
 *
 * @param  string fileName - Name der ini-Datei
 * @param  string section  - Abschnitt des Eintrags
 * @param  string key      - Name des zu löschenden Eintrags
 *
 * @return int - Fehlerstatus
 */
int DeletePrivateProfileKey(string fileName, string section, string key) {
   string sNull;

   if (!WritePrivateProfileStringA(section, key, sNull, fileName))
      return(catch("DeletePrivateProfileKey() ->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=NULL, fileName=\""+ fileName +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   return(NO_ERROR);
}


/**
 * Gibt den Versionsstring des Terminals zurück.
 *
 * @return string - Version oder Leerstring, falls ein Fehler auftrat
 */
string GetTerminalVersion() {
   static string static.result[1];
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   int    bufferSize = MAX_PATH;
   string fileName[]; InitializeStringBuffer(fileName, bufferSize);
   int chars = GetModuleFileNameA(NULL, fileName[0], bufferSize);
   if (chars == 0)
      return(_empty(catch("GetTerminalVersion(1) ->kernel32::GetModuleFileNameA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   int iNull[];
   int infoSize = GetFileVersionInfoSizeA(fileName[0], iNull);
   if (infoSize == 0)
      return(_empty(catch("GetTerminalVersion(2) ->version::GetFileVersionInfoSizeA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   int infoBuffer[]; InitializeBuffer(infoBuffer, infoSize);
   if (!GetFileVersionInfoA(fileName[0], 0, infoSize, infoBuffer))
      return(_empty(catch("GetTerminalVersion(3) ->version::GetFileVersionInfoA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   string infoString = BufferToStr(infoBuffer);                      // Strings im Buffer sind Unicode-Strings
   //infoString = Ð•4………V…S…_…V…E…R…S…I…O…N…_…I…N…F…O……………½•ïþ……•………•…á……………•…á………?…………………•………•………………………………………0•……•…S…t…r…i…n…g…F…i…l…e…I…n…f…o………••……•…0…0…0…0…0…4…b…0………L…•…•…C…o…m…m…e…n…t…s………h…t…t…p…:…/…/…w…w…w….…m…e…t…a…q…u…o…t…e…s….…n…e…t………T…•…•…C…o…m…p…a…n…y…N…a…m…e……………M…e…t…a…Q…u…o…t…e…s… …S…o…f…t…w…a…r…e… …C…o…r…p….………>…•…•…F…i…l…e…D…e…s…c…r…i…p…t…i…o…n……………M…e…t…a…T…r…a…d…e…r……………6…•…•…F…i…l…e…V…e…r…s…i…o…n……………4….…0….…0….…2…2…5…………………6…•…•…I…n…t…e…r…n…a…l…N…a…m…e………M…e…t…a…T…r…a…d…e…r……………†…1…•…L…e…g…a…l…C…o…p…y…r…i…g…h…t………C…o…p…y…r…i…g…h…t… …©… …2…0…0…1…-…2…0…0…9…,… …M…e…t…a…Q…u…o…t…e…s… …S…o…f…t…w…a…r…e… …C…o…r…p….……………@…•…•…L…e…g…a…l…T…r…a…d…e…m…a…r…k…s……………M…e…t…a…T…r…a…d…e…r…®………(………•…O…r…i…g…i…n…a…l…F…i…l…e…n…a…m…e……… ………•…P…r…i…v…a…t…e…B…u…i…l…d………6…•…•…P…r…o…d…u…c…t…N…a…m…e……………M…e…t…a…T…r…a…d…e…r……………:…•…•…P…r…o…d…u…c…t…V…e…r…s…i…o…n………4….…0….…0….…2…2…5………………… ………•…S…p…e…c…i…a…l…B…u…i…l…d………D………•…V…a…r…F…i…l…e…I…n…f…o……………$…•………T…r…a…n…s…l…a…t…i…o…n…………………°•FE2X…………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………………
   string Z                  = CharToStr(PLACEHOLDER_ZERO_CHAR);
   string C                  = CharToStr(PLACEHOLDER_CTL_CHAR);
   string key.ProductVersion = StringConcatenate(C,Z,"P",Z,"r",Z,"o",Z,"d",Z,"u",Z,"c",Z,"t",Z,"V",Z,"e",Z,"r",Z,"s",Z,"i",Z,"o",Z,"n",Z,Z);
   string key.FileVersion    = StringConcatenate(C,Z,"F",Z,"i",Z,"l",Z,"e",Z,"V",Z,"e",Z,"r",Z,"s",Z,"i",Z,"o",Z,"n",Z,Z);

   int pos = StringFind(infoString, key.ProductVersion);             // zuerst nach ProductVersion suchen...
   if (pos != -1) {
      pos += StringLen(key.ProductVersion);
   }
   else {
      //debug("GetTerminalVersion() ->GetFileVersionInfoA()   ProductVersion not found");
      pos = StringFind(infoString, key.FileVersion);                 // ...dann nach FileVersion
      if (pos == -1) {
         //debug("GetTerminalVersion() ->GetFileVersionInfoA()   FileVersion not found");
         return(_empty(catch("GetTerminalVersion(4)   terminal version info not found", ERR_RUNTIME_ERROR)));
      }
      pos += StringLen(key.FileVersion);
   }

   // erstes Nicht-NULL-Byte nach dem Version-Key finden
   for (; pos < infoSize; pos++) {
      if (BufferGetChar(infoBuffer, pos) != 0x00)
         break;
   }
   if (pos == infoSize) {
      //debug("GetTerminalVersion()   no non-NULL byte after version key found");
      return(_empty(catch("GetTerminalVersion(5)   terminal version info value not found", ERR_RUNTIME_ERROR)));
   }

   // Unicode-String auslesen und konvertieren
   string version = BufferWCharsToStr(infoBuffer, pos/4, (infoSize-pos)/4);

   if (IsError(catch("GetTerminalVersion(6)")))
      return("");

   static.result[0] = version;
   return(static.result[0]);
}


/**
 * Gibt die Build-Version des Terminals zurück.
 *
 * @return int - Build-Version oder 0, wenn ein Fehler auftrat
 */
int GetTerminalBuild() {
   static int static.result;                                         // ohne Initializer (@see MQL.doc)
   if (static.result != 0)
      return(static.result);

   string version = GetTerminalVersion();
   if (StringLen(version) == 0)
      return(0);

   string strings[];

   int size = Explode(version, ".", strings);
   if (size != 4)
      return(_ZERO(catch("GetTerminalBuild(1)   unexpected terminal version format = \""+ version +"\"", ERR_RUNTIME_ERROR)));

   if (!StringIsDigit(strings[size-1]))
      return(_ZERO(catch("GetTerminalBuild(2)   unexpected terminal version format = \""+ version +"\"", ERR_RUNTIME_ERROR)));

   int build = StrToInteger(strings[size-1]);

   if (IsError(catch("GetTerminalBuild(3)")))
      build = 0;

   static.result = build;
   return(static.result);
}


/**
 * Initialisiert einen Buffer zur Aufnahme von Bytes in der gewünschten Länge. Byte-Buffer können in MQL nur über Integer-Arrays dargestellt werden.
 *
 * @param  int buffer[] - das für den Buffer zu verwendende Integer-Array
 * @param  int length   - Länge des Buffers in Bytes
 *
 * @return int - Fehlerstatus
 */
int InitializeBuffer(int buffer[], int length) {
   if (ArrayDimension(buffer) > 1)
      return(catch("InitializeBuffer(1)  invalid parameter buffer, too many dimensions = "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAYS));
   if (length < 0)
      return(catch("InitializeBuffer(2)  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE));

   if (length & 0x03 == 0) length = length >> 2;                     // length & 0x03 = length % 4
   else                    length = length >> 2 + 1;

   if (ArraySize(buffer) != length)
      ArrayResize(buffer, length);
   ArrayInitialize(buffer, 0);

   return(catch("InitializeBuffer(3)"));
}


/**
 * Initialisiert einen Buffer zur Aufnahme eines Strings der gewünschten Länge.
 *
 * @param  string buffer[] - das für den Buffer zu verwendende String-Array
 * @param  int    length   - Länge des Buffers in Zeichen
 *
 * @return int - Fehlerstatus
 */
int InitializeStringBuffer(string& buffer[], int length) {
   if (ArrayDimension(buffer) > 1)
      return(catch("InitializeStringBuffer(1)  invalid parameter buffer, too many dimensions = "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAYS));
   if (length < 0)
      return(catch("InitializeStringBuffer(2)  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE));

   if (ArraySize(buffer) == 0)
      ArrayResize(buffer, 1);

   buffer[0] = CreateString(length);

   return(catch("InitializeStringBuffer(3)"));
}


/**
 * Erzeugt einen neuen String der gewünschten Länge.
 *
 * @param  int length - Länge
 *
 * @return string
 */
string CreateString(int length) {
   if (length < 0)
      return(_empty(catch("CreateString()  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   string newStr = StringConcatenate(MAX_STRING_LITERAL, "");        // Um immer einen neuen String zu erhalten (MT4-Zeigerproblematik), darf Ausgangsbasis kein Literal sein.
   int strLen = StringLen(newStr);                                   // Daher wird auch beim Initialisieren StringConcatenate() verwendet (siehe MQL.doc).

   while (strLen < length) {
      newStr = StringConcatenate(newStr, MAX_STRING_LITERAL);
      strLen = StringLen(newStr);
   }

   if (strLen != length)
      newStr = StringSubstr(newStr, 0, length);
   return(newStr);
}


/**
 * Gibt die Strategy-ID einer MagicNumber zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Strategy-ID
 */
int StrategyId(int magicNumber) {
   return(magicNumber >> 22);                                        // 10 bit (Bit 23-32) => Bereich 0-1023, aber immer größer 100
}


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID
 */
int LFX.CurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 0-15
}


/**
 * Gibt die Währung der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return string - Währungskürzel ("EUR", "GBP", "USD" etc.)
 */
string LFX.Currency(int magicNumber) {
   return(GetCurrency(LFX.CurrencyId(magicNumber)));
}


/**
 * Gibt den Wert des Position-Counters der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Counter
 */
int LFX.Counter(int magicNumber) {
   return(magicNumber & 0xF);                                        // 4 bit (Bit 1-4 ) => Bereich 0-15
}


/**
 * Gibt den Units-Wert der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return double - Units
 */
double LFX.Units(int magicNumber) {
   return(magicNumber >> 13 & 0x1F / 10.0);                          // 5 bit (Bit 14-18) => Bereich 0-31
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.Instance(int magicNumber) {
   return(magicNumber >> 4 & 0x1FF);                                 // 9 bit (Bit 5-13) => Bereich 0-511
}


/**
 * Gibt den vollständigen Dateinamen der lokalen Konfigurationsdatei zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname
 */
string GetLocalConfigPath() {
   static string static.result[1];                                   // ohne Initializer ...
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\metatrader-local-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetWin32ShortcutTarget(lnkFile);
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR)
            return(_empty(catch("GetLocalConfigPath(1) ->kernel32::_lcreat(filename=\""+ iniFile +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));
         _lclose(hFile);
      }
   }

   static.result[0] = iniFile;

   if (IsError(catch("GetLocalConfigPath(2)")))
      return("");
   return(static.result[0]);
}


/**
 * Gibt den vollständigen Dateinamen der globalen Konfigurationsdatei zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname
 */
string GetGlobalConfigPath() {
   static string static.result[1];                                   // ohne Initializer ...
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetWin32ShortcutTarget(lnkFile);
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR)
            return(_empty(catch("GetGlobalConfigPath(1) ->kernel32::_lcreat(filename=\""+ iniFile +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));
         _lclose(hFile);
      }
   }

   static.result[0] = iniFile;

   if (IsError(catch("GetGlobalConfigPath(2)")))
      return("");
   return(static.result[0]);
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
   if (curr == C_CNY) return(CID_CNY);
   if (curr == C_CZK) return(CID_CZK);
   if (curr == C_DKK) return(CID_DKK);
   if (curr == C_EUR) return(CID_EUR);
   if (curr == C_GBP) return(CID_GBP);
   if (curr == C_HKD) return(CID_HKD);
   if (curr == C_HRK) return(CID_HRK);
   if (curr == C_HUF) return(CID_HUF);
   if (curr == C_INR) return(CID_INR);
   if (curr == C_JPY) return(CID_JPY);
   if (curr == C_LTL) return(CID_LTL);
   if (curr == C_LVL) return(CID_LVL);
   if (curr == C_MXN) return(CID_MXN);
   if (curr == C_NOK) return(CID_NOK);
   if (curr == C_NZD) return(CID_NZD);
   if (curr == C_PLN) return(CID_PLN);
   if (curr == C_RUB) return(CID_RUB);
   if (curr == C_SAR) return(CID_SAR);
   if (curr == C_SEK) return(CID_SEK);
   if (curr == C_SGD) return(CID_SGD);
   if (curr == C_THB) return(CID_THB);
   if (curr == C_TRY) return(CID_TRY);
   if (curr == C_TWD) return(CID_TWD);
   if (curr == C_USD) return(CID_USD);
   if (curr == C_ZAR) return(CID_ZAR);

   return(_ZERO(catch("GetCurrencyId()   unknown currency = \""+ currency +"\"", ERR_RUNTIME_ERROR)));
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
      case CID_CNY: return(C_CNY);
      case CID_CZK: return(C_CZK);
      case CID_DKK: return(C_DKK);
      case CID_EUR: return(C_EUR);
      case CID_GBP: return(C_GBP);
      case CID_HKD: return(C_HKD);
      case CID_HRK: return(C_HRK);
      case CID_HUF: return(C_HUF);
      case CID_INR: return(C_INR);
      case CID_JPY: return(C_JPY);
      case CID_LTL: return(C_LTL);
      case CID_LVL: return(C_LVL);
      case CID_MXN: return(C_MXN);
      case CID_NOK: return(C_NOK);
      case CID_NZD: return(C_NZD);
      case CID_PLN: return(C_PLN);
      case CID_RUB: return(C_RUB);
      case CID_SAR: return(C_SAR);
      case CID_SEK: return(C_SEK);
      case CID_SGD: return(C_SGD);
      case CID_THB: return(C_THB);
      case CID_TRY: return(C_TRY);
      case CID_TWD: return(C_TWD);
      case CID_USD: return(C_USD);
      case CID_ZAR: return(C_ZAR);
   }
   return(_empty(catch("GetCurrency()   unknown currency id = "+ id, ERR_RUNTIME_ERROR)));
}


/**
 * Sortiert die übergebenen Tickets in chronologischer Reihenfolge (nach OpenTime und Ticket#).
 *
 * @param  int tickets[] - zu sortierende Tickets
 *
 * @return int - Fehlerstatus
 */
int SortTicketsChronological(int& tickets[]) {
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets < 2)
      return(NO_ERROR);

   int data[][2]; ArrayResize(data, sizeOfTickets);

   OrderPush("SortTicketsChronological(1)");

   // Tickets aufsteigend nach OrderOpenTime() sortieren
   for (int i=0; i < sizeOfTickets; i++) {
      if (!OrderSelectByTicket(tickets[i], "SortTicketsChronological(2)", NULL, O_POP))
         return(last_error);
      data[i][0] = OrderOpenTime();
      data[i][1] = tickets[i];
   }
   ArraySort(data);

   // Tickets mit derselben OpenTime nach Ticket# sortieren
   int open, lastOpen=-1, sortFrom=-1;

   for (i=0; i < sizeOfTickets; i++) {
      open = data[i][0];

      if (open == lastOpen) {
         if (sortFrom == -1) {
            sortFrom = i-1;
            data[sortFrom][0] = data[sortFrom][1];
         }
         data[i][0] = data[i][1];
      }
      else if (sortFrom != -1) {
         ArraySort(data, i-sortFrom, sortFrom);
         sortFrom = -1;
      }
      lastOpen = open;
   }
   if (sortFrom != -1)
      ArraySort(data, i+1-sortFrom, sortFrom);

   // Tickets zurück ins Ausgangsarray schreiben
   for (i=0; i < sizeOfTickets; i++) {
      tickets[i] = data[i][1];
   }

   return(catch("SortTicketsChronological(3)", NULL, O_POP));
}


/**
 * Aktiviert bzw. deaktiviert den Aufruf der start()-Funktion von Expert Advisern bei Eintreffen von Ticks.
 * Wird üblicherweise aus der init()-Funktion aufgerufen.
 *
 * @param  bool enable - gewünschter Status: On/Off
 *
 * @return int - Fehlerstatus
 */
int Menu.Experts(bool enable) {
   if (This.IsTesting())
      return(debug("Menu.Experts()   skipping in Tester", NO_ERROR));

   // TODO: Lock implementieren, damit mehrere gleichzeitige Aufrufe sich nicht gegenseitig überschreiben
   // TODO: Vermutlich Deadlock bei IsStopped()=TRUE, dann PostMessage() verwenden

   int hWnd = GetApplicationMainWindow();
   if (hWnd == 0)
      return(last_error);

   if (enable) {
      if (!IsExpertEnabled())
         SendMessageA(hWnd, WM_COMMAND, ID_EXPERTS_ONOFF, 0);
   }
   else /*disable*/ {
      if (IsExpertEnabled())
         SendMessageA(hWnd, WM_COMMAND, ID_EXPERTS_ONOFF, 0);
   }
   return(NO_ERROR);
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
            maxLegendId  = Max(maxLegendId, StrToInteger(substrings[1]));
            maxYDistance = Max(maxYDistance, Round(ObjectGet(objName, OBJPROP_YDISTANCE)));
         }
         labelObj--;
      }
   }

   string label = StringConcatenate("Legend.", maxLegendId+1, ".", name);
   if (ObjectFind(label) >= 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER   , CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE,               5);
      ObjectSet(label, OBJPROP_YDISTANCE, maxYDistance+19);
   }
   else GetLastError();
   ObjectSetText(label, " ");

   if (IsError(catch("CreateLegendLabel()")))
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
 * Ob ein Tradeserver-Error temporär (also vorübergehend) ist oder nicht. Bei einem vorübergehenden Fehler *kann* der erneute Versuch,
 * die Order auszuführen, erfolgreich sein.
 *
 * @param  int error - Fehlerstatus
 *
 * @return bool
 *
 * @see IsPermanentTradeError()
 */
bool IsTemporaryTradeError(int error) {
   switch (error) {
      // temporary errors
      case ERR_COMMON_ERROR:                 //        2   trade denied                                                       // TODO: Warum ist dies temporär?
      case ERR_SERVER_BUSY:                  //        4   trade server is busy
      case ERR_TRADE_TIMEOUT:                //      128   trade timeout
      case ERR_INVALID_PRICE:                //      129   Kurs bewegt sich zu schnell (aus dem Fenster)
      case ERR_PRICE_CHANGED:                //      135   price changed
      case ERR_OFF_QUOTES:                   //      136   off quotes
      case ERR_BROKER_BUSY:                  //      137   broker is busy
      case ERR_REQUOTE:                      //      138   requote
      case ERR_TRADE_CONTEXT_BUSY:           //      146   trade context is busy
         return(true);

      // permanent errors
      case ERR_NO_RESULT:                    //        1   no result                                                          // TODO: Ist temporär!
      case ERR_INVALID_TRADE_PARAMETERS:     //        3   invalid trade parameters
      case ERR_OLD_VERSION:                  //        5   old version of client terminal
      case ERR_NO_CONNECTION:                //        6   no connection to trade server                                      // TODO: Ist temporär!
      case ERR_NOT_ENOUGH_RIGHTS:            //        7   not enough rights
      case ERR_TOO_FREQUENT_REQUESTS:        // ???    8   too frequent requests                                              // TODO: Ist temporär!
      case ERR_MALFUNCTIONAL_TRADE:          //        9   malfunctional trade operation
      case ERR_ACCOUNT_DISABLED:             //       64   account disabled
      case ERR_INVALID_ACCOUNT:              //       65   invalid account
      case ERR_INVALID_STOPS:                //      130   invalid stop
      case ERR_INVALID_TRADE_VOLUME:         //      131   invalid trade volume
      case ERR_MARKET_CLOSED:                //      132   market is closed
      case ERR_TRADE_DISABLED:               //      133   trading is disabled
      case ERR_NOT_ENOUGH_MONEY:             //      134   not enough money
      case ERR_ORDER_LOCKED:                 //      139   order is locked
      case ERR_LONG_POSITIONS_ONLY_ALLOWED:  //      140   long positions only allowed
      case ERR_TOO_MANY_REQUESTS:            // ???  141   too many requests                                                  // TODO: Ist temporär!
      case ERR_TRADE_MODIFY_DENIED:          //      145   modification denied because too close to market                    // TODO: Ist temporär!
      case ERR_TRADE_EXPIRATION_DENIED:      //      147   expiration settings denied by broker
      case ERR_TRADE_TOO_MANY_ORDERS:        //      148   number of open and pending orders has reached the broker limit
      case ERR_TRADE_HEDGE_PROHIBITED:       //      149   hedging prohibited
      case ERR_TRADE_PROHIBITED_BY_FIFO:     //      150   prohibited by FIFO rules
         return(false);
   }
   return(false);
}


/**
 * Ob ein Tradeserver-Error permanent (also nicht nur vorübergehend) ist oder nicht. Bei einem permanenten Fehler wird auch der erneute Versuch,
 * die Order auszuführen, fehlschlagen.
 *
 * @param  int error - Fehlerstatus
 *
 * @return bool
 *
 * @see IsTemporaryTradeError()
 */
bool IsPermanentTradeError(int error) {
   return(!IsTemporaryTradeError(error));
}


/**
 * Entfernt ein Element vom Ende eines Boolean-Arrays und gibt es zurück.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - das entfernte Element oder FALSE, wenn ein Fehler auftrat (@see last_error)
 */
bool ArrayPopBool(bool array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_false(catch("ArrayPopBool()   cannot pop element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   bool popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Beginn eines Boolean-Arrays und gibt es zurück.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - das entfernte Element oder FALSE, wenn ein Fehler auftrat (@see last_error)
 */
bool ArrayShiftBool(bool array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_false(catch("ArrayShiftBool()   cannot shift element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   bool shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt alle Vorkommen eines Elements aus einem Boolean-Array.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArrayDropBool(bool array[], bool value) {
   int size = ArraySize(array);
   if (size == 0)
      return(0);

   for (int count, i=size-1; i>=0; i--) {
      if (array[i] == value) {
         if (i < size-1)                           // ArrayCopy(), wenn das zu entfernende Element nicht das letzte ist
            ArrayCopy(array, array, i, i+1);
         size = ArrayResize(array, size-1);        // Array um ein Element kürzen
         count++;
      }
   }
   return(count);
}


/**
 * Entfernt einen Teil aus einem Boolean-Array.
 *
 * @param  bool array[] - Boolean-Array
 * @param  int  offset  - Startposition zu entfernender Elemente
 * @param  int  length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArraySpliceBools(bool array[], int offset, int length) {
   int size = ArraySize(array);
   if (offset < 0)      return(_ZERO(catch("ArraySpliceBools(1)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (offset > size-1) return(_ZERO(catch("ArraySpliceBools(2)   invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (length < 0)      return(_ZERO(catch("ArraySpliceBools(3)   invalid parameter length = "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (size   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < size) {
      ArrayCopy(array, array, offset, offset+length);                // ArrayCopy(), wenn die zu entfernenden Elemente das Ende nicht einschließen
   }
   else {
      length = size - offset;
   }
   ArrayResize(array, size-length);

   return(length);
}


/**
 * Fügt ein Element am Ende eines Boolean-Arrays an.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayPushBool(bool& array[], bool value) {
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Fügt ein Element am Beginn eines Boolean-Arrays an.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayUnshiftBool(bool array[], bool value) {
   ReverseBoolArray(array);
   int size = ArrayPushBool(array, value);
   ReverseBoolArray(array);
   return(size);
}


/**
 * Vereint die Werte zweier Boolean-Arrays.
 *
 * @param  bool array1[] - Boolean-Array
 * @param  bool array2[] - Boolean-Array
 * @param  bool merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays
 */
int MergeBoolArrays(bool array1[], bool array2[], bool merged[]) {
   // Da merged[] Referenz auf array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
   bool tmp[]; ArrayResize(tmp, 0);

   int size1 = ArraySize(array1);
   if (size1 > 0)
      ArrayCopy(tmp, array1);

   int size2 = ArraySize(array2);
   if (size2 > 0)
      ArrayCopy(tmp, array2, size1);

   int size3 = size1 + size2;
   if (size3 > 0)
      ArrayCopy(merged, tmp);
   ArrayResize(merged, size3);

   ArrayResize(tmp, 0);
   return(size3);
}


/**
 * Entfernt ein Element vom Ende eines Integer-Arrays und gibt es zurück.
 *
 * @param  int array[] - Integer-Array
 *
 * @return int - das entfernte Element oder 0, wenn ein Fehler auftrat (@see last_error)
 */
int ArrayPopInt(int array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayPopInt()   cannot pop element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   int popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Beginn eines Integer-Arrays und gibt es zurück.
 *
 * @param  int array[] - Integer-Array
 *
 * @return int - das entfernte Element oder 0, wenn ein Fehler auftrat (@see last_error)
 */
int ArrayShiftInt(int array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayShiftInt()   cannot shift element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   int shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt alle Vorkommen eines Elements aus einem Integer-Array.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArrayDropInt(int array[], int value) {
   int size = ArraySize(array);
   if (size == 0)
      return(0);

   for (int count, i=size-1; i>=0; i--) {
      if (array[i] == value) {
         if (i < size-1)                           // ArrayCopy(), wenn das zu entfernende Element nicht das letzte ist
            ArrayCopy(array, array, i, i+1);
         size = ArrayResize(array, size-1);        // Array um ein Element kürzen
         count++;
      }
   }
   return(count);
}


/**
 * Entfernt einen Teil aus einem Integer-Array.
 *
 * @param  int array[] - Integer-Array
 * @param  int offset  - Startposition zu entfernender Elemente
 * @param  int length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArraySpliceInts(int array[], int offset, int length) {
   int size = ArraySize(array);
   if (offset < 0)      return(_ZERO(catch("ArraySpliceInts(1)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (offset > size-1) return(_ZERO(catch("ArraySpliceInts(2)   invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (length < 0)      return(_ZERO(catch("ArraySpliceInts(3)   invalid parameter length = "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (size   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < size) {
      ArrayCopy(array, array, offset, offset+length);                // ArrayCopy(), wenn die zu entfernenden Elemente das Ende nicht einschließen
   }
   else {
      length = size - offset;
   }
   ArrayResize(array, size-length);

   return(length);
}


/**
 * Fügt ein Element am Ende eines Integer-Arrays an.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - hinzuzufügendes Element
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
 * Fügt ein Element am Beginn eines Integer-Arrays an.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayUnshiftInt(int array[], int value) {
   ReverseIntArray(array);
   int size = ArrayPushInt(array, value);
   ReverseIntArray(array);
   return(size);
}


/**
 * Vereint die Werte zweier Integer-Arrays.
 *
 * @param  int array1[] - Integer-Array
 * @param  int array2[] - Integer-Array
 * @param  int merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays
 */
int MergeIntArrays(int array1[], int array2[], int merged[]) {
   // Da results[] Referenz auf array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
   int tmp[]; ArrayResize(tmp, 0);

   int size1 = ArraySize(array1);
   if (size1 > 0)
      ArrayCopy(tmp, array1);

   int size2 = ArraySize(array2);
   if (size2 > 0)
      ArrayCopy(tmp, array2, size1);

   int size3 = size1 + size2;
   if (size3 > 0)
      ArrayCopy(merged, tmp);
   ArrayResize(merged, size3);

   ArrayResize(tmp, 0);
   return(size3);
}


/**
 * Entfernt ein Element vom Ende eines Double-Array und gibt es zurück.
 *
 * @param  int double[] - Double-Array
 *
 * @return double - das entfernte Element oder 0, wenn ein Fehler auftrat (@see last_error)
 */
double ArrayPopDouble(double array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayPopDouble()   cannot pop element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   double popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Beginn eines Double-Arrays und gibt es zurück.
 *
 * @param  double array[] - Double-Array
 *
 * @return double - das entfernte Element oder 0, wenn ein Fehler auftrat (@see last_error)
 */
double ArrayShiftDouble(double array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayShiftDouble()   cannot shift element from an empty array = {}", ERR_SOME_ARRAY_ERROR)));

   double shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt alle Vorkommen eines Elements aus einem Double-Array.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArrayDropDouble(double array[], double value) {
   int size = ArraySize(array);
   if (size == 0)
      return(0);

   for (int count, i=size-1; i>=0; i--) {
      if (EQ(array[i], value)) {
         if (i < size-1)                           // ArrayCopy(), wenn das zu entfernende Element nicht das letzte ist
            ArrayCopy(array, array, i, i+1);
         size = ArrayResize(array, size-1);        // Array um ein Element kürzen
         count++;
      }
   }
   return(count);
}


/**
 * Entfernt einen Teil aus einem Double-Array.
 *
 * @param  double array[] - Double-Array
 * @param  int    offset  - Startposition zu entfernender Elemente
 * @param  int    length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArraySpliceDoubles(double array[], int offset, int length) {
   int size = ArraySize(array);
   if (offset < 0)      return(_ZERO(catch("ArraySpliceDoubles(1)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (offset > size-1) return(_ZERO(catch("ArraySpliceDoubles(2)   invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (length < 0)      return(_ZERO(catch("ArraySpliceDoubles(3)   invalid parameter length = "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (size   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < size) {
      ArrayCopy(array, array, offset, offset+length);                // ArrayCopy(), wenn die zu entfernenden Elemente das Ende nicht einschließen
   }
   else {
      length = size - offset;
   }
   ArrayResize(array, size-length);

   return(length);
}


/**
 * Fügt ein Element am Ende eines Double-Arrays an.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - hinzuzufügendes Element
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
 * Fügt ein Element am Beginn eines Double-Arrays an.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayUnshiftDouble(double array[], double value) {
   ReverseDoubleArray(array);
   int size = ArrayPushDouble(array, value);
   ReverseDoubleArray(array);
   return(size);
}


/**
 * Vereint die Werte zweier Double-Arrays.
 *
 * @param  double array1[] - Double-Array
 * @param  double array2[] - Double-Array
 * @param  double merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays
 */
int MergeDoubleArrays(double array1[], double array2[], double merged[]) {
   // Da results[] Referenz auf array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
   double tmp[]; ArrayResize(tmp, 0);

   int size1 = ArraySize(array1);
   if (size1 > 0)
      ArrayCopy(tmp, array1);

   int size2 = ArraySize(array2);
   if (size2 > 0)
      ArrayCopy(tmp, array2, size1);

   int size3 = size1 + size2;
   if (size3 > 0)
      ArrayCopy(merged, tmp);
   ArrayResize(merged, size3);

   ArrayResize(tmp, 0);
   return(size3);
}


/**
 * Entfernt ein Element vom Ende eines String-Arrays und gibt es zurück.
 *
 * @param  string array[] - String-Array
 *
 * @return string - das entfernte Element oder ein Leerstring, wenn ein Fehler auftrat (@see last_error)
 */
string ArrayPopString(string array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_empty(catch("ArrayPopString()   cannot pop element from empty array = {}", ERR_SOME_ARRAY_ERROR)));

   string popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Beginn eines String-Arrays und gibt es zurück.
 *
 * @param  string array[] - String-Array
 *
 * @return string - das entfernte Element oder ein Leerstring, wenn ein Fehler auftrat (@see last_error)
 */
string ArrayShiftString(string array[]) {
   int size = ArraySize(array);
   if (size == 0)
      return(_empty(catch("ArrayShiftString()   cannot shift element from an empty array = {}", ERR_SOME_ARRAY_ERROR)));

   string shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt alle Vorkommen eines Elements aus einem String-Array.
 *
 * @param  string array[] - String-Array
 * @param  string value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArrayDropString(string array[], string value) {
   int size = ArraySize(array);
   if (size == 0)
      return(0);

   // TODO: nicht initialisierten String verarbeiten (NULL-Pointer)

   for (int count, i=size-1; i>=0; i--) {
      if (array[i] == value) {
         if (i < size-1)                           // ArrayCopy(), wenn das zu entfernende Element nicht das letzte ist
            ArrayCopy(array, array, i, i+1);
         size = ArrayResize(array, size-1);        // Array um ein Element kürzen
         count++;
      }
   }
   return(count);
}


/**
 * Entfernt einen Teil aus einem String-Array.
 *
 * @param  string array[] - String-Array
 * @param  int    offset  - Startposition zu entfernender Elemente
 * @param  int    length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente
 */
int ArraySpliceStrings(string array[], int offset, int length) {
   int size = ArraySize(array);
   if (offset < 0)      return(_ZERO(catch("ArraySpliceStrings(1)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (offset > size-1) return(_ZERO(catch("ArraySpliceStrings(2)   invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (length < 0)      return(_ZERO(catch("ArraySpliceStrings(3)   invalid parameter length = "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (size   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < size) {
      ArrayCopy(array, array, offset, offset+length);                // ArrayCopy(), wenn die zu entfernenden Elemente das Ende nicht einschließen
   }
   else {
      length = size - offset;
   }
   ArrayResize(array, size-length);

   return(length);
}


/**
 * Fügt ein Element am Ende eines String-Arrays an.
 *
 * @param  string array[] - String-Array
 * @param  string value   - hinzuzufügendes Element
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
 * Fügt ein Element am Beginn eines String-Arrays an.
 *
 * @param  string array[] - String-Array
 * @param  string value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays
 */
int ArrayUnshiftString(string array[], string value) {
   ReverseStringArray(array);
   int size = ArrayPushString(array, value);
   ReverseStringArray(array);
   return(size);
}


/**
 * Vereint die Werte zweier String-Arrays.
 *
 * @param  string array1[] - String-Array
 * @param  string array2[] - String-Array
 * @param  string merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays
 */
int MergeStringArrays(string array1[], string array2[], string merged[]) {
   // Da results[] Referenz auf array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
   string tmp[]; ArrayResize(tmp, 0);

   int size1 = ArraySize(array1);
   if (size1 > 0)
      ArrayCopy(tmp, array1);

   int size2 = ArraySize(array2);
   if (size2 > 0)
      ArrayCopy(tmp, array2, size1);

   int size3 = size1 + size2;
   if (size3 > 0)
      ArrayCopy(merged, tmp);
   ArrayResize(merged, size3);

   ArrayResize(tmp, 0);
   return(size3);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Boolean-Arrays umgekehrt ist oder nicht.
 *
 * @param bool array[] - Boolean-Array
 *
 * @return bool
 */
bool IsReverseIndexedBoolArray(bool array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Integer-Arrays umgekehrt ist oder nicht.
 *
 * @param  int array[] - Integer-Array
 *
 * @return bool
 */
bool IsReverseIndexedIntArray(int array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Double-Arrays umgekehrt ist oder nicht.
 *
 * @param  double array[] - Double-Array
 *
 * @return bool
 */
bool IsReverseIndexedDoubleArray(double array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen String-Arrays umgekehrt ist oder nicht.
 *
 * @param  string array[] - String-Array
 *
 * @return bool
 */
bool IsReverseIndexedStringArray(string array[]) {
   if (ArraySetAsSeries(array, false))
      return(!ArraySetAsSeries(array, true));
   return(false);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Boolean-Arrays um.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedBoolArray()
 */
bool ReverseBoolArray(bool array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Integer-Arrays um.
 *
 * @param  int array[] - Integer-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedIntArray()
 */
bool ReverseIntArray(int array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Double-Arrays um.
 *
 * @param  double array[] - Double-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedDoubleArray()
 */
bool ReverseDoubleArray(double array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Kehrt die Reihenfolge der Elemente eines String-Arrays um.
 *
 * @param  string array[] - String-Array
 *
 * @return bool - TRUE, wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see IsReverseIndexedStringArray()
 */
bool ReverseStringArray(string array[]) {
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
 * BufferToHexStr(WIN32_FIND_DATA) = 20000000
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
int    wfd.FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0]); }
bool   wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_READONLY      == FILE_ATTRIBUTE_READONLY     ); }
bool   wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_HIDDEN        == FILE_ATTRIBUTE_HIDDEN       ); }
bool   wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SYSTEM        == FILE_ATTRIBUTE_SYSTEM       ); }
bool   wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DIRECTORY     == FILE_ATTRIBUTE_DIRECTORY    ); }
bool   wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ARCHIVE       == FILE_ATTRIBUTE_ARCHIVE      ); }
bool   wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DEVICE        == FILE_ATTRIBUTE_DEVICE       ); }
bool   wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NORMAL        == FILE_ATTRIBUTE_NORMAL       ); }
bool   wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_TEMPORARY     == FILE_ATTRIBUTE_TEMPORARY    ); }
bool   wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SPARSE_FILE   == FILE_ATTRIBUTE_SPARSE_FILE  ); }
bool   wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT); }
bool   wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_COMPRESSED    == FILE_ATTRIBUTE_COMPRESSED   ); }
bool   wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_OFFLINE       == FILE_ATTRIBUTE_OFFLINE      ); }
bool   wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NOT_INDEXED   == FILE_ATTRIBUTE_NOT_INDEXED  ); }
bool   wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ENCRYPTED     == FILE_ATTRIBUTE_ENCRYPTED    ); }
bool   wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_VIRTUAL       == FILE_ATTRIBUTE_VIRTUAL      ); }
string wfd.FileName                  (/*WIN32_FIND_DATA*/int wfd[]) { return(BufferCharsToStr(wfd, 44, MAX_PATH)); }
string wfd.AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]) { return(BufferCharsToStr(wfd, 304, 14)); }


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int wfd[] - WIN32_FIND_DATA structure
 *
 * @return string
 */
string wfd.FileAttributesToStr(/*WIN32_FIND_DATA*/int wfd[]) {
   string result = "";
   int flags = wfd.FileAttributes(wfd);

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
 * BufferToHexStr(FILETIME) =
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
 * BufferToHexStr(PROCESS_INFORMATION) = 68020000 74020000 D40E0000 B80E0000
 */
int pi.hProcess (/*PROCESS_INFORMATION*/int pi[]) { return(pi[0]); }
int pi.hThread  (/*PROCESS_INFORMATION*/int pi[]) { return(pi[1]); }
int pi.ProcessId(/*PROCESS_INFORMATION*/int pi[]) { return(pi[2]); }
int pi.ThreadId (/*PROCESS_INFORMATION*/int pi[]) { return(pi[3]); }


/**
 * Win32 structure SECURITY_ATTRIBUTES
 *
 * typedef struct _SECURITY_ATTRIBUTES {
 *    DWORD  nLength;
 *    LPVOID lpSecurityDescriptor;
 *    BOOL   bInheritHandle;
 * } SECURITY_ATTRIBUTES, sa;       // = 12 byte = int[3]
 *
 * BufferToHexStr(SECURITY_ATTRIBUTES) = 0C000000 00000000 00000000
 */
int  sa.Length            (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[0]); }
int  sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[1]); }
bool sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[2]); }


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
 * BufferToHexStr(STARTUPINFO) = 44000000 103E1500 703E1500 D83D1500 00000000 00000000 00000000 00000000 00000000 00000000 00000000 010E0000 03000000 00000000 41060000 01000100 00000000
 */
int si.cb            (/*STARTUPINFO*/int si[]) { return(si[ 0]); }
int si.Desktop       (/*STARTUPINFO*/int si[]) { return(si[ 2]); }
int si.Title         (/*STARTUPINFO*/int si[]) { return(si[ 3]); }
int si.X             (/*STARTUPINFO*/int si[]) { return(si[ 4]); }
int si.Y             (/*STARTUPINFO*/int si[]) { return(si[ 5]); }
int si.XSize         (/*STARTUPINFO*/int si[]) { return(si[ 6]); }
int si.YSize         (/*STARTUPINFO*/int si[]) { return(si[ 7]); }
int si.XCountChars   (/*STARTUPINFO*/int si[]) { return(si[ 8]); }
int si.YCountChars   (/*STARTUPINFO*/int si[]) { return(si[ 9]); }
int si.FillAttribute (/*STARTUPINFO*/int si[]) { return(si[10]); }
int si.Flags         (/*STARTUPINFO*/int si[]) { return(si[11]); }
int si.ShowWindow    (/*STARTUPINFO*/int si[]) { return(si[12] & 0xFFFF); }
int si.hStdInput     (/*STARTUPINFO*/int si[]) { return(si[14]); }
int si.hStdOutput    (/*STARTUPINFO*/int si[]) { return(si[15]); }
int si.hStdError     (/*STARTUPINFO*/int si[]) { return(si[16]); }

int si.setCb         (/*STARTUPINFO*/int& si[], int size   ) { si[ 0] =  size; }
int si.setFlags      (/*STARTUPINFO*/int& si[], int flags  ) { si[11] = flags; }
int si.setShowWindow (/*STARTUPINFO*/int& si[], int cmdShow) { si[12] = (si[12] & 0xFFFF0000) + (cmdShow & 0xFFFF); }


/**
 * Gibt die lesbare Version eines STARTUPINFO-Flags zurück.
 *
 * @param  int si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.FlagsToStr(/*STARTUPINFO*/int si[]) {
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
 * @param  int si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.ShowWindowToStr(/*STARTUPINFO*/int si[]) {
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
 * BufferToHexStr(SYSTEMTIME) = DB070100 06000F00 12003600 05000A03
 */
int st.Year     (/*SYSTEMTIME*/int st[]) { return(st[0] &  0x0000FFFF); }
int st.Month    (/*SYSTEMTIME*/int st[]) { return(st[0] >> 16        ); }
int st.DayOfWeek(/*SYSTEMTIME*/int st[]) { return(st[1] &  0x0000FFFF); }
int st.Day      (/*SYSTEMTIME*/int st[]) { return(st[1] >> 16        ); }
int st.Hour     (/*SYSTEMTIME*/int st[]) { return(st[2] &  0x0000FFFF); }
int st.Minute   (/*SYSTEMTIME*/int st[]) { return(st[2] >> 16        ); }
int st.Second   (/*SYSTEMTIME*/int st[]) { return(st[3] &  0x0000FFFF); }
int st.MilliSec (/*SYSTEMTIME*/int st[]) { return(st[3] >> 16        ); }


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
 * BufferToHexStr(TIME_ZONE_INFORMATION) = 88FFFFFF
 *                                         47005400 42002000 4E006F00 72006D00 61006C00 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    N   o    r   m    a   l    z   e    i   t
 *                                         00000A00 00000500 04000000 00000000
 *                                         00000000
 *                                         47005400 42002000 53006F00 6D006D00 65007200 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    S   o    m   m    e   r    z   e    i   t
 *                                         00000300 00000500 03000000 00000000
 *                                         C4FFFFFF
 */
int    tzi.Bias        (/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[0]); }                               // Bias in Minuten
string tzi.StandardName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 1, 16)); }
void   tzi.StandardDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 17, 4); }
int    tzi.StandardBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[21]); }                              // Bias in Minuten
string tzi.DaylightName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 22, 16)); }
void   tzi.DaylightDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 38, 4); }
int    tzi.DaylightBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[42]); }                              // Bias in Minuten


/**
 * Gibt den Inhalt eines Byte-Buffers als lesbaren String zurück. NULL-Bytes werden gestrichelt (…), Control-Character (< 0x20) fett (•) dargestellt.
 * Nützlich, um einen Bufferinhalt schnell visualisieren zu können.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 *
 * @return string
 */
string BufferToStr(int buffer[]) {
   int    size   = ArraySize(buffer);
   string result = CreateString(size << 2);                       // ein Integer = 4 Byte = 4 Zeichen

   for (int i=0; i < size; i++) {
      int integer = buffer[i];                                    // Integers nacheinander verarbeiten
                                                                                                            // +---+------------+------+
      for (int n=0; n < 4; n++) {                                                                           // | n |    byte    | char |
         int byte = integer & 0xFF;                               // einzelnes Byte des Integers lesen      // +---+------------+------+
         if (byte < 0x20) {                                       // nicht darstellbare Zeichen ersetzen    // | 0 | 0x000000FF |   1  |
            if (byte == 0x00) byte = PLACEHOLDER_ZERO_CHAR;       // NUL-Byte          (…)                  // | 1 | 0x0000FF00 |   2  |
            else              byte = PLACEHOLDER_CTL_CHAR;        // Control-Character (•)                  // | 2 | 0x00FF0000 |   3  |
         }                                                                                                  // | 3 | 0xFF000000 |   4  |
         result = StringSetChar(result, i<<2 + n, byte);          // Zeichen setzen                         // +---+------------+------+
         integer >>= 8;
      }
   }

   if (IsError(catch("BufferToStr()")))
      return("");
   return(result);
}


/**
 * Gibt den Inhalt eines Byte-Buffers als hexadezimalen String zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 *
 * @return string
 */
string BufferToHexStr(int buffer[]) {
   string result = "";
   int size = ArraySize(buffer);

   // Structs werden in MQL mit Hilfe von Integer-Arrays nachgebildet. Integers sind interpretierte binäre Werte (Reihenfolge von HIBYTE, LOBYTE, HIWORD, LOWORD).
   // Diese Interpretation muß wieder rückgängig gemacht werden.
   for (int i=0; i < size; i++) {
      string hex   = IntToHexStr(buffer[i]);
      string byte1 = StringSubstr(hex, 6, 2);
      string byte2 = StringSubstr(hex, 4, 2);
      string byte3 = StringSubstr(hex, 2, 2);
      string byte4 = StringSubstr(hex, 0, 2);
      result = StringConcatenate(result, " ", byte1, byte2, byte3, byte4);
   }

   if (size > 0)
      result = StringSubstr(result, 1);

   if (IsError(catch("BufferToHexStr()")))
      return("");
   return(result);
}


/**
 * Gibt ein einzelnes Zeichen (ein Byte) von der angegebenen Position des Buffers zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 * @param  int pos      - Zeichen-Position
 *
 * @return int - Zeichen-Code oder -1, wenn ein Fehler auftrat
 */
int BufferGetChar(int buffer[], int pos) {
   int chars = ArraySize(buffer) << 2;

   if (pos < 0)      return(_int(-1, catch("BufferGetChar(1)  invalid parameter pos: "+ pos, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (pos >= chars) return(_int(-1, catch("BufferGetChar(2)  invalid parameter pos: "+ pos, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int i = pos >> 2;                      // Index des relevanten Integers des Arrays     // +---+------------+
   int b = pos & 0x03;                    // Index des relevanten Bytes des Integers      // | b |    byte    |
                                                                                          // +---+------------+
   int integer = buffer[i] >> (b<<3);                                                     // | 0 | 0x000000FF |
   int char    = integer & 0xFF;                                                          // | 1 | 0x0000FF00 |
                                                                                          // | 2 | 0x00FF0000 |
   return(char);                                                                          // | 3 | 0xFF000000 |
}                                                                                         // +---+------------+


/**
 * Gibt die in einem Byte-Buffer im angegebenen Bereich gespeicherte und mit einem NULL-Byte terminierte ANSI-Charactersequenz zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 * @param  int from     - Index des ersten Bytes des für die Charactersequenz reservierten Bereichs, beginnend mit 0
 * @param  int length   - Anzahl der im Buffer für die Charactersequenz reservierten Bytes
 *
 * @return string - ANSI-String
 */
string BufferCharsToStr(int buffer[], int from, int length) {
   int fromChar=from, toChar=fromChar+length, bufferChars=ArraySize(buffer)<<2;

   if (fromChar < 0)            return(_empty(catch("BufferCharsToStr(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (fromChar >= bufferChars) return(_empty(catch("BufferCharsToStr(2)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (length < 0)              return(_empty(catch("BufferCharsToStr(3)  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (toChar >= bufferChars)   return(_empty(catch("BufferCharsToStr(4)  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (length == 0)
      return("");

   string result = "";
   int    chars, fromInt=fromChar>>2, toInt=toChar>>2, n=fromChar&0x03;    // Indizes der relevanten Array-Integers und des ersten Chars (liegt evt. nicht auf Integer-Boundary)

   for (int i=fromInt; i <= toInt; i++) {
      int byte, integer=buffer[i];

      for (; n < 4; n++) {                                                 // n: 0-1-2-3
         if (chars == length)
            break;
         byte = integer >> (n<<3) & 0xFF;                                  // integer >> 0-8-16-24
         if (byte == 0x00)                                                 // NULL-Byte: Ausbruch aus innerer Schleife
            break;
         result = StringConcatenate(result, CharToStr(byte));
         chars++;
      }
      if (byte == 0x00)                                                    // NULL-Byte: Ausbruch aus äußerer Schleife
         break;
      n = 0;
   }

   if (IsError(catch("BufferCharsToStr(5)")))
      return("");
   return(result);
}


/**
 * Gibt die in einem Byte-Buffer im angegebenen Bereich gespeicherte und mit einem NULL-Byte terminierte WCHAR-Charactersequenz (Multibyte-Characters) zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 * @param  int from     - Index des ersten Integers der Charactersequenz
 * @param  int length   - Anzahl der Integers des im Buffer für die Charactersequenz reservierten Bereiches
 *
 * @return string - ANSI-String
 *
 *
 *  NOTE:
 *  -----
 *  Zur Zeit arbeitet diese Funktion nur mit Charactersequenzen, die an Integer-Boundaries beginnen und enden.
 */
string BufferWCharsToStr(int buffer[], int from, int length) {
   if (from < 0)
      return(catch("BufferWCharsToStr(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   int to = from+length, size=ArraySize(buffer);
   if (to > size)
      return(catch("BufferWCharsToStr(2)  invalid parameter length: "+ length, ERR_INVALID_FUNCTION_PARAMVALUE));

   string result = "";

   for (int i=from; i < to; i++) {
      string strChar;
      int word, shift=0, integer=buffer[i];

      for (int n=0; n < 2; n++) {
         word = integer >> shift & 0xFFFF;
         if (word == 0)                                        // termination character (0x00)
            break;
         int byte1 = word      & 0xFF;
         int byte2 = word >> 8 & 0xFF;

         if (byte1!=0 && byte2==0) strChar = CharToStr(byte1);
         else                      strChar = "?";              // multi-byte character
         result = StringConcatenate(result, strChar);
         shift += 16;
      }
      if (word == 0)
         break;
   }

   if (IsError(catch("BufferWCharsToStr(3)")))
      return("");
   return(result);
}


/**
 * Konvertiert einen String-Buffer in ein String-Array.
 *
 * @param  int    buffer[]  - Buffer mit durch NULL-Zeichen getrennten Strings, terminiert durch ein weiteres NULL-Zeichen
 * @param  string results[] - Ergebnisarray
 *
 * @return int - Anzahl der konvertierten Strings
 */
int ExplodeStrings(int buffer[], string& results[]) {
   int  bufferSize = ArraySize(buffer);
   bool separator  = true;

   ArrayResize(results, 0);
   int resultSize = 0;

   for (int i=0; i < bufferSize; i++) {
      int value, shift=0, integer=buffer[i];

      // Die Reihenfolge von HIBYTE, LOBYTE, HIWORD und LOWORD eines Integers muß in die eines Strings konvertiert werden.
      for (int n=0; n < 4; n++) {
         value = integer >> shift & 0xFF;             // Integer in Bytes zerlegen

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

   if (IsError(catch("ExplodeStrings()")))
      return(0);
   return(ArraySize(results));
}


/**
 * Alias für ExplodeStringsA()
 */
int ExplodeStringsA(int buffer[], string& results[]) {
   return(ExplodeStrings(buffer, results));
}


/**
 *
 */
int ExplodeStringsW(int buffer[], string& results[]) {
   return(catch("ExplodeStringsW()   function not implemented", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Ermittelt den vollständigen Dateipfad der Zieldatei, auf die ein Windows-Shortcut (.lnk-File) zeigt.
 *
 * @return string lnkFilename - vollständige Pfadangabe zum Shortcut
 *
 * @return string - Dateipfad der Zieldatei oder Leerstring, falls ein Fehler auftrat
 */
string GetWin32ShortcutTarget(string lnkFilename) {
   // --------------------------------------------------------------------------
   // How to read the target's path from a .lnk-file:
   // --------------------------------------------------------------------------
   // Problem:
   //
   //    The COM interface to shell32.dll IShellLink::GetPath() fails!
   //
   // Solution:
   //
   //   We need to parse the file manually. The path can be found like shown
   //   here.  If the shell item id list is not present (as signaled in flags),
   //   we have to assume A = -6.
   //
   //  +-----------------+----------------------------------------------------+
   //  |     Byte-Offset | Description                                        |
   //  +-----------------+----------------------------------------------------+
   //  |               0 | 'L' (magic value)                                  |
   //  +-----------------+----------------------------------------------------+
   //  |            4-19 | GUID                                               |
   //  +-----------------+----------------------------------------------------+
   //  |           20-23 | shortcut flags                                     |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | ...                                                |
   //  +-----------------+----------------------------------------------------+
   //  |           76-77 | A (16 bit): size of shell item id list, if present |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | shell item id list, if present                     |
   //  +-----------------+----------------------------------------------------+
   //  |      78 + 4 + A | B (32 bit): size of file location info             |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | file location info                                 |
   //  +-----------------+----------------------------------------------------+
   //  |      78 + A + B | C (32 bit): size of local volume table             |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | local volume table                                 |
   //  +-----------------+----------------------------------------------------+
   //  |  78 + A + B + C | target path string (ending with 0x00)              |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | ...                                                |
   //  +-----------------+----------------------------------------------------+
   //  |             ... | 0x00                                               |
   //  +-----------------+----------------------------------------------------+
   //
   // @see http://www.codeproject.com/KB/shell/ReadLnkFile.aspx
   // --------------------------------------------------------------------------

   if (StringLen(lnkFilename) < 4 || StringRight(lnkFilename, 4)!=".lnk")
      return(_empty(catch("GetWin32ShortcutTarget(1)  invalid parameter lnkFilename: \""+ lnkFilename +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   // --------------------------------------------------------------------------
   // Get the .lnk-file content:
   // --------------------------------------------------------------------------
   int hFile = _lopen(string lnkFilename, OF_READ);
   if (hFile == HFILE_ERROR)
      return(_empty(catch("GetWin32ShortcutTarget(2) ->kernel32::_lopen(\""+ lnkFilename +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   int iNull[];
   int fileSize = GetFileSize(hFile, iNull);
   if (fileSize == 0xFFFFFFFF) {
      catch("GetWin32ShortcutTarget(3) ->kernel32::GetFileSize(\""+ lnkFilename +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
      _lclose(hFile);
      return("");
   }
   int buffer[]; InitializeBuffer(buffer, fileSize);

   int bytes = _lread(hFile, buffer, fileSize);
   if (bytes != fileSize) {
      catch("GetWin32ShortcutTarget(4) ->kernel32::_lread(\""+ lnkFilename +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
      _lclose(hFile);
      return("");
   }
   _lclose(hFile);

   if (bytes < 24)
      return(_empty(catch("GetWin32ShortcutTarget(5)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   int integers  = ArraySize(buffer);
   int charsSize = bytes;
   int chars[]; ArrayResize(chars, charsSize);     // int-Array in char-Array umwandeln

   for (int i, n=0; i < integers; i++) {
      for (int shift=0; shift<32 && n<charsSize; shift+=8, n++) {
         chars[n] = buffer[i] >> shift & 0xFF;
      }
   }

   // --------------------------------------------------------------------------
   // Check the magic value (first byte) and the GUID (16 byte from 5th byte):
   // --------------------------------------------------------------------------
   // The GUID is telling the version of the .lnk-file format. We expect the
   // following GUID (hex): 01 14 02 00 00 00 00 00 C0 00 00 00 00 00 00 46.
   // --------------------------------------------------------------------------
   if (chars[0] != 'L')                            // test the magic value
      return(_empty(catch("GetWin32ShortcutTarget(6)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

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
      return(_empty(catch("GetWin32ShortcutTarget(7)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));
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
      if (__LOG) log("GetWin32ShortcutTarget(8)  shortcut target is not a file or directory: \""+ lnkFilename +"\"");
      return("");
   }

   // --------------------------------------------------------------------------
   // Shell item id list (starts at offset 76 with 2 byte length):
   // --------------------------------------------------------------------------
   int A = -6;
   if (hasShellItemIdList) {
      i = 76;
      if (charsSize < i+2)
         return(_empty(catch("GetWin32ShortcutTarget(8)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));
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
   if (charsSize < i+4)
      return(_empty(catch("GetWin32ShortcutTarget(9)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

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
   if (charsSize < i+4)
      return(_empty(catch("GetWin32ShortcutTarget(10)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   int C  = chars[i];       i++;    // little endian format
       C |= chars[i] <<  8; i++;
       C |= chars[i] << 16; i++;
       C |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local path string (ending with 0x00):
   // --------------------------------------------------------------------------
   i = 78 + A + B + C;
   if (charsSize < i+1)
      return(_empty(catch("GetWin32ShortcutTarget(11)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   string target = "";
   for (; i < charsSize; i++) {
      if (chars[i] == 0x00)
         break;
      target = StringConcatenate(target, CharToStr(chars[i]));
   }
   if (StringLen(target) == 0)
      return(_empty(catch("GetWin32ShortcutTarget(12)  invalid target in .lnk file \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   // --------------------------------------------------------------------------
   // Convert the target path into the long filename format:
   // --------------------------------------------------------------------------
   // GetLongPathNameA() fails if the target file doesn't exist!
   // --------------------------------------------------------------------------
   string lfnBuffer[]; InitializeStringBuffer(lfnBuffer, MAX_PATH);
   if (GetLongPathNameA(target, lfnBuffer[0], MAX_PATH) != 0)        // file does exist
      target = lfnBuffer[0];

   //debug("GetWin32ShortcutTarget()   chars="+ ArraySize(chars) +"   A="+ A +"   B="+ B +"   C="+ C +"   target=\""+ target +"\"");

   if (IsError(catch("GetWin32ShortcutTarget(13)")))
      return("");
   return(target);
}


/**
 * MetaTrader4_Internal_Message. Pseudo-Konstante, wird beim ersten Zugriff initialisiert.
 *
 * @return int - Windows Message ID oder 0, falls ein Fehler auftrat
 */
int WM_MT4() {
   static int message;                                               // ohne Initializer (@see MQL.doc)

   if (message == 0) {
      message = RegisterWindowMessageA("MetaTrader4_Internal_Message");

      if (message == 0) {
         message = -1;                                               // RegisterWindowMessage() wird auch bei Fehler nur einmal aufgerufen
         catch("WM_MT4() ->user32::RegisterWindowMessageA()", ERR_WIN32_ERROR);
      }
   }

   if (message == -1)
      return(0);
   return(message);
}


/**
 * Schickt einen künstlichen Tick an den aktuellen Chart.
 *
 * @param  bool sound - ob der Tick akustisch bestätigt werden soll oder nicht (default: nein)
 *
 * @return int - Fehlerstatus
 */
int Chart.SendTick(bool sound=false) {
   bool testing, visualMode, testerStopped, testerPaused;

   if (IsExpert()) {
      testing       = IsTesting();
      visualMode    = IsVisualMode();
      testerStopped = false;                                         // Code wird ausgeführt, also beide FALSE
      testerPaused  = false;
   }
   else if (IsIndicator()) {
      testing       = IndicatorIsTesting();                          // TODO: IndicatorIsTesting() in init() und deinit() implementieren
      visualMode    = testing;
      testerStopped = false;                                         // Code wird ausgeführt, also beide FALSE
      testerPaused  = false;
   }
   else if (IsScript()) {
      testing    = ScriptIsTesting();
      visualMode = testing;
      if (testing) {
         int hWndSettings  = GetDlgItem(GetTesterWindow(), ID_TESTER_SETTINGS);
         int hBtnStartStop = GetDlgItem(hWndSettings, ID_TESTER_STARTSTOP);
         testerStopped = (GetWindowText(hBtnStartStop) == "Start");
         testerPaused  = (!testerStopped && GetWindowText(GetDlgItem(hWndSettings, ID_TESTER_PAUSERESUME))==">>");
      }
      else {
         testerStopped = false;                                      // wir sind nicht im Tester
         testerPaused  = false;
      }
   }

   int hWnd = WindowHandle(Symbol(), NULL);
   if (hWnd == 0)
      return(catch("Chart.SendTick(1) ->WindowHandle() = "+ hWnd, ERR_RUNTIME_ERROR));

   if (!testing) {
      if (!PostMessageA(hWnd, WM_MT4(), MT4_TICK, 0))
         return(catch("Chart.SendTick(2) ->user32::PostMessageA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
   }
   else if (visualMode && !testerStopped && testerPaused) {
      SendMessageA(hWnd, WM_COMMAND, ID_TESTER_TICK, 0);             // Bedingung kann nur durch Scripte erfüllt werden (EA's und Indikatoren sind niemals "paused")
   }

   if (sound)
      PlaySound("tick1.wav");

   return(NO_ERROR);
}


/**
 * Gibt den Namen des aktuellen History-Verzeichnisses zurück.  Der Name ist bei bestehender Verbindung identisch mit dem Rückgabewert von AccountServer(),
 * läßt sich mit dieser Funktion aber auch ohne Verbindung und bei Accountwechsel zuverlässig ermitteln.
 *
 * @return string - Verzeichnisname oder Leerstring, falls ein Fehler auftrat
 */
string GetServerDirectory() {
   // Der Verzeichnisname wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen
   // die Rückgabewerte der MQL-Accountfunktionen evt. schon auf den neuen Account, der aktuelle Tick gehört aber noch zum alten Chart des alten Verzeichnisses.
   // Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Verzeichnis befinden.

   static string static.result[1];
   static int    lastTick;                                           // hilft bei der Erkennung von Mehrfachaufrufen während desselben Ticks

   // 1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (ValidBars == 0) /*&&*/ if (Tick != lastTick)
      static.result[0] = "";
   lastTick = Tick;

   // 2) wenn Wert im Cache, gecachten Wert zurückgeben
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // 3.1) Wert ermitteln
   string directory = AccountServer();

   // 3.2) wenn AccountServer() == "", Verzeichnis manuell ermitteln
   if (StringLen(directory) == 0) {
      // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
      string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");
      int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
      if (hFile < 0)                                                 // u.a. wenn das Serververzeichnis noch nicht existiert
         return(_empty(catch("GetServerDirectory(1) ->FileOpenHistory(\""+ fileName +"\")")));
      FileClose(hFile);

      // Datei suchen und Verzeichnisnamen auslesen
      string pattern = StringConcatenate(TerminalPath(), "\\history\\*");
      /*WIN32_FIND_DATA*/int wfd[]; InitializeBuffer(wfd, WIN32_FIND_DATA.size);
      int hFindDir=FindFirstFileA(pattern, wfd), next=hFindDir;

      while (next > 0) {
         if (wfd.FileAttribute.Directory(wfd)) {
            string name = wfd.FileName(wfd);
            if (name != ".") /*&&*/ if (name != "..") {
               pattern = StringConcatenate(TerminalPath(), "\\history\\", name, "\\", fileName);
               int hFindFile = FindFirstFileA(pattern, wfd);
               if (hFindFile != INVALID_HANDLE_VALUE) {
                  //debug("FindTradeServerDirectory()   file = "+ pattern +"   found");
                  FindClose(hFindFile);
                  directory = name;
                  if (!DeleteFileA(pattern))                         // tmp. Datei per Win-API löschen (MQL kann es im History-Verzeichnis nicht)
                     return(_empty(catch("GetServerDirectory(2) ->kernel32::DeleteFileA(filename=\""+ pattern +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR), FindClose(hFindDir)));
                  break;
               }
            }
         }
         next = FindNextFileA(hFindDir, wfd);
      }
      if (hFindDir == INVALID_HANDLE_VALUE)
         return(_empty(catch("GetServerDirectory(3) directory \""+ TerminalPath() +"\\history\\\" not found", ERR_FILE_NOT_FOUND)));

      FindClose(hFindDir);
      ArrayResize(wfd, 0);
      //debug("GetServerDirectory()   resolved directory = \""+ directory +"\"");
   }

   int error = GetLastError();
   if (IsError(error))
      return(_empty(catch("GetServerDirectory(4)", error)));

   if (StringLen(directory) == 0)
      return(_empty(catch("GetServerDirectory(5)  cannot find trade server directory", ERR_RUNTIME_ERROR)));

   static.result[0] = directory;
   return(static.result[0]);
}


/**
 * Gibt den Kurznamen der Firma des aktuellen Accounts zurück. Der Name wird aus dem Namen des Account-Servers und
 * nicht aus dem Rückgabewert von AccountCompany() ermittelt.
 *
 * @return string - Kurzname
 */
string ShortAccountCompany() {
   string server=StringToLower(GetServerDirectory());

   if      (StringStartsWith(server, "alpari-"            )) return("Alpari"          );
   else if (StringStartsWith(server, "alparibroker-"      )) return("Alpari"          );
   else if (StringStartsWith(server, "alpariuk-"          )) return("Alpari"          );
   else if (StringStartsWith(server, "alparius-"          )) return("Alpari"          );
   else if (StringStartsWith(server, "apbgtrading-"       )) return("APBG"            );
   else if (StringStartsWith(server, "atcbrokers-"        )) return("ATC"             );
   else if (StringStartsWith(server, "atcbrokersest-"     )) return("ATC"             );
   else if (StringStartsWith(server, "atcbrokersliq1-"    )) return("ATC"             );
   else if (StringStartsWith(server, "broco-"             )) return("BroCo"           );
   else if (StringStartsWith(server, "brocoinvestments-"  )) return("BroCo"           );
   else if (StringStartsWith(server, "dukascopy-"         )) return("Dukascopy"       );
   else if (StringStartsWith(server, "easyforex-"         )) return("EasyForex"       );
   else if (StringStartsWith(server, "finfx-"             )) return("FinFX"           );
   else if (StringStartsWith(server, "forex-"             )) return("Forex Ltd"       );
   else if (StringStartsWith(server, "forexbaltic-"       )) return("FB Capital"      );
   else if (StringStartsWith(server, "fxprimus-"          )) return("FX Primus"       );
   else if (StringStartsWith(server, "fxpro.com-"         )) return("FxPro"           );
   else if (StringStartsWith(server, "fxdd-"              )) return("FXDD"            );
   else if (StringStartsWith(server, "gcmfx-"             )) return("Gallant"         );
   else if (StringStartsWith(server, "gftforex-"          )) return("GFT"             );
   else if (StringStartsWith(server, "inovatrade-"        )) return("InovaTrade"      );
   else if (StringStartsWith(server, "investorseurope-"   )) return("Investors Europe");
   else if (StringStartsWith(server, "liteforex-"         )) return("LiteForex"       );
   else if (StringStartsWith(server, "londoncapitalgr-"   )) return("London Capital"  );
   else if (StringStartsWith(server, "londoncapitalgroup-")) return("London Capital"  );
   else if (StringStartsWith(server, "mbtrading-"         )) return("MB Trading"      );
   else if (StringStartsWith(server, "migbank-"           )) return("MIG"             );
   else if (StringStartsWith(server, "oanda-"             )) return("Oanda"           );
   else if (StringStartsWith(server, "sig-"               )) return("LiteForex"       );
   else if (StringStartsWith(server, "sts-"               )) return("STS"             );
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
   string sNull;
   int    iNull[];

   /*STARTUPINFO*/int si[]; InitializeBuffer(si, STARTUPINFO.size);
      si.setCb        (si, STARTUPINFO.size);
      si.setFlags     (si, STARTF_USESHOWWINDOW);
      si.setShowWindow(si, cmdShow);

   /*PROCESS_INFORMATION*/int pi[]; InitializeBuffer(pi, PROCESS_INFORMATION.size);

   if (!CreateProcessA(sNull, cmdLine, iNull, iNull, false, 0, iNull, sNull, si, pi))
      return(catch("WinExecAndWait(1) ->kernel32::CreateProcessA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   int result = WaitForSingleObject(pi.hProcess(pi), INFINITE);

   if (result != WAIT_OBJECT_0) {
      if (result == WAIT_FAILED) catch("WinExecAndWait(2) ->kernel32::WaitForSingleObject()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
      else if (__LOG)            log("WinExecAndWait() ->kernel32::WaitForSingleObject() => "+ WaitForSingleObjectValueToStr(result));
   }

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("WinExecAndWait(3)"));
}


/**
 * Liest eine Datei zeilenweise (ohne Zeilenende-Zeichen) in ein Array ein.
 *
 * @param  string filename       - Dateiname mit zu "..\files\" relativer Pfadangabe
 * @param  string result[]       - Array zur Aufnahme der einzelnen Zeilen
 * @param  bool   skipEmptyLines - ob leere Zeilen übersprungen werden sollen (default: nein)
 *
 * @return int - Anzahl der eingelesenen Zeilen oder -1, falls ein Fehler auftrat
 */
int FileReadLines(string filename, string result[], bool skipEmptyLines=false) {
   int hFile, hFileBin, fieldSeparator='\t';

   // Datei öffnen
   hFile = FileOpen(filename, FILE_CSV|FILE_READ, fieldSeparator);         // erwartet Pfadangabe relativ zu .\experts\files
   if (hFile < 0)
      return(_int(-1, catch("FileReadLines(1) ->FileOpen(\""+ filename +"\", FILE_CSV|FILE_READ)", GetLastError())));


   // Schnelle Rückkehr bei leerer Datei
   if (FileSize(hFile) == 0) {
      FileClose(hFile);
      ArrayResize(result, 0);
      return(ifInt(IsError(catch("FileReadLines(2)")), -1, 0));
   }


   // Datei zeilenweise einlesen
   bool newLine=true, blankLine=false, lineEnd=true, wasSeparator;
   string line, value, lines[]; ArrayResize(lines, 0);                     // Zwischenspeicher für gelesene Zeilen
   int i, len, fPointer;                                                   // Zeilenzähler und Länge des gelesenen Strings

   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                                       // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                                 // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
         fPointer  = FileTell(hFile);                                      // zeigt immer auf den aktuellen Zeilenbeginn
      }

      // Zeile auslesen
      value = FileReadString(hFile);

      // auf Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd  = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                                    // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                                           // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
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
         //debug("FileReadLines()   new line "+ i +",   "+ StringLen(value) +" chars,   fPointer="+ FileTell(hFile));
      }
      else {
         // bei langen Zeilen prüfen, ob das letzte Zeichen ein Separator war (FileReadString() liest max. 4095 Zeichen)
         len = StringLen(lines[i-1]);
         if (len < 4095) {
            wasSeparator = true;
         }
         else {
            if (hFileBin == 0) {
               hFileBin = FileOpen(filename, FILE_BIN|FILE_READ);
               if (hFileBin < 0) {
                  FileClose(hFile);
                  return(_int(-1, catch("FileReadLines(3) ->FileOpen(\""+ filename +"\", FILE_BIN|FILE_READ)", GetLastError())));
               }
            }
            if (!FileSeek(hFileBin, fPointer+len, SEEK_SET)) {
               FileClose(hFile);
               FileClose(hFileBin);
               return(_int(-1, catch("FileReadLines(4) ->FileSeek(hFileBin, "+ (fPointer+len) +", SEEK_SET)", GetLastError())));
            }
            wasSeparator = (fieldSeparator == FileReadInteger(hFileBin, CHAR_VALUE));
         }

         if (wasSeparator) lines[i-1] = StringConcatenate(lines[i-1], CharToStr(fieldSeparator), value);
         else              lines[i-1] = StringConcatenate(lines[i-1],                            value);
         //debug("FileReadLines()   extend line "+ i +",   adding "+ StringLen(value) +" chars to existing "+ StringLen(lines[i-1]) +" chars,   fPointer="+ FileTell(hFile));
      }
   }

   // Dateiende hat ERR_END_OF_FILE ausgelöst
   int error = GetLastError();
   if (error!=ERR_END_OF_FILE) /*&&*/ if (IsError(error)) {
      FileClose(hFile);
      if (hFileBin != 0)
         FileClose(hFileBin);
      return(_int(-1, catch("FileReadLines(5)", error)));
   }

   // Dateien schließen
   FileClose(hFile);
   if (hFileBin != 0)
      FileClose(hFileBin);

   // Zeilen in Ergebnisarray kopieren
   ArrayResize(result, i);
   if (i > 0)
      ArrayCopy(result, lines);

   if (ArraySize(lines) > 0)
      ArrayResize(lines, 0);
   return(ifInt(IsError(catch("FileReadLines(6)")), -1, i));
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
 * Gibt das Standardsymbol des aktuellen Symbols zurück.
 * (z.B. StdSymbol() => "EURUSD")
 *
 * @return string - Standardsymbol oder das aktuelle Symbol, wenn das Standardsymbol unbekannt ist
 *
 *
 *  NOTE:
 *  -----
 *  Alias für GetStandardSymbol(Symbol())
 */
string StdSymbol() {
   static string static.lastSymbol[1], static.result[1];
   /*
   Indikatoren:  lokale Library-Arrays:  live:    werden bei Symbolwechsel nicht zurückgesetzt
   EA's:         lokale Library-Arrays:  live:    werden bei Symbolwechsel nicht zurückgesetzt
   EA's:         lokale Library-Arrays:  Tester:  werden bei Symbolwechsel und Start nicht zurückgesetzt
   */

   // Symbolwechsel erkennen
   if (StringLen(static.result[0]) > 0) {
      if (Symbol() == static.lastSymbol[0])
         return(static.result[0]);
   }

   static.lastSymbol[0] = Symbol();
   static.result    [0] = GetStandardSymbol(Symbol());

   return(static.result[0]);
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
 *  NOTE:
 *  -----
 *  Alias für GetStandardSymbolOrAlt(symbol, symbol)
 */
string GetStandardSymbol(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetStandardSymbol()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
   return(GetStandardSymbolOrAlt(symbol, symbol));
}


/**
 * Gibt für ein broker-spezifisches Symbol das Standardsymbol oder den angegebenen Alternativwert zurück.
 * (z.B. GetStandardSymbolOrAlt("EURUSDm") => "EURUSD")
 *
 * @param  string symbol   - broker-spezifisches Symbol
 * @param  string altValue - alternativer Rückgabewert, falls kein Standardsymbol gefunden wurde
 *
 * @return string - Ergebnis
 *
 *
 *  NOTE:
 *  -----
 *  Im Unterschied zu GetStandardSymbolStrict() erlaubt diese Funktion die Angabe eines Alternativwertes, läßt jedoch nicht mehr so
 *  einfach erkennen, ob ein Standardsymbol gefunden wurde oder nicht.
 */
string GetStandardSymbolOrAlt(string symbol, string altValue="") {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetStandardSymbolOrAlt()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string value = GetStandardSymbolStrict(symbol);

   if (StringLen(value) == 0)
      value = altValue;

   return(value);
}


/**
 * Gibt für ein broker-spezifisches Symbol das Standardsymbol zurück.
 * (z.B. GetStandardSymbolStrict("EURUSDm") => "EURUSD")
 *
 * @param  string symbol - Broker-spezifisches Symbol
 *
 * @return string - Standardsymbol oder Leerstring, falls kein Standardsymbol gefunden wurde.
 *
 *
 * @see GetStandardSymbolOrAlt() - für die Angabe eines Alternativwertes, wenn kein Standardsymbol gefunden wurde
 */
string GetStandardSymbolStrict(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetStandardSymbolStrict()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

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
                if (StringStartsWith(symbol, "CHFPLN")) return("CHFPLN");
                if (StringStartsWith(symbol, "CHFSGD")) return("CHFSGD");
                if (StringStartsWith(symbol, "CHFZAR")) return("CHFZAR");
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
                if (StringStartsWith(symbol, "GBPPLN")) return("GBPPLN");
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

      case 'O': break;

      case 'P': if (StringStartsWith(symbol, "PLNJPY")) return("PLNJPY");
                break;

      case 'Q': break;

      case 'S': if (StringStartsWith(symbol, "SEKJPY")) return("SEKJPY");
                if (StringStartsWith(symbol, "SGDJPY")) return("SGDJPY");
                if (symbol == "SILVER"    )             return("XAGUSD");
                if (symbol == "SILVEREURO")             return("XAGEUR");
                break;

      case 'T': break;
                if (StringStartsWith(symbol, "TRYJPY")) return("TRYJPY");

      case 'U': if (StringStartsWith(symbol, "USDCAD")) return("USDCAD");
                if (StringStartsWith(symbol, "USDCHF")) return("USDCHF");
                if (StringStartsWith(symbol, "USDCCK")) return("USDCZK");
                if (StringStartsWith(symbol, "USDCNY")) return("USDCNY");
                if (StringStartsWith(symbol, "USDCZK")) return("USDCZK");
                if (StringStartsWith(symbol, "USDDKK")) return("USDDKK");
                if (StringStartsWith(symbol, "USDHKD")) return("USDHKD");
                if (StringStartsWith(symbol, "USDHRK")) return("USDHRK");
                if (StringStartsWith(symbol, "USDHUF")) return("USDHUF");
                if (StringStartsWith(symbol, "USDINR")) return("USDINR");
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
                if (StringStartsWith(symbol, "USDSAR")) return("USDSAR");
                if (StringStartsWith(symbol, "USDSGD")) return("USDSGD");
                if (StringStartsWith(symbol, "USDTHB")) return("USDTHB");
                if (StringStartsWith(symbol, "USDTRY")) return("USDTRY");
                if (StringStartsWith(symbol, "USDTWD")) return("USDTWD");
                if (StringStartsWith(symbol, "USDZAR")) return("USDZAR");
                if (symbol == "USDX")                   return("USDX"  );
                break;

      case 'V':
      case 'W': break;

      case 'X': if (StringStartsWith(symbol, "XAGEUR")) return("XAGEUR");
                if (StringStartsWith(symbol, "XAGJPY")) return("XAGJPY");
                if (StringStartsWith(symbol, "XAGUSD")) return("XAGUSD");
                if (StringStartsWith(symbol, "XAUEUR")) return("XAUEUR");
                if (StringStartsWith(symbol, "XAUJPY")) return("XAUJPY");
                if (StringStartsWith(symbol, "XAUUSD")) return("XAUUSD");
                break;

      case 'Y': break;

      case 'Z': if (StringStartsWith(symbol, "ZARJPY")) return("ZARJPY");

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
 *  NOTE:
 *  -----
 *  Alias für GetSymbolNameOrAlt(symbol, symbol)
 */
string GetSymbolName(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetSymbolName()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
   return(GetSymbolNameOrAlt(symbol, symbol));
}


/**
 * Gibt den Kurznamen eines Symbols zurück oder den angegebenen Alternativwert, wenn das Symbol unbekannt ist.
 * (z.B. GetSymbolNameOrAlt("EURUSD") => "EUR/USD")
 *
 * @param  string symbol   - Symbol
 * @param  string altValue - alternativer Rückgabewert
 *
 * @return string - Ergebnis
 *
 * @see GetSymbolNameStrict()
 */
string GetSymbolNameOrAlt(string symbol, string altValue="") {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetSymbolNameOrAlt()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

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
 * @return string - Kurzname oder Leerstring, falls das Symbol unbekannt ist
 */
string GetSymbolNameStrict(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetSymbolNameStrict()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

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
   if (symbol == "CHFPLN"  ) return("CHF/PLN"  );
   if (symbol == "CHFSGD"  ) return("CHF/SGD"  );
   if (symbol == "CHFZAR"  ) return("CHF/ZAR"  );
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
   if (symbol == "GBPPLN"  ) return("GBP/PLN"  );
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
   if (symbol == "PLNJPY"  ) return("PLN/JPY"  );
   if (symbol == "SEKJPY"  ) return("SEK/JPY"  );
   if (symbol == "SGDJPY"  ) return("SGD/JPY"  );
   if (symbol == "TRYJPY"  ) return("TRY/JPY"  );
   if (symbol == "USDCAD"  ) return("USD/CAD"  );
   if (symbol == "USDCHF"  ) return("USD/CHF"  );
   if (symbol == "USDCNY"  ) return("USD/CNY"  );
   if (symbol == "USDCZK"  ) return("USD/CZK"  );
   if (symbol == "USDDKK"  ) return("USD/DKK"  );
   if (symbol == "USDHKD"  ) return("USD/HKD"  );
   if (symbol == "USDHRK"  ) return("USD/HRK"  );
   if (symbol == "USDHUF"  ) return("USD/HUF"  );
   if (symbol == "USDINR"  ) return("USD/INR"  );
   if (symbol == "USDJPY"  ) return("USD/JPY"  );
   if (symbol == "USDLFX"  ) return("USD-Index");
   if (symbol == "USDLTL"  ) return("USD/LTL"  );
   if (symbol == "USDLVL"  ) return("USD/LVL"  );
   if (symbol == "USDMXN"  ) return("USD/MXN"  );
   if (symbol == "USDNOK"  ) return("USD/NOK"  );
   if (symbol == "USDPLN"  ) return("USD/PLN"  );
   if (symbol == "USDRUB"  ) return("USD/RUB"  );
   if (symbol == "USDSAR"  ) return("USD/SAR"  );
   if (symbol == "USDSEK"  ) return("USD/SEK"  );
   if (symbol == "USDSGD"  ) return("USD/SGD"  );
   if (symbol == "USDTHB"  ) return("USD/THB"  );
   if (symbol == "USDTRY"  ) return("USD/TRY"  );
   if (symbol == "USDTWD"  ) return("USD/TWD"  );
   if (symbol == "USDX"    ) return("USD-Index");
   if (symbol == "USDZAR"  ) return("USD/ZAR"  );
   if (symbol == "XAGEUR"  ) return("XAG/EUR"  );
   if (symbol == "XAGJPY"  ) return("XAG/JPY"  );
   if (symbol == "XAGUSD"  ) return("XAG/USD"  );
   if (symbol == "XAUEUR"  ) return("XAU/EUR"  );
   if (symbol == "XAUJPY"  ) return("XAU/JPY"  );
   if (symbol == "XAUUSD"  ) return("XAU/USD"  );
   if (symbol == "ZARJPY"  ) return("ZAR/JPY"  );

   return("");
}


/**
 * Gibt den Langnamen eines Symbols zurück.
 * (z.B. GetLongSymbolName("EURUSD") => "EUR/USD")
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - Langname oder der übergebene Ausgangswert, wenn kein Langname gefunden wurde
 *
 *
 *  NOTE:
 *  -----
 *  Alias für GetLongSymbolNameOrAlt(symbol, symbol)
 */
string GetLongSymbolName(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetLongSymbolName()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
   return(GetLongSymbolNameOrAlt(symbol, symbol));
}


/**
 * Gibt den Langnamen eines Symbols zurück oder den angegebenen Alternativwert, wenn kein Langname gefunden wurde.
 * (z.B. GetLongSymbolNameOrAlt("USDLFX") => "USD-Index (LFX)")
 *
 * @param  string symbol   - Symbol
 * @param  string altValue - alternativer Rückgabewert
 *
 * @return string - Ergebnis
 */
string GetLongSymbolNameOrAlt(string symbol, string altValue="") {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetLongSymbolNameOrAlt()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string value = GetLongSymbolNameStrict(symbol);

   if (StringLen(value) == 0)
      value = altValue;

   return(value);
}


/**
 * Gibt den Langnamen eines Symbols zurück.
 * (z.B. GetLongSymbolNameStrict("USDLFX") => "USD-Index (LFX)")
 *
 * @param  string symbol - Symbol
 *
 * @return string - Langname oder Leerstring, falls das Symnol unbekannt ist oder keinen Langnamen hat
 */
string GetLongSymbolNameStrict(string symbol) {
   if (StringLen(symbol) == 0)
      return(_empty(catch("GetLongSymbolNameStrict()   invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   symbol = GetStandardSymbolStrict(symbol);

   if (StringLen(symbol) == 0)
      return("");

   if (symbol == "#DJI.X"  ) return("Dow Jones Industrial"    );
   if (symbol == "#DJT.X"  ) return("Dow Jones Transportation");
   if (symbol == "#N100.X" ) return("Nasdaq 100"              );
   if (symbol == "#NCOMP.X") return("Nasdaq Composite"        );
   if (symbol == "#NIK.X"  ) return("Nikkei 225"              );
   if (symbol == "#SPX.X"  ) return("S&P 500"                 );
   if (symbol == "AUDLFX"  ) return("AUD-Index (LFX)"         );
   if (symbol == "CADLFX"  ) return("CAD-Index (LFX)"         );
   if (symbol == "CHFLFX"  ) return("CHF-Index (LFX)"         );
   if (symbol == "EURLFX"  ) return("EUR-Index (LFX)"         );
   if (symbol == "EURX"    ) return("EUR-Index (CME)"         );
   if (symbol == "GBPLFX"  ) return("GBP-Index (LFX)"         );
   if (symbol == "LFXJPY"  ) return("1/JPY-Index (LFX)"       );
   if (symbol == "NZDLFX"  ) return("NZD-Index (LFX)"         );
   if (symbol == "USDLFX"  ) return("USD-Index (LFX)"         );
   if (symbol == "USDX"    ) return("USD-Index (CME)"         );
   if (symbol == "XAGEUR"  ) return("Silver/EUR"              );
   if (symbol == "XAGJPY"  ) return("Silver/JPY"              );
   if (symbol == "XAGUSD"  ) return("Silver/USD"              );
   if (symbol == "XAUEUR"  ) return("Gold/EUR"                );
   if (symbol == "XAUJPY"  ) return("Gold/JPY"                );
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
 * Konvertiert ein Boolean-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  bool   values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string BoolsToStr(bool values[][], string separator=", ") {
   return(BoolsToStr_intern(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string BoolsToStr_intern(bool values2[][], bool values3[][][], string separator) {
   if (separator == "0")   // NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;

   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinBools(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      bool      valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = BoolsToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      bool      valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = BoolsToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("BoolsToStr()  illegal parameter values, too many dimensions = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Gibt die aktuelle Zeit in GMT zurück.
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime TimeGMT() {
   /*SYSTEMTIME*/int st[]; InitializeBuffer(st, SYSTEMTIME.size);
   GetSystemTime(st);

   int year  = st.Year(st);
   int month = st.Month(st);
   int day   = st.Day(st);
   int hour  = st.Hour(st);
   int min   = st.Minute(st);
   int sec   = st.Second(st);

   string strTime = StringConcatenate(year, ".", month, ".", day, " ", hour, ":", min, ":", sec);
   datetime time  = StrToTime(strTime);

   int error = GetLastError();
   if (IsError(error))
      return(_int(-1, catch("TimeGMT()", error)));
   return(time);
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
   if (StringLen(prefix) == 0)
      return(_false(catch("StringStartsWith()   empty prefix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   if (StringLen(prefix) == 0)
      return(_false(catch("StringIStartsWith()   empty prefix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   int lenObject  = StringLen(object);
   int lenPostfix = StringLen(postfix);

   if (lenPostfix == 0)
      return(_false(catch("StringEndsWith()   empty postfix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (lenObject < lenPostfix)
      return(false);

   if (lenObject == lenPostfix)
      return(object == postfix);

   int start = lenObject-lenPostfix;
   return(StringFind(object, postfix, start) == start);
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
   int lenObject  = StringLen(object);
   int lenPostfix = StringLen(postfix);

   if (lenPostfix == 0)
      return(_false(catch("StringIEndsWith()   empty postfix \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (lenObject < lenPostfix)
      return(false);

   object  = StringToUpper(object);
   postfix = StringToUpper(postfix);

   if (lenObject == lenPostfix)
      return(object == postfix);

   int start = lenObject-lenPostfix;
   return(StringFind(object, postfix, start) == start);
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
   if (n > 0) return(StringSubstr   (value, 0, n                 ));
   if (n < 0) return(StringSubstrFix(value, 0, StringLen(value)+n));
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
   if (n > 0) return(StringSubstr(value, StringLen(value)-n));
   if (n < 0) return(StringSubstr(value, -n                ));
   return("");
}


/**
 * Bugfix für StringSubstr(string, start, length=0), die MQL-Funktion gibt für length=0 Unfug zurück.
 * Ermöglicht zusätzlich die Angabe negativer Werte für start und length.
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
      start = Max(0, start + StringLen(object));

   if (length < 0) {
      start += 1 + length;
      length = Abs(length);
   }
   return(StringSubstr(object, start, length));
}


/**
 * Ersetzt in einem String alle Vorkommen eines Substrings durch einen anderen String (kein rekursives Ersetzen).
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
   if (foundPos == -1)
      return(object);

   string result = "";

   while (foundPos > -1) {
      result   = StringConcatenate(result, StringSubstrFix(object, startPos, foundPos-startPos), replace);
      startPos = foundPos + StringLen(search);
      foundPos = StringFind(object, search, startPos);
   }
   result = StringConcatenate(result, StringSubstr(object, startPos));

   int error = GetLastError();
   if (IsError(error))
      return(_empty(catch("StringReplace()", error)));
   return(result);
}


/**
 * Erweitert einen String mit einem anderen String linksseitig auf eine gewünschte Mindestlänge.
 *
 * @param  string input      - Ausgangsstring
 * @param  int    pad_length - gewünschte Mindestlänge
 * @param  string pad_string - zum Erweitern zu verwendender String (default: Leerzeichen)
 *
 * @return string
 */
string StringLeftPad(string input, int pad_length, string pad_string=" ") {
   int length = StringLen(input);

   while (length < pad_length) {
      input  = StringConcatenate(pad_string, input);
      length = StringLen(input);
   }
   if (length > pad_length)
      input = StringRight(input, pad_length);

   return(input);
}


/**
 * Erweitert einen String mit einem anderen String rechtsseitig auf eine gewünschte Mindestlänge.
 *
 * @param  string input      - Ausgangsstring
 * @param  int    pad_length - gewünschte Mindestlänge
 * @param  string pad_string - zum Erweitern zu verwendender String (default: Leerzeichen)
 *
 * @return string
 */
string StringRightPad(string input, int pad_length, string pad_string=" ") {
   int length = StringLen(input);

   while (length < pad_length) {
      input  = StringConcatenate(input, pad_string);
      length = StringLen(input);
   }
   if (length > pad_length)
      input = StringLeft(input, pad_length);

   return(input);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionStartTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerPrevSessionStartTime(1)  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime fxtTime = ServerToFXT(serverTime);
   if (fxtTime == -1)
      return(-1);

   datetime startTime = GetFXTPrevSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(FXTToServerTime(startTime));
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionEndTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerPrevSessionEndTime(1)  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetServerPrevSessionStartTime(serverTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Startzeit oder -1, falls ein Fehler auftrat
 */
datetime GetServerSessionStartTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerSessionStartTime(1)  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int offset = GetServerToFXTOffset(datetime serverTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime fxtTime = serverTime - offset;
   if (fxtTime < 0)
      return(_int(-1, catch("GetServerSessionStartTime(2)  illegal datetime result: "+ fxtTime +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   int dayOfWeek = TimeDayOfWeek(fxtTime);

   if (dayOfWeek==SATURDAY || dayOfWeek==SUNDAY)
      return(_int(-1, SetLastError(ERR_MARKET_CLOSED)));

   fxtTime   -= TimeHour(fxtTime)*HOURS + TimeMinute(fxtTime)*MINUTES + TimeSeconds(fxtTime)*SECONDS;
   serverTime = fxtTime + offset;

   if (serverTime < 0)
      return(_int(-1, catch("GetServerSessionStartTime(3)  illegal datetime result: "+ serverTime +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_INVALID_FUNCTION_PARAMVALUE)));
   return(serverTime);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetServerSessionEndTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerSessionEndTime()  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetServerSessionStartTime(serverTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetServerNextSessionStartTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerNextSessionStartTime()  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime fxtTime = ServerToFXT(serverTime);
   if (fxtTime == -1)
      return(-1);

   datetime startTime = GetFXTNextSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(FXTToServerTime(startTime));
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetServerNextSessionEndTime(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("GetServerNextSessionEndTime()  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetServerNextSessionStartTime(datetime serverTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTPrevSessionStartTime(datetime gmtTime) {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTPrevSessionStartTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime fxtTime = GMTToFXT(gmtTime);
   if (fxtTime == -1)
      return(-1);

   datetime startTime = GetFXTPrevSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(FXTToGMT(startTime));
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTPrevSessionEndTime(datetime gmtTime) {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTPrevSessionEndTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetGMTPrevSessionStartTime(gmtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTSessionStartTime(datetime gmtTime) /*throws ERR_MARKET_CLOSED*/ {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTSessionStartTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime fxtTime = GMTToFXT(gmtTime);
   if (fxtTime == -1)
      return(-1);

   datetime startTime = GetFXTSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(FXTToGMT(startTime));
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTSessionEndTime(datetime gmtTime) /*throws ERR_MARKET_CLOSED*/ {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTSessionEndTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetGMTSessionStartTime(datetime gmtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTNextSessionStartTime(datetime gmtTime) {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTNextSessionStartTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime fxtTime = GMTToFXT(gmtTime);
   if (fxtTime == -1)
      return(-1);

   datetime startTime = GetFXTNextSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(FXTToGMT(startTime));
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetGMTNextSessionEndTime(datetime gmtTime) {
   if (gmtTime < 0)
      return(_int(-1, catch("GetGMTNextSessionEndTime()  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetGMTNextSessionStartTime(datetime gmtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTPrevSessionStartTime(datetime fxtTime) {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTPrevSessionStartTime(1)  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) - 1*DAY;
   if (startTime < 0)
      return(_int(-1, catch("GetFXTPrevSessionStartTime(2)  illegal datetime result: "+ startTime +" (not a time)", ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(startTime);
   if      (dow == SATURDAY) startTime -= 1*DAY;
   else if (dow == SUNDAY  ) startTime -= 2*DAYS;

   if (startTime < 0)
      return(_int(-1, catch("GetFXTPrevSessionStartTime(3)  illegal datetime result: "+ startTime +" (not a time)", ERR_RUNTIME_ERROR)));

   return(startTime);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTPrevSessionEndTime(datetime fxtTime) {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTPrevSessionEndTime()  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetFXTPrevSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTSessionStartTime(datetime fxtTime) /*throws ERR_MARKET_CLOSED*/ {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTSessionStartTime(1)  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime);
   if (startTime < 0)
      return(_int(-1, catch("GetFXTSessionStartTime(2)  illegal datetime result: "+ startTime +" (not a time)", ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(startTime);
   if (dow == SATURDAY || dow == SUNDAY)
      return(_int(-1, SetLastError(ERR_MARKET_CLOSED)));

   return(startTime);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTSessionEndTime(datetime fxtTime) /*throws ERR_MARKET_CLOSED*/ {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTSessionEndTime()  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetFXTSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTNextSessionStartTime(datetime fxtTime) {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTNextSessionStartTime()  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) + 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(startTime);
   if      (dow == SATURDAY) startTime += 2*DAYS;
   else if (dow == SUNDAY  ) startTime += 1*DAY;

   return(startTime);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen FXT-Zeitpunkt (Forex Standard Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GetFXTNextSessionEndTime(datetime fxtTime) {
   if (fxtTime < 0)
      return(_int(-1, catch("GetFXTNextSessionEndTime()  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   datetime startTime = GetFXTNextSessionStartTime(fxtTime);
   if (startTime == -1)
      return(-1);

   return(startTime + 1*DAY);
}


/**
 * Korrekter Vergleich zweier Doubles.
 *
 * MetaQuotes-Alias für EQ()
 */
bool CompareDoubles(double double1, double double2) {
   return(EQ(double1, double2));                                     // Die MetaQuotes-Funktion ist fehlerhaft.
}


/**
 * Gibt die hexadezimale Repräsentation einer Ganzzahl zurück.
 *
 * @param  int integer - Ganzzahl
 *
 * @return string - hexadezimaler Wert entsprechender Länge
 *
 * Beispiel: IntegerToHexStr(2058) => "80A"
 */
string IntegerToHexStr(int integer) {
   if (integer == 0)
      return("0");

   string hexStr, char, chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};
   int    value = integer;

   while (value != 0) {
      char   = chars[value & 0x0F];                // value % 16
      hexStr = StringConcatenate(char, hexStr);
      value >>= 4;                                 // value / 16
   }
   return(hexStr);
}


/**
 * Gibt die hexadezimale Repräsentation eines Bytes zurück.
 *
 * @param  int byte - Byte
 *
 * @return string - hexadezimaler Wert mit 2 Stellen
 *
 * Beispiel: ByteToHexStr(10) => "0A"
 */
string ByteToHexStr(int byte) {
   string hexStr, char, chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};
   int    value = byte;

   for (int i=0; i < 2; i++) {
      char   = chars[value & 0x0F];                // value % 16
      hexStr = StringConcatenate(char, hexStr);
      value >>= 4;                                 // value / 16
   }
   return(hexStr);
}


/**
 * Alias
 */
string CharToHexStr(int char) {
   return(ByteToHexStr(char));
}


/**
 * Gibt die hexadezimale Repräsentation eines Words zurück.
 *
 * @param  int word - Word (2 Byte)
 *
 * @return string - hexadezimaler Wert mit 4 Stellen
 *
 * Beispiel: WordToHexStr(2595) => "0A23"
 */
string WordToHexStr(int word) {
   string hexStr, char, chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};
   int    value = word;

   for (int i=0; i < 4; i++) {
      char   = chars[value & 0x0F];                // value % 16
      hexStr = StringConcatenate(char, hexStr);
      value >>= 4;                                 // value / 16
   }
   return(hexStr);
}


/**
 * Gibt die hexadezimale Repräsentation eines Dwords zurück.
 *
 * @param  int dword - Dword (4 Byte, entspricht einem MQL-Integer)
 *
 * @return string - hexadezimaler Wert mit 8 Stellen
 *
 * Beispiel: DwordToHexStr(13465610) => "00CD780A"
 */
string DwordToHexStr(int dword) {
   string hexStr, char, chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};
   int    value = dword;

   for (int i=0; i < 8; i++) {
      char   = chars[value & 0x0F];                // value % 16
      hexStr = StringConcatenate(char, hexStr);
      value >>= 4;                                 // value / 16
   }
   return(hexStr);
}


/**
 * Alias
 */
string IntToHexStr(int integer) {
   return(DwordToHexStr(integer));
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
   return(_ZERO(catch("DecreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Konvertiert einen Double in einen String und entfernt abschließende Nullstellen.
 *
 * @param  double value
 *
 * @return string
 */
string DoubleToStrTrim(double value) {
   string result = value;

   int digits = Max(1, CountDecimals(value));                        // mindestens eine Dezimalstelle wird erhalten

   if (digits < 8)
      result = StringLeft(result, digits-8);

   return(result);
}


/**
 * Konvertiert die angegebene FXT-Zeit (Forex Standard Time) nach GMT.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime FXTToGMT(datetime fxtTime) {
   if (fxtTime < 0)
      return(_int(-1, catch("FXTToGMT(1)  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int offset = GetFXTToGMTOffset(fxtTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime result = fxtTime - offset;
   if (result < 0)
      return(_int(-1, catch("FXTToGMT(2)   illegal datetime result: "+ result +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   return(result);
}


/**
 * Konvertiert die angegebene FXT-Zeit (Forex Standard Time) nach Tradeserver-Zeit.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime FXTToServerTime(datetime fxtTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (fxtTime < 0)
      return(_int(-1, catch("FXTToServerTime(1)  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int offset = GetFXTToServerTimeOffset(fxtTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime result = fxtTime - offset;
   if (result < 0)
      return(_int(-1, catch("FXTToServerTime(2)   illegal datetime result: "+ result +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   return(result);
}


/**
 * Prüft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt.
 *
 * @param  int results[] - Array, das die IDs der Timeframes aufnimmt, in denen das Event aufgetreten ist (mehrere sind möglich)
 * @param  int flags     - Flags ein oder mehrerer zu prüfender Timeframes (default: aktuelle Chartperiode)
 *
 * @return bool - ob mindestens ein BarOpen-Event erkannt wurde
 */
bool EventListener.BarOpen(int results[], int flags=NULL) {
   if (ArraySize(results) != 0)
      ArrayResize(results, 0);

   int currentPeriodFlag = PeriodFlag(Period());
   if (flags == NULL)
      flags = currentPeriodFlag;

   static int lastTick;

   // Die aktuelle Periode kann einfach und schnell geprüft werden.
   if (flags & currentPeriodFlag != 0) {
      static int  lastOpenTime;
      static bool lastResult;

      if (lastOpenTime != 0) {
         if (Tick == lastTick) {
            if (lastResult)                                          // wiederholter Aufruf während desselben Ticks
               ArrayPushInt(results, Period());
         }
         else if (Time[0] != lastOpenTime) {                         // neuer Tick
            ArrayPushInt(results, Period());
            lastResult = true;
         }
         else {
            lastResult = false;
         }
      }
      lastOpenTime = Time[0];
      lastTick     = Tick;
   }

   // Prüfungen für andere als die aktuelle Chartperiode
   else {
      static int lastMinute = 0;

      datetime tick = MarketInfo(Symbol(), MODE_TIME);               // nur Sekundenauflösung
      int minute;

      // PERIODFLAG_M1
      if (flags & F_PERIOD_M1 != 0) {
         if (lastTick == 0) {
            lastTick   = tick;
            lastMinute = TimeMinute(tick);
            //debug("EventListener.BarOpen(M1)   initialisiert   lastTick: '", TimeToStr(lastTick, TIME_FULL), "' (", lastMinute, ")");
         }
         else if (lastTick != tick) {
            minute = TimeMinute(tick);
            if (lastMinute < minute)
               ArrayPushInt(results, F_PERIOD_M1);
            //debug("EventListener.BarOpen(M1)   prüfe   alt: '", TimeToStr(lastTick, TIME_FULL), "' (", lastMinute, ")   neu: '", TimeToStr(tick, TIME_FULL), "' (", minute, ")");
            lastTick   = tick;
            lastMinute = minute;
         }
         //else debug("EventListener.BarOpen(M1)   zwei Ticks in derselben Sekunde");
      }
   }

   // TODO: verbleibende Timeframe-Flags verarbeiten
   /*
   if (flags & F_PERIOD_M5  != 0) ArrayPushInt(results, F_PERIOD_M5 );
   if (flags & F_PERIOD_M15 != 0) ArrayPushInt(results, F_PERIOD_M15);
   if (flags & F_PERIOD_M30 != 0) ArrayPushInt(results, F_PERIOD_M30);
   if (flags & F_PERIOD_H1  != 0) ArrayPushInt(results, F_PERIOD_H1 );
   if (flags & F_PERIOD_H4  != 0) ArrayPushInt(results, F_PERIOD_H4 );
   if (flags & F_PERIOD_D1  != 0) ArrayPushInt(results, F_PERIOD_D1 );
   if (flags & F_PERIOD_W1  != 0) ArrayPushInt(results, F_PERIOD_W1 );
   if (flags & F_PERIOD_MN1 != 0) ArrayPushInt(results, F_PERIOD_MN1);
   */

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("EventListener.BarOpen()", error)));
   return(ArraySize(results) != 0);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountChange-Event aufgetreten ist.
 *
 * @param  int results[] - eventspezifische Detailinfos {last_account, current_account, current_account_login}
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 *
 *  NOTE:
 *  -----
 *  Während des Terminal-Starts und bei Accountwechseln kann AccountNumber() kurzzeitig 0 zurückgeben.
 *  Diese start()-Aufrufe des noch nicht vollständig initialisierten Acconts werden nicht als Accountwechsel im Sinne dieses Listeners interpretiert.
 */
bool EventListener.AccountChange(int results[], int flags=NULL) {
   static int accountData[3];                         // {last_account, current_account, current_account_login}

   bool eventStatus = false;
   int  account = AccountNumber();

   if (account != 0) {                                // AccountNumber() == 0 ignorieren
      if (accountData[1] == 0) {                      // 1. Lib-Aufruf
         accountData[0] = 0;
         accountData[1] = account;
         accountData[2] = GMTToServerTime(TimeGMT());
         //debug("EventListener.AccountChange()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_FULL));
      }
      else if (accountData[1] != account) {           // Aufruf nach Accountwechsel zur Laufzeit
         accountData[0] = accountData[1];
         accountData[1] = account;
         accountData[2] = GMTToServerTime(TimeGMT());
         //debug("EventListener.AccountChange()   Account "+ account +" nach Accountwechsel initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_FULL));
         eventStatus = true;
      }
   }
   //debug("EventListener.AccountChange()   eventStatus: "+ eventStatus);

   if (ArraySize(results) != 3)
      ArrayResize(results, 3);
   ArrayCopy(results, accountData);

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("EventListener.AccountChange()", error)));

   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountPayment-Event aufgetreten ist.
 *
 * @param  int results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.AccountPayment(int results[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderPlace-Event aufgetreten ist.
 *
 * @param  int results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderPlace(int results[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderChange-Event aufgetreten ist.
 *
 * @param  int results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderChange(int results[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderCancel-Event aufgetreten ist.
 *
 * @param  int results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderCancel(int results[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionOpen-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int tickets[] - Zielarray für Ticketnummern neu geöffneter Positionen
 * @param  int flags     - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                         (default: keine)
 * @return bool - Ergebnis
 */
bool EventListener.PositionOpen(int& tickets[], int flags=NULL) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(tickets) > 0)
      ArrayResize(tickets, 0);

   static int      accountNumber  [1];
   static datetime accountInitTime[1];                                                    // GMT-Zeit
   static int      knownPendings  [][2];                                                  // die bekannten pending Orders und ihr Typ
   static int      knownPositions [];                                                     // die bekannten Positionen

   if (accountNumber[0] == 0) {                                                           // 1. Aufruf
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      //debug("EventListener.PositionOpen()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, GMT-Zeit: '"+ TimeToStr(accountInitTime[0], TIME_FULL) +"'");
   }
   else if (accountNumber[0] != account) {                                                // Aufruf nach Accountwechsel zur Laufzeit: bekannte Positionen löschen
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      ArrayResize(knownPendings, 0);
      ArrayResize(knownPositions, 0);
      //debug("EventListener.PositionOpen()   Account "+ account +" nach Accountwechsel initialisiert, GMT-Zeit: '"+ TimeToStr(accountInitTime[0], TIME_FULL) +"'");
   }

   OrderPush("EventListener.PositionOpen(1)");
   int orders = OrdersTotal();

   // pending Orders und offene Positionen überprüfen
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))                                    // FALSE: während des Auslesens wurde in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      int n, pendings, positions, type=OrderType(), ticket=OrderTicket();

      // pending Orders überprüfen und ggf. aktualisieren
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP) {
         pendings = ArrayRange(knownPendings, 0);
         for (n=0; n < pendings; n++)
            if (knownPendings[n][0] == ticket)                                            // bekannte pending Order
               break;
         if (n < pendings)
            continue;

         ArrayResize(knownPendings, pendings+1);                                          // neue (unbekannte) pending Order
         knownPendings[pendings][0] = ticket;
         knownPendings[pendings][1] = type;
         //debug("EventListener.PositionOpen()   pending order #", ticket, " added: ", OperationTypeDescription(type));
      }

      // offene Positionen überprüfen und ggf. aktualisieren
      else if (type==OP_BUY || type==OP_SELL) {
         positions = ArraySize(knownPositions);
         for (n=0; n < positions; n++)
            if (knownPositions[n] == ticket)                                              // bekannte Position
               break;
         if (n < positions)
            continue;

         // Die offenen Positionen stehen u.U. (z.B. nach Accountwechsel) erst nach einigen Ticks zur Verfügung. Daher müssen
         // neue Positionen zusätzlich anhand ihres OrderOpen-Timestamps auf ihren jeweiligen Status überprüft werden.

         // neue (unbekannte) Position: prüfen, ob sie nach Accountinitialisierung geöffnet wurde (= wirklich neu ist)
         if (accountInitTime[0] <= ServerToGMT(OrderOpenTime())) {
            // ja, in flags angegebene Orderkriterien prüfen
            int event = 1;
            pendings = ArrayRange(knownPendings, 0);

            if (flags & OFLAG_CURRENTSYMBOL != 0)   event &= (OrderSymbol()==Symbol())+0; // MQL kann Booleans für Binärops. nicht casten
            if (flags & OFLAG_BUY           != 0)   event &= (type==OP_BUY )+0;
            if (flags & OFLAG_SELL          != 0)   event &= (type==OP_SELL)+0;
            if (flags & OFLAG_MARKETORDER   != 0) {
               for (int z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                      // Order war pending
                     break;                         event &= (z==pendings)+0;
            }
            if (flags & OFLAG_PENDINGORDER  != 0) {
               for (z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                      // Order war pending
                     break;                         event &= (z<pendings)+0;
            }

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1) {
               ArrayResize(tickets, ArraySize(tickets)+1);
               tickets[ArraySize(tickets)-1] = ticket;
            }
         }

         ArrayResize(knownPositions, positions+1);
         knownPositions[positions] = ticket;
         //debug("EventListener.PositionOpen()   position #", ticket, " added: ", OperationTypeDescription(type));
      }
   }

   bool eventStatus = (ArraySize(tickets) > 0);
   //debug("EventListener.PositionOpen()   eventStatus: "+ eventStatus);

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("EventListener.PositionOpen(2)", error, O_POP)));

   return(eventStatus && OrderPop("EventListener.PositionOpen(3)"));
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionClose-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int tickets[] - Zielarray für Ticket-Nummern geschlossener Positionen
 * @param  int flags     - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                         (default: keine)
 * @return bool - Ergebnis
 */
bool EventListener.PositionClose(int tickets[], int flags=NULL) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   OrderPush("EventListener.PositionClose(1)");

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(tickets) > 0)
      ArrayResize(tickets, 0);

   static int accountNumber[1];
   static int knownPositions[];                                         // bekannte Positionen
          int noOfKnownPositions = ArraySize(knownPositions);

   if (accountNumber[0] == 0) {
      accountNumber[0] = account;
      //debug("EventListener.PositionClose()   Account "+ account +" nach 1. Lib-Aufruf initialisiert");
   }
   else if (accountNumber[0] != account) {
      accountNumber[0] = account;
      ArrayResize(knownPositions, 0);
      //debug("EventListener.PositionClose()   Account "+ account +" nach Accountwechsel initialisiert");
   }
   else {
      // alle beim letzten Aufruf offenen Positionen prüfen             // TODO: bei offenen Orders und dem ersten Login in einen anderen Account crasht alles
      for (int i=0; i < noOfKnownPositions; i++) {
         if (!OrderSelectByTicket(knownPositions[i], "EventListener.PositionClose(2)", NULL, O_POP))
            return(false);

         if (OrderCloseTime() > 0) {                                    // Position geschlossen, in flags angegebene Orderkriterien prüfen
            int    event=1, type=OrderType();
            bool   pending;
            string comment = StringToLower(StringTrim(OrderComment()));

            if      (StringStartsWith(comment, "so:" )) pending = true; // Margin Stopout, wie pending behandeln
            else if (StringEndsWith  (comment, "[tp]")) pending = true;
            else if (StringEndsWith  (comment, "[sl]")) pending = true;
            else if (OrderTakeProfit() > 0) {
               if      (type == OP_BUY )                pending = (OrderClosePrice() >= OrderTakeProfit());
               else if (type == OP_SELL)                pending = (OrderClosePrice() <= OrderTakeProfit());
            }

            if (flags & OFLAG_CURRENTSYMBOL != 0) event &= (OrderSymbol()==Symbol()) +0;  // MQL kann Booleans für Binäroperationen nicht casten
            if (flags & OFLAG_BUY           != 0) event &= (type==OP_BUY )           +0;
            if (flags & OFLAG_SELL          != 0) event &= (type==OP_SELL)           +0;
            if (flags & OFLAG_MARKETORDER   != 0) event &= (!pending)                +0;
            if (flags & OFLAG_PENDINGORDER  != 0) event &= ( pending)                +0;

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1)
               ArrayPushInt(tickets, knownPositions[i]);
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
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE: während des Auslesens wurde in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         noOfKnownPositions++;
         ArrayResize(knownPositions, noOfKnownPositions);
         knownPositions[noOfKnownPositions-1] = OrderTicket();
         //debug("EventListener.PositionClose()   open position #", ticket, " added: ", OperationTypeDescription(OrderType()));
      }
   }

   bool eventStatus = (ArraySize(tickets) > 0);
   //debug("EventListener.PositionClose()   eventStatus: "+ eventStatus);

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("EventListener.PositionClose(3)", error, O_POP)));

   return(eventStatus && OrderPop("EventListener.PositionClose(4)"));
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand-Event aufgetreten ist.
 *
 * @param  string commands[] - Array zur Aufnahme der aufgetretenen Kommandos
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string commands[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein InternalCommand-Event aufgetreten ist.
 *
 * @param  string commands[] - Array zur Aufnahme der aufgetretenen Kommandos
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.InternalCommand(string commands[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ExternalCommand-Event aufgetreten ist.
 *
 * @param  string commands[] - Array zur Aufnahme der aufgetretenen Kommandos
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ExternalCommand(string commands[], int flags=NULL) {
   // TODO: implementieren
   return(false);
}


/**
 * Zerlegt einen String in Teilstrings.
 *
 * @param  string object    - zu zerlegender String
 * @param  string separator - Trennstring
 * @param  string results[] - Zielarray für die Teilstrings
 * @param  int    limit     - maximale Anzahl von Teilstrings (default: kein Limit)
 *
 * @return int - Anzahl der Teilstrings oder -1, wennn ein Fehler auftrat
 */
int Explode(string object, string separator, string& results[], int limit=NULL) {
   // Der Parameter object *könnte* ein Element des Ergebnisarrays results[] sein, daher erstellen wir
   // vor Modifikation von results[] eine Kopie von object und verwenden diese.
   string _object = StringConcatenate(object, "");

   int lenObject    = StringLen(_object),
       lenSeparator = StringLen(separator);

   if (lenObject == 0) {                     // Leerstring
      ArrayResize(results, 1);
      results[0] = _object;
   }
   else if (StringLen(separator) == 0) {     // NUL-Separator: String in einzelne Zeichen zerlegen
      if (limit==NULL || limit > lenObject)
         limit = lenObject;
      ArrayResize(results, limit);

      for (int i=0; i < limit; i++) {
         results[i] = StringSubstr(_object, i, 1);
      }
   }
   else {                                    // String in Substrings zerlegen
      int size, pos;
      i = 0;

      while (i < lenObject) {
         ArrayResize(results, size+1);

         pos = StringFind(_object, separator, i);
         if (limit == size+1)
            pos = -1;
         if (pos == -1) {
            results[size] = StringSubstr(_object, i);
            break;
         }
         else if (pos == i) {
            results[size] = "";
         }
         else {
            results[size] = StringSubstrFix(_object, i, pos-i);
         }
         size++;
         i = pos + lenSeparator;
      }

      if (i == lenObject) {                  // bei abschließendem Separator Substrings mit Leerstring beenden
         ArrayResize(results, size+1);
         results[size] = "";                 // TODO: !!! Wechselwirkung zwischen Limit und Separator am Ende überprüfen
      }
   }

   int error = GetLastError();
   if (IsError(error))
      return(_int(-1, catch("Explode()", error)));

   return(ArraySize(results));
}


/**
 * Liest die History eines Accounts aus dem Dateisystem in das angegebene Array ein (Daten werden als Strings gespeichert).
 *
 * @param  int    account                    - Account-Nummer
 * @param  string results[][HISTORY_COLUMNS] - Zeiger auf Ergebnisarray
 *
 * @return int - Fehlerstatus
 */
int GetAccountHistory(int account, string results[][HISTORY_COLUMNS]) {
   if (ArrayRange(results, 1) != HISTORY_COLUMNS)
      return(catch("GetAccountHistory(1)   invalid parameter results["+ ArrayRange(results, 0) +"]["+ ArrayRange(results, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   static int    static.account[1];
   static string static.results[][HISTORY_COLUMNS];

   ArrayResize(results, 0);

   // nach Möglichkeit die gecachten Daten liefern
   if (account == static.account[0]) {
      ArrayCopy(results, static.results);
      if (__LOG) log("GetAccountHistory()   delivering "+ ArrayRange(results, 0) +" history entries for account "+ account +" from cache");
      return(catch("GetAccountHistory(2)"));
   }

   // Cache-Miss, History-Datei auslesen
   string header[HISTORY_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment" };

   string filename = ShortAccountCompany() +"/"+ account + "_account_history.csv";
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (hFile < 0) {
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE)
         return(error);
      return(catch("GetAccountHistory(3) ->FileOpen(\""+ filename +"\")", error));
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

   if (IsError(error))        // ret
      return(error);


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) > 0) {       // "leere" Historydaten nicht cachen (falls Datei noch erstellt wird)
      //if (__LOG) log("GetAccountHistory()   caching "+ ArrayRange(result, 0) +" history entries for account "+ account);
      static.account[0] = account;
      ArrayResize(static.results, 0);
      ArrayCopy  (static.results, result);
      ArrayResize(result, 0);

      ArrayCopy(results, static.results);
   }

   ArrayResize(header, 0);
   return(catch("GetAccountHistory(7)"));
}


/**
 * Gibt unabhängig von einer Tradeserver-Verbindung die Nummer des aktuellen Accounts zurück.
 *
 * @return int - Account-Nummer oder 0, falls ein Fehler auftrat
 */
int GetAccountNumber() /*throws ERR_TERMINAL_NOT_YET_READY*/ {       // evt. während des Terminal-Starts
   static int static.result;
   if (static.result != 0)
      return(static.result);

   int account = AccountNumber();

   if (account == 0x4000) {                                          // beim Test ohne Tradeserver-Verbindung
      if (!IsTesting())
         return(_ZERO(catch("GetAccountNumber(1) ->AccountNumber() got illegal account number "+ account +" (0x"+ IntToHexStr(account) +")", ERR_RUNTIME_ERROR)));
      account = 0;
   }

   if (account == 0) {
      string title = GetWindowText(GetApplicationMainWindow());      // Titelzeile des Hauptfensters auswerten:
      if (StringLen(title) == 0)                                     // benutzt SendMessage(), nicht nach Stop bei VisualMode=true benutzen => UI-Thread-Deadlock
         return(_ZERO(SetLastError(ERR_TERMINAL_NOT_YET_READY)));

      int pos = StringFind(title, ":");
      if (pos < 1)
         return(_ZERO(catch("GetAccountNumber(2)   account number separator not found in top window title \""+ title +"\"", ERR_RUNTIME_ERROR)));

      string strValue = StringLeft(title, pos);
      if (!StringIsDigit(strValue))
         return(_ZERO(catch("GetAccountNumber(3)   account number in top window title contains non-digit characters \""+ title +"\"", ERR_RUNTIME_ERROR)));

      account = StrToInteger(strValue);
   }

   if (IsError(catch("GetAccountNumber(4)")))
      return(0);

   // Im Tester kann die Accountnummer gecacht werden und verhindert dadurch Deadlock-Probleme bei Verwendung von SendMessage() in _DEINIT_.
   if (This.IsTesting())
      static.result = account;

   return(account);                                                  // nicht die statische Variable zurückgeben (kann 0 sein)
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Ergebnisarrays (aufsteigend nach Zeitpunkt sortiert).
 *
 * @param  int      account  - Account-Nummer
 * @param  datetime times[]  - Zeiger auf Ergebnisarray für die Zeitpunkte der Balanceänderung
 * @param  double   values[] - Zeiger auf Ergebnisarray der entsprechenden Balancewerte
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime& times[], double& values[]) {
   static int      static.account[1];
   static datetime static.times [];
   static double   static.values[];

   ArrayResize(times,  0);
   ArrayResize(values, 0);

   // Daten nach Möglichkeit aus dem Cache liefern       TODO: paralleles Cachen mehrerer Wertereihen ermöglichen
   if (account == static.account[0]) {
      /**
       * TODO: Fehler tritt nach Neustart auf, wenn Balance-Indikator geladen ist und AccountNumber() noch 0 zurückgibt
       *
       * stdlib: Error: incorrect start position 0 for ArrayCopy function
       * stdlib: Log:   Balance::stdlib::GetBalanceHistory()   delivering 0 balance values for account 0 from cache
       * stdlib: Alert: ERROR:   AUDUSD,M15::Balance::stdlib::GetBalanceHistory(1)  [4051 - invalid function parameter value]
       */
      ArrayCopy(times,  static.times);
      ArrayCopy(values, static.values);
      if (__LOG) log("GetBalanceHistory()   delivering "+ ArraySize(times) +" balance values for account "+ account +" from cache");
      return(catch("GetBalanceHistory(1)"));
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (IsError(error)) {
      if (error == ERR_CANNOT_OPEN_FILE) return(catch("GetBalanceHistory(2)", error));
                                         return(catch("GetBalanceHistory(3)"));
   }

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
         ArrayResize(times,  n+1);
         ArrayResize(values, n+1);
         times [n] = time;
         values[n] = balance;
         n++;                                // n: Anzahl der existierenden Ergebnisdaten => ArraySize(lpTimes)
      }
      else if (balance != lastBalance) {
         // ... alle weiteren nur, wenn die Balance sich geändert hat
         if (time == lastTime) {             // Existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            values[n-1] = balance;           // wird der letzte Wert nur mit dem aktuellen überschrieben.
         }
         else {
            ArrayResize(times,  n+1);
            ArrayResize(values, n+1);
            times [n] = time;
            values[n] = balance;
            n++;
         }
      }
      lastTime    = time;
      lastBalance = balance;
   }

   // Daten cachen
   static.account[0] = account;
   ArrayResize(static.times,  0); ArrayCopy(static.times,  times );
   ArrayResize(static.values, 0); ArrayCopy(static.values, values);
   if (__LOG) log("GetBalanceHistory()   caching "+ ArraySize(times) +" balance values for account "+ account);

   ArrayResize(data, 0);
   return(catch("GetBalanceHistory(5)"));
}


/**
 * Gibt den Rechnernamen des laufenden Systems zurück.
 *
 * @return string - Name oder Leerstring, falls ein Fehler auftrat
 */
string GetComputerName() {
   static string static.result[1];
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);
   int    lpBufferSize[1]; lpBufferSize[0] = bufferSize;

   if (!GetComputerNameA(buffer[0], lpBufferSize))
      return(_empty(catch("GetComputerName() ->kernel32::GetComputerNameA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   static.result[0] = buffer[0];
   return(static.result[0]);
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

   int bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   // zuerst globale, dann lokale Config auslesen                             // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, strDefault, buffer[0], bufferSize, GetGlobalConfigPath());
   GetPrivateProfileStringA(section, key, buffer[0],  buffer[0], bufferSize, GetLocalConfigPath());

   buffer[0] = StringToLower(buffer[0]);

   bool result;
   if      (buffer[0] == ""    ) result = defaultValue;
   else if (buffer[0] == "1"   ) result = true;
   else if (buffer[0] == "true") result = true;
   else if (buffer[0] == "yes" ) result = true;
   else if (buffer[0] == "on"  ) result = true;

   if (IsError(catch("GetConfigBool()")))
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
   int bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   // zuerst globale, dann lokale Config auslesen                             // zu kleiner Buffer ist hier nicht möglich
   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], bufferSize, GetGlobalConfigPath());
   GetPrivateProfileStringA(section, key, buffer[0],                    buffer[0], bufferSize, GetLocalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (IsError(catch("GetConfigDouble()")))
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
       result = GetPrivateProfileIntA(section, key, result,       GetLocalConfigPath());

   if (IsError(catch("GetConfigInt()")))
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
 * Ob der angegebene Schlüssel in der lokalen Konfigurationsdatei existiert oder nicht.
 *
 * @param  string section - Name des Konfigurationsabschnittes
 * @param  string key     - Schlüssel
 *
 * @return bool
 */
bool IsLocalConfigKey(string section, string key) {
   string keys[];
   GetPrivateProfileKeys(GetLocalConfigPath(), section, keys);

   bool result;
   int size = ArraySize(keys);

   if (size != 0) {
      key = StringToLower(key);

      for (int i=0; i < size; i++) {
         if (key == StringToLower(keys[i])) {
            result = true;
            break;
         }
      }
   }

   if (ArraySize(keys) > 0)
      ArrayResize(keys, 0);
   return(result);
}


/**
 * Ob der angegebene Schlüssel in der globalen Konfigurationsdatei existiert oder nicht.
 *
 * @param  string section - Name des Konfigurationsabschnittes
 * @param  string key     - Schlüssel
 *
 * @return bool
 */
bool IsGlobalConfigKey(string section, string key) {
   string keys[];
   GetPrivateProfileKeys(GetGlobalConfigPath(), section, keys);

   bool result;
   int size = ArraySize(keys);

   if (size != 0) {
      key = StringToLower(key);

      for (int i=0; i < size; i++) {
         if (key == StringToLower(keys[i])) {
            result = true;
            break;
         }
      }
   }

   if (ArraySize(keys) > 0)
      ArrayResize(keys, 0);
   return(result);
}


/**
 * Ob der angegebene Schlüssel in der globalen oder lokalen Konfigurationsdatei existiert oder nicht.
 *
 * @param  string section - Name des Konfigurationsabschnittes
 * @param  string key     - Schlüssel
 *
 * @return bool
 */
bool IsConfigKey(string section, string key) {
   if (IsGlobalConfigKey(section, key))
      return(true);
   return(IsLocalConfigKey(section, key));
}


/**
 * Gibt den Offset der angegebenen FXT-Zeit (Forex Standard Time) zu GMT zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetFXTToGMTOffset(datetime fxtTime) {
   if (fxtTime < 0) {
      catch("GetFXTToGMTOffset()  invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(fxtTime)-1970;

   // FXT                                           GMT+0200,GMT+0300
   if      (fxtTime < FXT_transitions[year][0]) offset = 2 * HOURS;
   else if (fxtTime < FXT_transitions[year][1]) offset = 3 * HOURS;
   else                                         offset = 2 * HOURS;

   return(offset);
}


/**
 * Gibt den Offset der angegebenen FXT-Zeit (Forex Standard Time) zu Tradeserver-Zeit zurück.
 *
 * @param  datetime fxtTime - FXT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetFXTToServerTimeOffset(datetime fxtTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (fxtTime < 0) {
      catch("GetFXTToServerTimeOffset(1)   invalid parameter fxtTime: "+ fxtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // Offset FXT zu GMT
   int offset1 = GetFXTToGMTOffset(fxtTime);
   if (offset1 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   // Offset GMT zu Tradeserver
   int offset2 = GetGMTToServerTimeOffset(fxtTime - offset1);
   if (offset2 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   return(offset1 + offset2);
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

   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   GetPrivateProfileStringA(section, key, strDefault, buffer[0], bufferSize, GetGlobalConfigPath());

   buffer[0] = StringToLower(buffer[0]);

   bool result;
   if      (buffer[0] == ""    ) result = defaultValue;
   else if (buffer[0] == "1"   ) result = true;
   else if (buffer[0] == "true") result = true;
   else if (buffer[0] == "yes" ) result = true;
   else if (buffer[0] == "on"  ) result = true;

   if (IsError(catch("GetGlobalConfigBool()")))
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
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], bufferSize, GetGlobalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (IsError(catch("GetGlobalConfigDouble()")))
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

   if (IsError(catch("GetGlobalConfigInt()")))
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
 * Gibt den Offset der angegebenen GMT-Zeit zur Tradeserver-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 *
 *
 *  NOTE:
 *  -----
 *  Das Ergebnis ist der entgegengesetzte Wert des Offsets von Tradeserver-Zeit zu GMT.
 */
int GetGMTToServerTimeOffset(datetime gmtTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (gmtTime < 0) {
      catch("GetGMTToServerTimeOffset(1)   invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string timezone = GetServerTimezone();
   if (StringLen(timezone) == 0)
      return(EMPTY_VALUE);

   if (timezone == "Alpari") {
      if (gmtTime < D'2012.04.01 00:00:00') timezone = "Europe/Berlin";
      else                                  timezone = "Europe/Kiev";
   }

   int offset, year = TimeYear(gmtTime)-1970;

   if (timezone == "Europe/Minsk") {             // GMT+0200,GMT+0300
      if      (gmtTime < EMST_transitions[year][2]) offset = -2 * HOURS;
      else if (gmtTime < EMST_transitions[year][3]) offset = -3 * HOURS;
      else                                          offset = -2 * HOURS;
   }

   else if (timezone == "Europe/Kiev") {         // GMT+0200,GMT+0300
      if      (gmtTime < EEST_transitions[year][2]) offset = -2 * HOURS;
      else if (gmtTime < EEST_transitions[year][3]) offset = -3 * HOURS;
      else                                          offset = -2 * HOURS;
   }

   else if (timezone == "FXT") {                 // GMT+0200,GMT+0300
      if      (gmtTime < FXT_transitions[year][2])  offset = -2 * HOURS;
      else if (gmtTime < FXT_transitions[year][3])  offset = -3 * HOURS;
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
      catch("GetGMTToServerTimeOffset(2)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG);
      return(EMPTY_VALUE);
   }

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
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-1) {
      bufferSize <<= 1;
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);
   }

   if (IsError(catch("GetPrivateProfileString()")))
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

   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   GetPrivateProfileStringA(section, key, strDefault, buffer[0], bufferSize, GetLocalConfigPath());

   buffer[0] = StringToLower(buffer[0]);

   bool result;
   if      (buffer[0] == ""    ) result = defaultValue;
   else if (buffer[0] == "1"   ) result = true;
   else if (buffer[0] == "true") result = true;
   else if (buffer[0] == "yes" ) result = true;
   else if (buffer[0] == "on"  ) result = true;

   if (IsError(catch("GetLocalConfigBool()")))
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
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], bufferSize, GetLocalConfigPath());

   double result = StrToDouble(buffer[0]);

   if (IsError(catch("GetLocalConfigDouble()")))
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

   if (IsError(catch("GetLocalConfigInt()")))
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
   if (time < 0)
      return(_empty(catch("GetDayOfWeek(1)  invalid parameter time: "+ time +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

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
      case ERR_COMMON_ERROR               : return("trade denied"                                                  ); //    2
      case ERR_INVALID_TRADE_PARAMETERS   : return("invalid trade parameters"                                      ); //    3
      case ERR_SERVER_BUSY                : return("trade server is busy"                                          ); //    4
      case ERR_OLD_VERSION                : return("old version of client terminal"                                ); //    5
      case ERR_NO_CONNECTION              : return("no connection to trade server"                                 ); //    6
      case ERR_NOT_ENOUGH_RIGHTS          : return("not enough rights"                                             ); //    7
      case ERR_TOO_FREQUENT_REQUESTS      : return("too frequent requests"                                         ); //    8
      case ERR_MALFUNCTIONAL_TRADE        : return("malfunctional trade operation"                                 ); //    9
      case ERR_ACCOUNT_DISABLED           : return("account disabled"                                              ); //   64
      case ERR_INVALID_ACCOUNT            : return("invalid account"                                               ); //   65
      case ERR_TRADE_TIMEOUT              : return("trade timeout"                                                 ); //  128
      case ERR_INVALID_PRICE              : return("invalid price"                                                 ); //  129 Kurs bewegt sich zu schnell (aus dem Fenster)
      case ERR_INVALID_STOPS              : return("invalid stop"                                                  ); //  130
      case ERR_INVALID_TRADE_VOLUME       : return("invalid trade volume"                                          ); //  131
      case ERR_MARKET_CLOSED              : return("market is closed"                                              ); //  132
      case ERR_TRADE_DISABLED             : return("trading is disabled"                                           ); //  133
      case ERR_NOT_ENOUGH_MONEY           : return("not enough money"                                              ); //  134
      case ERR_PRICE_CHANGED              : return("price changed"                                                 ); //  135
      case ERR_OFF_QUOTES                 : return("off quotes"                                                    ); //  136
      case ERR_BROKER_BUSY                : return("broker is busy"                                                ); //  137
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
      case ERR_RUNTIME_ERROR              : return("runtime error"                                                 ); // 4000 common runtime error (no mql error)
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
      case ERR_WRONG_JUMP                 : return("wrong jump"                                                    ); // 4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("array not initialized"                                         ); // 4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("DLL function calls not allowed"                                ); // 4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("cannot load library"                                           ); // 4018
      case ERR_CANNOT_CALL_FUNCTION       : return("cannot call function"                                          ); // 4019
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("ex4 library function calls not allowed"                        ); // 4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("not enough memory for temp string returned from function"      ); // 4021
      case ERR_SYSTEM_BUSY                : return("system busy"                                                   ); // 4022
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("invalid function parameter count"                              ); // 4050 invalid parameters count
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("invalid function parameter value"                              ); // 4051 invalid parameter value
      case ERR_STRING_FUNCTION_INTERNAL   : return("string function internal error"                                ); // 4052
      case ERR_SOME_ARRAY_ERROR           : return("array error"                                                   ); // 4053 some array error
      case ERR_INCORRECT_SERIESARRAY_USING: return("incorrect series array using"                                  ); // 4054
      case ERR_CUSTOM_INDICATOR_ERROR     : return("custom indicator error"                                        ); // 4055 custom indicator error
      case ERR_INCOMPATIBLE_ARRAYS        : return("incompatible arrays"                                           ); // 4056 incompatible arrays
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                             ); // 4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                                     ); // 4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTER : return("function not allowed in test mode"                             ); // 4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                        ); // 4060
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                               ); // 4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                                     ); // 4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                                    ); // 4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                                     ); // 4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                      ); // 4065
      case ERR_HISTORY_UPDATE             : return("requested history data in update state"                        ); // 4066 history in update state
      case ERR_TRADE_ERROR                : return("error in trading function"                                     ); // 4067 error in trading function
      case ERR_END_OF_FILE                : return("end of file"                                                   ); // 4099 end of file
      case ERR_SOME_FILE_ERROR            : return("file error"                                                    ); // 4100 some file error
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
      case ERR_WIN32_ERROR                : return("win32 api error"                                               ); // 5000
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("function not implemented"                                      ); // 5001
      case ERR_INVALID_INPUT              : return("invalid input parameter value"                                 ); // 5002
      case ERR_INVALID_CONFIG_PARAMVALUE  : return("invalid configuration parameter value"                         ); // 5003
      case ERR_TERMINAL_NOT_YET_READY     : return("terminal not yet ready"                                        ); // 5004
      case ERR_INVALID_TIMEZONE_CONFIG    : return("invalid or missing timezone configuration"                     ); // 5005
      case ERR_INVALID_MARKET_DATA        : return("invalid market data"                                           ); // 5006
      case ERR_FILE_NOT_FOUND             : return("file not found"                                                ); // 5007
      case ERR_CANCELLED_BY_USER          : return("cancelled by user"                                             ); // 5008
      case ERR_FUNC_NOT_ALLOWED           : return("function not allowed"                                          ); // 5009
      case ERR_INVALID_COMMAND            : return("invalid or unknow command"                                     ); // 5010
      case ERR_ILLEGAL_STATE              : return("illegal runtime state"                                         ); // 5011
   }
   return("unknown error");
}


/**
 * Ob der angegebene Wert ein gültiger Fehler-Code ist.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsErrorCode(int value) {
   return(ErrorDescription(value) != "unknown error");
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
      case ERR_FUNC_NOT_ALLOWED_IN_TESTER : return("ERR_FUNC_NOT_ALLOWED_IN_TESTER" ); // 4059
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
      case ERR_WIN32_ERROR                : return("ERR_WIN32_ERROR"                ); // 5000
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("ERR_FUNCTION_NOT_IMPLEMENTED"   ); // 5001
      case ERR_INVALID_INPUT              : return("ERR_INVALID_INPUT"              ); // 5002
      case ERR_INVALID_CONFIG_PARAMVALUE  : return("ERR_INVALID_CONFIG_PARAMVALUE"  ); // 5003
      case ERR_TERMINAL_NOT_YET_READY     : return("ERR_TERMINAL_NOT_YET_READY"     ); // 5004
      case ERR_INVALID_TIMEZONE_CONFIG    : return("ERR_INVALID_TIMEZONE_CONFIG"    ); // 5005
      case ERR_INVALID_MARKET_DATA        : return("ERR_INVALID_MARKET_DATA"        ); // 5006
      case ERR_FILE_NOT_FOUND             : return("ERR_FILE_NOT_FOUND"             ); // 5007
      case ERR_CANCELLED_BY_USER          : return("ERR_CANCELLED_BY_USER"          ); // 5008
      case ERR_FUNC_NOT_ALLOWED           : return("ERR_FUNC_NOT_ALLOWED"           ); // 5009
      case ERR_INVALID_COMMAND            : return("ERR_INVALID_COMMAND"            ); // 5010
      case ERR_ILLEGAL_STATE              : return("ERR_ILLEGAL_STATE"              ); // 5011
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
      case EVENT_BAR_OPEN       : return("EVENT_BAR_OPEN"       );
      case EVENT_ORDER_PLACE    : return("EVENT_ORDER_PLACE"    );
      case EVENT_ORDER_CHANGE   : return("EVENT_ORDER_CHANGE"   );
      case EVENT_ORDER_CANCEL   : return("EVENT_ORDER_CANCEL"   );
      case EVENT_POSITION_OPEN  : return("EVENT_POSITION_OPEN"  );
      case EVENT_POSITION_CLOSE : return("EVENT_POSITION_CLOSE" );
      case EVENT_ACCOUNT_CHANGE : return("EVENT_ACCOUNT_CHANGE" );
      case EVENT_ACCOUNT_PAYMENT: return("EVENT_ACCOUNT_PAYMENT");
   }
   return(_empty(catch("EventToStr()   unknown event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt den Offset der angegebenen lokalen Zeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetLocalToGMTOffset() {
   /*TIME_ZONE_INFORMATION*/int tzi[]; InitializeBuffer(tzi, TIME_ZONE_INFORMATION.size);
   int type = GetTimeZoneInformation(tzi);

   int offset = 0;

   if (type != TIME_ZONE_ID_UNKNOWN) {
      offset = tzi.Bias(tzi);
      if (type == TIME_ZONE_ID_DAYLIGHT)
         offset += tzi.DaylightBias(tzi);
      offset *= -60;
   }

   if (IsError(catch("GetLocalToGMTOffset()")))
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
string MovingAverageMethodToStr(int method) {
   switch (method) {
      case MODE_SMA : return("MODE_SMA" );
      case MODE_EMA : return("MODE_EMA" );
      case MODE_SMMA: return("MODE_SMMA");
      case MODE_LWMA: return("MODE_LWMA");
      case MODE_ALMA: return("MODE_ALMA");
   }
   return(_empty(catch("MovingAverageMethodToStr()  invalid paramter method = "+ method, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die lesbare Beschreibung einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MovingAverageMethodDescription(int method) {
   switch (method) {
      case MODE_SMA : return("SMA" );
      case MODE_EMA : return("EMA" );
      case MODE_SMMA: return("SMMA");
      case MODE_LWMA: return("LWMA");
      case MODE_ALMA: return("ALMA");
   }
   return(_empty(catch("MovingAverageMethodDescription()  invalid paramter method = "+ method, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die numerische Konstante einer MovingAverage-Methode zurück.
 *
 * @param  string method - MA-Methode: [MODE_][SMA|EMA|SMMA|LWMA|ALMA]
 *
 * @return int - MA-Konstante oder -1, wenn der Methodenbezeichner unbekannt ist
 */
int MovingAverageMethodToId(string method) {
   string value = StringToUpper(method);

   if (StringStartsWith(value, "MODE_"))
      value = StringRight(value, -5);

   if (value == "SMA" ) return(MODE_SMA );
   if (value == "EMA" ) return(MODE_EMA );
   if (value == "SMMA") return(MODE_SMMA);
   if (value == "LWMA") return(MODE_LWMA);
   if (value == "ALMA") return(MODE_ALMA);

   if (__LOG) log("MovingAverageMethodToId()  invalid parameter method: \""+ method +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
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
   return(_empty(catch("MessageBoxCmdToStr()  unknown message box command = "+ cmd, ERR_RUNTIME_ERROR)));
}


/**
 * Ob der übergebene Parameter eine Tradeoperation bezeichnet.
 *
 * @param  int value - zu prüfender Wert
 *
 * @return bool
 */
bool IsTradeOperation(int value) {
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
 * Ob der übergebene Parameter eine Long-Tradeoperation bezeichnet.
 *
 * @param  int value - zu prüfender Wert
 *
 * @return bool
 */
bool IsLongTradeOperation(int value) {
   switch (value) {
      case OP_BUY:
      case OP_BUYLIMIT:
      case OP_BUYSTOP:
         return(true);
   }
   return(false);
}


/**
 * Ob der übergebene Parameter eine Short-Tradeoperation bezeichnet.
 *
 * @param  int value - zu prüfender Wert
 *
 * @return bool
 */
bool IsShortTradeOperation(int value) {
   switch (value) {
      case OP_SELL:
      case OP_SELLLIMIT:
      case OP_SELLSTOP:
         return(true);
   }
   return(false);
}


/**
 * Ob der übergebene Parameter eine "pending" Tradeoperation bezeichnet.
 *
 * @param  int value - zu prüfender Wert
 *
 * @return bool
 */
bool IsPendingTradeOperation(int value) {
   switch (value) {
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
      case OP_UNDEFINED: return("OP_UNDEFINED");
   }
   return(_empty(catch("OperationTypeToStr()  invalid parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
      case OP_UNDEFINED: return("undefined" );
   }
   return(_empty(catch("OperationTypeDescription()  invalid parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   return(_empty(catch("AppliedPriceToStr()  invalid parameter appliedPrice: "+ appliedPrice, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   return(_empty(catch("AppliedPriceDescription()  invalid parameter appliedPrice: "+ appliedPrice, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt den Integer-Wert eines Timeframe-Bezeichners zurück.
 *
 * @param  string timeframe - M1, M5, M15, M30 etc.
 *
 * @return int - Timeframe-Code oder -1, wenn der Bezeichner ungültig ist
 */
int PeriodToId(string timeframe) {
   timeframe = StringToUpper(timeframe);

   if (StringStartsWith(timeframe, "PERIOD_"))
      timeframe = StringRight(timeframe, -7);

   if (timeframe == "M1" ) return(PERIOD_M1 );     //     1  1 minute
   if (timeframe == "M5" ) return(PERIOD_M5 );     //     5  5 minutes
   if (timeframe == "M15") return(PERIOD_M15);     //    15  15 minutes
   if (timeframe == "M30") return(PERIOD_M30);     //    30  30 minutes
   if (timeframe == "H1" ) return(PERIOD_H1 );     //    60  1 hour
   if (timeframe == "H4" ) return(PERIOD_H4 );     //   240  4 hour
   if (timeframe == "D1" ) return(PERIOD_D1 );     //  1440  daily
   if (timeframe == "W1" ) return(PERIOD_W1 );     // 10080  weekly
   if (timeframe == "MN1") return(PERIOD_MN1);     // 43200  monthly

   if (__LOG) log("PeriodToId()  invalid parameter timeframe: \""+ timeframe +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
   return(-1);
}


/**
 * Gibt die lesbare Konstante einer Timeframe-ID zurück.
 *
 * @param  int period - Timeframe-Code bzw. Anzahl der Minuten je Chart-Bar (default: aktuelle Periode)
 *
 * @return string
 */
string PeriodToStr(int period=NULL) {
   if (period == NULL)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return("PERIOD_M1" );     //     1  1 minute
      case PERIOD_M5 : return("PERIOD_M5" );     //     5  5 minutes
      case PERIOD_M15: return("PERIOD_M15");     //    15  15 minutes
      case PERIOD_M30: return("PERIOD_M30");     //    30  30 minutes
      case PERIOD_H1 : return("PERIOD_H1" );     //    60  1 hour
      case PERIOD_H4 : return("PERIOD_H4" );     //   240  4 hour
      case PERIOD_D1 : return("PERIOD_D1" );     //  1440  daily
      case PERIOD_W1 : return("PERIOD_W1" );     // 10080  weekly
      case PERIOD_MN1: return("PERIOD_MN1");     // 43200  monthly
   }
   return(_empty(catch("PeriodToStr()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die Beschreibung eines Timeframe-Codes zurück.
 *
 * @param  int period - Timeframe-Code bzw. Anzahl der Minuten je Chart-Bar (default: aktuelle Periode)
 *
 * @return string
 */
string PeriodDescription(int period=NULL) {
   if (period == NULL)
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
   return(_empty(catch("PeriodDescription()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt das Timeframe-Flag der angegebenen Chartperiode zurück.
 *
 * @param  int period - Timeframe-Identifier (default: Periode des aktuellen Charts)
 *
 * @return int - Timeframe-Flag
 */
int PeriodFlag(int period=NULL) {
   if (period == NULL)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(F_PERIOD_M1 );
      case PERIOD_M5 : return(F_PERIOD_M5 );
      case PERIOD_M15: return(F_PERIOD_M15);
      case PERIOD_M30: return(F_PERIOD_M30);
      case PERIOD_H1 : return(F_PERIOD_H1 );
      case PERIOD_H4 : return(F_PERIOD_H4 );
      case PERIOD_D1 : return(F_PERIOD_D1 );
      case PERIOD_W1 : return(F_PERIOD_W1 );
      case PERIOD_MN1: return(F_PERIOD_MN1);
   }
   return(_ZERO(catch("PeriodFlag()  invalid parameter period = "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
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

   if (flags & F_PERIOD_M1  != 0) result = StringConcatenate(result, "|M1" );
   if (flags & F_PERIOD_M5  != 0) result = StringConcatenate(result, "|M5" );
   if (flags & F_PERIOD_M15 != 0) result = StringConcatenate(result, "|M15");
   if (flags & F_PERIOD_M30 != 0) result = StringConcatenate(result, "|M30");
   if (flags & F_PERIOD_H1  != 0) result = StringConcatenate(result, "|H1" );
   if (flags & F_PERIOD_H4  != 0) result = StringConcatenate(result, "|H4" );
   if (flags & F_PERIOD_D1  != 0) result = StringConcatenate(result, "|D1" );
   if (flags & F_PERIOD_W1  != 0) result = StringConcatenate(result, "|W1" );
   if (flags & F_PERIOD_MN1 != 0) result = StringConcatenate(result, "|MN1");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die Zeitzone des aktuellen MT-Servers zurück (nach Olson Timezone Database).
 *
 * @return string - Zeitzonen-Identifier oder Leerstring, falls ein Fehler auftrat
 *
 * @see http://en.wikipedia.org/wiki/Tz_database
 */
string GetServerTimezone() /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   /*
   Die Timezone-ID wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen die
   Rückgabewerte der MQL-Accountfunktionen evt. schon auf den neuen Account, der aktuelle Tick gehört aber noch zum alten Chart mit den alten Bars.
   Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Chart mit neuer Zeitzone befinden.
   */
   static string static.timezone[1];
   static int    lastTick;                                           // Erkennung von Mehrfachaufrufen während desselben Ticks

   // (1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (ValidBars == 0) /*&&*/ if (Tick != lastTick)
      static.timezone[0] = "";
   lastTick = Tick;

   if (StringLen(static.timezone[0]) > 0)
      return(static.timezone[0]);


   // (2) Timezone-ID ermitteln
   string timezone, directory=StringToLower(GetServerDirectory());

   if (StringLen(directory) == 0)
      return("");
   else if (StringStartsWith(directory, "alpari-"            )) timezone = "Alpari";               // Alpari: bis 01.04.2012 "Europe/Berlin"
   else if (StringStartsWith(directory, "alparibroker-"      )) timezone = "Alpari";               //          ab 02.04.2012 "Europe/Kiev"
   else if (StringStartsWith(directory, "alpariuk-"          )) timezone = "Alpari";               //
   else if (StringStartsWith(directory, "alparius-"          )) timezone = "Alpari";               // (History wurde nicht aktualisiert)
   else if (StringStartsWith(directory, "apbgtrading-"       )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "atcbrokers-"        )) timezone = "FXT";
   else if (StringStartsWith(directory, "atcbrokersest-"     )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "atcbrokersliq1-"    )) timezone = "FXT";
   else if (StringStartsWith(directory, "broco-"             )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "brocoinvestments-"  )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "dukascopy-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "easyforex-"         )) timezone = "GMT";
   else if (StringStartsWith(directory, "finfx-"             )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "forex-"             )) timezone = "GMT";
   else if (StringStartsWith(directory, "fxprimus-"          )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "fxpro.com-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "fxdd-"              )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "gcmfx-"             )) timezone = "GMT";
   else if (StringStartsWith(directory, "gftforex-"          )) timezone = "GMT";
   else if (StringStartsWith(directory, "inovatrade-"        )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "investorseurope-"   )) timezone = "Europe/London";
   else if (StringStartsWith(directory, "liteforex-"         )) timezone = "Europe/Minsk";
   else if (StringStartsWith(directory, "londoncapitalgr-"   )) timezone = "GMT";
   else if (StringStartsWith(directory, "londoncapitalgroup-")) timezone = "GMT";
   else if (StringStartsWith(directory, "mbtrading-"         )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "migbank-"           )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "oanda-"             )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "sig-"               )) timezone = "Europe/Minsk";
   else if (StringStartsWith(directory, "sts-"               )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "teletrade-"         )) timezone = "Europe/Berlin";
   else {
      // Fallback zur manuellen Konfiguration in globaler Config
      timezone = GetGlobalConfigString("Timezones", directory, "");
      if (StringLen(timezone) == 0)
         return(_empty(catch("GetServerTimezone(1)  missing timezone configuration for trade server \""+ GetServerDirectory() +"\"", ERR_INVALID_TIMEZONE_CONFIG)));
   }


   if (IsError(catch("GetServerTimezone(2)")))
      return("");

   static.timezone[0] = timezone;
   return(timezone);
}


/**
 * Gibt das Handle des MetaTrader-Hauptfensters zurück.
 *
 * @return int - Handle oder 0, falls ein Fehler auftrat
 */
int GetApplicationMainWindow() {
   static int hWnd;                                                  // ohne Initializer (@see MQL.doc)
   if (hWnd != 0)
      return(hWnd);

   string terminalClassName = "MetaQuotes::MetaTrader::4.00";

   // WindowHandle()
   if (!IsTesting() || IsVisualMode()) {
      hWnd = WindowHandle(Symbol(), NULL);                           // schlägt in etlichen Situationen fehl (init(), deinit(), in start() bei Programmstart, im Tester)
      if (hWnd != 0) {
         hWnd = GetAncestor(hWnd, GA_ROOT);
         if (GetClassName(hWnd) != terminalClassName) {
            catch("GetApplicationMainWindow(1)   wrong top-level window found (class \""+ GetClassName(hWnd) +"\"), hChild originates from WindowHandle()", ERR_RUNTIME_ERROR);
            hWnd = 0;
         }
         else {
            return(hWnd);
         }
      }
   }

   // alle Top-Level-Windows durchlaufen
   int processId[1], hWndNext=GetTopWindow(NULL), myProcessId=GetCurrentProcessId();

   while (hWndNext != 0) {
      GetWindowThreadProcessId(hWndNext, processId);
      if (processId[0]==myProcessId) /*&&*/ if (GetClassName(hWndNext)==terminalClassName)
         break;
      hWndNext = GetWindow(hWndNext, GW_HWNDNEXT);
   }
   if (hWndNext == 0) {
      catch("GetApplicationMainWindow(2)   cannot find application main window", ERR_RUNTIME_ERROR);
      hWnd = 0;
   }
   hWnd = hWndNext;

   return(hWnd);
}


/**
 * Gibt das Fensterhandle des Strategy Testers zurück. Wird die Funktion nicht aus dem Tester heraus aufgerufen, ist es möglich,
 * daß das Fenster noch nicht existiert.
 *
 * @return int - Handle oder 0, falls ein Fehler auftrat
 */
int GetTesterWindow() {
   static int hWndTester;                                                  // ohne Initializer (@see MQL.doc)
   if (hWndTester != 0)
      return(hWndTester);


   // Das Fenster kann im Terminalfenster angedockt sein oder in einem eigenen Toplevel-Window floaten, in beiden Fällen ist das Handle dasselbe und bleibt konstant.
   // alte Version mit dynamischen Klassennamen: v1.498


   // (1) Zunächst den im Hauptfenster angedockten Tester suchen
   int hWndMain = GetApplicationMainWindow();
   if (hWndMain == 0)
      return(0);
   int hWnd = GetDlgItem(hWndMain, ID_DOCKABLES_CONTAINER);                // Container für im Hauptfenster angedockte Fenster
   if (hWnd == 0)
      return(_NULL(catch("GetTesterWindow(1)   cannot find main parent window of docked child windows")));
   hWndTester = GetDlgItem(hWnd, ID_TESTER);
   if (hWndTester != 0)
      return(hWndTester);


   // (2) Dann Toplevel-Windows durchlaufen und nicht angedocktes Testerfenster des eigenen Prozesses suchen
   int processId[1], hNext=GetTopWindow(NULL), me=GetCurrentProcessId();
   while (hNext != 0) {
      GetWindowThreadProcessId(hNext, processId);

      if (processId[0] == me) {
         if (StringStartsWith(GetWindowText(hNext), "Tester")) {
            hWnd = GetDlgItem(hNext, ID_UNDOCKED_CONTAINER);               // Container für nicht angedockten Tester
            if (hWnd == 0)
               return(_NULL(catch("GetTesterWindow(2)   cannot find children of top-level Tester window")));
            hWndTester = GetDlgItem(hWnd, ID_TESTER);
            if (hWndTester == 0)
               return(_NULL(catch("GetTesterWindow(3)   cannot find sub-children of top-level Tester window")));
            break;
         }
      }
      hNext = GetWindow(hNext, GW_HWNDNEXT);
   }


   // (3) bei ausbleibenden Erfolg Umgebung prüfen und nur ggf. Exception werfen (das Tester-Fenster könnte noch nicht existieren)
   if (hWndTester == 0) {
      if (This.IsTesting())
         return(_NULL(catch("GetTesterWindow(4)   cannot find Strategy Tester window", ERR_RUNTIME_ERROR)));

      if (__LOG) log("GetTesterWindow()   cannot find Strategy Tester window");
   }

   return(hWndTester);
}


/**
 * Gibt die ID des Userinterface-Threads zurück.
 *
 * @return int - Thread-ID (nicht das Pseudo-Handle) oder 0, falls ein Fehler auftrat
 */
int GetUIThreadId() {
   static int threadId;                                              // ohne Initializer (@see MQL.doc)
   if (threadId != 0)
      return(threadId);

   int hWnd = GetApplicationMainWindow();
   if (hWnd == 0)
      return(0);

   int iNull[];
   threadId = GetWindowThreadProcessId(hWnd, iNull);

   return(threadId);
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
      case REASON_UNDEFINED  : return("undefined"                        );
      case REASON_CHARTCLOSE : return("chart closed or template changed" );
      case REASON_REMOVE     : return("program removed from chart"       );
      case REASON_RECOMPILE  : return("program recompiled"               );
      case REASON_PARAMETERS : return("input parameters changed"         );
      case REASON_CHARTCHANGE: return("chart symbol or timeframe changed");
      case REASON_ACCOUNT    : return("account changed"                  );
   }
   return(_empty(catch("UninitializeReasonDescription()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
      case REASON_UNDEFINED  : return("REASON_UNDEFINED"  );
      case REASON_CHARTCLOSE : return("REASON_CHARTCLOSE" );
      case REASON_REMOVE     : return("REASON_REMOVE"     );
      case REASON_RECOMPILE  : return("REASON_RECOMPILE"  );
      case REASON_PARAMETERS : return("REASON_PARAMETERS" );
      case REASON_CHARTCHANGE: return("REASON_CHARTCHANGE");
      case REASON_ACCOUNT    : return("REASON_ACCOUNT"    );
   }
   return(_empty(catch("UninitializeReasonToStr()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt den Titelbartext des angegebenen Fensters oder den Text des angegebenen Windows-Control zurück.
 *
 * @param  int hWnd - Handle
 *
 * @return string - Text oder Leerstring, falls ein Fehler auftrat
 *
 *
 *  NOTE:
 *  -----
 *  Benutzt SendMessage(), deshalb nicht nach EA-Stop bei VisualMode=TRUE benutzen, da UI-Thread-Deadlock
 */
string GetWindowText(int hWnd) {
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetWindowTextA(hWnd, buffer[0], bufferSize);

   while (chars >= bufferSize-1) {                                   // GetWindowTextA() gibt beim Abschneiden zu langer Tielzeilen mal {bufferSize},
      bufferSize <<= 1;                                              // mal {bufferSize-1} zurück.
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetWindowTextA(hWnd, buffer[0], bufferSize);
   }

   if (chars == 0) {
      // GetLastWin32Error() prüfen, hWnd könnte ungültig sein
   }

   return(buffer[0]);
}


/**
 * Gibt den Klassennamen des angegebenen Fensters zurück.
 *
 * @param  int hWnd - Handle des Fensters
 *
 * @return string - Klassenname oder Leerstring, falls ein Fehler auftrat
 */
string GetClassName(int hWnd) {
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetClassNameA(hWnd, buffer[0], bufferSize);

   while (chars >= bufferSize-1) {                                   // GetClassNameA() gibt beim Abschneiden zu langer Klassennamen {bufferSize-1} zurück.
      bufferSize <<= 1;
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetClassNameA(hWnd, buffer[0], bufferSize);
   }

   if (chars == 0)
      return(_empty(catch("GetClassName() ->user32::GetClassNameA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR)));

   return(buffer[0]);
}


/**
 * Konvertiert die angegebene GMT-Zeit nach FXT-Zeit (Forex Standard Time).
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GMTToFXT(datetime gmtTime) {
   if (gmtTime < 0)
      return(_int(-1, catch("GMTToFXT(1)  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int offset = GetGMTToFXTOffset(gmtTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime result = gmtTime - offset;
   if (result < 0)
      return(_int(-1, catch("GMTToFXT(2)   illegal datetime result: "+ result +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   return(result);
}


/**
 * Konvertiert die angegebene GMT-Zeit nach Tradeserver-Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GMTToServerTime(datetime gmtTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (gmtTime < 0)
      return(_int(-1, catch("GMTToServerTime(1)  invalid parameter gmtTime: "+ gmtTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string zone = GetServerTimezone();
   if (StringLen(zone) == 0)
      return(-1);

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (zone == "GMT")
      return(gmtTime);

   int offset = GetGMTToServerTimeOffset(gmtTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime result = gmtTime - offset;
   if (result < 0)
      return(_int(-1, catch("GMTToServerTime(2)   illegal datetime result: "+ result +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   return(result);
}


/**
 * Berechnet den Balancewert eines Accounts am angegebenen Offset des aktuellen Charts und schreibt ihn in das Ergebnisarray.
 *
 * @param  int    account - Account, für den der Wert berechnet werden soll
 * @param  double buffer  - Ergebnisarray (z.B. Indikatorpuffer)
 * @param  int    bar     - Barindex des zu berechnenden Wertes (Chart-Offset)
 *
 * @return int - Fehlerstatus
 */
int iAccountBalance(int account, double buffer[], int bar) {

   // TODO: Berechnung einzelner Bar implementieren (zur Zeit wird der Indikator hier noch komplett neuberechnet)

   if (iAccountBalanceSeries(account, buffer) == ERR_HISTORY_UPDATE) {
      catch("iAccountBalance(1)");
      return(SetLastError(ERR_HISTORY_UPDATE));
   }

   return(catch("iAccountBalance(2)"));
}


/**
 * Berechnet den Balanceverlauf eines Accounts für alle Bars des aktuellen Charts und schreibt die Werte in das angegebene Zielarray.
 *
 * @param  int    account - Account-Nummer
 * @param  double buffer  - Ergebnisarray (z.B. Indikatorpuffer)
 *
 * @return int - Fehlerstatus
 */
int iAccountBalanceSeries(int account, double& buffer[]) {
   if (ArraySize(buffer) != Bars) {
      ArrayResize(buffer, Bars);
      ArrayInitialize(buffer, EMPTY_VALUE);
   }

   // Balance-History holen
   datetime times []; ArrayResize(times , 0);
   double   values[]; ArrayResize(values, 0);

   int error = GetBalanceHistory(account, times, values);            // aufsteigend nach Zeit sortiert (in times[0] stehen die ältesten Werte)
   if (IsError(error))
      return(error);

   int bar, lastBar, historySize=ArraySize(values);

   // Balancewerte für Bars des aktuellen Charts ermitteln und ins Ergebnisarray schreiben
   for (int i=0; i < historySize; i++) {
      // Barindex des Zeitpunkts berechnen
      bar = iBarShiftNext(NULL, 0, times[i]);
      if (bar == EMPTY_VALUE)                                        // ERR_HISTORY_UPDATE ?
         return(last_error);
      if (bar == -1)                                                 // dieser und alle folgenden Werte sind zu neu für den Chart
         break;

      // Lücken mit vorherigem Balancewert füllen
      if (bar < lastBar-1) {
         for (int z=lastBar-1; z > bar; z--) {
            buffer[z] = buffer[lastBar];
         }
      }

      // aktuellen Balancewert eintragen
      buffer[bar] = values[i];
      lastBar = bar;
   }

   // Ergebnisarray bis zur ersten Bar mit dem letzten bekannten Balancewert füllen
   for (bar=lastBar-1; bar >= 0; bar--) {
      buffer[bar] = buffer[lastBar];
   }

   if (ArraySize(times)  > 0) ArrayResize(times,  0);
   if (ArraySize(values) > 0) ArrayResize(values, 0);

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
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int period/*=0*/, datetime time) /*throws ERR_HISTORY_UPDATE*/ {
   if (symbol == "0")                                       // NULL ist Integer (0)
      symbol = Symbol();

   if (time < 0)
      return(_int(EMPTY_VALUE, catch("iBarShiftPrevious(1)  invalid parameter time: "+ time +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

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

   if (IsError(error)) {
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
 */
int iBarShiftNext(string symbol/*=NULL*/, int period/*=0*/, datetime time) /*throws ERR_HISTORY_UPDATE*/ {
   if (symbol == "0")                                       // NULL ist Integer (0)
      symbol = Symbol();

   if (time < 0)
      return(_int(EMPTY_VALUE, catch("iBarShiftNext(1)  invalid parameter time: "+ time +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int bar   = iBarShift(symbol, period, time, true);
   int error = GetLastError();                              // ERR_HISTORY_UPDATE ???

   if (error==NO_ERROR) /*&&*/ if (bar==-1) {               // falls die Bar nicht existiert und auch kein Update läuft
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

   if (IsError(error)) {
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
   return(_ZERO(catch("IncreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Verbindet die Werte eines Boolean-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  bool   values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinBools(bool values[], string separator) {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("JoinBools()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (values[i]) strings[i] = "true";
      else           strings[i] = "false";
   }

   string result = JoinStrings(strings, separator);

   if (ArraySize(strings) > 0)
      ArrayResize(strings, 0);

   return(result);
}


/**
 * Verbindet die Werte eines Double-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  double values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinDoubles(double values[], string separator) {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("JoinDoubles()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = NumberToStr(values[i], ".1+");
      if (StringLen(strings[i]) == 0)
         return("");
   }

   string result = JoinStrings(strings, separator);

   if (ArraySize(strings) > 0)
      ArrayResize(strings, 0);

   return(result);
}


/**
 * Addiert die Werte eines Double-Arrays.
 *
 * @param  double values[]  - Array mit Ausgangswerten
 *
 * @return double - Summe aller Werte oder 0, falls ein Fehler auftrat
 */
double SumDoubles(double values[]) {
   if (ArrayDimension(values) > 1)
      return(_ZERO(catch("SumDoubles()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   double sum;

   int size = ArraySize(values);

   for (int i=0; i < size; i++) {
      sum += values[i];
   }

   return(sum);
}


/**
 * Konvertiert ein Doubles-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string DoublesToStr(double values[][], string separator=", ") {
   return(DoublesToStr_intern(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string DoublesToStr_intern(double values2[][], double values3[][][], string separator) {
   if (separator == "0")   // NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;

   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoubles(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      double    valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = DoublesToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      double    valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = DoublesToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("DoublesToStr()  illegal parameter values, too many dimensions = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein Array mit Kursen in einen lesbaren String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string RatesToStr(double values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("RatesToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = NumberToStr(values[i], PriceFormat);
      if (StringLen(strings[i]) == 0)
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein Array mit Geldbeträgen in einen lesbaren String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String mit 2 Nachkommastellen je Wert oder Leerstring, falls ein Fehler auftrat
 */
string MoneysToStr(double values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("MoneysToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = NumberToStr(values[i], ".2");
      if (StringLen(strings[i]) == 0)
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Verbindet die Werte eines Integer-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  int    values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinInts(int values[], string separator) {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("JoinInts()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = values[i];
   }

   string result = JoinStrings(strings, separator);
   if (ArraySize(strings) > 0)
      ArrayResize(strings, 0);
   return(result);
}


/**
 * Addiert die Werte eines Integer-Arrays.
 *
 * @param  int values[] - Array mit Ausgangswerten
 *
 * @return int - Summe der Werte oder 0, falls ein Fehler auftrat
 */
int SumInts(int values[]) {
   if (ArrayDimension(values) > 1)
      return(_ZERO(catch("SumInts()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int sum, size=ArraySize(values);

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum);
}


/**
 * Konvertiert ein Integer-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string IntsToStr(int values[][], string separator=", ") {
   return(IntsToStr_intern(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string IntsToStr_intern(int values2[][], int values3[][][], string separator) {
   if (separator == "0")   // NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result;


   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinInts(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      int       valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = IntsToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      int       valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = IntsToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("IntsToStr()  illegal parameter values, too many dimensions = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein DateTime-Array in einen lesbaren String.
 *
 * @param  datetime values[]
 * @param  string   separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TimesToStr(datetime values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("TimesToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if      (values[i] <  0) strings[i] = "-1";
      else if (values[i] == 0) strings[i] =  "0";
      else                     strings[i] = StringConcatenate("'", TimeToStr(values[i], TIME_FULL), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein Char-Array in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string CharsToStr(int values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("CharsToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = StringConcatenate("'", CharToStr(values[i]), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein OperationType-Array in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string OperationTypesToStr(int values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("OperationTypesToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string strings[]; ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = OperationTypeToStr(values[i]);
      if (StringLen(strings[i]) == 0)
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Verbindet die Werte eines Stringarrays unter Verwendung des angegebenen Separators.
 *
 * @param  string values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinStrings(string values[], string separator) {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("JoinStrings()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string result = "";

   int size = ArraySize(values);

   for (int i=1; i < size; i++) {
      result = StringConcatenate(result, separator, values[i]);
   }

   if (size > 0)
      result = StringConcatenate(values[0], result);

   if (IsError(catch("JoinStrings()")))
      return("");
   return(result);
}


/**
 * Konvertiert ein String-Array in einen lesbaren String.
 *
 * @param  string values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string StringsToStr(string values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("StringsToStr()  invalid parameter values, too many dimensions = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")   // NULL
      separator = ", ";

   string joined = JoinStrings(values, StringConcatenate("\"", separator, "\""));
   if (StringLen(joined) == 0)
      return("");
   return(StringConcatenate("{\"", joined, "\"}"));
}


/**
 * Durchsucht ein Boolean-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchBoolArray(bool haystack[], bool needle) {
   if (ArrayDimension(haystack) > 1)
      return(_int(-1, catch("SearchBoolArray()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(-1);
}


/**
 * Prüft, ob ein Boolean in einem Array enthalten ist.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return bool
 */
bool BoolInArray(bool haystack[], bool needle) {
   return(SearchBoolArray(haystack, needle) > -1);
}


/**
 * Durchsucht ein Integer-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  int haystack[] - zu durchsuchendes Array
 * @param  int needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchIntArray(int haystack[], int needle) {
   if (ArrayDimension(haystack) > 1)
      return(_int(-1, catch("SearchIntArray()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @param  int haystack[] - zu durchsuchendes Array
 * @param  int needle     - zu suchender Wert
 *
 * @return bool
 */
bool IntInArray(int haystack[], int needle) {
   return(SearchIntArray(haystack, needle) > -1);
}


/**
 * Durchsucht ein Double-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  double haystack[] - zu durchsuchendes Array
 * @param  double needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchDoubleArray(double haystack[], double needle) {
   if (ArrayDimension(haystack) > 1)
      return(_int(-1, catch("SearchDoubleArray()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @param  double haystack[] - zu durchsuchendes Array
 * @param  double needle     - zu suchender Wert
 *
 * @return bool
 */
bool DoubleInArray(double haystack[], double needle) {
   return(SearchDoubleArray(haystack, needle) > -1);
}


/**
 * Durchsucht ein String-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchStringArray(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1)
      return(_int(-1, catch("SearchStringArray()   too many dimensions in parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return bool
 */
bool StringInArray(string haystack[], string needle) {
   return(SearchStringArray(haystack, needle) > -1);
}


/**
 * Entfernt die angegebenen Objekte aus dem aktuellen Chart.
 *
 * @param  string objects[] - Array mit Objektlabels
 *
 * @return int - Fehlerstatus
 */
int RemoveChartObjects(string objects[]) {
   int size = ArraySize(objects);
   if (size == 0)
      return(NO_ERROR);

   for (int i=0; i < size; i++) {
      ObjectDelete(objects[i]);
   }
   ArrayResize(objects, 0);

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
int SendSMS(string receiver, string message) {
   if (!StringIsDigit(receiver))
      return(catch("SendSMS(1)   invalid parameter receiver: \""+ receiver +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));

   // TODO: Gateway-Zugangsdaten auslagern

   // Befehlszeile für Shellaufruf zusammensetzen
   string url          = "https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={id}&to="+ receiver +"&text="+ UrlEncode(message);
   string filesDir     = TerminalPath() +"\\experts\\files";
   string time         = StringReplace(StringReplace(TimeToStr(TimeLocal(), TIME_FULL), ".", "-"), ":", ".");
   string responseFile = filesDir +"\\sms_"+ time +"_"+ GetCurrentThreadId() +".response";
   string logFile      = filesDir +"\\sms.log";
   string cmdLine      = "wget.exe -b --no-check-certificate \""+ url +"\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";

   int error = WinExec(cmdLine, SW_HIDE);       // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("SendSMS(1) ->kernel32::WinExec(cmdLine=\""+ cmdLine +"\"), error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WIN32_ERROR));

   /**
    * TODO: Prüfen, ob wget.exe im Pfad gefunden werden kann:  =>  error=2 [File not found]
    *
    *
    * TODO: Fehlerauswertung nach dem Versand
    *
    * --2011-03-23 08:32:06--  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={id}&to={receiver}&text={text}
    * Resolving api.clickatell.com... failed: Unknown host.
    * wget: unable to resolve host address `api.clickatell.com'
    */

   return(catch("SendSMS(2)"));
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach FXT (Forex Standard Time).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - FXT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime ServerToFXT(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("ServerToFXT()  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string zone = GetServerTimezone();
   if (StringLen(zone) == 0)
      return(-1);

   // schnelle Rückkehr, wenn der Tradeserver unter FXT läuft
   if (zone == "FXT")
      return(serverTime);

   datetime gmtTime = ServerToGMT(serverTime);
   if (gmtTime == -1)
      return(-1);

   return(GMTToFXT(gmtTime));
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach GMT.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime ServerToGMT(datetime serverTime) /*throws ERR_INVALID_TIMEZONE_CONFIG*/ {
   if (serverTime < 0)
      return(_int(-1, catch("ServerToGMT(1)   invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string zone = GetServerTimezone();
   if (StringLen(zone) == 0)
      return(-1);

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (zone == "GMT")
      return(serverTime);

   int offset = GetServerToGMTOffset(serverTime);
   if (offset == EMPTY_VALUE)
      return(-1);

   datetime result = serverTime - offset;
   if (result < 0)
      return(_int(-1, catch("ServerToGMT(2)   illegal datetime result: "+ result +" (not a time) for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   return(result);
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
   if (StringLen(substring) == 0)
      return(_false(catch("StringContains()   empty substring \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   if (StringLen(substring) == 0)
      return(_false(catch("StringIContains()   empty substring \"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
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

   if (IsError(catch("StringFindR()")))
      return(-1);
   return(lastFound);
}


/**
 * Konvertiert einen String in Kleinschreibweise.
 *
 * Alias für StringToLower()
 */
string StrToLower(string value) {
   return(StringToLower(value));
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
   int char, len=StringLen(value);

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

   if (IsError(catch("StringToLower()")))
      return("");
   return(result);
}


/**
 * Konvertiert einen String in Großschreibweise.
 *
 * Alias für StringToUpper()
 */
string StrToUpper(string value) {
   return(StringToUpper(value));
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
   int char, len=StringLen(value);

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

   if (IsError(catch("StringToUpper()")))
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
   string strChar, result="";
   int    char, len=StringLen(value);

   for (int i=0; i < len; i++) {
      strChar = StringSubstr(value, i, 1);
      char    = StringGetChar(strChar, 0);

      if      (47 < char && char <  58) result = StringConcatenate(result, strChar);                  // 0-9
      else if (64 < char && char <  91) result = StringConcatenate(result, strChar);                  // A-Z
      else if (96 < char && char < 123) result = StringConcatenate(result, strChar);                  // a-z
      else if (char == ' ')             result = StringConcatenate(result, "+");
      else                              result = StringConcatenate(result, "%", CharToHexStr(char));
   }

   if (IsError(catch("UrlEncode()")))
      return("");
   return(result);
}


/**
 * Prüft, ob der angegebene Name eine existierende und normale Datei ist (kein Verzeichnis).
 *
 * @return string filename - vollständiger Dateiname (für Windows-Dateifunktionen)
 *
 * @return bool
 */
bool IsFile(string filename) {
   bool result;

   if (StringLen(filename) > 0) {
      /*WIN32_FIND_DATA*/int wfd[]; InitializeBuffer(wfd, WIN32_FIND_DATA.size);

      int hSearch = FindFirstFileA(filename, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {                         // INVALID_HANDLE_VALUE = nichts gefunden
         result = !wfd.FileAttribute.Directory(wfd);
         FindClose(hSearch);
      }
      ArrayResize(wfd, 0);
   }
   return(result);
}


/**
 * Prüft, ob der angegebene Name ein existierendes Verzeichnis ist (keine normale Datei).
 *
 * @return string filename - vollständiger Dateiname (für Windows-Dateifunktionen)
 *
 * @return bool
 */
bool IsDirectory(string filename) {
   bool result;

   if (StringLen(filename) > 0) {
      while (StringRight(filename, 1) == "\\") {
         filename = StringLeft(filename, -1);
      }

      /*WIN32_FIND_DATA*/int wfd[]; InitializeBuffer(wfd, WIN32_FIND_DATA.size);

      int hSearch = FindFirstFileA(filename, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {                         // INVALID_HANDLE_VALUE = nichts gefunden
         result = wfd.FileAttribute.Directory(wfd);
         FindClose(hSearch);
      }
      ArrayResize(wfd, 0);
   }
   return(result);
}


/**
 * Prüft, ob der angegebene Name eine existierende und normale MQL-Datei ist (kein Verzeichnis).
 *
 * @return string filename - zu ".\files\" relativer Dateiname (für MQL-Dateifunktionen)
 *
 * @return bool
 */
bool IsMqlFile(string filename) {
   if (IsScript() || !This.IsTesting()) filename = StringConcatenate(TerminalPath(), "\\experts\\files\\", filename);
   else                                 filename = StringConcatenate(TerminalPath(), "\\tester\\files\\",  filename);
   return(IsFile(filename));
}


/**
 * Prüft, ob der angegebene Name ein existierendes MQL-Verzeichnis ist (keine normale Datei).
 *
 * @return string filename - zu ".\files\" relativer Dateiname (für MQL-Dateifunktionen)
 *
 * @return bool
 */
bool IsMqlDirectory(string filename) {
   if (IsScript() || !This.IsTesting()) filename = StringConcatenate(TerminalPath(), "\\experts\\files\\", filename);
   else                                 filename = StringConcatenate(TerminalPath(), "\\tester\\files\\",  filename);
   return(IsDirectory(filename));
}


/**
 * Findet alle zum angegebenen Muster passenden Dateinamen. Pseudo-Verzeichnisse ("." und "..") werden nicht berücksichtigt.
 *
 * @param  string  pattern     - Namensmuster mit Wildcards nach Windows-Konventionen
 * @param  string& lpResults[] - Zeiger auf Array zur Aufnahme der Suchergebnisse
 * @param  int     flags       - zusätzliche Suchflags: [FF_DIRSONLY | FF_FILESONLY | FF_SORT] (default: keine)
 *
 *                               FF_DIRSONLY:  return only directory entries which match the pattern (default: all entries)
 *                               FF_FILESONLY: return only file entries which match the pattern      (default: all entries)
 *                               FF_SORT:      sort returned entries                                 (default: NTFS: sorting, FAT: no sorting)
 *
 * @return int - Anzahl der gefundenen Einträge oder -1, falls ein Fehler auftrat
 */
int FindFileNames(string pattern, string& lpResults[], int flags=NULL) {
   if (StringLen(pattern) == 0)
      return(_int(-1, catch("FindFileNames(1)   illegal parameter pattern = \""+ pattern +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));

   ArrayResize(lpResults, 0);

   string name;
   /*WIN32_FIND_DATA*/ int wfd[]; InitializeBuffer(wfd, WIN32_FIND_DATA.size);
   int hSearch = FindFirstFileA(pattern, wfd), next=hSearch;

   while (next > 0) {
      name = wfd.FileName(wfd);
      //debug("FindFileNames()   \""+ name +"\"   "+ wfd.FileAttributesToStr(wfd));

      while (true) {
         if (wfd.FileAttribute.Directory(wfd)) {
            if (flags & FF_FILESONLY != 0)  break;
            if (name ==  ".")               break;
            if (name == "..")               break;
         }
         else if (flags & FF_DIRSONLY != 0) break;
         ArrayPushString(lpResults, name);
         break;
      }
      next = FindNextFileA(hSearch, wfd);
   }
   ArrayResize(wfd, 0);

   if (hSearch == INVALID_HANDLE_VALUE)                              // INVALID_HANDLE_VALUE = nichts gefunden
      return(0);
   FindClose(hSearch);

   int size = ArraySize(lpResults);

   if (flags & FF_SORT!=0) /*&&*/ if (size > 1) {                    // TODO: Ergebnisse ggf. sortieren
   }
   return(size);
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
         else catch("RGB(1)  invalid parameter blue: "+ blue, ERR_INVALID_FUNCTION_PARAMVALUE);
      }
      else catch("RGB(2)  invalid parameter green: "+ green, ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   else catch("RGB(3)  invalid parameter red: "+ red, ERR_INVALID_FUNCTION_PARAMVALUE);

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
   int red   = rgb       & 0xFF;
   int green = rgb >>  8 & 0xFF;
   int blue  = rgb >> 16 & 0xFF;

   return(StringConcatenate(red, ",", green, ",", blue));
}


/**
 * Konvertiert drei RGB-Farbwerte in den HSV-Farbraum (Hue-Saturation-Value).
 *
 * @param  int    red   - Rotanteil  (0-255)
 * @param  int    green - Grünanteil (0-255)
 * @param  int    blue  - Blauanteil (0-255)
 * @param  double hsv[] - Array zur Aufnahme der HSV-Werte
 *
 * @return int - Fehlerstatus
 */
int RGBValuesToHSVColor(int red, int green, int blue, double hsv[]) {
   return(RGBToHSVColor(RGB(red, green, blue), hsv));
}


/**
 * Konvertiert eine RGB-Farbe in den HSV-Farbraum (Hue-Saturation-Value).
 *
 * @param  color  rgb   - Farbe
 * @param  double hsv[] - Array zur Aufnahme der HSV-Werte
 *
 * @return int - Fehlerstatus
 */
int RGBToHSVColor(color rgb, double& hsv[]) {
   int red   = rgb       & 0xFF;
   int green = rgb >>  8 & 0xFF;
   int blue  = rgb >> 16 & 0xFF;

   double r=red/255.0, g=green/255.0, b=blue/255.0;                  // scale to unity (0-1)

   double dMin   = MathMin(r, MathMin(g, b)); int iMin   = Min(red, Min(green, blue));
   double dMax   = MathMax(r, MathMax(g, b)); int iMax   = Max(red, Max(green, blue));
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

   if (ArraySize(hsv) != 3)
      ArrayResize(hsv, 3);

   hsv[0] = hue * 360;
   hsv[1] = sat;
   hsv[2] = val;

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
      return(catch("HSVToRGBColor(1)   illegal parameter hsv: "+ DoublesToStr(hsv), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(hsv) != 3)
      return(catch("HSVToRGBColor(2)   illegal parameter hsv: "+ DoublesToStr(hsv), ERR_INCOMPATIBLE_ARRAYS));

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
   if (hue < 0.0 || hue > 360.0)             return(_int(-1, catch("HSVValuesToRGBColor(1)  invalid parameter hue: "+ NumberToStr(hue, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (saturation < 0.0 || saturation > 1.0) return(_int(-1, catch("HSVValuesToRGBColor(2)  invalid parameter saturation: "+ NumberToStr(saturation, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (value < 0.0 || value > 1.0)           return(_int(-1, catch("HSVValuesToRGBColor(3)  invalid parameter value: "+ NumberToStr(value, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));

   double red, green, blue;

   if (EQ(saturation, 0)) {
      red   = value;
      green = value;
      blue  = value;
   }
   else {
      double h  = hue / 60;                           // h = hue / 360 * 6
      int    i  = h;
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

   int r = Round(red   * 255);
   int g = Round(green * 255);
   int b = Round(blue  * 255);

   color rgb = r + g<<8 + b<<16;

   int error = GetLastError();
   if (IsError(error))
      return(_int(-1, catch("HSVValuesToRGBColor(4)", error)));
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

               ArrayResize(hsv, 0);

               int error = GetLastError();
               if (IsError(error))
                  return(_int(-1, catch("Color.ModifyHSV(1)", error)));

               return(result);
            }
            else catch("Color.ModifyHSV(2)  invalid parameter mod_value: "+ NumberToStr(mod_value, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
         }
         else catch("Color.ModifyHSV(3)  invalid parameter mod_saturation: "+ NumberToStr(mod_saturation, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      }
      else catch("Color.ModifyHSV(4)  invalid parameter mod_hue: "+ NumberToStr(mod_hue, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   else catch("Color.ModifyHSV(5)  invalid parameter rgb: "+ rgb, ERR_INVALID_FUNCTION_PARAMVALUE);

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
   if (digits < 0 || digits > 16)
      return(_empty(catch("DoubleToStrEx()  illegal parameter digits: "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));

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
   if (value < 0) {
      isNegative = true;
      value = -value;
   }

   double integer    = MathFloor(value);
   string strInteger = Round(integer);

   double remainder    = MathRound((value-integer) * decimals[digits]);
   string strRemainder = "";

   for (int i=0; i < digits; i++) {
      double fraction = MathFloor(remainder/10);
      int    digit    = Round(remainder - fraction*10);
      strRemainder = digit + strRemainder;
      remainder    = fraction;
   }

   string result = strInteger;

   if (digits > 0)
      result = StringConcatenate(result, ".", strRemainder);

   if (isNegative)
      result = StringConcatenate("-", result);

   ArrayResize(decimals, 0);
   return(result);
}


/**
 * MetaQuotes-Alias für DoubleToStrEx()
 */
string DoubleToStrMorePrecision(double value, int precision) {
   return(DoubleToStrEx(value, precision));
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
   if (times < 0)
      return(_empty(catch("StringRepeat()  invalid parameter times: "+ times, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (times ==  0)           return("");
   if (StringLen(input) == 0) return("");

   string output = input;
   for (int i=1; i < times; i++) {
      output = StringConcatenate(output, input);
   }
   return(output);
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
   return(MathRound(number*operand + Sign(number)*0.000000000001) / operand);
}


/**
 * Formatiert einen numerischen Wert im angegebenen Format und gibt den resultierenden String zurück.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of the decimal point.
 *
 * Mask parameters:
 *
 *   n        = number of digits to the left of the decimal point, e.g. NumberToStr(123.456, "5") => "123"
 *   n.d      = number of left and right digits, e.g. NumberToStr(123.456, "5.2") => "123.45"
 *   n.       = number of left and all right digits, e.g. NumberToStr(123.456, "2.") => "23.456"
 *    .d      = all left and number of right digits, e.g. NumberToStr(123.456, ".2") => "123.45"
 *    .d'     = all left and number of right digits plus 1 additional subpip digit, e.g. NumberToStr(123.45678, ".4'") => "123.4567'8"
 *    .d+     = + anywhere right of .d in mask: all left and minimum number of right digits, e.g. NumberToStr(123.456, ".2+") => "123.456"
 *  +n.d      = + anywhere left of n. in mask: plus sign for positive values
 *    R       = round result in the last displayed digit, e.g. NumberToStr(123.456, "R3.2") => "123.46", e.g. NumberToStr(123.7, "R3") => "124"
 *    ;       = Separatoren tauschen (Europäisches Format), e.g. NumberToStr(123456.789, "6.2;") => "123456,78"
 *    ,       = Tausender-Separatoren einfügen, e.g. NumberToStr(123456.789, "6.2,") => "123,456.78"
 *    ,<char> = Tausender-Separatoren einfügen und auf <char> setzen, e.g. NumberToStr(123456.789, ", 6.2") => "123 456.78"
 *
 * @param  double number
 * @param  string mask
 *
 * @return string - formatierter Wert oder Leerstring, falls ein Fehler auftrat
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
         else if (nDigit && char==39) {      // 39 => '
            nSubpip = nRight;
            continue;
         }
         else {
            if  (char == '+') nRight = Max(nRight + (nSubpip>0), CountDecimals(number));     // (int) bool
            else if (!nDigit) nRight = CountDecimals(number);
            break;
         }
      }
      if (nDigit) {
         if (nSubpip >  0) nRight++;
         if (nSubpip == 8) nSubpip = 0;
         nRight = Min(nRight, 8);
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
   else             nLeft = Min(nLeft, dLeft);
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

   //debug("NumberToStr(double="+ DoubleToStr(number, 8) +", mask="+ mask +")    nLeft="+ nLeft +"    dLeft="+ dLeft +"    nRight="+ nRight +"    nSubpip="+ nSubpip +"    outStr=\""+ outStr +"\"");

   if (IsError(catch("NumberToStr()")))
      return("");
   return(outStr);
}


/**
 * TODO: Es werden noch keine Limit- und TakeProfit-Orders unterstützt.
 *
 * Drop-in-Ersatz für und erweiterte Version von OrderSend(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  string   symbol      - Symbol des Instruments          (default: aktuelles Instrument)
 * @param  int      type        - Operation type: [OP_BUY|OP_SELL|OP_BUYLIMIT|OP_SELLLIMIT|OP_BUYSTOP|OP_SELLSTOP]
 * @param  double   lots        - Transaktionsvolumen in Lots
 * @param  double   price       - Preis (nur bei pending Orders)
 * @param  double   slippage    - akzeptable Slippage in Pips     (default: 0          )
 * @param  double   stopLoss    - StopLoss-Level                  (default: -kein-     )
 * @param  double   takeProfit  - TakeProfit-Level                (default: -kein-     )
 * @param  string   comment     - Orderkommentar, max. 27 Zeichen (default: -kein-     )
 * @param  int      magicNumber - MagicNumber                     (default: 0          )
 * @param  datetime expires     - Gültigkeit der Order            (default: GTC        )
 * @param  color    markerColor - Farbe des Chartmarkers
 * @param  int      execFlags   - die Ausführung steuernde Flags
 * @param  double   execution[] - Ausführungsdaten
 *
 * @return int - Ticket oder -1, falls ein Fehler auftrat
 *
 *
 * Elemente des Parameters execution[] (out)
 * -----------------------------------------
 * - EXEC_TIME      : OrderOpenTime
 * - EXEC_PRICE     : OrderOpenPrice (bei Pending-Orders der Pending-Price, bei Market-Orders der ausgeführte OpenPrice)
 * - EXEC_SWAP      : immer 0
 * - EXEC_COMMISSION: OrderCommission (nur bei Market-Orders)
 * - EXEC_PROFIT    : immer 0
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden
 * - EXEC_REQUOTES  : Anzahl der aufgetretenen Requotes
 * - EXEC_SLIPPAGE  : Gesamtslippage der Orderausführung in Pips nach Requotes (positiv: zu ungunsten; negativ: zu gunsten)
 * - EXEC_TICKET    : das erzeugte Ticket (wie von der Funktion zurückgegeben)
 */
int OrderSendEx(string symbol/*=NULL*/, int type, double lots, double price/*=0*/, double slippage/*=0*/, double stopLoss/*=0*/, double takeProfit/*=0*/, string comment/*=""*/, int magicNumber/*=0*/, datetime expires/*=0*/, color markerColor, int execFlags, double& execution[]) {
   // -- Beginn Parametervalidierung --
   // symbol
   if (symbol == "0")      // = NULL
      symbol = Symbol();
   int    digits         = MarketInfo(symbol, MODE_DIGITS);
   double minLot         = MarketInfo(symbol, MODE_MINLOT);
   double maxLot         = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep        = MarketInfo(symbol, MODE_LOTSTEP);

   int    pipDigits      = digits & (~1);
   int    pipPoints      = Round(MathPow(10, digits-pipDigits));
   double pip            =     1/MathPow(10, pipDigits), pips=pip;
   int    slippagePoints = Round(slippage * pipPoints);
   double stopDistance   = MarketInfo(symbol, MODE_STOPLEVEL)/pipPoints;
   string priceFormat    = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   int error = GetLastError();
   if (IsError(error))                                         return(_int(-1, catch("OrderSendEx(1)   symbol=\""+ symbol +"\"", error)));
   // type
   if (!IsTradeOperation(type))                                return(_int(-1, catch("OrderSendEx(2)   invalid parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
   // lots
   if (LT(lots, minLot))                                       return(_int(-1, catch("OrderSendEx(3)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME)));
   if (GT(lots, maxLot))                                       return(_int(-1, catch("OrderSendEx(4)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME)));
   if (NE(MathModFix(lots, lotStep), 0))                       return(_int(-1, catch("OrderSendEx(5)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_TRADE_VOLUME)));
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0))                                           return(_int(-1, catch("OrderSendEx(6)   illegal parameter price = "+ NumberToStr(price, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (IsPendingTradeOperation(type)) /*&&*/ if (EQ(price, 0)) return(_int(-1, catch("OrderSendEx(7)   illegal "+ OperationTypeDescription(type) +" price = "+ NumberToStr(price, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE)));
   // slippage
   if (LT(slippage, 0))                                        return(_int(-1, catch("OrderSendEx(8)   illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   // stopLoss
   if (LT(stopLoss, 0))                                        return(_int(-1, catch("OrderSendEx(9)   illegal parameter stopLoss = "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE)));
   stopLoss = NormalizeDouble(stopLoss, digits);
   // takeProfit
   if (NE(takeProfit, 0))                                      return(_int(-1, catch("OrderSendEx(10)   submission of take-profit orders not yet implemented", ERR_INVALID_FUNCTION_PARAMVALUE)));
   takeProfit = NormalizeDouble(takeProfit, digits);
   // comment
   if (comment == "0")     // = NULL
      comment = "";
   else if (StringLen(comment) > 27)                           return(_int(-1, catch("OrderSendEx(11)   illegal parameter comment = \""+ comment +"\" (max. 27 chars)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   // expires
   if (expires != 0) /*&&*/ if (expires <= TimeCurrent())      return(_int(-1, catch("OrderSendEx(12)   illegal parameter expires = "+ ifString(expires<0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_FUNCTION_PARAMVALUE)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_int(-1, catch("OrderSendEx(13)   illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE)));
   // execution
   if (ArraySize(execution) != 9)
      ArrayResize(execution, 9);
   // -- Ende Parametervalidierung --

   int    ticket, time1, time2, firstTime1, requotes;
   double firstPrice;                                                                     // erster OrderPrice (falls ERR_REQUOTE auftritt)


   // Endlosschleife, bis Order ausgeführt wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      error = NO_ERROR;

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderSendEx()   trade context busy, retrying...");
         Sleep(300);                                                                      // 0.3 Sekunden warten
      }
      else {
         // zu verwendenden OpenPrice bestimmen und ggf. StopDistance validieren
         double bid = MarketInfo(symbol, MODE_BID);
         double ask = MarketInfo(symbol, MODE_ASK);
         if      (type == OP_BUY    ) price = ask;
         else if (type == OP_SELL   ) price = bid;
         else if (type == OP_BUYSTOP) {
            if (LT(price - stopDistance*pips, ask)) return(_int(-1, catch("OrderSendEx(14)   "+ OperationTypeDescription(type) +" at "+ NumberToStr(price, priceFormat) +" too close to market ("+ NumberToStr(bid, priceFormat) +"/"+ NumberToStr(ask, priceFormat) +", stop distance="+ NumberToStr(stopDistance, ".+") +" pip)", ERR_INVALID_STOPS)));
         }
         else if (type == OP_SELLSTOP) {
            if (GT(price + stopDistance*pips, bid)) return(_int(-1, catch("OrderSendEx(15)   "+ OperationTypeDescription(type) +" at "+ NumberToStr(price, priceFormat) +" too close to market ("+ NumberToStr(bid, priceFormat) +"/"+ NumberToStr(ask, priceFormat) +", stop distance="+ NumberToStr(stopDistance, ".+") +" pip)", ERR_INVALID_STOPS)));
         }
         price = NormalizeDouble(price, digits);

         if (NE(stopLoss, 0)) {
            if (type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT) {
               if (GE(stopLoss, price))   return(_int(-1, catch("OrderSendEx(16)   illegal stoploss "+ NumberToStr(stopLoss, priceFormat) +" for "+ OperationTypeDescription(type) +" at "+ NumberToStr(price, priceFormat), ERR_INVALID_STOPS)));
            }
            else if (LE(stopLoss, price)) return(_int(-1, catch("OrderSendEx(17)   illegal stoploss "+ NumberToStr(stopLoss, priceFormat) +" for "+ OperationTypeDescription(type) +" at "+ NumberToStr(price, priceFormat), ERR_INVALID_STOPS)));
         }

         time1 = GetTickCount();
         if (firstTime1 == 0) {
            firstTime1 = time1;
            firstPrice = price;                                                           // OrderPrice und Zeit der ersten Ausführung merken
         }

         ticket = OrderSend(symbol, type, lots, price, slippagePoints, stopLoss, takeProfit, comment, magicNumber, expires, markerColor);
         time2  = GetTickCount();

         if (ticket > 0) {
            OrderPush("OrderSendEx(18)");
            WaitForTicket(ticket, false);                                                 // wartet und selektiert (FALSE)

            if (!ChartMarker.OrderSent_A(ticket, digits, markerColor))
               return(_int(-1, OrderPop("OrderSendEx(19)")));

            // Execution-Struktur füllen
            execution[EXEC_TIME      ] = OrderOpenTime();
            execution[EXEC_PRICE     ] = OrderOpenPrice();
            execution[EXEC_SWAP      ] = 0;
            execution[EXEC_COMMISSION] = OrderCommission();
            execution[EXEC_PROFIT    ] = 0;
            execution[EXEC_DURATION  ] = (time2-firstTime1)/1000.0;                       // in Sekunden
            execution[EXEC_REQUOTES  ] = requotes;                                        // Anzahl
               if      (OrderType() == OP_BUY ) slippage = OrderOpenPrice() - firstPrice;
               else if (OrderType() == OP_SELL) slippage = firstPrice - OrderOpenPrice();
               else                             slippage = 0;
            execution[EXEC_SLIPPAGE  ] = NormalizeDouble(slippage/pips, 1);               // in Pips
            execution[EXEC_TICKET    ] = ticket;

            if (__LOG) log("OrderSendEx()   opened "+ OrderSendEx.LogMessage(ticket, type, lots, firstPrice, digits, time2-firstTime1, requotes));
            if (!IsTesting())
               PlaySound(ifString(requotes==0, "OrderOk.wav", "Blip.wav"));

            if (IsError(catch("OrderSendEx(20)", NULL, O_POP)))
               return(-1);
            return(ticket);                                                               // regular exit
         }
         error = GetLastError();

         if (error == ERR_REQUOTE) {
            requotes++;
            if (IsTesting())
               break;
            continue;                                                                     // nach ERR_REQUOTE Order schnellstmöglich wiederholen
         }
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                                               // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;

         warn(StringConcatenate("OrderSendEx()   temporary trade error after ", DoubleToStr((time2-firstTime1)/1000.0, 3), " s", ifString(requotes==0, "", StringConcatenate(" and ", requotes, " requote", ifString(requotes==1, "", "s"))), ", retrying..."), error);
      }
   }

   return(_int(-1, catch("OrderSendEx(22)   permanent trade error after "+ DoubleToStr((time2-firstTime1)/1000.0, 3) +" s"+ ifString(requotes==0, "", " and "+ requotes +" requote"+ ifString(requotes==1, "", "s")), error)));
}


/**
 * Generiert eine ausführliche Logmessage für eine erfolgreich abgeschickte oder ausgeführte Order.
 *
 * @param  int    ticket   - Ticket-Nummer der Order
 * @param  int    type     - gewünschter Ordertyp
 * @param  double lots     - gewünschtes Ordervolumen
 * @param  double price    - gewünschter Orderpreis
 * @param  int    digits   - Nachkommastellen des Ordersymbols
 * @param  int    time     - zur Orderausführung benötigte Zeit
 * @param  int    requotes - Anzahl der aufgetretenen Requotes
 *
 * @return string - Logmessage
 */
/*private*/ string OrderSendEx.LogMessage(int ticket, int type, double lots, double price, int digits, int time, int requotes) {
   int    pipDigits   = digits & (~1);
   double pip         = 1/MathPow(10, pipDigits);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   // Das Ticket ist bereits selektiert
   string strType = OperationTypeDescription(OrderType());
   if (type != OrderType())
      strType = StringConcatenate(strType, " (instead of ", OperationTypeDescription(type), ")");

   string strLots = NumberToStr(OrderLots(), ".+");
   if (NE(lots, OrderLots()))
      strLots = StringConcatenate(strLots, " (instead of ", NumberToStr(lots, ".+"), ")");

   string strPrice    = NumberToStr(OrderOpenPrice(), priceFormat);
   string strSlippage = "";
   if (type == OrderType()) {
      if (NE(price, OrderOpenPrice())) {
         strPrice = StringConcatenate(strPrice, " (instead of ", NumberToStr(price, priceFormat), ")");
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
            strSlippage = NumberToStr(MathAbs(OrderOpenPrice()-price)/pip, ".+");
            int plus    = GT(OrderOpenPrice(), price);
            if (OrderType() == plus^1) strSlippage = StringConcatenate(" (", strSlippage, " pip slippage)");
            else                       strSlippage = StringConcatenate(" (", strSlippage, " pip positive slippage)");
         }
      }
   }

   string message = StringConcatenate("#", ticket, " ", strType, " ", strLots, " ", OrderSymbol(), " at ", strPrice);
   if (NE(OrderStopLoss(), 0))        message = StringConcatenate(message, ", sl=", NumberToStr(OrderStopLoss(), priceFormat));
   if (StringLen(OrderComment()) > 0) message = StringConcatenate(message, ", comment=\"", OrderComment(), "\"");
                                      message = StringConcatenate(message, " after ", DoubleToStr(time/1000.0, 3), " s");
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }

   message = StringConcatenate(message, strSlippage);

   int error = GetLastError();
   if (IsError(error))
      return(_empty(catch("OrderSendEx.LogMessage(2)", error)));
   return(message);
}


/**
 * Korrigiert die vom Terminal beim Ausführen von OrderSend() gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderSent_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderSent_A(int ticket, int digits, color markerColor) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   if (!OrderSelectByTicket(ticket, "ChartMarker.OrderSent_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderSent_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderComment());

   return(ifBool(OrderPop("ChartMarker.OrderSent_A(2)"), result, false));
}


/**
 * Korrigiert die vom Terminal beim Ausführen von OrderSend() gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket braucht während der Ausführung nicht selektierbar zu sein.
 *
 * @param  int      ticket      - Ticket
 * @param  int      digits      - Nachkommastellen des Ordersymbols
 * @param  color    markerColor - Farbe des Chartmarkers
 * @param  int      type        - Ordertyp
 * @param  double   lots        - Lotsize
 * @param  string   symbol      - OrderSymbol
 * @param  datetime openTime    - OrderOpenTime
 * @param  double   openPrice   - OrderOpenPrice
 * @param  double   stopLoss    - StopLoss
 * @param  double   takeProfit  - TakeProfit
 * @param  string   comment     - OrderComment
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderSent_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   static string types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: setzen, korrigieren oder löschen                               // "#1 buy[ stop] 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(openPrice, digits));
   if (ObjectFind(label1) == 0) {
      if (markerColor == CLR_NONE) ObjectDelete(label1);                               // löschen
      else                         ObjectSet(label1, OBJPROP_COLOR, markerColor);      // korrigieren
   }
   else if (markerColor != CLR_NONE) {
      if (ObjectCreate(label1, OBJ_ARROW, 0, openTime, openPrice)) {                   // setzen
         ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label1, OBJPROP_COLOR    , markerColor     );
         ObjectSetText(label1, comment);
      }
   }

   // StopLoss-Marker: immer löschen                                                   // "#1 buy[ stop] 0.10 GBPUSD at 1.52904 stop loss at 1.52784"
   if (NE(stopLoss, 0)) {
      string label2 = StringConcatenate(label1, " stop loss at ", DoubleToStr(stopLoss, digits));
      if (ObjectFind(label2) == 0)
         ObjectDelete(label2);
   }

   // TakeProfit-Marker: immer löschen                                                 // "#1 buy[ stop] 0.10 GBPUSD at 1.52904 take profit at 1.58000"
   if (NE(takeProfit, 0)) {
      string label3 = StringConcatenate(label1, " take profit at ", DoubleToStr(takeProfit, digits));
      if (ObjectFind(label3) == 0)
         ObjectDelete(label3);
   }

   return(IsNoError(catch("ChartMarker.OrderSent_B()")));
}


/**
 * Drop-in-Ersatz für und erweiterte Version von OrderModify(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  int      ticket      - zu änderndes Ticket
 * @param  double   openPrice   - OpenPrice (nur bei Pending-Orders)
 * @param  double   stopLoss    - StopLoss-Level
 * @param  double   takeProfit  - TakeProfit-Level
 * @param  datetime expires     - Gültigkeit (nur bei Pending-Orders)
 * @param  color    markerColor - Farbe des Chart-Markers
 * @param  int      execFlags   - die Ausführung steuernde Flags
 * @param  double   execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Elemente des Parameters execution[] (out)
 * -----------------------------------------
 * - EXEC_TIME      : Zeitpunkt der Orderausführung
 * - EXEC_PRICE     : immer 0
 * - EXEC_SWAP      : immer 0
 * - EXEC_COMMISSION: immer 0
 * - EXEC_PROFIT    : immer 0
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden
 * - EXEC_REQUOTES  : immer 0
 * - EXEC_SLIPPAGE  : immer 0
 * - EXEC_TICKET    : immer 0
 */
bool OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int execFlags, double& execution[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelectByTicket(ticket, "OrderModifyEx(1)", O_PUSH)) return(false);
   if (!IsTradeOperation(OrderType()))                           return(_false(catch("OrderModifyEx(2)   #"+ ticket +" is not an order ticket", ERR_INVALID_TICKET, O_POP)));
   if (OrderCloseTime() != 0)                                    return(_false(catch("OrderModifyEx(3)   #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP)));
   int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   int error = GetLastError();
   if (IsError(error))                                           return(_false(catch("OrderModifyEx(4)   symbol=\""+ OrderSymbol() +"\"", error, O_POP)));
   // openPrice
   openPrice = NormalizeDouble(openPrice, digits);
   if (LE(openPrice, 0))                                         return(_false(catch("OrderModifyEx(5)   illegal parameter openPrice = "+ NumberToStr(openPrice, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   if (NE(openPrice, OrderOpenPrice())) {
      if (!IsPendingTradeOperation(OrderType()))                 return(_false(catch("OrderModifyEx(6)   cannot modify open price of already open position #"+ ticket, ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
      // TODO: Bid/Ask <=> openPrice prüfen
      // TODO: StopDistance(openPrice) prüfen
   }
   // stopLoss
   stopLoss = NormalizeDouble(stopLoss, digits);
   if (LT(stopLoss, 0))                                          return(_false(catch("OrderModifyEx(7)   illegal parameter stopLoss = "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   if (NE(stopLoss, OrderStopLoss())) {
      // TODO: Bid/Ask <=> stopLoss prüfen
      // TODO: StopDistance(stopLoss) prüfen
   }
   // takeProfit
   takeProfit = NormalizeDouble(takeProfit, digits);
   if (LT(takeProfit, 0))                                        return(_false(catch("OrderModifyEx(8)   illegal parameter takeProfit = "+ NumberToStr(takeProfit, priceFormat), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   if (NE(takeProfit, OrderTakeProfit())) {
      // TODO: Bid/Ask <=> takeProfit prüfen
      // TODO: StopDistance(takeProfit) prüfen
   }
   // expires
   if (expires!=0) /*&&*/ if (expires <= TimeCurrent())          return(_false(catch("OrderModifyEx(9)   illegal parameter expires = "+ ifString(expires < 0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   if (expires != OrderExpiration())
      if (!IsPendingTradeOperation(OrderType()))                 return(_false(catch("OrderModifyEx(10)   cannot modify expiration of already open position #"+ ticket, ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')   return(_false(catch("OrderModifyEx(11)   illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // execution
   if (ArraySize(execution) != 9)
      ArrayResize(execution, 9);
   // -- Ende Parametervalidierung --

   double oldOpenPrice=OrderOpenPrice(), oldStopLoss=OrderStopLoss(), oldTakeprofit=OrderTakeProfit();

   int      time1, time2, firstTime1;
   datetime modifyTime;

   // Endlosschleife, bis Order geändert wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      error = NO_ERROR;

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderModifyEx()   trade context busy, retrying...");
         Sleep(300);                                                    // 0.3 Sekunden warten
      }
      else {
         time1      = GetTickCount();
         modifyTime = TimeCurrent();
         if (firstTime1 == 0)                                           // Zeit der ersten Ausführung
            firstTime1 = time1;

         bool success = OrderModify(ticket, openPrice, stopLoss, takeProfit, expires, markerColor);
         time2 = GetTickCount();

         if (success) {
            WaitForTicket(ticket, false);                               // wartet und re-selektiert (FALSE)
            // TODO: WaitForChanges() implementieren

            if (!ChartMarker.OrderModified_A(ticket, digits, markerColor, TimeCurrent(), oldOpenPrice, oldStopLoss, oldTakeprofit))
               return(_false(OrderPop("OrderModifyEx(12)")));

            // Execution-Struktur füllen
            execution[EXEC_TIME      ] = modifyTime;
            execution[EXEC_PRICE     ] = 0;
            execution[EXEC_SWAP      ] = 0;
            execution[EXEC_COMMISSION] = 0;
            execution[EXEC_PROFIT    ] = 0;
            execution[EXEC_DURATION  ] = (time2-firstTime1)/1000.0;     // in Sekunden
            execution[EXEC_REQUOTES  ] = 0;
            execution[EXEC_SLIPPAGE  ] = 0;
            execution[EXEC_TICKET    ] = 0;

            //if (__LOG) log("OrderModifyEx()   "+ OrderModifyEx.LogMessage(ticket, digits, time2-time1));    // TODO: OrderModifyEx.LogMessage() implementieren
            if (!IsTesting())
               PlaySound("RFQ.wav");

            return(IsNoError(catch("OrderModifyEx(13)", NULL, O_POP))); // regular exit
         }
         error = GetLastError();
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                             // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;

         warn(StringConcatenate("OrderModifyEx()   temporary trade error after ", DoubleToStr((time2-time1)/1000.0, 3), " s, retrying..."), error);
      }
   }

   return(_false(catch("OrderModifyEx(14)   permanent trade error after "+ DoubleToStr((time2-time1)/1000.0, 3) +" s", error, O_POP)));
}


/**
 * Korrigiert die vom Terminal beim Modifizieren einer Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int      ticket        - Ticket
 * @param  int      digits        - Nachkommastellen des Ordersymbols
 * @param  color    markerColor   - Farbe des Chartmarkers
 * @param  datetime modifyTime    - OrderModifyTime
 * @param  double   oldOpenPrice  - ursprünglicher OrderOpenPrice
 * @param  double   oldStopLoss   - ursprünglicher StopLoss
 * @param  double   oldTakeProfit - ursprünglicher TakeProfit
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderModified_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeprofit) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   if (!OrderSelectByTicket(ticket, "ChartMarker.OrderModified_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderModified_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), modifyTime, oldOpenPrice, OrderOpenPrice(), oldStopLoss, OrderStopLoss(), oldTakeprofit, OrderTakeProfit(), OrderComment());

   return(ifBool(OrderPop("ChartMarker.OrderModified_A(2)"), result, false));
}


/**
 * Korrigiert die vom Terminal beim Modifizieren einer Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket braucht während der Ausführung nicht selektierbar zu sein.
 *
 * @param  int      ticket        - Ticket
 * @param  int      digits        - Nachkommastellen des Ordersymbols
 * @param  color    markerColor   - Farbe des Chartmarkers
 * @param  int      type          - Ordertyp
 * @param  double   lots          - Lotsize
 * @param  string   symbol        - OrderSymbol
 * @param  datetime openTime      - OrderOpenTime
 * @param  datetime modifyTime    - OrderModifyTime
 * @param  double   oldOpenPrice  - ursprünglicher OrderOpenPrice
 * @param  double   openPrice     - aktueller OrderOpenPrice
 * @param  double   oldStopLoss   - ursprünglicher StopLoss
 * @param  double   stopLoss      - aktueller StopLoss
 * @param  double   oldTakeProfit - ursprünglicher TakeProfit
 * @param  double   takeProfit    - aktueller TakeProfit
 * @param  string   comment       - OrderComment
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderModified_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   bool openModified = NE(openPrice,  oldOpenPrice );
   bool slModified   = NE(stopLoss,   oldStopLoss  );
   bool tpModified   = NE(takeProfit, oldTakeProfit);

   static string label, types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: setzen, korrigieren oder löschen                               // "#1 buy[ stop] 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " ", symbol, " at ");
   if (openModified) {
      label = StringConcatenate(label1, DoubleToStr(oldOpenPrice, digits));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // alten Open-Marker löschen
      label = StringConcatenate("#", ticket, " ", types[type], " modified ", TimeToStr(modifyTime-60*SECONDS));
      if (ObjectFind(label) == 0)                                                      // #1 buy stop modified 2012.03.12 03:06
         ObjectDelete(label);                                                          // Modify-Marker löschen, wenn er auf der vorherigen Minute liegt
      label = StringConcatenate("#", ticket, " ", types[type], " modified ", TimeToStr(modifyTime));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // Modify-Marker löschen, wenn er auf der aktuellen Minute liegt
   }
   label = StringConcatenate(label1, DoubleToStr(openPrice, digits));
   if (ObjectFind(label) == 0) {
      if (markerColor == CLR_NONE) ObjectDelete(label);                                // neuen Open-Marker löschen
      else {
         if (openModified)
            ObjectSet(label, OBJPROP_TIME1, modifyTime);
         ObjectSet(label, OBJPROP_COLOR, markerColor);                                 // neuen Open-Marker korrigieren
      }
   }
   else if (markerColor != CLR_NONE) {                                                 // neuen Open-Marker setzen
      if (ObjectCreate(label, OBJ_ARROW, 0, ifInt(openModified, modifyTime, openTime), openPrice)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR    , markerColor     );
         ObjectSetText(label, comment);
      }
   }

   // StopLoss-Marker: immer löschen                                                   // "#1 buy[ stop] 0.10 GBPUSD at 1.52904 stop loss at 1.52784"
   if (NE(oldStopLoss, 0)) {
      label = StringConcatenate(label1, DoubleToStr(oldOpenPrice, digits), " stop loss at ", DoubleToStr(oldStopLoss, digits));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // alten löschen
   }
   if (slModified) {                                                                   // #1 sl modified 2012.03.12 03:06
      label = StringConcatenate("#", ticket, " sl modified ", TimeToStr(modifyTime-60*SECONDS));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // neuen löschen, wenn er auf der vorherigen Minute liegt
      label = StringConcatenate("#", ticket, " sl modified ", TimeToStr(modifyTime));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // neuen löschen, wenn er auf der aktuellen Minute liegt
   }

   // TakeProfit-Marker: immer löschen                                                 // "#1 buy[ stop] 0.10 GBPUSD at 1.52904 take profit at 1.58000"
   if (NE(oldTakeProfit, 0)) {
      label = StringConcatenate(label1, DoubleToStr(oldOpenPrice, digits), " take profit at ", DoubleToStr(oldTakeProfit, digits));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // alten löschen
   }
   if (tpModified) {                                                                   // #1 tp modified 2012.03.12 03:06
      label = StringConcatenate("#", ticket, " tp modified ", TimeToStr(modifyTime-60*SECONDS));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // neuen löschen, wenn er auf der vorherigen Minute liegt
      label = StringConcatenate("#", ticket, " tp modified ", TimeToStr(modifyTime));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);                                                          // neuen löschen, wenn er auf der aktuellen Minute liegt
   }

   return(IsNoError(catch("ChartMarker.OrderModified_B()")));
}


/**
 * Korrigiert die vom Terminal beim Ausführen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int    ticket       - Ticket
 * @param  int    pendingType  - OrderType der Pending-Order
 * @param  double pendingPrice - OpenPrice der Pending-Order
 * @param  int    digits       - Nachkommastellen des Ordersymbols
 * @param  color  markerColor  - Farbe des Chartmarkers
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderFilled_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   if (!OrderSelectByTicket(ticket, "ChartMarker.OrderFilled_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderFilled_B(ticket, pendingType, pendingPrice, digits, markerColor, OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderComment());

   return(ifBool(OrderPop("ChartMarker.OrderFilled_A(2)"), result, false));
}


/**
 * Korrigiert die vom Terminal beim Ausführen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket braucht während der Ausführung nicht selektierbar zu sein.
 *
 * @param  int      ticket       - Ticket
 * @param  int      pendingType  - Pending-OrderType
 * @param  double   pendingPrice - Pending-OrderOpenPrice
 * @param  int      digits       - Nachkommastellen des Ordersymbols
 * @param  color    markerColor  - Farbe des Chartmarkers
 * @param  double   lots         - Lotsize
 * @param  string   symbol       - OrderSymbol
 * @param  datetime openTime     - OrderOpenTime
 * @param  double   openPrice    - OrderOpenPrice
 * @param  string   comment      - OrderComment
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderFilled_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   static string types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: immer löschen                                                  // "#1 buy stop 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[pendingType], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(pendingPrice, digits));
   if (ObjectFind(label1) == 0)
      ObjectDelete(label1);

   // Trendlinie: immer löschen                                                        // "#1 1.52904 -> 1.52904"
   string label2 = StringConcatenate("#", ticket, " ", DoubleToStr(pendingPrice, digits), " -> ", DoubleToStr(openPrice, digits));
   if (ObjectFind(label2) == 0)
      ObjectDelete(label2);

   // OrderFill-Marker: immer löschen                                                  // "#1 buy stop 0.10 GBPUSD at 1.52904 buy[ by tester] at 1.52904"
   string label3 = StringConcatenate(label1, " ", types[ifInt(IsLongTradeOperation(pendingType), OP_BUY, OP_SELL)], ifString(IsTesting(), " by tester", ""), " at ", DoubleToStr(openPrice, digits));
   if (ObjectFind(label3) == 0)
         ObjectDelete(label3);                                                         // löschen

   // neuen OrderFill-Marker: setzen, korrigieren oder löschen                         // "#1 buy 0.10 GBPUSD at 1.52904"
   string label4 = StringConcatenate("#", ticket, " ", types[ifInt(IsLongTradeOperation(pendingType), OP_BUY, OP_SELL)], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(openPrice, digits));
   if (ObjectFind(label4) == 0) {
      if (markerColor == CLR_NONE) ObjectDelete(label4);                               // löschen
      else                         ObjectSet(label4, OBJPROP_COLOR, markerColor);      // korrigieren
   }
   else if (markerColor != CLR_NONE) {
      if (ObjectCreate(label4, OBJ_ARROW, 0, openTime, openPrice)) {                   // setzen
         ObjectSet(label4, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label4, OBJPROP_COLOR    , markerColor     );
         ObjectSetText(label4, comment);
      }
   }

   return(IsNoError(catch("ChartMarker.OrderFilled_B()")));
}


/**
 * Korrigiert die vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   if (!OrderSelectByTicket(ticket, "ChartMarker.PositionClosed_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.PositionClosed_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice());

   return(ifBool(OrderPop("ChartMarker.PositionClosed_A(2)"), result, false));
}


/**
 * Korrigiert die vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket braucht während der Ausführung nicht selektierbar zu sein.
 *
 * @param  int      ticket      - Ticket
 * @param  int      digits      - Nachkommastellen des Ordersymbols
 * @param  color    markerColor - Farbe des Chartmarkers
 * @param  int      type        - OrderType
 * @param  double   lots        - Lotsize
 * @param  string   symbol      - OrderSymbol
 * @param  datetime openTime    - OrderOpenTime
 * @param  double   openPrice   - OrderOpenPrice
 * @param  datetime closeTime   - OrderCloseTime
 * @param  double   closePrice  - OrderClosePrice
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   static string types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: ggf. löschen                                                   // "#1 buy 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(openPrice, digits));
   if (markerColor == CLR_NONE) {
      if (ObjectFind(label1) == 0)
         ObjectDelete(label1);                                                         // löschen
   }

   // Trendlinie: setzen oder löschen                                                  // "#1 1.53024 -> 1.52904"
   string label2 = StringConcatenate("#", ticket, " ", DoubleToStr(openPrice, digits), " -> ", DoubleToStr(closePrice, digits));
   if (ObjectFind(label2) == 0) {
      if (markerColor == CLR_NONE)
         ObjectDelete(label2);                                                         // löschen
   }
   else if (markerColor != CLR_NONE) {                                                 // setzen
      if (ObjectCreate(label2, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(label2, OBJPROP_RAY  , false    );
         ObjectSet(label2, OBJPROP_STYLE, STYLE_DOT);
         ObjectSet(label2, OBJPROP_COLOR, ifInt(type==OP_BUY, Blue, Red));
         ObjectSet(label2, OBJPROP_BACK , true);
      }
   }

   // Close-Marker: setzen, korrigieren oder löschen                                   // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
   string label3 = StringConcatenate(label1, " close", ifString(IsTesting(), " by tester", ""), " at ", DoubleToStr(closePrice, digits));
   if (ObjectFind(label3) == 0) {
      if (markerColor == CLR_NONE) ObjectDelete(label3);                               // löschen
      else                         ObjectSet(label3, OBJPROP_COLOR, markerColor);      // korrigieren
   }
   else if (markerColor != CLR_NONE) {
      if (ObjectCreate(label3, OBJ_ARROW, 0, closeTime, closePrice)) {                 // setzen
         ObjectSet(label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(label3, OBJPROP_COLOR    , markerColor      );
      }
   }

   return(IsNoError(catch("ChartMarker.PositionClosed_B()")));
}


/**
 * Korrigiert die vom Terminal beim Löschen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderDeleted_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   if (!OrderSelectByTicket(ticket, "ChartMarker.OrderDeleted_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderDeleted_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice());

   return(ifBool(OrderPop("ChartMarker.OrderDeleted_A(2)"), result, false));
}


/**
 * Korrigiert die vom Terminal beim Löschen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket braucht während der Ausführung nicht selektierbar zu sein.
 *
 * @param  int      ticket      - Ticket
 * @param  int      digits      - Nachkommastellen des Ordersymbols
 * @param  color    markerColor - Farbe des Chartmarkers
 * @param  int      type        - Ordertyp
 * @param  double   lots        - Lotsize
 * @param  string   symbol      - OrderSymbol
 * @param  datetime openTime    - OrderOpenTime
 * @param  double   openPrice   - OrderOpenPrice
 * @param  datetime closeTime   - OrderCloseTime
 * @param  double   closePrice  - OrderClosePrice
 *
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderDeleted_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   static string types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: ggf. löschen                                                   // "#1 buy stop 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(openPrice, digits));
   if (markerColor == CLR_NONE) {
      if (ObjectFind(label1) == 0)
         ObjectDelete(label1);
   }

   // Trendlinie: setzen oder löschen                                                  // "#1 delete"
   string label2 = StringConcatenate("#", ticket, " delete");
   if (ObjectFind(label2) == 0) {
      if (markerColor == CLR_NONE)
         ObjectDelete(label2);                                                         // löschen
   }
   else if (markerColor != CLR_NONE) {                                                 // setzen
      if (ObjectCreate(label2, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(label2, OBJPROP_RAY  , false    );
         ObjectSet(label2, OBJPROP_STYLE, STYLE_DOT);
         ObjectSet(label2, OBJPROP_COLOR, ifInt(IsLongTradeOperation(type), Blue, Red));
         ObjectSet(label2, OBJPROP_BACK , true);
      }
   }

   // OrderClose-Marker: setzen, korrigieren oder löschen                              // "#1 buy stop 0.10 GBPUSD at 1.52904 deleted"
   string label3 = StringConcatenate(label1, " deleted");
   if (ObjectFind(label3) == 0) {
      if (markerColor == CLR_NONE) ObjectDelete(label3);                               // löschen
      else                         ObjectSet(label3, OBJPROP_COLOR, markerColor);      // korrigieren
   }
   else if (markerColor != CLR_NONE) {
      if (ObjectCreate(label3, OBJ_ARROW, 0, closeTime, closePrice)) {                 // setzen
         ObjectSet(label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(label3, OBJPROP_COLOR    , markerColor      );
      }
   }

   return(IsNoError(catch("ChartMarker.OrderDeleted_B()")));
}


/**
 * Drop-in-Ersatz für und erweiterte Version von OrderClose(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  int    ticket      - Ticket der zu schließenden Position
 * @param  double lots        - zu schließendes Volumen in Lots (default: komplette Position)
 * @param  double price       - Preis                           (wird zur Zeit ignoriert    )
 * @param  double slippage    - akzeptable Slippage in Pips     (default: 0                 )
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Elemente des Parameters execution[] (out)
 * -----------------------------------------
 * - EXEC_TIME      : OrderCloseTime
 * - EXEC_PRICE     : OrderClosePrice
 * - EXEC_SWAP      : realisierter Swap der geschlossenen (Teil-)Position (1)
 * - EXEC_COMMISSION: realisierte Commission der geschlossenen (Teil-)Position (1)
 * - EXEC_PROFIT    : realisierter Profit der geschlossenen (Teil-)Position (1)
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden
 * - EXEC_REQUOTES  : Anzahl der aufgetretenen Requotes
 * - EXEC_SLIPPAGE  : Slippage der Orderausführung in Pips (positiv: zu ungunsten; negativ: zu gunsten)
 * - EXEC_TICKET    : Ticket einer verbleibenden Restposition (nur bei partiellem Close)
 *
 * 1) vom MT4-Server berechnet, kann bei partiellem Close vom theoretischen Wert abweichen
 */
bool OrderCloseEx(int ticket, double lots/*=0*/, double price/*=0*/, double slippage/*=0*/, color markerColor, int execFlags, double& execution[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelectByTicket(ticket, "OrderCloseEx(1)", O_PUSH)) return(false);
   if (OrderCloseTime() != 0)                                   return(_false(catch("OrderCloseEx(2)   #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP)));
   if (OrderType() > OP_SELL)                                   return(_false(catch("OrderCloseEx(3)   #"+ ticket +" is not an open position", ERR_INVALID_TICKET, O_POP)));
   // lots
   int    digits   = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double minLot   = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep  = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   double openLots = OrderLots();
   int error = GetLastError();
   if (IsError(error))                                          return(_false(catch("OrderCloseEx(4)   symbol=\""+ OrderSymbol() +"\"", error, O_POP)));
   if (EQ(lots, 0)) {
      lots = openLots;
   }
   else if (NE(lots, openLots)) {
      if (LT(lots, minLot))                                     return(_false(catch("OrderCloseEx(5)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
      if (GT(lots, openLots))                                   return(_false(catch("OrderCloseEx(6)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (OpenLots="+ NumberToStr(openLots, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
      if (NE(MathModFix(lots, lotStep), 0))                     return(_false(catch("OrderCloseEx(7)   illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   }
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0))                                            return(_false(catch("OrderCloseEx(8)   illegal parameter price = "+ NumberToStr(price, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // slippage
   if (LT(slippage, 0))                                         return(_false(catch("OrderCloseEx(9)   illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')  return(_false(catch("OrderCloseEx(10)   illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // execution
   if (ArraySize(execution) != 9)
      ArrayResize(execution, 9);
   // -- Ende Parametervalidierung --

   /*
   Vollständiges Close
   ===================
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+
   |               | Ticket | Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission | Profit | MagicNumber | Comment         |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+
   | open          |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3207'9 | -0.80 |      -8.00 |   0.00 |         666 | order comment   |
   | closed        |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 12:00:05 |   1.3215'9 | -0.80 |      -8.00 |  64.00 |         666 | order comment   |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+

   Partielles Close
   ================
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+-----------------+
   |               | Ticket | Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission | Profit | MagicNumber | Comment(Online) | Comment(Tester) |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+-----------------+
   | open          |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3207'9 | -0.80 |      -8.00 |  64.00 |         666 | order comment   | order comment   |
   | partial close |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 12:00:05 |   1.3215'9 | -0.56 |      -5.60 |  44.80 |         666 | to #2           | partial close   |
   | remainder     |     #2 |  Buy | 0.30 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3215'9 | -0.24 |      -2.40 |  19.20 |         666 | from #1         | split from #1   |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+-----------------+
   | close         |     #2 |  Buy | 0.30 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 13:00:05 |   1.3245'7 | -0.24 |      -2.40 | 108.60 |         666 | from #1         | split from #1   |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+-----------------+-----------------+
    - OpenTime, OpenPrice und MagicNumber der Restposition entsprechen den Werten der Ausgangsposition.
    - Swap, Commission und Profit werden anteilig auf geschlossene Teil- und Restposition verteilt.
   */

   int    pipDigits      = digits & (~1);
   int    pipPoints      = Round(MathPow(10, digits-pipDigits));
   double pip            =     1/MathPow(10, pipDigits), pips=pip;
   int    slippagePoints = Round(slippage * pipPoints);
   string priceFormat    = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   int    time1, time2, firstTime1, requotes, remainder;
   double firstPrice;                                                                        // erster OrderPrice (falls ERR_REQUOTE auftritt)
   bool   success;


   // Endlosschleife, bis Position geschlossen wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      error = NO_ERROR;

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderCloseEx()   trade context busy, retrying...");
      }
      else {
         if      (OrderType() == OP_BUY ) price = MarketInfo(OrderSymbol(), MODE_BID);
         else if (OrderType() == OP_SELL) price = MarketInfo(OrderSymbol(), MODE_ASK);
         price = NormalizeDouble(price, digits);

         time1 = GetTickCount();
         if (firstTime1 == 0) {
            firstTime1 = time1;
            firstPrice = price;                                                              // OrderPrice und Zeit der ersten Ausführung merken
         }
         success = OrderClose(ticket, lots, price, slippagePoints, markerColor);
         time2   = GetTickCount();

         if (success) {
            WaitForTicket(ticket, false);                                                    // wartet und re-selektiert (FALSE)

            if (!ChartMarker.PositionClosed_A(ticket, digits, markerColor))
               return(_false(OrderPop("OrderCloseEx(11)")));

            // Execution-Struktur füllen
            execution[EXEC_TIME      ] = OrderCloseTime();
            execution[EXEC_PRICE     ] = OrderClosePrice();
            execution[EXEC_SWAP      ] = OrderSwap();
            execution[EXEC_COMMISSION] = OrderCommission();
            execution[EXEC_PROFIT    ] = OrderProfit();
            execution[EXEC_DURATION  ] = (time2-firstTime1)/1000.0;                          // in Sekunden
            execution[EXEC_REQUOTES  ] = requotes;                                           // Anzahl
               if      (OrderType() == OP_BUY ) slippage = firstPrice - OrderClosePrice();
               else if (OrderType() == OP_SELL) slippage = OrderClosePrice() - firstPrice;
            execution[EXEC_SLIPPAGE  ] = NormalizeDouble(slippage/pips, 1);                  // in Pips
            execution[EXEC_TICKET    ] = 0;

            // Restposition finden
            if (NE(lots, openLots)) {
               string strValue, strValue2;
               if (IsTesting()) /*&&*/ if (!StringIStartsWith(OrderComment(), "to #")) {     // Fall-Back zum Serververhalten, falls der Unterschied in späteren Terminalversionen behoben ist.
                  // Der Tester überschreibt den OrderComment statt mit "to #2" mit "partial close".
                  if (OrderComment() != "partial close")             return(_false(catch("OrderCloseEx(12)   unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP)));
                  strValue  = StringConcatenate("split from #", ticket);
                  strValue2 = StringConcatenate(      "from #", ticket);

                  OrderPush("OrderCloseEx(13)");
                  for (int i=OrdersTotal()-1; i >= 0; i--) {
                     if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                      // FALSE: darf im Tester nicht auftreten
                        catch("OrderCloseEx(14) ->OrderSelect(i="+ i +", SELECT_BY_POS, MODE_TRADES)   unexpectedly returned FALSE", ERR_RUNTIME_ERROR);
                        break;
                     }
                     if (OrderTicket() == ticket)        continue;
                     if (OrderComment() != strValue)
                        if (OrderComment() != strValue2) continue;                           // falls der Unterschied in späteren Terminalversionen behoben ist
                     if (NE(lots+OrderLots(), openLots)) continue;

                     remainder = OrderTicket();
                     break;
                  }
                  OrderPop("OrderCloseEx(15)");
                  if (remainder == 0) {
                     if (IsLastError())                              return(_false(OrderPop("OrderCloseEx(16)")));
                                                                     return(_false(catch("OrderCloseEx(17)   cannot find remaining position of partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots)", ERR_RUNTIME_ERROR, O_POP)));
                  }
               }
               if (remainder == 0) {
                  if (!StringIStartsWith(OrderComment(), "to #"))    return(_false(catch("OrderCloseEx(18)   unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP)));
                  strValue = StringRight(OrderComment(), -4);
                  if (!StringIsDigit(strValue))                      return(_false(catch("OrderCloseEx(19)   unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP)));
                  remainder = StrToInteger(strValue);
                  if (remainder == 0)                                return(_false(catch("OrderCloseEx(20)   unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP)));
               }
               WaitForTicket(remainder, true);
               execution[EXEC_TICKET] = remainder;
            }

            if (__LOG) log("OrderCloseEx()   "+ OrderCloseEx.LogMessage(ticket, lots, firstPrice, digits, time2-firstTime1, requotes));
            if (!IsTesting())
               PlaySound(ifString(requotes==0, "OrderOk.wav", "Blip.wav"));

            return(IsNoError(catch("OrderCloseEx(21)", NULL, O_POP)));                       // regular exit
         }

         error = GetLastError();
         if (error == ERR_REQUOTE) {
            requotes++;
            if (IsTesting())
               break;
            continue;                                                                        // nach ERR_REQUOTE Order schnellstmöglich wiederholen
         }
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                                                  // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;
                                                                                             // nach Fertigstellung durch log() ersetzen
         warn(StringConcatenate("OrderCloseEx()   temporary trade error after ", DoubleToStr((time2-firstTime1)/1000.0, 3), " s", ifString(requotes==0, "", StringConcatenate(" and ", requotes, " requote", ifString(requotes==1, "", "s"))), ", retrying..."), error);
      }
      Sleep(300);                                                                            // 0.3 Sekunden warten
   }
   return(_false(catch("OrderCloseEx(23)   permanent trade error after "+ DoubleToStr((time2-firstTime1)/1000.0, 3) +" s"+ ifString(requotes==0, "", " and "+ requotes +" requote"+ ifString(requotes==1, "", "s")), error, O_POP)));
}


/**
 *
 */
/*private*/ string OrderCloseEx.LogMessage(int ticket, double lots, double price, int digits, int time, int requotes) {
   int    pipDigits   = digits & (~1);
   double pip         = 1/MathPow(10, pipDigits);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   // Ticket ist hier immer selektiert
   // TODO: Logmessage bei partiellem Close anpassen (geschlossenes Volumen, verbleibendes Ticket)

   string strType = OperationTypeDescription(OrderType());
   string strLots = NumberToStr(OrderLots(), ".+");

   string strPrice    = NumberToStr(OrderClosePrice(), priceFormat);
   string strSlippage = "";
   if (NE(price, OrderClosePrice())) {
      strPrice    = StringConcatenate(strPrice, " (instead of ", NumberToStr(price, priceFormat), ")");
      strSlippage = NumberToStr(MathAbs(OrderClosePrice()-price)/pip, ".+");
      int plus    = GT(OrderClosePrice(), price);
      if ((OrderType() == plus)) strSlippage = StringConcatenate(" (", strSlippage, " pip slippage)");
      else                       strSlippage = StringConcatenate(" (", strSlippage, " pip positive slippage)");
   }

   string message = StringConcatenate("closed #", ticket, " ", strType, " ", strLots, " ", OrderSymbol(), " at ", strPrice, " after ", DoubleToStr(time/1000.0, 3), " s");

   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }

   message = StringConcatenate(message, strSlippage);

   int error = GetLastError();
   if (IsError(error))
      return(_empty(catch("OrderCloseEx.LogMessage(2)", error)));
   return(message);
}


/**
 * Drop-in-Ersatz für und erweiterte Version von OrderCloseBy(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  int    ticket      - Ticket der zu schließenden Position
 * @param  int    opposite    - Ticket der zum Schließen zu verwendenden Gegenposition
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Elemente des Parameters execution[] (out)
 * -----------------------------------------
 * - EXEC_TIME      : effektiver Zeitpunkt, zu dem die (Teil-)Position geschlossen wurde
 * - EXEC_PRICE     : effektiver Preis, zu dem die (Teil-)Position geschlossen wurde
 * - EXEC_SWAP      : realisierter OrderSwap der geschlossenen (Teil-)Position (1)
 * - EXEC_COMMISSION: realisierte OrderCommission der geschlossenen (Teil-)Position (1)
 * - EXEC_PROFIT    : realisierter OrderProfit der geschlossenen (Teil-)Position (1)
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden
 * - EXEC_REQUOTES  : immer 0
 * - EXEC_SLIPPAGE  : immer 0
 * - EXEC_TICKET    : Ticket einer verbleibenden Restposition (bei partiellem Close)
 *
 * (1) vom MT4-Server berechnet, bei partiellem Close aufgeteilt (kann vom tatsächlichen Wert abweichen)
 */
bool OrderCloseByEx(int ticket, int opposite, color markerColor, int execFlags, double& execution[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelectByTicket(ticket, "OrderCloseByEx(1)", O_PUSH))        return(false);
   if (OrderCloseTime() != 0)                                            return(_false(catch("OrderCloseByEx(2)   #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP)));
   if (OrderType() > OP_SELL)                                            return(_false(catch("OrderCloseByEx(3)   #"+ ticket +" is not an open position", ERR_INVALID_TICKET, O_POP)));
   int      ticketType     = OrderType();
   double   ticketLots     = OrderLots();
   datetime ticketOpenTime = OrderOpenTime();
   string   symbol         = OrderSymbol();
   // opposite
   if (!OrderSelectByTicket(opposite, "OrderCloseByEx(4)", NULL, O_POP)) return(false);
   if (OrderCloseTime() != 0)                                            return(_false(catch("OrderCloseByEx(5)   opposite #"+ opposite +" is already closed", ERR_INVALID_TICKET, O_POP)));
   int      oppositeType     = OrderType();
   double   oppositeLots     = OrderLots();
   datetime oppositeOpenTime = OrderOpenTime();
   if (ticketType != oppositeType^1)                                     return(_false(catch("OrderCloseByEx(6)   #"+ opposite +" is not opposite to #"+ ticket, ERR_INVALID_TICKET, O_POP)));
   if (symbol != OrderSymbol())                                          return(_false(catch("OrderCloseByEx(7)   #"+ opposite +" is not opposite to #"+ ticket, ERR_INVALID_TICKET, O_POP)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')           return(_false(catch("OrderCloseByEx(8)   illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // execution
   ArrayResize(execution, 0);
   ArrayResize(execution, 9);                                        // Re-Initialisierung
   // -- Ende Parametervalidierung --

   /*
   Vollständiges Close
   ===================
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
   |           | Ticket | Type | Lots | Symbol |                OpenTime | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission |  Profit | MagicNumber | Comment           |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
   | open      |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 |                     |   1.3237'4 | -0.80 |      -8.00 |  714.00 |         111 |                   |
   | open      |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 |                     |   1.3239'4 | -1.50 |      -8.00 | -837.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
    #1 by #2:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.20 20:00:01 |   1.3155'7 | -2.30 |      -8.00 | -103.00 |         111 |                   |
   | closed    |     #2 | Sell | 0.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.20 20:00:01 |   1.3155'7 |  0.00 |       0.00 |    0.00 |         222 | close hedge by #1 | müßte "close hedge for #1" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
    #2 by #1:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |  0.00 |       0.00 |    0.00 |         111 | close hedge by #2 | müßte "close hedge for #2" lauten
   | closed    |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 | -2.30 |      -8.00 | -103.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+-------------------+
    - Der ClosePrice des schließenden Tickets (by) wird auf seinen OpenPrice gesetzt (byOpenPrice == byClosePrice), der ClosePrice des zu schließenden Tickets auf byOpenPrice.
    - Swap und Profit des schließenden Tickets (by) werden zum zu schließenden Ticket addiert, bereits berechnete Commission wird erstattet. Die LotSize des schließenden Tickets
      (by) wird auf 0 gesetzt.


   Partielles Close
   ================
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   |           | Ticket | Type | Lots | Symbol |            OpenTime     | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission |  Profit | MagicNumber | Comment/Online             | Comment/Tester < Build 416 | Comment/Tester >= Build 416 |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | open      |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 |                     |   1.3237'4 | -0.56 |      -5.60 |  499.80 |         111 |                            |                            |                             |
   | open      |     #2 | Sell | 1.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 |                     |   1.3239'4 | -1.50 |      -8.00 | -837.00 |         222 |                            |                            |                             |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+

    #smaller(1) by #larger(2):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3155'7 | -2.06 |      -5.60 |  -72.10 |         111 | partial close              | partial close              | to #3                       | müßte unverändert sein
   | closed    |     #2 | Sell | 0.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3155'7 |  0.00 |       0.00 |    0.00 |         222 | close hedge by #1          | close hedge by #1          | close hedge by #1           | müßte "partial close/close hedge for #1" lauten
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 20:00:01 (1) |  1.3155'7 |                     |   1.3239'4 |  0.00 |      -2.40 | -251.00 |         222 | from #1                    | split from #1              | from #1                     | müßte "split from #2" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
    - Der Swap des schließenden Tickets (by) wird zum zu schließenden Ticket addiert, bereits berechnete Commission wird aufgeteilt und erstattet. Die LotSize des schließenden
      Tickets (by) wird auf 0 gesetzt.
    - Der Profit der Restposition ist erst nach Schließen oder dem nächsten Tick korrekt aktualisiert (nur im Tester???).

    #larger(2) by #smaller(1):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |  0.00 |       0.00 |    0.00 |         111 | close hedge by #2          | close hedge by #2          | close hedge by #2           | müßte "close hedge for #2" lauten
   | closed    |     #2 | Sell | 0.70 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 | -2.06 |      -5.60 |  -72.10 |         222 | partial close              | partial close              |                             |
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 14:00:05 (2) |  1.3155'7 |                     |   1.3239'4 |  0.00 |      -2.40 | -251.10 |         222 | partial close              | partial close              |                             | müßte "split from #2" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+-------+------------+---------+-------------+----------------------------+----------------------------+-----------------------------+
    - Swap und Profit des schließenden Tickets (by) werden zum zu schließenden Ticket addiert, bereits berechnete Commission wird aufgeteilt und erstattet. Die LotSize des
      schließenden Tickets (by) wird auf 0 gesetzt.
    - Der Profit der Restposition ist erst nach Schließen oder dem nächsten Tick korrekt aktualisiert (nur im Tester???).
    - Zwischen den ursprünglichen Positionen und der Restposition besteht keine auswertbare Beziehung mehr.

   (1) Die OpenTime der Restposition wird im Tester falsch gesetzt (3).
   (2) Die OpenTime der Restposition wird online und im Tester korrekt gesetzt (3).
   (3) Es ist nicht absehbar, zu welchen Folgefehlern es künftig im Tester durch den OpenTime-Fehler beim Schließen nach Methode 1 "#smaller by #larger" kommen kann. Im Tester
       wird daher immer die umständlichere Methode 2 "#larger by #smaller" verwendet. Die dabei fehlende Cross-Referenz wiederum macht sie für die Online-Verwendung unbrauchbar,
       denn theoretisch könnten online Orders mit exakt den gleichen Orderdaten existieren. Dieser Fall wird im Tester, wo immer nur eine Strategie läuft, vernachlässigt.
       Wichtiger scheint, daß die Daten der verbleibenden Restposition immer korrekt sind.
   */

   // Tradereihenfolge analysieren
   int    first, second, smaller, larger;
   double firstLots, secondLots;

   if (ticketOpenTime < oppositeOpenTime || (ticketOpenTime==oppositeOpenTime && ticket < opposite)) {
      first  = ticket;   firstLots  = ticketLots;
      second = opposite; secondLots = oppositeLots;
   }
   else {
      first  = opposite; firstLots  = oppositeLots;
      second = ticket;   secondLots = ticketLots;
   }
   if (LE(firstLots, secondLots)) { smaller = first;  larger = second; }
   else                           { smaller = second; larger = first;  }


   int  error, time1, time2, remainder;
   bool success, smallerByLarger=!IsTesting(), largerBySmaller=!smallerByLarger;


   // Endlosschleife, bis Positionen geschlossen wurden oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      error = NO_ERROR;

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderCloseByEx()   trade context busy, retrying...");
      }
      else {
         time1 = GetTickCount();
         if (smallerByLarger) success = OrderCloseBy(smaller, larger, markerColor);    // siehe (3)
         else                 success = OrderCloseBy(larger, smaller, markerColor);
         time2 = GetTickCount();

         if (success) {
            // Execution-Struktur füllen
            WaitForTicket(first, false);                                               // wartet und selektiert (FALSE)
            execution[EXEC_SWAP      ] = OrderSwap();
            execution[EXEC_COMMISSION] = OrderCommission();
            execution[EXEC_PROFIT    ] = OrderProfit();

            WaitForTicket(second, false);                                              // wartet und selektiert (FALSE)
            execution[EXEC_TIME      ]  = OrderOpenTime();                             // Daten des zweiten Tickets
            execution[EXEC_PRICE     ]  = OrderOpenPrice();
            execution[EXEC_SWAP      ] += OrderSwap();
            execution[EXEC_COMMISSION] += OrderCommission();
            execution[EXEC_PROFIT    ] += OrderProfit();

            execution[EXEC_DURATION  ] = (time2-time1)/1000.0;                         // in Sekunden
            execution[EXEC_REQUOTES  ] = 0;
            execution[EXEC_SLIPPAGE  ] = 0;
            execution[EXEC_TICKET    ] = 0;

            // Restposition finden
            if (NE(firstLots, secondLots)) {
               if (smallerByLarger) {                                                  // online
                  // Referenz: remainder.comment = "from #smaller"
                  string strValue = StringConcatenate("from #", smaller);

                  for (int i=OrdersTotal()-1; i >= 0; i--) {
                     if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;        // FALSE: während des Auslesens wurde in einem anderen Thread ein offenes Ticket geschlossen (darf im Tester nicht auftreten)
                     if (OrderComment() != strValue)                  continue;
                     remainder = OrderTicket();
                     break;
                  }
                  if (remainder == 0)
                     return(_false(catch("OrderCloseByEx(9)   cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = smaller) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = larger)", ERR_RUNTIME_ERROR, O_POP)));
               }

               else /*(largerBySmaller)*/ {                                            // im Tester
                  // keine Referenz vorhanden
                  if (!OrderSelectByTicket(larger, "OrderCloseByEx(10)", NULL, O_POP))
                     return(false);
                  int      remainderType        = OrderType();
                  double   remainderLots        = MathAbs(firstLots - secondLots);
                  string   remainderSymbol      = OrderSymbol();
                  datetime remainderOpenTime    = OrderOpenTime();
                  double   remainderOpenprice   = OrderOpenPrice();
                  datetime remainderCloseTime   = 0;
                  int      remainderMagicNumber = OrderMagicNumber();
                  string   remainderComment     = ifString(GetTerminalBuild() < 416, "partial close", OrderComment());

                  for (i=OrdersTotal()-1; i >= 0; i--) {
                     if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(_false(catch("OrderCloseByEx(11) ->OrderSelect(i="+ i +", SELECT_BY_POS, MODE_TRADES)   unexpectedly returned FALSE", ERR_RUNTIME_ERROR, O_POP)));
                     if (OrderType() == remainderType)
                        if (EQ(OrderLots(), remainderLots))
                           if (OrderSymbol() == remainderSymbol)
                              if (OrderOpenTime() == remainderOpenTime)
                                 if (EQ(OrderOpenPrice(), remainderOpenprice))
                                    if (OrderCloseTime() == remainderCloseTime)
                                       if (OrderMagicNumber() == remainderMagicNumber)
                                          if (OrderComment() == remainderComment) {
                                             remainder = OrderTicket();
                                             break;
                                          }
                  }
                  if (remainder == 0)
                     return(_false(catch("OrderCloseByEx(12)   cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = larger) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = smaller)", ERR_RUNTIME_ERROR, O_POP)));
               }
               execution[EXEC_TICKET] = remainder;
            }

            if (__LOG) log(StringConcatenate("OrderCloseByEx()   closed #", first, " by #", second, ", remainder", ifString(remainder==0, ": none", " #"+ remainder), " after ", DoubleToStr((time2-time1)/1000.0, 3), " s"));
            if (!IsTesting())
               PlaySound("OrderOk.wav");

            return(IsNoError(catch("OrderCloseByEx(13)", NULL, O_POP)));               // regular exit
         }

         error = GetLastError();
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                                            // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;

         warn(StringConcatenate("OrderCloseByEx()   temporary trade error after ", DoubleToStr((time2-time1)/1000.0, 3), " s, retrying..."), error);
      }
      Sleep(300);                                                                      // 0.3 Sekunden warten
   }
   return(_false(catch("OrderCloseByEx(14)   permanent trade error after "+ DoubleToStr((time2-time1)/1000.0, 3) +" s", error, O_POP)));
}


/**
 * Schließt mehrere offene Positionen mehrerer Instrumente auf möglichst effektive Art und Weise.
 *
 * @param  int    tickets[]   - Tickets der zu schließenden Positionen
 * @param  double slippage    - zu akzeptierende Slippage in Pip (default: 0)
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus: FALSE, wenn mindestens eines der Tickets nicht geschlossen werden konnte oder ein Fehler auftrat
 *
 *
 * Für jedes übergebene Ticket enthält execution[] entsprechend der Reihenfolge nach Rückkehr die folgenden Elemente:
 * ------------------------------------------------------------------------------------------------------------------
 * - EXEC_TIME      : Ausführungszeitpunkt der flat-stellenden Transaktion des Ticketsymbols
 * - EXEC_PRICE     : Ausführungspreis der flat-stellenden Transaktion des Ticketsymbols
 * - EXEC_SWAP      : OrderSwap dieses Tickets (1)(2)
 * - EXEC_COMMISSION: OrderCommission dieses Tickets (1)(2)
 * - EXEC_PROFIT    : OrderProfit dieses Tickets (1)(2)
 * - EXEC_DURATION  : Dauer der flat-stellenden Transaktion des Ticketsymbols in Sekunden
 * - EXEC_REQUOTES  : Anzahl der aufgetretenen Requotes
 * - EXEC_SLIPPAGE  : Slippage der flat-stellenden Transaktion des Ticketsymbols in Pips (positiv: zu ungunsten; negativ: zu gunsten)
 * - EXEC_TICKET    : immer 0
 *
 * (1) vom MT4-Server berechnet, kann vom tatsächlichen Einzelwert abweichen
 * (2) aus weiteren Tickets resultierende Beträge werden zum entsprechenden Wert des letzten Tickets des Ticketsymbols addiert,
 *     die Summe der Einzelwerte aller Tickets eines Symbols entspricht dem tatsächlichen Gesamtwert
 */
bool OrderMultiClose(int tickets[], double slippage/*=0*/, color markerColor, int execFlags, double& execution[]) {
   // (1) Beginn Parametervalidierung --
   // tickets
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets == 0)                                     return(_false(catch("OrderMultiClose(1)   invalid size of parameter tickets = "+ IntsToStr(tickets), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   OrderPush("OrderMultiClose(2)");
   for (int i=0; i < sizeOfTickets; i++) {
      if (!OrderSelectByTicket(tickets[i], "OrderMultiClose(3)", NULL, O_POP))
         return(false);
      if (OrderCloseTime() != 0)                               return(_false(catch("OrderMultiClose(3)   #"+ tickets[i] +" is already closed", ERR_INVALID_TICKET, O_POP)));
      if (OrderType() > OP_SELL)                               return(_false(catch("OrderMultiClose(4)   #"+ tickets[i] +" is not an open position", ERR_INVALID_TICKET, O_POP)));
   }
   // slippage
   if (LT(slippage, 0))                                        return(_false(catch("OrderMultiClose(5)   illegal parameter slippage: "+ NumberToStr(slippage, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(catch("OrderMultiClose(6)   illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // -- Ende Parametervalidierung --


   // (2) schnelles Close, wenn nur ein einziges Ticket angegeben wurde
   if (sizeOfTickets == 1)
      return(OrderCloseEx(tickets[0], NULL, NULL, slippage, markerColor, execFlags, execution) && OrderPop("OrderMultiClose(7)"));


   // (3) Zuordnung der Tickets zu Symbolen ermitteln
   string symbols        []; ArrayResize(symbols, 0);
   int si, tickets.symbol[]; ArrayResize(tickets.symbol, sizeOfTickets);
   int symbols.lastTicket[]; ArrayResize(symbols.lastTicket, 0);

   for (i=0; i < sizeOfTickets; i++) {
      if (!OrderSelectByTicket(tickets[i], "OrderMultiClose(8)", NULL, O_POP))
         return(false);
      si = SearchStringArray(symbols, OrderSymbol());
      if (si == -1)
         si = ArrayResize(symbols.lastTicket, ArrayPushString(symbols, OrderSymbol())) - 1;
      tickets.symbol[i]      = si;
      symbols.lastTicket[si] = i;
   }
   if (!OrderPop("OrderMultiClose(9)"))
      return(false);


   // (4) Tickets gemeinsam schließen, wenn alle zum selben Symbol gehören
   int sizeOfSymbols = ArraySize(symbols);
   if (sizeOfSymbols == 1)
      return(OrderMultiClose.OneSymbol(tickets, slippage, markerColor, execFlags, execution));


   // (5) Tickets symbolweise auslesen und Gruppen zunächst nur glattstellen
   ArrayResize(execution, 0);
   ArrayResize(execution, 9*sizeOfTickets);                                // Re-Initialisierung
   double exec[];

   // tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu verhindern, wird auf einer Kopie gearbeitet.
   int copy[], flatSymbols[]; ArrayResize(copy, 0); ArrayResize(flatSymbols, 0);
   int sizeOfCopy=ArrayCopy(copy, tickets), pos, group[];


   for (si=0; si < sizeOfSymbols; si++) {
      ArrayResize(group, 0);

      for (i=0; i < sizeOfCopy; i++) {
         if (si == tickets.symbol[i])
            ArrayPushInt(group, copy[i]);
      }
      int newTicket = OrderMultiClose.Flatten(group, slippage, execFlags, exec);
      if (IsLastError())
         return(false);

      int sizeOfGroup = ArraySize(group);

      // Ausführungsdaten der Gruppe an die entsprechende Position des Funktionsparameters kopieren
      for (i=0; i < sizeOfGroup; i++) {
         pos = SearchIntArray(tickets, group[i]);
         execution[9*pos+EXEC_TIME    ] = exec[EXEC_TIME    ];             // Werte sind in der ganzen Gruppe gleich
         execution[9*pos+EXEC_PRICE   ] = exec[EXEC_PRICE   ];
         execution[9*pos+EXEC_DURATION] = exec[EXEC_DURATION];
         execution[9*pos+EXEC_REQUOTES] = exec[EXEC_REQUOTES];
         execution[9*pos+EXEC_SLIPPAGE] = exec[EXEC_SLIPPAGE];
         execution[9*pos+EXEC_TICKET  ] = 0;
      }
      for (i=0; i < sizeOfGroup; i++) {
         if (newTicket == 0) {                                             // kein neues Ticket: Positionen waren schon ausgeglichen oder ein Ticket wurde komplett geschlossen
            if (Round(exec[9*i+EXEC_TICKET]) == -1)
               break;
         }
         else if (Round(exec[9*i+EXEC_TICKET]) == newTicket)               // neues Ticket: unabhängige neue Position oder ein Ticket wurde partiell geschlossen
            break;
      }
      if (i < sizeOfGroup) {                                               // break getriggert => geschlossenes Ticket gefunden
         pos = SearchIntArray(tickets, group[i]);
         execution[9*pos+EXEC_SWAP      ] = exec[9*i+EXEC_SWAP      ];
         execution[9*pos+EXEC_COMMISSION] = exec[9*i+EXEC_COMMISSION];
         execution[9*pos+EXEC_PROFIT    ] = exec[9*i+EXEC_PROFIT    ];
         sizeOfGroup -= ArraySpliceInts(group, i, 1);                      // geschlossenes Ticket löschen
         sizeOfCopy  -= ArrayDropInt(copy,  group[i]);
         ArraySpliceInts(tickets.symbol, i, 1);
      }
      if (newTicket != 0) {
         sizeOfGroup = ArrayPushInt(group, newTicket);                     // neues Ticket hinzufügen
         sizeOfCopy  = ArrayPushInt(copy,  newTicket);
         ArrayPushInt(tickets.symbol, si);
      }

      if (sizeOfGroup != 0)
         ArrayPushInt(flatSymbols, si);                                    // Symbol zum späteren Schließen vormerken
   }


   // (6) verbliebene Teilpositionen der glattgestellten Gruppen schließen
   int flats = ArraySize(flatSymbols);
   for (i=0; i < flats; i++) {
      ArrayResize(group, 0);
      for (int n=0; n < sizeOfCopy; n++) {
         if (flatSymbols[i] == tickets.symbol[n])
            ArrayPushInt(group, copy[n]);
      }
      sizeOfGroup = ArraySize(group);

      if (!OrderMultiClose.Flattened(group, markerColor, execFlags, exec))
         return(false);

      // Ausführungsdaten der Gruppe an die entsprechende Position des Funktionsparameters kopieren
      for (int j=0; j < sizeOfGroup; j++) {
         pos = SearchIntArray(tickets, group[j]);
         if (pos == -1)                                                    // neue Tickets dem letzten übergebenen Ticket zuordnen
            pos = symbols.lastTicket[flatSymbols[i]];
         execution[9*pos+EXEC_SWAP      ] += exec[9*j+EXEC_SWAP      ];
         execution[9*pos+EXEC_COMMISSION] += exec[9*j+EXEC_COMMISSION];    // Beträge jeweils addieren
         execution[9*pos+EXEC_PROFIT    ] += exec[9*j+EXEC_PROFIT    ];
      }
   }

   return(IsNoError(catch("OrderMultiClose(10)")));
}


/**
 * Schließt mehrere offene Positionen eines Instruments auf möglichst effektive Art und Weise.
 *
 * @param  int    tickets[]   - Tickets der zu schließenden Positionen
 * @param  double slippage    - zu akzeptierende Slippage in Pip (default: 0)
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus: FALSE, wenn mindestens eines der Tickets nicht geschlossen werden konnte oder ein Fehler auftrat
 *
 *
 * Für jedes übergebene Ticket enthält execution[] nach Rückkehr entsprechend der Reihenfolge in tickets[] die folgenden Elemente:
 * -------------------------------------------------------------------------------------------------------------------------------
 * - EXEC_TIME      : Ausführungszeitpunkt der flat-stellenden Transaktion
 * - EXEC_PRICE     : Ausführungspreis der flat-stellenden Transaktion
 * - EXEC_SWAP      : OrderSwap dieses Tickets (1)(2)
 * - EXEC_COMMISSION: OrderCommission dieses Tickets (1)(2)
 * - EXEC_PROFIT    : OrderProfit dieses Tickets (1)(2)
 * - EXEC_DURATION  : Dauer der flat-stellenden Transaktion in Sekunden
 * - EXEC_REQUOTES  : Anzahl der aufgetretenen Requotes
 * - EXEC_SLIPPAGE  : Slippage der flat-stellenden Transaktion in Pips (positiv: zu ungunsten; negativ: zu gunsten)
 * - EXEC_TICKET    : immer 0
 *
 * (1) vom MT4-Server berechnet, kann vom tatsächlichen Einzelwert abweichen
 * (2) aus weiteren Tickets resultierende Beträge werden zum entsprechenden Wert des letzten Tickets addiert,
 *     die Summe der Einzelwerte aller Tickets entspricht dem tatsächlichen Gesamtwert
 */
/*private*/ bool OrderMultiClose.OneSymbol(int tickets[], double slippage/*=0*/, color markerColor, int execFlags, double& execution[]) {
   // keine nochmalige Parametervalidierung (private)
   int sizeOfTickets = ArraySize(tickets);

   ArrayResize(execution, 0);
   ArrayResize(execution, 9*sizeOfTickets);                             // Re-Initialisierung


   // (1) schnelles Close, wenn nur ein einziges Ticket angegeben wurde
   if (sizeOfTickets == 1)
      return(OrderCloseEx(tickets[0], NULL, NULL, slippage, markerColor, execFlags, execution));


   // (2) tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu verhindern, arbeiten wir auf einer Kopie.
   int copy[]; ArrayResize(copy, 0);
   int sizeOfCopy = ArrayCopy(copy, tickets);


   // (3) Gesamtposition glatt stellen
   double exec[];
   int newTicket = OrderMultiClose.Flatten(copy, slippage, execFlags, exec);
   if (IsLastError())
      return(false);

   for (int i=0; i < sizeOfTickets; i++) {
      execution[9*i+EXEC_TIME    ] = exec[EXEC_TIME    ];               // Werte sind bei allen exec[]-Tickets gleich
      execution[9*i+EXEC_PRICE   ] = exec[EXEC_PRICE   ];
      execution[9*i+EXEC_DURATION] = exec[EXEC_DURATION];
      execution[9*i+EXEC_REQUOTES] = exec[EXEC_REQUOTES];
      execution[9*i+EXEC_SLIPPAGE] = exec[EXEC_SLIPPAGE];
      execution[9*i+EXEC_TICKET  ] = 0;
   }
   for (i=0; i < sizeOfTickets; i++) {
      if (newTicket == 0) {                                             // kein neues Ticket: Positionen waren schon ausgeglichen oder ein Ticket wurde komplett geschlossen
         if (Round(exec[9*i+EXEC_TICKET]) == -1)
            break;
      }
      else if (Round(exec[9*i+EXEC_TICKET]) == newTicket)               // neues Ticket: unabhängige neue Position oder ein Ticket wurde partiell geschlossen
         break;
   }
   if (i < sizeOfTickets) {                                             // break getriggert => geschlossenes Ticket gefunden
      execution[9*i+EXEC_SWAP      ] = exec[9*i+EXEC_SWAP      ];
      execution[9*i+EXEC_COMMISSION] = exec[9*i+EXEC_COMMISSION];
      execution[9*i+EXEC_PROFIT    ] = exec[9*i+EXEC_PROFIT    ];
      sizeOfCopy -= ArraySpliceInts(copy, i, 1);                        // geschlossenes Ticket löschen
   }
   if (newTicket != 0)
      sizeOfCopy = ArrayPushInt(copy, newTicket);                       // neues Ticket hinzufügen

   if (sizeOfCopy == 0)
      return(IsNoError(catch("OrderMultiClose.OneSymbol(1)")));


   // (4) Teilpositionen auflösen
   if (!OrderMultiClose.Flattened(copy, markerColor, execFlags, exec))
      return(false);

   for (i=0; i < sizeOfCopy; i++) {
      int pos = SearchIntArray(tickets, copy[i]);
      if (pos == -1)                                                    // neue Tickets dem letzten übergebenen Ticket zuordnen
         pos = sizeOfTickets-1;
      execution[9*pos+EXEC_SWAP      ] += exec[9*i+EXEC_SWAP      ];
      execution[9*pos+EXEC_COMMISSION] += exec[9*i+EXEC_COMMISSION];    // Beträge jeweils addieren
      execution[9*pos+EXEC_PROFIT    ] += exec[9*i+EXEC_PROFIT    ];
   }

   return(IsNoError(catch("OrderMultiClose.OneSymbol(2)")));
}


/**
 * Gleicht die Gesamtposition mehrerer Tickets eines Symbols durch eine zusätzliche Tradeoperation aus. Dies geschieht
 * bevorzugt durch (partielles) Schließen einer der Positionen oder durch Öffnen einer neuen Position.
 *
 * @param  int    tickets[]   - Tickets der auszugleichenden Positionen
 * @param  double slippage    - akzeptable Slippage in Pip (default: 0)
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return int - ein resultierendes neues Ticket (falls zutreffend); 0, falls ein Fehler auftrat (@see last_error)
 *
 *
 * Für jedes übergebene Ticket enthält execution[] nach Rückkehr entsprechend der Reihenfolge in tickets[] die folgenden Elemente:
 * -------------------------------------------------------------------------------------------------------------------------------
 * - EXEC_TIME      : Zeitpunkt der Glattstellung (1)(2)
 * - EXEC_PRICE     : Ausführungspreis der Glattstellung (1)(2)
 * - EXEC_SWAP      : realisierter OrderSwap beim Schließen dieses Tickets (falls zutreffend) (3)
 * - EXEC_COMMISSION: realisierte OrderCommission beim Schließen dieses Tickets (falls zutreffend) (3)
 * - EXEC_PROFIT    : realisierter OrderProfit beim Schließen dieses Tickets (falls zutreffend) (3)
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden (1)
 * - EXEC_REQUOTES  : Anzahl der aufgetretenen Requotes (1)
 * - EXEC_SLIPPAGE  : Slippage der Orderausführung in Pips (positiv: zu ungunsten; negativ: zu gunsten) (1)
 * - EXEC_TICKET    : durch partielles Schließen dieses Tickets erzeugtes weiteres Ticket; -1, wenn dieses Ticket vollständig geschlossen wurde (falls zutreffend)
 *
 * (1) Wert ist bei allen Tickets gleich
 * (2) ist die Gesamtposition bereits ausgeglichen, der OrderOpen-Wert des zuletzt geöffneten Tickets (dieses glich die Gesamtposition aus)
 * (3) vom MT4-Server berechnet, kann vom tatsächlichen Wert abweichen
 */
/*private*/ int OrderMultiClose.Flatten(int tickets[], double slippage/*=0*/, int execFlags, double& execution[]) {
   // keine nochmalige Parametervalidierung (private)
   int sizeOfTickets = ArraySize(tickets);

   ArrayResize(execution, 0);
   ArrayResize(execution, 9*sizeOfTickets);                          // Re-Initialisierung

   OrderPush("OrderMultiClose.Flatten(1)");

   double totalLots, lots[];
   for (int i=0; i < sizeOfTickets; i++) {
      if (!OrderSelectByTicket(tickets[i], "OrderMultiClose.Flatten(2)", NULL, O_POP))
         return(0);                                                  // einzelne Lotsizes speichern und Gesamtposition ermitteln
      if (OrderType() == OP_BUY) { totalLots += OrderLots(); ArrayPushDouble(lots,  OrderLots()); }
      else                       { totalLots -= OrderLots(); ArrayPushDouble(lots, -OrderLots()); }
   }

   int newTicket;

   if (EQ(totalLots, 0)) {
      // Gesamtposition ist bereits ausgeglichen
      int copy[]; ArrayResize(copy, 0);                              // zuletzt geöffnetes Ticket ermitteln
      ArrayCopy(copy, tickets);
      SortTicketsChronological(copy);
      if (!OrderSelectByTicket(copy[sizeOfTickets-1], "OrderMultiClose.Flatten(3)", NULL, O_POP))
         return(0);

      for (i=0; i < sizeOfTickets; i++) {
         execution[9*i+EXEC_TIME      ] = OrderOpenTime();
         execution[9*i+EXEC_PRICE     ] = OrderOpenPrice();
         execution[9*i+EXEC_SWAP      ] = 0;
         execution[9*i+EXEC_COMMISSION] = 0;
         execution[9*i+EXEC_PROFIT    ] = 0;
         execution[9*i+EXEC_DURATION  ] = 0;
         execution[9*i+EXEC_REQUOTES  ] = 0;
         execution[9*i+EXEC_SLIPPAGE  ] = 0;
         execution[9*i+EXEC_TICKET    ] = 0;
      }
      if (!OrderPop("OrderMultiClose.Flatten(4)"))
         return(0);
   }
   else {
      string symbol = OrderSymbol();
      if (!OrderPop("OrderMultiClose.Flatten(5)"))
         return(0);

      // Gesamtposition ausgleichen
      int totalPosition = ifInt(GT(totalLots, 0), OP_LONG, OP_SHORT);

      // nach Möglichkeit OrderClose() verwenden: reduziert MarginRequired, verhindert Überschreiten von TradeserverLimit
      int closeTicket;
      for (i=0; i < sizeOfTickets; i++) {
         if (EQ(lots[i], totalLots)) {                               // zuerst vollständig schließbares Ticket suchen
            closeTicket = tickets[i];
            break;
         }
      }
      if (closeTicket == 0) {
         for (i=0; i < sizeOfTickets; i++) {                         // danach partiell schließbares Ticket suchen
            if (totalPosition == OP_LONG) {
               if (GT(lots[i], totalLots)) {
                  closeTicket = tickets[i];
                  break;
               }
            }
            else {
               if (LT(lots[i], totalLots)) {
                  closeTicket = tickets[i];
                  break;
               }
            }
         }
      }

      int type = totalPosition^1;
      double exec[];

      if (closeTicket != 0) {
         //debug("OrderMultiClose.Flatten()   "+ sizeOfTickets +" "+ symbol +" position"+ ifString(sizeOfTickets==1, "", "s") +" by close of #"+ closeTicket);
         // OrderClose eines existierenden Tickets
         if (!OrderCloseEx(closeTicket, MathAbs(totalLots), NULL, slippage, CLR_NONE, execFlags, exec))
            return(0);
      }
      else {
         //debug("OrderMultiClose.Flatten()   "+ sizeOfTickets +" "+ symbol +" position"+ ifString(sizeOfTickets==1, "", "s") +" by open of "+ OperationTypeDescription(type) +" order");
         // OrderSend: neues Ticket öffnen
         if (OrderSendEx(symbol, type, MathAbs(totalLots), NULL, slippage, NULL, NULL, NULL, NULL, NULL, CLR_NONE, execFlags, exec) == -1)
            return(0);
      }
      newTicket = Round(exec[EXEC_TICKET]);

      for (i=0; i < sizeOfTickets; i++) {
         execution[9*i+EXEC_TIME      ] =                                   exec[EXEC_TIME      ];
         execution[9*i+EXEC_PRICE     ] =                                   exec[EXEC_PRICE     ];
         execution[9*i+EXEC_SWAP      ] = ifDouble(tickets[i]==closeTicket, exec[EXEC_SWAP      ], 0);
         execution[9*i+EXEC_COMMISSION] = ifDouble(tickets[i]==closeTicket, exec[EXEC_COMMISSION], 0);
         execution[9*i+EXEC_PROFIT    ] = ifDouble(tickets[i]==closeTicket, exec[EXEC_PROFIT    ], 0);
         execution[9*i+EXEC_DURATION  ] =                                   exec[EXEC_DURATION  ];
         execution[9*i+EXEC_REQUOTES  ] =                                   exec[EXEC_REQUOTES  ];
         execution[9*i+EXEC_SLIPPAGE  ] =                                   exec[EXEC_SLIPPAGE  ];
         if (tickets[i] != closeTicket) execution[9*i+EXEC_TICKET] =  0;
         else if (newTicket == 0)       execution[9*i+EXEC_TICKET] = -1;               // Ticket vollständig geschlossen
         else                           execution[9*i+EXEC_TICKET] = newTicket;        // Ticket partiell geschlossen
      }
   }

   if (IsError(catch("OrderMultiClose.Flatten(6)")))
      return(0);
   return(newTicket);
}


/**
 * Schließt die ausgeglichene Gesamtposition eines Symbols per OrderCloseBy().
 *
 * @param  int    tickets[]   - Tickets der gehedgten Positionen
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Für jedes übergebene Ticket enthält execution[] nach Rückkehr entsprechend der Reihenfolge in tickets[] die folgenden Elemente:
 * -------------------------------------------------------------------------------------------------------------------------------
 * - EXEC_TIME      : OrderOpenTime des zuletzt geöffneten Tickets (1)
 * - EXEC_PRICE     : OrderOpenPrice des zuletzt geöffneten Tickets (1)
 * - EXEC_SWAP      : OrderSwap dieses Tickets (2)(3)
 * - EXEC_COMMISSION: OrderCommission dieses Tickets (2)(3)
 * - EXEC_PROFIT    : OrderProfit dieses Tickets (2)(3)
 * - EXEC_DURATION  : immer 0
 * - EXEC_REQUOTES  : immer 0
 * - EXEC_SLIPPAGE  : immer 0
 * - EXEC_TICKET    : immer 0
 *
 * (1) Wert ist bei allen Tickets gleich
 * (2) vom MT4-Server berechnet (kann vom tatsächlichen Einzelwert abweichen
 * (3) aus dem Öffnen und Schließen zusätzlicher Tickets resultierende Beträge werden zum entsprechenden Wert des letzten Tickets addiert,
 *     die Summe der Einzelwerte aller Tickets entspricht dem tatsächlichen Gesamtwert
 */
/*private*/ bool OrderMultiClose.Flattened(int tickets[], color markerColor, int execFlags, double& execution[]) {
   int sizeOfTickets = ArraySize(tickets);

   // tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu verhindern, arbeiten wir auf einer Kopie.
   int copy[]; ArrayResize(copy, 0);
   ArrayCopy(copy, tickets);
   int sizeOfCopy = sizeOfTickets;

   // Logging
   if (!OrderSelectByTicket(copy[0], "OrderMultiClose.Flattened(1)", O_PUSH))
      return(false);
   if (__LOG) log(StringConcatenate("OrderMultiClose.Flattened()   closing ", sizeOfCopy, " hedged ", OrderSymbol(), " positions ", IntsToStr(copy)));


   // execution[TIME & PRICE] setzen
   ArrayResize(execution, 0);
   ArrayResize(execution, 9*sizeOfTickets);                                   // Re-Initialisierung

   SortTicketsChronological(copy);                                            // zuletzt geöffnetes Ticket
   if (!OrderSelectByTicket(copy[sizeOfCopy-1], "OrderMultiClose.Flattened(2)", NULL, O_POP))
      return(false);
   for (int i=0; i < sizeOfTickets; i++) {
      execution[9*i+EXEC_TIME ] = OrderOpenTime();
      execution[9*i+EXEC_PRICE] = OrderOpenPrice();
   }


   // Teilpositionen nacheinander auflösen
   while (sizeOfCopy > 0) {
      int opposite, first=copy[0];
      if (!OrderSelectByTicket(first, "OrderMultiClose.Flattened(3)", NULL, O_POP))
         return(false);
      int firstType = OrderType();

      for (i=1; i < sizeOfCopy; i++) {
         if (!OrderSelectByTicket(copy[i], "OrderMultiClose.Flattened(4)", NULL, O_POP))
            return(false);
         if (OrderType() == firstType^1) {
            opposite = copy[i];                                               // erste Opposite-Position ermitteln
            break;
         }
      }
      if (opposite == 0)
         return(_false(catch("OrderMultiClose.Flattened(5)   cannot find opposite position for "+ OperationTypeDescription(firstType) +" #"+ first, ERR_RUNTIME_ERROR, O_POP)));

      double exec[];
      if (!OrderCloseByEx(first, opposite, markerColor, execFlags, exec))     // erste und Opposite-Position schließen
         return(_false(OrderPop("OrderMultiClose.Flattened(6)")));

      sizeOfCopy -= ArraySpliceInts(copy, 0, 1);                              // erstes und opposite Ticket löschen
      sizeOfCopy -= ArrayDropInt(copy, opposite);

      int newTicket = Round(exec[EXEC_TICKET]);
      if (newTicket != 0)                                                     // Restposition zu verbleibenden Tickets hinzufügen
         sizeOfCopy = ArrayPushInt(copy, newTicket);

      i = SearchIntArray(tickets, first);                                     // Ausgangsticket für realisierte Beträge ermitteln
      if (i == -1) {                                                          // Reihenfolge: first, opposite, last
         i = SearchIntArray(tickets, opposite);
         if (i == -1)
            i = sizeOfTickets-1;
      }
      execution[9*i+EXEC_SWAP      ] += exec[EXEC_SWAP      ];                // Beträge addieren
      execution[9*i+EXEC_COMMISSION] += exec[EXEC_COMMISSION];
      execution[9*i+EXEC_PROFIT    ] += exec[EXEC_PROFIT    ];

      SortTicketsChronological(copy);
   }

   return(IsNoError(catch("OrderMultiClose.Flattened(7)", NULL, O_POP)));
}


/**
 * Drop-in-Ersatz für und erweiterte Version von OrderDelete(). Fängt temporäre Tradeserver-Fehler ab und behandelt sie entsprechend.
 *
 * @param  int    ticket      - Ticket der zu schließenden Order
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    execFlags   - die Ausführung steuernde Flags
 * @param  double execution[] - Ausführungsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Elemente des Parameters execution[] (out)
 * -----------------------------------------
 * - EXEC_TIME      : OrderCloseTime
 * - EXEC_PRICE     : OrderClosePrice
 * - EXEC_SWAP      : immer 0
 * - EXEC_COMMISSION: immer 0
 * - EXEC_PROFIT    : immer 0
 * - EXEC_DURATION  : Dauer der Orderausführung in Sekunden
 * - EXEC_REQUOTES  : immer 0
 * - EXEC_SLIPPAGE  : immer 0
 * - EXEC_TICKET    : immer 0
 */
bool OrderDeleteEx(int ticket, color markerColor, int execFlags, double& execution[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelectByTicket(ticket, "OrderDeleteEx(1)", O_PUSH)) return(false);
   if (!IsPendingTradeOperation(OrderType()))                    return(_false(catch("OrderDeleteEx(2)   #"+ ticket +" is not a pending order", ERR_INVALID_TICKET, O_POP)));
   if (OrderCloseTime() != 0)                                    return(_false(catch("OrderDeleteEx(3)   #"+ ticket +" is already deleted", ERR_INVALID_TICKET, O_POP)));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')   return(_false(catch("OrderDeleteEx(4)   illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_FUNCTION_PARAMVALUE, O_POP)));
   // execution
   if (ArraySize(execution) != 9)
      ArrayResize(execution, 9);
   // -- Ende Parametervalidierung --

   /*
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   |         | Ticket |     Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice | Swap | Commission | Profit | MagicNumber | Comment       |
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   | open    |     #1 | Stop Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.4165'6 |                     |   1.3204'4 | 0.00 |       0.00 |   0.00 |         666 | order comment |
   | deleted |     #1 | Stop Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.4165'6 | 2012.03.20 12:00:06 |   1.3204'4 | 0.00 |       0.00 |   0.00 |         666 | cancelled     |
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   */

   int digits = MarketInfo(OrderSymbol(), MODE_DIGITS);                 // für OrderDeleteEx.LogMessage() und OrderDeleteEx.ChartMarker()
   int error = GetLastError();
   if (IsError(error)) return(_false(catch("OrderDeleteEx(5)   symbol=\""+ OrderSymbol() +"\"", error, O_POP)));

   int time1, time2;

   // Endlosschleife, bis Order gelöscht wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      error = NO_ERROR;

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderDeleteEx()   trade context busy, retrying...");
         Sleep(300);                                                    // 0.3 Sekunden warten
      }
      else {
         if (time1 == 0)
            time1 = GetTickCount();                                     // Zeit der ersten Ausführung

         bool success = OrderDelete(ticket, markerColor);
         time2 = GetTickCount();

         if (success) {
            WaitForTicket(ticket, false);                               // wartet und re-selektiert (FALSE)

            if (!ChartMarker.OrderDeleted_A(ticket, digits, markerColor))
               return(_false(OrderPop("OrderDeleteEx(6)")));

            // Execution-Struktur füllen
            execution[EXEC_TIME      ] = OrderCloseTime();
            execution[EXEC_PRICE     ] = OrderClosePrice();
            execution[EXEC_SWAP      ] = 0;
            execution[EXEC_COMMISSION] = 0;
            execution[EXEC_PROFIT    ] = 0;
            execution[EXEC_DURATION  ] = (time2-time1)/1000.0;          // in Sekunden
            execution[EXEC_REQUOTES  ] = 0;
            execution[EXEC_SLIPPAGE  ] = 0;
            execution[EXEC_TICKET    ] = 0;

            if (__LOG) log("OrderDeleteEx()   "+ OrderDeleteEx.LogMessage(ticket, digits, time2-time1));
            if (!IsTesting())
               PlaySound("OrderOk.wav");

            return(IsNoError(catch("OrderDeleteEx(7)", NULL, O_POP)));  // regular exit
         }
         error = GetLastError();
         if (IsNoError(error))
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))                             // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;

         warn(StringConcatenate("OrderDeleteEx()   temporary trade error after ", DoubleToStr((time2-time1)/1000.0, 3), " s, retrying..."), error);
      }
   }

   return(_false(catch("OrderDeleteEx(8)   permanent trade error after "+ DoubleToStr((time2-time1)/1000.0, 3) +" s", error, O_POP)));
}


/**
 * Generiert eine ausführliche Logmessage für eine erfolgreich gelöschte Order.
 *
 * @param  int ticket - Ticket der Order
 * @param  int digits - Nachkommastellen des Ordersymbols
 * @param  int time   - zur Ausführung benötigte Zeit
 *
 * @return string - Logmessage
 */
/*private*/ string OrderDeleteEx.LogMessage(int ticket, int digits, int time) {
   // Ticket ist bereits selektiert
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(OrderType());
   string strLots     = NumberToStr(OrderLots(), ".+");
   string strPrice    = NumberToStr(OrderOpenPrice(), priceFormat);
   string message     = StringConcatenate("deleted #", ticket, " ", strType, " ", strLots, " ", OrderSymbol(), " at ", strPrice, " after ", DoubleToStr(time/1000.0, 3), " s");

   int error = GetLastError();
   if (IsError(error))
      return(_empty(catch("OrderDeleteEx.LogMessage(2)", error)));
   return(message);
}


/**
 * Streicht alle offenen Pending-Orders.
 *
 * @param  color markerColor - Farbe des Chart-Markers (default: kein Marker)
 *
 * @return bool - Erfolgsstatus
 */
bool DeletePendingOrders(color markerColor=CLR_NONE) {
   int flags = NULL;
   double execution[];
   int size = OrdersTotal();

   if (size > 0) {
      OrderPush("DeletePendingOrders(1)");

      for (int i=size-1; i >= 0; i--) {                                 // offene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
            continue;
         if (IsPendingTradeOperation(OrderType())) {
            if (!OrderDeleteEx(OrderTicket(), CLR_NONE, flags, execution))
               return(_false(OrderPop("DeletePendingOrders(2)")));
         }
      }

      OrderPop("DeletePendingOrders(3)");
   }
   return(true);
}


/*
// --------------------------------------------------------------------------------------------------------------------------------
// Tests mit globalen Arrays
// @return string
string staticString[1];
string StaticString() {
   if (StringLen(staticString[0]) == 0) staticString[0] = "s0";
   else                                 staticString[0] = StringConcatenate("s", StrToInteger(StringRight(staticString[0], -1))+1);
   return(staticString[0]);
}
// @return bool
bool staticBool[1];
bool StaticBool() {
   staticBool[0] = !staticBool[0];
   return(staticBool[0]);
}
// @return int
int staticInt[1];
int StaticInt() {
   staticInt[0] = staticInt[0] + 1;
   return(staticInt[0]);
}
// @return double
double staticDouble[1];
double StaticDouble() {
   staticDouble[0] = staticDouble[0] + 1;
   return(staticDouble[0]);
}
*/
// --------------------------------------------------------------------------------------------------------------------------------
// Tests mit lokalen Arrays
// @return string
string StaticString() {
   static string staticString[1];
   if (StringLen(staticString[0]) == 0) staticString[0] = "s0";
   else                                 staticString[0] = StringConcatenate("s", StrToInteger(StringRight(staticString[0], -1))+1);
   return(staticString[0]);
}
// @return bool
bool StaticBool() {
   static bool staticBool[1];
   staticBool[0] = !staticBool[0];
   return(staticBool[0]);
}
// @return int
int StaticInt() {
   static int staticInt[1];
   staticInt[0] = staticInt[0] + 1;
   return(staticInt[0]);
}
// @return double
double StaticDouble() {
   static double staticDouble[1];
   staticDouble[0] = staticDouble[0] + 1;
   return(staticDouble[0]);
}
// --------------------------------------------------------------------------------------------------------------------------------
