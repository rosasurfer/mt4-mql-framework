/**
 * stdlib.mqh
 */

#include <stddefine.mqh>   // constant definitions


#import "stdlib.ex4"

   bool     CompareDoubles(double double1, double double2);
   string   DecimalToHex(int number);
   int      DecreasePeriod(int period);
   string   DoubleToStrTrim(double number);
   bool     EventListener(int event, int& results[], int flags);
   bool     EventListener.BarOpen(int& results[], int flags);
   bool     EventListener.OrderPlace(int& results[], int flags);
   bool     EventListener.OrderChange(int& results[], int flags);
   bool     EventListener.OrderCancel(int& results[], int flags);
   bool     EventListener.PositionOpen(int& results[], int flags);
   bool     EventListener.PositionClose(int& results[], int flags);
   bool     EventListener.AccountPayment(int& results[], int flags);
   bool     EventListener.HistoryChange(int& results[], int flags);
   bool     EventListener.AccountChange(int& results[], int flags);
   bool     EventTracker.QuoteLimits(string symbol, double& limits[2]);
   string   FormatMoney(double amount);
   string   FormatPrice(double price, int digits);
   int      GetAccountHistory(int account, string& destination[][HISTORY_COLUMNS]);
   int      GetAccountNumber();
   double   GetAverageSpread(string symbol);
   int      GetBalanceHistory(int account, datetime& times[], double& values[]);
   string   GetComputerName();
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
   string   GetDayOfWeek(datetime time, bool format);
   string   GetErrorDescription(int error);
   string   GetEventDescription(int event);
   string   GetMetaTraderDirectory();
   string   GetModuleDirectoryName();
   int      GetMovingAverageMethod(string description);
   string   GetOperationTypeDescription(int operationType);
   int      GetPeriod(string description);
   string   GetPeriodDescription(int period);
   int      GetPeriodFlag(int period);
   string   GetPeriodFlagDescription(int flags);
   string   GetTradeServerTimezone();
   datetime GetSessionStartTime(datetime time);
   int      GetTopWindow();
   string   GetWindowsErrorDescription(int error);
   string   GetWindowText(int hWnd);
   string   GetUninitReasonDescription(int reason);
   int      iBalanceSeries(int account, double& iBuffer[]);
   int      iBarShiftNext(string symbol, int timeframe, datetime time);
   int      iBarShiftPrevious(string symbol, int timeframe, datetime time);
   int      IncreasePeriod(int period);
   int      onBarOpen(int details[]);
   int      onOrderPlace(int tickets[]);
   int      onOrderChange(int tickets[]);
   int      onOrderCancel(int tickets[]);
   int      onPositionOpen(int tickets[]);
   int      onPositionClose(int tickets[]);
   int      onAccountChange(int details[]);
   int      onAccountPayment(int tickets[]);
   int      onHistoryChange(int tickets[]);
   int      RegisterChartObject(string label, string& objects[]);
   int      RemoveChartObjects(string& objects[]);
   int      SendTextMessage(string receiver, string message);
   bool     StringContains(string object, string substring);
   bool     StringICompare(string string1, string string2);
   bool     StringIContains(string object, string substring);
   bool     StringIsDigit(string value);
   int      StringFindR(string subject, string search);
   string   StringToLower(string value);
   string   StringToUpper(string value);
   string   StringTrim(string value);
   string   UrlEncode(string value);


   // ----------------------------------------------------------------------------------
   // Original-MetaQuotes Funktionen   !!! NICHT VERWENDEN !!!
   //
   // Diese Funktionen stehen hier nur zur Dokumentation. Sie sind teilweise fehlerhaft.
   // ----------------------------------------------------------------------------------
   int    RGB(int red, int green, int blue);
   string DoubleToStrMorePrecision(double number, int precision);
   string IntegerToHexString(int integer);

#import

