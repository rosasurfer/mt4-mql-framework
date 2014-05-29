/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15               entspricht stdlib::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15               Vielfaches von 0.1 von 1 bis 10           // nicht mehr verwendet, alle Referenzen gelöscht
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15                                                         // nicht mehr verwendet, alle Referenzen gelöscht
 */
#define STRATEGY_ID   102                                            // eindeutige ID der Strategie (Bereich 101-1023)


int    lfxAccount;                                                   // LFX-Account: im LFX-Terminal ein TradeAccount, im Trading-Terminal der aktuelle Account
string lfxAccountCurrency;
int    lfxAccountType;
string lfxAccountName;
string lfxAccountCompany;

bool   isLfxInstrument;
string lfxCurrency;
int    lfxCurrencyId;
double lfxChartDeviation;                                            // RealPrice + Deviation = LFX-ChartPrice
int    lfxOrder   [LFX_ORDER.intSize];                               // LFX_ORDER
int    lfxOrders[][LFX_ORDER.intSize];                               // LFX_ORDER[]


/**
 * Initialisiert die internen Variablen zum Zugriff auf den LFX-TradeAccount.
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.InitAccountData() {
   if (lfxAccount > 0)
      return(true);

   int    _account;
   string _accountCurrency;
   int    _accountType;
   string _accountName;
   string _accountCompany;

   bool isLfxInstrument = (StringLeft(Symbol(), 3)=="LFX" || StringRight(Symbol(), 3)=="LFX");

   if (isLfxInstrument) {
      // Daten des TradeAccounts
      string section = "LFX";
      string key     = "MRUTradeAccount";
      //if (This.IsTesting())                            // TODO: Workaround schaffen für Fehler in Indikator::init() bei Terminalstart, wenn Chartfenster noch nicht bereit ist
      //   key = key + ".Tester";                        //       WindowHandle() = 0
      _account = GetLocalConfigInt(section, key, 0);
      if (_account <= 0) {
         string value = GetLocalConfigString(section, key, "");
         if (!StringLen(value)) return(!catch("LFX.InitAccountData(1)   missing trade account setting ["+ section +"]->"+ key,                       ERR_RUNTIME_ERROR));
                                return(!catch("LFX.InitAccountData(2)   invalid trade account setting ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_RUNTIME_ERROR));
      }
   }
   else {
      // Daten des aktuellen Accounts
      _account = GetAccountNumber();
      if (!_account)
         return(!SetLastError(stdlib.GetLastError()));
   }

   // AccountCurrency
   section = "Accounts";
   key     = _account +".currency";
   _accountCurrency = GetGlobalConfigString(section, key, "");
   if (!StringLen(_accountCurrency))  return(!catch("LFX.InitAccountData(3)   missing account currency setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));
   if (!IsCurrency(_accountCurrency)) return(!catch("LFX.InitAccountData(4)   invalid account currency setting ["+ section +"]->"+ key +" = \""+ _accountCurrency +"\"", ERR_RUNTIME_ERROR));
   _accountCurrency = StringToUpper(_accountCurrency);

   // AccountType
   key   = _account +".type";
   value = StringToLower(GetGlobalConfigString(section, key, ""));
   if (!StringLen(value))             return(!catch("LFX.InitAccountData(5)   missing account type setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));
   if      (value == "demo") _accountType = ACCOUNT_TYPE_DEMO;
   else if (value == "real") _accountType = ACCOUNT_TYPE_REAL;
   else                               return(!catch("LFX.InitAccountData(6)   invalid account type setting ["+ section +"]->"+ key +" = \""+ GetGlobalConfigString(section, key, "") +"\"", ERR_RUNTIME_ERROR));

   // AccountName
   section = "Accounts";
   key     = _account +".name";
   _accountName = GetGlobalConfigString(section, key, "");
   if (!StringLen(_accountName))      return(!catch("LFX.InitAccountData(7)   missing account name setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // AccountCompany
   section = "Accounts";
   key     = _account +".company";
   _accountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(_accountCompany))   return(!catch("LFX.InitAccountData(8)   missing account company setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));


   // globale Variablen erst nach vollständiger erfolgreicher Validierung überschreiben
   lfxAccount         = _account;
   lfxAccountCurrency = _accountCurrency;
   lfxAccountType     = _accountType;
   lfxAccountName     = _accountName;
   lfxAccountCompany  = _accountCompany;

   return(true);
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
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
 * @return int - Currency-ID, entsprechend stdlib1::GetCurrencyId()
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
 * Gibt eine LFX-Order des aktuellen Accounts zurück.
 *
 * @param  int ticket - Ticket der zurückzugebenden Order
 * @param  int lo[]   - LFX_ORDER-Struct zur Aufnahme der gelesenen Daten
 *
 * @return int - Erfolgsstatus: +1, wenn die Order erfolgreich gelesen wurden
 *                              -1, wenn die Order nicht gefunden wurde
 *                               0, falls ein anderer Fehler auftrat
 */
