/**
 * Letzte Version mit vollständigem Funktions-Listing: git commit deaf9a4 (2015.06.14 10:29:29 GMT)
 */
#import "rsfLib1.ex4"

   // Arrays
   bool     ArrayAddInt         (int    array[],   int value);
   int      ArraySetInts        (int    array[][], int i, int values[]);

   int      ArrayPushBool       (bool   array[],   bool   value   );
   int      ArrayPushInt        (int    array[],   int    value   );
   int      ArrayPushInts       (int    array[][], int    values[]);
   int      ArrayPushDouble     (double array[],   double value   );
   int      ArrayPushString     (string array[],   string value   );

   bool     ArrayPopBool        (bool   array[]);
   int      ArrayPopInt         (int    array[]);
   double   ArrayPopDouble      (double array[]);
   string   ArrayPopString      (string array[]);

   int      ArrayUnshiftBool    (bool   array[], bool   value);
   int      ArrayUnshiftInt     (int    array[], int    value);
   int      ArrayUnshiftDouble  (double array[], double value);
   int      ArrayUnshiftString  (string array[], string value);

   bool     ArrayShiftBool      (bool   array[]);
   int      ArrayShiftInt       (int    array[]);
   double   ArrayShiftDouble    (double array[]);
   string   ArrayShiftString    (string array[]);

   int      ArrayDropBool       (bool   array[], bool   value);
   int      ArrayDropInt        (int    array[], int    value);
   int      ArrayDropDouble     (double array[], double value);
   int      ArrayDropString     (string array[], string value);

   int      ArraySpliceBools    (bool   array[],   int offset, int length);
   int      ArraySpliceInts     (int    array[],   int offset, int length);
   int      ArraySpliceDoubles  (double array[],   int offset, int length);
   int      ArraySpliceStrings  (string array[],   int offset, int length);

   int      ArrayInsertBool       (bool   array[],   int offset, bool   value   );
   int      ArrayInsertBools      (bool   array[],   int offset, bool   values[]);
   int      ArrayInsertInt        (int    array[],   int offset, int    value   );
   int      ArrayInsertInts       (int    array[],   int offset, int    values[]);
   int      ArrayInsertDouble     (double array[],   int offset, double value   );
   int      ArrayInsertDoubles    (double array[],   int offset, double values[]);
#import "rsfLib2.ex4"
   int      ArrayInsertDoubleArray(double array[][], int offset, double values[]);
   int      ArrayInsertString     (string array[],   int offset, string value   );
   int      ArrayInsertStrings    (string array[],   int offset, string values[]);

