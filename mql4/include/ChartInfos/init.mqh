/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Konfiguration f¸r Preisanzeige einlesen
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer das Bid angezeigt (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Pr¸fen, ob wir auf einem LFX-Instrument laufen
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
 * auﬂerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   if (isLfxInstrument) {
      if (!Tick) {
         // erste Parameter-Eingabe eines neuen Indikators: LFX-Status komplett neu einlesen
         if (!RestoreLfxStatusFromFiles())
            return(last_error);
      }
      else {
         // Parameter-Wechsel eines vorhandenen Indikators: in Library gespeicherten LFX-Status restaurieren
         string s = "";
         if (!RestoreLfxStatusFromLib(s))
            return(last_error);
      }
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
   if (isLfxInstrument) {
      string prevSymbol = "";

      // in Library gespeicherten LFX-Status restaurieren, um Symbolwechsel zu erkennen
      if (!RestoreLfxStatusFromLib(prevSymbol))
         return(last_error);

      if (Symbol() != prevSymbol) {
         // Symbolwechsel: volatilen LFX-Status des alten Symbols speichern und Status des aktuellen Symbols komplett neu einlesen
         if (!SaveVolatileLfxStatus())
            return(last_error);

         if (!RestoreLfxStatusFromFiles())
            return(last_error);
      }
      else {
         // Timeframe-Wechsel: in Library gespeicherter LFX-Status ist bereits restauriert
      }

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
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
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
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
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
