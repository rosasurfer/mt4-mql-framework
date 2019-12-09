/**
 * FxtHeader.mqh
 *
 * @origin  MetaQuotes
 */

#define FXT_VERSION     405


// FXT file header
int      i_version   = FXT_VERSION;                                                     //    0 + 4
string   s_copyright = "(C)opyright 2005-2007, MetaQuotes Software Corp."; // 64 bytes  //    4 + 64
string   s_server;                                    // 128 bytes                      //   68 + 128
string   s_symbol;                                    // 12 bytes                       //  196 + 12
int      i_period;                                                                      //  208 + 4
int      i_model=0;                                   // every tick model               //  212 + 4
int      i_bars=0;                                    // bars processed                 //  216 + 4
datetime t_fromdate = 0;                              // begin modelling date           //  220 + 4
datetime t_todate   = 0;                              // end modelling date             //  224 + 4
//++++ add 4 bytes to align the next double                                             +++++++
double   d_modelquality = 99.0;                                                         //  232 + 8
//---- common parameters                                                                -------
string   s_currency;                                  // base currency (12 bytes)       //  240 + 12
int      i_spread;                                                                      //  252 + 4
int      i_digits;                                                                      //  256 + 4
//++++ add 4 bytes to align the next double                                             +++++++
double   d_point;                                                                       //  264 + 8
int      i_lot_min;                                   // minimal lot size               //  272 + 4
int      i_lot_max;                                   // maximal lot size               //  276 + 4
int      i_lot_step;                                                                    //  280 + 4
int      i_stops_level;                               // stops level value              //  284 + 4
bool     b_gtc_pendings = false;                      // good till cancel               //  288 + 4
//---- profit calculation parameters                                                    -------
//++++ add 4 bytes to align the next double                                             +++++++
double   d_contract_size;                                                               //  296 + 8
double   d_tick_value;                                                                  //  304 + 8
double   d_tick_size;                                                                   //  312 + 8
int      i_profit_mode = PCM_FOREX;                   // profit calculation mode        //  320 + 4
//---- swaps calculation                                                                -------
bool     b_swap_enable = true;                                                          //  324 + 4
int      i_swap_type   = SCM_POINTS;                  // swap calculation mode          //  328 + 4
//++++ add 4 bytes to align the next double                                             +++++++
double   d_swap_long;                                                                   //  336 + 8
double   d_swap_short;                                // overnight swaps values         //  344 + 8
int      i_swap_rollover3days = 3;                    // weekday of triple swaps        //  352 + 4
//---- margin calculation                                                               -------
int      i_leverage=100;                                                                //  356 + 4
int      i_free_margin_mode    = FMCM_USE_PL;         // free margin calculation mode   //  360 + 4
int      i_margin_mode         = MCM_FOREX;           // margin calculation mode        //  364 + 4
int      i_margin_stopout      = 30;                  // margin stopout level           //  368 + 4
int      i_margin_stopout_mode = MSM_PERCENT;         // margin stopout check mode      //  372 + 4
double   d_margin_initial      = 0.0;                 // margin requirements            //  376 + 8
double   d_margin_maintenance  = 0.0;                                                   //  384 + 8
double   d_margin_hedged       = 0.0;                                                   //  392 + 8
double   d_margin_divider      = 1.0;                                                   //  400 + 8
string   s_margin_currency;                           // 12 bytes                       //  408 + 12
//---- commissions calculation                                                          -------
//++++ add 4 bytes to align the next double                                             +++++++
double   d_comm_base = 0;                             // basic commission               //  424 + 8
int      i_comm_type = COMMISSION_MODE_PIPS;          // basic commission type          //  432 + 4
int      i_comm_lots = COMMISSION_TYPE_PER_DEAL;      // commission per lot or per deal //  436 + 4
//---- for internal use                                                                 -------
int      i_from_bar=0;                                // 'fromdate' bar number          //  440 + 4
int      i_to_bar=0;                                  // 'todate' bar number            //  444 + 4
int      i_start_period[6];                                                             //  448 + 24
int      i_from=0;                                    // must be zero                   //  472 + 4
int      i_to=0;                                      // must be zero                   //  476 + 4
int      i_freeze_level=0;                            // order's freeze level in points //  480 + 4
int      i_reserved[61];                              // unused                         //  484 + 244 = 728


/**
 *
 */
