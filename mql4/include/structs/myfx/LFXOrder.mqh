/**
 * MQL structure LFX_ORDER
 *
 * struct LFX_ORDER {
 *    int    ticket;          //   4         lo[ 0]      // Ticket, enthält Strategy- und Currency-ID
 *    int    type;            //   4         lo[ 1]      // Operation-Type
 *    int    units;           //   4         lo[ 2]      // Order-Units in Zehnteln einer Unit
 *    int    lots;            //   4         lo[ 3]      // Ordervolumen in Hundertsteln eines Lots USD
 *    int    openEquity;      //   4         lo[ 4]      // Equity zum Open-Zeitpunkt in Hundertsteln der Account-Währung (inkl. unrealisierter Verluste, exkl. unrealisierter Gewinne)
 *    int    openTime;        //   4         lo[ 5]      // OpenTime, GMT
 *    int    openPriceLfx;    //   4         lo[ 6]      // OpenPrice in Points, LFX
 *    int    openPriceTime    //   4         lo[ 7]      // Zeitpunkt des Erreichens des OpenPrice-Limits, GMT
 *    int    stopLossLfx;     //   4         lo[ 8]      // StopLoss-Preis in Points, LFX
 *    int    stopLossTime     //   4         lo[ 9]      // Zeitpunkt des Erreichens des StopLosses, GMT
 *    int    takeProfitLfx;   //   4         lo[10]      // TakeProfit-Preis in Points, LFX
 *    int    takeProfitTime   //   4         lo[11]      // Zeitpunkt des Erreichens des TakeProfits, GMT
 *    int    closeTime;       //   4         lo[12]      // CloseTime, GMT
 *    int    closePriceLfx;   //   4         lo[13]      // ClosePrice in Points, LFX
 *    int    profit;          //   4         lo[14]      // Profit in Hundertsteln der Account-Währung (realisiert oder unrealisiert)
 *    int    deviation;       //   4         lo[15]      // Abweichung der gespeicherten LFX- von den tatsächlichen Preisen in Points: realPrice + deviation = lfxPrice
 *    szchar comment[32];     //  32         lo[16]      // Kommentar, <NUL>-terminiert
 *    int    version;         //   4         lo[24]      // Zeitpunkt der letzten Änderung, GMT
 * } lo;                      // 100 byte = int[25]
 *
 *
 * @see  Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */

