//
// MetaTrader structure FXT_HEADER: FXT-File Header version 405 (ab Build ???)
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 FXT Header"
description "Files '*.fxt'"

applies_to  file
fixed_start 0

begin
   endsection
                                                    // -- offset ---- size --- description ----------------------------------------------------------------------------
   uint32       "Version"                           //         0         4     Header-Version
   char[64]     "Description"                       //         4        64
   char[128]    "Server Name"                       //        68       128
   char[12]     "Symbol"                            //       196        12
   uint32       "Timeframe (minutes)"               //       208         4
   endsection

   uint32       "Model Type"                        //       212         4     0=EveryTick|1=ControlPoints|2=BarOpen
   move         16                                  //       216        16
   double       "Model Quality"                     //       232         8
   move         244                                 //       240       244
   uint32       "Model Errors"                      //       484         4     number of errors during model generation
   move         -272                                //       488      -272
   uint32       "Modeled Bars (w/o prolog)"         //       216         4
   move         220                                 //       220       220
   uint32       "First Bar (w/o prolog)"            //       440         4     bar number (0: first bar)
   move         -224                                //       444      -224
   UNIXDateTime "First Bar Time"                    //       220         4
   move         220                                 //       224       220
   uint32       "Last Bar (w/o prolog)"             //       444         4     bar number (0: last bar)
   move         -224                                //       448      -224
   UNIXDateTime "Last Bar Time"                     //       224         4
   move         12                                  //       228        12
   endsection

   // common parameters                             // ----------------------------------------------------------------------------------------------------------------
   char[12]     "Base Currency"                     //       240        12
   uint32       "Spread (points)"                   //       252         4     0 = current spread (variable)
   uint32       "Digits"                            //       256         4
   move         4                                   //       260         4
   double       "Point Size"                        //       264         8
   uint32       "Min Lotsize * 100"                 //       272         4     in Hundertsteln Lot
   uint32       "Max Lotsize * 100"                 //       276         4     in Hundertsteln Lot
   uint32       "Lot Stepsize * 100"                //       280         4     in Hundertsteln Lot
   uint32       "Stop Distance (points)"            //       284         4
   move         192                                 //       288       192
   uint32       "Freeze Distance (points)"          //       480         4
   move         -196                                //       484      -196
   boole32      "Pendings GTC"                      //       288         4
   move         4                                   //       292         4
   endsection

   // profit calculation parameters                 // ----------------------------------------------------------------------------------------------------------------
   double       "Contract Size (units)"             //       296         8
   double       "Tick Value"                        //       304         8     in Quote-Currency oder Accountwährung ???
   double       "Tick Size"                         //       312         8
   uint32       "Profit Calculation Mode"           //       320         4
   endsection

   // swap calculation parameters                   // ----------------------------------------------------------------------------------------------------------------
   boole32      "Swap Enabled"                      //       324         4
   uint32       "Swap Type"                         //       328         4
   move         4                                   //       332         4
   double       "Long Swap Value"                   //       336         8
   double       "Short Swap Value"                  //       344         8
   uint32       "Triple Rollover Weekday"           //       352         4
   endsection

   // margin calculation parameters                 // ----------------------------------------------------------------------------------------------------------------
   uint32       "Account Leverage"                  //       356         4
   move         4                                   //       360         4
   uint32       "Margin Calculation Mode"           //       364         4
   move         -8                                  //       368        -8
   uint32       "Free Margin Calculation Type"      //       360         4
   move         8                                   //       364         8
   uint32       "Margin Stopout Type"               //       372         4
   move         -8                                  //       376        -8
   uint32       "Margin Stopout Level (%)"          //       368         4
   move         4                                   //       372         4
   double       "Margin Init (units)"               //       376         8
   double       "Margin Maintenance (units)"        //       384         8
   double       "Margin Hedged (units)"             //       392         8
   double       "Margin Divider"                    //       400         8     AccountLeverage Divider oder CustomLeverage
   char[12]     "Margin Currency"                   //       408        12
   move         4                                   //       420         4
   endsection

   // commission calculation parameters             // ----------------------------------------------------------------------------------------------------------------
   move         8                                   //       424         8
   uint32       "Commission Calculation Mode"       //       432         4
   move         -12                                 //       436       -12
   double       "Commission Value"                  //       424         8     commission rate
   move         4                                   //       432         4
   uint32       "Commission Type"                   //       436         4     !!! prüfen !!! round-turn or per deal
   endsection

   // later additions                               // ----------------------------------------------------------------------------------------------------------------
   move         4                                   //       440         4     skip "First Bar"          (see above)
   move         4                                   //       444         4     skip "Last Bar"           (see above)
   uint32[6]    "Start Period"                      //       448        24     [0] = index of first bar
   UNIXDateTime "Tester Setting From"               //       472         4     begin date from tester settings
   UNIXDateTime "Tester Setting To"                 //       476         4     end date from tester settings
   move         4                                   //       480         4     skip "Order Freeze Level" (see above)
   move         4                                   //       484         4     skip "Model Errors"       (see above)
   hex 240      "Reserved"                          //       488       240
end
