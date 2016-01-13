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
   if (!RestoreRuntimeStatus())                                      // restauriert mode.extern
      return(last_error);


   // (3) TradeAccount initialisieren
   if (!mode.extern) /*&&*/ if (!InitTradeAccount())     return(last_error);
   if (!mode.intern) /*&&*/ if (!UpdateAccountDisplay()) return(last_error);


   // (4) Input-Parameter validieren
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
   if (!mode.remote) {
      // Leverage: eine symbol-spezifische hat Vorrang vor einer allgemeinen Konfiguration
      section="Moneymanagement"; key=stdSymbol +".Leverage";
      string sValue = GetLocalConfigString(section, key);
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
   if (mode.remote) {
      // RemoteOrder-Daten einlesen
      if (!RestoreRemoteOrders(false)) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators durch ein Template, auch bei Terminal-Start (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Template() {
   if (mode.remote) {
      // RemoteOrder-Daten neu einlesen
      if (!RestoreRemoteOrders(false)) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter (Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Parameters() {
   if (mode.remote) {
      // in Library gespeicherte RemoteOrder-Daten restaurieren
      bool fromCache = true;
      if (!RestoreRemoteOrders(fromCache)) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Wechsel der Chartperiode (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_TimeframeChange() {
   if (mode.remote) {
      // in Library gespeicherte RemoteOrder-Daten restaurieren
      bool fromCache = true;
      if (!RestoreRemoteOrders(fromCache)) return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Nach Änderung des Chartsymbols (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_SymbolChange() {
   if (mode.remote) {
      // RemoteOrder-Daten des alten Symbols speichern (liegen noch in Library)
      bool fromCache = true;
      if (!RestoreRemoteOrders(fromCache)) return(last_error);
      if (!SaveRemoteOrderCache())         return(last_error);

      // RemoteOrder-Daten des neuen Symbols einlesen
      if (!RestoreRemoteOrders(false))     return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung (kein Input-Dialog).
 *
 * @return int - Fehlerstatus
 */
int onInit_Recompile() {
   if (mode.remote) {
      // RemoteOrder-Daten neu einlesen
      if (!RestoreRemoteOrders(false)) return(last_error);
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
