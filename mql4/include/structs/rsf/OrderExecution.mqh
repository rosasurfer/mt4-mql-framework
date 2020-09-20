/**
 * Framework struct ORDER_EXECUTION
 *
 * struct ORDER_EXECUTION {
 *    int    error;           //   4      => oe[ 0]      // Fehlercode
 *    szchar symbol[12];      //  16      => oe[ 1]      // OrderSymbol, <NUL>-terminiert
 *    int    digits;          //   4      => oe[ 5]      // Digits des Ordersymbols
 *    int    stopDistance;    //   4      => oe[ 6]      // Stop-Distance in Points
 *    int    freezeDistance;  //   4      => oe[ 7]      // Freeze-Distance in Points
 *    int    bid;             //   4      => oe[ 8]      // Bid-Preis vor Ausführung in Points
 *    int    ask;             //   4      => oe[ 9]      // Ask-Preis vor Ausführung in Points
 *    int    ticket;          //   4      => oe[10]      // Ticket
 *    int    type;            //   4      => oe[11]      // Operation-Type
 *    int    lots;            //   4      => oe[12]      // Ordervolumen in Hundertsteln eines Lots
 *    int    openTime;        //   4      => oe[13]      // OrderOpenTime
 *    int    openPrice;       //   4      => oe[14]      // OpenPrice in Points
 *    int    stopLoss;        //   4      => oe[15]      // StopLoss-Preis in Points
 *    int    takeProfit;      //   4      => oe[16]      // TakeProfit-Preis in Points
 *    int    closeTime;       //   4      => oe[17]      // OrderCloseTime
 *    int    closePrice;      //   4      => oe[18]      // ClosePrice in Points
 *    int    swap;            //   4      => oe[19]      // Swap-Betrag in Hundertsteln der Account-Währung
 *    int    commission;      //   4      => oe[20]      // Commission-Betrag in Hundertsteln der Account-Währung
 *    int    profit;          //   4      => oe[21]      // Profit in Hundertsteln der Account-Währung
 *    szchar comment[28];     //  28      => oe[22]      // Orderkommentar, <NUL>-terminiert
 *    int    duration;        //   4      => oe[29]      // Dauer der Auführung in Millisekunden
 *    int    requotes;        //   4      => oe[30]      // Anzahl aufgetretener Requotes
 *    int    slippage;        //   4      => oe[31]      // aufgetretene Slippage in Points (positiv: zu ungunsten, negativ: zu gunsten)
 *    int    remainingTicket; //   4      => oe[32]      // zusätzlich erzeugtes, verbleibendes Ticket
 *    int    remainingLots;   //   4      => oe[33]      // verbleibendes Ordervolumen in Hundertsteln eines Lots (nach partial close)
 * } oe;                      // 136 byte = int[34]
 */
#define OE.error                  0                      // Array-Offsets
#define OE.symbol                 1
#define OE.digits                 5
#define OE.stopDistance           6
#define OE.freezeDistance         7
#define OE.bid                    8
#define OE.ask                    9
#define OE.ticket                10
#define OE.type                  11
#define OE.lots                  12
#define OE.openTime              13
#define OE.openPrice             14
#define OE.stopLoss              15
#define OE.takeProfit            16
#define OE.closeTime             17
#define OE.closePrice            18
#define OE.swap                  19
#define OE.commission            20
#define OE.profit                21
#define OE.comment               22
#define OE.duration              29
#define OE.requotes              30
#define OE.slippage              31
#define OE.remainingTicket       32
#define OE.remainingLots         33


