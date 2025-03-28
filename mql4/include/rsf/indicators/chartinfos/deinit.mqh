/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   // uninstall the chart ticker
   if (__tickTimerId > NULL) {
      int id = __tickTimerId; __tickTimerId = NULL;
      if (!ReleaseTickTimer(id)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   // unregister the order event listener
   if (Track.Orders) {
      string name = orderTracker.key + StrToLower(Symbol());
      int counter = Max(GetPropA(hWndDesktop, name), 1) - 1;
      SetPropA(hWndDesktop, name, counter);
   }

   StoreStatus();
   QC.StopChannels();
   ScriptRunner.StopParamSender();
   return(last_error);
}


/**
 * außerhalb iCustom(): bei Parameteränderung
 * innerhalb iCustom(): nie
 *
 * @return int - error status
 */
int onDeinitParameters() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): bei Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen, auch vorm Laden eines Profils oder Templates
 * innerhalb iCustom(): in allen deinit()-Fällen
 *
 * @return int - error status
 */
int onDeinitRemove() {
   // Profilwechsel oder Terminal-Shutdown

   // gecachte LFX-Orderdaten speichern
   if (!SaveLfxOrderCache())
      return(last_error);
   return(NO_ERROR);
}


/**
 *
 * @return int - error status
 */
int onDeinitTemplate() {
   return(onDeinitRemove());
}


/**
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   return(onDeinitRemove());
}


/**
 *
 * @return int - error status
 */
int onDeinitClose() {
   return(onDeinitRemove());
}


/**
 * außerhalb iCustom(): bei Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   // gecachte LFX-Orderdaten speichern
   if (!SaveLfxOrderCache())
      return(last_error);
   return(NO_ERROR);
}
