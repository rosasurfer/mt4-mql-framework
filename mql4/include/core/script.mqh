
#define __TYPE__         MT_SCRIPT
#define __lpSuperContext NULL


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   if (__WHEREAMI__ == NULL)                                                              // Aufruf durch Terminal, in Scripten sind alle Variablen zurückgesetzt
      __WHEREAMI__ = RF_INIT;
   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), WindowHandle(Symbol(), NULL), WindowOnDropped());


   // (1) Initialisierung abschließen, wenn der Kontext unvollständig ist
   if (!UpdateExecutionContext()) {
      UpdateProgramStatus(); if (__STATUS_OFF) return(last_error);
   }


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(iNull);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }

                                                                                          // #define INIT_TIMEZONE               in stdlib.init()
   // (3) user-spezifische Init-Tasks ausführen                                           // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                                      // #define INIT_BARS_ON_HIST_UPDATE
                                                                                          // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                                     // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)       return(UpdateProgramStatus(catch("init(2)  MarketInfo(MODE_TICKSIZE) = 0", ERR_INVALID_MARKET_DATA)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue)      return(UpdateProgramStatus(catch("init(4)  MarketInfo(MODE_TICKVALUE) = 0", ERR_INVALID_MARKET_DATA)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                                      // noch nicht implementiert


   // (4) User-spezifische init()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   error = onInit();                                                                      // Preprocessing-Hook
   if (!error) {                                                                          //
      switch (UninitializeReason()) {                                                     //
         case REASON_PARAMETERS : error = onInitParameterChange(); break;                 //
         case REASON_CHARTCHANGE: error = onInitChartChange();     break;                 //
         case REASON_ACCOUNT    : error = onInitAccountChange();   break;                 //
         case REASON_CHARTCLOSE : error = onInitChartClose();      break;                 //
         case REASON_UNDEFINED  : error = onInitUndefined();       break;                 //
         case REASON_REMOVE     : error = onInitRemove();          break;                 //
         case REASON_RECOMPILE  : error = onInitRecompile();       break;                 //
         // build > 509                                                                   //
         case REASON_TEMPLATE   : error = onInitTemplate();        break;                 //
         case REASON_INITFAILED : error = onInitFailed();          break;                 //
         case REASON_CLOSE      : error = onInitClose();           break;                 //
                                                                                          //
         default: return(UpdateProgramStatus(catch("init(5)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                                   //
   }                                                                                      //
   if (IsError(error)) SetLastError(error);                                               //
   UpdateProgramStatus();                                                                 //
                                                                                          //
   if (error != -1) {                                                                     //
      error = afterInit();                                                                // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                            //
      UpdateProgramStatus();                                                              //
   }                                                                                      //

   UpdateProgramStatus(catch("init(6)"));
   return(last_error);
}


/**
 * Globale start()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                            // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      debug("start(1)  "+ msg);
      return(last_error);
   }

   __WHEREAMI__ = RF_START;
   SyncMainContext_start(__ExecutionContext);

   Tick++; zTick++;                                                           // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime  = Tick.Time;
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);                          // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
   Tick.isVirtual = true;                                                     // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   ValidBars      = -1;
   ChangedBars    = -1;

   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) {      // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         UpdateProgramStatus(catch("start(2)", error));                       // nicht sicher detektiert werden kann
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (1) init() war immer erfolgreich


   // (2) Abschluß der Chart-Initialisierung überprüfen
   if (!(ec_InitFlags(__ExecutionContext) & INIT_DOESNT_REQUIRE_BARS))                          // Bars kann 0 sein, wenn das Script auf einem leeren Chart startet
      if (!Bars)                                                                                // (Waiting for update...) oder der Chart beim Terminal-Start noch nicht
         return(UpdateProgramStatus(catch("start(3)  Bars = 0", ERS_TERMINAL_NOT_YET_READY)));  // vollständig initialisiert ist


   // (3) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(SetLastError(stdlib.GetLastError()));
      if (__STATUS_OFF) return(last_error);
   }


   // (4) Main-Funktion aufrufen
   onStart();


   // (5) Fehler-Status auswerten
   error = ec_DllError(__ExecutionContext);
   if (error != NO_ERROR) catch("start(4)  DLL error", error);
   else if (!last_error) {
      error = ec_MqlError(__ExecutionContext);
      if (error != NO_ERROR) last_error = error;
   }
   error = GetLastError();
   if (error != NO_ERROR) catch("start(5)", error);

   return(UpdateProgramStatus(last_error));
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;
   SyncMainContext_deinit(__ExecutionContext, UninitializeReason());


   // (1) User-spezifische deinit()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (!error) {                                                                 //
      switch (UninitializeReason()) {                                            //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
         // build > 509                                                          //
         case REASON_TEMPLATE   : error = onDeinitTemplate();        break;      //
         case REASON_INITFAILED : error = onDeinitFailed();          break;      //
         case REASON_CLOSE      : error = onDeinitClose();           break;      //
                                                                                 //
         default:                                                                //
            UpdateProgramStatus(catch("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR));
            LeaveContext(__ExecutionContext);                                    //
            return(last_error);                                                  //
      }                                                                          //
   }                                                                             //
   if (IsError(error)) SetLastError(error);                                      //
   UpdateProgramStatus();                                                        //
                                                                                 //
   if (error != -1) {                                                            //
      error = afterDeinit();                                                     // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                   //
      UpdateProgramStatus();                                                     //
   }                                                                             //


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);


   UpdateProgramStatus(catch("deinit(2)"));
   LeaveContext(__ExecutionContext);
   return(last_error); __DummyCalls();
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Ob das aktuell ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Ob das aktuell ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(true);
}


/**
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Ob das aktuell ausgeführte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Update the script's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 */
bool UpdateExecutionContext() {
   // (1) EXECUTION_CONTEXT finalisieren
   int hChart = ec_hChart(__ExecutionContext);
   if (!hChart) {
      hChart = WindowHandleEx(NULL); if (!hChart) return(false);
      ec_SetHChart      (__ExecutionContext, hChart           );
      ec_SetHChartWindow(__ExecutionContext, GetParent(hChart));
   }
   ec_SetTestFlags(__ExecutionContext, ifInt(Script.IsTesting(), TF_VISUAL_TEST, 0));        // Ein Script kann nur auf einem sichtbaren Chart laufen.
   ec_SetLogging  (__ExecutionContext, true);
   ec_SetLogFile  (__ExecutionContext, ""  );


   // (2) globale Variablen initialisieren
   __NAME__       = WindowExpertName();
   __CHART        = true;
   __LOG          = true;
   __LOG_CUSTOM   = false;                                                                   // Custom-Logging gibt es vorerst nur für Experts

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!catch("UpdateExecutionContext(1)"));
}


/**
 * Handler für im Script auftretende Fehler. Zur Zeit wird der Fehler nur angezeigt.
 *
 * @param  string location - Ort, an dem der Fehler auftrat
 * @param  string message  - Fehlermeldung
 * @param  int    error    - zu setzender Fehlercode
 *
 * @return int - derselbe Fehlercode
 */
int HandleScriptError(string location, string message, int error) {
   if (StringLen(location) > 0)
      location = " :: "+ location;

   PlaySoundEx("Windows Chord.wav");
   MessageBox(message, "Script "+ __NAME__ + location, MB_ICONERROR|MB_OK);

   return(SetLastError(error));
}


/**
 * Überprüft und aktualisiert den aktuellen Programmstatus des Scripts. Setzt je nach Kontext das Flag __STATUS_OFF.
 *
 * @param  int value - der zurückzugebende Wert (default: NULL)
 *
 * @return int - der übergebene Wert
 */
int UpdateProgramStatus(int value=NULL) {
   switch (last_error) {
      case NO_ERROR                  :
      case ERS_HISTORY_UPDATE        :
    //case ERS_TERMINAL_NOT_YET_READY:                               // in Scripten ist ERS_TERMINAL_NOT_YET_READY kein Status, sondern normaler Fehler
      case ERS_EXECUTION_STOPPING    : break;

      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
   }
   return(value);

   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   HandleScriptError(NULL, NULL, NULL);
}



// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int    stdlib.init  (int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int    stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);

   int    onInitAccountChange();
   int    onInitChartChange();
   int    onInitChartClose();
   int    onInitParameterChange();
   int    onInitRecompile();
   int    onInitRemove();
   int    onInitUndefined();
   // build > 509
   int    onInitTemplate();
   int    onInitFailed();
   int    onInitClose();

   int    onDeinitAccountChange();
   int    onDeinitChartChange();
   int    onDeinitChartClose();
   int    onDeinitParameterChange();
   int    onDeinitRecompile();
   int    onDeinitRemove();
   int    onDeinitUndefined();
   // build > 509
   int    onDeinitTemplate();
   int    onDeinitFailed();
   int    onDeinitClose();

   string GetWindowText(int hWnd);

#import "Expander.dll"
   int    ec_DllError         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError         (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetHChart        (/*EXECUTION_CONTEXT*/int ec[], int    hChart        );
   int    ec_SetHChartWindow  (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow  );
   bool   ec_SetLogging       (/*EXECUTION_CONTEXT*/int ec[], int    logging       );
   string ec_SetLogFile       (/*EXECUTION_CONTEXT*/int ec[], string logFile       );
   int    ec_SetLpSuperContext(/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext);
   int    ec_SetTestFlags     (/*EXECUTION_CONTEXT*/int ec[], int    testFlags     );

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int hChart, int subChartDropped);
   bool   SyncMainContext_start (int ec[]);
   bool   SyncMainContext_deinit(int ec[], int uninitReason);

#import "user32.dll"
   int    GetParent(int hWnd);

#import
