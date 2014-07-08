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
 * außerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   if (isLfxInstrument) {
      // offene LFX-Orders neu einlesen, da sie während des Input-Dialogs extern geändert worden sein können
      if (!RefreshLfxOrders(true))
         return(last_error);
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
      // in Library gespeicherte LFX-Orders restaurieren
      string symbol[1];
      int error = ChartInfos.CopyLfxOrders(false, symbol, lfxOrders);
      if (IsError(error))
         return(SetLastError(error));

      int size = ArrayRange(lfxOrders, 0);

      if (symbol[0] != Symbol()) {
         // bei Symbolwechsel LFX-Orders des alten Symbols speichern und LFX-Orders des neuen Symbols neu einlesen
         if (!LFX.SaveOrders(lfxOrders))
               return(last_error);
         if (!RefreshLfxOrders(false))
            return(last_error);
      }
      else {
         // Zähler der offenen Positionen und Open-Indizes aktualisieren
         ArrayResize(lfxOrders.isOpen, size);
         lfxOrders.positions.size = 0;

         for (int i=0; i < size; i++) {
            lfxOrders.isOpen[i] = los.IsOpen(lfxOrders, i);
            if (lfxOrders.isOpen[i])
               lfxOrders.positions.size++;
         }
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
      // offene LFX-Orders neu einlesen
      if (!RefreshLfxOrders(false))
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
      // offene LFX-Orders neu einlesen
      if (!RefreshLfxOrders(false))
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
