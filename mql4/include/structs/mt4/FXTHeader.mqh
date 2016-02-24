/**
 * FXTHeader.mqh
 * Copyleft removed
 * http://www.metaquotes.net
 */

#define FXT_VERSION         405

#define PROFIT_CALC_FOREX     0        // profit calculation modes
#define PROFIT_CALC_CFD       1
#define PROFIT_CALC_FUTURES   2

#define SWAP_BY_POINTS        0        // swap types
#define SWAP_BY_DOLLARS       1
#define SWAP_BY_INTEREST      2

#define MARGIN_DONT_USE       0        // free margin calculation modes
#define MARGIN_USE_ALL        1
#define MARGIN_USE_PROFIT     2
#define MARGIN_USE_LOSS       3

#define MARGIN_CALC_FOREX     0        // margin calculation modes
#define MARGIN_CALC_CFD       1
#define MARGIN_CALC_FUTURES   2
#define MARGIN_CALC_CFDINDEX  3

#define MARGIN_TYPE_PERCENT   0        // stop out modes
#define MARGIN_TYPE_CURRENCY  1

#define COMM_TYPE_MONEY       0        // commission types
#define COMM_TYPE_PIPS        1
#define COMM_TYPE_PERCENT     2

#define COMMISSION_PER_LOT    0        // commission per lot or per deal
#define COMMISSION_PER_DEAL   1


// FXT file header
int      i_version=FXT_VERSION;                                                        //    0 + 4
string   s_copyright="Copyleft removed";                                 // 64 bytes   //    4 + 64
string   s_server;                                   // 128 bytes                      //   68 + 128
string   s_symbol;                                   // 12 bytes                       //  196 + 12
int      i_period;                                                                     //  208 + 4
int      i_model=0;                                  // every tick model               //  212 + 4
int      i_bars=0;                                   // bars processed                 //  216 + 4
datetime t_fromdate=0;                               // begin modelling date           //  220 + 4
datetime t_todate=0;                                 // end modelling date             //  224 + 4
//++++ add 4 bytes to align the next double                                            +++++++
double   d_modelquality=99.0;                                                          //  232 + 8
//---- common parameters                                                               -------
string   s_currency;                                 // base currency (12 bytes)       //  240 + 12
int      i_spread;                                                                     //  252 + 4
int      i_digits;                                                                     //  256 + 4
//++++ add 4 bytes to align the next double                                            +++++++
double   d_point;                                                                      //  264 + 8
int      i_lot_min;                                  // minimal lot size               //  272 + 4
int      i_lot_max;                                  // maximal lot size               //  276 + 4
int      i_lot_step;                                                                   //  280 + 4
int      i_stops_level;                              // stops level value              //  284 + 4
bool     b_gtc_pendings=false;                       // good till cancel               //  288 + 4
//---- profit calculation parameters                                                   -------
//++++ add 4 bytes to align the next double                                            +++++++
double   d_contract_size;                                                              //  296 + 8
double   d_tick_value;                                                                 //  304 + 8
double   d_tick_size;                                                                  //  312 + 8
int      i_profit_mode=PROFIT_CALC_FOREX;            // profit calculation mode        //  320 + 4
//---- swaps calculation                                                               -------
bool     b_swap_enable=true;                                                           //  324 + 4
int      i_swap_type=SWAP_BY_POINTS;                 // type of swap                   //  328 + 4
//++++ add 4 bytes to align the next double                                            +++++++
double   d_swap_long;                                                                  //  336 + 8
double   d_swap_short;                               // overnight swaps values         //  344 + 8
int      i_swap_rollover3days=3;                     // number of day of triple swaps  //  352 + 4
//---- margin calculation                                                              -------
int      i_leverage=100;                                                               //  356 + 4
int      i_free_margin_mode=MARGIN_USE_ALL;          // free margin calculation mode   //  360 + 4
int      i_margin_mode=MARGIN_CALC_FOREX;            // margin calculation mode        //  364 + 4
int      i_margin_stopout=30;                        // margin stopout level           //  368 + 4
int      i_margin_stopout_mode=MARGIN_TYPE_PERCENT;  // margin stopout check mode      //  372 + 4
double   d_margin_initial=0.0;                       // margin requirements            //  376 + 8
double   d_margin_maintenance=0.0;                                                     //  384 + 8
double   d_margin_hedged=0.0;                                                          //  392 + 8
double   d_margin_divider=1.0;                                                         //  400 + 8
string   s_margin_currency;                          // 12 bytes                       //  408 + 12
//---- commissions calculation                                                         -------
//++++ add 4 bytes to align the next double                                            +++++++
double   d_comm_base=0.0;                            // basic commission               //  424 + 8
int      i_comm_type=COMM_TYPE_PIPS;                 // basic commission type          //  432 + 4
int      i_comm_lots=COMMISSION_PER_LOT;             // commission per lot or per deal //  436 + 4
//---- for internal use                                                                -------
int      i_from_bar=0;                               // 'fromdate' bar number          //  440 + 4
int      i_to_bar=0;                                 // 'todate' bar number            //  444 + 4
int      i_start_period[6];                                                            //  448 + 24
int      i_from=0;                                   // must be zero                   //  472 + 4
int      i_to=0;                                     // must be zero                   //  476 + 4
int      i_freeze_level=0;                           // order's freeze level in points //  480 + 4
int      i_reserved[61];                             // unused                         //  484 + 244 = 600