int LFX.GetOrder(int ticket, /*LFX_ORDER*/int lo[]) {
   // Parametervaliderung
   if (ticket <= 0) return(!catch("LFX.GetOrder(1)   invalid parameter ticket = "+ ticket, ERR_INVALID_FUNCTION_PARAMVALUE));


   // (1) Orderdaten lesen
   if (!lfxAccount) /*&&*/ if (!LFX.InitAccountData())
      return(NULL);
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = StringConcatenate(lfxAccountCompany, ".", lfxAccount);
   string key     = ticket;
   string value   = GetIniString(file, section, key, "");
   if (!StringLen(value)) {
      if (IsIniKey(file, section, key)) return(!catch("LFX.GetOrder(2)   invalid order entry ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_RUNTIME_ERROR));
                                        return(-1);                  // Ticket nicht gefunden
   }


   // (2) Orderdaten validieren
   //Ticket = Symbol, Label, OrderType, Units, OpenEquity, (-)OpenTime, OpenPrice, OpenPriceTime, StopLoss, StopLossTime, TakeProfit, TakeProfitTime, (-)CloseTime, ClosePrice, Profit, LfxDeviation, Version
   string sValue, values[];
   if (Explode(value, ",", values, NULL) != 17)  return(!catch("LFX.GetOrder(3)   invalid order entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // Label
   string _label = StringTrim(values[1]);

   // OrderType
   sValue = StringTrim(values[2]);
   int _orderType = StrToOperationType(sValue);
   if (!IsTradeOperation(_orderType))            return(!catch("LFX.GetOrder(4)   invalid order type \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderUnits
   sValue = StringTrim(values[3]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(5)   invalid unit size \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderUnits = StrToDouble(sValue);
   if (_orderUnits <= 0)                         return(!catch("LFX.GetOrder(6)   invalid unit size \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenEquity
   sValue = StringTrim(values[4]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(7)   invalid open equity \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openEquity = StrToDouble(sValue);
   if (!IsPendingTradeOperation(_orderType))
      if (_openEquity <= 0)                      return(!catch("LFX.GetOrder(8)   invalid open equity \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenTime
   sValue = StringTrim(values[5]);
   if      (StringIsInteger(sValue)) datetime _openTime =  StrToInteger(sValue);
   else if (StringStartsWith(sValue, "-"))    _openTime = -StrToTime(StringSubstr(sValue, 1));
   else                                       _openTime =  StrToTime(sValue);
   if (!_openTime)                               return(!catch("LFX.GetOrder(9)   invalid open time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (Abs(_openTime) > mql.GetSystemTime())     return(!catch("LFX.GetOrder(10)   invalid open time \""+ TimeToStr(Abs(_openTime), TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenPrice
   sValue = StringTrim(values[6]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(11)   invalid open price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openPrice = StrToDouble(sValue);
   if (_openPrice <= 0)                          return(!catch("LFX.GetOrder(12)   invalid open price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenPriceTime
   sValue = StringTrim(values[7]);
   if (StringIsDigit(sValue)) datetime _openPriceTime = StrToInteger(sValue);
   else                                _openPriceTime =    StrToTime(sValue);
   if      (_openPriceTime < 0)                  return(!catch("LFX.GetOrder(13)   invalid open-price time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_openPriceTime > 0)
      if (_openPriceTime > mql.GetSystemTime())  return(!catch("LFX.GetOrder(14)   invalid open-price time \""+ TimeToStr(_openPriceTime, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // StopLoss
   sValue = StringTrim(values[8]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(15)   invalid stoploss \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _stopLoss = StrToDouble(sValue);
   if (_stopLoss < 0)                            return(!catch("LFX.GetOrder(16)   invalid stoploss \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // StopLossTime
   sValue = StringTrim(values[9]);
   if (StringIsDigit(sValue)) datetime _stopLossTime = StrToInteger(sValue);
   else                                _stopLossTime =    StrToTime(sValue);
   if      (_stopLossTime < 0)                   return(!catch("LFX.GetOrder(17)   invalid stoploss time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_stopLossTime > 0)
      if (_stopLossTime > mql.GetSystemTime())   return(!catch("LFX.GetOrder(18)   invalid stoploss time \""+ TimeToStr(_stopLossTime, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // TakeProfit
   sValue = StringTrim(values[10]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(19)   invalid takeprofit \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _takeProfit = StrToDouble(sValue);
   if (_takeProfit < 0)                          return(!catch("LFX.GetOrder(20)   invalid takeprofit \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // TakeProfitTime
   sValue = StringTrim(values[11]);
   if (StringIsDigit(sValue)) datetime _takeProfitTime = StrToInteger(sValue);
   else                                _takeProfitTime =    StrToTime(sValue);
   if      (_takeProfitTime < 0)                 return(!catch("LFX.GetOrder(21)   invalid takeprofit time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_takeProfitTime > 0)
      if (_takeProfitTime > mql.GetSystemTime()) return(!catch("LFX.GetOrder(22)   invalid takeprofit time \""+ TimeToStr(_takeProfitTime, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // CloseTime
   sValue = StringTrim(values[12]);
   if      (StringIsInteger(sValue)) datetime _closeTime =  StrToInteger(sValue);
   else if (StringStartsWith(sValue, "-"))    _closeTime = -StrToTime(StringSubstr(sValue, 1));
   else                                       _closeTime =  StrToTime(sValue);
   if (Abs(_closeTime) > mql.GetSystemTime())    return(!catch("LFX.GetOrder(23)   invalid close time \""+ TimeToStr(Abs(_closeTime), TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // ClosePrice
   sValue = StringTrim(values[13]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(24)   invalid close price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _closePrice = StrToDouble(sValue);
   if (_closePrice < 0)                          return(!catch("LFX.GetOrder(25)   invalid close price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (!_closeTime && _closePrice)               return(!catch("LFX.GetOrder(26)   close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_closeTime > 0 && !_closePrice)           return(!catch("LFX.GetOrder(27)   close time/price mis-match \""+ TimeToStr(_closeTime, TIME_FULL) +"\"/0 in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderProfit
   sValue = StringTrim(values[14]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(28)   invalid order profit \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderProfit = StrToDouble(sValue);

   // LfxDeviation
   sValue = StringTrim(values[15]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(29)   invalid LFX deviation \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _lfxDeviation = StrToDouble(sValue);

   // Version
   sValue = StringTrim(values[16]);
   if (StringIsDigit(sValue)) datetime _version = StrToInteger(sValue);
   else                                _version =    StrToTime(sValue);
   if (_version <= 0)                            return(!catch("LFX.GetOrder(30)   invalid last update time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_version > mql.GetSystemTime())           return(!catch("LFX.GetOrder(31)   invalid version time \""+ TimeToStr(_version, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));


   // (3) Orderdaten in übergebenes Array schreiben (erst nach vollständiger erfolgreicher Validierung)
   InitializeByteBuffer(lo, LFX_ORDER.size);

   lo.setTicket        (lo,  ticket        );                        // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
   lo.setDeviation     (lo, _lfxDeviation  );                        // LFX-Deviation immer vor den Preisen
   lo.setType          (lo, _orderType     );
   lo.setUnits         (lo, _orderUnits    );
   lo.setLots          (lo,  NULL          );
   lo.setOpenEquity    (lo, _openEquity    );
   lo.setOpenTime      (lo, _openTime      );
   lo.setOpenPriceLfx  (lo, _openPrice     );
   lo.setOpenPriceTime (lo, _openPriceTime );
   lo.setStopLossLfx   (lo, _stopLoss      );
   lo.setStopLossTime  (lo, _stopLossTime  );
   lo.setTakeProfitLfx (lo, _takeProfit    );
   lo.setTakeProfitTime(lo, _takeProfitTime);
   lo.setCloseTime     (lo, _closeTime     );
   lo.setClosePriceLfx (lo, _closePrice    );
   lo.setProfit        (lo, _orderProfit   );
   lo.setComment       (lo, _label         );
   lo.setVersion       (lo, _version       );

   return(!catch("LFX.GetOrder(32)"));
}


// OrderType-Flags für LFX.GetOrders()
#define OF_OPEN                1
#define OF_CLOSED              2
#define OF_PENDINGORDER        4
#define OF_OPENPOSITION        8
#define OF_PENDINGPOSITION    16


/**
 * Gibt mehrere LFX-Orders des aktuellen Accounts zurück.
 *
 * @param  string currency   - LFX-Währung der Orders (default: alle Währungen)
 * @param  int    fSelection - Kombination von Selection-Flags (default: alle Orders werden zurückgegeben)
 *                             OF_OPEN            - gibt alle offenen Orders zurück (Pending-Orders und offene Positionen)
 *                             OF_CLOSED          - gibt alle geschlossenen Orders zurück (Trade History)
 *                             OF_PENDINGORDER    - gibt alle herkömmlichen Pending-Orders zurück (OP_BUYLIMIT, OP_BUYSTOP, OP_SELLLIMIT, OP_SELLSTOP)
 *                             OF_OPENPOSITION    - gibt alle offenen Positionen zurück
 *                             OF_PENDINGPOSITION - gibt alle offenen Positionen mit wartendem StopLoss oder TakeProfit zurück
 * @param  int    los[]      - LFX_ORDER[]-Array zur Aufnahme der gelesenen Daten
 *
 * @return int - Anzahl der zurückgegebenen Orders oder -1, falls ein Fehler auftrat
 */
int LFX.GetOrders(string currency, int fSelection, /*LFX_ORDER*/int los[][]) {
   // (1) Parametervaliderung
   int currencyId = 0;                                                     // 0: alle Währungen
   if (currency == "0")                                                    // (string) NULL
      currency = "";

   if (StringLen(currency) > 0) {
      currencyId = GetCurrencyId(currency);
      if (!currencyId)
         return(_int(-1, SetLastError(stdlib.GetLastError())));
   }

   if (!fSelection)                                                        // ohne Angabe wird alles zurückgeben
      fSelection |= OF_OPEN | OF_CLOSED;
   if ((fSelection & OF_PENDINGORDER) && (fSelection & OF_OPENPOSITION))   // sind OF_PENDINGORDER und OF_OPENPOSITION gesetzt, werden alle OF_OPEN zurückgegeben
      fSelection |= OF_OPEN;

   ArrayResize(los, 0);
   int error = InitializeByteBuffer(los, LFX_ORDER.size);                  // validiert Dimensionierung
   if (IsError(error))
      return(_int(-1, SetLastError(error)));


   // (2) alle Tickets einlesen
   if (!lfxAccount) /*&&*/ if (!LFX.InitAccountData())
      return(-1);
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = StringConcatenate(lfxAccountCompany, ".", lfxAccount);
   string keys[];
   int keysSize = GetIniKeys(file, section, keys);


   // (3) Orders nacheinander einlesen und gegen Currency und Selektionflags prüfen
   int /*LFX_ORDER*/lo[];

   for (int i=0; i < keysSize; i++) {
      int ticket = StrToInteger(keys[i]);
      if (currencyId != 0)
         if (LFX.CurrencyId(ticket) != currencyId)
            continue;

      // falls ein Currency-Filter angegeben ist, sind hier alle Tickets gefiltert
      int result = LFX.GetOrder(ticket, lo);
      if (result != 1) {
         if (!result)                                                      // -1, wenn das Ticket nicht gefunden wurde
            return(-1);                                                    //  0, falls ein anderer Fehler auftrat
         return(_int(-1, catch("LFX.GetOrders(1)->LFX.GetOrder(ticket="+ ticket +")   order not found", ERR_RUNTIME_ERROR)));
      }

      bool match = false;
      while (true) {
         if (lo.IsClosed(lo)) {
            match = (fSelection & OF_CLOSED);
            break;
         }
         // ab hier immer offene Order
         if (fSelection & OF_OPEN && 1) {
            match = true;
            break;
         }
         if (lo.IsPending(lo)) {
            match = (fSelection & OF_PENDINGORDER);
            break;
         }
         // ab hier immer offene Position
         if (fSelection & OF_OPENPOSITION && 1) {
            match = true;
            break;
         }
         if (fSelection & OF_PENDINGPOSITION && 1)
            match = (lo.StopLoss(lo) || lo.TakeProfit(lo));
         break;
      }
      if (match)
         ArrayPushIntArray(los, lo);                                 // bei Match Order an übergebenes LFX_ORDER-Array anfügen
   }
   ArrayResize(keys, 0);
   ArrayResize(lo,   0);

   if (!catch("LFX.GetOrders(2)"))
      return(ArrayRange(los, 0));
   return(-1);
}


/**
 * Speichert eine LFX-Order in der .ini-Datei des aktuellen Accounts.
 *
 * @param  LFX_ORDER los[] - ein einzelnes oder ein Array von LFX_ORDER-Structs
 * @param  int       index - Arrayindex der zu speichernden Order, wenn los[] ein Array von LFX_ORDER-Structs ist.
 *                           Der Parameter wird ignoriert, wenn los[] ein einzelnes Struct ist.
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.SaveOrder(/*LFX_ORDER*/int los[], int index=NULL) {
   // (1) übergebene Order in eine einzelne Order umkopieren (Parameter los[] kann unterschiedliche Dimensionen haben)
   int dims = ArrayDimension(los); if (dims > 2)   return(!catch("LFX.SaveOrder(1)   invalid dimensions of parameter los = "+ dims, ERR_INCOMPATIBLE_ARRAYS));

   /*LFX_ORDER*/int lo[]; ArrayResize(lo, LFX_ORDER.intSize);
   if (dims == 1) {
      // Parameter los[] ist einzelne Order
      if (ArrayRange(los, 0) != LFX_ORDER.intSize) return(!catch("LFX.SaveOrder(2)   invalid size of parameter los["+ ArrayRange(los, 0) +"]", ERR_INCOMPATIBLE_ARRAYS));
      ArrayCopy(lo, los);
   }
   else {
      // Parameter los[] ist Order-Array
      if (ArrayRange(los, 1) != LFX_ORDER.intSize) return(!catch("LFX.SaveOrder(3)   invalid size of parameter los["+ ArrayRange(los, 0) +"]["+ ArrayRange(los, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));
      int losSize = ArrayRange(los, 0);
      if (index < 0 || index > losSize-1)          return(!catch("LFX.SaveOrder(4)   invalid parameter index = "+ index, ERR_ARRAY_INDEX_OUT_OF_RANGE));
      CopyMemory(GetIntsAddress(los)+ index*LFX_ORDER.intSize*4, GetIntsAddress(lo), LFX_ORDER.intSize*4);
   }


   // (2) parallele Änderungen erkennen: zu speichernde Version mit letzter gespeicherter Version vergleichen
   /*LFX_ORDER*/int lastVersion[], ticket=lo.Ticket(lo);

   int result = LFX.GetOrder(ticket, lastVersion);
   if (!result) return(false);
   if (result > 0)
      if (lo.Version(lastVersion) > lo.Version(lo))
         return(!catch("LFX.SaveOrder(5)   concurrent modification of #"+ ticket +" (expected version \""+ TimeToStr(lo.Version(lo), TIME_FULL) +"\", found version \""+ TimeToStr(lo.Version(lastVersion), TIME_FULL) +"\")", ERR_CONCURRENT_MODIFICATION));

   datetime newVersion = TimeGMT();


   // (3) Daten formatieren
   //Ticket = Symbol, Label, OrderType, Units, OpenEquity, OpenTime, OpenPrice, OpenPriceTime, StopLoss, StopLossTime, TakeProfit, TakeProfitTime, CloseTime, ClosePrice, Profit, LfxDeviation, Version
   string sSymbol         =                          lo.Currency      (lo);
   string sLabel          =                          lo.Comment       (lo);                                                                                               sLabel          = StringRightPad(sLabel         ,  9, " ");
   string sOperationType  = OperationTypeDescription(lo.Type          (lo));                                                                                              sOperationType  = StringRightPad(sOperationType , 10, " ");
   string sUnits          =              NumberToStr(lo.Units         (lo), ".+");                                                                                        sUnits          = StringLeftPad (sUnits         ,  5, " ");
   string sOpenEquity     =                ifString(!lo.OpenEquity    (lo), "0", DoubleToStr(lo.OpenEquity(lo), 2));                                                      sOpenEquity     = StringLeftPad (sOpenEquity    , 10, " ");
   string sOpenTime       =                 ifString(lo.OpenTime      (lo) < 0, "-", "") + TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL);                                    sOpenTime       = StringLeftPad (sOpenTime      , 20, " ");
   string sOpenPriceLfx   =              DoubleToStr(lo.OpenPriceLfx  (lo), lo.Digits(lo));                                                                               sOpenPriceLfx   = StringLeftPad (sOpenPriceLfx  ,  9, " ");
   string sOpenPriceTime  =                ifString(!lo.OpenPriceTime (lo), "0", TimeToStr(lo.OpenPriceTime(lo), TIME_FULL));                                             sOpenPriceTime  = StringLeftPad (sOpenPriceTime , 19, " ");
   string sStopLossLfx    =                ifString(!lo.StopLossLfx   (lo), "0", DoubleToStr(lo.StopLossLfx(lo),   lo.Digits(lo)));                                       sStopLossLfx    = StringLeftPad (sStopLossLfx   ,  7, " ");  // "StopLos"
   string sStopLossTime   =                ifString(!lo.StopLossTime  (lo), "0", TimeToStr(lo.StopLossTime(lo), TIME_FULL));                                              sStopLossTime   = StringLeftPad (sStopLossTime  , 19, " ");
   string sTakeProfitLfx  =                ifString(!lo.TakeProfitLfx (lo), "0", DoubleToStr(lo.TakeProfitLfx(lo), lo.Digits(lo)));                                       sTakeProfitLfx  = StringLeftPad (sTakeProfitLfx ,  7, " ");  // "TakePro"
   string sTakeProfitTime =                ifString(!lo.TakeProfitTime(lo), "0", TimeToStr(lo.TakeProfitTime(lo), TIME_FULL));                                            sTakeProfitTime = StringLeftPad (sTakeProfitTime, 19, " ");
   string sCloseTime      =                 ifString(lo.CloseTime     (lo) < 0, "-", "") + ifString(!lo.CloseTime(lo), "0", TimeToStr(Abs(lo.CloseTime(lo)), TIME_FULL)); sCloseTime      = StringLeftPad (sCloseTime     , 20, " ");
   string sClosePriceLfx  =                ifString(!lo.ClosePriceLfx (lo), "0", DoubleToStr(lo.ClosePriceLfx(lo), lo.Digits(lo)));                                       sClosePriceLfx  = StringLeftPad (sClosePriceLfx , 10, " ");
   string sProfit         =                ifString(!lo.Profit        (lo), "0", DoubleToStr(lo.Profit(lo), 2));                                                          sProfit         = StringLeftPad (sProfit        ,  7, " ");
   string sDeviation      =                ifString(!lo.Deviation     (lo), "0", DoubleToStr(lo.Deviation(lo), lo.Digits(lo)));                                           sDeviation      = StringLeftPad (sDeviation     ,  9, " ");
   string sVersion        = TimeToStr(newVersion, TIME_FULL);


   // (4) Daten schreiben
   if (!lfxAccount) /*&&*/ if (!LFX.InitAccountData())
      return(false);
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = StringConcatenate(lfxAccountCompany, ".", lfxAccount);
   string key     = ticket;
   string value   = StringConcatenate(sSymbol, ", ", sLabel, ", ", sOperationType, ", ", sUnits, ", ", sOpenEquity, ", ", sOpenTime, ", ", sOpenPriceLfx, ", ", sOpenPriceTime, ", ", sStopLossLfx, ", ", sStopLossTime, ", ", sTakeProfitLfx, ", ", sTakeProfitTime, ", ", sCloseTime, ", ", sClosePriceLfx, ", ", sProfit, ", ", sDeviation, ", ", sVersion);

   if (!WritePrivateProfileStringA(section, key, " "+ value, file))
      return(!catch("LFX.SaveOrder(6)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\", fileName=\""+ file +"\")", win32.GetLastError(ERR_WIN32_ERROR)));


   // (5) Version der übergebenen Order aktualisieren
   if (dims == 1) lo.setVersion(los,        newVersion);             // Parameter los[] ist einzelne Order
   else          los.setVersion(los, index, newVersion);             // Parameter los[] ist Order-Array
   return(true);
}


/**
 * Liest den im Chart gespeicherten aktuellen Anzeigestatus aus.
 *
 * @return bool - Status: ON/OFF
 */
bool LFX.ReadDisplayStatus() {
   string label = __NAME__ +".status";
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Speichert den angegebenen Anzeigestatus im Chart.
 *
 * @param  bool status - Status
 *
 * @return int - Fehlerstatus
 */
int LFX.SaveDisplayStatus(bool status) {
   string label = __NAME__ +".status";

   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_XDISTANCE, -1000);                   // Label in unsichtbaren Bereich setzen
   ObjectSetText(label, ""+ status, 0);

   return(catch("LFX.SaveDisplayStatus()"));
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int    iNull, iNulls[];
   double dNull;
   string sNull;
   LFX.CurrencyId(NULL);
   LFX.GetOrder(NULL, iNulls);
   LFX.GetOrders(NULL, NULL, iNulls);
   LFX.InitAccountData();
   LFX.InstanceId(NULL);
   LFX.IsMyOrder();
   LFX.ReadDisplayStatus();
   LFX.SaveDisplayStatus(NULL);
   LFX.SaveOrder(iNulls, NULL);
   LFX_ORDER.toStr(iNulls);
}


#import "stdlib1.ex4"
   int      ArrayPushIntArray(int array[][], int values[]);
   string   BufferCharsToStr(int buffer[], int from, int length);
   int      GetAccountNumber();
   string   GetCurrency(int id);
   int      GetCurrencyId(string currency);
   string   GetGlobalConfigString(string section, string key, string defaultValue);
   int      GetIniKeys(string fileName, string section, string names[]);
   string   GetIniString(string fileName, string section, string key, string defaultValue);
   int      GetLocalConfigInt(string section, string key, int defaultValue);
   string   GetLocalConfigString(string section, string key, string defaultValue);
   int      InitializeByteBuffer(int buffer[], int length);
   bool     IsIniKey(string fileName, string section, string key);
   bool     IsPendingTradeOperation(int value);
   bool     IsTradeOperation(int value);
   string   JoinStrings(string array[], string separator);
   datetime mql.GetSystemTime();
   string   NumberToStr(double number, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr(int type);
   bool     StringIsDigit(string value);
   bool     StringIsInteger(string value);
   bool     StringIsNumeric(string value);
   string   StringLeftPad(string input, int length, string pad_string);
   string   StringReplace.Recursive(string object, string search, string replace);
   bool     StringStartsWith(string object, string prefix);
   string   StringToLower(string value);
   string   StringTrim(string value);
   int      StrToOperationType(string value);
   datetime TimeGMT();
#import "MetaQuotes2.ex4"
   int      GetIntsAddress(int array[]);
#import
