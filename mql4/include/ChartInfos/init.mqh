/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parametervalidierung
   // (1.1) Tracking- bzw. Anzeigemodus: interne | externe | Remote-Positionen
   isLfxInstrument = false;
   mode.intern     = false;
   mode.extern     = false;
   mode.remote     = false;
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   if (StringLen(lfxCurrency) > 0) {
      lfxCurrencyId     = GetCurrencyId(lfxCurrency);
      lfxChartDeviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);
      isLfxInstrument   = true;
      mode.remote       = true;                                      // TODO: LFX/mode.remote muß in Abhängigkeit einer Konfiguration gesetzt werden
   }

   // (1.2) Preisanzeige
   string section="", key="", stdSymbol=StdSymbol();
   string price = "bid";
   if (!IsVisualMode()) {                                            // im Tester wird immer das Bid angezeigt (ist ausreichend und schneller)
      section="AppliedPrice"; key=stdSymbol;
      price = StringToLower(GetGlobalConfigString(section, key, "median"));
   }
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(2)   invalid configuration value ["+ section +"]->"+ key +" = \""+ price +"\" (unknown)", ERR_INVALID_CONFIG_PARAMVALUE));

   // (1.3) Moneymanagement
   if (!isLfxInstrument) {
      // Leverage: eine symbol-spezifische hat Vorrang vor einer allgemeinen Konfiguration
      section="Moneymanagement"; key=stdSymbol +".Leverage";
      string sValue = GetConfigString(section, key, "");
      if (StringLen(sValue) > 0) {
         if (!StringIsNumeric(sValue)) return(catch("onInit(3)   invalid configuration value ["+ section +"]->"+ key +" = \""+ sValue +"\" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
         double dValue = StrToDouble(sValue);
         if (dValue < 0.1)             return(catch("onInit(4)   invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too low)", ERR_INVALID_CONFIG_PARAMVALUE));
         mm.customLeverage    = dValue;
         mm.isDefaultLeverage = false;
      }
      else {
         // allgemeine Konfiguration: der Hebel ergibt sich aus dem konfigurierten oder dem Default-Risiko
         mm.isDefaultLeverage = true;
      }

      // Risk
      key    = "DefaultRisk";
      sValue = GetConfigString(section, key, DoubleToStr(DEFAULT_RISK, 2));
      if (!StringIsNumeric(sValue))    return(catch("onInit(5)   invalid configuration value ["+ section +"]->"+ key +" = \""+ sValue +"\" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (dValue <= 0)                 return(catch("onInit(6)   invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too low)", ERR_INVALID_CONFIG_PARAMVALUE));
      mm.stdRisk = dValue;

      // StopLoss
      key    = "DefaultStopLoss";
      sValue = GetConfigString(section, key, DoubleToStr(DEFAULT_STOPLOSS, 2));
      if (!StringIsNumeric(sValue))    return(catch("onInit(7)   invalid configuration value ["+ section +"]->"+ key +" = \""+ sValue +"\" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (dValue <=   0)               return(catch("onInit(8)   invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too low)", ERR_INVALID_CONFIG_PARAMVALUE));
      if (dValue >= 100)               return(catch("onInit(9)   invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (too high)", ERR_INVALID_CONFIG_PARAMVALUE));
      mm.stoploss = dValue;

      // Notice: nur lokale Konfiguration
      key = stdSymbol +".Notice";
      mm.notice = GetLocalConfigString(section, key, "");
   }


   // (2) in allen init()-Szenarios im Fenster gespeicherten Status restaurieren
   if (!RestoreWindowStatus())
      return(last_error);


   // (3) Textlabel erzeugen
   CreateLabels();

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(10)"));
}


/**
 * Nach manuellem Laden des Indikators durch den User, mit Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.User() {
   if (isLfxInstrument) {
      // LFX-Status einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start, kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.Template() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter, mit Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.Parameters() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Wechsel der aktuellen Chartperiode, kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.TimeframeChange() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status restaurieren
      if (!RestoreLfxStatusFromLib())
         return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols, kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.SymbolChange() {
   if (isLfxInstrument) {
      // in Library gespeicherten LFX-Status des alten Symbols restaurieren und speichern
      if (!RestoreLfxStatusFromLib())   return(last_error);
      if (!SaveVolatileLfxStatus())     return(last_error);

      // LFX-Status des aktuellen Symbols einlesen
      if (!RestoreLfxStatusFromFiles()) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInit.Recompile() {
   if (isLfxInstrument) {
      // LFX-Status neu einlesen
      if (!RestoreLfxStatusFromFiles())
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
   return(catch("afterInit(1)"));
}
