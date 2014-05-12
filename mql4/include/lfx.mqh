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
string lfxAccountCompany;
int    lfxAccountType;

bool   isLfxInstrument;
string lfxCurrency;
int    lfxCurrencyId;
double lfxChartDeviation;                                            // RealPrice + Deviation = LFX-ChartPrice
int    lfxOrder   [LFX_ORDER.intSize];                               // LFX_ORDER
int    lfxOrders[][LFX_ORDER.intSize];                               // LFX_ORDER[]


/**
 * MQL4 structure LFX_ORDER
 *
 * struct LFX_ORDER {
 *    int  ticket;            //   4         lo[ 0]      // Ticket, enthält Strategy- und Currency-ID
 *    int  type;              //   4         lo[ 1]      // Operation-Type
 *    int  units;             //   4         lo[ 2]      // Order-Units in Zehnteln einer Unit
 *    int  lots;              //   4         lo[ 3]      // Ordervolumen in Hundertsteln eines Lots USD
 *    int  openTime;          //   4         lo[ 4]      // OpenTime, GMT
 *    int  openPriceLfx;      //   4         lo[ 5]      // OpenPrice in Points, LFX
 *    int  openPriceTime      //   4         lo[ 6]      // Zeitpunkt des Erreichens des OpenPrice-Limits, GMT
 *    int  openEquity;        //   4         lo[ 7]      // Equity zum Open-Zeitpunkt in Hundertsteln der Account-Währung (inkl. unrealisierter Verluste, exkl. unrealisierter Gewinne)
 *    int  stopLossLfx;       //   4         lo[ 8]      // StopLoss-Preis in Points, LFX
 *    int  stopLossTime       //   4         lo[ 9]      // Zeitpunkt des Erreichens des StopLosses, GMT
 *    int  takeProfitLfx;     //   4         lo[10]      // TakeProfit-Preis in Points, LFX
 *    int  takeProfitTime     //   4         lo[11]      // Zeitpunkt des Erreichens des TakeProfits, GMT
 *    int  closeTime;         //   4         lo[12]      // CloseTime, GMT
 *    int  closePriceLfx;     //   4         lo[13]      // ClosePrice in Points, LFX
 *    int  profit;            //   4         lo[14]      // Profit in Hundertsteln der Account-Währung (realisiert oder unrealisiert)
 *    int  deviation;         //   4         lo[15]      // Abweichung der gespeicherten LFX- von den tatsächlichen Preisen in Points: realPrice + deviation = lfxPrice
 *    char szComment[32];     //  32         lo[16]      // Kommentar, bis zu 31 Zeichen + <NUL> (kann vom Orderkommentar beim Broker abweichen)
 *    int  version;           //   4         lo[24]      // Zeitpunkt der letzten Änderung, GMT
 * } lo;                      // 100 byte = int[25]
 */

