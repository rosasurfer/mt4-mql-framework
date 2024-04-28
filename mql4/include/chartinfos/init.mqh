/**
 * Initialization preprocessing.
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // UnitSize.Corner: "top | bottom*" (may be shortened)
   string sValues[], sValue = UnitSize.Corner;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("top",    sValue)) unitSize.corner = CORNER_TOP_RIGHT;
   else if (StrStartsWith("bottom", sValue)) unitSize.corner = CORNER_BOTTOM_RIGHT;
   else return(catch("onInit(1)  invalid input parameter UnitSize.Corner: "+ UnitSize.Corner, ERR_INVALID_INPUT_PARAMETER));
   totalPosition.corner = unitSize.corner;
   UnitSize.Corner      = ifString(unitSize.corner==CORNER_TOP_RIGHT, "top", "bottom");
   // Track.Orders
   if (AutoConfiguration) Track.Orders = GetConfigBool(indicator, "Track.Orders", Track.Orders);

   // init labels, status and used trade account
   if (!CreateLabels())         return(last_error);
   if (!RestoreStatus())        return(last_error);
   if (!InitTradeAccount())     return(last_error);
   if (!UpdateAccountDisplay()) return(last_error);

   if (mode.intern) {
      // resolve unitsize configuration, after InitTradeAccount()
      if (!ReadUnitSizeConfigValue("Leverage",    sValue)) return(last_error); mm.cfgLeverage    = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskPercent", sValue)) return(last_error); mm.cfgRiskPercent = StrToDouble(sValue);
      if (!ReadUnitSizeConfigValue("RiskRange",   sValue)) return(last_error); mm.cfgRiskRange   = StrToDouble(sValue);
      mm.cfgRiskRangeIsADR = StrCompareI(sValue, "ADR");
   }
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
      if (mode.intern && Track.Orders) {
         hWndDesktop = GetDesktopWindow();
         orderTracker.key = "rsf::order-tracker::"+ GetAccountNumber() +"::";
         string name = orderTracker.key + StrToLower(Symbol());
         int counter = Max(GetPropA(hWndDesktop, name), 0) + 1;
         SetPropA(hWndDesktop, name, counter);
      }

      // setup a chart ticker
      int hWnd = __ExecutionContext[EC.hChart];
      int millis = 2000;                                          // once every 2 seconds

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
   return(catch("afterInit(3)"));
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
      if (!StrIsNumeric(sValue))    return(!catch("GetUnitSizeConfigValue(1)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
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
         if (!StrIsNumeric(sValue)) return(!catch("GetUnitSizeConfigValue(3)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
         dValue = StrToDouble(sValue);
         if (dValue < 0)            return(!catch("GetUnitSizeConfigValue(4)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
         value = sValue;
         return(true);
      }
      sValue = StrTrim(StrLeft(sValue, -3));
      if (!StrIsNumeric(sValue))    return(!catch("GetUnitSizeConfigValue(5)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric pip value)", ERR_INVALID_CONFIG_VALUE));
      dValue = StrToDouble(sValue);
      if (dValue < 0)               return(!catch("GetUnitSizeConfigValue(6)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
      value = dValue * Pip;
      return(true);
   }

   return(!catch("GetUnitSizeConfigValue(7)  unsupported [UnitSize] config key: \""+ key +"\"", ERR_INVALID_PARAMETER));
}
