/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Textlabel zuerst erzeugen, RestoreWindowStatus() benötigt sie bereits
   if (!CreateLabels())
      return(last_error);


   // (2) Status restaurieren
   mode.intern     = true;                                           // Default-Status
   mode.extern     = false;
   mode.remote     = false;
   isLfxInstrument = false;

   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   if (StringLen(lfxCurrency) > 0) {
      lfxCurrencyId     = GetCurrencyId(lfxCurrency);
      lfxChartDeviation = GetGlobalConfigDouble("Charts", "LFXDeviation."+ lfxCurrency, 0);
      isLfxInstrument   = true;
      mode.remote       = true;                                      // TODO: LFX/mode.remote muß in Abhängigkeit einer Konfiguration gesetzt werden
      /*
      if (!lfxAccount) if (!LFX.InitAccountData())
         return(last_error);
      string name = lfxAccountName +": "+ lfxAccountCompany +", "+ lfxAccount +", "+ lfxAccountCurrency;
      ObjectSetText(label.lfxTradeAccount, name, 8, "Arial Fett", ifInt(lfxAccountType==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
      */
   }
   else if (!RestoreWindowStatus()) {                                // restauriert mode.intern/extern
      return(last_error);
   }


   // (3) Konfiguration einlesen und validieren
   // AppliedPrice
   string section="", key="", stdSymbol=StdSymbol();
   string price = "bid";
   if (!IsVisualModeFix()) {                                         // im Tester wird immer das Bid angezeigt (ist ausreichend und schneller)
      section = "Charts";
      key     = "AppliedPrice."+ stdSymbol;
      price   = StringToLower(GetGlobalConfigString(section, key, "median"));
   }
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)  invalid configuration value ["+ section +"]->"+ key +" = \""+ price +"\" (unknown)", ERR_INVALID_CONFIG_PARAMVALUE));

   // Moneymanagement
   if (!isLfxInstrument) {
      // Leverage: eine symbol-spezifische hat Vorrang vor einer allgemeinen Konfiguration
      section="Moneymanagement"; key=stdSymbol +".Leverage";
      string sValue = GetLocalConfigString(section, key, "");
      if (StringLen(sValue) > 0) {
         if (!StringIsNumeric(sValue)) return(catch("onInit(2)  invalid configuration value ["+ section +"]->"+ key +" = \""+ sValue +"\" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
         double dValue = StrToDouble(sValue);
         if (dValue < 0.1)             return(catch("onInit(3)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too low)", ERR_INVALID_CONFIG_PARAMVALUE));
         mm.customLeverage   = dValue;
         mm.isCustomUnitSize = true;
      }
      else {
         // Standard-Konfiguration: der Hebel wird aus der Standard-Volatilität berechnet
         mm.isCustomUnitSize = false;
      }

      // Volatilität
      if (!mm.isCustomUnitSize) {
         key    = "Volatility";
         sValue = GetLocalConfigString(section, key, DoubleToStr(STANDARD_VOLATILITY, 2));
         if (!StringIsNumeric(sValue)) return(catch("onInit(4)  invalid configuration value ["+ section +"]->"+ key +" = \""+ sValue +"\" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
         dValue = StrToDouble(sValue);
         if (dValue <= 0)              return(catch("onInit(5)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too low)", ERR_INVALID_CONFIG_PARAMVALUE));
         mm.stdVola = dValue;
      }
   }

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(6)"));
}


/**
 * Nach manuellem Laden des Indikators durch den User (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_User() {
   if (isLfxInstrument) {
      // LFX-Status einlesen
      if (!RestoreLfxStatusFromFile())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Template() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFile())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Parameters() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Wechsel der aktuellen Chartperiode (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_TimeframeChange() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_SymbolChange() {
   if (isLfxInstrument) {
      // LFX-Status des alten Symbols speichern (liegt noch in Library)
      if (!RestoreLfxStatusFromLib())  return(last_error);
      if (!SaveVolatileLfxStatus())    return(last_error);

      // LFX-Status des neuen Symbols einlesen
      if (!RestoreLfxStatusFromFile()) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Recompile() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFile())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   // ggf. OfflineTicker installieren
   if (Offline.Ticker && !This.IsTesting() && GetServerName()=="MyFX-Synthetic") {
      int hWnd    = WindowHandleEx(NULL); if (!hWnd) return(last_error);
      int millis  = 1000;
      int timerId = SetupTickTimer(hWnd, millis, TICK_OFFLINE_REFRESH);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Chart-Markierung anzeigen
      string label = __NAME__+".Status";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings: runder "Online"-Marker
         ObjectRegister(label);
      }
   }
   return(catch("afterInit(2)"));
}
