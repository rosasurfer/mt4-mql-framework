/**
 * Nach Funktionalität gruppierter Überblick aller in MQL zusätzlich zur Verfügung stehenden Funktionen und der jeweils benötigten Library.
 *
 *
 * @note  Diese Datei kann nicht inkludiert werden.
 * @note  Das der Deklaration folgende doppelte Semikolon aktiviert den UEStudio-Function-Browser, der Importdeklarationen im Normalfall nicht anzeigt.
 */

                        // Konfiguration
/*stdlib1.ex4     */    string   GetLocalConfigPath();;
/*stdlib1.ex4     */    string   GetGlobalConfigPath();;
/*stdfunctions.mqh*/    string   GetAccountConfigPath(string companyId, string accountId);;

/*stdfunctions.mqh*/    bool     IsConfigKey             (string section, string key);;
/*stdfunctions.mqh*/    bool     IsLocalConfigKey        (string section, string key);;
/*stdfunctions.mqh*/    bool     IsGlobalConfigKey       (string section, string key);;

/*stdfunctions.mqh*/    bool     GetConfigBool           (string section, string key, bool   defaultValue);;
/*stdfunctions.mqh*/    int      GetConfigInt            (string section, string key, int    defaultValue);;
/*stdfunctions.mqh*/    double   GetConfigDouble         (string section, string key, double defaultValue);;
/*stdfunctions.mqh*/    string   GetConfigString         (string section, string key, string defaultValue);;
/*stdfunctions.mqh*/    string   GetRawConfigString      (string section, string key, string defaultValue);;

/*stdfunctions.mqh*/    bool     GetLocalConfigBool      (string section, string key, bool   defaultValue);;
/*stdfunctions.mqh*/    int      GetLocalConfigInt       (string section, string key, int    defaultValue);;
/*stdfunctions.mqh*/    double   GetLocalConfigDouble    (string section, string key, double defaultValue);;
/*stdfunctions.mqh*/    string   GetLocalConfigString    (string section, string key, string defaultValue);;
/*stdfunctions.mqh*/    string   GetRawLocalConfigString (string section, string key, string defaultValue);;

/*stdfunctions.mqh*/    bool     GetGlobalConfigBool     (string section, string key, bool   defaultValue);;
/*stdfunctions.mqh*/    int      GetGlobalConfigInt      (string section, string key, int    defaultValue);;
/*stdfunctions.mqh*/    double   GetGlobalConfigDouble   (string section, string key, double defaultValue);;
/*stdfunctions.mqh*/    string   GetGlobalConfigString   (string section, string key, string defaultValue);;
/*stdfunctions.mqh*/    string   GetRawGlobalConfigString(string section, string key, string defaultValue);;

/*stdfunctions.mqh*/    bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);;
/*stdfunctions.mqh*/    int      GetIniInt      (string fileName, string section, string key, int    defaultValue);;
/*stdfunctions.mqh*/    double   GetIniDouble   (string fileName, string section, string key, double defaultValue);;
/*stdfunctions.mqh*/    string   GetIniString   (string fileName, string section, string key, string defaultValue);;
/*stdlib1.ex4     */    string   GetRawIniString(string fileName, string section, string key, string defaultValue);;

/*stdlib1.ex4     */    int      GetIniSections (string fileName, string sections[]);;
/*stdlib2.ex4     */    int      GetIniKeys     (string fileName, string section, string keys[]);;

/*stdlib1.ex4     */    bool     IsIniSection   (string fileName, string section);;
/*stdlib1.ex4     */    bool     IsIniKey       (string fileName, string section, string key);;

/*stdfunctions.mqh*/    bool     DeleteIniKey   (string fileName, string section, string key);;


                        // Chart-Ticker
/*Expander.dll    */    int      SetupTickTimer(int hWnd, int millis, int flags);;
/*Expander.dll    */    bool     RemoveTickTimer(int timerId);;