// Getter
int      oe.Error              (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.error          ]);                                         ORDER_EXECUTION.toStr(oe); }
string   oe.Symbol             (/*ORDER_EXECUTION*/int oe[]         ) {                     return(GetStringA(GetIntsAddress(oe) + OE.symbol*4));                                             ORDER_EXECUTION.toStr(oe); }
int      oe.Digits             (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.digits         ]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.StopDistance       (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.stopDistance   ]/MathPow(10, digits & 1), digits & 1));    ORDER_EXECUTION.toStr(oe); }
double   oe.FreezeDistance     (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.freezeDistance ]/MathPow(10, digits & 1), digits & 1));    ORDER_EXECUTION.toStr(oe); }
double   oe.Bid                (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.bid            ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
double   oe.Ask                (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.ask            ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
int      oe.Ticket             (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.ticket         ]);                                         ORDER_EXECUTION.toStr(oe); }
int      oe.Type               (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.type           ]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.Lots               (/*ORDER_EXECUTION*/int oe[]         ) {                               return(NormalizeDouble(oe[OE.lots           ]/100., 2));                                ORDER_EXECUTION.toStr(oe); }
datetime oe.OpenTime           (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.openTime       ]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.OpenPrice          (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.openPrice      ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
double   oe.StopLoss           (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.stopLoss       ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
double   oe.TakeProfit         (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.takeProfit     ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
datetime oe.CloseTime          (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.closeTime      ]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.ClosePrice         (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.closePrice     ]/MathPow(10, digits), digits));            ORDER_EXECUTION.toStr(oe); }
double   oe.Swap               (/*ORDER_EXECUTION*/int oe[]         ) {                               return(NormalizeDouble(oe[OE.swap           ]/100., 2));                                ORDER_EXECUTION.toStr(oe); }
double   oe.Commission         (/*ORDER_EXECUTION*/int oe[]         ) {                               return(NormalizeDouble(oe[OE.commission     ]/100., 2));                                ORDER_EXECUTION.toStr(oe); }
double   oe.Profit             (/*ORDER_EXECUTION*/int oe[]         ) {                               return(NormalizeDouble(oe[OE.profit         ]/100., 2));                                ORDER_EXECUTION.toStr(oe); }
string   oe.Comment            (/*ORDER_EXECUTION*/int oe[]         ) {                     return(GetStringA(GetIntsAddress(oe) + OE.comment*4));                                            ORDER_EXECUTION.toStr(oe); }
int      oe.Duration           (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.duration       ]);                                         ORDER_EXECUTION.toStr(oe); }
int      oe.Requotes           (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.requotes       ]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.Slippage           (/*ORDER_EXECUTION*/int oe[]         ) { int digits=oe.Digits(oe);     return(NormalizeDouble(oe[OE.slippage       ]/MathPow(10, digits & 1), digits & 1));    ORDER_EXECUTION.toStr(oe); }
int      oe.RemainingTicket    (/*ORDER_EXECUTION*/int oe[]         ) {                                               return(oe[OE.remainingTicket]);                                         ORDER_EXECUTION.toStr(oe); }
double   oe.RemainingLots      (/*ORDER_EXECUTION*/int oe[]         ) {                               return(NormalizeDouble(oe[OE.remainingLots  ]/100., 2));                                ORDER_EXECUTION.toStr(oe); }

int      oes.Error             (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.error          ]);                                      ORDER_EXECUTION.toStr(oe); }
string   oes.Symbol            (/*ORDER_EXECUTION*/int oe[][], int i) {                     return(GetStringA(GetIntsAddress(oe) + (i*ORDER_EXECUTION.intSize + OE.symbol)*4));               ORDER_EXECUTION.toStr(oe); }
int      oes.Digits            (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.digits         ]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.StopDistance      (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.stopDistance   ]/MathPow(10, digits & 1), digits & 1)); ORDER_EXECUTION.toStr(oe); }
double   oes.FreezeDistance    (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.freezeDistance ]/MathPow(10, digits & 1), digits & 1)); ORDER_EXECUTION.toStr(oe); }
double   oes.Bid               (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.bid            ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
double   oes.Ask               (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.ask            ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
int      oes.Ticket            (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.ticket         ]);                                      ORDER_EXECUTION.toStr(oe); }
int      oes.Type              (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.type           ]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.Lots              (/*ORDER_EXECUTION*/int oe[][], int i) {                               return(NormalizeDouble(oe[i][OE.lots           ]/100., 2));                             ORDER_EXECUTION.toStr(oe); }
datetime oes.OpenTime          (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.openTime       ]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.OpenPrice         (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.openPrice      ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
double   oes.StopLoss          (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.stopLoss       ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
double   oes.TakeProfit        (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.takeProfit     ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
datetime oes.CloseTime         (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.closeTime      ]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.ClosePrice        (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.closePrice     ]/MathPow(10, digits), digits));         ORDER_EXECUTION.toStr(oe); }
double   oes.Swap              (/*ORDER_EXECUTION*/int oe[][], int i) {                               return(NormalizeDouble(oe[i][OE.swap           ]/100., 2));                             ORDER_EXECUTION.toStr(oe); }
double   oes.Commission        (/*ORDER_EXECUTION*/int oe[][], int i) {                               return(NormalizeDouble(oe[i][OE.commission     ]/100., 2));                             ORDER_EXECUTION.toStr(oe); }
double   oes.Profit            (/*ORDER_EXECUTION*/int oe[][], int i) {                               return(NormalizeDouble(oe[i][OE.profit         ]/100., 2));                             ORDER_EXECUTION.toStr(oe); }
string   oes.Comment           (/*ORDER_EXECUTION*/int oe[][], int i) {                     return(GetStringA(GetIntsAddress(oe) + (i*ORDER_EXECUTION.intSize + OE.comment)*4));              ORDER_EXECUTION.toStr(oe); }
int      oes.Duration          (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.duration       ]);                                      ORDER_EXECUTION.toStr(oe); }
int      oes.Requotes          (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.requotes       ]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.Slippage          (/*ORDER_EXECUTION*/int oe[][], int i) { int digits=oes.Digits(oe, i); return(NormalizeDouble(oe[i][OE.slippage       ]/MathPow(10, digits & 1), digits & 1)); ORDER_EXECUTION.toStr(oe); }
int      oes.RemainingTicket   (/*ORDER_EXECUTION*/int oe[][], int i) {                                               return(oe[i][OE.remainingTicket]);                                      ORDER_EXECUTION.toStr(oe); }
double   oes.RemainingLots     (/*ORDER_EXECUTION*/int oe[][], int i) {                               return(NormalizeDouble(oe[i][OE.remainingLots  ]/100., 2));                             ORDER_EXECUTION.toStr(oe); }