// Getter
int      lo.Ticket         (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 0]);                                                                           LFX_ORDER.toStr(lo); }
int      lo.Type           (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 1]);                                                                           LFX_ORDER.toStr(lo); }
double   lo.Units          (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 2]/ 10., 1));                                                                  LFX_ORDER.toStr(lo); }
double   lo.Lots           (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 3]/100., 2));                                                                  LFX_ORDER.toStr(lo); }
double   lo.OpenEquity     (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[ 4]/100., 2));                                                                  LFX_ORDER.toStr(lo); }
datetime lo.OpenTime       (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 5]);                                                                           LFX_ORDER.toStr(lo); }
double   lo.OpenPriceLfx   (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 6]/MathPow(10, digits), digits));                                              LFX_ORDER.toStr(lo); }
datetime lo.OpenPriceTime  (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 7]);                                                                           LFX_ORDER.toStr(lo); }
double   lo.StopLossLfx    (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[ 8]/MathPow(10, digits), digits));                                              LFX_ORDER.toStr(lo); }
datetime lo.StopLossTime   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[ 9]);                                                                           LFX_ORDER.toStr(lo); }
double   lo.TakeProfitLfx  (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[10]/MathPow(10, digits), digits));                                              LFX_ORDER.toStr(lo); }
datetime lo.TakeProfitTime (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[11]);                                                                           LFX_ORDER.toStr(lo); }
datetime lo.CloseTime      (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[12]);                                                                           LFX_ORDER.toStr(lo); }
double   lo.ClosePriceLfx  (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[13]/MathPow(10, digits), digits));                                              LFX_ORDER.toStr(lo); }
double   lo.Profit         (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[14]/100., 2));                                                                  LFX_ORDER.toStr(lo); }
double   lo.Deviation      (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[15]/MathPow(10, digits), digits));                                              LFX_ORDER.toStr(lo); }
string   lo.Comment        (/*LFX_ORDER*/int lo[]         ) {                                 return(BufferCharsToStr(lo, 64, 32));                                                                      LFX_ORDER.toStr(lo); }
datetime lo.Version        (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[24]);                                                                           LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions ------------------------------------------------------------------------------------------------------------------------------------
int      lo.Digits         (/*LFX_ORDER*/int lo[]         ) {                   return(ifInt(LFX.CurrencyId(lo.Ticket(lo))==CID_JPY, 3, 5));                                                             LFX_ORDER.toStr(lo); }
string   lo.Currency       (/*LFX_ORDER*/int lo[]         ) {             return(GetCurrency(LFX.CurrencyId(lo.Ticket(lo))));                                                                            LFX_ORDER.toStr(lo); }
int      lo.CurrencyId     (/*LFX_ORDER*/int lo[]         ) {                         return(LFX.CurrencyId(lo.Ticket(lo)));                                                                             LFX_ORDER.toStr(lo); }
bool     lo.IsPending      (/*LFX_ORDER*/int lo[]         ) {                             return(OP_BUYLIMIT<=lo.Type(lo) && lo.Type(lo)<=OP_SELLSTOP);                                                  LFX_ORDER.toStr(lo); }
bool     lo.IsOpened       (/*LFX_ORDER*/int lo[]         ) {                  return((lo.Type(lo)==OP_BUY || lo.Type(lo)==OP_SELL) && lo.OpenTime(lo) > 0);                                             LFX_ORDER.toStr(lo); }
bool     lo.IsOpen         (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.IsOpened(lo) && !lo.IsClosed(lo));                                                          LFX_ORDER.toStr(lo); }
bool     lo.IsClosed       (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) > 0);                                                                          LFX_ORDER.toStr(lo); }
bool     lo.IsOpenError    (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.OpenTime(lo) < 0);                                                                          LFX_ORDER.toStr(lo); }
bool     lo.IsCloseError   (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) < 0);                                                                          LFX_ORDER.toStr(lo); }
double   lo.OpenPrice      (/*LFX_ORDER*/int lo[]         ) { double oLfx =lo.OpenPriceLfx (lo), dev=lo.Deviation(lo); if (!oLfx ) dev=0; return(NormalizeDouble(oLfx -dev, lo.Digits(lo)));             LFX_ORDER.toStr(lo); }
double   lo.StopLoss       (/*LFX_ORDER*/int lo[]         ) { double slLfx=lo.StopLossLfx  (lo), dev=lo.Deviation(lo); if (!slLfx) dev=0; return(NormalizeDouble(slLfx-dev, lo.Digits(lo)));             LFX_ORDER.toStr(lo); }
double   lo.TakeProfit     (/*LFX_ORDER*/int lo[]         ) { double tpLfx=lo.TakeProfitLfx(lo), dev=lo.Deviation(lo); if (!tpLfx) dev=0; return(NormalizeDouble(tpLfx-dev, lo.Digits(lo)));             LFX_ORDER.toStr(lo); }
double   lo.ClosePrice     (/*LFX_ORDER*/int lo[]         ) { double cLfx =lo.ClosePriceLfx(lo), dev=lo.Deviation(lo); if (!cLfx ) dev=0; return(NormalizeDouble(cLfx -dev, lo.Digits(lo)));             LFX_ORDER.toStr(lo); }
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.Ticket        (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 0]);                                                                        LFX_ORDER.toStr(lo); }
int      los.Type          (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 1]);                                                                        LFX_ORDER.toStr(lo); }
double   los.Units         (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 2]/ 10., 1));                                                               LFX_ORDER.toStr(lo); }
double   los.Lots          (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 3]/100., 2));                                                               LFX_ORDER.toStr(lo); }
double   los.OpenEquity    (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][ 4]/100., 2));                                                               LFX_ORDER.toStr(lo); }
datetime los.OpenTime      (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 5]);                                                                        LFX_ORDER.toStr(lo); }
double   los.OpenPriceLfx  (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 6]/MathPow(10, digits), digits));                                           LFX_ORDER.toStr(lo); }
datetime los.OpenPriceTime (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 7]);                                                                        LFX_ORDER.toStr(lo); }
double   los.StopLossLfx   (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][ 8]/MathPow(10, digits), digits));                                           LFX_ORDER.toStr(lo); }
datetime los.StopLossTime  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][ 9]);                                                                        LFX_ORDER.toStr(lo); }
double   los.TakeProfitLfx (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][10]/MathPow(10, digits), digits));                                           LFX_ORDER.toStr(lo); }
datetime los.TakeProfitTime(/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][11]);                                                                        LFX_ORDER.toStr(lo); }
datetime los.CloseTime     (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][12]);                                                                        LFX_ORDER.toStr(lo); }
double   los.ClosePriceLfx (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][13]/MathPow(10, digits), digits));                                           LFX_ORDER.toStr(lo); }
double   los.Profit        (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][14]/100., 2));                                                               LFX_ORDER.toStr(lo); }
double   los.Deviation     (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo, i);    return(NormalizeDouble(lo[i][15]/MathPow(10, digits), digits));                                           LFX_ORDER.toStr(lo); }
string   los.Comment       (/*LFX_ORDER*/int lo[][], int i) {                                 return(BufferCharsToStr(lo, ArrayRange(lo, 1)*i*4 + 64, 32));                                              LFX_ORDER.toStr(lo); }
datetime los.Version       (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][24]);                                                                        LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions ------------------------------------------------------------------------------------------------------------------------------------
int      los.Digits        (/*LFX_ORDER*/int lo[][], int i) {                  return(ifInt(LFX.CurrencyId(los.Ticket(lo, i))==CID_JPY, 3, 5));                                                          LFX_ORDER.toStr(lo); }
string   los.Currency      (/*LFX_ORDER*/int lo[][], int i) {            return(GetCurrency(LFX.CurrencyId(los.Ticket(lo, i))));                                                                         LFX_ORDER.toStr(lo); }
int      los.CurrencyId    (/*LFX_ORDER*/int lo[][], int i) {                        return(LFX.CurrencyId(los.Ticket(lo, i)));                                                                          LFX_ORDER.toStr(lo); }
bool     los.IsPending     (/*LFX_ORDER*/int lo[][], int i) {                            return(OP_BUYLIMIT<=los.Type(lo, i) && los.Type(lo, i)<=OP_SELLSTOP);                                           LFX_ORDER.toStr(lo); }
bool     los.IsOpened      (/*LFX_ORDER*/int lo[][], int i) {             return((los.Type(lo, i)==OP_BUY || los.Type(lo, i)==OP_SELL) && los.OpenTime(lo, i) > 0);                                      LFX_ORDER.toStr(lo); }
bool     los.IsOpen        (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.IsOpened(lo, i) && !los.IsClosed(lo, i));                                                   LFX_ORDER.toStr(lo); }
bool     los.IsClosed      (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) > 0);                                                                       LFX_ORDER.toStr(lo); }
bool     los.IsOpenError   (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.OpenTime(lo, i) < 0);                                                                       LFX_ORDER.toStr(lo); }
bool     los.IsCloseError  (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) < 0);                                                                       LFX_ORDER.toStr(lo); }
double   los.OpenPrice     (/*LFX_ORDER*/int lo[][], int i) { double oLfx =los.OpenPriceLfx (lo, i), dev=los.Deviation(lo, i); if (!oLfx ) dev=0; return(NormalizeDouble(oLfx -dev, los.Digits(lo, i))); LFX_ORDER.toStr(lo); }
double   los.StopLoss      (/*LFX_ORDER*/int lo[][], int i) { double slLfx=los.StopLossLfx  (lo, i), dev=los.Deviation(lo, i); if (!slLfx) dev=0; return(NormalizeDouble(slLfx-dev, los.Digits(lo, i))); LFX_ORDER.toStr(lo); }
double   los.TakeProfit    (/*LFX_ORDER*/int lo[][], int i) { double tpLfx=los.TakeProfitLfx(lo, i), dev=los.Deviation(lo, i); if (!tpLfx) dev=0; return(NormalizeDouble(tpLfx-dev, los.Digits(lo, i))); LFX_ORDER.toStr(lo); }
double   los.ClosePrice    (/*LFX_ORDER*/int lo[][], int i) { double cLfx =los.ClosePriceLfx(lo, i), dev=los.Deviation(lo, i); if (!cLfx ) dev=0; return(NormalizeDouble(cLfx -dev, los.Digits(lo, i))); LFX_ORDER.toStr(lo); }
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


