/**
 * Return a readable representation of a signal trade flag.
 *
 * @param  int flag
 *
 * @return string - readable flag or an empty string in case of errors
 */
string SignalTradeToStr(int flag) {
   switch (flag) {
      case NULL:                  return("(undefined)"          );
      case SIG_TRADE_LONG:        return("SIG_TRADE_LONG"       );
      case SIG_TRADE_SHORT:       return("SIG_TRADE_SHORT"      );
      case SIG_TRADE_CLOSE_ALL:   return("SIG_TRADE_CLOSE_ALL"  );
      case SIG_TRADE_CLOSE_LONG:  return("SIG_TRADE_CLOSE_LONG" );
      case SIG_TRADE_CLOSE_SHORT: return("SIG_TRADE_CLOSE_SHORT");
   }
   return(_EMPTY_STR(catch("SignalTradeToStr(1)  "+ instance.name +" invalid parameter flag: "+ flag, ERR_INVALID_PARAMETER)));
}
