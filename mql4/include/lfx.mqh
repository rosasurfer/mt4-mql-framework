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


int    lfxAccount;                                                   // LFX-Account: im LFX-Terminal ein Remote-Account, im Trading-terminal der aktuelle Account
string lfxAccountCompany;
int    lfxAccountType;


/**
 * Überprüft bzw. initialisiert die internen Accountvariablen zum Zugriff auf LFX-Orders.
 *
 * @return bool - ob die ermittelten Daten gültig sind
 */
bool LFX.CheckAccount() {
   if (lfxAccount > 0)
      return(true);

   int    _account;
   string _accountCompany;
   int    _accountType;

   bool isLfxChart = (StringLeft(Symbol(), 3)=="LFX" || StringRight(Symbol(), 3)=="LFX");

   if (isLfxChart) {
      // Daten des Remote-Accounts
      string section = "LFX";
      string key     = "MRURemoteAccount";
      _account = GetLocalConfigInt(section, key, 0);
      if (_account <= 0) {
         string value = GetLocalConfigString(section, key, "");
         if (!StringLen(value)) return(!catch("LFX.CheckAccount(1)   missing remote account setting ["+ section +"]->"+ key,                       ERR_RUNTIME_ERROR));
                                return(!catch("LFX.CheckAccount(2)   invalid remote account setting ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_RUNTIME_ERROR));
      }
   }
   else {
      // Daten des aktuellen Accounts
      _account = GetAccountNumber();
      if (!_account) return(!SetLastError(stdlib_GetLastError()));
   }

   // AccountCompany
   section = "Accounts";
   key     = _account +".company";
   _accountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(_accountCompany)) return(!catch("LFX.CheckAccount(3)   missing account company setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // AccountType
   key   = _account +".type";
   value = StringToLower(GetGlobalConfigString(section, key, ""));
   if (!StringLen(value)) return(!catch("LFX.CheckAccount(4)   missing account type setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));
   if      (value == "demo") _accountType = ACCOUNT_TYPE_DEMO;
   else if (value == "real") _accountType = ACCOUNT_TYPE_REAL;
   else return(!catch("LFX.CheckAccount(5)   invalid account type setting ["+ section +"]->"+ key +" = \""+ GetGlobalConfigString(section, key, "") +"\"", ERR_RUNTIME_ERROR));

   // globale Variablen erst nach vollständiger erfolgreicher Validierung überschreiben
   lfxAccount        = _account;
   lfxAccountCompany = _accountCompany;
   lfxAccountType    = _accountType;

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
 * MQL4 structure LFX_ORDER
 *
 * struct LFX_ORDER {
 *    int  ticket;            //   4         lo[ 0]      // Ticket, enthält Strategy- und Currency-ID
 *    int  type;              //   4         lo[ 1]      // Operation-Type
 *    int  units;             //   4         lo[ 2]      // Order-Units in Zehnteln einer Unit
 *    int  lots;              //   4         lo[ 3]      // Ordervolumen in Hundertsteln eines Lots USD
 *    int  openTime;          //   4         lo[ 4]      // OpenTime, GMT
 *    int  openPrice;         //   4         lo[ 5]      // OpenPrice in Points
 *    int  openEquity;        //   4         lo[ 6]      // Equity zum Open-Zeitpunkt in Hundertsteln der Account-Währung (inkl. unrealisierter Verluste, exkl. unrealisierter Gewinne)
 *    int  stopLoss;          //   4         lo[ 7]      // StopLoss-Preis in Points
 *    int  takeProfit;        //   4         lo[ 8]      // TakeProfit-Preis in Points
 *    int  closeTime;         //   4         lo[ 9]      // CloseTime, GMT
 *    int  closePrice;        //   4         lo[10]      // ClosePrice in Points
 *    int  profit;            //   4         lo[11]      // Profit in Hundertsteln der Account-Währung (realisiert oder unrealisiert)
 *    char szComment[32];     //  32         lo[12]      // Orderkommentar, bis zu 31 Zeichen + <NUL>
 *    int  version;           //   4         lo[20]      // Zeitpunkt der letzten Aktualisierung, GMT
 * } lo;                      //  84 byte = int[21]
 */

// Getter
int      lo.Ticket     (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 0]);                                 }
int      lo.Type       (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 1]);                                 }
double   lo.Units      (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 2]/ 10., 1));                        }
double   lo.Lots       (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 3]/100., 2));                        }
datetime lo.OpenTime   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 4]);                                 }
double   lo.OpenPrice  (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 5]/MathPow(10, digits), digits));    }
double   lo.OpenEquity (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 6]/100., 2));                        }
double   lo.StopLoss   (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 7]/MathPow(10, digits), digits));    }
double   lo.TakeProfit (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 8]/MathPow(10, digits), digits));    }
datetime lo.CloseTime  (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 9]);                                 }
double   lo.ClosePrice (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[10]/MathPow(10, digits), digits));    }
double   lo.Profit     (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[11]/100., 2));                        }
string   lo.Comment    (/*LFX_ORDER*/int lo[]         ) {                                 return(BufferCharsToStr(lo, 48, 32));                            }
datetime lo.Version    (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[20]);                                 }
int      lo.Digits     (/*LFX_ORDER*/int lo[]         ) { /*Helper*/        return(ifInt(LFX.CurrencyId(lo.Ticket(lo))==CID_JPY, 3, 5));                   }
string   lo.Currency   (/*LFX_ORDER*/int lo[]         ) { /*Helper*/  return(GetCurrency(LFX.CurrencyId(lo.Ticket(lo))));                                  }
int      lo.CurrencyId (/*LFX_ORDER*/int lo[]         ) { /*Helper*/              return(LFX.CurrencyId(lo.Ticket(lo)));                                   }

