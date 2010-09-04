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
   datetime EasternToServerTime(datetime easternTime);
   datetime GmtToEasternTime(datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);
   datetime ServerToEasternTime(datetime serverTime);
   datetime ServerToGMT(datetime serverTime);

   int      GetEasternToGmtOffset(datetime easternTime);
   int      GetEasternToServerTimeOffset(datetime easternTime);
   int      GetGmtToEasternTimeOffset(datetime gmtTime);
   int      GetGmtToServerTimeOffset(datetime gmtTime);
   int      GetLocalToGmtOffset();
   int      GetServerToEasternTimeOffset(datetime serverTime);
   int      GetServerToGmtOffset(datetime serverTime);

   datetime GetEasternPrevSessionStartTime(datetime easternTime);
   datetime GetEasternPrevSessionEndTime(datetime easternTime);
   datetime GetEasternSessionStartTime(datetime easternTime);
   datetime GetEasternSessionEndTime(datetime easternTime);
   datetime GetEasternNextSessionStartTime(datetime easternTime);
   datetime GetEasternNextSessionEndTime(datetime easternTime);

   datetime GetGmtPreviousSessionStartTime(datetime gtmTime);
   datetime GetGmtPreviousSessionEndTime(datetime gtmTime);
   datetime GetGmtSessionStartTime(datetime gmtTime);
   datetime GetGmtSessionEndTime(datetime gmtTime);
   datetime GetGmtNextSessionStartTime(datetime gtmTime);
   datetime GetGmtNextSessionEndTime(datetime gtmTime);

   datetime GetServerPrevSessionStartTime(datetime serverTime);
   datetime GetServerPreviousSessionEndTime(datetime serverTime);
   datetime GetServerSessionStartTime(datetime serverTime);
   datetime GetServerSessionEndTime(datetime serverTime);
   datetime GetServerNextSessionStartTime(datetime serverTime);
   datetime GetServerNextSessionEndTime(datetime serverTime);

   string   GetDayOfWeek(datetime time, bool format);
   string   GetServerTimezone();

   // Events
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
   bool     EventTracker.GetGridLimits(double& limits[2]);
   bool     EventTracker.SetGridLimits(double& limits[2]);

   // Numbers
   bool     CompareDoubles(double double1, double double2);
   string   DecimalToHex(int number);
   string   DoubleToStrTrim(double number);
   string   FormatMoney(double amount);
   string   FormatPrice(double price, int digits);

   // Strings
   bool     StringContains(string object, string substring);
   bool     StringIContains(string object, string substring);
   int      StringFindR(string subject, string search);
   bool     StringICompare(string string1, string string2);
   bool     StringIsDigit(string value);
   string   StringToLower(string value);
   string   StringToUpper(string value);
   string   StringTrim(string value);
   int      Explode(string subject, string separator, string& results[]);
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
   string   GetTerminalDirectory();
   int      GetTerminalTopWindow();
   string   GetUninitReasonDescription(int reason);
   string   GetWindowsErrorDescription(int error);
   string   GetWindowText(int hWnd);
   int      iBalanceSeries(int account, double& iBuffer[]);
   int      iBarShiftNext(string symbol, int timeframe, datetime time);
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
