/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration für Preisanzeige auswerten
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer PRICE_BID verwendet (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Prüfen, ob wir unter einem LFX-Instrument laufen und wenn ja, LFX-Details initialisieren
   if      (StringStartsWith(Symbol(), "LFX")) { isLfxInstrument = true; lfxCurrency = StringRight(Symbol(), -3); }
   else if (StringEndsWith  (Symbol(), "LFX")) { isLfxInstrument = true; lfxCurrency = StringLeft (Symbol(), -3); }
   else                                        { isLfxInstrument = false;                                         }
   if (isLfxInstrument) {
      lfxCurrencyId = GetCurrencyId(lfxCurrency);
      if (!LFX.CheckAccount()) {
         debug("onInit(0.2)->LFX.CheckAccount() = false  cancelling init()", last_error);
         return(-1);                                                 // -1: kritischer Fehler, init() wird sofort abgebrochen
      }
   }

   // Label erzeugen
   CreateLabels();
   return(catch("onInit(2)"));
}


/**
 * außerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   if (isLfxInstrument) {
      // offene Pending-Orders der aktuellen Währung einlesen
      LFX.GetSelectedOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);

      // in Library gespeicherte Remote-Positionsdaten restaurieren, können aktueller als die gelesenen Remote-Orderdaten sein
      int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 * innerhalb iCustom(): ?
 *
 * @return int - Fehlerstatus
 */
int onInitChartChange() {
   // bei Symbolwechsel
   // ???

   // bei Timeframe-Wechsel
   if (isLfxInstrument) {
      // in Library gespeicherte Remote-Orders restaurieren
      int error = ChartInfos.CopyLfxOrders(false, lfxOrders);
      if (IsError(error))
         return(SetLastError(error));

      // in Library gespeicherte Remote-Positionsdaten restaurieren, können aktueller als die Remote-Orderdaten sein
      error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * außerhalb iCustom(): wenn Template mit Indikator darin geladen wird (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * innerhalb iCustom(): in allen init()-Fällen, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   if (isLfxInstrument) {
      // offene Pending-Orders der aktuellen LFX-Währung einlesen
      LFX.GetSelectedOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);

      if (Symbol() == "AUDLFX") {
         int orders = ArrayRange(lfxOrders, 0);
         debug("onInitUndefined()   got "+ orders +" pending order"+ ifString(orders==1, "", "s"));
         if (orders > 0) {
            LFX_ORDER.toStr(lfxOrders, true);
         }
      }
   }
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ???
 * innerhalb iCustom(): im Tester nach Test-Restart bei VisualMode=Off, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Recompilation, vorhandener Indikator, kein Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   if (isLfxInstrument) {
      // offene Pending-Orders der aktuellen LFX-Währung einlesen
      LFX.GetSelectedOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);

      if (Symbol() == "AUDLFX") {
         int orders = ArrayRange(lfxOrders, 0);
         debug("onInitRecompile()   got "+ orders +" pending order"+ ifString(orders==1, "", "s"));
         if (orders > 0) {
            LFX_ORDER.toStr(lfxOrders, true);
         }
      }
   }
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing
 *
 * @return int - Fehlerstatus
 *
int afterInit() {
   return(NO_ERROR);
}
*/
