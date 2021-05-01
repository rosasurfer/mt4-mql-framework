/**
 * Framework struct LFX_ORDER
 *
 * struct LFX_ORDER {
 *    int    ticket;                //   4         lo[ 0]      // LFX-Ticket, enthält Strategy- und Currency-ID
 *    int    type;                  //   4         lo[ 1]      // Ordertype (Operationtype)
 *    int    units;                 //   4         lo[ 2]      // Order-Units in Zehnteln einer Unit
 *    int    lots;                  //   4         lo[ 3]      // Ordervolumen in Hundertsteln eines Lots USD
 *    int    openEquity;            //   4         lo[ 4]      // Equity zum Open-Zeitpunkt in Hundertsteln der Account-Währung (inkl. unrealisierter Verluste, exkl. unrealisierter Gewinne)
 *    int    openTriggerTime        //   4         lo[ 5]      // Zeitpunkt des Erreichens eines Open-Limits in FXT
 *    int    openTime;              //   4         lo[ 6]      // OpenTime in FXT (negativ: Zeitpunkt eines Fehlers beim Öffnen der Order)
 *    int    openPrice;             //   4         lo[ 7]      // OpenPrice in Points
 *    int    takeProfitPrice;       //   4         lo[ 8]      // TakeProfit-Preis in Points
 *    int    takeProfitValue;       //   4         lo[ 9]      // TakeProfit-Value in Hundertsteln der Account-Währung
 *    int    takeProfitPercent;     //   4         lo[10]      // TakeProfit-Value in Hundertstel-Prozent von OpenEquity
 *    BOOL   takeProfitTriggered    //   4         lo[11]      // ob ein TakeProfit-Limit ausgelöst wurde
 *    int    stopLossPrice;         //   4         lo[12]      // StopLoss-Preis in Points
 *    int    stopLossValue;         //   4         lo[13]      // StopLoss-Value in Hundertsteln der Account-Währung
 *    int    stopLossPercent;       //   4         lo[14]      // StopLoss-Value in Hundertstel-Prozent von OpenEquity
 *    BOOL   stopLossTriggered      //   4         lo[15]      // ob ein StopLoss-Limit ausgelöst wurde
 *    int    closeTriggerTime       //   4         lo[16]      // Zeitpunkt des Erreichens eines Close-Limits in FXT
 *    int    closeTime;             //   4         lo[17]      // CloseTime in FXT (negativ: Zeitpunkt eines Fehlers beim Schließen der Order)
 *    int    closePrice;            //   4         lo[18]      // ClosePrice in Points
 *    int    profit;                //   4         lo[19]      // Profit in Hundertsteln der Account-Währung (realisiert oder unrealisiert)
 *    szchar comment[32];           //  32         lo[20]      // Kommentar, <NUL>-terminiert
 *    int    modificationTime;      //   4         lo[28]      // Zeitpunkt der letzten Änderung in FXT
 *    int    version;               //   4         lo[29]      // Version (fortlaufender Zähler)
 * } lo;                            // 120 byte = int[30]
 *
 *
 * Note: Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */
#define LFX_ORDER.ticket                0                      // Array-Offsets
#define LFX_ORDER.type                  1
#define LFX_ORDER.units                 2
#define LFX_ORDER.lots                  3
#define LFX_ORDER.openEquity            4
#define LFX_ORDER.openTriggerTime       5
#define LFX_ORDER.openTime              6
#define LFX_ORDER.openPrice             7
#define LFX_ORDER.takeProfitPrice       8
#define LFX_ORDER.takeProfitValue       9
#define LFX_ORDER.takeProfitPercent    10
#define LFX_ORDER.takeProfitTriggered  11
#define LFX_ORDER.stopLossPrice        12
#define LFX_ORDER.stopLossValue        13
#define LFX_ORDER.stopLossPercent      14
#define LFX_ORDER.stopLossTriggered    15
#define LFX_ORDER.closeTriggerTime     16
#define LFX_ORDER.closeTime            17
#define LFX_ORDER.closePrice           18
#define LFX_ORDER.profit               19
#define LFX_ORDER.comment              20
#define LFX_ORDER.modificationTime     28
#define LFX_ORDER.version              29


