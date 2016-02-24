/**
 * Importdeklarartionen für alle Expanderfunktionen ohne Array-Parameter (je MQL-Modul können bis zu 512 Arrays deklariert werden)
 *
 * Ausnahme: Basisfunktionen zum Ermitteln von Array-Speicheradressen
 */
#import "Expander.dll"

   // Chart-Ticker
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     RemoveTickTimer(int timerId);

   int      GetApplicationWindow();
   datetime GetGmtTime();
   int      GetLastWin32Error();
   datetime GetLocalTime();
   int      GetUIThreadId();
   int      GetWindowProperty(int hWnd, string name);
   string   IntToHexStr(int value);
   bool     IsBuiltinTimeframe(int timeframe);
   bool     IsCustomTimeframe(int timeframe);
   bool     IsUIThread();
   int      MT4InternalMsg();
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   PeriodDescription(int period);
   string   PeriodToStr(int period);
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   int      RemoveWindowProperty(int hWnd, string name);
   string   RootFunctionName(int id);
   string   RootFunctionToStr(int id);
   bool     SetWindowProperty(int hWnd, string name, int value);
   bool     StringCompare(string s1, string s2);
   bool     StringIsNull(string value);
   string   StringToStr(string value);
   string   TimeframeDescription(int timeframe);
   string   TimeframeToStr(int timeframe);
   string   UninitializeReasonToStr(int reason);

   // Handling von Speicheradressen
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);
   int      GetStringAddress (string value   );                   // Vorsicht: Ist value kein Arrayelement, erhält die DLL eine Kopie, die dann vermutlich eine lokale Variable
   int      GetStringsAddress(string values[]);                   //           der aufrufenden MQL-Funktion ist. Sie *könnte* nach Rückkehr sofort freigegeben werden, scheinbar
   string   GetString(int address);                               //           erfolgt dies aber erst bei Funktionsende gemeinsam mit den anderen lokalen (Stack-)Variablen.

   // Stubs, können bei Bedarf im Modul durch konkrete Versionen "überschrieben" werden.
   int      onInit();
   int      onInit_User();
   int      onInit_Template();
   int      onInit_Program();
   int      onInit_ProgramClearTest();
   int      onInit_Parameters();
   int      onInit_TimeframeChange();
   int      onInit_SymbolChange();
   int      onInit_Recompile();
   int      afterInit();

   int      onStart();                                               // Scripte
   int      onTick();                                                // EA's + Indikatoren

   int      onDeinit();
   int      afterDeinit();
#import
