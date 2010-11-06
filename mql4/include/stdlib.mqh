/**
 * stdlib.mqh
 */

#include <stddefine.mqh>   // constant definitions


#import "stdlib.ex4"

   // Arrays
   string   JoinBools(bool& values[], string separator);
   string   JoinDoubles(double& values[], string separator);
   string   JoinInts(int& values[], string separator);
   string   JoinStrings(string& values[], string separator);

   // conditional Statements
   double   ifDouble(bool condition, double dThen, double dElse);
   int      ifInt(bool condition, int iThen, int iElse);
   string   ifString(bool condition, string strThen, string strElse);

   // Config
   bool     GetConfigBool(string section, string key, bool defaultValue);
   double   GetConfigDouble(string section, string key, double defaultValue);
   int      GetConfigInt(string section, string key, int defaultValue);
   string   GetConfigString(string section, string key, string defaultValue);
   bool     GetGlobalConfigBool(string section, string key, bool defaultValue);
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   int      GetGlobalConfigInt(string section, string key, int defaultValue);
   string   GetGlobalConfigString(string section, string key, string defaultValue);
   bool     GetLocalConfigBool(string section, string key, bool defaultValue);
   double   GetLocalConfigDouble(string section, string key, double defaultValue);
   int      GetLocalConfigInt(string section, string key, int defaultValue);
   string   GetLocalConfigString(string section, string key, string defaultValue);

   // Date/Time
   datetime EasternToGMT(datetime easternTime);
 //datetime EasternToLocalTime(datetime easternTime);
   datetime EasternToServerTime(datetime easternTime);
   datetime GmtToEasternTime(datetime gmtTime);
 //datetime GmtToLocalTime(datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);
 //datetime LocalToEasternTime(datetime localTime);
 //datetime LocalToGMT(datetime localTime);
 //datetime LocalToServerTime(datetime localTime);
   datetime ServerToEasternTime(datetime serverTime);
 //datetime ServerToLocalTime(datetime serverTime);
   datetime ServerToGMT(datetime serverTime);

   int      GetEasternToGmtOffset(datetime easternTime);
 //int      GetEasternToLocalTimeOffset(datetime easternTime);
   int      GetEasternToServerTimeOffset(datetime easternTime);
   int      GetGmtToEasternTimeOffset(datetime gmtTime);
 //int      GetGmtToLocalTimeOffset(datetime gmtTime);
   int      GetGmtToServerTimeOffset(datetime gmtTime);
 //int      GetLocalToEasternTimeOffset();
   int      GetLocalToGmtOffset(datetime localTime);
 //int      GetLocalToServerTimeOffset();
   int      GetServerToEasternTimeOffset(datetime serverTime);
   int      GetServerToGmtOffset(datetime serverTime);
 //int      GetServerToLocalTimeOffset(datetime serverTime);

   datetime GetEasternPrevSessionStartTime(datetime easternTime);
   datetime GetEasternPrevSessionEndTime(datetime easternTime);
   datetime GetEasternSessionStartTime(datetime easternTime);
   datetime GetEasternSessionEndTime(datetime easternTime);
   datetime GetEasternNextSessionStartTime(datetime easternTime);
   datetime GetEasternNextSessionEndTime(datetime easternTime);

   datetime GetGmtPrevSessionStartTime(datetime gtmTime);
   datetime GetGmtPrevSessionEndTime(datetime gtmTime);
   datetime GetGmtSessionStartTime(datetime gmtTime);
   datetime GetGmtSessionEndTime(datetime gmtTime);
   datetime GetGmtNextSessionStartTime(datetime gtmTime);
   datetime GetGmtNextSessionEndTime(datetime gtmTime);

 //datetime GetLocalPrevSessionStartTime(datetime localTime);
 //datetime GetLocalPrevSessionEndTime(datetime localTime);
 //datetime GetLocalSessionStartTime(datetime localTime);
 //datetime GetLocalSessionEndTime(datetime localTime);
 //datetime GetLocalNextSessionStartTime(datetime localTime);
 //datetime GetLocalNextSessionEndTime(datetime localTime);

   datetime GetServerPrevSessionStartTime(datetime serverTime);
   datetime GetServerPrevSessionEndTime(datetime serverTime);
   datetime GetServerSessionStartTime(datetime serverTime);
   datetime GetServerSessionEndTime(datetime serverTime);
   datetime GetServerNextSessionStartTime(datetime serverTime);
   datetime GetServerNextSessionEndTime(datetime serverTime);

   string   GetDayOfWeek(datetime time, bool format);
   string   GetServerTimezone();
   datetime TimeGMT();

   // Eventlistener
   bool     EventListener(int event, int& results[], int flags);
   bool     EventListener.AccountChange(int& results[], int flags);
   bool     EventListener.AccountPayment(int& results[], int flags);
   bool     EventListener.BarOpen(int& results[], int flags);
   bool     EventListener.HistoryChange(int& results[], int flags);
   bool     EventListener.OrderPlace(int& results[], int flags);
   bool     EventListener.OrderChange(int& results[], int flags);
   bool     EventListener.OrderCancel(int& results[], int flags);
   bool     EventListener.PositionOpen(int& results[], int flags);
   bool     EventListener.PositionClose(int& results[], int flags);

   // Eventhandler
   int      onAccountChange(int details[]);
   int      onAccountPayment(int tickets[]);
   int      onBarOpen(int details[]);
   int      onHistoryChange(int tickets[]);
   int      onOrderPlace(int tickets[]);
   int      onOrderCancel(int tickets[]);
   int      onOrderChange(int tickets[]);
   int      onPositionOpen(int tickets[]);
   int      onPositionClose(int tickets[]);

   // EventTracker (Indikator)
   bool     EventTracker.GetBandLimits(double& limits[3]);
   bool     EventTracker.SetBandLimits(double& limits[3]);
   bool     EventTracker.GetRateGridLimits(double& limits[2]);
   bool     EventTracker.SetRateGridLimits(double& limits[2]);

   // Math
   double   MathRoundFix(double number, int decimals);
   int      MathSign(double number);

   // Numbers
   bool     CompareDoubles(double double1, double double2);
   int      CountDecimals(double number);
   string   DecimalToHex(int number);
   string   FormatNumber(double number, string mask);

   // Strings
   bool     StringStartsWith(string object, string prefix);
   bool     StringIStartsWith(string object, string prefix);
   bool     StringContains(string object, string substring);
   bool     StringIContains(string object, string substring);
   bool     StringEndsWith(string object, string postfix);
   bool     StringIEndsWith(string object, string postfix);
   int      StringFindR(string object, string search);
   bool     StringICompare(string string1, string string2);
   bool     StringIsDigit(string value);
   string   StringLeft(string value, int n);
   string   StringRight(string value, int n);
   string   StringRepeat(string input, int times);
   string   StringReplace(string object, string search, string replace);
   string   StringSubstrFix(string object, int start, int length);
   string   StringToLower(string value);
   string   StringToUpper(string value);
   string   StringTrim(string value);
   int      Explode(string object, string separator, string& results[]);
   string   UrlEncode(string value);

   // sonstiges
   int      DecreasePeriod(int period);
   int      GetAccountHistory(int account, string& destination[][HISTORY_COLUMNS]);
   int      GetAccountNumber();
   double   GetAverageSpread(string symbol);
   int      GetBalanceHistory(int account, datetime& times[], double& values[]);
   string   GetComputerName();
   string   GetErrorDescription(int error);
   string   GetEventDescription(int event);
   int      GetLastLibraryError();
   int      GetMovingAverageMethod(string description);
   string   GetOperationTypeDescription(int operationType);
   int      GetPeriod(string description);
   string   GetPeriodDescription(int period);
   int      GetPeriodFlag(int period);
   string   GetPeriodFlagDescription(int flags);
   int      GetTerminalTopWindow();
   string   GetUninitReasonDescription(int reason);
   string   GetWindowsErrorDescription(int error);
   string   GetWindowText(int hWnd);
   int      iBalanceSeries(int account, double& iBuffer[]);
   int      iBarShiftNext(datetime time);
   int      iBarShiftPrevious(string symbol, int timeframe, datetime time);
   int      IncreasePeriod(int period);
   int      RegisterChartObject(string label, string& objects[]);
   int      RemoveChartObjects(string& objects[]);
   int      SendTextMessage(string receiver, string message);
   int      SetWindowText(int hWnd, string text);


   // ----------------------------------------------------------------------------------
   // Original-MetaQuotes Funktionen   !!! NICHT VERWENDEN !!!
   //
   // Diese Funktionen stehen hier nur zur Dokumentation. Sie sind teilweise fehlerhaft.
   // ----------------------------------------------------------------------------------
   int      RGB(int red, int green, int blue);
   string   DoubleToStrMorePrecision(double number, int precision);
   string   IntegerToHexString(int integer);

#import