// Setter
int      oe.setError           (/*ORDER_EXECUTION*/int &oe[],          int      error     ) { oe[OE.error          ]  = error;                                                       return(error     ); ORDER_EXECUTION.toStr(oe); }
string   oe.setSymbol          (/*ORDER_EXECUTION*/int  oe[],          string   symbol    ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("oe.setSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("oe.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   string array[]; ArrayResize(array, 1); array[0]=symbol;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(oe) + OE.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1); /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                                                                            return(symbol    ); ORDER_EXECUTION.toStr(oe); }
int      oe.setDigits          (/*ORDER_EXECUTION*/int &oe[],          int      digits    ) { oe[OE.digits         ]  = digits;                                                      return(digits    ); ORDER_EXECUTION.toStr(oe); }
double   oe.setStopDistance    (/*ORDER_EXECUTION*/int &oe[],          double   distance  ) { oe[OE.stopDistance   ]  = MathRound(distance * MathPow(10, oe.Digits(oe) & 1));        return(distance  ); ORDER_EXECUTION.toStr(oe); }
double   oe.setFreezeDistance  (/*ORDER_EXECUTION*/int &oe[],          double   distance  ) { oe[OE.freezeDistance ]  = MathRound(distance * MathPow(10, oe.Digits(oe) & 1));        return(distance  ); ORDER_EXECUTION.toStr(oe); }
double   oe.setBid             (/*ORDER_EXECUTION*/int &oe[],          double   bid       ) { oe[OE.bid            ]  = MathRound(bid * MathPow(10, oe.Digits(oe)));                 return(bid       ); ORDER_EXECUTION.toStr(oe); }
double   oe.setAsk             (/*ORDER_EXECUTION*/int &oe[],          double   ask       ) { oe[OE.ask            ]  = MathRound(ask * MathPow(10, oe.Digits(oe)));                 return(ask       ); ORDER_EXECUTION.toStr(oe); }
int      oe.setTicket          (/*ORDER_EXECUTION*/int &oe[],          int      ticket    ) { oe[OE.ticket         ]  = ticket;                                                      return(ticket    ); ORDER_EXECUTION.toStr(oe); }
int      oe.setType            (/*ORDER_EXECUTION*/int &oe[],          int      type      ) { oe[OE.type           ]  = type;                                                        return(type      ); ORDER_EXECUTION.toStr(oe); }
double   oe.setLots            (/*ORDER_EXECUTION*/int &oe[],          double   lots      ) { oe[OE.lots           ]  = MathRound(lots * 100);                                       return(lots      ); ORDER_EXECUTION.toStr(oe); }
datetime oe.setOpenTime        (/*ORDER_EXECUTION*/int &oe[],          datetime openTime  ) { oe[OE.openTime       ]  = openTime;                                                    return(openTime  ); ORDER_EXECUTION.toStr(oe); }
double   oe.setOpenPrice       (/*ORDER_EXECUTION*/int &oe[],          double   openPrice ) { oe[OE.openPrice      ]  = MathRound(openPrice  * MathPow(10, oe.Digits(oe)));          return(openPrice ); ORDER_EXECUTION.toStr(oe); }
double   oe.setStopLoss        (/*ORDER_EXECUTION*/int &oe[],          double   stopLoss  ) { oe[OE.stopLoss       ]  = MathRound(stopLoss   * MathPow(10, oe.Digits(oe)));          return(stopLoss  ); ORDER_EXECUTION.toStr(oe); }
double   oe.setTakeProfit      (/*ORDER_EXECUTION*/int &oe[],          double   takeProfit) { oe[OE.takeProfit     ]  = MathRound(takeProfit * MathPow(10, oe.Digits(oe)));          return(takeProfit); ORDER_EXECUTION.toStr(oe); }
datetime oe.setCloseTime       (/*ORDER_EXECUTION*/int &oe[],          datetime closeTime ) { oe[OE.closeTime      ]  = closeTime;                                                   return(closeTime ); ORDER_EXECUTION.toStr(oe); }
double   oe.setClosePrice      (/*ORDER_EXECUTION*/int &oe[],          double   closePrice) { oe[OE.closePrice     ]  = MathRound(closePrice * MathPow(10, oe.Digits(oe)));          return(closePrice); ORDER_EXECUTION.toStr(oe); }
double   oe.setSwap            (/*ORDER_EXECUTION*/int &oe[],          double   swap      ) { oe[OE.swap           ]  = MathRound(swap * 100);                                       return(swap      ); ORDER_EXECUTION.toStr(oe); }
double   oe.addSwap            (/*ORDER_EXECUTION*/int &oe[],          double   swap      ) { oe[OE.swap           ] += MathRound(swap * 100);                                       return(swap      ); ORDER_EXECUTION.toStr(oe); }
double   oe.setCommission      (/*ORDER_EXECUTION*/int &oe[],          double   comission ) { oe[OE.commission     ]  = MathRound(comission * 100);                                  return(comission ); ORDER_EXECUTION.toStr(oe); }
double   oe.addCommission      (/*ORDER_EXECUTION*/int &oe[],          double   comission ) { oe[OE.commission     ] += MathRound(comission * 100);                                  return(comission ); ORDER_EXECUTION.toStr(oe); }
double   oe.setProfit          (/*ORDER_EXECUTION*/int &oe[],          double   profit    ) { oe[OE.profit         ]  = MathRound(profit * 100);                                     return(profit    ); ORDER_EXECUTION.toStr(oe); }
double   oe.addProfit          (/*ORDER_EXECUTION*/int &oe[],          double   profit    ) { oe[OE.profit         ] += MathRound(profit * 100);                                     return(profit    ); ORDER_EXECUTION.toStr(oe); }
string   oe.setComment         (/*ORDER_EXECUTION*/int  oe[],          string   comment   ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > MAX_ORDER_COMMENT_LENGTH) return(_EMPTY_STR(catch("oe.setComment()  too long parameter comment = \""+ comment +"\" (max "+ MAX_ORDER_COMMENT_LENGTH +" chars)"), ERR_INVALID_PARAMETER));
   string array[]; ArrayResize(array, 1); array[0]=comment;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(oe) + OE.comment*4;
   CopyMemory(dest, src, StringLen(comment)+1);                      /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                                                                            return(comment   ); ORDER_EXECUTION.toStr(oe); }
