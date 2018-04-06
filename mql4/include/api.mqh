/**
 * Overview of available functions grouped by location (including DLL functions provided by the MT4Expander).
 * This file must not be included. It serves as a replacement if the development environment provides no cTags functionality.
 *
 * Note: The trailing semicolon is specific to UEStudio and activates the function browser.
 */


// stdfunctions.mqh
bool     _bool(bool param1, int param2=NULL, int param3=NULL, int param4=NULL);;
double   _double(double param1, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _EMPTY(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
string   _EMPTY_STR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _EMPTY_VALUE(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool     _false(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _int(int param1, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _last_error(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
datetime _NaT(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _NO_ERROR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int      _NULL(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
string   _string(string param1, int param2=NULL, int param3=NULL, int param4=NULL);;
bool     _true(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int      Abs(int value);;
string   AccountAlias(string accountCompany, int accountNumber);;
int      AccountCompanyId(string shortName);;
int      AccountNumberFromAlias(string accountCompany, string accountAlias);;
int      ArrayUnshiftString(string array[], string value);;
int      catch(string location, int error=NO_ERROR, bool orderPop=false);;
int      Ceil(double value);;
bool     Chart.DeleteValue(string key);;
int      Chart.Expert.Properties();;
int      Chart.Objects.UnselectAll();;
int      Chart.Refresh();;
int      Chart.SendTick(bool sound = false);;
bool     Chart.StoreBool(string key, bool value);;
bool     Chart.StoreDouble(string key, double value);;
bool     Chart.StoreInt(string key, int value);;
bool     Chart.StoreString(string key, string value);;
string   CharToHexStr(int char);;
string   ColorToHtmlStr(color rgb);;
string   ColorToStr(color value);;
double   CommissionValue(double lots = 1.0);;
void     CopyMemory(int destination, int source, int bytes);;
int      CountDecimals(double number);;
string   CreateString(int length);;
datetime DateTime(int year, int month=1, int day=1, int hours=0, int minutes=0, int seconds=0);;
int      debug(string message, int error = NO_ERROR);;
int      DebugMarketInfo(string location);;
bool     DeleteIniKey(string fileName, string section, string key);;
int      Div(int a, int b, int onZero = 0);;
bool     EnumChildWindows(int hWnd, bool recursive = false);;
bool     EQ(double double1, double double2, int digits = 8);;
string   ErrorDescription(int error);;
bool     EventListener.NewTick();;
string   FileAccessModeToStr(int mode);;
int      Floor(double value);;
void     ForceAlert(string message);;
bool     GE(double double1, double double2, int digits = 8);;
string   GetAccountConfigPath(string companyId, string accountId);;
string   GetClassName(int hWnd);;
bool     GetConfigBool(string section, string key, bool defaultValue = false);;
double   GetConfigDouble(string section, string key, double defaultValue = 0);;
int      GetConfigInt(string section, string key, int defaultValue = 0);;
string   GetConfigString(string section, string key, string defaultValue = "");;
string   GetCurrency(int id);;
int      GetCurrencyId(string currency);;
double   GetExternalAssets(string companyId, string accountId);;
datetime GetFxtTime();;
bool     GetGlobalConfigBool(string section, string key, bool defaultValue = false);;
double   GetGlobalConfigDouble(string section, string key, double defaultValue = 0);;
int      GetGlobalConfigInt(string section, string key, int defaultValue = 0);;
string   GetGlobalConfigString(string section, string key, string defaultValue = "");;
bool     GetIniBool(string fileName, string section, string key, bool defaultValue = false);;
double   GetIniDouble(string fileName, string section, string key, double defaultValue = 0);;
int      GetIniInt(string fileName, string section, string key, int defaultValue = 0);;
string   GetIniString(string fileName, string section, string key, string defaultValue = "");;
bool     GetLocalConfigBool(string section, string key, bool defaultValue = false);;
double   GetLocalConfigDouble(string section, string key, double defaultValue = 0);;
int      GetLocalConfigInt(string section, string key, int defaultValue = 0);;
string   GetLocalConfigString(string section, string key, string defaultValue = "");;
string   GetRawConfigString(string section, string key, string defaultValue = "");;
string   GetRawGlobalConfigString(string section, string key, string defaultValue = "");;
string   GetRawLocalConfigString(string section, string key, string defaultValue = "");;
datetime GetServerTime();;
bool     GT(double double1, double double2, int digits = 8);;
int      HandleEvent(int event);;
string   HistoryFlagsToStr(int flags);;
bool     ifBool(bool condition, bool thenValue, bool elseValue);;
double   ifDouble(bool condition, double thenValue, double elseValue);;
int      ifInt(bool condition, int thenValue, int elseValue);;
string   ifString(bool condition, string thenValue, string elseValue);;
int      InitReason();;
string   InitReasonDescription(int reason);;
bool     IsConfigKey(string section, string key);;
bool     IsCurrency(string value);;
bool     IsEmpty(double value);;
bool     IsEmptyString(string value);;
bool     IsEmptyValue(double value);;
bool     IsError(int value);;
bool     IsGlobalConfigKey(string section, string key);;
bool     IsInfinity(double value);;
bool     IsLastError();;
bool     IsLeapYear(int year);;
bool     IsLocalConfigKey(string section, string key);;
bool     IsLogging();;
bool     IsLongTradeOperation(int value);;
bool     IsMqlDirectory(string dirname);;
bool     IsMqlFile(string filename);;
bool     IsNaN(double value);;
bool     IsNaT(datetime value);;
bool     IsPendingTradeOperation(int value);;
bool     IsShortAccountCompany(string value);;
bool     IsShortTradeOperation(int value);;
bool     IsSuperContext();;
bool     IsTicket(int ticket);;
bool     IsTradeOperation(int value);;
bool     IsVisualModeFix();;
bool     LE(double double1, double double2, int digits = 8);;
int      log(string message, int error = NO_ERROR);;
bool     LogOrder(int ticket);;
bool     LogTicket(int ticket);;
bool     LT(double double1, double double2, int digits = 8);;
string   MaMethodDescription(int method);;
string   MaMethodToStr(int method);;
int      MarketWatch.Symbols();;
double   MathDiv(double a, double b, double onZero = 0);;
double   MathModFix(double a, double b);;
int      Max(int value1, int value2, int value3=INT_MIN, int value4=INT_MIN, int value5=INT_MIN, int value6=INT_MIN, int value7=INT_MIN, int value8=INT_MIN);;
string   MessageBoxButtonToStr(int id);;
int      MessageBoxEx(string caption, string message, int flags = MB_OK);;
int      Min(int value1, int value2, int value3=INT_MAX, int value4=INT_MAX, int value5=INT_MAX, int value6=INT_MAX, int value7=INT_MAX, int value8=INT_MAX);;
string   ModuleTypesToStr(int fType);;
string   MovingAverageMethodDescription(int method);;
string   MovingAverageMethodToStr(int method);;
bool     NE(double double1, double double2, int digits = 8);;
double   NormalizeLots(double lots);;
string   NumberToStr(double value, string mask);;
string   OperationTypeDescription(int type);;
string   OperationTypeToStr(int type);;
bool     OrderPop(string location);;
int      OrderPush(string location);;
string   OrderTypeDescription(int type);;
string   OrderTypeToStr(int type);;
int      PeriodFlag(int period = NULL);;
string   PeriodFlagsToStr(int flags);;
double   PipValue(double lots=1.0, bool suppressErrors=false);;
double   PipValueEx(string symbol, double lots=1.0, bool suppressErrors=false);;
bool     PlaySoundEx(string soundfile);;
string   PriceTypeDescription(int type);;
string   PriceTypeToStr(int type);;
string   QuoteStr(string value);;
double   RefreshExternalAssets(string companyId, string accountId);;
int      ResetLastError();;
int      Round(double value);;
double   RoundCeil(double number, int decimals = 0);;
double   RoundEx(double number, int decimals = 0);;
double   RoundFloor(double number, int decimals = 0);;
bool     SelectTicket(int ticket, string location, bool storeSelection=false, bool onErrorRestoreSelection=false);;
bool     SendEmail(string sender, string receiver, string subject, string message);;
bool     SendSMS(string receiver, string message);;
string   ShellExecuteErrorDescription(int error);;
string   ShortAccountCompany();;
string   ShortAccountCompanyFromId(int id);;
int      Sign(double number);;
int      start.RelaunchInputDialog();;
string   StringCapitalize(string value);;
bool     StringCompareI(string string1, string string2);;
bool     StringContains(string object, string substring);;
bool     StringContainsI(string object, string substring);;
bool     StringEndsWithI(string object, string suffix);;
int      StringFindR(string object, string search);;
bool     StringIsDigit(string value);;
bool     StringIsEmailAddress(string value);;
bool     StringIsInteger(string value);;
bool     StringIsNumeric(string value);;
bool     StringIsPhoneNumber(string value);;
string   StringLeft(string value, int n);;
string   StringLeftPad(string input, int pad_length, string pad_string = " ");;
string   StringLeftTo(string value, string substring, int count = 1);;
string   StringPadLeft(string input, int pad_length, string pad_string = " ");;
string   StringPadRight(string input, int pad_length, string pad_string = " ");;
string   StringRepeat(string input, int times);;
string   StringReplace(string object, string search, string replace);;
string   StringReplace.Recursive(string object, string search, string replace);;
string   StringRight(string value, int n);;
string   StringRightFrom(string value, string substring, int count = 1);;
string   StringRightPad(string input, int pad_length, string pad_string = " ");;
bool     StringStartsWith(string object, string prefix);;
bool     StringStartsWithI(string object, string prefix);;
string   StringSubstrFix(string object, int start, int length = INT_MAX);;
string   StringToHexStr(string value);;
string   StringToLower(string value);;
string   StringToUpper(string value);;
string   StringTrim(string value);;
bool     StrToBool(string value);;
int      StrToMaMethod(string value, int execFlags = NULL);;
int      StrToMovingAverageMethod(string value, int execFlags = NULL);;
int      StrToOperationType(string value);;
int      StrToPeriod(string value, int execFlags = NULL);;
int      StrToPriceType(string value, int execFlags = NULL);;
int      StrToTimeframe(string timeframe, int execFlags = NULL);;
int      StrToTradeDirection(string value, int execFlags = NULL);;
int      SumInts(int values[]);;
string   SwapCalculationModeToStr(int mode);;
bool     Tester.IsPaused();;
bool     Tester.IsStopped();;
int      Tester.Pause();;
bool     This.IsTesting();;
datetime TimeCurrentEx(string location = "");;
int      TimeDayFix(datetime time);;
int      TimeDayOfWeekFix(datetime time);;
int      TimeframeFlag(int timeframe = NULL);;
datetime TimeFXT();;
datetime TimeGMT();;
datetime TimeLocalEx(string location = "");;
datetime TimeServer();;
int      TimeYearFix(datetime time);;
int      Toolbar.Experts(bool enable);;
string   TradeCommandToStr(int cmd);;
string   UninitializeReasonDescription(int reason);;
string   UrlEncode(string value);;
bool     WaitForTicket(int ticket, bool orderKeep = true);;
int      warn(string message, int error = NO_ERROR);;
int      warnSMS(string message, int error = NO_ERROR);;
int      WM_MT4();;


// functions/@ALMA.mqh
void     @ALMA.CalculateWeights(double &weights[], int periods, double offset=0.85, double sigma=6.0);;


// functions/@ATR.mqh
double   @ATR(string symbol, int timeframe, int periods, int offset);;


// functions/@Bands.mqh
void     @Bands.SetIndicatorStyles(color mainColor, color bandsColor);;
void     @Bands.UpdateLegend(string legendLabel, string legendDescription, color bandsColor, double currentUpperValue, double currentLowerValue);;


// functions/@NLMA.mqh
bool     @NLMA.CalculateWeights(double &weights[], int cycles, int cycleLength);;


// functions/@Trend.mqh
void     @Trend.UpdateDirection(double values[], int bar, double &trend[], double &uptrend[], double &downtrend[], double &uptrend2[], int lineStyle, bool enableColoring=false, bool enableUptrend2=false, int normalizeDigits=EMPTY_VALUE);;
void     @Trend.UpdateLegend(string label, string name, string status, color uptrendColor, color downtrendColor, double value, int trend, datetime barOpenTime);;


// functions/Configure.Signal.Mail.mqh
bool     Configure.Signal.Mail(string config, bool &enabled, string &sender, string &receiver, bool muteErrors = false);;


// functions/Configure.Signal.SMS.mqh
bool     Configure.Signal.SMS(string config, bool &enabled, string &receiver, bool muteErrors = false);;


// functions/Configure.Signal.Sound.mqh
bool     Configure.Signal.Sound(string config, bool &enabled);;


// functions/EventListener.BarOpen.mqh
bool     EventListener.BarOpen(int timeframe = NULL);;


// functions/ExplodeStrings.mqh
int      ExplodeStrings(int buffer[], string &results[]);;


// functions/iBarShiftNext.mqh
int      iBarShiftNext(string symbol=NULL, int period=NULL, datetime time, int muteFlags=NULL);;


// functions/iBarShiftPrevious.mqh
int      iBarShiftPrevious(string symbol=NULL, int period=NULL, datetime time, int muteFlags=NULL);;


// functions/iChangedBars.mqh
int      iChangedBars(string symbol=NULL, int period=NULL, int muteFlags=NULL);;


// functions/InitializeByteBuffer.mqh
int      InitializeByteBuffer(int buffer[], int bytes);;


// functions/iPreviousPeriodTimes.mqh
bool     iPreviousPeriodTimes(int timeframe=NULL, datetime &openTime.fxt=NULL, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv);;


// functions/JoinBools.mqh
string   JoinBools(bool values[], string separator);;


// functions/JoinDoubles.mqh
string   JoinDoubles(double values[], string separator);;


// functions/JoinDoublesEx.mqh
string   JoinDoublesEx(double values[], string separator, int digits);;


// functions/JoinInts.mqh
string   JoinInts(int values[], string separator);;


// functions/JoinStrings.mqh
string   JoinStrings(string values[], string separator);;


// iCustom/icMACD.mqh
double   icMACD(int timeframe, int fastMaPeriods, string fastMaMethod, string fastMaAppliedPrice, int slowMaPeriods, string slowMaMethod, string slowMaAppliedPrice, int maxValues, int iBuffer, int iBar);;


// iCustom/icMovingAverage.mqh
double   icMovingAverage(int timeframe, int maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int maxValues, int iBuffer, int iBar);;


// iCustom/icNonLagMA.mqh
double   icNonLagMA(int timeframe, int cycleLength, int maxValues, int iBuffer, int iBar);;


// iCustom/icTrix.mqh
double   icTrix(int timeframe, int emaPeriods, string emaAppliedPrice, int iBuffer, int iBar);;


// scriptrunner.mqh
bool     RunScript(string name, string parameters = "");;
bool     ScriptRunner.GetParameters(string parameters[]);;
bool     ScriptRunner.SetParameters(string parameters);;


// stdlib1.ex4
bool     AquireLock(string mutexName, bool wait);;
int      ArrayDropBool(bool array[], bool value);;
int      ArrayDropDouble(double array[], double value);;
int      ArrayDropInt(int array[], int value);;
int      ArrayDropString(string array[], string value);;
int      ArrayInsertBool(bool &array[], int offset, bool value);;
int      ArrayInsertBools(bool array[], int offset, bool values[]);;
int      ArrayInsertDouble(double &array[], int offset, double value);;
int      ArrayInsertDoubles(double array[], int offset, double values[]);;
int      ArrayInsertInt(int &array[], int offset, int value);;
int      ArrayInsertInts(int array[], int offset, int values[]);;
bool     ArrayPopBool(bool array[]);;
double   ArrayPopDouble(double array[]);;
int      ArrayPopInt(int array[]);;
string   ArrayPopString(string array[]);;
int      ArrayPushBool(bool &array[], bool value);;
int      ArrayPushDouble(double &array[], double value);;
int      ArrayPushInt(int &array[], int value);;
int      ArrayPushInts(int array[][], int value[]);;
int      ArrayPushString(string &array[], string value);;
int      ArraySetInts(int array[][], int offset, int values[]);;
bool     ArrayShiftBool(bool array[]);;
double   ArrayShiftDouble(double array[]);;
int      ArrayShiftInt(int array[]);;
string   ArrayShiftString(string array[]);;
int      ArraySpliceBools(bool array[], int offset, int length);;
int      ArraySpliceDoubles(double array[], int offset, int length);;
int      ArraySpliceInts(int array[], int offset, int length);;
int      ArraySpliceStrings(string array[], int offset, int length);;
int      ArrayUnshiftBool(bool array[], bool value);;
int      ArrayUnshiftDouble(double array[], double value);;
int      ArrayUnshiftInt(int array[], int value);;
bool     BoolInArray(bool haystack[], bool needle);;
int      BufferGetChar(int buffer[], int pos);;
string   BufferToHexStr(int buffer[]);;
string   BufferToStr(int buffer[]);;
string   BufferWCharsToStr(int buffer[], int from, int length);;
string   ByteToHexStr(int byte);;
bool     ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor);;
bool     ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);;
bool     ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor);;
bool     ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment);;
bool     ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeprofit);;
bool     ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment);;
bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);;
bool     ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment);;
bool     ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor);;
bool     ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);;
color    Color.ModifyHSV(color rgb, double mod_hue, double mod_saturation, double mod_value);;
string   CreateLegendLabel(string name);;
string   CreateTempFile(string path, string prefix = "");;
string   DateTimeToStr(datetime time, string mask);;
int      DecreasePeriod(int period = 0);;
bool     DeletePendingOrders(color markerColor = CLR_NONE);;
int      DeleteRegisteredObjects(string prefix = NULL);;
bool     DoubleInArray(double haystack[], double needle);;
string   DoubleToStrEx(double value, int digits);;
bool     EditFile(string filename);;
bool     EditFiles(string filenames[]);;
bool     EventListener.ChartCommand(string commands[]);;
int      Explode(string input, string separator, string &results[], int limit = NULL);;
int      FileReadLines(string filename, string result[], bool skipEmptyLines = false);;
int      FindFileNames(string pattern, string &lpResults[], int flags = NULL);;
datetime FxtToGmtTime(datetime fxtTime);;
datetime FxtToServerTime(datetime fxtTime);;
int      GetAccountHistory(int account, string results[][AH_COLUMNS]);;
int      GetAccountNumber();;
int      GetBalanceHistory(int account, datetime &times[], double &values[]);;
int      GetCustomLogID();;
int      GetFxtToGmtTimeOffset(datetime fxtTime);;
int      GetFxtToServerTimeOffset(datetime fxtTime);;
string   GetGlobalConfigPath();;
int      GetGmtToFxtTimeOffset(datetime gmtTime);;
int      GetGmtToServerTimeOffset(datetime gmtTime);;
string   GetHostName();;
int      GetIniKeys(string fileName, string section, string keys[]);;
int      GetIniSections(string fileName, string names[]);;
int      GetIniSections(string fileName, string sections[]);;
string   GetLocalConfigPath();;
int      GetLocalToGmtTimeOffset();;
string   GetLongSymbolName(string symbol);;
string   GetLongSymbolNameOrAlt(string symbol, string altValue = "");;
string   GetLongSymbolNameStrict(string symbol);;
datetime GetNextSessionEndTime.fxt(datetime fxtTime);;
datetime GetNextSessionEndTime.gmt(datetime gmtTime);;
datetime GetNextSessionEndTime.srv(datetime serverTime);;
datetime GetNextSessionStartTime.fxt(datetime fxtTime);;
datetime GetNextSessionStartTime.gmt(datetime gmtTime);;
datetime GetNextSessionStartTime.srv(datetime serverTime);;
datetime GetPrevSessionEndTime.fxt(datetime fxtTime);;
datetime GetPrevSessionEndTime.gmt(datetime gmtTime);;
datetime GetPrevSessionEndTime.srv(datetime serverTime);;
datetime GetPrevSessionStartTime.fxt(datetime fxtTime);;
datetime GetPrevSessionStartTime.gmt(datetime gmtTime);;
datetime GetPrevSessionStartTime.srv(datetime serverTime);;
string   GetRawIniString(string fileName, string section, string key, string defaultValue = "");;
string   GetServerName();;
string   GetServerTimezone();;
int      GetServerToFxtTimeOffset(datetime serverTime);;
int      GetServerToGmtTimeOffset(datetime serverTime);;
datetime GetSessionEndTime.fxt(datetime fxtTime);;
datetime GetSessionEndTime.gmt(datetime gmtTime);;
datetime GetSessionEndTime.srv(datetime serverTime);;
datetime GetSessionStartTime.fxt(datetime fxtTime);;
datetime GetSessionStartTime.gmt(datetime gmtTime);;
datetime GetSessionStartTime.srv(datetime serverTime);;
string   GetStandardSymbol(string symbol);;
string   GetStandardSymbolOrAlt(string symbol, string altValue = "");;
string   GetStandardSymbolStrict(string symbol);;
string   GetSymbolName(string symbol);;
string   GetSymbolNameOrAlt(string symbol, string altValue = "");;
string   GetSymbolNameStrict(string symbol);;
string   GetTempPath();;
int      GetTesterWindow();;
bool     GetTimezoneTransitions(datetime serverTime, int &previousTransition[], int &nextTransition[]);;
string   GetWindowsShortcutTarget(string lnkFilename);;
string   GetWindowText(int hWnd);;
datetime GmtToFxtTime(datetime gmtTime);;
datetime GmtToServerTime(datetime gmtTime);;
color    HSVToRGB(double hsv[3]);;
color    HSVValuesToRGB(double hue, double saturation, double value);;
int      iAccountBalance(int account, double buffer[], int bar);;
int      iAccountBalanceSeries(int account, double &buffer[]);;
int      IncreasePeriod(int period = NULL);;
int      InitializeDoubleBuffer(double buffer[], int size);;
int      InitializeStringBuffer(string &buffer[], int length);;
string   InputsToStr();;
string   IntegerToBinaryStr(int integer);;
string   IntegerToHexStr(int integer);;
bool     IntInArray(int haystack[], int needle);;
bool     IsDirectory(string path);;
bool     IsFile(string path);;
bool     IsIniKey(string fileName, string section, string key);;
bool     IsIniSection(string fileName, string section);;
bool     IsPermanentTradeError(int error);;
bool     IsReverseIndexedBoolArray(bool array[]);;
bool     IsReverseIndexedDoubleArray(double array[]);;
bool     IsReverseIndexedIntArray(int array[]);;
bool     IsReverseIndexedStringArray(string array[]);;
bool     IsTemporaryTradeError(int error);;
int      MergeBoolArrays(bool array1[], bool array2[], bool merged[]);;
int      MergeDoubleArrays(double array1[], double array2[], double merged[]);;
int      MergeIntArrays(int array1[], int array2[], int merged[]);;
int      MergeStringArrays(string array1[], string array2[], string merged[]);;
bool     ObjectDeleteSilent(string label, string location);;
int      ObjectRegister(string label);;
bool     onBarOpen();;
bool     onChartCommand(string data[]);;
int      onDeinitAccountChange();;
int      onDeinitChartChange();;
int      onDeinitChartClose();;
int      onDeinitClose();;
int      onDeinitFailed();;
int      onDeinitParameterChange();;
int      onDeinitRecompile();;
int      onDeinitRemove();;
int      onDeinitTemplate();;
int      onDeinitUndefined();;
int      onInitAccountChange();;
int      onInitChartChange();;
int      onInitChartClose();;
int      onInitClose();;
int      onInitFailed();;
int      onInitParameterChange();;
int      onInitRecompile();;
int      onInitRemove();;
int      onInitTemplate();;
int      onInitUndefined();;
bool     OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool     OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool     OrderDeleteEx(int ticket, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool     OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool     OrderMultiClose(int tickets[], double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]);;
int      OrderSendEx(string symbol=NULL, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool     ReleaseLock(string mutexName);;
int      RepositionLegend();;
bool     ReverseBoolArray(bool array[]);;
bool     ReverseDoubleArray(double array[]);;
bool     ReverseIntArray(int array[]);;
bool     ReverseStringArray(string array[]);;
color    RGB(int red, int green, int blue);;
int      RGBToHSV(color rgb, double &hsv[]);;
int      RGBValuesToHSV(int red, int green, int blue, double hsv[]);;
int      SearchBoolArray(bool haystack[], bool needle);;
int      SearchDoubleArray(double haystack[], double needle);;
int      SearchIntArray(int haystack[], int needle);;
int      SearchStringArray(string haystack[], string needle);;
int      SearchStringArrayI(string haystack[], string needle);;
datetime ServerToFxtTime(datetime serverTime);;
datetime ServerToGmtTime(datetime serverTime);;
int      SetCustomLog(int id, string file);;
int      ShowStatus(int error);;
int      SortTicketsChronological(int &tickets[]);;
string   StdSymbol();;
bool     StringInArray(string haystack[], string needle);;
bool     StringInArrayI(string haystack[], string needle);;
string   StringPad(string input, int pad_length, string pad_string=" ", int pad_type=STR_PAD_RIGHT);;
double   SumDoubles(double values[]);;
string   WaitForSingleObjectValueToStr(int value);;
int      WinExecWait(string cmdLine, int cmdShow);;
string   WordToHexStr(int word);;


// stdlib2.ex4
string   BoolsToStr(bool array[], string separator);;
string   CharsToStr(int array[], string separator);;
string   DoublesToStr(double array[], string separator);;
string   DoublesToStrEx(double array[], string separator, int digits/*=0..16*/);;
string   iBufferToStr(double array[], string separator);;
string   IntsToStr(int array[], string separator);;
string   MoneysToStr(double array[], string separator);;
string   OperationTypesToStr(int array[], string separator);;
string   PricesToStr(double array[], string separator);;
string   RatesToStr(double array[], string separator);;
string   StringsToStr(string array[], string separator);;
string   TicketsToStr(int array[], string separator);;
string   TicketsToStr.Lots(int array[], string separator);;
string   TicketsToStr.LotsSymbols(int array[], string separator);;
string   TicketsToStr.Position(int array[]);;
string   TimesToStr(datetime array[], string separator);;


// Expander.dll
string   BoolToStr(bool value);;
string   DeinitFlagsToStr(int flags);;
string   DoubleQuoteStr(string value);;
string   ec_CustomLogFile  (int ec[]);;
int      ec_DeinitFlags    (int ec[]);;
int      ec_DllError       (int ec[]);;
int      ec_DllWarning     (int ec[]);;
int      ec_hChart         (int ec[]);;
int      ec_hChartWindow   (int ec[]);;
int      ec_InitCycle      (int ec[]);;
int      ec_InitFlags      (int ec[]);;
int      ec_InitReason     (int ec[]);;
int      ec_LaunchType     (int ec[]);;
bool     ec_Logging        (int ec[]);;
int      ec_lpSuperContext (int ec[]);;
string   ec_ModuleName     (int ec[]);;
int      ec_ModuleType     (int ec[]);;
int      ec_MqlError       (int ec[]);;
bool     ec_Optimization   (int ec[]);;
int      ec_ProgramId      (int ec[]);;
string   ec_ProgramName    (int ec[]);;
int      ec_ProgramType    (int ec[]);;
int      ec_RootFunction   (int ec[]);;
int      ec_SetDllError    (int ec[], int error);;
bool     ec_SetLogging     (int ec[], int logging);;
int      ec_SetMqlError    (int ec[], int error);;
int      ec_SetRootFunction(int ec[], int function);;
bool     ec_SuperContext   (int ec[], int sec[]);;
string   ec_Symbol         (int ec[]);;
bool     ec_Testing        (int ec[]);;
int      ec_Timeframe      (int ec[]);;
int      ec_UninitReason   (int ec[]);;
bool     ec_VisualMode     (int ec[]);;
int      mec_InitFlags     (int ec[]);;
int      mec_RootFunction  (int ec[]);;
int      mec_UninitReason  (int ec[]);;
string   ErrorToStr(int error);;
string   EXECUTION_CONTEXT_toStr(int ec[], int outputDebug);;
int      GetApplicationWindow();;
int      GetBoolsAddress(bool array[]);;
int      GetDoublesAddress(double array[]);;
datetime GetGmtTime();;
int      GetIntsAddress(int array[]);;
int      GetLastWin32Error();;
datetime GetLocalTime();;
string   GetString(int address);;
int      GetStringAddress(string value);;
int      GetStringsAddress(string values[]);;
int      GetTerminalBuild();;
string   GetTerminalVersion();;
int      GetUIThreadId();;
int      GetWindowProperty(int hWnd, string name);;
string   InitFlagsToStr(int flags);;
string   InitializeReasonToStr(int reason);;
string   InitReasonToStr(int reason);;
string   IntToHexStr(int value);;
bool     IsCustomTimeframe(int timeframe);;
bool     IsStdTimeframe(int timeframe);;
bool     IsUIThread();;
bool     LeaveContext(int ec[]);;
string   lpEXECUTION_CONTEXT_toStr(int lpEc, int outputDebug);;
string   ModuleTypeDescription(int type);;
string   ModuleTypeToStr(int type);;
int      MT4InternalMsg();;
string   PeriodDescription(int period);;
string   PeriodToStr(int period);;
string   ProgramTypeDescription(int type);;
string   ProgramTypeToStr(int type);;
bool     RemoveTickTimer(int timerId);;
int      RemoveWindowProperty(int hWnd, string name);;
string   RootFunctionDescription(int id);;
string   RootFunctionToStr(int id);;
int      SetupTickTimer(int hWnd, int millis, int flags);;
bool     SetWindowProperty(int hWnd, string name, int value);;
bool     ShiftIndicatorBuffer(double buffer[], int bufferSize, int bars, double emptyValue);;
string   ShowWindowCmdToStr(int cmdShow);;
bool     StringCompare(string s1, string s2);;
bool     StringEndsWith(string object, string suffix);;
bool     StringIsNull(string value);;
string   StringToStr(string value);;
bool     SyncLibContext_deinit(int ec[], int uninitReason);;
bool     SyncLibContext_init(int ec[], int uninitReason, int initFlags, int deinitFlags, string name, string symbol, int period, int isOptimization);;
bool     SyncMainContext_deinit(int ec[], int uninitReason);;
bool     SyncMainContext_init(int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);;
bool     SyncMainContext_start(int ec[], datetime time, double bid, double ask, int volume);;
string   TimeframeDescription(int timeframe);;
string   TimeframeToStr(int timeframe);;
string   TradeDirectionDescription(int direction);
string   TradeDirectionToStr(int direction);
string   UninitializeReasonToStr(int reason);;
string   UninitReasonToStr(int reason);;
