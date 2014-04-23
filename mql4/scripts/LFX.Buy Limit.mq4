/**
 * Erzeugt eine neue LFX-"Buy Limit"-Order, die überwacht und bei Erreichen des Limit-Preises automatisch ausgeführt wird.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

//#include <lfx.mqh>
//#include <win32api.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern double Units           = 1.0;                                 // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice;
extern double StopLossPrice;
extern double TakeProfitPrice;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string lfxCurrency;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) LFX-Currency bestimmen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot manage LFX orders on a non LFX chart (\""+ Symbol() +"\")", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }


   // (2) Parametervalidierung
   // Units
   if (NE(MathModFix(Units, 0.1), 0))    return(catch("onInit(1)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   if (Units < 0.1 || Units > 1)         return(catch("onInit(2)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   if (LimitPrice >= Bid)                return(catch("onInit(3)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be lower than the current LFX price)", ERR_INVALID_INPUT_PARAMVALUE));
   if (LimitPrice <= 0)                  return(catch("onInit(4)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be positive)", ERR_INVALID_INPUT_PARAMVALUE));

   // StopLossPrice
   if (StopLossPrice < 0)                return(catch("onInit(5)   Illegal input parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +" (can't be negative)", ERR_INVALID_INPUT_PARAMVALUE));
   if (StopLossPrice > 0)
      if (StopLossPrice >= LimitPrice)   return(catch("onInit(6)   Illegal input parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +" (must be lower than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfitPrice
   if (TakeProfitPrice != 0)
      if (TakeProfitPrice <= LimitPrice) return(catch("onInit(7)   Illegal input parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +" (must be higher than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));

   return(catch("onInit(8)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // (1) Sicherheitsabfrage
   PlaySound("notify.wav");
   int button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "")
                         +"Do you really want to place a limit order to Buy "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                         +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                         + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
                         + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
                         __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(1)"));


   // (2) Order in .ini-Datei speichern
   //Ticket = Symbol, Label, OrderType, Units, OpenTime_GMT, OpenEquity, OpenPrice, StopLoss, TakeProfit, CloseTime_GMT, ClosePrice, Profit, LastUpdate_GMT
   //  x        x       x        x        x        x                        x          x          x
   string sSymbol      = lfxCurrency;
   /*
   string sLabel       = "#"+ counter;                          sLabel       = StringRightPad(sLabel     ,  9, " ");
   string sOrderType   = OperationTypeDescription(direction);   sOrderType   = StringRightPad(sOrderType ,  9, " ");
   string sUnits       = NumberToStr(Units, ".+");              sUnits       = StringLeftPad (sUnits     ,  5, " ");
   string sOpenTime    = TimeToStr(TimeGMT(), TIME_FULL);
   string sOpenEquity  = DoubleToStr(equity, 2);                sOpenEquity  = StringLeftPad(sOpenEquity ,  7, " ");
   string sOpenPrice   = DoubleToStr(openPrice, lfxDigits);     sOpenPrice   = StringLeftPad(sOpenPrice  ,  9, " ");
   string sStopLoss    = "0";                                   sStopLoss    = StringLeftPad(sStopLoss   ,  8, " ");
   string sTakeProfit  = "0";                                   sTakeProfit  = StringLeftPad(sTakeProfit , 10, " ");
   string sCloseTime   = "0";                                   sCloseTime   = StringLeftPad(sCloseTime  , 19, " ");
   string sClosePrice  = "0";                                   sClosePrice  = StringLeftPad(sClosePrice , 10, " ");
   string sOrderProfit = "0";                                   sOrderProfit = StringLeftPad(sOrderProfit,  7, " ");
   string sLastUpdate  = sOpenTime;

   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = ShortAccountCompany() +"."+ GetAccountNumber();
   string key     = magicNumber;
   string value   = sSymbol +", "+ sLabel +", "+ sOrderType +", "+ sUnits +", "+ sOpenTime +", "+ sOpenEquity +", "+ sOpenPrice +", "+ sStopLoss +", "+ sTakeProfit +", "+ sCloseTime +", "+ sClosePrice +", "+ sOrderProfit +", "+ sLastUpdate;

   if (!WritePrivateProfileStringA(section, key, " "+ value, file))
      return(catch("onStart(11)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
   */

   return(last_error);
}