#import "rsfLib1.ex4"
   bool     BoolInArray   (bool   haystack[], bool   needle);
   bool     IntInArray    (int    haystack[], int    needle);
   bool     DoubleInArray (double haystack[], double needle);
   bool     StringInArray (string haystack[], string needle);
   bool     StringInArrayI(string haystack[], string needle);

   int      SearchBoolArray   (bool   haystack[], bool   needle);
   int      SearchIntArray    (int    haystack[], int    needle);
   int      SearchDoubleArray (double haystack[], double needle);
   int      SearchStringArray (string haystack[], string needle);
   int      SearchStringArrayI(string haystack[], string needle);

   bool     ReverseBoolArray  (bool   array[]);
   bool     ReverseIntArray   (int    array[]);
   bool     ReverseDoubleArray(double array[]);
   bool     ReverseStringArray(string array[]);

   bool     IsReverseIndexedBoolArray  (bool   array[]);
   bool     IsReverseIndexedIntArray   (int    array[]);
   bool     IsReverseIndexedDoubleArray(double array[]);
   bool     IsReverseIndexedSringArray (string array[]);

   int      MergeBoolArrays  (bool   array1[], bool   array2[], bool   merged[]);
   int      MergeIntArrays   (int    array1[], int    array2[], int    merged[]);
   int      MergeDoubleArrays(double array1[], double array2[], double merged[]);
   int      MergeStringArrays(string array1[], string array2[], string merged[]);

   double   SumDoubles(double array[]);


   // Buffer-Funktionen
   int      InitializeDoubleBuffer(double buffer[], int size);

   string   BufferToStr   (int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int char);

   string   BufferWCharsToStr(int buffer[], int from, int length);  //string BufferGetStringW(int buffer[], int from, int length);     // Alias


   // configuration
   int      GetIniSections(string fileName, string &names[]);


   // Date/Time
   datetime FxtToGmtTime   (datetime fxtTime);
   datetime FxtToServerTime(datetime fxtTime);                                                        // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GmtToFxtTime   (datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);                                                        // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime ServerToFxtTime(datetime serverTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime ServerToGmtTime(datetime serverTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetFxtToGmtTimeOffset   (datetime fxtTime);
   int      GetFxtToServerTimeOffset(datetime fxtTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetGmtToFxtTimeOffset   (datetime gmtTime);
   int      GetGmtToServerTimeOffset(datetime gmtTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetServerToFxtTimeOffset(datetime serverTime);                                            // throws ERR_INVALID_TIMEZONE_CONFIG
   int      GetServerToGmtTimeOffset(datetime serverTime);                                            // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetLocalToGmtTimeOffset();
   bool     GetTimezoneTransitions(datetime serverTime, int prevTransition[], int nextTransition[]);  // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetPrevSessionStartTime.fxt(datetime fxtTime   );
   datetime GetPrevSessionStartTime.gmt(datetime gmtTime   );
   datetime GetPrevSessionStartTime.srv(datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetPrevSessionEndTime.fxt  (datetime fxtTime   );
   datetime GetPrevSessionEndTime.gmt  (datetime gmtTime   );
   datetime GetPrevSessionEndTime.srv  (datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetSessionStartTime.fxt    (datetime fxtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionStartTime.gmt    (datetime gmtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionStartTime.srv    (datetime serverTime);                                         // throws ERR_MARKET_CLOSED, ERR_INVALID_TIMEZONE_CONFIG

   datetime GetSessionEndTime.fxt      (datetime fxtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionEndTime.gmt      (datetime gmtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionEndTime.srv      (datetime serverTime);                                         // throws ERR_MARKET_CLOSED, ERR_INVALID_TIMEZONE_CONFIG

   datetime GetNextSessionStartTime.fxt(datetime fxtTime   );
   datetime GetNextSessionStartTime.gmt(datetime gmtTime   );
   datetime GetNextSessionStartTime.srv(datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetNextSessionEndTime.fxt  (datetime fxtTime   );
   datetime GetNextSessionEndTime.gmt  (datetime gmtTime   );
   datetime GetNextSessionEndTime.srv  (datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG


   // Event-Listener/Handler: Diese Library-Versionen sind leere Stubs, bei Verwendung müssen die Handler im Programm implementiert werden.
   bool     onBarOpen();
   bool     onCommand(string data[]);


   // Farben
   color    RGB(int red, int green, int blue);
   int      RGBToHSL(color rgb, double hsl[], bool human = false);
   color    HSLToRGB(double hsl[3]);
   color    ModifyColor(color rgb, double hue, double saturation, double lightness);


   // Files, I/O
   string   CreateTempFile(string path, string prefix="");
   string   GetTempPath();

   int      FindFileNames(string pattern, string results[], int flags);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   bool     EditFile (string filename   );
   bool     EditFiles(string filenames[]);


   // Locks
   bool     AquireLock(string mutexName, bool wait);
   bool     ReleaseLock(string mutexName);


   // Strings
   bool     SortStrings(string &values[]);
   string   StringPad(string input, int length, string pad_string, int pad_type);


   // Tradefunktionen, Orderhandling
   bool     IsTemporaryTradeError(int error);

   // s: StopDistance/FreezeDistance integriert
   int /*s*/OrderSendEx(string symbol, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool/*s*/OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool     OrderDeleteEx(int ticket, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseEx(int ticket, double lots, double slippage, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, int oe[]);
   bool     OrdersClose(int tickets[], double slippage, color markerColor, int oeFlags, int oes[][]);
   bool     OrdersCloseSameSymbol(int tickets[], double slippage, color markerColor, int oeFlags, int oes[][]);
   int      OrdersHedge(int tickets[], double slippage, int oeFlags, int oes[][]);
   bool     OrdersCloseHedged(int tickets[], color markerColor, int oeFlags, int oes[][]);
   bool     DeletePendingOrders(color markerColor);

   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment);
   bool     ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);
   bool     ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor);
   bool     ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment);
   bool     ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeProfit);
   bool     ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment);
   bool     ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);


   // sonstiges
   int      SortTicketsChronological(int tickets[]);
#import "rsfLib2.ex4"
   bool     SortClosedTickets(int keys[][]);
   bool     SortOpenTickets(int keys[][]);

#import "rsfLib1.ex4"
   string   StdSymbol();                                                            // Alias für GetStandardSymbol(Symbol())
   string   GetStandardSymbol(string symbol);                                       // Alias für GetStandardSymbolOrAlt(symbol, symbol)
   string   GetStandardSymbolOrAlt(string symbol, string altValue);
   string   GetStandardSymbolStrict(string symbol);

   string   GetSymbolName(string symbol);                                           // Alias für GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                                       // Alias für GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   int      RepositionLegend();
   bool     ObjectDeleteSilent(string label, string location);
   int      ObjectRegister(string label);
   int      DeleteRegisteredObjects();


   // toString-Funktionen
   string   DoubleToStrEx(double value, int digits/*=0..16*/);

   string   IntegerToBinaryStr(int integer);

   string   CharToHexStr(int char);
   string   WordToHexStr(int word);
   string   IntegerToHexStr(int decimal);

#import "rsfLib2.ex4"
   string   BoolsToStr             (bool array[], string separator);
   string   IntsToStr               (int array[], string separator);
   string   CharsToStr              (int array[], string separator);
   string   TicketsToStr            (int array[], string separator);
   string   TicketsToStr.Lots       (int array[], string separator);
   string   TicketsToStr.LotsSymbols(int array[], string separator);
   string   TicketsToStr.Position   (int array[]);
   string   OperationTypesToStr     (int array[], string separator);
   string   TimesToStr         (datetime array[], string separator);
   string   DoublesToStr         (double array[], string separator);
   string   DoublesToStrEx       (double array[], string separator, int digits/*=0..16*/);
   string   iBufferToStr         (double array[], string separator);
   string   MoneysToStr          (double array[], string separator);
   string   RatesToStr           (double array[], string separator); string PricesToStr(double array[], string separator);   // Alias
   string   StringsToStr         (string array[], string separator);

#import "rsfLib1.ex4"
   string   GetWindowsShortcutTarget(string lnkFile);
   string   GetWindowText(int hWnd);
   string   WaitForSingleObjectValueToStr(int value);
   int      WinExecWait(string cmdLine, int cmdShow);
#import "rsfLib2.ex4"
   int      GetTerminalRuntime();
#import


// ShowWindow()-Konstanten für WinExecWait(), Details siehe win32api.mqh
#define SW_SHOW                  5
#define SW_SHOWNA                8
#define SW_HIDE                  0
#define SW_SHOWMAXIMIZED         3
#define SW_SHOWMINIMIZED         2
#define SW_SHOWMINNOACTIVE       7
#define SW_MINIMIZE              6
#define SW_FORCEMINIMIZE        11
#define SW_SHOWNORMAL            1
#define SW_SHOWNOACTIVATE        4
#define SW_RESTORE               9
#define SW_SHOWDEFAULT          10