// Getter
int      lo.Ticket              (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.ticket             ]);                                                                      LFX_ORDER.toStr(lo); }
int      lo.Type                (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.type               ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.Units               (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[LFX_ORDER.units              ]/ 10., 1));                                                             LFX_ORDER.toStr(lo); }
double   lo.Lots                (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[LFX_ORDER.lots               ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
double   lo.OpenEquity          (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[LFX_ORDER.openEquity         ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
datetime lo.OpenTriggerTime     (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.openTriggerTime    ]);                                                                      LFX_ORDER.toStr(lo); }
datetime lo.OpenTime            (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.openTime           ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.OpenPrice           (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[LFX_ORDER.openPrice          ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.TakeProfitPrice     (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[LFX_ORDER.takeProfitPrice    ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.TakeProfitValue     (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[LFX_ORDER.takeProfitValue    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
double   lo.TakeProfitPercent   (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[LFX_ORDER.takeProfitPercent  ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
bool     lo.TakeProfitTriggered (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.takeProfitTriggered] != 0);                                                                 LFX_ORDER.toStr(lo); }
double   lo.StopLossPrice       (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[LFX_ORDER.stopLossPrice      ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.StopLossValue       (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[LFX_ORDER.stopLossValue      ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
double   lo.StopLossPercent     (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[LFX_ORDER.stopLossPercent    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
bool     lo.StopLossTriggered   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.stopLossTriggered  ] != 0);                                                                 LFX_ORDER.toStr(lo); }
datetime lo.CloseTriggerTime    (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.closeTriggerTime   ]);                                                                      LFX_ORDER.toStr(lo); }
datetime lo.CloseTime           (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.closeTime          ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.ClosePrice          (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[LFX_ORDER.closePrice         ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.Profit              (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[LFX_ORDER.profit             ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
string   lo.Comment             (/*LFX_ORDER*/int lo[]         ) {                        return(GetStringA(GetIntsAddress(lo) + LFX_ORDER.comment*4));                                                                             LFX_ORDER.toStr(lo); }
datetime lo.ModificationTime    (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.modificationTime   ]);                                                                      LFX_ORDER.toStr(lo); }
int      lo.Version             (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.version            ]);                                                                      LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions -----------------------------------------------------------------------------------------------------------------------------------------------------------------
int      lo.Digits              (/*LFX_ORDER*/int lo[]         ) {                                                  return(5);                                                                                                      LFX_ORDER.toStr(lo); }
string   lo.Currency            (/*LFX_ORDER*/int lo[]         ) {             return(GetCurrency(LFX.CurrencyId(lo.Ticket(lo))));                                                                                                  LFX_ORDER.toStr(lo); }
int      lo.CurrencyId          (/*LFX_ORDER*/int lo[]         ) {                         return(LFX.CurrencyId(lo.Ticket(lo)));                                                                                                   LFX_ORDER.toStr(lo); }
bool     lo.IsPendingOrder      (/*LFX_ORDER*/int lo[]         ) { if (!lo.IsClosed(lo)) {
                                                                      if (OP_BUYLIMIT<=lo.Type(lo) && lo.Type(lo)<=OP_SELLSTOP)                                                  return(true);
                                                                      if ((lo.Type(lo)==OP_BUY     || lo.Type(lo)==OP_SELL    ) && lo.OpenTriggerTime(lo) && lo.IsOpenError(lo)) return(true);
                                                                   }                                                                                                             return(false);                                     LFX_ORDER.toStr(lo); }
bool     lo.IsPosition          (/*LFX_ORDER*/int lo[]         ) {                  return((lo.Type(lo)==OP_BUY || lo.Type(lo)==OP_SELL) && lo.OpenTime(lo) > 0);                                                                   LFX_ORDER.toStr(lo); }
bool     lo.IsOpenPosition      (/*LFX_ORDER*/int lo[]         ) {                                    return(lo.IsPosition(lo) && !lo.IsClosed(lo));                                                                                LFX_ORDER.toStr(lo); }
bool     lo.IsPendingPosition   (/*LFX_ORDER*/int lo[]         ) {                                return(lo.IsOpenPosition(lo) && (lo.IsStopLoss(lo) || lo.IsTakeProfit(lo)));                                                      LFX_ORDER.toStr(lo); }
bool     lo.IsClosedPosition    (/*LFX_ORDER*/int lo[]         ) {                                    return(lo.IsPosition(lo) &&  lo.IsClosed(lo));                                                                                LFX_ORDER.toStr(lo); }
bool     lo.IsClosed            (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) > 0);                                                                                                LFX_ORDER.toStr(lo); }
bool     lo.IsTakeProfit        (/*LFX_ORDER*/int lo[]         ) {                             return(lo.IsTakeProfitPrice(lo) || lo.IsTakeProfitValue(lo) || lo.IsTakeProfitPercent(lo));                                          LFX_ORDER.toStr(lo); }
bool     lo.IsTakeProfitPrice   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.takeProfitPrice  ] != 0          );                                                         LFX_ORDER.toStr(lo); }
bool     lo.IsTakeProfitValue   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.takeProfitValue  ] != EMPTY_VALUE);                                                         LFX_ORDER.toStr(lo); }
bool     lo.IsTakeProfitPercent (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.takeProfitPercent] != EMPTY_VALUE);                                                         LFX_ORDER.toStr(lo); }
bool     lo.IsStopLoss          (/*LFX_ORDER*/int lo[]         ) {                               return(lo.IsStopLossPrice(lo) || lo.IsStopLossValue(lo) || lo.IsStopLossPercent(lo));                                              LFX_ORDER.toStr(lo); }
bool     lo.IsStopLossPrice     (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.stopLossPrice  ] != 0          );                                                           LFX_ORDER.toStr(lo); }
bool     lo.IsStopLossValue     (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.stopLossValue  ] != EMPTY_VALUE);                                                           LFX_ORDER.toStr(lo); }
bool     lo.IsStopLossPercent   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[LFX_ORDER.stopLossPercent] != EMPTY_VALUE);                                                           LFX_ORDER.toStr(lo); }
bool     lo.IsOpenError         (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.OpenTime(lo) < 0);                                                                                                LFX_ORDER.toStr(lo); }
bool     lo.IsCloseError        (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) < 0);                                                                                                LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.Ticket             (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.ticket             ]);                                                                   LFX_ORDER.toStr(lo); }
int      los.Type               (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.type               ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.Units              (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][LFX_ORDER.units              ]/ 10., 1));                                                          LFX_ORDER.toStr(lo); }
double   los.Lots               (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][LFX_ORDER.lots               ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
double   los.OpenEquity         (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][LFX_ORDER.openEquity         ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
datetime los.OpenTriggerTime    (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.openTriggerTime    ]);                                                                   LFX_ORDER.toStr(lo); }
datetime los.OpenTime           (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.openTime           ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.OpenPrice          (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][LFX_ORDER.openPrice          ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.TakeProfitPrice    (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][LFX_ORDER.takeProfitPrice    ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.TakeProfitValue    (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][LFX_ORDER.takeProfitValue    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
double   los.TakeProfitPercent  (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][LFX_ORDER.takeProfitPercent  ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
bool     los.TakeProfitTriggered(/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.takeProfitTriggered] != 0);                                                              LFX_ORDER.toStr(lo); }
double   los.StopLossPrice      (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][LFX_ORDER.stopLossPrice      ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.StopLossValue      (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][LFX_ORDER.stopLossValue      ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
double   los.StopLossPercent    (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][LFX_ORDER.stopLossPercent    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
bool     los.StopLossTriggered  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.stopLossTriggered  ] != 0);                                                              LFX_ORDER.toStr(lo); }
datetime los.CloseTriggerTime   (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.closeTriggerTime   ]);                                                                   LFX_ORDER.toStr(lo); }
datetime los.CloseTime          (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.closeTime          ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.ClosePrice         (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][LFX_ORDER.closePrice         ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.Profit             (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][LFX_ORDER.profit             ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
string   los.Comment            (/*LFX_ORDER*/int lo[][], int i) {                        return(GetStringA(GetIntsAddress(lo)+ (i*LFX_ORDER.intSize + LFX_ORDER.comment)*4));                                                      LFX_ORDER.toStr(lo); }
datetime los.ModificationTime   (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.modificationTime   ]);                                                                   LFX_ORDER.toStr(lo); }
int      los.Version            (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.version            ]);                                                                   LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions -----------------------------------------------------------------------------------------------------------------------------------------------------------------
int      los.Digits             (/*LFX_ORDER*/int lo[][], int i) {                                                  return(5);                                                                                                      LFX_ORDER.toStr(lo); }
string   los.Currency           (/*LFX_ORDER*/int lo[][], int i) {            return(GetCurrency(LFX.CurrencyId(los.Ticket(lo, i))));                                                                                               LFX_ORDER.toStr(lo); }
int      los.CurrencyId         (/*LFX_ORDER*/int lo[][], int i) {                        return(LFX.CurrencyId(los.Ticket(lo, i)));                                                                                                LFX_ORDER.toStr(lo); }
bool     los.IsPendingOrder     (/*LFX_ORDER*/int lo[][], int i) { if (!los.IsClosed(lo, i)) {
                                                                      if (OP_BUYLIMIT<=los.Type(lo, i) && los.Type(lo, i)<=OP_SELLSTOP)                                                          return(true);
                                                                      if ((los.Type(lo, i)==OP_BUY     || los.Type(lo, i)==OP_SELL    ) && los.OpenTriggerTime(lo, i) && los.IsOpenError(lo, i)) return(true);
                                                                   }                                                                                                                             return(false);                     LFX_ORDER.toStr(lo); }
bool     los.IsPosition         (/*LFX_ORDER*/int lo[][], int i) {             return((los.Type(lo, i)==OP_BUY || los.Type(lo, i)==OP_SELL) && los.OpenTime(lo, i) > 0);                                                            LFX_ORDER.toStr(lo); }
bool     los.IsOpenPosition     (/*LFX_ORDER*/int lo[][], int i) {                                   return(los.IsPosition(lo, i) && !los.IsClosed(lo, i));                                                                         LFX_ORDER.toStr(lo); }
bool     los.IsPendingPosition  (/*LFX_ORDER*/int lo[][], int i) {                               return(los.IsOpenPosition(lo, i) && (los.IsStopLoss(lo, i) || los.IsTakeProfit(lo, i)));                                           LFX_ORDER.toStr(lo); }
bool     los.IsClosedPosition   (/*LFX_ORDER*/int lo[][], int i) {                                   return(los.IsPosition(lo, i) &&  los.IsClosed(lo, i));                                                                         LFX_ORDER.toStr(lo); }
bool     los.IsClosed           (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) > 0);                                                                                             LFX_ORDER.toStr(lo); }
bool     los.IsTakeProfit       (/*LFX_ORDER*/int lo[][], int i) {                            return(los.IsTakeProfitPrice(lo, i) || los.IsTakeProfitValue(lo, i) || los.IsTakeProfitPercent(lo, i));                               LFX_ORDER.toStr(lo); }
bool     los.IsTakeProfitPrice  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.takeProfitPrice  ] != 0          );                                                      LFX_ORDER.toStr(lo); }
bool     los.IsTakeProfitValue  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.takeProfitValue  ] != EMPTY_VALUE);                                                      LFX_ORDER.toStr(lo); }
bool     los.IsTakeProfitPercent(/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.takeProfitPercent] != EMPTY_VALUE);                                                      LFX_ORDER.toStr(lo); }
bool     los.IsStopLoss         (/*LFX_ORDER*/int lo[][], int i) {                              return(los.IsStopLossPrice(lo, i) || los.IsStopLossValue(lo, i) || los.IsStopLossPercent(lo, i));                                   LFX_ORDER.toStr(lo); }
bool     los.IsStopLossPrice    (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.stopLossPrice  ] != 0          );                                                        LFX_ORDER.toStr(lo); }
bool     los.IsStopLossValue    (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.stopLossValue  ] != EMPTY_VALUE);                                                        LFX_ORDER.toStr(lo); }
bool     los.IsStopLossPercent  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][LFX_ORDER.stopLossPercent] != EMPTY_VALUE);                                                        LFX_ORDER.toStr(lo); }
bool     los.IsOpenError        (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.OpenTime(lo, i) < 0);                                                                                             LFX_ORDER.toStr(lo); }
bool     los.IsCloseError       (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) < 0);                                                                                             LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