int      los.Ticket    (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 0]);                              }
int      los.Type      (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 1]);                              }
double   los.Units     (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 2]/ 10., 1));                     }
double   los.Lots      (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 3]/100., 2));                     }
datetime los.OpenTime  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 4]);                              }
double   los.OpenPrice (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 5]/MathPow(10, digits), digits)); }
double   los.OpenEquity(/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 6]/100., 2));                     }
double   los.StopLoss  (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 7]/MathPow(10, digits), digits)); }
double   los.TakeProfit(/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 8]/MathPow(10, digits), digits)); }
datetime los.CloseTime (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 9]);                              }
double   los.ClosePrice(/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][10]/MathPow(10, digits), digits)); }
double   los.Profit    (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][11]/100., 2));                     }
string   los.Comment   (/*LFX_ORDER*/int lo[][], int i) {                                 return(BufferCharsToStr(lo, ArrayRange(lo, 1)*i*4 + 48, 32));    }
datetime los.Version   (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][20]);                              }
int      los.Digits    (/*LFX_ORDER*/int lo[][], int i) { /*Helper*/       return(ifInt(LFX.CurrencyId(los.Ticket(lo, i))==CID_JPY, 3, 5));                }
string   los.Currency  (/*LFX_ORDER*/int lo[][], int i) { /*Helper*/ return(GetCurrency(LFX.CurrencyId(los.Ticket(lo, i))));                               }
int      los.CurrencyId(/*LFX_ORDER*/int lo[][], int i) { /*Helper*/             return(LFX.CurrencyId(los.Ticket(lo, i)));                                }

