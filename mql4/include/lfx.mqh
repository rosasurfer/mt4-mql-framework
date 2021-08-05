/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15         entspricht rsfLib1::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15         Vielfaches von 0.1 von 1 bis 10           // wird in MagicNumber nicht mehr verwendet
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15                                                   // wird in MagicNumber nicht mehr verwendet
 */
#define STRATEGY_ID               102                          // unique strategy id from 101-1023 (10 bit)

#define NO_LIMIT_TRIGGERED         -1                          // Limitkontrolle
#define OPEN_LIMIT_TRIGGERED        1
#define STOPLOSS_LIMIT_TRIGGERED    2
#define TAKEPROFIT_LIMIT_TRIGGERED  3

bool   mode.intern = true;                                     // default: Orderdaten und Trading im aktuellen Account
bool   mode.extern = false;                                    // Orderdaten und Trading in externem Account

string tradeAccount.company = "";
int    tradeAccount.number;
string tradeAccount.currency = "";
int    tradeAccount.type;                                      // ACCOUNT_TYPE_DEMO|ACCOUNT_TYPE_REAL
string tradeAccount.name = "";                                 // Inhaber

string lfxCurrency = "";
int    lfxCurrencyId;
int    lfxOrders[][LFX_ORDER.intSize];                         // Array von LFX_ORDERs

// Trade-Terminal -> LFX-Terminal: P/L-Messages
string  qc.TradeToLfxChannels[9];                              // ein Channel je LFX-Währung bzw. LFX-Chart
int    hQC.TradeToLfxSenders [9];                              // jeweils ein Sender
string  qc.TradeToLfxChannel = "";                             // Channel des aktuellen LFX-Charts (einer)
int    hQC.TradeToLfxReceiver;                                 // Receiver des aktuellen LFX-Charts (einer)

// LFX-Terminal -> Trade-Terminal: TradeCommands
string  qc.TradeCmdChannel = "";
int    hQC.TradeCmdSender;
int    hQC.TradeCmdReceiver;


/**
 * Initialize global vars describing the current trade account.
 *
 * @param  string accountId [optional] - account identifier in format "{account-company}:{account-number}"
 *                                       (default: the current account)
 *
 * @return bool - success status i.e. whether the new account data was successfully applied
 */
