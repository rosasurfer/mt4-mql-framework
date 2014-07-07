/**
 * Deinitialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();
   QC.StopChannels();
   return(last_error);
}


/**
 * auﬂerhalb iCustom(): bei Parameter‰nderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameterChange() {
   string symbol[1]; symbol[0] = Symbol();

   // LFX-Orders in Library zwischenspeichern, um volatilen P/L-Status nicht zu verlieren
   int error = ChartInfos.CopyLfxOrders(true, symbol, lfxOrders);
   if (IsError(error))
      return(SetLastError(error));
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): bei Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartChange() {
   string symbol[1]; symbol[0] = Symbol();

   // LFX-Orders in Library zwischenspeichern, um volatilen P/L-Status nicht zu verlieren
   int error = ChartInfos.CopyLfxOrders(true, symbol, lfxOrders);
   if (IsError(error))
      return(SetLastError(error));
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen
 * innerhalb iCustom(): in allen deinit()-F‰llen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   // TODO: LFX-Orders in Datei speichern, um volatilen Status nicht zu verlieren (Laufzeit testen)
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): bei Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   // TODO: LFX-Orders irgendwo zwischenspeichern, um volatilen P/L-Status nicht zu verlieren (QuickChannel ?)
   return(NO_ERROR);
}


/**
 * Deinitialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
*/
