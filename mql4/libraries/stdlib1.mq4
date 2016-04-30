/**
 * Datentypen und Speichergrößen in C, Win32 (16-bit word size) und MQL:
 * =====================================================================
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
 * | 1 qword | 2 dword | 4 word | 8 byte | 64 bit |                 | 0xFFFFFFFF 0xFFFFFFFF |   -9.223.372.036.854.775.808 |                              0 |     double     |  LONGLONG,DWORDLONG |     double     | MQL-double: 53 bit Mantisse (Integers bis 53 Bit ohne Genauigkeitsverlust)
 * |         |         |        |        |        |                 |                       |    9.223.372.036.854.775.807 |     18.446.744.073.709.551.616 |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 */
#property library

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/EventListener.BarOpen.MTF.mqh>
#include <functions/ExplodeStrings.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <timezones.mqh>
#include <win32api.mqh>

#include <structs/myfx/ORDER_EXECUTION.mqh>

#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>
#include <iFunctions/iPreviousPeriodTimes.mqh>


/**
 * Initialisierung der Library. Informiert die Library über das Aufrufen der init()-Funktion des Hauptprogramms.
 *
 * @param  int ec[]       - EXECUTION_CONTEXT des Hauptmoduls
 * @param  int tickData[] - Array, das die Daten der letzten Ticks aufnimmt (Variablen im aufrufenden Indikator sind nicht statisch)
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int stdlib.init(/*EXECUTION_CONTEXT*/int ec[], int &tickData[]) {
   prev_error = last_error;
   last_error = NO_ERROR;

   // (1) Context in die Library kopieren
   ArrayCopy(__ExecutionContext, ec);


   // (2) globale Variablen (re-)initialisieren
   __lpSuperContext =                   ec_lpSuperContext(ec);
   __TYPE__        |=                   ec_ProgramType   (ec);
   __NAME__         = StringConcatenate(ec_ProgramName   (ec), "::", WindowExpertName());
   __WHEREAMI__     =                   ec_RootFunction  (ec);
   __CHART          =                  (ec_hChart        (ec)!=0);
   __LOG            =                   ec_Logging       (ec);
      int initFlags = ec_InitFlags(ec) | SumInts(__INIT_FLAGS__);
   __LOG_CUSTOM     = (initFlags & INIT_CUSTOMLOG && 1);

   PipDigits        = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints        = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip              = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat   = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat      = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) user-spezifische Init-Tasks ausführen
   if (initFlags & INIT_TIMEZONE && 1) {                             // Zeitzonen-Konfiguration überprüfen
      if (GetServerTimezone() == "")
         return(last_error);
   }

   if (initFlags & INIT_PIPVALUE && 1) {                             // im Moment unnötig, da in stdlib weder TickSize noch PipValue() verwendet werden
      /*
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                          // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // - synthetisches Symbol im Offline-Chart
            return(debug("stdlib.init()  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         return(catch("stdlib.init(1)", error));
      }
      if (!TickSize) return(debug("stdlib.init()  MarketInfo(MODE_TICKSIZE) = "+ NumberToStr(TickSize, ".+"), SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // siehe oben bei MODE_TICKSIZE
            return(debug("stdlib.init()  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         return(catch("stdlib.init(2)", error));
      }
      if (!tickValue) return(debug("stdlib.init()  MarketInfo(MODE_TICKVALUE) = "+ NumberToStr(tickValue, ".+"), SetLastError(ERS_TERMINAL_NOT_YET_READY)));
      */
   }


   // (4) nur für EA's durchzuführende globale Initialisierungen
   if (IsExpert()) {                                                 // nach Neuladen Orderkontext der Library wegen Bug ausdrücklich zurücksetzen (siehe MQL.doc)
      int reasons[] = { REASON_ACCOUNT, REASON_REMOVE, REASON_UNDEFINED, REASON_CHARTCLOSE };
      if (IntInArray(reasons, ec_UninitializeReason(ec)))
         OrderSelect(0, SELECT_BY_TICKET);


      if (IsTesting()) {                                             // nur im Tester
         if (!SetWindowTextA(GetTesterWindow(), "Tester"))           // Titelzeile des Testers zurücksetzen (ist u.U. noch vom letzten Test modifiziert)
            return(catch("stdlib.init(3)->user32::SetWindowTextA()", ERR_WIN32_ERROR));   // TODO: Warten, bis die Titelzeile gesetzt ist

         if (!GetAccountNumber())//throws ERS_TERMINAL_NOT_YET_READY // Accountnummer sofort ermitteln (wird intern gecacht), da ein Aufruf im Tester in deinit()
            return(last_error);                                      // u.U. den UI-Thread blockieren kann.
      }
   }


   // (5) gespeicherte Tickdaten zurückliefern (werden nur von Indikatoren ausgewertet)
   if (ArraySize(tickData) < 3)
      ArrayResize(tickData, 3);
   tickData[0] = Tick;
   tickData[1] = Tick.Time;
   tickData[2] = Tick.prevTime;

   if (!last_error)
      catch("stdlib.init(4)");
   return(last_error);
}


/**
 * Informiert die Library über das Aufrufen der start()-Funktion des laufenden Programms. Durch Übergabe des aktuellen Ticks kann die Library später erkennen,
 * ob verschiedene Funktionsaufrufe während desselben oder unterschiedlicher Ticks erfolgen.
 *
 * @param  int      ec[]        - EXECUTION_CONTEXT des Hauptmoduls
 * @param  int      tick        - Tickzähler, nicht identisch mit Volume[0] (synchronisiert den Wert des aufrufenden Moduls mit dem der Library)
 * @param  datetime tickTime    - Zeitpunkt des Ticks                       (synchronisiert den Wert des aufrufenden Moduls mit dem der Library)
 * @param  int      validBars   - Anzahl der seit dem letzten Tick unveränderten Bars oder -1, wenn die Funktion nicht aus einem Indikator aufgerufen wird
 * @param  int      changedBars - Anzahl der seit dem letzten Tick geänderten Bars oder -1, wenn die Funktion nicht aus einem Indikator aufgerufen wird
 *
 * @return int - Fehlerstatus
 */
int stdlib.start(/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars) {
   __WHEREAMI__ = ec_setRootFunction(__ExecutionContext, RF_START);


   if (Tick != tick) {
      // (1) erster Aufruf bei erstem Tick ...
      // vorher: Tick.prevTime = 0;                   danach: Tick.prevTime = 0;
      //         Tick.Time     = 0;                           Tick.Time     = tickTime[0];
      // ---------------------------------------------------------------------------------
      // (2) ... oder erster Aufruf bei weiterem Tick
      // vorher: Tick.prevTime = 0|tickTime[2];       danach: Tick.prevTime = tickTime[1];
      //         Tick.Time     =   tickTime[1];               Tick.Time     = tickTime[0];
      Tick.prevTime = Tick.Time;
      Tick.Time     = tickTime;
   }
   else {
      // (3) erneuter Aufruf während desselben Ticks (alles bleibt unverändert)
   }

   Tick        = tick;                                               // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   ValidBars   = validBars;
   ChangedBars = changedBars;

   return(NO_ERROR);
}


/**
 * Deinitialisierung der Library. Informiert die Library über das Aufrufen der deinit()-Funktion des Hauptprogramms.
 *
 * @param  int ec[] - EXECUTION_CONTEXT
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen
 *       verfrüht und nicht erst nach 2.5 Sekunden ab. In diesem Fall wird diese deinit()-Funktion u.U. nicht mehr ausgeführt.
 */
int stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]) {
   __WHEREAMI__ =                               RF_DEINIT;
   ec_setRootFunction      (__ExecutionContext, RF_DEINIT                );
   ec_setUninitializeReason(__ExecutionContext, ec_UninitializeReason(ec));


   // (1) ggf. noch gehaltene Locks freigeben
   int error = NO_ERROR;
   if (!ReleaseLocks(true))
      error = last_error;


   // (2) EXECUTION_CONTEXT von Indikatoren zwischenspeichern
   if (IsIndicator()) {
      ArrayCopy(__ExecutionContext, ec);
      if (IsError(catch("stdlib.deinit(1)")))
         error = last_error;
   }
   return(error);
}


/**
 * Ob in der Library Ticks gespeichert sind oder nicht.
 *
 * @return bool - TRUE, wenn in der Library noch keine Ticks gespeichert sind; FALSE andererseits
 *
 * NOTE: nur für Aufruf in Indicator::init() oder Indicator::InitReason()
 */
bool Init.IsNoTick() {
   return(!Tick);
}


string static.currentSymbol[1];


/**
 * Speichert das aktuelle Chartsymbol in der Library, um init()-Cycles eines Indikators überdauern und Symbolwechsel erkennen zu können.
 *
 * @param  string symbol - aktuelles Chartsymbol
 *
 * NOTE: nur für Aufruf in Indicator::init() oder Indicator::InitReason()
 */
void Init.StoreSymbol(string symbol) {
   static.currentSymbol[0] = symbol;
}


/**
 * Vergleicht das übergebene mit dem intern gespeicherten Symbol, um nach init()-Cycles eines Indikators einen Symbolwechsel erkennen zu können.
 *
 * @param  string symbol - Symbol
 *
 * @result bool - TRUE, wenn das in der Library gespeicherte Symbol nicht mit dem übergebenen Symbol übereinstimmt;
 *                FALSE, wenn die Symbole übereinstimmen oder in der Library noch kein Symbol gespeichert ist
 *
 * NOTE: nur für Aufruf in Indicator::init() oder Indicator::InitReason()
 */
bool Init.IsNewSymbol(string symbol) {
   if (StringLen(static.currentSymbol[0]) > 0)
      return(static.currentSymbol[0] != symbol);
   return(false);
}


// alt: Globale Init/Deinit-Stubs, können bei Bedarf durch lokale Versionen überschrieben werden.
int    onInitParameterChange()   {                                                                                                            return(NO_ERROR);  }
int    onInitChartChange()       {                                                                                                            return(NO_ERROR);  }
int    onInitAccountChange()     {                                   return(catch("onInitAccountChange()  unexpected UninitializeReason",   ERR_RUNTIME_ERROR)); }
int    onInitChartClose()        {                                                                                                            return(NO_ERROR);  }
int    onInitUndefined()         {                                                                                                            return(NO_ERROR);  }
int    onInitRemove()            {                                                                                                            return(NO_ERROR);  }
int    onInitRecompile()         {                                                                                                            return(NO_ERROR);  }
int    onInitTemplate()          { /*build > 509*/                   return(catch("onInitTemplate()  unexpected UninitializeReason",        ERR_RUNTIME_ERROR)); }
int    onInitFailed()            { /*build > 509*/                   return(catch("onInitFailed()  unexpected UninitializeReason",          ERR_RUNTIME_ERROR)); }
int    onInitClose()             { /*build > 509*/                   return(catch("onInitClose()  unexpected UninitializeReason",           ERR_RUNTIME_ERROR)); }

int    onDeinitParameterChange() {                                                                                                            return(NO_ERROR);  }
int    onDeinitChartChange()     {                                                                                                            return(NO_ERROR);  }
int    onDeinitAccountChange()   { if (IsExpert())                   return(catch("onDeinitAccountChange()  unexpected UninitializeReason", ERR_RUNTIME_ERROR));
                                   /*if (IsIndicator()) _warn("onDeinitAccountChange()  unexpected UninitializeReason");*/                    return(NO_ERROR);  }
int    onDeinitChartClose()      { /*if (IsIndicator()) _warn("onDeinitChartClose()  unexpected UninitializeReason");*/                       return(NO_ERROR);  }
int    onDeinitUndefined()       { if (IsExpert()) if (!IsTesting()) return(catch("onDeinitUndefined()  unexpected UninitializeReason",     ERR_RUNTIME_ERROR));
                                   /*if (IsIndicator()) _warn("onDeinitUndefined()  unexpected UninitializeReason");*/                        return(NO_ERROR);  }
int    onDeinitRemove()          {                                                                                                            return(NO_ERROR);  }
int    onDeinitRecompile()       {                                                                                                            return(NO_ERROR);  }
int    onDeinitTemplate()        { /*build > 509*/                     /*_warn("onDeinitTemplate()  unexpected UninitializeReason");*/        return(NO_ERROR);  }
int    onDeinitFailed()          { /*build > 509*/                     /*_warn("onDeinitFailed()  unexpected UninitializeReason");  */        return(NO_ERROR);  }
int    onDeinitClose()           { /*build > 509*/                     /*_warn("onDeinitClose()  unexpected UninitializeReason");   */        return(NO_ERROR);  }

string InputsToStr()             {                                                  return("InputsToStr()  function not implemented"); }
int    ShowStatus(int error)     { Comment("\n\n\n\nShowStatus() not implemented"); return(error); }


/**
 * Nur zu Testzwecken bei Unterscheidung von 509/600-Builds.
 *
 * @param  string message - anzuzeigende Nachricht
 * @param  int    error   - anzuzeigender Fehlercode
 *
 * @return int - derselbe Fehlercode
 */
