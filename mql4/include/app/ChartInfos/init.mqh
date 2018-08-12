/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Textlabel zuerst erzeugen, RestoreRuntimeStatus() benötigt sie bereits
   if (!CreateLabels())
      return(last_error);


   // (2) Laufzeitstatus restaurieren
   if (!RestoreRuntimeStatus())                                               // restauriert positions.absoluteProfits, mode.extern.notrading
      return(last_error);


   // (3) TradeAccount initialisieren                                         // bei "mode.extern" schon in RestoreRuntimeStatus() geschehen
   if (!mode.extern.notrading) /*&&*/ if (!InitTradeAccount())     return(last_error);
   if (!mode.intern.trading)   /*&&*/ if (!UpdateAccountDisplay()) return(last_error);


   // (4) Config-Parameter validieren
   // DisplayedPrice
   string section="", key="", stdSymbol=StdSymbol(), sValue="bid";
   if (!IsVisualModeFix()) {                                                  // im Tester wird immer das Bid angezeigt (ist ausreichend und schneller)
      section = "Chart";
      key     = "DisplayedPrice."+ stdSymbol;
      sValue  = StringToLower(GetConfigString(section, key, "median"));
   }
   if      (sValue == "bid"   ) displayedPrice = PRICE_BID;
   else if (sValue == "ask"   ) displayedPrice = PRICE_ASK;
   else if (sValue == "median") displayedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (unknown)", ERR_INVALID_CONFIG_PARAMVALUE));

   // Moneymanagement
   if (!mode.remote.trading) {
      // Leverage: eine symbol-spezifische hat Vorrang vor einer allgemeinen Konfiguration
      section = "Moneymanagement";
      key     = stdSymbol +".Leverage";
      sValue  = GetConfigString(section, key);
      if (StringLen(sValue) > 0) {
         if (!StringIsNumeric(sValue)) return(catch("onInit(2)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
         double dValue = StrToDouble(sValue);
         if (dValue < 0.1)             return(catch("onInit(3)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (minimum 0.1)", ERR_INVALID_CONFIG_PARAMVALUE));
         mm.customLeverage = dValue;
         mm.isCustom       = true;
      }
      else {
         // Standard-Konfiguration: der Hebel wird aus der Standard-Volatilität berechnet
         mm.isCustom = false;
      }

      // Volatilität
      if (!mm.isCustom) {
         key    = "Volatility";
         sValue = GetConfigString(section, key, DoubleToStr(MM.STD_VOLATILITY, 2));
         if (!StringIsNumeric(sValue)) return(catch("onInit(4)  invalid configuration value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue) +" (not numeric)", ERR_INVALID_CONFIG_PARAMVALUE));
         dValue = StrToDouble(sValue);
         if (dValue <= 0)              return(catch("onInit(5)  invalid configuration value ["+ section +"]->"+ key +" = "+ sValue +" (not positive)", ERR_INVALID_CONFIG_PARAMVALUE));
         mm.stdVola = dValue;
      }
   }


   // (5) nur bei bei "mode.intern": OrderTracker-Konfiguration validieren
   if (mode.intern.trading) {
      if (!OrderTracker.Configure()) return(last_error);
   }


   SetIndexLabel(0, NULL);                                                    // Datenanzeige ausschalten
   return(catch("onInit(6)"));
}


/**
 * Nach manuellem Laden des Indikators durch den User (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_User() {
   if (!mode.extern.notrading) {
      if (!RestoreLfxOrders(false)) return(last_error);                       // LFX-Orders neu einlesen
   }
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators durch ein Template, auch bei Terminal-Start (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Template() {
   if (!mode.extern.notrading) {
      if (!RestoreLfxOrders(false)) return(last_error);                       // LFX-Orders neu einlesen
   }
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Parameters() {
   if (!mode.extern.notrading) {
      if (!RestoreLfxOrders(true)) return(last_error);                        // in Library gespeicherte LFX-Orders restaurieren
   }
   return(NO_ERROR);
}


/**
 * Nach Wechsel der Chartperiode (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_TimeframeChange() {
   if (!mode.extern.notrading) {
      if (!RestoreLfxOrders(true)) return(last_error);                        // in Library gespeicherte LFX-Orders restaurieren
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung des Chartsymbols (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_SymbolChange() {
   if (!mode.extern.notrading) {
      if (!RestoreLfxOrders(true))  return(last_error);                       // LFX-Orderdaten des vorherigen Symbols speichern (liegen noch in Library)
      if (!SaveLfxOrderCache())     return(last_error);
      if (!RestoreLfxOrders(false)) return(last_error);                       // LFX-Orders des aktuellen Symbols einlesen
   }
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Recompile() {
   if (mode.remote.trading) {
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
   if (Offline.Ticker) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StringCompareI(GetServerName(), "XTrade-Synthetic")) {
      int hWnd    = ec_hChart(__ExecutionContext);
      int millis  = 1000;
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH|TICK_IF_VISIBLE);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Status des Offline-Tickers im Chart anzeigen
      string label = __NAME__+".TickerStatus";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings: runder Marker, grün="Online"
         ObjectRegister(label);
      }
   }
   return(catch("afterInit(2)"));
}


/**
 * Konfiguriert den internen OrderTracker.
 *
 * @return bool - Erfolgsstatus
 */
bool OrderTracker.Configure() {
   // (1) Track.Orders: "on | off | account*"
   track.orders = false;
   string sValue = StringToLower(StringTrim(Track.Orders));
   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      track.orders = true;
   }
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false" || sValue=="") {
      track.orders = false;
   }
   else if (sValue=="account" || sValue=="on | off | account*") {
      string accountConfig = GetAccountConfigPath(tradeAccount.company, tradeAccount.number);
      string section       = "EventTracker";
      string key           = "Track.Orders";
      track.orders = GetIniBool(accountConfig, section, key);
   }
   else return(!catch("OrderTracker.Configure(1)  Invalid input parameter Track.Orders = "+ DoubleQuoteStr(Track.Orders), ERR_INVALID_INPUT_PARAMETER));


   // (2) Signal-Methoden einlesen
   if (track.orders) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
   }
   return(!catch("OrderTracker.Configure(2)"));
}
