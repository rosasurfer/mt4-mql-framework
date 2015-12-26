/**
 * MQL structure LFX_ORDER
 *
 * struct LFX_ORDER {
 *    int    ticket;                //   4         lo[ 0]      // Ticket, enthält Strategy- und Currency-ID
 *    int    type;                  //   4         lo[ 1]      // Operation-Type
 *    int    units;                 //   4         lo[ 2]      // Order-Units in Zehnteln einer Unit
 *    int    lots;                  //   4         lo[ 3]      // Ordervolumen in Hundertsteln eines Lots USD
 *    int    openEquity;            //   4         lo[ 4]      // Equity zum Open-Zeitpunkt in Hundertsteln der Account-Währung (inkl. unrealisierter Verluste, exkl. unrealisierter Gewinne)
 *    int    openTime;              //   4         lo[ 5]      // OpenTime in GMT (negativ: Zeitpunkt eines Fehlers beim Öffnen der Order)
 *    int    openPrice;             //   4         lo[ 6]      // OpenPrice in Points
 *    int    openTriggerTime        //   4         lo[ 7]      // Zeitpunkt des Erreichens eines Open-Limits in GMT
 *    int    stopLoss;              //   4         lo[ 8]      // StopLoss-Preis in Points
 *    int    stopLossValue;         //   4         lo[ 9]      // StopLoss-Value in Hundertsteln der Account-Währung
 *    BOOL   stopLossTriggered      //   4         lo[10]      // ob ein StopLoss-Limit ausgelöst wurde
 *    int    takeProfit;            //   4         lo[11]      // TakeProfit-Preis in Points
 *    int    takeProfitValue;       //   4         lo[12]      // TakeProfit-Value in Hundertsteln der Account-Währung
 *    BOOL   takeProfitTriggered    //   4         lo[13]      // ob ein TakeProfit-Limit ausgelöst wurde
 *    int    closeTriggerTime       //   4         lo[14]      // Zeitpunkt des Erreichens eines Close-Limits in GMT
 *    int    closeTime;             //   4         lo[15]      // CloseTime in GMT (negativ: Zeitpunkt eines Fehlers beim Schließen der Order)
 *    int    closePrice;            //   4         lo[16]      // ClosePrice in Points
 *    int    profit;                //   4         lo[17]      // Profit in Hundertsteln der Account-Währung (realisiert oder unrealisiert)
 *    szchar comment[32];           //  32         lo[18]      // Kommentar, <NUL>-terminiert
 *    int    modificationTime;      //   4         lo[26]      // Zeitpunkt der letzten Änderung in GMT
 *    int    version;               //   4         lo[27]      // Version (fortlaufender Zähler)
 * } lo;                            // 112 byte = int[28]
 *
 *
 * Note: Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */
#define I_LFX_ORDER.ticket                0                    // Offsets
#define I_LFX_ORDER.type                  1
#define I_LFX_ORDER.units                 2
#define I_LFX_ORDER.lots                  3
#define I_LFX_ORDER.openEquity            4
#define I_LFX_ORDER.openTime              5
#define I_LFX_ORDER.openPrice             6
#define I_LFX_ORDER.openTriggerTime       7
#define I_LFX_ORDER.stopLoss              8
#define I_LFX_ORDER.stopLossValue         9
#define I_LFX_ORDER.stopLossTriggered    10
#define I_LFX_ORDER.takeProfit           11
#define I_LFX_ORDER.takeProfitValue      12
#define I_LFX_ORDER.takeProfitTriggered  13
#define I_LFX_ORDER.closeTriggerTime     14
#define I_LFX_ORDER.closeTime            15
#define I_LFX_ORDER.closePrice           16
#define I_LFX_ORDER.profit               17
#define I_LFX_ORDER.comment              18
#define I_LFX_ORDER.modificationTime     26
#define I_LFX_ORDER.version              27


