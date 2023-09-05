/**
 * Initialization preprocessing.
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // UnitSize.Corner: "top-left | top-right | bottom-left | bottom-right*" and  "tl | tr | bl | br"
   string sValues[], sValue = UnitSize.Corner;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue=="top-left"     || sValue=="tl") unitSize.corner = CORNER_TOP_LEFT;
   else if (sValue=="top-right"    || sValue=="tr") unitSize.corner = CORNER_TOP_RIGHT;
   else if (sValue=="bottom-left"  || sValue=="bl") unitSize.corner = CORNER_BOTTOM_LEFT;
   else if (sValue=="bottom-right" || sValue=="br") unitSize.corner = CORNER_BOTTOM_RIGHT;
   else return(catch("onInit(1)  invalid input parameter UnitSize.Corner: "+ UnitSize.Corner, ERR_INVALID_INPUT_PARAMETER));
   totalPosition.corner = unitSize.corner;
   UnitSize.Corner      = cornerDescriptions[unitSize.corner];

   // init labels, status and used trade account
   if (!CreateLabels())         return(last_error);
   if (!RestoreStatus())        return(last_error);
   if (!InitTradeAccount())     return(last_error);
   if (!UpdateAccountDisplay()) return(last_error);

   // resolve the price type to display
   string section = "ChartInfos";
   string key     = "DisplayedPrice."+ StdSymbol();
   sValue  = StrToLower(GetConfigString(section, key, "Bid"));    // default: Bid
   if      (sValue == "bid"   ) displayedPrice = PRICE_BID;
   else if (sValue == "ask"   ) displayedPrice = PRICE_ASK;
   else if (sValue == "median") displayedPrice = PRICE_MEDIAN;
   else return(catch("onInit(2)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (unknown)", ERR_INVALID_CONFIG_VALUE));

   if (mode.intern) {
      // resolve unitsize configuration
      if (!ReadUnitSizeConfigValue("Leverage",    sValue)) return(last_error); mm.cfgLeverage    = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskPercent", sValue)) return(last_error); mm.cfgRiskPercent = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskRange",   sValue)) return(last_error); mm.cfgRiskRange   = StrToDouble(sValue);
      mm.cfgRiskRangeIsADR = StrCompareI(sValue, "ADR");

      // order tracker
      if (!OrderTracker.Configure()) return(last_error);
   }
   return(catch("onInit(3)"));
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
   if (__isTesting) {
      positions.absoluteProfits = true;
   }
   else {
      // setup a chart ticker
      int hWnd = __ExecutionContext[EC.hChart];
      int millis = 1000;                                          // once every second

      if (StrStartsWithI(GetAccountServer(), "XTrade-")) {
         // offline ticker to update chart data in synthetic charts
         __tickTimerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH|TICK_IF_WINDOW_VISIBLE);
         if (!__tickTimerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));

         // display ticker status
         string label = ProgramName() +".TickerStatus";
         if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(__ExecutionContext[EC.mqlError]);
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);     // a "dot" marker, Green = online
      }
      else {
         // virtual ticks to update chart infos on a slow data feed
         __tickTimerId = SetupTickTimer(hWnd, millis, TICK_IF_WINDOW_VISIBLE);
         if (!__tickTimerId) return(catch("afterInit(2)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      }
   }
   //debug("afterInit(0.1)  IsConnected="+ IsConnected() +"  wndTitle="+ GetInternalWindowTextA(__ExecutionContext[EC.hChartWindow]));
   return(catch("afterInit(3)"));
}


/**
 * Konfiguriert den internen OrderTracker.
 *
 * @return bool - success status
 */
bool OrderTracker.Configure() {
   if (!mode.intern) return(true);
   orderTracker.enabled = false;

   string sValues[], sValue = StrToLower(Track.Orders);           // default: "on | off | auto*"
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
      orderTracker.enabled = GetConfigBool("ChartInfos", "Track.Orders");
   }
   else return(!catch("OrderTracker.Configure(1)  invalid input parameter Track.Orders: "+ DoubleQuoteStr(Track.Orders), ERR_INVALID_INPUT_PARAMETER));

   if (orderTracker.enabled) {
      // read signaling method configuration
      if (!ConfigureSignalsBySound(Signal.Sound, signal.sound                                         )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail,  signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,   signal.sms,                      signal.sms.receiver )) return(last_error);

      // register the indicator as order event listener
      if (!__isTesting) {
         hWndDesktop = GetDesktopWindow();
         orderTracker.key = "rsf::order-tracker::"+ GetAccountNumber() +"::";
         string name = orderTracker.key + StrToLower(Symbol());
         int counter = Max(GetPropA(hWndDesktop, name), 0) + 1;
         SetPropA(hWndDesktop, name, counter);
      }
   }
   return(!catch("OrderTracker.Configure(2)"));
}


/**
 * Find the applicable configuration for the [UnitSize] calculation and return the configured value.
 *
 * @param _In_  string name   - unitsize configuration identifier
 * @param _Out_ string &value - configuration value
 *
 * @return bool - success status
 */
bool ReadUnitSizeConfigValue(string name, string &value) {
   string section="Unitsize", sValue="";
   value = "";

   string key = Symbol() +"."+ name;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   key = StdSymbol() +"."+ name;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   key = "Default."+ name;
   if (IsConfigKey(section, key)) {
      if (!ValidateUnitSizeConfigValue(section, key, sValue)) return(false);
      value = sValue;
      return(true);
   }

   return(true);           // success also if no configuration was found (returns an empty string)
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
