
/**
 * Ermittelt ID und Status der im aktuellen Chart gemanagten Sequenzen.
 *
 * @param  string ids[]    - Array zur Aufnahme der gefundenen Sequenz-ID's
 * @param  int    status[] - Array zur Aufnahme der gefundenen Sequenz-Statuswerte
 *
 * @return bool - ob mindestens eine aktive Sequenz gefunden wurde
 */
bool FindChartSequences(string ids[], int status[]) {
   ArrayResize(ids,    0);
   ArrayResize(status, 0);

   string label = "SnowRoller.status";

   if (ObjectFind(label) == 0) {
      string values[], data[], strValue, text=StringToUpper(StringTrim(ObjectDescription(label)));
      int sizeOfValues = Explode(text, ",", values, NULL);

      for (int i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 2) return(_false(catch("FindChartSequences(1)   illegal chart label "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_RUNTIME_ERROR)));

         // Sequenz-ID
         strValue  = StringTrim(data[0]);
         bool test = false;
         if (StringLeft(strValue, 1) == "T") {
            test     = true;
            strValue = StringRight(strValue, -1);
         }
         if (!StringIsDigit(strValue))                 return(_false(catch("FindChartSequences(2)   illegal sequence id in chart label "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_RUNTIME_ERROR)));
         int iValue = StrToInteger(strValue);
         if (iValue == 0)
            continue;
         string strSequenceId = ifString(test, "T", "") + iValue;

         // Sequenz-Status
         strValue = StringTrim(data[1]);
         if (!StringIsDigit(strValue))                 return(_false(catch("FindChartSequences(3)   illegal sequence status in chart label "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_RUNTIME_ERROR)));
         iValue = StrToInteger(strValue);
         if (!IsValidSequenceStatus(iValue))           return(_false(catch("FindChartSequences(4)   invalid sequence status in chart label "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_RUNTIME_ERROR)));
         int sequenceStatus = iValue;

         ArrayPushString(ids,    strSequenceId );
         ArrayPushInt   (status, sequenceStatus);
         //debug("FindChartSequences()   "+ label +" = "+ strSequenceId +"|"+ sequenceStatus);
      }
   }
   return(ArraySize(ids));                                           // (bool) int
}


/**
 * Ob ein Wert einen Sequenzstatus-Code darstellt.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsSequenceStatus(int value) {
   switch (value) {
      case STATUS_UNINITIALIZED: return(true);
      case STATUS_WAITING      : return(true);
      case STATUS_STARTING     : return(true);
      case STATUS_PROGRESSING  : return(true);
      case STATUS_STOPPING     : return(true);
      case STATUS_STOPPED      : return(true);
   }
   return(false);
}


/**
 * Ob ein Wert einen gültigen Sequenzstatus-Code darstellt.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsValidSequenceStatus(int value) {
   switch (value) {
    //case STATUS_UNINITIALIZED: return(true);                       // ungültig
      case STATUS_WAITING      : return(true);
      case STATUS_STARTING     : return(true);
      case STATUS_PROGRESSING  : return(true);
      case STATUS_STOPPING     : return(true);
      case STATUS_STOPPED      : return(true);
   }
   return(false);
}


/**
 * Prüft auf MA-Trendwechsel
 *
 * @param  int    timeframe   - zu verwendender Timeframe
 * @param  string maPeriods   - Indikator-Parameter
 * @param  string maTimeframe - Indikator-Parameter
 * @param  string maMethod    - Indikator-Parameter
 * @param  int    lag         - Trigger-Verzögerung, größer/gleich 0
 * @param  int    directions  - Kombination von Trend-Flags:
 *                              MODE_UPTREND   - Wechsel zum Up-Trend wird signalisiert
 *                              MODE_DOWNTREND - Wechsel zum Down-Trend wird signalisiert
 * @param  int    lpSignal    - Zeiger auf Variable zur Signalaufnahme (+: Wechsel zum Up-Trend, -: Wechsel zum Down-Trend)
 *
 * @return bool - Erfolgsstatus (nicht, ob ein Signal aufgetreten ist)
 *
 *
 *  TODO: 1) refaktorieren und auslagern
 *        2) Die Funktion könnte den Indikator selbst berechnen und nur bei abweichender Periode auf iCustom() zurückgreifen.
 */