int      oe.setDuration        (/*ORDER_EXECUTION*/int &oe[],          int      milliSec  ) { oe[OE.duration       ] = milliSec;                                                     return(milliSec  ); ORDER_EXECUTION.toStr(oe); }
int      oe.setRequotes        (/*ORDER_EXECUTION*/int &oe[],          int      requotes  ) { oe[OE.requotes       ] = requotes;                                                     return(requotes  ); ORDER_EXECUTION.toStr(oe); }
double   oe.setSlippage        (/*ORDER_EXECUTION*/int &oe[],          double   slippage  ) { oe[OE.slippage       ] = MathRound(slippage * MathPow(10, oe.Digits(oe) & 1));         return(slippage  ); ORDER_EXECUTION.toStr(oe); }
int      oe.setRemainingTicket (/*ORDER_EXECUTION*/int &oe[],          int      ticket    ) { oe[OE.remainingTicket] = ticket;                                                       return(ticket    ); ORDER_EXECUTION.toStr(oe); }
double   oe.setRemainingLots   (/*ORDER_EXECUTION*/int &oe[],          double   lots      ) { oe[OE.remainingLots  ] = MathRound(lots * 100);                                        return(lots      ); ORDER_EXECUTION.toStr(oe); }
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

int      oes.setError          (/*ORDER_EXECUTION*/int &oe[][], int i, int error) {
   if (i == -1) { for (int n=ArrayRange(oe, 0)-1; n >= 0; n--)                                oe[n][OE.error          ] = error;                                                     return(error     ); }
                                                                                              oe[i][OE.error          ] = error;                                                     return(error     ); ORDER_EXECUTION.toStr(oe); }
string   oes.setSymbol         (/*ORDER_EXECUTION*/int  oe[][], int i, string   symbol    ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("oes.setSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol)), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("oes.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)"), ERR_INVALID_PARAMETER));
   string array[]; ArrayResize(array, 1); array[0]=symbol;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(oe) + (i*ORDER_EXECUTION.intSize + OE.symbol)*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                                                                            return(symbol    ); ORDER_EXECUTION.toStr(oe); }
