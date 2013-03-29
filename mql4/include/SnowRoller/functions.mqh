
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
 * @param  int    smoothing   - Trend-Smoothing in Bars, größer/gleich 0
 * @param  int    directions  - Kombination von Trend-Flags:
 *                              MODE_UPTREND   - Wechsel zum Up-Trend wird signalisiert
 *                              MODE_DOWNTREND - Wechsel zum Down-Trend wird signalisiert
 * @param  int    lpSignal    - Zeiger auf Variable zur Signalaufnahme (+: Wechsel zum Up-Trend, -: Wechsel zum Down-Trend)
 *
 * @return bool - Erfolgsstatus (nicht, ob ein Signal aufgetreten ist)
 *
 *
 *  TODO: auslagern
 */
bool CheckTrendChange(int timeframe, string maPeriods, string maTimeframe, string maMethod, int smoothing, int directions, int &lpSignal) {
   lpSignal = 0;
   int maxValues = Max(5 + 8*smoothing, 50);                         // mindestens 50 Werte berechnen, um redundante Indikator-Instanzen zu vermeiden

   int /*ICUSTOM*/ic[]; if (!ArraySize(ic)) InitializeICustom(ic, NULL);
   ic[IC_LAST_ERROR] = NO_ERROR;


   // Trend in Bar 1 ermitteln
   int trend = iCustom(NULL, timeframe, "Moving Average",            // +/-
                       maPeriods,                                    // MA.Periods
                       maTimeframe,                                  // MA.Timeframe
                       maMethod,                                     // MA.Method
                       "Close",                                      // AppliedPrice
                       ForestGreen,                                  // Color.UpTrend
                       Red,                                          // Color.DownTrend
                       smoothing,                                    // Trend.Smoothing
                       0,                                            // Shift.H
                       0,                                            // Shift.V
                       maxValues,                                    // Max.Values
                       "",                                           // _________________
                       ic[IC_PTR],                                   // __iCustom__
                       MovingAverage.MODE_TREND_SMOOTH, 1);          // throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERS_HISTORY_UPDATE) return(_false(catch("CheckTrendChange(1)", error)));
   if (IsError(ic[IC_LAST_ERROR]))                           return(_false(SetLastError(ic[IC_LAST_ERROR])));
   if (!trend)                                               return(_false(catch("CheckTrendChange(2)->iCustom(Moving Average)   invalid trend = "+ trend, ERR_CUSTOM_INDICATOR_ERROR)));


   // Trendwechsel detektieren
   if (trend == +1) /*&&*/ if (_bool(directions & MODE_UPTREND  )) lpSignal = +1;
   if (trend == -1) /*&&*/ if (_bool(directions & MODE_DOWNTREND)) lpSignal = -1;


   if (error == ERS_HISTORY_UPDATE)
      warn("CheckTrendChange()   ERS_HISTORY_UPDATE");               // TODO: bei ERS_HISTORY_UPDATE die zur Berechnung verwendeten Bars prüfen
   return(!__STATUS_ERROR);
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
