/**
 * Data types and sizes in C, C++/Win32 and MQL4
 * =============================================
 *
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * |         |         |        |        |        |                 |          max (hex) |     signed range (decimal) |   unsigned range (decimal) |       C        |     C++/Win32      |      MQL4      |      MQL5       |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * |         |         |        |        |  1 bit |                 |               0x01 |                    0 ... 1 |                    0 ... 1 |                |                    |                |                 |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * |         |         |        | 1 byte |  8 bit |       2 nibbles |               0xFF |               -128 ... 127 |                  0 ... 255 |     char       |     BYTE,bool      |                | char,uchar,bool |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * |         |         | 1 word | 2 byte | 16 bit | HIBYTE + LOBYTE |             0xFFFF |         -32'768 ... 32'767 |               0 ... 65'535 |     short      |     WORD,WCHAR     |                |   short,ushort  |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * |         | 1 dword | 2 word | 4 byte | 32 bit | HIWORD + LOWORD |         0xFFFFFFFF |             -2'147'483'648 |                          0 |   int,long     |     BOOL,DWORD     |  bool,char,int |    int,uint     |
 * |         |         |        |        |        |                 |                    |              2'147'483'647 |              4'294'967'295 |     float      |   WPARAM,LPARAM,   | color,datetime |      color      |
 * |         |         |        |        |        |                 |                    |                            |                            |                | handles, pointers  |                |                 |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * | 1 qword | 2 dword | 4 word | 8 byte | 64 bit |                 | 0xFFFFFFFFFFFFFFFF | -9'223'372'036'854'775'808 |                          0 |     double     |   int64,_time64_t  |   double (1)   |    long,ulong   |
 * |         |         |        |        |        |                 |                    |  9'223'372'036'854'775'807 | 18'446'744'073'709'551'616 |                | LONGLONG,DWORDLONG |                | datetime,double |
 * +---------+---------+--------+--------+--------+-----------------+--------------------+----------------------------+----------------------------+----------------+--------------------+----------------+-----------------+
 * (1) A double with 53 bit mantisse which allows integers of up to 53 bit without loss of precision.
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <timezones.mqh>
#include <win32api.mqh>
#include <functions/ExplodeStrings.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinBools.mqh>
#include <functions/JoinDoubles.mqh>
#include <functions/JoinDoublesEx.mqh>
#include <functions/JoinInts.mqh>
#include <structs/rsf/OrderExecution.mqh>


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   return(NO_ERROR);
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   return(CheckLocks());
}


/**
 * Add a value to all elements of an integer array.
 *
 * @param  _InOut_ int &array[]
 * @param  _In_    int  value
 *
 * @return bool - success status
 */
bool ArrayAddInt(int &array[], int value) {
   int size = ArraySize(array);
   for (int i=0; i < size; i++) {
      array[i] += value;
   }
   return(!catch("ArrayAddInt(1)"));
}


/**
 * Load a file into the text editor.
 *
 * @param  string filename
 *
 * @return bool - success status
 */
bool EditFile(string filename) {
   if (!StringLen(filename)) return(!catch("EditFile(1)  invalid parameter filename: "+ DoubleQuoteStr(filename), ERR_INVALID_PARAMETER));

   string file[1]; file[0] = filename;
   return(EditFiles(file));
}


/**
 * Load multiple files into the text editor.
 *
 * @param  string &filenames[]
 *
 * @return bool - success status
 */
bool EditFiles(string &filenames[]) {
   int size = ArraySize(filenames);
   if (!size) return(!catch("EditFiles(1)  invalid parameter filenames: {}", ERR_INVALID_PARAMETER));

   for (int i=0; i < size; i++) {
      if (!StringLen(filenames[i])) return(!catch("EditFiles(2)  invalid parameter filenames["+ i +"]: "+ DoubleQuoteStr(filenames[i]), ERR_INVALID_PARAMETER));
      if (IsLogDebug()) logDebug("EditFiles(3)  loading "+ DoubleQuoteStr(filenames[i]));

      if (IsFile(filenames[i], MODE_SYSTEM)) {
         while (IsSymlinkA(filenames[i])) {
            string target = GetReparsePointTargetA(filenames[i]);    // resolve symlinks as some editors cannot write to it (e.g. TextPad)
            if (!StringLen(target))
               break;
            filenames[i] = target;
         }
      }
      else if (IsDirectory(filenames[i], MODE_SYSTEM)) {
         logError("EditFiles(4)  cannot edit directory "+ DoubleQuoteStr(filenames[i]), ERR_FILE_IS_DIRECTORY);
         ArraySpliceStrings(filenames, i, 1);
         size--; i--;
         continue;
      }
      else {}                                                        // file doesn't exist, behavior is up to the editor
   }

   // check the editor configuration
   string editor = GetGlobalConfigString("System", "Editor");

   if (StringLen(editor) > 0) {
      // use configured editor
      string cmd = editor +" \""+ JoinStrings(filenames, "\" \"") +"\"";
      int result = WinExec(cmd, SW_SHOWNORMAL);
      if (result < 32) return(!catch("EditFiles(5)->kernel32::WinExec(cmd="+ DoubleQuoteStr(editor) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));
   }
   else {
      // use ShellExecute() and the OS default "open" handler
      string sNull;
      for (i=0; i < size; i++) {
         result = ShellExecuteA(NULL, "open", filenames[i], sNull, sNull, SW_SHOWNORMAL);
         if (result <= 32) return(!catch("EditFiles(6)->shell32::ShellExecuteA(file="+ DoubleQuoteStr(filenames[i]) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));
      }
   }
   return(!catch("EditFiles(7)"));
}


/**
 * Ermittelt Zeitpunkt und Offset des vorherigen und nächsten DST-Wechsels der angebenen Serverzeit.
 *
 * @param  _In_  datetime serverTime       - Serverzeit
 * @param  _Out_ datetime prevTransition[] - Array zur Aufnahme der letzten vorherigen Transitionsdaten
 * @param  _Out_ datetime nextTransition[] - Array zur Aufnahme der nächsten Transitionsdaten
 *
 * @return bool - success status
 *
 * Format of prevTransition[] and nextTransition[]:
 * ------------------------------------------------
 * int[] = {
 *    TRANSITION_TIME   => GMT-Zeitpunkt des Wechsels oder -1, wenn der Wechsel unbekannt ist,
 *    TRANSITION_OFFSET => GMT-Offset nach dem Wechsel,
 *    TRANSITION_DST    => ob nach dem Wechsel DST gilt oder nicht
 * }
 */
