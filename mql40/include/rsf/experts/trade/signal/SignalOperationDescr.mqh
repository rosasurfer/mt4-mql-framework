/**
 * Return a description of a signal operation flag.
 *
 * @param  int flag
 *
 * @return string - description or an empty string in case of errors
 */
string SignalOperationDescr(int flag) {
   switch (flag) {
      case NULL:               return("(undefined)"       );
      case SIG_OP_LONG:        return("long"       );
      case SIG_OP_SHORT:       return("short"      );
      case SIG_OP_CLOSE_ALL:   return("close all"  );
      case SIG_OP_CLOSE_LONG:  return("close long" );
      case SIG_OP_CLOSE_SHORT: return("close short");
   }
   return(_EMPTY_STR(catch("SignalOperationDescr(1)  "+ instance.name +" invalid parameter flag: "+ flag, ERR_INVALID_PARAMETER)));
}
