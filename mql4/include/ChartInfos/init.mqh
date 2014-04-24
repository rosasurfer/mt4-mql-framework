/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration für Preisanzeige auswerten
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer PRICE_BID verwendet (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Prüfen, ob wir auf einem LFX-Chart laufen und ggf. LFX-Account-Details initialisieren
   isLfxChart = (StringLeft(Symbol(), 3)=="LFX" || StringRight(Symbol(), 3)=="LFX");
   if (isLfxChart) /*&&*/ if (!LFX.CheckAccount())
      return(last_error);

   // Label erzeugen
   CreateLabels();
   return(catch("onInit(2)"));
}


/**
 * außerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   if (isLfxChart) {
      // (1) LFX: offene Remote-Tickets einlesen
      if (Symbol()=="AUDLFX") {
         debug("onInitParameterChange()   read open LFX tickets");

         /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
         LFX.ReadOpenOrders(los);
         //LFX_ORDER.toStr(los, true);
         ArrayResize(los, 0);
      }

      // (2) LFX: in Library gespeicherte Remote-Ticketdaten restaurieren (können aktueller als (1) sein)
      int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 * innerhalb iCustom(): ?
 *
 * @return int - Fehlerstatus
 */
int onInitChartChange() {
   // bei Symbolwechsel
   // ???

   // bei Timeframe-Wechsel
   if (isLfxChart) {
      // LFX: entweder komplette offene Tickets in Library zwischenspeichern oder offene Tickets neu einlesen

      // LFX: in Library gespeicherte Remote-Ticketdaten restaurieren
      int error = ChartInfos.CopyRemotePositions(false, remote.position.tickets, remote.position.types, remote.position.data);
      if (IsError(error))
         return(SetLastError(error));
   }
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * außerhalb iCustom(): wenn Indikator im Template (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * innerhalb iCustom(): in allen init()-Fällen, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   if (isLfxChart) {
      // LFX: alle offenen Remote-Tickets einlesen
      if (Symbol()=="AUDLFX") {
         debug("onInitUndefined()   read open LFX tickets");

         /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
         LFX.ReadOpenOrders(los);
         //LFX_ORDER.toStr(los, true);
         ArrayResize(los, 0);
      }
   }
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ???
 * innerhalb iCustom(): im Tester nach Test-Restart bei VisualMode=Off, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Recompilation, vorhandener Indikator, kein Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   if (isLfxChart) {
      // LFX: alle offenen Remote-Tickets einlesen
      if (Symbol()=="AUDLFX") {
         debug("onInitRecompile()   read open LFX tickets");

         /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
         LFX.ReadOpenOrders(los);
         //LFX_ORDER.toStr(los, true);
         ArrayResize(los, 0);
      }
   }
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing
 *
 * @return int - Fehlerstatus
 *
int afterInit() {
   return(NO_ERROR);
}
*/