// Getter
int      lo.Ticket         (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 0]);                                      }
int      lo.Type           (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 1]);                                      }
double   lo.Units          (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 2]/ 10., 1));                             }
double   lo.Lots           (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 3]/100., 2));                             }
datetime lo.OpenTime       (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 4]);                                      }
double   lo.OpenPriceLfx   (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 5]/MathPow(10, digits), digits));         }
datetime lo.OpenPriceTime  (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 6]);                                      }
double   lo.OpenEquity     (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 7]/100., 2));                             }
double   lo.StopLossLfx    (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 8]/MathPow(10, digits), digits));         }
datetime lo.StopLossTime   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 9]);                                      }
double   lo.TakeProfitLfx  (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[10]/MathPow(10, digits), digits));         }
datetime lo.TakeProfitTime (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[11]);                                      }
datetime lo.CloseTime      (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[12]);                                      }
double   lo.ClosePriceLfx  (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[13]/MathPow(10, digits), digits));         }
double   lo.Profit         (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[14]/100., 2));                             }
double   lo.Deviation      (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[15]/MathPow(10, digits), digits));         }
string   lo.Comment        (/*LFX_ORDER*/int lo[]         ) {                                 return(BufferCharsToStr(lo, 64, 32));                                 }
datetime lo.Version        (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[24]);                                      }
//---------------------------------------------------------------------------  Helper  ------------------------------------------------------------------------------
int      lo.Digits         (/*LFX_ORDER*/int lo[]         ) {                   return(ifInt(LFX.CurrencyId(lo.Ticket(lo))==CID_JPY, 3, 5));                        }
string   lo.Currency       (/*LFX_ORDER*/int lo[]         ) {             return(GetCurrency(LFX.CurrencyId(lo.Ticket(lo))));                                       }
int      lo.CurrencyId     (/*LFX_ORDER*/int lo[]         ) {                         return(LFX.CurrencyId(lo.Ticket(lo)));                                        }
bool     lo.IsPending      (/*LFX_ORDER*/int lo[]         ) {                             return(OP_BUYLIMIT<=lo.Type(lo) && lo.Type(lo)<=OP_SELLSTOP);             }
bool     lo.IsOpened       (/*LFX_ORDER*/int lo[]         ) {                  return((lo.Type(lo)==OP_BUY || lo.Type(lo)==OP_SELL) && lo.OpenTime(lo) > 0);        }
bool     lo.IsOpen         (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.IsOpened(lo) && !lo.IsClosed(lo));                     }
bool     lo.IsClosed       (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) > 0);                                     }
bool     lo.IsOpenError    (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.OpenTime(lo) < 0);                                     }
bool     lo.IsCloseError   (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) < 0);                                     }
double   lo.OpenPrice      (/*LFX_ORDER*/int lo[]         ) { double oLfx =lo.OpenPriceLfx (lo), dev=lo.Deviation(lo); if (!oLfx ) dev=0; return(NormalizeDouble(oLfx -dev, lo.Digits(lo))); }
double   lo.StopLoss       (/*LFX_ORDER*/int lo[]         ) { double slLfx=lo.StopLossLfx  (lo), dev=lo.Deviation(lo); if (!slLfx) dev=0; return(NormalizeDouble(slLfx-dev, lo.Digits(lo))); }
double   lo.TakeProfit     (/*LFX_ORDER*/int lo[]         ) { double tpLfx=lo.TakeProfitLfx(lo), dev=lo.Deviation(lo); if (!tpLfx) dev=0; return(NormalizeDouble(tpLfx-dev, lo.Digits(lo))); }
double   lo.ClosePrice     (/*LFX_ORDER*/int lo[]         ) { double cLfx =lo.ClosePriceLfx(lo), dev=lo.Deviation(lo); if (!cLfx ) dev=0; return(NormalizeDouble(cLfx -dev, lo.Digits(lo))); }
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.Ticket        (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 0]);                                   }
int      los.Type          (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 1]);                                   }
double   los.Units         (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 2]/ 10., 1));                          }
double   los.Lots          (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 3]/100., 2));                          }
datetime los.OpenTime      (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 4]);                                   }
double   los.OpenPriceLfx  (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 5]/MathPow(10, digits), digits));      }
datetime los.OpenPriceTime (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 6]);                                   }
double   los.OpenEquity    (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 7]/100., 2));                          }
double   los.StopLossLfx   (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 8]/MathPow(10, digits), digits));      }
datetime los.StopLossTime  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 9]);                                   }
double   los.TakeProfitLfx (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][10]/MathPow(10, digits), digits));      }
datetime los.TakeProfitTime(/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][11]);                                   }
datetime los.CloseTime     (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][12]);                                   }
double   los.ClosePriceLfx (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][13]/MathPow(10, digits), digits));      }
double   los.Profit        (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][14]/100., 2));                          }
double   los.Deviation     (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo, i);    return(NormalizeDouble(lo[i][15]/MathPow(10, digits), digits));      }
string   los.Comment       (/*LFX_ORDER*/int lo[][], int i) {                                 return(BufferCharsToStr(lo, ArrayRange(lo, 1)*i*4 + 64, 32));         }
datetime los.Version       (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][24]);                                   }
//---------------------------------------------------------------------------  Helper  ------------------------------------------------------------------------------
int      los.Digits        (/*LFX_ORDER*/int lo[][], int i) {                  return(ifInt(LFX.CurrencyId(los.Ticket(lo, i))==CID_JPY, 3, 5));                     }
string   los.Currency      (/*LFX_ORDER*/int lo[][], int i) {            return(GetCurrency(LFX.CurrencyId(los.Ticket(lo, i))));                                    }
int      los.CurrencyId    (/*LFX_ORDER*/int lo[][], int i) {                        return(LFX.CurrencyId(los.Ticket(lo, i)));                                     }
bool     los.IsPending     (/*LFX_ORDER*/int lo[][], int i) {                            return(OP_BUYLIMIT<=los.Type(lo, i) && los.Type(lo, i)<=OP_SELLSTOP);      }
bool     los.IsOpened      (/*LFX_ORDER*/int lo[][], int i) {             return((los.Type(lo, i)==OP_BUY || los.Type(lo, i)==OP_SELL) && los.OpenTime(lo, i) > 0); }
bool     los.IsOpen        (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.IsOpened(lo, i) && !los.IsClosed(lo, i));              }
bool     los.IsClosed      (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) > 0);                                  }
bool     los.IsOpenError   (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.OpenTime(lo, i) < 0);                                  }
bool     los.IsCloseError  (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) < 0);                                  }
double   los.OpenPrice     (/*LFX_ORDER*/int lo[][], int i) { double oLfx =los.OpenPriceLfx (lo, i), dev=los.Deviation(lo, i); if (!oLfx ) dev=0; return(NormalizeDouble(oLfx -dev, los.Digits(lo, i))); }
double   los.StopLoss      (/*LFX_ORDER*/int lo[][], int i) { double slLfx=los.StopLossLfx  (lo, i), dev=los.Deviation(lo, i); if (!slLfx) dev=0; return(NormalizeDouble(slLfx-dev, los.Digits(lo, i))); }
double   los.TakeProfit    (/*LFX_ORDER*/int lo[][], int i) { double tpLfx=los.TakeProfitLfx(lo, i), dev=los.Deviation(lo, i); if (!tpLfx) dev=0; return(NormalizeDouble(tpLfx-dev, los.Digits(lo, i))); }
double   los.ClosePrice    (/*LFX_ORDER*/int lo[][], int i) { double cLfx =los.ClosePriceLfx(lo, i), dev=los.Deviation(lo, i); if (!cLfx ) dev=0; return(NormalizeDouble(cLfx -dev, los.Digits(lo, i))); }
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------