// Setter
int      lo.setTicket     (/*LFX_ORDER*/int &lo[],          int      ticket    ) { lo[ 0]    = ticket;                                                 return(ticket    ); }
int      lo.setType       (/*LFX_ORDER*/int &lo[],          int      type      ) { lo[ 1]    = type;                                                   return(type      ); }
double   lo.setUnits      (/*LFX_ORDER*/int &lo[],          double   units     ) { lo[ 2]    = MathRound(units *  10);                                 return(units     ); }
double   lo.setLots       (/*LFX_ORDER*/int &lo[],          double   lots      ) { lo[ 3]    = MathRound(lots  * 100);                                 return(lots      ); }
datetime lo.setOpenTime   (/*LFX_ORDER*/int &lo[],          datetime openTime  ) { lo[ 4]    = openTime;                                               return(openTime  ); }
double   lo.setOpenPrice  (/*LFX_ORDER*/int &lo[],          double   openPrice ) { lo[ 5]    = MathRound(openPrice  * MathPow(10, lo.Digits(lo)));     return(openPrice ); }
double   lo.setOpenEquity (/*LFX_ORDER*/int &lo[],          double   openEquity) { lo[ 6]    = MathRound(openEquity * 100);                            return(openEquity); }
double   lo.setStopLoss   (/*LFX_ORDER*/int &lo[],          double   stopLoss  ) { lo[ 7]    = MathRound(stopLoss   * MathPow(10, lo.Digits(lo)));     return(stopLoss  ); }
double   lo.setTakeProfit (/*LFX_ORDER*/int &lo[],          double   takeProfit) { lo[ 8]    = MathRound(takeProfit * MathPow(10, lo.Digits(lo)));     return(takeProfit); }
datetime lo.setCloseTime  (/*LFX_ORDER*/int &lo[],          datetime closeTime ) { lo[ 9]    = closeTime;                                              return(closeTime ); }
double   lo.setClosePrice (/*LFX_ORDER*/int &lo[],          double   closePrice) { lo[10]    = MathRound(closePrice * MathPow(10, lo.Digits(lo)));     return(closePrice); }
double   lo.setProfit     (/*LFX_ORDER*/int &lo[],          double   profit    ) { lo[11]    = MathRound(profit * 100);                                return(profit    ); }
string   lo.setComment    (/*LFX_ORDER*/int  lo[],          string   comment   ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("lo.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetBufferAddress(lo)+48, GetStringAddress(comment), StringLen(comment)+1);                                                               return(comment   ); }
datetime lo.setVersion    (/*LFX_ORDER*/int &lo[],          datetime version   ) { lo[20]    = version;                                                return(version   ); }

int      los.setTicket    (/*LFX_ORDER*/int &lo[][], int i, int      ticket    ) { lo[i][ 0] = ticket;                                                 return(ticket    ); }
int      los.setType      (/*LFX_ORDER*/int &lo[][], int i, int      type      ) { lo[i][ 1] = type;                                                   return(type      ); }
double   los.setUnits     (/*LFX_ORDER*/int &lo[][], int i, double   units     ) { lo[i][ 2] = MathRound(units *  10);                                 return(units     ); }
double   los.setLots      (/*LFX_ORDER*/int &lo[][], int i, double   lots      ) { lo[i][ 3] = MathRound(lots  * 100);                                 return(lots      ); }
datetime los.setOpenTime  (/*LFX_ORDER*/int &lo[][], int i, datetime openTime  ) { lo[i][ 4] = openTime;                                               return(openTime  ); }
double   los.setOpenPrice (/*LFX_ORDER*/int &lo[][], int i, double   openPrice ) { lo[i][ 5] = MathRound(openPrice  * MathPow(10, los.Digits(lo, i))); return(openPrice ); }
double   los.setOpenEquity(/*LFX_ORDER*/int &lo[][], int i, double   openEquity) { lo[i][ 6] = MathRound(openEquity * 100);                            return(openEquity); }
double   los.setStopLoss  (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss  ) { lo[i][ 7] = MathRound(stopLoss   * MathPow(10, los.Digits(lo, i))); return(stopLoss  ); }
double   los.setTakeProfit(/*LFX_ORDER*/int &lo[][], int i, double   takeProfit) { lo[i][ 8] = MathRound(takeProfit * MathPow(10, los.Digits(lo, i))); return(takeProfit); }
datetime los.setCloseTime (/*LFX_ORDER*/int &lo[][], int i, datetime closeTime ) { lo[i][ 9] = closeTime;                                              return(closeTime ); }
double   los.setClosePrice(/*LFX_ORDER*/int &lo[][], int i, double   closePrice) { lo[i][10] = MathRound(closePrice * MathPow(10, los.Digits(lo, i))); return(closePrice); }
double   los.setProfit    (/*LFX_ORDER*/int &lo[][], int i, double   profit    ) { lo[i][11] = MathRound(profit * 100);                                return(profit    ); }
string   los.setComment   (/*LFX_ORDER*/int  lo[][], int i, string   comment   ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("los.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetBufferAddress(lo)+ i*ArrayRange(lo, 1)*4 + 48, GetStringAddress(comment), StringLen(comment)+1);                                      return(comment   ); }
datetime los.setVersion   (/*LFX_ORDER*/int &lo[][], int i, datetime version   ) { lo[i][20] = version;                                                return(version   ); }


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer LFX_ORDER-Strukturen zurück.
 *
 * @param  int  lo[]        - LFX_ORDER
 * @param  bool debugOutput - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string - lesbarer String oder Leerstring, falls ein fehler auftrat
 */
string LFX_ORDER.toStr(/*LFX_ORDER*/int lo[], bool debugOutput=false) {
   int dimensions = ArrayDimension(lo);

   if (dimensions > 2)                                    return(_empty(catch("LFX_ORDER.toStr(1)   too many dimensions of parameter lo = "+ dimensions, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArrayRange(lo, dimensions-1) != LFX_ORDER.intSize) return(_empty(catch("LFX_ORDER.toStr(2)   invalid size of parameter lo ("+ ArrayRange(lo, dimensions-1) +")", ERR_INVALID_FUNCTION_PARAMVALUE)));

   int    digits, pipDigits;
   string priceFormat, line, lines[]; ArrayResize(lines, 0);


   if (dimensions == 1) {
      // lo ist struct LFX_ORDER (eine Dimension)
      digits      = lo.Digits(lo);
      pipDigits   = digits & (~1);
      priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      line        = StringConcatenate("{ticket="    ,                    lo.Ticket    (lo),
                                     ", currency=\"",                    lo.Currency  (lo), "\"",
                                     ", type="      , OperationTypeToStr(lo.Type      (lo)),
                                     ", units="     ,        NumberToStr(lo.Units     (lo), ".+"),
                                     ", lots="      ,        NumberToStr(lo.Lots      (lo), ".+"),
                                     ", openTime="  ,           ifString(lo.OpenTime  (lo), "'"+ TimeToStr(lo.OpenTime(lo), TIME_FULL) +"'", "0"),
                                     ", openPrice=" ,        NumberToStr(lo.OpenPrice (lo), priceFormat),
                                     ", openEquity=",        DoubleToStr(lo.OpenEquity(lo), 2),
                                     ", stopLoss="  ,        NumberToStr(lo.StopLoss  (lo), priceFormat),
                                     ", takeProfit=",        NumberToStr(lo.TakeProfit(lo), priceFormat),
                                     ", closeTime=" ,           ifString(lo.CloseTime (lo), "'"+ TimeToStr(lo.CloseTime(lo), TIME_FULL) +"'", "0"),
                                     ", closePrice=",        NumberToStr(lo.ClosePrice(lo), priceFormat),
                                     ", profit="    ,        DoubleToStr(lo.Profit    (lo), 2),
                                     ", comment=\"" ,                    lo.Comment   (lo), "\"",
                                     ", version="   ,           ifString(lo.Version   (lo), "'"+ TimeToStr(lo.Version(lo), TIME_FULL) +"'", "0"), "}");
      if (debugOutput)
         debug("LFX_ORDER.toStr()   "+ line);
      ArrayPushString(lines, line);
   }
   else {
      // lo ist struct[] LFX_ORDER (zwei Dimensionen)
      int size = ArrayRange(lo, 0);

      for (int i=0; i < size; i++) {
         digits      = los.Digits(lo, i);
         pipDigits   = digits & (~1);
         priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
         line        = StringConcatenate("[", i, "]={ticket="    ,                    los.Ticket    (lo, i),
                                                  ", currency=\"",                    los.Currency  (lo, i), "\"",
                                                  ", type="      , OperationTypeToStr(los.Type      (lo, i)),
                                                  ", units="     ,        NumberToStr(los.Units     (lo, i), ".+"),
                                                  ", lots="      ,        NumberToStr(los.Lots      (lo, i), ".+"),
                                                  ", openTime="  ,           ifString(los.OpenTime  (lo, i), "'"+ TimeToStr(los.OpenTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", openPrice=" ,        NumberToStr(los.OpenPrice (lo, i), priceFormat),
                                                  ", openEquity=",        DoubleToStr(los.OpenEquity(lo, i), 2),
                                                  ", stopLoss="  ,        NumberToStr(los.StopLoss  (lo, i), priceFormat),
                                                  ", takeProfit=",        NumberToStr(los.TakeProfit(lo, i), priceFormat),
                                                  ", closeTime=" ,           ifString(los.CloseTime (lo, i), "'"+ TimeToStr(los.CloseTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", closePrice=",        NumberToStr(los.ClosePrice(lo, i), priceFormat),
                                                  ", profit="    ,        DoubleToStr(los.Profit    (lo, i), 2),
                                                  ", comment=\"" ,                    los.Comment   (lo, i), "\"",
                                                  ", version="   ,           ifString(los.Version   (lo, i), "'"+ TimeToStr(los.Version(lo, i), TIME_FULL) +"'", "0"), "}");
         if (debugOutput)
            debug("LFX_ORDER.toStr()   "+ line);
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("LFX_ORDER.toStr(3)");
   return(output);
}


/**
 * Liest alle offenen LFX-Orders des aktuellen Accounts ein.
 *
 * @param  int los[] - LFX_ORDER[]-Array zur Aufnahme der gelesenen Daten
 *
 * @return int - Anzahl der offenen Orders oder -1, falls ein Fehler auftrat
 */
int LFX.ReadOpenOrders(/*LFX_ORDER*/int los[][]) {
   int losSize = ArrayResize(los, 0);
   int error   = InitializeByteBuffer(los, LFX_ORDER.size);          // validiert die Dimensionierung
   if (IsError(error))
      return(_int(-1, SetLastError(error)));


   // (1) alle Ticket-IDs einlesen
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = lfxAccountCompany +"."+ lfxAccount;
   string keys[];
   int keysSize = GetIniKeys(file, section, keys);


   // (2) Tickets nacheinander einlesen und prüfen
   int      o.ticket, o.type, result;
   string   o.symbol="", o.label ="";
   double   o.units, o.openEquity, o.openPrice, o.stopLoss, o.takeProfit, o.closePrice, o.profit;
   datetime o.openTime, o.closeTime, o.lastUpdate;

   for (int n, i=0; i < keysSize; i++) {
      o.ticket = StrToInteger(keys[i]);
      result   = LFX.ReadTicket(o.ticket, o.symbol, o.label, o.type, o.units, o.openTime, o.openEquity, o.openPrice, o.stopLoss, o.takeProfit, o.closeTime, o.closePrice, o.profit, o.lastUpdate);
      if (result != 1) {
         if (!result)                                                // -1, wenn das Ticket nicht gefunden wurde
            return(-1);                                              //  0, falls ein anderer Fehler auftrat
         return(_int(-1, catch("LFX.ReadOpenOrders(1)->LFX.ReadTicket(ticket="+ o.ticket +")   ticket not found", ERR_RUNTIME_ERROR)));
      }
      if (!o.closeTime) {
         // offene Orders in LFX_ORDER-Array kopieren
         n = losSize;
         losSize++; ArrayResize(los, losSize);
         los.setTicket    (los, n, o.ticket    );                    // Ticket immer zuerst, damit im Struct daraus Currency-ID und Digits ermittelt werden können
         los.setType      (los, n, o.type      );
         los.setUnits     (los, n, o.units     );
         los.setLots      (los, n, 0           );
         los.setOpenTime  (los, n, o.openTime  );
         los.setOpenPrice (los, n, o.openPrice );
         los.setOpenEquity(los, n, o.openEquity);
         los.setStopLoss  (los, n, o.stopLoss  );
         los.setTakeProfit(los, n, o.takeProfit);
         los.setCloseTime (los, n, o.closeTime );
         los.setClosePrice(los, n, o.closePrice);
         los.setProfit    (los, n, o.profit    );
         los.setComment   (los, n, o.label     );
         los.setVersion   (los, n, o.lastUpdate);
      }
   }

   ArrayResize(keys, 0);
   return(losSize);
}


/**
 * Liest das angegebene LFX-Ticket.
 *
 * @param  int       ticket      - LFX-Ticket (entspricht der MagicNumber der Teilpositionen)
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
 *                               0, falls ein anderer Fehler auftrat
 */
int LFX.ReadTicket(int ticket, string &symbol, string &label, int &orderType, double &orderUnits, datetime &openTime, double &openEquity, double &openPrice, double &stopLoss, double &takeProfit, datetime &closeTime, double &closePrice, double &orderProfit, datetime &lastUpdate) {
   // (1) Ticket auslesen
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = lfxAccountCompany +"."+ lfxAccount;
   string key     = ticket;
   string value   = GetIniString(file, section, key, "");
   if (!StringLen(value)) {
      if (IsIniKey(file, section, key))         return(_NULL(catch("LFX.ReadTicket(1)   invalid config value ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      return(-1);                               // Ticket nicht gefunden
   }


   // (2) Ticketdetails validieren
   //Ticket = Symbol, Label, OrderType, OrderUnits, OpenTime_GMT, OpenEquity, OpenPrice, StopLoss, TakeProfit, CloseTime_GMT, ClosePrice, OrderProfit, LastUpdate_GMT
   string sValue, values[];
   if (Explode(value, ",", values, NULL) != 13) return(_NULL(catch("LFX.ReadTicket(2)   invalid config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // Symbol
   sValue = StringTrim(values[0]);
   string _symbol = sValue;

   // Label
   sValue = StringTrim(values[1]);
   string _label = sValue;

   // OrderType
   sValue = StringTrim(values[2]);
   int _orderType = StrToOperationType(sValue);
   if (!IsTradeOperation(_orderType))           return(_NULL(catch("LFX.ReadTicket(3)   invalid order type \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OrderUnits
   sValue = StringTrim(values[3]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(4)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderUnits = StrToDouble(sValue);
   if (_orderUnits <= 0)                        return(_NULL(catch("LFX.ReadTicket(5)   invalid unit size \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenTime_GMT
   sValue = StringTrim(values[4]);
   if (StringIsDigit(sValue)) datetime _openTime = StrToInteger(sValue);
   else                                _openTime =    StrToTime(sValue);
   if (_openTime <= 0)                          return(_NULL(catch("LFX.ReadTicket(6)   invalid open time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_openTime > TimeGMT())                   return(_NULL(catch("LFX.ReadTicket(7)   invalid open time_gmt \""+ TimeToStr(_openTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenEquity
   sValue = StringTrim(values[5]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(8)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openEquity = StrToDouble(sValue);
   if (!IsPendingTradeOperation(_orderType))
      if (_openEquity <= 0)                     return(_NULL(catch("LFX.ReadTicket(9)   invalid open equity \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OpenPrice
   sValue = StringTrim(values[6]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(10)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _openPrice = StrToDouble(sValue);
   if (_openPrice <= 0)                         return(_NULL(catch("LFX.ReadTicket(11)   invalid open price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // StopLoss
   sValue = StringTrim(values[7]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(12)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _stopLoss = StrToDouble(sValue);
   if (_stopLoss < 0)                           return(_NULL(catch("LFX.ReadTicket(13)   invalid stoploss \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // TakeProfit
   sValue = StringTrim(values[8]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(14)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _takeProfit = StrToDouble(sValue);
   if (_takeProfit < 0)                         return(_NULL(catch("LFX.ReadTicket(15)   invalid takeprofit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // CloseTime_GMT
   sValue = StringTrim(values[9]);
   if (StringIsDigit(sValue)) datetime _closeTime = StrToInteger(sValue);
   else                                _closeTime =    StrToTime(sValue);
   if      (_closeTime < 0)                     return(_NULL(catch("LFX.ReadTicket(16)   invalid close time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   else if (_closeTime > 0)
      if (_closeTime > TimeGMT())               return(_NULL(catch("LFX.ReadTicket(17)   invalid close time_gmt \""+ TimeToStr(_closeTime, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // ClosePrice
   sValue = StringTrim(values[10]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(18)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _closePrice = StrToDouble(sValue);
   if (_closePrice < 0)                         return(_NULL(catch("LFX.ReadTicket(19)   invalid close price \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (!_closeTime && _closePrice!=0)           return(_NULL(catch("LFX.ReadTicket(20)   close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_closeTime!=0 && !_closePrice)           return(_NULL(catch("LFX.ReadTicket(21)   close time/price mis-match "+ TimeToStr(_closeTime, TIME_FULL) +"/0 in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

   // OrderProfit
   sValue = StringTrim(values[11]);
   if (!StringIsNumeric(sValue))                return(_NULL(catch("LFX.ReadTicket(22)   invalid order profit \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   double _orderProfit = StrToDouble(sValue);

   // LastUpdate_GMT
   sValue = StringTrim(values[12]);
   if (StringIsDigit(sValue)) datetime _lastUpdate = StrToInteger(sValue);
   else                                _lastUpdate =    StrToTime(sValue);
   if (_lastUpdate <= 0)                        return(_NULL(catch("LFX.ReadTicket(23)   invalid last update time \""+ sValue +"\" in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
   if (_lastUpdate > TimeGMT())                 return(_NULL(catch("LFX.ReadTicket(24)   invalid last update time_gmt \""+ TimeToStr(_lastUpdate, TIME_FULL) +"\" (current time_gmt \""+ TimeToStr(TimeGMT(), TIME_FULL) +"\") in config value ["+ section +"]->"+ ticket +" = \""+ value +"\" in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));


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
 * Schreibt das angegebene LFX-Ticket in die .ini-Datei des angegebenen Accounts.
 *
 * @param  int      ticket
 * @param  string   label
 * @param  int      operationType
 * @param  double   units
 * @param  datetime openTime
 * @param  double   openEquity
 * @param  double   openPrice
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   profit
 * @param  datetime lastUpdate
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.WriteTicket(int ticket, string label, int operationType, double units, datetime openTime, double openEquity, double openPrice, double stopLoss, double takeProfit, datetime closeTime, double closePrice, double profit, datetime lastUpdate) {
   // (1) Parametervalidierung
   if (ticket >> 22 != STRATEGY_ID)        return(!catch("LFX.WriteTicket(1)   invalid parameter ticket = "+ ticket +" (not a LFX ticket)", ERR_INVALID_FUNCTION_PARAMVALUE));
   int lfxId = LFX.CurrencyId(ticket);
   if (lfxId < CID_AUD || lfxId > CID_USD) return(!catch("LFX.WriteTicket(2)   invalid parameter ticket = "+ ticket +" (not a LFX currency ticket="+ lfxId +")", ERR_INVALID_FUNCTION_PARAMVALUE));
   if (label == "0")    // (string) NULL
      label = "";
   if (!IsTradeOperation(operationType))   return(!catch("LFX.WriteTicket(3)   invalid parameter operationType = "+ operationType +" (not a trade operation)", ERR_INVALID_FUNCTION_PARAMVALUE));
   if (units <= 0)                         return(!catch("LFX.WriteTicket(4)   invalid parameter units = "+ NumberToStr(units, ".1+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (openTime <= 0)                      return(!catch("LFX.WriteTicket(5)   invalid parameter openTime = "+ openTime, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (IsPendingTradeOperation(operationType))
      openEquity = NULL;
   else if (openEquity <= 0)               return(!catch("LFX.WriteTicket(6)   invalid parameter openEquity = "+ DoubleToStr(openEquity, 2), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (openPrice <= 0)                     return(!catch("LFX.WriteTicket(7)   invalid parameter openPrice = "+ NumberToStr(openPrice, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (stopLoss < 0)                       return(!catch("LFX.WriteTicket(8)   invalid parameter stopLoss = "+ NumberToStr(stopLoss, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (takeProfit < 0)                     return(!catch("LFX.WriteTicket(9)   invalid parameter takeProfit = "+ NumberToStr(takeProfit, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (closeTime < 0)                      return(!catch("LFX.WriteTicket(10)   invalid parameter closeTime = "+ closeTime, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (closePrice < 0)                     return(!catch("LFX.WriteTicket(11)   invalid parameter closePrice = "+ NumberToStr(closePrice, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (!closeTime && closePrice!=0)        return(!catch("LFX.WriteTicket(12)   invalid parameter closeTime/closePrice: mis-match 0/"+ NumberToStr(closePrice, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));
   if (closeTime!=0 && !closePrice)        return(!catch("LFX.WriteTicket(13)   invalid parameter closeTime/closePrice: mis-match \""+ TimeToStr(closeTime, TIME_FULL) +"\"/0", ERR_INVALID_FUNCTION_PARAMVALUE));
   // profit: immer ok
   if (lastUpdate <= 0)                    return(!catch("LFX.WriteTicket(14)   invalid parameter lastUpdate = "+ lastUpdate, ERR_INVALID_FUNCTION_PARAMVALUE));

   string lfxCurrency = GetCurrency(lfxId);
   int    lfxDigits   = ifInt(lfxId==CID_JPY, 3, 5);


   // (2) Ticketdaten formatieren
   //Ticket = Symbol, Label, TradeOperation, Units, OpenTime_GMT, OpenEquity, OpenPrice, StopLoss, TakeProfit, CloseTime_GMT, ClosePrice, Profit, LastUpdate_GMT
   string sSymbol        = lfxCurrency;
   string sLabel         =                                                                                  StringRightPad(label         ,  9, " ");
   string sOperationType = OperationTypeDescription(operationType);                        sOperationType = StringRightPad(sOperationType, 10, " ");
   string sUnits         = NumberToStr(units, ".+");                                       sUnits         = StringLeftPad (sUnits        ,  5, " ");
   string sOpenTime      = TimeToStr(openTime, TIME_FULL);
   string sOpenEquity    = ifString(!openEquity, "0", DoubleToStr(openEquity, 2));         sOpenEquity    = StringLeftPad(sOpenEquity    ,  7, " ");
   string sOpenPrice     = DoubleToStr(openPrice, lfxDigits);                              sOpenPrice     = StringLeftPad(sOpenPrice     ,  9, " ");
   string sStopLoss      = ifString(!stopLoss,   "0", DoubleToStr(stopLoss,   lfxDigits)); sStopLoss      = StringLeftPad(sStopLoss      ,  8, " ");
   string sTakeProfit    = ifString(!takeProfit, "0", DoubleToStr(takeProfit, lfxDigits)); sTakeProfit    = StringLeftPad(sTakeProfit    , 10, " ");
   string sCloseTime     = ifString(!closeTime,  "0", TimeToStr(closeTime, TIME_FULL));    sCloseTime     = StringLeftPad(sCloseTime     , 19, " ");
   string sClosePrice    = ifString(!closePrice, "0", DoubleToStr(closePrice, lfxDigits)); sClosePrice    = StringLeftPad(sClosePrice    , 10, " ");
   string sProfit        = ifString(!profit,     "0", DoubleToStr(profit, 2));             sProfit        = StringLeftPad(sProfit        ,  7, " ");
   string sLastUpdate    = TimeToStr(lastUpdate, TIME_FULL);


   // (3) Ticketdaten schreiben
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = lfxAccountCompany +"."+ lfxAccount;
   string key     = ticket;
   string value   = sSymbol +", "+ sLabel +", "+ sOperationType +", "+ sUnits +", "+ sOpenTime +", "+ sOpenEquity +", "+ sOpenPrice +", "+ sStopLoss +", "+ sTakeProfit +", "+ sCloseTime +", "+ sClosePrice +", "+ sProfit +", "+ sLastUpdate;

   if (!WritePrivateProfileStringA(section, key, " "+ value, file))
      return(!catch("LFX.WriteTicket(15)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   return(true);
}


/**
 * Liest die Instanz-ID's aller offenen LFX-Tickets und den Counter der angegebenen LFX-Währung in die übergebenen Variablen ein.
 *
 * @param  string  lfxCurrency     - LFX-Währung
 * @param  int    &instanceIds[]   - Array zur Aufnahme der Instanz-ID's aller offenen Tickets
 * @param  int    &currencyCounter - Variable zur Aufnahme des Counters der angegebenen LFX-Währung
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.ReadInstanceIdsCounter(string lfxCurrency, int &instanceIds[], int &currencyCounter) {
   static bool done = false;
   if (done)                                                          // Rückkehr, falls Positionen bereits eingelesen wurden
      return(true);

   int knownMagics[];
   ArrayResize(knownMagics,    0);
   ArrayResize(instanceIds, 0);
   currencyCounter = 0;

   // Ticket-IDs einlesen
   string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
   string section = lfxAccountCompany +"."+ lfxAccount;
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
         result = LFX.ReadTicket(ticket, symbol, label, orderType, units, openTime, openEquity, openPrice, stopLoss, takeProfit, closeTime, closePrice, profit, lastUpdate);
         if (result != 1)                                            // +1, wenn das Ticket erfolgreich gelesen wurden
            return(last_error);                                      // -1, wenn das Ticket nicht gefunden wurde; 0, falls ein anderer Fehler auftrat
         if (closeTime != 0)
            continue;                                                // keine offene Order

         ArrayPushInt(instanceIds, LFX.InstanceId(ticket));
         if (symbol == lfxCurrency) {
            if (StringStartsWith(label, "#"))
               label = StringSubstr(label, 1);
            currencyCounter = Max(currencyCounter, StrToInteger(label));
         }
      }
   }

   done = true;                                                      // Erledigt-Flag setzen
   return(!catch("LFX.ReadInstanceIdsCounter(2)"));
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
   LFX.CheckAccount();
   LFX.Counter(NULL);
   LFX.CurrencyId(NULL);
   LFX.InstanceId(NULL);
   LFX.IsMyOrder();
   LFX.ReadDisplayStatus();
   LFX.ReadInstanceIdsCounter(NULL, iNulls, iNull);
   LFX.ReadOpenOrders(iNulls);
   LFX.ReadTicket(NULL, sNull, sNull, iNull, dNull, iNull, dNull, dNull, dNull, dNull, iNull, dNull, dNull, iNull);
   LFX.SaveDisplayStatus(NULL);
   LFX.Units(NULL);
   LFX.WriteTicket(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   LFX_ORDER.toStr(iNulls);

   lo.Ticket        (iNulls);       los.Ticket       (iNulls, NULL);
   lo.Version       (iNulls);       los.Version      (iNulls, NULL);
   lo.Type          (iNulls);       los.Type         (iNulls, NULL);
   lo.Units         (iNulls);       los.Units        (iNulls, NULL);
   lo.Lots          (iNulls);       los.Lots         (iNulls, NULL);
   lo.OpenTime      (iNulls);       los.OpenTime     (iNulls, NULL);
   lo.OpenPrice     (iNulls);       los.OpenPrice    (iNulls, NULL);
   lo.OpenEquity    (iNulls);       los.OpenEquity   (iNulls, NULL);
   lo.StopLoss      (iNulls);       los.StopLoss     (iNulls, NULL);
   lo.TakeProfit    (iNulls);       los.TakeProfit   (iNulls, NULL);
   lo.CloseTime     (iNulls);       los.CloseTime    (iNulls, NULL);
   lo.ClosePrice    (iNulls);       los.ClosePrice   (iNulls, NULL);
   lo.Profit        (iNulls);       los.Profit       (iNulls, NULL);
   lo.Comment       (iNulls);       los.Comment      (iNulls, NULL);
   lo.Digits        (iNulls);       los.Digits       (iNulls, NULL);
   lo.Currency      (iNulls);       los.Currency     (iNulls, NULL);
   lo.CurrencyId    (iNulls);       los.CurrencyId   (iNulls, NULL);

   lo.setTicket     (iNulls, NULL); los.setTicket    (iNulls, NULL, NULL);
   lo.setType       (iNulls, NULL); los.setType      (iNulls, NULL, NULL);
   lo.setUnits      (iNulls, NULL); los.setUnits     (iNulls, NULL, NULL);
   lo.setLots       (iNulls, NULL); los.setLots      (iNulls, NULL, NULL);
   lo.setOpenTime   (iNulls, NULL); los.setOpenTime  (iNulls, NULL, NULL);
   lo.setOpenPrice  (iNulls, NULL); los.setOpenPrice (iNulls, NULL, NULL);
   lo.setOpenEquity (iNulls, NULL); los.setOpenEquity(iNulls, NULL, NULL);
   lo.setStopLoss   (iNulls, NULL); los.setStopLoss  (iNulls, NULL, NULL);
   lo.setTakeProfit (iNulls, NULL); los.setTakeProfit(iNulls, NULL, NULL);
   lo.setCloseTime  (iNulls, NULL); los.setCloseTime (iNulls, NULL, NULL);
   lo.setClosePrice (iNulls, NULL); los.setClosePrice(iNulls, NULL, NULL);
   lo.setProfit     (iNulls, NULL); los.setProfit    (iNulls, NULL, NULL);
   lo.setComment    (iNulls, NULL); los.setComment   (iNulls, NULL, NULL);
   lo.setVersion    (iNulls, NULL); los.setVersion   (iNulls, NULL, NULL);
}