// Getter
int      lo.Ticket              (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.ticket             ]);                                                                      LFX_ORDER.toStr(lo); }
int      lo.Type                (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.type               ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.Units               (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[I_LFX_ORDER.units              ]/ 10., 1));                                                             LFX_ORDER.toStr(lo); }
double   lo.Lots                (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[I_LFX_ORDER.lots               ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
double   lo.OpenEquity          (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[I_LFX_ORDER.openEquity         ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
datetime lo.OpenTime            (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.openTime           ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.OpenPrice           (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[I_LFX_ORDER.openPrice          ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
datetime lo.OpenTriggerTime     (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.openTriggerTime    ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.StopLoss            (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[I_LFX_ORDER.stopLoss           ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.StopLossValue       (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[I_LFX_ORDER.stopLossValue      ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
bool     lo.StopLossTriggered   (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.stopLossTriggered  ] != 0);                                                                 LFX_ORDER.toStr(lo); }
double   lo.TakeProfit          (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[I_LFX_ORDER.takeProfit         ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.TakeProfitValue     (/*LFX_ORDER*/int lo[]         ) {                                                   int v=lo[I_LFX_ORDER.takeProfitValue    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2));    LFX_ORDER.toStr(lo); }
bool     lo.TakeProfitTriggered (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.takeProfitTriggered] != 0);                                                                 LFX_ORDER.toStr(lo); }
datetime lo.CloseTriggerTime    (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.closeTriggerTime   ]);                                                                      LFX_ORDER.toStr(lo); }
datetime lo.CloseTime           (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.closeTime          ]);                                                                      LFX_ORDER.toStr(lo); }
double   lo.ClosePrice          (/*LFX_ORDER*/int lo[]         ) { int digits=lo.Digits(lo);        return(NormalizeDouble(lo[I_LFX_ORDER.closePrice         ]/MathPow(10, digits), digits));                                         LFX_ORDER.toStr(lo); }
double   lo.Profit              (/*LFX_ORDER*/int lo[]         ) {                                  return(NormalizeDouble(lo[I_LFX_ORDER.profit             ]/100., 2));                                                             LFX_ORDER.toStr(lo); }
string   lo.Comment             (/*LFX_ORDER*/int lo[]         ) {                         return(GetString(GetIntsAddress(lo) + I_LFX_ORDER.comment*4));                                                                             LFX_ORDER.toStr(lo); }
datetime lo.ModificationTime    (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.modificationTime   ]);                                                                      LFX_ORDER.toStr(lo); }
int      lo.Version             (/*LFX_ORDER*/int lo[]         ) {                                                  return(lo[I_LFX_ORDER.version            ]);                                                                      LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions -----------------------------------------------------------------------------------------------------------------------------------------------------------------
int      lo.Digits              (/*LFX_ORDER*/int lo[]         ) {                   return(ifInt(LFX.CurrencyId(lo.Ticket(lo))==CID_JPY, 3, 5));                                                                                     LFX_ORDER.toStr(lo); }
string   lo.Currency            (/*LFX_ORDER*/int lo[]         ) {             return(GetCurrency(LFX.CurrencyId(lo.Ticket(lo))));                                                                                                    LFX_ORDER.toStr(lo); }
int      lo.CurrencyId          (/*LFX_ORDER*/int lo[]         ) {                         return(LFX.CurrencyId(lo.Ticket(lo)));                                                                                                     LFX_ORDER.toStr(lo); }
bool     lo.IsPending           (/*LFX_ORDER*/int lo[]         ) {                             return(OP_BUYLIMIT<=lo.Type(lo) && lo.Type(lo)<=OP_SELLSTOP && !lo.IsClosed(lo));                                                      LFX_ORDER.toStr(lo); }
bool     lo.IsOpened            (/*LFX_ORDER*/int lo[]         ) {                  return((lo.Type(lo)==OP_BUY || lo.Type(lo)==OP_SELL) && lo.OpenTime(lo) > 0);                                                                     LFX_ORDER.toStr(lo); }
bool     lo.IsOpen              (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.IsOpened(lo) && !lo.IsClosed(lo));                                                                                  LFX_ORDER.toStr(lo); }
bool     lo.IsClosed            (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) > 0);                                                                                                  LFX_ORDER.toStr(lo); }
bool     lo.IsOpenError         (/*LFX_ORDER*/int lo[]         ) {                                      return(lo.OpenTime(lo) < 0);                                                                                                  LFX_ORDER.toStr(lo); }
bool     lo.IsCloseError        (/*LFX_ORDER*/int lo[]         ) {                                     return(lo.CloseTime(lo) < 0);                                                                                                  LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.Ticket             (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.ticket             ]);                                                                   LFX_ORDER.toStr(lo); }
int      los.Type               (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.type               ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.Units              (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][I_LFX_ORDER.units              ]/ 10., 1));                                                          LFX_ORDER.toStr(lo); }
double   los.Lots               (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][I_LFX_ORDER.lots               ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
double   los.OpenEquity         (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][I_LFX_ORDER.openEquity         ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
datetime los.OpenTime           (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.openTime           ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.OpenPrice          (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][I_LFX_ORDER.openPrice          ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
datetime los.OpenTriggerTime    (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.openTriggerTime    ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.StopLoss           (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][I_LFX_ORDER.stopLoss           ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.StopLossValue      (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][I_LFX_ORDER.stopLossValue      ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
bool     los.StopLossTriggered  (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.stopLossTriggered  ] != 0);                                                              LFX_ORDER.toStr(lo); }
double   los.TakeProfit         (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][I_LFX_ORDER.takeProfit         ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.TakeProfitValue    (/*LFX_ORDER*/int lo[][], int i) {                                                   int v=lo[i][I_LFX_ORDER.takeProfitValue    ]; if (v==EMPTY_VALUE) return(v); return(NormalizeDouble(v/100., 2)); LFX_ORDER.toStr(lo); }
bool     los.TakeProfitTriggered(/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.takeProfitTriggered] != 0);                                                              LFX_ORDER.toStr(lo); }
datetime los.CloseTriggerTime   (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.closeTriggerTime   ]);                                                                   LFX_ORDER.toStr(lo); }
datetime los.CloseTime          (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.closeTime          ]);                                                                   LFX_ORDER.toStr(lo); }
double   los.ClosePrice         (/*LFX_ORDER*/int lo[][], int i) { int digits=los.Digits(lo ,i);    return(NormalizeDouble(lo[i][I_LFX_ORDER.closePrice         ]/MathPow(10, digits), digits));                                      LFX_ORDER.toStr(lo); }
double   los.Profit             (/*LFX_ORDER*/int lo[][], int i) {                                  return(NormalizeDouble(lo[i][I_LFX_ORDER.profit             ]/100., 2));                                                          LFX_ORDER.toStr(lo); }
string   los.Comment            (/*LFX_ORDER*/int lo[][], int i) {                         return(GetString(GetIntsAddress(lo)+ i*LFX_ORDER.intSize*4 + I_LFX_ORDER.comment*4));                                                      LFX_ORDER.toStr(lo); }
datetime los.ModificationTime   (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.modificationTime   ]);                                                                   LFX_ORDER.toStr(lo); }
int      los.Version            (/*LFX_ORDER*/int lo[][], int i) {                                                  return(lo[i][I_LFX_ORDER.version            ]);                                                                   LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------- Helper Functions -----------------------------------------------------------------------------------------------------------------------------------------------------------------
int      los.Digits             (/*LFX_ORDER*/int lo[][], int i) {                  return(ifInt(LFX.CurrencyId(los.Ticket(lo, i))==CID_JPY, 3, 5));                                                                                  LFX_ORDER.toStr(lo); }
string   los.Currency           (/*LFX_ORDER*/int lo[][], int i) {            return(GetCurrency(LFX.CurrencyId(los.Ticket(lo, i))));                                                                                                 LFX_ORDER.toStr(lo); }
int      los.CurrencyId         (/*LFX_ORDER*/int lo[][], int i) {                        return(LFX.CurrencyId(los.Ticket(lo, i)));                                                                                                  LFX_ORDER.toStr(lo); }
bool     los.IsPending          (/*LFX_ORDER*/int lo[][], int i) {                            return(OP_BUYLIMIT<=los.Type(lo, i) && los.Type(lo, i)<=OP_SELLSTOP && !los.IsClosed(lo, i));                                           LFX_ORDER.toStr(lo); }
bool     los.IsOpened           (/*LFX_ORDER*/int lo[][], int i) {             return((los.Type(lo, i)==OP_BUY || los.Type(lo, i)==OP_SELL) && los.OpenTime(lo, i) > 0);                                                              LFX_ORDER.toStr(lo); }
bool     los.IsOpen             (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.IsOpened(lo, i) && !los.IsClosed(lo, i));                                                                           LFX_ORDER.toStr(lo); }
bool     los.IsClosed           (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) > 0);                                                                                               LFX_ORDER.toStr(lo); }
bool     los.IsOpenError        (/*LFX_ORDER*/int lo[][], int i) {                                     return(los.OpenTime(lo, i) < 0);                                                                                               LFX_ORDER.toStr(lo); }
bool     los.IsCloseError       (/*LFX_ORDER*/int lo[][], int i) {                                    return(los.CloseTime(lo, i) < 0);                                                                                               LFX_ORDER.toStr(lo); }
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


