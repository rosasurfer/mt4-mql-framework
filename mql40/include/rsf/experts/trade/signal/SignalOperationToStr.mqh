/**
 * Return a readable representation of a signal operation flag.
 *
 * @param  int flag
 *
 * @return string - readable flag or an empty string in case of errors
 */
string SignalOperationToStr(int flag) {
   switch (flag) {
      case NULL:               return("(undefined)"       );
      case SIG_OP_LONG:        return("SIG_OP_LONG"       );
      case SIG_OP_SHORT:       return("SIG_OP_SHORT"      );
      case SIG_OP_CLOSE_ALL:   return("SIG_OP_CLOSE_ALL"  );
      case SIG_OP_CLOSE_LONG:  return("SIG_OP_CLOSE_LONG" );
      case SIG_OP_CLOSE_SHORT: return("SIG_OP_CLOSE_SHORT");
   }
   return(_EMPTY_STR(catch("SignalOperationToStr(1)  "+ instance.name +" invalid parameter flag: "+ flag, ERR_INVALID_PARAMETER)));
}
