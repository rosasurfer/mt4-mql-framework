/**
 * Initialisierung Preprocessing-Hook
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
 * Nach manuellem Laden des Indikators durch den User. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.User() {
   if (isLfxInstrument) {
      // LFX-Status einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.Template() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.Parameters() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung der aktuellen Chartperiode. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.TimeframeChange() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.SymbolChange() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status des alten Symbols restaurieren und speichern
      if (!RestoreLfxStatusFromLib())   return(last_error);
      if (!SaveVolatileLfxStatus())     return(last_error);

      // LFX-Status des aktuellen Symbols einlesen
      if (!RestoreLfxStatusFromFiles()) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung. Kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInit.Recompile() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
   }
   return(NO_ERROR);
}
