/**
 * Deinitialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // ggf. Offline-Ticker deinstallieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   // in allen deinit()-Szenarien Laufzeitstatus speichern
   if (!StoreRuntimeStatus()) return(last_error);

   // unregister the order event listener
   if (track.orders) {
      static int hWnd;
      if (!hWnd) hWnd = GetTerminalMainWindow();
      string name = "order-tracker:"+ StrToLower(Symbol());
      int counter = GetWindowIntegerA(hWnd, name);

      if (counter > 0) {
         counter--;
         if (!SetWindowIntegerA(hWnd, name, counter))
            return(!catch("onDeinit(2)->SetWindowIntegerA() => FALSE", ERR_RUNTIME_ERROR));
      }
      else logError("onDeinit(3)  illegal event listener counter in main window: "+ counter, ERR_ILLEGAL_STATE);
   }

   QC.StopChannels();
   ScriptRunner.StopParamSender();
   return(last_error);
}


/**
 * auﬂerhalb iCustom(): bei Parameter‰nderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameters() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): bei Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartChange() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * auﬂerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen, auch vorm Laden eines Profils oder Templates
 * innerhalb iCustom(): in allen deinit()-F‰llen
 *
 * @return int - Fehlerstatus
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
 * @return int - Fehlerstatus
 */
int onDeinitTemplate() {
   return(onDeinitRemove());
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartClose() {
   return(onDeinitRemove());
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinitClose() {
   return(onDeinitRemove());
}


/**
 * auﬂerhalb iCustom(): bei Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   // gecachte LFX-Orderdaten speichern
   if (!SaveLfxOrderCache())
      return(last_error);
   return(NO_ERROR);
}