int      oes.setDigits         (/*ORDER_EXECUTION*/int &oe[][], int i, int      digits    ) { oe[i][OE.digits         ]  = digits;                                                   return(digits    ); ORDER_EXECUTION.toStr(oe); }
double   oes.setStopDistance   (/*ORDER_EXECUTION*/int &oe[][], int i, double   distance  ) { oe[i][OE.stopDistance   ]  = MathRound(distance * MathPow(10, oes.Digits(oe, i) & 1)); return(distance  ); ORDER_EXECUTION.toStr(oe); }
double   oes.setFreezeDistance (/*ORDER_EXECUTION*/int &oe[][], int i, double   distance  ) { oe[i][OE.freezeDistance ]  = MathRound(distance * MathPow(10, oes.Digits(oe, i) & 1)); return(distance  ); ORDER_EXECUTION.toStr(oe); }
double   oes.setBid            (/*ORDER_EXECUTION*/int &oe[][], int i, double   bid       ) { oe[i][OE.bid            ]  = MathRound(bid * MathPow(10, oes.Digits(oe, i)));          return(bid       ); ORDER_EXECUTION.toStr(oe); }
double   oes.setAsk            (/*ORDER_EXECUTION*/int &oe[][], int i, double   ask       ) { oe[i][OE.ask            ]  = MathRound(ask * MathPow(10, oes.Digits(oe, i)));          return(ask       ); ORDER_EXECUTION.toStr(oe); }
int      oes.setTicket         (/*ORDER_EXECUTION*/int &oe[][], int i, int      ticket    ) { oe[i][OE.ticket         ]  = ticket;                                                   return(ticket    ); ORDER_EXECUTION.toStr(oe); }
int      oes.setType           (/*ORDER_EXECUTION*/int &oe[][], int i, int      type      ) { oe[i][OE.type           ]  = type;                                                     return(type      ); ORDER_EXECUTION.toStr(oe); }
double   oes.setLots           (/*ORDER_EXECUTION*/int &oe[][], int i, double   lots      ) { oe[i][OE.lots           ]  = MathRound(lots * 100);                                    return(lots      ); ORDER_EXECUTION.toStr(oe); }
datetime oes.setOpenTime       (/*ORDER_EXECUTION*/int &oe[][], int i, datetime openTime  ) { oe[i][OE.openTime       ]  = openTime;                                                 return(openTime  ); ORDER_EXECUTION.toStr(oe); }
double   oes.setOpenPrice      (/*ORDER_EXECUTION*/int &oe[][], int i, double   openPrice ) { oe[i][OE.openPrice      ]  = MathRound(openPrice  * MathPow(10, oes.Digits(oe, i)));   return(openPrice ); ORDER_EXECUTION.toStr(oe); }
double   oes.setStopLoss       (/*ORDER_EXECUTION*/int &oe[][], int i, double   stopLoss  ) { oe[i][OE.stopLoss       ]  = MathRound(stopLoss   * MathPow(10, oes.Digits(oe, i)));   return(stopLoss  ); ORDER_EXECUTION.toStr(oe); }
double   oes.setTakeProfit     (/*ORDER_EXECUTION*/int &oe[][], int i, double   takeProfit) { oe[i][OE.takeProfit     ]  = MathRound(takeProfit * MathPow(10, oes.Digits(oe, i)));   return(takeProfit); ORDER_EXECUTION.toStr(oe); }
datetime oes.setCloseTime      (/*ORDER_EXECUTION*/int &oe[][], int i, datetime closeTime ) { oe[i][OE.closeTime      ]  = closeTime;                                                return(closeTime ); ORDER_EXECUTION.toStr(oe); }
double   oes.setClosePrice     (/*ORDER_EXECUTION*/int &oe[][], int i, double   closePrice) { oe[i][OE.closePrice     ]  = MathRound(closePrice * MathPow(10, oes.Digits(oe, i)));   return(closePrice); ORDER_EXECUTION.toStr(oe); }
double   oes.setSwap           (/*ORDER_EXECUTION*/int &oe[][], int i, double   swap      ) { oe[i][OE.swap           ]  = MathRound(swap * 100);                                    return(swap      ); ORDER_EXECUTION.toStr(oe); }
double   oes.addSwap           (/*ORDER_EXECUTION*/int &oe[][], int i, double   swap      ) { oe[i][OE.swap           ] += MathRound(swap * 100);                                    return(swap      ); ORDER_EXECUTION.toStr(oe); }
double   oes.setCommission     (/*ORDER_EXECUTION*/int &oe[][], int i, double   comission ) { oe[i][OE.commission     ]  = MathRound(comission * 100);                               return(comission ); ORDER_EXECUTION.toStr(oe); }
double   oes.addCommission     (/*ORDER_EXECUTION*/int &oe[][], int i, double   comission ) { oe[i][OE.commission     ] += MathRound(comission * 100);                               return(comission ); ORDER_EXECUTION.toStr(oe); }
double   oes.setProfit         (/*ORDER_EXECUTION*/int &oe[][], int i, double   profit    ) { oe[i][OE.profit         ]  = MathRound(profit * 100);                                  return(profit    ); ORDER_EXECUTION.toStr(oe); }
double   oes.addProfit         (/*ORDER_EXECUTION*/int &oe[][], int i, double   profit    ) { oe[i][OE.profit         ] += MathRound(profit * 100);                                  return(profit    ); ORDER_EXECUTION.toStr(oe); }
string   oes.setComment        (/*ORDER_EXECUTION*/int  oe[][], int i, string   comment   ) {
   if (!StringLen(comment)) comment = "";                            // sicherstellen, daß der String initialisiert ist
   if ( StringLen(comment) > MAX_ORDER_COMMENT_LENGTH) return(_EMPTY_STR(catch("oes.setComment()  too long parameter comment = \""+ comment +"\" (max "+ MAX_ORDER_COMMENT_LENGTH +" chars)"), ERR_INVALID_PARAMETER));
   string array[]; ArrayResize(array, 1); array[0]=comment;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(oe) + (i*ORDER_EXECUTION.intSize + OE.comment)*4;
   CopyMemory(dest, src, StringLen(comment)+1);                      /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                                                                            return(comment   ); ORDER_EXECUTION.toStr(oe); }