bool CheckTrendChange(int timeframe, string maPeriods, string maTimeframe, string maMethod, int lag, int directions, int &lpSignal) {
   if (lag < 0)
      return(_false(catch("CheckTrendChange(1)   illegal parameter lag = "+ lag, ERR_INVALID_FUNCTION_PARAMVALUE)));

   lpSignal = 0;
                                                                                 // +-----+------+
   int error, /*ICUSTOM*/ic[]; if (!ArraySize(ic)) InitializeICustom(ic, NULL);  // | lag | bars |
   ic[IC_LAST_ERROR] = NO_ERROR;                                                 // +-----+------+
                                                                                 // |  0  |   4  | Erkennung onBarOpen der neuen Bar (neuer Trend 1 Periode lang, frühester Zeitpunkt)
   int    barTrend, trend, counterTrend;                                         // |  1  |  12  | Erkennung onBarOpen der nächsten Bar (neuer Trend 2 Perioden lang)
   string strTrend, changePattern;                                               // |  2  |  20  | Erkennung onBarOpen der übernächsten Bar (neuer Trend 3 Perioden lang)
   int    bars   = 4 + 8*lag;                                                    // +-----+------+
   int    values = Max(bars+1, 20);                            // +1 wegen fehlendem Trend der ältesten Bar; 20 (größtes lag) zur Reduktion ansonsten ident. Indikator-Instanzen

   for (int bar=bars-1; bar>0; bar--) {                        // Bar 0 ist immer unvollständig und wird nicht benötigt
      // (1) Trend der einzelnen Bars ermitteln
      barTrend = iCustom(NULL, timeframe, "Moving Average",    // (int) double ohne Präzisionsfehler (siehe MA-Implementierung)
                         maPeriods,                            // MA.Periods
                         maTimeframe,                          // MA.Timeframe
                         maMethod,                             // MA.Method
                         "Close",                              // AppliedPrice
                         values,                               // Max.Values
                         ForestGreen,                          // Color.UpTrend
                         Red,                                  // Color.DownTrend
                         "",                                   // _________________
                         ic[IC_PTR],                           // __iCustom__
                         BUFFER_2, bar); //throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE

      error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERS_HISTORY_UPDATE)
         return(_false(catch("CheckTrendChange(2)", error)));
      if (IsError(ic[IC_LAST_ERROR]))
         return(_false(SetLastError(ic[IC_LAST_ERROR])));
      if (!barTrend)
         return(_false(catch("CheckTrendChange(3)->iCustom(Moving Average)   invalid trend for bar="+ bar +": "+ barTrend, ERR_CUSTOM_INDICATOR_ERROR)));


      // (2) Trendwechsel detektieren
      if (bar == bars-1) {
         trend = barTrend;                                     // Initialisierung
      }
      else if (barTrend == trend) {
         counterTrend = 0;
      }
      else {
         counterTrend++;
         if (counterTrend > lag) {
            if (bar > 1) {
               trend        = -Sign(trend);
               counterTrend = 0;
               continue;
            }
            // Trendwechsel in Bar 1 (nach Berücksichtigung von lag)
            if (trend < 0) {
               if (directions & MODE_UPTREND != 0) {
                  lpSignal = 1;
                  //debug("CheckTrendChange()   "+ TimeToStr(TimeCurrent()) +"   trend change up");
               }
            }
            else {
               if (directions & MODE_DOWNTREND != 0) {
                  lpSignal = -1;
                  //debug("CheckTrendChange()   "+ TimeToStr(TimeCurrent()) +"   trend change down");
               }
            }
         }
      }
   }

   if (error == ERS_HISTORY_UPDATE)
      debug("CheckTrendChange()   ERS_HISTORY_UPDATE");        // TODO: bei ERS_HISTORY_UPDATE die zur Berechnung verwendeten Bars prüfen

   return(!catch("CheckTrendChange(4)"));
}


/**
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenz-ID im Bereich 1000-16383 (mindestens 4-stellig, maximal 14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;                                                     // TODO: Im Tester müssen fortlaufende IDs generiert werden.
   while (id < SID_MIN || id > SID_MAX) {
      id = MathRand();
   }
   return(id);                                                 // TODO: ID auf Eindeutigkeit prüfen
}


/**
 * Holt eine Bestätigung für einen Trade-Request beim ersten Tick ein (um Programmfehlern vorzubeugen).
 *
 * @param  string location - Ort der Bestätigung
 * @param  string message  - Meldung
 *
 * @return bool - Ergebnis
 */
bool ConfirmTick1Trade(string location, string message) {
   static bool done, confirmed;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         ForceSound("notify.wav");
         confirmed = (IDOK == ForceMessageBox(__NAME__ + ifString(!StringLen(location), "", " - "+ location), ifString(!IsDemo(), "- Live Account -\n\n", "") + message, MB_ICONQUESTION|MB_OKCANCEL));
         if (Tick > 0)
            RefreshRates();                                          // bei Tick==0, also Aufruf in init(), ist RefreshRates() unnötig
      }
      done = true;
   }
   return(confirmed);
}


int lastEventId;


/**
 * Generiert eine neue Event-ID.
 *
 * @return int - ID (ein fortlaufender Zähler)
 */
int CreateEventId() {
   lastEventId++;
   return(lastEventId);
}


/**
 * Gibt die lesbare Konstante eines Status-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_UNINITIALIZED: return("STATUS_UNINITIALIZED");
      case STATUS_WAITING      : return("STATUS_WAITING"      );
      case STATUS_STARTING     : return("STATUS_STARTING"     );
      case STATUS_PROGRESSING  : return("STATUS_PROGRESSING"  );
      case STATUS_STOPPING     : return("STATUS_STOPPING"     );
      case STATUS_STOPPED      : return("STATUS_STOPPED"      );
   }
   return(_empty(catch("StatusToStr()   invalid parameter status = "+ status, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Ob der angegebene StopPrice erreicht wurde.
 *
 * @param  int    type  - Stop-Typ: OP_BUYSTOP|OP_SELLSTOP|OP_BUY|OP_SELL
 * @param  double price - StopPrice
 *
 * @return bool
 */
bool IsStopTriggered(int type, double price) {
   if (type == OP_BUYSTOP ) return(Ask >= price);                    // pending Buy-Stop
   if (type == OP_SELLSTOP) return(Bid <= price);                    // pending Sell-Stop

   if (type == OP_BUY     ) return(Bid <= price);                    // Long-StopLoss
   if (type == OP_SELL    ) return(Ask >= price);                    // Short-StopLoss

   return(_false(catch("IsStopTriggered()   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
}
