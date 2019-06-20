
/**
 * Neu geladener EA. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitUser() {
   ValidateConfig(true);                                      // interactive = true
   return(last_error);
}


/**
 * EA durch Template geladen. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInitTemplate() {
   // im Chart gespeicherte Daten restaurieren
   if (RestoreRuntimeStatus())
      ValidateConfig(false);                                  // interactive = false

   ResetRuntimeStatus();
   return(last_error);
}


/**
 * Nach Parameteränderung. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitParameters() {
   StoreConfiguration();

   if (!ValidateConfig(true))                                 // interactive = true
      RestoreConfiguration();

   return(last_error);
}


/**
 * Nach Timeframe-Wechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitTimeframeChange() {
   // nicht-statische Input-Parameter restaurieren
   GridSize        = last.GridSize;
   LotSize         = last.LotSize;
   StartConditions = last.StartConditions;
   return(NO_ERROR);
}


/**
 * Nach Symbolwechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitSymbolChange() {
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Nach Recompilation. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   return(onInitTemplate());                                         // Funktionalität entspricht onInitTemplate()
}


/**
 * Postprocessing-Hook nach Initialisierung
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   CreateStatusBox();
   return(last_error);
}


/**
 * Die Statusbox besteht aus untereinander angeordneten Quadraten (Font "Webdings", Zeichen 'g').
 *
 * @return int - Fehlerstatus
 */
int CreateStatusBox() {
   if (!__CHART()) return(false);

   int x=0, y[]={33, 66}, fontSize=115, rectangles=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // entspricht Chart-Background
   string label;

   for (int i=0; i < rectangles; i++) {
      label = StringConcatenate(__NAME(), ".statusbox."+ (i+1));
      if (ObjectFind(label) != 0) {
         if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
            return(!catch("CreateStatusBox(1)"));
         ObjectRegister(label);
      }
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x   );
      ObjectSet    (label, OBJPROP_YDISTANCE, y[i]);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(!catch("CreateStatusBox(2)"));
}
