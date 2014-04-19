/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15         @see: stdlib1::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15         Vielfaches von 0.1 von 1 bis 10
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15
 */
#define STRATEGY_ID   102                                            // eindeutige ID der Strategie (Bereich 101-1023)


// Currency-ID's (entsprechen den ID's in stddefine.mqh)
#define CID_AUD       1
#define CID_CAD       2
#define CID_CHF       3
#define CID_EUR       4
#define CID_GBP       5
#define CID_JPY       6
#define CID_NZD       7
#define CID_USD       8


// LFX-Currencies und LFX-QuickChannel-Namen: Arrayindizes stimmen mit Currency-ID's überein
string lfxCurrencies     [] = {"",            "AUD",            "CAD",            "CHF",            "EUR",            "GBP",            "JPY",            "NZD",            "USD"};
string channels.lfxProfit[] = {"", "LFX.Profit.AUD", "LFX.Profit.CAD", "LFX.Profit.CHF", "LFX.Profit.EUR", "LFX.Profit.GBP", "LFX.Profit.JPY", "LFX.Profit.NZD", "LFX.Profit.USD"};


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
int LFX.GetCurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 1-15
}


/**
 * Gibt die Units der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return double - Units
 */
double LFX.GetUnits(int magicNumber) {
   return(magicNumber >> 14 & 0xF / 10.);                            // 4 bit (Bit 15-18) => Bereich 1-15
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.GetInstanceId(int magicNumber) {
   return(magicNumber >> 4 & 0x3FF);                                 // 10 bit (Bit 5-14) => Bereich 1-1023
}


/**
 * Gibt den Position-Counter der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Counter
 */
int LFX.GetCounter(int magicNumber) {
   return(magicNumber & 0xF);                                        // 4 bit (Bit 1-4 ) => Bereich 1-15
}


/**
 * Ermittelt die Orderdetails der angegebenen LFX-Remote-Position.
 *
 * @param  int       account     - AccountNumber der einzulesenden Position
 * @param  int       ticket      - Ticket der LFX-Position (entspricht der MagicNumber der einzelnen Teilpositionen)
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
 * @return int - Erfolgsstatus: +1, wenn die Positionsdaten erfolgreich ermittelt wurden
 *                              -1, wenn keine entsprechende Position gefunden wurde
 *                               0, falls ein Fehler auftrat
 */
int LFX.ReadRemotePosition(int account, int ticket, string &label, int &orderType, double &orderUnits, datetime &openTime, double &openEquity, double &openPrice, double &stopLoss, double &takeProfit, datetime &closeTime, double &closePrice, double &orderProfit, datetime &lastUpdate) {
   string sections[], section, file=StringConcatenate(TerminalPath(), "\\experts\\files\\", ShortAccountCompany(), "\\remote_positions.ini");
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
   //Ticket = Label, OrderType, OrderUnits, OpenTime_GMT, OpenEquity, OpenPrice, StopLoss, TakeProfit, CloseTime_GMT, ClosePrice, Profit, LastUpdate_GMT
   string sValue, values[];
   if (Explode(value, ",", values, NULL) != 12) return(_NULL(catch("LFX.ReadRemotePosition(2)   invalid config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // Label
   sValue = StringTrim(values[0]);
   string _label = sValue;

   // OrderType
   sValue = StringToUpper(StringTrim(values[1]));
   if      (sValue == "L") int _orderType = OP_LONG;
   else if (sValue == "S")     _orderType = OP_SELL;
   else                                         return(_NULL(catch("LFX.ReadRemotePosition(3)   invalid order type \""+ StringTrim(values[1]) +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OrderUnits
   sValue = StringTrim(values[2]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(4)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderUnits = StrToDouble(sValue);
   if (LE(_orderUnits, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(5)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenTime_GMT
   sValue = StringTrim(values[3]);
   if (StringIsDigit(sValue)) datetime _openTime = StrToInteger(sValue);
   else                                _openTime =    StrToTime(sValue);
   if (_openTime <= 0)                          return(_NULL(catch("LFX.ReadRemotePosition(6)   invalid open time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_openTime > TimeGMT())                   return(_NULL(catch("LFX.ReadRemotePosition(7)   invalid open time_gmt \""+ TimeToStr(_openTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   _openTime = GMTToServerTime(_openTime);

   // OpenEquity
   sValue = StringTrim(values[4]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(8)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openEquity = StrToDouble(sValue);
   if (LE(_openEquity, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(9)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenPrice
   sValue = StringTrim(values[5]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(10)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openPrice = StrToDouble(sValue);
   if (LE(_openPrice, 0))                       return(_NULL(catch("LFX.ReadRemotePosition(11)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // StopLoss
   sValue = StringTrim(values[6]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(12)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _stopLoss = StrToDouble(sValue);
   if (LT(_stopLoss, 0))                        return(_NULL(catch("LFX.ReadRemotePosition(13)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // TakeProfit
   sValue = StringTrim(values[7]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(14)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _takeProfit = StrToDouble(sValue);
   if (LT(_takeProfit, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(15)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // CloseTime_GMT
   sValue = StringTrim(values[8]);
   if (StringIsDigit(sValue)) datetime _closeTime = StrToInteger(sValue);
   else                                _closeTime =    StrToTime(sValue);
   if      (_closeTime < 0)                     return(_NULL(catch("LFX.ReadRemotePosition(16)   invalid close time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   else if (_closeTime > 0) {
      if (_closeTime > TimeGMT())               return(_NULL(catch("LFX.ReadRemotePosition(17)   invalid close time_gmt \""+ TimeToStr(_closeTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      _closeTime = GMTToServerTime(_closeTime);
   }

   // ClosePrice
   sValue = StringTrim(values[9]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(18)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _closePrice = StrToDouble(sValue);
   if (LT(_closePrice, 0))                      return(_NULL(catch("LFX.ReadRemotePosition(19)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_closeTime==0 && NE(_closePrice, 0))     return(_NULL(catch("LFX.ReadRemotePosition(20)   close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_closeTime!=0 && EQ(_closePrice, 0))     return(_NULL(catch("LFX.ReadRemotePosition(21)   close time/price mis-match "+ TimeToStr(_closeTime, TIME_FULL) +"/0 in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // Profit
   sValue = StringTrim(values[10]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadRemotePosition(22)   invalid order profit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderProfit = StrToDouble(sValue);

   // LastUpdate_GMT
   sValue = StringTrim(values[11]);
   if (StringIsDigit(sValue)) datetime _lastUpdate = StrToInteger(sValue);
   else                                _lastUpdate =    StrToTime(sValue);
   if (_lastUpdate <= 0)                        return(_NULL(catch("LFX.ReadRemotePosition(23)   invalid last update time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_lastUpdate > TimeGMT())                 return(_NULL(catch("LFX.ReadRemotePosition(24)   invalid last update time_gmt \""+ TimeToStr(_lastUpdate, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   _lastUpdate = GMTToServerTime(_lastUpdate);


   // (2) übergebene Variablen erst nach vollständiger Validierung mit ausgelesenen Daten beschreiben
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
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int    iNull;
   double dNull;
   string sNull;
   LFX.IsMyOrder();
   LFX.GetCounter(NULL);
   LFX.GetCurrencyId(NULL);
   LFX.GetInstanceId(NULL);
   LFX.GetUnits(NULL);
   LFX.ReadRemotePosition(NULL, NULL, sNull, iNull, dNull, iNull, dNull, dNull, dNull, dNull, iNull, dNull, dNull, iNull);
}
