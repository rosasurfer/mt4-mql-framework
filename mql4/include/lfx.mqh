/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15         entspricht stdlib::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15         Vielfaches von 0.1 von 1 bis 10
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15
 */
#define STRATEGY_ID   102                                            // eindeutige ID der Strategie (Bereich 101-1023)


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
 *
 * @return bool
 */
bool LFX.IsMyOrder() {
   return(OrderMagicNumber() >> 22 == STRATEGY_ID);                  // 10 bit (Bit 23-32) => Bereich 101-1023
}


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID, entsprechend stdlib1::GetCurrencyId()
 */
int LFX.CurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 1-15
}


/**
 * Gibt die Units der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return double - Units
 */
double LFX.Units(int magicNumber) {
   return(magicNumber >> 14 & 0xF / 10.);                            // 4 bit (Bit 15-18) => Bereich 1-15
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.InstanceId(int magicNumber) {
   return(magicNumber >> 4 & 0x3FF);                                 // 10 bit (Bit 5-14) => Bereich 1-1023
}


/**
 * Gibt den Position-Counter der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Counter
 */
int LFX.Counter(int magicNumber) {
   return(magicNumber & 0xF);                                        // 4 bit (Bit 1-4 ) => Bereich 1-15
}


/**
 * Ermittelt die Orderdetails der angegebenen LFX-Remote-Position.
 *
 * @param  int       account     - AccountNumber der einzulesenden Position
 * @param  int       ticket      - Ticket der LFX-Position (entspricht der MagicNumber der einzelnen Teilpositionen)
 * @param  string   &symbol      - Variable zur Aufnahme des Symbols
 * @param  string   &label       - Variable zur Aufnahme des Labels
 * @param  int      &orderType   - Variable zur Aufnahme des OrderTypes
 * @param  double   &orderUnits  - Variable zur Aufnahme der OrderUnits
 * @param  datetime &openTime    - Variable zur Aufnahme der OpenTime
 * @param  double   &openEquity  - Variable zur Aufnahme der OpenEquity
 * @param  double   &openPrice   - Variable zur Aufnahme des OpenPrice
 * @param  double   &stopLoss    - Variable zur Aufnahme des StopLoss
 * @param  double   &takeProfit  - Variable zur Aufnahme des TakeProfit
 * @param  datetime &closeTime   - Variable zur Aufnahme der CloseTime
 * @param  double   &closePrice  - Variable zur Aufnahme des ClosePrice
 * @param  double   &orderProfit - Variable zur Aufnahme des OrderProfits
 * @param  datetime &lastUpdate  - Variable zur Aufnahme des Zeitpunkts des letzten Updates
 *
 * @return int - Erfolgsstatus: +1, wenn das Ticket erfolgreich gelesen wurden
 *                              -1, wenn das Ticket nicht gefunden wurde
 *                               0, falls ein Fehler auftrat
 */
int LFX.ReadRemotePosition(int account, int ticket, string &symbol, string &label, int &orderType, double &orderUnits, datetime &openTime, double &openEquity, double &openPrice, double &stopLoss, double &takeProfit, datetime &closeTime, double &closePrice, double &orderProfit, datetime &lastUpdate) {
   string sections[], section, file=TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   for (int i=GetIniSections(file, sections)-1; i >= 0; i--) {
      if (StringEndsWith(sections[i], "."+ account)) {
         section = sections[i];
         break;
      }
   }
   if (!StringLen(section))
      return(-1);

   string value = GetIniString(file, section, ticket, "");
   if (!StringLen(value)) {
      if (IsIniKey(file, section, ticket))      return(_NULL(catch("LFX.ReadRemotePosition(1)   invalid config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      return(-1);
   }


   // (1) .ini-Eintrag auslesen und validieren
   //Ticket = Symbol, Label, OrderType, Units, OpenTime_GMT, OpenEquity, OpenPrice, StopLoss, TakeProfit, CloseTime_GMT, ClosePrice, Profit, LastUpdate_GMT
   string sValue, values[];
   if (Explode(value, ",", values, NULL) != 13) return(_NULL(catch("LFX.ReadRemotePosition(2)   invalid config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // Symbol
   sValue = StringTrim(values[0]);
   string _symbol = sValue;

   // Label
   sValue = StringTrim(values[1]);
   string _label = sValue;

   // OrderType
   int _orderType = StrToOperationType(values[2]);
   if (_orderType == OP_UNDEFINED)              return(_NULL(catch("LFX.ReadRemotePosition(3)   invalid order type \""+ StringTrim(values[1]) +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OrderUnits
   sValue = StringTrim(values[3]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(4)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderUnits = StrToDouble(sValue);
   if (LE(_orderUnits, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(5)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenTime_GMT
   sValue = StringTrim(values[4]);
   if (StringIsDigit(sValue)) datetime _openTime = StrToInteger(sValue);
   else                                _openTime =    StrToTime(sValue);
   if (_openTime <= 0)                          return(_NULL(catch("LFX.ReadRemotePosition(6)   invalid open time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_openTime > TimeGMT())                   return(_NULL(catch("LFX.ReadRemotePosition(7)   invalid open time_gmt \""+ TimeToStr(_openTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   _openTime = GMTToServerTime(_openTime);

   // OpenEquity
   sValue = StringTrim(values[5]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(8)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openEquity = StrToDouble(sValue);
   if (LE(_openEquity, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(9)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenPrice
   sValue = StringTrim(values[6]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(10)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openPrice = StrToDouble(sValue);
   if (LE(_openPrice, 0))                       return(_NULL(catch("LFX.ReadRemotePosition(11)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // StopLoss
   sValue = StringTrim(values[7]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(12)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _stopLoss = StrToDouble(sValue);
   if (LT(_stopLoss, 0))                        return(_NULL(catch("LFX.ReadRemotePosition(13)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // TakeProfit
   sValue = StringTrim(values[8]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(14)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _takeProfit = StrToDouble(sValue);
   if (LT(_takeProfit, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(15)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // CloseTime_GMT
   sValue = StringTrim(values[9]);
   if (StringIsDigit(sValue)) datetime _closeTime = StrToInteger(sValue);
   else                                _closeTime =    StrToTime(sValue);
   if      (_closeTime < 0)                     return(_NULL(catch("LFX.ReadRemotePosition(16)   invalid close time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   else if (_closeTime > 0) {
      if (_closeTime > TimeGMT())               return(_NULL(catch("LFX.ReadRemotePosition(17)   invalid close time_gmt \""+ TimeToStr(_closeTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      _closeTime = GMTToServerTime(_closeTime);
   }

   // ClosePrice
   sValue = StringTrim(values[10]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(18)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _closePrice = StrToDouble(sValue);
   if (LT(_closePrice, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(19)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_closeTime==0 && NE(_closePrice, 0))     return(_NULL(catch("LFX.ReadRemotePosition(20)   close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_closeTime!=0 && EQ(_closePrice, 0))     return(_NULL(catch("LFX.ReadRemotePosition(21)   close time/price mis-match "+ TimeToStr(_closeTime, TIME_FULL) +"/0 in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // Profit
   sValue = StringTrim(values[11]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(22)   invalid order profit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderProfit = StrToDouble(sValue);

   // LastUpdate_GMT
   sValue = StringTrim(values[12]);
   if (StringIsDigit(sValue)) datetime _lastUpdate = StrToInteger(sValue);
   else                                _lastUpdate =    StrToTime(sValue);
   if (_lastUpdate <= 0)                        return(_NULL(catch("LFX.ReadRemotePosition(23)   invalid last update time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_lastUpdate > TimeGMT())                 return(_NULL(catch("LFX.ReadRemotePosition(24)   invalid last update time_gmt \""+ TimeToStr(_lastUpdate, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   _lastUpdate = GMTToServerTime(_lastUpdate);


   // (2) übergebene Variablen erst nach vollständiger erfolgreicher Validierung modifizieren
   symbol      = _symbol;
   label       = _label;
   orderType   = _orderType;
   orderUnits  = _orderUnits;
   openTime    = _openTime;
   openEquity  = _openEquity;
   openPrice   = _openPrice;
   stopLoss    = _stopLoss;
   takeProfit  = _takeProfit;
   closeTime   = _closeTime;
   closePrice  = _closePrice;
   orderProfit = _orderProfit;
   lastUpdate  = _lastUpdate;

   return(1);
}


/**
 * Liest die Instanz-ID's aller offenen LFX-Tickets und den Counter der angegebenen LFX-Währung in die übergebenen Variablen ein.
 *
 * @param  int    account          - AccountNumber
 * @param  string lfxCurrency      - LFX-Währung
 * @param  int   &allInstanceIds[] - Array zur Aufnahme der Instanz-ID's aller offenen Tickets
 * @param  int   &currencyCounter  - Variable zur Aufnahme des Counters der angegebenen LFX-Währung
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.ReadInstanceIdsCounter(int account, string lfxCurrency, int &allInstanceIds[], int &currencyCounter) {
   static bool done = false;
   if (done)                                                          // Rückkehr, falls Positionen bereits eingelesen wurden
      return(true);

   int knownMagics[];
   ArrayResize(knownMagics,    0);
   ArrayResize(allInstanceIds, 0);
   currencyCounter = 0;


   // Accountdetails bestimmen
   string section        = "Accounts";
   string key            = account +".company";
   string accountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(accountCompany)) {
      PlaySound("notify.wav");
      MessageBox("Missing account company setting for account \""+ account +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(!SetLastError(ERR_RUNTIME_ERROR));
   }

   // alle Tickets des Accounts einlesen
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
          section = accountCompany +"."+ account;
   string keys[];
   int keysSize = GetIniKeys(file, section, keys);

   // offene Orders finden und auswerten
   string   symbol="", label="";
   int      ticket, orderType, result;
   double   units, openEquity, openPrice, stopLoss, takeProfit, closePrice, profit;
   datetime openTime, closeTime, lastUpdate;

   for (int i=0; i < keysSize; i++) {
      if (StringIsDigit(keys[i])) {
         ticket = StrToInteger(keys[i]);
         result = LFX.ReadRemotePosition(account, ticket, symbol, label, orderType, units, openTime, openEquity, openPrice, stopLoss, takeProfit, closeTime, closePrice, profit, lastUpdate);
         if (result != 1)                                            // +1, wenn das Ticket erfolgreich gelesen wurden
            return(last_error);                                      // -1, wenn das Ticket nicht gefunden wurde; 0, falls ein Fehler auftrat
         if (closeTime != 0)
            continue;                                                // keine offene Order

         ArrayPushInt(allInstanceIds, LFX.InstanceId(ticket));
         if (symbol == lfxCurrency) {
            if (StringStartsWith(label, "#"))
               label = StringSubstr(label, 1);
            currencyCounter = Max(currencyCounter, StrToInteger(label));
         }
      }
   }

   done = true;                                                      // Erledigt-Flag setzen
   return(!catch("LFX.ReadInstanceIdsCounter()"));
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
   LFX.Counter(NULL);
   LFX.CurrencyId(NULL);
   LFX.InstanceId(NULL);
   LFX.IsMyOrder();
   LFX.ReadDisplayStatus();
   LFX.ReadInstanceIdsCounter(NULL, NULL, iNulls, iNull);
   LFX.ReadRemotePosition(NULL, NULL, sNull, sNull, iNull, dNull, iNull, dNull, dNull, dNull, dNull, iNull, dNull, dNull, iNull);
   LFX.SaveDisplayStatus(NULL);
   LFX.Units(NULL);
}
