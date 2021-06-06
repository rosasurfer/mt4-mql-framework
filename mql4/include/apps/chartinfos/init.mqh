/**
 * Initialization preprocessing
 *
 * @return int - error status
 */
int onInit() {
   if (!CreateLabels())         return(last_error);                           // label creation first; needed by RestoreRuntimeStatus()
   if (!RestoreRuntimeStatus()) return(last_error);                           // restores positions.absoluteProfits
   if (!InitTradeAccount())     return(last_error);                           // set used trade account
   if (!UpdateAccountDisplay()) return(last_error);

   // read config: displayed price
   string section="", key="", stdSymbol=StdSymbol(), sValue="bid";
   if (!IsVisualModeFix()) {                                                  // in tester is always bid displayed (sufficient and faster)
      section = "ChartInfos";
      key     = "DisplayedPrice."+ stdSymbol;
      sValue  = StrToLower(GetConfigString(section, key, "median"));
   }
   if      (sValue == "bid"   ) displayedPrice = PRICE_BID;
   else if (sValue == "ask"   ) displayedPrice = PRICE_ASK;
   else if (sValue == "median") displayedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (unknown)", ERR_INVALID_CONFIG_VALUE));

   if (mode.intern) {
      mm.risk         = 0;                                                    // default: unitsize calculation disabled
      mm.stopDistance = 0;

      // read config: unitsize calculation
      section = "PositionSize";
      string defaultRiskKey="Default.Risk", symbolRiskKey=stdSymbol +".Risk", symbolDistKey=stdSymbol +".StopDistance";
      string sDefaultRisk = GetConfigString(section, defaultRiskKey);
      string sSymbolRisk  = GetConfigString(section, symbolRiskKey);
      string sSymbolDist  = GetConfigString(section, symbolDistKey);

      if ((StringLen(sDefaultRisk) || StringLen(sSymbolRisk)) && StringLen(sSymbolDist)) {
         key    = ifString(StringLen(sSymbolRisk), symbolRiskKey, defaultRiskKey);
         sValue = ifString(StringLen(sSymbolRisk), sSymbolRisk,   sDefaultRisk);

         if (!StrIsNumeric(sValue)) return(catch("onInit(2)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (non-numeric value)", ERR_INVALID_CONFIG_VALUE));
         double dValue = StrToDouble(sValue);
         if (dValue <= 0)           return(catch("onInit(3)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (non-positive value)", ERR_INVALID_CONFIG_VALUE));
         mm.risk = dValue;

         key    = symbolDistKey;
         sValue = sSymbolDist;
         if (!StrIsNumeric(sValue)) return(catch("onInit(4)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (non-numeric value)", ERR_INVALID_CONFIG_VALUE));
         dValue = StrToDouble(sValue);
         if (dValue <= 0)           return(catch("onInit(5)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (non-positive value)", ERR_INVALID_CONFIG_VALUE));
         mm.stopDistance = dValue;
      }

      // order tracker
      if (!OrderTracker.Configure()) return(last_error);
   }

   if (IsTesting()) {
      positions.absoluteProfits = true;
   }
   return(catch("onInit(6)"));
}


/**
 * Nach manuellem Laden des Indikators durch den User (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitUser() {
   if (!RestoreLfxOrders(false)) return(last_error);                          // LFX-Orders neu einlesen
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators durch ein Template, auch bei Terminal-Start (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitTemplate() {
   if (!RestoreLfxOrders(false)) return(last_error);                          // LFX-Orders neu einlesen
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitParameters() {
   if (!RestoreLfxOrders(true)) return(last_error);                           // in Library gespeicherte LFX-Orders restaurieren
   return(NO_ERROR);
}


/**
 * Nach Wechsel der Chartperiode (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitTimeframeChange() {
   if (!RestoreLfxOrders(true)) return(last_error);                           // in Library gespeicherte LFX-Orders restaurieren
   return(NO_ERROR);
}


/**
 * Nach Änderung des Chartsymbols (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitSymbolChange() {
   if (!RestoreLfxOrders(true))  return(last_error);                          // LFX-Orderdaten des vorherigen Symbols speichern (liegen noch in Library)
   if (!SaveLfxOrderCache())     return(last_error);
   if (!RestoreLfxOrders(false)) return(last_error);                          // LFX-Orders des aktuellen Symbols einlesen
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   if (mode.extern) {
      if (!RestoreLfxOrders(false)) return(last_error);                       // LFX-Orders neu einlesen
   }
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   // ggf. Offline-Ticker installieren
   if (Offline.Ticker) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StrStartsWithI(GetAccountServer(), "XTrade-")) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 1000;
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH|TICK_IF_VISIBLE);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Status des Offline-Tickers im Chart anzeigen
      string label = ProgramName() +".TickerStatus";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings: runder Marker, grün="Online"
         RegisterObject(label);
      }
   }
   return(catch("afterInit(2)"));
}


/**
 * Konfiguriert den internen OrderTracker.
 *
 * @return bool - success status
 */
bool OrderTracker.Configure() {
   if (!mode.intern) return(true);
   track.orders = false;

   string sValue = StrToLower(Track.Orders), values[];            // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   if (sValue == "on") {
      track.orders = true;
   }
   else if (sValue == "off") {
      track.orders = false;
   }
   else if (sValue == "auto") {
      track.orders = GetConfigBool("EventTracker", "Track.Orders");
   }
   else return(!catch("OrderTracker.Configure(1)  Invalid input parameter Track.Orders = "+ DoubleQuoteStr(Track.Orders), ERR_INVALID_INPUT_PARAMETER));

   // Signal-Methoden einlesen
   if (track.orders) {
      if (!ConfigureSignalingBySound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!ConfigureSignalingByMail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalingBySMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
   }
   return(!catch("OrderTracker.Configure(2)"));
}
