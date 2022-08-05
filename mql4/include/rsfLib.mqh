/**
 * Functions already imported by the framework core files are removed from this file.
 * Last version with a complete function listing:
 *
 * @see  git commit deaf9a4 (2015.06.14 10:29:29 GMT)
 */
#import "rsfLib.ex4"

   // arrays
   bool     ArrayAddInt         (int    &array[],   int value);
   int      ArraySetInts        (int    &array[][], int i, int values[]);

   int      ArrayPushBool       (bool   &array[],   bool   value   );
   int      ArrayPushInt        (int    &array[],   int    value   );
   int      ArrayPushInts       (int    &array[][], int    values[]);
   int      ArrayPushDouble     (double &array[],   double value   );
   int      ArrayPushDoubles    (double &array[][], double values[]);
   int      ArrayPushString     (string &array[],   string value   );

   bool     ArrayPopBool        (bool   &array[]);
   int      ArrayPopInt         (int    &array[]);
   double   ArrayPopDouble      (double &array[]);
   string   ArrayPopString      (string &array[]);

   int      ArrayUnshiftBool    (bool   &array[], bool   value);
   int      ArrayUnshiftInt     (int    &array[], int    value);
   int      ArrayUnshiftDouble  (double &array[], double value);
   int      ArrayUnshiftString  (string &array[], string value);

   bool     ArrayShiftBool      (bool   &array[]);
   int      ArrayShiftInt       (int    &array[]);
   double   ArrayShiftDouble    (double &array[]);
   string   ArrayShiftString    (string &array[]);

   int      ArrayDropBool       (bool   &array[], bool   value);
   int      ArrayDropInt        (int    &array[], int    value);
   int      ArrayDropDouble     (double &array[], double value);
   int      ArrayDropString     (string &array[], string value);

   int      ArraySpliceBools    (bool   &array[], int offset, int length);
   int      ArraySpliceInts     (int    &array[], int offset, int length);
   int      ArraySpliceDoubles  (double &array[], int offset, int length);
   int      ArraySpliceStrings  (string &array[], int offset, int length);

   int      ArrayInsertBool       (bool   &array[],   int offset, bool   value   );
   int      ArrayInsertBools      (bool   &array[],   int offset, bool   values[]);
   int      ArrayInsertInt        (int    &array[],   int offset, int    value   );
   int      ArrayInsertInts       (int    &array[],   int offset, int    values[]);
   int      ArrayInsertDouble     (double &array[],   int offset, double value   );
   int      ArrayInsertDoubles    (double &array[],   int offset, double values[]);
   int      ArrayInsertDoubleArray(double &array[][], int offset, double values[]);
   int      ArrayInsertString     (string &array[],   int offset, string value   );
   int      ArrayInsertStrings    (string &array[],   int offset, string values[]);

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

   bool     ReverseBoolArray  (bool   &array[]);
   bool     ReverseIntArray   (int    &array[]);
   bool     ReverseDoubleArray(double &array[]);
   bool     ReverseStringArray(string &array[]);

   bool     IsReverseIndexedBoolArray  (bool   array[]);
   bool     IsReverseIndexedIntArray   (int    array[]);
   bool     IsReverseIndexedDoubleArray(double array[]);
   bool     IsReverseIndexedSringArray (string array[]);

   int      MergeBoolArrays  (bool   array1[], bool   array2[], bool   &merged[]);
   int      MergeIntArrays   (int    array1[], int    array2[], int    &merged[]);
   int      MergeDoubleArrays(double array1[], double array2[], double &merged[]);
   int      MergeStringArrays(string array1[], string array2[], string &merged[]);

   double   SumDoubles(double array[]);


   // buffer functions
   int      InitializeDoubleBuffer(double buffer[], int size);

   string   BufferToStr   (int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int chr);

   string   BufferWCharsToStr(int buffer[], int from, int length);  //string BufferGetStringW(int buffer[], int from, int length);     // alias


   // configuration
   int      GetIniSections(string fileName, string &names[]);


   // date/time
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

   datetime GetSessionStartTime(datetime time, int tz);
   datetime GetSessionEndTime  (datetime time, int tz);

   datetime GetPrevSessionStartTime(datetime time, int tz);
   datetime GetPrevSessionEndTime  (datetime time, int tz);

   datetime GetNextSessionStartTime.fxt(datetime fxtTime   );
   datetime GetNextSessionStartTime.gmt(datetime gmtTime   );
   datetime GetNextSessionStartTime.srv(datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetNextSessionEndTime.fxt  (datetime fxtTime   );
   datetime GetNextSessionEndTime.gmt  (datetime gmtTime   );
   datetime GetNextSessionEndTime.srv  (datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG


   // colors
   color    RGB(int red, int green, int blue);
   int      RGBToHSL(color rgb, double hsl[], bool human = false);
   color    HSLToRGB(double hsl[3]);
   color    ModifyColor(color rgb, double hue, double saturation, double lightness);


   // files, i/o
   string   CreateTempFile(string path, string prefix="");
   string   GetTempPath();

   int      FindFileNames(string pattern, string results[], int flags);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   bool     EditFile(string filename);
   bool     EditFiles(string filenames[]);


   // locking
   bool     AquireLock(string mutexName, bool wait);
   bool     ReleaseLock(string mutexName);


   // strings
   bool     SortStrings(string &values[]);
   string   StringPad(string input, int length, string pad_string, int pad_type);


   // trade functions and order handling
   bool     IsTemporaryTradeError(int error);

   // s: StopDistance/FreezeDistance check integrated
   int /*s*/OrderSendEx(string symbol, int type, double lots, double price, int slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool/*s*/OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool     OrderDeleteEx(int ticket, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseEx(int ticket, double lots, int slippage, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, int oe[]);
   bool     OrdersClose(int tickets[], int slippage, color markerColor, int oeFlags, int oes[][]);
   bool     OrdersCloseSameSymbol(int tickets[], int slippage, color markerColor, int oeFlags, int oes[][]);
   int      OrdersHedge(int tickets[], int slippage, int oeFlags, int oes[][]);
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


   // other
   int      CreateRawSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string directory = "");
   bool     IsRawSymbol(string symbol, string directory = "");

   string   GetSymbolName(string symbol);                               // alias of GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                           // alias of GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   bool     ObjectCreateRegister(string name, int type, int window, datetime time1, double price1, datetime time2, double price2, datetime time3, double price3);
   int      DeleteRegisteredObjects();

   bool     SortOpenTickets(int &keys[][]);
   int      SortTicketsChronological(int &tickets[]);


   // toString helpers
   string   CharToHexStr(int chr);
   string   DoubleToStrEx(double value, int digits/*=0..16*/);
   string   IntegerToBinaryStr(int integer);
   string   IntegerToHexStr(int decimal);
   string   WaitForSingleObjectValueToStr(int value);
   string   WordToHexStr(int word);

   string   BoolsToStr             (bool array[], string separator);
   string   CharsToStr              (int array[], string separator);
   string   DoublesToStr         (double array[], string separator);
   string   DoublesToStrEx       (double array[], string separator, int digits/*=0..16*/);
   string   IntsToStr               (int array[], string separator);
   string   MoneysToStr          (double array[], string separator);
   string   OperationTypesToStr     (int array[], string separator);
   string   PricesToStr          (double array[], string separator);    // alias of RatesToStr()
   string   RatesToStr           (double array[], string separator);
   string   StringsToStr         (string array[], string separator);
   string   TicketsToStr            (int array[], string separator);
   string   TicketsToStr.Lots       (int array[], string separator);
   string   TicketsToStr.LotsSymbols(int array[], string separator);
   string   TicketsToStr.Position   (int array[]);
   string   TimesToStr         (datetime array[], string separator);


   // other
   bool     DoubleQuoteStrings(string &array[]);
   string   GetWindowsShortcutTarget(string lnkFile);
   int      WinExecWait(string cmdLine, int cmdShow);
#import


// ShowWindow() constants for WinExecWait(), @see win32api.mqh
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