// Setter
int      lo.setTicket         (/*LFX_ORDER*/int &lo[],          int      ticket        ) { lo[ 0]    = ticket;                                                 return(ticket        ); }
int      lo.setType           (/*LFX_ORDER*/int &lo[],          int      type          ) { lo[ 1]    = type;                                                   return(type          ); }
double   lo.setUnits          (/*LFX_ORDER*/int &lo[],          double   units         ) { lo[ 2]    = MathRound(units *  10);                                 return(units         ); }
double   lo.setLots           (/*LFX_ORDER*/int &lo[],          double   lots          ) { lo[ 3]    = MathRound(lots  * 100);                                 return(lots          ); }
datetime lo.setOpenTime       (/*LFX_ORDER*/int &lo[],          datetime openTime      ) { lo[ 4]    = openTime;                                               return(openTime      ); }
double   lo.setOpenPriceLfx   (/*LFX_ORDER*/int &lo[],          double   openPriceLfx  ) { lo[ 5]    = MathRound(openPriceLfx * MathPow(10, lo.Digits(lo)));   return(openPriceLfx  ); }
datetime lo.setOpenPriceTime  (/*LFX_ORDER*/int &lo[],          datetime openPriceTime ) { lo[ 6]    = openPriceTime;                                          return(openPriceTime ); }
double   lo.setOpenEquity     (/*LFX_ORDER*/int &lo[],          double   openEquity    ) { lo[ 7]    = MathRound(openEquity * 100);                            return(openEquity    ); }
double   lo.setStopLossLfx    (/*LFX_ORDER*/int &lo[],          double   stopLossLfx   ) { lo[ 8]    = MathRound(stopLossLfx * MathPow(10, lo.Digits(lo)));    return(stopLossLfx   ); }
datetime lo.setStopLossTime   (/*LFX_ORDER*/int &lo[],          datetime stopLossTime  ) { lo[ 9]    = stopLossTime;                                           return(stopLossTime  ); }
double   lo.setTakeProfitLfx  (/*LFX_ORDER*/int &lo[],          double   takeProfitLfx ) { lo[10]    = MathRound(takeProfitLfx * MathPow(10, lo.Digits(lo)));  return(takeProfitLfx ); }
datetime lo.setTakeProfitTime (/*LFX_ORDER*/int &lo[],          datetime takeProfitTime) { lo[11]    = takeProfitTime;                                         return(takeProfitTime); }
datetime lo.setCloseTime      (/*LFX_ORDER*/int &lo[],          datetime closeTime     ) { lo[12]    = closeTime;                                              return(closeTime     ); }
double   lo.setClosePriceLfx  (/*LFX_ORDER*/int &lo[],          double   closePriceLfx ) { lo[13]    = MathRound(closePriceLfx * MathPow(10, lo.Digits(lo)));  return(closePriceLfx ); }
double   lo.setProfit         (/*LFX_ORDER*/int &lo[],          double   profit        ) { lo[14]    = MathRound(profit * 100);                                return(profit        ); }
double   lo.setDeviation      (/*LFX_ORDER*/int &lo[],          double   deviation     ) { lo[15]    = MathRound(deviation * MathPow(10, lo.Digits(lo)));      return(deviation     ); }
string   lo.setComment        (/*LFX_ORDER*/int  lo[],          string   comment       ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("lo.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetStringAddress(comment), GetBufferAddress(lo)+64, StringLen(comment)+1);                                                                       return(comment       ); }
datetime lo.setVersion        (/*LFX_ORDER*/int &lo[],          datetime version       ) { lo[24]    = version;                                                return(version       ); }
double   lo.setOpenPrice      (/*LFX_ORDER*/int &lo[],          double   openPrice     ) { double dev=lo.Deviation(lo); if (EQ(openPrice , 0)) dev=0; lo.setOpenPriceLfx (lo, openPrice +dev); return(openPrice ); }
double   lo.setStopLoss       (/*LFX_ORDER*/int &lo[],          double   stopLoss      ) { double dev=lo.Deviation(lo); if (EQ(stopLoss  , 0)) dev=0; lo.setStopLossLfx  (lo, stopLoss  +dev); return(stopLoss  ); }
double   lo.setTakeProfit     (/*LFX_ORDER*/int &lo[],          double   takeProfit    ) { double dev=lo.Deviation(lo); if (EQ(takeProfit, 0)) dev=0; lo.setTakeProfitLfx(lo, takeProfit+dev); return(takeProfit); }
double   lo.setClosePrice     (/*LFX_ORDER*/int &lo[],          double   closePrice    ) { double dev=lo.Deviation(lo); if (EQ(closePrice, 0)) dev=0; lo.setClosePriceLfx(lo, closePrice+dev); return(closePrice); }

int      los.setTicket        (/*LFX_ORDER*/int &lo[][], int i, int      ticket        ) { lo[i][ 0] = ticket;                                                 return(ticket        ); }
int      los.setType          (/*LFX_ORDER*/int &lo[][], int i, int      type          ) { lo[i][ 1] = type;                                                   return(type          ); }
double   los.setUnits         (/*LFX_ORDER*/int &lo[][], int i, double   units         ) { lo[i][ 2] = MathRound(units *  10);                                 return(units         ); }
double   los.setLots          (/*LFX_ORDER*/int &lo[][], int i, double   lots          ) { lo[i][ 3] = MathRound(lots  * 100);                                 return(lots          ); }
datetime los.setOpenTime      (/*LFX_ORDER*/int &lo[][], int i, datetime openTime      ) { lo[i][ 4] = openTime;                                               return(openTime      ); }
double   los.setOpenPriceLfx  (/*LFX_ORDER*/int &lo[][], int i, double   openPrice     ) { lo[i][ 5] = MathRound(openPrice  * MathPow(10, los.Digits(lo, i))); return(openPrice     ); }
datetime los.setOpenPriceTime (/*LFX_ORDER*/int &lo[][], int i, datetime openPriceTime ) { lo[i][ 6] = openPriceTime;                                          return(openPriceTime ); }
double   los.setOpenEquity    (/*LFX_ORDER*/int &lo[][], int i, double   openEquity    ) { lo[i][ 7] = MathRound(openEquity * 100);                            return(openEquity    ); }
double   los.setStopLossLfx   (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss      ) { lo[i][ 8] = MathRound(stopLoss   * MathPow(10, los.Digits(lo, i))); return(stopLoss      ); }
datetime los.setStopLossTime  (/*LFX_ORDER*/int &lo[][], int i, datetime stopLossTime  ) { lo[i][ 9] = stopLossTime;                                           return(stopLossTime  ); }
double   los.setTakeProfitLfx (/*LFX_ORDER*/int &lo[][], int i, double   takeProfit    ) { lo[i][10] = MathRound(takeProfit * MathPow(10, los.Digits(lo, i))); return(takeProfit    ); }
datetime los.setTakeProfitTime(/*LFX_ORDER*/int &lo[][], int i, datetime takeProfitTime) { lo[i][11] = takeProfitTime;                                         return(takeProfitTime); }
datetime los.setCloseTime     (/*LFX_ORDER*/int &lo[][], int i, datetime closeTime     ) { lo[i][12] = closeTime;                                              return(closeTime     ); }
double   los.setClosePriceLfx (/*LFX_ORDER*/int &lo[][], int i, double   closePrice    ) { lo[i][13] = MathRound(closePrice * MathPow(10, los.Digits(lo, i))); return(closePrice    ); }
double   los.setProfit        (/*LFX_ORDER*/int &lo[][], int i, double   profit        ) { lo[i][14] = MathRound(profit * 100);                                return(profit        ); }
double   los.setDeviation     (/*LFX_ORDER*/int &lo[][], int i, double   deviation     ) { lo[i][15] = MathRound(deviation * MathPow(10, los.Digits(lo, i)));  return(deviation     ); }
string   los.setComment       (/*LFX_ORDER*/int  lo[][], int i, string   comment       ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("los.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetStringAddress(comment), GetBufferAddress(lo)+ i*ArrayRange(lo, 1)*4 + 64, StringLen(comment)+1);                                              return(comment       ); }
datetime los.setVersion       (/*LFX_ORDER*/int &lo[][], int i, datetime version       ) { lo[i][24] = version;                                                return(version       ); }
double   los.setOpenPrice     (/*LFX_ORDER*/int &lo[][], int i, double   openPrice     ) { double dev=los.Deviation(lo, i); if (EQ(openPrice , 0)) dev=0; los.setOpenPriceLfx (lo, i, openPrice +dev); return(openPrice ); }
double   los.setStopLoss      (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss      ) { double dev=los.Deviation(lo, i); if (EQ(stopLoss  , 0)) dev=0; los.setStopLossLfx  (lo, i, stopLoss  +dev); return(stopLoss  ); }
double   los.setTakeProfit    (/*LFX_ORDER*/int &lo[][], int i, double   takeProfit    ) { double dev=los.Deviation(lo, i); if (EQ(takeProfit, 0)) dev=0; los.setTakeProfitLfx(lo, i, takeProfit+dev); return(takeProfit); }
double   los.setClosePrice    (/*LFX_ORDER*/int &lo[][], int i, double   closePrice    ) { double dev=los.Deviation(lo, i); if (EQ(closePrice, 0)) dev=0; los.setClosePriceLfx(lo, i, closePrice+dev); return(closePrice); }


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
      line        = StringConcatenate("{ticket="        ,                    lo.Ticket        (lo),
                                     ", currency=\""    ,                    lo.Currency      (lo), "\"",
                                     ", type="          , OperationTypeToStr(lo.Type          (lo)),
                                     ", units="         ,        NumberToStr(lo.Units         (lo), ".+"),
                                     ", lots="          ,        NumberToStr(lo.Lots          (lo), ".+"),
                                     ", openTime="      ,           ifString(lo.OpenTime      (lo), "'"+ TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL) +"'"+ ifString(lo.IsOpenError(lo), "(ERROR)", ""), "0"),
                                     ", openPrice="     ,        NumberToStr(lo.OpenPriceLfx  (lo), priceFormat),
                                     ", openPriceTime=" ,           ifString(lo.OpenPriceTime (lo), "'"+ TimeToStr(lo.OpenPriceTime(lo), TIME_FULL) +"'", "0"),
                                     ", openEquity="    ,        DoubleToStr(lo.OpenEquity    (lo), 2),
                                     ", stopLoss="      ,           ifString(lo.StopLossLfx   (lo), NumberToStr(lo.StopLossLfx(lo), priceFormat), "0"),
                                     ", stopLossTime="  ,           ifString(lo.StopLossTime  (lo), "'"+ TimeToStr(lo.StopLossTime(lo), TIME_FULL) +"'", "0"),
                                     ", takeProfit="    ,           ifString(lo.TakeProfitLfx (lo), NumberToStr(lo.TakeProfitLfx(lo), priceFormat), "0"),
                                     ", takeProfitTime=",           ifString(lo.TakeProfitTime(lo), "'"+ TimeToStr(lo.TakeProfitTime(lo), TIME_FULL) +"'", "0"),
                                     ", closeTime="     ,           ifString(lo.CloseTime     (lo), "'"+ TimeToStr(lo.CloseTime(lo), TIME_FULL) +"'", "0"),
                                     ", closePrice="    ,           ifString(lo.ClosePriceLfx (lo), NumberToStr(lo.ClosePriceLfx(lo), priceFormat), "0"),
                                     ", profit="        ,        DoubleToStr(lo.Profit        (lo), 2),
                                     ", deviation="     ,        NumberToStr(lo.Deviation     (lo), priceFormat),
                                     ", comment=\""     ,                    lo.Comment       (lo), "\"",
                                     ", version="       ,           ifString(lo.Version       (lo), "'"+ TimeToStr(lo.Version(lo), TIME_FULL) +"'", "0"), "}");
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
         line        = StringConcatenate("[", i, "]={ticket="        ,                    los.Ticket        (lo, i),
                                                  ", currency=\""    ,                    los.Currency      (lo, i), "\"",
                                                  ", type="          , OperationTypeToStr(los.Type          (lo, i)),
                                                  ", units="         ,        NumberToStr(los.Units         (lo, i), ".+"),
                                                  ", lots="          ,        NumberToStr(los.Lots          (lo, i), ".+"),
                                                  ", openTime="      ,           ifString(los.OpenTime      (lo, i), "'"+ TimeToStr(Abs(los.OpenTime(lo, i)), TIME_FULL) +"'"+ ifString(los.IsOpenError(lo, i), "(ERROR)", ""), "0"),
                                                  ", openEquity="    ,        DoubleToStr(los.OpenEquity    (lo, i), 2),
                                                  ", openPrice="     ,        NumberToStr(los.OpenPriceLfx  (lo, i), priceFormat),
                                                  ", openPriceTime=" ,           ifString(los.OpenPriceTime (lo, i), "'"+ TimeToStr(los.OpenPriceTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", stopLoss="      ,           ifString(los.StopLossLfx   (lo, i), NumberToStr(los.StopLossLfx(lo, i), priceFormat), "0"),
                                                  ", stopLossTime="  ,           ifString(los.StopLossTime  (lo, i), "'"+ TimeToStr(los.StopLossTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", takeProfit="    ,           ifString(los.TakeProfitLfx (lo, i), NumberToStr(los.TakeProfitLfx(lo, i), priceFormat), "0"),
                                                  ", takeProfitTime=",           ifString(los.TakeProfitTime(lo, i), "'"+ TimeToStr(los.TakeProfitTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", closeTime="     ,           ifString(los.CloseTime     (lo, i), "'"+ TimeToStr(los.CloseTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", closePrice="    ,           ifString(los.ClosePriceLfx (lo, i), NumberToStr(los.ClosePriceLfx(lo, i), priceFormat), "0"),
                                                  ", profit="        ,        DoubleToStr(los.Profit        (lo, i), 2),
                                                  ", deviation="     ,        NumberToStr(los.Deviation     (lo, i), priceFormat),
                                                  ", comment=\""     ,                    los.Comment       (lo, i), "\"",
                                                  ", version="       ,           ifString(los.Version       (lo, i), "'"+ TimeToStr(los.Version(lo, i), TIME_FULL) +"'", "0"), "}");
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
 * Initialisiert die internen Variablen zum Zugriff auf den LFX-TradeAccount.
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.InitAccountData() {
   if (lfxAccount > 0)
      return(true);

   int    _account;
   string _accountCompany;
   int    _accountType;

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

   // AccountCompany
   section = "Accounts";
   key     = _account +".company";
   _accountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(_accountCompany)) return(!catch("LFX.InitAccountData(3)   missing account company setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // AccountType
   key   = _account +".type";
   value = StringToLower(GetGlobalConfigString(section, key, ""));
   if (!StringLen(value)) return(!catch("LFX.InitAccountData(4)   missing account type setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));
   if      (value == "demo") _accountType = ACCOUNT_TYPE_DEMO;
   else if (value == "real") _accountType = ACCOUNT_TYPE_REAL;
   else return(!catch("LFX.InitAccountData(5)   invalid account type setting ["+ section +"]->"+ key +" = \""+ GetGlobalConfigString(section, key, "") +"\"", ERR_RUNTIME_ERROR));

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
   //Ticket = Symbol, Label, OrderType, OrderUnits, OpenTime, OpenEquity, OpenPrice, OpenPriceTime, StopLoss, StopLossTime, TakeProfit, TakeProfitTime, CloseTime, ClosePrice, OrderProfit, LfxDeviation, Version
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

   // OpenTime
   sValue = StringTrim(values[4]);
   if      (StringIsInteger(sValue)) datetime _openTime =  StrToInteger(sValue);
   else if (StringStartsWith(sValue, "-"))    _openTime = -StrToTime(StringSubstr(sValue, 1));
   else                                       _openTime =  StrToTime(sValue);
   if (!_openTime)                               return(!catch("LFX.GetOrder(7)   invalid open time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_openTime > mql.GetSystemTime())          return(!catch("LFX.GetOrder(8)   invalid open time \""+ TimeToStr(_openTime, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OpenEquity
   sValue = StringTrim(values[5]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(9)   invalid open equity \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _openEquity = StrToDouble(sValue);
   if (!IsPendingTradeOperation(_orderType))
      if (_openEquity <= 0)                      return(!catch("LFX.GetOrder(10)   invalid open equity \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

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
   if (StringIsDigit(sValue)) datetime _closeTime = StrToInteger(sValue);
   else                                _closeTime =    StrToTime(sValue);
   if      (_closeTime < 0)                      return(!catch("LFX.GetOrder(23)   invalid close time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   else if (_closeTime > 0)
      if (_closeTime > mql.GetSystemTime())      return(!catch("LFX.GetOrder(24)   invalid close time \""+ TimeToStr(_closeTime, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // ClosePrice
   sValue = StringTrim(values[13]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(25)   invalid close price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _closePrice = StrToDouble(sValue);
   if (_closePrice < 0)                          return(!catch("LFX.GetOrder(26)   invalid close price \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (!_closeTime && _closePrice!=0)            return(!catch("LFX.GetOrder(27)   close time/price mis-match 0/"+ NumberToStr(_closePrice, ".+") +" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_closeTime!=0 && !_closePrice)            return(!catch("LFX.GetOrder(28)   close time/price mis-match \""+ TimeToStr(_closeTime, TIME_FULL) +"\"/0 in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));

   // OrderProfit
   sValue = StringTrim(values[14]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(29)   invalid order profit \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _orderProfit = StrToDouble(sValue);

   // LfxDeviation
   sValue = StringTrim(values[15]);
   if (!StringIsNumeric(sValue))                 return(!catch("LFX.GetOrder(30)   invalid LFX deviation \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   double _lfxDeviation = StrToDouble(sValue);

   // Version
   sValue = StringTrim(values[16]);
   if (StringIsDigit(sValue)) datetime _version = StrToInteger(sValue);
   else                                _version =    StrToTime(sValue);
   if (_version <= 0)                            return(!catch("LFX.GetOrder(31)   invalid last update time \""+ sValue +"\" in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));
   if (_version > mql.GetSystemTime())           return(!catch("LFX.GetOrder(32)   invalid version time \""+ TimeToStr(_version, TIME_FULL) +" GMT\" (current time \""+ TimeToStr(mql.GetSystemTime(), TIME_FULL) +" GMT\") in order entry ["+ section +"]->"+ ticket +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR));


   // (3) Orderdaten in übergebenes Array schreiben (erst nach vollständiger erfolgreicher Validierung)
   InitializeByteBuffer(lo, LFX_ORDER.size);

   lo.setTicket        (lo,  ticket        );                        // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
   lo.setDeviation     (lo, _lfxDeviation  );                        // LFX-Deviation immer vor den Preisen
   lo.setType          (lo, _orderType     );
   lo.setUnits         (lo, _orderUnits    );
   lo.setLots          (lo,  NULL          );
   lo.setOpenTime      (lo, _openTime      );
   lo.setOpenEquity    (lo, _openEquity    );
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

   return(!catch("LFX.GetOrder(33)"));
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
   //Ticket = Symbol, Label, TradeOperation, Units, OpenTime, OpenEquity, OpenPrice, OpenPriceTime, StopLoss, StopLossTime, TakeProfit, TakeProfitTime, CloseTime, ClosePrice, Profit, LfxDeviation,Version
   string sSymbol         =                          lo.Currency      (lo);
   string sLabel          =                          lo.Comment       (lo);                                                                                               sLabel          = StringRightPad(sLabel         ,  9, " ");
   string sOperationType  = OperationTypeDescription(lo.Type          (lo));                                                                                              sOperationType  = StringRightPad(sOperationType , 10, " ");
   string sUnits          =              NumberToStr(lo.Units         (lo), ".+");                                                                                        sUnits          = StringLeftPad (sUnits         ,  5, " ");
   string sOpenTime       =                 ifString(lo.OpenTime      (lo) < 0, "-", "") + TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL);                                    sOpenTime       = StringLeftPad (sOpenTime      , 20, " ");
   string sOpenEquity     =                ifString(!lo.OpenEquity    (lo), "0", DoubleToStr(lo.OpenEquity(lo), 2));                                                      sOpenEquity     = StringLeftPad (sOpenEquity    ,  7, " ");
   string sOpenPriceLfx   =              DoubleToStr(lo.OpenPriceLfx  (lo), lo.Digits(lo));                                                                               sOpenPriceLfx   = StringLeftPad (sOpenPriceLfx  ,  9, " ");
   string sOpenPriceTime  =                ifString(!lo.OpenPriceTime (lo), "0", TimeToStr(lo.OpenPriceTime(lo), TIME_FULL));                                             sOpenPriceTime  = StringLeftPad (sOpenPriceTime , 19, " ");
   string sStopLossLfx    =                ifString(!lo.StopLossLfx   (lo), "0", DoubleToStr(lo.StopLossLfx(lo),   lo.Digits(lo)));                                       sStopLossLfx    = StringLeftPad (sStopLossLfx   ,  8, " ");
   string sStopLossTime   =                ifString(!lo.StopLossTime  (lo), "0", TimeToStr(lo.StopLossTime(lo), TIME_FULL));                                              sStopLossTime   = StringLeftPad (sStopLossTime  , 19, " ");
   string sTakeProfitLfx  =                ifString(!lo.TakeProfitLfx (lo), "0", DoubleToStr(lo.TakeProfitLfx(lo), lo.Digits(lo)));                                       sTakeProfitLfx  = StringLeftPad (sTakeProfitLfx , 10, " ");
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
   string value   = StringConcatenate(sSymbol, ", ", sLabel, ", ", sOperationType, ", ", sUnits, ", ", sOpenTime, ", ", sOpenEquity, ", ", sOpenPriceLfx, ", ", sOpenPriceTime, ", ", sStopLossLfx, ", ", sStopLossTime, ", ", sTakeProfitLfx, ", ", sTakeProfitTime, ", ", sCloseTime, ", ", sClosePriceLfx, ", ", sProfit, ", ", sDeviation, ", ", sVersion);

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

   lo.ClosePrice       (iNulls);       los.ClosePrice       (iNulls, NULL);
   lo.CloseTime        (iNulls);       los.CloseTime        (iNulls, NULL);
   lo.Comment          (iNulls);       los.Comment          (iNulls, NULL);
   lo.Currency         (iNulls);       los.Currency         (iNulls, NULL);
   lo.CurrencyId       (iNulls);       los.CurrencyId       (iNulls, NULL);
   lo.Digits           (iNulls);       los.Digits           (iNulls, NULL);
   lo.IsClosed         (iNulls);       los.IsClosed         (iNulls, NULL);
   lo.IsCloseError     (iNulls);       los.IsCloseError     (iNulls, NULL);
   lo.IsOpen           (iNulls);       los.IsOpen           (iNulls, NULL);
   lo.IsOpened         (iNulls);       los.IsOpened         (iNulls, NULL);
   lo.IsOpenError      (iNulls);       los.IsOpenError      (iNulls, NULL);
   lo.IsPending        (iNulls);       los.IsPending        (iNulls, NULL);
   lo.Lots             (iNulls);       los.Lots             (iNulls, NULL);
   lo.OpenEquity       (iNulls);       los.OpenEquity       (iNulls, NULL);
   lo.OpenPrice        (iNulls);       los.OpenPrice        (iNulls, NULL);
   lo.OpenPriceTime    (iNulls);       los.OpenPriceTime    (iNulls, NULL);
   lo.OpenTime         (iNulls);       los.OpenTime         (iNulls, NULL);
   lo.Profit           (iNulls);       los.Profit           (iNulls, NULL);
   lo.Deviation        (iNulls);       los.Deviation        (iNulls, NULL);
   lo.StopLoss         (iNulls);       los.StopLoss         (iNulls, NULL);
   lo.StopLossTime     (iNulls);       los.StopLossTime     (iNulls, NULL);
   lo.TakeProfit       (iNulls);       los.TakeProfit       (iNulls, NULL);
   lo.TakeProfitTime   (iNulls);       los.TakeProfitTime   (iNulls, NULL);
   lo.Ticket           (iNulls);       los.Ticket           (iNulls, NULL);
   lo.Type             (iNulls);       los.Type             (iNulls, NULL);
   lo.Units            (iNulls);       los.Units            (iNulls, NULL);
   lo.Version          (iNulls);       los.Version          (iNulls, NULL);

   lo.setClosePrice    (iNulls, NULL); los.setClosePrice    (iNulls, NULL, NULL);
   lo.setCloseTime     (iNulls, NULL); los.setCloseTime     (iNulls, NULL, NULL);
   lo.setComment       (iNulls, NULL); los.setComment       (iNulls, NULL, NULL);
   lo.setLots          (iNulls, NULL); los.setLots          (iNulls, NULL, NULL);
   lo.setOpenEquity    (iNulls, NULL); los.setOpenEquity    (iNulls, NULL, NULL);
   lo.setOpenPrice     (iNulls, NULL); los.setOpenPrice     (iNulls, NULL, NULL);
   lo.setOpenPriceTime (iNulls, NULL); los.setOpenPriceTime (iNulls, NULL, NULL);
   lo.setOpenTime      (iNulls, NULL); los.setOpenTime      (iNulls, NULL, NULL);
   lo.setProfit        (iNulls, NULL); los.setProfit        (iNulls, NULL, NULL);
   lo.setDeviation     (iNulls, NULL); los.setDeviation     (iNulls, NULL, NULL);
   lo.setStopLoss      (iNulls, NULL); los.setStopLoss      (iNulls, NULL, NULL);
   lo.setStopLossTime  (iNulls, NULL); los.setStopLossTime  (iNulls, NULL, NULL);
   lo.setTakeProfit    (iNulls, NULL); los.setTakeProfit    (iNulls, NULL, NULL);
   lo.setTakeProfitTime(iNulls, NULL); los.setTakeProfitTime(iNulls, NULL, NULL);
   lo.setTicket        (iNulls, NULL); los.setTicket        (iNulls, NULL, NULL);
   lo.setType          (iNulls, NULL); los.setType          (iNulls, NULL, NULL);
   lo.setUnits         (iNulls, NULL); los.setUnits         (iNulls, NULL, NULL);
   lo.setVersion       (iNulls, NULL); los.setVersion       (iNulls, NULL, NULL);
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
