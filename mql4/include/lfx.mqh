/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15               entspricht stdlib::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15               Vielfaches von 0.1 von 1 bis 10           // wird nicht mehr verwendet, alle Referenzen gelöscht
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15                                                         // wird nicht mehr verwendet, alle Referenzen gelöscht
 */
#define STRATEGY_ID   102                                            // eindeutige ID der Strategie (Bereich 101-1023)


bool   mode.intern = true;    // Default                             // - Interne Positionsdaten stammen aus dem Terminal selbst, sie werden bei jedem Tick zurückgesetzt und neu
bool   mode.extern;                                                  //   eingelesen. Orderänderungen werden automatisch erkannt.
bool   mode.remote;                                                  // - Externe und Remote-Positionsdaten stammen aus einer externen Quelle und werden nur bei Timeframe-Wechsel
                                                                     //   oder nach Eintreffen eines entsprechenden Events zurückgesetzt und neu eingelesen. Orderänderungen werden
string tradeAccount.company;                                         //   nicht automatisch erkannt.
int    tradeAccount.number;
string tradeAccount.currency;
int    tradeAccount.type;                                            // ACCOUNT_TYPE_DEMO|ACCOUNT_TYPE_REAL
string tradeAccount.name;                                            // Inhaber
string tradeAccount.alias;                                           // Alias für Logs, SMS etc.


string lfxCurrency = "";
int    lfxCurrencyId;
int    lfxOrders[][LFX_ORDER.intSize];                               // Array von LFX_ORDERs


#define NO_LIMIT_TRIGGERED         -1                                // Limitkontrolle
#define OPEN_LIMIT_TRIGGERED        1
#define STOPLOSS_LIMIT_TRIGGERED    2
#define TAKEPROFIT_LIMIT_TRIGGERED  3


// Trade-Terminal -> LFX-Terminal: P/L-Messages
string  qc.TradeToLfxChannels[9];                           // ein Channel je LFX-Währung bzw. LFX-Chart
int    hQC.TradeToLfxSenders [9];                           // jeweils ein Sender
string  qc.TradeToLfxChannel;                               // Channel des aktuellen LFX-Charts (einer)
int    hQC.TradeToLfxReceiver;                              // Receiver des aktuellen LFX-Charts (einer)


// LFX-Terminal -> Trade-Terminal: TradeCommands
string  qc.TradeCmdChannel;
int    hQC.TradeCmdSender;
int    hQC.TradeCmdReceiver;


/**
 * Initialisiert Status und Variablen des zu verwendenden TradeAccounts. Wird ein Account-Parameter übergeben, wird dieser Account als externer Account
 * interpretiert und eingestellt (mode.extern=TRUE).
 *
 * @param  string accountKey - Identifier eines externen Accounts im Format "{AccountCompany}:{Account}" (default: keiner)
 *                             Dies kann sein:
 *                              • eine "Integer:Integer"-Kombination: RestoreRuntimeStatus() kennt Accounts nur anhand von Integer-ID's
 *                              • eine "String:Integer"-Kombination:  regulärer Account mit Company und AccountNumber
 *                              • eine "String:String"-Kombination:   SimpleTrader-Account mit Company und AccountAlias
 *
 * @return bool - Erfolgsstatus; nicht, ob der angegebene Schlüssel einen gültigen Account darstellte
 */