/*Expander.dll*/
bool     ShiftIndicatorBuffer(double buffer[], int bufferSize, int bars, double emptyValue);;
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
int      GetUIThreadId();;
int      GetWindowProperty(int hWnd, string name);;
bool     IsCustomTimeframe(int timeframe);;
bool     IsStdTimeframe(int timeframe);;
bool     IsUIThread();;
string   IntToHexStr(int value);;
int      MT4InternalMsg();;
string   ModuleTypeDescription(int type);;
string   ModuleTypeToStr(int type);;
string   PeriodDescription(int period);;
string   PeriodToStr(int period);;
string   ProgramTypeDescription(int type);;
string   ProgramTypeToStr(int type);;
int      RemoveWindowProperty(int hWnd, string name);;
string   RootFunctionName(int id);;
string   RootFunctionToStr(int id);;
bool     SetWindowProperty(int hWnd, string name, int value);;
bool     StringCompare(string s1, string s2);;
bool     StringIsNull(string value);;
string   StringToStr(string value);;
bool     SyncLibExecutionContext(int ec[], string name, int rootFunction, string symbol, int period);;
bool     SyncMainExecutionContext(int ec[], int programType, string programName, int rootFunction, int reason, string symbol, int period);;
string   TimeframeDescription(int timeframe);;
string   TimeframeToStr(int timeframe);;
string   UninitializeReasonToStr(int reason);;
string   ShowWindowCmdToStr(int cmdShow);;


// scriptrunner.mqh
bool RunScript(string name, string parameters="");;
bool ScriptRunner.SetParameters(string parameters);;
bool ScriptRunner.GetParameters(string parameters[]);;


