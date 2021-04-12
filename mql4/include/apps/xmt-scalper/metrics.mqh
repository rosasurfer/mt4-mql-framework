/**
 * Management and processing of system performance metrics
 */
#define METRIC_RC1      0              // real: cumulative PL in pip w/o commission
#define METRIC_RC2      1              // real: cumulative PL in pip with commission
#define METRIC_RC3      2              // real: cumulative PL in money w/o commission
#define METRIC_RC4      3              // real: cumulative PL in money with commission
#define METRIC_RD1      4              // real: daily PL in pip w/o commission
#define METRIC_RD2      5              // real: daily PL in pip with commission
#define METRIC_RD3      6              // real: daily PL in money w/o commission
#define METRIC_RD4      7              // real: daily PL in money with commission

#define METRIC_VC1      8              // virt: cumulative PL in pip w/o commission
#define METRIC_VC2      9              // virt: cumulative PL in pip with commission
#define METRIC_VC3     10              // virt: cumulative PL in money w/o commission
#define METRIC_VC4     11              // virt: cumulative PL in money with commission
#define METRIC_VD1     12              // virt: daily PL in pip w/o commission
#define METRIC_VD2     13              // virt: daily PL in pip with commission
#define METRIC_VD3     14              // virt: daily PL in money w/o commission
#define METRIC_VD4     15              // virt: daily PL in money with commission


bool   metrics.initialized;            // whether metrics metadata has been initialized
string metrics.server = "XTrade-Testresults";
int    metrics.format = 400;

bool   metrics.enabled    [16];        // whether a specific metric is currently activated
string metrics.symbol     [16];        // the symbol of a metric
string metrics.description[16];        // the description of a metric
int    metrics.digits     [16];        // the digits value of a metric
bool   metrics.symbolOK   [16];        // whether the "symbols.raw" checkup of a metric was done
int    metrics.hSet       [16];        // the HistorySet handle of a metric
double metrics.hShift     [16];        // horizontal shift added to the history of a metric to prevent negative values


/**
 * Initialize/re-initialize metrics processing.
 *
 * @return bool - success status
 */
bool InitMetrics() {
   if (!metrics.initialized) {
      // metadata is initialized only once
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

   // the metrics configuration is read/applied on every call
   string section = ProgramName() + ifString(IsTesting(), ".Tester", "");
   metrics.enabled[METRIC_RC1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC1", true));
   metrics.enabled[METRIC_RC2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC2", true));
   metrics.enabled[METRIC_RC3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC3", true));
   metrics.enabled[METRIC_RC4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC4", true));
   metrics.enabled[METRIC_RD1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD1", true));
   metrics.enabled[METRIC_RD2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD2", true));
   metrics.enabled[METRIC_RD3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD3", true));
   metrics.enabled[METRIC_RD4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD4", true));

   metrics.enabled[METRIC_VC1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC1", true));
   metrics.enabled[METRIC_VC2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC2", true));
   metrics.enabled[METRIC_VC3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC3", true));
   metrics.enabled[METRIC_VC4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC4", true));
   metrics.enabled[METRIC_VD1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD1", true));
   metrics.enabled[METRIC_VD2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD2", true));
   metrics.enabled[METRIC_VD3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD3", true));
   metrics.enabled[METRIC_VD4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD4", true));

   int size = ArraySize(metrics.enabled);
   for (int i=0; i < size; i++) {
      InitMetricHistory(i);
   }
   return(!catch("InitMetrics(1)"));
}


/**
 * Open/close the history of the specified metric.
 *
 * @param  int mId - metric identifier
 *
 * @return bool - success status
 */
bool InitMetricHistory(int mId) {
   if (!metrics.enabled[mId]) {
      CloseHistorySet(mId);                                       // close the history
      return(true);
   }

   if (!metrics.symbolOK[mId]) {
      if (metrics.server != "") {
         if (!IsRawSymbol(metrics.symbol[mId], metrics.server)) {    // create a new symbol if it doesn't yet exist
            string group = "System metrics";
            int sId = CreateSymbol(metrics.symbol[mId], metrics.description[mId], group, metrics.digits[mId], AccountCurrency(), AccountCurrency(), metrics.server);
            if (sId < 0) return(false);
         }
      }
      metrics.symbolOK[mId] = true;
   }

   if (!metrics.hSet[mId])                                        // open the history
      metrics.hSet[mId] = GetHistorySet(mId);

   return(metrics.hSet[mId] != NULL);
}


/**
 * Return a handle for the HistorySet of the specified metric.
 *
 * @param  int mId - metric identifier
 *
 * @return int - HistorySet handle or NULL in case of other errors
 */
int GetHistorySet(int mId) {
   int hSet;
   if      (mId <  6) hSet = HistorySet1.Get(metrics.symbol[mId], metrics.server);
   else if (mId < 12) hSet = HistorySet2.Get(metrics.symbol[mId], metrics.server);
   else               hSet = HistorySet3.Get(metrics.symbol[mId], metrics.server);

   if (hSet == -1) {
      if      (mId <  6) hSet = HistorySet1.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
      else if (mId < 12) hSet = HistorySet2.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
      else               hSet = HistorySet3.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
   }

   if (hSet > 0)
      return(hSet);
   return(NULL);
}


/**
 * Close the HistorySet of the specified metric.
 *
 * @param  int mId - metric identifier
 *
 * @return bool - success status
 */
bool CloseHistorySet(int mId) {
   if (!metrics.hSet[mId]) return(true);

   bool success = false;
   if      (mId <  6) success = HistorySet1.Close(metrics.hSet[mId]);
   else if (mId < 12) success = HistorySet2.Close(metrics.hSet[mId]);
   else               success = HistorySet3.Close(metrics.hSet[mId]);

   metrics.hSet[mId] = NULL;
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
