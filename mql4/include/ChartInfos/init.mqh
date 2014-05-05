/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration f¸r Preisanzeige auswerten
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer PRICE_BID verwendet (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Pr¸fen, ob wir auf einem LFX-Instrument laufen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   if (StringLen(lfxCurrency) > 0) {
      isLfxInstrument = true;
      lfxCurrencyId   = GetCurrencyId(lfxCurrency);
   }

   // Label erzeugen
   CreateLabels();
   return(catch("onInit(2)"));
}


/**
 * auﬂerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   if (isLfxInstrument) {
      // Pending-Orders neu einlesen, da die Orders w‰hrend des Input-Dialogs extern ge‰ndert worden sein kˆnnen
      LFX.GetOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);

      // in Library gespeicherte Remote-Positionsdaten restaurieren
      int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 * innerhalb iCustom(): ?
 *
 * @return int - Fehlerstatus
 */
int onInitChartChange() {
   // bei Symbolwechsel
   // ???

   // bei Timeframe-Wechsel
   if (isLfxInstrument) {
      // in Library gespeicherte Pending-Orders restaurieren
      int error = ChartInfos.CopyLfxOrders(false, lfxOrders);
      if (IsError(error))
         return(SetLastError(error));

      // in Library gespeicherte Remote-Positionsdaten restaurieren
      error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * auﬂerhalb iCustom(): wenn Template mit Indikator darin geladen wird (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * innerhalb iCustom(): in allen init()-F‰llen, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   if (isLfxInstrument) {
      // Pending-Orders neu einlesen
      LFX.GetOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);
   }
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): ???
 * innerhalb iCustom(): im Tester nach Test-Restart bei VisualMode=Off, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): nach Recompilation, vorhandener Indikator, kein Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   if (isLfxInstrument) {
      // Pending-Orders neu einlesen
      LFX.GetOrders(lfxOrders, lfxCurrency, OF_PENDINGORDER|OF_PENDINGPOSITION);

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
