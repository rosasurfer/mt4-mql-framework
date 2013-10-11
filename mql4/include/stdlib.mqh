/**
 * NOTE: Headerdatei und Library sind kompatibel zu den Original-MetaQuotes-Versionen.
 */
#import "stdlib.ex4"

   // MQL-Status- und Laufzeitumgebungs-Informationen
   bool     IsExpert();
   bool     Expert.IsTesting();

   bool     IsIndicator();
   bool     Indicator.IsTesting();
   int      Indicator.InitExecutionContext(/*EXECUTION_CONTEXT*/int ec[]);
   bool     Indicator.IsSuperContext();

   bool     IsScript();
   bool     Script.IsTesting();

   bool     IsLibrary();
   bool     This.IsTesting();                                        // Shortkey für: Expert.IsTesting() || Indicator.IsTesting() || Script.IsTesting()

   bool     IsLogging();
   int      SetCustomLog(int id, string file);
   int      GetCustomLogID();
   string   GetCustomLogFile(int id);

   bool     IsError(int value);
   bool     IsErrorCode(int value);
   int      SetLastError(int error, int param);
   int      stdlib_GetLastError();

   string   GetTerminalVersion();
   int      GetTerminalBuild();
   int      GetApplicationWindow();
   int      GetTesterWindow();
   int      GetUIThreadId();
   string   GetServerDirectory();

   bool     Tester.IsPaused();
   bool     Tester.IsStopped();


   // Account-Informationen
   int      GetAccountNumber();
   string   ShortAccountCompany();
   string   GetServerTimezone();                                     // throws ERR_INVALID_TIMEZONE_CONFIG
   double   GetCommission();
   int      DebugMarketInfo(string location);


   // Terminal-Interaktionen
   int      Toolbar.Experts(bool enable);
   int      Chart.Expert.Properties();
   int      Chart.Refresh(bool sound);
   int      Chart.SendTick(bool sound);
   int      MarketWatch.Symbols();
   int      Tester.Pause();
   int      Tester.Stop();


   // Arrays
   int      ArraySetIntArray(int array[][], int i, int values[]);

   int      ArrayPushBool    (bool   array[],   bool   value   );
   int      ArrayPushInt     (int    array[],   int    value   );
   int      ArrayPushIntArray(int    array[][], int    values[]);
   int      ArrayPushDouble  (double array[],   double value   );
   int      ArrayPushString  (string array[],   string value   );

   bool     ArrayPopBool  (bool   array[]);
   int      ArrayPopInt   (int    array[]);
   double   ArrayPopDouble(double array[]);
   string   ArrayPopString(string array[]);

   int      ArrayUnshiftBool  (bool   array[], bool   value);
   int      ArrayUnshiftInt   (int    array[], int    value);
   int      ArrayUnshiftDouble(double array[], double value);
   int      ArrayUnshiftString(string array[], string value);

   bool     ArrayShiftBool  (bool   array[]);
   int      ArrayShiftInt   (int    array[]);
   double   ArrayShiftDouble(double array[]);
   string   ArrayShiftString(string array[]);

   int      ArrayDropBool  (bool   array[], bool   value);
   int      ArrayDropInt   (int    array[], int    value);
   int      ArrayDropDouble(double array[], double value);
   int      ArrayDropString(string array[], string value);

   int      ArraySpliceBools    (bool   array[],   int offset, int length);
   int      ArraySpliceInts     (int    array[],   int offset, int length);
   int      ArraySpliceIntArrays(int    array[][], int offset, int length);
   int      ArraySpliceDoubles  (double array[],   int offset, int length);
   int      ArraySpliceStrings  (string array[],   int offset, int length);

   int      ArrayInsertBool   (bool   array[], int offset, bool   values  );
   int      ArrayInsertBools  (bool   array[], int offset, bool   values[]);
   int      ArrayInsertDouble (double array[], int offset, double values  );
   int      ArrayInsertDoubles(double array[], int offset, double values[]);
   int      ArrayInsertInt    (int    array[], int offset, int    values  );
   int      ArrayInsertInts   (int    array[], int offset, int    values[]);
   int      ArrayInsertString (string array[], int offset, string values  );
   int      ArrayInsertStrings(string array[], int offset, string values[]);

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

   string   JoinBools  (bool   array[], string separator);
   string   JoinInts   (int    array[], string separator);
   string   JoinDoubles(double array[], string separator);
   string   JoinStrings(string array[], string separator);
   int      DoubleQuoteStrings(string array[]);

   int      SumInts   (int    array[]);
   double   SumDoubles(double array[]);


   // Buffer-Funktionen
   int      InitializeCharBuffer  (int    buffer[], int length);  int InitializeByteBuffer(int buffer[], int length);                  // Alias
   int      InitializeDoubleBuffer(double buffer[], int size  );
   int      InitializeStringBuffer(string buffer[], int length);

   string   BufferToStr   (int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int char);

   string   BufferCharsToStr (int buffer[], int from, int length);  //string BufferGetStringA(int buffer[], int from, int length);     // Alias
   string   BufferWCharsToStr(int buffer[], int from, int length);  //string BufferGetStringW(int buffer[], int from, int length);     // Alias

   int      ExplodeStringsA(int buffer[], string results[]);   int ExplodeStrings(int buffer[], string results[]);                     // Alias
   int      ExplodeStringsW(int buffer[], string results[]);


   // Conditional Statements
   bool     ifBool  (bool condition, bool   bThen, bool   bElse);
   int      ifInt   (bool condition, int    iThen, int    iElse);
   double   ifDouble(bool condition, double dThen, double dElse);
   string   ifString(bool condition, string sThen, string sElse);


   // Configuration
   string   GetLocalConfigPath();
   string   GetGlobalConfigPath();

   bool     IsConfigKey      (string section, string key);
   bool     IsLocalConfigKey (string section, string key);
   bool     IsGlobalConfigKey(string section, string key);

   bool     GetConfigBool  (string section, string key, bool   defaultValue);
   int      GetConfigInt   (string section, string key, int    defaultValue);
   double   GetConfigDouble(string section, string key, double defaultValue);
   string   GetConfigString(string section, string key, string defaultValue);

   bool     GetLocalConfigBool  (string section, string key, bool   defaultValue);
   int      GetLocalConfigInt   (string section, string key, int    defaultValue);
   double   GetLocalConfigDouble(string section, string key, double defaultValue);
   string   GetLocalConfigString(string section, string key, string defaultValue);

   bool     GetGlobalConfigBool  (string section, string key, bool   defaultValue);
   int      GetGlobalConfigInt   (string section, string key, int    defaultValue);
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   string   GetGlobalConfigString(string section, string key, string defaultValue);


   // Date/Time
   datetime FXTToGMT(datetime fxtTime);
   datetime FXTToServerTime(datetime fxtTime);                                                              // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GMTToFXT(datetime gmtTime);
   datetime GMTToServerTime(datetime gmtTime);                                                              // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime ServerToFXT(datetime serverTime);                                                               // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime ServerToGMT(datetime serverTime);                                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetFXTToGMTOffset(datetime fxtTime);
   int      GetFXTToServerTimeOffset(datetime fxtTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetGMTToFXTOffset(datetime gmtTime);
   int      GetGMTToServerTimeOffset(datetime gmtTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetServerToFXTOffset(datetime serverTime);                                                      // throws ERR_INVALID_TIMEZONE_CONFIG
   int      GetServerToGMTOffset(datetime serverTime);                                                      // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetLocalToGMTOffset();

   datetime GetFXTPrevSessionStartTime(datetime fxtTime);
   datetime GetFXTPrevSessionEndTime(datetime fxtTime);
   datetime GetFXTSessionStartTime(datetime fxtTime);                                                       // throws ERR_MARKET_CLOSED
   datetime GetFXTSessionEndTime(datetime fxtTime);                                                         // throws ERR_MARKET_CLOSED
   datetime GetFXTNextSessionStartTime(datetime fxtTime);
   datetime GetFXTNextSessionEndTime(datetime fxtTime);

   datetime GetGMTPrevSessionStartTime(datetime gmtTime);
   datetime GetGMTPrevSessionEndTime(datetime gmtTime);
   datetime GetGMTSessionStartTime(datetime gmtTime);                                                       // throws ERR_MARKET_CLOSED
   datetime GetGMTSessionEndTime(datetime gmtTime);                                                         // throws ERR_MARKET_CLOSED
   datetime GetGMTNextSessionStartTime(datetime gmtTime);
   datetime GetGMTNextSessionEndTime(datetime gmtTime);

   datetime GetServerPrevSessionStartTime(datetime serverTime);                                             // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerPrevSessionEndTime(datetime serverTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerSessionStartTime(datetime serverTime);                                                 // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   datetime GetServerSessionEndTime(datetime serverTime);                                                   // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   datetime GetServerNextSessionStartTime(datetime serverTime);                                             // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerNextSessionEndTime(datetime serverTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   string   GetDayOfWeek(datetime time, bool longFormat);
   datetime GetLocalTimeEx();
   datetime GetSystemTimeEx(); datetime TimeGMT();                                                          // Alias
   bool     GetServerTimezoneTransitions(datetime serverTime, int lastTransition[], int nextTransition[]);  // throws ERR_INVALID_TIMEZONE_CONFIG


   // Event-Listener: *können* bei Verwendung im Programm durch alternative/effizientere Versionen überschrieben werden
   bool     EventListener.BarOpen        (int    data[], int criteria);
   bool     EventListener.AccountChange  (int    data[], int criteria);
   bool     EventListener.AccountPayment (int    data[], int criteria);
   bool     EventListener.OrderPlace     (int    data[], int criteria);
   bool     EventListener.OrderChange    (int    data[], int criteria);
   bool     EventListener.OrderCancel    (int    data[], int criteria);
   bool     EventListener.PositionOpen   (int    data[], int criteria);
   bool     EventListener.PositionClose  (int    data[], int criteria);
   bool     EventListener.ChartCommand   (string data[], int criteria);
   bool     EventListener.InternalCommand(string data[], int criteria);
   bool     EventListener.ExternalCommand(string data[], int criteria);


   // "abstrakte" Event-Handler: *müssen* bei Verwendung im Programm implementiert werden
   /*abstract*/ int onBarOpen        (int    data[]);
   /*abstract*/ int onAccountChange  (int    data[]);
   /*abstract*/ int onAccountPayment (int    data[]);
   /*abstract*/ int onOrderPlace     (int    data[]);
   /*abstract*/ int onOrderChange    (int    data[]);
   /*abstract*/ int onOrderCancel    (int    data[]);
   /*abstract*/ int onPositionOpen   (int    data[]);
   /*abstract*/ int onPositionClose  (int    data[]);
   /*abstract*/ int onChartCommand   (string data[]);
   /*abstract*/ int onInternalCommand(string data[]);
   /*abstract*/ int onExternalCommand(string data[]);


   // Farben
   color    RGB(int red, int green, int blue);

   int      RGBToHSVColor(color rgb, double hsv[]);
   int      RGBValuesToHSVColor(int red, int green, int blue, double hsv[]);

   color    HSVToRGBColor(double hsv[]);
   color    HSVValuesToRGBColor(double hue, double saturation, double value);

   color    Color.ModifyHSV(color rgb, double hue, double saturation, double value);

   string   ColorToStr(color rgb);
   string   ColorToRGBStr(color rgb);
   string   ColorToHtmlStr(color rgb);


   // Files, I/O
   bool     IsFile(string filename);
   bool     IsDirectory(string filename);
   bool     IsMqlFile(string filename);
   bool     IsMqlDirectory(string filename);
   int      FindFileNames(string pattern, string results[], int flags);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   int      GetPrivateProfileSectionNames(string fileName, string names[]);
   int      GetPrivateProfileKeys(string fileName, string section, string keys[]);
   string   GetPrivateProfileString(string fileName, string section, string key, string defaultValue);
   int      DeletePrivateProfileKey(string fileName, string section, string key);


   // Locks
   bool     AquireLock(string mutexName);
   bool     ReleaseLock(string mutexName);
   bool     ReleaseLocks(bool warn);


   // MagicNumbers
   int      StrategyId(int magicNumber);
   string   LFX.Currency(int magicNumber);
   int      LFX.CurrencyId(int magicNumber);
   int      LFX.Counter(int magicNumber);
   double   LFX.Units(int magicNumber);
   int      LFX.Instance(int magicNumber);


   // Math, Numbers
   bool     EQ(double a, double b, int digits); bool CompareDoubles(double a, double b);  // MetaQuotes-Alias
   bool     NE(double a, double b, int digits);

   bool     LT(double a, double b, int digits);
   bool     LE(double a, double b, int digits);

   bool     GT(double a, double b, int digits);
   bool     GE(double a, double b, int digits);

   double   MathModFix(double a, double b);
   int      CountDecimals(double value);

   int      Abs(int value);
   int      Min(int a, int b);
   int      Max(int a, int b);
   int      Floor     (double value);
   int      Ceil      (double value);
   int      Sign      (double value);
   int      Round     (double value);
   double   RoundEx   (double value, int decimals);
   double   RoundFloor(double value, int decimals);
   double   RoundCeil (double value, int decimals);


   // Strings
   string   CreateString(int length);
   string   StringToStr(string value);

   bool     StringIsDigit(string value);
   bool     StringIsInteger(string value);
   bool     StringIsNumeric(string value);
   bool     StringIsNull(string value);

   bool     StringContains(string object, string substring);
   bool     StringIContains(string object, string substring);

   bool     StringStartsWith(string object, string prefix);
   bool     StringIStartsWith(string object, string prefix);
   bool     StringEndsWith(string object, string postfix);
   bool     StringIEndsWith(string object, string postfix);
   bool     StringICompare(string a, string b);

   string   StringLeft(string value, int n);
   string   StringRight(string value, int n);

   string   StringTrim(string value);
   string   StringLeftPad (string input, int length, string pad_string);
   string   StringRightPad(string input, int length, string pad_string);
   string   StringPad     (string input, int length, string pad_string, int pad_type);

   string   StringToLower(string value);
   string   StringToUpper(string value);

   int      StringFindR(string object, string search);
   string   StringRepeat(string input, int times);
   string   StringReplace(string object, string search, string replace);
   string   StringSubstrFix(string object, int start, int length);

   int      Explode(string input, string separator, string results[], int limit);
   string   UrlEncode(string value);


   // Tradefunktionen, Orderhandling
   bool     IsTemporaryTradeError(int error);
   bool     IsPermanentTradeError(int error);
   bool     IsTradeOperation(int value);
   bool     IsLongTradeOperation(int value);
   bool     IsShortTradeOperation(int value);
   bool     IsPendingTradeOperation(int value);

   // s: StopDistance/FreezeDistance integriert
   int /*s*/OrderSendEx(string symbol, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool/*s*/OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, int oe[]);
   bool     OrderDeleteEx(int ticket, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, int oeFlags, int oe[]);
   bool     OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, int oe[]);
   bool     OrderMultiClose(int tickets[], double slippage, color markerColor, int oeFlags, int oes[][]);
   bool     DeletePendingOrders(color markerColor);

   int      OrderPush(string location);
   bool     OrderPop(string location);
   bool     SelectTicket(int ticket, string location, bool orderPush, bool onErrorOrderPop);
   bool     WaitForTicket(int ticket, bool orderKeep);

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
   int      GetAccountHistory(int account, string results[]);
   int      GetBalanceHistory(int account, datetime times[], double values[]);
   double   PipValue(double lots, bool hideErrors);
   int      SortTicketsChronological(int tickets[]);

   string   GetCurrency(int id);
   int      GetCurrencyId(string currency);

   string   StdSymbol();                                                               // Alias für GetStandardSymbol(Symbol())
   string   GetStandardSymbol(string symbol);                                          // Alias für GetStandardSymbolOrAlt(symbol, symbol)
   string   GetStandardSymbolOrAlt(string symbol, string altValue);
   string   GetStandardSymbolStrict(string symbol);

   string   GetSymbolName(string symbol);                                              // Alias für GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                                          // Alias für GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   int      MovingAverageMethodToId(string method);
   int      PeriodFlag(int period);
   int      PeriodToId(string description);  int TimeframeToId(string description);    // Alias

   string   CreateLegendLabel(string name);
   int      RepositionLegend();
   bool     ObjectDeleteSilent(string label, string location);
   int      PushObject(string label);
   int      RemoveChartObjects();

   int      iAccountBalance(int account, double buffer[], int bar);
   int      iAccountBalanceSeries(int account, double buffer[]);
   int      iBarShiftNext(string symbol, int period, datetime time);                   // throws ERS_HISTORY_UPDATE
   int      iBarShiftPrevious(string symbol, int period, datetime time);               // throws ERS_HISTORY_UPDATE

   int      ForceMessageBox(string caption, string message, int flags);
   int      ForceSound(string soundfile);
   int      SendSMS(string receiver, string message);


   // toString-Funktionen
   string   BoolToStr(bool value);
   string   DoubleToStrEx(double value, int digits);  string DoubleToStrMorePrecision(double value, int precision);     // MetaQuotes-Alias

   string   IntegerToBinaryStr(int integer);

   string   IntegerToHexStr(int integer);
   string   ByteToHexStr(int byte);   string CharToHexStr(int char);                                                    // Alias
   string   WordToHexStr(int word);
   string   DwordToHexStr(int dword); string IntToHexStr(int integer); string IntegerToHexString(int integer);          // Alias + MetaQuotes-Alias
   string   StringToHexStr(string value);

   string   BoolsToStr        (bool array[], string separator);
   string   IntsToStr          (int array[], string separator);
   string   CharsToStr         (int array[], string separator);
   string   OperationTypesToStr(int array[], string separator);
   string   TimesToStr    (datetime array[], string separator);
   string   DoublesToStr    (double array[], string separator);
   string   MoneysToStr     (double array[], string separator);
   string   RatesToStr      (double array[], string separator); string PricesToStr(double array[], string separator);   // Alias
   string   StringsToStr    (string array[], string separator);

   string   AppliedPriceDescription(int appliedPrice);
   string   AppliedPriceToStr      (int appliedPrice);
   string   ChartPropertiesToStr(int flags);
   string   InitFlagsToStr  (int flags);
   string   DateToStr(datetime time, string mask);
   string   DeinitFlagsToStr(int flags);
   string   ErrorDescription(int error);
   string   ErrorToStr      (int error);
   string   EventToStr(int event);
   string   FileAccessModeToStr(int mode);
   string   MessageBoxCmdToStr(int cmd);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr      (int type);
   string   MovingAverageMethodDescription(int method);
   string   MovingAverageMethodToStr      (int method);
   string   NumberToStr(double number, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr      (int type);
   string   ORDER_EXECUTION.toStr(/*ORDER_EXECUTION*/int oe[], bool debugOutput=false);
   string   PeriodFlagToStr(int flag);
   string   PeriodDescription(int period);      string TimeframeDescription(int timeframe);     // Alias
   string   PeriodToStr      (int period);      string TimeframeToStr      (int timeframe);     // Alias
   string   ShellExecuteErrorToStr(int error);
   string   UninitializeReasonDescription(int reason);
   string   UninitializeReasonToStr      (int reason);
   string   WaitForSingleObjectValueToStr(int value);
   string   __whereamiToStr(int id);


   // MQL-Structs Getter und Setter
   int      oe.Error             (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Error             (/*ORDER_EXECUTION*/int oe[][], int i);
   string   oe.Symbol            (/*ORDER_EXECUTION*/int oe[]);                       string   oes.Symbol            (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.Digits            (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Digits            (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.StopDistance      (/*ORDER_EXECUTION*/int oe[]);                       double   oes.StopDistance      (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.FreezeDistance    (/*ORDER_EXECUTION*/int oe[]);                       double   oes.FreezeDistance    (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Bid               (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Bid               (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Ask               (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Ask               (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.Ticket            (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Ticket            (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.Type              (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Type              (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Lots              (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Lots              (/*ORDER_EXECUTION*/int oe[][], int i);
   datetime oe.OpenTime          (/*ORDER_EXECUTION*/int oe[]);                       datetime oes.OpenTime          (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.OpenPrice         (/*ORDER_EXECUTION*/int oe[]);                       double   oes.OpenPrice         (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.StopLoss          (/*ORDER_EXECUTION*/int oe[]);                       double   oes.StopLoss          (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.TakeProfit        (/*ORDER_EXECUTION*/int oe[]);                       double   oes.TakeProfit        (/*ORDER_EXECUTION*/int oe[][], int i);
   datetime oe.CloseTime         (/*ORDER_EXECUTION*/int oe[]);                       datetime oes.CloseTime         (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.ClosePrice        (/*ORDER_EXECUTION*/int oe[]);                       double   oes.ClosePrice        (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Swap              (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Swap              (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Commission        (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Commission        (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Profit            (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Profit            (/*ORDER_EXECUTION*/int oe[][], int i);
   string   oe.Comment           (/*ORDER_EXECUTION*/int oe[]);                       string   oes.Comment           (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.Duration          (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Duration          (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.Requotes          (/*ORDER_EXECUTION*/int oe[]);                       int      oes.Requotes          (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.Slippage          (/*ORDER_EXECUTION*/int oe[]);                       double   oes.Slippage          (/*ORDER_EXECUTION*/int oe[][], int i);
   int      oe.RemainingTicket   (/*ORDER_EXECUTION*/int oe[]);                       int      oes.RemainingTicket   (/*ORDER_EXECUTION*/int oe[][], int i);
   double   oe.RemainingLots     (/*ORDER_EXECUTION*/int oe[]);                       double   oes.RemainingLots     (/*ORDER_EXECUTION*/int oe[][], int i);

   int      oe.setError          (/*ORDER_EXECUTION*/int oe[], int      error     );  int      oes.setError          (/*ORDER_EXECUTION*/int oe[][], int i, int      error     );
   string   oe.setSymbol         (/*ORDER_EXECUTION*/int oe[], string   symbol    );  string   oes.setSymbol         (/*ORDER_EXECUTION*/int oe[][], int i, string   symbol    );
   int      oe.setDigits         (/*ORDER_EXECUTION*/int oe[], int      digits    );  int      oes.setDigits         (/*ORDER_EXECUTION*/int oe[][], int i, int      digits    );
   double   oe.setStopDistance   (/*ORDER_EXECUTION*/int oe[], double   distance  );  double   oes.setStopDistance   (/*ORDER_EXECUTION*/int oe[][], int i, double   distance  );
   double   oe.setFreezeDistance (/*ORDER_EXECUTION*/int oe[], double   distance  );  double   oes.setFreezeDistance (/*ORDER_EXECUTION*/int oe[][], int i, double   distance  );
   double   oe.setBid            (/*ORDER_EXECUTION*/int oe[], double   bid       );  double   oes.setBid            (/*ORDER_EXECUTION*/int oe[][], int i, double   bid       );
   double   oe.setAsk            (/*ORDER_EXECUTION*/int oe[], double   ask       );  double   oes.setAsk            (/*ORDER_EXECUTION*/int oe[][], int i, double   ask       );
   int      oe.setTicket         (/*ORDER_EXECUTION*/int oe[], int      ticket    );  int      oes.setTicket         (/*ORDER_EXECUTION*/int oe[][], int i, int      ticket    );
   int      oe.setType           (/*ORDER_EXECUTION*/int oe[], int      type      );  int      oes.setType           (/*ORDER_EXECUTION*/int oe[][], int i, int      type      );
   double   oe.setLots           (/*ORDER_EXECUTION*/int oe[], double   lots      );  double   oes.setLots           (/*ORDER_EXECUTION*/int oe[][], int i, double   lots      );
   datetime oe.setOpenTime       (/*ORDER_EXECUTION*/int oe[], datetime openTime  );  datetime oes.setOpenTime       (/*ORDER_EXECUTION*/int oe[][], int i, datetime openTime  );
   double   oe.setOpenPrice      (/*ORDER_EXECUTION*/int oe[], double   openPrice );  double   oes.setOpenPrice      (/*ORDER_EXECUTION*/int oe[][], int i, double   openPrice );
   double   oe.setStopLoss       (/*ORDER_EXECUTION*/int oe[], double   stopLoss  );  double   oes.setStopLoss       (/*ORDER_EXECUTION*/int oe[][], int i, double   stopLoss  );
   double   oe.setTakeProfit     (/*ORDER_EXECUTION*/int oe[], double   takeProfit);  double   oes.setTakeProfit     (/*ORDER_EXECUTION*/int oe[][], int i, double   takeProfit);
   datetime oe.setCloseTime      (/*ORDER_EXECUTION*/int oe[], datetime closeTime );  datetime oes.setCloseTime      (/*ORDER_EXECUTION*/int oe[][], int i, datetime closeTime );
   double   oe.setClosePrice     (/*ORDER_EXECUTION*/int oe[], double   closePrice);  double   oes.setClosePrice     (/*ORDER_EXECUTION*/int oe[][], int i, double   closePrice);
   double   oe.setSwap           (/*ORDER_EXECUTION*/int oe[], double   swap      );  double   oes.setSwap           (/*ORDER_EXECUTION*/int oe[][], int i, double   swap      );
   double   oe.addSwap           (/*ORDER_EXECUTION*/int oe[], double   swap      );  double   oes.addSwap           (/*ORDER_EXECUTION*/int oe[][], int i, double   swap      );
   double   oe.setCommission     (/*ORDER_EXECUTION*/int oe[], double   comission );  double   oes.setCommission     (/*ORDER_EXECUTION*/int oe[][], int i, double   comission );
   double   oe.addCommission     (/*ORDER_EXECUTION*/int oe[], double   comission );  double   oes.addCommission     (/*ORDER_EXECUTION*/int oe[][], int i, double   comission );
   double   oe.setProfit         (/*ORDER_EXECUTION*/int oe[], double   profit    );  double   oes.setProfit         (/*ORDER_EXECUTION*/int oe[][], int i, double   profit    );
   double   oe.addProfit         (/*ORDER_EXECUTION*/int oe[], double   profit    );  double   oes.addProfit         (/*ORDER_EXECUTION*/int oe[][], int i, double   profit    );
   string   oe.setComment        (/*ORDER_EXECUTION*/int oe[], string   comment   );  string   oes.setComment        (/*ORDER_EXECUTION*/int oe[][], int i, string   comment   );
   int      oe.setDuration       (/*ORDER_EXECUTION*/int oe[], int      milliSec  );  int      oes.setDuration       (/*ORDER_EXECUTION*/int oe[][], int i, int      milliSec  );
   int      oe.setRequotes       (/*ORDER_EXECUTION*/int oe[], int      requotes  );  int      oes.setRequotes       (/*ORDER_EXECUTION*/int oe[][], int i, int      requotes  );
   double   oe.setSlippage       (/*ORDER_EXECUTION*/int oe[], double   slippage  );  double   oes.setSlippage       (/*ORDER_EXECUTION*/int oe[][], int i, double   slippage  );
   int      oe.setRemainingTicket(/*ORDER_EXECUTION*/int oe[], int      ticket    );  int      oes.setRemainingTicket(/*ORDER_EXECUTION*/int oe[][], int i, int      ticket    );
   double   oe.setRemainingLots  (/*ORDER_EXECUTION*/int oe[], double   lots      );  double   oes.setRemainingLots  (/*ORDER_EXECUTION*/int oe[][], int i, double   lots      );


   // Win32-Funktionen (an MQL angepaßt)
   void     CopyMemory(int destination, int source, int bytes);
   string   GetClassName(int hWnd);
   string   GetComputerName();
   string   GetWin32ShortcutTarget(string lnkFile);
   string   GetWindowText(int hWnd);
   int      LoadCursorById(int hInstance, int resourceId);
   int      LoadCursorByName(int hInstance, string cursorName);
   int      WinExecAndWait(string cmdLine, int cmdShow);
   int      WM_MT4();                                                // MetaTrader4_Internal_Message (wird wie Pseudo-Konstante benutzt)


   // Default-Implementierungen: müssen bei Verwendung im Programm implementiert werden
   int      onInit();
   int      onInitParameterChange();
   int      onInitChartChange();
   int      onInitAccountChange();
   int      onInitChartClose();
   int      onInitUndefined();
   int      onInitRemove();
   int      onInitRecompile();
   int      afterInit();

   int      onStart();                                               // Scripte
   int      onTick();                                                // EA's + Indikatoren
   int      ShowStatus(int error);                                   // EA's
   string   InputsToStr();
   void     DummyCalls();

   int      onDeinit();
   int      onDeinitParameterChange();
   int      onDeinitChartChange();
   int      onDeinitAccountChange();
   int      onDeinitChartClose();
   int      onDeinitUndefined();
   int      onDeinitRemove();
   int      onDeinitRecompile();
   int      afterDeinit();


   // erweiterte Root-Funktionen
   int      stdlib_init  (/*EXECUTION_CONTEXT*/int ec[], int tickData[]);
   int      stdlib_start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int      stdlib_deinit(/*EXECUTION_CONTEXT*/int ec[]);


#import "sample1.ex4"
   int      GetBoolsAddress  (bool   array[]);
#import "sample2.ex4"
   int      GetIntsAddress   (int    array[]);    int GetBufferAddress(int buffer[]); // Alias
#import "sample3.ex4"
   int      GetDoublesAddress(double array[]);
#import "sample4.ex4"
   int      GetStringsAddress(string array[]);
#import "sample5.ex4"
   int      GetStringAddress (string value);
#import "sample.dll"
   string   GetStringValue(int address);
#import "structs1.ex4"
   string   EXECUTION_CONTEXT.toStr(/*EXECUTION_CONTEXT*/int ec[], bool debugOutput);
   string   HISTORY_HEADER.toStr   (/*HISTORY_HEADER*/   int hh[], bool debugOutput);
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