// Setter
int      lo.setTicket              (/*LFX_ORDER*/int &lo[],          int      ticket             ) { int v=ticket;                                                                            lo[I_LFX_ORDER.ticket             ] = v;    return(ticket                  ); LFX_ORDER.toStr(lo); }
int      lo.setType                (/*LFX_ORDER*/int &lo[],          int      type               ) { int v=type;                                                                              lo[I_LFX_ORDER.type               ] = v;    return(type                    ); LFX_ORDER.toStr(lo); }
double   lo.setUnits               (/*LFX_ORDER*/int &lo[],          double   units              ) { int v=MathRound(units      *  10);                                                       lo[I_LFX_ORDER.units              ] = v;    return(units                   ); LFX_ORDER.toStr(lo); }
double   lo.setLots                (/*LFX_ORDER*/int &lo[],          double   lots               ) { int v=MathRound(lots       * 100);                                                       lo[I_LFX_ORDER.lots               ] = v;    return(lots                    ); LFX_ORDER.toStr(lo); }
double   lo.setOpenEquity          (/*LFX_ORDER*/int &lo[],          double   openEquity         ) { int v=MathRound(openEquity * 100);                                                       lo[I_LFX_ORDER.openEquity         ] = v;    return(openEquity              ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenTime            (/*LFX_ORDER*/int &lo[],          datetime openTime           ) { int v=openTime;                                                                          lo[I_LFX_ORDER.openTime           ] = v;    return(openTime                ); LFX_ORDER.toStr(lo); }
double   lo.setOpenPrice           (/*LFX_ORDER*/int &lo[],          double   openPrice          ) { int v=MathRound(openPrice  * MathPow(10, lo.Digits(lo)));                                lo[I_LFX_ORDER.openPrice          ] = v;    return(openPrice               ); LFX_ORDER.toStr(lo); }
datetime lo.setOpenTriggerTime     (/*LFX_ORDER*/int &lo[],          datetime openTriggerTime    ) { int v=openTriggerTime;                                                                   lo[I_LFX_ORDER.openTriggerTime    ] = v;    return(openTriggerTime         ); LFX_ORDER.toStr(lo); }
double   lo.setStopLoss            (/*LFX_ORDER*/int &lo[],          double   stopLoss           ) { int v=MathRound(stopLoss   * MathPow(10, lo.Digits(lo)));                                lo[I_LFX_ORDER.stopLoss           ] = v;    return(stopLoss                ); LFX_ORDER.toStr(lo); }
double   lo.setStopLossValue       (/*LFX_ORDER*/int &lo[],          double   stopLossValue      ) { int v=EMPTY_VALUE; if (stopLossValue  !=EMPTY_VALUE) v=MathRound(stopLossValue   * 100); lo[I_LFX_ORDER.stopLossValue      ] = v;    return(stopLossValue           ); LFX_ORDER.toStr(lo); }
bool     lo.setStopLossTriggered   (/*LFX_ORDER*/int &lo[],          bool     stopLossTriggered  ) { int v=stopLossTriggered != 0;                                                            lo[I_LFX_ORDER.stopLossTriggered  ] = v;    return(stopLossTriggered != 0  ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfit          (/*LFX_ORDER*/int &lo[],          double   takeProfit         ) { int v=MathRound(takeProfit * MathPow(10, lo.Digits(lo)));                                lo[I_LFX_ORDER.takeProfit         ] = v;    return(takeProfit              ); LFX_ORDER.toStr(lo); }
double   lo.setTakeProfitValue     (/*LFX_ORDER*/int &lo[],          double   takeProfitValue    ) { int v=EMPTY_VALUE; if (takeProfitValue!=EMPTY_VALUE) v=MathRound(takeProfitValue * 100); lo[I_LFX_ORDER.takeProfitValue    ] = v;    return(takeProfitValue         ); LFX_ORDER.toStr(lo); }
bool     lo.setTakeProfitTriggered (/*LFX_ORDER*/int &lo[],          bool     takeProfitTriggered) { int v=takeProfitTriggered != 0;                                                          lo[I_LFX_ORDER.takeProfitTriggered] = v;    return(takeProfitTriggered != 0); LFX_ORDER.toStr(lo); }
datetime lo.setCloseTriggerTime    (/*LFX_ORDER*/int &lo[],          datetime closeTriggerTime   ) { int v=closeTriggerTime;                                                                  lo[I_LFX_ORDER.closeTriggerTime   ] = v;    return(closeTriggerTime        ); LFX_ORDER.toStr(lo); }
datetime lo.setCloseTime           (/*LFX_ORDER*/int &lo[],          datetime closeTime          ) { int v=closeTime;                                                                         lo[I_LFX_ORDER.closeTime          ] = v;    return(closeTime               ); LFX_ORDER.toStr(lo); }
double   lo.setClosePrice          (/*LFX_ORDER*/int &lo[],          double   closePrice         ) { int v=MathRound(closePrice * MathPow(10, lo.Digits(lo)));                                lo[I_LFX_ORDER.closePrice         ] = v;    return(closePrice              ); LFX_ORDER.toStr(lo); }
double   lo.setProfit              (/*LFX_ORDER*/int &lo[],          double   profit             ) { int v=MathRound(profit * 100);                                                           lo[I_LFX_ORDER.profit             ] = v;    return(profit                  ); LFX_ORDER.toStr(lo); }
string   lo.setComment             (/*LFX_ORDER*/int &lo[],          string   comment            ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if (StringLen(comment) > 31) return(_EMPTY_STR(catch("lo.setComment()  too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_PARAMETER));
   int src  = GetStringAddress(comment);
   int dest = GetIntsAddress(lo) + I_LFX_ORDER.comment*4;
   CopyMemory(dest, src, StringLen(comment)+1);                                                                                                                                                                                           return(comment                 ); LFX_ORDER.toStr(lo); }
datetime lo.setModificationTime    (/*LFX_ORDER*/int &lo[],          datetime modificationTime   ) { int v=modificationTime;                                                                  lo[I_LFX_ORDER.modificationTime   ] = v;    return(modificationTime        ); LFX_ORDER.toStr(lo); }
int      lo.setVersion             (/*LFX_ORDER*/int &lo[],          int      version            ) { int v=version;                                                                           lo[I_LFX_ORDER.version            ] = v;    return(version                 ); LFX_ORDER.toStr(lo); }
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      los.setTicket             (/*LFX_ORDER*/int &lo[][], int i, int      ticket             ) { int v=ticket;                                                                            lo[i][I_LFX_ORDER.ticket             ] = v; return(ticket                  ); LFX_ORDER.toStr(lo); }
int      los.setType               (/*LFX_ORDER*/int &lo[][], int i, int      type               ) { int v=type;                                                                              lo[i][I_LFX_ORDER.type               ] = v; return(type                    ); LFX_ORDER.toStr(lo); }
double   los.setUnits              (/*LFX_ORDER*/int &lo[][], int i, double   units              ) { int v=MathRound(units      *  10);                                                       lo[i][I_LFX_ORDER.units              ] = v; return(units                   ); LFX_ORDER.toStr(lo); }
double   los.setLots               (/*LFX_ORDER*/int &lo[][], int i, double   lots               ) { int v=MathRound(lots       * 100);                                                       lo[i][I_LFX_ORDER.lots               ] = v; return(lots                    ); LFX_ORDER.toStr(lo); }
double   los.setOpenEquity         (/*LFX_ORDER*/int &lo[][], int i, double   openEquity         ) { int v=MathRound(openEquity * 100);                                                       lo[i][I_LFX_ORDER.openEquity         ] = v; return(openEquity              ); LFX_ORDER.toStr(lo); }
datetime los.setOpenTime           (/*LFX_ORDER*/int &lo[][], int i, datetime openTime           ) { int v=openTime;                                                                          lo[i][I_LFX_ORDER.openTime           ] = v; return(openTime                ); LFX_ORDER.toStr(lo); }
double   los.setOpenPrice          (/*LFX_ORDER*/int &lo[][], int i, double   openPrice          ) { int v=MathRound(openPrice  * MathPow(10, los.Digits(lo, i)));                            lo[i][I_LFX_ORDER.openPrice          ] = v; return(openPrice               ); LFX_ORDER.toStr(lo); }
datetime los.setOpenTriggerTime    (/*LFX_ORDER*/int &lo[][], int i, datetime openTriggerTime    ) { int v=openTriggerTime;                                                                   lo[i][I_LFX_ORDER.openTriggerTime    ] = v; return(openTriggerTime         ); LFX_ORDER.toStr(lo); }
double   los.setStopLoss           (/*LFX_ORDER*/int &lo[][], int i, double   stopLoss           ) { int v=MathRound(stopLoss   * MathPow(10, los.Digits(lo, i)));                            lo[i][I_LFX_ORDER.stopLoss           ] = v; return(stopLoss                ); LFX_ORDER.toStr(lo); }
double   los.setStopLossValue      (/*LFX_ORDER*/int &lo[][], int i, double   stopLossValue      ) { int v=EMPTY_VALUE; if (stopLossValue  !=EMPTY_VALUE) v=MathRound(stopLossValue   * 100); lo[i][I_LFX_ORDER.stopLossValue      ] = v; return(stopLossValue           ); LFX_ORDER.toStr(lo); }
bool     los.setStopLossTriggered  (/*LFX_ORDER*/int &lo[][], int i, bool     stopLossTriggered  ) { int v=stopLossTriggered != 0;                                                            lo[i][I_LFX_ORDER.stopLossTriggered  ] = v; return(stopLossTriggered != 0  ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfit         (/*LFX_ORDER*/int &lo[][], int i, double   takeProfit         ) { int v=MathRound(takeProfit * MathPow(10, los.Digits(lo, i)));                            lo[i][I_LFX_ORDER.takeProfit         ] = v; return(takeProfit              ); LFX_ORDER.toStr(lo); }
double   los.setTakeProfitValue    (/*LFX_ORDER*/int &lo[][], int i, double   takeProfitValue    ) { int v=EMPTY_VALUE; if (takeProfitValue!=EMPTY_VALUE) v=MathRound(takeProfitValue * 100); lo[i][I_LFX_ORDER.takeProfitValue    ] = v; return(takeProfitValue         ); LFX_ORDER.toStr(lo); }
bool     los.setTakeProfitTriggered(/*LFX_ORDER*/int &lo[][], int i, bool     takeProfitTriggered) { int v=takeProfitTriggered != 0;                                                          lo[i][I_LFX_ORDER.takeProfitTriggered] = v; return(takeProfitTriggered != 0); LFX_ORDER.toStr(lo); }
datetime los.setCloseTriggerTime   (/*LFX_ORDER*/int &lo[][], int i, datetime closeTriggerTime   ) { int v=closeTriggerTime;                                                                  lo[i][I_LFX_ORDER.closeTriggerTime   ] = v; return(closeTriggerTime        ); LFX_ORDER.toStr(lo); }
datetime los.setCloseTime          (/*LFX_ORDER*/int &lo[][], int i, datetime closeTime          ) { int v=closeTime;                                                                         lo[i][I_LFX_ORDER.closeTime          ] = v; return(closeTime               ); LFX_ORDER.toStr(lo); }
double   los.setClosePrice         (/*LFX_ORDER*/int &lo[][], int i, double   closePrice         ) { int v=MathRound(closePrice * MathPow(10, los.Digits(lo, i)));                            lo[i][I_LFX_ORDER.closePrice         ] = v; return(closePrice              ); LFX_ORDER.toStr(lo); }
double   los.setProfit             (/*LFX_ORDER*/int &lo[][], int i, double   profit             ) { int v=MathRound(profit * 100);                                                           lo[i][I_LFX_ORDER.profit             ] = v; return(profit                  ); LFX_ORDER.toStr(lo); }
string   los.setComment            (/*LFX_ORDER*/int &lo[][], int i, string   comment            ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > 31) return(_EMPTY_STR(catch("los.setComment()  too long parameter comment = \""+ comment +"\" (maximum 31 chars)"), ERR_INVALID_PARAMETER));
   int src  = GetStringAddress(comment);
   int dest = GetIntsAddress(lo) + i*LFX_ORDER.intSize*4 + I_LFX_ORDER.comment*4;
   CopyMemory(dest, src, StringLen(comment)+1);                                                                                                                                                                                           return(comment                 ); LFX_ORDER.toStr(lo); }
datetime los.setModificationTime   (/*LFX_ORDER*/int &lo[][], int i, datetime modificationTime   ) { int v=modificationTime;                                                                  lo[i][I_LFX_ORDER.modificationTime   ] = v; return(modificationTime        ); LFX_ORDER.toStr(lo); }
int      los.setVersion            (/*LFX_ORDER*/int &lo[][], int i, int      version            ) { int v=version;                                                                           lo[i][I_LFX_ORDER.version            ] = v; return(version                 ); LFX_ORDER.toStr(lo); }
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Gibt die lesbare Repräsentation einer oder mehrerer LFX_ORDER-Strukturen zurück.
 *
 * @param  int  lo[]        - LFX_ORDER
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
                                     ", openTime="           ,           ifString(lo.OpenTime           (lo), "'"+ TimeToStr(Abs(lo.OpenTime(lo)), TIME_FULL) +"'"+ ifString(lo.IsOpenError(lo), "(ERROR)", ""), "0"),
                                     ", openPrice="          ,        NumberToStr(lo.OpenPrice          (lo), priceFormat),
                                     ", openTriggerTime="    ,           ifString(lo.OpenTriggerTime    (lo), "'"+ TimeToStr(lo.OpenTriggerTime(lo), TIME_FULL) +"'", "0"),
                                     ", stopLoss="           ,           ifString(lo.StopLoss           (lo), NumberToStr(lo.StopLoss(lo), priceFormat), "0"),
                                     ", stopLossValue="      ,           ifString(lo.StopLossValue      (lo)==EMPTY_VALUE, "NULL", DoubleToStr(lo.StopLossValue(lo), 2)),
                                     ", stopLossTriggered="  ,          BoolToStr(lo.StopLossTriggered  (lo)),
                                     ", takeProfit="         ,           ifString(lo.TakeProfit         (lo), NumberToStr(lo.TakeProfit(lo), priceFormat), "0"),
                                     ", takeProfitValue="    ,           ifString(lo.TakeProfitValue    (lo)==EMPTY_VALUE, "NULL", DoubleToStr(lo.TakeProfitValue(lo), 2)),
                                     ", takeProfitTriggered=",          BoolToStr(lo.TakeProfitTriggered(lo)),
                                     ", closeTriggerTime="   ,           ifString(lo.CloseTriggerTime   (lo), "'"+ TimeToStr(lo.CloseTriggerTime(lo), TIME_FULL) +"'", "0"),
                                     ", closeTime="          ,           ifString(lo.CloseTime          (lo), "'"+ TimeToStr(lo.CloseTime(lo), TIME_FULL) +"'", "0"),
                                     ", closePrice="         ,           ifString(lo.ClosePrice         (lo), NumberToStr(lo.ClosePrice(lo), priceFormat), "0"),
                                     ", profit="             ,        DoubleToStr(lo.Profit             (lo), 2),
                                     ", comment=\""          ,                    lo.Comment            (lo), "\"",
                                     ", modificationTime="   ,           ifString(lo.ModificationTime   (lo), "'"+ TimeToStr(lo.ModificationTime(lo), TIME_FULL) +"'", "0"),
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
                                                  ", openTime="           ,           ifString(los.OpenTime           (lo, i), "'"+ TimeToStr(Abs(los.OpenTime(lo, i)), TIME_FULL) +"'"+ ifString(los.IsOpenError(lo, i), "(ERROR)", ""), "0"),
                                                  ", openPrice="          ,        NumberToStr(los.OpenPrice          (lo, i), priceFormat),
                                                  ", openTriggerTime="    ,           ifString(los.OpenTriggerTime    (lo, i), "'"+ TimeToStr(los.OpenTriggerTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", stopLoss="           ,           ifString(los.StopLoss           (lo, i), NumberToStr(los.StopLoss(lo, i), priceFormat), "0"),
                                                  ", stopLossValue="      ,           ifString(los.StopLossValue      (lo, i)==EMPTY_VALUE, "NULL", DoubleToStr(los.StopLossValue(lo, i), 2)),
                                                  ", stopLossTriggered="  ,          BoolToStr(los.StopLossTriggered  (lo, i)),
                                                  ", takeProfit="         ,           ifString(los.TakeProfit         (lo, i), NumberToStr(los.TakeProfit(lo, i), priceFormat), "0"),
                                                  ", takeProfitValue="    ,           ifString(los.TakeProfitValue    (lo, i)==EMPTY_VALUE, "NULL", DoubleToStr(los.TakeProfitValue(lo, i), 2)),
                                                  ", takeProfitTriggered=",          BoolToStr(los.TakeProfitTriggered(lo, i)),
                                                  ", closeTriggerTime="   ,           ifString(los.CloseTriggerTime   (lo, i), "'"+ TimeToStr(los.CloseTriggerTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", closeTime="          ,           ifString(los.CloseTime          (lo, i), "'"+ TimeToStr(los.CloseTime(lo, i), TIME_FULL) +"'", "0"),
                                                  ", closePrice="         ,           ifString(los.ClosePrice         (lo, i), NumberToStr(los.ClosePrice(lo, i), priceFormat), "0"),
                                                  ", profit="             ,        DoubleToStr(los.Profit             (lo, i), 2),
                                                  ", comment=\""          ,                    los.Comment            (lo, i), "\"",
                                                  ", modificationTime="   ,           ifString(los.ModificationTime   (lo, i), "'"+ TimeToStr(los.ModificationTime(lo, i), TIME_FULL) +"'", "0"),
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
   lo.IsCloseError          (iNulls);       los.IsCloseError          (iNulls, NULL);
   lo.IsOpen                (iNulls);       los.IsOpen                (iNulls, NULL);
   lo.IsOpened              (iNulls);       los.IsOpened              (iNulls, NULL);
   lo.IsOpenError           (iNulls);       los.IsOpenError           (iNulls, NULL);
   lo.IsPending             (iNulls);       los.IsPending             (iNulls, NULL);
   lo.Lots                  (iNulls);       los.Lots                  (iNulls, NULL);
   lo.ModificationTime      (iNulls);       los.ModificationTime      (iNulls, NULL);
   lo.OpenEquity            (iNulls);       los.OpenEquity            (iNulls, NULL);
   lo.OpenPrice             (iNulls);       los.OpenPrice             (iNulls, NULL);
   lo.OpenTime              (iNulls);       los.OpenTime              (iNulls, NULL);
   lo.OpenTriggerTime       (iNulls);       los.OpenTriggerTime       (iNulls, NULL);
   lo.Profit                (iNulls);       los.Profit                (iNulls, NULL);
   lo.StopLoss              (iNulls);       los.StopLoss              (iNulls, NULL);
   lo.StopLossTriggered     (iNulls);       los.StopLossTriggered     (iNulls, NULL);
   lo.StopLossValue         (iNulls);       los.StopLossValue         (iNulls, NULL);
   lo.TakeProfit            (iNulls);       los.TakeProfit            (iNulls, NULL);
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
   lo.setStopLoss           (iNulls, NULL); los.setStopLoss           (iNulls, NULL, NULL);
   lo.setStopLossTriggered  (iNulls, NULL); los.setStopLossTriggered  (iNulls, NULL, NULL);
   lo.setStopLossValue      (iNulls, NULL); los.setStopLossValue      (iNulls, NULL, NULL);
   lo.setTakeProfit         (iNulls, NULL); los.setTakeProfit         (iNulls, NULL, NULL);
   lo.setTakeProfitTriggered(iNulls, NULL); los.setTakeProfitTriggered(iNulls, NULL, NULL);
   lo.setTakeProfitValue    (iNulls, NULL); los.setTakeProfitValue    (iNulls, NULL, NULL);
   lo.setTicket             (iNulls, NULL); los.setTicket             (iNulls, NULL, NULL);
   lo.setType               (iNulls, NULL); los.setType               (iNulls, NULL, NULL);
   lo.setUnits              (iNulls, NULL); los.setUnits              (iNulls, NULL, NULL);
   lo.setVersion            (iNulls, NULL); los.setVersion            (iNulls, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string GetCurrency(int id);
   string OperationTypeToStr(int type);

#import "Expander.dll"
   int    GetStringAddress(string value);
#import


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "Expander.dll"
//   // Getter
//   int      lo.Ticket                 (/*LFX_ORDER*/int lo[]);
//   int      lo.Type                   (/*LFX_ORDER*/int lo[]);
//   double   lo.Units                  (/*LFX_ORDER*/int lo[]);
//   double   lo.Lots                   (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenEquity             (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenTime               (/*LFX_ORDER*/int lo[]);
//   double   lo.OpenPrice              (/*LFX_ORDER*/int lo[]);
//   datetime lo.OpenTriggerTime        (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLoss               (/*LFX_ORDER*/int lo[]);
//   double   lo.StopLossValue          (/*LFX_ORDER*/int lo[]);
//   bool     lo.StopLossTriggered      (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfit             (/*LFX_ORDER*/int lo[]);
//   double   lo.TakeProfitValue        (/*LFX_ORDER*/int lo[]);
//   bool     lo.TakeProfitTriggered    (/*LFX_ORDER*/int lo[]);
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
//   bool     lo.IsPending              (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpened               (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpen                 (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsClosed               (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsOpenError            (/*LFX_ORDER*/int lo[]);
//   bool     lo.IsCloseError           (/*LFX_ORDER*/int lo[]);

//   int      los.Ticket                (/*LFX_ORDER*/int lo[][], int i);
//   int      los.Type                  (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Units                 (/*LFX_ORDER*/int lo[][], int i);
//   double   los.Lots                  (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenEquity            (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenTime              (/*LFX_ORDER*/int lo[][], int i);
//   double   los.OpenPrice             (/*LFX_ORDER*/int lo[][], int i);
//   datetime los.OpenTriggerTime       (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLoss              (/*LFX_ORDER*/int lo[][], int i);
//   double   los.StopLossValue         (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.StopLossTriggered     (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfit            (/*LFX_ORDER*/int lo[][], int i);
//   double   los.TakeProfitValue       (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.TakeProfitTriggered   (/*LFX_ORDER*/int lo[][], int i);
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
//   bool     los.IsPending             (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpened              (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpen                (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsClosed              (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsOpenError           (/*LFX_ORDER*/int lo[][], int i);
//   bool     los.IsCloseError          (/*LFX_ORDER*/int lo[][], int i);

//   // Setter
//   int      lo.setTicket              (/*LFX_ORDER*/int lo[], int      ticket             );
//   int      lo.setType                (/*LFX_ORDER*/int lo[], int      type               );
//   double   lo.setUnits               (/*LFX_ORDER*/int lo[], double   units              );
//   double   lo.setLots                (/*LFX_ORDER*/int lo[], double   lots               );
//   double   lo.setOpenEquity          (/*LFX_ORDER*/int lo[], double   openEquity         );
//   datetime lo.setOpenTime            (/*LFX_ORDER*/int lo[], datetime openTime           );
//   double   lo.setOpenPrice           (/*LFX_ORDER*/int lo[], double   openPrice          );
//   datetime lo.setOpenTriggerTime     (/*LFX_ORDER*/int lo[], datetime openTriggerTime    );
//   double   lo.setStopLoss            (/*LFX_ORDER*/int lo[], double   stopLoss           );
//   double   lo.setStopLossValue       (/*LFX_ORDER*/int lo[], double   stopLossValue      );
//   bool     lo.setStopLossTriggered   (/*LFX_ORDER*/int lo[], int      stopLossTriggered  );
//   double   lo.setTakeProfit          (/*LFX_ORDER*/int lo[], double   takeProfit         );
//   double   lo.setTakeProfitValue     (/*LFX_ORDER*/int lo[], double   takeProfitValue    );
//   bool     lo.setTakeProfitTriggered (/*LFX_ORDER*/int lo[], int      takeProfitTriggered);
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
//   datetime los.setOpenTime           (/*LFX_ORDER*/int lo[][], int i, datetime openTime           );
//   double   los.setOpenPrice          (/*LFX_ORDER*/int lo[][], int i, double   openPrice          );
//   datetime los.setOpenTriggerTime    (/*LFX_ORDER*/int lo[][], int i, datetime openTriggerTime    );
//   double   los.setStopLoss           (/*LFX_ORDER*/int lo[][], int i, double   stopLoss           );
//   double   los.setStopLossValue      (/*LFX_ORDER*/int lo[][], int i, double   stopLossValue      );
//   bool     los.setStopLossTriggered  (/*LFX_ORDER*/int lo[][], int i, int      stopLossTriggered  );
//   double   los.setTakeProfit         (/*LFX_ORDER*/int lo[][], int i, double   takeProfit         );
//   double   los.setTakeProfitValue    (/*LFX_ORDER*/int lo[][], int i, double   takeProfitValue    );
//   bool     los.setTakeProfitTriggered(/*LFX_ORDER*/int lo[][], int i, int      takeProfitTriggered);
//   datetime los.setCloseTriggerTime   (/*LFX_ORDER*/int lo[][], int i, datetime closeTriggerTime   );
//   datetime los.setCloseTime          (/*LFX_ORDER*/int lo[][], int i, datetime closeTime          );
//   double   los.setClosePrice         (/*LFX_ORDER*/int lo[][], int i, double   closePrice         );
//   double   los.setProfit             (/*LFX_ORDER*/int lo[][], int i, double   profit             );
//   string   los.setComment            (/*LFX_ORDER*/int lo[][], int i, string   comment            );
//   datetime los.setModificationTime   (/*LFX_ORDER*/int lo[][], int i, datetime modificationTime   );
//   int      los.setVersion            (/*LFX_ORDER*/int lo[][], int i, int      version            );

//   string   LFX_ORDER.toStr(/*LFX_ORDER*/int lo[], int outputDebug);
//#import
