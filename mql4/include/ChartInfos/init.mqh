/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Konfiguration für Preisanzeige einlesen
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer das Bid angezeigt (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Prüfen, ob wir auf einem LFX-Instrument laufen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   if (StringLen(lfxCurrency) > 0) {
      isLfxInstrument   = true;
      lfxCurrencyId     = GetCurrencyId(lfxCurrency);
      lfxChartDeviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);
   }

   // Label erzeugen
   CreateLabels();

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
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
      // Pending-Orders neu einlesen, da die Orders während des Input-Dialogs extern geändert worden sein können
      if (LFX.GetOrders(lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION, lfxOrders) < 0)
         return(last_error);

      // in Library gespeicherte Remote-Positionsdaten restaurieren
      string symbol[1];
      int error = ChartInfos.CopyRemotePositions(false, symbol, remote.position.tickets, remote.position.types, remote.position.data);
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
   if (isLfxInstrument) {
      // in Library gespeicherte Pending-Orders restaurieren
      string symbol[1];
      int error = ChartInfos.CopyLfxOrders(false, symbol, lfxOrders);
      if (IsError(error))
         return(SetLastError(error));

      if (symbol[0] != Symbol()) {
         // bei Symbolwechsel Pending-Orders neu einlesen
         if (LFX.GetOrders(lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION, lfxOrders) < 0)
            return(last_error);
      }
      else {
         // bei Timeframe-Wechsel in Library gespeicherte Remote-Positionsdaten restaurieren
         error = ChartInfos.CopyRemotePositions(false, symbol, remote.position.tickets, remote.position.types, remote.position.data);
         if (IsError(error))
            return(SetLastError(error));
      }
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
      // Pending-Orders neu einlesen
      if (LFX.GetOrders(lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION, lfxOrders) < 0)
         return(last_error);
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
      // Pending-Orders neu einlesen
      if (LFX.GetOrders(lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION, lfxOrders) < 0)
         return(last_error);

      // TODO: irgendwo gespeicherte Remote-Positionsdaten restaurieren (QuickChannel ?)
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