// Setter
int      lo.setTicket              (/*LFX_ORDER*/int &lo[],          int      ticket             ) { int v=ticket;                                                                                lo[LFX_ORDER.ticket             ] = v;    return(ticket                  ); LFX_ORDER.toStr(lo); }
int      lo.setType                (/*LFX_ORDER*/int &lo[],          int      type               ) { int v=type;                                                                                  lo[LFX_ORDER.type               ] = v;    return(type                    ); LFX_ORDER.toStr(lo); }
double   lo.setUnits               (/*LFX_ORDER*/int &lo[],          double   units              ) { int v=MathRound(units      *  10);                                                           lo[LFX_ORDER.units              ] = v;    return(units                   ); LFX_ORDER.toStr(lo); }
double   lo.setLots                (/*LFX_ORDER*/int &lo[],          double   lots               ) { int v=MathRound(lots       * 100);                                                           lo[LFX_ORDER.lots               ] = v;    return(lots                    ); LFX_ORDER.toStr(lo); }
double   lo.setOpenEquity          (/*LFX_ORDER*/int &lo[],          double   openEquity         ) { int v=MathRound(openEquity * 100);                                                           lo[LFX_ORDER.openEquity         ] = v;    return(openEquity              ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenTriggerTime     (/*LFX_ORDER*/int &lo[],          datetime openTriggerTime    ) { int v=openTriggerTime;                                                                       lo[LFX_ORDER.openTriggerTime    ] = v;    return(openTriggerTime         ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenTime            (/*LFX_ORDER*/int &lo[],          datetime openTime           ) { int v=openTime;                                                                              lo[LFX_ORDER.openTime           ] = v;    return(openTime                ); LFX_ORDER.toStr(lo); }
double   lo.setOpenPrice           (/*LFX_ORDER*/int &lo[],          double   openPrice          ) { int v=MathRound(openPrice       * MathPow(10, lo.Digits(lo)));                               lo[LFX_ORDER.openPrice          ] = v;    return(openPrice               ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfitPrice     (/*LFX_ORDER*/int &lo[],          double   takeProfitPrice    ) { int v=MathRound(takeProfitPrice * MathPow(10, lo.Digits(lo)));                               lo[LFX_ORDER.takeProfitPrice    ] = v;    return(takeProfitPrice         ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfitValue     (/*LFX_ORDER*/int &lo[],          double   takeProfitValue    ) { int v=EMPTY_VALUE; if (takeProfitValue  !=EMPTY_VALUE) v=MathRound(takeProfitValue   * 100); lo[LFX_ORDER.takeProfitValue    ] = v;    return(takeProfitValue         ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfitPercent   (/*LFX_ORDER*/int &lo[],          double   takeProfitPercent  ) { int v=EMPTY_VALUE; if (takeProfitPercent!=EMPTY_VALUE) v=MathRound(takeProfitPercent * 100); lo[LFX_ORDER.takeProfitPercent  ] = v;    return(takeProfitPercent       ); LFX_ORDER.toStr(lo); }
bool     lo.setTakeProfitTriggered (/*LFX_ORDER*/int &lo[],          bool     takeProfitTriggered) { int v=takeProfitTriggered != 0;                                                              lo[LFX_ORDER.takeProfitTriggered] = v;    return(takeProfitTriggered != 0); LFX_ORDER.toStr(lo); }
double   lo.setStopLossPrice       (/*LFX_ORDER*/int &lo[],          double   stopLossPrice      ) { int v=MathRound(stopLossPrice   * MathPow(10, lo.Digits(lo)));                               lo[LFX_ORDER.stopLossPrice      ] = v;    return(stopLossPrice           ); LFX_ORDER.toStr(lo); }
double   lo.setStopLossValue       (/*LFX_ORDER*/int &lo[],          double   stopLossValue      ) { int v=EMPTY_VALUE; if (stopLossValue  !=EMPTY_VALUE) v=MathRound(stopLossValue   * 100);     lo[LFX_ORDER.stopLossValue      ] = v;    return(stopLossValue           ); LFX_ORDER.toStr(lo); }
double   lo.setStopLossPercent     (/*LFX_ORDER*/int &lo[],          double   stopLossPercent    ) { int v=EMPTY_VALUE; if (stopLossPercent!=EMPTY_VALUE) v=MathRound(stopLossPercent * 100);     lo[LFX_ORDER.stopLossPercent    ] = v;    return(stopLossPercent         ); LFX_ORDER.toStr(lo); }
bool     lo.setStopLossTriggered   (/*LFX_ORDER*/int &lo[],          bool     stopLossTriggered  ) { int v=stopLossTriggered != 0;                                                                lo[LFX_ORDER.stopLossTriggered  ] = v;    return(stopLossTriggered != 0  ); LFX_ORDER.toStr(lo); }
datetime lo.setCloseTriggerTime    (/*LFX_ORDER*/int &lo[],          datetime closeTriggerTime   ) { int v=closeTriggerTime;                                                                      lo[LFX_ORDER.closeTriggerTime   ] = v;    return(closeTriggerTime        ); LFX_ORDER.toStr(lo); }
datetime lo.setCloseTime           (/*LFX_ORDER*/int &lo[],          datetime closeTime          ) { int v=closeTime;                                                                             lo[LFX_ORDER.closeTime          ] = v;    return(closeTime               ); LFX_ORDER.toStr(lo); }
double   lo.setClosePrice          (/*LFX_ORDER*/int &lo[],          double   closePrice         ) { int v=MathRound(closePrice * MathPow(10, lo.Digits(lo)));                                    lo[LFX_ORDER.closePrice         ] = v;    return(closePrice              ); LFX_ORDER.toStr(lo); }
double   lo.setProfit              (/*LFX_ORDER*/int &lo[],          double   profit             ) { int v=MathRound(profit * 100);                                                               lo[LFX_ORDER.profit             ] = v;    return(profit                  ); LFX_ORDER.toStr(lo); }
string   lo.setComment             (/*LFX_ORDER*/int &lo[],          string   comment            ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if (StringLen(comment) > 31) return(_EMPTY_STR(catch("lo.setComment()  too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_PARAMETER));
   string array[]; ArrayResize(array, 1); array[0]=comment;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(lo) + LFX_ORDER.comment*4;
   CopyMemory(dest, src, StringLen(comment)+1);
   ArrayResize(array, 0);                                                                                                                                                                                                                     return(comment                 ); LFX_ORDER.toStr(lo); }
datetime lo.setModificationTime    (/*LFX_ORDER*/int &lo[],          datetime modificationTime   ) { int v=modificationTime;                                                                      lo[LFX_ORDER.modificationTime   ] = v;    return(modificationTime        ); LFX_ORDER.toStr(lo); }
int      lo.setVersion             (/*LFX_ORDER*/int &lo[],          int      version            ) { int v=version;                                                                               lo[LFX_ORDER.version            ] = v;    return(version                 ); LFX_ORDER.toStr(lo); }
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.setTicket             (/*LFX_ORDER*/int &lo[][], int i, int      ticket             ) { int v=ticket;                                                                                lo[i][LFX_ORDER.ticket             ] = v; return(ticket                  ); LFX_ORDER.toStr(lo); }
int      los.setType               (/*LFX_ORDER*/int &lo[][], int i, int      type               ) { int v=type;                                                                                  lo[i][LFX_ORDER.type               ] = v; return(type                    ); LFX_ORDER.toStr(lo); }
double   los.setUnits              (/*LFX_ORDER*/int &lo[][], int i, double   units              ) { int v=MathRound(units      *  10);                                                           lo[i][LFX_ORDER.units              ] = v; return(units                   ); LFX_ORDER.toStr(lo); }
double   los.setLots               (/*LFX_ORDER*/int &lo[][], int i, double   lots               ) { int v=MathRound(lots       * 100);                                                           lo[i][LFX_ORDER.lots               ] = v; return(lots                    ); LFX_ORDER.toStr(lo); }
double   los.setOpenEquity         (/*LFX_ORDER*/int &lo[][], int i, double   openEquity         ) { int v=MathRound(openEquity * 100);                                                           lo[i][LFX_ORDER.openEquity         ] = v; return(openEquity              ); LFX_ORDER.toStr(lo); }
datetime los.setOpenTriggerTime    (/*LFX_ORDER*/int &lo[][], int i, datetime openTriggerTime    ) { int v=openTriggerTime;                                                                       lo[i][LFX_ORDER.openTriggerTime    ] = v; return(openTriggerTime         ); LFX_ORDER.toStr(lo); }
datetime los.setOpenTime           (/*LFX_ORDER*/int &lo[][], int i, datetime openTime           ) { int v=openTime;                                                                              lo[i][LFX_ORDER.openTime           ] = v; return(openTime                ); LFX_ORDER.toStr(lo); }
double   los.setOpenPrice          (/*LFX_ORDER*/int &lo[][], int i, double   openPrice          ) { int v=MathRound(openPrice       * MathPow(10, los.Digits(lo, i)));                           lo[i][LFX_ORDER.openPrice          ] = v; return(openPrice               ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfitPrice    (/*LFX_ORDER*/int &lo[][], int i, double   takeProfitPrice    ) { int v=MathRound(takeProfitPrice * MathPow(10, los.Digits(lo, i)));                           lo[i][LFX_ORDER.takeProfitPrice    ] = v; return(takeProfitPrice         ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfitValue    (/*LFX_ORDER*/int &lo[][], int i, double   takeProfitValue    ) { int v=EMPTY_VALUE; if (takeProfitValue  !=EMPTY_VALUE) v=MathRound(takeProfitValue   * 100); lo[i][LFX_ORDER.takeProfitValue    ] = v; return(takeProfitValue         ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfitPercent  (/*LFX_ORDER*/int &lo[][], int i, double   takeProfitPercent  ) { int v=EMPTY_VALUE; if (takeProfitPercent!=EMPTY_VALUE) v=MathRound(takeProfitPercent * 100); lo[i][LFX_ORDER.takeProfitPercent  ] = v; return(takeProfitPercent       ); LFX_ORDER.toStr(lo); }
bool     los.setTakeProfitTriggered(/*LFX_ORDER*/int &lo[][], int i, bool     takeProfitTriggered) { int v=takeProfitTriggered != 0;                                                              lo[i][LFX_ORDER.takeProfitTriggered] = v; return(takeProfitTriggered != 0); LFX_ORDER.toStr(lo); }
double   los.setStopLossPrice      (/*LFX_ORDER*/int &lo[][], int i, double   stopLossPrice      ) { int v=MathRound(stopLossPrice   * MathPow(10, los.Digits(lo, i)));                           lo[i][LFX_ORDER.stopLossPrice      ] = v; return(stopLossPrice           ); LFX_ORDER.toStr(lo); }
double   los.setStopLossValue      (/*LFX_ORDER*/int &lo[][], int i, double   stopLossValue      ) { int v=EMPTY_VALUE; if (stopLossValue  !=EMPTY_VALUE) v=MathRound(stopLossValue   * 100);     lo[i][LFX_ORDER.stopLossValue      ] = v; return(stopLossValue           ); LFX_ORDER.toStr(lo); }
double   los.setStopLossPercent    (/*LFX_ORDER*/int &lo[][], int i, double   stopLossPercent    ) { int v=EMPTY_VALUE; if (stopLossPercent!=EMPTY_VALUE) v=MathRound(stopLossPercent * 100);     lo[i][LFX_ORDER.stopLossPercent    ] = v; return(stopLossPercent         ); LFX_ORDER.toStr(lo); }
bool     los.setStopLossTriggered  (/*LFX_ORDER*/int &lo[][], int i, bool     stopLossTriggered  ) { int v=stopLossTriggered != 0;                                                                lo[i][LFX_ORDER.stopLossTriggered  ] = v; return(stopLossTriggered != 0  ); LFX_ORDER.toStr(lo); }
datetime los.setCloseTriggerTime   (/*LFX_ORDER*/int &lo[][], int i, datetime closeTriggerTime   ) { int v=closeTriggerTime;                                                                      lo[i][LFX_ORDER.closeTriggerTime   ] = v; return(closeTriggerTime        ); LFX_ORDER.toStr(lo); }
datetime los.setCloseTime          (/*LFX_ORDER*/int &lo[][], int i, datetime closeTime          ) { int v=closeTime;                                                                             lo[i][LFX_ORDER.closeTime          ] = v; return(closeTime               ); LFX_ORDER.toStr(lo); }
double   los.setClosePrice         (/*LFX_ORDER*/int &lo[][], int i, double   closePrice         ) { int v=MathRound(closePrice * MathPow(10, los.Digits(lo, i)));                                lo[i][LFX_ORDER.closePrice         ] = v; return(closePrice              ); LFX_ORDER.toStr(lo); }
double   los.setProfit             (/*LFX_ORDER*/int &lo[][], int i, double   profit             ) { int v=MathRound(profit * 100);                                                               lo[i][LFX_ORDER.profit             ] = v; return(profit                  ); LFX_ORDER.toStr(lo); }
string   los.setComment            (/*LFX_ORDER*/int &lo[][], int i, string   comment            ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_EMPTY_STR(catch("los.setComment()  too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_PARAMETER));
   string array[]; ArrayResize(array, 1); array[0]=comment;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(lo) + (i*LFX_ORDER.intSize + LFX_ORDER.comment)*4;
   CopyMemory(dest, src, StringLen(comment)+1);
   ArrayResize(array, 0);                                                                                                                                                                                                                     return(comment                 ); LFX_ORDER.toStr(lo); }
datetime los.setModificationTime   (/*LFX_ORDER*/int &lo[][], int i, datetime modificationTime   ) { int v=modificationTime;                                                                      lo[i][LFX_ORDER.modificationTime   ] = v; return(modificationTime        ); LFX_ORDER.toStr(lo); }
int      los.setVersion            (/*LFX_ORDER*/int &lo[][], int i, int      version            ) { int v=version;                                                                               lo[i][LFX_ORDER.version            ] = v; return(version                 ); LFX_ORDER.toStr(lo); }
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Gibt die lesbare Repräsentation einer oder mehrerer struct LFX_ORDER zurück.
 *
 * @param  int  lo[]        - struct LFX_ORDER
 * @param  bool outputDebug - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string - lesbarer String oder Leerstring, falls ein fehler auftrat
 */
string LFX_ORDER.toStr(/*LFX_ORDER*/int lo[], bool outputDebug=false) {
   outputDebug = outputDebug!=0;

   int dimensions = ArrayDimension(lo);

   if (dimensions > 2)                                    return(_EMPTY_STR(catch("LFX_ORDER.toStr(1)  too many dimensions of parameter lo = "+ dimensions, ERR_INVALID_PARAMETER)));
   if (ArrayRange(lo, dimensions-1) != LFX_ORDER.intSize) return(_EMPTY_STR(catch("LFX_ORDER.toStr(2)  invalid size of parameter lo ("+ ArrayRange(lo, dimensions-1) +")", ERR_INVALID_PARAMETER)));

   int    digits, pipDigits;
   string priceFormat, line, lines[]; ArrayResize(lines, 0);


   if (dimensions == 1) {
      // lo ist einzelnes Struct LFX_ORDER (eine Dimension)
      digits      = lo.Digits(lo);
      pipDigits   = digits & (~1);
      priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      line        = StringConcatenate("{ticket="             ,                    lo.Ticket             (lo),
                                     ", currency=\""         ,                    lo.Currency           (lo), "\"",
                                     ", type="               , OperationTypeToStr(lo.Type               (lo)),
                                     ", units="              ,        NumberToStr(lo.Units              (lo), ".+"),
                                     ", lots="               ,        NumberToStr(lo.Lots               (lo), ".+"),
                                     ", openEquity="         ,        DoubleToStr(lo.OpenEquity         (lo), 2),
                                     ", openTriggerTime="    ,           ifString(lo.OpenTriggerTime    (lo), "'"+ TimeToStr(lo.OpenTriggerTime(lo), TIME_FULL) +" FXT'", "NULL"),
                                     ", openTime="           ,           ifString(lo.OpenTime           (lo), "'"+ TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL) +" FXT'"+ ifString(lo.IsOpenError(lo), "(ERROR)", ""), "NULL"),
                                     ", openPrice="          ,        NumberToStr(lo.OpenPrice          (lo), priceFormat),
                                     ", takeProfitPrice="    ,           ifString(lo.IsTakeProfitPrice  (lo), NumberToStr(lo.TakeProfitPrice  (lo), priceFormat), "NULL"),
                                     ", takeProfitValue="    ,           ifString(lo.IsTakeProfitValue  (lo), DoubleToStr(lo.TakeProfitValue  (lo), 2), "NULL"),
                                     ", takeProfitPercent="  ,           ifString(lo.IsTakeProfitPercent(lo), DoubleToStr(lo.TakeProfitPercent(lo), 2), "NULL"),
                                     ", takeProfitTriggered=",          BoolToStr(lo.TakeProfitTriggered(lo)),
                                     ", stopLossPrice="      ,           ifString(lo.IsStopLossPrice    (lo), NumberToStr(lo.StopLossPrice  (lo), priceFormat), "NULL"),
                                     ", stopLossValue="      ,           ifString(lo.IsStopLossValue    (lo), DoubleToStr(lo.StopLossValue  (lo), 2), "NULL"),
                                     ", stopLossPercent="    ,           ifString(lo.IsStopLossPercent  (lo), DoubleToStr(lo.StopLossPercent(lo), 2), "NULL"),
                                     ", stopLossTriggered="  ,          BoolToStr(lo.StopLossTriggered  (lo)),
                                     ", closeTriggerTime="   ,           ifString(lo.CloseTriggerTime   (lo), "'"+ TimeToStr(lo.CloseTriggerTime(lo), TIME_FULL) +" FXT'", "NULL"),
                                     ", closeTime="          ,           ifString(lo.CloseTime          (lo), "'"+ TimeToStr(lo.CloseTime(lo), TIME_FULL) +" FXT'", "NULL"),
                                     ", closePrice="         ,           ifString(lo.ClosePrice         (lo)!=0, NumberToStr(lo.ClosePrice(lo), priceFormat), "NULL"),
                                     ", profit="             ,        DoubleToStr(lo.Profit             (lo), 2),
                                     ", comment=\""          ,                    lo.Comment            (lo), "\"",
                                     ", modificationTime="   ,           ifString(lo.ModificationTime   (lo), "'"+ TimeToStr(lo.ModificationTime(lo), TIME_FULL) +" FXT'", "NULL"),
                                     ", version="            ,                    lo.Version            (lo), "}");
      if (outputDebug)
         debug("LFX_ORDER.toStr()  "+ line);
      ArrayPushString(lines, line);
   }
   else {
      // lo ist Struct-Array LFX_ORDER[] (zwei Dimensionen)
      int size = ArrayRange(lo, 0);

      for (int i=0; i < size; i++) {
         digits      = los.Digits(lo, i);
         pipDigits   = digits & (~1);
         priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
         line        = StringConcatenate("[", i, "]={ticket="             ,                    los.Ticket             (lo, i),
                                                  ", currency=\""         ,                    los.Currency           (lo, i), "\"",
                                                  ", type="               , OperationTypeToStr(los.Type               (lo, i)),
                                                  ", units="              ,        NumberToStr(los.Units              (lo, i), ".+"),
                                                  ", lots="               ,        NumberToStr(los.Lots               (lo, i), ".+"),
                                                  ", openEquity="         ,        DoubleToStr(los.OpenEquity         (lo, i), 2),
                                                  ", openTriggerTime="    ,           ifString(los.OpenTriggerTime    (lo, i), "'"+ TimeToStr(los.OpenTriggerTime(lo, i), TIME_FULL) +" FXT'", "NULL"),
                                                  ", openTime="           ,           ifString(los.OpenTime           (lo, i), "'"+ TimeToStr(Abs(los.OpenTime(lo, i)), TIME_FULL) +" FXT'"+ ifString(los.IsOpenError(lo, i), "(ERROR)", ""), "NULL"),
                                                  ", openPrice="          ,        NumberToStr(los.OpenPrice          (lo, i), priceFormat),
                                                  ", takeProfitPrice="    ,           ifString(los.IsTakeProfitPrice  (lo, i), NumberToStr(los.TakeProfitPrice  (lo, i), priceFormat), "NULL"),
                                                  ", takeProfitValue="    ,           ifString(los.IsTakeProfitValue  (lo, i), DoubleToStr(los.TakeProfitValue  (lo, i), 2), "NULL"),
                                                  ", takeProfitPercent="  ,           ifString(los.IsTakeProfitPercent(lo, i), DoubleToStr(los.TakeProfitPercent(lo, i), 2), "NULL"),
                                                  ", takeProfitTriggered=",          BoolToStr(los.TakeProfitTriggered(lo, i)),
                                                  ", stopLossPrice="      ,           ifString(los.IsStopLossPrice    (lo, i), NumberToStr(los.StopLossPrice  (lo, i), priceFormat), "NULL"),
                                                  ", stopLossValue="      ,           ifString(los.IsStopLossValue    (lo, i), DoubleToStr(los.StopLossValue  (lo, i), 2), "NULL"),
                                                  ", stopLossPercent="    ,           ifString(los.IsStopLossPercent  (lo, i), DoubleToStr(los.StopLossPercent(lo, i), 2), "NULL"),
                                                  ", stopLossTriggered="  ,          BoolToStr(los.StopLossTriggered  (lo, i)),
                                                  ", closeTriggerTime="   ,           ifString(los.CloseTriggerTime   (lo, i), "'"+ TimeToStr(los.CloseTriggerTime(lo, i), TIME_FULL) +" FXT'", "NULL"),
                                                  ", closeTime="          ,           ifString(los.CloseTime          (lo, i), "'"+ TimeToStr(los.CloseTime(lo, i), TIME_FULL) +" FXT'", "NULL"),
                                                  ", closePrice="         ,           ifString(los.ClosePrice         (lo, i)!=0, NumberToStr(los.ClosePrice(lo, i), priceFormat), "NULL"),
                                                  ", profit="             ,        DoubleToStr(los.Profit             (lo, i), 2),
                                                  ", comment=\""          ,                    los.Comment            (lo, i), "\"",
                                                  ", modificationTime="   ,           ifString(los.ModificationTime   (lo, i), "'"+ TimeToStr(los.ModificationTime(lo, i), TIME_FULL) +" FXT'", "NULL"),
                                                  ", version="            ,                    los.Version            (lo, i), "}");
         if (outputDebug)
            debug("LFX_ORDER.toStr()  "+ line);
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("LFX_ORDER.toStr(3)");
   return(output);


   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   int iNulls[];
   lo.ClosePrice            (iNulls);       los.ClosePrice            (iNulls, NULL);
   lo.CloseTime             (iNulls);       los.CloseTime             (iNulls, NULL);
   lo.CloseTriggerTime      (iNulls);       los.CloseTriggerTime      (iNulls, NULL);
   lo.Comment               (iNulls);       los.Comment               (iNulls, NULL);
   lo.Currency              (iNulls);       los.Currency              (iNulls, NULL);
   lo.CurrencyId            (iNulls);       los.CurrencyId            (iNulls, NULL);
   lo.Digits                (iNulls);       los.Digits                (iNulls, NULL);
   lo.IsClosed              (iNulls);       los.IsClosed              (iNulls, NULL);
   lo.IsClosedPosition      (iNulls);       los.IsClosedPosition      (iNulls, NULL);
   lo.IsCloseError          (iNulls);       los.IsCloseError          (iNulls, NULL);
   lo.IsOpenError           (iNulls);       los.IsOpenError           (iNulls, NULL);
   lo.IsOpenPosition        (iNulls);       los.IsOpenPosition        (iNulls, NULL);
   lo.IsPendingPosition     (iNulls);       los.IsPendingPosition     (iNulls, NULL);
   lo.IsPendingOrder        (iNulls);       los.IsPendingOrder        (iNulls, NULL);
   lo.IsPosition            (iNulls);       los.IsPosition            (iNulls, NULL);
   lo.IsStopLoss            (iNulls);       los.IsStopLoss            (iNulls, NULL);
   lo.IsStopLossPercent     (iNulls);       los.IsStopLossPercent     (iNulls, NULL);
   lo.IsStopLossPrice       (iNulls);       los.IsStopLossPrice       (iNulls, NULL);
   lo.IsStopLossValue       (iNulls);       los.IsStopLossValue       (iNulls, NULL);
   lo.IsTakeProfit          (iNulls);       los.IsTakeProfit          (iNulls, NULL);
   lo.IsTakeProfitPercent   (iNulls);       los.IsTakeProfitPercent   (iNulls, NULL);
   lo.IsTakeProfitPrice     (iNulls);       los.IsTakeProfitPrice     (iNulls, NULL);
   lo.IsTakeProfitValue     (iNulls);       los.IsTakeProfitValue     (iNulls, NULL);
   lo.Lots                  (iNulls);       los.Lots                  (iNulls, NULL);
   lo.ModificationTime      (iNulls);       los.ModificationTime      (iNulls, NULL);
   lo.OpenEquity            (iNulls);       los.OpenEquity            (iNulls, NULL);
   lo.OpenPrice             (iNulls);       los.OpenPrice             (iNulls, NULL);
   lo.OpenTime              (iNulls);       los.OpenTime              (iNulls, NULL);
   lo.OpenTriggerTime       (iNulls);       los.OpenTriggerTime       (iNulls, NULL);
   lo.Profit                (iNulls);       los.Profit                (iNulls, NULL);
   lo.StopLossPercent       (iNulls);       los.StopLossPercent       (iNulls, NULL);
   lo.StopLossPrice         (iNulls);       los.StopLossPrice         (iNulls, NULL);
   lo.StopLossTriggered     (iNulls);       los.StopLossTriggered     (iNulls, NULL);
   lo.StopLossValue         (iNulls);       los.StopLossValue         (iNulls, NULL);
   lo.TakeProfitPercent     (iNulls);       los.TakeProfitPercent     (iNulls, NULL);
   lo.TakeProfitPrice       (iNulls);       los.TakeProfitPrice       (iNulls, NULL);
   lo.TakeProfitTriggered   (iNulls);       los.TakeProfitTriggered   (iNulls, NULL);
   lo.TakeProfitValue       (iNulls);       los.TakeProfitValue       (iNulls, NULL);
   lo.Ticket                (iNulls);       los.Ticket                (iNulls, NULL);
   lo.Type                  (iNulls);       los.Type                  (iNulls, NULL);
   lo.Units                 (iNulls);       los.Units                 (iNulls, NULL);
   lo.Version               (iNulls);       los.Version               (iNulls, NULL);

   lo.setClosePrice         (iNulls, NULL); los.setClosePrice         (iNulls, NULL, NULL);
   lo.setCloseTime          (iNulls, NULL); los.setCloseTime          (iNulls, NULL, NULL);
   lo.setCloseTriggerTime   (iNulls, NULL); los.setCloseTriggerTime   (iNulls, NULL, NULL);
   lo.setComment            (iNulls, NULL); los.setComment            (iNulls, NULL, NULL);
   lo.setLots               (iNulls, NULL); los.setLots               (iNulls, NULL, NULL);
   lo.setModificationTime   (iNulls, NULL); los.setModificationTime   (iNulls, NULL, NULL);
   lo.setOpenEquity         (iNulls, NULL); los.setOpenEquity         (iNulls, NULL, NULL);
   lo.setOpenPrice          (iNulls, NULL); los.setOpenPrice          (iNulls, NULL, NULL);
   lo.setOpenTime           (iNulls, NULL); los.setOpenTime           (iNulls, NULL, NULL);
   lo.setOpenTriggerTime    (iNulls, NULL); los.setOpenTriggerTime    (iNulls, NULL, NULL);
   lo.setProfit             (iNulls, NULL); los.setProfit             (iNulls, NULL, NULL);
   lo.setStopLossPercent    (iNulls, NULL); los.setStopLossPercent    (iNulls, NULL, NULL);
   lo.setStopLossPrice      (iNulls, NULL); los.setStopLossPrice      (iNulls, NULL, NULL);
   lo.setStopLossTriggered  (iNulls, NULL); los.setStopLossTriggered  (iNulls, NULL, NULL);
   lo.setStopLossValue      (iNulls, NULL); los.setStopLossValue      (iNulls, NULL, NULL);
   lo.setTakeProfitPercent  (iNulls, NULL); los.setTakeProfitPercent  (iNulls, NULL, NULL);
   lo.setTakeProfitPrice    (iNulls, NULL); los.setTakeProfitPrice    (iNulls, NULL, NULL);
   lo.setTakeProfitTriggered(iNulls, NULL); los.setTakeProfitTriggered(iNulls, NULL, NULL);
   lo.setTakeProfitValue    (iNulls, NULL); los.setTakeProfitValue    (iNulls, NULL, NULL);
   lo.setTicket             (iNulls, NULL); los.setTicket             (iNulls, NULL, NULL);
   lo.setType               (iNulls, NULL); los.setType               (iNulls, NULL, NULL);
   lo.setUnits              (iNulls, NULL); los.setUnits              (iNulls, NULL, NULL);
   lo.setVersion            (iNulls, NULL); los.setVersion            (iNulls, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "rsfMT4Expander.dll"
//   // Getter
//   int      lo.Ticket                 (/*LFX_ORDER*/int lo[]);
//   int      lo.Type                   (/*LFX_ORDER*/int lo[]);
//   double   lo.Units                  (/*LFX_ORDER*/int lo[]);
//   double   lo.Lots                   (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenEquity             (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenTriggerTime        (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenTime               (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenPrice              (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfitPrice        (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfitValue        (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfitPercent      (/*LFX_ORDER*/int lo[]);
//   bool     lo.TakeProfitTriggered    (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLossPrice          (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLossValue          (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLossPercent        (/*LFX_ORDER*/int lo[]);
//   bool     lo.StopLossTriggered      (/*LFX_ORDER*/int lo[]);
//   datetime lo.CloseTriggerTime       (/*LFX_ORDER*/int lo[]);
//   datetime lo.CloseTime              (/*LFX_ORDER*/int lo[]);
//   double   lo.ClosePrice             (/*LFX_ORDER*/int lo[]);
//   double   lo.Profit                 (/*LFX_ORDER*/int lo[]);
//   string   lo.Comment                (/*LFX_ORDER*/int lo[]);
//   datetime lo.ModificationTime       (/*LFX_ORDER*/int lo[]);
//   int      lo.Version                (/*LFX_ORDER*/int lo[]);
//   int      lo.Digits                 (/*LFX_ORDER*/int lo[]);
//   string   lo.Currency               (/*LFX_ORDER*/int lo[]);
//   int      lo.CurrencyId             (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsPendingOrder         (/*LFX_ORDER*/int lo[]);              // ohne Fehler gilt: lo.IsPendingOrder() == !lo.IsPosition()
//   bool     lo.IsPosition             (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpenPosition         (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsPendingPosition      (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsClosedPosition       (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsClosed               (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsTakeProfit           (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsTakeProfitPrice      (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsTakeProfitValue      (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsTakeProfitPercent    (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsStopLoss             (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsStopLossPrice        (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsStopLossValue        (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsStopLossPercent      (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpenError            (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsCloseError           (/*LFX_ORDER*/int lo[]);

//   int      los.Ticket                (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Type                  (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Units                 (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Lots                  (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenEquity            (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenTriggerTime       (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenTime              (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenPrice             (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfitPrice       (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfitValue       (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfitPercent     (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.TakeProfitTriggered   (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLossPrice         (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLossValue         (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLossPercent       (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.StopLossTriggered     (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.CloseTriggerTime      (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.CloseTime             (/*LFX_ORDER*/int lo[][], int i);
//   double   los.ClosePrice            (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Profit                (/*LFX_ORDER*/int lo[][], int i);
//   string   los.Comment               (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.ModificationTime      (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Version               (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Digits                (/*LFX_ORDER*/int lo[][], int i);
//   string   los.Currency              (/*LFX_ORDER*/int lo[][], int i);
//   int      los.CurrencyId            (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsPendingOrder        (/*LFX_ORDER*/int lo[][], int i);     // ohne Fehler gilt: los.IsPendingOrder() == !los.IsPosition()
//   bool     los.IsPosition            (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpenPosition        (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsPendingPosition     (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsClosedPosition      (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsClosed              (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsTakeProfit          (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsTakeProfitPrice     (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsTakeProfitValue     (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsTakeProfitPercent   (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsStopLoss            (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsStopLossPrice       (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsStopLossValue       (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsStopLossPercent     (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpenError           (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsCloseError          (/*LFX_ORDER*/int lo[][], int i);

//   // Setter
//   int      lo.setTicket              (/*LFX_ORDER*/int lo[], int      ticket             );
//   int      lo.setType                (/*LFX_ORDER*/int lo[], int      type               );
//   double   lo.setUnits               (/*LFX_ORDER*/int lo[], double   units              );
//   double   lo.setLots                (/*LFX_ORDER*/int lo[], double   lots               );
//   double   lo.setOpenEquity          (/*LFX_ORDER*/int lo[], double   openEquity         );
//   datetime lo.setOpenTriggerTime     (/*LFX_ORDER*/int lo[], datetime openTriggerTime    );
//   datetime lo.setOpenTime            (/*LFX_ORDER*/int lo[], datetime openTime           );
//   double   lo.setOpenPrice           (/*LFX_ORDER*/int lo[], double   openPrice          );
//   double   lo.setTakeProfitPrice     (/*LFX_ORDER*/int lo[], double   takeProfitPrice    );
//   double   lo.setTakeProfitValue     (/*LFX_ORDER*/int lo[], double   takeProfitValue    );
//   double   lo.setTakeProfitPercent   (/*LFX_ORDER*/int lo[], double   takeProfitPercent  );
//   bool     lo.setTakeProfitTriggered (/*LFX_ORDER*/int lo[], int      takeProfitTriggered);
//   double   lo.setStopLossPrice       (/*LFX_ORDER*/int lo[], double   stopLossPrice      );
//   double   lo.setStopLossValue       (/*LFX_ORDER*/int lo[], double   stopLossValue      );
//   double   lo.setStopLossPercent     (/*LFX_ORDER*/int lo[], double   stopLossPercent    );
//   bool     lo.setStopLossTriggered   (/*LFX_ORDER*/int lo[], int      stopLossTriggered  );
//   datetime lo.setCloseTriggerTime    (/*LFX_ORDER*/int lo[], datetime closeTriggerTime   );
//   datetime lo.setCloseTime           (/*LFX_ORDER*/int lo[], datetime closeTime          );
//   double   lo.setClosePrice          (/*LFX_ORDER*/int lo[], double   closePrice         );
//   double   lo.setProfit              (/*LFX_ORDER*/int lo[], double   profit             );
//   string   lo.setComment             (/*LFX_ORDER*/int lo[], string   comment            );
//   datetime lo.setModificationTime    (/*LFX_ORDER*/int lo[], datetime modificationTime   );
//   int      lo.setVersion             (/*LFX_ORDER*/int lo[], int      version            );

//   int      los.setTicket             (/*LFX_ORDER*/int lo[][], int i, int      ticket             );
//   int      los.setType               (/*LFX_ORDER*/int lo[][], int i, int      type               );
//   double   los.setUnits              (/*LFX_ORDER*/int lo[][], int i, double   units              );
//   double   los.setLots               (/*LFX_ORDER*/int lo[][], int i, double   lots               );
//   double   los.setOpenEquity         (/*LFX_ORDER*/int lo[][], int i, double   openEquity         );
//   datetime los.setOpenTriggerTime    (/*LFX_ORDER*/int lo[][], int i, datetime openTriggerTime    );
//   datetime los.setOpenTime           (/*LFX_ORDER*/int lo[][], int i, datetime openTime           );
//   double   los.setOpenPrice          (/*LFX_ORDER*/int lo[][], int i, double   openPrice          );
//   double   los.setTakeProfitPrice    (/*LFX_ORDER*/int lo[][], int i, double   takeProfitPrice    );
//   double   los.setTakeProfitValue    (/*LFX_ORDER*/int lo[][], int i, double   takeProfitValue    );
//   double   los.setTakeProfitPercent  (/*LFX_ORDER*/int lo[][], int i, double   takeProfitPercent  );
//   bool     los.setTakeProfitTriggered(/*LFX_ORDER*/int lo[][], int i, int      takeProfitTriggered);
//   double   los.setStopLossPrice      (/*LFX_ORDER*/int lo[][], int i, double   stopLossPrice      );
//   double   los.setStopLossValue      (/*LFX_ORDER*/int lo[][], int i, double   stopLossValue      );
//   double   los.setStopLossPercent    (/*LFX_ORDER*/int lo[][], int i, double   stopLossPercent    );
//   bool     los.setStopLossTriggered  (/*LFX_ORDER*/int lo[][], int i, int      stopLossTriggered  );
//   datetime los.setCloseTriggerTime   (/*LFX_ORDER*/int lo[][], int i, datetime closeTriggerTime   );
//   datetime los.setCloseTime          (/*LFX_ORDER*/int lo[][], int i, datetime closeTime          );
//   double   los.setClosePrice         (/*LFX_ORDER*/int lo[][], int i, double   closePrice         );
//   double   los.setProfit             (/*LFX_ORDER*/int lo[][], int i, double   profit             );
//   string   los.setComment            (/*LFX_ORDER*/int lo[][], int i, string   comment            );
//   datetime los.setModificationTime   (/*LFX_ORDER*/int lo[][], int i, datetime modificationTime   );
//   int      los.setVersion            (/*LFX_ORDER*/int lo[][], int i, int      version            );

//   string   LFX_ORDER.toStr(/*LFX_ORDER*/int lo[], int outputDebug);
//#import
