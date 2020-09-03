/**
 * Duel
 *
 * Eye to eye stand winners and losers
 * Hurt by envy, cut by greed
 * Face to face with their own disillusions
 * The scars of old romances still on their cheeks
 *
 *
 * A uni-directional or bi-directional grid with optional pyramiding, martingale or reverse-martingale position sizing.
 *
 * - If both multipliers are "0" the EA trades like a regular single-position system (no grid).
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a Martingale system.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string GridDirection         = "Long | Short | Both*";
extern int    GridSize              = 20;
extern double UnitSize              = 0.01;     // lots at the first grid level

extern double Pyramid.Multiplier    = 1;        // unitsize multiplier on the winning side
extern double Martingale.Multiplier = 1;        // unitsize multiplier on the losing side

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>


#define STRATEGY_ID         105                 // unique strategy id from 101-1023 (10 bit)
#define SEQUENCE_ID_MIN    1000                 // min. sequence id value (at least 4 digits)
#define SEQUENCE_ID_MAX   16383                 // max. sequence id value (at most 14 bits: 32767 >> 1)

#define STATUS_UNDEFINED      0                 // sequence status values
#define STATUS_WAITING        1
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3

#define D_LONG                TRADE_DIRECTION_LONG
#define D_SHORT               TRADE_DIRECTION_SHORT
#define D_BOTH                TRADE_DIRECTION_BOTH

#define CLR_PENDING           DeepSkyBlue       // order marker colors
#define CLR_LONG              Blue
#define CLR_SHORT             Red
#define CLR_CLOSE             Orange


// sequence data
int      sequence.id;
datetime sequence.created;
string   sequence.name = "";                    // "[LSB].{sequence.id}"
bool     sequence.isTest;                       // whether the sequence is a test (a finished test can be loaded into an online chart)
int      sequence.status;
int      sequence.directions;
double   sequence.unitsize;                     // lots at the first level
double   sequence.gridbase;
double   sequence.startEquity;

// order management
bool     long.enabled;
int      long.ticket      [];
int      long.level       [];                   // grid level: -n...-1 || +1...+n
int      long.pendingType [];
datetime long.pendingTime [];
double   long.pendingPrice[];
int      long.type        [];
datetime long.openTime    [];
double   long.openPrice   [];
datetime long.closeTime   [];
double   long.closePrice  [];
double   long.swap        [];
double   long.commission  [];
double   long.profit      [];

bool     short.enabled;
int      short.ticket      [];
int      short.level       [];
int      short.pendingType [];
datetime short.pendingTime [];
double   short.pendingPrice[];
int      short.type        [];
datetime short.openTime    [];
double   short.openPrice   [];
datetime short.closeTime   [];
double   short.closePrice  [];
double   short.swap        [];
double   short.commission  [];
double   short.profit      [];


#include <apps/duel/init.mqh>
#include <apps/duel/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (sequence.status == STATUS_WAITING) {              // start a new sequence
      StartSequence();
   }
   else if (sequence.status == STATUS_PROGRESSING) {     // manage a running sequence
      if (UpdateStatus()) {                              // check pending orders and PL
         if (IsStopSignal()) StopSequence();             // close all positions
         else                UpdateOrders();             // add/modify pending orders
      }
   }
   else if (sequence.status == STATUS_STOPPED) {
   }

   return(debug("onTick(0.1)", GetLastError()));
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @return bool
 */
bool IsStopSignal() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   return(!catch("IsStopSignal(2)", ERR_NOT_IMPLEMENTED));
}


/**
 * Start a new sequence. When called all previous sequence data was reset.
 *
 * @return bool - success status
 */
bool StartSequence() {
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (__LOG()) log("StartSequence(2)  "+ sequence.name +" starting sequence...");

   if      (sequence.directions == D_LONG)  sequence.gridbase = Ask;
   else if (sequence.directions == D_SHORT) sequence.gridbase = Bid;
   else                                     sequence.gridbase = NormalizeDouble((Bid+Ask)/2, Digits);

   sequence.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   sequence.status      = STATUS_PROGRESSING;

   UpdateOrders();

   if (__LOG()) log("StartSequence(3)  "+ sequence.name +" sequence started (gridbase "+ NumberToStr(sequence.gridbase, PriceFormat) +")");
   return(!catch("StartSequence(4)"));
}


/**
 * Close all open positions, delete pending orders and stop the sequence.
 *
 * @return bool - success status
 */
bool StopSequence() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   return(!catch("StopSequence(2)", ERR_NOT_IMPLEMENTED));
}


/**
 * Update internal order and PL status with current market data.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   return(!catch("UpdateStatus(2)", ERR_NOT_IMPLEMENTED));
}


/**
 * Update all existing orders and add new or missing ones.
 *
 * @param  int direction [optional] - order direction flags (default: all currently active trade directions)
 *
 * @return bool - success status
 */
