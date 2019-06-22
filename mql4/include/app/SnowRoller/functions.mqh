
/**
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenz-ID im Bereich 1000-16383 (mindestens 4-stellig, maximal 14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;                                               // TODO: Im Tester müssen fortlaufende IDs generiert werden.
   while (id < SID_MIN || id > SID_MAX) {
      id = MathRand();
   }
   return(id);                                           // TODO: ID auf Eindeutigkeit prüfen
}


/**
 * Holt eine Bestätigung für einen Trade-Request beim ersten Tick ein (um Programmfehlern vorzubeugen).
 *
 * @param  string location - Ort der Bestätigung
 * @param  string message  - Meldung
 *
 * @return bool - Ergebnis
 */
bool ConfirmFirstTickTrade(string location, string message) {
   static bool done, confirmed;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         PlaySoundEx("Windows Notify.wav");
         confirmed = (IDOK == MessageBoxEx(__NAME() + ifString(!StringLen(location), "", " - "+ location), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL));
         if (Tick > 0) RefreshRates();                   // bei Tick==0, also Aufruf in init(), ist RefreshRates() unnötig
      }
      done = true;
   }
   return(confirmed);
}


int lastEventId;


/**
 * Generiert eine neue Event-ID.
 *
 * @return int - ID (ein fortlaufender Zähler)
 */
int CreateEventId() {
   lastEventId++;
   return(lastEventId);
}


/**
 * Gibt die lesbare Konstante eines Status-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("STATUS_UNDEFINED"  );
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_STARTING   : return("STATUS_STARTING"   );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPING   : return("STATUS_STOPPING"   );
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr()  invalid parameter status = "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Ob der angegebene StopPrice erreicht wurde.
 *
 * @param  int    type  - Stop-Typ: OP_BUYSTOP|OP_SELLSTOP|OP_BUY|OP_SELL
 * @param  double price - StopPrice
 *
 * @return bool
 */
bool IsStopTriggered(int type, double price) {
   if (type == OP_BUYSTOP ) return(Ask >= price);        // pending Buy-Stop
   if (type == OP_SELLSTOP) return(Bid <= price);        // pending Sell-Stop

   if (type == OP_BUY     ) return(Bid <= price);        // Long-StopLoss
   if (type == OP_SELL    ) return(Ask >= price);        // Short-StopLoss

   return(!catch("IsStopTriggered()  illegal parameter type = "+ type, ERR_INVALID_PARAMETER));
}
