/**
 * stdlib.mqh
 */

#include <stddefine.mqh>   // constant definitions


#import "stdlib.ex4"

   bool     CheckEvent(int event, int& results[], int flags);
   bool     CheckEvent.BarOpen(int& results[], int flags);
   bool     CheckEvent.OrderPlace(int& results[], int flags);
   bool     CheckEvent.OrderChange(int& results[], int flags);
   bool     CheckEvent.OrderCancel(int& results[], int flags);
   bool     CheckEvent.PositionOpen(int& results[], int flags);
   bool     CheckEvent.PositionClose(int& results[], int flags);
   bool     CheckEvent.AccountPayment(int& results[], int flags);
   bool     CheckEvent.HistoryChange(int& results[], int flags);
   bool     CompareDoubles(double double1, double double2);
   int      DecreasePeriod(int period);
   string   DoubleToStrTrim(double number);
   string   FormatMoney(double amount);
   string   FormatPrice(double price, int digits);
   int      GetAccountHistory(int account, string& destination[][HISTORY_COLUMNS]);
   double   GetAverageSpread(string symbol);
   int      GetBalanceHistory(int account, datetime& times[], double& values[]);
   string   GetComputerName();
   string   GetDayOfWeek(datetime time, bool format);
   string   GetErrorDescription(int error);
   string   GetEventDescription(int event);
   string   GetMetaTraderDirectory();
   string   GetModuleDirectoryName();
   string   GetOperationTypeDescription(int operationType);
   string   GetPeriodDescription(int period);
   string   GetPeriodFlagDescription(int flags);
   int      GetTradeServerEETOffset();
   int      GetTradeServerGMTOffset();
   datetime GetSessionStartTime(datetime time);
   string   GetWinErrorDescription(int error);
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
   int      onAccountPayment(int tickets[]);
   int      onHistoryChange(int tickets[]);
   bool     QuoteTracker.SMSLimits(string symbol, double& limits[2]);
   bool     QuoteTracker.SoundLimits(string symbol, double& limits[2]);
   int      RegisterChartObject(string label, string& objects[]);
   int      RemoveChartObjects(string& objects[]);
   bool     StringCompare(string string1, string string2, bool ignoreCase);
   int      StringFindR(string subject, string search);
   string   StringToLower(string value);
   string   StringToUpper(string value);
   string   StringTrim(string value);


   // ----------------------------------------------------------------------------------
   // Original-MetaQuotes Funktionen   !!! NICHT VERWENDEN !!!
   //
   // Diese Funktionen stehen hier nur zur Dokumentation. Sie sind teilweise fehlerhaft.
   // ----------------------------------------------------------------------------------
   int    RGB(int red, int green, int blue);
   string DoubleToStrMorePrecision(double number, int precision);
   string IntegerToHexString(int number);

#import