void WriteHeader(int hFile, string symbol, int period, int start_bar, int spread, double commission=0, int leverage=100) {
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

   FileWriteInteger(hFile, i_version,             LONG_VALUE  );
   FileWriteString (hFile, s_copyright,           64          );
   FileWriteString (hFile, s_server,              128         );
   FileWriteString (hFile, s_symbol,              12          );
   FileWriteInteger(hFile, i_period,              LONG_VALUE  );
   FileWriteInteger(hFile, i_model,               LONG_VALUE  );
   FileWriteInteger(hFile, i_bars,                LONG_VALUE  );
   FileWriteInteger(hFile, t_fromdate,            LONG_VALUE  );
   FileWriteInteger(hFile, t_todate,              LONG_VALUE  );
   FileWriteInteger(hFile, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (hFile, d_modelquality,        DOUBLE_VALUE);
   FileWriteString (hFile, s_currency,            12          );
   FileWriteInteger(hFile, i_spread,              LONG_VALUE  );
   FileWriteInteger(hFile, i_digits,              LONG_VALUE  );
   FileWriteInteger(hFile, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (hFile, d_point,               DOUBLE_VALUE);
   FileWriteInteger(hFile, i_lot_min,             LONG_VALUE  );
   FileWriteInteger(hFile, i_lot_max,             LONG_VALUE  );
   FileWriteInteger(hFile, i_lot_step,            LONG_VALUE  );
   FileWriteInteger(hFile, i_stops_level,         LONG_VALUE  );
   FileWriteInteger(hFile, b_gtc_pendings,        LONG_VALUE  );
   FileWriteInteger(hFile, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (hFile, d_contract_size,       DOUBLE_VALUE);
   FileWriteDouble (hFile, d_tick_value,          DOUBLE_VALUE);
   FileWriteDouble (hFile, d_tick_size,           DOUBLE_VALUE);
   FileWriteInteger(hFile, i_profit_mode,         LONG_VALUE  );
   FileWriteInteger(hFile, b_swap_enable,         LONG_VALUE  );
   FileWriteInteger(hFile, i_swap_type,           LONG_VALUE  );
   FileWriteInteger(hFile, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (hFile, d_swap_long,           DOUBLE_VALUE);
   FileWriteDouble (hFile, d_swap_short,          DOUBLE_VALUE);
   FileWriteInteger(hFile, i_swap_rollover3days,  LONG_VALUE  );
   FileWriteInteger(hFile, i_leverage,            LONG_VALUE  );
   FileWriteInteger(hFile, i_free_margin_mode,    LONG_VALUE  );
   FileWriteInteger(hFile, i_margin_mode,         LONG_VALUE  );
   FileWriteInteger(hFile, i_margin_stopout,      LONG_VALUE  );
   FileWriteInteger(hFile, i_margin_stopout_mode, LONG_VALUE  );
   FileWriteDouble (hFile, d_margin_initial,      DOUBLE_VALUE);
   FileWriteDouble (hFile, d_margin_maintenance,  DOUBLE_VALUE);
   FileWriteDouble (hFile, d_margin_hedged,       DOUBLE_VALUE);
   FileWriteDouble (hFile, d_margin_divider,      DOUBLE_VALUE);
   FileWriteString (hFile, s_margin_currency,     12          );
   FileWriteInteger(hFile, 0,                     LONG_VALUE  );    // alignment to 8 bytes
   FileWriteDouble (hFile, d_comm_base,           DOUBLE_VALUE);
   FileWriteInteger(hFile, i_comm_type,           LONG_VALUE  );
   FileWriteInteger(hFile, i_comm_lots,           LONG_VALUE  );
   FileWriteInteger(hFile, i_from_bar,            LONG_VALUE  );
   FileWriteInteger(hFile, i_to_bar,              LONG_VALUE  );
   FileWriteArray  (hFile, i_start_period, 0,     6           );
   FileWriteInteger(hFile, i_from,                LONG_VALUE  );
   FileWriteInteger(hFile, i_to,                  LONG_VALUE  );
   FileWriteInteger(hFile, i_freeze_level,        LONG_VALUE  );
   FileWriteArray  (hFile, i_reserved, 0,         61          );

   return;
   int iNull; ReadAndCheckHeader(NULL, NULL, iNull);
}


/**
 *
 */
bool ReadAndCheckHeader(int hFile, int period, int &bars) {
   FileFlush(hFile);
   FileSeek(hFile, 0, SEEK_SET);

   if (FileReadInteger(hFile, LONG_VALUE) != FXT_VERSION)      return(false);  // file version

   FileSeek(hFile, 196, SEEK_SET);
   if (FileReadString(hFile, 12) != Symbol())                  return(false);  // symbol
   if (FileReadInteger(hFile, LONG_VALUE) != period)           return(false);  // period
   if (FileReadInteger(hFile, LONG_VALUE) != 0)                return(false);  // modeling type: every tick

   int iValue = FileReadInteger(hFile, LONG_VALUE);
   if (iValue <= 0)                                            return(false);  // modeledBars
   bars = iValue;

   FileSeek(hFile, 232, SEEK_SET);
   double dValue = FileReadDouble(hFile, DOUBLE_VALUE);
   if (dValue < 0 || dValue > 100)                             return(false);  // modeling quality

   string sValue = FileReadString(hFile, 12);
   if (sValue != StringSubstr(Symbol(), 0, 3))                 return(false);  // base currency

   if (FileReadInteger(hFile, LONG_VALUE) < 0)                 return(false);  // spread
   if (FileReadInteger(hFile, LONG_VALUE) != Digits)           return(false);  // digits
   FileSeek(hFile, 264, SEEK_SET);
   if (FileReadDouble(hFile, DOUBLE_VALUE) != Point)           return(false);  // point

   if (FileReadInteger(hFile, LONG_VALUE) < 0)                 return(false);  // min lot
   if (FileReadInteger(hFile, LONG_VALUE) < 0)                 return(false);  // max lot
   if (FileReadInteger(hFile, LONG_VALUE) < 0)                 return(false);  // lot step

   if (FileReadInteger(hFile, LONG_VALUE) < 0)                 return(false);  // stops distance level

   FileSeek(hFile, 296, SEEK_SET);
   if (FileReadDouble(hFile, DOUBLE_VALUE) < 0)                return(false);  // contract size

   FileSeek(hFile, 320, SEEK_SET);
   iValue = FileReadInteger(hFile, LONG_VALUE);
   if (iValue < PCM_FOREX || iValue > PCM_FUTURES)             return(false);  // profit calculation mode

   FileSeek(hFile, 352, SEEK_SET);
   iValue = FileReadInteger(hFile, LONG_VALUE);
   if (iValue < SUNDAY || iValue > SATURDAY)                   return(false);  // triple rollover weekday

   iValue = FileReadInteger(hFile, LONG_VALUE);
   if (iValue <= 0 || iValue > 500)                            return(false);  // account leverage

   if (FileSize(hFile) < FXT_HEADER.size + bars*FXT_TICK.size) return(false);  // file size

   return(!catch("ReadAndCheckHeader(1)"));
   WriteHeader(NULL, NULL, NULL, NULL, NULL);
}
