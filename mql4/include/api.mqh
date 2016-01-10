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
  TODO                  string   GetAccountConfigPath(string companyId, string accountId);;

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












// stdfunctions.mgh

int start.RelaunchInputDialog();;
int debug(string message, int error=NO_ERROR);;
int catch(string location, int error=NO_ERROR, bool orderPop=false);;
int warn(string message, int error=NO_ERROR);;
int warnSMS(string message, int error=NO_ERROR);;
int log(string message, int error=NO_ERROR);;
string ErrorDescription(int error);;
string ErrorToStr(int error);;
string PeriodDescription(int period=NULL);;
string TimeframeDescription(int timeframe=NULL);;
string StringReplace(string object, string search, string replace);;
string StringSubstrFix(string object, int start, int length=INT_MAX);;
int PlaySoundEx(string soundfile);;
int ForceMessageBox(string caption, string message, int flags=MB_OK);;
int WindowHandleEx(string symbol, int timeframe=NULL);;
string ChartDescription(string symbol, int timeframe);;
string GetClassName(int hWnd);;
bool IsVisualModeFix();;
bool IsError(int value);;
bool IsLastError();;
int ResetLastError();;
bool HandleEvents(int eventFlags);;
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
bool GT(double double1, double double2, int digits=8)
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
int Min(int value1, int value2);;
int Max(int value1, int value2);;
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
string RootFunctionToStr(int id);;
string RootFunctionName(int id);;
string PeriodToStr(int period=NULL, int execFlags=NULL);;
string TimeframeToStr(int timeframe=NULL, int execFlags=NULL);;
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
int DebugMarketInfo(string symbol, string location);;
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
int MT4InternalMsg();;
int WM_MT4();;
bool EventListener.NewTick(int results[], int flags=NULL) {
datetime TimeServer() {
datetime TimeGMT() {
datetime TimeFXT() {
datetime GetFxtTime() {
datetime TimeLocalEx(string location="") {
datetime TimeCurrentEx(string location="") {
string BoolToStr(bool value) {
string ModuleTypesToStr(int fType) {
string UninitializeReasonToStr(int reason) {
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


