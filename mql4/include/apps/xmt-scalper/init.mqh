/**
 * Initialization preprocessing
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // TradingMode
   string values[], sValue = TradingMode;
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("regular", sValue)) { tradingMode = TRADING_MODE_REGULAR; TradingMode = "Regular"; }
   else if (StrStartsWith("virtual", sValue)) { tradingMode = TRADING_MODE_VIRTUAL; TradingMode = "Virtual"; }
   else if (StrStartsWith("mirror",  sValue)) { tradingMode = TRADING_MODE_MIRROR;  TradingMode = "Mirror";  }
   else                                                      return(catch("onInit(1)  Invalid input parameter TradingMode: "+ DoubleQuoteStr(TradingMode), ERR_INVALID_INPUT_PARAMETER));
   // EntryIndicator
   if (EntryIndicator < 1 || EntryIndicator > 3)             return(catch("onInit(2)  invalid input parameter EntryIndicator: "+ EntryIndicator +" (must be from 1-3)", ERR_INVALID_INPUT_PARAMETER));
   // IndicatorTimeframe
   if (IsTesting() && IndicatorTimeframe!=Period())          return(catch("onInit(3)  illegal test on "+ PeriodDescription(Period()) +" for configured EA timeframe "+ PeriodDescription(IndicatorTimeframe), ERR_RUNTIME_ERROR));
   // BreakoutReversal
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if (LT(BreakoutReversal*Pip, stopLevel*Point))            return(catch("onInit(4)  invalid input parameter BreakoutReversal: "+ NumberToStr(BreakoutReversal, ".1+") +" (must be larger than MODE_STOPLEVEL)", ERR_INVALID_INPUT_PARAMETER));
   double minLots=MarketInfo(Symbol(), MODE_MINLOT), maxLots=MarketInfo(Symbol(), MODE_MAXLOT);
   if (MoneyManagement) {
      // Risk
      if (LE(Risk, 0))                                       return(catch("onInit(5)  invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
      double lots = CalculateLots(false); if (IsLastError()) return(last_error);
      if (LT(lots, minLots))                                 return(catch("onInit(6)  not enough money ("+ DoubleToStr(AccountEquity()-AccountCredit(), 2) +") for input parameter Risk="+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")", ERR_NOT_ENOUGH_MONEY));
      if (GT(lots, maxLots))                                 return(catch("onInit(7)  too large input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" larger than MODE_MAXLOT="+  NumberToStr(maxLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
   }
   else {
      // ManualLotsize
      if (LT(ManualLotsize, minLots))                        return(catch("onInit(8)  too small input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
      if (GT(ManualLotsize, maxLots))                        return(catch("onInit(9)  too large input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (larger than MODE_MAXLOT="+ NumberToStr(maxLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
   }
   // EA.StopOnProfit / EA.StopOnLoss
   if (EA.StopOnProfit && EA.StopOnLoss) {
      if (EA.StopOnProfit <= EA.StopOnLoss)                  return(catch("onInit(10)  input parameter mis-match EA.StopOnProfit="+ DoubleToStr(EA.StopOnProfit, 2) +" / EA.StopOnLoss="+ DoubleToStr(EA.StopOnLoss, 2) +" (profit must be larger than loss)", ERR_INVALID_INPUT_PARAMETER));
   }

   // initialize/normalize global vars
   if (UseSpreadMultiplier) { minBarSize = 0;              sMinBarSize = "-";                                }
   else                     { minBarSize = MinBarSize*Pip; sMinBarSize = DoubleToStr(MinBarSize, 1) +" pip"; }
   MaxSpread     = NormalizeDouble(MaxSpread, 1);
   sMaxSpread    = DoubleToStr(MaxSpread, 1);
   orderSlippage = Round(MaxSlippage*Pip/Point);
   orderComment  = "XMT"+ ifString(ChannelBug, "-ChBug", "") + ifString(TakeProfitBug, "-TpBug", "");

   if (!Magic) Magic = GenerateMagicNumber();      // old

   if (!ReadOrderLog()) return(last_error);
   SS.All();

   return(catch("onInit(11)"));
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   SetLogfile(GetLogFilename());
   return(last_error);
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   SetLogfile(GetLogFilename());
   return(last_error);
}


/**
 * Called after the current chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   SetLogfile("");
   return(SetLastError(ERR_CANCELLED_BY_USER));
}