int      oes.setDuration       (/*ORDER_EXECUTION*/int &oe[][], int i, int      milliSec  ) { oe[i][OE.duration       ] = milliSec;                                                  return(milliSec  ); ORDER_EXECUTION.toStr(oe); }
int      oes.setRequotes       (/*ORDER_EXECUTION*/int &oe[][], int i, int      requotes  ) { oe[i][OE.requotes       ] = requotes;                                                  return(requotes  ); ORDER_EXECUTION.toStr(oe); }
double   oes.setSlippage       (/*ORDER_EXECUTION*/int &oe[][], int i, double   slippage  ) { oe[i][OE.slippage       ] = MathRound(slippage * MathPow(10, oes.Digits(oe, i) & 1));  return(slippage  ); ORDER_EXECUTION.toStr(oe); }
int      oes.setRemainingTicket(/*ORDER_EXECUTION*/int &oe[][], int i, int      ticket    ) { oe[i][OE.remainingTicket] = ticket;                                                    return(ticket    ); ORDER_EXECUTION.toStr(oe); }
double   oes.setRemainingLots  (/*ORDER_EXECUTION*/int &oe[][], int i, double   lots      ) { oe[i][OE.remainingLots  ] = MathRound(lots * 100);                                     return(lots      ); ORDER_EXECUTION.toStr(oe); }


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer ORDER_EXECUTION-Structs zurück.
 *
 * @param  int oe[] - struct ORDER_EXECUTION
 *
 * @return string - lesbarer String oder Leerstring, falls ein Fehler auftrat
 */
