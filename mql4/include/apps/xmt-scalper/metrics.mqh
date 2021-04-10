/**
 * Initialize processing of performance metrics.
 *
 * @return bool - success status
 */
bool InitMetrics() {
   // metadata initialization is done only once
   if (!metrics.initialized) {
      ArrayInitialize(metrics.enabled,   0);
      ArrayInitialize(metrics.symbolOK,  0);
      ArrayInitialize(metrics.hSet,      0);
      ArrayInitialize(metrics.hShift, 1000);

      metrics.symbol[METRIC_RC1] = "XMT"+ sequence.id +".RC1"; metrics.digits[METRIC_RC1] = 1; metrics.description[METRIC_RC1] = "XMT."+ sequence.id +" real cumulative PL in pip w/o commission";
      metrics.symbol[METRIC_RC2] = "XMT"+ sequence.id +".RC2"; metrics.digits[METRIC_RC2] = 1; metrics.description[METRIC_RC2] = "XMT."+ sequence.id +" real cumulative PL in pip with commission";
      metrics.symbol[METRIC_RC3] = "XMT"+ sequence.id +".RC3"; metrics.digits[METRIC_RC3] = 2; metrics.description[METRIC_RC3] = "XMT."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_RC4] = "XMT"+ sequence.id +".RC4"; metrics.digits[METRIC_RC4] = 2; metrics.description[METRIC_RC4] = "XMT."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" with commission";
      metrics.symbol[METRIC_RD1] = "XMT"+ sequence.id +".RC1"; metrics.digits[METRIC_RD1] = 1; metrics.description[METRIC_RD1] = "XMT."+ sequence.id +" real daily PL in pip w/o commission";
      metrics.symbol[METRIC_RD2] = "XMT"+ sequence.id +".RC2"; metrics.digits[METRIC_RD2] = 1; metrics.description[METRIC_RD2] = "XMT."+ sequence.id +" real daily PL in pip with commission";
      metrics.symbol[METRIC_RD3] = "XMT"+ sequence.id +".RC3"; metrics.digits[METRIC_RD3] = 2; metrics.description[METRIC_RD3] = "XMT."+ sequence.id +" real daily PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_RD4] = "XMT"+ sequence.id +".RC4"; metrics.digits[METRIC_RD4] = 2; metrics.description[METRIC_RD4] = "XMT."+ sequence.id +" real daily PL in "+ AccountCurrency() +" with commission";

      metrics.symbol[METRIC_VC1] = "XMT"+ sequence.id +".VC1"; metrics.digits[METRIC_VC1] = 1; metrics.description[METRIC_VC1] = "XMT."+ sequence.id +" virtual cumulative PL in pip w/o commission";
      metrics.symbol[METRIC_VC2] = "XMT"+ sequence.id +".VC2"; metrics.digits[METRIC_VC2] = 1; metrics.description[METRIC_VC2] = "XMT."+ sequence.id +" virtual cumulative PL in pip with commission";
      metrics.symbol[METRIC_VC3] = "XMT"+ sequence.id +".VC3"; metrics.digits[METRIC_VC3] = 2; metrics.description[METRIC_VC3] = "XMT."+ sequence.id +" virtual cumulative PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_VC4] = "XMT"+ sequence.id +".VC4"; metrics.digits[METRIC_VC4] = 2; metrics.description[METRIC_VC4] = "XMT."+ sequence.id +" virtual cumulative PL in "+ AccountCurrency() +" with commission";
      metrics.symbol[METRIC_VD1] = "XMT"+ sequence.id +".VC1"; metrics.digits[METRIC_VD1] = 1; metrics.description[METRIC_VD1] = "XMT."+ sequence.id +" virtual daily PL in pip w/o commission";
      metrics.symbol[METRIC_VD2] = "XMT"+ sequence.id +".VC2"; metrics.digits[METRIC_VD2] = 1; metrics.description[METRIC_VD2] = "XMT."+ sequence.id +" virtual daily PL in pip with commission";
      metrics.symbol[METRIC_VD3] = "XMT"+ sequence.id +".VC3"; metrics.digits[METRIC_VD3] = 2; metrics.description[METRIC_VD3] = "XMT."+ sequence.id +" virtual daily PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_VD4] = "XMT"+ sequence.id +".VC4"; metrics.digits[METRIC_VD4] = 2; metrics.description[METRIC_VD4] = "XMT."+ sequence.id +" virtual daily PL in "+ AccountCurrency() +" with commission";

      metrics.initialized = true;
   }

   // the metrics configuration is read and applied on each call
   string section = ProgramName() + ifString(IsTesting(), ".Tester", "");
   metrics.enabled[METRIC_RC1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RC1", true));
   metrics.enabled[METRIC_RC2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RC2", true));
   metrics.enabled[METRIC_RC3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RC3", true));
   metrics.enabled[METRIC_RC4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RC4", true));
   metrics.enabled[METRIC_RD1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RD1", true));
   metrics.enabled[METRIC_RD2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RD2", true));
   metrics.enabled[METRIC_RD3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RD3", true));
   metrics.enabled[METRIC_RD4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric_RD4", true));

   metrics.enabled[METRIC_VC1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VC1", true));
   metrics.enabled[METRIC_VC2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VC2", true));
   metrics.enabled[METRIC_VC3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VC3", true));
   metrics.enabled[METRIC_VC4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VC4", true));
   metrics.enabled[METRIC_VD1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VD1", true));
   metrics.enabled[METRIC_VD2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VD2", true));
   metrics.enabled[METRIC_VD3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VD3", true));
   metrics.enabled[METRIC_VD4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric_VD4", true));

   InitHistory(METRIC_RC1);
   InitHistory(METRIC_RC2);
   InitHistory(METRIC_RC3);
   InitHistory(METRIC_RC4);
   InitHistory(METRIC_RD1);
   InitHistory(METRIC_RD2);
   InitHistory(METRIC_RD3);
   InitHistory(METRIC_RD4);

   InitHistory(METRIC_VC1);
   InitHistory(METRIC_VC2);
   InitHistory(METRIC_VC3);
   InitHistory(METRIC_VC4);
   InitHistory(METRIC_VD1);
   InitHistory(METRIC_VD2);
   InitHistory(METRIC_VD3);
   InitHistory(METRIC_VD4);

   return(!catch("InitMetrics(1)"));
}


/**
 * Open/close the history of the specified metric.
 *
 * @param  int metric - metric identifier
 *
 * @return bool - success status
 */
bool InitHistory(int metric) {
   if (!metrics.enabled[metric]) {
      CloseHistorySet(metric);                                 // close the history
      return(true);
   }

   if (!metrics.symbolOK[metric]) {                            // create a new symbol if it doesn't exist
      //CreateSymbol();
      metrics.symbolOK[metric] = true;
   }

   if (!metrics.hSet[metric])                                  // open the history
      metrics.hSet[metric] = GetHistorySet(metric);

   return(metrics.hSet[metric] != NULL);
}


/**
 * Return a handle for the HistorySet of the specified metric.
 *
 * @param  int metric - metric identifier
 *
 * @return int - HistorySet handle or NULL in case of other errors
 */
int GetHistorySet(int metric) {
   int hSet;
   if      (metric <  6) hSet = HistorySet1.Get(metrics.symbol[metric], metrics.server);
   else if (metric < 12) hSet = HistorySet2.Get(metrics.symbol[metric], metrics.server);
   else                  hSet = HistorySet3.Get(metrics.symbol[metric], metrics.server);

   if (hSet == -1) {
      if      (metric <  6) hSet = HistorySet1.Create(metrics.symbol[metric], metrics.description[metric], metrics.digits[metric], metrics.format, metrics.server);
      else if (metric < 12) hSet = HistorySet2.Create(metrics.symbol[metric], metrics.description[metric], metrics.digits[metric], metrics.format, metrics.server);
      else                  hSet = HistorySet3.Create(metrics.symbol[metric], metrics.description[metric], metrics.digits[metric], metrics.format, metrics.server);
   }

   if (hSet > 0)
      return(hSet);
   return(NULL);
}


/**
 * Close the HistorySet of the specified metric.
 *
 * @param  int metric - metric identifier
 *
 * @return bool - success status
 */
bool CloseHistorySet(int metric) {
   if (!metrics.hSet[metric]) return(true);

   bool success = false;
   if      (metric <  6) success = HistorySet1.Close(metrics.hSet[metric]);
   else if (metric < 12) success = HistorySet2.Close(metrics.hSet[metric]);
   else                  success = HistorySet3.Close(metrics.hSet[metric]);

   metrics.hSet[metric] = NULL;
   return(success);
}


/**
 * Record performance metrics of the sequence.
 *
 * @return bool - success status
 */
bool RecordMetrics() {
   double value;
   bool success = true;

   static int flags;
   static bool flagsInitialized = false; if (!flagsInitialized) {
      flags = ifInt(IsTesting(), HST_BUFFER_TICKS, NULL);      // buffer ticks in tester
      flagsInitialized = true;
   }

   // real metrics
   if (metrics.enabled[METRIC_RC1] && success) {               // cumulative PL in pip w/o commission
      value   = real.totalPip + metrics.hShift[METRIC_RC1];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC1], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_RC2] && success) {               // cumulative PL in pip with commission
      value   = real.totalPipNet + metrics.hShift[METRIC_RC2];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC2], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_RC3] && success) {               // cumulative PL in money w/o commission
      value   = real.totalPl + metrics.hShift[METRIC_RC3];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC3], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_RC4] && success) {               // cumulative PL in money with commission
      value   = real.totalPlNet + metrics.hShift[METRIC_RC4];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC4], Tick.Time, value, flags);
   }
 //if (metrics.enabled[METRIC_RD1] && success) {               // daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD1], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD2] && success) {               // daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD2], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD3] && success) {               // daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD3], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD4] && success) {               // daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD4], Tick.Time, value, flags);
 //}

   // virtual metrics
   if (metrics.enabled[METRIC_VC1] && success) {               // cumulative PL in pip w/o commission
      value   = virt.totalPip + metrics.hShift[METRIC_VC1];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC1], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_VC2] && success) {               // cumulative PL in pip with commission
      value   = virt.totalPipNet + metrics.hShift[METRIC_VC2];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC2], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_VC3] && success) {               // cumulative PL in money w/o commission
      value   = virt.totalPl + metrics.hShift[METRIC_VC3];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC3], Tick.Time, value, flags);
   }
   if (metrics.enabled[METRIC_VC4] && success) {               // cumulative PL in money with commission
      value   = virt.totalPlNet + metrics.hShift[METRIC_VC4];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC4], Tick.Time, value, flags);
   }
 //if (metrics.enabled[METRIC_VD1] && success) {               // daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD1], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD2] && success) {               // daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD2], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD3] && success) {               // daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD3], Tick.Time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD4] && success) {               // daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD4], Tick.Time, value, flags);
 //}
   return(success);
}
