/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer PRICE_BID verwendet (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   CreateLabels();

   // Pr¸fen, ob wir auf einem LFX-Chart laufen
   isLfxChart = (StringLeft(Symbol(), 3)=="LFX" || StringRight(Symbol(), 3)=="LFX");

   return(catch("onInit(2)"));
}


/**
 * auﬂerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei ViualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
 */
int onInitParameterChange() {
   // in Library gespeicherte Remote-Positionsdaten restaurieren
   int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
   if (IsError(error))
      return(SetLastError(error));
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 * innerhalb iCustom(): ?
 *
 * @return int - Fehlerstatus
 *
 */
int onInitChartChange() {
   // in Library gespeicherte Remote-Positionsdaten restaurieren
   int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
   if (IsError(error))
      return(SetLastError(error));
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * auﬂerhalb iCustom(): wenn Indikator im Template (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * innerhalb iCustom(): in allen init()-F‰llen, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): ?
 * innerhalb iCustom(): im Tester nach Test-Restart bei VisualMode=Off, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): nach Recompile, vorhandener Indikator, kein Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
 */
int onInitRecompile() {
   // in "remote_positions.ini" gespeicherte Positionsdaten restaurieren
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