// Setter
int      lo.setTicket         (/*LFX_ORDER*/int &lo[],          int      ticket        ) { lo[ 0]    = ticket;                                                                                         return(ticket        ); LFX_ORDER.toStr(lo); }
int      lo.setType           (/*LFX_ORDER*/int &lo[],          int      type          ) { lo[ 1]    = type;                                                                                           return(type          ); LFX_ORDER.toStr(lo); }
double   lo.setUnits          (/*LFX_ORDER*/int &lo[],          double   units         ) { lo[ 2]    = MathRound(units *  10);                                                                         return(units         ); LFX_ORDER.toStr(lo); }
double   lo.setLots           (/*LFX_ORDER*/int &lo[],          double   lots          ) { lo[ 3]    = MathRound(lots  * 100);                                                                         return(lots          ); LFX_ORDER.toStr(lo); }
double   lo.setOpenEquity     (/*LFX_ORDER*/int &lo[],          double   openEquity    ) { lo[ 4]    = MathRound(openEquity * 100);                                                                    return(openEquity    ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenTime       (/*LFX_ORDER*/int &lo[],          datetime openTime      ) { lo[ 5]    = openTime;                                                                                       return(openTime      ); LFX_ORDER.toStr(lo); }
double   lo.setOpenPriceLfx   (/*LFX_ORDER*/int &lo[],          double   openPriceLfx  ) { lo[ 6]    = MathRound(openPriceLfx * MathPow(10, lo.Digits(lo)));                                           return(openPriceLfx  ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenPriceTime  (/*LFX_ORDER*/int &lo[],          datetime openPriceTime ) { lo[ 7]    = openPriceTime;                                                                                  return(openPriceTime ); LFX_ORDER.toStr(lo); }
double   lo.setStopLossLfx    (/*LFX_ORDER*/int &lo[],          double   stopLossLfx   ) { lo[ 8]    = MathRound(stopLossLfx * MathPow(10, lo.Digits(lo)));                                            return(stopLossLfx   ); LFX_ORDER.toStr(lo); }
datetime lo.setStopLossTime   (/*LFX_ORDER*/int &lo[],          datetime stopLossTime  ) { lo[ 9]    = stopLossTime;                                                                                   return(stopLossTime  ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfitLfx  (/*LFX_ORDER*/int &lo[],          double   takeProfitLfx ) { lo[10]    = MathRound(takeProfitLfx * MathPow(10, lo.Digits(lo)));                                          return(takeProfitLfx ); LFX_ORDER.toStr(lo); }
datetime lo.setTakeProfitTime (/*LFX_ORDER*/int &lo[],          datetime takeProfitTime) { lo[11]    = takeProfitTime;                                                                                 return(takeProfitTime); LFX_ORDER.toStr(lo); }
datetime lo.setCloseTime      (/*LFX_ORDER*/int &lo[],          datetime closeTime     ) { lo[12]    = closeTime;                                                                                      return(closeTime     ); LFX_ORDER.toStr(lo); }
double   lo.setClosePriceLfx  (/*LFX_ORDER*/int &lo[],          double   closePriceLfx ) { lo[13]    = MathRound(closePriceLfx * MathPow(10, lo.Digits(lo)));                                          return(closePriceLfx ); LFX_ORDER.toStr(lo); }
double   lo.setProfit         (/*LFX_ORDER*/int &lo[],          double   profit        ) { lo[14]    = MathRound(profit * 100);                                                                        return(profit        ); LFX_ORDER.toStr(lo); }
double   lo.setDeviation      (/*LFX_ORDER*/int &lo[],          double   deviation     ) { lo[15]    = MathRound(deviation * MathPow(10, lo.Digits(lo)));                                              return(deviation     ); LFX_ORDER.toStr(lo); }
string   lo.setComment        (/*LFX_ORDER*/int  lo[],          string   comment       ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("lo.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetStringAddress(comment), GetBufferAddress(lo)+64, StringLen(comment)+1);                                                                                                               return(comment       ); LFX_ORDER.toStr(lo); }
datetime lo.setVersion        (/*LFX_ORDER*/int &lo[],          datetime version       ) { lo[24]    = version;                                                                                        return(version       ); LFX_ORDER.toStr(lo); }
double   lo.setOpenPrice      (/*LFX_ORDER*/int &lo[],          double   openPrice     ) { double dev=lo.Deviation(lo); if (EQ(openPrice , 0)) dev=0; lo.setOpenPriceLfx (lo, openPrice +dev);         return(openPrice     ); LFX_ORDER.toStr(lo); }
double   lo.setStopLoss       (/*LFX_ORDER*/int &lo[],          double   stopLoss      ) { double dev=lo.Deviation(lo); if (EQ(stopLoss  , 0)) dev=0; lo.setStopLossLfx  (lo, stopLoss  +dev);         return(stopLoss      ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfit     (/*LFX_ORDER*/int &lo[],          double   takeProfit    ) { double dev=lo.Deviation(lo); if (EQ(takeProfit, 0)) dev=0; lo.setTakeProfitLfx(lo, takeProfit+dev);         return(takeProfit    ); LFX_ORDER.toStr(lo); }
double   lo.setClosePrice     (/*LFX_ORDER*/int &lo[],          double   closePrice    ) { double dev=lo.Deviation(lo); if (EQ(closePrice, 0)) dev=0; lo.setClosePriceLfx(lo, closePrice+dev);         return(closePrice    ); LFX_ORDER.toStr(lo); }

int      los.setTicket        (/*LFX_ORDER*/int &lo[][], int i, int      ticket        ) { lo[i][ 0] = ticket;                                                                                         return(ticket        ); LFX_ORDER.toStr(lo); }
int      los.setType          (/*LFX_ORDER*/int &lo[][], int i, int      type          ) { lo[i][ 1] = type;                                                                                           return(type          ); LFX_ORDER.toStr(lo); }
double   los.setUnits         (/*LFX_ORDER*/int &lo[][], int i, double   units         ) { lo[i][ 2] = MathRound(units *  10);                                                                         return(units         ); LFX_ORDER.toStr(lo); }
double   los.setLots          (/*LFX_ORDER*/int &lo[][], int i, double   lots          ) { lo[i][ 3] = MathRound(lots  * 100);                                                                         return(lots          ); LFX_ORDER.toStr(lo); }
double   los.setOpenEquity    (/*LFX_ORDER*/int &lo[][], int i, double   openEquity    ) { lo[i][ 4] = MathRound(openEquity * 100);                                                                    return(openEquity    ); LFX_ORDER.toStr(lo); }
datetime los.setOpenTime      (/*LFX_ORDER*/int &lo[][], int i, datetime openTime      ) { lo[i][ 5] = openTime;                                                                                       return(openTime      ); LFX_ORDER.toStr(lo); }
double   los.setOpenPriceLfx  (/*LFX_ORDER*/int &lo[][], int i, double   openPrice     ) { lo[i][ 6] = MathRound(openPrice  * MathPow(10, los.Digits(lo, i)));                                         return(openPrice     ); LFX_ORDER.toStr(lo); }
datetime los.setOpenPriceTime (/*LFX_ORDER*/int &lo[][], int i, datetime openPriceTime ) { lo[i][ 7] = openPriceTime;                                                                                  return(openPriceTime ); LFX_ORDER.toStr(lo); }
double   los.setStopLossLfx   (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss      ) { lo[i][ 8] = MathRound(stopLoss   * MathPow(10, los.Digits(lo, i)));                                         return(stopLoss      ); LFX_ORDER.toStr(lo); }
datetime los.setStopLossTime  (/*LFX_ORDER*/int &lo[][], int i, datetime stopLossTime  ) { lo[i][ 9] = stopLossTime;                                                                                   return(stopLossTime  ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfitLfx (/*LFX_ORDER*/int &lo[][], int i, double   takeProfit    ) { lo[i][10] = MathRound(takeProfit * MathPow(10, los.Digits(lo, i)));                                         return(takeProfit    ); LFX_ORDER.toStr(lo); }
datetime los.setTakeProfitTime(/*LFX_ORDER*/int &lo[][], int i, datetime takeProfitTime) { lo[i][11] = takeProfitTime;                                                                                 return(takeProfitTime); LFX_ORDER.toStr(lo); }
datetime los.setCloseTime     (/*LFX_ORDER*/int &lo[][], int i, datetime closeTime     ) { lo[i][12] = closeTime;                                                                                      return(closeTime     ); LFX_ORDER.toStr(lo); }
double   los.setClosePriceLfx (/*LFX_ORDER*/int &lo[][], int i, double   closePrice    ) { lo[i][13] = MathRound(closePrice * MathPow(10, los.Digits(lo, i)));                                         return(closePrice    ); LFX_ORDER.toStr(lo); }
double   los.setProfit        (/*LFX_ORDER*/int &lo[][], int i, double   profit        ) { lo[i][14] = MathRound(profit * 100);                                                                        return(profit        ); LFX_ORDER.toStr(lo); }
double   los.setDeviation     (/*LFX_ORDER*/int &lo[][], int i, double   deviation     ) { lo[i][15] = MathRound(deviation * MathPow(10, los.Digits(lo, i)));                                          return(deviation     ); LFX_ORDER.toStr(lo); }
string   los.setComment       (/*LFX_ORDER*/int  lo[][], int i, string   comment       ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_empty(catch("los.setComment()   too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_FUNCTION_PARAMVALUE));
   CopyMemory(GetStringAddress(comment), GetBufferAddress(lo)+ i*ArrayRange(lo, 1)*4 + 64, StringLen(comment)+1);                                                                                      return(comment       ); LFX_ORDER.toStr(lo); }
datetime los.setVersion       (/*LFX_ORDER*/int &lo[][], int i, datetime version       ) { lo[i][24] = version;                                                                                        return(version       ); LFX_ORDER.toStr(lo); }
double   los.setOpenPrice     (/*LFX_ORDER*/int &lo[][], int i, double   openPrice     ) { double dev=los.Deviation(lo, i); if (EQ(openPrice , 0)) dev=0; los.setOpenPriceLfx (lo, i, openPrice +dev); return(openPrice     ); LFX_ORDER.toStr(lo); }
double   los.setStopLoss      (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss      ) { double dev=los.Deviation(lo, i); if (EQ(stopLoss  , 0)) dev=0; los.setStopLossLfx  (lo, i, stopLoss  +dev); return(stopLoss      ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfit    (/*LFX_ORDER*/int &lo[][], int i, double   takeProfit    ) { double dev=los.Deviation(lo, i); if (EQ(takeProfit, 0)) dev=0; los.setTakeProfitLfx(lo, i, takeProfit+dev); return(takeProfit    ); LFX_ORDER.toStr(lo); }
double   los.setClosePrice    (/*LFX_ORDER*/int &lo[][], int i, double   closePrice    ) { double dev=los.Deviation(lo, i); if (EQ(closePrice, 0)) dev=0; los.setClosePriceLfx(lo, i, closePrice+dev); return(closePrice    ); LFX_ORDER.toStr(lo); }


/**
 * Gibt die lesbare Repräsentation einer oder mehrerer LFX_ORDER-Strukturen zurück.
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
      // lo ist einzelnes Struct LFX_ORDER (eine Dimension)
      digits      = lo.Digits(lo);
      pipDigits   = digits & (~1);
      priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      line        = StringConcatenate("{ticket="        ,                    lo.Ticket        (lo),
                                     ", currency=\""    ,                    lo.Currency      (lo), "\"",
                                     ", type="          , OperationTypeToStr(lo.Type          (lo)),
                                     ", units="         ,        NumberToStr(lo.Units         (lo), ".+"),
                                     ", lots="          ,        NumberToStr(lo.Lots          (lo), ".+"),
                                     ", openEquity="    ,        DoubleToStr(lo.OpenEquity    (lo), 2),
                                     ", openTime="      ,           ifString(lo.OpenTime      (lo), "'"+ TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL) +"'"+ ifString(lo.IsOpenError(lo), "(ERROR)", ""), "0"),
                                     ", openPrice="     ,        NumberToStr(lo.OpenPriceLfx  (lo), priceFormat),
                                     ", openPriceTime=" ,           ifString(lo.OpenPriceTime (lo), "'"+ TimeToStr(lo.OpenPriceTime(lo), TIME_FULL) +"'", "0"),
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
      // lo ist Struct-Array LFX_ORDER[] (zwei Dimensionen)
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
                                                  ", openEquity="    ,        DoubleToStr(los.OpenEquity    (lo, i), 2),
                                                  ", openTime="      ,           ifString(los.OpenTime      (lo, i), "'"+ TimeToStr(Abs(los.OpenTime(lo, i)), TIME_FULL) +"'"+ ifString(los.IsOpenError(lo, i), "(ERROR)", ""), "0"),
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


   // unnütze Compilerwarnungen unterdrücken
   int iNulls[];
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


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string BufferCharsToStr(int buffer[], int from, int length);
   void   CopyMemory(int source, int destination, int bytes);
   string GetCurrency(int id);
   string JoinStrings(string array[], string separator);
   string NumberToStr(double number, string format);
   string OperationTypeToStr(int type);

#import "MT4Lib.dll"
   int    GetBufferAddress(int buffer[]);
   int    GetStringAddress(string value);
#import


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "struct.LFX_ORDER.ex4"
//   // Getter
//   int      lo.Ticket            (/*LFX_ORDER*/int lo[]);
//   int      lo.Type              (/*LFX_ORDER*/int lo[]);
//   double   lo.Units             (/*LFX_ORDER*/int lo[]);
//   double   lo.Lots              (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenEquity        (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenTime          (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenPriceLfx      (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenPriceTime     (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLossLfx       (/*LFX_ORDER*/int lo[]);
//   datetime lo.StopLossTime      (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfitLfx     (/*LFX_ORDER*/int lo[]);
//   datetime lo.TakeProfitTime    (/*LFX_ORDER*/int lo[]);
//   datetime lo.CloseTime         (/*LFX_ORDER*/int lo[]);
//   double   lo.ClosePriceLfx     (/*LFX_ORDER*/int lo[]);
//   double   lo.Profit            (/*LFX_ORDER*/int lo[]);
//   double   lo.Deviation         (/*LFX_ORDER*/int lo[]);
//   string   lo.Comment           (/*LFX_ORDER*/int lo[]);
//   datetime lo.Version           (/*LFX_ORDER*/int lo[]);
//   int      lo.Digits            (/*LFX_ORDER*/int lo[]);
//   string   lo.Currency          (/*LFX_ORDER*/int lo[]);
//   int      lo.CurrencyId        (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsPending         (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpened          (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpen            (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsClosed          (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpenError       (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsCloseError      (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenPrice         (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLoss          (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfit        (/*LFX_ORDER*/int lo[]);
//   double   lo.ClosePrice        (/*LFX_ORDER*/int lo[]);

//   int      los.Ticket           (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Type             (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Units            (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Lots             (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenEquity       (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenTime         (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenPriceLfx     (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenPriceTime    (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLossLfx      (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.StopLossTime     (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfitLfx    (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.TakeProfitTime   (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.CloseTime        (/*LFX_ORDER*/int lo[][], int i);
//   double   los.ClosePriceLfx    (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Profit           (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Deviation        (/*LFX_ORDER*/int lo[][], int i);
//   string   los.Comment          (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.Version          (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Digits           (/*LFX_ORDER*/int lo[][], int i);
//   string   los.Currency         (/*LFX_ORDER*/int lo[][], int i);
//   int      los.CurrencyId       (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsPending        (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpened         (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpen           (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsClosed         (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpenError      (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsCloseError     (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenPrice        (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLoss         (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfit       (/*LFX_ORDER*/int lo[][], int i);
//   double   los.ClosePrice       (/*LFX_ORDER*/int lo[][], int i);

//   // Setter
//   int      lo.setTicket         (/*LFX_ORDER*/int lo[], int      ticket        );
//   int      lo.setType           (/*LFX_ORDER*/int lo[], int      type          );
//   double   lo.setUnits          (/*LFX_ORDER*/int lo[], double   units         );
//   double   lo.setLots           (/*LFX_ORDER*/int lo[], double   lots          );
//   double   lo.setOpenEquity     (/*LFX_ORDER*/int lo[], double   openEquity    );
//   datetime lo.setOpenTime       (/*LFX_ORDER*/int lo[], datetime openTime      );
//   double   lo.setOpenPriceLfx   (/*LFX_ORDER*/int lo[], double   openPriceLfx  );
//   datetime lo.setOpenPriceTime  (/*LFX_ORDER*/int lo[], datetime openPriceTime );
//   double   lo.setStopLossLfx    (/*LFX_ORDER*/int lo[], double   stopLossLfx   );
//   datetime lo.setStopLossTime   (/*LFX_ORDER*/int lo[], datetime stopLossTime  );
//   double   lo.setTakeProfitLfx  (/*LFX_ORDER*/int lo[], double   takeProfitLfx );
//   datetime lo.setTakeProfitTime (/*LFX_ORDER*/int lo[], datetime takeProfitTime);
//   datetime lo.setCloseTime      (/*LFX_ORDER*/int lo[], datetime closeTime     );
//   double   lo.setClosePriceLfx  (/*LFX_ORDER*/int lo[], double   closePriceLfx );
//   double   lo.setProfit         (/*LFX_ORDER*/int lo[], double   profit        );
//   double   lo.setDeviation      (/*LFX_ORDER*/int lo[], double   deviation     );
//   string   lo.setComment        (/*LFX_ORDER*/int lo[], string   comment       );
//   datetime lo.setVersion        (/*LFX_ORDER*/int lo[], datetime version       );
//   double   lo.setOpenPrice      (/*LFX_ORDER*/int lo[], double   openPrice     );
//   double   lo.setStopLoss       (/*LFX_ORDER*/int lo[], double   stopLoss      );
//   double   lo.setTakeProfit     (/*LFX_ORDER*/int lo[], double   takeProfit    );
//   double   lo.setClosePrice     (/*LFX_ORDER*/int lo[], double   closePrice    );

//   int      los.setTicket        (/*LFX_ORDER*/int lo[][], int i, int      ticket        );
//   int      los.setType          (/*LFX_ORDER*/int lo[][], int i, int      type          );
//   double   los.setUnits         (/*LFX_ORDER*/int lo[][], int i, double   units         );
//   double   los.setLots          (/*LFX_ORDER*/int lo[][], int i, double   lots          );
//   double   los.setOpenEquity    (/*LFX_ORDER*/int lo[][], int i, double   openEquity    );
//   datetime los.setOpenTime      (/*LFX_ORDER*/int lo[][], int i, datetime openTime      );
//   double   los.setOpenPriceLfx  (/*LFX_ORDER*/int lo[][], int i, double   openPrice     );
//   datetime los.setOpenPriceTime (/*LFX_ORDER*/int lo[][], int i, datetime openPriceTime );
//   double   los.setStopLossLfx   (/*LFX_ORDER*/int lo[][], int i, double   stopLoss      );
//   datetime los.setStopLossTime  (/*LFX_ORDER*/int lo[][], int i, datetime stopLossTime  );
//   double   los.setTakeProfitLfx (/*LFX_ORDER*/int lo[][], int i, double   takeProfit    );
//   datetime los.setTakeProfitTime(/*LFX_ORDER*/int lo[][], int i, datetime takeProfitTime);
//   datetime los.setCloseTime     (/*LFX_ORDER*/int lo[][], int i, datetime closeTime     );
//   double   los.setClosePriceLfx (/*LFX_ORDER*/int lo[][], int i, double   closePrice    );
//   double   los.setProfit        (/*LFX_ORDER*/int lo[][], int i, double   profit        );
//   double   los.setDeviation     (/*LFX_ORDER*/int lo[][], int i, double   deviation     );
//   string   los.setComment       (/*LFX_ORDER*/int lo[][], int i, string   comment       );
//   datetime los.setVersion       (/*LFX_ORDER*/int lo[][], int i, datetime version       );
//   double   los.setOpenPrice     (/*LFX_ORDER*/int lo[][], int i, double   openPrice     );
//   double   los.setStopLoss      (/*LFX_ORDER*/int lo[][], int i, double   stopLoss      );
//   double   los.setTakeProfit    (/*LFX_ORDER*/int lo[][], int i, double   takeProfit    );
//   double   los.setClosePrice    (/*LFX_ORDER*/int lo[][], int i, double   closePrice    );

//   string   LFX_ORDER.toStr(/*LFX_ORDER*/int lo[], bool debugOutput);
//#import
