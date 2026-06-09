/**
 * Initialization preprocessing.
 *
 * @return int - error status
 */
int onInit() {
   hWndDesktop = GetDesktopWindow();

   // reset global vars with account state (we may be called from an event handler, outside an init cycle)
   mm.done                 = false;
   mm.externalAssetsCached = false;                      // invalidate cached external assets
   positions.analyzed      = false;                      // reparse configuration
   ArrayResize(config.terms,   0);                       //
   ArrayResize(config.sData,   0);                       //
   ArrayResize(config.dData,   0);                       //
   ArrayResize(positions.data, 0);                       //
   ArrayResize(trackedOrders,  0);

   ArrayResize(lfxOrders.iCache, 0);
   ArrayResize(lfxOrders.bCache, 0);
   ArrayResize(lfxOrders.dCache, 0);
   lfxOrders.pendingOrders    = 0;
   lfxOrders.openPositions    = 0;
   lfxOrders.pendingPositions = 0;

   // configuration
   if (AutoConfiguration) {
      string indicator = WindowExpertName();
      ShowPrice    = GetConfigBool(indicator, "ShowPrice", ShowPrice);
      ShowUnitSize = GetConfigBool(indicator, "ShowUnitSize", ShowUnitSize);
      TrackOrders  = GetConfigBool(indicator, "TrackOrders", TrackOrders);
   }

   // init labels, status and used trade account
   if (!RestoreStatus())        return(last_error);
   if (!CreateLabels())         return(last_error);
   if (!InitTradeAccount())     return(last_error);
   if (!UpdateAccountDisplay()) return(last_error);

   return(catch("onInit(2)"));
}


/**
 * Called after the indicator was manually loaded by the user. There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   RestoreLfxOrders(false);                              // read from file
   return(last_error);
}


/**
 * Called after the indicator was loaded by a chart template. Also at terminal start. Also in tester with both
 * VisualMode=On|Off if the indicator is loaded by template "Tester.tpl". There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   RestoreLfxOrders(false);                              // read from file
   return(last_error);
}


/**
 * Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   RestoreLfxOrders(true);                               // from cache
   return(last_error);
}


/**
 * Called after the chart timeframe has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTimeframeChange() {
   RestoreLfxOrders(true);                               // from cache
   return(last_error);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   if (!RestoreLfxOrders(true))  return(last_error);     // restore old orders from cache
   if (!SaveLfxOrderCache())     return(last_error);     // save old orders to file
   if (!RestoreLfxOrders(false)) return(last_error);     // read new orders from file
   return(NO_ERROR);
}


/**
 * Called after the indicator was recompiled. In older terminals (which ones exactly?) indicators are not automatically
 * reloded if the terminal is disconnected. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   if (mode.extern) {
      RestoreLfxOrders(false);                           // read from file
   }
   return(last_error);
}


/**
 * Initialization postprocessing.
 *
 * @return int - error status
 */
int afterInit() {
   // reset the command handler
   if (__isChart) {
      string sValues[];
      GetChartCommand("", sValues);
   }

   if (__isTesting) {
      positions.showAbsProfits = true;
   }
   else {
      // register an order event listener
      if (mode.intern && TrackOrders) {
         orderTracker.key = "rsf::order-tracker::"+ GetAccountNumber() +"::";
         string property = orderTracker.key + StrToLower(Symbol());
         int counter = Max(GetWindowPropertyA(hWndDesktop, property), 0) + 1;
         SetWindowPropertyA(hWndDesktop, property, counter);
      }

      // setup a chart ticker
      if (!__virtualTicksTimerId) {
         int hWnd = __ExecutionContext[EC.chart], milliseconds;

         if (StrStartsWithI(GetAccountServer(), "XTrade-")) {
            // offline ticker to update synthetic charts
            milliseconds = 1000;
            __virtualTicksTimerId = SetupTickTimer(hWnd, milliseconds, TICK_CHART_REFRESH|TICK_IF_WINDOW_VISIBLE);
            if (!__virtualTicksTimerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));

            // display ticker status
            string label = MqlProgramName() +".TickerStatus";
            if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(__ExecutionContext[EC.mqlError]);
            ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
            ObjectSet    (label, OBJPROP_XDISTANCE, 38);
            ObjectSet    (label, OBJPROP_YDISTANCE, 38);
            ObjectSetText(label, "n", 6, "Webdings", LimeGreen);     // a "dot" marker, Green = online
         }
         else {
            // virtual ticks to update chart infos/custom positions without waiting for the next tick
            milliseconds = 600;
            __virtualTicksTimerId = SetupTickTimer(hWnd, milliseconds, TICK_IF_WINDOW_VISIBLE);
            if (!__virtualTicksTimerId) return(catch("afterInit(2)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
         }
      }
   }
   return(catch("afterInit(3)"));
}