bool InitTradeAccount(string accountId = "") {
   if (accountId == "0") accountId = "";                       // (string) NULL

   string currAccountCompany = GetAccountCompany(); if (!StringLen(currAccountCompany)) return(false);
   int    currAccountNumber  = GetAccountNumber();  if (!currAccountNumber)             return(false);

   string _accountCompany = "";                                // global vars are modified on success only
   int    _accountNumber;
   string _accountCurrency = "";
   int    _accountType;
   string _accountName = "";

   if (StringLen(accountId) > 0) {
      // resolve the specified trade account
      _accountCompany = StrLeftTo(accountId, ":"); if (!StringLen(_accountCompany)) return(!logWarn("InitTradeAccount(1)  invalid parameter accountId: "+ DoubleQuoteStr(accountId)));
      string sValue = StrRightFrom(accountId, ":"); if (!StrIsDigit(sValue))        return(!logWarn("InitTradeAccount(2)  invalid parameter accountId: "+ DoubleQuoteStr(accountId)));
      _accountNumber = StrToInteger(sValue); if (!_accountNumber)                   return(!logWarn("InitTradeAccount(3)  invalid parameter accountId: "+ DoubleQuoteStr(accountId)));
   }
   else {
      // use the current account and resolve a configured trade account
      _accountCompany = currAccountCompany;
      _accountNumber  = currAccountNumber;

      string file    = GetAccountConfigPath(); if (!StringLen(file)) return(false);
      string section = "General";
      string key     = "TradeAccount"+ ifString(This.IsTesting(), ".Tester", "");
      sValue = GetIniStringA(file, section, key, "");
      if (StringLen(sValue) > 0) {
         if (!StrIsDigit(sValue))                                                   return(!logWarn("InitTradeAccount(4)  invalid trade account setting ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue)));
         _accountNumber = StrToInteger(sValue); if (!_accountNumber)                return(!logWarn("InitTradeAccount(5)  invalid trade account setting ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue)));
         section = "Accounts";
         key     = _accountNumber +".company";
         sValue  = GetGlobalConfigString(section, key); if (!StringLen(sValue))     return(!logWarn("InitTradeAccount(6)  missing global account setting ["+ section +"]->"+ key));
         _accountCompany = sValue;
      }
   }

   // cancel execution if the resolved trade account is already active
   if (tradeAccount.company==_accountCompany && tradeAccount.number==_accountNumber)
      return(true);

   // resolve the remaining vars
   _accountCurrency = AccountCurrency();
   _accountType     = ifInt(IsDemoFix(), ACCOUNT_TYPE_DEMO, ACCOUNT_TYPE_REAL);
   _accountName     = AccountName();

   if (_accountCompany!=currAccountCompany || _accountNumber!=currAccountNumber) {
      // AccountCurrency
      section = "Accounts";
      key     = _accountNumber +".currency";
      sValue  = GetGlobalConfigString(section, key); if (!StringLen(sValue))        return(!logWarn("InitTradeAccount(7)  missing global account setting ["+ section +"]->"+ key));
      if (!IsCurrency(sValue))                                                      return(!logWarn("InitTradeAccount(8)  invalid global account setting ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue)));
      _accountCurrency = StrToUpper(sValue);

      // AccountType
      section = "Accounts";
      key     = _accountNumber +".type";
      sValue  = GetGlobalConfigString(section, key); if (!StringLen(sValue))        return(!logWarn("InitTradeAccount(9)  missing global account setting ["+ section +"]->"+ key));
      if      (StrCompareI(sValue, "demo")) _accountType = ACCOUNT_TYPE_DEMO;
      else if (StrCompareI(sValue, "real")) _accountType = ACCOUNT_TYPE_REAL;
      else                                                                          return(!logWarn("InitTradeAccount(10)  invalid global account setting ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue)));

      // AccountName
      section = "Accounts";
      key     = _accountNumber +".name";
      sValue  = GetGlobalConfigString(section, key); if (!StringLen(sValue))        return(!logWarn("InitTradeAccount(11)  missing global account setting ["+ section +"]->"+ key));
      _accountName = sValue;
   }

   // success: modify global vars
   mode.intern = (_accountCompany==currAccountCompany && _accountNumber==currAccountNumber);
   mode.extern = !mode.intern;

   tradeAccount.company  = _accountCompany;
   tradeAccount.number   = _accountNumber;
   tradeAccount.currency = _accountCurrency;
   tradeAccount.type     = _accountType;
   tradeAccount.name     = _accountName;

   // store account identifier in the chart to enable remote access by scripts
   string label = "TradeAccount";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      RegisterObject(label);
   }                                                                 // format "{account-company}:{account-number}"
   ObjectSetText(label, StringConcatenate(tradeAccount.company, ":", tradeAccount.number));

   if (mode.extern) {
      if (StrEndsWith(Symbol(), "LFX")) {
         lfxCurrency   = StrLeft(Symbol(), -3);                      // TODO: replace LFX vars with actual symbol
         lfxCurrencyId = GetCurrencyId(lfxCurrency);
      }
   }
   return(true);
}


/**
 * Ob das aktuell selektierte Ticket eine LFX-Order ist.
 *
 * @return bool
 */
bool LFX.IsMyOrder() {
   return(OrderMagicNumber() >> 22 == STRATEGY_ID);                  // 10 bit (Bit 23-32) => Bereich 101-1023
}


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Order zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID, entsprechend std::GetCurrencyId()
 */
int LFX.CurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 1-15
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Order zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.InstanceId(int magicNumber) {
   return(magicNumber >> 4 & 0x3FF);                                 // 10 bit (Bit 5-14) => Bereich 1-1023
}


/**
 * Erzeugt eine neue Instanz-ID.
 *
 * @param  LFX_ORDER orders[] - Array von LFX_ORDERs. Die generierte Instanz-ID wird unter Berücksichtigung dieser Orders eindeutig sein.
 *
 * @return int - Instanz-ID im Bereich 1-1023 (10 bit)
 */
int LFX.CreateInstanceId(/*LFX_ORDER*/int orders[][]) {
   int id, ids[], size=ArrayRange(orders, 0);
   ArrayResize(ids, 0);

   for (int i=0; i < size; i++) {
      ArrayPushInt(ids, LFX.InstanceId(los.Ticket(orders, i)));
   }

   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   while (!id) {
      id = MathRand();
      while (id > 1023) {
         id >>= 1;
      }
      if (IntInArray(ids, id))                                       // sicherstellen, daß die ID nicht gerade benutzt wird
         id = 0;
   }
   return(id);
}


/**
 * Generiert eine neue LFX-Ticket-ID (Wert für OrderMagicNumber().
 *
 * @param  LFX_ORDER orders[] - Array von LFX_ORDERs. Das generierte Ticket wird unter Berücksichtigung dieser Orders eindeutig sein.
 * @param  string    currency - LFX-Währung, für die eine Ticket-ID erzeugt werden soll.
 *
 * @return int - LFX-Ticket-ID oder NULL, falls ein Fehler auftrat
 */
int LFX.CreateMagicNumber(/*LFX_ORDER*/int orders[][], string currency) {
   int iStrategy = STRATEGY_ID & 0x3FF << 22;                        // 10 bit (Bits 23-32)
   int iCurrency = GetCurrencyId(currency) & 0xF << 18;              //  4 bit (Bits 19-22)
   int iInstance = LFX.CreateInstanceId(orders) & 0x3FF << 4;        // 10 bit (Bits  5-14)
   return(iStrategy + iCurrency + iInstance);
}


/**
 * Gibt den größten existierenden Marker der offenen Orders des angegebenen Symbols zurück.
 *
 * @param  LFX_ORDER orders[]   - Array von LFX_ORDERs
 * @param  int       currencyId - Währungs-ID
 *
 * @return int - positive Ganzzahl oder 0, falls keine markierte Order existiert
 */
int LFX.GetMaxOpenOrderMarker(/*LFX_ORDER*/int orders[][], int currencyId) {
   int marker, size=ArrayRange(orders, 0);

   for (int i=0; i < size; i++) {
      if (los.CurrencyId(orders, i) != currencyId) continue;
      if (los.IsClosed  (orders, i))               continue;

      string comment = los.Comment(orders, i);
      if      (StrStartsWith(comment, los.Currency(orders, i) +".")) comment = StrRightFrom(comment, ".");
      else if (StrStartsWith(comment, "#"))                          comment = StrRight    (comment,  -1);
      else
         continue;
      marker = Max(marker, StrToInteger(comment));
   }
   return(marker);
}


/**
 * Ob die angegebene LFX-Order eines ihrer konfigurierten Limite erreicht hat.
 *
 * @param  _In_     LFX_ORDER orders[] - Array von LFX-ORDERs
 * @param  _In_     int       i        - Index der zu prüfenden Order innerhalb des übergebenen LFX_ORDER-Arrays
 * @param  _In_opt_ double    bid      - zur Prüfung zu benutzender Bid-Preis bei Price-Limits   (NULL:        keine Limitprüfung gegen den Bid-Preis)
 * @param  _In_opt_ double    ask      - zur Prüfung zu benutzender Ask-Preis bei Price-Limits   (NULL:        keine Limitprüfung gegen den Ask-Preis)
 * @param  _In_opt_ double    profit   - zur Prüfung zu benutzender P/L-Betrag bei Profit-Limits (EMPTY_VALUE: keine Limitprüfung von Profitbeträgen )
 *
 * @return int - Triggerstatus, NO_LIMIT_TRIGGERED:         wenn kein Limit erreicht wurde
 *                              OPEN_LIMIT_TRIGGERED:       wenn ein Entry-Limit erreicht wurde
 *                              STOPLOSS_LIMIT_TRIGGERED:   wenn ein StopLoss-Limit erreicht wurde
 *                              TAKEPROFIT_LIMIT_TRIGGERED: wenn ein TakeProfit-Limit erreicht wurde
 *                              0 (zero):                   wenn ein Fehler auftrat
 *
 * Nachdem ein Limit getriggert wurde, wird bis zum Eintreffen der Ausführungsbestätigung derselbe Triggerstatus zurückgegeben.
 */
int LFX.CheckLimits(/*LFX_ORDER*/int orders[][], int i, double bid, double ask, double profit) {
   if (los.IsClosed(orders, i)) return(NO_LIMIT_TRIGGERED);


   // (1) fehlerhafte Orders und bereits getriggerte Limits (auf Ausführungsbestätigung wartende Order) abfangen
   int type = los.Type(orders, i);
   switch (type) {
      case OP_BUYLIMIT :
      case OP_BUYSTOP  :
      case OP_SELLLIMIT:
      case OP_SELLSTOP :
         if (los.IsOpenError    (orders, i))        return(NO_LIMIT_TRIGGERED);
         if (los.OpenTriggerTime(orders, i) != 0)   return(OPEN_LIMIT_TRIGGERED);
         break;

      case OP_BUY :
      case OP_SELL:
         if (los.IsCloseError(orders, i))           return(NO_LIMIT_TRIGGERED);
         if (los.CloseTriggerTime(orders, i) != 0) {
            if (los.StopLossTriggered  (orders, i)) return(STOPLOSS_LIMIT_TRIGGERED  );
            if (los.TakeProfitTriggered(orders, i)) return(TAKEPROFIT_LIMIT_TRIGGERED);
            return(_NULL(catch("LFX.CheckLimits(1)  business rule violation in #"+ los.Ticket(orders, i) +": closeTriggerTime="+ los.CloseTriggerTime(orders, i) +", slTriggered=false, tpTriggered=false", ERR_RUNTIME_ERROR)));
         }
         break;

      default:
         return(NO_LIMIT_TRIGGERED);
   }


   // (2) Open-Limits prüfen
   int digits = los.Digits(orders, i);
   switch (type) {
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         if (ask!=NULL) /*&&*/ if (LE(ask, los.OpenPrice(orders, i), digits)) {
            los.setClosePrice(orders, i, ask);
            return(OPEN_LIMIT_TRIGGERED);
         }
         return(NO_LIMIT_TRIGGERED);

      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
         if (bid!=NULL) /*&&*/ if (GE(bid, los.OpenPrice(orders, i), digits)) {
            los.setClosePrice(orders, i, bid);
            return(OPEN_LIMIT_TRIGGERED);
         }
         return(NO_LIMIT_TRIGGERED);
   }


   // (3) Close-Limits prüfen
   if (los.IsStopLoss(orders, i)) {
      switch (type) {
         case OP_BUY:
            if (ask!=NULL) /*&&*/ if (los.IsStopLossPrice(orders, i)) /*&&*/ if (LE(ask, los.StopLossPrice(orders, i), digits)) {
               los.setClosePrice(orders, i, ask        );
               los.setProfit    (orders, i, EMPTY_VALUE);
               return(STOPLOSS_LIMIT_TRIGGERED);
            }
            break;

         case OP_SELL:
            if (bid!=NULL) /*&&*/ if (los.IsStopLossPrice(orders, i)) /*&&*/ if (GE(bid, los.StopLossPrice(orders, i), digits)) {
               los.setClosePrice(orders, i, bid        );
               los.setProfit    (orders, i, EMPTY_VALUE);
               return(STOPLOSS_LIMIT_TRIGGERED);
            }
            break;
      }
      if (profit != EMPTY_VALUE) {
         if (los.IsStopLossValue(orders, i)) /*&&*/ if (LE(profit, los.StopLossValue(orders, i), 2)) {
            los.setClosePrice(orders, i, NULL  );
            los.setProfit    (orders, i, profit);
            return(STOPLOSS_LIMIT_TRIGGERED);
         }
         if (los.IsStopLossPercent(orders, i)) /*&&*/ if (LE(profit/los.OpenEquity(orders, i)*100, los.StopLossPercent(orders, i), 2)) {
            los.setClosePrice(orders, i, NULL  );
            los.setProfit    (orders, i, profit);
            return(STOPLOSS_LIMIT_TRIGGERED);
         }
      }
   }

   if (los.IsTakeProfit(orders, i)) {
      switch (type) {
         case OP_BUY:
            if (bid!=NULL) /*&&*/ if (los.IsTakeProfitPrice(orders, i)) /*&&*/ if (GE(bid, los.TakeProfitPrice(orders, i), digits)) {
               los.setClosePrice(orders, i, bid        );
               los.setProfit    (orders, i, EMPTY_VALUE);
               return(TAKEPROFIT_LIMIT_TRIGGERED);
            }
            break;

         case OP_SELL:
            if (ask!=NULL) /*&&*/ if (los.IsTakeProfitPrice(orders, i)) /*&&*/ if (LE(ask, los.TakeProfitPrice(orders, i), digits)) {
               los.setClosePrice(orders, i, ask        );
               los.setProfit    (orders, i, EMPTY_VALUE);
               return(TAKEPROFIT_LIMIT_TRIGGERED);
            }
            break;
      }
      if (profit != EMPTY_VALUE) {
         if (los.IsTakeProfitValue(orders, i)) /*&&*/ if (GE(profit, los.TakeProfitValue(orders, i), 2)) {
            los.setClosePrice(orders, i, NULL  );
            los.setProfit    (orders, i, profit);
            return(TAKEPROFIT_LIMIT_TRIGGERED);
         }
         if (los.IsTakeProfitPercent(orders, i)) /*&&*/ if (GE(profit/los.OpenEquity(orders, i)*100, los.TakeProfitPercent(orders, i), 2)) {
            los.setClosePrice(orders, i, NULL  );
            los.setProfit    (orders, i, profit);
            return(TAKEPROFIT_LIMIT_TRIGGERED);
         }
      }
   }

   return(NO_LIMIT_TRIGGERED);
}


/**
 * Verarbeitet das getriggerte Limit einer LFX-Order. Schickt dem TradeTerminal ein TradeCommand zur Orderausführung und prüft diese.
 *
 * @param  LFX_ORDER orders[]  - Array von LFX_ORDERs
 * @param  int       i         - Index der getriggerten Order innerhalb des übergebenen LFX_ORDER-Arrays
 * @param  int       limitType - Typ des getriggerten Limits
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.SendTradeCommand(/*LFX_ORDER*/int orders[][], int i, int limitType) {
   string   symbol.i = los.Currency(orders, i) +"."+ StrToInteger(StrSubstr(los.Comment(orders, i), 1));
   string   logMsg="", trigger="", limitValue="", currentValue="", separator="", limitPercent="", currentPercent="", priceFormat=",'R.4'";
   int      /*LFX_ORDER*/order[];
   datetime triggerTime, now=TimeFXT(); if (!now) return(false);

   switch (limitType) {
      case NO_LIMIT_TRIGGERED: return(true);

      case OPEN_LIMIT_TRIGGERED:
         triggerTime = los.OpenTriggerTime(orders, i); break;

      case STOPLOSS_LIMIT_TRIGGERED:
      case TAKEPROFIT_LIMIT_TRIGGERED:
         triggerTime = los.CloseTriggerTime(orders, i); break;

      default:
         return(!catch("LFX.SendTradeCommand(1)  invalid parameter limitType: "+ limitType +" (no limit type)", ERR_INVALID_PARAMETER));
   }

   /*
   Überblick:
   ----------
   if (!triggerTime) {
      // (1) Das Limit wurde gerade getriggert (während des aktuellen Ticks), die Orderausführung noch nicht eingeleitet.
   }
   else if (now < triggerTime + 30*SECONDS) {
      // (2) Die Orderausführung wurde eingeleitet und wir warten auf die Ausführungsbestätigung.
   }
   else {
      // (3) Die Orderausführung wurde eingeleitet und die Ausführungsbestätigung ist überfällig.
   }
   */

   // Für Fälle (1) und (3) die Bestandteile eines Betrags-Limits einer Close-Logmessage definieren
   if (now >= triggerTime + 30*SECONDS) {                                              // schließt !triggerTime mit ein
      if (limitType == STOPLOSS_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i)) {
            if (los.IsStopLossValue  (orders, i)) { limitValue   = DoubleToStr(los.StopLossValue  (orders, i), 2);      currentValue   = DoubleToStr(los.Profit(orders, i), 2); }
            if (los.IsStopLossPercent(orders, i)) { limitPercent = DoubleToStr(los.StopLossPercent(orders, i), 2) +"%"; currentPercent = DoubleToStr(los.Profit(orders, i)/los.OpenEquity(orders, i)*100, 2) +"%"; }
            if (los.IsStopLossValue(orders, i) && los.IsStopLossPercent(orders, i)) separator = "|";
         }
      }
      if (limitType == TAKEPROFIT_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i)) {
            if (los.IsTakeProfitValue  (orders, i)) { limitValue   = DoubleToStr(los.TakeProfitValue  (orders, i), 2);      currentValue   = DoubleToStr(los.Profit(orders, i), 2); }
            if (los.IsTakeProfitPercent(orders, i)) { limitPercent = DoubleToStr(los.TakeProfitPercent(orders, i), 2) +"%"; currentPercent = DoubleToStr(los.Profit(orders, i)/los.OpenEquity(orders, i)*100, 2) +"%"; }
            if (los.IsTakeProfitValue(orders, i) && los.IsTakeProfitPercent(orders, i)) separator = "|";
         }
      }
   }


   if (!triggerTime) {
      // (1.1) Die Orderausführung wurde noch nicht eingeleitet. Logmessage zusammenstellen und loggen
      if (limitType == OPEN_LIMIT_TRIGGERED) { trigger = StrToLower(OperationTypeDescription(los.Type(orders, i))) +" at "+ NumberToStr(los.OpenPrice(orders, i), priceFormat) +" triggered"; logMsg = trigger +" (current="+ NumberToStr(los.ClosePrice(orders, i), priceFormat) +")"; }
      if (limitType == STOPLOSS_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i))     { trigger = "SL amount of "+ limitValue + separator + limitPercent +" triggered";                                                                   logMsg = trigger +" (current="+ currentValue + separator + currentPercent +")";           }
         else                                { trigger = "SL price at "+ NumberToStr(los.StopLossPrice(orders, i), priceFormat) +" triggered";                                                   logMsg = trigger +" (current="+ NumberToStr(los.ClosePrice(orders, i), priceFormat) +")"; }
      }
      if (limitType == TAKEPROFIT_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i))     { trigger = "TP amount of "+ limitValue + separator + limitPercent +" triggered";                                                                   logMsg = trigger +" (current="+ currentValue + separator + currentPercent +")";           }
         else                                { trigger = "TP price at "+ NumberToStr(los.TakeProfitPrice(orders, i), priceFormat) +" triggered";                                                 logMsg = trigger +" (current="+ NumberToStr(los.ClosePrice(orders, i), priceFormat) +")"; }
      }
      logMsg = symbol.i +" #"+ los.Ticket(orders, i) +" "+ logMsg;
      logDebug("LFX.SendTradeCommand(2)  "+ logMsg);

      // (1.2) Auslösen speichern und TradeCommand verschicken
      if (limitType == OPEN_LIMIT_TRIGGERED)        los.setOpenTriggerTime    (orders, i, now );
      else {                                        los.setCloseTriggerTime   (orders, i, now );
         if (limitType == STOPLOSS_LIMIT_TRIGGERED) los.setStopLossTriggered  (orders, i, true);
         else                                       los.setTakeProfitTriggered(orders, i, true);
      }
      if (!LFX.SaveOrder(orders, i)) return(false);         // TODO: !!! Fehler in LFX.SaveOrder() behandeln, wenn die Order schon verarbeitet wurde (z.B. von anderem Terminal)

                                                            // "LfxOrder{Type}Command {ticket:12345, trigger:"trigger"}"
      if (limitType == OPEN_LIMIT_TRIGGERED) string tradeCmd = "LfxOrderOpenCommand{ticket:" + los.Ticket(orders, i) +", trigger:"+ DoubleQuoteStr(StrReplace(StrReplace(trigger, ",", HTML_COMMA), "\"", HTML_DQUOTE)) +"}";
      else                                          tradeCmd = "LfxOrderCloseCommand{ticket:"+ los.Ticket(orders, i) +", trigger:"+ DoubleQuoteStr(StrReplace(StrReplace(trigger, ",", HTML_COMMA), "\"", HTML_DQUOTE)) +"}";

      if (!QC.SendTradeCommand(tradeCmd)) {
         if (limitType == OPEN_LIMIT_TRIGGERED) los.setOpenTime (orders, i, -now);     // Bei einem Fehler in QC.SendTradeCommand() diesen Fehler auch
         else                                   los.setCloseTime(orders, i, -now);     // in der Order speichern. Ansonsten wartet die Funktion auf eine
         LFX.SaveOrder(orders, i);                                                     // Ausführungsbestätigung, die nicht kommen kann.
         return(false);
      }
   }
   else if (now < triggerTime + 30*SECONDS) {
      // (2) Die Orderausführung wurde eingeleitet und wir warten auf die Ausführungsbestätigung.
   }
   else {
      // (3) Die Orderausführung wurde eingeleitet und die Ausführungsbestätigung ist überfällig.
      // Logmessage zusammenstellen
      if (limitType == OPEN_LIMIT_TRIGGERED) logMsg = "missing trade confirmation for triggered "+ StrToLower(OperationTypeDescription(los.Type(orders, i))) +" at "+ NumberToStr(los.OpenPrice(orders, i), priceFormat);
      if (limitType == STOPLOSS_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i))     logMsg = "missing trade confirmation for triggered SL amount of "+ limitValue + separator + limitPercent;
         else                                logMsg = "missing trade confirmation for triggered SL price at "+ NumberToStr(los.StopLossPrice(orders, i), priceFormat);
      }
      if (limitType == TAKEPROFIT_LIMIT_TRIGGERED) {
         if (!los.ClosePrice(orders, i))     logMsg = "missing trade confirmation for triggered TP amount of "+ limitValue + separator + limitPercent;
         else                                logMsg = "missing trade confirmation for triggered TP price at "+ NumberToStr(los.TakeProfitPrice(orders, i), priceFormat);
      }

      // aktuell gespeicherte Version der Order holen
      int result = LFX.GetOrder(los.Ticket(orders, i), order); if (result != 1) return(!catch("LFX.SendTradeCommand(3)->LFX.GetOrder(ticket="+ los.Ticket(orders, i) +") => "+ result, ERR_RUNTIME_ERROR));

      if (lo.Version(order) != los.Version(orders, i)) {                               // Gespeicherte Version ist modifiziert (kann nur neuer sein)
         // Die Order wurde ausgeführt oder ein Fehler trat auf. In beiden Fällen erfolgte jedoch keine Benachrichtigung.
         // Diese Prüfung wird als ausreichende Benachrichtigung gewertet und fortgefahren.
         logDebug("LFX.SendTradeCommand(4)  "+ symbol.i +" #"+ los.Ticket(orders, i) +" "+ logMsg +", continuing...");    // TODO: !!! Keine Warnung, solange möglicherweise gar kein Receiver existiert.
         if (limitType == OPEN_LIMIT_TRIGGERED) logDebug("LFX.SendTradeCommand(5)  "+ symbol.i +" #"+ lo.Ticket(order) +" "+ ifString(!lo.IsOpenError (order), "position was opened", "opening of position failed"));
         else                                   logDebug("LFX.SendTradeCommand(6)  "+ symbol.i +" #"+ lo.Ticket(order) +" "+ ifString(!lo.IsCloseError(order), "position was closed", "closing of position failed"));
         ArraySetInts(orders, i, order);                                               // lokale Order mit neu eingelesener Order überschreiben
      }
      else {
         // Order ist unverändert, Fehler melden und speichern.
         logWarn("LFX.SendTradeCommand(7)  "+ symbol.i +" #"+ los.Ticket(orders, i) +" "+ logMsg +", continuing...");
         if (limitType == OPEN_LIMIT_TRIGGERED) los.setOpenTime (orders, i, -now);     // Sollte die Order nach dieser Zeit doch noch erfolgreich ausgeführt werden, wird dieser
         else                                   los.setCloseTime(orders, i, -now);     // Fehler mit dem letztendlichen Erfolg überschrieben. Dies tritt z.B. auf, wenn der
         if (!LFX.SaveOrder(orders, i)) return(false);                                 // Trade-Server vor der letztendlichen Ausführung mehrere Minuten hängt (z.B. Demo-Server).
      }
   }
   return(true);
}