/**
 * FXT file header
 */
void WriteHeader(int handle, string symbol, int period, int start_bar, int spread, double commission=0, int leverage=100) {
   s_server              = AccountServer();
   d_comm_base           = commission;
   i_leverage            = leverage;

   s_symbol              = symbol;
   i_period              = period;
   i_bars                = 0;
   s_currency            = StringSubstr(s_symbol, 0, 3);

   i_spread              = MarketInfo(s_symbol, MODE_SPREAD); if (spread > 0) i_spread = spread;
   i_digits              = Digits;
   d_point               = Point;
   i_lot_min             = MarketInfo(s_symbol, MODE_MINLOT)  * 100;
   i_lot_max             = MarketInfo(s_symbol, MODE_MAXLOT)  * 100;
   i_lot_step            = MarketInfo(s_symbol, MODE_LOTSTEP) * 100;
   i_stops_level         = MarketInfo(s_symbol, MODE_STOPLEVEL);
   d_contract_size       = MarketInfo(s_symbol, MODE_LOTSIZE);
   d_tick_value          = MarketInfo(s_symbol, MODE_TICKVALUE);
   d_tick_size           = MarketInfo(s_symbol, MODE_TICKSIZE);
   i_profit_mode         = MarketInfo(s_symbol, MODE_PROFITCALCMODE);
   i_swap_type           = MarketInfo(s_symbol, MODE_SWAPTYPE);
   d_swap_long           = MarketInfo(s_symbol, MODE_SWAPLONG);
   d_swap_short          = MarketInfo(s_symbol, MODE_SWAPSHORT);
   i_free_margin_mode    = AccountFreeMarginMode();
   i_margin_mode         = MarketInfo(s_symbol, MODE_MARGINCALCMODE);
   i_margin_stopout      = AccountStopoutLevel();
   i_margin_stopout_mode = AccountStopoutMode();
   d_margin_initial      = MarketInfo(s_symbol, MODE_MARGININIT);
   d_margin_maintenance  = MarketInfo(s_symbol, MODE_MARGINMAINTENANCE);
   d_margin_hedged       = MarketInfo(s_symbol, MODE_MARGINHEDGED);
   s_margin_currency     = AccountCurrency();
   i_from_bar            = start_bar;
   i_start_period[0]     = start_bar;
   i_freeze_level        = MarketInfo(s_symbol, MODE_FREEZELEVEL);

   FileWriteInteger(handle, i_version,             LONG_VALUE  );
   FileWriteString (handle, s_copyright,           64          );
   FileWriteString (handle, s_server,              128         );
   FileWriteString (handle, s_symbol,              12          );
   FileWriteInteger(handle, i_period,              LONG_VALUE  );
   FileWriteInteger(handle, i_model,               LONG_VALUE  );
   FileWriteInteger(handle, i_bars,                LONG_VALUE  );
   FileWriteInteger(handle, t_fromdate,            LONG_VALUE  );
   FileWriteInteger(handle, t_todate,              LONG_VALUE  );
   FileWriteInteger(handle, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (handle, d_modelquality,        DOUBLE_VALUE);
   FileWriteString (handle, s_currency,            12          );
   FileWriteInteger(handle, i_spread,              LONG_VALUE  );
   FileWriteInteger(handle, i_digits,              LONG_VALUE  );
   FileWriteInteger(handle, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (handle, d_point,               DOUBLE_VALUE);
   FileWriteInteger(handle, i_lot_min,             LONG_VALUE  );
   FileWriteInteger(handle, i_lot_max,             LONG_VALUE  );
   FileWriteInteger(handle, i_lot_step,            LONG_VALUE  );
   FileWriteInteger(handle, i_stops_level,         LONG_VALUE  );
   FileWriteInteger(handle, b_gtc_pendings,        LONG_VALUE  );
   FileWriteInteger(handle, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (handle, d_contract_size,       DOUBLE_VALUE);
   FileWriteDouble (handle, d_tick_value,          DOUBLE_VALUE);
   FileWriteDouble (handle, d_tick_size,           DOUBLE_VALUE);
   FileWriteInteger(handle, i_profit_mode,         LONG_VALUE  );
   FileWriteInteger(handle, b_swap_enable,         LONG_VALUE  );
   FileWriteInteger(handle, i_swap_type,           LONG_VALUE  );
   FileWriteInteger(handle, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (handle, d_swap_long,           DOUBLE_VALUE);
   FileWriteDouble (handle, d_swap_short,          DOUBLE_VALUE);
   FileWriteInteger(handle, i_swap_rollover3days,  LONG_VALUE  );
   FileWriteInteger(handle, i_leverage,            LONG_VALUE  );
   FileWriteInteger(handle, i_free_margin_mode,    LONG_VALUE  );
   FileWriteInteger(handle, i_margin_mode,         LONG_VALUE  );
   FileWriteInteger(handle, i_margin_stopout,      LONG_VALUE  );
   FileWriteInteger(handle, i_margin_stopout_mode, LONG_VALUE  );
   FileWriteDouble (handle, d_margin_initial,      DOUBLE_VALUE);
   FileWriteDouble (handle, d_margin_maintenance,  DOUBLE_VALUE);
   FileWriteDouble (handle, d_margin_hedged,       DOUBLE_VALUE);
   FileWriteDouble (handle, d_margin_divider,      DOUBLE_VALUE);
   FileWriteString (handle, s_margin_currency,     12          );
   FileWriteInteger(handle, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (handle, d_comm_base,           DOUBLE_VALUE);
   FileWriteInteger(handle, i_comm_type,           LONG_VALUE  );
   FileWriteInteger(handle, i_comm_lots,           LONG_VALUE  );
   FileWriteInteger(handle, i_from_bar,            LONG_VALUE  );
   FileWriteInteger(handle, i_to_bar,              LONG_VALUE  );
   FileWriteArray  (handle, i_start_period, 0,     6           );
   FileWriteInteger(handle, i_from,                LONG_VALUE  );
   FileWriteInteger(handle, i_to,                  LONG_VALUE  );
   FileWriteInteger(handle, i_freeze_level,        LONG_VALUE  );
   FileWriteArray  (handle, i_reserved, 0,         61          );
}


/**
 *
 */
bool ReadAndCheckHeader(int handle, int period, int &bars) {
   int    iValue;
   double dValue;
   string sValue;

   GetLastError();
   FileFlush(handle);
   FileSeek(handle, 0, SEEK_SET);

   if (FileReadInteger(handle, LONG_VALUE) != FXT_VERSION) return(false);  // file version

   FileSeek(handle, 64, SEEK_CUR);
   if (FileReadString(handle, 12) != Symbol())             return(false);  // symbol
   if (FileReadInteger(handle, LONG_VALUE) != period)      return(false);  // period
   if (FileReadInteger(handle, LONG_VALUE) != 0)           return(false);  // model type: every tick

   iValue = FileReadInteger(handle, LONG_VALUE);                           // bars
   if (iValue <= 0)                                        return(false);
   bars = iValue;

   FileSeek(handle, 12, SEEK_CUR);
   dValue = FileReadDouble(handle, DOUBLE_VALUE);                          // model quality
   if (dValue < 0 || dValue > 100)                         return(false);

   sValue = FileReadString(handle, 12);                                    // currency
   if (sValue != StringSubstr(Symbol(), 0, 3))             return(false);

   if (FileReadInteger(handle, LONG_VALUE) < 0)            return(false);  // spread
   if (FileReadInteger(handle, LONG_VALUE) != Digits)      return(false);  // digits
   FileSeek(handle, 4, SEEK_CUR);
   if (FileReadDouble(handle, DOUBLE_VALUE) != Point)      return(false);  // point

   if (FileReadInteger(handle, LONG_VALUE) < 0)            return(false);  // min lot
   if (FileReadInteger(handle, LONG_VALUE) < 0)            return(false);  // max lot
   if (FileReadInteger(handle, LONG_VALUE) < 0)            return(false);  // lot step

   if (FileReadInteger(handle, LONG_VALUE) < 0)            return(false);  // stop level
   FileSeek(handle, 8, SEEK_CUR);
   if (FileReadDouble(handle, DOUBLE_VALUE) < 0)           return(false);  // contract size

   FileSeek(handle, 16, SEEK_CUR);
   iValue = FileReadInteger(handle, LONG_VALUE);                           // profit mode
   if (iValue < 0 || iValue > PROFIT_CALC_FUTURES)         return(false);

   FileSeek(handle, 28, SEEK_CUR);                                         // triple rollovers
   iValue = FileReadInteger(handle, LONG_VALUE);
   if (iValue < 0 || iValue > 6)                           return(false);

   iValue = FileReadInteger(handle, LONG_VALUE);                           // leverage
   if (iValue <= 0 || iValue > 500)                        return(false);

   if( GetLastError() == ERR_END_OF_FILE)                  return(false);  // unexpected end of file
   if (FileSize(handle) < 600+bars*52)                     return(false);  // file size

   return(true);
}