bool InitTradeAccount(string accountKey="") {
   if (accountKey == "0")                                            // (string) NULL
      accountKey = "";

   string _accountCompany;
   int    _accountNumber;
   string _accountCurrency;
   int    _accountType;
   string _accountName;
   string _accountAlias;


   // (1) einen übergebenen externen Account zuordnen
   if (StringLen(accountKey) > 0) {
      string sCompanyId = StringLeftTo   (accountKey, ":"); if (!StringLen(sCompanyId))                          return(_true(warn("InitTradeAccount(1)  invalid parameter accountKey = \""+ accountKey +"\"")));
      string sAccountId = StringRightFrom(accountKey, ":"); if (!StringLen(sAccountId))                          return(_true(warn("InitTradeAccount(2)  invalid parameter accountKey = \""+ accountKey +"\"")));

      bool sCompanyId.isDigit = StringIsDigit(sCompanyId);
      bool sAccountId.isDigit = StringIsDigit(sAccountId);

      // (1.1) companyId zuordnen
      if (sCompanyId.isDigit) {
         _accountCompany = ShortAccountCompanyFromId(StrToInteger(sCompanyId)); if (!StringLen(_accountCompany)) return(_true(warn("InitTradeAccount(3)  unsupported account key = \""+ accountKey +"\"")));
      }
      else {
         _accountCompany = sCompanyId; if (!IsShortAccountCompany(_accountCompany))                              return(_true(warn("InitTradeAccount(4)  unsupported account key = \""+ accountKey +"\"")));
      }

      // (1.2) accountId zuordnen
      if (sAccountId.isDigit) {
         _accountNumber = StrToInteger(sAccountId); if (!_accountNumber)                                         return(_true(warn("InitTradeAccount(5)  invalid parameter accountKey = \""+ accountKey +"\"")));
         _accountAlias  = AccountAlias(_accountCompany, _accountNumber); if (!StringLen(_accountAlias))          return(_true(warn("InitTradeAccount(6)  unsupported account key = \""+ accountKey +"\"")));
      }
      else {
         _accountAlias  = sAccountId;
         _accountNumber = AccountNumberFromAlias(_accountCompany, _accountAlias); if (!_accountNumber)           return(_true(warn("InitTradeAccount(7)  unsupported account key = \""+ accountKey +"\"")));
      }
      if (tradeAccount.company==_accountCompany && tradeAccount.number==_accountNumber)
         return(true);


      // (2) restliche Variablen eines SimpleTrader-Accounts ermitteln
      if (StringCompareI(_accountCompany, AC.SimpleTrader)) {
         string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
         string file   = TerminalPath() + mqlDir +"\\files\\"+ _accountCompany +"\\"+ _accountAlias +"_config.ini";
         if (!IsFile(file))      return(_true(warn("InitTradeAccount(8)  account configuration file not found \""+ file +"\"")));

         // AccountCurrency
         string section = "General";
         string key     = "Account.Currency";
         string value   = GetIniString(file, section, key);
         if (!StringLen(value))  return(_true(warn("InitTradeAccount(9)  missing account setting ["+ section +"]->"+ key +" for SimpleTrader account \""+ _accountAlias +"\"")));
         if (!IsCurrency(value)) return(_true(warn("InitTradeAccount(10)  invalid account setting ["+ section +"]->"+ key +" = \""+ value +"\" for SimpleTrader account \""+ _accountAlias +"\"" )));
         _accountCurrency = StringToUpper(value);

         // AccountType (für SimpleTrader immer DEMO)
         _accountType = ACCOUNT_TYPE_DEMO;

         // AccountName
         section = "General";
         key     = "Account.Name";
         value   = GetIniString(file, section, key);
         if (!StringLen(value))  return(_true(warn("InitTradeAccount(11)  missing account setting ["+ section +"]->"+ key +" for SimpleTrader account \""+ _accountAlias +"\"")));
         _accountName = value;
      }
   }


   // (3) kein externer Account angegeben: AccountNumber bestimmen und durch einen ggf. konfigurierten Remote-Account überschreiben
   else {
      _accountNumber = GetAccountNumber(); if (!_accountNumber) return(!SetLastError(stdlib.GetLastError()));

      mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
      file    = TerminalPath() + mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ _accountNumber +"_config.ini";
      section = "General";
         if (IsIndicator() && StringStartsWith(__NAME__, "LFX-Recorder")) section = "LFX-Recorder";
      key     = "TradeAccount" + ifString(This.IsTesting(), ".Tester", "");

      int tradeAccount = GetIniInt(file, section, key);
      if (tradeAccount <= 0) {
         value = GetIniString(file, section, key);
         if (StringLen(value) > 0) return(_true(warn("InitTradeAccount(12)  invalid remote account setting ["+ section +"]->"+ key +" = \""+ value +"\"")));
      }
      else {
         _accountNumber = tradeAccount;
      }
   }


   // (4) restliche Variablen eines Nicht-SimpleTrader-Accounts ermitteln
   if (!StringCompareI(_accountCompany, AC.SimpleTrader)) {
      // AccountCompany
      section = "Accounts";
      key     = _accountNumber +".company";
      value   = GetGlobalConfigString(section, key);
      if (!StringLen(value))  return(_true(warn("InitTradeAccount(13)  missing global account setting ["+ section +"]->"+ key)));
      _accountCompany = value;

      // AccountCurrency
      section = "Accounts";
      key     = _accountNumber +".currency";
      value   = GetGlobalConfigString(section, key);
      if (!StringLen(value))  return(_true(warn("InitTradeAccount(14)  missing global account setting ["+ section +"]->"+ key)));
      if (!IsCurrency(value)) return(_true(warn("InitTradeAccount(15)  invalid global account setting ["+ section +"]->"+ key +" = \""+ value +"\"")));
      _accountCurrency = StringToUpper(value);

      // AccountType
      section = "Accounts";
      key     = _accountNumber +".type";
      value   = StringToLower(GetGlobalConfigString(section, key));
      if (!StringLen(value))  return(_true(warn("InitTradeAccount(16)  missing global account setting ["+ section +"]->"+ key)));
      if      (value == "demo") _accountType = ACCOUNT_TYPE_DEMO;
      else if (value == "real") _accountType = ACCOUNT_TYPE_REAL;
      else                    return(_true(warn("InitTradeAccount(17)  invalid global account setting ["+ section +"]->"+ key +" = \""+ GetGlobalConfigString(section, key) +"\"")));

      // AccountName
      section = "Accounts";
      key     = _accountNumber +".name";
      value   = GetGlobalConfigString(section, key);
      if (!StringLen(value))  return(_true(warn("InitTradeAccount(18)  missing global account setting ["+ section +"]->"+ key)));
      _accountName = value;

      // AccountAlias
      section = "Accounts";
      key     = _accountNumber +".alias";
      value   = GetGlobalConfigString(section, key);
      if (!StringLen(value))  return(_true(warn("InitTradeAccount(19)  missing global account setting ["+ section +"]->"+ key)));
      _accountAlias = value;
   }


   // (5) globale Variablen erst nach vollständiger erfolgreicher Validierung überschreiben
   mode.intern = (_accountCompany==ShortAccountCompany() && _accountNumber==GetAccountNumber());
   mode.extern = !mode.intern && StringLen(accountKey) > 0;
   mode.remote = !mode.intern && !mode.extern;

   tradeAccount.number   = _accountNumber;
   tradeAccount.currency = _accountCurrency;
   tradeAccount.type     = _accountType;
   tradeAccount.company  = _accountCompany;
   tradeAccount.name     = _accountName;
   tradeAccount.alias    = _accountAlias;

   if (mode.remote) {
      if (StringEndsWith(Symbol(), "LFX")) {
         lfxCurrency   = StringLeft(Symbol(), -3);                   // TODO: lfx-Variablen durch Symbol() ersetzen
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

   MathSrand(GetTickCount());
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
      if      (StringStartsWith(comment, los.Currency(orders, i) +".")) comment = StringRightFrom(comment, ".");
      else if (StringStartsWith(comment, "#"))                          comment = StringRight    (comment,  -1);
      else
         continue;
      marker = Max(marker, StrToInteger(comment));
   }
   return(marker);
}


/**
 * Gibt eine LFX-Order des TradeAccounts zurück.
 *
 * @param  int ticket - Ticket der zurückzugebenden Order
 * @param  int lo[]   - LFX_ORDER-Struct zur Aufnahme der gelesenen Daten
 *
 * @return int - Erfolgsstatus: +1, wenn die Order erfolgreich gelesen wurde
 *                              -1, wenn die Order nicht gefunden wurde
 *                               0, falls ein anderer Fehler auftrat
 */
int LFX.GetOrder(int ticket, /*LFX_ORDER*/int lo[]) {
   // Parametervaliderung
   if (ticket <= 0) return(!catch("LFX.GetOrder(1)  invalid parameter ticket = "+ ticket, ERR_INVALID_PARAMETER));


   // (1) Orderdaten lesen
   string mqlDir  = TerminalPath() + ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = mqlDir +"\\files\\"+ tradeAccount.company +"\\"+ tradeAccount.number +"_config.ini";
   string section = "LFX-Orders";
   string key     = ticket;
   string value   = GetIniString(file, section, key);
   if (!StringLen(value)) {
      if (IsIniKey(file, section, key)) return(!catch("LFX.GetOrder(2)  invalid order entry ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_RUNTIME_ERROR));
                                        return(-1);                  // Ticket nicht gefunden
   }


   // (2) Orderdaten validieren
   //Ticket = Symbol, Comment, OrderType, Units, OpenEquity, OpenTriggerTime, (-)OpenTime, OpenPrice, TakeProfitPrice, TakeProfitValue, TakeProfitPercent, TakeProfitTriggered, StopLossPrice, StopLossValue, StopLossPercent, StopLossTriggered, CloseTriggerTime, (-)CloseTime, ClosePrice, Profit, ModificationTime, Version
   string sValue, values[];
   if (Explode(value, ",", values, NULL) != 22)       return(!catch("LFX.GetOrder(3)  invalid order entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   int digits = 5;

   // Comment
   string _comment = StringTrim(values[1]);

   // OrderType
   sValue = StringTrim(values[2]);
   int _orderType = StrToOperationType(sValue);
   if (!IsTradeOperation(_orderType))                 return(!catch("LFX.GetOrder(4)  invalid order type \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderUnits
   sValue = StringTrim(values[3]);
   if (!StringIsNumeric(sValue))                      return(!catch("LFX.GetOrder(5)  invalid unit size \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderUnits = StrToDouble(sValue);
   if (_orderUnits <= 0)                              return(!catch("LFX.GetOrder(6)  invalid unit size \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _orderUnits = NormalizeDouble(_orderUnits, 1);

   // OpenEquity
   sValue = StringTrim(values[4]);
   if (!StringIsNumeric(sValue))                      return(!catch("LFX.GetOrder(7)  invalid open equity \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openEquity = StrToDouble(sValue);
   if (!IsPendingTradeOperation(_orderType))
      if (_openEquity <= 0)                           return(!catch("LFX.GetOrder(8)  invalid open equity \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _openEquity = NormalizeDouble(_openEquity, 2);

   // OpenTriggerTime
   sValue = StringTrim(values[5]);
   if (StringIsDigit(sValue)) datetime _openTriggerTime = StrToInteger(sValue);
   else                                _openTriggerTime =    StrToTime(sValue);
   if      (_openTriggerTime < 0)                     return(!catch("LFX.GetOrder(9)  invalid open-trigger time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_openTriggerTime > 0)
      if (_openTriggerTime > GetFxtTime())            return(!catch("LFX.GetOrder(10)  invalid open-trigger time \""+ TimeToStr(_openTriggerTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenTime
   sValue = StringTrim(values[6]);
   if      (StringIsInteger(sValue)) datetime _openTime =  StrToInteger(sValue);
   else if (StringStartsWith(sValue, "-"))    _openTime = -StrToTime(StringSubstr(sValue, 1));
   else                                       _openTime =  StrToTime(sValue);
   if (!_openTime)                                    return(!catch("LFX.GetOrder(11)  invalid open time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (Abs(_openTime) > GetFxtTime())                 return(!catch("LFX.GetOrder(12)  invalid open time \""+ TimeToStr(Abs(_openTime), TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenPrice
   sValue = StringTrim(values[7]);
   if (!StringIsNumeric(sValue))                      return(!catch("LFX.GetOrder(13)  invalid open price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openPrice = StrToDouble(sValue);
   if (_openPrice <= 0)                               return(!catch("LFX.GetOrder(14)  invalid open price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _openPrice = NormalizeDouble(_openPrice, digits);

   // TakeProfitPrice
   sValue = StringTrim(values[8]);
   if (!StringLen(sValue)) double _takeProfitPrice = 0;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(15)  invalid takeprofit price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _takeProfitPrice = StrToDouble(sValue);
      if (_takeProfitPrice < 0)                       return(!catch("LFX.GetOrder(16)  invalid takeprofit price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      _takeProfitPrice = NormalizeDouble(_takeProfitPrice, digits);
   }

   // TakeProfitValue
   sValue = StringTrim(values[9]);
   if      (!StringLen(sValue)) double _takeProfitValue = EMPTY_VALUE;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(17)  invalid takeprofit value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else                               _takeProfitValue = NormalizeDouble(StrToDouble(sValue), 2);

   // TakeProfitPercent
   sValue = StringTrim(values[10]);
   if      (!StringLen(sValue)) double _takeProfitPercent = EMPTY_VALUE;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(18)  invalid takeprofit percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _takeProfitPercent = NormalizeDouble(StrToDouble(sValue), 2);
      if (_takeProfitPercent < -100)                  return(!catch("LFX.GetOrder(19)  invalid takeprofit percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // TakeProfitTriggered
   sValue = StringTrim(values[11]);
   if      (sValue == "0") bool _takeProfitTriggered = false;
   else if (sValue == "1")      _takeProfitTriggered = true;
   else                                               return(!catch("LFX.GetOrder(20)  invalid takeProfit-triggered value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // StopLossPrice
   sValue = StringTrim(values[12]);
   if (!StringLen(sValue)) double _stopLossPrice = 0;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(21)  invalid stoploss price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossPrice = StrToDouble(sValue);
      if (_stopLossPrice < 0)                         return(!catch("LFX.GetOrder(22)  invalid stoploss price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      _stopLossPrice = NormalizeDouble(_stopLossPrice, digits);
      if (_stopLossPrice && _takeProfitPrice) {
         if (IsLongTradeOperation(_orderType)) {
            if (_stopLossPrice >= _takeProfitPrice)   return(!catch("LFX.GetOrder(23)  stoploss/takeprofit price mis-match "+ DoubleToStr(_stopLossPrice, digits) +"/"+ DoubleToStr(_takeProfitPrice, digits) +" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
         }
         else if (_stopLossPrice <= _takeProfitPrice) return(!catch("LFX.GetOrder(24)  stoploss/takeprofit price mis-match "+ DoubleToStr(_stopLossPrice, digits) +"/"+ DoubleToStr(_takeProfitPrice, digits) +" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      }
   }

   // StopLossValue
   sValue = StringTrim(values[13]);
   if      (!StringLen(sValue)) double _stopLossValue = EMPTY_VALUE;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(25)  invalid stoploss value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossValue = NormalizeDouble(StrToDouble(sValue), 2);
      if (!IsEmptyValue(_stopLossValue) && !IsEmptyValue(_takeProfitValue))
         if (_stopLossValue >= _takeProfitValue)      return(!catch("LFX.GetOrder(26)  stoploss/takeprofit value mis-match "+ DoubleToStr(_stopLossValue, 2) +"/"+ DoubleToStr(_takeProfitValue, 2) +" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // StopLossPercent
   sValue = StringTrim(values[14]);
   if      (!StringLen(sValue)) double _stopLossPercent = EMPTY_VALUE;
   else if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(27)  invalid stoploss percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else {
      _stopLossPercent = NormalizeDouble(StrToDouble(sValue), 2);
      if (_stopLossPercent < -100)                    return(!catch("LFX.GetOrder(28)  invalid stoploss percent value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
      if (!IsEmptyValue(_stopLossPercent) && !IsEmptyValue(_takeProfitPercent))
         if (_stopLossPercent >= _takeProfitPercent)  return(!catch("LFX.GetOrder(29)  stoploss/takeprofit percent mis-match "+ DoubleToStr(_stopLossPercent, 2) +"/"+ DoubleToStr(_takeProfitPercent, 2) +" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }

   // StopLossTriggered
   sValue = StringTrim(values[15]);
   if      (sValue == "0") bool _stopLossTriggered = false;
   else if (sValue == "1")      _stopLossTriggered = true;
   else                                               return(!catch("LFX.GetOrder(30)  invalid stoploss-triggered value \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // CloseTriggerTime
   sValue = StringTrim(values[16]);
   if (StringIsDigit(sValue)) datetime _closeTriggerTime = StrToInteger(sValue);
   else                                _closeTriggerTime =    StrToTime(sValue);
   if      (_closeTriggerTime < 0)                    return(!catch("LFX.GetOrder(31)  invalid close-trigger time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_closeTriggerTime > 0)
      if (_closeTriggerTime > GetFxtTime())           return(!catch("LFX.GetOrder(32)  invalid close-trigger time \""+ TimeToStr(_closeTriggerTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // CloseTime
   sValue = StringTrim(values[17]);
   if      (StringIsInteger(sValue)) datetime _closeTime =  StrToInteger(sValue);
   else if (StringStartsWith(sValue, "-"))    _closeTime = -StrToTime(StringSubstr(sValue, 1));
   else                                       _closeTime =  StrToTime(sValue);
   if (Abs(_closeTime) > GetFxtTime())                return(!catch("LFX.GetOrder(33)  invalid close time \""+ TimeToStr(Abs(_closeTime), TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // ClosePrice
   sValue = StringTrim(values[18]);
   if (!StringIsNumeric(sValue))                      return(!catch("LFX.GetOrder(34)  invalid close price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _closePrice = StrToDouble(sValue);
   if (_closePrice < 0)                               return(!catch("LFX.GetOrder(35)  invalid close price \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   _closePrice = NormalizeDouble(_closePrice, digits);
   if (!_closeTime && _closePrice)                    return(!catch("LFX.GetOrder(36)  close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_closeTime > 0 && !_closePrice)                return(!catch("LFX.GetOrder(37)  close time/price mis-match \""+ TimeToStr(_closeTime, TIME_FULL) +"\"/0 in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderProfit
   sValue = StringTrim(values[19]);
   if (!StringIsNumeric(sValue))                      return(!catch("LFX.GetOrder(38)  invalid order profit \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderProfit = StrToDouble(sValue);
   _orderProfit = NormalizeDouble(_orderProfit, 2);

   // ModificationTime
   sValue = StringTrim(values[20]);
   if (StringIsDigit(sValue)) datetime _modificationTime = StrToInteger(sValue);
   else                                _modificationTime =    StrToTime(sValue);
   if (_modificationTime <= 0)                        return(!catch("LFX.GetOrder(39)  invalid modification time \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_modificationTime > GetFxtTime())              return(!catch("LFX.GetOrder(40)  invalid modification time \""+ TimeToStr(_modificationTime, TIME_FULL) +" FXT\" (current time \""+ TimeToStr(GetFxtTime(), TIME_FULL) +" FXT\") in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // Version
   sValue = StringTrim(values[21]);
   if (!StringIsDigit(sValue))                        return(!catch("LFX.GetOrder(41)  invalid version \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   int _version = StrToInteger(sValue);
   if (_version <= 0)                                 return(!catch("LFX.GetOrder(42)  invalid version \""+ sValue +"\" in order ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));


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

   return(!catch("LFX.GetOrder(43)"));
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
 * @return int - Anzahl der zurückgegebenen Orders oder -1 (EMPTY), falls ein Fehler auftrat
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
   string mqlDir  = TerminalPath() + ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = mqlDir +"\\files\\"+ tradeAccount.company +"\\"+ tradeAccount.number +"_config.ini";
   string section = "LFX-Orders";
   string keys[];
   int keysSize = GetIniKeys(file, section, keys);


   // (3) Orders nacheinander einlesen und gegen Currency und Selektionflags prüfen
   /*LFX_ORDER*/int order[];

   for (int i=0; i < keysSize; i++) {
      if (!StringIsDigit(keys[i])) continue;
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
   int dims = ArrayDimension(orders); if (dims > 2)   return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(1)  invalid dimensions of parameter orders = "+ dims, ERR_INCOMPATIBLE_ARRAYS, fCatch));

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
      if (index < 0 || index > ordersSize-1)          return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(4)  invalid parameter index = "+ index, ERR_ARRAY_INDEX_OUT_OF_RANGE, fCatch));
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
         log("LFX.SaveOrder(5)  stored  ="+ LFX_ORDER.toStr(stored));
         log("LFX.SaveOrder(6)  to store="+ LFX_ORDER.toStr(order ));
         return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(7)  concurrent modification of #"+ ticket +", expected version "+ lo.Version(order) +" of '"+ TimeToStr(lo.ModificationTime(order), TIME_FULL) +" FXT', found version "+ lo.Version(stored) +" of '"+ TimeToStr(lo.ModificationTime(stored), TIME_FULL) +" FXT'", ERR_CONCURRENT_MODIFICATION, fCatch));
      }
   }


   // (3) Daten formatieren
   //Ticket = Symbol, Comment, OrderType, Units, OpenEquity, OpenTriggerTime, OpenTime, OpenPrice, TakeProfitPrice, TakeProfitValue, TakeProfitPercent, TakeProfitTriggered, StopLossPrice, StopLossValue, StopLossPercent, StopLossTriggered, CloseTriggerTime, CloseTime, ClosePrice, Profit, ModificationTime, Version
   string sSymbol              =                          lo.Currency           (order);
   string sComment             =                          lo.Comment            (order);                                                                                                     sComment           = StringPadRight(sComment          , 13, " ");
   string sOperationType       = OperationTypeDescription(lo.Type               (order));                                                                                                    sOperationType     = StringPadRight(sOperationType    , 10, " ");
   string sUnits               =              NumberToStr(lo.Units              (order), ".+");                                                                                              sUnits             = StringPadLeft (sUnits            ,  5, " ");
   string sOpenEquity          =                ifString(!lo.OpenEquity         (order), "0", DoubleToStr(lo.OpenEquity(order), 2));                                                         sOpenEquity        = StringPadLeft (sOpenEquity       , 10, " ");
   string sOpenTriggerTime     =                ifString(!lo.OpenTriggerTime    (order), "0", TimeToStr(lo.OpenTriggerTime(order), TIME_FULL));                                              sOpenTriggerTime   = StringPadLeft (sOpenTriggerTime  , 19, " ");
   string sOpenTime            =                 ifString(lo.OpenTime           (order) < 0, "-", "") + TimeToStr(Abs(lo.OpenTime(order)), TIME_FULL);                                       sOpenTime          = StringPadLeft (sOpenTime         , 19, " ");
   string sOpenPrice           =              DoubleToStr(lo.OpenPrice          (order), lo.Digits(order));                                                                                  sOpenPrice         = StringPadLeft (sOpenPrice        ,  9, " ");
   string sTakeProfitPrice     =                ifString(!lo.IsTakeProfitPrice  (order), "", DoubleToStr(lo.TakeProfitPrice  (order), lo.Digits(order)));                                    sTakeProfitPrice   = StringPadLeft (sTakeProfitPrice  ,  7, " ");
   string sTakeProfitValue     =                ifString(!lo.IsTakeProfitValue  (order), "", DoubleToStr(lo.TakeProfitValue  (order), 2));                                                   sTakeProfitValue   = StringPadLeft (sTakeProfitValue  ,  7, " ");
   string sTakeProfitPercent   =                ifString(!lo.IsTakeProfitPercent(order), "", DoubleToStr(lo.TakeProfitPercent(order), 2));                                                   sTakeProfitPercent = StringPadLeft (sTakeProfitPercent,  5, " ");
   string sTakeProfitTriggered =                         (lo.TakeProfitTriggered(order)!=0);
   string sStopLossPrice       =                ifString(!lo.IsStopLossPrice    (order), "", DoubleToStr(lo.StopLossPrice  (order), lo.Digits(order)));                                      sStopLossPrice     = StringPadLeft (sStopLossPrice    ,  7, " ");
   string sStopLossValue       =                ifString(!lo.IsStopLossValue    (order), "", DoubleToStr(lo.StopLossValue  (order), 2));                                                     sStopLossValue     = StringPadLeft (sStopLossValue    ,  7, " ");
   string sStopLossPercent     =                ifString(!lo.IsStopLossPercent  (order), "", DoubleToStr(lo.StopLossPercent(order), 2));                                                     sStopLossPercent   = StringPadLeft (sStopLossPercent  ,  5, " ");
   string sStopLossTriggered   =                         (lo.StopLossTriggered  (order)!=0);
   string sCloseTriggerTime    =                ifString(!lo.CloseTriggerTime   (order), "0", TimeToStr(lo.CloseTriggerTime(order), TIME_FULL));                                             sCloseTriggerTime  = StringPadLeft (sCloseTriggerTime , 19, " ");
   string sCloseTime           =                 ifString(lo.CloseTime          (order) < 0, "-", "") + ifString(!lo.CloseTime(order), "0", TimeToStr(Abs(lo.CloseTime(order)), TIME_FULL)); sCloseTime         = StringPadLeft (sCloseTime        , 19, " ");
   string sClosePrice          =                ifString(!lo.ClosePrice         (order), "0", DoubleToStr(lo.ClosePrice(order), lo.Digits(order)));                                          sClosePrice        = StringPadLeft (sClosePrice       , 10, " ");
   string sProfit              =                ifString(!lo.Profit             (order), "0", DoubleToStr(lo.Profit    (order), 2));                                                         sProfit            = StringPadLeft (sProfit           ,  7, " ");

     datetime modificationTime = TimeFXT(); if (!modificationTime) return(false);
     int      version          = lo.Version(order) + 1;

   string sModificationTime    = TimeToStr(modificationTime, TIME_FULL);
   string sVersion             = version;


   // (4) Daten schreiben
   string mqlDir  = TerminalPath() + ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = mqlDir +"\\files\\"+ tradeAccount.company +"\\"+ tradeAccount.number +"_config.ini";
   string section = "LFX-Orders";
   string key     = ticket;
   string value   = StringConcatenate(sSymbol, ", ", sComment, ", ", sOperationType, ", ", sUnits, ", ", sOpenEquity, ", ", sOpenTriggerTime, ", ", sOpenTime, ", ", sOpenPrice, ", ", sTakeProfitPrice, ", ", sTakeProfitValue, ", ", sTakeProfitPercent, ", ", sTakeProfitTriggered, ", ", sStopLossPrice, ", ", sStopLossValue, ", ", sStopLossPercent, ", ", sStopLossTriggered, ", ", sCloseTriggerTime, ", ", sCloseTime, ", ", sClosePrice, ", ", sProfit, ", ", sModificationTime, ", ", sVersion);

   if (!WritePrivateProfileStringA(section, key, " "+ value, file))
      return(!__LFX.SaveOrder.HandleError("LFX.SaveOrder(8)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR, fCatch));


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
 * @private - Aufruf nur aus LFX.SaveOrder()
 */
/*@private*/int __LFX.SaveOrder.HandleError(string message, int error, int fCatch) {
   if (!error)
      return(NO_ERROR);
   SetLastError(error);

   // (1) die angegebenen Fehler "leise" abfangen
   if (fCatch & MUTE_ERR_CONCUR_MODIFICATION && 1) {
      if (error == ERR_CONCURRENT_MODIFICATION) {
         if (__LOG) log(message, error);
         return(error);
      }
   }

   // (2) für alle restlichen Fehler harten Laufzeitfehler auslösen
   return(catch(message, error));
}


/**
 * Sendet dem aktuellen TradeAccount ein TradeCommand.
 *
 * @param  string cmd - Command
 *
 * @return bool - Erfolgsstatus
 */
bool QC.SendTradeCommand(string cmd) {
   while (true) {
      if (!hQC.TradeCmdSender) /*&&*/ if (!QC.StartTradeCmdSender())
         return(false);

      int result = QC_SendMessage(hQC.TradeCmdSender, cmd, QC_FLAG_SEND_MSG_IF_RECEIVER);
      if (!result)
         return(!catch("QC.SendTradeCommand(1)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

      if (result == QC_SEND_MSG_IGNORED) {
         debug("QC.SendTradeCommand(2)  receiver on \""+ qc.TradeCmdChannel +"\" gone");
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
   string file    = TerminalPath() +"\\..\\quickchannel.ini";
   string section = tradeAccount.number;
   string keys[], value;
   int error, iValue, keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StringStartsWithI(keys[i], "TradeCommands.")) {
         value = GetIniString(file, section, keys[i]);
         if (value!="") /*&&*/ if (value!="0") {
            // Channel sollte aktiv sein, testen...
            int result = QC_ChannelHasReceiver(keys[i]);
            if (result == QC_CHECK_RECEIVER_OK)                   // Receiver ist da, Channel ist ok
               break;
            if (result == QC_CHECK_CHANNEL_NONE) {                // orphaned Channeleintrag aus .ini-Datei löschen
               if (!DeleteIniKey(file, section, keys[i]))         // kann auftreten, wenn das TradeTerminal oder der dortige Indikator crashte (z.B. bei Recompile)
                  return(!SetLastError(stdlib.GetLastError()));
               continue;
            }
            if (result == QC_CHECK_RECEIVER_NONE) return(!catch("QC.StartTradeCmdSender(1)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") has no reiver but a sender",          ERR_WIN32_ERROR));
            if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.StartTradeCmdSender(2)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
                                                  return(!catch("QC.StartTradeCmdSender(3)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = unexpected return value: "+ result, ERR_WIN32_ERROR));
         }
      }
   }
   if (i >= keysSize) {                                            // break wurde nicht getriggert
      warn("QC.StartTradeCmdSender(4)  No TradeCommand receiver found. Is the trade terminal running?");
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

   int    hTmp    = hQC.TradeCmdSender;
   string channel = qc.TradeCmdChannel;

   hQC.TradeCmdSender = NULL;
   qc.TradeCmdChannel = "";

   if (!QC_ReleaseSender(hTmp))
      return(!catch("QC.StopTradeCmdSender(1)->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")  error stopping sender", ERR_WIN32_ERROR));

   //debug("QC.StopTradeCmdSender()  sender on \""+ channel +"\" stopped");
   return(true);
}


/**
 * Startet einen QuickChannel-Receiver für TradeCommands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartTradeCmdReceiver() {
   if (hQC.TradeCmdReceiver != NULL) return(true);
   if (!__CHART)                     return(false);

   int hWnd = WindowHandleEx(NULL);
   if (!hWnd) return(false);

   // Channelnamen definieren
   qc.TradeCmdChannel = "TradeCommands.0x"+ IntToHexStr(hWnd);

   // Receiver starten
   hQC.TradeCmdReceiver = QC_StartReceiver(qc.TradeCmdChannel, hWnd);
   if (!hQC.TradeCmdReceiver)
      return(!catch("QC.StartTradeCmdReceiver(1)->MT4iQuickChannel::QC_StartReceiver(channel=\""+ qc.TradeCmdChannel +"\", hWnd=0x"+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));

   //debug("QC.StartTradeCmdReceiver()  receiver on \""+ qc.TradeCmdChannel +"\" started");

   // Channelnamen und -status in .ini-Datei hinterlegen
   string file    = TerminalPath() +"\\..\\quickchannel.ini";
   string section = GetAccountNumber();
   string key     = qc.TradeCmdChannel;
   string value   = "1";
   if (!WritePrivateProfileStringA(section, key, value, file))
      return(!catch("QC.StartTradeCmdReceiver(2)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));

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
      string file    = TerminalPath() +"\\..\\quickchannel.ini";
      string section = GetAccountNumber();
      string key     = qc.TradeCmdChannel;
      if (!DeleteIniKey(file, section, key)) return(!SetLastError(stdlib.GetLastError()));

      // Receiver stoppen
      int    hTmp    = hQC.TradeCmdReceiver;
      string channel = qc.TradeCmdChannel;
      hQC.TradeCmdReceiver   = NULL;                                 // Handle immer zurücksetzen (um mehrfache Stopversuche bei Fehlern zu vermeiden)
      qc.TradeCmdChannel = "";
      if (!QC_ReleaseReceiver(hTmp)) return(!catch("QC.StopTradeCmdReceiver(1)->MT4iQuickChannel::QC_ReleaseReceiver(channel=\""+ channel +"\")  error stopping receiver", ERR_WIN32_ERROR));

      //debug("QC.StopTradeCmdReceiver()  receiver on \""+ channel +"\" stopped");
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
      return(!catch("QC.SendOrderNotification(1)  illegal parameter cid = "+ cid, ERR_ARRAY_INDEX_OUT_OF_RANGE));

   if (!hQC.TradeToLfxSenders[cid]) /*&&*/ if (!QC.StartLfxSender(cid))
      return(false);

   int result = QC_SendMessage(hQC.TradeToLfxSenders[cid], msg, QC_FLAG_SEND_MSG_IF_RECEIVER);
   if (!result)
      return(!catch("QC.SendOrderNotification(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
   return(true);
}


/**
 * Startet einen QuickChannel-Sender für "TradeToLfxTerminal"-Messages. Das LFX-Terminal kann sich über diesen Channel auch selbst Messages schicken.
 *
 * @param  int cid - Currency-ID des zu startenden Channels
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartLfxSender(int cid) {
   if (cid < 1 || cid >= ArraySize(hQC.TradeToLfxSenders))
      return(!catch("QC.StartLfxSender(1)  illegal parameter cid = "+ cid, ERR_ARRAY_INDEX_OUT_OF_RANGE));
   if (hQC.TradeToLfxSenders[cid] > 0)
      return(true);
                                                                     // Channel-Name: "{AccountCompanyId}:{AccountNumber}:LFX.Profit.{Currency}"
   qc.TradeToLfxChannels[cid] = AccountCompanyId(tradeAccount.company) +":"+ tradeAccount.number +":LFX.Profit."+ GetCurrency(cid);
   hQC.TradeToLfxSenders[cid] = QC_StartSender(qc.TradeToLfxChannels[cid]);
   if (!hQC.TradeToLfxSenders[cid])
      return(!catch("QC.StartLfxSender(2)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.TradeToLfxChannels[cid] +"\")", ERR_WIN32_ERROR));

   //debug("QC.StartLfxSender(3)  sender on \""+ qc.TradeToLfxChannels[cid] +"\" started");
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
         int    hTmp    = hQC.TradeToLfxSenders[i];
         string channel = qc.TradeToLfxChannels[i];

         hQC.TradeToLfxSenders[i] = NULL;                            // Handle immer zurücksetzen (um mehrfache Stopversuche bei Fehlern zu vermeiden)
         qc.TradeToLfxChannels[i] = "";

         if (!QC_ReleaseSender(hTmp))
            return(!catch("QC.StopLfxSenders()->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")  error stopping sender", ERR_WIN32_ERROR));
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
   if (hQC.TradeToLfxReceiver != NULL)   return(true);
   if (!__CHART)                         return(false);
   if (!StringEndsWith(Symbol(), "LFX")) return(false);              // kein LFX-Chart

   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(false);        // Channel-Name: "{AccountCompanyId}:{AccountNumber}:LFX.Profit.{Currency}"
   qc.TradeToLfxChannel = AccountCompanyId(tradeAccount.company) +":"+ tradeAccount.number +":LFX.Profit."+ StringLeft(Symbol(), -3);

   hQC.TradeToLfxReceiver = QC_StartReceiver(qc.TradeToLfxChannel, hWnd);
   if (!hQC.TradeToLfxReceiver)
      return(!catch("QC.StartLfxReceiver(1)->MT4iQuickChannel::QC_StartReceiver(channel=\""+ qc.TradeToLfxChannel +"\", hWnd=0x"+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));

   //debug("QC.StartLfxReceiver(2)  receiver on \""+ qc.TradeToLfxChannel +"\" started");
   return(true);
}


/**
 * Stoppt den QuickChannel-Receiver für "TradeToLfxTerminal"-Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopLfxReceiver() {
   if (hQC.TradeToLfxReceiver != NULL) {
      int    hTmp    = hQC.TradeToLfxReceiver;
      string channel = qc.TradeToLfxChannel;

      hQC.TradeToLfxReceiver = NULL;                                 // Handle immer zurücksetzen (um mehrfache Stopversuche bei Fehlern zu vermeiden)
      qc.TradeToLfxChannel   = "";
      if (!QC_ReleaseReceiver(hTmp))
         return(!catch("QC.StopLfxReceiver()->MT4iQuickChannel::QC_ReleaseReceiver(channel=\""+ channel +"\")  error stopping receiver", ERR_WIN32_ERROR));
   }
   return(true);
}


/**
 * Stoppt alle laufenden Sender und Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopChannels() {
   if (!QC.StopLfxSenders())            return(false);
   if (!QC.StopLfxReceiver())           return(false);

   if (!QC.StopTradeCmdSender()  )      return(false);
   if (!QC.StopTradeCmdReceiver())      return(false);
   return(true);
}


/**
 * Dummy-Calls unterdrücken unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int iNulls[];
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


#import "stdlib1.ex4"
   string ArrayPopString(string array[]);
   int    ArrayPushInts(int array[][], int values[]);
   int    GetAccountNumber();
   bool   IntInArray(int haystack[], int needle);
   bool   IsIniKey(string fileName, string section, string key);
#import
