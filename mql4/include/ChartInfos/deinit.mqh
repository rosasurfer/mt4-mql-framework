/**
 * Deinitialisierung
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

   // Remote-Positionsdaten in Library zwischenspeichern
   int error = ChartInfos.CopyRemotePositions(true, symbol, remote.position.tickets, remote.position.types, remote.position.data);
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

   // Pending-Orders in Library zwischenspeichern
   int error = ChartInfos.CopyLfxOrders(true, symbol, lfxOrders);
   if (IsError(error))
      return(SetLastError(error));

   // Remote-Positionsdaten in Library zwischenspeichern
   error = ChartInfos.CopyRemotePositions(true, symbol, remote.position.tickets, remote.position.types, remote.position.data);
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
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): bei Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   // TODO: Remote-Positionsdaten irgendwo zwischenspeichern (QuickChannel ?)
   return(NO_ERROR);
}


/**
 * Deinitialisierung Postprocessing
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
*/
