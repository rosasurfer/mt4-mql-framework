/**
 * Compose a message for a closed position not closed by the EA itself. The ticket must be selected.
 *
 * @param  _Out_ int error - error code to be returned (if any)
 *
 * @return string
 */
string ComposePositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 was [unexpectedly ]closed [by SL|TP ]at 1.5457'2 ([slippage: -0.3 pip, ]market: Bid/Ask) [sl|tp|so: 47.7%/169.20/354.40]
   error = NO_ERROR;

   int    ticket      = OrderTicket();
   int    type        = OrderType();
   double lots        = OrderLots();
   double closePrice  = OrderClosePrice();
   double stoploss    = OrderStopLoss();
   double takeprofit  = OrderTakeProfit();
   string comment     = OrderComment();
   bool   closedBySO  = StrStartsWith(comment, "so:");
   bool   closedBySL  = StrEndsWith(comment, "[sl]");
   bool   closedByTP  = StrEndsWith(comment, "[tp]");
   double slippage    = 0;

   // closedBySL
   if (!stoploss || !lots || closedBySO || closedByTP) {
      closedBySL = false;
   }
   else if (!closedBySL) {
      if (type == OP_BUY) closedBySL = LE(closePrice, stoploss, Digits);
      else                closedBySL = GE(closePrice, stoploss, Digits);
   }
   if (closedBySL) slippage = NormalizeDouble(closePrice-stoploss, Digits);

   // closedByTP
   if (!takeprofit|| !lots || closedBySO || closedBySL) {
      closedByTP = false;
   }
   else if (!closedByTP) {
      if (type == OP_BUY) closedByTP = GE(closePrice, takeprofit, Digits);
      else                closedByTP = LE(closePrice, takeprofit, Digits);
   }
   if (closedByTP) slippage = NormalizeDouble(closePrice-takeprofit, Digits);
   if (type == OP_SELL) slippage = -slippage;                                 // same for both limits

   string sType       = OperationTypeDescription(type);
   string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);
   string sUnexpected = ifString(closedBySL || closedByTP || (__isTesting && __CoreFunction==CF_DEINIT), "", "unexpectedly ");
   string sBySL       = ifString(closedBySL, "by SL ", "");
   string sByTP       = ifString(closedByTP, "by TP ", "");
   string sSlippage   = ifString(slippage==NULL, "", "slippage: "+ NumberToStr(slippage/pUnit, "R+."+ pDigits) + ifString(spUnit=="pip", " pip", "") +", ");
   string sComment    = ifString(comment==instance.name, "", " "+ comment);

   string msg = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" was "+ sUnexpected +"closed "+ sBySL + sByTP +"at "+ sClosePrice;
          msg = msg +" ("+ sSlippage +"market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")"+ sComment;

   if (closedBySO)                                    error = ERR_MARGIN_STOPOUT;
   else if (closedBySL || closedByTP)                 error = NO_ERROR;
   else if (__isTesting && __CoreFunction==CF_DEINIT) error = NO_ERROR;
   else                                               error = ERR_CONCURRENT_MODIFICATION;

   return(msg);
}