bool GetTimezoneTransitions(datetime serverTime, int &prevTransition[], int &nextTransition[]) {
   if (serverTime < 0)              return(!catch("GetTimezoneTransitions(1)  invalid parameter serverTime: "+ serverTime +" (not a time)", ERR_INVALID_PARAMETER));
   if (serverTime >= D'2038.01.01') return(!catch("GetTimezoneTransitions(2)  too large parameter serverTime: '"+ GmtTimeFormat(serverTime, "%a, %d.%m.%Y %H:%M") +"' (unsupported)", ERR_INVALID_PARAMETER));

   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone))        return(false);
   /**
    * Logik:
    * ------
    *  if      (datetime < TR_TO_DST) offset = STD_OFFSET;     // Normalzeit zu Jahresbeginn
    *  else if (datetime < TR_TO_STD) offset = DST_OFFSET;     // DST
    *  else                           offset = STD_OFFSET;     // Normalzeit zu Jahresende
    *
    *
    * Szenarien:                           Wechsel zu DST (TR_TO_DST)              Wechsel zu Normalzeit (TR_TO_STD)
    * ----------                           ----------------------------------      ----------------------------------
    *  kein Wechsel, ständig Normalzeit:   -1                      DST_OFFSET      -1                      STD_OFFSET      // durchgehend Normalzeit
    *  kein Wechsel, ständig DST:          -1                      DST_OFFSET      INT_MAX                 STD_OFFSET      // durchgehend DST
    *  1 Wechsel zu DST:                   1975.04.11 00:00:00     DST_OFFSET      INT_MAX                 STD_OFFSET      // Jahr beginnt mit Normalzeit und endet mit DST
    *  1 Wechsel zu Normalzeit:            -1                      DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Jahr beginnt mit DST und endet mit Normalzeit
    *  2 Wechsel:                          1975.04.01 00:00:00     DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Normalzeit -> DST -> Normalzeit
    */
   datetime toDST, toSTD;
   int i, iMax=2037-1970, y=TimeYearEx(serverTime);

   // letzter Wechsel
   if (ArraySize(prevTransition) < 3)
      ArrayResize(prevTransition, 3);
   ArrayInitialize(prevTransition, 0);
   i = y-1970;

   while (true) {
      if (i < 0)              { prevTransition[TRANSITION_TIME] = -1; break; }
      if (lTimezone == "gmt") { prevTransition[TRANSITION_TIME] = -1; break; }

      if (lTimezone == "america/new_york") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else if (lTimezone == "europe/berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else if (lTimezone == "europe/kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else if (lTimezone == "europe/london") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else if (lTimezone == "europe/minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else if (lTimezone=="fxt" || lTimezone=="america/new_york+0700") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { prevTransition[TRANSITION_TIME] = toSTD; prevTransition[TRANSITION_OFFSET] = transitions.FXT             [i][STD_OFFSET]; prevTransition[TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { prevTransition[TRANSITION_TIME] = toDST; prevTransition[TRANSITION_OFFSET] = transitions.FXT             [i][DST_OFFSET]; prevTransition[TRANSITION_DST] = true;  break; }
      }

      else return(!catch("GetTimezoneTransitions(3)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG));

      i--;                                                           // letzter Wechsel war früher
   }


   // nächster Wechsel
   if (ArraySize(nextTransition) < 3)
      ArrayResize(nextTransition, 3);
   ArrayInitialize(nextTransition, 0);
   i = y-1970;

   while (true) {
      if (i > iMax)           { nextTransition[TRANSITION_TIME] = -1; break; }
      if (lTimezone == "gmt") { nextTransition[TRANSITION_TIME] = -1; break; }

      if (lTimezone == "america/new_york") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else if (lTimezone == "europe/berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else if (lTimezone == "europe/kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else if (lTimezone == "europe/london") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else if (lTimezone == "europe/minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else if (lTimezone=="fxt" || lTimezone=="america/new_york+0700") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TRANSITION_TIME] = toDST; nextTransition[TRANSITION_OFFSET] = transitions.FXT             [i][DST_OFFSET]; nextTransition[TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TRANSITION_TIME] = toSTD; nextTransition[TRANSITION_OFFSET] = transitions.FXT             [i][STD_OFFSET]; nextTransition[TRANSITION_DST] = false; break; }
      }

      else return(!catch("GetTimezoneTransitions(4)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG));

      i++;                                                        // nächster Wechsel ist später
   }
   return(true);
}


string __lockNames   [];                                          // Namen der Locks, die vom Programm gehalten werden
int    __lockCounters[];                                          // Anzahl der akquirierten Locks je Name


/**
 * Versucht, das Terminal-weite Lock mit dem angegebenen Namen zu erwerben.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 * @param  bool   wait      - ob auf das Lock gewartet (TRUE) oder sofort zurückgekehrt (FALSE) werden soll
 *
 * @return bool - success status
 */
bool AquireLock(string mutexName, bool wait) {
   wait = wait!=0;

   if (!StringLen(mutexName)) return(!catch("AquireLock(1)  illegal parameter mutexName: "+ DoubleQuoteStr(mutexName), ERR_INVALID_PARAMETER));

   // check if we already own the lock
   int i = SearchStringArray(__lockNames, mutexName);
   if (i > -1) {                                               // yes
      __lockCounters[i]++;
      return(true);
   }

   int error, duration, seconds=1, startTime=GetTickCount();
   string globalVar = ifString(__isTesting, "tester.", "") + mutexName;

   // loop until lock is aquired
   while (true) {
      if (GlobalVariableSetOnCondition(globalVar, 1, 0)) {     // try to get it
         ArrayPushString(__lockNames, mutexName);               // got it
         ArrayPushInt   (__lockCounters,      1);
         return(true);
      }
      error = GetLastError();

      if (error == ERR_GLOBAL_VARIABLE_NOT_FOUND) {            // create mutex if it doesn't yet exist
         if (!GlobalVariableSet(globalVar, 0)) {
            error = GetLastError();
            return(!catch("AquireLock(2)  failed to create mutex "+ DoubleQuoteStr(mutexName), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
         continue;                                             // retry
      }
      if (IsError(error)) return(!catch("AquireLock(3)  failed to get lock on mutex "+ DoubleQuoteStr(mutexName), error));
      if (IsStopped())    return(_true(logWarn("AquireLock(4)  couldn't yet get lock on mutex "+ DoubleQuoteStr(mutexName) +" but was ordered to stop, taking it...")));
      if (!wait)          return(false);

      // warn every second, cancel after 10 seconds
      duration = GetTickCount() - startTime;
      if (duration >= seconds*1000) {
         if (seconds >= 10)
            return(!catch("AquireLock(5)  failed to get lock on mutex "+ DoubleQuoteStr(mutexName) +" after "+ (duration/1000) +" sec, giving up", ERR_RUNTIME_ERROR));
         logNotice("AquireLock(6)  couldn't get lock on mutex "+ DoubleQuoteStr(mutexName) +" after "+ duration/1000 +" sec, retrying...");
         seconds++;
      }

      // sleep and retry...
      if (IsIndicator() || IsTesting()) SleepEx(100, true);    // indicator or expert in tester
      else                              Sleep(100);
   }

   return(!catch("AquireLock(7)", ERR_WRONG_JUMP));            // unreachable
}



/**
 * Gibt das Terminal-Lock mit dem angegebenen Namen wieder frei.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 *
 * @return bool - success status
 */
bool ReleaseLock(string mutexName) {
   if (!StringLen(mutexName)) return(!catch("ReleaseLock(1)  illegal parameter mutexName: \"\"", ERR_INVALID_PARAMETER));

   // check, if we indeed own that lock
   int i = SearchStringArray(__lockNames, mutexName);
   if (i == -1)
      return(!catch("ReleaseLock(2)  do not own a lock for mutex \""+ mutexName +"\"", ERR_RUNTIME_ERROR));

   // we do, decrease the counter
   __lockCounters[i]--;

   // remove it, if counter is zero
   if (__lockCounters[i] == 0) {
      ArraySpliceStrings(__lockNames,    i, 1);
      ArraySpliceInts   (__lockCounters, i, 1);

      string globalVarName = mutexName;

      if (__isTesting)
         globalVarName = "tester."+ mutexName;

      if (!GlobalVariableSet(globalVarName, 0)) {
         int error = GetLastError();
         return(!catch("ReleaseLock(3)  failed to reset mutex \""+ mutexName +"\"", ifInt(!error, ERR_RUNTIME_ERROR, error)));
      }
   }
   return(true);
}


/**
 * Clean up aquired locks and issue a warning if an unreleased lock was found.
 *
 * @return int - error status
 *
 * @access private
 */
int CheckLocks() {
   int error = NO_ERROR;

   for (int i=ArraySize(__lockNames)-1; i >= 0; i--) {
      logWarn("CheckLocks(1)  unreleased lock found for mutex "+ DoubleQuoteStr(__lockNames[i]));
      if (!ReleaseLock(__lockNames[i]))
         error = last_error;
   }
   return(error);
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zu FXT (Forex Time) zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return int - Offset in Sekunden (immer negativ), es gilt: FXT + Offset = GMT
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetGmtToFxtTimeOffset(datetime gmtTime) {
   if (gmtTime < 0) return(_EMPTY_VALUE(catch("GetGmtToFxtTimeOffset(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearEx(gmtTime)-1970;

   // FXT
   if      (gmtTime < transitions.FXT[year][TR_TO_DST.gmt]) offset = -transitions.FXT[year][STD_OFFSET];
   else if (gmtTime < transitions.FXT[year][TR_TO_STD.gmt]) offset = -transitions.FXT[year][DST_OFFSET];
   else                                                     offset = -transitions.FXT[year][STD_OFFSET];

   return(offset);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu FXT (Forex Time) zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return int - Offset in Sekunden, es gilt: FXT + Offset = Serverzeit (positive Werte für östlich von FXT laufende Server)
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToFxtTimeOffset(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu FXT festen Zeitzone läuft
   if (lTimezone == "fxt"                  ) return(       0);
   if (lTimezone == "america/new_york+0700") return(       0);
   if (lTimezone == "fxt-0200"             ) return(-2*HOURS);
   if (lTimezone == "america/new_york+0500") return(-2*HOURS);
   if (lTimezone == "america/new_york"     ) return(-7*HOURS);

   if (serverTime < 0) return(_EMPTY_VALUE(catch("GetServerToFxtTimeOffset(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_PARAMETER)));

   // Offset Server zu GMT
   int offset1 = 0;
   if (timezone != "gmt") {
      offset1 = GetServerToGmtTimeOffset(serverTime);
      if (offset1 == EMPTY_VALUE)
         return(EMPTY_VALUE);
   }

   // Offset GMT zu FXT
   int offset2 = GetGmtToFxtTimeOffset(serverTime - offset1);
   if (offset2 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   return(offset1 + offset2);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return int - Offset in Sekunden, es gilt: GMT + Offset = Serverzeit (positive Werte für östlich von GMT laufende Server)
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToGmtTimeOffset(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu GMT festen Zeitzone läuft
   if (lTimezone == "gmt") return(0);

   if (serverTime < 0) return(_EMPTY_VALUE(catch("GetServerToGmtTimeOffset(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearEx(serverTime)-1970;

   if (lTimezone == "america/new_york") {
      if      (serverTime < transitions.America_New_York[year][TR_TO_DST.local]) offset = transitions.America_New_York[year][STD_OFFSET];
      else if (serverTime < transitions.America_New_York[year][TR_TO_STD.local]) offset = transitions.America_New_York[year][DST_OFFSET];
      else                                                                       offset = transitions.America_New_York[year][STD_OFFSET];
   }
   else if (lTimezone == "europe/berlin") {
      if      (serverTime < transitions.Europe_Berlin   [year][TR_TO_DST.local]) offset = transitions.Europe_Berlin   [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Berlin   [year][TR_TO_STD.local]) offset = transitions.Europe_Berlin   [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Berlin   [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/kiev") {
      if      (serverTime < transitions.Europe_Kiev     [year][TR_TO_DST.local]) offset = transitions.Europe_Kiev     [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Kiev     [year][TR_TO_STD.local]) offset = transitions.Europe_Kiev     [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Kiev     [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/london") {
      if      (serverTime < transitions.Europe_London   [year][TR_TO_DST.local]) offset = transitions.Europe_London   [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_London   [year][TR_TO_STD.local]) offset = transitions.Europe_London   [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_London   [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/minsk") {
      if      (serverTime < transitions.Europe_Minsk    [year][TR_TO_DST.local]) offset = transitions.Europe_Minsk    [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Minsk    [year][TR_TO_STD.local]) offset = transitions.Europe_Minsk    [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Minsk    [year][STD_OFFSET];
   }
   else if (lTimezone=="fxt" || lTimezone=="america/new_york+0700") {
      if      (serverTime < transitions.FXT             [year][TR_TO_DST.local]) offset = transitions.FXT             [year][STD_OFFSET];
      else if (serverTime < transitions.FXT             [year][TR_TO_STD.local]) offset = transitions.FXT             [year][DST_OFFSET];
      else                                                                       offset = transitions.FXT             [year][STD_OFFSET];
   }
   else if (lTimezone=="fxt-0200" || lTimezone=="america/new_york+0500") {
      datetime fxtTime = serverTime + PLUS_2_H;
      if      (fxtTime < transitions.FXT                [year][TR_TO_DST.local]) offset = transitions.FXT             [year][STD_OFFSET] + MINUS_2_H;
      else if (fxtTime < transitions.FXT                [year][TR_TO_STD.local]) offset = transitions.FXT             [year][DST_OFFSET] + MINUS_2_H;
      else                                                                       offset = transitions.FXT             [year][STD_OFFSET] + MINUS_2_H;
   }
   else return(_EMPTY_VALUE(catch("GetServerToGmtTimeOffset(2)  unknown server timezone configuration \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

   return(offset);
}


/**
 * Return all keys of an .ini file section.
 *
 * @param  _In_  string fileName - initialization filename
 * @param  _In_  string section  - initialization file section
 * @param  _Out_ string keys[]   - array receiving the found keys
 *
 * @return int - number of found keys or EMPTY (-1) in case of errors
 */
int GetIniKeys(string fileName, string section, string &keys[]) {
   int bufferSize = 512;
   int buffer[]; InitializeByteBuffer(buffer, bufferSize);

   int chars = GetIniKeysA(fileName, section, buffer, bufferSize);

   // handle a too small buffer
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeByteBuffer(buffer, bufferSize);
      chars = GetIniKeysA(fileName, section, buffer, bufferSize);
   }

   if (!chars) int size = ArrayResize(keys, 0);             // file or section not found or empty section
   else            size = ExplodeStrings(buffer, keys);

   ArrayResize(buffer, 0);

   if (!catch("GetIniKeys(1)"))
      return(size);
   return(EMPTY);
}


/**
 * Return all section names of an .ini file.
 *
 * @param  _In_  string fileName - initialization filename
 * @param  _Out_ string names[]  - array receiving the found section names
 *
 * @return int - number of found section names or EMPTY (-1) in case of errors
 */
int GetIniSections(string fileName, string &names[]) {
   int bufferSize = 512;
   int buffer[]; InitializeByteBuffer(buffer, bufferSize);

   int chars = GetIniSectionsA(fileName, buffer, bufferSize);

   // handle a too small buffer
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeByteBuffer(buffer, bufferSize);
      chars = GetIniSectionsA(fileName, buffer, bufferSize);
   }

   if (!chars) int size = ArrayResize(names, 0);            // file not found or no sections
   else            size = ExplodeStrings(buffer, names);

   ArrayResize(buffer, 0);

   if (!catch("GetIniSections(1)"))
      return(size);
   return(EMPTY);
}


/**
 * Return the name of the current account server. Similar to the built-in function AccountServer() but can also be used without
 * a server connection.
 *
 * @return string - directory name or an empty string in case of errors
 */
string GetAccountServer() {
   // Der Servername wird zwischengespeichert und der Cache bei ValidBars = 0 invalidiert. Bei Accountwechsel zeigen die MQL-
   // Accountfunktionen evt. schon auf den neuen Account, das Programm verarbeitet aber noch einen Tick des alten Charts im
   // alten Serververzeichnis. Erst nach ValidBars = 0 ist sichergestellt, daß das neue Serververzeichnis aktiv ist.

   static string static.serverName[1];
   static int    static.lastTick;                     // für Erkennung von Mehrfachaufrufen während desselben Ticks

   // invalidate cache if a new tick and ValidBars==0
   int tick = __ExecutionContext[EC.ticks];
   if (!__ExecutionContext[EC.validBars]) /*&&*/ if (tick != static.lastTick)
      static.serverName[0] = "";
   static.lastTick = tick;

   if (!StringLen(static.serverName[0])) {
      string serverName=AccountServer(), tmpFilename="", fullTmpFilename="";

      if (!StringLen(serverName)) {
         // create temporary file
         tmpFilename = "~GetAccountServer~"+ GetCurrentThreadId() +".tmp";
         int hFile = FileOpenHistory(tmpFilename, FILE_WRITE|FILE_BIN);

         if (hFile < 0) {                             // if the server directory doesn't yet exist or write access was denied
            int error = GetLastError();
            if (error == ERR_CANNOT_OPEN_FILE) logNotice("GetAccountServer(1)->FileOpenHistory(\""+ tmpFilename +"\", FILE_WRITE)", _int(error, SetLastError(ERS_TERMINAL_NOT_YET_READY)));
            else                               catch("GetAccountServer(2)->FileOpenHistory(\""+ tmpFilename +"\", FILE_WRITE)", error);
            return(EMPTY_STR);
         }
         FileClose(hFile);

         // search the created file
         string pattern = GetHistoryRootPathA() +"/*";

         /*WIN32_FIND_DATA*/int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA_size);
         int hFindDir = FindFirstFileA(pattern, wfd), next = hFindDir;
         while (next != 0) {
            if (wfd_FileAttribute_Directory(wfd)) {
               string name = wfd_FileName(wfd);
               if (name!=".") /*&&*/ if (name!="..") {
                  fullTmpFilename = GetHistoryRootPathA() +"/"+ name +"/"+ tmpFilename;
                  if (IsFile(fullTmpFilename, MODE_SYSTEM)) {
                     DeleteFileA(fullTmpFilename);
                     serverName = name;
                     break;
                  }
               }
            }
            next = FindNextFileA(hFindDir, wfd);
         }
         if (hFindDir == INVALID_HANDLE_VALUE) return(_EMPTY_STR(catch("GetAccountServer(4) directory "+ DoubleQuoteStr(pattern) +" not found", ERR_FILE_NOT_FOUND)));

         FindClose(hFindDir);
         ArrayResize(wfd, 0);
      }

      if (IsError(catch("GetAccountServer(5)"))) return( EMPTY_STR);
      if (!StringLen(serverName))                return(_EMPTY_STR(catch("GetAccountServer(6)  cannot find server directory containing "+ DoubleQuoteStr(tmpFilename), ERR_RUNTIME_ERROR)));

      static.serverName[0] = serverName;
   }
   return(static.serverName[0]);
}


/**
 * Initialisiert einen Buffer zur Aufnahme der gewünschten Anzahl von Doubles.
 *
 * @param  double buffer[] - das für den Buffer zu verwendende Double-Array
 * @param  int    size     - Anzahl der im Buffer zu speichernden Doubles
 *
 * @return int - error status
 */
int InitializeDoubleBuffer(double buffer[], int size) {
   if (ArrayDimension(buffer) > 1) return(catch("InitializeDoubleBuffer(1)  too many dimensions of parameter buffer: "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAY));
   if (size < 0)                   return(catch("InitializeDoubleBuffer(2)  invalid parameter size: "+ size, ERR_INVALID_PARAMETER));

   if (ArraySize(buffer) != size)
      ArrayResize(buffer, size);

   if (ArraySize(buffer) > 0)
      ArrayInitialize(buffer, 0);

   return(catch("InitializeDoubleBuffer(3)"));
}


/**
 * Initialisiert einen Buffer zur Aufnahme eines Strings der gewünschten Länge.
 *
 * @param  string buffer[] - das für den Buffer zu verwendende String-Array
 * @param  int    length   - Länge des Buffers in Zeichen
 *
 * @return int - error status
 */
int InitializeStringBuffer(string &buffer[], int length) {
   if (ArrayDimension(buffer) > 1) return(catch("InitializeStringBuffer(1)  too many dimensions of parameter buffer: "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAY));
   if (length < 0)                 return(catch("InitializeStringBuffer(2)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER));

   if (ArraySize(buffer) == 0)
      ArrayResize(buffer, 1);

   buffer[0] = CreateString(length);

   return(catch("InitializeStringBuffer(3)"));
}


/**
 * Sort an array of strings.
 *
 * @param  string values[]
 *
 * @return bool - success status
 */
bool SortStrings(string &values[]) {
   if (ArrayDimension(values) > 1) return(catch("SortStrings(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(values) < 2)             // nothing to do
      return(true);
   return(SortMqlStringsA(values, ArraySize(values)));
}


/**
 * Sortiert die übergebenen Tickets in chronologischer Reihenfolge (nach OpenTime und Ticket#).
 *
 * @param  _InOut_ int tickets[] - zu sortierende Tickets
 *
 * @return int - error status
 */
int SortTicketsChronological(int &tickets[]) {
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets < 2)
      return(NO_ERROR);

   int data[][2]; ArrayResize(data, sizeOfTickets);

   OrderPush("SortTicketsChronological(1)");

   // Tickets aufsteigend nach OrderOpenTime() sortieren
   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "SortTicketsChronological(2)", NULL, O_POP))
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
 * Sortiert die übergebenen Ticketdaten nach {OpenTime, Ticket}.
 *
 * @param  _Inout_ int tickets[] - Array mit Ticketdaten
 *
 * @return bool - success status
 */
bool SortOpenTickets(int &tickets[][/*{OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 2) return(!catch("SortOpenTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAY));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2)
      return(true);                                                  // weniger als 2 Zeilen

   // Zeilen nach OpenTime sortieren
   ArraySort(tickets);

   // Zeilen mit gleicher OpenTime zusätzlich nach Ticket sortieren
   int openTime, lastOpenTime, ticket, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);

   for (int i=0, n; i < rows; i++) {
      openTime = tickets[i][0];
      ticket   = tickets[i][1];

      if (openTime == lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // in sameOpenTimes[] angesammelte Zeilen von keys[] nach Ticket sortieren
         if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
            return(false);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in keys[]

      lastOpenTime = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
         return(false);
      n = 0;
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortOpenTickets(2)"));
}


/**
 * Internal helper for SortOpenTickets().
 *
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach Ticket. Die OpenTime-Felder dieser Zeilen sind gleich
 * und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - success status
 *
 * @access private
 */
bool __SOT.SameOpenTimes(int &ticketData[][/*{OpenTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   // Originaldaten mit den sortierten Werten überschreiben
   for (int i, n=0; n < rows; n++) {
      i                = rowsToSort[n][1];
      ticketData[i][1] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SOT.SameOpenTimes(1)"));
}


/**
 * Positioniert die Legende neu (wird nach Entfernen eines Legendenlabels aufgerufen).
 *
 * @return int - error status
 */
int RepositionLegend() {
   if (__isSuperContext) return(true);

   int iObjects=ObjectsTotal(), iLabels=ObjectsTotal(OBJ_LABEL);

   string sLabels[];   ArrayResize(sLabels, 0);    // Namen der gefundenen Label
   int    yDists[][2]; ArrayResize(yDists,  0);    // Y-Distance und sLabels[]-Index, um Label nach Position sortieren zu können

   for (int i=0, n; i < iObjects && iLabels; i++) {
      string objName = ObjectName(i);
      if (ObjectType(objName) == OBJ_LABEL) {
         if (StrStartsWith(objName, "rsf.Legend.")) {
            ArrayResize(sLabels, n+1);
            ArrayResize(yDists,  n+1);
            sLabels[n]    = objName;
            yDists [n][0] = ObjectGet(objName, OBJPROP_YDISTANCE);
            yDists [n][1] = n;
            n++;
         }
         iLabels--;
      }
   }

   if (n > 0) {
      ArraySort(yDists);
      for (i=0; i < n; i++) {
         ObjectSet(sLabels[yDists[i][1]], OBJPROP_YDISTANCE, 20 + i*19);
      }
   }
   return(catch("RepositionLegend(1)"));
}


/**
 * Ob ein Tradeserver-Fehler temporär (also vorübergehend) ist oder nicht. Bei einem vorübergehenden Fehler *kann* der erneute Versuch, die
 * Order auszuführen, erfolgreich sein.
 *
 * @return int - error status
 *
 * @return bool
 */
bool IsTemporaryTradeError(int error) {
   switch (error) {
      // temporary errors
      case ERR_SERVER_BUSY:                  //        4   trade server busy
      case ERR_TRADE_TIMEOUT:                //      128   trade timeout
      case ERR_INVALID_PRICE:                //      129   price moves too fast (away)
      case ERR_PRICE_CHANGED:                //      135   price changed
      case ERR_OFF_QUOTES:                   //      136   off quotes (atm the broker cannot provide prices)
      case ERR_REQUOTE:                      //      138   requote
      case ERR_TRADE_CONTEXT_BUSY:           //      146   trade context busy
         return(true);

      // permanent errors
      case ERR_NO_RESULT:                    //        1   no result                                                 // TODO: temporary
      case ERR_TRADESERVER_GONE:             //        2   trade server gone                                         // TODO: temporary, e.g. on trade server change
      case ERR_INVALID_TRADE_PARAMETERS:     //        3   invalid trade parameters
      case ERR_OLD_VERSION:                  //        5   old version of client terminal
      case ERR_NO_CONNECTION:                //        6   no connection to trade server                             // TODO: temporary
      case ERR_NOT_ENOUGH_RIGHTS:            //        7   not enough rights
      case ERR_TOO_FREQUENT_REQUESTS:        // ???    8   too frequent requests                                     // TODO: temporary
      case ERR_MALFUNCTIONAL_TRADE:          //        9   malfunctional trade operation
      case ERR_ACCOUNT_DISABLED:             //       64   account disabled
      case ERR_INVALID_ACCOUNT:              //       65   invalid account
      case ERR_INVALID_STOP:                 //      130   invalid stop
      case ERR_INVALID_TRADE_VOLUME:         //      131   invalid trade volume
      case ERR_MARKET_CLOSED:                //      132   market is closed
      case ERR_TRADE_DISABLED:               //      133   trading is disabled
      case ERR_NOT_ENOUGH_MONEY:             //      134   not enough money
      case ERR_BROKER_BUSY:                  //      137   automated trading disabled (manual trading still enabled)
      case ERR_ORDER_LOCKED:                 //      139   order is locked
      case ERR_LONG_POSITIONS_ONLY_ALLOWED:  //      140   long positions only allowed
      case ERR_TOO_MANY_REQUESTS:            // ???  141   too many requests                                         // TODO: temporary
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
 * Weist einer Position eines zweidimensionalen Integer-Arrays ein anderes Array zu (entspricht array[i] = array[] für ein
 * Array von Arrays).
 *
 * @param  int array[][] - zu modifizierendes zwei-dimensionales Arrays
 * @param  int offset    - zu modifizierende Position
 * @param  int values[]  - zuzuweisendes Array (Größe muß der zweiten Dimension des zu modifizierenden Arrays entsprechen)
 *
 * @return int - error status
 */
int ArraySetInts(int array[][], int offset, int values[]) {
   if (ArrayDimension(array) != 2)   return(catch("ArraySetInts(1)  illegal dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY));
   if (ArrayDimension(values) != 1)  return(catch("ArraySetInts(2)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY));
   int dim1 = ArrayRange(array, 0);
   int dim2 = ArrayRange(array, 1);
   if (ArraySize(values) != dim2)    return(catch("ArraySetInts(3)  array size mis-match of parameters array and values: array["+ dim1 +"]["+ dim2 +"] / values["+ ArraySize(values) +"]", ERR_INCOMPATIBLE_ARRAY));
   if (offset < 0 || offset >= dim1) return(catch("ArraySetInts(4)  illegal parameter offset: "+ offset, ERR_INVALID_PARAMETER));

   int src  = GetIntsAddress(values);
   int dest = GetIntsAddress(array) + offset*dim2*4;
   CopyMemory(dest, src, dim2*4);
   return(NO_ERROR);
}


/**
 * Fügt ein Element am Ende eines Boolean-Arrays an.
 *
 * @param  _InOut_ bool array[] - Boolean-Array
 * @param  _In_    bool value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayPushBool(bool &array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushBool()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Fügt ein Element am Ende eines Integer-Arrays an.
 *
 * @param  _InOut_ int array[] - Integer-Array
 * @param  _In_    int value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayPushInt(int &array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushInt()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Append an integer array to the end of a 2-dimensional integer array.
 *
 * @param  int array[][] - array to extend
 * @param  int value[]   - array to append (size must match the 2nd dimension of the array to extend)
 *
 * @return int - new number of rows of the extended array or EMPTY (-1) in case of errors
 */
int ArrayPushInts(int array[][], int value[]) {
   if (ArrayDimension(array) != 2) return(_EMPTY(catch("ArrayPushInts(1)  illegal dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(value) != 1) return(_EMPTY(catch("ArrayPushInts(2)  too many dimensions of parameter value: "+ ArrayDimension(value), ERR_INCOMPATIBLE_ARRAY)));
   int dim1 = ArrayRange(array, 0);
   int dim2 = ArrayRange(array, 1);
   if (ArraySize(value) != dim2)   return(_EMPTY(catch("ArrayPushInts(3)  array size mis-match of parameters array and value: array["+ dim1 +"]["+ dim2 +"] / value["+ ArraySize(value) +"]", ERR_INCOMPATIBLE_ARRAY)));

   ArrayResize(array, dim1+1);
   int src  = GetIntsAddress(value);
   int dest = GetIntsAddress(array) + dim1*dim2*4;
   CopyMemory(dest, src, dim2*4);
   return(dim1+1);
}


/**
 * Fügt ein Element am Ende eines Double-Arrays an.
 *
 * @param  _InOut_ double array[] - Double-Array
 * @param  _In_    double value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayPushDouble(double &array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushDouble()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Append a double array to the end of a 2-dimensional double array.
 *
 * @param  double array[][] - array to extend
 * @param  double value[]   - array to append (size must match the 2nd dimension of the array to extend)
 *
 * @return int - new number of rows of the extended array or EMPTY (-1) in case of errors
 */
int ArrayPushDoubles(double array[][], double value[]) {
   if (ArrayDimension(array) != 2) return(_EMPTY(catch("ArrayPushDoubles(1)  illegal dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(value) != 1) return(_EMPTY(catch("ArrayPushDoubles(2)  too many dimensions of parameter value: "+ ArrayDimension(value), ERR_INCOMPATIBLE_ARRAY)));
   int dim1 = ArrayRange(array, 0);
   int dim2 = ArrayRange(array, 1);
   if (ArraySize(value) != dim2)   return(_EMPTY(catch("ArrayPushDoubles(3)  array size mis-match of parameters array and value: array["+ dim1 +"]["+ dim2 +"] / value["+ ArraySize(value) +"]", ERR_INCOMPATIBLE_ARRAY)));

   ArrayResize(array, dim1+1);
   int src  = GetDoublesAddress(value);
   int dest = GetDoublesAddress(array) + dim1*dim2*8;
   CopyMemory(dest, src, dim2*8);
   return(dim1+1);
}


/**
 * Fügt ein Element am Ende eines String-Arrays an.
 *
 * @param  string array[] - String-Array
 * @param  string value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayPushString(string &array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushString()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Entfernt ein Element vom Ende eines Boolean-Arrays und gibt es zurück.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - das entfernte Element oder FALSE, falls ein Fehler auftrat
 */
bool ArrayPopBool(bool array[]) {
   if (ArrayDimension(array) > 1) return(!catch("ArrayPopBool(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY));

   int size = ArraySize(array);
   if (size == 0)                 return(!catch("ArrayPopBool(2)  cannot pop element from empty array = {}", ERR_ARRAY_ERROR));

   bool popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Ende eines Integer-Arrays und gibt es zurück.
 *
 * @param  int array[] - Integer-Array
 *
 * @return int - das entfernte Element oder 0, falls ein Fehler auftrat
 */
int ArrayPopInt(int array[]) {
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayPopInt(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayPopInt(2)  cannot pop element from empty array = {}", ERR_ARRAY_ERROR)));

   int popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Ende eines Double-Array und gibt es zurück.
 *
 * @param  int double[] - Double-Array
 *
 * @return double - das entfernte Element oder 0, falls ein Fehler auftrat
 */
double ArrayPopDouble(double array[]) {
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayPopDouble(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayPopDouble(2)  cannot pop element from empty array = {}", ERR_ARRAY_ERROR)));

   double popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Entfernt ein Element vom Ende eines String-Arrays und gibt es zurück.
 *
 * @param  string array[] - String-Array
 *
 * @return string - das entfernte Element oder ein Leerstring, falls ein Fehler auftrat
 */
string ArrayPopString(string array[]) {
   if (ArrayDimension(array) > 1) return(_EMPTY_STR(catch("ArrayPopString(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_EMPTY_STR(catch("ArrayPopString(2)  cannot pop element from empty array = {}", ERR_ARRAY_ERROR)));

   string popped = array[size-1];
   ArrayResize(array, size-1);

   return(popped);
}


/**
 * Fügt ein Element am Beginn eines Boolean-Arrays an.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayUnshiftBool(bool array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftBool()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   ReverseBoolArray(array);
   int size = ArrayPushBool(array, value);
   ReverseBoolArray(array);
   return(size);
}


/**
 * Fügt ein Element am Beginn eines Integer-Arrays an.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayUnshiftInt(int array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftInt()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   ReverseIntArray(array);
   int size = ArrayPushInt(array, value);
   ReverseIntArray(array);
   return(size);
}


/**
 * Fügt ein Element am Beginn eines Double-Arrays an.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayUnshiftDouble(double array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftDouble()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   ReverseDoubleArray(array);
   int size = ArrayPushDouble(array, value);
   ReverseDoubleArray(array);
   return(size);
}


/**
 * Entfernt ein Element vom Beginn eines Boolean-Arrays und gibt es zurück.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - das entfernte Element oder FALSE, falls ein Fehler auftrat
 */
bool ArrayShiftBool(bool array[]) {
   if (ArrayDimension(array) > 1) return(!catch("ArrayShiftBool(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY));

   int size = ArraySize(array);
   if (size == 0)                 return(!catch("ArrayShiftBool(2)  cannot shift element from empty array = {}", ERR_ARRAY_ERROR));

   bool shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt ein Element vom Beginn eines Integer-Arrays und gibt es zurück.
 *
 * @param  int array[] - Integer-Array
 *
 * @return int - das entfernte Element oder 0, falls ein Fehler auftrat
 */
int ArrayShiftInt(int array[]) {
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayShiftInt(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayShiftInt(2)  cannot shift element from empty array = {}", ERR_ARRAY_ERROR)));

   int shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt ein Element vom Beginn eines Double-Arrays und gibt es zurück.
 *
 * @param  double array[] - Double-Array
 *
 * @return double - das entfernte Element oder 0, falls ein Fehler auftrat
 */
double ArrayShiftDouble(double array[]) {
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayShiftDouble(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_NULL(catch("ArrayShiftDouble(2)  cannot shift element from an empty array = {}", ERR_ARRAY_ERROR)));

   double shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt ein Element vom Beginn eines String-Arrays und gibt es zurück.
 *
 * @param  string array[] - String-Array
 *
 * @return string - das entfernte Element oder ein Leerstring, falls ein Fehler auftrat
 */
string ArrayShiftString(string array[]) {
   if (ArrayDimension(array) > 1) return(_EMPTY_STR(catch("ArrayShiftString(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(array);
   if (size == 0)
      return(_EMPTY_STR(catch("ArrayShiftString(2)  cannot shift element from an empty array = {}", ERR_ARRAY_ERROR)));

   string shifted = array[0];

   if (size > 1)
      ArrayCopy(array, array, 0, 1);
   ArrayResize(array, size-1);

   return(shifted);
}


/**
 * Entfernt aus einem Boolean-Array alle Vorkommen eines Elements.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayDropBool(bool array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropBool()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

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
 * Entfernt aus einem Integer-Array alle Vorkommen eines Elements.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayDropInt(int array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropInt()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

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
 * Entfernt aus einem Double-Array alle Vorkommen eines Elements.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayDropDouble(double array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropDouble()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

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
 * Entfernt aus einem String-Array alle Vorkommen eines Elements.
 *
 * @param  string array[] - String-Array
 * @param  string value   - zu entfernendes Element
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayDropString(string array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropString()  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   int count, size=ArraySize(array);
   if (!size)
      return(0);

   if (StrIsNull(value)) {                            // NULL-Pointer
      for (int i=size-1; i>=0; i--) {
         if (!StringLen(array[i])) /*&&*/ if (StrIsNull(array[i])) {
            if (i < size-1)                           // ArrayCopy(), wenn das zu entfernende Element nicht das letzte ist
               ArrayCopy(array, array, i, i+1);
            size = ArrayResize(array, size-1);        // Array um ein Element kürzen
            count++;
         }
      }
      return(count);
   }

   // normaler String (kein NULL-Pointer)
   for (i=size-1; i>=0; i--) {
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
 * @param  int  offset  - Startindex zu entfernender Elemente
 * @param  int  length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArraySpliceBools(bool array[], int offset, int length) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArraySpliceBools(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);
   if (offset < 0)                return(_EMPTY(catch("ArraySpliceBools(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > size-1)           return(_EMPTY(catch("ArraySpliceBools(3)  invalid parameter offset: "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_PARAMETER)));
   if (length < 0)                return(_EMPTY(catch("ArraySpliceBools(4)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));

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
 * Remove a number of elements from an integer array. If the array is 1-dimensional the function operates on element indexes.
 * If the array is 2-dimensional the function operates on row indexes.
 *
 * @param  int array[][] - source array
 * @param  int offset    - start offset of the elements/rows to remove
 * @param  int length    - number of elements/rows to remove
 *
 * @return int - number of removed elements/rows or EMPTY (-1) in case of errors
 */
int ArraySpliceInts(int array[], int offset, int length) {
   int dims = ArrayDimension(array);
   if (dims > 2)        return(_EMPTY(catch("ArraySpliceInts(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int dim1 = ArrayRange(array, 0), dim2=0;
   if (dims > 1) dim2 = ArrayRange(array, 1);

   if (offset < 0)      return(_EMPTY(catch("ArraySpliceInts(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > dim1-1) return(_EMPTY(catch("ArraySpliceInts(3)  invalid parameter offset: "+ offset +" for array["+ dim1 +"]"+ ifString(dims==1, "", "[]"), ERR_INVALID_PARAMETER)));
   if (length < 0)      return(_EMPTY(catch("ArraySpliceInts(4)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));

   if (dim1   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < dim1) {
      if (dims == 1) ArrayCopy(array, array, offset,       offset+length      ); // copy remaining elements from the end
      else           ArrayCopy(array, array, offset*dim2, (offset+length)*dim2);
   }
   else {
      length = dim1 - offset;
   }

   ArrayResize(array, dim1-length);
   return(length);
}


/**
 * Remove a number of elements from a double array. If the array is 1-dimensional the function operates on element indexes.
 * If the array is 2-dimensional the function operates on row indexes.
 *
 * @param  double array[][] - source array
 * @param  int    offset    - start offset of the elements/rows to remove
 * @param  int    length    - number of elements/rows to remove
 *
 * @return int - number of removed elements/rows or EMPTY (-1) in case of errors
 */
int ArraySpliceDoubles(double array[], int offset, int length) {
   int dims = ArrayDimension(array);
   if (dims > 2)        return(_EMPTY(catch("ArraySpliceDoubles(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int dim1 = ArrayRange(array, 0), dim2=0;
   if (dims > 1) dim2 = ArrayRange(array, 1);

   if (offset < 0)      return(_EMPTY(catch("ArraySpliceDoubles(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > dim1-1) return(_EMPTY(catch("ArraySpliceDoubles(3)  invalid parameter offset: "+ offset +" for array["+ dim1 +"]"+ ifString(dims==1, "", "[]"), ERR_INVALID_PARAMETER)));
   if (length < 0)      return(_EMPTY(catch("ArraySpliceDoubles(4)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));

   if (dim1   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < dim1) {
      if (dims == 1) ArrayCopy(array, array, offset,       offset+length      ); // copy remaining elements from the end
      else           ArrayCopy(array, array, offset*dim2, (offset+length)*dim2);
   }
   else {
      length = dim1 - offset;
   }

   ArrayResize(array, dim1-length);
   return(length);
}


/**
 * Entfernt einen Teil aus einem String-Array.
 *
 * @param  string array[] - String-Array
 * @param  int    offset  - Startindex zu entfernender Elemente
 * @param  int    length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArraySpliceStrings(string array[], int offset, int length) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArraySpliceStrings(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(array);
   if (offset < 0)                return(_EMPTY(catch("ArraySpliceStrings(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > size-1)           return(_EMPTY(catch("ArraySpliceStrings(3)  invalid parameter offset: "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_PARAMETER)));
   if (length < 0)                return(_EMPTY(catch("ArraySpliceStrings(4)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));

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
 * Fügt ein Element an der angegebenen Position eines Bool-Arrays ein.
 *
 * @param  _InOut_ bool array[] - Bool-Array
 * @param  _In_    int  offset  - Position, an dem das Element eingefügt werden soll
 * @param  _In_    bool value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertBool(bool &array[], int offset, bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertBool(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertBool(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertBool(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(ArrayUnshiftBool(array, value));

   // Einfügen am Ende des Arrays
   if (offset == size)
      return(ArrayPushBool(array, value));

   // Einfügen innerhalb des Arrays (ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten)
   ArrayCopy(array, array, offset+1, offset, size-offset);                       // Elemente nach Offset nach hinten schieben
   array[offset] = value;                                                        // Lücke mit einzufügendem Wert füllen

   return(size + 1);
}


/**
 * Fügt ein Element an der angegebenen Position eines Integer-Arrays ein.
 *
 * @param  _InOut_ int array[] - Integer-Array
 * @param  _In_    int offset  - Position, an dem das Element eingefügt werden soll
 * @param  _In_    int value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertInt(int &array[], int offset, int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertInt(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertInt(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertInt(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(ArrayUnshiftInt(array, value));

   // Einfügen am Ende des Arrays
   if (offset == size)
      return(ArrayPushInt(array, value));

   // Einfügen innerhalb des Arrays (ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten)
   ArrayCopy(array, array, offset+1, offset, size-offset);                       // Elemente nach Offset nach hinten schieben
   array[offset] = value;                                                        // Lücke mit einzufügendem Wert füllen

   return(size + 1);
}


/**
 * Fügt ein Element an der angegebenen Position eines Double-Arrays ein.
 *
 * @param  _InOut_ double array[] - Double-Array
 * @param  _In_    int    offset  - Position, an dem das Element eingefügt werden soll
 * @param  _In_    double value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertDouble(double &array[], int offset, double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertDouble(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertDouble(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertDouble(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(ArrayUnshiftDouble(array, value));

   // Einfügen am Ende des Arrays
   if (offset == size)
      return(ArrayPushDouble(array, value));

   // Einfügen innerhalb des Arrays (ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten)
   ArrayCopy(array, array, offset+1, offset, size-offset);                       // Elemente nach Offset nach hinten schieben
   array[offset] = value;                                                        // Lücke mit einzufügendem Wert füllen

   return(size + 1);
}


/**
 * Fügt an einem Offset eines zwei-dimensionalen Double-Arrays ein anderes Double-Array ein.
 *
 * @param  _InOut_ double array[][] - zu vergrößerndes zwei-dimensionales Ausgangs-Array
 * @param  _In_    int    offset    - Position im Ausgangs-Array, an dem das andere Array eingefügt werden soll
 * @param  _In_    double values[]  - einzufügendes Array (muß in seiner ersten Dimension der zweiten Dimension des Ausgangsarrays entsprechen)
 *
 * @return int - neue Größe des Ausgangsarrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertDoubleArray(double &array[][], int offset, double values[]) {
   if (ArrayDimension(array) != 2)         return(catch("ArrayInsertDoubleArray(1)  illegal dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY));
   if (ArrayDimension(values) != 1)        return(catch("ArrayInsertDoubleArray(2)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY));
   int array.dim1 = ArrayRange(array, 0);
   int array.dim2 = ArrayRange(array, 1);
   if (ArraySize(values) != array.dim2)    return(catch("ArrayInsertDoubleArray(3)  array size mis-match of parameters array and values: array["+ array.dim1 +"]["+ array.dim2 +"] / values["+ ArraySize(values) +"]", ERR_INCOMPATIBLE_ARRAY));
   if (offset < 0 || offset >= array.dim1) return(catch("ArrayInsertDoubleArray(4)  illegal parameter offset: "+ offset, ERR_INVALID_PARAMETER));

   // Ausgangsarray vergrößern
   int newSize = array.dim1 + 1;
   ArrayResize(array, newSize);

   // Inhalt des Ausgangsarrays von offset nach hinten verschieben
   int array.dim2.size = array.dim2 * DOUBLE_VALUE;
   int src   = GetDoublesAddress(array) + offset * array.dim2.size;
   int dest  =                               src + array.dim2.size;
   int bytes =               (array.dim1-offset) * array.dim2.size;
   CopyMemory(dest, src, bytes);

   // Inhalt des anderen Arrays an den gewünschten Offset schreiben
   dest  = src;
   src   = GetDoublesAddress(values);
   bytes = array.dim2.size;
   CopyMemory(dest, src, bytes);

   return(newSize);
}


/**
 * Fügt in ein Bool-Array die Elemente eines anderen Bool-Arrays ein.
 *
 * @param  bool array[]  - Ausgangs-Array
 * @param  int  offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  bool values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertBools(bool array[], int offset, bool values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertBools(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertBools(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertBools(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertBools(4)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));
   int sizeOfValues = ArraySize(values);

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(MergeBoolArrays(values, array, array));

   // Einfügen am Ende des Arrays
   if (offset == sizeOfArray)
      return(MergeBoolArrays(array, values, array));

   // Einfügen innerhalb des Arrays
   int newSize = sizeOfArray + sizeOfValues;
   ArrayResize(array, newSize);

   // ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten
   ArrayCopy(array, array, offset+sizeOfValues, offset, sizeOfArray-offset);     // Elemente nach Offset nach hinten schieben
   ArrayCopy(array, values, offset);                                             // Lücke mit einzufügenden Werten überschreiben

   return(newSize);
}


/**
 * Fügt in ein Integer-Array die Elemente eines anderen Integer-Arrays ein.
 *
 * @param  int array[]  - Ausgangs-Array
 * @param  int offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  int values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertInts(int array[], int offset, int values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertInts(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertInts(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertInts(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertInts(4)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));
   int sizeOfValues = ArraySize(values);

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(MergeIntArrays(values, array, array));

   // Einfügen am Ende des Arrays
   if (offset == sizeOfArray)
      return(MergeIntArrays(array, values, array));

   // Einfügen innerhalb des Arrays
   int newSize = sizeOfArray + sizeOfValues;
   ArrayResize(array, newSize);

   // ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten
   ArrayCopy(array, array, offset+sizeOfValues, offset, sizeOfArray-offset);     // Elemente nach Offset nach hinten schieben
   ArrayCopy(array, values, offset);                                             // Lücke mit einzufügenden Werten überschreiben

   return(newSize);
}


/**
 * Fügt in ein Double-Array die Elemente eines anderen Double-Arrays ein.
 *
 * @param  double array[]  - Ausgangs-Array
 * @param  int    offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  double values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertDoubles(double array[], int offset, double values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertDoubles(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertDoubles(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertDoubles(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertDoubles(4)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));
   int sizeOfValues = ArraySize(values);

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(MergeDoubleArrays(values, array, array));

   // Einfügen am Ende des Arrays
   if (offset == sizeOfArray)
      return(MergeDoubleArrays(array, values, array));

   // Einfügen innerhalb des Arrays
   int newSize = sizeOfArray + sizeOfValues;
   ArrayResize(array, newSize);

   // ArrayCopy() benutzt bei primitiven Arrays MoveMemory(), wir brauchen nicht mit einer zusätzlichen Kopie arbeiten
   ArrayCopy(array, array, offset+sizeOfValues, offset, sizeOfArray-offset);     // Elemente nach Offset nach hinten schieben
   ArrayCopy(array, values, offset);                                             // Lücke mit einzufügenden Werten überschreiben

   return(newSize);
}


/**
 * Fügt ein Element an der angegebenen Position eines String-Arrays ein.
 *
 * @param  _InOut_ string array[] - String-Array
 * @param  _In_    int    offset  - Position, an dem das Element eingefügt werden soll
 * @param  _In_    string value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (nEMPTY), falls ein Fehler auftrat
 */
int ArrayInsertString(string &array[], int offset, string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertString(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertString(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertString(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(ArrayUnshiftString(array, value));

   // Einfügen am Ende des Arrays
   if (offset == size)
      return(ArrayPushString(array, value));

   // Einfügen innerhalb des Arrays: ArrayCopy() "zerstört" bei String-Arrays den sich überlappenden Bereich, daher zusätzliche Kopie nötig
   string tmp[]; ArrayResize(tmp, 0);
   ArrayCopy(tmp, array, 0, offset, size-offset);                                // Kopie der Elemente hinterm Einfügepunkt machen
   ArrayCopy(array, tmp, offset+1);                                              // Elemente hinterm Einfügepunkt nach hinten schieben (Quelle: die Kopie)
   ArrayResize(tmp, 0);
   array[offset] = value;                                                        // Lücke mit einzufügendem Wert füllen
   return(size + 1);
}


/**
 * Fügt in ein String-Array die Elemente eines anderen String-Arrays ein.
 *
 * @param  _InOut_ string array[]  - Ausgangs-Array
 * @param  _In_    int    offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  _In_    string values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertStrings(string &array[], int offset, string values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertStrings(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertStrings(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertStrings(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertStrings(4)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));
   int sizeOfValues = ArraySize(values);

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(MergeStringArrays(values, array, array));

   // Einfügen am Ende des Arrays
   if (offset == sizeOfArray)
      return(MergeStringArrays(array, values, array));

   // Einfügen innerhalb des Arrays
   int newSize = sizeOfArray + sizeOfValues;
   ArrayResize(array, newSize);

   // ArrayCopy() "zerstört" bei String-Arrays den sich überlappenden Bereich, wir müssen mit einer zusätzlichen Kopie arbeiten
   string tmp[]; ArrayResize(tmp, 0);
   ArrayCopy(tmp, array, 0, offset, sizeOfArray-offset);                         // Kopie der Elemente hinter dem Einfügepunkt erstellen
   ArrayCopy(array, tmp, offset+sizeOfValues);                                   // Elemente hinter dem Einfügepunkt nach hinten schieben
   ArrayCopy(array, values, offset);                                             // Lücke mit einzufügenden Werten überschreiben

   ArrayResize(tmp, 0);
   return(newSize);
}


/**
 * Prüft, ob ein Boolean in einem Array enthalten ist.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool BoolInArray(bool haystack[], bool needle) {
   needle = needle!=0;

   if (ArrayDimension(haystack) > 1) return(!catch("BoolInArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY));
   return(SearchBoolArray(haystack, needle) > -1);
}


/**
 * Prüft, ob ein Integer in einem Array enthalten ist.
 *
 * @param  int haystack[] - zu durchsuchendes Array
 * @param  int needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool IntInArray(int haystack[], int needle) {
   if (ArrayDimension(haystack) > 1) return(!catch("IntInArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY));
   return(SearchIntArray(haystack, needle) > -1);
}


/**
 * Prüft, ob ein Double in einem Array enthalten ist.
 *
 * @param  double haystack[] - zu durchsuchendes Array
 * @param  double needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool DoubleInArray(double haystack[], double needle) {
   if (ArrayDimension(haystack) > 1) return(!catch("DoubleInArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY));
   return(SearchDoubleArray(haystack, needle) > -1);
}


/**
 * Prüft, ob ein String in einem Array enthalten ist. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool StringInArray(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(!catch("StringInArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY));
   return(SearchStringArray(haystack, needle) > -1);
}


/**
 * Prüft, ob ein String in einem Array enthalten ist. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool StringInArrayI(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(!catch("StringInArrayI()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY));
   return(SearchStringArrayI(haystack, needle) > -1);
}


/**
 * Durchsucht ein Boolean-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder EMPTY (-1), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchBoolArray(bool haystack[], bool needle) {
   needle = needle!=0;

   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchBoolArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(EMPTY);
}


/**
 * Durchsucht ein Integer-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  int haystack[] - zu durchsuchendes Array
 * @param  int needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder EMPTY (-1), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchIntArray(int haystack[], int needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchIntArray(1)  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(EMPTY);
}


/**
 * Durchsucht ein Double-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  double haystack[] - zu durchsuchendes Array
 * @param  double needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder EMPTY (-1), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchDoubleArray(double haystack[], double needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchDoubleArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (EQ(haystack[i], needle))
         return(i);
   }
   return(EMPTY);
}


/**
 * Durchsucht ein String-Array nach einem Wert und gibt dessen Index zurück. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder EMPTY (-1), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchStringArray(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchStringArray()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY)));
   int size = ArraySize(haystack);

   for (int i=0; i < size; i++) {
      if (haystack[i] == needle)
         return(i);
   }
   return(EMPTY);
}


/**
 * Durchsucht ein String-Array nach einem Wert und gibt dessen Index zurück. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string haystack[] - zu durchsuchendes Array
 * @param  string needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder EMPTY (-1), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchStringArrayI(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchStringArrayI()  too many dimensions of parameter haystack: "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(haystack);
   needle = StrToLower(needle);

   for (int i=0; i < size; i++) {
      if (StrToLower(haystack[i]) == needle)
         return(i);
   }
   return(EMPTY);
}


/**
 * Kehrt die Reihenfolge der Elemente eines Boolean-Arrays um.
 *
 * @param  bool array[] - Boolean-Array
 *
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see  IsReverseIndexedBoolArray()
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see  IsReverseIndexedIntArray()
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see  IsReverseIndexedDoubleArray()
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
 *                FALSE, wenn die interne Indizierung normal ist
 *
 * @see  IsReverseIndexedStringArray()
 */
bool ReverseStringArray(string array[]) {
   if (ArraySetAsSeries(array, true))
      return(!ArraySetAsSeries(array, false));
   return(true);
}


/**
 * Ob die Indizierung der internen Implementierung des angegebenen Boolean-Arrays umgekehrt ist oder nicht.
 *
 * @param  bool array[] - Boolean-Array
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
 * Vereint die Werte zweier Boolean-Arrays.
 *
 * @param  bool array1[] - Boolean-Array
 * @param  bool array2[] - Boolean-Array
 * @param  bool merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int MergeBoolArrays(bool array1[], bool array2[], bool merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeBoolArrays(1)  too many dimensions of parameter array1: "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeBoolArrays(2)  too many dimensions of parameter array2: "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeBoolArrays(3)  too many dimensions of parameter merged: "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAY)));

   // Da merged[] Referenz auf array1[] oder array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
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
 * Vereint die Werte zweier Integer-Arrays.
 *
 * @param  int array1[] - Integer-Array
 * @param  int array2[] - Integer-Array
 * @param  int merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int MergeIntArrays(int array1[], int array2[], int merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeIntArrays(1)  too many dimensions of parameter array1: "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeIntArrays(2)  too many dimensions of parameter array2: "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeIntArrays(3)  too many dimensions of parameter merged: "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAY)));

   // Da merged[] Referenz auf array1[] oder array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
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
 * Vereint die Werte zweier Double-Arrays.
 *
 * @param  double array1[] - Double-Array
 * @param  double array2[] - Double-Array
 * @param  double merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int MergeDoubleArrays(double array1[], double array2[], double merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeDoubleArrays(1)  too many dimensions of parameter array1: "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeDoubleArrays(2)  too many dimensions of parameter array2: "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeDoubleArrays(3)  too many dimensions of parameter merged: "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAY)));

   // Da merged[] Referenz auf array1[] oder array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
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
 * Vereint die Werte zweier String-Arrays.
 *
 * @param  string array1[] - String-Array
 * @param  string array2[] - String-Array
 * @param  string merged[] - resultierendes Array
 *
 * @return int - Größe des resultierenden Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int MergeStringArrays(string array1[], string array2[], string merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeStringArrays(1)  too many dimensions of parameter array1: "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeStringArrays(2)  too many dimensions of parameter array2: "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeStringArrays(3)  too many dimensions of parameter merged: "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAY)));

   // Da merged[] Referenz auf array1[] oder array2[] sein kann, arbeiten wir über den Umweg einer Kopie.
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
 * Addiert die Werte eines Double-Arrays.
 *
 * @param  double values[]  - Array mit Ausgangswerten
 *
 * @return double - Summe aller Werte oder 0, falls ein Fehler auftrat
 */
double SumDoubles(double values[]) {
   if (ArrayDimension(values) > 1) return(_NULL(catch("SumDoubles()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   double sum;

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum);
}


/**
 * Convert an array of order tickets to a readable representation.
 *
 * @param  int    tickets[]
 * @param  string separator [optional] - element separator (default: ", ")
 *
 * @return string - readable representation or an empty string in case of errors
 */
string TicketsToStr(int tickets[], string separator = ", ") {
   if (ArrayDimension(tickets) != 1) return(_EMPTY_STR(catch("TicketsToStr(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(tickets);
   if (!size) return("{}");

   if (separator == "0")                           // (string) NULL
      separator = ", ";

   string result="", sValue="";

   for (int i=0; i < size; i++) {
      if   (tickets[i] > 0) sValue = StringConcatenate("#", tickets[i]);
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");
      result = StringConcatenate(result, separator, sValue);
   }

   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Gibt die lesbare Version eines Zeichenbuffers zurück. <NUL>-Characters (0x00h) werden gestrichelt (…), Control-Characters (< 0x20h)
 * fett (•) dargestellt.
 *
 * @param  int buffer[] - Byte-Buffer (kann ein- oder zwei-dimensional sein)
 *
 * @return string
 */
string BufferToStr(int buffer[]) {
   int dimensions = ArrayDimension(buffer);
   if (dimensions != 1)
      return(__BuffersToStr(buffer));

   string result = "";
   int size = ArraySize(buffer);                                        // ein Integer = 4 Byte = 4 Zeichen

   // Integers werden binär als {LOBYTE, HIBYTE, LOWORD, HIWORD} gespeichert.
   for (int i=0; i < size; i++) {
      int integer = buffer[i];                                          // Integers nacheinander verarbeiten
                                                                                                                     // +---+------------+------+
      for (int b=0; b < 4; b++) {                                                                                    // | b |    byte    | char |
         int chr = integer & 0xFF;                                      // ein einzelnes Byte des Integers lesen     // +---+------------+------+
         if (chr < 0x20) {                                              // nicht darstellbare Zeichen ersetzen       // | 0 | 0x000000FF |   1  |
            if (chr == 0x00) chr = PLACEHOLDER_NUL_CHAR;                // NUL-Byte          (…)                     // | 1 | 0x0000FF00 |   2  |
            else             chr = PLACEHOLDER_CTRL_CHAR;               // Control-Character (•)                     // | 2 | 0x00FF0000 |   3  |
         }                                                                                                           // | 3 | 0xFF000000 |   4  |
         result = StringConcatenate(result, CharToStr(chr));                                                         // +---+------------+------+
         integer >>= 8;
      }
   }
   return(result);
}


/**
 * Gibt den Inhalt eines Byte-Buffers als lesbaren String zurück. NUL-Bytes (0x00h) werden gestrichelt (…), Control-Character (< 0x20h)
 * fett (•) dargestellt. Nützlich, um einen Bufferinhalt schnell visualisieren zu können.
 *
 * @param  int buffer[] - Byte-Buffer (kann ein- oder zwei-dimensional sein)
 *
 * @return string
 *
 * @access private - Aufruf nur aus BufferToStr()
 */
string __BuffersToStr(int buffer[][]) {
   int dimensions = ArrayDimension(buffer);
   if (dimensions > 2) return(_EMPTY_STR(catch("__BuffersToStr()  too many dimensions of parameter buffer: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));

   if (dimensions == 1)
      return(BufferToStr(buffer));

   string result = "";
   int dim1=ArrayRange(buffer, 0), dim2=ArrayRange(buffer, 1);          // ein Integer = 4 Byte = 4 Zeichen

   // Integers werden binär als {LOBYTE, HIBYTE, LOWORD, HIWORD} gespeichert.
   for (int i=0; i < dim1; i++) {
      for (int n=0; n < dim2; n++) {
         int integer = buffer[i][n];                                    // Integers nacheinander verarbeiten
                                                                                                                     // +---+------------+------+
         for (int b=0; b < 4; b++) {                                                                                 // | b |    byte    | char |
            int chr = integer & 0xFF;                                   // ein einzelnes Byte des Integers lesen     // +---+------------+------+
            if (chr < 0x20) {                                           // nicht darstellbare Zeichen ersetzen       // | 0 | 0x000000FF |   1  |
               if (chr == 0x00) chr = PLACEHOLDER_NUL_CHAR;             // NUL-Byte          (…)                     // | 1 | 0x0000FF00 |   2  |
               else             chr = PLACEHOLDER_CTRL_CHAR;            // Control-Character (•)                     // | 2 | 0x00FF0000 |   3  |
            }                                                                                                        // | 3 | 0xFF000000 |   4  |
            result = StringConcatenate(result, CharToStr(chr));                                                      // +---+------------+------+
            integer >>= 8;
         }
      }
   }
   return(result);
}


/**
 * Gibt den Inhalt eines Byte-Buffers als hexadezimalen String zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann ein- oder zwei-dimensional sein)
 *
 * @return string
 */
string BufferToHexStr(int buffer[]) {
   int dimensions = ArrayDimension(buffer);
   if (dimensions != 1)
      return(__BuffersToHexStr(buffer));

   string hex="", byte1="", byte2="", byte3="", byte4="", result="";
   int size = ArraySize(buffer);

   // Integers werden binär als {LOBYTE, HIBYTE, LOWORD, HIWORD} gespeichert.
   for (int i=0; i < size; i++) {
      hex    = IntToHexStr(buffer[i]);
      byte1  = StringSubstr(hex, 6, 2);
      byte2  = StringSubstr(hex, 4, 2);
      byte3  = StringSubstr(hex, 2, 2);
      byte4  = StringSubstr(hex, 0, 2);
      result = StringConcatenate(result, " ", byte1, byte2, byte3, byte4);
   }
   if (size > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt den Inhalt eines Byte-Buffers als hexadezimalen String zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann ein- oder zwei-dimensional sein)
 *
 * @return string
 *
 * @access private - Aufruf nur aus BufferToHexStr()
 */
string __BuffersToHexStr(int buffer[][]) {
   int dimensions = ArrayDimension(buffer);
   if (dimensions > 2) return(_EMPTY_STR(catch("__BuffersToHexStr()  too many dimensions of parameter buffer: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));

   if (dimensions == 1)
      return(BufferToHexStr(buffer));

   int dim1=ArrayRange(buffer, 0), dim2=ArrayRange(buffer, 1);

   string hex="", byte1="", byte2="", byte3="", byte4="", result="";

   // Integers werden binär als {LOBYTE, HIBYTE, LOWORD, HIWORD} gespeichert.
   for (int i=0; i < dim1; i++) {
      for (int n=0; n < dim2; n++) {
         hex    = IntToHexStr(buffer[i][n]);
         byte1  = StringSubstr(hex, 6, 2);
         byte2  = StringSubstr(hex, 4, 2);
         byte3  = StringSubstr(hex, 2, 2);
         byte4  = StringSubstr(hex, 0, 2);
         result = StringConcatenate(result, " ", byte1, byte2, byte3, byte4);
      }
   }
   if (dim1 > 0) /*&&*/ if (dim2 > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt ein einzelnes Zeichen (ein Byte) von der angegebenen Position eines Buffers zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 * @param  int pos      - Zeichen-Position
 *
 * @return int - Zeichen-Code oder EMPTY (-1), falls ein Fehler auftrat
 */
int BufferGetChar(int buffer[], int pos) {
   int chars = ArraySize(buffer) << 2;

   if (pos < 0)      return(_EMPTY(catch("BufferGetChar(1)  invalid parameter pos: "+ pos, ERR_INVALID_PARAMETER)));
   if (pos >= chars) return(_EMPTY(catch("BufferGetChar(2)  invalid parameter pos: "+ pos, ERR_INVALID_PARAMETER)));

   int i = pos >> 2;                      // Index des relevanten Integers des Arrays     // +---+------------+
   int b = pos & 0x03;                    // Index des relevanten Bytes des Integers      // | b |    byte    |
                                                                                          // +---+------------+
   int integer = buffer[i] >> (b<<3);                                                     // | 0 | 0x000000FF |
   int chr     = integer & 0xFF;                                                          // | 1 | 0x0000FF00 |
                                                                                          // | 2 | 0x00FF0000 |
   return(chr);                                                                           // | 3 | 0xFF000000 |
}                                                                                         // +---+------------+


/**
 * Konvertiert den in einem Buffer gespeicherten Unicode-String in einen ANSI-String und gibt ihn zurück.
 *
 * @param  int buffer[] - Byte-Buffer (kann in MQL nur über ein Integer-Array abgebildet werden)
 * @param  int from     - Index des ersten Integers der Zeichensequenz
 * @param  int length   - Anzahl der für die Zeichensequenz reservierten Integers
 *
 * @return string - ANSI-String oder Leerstring, falls ein Fehler auftrat
 *
 *
 * TODO: Zur Zeit kann diese Funktion nur mit Integer-Boundaries, nicht mit WCHAR-Boundaries (words) umgehen.
 */
string BufferWCharsToStr(int buffer[], int from, int length) {
   if (from   < 0) return(_EMPTY_STR(catch("BufferWCharsToStr(1)  invalid parameter from: "+ from, ERR_INVALID_PARAMETER)));
   if (length < 0) return(_EMPTY_STR(catch("BufferWCharsToStr(2)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));
   int to = from+length, size=ArraySize(buffer);
   if (to > size)  return(_EMPTY_STR(catch("BufferWCharsToStr(3)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));

   string result = "";

   for (int i=from; i < to; i++) {
      string sChar = "";
      int word, shift=0, integer=buffer[i];

      for (int n=0; n < 2; n++) {
         word = integer >> shift & 0xFFFF;
         if (word == 0)                                              // termination character (0x00)
            break;
         int byte1 = word      & 0xFF;
         int byte2 = word >> 8 & 0xFF;

         if (byte1 && !byte2) sChar = CharToStr(byte1);
         else                 sChar = "¿";                           // multibyte character
         result = StringConcatenate(result, sChar);
         shift += 16;
      }
      if (word == 0)
         break;
   }

   if (!catch("BufferWCharsToStr(4)"))
      return(result);
   return("");
}


/**
 * Resolve the name of the file a Windows shortcut (.lnk file) is pointing to.
 *
 * @return string lnkFilename - Windows shortcut filename
 *
 * @return string - full target filename or EMPTY_STR in case of errors
 */
string GetWindowsShortcutTarget(string lnkFilename) {
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
   //   we have to assume: var $A = -6
   //
   //  +-------------------+---------------------------------------------------------------+
   //  |       Byte-Offset | Description                                                   |
   //  +-------------------+---------------------------------------------------------------+
   //  |                 0 | 'L' (magic value)                                             |
   //  +-------------------+---------------------------------------------------------------+
   //  |              4-19 | GUID                                                          |
   //  +-------------------+---------------------------------------------------------------+
   //  |             20-23 | shortcut flags                                                |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | ...                                                           |
   //  +-------------------+---------------------------------------------------------------+
   //  |             76-77 | var $A (word, 16 bit): size of shell item id list, if present |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | shell item id list, if present                                |
   //  +-------------------+---------------------------------------------------------------+
   //  |       78 + 4 + $A | var $B (dword, 32 bit): size of file location info            |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | file location info                                            |
   //  +-------------------+---------------------------------------------------------------+
   //  |      78 + $A + $B | var $C (dword, 32 bit): size of local volume table            |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | local volume table                                            |
   //  +-------------------+---------------------------------------------------------------+
   //  | 78 + $A + $B + $C | target path string (ending with 0x00)                         |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | ...                                                           |
   //  +-------------------+---------------------------------------------------------------+
   //  |               ... | 0x00                                                          |
   //  +-------------------+---------------------------------------------------------------+
   //
   // @link  http://www.codeproject.com/KB/shell/ReadLnkFile.aspx
   // --------------------------------------------------------------------------

   if (StringLen(lnkFilename) < 4 || StrRight(lnkFilename, 4)!=".lnk")
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(1)  invalid parameter lnkFilename: \""+ lnkFilename +"\"", ERR_INVALID_PARAMETER)));

   // --------------------------------------------------------------------------
   // Get the .lnk-file content:
   // --------------------------------------------------------------------------
   int hFile = _lopen(string lnkFilename, OF_READ);
   if (hFile == HFILE_ERROR)
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(2)->kernel32::_lopen(\""+ lnkFilename +"\")", ERR_WIN32_ERROR)));

   int iNull[], fileSize=GetFileSize(hFile, iNull);
   if (fileSize == INVALID_FILE_SIZE) {
      catch("GetWindowsShortcutTarget(3)->kernel32::GetFileSize(\""+ lnkFilename +"\")", ERR_WIN32_ERROR);
      _lclose(hFile);
      return("");
   }
   int buffer[]; InitializeByteBuffer(buffer, fileSize);

   int bytes = _lread(hFile, buffer, fileSize);
   if (bytes != fileSize) {
      catch("GetWindowsShortcutTarget(4)->kernel32::_lread(\""+ lnkFilename +"\")", ERR_WIN32_ERROR);
      _lclose(hFile);
      return("");
   }
   _lclose(hFile);

   if (bytes < 24) return(_EMPTY_STR(catch("GetWindowsShortcutTarget(5)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   int integers  = ArraySize(buffer);
   int charsSize = bytes;
   int chars[]; ArrayResize(chars, charsSize);     // int-Array in char-Array umwandeln

   for (int i, n=0; i < integers; i++) {
      for (int shift=0; shift<32 && n<charsSize; shift+=8, n++) {
         chars[n] = buffer[i] >> shift & 0xFF;
      }
   }

   // --------------------------------------------------------------------------
   // Check the magic value (offset 0) and the GUID (16 byte from offset 4):
   // --------------------------------------------------------------------------
   // The GUID is telling the version of the .lnk-file format. We expect the
   // following GUID (hex): 01 14 02 00 00 00 00 00 C0 00 00 00 00 00 00 46.
   // --------------------------------------------------------------------------
   if (chars[0] != 'L')                            // test the magic value
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(6)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

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
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(7)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));
   }

   // --------------------------------------------------------------------------
   // Get the flags (4 byte from offset 20) and
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

   bool hasShellItemIdList = (dwFlags & 0x00000001 && 1);
   bool pointsToFileOrDir  = (dwFlags & 0x00000002 && 1);

   if (!pointsToFileOrDir) {
      if (IsLogNotice()) logNotice("GetWindowsShortcutTarget(8)  shortcut target is not a file or directory: \""+ lnkFilename +"\"");
      return("");
   }

   // --------------------------------------------------------------------------
   // Shell item id list (starts at offset 76 with 2 byte length):
   // --------------------------------------------------------------------------
   int A = -6;
   if (hasShellItemIdList) {
      i = 76;
      if (charsSize < i+2)
         return(_EMPTY_STR(catch("GetWindowsShortcutTarget(9)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));
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
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(10)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

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
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(11)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   int C  = chars[i];       i++;    // little endian format
       C |= chars[i] <<  8; i++;
       C |= chars[i] << 16; i++;
       C |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local path string (ending with 0x00):
   // --------------------------------------------------------------------------
   i = 78 + A + B + C;
   if (charsSize < i+1)
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(12)  unknown .lnk file format in \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   string target = "";
   for (; i < charsSize; i++) {
      if (chars[i] == 0x00)
         break;
      target = StringConcatenate(target, CharToStr(chars[i]));
   }
   if (!StringLen(target))
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(13)  invalid target in .lnk file \""+ lnkFilename +"\"", ERR_RUNTIME_ERROR)));

   // --------------------------------------------------------------------------
   // Convert the target path into the long filename format:
   // --------------------------------------------------------------------------
   // GetLongPathNameA() fails if the target file doesn't exist!
   // --------------------------------------------------------------------------
   string lfnBuffer[]; InitializeStringBuffer(lfnBuffer, MAX_PATH);
   if (GetLongPathNameA(target, lfnBuffer[0], MAX_PATH) != 0)        // file does exist
      target = lfnBuffer[0];

   //debug("GetWindowsShortcutTarget(14)  chars="+ ArraySize(chars) +"   A="+ A +"   B="+ B +"   C="+ C +"   target=\""+ target +"\"");

   if (!catch("GetWindowsShortcutTarget(15)"))
      return(target);
   return("");
}


/**
 * Führt eine Anwendung aus und wartet, bis sie beendet ist.
 *
 * @param  string cmdLine - Befehlszeile
 * @param  int    cmdShow - ShowWindow()-Konstante
 *
 * @return int - error status
 */
int WinExecWait(string cmdLine, int cmdShow) {
   /*STARTUPINFO*/int si[]; InitializeByteBuffer(si, STARTUPINFO_size);
   si_setSize      (si, STARTUPINFO_size);
   si_setFlags     (si, STARTF_USESHOWWINDOW);
   si_setShowWindow(si, cmdShow);

   int    iNull[], /*PROCESS_INFORMATION*/pi[]; InitializeByteBuffer(pi, PROCESS_INFORMATION_size);
   string sNull;

   if (!CreateProcessA(sNull, cmdLine, iNull, iNull, false, 0, iNull, sNull, si, pi))
      return(catch("WinExecWait(1)->kernel32::CreateProcessA(cmdLine=\""+ cmdLine +"\")", ERR_WIN32_ERROR));

   int result = WaitForSingleObject(pi_hProcess(pi), INFINITE);

   // @link  http://stackoverflow.com/questions/9369823/how-to-get-a-sub-process-return-code
   //
   // GetExitCodeProcess(pi.hProcess, &exit_code);
   // printf("execution of: \"%s\"\nexit code: %d", cmdLine, exit_code);

   if (result != WAIT_OBJECT_0) {
      if (result == WAIT_FAILED) catch("WinExecWait(2)->kernel32::WaitForSingleObject()", ERR_WIN32_ERROR);
      else                         logNotice("WinExecWait(3)->kernel32::WaitForSingleObject() => "+ WaitForSingleObjectValueToStr(result));
   }

   CloseHandle(pi_hProcess(pi));
   CloseHandle(pi_hThread (pi));

   return(catch("WinExecWait(4)"));
}


/**
 * Read a file into an array. Each element of the array will hold a line of the file, with the end-of-line separator removed.
 *
 * @param  string filename                  - name relative to "{data-directory}\mql4\files" with "\" or "/" separators
 * @param  string result[]                  - array receiving the read lines
 * @param  bool   skipEmptyLines [optional] - whether to skip empty lines (default: no)
 *
 * @return int - number of lines returned in result[] or EMPTY (-1) in case of errors
 */
int FileReadLines(string filename, string result[], bool skipEmptyLines = false) {
   skipEmptyLines = skipEmptyLines!=0;
   ArrayResize(result, 0);

   int hFile, hFileBin, fieldSeparator='\t';

   // open the file
   hFile = FileOpen(filename, FILE_CSV|FILE_READ, fieldSeparator);
   if (hFile < 0) return(_EMPTY(catch("FileReadLines(1)->FileOpen(\""+ filename +"\")")));

   // quick return on an empty file
   if (!FileSize(hFile)) {
      FileClose(hFile);
      return(ifInt(!catch("FileReadLines(2)"), 0, -1));
   }

   // read file line by line
   bool newLine=true, blankLine=false, lineEnd=true, wasSeparator;
   string line="", value="", lines[]; ArrayResize(lines, 0);               // cache for read lines
   int i, len, fPointer;                                                   // line counter and length of the read string

   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                                       // if the last loop reached EOF
         newLine   = true;                                                 // mark begin of a new line = BOL
         blankLine = false;
         lineEnd   = false;
         fPointer  = FileTell(hFile);                                      // points to the start of the current line
      }

      // read line
      value = FileReadString(hFile);                                       // MQL4 bug: FileReadString() stops reading after 4095 chars

      // check for EOL and EOF
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd  = true;
         if (newLine) {
            if (!StringLen(value)) {
               if (FileIsEnding(hFile))                                    // BOL + EOF => not a line => break
                  break;
               blankLine = true;                                           // BOL + EOL => empty line
            }
         }
      }

      // skip empty lines if configured
      if (blankLine) /*&&*/ if (skipEmptyLines)
         continue;

      // store the read string in a new line or append it to the previously read line
      if (newLine) {
         i++;
         ArrayResize(lines, i);
         lines[i-1] = value;
      }
      else {
         // FileReadString() reads max. 4095 chars: check longer lines for a separator
         len = StringLen(lines[i-1]);
         if (len < 4095) {
            wasSeparator = true;
         }
         else {
            if (!hFileBin) {
               hFileBin = FileOpen(filename, FILE_BIN|FILE_READ);
               if (hFileBin < 0) {
                  FileClose(hFile);
                  return(_EMPTY(catch("FileReadLines(3)->FileOpen(\""+ filename +"\")")));
               }
            }
            if (!FileSeek(hFileBin, fPointer+len, SEEK_SET)) {
               FileClose(hFile);
               FileClose(hFileBin);
               return(_EMPTY(catch("FileReadLines(4)->FileSeek(hFileBin, "+ (fPointer+len) +", SEEK_SET)", GetLastError())));
            }
            wasSeparator = (fieldSeparator == FileReadInteger(hFileBin, CHAR_VALUE));
         }

         if (wasSeparator) lines[i-1] = StringConcatenate(lines[i-1], CharToStr(fieldSeparator), value);
         else              lines[i-1] = StringConcatenate(lines[i-1],                            value);
      }
   }

   // check whether the end of file triggered ERR_END_OF_FILE
   int error = GetLastError();
   if (error && error!=ERR_END_OF_FILE) {
      FileClose(hFile);
      if (hFileBin != 0)
         FileClose(hFileBin);
      return(_EMPTY(catch("FileReadLines(5)", error)));
   }

   // close file
   FileClose(hFile);
   if (hFileBin != 0) FileClose(hFileBin);

   // copy read lines into result[] array
   ArrayResize(result, i);
   if (i > 0) ArrayCopy(result, lines);

   if (ArraySize(lines) > 0)
      ArrayResize(lines, 0);
   return(ifInt(!catch("FileReadLines(6)"), i, EMPTY));
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
 * Gibt den Kurznamen eines Symbols zurück.
 * (z.B. GetSymbolName("EURUSD") => "EUR/USD")
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - Kurzname oder der übergebene Ausgangswert, wenn das Symbol unbekannt ist
 *
 *
 * NOTE: Alias für GetSymbolNameOrAlt(symbol, symbol)
 */
string GetSymbolName(string symbol) {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetSymbolName()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
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
 * @see  GetSymbolNameStrict()
 */
string GetSymbolNameOrAlt(string symbol, string altValue="") {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetSymbolNameOrAlt()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   string value = GetSymbolNameStrict(symbol);
   if (!StringLen(value))
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
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetSymbolNameStrict()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   symbol = FindStandardSymbol(symbol, /*strict=*/true);
   if (!StringLen(symbol))
      return("");

   switch (StringGetChar(symbol, 0)) {
      case 'A': if (symbol == "AUDCAD" ) return("AUD/CAD"  );
                if (symbol == "AUDCHF" ) return("AUD/CHF"  );
                if (symbol == "AUDDKK" ) return("AUD/DKK"  );
                if (symbol == "AUDJPY" ) return("AUD/JPY"  );
                if (symbol == "AUDLFX" ) return("AUD-LFX"  );
                if (symbol == "AUDNZD" ) return("AUD/NZD"  );
                if (symbol == "AUDPLN" ) return("AUD/PLN"  );
                if (symbol == "AUDSGD" ) return("AUD/SGD"  );
                if (symbol == "AUDUSD" ) return("AUD/USD"  );
                break;

      case 'B': break;

      case 'C': if (symbol == "CADCHF" ) return("CAD/CHF"  );
                if (symbol == "CADJPY" ) return("CAD/JPY"  );
                if (symbol == "CADLFX" ) return("CAD-LFX"  );
                if (symbol == "CADSGD" ) return("CAD/SGD"  );
                if (symbol == "CHFJPY" ) return("CHF/JPY"  );
                if (symbol == "CHFLFX" ) return("CHF-LFX"  );
                if (symbol == "CHFPLN" ) return("CHF/PLN"  );
                if (symbol == "CHFSGD" ) return("CHF/SGD"  );
                if (symbol == "CHFZAR" ) return("CHF/ZAR"  );
                break;

      case 'D': if (symbol == "DAX"    ) return("DAX"      );
                if (symbol == "DJIA"   ) return("DJIA"     );
                if (symbol == "DJTA"   ) return("DJTA"     );
                break;

      case 'E': if (symbol == "EURAUD" ) return("EUR/AUD"  );
                if (symbol == "EURCAD" ) return("EUR/CAD"  );
                if (symbol == "EURCHF" ) return("EUR/CHF"  );
                if (symbol == "EURCZK" ) return("EUR/CZK"  );
                if (symbol == "EURDKK" ) return("EUR/DKK"  );
                if (symbol == "EURGBP" ) return("EUR/GBP"  );
                if (symbol == "EURHKD" ) return("EUR/HKD"  );
                if (symbol == "EURHUF" ) return("EUR/HUF"  );
                if (symbol == "EURJPY" ) return("EUR/JPY"  );
                if (symbol == "EURLFX" ) return("EUR-LFX"  );
                if (symbol == "EURLVL" ) return("EUR/LVL"  );
                if (symbol == "EURMXN" ) return("EUR/MXN"  );
                if (symbol == "EURNOK" ) return("EUR/NOK"  );
                if (symbol == "EURNZD" ) return("EUR/NZD"  );
                if (symbol == "EURPLN" ) return("EUR/PLN"  );
                if (symbol == "EURRUB" ) return("EUR/RUB"  );
                if (symbol == "EURSEK" ) return("EUR/SEK"  );
                if (symbol == "EURSGD" ) return("EUR/SGD"  );
                if (symbol == "EURTRY" ) return("EUR/TRY"  );
                if (symbol == "EURUSD" ) return("EUR/USD"  );
                if (symbol == "EURX"   ) return("EUR-Index");
                if (symbol == "EURZAR" ) return("EUR/ZAR"  );
                break;

      case 'F': break;

      case 'G': if (symbol == "GBPAUD" ) return("GBP/AUD"  );
                if (symbol == "GBPCAD" ) return("GBP/CAD"  );
                if (symbol == "GBPCHF" ) return("GBP/CHF"  );
                if (symbol == "GBPDKK" ) return("GBP/DKK"  );
                if (symbol == "GBPJPY" ) return("GBP/JPY"  );
                if (symbol == "GBPLFX" ) return("GBP-LFX"  );
                if (symbol == "GBPNOK" ) return("GBP/NOK"  );
                if (symbol == "GBPNZD" ) return("GBP/NZD"  );
                if (symbol == "GBPPLN" ) return("GBP/PLN"  );
                if (symbol == "GBPRUB" ) return("GBP/RUB"  );
                if (symbol == "GBPSEK" ) return("GBP/SEK"  );
                if (symbol == "GBPUSD" ) return("GBP/USD"  );
                if (symbol == "GBPZAR" ) return("GBP/ZAR"  );
                break;

      case 'H': if (symbol == "HKDJPY" ) return("HKD/JPY"  );
                break;

      case 'I': break;

      case 'J': if (symbol == "JPYLFX" ) return("JPY-LFX"  );
                break;

      case 'K': break;

      case 'L': if (symbol == "LFXJPY" ) return("1/JPY-LFX");
                break;

      case 'M': if (symbol == "MXNJPY" ) return("MXN/JPY"  );
                break;

      case 'N': if (symbol == "NAS100" ) return("Nasdaq 100");
                if (symbol == "NASCOMP") return("Nasdaq Composite");
                if (symbol == "NIK225" ) return("Nikkei 225");
                if (symbol == "NOKJPY" ) return("NOK/JPY"  );
                if (symbol == "NOKSEK" ) return("NOK/SEK"  );
                if (symbol == "NZDCAD" ) return("NZD/CAD"  );
                if (symbol == "NZDCHF" ) return("NZD/CHF"  );
                if (symbol == "NZDJPY" ) return("NZD/JPY"  );
                if (symbol == "NZDLFX" ) return("NZD-LFX"  );
                if (symbol == "NZDSGD" ) return("NZD/SGD"  );
                if (symbol == "NZDUSD" ) return("NZD/USD"  );
                break;

      case 'O': break;

      case 'P': if (symbol == "PLNJPY" ) return("PLN/JPY"  );
                break;

      case 'Q': break;

      case 'R': if (symbol == "RUSSELL") return("Russell 2000");
                break;

      case 'S': if (symbol == "SEKJPY" ) return("SEK/JPY"  );
                if (symbol == "SGDJPY" ) return("SGD/JPY"  );
                if (symbol == "SP500"  ) return("S&P 500"  );
                break;

      case 'T': if (symbol == "TRYJPY" ) return("TRY/JPY"  );
                break;

      case 'U': if (symbol == "USDCAD" ) return("USD/CAD"  );
                if (symbol == "USDCHF" ) return("USD/CHF"  );
                if (symbol == "USDCNY" ) return("USD/CNY"  );
                if (symbol == "USDCZK" ) return("USD/CZK"  );
                if (symbol == "USDDKK" ) return("USD/DKK"  );
                if (symbol == "USDHKD" ) return("USD/HKD"  );
                if (symbol == "USDHRK" ) return("USD/HRK"  );
                if (symbol == "USDHUF" ) return("USD/HUF"  );
                if (symbol == "USDINR" ) return("USD/INR"  );
                if (symbol == "USDJPY" ) return("USD/JPY"  );
                if (symbol == "USDLFX" ) return("USD-LFX"  );
                if (symbol == "USDLTL" ) return("USD/LTL"  );
                if (symbol == "USDLVL" ) return("USD/LVL"  );
                if (symbol == "USDMXN" ) return("USD/MXN"  );
                if (symbol == "USDNOK" ) return("USD/NOK"  );
                if (symbol == "USDPLN" ) return("USD/PLN"  );
                if (symbol == "USDRUB" ) return("USD/RUB"  );
                if (symbol == "USDSAR" ) return("USD/SAR"  );
                if (symbol == "USDSEK" ) return("USD/SEK"  );
                if (symbol == "USDSGD" ) return("USD/SGD"  );
                if (symbol == "USDTHB" ) return("USD/THB"  );
                if (symbol == "USDTRY" ) return("USD/TRY"  );
                if (symbol == "USDTWD" ) return("USD/TWD"  );
                if (symbol == "USDX"   ) return("USD-Index");
                if (symbol == "USDZAR" ) return("USD/ZAR"  );
                break;

      case 'V':
      case 'W': break;

      case 'X': if (symbol == "XAGEUR" ) return("XAG/EUR"  );
                if (symbol == "XAGJPY" ) return("XAG/JPY"  );
                if (symbol == "XAGUSD" ) return("XAG/USD"  );
                if (symbol == "XAUEUR" ) return("XAU/EUR"  );
                if (symbol == "XAUJPY" ) return("XAU/JPY"  );
                if (symbol == "XAUUSD" ) return("XAU/USD"  );
                break;

      case 'Y': break;

      case 'Z': if (symbol == "ZARJPY" ) return("ZAR/JPY"  );
                break;
   }

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
 * NOTE: Alias für GetLongSymbolNameOrAlt(symbol, symbol)
 */
string GetLongSymbolName(string symbol) {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetLongSymbolName()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
   return(GetLongSymbolNameOrAlt(symbol, symbol));
}


/**
 * Gibt den Langnamen eines Symbols zurück oder den angegebenen Alternativwert, wenn kein Langname gefunden wurde.
 * (z.B. GetLongSymbolNameOrAlt("USDLFX") => "USD (LFX)")
 *
 * @param  string symbol   - Symbol
 * @param  string altValue - alternativer Rückgabewert
 *
 * @return string - Ergebnis
 */
string GetLongSymbolNameOrAlt(string symbol, string altValue="") {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetLongSymbolNameOrAlt()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   string value = GetLongSymbolNameStrict(symbol);

   if (!StringLen(value))
      value = altValue;

   return(value);
}


/**
 * Gibt den Langnamen eines Symbols zurück.
 * (z.B. GetLongSymbolNameStrict("USDLFX") => "USD (LFX)")
 *
 * @param  string symbol - Symbol
 *
 * @return string - Langname oder Leerstring, falls das Symnol unbekannt ist oder keinen Langnamen hat
 */
string GetLongSymbolNameStrict(string symbol) {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetLongSymbolNameStrict()  invalid parameter symbol: \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   symbol = FindStandardSymbol(symbol, /*strict=*/true);
   if (!StringLen(symbol))
      return("");

   if (symbol == "ASX200"  ) return("ASX 200"                 );
   if (symbol == "AUDLFX"  ) return("AUD (LFX)"               );
   if (symbol == "CADLFX"  ) return("CAD (LFX)"               );
   if (symbol == "CHFLFX"  ) return("CHF (LFX)"               );
   if (symbol == "DJIA"    ) return("Dow Jones Industrial"    );
   if (symbol == "DJTA"    ) return("Dow Jones Transportation");
   if (symbol == "EURLFX"  ) return("EUR (LFX)"               );
   if (symbol == "EURX"    ) return("EUR Index (ICE)"         );
   if (symbol == "GBPLFX"  ) return("GBP (LFX)"               );
   if (symbol == "JPYLFX"  ) return("JPY (LFX)"               );
   if (symbol == "LFXJPY"  ) return("1/JPY (LFX)"             );
   if (symbol == "NAS100"  ) return("Nasdaq 100"              );
   if (symbol == "NASCOMP" ) return("Nasdaq Composite"        );
   if (symbol == "NIK225"  ) return("Nikkei 225"              );
   if (symbol == "NZDLFX"  ) return("NZD (LFX)"               );
   if (symbol == "RUSSELL" ) return("Russell 2000"            );
   if (symbol == "SP500"   ) return("S&P 500"                 );
   if (symbol == "USDLFX"  ) return("USD (LFX)"               );
   if (symbol == "USDX"    ) return("USD Index (ICE)"         );
   if (symbol == "XAGEUR"  ) return("Silver/EUR"              );
   if (symbol == "XAGJPY"  ) return("Silver/JPY"              );
   if (symbol == "XAGUSD"  ) return("Silver/USD"              );
   if (symbol == "XAUEUR"  ) return("Gold/EUR"                );
   if (symbol == "XAUJPY"  ) return("Gold/JPY"                );
   if (symbol == "XAUUSD"  ) return("Gold/USD"                );

   string prefix = StrLeft(symbol, -3);
   string suffix = StrRight(symbol, 3);

   if      (suffix == ".BA") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Balance"      )); }
   else if (suffix == ".BX") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Balance + AuM")); }
   else if (suffix == ".EA") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Equity"       )); }
   else if (suffix == ".EX") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Equity + AuM" )); }
   else if (suffix == ".LA") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Leverage"     )); }
   else if (suffix == ".PL") { if (StrIsDigits(prefix)) return(StringConcatenate("Account ", prefix, " Profit/Loss"  )); }

   return("");
}


/**
 * Pad a string to a certain length with another string.
 *
 * @param  string input
 * @param  int    pad_length
 * @param  string pad_string - Pad-String                                         (default: Leerzeichen  )
 * @param  int    pad_type   - Pad-Type [STR_PAD_LEFT|STR_PAD_RIGHT|STR_PAD_BOTH] (default: STR_PAD_RIGHT)
 *
 * @return string - String oder Leerstring, falls ein Fehler auftrat
 */
string StringPad(string input, int pad_length, string pad_string=" ", int pad_type=STR_PAD_RIGHT) {
   int lenInput = StringLen(input);
   if (pad_length <= lenInput)
      return(input);

   int lenPadStr = StringLen(pad_string);
   if (lenPadStr < 1)
      return(_EMPTY_STR(catch("StringPad(1)  illegal parameter pad_string: \""+ pad_string +"\"", ERR_INVALID_PARAMETER)));

   if (pad_type == STR_PAD_LEFT ) return(StrPadLeft (input, pad_length, pad_string));
   if (pad_type == STR_PAD_RIGHT) return(StrPadRight(input, pad_length, pad_string));


   if (pad_type == STR_PAD_BOTH) {
      int padLengthLeft  = (pad_length-lenInput)/2 + (pad_length-lenInput)%2;
      int padLengthRight = (pad_length-lenInput)/2;

      string paddingLeft  = StrRepeat(pad_string, padLengthLeft );
      string paddingRight = StrRepeat(pad_string, padLengthRight);
      if (lenPadStr > 1) {
         paddingLeft  = StringSubstr(paddingLeft,  0, padLengthLeft );
         paddingRight = StringSubstr(paddingRight, 0, padLengthRight);
      }
      return(paddingLeft + input + paddingRight);
   }

   return(_EMPTY_STR(catch("StringPad(2)  illegal parameter pad_type: "+ pad_type, ERR_INVALID_PARAMETER)));
}


/**
 * Convert a boolean array to a readable representation.
 *
 * @param  bool   array[]
 * @param  string separator [optional] - element separator (default: ", ")
 *
 * @return string - string representation or an empty string in case of errors
 */
string BoolsToStr(bool array[][], string separator = ", ") {
   return(__BoolsToStr(array, array, separator));
}


/**
 * Internal helper function working around the compiler's dimension check. Used only by BoolsToStr().
 */
string __BoolsToStr(bool values2[][], bool values3[][][], string separator) {
   if (separator == "0")                              // (string) NULL
      separator = ", ";
   string result = "";
   int dimensions = ArrayDimension(values2);
   int dim1 = ArrayRange(values2, 0);

   // test for a 1-dimensional array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinBools(values2, separator), "}"));
   }

   int dim2 = ArrayRange(values2, 1);

   // test for a 2-dimensional array
   if (dimensions == 2) {
      string sValues2_X[]; ArrayResize(sValues2_X, dim1);
      bool    values2_Y[]; ArrayResize( values2_Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2_Y[y] = values2[x][y];
         }
         sValues2_X[x] = BoolsToStr(values2_Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(sValues2_X, separator), "}");
      ArrayResize(sValues2_X, 0);
      ArrayResize( values2_Y, 0);
      return(result);
   }

   int dim3 = ArrayRange(values3, 2);

   // test for a 3-dimensional array
   if (dimensions == 3) {
      string sValues3_X[]; ArrayResize(sValues3_X, dim1);
      string sValues3_Y[]; ArrayResize(sValues3_Y, dim2);
      bool    values3_Z[]; ArrayResize( values3_Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3_Z[z] = values3[x][y][z];
            }
            sValues3_Y[y] = BoolsToStr(values3_Z, separator);
         }
         sValues3_X[x] = StringConcatenate("{", JoinStrings(sValues3_Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(sValues3_X, separator), "}");
      ArrayResize(sValues3_X, 0);
      ArrayResize(sValues3_Y, 0);
      ArrayResize( values3_Z, 0);
      return(result);
   }
   return(_EMPTY_STR(catch("__BoolsToStr(1)  too many dimensions of parameter array: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));
}


/**
 * Convert a string array to a readable representation.
 *
 * @param  string array[]
 * @param  string separator [optional] - element separator (default: ", ")
 *
 * @return string - string representation or an empty string in case of errors
 */
string StringsToStr(string array[][], string separator = ", ") {
   return(__StringsToStr(array, array, separator));
}


/**
 * Internal helper function working around the compiler's dimension check. Used only by StringsToStr().
 */
string __StringsToStr(string values2[][], string values3[][][], string separator) {
   if (separator == "0")                              // (string) NULL
      separator = ", ";
   string result = "";
   int dimensions = ArrayDimension(values2);
   int dim1 = ArrayRange(values2, 0);

   // test for a 1-dimensional array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      string copy[]; ArrayResize(copy, 0);
      ArrayCopy(copy, values2);
      DoubleQuoteStrings(copy);

      result = StringConcatenate("{", JoinStrings(copy, separator), "}");
      ArrayResize(copy, 0);
      return(result);
   }

   int dim2 = ArrayRange(values2, 1);

   // test for a 2-dimensional array
   if (dimensions == 2) {
      string sValues2_X[]; ArrayResize(sValues2_X, dim1);
      string  values2_Y[]; ArrayResize( values2_Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2_Y[y] = values2[x][y];             // TODO: catch NPE
         }
         sValues2_X[x] = StringsToStr(values2_Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(sValues2_X, separator), "}");
      ArrayResize(sValues2_X, 0);
      ArrayResize( values2_Y, 0);
      return(result);
   }

   int dim3 = ArrayRange(values3, 2);

   // test for a 3-dimensional array
   if (dimensions == 3) {
      string sValues3_X[]; ArrayResize(sValues3_X, dim1);
      string sValues3_Y[]; ArrayResize(sValues3_Y, dim2);
      string  values3_Z[]; ArrayResize( values3_Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3_Z[z] = values3[x][y][z];       // TODO: catch NPE
            }
            sValues3_Y[y] = StringsToStr(values3_Z, separator);
         }
         sValues3_X[x] = StringConcatenate("{", JoinStrings(sValues3_Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(sValues3_X, separator), "}");
      ArrayResize(sValues3_X, 0);
      ArrayResize(sValues3_Y, 0);
      ArrayResize( values3_Z, 0);
      return(result);
   }
   return(_EMPTY_STR(catch("__StringsToStr(1)  too many dimensions of parameter array: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionStartTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime fxtTime = ServerToFxtTime(serverTime);
   if (fxtTime == NaT)
      return(NaT);

   datetime startTime = GetPrevSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(FxtToServerTime(startTime));
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionEndTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime startTime = GetPrevSessionStartTime.srv(serverTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Startzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionStartTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   int offset = GetServerToFxtTimeOffset(datetime serverTime);
   if (offset == EMPTY_VALUE)
      return(NaT);

   datetime fxtTime = serverTime - offset;
   if (fxtTime < 0)
      return(_NaT(catch("GetSessionStartTime.srv(1)  illegal result "+ fxtTime +" for timezone offset of "+ (-offset/MINUTES) +" minutes", ERR_RUNTIME_ERROR)));

   int dayOfWeek = TimeDayOfWeekEx(fxtTime);

   if (dayOfWeek==SATURDAY || dayOfWeek==SUNDAY)
      return(_NaT(SetLastError(ERR_MARKET_CLOSED)));

   return(fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) + offset);
}


/**
 * Gibt die Endzeit der Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionEndTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   datetime startTime = GetSessionStartTime.srv(serverTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionStartTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime fxtTime = ServerToFxtTime(serverTime);
   if (fxtTime == NaT)
      return(NaT);

   datetime startTime = GetNextSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(FxtToServerTime(startTime));
}


/**
 * Gibt die Endzeit der nächsten Handelssession für die angegebene Serverzeit zurück.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionEndTime.srv(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime startTime = GetNextSessionStartTime.srv(datetime serverTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionStartTime.gmt(datetime gmtTime) {
   datetime fxtTime = GmtToFxtTime(gmtTime);
   if (fxtTime == NaT)
      return(NaT);

   datetime startTime = GetPrevSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(FxtToGmtTime(startTime));
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionEndTime.gmt(datetime gmtTime) {
   datetime startTime = GetPrevSessionStartTime.gmt(gmtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionStartTime.gmt(datetime gmtTime) { // throws ERR_MARKET_CLOSED
   datetime fxtTime = GmtToFxtTime(gmtTime);
   if (fxtTime == NaT)
      return(NaT);

   datetime startTime = GetSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(FxtToGmtTime(startTime));
}


/**
 * Gibt die Endzeit der Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionEndTime.gmt(datetime gmtTime) { // throws ERR_MARKET_CLOSED
   datetime startTime = GetSessionStartTime.gmt(datetime gmtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionStartTime.gmt(datetime gmtTime) {
   datetime fxtTime = GmtToFxtTime(gmtTime);
   if (fxtTime == NaT)
      return(NaT);

   datetime startTime = GetNextSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(FxtToGmtTime(startTime));
}


/**
 * Gibt die Endzeit der nächsten Handelssession für die angegebene GMT-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionEndTime.gmt(datetime gmtTime) {
   datetime startTime = GetNextSessionStartTime.gmt(datetime gmtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für die angegebe FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionStartTime.fxt(datetime fxtTime) {
   if (fxtTime < 0)
      return(_NaT(catch("GetPrevSessionStartTime.fxt(1)  invalid parameter fxtTime: "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) - 1*DAY;
   if (startTime < 0)
      return(_NaT(catch("GetPrevSessionStartTime.fxt(2)  illegal result "+ startTime, ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekEx(startTime);
   if      (dow == SATURDAY) startTime -= 1*DAY;
   else if (dow == SUNDAY  ) startTime -= 2*DAYS;

   return(startTime);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für die angegebene FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetPrevSessionEndTime.fxt(datetime fxtTime) {
   datetime startTime = GetPrevSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der Handelssession für die angegebene FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionStartTime.fxt(datetime fxtTime) { // throws ERR_MARKET_CLOSED
   if (fxtTime < 0)
      return(_NaT(catch("GetSessionStartTime.fxt(1)  invalid parameter fxtTime: "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime);
   if (startTime < 0)
      return(_NaT(catch("GetSessionStartTime.fxt(2)  illegal result "+ startTime, ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekEx(startTime);
   if (dow == SATURDAY || dow == SUNDAY)
      return(_NaT(SetLastError(ERR_MARKET_CLOSED)));

   return(startTime);
}


/**
 * Gibt die Endzeit der Handelssession für die angegebene FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetSessionEndTime.fxt(datetime fxtTime) { // throws ERR_MARKET_CLOSED
   datetime startTime = GetSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für die angegebene FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionStartTime.fxt(datetime fxtTime) {
   if (fxtTime < 0) return(_NaT(catch("GetNextSessionStartTime.fxt()  invalid parameter fxtTime: "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) + 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekEx(startTime);
   if      (dow == SATURDAY) startTime += 2*DAYS;
   else if (dow == SUNDAY  ) startTime += 1*DAY;

   return(startTime);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für die angegebene FXT-Zeit (Forex Time) zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GetNextSessionEndTime.fxt(datetime fxtTime) {
   datetime startTime = GetNextSessionStartTime.fxt(fxtTime);
   if (startTime == NaT)
      return(NaT);

   return(startTime + 1*DAY);
}


/**
 * Convert a character to its hexadecimal representation.
 *
 * @param  int chr - character (1 byte)
 *
 * @return string
 *
 * @example
 *   CharToHexStr(10) => "0A"
 */
string CharToHexStr(int chr) {
   string str="", chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};

   str = StringConcatenate(str, chars[chr >> 4 & 0x0F]);
   str = StringConcatenate(str, chars[chr      & 0x0F]);

   return(str);
}


/**
 * Convert a word to its hexadecimal representation.
 *
 * @param  int word - word (2 bytes)
 *
 * @return string
 *
 * @example
 *   WordToHexStr(2595) => "0A23"
 */
string WordToHexStr(int word) {
   string str="", chars[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};

   str = StringConcatenate(str, chars[word >> 12 & 0x0F]);
   str = StringConcatenate(str, chars[word >>  8 & 0x0F]);
   str = StringConcatenate(str, chars[word >>  4 & 0x0F]);
   str = StringConcatenate(str, chars[word       & 0x0F]);

   return(str);
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

   string hexStr="", chr="", chrs[] = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"};
   int    value = integer;

   while (value != 0) {
      chr    = chrs[value & 0x0F];                  // value % 16
      hexStr = StringConcatenate(chr, hexStr);
      value >>= 4;                                 // value / 16
   }
   return(hexStr);
}


/**
 * Gibt die binäre Repräsentation einer Ganzzahl zurück.
 *
 * @param  int integer - Ganzzahl
 *
 * @return string - binärer Wert
 *
 * Beispiel: IntegerToBinaryStr(109) => "1101101"
 */
string IntegerToBinaryStr(int integer) {
   if (!integer)
      return("0");

   string result = "";

   while (integer != 0) {
      result = StringConcatenate(integer & 0x01, result);
      integer >>= 1;
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
   if (!period)
      period = Period();

   //ex4_GetIntValue(1);

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
      case PERIOD_Q1 : return(PERIOD_MN1);
   }
   return(_NULL(catch("DecreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_PARAMETER)));
}


/**
 * Konvertiert die angegebene FXT-Zeit (Forex Time) nach GMT.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime FxtToGmtTime(datetime fxtTime) {
   int offset = GetFxtToGmtTimeOffset(fxtTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(fxtTime - offset);
}


/**
 * Konvertiert die angegebene FXT-Zeit (Forex Time) nach Serverzeit.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime FxtToServerTime(datetime fxtTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   int offset = GetFxtToServerTimeOffset(fxtTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(fxtTime - offset);
}


/**
 * Zerlegt einen String in Teilstrings.
 *
 * @param  _In_  string input            - zu zerlegender String
 * @param  _In_  string separator        - Trennstring
 * @param  _Out_ string results[]        - Zielarray für die Teilstrings
 * @param  _In_  int    limit [optional] - maximale Anzahl von Teilstrings (default: kein Limit)
 *
 * @return int - Anzahl der Teilstrings oder EMPTY (-1), wennn ein Fehler auftrat
 */
int Explode(string input, string separator, string &results[], int limit = NULL) {
   // Der Parameter input *könnte* eine Referenz auf ein Element des Ergebnisarrays results[] sein, daher erstellen wir
   // vor Modifikation von results[] eine Kopie von input und verarbeiten diese.
   string _input = StringConcatenate(input, "");

   int lenInput     = StringLen(input),
       lenSeparator = StringLen(separator);

   if (StrIsNull(input)) {                   // NULL-Pointer
      ArrayResize(results, 0);
   }
   else if (lenInput == 0) {                 // Leerstring
      ArrayResize(results, 1);
      results[0] = _input;
   }
   else if (!StringLen(separator)) {         // Separator ist Leerstring: String in einzelne Zeichen zerlegen
      if (!limit || limit > lenInput)
         limit = lenInput;
      ArrayResize(results, limit);

      for (int i=0; i < limit; i++) {
         results[i] = StringSubstr(_input, i, 1);
      }
   }
   else {                                    // String in Substrings zerlegen
      int size, pos;
      i = 0;

      while (i < lenInput) {
         ArrayResize(results, size+1);

         pos = StringFind(_input, separator, i);
         if (limit == size+1)
            pos = -1;
         if (pos == -1) {
            results[size] = StringSubstr(_input, i);
            break;
         }
         else if (pos == i) {
            results[size] = "";
         }
         else {
            results[size] = StringSubstr(_input, i, pos-i);
         }
         size++;
         i = pos + lenSeparator;
      }

      if (i == lenInput) {                   // bei abschließendem Separator Substrings mit Leerstring beenden
         ArrayResize(results, size+1);
         results[size] = "";                 // TODO: !!! Wechselwirkung zwischen Limit und Separator am Ende überprüfen
      }
   }

   int error = GetLastError();
   if (!error)
      return(ArraySize(results));
   return(_EMPTY(catch("Explode(1)", error)));
}


/**
 * Return the current account number (with and without a trade server connection).
 *
 * @return int - account number or NULL (0) in case of errors
 */
int GetAccountNumber() {
   static int testAccount;
   if (testAccount != 0)
      return(testAccount);

   int account = AccountNumber();

   if (account == 0x4000) {                                             // im Tester ohne Server-Verbindung
      if (!__isTesting)           return(!catch("GetAccountNumber(1)->AccountNumber()  illegal account number "+ account +" (0x"+ IntToHexStr(account) +")", ERR_RUNTIME_ERROR));
      account = 0;
   }

   if (!account) {                                                      // Titelzeile des Hauptfensters auswerten
      string title = GetInternalWindowTextA(GetTerminalMainWindow());
      if (!StringLen(title))      return(!logInfo("GetAccountNumber(2)->GetInternalWindowTextA(hWndMain) = \"\"", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      int pos = StringFind(title, ":");
      if (pos < 1)                return(!catch("GetAccountNumber(3)  account number separator not found in top window title \""+ title +"\"", ERR_RUNTIME_ERROR));

      string strValue = StrLeft(title, pos);
      if (!StrIsDigits(strValue)) return(!catch("GetAccountNumber(4)  account number in top window title contains non-digits \""+ title +"\"", ERR_RUNTIME_ERROR));

      account = StrToInteger(strValue);
   }

   // Im Tester wird die Accountnummer gecacht, um UI-Deadlocks in deinit() caused by GetWindowText() calls zu vermeiden.
   // Online wird nicht gecacht, da sonst ein Accountwechsel nicht erkannt werden würde.
   if (__isTesting)
      testAccount = account;
   return(account);                                                     // nicht die statische Testervariable zurückgeben (ist online immer 0)
}


/**
 * Gibt den Rechnernamen des laufenden Systems zurück.
 *
 * @return string - Name oder Leerstring, falls ein Fehler auftrat
 */
string GetHostName() {
   static string static.result[1];

   if (!StringLen(static.result[0])) {
      int size[]; ArrayResize(size, 1);
      size[0] = MAX_COMPUTERNAME_LENGTH + 1;
      string buffer[]; InitializeStringBuffer(buffer, size[0]);

      if (!GetComputerNameA(buffer[0], size)) return(_EMPTY_STR(catch("GetHostName(1)->kernel32::GetComputerNameA()", ERR_WIN32_ERROR)));
      static.result[0] = StrToLower(buffer[0]);

      ArrayResize(buffer, 0);
      ArrayResize(size,   0);
   }
   return(static.result[0]);
}


/**
 * Gibt den Offset der angegebenen FXT-Zeit (Forex Time) zu GMT zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return int - Offset in Sekunden, es gilt: GMT + Offset = FXT (immer positive Werte)
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetFxtToGmtTimeOffset(datetime fxtTime) {
   if (fxtTime < 0) return(_EMPTY_VALUE(catch("GetFxtToGmtTimeOffset(1)  invalid parameter fxtTime: "+ fxtTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearEx(fxtTime)-1970;

   // FXT
   if      (fxtTime < transitions.FXT[year][TR_TO_DST.local]) offset = transitions.FXT[year][STD_OFFSET];
   else if (fxtTime < transitions.FXT[year][TR_TO_STD.local]) offset = transitions.FXT[year][DST_OFFSET];
   else                                                       offset = transitions.FXT[year][STD_OFFSET];

   return(offset);
}


/**
 * Gibt den Offset der angegebenen FXT-Zeit (Forex Time) zu Serverzeit zurück.
 *
 * @param  datetime fxtTime - FXT-Zeit
 *
 * @return int - Offset in Sekunden, es gilt: Serverzeit + Offset = FXT (positive Werte für westlich von FXT laufende Server)
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetFxtToServerTimeOffset(datetime fxtTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu FXT festen Zeitzone läuft
   if (lTimezone == "fxt"                  ) return(      0);
   if (lTimezone == "america/new_york+0700") return(      0);
   if (lTimezone == "fxt-0200"             ) return(2*HOURS);
   if (lTimezone == "america/new_york+0500") return(2*HOURS);
   if (lTimezone == "america/new_york"     ) return(7*HOURS);


   if (fxtTime < 0) return(_EMPTY_VALUE(catch("GetFxtToServerTimeOffset(1)  invalid parameter fxtTime: "+ fxtTime, ERR_INVALID_PARAMETER)));


   // Offset FXT zu GMT
   int offset1 = GetFxtToGmtTimeOffset(fxtTime);
   if (offset1 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   // Offset GMT zu Server
   int offset2 = 0;
   if (lTimezone != "gmt") {
      offset2 = GetGmtToServerTimeOffset(fxtTime - offset1);
      if (offset2 == EMPTY_VALUE)
         return(EMPTY_VALUE);
   }
   return(offset1 + offset2);
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zur Serverzeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return int - Offset in Sekunden, es gilt: Serverzeit + Offset = GMT (positive Werte für westlich von GMT laufende Server)
 *               EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetGmtToServerTimeOffset(datetime gmtTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu GMT festen Zeitzone läuft
   if (lTimezone == "gmt") return(0);

   if (gmtTime < 0) return(_EMPTY_VALUE(catch("GetGmtToServerTimeOffset(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearEx(gmtTime)-1970;

   if (lTimezone == "america/new_york") {
      if      (gmtTime < transitions.America_New_York[year][TR_TO_DST.gmt]) offset = -transitions.America_New_York[year][STD_OFFSET];
      else if (gmtTime < transitions.America_New_York[year][TR_TO_STD.gmt]) offset = -transitions.America_New_York[year][DST_OFFSET];
      else                                                                  offset = -transitions.America_New_York[year][STD_OFFSET];
   }
   else if (lTimezone == "europe/berlin") {
      if      (gmtTime < transitions.Europe_Berlin   [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Berlin   [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Berlin   [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Berlin   [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Berlin   [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/kiev") {
      if      (gmtTime < transitions.Europe_Kiev     [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Kiev     [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Kiev     [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Kiev     [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Kiev     [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/london") {
      if      (gmtTime < transitions.Europe_London   [year][TR_TO_DST.gmt]) offset = -transitions.Europe_London   [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_London   [year][TR_TO_STD.gmt]) offset = -transitions.Europe_London   [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_London   [year][STD_OFFSET];
   }
   else if (lTimezone == "europe/minsk") {
      if      (gmtTime < transitions.Europe_Minsk    [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Minsk    [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Minsk    [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Minsk    [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Minsk    [year][STD_OFFSET];
   }
   else if (lTimezone=="fxt" || lTimezone=="america/new_york+0700") {
      if      (gmtTime < transitions.FXT             [year][TR_TO_DST.gmt]) offset = -transitions.FXT             [year][STD_OFFSET];
      else if (gmtTime < transitions.FXT             [year][TR_TO_STD.gmt]) offset = -transitions.FXT             [year][DST_OFFSET];
      else                                                                  offset = -transitions.FXT             [year][STD_OFFSET];
   }
   else if (lTimezone=="fxt-0200" || lTimezone=="america/new_york+0500") {
      if      (gmtTime < transitions.FXT             [year][TR_TO_DST.gmt]) offset = -transitions.FXT             [year][STD_OFFSET] + PLUS_2_H;
      else if (gmtTime < transitions.FXT             [year][TR_TO_STD.gmt]) offset = -transitions.FXT             [year][DST_OFFSET] + PLUS_2_H;
      else                                                                  offset = -transitions.FXT             [year][STD_OFFSET] + PLUS_2_H;
   }
   else return(_EMPTY_VALUE(catch("GetGmtToServerTimeOffset(2)  unknown server timezone configuration \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

   return(offset);
}


/**
 * Gibt den Offset der aktuellen lokalen Zeit zu GMT (Greenwich Mean Time) zurück. Kann nicht im Tester verwendet werden, da
 * (1) dieser Offset der aktuelle Offset der aktuellen Zeit ist und
 * (2) die lokale Zeitzone im Tester modelliert wird und nicht mit der tatsächlichen lokalen Zeitzone übereinstimmt.
 *
 * @return int - Offset in Sekunden oder, es gilt: GMT + Offset = LocalTime
 *               EMPTY_VALUE, falls  ein Fehler auftrat
 */
int GetLocalToGmtTimeOffset() {
   if (__isTesting) return(_EMPTY_VALUE(catch("GetLocalToGmtTimeOffset()", ERR_FUNC_NOT_ALLOWED_IN_TESTER)));

   /*TIME_ZONE_INFORMATION*/int tzi[]; InitializeByteBuffer(tzi, TIME_ZONE_INFORMATION_size);

   int offset, type=GetTimeZoneInformation(tzi);

   if (type != TIME_ZONE_ID_UNKNOWN) {
      offset = tzi_Bias(tzi);
      if (type == TIME_ZONE_ID_DAYLIGHT)
         offset += tzi_DaylightBias(tzi);
      offset *= -60;
   }

   ArrayResize(tzi, 0);
   return(offset);
}


/**
 * Return the current trade server's timezone identifier.
 *
 * @return string - timezone identifier or an empty string in case of errors
 *
 * @see  http://en.wikipedia.org/wiki/Tz_database     [Olson Timezone Database]
 */
string GetServerTimezone() {
   // - The resolved timezone can only change when the trade account changes.
   // - On account change indicators do not perform an init cycle.
   // - The built-in account functions can't be used to detect an account change. They already return new account data even if
   //   the program still operates on previous chart data and processes old ticks. On the first tick received for the new
   //   account ValidBars is 0 (zero). This is used to invalidate and refresh a cached timezone id.
   // - This function is stored in the library to make the cache survive an indicator init cyle.

   #define IDX_SERVER   0
   #define IDX_COMPANY  1
   #define IDX_TIMEZONE 2

   int tick=__ExecutionContext[EC.ticks], validBars=__ExecutionContext[EC.validBars];
   static int lastTick = -1;
   static string lastResult[3]; // {lastServer, lastCompany, lastTimezone};

   if (tick != lastTick) {
      if (StringLen(lastResult[IDX_TIMEZONE]) && !validBars) {
         string server = GetAccountServer(); if (!StringLen(server)) return("");
         if (!StrCompare(server, lastResult[IDX_SERVER])) {
            lastResult[IDX_TIMEZONE] = "";
         }
      }
   }

   if (!StringLen(lastResult[IDX_TIMEZONE])) {
      lastResult[IDX_SERVER ] = GetAccountServer();    if (!StringLen(lastResult[IDX_SERVER ])) return("");
      lastResult[IDX_COMPANY] = GetAccountCompanyId(); if (!StringLen(lastResult[IDX_COMPANY])) return("");

      // prefer a custom company mapping of a full server name
      string customMapping = GetGlobalConfigString("AccountCompanies", lastResult[IDX_SERVER]);    // global only to prevent recursion

      if (StringLen(customMapping) > 0) {
         lastResult[IDX_TIMEZONE] = GetGlobalConfigString("Timezones", customMapping);
      }
      else {
         lastResult[IDX_TIMEZONE] = GetGlobalConfigString("Timezones", lastResult[IDX_SERVER]);
         if (!StringLen(lastResult[IDX_TIMEZONE])) {
            lastResult[IDX_TIMEZONE] = GetGlobalConfigString("Timezones", lastResult[IDX_COMPANY]);
         }
      }
      if (!StringLen(lastResult[IDX_TIMEZONE])) {
         if (IsLogNotice()) logNotice("GetServerTimezone(1)  missing timezone configuration for server "+ DoubleQuoteStr(lastResult[IDX_SERVER]) +" (company id "+ DoubleQuoteStr(lastResult[IDX_COMPANY]) +"), using default timezone \"FXT\"");
         lastResult[IDX_TIMEZONE] = "FXT";
      }
   }

   lastTick = tick;
   return(lastResult[IDX_TIMEZONE]);
}


/**
 * Konvertiert die angegebene GMT-Zeit nach FXT-Zeit (Forex Time).
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime GmtToFxtTime(datetime gmtTime) {
   int offset = GetGmtToFxtTimeOffset(gmtTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(gmtTime - offset);
}


/**
 * Konvertiert die angegebene GMT-Zeit nach Serverzeit.
 *
 * @param  datetime gmtTime - GMT-Zeit
 *
 * @return datetime - Serverzeit oder NaT, falls ein Fehler auftrat
 */
datetime GmtToServerTime(datetime gmtTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   int offset = GetGmtToServerTimeOffset(gmtTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(gmtTime - offset);
}


/**
 * Gibt die nächstgrößere Periode der angegebenen Periode zurück.
 *
 * @param  int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - Nächstgrößere Periode oder der ursprüngliche Wert, wenn keine größere Periode existiert.
 */
int IncreasePeriod(int period = 0) {
   if (!period)
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
      case PERIOD_MN1: return(PERIOD_Q1 );
      case PERIOD_Q1 : return(PERIOD_Q1 );
   }
   return(_NULL(catch("IncreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_PARAMETER)));
}


string __registeredObjects[];
int    __registeredOjectsCounter = 0;


/**
 * Create a chart object and register it for auto-removal on Program::deinit(). Function parameters are identical to the
 * built-in function ObjectCreate().
 *
 * @param  string   name   - unique object name (max. 63 chars, may contain line breaks)
 * @param  int      type   - object type identifier
 * @param  int      window - index of the chart window to create the object in
 * @param  datetime time1  - time value of the first coordinate pair
 * @param  double   price1 - price value of the first coordinate pair
 * @param  datetime time2  - time value of the second coordinate pair
 * @param  double   price2 - price value of the second coordinate pair
 * @param  datetime time3  - time value of the third coordinate pair
 * @param  double   price3 - price value of the third coordinate pair
 *
 * @return bool - success status
 *
 * TODO:
 *  - 106.000 initial calls on terminal start with 7 open charts
 *  - SuperBars in regular charts: permant non-stopping calls (after a few minutes more than 1.000.000)
 *  - SuperBars in offline charts: 271 calls on every tick
 *  - move elsewhere as the library is not a singleton (there can be multiple instances)
 */
bool ObjectCreateRegister(string name, int type, int window, datetime time1, double price1, datetime time2, double price2, datetime time3, double price3) {
   bool success = false;

   // create the object
   switch (type) {
      case OBJ_VLINE        :    // Vertical line. Uses time of first coordinate pair.
      case OBJ_HLINE        :    // Horizontal line. Uses price of first coordinate pair.
      case OBJ_TREND        :    // Trend line. Uses 2 coordinate pairs.
      case OBJ_TRENDBYANGLE :    // Trend by angle. Uses 1 coordinate pair.
      case OBJ_REGRESSION   :    // Regression. Uses times of first two coordinate pairs.
      case OBJ_CHANNEL      :    // Channel. Uses 3 coordinate pairs.
      case OBJ_STDDEVCHANNEL:    // Standard deviation channel. Uses times of first two coordinate pairs.
      case OBJ_GANNLINE     :    // Gann line. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_GANNFAN      :    // Gann fan. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_GANNGRID     :    // Gann grid. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_FIBO         :    // Fibonacci retracement. Uses 2 coordinate pairs.
      case OBJ_FIBOTIMES    :    // Fibonacci time zones. Uses 2 coordinate pairs.
      case OBJ_FIBOFAN      :    // Fibonacci fan. Uses 2 coordinate pairs.
      case OBJ_FIBOARC      :    // Fibonacci arcs. Uses 2 coordinate pairs.
      case OBJ_EXPANSION    :    // Fibonacci expansions. Uses 3 coordinate pairs.
      case OBJ_FIBOCHANNEL  :    // Fibonacci channel. Uses 3 coordinate pairs.
      case OBJ_RECTANGLE    :    // Rectangle. Uses 2 coordinate pairs.
      case OBJ_TRIANGLE     :    // Triangle. Uses 3 coordinate pairs.
      case OBJ_ELLIPSE      :    // Ellipse. Uses 2 coordinate pairs.
      case OBJ_PITCHFORK    :    // Andrews pitchfork. Uses 3 coordinate pairs.
      case OBJ_CYCLES       :    // Cycles. Uses 2 coordinate pairs.
      case OBJ_TEXT         :    // Text. Uses 1 coordinate pair.
      case OBJ_ARROW        :    // Arrows. Uses 1 coordinate pair.
      case OBJ_LABEL        :    // Text label. Uses 1 coordinate pair in pixels.
      default:
         success = ObjectCreate(name, type, window, time1, price1, time2, price2, time3, price3);
   }
   if (!success) return(!catch("ObjectCreateRegister(1)  name=\""+ name +"\"  type="+ type +"  window="+ window, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

   // register the object for auto-removal
   int size = ArraySize(__registeredObjects);
   if (size <= __registeredOjectsCounter) {
      if (!size) size = 512;
      size <<= 1;                                           // prevent re-allocation on every call (initial size 1024)
      ArrayResize(__registeredObjects, size);
      if (size >= 262144) debug("ObjectCreateRegister(2)  sizeOf(registeredObjects) = "+ size);
   }
   __registeredObjects[__registeredOjectsCounter] = name;
   __registeredOjectsCounter++;

   //if (Period() == 202)
   //debug("ObjectCreateRegister(0.1)  Tick="+ __ExecutionContext[EC.ticks] +"  objectsCounter="+ __registeredOjectsCounter +"  \""+ name +"\"");
   return(true);
}


/**
 * Delete all chart objects marked for auto-removal. Called on Program::deinit().
 *
 * @return int - error status
 */
int DeleteRegisteredObjects() {
   for (int i=0; i < __registeredOjectsCounter; i++) {
      if (ObjectFind(__registeredObjects[i]) != -1) {
         if (!ObjectDelete(__registeredObjects[i])) logWarn("DeleteRegisteredObjects(1)->ObjectDelete(name=\""+ __registeredObjects[i] +"\")", intOr(GetLastError(), ERR_RUNTIME_ERROR));
      }
   }
   ArrayResize(__registeredObjects, 0);
   __registeredOjectsCounter = 0;
   return(catch("DeleteRegisteredObjects(2)"));
}


/**
 * Konvertiert die angegebene Serverzeit nach FXT (Forex Time).
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime ServerToFxtTime(datetime serverTime) {
   int offset = GetServerToFxtTimeOffset(serverTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(serverTime - offset);
}


/**
 * Konvertiert die angegebene Serverzeit nach GMT.
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - GMT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime ServerToGmtTime(datetime serverTime) {
   int offset = GetServerToGmtTimeOffset(serverTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(serverTime - offset);
}


/**
 * Findet alle zum angegebenen Muster passenden Dateinamen. Die Pseudo-Verzeichnisse "." und ".." werden nicht berücksichtigt.
 *
 * @param  string pattern     - Namensmuster mit Wildcards nach Windows-Konventionen
 * @param  string lpResults[] - Zeiger auf Array zur Aufnahme der Suchergebnisse
 * @param  int    flags       - zusätzliche Suchflags: [FF_DIRSONLY | FF_FILESONLY | FF_SORT] (default: keine)
 *
 *                              FF_DIRSONLY:  return only directory entries which match the pattern (default: all entries)
 *                              FF_FILESONLY: return only file entries which match the pattern      (default: all entries)
 *                              FF_SORT:      sort returned entries                                 (default: NTFS: sorting, FAT: no sorting)
 *
 * @return int - Anzahl der gefundenen Einträge oder EMPTY (-1), falls ein Fehler auftrat
 */
int FindFileNames(string pattern, string &lpResults[], int flags = NULL) {
   if (!StringLen(pattern)) return(_EMPTY(catch("FindFileNames(1)  illegal parameter pattern: \""+ pattern +"\"", ERR_INVALID_PARAMETER)));

   ArrayResize(lpResults, 0);

   string name = "";
   /*WIN32_FIND_DATA*/ int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA_size);
   int hSearch = FindFirstFileA(pattern, wfd), next=hSearch;

   while (next > 0) {
      name = wfd_FileName(wfd);
      while (true) {
         if (wfd_FileAttribute_Directory(wfd)) {
            if (flags & FF_FILESONLY && 1)  break;
            if (name ==  ".")               break;
            if (name == "..")               break;
         }
         else if (flags & FF_DIRSONLY && 1) break;
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

   if (flags & FF_SORT && size > 1) {                                // TODO: Ergebnisse ggf. sortieren
   }
   return(size);
}


/**
 * Konvertiert drei R-G-B-Farbwerte in eine Farbe.
 *
 * @param  int red   - Rotanteil  (0-255)
 * @param  int green - Grünanteil (0-255)
 * @param  int blue  - Blauanteil (0-255)
 *
 * @return color - Farbe oder EMPTY (-1), falls ein Fehler auftrat
 *
 * Beispiel: RGB(255, 255, 255) => 0x00FFFFFF (weiß)
 */
color RGB(int red, int green, int blue) {
   if (0 <= red && red <= 255) {
      if (0 <= green && green <= 255) {
         if (0 <= blue && blue <= 255) {
            return(red + green<<8 + blue<<16);

         } else catch("RGB(1)  invalid parameter blue: "+ blue, ERR_INVALID_PARAMETER);
      } else    catch("RGB(2)  invalid parameter green: "+ green, ERR_INVALID_PARAMETER);
   } else       catch("RGB(3)  invalid parameter red: "+ red, ERR_INVALID_PARAMETER);

   return(EMPTY);
}


/**
 * Convert a RGB color to the HSL color model (hue, saturation, lightness). This model is used by the Windows color picker.
 *
 * @param  _In_  color   rgb              - RGB color
 * @param  _Out_ double &hsl[]            - array the resulting HSL color components are copied to (each in the range 0...1)
 * @param  _In_  bool    human [optional] - whether the color components should be returned in human-readable format
 *                                          (default: no, each in the range 0...1)
 * @return int - error status
 */
int RGBToHSL(color rgb, double &hsl[], bool human = false) {
   human = (human!=0);
   if (ArrayDimension(hsl) != 1) return(catch("RGBToHSL(1)  illegal parameter hsl (dimensions: "+ ArrayDimension(hsl) +")", ERR_INCOMPATIBLE_ARRAY));

   int iR = rgb       & 0xFF;
   int iG = rgb >>  8 & 0xFF;
   int iB = rgb >> 16 & 0xFF;

   double dR=iR/255., dG=iG/255., dB=iB/255.;                     // scale values to the range 0...1

   double dMin   = MathMin(dR, MathMin(dG, dB)); int iMin   = Min(iR, Min(iG, iB));
   double dMax   = MathMax(dR, MathMax(dG, dB)); int iMax   = Max(iR, Max(iG, iB));
   double dDelta = dMax - dMin;                  int iDelta = iMax - iMin;

   double hue=0, sat=0, lum=(dMax + dMin)/2;

   if (iDelta != 0) {
      if      (iR == iMax)  hue =     (dG-dB)/dDelta;
      else if (iG == iMax)  hue = 2 + (dB-dR)/dDelta;
      else   /*iB == iMax*/ hue = 4 + (dR-dG)/dDelta;

      hue = MathModFix(hue, 6) * 60;
      if (hue < 0) hue += 360;

      if (lum < 0.5) sat = dDelta / (    dMax + dMin);
      else           sat = dDelta / (2 - dMax - dMin);
   }

   if (ArraySize(hsl) != 3)
      ArrayResize(hsl, 3);

   hsl[HSL_HUE       ] = hue / 360;
   hsl[HSL_SATURATION] = sat;
   hsl[HSL_LIGHTNESS ] = lum;

   if (human) {
      hsl[HSL_HUE       ] = hue;
      hsl[HSL_SATURATION] = sat * 100;
      hsl[HSL_LIGHTNESS ] = lum * 100;
   }
   return(catch("RGBToHSL(2)"));
}


/**
 * Convert a HSL color to the RGB color model.
 *
 * @param  double hsl[] - array holding HSL color components (hue, saturation, lightness) in the range 0...1
 *
 * @return color - RGB color or EMPTY (-1) in case of errors
 */
color HSLToRGB(double hsl[3]) {
   if (ArrayDimension(hsl) != 1) return(_EMPTY(catch("HSLToRGB(1)  illegal parameter hsl (dimensions: "+ ArrayDimension(hsl) +")", ERR_INCOMPATIBLE_ARRAY)));
   if (ArraySize(hsl) != 3)      return(_EMPTY(catch("HSLToRGB(2)  illegal parameter hsl (size: "+ ArraySize(hsl) +")", ERR_INCOMPATIBLE_ARRAY)));

   double hue = hsl[HSL_HUE       ];
   double sat = hsl[HSL_SATURATION];
   double lum = hsl[HSL_LIGHTNESS ];

   if (hue < 0 || hue > 1)       return(_EMPTY(catch("HSLToRGB(3)  invalid parameter hsl.hue: "+ NumberToStr(hue, ".1+"), ERR_INVALID_PARAMETER)));
   if (sat < 0 || sat > 1)       return(_EMPTY(catch("HSLToRGB(4)  invalid parameter hsl.saturation: "+ NumberToStr(sat, ".1+"), ERR_INVALID_PARAMETER)));
   if (lum < 0 || lum > 1)       return(_EMPTY(catch("HSLToRGB(5)  invalid parameter hsl.lightness: "+ NumberToStr(lum, ".1+"), ERR_INVALID_PARAMETER)));

   hue = MathModFix(hue*360, 360);

   double h = hue / 60;
   double c = (1 - MathAbs(2*lum - 1)) * sat;
   double x = c * (1 - MathAbs(MathModFix(h, 2) - 1));

   double dR, dG, dB;

   int i = h;                          // integer part of h (0...5)
   switch (i) {
      case 0: dR = c; dG = x; break;
      case 1: dR = x; dG = c; break;
      case 2: dG = c; dB = x; break;
      case 3: dG = x; dB = c; break;
      case 4: dR = x; dB = c; break;
      case 5: dR = c; dB = x; break;
   }

   double m = lum - c/2;
   dR += m;
   dG += m;
   dB += m;

   int iR = MathRound(dR * 255);
   int iG = MathRound(dG * 255);
   int iB = MathRound(dB * 255);

   color rgb = iR + iG<<8 + iB<<16;

   if (!catch("HSLToRGB(6)"))
      return(rgb);
   return(EMPTY);
}


/**
 * Adjust an RGB color using the HSL color model (same as the Windows color picker).
 *
 * @param  color  rgb        - color to adjust
 * @param  double hue        - shift from -360° to +360°                  (NULL for no change)
 * @param  double saturation - adjustment from -100% to positive infinite (NULL for no change)
 * @param  double lightness  - adjustment from -100% to positive infinite (NULL for no change)
 *
 * @return color - adjusted color or EMPTY (-1) in case of errors
 *
 * Example:
 * --------
 *   ModifyColor(C'90,128,162', NULL, NULL, 30) => C'119,168,212'          // lightness of the color is increased by 30%
 */
color ModifyColor(color rgb, double hue, double saturation, double lightness) {
   if (rgb == CLR_NONE) return(CLR_NONE);

   if (rgb >= 0) {
      if (-360 <= hue && hue <= 360) {
         if (saturation >= -100) {                                         // max. reduction is -100%
            if (lightness >= -100) {                                       // max. reduction is -100%

               // convert color to HSL
               double hsl[];
               RGBToHSL(rgb, hsl);

               // adjust hue
               if (NE(hue, 0)) {
                  hsl[HSL_HUE] += hue/360;
                  if      (hsl[HSL_HUE] < 0) hsl[HSL_HUE] += 1;            // limit range to 0...1
                  else if (hsl[HSL_HUE] > 1) hsl[HSL_HUE] -= 1;
               }

               // adjust saturation
               if (NE(saturation, 0)) {
                  hsl[HSL_SATURATION] *= (1 + saturation/100);
                  hsl[HSL_SATURATION]  = MathMax(hsl[HSL_SATURATION], 0);  // limit range to 0...1
                  hsl[HSL_SATURATION]  = MathMin(hsl[HSL_SATURATION], 1);
               }

               // adjust lightness
               if (NE(lightness, 0)) {
                  hsl[HSL_LIGHTNESS] *= (1 + lightness/100);
                  hsl[HSL_LIGHTNESS]  = MathMax(hsl[HSL_LIGHTNESS], 0);    // limit range to 0...1
                  hsl[HSL_LIGHTNESS]  = MathMin(hsl[HSL_LIGHTNESS], 1);
               }

               // convert color back to RGB
               color result = HSLToRGB(hsl);
               ArrayResize(hsl, 0);

               if (!catch("ModifyColor(1)"))
                  return(result);

            } else catch("ModifyColor(2)  invalid parameter lightness: "+ NumberToStr(lightness, ".1+"), ERR_INVALID_PARAMETER);
         } else    catch("ModifyColor(3)  invalid parameter saturation: "+ NumberToStr(saturation, ".1+"), ERR_INVALID_PARAMETER);
      } else       catch("ModifyColor(4)  invalid parameter hue: "+ NumberToStr(hue, ".1+"), ERR_INVALID_PARAMETER);
   } else          catch("ModifyColor(5)  invalid parameter rgb: "+ rgb, ERR_INVALID_PARAMETER);

   return(EMPTY);
}


/**
 * Convert a double to a string with up to 16 decimal digits.
 *
 * @param  double value  - value
 * @param  int    digits - number of decimals
 *
 * @return string
 */
string DoubleToStrEx(double value, int digits) {
   string sValue = value;
   if (StringGetChar(sValue, 3) == '#')                              // "-1.#IND0000" => NaN
      return(sValue);                                                // "-1.#INF0000" => Infinite

   if (digits < 0 || digits > 16)
      return(_EMPTY_STR(catch("DoubleToStrEx()  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER)));

   /*
   double decimals[17] = { 1.0,                                      // Der Compiler interpretiert über mehrere Zeilen verteilte Array-Initializer
                          10.0,                                      // als in einer Zeile stehend und gibt bei Fehlern falsche Zeilennummern zurück.
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

   double integer      = MathFloor(value);
   string strInteger   = Round(integer);

   double remainder    = MathRound((value-integer) * decimals[digits]);
   string strRemainder = "";

   for (int i=0; i < digits; i++) {
      double fraction = MathFloor(remainder/10);
      int    digit    = MathRound(remainder - fraction*10);
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
 * Wrap values of a string array in double quote characters. Modifies the passed array. Not initialized array elements
 * (string NULL pointers) are not modified.
 *
 * @param  string values[]
 *
 * @return bool - success status
 */
bool DoubleQuoteStrings(string &values[]) {
   if (ArrayDimension(values) > 1) return(!catch("DoubleQuoteStrings(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY));

   int size = ArraySize(values);

   for (int i=0; i < size; i++) {
      if (!StrIsNull(values[i]))                                     // skip NULL pointers
         values[i] = StringConcatenate("\"", values[i], "\"");
   }
   return(true);
}


/**
 * Store LFX_ORDER data in the library or restore it from data stored in the library.
 *
 * @param  _In_    bool   store    - processing direction: TRUE  = store passed parameters in the library
 *                                                         FALSE = restore parameters from data in the library
 * @param  _InOut_ int    orders[] - structs LFX_ORDER[]
 * @param  _InOut_ int    iData [] - integer data
 * @param  _InOut_ bool   bData [] - boolean data
 * @param  _InOut_ double dData [] - double data
 *
 * @return int - number of copied LFX_ORDER structs or EMPTY (-1) in case of errors
 */
int ChartInfos.CopyLfxOrders(bool store, /*LFX_ORDER*/int orders[][], int iData[][], bool bData[][], double dData[][]) {
   store = store!=0;

   static int    static_orders[][LFX_ORDER_intSize];
   static int    static_iData [][1];
   static bool   static_bData [][3];
   static double static_dData [][7];

   if (store) {
      ArrayResize(static_orders, 0);
      ArrayResize(static_iData,  0);
      ArrayResize(static_bData,  0);
      ArrayResize(static_dData,  0);

      if (ArrayRange(orders, 0) > 0) ArrayCopy(static_orders, orders);
      if (ArrayRange(iData,  0) > 0) ArrayCopy(static_iData,  iData );
      if (ArrayRange(bData,  0) > 0) ArrayCopy(static_bData,  bData );
      if (ArrayRange(dData,  0) > 0) ArrayCopy(static_dData,  dData );

      if (IsError(catch("ChartInfos.CopyLfxOrders(1)"))) return(EMPTY);
   }
   else {
      ArrayResize(orders, 0);
      ArrayResize(iData,  0);
      ArrayResize(bData,  0);
      ArrayResize(dData,  0);

      if (ArrayRange(static_orders, 0) > 0) ArrayCopy(orders, static_orders);
      if (ArrayRange(static_iData,  0) > 0) ArrayCopy(iData,  static_iData );
      if (ArrayRange(static_bData,  0) > 0) ArrayCopy(bData,  static_bData );
      if (ArrayRange(static_dData,  0) > 0) ArrayCopy(dData,  static_dData );

      if (IsError(catch("ChartInfos.CopyLfxOrders(2)"))) return(EMPTY);
   }

   return(ArrayRange(orders, 0));
}


/**
 * Convert an array of character values to a human-readable string.
 *
 * @param  int    values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string CharsToStr(int values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("CharsToStr(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = StringConcatenate("'", CharToStr(values[i]), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Convert a double array with max. 3 dimensions to a human-readable string.
 *
 * @param  double values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string DoublesToStr(double values[][], string separator = ", ") {
   return(__DoublesToStr(values, values, separator));
}


/**
 * Internal helper for DoublesToStr(), works around the compiler's dimension check.
 *
 * @access private
 */
string __DoublesToStr(double values2[][], double values3[][][], string separator) {
   if (separator == "0")               // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result = "";

   // 1-dimensional array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoubles(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);

   // 2-dimensional array
   if (dimensions == 2) {
      string sValues2.X[]; ArrayResize(sValues2.X, dim1);
      double  values2.Y[]; ArrayResize( values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         sValues2.X[x] = DoublesToStr(values2.Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(sValues2.X, separator), "}");
      ArrayResize(sValues2.X, 0);
      ArrayResize( values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);

   // 3-dimensional array
   if (dimensions == 3) {
      string sValues3.X[]; ArrayResize(sValues3.X, dim1);
      string sValues3.Y[]; ArrayResize(sValues3.Y, dim2);
      double  values3.Z[]; ArrayResize( values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            sValues3.Y[y] = DoublesToStr(values3.Z, separator);
         }
         sValues3.X[x] = StringConcatenate("{", JoinStrings(sValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(sValues3.X, separator), "}");
      ArrayResize(sValues3.X, 0);
      ArrayResize(sValues3.Y, 0);
      ArrayResize( values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__DoublesToStr(1)  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));
}


/**
 * Convert a double array with max. 3 dimensions to a human-readable string using a custom precision of up to 16 digits.
 *
 * @param  double values[]  - values to convert
 * @param  string separator - separator (default: ", ")
 * @param  int    digits    - number of decimal digits (0-16)
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string DoublesToStrEx(double values[][], string separator, int digits) {
   return(__DoublesToStrEx(values, values, separator, digits));
}


/**
 * Internal helper for DoublesToStrEx(), works around the compiler's dimension check.
 *
 * @access private
 */
string __DoublesToStrEx(double values2[][], double values3[][][], string separator, int digits) {
   if (digits < 0 || digits > 16) return(_EMPTY_STR(catch("__DoublesToStrEx(1)  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER)));

   if (separator == "0")               // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result = "";

   // 1-dimensional array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoublesEx(values2, digits, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);

   // 2-dimensional array
   if (dimensions == 2) {
      string sValues2.X[]; ArrayResize(sValues2.X, dim1);
      double  values2.Y[]; ArrayResize( values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         sValues2.X[x] = DoublesToStrEx(values2.Y, separator, digits);
      }

      result = StringConcatenate("{", JoinStrings(sValues2.X, separator), "}");
      ArrayResize(sValues2.X, 0);
      ArrayResize( values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);

   // 3-dimensional array
   if (dimensions == 3) {
      string sValues3.X[]; ArrayResize(sValues3.X, dim1);
      string sValues3.Y[]; ArrayResize(sValues3.Y, dim2);
      double  values3.Z[]; ArrayResize( values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            sValues3.Y[y] = DoublesToStrEx(values3.Z, separator, digits);
         }
         sValues3.X[x] = StringConcatenate("{", JoinStrings(sValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(sValues3.X, separator), "}");
      ArrayResize(sValues3.X, 0);
      ArrayResize(sValues3.Y, 0);
      ArrayResize( values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__DoublesToStrEx(2)  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));
}


/**
 * Convert an integer array with max. 3 dimensions to a human-readable string.
 *
 * @param  int    values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string IntsToStr(int values[][], string separator = ", ") {
   return(__IntsToStr(values, values, separator));
}


/**
 * Internal helper for IntsToStr(), works around the compiler's dimension check.
 *
 * @access private
 */
string __IntsToStr(int values2[][], int values3[][][], string separator) {
   if (separator == "0")               // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result = "";

   // 1-dimensional array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinInts(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);

   // 2-dimensional array
   if (dimensions == 2) {
      string sValues2.X[]; ArrayResize(sValues2.X, dim1);
      int     values2.Y[]; ArrayResize( values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         sValues2.X[x] = IntsToStr(values2.Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(sValues2.X, separator), "}");
      ArrayResize(sValues2.X, 0);
      ArrayResize( values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);

   // 3-dimensional array
   if (dimensions == 3) {
      string sValues3.X[]; ArrayResize(sValues3.X, dim1);
      string sValues3.Y[]; ArrayResize(sValues3.Y, dim2);
      int     values3.Z[]; ArrayResize( values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            sValues3.Y[y] = IntsToStr(values3.Z, separator);
         }
         sValues3.X[x] = StringConcatenate("{", JoinStrings(sValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(sValues3.X, separator), "}");
      ArrayResize(sValues3.X, 0);
      ArrayResize(sValues3.Y, 0);
      ArrayResize( values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__IntsToStr(1)  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAY)));
}


/**
 * Convert an array with money amounts to a human-readable string (with 2 digits per value).
 *
 * @param  double values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string MoneysToStr(double values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("MoneysToStr(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = DoubleToStr(values[i], 2);
      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Convert an array with operation types to a human-readable string.
 *
 * @param  int    values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string OperationTypesToStr(int values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("OperationTypesToStr(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   string strings[]; ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = OperationTypeToStr(values[i]);
      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Convert an array with price quotes to a human-readable string (formatted with the current PriceFormat).
 *
 * @param  double values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string RatesToStr(double values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("RatesToStr(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   if (size == 0)
      return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (!values[i]) strings[i] = "0";
      else            strings[i] = NumberToStr(values[i], PriceFormat);

      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Alias of RatesToStr()
 *
 * Convert an array with price quotes to a human-readable string (formatted with the current PriceFormat).
 *
 * @param  double values[]
 * @param  string separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string PricesToStr(double values[], string separator = ", ") {
   return(RatesToStr(values, separator));
}


/**
 * Convert an array of order tickets to a human-readable string, additionally containing the lotsize per ticket.
 *
 * @param  int    tickets[]
 * @param  string separator - separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string TicketsToStr.Lots(int tickets[], string separator = ", ") {
   if (ArrayDimension(tickets) != 1) return(_EMPTY_STR(catch("TicketsToStr.Lots(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(tickets);
   if (!size) return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   OrderPush("TicketsToStr.Lots(2)");
   string result="", sValue="";

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"));
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"));
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.Lots(3)");
   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Convert an array of order tickets to a human-readable string, additionally containing symbol and lotsize per ticket.
 *
 * @param  int    tickets[]
 * @param  string separator - separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string TicketsToStr.LotsSymbols(int tickets[], string separator = ", ") {
   if (ArrayDimension(tickets) != 1) return(_EMPTY_STR(catch("TicketsToStr.LotsSymbols(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(tickets);
   if (!size) return("{}");

   if (separator == "0")               // (string) NULL
      separator = ", ";

   string result="", sValue="";
   OrderPush("TicketsToStr.LotsSymbols(2)");

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.LotsSymbols(3)");
   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Resolve the total position of the passed tickets and convert it to a human-readable string.
 *
 * @param  int tickets[]
 *
 * @return string - string with total position sizes or an empty string in case of errors
 */
string TicketsToStr.Position(int tickets[]) {
   if (ArrayDimension(tickets) != 1) return(_EMPTY_STR(catch("TicketsToStr.Position(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAY)));

   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return("(empty)");

   double longPosition, shortPosition, totalPosition, hedgedPosition;
   OrderPush("TicketsToStr.Position(2)");

   for (int i=0; i < ticketsSize; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if (IsLongOrderType(OrderType())) longPosition  += OrderLots();
            else                              shortPosition += OrderLots();
         }
         else GetLastError();
      }
   }

   OrderPop("TicketsToStr.Position(3)");

   longPosition   = NormalizeDouble(longPosition,  2);
   shortPosition  = NormalizeDouble(shortPosition, 2);
   totalPosition  = NormalizeDouble(longPosition - shortPosition, 2);
   hedgedPosition = MathMin(longPosition, shortPosition);
   bool isPosition = longPosition || shortPosition;

   string result = "";
   if (!isPosition)         result = "0 lot";
   else if (!totalPosition) result = "±"+ NumberToStr(longPosition,  ".+")                                                                          +" lot (hedged)";
   else                     result =      NumberToStr(totalPosition, ".+") + ifString(!hedgedPosition, "", " ±"+ NumberToStr(hedgedPosition, ".+")) +" lot";

   return(result);
}


/**
 * Convert a datetime array to a human-readable string.
 *
 * @param  datetime values[]
 * @param  string   separator - value separator (default: ", ")
 *
 * @return string - human-readable string or an empty string in case of errors
 */
string TimesToStr(datetime values[], string separator=", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("TimesToStr(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if      (values[i] <  0) strings[i] = "-1";
      else if (values[i] == 0) strings[i] =  "0";
      else                     strings[i] = StringConcatenate("'", TimeToStr(values[i], TIME_FULL), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Handler for order related errors which occurred in one of the library's order functions.
 *
 * The error is always set in the passed struct ORDER_EXECUTION. After the passed execution flags determine how the error is
 * handled. All errors not matched by an execution flag (see F_ERR_* constants) cause a fatal runtime error.
 *
 * @param  _In_    string message                  - error message
 * @param  _In_    int    error                    - the occurred error
 * @param  _In_    int    oeFlags                  - order execution flags
 * @param  _InOut_ int    oe[]                     - one or multiple order execution details (struct ORDER_EXECUTION)
 * @param  _In_    bool   refreshPrices [optional] - whether to refresh market prices in the passed struct ORDER_EXECUTION
 *                                                   (default: no)
 * @return int - the same error
 */
int Order.HandleError(string message, int error, int oeFlags, int oe[], bool refreshPrices = false) {
   refreshPrices = refreshPrices!=0;

   bool singleOE = ArrayDimension(oe)==1;                   // whether a single or multiple ORDER_EXECUTIONs were passed
   if (singleOE) oe.setError(oe, error);
   else          oes.setError(oe, -1, error);

   if (!error) return(NO_ERROR);

   if (refreshPrices) {
      if (singleOE) {
         string symbol = oe.Symbol(oe);
         oe.setBid(oe, MarketInfo(symbol, MODE_BID));
         oe.setAsk(oe, MarketInfo(symbol, MODE_ASK));
      }
      else {
         symbol = oes.Symbol(oe, 0);
         oes.setBid(oe, -1, MarketInfo(symbol, MODE_BID));
         oes.setAsk(oe, -1, MarketInfo(symbol, MODE_ASK));
      }
   }

   // in tester always add ERS_EXECUTION_STOPPING to the passed flags
   if (__isTesting && IsStopped())
      oeFlags |= F_ERS_EXECUTION_STOPPING;

   // filter the flagged errors and log them accordingly
   int loglevel = ifInt(oeFlags & F_LOG_NOTICE, LOG_NOTICE, LOG_INFO);

   if (error==ERR_CONCURRENT_MODIFICATION  && oeFlags & F_ERR_CONCURRENT_MODIFICATION ) return(log(message, error, loglevel));
   if (error==ERS_EXECUTION_STOPPING       && oeFlags & F_ERS_EXECUTION_STOPPING      ) return(log(message, error, loglevel));
   if (error==ERS_HISTORY_UPDATE           && oeFlags & F_ERS_HISTORY_UPDATE          ) return(log(message, error, loglevel));
   if (error==ERR_INVALID_PARAMETER        && oeFlags & F_ERR_INVALID_PARAMETER       ) return(log(message, error, loglevel));
   if (error==ERR_INVALID_STOP             && oeFlags & F_ERR_INVALID_STOP            ) return(log(message, error, loglevel));
   if (error==ERR_INVALID_TICKET           && oeFlags & F_ERR_INVALID_TICKET          ) return(log(message, error, loglevel));
   if (error==ERR_INVALID_TRADE_PARAMETERS && oeFlags & F_ERR_INVALID_TRADE_PARAMETERS) return(log(message, error, loglevel));
   if (error==ERR_MARKET_CLOSED            && oeFlags & F_ERR_MARKET_CLOSED           ) return(log(message, error, Max(loglevel, LOG_WARN)));
   if (error==ERR_NO_CONNECTION            && oeFlags & F_ERR_NO_CONNECTION           ) return(log(message, error, Max(loglevel, LOG_WARN)));
   if (error==ERR_NO_RESULT                && oeFlags & F_ERR_NO_RESULT               ) return(log(message, error, loglevel));
   if (error==ERR_OFF_QUOTES               && oeFlags & F_ERR_OFF_QUOTES              ) return(log(message, error, loglevel));
   if (error==ERR_ORDER_CHANGED            && oeFlags & F_ERR_ORDER_CHANGED           ) return(log(message, error, loglevel));
   if (error==ERR_SERIES_NOT_AVAILABLE     && oeFlags & F_ERR_SERIES_NOT_AVAILABLE    ) return(log(message, error, loglevel));
   if (error==ERS_TERMINAL_NOT_YET_READY   && oeFlags & F_ERS_TERMINAL_NOT_YET_READY  ) return(log(message, error, loglevel));
   if (error==ERR_TRADE_DISABLED           && oeFlags & F_ERR_TRADE_DISABLED          ) return(log(message, error, Max(loglevel, LOG_WARN)));
   if (error==ERR_TRADE_MODIFY_DENIED      && oeFlags & F_ERR_TRADE_MODIFY_DENIED     ) return(log(message, error, loglevel));
   if (error==ERR_STOP_DISTANCE_VIOLATED   && oeFlags & F_ERR_STOP_DISTANCE_VIOLATED  ) return(log(message, error, loglevel));
   if (error==ERR_TRADESERVER_GONE         && oeFlags & F_ERR_TRADESERVER_GONE        ) return(log(message, error, Max(loglevel, LOG_WARN)));

   // trigger a fatal error for everything else
   return(catch(message, error));
}


/**
 * Logmessage für temporäre Trade-Fehler.
 *
 * @param  int oe[]   - execution details (struct ORDER_EXECUTION)
 * @param  int errors - Anzahl der bisher aufgetretenen temporären Fehler
 *
 * @return string
 */
string Order.TempErrorMsg(int oe[], int errors) {
   // temporary error after 0.345 s and 1 requote, retrying...

   string message = "temporary error";

   if (!__isTesting) {
      message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
      int requotes = oe.Requotes(oe);
      if (requotes > 0) message = message +" and "+ requotes +" requote" + Pluralize(requotes);
   }
   return(message +", retrying... ("+ errors +")");
}


/**
 * Extended version of the built-in function OrderSend().
 *
 * @param  _In_  string   symbol      - symbol to trade (NULL: current symbol)
 * @param  _In_  int      type        - trade operation type
 * @param  _In_  double   lots        - trade volume in lots
 * @param  _In_  double   price       - limit price for pending orders (ignored for market orders)
 * @param  _In_  int      slippage    - acceptable slippage in point
 * @param  _In_  double   stopLoss    - stoploss price
 * @param  _In_  double   takeProfit  - takeprofit price
 * @param  _In_  string   comment     - order comment (max. 27 chars)
 * @param  _In_  int      magicNumber - magic order number
 * @param  _In_  datetime expires     - a pending order's expiration date (if supported by the broker)
 * @param  _In_  color    markerColor - color of the chart marker to set
 * @param  _In_  int      oeFlags     - additional flags controlling order execution
 * @param  _Out_ int      oe[]        - order execution details (struct ORDER_EXECUTION)
 *
 * @return int - resulting ticket or NULL in case of errors
 *
 * Notes: Typical trade operation errors returned in oe.Error are:
 *        - ERR_INVALID_TRADE_VOLUME:   the trade volume is not supported by the broker
 *        - ERR_INVALID_STOP:           the pending order price violates the current market
 *        - ERR_STOP_DISTANCE_VIOLATED: SL or TP violates the broker's stop distance
 */
int OrderSendEx(string symbol/*=NULL*/, int type, double lots, double price, int slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, int oe[]) {
   // validate parameters
   // oe[]
   if (ArrayDimension(oe) > 1)                                 return(!catch("OrderSendEx(1)  invalid parameter oe[] (too many dimensions: "+ ArrayDimension(oe) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(oe) != ORDER_EXECUTION_intSize)
      ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);
   // symbol
   if (symbol == "0") symbol = Symbol();                       // (string) NULL
   if (__isTesting && !StrCompareI(symbol, Symbol()))          return(!Order.HandleError("OrderSendEx(2)  cannot trade symbol "+ symbol +" in a "+ Symbol() +" test", ERR_SYMBOL_NOT_AVAILABLE, oeFlags, oe));
   int    digits         = MarketInfo(symbol, MODE_DIGITS);
   double minLot         = MarketInfo(symbol, MODE_MINLOT);
   double maxLot         = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep        = MarketInfo(symbol, MODE_LOTSTEP);
   int    pipDigits      = digits & (~1);
   int    pipPoints      = MathRound(MathPow(10, digits & 1));
   double pip            = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits), pips=pip;
   double stopDistance   = MarketInfo(symbol, MODE_STOPLEVEL  )/pipPoints;
   double freezeDistance = MarketInfo(symbol, MODE_FREEZELEVEL)/pipPoints;
   string priceFormat    = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));
   int error = GetLastError();
   if (IsError(error))                                         return(!Order.HandleError("OrderSendEx(3)  symbol="+ symbol, error, oeFlags, oe));
   // type
   if (!IsOrderType(type))                                     return(!Order.HandleError("OrderSendEx(4)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER, oeFlags, oe));
   bool isPendingType = IsPendingOrderType(type);
   // lots
   if (LT(lots, minLot))                                       return(!Order.HandleError("OrderSendEx(5)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe));
   if (GT(lots, maxLot))                                       return(!Order.HandleError("OrderSendEx(6)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe));
   if (MathModFix(lots, lotStep) != 0)                         return(!Order.HandleError("OrderSendEx(7)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe));
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0))                                           return(!Order.HandleError("OrderSendEx(8)  illegal parameter price: "+ NumberToStr(price, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe));
   if (isPendingType) /*&&*/ if (EQ(price, 0))                 return(!Order.HandleError("OrderSendEx(9)  illegal "+ OperationTypeDescription(type) +" price: "+ NumberToStr(price, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe));
   price = NormalizeDouble(price, digits);
   // slippage
   if (slippage < 0)                                           return(!Order.HandleError("OrderSendEx(10)  illegal parameter slippage: "+ slippage, ERR_INVALID_PARAMETER, oeFlags, oe));
   // stopLoss
   if (LT(stopLoss, 0))                                        return(!Order.HandleError("OrderSendEx(11)  illegal parameter stopLoss: "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe));
   stopLoss = NormalizeDouble(stopLoss, digits);
   // takeProfit
   if (LT(takeProfit, 0))                                      return(!Order.HandleError("OrderSendEx(12)  illegal parameter takeProfit: "+ NumberToStr(takeProfit, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe));
   takeProfit = NormalizeDouble(takeProfit, digits);
   // comment
   if (comment == "0") comment = "";                           // (string) NULL
   else if (StringLen(comment) > MAX_ORDER_COMMENT_LENGTH)     return(!Order.HandleError("OrderSendEx(13)  illegal parameter comment: "+ DoubleQuoteStr(comment) +" (max. "+ MAX_ORDER_COMMENT_LENGTH +" chars)", ERR_INVALID_PARAMETER, oeFlags, oe));
   if (!StringLen(comment)) string msgComment = "";
   else                            msgComment = " \""+ comment +"\"";
   // expires
   if (expires && expires <= TimeServer(false))                return(!Order.HandleError("OrderSendEx(14)  illegal parameter expires: "+ ifString(expires < 0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_PARAMETER, oeFlags, oe));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(!Order.HandleError("OrderSendEx(15)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oe));

   static datetime testCase.from=INT_MAX, testCase.to=INT_MIN;
   static bool done = false;
   if (!done) {
      //if (__isTesting) /*&&*/ if (IsConfigKey("SnowRoller.Tester", "TestCase.From") && IsConfigKey("SnowRoller.Tester", "TestCase.To")) {
      //   testCase.from = StrToTime(GetConfigString("SnowRoller.Tester", "TestCase.From"));
      //   testCase.to   = StrToTime(GetConfigString("SnowRoller.Tester", "TestCase.To"));
      //}
      done = true;
   }
   bool testCase = (testCase.from <= TimeCurrent() && TimeCurrent() <= testCase.to);

   // initialize oe[]
   oe.setSymbol        (oe, symbol        );
   oe.setDigits        (oe, digits        );
   oe.setStopDistance  (oe, stopDistance  );
   oe.setFreezeDistance(oe, freezeDistance);
   oe.setType          (oe, type          );
   oe.setLots          (oe, lots          );
   oe.setOpenPrice     (oe, price         );
   oe.setStopLoss      (oe, stopLoss      );
   oe.setTakeProfit    (oe, takeProfit    );
   oe.setComment       (oe, comment       );

   int ticket, time, time1 = GetTickCount(), requotes, tempErrors;

   // loop until the trade request succeeded or a permanent error occurred
   while (true) {
      // terminal bug: After recompiling and reloading an EA IsStopped() continues to return TRUE.
      if (IsStopped()) return(!Order.HandleError("OrderSendEx(16)  "+ OrderSendEx.ErrorMsg(oe), ERS_EXECUTION_STOPPING, oeFlags, oe));

      if (IsTradeContextBusy()) {
         if (IsLogDebug()) logDebug("OrderSendEx(17)  trade context busy, retrying...");
         Sleep(300);
         continue;
      }

      double bid = MarketInfo(symbol, MODE_BID);
      double ask = MarketInfo(symbol, MODE_ASK);
      if (!time) {
         oe.setBid(oe, bid);
         oe.setAsk(oe, ask);
      }
      if      (type == OP_BUY ) price = ask;
      else if (type == OP_SELL) price = bid;
      price = NormalizeDouble(price, digits);
      oe.setOpenPrice(oe, price);

      // submit the trade request
      time = GetTickCount();
      if (!testCase) ticket = OrderSend(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor);
      oe.setDuration(oe, GetTickCount()-time1);                            // total time in milliseconds

      if (ticket > 0) {
         OrderPush("OrderSendEx(18)");
         WaitForTicket(ticket, /*select=*/true);

         if (!ChartMarker.OrderSent_A(ticket, digits, markerColor))
            return(_NULL(oe.setError(oe, last_error), OrderPop("OrderSendEx(19)")));

         // On a slow OrderSend() response or in a fast market limits/stops may have already been executed, or the order may
         // have been modified or closed. The returned values must describe the original order, not the current order status.
         oe.setTicket    (oe, ticket         );
         oe.setOpenTime  (oe, OrderOpenTime());
         oe.setOpenPrice (oe, ifDouble(isPendingType, price, OrderOpenPrice()));
         oe.setStopLoss  (oe, stopLoss       );
         oe.setTakeProfit(oe, takeProfit     );
         oe.setSwap      (oe, ifDouble(isPendingType, 0, OrderSwap()));
         oe.setCommission(oe, ifDouble(isPendingType, 0, OrderCommission()));
         oe.setProfit    (oe, 0              );
         oe.setRequotes  (oe, requotes       );
            if      (type == OP_BUY ) double dSlippage = OrderOpenPrice() - ask;
            else if (type == OP_SELL)        dSlippage = bid - OrderOpenPrice();
            else                             dSlippage = 0;
         oe.setSlippage(oe, NormalizeDouble(dSlippage/pips, digits & 1));  // total slippage after requotes in pip

         if (IsLogDebug()) logDebug("OrderSendEx(20)  "+ OrderSendEx.SuccessMsg(oe));

         if (__isTesting) {
            if (type<=OP_SELL && __ExecutionContext[EC.externalReporting]) {
               Test_onPositionOpen(__ExecutionContext, ticket, type, OrderLots(), symbol, OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), magicNumber, comment);
            }
         }
         else PlaySoundEx(ifString(requotes, "OrderRequote.wav", "OrderOk.wav"));

         OrderPop("OrderSendEx(21)");
         if (IsError(Order.HandleError("OrderSendEx(22)", GetLastError(), oeFlags, oe)))
            return(NULL);
         return(ticket);                                                   // regular exit (NO_ERROR)
      }

      error = GetLastError();
      if (testCase) error = ERR_TRADESERVER_GONE;

      oe.setError     (oe, error     );                                    // store needed data for potential error messages
      oe.setOpenPrice (oe, price     );
      oe.setStopLoss  (oe, stopLoss  );
      oe.setTakeProfit(oe, takeProfit);

      switch (error) {
         case ERR_TRADE_CONTEXT_BUSY:
            if (IsLogDebug()) logDebug("OrderSendEx(23)  trade context busy, retrying...");
            Sleep(300);
            continue;

         case ERR_SERVER_BUSY:
         case ERR_TRADE_TIMEOUT:
         case ERR_INVALID_PRICE:
         case ERR_PRICE_CHANGED:
         case ERR_OFF_QUOTES:
            tempErrors++;
            if (tempErrors > 5) break;
            logWarn("OrderSendEx(24)  "+ OrderSendEx.TempErrorMsg(oe, tempErrors), error);
            continue;

         case ERR_REQUOTE:
            requotes++;
            oe.setRequotes(oe, requotes);
            if (__isTesting)  break;
            if (requotes > 5) break;
            continue;                                                      // no delay after ERR_REQUOTE

         // map terminal generated errors
         case ERR_INVALID_STOP:
            bool marketViolated = false;
            if (!oe.StopDistance(oe))      marketViolated = true;
            else if (type == OP_BUYSTOP)   marketViolated = LE(oe.OpenPrice(oe), oe.Ask(oe));
            else if (type == OP_BUYLIMIT)  marketViolated = GE(oe.OpenPrice(oe), oe.Ask(oe));
            else if (type == OP_SELLSTOP)  marketViolated = GE(oe.OpenPrice(oe), oe.Bid(oe));
            else if (type == OP_SELLLIMIT) marketViolated = LE(oe.OpenPrice(oe), oe.Bid(oe));
            if (!marketViolated) {
               if (IsLogDebug()) logDebug("OrderSendEx(25)  translating returned ERR_INVALID_STOP => ERR_STOP_DISTANCE_VIOLATED");
               error = oe.setError(oe, ERR_STOP_DISTANCE_VIOLATED);
            }
            break;

         case NO_ERROR:
            logWarn("OrderSendEx(26)  returned no ticket and no error => ERR_RUNTIME_ERROR");
            error = oe.setError(oe, ERR_RUNTIME_ERROR);
            break;
      }
      break;
   }
   return(!Order.HandleError("OrderSendEx(27)  "+ OrderSendEx.ErrorMsg(oe), error, oeFlags, oe, true));
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 */
string OrderSendEx.SuccessMsg(/*ORDER_EXECUTION*/int oe[]) {
   // opened #1 Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8[ instead of 1.5522'0], sl=1.5500'0, tp=1.5600'0 (slippage: -2.8 pip, market: Bid/Ask) after 0.345 s and 1 requote

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string sComment    = oe.Comment(oe); if (StringLen(sComment) > 0) sComment = " \""+ sComment +"\"";
   string sPrice      = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string sBid        = NumberToStr(oe.Bid(oe), priceFormat);
   string sAsk        = NumberToStr(oe.Ask(oe), priceFormat);
   string sSlippage   = "";
      double slippage = oe.Slippage(oe);
      if (NE(slippage, 0, digits)) {
         sPrice    = sPrice +" instead of "+ NumberToStr(ifDouble(oe.Type(oe)==OP_SELL, oe.Bid(oe), oe.Ask(oe)), priceFormat);
         sSlippage = "slippage: "+ NumberToStr(-slippage, "+."+ (Digits & 1)) +" pip, ";
      }
   string message = "opened #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ symbol + sComment +" at "+ sPrice;
   if (NE(oe.StopLoss  (oe), 0)) message = message +", sl="+ NumberToStr(oe.StopLoss(oe), priceFormat);
   if (NE(oe.TakeProfit(oe), 0)) message = message +", tp="+ NumberToStr(oe.TakeProfit(oe), priceFormat);
                                 message = message +" ("+ sSlippage +"market: "+ sBid +"/"+ sAsk +")";
   if (!__isTesting) {
      message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
      int requotes = oe.Requotes(oe);
      if (requotes > 0) message = message +" and "+ requotes +" requote"+ Pluralize(requotes);
   }
   return(message);
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[]   - Ausführungsdetails (ORDER_EXECUTION)
 * @param  int errors - Anzahl der bisher aufgetretenen temporären Fehler
 *
 * @return string
 */
string OrderSendEx.TempErrorMsg(int oe[], int errors) {
   if (oe.Error(oe) != ERR_OFF_QUOTES)
      return(Order.TempErrorMsg(oe, errors));

   // temporary error while trying to Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8 (market: Bid/Ask) after 0.345 s and 1 requote, retrying... (1)

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

   string sType    = OperationTypeDescription(oe.Type(oe));
   string sLots    = NumberToStr(oe.Lots(oe), ".+");
   string symbol   = oe.Symbol(oe);
   string sPrice   = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string sBid     = NumberToStr(oe.Bid(oe), priceFormat);
   string sAsk     = NumberToStr(oe.Ask(oe), priceFormat);
   string sComment = oe.Comment(oe);
      if (StringLen(sComment) > 0) sComment = " \""+ sComment +"\"";

   string message = "temporary error while trying to "+ sType +" "+ sLots +" "+ oe.Symbol(oe) + sComment +" at "+ sPrice +" (market: "+ sBid +"/"+ sAsk +")";

   if (!__isTesting) {
      message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
      int requotes = oe.Requotes(oe);
      if (requotes > 0) message = message +" and "+ requotes +" requote"+ Pluralize(requotes);
   }
   return(message +", retrying... ("+ errors +")");
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 */
string OrderSendEx.ErrorMsg(/*ORDER_EXECUTION*/int oe[]) {
   // error while trying to Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8, sl=1.5500'0, tp=1.5600'0 (market: Bid/Ask[, stop distance=2.3 pip]) after 0.345 s and 1 requote

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

   string sType    = OperationTypeDescription(oe.Type(oe));
   string sLots    = NumberToStr(oe.Lots(oe), ".+");
   string symbol   = oe.Symbol(oe);
   string sComment = oe.Comment(oe); if (StringLen(sComment) > 0) sComment = " \""+ sComment +"\"";
   string sPrice   = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string sBid     = NumberToStr(oe.Bid(oe), priceFormat);
   string sAsk     = NumberToStr(oe.Ask(oe), priceFormat);
   string sSD      = "";
   if (NE(oe.StopDistance(oe), 0)) sSD = ", stop distance="+ NumberToStr(oe.StopDistance(oe), ".+") +" pip";

   string message = "error while trying to "+ sType +" "+ sLots +" "+ symbol + sComment +" at "+ sPrice;

   if (NE(oe.StopLoss  (oe), 0)) message = message +", sl="+ NumberToStr(oe.StopLoss(oe), priceFormat);
   if (NE(oe.TakeProfit(oe), 0)) message = message +", tp="+ NumberToStr(oe.TakeProfit(oe), priceFormat);
                                 message = message +" (market: "+ sBid +"/"+ sAsk + sSD +")";
   if (!__isTesting) {
      message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
      int requotes = oe.Requotes(oe);
      if (requotes > 0) message = message +" and "+ requotes +" requote"+ Pluralize(requotes);
   }
   return(message);
}


/**
 * Extended version of the built-in function OrderModify().
 *
 * @param  _In_  int      ticket      - ticket to modify
 * @param  _In_  double   openPrice   - new OpenPrice for pending orders or NULL for no change
 * @param  _In_  double   stopLoss    - new StopLoss price
 * @param  _In_  double   takeProfit  - new TakeProfit price
 * @param  _In_  datetime expires     - new expiration (valid only for pending entry orders)
 * @param  _In_  color    markerColor - color of the created chart marker
 * @param  _In_  int      oeFlags     - flags controlling order execution
 * @param  _Out_ int      oe[]        - execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: Typical trade operation errors returned in oe.Error are:
 *        - ERR_INVALID_TICKET:           unknown ticket id
 *        - ERR_NO_RESULT:                the request doesn't change any order parameters
 *        - ERR_INVALID_STOP:             the request violates the current market
 *        - ERR_STOP_DISTANCE_VIOLATED:   the request violates the broker's stop distance
 *        - ERR_TRADE_MODIFY_DENIED:      the request violates the broker's freeze level
 *        - ERR_INVALID_TRADE_PARAMETERS: order status changed (order limit already executed or position already closed)
 */
bool OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, int oe[]) {
   // validate parameters
   // oe[]
   if (ArrayDimension(oe) > 1)                                 return(!catch("OrderModifyEx(1)  invalid parameter oe[] (too many dimensions: "+ ArrayDimension(oe) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(oe) != ORDER_EXECUTION_intSize)
      ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);
   // ticket
   if (!SelectTicket(ticket, "OrderModifyEx(2)", O_PUSH))      return(!oe.setError(oe, ERR_INVALID_TICKET));
   if (!IsOrderType(OrderType()))                              return(_false(Order.HandleError("OrderModifyEx(3)  #"+ ticket +" is not an order ticket", ERR_INVALID_TICKET, oeFlags, oe), OrderPop("OrderModifyEx(4)")));
   if (OrderCloseTime() != 0)                                  return(_false(Order.HandleError("OrderModifyEx(5)  ticket #"+ ticket +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderModifyEx(6)")));
   bool   isPendingOrder = IsPendingOrderType(OrderType());
   int    digits         = MarketInfo(OrderSymbol(), MODE_DIGITS);
   int    pipDigits      = digits & (~1);
   int    pipPoints      = MathRound(MathPow(10, digits & 1));
   double stopDistance   = MarketInfo(OrderSymbol(), MODE_STOPLEVEL  )/pipPoints;
   double freezeDistance = MarketInfo(OrderSymbol(), MODE_FREEZELEVEL)/pipPoints;
   string priceFormat    = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   int error = GetLastError();
   if (IsError(error))                                         return(_false(Order.HandleError("OrderModifyEx(7)  symbol=\""+ OrderSymbol() +"\"", error, oeFlags, oe), OrderPop("OrderModifyEx(8)")));
   // openPrice
   openPrice = NormalizeDouble(openPrice, digits);
   if (LT(openPrice, 0, digits))                               return(_false(Order.HandleError("OrderModifyEx(9)  illegal parameter openPrice: "+ NumberToStr(openPrice, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderModifyEx(10)")));
   if (EQ(openPrice, 0, digits)) openPrice = NormalizeDouble(OrderOpenPrice(), digits);
   if (!isPendingOrder) {
      if (NE(openPrice, OrderOpenPrice(), digits))             return(_false(Order.HandleError("OrderModifyEx(11)  cannot modify entry price of already open position #"+ ticket, ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderModifyEx(12)")));
   }
   // stopLoss
   stopLoss = NormalizeDouble(stopLoss, digits);
   if (LT(stopLoss, 0, digits))                                return(_false(Order.HandleError("OrderModifyEx(13)  illegal parameter stopLoss: "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderModifyEx(14)")));
   // takeProfit
   takeProfit = NormalizeDouble(takeProfit, digits);
   if (LT(takeProfit, 0, digits))                              return(_false(Order.HandleError("OrderModifyEx(15)  illegal parameter takeProfit: "+ NumberToStr(takeProfit, priceFormat), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderModifyEx(16)")));
   // expires
   if (expires != 0)
      if (expires <= TimeServer(false))                        return(_false(Order.HandleError("OrderModifyEx(17)  illegal parameter expires: "+ ifString(expires < 0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderModifyEx(18)")));
   if (expires != OrderExpiration())
      if (!isPendingOrder)                                     return(_false(Order.HandleError("OrderModifyEx(19)  cannot modify expiration of already open position #"+ ticket, ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderModifyEx(20)")));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(Order.HandleError("OrderModifyEx(21)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderModifyEx(22)")));

   // initialize oe[]
   oe.setSymbol        (oe, OrderSymbol()    );
   oe.setDigits        (oe, digits           );
   oe.setStopDistance  (oe, stopDistance     );
   oe.setFreezeDistance(oe, freezeDistance   );
   oe.setBid           (oe, MarketInfo(OrderSymbol(), MODE_BID));
   oe.setAsk           (oe, MarketInfo(OrderSymbol(), MODE_ASK));
   oe.setTicket        (oe, ticket           );
   oe.setType          (oe, OrderType()      );
   oe.setLots          (oe, OrderLots()      );
   oe.setOpenPrice     (oe, openPrice        );
   oe.setStopLoss      (oe, stopLoss         );
   oe.setTakeProfit    (oe, takeProfit       );
   oe.setSwap          (oe, OrderSwap()      );
   oe.setCommission    (oe, OrderCommission());
   oe.setProfit        (oe, OrderProfit()    );
   oe.setComment       (oe, OrderComment()   );

   double prevOpenPrice=OrderOpenPrice(), prevStopLoss=OrderStopLoss(), prevTakeProfit=OrderTakeProfit();

   if (EQ(openPrice, prevOpenPrice, digits)) /*&&*/ if (EQ(stopLoss, prevStopLoss, digits)) /*&&*/ if (EQ(takeProfit, prevTakeProfit, digits)) {
      logWarn("OrderModifyEx(23)  nothing to modify for ticket #"+ ticket);
      return(_false(Order.HandleError("OrderModifyEx(24)", ERR_NO_RESULT, oeFlags, oe), OrderPop("OrderModifyEx(25)")));
   }
   int  tempErrors, startTime = GetTickCount();
   bool success;

   // loop until the order was modified or a permanent error occurred
   while (true) {
      // terminal bug: After recompiling and reloading an EA IsStopped() continues to return TRUE.
      if (IsStopped()) return(_false(Order.HandleError("OrderModifyEx(26)  "+ OrderModifyEx.ErrorMsg(oe, prevOpenPrice, prevStopLoss, prevTakeProfit), ERS_EXECUTION_STOPPING, oeFlags, oe), OrderPop("OrderModifyEx(27)")));

      if (IsTradeContextBusy()) {
         if (IsLogDebug()) logDebug("OrderModifyEx(28)  trade context busy, retrying...");
         Sleep(300);
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      success = OrderModify(ticket, openPrice, stopLoss, takeProfit, expires, markerColor);

      oe.setDuration(oe, GetTickCount()-startTime);

      if (success) {
         WaitForTicket(ticket, /*select=*/true);

         if (!ChartMarker.OrderModified_A(ticket, digits, markerColor, __ExecutionContext[EC.currTickTime], prevOpenPrice, prevStopLoss, prevTakeProfit))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderModifyEx(29)")));

         // In a fast market limits may have already been executed or the order status may have changed other-wise.
         // The returned values must describe the original order, not the current status.
         oe.setOpenTime  (oe, OrderOpenTime());
         oe.setOpenPrice (oe, openPrice      );
         oe.setStopLoss  (oe, stopLoss       );
         oe.setTakeProfit(oe, takeProfit     );
         oe.setSwap      (oe, ifDouble(isPendingOrder, 0, OrderSwap()));
         oe.setCommission(oe, ifDouble(isPendingOrder, 0, OrderCommission()));
         oe.setProfit    (oe, ifDouble(isPendingOrder, 0, OrderProfit()));

         if (IsLogDebug()) logDebug("OrderModifyEx(30)  "+ OrderModifyEx.SuccessMsg(oe, prevOpenPrice, prevStopLoss, prevTakeProfit));
         if (!__isTesting) PlaySoundEx("OrderModified.wav");                           // regular exit (NO_ERROR)
         return(!_bool(Order.HandleError("OrderModifyEx(31)", GetLastError(), oeFlags, oe), OrderPop("OrderModifyEx(32)")));
      }

      error = GetLastError();

      switch (error) {
         case ERR_TRADE_CONTEXT_BUSY:
            if (IsLogDebug()) logDebug("OrderModifyEx(33)  trade context busy, retrying...");
            Sleep(300);
            continue;

         case ERR_SERVER_BUSY:
         case ERR_TRADE_TIMEOUT:
            tempErrors++;
            if (tempErrors > 5) break;
            logWarn("OrderModifyEx(34)  "+ Order.TempErrorMsg(oe, tempErrors), error);
            continue;

         // map terminal generated errors
         case ERR_INVALID_TICKET:                // unknown ticket or not an open pending order anymore (client-side)
            if (IsLogDebug()) logDebug("OrderModifyEx(35)  translating returned ERR_INVALID_TICKET => ERR_INVALID_TRADE_PARAMETERS");
            error = oe.setError(oe, ERR_INVALID_TRADE_PARAMETERS);
            break;

         case ERR_INVALID_STOP:
            logWarn("OrderModifyEx(36)  detection of ERR_STOP_DISTANCE_VIOLATED not yet implemented", ERR_NOT_IMPLEMENTED);
            break;

         case NO_ERROR:
            logWarn("OrderModifyEx(37)  returned no success and no error => ERR_RUNTIME_ERROR");
            error = oe.setError(oe, ERR_RUNTIME_ERROR);
            break;
      }
      break;
   }

   string msg = OrderModifyEx.ErrorMsg(oe, prevOpenPrice, prevStopLoss, prevTakeProfit);
   return(_false(Order.HandleError("OrderModifyEx(38)  "+ msg, error, oeFlags, oe, true), OrderPop("OrderModifyEx(39)")));
}


/**
 * Compose a log message for successful execution of OrderModifyEx().
 *
 * @param  int    oe[]           - execution details (struct ORDER_EXECUTION)
 * @param  double prevOpenPrice  - previous OpenPrice
 * @param  double prevStopLoss   - previous StopLoss
 * @param  double prevTakeProfit - previous TakeProfit
 *
 * @return string
 */
string OrderModifyEx.SuccessMsg(int oe[], double prevOpenPrice, double prevStopLoss, double prevTakeProfit) {
   // modified #1 Stop Buy 0.1 GBPUSD "SR.12345.+2" at 1.5500'0[ => 1.5520'0][, sl=1.5450'0 => 1.5455'0][, tp=1.5520'0 => 1.5530'0] after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string comment     = oe.Comment(oe);
      if (StringLen(comment) > 0) comment = " \""+ comment +"\"";

   double openPrice=oe.OpenPrice(oe), stopLoss=oe.StopLoss(oe), takeProfit=oe.TakeProfit(oe);

   string sPrice = NumberToStr(openPrice, priceFormat);
                    if (NE(openPrice,  prevOpenPrice) ) sPrice = NumberToStr(prevOpenPrice, priceFormat) +" => "+ sPrice;
   string sSL = ""; if (NE(stopLoss,   prevStopLoss)  ) sSL    = ", sl="+ NumberToStr(prevStopLoss, priceFormat) +" => "+ NumberToStr(stopLoss, priceFormat);
   string sTP = ""; if (NE(takeProfit, prevTakeProfit)) sTP    = ", tp="+ NumberToStr(prevTakeProfit, priceFormat) +" => "+ NumberToStr(takeProfit, priceFormat);

   string message = "modified #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ oe.Symbol(oe) + comment +" at "+ sPrice +  sSL + sTP;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";

   return(message);
}


/**
 * Compose a log message for failed execution of OrderModifyEx().
 *
 * @param  int    oe[]           - execution details (struct ORDER_EXECUTION)
 * @param  double prevOpenPrice  - previous OpenPrice
 * @param  double prevStopLoss   - previous StopLoss
 * @param  double prevTakeProfit - previous TakeProfit
 *
 * @return string
 */
string OrderModifyEx.ErrorMsg(int oe[], double prevOpenPrice, double prevStopLoss, double prevTakeProfit) {
   // error while trying to modify #1 Stop Buy 0.5 GBPUSD "SR.12345.+2" at 1.5524'8[ => 1.5520'0][, sl=1.5450'0 => 1.5455'0][, tp=1.5520'0 => 1.5530'0] (market: Bid/Ask[, stop distance=2.3 pip]) after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots     (oe), ".+");
   string symbol      = oe.Symbol(oe);
   string comment     = oe.Comment(oe); if (StringLen(comment) > 0) comment = " \""+ comment +"\"";

   double openPrice=oe.OpenPrice(oe), stopLoss=oe.StopLoss(oe), takeProfit=oe.TakeProfit(oe);

   string sPrice = NumberToStr(openPrice, priceFormat);
                        if (NE(openPrice, prevOpenPrice))   sPrice = NumberToStr(prevOpenPrice, priceFormat) +" => "+ sPrice;
   string sSL     = ""; if (NE(stopLoss,   prevStopLoss))   sSL    = ", sl="+ NumberToStr(prevStopLoss, priceFormat) +" => "+ NumberToStr(stopLoss, priceFormat);
   string sTP     = ""; if (NE(takeProfit, prevTakeProfit)) sTP    = ", tp="+ NumberToStr(prevTakeProfit, priceFormat) +" => "+ NumberToStr(takeProfit, priceFormat);
   string sSD     = ""; if (NE(oe.StopDistance(oe), 0))     sSD    = ", stop distance="+ NumberToStr(oe.StopDistance(oe), ".+") +" pip";
   string sMarket = "(market: "+ NumberToStr(oe.Bid(oe), priceFormat) +"/"+ NumberToStr(oe.Ask(oe), priceFormat) + sSD +")";

   string message = "error while trying to modify #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ symbol + comment +" at "+ sPrice + sSL + sTP +" "+ sMarket;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";

   return(message);
}


/**
 * Extended version of OrderClose().
 *
 * @param  _In_  int    ticket      - order ticket of the position to close
 * @param  _In_  double lots        - order size to close (default: full order size)
 * @param  _In_  int    slippage    - acceptable slippage in point
 * @param  _In_  color  markerColor - color of the chart marker to set
 * @param  _In_  int    oeFlags     - flags controlling trade request execution
 * @param  _Out_ int    oe[]        - execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: (1) On partial close the final values for swap, commission and profit may be spread by the trade server over both
 *            the partially closed and the remaining ticket.
 *
 *        (2) Typical trade operation errors returned in oe.Error are:
 *            - ERR_INVALID_TICKET:           the specified ticket is not an order ticket
 *            - ERR_INVALID_TRADE_PARAMETERS: the ticket is not an open position (anymore)
 */
bool OrderCloseEx(int ticket, double lots, int slippage, color markerColor, int oeFlags, int oe[]) {
   // validate parameters
   // oe[]
   if (ArrayDimension(oe) > 1)                                 return(!catch("OrderCloseEx(1)  invalid parameter oe[] (too many dimensions: "+ ArrayDimension(oe) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(oe) != ORDER_EXECUTION_intSize)
      ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);
   // ticket
   if (!SelectTicket(ticket, "OrderCloseEx(2)", O_PUSH))       return(!oe.setError(oe, ERR_INVALID_TICKET));
   if (OrderCloseTime() != 0)                                  return(_false(Order.HandleError("OrderCloseEx(3)  ticket #"+ ticket +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseEx(4)")));
   if (OrderType() > OP_SELL)                                  return(_false(Order.HandleError("OrderCloseEx(5)  ticket #"+ ticket +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseEx(6)")));
   // lots
   int    digits   = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double minLot   = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep  = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   double openLots = OrderLots();
   int error = GetLastError();
   if (IsError(error))                                         return(_false(Order.HandleError("OrderCloseEx(7)  symbol="+ OrderSymbol(), error, oeFlags, oe), OrderPop("OrderCloseEx(8)")));
   if (EQ(lots, 0, 2)) {
      lots = openLots;
   }
   else if (NE(lots, openLots, 2)) {
      if (LT(lots, minLot, 2))                                 return(_false(Order.HandleError("OrderCloseEx(9)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe), OrderPop("OrderCloseEx(10)")));
      if (GT(lots, openLots, 2))                               return(_false(Order.HandleError("OrderCloseEx(11)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (open lots="+ NumberToStr(openLots, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe), OrderPop("OrderCloseEx(12)")));
      if (MathModFix(lots, lotStep) != 0)                      return(_false(Order.HandleError("OrderCloseEx(13)  illegal parameter lots: "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_TRADE_VOLUME, oeFlags, oe), OrderPop("OrderCloseEx(14)")));
   }
   lots = NormalizeDouble(lots, 2);
   // slippage
   if (slippage < 0)                                           return(_false(Order.HandleError("OrderCloseEx(15)  illegal parameter slippage: "+ slippage, ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderCloseEx(16)")));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(Order.HandleError("OrderCloseEx(17)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderCloseEx(18)")));

   // initialize oe[]
   oe.setTicket    (oe, ticket           );
   oe.setSymbol    (oe, OrderSymbol()    );
   oe.setDigits    (oe, digits           );
   oe.setBid       (oe, MarketInfo(OrderSymbol(), MODE_BID));
   oe.setAsk       (oe, MarketInfo(OrderSymbol(), MODE_ASK));
   oe.setType      (oe, OrderType()      );
   oe.setLots      (oe, lots             );
   oe.setOpenTime  (oe, OrderOpenTime()  );
   oe.setOpenPrice (oe, OrderOpenPrice() );
   oe.setStopLoss  (oe, OrderStopLoss()  );
   oe.setTakeProfit(oe, OrderTakeProfit());
   oe.setComment   (oe, OrderComment()   );

   /*
   Complete Close
   ==============
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+
   |               | Ticket | Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission | Profit | MagicNumber | Comment        |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+
   | open          |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3207'9 | -0.80 |      -8.00 |   0.00 |         666 | order comment  |
   | closed        |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 12:00:05 |   1.3215'9 | -0.80 |      -8.00 |  64.00 |         666 | order comment  |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+

   Partial Close
   =============
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+----------------+
   |               | Ticket | Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice |  Swap | Commission | Profit | MagicNumber | Comment Online | Comment Tester |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+----------------+
   | open          |     #1 |  Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3207'9 | -0.80 |      -8.00 |  64.00 |         666 | order comment  | order comment  |
   | partial close |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 12:00:05 |   1.3215'9 | -0.56 |      -5.60 |  44.80 |         666 | to #2          | partial close  |
   | remainder     |     #2 |  Buy | 0.30 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 |                     |   1.3215'9 | -0.24 |      -2.40 |  19.20 |         666 | from #1        | split from #1  |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+----------------+
   | close         |     #2 |  Buy | 0.30 | EURUSD | 2012.03.19 11:00:05 |  1.3209'5 | 2012.03.20 13:00:05 |   1.3245'7 | -0.24 |      -2.40 | 108.60 |         666 | from #1        | split from #1  |
   +---------------+--------+------+------+--------+---------------------+-----------+---------------------+------------+-------+------------+--------+-------------+----------------+----------------+
    - OpenTime, OpenPrice and MagicNumber of the remaining position match the original position.
    - Swap, commission and profit are divided over the partially closed and the remaining position.
   */

   int    pipDigits   = digits & (~1);
   double pip         = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits), pips=pip;
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

   int    time1, firstTime1 = GetTickCount(), requotes, tempErrors, remainder;
   double price, firstPrice, bid, ask;
   bool   success;

   // loop until the order is closed or a non-fixable error occurred
   while (true) {
      // terminal bug: after recompiling and reloading an expert IsStopped() will continue to return TRUE
      if (IsStopped()) return(_false(Order.HandleError("OrderCloseEx(19)  "+ OrderCloseEx.ErrorMsg(oe), ERS_EXECUTION_STOPPING, oeFlags, oe), OrderPop("OrderCloseEx(20)")));

      if (IsTradeContextBusy()) {
         if (IsLogDebug()) logDebug("OrderCloseEx(21)  trade context busy, retrying...");
         Sleep(300);
         continue;
      }

      // determine the close price to use
      bid = oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      ask = oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));
      if      (OrderType() == OP_BUY ) price = bid;
      else if (OrderType() == OP_SELL) price = ask;
      price = oe.setClosePrice(oe, NormalizeDouble(price, digits));
      if (!time1) firstPrice = price;                                               // remember first close price (in case of ERR_REQUOTE)

      time1   = GetTickCount();
      success = OrderClose(ticket, lots, price, slippage, markerColor);

      oe.setDuration(oe, GetTickCount()-firstTime1);

      if (success) {
         WaitForTicket(ticket, /*select=*/true);

         if (!ChartMarker.PositionClosed_A(ticket, digits, markerColor))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderCloseEx(22)")));

         oe.setCloseTime (oe, OrderCloseTime());
         oe.setClosePrice(oe, OrderClosePrice());
         oe.setSwap      (oe, OrderSwap());
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, OrderProfit());
         oe.setRequotes  (oe, requotes);
            if (OrderType() == OP_BUY ) double dSlippage = oe.Bid(oe) - OrderClosePrice();
            else                               dSlippage = OrderClosePrice() - oe.Ask(oe);
         oe.setSlippage(oe, NormalizeDouble(dSlippage/pips, 1));                    // in pip

         // find the remaining position
         if (NE(lots, openLots, 2)) {
            string sValue1="", sValue2="";
            if (__isTesting) /*&&*/ if (!StrStartsWithI(OrderComment(), "to #")) {  // fall-back to server behavior if current terminal builds fixed the comment issue
               // the Tester overwrites the comment with "partial close" instead of "to #2"
               if (OrderComment() != "partial close") return(_false(Order.HandleError("OrderCloseEx(23)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseEx(24)")));
               sValue1 = "split from #"+ ticket;
               sValue2 = "from #"+ ticket;

               OrderPush("OrderCloseEx(25)");
               for (int i=OrdersTotal()-1; i >= 0; i--) {
                  OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                  if (OrderTicket() == ticket)        continue;
                  if (OrderComment() != sValue1)
                     if (OrderComment() != sValue2)   continue;                     // if current terminal builds fixed the comment issue
                  if (NE(lots+OrderLots(), openLots)) continue;

                  remainder = OrderTicket();
                  break;
               }
               OrderPop("OrderCloseEx(26)");
               if (!remainder) {
                  if (IsLastError())                        return(_false(OrderPop("OrderCloseEx(27)")));
                                                            return(_false(Order.HandleError("OrderCloseEx(28)  cannot find remaining position of partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots)", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseEx(29)")));
               }
            }
            if (!remainder) {
               if (!StrStartsWithI(OrderComment(), "to #")) return(_false(Order.HandleError("OrderCloseEx(30)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseEx(31)")));
               sValue1 = StrSubstr(OrderComment(), 4);
               if (!StrIsDigits(sValue1))                   return(_false(Order.HandleError("OrderCloseEx(32)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseEx(33)")));
               remainder = StrToInteger(sValue1);
               if (!remainder)                              return(_false(Order.HandleError("OrderCloseEx(34)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseEx(35)")));
            }
            WaitForTicket(remainder);
            oe.setRemainingTicket(oe, remainder);
            oe.setRemainingLots  (oe, openLots-lots);
         }
         if (IsLogDebug()) logDebug("OrderCloseEx(36)  "+ OrderCloseEx.SuccessMsg(oe));

         if (!__isTesting)                                       PlaySoundEx(ifString(requotes, "OrderRequote.wav", "OrderOk.wav"));
         else if (__ExecutionContext[EC.externalReporting] != 0) Test_onPositionClose(__ExecutionContext, ticket, OrderCloseTime(), OrderClosePrice(), OrderSwap(), OrderProfit());
                                                                                    // regular exit
         return(_bool(!Order.HandleError("OrderCloseEx(37)", GetLastError(), oeFlags, oe), OrderPop("OrderCloseEx(38)")));
      }

      error = GetLastError();

      switch (error) {
         case ERR_TRADE_CONTEXT_BUSY:
            if (IsLogDebug()) logDebug("OrderCloseEx(39)  trade context busy, retrying...");
            Sleep(300);
            continue;

         case ERR_SERVER_BUSY:
         case ERR_TRADE_TIMEOUT:
         case ERR_INVALID_PRICE:
         case ERR_PRICE_CHANGED:
         case ERR_OFF_QUOTES:
            tempErrors++;
            if (tempErrors > 5) break;
            logWarn("OrderCloseEx(40)  "+ Order.TempErrorMsg(oe, tempErrors), error);
            continue;

         case ERR_REQUOTE:
            requotes++;
            oe.setRequotes(oe, requotes);
            if (__isTesting || requotes > 5) break;
            continue;                                                               // immediately repeat the request

         // map terminal generated errors
         case ERR_INVALID_TICKET:                                                   // unknown ticket or not an open position anymore (client-side)   !!! not yet encountered
            if (IsLogDebug()) logDebug("OrderCloseEx(41)  translating returned ERR_INVALID_TICKET => ERR_INVALID_TRADE_PARAMETERS");
            error = ERR_INVALID_TRADE_PARAMETERS;
            break;

         case NO_ERROR:
            if (IsLogNotice()) logNotice("OrderCloseEx(42)  no error returned => ERR_RUNTIME_ERROR");
            error = ERR_RUNTIME_ERROR;
            break;
      }
      break;
   }
   return(_false(Order.HandleError("OrderCloseEx(43)  "+ OrderCloseEx.ErrorMsg(oe), error, oeFlags, oe, true), OrderPop("OrderCloseEx(44)")));
}


/**
 * Compose a log message for successful execution of OrderCloseEx().
 *
 * @param  int oe[] - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderCloseEx.SuccessMsg(int oe[]) {
   // closed #1 Buy 0.6 GBPUSD "SR.1234.+2" from 1.5520'0 [partially] at 1.5534'4[ instead of 1.5532'2][, remainder: #2 Buy 0.1 GBPUSD] ([slippage: -2.8 pip, ]market: Bid/Ask) after 0.123 s and 1 requote

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   double pip         = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string sOpenPrice  = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string sClosePrice = NumberToStr(oe.ClosePrice(oe), priceFormat);
   string sBid        = NumberToStr(oe.Bid(oe), priceFormat);
   string sAsk        = NumberToStr(oe.Ask(oe), priceFormat);
   string comment     = oe.Comment(oe);
      if (StringLen(comment) > 0) comment = " \""+ comment +"\"";
   string sSlippage   = "";

   double slippage = oe.Slippage(oe);
   if (NE(slippage, 0, digits)) {
      sClosePrice = sClosePrice +" instead of "+ NumberToStr(ifDouble(!oe.Type(oe), oe.Bid(oe), oe.Ask(oe)), priceFormat);
      sSlippage   = "slippage: "+ NumberToStr(-slippage, "+."+ (Digits & 1)) +" pip, ";
   }
   int remainder = oe.RemainingTicket(oe);
   string message = "closed #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ symbol + comment +" from "+ sOpenPrice + ifString(!remainder, "", " partially") +" at "+ sClosePrice;

   if (remainder != 0) message = message +", remainder: #"+ remainder +" "+ sType +" "+ NumberToStr(oe.RemainingLots(oe), ".+") +" "+ symbol;
                       message = message +" ("+ sSlippage +"market: "+ sBid +"/"+ sAsk +")";

   if (!__isTesting) {
      message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
      int requotes = oe.Requotes(oe);
      if (requotes > 0) message = message +" and "+ requotes +" requote"+ Pluralize(requotes);
   }
   return(message);
}


/**
 * Compose a log message for failed execution of OrderCloseEx().
 *
 * @param  int oe[] - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderCloseEx.ErrorMsg(int oe[]) {
   // error while trying to close #1 Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8[, sl=1.5500'0[, tp=1.5600'0]] (market: Bid/Ask[, stop distance=2.1 pip]) after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string comment     = oe.Comment(oe);
      if (StringLen(comment) > 0) comment = " \""+ comment +"\"";
   string sPrice      = NumberToStr(oe.ClosePrice(oe), priceFormat);

   string sSL = ""; if (NE(oe.StopLoss    (oe), 0)) sSL = ", sl="+ NumberToStr(oe.StopLoss  (oe), priceFormat);
   string sTP = ""; if (NE(oe.TakeProfit  (oe), 0)) sTP = ", tp="+ NumberToStr(oe.TakeProfit(oe), priceFormat);
   string sSD = ""; if (NE(oe.StopDistance(oe), 0)) sSD = ", stop distance="+ NumberToStr(oe.StopDistance(oe), ".+") +" pip";

   string sMarket = "(market: "+ NumberToStr(oe.Bid(oe), priceFormat) +"/"+ NumberToStr(oe.Ask(oe), priceFormat) + sSD +")";

   string message = "error while trying to close #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ symbol + comment +" at "+ sPrice + sSL + sTP +" "+ sMarket;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";

   return(message);
}


/**
 * Extended version of OrderCloseBy().
 *
 * @param  _In_  int   ticket      - order ticket of the position to close
 * @param  _In_  int   opposite    - order ticket of the opposite position to close
 * @param  _In_  color markerColor - color of the chart marker to set
 * @param  _In_  int   oeFlags     - flags controlling trade request execution
 * @param  _Out_ int   oe[]        - execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: (1) Typical trade operation errors returned in oe.Error are:
 *            - ERR_INVALID_TICKET:           one of the ids is not a valid ticket id
 *            - ERR_MIXED_SYMBOLS:            tickets belong to multiple symbols
 *            - ERR_INVALID_TRADE_PARAMETERS: one of the tickets is not an open position or the tickets can't be closed by
 *                                            each other (anymore)
 *
 *        (2) On partial close the total values for swap, commission and profit may be spread by the trade server over both
 *            tickets. The values returned in oe[] are summed-up values of both tickets.
 */
bool OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, int oe[]) {
   // validate parameters
   // oe[]
   if (ArrayDimension(oe) > 1)                                    return(!catch("OrderCloseByEx(1)  invalid parameter oe[] (too many dimensions: "+ ArrayDimension(oe) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(oe) != ORDER_EXECUTION_intSize)
      ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);
   // ticket
   if (!SelectTicket(ticket, "OrderCloseByEx(2)", O_PUSH))        return(!oe.setError(oe, ERR_INVALID_TICKET));
   if (OrderCloseTime() != 0)                                     return(_false(Order.HandleError("OrderCloseByEx(3)  ticket #"+ ticket +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseByEx(4)")));
   if (OrderType() > OP_SELL)                                     return(_false(Order.HandleError("OrderCloseByEx(5)  ticket #"+ ticket +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseByEx(6)")));
   int      ticketType     = OrderType();
   double   ticketLots     = OrderLots();
   datetime ticketOpenTime = OrderOpenTime();
   string   symbol         = OrderSymbol();
   // opposite
   if (!SelectTicket(opposite, "OrderCloseByEx(7)", NULL, O_POP)) return(!oe.setError(oe, ERR_INVALID_TICKET));
   if (symbol != OrderSymbol())                                   return(_false(Order.HandleError("OrderCloseByEx(8)  ticket #"+ opposite +" ("+ OperationTypeDescription(OrderType()) +" "+ OrderSymbol() +") is not opposite to ticket #"+ ticket +" ("+ OperationTypeDescription(ticketType) +" "+ symbol +")", ERR_MIXED_SYMBOLS, oeFlags, oe), OrderPop("OrderCloseByEx(9)")));
   if (OrderCloseTime() != 0)                                     return(_false(Order.HandleError("OrderCloseByEx(10)  opposite ticket #"+ opposite +" is not an open position (anymore)", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseByEx(11)")));
   int      oppositeType     = OrderType();
   double   oppositeLots     = OrderLots();
   datetime oppositeOpenTime = OrderOpenTime();
   if (ticketType != oppositeType^1)                              return(_false(Order.HandleError("OrderCloseByEx(12)  ticket #"+ opposite +" ("+ OperationTypeDescription(oppositeType) +") is not opposite to ticket #"+ ticket +" ("+ OperationTypeDescription(ticketType) +")", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderCloseByEx(13)")));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')    return(_false(Order.HandleError("OrderCloseByEx(14)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderCloseByEx(15)")));

   // initialize oe[]
   oe.setSymbol(oe, OrderSymbol());
   oe.setDigits(oe, MarketInfo(OrderSymbol(), MODE_DIGITS));
   oe.setTicket(oe, ticket);
   oe.setBid   (oe, MarketInfo(OrderSymbol(), MODE_BID));
   oe.setAsk   (oe, MarketInfo(OrderSymbol(), MODE_ASK));
   oe.setType  (oe, ticketType);
   oe.setLots  (oe, ticketLots);

   /*
   Complete close
   ==============
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   |           | Ticket | Type | Lots | Symbol |                OpenTime | OpenPrice |           CloseTime | ClosePrice | Commission |  Swap |  Profit | MagicNumber | Comment           |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | open      |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 |                     |   1.3237'4 |      -8.00 | -0.80 |  714.00 |         111 |                   |
   | open      |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 |                     |   1.3239'4 |      -8.00 | -1.50 | -837.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+

    #1 by #2:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.20 20:00:01 |   1.3155'7 |      -8.00 | -2.30 | -103.00 |         111 |                   |
   | closed    |     #2 | Sell | 0.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.20 20:00:01 |   1.3155'7 |       0.00 |  0.00 |    0.00 |         222 | close hedge by #1 | should be "close hedge for #1"
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+

    #2 by #1:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |       0.00 |  0.00 |    0.00 |         111 | close hedge by #2 | should be "close hedge for #2"
   | closed    |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 |      -8.00 | -2.30 | -103.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
    - The "ClosePrice" of the closing ticket (by) is set to its "OpenPrice" (byOpenPrice == byClosePrice), the "ClosePrice"
      of the closed ticket is set to "byOpenPrice".
    - Swap and profit of the closing ticket (by) are added to the closed ticket, already indicated commission is refunded.
      The "LotSize" of the closing ticket (by) is set to 0 (zero).


   Partial close
   =============
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   |           | Ticket | Type | Lots | Symbol |            OpenTime     | OpenPrice |           CloseTime | ClosePrice | Commission |  Swap |  Profit | MagicNumber | Comment/Online             | Comment/Tester < Build 416 | Comment/Tester >= Build 416 |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | open      |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 |                     |   1.3237'4 |      -5.60 | -0.56 |  499.80 |         111 |                            |                            |                             |
   | open      |     #2 | Sell | 1.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 |                     |   1.3239'4 |      -8.00 | -1.50 | -837.00 |         222 |                            |                            |                             |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+

    #smaller(1) by #larger(2):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3155'7 |      -5.60 | -2.06 |  -72.10 |         111 | partial close              | partial close              | to #3                       | should be unchanged
   | closed    |     #2 | Sell | 0.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3155'7 |       0.00 |  0.00 |    0.00 |         222 | close hedge by #1          | close hedge by #1          | close hedge by #1           | should be "partial close/close hedge for #1"
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 20:00:01 (1) |  1.3155'7 |                     |   1.3239'4 |      -2.40 |  0.00 | -251.00 |         222 | from #1                    | split from #1              | from #1                     | should be "split from #2"
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
    - Swap and profit of the closing ticket (by) are added to the closed ticket, already indicated commission is splitted and
      refunded. The "LotSize" of the closing ticket (by) is set to 0 (zero).
    - "OrderProfit" of the remaining ticket (position) is not immediately updated. It will be updated after the next tick or
      after the ticket is closed which might be during the same tick as the OrderCloseBy() call (confirmed in Tester, todo: check online).

    #larger(2) by #smaller(1):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |       0.00 |  0.00 |    0.00 |         111 | close hedge by #2          | close hedge by #2          | close hedge by #2           | should be "close hedge for #2"
   | closed    |     #2 | Sell | 0.70 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 |      -5.60 | -2.06 |  -72.10 |         222 | partial close              | partial close              |                             |
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 14:00:05 (2) |  1.3155'7 |                     |   1.3239'4 |      -2.40 |  0.00 | -251.10 |         222 | partial close              | partial close              |                             | should be "split from #2"
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
    - Swap and profit of the closing ticket (by) are added to the closed ticket, already indicated commission is splitted and
      refunded. The "LotSize" of the closing ticket (by) is set to 0 (zero).
    - "OrderProfit" of the remaining ticket (position) is not immediately updated. It will be updated after the next tick or
      after the ticket is closed which might be during the same tick as the OrderCloseBy() call (confirmed in Tester, todo: check online).
    - There remains *no* reference connecting the original tickets and the remaining position.

   (1) The remaining position's "OpenTime" is incorrect in Tester (3).
   (2) The remaining position's "OpenTime" is correct online and in Tester (3).
   (3) To work around issue (1) (incorrect "OpenTime" on CloseBy("#smaller by #larger")) in Tester always the more complicated
       method CloseBy("#larger by #smaller") is used. However, that approach caanot be used in online trading as there may
       exist tickets with identical data (which cannot happen in Tester). As it's more important to always have a correct
       remaining position the function chooses the best approach depending on context.
   */

   // analyse ticket order
   int    first, second, smaller, larger, largerType;
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
   if (larger == ticket) largerType = ticketType;
   else                  largerType = oppositeType;

   int  error, time1, tempErrors, remainder;
   bool success, smallerByLarger=!__isTesting, largerBySmaller=!smallerByLarger;

   // loop until the positions have been closed or a non-fixable error occurred
   while (true) {
      // terminal bug: After recompiling and reloading an EA IsStopped() continues to return TRUE.
      if (IsStopped()) return(_false(Order.HandleError("OrderCloseByEx(16)  "+ OrderCloseByEx.ErrorMsg(first, second, oe), ERS_EXECUTION_STOPPING, oeFlags, oe), OrderPop("OrderCloseByEx(17)")));

      if (IsTradeContextBusy()) {
         if (IsLogDebug()) logDebug("OrderCloseByEx(18)  trade context busy, retrying...");
         Sleep(300);
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      time1 = GetTickCount();
      if (smallerByLarger) success = OrderCloseBy(smaller, larger, markerColor); // see "Partial Close" note (3)
      else                 success = OrderCloseBy(larger, smaller, markerColor);

      oe.setDuration(oe, GetTickCount()-time1);

      if (success) {
         // populate oe[]
         WaitForTicket(first, /*select=*/true);                                  // data of first ticket
         oe.setOpenTime  (oe, OrderOpenTime()  );
         oe.setOpenPrice (oe, OrderOpenPrice() );
         oe.setSwap      (oe, OrderSwap()      );
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, OrderProfit()    );

         WaitForTicket(second, /*select=*/true);                                 // data of second ticket
         oe.setCloseTime (oe, OrderOpenTime()  );
         oe.setClosePrice(oe, OrderOpenPrice() );
         oe.addSwap      (oe, OrderSwap()      );
         oe.addCommission(oe, OrderCommission());
         oe.addProfit    (oe, OrderProfit()    );

         // find remaining position
         if (NE(firstLots, secondLots)) {
            double remainderLots = MathAbs(firstLots - secondLots);

            if (smallerByLarger) {                                               // online
               // reference in remainder.comment = "from #smaller"
               string sValue = StringConcatenate("from #", smaller);

               for (int i=OrdersTotal()-1; i >= 0; i--) {
                  if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;     // FALSE: during iteration a ticket was closed in another thread
                  if (OrderComment() != sValue)                    continue;
                  remainder = OrderTicket();
                  break;
               }
               if (!remainder) return(_false(Order.HandleError("OrderCloseByEx(19)  cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = smaller) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = larger)", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseByEx(20)")));
            }

            else /*(largerBySmaller)*/ {                                         // in tester
               // no reference available
               if (!SelectTicket(larger, "OrderCloseByEx(21)", NULL, O_POP)) return(!oe.setError(oe, ERR_INVALID_TICKET));
               int      remainderType        = OrderType();
               //       remainderLots        = ...
               string   remainderSymbol      = OrderSymbol();
               datetime remainderOpenTime    = OrderOpenTime();
               double   remainderOpenprice   = OrderOpenPrice();
               datetime remainderCloseTime   = 0;
               int      remainderMagicNumber = OrderMagicNumber();
               string   remainderComment     = ifString(GetTerminalBuild() < 416, "partial close", OrderComment());

               for (i=OrdersTotal()-1; i >= 0; i--) {
                  if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(_false(Order.HandleError("OrderCloseByEx(22)->OrderSelect(i="+ i +", SELECT_BY_POS, MODE_TRADES)  => FALSE", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseByEx(23)")));
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
               if (!remainder) return(_false(Order.HandleError("OrderCloseByEx(24)  cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = larger) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = smaller)", ERR_RUNTIME_ERROR, oeFlags, oe), OrderPop("OrderCloseByEx(25)")));
            }
            oe.setLots           (oe, MathMin(firstLots, secondLots));
            oe.setRemainingTicket(oe, remainder                     );
            oe.setRemainingLots  (oe, remainderLots                 );
         }

         if (IsLogDebug()) logDebug("OrderCloseByEx(26)  "+ OrderCloseByEx.SuccessMsg(first, second, largerType, oe));
         if (!__isTesting) PlaySoundEx("OrderOk.wav");
         return(!oe.setError(oe, catch("OrderCloseByEx(27)", NULL, O_POP)));     // regular exit (NO_ERROR)
      }

      error = oe.setError(oe, GetLastError());

      switch (error) {
         case ERR_TRADE_CONTEXT_BUSY:
            if (IsLogDebug()) logDebug("OrderCloseByEx(28)  trade context busy, retrying...");
            Sleep(300);
            continue;

         case ERR_SERVER_BUSY:
         case ERR_TRADE_TIMEOUT:
            tempErrors++;
            if (tempErrors > 5) break;
            logWarn("OrderCloseByEx(29)  "+ Order.TempErrorMsg(oe, tempErrors), error);
            continue;

         // map terminal generated errors
         case ERR_INVALID_TICKET:                 // unknown tickets or not open positions anymore (client-side)                          ! not yet encountered
            if (IsLogDebug()) logDebug("OrderCloseByEx(30)  translating returned ERR_INVALID_TICKET => ERR_INVALID_TRADE_PARAMETERS");
            error = ERR_INVALID_TRADE_PARAMETERS;
            break;

         case ERR_OFF_QUOTES:                     // positions are locked and in processing queue (server-side) => SL/TP are executed     ! not yet encountered
            if (IsLogDebug()) logDebug("OrderCloseByEx(31)  translating returned ERR_OFF_QUOTES => ERR_INVALID_TRADE_PARAMETERS");
            error = ERR_INVALID_TRADE_PARAMETERS;
            break;

         case ERR_INVALID_TRADE_PARAMETERS:       // positions are processed and not open anymore (server-side)
            break;

         case NO_ERROR:
            if (IsLogNotice()) logNotice("OrderCloseByEx(32)  no error returned => ERR_RUNTIME_ERROR");
            error = oe.setError(oe, ERR_RUNTIME_ERROR);
            break;
      }
      break;                                      // fail for all other errors
   }
   return(_false(Order.HandleError("OrderCloseByEx(33)  "+ OrderCloseByEx.ErrorMsg(first, second, oe), error, oeFlags, oe, true), OrderPop("OrderCloseByEx(34)")));
}


/**
 * Compose a log message for successful execution of OrderCloseByEx().
 *
 * @param  int first      - first ticket to close
 * @param  int second     - second ticket to close
 * @param  int largerType - order type of the ticket with the larger lots
 * @param  int oe[]       - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderCloseByEx.SuccessMsg(int first, int second, int largerType, int oe[]) {
   // closed #30 by #38, remainder: #39 Buy 0.6 GBPUSD after 0.000 s
   // closed #31 by #39, no remainder after 0.000 s

   string message = "closed #"+ first +" by #"+ second;

   int remainder = oe.RemainingTicket(oe);
   if (remainder != 0) message = message +", remainder: #"+ remainder +" "+ OperationTypeDescription(largerType) +" "+ NumberToStr(oe.RemainingLots(oe), ".+") +" "+ oe.Symbol(oe);
   else                message = message +", no remainder";
   if (!__isTesting)   message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
   return(message);
}


/**
 * Compose a log message for failed execution of OrderCloseByEx().
 *
 * @param  int first  - first ticket to close
 * @param  int second - second ticket to close
 * @param  int oe[]   - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderCloseByEx.ErrorMsg(int first, int second, /*ORDER_EXECUTION*/int oe[]) {
   // error while trying to close #1 by #2 after 0.345 s

   string message = "error while trying to close #"+ first +" by #"+ second;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";
   return(message);
}


/**
 * Close multiple positions of mixed symbols in the most efficient way.
 *
 * @param  _In_  int   tickets[]   - ticket ids of the positions to close
 * @param  _In_  int   slippage    - acceptable slippage in points
 * @param  _In_  color markerColor - color of the chart marker set
 * @param  _In_  int   oeFlags     - additional flags controling execution
 * @param  _Out_ int   oes[]       - array of execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: (1) If total positions should be hedged before closing them (default) all fields oe.CloseTime and oe.ClosePrice
 *            contain the values of the symbol's hedging transaction.
 *
 *        (2) The values oe.Swap, oe.Commission and oe.Profit returned by the trade server may differ from the real values
 *            as partial amounts may be accounted to an opposite closing position. All remaining partial amounts are returned
 *            with the last closed ticket per symbol. The sum of all partial returned amounts per symbol matches the total
 *            value of that symbol.
 *
 *        (3) If an error occures it is stored in the field oe.Error of all tickets. Typical trade operation errors are:
 *            - ERR_INVALID_TICKET:           one of the ids is not a valid ticket id
 *            - ERR_INVALID_TRADE_PARAMETERS: one of the tickets is not an open position (anymore)
 */
bool OrdersClose(int tickets[], int slippage, color markerColor, int oeFlags, int oes[][]) {
   // validate parameters
   // oes[][]
   if (ArrayDimension(oes) != 2)                                    return(!catch("OrdersClose(1)  invalid parameter oes[] (illegal number of dimensions: "+ ArrayDimension(oes) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArrayRange(oes, 1) != ORDER_EXECUTION_intSize)               return(!catch("OrdersClose(2)  invalid size of parameter oes["+ ArrayRange(oes, 0) +"]["+ ArrayRange(oes, 1) +"]", ERR_INCOMPATIBLE_ARRAY));
   int sizeOfTickets = ArraySize(tickets);
   ArrayResize(oes, Max(sizeOfTickets, 1));  ArrayInitialize(oes, 0);
   // tickets[]
   if (!sizeOfTickets)                                              return(!Order.HandleError("OrdersClose(3)  invalid parameter tickets (size = 0)", ERR_INVALID_PARAMETER, oeFlags, oes));
   // slippage
   if (slippage < 0)                                                return(!Order.HandleError("OrdersClose(4)  illegal parameter slippage: "+ slippage, ERR_INVALID_PARAMETER, oeFlags, oes));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')      return(!Order.HandleError("OrdersClose(5)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oes));

   // initialize oes[]
   OrderPush("OrdersClose(6)");
   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrdersClose(7)"))              return(_false(oes.setError(oes, -1, ERR_INVALID_TICKET), OrderPop("OrdersClose(8)")));
      oes.setTicket    (oes, i, tickets[i]);
      oes.setSymbol    (oes, i, OrderSymbol());
      oes.setDigits    (oes, i, MarketInfo(OrderSymbol(), MODE_DIGITS));
      if (OrderCloseTime() != 0)                                    return(_false(Order.HandleError("OrdersClose(9)  ticket #"+ tickets[i] +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersClose(10)")));
      if (OrderType() > OP_SELL)                                    return(_false(Order.HandleError("OrdersClose(11)  ticket #"+ tickets[i] +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersClose(12)")));
      oes.setType      (oes, i, OrderType());
      oes.setLots      (oes, i, OrderLots());
      oes.setOpenTime  (oes, i, OrderOpenTime());
      oes.setOpenPrice (oes, i, OrderOpenPrice());
      oes.setStopLoss  (oes, i, OrderStopLoss());
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment());
   }
   OrderPop("OrdersClose(13)");

   // read the passed ticket symbols and map ticket and symbol indexes
   string symbol="", symbols[];    ArrayResize(symbols, 0);                   // all symbols
   int symbols.lastTicketIdx[]; ArrayResize(symbols.lastTicketIdx, 0);
   int si, tickets.symbolIdx[]; ArrayResize(tickets.symbolIdx, sizeOfTickets);

   for (int ti=0; ti < sizeOfTickets; ti++) {                                 // ticket index
      symbol = oes.Symbol(oes, ti);
      si = SearchStringArray(symbols, symbol);                                // symbol index
      if (si == -1) {
         si = ArrayResize(symbols.lastTicketIdx, ArrayPushString(symbols, symbol)) - 1;
      }
      tickets.symbolIdx    [ti] = si;                                         // index of the symbol in symbols[] for each ticket
      symbols.lastTicketIdx[si] = ti;                                         // index of the last ticket in tickets[] for each symbol
   }

   // close tickets together if all are of the same symbol
   int oes2[][ORDER_EXECUTION_intSize];
   int sizeOfSymbols = ArraySize(symbols);
   if (sizeOfSymbols == 1) {
      if (!OrdersCloseSameSymbol(tickets, slippage, markerColor, oeFlags, oes2))
         return(!oes.setError(oes, -1, oes.Error(oes2, 0)));
      CopyMemory(GetIntsAddress(oes), GetIntsAddress(oes2), ArraySize(oes2)*4);
      ArrayResize(oes2, 0);
      return(!Order.HandleError("OrdersClose(14)", GetLastError(), oeFlags, oes));
   }

   // tickets belong to multiple symbols
   // we are not in the Tester
   if (IsLogDebug()) logDebug("OrdersClose(15)  closing "+ sizeOfTickets +" mixed positions "+ TicketsToStr.Lots(tickets));

   // continue with a modifyable copy of tickets[]
   int ticketsCopy[], flatSymbols[]; ArrayResize(ticketsCopy, 0); ArrayResize(flatSymbols, 0);
   int sizeOfTicketsCopy = ArrayCopy(ticketsCopy, tickets), pos, group[], sizeOfGroup;

   // step 1: group tickets per symbol and hedge each group (fastest way)
   for (si=0; si < sizeOfSymbols; si++) {
      ArrayResize(group, 0);
      for (i=0; i < sizeOfTicketsCopy; i++) {
         if (tickets.symbolIdx[i] == si)
            ArrayPushInt(group, ticketsCopy[i]);
      }
      int newTicket = OrdersHedge(group, slippage, oeFlags, oes2);               // newTicket = -1: no new ticket (one of the tickets was fully closed)
      if (!newTicket && oes.Error(oes2, 0))                                      // newTicket =  0: error or total position was already flat
         return(!oes.setError(oes, -1, oes.Error(oes2, 0)));                     // newTicket >  0: new ticket of offsetting transaction (new position) or remaining position after a partial close

      // copy execution details back to the respective passed ticket
      sizeOfGroup = ArraySize(group);
      for (i=0; i < sizeOfGroup; i++) {
         pos = SearchIntArray(tickets, group[i]);
         oes.setBid       (oes, pos, oes.Bid       (oes2, i));
         oes.setAsk       (oes, pos, oes.Ask       (oes2, i));
         oes.setCloseTime (oes, pos, oes.CloseTime (oes2, i));
         oes.setClosePrice(oes, pos, oes.ClosePrice(oes2, i));
         oes.setDuration  (oes, pos, oes.Duration  (oes2, i));
         oes.setRequotes  (oes, pos, oes.Requotes  (oes2, i));
         oes.setSlippage  (oes, pos, oes.Slippage  (oes2, i));
      }
      if (newTicket != 0) {                                                      // either one ticket was fully closed or there is a new ticket
         for (i=0; i < sizeOfGroup; i++) {
            if (oes.RemainingTicket(oes2, i) == newTicket) {                     // partially or fully closed ticket found
               pos = SearchIntArray(tickets, group[i]);
               oes.setSwap      (oes, pos, oes.Swap      (oes2, i));
               oes.setCommission(oes, pos, oes.Commission(oes2, i));
               oes.setProfit    (oes, pos, oes.Profit    (oes2, i));

               pos = SearchIntArray(ticketsCopy, group[i]);
               sizeOfTicketsCopy -= ArraySpliceInts(ticketsCopy,       pos, 1);  // drop the closed ticket
                                    ArraySpliceInts(tickets.symbolIdx, pos, 1);
               sizeOfGroup--;
               break;
            }
         }
         if (newTicket > 0) {
            sizeOfTicketsCopy = ArrayPushInt(ticketsCopy, newTicket);            // add the new ticket (if any)
                                ArrayPushInt(tickets.symbolIdx,  si);
            sizeOfGroup++;
         }
      }

      if (sizeOfGroup > 0)
         ArrayPushInt(flatSymbols, si);                                          // memorize the now hedged symbol (to be closed in step 2)
   }

   // step 2: close all hedged symbols with remaining positions
   int sizeOfFlats = ArraySize(flatSymbols);
   for (si=0; si < sizeOfFlats; si++) {
      ArrayResize(group, 0);
      for (ti=0; ti < sizeOfTicketsCopy; ti++) {
         if (flatSymbols[si] == tickets.symbolIdx[ti])
            ArrayPushInt(group, ticketsCopy[ti]);
      }
      if (!OrdersCloseHedged(group, markerColor, oeFlags, oes2))
         return(!oes.setError(oes, -1, oes.Error(oes2, 0)));

      // copy execution details back to the respective passed ticket
      sizeOfGroup = ArraySize(group);
      for (int gi=0; gi < sizeOfGroup; gi++) {
         pos = SearchIntArray(tickets, group[gi]);
         if (pos == -1)                                                          // assign values of new tickets to the last passed ticket
            pos = symbols.lastTicketIdx[flatSymbols[si]];
         oes.addSwap      (oes, pos, oes.Swap      (oes2, gi));
         oes.addCommission(oes, pos, oes.Commission(oes2, gi));                  // add-up values to existing values
         oes.addProfit    (oes, pos, oes.Profit    (oes2, gi));
      }
   }

   ArrayResize(oes2, 0);
   return(!Order.HandleError("OrdersClose(16)", GetLastError(), oeFlags, oes));
}


/**
 * Close multiple positions of the same symbol in the most efficient way.
 *
 * @param  _In_  int   tickets[]   - order tickets to close
 * @param  _In_  int   slippage    - acceptable slippage in points
 * @param  _In_  color markerColor - color of the chart marker to set
 * @param  _In_  int   oeFlags     - flags controlling trade request execution:
 *                                   F_OE_DONT_HEDGE - don't hedge the total position with an opposite trade transaction
 * @param  _Out_ int   oes[][]     - array of execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: (1) If the total position is hedged before closing (default) all fields oe.CloseTime and oe.ClosePrice contain the
 *            values of the hedging transaction.
 *
 *        (2) The values oe.Swap, oe.Commission and oe.Profit returned by the trade server may differ from the real values
 *            as partial amounts may be accounted to an opposite closing position. All remaining partial amounts are returned
 *            with the last passed ticket. The sum of all partial returned amounts matches the total value of all tickets.
 *
 *        (3) If an error occures it is stored in the field oe.Error of all tickets. Typical trade operation errors are:
 *            - ERR_INVALID_TICKET:           one of the ids is not a valid ticket id
 *            - ERR_INVALID_TRADE_PARAMETERS: one of the tickets is not an open position (anymore)
 *            - ERR_MIXED_SYMBOLS:            the tickets belong to mixed symbols
 */
bool OrdersCloseSameSymbol(int tickets[], int slippage, color markerColor, int oeFlags, int oes[][]) {
   // validate parameters
   // oes[][]
   if (ArrayDimension(oes) != 2)                                      return(!catch("OrdersCloseSameSymbol(1)  invalid parameter oes[] (illegal number of dimensions: "+ ArrayDimension(oes) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArrayRange(oes, 1) != ORDER_EXECUTION_intSize)                 return(!catch("OrdersCloseSameSymbol(2)  invalid size of parameter oes["+ ArrayRange(oes, 0) +"]["+ ArrayRange(oes, 1) +"]", ERR_INCOMPATIBLE_ARRAY));
   int sizeOfTickets = ArraySize(tickets);
   ArrayResize(oes, Max(sizeOfTickets, 1));  ArrayInitialize(oes, 0);
   // tickets[]
   if (!sizeOfTickets)                                                return(!Order.HandleError("OrdersCloseSameSymbol(3)  invalid parameter tickets (size = 0)", ERR_INVALID_PARAMETER, oeFlags, oes));
   // slippage
   if (slippage < 0)                                                  return(!Order.HandleError("OrdersCloseSameSymbol(4)  illegal parameter slippage: "+ slippage, ERR_INVALID_PARAMETER, oeFlags, oes));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')        return(!Order.HandleError("OrdersCloseSameSymbol(5)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oes));

   // initialize oes[]
   if (!SelectTicket(tickets[0], "OrdersCloseSameSymbol(6)", O_PUSH)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
   string symbol = OrderSymbol();
   int    digits = MarketInfo(OrderSymbol(), MODE_DIGITS);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrdersCloseSameSymbol(7)"))      return(_false(oes.setError(oes, -1, ERR_INVALID_TICKET), OrderPop("OrdersCloseSameSymbol(8)")));
      if (OrderSymbol() != symbol)                                    return(_false(Order.HandleError("OrdersCloseSameSymbol(9)  tickets belong to multiple symbols", ERR_MIXED_SYMBOLS, oeFlags, oes), OrderPop("OrdersCloseSameSymbol(10)")));
      oes.setTicket    (oes, i, tickets[i]       );
      oes.setSymbol    (oes, i, symbol           );
      oes.setDigits    (oes, i, digits           );
      if (OrderCloseTime() != 0)                                      return(_false(Order.HandleError("OrdersCloseSameSymbol(11)  ticket #"+ tickets[i] +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersCloseSameSymbol(12)")));
      if (OrderType() > OP_SELL)                                      return(_false(Order.HandleError("OrdersCloseSameSymbol(13)  ticket #"+ tickets[i] +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersCloseSameSymbol(14)")));
      oes.setType      (oes, i, OrderType()      );
      oes.setLots      (oes, i, OrderLots()      );
      oes.setOpenTime  (oes, i, OrderOpenTime()  );
      oes.setOpenPrice (oes, i, OrderOpenPrice() );
      oes.setStopLoss  (oes, i, OrderStopLoss()  );
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment()   );
   }
   OrderPop("OrdersCloseSameSymbol(15)");

   // simple close if a single ticket was passed or the flag F_OE_DONT_HEDGE is set
   if (sizeOfTickets==1 || oeFlags & F_OE_DONT_HEDGE) {
      int oe[], src, dest;
      for (i=0; i < sizeOfTickets; i++) {
         if (!OrderCloseEx(tickets[i], NULL, slippage, markerColor, oeFlags, oe)) return(!oes.setError(oes, -1, oe.Error(oe)));
         src  = GetIntsAddress(oe);
         dest = GetIntsAddress(oes) + i*ORDER_EXECUTION_intSize*4;
         CopyMemory(dest, src, ArraySize(oe)*4);
      }
      ArrayResize(oe, 0);
      return(true);
   }

   // multiple close
   if (IsLogDebug()) logDebug("OrdersCloseSameSymbol(16)  closing "+ sizeOfTickets +" "+ symbol +" positions "+ TicketsToStr.Lots(tickets));

   // continue with a modifyable copy of tickets[]
   int ticketsCopy[]; ArrayResize(ticketsCopy, 0);
   int sizeOfCopy = ArrayCopy(ticketsCopy, tickets);

   // hedge the total position
   int oes2[][ORDER_EXECUTION_intSize];                                 // newTicket = -1: no new ticket (one of the tickets was fully closed)
   int newTicket = OrdersHedge(ticketsCopy, slippage, oeFlags, oes2);   // newTicket =  0: error or total position was already flat
   if (IsError(oes.Error(oes2, 0)))                                     // newTicket >  0: new ticket of offsetting transaction (new position) or remaining position after a partial close
      return(!oes.setError(oes, -1, oes.Error(oes2, 0)));

   for (i=0; i < sizeOfTickets; i++) {
      oes.setBid       (oes, i, oes.Bid       (oes2, i));
      oes.setAsk       (oes, i, oes.Ask       (oes2, i));
      oes.setCloseTime (oes, i, oes.CloseTime (oes2, i));
      oes.setClosePrice(oes, i, oes.ClosePrice(oes2, i));
      oes.setDuration  (oes, i, oes.Duration  (oes2, i));
      oes.setRequotes  (oes, i, oes.Requotes  (oes2, i));
      oes.setSlippage  (oes, i, oes.Slippage  (oes2, i));
   }
   if (newTicket != 0) {
      for (i=0; i < sizeOfTickets; i++) {
         if (oes.RemainingTicket(oes2, i) == newTicket) {
            oes.setSwap      (oes, i, oes.Swap      (oes2, i));
            oes.setCommission(oes, i, oes.Commission(oes2, i));
            oes.setProfit    (oes, i, oes.Profit    (oes2, i));
            sizeOfCopy -= ArraySpliceInts(ticketsCopy, i, 1);           // drop the closed ticket
            break;
         }
      }
      if (newTicket > 0)
         sizeOfCopy = ArrayPushInt(ticketsCopy, newTicket);             // add the new open ticket
   }

   // close the hedged position
   if (!OrdersCloseHedged(ticketsCopy, markerColor, oeFlags, oes2))
      return(!oes.setError(oes, -1, oes.Error(oes2, 0)));

   for (i=0; i < sizeOfCopy; i++) {
      int pos = SearchIntArray(tickets, ticketsCopy[i]);
      if (pos == -1)
         pos = sizeOfTickets-1;
      oes.addSwap      (oes, pos, oes.Swap      (oes2, i));             // add transaction results of new tickets to the last passed ticket
      oes.addCommission(oes, pos, oes.Commission(oes2, i));
      oes.addProfit    (oes, pos, oes.Profit    (oes2, i));
   }

   ArrayResize(oes2,        0);
   ArrayResize(ticketsCopy, 0);
   return(!Order.HandleError("OrdersCloseSameSymbol(17)", GetLastError(), oeFlags, oes));
}


/**
 * Offset multiple positions and create a flat (hedged) total position by submitting a single trade operation request.
 * Preferably one of the positions is closed. If a (partial) close doesn't yield the intended result an additional hedging
 * position is opened. All passed order tickets must belong to the same symbol.
 *
 * @param  _In_  int tickets[] - order tickets to offset
 * @param  _In_  int slippage  - acceptable slippage in points for the offsetting transaction
 * @param  _In_  int oeFlags   - flags controlling trade request execution:
 *                               F_OE_DONT_CHECK_STATUS - don't check the ticket's order status to prevent
 *                                                        ERR_INVALID_TRADE_PARAMETERS if a ticket is already closed
 * @param  _Out_ int oes[][]   - array of execution details (struct ORDER_EXECUTION)
 *
 * @return int - the resulting ticket id of an offsetting transaction (a new position or a partial remainder) or
 *               -1 if one of the positions was fully closed or
 *                0 if the total position was already flat or in case of errors (check oe.Error)
 *
 * Notes: (1) If one of the tickets was fully closed to offset the total position the return value -1 is stored in
 *            oe.RemainingTicket of the fully closed ticket and oe.RemainingLots of the ticket is set to zero (0). oe.Swap,
 *            oe.Commission und oe.Profit of the ticket are updated accordingly.
 *
 *        (2) If one of the tickets was partially closed to offset the total position the return value (new ticket of the
 *            remaining position) is stored in oe.RemainingTicket of the partially closed ticket and oe.RemainingLots of the
 *            ticket is set to the lotsize of the remaining position. oe.Swap, oe.Commission und oe.Profit of the ticket are
 *            updated accordingly.
 *
 *        (3) Time and price of the last (the offsetting) transaction are stored as oe.CloseTime/oe.ClosePrice of all tickets.
 *
 *        (4) In case of errors the error is stored in oe.Error of all tickets. Typical trade operation errors are:
 *            - ERR_INVALID_TICKET:           one of the ids is not a valid ticket id
 *            - ERR_INVALID_TRADE_PARAMETERS: one of the tickets is not an open position (anymore)
 *            - ERR_MIXED_SYMBOLS:            the tickets belong to mixed symbols
 */
int OrdersHedge(int tickets[], int slippage, int oeFlags, int oes[][]) {
   // validate parameters
   // oes[][]
   if (ArrayDimension(oes) != 2)                                    return(!catch("OrdersHedge(1)  invalid parameter oes[] (illegal number of dimensions: "+ ArrayDimension(oes) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArrayRange(oes, 1) != ORDER_EXECUTION_intSize)               return(!catch("OrdersHedge(2)  invalid size of parameter oes["+ ArrayRange(oes, 0) +"]["+ ArrayRange(oes, 1) +"]", ERR_INCOMPATIBLE_ARRAY));
   int sizeOfTickets = ArraySize(tickets);
   ArrayResize(oes, Max(sizeOfTickets, 1)); ArrayInitialize(oes, 0);
   // tickets[]
   if (!sizeOfTickets)                                              return(!Order.HandleError("OrdersHedge(3)  invalid parameter tickets (size=0)", ERR_INVALID_PARAMETER, oeFlags, oes));
   // slippage
   if (slippage < 0)                                                return(!Order.HandleError("OrdersHedge(4)  illegal parameter slippage: "+ slippage, ERR_INVALID_PARAMETER, oeFlags, oes));

   // initialize oes[]
   if (!SelectTicket(tickets[0], "OrdersHedge(5)", O_PUSH))         return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
   string symbol = OrderSymbol();
   int    digits = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double totalLots, lots[]; ArrayResize(lots, 0);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrdersHedge(6)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
      if (OrderSymbol() != symbol)                                  return(_false(Order.HandleError("OrdersHedge(7)  tickets belong to multiple symbols", ERR_MIXED_SYMBOLS, oeFlags, oes), OrderPop("OrdersHedge(8)")));
      oes.setTicket    (oes, i, tickets[i]       );
      oes.setSymbol    (oes, i, symbol           );
      oes.setDigits    (oes, i, digits           );
      if (OrderCloseTime() && !(oeFlags & F_OE_DONT_CHECK_STATUS))  return(_false(Order.HandleError("OrdersHedge(9)  ticket #"+ tickets[i] +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersHedge(10)")));
      if (OrderType() > OP_SELL)                                    return(_false(Order.HandleError("OrdersHedge(11)  ticket #"+ tickets[i] +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersHedge(12)")));
      oes.setType      (oes, i, OrderType()      );
      oes.setLots      (oes, i, OrderLots()      );
      oes.setOpenTime  (oes, i, OrderOpenTime()  );
      oes.setOpenPrice (oes, i, OrderOpenPrice() );
      oes.setStopLoss  (oes, i, OrderStopLoss()  );
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment()   );

      if (OrderType() == OP_BUY) { totalLots += OrderLots(); ArrayPushDouble(lots,  OrderLots()); }
      else                       { totalLots -= OrderLots(); ArrayPushDouble(lots, -OrderLots()); }
   }
   int newTicket = 0;

   if (EQ(totalLots, 0)) {
      // total position is already flat
      if (IsLogDebug()) logDebug("OrdersHedge(13)  "+ sizeOfTickets +" "+ symbol +" positions "+ TicketsToStr.Lots(tickets) +" are already flat");

      // set all CloseTime/ClosePrices to OpenTime/OpenPrice of the ticket opened last
      int ticketsCopy[]; ArrayResize(ticketsCopy, 0);
      ArrayCopy(ticketsCopy, tickets);
      SortTicketsChronological(ticketsCopy);
      if (!SelectTicket(ticketsCopy[sizeOfTickets-1], "OrdersHedge(14)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
      for (i=0; i < sizeOfTickets; i++) {
         oes.setBid       (oes, i, MarketInfo(symbol, MODE_BID));
         oes.setAsk       (oes, i, MarketInfo(symbol, MODE_ASK));
         oes.setCloseTime (oes, i, OrderOpenTime()             );
         oes.setClosePrice(oes, i, OrderOpenPrice()            );
      }
      OrderPop("OrdersHedge(15)");
      ArrayResize(ticketsCopy, 0);
   }
   else {
      // total position is not flat
      OrderPop("OrdersHedge(16)");
      if (IsLogDebug()) logDebug("OrdersHedge(17)  hedging "+ sizeOfTickets +" "+ symbol +" position"+ ifString(sizeOfTickets==1, " ", "s ") + TicketsToStr.Lots(tickets));
      int closeTicket, totalDir=ifInt(GT(totalLots, 0), OP_LONG, OP_SHORT), oe[];

      // if possible use OrderCloseEx() for hedging (reduces MarginRequired and cannot cause violation of TradeserverLimit)
      if (!(oeFlags & F_OE_DONT_CHECK_STATUS)) {
         for (i=0; i < sizeOfTickets; i++) {
            if (EQ(lots[i], totalLots)) {                // first find a ticket to close completely
               closeTicket = tickets[i];
               break;
            }
         }
         if (!closeTicket) {
            for (i=0; i < sizeOfTickets; i++) {          // if not found, find a ticket to close partially
               if (totalDir == OP_LONG) {
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
      }

      if (closeTicket != 0) {
         // partial or complete close of an existing ticket
         if (!OrderCloseEx(closeTicket, MathAbs(totalLots), slippage, CLR_NONE, oeFlags, oe))
            return(!oes.setError(oes, -1, oe.Error(oe)));
         newTicket = oe.RemainingTicket(oe);

         for (i=0; i < sizeOfTickets; i++) {
            oes.setBid       (oes, i, oe.Bid       (oe));
            oes.setAsk       (oes, i, oe.Ask       (oe));
            oes.setCloseTime (oes, i, oe.CloseTime (oe));
            oes.setClosePrice(oes, i, oe.ClosePrice(oe));
            oes.setDuration  (oes, i, oe.Duration  (oe));
            oes.setRequotes  (oes, i, oe.Requotes  (oe));
            oes.setSlippage  (oes, i, oe.Slippage  (oe));

            if (tickets[i] == closeTicket) {
               oes.setSwap      (oes, i, oe.Swap      (oe));
               oes.setCommission(oes, i, oe.Commission(oe));
               oes.setProfit    (oes, i, oe.Profit    (oe));
               if (!newTicket) {                                         newTicket = oes.setRemainingTicket(oes, i, -1       ); }   // ticket was completely closed
               else            { oes.setRemainingLots(oes, i, oe.RemainingLots(oe)); oes.setRemainingTicket(oes, i, newTicket); }   // ticket was partially closed
            }
         }
      }
      else {
         // open a new hedging position/ticket
         if (!OrderSendEx(symbol, totalDir^1, MathAbs(totalLots), NULL, slippage, NULL, NULL, NULL, NULL, NULL, CLR_NONE, oeFlags, oe))
            return(!oes.setError(oes, -1, oe.Error(oe)));
         newTicket = oe.Ticket(oe);

         for (i=0; i < sizeOfTickets; i++) {
            oes.setBid       (oes, i, oe.Bid       (oe));
            oes.setAsk       (oes, i, oe.Ask       (oe));
            oes.setCloseTime (oes, i, oe.OpenTime  (oe));
            oes.setClosePrice(oes, i, oe.OpenPrice (oe));
            oes.setDuration  (oes, i, oe.Duration  (oe));
            oes.setRequotes  (oes, i, oe.Requotes  (oe));
            oes.setSlippage  (oes, i, oe.Slippage  (oe));
         }
      }
      ArrayResize(oe, 0);
   }
   ArrayResize(lots, 0);

   if (!Order.HandleError("OrdersHedge(18)", GetLastError(), oeFlags, oes))
      return(newTicket);
   return(NULL);
}


/**
 * Close multiple orders forming a hedged (flat) position. All passed tickets must belong to the same symbol.
 *
 * @param  _In_  int   tickets[]   - order tickets forming the flat position
 * @param  _In_  color markerColor - color of the chart markers to set
 * @param  _In_  int   oeFlags     - flags controlling trade request execution
 * @param  _Out_ int   oes[][]     - array of execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: (1) OpenTime/OpenPrice of the newest ticket (the hedging transaction) become CloseTime/ClosePrice of all tickets.
 *
 *        (2) Returned oe.Swap, oe.Commission and oe.Profit of single tickets may differ from actual values. However the
 *            summed-up values of all tickets are consistent with actual total values.
 *
 *        (3) If an error occurred it is stored in the field oe.Error of all tickets. Typical trade operation errors are:
 *            - ERR_INVALID_TICKET:           one of the ids is not a valid ticket id
 *            - ERR_MIXED_SYMBOLS:            the tickets belong to multiple symbols
 *            - ERR_TOTAL_POSITION_NOT_FLAT:  the total position of all tickets is not flat
 *            - ERR_INVALID_TRADE_PARAMETERS: one of the tickets is not an open position (anymore)
 */
bool OrdersCloseHedged(int tickets[], color markerColor, int oeFlags, int oes[][]) {
   // validate parameters
   // oes[][]
   if (ArrayDimension(oes) != 2)                                          return(!catch("OrdersCloseHedged(1)  invalid parameter oes[] (illegal number of dimensions: "+ ArrayDimension(oes) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArrayRange(oes, 1) != ORDER_EXECUTION_intSize)                     return(!catch("OrdersCloseHedged(2)  invalid size of parameter oes["+ ArrayRange(oes, 0) +"]["+ ArrayRange(oes, 1) +"]", ERR_INCOMPATIBLE_ARRAY));
   int sizeOfTickets = ArraySize(tickets);
   ArrayResize(oes, Max(sizeOfTickets, 1)); ArrayInitialize(oes, 0);
   // tickets[]
   if (sizeOfTickets < 2)                                                 return(!Order.HandleError("OrdersCloseHedged(3)  invalid parameter tickets (size="+ sizeOfTickets +")", ERR_INVALID_PARAMETER, oeFlags, oes));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')            return(!Order.HandleError("OrdersCloseHedged(4)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oes));

   // initialize oes[]
   if (!SelectTicket(tickets[0], "OrdersCloseHedged(5)", O_PUSH))         return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
   string symbol = OrderSymbol();
   int    digits = MarketInfo(symbol, MODE_DIGITS);
   double bid    = MarketInfo(symbol, MODE_BID);
   double ask    = MarketInfo(symbol, MODE_ASK);
   double lots   = 0;

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrdersCloseHedged(6)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
      if (OrderSymbol() != symbol)                                        return(_false(Order.HandleError("OrdersCloseHedged(7)  tickets belong to multiple symbols", ERR_MIXED_SYMBOLS, oeFlags, oes), OrderPop("OrdersCloseHedged(8)")));
      oes.setTicket    (oes, i, tickets[i]       );
      oes.setSymbol    (oes, i, symbol           );
      oes.setDigits    (oes, i, digits           );
      oes.setBid       (oes, i, bid              );
      oes.setAsk       (oes, i, ask              );
      if (OrderCloseTime() != 0)                                          return(_false(Order.HandleError("OrdersCloseHedged(9)  ticket #"+ tickets[i] +" is already closed", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersCloseHedged(10)")));
      if (OrderType() > OP_SELL)                                          return(_false(Order.HandleError("OrdersCloseHedged(11)  ticket #"+ tickets[i] +" is not an open position: "+ OperationTypeDescription(OrderType()), ERR_INVALID_TRADE_PARAMETERS, oeFlags, oes), OrderPop("OrdersCloseHedged(12)")));
      oes.setType      (oes, i, OrderType()      );
      oes.setLots      (oes, i, OrderLots()      );
      lots += ifInt(OrderType()==OP_BUY, +1, -1) * OrderLots();
      oes.setOpenTime  (oes, i, OrderOpenTime()  );
      oes.setOpenPrice (oes, i, OrderOpenPrice() );
      oes.setStopLoss  (oes, i, OrderStopLoss()  );
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment()   );
   }
   if (NE(lots, 0, 2)) return(_false(Order.HandleError("OrdersCloseHedged(13)  tickets don't form a flat position (total position: "+ DoubleToStr(lots, 2) +")", ERR_TOTAL_POSITION_NOT_FLAT, oeFlags, oes), OrderPop("OrdersCloseHedged(14)")));

   if (IsLogDebug()) logDebug("OrdersCloseHedged(15)  closing "+ sizeOfTickets +" hedged "+ OrderSymbol() +" positions "+ TicketsToStr.Lots(tickets));

   // continue with a modifyable copy of tickets[]
   int ticketsCopy[]; ArrayResize(ticketsCopy, 0);
   int sizeOfCopy = ArrayCopy(ticketsCopy, tickets);

   // resolve the youngest ticket
   SortTicketsChronological(ticketsCopy);
   if (!SelectTicket(ticketsCopy[sizeOfCopy-1], "OrdersCloseHedged(16)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
   for (i=0; i < sizeOfTickets; i++) {
      oes.setCloseTime (oes, i, OrderOpenTime() );                      // use the youngest ticket for close values of all others
      oes.setClosePrice(oes, i, OrderOpenPrice());
   }

   // close all (partial) positions one by one
   while (sizeOfCopy > 0) {
      int first = ticketsCopy[0], opposite;
      if (!SelectTicket(first, "OrdersCloseHedged(17)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
      int firstType = OrderType();

      for (i=1; i < sizeOfCopy; i++) {
         if (!SelectTicket(ticketsCopy[i], "OrdersCloseHedged(18)", NULL, O_POP)) return(!oes.setError(oes, -1, ERR_INVALID_TICKET));
         if (OrderType() == firstType^1) {
            opposite = ticketsCopy[i];                                  // find the first opposite match
            break;
         }
      }
      if (!opposite) return(_false(Order.HandleError("OrdersCloseHedged(19)  cannot find opposite position for "+ OperationTypeDescription(firstType) +" ticket #"+ first, ERR_TOTAL_POSITION_NOT_FLAT, oeFlags, oes), OrderPop("OrdersCloseHedged(20)")));

      int oe[];
      if (!OrderCloseByEx(first, opposite, markerColor, oeFlags, oe))   // close first and opposite position
         return(_false(oes.setError(oes, -1, oe.Error(oe)), OrderPop("OrdersCloseHedged(21)")));

      sizeOfCopy -= ArraySpliceInts(ticketsCopy, 0, 1);                 // drop first and opposite ticket
      sizeOfCopy -= ArrayDropInt(ticketsCopy, opposite);

      int newTicket = oe.RemainingTicket(oe);
      if (newTicket != 0)                                               // add any remaining position
         sizeOfCopy = ArrayPushInt(ticketsCopy, newTicket);

      i = SearchIntArray(tickets, first);                               // resolve the ticket to add trade results to
      if (i == -1) {                                                    // order: first, opposite, last
         i = SearchIntArray(tickets, opposite);
         if (i == -1)
            i = sizeOfTickets-1;
      }
      oes.addSwap      (oes, i, oe.Swap      (oe));                     // sum-up values
      oes.addCommission(oes, i, oe.Commission(oe));
      oes.addProfit    (oes, i, oe.Profit    (oe));

      SortTicketsChronological(ticketsCopy);
   }

   ArrayResize(oe,          0);
   ArrayResize(ticketsCopy, 0);
   return(!_bool(Order.HandleError("OrdersCloseHedged(22)", GetLastError(), oeFlags, oes), OrderPop("OrdersCloseHedged(23)")));
}


/**
 * Extended version of OrderDelete().
 *
 * @param  _In_  int   ticket      - order ticket to cancel
 * @param  _In_  color markerColor - color of the chart marker to set
 * @param  _In_  int   oeFlags     - flags controlling trade request execution
 * @param  _Out_ int   oe[]        - execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 *
 * Notes: Typical trade operation errors returned in oe.Error are:
 *        - ERR_INVALID_TICKET:           unknown ticket id
 *        - ERR_INVALID_TRADE_PARAMETERS: ticket is not an open pending order (anymore)
 */
bool OrderDeleteEx(int ticket, color markerColor, int oeFlags, int oe[]) {
   // validate parameters
   // oe[]
   if (ArrayDimension(oe) > 1)                                 return(!catch("OrderDeleteEx(1)  invalid parameter oe[] (too many dimensions: "+ ArrayDimension(oe) +")", ERR_INCOMPATIBLE_ARRAY));
   if (ArraySize(oe) != ORDER_EXECUTION_intSize)
      ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);
   // ticket
   if (!SelectTicket(ticket, "OrderDeleteEx(2)", O_PUSH))      return(!oe.setError(oe, ERR_INVALID_TICKET));
   if (!IsPendingOrderType(OrderType()))                       return(_false(Order.HandleError("OrderDeleteEx(3)  #"+ ticket +" is not a pending order", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderDeleteEx(4)")));
   if (OrderCloseTime() != 0)                                  return(_false(Order.HandleError("OrderDeleteEx(5)  #"+ ticket +" is already deleted", ERR_INVALID_TRADE_PARAMETERS, oeFlags, oe), OrderPop("OrderDeleteEx(6)")));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(Order.HandleError("OrderDeleteEx(7)  illegal parameter markerColor: 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, oeFlags, oe), OrderPop("OrderDeleteEx(8)")));

   // initialize oe[]
   oe.setSymbol    (oe, OrderSymbol()    );
   oe.setDigits    (oe, MarketInfo(OrderSymbol(), MODE_DIGITS));
   oe.setTicket    (oe, ticket           );
   oe.setType      (oe, OrderType()      );
   oe.setLots      (oe, OrderLots()      );
   oe.setOpenTime  (oe, OrderOpenTime()  );
   oe.setOpenPrice (oe, OrderOpenPrice() );
   oe.setStopLoss  (oe, OrderStopLoss()  );
   oe.setTakeProfit(oe, OrderTakeProfit());
   oe.setComment   (oe, OrderComment()   );

   /*
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   |         | Ticket |     Type | Lots | Symbol |            OpenTime | OpenPrice |           CloseTime | ClosePrice | Swap | Commission | Profit | MagicNumber | Comment       |
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   | open    |     #1 | Stop Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.4165'6 |                     |   1.3204'4 | 0.00 |       0.00 |   0.00 |         666 | order comment |
   | deleted |     #1 | Stop Buy | 1.00 | EURUSD | 2012.03.19 11:00:05 |  1.4165'6 | 2012.03.20 12:00:06 |   1.3204'4 | 0.00 |       0.00 |   0.00 |         666 | cancelled     |
   +---------+--------+----------+------+--------+---------------------+-----------+---------------------+------------+------+------------+--------+-------------+---------------+
   */
   int  error, startTime = GetTickCount(), tempErrors;
   bool success;

   // loop until the order was deleted or a non-fixable error occurred
   while (true) {
      // terminal bug: After recompiling and reloading an EA IsStopped() continues to return TRUE.
      if (IsStopped()) return(_false(Order.HandleError("OrderDeleteEx(9)  "+ OrderDeleteEx.ErrorMsg(oe), ERS_EXECUTION_STOPPING, oeFlags, oe), OrderPop("OrderDeleteEx(10)")));

      if (IsTradeContextBusy()) {
         if (IsLogDebug()) logDebug("OrderDeleteEx(11)  trade context busy, retrying...");
         Sleep(300);
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      success = OrderDelete(ticket, markerColor);

      oe.setDuration(oe, GetTickCount()-startTime);

      if (success) {
         WaitForTicket(ticket, /*select=*/true);

         if (!ChartMarker.OrderDeleted_A(ticket, oe.Digits(oe), markerColor))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderDeleteEx(12)")));

         if (IsLogDebug()) logDebug(StringConcatenate("OrderDeleteEx(13)  ", OrderDeleteEx.SuccessMsg(oe)));
         if (!__isTesting) PlaySoundEx("OrderOk.wav");

         return(!oe.setError(oe, catch("OrderDeleteEx(14)", NULL, O_POP)));   // regular exit (NO_ERROR)
      }

      error = GetLastError();

      switch (error) {
         case ERR_TRADE_CONTEXT_BUSY:
            if (IsLogDebug()) logDebug("OrderDeleteEx(15)  trade context busy, retrying...");
            Sleep(300);
            continue;

         case ERR_SERVER_BUSY:
         case ERR_TRADE_TIMEOUT:
            tempErrors++;
            if (tempErrors > 5) break;
            logWarn("OrderDeleteEx(16)  "+ Order.TempErrorMsg(oe, tempErrors), error);
            continue;

         // map terminal generated errors
         case ERR_INVALID_TICKET:                // unknown ticket or not open pending order anymore (client-side)
            if (IsLogDebug()) logDebug("OrderDeleteEx(17)  translating returned ERR_INVALID_TICKET => ERR_INVALID_TRADE_PARAMETERS");
            error = ERR_INVALID_TRADE_PARAMETERS;
            break;
         case ERR_OFF_QUOTES:                    // order is locked and in processing queue (server-side)
            if (IsLogDebug()) logDebug("OrderDeleteEx(18)  translating returned ERR_OFF_QUOTES => ERR_INVALID_TRADE_PARAMETERS");
            error = ERR_INVALID_TRADE_PARAMETERS;
            break;
         case ERR_INVALID_TRADE_PARAMETERS:      // order is processed and not open pending anymore (server-side)
            break;
         case NO_ERROR:
            if (IsLogNotice()) logNotice("OrderDeleteEx(19)  no error returned => ERR_RUNTIME_ERROR");
            error = ERR_RUNTIME_ERROR;
            break;
      }
      break;                                     // fail for all other errors
   }
   return(_false(Order.HandleError("OrderDeleteEx(20)  "+ OrderDeleteEx.ErrorMsg(oe), error, oeFlags, oe, true), OrderPop("OrderDeleteEx(21)")));
}


/**
 * Compose a log message for successful execution of OrderDeleteEx().
 *
 * @param  int oe[] - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderDeleteEx.SuccessMsg(int oe[]) {
   // deleted #1 Stop Buy 0.5 GBPUSD at 1.5520'3 ("SR.12345.+3") after 0.2 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string sComment    = oe.Comment(oe);
      if (StringLen(sComment) > 0) sComment = " \""+ sComment +"\"";
   string strPrice    = NumberToStr(oe.OpenPrice(oe), priceFormat);

   string message = "deleted #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ oe.Symbol(oe) + sComment +" at "+ strPrice;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";

   return(message);
}


/**
 * Compose a log message for failed execution of OrderDeleteEx().
 *
 * @param  int oe[] - execution details (struct ORDER_EXECUTION)
 *
 * @return string
 */
string OrderDeleteEx.ErrorMsg(int oe[]) {
   // The ticket always exists. Typically it is not a pendig order (anymore).
   // error while trying to delete #1 Stop Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8, sl=1.5500'0, tp=1.5600'0 (market: Bid/Ask[, stop distance=2.1 pip]) after 0.345 s
   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string sType       = OperationTypeDescription(oe.Type(oe));
   string sLots       = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string sComment    = oe.Comment(oe);
      if (StringLen(sComment) > 0) sComment = " \""+ sComment +"\"";

   string sPrice  = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string sSL     = ""; if (NE(oe.StopLoss    (oe), 0, digits)) sSL = ", sl="+ NumberToStr(oe.StopLoss  (oe), priceFormat);
   string sTP     = ""; if (NE(oe.TakeProfit  (oe), 0, digits)) sTP = ", tp="+ NumberToStr(oe.TakeProfit(oe), priceFormat);
   string sSD     = ""; if (NE(oe.StopDistance(oe), 0))         sSD = ", stop distance="+ NumberToStr(oe.StopDistance(oe), ".+") +" pip";
   string sMarket = "(market: "+ NumberToStr(oe.Bid(oe), priceFormat) +"/"+ NumberToStr(oe.Ask(oe), priceFormat) + sSD +")";

   string message = "error while trying to delete #"+ oe.Ticket(oe) +" "+ sType +" "+ sLots +" "+ symbol + sComment +" at "+ sPrice + sSL + sTP +" "+ sMarket;
   if (!__isTesting) message = message +" after "+ DoubleToStr(oe.Duration(oe)/1000., 3) +" s";

   return(message);
}


/**
 * Streicht alle offenen Pending-Orders.
 *
 * @param  color markerColor [optional] - Farbe des Chart-Markers (default: kein Marker)
 *
 * @return bool - success status
 */
bool DeletePendingOrders(color markerColor = CLR_NONE) {
   int oeFlags = NULL;
   /*ORDER_EXECUTION*/int oe[];

   int size = OrdersTotal();
   if (size > 0) {
      OrderPush("DeletePendingOrders(1)");
      for (int i=size-1; i >= 0; i--) {                                 // offene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
            continue;
         if (IsPendingOrderType(OrderType())) {
            if (!OrderDeleteEx(OrderTicket(), CLR_NONE, oeFlags, oe))
               return(_false(OrderPop("DeletePendingOrders(2)")));
         }
      }
      OrderPop("DeletePendingOrders(3)");
   }
   ArrayResize(oe, 0);
   return(true);
}


/**
 * Korrigiert die vom Terminal beim Ausführen von OrderSend() gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - success status
 *
 * @see  ChartMarker.OrderSent_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderSent_A(int ticket, int digits, color markerColor) {
   if (!__isChart) return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderSent_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderSent_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderComment());

   return(result && OrderPop("ChartMarker.OrderSent_A(2)"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderSent_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment) {
   if (!__isChart) return(true);

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

   return(!catch("ChartMarker.OrderSent_B()"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderModified_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeprofit) {
   if (!__isChart) return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderModified_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderModified_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), modifyTime, oldOpenPrice, OrderOpenPrice(), oldStopLoss, OrderStopLoss(), oldTakeprofit, OrderTakeProfit(), OrderComment());

   return(result && OrderPop("ChartMarker.OrderModified_A(2)"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderModified_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment) {
   if (!__isChart) return(true);

   bool openModified = NE(openPrice,  oldOpenPrice );
   bool slModified   = NE(stopLoss,   oldStopLoss  );
   bool tpModified   = NE(takeProfit, oldTakeProfit);

   static string types[] = {"buy","sell","buy limit","sell limit","buy stop","sell stop"};

   // OrderOpen-Marker: setzen, korrigieren oder löschen                               // "#1 buy[ stop] 0.10 GBPUSD at 1.52904"
   string label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " ", symbol, " at ");
   if (openModified) {
      string label = StringConcatenate(label1, DoubleToStr(oldOpenPrice, digits));
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

   return(!catch("ChartMarker.OrderModified_B()"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderFilled_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor) {
   if (!__isChart) return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderFilled_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderFilled_B(ticket, pendingType, pendingPrice, digits, markerColor, OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderComment());

   return(result && OrderPop("ChartMarker.OrderFilled_A(2)"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderFilled_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment) {
   if (!__isChart) return(true);

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
   string label3 = StringConcatenate(label1, " ", types[ifInt(IsLongOrderType(pendingType), OP_BUY, OP_SELL)], ifString(__isTesting, " by tester", ""), " at ", DoubleToStr(openPrice, digits));
   if (ObjectFind(label3) == 0)
         ObjectDelete(label3);                                                         // löschen

   // neuen OrderFill-Marker: setzen, korrigieren oder löschen                         // "#1 buy 0.10 GBPUSD at 1.52904"
   string label4 = StringConcatenate("#", ticket, " ", types[ifInt(IsLongOrderType(pendingType), OP_BUY, OP_SELL)], " ", DoubleToStr(lots, 2), " ", symbol, " at ", DoubleToStr(openPrice, digits));
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

   return(!catch("ChartMarker.OrderFilled_B()"));
}


/**
 * Korrigiert die vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - success status
 */
bool ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor) {
   if (!__isChart) return(true);

   if (!SelectTicket(ticket, "ChartMarker.PositionClosed_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.PositionClosed_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice());

   return(result && OrderPop("ChartMarker.PositionClosed_A(2)"));
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
 * @return bool - success status
 */
bool ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   if (!__isChart) return(true);

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
   string label3 = StringConcatenate(label1, " close", ifString(__isTesting, " by tester", ""), " at ", DoubleToStr(closePrice, digits));
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

   return(!catch("ChartMarker.PositionClosed_B()"));
}


/**
 * Korrigiert die vom Terminal beim Löschen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 * Das Ticket muß während der Ausführung selektierbar sein.
 *
 * @param  int   ticket      - Ticket
 * @param  int   digits      - Nachkommastellen des Ordersymbols
 * @param  color markerColor - Farbe des Chartmarkers
 *
 * @return bool - success status
 *
 * @see  ChartMarker.OrderDeleted_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor) {
   if (!__isChart) return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderDeleted_A(1)", O_PUSH))
      return(false);

   bool result = ChartMarker.OrderDeleted_B(ticket, digits, markerColor, OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice());

   return(result && OrderPop("ChartMarker.OrderDeleted_A(2)"));
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
 * @return bool - success status
 *
 * @see  ChartMarker.OrderDeleted_A(), wenn das Ticket während der Ausführung selektierbar ist
 */
bool ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   if (!__isChart) return(true);

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
         ObjectSet(label2, OBJPROP_COLOR, ifInt(IsLongOrderType(type), Blue, Red));
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

   return(!catch("ChartMarker.OrderDeleted_B()"));
}


/**
 * MQL-Wrapper für die Win32-Funktion GetTempPath().
 *
 * @return string - Dateipfad für temporäre Dateien oder Leerstring, falls ein Fehler auftrat
 */
string GetTempPath() {
   int    bufferSize = MAX_PATH;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetTempPathA(bufferSize, buffer[0]);
   if (chars > bufferSize) {
      bufferSize = chars;
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetTempPathA(bufferSize, buffer[0]);
   }
   if (!chars) return(_EMPTY_STR(catch("GetTempPath(1)->kernel32::GetTempPathA() => 0", ERR_WIN32_ERROR)));

   string tmpPath = buffer[0];
   ArrayResize(buffer, 0);
   return(tmpPath);
}


/**
 * Erzeugt eine eindeutige Datei im angegebenen Verzeichnis.
 *
 * @param  string path   - Name des Verzeichnisses, in dem die Datei erzeugt wird
 * @param  string prefix - Prefix des Namens der zu erzeugenden Datei (bis zu 3 Zeichen dieses Wertes werden verwendet)
 *
 * @return string - Dateiname oder Leerstring, falls ein Fehler auftrat
 */
string CreateTempFile(string path, string prefix="") {
   int len = StringLen(path);
   if (!len)                               return(_EMPTY(catch("CreateTempFile(1)  illegal parameter path: "+ DoubleQuoteStr(path), ERR_INVALID_PARAMETER)));
   if (len > MAX_PATH-14)                  return(_EMPTY(catch("CreateTempFile(2)  illegal parameter path: "+ DoubleQuoteStr(path) +" (max "+ (MAX_PATH-14) +" characters)", ERR_INVALID_PARAMETER)));
   if (path!=".") /*&&*/ if (path!="..")
      if (!IsDirectory(path, MODE_SYSTEM)) return(_EMPTY(catch("CreateTempFile(3)  directory not found: "+ DoubleQuoteStr(path), ERR_FILE_NOT_FOUND)));

   if (StrIsNull(prefix))
      prefix = "";

   int    bufferSize = MAX_PATH;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int unique = 0;                                                   // 0, wenn der Dateiname eindeutig sein soll
   int fileId = GetTempFileNameA(path, prefix, unique, buffer[0]);
   if (!fileId) return(_EMPTY_STR(catch("GetTempFileName(4)->kernel32::GetTempFileNameA() => 0", ERR_WIN32_ERROR)));

   string filename = buffer[0];
   ArrayResize(buffer, 0);
   return(filename);
}


/**
 * Whether a symbol exists in "symbols.raw" of a directory.
 *
 * @param  string symbol               - symbol
 * @param  string directory [optional] - directory
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 *
 * @return bool - success status or FALSE in case of errors
 */
bool IsRawSymbol(string symbol, string directory = "") {
   if (!StringLen(symbol))                    return(!catch("IsRawSymbol(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("IsRawSymbol(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("IsRawSymbol(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   if (directory == "0") directory = "";              // (string) NULL
   string filename = "";

   if (directory == "") {                             // current trade server, use MQL::FileOpenHistory()
      // check "symbols.raw"
      filename = "symbols.raw";                       // without the additional check FileOpenHistory(READ) logs a warning if the file doesn't exist
      if (!IsFile(GetAccountServerPath() +"/"+ filename, MODE_SYSTEM)) return(false);

      // open the file
      int hFile = FileOpenHistory(filename, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (error || hFile <= 0) return(!catch("IsRawSymbol(4)->FileOpenHistory(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }
   else if (!IsAbsolutePath(directory)) {             // relative sandbox path, use MQL::FileOpen()
      // check "symbols.raw"
      filename = directory +"/symbols.raw";           // without the additional check FileOpen(READ) logs a warning if the file doesn't exist
      if (!IsFile(filename, MODE_MQL)) return(false);

      // open the file
      hFile = FileOpen(filename, FILE_READ|FILE_BIN);
      error = GetLastError();
      if (error || hFile <= 0) return(!catch("IsRawSymbol(5)->FileOpen("+ DoubleQuoteStr(filename) +", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }
   else {                                             // absolute path, use Expander
      return(!catch("IsRawSymbol(6)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   // validate the file size
   int fileSize = FileSize(hFile);
   if (!fileSize)                   { FileClose(hFile); return(false); }
   if (fileSize % SYMBOL_size != 0) { FileClose(hFile); return(!catch("IsRawSymbol(7)  illegal size of "+ DoubleQuoteStr(filename) +" (not an even SYMBOL size, "+ (fileSize % SYMBOL_size) +" trailing bytes)", intOr(GetLastError(), ERR_RUNTIME_ERROR))); }

   // read all symbols
   int symbolsCount = fileSize/SYMBOL_size;
   /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);
   int dwords = FileReadArray(hFile, symbols, 0, fileSize/4);
   error = GetLastError();
   if (error || dwords!=fileSize/4) { FileClose(hFile); return(!catch("IsRawSymbol(8)  error reading "+ DoubleQuoteStr(filename) +" ("+ dwords*4 +" of "+ fileSize +" bytes read)", intOr(error, ERR_RUNTIME_ERROR))); }

   // check for the specified symbol
   bool found = false;
   for (int i=0; i < symbolsCount; i++) {
      if (StrCompareI(symbols_Name(symbols, i), symbol)) {
         found = true;
         break;
      }
   }
   FileClose(hFile);
   ArrayResize(symbols, 0);
   return(found);
}


/**
 * Create a raw symbol and add it to "symbols.raw" of the specified directory.
 *
 * @param  string symbol               - symbol
 * @param  string description          - symbol description
 * @param  string group                - group the symbol is listed in
 * @param  int    digits               - digits
 * @param  string baseCurrency         - base currency
 * @param  string marginCurrency       - margin currency
 * @param  string directory [optional] - directory name
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 *
 * @return int - id of the new symbol (field SYMBOL.id) or EMPTY (-1) in case of errors
 */
int CreateRawSymbol(string symbol, string description, string group, int digits, string baseCurrency, string marginCurrency, string directory = "") {
   if (!StringLen(symbol))                         return(_EMPTY(catch("CreateRawSymbol(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH)      return(_EMPTY(catch("CreateRawSymbol(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   if (StrContains(symbol, " "))                   return(_EMPTY(catch("CreateRawSymbol(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER)));
   if (StringLen(group) > MAX_SYMBOL_GROUP_LENGTH) return(_EMPTY(catch("CreateRawSymbol(4)  invalid parameter group: "+ DoubleQuoteStr(group) +" (max "+ MAX_SYMBOL_GROUP_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   if (directory == "0") directory = "";           // (string) NULL

   if (IsLogInfo()) logInfo("CreateRawSymbol(5)  creating \""+ directory + ifString(directory=="", "", "/") + symbol +"\" (group \""+ group +"\")");

   int   groupIndex;
   color groupColor = CLR_NONE;

   // read existing symbol groups
   /*SYMBOL_GROUP[]*/int sgs[];
   int size = GetSymbolGroups(sgs, directory); if (size < 0) return(-1);

   // look-up the specified group
   for (int i=0; i < size; i++) {
      if (sgs_Name(sgs, i) == group) break;
   }

   // if group not found create it
   if (i == size) {
      i = AddSymbolGroup(sgs, group, group, groupColor); if (i < 0) return(-1);
      if (!SaveSymbolGroups(sgs, directory))                        return(-1);
   }
   groupIndex = i;
   groupColor = sgs_BackgroundColor(sgs, i);

   // create symbol
   /*SYMBOL*/int iSymbol[]; InitializeByteBuffer(iSymbol, SYMBOL_size);
   if (!SetRawSymbolTemplate               (iSymbol, SYMBOL_TYPE_INDEX))              return(-1);
   if (!StringLen(symbol_SetName           (iSymbol, symbol          )))              return(_EMPTY(catch("CreateRawSymbol(6)->symbol_SetName() => NULL", ERR_RUNTIME_ERROR)));
   if (!StringLen(symbol_SetDescription    (iSymbol, description     )))              return(_EMPTY(catch("CreateRawSymbol(7)->symbol_SetDescription() => NULL", ERR_RUNTIME_ERROR)));
   if (          !symbol_SetDigits         (iSymbol, digits           ))              return(_EMPTY(catch("CreateRawSymbol(8)->symbol_SetDigits() => FALSE", ERR_RUNTIME_ERROR)));
   if (!StringLen(symbol_SetBaseCurrency   (iSymbol, baseCurrency    )))              return(_EMPTY(catch("CreateRawSymbol(9)->symbol_SetBaseCurrency() => NULL", ERR_RUNTIME_ERROR)));
   if (!StringLen(symbol_SetMarginCurrency (iSymbol, marginCurrency  )))              return(_EMPTY(catch("CreateRawSymbol(10)->symbol_SetMarginCurrency() => NULL", ERR_RUNTIME_ERROR)));
   if (           symbol_SetGroup          (iSymbol, groupIndex        ) < 0)         return(_EMPTY(catch("CreateRawSymbol(11)->symbol_SetGroup() => -1", ERR_RUNTIME_ERROR)));
   if (           symbol_SetBackgroundColor(iSymbol, groupColor        ) == CLR_NONE) return(_EMPTY(catch("CreateRawSymbol(12)->symbol_SetBackgroundColor() => CLR_NONE", ERR_RUNTIME_ERROR)));

   // insert it into "symbols.raw"
   if (!InsertRawSymbol(iSymbol, directory)) return(-1);
   return(symbol_Id(iSymbol));
}


/**
 * Fügt einer Liste von Symbolgruppen eine weitere hinzu. Die Gruppe wird an der ersten verfügbaren Position der Liste gespeichert.
 *
 * @param  SYMBOL_GROUP sgs[] - Liste von Symbolgruppen, der die neue Gruppe hinzugefügt werden soll
 * @param  string name        - Gruppenname
 * @param  string description - Gruppenbeschreibung
 * @param  color  bgColor     - Hintergrundfarbe der Symbolgruppe im "Market Watch"-Window
 *
 * @return int - Index der Gruppe innerhalb der Liste oder EMPTY (-1), falls ein Fehler auftrat (z.B. wenn die angegebene Gruppe bereits existiert)
 */
int AddSymbolGroup(/*SYMBOL_GROUP*/int sgs[], string name, string description, color bgColor) {
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP_size != 0)         return(_EMPTY(catch("AddSymbolGroup(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP_size) +" trailing bytes)", ERR_RUNTIME_ERROR)));
   if (!StringLen(name))                          return(_EMPTY(catch("AddSymbolGroup(2)  invalid parameter name: "+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER)));
   if (StringLen(name) > MAX_SYMBOL_GROUP_LENGTH) return(_EMPTY(catch("AddSymbolGroup(3)  invalid parameter name: "+ DoubleQuoteStr(name) +" (max "+ MAX_SYMBOL_GROUP_LENGTH +" characters)", ERR_INVALID_PARAMETER)));
   if (bgColor!=CLR_NONE && bgColor & 0xFF000000) return(_EMPTY(catch("AddSymbolGroup(4)  invalid parameter bgColor: 0x"+ IntToHexStr(bgColor) +" (not a color)", ERR_INVALID_PARAMETER)));

   // überprüfen, ob die angegebene Gruppe bereits existiert und dabei den ersten freien Index ermitteln
   int groupsSize = byteSize/SYMBOL_GROUP_size;
   int iFree = -1;
   for (int i=0; i < groupsSize; i++) {
      string foundName = sgs_Name(sgs, i);
      if (name == foundName)  return(_EMPTY(catch("AddSymbolGroup(5)  a group named "+ DoubleQuoteStr(name) +" already exists", ERR_RUNTIME_ERROR)));
      if (iFree==-1 && foundName=="")
         iFree = i;
   }

   // ohne freien Index das Array entsprechend vergrößern
   if (iFree == -1) {
      ArrayResize(sgs, (groupsSize+1)*SYMBOL_GROUP_intSize);
      iFree = groupsSize;
      groupsSize++;
   }

   // neue Gruppe erstellen und an freien Index kopieren
   /*SYMBOL_GROUP*/int sg[]; InitializeByteBuffer(sg, SYMBOL_GROUP_size);
   if (!StringLen(sg_SetName           (sg, name       )))            return(_EMPTY(catch("AddSymbolGroup(6)->sg_SetName() => NULL", ERR_RUNTIME_ERROR)));
   if (!StringLen(sg_SetDescription    (sg, description)))            return(_EMPTY(catch("AddSymbolGroup(7)->sg_SetDescription() => NULL", ERR_RUNTIME_ERROR)));
   if (           sg_SetBackgroundColor(sg, bgColor    ) == CLR_NONE) return(_EMPTY(catch("AddSymbolGroup(8)->sg_SetBackgroundColor() => CLR_NONE", ERR_RUNTIME_ERROR)));

   int src  = GetIntsAddress(sg);
   int dest = GetIntsAddress(sgs) + iFree*SYMBOL_GROUP_size;
   CopyMemory(dest, src, SYMBOL_GROUP_size);
   ArrayResize(sg, 0);

   return(iFree);
}


/**
 * Return the SYMBOL_GROUPs found in "symgroups.raw" of a directory.
 *
 * @param  _Out_ SYMBOL_GROUP &sgs[]               - array receiving the found symbol groups
 * @param  _In_  string       directory [optional] - directory name
 *                                                    if empty:            the current trade server directory (default)
 *                                                    if a relative path:  relative to the MQL sandbox/files directory
 *                                                    if an absolute path: as is
 *
 * @return int - number of found SYMBOL_GROUPs or EMPTY (-1) in case of errors
 */
int GetSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string directory = "") {
   ArrayResize(sgs, 0);
   if (directory == "0") directory = "";                    // (string) NULL

   if (directory == "") {                                   // current trade server, use MQL::FileOpenHistory()
      // stat "symgroups.raw"
      string filename = "symgroups.raw";                    // without the additional check FileOpenHistory(READ) logs a warning if the file doesn't exist
      if (!IsFile(GetAccountServerPath() +"/"+ filename, MODE_SYSTEM)) return(0);

      // open the file
      int hFile = FileOpen(filename, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0)  return(_EMPTY(catch("GetSymbolGroups(1)->FileOpenHistory(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR))));
   }
   else if (!IsAbsolutePath(directory)) {                   // relative sandbox path, use MQL::FileOpen()
      // stat "symgroups.raw"
      filename = directory +"/symgroups.raw";
      if (!IsFile(filename, MODE_MQL)) return(0);           // without the additional check FileOpen(READ) logs a warning if the file doesn't exist

      // open the file
      hFile = FileOpen(filename, FILE_READ|FILE_BIN);
      error = GetLastError();
      if (IsError(error) || hFile <= 0)  return(_EMPTY(catch("GetSymbolGroups(2)->FileOpen(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR))));
   }
   else {                                                   // absolute path, use Expander
      return(_EMPTY(catch("GetSymbolGroups(3)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED)));
   }

   // validate the file size
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL_GROUP_size != 0) {
      FileClose(hFile);               return(_EMPTY(catch("GetSymbolGroups(4)  invalid size of \""+ filename +"\" (not an even SYMBOL_GROUP size, "+ (fileSize % SYMBOL_GROUP_size) +" trailing bytes)", intOr(GetLastError(), ERR_RUNTIME_ERROR))));
   }
   if (!fileSize) { FileClose(hFile); return(0); }          // accept an empty file which may temporarily happen at creation time
                                                            // default: 32 * SYMBOL_GROUP_size = 32 * 80 = 2560 byte
   // read the file
   InitializeByteBuffer(sgs, fileSize);
   int ints = FileReadArray(hFile, sgs, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(_EMPTY(catch("GetSymbolGroups(5)  error reading \""+ filename +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", intOr(error, ERR_RUNTIME_ERROR))));

   return(fileSize/SYMBOL_GROUP_size);
}


/**
 * Add a symbol to "symbols.raw" of the specified directory and insert it at the correct position.
 *
 * @param  SYMBOL symbol               - symbol
 * @param  string directory [optional] - directory name
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 * @return bool - success status
 */
bool InsertRawSymbol(/*SYMBOL*/int symbol[], string directory = "") {
   if (ArraySize(symbol) != SYMBOL_intSize) return(!catch("InsertRawSymbol(1)  invalid size "+ ArraySize(symbol) +" of parameter symbol[] (not SYMBOL_intSize)", ERR_RUNTIME_ERROR));
   string symbolName = symbol_Name(symbol), filename="";
   if (!StringLen(symbolName))              return(!catch("InsertRawSymbol(2)  invalid parameter symbol[], SYMBOL.name: "+ DoubleQuoteStr(symbolName), ERR_RUNTIME_ERROR));
   if (directory == "0") directory = "";           // (string) NULL

   if (directory == "") {                          // current trade server, use MQL::FileOpenHistory()
      if (!UseTradeServerPath(GetAccountServerPath(), "InsertRawSymbol(3)")) return(false);

      // open "symbols.raw"
      filename = "symbols.raw";
      int hFile = FileOpenHistory(filename, FILE_READ|FILE_WRITE|FILE_BIN);
      int error = GetLastError();
      if (error || hFile <= 0) return(!catch("InsertRawSymbol(4)->FileOpenHistory(\""+ filename +"\", FILE_READ|FILE_WRITE) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }
   else if (!IsAbsolutePath(directory)) {          // relative sandbox path, use MQL::FileOpen()
      if (!UseTradeServerPath(directory, "InsertRawSymbol(5)")) return(false);

      // open "symbols.raw"
      filename = directory +"/symbols.raw";
      hFile = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_BIN);
      error = GetLastError();
      if (error || hFile <= 0) return(!catch("InsertRawSymbol(6)->FileOpen(\""+ filename +"\", FILE_READ|FILE_WRITE) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }
   else {                                          // absolute path, use Expander
      return(!catch("InsertRawSymbol(7)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   // check file size
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL_size != 0) {
      FileClose(hFile); return(!catch("InsertRawSymbol(8)  invalid size of \""+ filename +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL_size) +" trailing bytes)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
   }
   int symbolsSize = fileSize/SYMBOL_size, maxId=-1;
   /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);

   // read existing symbols
   if (fileSize > 0) {
      int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
      error = GetLastError();
      if (error || ints!=fileSize/4) { FileClose(hFile); return(!catch("InsertRawSymbol(9)  error reading \""+ filename +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", intOr(error, ERR_RUNTIME_ERROR))); }

      // make sure the new symbol doesn't already exist, and find largest symbol id
      for (int i=0; i < symbolsSize; i++) {
         if (StrCompareI(symbols_Name(symbols, i), symbolName)) { FileClose(hFile); return(!catch("InsertRawSymbol(10)   symbol \""+ symbols_Name(symbols, i) +"\" already exists", ERR_RUNTIME_ERROR)); }
         maxId = Max(maxId, symbols_Id(symbols, i));
      }
   }

   // set new symbol id and append the new symbol to the end
   if (symbol_SetId(symbol, maxId+1) == -1) { FileClose(hFile); return(!catch("InsertRawSymbol(11)->symbol_SetId() => -1", ERR_RUNTIME_ERROR)); }
   ArrayResize(symbols, (symbolsSize+1)*SYMBOL_intSize);
   i = symbolsSize;
   symbolsSize++;
   int src  = GetIntsAddress(symbol);
   int dest = GetIntsAddress(symbols) + i*SYMBOL_size;
   CopyMemory(dest, src, SYMBOL_size);

   // sort symbols and save them to disk                       // TODO: synchronize "symbols.sel" (or delete?)
   if (!SortSymbols(symbols, symbolsSize)) { FileClose(hFile); return(!catch("InsertRawSymbol(12)->SortSymbols() => FALSE", ERR_RUNTIME_ERROR)); }

   if (!FileSeek(hFile, 0, SEEK_SET)) { FileClose(hFile);      return(!catch("InsertRawSymbol(13)->FileSeek(hFile, 0, SEEK_SET) => FALSE", ERR_RUNTIME_ERROR)); }
   int elements = symbolsSize * SYMBOL_size / 4;
   ints  = FileWriteArray(hFile, symbols, 0, elements);
   error = GetLastError();
   FileClose(hFile);
   if (error || ints!=elements)                                return(!catch("InsertRawSymbol(14)  error writing SYMBOL[] to \""+ filename +"\" ("+ ints*4 +" of "+ symbolsSize*SYMBOL_size +" bytes written)", intOr(error, ERR_RUNTIME_ERROR)));

   return(!catch("InsertRawSymbol(15)"));
}


/**
 * Save the specified SYMBOL_GROUPs to a file "symgroups.raw" of a directory. Overwrites an existing file.
 *
 * @param  SYMBOL_GROUP sgs[]                - symbol groups
 * @param  string       directory [optional] - directory name
 *                                              if empty:            the current trade server directory (default)
 *                                              if a relative path:  relative to the MQL sandbox/files directory
 *                                              if an absolute path: as is
 * @return bool - success status
 */
bool SaveSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string directory = "") {
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP_size != 0) return(!catch("SaveSymbolGroups(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP_size) +" trailing bytes)", ERR_RUNTIME_ERROR));
   if (byteSize > 32*SYMBOL_GROUP_size)   return(!catch("SaveSymbolGroups(2)  invalid number of groups in sgs[] (max 32)", ERR_RUNTIME_ERROR));
   if (directory == "0") directory = "";           // (string) NULL

   // copy the passed array and extend it to a full "symgroups.raw" file size (32 groups)
   int sgs_copy[]; ArrayResize(sgs_copy, 0);
   if (ArraySize(sgs) < 32*SYMBOL_GROUP_intSize)
      InitializeByteBuffer(sgs_copy, 32*SYMBOL_GROUP_size);
   ArrayCopy(sgs_copy, sgs);

   if (directory == "") {                          // current trade server, use MQL::FileOpenHistory()
      if (!UseTradeServerPath(GetAccountServerPath(), "SaveSymbolGroups(3)")) return(false);

      // open "symgroups.raw"
      string filename = "symgroups.raw";
      int hFile = FileOpenHistory(filename, FILE_WRITE|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0) return(!catch("SaveSymbolGroups(4)->FileOpenHistory(\""+ filename +"\", FILE_WRITE) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }

   else if (!IsAbsolutePath(directory)) {          // relative sandbox path, use MQL::FileOpen()
      if (!UseTradeServerPath(directory, "SaveSymbolGroups(5)")) return(false);

      // open "symgroups.raw"
      filename = directory +"/symgroups.raw";
      hFile = FileOpen(filename, FILE_WRITE|FILE_BIN);
      error = GetLastError();
      if (IsError(error) || hFile <= 0) return(!catch("SaveSymbolGroups(6)->FileOpen(\""+ filename +"\", FILE_WRITE) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   }

   else {                                          // absolute path, use Expander
      return(!catch("SaveSymbolGroups(7)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   // write "symgroups.raw"
   int arraySize = ArraySize(sgs_copy);
   int ints = FileWriteArray(hFile, sgs_copy, 0, arraySize);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=arraySize) return(!catch("SaveSymbolGroups(8)  error writing SYMBOL_GROUPs to \""+ filename +"\" ("+ ints*4 +" of "+ arraySize*4 +" bytes written)", intOr(error, ERR_RUNTIME_ERROR)));

   ArrayResize(sgs_copy, 0);
   return(true);
}


/**
 * Kopiert das Template des angegebenen Symbol-Typs in das übergebene Symbol.
 *
 * @param  SYMBOL symbol - Symbol
 * @param  int    type   - Symbol-Typ
 *
 * @return bool - success status
 */
bool SetRawSymbolTemplate(/*SYMBOL*/int symbol[], int type) {
   // Parameter validieren und Template-Datei bestimmen
   string fileName = "";
   switch (type) {
      case SYMBOL_TYPE_FOREX  : fileName = "templates/SYMBOL_TYPE_FOREX.raw";   break;
      case SYMBOL_TYPE_CFD    : fileName = "templates/SYMBOL_TYPE_CFD.raw";     break;
      case SYMBOL_TYPE_INDEX  : fileName = "templates/SYMBOL_TYPE_INDEX.raw";   break;
      case SYMBOL_TYPE_FUTURES: fileName = "templates/SYMBOL_TYPE_FUTURES.raw"; break;

      default: return(!catch("SetRawSymbolTemplate(1)  invalid parameter type: "+ type +" (not a symbol type)", ERR_INVALID_PARAMETER));
   }

   // Template-File auf Existenz prüfen
   if (!IsFile(fileName, MODE_MQL))       // without the additional check FileOpen(READ) logs a warning if the file doesn't exist
      return(false);

   // Datei öffnen und Größe validieren
   int hFile = FileOpen(fileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)       return(!catch("SetRawSymbolTemplate(2)->FileOpen(\""+ fileName +"\", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));
   int fileSize = FileSize(hFile);
   if (fileSize != SYMBOL_size) {
      FileClose(hFile);                    return(!catch("SetRawSymbolTemplate(3)  invalid size "+ fileSize +" of \""+ fileName +"\" (not a SYMBOL size)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
   }

   // Datei in das übergebene Symbol einlesen
   InitializeByteBuffer(symbol, fileSize);
   int ints = FileReadArray(hFile, symbol, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(!catch("SetRawSymbolTemplate(3)  error reading \""+ fileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", intOr(error, ERR_RUNTIME_ERROR)));

   return(true);
}


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
   ArrayResize(__lockNames,    0);
   ArrayResize(__lockCounters, 0);

   ArrayResize(__registeredObjects, 0);
   __registeredOjectsCounter = 0;
}


#import "rsfMT4Expander.dll"
   int    GetIniKeysA(string fileName, string section, int buffer[], int bufferSize);
   int    GetIniSectionsA(string fileName, int buffer[], int bufferSize);
   bool   SortMqlStringsA(string values[], int size);
   bool   SortSymbols(int symbols[], int size);

   bool   Test_onPositionOpen(int ec[], int ticket, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_onPositionClose(int ec[], int ticket, datetime closeTime, double closePrice, double swap, double profit);

   int    symbol_Id  (int symbol[]);
   string symbol_Name(int symbol[]);

   int    symbols_Id  (int symbols[], int i);
   string symbols_Name(int symbols[], int i);

   int    symbol_SetId             (int symbol[], int    id         );
   string symbol_SetName           (int symbol[], string name       );
   string symbol_SetDescription    (int symbol[], string description);
   int    symbol_SetDigits         (int symbol[], int    digits     );
   string symbol_SetBaseCurrency   (int symbol[], string currency   );
   string symbol_SetMarginCurrency (int symbol[], string currency   );
   int    symbol_SetGroup          (int symbol[], int    index      );
   color  symbol_SetBackgroundColor(int symbol[], color  bgColor    );

   string sg_SetName           (int sg[], string name       );
   string sg_SetDescription    (int sg[], string description);
   color  sg_SetBackgroundColor(int sg[], color  bgColor    );

   string sgs_Name           (int sg[], int i);
   color  sgs_BackgroundColor(int sg[], int i);

   int    pi_hProcess(int pi[]);
   int    pi_hThread (int pi[]);

   int    si_setFlags     (int si[], int flags  );
   int    si_setShowWindow(int si[], int cmdShow);
   int    si_setSize      (int si[], int size   );

   int    tzi_Bias        (int tzi[]);
   int    tzi_DaylightBias(int tzi[]);

   bool   wfd_FileAttribute_Directory(int wfd[]);
   string wfd_FileName               (int wfd[]);
#import