bool UpdateOrders(int direction = D_BOTH) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateOrders(1)  "+ sequence.name +" cannot update orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (direction & D_BOTH == D_BOTH) {
      if (!UpdateOrders(D_LONG))  return(false);
      if (!UpdateOrders(D_SHORT)) return(false);
      return(true);
   }
   int orders, minLevel=EMPTY_VALUE, maxLevel=EMPTY_VALUE;

   if (direction == D_LONG) {
      if (long.enabled) {
         orders = ArraySize(long.ticket);
         if (!orders) {
            Grid.AddPosition(direction, 0);              // erste Order in den Markt legen
         }
         else {
            minLevel = long.level[0];
            maxLevel = long.level[orders-1];
            // nächsten Preis oben/unten berechnen
            // wenn erste/letzte Order offen sind, die jeweils nächste in den Markt legen
            return(!catch("UpdateOrders(2)", ERR_NOT_IMPLEMENTED));
         }
      }
      return(true);
   }

   if (direction == D_SHORT) {
      if (short.enabled) {
         return(!catch("UpdateOrders(3)", ERR_NOT_IMPLEMENTED));
      }
      return(true);
   }

   return(!catch("UpdateOrders(4)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Generate a new sequence id. As strategy ids differ multiple strategies may use the same sequence id at the same time.
 *
 * @return int - sequence id between SID_MAX and SID_MAX (1000-16383)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;
   while (id < SEQUENCE_ID_MIN || id > SEQUENCE_ID_MAX) {
      id = MathRand();                                      // TODO: in tester generate consecutive ids
   }                                                        // TODO: test the id for uniqueness
   return(id);
}


/**
 * Generate a unique magic order number for the sequence.
 *
 * @return int - magic number or NULL in case of errors
 */
int CreateMagicNumber() {
   if (STRATEGY_ID & ( ~0x3FF) != 0) return(!catch("CreateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   if (sequence.id & (~0x3FFF) != 0) return(!catch("CreateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023   (max. 10 bit)
   int sequence = sequence.id;                              // 1000-16383 (max. 14 bit)
   int level    = 0;                                        // 0          (not needed for this strategy)

   return((strategy<<22) + (sequence<<8) + (level<<0));
}


/**
 * Open a market position for the specified level and add the order data to the order arrays.
 *
 * @param  int direction - trade direction: D_LONG | D_SHORT
 * @param  int level     - grid level of the position to open: -n...+n
 *
 * @return bool - success status
 */
bool Grid.AddPosition(int direction, int level) {
   if (IsLastError())                           return(false);
   if (sequence.status != STATUS_PROGRESSING)   return(!catch("Grid.AddPosition(1)  "+ sequence.name +" cannot add position to "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("Grid.AddPosition(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int oe[], orderType = ifInt(direction==D_LONG, OP_BUY, OP_SELL);

   int ticket = SubmitMarketOrder(orderType, level, oe);
   if (!ticket) return(false);

   // prepare dataset
   //int    ticket       = ...                     // use as is
   //int    level        = ...                     // ...
   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = NULL;
   int      type         = orderType;
   datetime openTime     = oe.OpenTime (oe);
   double   openPrice    = oe.OpenPrice(oe);
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   double   swap         = oe.Swap      (oe);      // for the theoretical case that swap is already set on OrderOpen
   double   commission   = oe.Commission(oe);
   double   profit       = NULL;

   // store dataset
   Orders.AddRecord(direction, ticket, level, pendingType, pendingTime, pendingPrice, type, openTime, openPrice, closeTime, closePrice, swap, commission, profit);
   return(!last_error);
}


/**
 * Add an order record to the order arrays. No data is overwritten. The position to insert is automatically determined.
 *
 * @param  int      direction
 *
 * @param  int      ticket
 * @param  int      level
 *
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 *
 * @param  int      type
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  datetime closeTime
 * @param  double   closePrice
 *
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - success status
 */
bool Orders.AddRecord(int direction, int ticket, int level, int pendingType, datetime pendingTime, double pendingPrice, int type, datetime openTime, double openPrice, datetime closeTime, double closePrice, double swap, double commission, double profit) {
   if (direction == D_LONG) {
      int size = ArraySize(long.ticket);

      for (int i=0; i < size; i++) {
         if (long.level[i] == level) return(!catch("Orders.AddRecord(1)  "+ sequence.name +" cannot overwrite ticket #"+ long.ticket[i] +" of level "+ level +" (index "+ i +")", ERR_ILLEGAL_STATE));
         if (long.level[i] > level)
            break;
      }
      ArrayInsertInt   (long.ticket,       i, ticket                               );
      ArrayInsertInt   (long.level,        i, level                                );
      ArrayInsertInt   (long.pendingType,  i, pendingType                          );
      ArrayInsertInt   (long.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(long.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (long.type,         i, type                                 );
      ArrayInsertInt   (long.openTime,     i, openTime                             );
      ArrayInsertDouble(long.openPrice,    i, NormalizeDouble(openPrice, Digits)   );
      ArrayInsertInt   (long.closeTime,    i, closeTime                            );
      ArrayInsertDouble(long.closePrice,   i, NormalizeDouble(closePrice, Digits)  );
      ArrayInsertDouble(long.swap,         i, NormalizeDouble(swap,       2)       );
      ArrayInsertDouble(long.commission,   i, NormalizeDouble(commission, 2)       );
      ArrayInsertDouble(long.profit,       i, NormalizeDouble(profit,     2)       );
   }

   else if (direction == D_SHORT) {
      size = ArraySize(long.ticket);

      for (i=0; i < size; i++) {
         if (short.level[i] == level) return(!catch("Orders.AddRecord(2)  "+ sequence.name +" cannot overwrite ticket #"+ short.ticket[i] +" of level "+ level +" (index "+ i +")", ERR_ILLEGAL_STATE));
         if (short.level[i] > level)
            break;
      }
      ArrayInsertInt   (short.ticket,       i, ticket                               );
      ArrayInsertInt   (short.level,        i, level                                );
      ArrayInsertInt   (short.pendingType,  i, pendingType                          );
      ArrayInsertInt   (short.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(short.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (short.type,         i, type                                 );
      ArrayInsertInt   (short.openTime,     i, openTime                             );
      ArrayInsertDouble(short.openPrice,    i, NormalizeDouble(openPrice, Digits)   );
      ArrayInsertInt   (short.closeTime,    i, closeTime                            );
      ArrayInsertDouble(short.closePrice,   i, NormalizeDouble(closePrice, Digits)  );
      ArrayInsertDouble(short.swap,         i, NormalizeDouble(swap,       2)       );
      ArrayInsertDouble(short.commission,   i, NormalizeDouble(commission, 2)       );
      ArrayInsertDouble(short.profit,       i, NormalizeDouble(profit,     2)       );
   }
   else return(!catch("Orders.AddRecord(3)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   return(!catch("Orders.AddRecord(4)"));
}


/**
 * Open a position at current market price.
 *
 * @param  _In_  int type  - order type: OP_BUY | OP_SELL
 * @param  _In_  int level - order gridlevel
 * @param  _Out_ int oe[]  - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket on success or NULL in case of errors
 */
int SubmitMarketOrder(int type, int level, int &oe[]) {
   if (IsLastError())                         return(0);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("SubmitMarketOrder(1)  "+ sequence.name +" cannot submit market order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (type!=OP_BUY  && type!=OP_SELL)        return(!catch("SubmitMarketOrder(2)  "+ sequence.name +" invalid parameter type: "+ type, ERR_INVALID_PARAMETER));

   double   lots        = sequence.unitsize;
   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber();
   datetime expires     = NULL;
   string   comment     = "Duel."+ sequence.name +"."+ NumberToStr(level, "+.");
   color    markerColor = ifInt(type==OP_BUY, CLR_LONG, CLR_SHORT);
   int      oeFlags     = NULL;

   int ticket = OrderSendEx(Symbol(), type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   return(!SetLastError(oe.Error(oe)));
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__CHART()) return(error);
   string msg="", sError="";

   switch (sequence.status) {
      case STATUS_UNDEFINED:   msg = "   not initialized"; break;
      case STATUS_WAITING:     msg = "   waiting";         break;
      case STATUS_PROGRESSING: msg = "   progressing";     break;
      case STATUS_STOPPED:     msg = "   stopped";         break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }

   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

   // 4 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, NL, __NAME(), msg, sError);
   if (__CoreFunction == CF_INIT)
      WindowRedraw();

   if (!catch("ShowStatus(2)"))
      return(error);
   return(last_error);
}


/**
 * ShowStatus: Update the string representations of standard and long sequence name.
 */
void SS.SequenceName() {
   sequence.name = "";

   if (long.enabled)  sequence.name = sequence.name +"L";
   if (short.enabled) sequence.name = sequence.name +"S";

   sequence.name = sequence.name +"."+ sequence.id;
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("GridDirection=",         DoubleQuoteStr(GridDirection),             ";", NL,
                            "GridSize=",              GridSize,                                  ";", NL,
                            "UnitSize=",              NumberToStr(UnitSize, ".1+"),              ";", NL,
                            "Pyramid.Multiplier=",    NumberToStr(Pyramid.Multiplier, ".1+"),    ";", NL,
                            "Martingale.Multiplier=", NumberToStr(Martingale.Multiplier, ".1+"), ";")
   );
}
