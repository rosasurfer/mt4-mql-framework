/**
 * Initialization preprocessing
 *
 * @return int - error status
 */
int onInit() {
   hWndTerminal = GetTerminalMainWindow();

   if (!CreateLabels())         return(last_error);                           // label creation first; needed by RestoreRuntimeStatus()
   if (!RestoreRuntimeStatus()) return(last_error);                           // restores positions.absoluteProfits
   if (!InitTradeAccount())     return(last_error);                           // set used trade account
   if (!UpdateAccountDisplay()) return(last_error);

   // read config: displayed price
   string section="", key="", stdSymbol=StdSymbol(), sValue="bid";
   if (!IsVisualModeFix()) {                                                  // in tester always display the Bid price (sufficient and faster)
      section = "ChartInfos";
      key     = "DisplayedPrice."+ stdSymbol;
      sValue  = StrToLower(GetConfigString(section, key, "median"));
   }
   if      (sValue == "bid"   ) displayedPrice = PRICE_BID;
   else if (sValue == "ask"   ) displayedPrice = PRICE_ASK;
   else if (sValue == "median") displayedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (unknown)", ERR_INVALID_CONFIG_VALUE));

   if (mode.intern) {
      // read config: unitsize calculation, see ChartInfos::CalculateUnitSize()
      if (!ReadUnitSizeConfigValue("Leverage",    sValue)) return(last_error); mm.cfgLeverage    = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskPercent", sValue)) return(last_error); mm.cfgRiskPercent = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskRange",   sValue)) return(last_error); mm.cfgRiskRange   = StrToDouble(sValue);

      mm.cfgRiskRangeIsADR = StrCompareI(sValue, "ADR");
      if (mm.cfgRiskRangeIsADR) mm.cfgRiskRange = iADR();

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
   orderTracker.enabled = false;

   string sValues[], sValue = StrToLower(Track.Orders);     // default: "on | off | auto*"
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);

   if (sValue == "on") {
      orderTracker.enabled = true;
   }
   else if (sValue == "off") {
      orderTracker.enabled = false;
   }
   else if (sValue == "auto") {
      orderTracker.enabled = GetConfigBool("EventTracker", "Track.Orders");
   }
   else return(!catch("OrderTracker.Configure(1)  invalid input parameter Track.Orders: "+ DoubleQuoteStr(Track.Orders), ERR_INVALID_INPUT_PARAMETER));

   if (orderTracker.enabled) {
      // read signaling method configuration
      if (!ConfigureSignalsBySound(Signal.Sound, signal.sound                                         )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail,  signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,   signal.sms,                      signal.sms.receiver )) return(last_error);

      // register the indicator as order event listener
      string name = "rsf::order-tracker::"+ StrToLower(Symbol());
      int counter = Max(GetWindowIntegerA(hWndTerminal, name), 0) + 1;
      SetWindowIntegerA(hWndTerminal, name, counter);
   }
   return(!catch("OrderTracker.Configure(2)"));
}


/**
 * Find the applicable configuration for the [UnitSize] calculation and return the configured value.
 *
 * @param _In_  string id     - unitsize configuration identifier
 * @param _Out_ string &value - configuration value
 *
 * @return bool - success status
 */
bool ReadUnitSizeConfigValue(string id, string &value) {
   string section="Unitsize", sValue="";
   value = "";

   string key = Symbol() +"."+ id;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   key = StdSymbol() +"."+ id;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   key = "Default."+ id;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   return(true);     // success also if no configuration was found (returns an empty string)
}


/**
 * Validate the specified [UnitSize] configuration key and return the configured value.
 *
 * @param _In_  string section - configuration section
 * @param _In_  string key     - configuration key
 * @param _Out_ string &value  - configured value
 *
 * @return bool - success status
 */
bool ValidateUnitSizeConfigValue(string section, string key, string &value) {
   string sValue = GetConfigString(section, key), sValueBak = sValue;

   if (StrEndsWithI(key, ".RiskPercent") || StrEndsWithI(key, ".Leverage")) {
      if (!StrIsNumeric(sValue))    return(!catch("GetUnitSizeConfigValue(1)  invalid configuration value ["+ section +"]->"+ key +": "+ DoubleQuoteStr(sValueBak) +" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
      double dValue = StrToDouble(sValue);
      if (dValue < 0)               return(!catch("GetUnitSizeConfigValue(2)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
      value = sValue;
      return(true);
   }

   if (StrEndsWithI(key, ".RiskRange")) {
      if (StrCompareI(sValue, "ADR")) {
         value = sValue;
         return(true);
      }
      if (!StrEndsWith(sValue, "pip")) {
         if (!StrIsNumeric(sValue)) return(!catch("GetUnitSizeConfigValue(3)  invalid configuration value ["+ section +"]->"+ key +": "+ DoubleQuoteStr(sValueBak) +" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
         dValue = StrToDouble(sValue);
         if (dValue < 0)            return(!catch("GetUnitSizeConfigValue(4)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
         value = sValue;
         return(true);
      }
      sValue = StrTrim(StrLeft(sValue, -3));
      if (!StrIsNumeric(sValue))    return(!catch("GetUnitSizeConfigValue(5)  invalid configuration value ["+ section +"]->"+ key +": "+ DoubleQuoteStr(sValueBak) +" (non-numeric pip value)", ERR_INVALID_CONFIG_VALUE));
      dValue = StrToDouble(sValue);
      if (dValue < 0)               return(!catch("GetUnitSizeConfigValue(6)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
      value = dValue * Pip;
      return(true);
   }

   return(!catch("GetUnitSizeConfigValue(7)  unsupported [UnitSize] config key: "+ DoubleQuoteStr(key), ERR_INVALID_PARAMETER));
}
