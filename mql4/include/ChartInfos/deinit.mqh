/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();
   StopQuickChannels();
   return(last_error);
}


/**
 * auﬂerhalb iCustom(): bei Parameter‰nderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameterChange() {
   // LFX-Orders in Library zwischenspeichern (nur formhalber, bei onInitParameterChange() werden sie wegen des zwischenzeitlichen Input-Dialogs neu aus der Datei eingelesen)
   int error = ChartInfos.CopyLfxOrders(true, lfxOrders);
   if (IsError(error))
      return(SetLastError(error));

   // Remote-Positionsdaten in Library zwischenspeichern
   error = ChartInfos.CopyRemotePositions(true, remote.position.tickets, remote.position.types, remote.position.data);
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
   // LFX-Orders in Library zwischenspeichern
   int error = ChartInfos.CopyLfxOrders(true, lfxOrders);
   if (IsError(error))
      return(SetLastError(error));

   // Remote-Positionsdaten in Library zwischenspeichern
   error = ChartInfos.CopyRemotePositions(true, remote.position.tickets, remote.position.types, remote.position.data);
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
   // Remote-Positionsdaten in "remote_positions.ini" speichern
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