// stdfunctions.mgh
string ShellExecuteErrorDescription(int error);;
string SwapCalculationModeToStr(int mode);;
string FileAccessModeToStr(int mode);;
string DeinitFlagsToStr(int flags);;
string InitFlagsToStr(int flags);;
string TestFlagsToStr(int flags);;
int StrToTimeframe(string timeframe);;
int StrToPeriod(string value);;
string PriceTypeDescription(int type);;
string PriceTypeToStr(int type);;
string MovingAverageMethodToStr(int method);;
string MaMethodToStr(int method);;
string MovingAverageMethodDescription(int method);;
string MaMethodDescription(int method);;
int StrToPriceType(string value);;
bool SendSMS(string receiver, string message);;
bool SendEmail(string sender, string receiver, string subject, string message);;
bool StringIsEmailAddress(string value);;
string TradeCommandToStr(int cmd);;
string StringCapitalize(string value);;
string HistoryFlagsToStr(int flags);;
bool OrderLog(int ticket);;
int PeriodFlag(int period=NULL);;
string PeriodFlagsToStr(int flags);;
datetime GetServerTime();;
string InitReasonToStr(int reason);;
string InitReasonDescription(int reason);;
string UninitializeReasonDescription(int reason);;
string StringReplace.Recursive(string object, string search, string replace);;
string NumberToStr(double value, string mask);;
string OrderTypeDescription(int type);;
string OperationTypeDescription(int type);;
string OrderTypeToStr(int type);;
string OperationTypeToStr(int type);;
int StrToOperationType(string value);;
string MessageBoxCmdToStr(int cmd);;
bool IsTradeOperation(int value);;
bool IsLongTradeOperation(int value);;
bool IsShortTradeOperation(int value);;
bool IsPendingTradeOperation(int value);;
bool IsCurrency(string value);;
string GetCurrency(int id);;
int GetCurrencyId(string currency);;
int start.RelaunchInputDialog();;
int debug(string message, int error=NO_ERROR);;
int catch(string location, int error=NO_ERROR, bool orderPop=false);;
int warn(string message, int error=NO_ERROR);;
int warnSMS(string message, int error=NO_ERROR);;
int log(string message, int error=NO_ERROR);;
string ErrorDescription(int error);;
string ErrorToStr(int error);;
string StringReplace(string object, string search, string replace);;
string StringSubstrFix(string object, int start, int length=INT_MAX);;
bool PlaySoundEx(string soundfile);;
int ForceMessageBox(string caption, string message, int flags=MB_OK);;
int WindowHandleEx(string symbol, int timeframe=NULL);;
string ChartDescription(string symbol, int timeframe);;
string GetClassName(int hWnd);;
bool IsVisualModeFix();;
bool IsError(int value);;
bool IsLastError();;
int ResetLastError();;
int HandleEvent(int event, int criteria=NULL);;
bool IsTicket(int ticket);;
bool SelectTicket(int ticket, string location, bool storeSelection=false, bool onErrorRestoreSelection=false);;
int OrderPush(string location);;
bool OrderPop(string location);;
bool WaitForTicket(int ticket, bool orderKeep=true);;
double PipValue(double lots=1.0, bool suppressErrors=false);;
double PipValueEx(string symbol, double lots=1.0, bool suppressErrors=false);;
bool IsLogging();;
bool ifBool(bool condition, bool thenValue, bool elseValue);;
int ifInt(bool condition, int thenValue, int elseValue);;
double ifDouble(bool condition, double thenValue, double elseValue);;
string ifString(bool condition, string thenValue, string elseValue);;
bool LT(double double1, double double2, int digits=8);;
bool LE(double double1, double double2, int digits=8);;
bool EQ(double double1, double double2, int digits=8);;
bool NE(double double1, double double2, int digits=8);;
bool GE(double double1, double double2, int digits=8);;
bool GT(double double1, double double2, int digits=8);;
bool IsNaN(double value);;
bool IsInfinity(double value);;
bool _true(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool _false(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int _NULL(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int _NO_ERROR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int _last_error(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
int _EMPTY(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool IsEmpty(double value);;
int _EMPTY_VALUE(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool IsEmptyValue(double value);;
string _EMPTY_STR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool IsEmptyString(string value);;
datetime _NaT(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL);;
bool IsNaT(datetime value);;
bool _bool(bool param1, int param2=NULL, int param3=NULL, int param4=NULL);;
int _int(int param1, int param2=NULL, int param3=NULL, int param4=NULL);;
double _double(double param1, int param2=NULL, int param3=NULL, int param4=NULL);;
string _string(string param1, int param2=NULL, int param3=NULL, int param4=NULL);;
int Min(int value1, int value2, int value3=INT_MAX, int value4=INT_MAX, int value5=INT_MAX, int value6=INT_MAX, int value7=INT_MAX, int value8=INT_MAX);;
int Max(int value1, int value2, int value3=INT_MIN, int value4=INT_MIN, int value5=INT_MIN, int value6=INT_MIN, int value7=INT_MIN, int value8=INT_MIN);;
int Abs(int value);;
int Sign(double number);;
int Round(double value);;
double RoundEx(double number, int decimals=0);;
double RoundFloor(double number, int decimals=0);;
double RoundCeil(double number, int decimals=0);;
int Floor(double value);;
int Ceil(double value);;
double MathDiv(double a, double b, double onZero=0);;
double MathModFix(double a, double b);;
int Div(int a, int b, int onZero=0);;
int CountDecimals(double number);;
string StringLeft(string value, int n);;
string StringLeftTo(string value, string substring, int count=1);;
string StringRight(string value, int n);;
string StringRightFrom(string value, string substring, int count=1);;
bool StringStartsWith(string object, string prefix);;
bool StringStartsWithI(string object, string prefix);;
bool StringEndsWith(string object, string suffix);;
bool StringEndsWithI(string object, string suffix);;
bool StringIsDigit(string value);;
bool StringIsInteger(string value);;
bool StringIsNumeric(string value);;
bool StringIsPhoneNumber(string value);;
int ArrayUnshiftString(string array[], string value);;
int StrToMaMethod(string value, int execFlags=NULL);;
int StrToMovingAverageMethod(string value, int execFlags=NULL);;
string QuoteStr(string value);;
string DoubleQuoteStr(string value);;
bool IsLeapYear(int year);;
datetime DateTime(int year, int month=1, int day=1, int hours=0, int minutes=0, int seconds=0);;
int TimeDayFix(datetime time);;
int TimeDayOfWeekFix(datetime time);;
int TimeYearFix(datetime time);;
void CopyMemory(int destination, int source, int bytes);;
int SumInts(int values[]);;
int DebugMarketInfo(string location);;
string StringPadLeft(string input, int pad_length, string pad_string=" ");;
string StringLeftPad(string input, int pad_length, string pad_string=" ");;
string StringPadRight(string input, int pad_length, string pad_string=" ");;
string StringRightPad(string input, int pad_length, string pad_string=" ");;
bool Expert.IsTesting();;
bool Script.IsTesting();;
bool Indicator.IsTesting();;
bool This.IsTesting();;
bool EnumChildWindows(int hWnd, bool recursive=false);;
bool StrToBool(string value);;
string StringToLower(string value);;
string StringToUpper(string value);;
string StringTrim(string value);;
string UrlEncode(string value);;
bool IsMqlFile(string filename);;
bool IsMqlDirectory(string dirname);;
string CharToHexStr(int char);;
string StringToHexStr(string value);;
int Chart.Expert.Properties();;
int Chart.SendTick(bool sound=false);;
int Chart.Objects.UnselectAll();;
int Chart.Refresh();;
int Tester.Pause();;
bool Tester.IsPaused();;
bool Tester.IsStopped();;
string CreateString(int length);;
int Toolbar.Experts(bool enable);;
int MarketWatch.Symbols();;
int WM_MT4();;
bool EventListener.NewTick();;
datetime TimeServer() {
datetime TimeGMT() {
datetime TimeFXT() {
datetime GetFxtTime() {
datetime TimeLocalEx(string location="") {
datetime TimeCurrentEx(string location="") {
string BoolToStr(bool value) {
string ModuleTypesToStr(int fType) {
double GetExternalAssets(string companyId, string accountId) {
double RefreshExternalAssets(string companyId, string accountId) {
bool IsConfigKey(string section, string key) {
bool IsLocalConfigKey(string section, string key) {
bool IsGlobalConfigKey(string section, string key) {
bool GetConfigBool(string section, string key, bool defaultValue=false) {
bool GetLocalConfigBool(string section, string key, bool defaultValue=false) {
bool GetGlobalConfigBool(string section, string key, bool defaultValue=false) {
bool GetIniBool(string fileName, string section, string key, bool defaultValue=false) {
int GetIniInt(string fileName, string section, string key, int defaultValue=0) {
double GetIniDouble(string fileName, string section, string key, double defaultValue=0) {
double GetConfigDouble(string section, string key, double defaultValue=0) {
double GetLocalConfigDouble(string section, string key, double defaultValue=0) {
double GetGlobalConfigDouble(string section, string key, double defaultValue=0) {
int GetConfigInt(string section, string key, int defaultValue=0) {
int GetLocalConfigInt(string section, string key, int defaultValue=0) {
int GetGlobalConfigInt(string section, string key, int defaultValue=0) {
string GetIniString(string fileName, string section, string key, string defaultValue="") {
string GetConfigString(string section, string key, string defaultValue="") {
string GetLocalConfigString(string section, string key, string defaultValue="") {
string GetGlobalConfigString(string section, string key, string defaultValue="") {
string GetRawConfigString(string section, string key, string defaultValue="") {
string GetRawLocalConfigString(string section, string key, string defaultValue="") {
string GetRawGlobalConfigString(string section, string key, string defaultValue="") {
bool DeleteIniKey(string fileName, string section, string key) {
string ShortAccountCompany() {
int AccountCompanyId(string shortName) {
string ShortAccountCompanyFromId(int id) {
bool IsShortAccountCompany(string value) {
string AccountAlias(string accountCompany, int accountNumber) {
int AccountNumberFromAlias(string accountCompany, string accountAlias) {
bool StringCompareI(string string1, string string2) {
bool StringContains(string object, string substring) {
bool StringContainsI(string object, string substring) {
int StringFindR(string object, string search) {
string ColorToHtmlStr(color rgb) {
string ColorToStr(color value)   {
string StringRepeat(string input, int times) {

/*functions/JoinStrings.mqh*/
string JoinStrings(string values[], string separator);;

/*functions/JoinDoublesEx.mqh*/
string JoinDoublesEx(double values[], string separator, int digits);;

/*functions/JoinDoubles.mqh*/
string JoinDoubles(double values[], string separator);;

/*functions/JoinBools.mqh*/
string JoinBools(bool values[], string separator);;

/*functions/InitializeByteBuffer.mqh*/
int InitializeByteBuffer(int buffer[], int bytes);;

/*functions/EventListener.BarOpen.mqh*/
bool EventListener.BarOpen();;

/*functions/EventListener.BarOpen.MTF.mqh*/
bool EventListener.BarOpen(int results[], int flags=NULL);;

/*functions/ExplodeStrings.mqh*/
int ExplodeStrings(int buffer[], string &results[]);;

/*functions/JoinInts.mqh*/
string JoinInts(int values[], string separator);;

/*iCustom/icMovingAverage.mqh*/
double icMovingAverage(int timeframe, string maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int iBuffer, int iBar);;

/*iCustom/icNonLagMA.mqh*/
double icNonLagMA(int timeframe, int cycleLength, string filterVersion, int maxValues, int iBuffer, int iBar);;

/*iCustom/icChartInfos.mqh*/
bool icChartInfos(int timeframe=NULL);;

/*iCustom/icEventTracker.mqh*/
bool icEventTracker(int timeframe);;

/*iCustom/icEventTracker.neu.mqh*/
bool icEventTracker.neu(int timeframe=NULL);;

/*iFunctions/iPreviousPeriodTimes.mqh*/
bool iPreviousPeriodTimes(int timeframe=NULL, datetime &openTime.fxt=NULL, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv);;

/*iFunctions/iChangedBars.mqh*/
int iChangedBars(string symbol=NULL, int period=NULL, int execFlags=NULL);;

/*iFunctions/iBarShiftPrevious.mqh*/
int iBarShiftPrevious(string symbol=NULL, int period=NULL, datetime time, int execFlags=NULL);;

/*iFunctions/iBarShiftNext.mqh*/
int iBarShiftNext(string symbol=NULL, int period=NULL, datetime time, int execFlags=NULL);;

/*iFunctions/@ALMA.mqh*/
void @ALMA.CalculateWeights(double &weights[], int periods, double offset=0.85, double sigma=6.0);;

/*iFunctions/@ATR.mqh*/
double @ATR(string symbol, int timeframe, int periods, int offset);;

/*iFunctions/@Bands.mqh*/
void @Bands.SetIndicatorStyles(color mainColor, color bandsColor);;

/*iFunctions/@Trend.mqh*/
void @Trend.UpdateLegend(string label, string name, string status, color uptrendColor, color downtrendColor, double value, int trend, datetime barOpenTime);;
void @Trend.UpdateColors(double values[], int bar, double &trend[], double &uptrend[], double &downtrend[], int lineStyle, double &uptrend2[], bool uptrend2_enable=false, int normalizeDigits=EMPTY_VALUE);;


// stdlib1.ex4
string GetTempPath();;
string CreateTempFile(string path, string prefix="");;
bool Init.IsNoTick();;
void Init.StoreSymbol(string symbol);;
bool Init.IsNewSymbol(string symbol);;
int onInitParameterChange();;
int onInitChartChange();;
int onInitAccountChange();;
int onInitChartClose();;
int onInitUndefined();;
int onInitRemove();;
int onInitRecompile();;
int onInitTemplate();;
int onInitFailed();;
int onInitClose();;
int onDeinitParameterChange();;
int onDeinitChartChange();;
int onDeinitAccountChange();;
int onDeinitChartClose();;
int onDeinitUndefined();;
int onDeinitRemove();;
int onDeinitRecompile();;
int onDeinitTemplate();;
int onDeinitFailed();;
int onDeinitClose();;
string InputsToStr();;
int ShowStatus(int error);;
bool EditFile(string filename);;
bool EditFiles(string filenames[]);;
double GetCommission();;
bool GetTimezoneTransitions(datetime serverTime, int &previousTransition[], int &nextTransition[]);;
int SetCustomLog(int id, string file);;
int GetCustomLogID();;
bool AquireLock(string mutexName, bool wait);;
bool ReleaseLock(string mutexName);;
bool ReleaseLocks(bool warn=false);;
int GetGmtToFxtTimeOffset(datetime gmtTime);;
int GetServerToFxtTimeOffset(datetime serverTime);;
int GetServerToGmtTimeOffset(datetime serverTime);;
int GetIniSections(string fileName, string names[]);;
bool IsIniSection(string fileName, string section);;
bool IsIniKey(string fileName, string section, string key);;
string GetTerminalVersion();;
int GetTerminalBuild();;
int MT4build();; // @author  Cristi Dumitrescu <birt@eareview.net>
string GetServerName();;
int InitializeDoubleBuffer(double buffer[], int size);;
int InitializeStringBuffer(string &buffer[], int length);;
int SortTicketsChronological(int &tickets[]);;
string CreateLegendLabel(string name);;
int RepositionLegend();;
bool IsTemporaryTradeError(int error);;
bool IsPermanentTradeError(int error);;
int ArraySetInts(int array[][], int offset, int values[]);;
int ArrayPushBool(bool &array[], bool value);;
int ArrayPushInt(int &array[], int value);;
int ArrayPushInts(int array[][], int value[]);;
int ArrayPushDouble(double &array[], double value);;
int ArrayPushString(string &array[], string value);;
bool ArrayPopBool(bool array[]);;
int ArrayPopInt(int array[]);;
double ArrayPopDouble(double array[]);;
string ArrayPopString(string array[]);;
int ArrayUnshiftBool(bool array[], bool value);;
int ArrayUnshiftInt(int array[], int value);;
int ArrayUnshiftDouble(double array[], double value);;
bool ArrayShiftBool(bool array[]);;
int ArrayShiftInt(int array[]);;
double ArrayShiftDouble(double array[]);;
string ArrayShiftString(string array[]);;
int ArrayDropBool(bool array[], bool value);;
int ArrayDropInt(int array[], int value);;
int ArrayDropDouble(double array[], double value);;
int ArrayDropString(string array[], string value);;
int ArraySpliceBools(bool array[], int offset, int length);;
int ArraySpliceInts(int array[], int offset, int length);;
int ArraySpliceDoubles(double array[], int offset, int length);;
int ArraySpliceStrings(string array[], int offset, int length);;
int ArrayInsertBool(bool &array[], int offset, bool value);;
int ArrayInsertInt(int &array[], int offset, int value);;
int ArrayInsertDouble(double &array[], int offset, double value);;
int ArrayInsertBools(bool array[], int offset, bool values[]);;
int ArrayInsertInts(int array[], int offset, int values[]);;
int ArrayInsertDoubles(double array[], int offset, double values[]);;
bool BoolInArray(bool haystack[], bool needle);;
bool IntInArray(int haystack[], int needle);;
bool DoubleInArray(double haystack[], double needle);;
bool StringInArray(string haystack[], string needle);;
bool StringInArrayI(string haystack[], string needle);;
int SearchBoolArray(bool haystack[], bool needle);;
int SearchIntArray(int haystack[], int needle);;
int SearchDoubleArray(double haystack[], double needle);;
int SearchStringArray(string haystack[], string needle);;
int SearchStringArrayI(string haystack[], string needle);;
bool ReverseBoolArray(bool array[]);;
bool ReverseIntArray(int array[]);;
bool ReverseDoubleArray(double array[]);;
bool ReverseStringArray(string array[]);;
bool IsReverseIndexedBoolArray(bool array[]);;
bool IsReverseIndexedIntArray(int array[]);;
bool IsReverseIndexedDoubleArray(double array[]);;
bool IsReverseIndexedStringArray(string array[]);;
int MergeBoolArrays(bool array1[], bool array2[], bool merged[]);;
int MergeIntArrays(int array1[], int array2[], int merged[]);;
int MergeDoubleArrays(double array1[], double array2[], double merged[]);;
int MergeStringArrays(string array1[], string array2[], string merged[]);;
double SumDoubles(double values[]);;
string BufferToStr(int buffer[]);;
string BufferToHexStr(int buffer[]);;
int BufferGetChar(int buffer[], int pos);;
string BufferWCharsToStr(int buffer[], int from, int length);;
string GetWindowsShortcutTarget(string lnkFilename);;
int WinExecWait(string cmdLine, int cmdShow);;
int FileReadLines(string filename, string result[], bool skipEmptyLines=false);;
string WaitForSingleObjectValueToStr(int value);;
string StdSymbol();;
string GetStandardSymbol(string symbol);;
string GetStandardSymbolOrAlt(string symbol, string altValue="");;
string GetStandardSymbolStrict(string symbol);;
string GetSymbolName(string symbol);;
string GetSymbolNameOrAlt(string symbol, string altValue="");;
string GetSymbolNameStrict(string symbol);;
string GetLongSymbolName(string symbol);;
string GetLongSymbolNameOrAlt(string symbol, string altValue="");;
string GetLongSymbolNameStrict(string symbol);;
string StringPad(string input, int pad_length, string pad_string=" ", int pad_type=STR_PAD_RIGHT);;
datetime GetPrevSessionStartTime.srv(datetime serverTime);;
datetime GetPrevSessionEndTime.srv(datetime serverTime);;
datetime GetSessionStartTime.srv(datetime serverTime);;
datetime GetSessionEndTime.srv(datetime serverTime);;
datetime GetNextSessionStartTime.srv(datetime serverTime);;
datetime GetNextSessionEndTime.srv(datetime serverTime);;
datetime GetPrevSessionStartTime.gmt(datetime gmtTime);;
datetime GetPrevSessionEndTime.gmt(datetime gmtTime);;
datetime GetSessionStartTime.gmt(datetime gmtTime);;
datetime GetSessionEndTime.gmt(datetime gmtTime);;
datetime GetNextSessionStartTime.gmt(datetime gmtTime);;
datetime GetNextSessionEndTime.gmt(datetime gmtTime);;
datetime GetPrevSessionStartTime.fxt(datetime fxtTime);;
datetime GetPrevSessionEndTime.fxt(datetime fxtTime);;
datetime GetSessionStartTime.fxt(datetime fxtTime);;
datetime GetSessionEndTime.fxt(datetime fxtTime);;
datetime GetNextSessionStartTime.fxt(datetime fxtTime);;
datetime GetNextSessionEndTime.fxt(datetime fxtTime);;
string IntegerToHexStr(int integer);;
string ByteToHexStr(int byte);;
string WordToHexStr(int word);;
string IntegerToBinaryStr(int integer);;
int DecreasePeriod(int period=0);;
datetime FxtToGmtTime(datetime fxtTime);;
datetime FxtToServerTime(datetime fxtTime);;
bool EventListener.AccountChange(int results[], int flags=NULL);;
bool EventListener.ChartCommand(string commands[], int flags=NULL);;
int Explode(string input, string separator, string &results[], int limit=NULL);;
int GetAccountHistory(int account, string results[][AH_COLUMNS]);;
int GetAccountNumber();;
int GetBalanceHistory(int account, datetime &times[], double &values[]);;
string GetHostName();;
int GetFxtToGmtTimeOffset(datetime fxtTime);;
int GetFxtToServerTimeOffset(datetime fxtTime);;
int GetGmtToServerTimeOffset(datetime gmtTime);;
string GetRawIniString(string fileName, string section, string key, string defaultValue="");;
int GetLocalToGmtTimeOffset();;
string GetServerTimezone();;
int GetTesterWindow();;
string GetWindowText(int hWnd);;
datetime GmtToFxtTime(datetime gmtTime);;
datetime GmtToServerTime(datetime gmtTime);;
int iAccountBalance(int account, double buffer[], int bar);;
int iAccountBalanceSeries(int account, double &buffer[]);;
int IncreasePeriod(int period=NULL);;
int ObjectRegister(string label);;
int RegisterChartObject(string label);;
int DeleteRegisteredObjects(string prefix=NULL);;
bool ObjectDeleteSilent(string label, string location);;
datetime ServerToFxtTime(datetime serverTime);;
datetime ServerToGmtTime(datetime serverTime);;
bool IsFile(string path);;
bool IsDirectory(string path);;
int FindFileNames(string pattern, string &lpResults[], int flags=NULL);;
color RGB(int red, int green, int blue);;
int RGBValuesToHSV(int red, int green, int blue, double hsv[]);;
int RGBToHSV(color rgb, double &hsv[]);;
color HSVToRGB(double hsv[3]);;
color HSVValuesToRGB(double hue, double saturation, double value);;
color Color.ModifyHSV(color rgb, double mod_hue, double mod_saturation, double mod_value);;
string DoubleToStrEx(double value, int digits);;
string DateTimeToStr(datetime time, string mask);;
int OrderSendEx(string symbol=NULL, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);;
bool ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment);;
bool OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeprofit);;
bool ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment);;
bool ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor);;
bool ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment);;
bool ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor);;
bool ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);;
bool ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor);;
bool ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);;
bool OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool OrderMultiClose(int tickets[], double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]);;
bool OrderDeleteEx(int ticket, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);;
bool DeletePendingOrders(color markerColor=CLR_NONE);;
bool onBarOpen        (int    data[]);;
bool onAccountChange  (int    data[]);;
bool onChartCommand   (string data[]);;
void DummyCalls();;