string ORDER_EXECUTION.toStr(/*ORDER_EXECUTION*/int oe[]) {
   int dimensions = ArrayDimension(oe);
   if (dimensions > 2)                                          return(_EMPTY_STR(catch("ORDER_EXECUTION.toStr(1)  too many dimensions of parameter oe = "+ dimensions, ERR_INVALID_PARAMETER)));
   if (ArrayRange(oe, dimensions-1) != ORDER_EXECUTION.intSize) return(_EMPTY_STR(catch("ORDER_EXECUTION.toStr(2)  invalid size of parameter oe ("+ ArrayRange(oe, dimensions-1) +")", ERR_INVALID_PARAMETER)));

   int    digits, pipDigits;
   string priceFormat, line, lines[]; ArrayResize(lines, 0);


   if (dimensions == 1) {
      // oe ist einzelnes Struct ORDER_EXECUTION (eine Dimension)
      digits      = oe.Digits(oe);
      pipDigits   = digits & (~1);
      priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      line        = StringConcatenate("{error="          ,          ifString(!oe.Error          (oe), 0, StringConcatenate(oe.Error(oe), " [", ErrorDescription(oe.Error(oe)), "]")),
                                     ", symbol=\""       ,                    oe.Symbol         (oe), "\"",
                                     ", digits="         ,                    oe.Digits         (oe),
                                     ", stopDistance="   ,        NumberToStr(oe.StopDistance   (oe), ".+"),
                                     ", freezeDistance=" ,        NumberToStr(oe.FreezeDistance (oe), ".+"),
                                     ", bid="            ,        NumberToStr(oe.Bid            (oe), priceFormat),
                                     ", ask="            ,        NumberToStr(oe.Ask            (oe), priceFormat),
                                     ", ticket="         ,                    oe.Ticket         (oe),
                                     ", type="           , OperationTypeToStr(oe.Type           (oe)),
                                     ", lots="           ,        NumberToStr(oe.Lots           (oe), ".+"),
                                     ", openTime="       ,           ifString(oe.OpenTime       (oe), "'"+ TimeToStr(oe.OpenTime(oe), TIME_FULL) +"'", "0"),
                                     ", openPrice="      ,        NumberToStr(oe.OpenPrice      (oe), priceFormat),
                                     ", stopLoss="       ,        NumberToStr(oe.StopLoss       (oe), priceFormat),
                                     ", takeProfit="     ,        NumberToStr(oe.TakeProfit     (oe), priceFormat),
                                     ", closeTime="      ,           ifString(oe.CloseTime      (oe), "'"+ TimeToStr(oe.CloseTime(oe), TIME_FULL) +"'", "0"),
                                     ", closePrice="     ,        NumberToStr(oe.ClosePrice     (oe), priceFormat),
                                     ", swap="           ,        DoubleToStr(oe.Swap           (oe), 2),
                                     ", commission="     ,        DoubleToStr(oe.Commission     (oe), 2),
                                     ", profit="         ,        DoubleToStr(oe.Profit         (oe), 2),
                                     ", duration="       ,                    oe.Duration       (oe),
                                     ", requotes="       ,                    oe.Requotes       (oe),
                                     ", slippage="       ,        DoubleToStr(oe.Slippage       (oe), 1),
                                     ", comment=\""      ,                    oe.Comment        (oe), "\"",
                                     ", remainingTicket=",                    oe.RemainingTicket(oe),
                                     ", remainingLots="  ,        NumberToStr(oe.RemainingLots  (oe), ".+"), "}");
      ArrayPushString(lines, line);
   }
   else {
      // oe ist Struct-Array ORDER_EXECUTION[] (zwei Dimensionen)
      int size = ArrayRange(oe, 0);

      for (int i=0; i < size; i++) {
         digits      = oes.Digits(oe, i);
         pipDigits   = digits & (~1);
         priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
         line        = StringConcatenate("[", i, "]={error="          ,          ifString(!oes.Error          (oe, i), 0, StringConcatenate(oes.Error(oe, i), " [", ErrorDescription(oes.Error(oe, i)), "]")),
                                                  ", symbol=\""       ,                    oes.Symbol         (oe, i), "\"",
                                                  ", digits="         ,                    oes.Digits         (oe, i),
                                                  ", stopDistance="   ,        DoubleToStr(oes.StopDistance   (oe, i), 1),
                                                  ", freezeDistance=" ,        DoubleToStr(oes.FreezeDistance (oe, i), 1),
                                                  ", bid="            ,        NumberToStr(oes.Bid            (oe, i), priceFormat),
                                                  ", ask="            ,        NumberToStr(oes.Ask            (oe, i), priceFormat),
                                                  ", ticket="         ,                    oes.Ticket         (oe, i),
                                                  ", type="           , OperationTypeToStr(oes.Type           (oe, i)),
                                                  ", lots="           ,        NumberToStr(oes.Lots           (oe, i), ".+"),
                                                  ", openTime="       ,           ifString(oes.OpenTime       (oe, i), "'"+ TimeToStr(oes.OpenTime(oe, i), TIME_FULL) +"'", "0"),
                                                  ", openPrice="      ,        NumberToStr(oes.OpenPrice      (oe, i), priceFormat),
                                                  ", stopLoss="       ,        NumberToStr(oes.StopLoss       (oe, i), priceFormat),
                                                  ", takeProfit="     ,        NumberToStr(oes.TakeProfit     (oe, i), priceFormat),
                                                  ", closeTime="      ,           ifString(oes.CloseTime      (oe, i), "'"+ TimeToStr(oes.CloseTime(oe, i), TIME_FULL) +"'", "0"),
                                                  ", closePrice="     ,        NumberToStr(oes.ClosePrice     (oe, i), priceFormat),
                                                  ", swap="           ,        DoubleToStr(oes.Swap           (oe, i), 2),
                                                  ", commission="     ,        DoubleToStr(oes.Commission     (oe, i), 2),
                                                  ", profit="         ,        DoubleToStr(oes.Profit         (oe, i), 2),
                                                  ", duration="       ,                    oes.Duration       (oe, i),
                                                  ", requotes="       ,                    oes.Requotes       (oe, i),
                                                  ", slippage="       ,        DoubleToStr(oes.Slippage       (oe, i), 1),
                                                  ", comment=\""      ,                    oes.Comment        (oe, i), "\"",
                                                  ", remainingTicket=",                    oes.RemainingTicket(oe, i),
                                                  ", remainingLots="  ,        NumberToStr(oes.RemainingLots  (oe, i), ".+"), "}");
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("ORDER_EXECUTION.toStr(3)");
   return(output);

   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   oe.Error             (oe);       oes.Error             (oe, NULL);
   oe.Symbol            (oe);       oes.Symbol            (oe, NULL);
   oe.Digits            (oe);       oes.Digits            (oe, NULL);
   oe.StopDistance      (oe);       oes.StopDistance      (oe, NULL);
   oe.FreezeDistance    (oe);       oes.FreezeDistance    (oe, NULL);
   oe.Bid               (oe);       oes.Bid               (oe, NULL);
   oe.Ask               (oe);       oes.Ask               (oe, NULL);
   oe.Ticket            (oe);       oes.Ticket            (oe, NULL);
   oe.Type              (oe);       oes.Type              (oe, NULL);
   oe.Lots              (oe);       oes.Lots              (oe, NULL);
   oe.OpenTime          (oe);       oes.OpenTime          (oe, NULL);
   oe.OpenPrice         (oe);       oes.OpenPrice         (oe, NULL);
   oe.StopLoss          (oe);       oes.StopLoss          (oe, NULL);
   oe.TakeProfit        (oe);       oes.TakeProfit        (oe, NULL);
   oe.CloseTime         (oe);       oes.CloseTime         (oe, NULL);
   oe.ClosePrice        (oe);       oes.ClosePrice        (oe, NULL);
   oe.Swap              (oe);       oes.Swap              (oe, NULL);
   oe.Commission        (oe);       oes.Commission        (oe, NULL);
   oe.Profit            (oe);       oes.Profit            (oe, NULL);
   oe.Comment           (oe);       oes.Comment           (oe, NULL);
   oe.Duration          (oe);       oes.Duration          (oe, NULL);
   oe.Requotes          (oe);       oes.Requotes          (oe, NULL);
   oe.Slippage          (oe);       oes.Slippage          (oe, NULL);
   oe.RemainingTicket   (oe);       oes.RemainingTicket   (oe, NULL);
   oe.RemainingLots     (oe);       oes.RemainingLots     (oe, NULL);

   oe.setError          (oe, NULL); oes.setError          (oe, NULL, NULL);
   oe.setSymbol         (oe, NULL); oes.setSymbol         (oe, NULL, NULL);
   oe.setDigits         (oe, NULL); oes.setDigits         (oe, NULL, NULL);
   oe.setStopDistance   (oe, NULL); oes.setStopDistance   (oe, NULL, NULL);
   oe.setFreezeDistance (oe, NULL); oes.setFreezeDistance (oe, NULL, NULL);
   oe.setBid            (oe, NULL); oes.setBid            (oe, NULL, NULL);
   oe.setAsk            (oe, NULL); oes.setAsk            (oe, NULL, NULL);
   oe.setTicket         (oe, NULL); oes.setTicket         (oe, NULL, NULL);
   oe.setType           (oe, NULL); oes.setType           (oe, NULL, NULL);
   oe.setLots           (oe, NULL); oes.setLots           (oe, NULL, NULL);
   oe.setOpenTime       (oe, NULL); oes.setOpenTime       (oe, NULL, NULL);
   oe.setOpenPrice      (oe, NULL); oes.setOpenPrice      (oe, NULL, NULL);
   oe.setStopLoss       (oe, NULL); oes.setStopLoss       (oe, NULL, NULL);
   oe.setTakeProfit     (oe, NULL); oes.setTakeProfit     (oe, NULL, NULL);
   oe.setCloseTime      (oe, NULL); oes.setCloseTime      (oe, NULL, NULL);
   oe.setClosePrice     (oe, NULL); oes.setClosePrice     (oe, NULL, NULL);
   oe.setSwap           (oe, NULL); oes.setSwap           (oe, NULL, NULL);
   oe.addSwap           (oe, NULL); oes.addSwap           (oe, NULL, NULL);
   oe.setCommission     (oe, NULL); oes.setCommission     (oe, NULL, NULL);
   oe.addCommission     (oe, NULL); oes.addCommission     (oe, NULL, NULL);
   oe.setProfit         (oe, NULL); oes.setProfit         (oe, NULL, NULL);
   oe.addProfit         (oe, NULL); oes.addProfit         (oe, NULL, NULL);
   oe.setComment        (oe, NULL); oes.setComment        (oe, NULL, NULL);
   oe.setDuration       (oe, NULL); oes.setDuration       (oe, NULL, NULL);
   oe.setRequotes       (oe, NULL); oes.setRequotes       (oe, NULL, NULL);
   oe.setSlippage       (oe, NULL); oes.setSlippage       (oe, NULL, NULL);
   oe.setRemainingTicket(oe, NULL); oes.setRemainingTicket(oe, NULL, NULL);
   oe.setRemainingLots  (oe, NULL); oes.setRemainingLots  (oe, NULL, NULL);
}