int _warn(string message, int error=NO_ERROR) {
   PlaySoundEx("alert.wav");
   log(message, error);
   return(error);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den Fehlercode nicht zurück.
 *
 * @return int - Fehlerstatus
 */
int stdlib.GetLastError() {
   return(last_error);
}


/**
 * Öffnet eine einzelne Datei im Texteditor.
 *
 * @param  string filename - Dateiname
 *
 * @return bool - Erfolgsstatus
 */
bool EditFile(string filename) {
   if (!StringLen(filename)) return(!catch("EditFile(1)  invalid parameter filename = "+ DoubleQuoteStr(filename), ERR_INVALID_PARAMETER));

   string file[1]; file[0] = filename;
   return(EditFiles(file));
}


/**
 * Öffnet eine oder mehrere Dateien im Texteditor.
 *
 * @param  string filenames[] - Dateinamen
 *
 * @return bool - Erfolgsstatus
 */
bool EditFiles(string filenames[]) {
   int size = ArraySize(filenames);
   if (!size)                       return(!catch("EditFiles(1)  invalid parameter filenames = {}", ERR_INVALID_PARAMETER));

   for (int i=0; i < size; i++) {
      if (!StringLen(filenames[i])) return(!catch("EditFiles(2)  invalid file name at filenames["+ i +"] = "+ DoubleQuoteStr(filenames[i]), ERR_INVALID_PARAMETER));
   }


   // prüfen, ob ein Editor konfiguriert ist
   string section = "System";
   string key     = "Editor";
   string editor  = GetGlobalConfigString(section, key);


   if (StringLen(editor) > 0) {
      // ja: konfigurierten Editor benutzen
      string cmd = editor +" \""+ JoinStrings(filenames, "\" \"") +"\"";
      int result = WinExec(cmd, SW_SHOWNORMAL);
      if (result < 32)
         return(!catch("EditFiles(3)->kernel32::WinExec(cmd=\""+ editor +"\")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));
   }
   else {
      // nein: ShellExecute() mit Default-Open-Methode benutzen
      string sNull;
      for (i=0; i < size; i++) {
         result = ShellExecuteA(NULL, "open", filenames[i], sNull, sNull, SW_SHOWNORMAL);
         if (result <= 32)
            return(!catch("EditFiles(4)->shell32::ShellExecuteA(file=\""+ filenames[i] +"\")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));
      }
   }
   return(!catch("EditFiles(5)"));
}


/**
 * Gibt die Commission-Rate des Accounts in der Accountwährung zurück.
 *
 * @return double - Commission-Rate oder -1 (EMPTY), falls ein Fehler auftrat
 */
double GetCommission() {
   string company  = ShortAccountCompany();
   int    account  = GetAccountNumber();
   string currency = AccountCurrency();

   double commission = GetGlobalConfigDouble("Commissions", company +"."+ currency +"."+ account, GetGlobalConfigDouble("Commissions", company +"."+ currency));
   if (commission < 0)
      return(_EMPTY(catch("GetCommission()  invalid configuration value [Commissions] "+ company +"."+ currency +"."+ account +" = "+ NumberToStr(commission, ".+"), ERR_INVALID_CONFIG_PARAMVALUE)));

   return(commission);
}


/**
 * Ermittelt Zeitpunkt und Offset des vorherigen und nächsten DST-Wechsels der angebenen Serverzeit.
 *
 * @param  datetime serverTime           - Serverzeit
 * @param  datetime previousTransition[] - Array zur Aufnahme der letzten vorherigen Transitionsdaten
 * @param  datetime nextTransition    [] - Array zur Aufnahme der nächsten Transitionsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Datenformat:
 * ------------
 *  transition[I_TRANSITION_TIME  ] - GMT-Zeitpunkt des Wechsels oder -1, wenn der Wechsel unbekannt ist
 *  transition[I_TRANSITION_OFFSET] - GMT-Offset nach dem Wechsel
 *  transition[I_TRANSITION_DST   ] - ob nach dem Wechsel DST gilt oder nicht
 */
bool GetTimezoneTransitions(datetime serverTime, int &previousTransition[], int &nextTransition[]) {
   if (serverTime < 0)              return(!catch("GetTimezoneTransitions(1)  invalid parameter serverTime = "+ serverTime +" (not a time)", ERR_INVALID_PARAMETER));
   if (serverTime >= D'2038.01.01') return(!catch("GetTimezoneTransitions(2)  too large parameter serverTime = '"+ DateTimeToStr(serverTime, "w, D.M.Y H:I") +"' (unsupported)", ERR_INVALID_PARAMETER));
   string timezone = GetServerTimezone();
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
   int i, iMax=2037-1970, y=TimeYearFix(serverTime);


   // letzter Wechsel
   if (ArraySize(previousTransition) < 3)
      ArrayResize(previousTransition, 3);
   ArrayInitialize(previousTransition, 0);
   i = y-1970;

   while (true) {
      if (i < 0)             { previousTransition[I_TRANSITION_TIME] = -1; break; }
      if (timezone == "GMT") { previousTransition[I_TRANSITION_TIME] = -1; break; }

      if (timezone == "America/New_York") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
      }

      else if (timezone == "Europe/Berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
      }

      else if (timezone == "Europe/Kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
      }

      else if (timezone == "Europe/London") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
      }

      else if (timezone == "Europe/Minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
      }

      else if (timezone == "FXT") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { previousTransition[I_TRANSITION_TIME] = toSTD; previousTransition[I_TRANSITION_OFFSET] = transitions.FXT             [i][STD_OFFSET]; previousTransition[I_TRANSITION_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { previousTransition[I_TRANSITION_TIME] = toDST; previousTransition[I_TRANSITION_OFFSET] = transitions.FXT             [i][DST_OFFSET]; previousTransition[I_TRANSITION_DST] = true;  break; }
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
      if (i > iMax)          { nextTransition[I_TRANSITION_TIME] = -1; break; }
      if (timezone == "GMT") { nextTransition[I_TRANSITION_TIME] = -1; break; }

      if (timezone == "America/New_York") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else if (timezone == "Europe/Berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else if (timezone == "Europe/Kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else if (timezone == "Europe/London") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else if (timezone == "Europe/Minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else if (timezone == "FXT") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[I_TRANSITION_TIME] = toDST; nextTransition[I_TRANSITION_OFFSET] = transitions.FXT             [i][DST_OFFSET]; nextTransition[I_TRANSITION_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[I_TRANSITION_TIME] = toSTD; nextTransition[I_TRANSITION_OFFSET] = transitions.FXT             [i][STD_OFFSET]; nextTransition[I_TRANSITION_DST] = false; break; }
      }

      else return(!catch("GetTimezoneTransitions(4)  unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG));

      i++;                                                           // nächster Wechsel ist später
   }
   return(true);
}


int    costum.log.id   = 0;         // static: EA ok, Indikator ?
string costum.log.file = "";        // static: EA ok, Indikator ?


/**
 * Setzt das zu verwendende Custom-Log.
 *
 * @param  int    id   - Log-ID (ähnlich einer Instanz-ID)
 * @param  string file - Name des Logfiles relativ zu ".\files\"
 *
 * @return int - dieselbe ID (for chaining)
 */
int SetCustomLog(int id, string file) {
   if (file == "0")        // (string) NULL
      file = "";
   costum.log.id   = id;
   costum.log.file = file;
   return(id);
}


/**
 * Gibt die ID des Custom-Logs zurück.
 *
 * @return int - ID
 */
int GetCustomLogID() {
   return(costum.log.id);
}


string lock.names   [];                                              // Namen der Locks, die vom aktuellen Programm gehalten werden
int    lock.counters[];                                              // Anzahl der akquirierten Locks je Name


/**
 * Versucht, das Terminal-weite Lock mit dem angegebenen Namen zu erwerben.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 * @param  bool   wait      - ob auf das Lock gewartet (TRUE) oder sofort zurückgekehrt (FALSE) werden soll
 *
 * @return bool - Erfolgsstatus
 */
bool AquireLock(string mutexName, bool wait) {
   wait = wait!=0;

   if (!StringLen(mutexName)) return(!catch("AquireLock(1)  illegal parameter mutexName = "+ DoubleQuoteStr(mutexName), ERR_INVALID_PARAMETER));

   // (1) check if we already own that lock
   int i = SearchStringArray(lock.names, mutexName);
   if (i > -1) {
      // yes
      lock.counters[i]++;
      return(true);
   }

   datetime now, startTime=GetTickCount();
   int      error, duration, seconds=1;
   string   globalVarName = mutexName;

   if (This.IsTesting())
      globalVarName = StringConcatenate("tester.", mutexName);

   // (2) no, run until lock is aquired
   while (true) {
      if (GlobalVariableSetOnCondition(globalVarName, 1, 0)) {       // try to get it
         ArrayPushString(lock.names, mutexName);                     // got it
         ArrayPushInt   (lock.counters,      1);
         return(true);
      }
      error = GetLastError();

      if (error == ERR_GLOBAL_VARIABLE_NOT_FOUND) {                  // create mutex if it doesn't yet exist
         if (!GlobalVariableSet(globalVarName, 0)) {
            error = GetLastError();
            return(!catch("AquireLock(2)  failed to create mutex "+ DoubleQuoteStr(mutexName), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
         continue;                                                   // retry
      }
      if (IsError(error)) return(!catch("AquireLock(3)  failed to get lock for mutex "+ DoubleQuoteStr(mutexName), error));
      if (IsStopped())    return(_false(warn("AquireLock(4)  couldn't get lock for mutex "+ DoubleQuoteStr(mutexName) +", stopping...")));
      if (!wait)
         return(false);

      // (2.1) warn every single second, cancel after 10 seconds
      duration = GetTickCount() - startTime;
      if (duration >= seconds*1000) {
         if (seconds >= 10)
            return(!catch("AquireLock(5)  failed to get lock for mutex "+ DoubleQuoteStr(mutexName) +" after "+ DoubleToStr(duration/1000., 3) +" sec., giving up", ERR_RUNTIME_ERROR));
         warn("AquireLock(6)  couldn't get lock for mutex "+ DoubleQuoteStr(mutexName) +" after "+ DoubleToStr(duration/1000., 3) +" sec., retrying...");
         seconds++;
      }

      // Sleep and retry...
      if (IsIndicator() || IsTesting()) SleepEx(100, true);          // Indicator oder Expert im Tester
      else                              Sleep  (100);
   }

   return(!catch("AquireLock(7)", ERR_WRONG_JUMP));                  // unreachable
}



/**
 * Gibt das Terminal-Lock mit dem angegebenen Namen wieder frei.
 *
 * @param  string mutexName - Namensbezeichner des Mutexes
 *
 * @return bool - Erfolgsstatus
 */
bool ReleaseLock(string mutexName) {
   if (!StringLen(mutexName)) return(!catch("ReleaseLock(1)  illegal parameter mutexName = \"\"", ERR_INVALID_PARAMETER));

   // check, if we indeed own that lock
   int i = SearchStringArray(lock.names, mutexName);
   if (i == -1)
      return(!catch("ReleaseLock(2)  do not own a lock for mutex \""+ mutexName +"\"", ERR_RUNTIME_ERROR));

   // we do, decrease the counter
   lock.counters[i]--;

   // remove it, if counter is zero
   if (lock.counters[i] == 0) {
      ArraySpliceStrings(lock.names,    i, 1);
      ArraySpliceInts   (lock.counters, i, 1);

      string globalVarName = mutexName;

      if (This.IsTesting())
         globalVarName = StringConcatenate("tester.", mutexName);

      if (!GlobalVariableSet(globalVarName, 0)) {
         int error = GetLastError();
         return(!catch("ReleaseLock(3)  failed to reset mutex \""+ mutexName +"\"", ifInt(!error, ERR_RUNTIME_ERROR, error)));
      }
   }
   return(true);
}


/**
 * Gibt alle noch gehaltenen Terminal-Locks frei (wird bei Programmende automatisch aufgerufen).
 *
 * @param  bool warn - ob für noch gehaltene Locks eine Warnung ausgegeben werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool ReleaseLocks(bool warn=false) {
   warn = warn!=0;

   int error, size=ArraySize(lock.names);

   if (size > 0) {
      for (int i=size-1; i>=0; i--) {
         if (warn)
            warn(StringConcatenate("ReleaseLocks()  unreleased lock found for mutex \"", lock.names[i], "\""));

         if (!ReleaseLock(lock.names[i]))
            error = last_error;
      }
   }
   return(!error);
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
   if (gmtTime < 0) return(_EMPTY_VALUE(catch("GetGmtToFxtTimeOffset(1)  invalid parameter gmtTime = "+ gmtTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearFix(gmtTime)-1970;

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
   string serverTimezone = GetServerTimezone();
   if (!StringLen(serverTimezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu FXT festen Zeitzone läuft
   if (serverTimezone == "FXT"             ) return(       0);
   if (serverTimezone == "FXT-0200"        ) return(-2*HOURS);
   if (serverTimezone == "America/New_York") return(-7*HOURS);


   if (serverTime < 0) return(_EMPTY_VALUE(catch("GetServerToFxtTimeOffset(1)  invalid parameter serverTime = "+ serverTime, ERR_INVALID_PARAMETER)));


   // Offset Server zu GMT
   int offset1 = 0;
   if (serverTimezone != "GMT") {
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
   string serverTimezone = GetServerTimezone();
   if (!StringLen(serverTimezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu GMT festen Zeitzone läuft
   if (serverTimezone == "GMT") return(0);


   if (serverTime < 0) return(_EMPTY_VALUE(catch("GetServerToGmtTimeOffset(1)  invalid parameter serverTime = "+ serverTime, ERR_INVALID_PARAMETER)));


   if (serverTimezone == "Alpari") {
      if (serverTime < D'2012.04.01 00:00:00') serverTimezone = "Europe/Berlin";
      else                                     serverTimezone = "Europe/Kiev";
   }
   else if (serverTimezone == "GlobalPrime") {
      if (serverTime < D'2015.10.25 00:00:00') serverTimezone = "FXT";
      else                                     serverTimezone = "Europe/Kiev";
   }

   int offset, year=TimeYearFix(serverTime)-1970;

   if (serverTimezone == "America/New_York") {
      if      (serverTime < transitions.America_New_York[year][TR_TO_DST.local]) offset = transitions.America_New_York[year][STD_OFFSET];
      else if (serverTime < transitions.America_New_York[year][TR_TO_STD.local]) offset = transitions.America_New_York[year][DST_OFFSET];
      else                                                                       offset = transitions.America_New_York[year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Berlin") {
      if      (serverTime < transitions.Europe_Berlin   [year][TR_TO_DST.local]) offset = transitions.Europe_Berlin   [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Berlin   [year][TR_TO_STD.local]) offset = transitions.Europe_Berlin   [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Berlin   [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Kiev") {
      if      (serverTime < transitions.Europe_Kiev     [year][TR_TO_DST.local]) offset = transitions.Europe_Kiev     [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Kiev     [year][TR_TO_STD.local]) offset = transitions.Europe_Kiev     [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Kiev     [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/London") {
      if      (serverTime < transitions.Europe_London   [year][TR_TO_DST.local]) offset = transitions.Europe_London   [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_London   [year][TR_TO_STD.local]) offset = transitions.Europe_London   [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_London   [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Minsk") {
      if      (serverTime < transitions.Europe_Minsk    [year][TR_TO_DST.local]) offset = transitions.Europe_Minsk    [year][STD_OFFSET];
      else if (serverTime < transitions.Europe_Minsk    [year][TR_TO_STD.local]) offset = transitions.Europe_Minsk    [year][DST_OFFSET];
      else                                                                       offset = transitions.Europe_Minsk    [year][STD_OFFSET];
   }
   else if (serverTimezone == "FXT") {
      if      (serverTime < transitions.FXT             [year][TR_TO_DST.local]) offset = transitions.FXT             [year][STD_OFFSET];
      else if (serverTime < transitions.FXT             [year][TR_TO_STD.local]) offset = transitions.FXT             [year][DST_OFFSET];
      else                                                                       offset = transitions.FXT             [year][STD_OFFSET];
   }
   else if (serverTimezone == "FXT-0200") {
      datetime fxtTime = serverTime + PLUS_2_H;
      if      (fxtTime < transitions.FXT                [year][TR_TO_DST.local]) offset = transitions.FXT             [year][STD_OFFSET] + MINUS_2_H;
      else if (fxtTime < transitions.FXT                [year][TR_TO_STD.local]) offset = transitions.FXT             [year][DST_OFFSET] + MINUS_2_H;
      else                                                                       offset = transitions.FXT             [year][STD_OFFSET] + MINUS_2_H;
   }
   else return(_EMPTY_VALUE(catch("GetServerToGmtTimeOffset(2)  unknown server timezone \""+ serverTimezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

   return(offset);
}


/**
 * Gibt die Namen aller Abschnitte einer .ini-Datei zurück.
 *
 * @param  string fileName - Name der .ini-Datei (wenn NULL, wird WIN.INI durchsucht)
 * @param  string names[]  - Array zur Aufnahme der gefundenen Abschnittsnamen
 *
 * @return int - Anzahl der gefundenen Abschnitte oder -1 (EMPTY), falls ein Fehler auftrat
 */
int GetIniSections(string fileName, string names[]) {
   int bufferSize = 200;
   int buffer[]; InitializeByteBuffer(buffer, bufferSize);

   int chars = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeByteBuffer(buffer, bufferSize);
      chars = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);
   }

   int length;
   if (!chars) length = ArrayResize(names, 0);                       // keine Sections gefunden (Datei nicht gefunden oder leer)
   else        length = ExplodeStrings(buffer, names);

   if (!catch("GetIniSections(1)"))
      return(length);
   return(EMPTY);
}


/**
 * Ob ein Abschnitt in einer .ini-Datei existiert. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string fileName - Name der .ini-Datei
 * @param  string section  - Name des Abschnitts
 *
 * @return bool
 */
bool IsIniSection(string fileName, string section) {
   bool result = false;

   string names[];
   if (GetIniSections(fileName, names) > 0) {
      result = StringInArrayI(names, section);
      ArrayResize(names, 0);
   }
   return(result);
}


/**
 * Ob ein Schlüssel in einer .ini-Datei existiert. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string fileName - Name der .ini-Datei
 * @param  string section  - Abschnitt des Eintrags
 * @param  string key      - Name des Schlüssels
 *
 * @return bool
 */
bool IsIniKey(string fileName, string section, string key) {
   string marker = "~^#";                                            // rarely found value
   string value  = GetRawIniString(fileName, section, key, marker);  // GetPrivateProfileInt() kann hier nicht verwendet werden, da die Funktion den Default-Value
                                                                     // auch bei existierendem Schlüssel und einem fehlendem Konfigurationswert (Leerstring) übernimmt.
   if (value != marker)
      return(true);

   bool result = false;

   string keys[];
   if (GetIniKeys(fileName, section, keys) > 0) {
      result = StringInArrayI(keys, key);
      ArrayResize(keys, 0);
   }
   return(result);
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

   string fileName[]; InitializeStringBuffer(fileName, MAX_PATH);
   if (!GetModuleFileNameA(NULL, fileName[0], MAX_PATH))                      return(_EMPTY_STR(catch("GetTerminalVersion(1)->kernel32::GetModuleFileNameA()", ERR_WIN32_ERROR)));

   int iNull[];
   int infoSize = GetFileVersionInfoSizeA(fileName[0], iNull); if (!infoSize) return(_EMPTY_STR(catch("GetTerminalVersion(2)->version::GetFileVersionInfoSizeA()", ERR_WIN32_ERROR)));

   int infoBuffer[]; InitializeByteBuffer(infoBuffer, infoSize);
   if (!GetFileVersionInfoA(fileName[0], NULL, infoSize, infoBuffer))         return(_EMPTY_STR(catch("GetTerminalVersion(3)->version::GetFileVersionInfoA()", ERR_WIN32_ERROR)));

   string infoString = BufferToStr(infoBuffer);                      // Strings im Buffer sind Unicode-Strings
   //     infoString = Ð•4………V…S…_…V…E…R…S…I…O…N…_…I…N…F…O……………½•ïþ……•………•…á……………•…á………?…………………•………•………………………………………0•……•…S…t…r…i…n…g…F…i…l…e…I…n…f…o………••……•…0…0…0…0…0…4…b…0………L…•…•…C…o…m…m…e…n…t…s………h…t…t…p…:…/…/…w…w…w….…m…e…t…a…q…u…o…t…e…s….…n…e…t………T…•…•…C…o…m…p…a…n…y…N…a…m…e……………M…e…t…a…Q…u…o…t…e…s… …S…o…f…t…w…a…r…e… …C…o…r…p….………>…•…•…F…i…l…e…D…e…s…c…r…i…p…t…i…o…n……………M…e…t…a…T…r…a…d…e…r……………6…•…•…F…i…l…e…V…e…r…s…i…o…n……………4….…0….…0….…2…2…5…………………6…•…•…I…n…t…e…r…n…a…l…N…a…m…e………M…e…t…a…T…r…a…d…e…r……………†…1…•…L…e…g…a…l…C…o…p…y…r…i…g…h…t………C…o…p…y…r…i…g…h…t… …©… …2…0…0…1…-…2…0…0…9…,… …M…e…t…a…Q…u…o…t…e…s… …S…o…f…t…w…a…r…e… …C…o…r…p….……………@…•…•…L…e…g…a…l…T…r…a…d…e…m…a…r…k…s……………M…e…t…a…T…r…a…d…e…r…®………(………•…O…r…i…g…i…n…a…l…F…i…l…e…n…a…m…e……… ………•…P…r…i…v…a…t…e…B…u…i…l…d………6…•…•…P…r…o…d…u…c…t…N…a…m…e……………M…e…t…a…T…r…a…d…e…r……………:…•…•…P…r…o…d…u…c…t…V…e…r…s…i…o…n………4….…0….…0….…2…2…5………………… ………•…S…p…e…c…i…a…l…B…u…i…l…d………D………•…V…a…r…F…i…l…e…I…n…f…o……………$…•………T…r…a…n…s…l…a…t…i…o…n…………………°•FE2X…………………………………………
   string Z                  = CharToStr(PLACEHOLDER_NUL_CHAR);
   string C                  = CharToStr(PLACEHOLDER_CTRL_CHAR);
   string key.ProductVersion = StringConcatenate(C,Z,"P",Z,"r",Z,"o",Z,"d",Z,"u",Z,"c",Z,"t",Z,"V",Z,"e",Z,"r",Z,"s",Z,"i",Z,"o",Z,"n",Z,Z);
   string key.FileVersion    = StringConcatenate(C,Z,"F",Z,"i",Z,"l",Z,"e",Z,"V",Z,"e",Z,"r",Z,"s",Z,"i",Z,"o",Z,"n",Z,Z);

   int pos = StringFind(infoString, key.ProductVersion);             // zuerst nach ProductVersion suchen...
   if (pos > -1) {
      pos += StringLen(key.ProductVersion);
   }
   else {                                                            // ...dann nach FileVersion suchen
      pos  = StringFind(infoString, key.FileVersion); if (pos == -1)          return(_EMPTY_STR(catch("GetTerminalVersion(6)  terminal version info not found", ERR_RUNTIME_ERROR)));
      pos += StringLen(key.FileVersion);
   }

   // erstes Nicht-NULL-Byte nach dem Version-Key finden
   for (; pos < infoSize; pos++) {
      if (BufferGetChar(infoBuffer, pos) != 0x00)
         break;
   }
   if (pos == infoSize)                                              // no non-NULL byte found after version key
      return(_EMPTY_STR(catch("GetTerminalVersion(7)  terminal version info value not found", ERR_RUNTIME_ERROR)));

   // Unicode-String auslesen und konvertieren
   string version = BufferWCharsToStr(infoBuffer, pos/4, (infoSize-pos)/4);

   if (IsError(catch("GetTerminalVersion(8)")))
      return("");

   static.result[0] = version;
   return(static.result[0]);
}


/**
 * Gibt die Build-Version des Terminals zurück.
 *
 * @return int - Build-Version oder 0, falls ein Fehler auftrat
 */
int GetTerminalBuild() {
   static int static.result;                                         // ohne Initializer (@see MQL.doc)
   if (static.result != 0)
      return(static.result);

   string version = GetTerminalVersion();
   if (!StringLen(version))
      return(0);

   string strings[];

   int size = Explode(version, ".", strings);
   if (size != 4)
      return(_NULL(catch("GetTerminalBuild(1)  unexpected terminal version format = \""+ version +"\"", ERR_RUNTIME_ERROR)));

   if (!StringIsDigit(strings[size-1]))
      return(_NULL(catch("GetTerminalBuild(2)  unexpected terminal version format = \""+ version +"\"", ERR_RUNTIME_ERROR)));

   int build = StrToInteger(strings[size-1]);

   if (IsError(catch("GetTerminalBuild(3)")))
      build = 0;

   static.result = build;
   return(static.result);
}


/**
 * @author  Cristi Dumitrescu <birt@eareview.net>
 */
int MT4build() {
   string fileName[]; InitializeStringBuffer(fileName, MAX_PATH);
   GetModuleFileNameA(GetModuleHandleA(NULL), fileName[0], MAX_PATH);

   int iNull[];
   int vSize = GetFileVersionInfoSizeA(fileName[0], iNull);

   int vInfo[]; ArrayResize(vInfo, vSize/4);
   GetFileVersionInfoA(fileName[0], NULL, vSize, vInfo);

   string vChar[4], vString="";

   for (int i=0; i < vSize/4; i++) {
      vChar[0] = CharToStr(vInfo[i]       & 0x000000FF);
      vChar[1] = CharToStr(vInfo[i] >>  8 & 0x000000FF);
      vChar[2] = CharToStr(vInfo[i] >> 16 & 0x000000FF);
      if (vChar[0]=="" && vChar[3]=="") vString = vString +" ";
      else                              vString = vString + vChar[0];

      vChar[3] = CharToStr(vInfo[i] >> 24 & 0x000000FF);
      if (vChar[1]=="" && vChar[0]=="") vString = vString +" ";
      else                              vString = vString + vChar[1];

      if (vChar[2]=="" && vChar[1]=="") vString = vString +" ";
      else                              vString = vString + vChar[2];

      if (vChar[3]=="" && vChar[2]=="") vString = vString +" ";
      else                              vString = vString + vChar[3];
   }
   vString = StringTrim(StringSubstr(vString, StringFind(vString, "FileVersion") + 11, 15));

   for (i=0; i < 3; i++) {
      vString = StringSubstr(vString, StringFind(vString, ".") + 1);
   }
   int build = StrToInteger(vString);
   return(build);
}


/**
 * Gibt den Namen des aktuellen History-Verzeichnisses zurück.  Der Name ist bei bestehender Verbindung identisch mit dem Rückgabewert von AccountServer(),
 * läßt sich mit dieser Funktion aber auch ohne Verbindung und bei Accountwechsel ermitteln.
 *
 * @return string - Verzeichnisname oder Leerstring, falls ein Fehler auftrat
 */
string GetServerName() {
   // Der Verzeichnisname wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen
   // die MQL-Accountfunktionen evt. schon auf den neuen Account, das Programm verarbeitet aber noch einen Tick des alten Charts im alten Serververzeichnis.
   // Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Serververzeichnis befinden.

   static string static.result[1];
   static int    lastTick;                                           // hilft bei der Erkennung von Mehrfachaufrufen während desselben Ticks

   // 1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (!ValidBars) /*&&*/ if (Tick != lastTick)
      static.result[0] = "";
   lastTick = Tick;

   // 2) wenn Wert im Cache, gecachten Wert zurückgeben
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // 3.1) Wert ermitteln
   string directory = AccountServer();

   // 3.2) wenn AccountServer() == "", Verzeichnis manuell ermitteln
   if (!StringLen(directory)) {
      // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
      string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");
      int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
      if (hFile < 0)                                                 // u.a. wenn das Serververzeichnis noch nicht existiert
         return(_EMPTY_STR(catch("GetServerName(1)->FileOpenHistory(\""+ fileName +"\")")));
      FileClose(hFile);

      // Datei suchen und Verzeichnisnamen auslesen
      string pattern = StringConcatenate(TerminalPath(), "\\history\\*");
      /*WIN32_FIND_DATA*/int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA.size);
      int hFindDir=FindFirstFileA(pattern, wfd), next=hFindDir;

      while (next != 0) {
         if (wfd_FileAttribute_Directory(wfd)) {
            string name = wfd_FileName(wfd);
            if (name != ".") /*&&*/ if (name != "..") {
               pattern = StringConcatenate(TerminalPath(), "\\history\\", name, "\\", fileName);
               int hFindFile = FindFirstFileA(pattern, wfd);
               if (hFindFile != INVALID_HANDLE_VALUE) {
                  //debug("GetServerName(2)  file = "+ pattern +"   found");
                  FindClose(hFindFile);
                  directory = name;
                  if (!DeleteFileA(pattern))                         // tmp. Datei per Win-API löschen (MQL kann es im History-Verzeichnis nicht)
                     return(_EMPTY_STR(catch("GetServerName(3)->kernel32::DeleteFileA(filename=\""+ pattern +"\")", ERR_WIN32_ERROR), FindClose(hFindDir)));
                  break;
               }
            }
         }
         next = FindNextFileA(hFindDir, wfd);
      }
      if (hFindDir == INVALID_HANDLE_VALUE)
         return(_EMPTY_STR(catch("GetServerName(4) directory \""+ TerminalPath() +"\\history\\\" not found", ERR_FILE_NOT_FOUND)));

      FindClose(hFindDir);
      ArrayResize(wfd, 0);
      //debug("GetServerName(5)  resolved directory = \""+ directory +"\"");
   }

   int error = GetLastError();
   if (IsError(error))
      return(_EMPTY_STR(catch("GetServerName(6)", error)));

   if (!StringLen(directory))
      return(_EMPTY_STR(catch("GetServerName(7)  cannot find trade server directory", ERR_RUNTIME_ERROR)));

   static.result[0] = directory;
   return(static.result[0]);
}


/**
 * Initialisiert einen Buffer zur Aufnahme der gewünschten Anzahl von Doubles.
 *
 * @param  double buffer[] - das für den Buffer zu verwendende Double-Array
 * @param  int    size     - Anzahl der im Buffer zu speichernden Doubles
 *
 * @return int - Fehlerstatus
 */
int InitializeDoubleBuffer(double buffer[], int size) {
   if (ArrayDimension(buffer) > 1) return(catch("InitializeDoubleBuffer(1)  too many dimensions of parameter buffer = "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAYS));
   if (size < 0)                   return(catch("InitializeDoubleBuffer(2)  invalid parameter size = "+ size, ERR_INVALID_PARAMETER));

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
 * @return int - Fehlerstatus
 */
int InitializeStringBuffer(string &buffer[], int length) {
   if (ArrayDimension(buffer) > 1) return(catch("InitializeStringBuffer(1)  too many dimensions of parameter buffer = "+ ArrayDimension(buffer), ERR_INCOMPATIBLE_ARRAYS));
   if (length < 0)                 return(catch("InitializeStringBuffer(2)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER));

   if (ArraySize(buffer) == 0)
      ArrayResize(buffer, 1);

   buffer[0] = CreateString(length);

   return(catch("InitializeStringBuffer(3)"));
}


/**
 * Gibt den vollständigen Dateinamen der lokalen Konfigurationsdatei des Terminals zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname oder Leerstring, falls ein Fehler auftrat
 */
string GetLocalConfigPath() {
   static string static.result[1];                                   // ohne Initializer
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\metatrader-local-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetWindowsShortcutTarget(lnkFile);
         if (!StringLen(iniFile))
            return("");
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR)
            return(_EMPTY_STR(catch("GetLocalConfigPath(1)->kernel32::_lcreat(filename=\""+ iniFile +"\")", ERR_WIN32_ERROR)));
         _lclose(hFile);
      }
   }

   static.result[0] = iniFile;

   if (!catch("GetLocalConfigPath(2)"))
      return(static.result[0]);
   return("");
}


/**
 * Gibt den vollständigen Dateinamen der globalen Konfigurationsdatei des Terminals zurück.
 * Existiert die Datei nicht, wird sie angelegt.
 *
 * @return string - Dateiname
 */
string GetGlobalConfigPath() {
   static string static.result[1];                                   // ohne Initializer
   if (StringLen(static.result[0]) > 0)
      return(static.result[0]);

   // Cache-miss, aktuellen Wert ermitteln
   string iniFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");
   bool createIniFile = false;

   if (!IsFile(iniFile)) {
      string lnkFile = StringConcatenate(iniFile, ".lnk");

      if (IsFile(lnkFile)) {
         iniFile = GetWindowsShortcutTarget(lnkFile);
         if (!StringLen(iniFile))
            return("");
         createIniFile = !IsFile(iniFile);
      }
      else {
         createIniFile = true;
      }

      if (createIniFile) {
         int hFile = _lcreat(iniFile, AT_NORMAL);
         if (hFile == HFILE_ERROR)
            return(_EMPTY_STR(catch("GetGlobalConfigPath(1)->kernel32::_lcreat(filename=\""+ iniFile +"\")", ERR_WIN32_ERROR)));
         _lclose(hFile);
      }
   }

   static.result[0] = iniFile;

   if (!catch("GetGlobalConfigPath(2)"))
      return(static.result[0]);
   return("");
}


/**
 * Sortiert die übergebenen Tickets in chronologischer Reihenfolge (nach OpenTime und Ticket#).
 *
 * @param  int tickets[] - zu sortierende Tickets
 *
 * @return int - Fehlerstatus
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
            maxYDistance = Max(maxYDistance, ObjectGet(objName, OBJPROP_YDISTANCE));
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

   if (!catch("CreateLegendLabel()"))
      return(label);
   return("");
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
 * Ob ein Tradeserver-Fehler temporär (also vorübergehend) ist oder nicht. Bei einem vorübergehenden Fehler *kann* der erneute Versuch,
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
      case ERR_SERVER_BUSY:                  //        4   trade server busy
      case ERR_TRADE_TIMEOUT:                //      128   trade timeout
      case ERR_INVALID_PRICE:                //      129   Kurs bewegt sich zu schnell (aus dem Fenster)
      case ERR_PRICE_CHANGED:                //      135   price changed
      case ERR_OFF_QUOTES:                   //      136   off quotes
      case ERR_REQUOTE:                      //      138   requote
      case ERR_TRADE_CONTEXT_BUSY:           //      146   trade context busy
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
      case ERR_INVALID_STOP:                 //      130   invalid stop
      case ERR_INVALID_TRADE_VOLUME:         //      131   invalid trade volume
      case ERR_MARKET_CLOSED:                //      132   market is closed
      case ERR_TRADE_DISABLED:               //      133   trading is disabled
      case ERR_NOT_ENOUGH_MONEY:             //      134   not enough money
      case ERR_BROKER_BUSY:                  //      137   EA trading disabled (manual trading still enabled)
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
 * Ob ein Tradeserver-Fehler permanent (also nicht nur vorübergehend) ist oder nicht. Bei einem permanenten Fehler wird auch der erneute Versuch,
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
 * Weist einer Position eines zweidimensionalen Integer-Arrays ein anderes Array zu (entspricht array[i] = array[] für ein Array von Arrays).
 *
 * @param  int array[][] - zu modifizierendes zwei-dimensionales Arrays
 * @param  int offset    - zu modifizierende Position
 * @param  int values[]  - zuzuweisendes Array (Größe muß der zweiten Dimension des zu modifizierenden Arrays entsprechen)
 *
 * @return int - Fehlerstatus
 */
int ArraySetInts(int array[][], int offset, int values[]) {
   if (ArrayDimension(array) != 2)   return(catch("ArraySetInts(1)  illegal dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));
   if (ArrayDimension(values) != 1)  return(catch("ArraySetInts(2)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS));
   int dim1 = ArrayRange(array, 0);
   int dim2 = ArrayRange(array, 1);
   if (ArraySize(values) != dim2)    return(catch("ArraySetInts(3)  array size mis-match of parameters array and values: array["+ dim1 +"]["+ dim2 +"] / values["+ ArraySize(values) +"]", ERR_INCOMPATIBLE_ARRAYS));
   if (offset < 0 || offset >= dim1) return(catch("ArraySetInts(4)  illegal parameter offset = "+ offset, ERR_INVALID_PARAMETER));

   int src  = GetIntsAddress(values);
   int dest = GetIntsAddress(array) + offset*dim2*4;
   CopyMemory(dest, src, dim2*4);
   return(NO_ERROR);
}


/**
 * Fügt ein Element am Ende eines Boolean-Arrays an.
 *
 * @param  bool array[] - Boolean-Array
 * @param  bool value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayPushBool(bool &array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushBool()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Fügt ein Element am Ende eines Integer-Arrays an.
 *
 * @param  int array[] - Integer-Array
 * @param  int value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayPushInt(int &array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushInt()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Fügt ein Integer-Array am Ende eines zweidimensionalen Integer-Arrays an.
 *
 * @param  int array[][] - zu erweiterndes Array ein-dimensionaler Arrays
 * @param  int value[]   - hinzuzufügendes Array (Größe muß zum zu erweiternden Array passen)
 *
 * @return int - neue Größe der ersten Dimension des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayPushInts(int array[][], int value[]) {
   if (ArrayDimension(array) != 2) return(_EMPTY(catch("ArrayPushInts(1)  illegal dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(value) != 1) return(_EMPTY(catch("ArrayPushInts(2)  too many dimensions of parameter value = "+ ArrayDimension(value), ERR_INCOMPATIBLE_ARRAYS)));
   int dim1 = ArrayRange(array, 0);
   int dim2 = ArrayRange(array, 1);
   if (ArraySize(value) != dim2)   return(_EMPTY(catch("ArrayPushInts(3)  array size mis-match of parameters array and value: array["+ dim1 +"]["+ dim2 +"] / value["+ ArraySize(value) +"]", ERR_INCOMPATIBLE_ARRAYS)));

   ArrayResize(array, dim1+1);
   int src  = GetIntsAddress(value);
   int dest = GetIntsAddress(array) + dim1*dim2*4;
   CopyMemory(dest, src, dim2*4);
   return(dim1+1);
}


/**
 * Fügt ein Element am Ende eines Double-Arrays an.
 *
 * @param  double array[] - Double-Array
 * @param  double value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayPushDouble(double &array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushDouble()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);

   ArrayResize(array, size+1);
   array[size] = value;

   return(size+1);
}


/**
 * Fügt ein Element am Ende eines String-Arrays an.
 *
 * @param  string array[] - String-Array
 * @param  string value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayPushString(string &array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayPushString()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
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
   if (ArrayDimension(array) > 1) return(!catch("ArrayPopBool(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));

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
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayPopInt(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayPopDouble(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(array) > 1) return(_EMPTY_STR(catch("ArrayPopString(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayUnshiftBool(bool array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftBool()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayUnshiftInt(int array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftInt()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayUnshiftDouble(double array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftDouble()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(array) > 1) return(!catch("ArrayShiftBool(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));

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
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayShiftInt(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(array) > 1) return(_NULL(catch("ArrayShiftDouble(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(array) > 1) return(_EMPTY_STR(catch("ArrayShiftString(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayDropBool(bool array[], bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropBool()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayDropInt(int array[], int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropInt()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayDropDouble(double array[], double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropDouble()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayDropString(string array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayDropString()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

   int count, size=ArraySize(array);
   if (!size)
      return(0);

   if (StringIsNull(value)) {                         // NULL-Pointer
      for (int i=size-1; i>=0; i--) {
         if (!StringLen(array[i])) /*&&*/ if (StringIsNull(array[i])) {
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
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArraySpliceBools(bool array[], int offset, int length) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArraySpliceBools(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);
   if (offset < 0)                return(_EMPTY(catch("ArraySpliceBools(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > size-1)           return(_EMPTY(catch("ArraySpliceBools(3)  invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_PARAMETER)));
   if (length < 0)                return(_EMPTY(catch("ArraySpliceBools(4)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));

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
 * Entfernt einen Teil aus einem Integer-Array.
 *
 * @param  int array[][] - ein- oder zweidimensionales Integer-Array
 * @param  int offset    - Startindex der zu entfernenden Elemente
 * @param  int length    - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArraySpliceInts(int array[], int offset, int length) {
   int dims = ArrayDimension(array);
   if (dims > 2)        return(_EMPTY(catch("ArraySpliceInts(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

   int dim1 = ArrayRange(array, 0), dim2=0;
   if (dims > 1) dim2 = ArrayRange(array, 1);

   if (offset < 0)      return(_EMPTY(catch("ArraySpliceInts(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > dim1-1) return(_EMPTY(catch("ArraySpliceInts(3)  invalid parameter offset = "+ offset +" for array["+ dim1 +"]"+ ifString(dims==1, "", "[]"), ERR_INVALID_PARAMETER)));
   if (length < 0)      return(_EMPTY(catch("ArraySpliceInts(4)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));

   if (dim1   == 0) return(0);
   if (length == 0) return(0);

   if (offset+length < dim1) {
      if (dims == 1) ArrayCopy(array, array, offset,       offset+length      );    // ArrayCopy(), wenn die zu entfernenden Elemente das Ende nicht einschließen
      else           ArrayCopy(array, array, offset*dim2, (offset+length)*dim2);
   }
   else {
      length = dim1 - offset;
   }

   ArrayResize(array, dim1-length);
   return(length);
}


/**
 * Entfernt einen Teil aus einem Double-Array.
 *
 * @param  double array[] - Double-Array
 * @param  int    offset  - Startindex zu entfernender Elemente
 * @param  int    length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArraySpliceDoubles(double array[], int offset, int length) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArraySpliceDoubles(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);
   if (offset < 0)                return(_EMPTY(catch("ArraySpliceDoubles(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > size-1)           return(_EMPTY(catch("ArraySpliceDoubles(3)  invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_PARAMETER)));
   if (length < 0)                return(_EMPTY(catch("ArraySpliceDoubles(4)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));

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
 * Entfernt einen Teil aus einem String-Array.
 *
 * @param  string array[] - String-Array
 * @param  int    offset  - Startindex zu entfernender Elemente
 * @param  int    length  - Anzahl der zu entfernenden Elemente
 *
 * @return int - Anzahl der entfernten Elemente oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArraySpliceStrings(string array[], int offset, int length) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArraySpliceStrings(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   int size = ArraySize(array);
   if (offset < 0)                return(_EMPTY(catch("ArraySpliceStrings(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   if (offset > size-1)           return(_EMPTY(catch("ArraySpliceStrings(3)  invalid parameter offset = "+ offset +" for sizeOf(array) = "+ size, ERR_INVALID_PARAMETER)));
   if (length < 0)                return(_EMPTY(catch("ArraySpliceStrings(4)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));

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
 * @param  bool array[] - Bool-Array
 * @param  int  offset  - Position, an dem das Element eingefügt werden soll
 * @param  bool value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertBool(bool &array[], int offset, bool value) {
   value = value!=0;

   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertBool(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertBool(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertBool(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

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
 * @param  int array[] - Integer-Array
 * @param  int offset  - Position, an dem das Element eingefügt werden soll
 * @param  int value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertInt(int &array[], int offset, int value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertInt(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertInt(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertInt(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

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
 * @param  double array[] - Double-Array
 * @param  int    offset  - Position, an dem das Element eingefügt werden soll
 * @param  double value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertDouble(double &array[], int offset, double value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertDouble(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertDouble(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertDouble(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

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
 * Fügt in ein Bool-Array die Elemente eines anderen Bool-Arrays ein.
 *
 * @param  bool array[]  - Ausgangs-Array
 * @param  int  offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  bool values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertBools(bool array[], int offset, bool values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertBools(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertBools(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertBools(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertBools(4)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertInts(int array[], int offset, int values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertInts(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertInts(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertInts(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertInts(4)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ArrayInsertDoubles(double array[], int offset, double values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertDoubles(1)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertDoubles(2)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertDoubles(3)  invalid parameter offset = "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertDoubles(4)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));
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
 * Prüft, ob ein Boolean in einem Array enthalten ist.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool BoolInArray(bool haystack[], bool needle) {
   needle = needle!=0;

   if (ArrayDimension(haystack) > 1) return(!catch("BoolInArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS));
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
   if (ArrayDimension(haystack) > 1) return(!catch("IntInArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS));
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
   if (ArrayDimension(haystack) > 1) return(!catch("DoubleInArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS));
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
   if (ArrayDimension(haystack) > 1) return(!catch("StringInArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS));
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
   if (ArrayDimension(haystack) > 1) return(!catch("StringInArrayI()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS));
   return(SearchStringArrayI(haystack, needle) > -1);
}


/**
 * Durchsucht ein Boolean-Array nach einem Wert und gibt dessen Index zurück.
 *
 * @param  bool haystack[] - zu durchsuchendes Array
 * @param  bool needle     - zu suchender Wert
 *
 * @return int - Index des ersten Vorkommen des Wertes oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchBoolArray(bool haystack[], bool needle) {
   needle = needle!=0;

   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchBoolArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - Index des ersten Vorkommen des Wertes oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchIntArray(int haystack[], int needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchIntArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - Index des ersten Vorkommen des Wertes oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchDoubleArray(double haystack[], double needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchDoubleArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - Index des ersten Vorkommen des Wertes oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchStringArray(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchStringArray()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));
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
 * @return int - Index des ersten Vorkommen des Wertes oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist oder ein Fehler auftrat
 */
int SearchStringArrayI(string haystack[], string needle) {
   if (ArrayDimension(haystack) > 1) return(_EMPTY(catch("SearchStringArrayI()  too many dimensions of parameter haystack = "+ ArrayDimension(haystack), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(haystack);
   needle = StringToLower(needle);

   for (int i=0; i < size; i++) {
      if (StringToLower(haystack[i]) == needle)
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
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
 * @return bool - TRUE,  wenn die Indizierung der internen Arrayimplementierung nach der Verarbeitung ebenfalls umgekehrt ist
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
 * @return int - Größe des resultierenden Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int MergeBoolArrays(bool array1[], bool array2[], bool merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeBoolArrays(1)  too many dimensions of parameter array1 = "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeBoolArrays(2)  too many dimensions of parameter array2 = "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeBoolArrays(3)  too many dimensions of parameter merged = "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Größe des resultierenden Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int MergeIntArrays(int array1[], int array2[], int merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeIntArrays(1)  too many dimensions of parameter array1 = "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeIntArrays(2)  too many dimensions of parameter array2 = "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeIntArrays(3)  too many dimensions of parameter merged = "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Größe des resultierenden Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int MergeDoubleArrays(double array1[], double array2[], double merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeDoubleArrays(1)  too many dimensions of parameter array1 = "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeDoubleArrays(2)  too many dimensions of parameter array2 = "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeDoubleArrays(3)  too many dimensions of parameter merged = "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @return int - Größe des resultierenden Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 */
int MergeStringArrays(string array1[], string array2[], string merged[]) {
   if (ArrayDimension(array1) > 1) return(_EMPTY(catch("MergeStringArrays(1)  too many dimensions of parameter array1 = "+ ArrayDimension(array1), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(array2) > 1) return(_EMPTY(catch("MergeStringArrays(2)  too many dimensions of parameter array2 = "+ ArrayDimension(array2), ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayDimension(merged) > 1) return(_EMPTY(catch("MergeStringArrays(3)  too many dimensions of parameter merged = "+ ArrayDimension(merged), ERR_INCOMPATIBLE_ARRAYS)));

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
   if (ArrayDimension(values) > 1) return(_NULL(catch("SumDoubles()  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   double sum;

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum);
}


/**
 * Gibt die lesbare Version eines Zeichenbuffers zurück. <NUL>-Characters (0x00h) werden gestrichelt (…), Control-Characters (< 0x20h) fett (•) dargestellt.
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
         int char = integer & 0xFF;                                     // ein einzelnes Byte des Integers lesen     // +---+------------+------+
         if (char < 0x20) {                                             // nicht darstellbare Zeichen ersetzen       // | 0 | 0x000000FF |   1  |
            if (char == 0x00) char = PLACEHOLDER_NUL_CHAR;              // NUL-Byte          (…)                     // | 1 | 0x0000FF00 |   2  |
            else              char = PLACEHOLDER_CTRL_CHAR;             // Control-Character (•)                     // | 2 | 0x00FF0000 |   3  |
         }                                                                                                           // | 3 | 0xFF000000 |   4  |
         result = StringConcatenate(result, CharToStr(char));                                                        // +---+------------+------+
         integer >>= 8;
      }
   }
   return(result);
}


/**
 * Gibt den Inhalt eines Byte-Buffers als lesbaren String zurück. NUL-Bytes (0x00h) werden gestrichelt (…), Control-Character (< 0x20h) fett (•) dargestellt.
 * Nützlich, um einen Bufferinhalt schnell visualisieren zu können.
 *
 * @param  int buffer[] - Byte-Buffer (kann ein- oder zwei-dimensional sein)
 *
 * @return string
 *
 * @access private - Aufruf nur aus BufferToStr()
 */
string __BuffersToStr(int buffer[][]) {
   int dimensions = ArrayDimension(buffer);
   if (dimensions > 2) return(_EMPTY_STR(catch("__BuffersToStr()  too many dimensions of parameter buffer = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));

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
            int char = integer & 0xFF;                                  // ein einzelnes Byte des Integers lesen     // +---+------------+------+
            if (char < 0x20) {                                          // nicht darstellbare Zeichen ersetzen       // | 0 | 0x000000FF |   1  |
               if (char == 0x00) char = PLACEHOLDER_NUL_CHAR;           // NUL-Byte          (…)                     // | 1 | 0x0000FF00 |   2  |
               else              char = PLACEHOLDER_CTRL_CHAR;          // Control-Character (•)                     // | 2 | 0x00FF0000 |   3  |
            }                                                                                                        // | 3 | 0xFF000000 |   4  |
            result = StringConcatenate(result, CharToStr(char));                                                     // +---+------------+------+
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

   string hex, byte1, byte2, byte3, byte4, result="";
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
   if (dimensions > 2) return(_EMPTY_STR(catch("__BuffersToHexStr()  too many dimensions of parameter buffer = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));

   if (dimensions == 1)
      return(BufferToHexStr(buffer));

   int dim1=ArrayRange(buffer, 0), dim2=ArrayRange(buffer, 1);

   string hex, byte1, byte2, byte3, byte4, result="";

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
 * @return int - Zeichen-Code oder -1 (EMPTY), falls ein Fehler auftrat
 */
int BufferGetChar(int buffer[], int pos) {
   int chars = ArraySize(buffer) << 2;

   if (pos < 0)      return(_EMPTY(catch("BufferGetChar(1)  invalid parameter pos = "+ pos, ERR_INVALID_PARAMETER)));
   if (pos >= chars) return(_EMPTY(catch("BufferGetChar(2)  invalid parameter pos = "+ pos, ERR_INVALID_PARAMETER)));

   int i = pos >> 2;                      // Index des relevanten Integers des Arrays     // +---+------------+
   int b = pos & 0x03;                    // Index des relevanten Bytes des Integers      // | b |    byte    |
                                                                                          // +---+------------+
   int integer = buffer[i] >> (b<<3);                                                     // | 0 | 0x000000FF |
   int char    = integer & 0xFF;                                                          // | 1 | 0x0000FF00 |
                                                                                          // | 2 | 0x00FF0000 |
   return(char);                                                                          // | 3 | 0xFF000000 |
}                                                                                         // +---+------------+


/**
 * Gibt den in einem Byte-Buffer im angegebenen Bereich gespeicherten WCHAR-String als MQL-String zurück.
 *
 * @param  int buffer[] - Byte-Buffer
 * @param  int from     - Offset des WCHAR-Strings innerhalb des Buffers in Bytes (Vielfaches von 2)
 * @param  int size     - Anzahl der für den WCHAR-String reservierten Bytes (Vielfaches von 2)
 *
 * @return string - MQL-String oder Leerstring, falls ein Fehler auftrat
 *
string BufferWCharsToStr(int buffer[], int from, int size) {
   int bufferSize = ArraySize(buffer) * 4;
   if (from < 0 || from >= bufferSize)     return(_EMPTY_STR(catch("BufferWCharsToStr(1)  invalid parameter from = "+ from +" (out of range)", ERR_INVALID_PARAMETER)));
   if (from%2 != 0)                        return(_EMPTY_STR(catch("BufferWCharsToStr(2)  invalid parameter from = "+ from +" (not a multiple of 2)", ERR_INVALID_PARAMETER));
   if (size < 0 || from+size > bufferSize) return(_EMPTY_STR(catch("BufferWCharsToStr(3)  invalid parameter size = "+ size +" (out of range)", ERR_INVALID_PARAMETER)));
   if (size%2 != 0)                        return(_EMPTY_STR(catch("BufferWCharsToStr(4)  invalid parameter size = "+ size +" (not a multiple of 2)", ERR_INVALID_PARAMETER));

   string result;
   if (!size)
      return(result);                                                // NULL-Pointer

   int fromAddr = GetIntsAddress(buffer) + from;
}
*/


/**
 * Gibt die in einem Byte-Buffer im angegebenen Bereich gespeicherte und mit einem NULL-Byte terminierte WCHAR-Charactersequenz (Multibyte-Characters) zurück.
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
   if (from   < 0) return(_EMPTY_STR(catch("BufferWCharsToStr(1)  invalid parameter from = "+ from, ERR_INVALID_PARAMETER)));
   if (length < 0) return(_EMPTY_STR(catch("BufferWCharsToStr(2)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));
   int to = from+length, size=ArraySize(buffer);
   if (to > size)  return(_EMPTY_STR(catch("BufferWCharsToStr(3)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));

   string result = "";

   for (int i=from; i < to; i++) {
      string sChar;
      int word, shift=0, integer=buffer[i];

      for (int n=0; n < 2; n++) {
         word = integer >> shift & 0xFFFF;
         if (word == 0)                                              // termination character (0x00)
            break;
         int byte1 = word      & 0xFF;
         int byte2 = word >> 8 & 0xFF;

         if (byte1 && !byte2) sChar = CharToStr(byte1);
         else                 sChar = "¿";                           // multi-byte character
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
 * Ermittelt den vollständigen Dateipfad der Zieldatei, auf die ein Windows-Shortcut (.lnk-File) zeigt.
 *
 * @return string lnkFilename - vollständige Pfadangabe zum Shortcut
 *
 * @return string - Dateipfad der Zieldatei oder Leerstring, falls ein Fehler auftrat
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
   // @see http://www.codeproject.com/KB/shell/ReadLnkFile.aspx
   // --------------------------------------------------------------------------

   if (StringLen(lnkFilename) < 4 || StringRight(lnkFilename, 4)!=".lnk")
      return(_EMPTY_STR(catch("GetWindowsShortcutTarget(1)  invalid parameter lnkFilename = \""+ lnkFilename +"\"", ERR_INVALID_PARAMETER)));

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
      if (__LOG) log("GetWindowsShortcutTarget(8)  shortcut target is not a file or directory: \""+ lnkFilename +"\"");
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
 * @return int - Fehlerstatus
 */
int WinExecWait(string cmdLine, int cmdShow) {
   /*STARTUPINFO*/int si[]; InitializeByteBuffer(si, STARTUPINFO.size);
   si_setSize      (si, STARTUPINFO.size);
   si_setFlags     (si, STARTF_USESHOWWINDOW);
   si_setShowWindow(si, cmdShow);

   int    iNull[], /*PROCESS_INFORMATION*/pi[]; InitializeByteBuffer(pi, PROCESS_INFORMATION.size);
   string sNull;

   if (!CreateProcessA(sNull, cmdLine, iNull, iNull, false, 0, iNull, sNull, si, pi))
      return(catch("WinExecWait(1)->kernel32::CreateProcessA(cmdLine=\""+ cmdLine +"\")", ERR_WIN32_ERROR));

   int result = WaitForSingleObject(pi_hProcess(pi), INFINITE);

   // @see  http://stackoverflow.com/questions/9369823/how-to-get-a-sub-process-return-code
   //
   // GetExitCodeProcess(pi.hProcess, &exit_code);
   // printf("execution of: \"%s\"\nexit code: %d", cmdLine, exit_code);

   if (result != WAIT_OBJECT_0) {
      if (result == WAIT_FAILED) catch("WinExecWait(2)->kernel32::WaitForSingleObject()", ERR_WIN32_ERROR);
      else if (__LOG)              log("WinExecWait(3)->kernel32::WaitForSingleObject() => "+ WaitForSingleObjectValueToStr(result));
   }

   CloseHandle(pi_hProcess(pi));
   CloseHandle(pi_hThread (pi));

   return(catch("WinExecWait(4)"));
}


/**
 * Liest eine Datei zeilenweise (ohne Zeilenende-Zeichen) in ein Array ein.
 *
 * @param  string filename       - Dateiname mit zu ".\files\" relativer Pfadangabe
 * @param  string result[]       - Array zur Aufnahme der einzelnen Zeilen
 * @param  bool   skipEmptyLines - ob leere Zeilen übersprungen werden sollen (default: nein)
 *
 * @return int - Anzahl der eingelesenen Zeilen oder -1 (EMPTY), falls ein Fehler auftrat
 */
int FileReadLines(string filename, string result[], bool skipEmptyLines=false) {
   skipEmptyLines = skipEmptyLines!=0;

   int hFile, hFileBin, fieldSeparator='\t';

   // Datei öffnen
   hFile = FileOpen(filename, FILE_CSV|FILE_READ, fieldSeparator);         // erwartet Pfadangabe relativ zu ".\files\"
   if (hFile < 0)
      return(_EMPTY(catch("FileReadLines(1)->FileOpen(\""+ filename +"\")")));


   // Schnelle Rückkehr bei leerer Datei
   if (FileSize(hFile) == 0) {
      FileClose(hFile);
      ArrayResize(result, 0);
      return(ifInt(!catch("FileReadLines(2)"), 0, -1));
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
            if (!StringLen(value)) {
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
         //debug("FileReadLines()  new line "+ i +",   "+ StringLen(value) +" chars,   fPointer="+ FileTell(hFile));
      }
      else {
         // FileReadString() liest max. 4095 Zeichen: bei langen Zeilen prüfen, ob das letzte Zeichen ein Separator war
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
         //debug("FileReadLines()  extend line "+ i +",   adding "+ StringLen(value) +" chars to existing "+ StringLen(lines[i-1]) +" chars,   fPointer="+ FileTell(hFile));
      }
   }

   // Dateiende hat ERR_END_OF_FILE ausgelöst
   int error = GetLastError();
   if (error!=ERR_END_OF_FILE) /*&&*/ if (IsError(error)) {
      FileClose(hFile);
      if (hFileBin != 0)
         FileClose(hFileBin);
      return(_EMPTY(catch("FileReadLines(5)", error)));
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
 * Gibt das Standardsymbol des aktuellen Symbols zurück.
 * (z.B. StdSymbol() => "EURUSD")
 *
 * @return string - Standardsymbol oder das aktuelle Symbol, wenn das Standardsymbol unbekannt ist
 *
 *
 * NOTE: Alias für GetStandardSymbol(Symbol())
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
 * NOTE: Alias für GetStandardSymbolOrAlt(symbol, symbol)
 */
string GetStandardSymbol(string symbol) {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetStandardSymbol()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
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
 * NOTE: Im Unterschied zu GetStandardSymbolStrict() erlaubt diese Funktion die Angabe eines Alternativwertes,
 *       läßt jedoch nicht mehr so einfach erkennen, ob ein Standardsymbol gefunden wurde oder nicht.
 */
string GetStandardSymbolOrAlt(string symbol, string altValue="") {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetStandardSymbolOrAlt()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   string value = GetStandardSymbolStrict(symbol);
   if (!StringLen(value))
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
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetStandardSymbolStrict()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   symbol = StringToUpper(symbol);

   if      (StringEndsWith(symbol, "_ASK")) symbol = StringLeft(symbol, -4);
   else if (StringEndsWith(symbol, "_AVG")) symbol = StringLeft(symbol, -4);

   switch (StringGetChar(symbol, 0)) {
      case '_': if                  (symbol=="_BRENT" )     return("BRENT"  );
                if                  (symbol=="_DJI"   )     return("DJIA"   );
                if                  (symbol=="_DJT"   )     return("DJTA"   );
                if                  (symbol=="_N225"  )     return("NIK225" );
                if                  (symbol=="_NQ100" )     return("NAS100" );
                if                  (symbol=="_NQCOMP")     return("NASCOMP");
                if                  (symbol=="_SP500" )     return("SP500"  );
                if                  (symbol=="_WTI"   )     return("WTI"    );
                break;

      case '#': if                  (symbol=="#DAX.XEI" )   return("DAX"  );
                if                  (symbol=="#DJI.XDJ" )   return("DJIA" );
                if                  (symbol=="#DJT.XDJ" )   return("DJTA" );
                if                  (symbol=="#SPX.X.XP")   return("SP500");
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

      case 'A': if (StringStartsWith(symbol, "AUDCAD"))     return("AUDCAD");
                if (StringStartsWith(symbol, "AUDCHF"))     return("AUDCHF");
                if (StringStartsWith(symbol, "AUDDKK"))     return("AUDDKK");
                if (StringStartsWith(symbol, "AUDJPY"))     return("AUDJPY");
                if (StringStartsWith(symbol, "AUDLFX"))     return("AUDLFX");
                if (StringStartsWith(symbol, "AUDNZD"))     return("AUDNZD");
                if (StringStartsWith(symbol, "AUDPLN"))     return("AUDPLN");
                if (StringStartsWith(symbol, "AUDSGD"))     return("AUDSGD");
                if (StringStartsWith(symbol, "AUDUSD"))     return("AUDUSD");
                if (                 symbol=="AUS200" )     return("ASX200");
                break;

      case 'B': if (StringStartsWith(symbol, "BRENT_"))     return("BRENT" );
                break;

      case 'C': if (StringStartsWith(symbol, "CADCHF")  )   return("CADCHF");
                if (StringStartsWith(symbol, "CADJPY")  )   return("CADJPY");
                if (StringStartsWith(symbol, "CADLFX")  )   return("CADLFX");
                if (StringStartsWith(symbol, "CADSGD")  )   return("CADSGD");
                if (StringStartsWith(symbol, "CHFJPY")  )   return("CHFJPY");
                if (StringStartsWith(symbol, "CHFLFX")  )   return("CHFLFX");
                if (StringStartsWith(symbol, "CHFPLN")  )   return("CHFPLN");
                if (StringStartsWith(symbol, "CHFSGD")  )   return("CHFSGD");
                if (StringStartsWith(symbol, "CHFZAR")  )   return("CHFZAR");
                if (                 symbol=="CLX5"     )   return("WTI"   );
                if (                 symbol=="CRUDE_OIL")   return("WTI"   );
                break;

      case 'D': if (                 symbol=="DE30"   )     return("DAX"   );
                break;

      case 'E': if (                 symbol=="ECX"   )      return("EURX"  );
                if (StringStartsWith(symbol, "EURAUD"))     return("EURAUD");
                if (StringStartsWith(symbol, "EURCAD"))     return("EURCAD");
                if (StringStartsWith(symbol, "EURCCK"))     return("EURCZK");
                if (StringStartsWith(symbol, "EURCZK"))     return("EURCZK");
                if (StringStartsWith(symbol, "EURCHF"))     return("EURCHF");
                if (StringStartsWith(symbol, "EURDKK"))     return("EURDKK");
                if (StringStartsWith(symbol, "EURGBP"))     return("EURGBP");
                if (StringStartsWith(symbol, "EURHKD"))     return("EURHKD");
                if (StringStartsWith(symbol, "EURHUF"))     return("EURHUF");
                if (StringStartsWith(symbol, "EURJPY"))     return("EURJPY");
                if (StringStartsWith(symbol, "EURLFX"))     return("EURLFX");
                if (StringStartsWith(symbol, "EURLVL"))     return("EURLVL");
                if (StringStartsWith(symbol, "EURMXN"))     return("EURMXN");
                if (StringStartsWith(symbol, "EURNOK"))     return("EURNOK");
                if (StringStartsWith(symbol, "EURNZD"))     return("EURNZD");
                if (StringStartsWith(symbol, "EURPLN"))     return("EURPLN");
                if (StringStartsWith(symbol, "EURRUB"))     return("EURRUB");
                if (StringStartsWith(symbol, "EURRUR"))     return("EURRUB");
                if (StringStartsWith(symbol, "EURSEK"))     return("EURSEK");
                if (StringStartsWith(symbol, "EURSGD"))     return("EURSGD");
                if (StringStartsWith(symbol, "EURTRY"))     return("EURTRY");
                if (StringStartsWith(symbol, "EURUSD"))     return("EURUSD");
                if (StringStartsWith(symbol, "EURZAR"))     return("EURZAR");
                if (                 symbol=="EURX"  )      return("EURX"  );
                break;

      case 'F': break;

      case 'G': if (StringStartsWith(symbol, "GBPAUD") )    return("GBPAUD");
                if (StringStartsWith(symbol, "GBPCAD") )    return("GBPCAD");
                if (StringStartsWith(symbol, "GBPCHF") )    return("GBPCHF");
                if (StringStartsWith(symbol, "GBPDKK") )    return("GBPDKK");
                if (StringStartsWith(symbol, "GBPJPY") )    return("GBPJPY");
                if (StringStartsWith(symbol, "GBPLFX") )    return("GBPLFX");
                if (StringStartsWith(symbol, "GBPNOK") )    return("GBPNOK");
                if (StringStartsWith(symbol, "GBPNZD") )    return("GBPNZD");
                if (StringStartsWith(symbol, "GBPPLN") )    return("GBPPLN");
                if (StringStartsWith(symbol, "GBPRUB") )    return("GBPRUB");
                if (StringStartsWith(symbol, "GBPRUR") )    return("GBPRUB");
                if (StringStartsWith(symbol, "GBPSEK") )    return("GBPSEK");
                if (StringStartsWith(symbol, "GBPUSD") )    return("GBPUSD");
                if (StringStartsWith(symbol, "GBPZAR") )    return("GBPZAR");
                if (                 symbol=="GOLD"    )    return("XAUUSD");
                if (                 symbol=="GOLDEURO")    return("XAUEUR");
                break;

      case 'H': if (StringStartsWith(symbol, "HKDJPY"))     return("HKDJPY");
                break;

      case 'I': break;

      case 'J': if (StringStartsWith(symbol, "JPYLFX"))     return("JPYLFX");
                break;

      case 'K': break;

      case 'L': if (StringStartsWith(symbol, "LFXJPY"))     return("LFXJPY");
                if (                 symbol=="LCOX5"  )     return("BRENT" );
                break;

      case 'M': if (StringStartsWith(symbol, "MXNJPY"))     return("MXNJPY");
                break;

      case 'N': if (StringStartsWith(symbol, "NOKJPY"))     return("NOKJPY");
                if (StringStartsWith(symbol, "NOKSEK"))     return("NOKSEK");
                if (StringStartsWith(symbol, "NZDCAD"))     return("NZDCAD");
                if (StringStartsWith(symbol, "NZDCHF"))     return("NZDCHF");
                if (StringStartsWith(symbol, "NZDJPY"))     return("NZDJPY");
                if (StringStartsWith(symbol, "NZDLFX"))     return("NZDLFX");
                if (StringStartsWith(symbol, "NZDSGD"))     return("NZDSGD");
                if (StringStartsWith(symbol, "NZDUSD"))     return("NZDUSD");
                break;

      case 'O': break;

      case 'P': if (StringStartsWith(symbol, "PLNJPY"))     return("PLNJPY");
                break;

      case 'Q': break;

      case 'R': if (                 symbol=="RUSSEL_2000") return("RUS2000");
                break;

      case 'S': if (                 symbol=="S&P_500"   )  return("SP500" );
                if (StringStartsWith(symbol, "SEKJPY")   )  return("SEKJPY");
                if (StringStartsWith(symbol, "SGDJPY")   )  return("SGDJPY");
                if (                 symbol=="SILVER"    )  return("XAGUSD");
                if (                 symbol=="SILVEREURO")  return("XAGEUR");
                break;

      case 'T': if (StringStartsWith(symbol, "TRYJPY"))     return("TRYJPY");
                break;

      case 'U':
                if (                 symbol=="US30"   )     return("DJIA"  );
                if (                 symbol=="US500"  )     return("SP500" );
                if (                 symbol=="US2000" )     return("RUS2000");
                if (StringStartsWith(symbol, "USDCAD"))     return("USDCAD");
                if (StringStartsWith(symbol, "USDCHF"))     return("USDCHF");
                if (StringStartsWith(symbol, "USDCCK"))     return("USDCZK");
                if (StringStartsWith(symbol, "USDCNY"))     return("USDCNY");
                if (StringStartsWith(symbol, "USDCZK"))     return("USDCZK");
                if (StringStartsWith(symbol, "USDDKK"))     return("USDDKK");
                if (StringStartsWith(symbol, "USDHKD"))     return("USDHKD");
                if (StringStartsWith(symbol, "USDHRK"))     return("USDHRK");
                if (StringStartsWith(symbol, "USDHUF"))     return("USDHUF");
                if (StringStartsWith(symbol, "USDINR"))     return("USDINR");
                if (StringStartsWith(symbol, "USDJPY"))     return("USDJPY");
                if (StringStartsWith(symbol, "USDLFX"))     return("USDLFX");
                if (StringStartsWith(symbol, "USDLTL"))     return("USDLTL");
                if (StringStartsWith(symbol, "USDLVL"))     return("USDLVL");
                if (StringStartsWith(symbol, "USDMXN"))     return("USDMXN");
                if (StringStartsWith(symbol, "USDNOK"))     return("USDNOK");
                if (StringStartsWith(symbol, "USDPLN"))     return("USDPLN");
                if (StringStartsWith(symbol, "USDRUB"))     return("USDRUB");
                if (StringStartsWith(symbol, "USDRUR"))     return("USDRUB");
                if (StringStartsWith(symbol, "USDSEK"))     return("USDSEK");
                if (StringStartsWith(symbol, "USDSAR"))     return("USDSAR");
                if (StringStartsWith(symbol, "USDSGD"))     return("USDSGD");
                if (StringStartsWith(symbol, "USDTHB"))     return("USDTHB");
                if (StringStartsWith(symbol, "USDTRY"))     return("USDTRY");
                if (StringStartsWith(symbol, "USDTWD"))     return("USDTWD");
                if (                 symbol=="USDX"   )     return("USDX"  );
                if (StringStartsWith(symbol, "USDZAR"))     return("USDZAR");
                if (                 symbol=="USTEC"  )     return("NAS100");
                break;

      case 'V': break;

      case 'W': if (StringStartsWith(symbol, "WTI_"  ))     return("WTI"   );
                break;

      case 'X': if (StringStartsWith(symbol, "XAGEUR"))     return("XAGEUR");
                if (StringStartsWith(symbol, "XAGJPY"))     return("XAGJPY");
                if (StringStartsWith(symbol, "XAGUSD"))     return("XAGUSD");
                if (StringStartsWith(symbol, "XAUEUR"))     return("XAUEUR");
                if (StringStartsWith(symbol, "XAUJPY"))     return("XAUJPY");
                if (StringStartsWith(symbol, "XAUUSD"))     return("XAUUSD");
                break;

      case 'Y': break;

      case 'Z': if (StringStartsWith(symbol, "ZARJPY"))     return("ZARJPY");
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
 * NOTE: Alias für GetSymbolNameOrAlt(symbol, symbol)
 */
string GetSymbolName(string symbol) {
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetSymbolName()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
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
   if (!StringLen(symbol))
      return(_EMPTY_STR(catch("GetSymbolNameOrAlt()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

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
      return(_EMPTY_STR(catch("GetSymbolNameStrict()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   symbol = GetStandardSymbolStrict(symbol);
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

      case 'R': if (symbol == "RUS2000") return("Russel 2000");
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
      return(_EMPTY_STR(catch("GetLongSymbolName()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
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
      return(_EMPTY_STR(catch("GetLongSymbolNameOrAlt()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

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
      return(_EMPTY_STR(catch("GetLongSymbolNameStrict()  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));

   symbol = GetStandardSymbolStrict(symbol);

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
   if (symbol == "RUS2000" ) return("Russel 2000"             );
   if (symbol == "SP500"   ) return("S&P 500"                 );
   if (symbol == "USDLFX"  ) return("USD (LFX)"               );
   if (symbol == "USDX"    ) return("USD Index (ICE)"         );
   if (symbol == "XAGEUR"  ) return("Silver/EUR"              );
   if (symbol == "XAGJPY"  ) return("Silver/JPY"              );
   if (symbol == "XAGUSD"  ) return("Silver/USD"              );
   if (symbol == "XAUEUR"  ) return("Gold/EUR"                );
   if (symbol == "XAUJPY"  ) return("Gold/JPY"                );
   if (symbol == "XAUUSD"  ) return("Gold/USD"                );

   string prefix = StringLeft(symbol, -3);
   string suffix = StringRight(symbol, 3);

   if      (suffix == ".BA") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Balance"      )); }
   else if (suffix == ".BX") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Balance + AuM")); }
   else if (suffix == ".EA") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Equity"       )); }
   else if (suffix == ".EX") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Equity + AuM" )); }
   else if (suffix == ".LA") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Leverage"     )); }
   else if (suffix == ".PL") { if (StringIsDigit(prefix)) return(StringConcatenate("Account ", prefix, " Profit/Loss"  )); }

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
      return(_EMPTY_STR(catch("StringPad(1)  illegal parameter pad_string = \""+ pad_string +"\"", ERR_INVALID_PARAMETER)));

   if (pad_type == STR_PAD_LEFT ) return(StringPadLeft (input, pad_length, pad_string));
   if (pad_type == STR_PAD_RIGHT) return(StringPadRight(input, pad_length, pad_string));


   if (pad_type == STR_PAD_BOTH) {
      int padLengthLeft  = (pad_length-lenInput)/2 + (pad_length-lenInput)%2;
      int padLengthRight = (pad_length-lenInput)/2;

      string paddingLeft  = StringRepeat(pad_string, padLengthLeft );
      string paddingRight = StringRepeat(pad_string, padLengthRight);
      if (lenPadStr > 1) {
         paddingLeft  = StringSubstr(paddingLeft,  0, padLengthLeft );
         paddingRight = StringSubstr(paddingRight, 0, padLengthRight);
      }
      return(paddingLeft + input + paddingRight);
   }

   return(_EMPTY_STR(catch("StringPad(2)  illegal parameter pad_type = "+ pad_type, ERR_INVALID_PARAMETER)));
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

   int dayOfWeek = TimeDayOfWeekFix(fxtTime);

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
      return(_NaT(catch("GetPrevSessionStartTime.fxt(1)  invalid parameter fxtTime = "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) - 1*DAY;
   if (startTime < 0)
      return(_NaT(catch("GetPrevSessionStartTime.fxt(2)  illegal result "+ startTime, ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekFix(startTime);
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
      return(_NaT(catch("GetSessionStartTime.fxt(1)  invalid parameter fxtTime = "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime);
   if (startTime < 0)
      return(_NaT(catch("GetSessionStartTime.fxt(2)  illegal result "+ startTime, ERR_RUNTIME_ERROR)));

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekFix(startTime);
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
   if (fxtTime < 0)
      return(_NaT(catch("GetNextSessionStartTime.fxt()  invalid parameter fxtTime = "+ fxtTime, ERR_INVALID_PARAMETER)));

   datetime startTime = fxtTime - TimeHour(fxtTime)*HOURS - TimeMinute(fxtTime)*MINUTES - TimeSeconds(fxtTime) + 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeekFix(startTime);
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

   string result;

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
   return(_NULL(catch("DecreasePeriod()  invalid parameter period = "+ period, ERR_INVALID_PARAMETER)));
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
 * Prüft, ob seit dem letzten Aufruf ein AccountChange-Event aufgetreten ist.
 *
 * @param  int results[] - eventspezifische Detailinfos {last_account, current_account, current_account_login}
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 *
 *
 * NOTE: Während des Terminal-Starts und bei Accountwechseln kann AccountNumber() kurzzeitig 0 zurückgeben.
 *       Diese start()-Aufrufe des noch nicht vollständig initialisierten Acconts werden nicht als Accountwechsel
 *       im Sinne dieses Listeners interpretiert.
 */
bool EventListener.AccountChange(int results[], int flags=NULL) {
   static int accountData[3];                         // {last_account, current_account, current_account_login}

   bool eventStatus = false;
   int  account = AccountNumber();

   if (account != 0) {                                // AccountNumber() == 0 ignorieren
      if (!accountData[1]) {                          // 1. Lib-Aufruf
         accountData[0] = 0;
         accountData[1] = account;
         accountData[2] = GmtToServerTime(GetGmtTime());
         //debug("EventListener.AccountChange()  Account "+ account +" nach 1. Lib-Aufruf initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_FULL));
      }
      else if (accountData[1] != account) {           // Aufruf nach Accountwechsel zur Laufzeit
         accountData[0] = accountData[1];
         accountData[1] = account;
         accountData[2] = GmtToServerTime(GetGmtTime());
         //debug("EventListener.AccountChange()  Account "+ account +" nach Accountwechsel initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_FULL));
         eventStatus = true;
      }
   }
   //debug("EventListener.AccountChange()  eventStatus: "+ eventStatus);

   if (ArraySize(results) != 3)
      ArrayResize(results, 3);
   ArrayCopy(results, accountData);

   int error = GetLastError();
   if (!error)
      return(eventStatus);
   return(!catch("EventListener.AccountChange(1)", error));
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand-Event aufgetreten ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string commands[], int flags=NULL) {
   return(!catch("EventListener.ChartCommand(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Zerlegt einen String in Teilstrings.
 *
 * @param  string input     - zu zerlegender String
 * @param  string separator - Trennstring
 * @param  string results[] - Zielarray für die Teilstrings
 * @param  int    limit     - maximale Anzahl von Teilstrings (default: kein Limit)
 *
 * @return int - Anzahl der Teilstrings oder -1 (EMPTY), wennn ein Fehler auftrat
 */
int Explode(string input, string separator, string &results[], int limit=NULL) {
   // Der Parameter input *könnte* ein Element des Ergebnisarrays results[] sein, daher erstellen wir
   // vor Modifikation von results[] eine Kopie von input und verwenden diese.
   string _input = StringConcatenate(input, "");

   int lenInput     = StringLen(input),
       lenSeparator = StringLen(separator);

   if (StringIsNull(input)) {                // Null-Pointer
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
 * Liest die History eines Accounts aus einer CSV-Datei in das angegebene Array ein (Werte werden im Array als Strings gespeichert).
 *
 * @param  int    account     - Account-Nummer
 * @param  string results[][] - Zielarray
 *
 * @return int - Fehlerstatus
 */
int GetAccountHistory(int account, string results[][AH_COLUMNS]) {
   if (ArrayRange(results, 1) != AH_COLUMNS)
      return(catch("GetAccountHistory(1)  invalid parameter results["+ ArrayRange(results, 0) +"]["+ ArrayRange(results, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   static int    static.account[1];
   static string static.results[][AH_COLUMNS];

   ArrayResize(results, 0);

   // nach Möglichkeit die gecachten Daten liefern
   if (account == static.account[0]) {
      ArrayCopy(results, static.results);
      return(catch("GetAccountHistory(3)"));
   }

   // Cache-Miss, Historydatei auslesen
   string header[AH_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment" };

   string filename = ShortAccountCompany() +"/"+ account + "_account_history.csv";
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (hFile < 0) {
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE)
         return(error);
      return(catch("GetAccountHistory(4)->FileOpen(\""+ filename +"\")", error));
   }

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true;
   int    lines=0, row=-2, col=-1;
   string result[][AH_COLUMNS]; ArrayResize(result, 0);        // tmp. Zwischenspeicher für ausgelesene Daten

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
            if (!StringLen(value)) {
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
      if (lineEnd) /*&&*/ if (col!=AH_COLUMNS-1) {
         error = catch("GetAccountHistory(5)  data format error in \""+ filename +"\", column count in line "+ lines +" is not "+ AH_COLUMNS, ERR_RUNTIME_ERROR);
         break;
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            error = catch("GetAccountHistory(6)  data format error in \""+ filename +"\", unexpected column header \""+ value +"\"", ERR_RUNTIME_ERROR);
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
   if (!error) {
      error = GetLastError();
      if (error == ERR_END_OF_FILE) {
         error = NO_ERROR;
      }
      else {
         catch("GetAccountHistory(7)", error);
      }
   }

   // vor evt. Fehler-Rückkehr auf jeden Fall Datei schließen
   FileClose(hFile);

   if (IsError(error))        // ret
      return(error);


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) > 0) {                                  // "leere" Historydaten nicht cachen (falls Datei noch erstellt wird)
      static.account[0] = account;
      ArrayResize(static.results, 0);
      ArrayCopy  (static.results, result);
      ArrayResize(result, 0);

      ArrayCopy(results, static.results);
   }

   ArrayResize(header, 0);
   return(catch("GetAccountHistory(9)"));
}


/**
 * Gibt die aktuelle Account-Nummer zurück (unabhängig von einer Server-Verbindung).
 *
 * @return int - Account-Nummer oder 0, falls ein Fehler auftrat
 *
 * @throws ERS_TERMINAL_NOT_YET_READY - falls die Account-Nummer während des Terminal-Starts noch nicht verfügbar ist (Titel des Hauptfensters noch nicht gesetzt)
 */
int GetAccountNumber() {
   static int tester.result;
   if (tester.result != 0)
      return(tester.result);

   int account = AccountNumber();

   if (account == 0x4000) {                                          // im Tester ohne Server-Verbindung
      if (!IsTesting())             return(_NULL(catch("GetAccountNumber(1)->AccountNumber()  illegal account number "+ account +" (0x"+ IntToHexStr(account) +")", ERR_RUNTIME_ERROR)));
      account = 0;
   }

   if (!account) {                                                   // Titelzeile des Hauptfensters auswerten
      string title = GetWindowText(GetApplicationWindow());          // benutzt SendMessage(), nicht nach Tester.Stop() bei VisualMode=On benutzen => Deadlock UI-Thread
      if (!StringLen(title))        return(_NULL(debug("GetAccountNumber(2)->GetWindowText(hWndMain) = \""+ title +"\"", SetLastError(ERS_TERMINAL_NOT_YET_READY))));

      int pos = StringFind(title, ":");
      if (pos < 1)                  return(_NULL(catch("GetAccountNumber(3)  account number separator not found in top window title \""+ title +"\"", ERR_RUNTIME_ERROR)));

      string strValue = StringLeft(title, pos);
      if (!StringIsDigit(strValue)) return(_NULL(catch("GetAccountNumber(4)  account number in top window title contains non-digits \""+ title +"\"", ERR_RUNTIME_ERROR)));

      account = StrToInteger(strValue);
   }

   // Im Tester muß die Accountnummer während der Laufzeit gecacht werden, um UI-Deadlocks bei Aufruf von GetWindowText() in deinit() zu vermeiden.
   // stdlib.init() ruft daher für Experts im Tester als Vorbedingung einer vollständigen Initialisierung GetAccountNumber() auf.
   // Online wiederum darf jedoch nicht gecacht werden, da Accountwechsel nicht zuverlässig erkannt werden können.
   if (IsTesting())
      tester.result = account;

   return(account);                                                  // nicht die statische Testervariable zurückgeben (ist online immer 0)
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Ergebnisarrays (aufsteigend nach Zeit sortiert).
 *
 * @param  int      account  - Account-Nummer
 * @param  datetime times[]  - Zeiger auf Ergebnisarray für die Zeiten der Balanceänderung
 * @param  double   values[] - Zeiger auf Ergebnisarray der entsprechenden Balancewerte
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime &times[], double &values[]) {
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
       * stdlib: Alert: ERROR:   AUDUSD,M15::Balance::stdlib::GetBalanceHistory(1)   [4051 - invalid function parameter value]
       */
      ArrayCopy(times,  static.times);
      ArrayCopy(values, static.values);
      return(catch("GetBalanceHistory(1)"));
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][AH_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (IsError(error)) {
      if (error == ERR_CANNOT_OPEN_FILE) return(catch("GetBalanceHistory(2", error));
                                         return(catch("GetBalanceHistory(3)"));
   }

   // Balancedatensätze einlesen und auswerten (History ist nach CloseTime sortiert)
   datetime time, lastTime;
   double   balance, lastBalance;
   int n, size=ArrayRange(data, 0);

   if (size == 0)
      return(catch("GetBalanceHistory(4)"));

   for (int i=0; i<size; i++) {
      balance = StrToDouble (data[i][I_AH_BALANCE       ]);
      time    = StrToInteger(data[i][I_AH_CLOSETIMESTAMP]);

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

   ArrayResize(data, 0);
   return(catch("GetBalanceHistory(5)"));
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
      static.result[0] = StringToLower(buffer[0]);

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
   if (fxtTime < 0) return(_EMPTY_VALUE(catch("GetFxtToGmtTimeOffset(1)  invalid parameter fxtTime = "+ fxtTime, ERR_INVALID_PARAMETER)));

   int offset, year=TimeYearFix(fxtTime)-1970;

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
   string serverTimezone = GetServerTimezone();
   if (!StringLen(serverTimezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu FXT festen Zeitzone läuft
   if (serverTimezone == "FXT"             ) return(      0);
   if (serverTimezone == "FXT-0200"        ) return(2*HOURS);
   if (serverTimezone == "America/New_York") return(7*HOURS);


   if (fxtTime < 0) return(_EMPTY_VALUE(catch("GetFxtToServerTimeOffset(1)  invalid parameter fxtTime = "+ fxtTime, ERR_INVALID_PARAMETER)));


   // Offset FXT zu GMT
   int offset1 = GetFxtToGmtTimeOffset(fxtTime);
   if (offset1 == EMPTY_VALUE)
      return(EMPTY_VALUE);

   // Offset GMT zu Server
   int offset2 = 0;
   if (serverTimezone != "GMT") {
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
   string serverTimezone = GetServerTimezone();
   if (!StringLen(serverTimezone))
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Server unter einer zu GMT festen Zeitzone läuft
   if (serverTimezone == "GMT") return(0);


   if (gmtTime < 0) return(_EMPTY_VALUE(catch("GetGmtToServerTimeOffset(1)  invalid parameter gmtTime = "+ gmtTime, ERR_INVALID_PARAMETER)));


   if (serverTimezone == "Alpari") {
      if (gmtTime < D'2012.04.01 00:00:00') serverTimezone = "Europe/Berlin";
      else                                  serverTimezone = "Europe/Kiev";
   }
   else if (serverTimezone == "GlobalPrime") {
      if (gmtTime < D'2015.10.25 00:00:00') serverTimezone = "FXT";
      else                                  serverTimezone = "Europe/Kiev";
   }

   int offset, year=TimeYearFix(gmtTime)-1970;

   if (serverTimezone == "America/New_York") {
      if      (gmtTime < transitions.America_New_York[year][TR_TO_DST.gmt]) offset = -transitions.America_New_York[year][STD_OFFSET];
      else if (gmtTime < transitions.America_New_York[year][TR_TO_STD.gmt]) offset = -transitions.America_New_York[year][DST_OFFSET];
      else                                                                  offset = -transitions.America_New_York[year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Berlin") {
      if      (gmtTime < transitions.Europe_Berlin   [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Berlin   [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Berlin   [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Berlin   [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Berlin   [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Kiev") {
      if      (gmtTime < transitions.Europe_Kiev     [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Kiev     [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Kiev     [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Kiev     [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Kiev     [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/London") {
      if      (gmtTime < transitions.Europe_London   [year][TR_TO_DST.gmt]) offset = -transitions.Europe_London   [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_London   [year][TR_TO_STD.gmt]) offset = -transitions.Europe_London   [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_London   [year][STD_OFFSET];
   }
   else if (serverTimezone == "Europe/Minsk") {
      if      (gmtTime < transitions.Europe_Minsk    [year][TR_TO_DST.gmt]) offset = -transitions.Europe_Minsk    [year][STD_OFFSET];
      else if (gmtTime < transitions.Europe_Minsk    [year][TR_TO_STD.gmt]) offset = -transitions.Europe_Minsk    [year][DST_OFFSET];
      else                                                                  offset = -transitions.Europe_Minsk    [year][STD_OFFSET];
   }
   else if (serverTimezone == "FXT") {
      if      (gmtTime < transitions.FXT             [year][TR_TO_DST.gmt]) offset = -transitions.FXT             [year][STD_OFFSET];
      else if (gmtTime < transitions.FXT             [year][TR_TO_STD.gmt]) offset = -transitions.FXT             [year][DST_OFFSET];
      else                                                                  offset = -transitions.FXT             [year][STD_OFFSET];
   }
   else if (serverTimezone == "FXT-0200") {
      if      (gmtTime < transitions.FXT             [year][TR_TO_DST.gmt]) offset = -transitions.FXT             [year][STD_OFFSET] + PLUS_2_H;
      else if (gmtTime < transitions.FXT             [year][TR_TO_STD.gmt]) offset = -transitions.FXT             [year][DST_OFFSET] + PLUS_2_H;
      else                                                                  offset = -transitions.FXT             [year][STD_OFFSET] + PLUS_2_H;
   }
   else return(_EMPTY_VALUE(catch("GetGmtToServerTimeOffset(2)  unknown server timezone \""+ serverTimezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

   return(offset);
}


/**
 * Gibt den Wert eines Schlüssels des angegebenen Abschnitts einer .ini-Datei als String zurück. Ein leerer Wert eines existierenden Schlüssels wird
 * als Leerstring zurückgegeben.
 *
 * @param  string fileName     - Name der .ini-Datei
 * @param  string section      - Abschnittsname
 * @param  string key          - Schlüsselname
 * @param  string defaultValue - Rückgabewert, falls der angegebene Schlüssel nicht existiert
 *
 * @return string - unveränderter Konfigurationswert oder Leerstring, falls ein Fehler auftrat (ggf. mit Konfigurationskommentar)
 */
string GetRawIniString(string fileName, string section, string key, string defaultValue="") {
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   // GetPrivateProfileString() übernimmt nur dann den angegebenen Default-Value, wenn der Schlüssel nicht existiert.
   // Ein Leervalue eines Schlüssels wird korrekt als Leerstring zurückgegeben.
   int chars = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-1) {
      bufferSize <<= 1;
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetPrivateProfileStringA(section, key, defaultValue, buffer[0], bufferSize, fileName);
   }

   if (!catch("GetRawIniString(1)"))
      return(buffer[0]);
   return("");
}


/**
 * Gibt die lesbare Beschreibung eines ShellExecute()/ShellExecuteEx()-Fehlercodes zurück.
 *
 * @param  int error - ShellExecute-Fehlercode
 *
 * @return string
 */
string ShellExecuteErrorDescription(int error) {
   switch (error) {
      case 0                     : return("out of memory or resources"                        );   //  0
      case ERROR_BAD_FORMAT      : return("incorrect file format"                             );   // 11

      case SE_ERR_FNF            : return("file not found"                                    );   //  2
      case SE_ERR_PNF            : return("path not found"                                    );   //  3
      case SE_ERR_ACCESSDENIED   : return("access denied"                                     );   //  5
      case SE_ERR_OOM            : return("out of memory"                                     );   //  8
      case SE_ERR_SHARE          : return("a sharing violation occurred"                      );   // 26
      case SE_ERR_ASSOCINCOMPLETE: return("file association information incomplete or invalid");   // 27
      case SE_ERR_DDETIMEOUT     : return("DDE operation timed out"                           );   // 28
      case SE_ERR_DDEFAIL        : return("DDE operation failed"                              );   // 29
      case SE_ERR_DDEBUSY        : return("DDE operation is busy"                             );   // 30
      case SE_ERR_NOASSOC        : return("file association information not available"        );   // 31
      case SE_ERR_DLLNOTFOUND    : return("DLL not found"                                     );   // 32
   }
   return(StringConcatenate("unknown ShellExecute() error (", error, ")"));
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
   if (This.IsTesting()) return(_EMPTY_VALUE(catch("GetLocalToGmtTimeOffset()", ERR_FUNC_NOT_ALLOWED_IN_TESTER)));

   /*TIME_ZONE_INFORMATION*/int tzi[]; InitializeByteBuffer(tzi, TIME_ZONE_INFORMATION.size);

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
 * Gibt die lesbare Konstante eines SwapCalculation-Modes zurück.
 *
 * @param  int mode - SwapCalculation-Mode
 *
 * @return string
 */
string SwapCalculationModeToStr(int mode) {
   switch (mode) {
      case SCM_POINTS         : return("SCM_POINTS"         );
      case SCM_BASE_CURRENCY  : return("SCM_BASE_CURRENCY"  );
      case SCM_INTEREST       : return("SCM_INTEREST"       );
      case SCM_MARGIN_CURRENCY: return("SCM_MARGIN_CURRENCY");       // Stringo: non-standard calculation (vom Broker abhängig)
   }
   return(_EMPTY_STR(catch("SwapCalculationModeToStr()  invalid paramter mode = "+ mode, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt die lesbare Konstante einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MaMethodToStr(int method) {
   switch (method) {
      case MODE_SMA : return("MODE_SMA" );
      case MODE_EMA : return("MODE_EMA" );
      case MODE_LWMA: return("MODE_LWMA");
      case MODE_ALMA: return("MODE_ALMA");
   }
   return(_EMPTY_STR(catch("MaMethodToStr()  invalid paramter method = "+ method, ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
string MovingAverageMethodToStr(int method) {
   return(MaMethodToStr(method));
}


/**
 * Gibt die lesbare Beschreibung einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MaMethodDescription(int method) {
   switch (method) {
      case MODE_SMA : return("SMA" );
      case MODE_EMA : return("EMA" );
      case MODE_LWMA: return("LWMA");
      case MODE_ALMA: return("ALMA");
   }
   return(_EMPTY_STR(catch("MaMethodDescription()  invalid paramter method = "+ method, ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
string MovingAverageMethodDescription(int method) {
   return(MaMethodDescription(method));
}


/**
 * Gibt den Integer-Wert eines PriceType-Bezeichners zurück.
 *
 * @param  string value
 *
 * @return int - PriceType-Code oder -1 (EMPTY), wenn der Bezeichner ungültig ist
 */
int StrToPriceType(string value) {
   string str = StringToUpper(StringTrim(value));

   if (StringLen(str) == 1) {
      if (str == "O"               ) return(PRICE_OPEN    );
      if (str == ""+ PRICE_OPEN    ) return(PRICE_OPEN    );
      if (str == "H"               ) return(PRICE_HIGH    );
      if (str == ""+ PRICE_HIGH    ) return(PRICE_HIGH    );
      if (str == "L"               ) return(PRICE_LOW     );
      if (str == ""+ PRICE_LOW     ) return(PRICE_LOW     );
      if (str == "C"               ) return(PRICE_CLOSE   );
      if (str == ""+ PRICE_CLOSE   ) return(PRICE_CLOSE   );
      if (str == "M"               ) return(PRICE_MEDIAN  );
      if (str == ""+ PRICE_MEDIAN  ) return(PRICE_MEDIAN  );
      if (str == "T"               ) return(PRICE_TYPICAL );
      if (str == ""+ PRICE_TYPICAL ) return(PRICE_TYPICAL );
      if (str == "W"               ) return(PRICE_WEIGHTED);
      if (str == ""+ PRICE_WEIGHTED) return(PRICE_WEIGHTED);
      if (str == "B"               ) return(PRICE_BID     );
      if (str == ""+ PRICE_BID     ) return(PRICE_BID     );
      if (str == "A"               ) return(PRICE_ASK     );
      if (str == ""+ PRICE_ASK     ) return(PRICE_ASK     );
   }
   else {
      if (StringStartsWith(str, "PRICE_"))
         str = StringRight(str, -6);

      if (str == "OPEN"            ) return(PRICE_OPEN    );
      if (str == "HIGH"            ) return(PRICE_HIGH    );
      if (str == "LOW"             ) return(PRICE_LOW     );
      if (str == "CLOSE"           ) return(PRICE_CLOSE   );
      if (str == "MEDIAN"          ) return(PRICE_MEDIAN  );
      if (str == "TYPICAL"         ) return(PRICE_TYPICAL );
      if (str == "WEIGHTED"        ) return(PRICE_WEIGHTED);
      if (str == "BID"             ) return(PRICE_BID     );
      if (str == "ASK"             ) return(PRICE_ASK     );
   }

   if (__LOG) log("StrToPriceType(1)  invalid parameter value = \""+ value +"\" (not a price type)", ERR_INVALID_PARAMETER);
   return(EMPTY);
}


/**
 * Gibt die lesbare Konstante eines Price-Identifiers zurück.
 *
 * @param  int type - Price-Type
 *
 * @return string
 */
string PriceTypeToStr(int type) {
   switch (type) {
      case PRICE_CLOSE   : return("PRICE_CLOSE"   );
      case PRICE_OPEN    : return("PRICE_OPEN"    );
      case PRICE_HIGH    : return("PRICE_HIGH"    );
      case PRICE_LOW     : return("PRICE_LOW"     );
      case PRICE_MEDIAN  : return("PRICE_MEDIAN"  );     // (High+Low)/2
      case PRICE_TYPICAL : return("PRICE_TYPICAL" );     // (High+Low+Close)/3
      case PRICE_WEIGHTED: return("PRICE_WEIGHTED");     // (High+Low+Close+Close)/4
      case PRICE_BID     : return("PRICE_BID"     );
      case PRICE_ASK     : return("PRICE_ASK"     );
   }
   return(_EMPTY_STR(catch("PriceTypeToStr(1)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt die lesbare Version eines Price-Identifiers zurück.
 *
 * @param  int type - Price-Type
 *
 * @return string
 */
string PriceTypeDescription(int type) {
   switch (type) {
      case PRICE_CLOSE   : return("Close"   );
      case PRICE_OPEN    : return("Open"    );
      case PRICE_HIGH    : return("High"    );
      case PRICE_LOW     : return("Low"     );
      case PRICE_MEDIAN  : return("Median"  );     // (High+Low)/2
      case PRICE_TYPICAL : return("Typical" );     // (High+Low+Close)/3
      case PRICE_WEIGHTED: return("Weighted");     // (High+Low+Close+Close)/4
      case PRICE_BID     : return("Bid"     );
      case PRICE_ASK     : return("Ask"     );
   }
   return(_EMPTY_STR(catch("PriceTypeDescription(1)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt den Integer-Wert eines Timeframe-Bezeichners zurück.
 *
 * @param  string value - M1, M5, M15, M30 etc.
 *
 * @return int - Timeframe-Code oder -1 (EMPTY), wenn der Bezeichner ungültig ist
 */
int StrToPeriod(string value) {
   string str = StringToUpper(StringTrim(value));

   if (StringStartsWith(str, "PERIOD_"))
      str = StringRight(str, -7);

   if (str ==           "M1" ) return(PERIOD_M1 );    // 1 minute
   if (str == ""+ PERIOD_M1  ) return(PERIOD_M1 );    //
   if (str ==           "M5" ) return(PERIOD_M5 );    // 5 minutes
   if (str == ""+ PERIOD_M5  ) return(PERIOD_M5 );    //
   if (str ==           "M15") return(PERIOD_M15);    // 15 minutes
   if (str == ""+ PERIOD_M15 ) return(PERIOD_M15);    //
   if (str ==           "M30") return(PERIOD_M30);    // 30 minutes
   if (str == ""+ PERIOD_M30 ) return(PERIOD_M30);    //
   if (str ==           "H1" ) return(PERIOD_H1 );    // 1 hour
   if (str == ""+ PERIOD_H1  ) return(PERIOD_H1 );    //
   if (str ==           "H4" ) return(PERIOD_H4 );    // 4 hour
   if (str == ""+ PERIOD_H4  ) return(PERIOD_H4 );    //
   if (str ==           "D1" ) return(PERIOD_D1 );    // 1 day
   if (str == ""+ PERIOD_D1  ) return(PERIOD_D1 );    //
   if (str ==           "W1" ) return(PERIOD_W1 );    // 1 week
   if (str == ""+ PERIOD_W1  ) return(PERIOD_W1 );    //
   if (str ==           "MN1") return(PERIOD_MN1);    // 1 month
   if (str == ""+ PERIOD_MN1 ) return(PERIOD_MN1);    //
   if (str ==           "Q1" ) return(PERIOD_Q1 );    // 1 quarter
   if (str == ""+ PERIOD_Q1  ) return(PERIOD_Q1 );    //

   if (__LOG) log("StrToPeriod(1)  invalid parameter value = \""+ value +"\"", ERR_INVALID_PARAMETER);
   return(EMPTY);
}


/**
 * Alias
 */
int StrToTimeframe(string timeframe) {
   return(StrToPeriod(timeframe));
}


/**
 * Gibt die lesbare Version eines Test-Flags zurück.
 *
 * @param  int flags - Kombination von Test-Flags
 *
 * @return string
 */
string TestFlagsToStr(int flags) {
   string result = "";

   if (!flags)                                           result = StringConcatenate(result, "|NULL"              );
   if (flags & TF_TEST && 1)                             result = StringConcatenate(result, "|TF_TEST"           );
   if (flags & TF_VISUAL_TEST     == TF_VISUAL_TEST    ) result = StringConcatenate(result, "|TF_VISUAL_TEST"    );
   if (flags & TF_OPTIMIZING_TEST == TF_OPTIMIZING_TEST) result = StringConcatenate(result, "|TF_OPTIMIZING_TEST");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die lesbare Version eines Init-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener Init-Flags
 *
 * @return string
 */
string InitFlagsToStr(int flags) {
   string result = "";

   if (!flags)                                result = StringConcatenate(result, "|0"                       );
   if (flags & INIT_TIMEZONE            && 1) result = StringConcatenate(result, "|INIT_TIMEZONE"           );
   if (flags & INIT_PIPVALUE            && 1) result = StringConcatenate(result, "|INIT_PIPVALUE"           );
   if (flags & INIT_BARS_ON_HIST_UPDATE && 1) result = StringConcatenate(result, "|INIT_BARS_ON_HIST_UPDATE");
   if (flags & INIT_CUSTOMLOG           && 1) result = StringConcatenate(result, "|INIT_CUSTOMLOG"          );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die lesbare Version eines Deinit-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener Deinit-Flags
 *
 * @return string
 */
string DeinitFlagsToStr(int flags) {
   string result = "";

   if (!flags) result = StringConcatenate(result, "|0"      );
   else        result = StringConcatenate(result, "|"+ flags);

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die lesbare Version eines FileAccess-Modes zurück.
 *
 * @param  int mode - Kombination verschiedener FileAccess-Modes
 *
 * @return string
 */
string FileAccessModeToStr(int mode) {
   string result = "";

   if (!mode)                  result = StringConcatenate(result, "|0"         );
   if (mode & FILE_CSV   && 1) result = StringConcatenate(result, "|FILE_CSV"  );
   if (mode & FILE_BIN   && 1) result = StringConcatenate(result, "|FILE_BIN"  );
   if (mode & FILE_READ  && 1) result = StringConcatenate(result, "|FILE_READ" );
   if (mode & FILE_WRITE && 1) result = StringConcatenate(result, "|FILE_WRITE");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die Zeitzone des aktuellen MetaTrader-Servers zurück (nach Olson Timezone Database).
 *
 * @return string - Zeitzonen-Identifier oder Leerstring, falls ein Fehler auftrat
 *
 * @see http://en.wikipedia.org/wiki/Tz_database
 */
string GetServerTimezone() { // throws ERR_INVALID_TIMEZONE_CONFIG
   /*
   Die Timezone-ID wird zwischengespeichert und erst mit Auftreten von ValidBars = 0 verworfen und neu ermittelt.  Bei Accountwechsel zeigen die
   Rückgabewerte der MQL-Accountfunktionen evt. schon auf den neuen Account, der aktuelle Tick gehört aber noch zum alten Chart mit den alten Bars.
   Erst ValidBars = 0 stellt sicher, daß wir uns tatsächlich im neuen Chart mit neuer Zeitzone befinden.
   */
   static string static.timezone[1];
   static int    lastTick;                                           // Erkennung von Mehrfachaufrufen während desselben Ticks

   // (1) wenn ValidBars==0 && neuer Tick, Cache verwerfen
   if (!ValidBars) /*&&*/ if (Tick != lastTick)
      static.timezone[0] = "";
   lastTick = Tick;

   if (StringLen(static.timezone[0]) > 0)
      return(static.timezone[0]);


   // (2) Timezone-ID ermitteln
   string timezone, directory=StringToLower(GetServerName());

   if (!StringLen(directory))
      return("");
   else if (StringStartsWith(directory, "alpari-"            )) timezone = "Alpari";               // Alpari: bis 31.03.2012 "Europe/Berlin" (History wurde nicht aktualisiert)
   else if (StringStartsWith(directory, "alparibroker-"      )) timezone = "Alpari";               //                 danach "Europe/Kiev"
   else if (StringStartsWith(directory, "alpariuk-"          )) timezone = "Alpari";
   else if (StringStartsWith(directory, "alparius-"          )) timezone = "Alpari";
   else if (StringStartsWith(directory, "apbgtrading-"       )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "atcbrokers-"        )) timezone = "FXT";
   else if (StringStartsWith(directory, "atcbrokersest-"     )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "atcbrokersliq1-"    )) timezone = "FXT";
   else if (StringStartsWith(directory, "axitrader-"         )) timezone = "Europe/Kiev";          // oder FXT ???
   else if (StringStartsWith(directory, "axitraderusa-"      )) timezone = "Europe/Kiev";          // oder FXT ???
   else if (StringStartsWith(directory, "broco-"             )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "brocoinvestments-"  )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "cmap-"              )) timezone = "FXT-0200";             // GMT+0000/+0100 (Europe/London) mit DST-Wechseln von America/New_York
   else if (StringStartsWith(directory, "collectivefx-"      )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "dukascopy-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "easyforex-"         )) timezone = "GMT";
   else if (StringStartsWith(directory, "finfx-"             )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "forex-"             )) timezone = "GMT";
   else if (StringStartsWith(directory, "fxopen-"            )) timezone = "Europe/Kiev";          // oder FXT ???
   else if (StringStartsWith(directory, "fxprimus-"          )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "fxpro.com-"         )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "fxdd-"              )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "gci-"               )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "gcmfx-"             )) timezone = "GMT";
   else if (StringStartsWith(directory, "gftforex-"          )) timezone = "GMT";
   else if (StringStartsWith(directory, "globalprime-"       )) timezone = "GlobalPrime";          // GlobalPrime: bis 24.10.2015 "FXT", dann "Europe/Kiev" (hoffentlich einmaliger Bug)
   else if (StringStartsWith(directory, "icmarkets-"         )) timezone = "FXT";
   else if (StringStartsWith(directory, "inovatrade-"        )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "integral-"          )) timezone = "GMT";                  // Global Prime demo
   else if (StringStartsWith(directory, "investorseurope-"   )) timezone = "Europe/London";
   else if (StringStartsWith(directory, "jfd-demo"           )) timezone = "Europe/London";
   else if (StringStartsWith(directory, "jfd-live"           )) timezone = "Europe/London";
   else if (StringStartsWith(directory, "liteforex-"         )) timezone = "FXT";                  // TODO: Hat *wann* 2014/2015 von "Europe/Minsk" auf FXT *oder* Athen umgestellt?
   else if (StringStartsWith(directory, "londoncapitalgr-"   )) timezone = "GMT";
   else if (StringStartsWith(directory, "londoncapitalgroup-")) timezone = "GMT";
   else if (StringStartsWith(directory, "mbtrading-"         )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "metaquotes-"        )) timezone = "GMT";                  // Dummy-Wert
   else if (StringStartsWith(directory, "migbank-"           )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "myfx-"              )) timezone = "FXT";                  // XTrade
   else if (StringStartsWith(directory, "oanda-"             )) timezone = "America/New_York";
   else if (StringStartsWith(directory, "pepperstone-"       )) timezone = "FXT";
   else if (StringStartsWith(directory, "primexm-"           )) timezone = "GMT";
   else if (StringStartsWith(directory, "sig-"               )) timezone = "Europe/Minsk";
   else if (StringStartsWith(directory, "sts-"               )) timezone = "Europe/Kiev";
   else if (StringStartsWith(directory, "teletrade-"         )) timezone = "Europe/Berlin";
   else if (StringStartsWith(directory, "teletradecy-"       )) timezone = "Europe/Berlin";
   else {
      // Fallback zur manuellen Konfiguration in globaler Config
      timezone = GetGlobalConfigString("Timezones", directory);
      if (!StringLen(timezone))
         return(_EMPTY_STR(catch("GetServerTimezone(1)  missing timezone configuration for trade server \""+ GetServerName() +"\"", ERR_INVALID_TIMEZONE_CONFIG)));
   }


   if (IsError(catch("GetServerTimezone(2)")))
      return("");

   static.timezone[0] = timezone;
   return(timezone);
}


/**
 * Gibt das Fensterhandle des Strategy Testers zurück. Wird die Funktion nicht aus dem Tester heraus aufgerufen, ist es möglich,
 * daß das Fenster noch nicht existiert.
 *
 * @return int - Handle oder 0, falls ein Fehler auftrat
 */
int GetTesterWindow() {
   static int hWndTester;                                                        // ohne Initializer, @see MQL.doc
   if (hWndTester != 0)
      return(hWndTester);


   // Das Fenster kann im Terminalfenster angedockt sein oder in einem eigenen Toplevel-Window floaten, in beiden Fällen ist das Handle dasselbe und bleibt konstant.
   // alte Version mit dynamischen Klassennamen: v1.498


   // (1) Zunächst den im Hauptfenster angedockten Tester suchen
   int hWndMain = GetApplicationWindow();
   if (!hWndMain)
      return(0);
   int hWnd = GetDlgItem(hWndMain, IDC_DOCKABLES_CONTAINER);                     // Container für im Hauptfenster angedockte Fenster
   if (!hWnd)
      return(_NULL(catch("GetTesterWindow(1)  cannot find main parent window of docked child windows")));
   hWndTester = GetDlgItem(hWnd, IDC_TESTER);
   if (hWndTester != 0)
      return(hWndTester);


   // (2) Dann Toplevel-Windows durchlaufen und nicht angedocktes Testerfenster des eigenen Prozesses suchen
   int processId[1], hNext=GetTopWindow(NULL), me=GetCurrentProcessId();
   while (hNext != 0) {
      GetWindowThreadProcessId(hNext, processId);

      if (processId[0] == me) {
         if (StringStartsWith(GetWindowText(hNext), "Tester")) {
            hWnd = GetDlgItem(hNext, IDC_UNDOCKED_CONTAINER);                    // Container für nicht angedockten Tester
            if (!hWnd)
               return(_NULL(catch("GetTesterWindow(2)  cannot find children of top-level Tester window")));
            hWndTester = GetDlgItem(hWnd, IDC_TESTER);
            if (!hWndTester)
               return(_NULL(catch("GetTesterWindow(3)  cannot find sub-children of top-level Tester window")));
            break;
         }
      }
      hNext = GetWindow(hNext, GW_HWNDNEXT);
   }


   if (!hWndTester)
      if (__LOG) log("GetTesterWindow(4)  Strategy Tester window not found");   // Fenster existiert noch nicht

   return(hWndTester);
}


/**
 * Gibt den Titelzeilentext des angegebenen Fensters oder den Text des angegebenen Windows-Controls zurück.
 *
 * @param  int hWnd - Handle
 *
 * @return string - Text oder Leerstring, falls ein Fehler auftrat
 *
 *
 * NOTE: Ruft intern SendMessage() auf, deshalb nicht im Tester bei VisualMode=On in Expert::deinit() benutzen, da sonst UI-Thread-Deadlock.
 */
string GetWindowText(int hWnd) {
   if (hWnd <= 0)       return(_EMPTY_STR(catch("GetWindowText(1)  invalid parameter hWnd = "+ hWnd, ERR_INVALID_PARAMETER)));
   if (!IsWindow(hWnd)) return(_EMPTY_STR(catch("GetWindowText(2)  not an existing window hWnd = 0x"+ IntToHexStr(hWnd), ERR_RUNTIME_ERROR)));

   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetWindowTextA(hWnd, buffer[0], bufferSize);

   while (chars >= bufferSize-1) {                                   // GetWindowTextA() gibt beim Abschneiden zu langer Tielzeilen mal {bufferSize},
      bufferSize <<= 1;                                              // mal {bufferSize-1} zurück.
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetWindowTextA(hWnd, buffer[0], bufferSize);
   }
   return(buffer[0]);
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

   if (iAccountBalanceSeries(account, buffer) == ERS_HISTORY_UPDATE)
      return(SetLastError(ERS_HISTORY_UPDATE));

   return(catch("iAccountBalance()"));
}


/**
 * Berechnet den Balanceverlauf eines Accounts für alle Bars des aktuellen Charts und schreibt die Werte in das angegebene Zielarray.
 *
 * @param  int    account - Account-Nummer
 * @param  double buffer  - Ergebnisarray (z.B. Indikatorpuffer)
 *
 * @return int - Fehlerstatus
 */
int iAccountBalanceSeries(int account, double &buffer[]) {
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
      bar = iBarShiftNext(NULL, NULL, times[i]);
      if (bar == EMPTY_VALUE) return(last_error);
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
   return(_NULL(catch("IncreasePeriod()  invalid parameter period = "+ period, ERR_INVALID_PARAMETER)));
}


string chart.objects[];


/**
 * Fügt ein Object-Label zu den bei Programmende oder Bedarf automatisch zu entfernenden Chartobjekten hinzu.
 *
 * @param  string label - Object-Label
 *
 * @return int - Anzahl der gespeicherten Label oder -1, falls ein Fehler auftrat
 */
int ObjectRegister(string label) {
   return(ArrayPushString(chart.objects, label));
}


/**
 * Alias
 */
int RegisterChartObject(string label) {
   return(ObjectRegister(label));
}


/**
 * Löscht alle zum automatischen Entfernen registrierten Chartobjekte, die mit dem angegebenen Filter beginnen, aus dem Chart.
 *
 * @param  string prefix - Prefix des Labels der zu löschenden Objekte (default: alle Objekte)
 *
 * @return int - Fehlerstatus
 */
int DeleteRegisteredObjects(string prefix/*=NULL*/) {
   int size = ArraySize(chart.objects);
   if (!size) return(NO_ERROR);

   bool filter=false, filtered=false;

   if (StringLen(prefix) > 0)
      filter = (prefix != "0");                                      // (string) NULL == "0"

   if (filter) {
      // Filter angegeben: nur die passenden Objekte löschen
      for (int i=size-1; i >= 0; i--) {                              // wegen ArraySpliceStrings() rückwärts ierieren
         if (StringStartsWith(chart.objects[i], prefix)) {
            if (ObjectFind(chart.objects[i]) != -1)
               if (!ObjectDelete(chart.objects[i])) warn("DeleteRegisteredObjects(1)->ObjectDelete(label=\""+ chart.objects[i] +"\")", GetLastError());
            ArraySpliceStrings(chart.objects, i, 1);
         }
      }
   }
   else {
      // kein Filter angegeben: alle Objekte löschen
      for (i=0; i < size; i++) {
         if (ObjectFind(chart.objects[i]) != -1)
            if (!ObjectDelete(chart.objects[i])) warn("DeleteRegisteredObjects(2)->ObjectDelete(label=\""+ chart.objects[i] +"\")", GetLastError());
      }
      ArrayResize(chart.objects, 0);
   }

   return(catch("DeleteRegisteredObjects(3)"));
}


/**
 * Löscht ein Chartobjekt, ohne einen Fehler zu melden, falls das Objekt nicht gefunden wurde.
 *
 * @param  string label    - Object-Label
 * @param  string location - Bezeichner für evt. Fehlermeldung
 *
 * @return bool - Erfolgsstatus
 */
bool ObjectDeleteSilent(string label, string location) {
   if (ObjectFind(label) == -1)
      return(true);

   if (ObjectDelete(label))
      return(true);

   return(!catch("ObjectDeleteSilent()->"+ location));
}


/**
 * Schickt eine SMS an die angegebene Telefonnummer.
 *
 * @param  string receiver - Telefonnummer des Empfängers (internationales Format: +49-123-456789)
 * @param  string message  - Text der SMS
 *
 * @return bool - Erfolgsstatus
 */
bool SendSMS(string receiver, string message) {
   string _receiver = StringReplace.Recursive(StringReplace(StringTrim(receiver), "-", ""), " ", "");

   if      (StringStartsWith(_receiver, "+" )) _receiver = StringRight(_receiver, -1);
   else if (StringStartsWith(_receiver, "00")) _receiver = StringRight(_receiver, -2);

   if (!StringIsDigit(_receiver)) return(!catch("SendSMS(1)  invalid parameter receiver = \""+ receiver +"\"", ERR_INVALID_PARAMETER));


   // (1) Zugangsdaten für SMS-Gateway holen
   // Service-Provider
   string section  = "SMS";
   string key      = "Provider";
   string provider = GetGlobalConfigString(section, key);
   if (!StringLen(provider)) return(!catch("SendSMS(2)  missing setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Username
   section = "SMS."+ provider;
   key     = "username";
   string username = GetGlobalConfigString(section, key);
   if (!StringLen(username)) return(!catch("SendSMS(3)  missing setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Password
   key = "password";
   string password = GetGlobalConfigString(section, key);
   if (!StringLen(password)) return(!catch("SendSMS(4)  missing setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // API-ID
   key = "api_id";
   int api_id = GetGlobalConfigInt(section, key);
   if (api_id <= 0) {
      string value = GetGlobalConfigString(section, key);
      if (!StringLen(value)) return(!catch("SendSMS(5)  missing setting ["+ section +"]->"+ key,                       ERR_RUNTIME_ERROR));
                             return(!catch("SendSMS(6)  invalid setting ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_RUNTIME_ERROR));
   }


   // (2) Befehlszeile für Shellaufruf zusammensetzen
   string url          = "https://api.clickatell.com/http/sendmsg?user="+ username +"&password="+ password +"&api_id="+ api_id +"&to="+ _receiver +"&text="+ UrlEncode(message);
   string mqlDir       = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string filesDir     = TerminalPath() + mqlDir +"\\files";
   string responseFile = filesDir +"\\sms_"+ DateTimeToStr(TimeLocalEx("SendSMS(7)"), "Y-M-D H.I.S") +"_"+ GetCurrentThreadId() +".response";
   string logFile      = filesDir +"\\sms.log";
   string cmd          = TerminalPath() +"\\"+ mqlDir +"\\libraries\\wget.exe";
   string arguments    = "-b --no-check-certificate \""+ url +"\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";
   string cmdLine      = cmd +" "+ arguments;


   // (3) Shellaufruf
   int result = WinExec(cmdLine, SW_HIDE);
   if (result < 32) return(!catch("SendSMS(8)->kernel32::WinExec(cmd=\""+ cmd +"\")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   /**
    * TODO: Fehlerauswertung nach dem Versand:
    *
    * --2011-03-23 08:32:06--  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={api_id}&to={receiver}&text={text}
    * Resolving api.clickatell.com... failed: Unknown host.
    * wget: unable to resolve host address `api.clickatell.com'
    *
    *
    * --2014-06-15 22:44:21--  (try:20)  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={api_id}&to={receiver}&text={text}
    * Connecting to api.clickatell.com|196.216.236.7|:443... failed: Permission denied.
    * Giving up.
    */

   if (__LOG) log("SendSMS(9)  SMS sent to "+ receiver +": \""+ message +"\"");

   return(!catch("SendSMS(10)"));
}


/**
 * Konvertiert die angegebene Serverzeit nach FXT (Forex Time).
 *
 * @param  datetime serverTime - Serverzeit
 *
 * @return datetime - FXT-Zeit oder NaT, falls ein Fehler auftrat
 */
datetime ServerToFxtTime(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
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
datetime ServerToGmtTime(datetime serverTime) { // throws ERR_INVALID_TIMEZONE_CONFIG
   int offset = GetServerToGmtTimeOffset(serverTime);
   if (offset == EMPTY_VALUE)
      return(NaT);
   return(serverTime - offset);
}


/**
 * Prüft, ob die angegebene Datei existiert und eine normale Datei ist (kein Verzeichnis).
 *
 * @return string filename - vollständiger Dateiname
 *
 * @return bool
 */
bool IsFile(string filename) {
   bool result;

   if (StringLen(filename) > 0) {
      /*WIN32_FIND_DATA*/int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA.size);

      int hSearch = FindFirstFileA(filename, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {                         // INVALID_HANDLE_VALUE = nichts gefunden
         result = !wfd_FileAttribute_Directory(wfd);
         FindClose(hSearch);
      }
      ArrayResize(wfd, 0);
   }
   return(result);
}


/**
 * Prüft, ob das angegebene Verzeichnis existiert.
 *
 * @return string filename - vollständiger Verzeichnisname
 *
 * @return bool
 */
bool IsDirectory(string filename) {
   //
   // TODO: !!! Achtung !!!
   //       http://stackoverflow.com/questions/6218325/how-do-you-check-if-a-directory-exists-on-windows-in-c
   //
   //       siehe: If szPath is "C:\\", GetFileAttributes, PathIsDirectory and PathFileExists will not work.
   //              – zwcloud Jun 30 '15 at 7:59
   //
   bool result;

   if (StringLen(filename) > 0) {
      while (StringRight(filename, 1) == "\\") {
         filename = StringLeft(filename, -1);
      }

      /*WIN32_FIND_DATA*/int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA.size);

      int hSearch = FindFirstFileA(filename, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {                         // INVALID_HANDLE_VALUE = nichts gefunden
         result = wfd_FileAttribute_Directory(wfd);
         FindClose(hSearch);
      }
      ArrayResize(wfd, 0);
   }
   return(result);
}


/**
 * Findet alle zum angegebenen Muster passenden Dateinamen. Pseudo-Verzeichnisse ("." und "..") werden nicht berücksichtigt.
 *
 * @param  string pattern     - Namensmuster mit Wildcards nach Windows-Konventionen
 * @param  string lpResults[] - Zeiger auf Array zur Aufnahme der Suchergebnisse
 * @param  int    flags       - zusätzliche Suchflags: [FF_DIRSONLY | FF_FILESONLY | FF_SORT] (default: keine)
 *
 *                              FF_DIRSONLY:  return only directory entries which match the pattern (default: all entries)
 *                              FF_FILESONLY: return only file entries which match the pattern      (default: all entries)
 *                              FF_SORT:      sort returned entries                                 (default: NTFS: sorting, FAT: no sorting)
 *
 * @return int - Anzahl der gefundenen Einträge oder -1 (EMPTY), falls ein Fehler auftrat
 */
int FindFileNames(string pattern, string &lpResults[], int flags=NULL) {
   if (!StringLen(pattern))
      return(_EMPTY(catch("FindFileNames(1)  illegal parameter pattern = \""+ pattern +"\"", ERR_INVALID_PARAMETER)));

   ArrayResize(lpResults, 0);

   string name;
   /*WIN32_FIND_DATA*/ int wfd[]; InitializeByteBuffer(wfd, WIN32_FIND_DATA.size);
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
 * @return color - Farbe oder -1 (EMPTY), falls ein Fehler auftrat
 *
 * Beispiel: RGB(255, 255, 255) => 0x00FFFFFF (weiß)
 */
color RGB(int red, int green, int blue) {
   if (0 <= red && red <= 255) {
      if (0 <= green && green <= 255) {
         if (0 <= blue && blue <= 255) {
            return(red + green<<8 + blue<<16);
         }
         else catch("RGB(1)  invalid parameter blue = "+ blue, ERR_INVALID_PARAMETER);
      }
      else catch("RGB(2)  invalid parameter green = "+ green, ERR_INVALID_PARAMETER);
   }
   else catch("RGB(3)  invalid parameter red = "+ red, ERR_INVALID_PARAMETER);

   return(EMPTY);
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
int RGBValuesToHSV(int red, int green, int blue, double hsv[]) {
   return(RGBToHSV(RGB(red, green, blue), hsv));
}


/**
 * Konvertiert eine RGB-Farbe in den HSV-Farbraum (Hue-Saturation-Value).
 *
 * @param  color  rgb   - Farbe
 * @param  double hsv[] - Array zur Aufnahme der HSV-Werte
 *
 * @return int - Fehlerstatus
 */
int RGBToHSV(color rgb, double &hsv[]) {
   int red   = rgb       & 0xFF;
   int green = rgb >>  8 & 0xFF;
   int blue  = rgb >> 16 & 0xFF;

   double r=red/255., g=green/255., b=blue/255.;                     // scale to unity (0-1)

   double dMin   = MathMin(r, MathMin(g, b)); int iMin   = Min(red, Min(green, blue));
   double dMax   = MathMax(r, MathMax(g, b)); int iMax   = Max(red, Max(green, blue));
   double dDelta = dMax - dMin;               int iDelta = iMax - iMin;

   double hue, sat, val=dMax;

   if (!iDelta) {
      hue = 0;
      sat = 0;
   }
   else {
      sat = dDelta / dMax;
      double del_R = ((dMax-r)/6 + dDelta/2) / dDelta;
      double del_G = ((dMax-g)/6 + dDelta/2) / dDelta;
      double del_B = ((dMax-b)/6 + dDelta/2) / dDelta;

      if      (red   == iMax) { hue =        del_B - del_G; }
      else if (green == iMax) { hue = 1./3 + del_R - del_B; }
      else if (blue  == iMax) { hue = 2./3 + del_G - del_R; }

      if      (hue < 0) { hue += 1; }
      else if (hue > 1) { hue -= 1; }
   }

   if (ArraySize(hsv) != 3)
      ArrayResize(hsv, 3);

   hsv[0] = hue * 360;
   hsv[1] = sat;
   hsv[2] = val;

   return(catch("RGBToHSV()"));
}


/**
 * Umrechnung einer Farbe aus dem HSV- in den RGB-Farbraum.
 *
 * @param  double hsv - HSV-Farbwerte
 *
 * @return color - Farbe oder -1, falls ein Fehler auftrat
 */
color HSVToRGB(double hsv[3]) {
   if (ArrayDimension(hsv) != 1)
      return(catch("HSVToRGB(1)  illegal parameter hsv = "+ DoublesToStr(hsv, NULL), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(hsv) != 3)
      return(catch("HSVToRGB(2)  illegal parameter hsv = "+ DoublesToStr(hsv, NULL), ERR_INCOMPATIBLE_ARRAYS));

   return(HSVValuesToRGB(hsv[0], hsv[1], hsv[2]));
}


/**
 * Konvertiert drei HSV-Farbwerte in eine RGB-Farbe.
 *
 * @param  double hue        - Farbton    (0.0 - 360.0)
 * @param  double saturation - Sättigung  (0.0 - 1.0)
 * @param  double value      - Helligkeit (0.0 - 1.0)
 *
 * @return color - Farbe oder -1 (EMPTY), falls ein Fehler auftrat
 */
color HSVValuesToRGB(double hue, double saturation, double value) {
   if (hue < 0 || hue > 360)             return(_EMPTY(catch("HSVValuesToRGB(1)  invalid parameter hue = "+ NumberToStr(hue, ".+"), ERR_INVALID_PARAMETER)));
   if (saturation < 0 || saturation > 1) return(_EMPTY(catch("HSVValuesToRGB(2)  invalid parameter saturation = "+ NumberToStr(saturation, ".+"), ERR_INVALID_PARAMETER)));
   if (value < 0 || value > 1)           return(_EMPTY(catch("HSVValuesToRGB(3)  invalid parameter value = "+ NumberToStr(value, ".+"), ERR_INVALID_PARAMETER)));

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

   int r = MathRound(red   * 255);
   int g = MathRound(green * 255);
   int b = MathRound(blue  * 255);

   color rgb = r + g<<8 + b<<16;

   int error = GetLastError();
   if (!error)
      return(rgb);
   return(_EMPTY(catch("HSVValuesToRGB(4)", error)));
}


/**
 * Modifiziert die HSV-Werte einer Farbe.
 *
 * @param  color  rgb            - zu modifizierende Farbe
 * @param  double mod_hue        - Änderung des Farbtons: +/-360.0°
 * @param  double mod_saturation - Änderung der Sättigung in %
 * @param  double mod_value      - Änderung der Helligkeit in %
 *
 * @return color - modifizierte Farbe oder -1 (EMPTY), falls ein Fehler auftrat
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
               double hsv[]; RGBToHSV(rgb, hsv);

               // Farbton anpassen
               if (!EQ(mod_hue, 0)) {
                  hsv[0] += mod_hue;
                  if      (hsv[0] <   0) hsv[0] += 360;
                  else if (hsv[0] > 360) hsv[0] -= 360;
               }

               // Sättigung anpassen
               if (!EQ(mod_saturation, 0)) {
                  hsv[1] = hsv[1] * (1 + mod_saturation/100);
                  if (hsv[1] > 1)
                     hsv[1] = 1;    // mehr als 100% geht nicht
               }

               // Helligkeit anpassen (modifiziert HSV.value *und* HSV.saturation)
               if (!EQ(mod_value, 0)) {

                  // TODO: HSV.sat und HSV.val zu gleichen Teilen ändern

                  hsv[2] = hsv[2] * (1 + mod_value/100);
                  if (hsv[2] > 1)
                     hsv[2] = 1;
               }

               // zurück nach RGB konvertieren
               color result = HSVValuesToRGB(hsv[0], hsv[1], hsv[2]);

               ArrayResize(hsv, 0);

               int error = GetLastError();
               if (IsError(error))
                  return(_EMPTY(catch("Color.ModifyHSV(1)", error)));

               return(result);
            }
            else catch("Color.ModifyHSV(2)  invalid parameter mod_value = "+ NumberToStr(mod_value, ".+"), ERR_INVALID_PARAMETER);
         }
         else catch("Color.ModifyHSV(3)  invalid parameter mod_saturation = "+ NumberToStr(mod_saturation, ".+"), ERR_INVALID_PARAMETER);
      }
      else catch("Color.ModifyHSV(4)  invalid parameter mod_hue = "+ NumberToStr(mod_hue, ".+"), ERR_INVALID_PARAMETER);
   }
   else catch("Color.ModifyHSV(5)  invalid parameter rgb = "+ rgb, ERR_INVALID_PARAMETER);

   return(EMPTY);
}


/**
 * Konvertiert einen Double mit bis zu 16 Nachkommastellen in einen String.
 *
 * @param  double value  - zu konvertierender Wert
 * @param  int    digits - Anzahl von Nachkommastellen
 *
 * @return string
 */
string DoubleToStrEx(double value, int digits) {
   string sValue = value;
   if (StringGetChar(sValue, 3) == '#')                              // "-1.#IND0000" => NaN
      return(sValue);                                                // "-1.#INF0000" => Infinite

   if (digits < 0 || digits > 16)
      return(_EMPTY_STR(catch("DoubleToStrEx()  illegal parameter digits = "+ digits, ERR_INVALID_PARAMETER)));

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


// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //
//                                                                                    //
// MQL Utility Funktionen                                                             //
//                                                                                    //
// @see http://www.forexfactory.com/showthread.php?p=2695655                          //
//                                                                                    //
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * Converts an MT4 datetime value to a formatted string, according to the instructions in the mask.
 *
 * Mask parameters:
 *
 *   y      = 2 digit year
 *   Y      = 4 digit year
 *   m      = 1-2 digit month
 *   M      = 2 digit month
 *   n      = 3 char month name, e.g. Nov    (English)
 *   N      = full month name, e.g. November (English)
 *   o      = 3 char month name, e.g. Mär    (Deutsch)
 *   O      = full month name, e.g. März     (Deutsch)
 *   d      = 1-2 digit day of month
 *   D      = 2 digit day of month
 *   T or t = append 'th' to day of month, e.g. 14th, 23rd, etc.
 *   w      = 3 char weekday name, e.g. Tue    (English)
 *   W      = full weekday name, e.g. Tuesday  (English)
 *   x      = 2 char weekday name, e.g. Di     (Deutsch)
 *   X      = full weekday name, e.g. Dienstag (Deutsch)
 *   h      = 1-2 digit hour (defaults to 24-hour format unless 'a' or 'A' are included)
 *   H      = 2 digit hour (defaults to 24-hour format unless 'a' or 'A' are included)
 *   a      = lowercase am/pm and 12-hour format
 *   A      = uppercase AM/PM and 12-hour format
 *   i      = 1-2 digit minutes in the hour
 *   I      = 2 digit minutes in the hour
 *   s      = 1-2 digit seconds in the minute
 *   S      = 2 digit seconds in the minute
 *
 *   All other characters in the mask are output 'as is'. Reserved characters can be output by preceding
 *   them with an exclamation mark:
 *
 *      e.g. DateTimeToStr(StrToTime("2010.07.30"), "(!D=DT N)")  =>  "(D=30th July)"
 *
 * @param  datetime time
 * @param  string   mask - default: TIME_FULL
 *
 * @return string - formatierter datetime-Wert oder Leerstring, falls ein Fehler auftrat
 */
string DateTimeToStr(datetime time, string mask) {
   if (time < 0) return(_EMPTY_STR(catch("DateTimeToStr(1)  invalid parameter time = "+ time +" (not a time)", ERR_INVALID_PARAMETER)));
   if (!StringLen(mask))
      return(TimeToStr(time, TIME_FULL));                            // mit leerer Maske wird das MQL-Standardformat verwendet

   string months_en[12] = {"","January","February","March","April","May","June","July","August","September","October","November","December"};
   string months_de[12] = {"","Januar" ,"Februar" ,"März" ,"April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"};
   string wdays_en [ 7] = {"Sunday" ,"Monday","Tuesday" ,"Wednesday","Thursday"  ,"Friday" ,"Saturday" };
   string wdays_de [ 7] = {"Sonntag","Montag","Dienstag","Mittwoch" ,"Donnerstag","Freitag","Sonnabend"};

   int dd  = TimeDayFix      (time);
   int mm  = TimeMonth       (time);
   int yy  = TimeYearFix     (time);
   int dw  = TimeDayOfWeekFix(time);
   int hr  = TimeHour        (time);
   int min = TimeMinute      (time);
   int sec = TimeSeconds     (time);

   bool h12f = StringFind(StringToUpper(mask), "A") >= 0;

   int h12 = 12;
   if      (hr > 12) h12 = hr - 12;
   else if (hr >  0) h12 = hr;

   if (hr <= 12) string ampm = "am";
   else                 ampm = "pm";

   switch (MathMod(dd, 10)) {
      case 1: string d10 = "st"; break;
      case 2:        d10 = "nd"; break;
      case 3:        d10 = "rd"; break;
      default:       d10 = "th";
   }
   if (dd > 10) /*&&*/ if (dd < 14)
      d10 = "th";

   string result = "";

   for (int i=0; i < StringLen(mask); i++) {
      string char = StringSubstr(mask, i, 1);
      if (char == "!") {
         result = result + StringSubstr(mask, i+1, 1);
         i++;
         continue;
      }
      if      (char == "d")                result = result +                    dd;
      else if (char == "D")                result = result + StringRight("0"+   dd, 2);
      else if (char == "m")                result = result +                    mm;
      else if (char == "M")                result = result + StringRight("0"+   mm, 2);
      else if (char == "y")                result = result + StringRight("0"+   yy, 2);
      else if (char == "Y")                result = result + StringRight("000"+ yy, 4);
      else if (char == "n")                result = result + StringSubstr(months_en[mm], 0, 3);
      else if (char == "N")                result = result +              months_en[mm];
      else if (char == "w")                result = result + StringSubstr(wdays_en [dw], 0, 3);
      else if (char == "W")                result = result +              wdays_en [dw];
      else if (char == "o")                result = result + StringSubstr(months_de[mm], 0, 3);
      else if (char == "O")                result = result +              months_de[mm];
      else if (char == "x")                result = result + StringSubstr(wdays_de [dw], 0, 2);
      else if (char == "X")                result = result +              wdays_de [dw];
      else if (char == "h") {
         if (h12f)                         result = result +                    h12;
         else                              result = result +                    hr; }
      else if (char == "H") {
         if (h12f)                         result = result + StringRight("0"+   h12, 2);
         else                              result = result + StringRight("0"+   hr, 2);
      }
      else if (char == "i")                result = result +                    min;
      else if (char == "I")                result = result + StringRight("0"+   min, 2);
      else if (char == "s")                result = result +                    sec;
      else if (char == "S")                result = result + StringRight("0"+   sec, 2);
      else if (char == "a")                result = result + ampm;
      else if (char == "A")                result = result + StringToUpper(ampm);
      else if (char == "t" || char == "T") result = result + d10;
      else                                 result = result + char;
   }
   return(result);
}


/**
 * TODO: Es werden noch keine Limit- und TakeProfit-Orders unterstützt.
 *
 * Erweiterte Version von OrderSend().
 *
 * @param  string   symbol      - Symbol des Instruments (default: aktuelles Instrument)
 * @param  int      type        - Operation type: [OP_BUY|OP_SELL|OP_BUYLIMIT|OP_SELLLIMIT|OP_BUYSTOP|OP_SELLSTOP]
 * @param  double   lots        - Transaktionsvolumen in Lots
 * @param  double   price       - Preis (nur bei Pending-Orders)
 * @param  double   slippage    - akzeptable Slippage in Pip
 * @param  double   stopLoss    - StopLoss-Level
 * @param  double   takeProfit  - TakeProfit-Level
 * @param  string   comment     - Orderkommentar (max. 27 Zeichen)
 * @param  int      magicNumber - MagicNumber
 * @param  datetime expires     - Gültigkeit der Order
 * @param  color    markerColor - Farbe des Chartmarkers
 * @param  int      oeFlags     - die Ausführung steuernde Flags
 * @param  int      oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return int - Ticket oder -1 (EMPTY), falls ein Fehler auftrat
 */
int OrderSendEx(string symbol/*=NULL*/, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]) {
   // -- Beginn Parametervalidierung --
   // symbol
   if (symbol == "0")      // (string) NULL
      symbol = Symbol();
   int    digits         = MarketInfo(symbol, MODE_DIGITS);
   double minLot         = MarketInfo(symbol, MODE_MINLOT);
   double maxLot         = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep        = MarketInfo(symbol, MODE_LOTSTEP);

   int    pipDigits      = digits & (~1);
   int    pipPoints      = MathRound(MathPow(10, digits & 1));
   double pip            = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits), pips=pip;
   int    slippagePoints = MathRound(slippage * pipPoints);
   double stopDistance   = MarketInfo(symbol, MODE_STOPLEVEL  )/pipPoints;
   double freezeDistance = MarketInfo(symbol, MODE_FREEZELEVEL)/pipPoints;
   string priceFormat    = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   int error = GetLastError();
   if (IsError(error))                                         return(_EMPTY(oe.setError(oe, catch("OrderSendEx(1)  symbol=\""+ symbol +"\"", error))));
   // type
   if (!IsTradeOperation(type))                                return(_EMPTY(oe.setError(oe, catch("OrderSendEx(2)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER))));
   // lots
   if (LT(lots, minLot))                                       return(_EMPTY(oe.setError(oe, catch("OrderSendEx(3)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME))));
   if (GT(lots, maxLot))                                       return(_EMPTY(oe.setError(oe, catch("OrderSendEx(4)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME))));
   if (MathModFix(lots, lotStep) != 0)                         return(_EMPTY(oe.setError(oe, catch("OrderSendEx(5)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_TRADE_VOLUME))));
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0))                                           return(_EMPTY(oe.setError(oe, catch("OrderSendEx(6)  illegal parameter price = "+ NumberToStr(price, priceFormat), ERR_INVALID_PARAMETER))));
   if (IsPendingTradeOperation(type)) /*&&*/ if (EQ(price, 0)) return(_EMPTY(oe.setError(oe, catch("OrderSendEx(7)  illegal "+ OperationTypeDescription(type) +" price = "+ NumberToStr(price, priceFormat), ERR_INVALID_PARAMETER))));
   price = NormalizeDouble(price, digits);
   // slippage
   if (LT(slippage, 0))                                        return(_EMPTY(oe.setError(oe, catch("OrderSendEx(8)  illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_PARAMETER))));
   // stopLoss
   if (LT(stopLoss, 0))                                        return(_EMPTY(oe.setError(oe, catch("OrderSendEx(9)  illegal parameter stopLoss = "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_PARAMETER))));
   stopLoss = NormalizeDouble(stopLoss, digits);               // StopDistance-Validierung erfolgt später
   // takeProfit
   if (!EQ(takeProfit, 0))                                     return(_EMPTY(oe.setError(oe, catch("OrderSendEx(10)  submission of take-profit orders not yet implemented", ERR_INVALID_PARAMETER))));
   takeProfit = NormalizeDouble(takeProfit, digits);           // StopDistance-Validierung erfolgt später
   // comment
   if (comment == "0")     // (string) NULL
      comment = "";
   else if (StringLen(comment) > 27)                           return(_EMPTY(oe.setError(oe, catch("OrderSendEx(11)  illegal parameter comment = \""+ comment +"\" (max. 27 chars)", ERR_INVALID_PARAMETER))));
   // expires
   if (expires != 0) /*&&*/ if (expires <= TimeCurrentEx("OrderSendEx(12)")) return(_EMPTY(oe.setError(oe, catch("OrderSendEx(13)  illegal parameter expires = "+ ifString(expires<0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_PARAMETER))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_EMPTY(oe.setError(oe, catch("OrderSendEx(14)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER))));
   // -- Ende Parametervalidierung --

   // oe initialisieren
   ArrayInitialize(oe, 0);
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

   int ticket, firstTime1=GetTickCount(), time1, requotes, tempErrors;


   // Schleife, bis Order ausgeführt wurde oder ein permanenter Fehler auftritt
   while (true) {
      if (IsStopped()) return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(15)  ", __OrderSendEx.PermErrorMsg(oe)), ERS_EXECUTION_STOPPING, false, oeFlags, oe)));

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderSendEx(16)  trade context busy, retrying...");
         Sleep(300);                                                             // 0.3 Sekunden warten
         continue;
      }

      // OpenPrice <> StopDistance validieren
      double bid = MarketInfo(symbol, MODE_BID);
      double ask = MarketInfo(symbol, MODE_ASK);
      if (!time1) {
         oe.setBid(oe, bid);
         oe.setAsk(oe, ask);
      }
      if      (type == OP_BUY ) price = ask;
      else if (type == OP_SELL) price = bid;
      price = NormalizeDouble(price, digits);
      oe.setOpenPrice(oe, price);

      if (type == OP_BUYSTOP) {
         if (LE(price, ask))                                  return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(17)  illegal price ", NumberToStr(price, priceFormat), " for ", OperationTypeDescription(type), " (market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ")"), ERR_INVALID_STOP, false, oeFlags, oe)));
         if (LT(price - stopDistance*pips, ask))              return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(18)  ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat), " too close to market (", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ", stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
      }
      else if (type == OP_SELLSTOP) {
         if (GE(price, bid))                                  return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(19)  illegal price ", NumberToStr(price, priceFormat), " for ", OperationTypeDescription(type), " (market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ")"), ERR_INVALID_STOP, false, oeFlags, oe)));
         if (GT(price + stopDistance*pips, bid))              return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(20)  ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat), " too close to market (", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ", stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
      }

      // StopLoss <> StopDistance validieren
      if (!EQ(stopLoss, 0)) {
         if (IsLongTradeOperation(type)) {
            if (GE(stopLoss, price))                          return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(21)  illegal stoploss ", NumberToStr(stopLoss, priceFormat), " for ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat)), ERR_INVALID_STOP, false, oeFlags, oe)));
            if (type == OP_BUY) {
               if (GE(stopLoss, bid))                         return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(22)  illegal stoploss ", NumberToStr(stopLoss, priceFormat), " for ", OperationTypeDescription(type), " at market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat)), ERR_INVALID_STOP, false, oeFlags, oe)));
               if (GT(stopLoss, bid - stopDistance*pips))     return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(23)  ", OperationTypeDescription(type), " at market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ", sl=", NumberToStr(stopLoss, priceFormat), " too close (stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
            }
            else if (GT(stopLoss, price - stopDistance*pips)) return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(24)  ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat), ", sl=", NumberToStr(stopLoss, priceFormat), " too close (stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
         }
         else /*short*/ {
            if (LE(stopLoss, price))                          return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(25)  illegal stoploss ", NumberToStr(stopLoss, priceFormat), " for ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat)), ERR_INVALID_STOP, false, oeFlags, oe)));
            if (type == OP_SELL) {
               if (LE(stopLoss, ask))                         return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(26)  illegal stoploss ", NumberToStr(stopLoss, priceFormat), " for ", OperationTypeDescription(type), " at market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat)), ERR_INVALID_STOP, false, oeFlags, oe)));
               if (LT(stopLoss, ask + stopDistance*pips))     return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(27)  ", OperationTypeDescription(type), " at market ", NumberToStr(bid, priceFormat), "/", NumberToStr(ask, priceFormat), ", sl=", NumberToStr(stopLoss, priceFormat), " too close (stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
            }
            else if (LT(stopLoss, price + stopDistance*pips)) return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(28)  ", OperationTypeDescription(type), " at ", NumberToStr(price, priceFormat), ", sl=", NumberToStr(stopLoss, priceFormat), " too close (stop distance=", NumberToStr(stopDistance, ".+"), " pip)"), ERR_INVALID_STOP, false, oeFlags, oe)));
         }
      }

      // TODO: TakeProfit <> StopDistance validieren

      time1  = GetTickCount();
      ticket = OrderSend(symbol, type, lots, price, slippagePoints, stopLoss, takeProfit, comment, magicNumber, expires, markerColor);

      oe.setDuration(oe, GetTickCount()-firstTime1);                             // Gesamtzeit in Millisekunden

      if (ticket > 0) {
         OrderPush("OrderSendEx(29)");
         WaitForTicket(ticket, false);                                           // FALSE wartet und selektiert

         if (!ChartMarker.OrderSent_A(ticket, digits, markerColor))
            return(_EMPTY(oe.setError(oe, last_error), OrderPop("OrderSendEx(30)")));

         oe.setTicket    (oe, ticket           );
         oe.setOpenTime  (oe, OrderOpenTime()  );
         oe.setOpenPrice (oe, OrderOpenPrice() );
         oe.setStopLoss  (oe, OrderStopLoss()  );
         oe.setTakeProfit(oe, OrderTakeProfit());
         oe.setSwap      (oe, OrderSwap()      );
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, 0                );                                // 0, egal was der Server meldet
         oe.setRequotes  (oe, requotes         );
            if      (OrderType() == OP_BUY ) slippage = OrderOpenPrice() - ask;
            else if (OrderType() == OP_SELL) slippage = bid - OrderOpenPrice();
            else                             slippage = 0;
         oe.setSlippage  (oe, NormalizeDouble(slippage/pips, digits & 1));   // Gesamtslippage nach Requotes in Pip

         if (__LOG) log(StringConcatenate("OrderSendEx(31)  ", __OrderSendEx.SuccessMsg(oe)));
         if (!IsTesting())
            PlaySoundEx(ifString(requotes, "OrderRequote.wav", "OrderOk.wav"));

         if (IsError(catch("OrderSendEx(32)", NULL, O_POP)))
            ticket = -1;
         oe.setError(oe, last_error);
         return(ticket);                                                         // regular exit
      }

      error = GetLastError();
      oe.setError     (oe, error     );
      oe.setOpenPrice (oe, price     );                                          // Soll-Daten für Error-Messages
      oe.setStopLoss  (oe, stopLoss  );
      oe.setTakeProfit(oe, takeProfit);

      if (error == ERR_TRADE_CONTEXT_BUSY) {
         if (__LOG) log("OrderSendEx(33)  trade context busy, retrying...");
         Sleep(300);                                                             // 0.3 Sekunden warten
         continue;
      }
      if (error == ERR_REQUOTE) {
         requotes++;
         oe.setRequotes(oe, requotes);
         if (IsTesting())
            break;
         if (requotes > 5)
            break;
         continue;                                                               // nach ERR_REQUOTE Order sofort wiederholen
      }
      if (!error)
         error = oe.setError(oe, ERR_RUNTIME_ERROR);
      if (!IsTemporaryTradeError(error))                                         // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
         break;
      tempErrors++;
      if (tempErrors > 5)
         break;
      warn(StringConcatenate("OrderSendEx(34)  ", __OrderSendEx.TempErrorMsg(oe, tempErrors)), error);
   }
   return(_EMPTY(__Order.HandleError(StringConcatenate("OrderSendEx(35)  ", __OrderSendEx.PermErrorMsg(oe)), error, true, oeFlags, oe)));
}


/**
 * "Exception"-Handler für in einer der Orderfunktionen aufgetretene Fehler. Je nach Execution-Flags werden "laute" Meldungen für die
 * entsprechenden Laufzeitfehler abgefangen. Die Fehler werden stattdessen leise gesetzt, was das eigene Behandeln und die Fortsetzung
 * des Programms ermöglicht.
 *
 * @param  string message     - Fehlermeldung
 * @param  int    error       - der aufgetretene Fehler
 * @param  bool   serverError - ob der Fehler client- oder server-seitig aufgetreten ist
 * @param  int    oeFlags     - die Ausführung steuernde Flags
 * @param  int    oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return int - derselbe Fehler
 *
 * @access private - Aufruf nur aus einer der Orderfunktionen
 */
int __Order.HandleError(string message, int error, bool serverError, int oeFlags, /*ORDER_EXECUTION*/int oe[]) {
   serverError = serverError!=0;

   oe.setError(oe, error);

   if (!error)
      return(NO_ERROR);

   // (1) bei server-seitigen Preisfehlern aktuelle Preise holen
   if (serverError) {
      switch (error) {
         case ERR_INVALID_PRICE:
         case ERR_PRICE_CHANGED:
         case ERR_REQUOTE      :
         case ERR_OFF_QUOTES   :
         case ERR_INVALID_STOP :
            string symbol = oe.Symbol(oe);
            oe.setBid(oe, MarketInfo(symbol, MODE_BID));
            oe.setAsk(oe, MarketInfo(symbol, MODE_ASK));
      }
   }

   // (2) die angegebenen Laufzeitfehler abfangen
   if (oeFlags & MUTE_ERR_INVALID_STOP && 1) {
      if (error == ERR_INVALID_STOP) {
         if (__LOG) log(message, error);
         return(error);
      }
   }

   // (3) für alle restlichen Fehler Laufzeitfehler auslösen
   return(catch(message, error));
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderSendEx()
 */
string __OrderSendEx.SuccessMsg(/*ORDER_EXECUTION*/int oe[]) {
   // opened #1 Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8 (instead of 1.5522'0), sl=1.5500'0, tp=1.5600'0 after 0.345 s and 1 requote (2.8 pip slippage)

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");
   string strPrice    = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string strSlippage = "";
      double slippage = oe.Slippage(oe);
      if (!EQ(slippage, 0)) { strPrice    = StringConcatenate(strPrice, " (instead of ", NumberToStr(ifDouble(oe.Type(oe)==OP_SELL, oe.Bid(oe), oe.Ask(oe)), priceFormat), ")");
         if (slippage > 0)    strSlippage = StringConcatenate(" (", DoubleToStr( slippage, digits & 1), " pip slippage)");
         else                 strSlippage = StringConcatenate(" (", DoubleToStr(-slippage, digits & 1), " pip positive slippage)");
      }
   string message = StringConcatenate("opened #", oe.Ticket(oe), " ", strType, " ", strLots, " ", oe.Symbol(oe), strComment , " at ", strPrice);
   if (!EQ(oe.StopLoss  (oe), 0)) message = StringConcatenate(message, ", sl=", NumberToStr(oe.StopLoss  (oe), priceFormat));
   if (!EQ(oe.TakeProfit(oe), 0)) message = StringConcatenate(message, ", tp=", NumberToStr(oe.TakeProfit(oe), priceFormat));
                                  message = StringConcatenate(message, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s");
   int requotes = oe.Requotes(oe);
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }
   return(StringConcatenate(message, strSlippage));
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[]   - Ausführungsdetails (ORDER_EXECUTION)
 * @param  int errors - Anzahl der bisher aufgetretenen temporären Fehler
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderSendEx()
 */
string __OrderSendEx.TempErrorMsg(/*ORDER_EXECUTION*/int oe[], int errors) {
   if (oe.Error(oe) != ERR_OFF_QUOTES)
      return(__Order.TempErrorMsg(oe, errors));

   // temporary error while trying to Buy 0.5 GBPUSD at 1.5524'8 (market Bid/Ask) after 0.345 s and 1 requote, retrying... (1)

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string strPrice    = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string strBid      = NumberToStr(MarketInfo(symbol, MODE_BID), priceFormat);
   string strAsk      = NumberToStr(MarketInfo(symbol, MODE_ASK), priceFormat);

   string message = StringConcatenate("temporary error while trying to ", strType, " ", strLots, " ", oe.Symbol(oe), " at ", strPrice, " (market ", strBid, "/", strAsk, ") after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s");

   int requotes = oe.Requotes(oe);
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }
   return(StringConcatenate(message, ", retrying... ("+ errors +")"));
}


/**
 * Logmessage für OrderSendEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderSendEx()
 */
string __OrderSendEx.PermErrorMsg(/*ORDER_EXECUTION*/int oe[]) {
   // permanent error while trying to Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8 (market Bid/Ask), sl=1.5500'0, tp=1.5600'0 after 0.345 s and 1 requote

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots     (oe), ".+"       );
   string symbol      = oe.Symbol(oe);
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");
   string strPrice    = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string strBid      = NumberToStr(MarketInfo(symbol, MODE_BID), priceFormat);
   string strAsk      = NumberToStr(MarketInfo(symbol, MODE_ASK), priceFormat);

   string message = StringConcatenate("permanent error while trying to ", strType, " ", strLots, " ", symbol, strComment, " at ", strPrice, " (market ", strBid, "/", strAsk, ")");

   if (!EQ(oe.StopLoss  (oe), 0))        message = StringConcatenate(message, ", sl=", NumberToStr(oe.StopLoss  (oe), priceFormat));
   if (!EQ(oe.TakeProfit(oe), 0))        message = StringConcatenate(message, ", tp=", NumberToStr(oe.TakeProfit(oe), priceFormat));
   if (oe.Error(oe) == ERR_INVALID_STOP) message = StringConcatenate(message, ", stop distance=", NumberToStr(oe.StopDistance(oe), ".+"), " pip");
                                         message = StringConcatenate(message, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s");

   int requotes = oe.Requotes(oe);
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }
   return(message);
}


/**
 * Logmessage für allgemeine temporäre Trade-Fehler.
 *
 * @param  int oe[]   - Ausführungsdetails (ORDER_EXECUTION)
 * @param  int errors - Anzahl der bisher aufgetretenen temporären Fehler
 *
 * @return string
 *
 * @access private - Aufruf nur aus einer der Orderfunktionen
 */
string __Order.TempErrorMsg(/*ORDER_EXECUTION*/int oe[], int errors) {
   // temporary error after 0.345 s and 1 requote, retrying...

   string message = StringConcatenate("temporary error after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s");

   int requotes = oe.Requotes(oe);
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }
   return(StringConcatenate(message, ", retrying... ("+ errors +")"));
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
   if (!__CHART) return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderSent_A(1)", O_PUSH))
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
   if (!__CHART) return(true);

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
   if (!EQ(stopLoss, 0)) {
      string label2 = StringConcatenate(label1, " stop loss at ", DoubleToStr(stopLoss, digits));
      if (ObjectFind(label2) == 0)
         ObjectDelete(label2);
   }

   // TakeProfit-Marker: immer löschen                                                 // "#1 buy[ stop] 0.10 GBPUSD at 1.52904 take profit at 1.58000"
   if (!EQ(takeProfit, 0)) {
      string label3 = StringConcatenate(label1, " take profit at ", DoubleToStr(takeProfit, digits));
      if (ObjectFind(label3) == 0)
         ObjectDelete(label3);
   }

   return(!catch("ChartMarker.OrderSent_B()"));
}


/**
 * Erweiterte Version von OrderModify().
 *
 * @param  int      ticket      - zu änderndes Ticket
 * @param  double   openPrice   - OpenPrice (nur bei Pending-Orders)
 * @param  double   stopLoss    - StopLoss-Level
 * @param  double   takeProfit  - TakeProfit-Level
 * @param  datetime expires     - Gültigkeit (nur bei Pending-Orders)
 * @param  color    markerColor - Farbe des Chart-Markers
 * @param  int      oeFlags     - die Ausführung steuernde Flags
 * @param  int      oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return bool - Erfolgsstatus
 */
bool OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!SelectTicket(ticket, "OrderModifyEx(1)", O_PUSH))      return(_false(oe.setError(oe, last_error)));
   if (!IsTradeOperation(OrderType()))                         return(_false(oe.setError(oe, catch("OrderModifyEx(2)  #"+ ticket +" is not an order ticket", ERR_INVALID_TICKET, O_POP))));
   if (OrderCloseTime() != 0)                                  return(_false(oe.setError(oe, catch("OrderModifyEx(3)  #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP))));
   int    digits         = MarketInfo(OrderSymbol(), MODE_DIGITS);
   int    pipDigits      = digits & (~1);
   int    pipPoints      = MathRound(MathPow(10, digits & 1));
   double stopDistance   = MarketInfo(OrderSymbol(), MODE_STOPLEVEL  )/pipPoints;
   double freezeDistance = MarketInfo(OrderSymbol(), MODE_FREEZELEVEL)/pipPoints;
   string priceFormat    = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   int error = GetLastError();
   if (IsError(error))                                         return(_false(oe.setError(oe, catch("OrderModifyEx(4)  symbol=\""+ OrderSymbol() +"\"", error, O_POP))));
   // openPrice
   openPrice = NormalizeDouble(openPrice, digits);
   if (LE(openPrice, 0))                                       return(_false(oe.setError(oe, catch("OrderModifyEx(5)  illegal parameter openPrice = "+ NumberToStr(openPrice, priceFormat), ERR_INVALID_PARAMETER, O_POP))));
   if (!EQ(openPrice, OrderOpenPrice())) {
      if (!IsPendingTradeOperation(OrderType()))               return(_false(oe.setError(oe, catch("OrderModifyEx(6)  cannot modify open price of already open position #"+ ticket, ERR_INVALID_PARAMETER, O_POP))));
      // TODO: Bid/Ask <=> openPrice prüfen
      // TODO: StopDistance(openPrice) prüfen
   }
   // stopLoss
   stopLoss = NormalizeDouble(stopLoss, digits);
   if (LT(stopLoss, 0))                                        return(_false(oe.setError(oe, catch("OrderModifyEx(7)  illegal parameter stopLoss = "+ NumberToStr(stopLoss, priceFormat), ERR_INVALID_PARAMETER, O_POP))));
   if (!EQ(stopLoss, OrderStopLoss())) {
      // TODO: Bid/Ask <=> stopLoss prüfen
      // TODO: StopDistance(stopLoss) prüfen
   }
   // takeProfit
   takeProfit = NormalizeDouble(takeProfit, digits);
   if (LT(takeProfit, 0))                                      return(_false(oe.setError(oe, catch("OrderModifyEx(8)  illegal parameter takeProfit = "+ NumberToStr(takeProfit, priceFormat), ERR_INVALID_PARAMETER, O_POP))));
   if (!EQ(takeProfit, OrderTakeProfit())) {
      // TODO: Bid/Ask <=> takeProfit prüfen
      // TODO: StopDistance(takeProfit) prüfen
   }
   // expires
   if (expires!=0) /*&&*/ if (expires <= TimeCurrentEx("OrderModifyEx(8.1)")) return(_false(oe.setError(oe, catch("OrderModifyEx(9)  illegal parameter expires = "+ ifString(expires < 0, expires, TimeToStr(expires, TIME_FULL)), ERR_INVALID_PARAMETER, O_POP))));
   if (expires != OrderExpiration())
      if (!IsPendingTradeOperation(OrderType()))               return(_false(oe.setError(oe, catch("OrderModifyEx(10)  cannot modify expiration of already open position #"+ ticket, ERR_INVALID_PARAMETER, O_POP))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(oe.setError(oe, catch("OrderModifyEx(11)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, O_POP))));
   // -- Ende Parametervalidierung --

   // oe initialisieren
   ArrayInitialize(oe, 0);
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

   double origOpenPrice=OrderOpenPrice(), origStopLoss=OrderStopLoss(), origTakeProfit=OrderTakeProfit();

   if (EQ(openPrice, origOpenPrice)) /*&&*/ if (EQ(stopLoss, origStopLoss)) /*&&*/ if (EQ(takeProfit, origTakeProfit)) {
      warn(StringConcatenate("OrderModifyEx(12)  nothing to modify for #", ticket));
      return(!oe.setError(oe, catch("OrderModifyEx(13)", NULL, O_POP)));
   }

   int  tempErrors, startTime=GetTickCount();
   bool success;


   // Schleife, bis Order geändert wurde oder ein permanenter Fehler auftritt
   while (true) {
      if (IsStopped()) return(_false(__Order.HandleError(StringConcatenate("OrderModifyEx(14)  ", __OrderModifyEx.PermErrorMsg(oe, origOpenPrice, origStopLoss, origTakeProfit)), ERS_EXECUTION_STOPPING, false, oeFlags, oe), OrderPop("OrderModifyEx(15)")));

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderModifyEx(16)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      success = OrderModify(ticket, openPrice, stopLoss, takeProfit, expires, markerColor);

      oe.setDuration(oe, GetTickCount()-startTime);                                    // Gesamtzeit in Millisekunden

      if (success) {
         WaitForTicket(ticket, false);                                                 // FALSE wartet und selektiert
         // TODO: WaitForChanges() implementieren

         if (!ChartMarker.OrderModified_A(ticket, digits, markerColor, TimeCurrentEx("OrderModifyEx(16.1)"), origOpenPrice, origStopLoss, origTakeProfit))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderModifyEx(17)")));

         oe.setOpenTime  (oe, OrderOpenTime()  );
         oe.setOpenPrice (oe, OrderOpenPrice() );
         oe.setStopLoss  (oe, OrderStopLoss()  );
         oe.setTakeProfit(oe, OrderTakeProfit());
         oe.setSwap      (oe, OrderSwap()      );
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, OrderProfit()    );

         if (__LOG) log(StringConcatenate("OrderModifyEx(18)  ", __OrderModifyEx.SuccessMsg(oe, origOpenPrice, origStopLoss, origTakeProfit)));
         if (!IsTesting())
            PlaySoundEx("OrderModified.wav");

         return(!oe.setError(oe, catch("OrderModifyEx(19)", NULL, O_POP)));            // regular exit
      }

      error = oe.setError(oe, GetLastError());
      if (error == ERR_TRADE_CONTEXT_BUSY) {
         if (__LOG) log("OrderModifyEx(20)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }
      if (!error)
         error = oe.setError(oe, ERR_RUNTIME_ERROR);
      if (!IsTemporaryTradeError(error))                                               // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
         break;
      tempErrors++;
      if (tempErrors > 5)
         break;
      warn(StringConcatenate("OrderModifyEx(21)  ", __Order.TempErrorMsg(oe, tempErrors)), error);
   }
   return(!catch(StringConcatenate("OrderModifyEx(22)  ", __OrderModifyEx.PermErrorMsg(oe, origOpenPrice, origStopLoss, origTakeProfit)), error, O_POP));
}


/**
 * Logmessage für OrderModifyEx().
 *
 * @param  int    oe[]           - Ausführungsdetails (ORDER_EXECUTION)
 * @param  double origOpenPrice  - ursprünglicher OpenPrice
 * @param  double origStopLoss   - ursprünglicher StopLoss
 * @param  double origTakeProfit - ursprünglicher TakeProfit
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderModifyEx()
 */
string __OrderModifyEx.SuccessMsg(/*ORDER_EXECUTION*/int oe[], double origOpenPrice, double origStopLoss, double origTakeProfit) {
   // modified #1 Stop Buy 0.1 GBPUSD "SR.12345.+2" at 1.5500'0[ =>1.5520'0][, sl: 1.5450'0 =>1.5455'0][, tp: 1.5520'0 =>1.5530'0] after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");

   double openPrice=oe.OpenPrice(oe), stopLoss=oe.StopLoss(oe), takeProfit=oe.TakeProfit(oe);

   string strPrice = NumberToStr(openPrice, priceFormat);
                 if (!EQ(openPrice,  origOpenPrice) ) strPrice = StringConcatenate(NumberToStr(origOpenPrice, priceFormat), " =>", strPrice);
   string strSL; if (!EQ(stopLoss,   origStopLoss)  ) strSL    = StringConcatenate(", sl: ", NumberToStr(origStopLoss,   priceFormat), " =>", NumberToStr(stopLoss,   priceFormat));
   string strTP; if (!EQ(takeProfit, origTakeProfit)) strTP    = StringConcatenate(", tp: ", NumberToStr(origTakeProfit, priceFormat), " =>", NumberToStr(takeProfit, priceFormat));

   return(StringConcatenate("modified #", oe.Ticket(oe), " ", strType, " ", strLots, " ", oe.Symbol(oe), strComment, " at ", strPrice, strSL, strTP, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Logmessage für OrderModifyEx().
 *
 * @param  int    oe[]           - Ausführungsdetails (ORDER_EXECUTION)
 * @param  double origOpenPrice  - ursprünglicher OpenPrice
 * @param  double origStopLoss   - ursprünglicher StopLoss
 * @param  double origTakeProfit - ursprünglicher TakeProfit
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderModifyEx()
 */
string __OrderModifyEx.PermErrorMsg(/*ORDER_EXECUTION*/int oe[], double origOpenPrice, double origStopLoss, double origTakeProfit) {
   // permanent error while trying to modify #1 Stop Buy 0.5 GBPUSD "SR.12345.+2" at 1.5524'8[ =>1.5520'0][ (market Bid/Ask)][, sl: 1.5450'0 =>1.5455'0][, tp: 1.5520'0 =>1.5530'0][, stop distance=5 pip] after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots     (oe), ".+");
   string symbol      = oe.Symbol(oe);
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");

   double openPrice=oe.OpenPrice(oe), stopLoss=oe.StopLoss(oe), takeProfit=oe.TakeProfit(oe);

   string strPrice = NumberToStr(openPrice, priceFormat);
                 if (!EQ(openPrice,  origOpenPrice) ) strPrice = StringConcatenate(NumberToStr(origOpenPrice, priceFormat), " =>", strPrice);
   string strSL; if (!EQ(stopLoss,   origStopLoss)  ) strSL    = StringConcatenate(", sl: ", NumberToStr(origStopLoss,   priceFormat), " =>", NumberToStr(stopLoss,   priceFormat));
   string strTP; if (!EQ(takeProfit, origTakeProfit)) strTP    = StringConcatenate(", tp: ", NumberToStr(origTakeProfit, priceFormat), " =>", NumberToStr(takeProfit, priceFormat));

   string strSD; if (oe.Error(oe) == ERR_INVALID_STOP) {
      strSD    = StringConcatenate(", stop distance=", NumberToStr(oe.StopDistance(oe), ".+"), " pip");
      strPrice = StringConcatenate(strPrice, " (market "+ NumberToStr(MarketInfo(symbol, MODE_BID), priceFormat) +"/"+ NumberToStr(MarketInfo(symbol, MODE_ASK), priceFormat) +")");
   }

   return(StringConcatenate("permanent error while trying to modify #", oe.Ticket(oe), " ", strType, " ", strLots, " ", symbol, strComment, " at ", strPrice, strSL, strTP, strSD, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
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
   if (!__CHART)
      return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderModified_A(1)", O_PUSH))
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
   if (!__CHART) return(true);

   bool openModified = !EQ(openPrice,  oldOpenPrice );
   bool slModified   = !EQ(stopLoss,   oldStopLoss  );
   bool tpModified   = !EQ(takeProfit, oldTakeProfit);

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
   if (!EQ(oldStopLoss, 0)) {
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
   if (!EQ(oldTakeProfit, 0)) {
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
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderFilled_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor) {
   if (!__CHART)
      return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderFilled_A(1)", O_PUSH))
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
   if (!__CHART) return(true);

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
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor) {
   if (!__CHART)
      return(true);

   if (!SelectTicket(ticket, "ChartMarker.PositionClosed_A(1)", O_PUSH))
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
   if (!__CHART) return(true);

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
 * @return bool - Erfolgsstatus
 *
 * @see ChartMarker.OrderDeleted_B(), wenn das Ticket während der Ausführung nicht selektierbar ist
 */
bool ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor) {
   if (!__CHART)
      return(true);

   if (!SelectTicket(ticket, "ChartMarker.OrderDeleted_A(1)", O_PUSH))
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
   if (!__CHART) return(true);

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

   return(!catch("ChartMarker.OrderDeleted_B()"));
}


/**
 * Erweiterte Version von OrderClose().
 *
 * @param  int    ticket      - Ticket der zu schließenden Position
 * @param  double lots        - zu schließendes Volumen in Lots (default: komplette Position)
 * @param  double price       - Preis (wird zur Zeit ignoriert)
 * @param  double slippage    - akzeptable Slippage in Pip
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    oeFlags     - die Ausführung steuernde Flags
 * @param  int    oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Die vom MT4-Server berechneten Werte in oe.Swap, oe.Commission und oe.Profit können bei partiellem Close vom theoretischen Wert abweichen.
 */
bool OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, int oeFlags, int oe[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!SelectTicket(ticket, "OrderCloseEx(1)", O_PUSH))       return(_false(oe.setError(oe, last_error)));
   if (OrderCloseTime() != 0)                                  return(_false(oe.setError(oe, catch("OrderCloseEx(2)  #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP))));
   if (OrderType() > OP_SELL)                                  return(_false(oe.setError(oe, catch("OrderCloseEx(3)  #"+ ticket +" is not an open position", ERR_INVALID_TICKET, O_POP))));
   // lots
   int    digits   = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double minLot   = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep  = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   double openLots = OrderLots();
   int error = GetLastError();
   if (IsError(error))                                         return(_false(oe.setError(oe, catch("OrderCloseEx(4)  symbol=\""+ OrderSymbol() +"\"", error, O_POP))));
   if (EQ(lots, 0)) {
      lots = openLots;
   }
   else if (!EQ(lots, openLots)) {
      if (LT(lots, minLot))                                    return(_false(oe.setError(oe, catch("OrderCloseEx(5)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_PARAMETER, O_POP))));
      if (GT(lots, openLots))                                  return(_false(oe.setError(oe, catch("OrderCloseEx(6)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (open lots="+ NumberToStr(openLots, ".+") +")", ERR_INVALID_PARAMETER, O_POP))));
      if (MathModFix(lots, lotStep) != 0)                      return(_false(oe.setError(oe, catch("OrderCloseEx(7)  illegal parameter lots = "+ NumberToStr(lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_PARAMETER, O_POP))));
   }
   lots = NormalizeDouble(lots, CountDecimals(lotStep));
   // price
   if (LT(price, 0))                                           return(_false(oe.setError(oe, catch("OrderCloseEx(8)  illegal parameter price = "+ NumberToStr(price, ".+"), ERR_INVALID_PARAMETER, O_POP))));
   // slippage
   if (LT(slippage, 0))                                        return(_false(oe.setError(oe, catch("OrderCloseEx(9)  illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_PARAMETER, O_POP))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(oe.setError(oe, catch("OrderCloseEx(10)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, O_POP))));
   // -- Ende Parametervalidierung --

   // oe initialisieren
   ArrayInitialize (oe, 0);
   oe.setSymbol    (oe, OrderSymbol()    );
   oe.setDigits    (oe, digits           );
   oe.setTicket    (oe, ticket           );
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
   int    pipPoints      = MathRound(MathPow(10, digits & 1));
   double pip            = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits), pips=pip;
   int    slippagePoints = MathRound(slippage * pipPoints);
   string priceFormat    = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));

   int    time1, firstTime1=GetTickCount(), requotes, tempErrors, remainder;
   double firstPrice, bid, ask;                                                        // erster OrderPrice (falls ERR_REQUOTE auftritt)
   bool   success;


   // Schleife, bis Position geschlossen wurde oder ein permanenter Fehler auftritt
   while (true) {
      if (IsStopped()) return(_false(__Order.HandleError(StringConcatenate("OrderCloseEx(11)  ", __OrderCloseEx.PermErrorMsg(oe)), ERS_EXECUTION_STOPPING, false, oeFlags, oe), OrderPop("OrderCloseEx(12)")));

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderCloseEx(13)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }

      // zu verwendenden Preis bestimmen
      bid = oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      ask = oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));
      if      (OrderType() == OP_BUY ) price = bid;
      else if (OrderType() == OP_SELL) price = ask;
      price = NormalizeDouble(price, digits);
      if (!time1)
         firstPrice = price;                                                           // OrderPrice der ersten Ausführung merken

      time1   = GetTickCount();
      success = OrderClose(ticket, lots, price, slippagePoints, markerColor);

      oe.setDuration(oe, GetTickCount()-firstTime1);                                   // Gesamtzeit in Millisekunden

      if (success) {
         WaitForTicket(ticket, false);                                                 // FALSE wartet und selektiert

         if (!ChartMarker.PositionClosed_A(ticket, digits, markerColor))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderCloseEx(14)")));

         oe.setCloseTime (oe, OrderCloseTime());
         oe.setClosePrice(oe, OrderClosePrice());
         oe.setSwap      (oe, OrderSwap());
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, OrderProfit());
         oe.setRequotes  (oe, requotes);
            if (OrderType() == OP_BUY ) slippage = oe.Bid(oe) - OrderClosePrice();
            else                        slippage = OrderClosePrice() - oe.Ask(oe);
         oe.setSlippage(oe, NormalizeDouble(slippage/pips, 1));                        // in Pip

         // Restposition finden
         if (!EQ(lots, openLots)) {
            string strValue, strValue2;
            if (IsTesting()) /*&&*/ if (!StringStartsWithI(OrderComment(), "to #")) {  // Fallback zum Serververhalten, falls der Unterschied in späteren Terminalversionen behoben ist.
               // Der Tester überschreibt den OrderComment statt mit "to #2" mit "partial close".
               if (OrderComment() != "partial close")          return(_false(oe.setError(oe, catch("OrderCloseEx(15)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP))));
               strValue  = StringConcatenate("split from #", ticket);
               strValue2 = StringConcatenate(      "from #", ticket);

               OrderPush("OrderCloseEx(16)");
               for (int i=OrdersTotal()-1; i >= 0; i--) {
                  if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                   // FALSE: darf im Tester nicht auftreten
                     catch("OrderCloseEx(17)->OrderSelect(i="+ i +", SELECT_BY_POS, MODE_TRADES)  unexpectedly returned FALSE", ERR_RUNTIME_ERROR);
                     break;
                  }
                  if (OrderTicket() == ticket)         continue;
                  if (OrderComment() != strValue)
                     if (OrderComment() != strValue2)  continue;                       // falls der Unterschied in späteren Terminalversionen behoben ist
                  if (!EQ(lots+OrderLots(), openLots)) continue;

                  remainder = OrderTicket();
                  break;
               }
               OrderPop("OrderCloseEx(18)");
               if (!remainder) {
                  if (IsLastError())                           return(_false(oe.setError(oe, last_error), OrderPop("OrderCloseEx(19)")));
                                                               return(_false(oe.setError(oe, catch("OrderCloseEx(20)  cannot find remaining position of partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots)", ERR_RUNTIME_ERROR, O_POP))));
               }
            }
            if (!remainder) {
               if (!StringStartsWithI(OrderComment(), "to #")) return(_false(oe.setError(oe, catch("OrderCloseEx(21)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP))));
               strValue = StringRight(OrderComment(), -4);
               if (!StringIsDigit(strValue))                   return(_false(oe.setError(oe, catch("OrderCloseEx(22)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP))));
               remainder = StrToInteger(strValue);
               if (!remainder)                                 return(_false(oe.setError(oe, catch("OrderCloseEx(23)  unexpected order comment after partial close of #"+ ticket +" ("+ NumberToStr(lots, ".+") +" of "+ NumberToStr(openLots, ".+") +" lots) = \""+ OrderComment() +"\"", ERR_RUNTIME_ERROR, O_POP))));
            }
            WaitForTicket(remainder, true);
            oe.setRemainingTicket(oe, remainder);
            oe.setRemainingLots  (oe, openLots-lots);
         }

         if (__LOG) log(StringConcatenate("OrderCloseEx(24)  ", __OrderCloseEx.SuccessMsg(oe)));
         if (!IsTesting())
            PlaySoundEx(ifString(requotes, "OrderRequote.wav", "OrderOk.wav"));

         return(!oe.setError(oe, catch("OrderCloseEx(25)", NULL, O_POP)));             // regular exit
      }

      error = GetLastError();
      if (error == ERR_TRADE_CONTEXT_BUSY) {
         if (__LOG) log("OrderCloseEx(26)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }
      if (error == ERR_REQUOTE) {
         requotes++;
         oe.setRequotes(oe, requotes);
         if (IsTesting())
            break;
         if (requotes > 5)
            break;
         continue;                                                                     // nach ERR_REQUOTE Order schnellstmöglich wiederholen
      }
      if (!error)
         error = ERR_RUNTIME_ERROR;
      if (!IsTemporaryTradeError(error))                                               // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
         break;
      tempErrors++;
      if (tempErrors > 5)
         break;
      warn(StringConcatenate("OrderCloseEx(27)  ", __Order.TempErrorMsg(oe, tempErrors)), error);
   }
   return(_false(oe.setError(oe, catch(StringConcatenate("OrderCloseEx(28)  ", __OrderCloseEx.PermErrorMsg(oe)), error, O_POP))));
}


/**
 * Logmessage für OrderCloseEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderCloseEx()
 */
string __OrderCloseEx.SuccessMsg(/*ORDER_EXECUTION*/int oe[]) {
   // closed #1 Buy 0.6 GBPUSD "SR.1234.+2" [partially] at 1.5534'4, remainder: #2 Buy 0.1 GBPUSD after 0.123 s and 1 requote (2.8 pip slippage)

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   double pip         = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string strSymbol   = oe.Symbol(oe);
   string strPrice    = NumberToStr(oe.ClosePrice(oe), priceFormat);
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");
   string strSlippage = "";
      double slippage = oe.Slippage(oe);
      if (!EQ(slippage, 0)) {
         strPrice    = StringConcatenate(strPrice, " (instead of ", NumberToStr(ifDouble(oe.Type(oe)==OP_BUY, oe.Bid(oe), oe.Ask(oe)), priceFormat), ")");
         if (slippage > 0) strSlippage = StringConcatenate(" (", DoubleToStr( slippage, digits & 1), " pip slippage)");
         else              strSlippage = StringConcatenate(" (", DoubleToStr(-slippage, digits & 1), " pip positive slippage)");
      }
   int  remainder = oe.RemainingTicket(oe);
   string message = StringConcatenate("closed #", oe.Ticket(oe), " ", strType, " ", strLots, " ", strSymbol, strComment, ifString(!remainder, "", " partially"), " at ", strPrice);

   if (remainder != 0)
      message = StringConcatenate(message, ", remainder: #", remainder, " ", strType, " ", NumberToStr(oe.RemainingLots(oe), ".+"), " ", strSymbol);

   message = StringConcatenate(message, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s");

   int requotes = oe.Requotes(oe);
   if (requotes > 0) {
      message = StringConcatenate(message, " and ", requotes, " requote");
      if (requotes > 1)
         message = StringConcatenate(message, "s");
   }
   return(StringConcatenate(message, strSlippage));
}


/**
 * Logmessage für OrderCloseEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderCloseEx()
 */
string __OrderCloseEx.PermErrorMsg(/*ORDER_EXECUTION*/int oe[]) {
   // permanent error while trying to close #1 Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8 (market Bid/Ask), sl=1.5500'0, tp=1.5600'0 after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");

   string strPrice = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string strSL; if (!EQ(oe.StopLoss  (oe), 0)) strSL = StringConcatenate(", sl=", NumberToStr(oe.StopLoss  (oe), priceFormat));
   string strTP; if (!EQ(oe.TakeProfit(oe), 0)) strTP = StringConcatenate(", tp=", NumberToStr(oe.TakeProfit(oe), priceFormat));
   string strSD; if (oe.Error(oe) == ERR_INVALID_STOP) {
      strPrice = StringConcatenate(strPrice, " (market ", NumberToStr(MarketInfo(symbol, MODE_BID), priceFormat), "/", NumberToStr(MarketInfo(symbol, MODE_ASK), priceFormat), ")");
      strSD    = StringConcatenate(", stop distance=", NumberToStr(oe.StopDistance(oe), ".+"), " pip");
   }
   return(StringConcatenate("permanent error while trying to close #", oe.Ticket(oe), " ", strType, " ", strLots, " ", symbol, strComment, " at ", strPrice, strSL, strTP, strSD, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Erweiterte Version von OrderCloseBy().
 *
 * @param  int   ticket      - Ticket der zu schließenden Position
 * @param  int   opposite    - Ticket der zum Schließen zu verwendenden Gegenposition
 * @param  color markerColor - Farbe des Chart-Markers
 * @param  int   oeFlags     - die Ausführung steuernde Flags
 * @param  int   oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Die vom MT4-Server berechneten Werte in oe.Swap, oe.Commission und oe.Profit können bei partiellem Close aufgeteilt sein
 *       und vom theoretischen Wert abweichen.
 */
bool OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!SelectTicket(ticket, "OrderCloseByEx(1)", O_PUSH))        return(_false(oe.setError(oe, last_error)));
   if (OrderCloseTime() != 0)                                     return(_false(oe.setError(oe, catch("OrderCloseByEx(2)  #"+ ticket +" is already closed", ERR_INVALID_TICKET, O_POP))));
   if (OrderType() > OP_SELL)                                     return(_false(oe.setError(oe, catch("OrderCloseByEx(3)  #"+ ticket +" is not an open position", ERR_INVALID_TICKET, O_POP))));
   int      ticketType     = OrderType();
   double   ticketLots     = OrderLots();
   datetime ticketOpenTime = OrderOpenTime();
   string   symbol         = OrderSymbol();
   // opposite
   if (!SelectTicket(opposite, "OrderCloseByEx(4)", NULL, O_POP)) return(_false(oe.setError(oe, last_error)));
   if (OrderCloseTime() != 0)                                     return(_false(oe.setError(oe, catch("OrderCloseByEx(5)  opposite #"+ opposite +" is already closed", ERR_INVALID_TICKET, O_POP))));
   int      oppositeType     = OrderType();
   double   oppositeLots     = OrderLots();
   datetime oppositeOpenTime = OrderOpenTime();
   if (ticketType != oppositeType^1)                              return(_false(oe.setError(oe, catch("OrderCloseByEx(6)  #"+ opposite +" is not opposite to #"+ ticket, ERR_INVALID_TICKET, O_POP))));
   if (symbol != OrderSymbol())                                   return(_false(oe.setError(oe, catch("OrderCloseByEx(7)  #"+ opposite +" is not opposite to #"+ ticket, ERR_INVALID_TICKET, O_POP))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')    return(_false(oe.setError(oe, catch("OrderCloseByEx(8)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, O_POP))));
   // -- Ende Parametervalidierung --

   // oe initialisieren
   ArrayInitialize(oe, 0);
   oe.setSymbol   (oe, OrderSymbol());
   oe.setDigits   (oe, MarketInfo(OrderSymbol(), MODE_DIGITS));
   oe.setTicket   (oe, ticket);
   oe.setBid      (oe, MarketInfo(OrderSymbol(), MODE_BID));
   oe.setAsk      (oe, MarketInfo(OrderSymbol(), MODE_ASK));
   oe.setType     (oe, ticketType);
   oe.setLots     (oe, ticketLots);

   /*
   Vollständiges Close
   ===================
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   |           | Ticket | Type | Lots | Symbol |                OpenTime | OpenPrice |           CloseTime | ClosePrice | Commission |  Swap |  Profit | MagicNumber | Comment           |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | open      |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 |                     |   1.3237'4 |      -8.00 | -0.80 |  714.00 |         111 |                   |
   | open      |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 |                     |   1.3239'4 |      -8.00 | -1.50 | -837.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
    #1 by #2:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 1.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.20 20:00:01 |   1.3155'7 |      -8.00 | -2.30 | -103.00 |         111 |                   |
   | closed    |     #2 | Sell | 0.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.20 20:00:01 |   1.3155'7 |       0.00 |  0.00 |    0.00 |         222 | close hedge by #1 | müßte "close hedge for #1" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
    #2 by #1:
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD |     2012.03.19 11:00:05 |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |       0.00 |  0.00 |    0.00 |         111 | close hedge by #2 | müßte "close hedge for #2" lauten
   | closed    |     #2 | Sell | 1.00 | EURUSD |     2012.03.19 14:00:05 |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 |      -8.00 | -2.30 | -103.00 |         222 |                   |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+-------------------+
    - Der ClosePrice des schließenden Tickets (by) wird auf seinen OpenPrice gesetzt (byOpenPrice == byClosePrice), der ClosePrice des zu schließenden Tickets auf byOpenPrice.
    - Swap und Profit des schließenden Tickets (by) werden zum zu schließenden Ticket addiert, bereits berechnete Commission wird erstattet. Die LotSize des schließenden Tickets
      (by) wird auf 0 gesetzt.


   Partielles Close
   ================
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   |           | Ticket | Type | Lots | Symbol |            OpenTime     | OpenPrice |           CloseTime | ClosePrice | Commission |  Swap |  Profit | MagicNumber | Comment/Online             | Comment/Tester < Build 416 | Comment/Tester >= Build 416 |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | open      |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 |                     |   1.3237'4 |      -5.60 | -0.56 |  499.80 |         111 |                            |                            |                             |
   | open      |     #2 | Sell | 1.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 |                     |   1.3239'4 |      -8.00 | -1.50 | -837.00 |         222 |                            |                            |                             |
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+

    #smaller(1) by #larger(2):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.70 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3155'7 |      -5.60 | -2.06 |  -72.10 |         111 | partial close              | partial close              | to #3                       | müßte unverändert sein
   | closed    |     #2 | Sell | 0.00 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3155'7 |       0.00 |  0.00 |    0.00 |         222 | close hedge by #1          | close hedge by #1          | close hedge by #1           | müßte "partial close/close hedge for #1" lauten
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 20:00:01 (1) |  1.3155'7 |                     |   1.3239'4 |      -2.40 |  0.00 | -251.00 |         222 | from #1                    | split from #1              | from #1                     | müßte "split from #2" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
    - Der Swap des schließenden Tickets (by) wird zum zu schließenden Ticket addiert, bereits berechnete Commission wird aufgeteilt und erstattet. Die LotSize des schließenden
      Tickets (by) wird auf 0 gesetzt.
    - Der Profit der Restposition ist erst nach Schließen oder dem nächsten Tick korrekt aktualisiert (nur im Tester???).

    #larger(2) by #smaller(1):
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
   | closed    |     #1 |  Buy | 0.00 | EURUSD | 2012.03.19 11:00:05     |  1.3166'0 | 2012.03.19 20:00:01 |   1.3166'0 |       0.00 |  0.00 |    0.00 |         111 | close hedge by #2          | close hedge by #2          | close hedge by #2           | müßte "close hedge for #2" lauten
   | closed    |     #2 | Sell | 0.70 | EURUSD | 2012.03.19 14:00:05     |  1.3155'7 | 2012.03.19 20:00:01 |   1.3166'0 |      -5.60 | -2.06 |  -72.10 |         222 | partial close              | partial close              |                             |
   | remainder |     #3 | Sell | 0.30 | EURUSD | 2012.03.19 14:00:05 (2) |  1.3155'7 |                     |   1.3239'4 |      -2.40 |  0.00 | -251.10 |         222 | partial close              | partial close              |                             | müßte "split from #2" lauten
   +-----------+--------+------+------+--------+-------------------------+-----------+---------------------+------------+------------+-------+---------+-------------+----------------------------+----------------------------+-----------------------------+
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
   bool success, smallerByLarger=!IsTesting(), largerBySmaller=!smallerByLarger;


   // Schleife, bis Positionen geschlossen wurden oder ein permanenter Fehler auftritt
   while (true) {
      if (IsStopped()) return(_false(__Order.HandleError(StringConcatenate("OrderCloseByEx(9)  ", __OrderCloseByEx.PermErrorMsg(first, second, oe)), ERS_EXECUTION_STOPPING, false, oeFlags, oe), OrderPop("OrderCloseByEx(10)")));

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderCloseByEx(11)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      time1 = GetTickCount();
      if (smallerByLarger) success = OrderCloseBy(smaller, larger, markerColor);       // siehe (3)
      else                 success = OrderCloseBy(larger, smaller, markerColor);

      oe.setDuration(oe, GetTickCount()-time1);                                        // Zeit in Millisekunden

      if (success) {
         // oe[] füllen
         WaitForTicket(first, false);                                                  // FALSE wartet und selektiert
         oe.setSwap      (oe, OrderSwap()      );
         oe.setCommission(oe, OrderCommission());
         oe.setProfit    (oe, OrderProfit()    );

         WaitForTicket(second, false);                                                 // FALSE wartet und selektiert
         oe.setCloseTime (oe, OrderOpenTime()  );                                      // Daten des zweiten Tickets
         oe.setClosePrice(oe, OrderOpenPrice() );
         oe.addSwap      (oe, OrderSwap()      );
         oe.addCommission(oe, OrderCommission());
         oe.addProfit    (oe, OrderProfit()    );

         // Restposition finden
         if (!EQ(firstLots, secondLots)) {
            double remainderLots = MathAbs(firstLots - secondLots);

            if (smallerByLarger) {                                                     // online
               // Referenz: remainder.comment = "from #smaller"
               string strValue = StringConcatenate("from #", smaller);

               for (int i=OrdersTotal()-1; i >= 0; i--) {
                  if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;           // FALSE: während des Auslesens wurde in einem anderen Thread ein offenes Ticket geschlossen (darf im Tester nicht auftreten)
                  if (OrderComment() != strValue)                  continue;
                  remainder = OrderTicket();
                  break;
               }
               if (!remainder)
                  return(_false(oe.setError(oe, catch("OrderCloseByEx(12)  cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = smaller) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = larger)", ERR_RUNTIME_ERROR, O_POP))));
            }

            else /*(largerBySmaller)*/ {                                               // im Tester
               // keine Referenz vorhanden
               if (!SelectTicket(larger, "OrderCloseByEx(13)", NULL, O_POP))
                  return(_false(oe.setError(oe, last_error)));
               int      remainderType        = OrderType();
               //       remainderLots        = ...
               string   remainderSymbol      = OrderSymbol();
               datetime remainderOpenTime    = OrderOpenTime();
               double   remainderOpenprice   = OrderOpenPrice();
               datetime remainderCloseTime   = 0;
               int      remainderMagicNumber = OrderMagicNumber();
               string   remainderComment     = ifString(GetTerminalBuild() < 416, "partial close", OrderComment());

               for (i=OrdersTotal()-1; i >= 0; i--) {
                  if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(_false(oe.setError(oe, catch("OrderCloseByEx(14)->OrderSelect(i="+ i +", SELECT_BY_POS, MODE_TRADES)  unexpectedly returned FALSE", ERR_RUNTIME_ERROR, O_POP))));
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
               if (!remainder)
                  return(_false(oe.setError(oe, catch("OrderCloseByEx(15)  cannot find remaining position of close #"+ ticket +" ("+ NumberToStr(ticketLots, ".+") +" lots = larger) by #"+ opposite +" ("+ NumberToStr(oppositeLots, ".+") +" lots = smaller)", ERR_RUNTIME_ERROR, O_POP))));
            }
            oe.setRemainingTicket(oe, remainder    );
            oe.setRemainingLots  (oe, remainderLots);
         }

         if (__LOG) log(StringConcatenate("OrderCloseByEx(16)  ", __OrderCloseByEx.SuccessMsg(first, second, largerType, oe)));
         if (!IsTesting())
            PlaySoundEx("OrderOk.wav");

         return(!oe.setError(oe, catch("OrderCloseByEx(17)", NULL, O_POP)));           // regular exit
      }

      error = GetLastError();
      if (error == ERR_TRADE_CONTEXT_BUSY) {
         if (__LOG) log("OrderCloseByEx(18)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }
      if (!error)
         error = ERR_RUNTIME_ERROR;
      if (!IsTemporaryTradeError(error))                                               // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
         break;
      tempErrors++;
      if (tempErrors > 5)
         break;
      warn(StringConcatenate("OrderCloseByEx(19)  ", __Order.TempErrorMsg(oe, tempErrors)), error);
   }
   return(_false(oe.setError(oe, catch(StringConcatenate("OrderCloseByEx(20)  ", __OrderCloseByEx.PermErrorMsg(first, second, oe)), error, O_POP))));
}


/**
 * Logmessage für OrderCloseByEx().
 *
 * @param  int first      - erstes zu schließende Ticket
 * @param  int second     - zweites zu schließende Ticket
 * @param  int largerType - OrderType des Tickets mit der größeren Lotsize
 * @param  int oe[]       - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderCloseByEx()
 */
string __OrderCloseByEx.SuccessMsg(int first, int second, int largerType, /*ORDER_EXECUTION*/int oe[]) {
   // closed #30 by #38, remainder: #39 Buy 0.6 GBPUSD after 0.000 s
   // closed #31 by #39, no remainder after 0.000 s

   string message = StringConcatenate("closed #", first, " by #", second);

   int remainder = oe.RemainingTicket(oe);
   if (remainder != 0) message = StringConcatenate(message, ", remainder: #", remainder, " ", OperationTypeDescription(largerType), " ", NumberToStr(oe.RemainingLots(oe), ".+"), " ", oe.Symbol(oe));
   else                message = StringConcatenate(message, ", no remainder");

   return(StringConcatenate(message, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Logmessage für OrderCloseByEx().
 *
 * @param  int first  - erstes zu schließende Ticket
 * @param  int second - zweites zu schließende Ticket
 * @param  int oe[]   - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderCloseEx()
 */
string __OrderCloseByEx.PermErrorMsg(int first, int second, /*ORDER_EXECUTION*/int oe[]) {
   // permanent error while trying to close #1 by #2 after 0.345 s

   return(StringConcatenate("permanent error while trying to close #", first, " by #", second, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Schließt mehrere offene Positionen mehrerer Instrumente möglichst effektiv.
 *
 * @param  int    tickets[]   - Tickets der zu schließenden Positionen
 * @param  double slippage    - zu akzeptierende Slippage in Pip
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    oeFlags     - die Ausführung steuernde Flags
 * @param  int    oes[]       - Ausführungsdetails (ORDER_EXECUTION[])
 *
 * @return bool - Erfolgsstatus: FALSE, wenn mindestens eines der Tickets nicht geschlossen werden konnte oder ein Fehler auftrat
 *
 *
 * NOTE: 1) Nach Rückkehr enthalten oe.CloseTime und oe.ClosePrice die Werte der glattstellenden Transaktion des jeweiligen Symbols.
 *
 *       2) Die vom MT4-Server berechneten Einzelwerte in oe.Swap, oe.Commission und oe.Profit können vom tatsächlichen Einzelwert abweichen.
 *          Aus weiteren beim Schließen erzeugter Tickets resultierende Beträge werden zum entsprechenden Wert des letzten Tickets des jeweiligen
 *          Symbols addiert. Die Summe der Einzelwerte aller Tickets eines Symbols entspricht dem tatsächlichen Gesamtwert dieses Symbols.
 */
bool OrderMultiClose(int tickets[], double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]) {
   // (1) Beginn Parametervalidierung --
   // tickets
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets == 0)                                     return(_false(oes.setError(oes, -1, catch("OrderMultiClose(1)  invalid size "+ sizeOfTickets +" of parameter tickets = {}", ERR_INVALID_PARAMETER, O_POP))));
   OrderPush("OrderMultiClose(2)");
   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrderMultiClose(3)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      if (OrderCloseTime() != 0)                               return(_false(oes.setError(oes, -1, catch("OrderMultiClose(4)  #"+ tickets[i] +" is already closed", ERR_INVALID_TICKET, O_POP))));
      if (OrderType() > OP_SELL)                               return(_false(oes.setError(oes, -1, catch("OrderMultiClose(5)  #"+ tickets[i] +" is not an open position", ERR_INVALID_TICKET, O_POP))));
   }
   // slippage
   if (LT(slippage, 0))                                        return(_false(oes.setError(oes, -1, catch("OrderMultiClose(6)  illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_PARAMETER, O_POP))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(oes.setError(oes, -1, catch("OrderMultiClose(7)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, O_POP))));
   // -- Ende Parametervalidierung --

   // oes initialisieren
   ArrayResize(oes, sizeOfTickets); ArrayInitialize(oes, 0);


   // (2) schnelles Close, wenn nur ein Ticket angegeben wurde
   if (sizeOfTickets == 1) {
      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      if (!OrderCloseEx(tickets[0], NULL, NULL, slippage, markerColor, oeFlags, oe))
         return(_false(oes.setError(oes, -1, last_error), OrderPop("OrderMultiClose(8)")));
      CopyMemory(GetIntsAddress(oes), GetIntsAddress(oe), ArraySize(oe)*4);
      ArrayResize(oe, 0);
      return(OrderPop("OrderMultiClose(9)") && !oes.setError(oes, -1, last_error));
   }


   // (3) Zuordnung der Tickets zu Symbolen ermitteln
   string symbols        []; ArrayResize(symbols, 0);
   int si, tickets.symbol[]; ArrayResize(tickets.symbol, sizeOfTickets);
   int symbols.lastTicket[]; ArrayResize(symbols.lastTicket, 0);

   for (i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrderMultiClose(10)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      si = SearchStringArray(symbols, OrderSymbol());
      if (si == -1)
         si = ArrayResize(symbols.lastTicket, ArrayPushString(symbols, OrderSymbol())) - 1;
      tickets.symbol    [ i] = si;
      symbols.lastTicket[si] =  i;
   }


   // (4) Tickets gemeinsam schließen, wenn alle zum selben Symbol gehören
   /*ORDER_EXECUTION*/int oes2[][ORDER_EXECUTION.intSize]; ArrayResize(oes2, sizeOfTickets); InitializeByteBuffer(oes2, ORDER_EXECUTION.size);

   int sizeOfSymbols = ArraySize(symbols);
   if (sizeOfSymbols == 1) {
      if (!__OrderMultiClose.OneSymbol(tickets, slippage, markerColor, oeFlags, oes2))
         return(_false(oes.setError(oes, -1, last_error), OrderPop("OrderMultiClose(11)")));
      CopyMemory(GetIntsAddress(oes), GetIntsAddress(oes2), ArraySize(oes2)*4);
      ArrayResize(oes2,               0);
      ArrayResize(symbols,            0);
      ArrayResize(tickets.symbol,     0);
      ArrayResize(symbols.lastTicket, 0);
      return(OrderPop("OrderMultiClose(12)") && !oes.setError(oes, -1, last_error));
   }


   // (5) Tickets gehören zu mehreren Symbolen
   if (__LOG) log(StringConcatenate("OrderMultiClose(13)  closing ", sizeOfTickets, " mixed positions ", TicketsToStr.Lots(tickets, NULL)));

   // (5.1) oes[] vorbelegen
   for (i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "OrderMultiClose(14)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      oes.setSymbol    (oes, i, OrderSymbol()                         );
      oes.setDigits    (oes, i, MarketInfo(OrderSymbol(), MODE_DIGITS));
      oes.setTicket    (oes, i, tickets[i]                            );
      oes.setType      (oes, i, OrderType()                           );
      oes.setLots      (oes, i, OrderLots()                           );
      oes.setOpenTime  (oes, i, OrderOpenTime()                       );
      oes.setOpenPrice (oes, i, OrderOpenPrice()                      );
      oes.setStopLoss  (oes, i, OrderStopLoss()                       );
      oes.setTakeProfit(oes, i, OrderTakeProfit()                     );
      oes.setComment   (oes, i, OrderComment()                        );
   }
   if (!OrderPop("OrderMultiClose(15)"))
      return(_false(oes.setError(oes, -1, last_error)));


   // (6) tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu vermeiden, arbeiten wir auf einer Kopie.
   int tickets.copy[], flatSymbols[]; ArrayResize(tickets.copy, 0); ArrayResize(flatSymbols, 0);
   int sizeOfCopy=ArrayCopy(tickets.copy, tickets), pos, group[], sizeOfGroup;


   // (7) Tickets symbolweise selektieren und Symbolgruppen zunächst nur glattstellen
   for (si=0; si < sizeOfSymbols; si++) {
      ArrayResize(group, 0);
      for (i=0; i < sizeOfCopy; i++) {
         if (si == tickets.symbol[i])
            ArrayPushInt(group, tickets.copy[i]);
      }
      sizeOfGroup = ArraySize(group);
      ArrayResize(oes2, sizeOfGroup); InitializeByteBuffer(oes2, ORDER_EXECUTION.size);

      int newTicket = __OrderMultiClose.Flatten(group, slippage, oeFlags, oes2); // -1: kein neues Ticket
      if (IsLastError())                                                         //  0: Fehler oder Gesamtposition war bereits flat
         return(_false(oes.setError(oes, -1, last_error)));                      // >0: neues Ticket

      // Ausführungsdaten der Gruppe an die entsprechende Position des Funktionsparameters kopieren
      for (i=0; i < sizeOfGroup; i++) {
         pos = SearchIntArray(tickets, group[i]);
         oes.setBid       (oes, pos, oes.Bid       (oes2, i));
         oes.setAsk       (oes, pos, oes.Ask       (oes2, i));
         oes.setCloseTime (oes, pos, oes.CloseTime (oes2, i));                   // Werte sind in der ganzen Gruppe gleich
         oes.setClosePrice(oes, pos, oes.ClosePrice(oes2, i));
         oes.setDuration  (oes, pos, oes.Duration  (oes2, i));
         oes.setRequotes  (oes, pos, oes.Requotes  (oes2, i));
         oes.setSlippage  (oes, pos, oes.Slippage  (oes2, i));
      }
      if (newTicket != 0) {                                                      // -1 = kein neues Ticket: ein Ticket wurde komplett geschlossen
         for (i=0; i < sizeOfGroup; i++) {                                       // >0 = neues Ticket:      unabhängige neue Position oder ein Ticket wurde partiell geschlossen
            if (oes.RemainingTicket(oes2, i) == newTicket) {                     // partiell oder komplett geschlossenes Ticket gefunden
               pos = SearchIntArray(tickets, group[i]);
               oes.setSwap      (oes, pos, oes.Swap      (oes2, i));
               oes.setCommission(oes, pos, oes.Commission(oes2, i));
               oes.setProfit    (oes, pos, oes.Profit    (oes2, i));

               pos = SearchIntArray(tickets.copy, group[i]);
               sizeOfCopy -= ArraySpliceInts(tickets.copy,   pos, 1);            // geschlossenes Ticket löschen
                             ArraySpliceInts(tickets.symbol, pos, 1);
               sizeOfGroup--;
               break;
            }
         }
         if (newTicket > 0) {
            sizeOfCopy = ArrayPushInt(tickets.copy, newTicket);                  // neues Ticket hinzufügen
                         ArrayPushInt(tickets.symbol,      si);
            sizeOfGroup++;
         }
      }

      if (sizeOfGroup > 0)
         ArrayPushInt(flatSymbols, si);                                          // jetzt glattgestelltes Symbol zum späteren Schließen vormerken
   }


   // (8) verbliebene Teilpositionen der glattgestellten Gruppen schließen
   int sizeOfFlats = ArraySize(flatSymbols);
   for (i=0; i < sizeOfFlats; i++) {
      ArrayResize(group, 0);
      for (int n=0; n < sizeOfCopy; n++) {
         if (flatSymbols[i] == tickets.symbol[n])
            ArrayPushInt(group, tickets.copy[n]);
      }
      sizeOfGroup = ArraySize(group);
      ArrayResize(oes2, sizeOfGroup); InitializeByteBuffer(oes2, ORDER_EXECUTION.size);

      if (!__OrderMultiClose.Flattened(group, markerColor, oeFlags, oes2))
         return(_false(oes.setError(oes, -1, last_error)));

      // Ausführungsdaten der Gruppe an die entsprechende Position des Funktionsparameters kopieren
      for (int j=0; j < sizeOfGroup; j++) {
         pos = SearchIntArray(tickets, group[j]);
         if (pos == -1)                                                          // neue Tickets dem letzten übergebenen Ticket zuordnen
            pos = symbols.lastTicket[flatSymbols[i]];
         oes.addSwap      (oes, pos, oes.Swap      (oes2, j));
         oes.addCommission(oes, pos, oes.Commission(oes2, j));                   // Beträge jeweils addieren
         oes.addProfit    (oes, pos, oes.Profit    (oes2, j));
      }
   }

   ArrayResize(oes2,               0);
   ArrayResize(symbols,            0);
   ArrayResize(tickets.symbol,     0);
   ArrayResize(symbols.lastTicket, 0);
   ArrayResize(tickets.copy,       0);
   ArrayResize(flatSymbols,        0);
   return(!oes.setError(oes, -1, catch("OrderMultiClose(16)")));
}


/**
 * Schließt mehrere offene Positionen eines Symbols auf möglichst schnelle Art und Weise.
 *
 * @param  int    tickets[]   - Tickets der zu schließenden Positionen
 * @param  double slippage    - akzeptable Slippage in Pip
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    oeFlags     - die Ausführung steuernde Flags
 * @param  int    oes[]       - Ausführungsdetails (ORDER_EXECUTION[])
 *
 * @return bool - Erfolgsstatus: FALSE, wenn mindestens eines der Tickets nicht geschlossen werden konnte oder ein Fehler auftrat
 *
 *
 * NOTE: 1) Nach Rückkehr enthalten oe.CloseTime und oe.ClosePrice der Tickets die Werte der glattstellenden Transaktion (bei allen Tickets gleich).
 *
 *       2) Die vom MT4-Server berechneten Einzelwerte in oe.Swap, oe.Commission und oe.Profit können vom tatsächlichen Einzelwert abweichen,
 *          die Summe der Einzelwerte aller Tickets entspricht jedoch dem tatsächlichen Gesamtwert.
 *
 * @access private - Aufruf nur aus OrderMultiClose()
 */
bool __OrderMultiClose.OneSymbol(int tickets[], double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]) {
   // keine nochmalige, ausführliche Parametervalidierung (da private)
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets == 0)
      return(_false(oes.setError(oes, -1, catch("__OrderMultiClose.OneSymbol(1)  invalid parameter tickets, size = "+ sizeOfTickets, ERR_INVALID_PARAMETER))));
   ArrayResize(oes, sizeOfTickets); ArrayInitialize(oes, 0);


   // (1) schnelles Close, wenn nur ein Ticket angegeben wurde
   if (sizeOfTickets == 1) {
      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      if (!OrderCloseEx(tickets[0], NULL, NULL, slippage, markerColor, oeFlags, oe))
         return(_false(oes.setError(oes, -1, last_error)));
      CopyMemory(GetIntsAddress(oes), GetIntsAddress(oe), ArraySize(oe)*4);
      ArrayResize(oe, 0);
      return(true);
   }
   if (__LOG) log(StringConcatenate("__OrderMultiClose.OneSymbol(2)  closing ", sizeOfTickets, " ", OrderSymbol(), " positions ", TicketsToStr.Lots(tickets, NULL)));


   // (2) oes[] vorbelegen
   if (!SelectTicket(tickets[0], "__OrderMultiClose.OneSymbol(3)", O_PUSH))
      return(_false(oes.setError(oes, -1, last_error)));
   int digits = MarketInfo(OrderSymbol(), MODE_DIGITS);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "__OrderMultiClose.OneSymbol(4)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      oes.setSymbol    (oes, i, OrderSymbol()    );
      oes.setDigits    (oes, i, digits           );
      oes.setTicket    (oes, i, tickets[i]       );
      oes.setType      (oes, i, OrderType()      );
      oes.setLots      (oes, i, OrderLots()      );
      oes.setOpenTime  (oes, i, OrderOpenTime()  );
      oes.setOpenPrice (oes, i, OrderOpenPrice() );
      oes.setStopLoss  (oes, i, OrderStopLoss()  );
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment()   );
   }


   // (3) tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu vermeiden, arbeiten wir auf einer Kopie.
   int tickets.copy[]; ArrayResize(tickets.copy, 0);
   int sizeOfCopy = ArrayCopy(tickets.copy, tickets);


   // (4) Gesamtposition glatt stellen
   /*ORDER_EXECUTION*/int oes2[][ORDER_EXECUTION.intSize]; ArrayResize(oes2, sizeOfCopy); InitializeByteBuffer(oes2, ORDER_EXECUTION.size);

   int newTicket = __OrderMultiClose.Flatten(tickets.copy, slippage, oeFlags, oes2);                  // -1: kein neues Ticket
   if (IsLastError())                                                                                 //  0: Fehler oder Gesamtposition war bereits flat
      return(_false(oes.setError(oes, -1, last_error), OrderPop("__OrderMultiClose.OneSymbol(5)")));  // >0: neues Ticket

   for (i=0; i < sizeOfTickets; i++) {
      oes.setBid       (oes, i, oes.Bid       (oes2, i));
      oes.setAsk       (oes, i, oes.Ask       (oes2, i));
      oes.setCloseTime (oes, i, oes.CloseTime (oes2, i));               // Werte sind bei allen oes2-Tickets gleich
      oes.setClosePrice(oes, i, oes.ClosePrice(oes2, i));
      oes.setDuration  (oes, i, oes.Duration  (oes2, i));
      oes.setRequotes  (oes, i, oes.Requotes  (oes2, i));
      oes.setSlippage  (oes, i, oes.Slippage  (oes2, i));
   }
   if (newTicket != 0) {                                                // -1 = kein neues Ticket: ein Ticket wurde komplett geschlossen
      for (i=0; i < sizeOfTickets; i++) {                               // >0 = neues Ticket:      unabhängige neue Position oder ein Ticket wurde partiell geschlossen
         if (oes.RemainingTicket(oes2, i) == newTicket) {               // partiell oder komplett geschlossenes Ticket gefunden
            oes.setSwap      (oes, i, oes.Swap      (oes2, i));
            oes.setCommission(oes, i, oes.Commission(oes2, i));
            oes.setProfit    (oes, i, oes.Profit    (oes2, i));
            sizeOfCopy -= ArraySpliceInts(tickets.copy, i, 1);          // geschlossenes Ticket löschen
            break;
         }
      }
      if (newTicket > 0)
         sizeOfCopy = ArrayPushInt(tickets.copy, newTicket);            // neues Ticket hinzufügen
   }


   // (5) Teilpositionen auflösen
   ArrayResize(oes2, sizeOfCopy); InitializeByteBuffer(oes2, ORDER_EXECUTION.size);

   if (!__OrderMultiClose.Flattened(tickets.copy, markerColor, oeFlags, oes2))
      return(_false(oes.setError(oes, -1, last_error), OrderPop("__OrderMultiClose.OneSymbol(6)")));

   for (i=0; i < sizeOfCopy; i++) {
      int pos = SearchIntArray(tickets, tickets.copy[i]);
      if (pos == -1)                                                    // neue Tickets dem letzten übergebenen Ticket zuordnen
         pos = sizeOfTickets-1;
      oes.addSwap      (oes, pos, oes.Swap      (oes2, i));
      oes.addCommission(oes, pos, oes.Commission(oes2, i));             // Beträge jeweils addieren
      oes.addProfit    (oes, pos, oes.Profit    (oes2, i));
   }

   ArrayResize(oes2,         0);
   ArrayResize(tickets.copy, 0);
   return(!oes.setError(oes, -1, catch("__OrderMultiClose.OneSymbol(7)", NULL, O_POP)));
}


/**
 * Gleicht die Gesamtposition mehrerer Tickets eines Symbols durch eine einzige Tradeoperation aus. Dies geschieht bevorzugt durch (ggf. partielles)
 * Schließen einer der Positionen, anderenfalls durch Öffnen einer entsprechenden Gegenposition.
 *
 * @param  int    tickets[] - Tickets der auszugleichenden Positionen
 * @param  double slippage  - akzeptable Slippage in Pip
 * @param  int    oeFlags   - die Ausführung steuernde Flags
 * @param  int    oes[]     - Ausführungsdetails (ORDER_EXECUTION[])
 *
 * @return int -  -1 oder ein resultierendes, neues Ticket (falls zutreffend, siehe Notes)
 *                0, falls ein Fehler auftrat
 *
 *
 * NOTE: 1) Nach Rückkehr enthalten oe.CloseTime und oe.ClosePrice der Tickets die Werte der glattstellenden Transaktion (bei allen Tickets gleich, da mit
 *          einer einzigen Transaktion glattgestellt wird). War die Gesamtposition bereits ausgeglichen, enthalten sie OrderOpenTime/OrderOpenPrice des
 *          zuletzt geöffneten Tickets. Dieses Ticket entspricht der glattstellenden Transaktion.
 *
 *       2) Nach Rückkehr enthalten oe.Swap, oe.Commission und oe.Profit *nur dann* einen Wert, wenn das jeweilige Ticket beim Glattstellen zumindest
 *          partiell geschlossen wurde. Diese vom MT4-Server berechneten Einzelwerte können vom tatsächlichen Wert abweichen, sind in Summe jedoch korrekt.
 *
 *       3) Nach Rückkehr enthalten oe.RemainingTicket und oe.RemainingLots *nur dann* einen Wert, wenn das jeweilige Ticket zum Glattstellen verwendet wurde.
 *          - Der Wert von oe.RemainingTicket ist -1, wenn das jeweilige Ticket vollständig geschlossen wurde.
 *          - Der Wert von oe.RemainingTicket ist ein weiteres, neues Ticket, wenn das jeweilige Ticket partiell geschlossen wurde.
 *          Nur bei einem einzigen der übergebenen Tickets sind bei Rückkehr oe.RemainingTicket und oe.RemainingLots gesetzt.
 *
 *       4) Der Rückgabewert der Funktion entspricht dem in einem der Tickets gesetzten Wert von oe.RemainingTicket (siehe Note 3).
 *
 * @access private - Aufruf nur aus OrderMultiClose()
 */
int __OrderMultiClose.Flatten(int tickets[], double slippage, int oeFlags, /*ORDER_EXECUTION*/int oes[][]) {
   // keine nochmalige, ausführliche Parametervalidierung (da private)
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets == 0)
      return(_NULL(oes.setError(oes, -1, catch("__OrderMultiClose.Flatten(1)  invalid parameter tickets, size = "+ sizeOfTickets, ERR_INVALID_PARAMETER))));


   // (1) oes[] vorbelegen, dabei Lotsizes und Gesamtposition ermitteln
   ArrayResize(oes, sizeOfTickets); ArrayInitialize(oes, 0);
   if (!SelectTicket(tickets[0], "__OrderMultiClose.Flatten(2)", O_PUSH))
      return(_NULL(oes.setError(oes, -1, last_error)));
   string symbol = OrderSymbol();
   int    digits = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double totalLots, lots[]; ArrayResize(lots, 0);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "__OrderMultiClose.Flatten(3)", NULL, O_POP))
         return(_NULL(oes.setError(oes, -1, last_error)));
      oes.setSymbol    (oes, i, symbol           );
      oes.setDigits    (oes, i, digits           );
      oes.setTicket    (oes, i, tickets[i]       );
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


   // (2) wenn Gesamtposition bereits ausgeglichen ist
   if (EQ(totalLots, 0)) {
      if (__LOG) log(StringConcatenate("__OrderMultiClose.Flatten(4)  ", sizeOfTickets, " ", symbol, " positions ", TicketsToStr.Lots(tickets, NULL), " are already flat"));

      int tickets.copy[]; ArrayResize(tickets.copy, 0);                                // zuletzt geöffnetes Ticket ermitteln
      ArrayCopy(tickets.copy, tickets);
      SortTicketsChronological(tickets.copy);
      if (!SelectTicket(tickets.copy[sizeOfTickets-1], "__OrderMultiClose.Flatten(5)", NULL, O_POP))
         return(_NULL(oes.setError(oes, -1, last_error)));

      for (i=0; i < sizeOfTickets; i++) {
         oes.setBid       (oes, i, MarketInfo(symbol, MODE_BID));
         oes.setAsk       (oes, i, MarketInfo(symbol, MODE_ASK));
         oes.setCloseTime (oes, i, OrderOpenTime()             );
         oes.setClosePrice(oes, i, OrderOpenPrice()            );
      }
      if (!OrderPop("__OrderMultiClose.Flatten(6)"))
         return(_NULL(oes.setError(oes, -1, last_error)));
      ArrayResize(tickets.copy, 0);
   }
   else {
      if (!OrderPop("__OrderMultiClose.Flatten(7)"))
         return(_NULL(oes.setError(oes, -1, last_error)));
      if (__LOG) log(StringConcatenate("__OrderMultiClose.Flatten(8)  flattening ", sizeOfTickets, " ", symbol, " position", ifString(sizeOfTickets==1, " ", "s "), TicketsToStr.Lots(tickets, NULL)));


      // (3) Gesamtposition ist unausgeglichen
      int closeTicket, totalPosition=ifInt(GT(totalLots, 0), OP_LONG, OP_SHORT);

      // nach Möglichkeit OrderClose() verwenden: reduziert MarginRequired, vermeidet bestmöglich Überschreiten von TradeserverLimit
      for (i=0; i < sizeOfTickets; i++) {
         if (EQ(lots[i], totalLots)) {                                                 // zuerst vollständig schließbares Ticket suchen
            closeTicket = tickets[i];
            break;
         }
      }
      if (!closeTicket) {
         for (i=0; i < sizeOfTickets; i++) {                                           // danach partiell schließbares Ticket suchen
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
      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

      if (closeTicket != 0) {
         // (3.1) partielles oder vollständiges OrderClose eines vorhandenen Tickets
         if (!OrderCloseEx(closeTicket, MathAbs(totalLots), NULL, slippage, CLR_NONE, oeFlags, oe))
            return(_NULL(oes.setError(oes, -1, last_error)));

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
               if (!newTicket) {                                         newTicket = oes.setRemainingTicket(oes, i, -1       ); }   // Ticket vollständig geschlossen
               else            { oes.setRemainingLots(oes, i, oe.RemainingLots(oe)); oes.setRemainingTicket(oes, i, newTicket); }   // Ticket partiell geschlossen
            }
         }
      }
      else {
         // (3.2) neues, ausgleichendes Ticket öffnen
         if (OrderSendEx(symbol, totalPosition^1, MathAbs(totalLots), NULL, slippage, NULL, NULL, NULL, NULL, NULL, CLR_NONE, oeFlags, oe) == -1)
            return(_NULL(oes.setError(oes, -1, last_error)));
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

   if (!catch("__OrderMultiClose.Flatten(9)"))
      return(newTicket);
   return(_NULL(oes.setError(oes, -1, last_error)));
}


/**
 * Löst die ausgeglichene Gesamtposition eines Symbols auf.
 *
 * @param  int    tickets[]   - Tickets der ausgeglichenen Positionen
 * @param  color  markerColor - Farbe des Chart-Markers
 * @param  int    oeFlags     - die Ausführung steuernde Flags
 * @param  int    oes[]       - Ausführungsdetails (ORDER_EXECUTION[])
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: 1) Nach Rückkehr enthalten oe.CloseTime und oe.ClosePrice OrderOpenTime/OrderOpenPrice des zuletzt geöffneten Tickets (Open-Werte der
 *          glattstellenden Transaktion). Diese Werte sind bei allen Tickets gleich.
 *
 *       2) Die vom MT4-Server berechneten Einzelwerte in oe.Swap, oe.Commission und oe.Profit können vom tatsächlichen Einzelwert abweichen,
 *          die Summe der Einzelwerte aller Tickets entspricht jedoch dem tatsächlichen Gesamtwert.
 *
 * @access private - Aufruf nur aus OrderMultiClose()
 */
bool __OrderMultiClose.Flattened(int tickets[], color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]) {
   // keine nochmalige, ausführliche Parametervalidierung (da private)
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets < 2)
      return(_false(oes.setError(oes, -1, catch("__OrderMultiClose.Flattened(1)  invalid parameter tickets, size = "+ sizeOfTickets, ERR_INVALID_PARAMETER))));
   ArrayResize(oes, sizeOfTickets); ArrayInitialize(oes, 0);


   // (1) oes[] vorbelegen
   if (!SelectTicket(tickets[0], "__OrderMultiClose.Flattened(2)", O_PUSH))
      return(_false(oes.setError(oes, -1, last_error)));
   int digits = MarketInfo(OrderSymbol(), MODE_DIGITS);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!SelectTicket(tickets[i], "__OrderMultiClose.Flattened(3)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      oes.setSymbol    (oes, i, OrderSymbol()    );
      oes.setDigits    (oes, i, digits           );
      oes.setBid       (oes, i, MarketInfo(OrderSymbol(), MODE_BID));
      oes.setAsk       (oes, i, MarketInfo(OrderSymbol(), MODE_ASK));
      oes.setTicket    (oes, i, OrderTicket()    );
      oes.setType      (oes, i, OrderType()      );
      oes.setLots      (oes, i, OrderLots()      );
      oes.setOpenTime  (oes, i, OrderOpenTime()  );
      oes.setOpenPrice (oes, i, OrderOpenPrice() );
      oes.setStopLoss  (oes, i, OrderStopLoss()  );
      oes.setTakeProfit(oes, i, OrderTakeProfit());
      oes.setComment   (oes, i, OrderComment()   );
   }


   // (2) Logging
   if (__LOG) log(StringConcatenate("__OrderMultiClose.Flattened(4)  closing ", sizeOfTickets, " hedged ", OrderSymbol(), " positions ", TicketsToStr.Lots(tickets, NULL)));


   // (3) tickets[] wird in Folge modifiziert. Um Änderungen am übergebenen Array zu vermeiden, arbeiten wir auf einer Kopie.
   int tickets.copy[]; ArrayResize(tickets.copy, 0);
   int sizeOfCopy = ArrayCopy(tickets.copy, tickets);

   SortTicketsChronological(tickets.copy);
   if (!SelectTicket(tickets.copy[sizeOfCopy-1], "__OrderMultiClose.Flattened(5)", NULL, O_POP))  // das zuletzt geöffnete Ticket
      return(_false(oes.setError(oes, -1, last_error)));
   for (i=0; i < sizeOfTickets; i++) {
      oes.setCloseTime (oes, i, OrderOpenTime() );
      oes.setClosePrice(oes, i, OrderOpenPrice());
   }


   // (4) Teilpositionen nacheinander auflösen
   while (sizeOfCopy > 0) {
      int opposite, first=tickets.copy[0];
      if (!SelectTicket(first, "__OrderMultiClose.Flattened(6)", NULL, O_POP))
         return(_false(oes.setError(oes, -1, last_error)));
      int firstType = OrderType();

      for (i=1; i < sizeOfCopy; i++) {
         if (!SelectTicket(tickets.copy[i], "__OrderMultiClose.Flattened(7)", NULL, O_POP))
            return(_false(oes.setError(oes, -1, last_error)));
         if (OrderType() == firstType^1) {
            opposite = tickets.copy[i];                                                   // erste Opposite-Position ermitteln
            break;
         }
      }
      if (!opposite)
         return(_false(oes.setError(oes, -1, catch("__OrderMultiClose.Flattened(8)  cannot find opposite position for "+ OperationTypeDescription(firstType) +" #"+ first, ERR_RUNTIME_ERROR, O_POP))));


      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      if (!OrderCloseByEx(first, opposite, markerColor, oeFlags, oe))                     // erste und Opposite-Position schließen
         return(_false(oes.setError(oes, -1, last_error), OrderPop("__OrderMultiClose.Flattened(9)")));

      sizeOfCopy -= ArraySpliceInts(tickets.copy, 0, 1);                                  // erstes und opposite Ticket löschen
      sizeOfCopy -= ArrayDropInt(tickets.copy, opposite);

      int newTicket = oe.RemainingTicket(oe);
      if (newTicket != 0)                                                                 // Restposition zu verbleibenden Tickets hinzufügen
         sizeOfCopy = ArrayPushInt(tickets.copy, newTicket);

      i = SearchIntArray(tickets, first);                                                 // Ausgangsticket für realisierte Beträge ermitteln
      if (i == -1) {                                                                      // Reihenfolge: first, opposite, last
         i = SearchIntArray(tickets, opposite);
         if (i == -1)
            i = sizeOfTickets-1;
      }
      oes.addSwap      (oes, i, oe.Swap      (oe));                                       // Beträge addieren
      oes.addCommission(oes, i, oe.Commission(oe));
      oes.addProfit    (oes, i, oe.Profit    (oe));

      SortTicketsChronological(tickets.copy);
   }

   ArrayResize(oe,           0);
   ArrayResize(tickets.copy, 0);
   return(!oes.setError(oes, -1, catch("__OrderMultiClose.Flattened(10)", NULL, O_POP)));
}


/**
 * Erweiterte Version von OrderDelete().
 *
 * @param  int   ticket      - Ticket der zu schließenden Order
 * @param  color markerColor - Farbe des Chart-Markers
 * @param  int   oeFlags     - die Ausführung steuernde Flags
 * @param  int   oe[]        - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return bool - Erfolgsstatus
 */
bool OrderDeleteEx(int ticket, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!SelectTicket(ticket, "OrderDeleteEx(1)", O_PUSH))      return(_false(oe.setError(oe, last_error)));
   if (!IsPendingTradeOperation(OrderType()))                  return(_false(oe.setError(oe, catch("OrderDeleteEx(2)  #"+ ticket +" is not a pending order", ERR_INVALID_TICKET, O_POP))));
   if (OrderCloseTime() != 0)                                  return(_false(oe.setError(oe, catch("OrderDeleteEx(3)  #"+ ticket +" is already deleted", ERR_INVALID_TICKET, O_POP))));
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255') return(_false(oe.setError(oe, catch("OrderDeleteEx(4)  illegal parameter markerColor = 0x"+ IntToHexStr(markerColor), ERR_INVALID_PARAMETER, O_POP))));
   // -- Ende Parametervalidierung --

   // oe initialisieren
   ArrayInitialize(oe, 0);
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
   int  error, firstTime1=GetTickCount(), time1, tempErrors;
   bool success;

   // Schleife, bis Order gelöscht wurde oder ein permanenter Fehler auftritt
   while (true) {
      if (IsStopped()) return(_false(__Order.HandleError(StringConcatenate("OrderDeleteEx(5)  ", __OrderDeleteEx.PermErrorMsg(oe)), ERS_EXECUTION_STOPPING, false, oeFlags, oe), OrderPop("OrderDeleteEx(6)")));

      if (IsTradeContextBusy()) {
         if (__LOG) log("OrderDeleteEx(7)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }

      oe.setBid(oe, MarketInfo(OrderSymbol(), MODE_BID));
      oe.setAsk(oe, MarketInfo(OrderSymbol(), MODE_ASK));

      time1   = GetTickCount();
      success = OrderDelete(ticket, markerColor);

      oe.setDuration(oe, GetTickCount()-firstTime1);                                   // Gesamtzeit in Millisekunden

      if (success) {
         WaitForTicket(ticket, false);                                                 // FALSE wartet und selektiert

         if (!ChartMarker.OrderDeleted_A(ticket, oe.Digits(oe), markerColor))
            return(_false(oe.setError(oe, last_error), OrderPop("OrderDeleteEx(8)")));

         if (__LOG) log(StringConcatenate("OrderDeleteEx(9)  ", __OrderDeleteEx.SuccessMsg(oe)));
         if (!IsTesting())
            PlaySoundEx("OrderOk.wav");

         return(!oe.setError(oe, catch("OrderDeleteEx(10)", NULL, O_POP)));             // regular exit
      }

      error = GetLastError();
      if (error == ERR_TRADE_CONTEXT_BUSY) {
         if (__LOG) log("OrderDeleteEx(11)  trade context busy, retrying...");
         Sleep(300);                                                                   // 0.3 Sekunden warten
         continue;
      }
      if (!error)
         error = ERR_RUNTIME_ERROR;
      if (!IsTemporaryTradeError(error))                                               // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
         break;
      tempErrors++;
      if (tempErrors > 5)
         break;
      warn(StringConcatenate("OrderDeleteEx(12)  ", __Order.TempErrorMsg(oe, tempErrors)), error);
   }
   return(_false(oe.setError(oe, catch(StringConcatenate("OrderDeleteEx(13)  ", __OrderDeleteEx.PermErrorMsg(oe)), error, O_POP))));
}


/**
 * Logmessage für OrderDeleteEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderDeleteEx()
 */
string __OrderDeleteEx.SuccessMsg(/*ORDER_EXECUTION*/int oe[]) {
   // deleted #1 Stop Buy 0.5 GBPUSD at 1.5520'3 ("SR.12345.+3") after 0.2 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");
   string strPrice    = NumberToStr(oe.OpenPrice(oe), priceFormat);

   return(StringConcatenate("deleted #", oe.Ticket(oe), " ", strType, " ", strLots, " ", oe.Symbol(oe), strComment, " at ", strPrice, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Logmessage für OrderDeleteEx().
 *
 * @param  int oe[] - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return string
 *
 * @access private - Aufruf nur aus OrderDeleteEx()
 */
string __OrderDeleteEx.PermErrorMsg(/*ORDER_EXECUTION*/int oe[]) {
   // permanent error while trying to delete #1 Stop Buy 0.5 GBPUSD "SR.1234.+1" at 1.5524'8 (market Bid/Ask), sl=1.5500'0, tp=1.5600'0 after 0.345 s

   int    digits      = oe.Digits(oe);
   int    pipDigits   = digits & (~1);
   string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
   string strType     = OperationTypeDescription(oe.Type(oe));
   string strLots     = NumberToStr(oe.Lots(oe), ".+");
   string symbol      = oe.Symbol(oe);
   string strComment  = oe.Comment(oe);
      if (StringLen(strComment) > 0) strComment = StringConcatenate(" \"", strComment, "\"");

   string strPrice = NumberToStr(oe.OpenPrice(oe), priceFormat);
   string strSL; if (!EQ(oe.StopLoss  (oe), 0)) strSL = StringConcatenate(", sl=", NumberToStr(oe.StopLoss  (oe), priceFormat));
   string strTP; if (!EQ(oe.TakeProfit(oe), 0)) strTP = StringConcatenate(", tp=", NumberToStr(oe.TakeProfit(oe), priceFormat));
   string strSD; if (oe.Error(oe) == ERR_INVALID_STOP) {
      strPrice = StringConcatenate(strPrice, " (market ", NumberToStr(MarketInfo(symbol, MODE_BID), priceFormat), "/", NumberToStr(MarketInfo(symbol, MODE_ASK), priceFormat), ")");
      strSD    = StringConcatenate(", stop distance=", NumberToStr(oe.StopDistance(oe), ".+"), " pip");
   }
   return(StringConcatenate("permanent error while trying to delete #", oe.Ticket(oe), " ", strType, " ", strLots, " ", symbol, strComment, " at ", strPrice, strSL, strTP, strSD, " after ", DoubleToStr(oe.Duration(oe)/1000., 3), " s"));
}


/**
 * Streicht alle offenen Pending-Orders.
 *
 * @param  color markerColor - Farbe des Chart-Markers (default: kein Marker)
 *
 * @return bool - Erfolgsstatus
 */
bool DeletePendingOrders(color markerColor=CLR_NONE) {
   int oeFlags = NULL;
   /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int size  = OrdersTotal();
   if (size > 0) {
      OrderPush("DeletePendingOrders(1)");

      for (int i=size-1; i >= 0; i--) {                                 // offene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
            continue;
         if (IsPendingTradeOperation(OrderType())) {
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
 * Wird nur im Tester aus Library::init() aufgerufen, um alle verwendeten globalen Arrays zurückzusetzen (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);
   ArrayResize(lock.names           , 0);
   ArrayResize(lock.counters        , 0);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


// abstrakte Funktionen (müssen bei Verwendung im Programm implementiert werden)
/*abstract*/ bool onBarOpen      (             ) { return(!catch("onBarOpen(1)",       ERR_NOT_IMPLEMENTED)); }
/*abstract*/ bool onBarOpen.MTF  (int    data[]) { return(!catch("onBarOpen.MTF(1)",   ERR_NOT_IMPLEMENTED)); }
/*abstract*/ bool onAccountChange(int    data[]) { return(!catch("onAccountChange(1)", ERR_NOT_IMPLEMENTED)); }
/*abstract*/ bool onChartCommand (string data[]) { return(!catch("onChartCommand(1)",  ERR_NOT_IMPLEMENTED)); }
/*abstract*/ void DummyCalls()                   {         catch("DummyCalls(1)",      ERR_NOT_IMPLEMENTED);  }


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib2.ex4"
   string DoublesToStr(double array[], string separator);
   string TicketsToStr.Lots(int array[], string separator);

#import "Expander.dll"
   int    ec_LastError               (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_UninitializeReason      (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_setRootFunction         (/*EXECUTION_CONTEXT*/int ec[], int function);
   int    ec_setUninitializeReason   (/*EXECUTION_CONTEXT*/int ec[], int reason  );

   int    pi_hProcess                (/*PROCESS_INFORMATION*/int pi[]);
   int    pi_hThread                 (/*PROCESS_INFORMATION*/int pi[]);

   int    si_setSize                 (/*STARTUPINFO*/int si[], int size   );
   int    si_setFlags                (/*STARTUPINFO*/int si[], int flags  );
   int    si_setShowWindow           (/*STARTUPINFO*/int si[], int cmdShow);

   int    tzi_Bias                   (/*TIME_ZONE_INFORMATION*/int tzi[]);
   int    tzi_DaylightBias           (/*TIME_ZONE_INFORMATION*/int tzi[]);

   bool   wfd_FileAttribute_Directory(/*WIN32_FIND_DATA*/int wfd[]);
   string wfd_FileName               (/*WIN32_FIND_DATA*/int wfd[]);
#import
