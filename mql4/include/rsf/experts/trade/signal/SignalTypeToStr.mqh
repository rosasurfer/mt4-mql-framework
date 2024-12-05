/**
 * Return a readable representation of a signal type.
 *
 * @param  int type
 *
 * @return string - readable constant or an empty string in case of errors
 */
string SignalTypeToStr(int type) {
   switch (type) {
      case NULL:                return("(undefined)"        );
      case SIG_TYPE_TIME:       return("SIG_TYPE_TIME"      );
      case SIG_TYPE_STOPLOSS:   return("SIG_TYPE_STOPLOSS"  );
      case SIG_TYPE_TAKEPROFIT: return("SIG_TYPE_TAKEPROFIT");
      case SIG_TYPE_ZIGZAG:     return("SIG_TYPE_ZIGZAG"    );
   }
   return(_EMPTY_STR(catch("SignalTypeToStr(1)  "+ instance.name +" invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}