/**
 * Gibt eine LFX-Order des TradeAccounts zurück.
 *
 * @param  int ticket - Ticket der zurückzugebenden Order
 * @param  int lo[]   - struct LFX_ORDER zur Aufnahme der gelesenen Daten
 *
 * @return int - Erfolgsstatus: +1, wenn die Order erfolgreich gelesen wurde
 *                              -1, wenn die Order nicht gefunden wurde
 *                               0, falls ein anderer Fehler auftrat
 */
int LFX.GetOrder(int ticket, /*LFX_ORDER*/int lo[]) {
   // Parametervaliderung
   if (ticket <= 0) return(!catch("LFX.GetOrder(1)  invalid parameter ticket: "+ ticket, ERR_INVALID_PARAMETER));


   // (1) Orderdaten lesen
   string file    = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(0);
   string section = "LFX-Orders";
   string key     = ticket;
   string value   = GetIniStringA(file, section, key, "");
   if (!StringLen(value)) {
      if (IsIniKeyA(file, section, key)) return(!catch("LFX.GetOrder(2)  invalid order entry ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_RUNTIME_ERROR));
                                         return(-1);                 // Ticket nicht gefunden
   }


   // (2) Orderdaten validieren
   //Ticket = Symbol, Comment, OrderType, Units, OpenEquity, OpenTriggerTime, (-)OpenTime, OpenPrice, TakeProfitPrice, TakeProfitValue, TakeProfitPercent, TakeProfitTriggered, StopLossPrice, StopLossValue, StopLossPercent, StopLossTriggered, CloseTriggerTime, (-)CloseTime, ClosePrice, Profit, ModificationTime, Version
   string sValue="", values[];
   if (Explode(value, ",", values, NULL) != 22)       return(!catch("LFX.GetOrder(3)  invalid order entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   int digits = 5;

   // Comment
   string _comment = StrTrim(values[1]);

   // OrderType
   sValue = StrTrim(values[2]);
   int _orderType = StrToOperationType(sValue);
   if (!IsOrderType(_orderType))                      return(!catch("LFX.GetOrder(4)  invalid order type \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderUnits
   sValue = StrTrim(values[3]);
   if (!StrIsNumeric(sValue))                         return(!catch("LFX.GetOrder(5)  invalid unit size \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderUnits = StrToDouble(sValue);
   if (_orderUnits <= 0)                              return(!catch("LFX.GetOrder(6)  invalid unit size \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _orderUnits = NormalizeDouble(_orderUnits, 1);

   // OpenEquity
   sValue = StrTrim(values[4]);
   if (!StrIsNumeric(sValue))                         return(!catch("LFX.GetOrder(7)  invalid open equity \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openEquity = StrToDouble(sValue);
   if (!IsPendingOrderType(_orderType))
      if (_openEquity <= 0)                           return(!catch("LFX.GetOrder(8)  invalid open equity \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _openEquity = NormalizeDouble(_openEquity, 2);

   // OpenTriggerTime
   sValue = StrTrim(values[5]);
   if (StrIsDigit(sValue)) datetime _openTriggerTime = StrToInteger(sValue);
   else                             _openTriggerTime =    StrToTime(sValue);
   if      (_openTriggerTime < 0)                     return(!catch("LFX.GetOrder(9)  invalid open-trigger time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_openTriggerTime > 0)
      if (_openTriggerTime > GetFxtTime())            return(!catch("LFX.GetOrder(10)  invalid open-trigger time \""+ TimeToStr(_openTriggerTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenTime
   sValue = StrTrim(values[6]);
   if      (StrIsInteger(sValue)) datetime _openTime =  StrToInteger(sValue);
   else if (StrStartsWith(sValue, "-"))    _openTime = -StrToTime(StringSubstr(sValue, 1));
   else                                    _openTime =  StrToTime(sValue);
   if (!_openTime)                                    return(!catch("LFX.GetOrder(11)  invalid open time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (Abs(_openTime) > GetFxtTime())                 return(!catch("LFX.GetOrder(12)  invalid open time \""+ TimeToStr(Abs(_openTime), TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenPrice
   sValue = StrTrim(values[7]);
   if (!StrIsNumeric(sValue))                         return(!catch("LFX.GetOrder(13)  invalid open price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openPrice = StrToDouble(sValue);
   if (_openPrice <= 0)                               return(!catch("LFX.GetOrder(14)  invalid open price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _openPrice = NormalizeDouble(_openPrice, digits);

   // TakeProfitPrice
   sValue = StrTrim(values[8]);
   if (!StringLen(sValue)) double _takeProfitPrice = 0;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(15)  invalid takeprofit price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _takeProfitPrice = StrToDouble(sValue);
      if (_takeProfitPrice < 0)                       return(!catch("LFX.GetOrder(16)  invalid takeprofit price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      _takeProfitPrice = NormalizeDouble(_takeProfitPrice, digits);
   }

   // TakeProfitValue
   sValue = StrTrim(values[9]);
   if      (!StringLen(sValue)) double _takeProfitValue = EMPTY_VALUE;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(17)  invalid takeprofit value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else                                _takeProfitValue = NormalizeDouble(StrToDouble(sValue), 2);

   // TakeProfitPercent
   sValue = StrTrim(values[10]);
   if      (!StringLen(sValue)) double _takeProfitPercent = EMPTY_VALUE;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(18)  invalid takeprofit percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _takeProfitPercent = NormalizeDouble(StrToDouble(sValue), 2);
      if (_takeProfitPercent < -100)                  return(!catch("LFX.GetOrder(19)  invalid takeprofit percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // TakeProfitTriggered
   sValue = StrTrim(values[11]);
   if      (sValue == "0") bool _takeProfitTriggered = false;
   else if (sValue == "1")      _takeProfitTriggered = true;
   else                                               return(!catch("LFX.GetOrder(20)  invalid takeProfit-triggered value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // StopLossPrice
   sValue = StrTrim(values[12]);
   if (!StringLen(sValue)) double _stopLossPrice = 0;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(21)  invalid stoploss price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossPrice = StrToDouble(sValue);
      if (_stopLossPrice < 0)                         return(!catch("LFX.GetOrder(22)  invalid stoploss price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      _stopLossPrice = NormalizeDouble(_stopLossPrice, digits);
      if (_stopLossPrice && _takeProfitPrice) {
         if (IsLongOrderType(_orderType)) {
            if (_stopLossPrice >= _takeProfitPrice)   return(!catch("LFX.GetOrder(23)  stoploss/takeprofit price mis-match "+ DoubleToStr(_stopLossPrice, digits) +"/"+ DoubleToStr(_takeProfitPrice, digits) +" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
         }
         else if (_stopLossPrice <= _takeProfitPrice) return(!catch("LFX.GetOrder(24)  stoploss/takeprofit price mis-match "+ DoubleToStr(_stopLossPrice, digits) +"/"+ DoubleToStr(_takeProfitPrice, digits) +" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      }
   }

   // StopLossValue
   sValue = StrTrim(values[13]);
   if      (!StringLen(sValue)) double _stopLossValue = EMPTY_VALUE;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(25)  invalid stoploss value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossValue = NormalizeDouble(StrToDouble(sValue), 2);
      if (!IsEmptyValue(_stopLossValue) && !IsEmptyValue(_takeProfitValue))
         if (_stopLossValue >= _takeProfitValue)      return(!catch("LFX.GetOrder(26)  stoploss/takeprofit value mis-match "+ DoubleToStr(_stopLossValue, 2) +"/"+ DoubleToStr(_takeProfitValue, 2) +" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // StopLossPercent
   sValue = StrTrim(values[14]);
   if      (!StringLen(sValue)) double _stopLossPercent = EMPTY_VALUE;
   else if (!StrIsNumeric(sValue))                    return(!catch("LFX.GetOrder(27)  invalid stoploss percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossPercent = NormalizeDouble(StrToDouble(sValue), 2);
      if (_stopLossPercent < -100)                    return(!catch("LFX.GetOrder(28)  invalid stoploss percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      if (!IsEmptyValue(_stopLossPercent) && !IsEmptyValue(_takeProfitPercent))
         if (_stopLossPercent >= _takeProfitPercent)  return(!catch("LFX.GetOrder(29)  stoploss/takeprofit percent mis-match "+ DoubleToStr(_stopLossPercent, 2) +"/"+ DoubleToStr(_takeProfitPercent, 2) +" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // StopLossTriggered
   sValue = StrTrim(values[15]);
   if      (sValue == "0") bool _stopLossTriggered = false;
   else if (sValue == "1")      _stopLossTriggered = true;
   else                                               return(!catch("LFX.GetOrder(30)  invalid stoploss-triggered value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // CloseTriggerTime
   sValue = StrTrim(values[16]);
   if (StrIsDigit(sValue)) datetime _closeTriggerTime = StrToInteger(sValue);
   else                             _closeTriggerTime =    StrToTime(sValue);
   if      (_closeTriggerTime < 0)                    return(!catch("LFX.GetOrder(31)  invalid close-trigger time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_closeTriggerTime > 0)
      if (_closeTriggerTime > GetFxtTime())           return(!catch("LFX.GetOrder(32)  invalid close-trigger time \""+ TimeToStr(_closeTriggerTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // CloseTime
   sValue = StrTrim(values[17]);
   if      (StrIsInteger(sValue)) datetime _closeTime =  StrToInteger(sValue);
   else if (StrStartsWith(sValue, "-"))    _closeTime = -StrToTime(StringSubstr(sValue, 1));
   else                                    _closeTime =  StrToTime(sValue);
   if (Abs(_closeTime) > GetFxtTime())                return(!catch("LFX.GetOrder(33)  invalid close time \""+ TimeToStr(Abs(_closeTime), TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // ClosePrice
   sValue = StrTrim(values[18]);
   if (!StrIsNumeric(sValue))                         return(!catch("LFX.GetOrder(34)  invalid close price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _closePrice = StrToDouble(sValue);
   if (_closePrice < 0)                               return(!catch("LFX.GetOrder(35)  invalid close price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _closePrice = NormalizeDouble(_closePrice, digits);
   if (_closeTime > 0 && !_closePrice)                return(!catch("LFX.GetOrder(36)  close time/price mis-match \""+ TimeToStr(_closeTime, TIME_FULL) +"\"/0 in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderProfit
   sValue = StrTrim(values[19]);
   if (!StrIsNumeric(sValue))                         return(!catch("LFX.GetOrder(37)  invalid order profit \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderProfit = StrToDouble(sValue);
   _orderProfit = NormalizeDouble(_orderProfit, 2);

   // ModificationTime
   sValue = StrTrim(values[20]);
   if (StrIsDigit(sValue)) datetime _modificationTime = StrToInteger(sValue);
   else                             _modificationTime =    StrToTime(sValue);
   if (_modificationTime <= 0)                        return(!catch("LFX.GetOrder(38)  invalid modification time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_modificationTime > GetFxtTime())              return(!catch("LFX.GetOrder(39)  invalid modification time \""+ TimeToStr(_modificationTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // Version
   sValue = StrTrim(values[21]);
   if (!StrIsDigit(sValue))                           return(!catch("LFX.GetOrder(40)  invalid version \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   int _version = StrToInteger(sValue);
   if (_version <= 0)                                 return(!catch("LFX.GetOrder(41)  invalid version \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));


   // (3) Orderdaten in übergebenes Array schreiben (erst nach vollständiger erfolgreicher Validierung)
   InitializeByteBuffer(lo, LFX_ORDER.size);

   lo.setTicket             (lo,  ticket             );              // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
   lo.setType               (lo, _orderType          );
   lo.setUnits              (lo, _orderUnits         );
   lo.setLots               (lo,  NULL               );
   lo.setOpenEquity         (lo, _openEquity         );
   lo.setOpenTriggerTime    (lo, _openTriggerTime    );
   lo.setOpenTime           (lo, _openTime           );
   lo.setOpenPrice          (lo, _openPrice          );
   lo.setStopLossPrice      (lo, _stopLossPrice      );
   lo.setStopLossValue      (lo, _stopLossValue      );
   lo.setStopLossPercent    (lo, _stopLossPercent    );
   lo.setStopLossTriggered  (lo, _stopLossTriggered  );
   lo.setTakeProfitPrice    (lo, _takeProfitPrice    );
   lo.setTakeProfitValue    (lo, _takeProfitValue    );
   lo.setTakeProfitPercent  (lo, _takeProfitPercent  );
   lo.setTakeProfitTriggered(lo, _takeProfitTriggered);
   lo.setCloseTriggerTime   (lo, _closeTriggerTime   );
   lo.setCloseTime          (lo, _closeTime          );
   lo.setClosePrice         (lo, _closePrice         );
   lo.setProfit             (lo, _orderProfit        );
   lo.setComment            (lo, _comment            );
   lo.setModificationTime   (lo, _modificationTime   );
   lo.setVersion            (lo, _version            );

   return(!catch("LFX.GetOrder(42)"));
}


// OrderType-Flags, siehe LFX.GetOrders()
#define OF_OPEN                1
#define OF_CLOSED              2
#define OF_PENDINGORDER        4
#define OF_OPENPOSITION        8
#define OF_PENDINGPOSITION    16


/**
 * Gibt mehrere LFX-Orders des TradeAccounts zurück.
 *
 * @param  string currency    - LFX-Währung der Orders (default: alle Währungen)
 * @param  int    fSelection  - Kombination von Selection-Flags (default: alle Orders werden zurückgegeben)
 *                              OF_OPEN            - gibt alle offenen Tickets zurück:                   Pending-Orders und offene Positionen, analog zu OrderSelect(MODE_TRADES)
 *                              OF_CLOSED          - gibt alle geschlossenen Tickets zurück:             Trade-History, analog zu OrderSelect(MODE_HISTORY)
 *                              OF_PENDINGORDER    - gibt alle Orders mit aktivem OpenLimit zurück:      OP_BUYLIMIT, OP_BUYSTOP, OP_SELLLIMIT, OP_SELLSTOP
 *                              OF_OPENPOSITION    - gibt alle offenen Positionen zurück
 *                              OF_PENDINGPOSITION - gibt alle Positionen mit aktivem CloseLimit zurück: StopLoss, TakeProfit
 * @param  LFX_ORDER orders[] - LFX_ORDER-Array zur Aufnahme der gelesenen Daten
 *
 * @return int - Anzahl der zurückgegebenen Orders oder EMPTY (-1), falls ein Fehler auftrat
 */
int LFX.GetOrders(string currency, int fSelection, /*LFX_ORDER*/int orders[][]) {
   // (1) Parametervaliderung
   int currencyId = 0;                                                     // 0: alle Währungen
   if (currency == "0")                                                    // (string) NULL
      currency = "";

   if (StringLen(currency) > 0) {
      currencyId = GetCurrencyId(currency); if (!currencyId) return(-1);
   }

   if (!fSelection)                                                        // ohne Angabe wird alles zurückgeben
      fSelection  = OF_OPEN | OF_CLOSED;
   if ((fSelection & OF_PENDINGORDER) && (fSelection & OF_OPENPOSITION))   // sind OF_PENDINGORDER und OF_OPENPOSITION gesetzt, werden alle OF_OPEN zurückgegeben
      fSelection |= OF_OPEN;

   ArrayResize(orders, 0);
   int error = InitializeByteBuffer(orders, LFX_ORDER.size);               // validiert Dimensionierung
   if (IsError(error)) return(_EMPTY(SetLastError(error)));

   // (2) alle Tickets einlesen
   string file = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(EMPTY);
   string keys[];
   int keysSize = GetIniKeys(file, "LFX-Orders", keys);

   // (3) Orders nacheinander einlesen und gegen Currency und Selektionflags prüfen
   /*LFX_ORDER*/int order[];

   for (int i=0; i < keysSize; i++) {
      if (!StrIsDigit(keys[i])) continue;
      int ticket = StrToInteger(keys[i]);

      if (currencyId != 0)
         if (LFX.CurrencyId(ticket) != currencyId)
            continue;

      // Ist ein Currency-Filter angegeben, sind ab hier alle Tickets gefiltert.
      int result = LFX.GetOrder(ticket, order);
      if (result != 1) {
         if (!result)                                                      // -1, wenn das Ticket nicht gefunden wurde
            return(EMPTY);                                                 //  0, falls ein anderer Fehler auftrat
         return(_EMPTY(catch("LFX.GetOrders(1)->LFX.GetOrder(ticket="+ ticket +")  order not found", ERR_RUNTIME_ERROR)));
      }

      bool match = false;
      while (true) {
         if (lo.IsClosed(order)) {
            match = (fSelection & OF_CLOSED);
            break;
         }
         // ab hier immer offene Order
         if (fSelection & OF_OPEN && 1) {
            match = true;
            break;
         }
         if (lo.IsPendingOrder(order)) {
            match = (fSelection & OF_PENDINGORDER);
            break;
         }
         // ab hier immer offene Position
         if (fSelection & OF_OPENPOSITION && 1) {
            match = true;
            break;
         }
         if (fSelection & OF_PENDINGPOSITION && 1)
            match = (lo.IsStopLoss(order) || lo.IsTakeProfit(order));
         break;
      }
      if (match)
         ArrayPushInts(orders, order);                                     // bei Match Order an übergebenes LFX_ORDER-Array anfügen
   }
   ArrayResize(keys,  0);
   ArrayResize(order, 0);

   if (!catch("LFX.GetOrders(2)"))
      return(ArrayRange(orders, 0));
   return(EMPTY);
}


/**
 * Speichert eine oder mehrere LFX-Orders in der .ini-Datei des TradeAccounts.
 *
 * @param  LFX_ORDER orders[] - eine einzelne LFX_ORDER oder ein Array von LFX_ORDERs
 * @param  int       index    - Arrayindex der zu speichernden Order, wenn orders[] ein LFX_ORDER[]-Array ist.
 *                              Der Parameter wird ignoriert, wenn orders[] eine einzelne LFX_ORDER ist.
 * @param  int       fCatch   - Flag mit leise zu setzenden Fehler, sodaß sie vom Aufrufer behandelt werden können
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.SaveOrder(/*LFX_ORDER*/int orders[], int index=NULL, int fCatch=NULL) {
   // (1) übergebene Order in eine einzelne Order umkopieren (Parameter orders[] kann unterschiedliche Dimensionen haben)
   int dims = ArrayDimension(orders); if (dims > 2)   return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(1)  invalid dimensions of parameter orders: "+ dims, ERR_INCOMPATIBLE_ARRAYS, fCatch));

   /*LFX_ORDER*/int order[]; ArrayResize(order, LFX_ORDER.intSize);
   if (dims == 1) {
      // Parameter orders[] ist einzelne Order
      if (ArrayRange(orders, 0) != LFX_ORDER.intSize) return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(2)  invalid size of parameter orders["+ ArrayRange(orders, 0) +"]", ERR_INCOMPATIBLE_ARRAYS, fCatch));
      ArrayCopy(order, orders);
   }
   else {
      // Parameter orders[] ist Order-Array
      if (ArrayRange(orders, 1) != LFX_ORDER.intSize) return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(3)  invalid size of parameter orders["+ ArrayRange(orders, 0) +"]["+ ArrayRange(orders, 1) +"]", ERR_INCOMPATIBLE_ARRAYS, fCatch));
      int ordersSize = ArrayRange(orders, 0);
      if (index < 0 || index > ordersSize-1)          return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(4)  invalid parameter index: "+ index, ERR_ARRAY_INDEX_OUT_OF_RANGE, fCatch));
      int src  = GetIntsAddress(orders) + index*LFX_ORDER.intSize*4;
      int dest = GetIntsAddress(order);
      CopyMemory(dest, src, LFX_ORDER.intSize*4);
   }


   // (2) Aktuell gespeicherte Version der Order holen und konkurrierende Schreibzugriffe abfangen
   /*LFX_ORDER*/int stored[], ticket=lo.Ticket(order);
   int result = LFX.GetOrder(ticket, stored);                        // +1, wenn die Order erfolgreich gelesen wurden
   if (!result) return(false);                                       // -1, wenn die Order nicht gefunden wurde
   if (result > 0) {                                                 //  0, falls ein anderer Fehler auftrat
      if (lo.Version(stored) > lo.Version(order)) {
         logDebug("LFX.SaveOrder(5)  to-store="+ LFX_ORDER.toStr(order ));
         logDebug("LFX.SaveOrder(6)  stored  ="+ LFX_ORDER.toStr(stored));
         return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(7)  concurrent modification of #"+ ticket +", expected version "+ lo.Version(order) +", found version "+ lo.Version(stored), ERR_CONCURRENT_MODIFICATION, fCatch));
      }
   }


   // (3) Daten formatieren
   //Ticket = Symbol, Comment, OrderType, Units, OpenEquity, OpenTriggerTime, OpenTime, OpenPrice, TakeProfitPrice, TakeProfitValue, TakeProfitPercent, TakeProfitTriggered, StopLossPrice, StopLossValue, StopLossPercent, StopLossTriggered, CloseTriggerTime, CloseTime, ClosePrice, Profit, ModificationTime, Version
   string sSymbol              =                          lo.Currency           (order);
   string sComment             =                          lo.Comment            (order);                                                                                                     sComment           = StrPadRight(sComment          , 13, " ");
   string sOperationType       = OperationTypeDescription(lo.Type               (order));                                                                                                    sOperationType     = StrPadRight(sOperationType    , 10, " ");
   string sUnits               =              NumberToStr(lo.Units              (order), ".+");                                                                                              sUnits             = StrPadLeft (sUnits            ,  5, " ");
   string sOpenEquity          =                ifString(!lo.OpenEquity         (order), "0", DoubleToStr(lo.OpenEquity(order), 2));                                                         sOpenEquity        = StrPadLeft (sOpenEquity       , 10, " ");
   string sOpenTriggerTime     =                ifString(!lo.OpenTriggerTime    (order), "0", TimeToStr(lo.OpenTriggerTime(order), TIME_FULL));                                              sOpenTriggerTime   = StrPadLeft (sOpenTriggerTime  , 19, " ");
   string sOpenTime            =                 ifString(lo.OpenTime           (order) < 0, "-", "") + TimeToStr(Abs(lo.OpenTime(order)), TIME_FULL);                                       sOpenTime          = StrPadLeft (sOpenTime         , 19, " ");
   string sOpenPrice           =              DoubleToStr(lo.OpenPrice          (order), lo.Digits(order));                                                                                  sOpenPrice         = StrPadLeft (sOpenPrice        ,  9, " ");
   string sTakeProfitPrice     =                ifString(!lo.IsTakeProfitPrice  (order), "", DoubleToStr(lo.TakeProfitPrice  (order), lo.Digits(order)));                                    sTakeProfitPrice   = StrPadLeft (sTakeProfitPrice  ,  7, " ");
   string sTakeProfitValue     =                ifString(!lo.IsTakeProfitValue  (order), "", DoubleToStr(lo.TakeProfitValue  (order), 2));                                                   sTakeProfitValue   = StrPadLeft (sTakeProfitValue  ,  7, " ");
   string sTakeProfitPercent   =                ifString(!lo.IsTakeProfitPercent(order), "", DoubleToStr(lo.TakeProfitPercent(order), 2));                                                   sTakeProfitPercent = StrPadLeft (sTakeProfitPercent,  5, " ");
   string sTakeProfitTriggered =                         (lo.TakeProfitTriggered(order)!=0);
   string sStopLossPrice       =                ifString(!lo.IsStopLossPrice    (order), "", DoubleToStr(lo.StopLossPrice  (order), lo.Digits(order)));                                      sStopLossPrice     = StrPadLeft (sStopLossPrice    ,  7, " ");
   string sStopLossValue       =                ifString(!lo.IsStopLossValue    (order), "", DoubleToStr(lo.StopLossValue  (order), 2));                                                     sStopLossValue     = StrPadLeft (sStopLossValue    ,  7, " ");
   string sStopLossPercent     =                ifString(!lo.IsStopLossPercent  (order), "", DoubleToStr(lo.StopLossPercent(order), 2));                                                     sStopLossPercent   = StrPadLeft (sStopLossPercent  ,  5, " ");
   string sStopLossTriggered   =                         (lo.StopLossTriggered  (order)!=0);
   string sCloseTriggerTime    =                ifString(!lo.CloseTriggerTime   (order), "0", TimeToStr(lo.CloseTriggerTime(order), TIME_FULL));                                             sCloseTriggerTime  = StrPadLeft (sCloseTriggerTime , 19, " ");
   string sCloseTime           =                 ifString(lo.CloseTime          (order) < 0, "-", "") + ifString(!lo.CloseTime(order), "0", TimeToStr(Abs(lo.CloseTime(order)), TIME_FULL)); sCloseTime         = StrPadLeft (sCloseTime        , 19, " ");
   string sClosePrice          =                ifString(!lo.ClosePrice         (order), "0", DoubleToStr(lo.ClosePrice(order), lo.Digits(order)));                                          sClosePrice        = StrPadLeft (sClosePrice       , 10, " ");
   string sProfit              =                ifString(!lo.Profit             (order), "0", DoubleToStr(lo.Profit    (order), 2));                                                         sProfit            = StrPadLeft (sProfit           ,  7, " ");

     datetime modificationTime = TimeFXT(); if (!modificationTime) return(false);
     int      version          = lo.Version(order) + 1;

   string sModificationTime    = TimeToStr(modificationTime, TIME_FULL);
   string sVersion             = version;


   // (4) Daten schreiben
   string file    = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(false);
   string section = "LFX-Orders";
   string key     = ticket;
   string value   = StringConcatenate(sSymbol, ", ", sComment, ", ", sOperationType, ", ", sUnits, ", ", sOpenEquity, ", ", sOpenTriggerTime, ", ", sOpenTime, ", ", sOpenPrice, ", ", sTakeProfitPrice, ", ", sTakeProfitValue, ", ", sTakeProfitPercent, ", ", sTakeProfitTriggered, ", ", sStopLossPrice, ", ", sStopLossValue, ", ", sStopLossPercent, ", ", sStopLossTriggered, ", ", sCloseTriggerTime, ", ", sCloseTime, ", ", sClosePrice, ", ", sProfit, ", ", sModificationTime, ", ", sVersion);

   if (!WritePrivateProfileStringA(section, key, " "+ value, file))
      return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(8)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ StrReplace(StrReplace(value, " ,", ",", true), ",  ", ", ", true) +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR, fCatch));


   // (5) Version der übergebenen Order aktualisieren
   if (dims == 1) {  lo.setModificationTime(orders,        modificationTime);  lo.setVersion(orders,        version); }
   else           { los.setModificationTime(orders, index, modificationTime); los.setVersion(orders, index, version); }
   return(true);
}


/**
 * Speichert die übergebenen LFX-Orders in der .ini-Datei des TradeAccounts.
 *
 * @param  LFX_ORDER orders[] - Array von LFX_ORDERs
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.SaveOrders(/*LFX_ORDER*/int orders[][]) {
   int size = ArrayRange(orders, 0);
   for (int i=0; i < size; i++) {
      if (!LFX.SaveOrder(orders, i))
         return(false);
   }
   return(true);
}


/**
 * "Exception"-Handler für in LFX.SaveOrder() aufgetretene Fehler. Die angegebenen abzufangenden Fehler werden nur "leise" gesetzt,
 * wodurch eine individuelle Behandlung durch den Aufrufer möglich wird.
 *
 * @param  string message - Fehlermeldung
 * @param  int    error   - der aufgetretene Fehler
 * @param  int    fCatch  - Flag mit leise zu setzenden Fehlern
 *
 * @return int - derselbe Fehler
 *
 * @access private - Aufruf nur aus LFX.SaveOrder()
 */
int __LFX.SaveOrder.HandleError(string message, int error, int fCatch) {
   if (!error)
      return(NO_ERROR);
   SetLastError(error);

   // (1) die angegebenen Fehler "leise" abfangen
   if (fCatch & F_ERR_CONCURRENT_MODIFICATION && 1) {
      if (error == ERR_CONCURRENT_MODIFICATION) {
         if (IsLogNotice()) logNotice(message, error);
         return(error);
      }
   }

   // (2) für alle restlichen Fehler harten Laufzeitfehler auslösen
   return(catch(message, error));
}


/**
 * Sendet dem aktuellen TradeAccount per QuickChannel ein TradeCommand. Zum Empfang läuft im ChartInfos-Indikator eines jeden TradeAccounts
 * ein entsprechender TradeCommand-Listener.
 *
 * @param  string cmd - Command
 *
 * @return bool - Erfolgsstatus
 */
bool QC.SendTradeCommand(string cmd) {
   if (!StringLen(cmd)) return(!catch("QC.SendTradeCommand(1)  invalid parameter cmd: "+ DoubleQuoteStr(cmd), ERR_INVALID_PARAMETER));

   cmd = StrReplace(cmd, TAB, HTML_TAB);

   while (true) {
      if (!hQC.TradeCmdSender) /*&&*/ if (!QC.StartTradeCmdSender())
         return(false);

      int result = QC_SendMessage(hQC.TradeCmdSender, cmd, QC_FLAG_SEND_MSG_IF_RECEIVER);
      if (!result)
         return(!catch("QC.SendTradeCommand(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

      if (result == QC_SEND_MSG_IGNORED) {
         debug("QC.SendTradeCommand(3)  receiver on \""+ qc.TradeCmdChannel +"\" gone");
         QC.StopTradeCmdSender();
         continue;
      }
      break;
   }

   QC.StopTradeCmdSender();
   return(true);
}


/**
 * Startet einen QuickChannel-Sender für TradeCommands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartTradeCmdSender() {
   if (hQC.TradeCmdSender != 0)
      return(true);

   // aktiven Channel ermitteln
   string file    = GetTerminalCommonDataPathA() +"\\quickchannel.ini";
   string section = tradeAccount.number;
   string keys[], value="";
   int error, iValue, keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StrStartsWithI(keys[i], "TradeCommands.")) {
         value = GetIniStringA(file, section, keys[i], "");
         if (value!="") /*&&*/ if (value!="0") {
            // Channel sollte aktiv sein, testen...
            int result = QC_ChannelHasReceiver(keys[i]);
            if (result == QC_CHECK_RECEIVER_OK)                   // Receiver ist da, Channel ist ok
               break;
            if (result == QC_CHECK_CHANNEL_NONE) {                // orphaned Channeleintrag aus .ini-Datei löschen
               if (!DeleteIniKeyA(file, section, keys[i]))        // kann auftreten, wenn das TradeTerminal oder der dortige Indikator crashte (z.B. bei Recompile)
                  return(false);
               continue;
            }
            if (result == QC_CHECK_RECEIVER_NONE) return(!catch("QC.StartTradeCmdSender(1)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") has no reiver but a sender",          ERR_WIN32_ERROR));
            if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.StartTradeCmdSender(2)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
                                                  return(!catch("QC.StartTradeCmdSender(3)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = unexpected return value: "+ result, ERR_WIN32_ERROR));
         }
      }
   }
   if (i >= keysSize) {                                            // break wurde nicht getriggert
      logWarn("QC.StartTradeCmdSender(4)  No TradeCommand receiver for account "+ DoubleQuoteStr(tradeAccount.company +":"+ tradeAccount.number) +" account found (keys="+ keysSize +"). Is the trade terminal running?");
      return(false);
   }

   // Sender auf gefundenem Channel starten
   qc.TradeCmdChannel = keys[i];
   hQC.TradeCmdSender = QC_StartSender(qc.TradeCmdChannel);
   if (!hQC.TradeCmdSender)
      return(!catch("QC.StartTradeCmdSender(5)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.TradeCmdChannel +"\")", ERR_WIN32_ERROR));
   //debug("QC.StartTradeCmdSender(6)  sender on \""+ qc.TradeCmdChannel +"\" started");
   return(true);
}


/**
 * Stoppt einen QuickChannel-Sender für TradeCommands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopTradeCmdSender() {
   if (!hQC.TradeCmdSender)
      return(true);

   int hTmp = hQC.TradeCmdSender;
              hQC.TradeCmdSender = NULL;

   if (!QC_ReleaseSender(hTmp))
      return(!catch("QC.StopTradeCmdSender(1)->MT4iQuickChannel::QC_ReleaseSender(ch=\""+ qc.TradeCmdChannel +"\")  error stopping sender", ERR_WIN32_ERROR));

   //debug("QC.StopTradeCmdSender()  sender on \""+ qc.TradeCmdChannel +"\" stopped");
   return(true);
}


/**
 * Startet einen QuickChannel-Receiver für TradeCommands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartTradeCmdReceiver() {
   if (hQC.TradeCmdReceiver != NULL) return(true);
   if (!__isChart)                   return(false);

   // Channelnamen definieren
   int hWnd = __ExecutionContext[EC.hChart];
   qc.TradeCmdChannel = "TradeCommands."+ IntToHexStr(hWnd);

   // Receiver starten
   hQC.TradeCmdReceiver = QC_StartReceiver(qc.TradeCmdChannel, hWnd);
   if (!hQC.TradeCmdReceiver)
      return(!catch("QC.StartTradeCmdReceiver(1)->MT4iQuickChannel::QC_StartReceiver(channel=\""+ qc.TradeCmdChannel +"\", hWnd="+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));
   //debug("QC.StartTradeCmdReceiver(2)  receiver on \""+ qc.TradeCmdChannel +"\" started");

   // Channelnamen und -status in .ini-Datei hinterlegen
   string file    = GetTerminalCommonDataPathA() +"\\quickchannel.ini";
   string section = GetAccountNumber();
   string key     = qc.TradeCmdChannel;
   string value   = "1";
   if (!WritePrivateProfileStringA(section, key, value, file))
      return(!catch("QC.StartTradeCmdReceiver(3)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));

   return(true);
}


/**
 * Stoppt einen QuickChannel-Receiver für TradeCommands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopTradeCmdReceiver() {
   if (hQC.TradeCmdReceiver != NULL) {
      // Channelstatus in .ini-Datei aktualisieren (vorm Stoppen des Receivers)
      string file    = GetTerminalCommonDataPathA() +"\\quickchannel.ini";
      string section = GetAccountNumber();
      string key     = qc.TradeCmdChannel;
      if (!DeleteIniKeyA(file, section, key)) return(false);

      // Receiver stoppen
      int hTmp = hQC.TradeCmdReceiver;
                 hQC.TradeCmdReceiver = NULL;                        // Handle immer zurücksetzen, um mehrfache Stopversuche bei Fehlern zu vermeiden

      if (!QC_ReleaseReceiver(hTmp)) return(!catch("QC.StopTradeCmdReceiver(1)->MT4iQuickChannel::QC_ReleaseReceiver(channel="+ DoubleQuoteStr(qc.TradeCmdChannel) +")  error stopping receiver", ERR_WIN32_ERROR));

      //debug("QC.StopTradeCmdReceiver()  receiver on "+ DoubleQuoteStr(qc.TradeCmdChannel) +" stopped");
   }
   return(true);
}


/**
 * Sendet dem LFX-Terminal eine Orderbenachrichtigung.
 *
 * @param  int    cid - Currency-ID des für die Nachricht zu benutzenden Channels
 * @param  string msg - Nachricht
 *
 * @return bool - Erfolgsstatus
 */
bool QC.SendOrderNotification(int cid, string msg) {
   if (cid < 1 || cid >= ArraySize(hQC.TradeToLfxSenders))
      return(!catch("QC.SendOrderNotification(1)  illegal parameter cid: "+ cid, ERR_ARRAY_INDEX_OUT_OF_RANGE));

   if (!hQC.TradeToLfxSenders[cid]) /*&&*/ if (!QC.StartLfxSender(cid))
      return(false);

   if (!QC_SendMessage(hQC.TradeToLfxSenders[cid], msg, QC_FLAG_SEND_MSG_IF_RECEIVER))
      return(!catch("QC.SendOrderNotification(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
   return(true);
}


/**
 * Startet einen QuickChannel-Sender für "TradeToLfxTerminal"-Messages. Das LFX-Terminal kann sich über diesen Channel auch selbst
 * Messages schicken.
 *
 * @param  int cid - Currency-ID des zu startenden Channels
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartLfxSender(int cid) {
   if (cid < 1 || cid >= ArraySize(hQC.TradeToLfxSenders))
      return(!catch("QC.StartLfxSender(1)  illegal parameter cid: "+ cid, ERR_ARRAY_INDEX_OUT_OF_RANGE));
   if (hQC.TradeToLfxSenders[cid] > 0)
      return(true);
                                                                     // Channel-Name: "{AccountCompanyAlias}:{AccountNumber}:LFX.Profit.{Currency}"
   qc.TradeToLfxChannels[cid] = tradeAccount.company +":"+ tradeAccount.number +":LFX.Profit."+ GetCurrency(cid);
   hQC.TradeToLfxSenders[cid] = QC_StartSender(qc.TradeToLfxChannels[cid]);
   if (!hQC.TradeToLfxSenders[cid])
      return(!catch("QC.StartLfxSender(2)->MT4iQuickChannel::QC_StartSender(channel="+ DoubleQuoteStr(qc.TradeToLfxChannels[cid]) +")", ERR_WIN32_ERROR));

   //debug("QC.StartLfxSender(3)  sender on "+ DoubleQuoteStr(qc.TradeToLfxChannels[cid]) +" started");
   return(true);
}


/**
 * Stoppt alle QuickChannel-Sender für "TradeToLfxTerminal"-Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopLfxSenders() {
   for (int i=ArraySize(hQC.TradeToLfxSenders)-1; i >= 0; i--) {
      if (hQC.TradeToLfxSenders[i] != NULL) {
         int hTmp = hQC.TradeToLfxSenders[i];
                    hQC.TradeToLfxSenders[i] = NULL;                 // Handle immer zurücksetzen, um mehrfache Stopversuche bei Fehlern zu vermeiden

         if (!QC_ReleaseSender(hTmp)) return(!catch("QC.StopLfxSenders()->MT4iQuickChannel::QC_ReleaseSender(channel="+ DoubleQuoteStr(qc.TradeToLfxChannels[i]) +")  error stopping sender", ERR_WIN32_ERROR));
      }
   }
   return(true);
}


/**
 * Startet einen QuickChannel-Receiver für "TradeToLfxTerminal"-Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartLfxReceiver() {
   if (hQC.TradeToLfxReceiver != NULL) return(true);
   if (!__isChart)                     return(false);
   if (!StrEndsWith(Symbol(), "LFX"))  return(false);                // kein LFX-Chart

   int hWnd = __ExecutionContext[EC.hChart];                         // Channel-Name: "{AccountCompanyAlias}:{AccountNumber}:LFX.Profit.{Currency}"
   qc.TradeToLfxChannel = tradeAccount.company +":"+ tradeAccount.number +":LFX.Profit."+ StrLeft(Symbol(), -3);

   hQC.TradeToLfxReceiver = QC_StartReceiver(qc.TradeToLfxChannel, hWnd);
   if (!hQC.TradeToLfxReceiver)
      return(!catch("QC.StartLfxReceiver(1)->MT4iQuickChannel::QC_StartReceiver(channel="+ DoubleQuoteStr(qc.TradeToLfxChannel) +", hWnd="+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));
   //debug("QC.StartLfxReceiver(2)  receiver on "+ DoubleQuoteStr(qc.TradeToLfxChannel) +" started");
   return(true);
}


/**
 * Stoppt den QuickChannel-Receiver für "TradeToLfxTerminal"-Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopLfxReceiver() {
   if (hQC.TradeToLfxReceiver != NULL) {
      int hTmp = hQC.TradeToLfxReceiver;
                 hQC.TradeToLfxReceiver = NULL;                      // Handle immer zurücksetzen, um mehrfache Stopversuche bei Fehlern zu vermeiden
      if (!QC_ReleaseReceiver(hTmp)) return(!catch("QC.StopLfxReceiver(1)->MT4iQuickChannel::QC_ReleaseReceiver(channel="+ DoubleQuoteStr(qc.TradeToLfxChannel) +")  error stopping receiver", ERR_WIN32_ERROR));
      //debug("QC.StopLfxReceiver(2)  receiver on "+ DoubleQuoteStr(qc.TradeToLfxChannel) +" stopped");
   }
   return(true);
}


/**
 * Stoppt alle laufenden Sender und Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopChannels() {
   if (!QC.StopLfxSenders())       return(false);
   if (!QC.StopLfxReceiver())      return(false);

   if (!QC.StopTradeCmdSender())   return(false);
   if (!QC.StopTradeCmdReceiver()) return(false);
   return(true);
}


/**
 * Dummy-Calls unterdrücken unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int iNull, iNulls[];
   LFX.CheckLimits(iNulls, NULL, NULL, NULL, NULL);
   LFX.CreateInstanceId(iNulls);
   LFX.CreateMagicNumber(iNulls, NULL);
   LFX.CurrencyId(NULL);
   LFX.GetMaxOpenOrderMarker(iNulls, NULL);
   LFX.GetOrder(NULL, iNulls);
   LFX.GetOrders(NULL, NULL, iNulls);
   LFX.InstanceId(NULL);
   LFX.IsMyOrder();
   LFX.SaveOrder(iNulls, NULL);
   LFX.SaveOrders(iNulls);
   LFX.SendTradeCommand(iNulls, NULL, NULL);
   LFX_ORDER.toStr(iNulls);
   QC.SendOrderNotification(NULL, NULL);
   QC.SendTradeCommand(NULL);
   QC.StartLfxReceiver();
   QC.StartLfxSender(NULL);
   QC.StartTradeCmdReceiver();
   QC.StartTradeCmdSender();
   QC.StopChannels();
   QC.StopLfxReceiver();
   QC.StopLfxSenders();
   QC.StopTradeCmdReceiver();
   QC.StopTradeCmdSender();
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   string ArrayPopString(string array[]);
   int    ArrayPushInts(int array[][], int values[]);
   int    ArraySetInts(int array[][], int i, int values[]);
   bool   IntInArray(int haystack[], int needle);
#import
