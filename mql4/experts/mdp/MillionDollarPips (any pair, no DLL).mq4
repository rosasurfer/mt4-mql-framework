#property copyright "Copyright ? 2011"
#property link      "http://www.metaquotes.net"
#property show_inputs

#include <stdlib.mqh>

extern string Configuration = "================ Configuration";
extern bool Show_Debug = false;
extern bool Verbose = false;
extern bool Mode_HighSpeed = true;
extern bool Mode_Safe = false;
extern bool Mode_MaxOrders = true;
bool gi_104 = false;
extern string Username = "Traders-Shop";
extern int Magic = 112226;
extern string OrderCmt = "MDP_2";
extern double TakeProfit = 10.0;
extern double StopLoss = 60.0;
extern double distance = 30.0;
extern string Money_Management = "---------------- Money Management";
double gd_136 = 0.1;
bool gi_144 = true;
extern double Min_Lots = 0.01;
extern double Max_Lots = 1000.0;
extern double Risk = 1000.0;
double gd_172 = 0.0;
string gs_unused_180 = "---------------- Scalping Factors";
double gd_188 = 15.0;
double gd_196 = 40.0;
double gd_204 = 145.0;
double gd_212 = 270.0;
double gd_220 = 0.4;
double gd_228 = 0.3333333333;
double gd_236 = 0.0;
extern string SL_TP_Trailing = "---------------- SL / TP / Trailing";
extern double Trailing_Resolution = 0.0;
double gd_260 = 0.0;
double gd_268 = 20.0;
extern bool Trailing_Stop = true;
bool gi_280 = true;
string gs_304;
int gi_312 = 0;
double gd_316 = 0.0;
int g_slippage_324 = 3;
double gda_328[30];
double gda_332[30];
int gia_336[30];
double gd_340 = 1.0;
double gd_348;
bool gi_356;
double gd_360;
bool gi_368 = false;
double gd_372 = 1.0;
double gd_380 = 0.0;
int gi_388 = 0;
int g_time_392 = 0;
int g_count_396 = 0;
double gda_400[30];
int gi_404 = 0;
bool gi_408 = true;
double gd_412 = 5.0;
double gd_420 = 10.0;
double gd_428 = 40.0;
bool gi_436 = false;
double gd_440 = 5.0;
double gd_448 = 10.0;
double gd_456 = 40.0;
bool gi_464 = false;
bool gi_unused_468 = false;
string gs_472 = "Valid user";
string gs_480;
int gia_488[] = {0};
int gia_492[] = {0};
int AccNum;

int init() {
   ArrayInitialize(gda_400, 0);
   gi_312 = 5;
   gd_316 = 0.00001;
   if (Digits < 5) g_slippage_324 = 0;
   else gi_388 = -1;
   gia_492[0]=1;
   start();
   return (0);
}

int start() {
   if (gi_312 == 0) {
      init();
      return;
   }
   if (gia_492[0] == true) {
         f0_2(gda_328, gda_332, gia_336, gd_340);
         f0_0(Period());
   }
   return (0);
}

void f0_0(int a_timeframe_0) {
   int ticket_16;
   int li_24;
   double ld_28;
   double ld_30;
   bool bool_28;
   double ld_92;
   bool li_116;
   double ld_120;
   double ld_136;
   double ld_220;
   int datetime_236;
   int li_240;
   double ld_244;
   double order_stoploss_260;
   double order_takeprofit_268;
   double ld_276;
   int li_292;
   int li_296;
   string ls_300;
   bool li_308;
   if (g_time_392 < Time[0]) {
      g_time_392 = Time[0];
      g_count_396 = 0;
   } else g_count_396++;
   double ihigh_64 = iHigh(Symbol(), a_timeframe_0, 0);
   double ilow_72 = iLow(Symbol(), a_timeframe_0, 0);
   double icustom_32 =  iMA(NULL, a_timeframe_0, 3, 0, MODE_LWMA, PRICE_LOW, 0);
   double icustom_40 =  iMA(NULL, a_timeframe_0, 3, 0, MODE_LWMA, PRICE_HIGH, 0);
   double ld_80 = icustom_32 - icustom_40;
   bool li_88 = Bid >= icustom_40 + ld_80 / 2.0;
   if (!gi_368) {
      for (int pos_4 = OrdersTotal() - 1; pos_4 >= 0; pos_4--) {
         OrderSelect(pos_4, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() == Symbol() && OrderCloseTime() != 0 && OrderClosePrice() != OrderOpenPrice() && OrderProfit() != 0.0 && OrderComment() != "partial close" && StringFind(OrderComment(), "[sl]from #") == -1 &&
            StringFind(OrderComment(), "[tp]from #") == -1) {
            gi_368 = true;
            ld_92 = MathAbs(OrderProfit() / (OrderClosePrice() - OrderOpenPrice()));
            gd_372 = ld_92 / OrderLots() / MarketInfo(Symbol(), MODE_LOTSIZE);
            gd_380 = (-OrderCommission()) / ld_92;
            Print("Commission_Rate : " + f0_3(gd_380));
            break;
         }
      }
   }
   if (!gi_368) {
      for (pos_4 = OrdersHistoryTotal() - 1; pos_4 >= 0; pos_4--) {
         OrderSelect(pos_4, SELECT_BY_POS, MODE_HISTORY);
         if (OrderSymbol() == Symbol() && OrderCloseTime() != 0 && OrderClosePrice() != OrderOpenPrice() && OrderProfit() != 0.0 && OrderComment() != "partial close" && StringFind(OrderComment(), "[sl]from #") == -1 &&
            StringFind(OrderComment(), "[tp]from #") == -1) {
            gi_368 = true;
            ld_92 = MathAbs(OrderProfit() / (OrderClosePrice() - OrderOpenPrice()));
            gd_372 = ld_92 / OrderLots() / MarketInfo(Symbol(), MODE_LOTSIZE);
            gd_380 = (-OrderCommission()) / ld_92;
            Print("Commission_Rate : " + f0_3(gd_380));
            break;
         }
      }
   }
   double ld_100 = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double ld_108 = Ask - Bid;
   double ld_128 = 0.5;
   if (ld_128 < ld_100 - 5.0 * gd_316) {
      li_116 = gi_436;
      ld_120 = gd_428 * gd_316;
      ld_128 = gd_420 * gd_316;
      ld_136 = gd_412 * gd_316;
   } else {
      if (!Mode_HighSpeed) {
         li_116 = gi_464;
         ld_120 = gd_456 * gd_316;
         ld_128 = gd_448 * gd_316;
         ld_136 = gd_440 * gd_316;
      } else {
         li_116 = gi_280;
         ld_120 = gd_268 * gd_316;
         ld_128 = gd_260 * gd_316;
         ld_136 = Trailing_Resolution * gd_316;
      }
   }
   ld_120 = MathMax(ld_120, ld_100);
   if (li_116) ld_128 = MathMax(ld_128, ld_100);
   double ld_unused_144 = gda_400[0];
   ArrayCopy(gda_400, gda_400, 0, 1, 29);
   gda_400[29] = ld_108;
   if (gi_404 < 30) gi_404++;
   double ld_152 = 0;
   pos_4 = 29;
   for (int count_8 = 0; count_8 < gi_404; count_8++) {
      ld_152 += gda_400[pos_4];
      pos_4--;
   }
   double ld_160 = ld_152 / gi_404;
   if (!gi_368 && ld_160 < 15.0 * gd_316) gd_380 = 15.0 * gd_316 - ld_160;
   double ld_168 = f0_5(Ask + gd_380);
   double ld_176 = f0_5(Bid - gd_380);
   double ld_184 = ld_160 + gd_380;

   double ld_192;
   double ld_200;
   double ld_208 = ihigh_64 - ilow_72;

   double limitTe;
   string mode=Mode_HighSpeed+"-"+Mode_Safe+"-0";
        if(mode=="0-0-0") { ld_192=0.24; ld_200=0.0018; limitTe=0.00250; }
   else if(mode=="0-1-0") { ld_192=0.68; ld_200=0.0023; limitTe=0.00300; }
   else if(mode=="1-0-0") { ld_192=0.28; ld_200=0.0018; limitTe=0.00100; }
   else if(mode=="1-1-0") { ld_192=0.56; ld_200=0.0022; limitTe=0.00250; }

   if(ld_208>limitTe) {
   if (Bid < icustom_40)   int li_216=-1;
   else if (Bid > icustom_32) li_216=1;
    }
   if (gd_236 == 0.0) ld_220 = gd_228 * ld_200;
   else ld_220 = gd_236 * gd_316;
   ld_220 = MathMax(ld_100, ld_220);
   if (Bid == 0.0 || MarketInfo(Symbol(), MODE_LOTSIZE) == 0.0) ld_220 = 0;
   double ld_228 = ld_220 + ld_160 + gd_380;
   if (gi_408) datetime_236 = TimeCurrent() + 60.0 * MathMax(10 * a_timeframe_0, 60);
   else datetime_236 = 0;
   if (MarketInfo(Symbol(), MODE_LOTSTEP) == 0.0) li_240 = 5;
   else li_240 = f0_7(0.1, MarketInfo(Symbol(), MODE_LOTSTEP));
   if (gi_144) {
      if (Risk < 0.001 || Risk > 1000.0) {
         Comment("ERROR -- Invalid Risk Value.");
         return;
      }
      if (AccountBalance() <= 0.0) {
         Comment("ERROR -- Account Balance is " + DoubleToStr(MathRound(AccountBalance()), 0));
         return;
      }
      if (ld_220 != 0.0) {
         gd_172 = MathMax(AccountBalance(), gd_172);
         ld_244 = MathMin(AccountFreeMargin() * AccountLeverage() / 2.0, gd_172 * Risk / 100.0 * Bid / ld_228);
         gd_136 = ld_244 / MarketInfo(Symbol(), MODE_LOTSIZE);
         gd_136 = NormalizeDouble(gd_136, li_240);
         gd_136 = MathMax(Min_Lots, gd_136);
         gd_136 = MathMax(MarketInfo(Symbol(), MODE_MINLOT), gd_136);
         gd_136 = MathMin(Max_Lots, gd_136);
         gd_136 = MathMin(MarketInfo(Symbol(), MODE_MAXLOT), gd_136);
      }
   }
   int count_252 = 0;
   int count_256 = 0;
   for (pos_4 = 0; pos_4 < OrdersTotal(); pos_4++) {
      OrderSelect(pos_4, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber() == Magic && OrderCloseTime() == 0) {
         if (OrderSymbol() != Symbol()) {
            count_256++;
            continue;
         }
         switch (OrderType()) {
         case OP_BUY:
            while (Trailing_Stop) {
               order_stoploss_260 = OrderStopLoss();
               order_takeprofit_268 = OrderTakeProfit();
               if (!(order_takeprofit_268 < f0_5(ld_168 + ld_120) && ld_168 + ld_120 - order_takeprofit_268 > ld_136)) break;
               order_stoploss_260 = f0_5(Bid - ld_120);
               order_takeprofit_268 = f0_5(ld_168 + ld_120);
               bool_28 = OrderModify(OrderTicket(), 0, order_stoploss_260, order_takeprofit_268, datetime_236, Lime);
               if (bool_28) break;
               li_24 = f0_1();
               if (!(li_24)) break;
            }
            count_252++;
            break;
         case OP_SELL:
            while (Trailing_Stop) {
               order_stoploss_260 = OrderStopLoss();
               order_takeprofit_268 = OrderTakeProfit();
               if (!(order_takeprofit_268 > f0_5(ld_176 - ld_120) && order_takeprofit_268 - ld_176 + ld_120 > ld_136)) break;
               order_stoploss_260 = f0_5(Ask + ld_120);
               order_takeprofit_268 = f0_5(ld_176 - ld_120);
               bool_28 = OrderModify(OrderTicket(), 0, order_stoploss_260, order_takeprofit_268, datetime_236, Orange);
               if (bool_28) break;
               li_24 = f0_1();
               if (!(li_24)) break;
            }
            count_252++;
            break;
         case OP_BUYSTOP:
            if (!li_88) {
               ld_276 = OrderTakeProfit() - OrderOpenPrice() - gd_380;
               while (true) {
                  if (!(f0_5(Ask + ld_128) < OrderOpenPrice() && OrderOpenPrice() - Ask - ld_128 > ld_136)) break;
                  bool_28 = OrderModify(OrderTicket(), f0_5(Ask + ld_128), f0_5(Bid + ld_128 - ld_276), f0_5(ld_168 + ld_128 + ld_276), 0, Lime);
                  if (bool_28) break;
                  li_24 = f0_1();
                  if (!(li_24)) break;
               }
               count_252++;
            } else OrderDelete(OrderTicket());
            break;
         case OP_SELLSTOP:
            if (li_88) {
               ld_276 = OrderOpenPrice() - OrderTakeProfit() - gd_380;
               while (true) {
                  if (!(f0_5(Bid - ld_128) > OrderOpenPrice() && Bid - ld_128 - OrderOpenPrice() > ld_136)) break;
                  bool_28 = OrderModify(OrderTicket(), f0_5(Bid - ld_128), f0_5(Ask - ld_128 + ld_276), f0_5(ld_176 - ld_128 - ld_276), 0, Orange);
                  if (bool_28) break;
                  li_24 = f0_1();
                  if (!(li_24)) break;
               }
               count_252++;
            } else OrderDelete(OrderTicket());
         }
      }
   }
   bool li_288 = false;
   if (gi_388 >= 0 || gi_388 == -2) {
      li_292 = NormalizeDouble(Bid / gd_316, 0);
      li_296 = NormalizeDouble(Ask / gd_316, 0);
      if (li_292 % 10 != 0 || li_296 % 10 != 0) gi_388 = -1;
      else {
         if (gi_388 >= 0 && gi_388 < 10) gi_388++;
         else gi_388 = -2;
      }
   }
   if (ld_220 != 0.0 && count_252 == 0 && li_216 != 0 && f0_5(ld_184) <= f0_5(gd_196 * gd_316) && gi_388 == -1) {
      if (li_216 < 0) {
         if (li_116) {
         ld_28 = Ask + distance * Point;
            ticket_16 = OrderSend(Symbol(), OP_BUYSTOP, gd_136, ld_28, g_slippage_324, ld_28 - StopLoss * Point, ld_28 + TakeProfit * Point, OrderCmt, Magic, datetime_236, Lime);
            if (ticket_16 < 0) {
               li_288 = true;
               Print("ERROR BUYSTOP : " + f0_3(Ask + ld_128) + " SL:" + f0_3(Bid + ld_128 - ld_220) + " TP:" + f0_3(ld_168 + ld_128 + ld_220));
            } else {
               PlaySound("news.wav");
               Print("BUYSTOP : " + f0_3(Ask + ld_128) + " SL:" + f0_3(Bid + ld_128 - ld_220) + " TP:" + f0_3(ld_168 + ld_128 + ld_220));
            }
         } else {
            if (Bid - ilow_72  && gd_348 > 0.0) {
               ticket_16 = OrderSend(Symbol(), OP_BUY, gd_136, Ask, g_slippage_324, 0, 0, OrderCmt, Magic, datetime_236, Lime);
               if (ticket_16 < 0) {
                  li_288 = true;
                  Print("ERROR BUY Ask:" + f0_3(Ask) + " SL:" + f0_3(Bid - ld_220) + " TP:" + f0_3(ld_168 + ld_220));
               } else {
                  while (true) {
                     bool_28 = OrderModify(ticket_16, 0, f0_5(Bid - ld_220), f0_5(ld_168 + ld_220), datetime_236, Lime);
                     if (bool_28) break;
                     li_24 = f0_1();
                     if (!(li_24)) break;
                  }
                  PlaySound("news.wav");
                  Print("BUY Ask:" + f0_3(Ask) + " SL:" + f0_3(Bid - ld_220) + " TP:" + f0_3(ld_168 + ld_220));
               }
            }
         }
      } else {
         if (li_216 > 0) {
            if (li_116) {
            ld_30 =Bid - distance * Point;
               ticket_16 = OrderSend(Symbol(), OP_SELLSTOP, gd_136, ld_30, g_slippage_324, ld_30 + StopLoss * Point, ld_30 - TakeProfit * Point, OrderCmt, Magic, datetime_236, Orange);
               if (ticket_16 < 0) {
                  li_288 = true;
                  Print("ERROR SELLSTOP : " + f0_3(Bid - ld_128) + " SL:" + f0_3(Ask - ld_128 + ld_220) + " TP:" + f0_3(ld_176 - ld_128 - ld_220));
               } else {
                  PlaySound("news.wav");
                  Print("SELLSTOP : " + f0_3(Bid - ld_128) + " SL:" + f0_3(Ask - ld_128 + ld_220) + " TP:" + f0_3(ld_176 - ld_128 - ld_220));
               }
            } else {
               if (ihigh_64 - Bid  && gd_348 < 0.0) {
                  ticket_16 = OrderSend(Symbol(), OP_SELL, gd_136, Bid, g_slippage_324, 0, 0, OrderCmt, Magic, datetime_236, Orange);
                  if (ticket_16 < 0) {
                     li_288 = true;
                     Print("ERROR SELL Bid:" + f0_3(Bid) + " SL:" + f0_3(Ask + ld_220) + " TP:" + f0_3(ld_176 - ld_220));
                  } else {
                     while (true) {
                        bool_28 = OrderModify(ticket_16, 0, f0_5(Ask + ld_220), f0_5(ld_176 - ld_220), datetime_236, Orange);
                        if (bool_28) break;
                        li_24 = f0_1();
                        if (!(li_24)) break;
                     }
                     PlaySound("news.wav");
                     Print("SELL Bid:" + f0_3(Bid) + " SL:" + f0_3(Ask + ld_220) + " TP:" + f0_3(ld_176 - ld_220));
                  }
               }
            }
         }
      }
   }
   if (gi_388 >= 0) Comment("Robot is initializing...");
   else {
      if (gi_388 == -2) Comment("ERROR -- Instrument " + Symbol() + " prices should have " + gi_312 + " fraction digits on broker account");
      else {
         ls_300 = TimeToStr(TimeCurrent()) + " tick:" + f0_6(g_count_396);
         if (Show_Debug || Verbose) {
            ls_300 = ls_300
               + "\n"
            + f0_3(ld_200) + " " + f0_3(ld_220) + " digits:" + gi_312 + " " + gi_388 + " stopLevel:" + f0_3(ld_100);
            ls_300 = ls_300
               + "\n"
            + li_216 + " " + f0_3(icustom_40) + " " + f0_3(icustom_32) + " " + f0_3(gd_220) + " exp:" + TimeToStr(datetime_236, TIME_MINUTES) + " numOrders:" + count_252 + " shouldRepeat:" + li_288;
            ls_300 = ls_300
            + "\ntrailingLimit:" + f0_3(ld_128) + " trailingDist:" + f0_3(ld_120) + " trailingResolution:" + f0_3(ld_136) + " useStopOrders:" + li_116;
         }
         ls_300 = ls_300
         + "\nBid:" + f0_3(Bid) + " Ask:" + f0_3(Ask) + " avgSpread:" + f0_3(ld_160) + "  Commission rate:" + f0_3(gd_380) + "  Real avg. spread:" + f0_3(ld_184) + "  Lots:" + f0_4(gd_136, li_240);
         if (Mode_HighSpeed) ls_300 = ls_300 + "   HIGH SPEED";
         if (Mode_Safe) ls_300 = ls_300 + "   SAFE";
         if (Mode_MaxOrders) ls_300 = ls_300 + "   MAX";
         if (f0_5(ld_184) > f0_5(gd_196 * gd_316)) {
            ls_300 = ls_300
               + "\n"
            + "Robot is OFF :: Real avg. spread is too high for this scalping strategy ( " + f0_3(ld_184) + " > " + f0_3(gd_196 * gd_316) + " )";
         }
         Comment(ls_300);
         if (count_252 != 0 || li_216 != 0 || Verbose) f0_8(ls_300);
      }
   }
   if (li_288) {
      li_308 = f0_1();
      if (li_308) f0_0(a_timeframe_0);
   }
}

int f0_1() {
   return (0);
}

void f0_2(double &ada_0[30], double &ada_4[30], int &aia_8[30], double ad_12) {
   double ld_52;
   if (aia_8[0] == 0 || MathAbs(Bid - ada_0[0]) >= ad_12 * gd_316) {
      for (int li_20 = 29; li_20 > 0; li_20--) {
         ada_0[li_20] = ada_0[li_20 - 1];
         ada_4[li_20] = ada_4[li_20 - 1];
         aia_8[li_20] = aia_8[li_20 - 1];
      }
      ada_0[0] = Bid;
      ada_4[0] = Ask;
      aia_8[0] = GetTickCount();
   }
   gd_348 = 0;
   gi_356 = false;
   double ld_24 = 0;
   int li_32 = 0;
   double ld_36 = 0;
   int li_44 = 0;
   int li_unused_48 = 0;
   for (li_20 = 1; li_20 < 30; li_20++) {
      if (aia_8[li_20] == 0) break;
      ld_52 = ada_0[0] - ada_0[li_20];
      if (ld_52 < ld_24) {
         ld_24 = ld_52;
         li_32 = aia_8[0] - aia_8[li_20];
      }
      if (ld_52 > ld_36) {
         ld_36 = ld_52;
         li_44 = aia_8[0] - aia_8[li_20];
      }
      if (ld_24 < 0.0 && ld_36 > 0.0 && ld_24 < 3.0 * ((-ad_12) * gd_316) || ld_36 > 3.0 * (ad_12 * gd_316)) {
         if ((-ld_24) / ld_36 < 0.5) {
            gd_348 = ld_36;
            gi_356 = li_44;
            break;
         }
         if ((-ld_36) / ld_24 < 0.5) {
            gd_348 = ld_24;
            gi_356 = li_32;
         }
      } else {
         if (ld_36 > 5.0 * (ad_12 * gd_316)) {
            gd_348 = ld_36;
            gi_356 = li_44;
         } else {
            if (ld_24 < 5.0 * ((-ad_12) * gd_316)) {
               gd_348 = ld_24;
               gi_356 = li_32;
               break;
            }
         }
      }
   }
   if (gi_356 == false) {
      gd_360 = 0;
      return;
   }
   gd_360 = 1000.0 * gd_348 / gi_356;
}

string f0_3(double ad_0) {
   return (DoubleToStr(ad_0, gi_312));
}

string f0_4(double ad_0, int ai_8) {
   return (DoubleToStr(ad_0, ai_8));
}

double f0_5(double ad_0) {
   return (NormalizeDouble(ad_0, gi_312));
}

string f0_6(int ai_0) {
   if (ai_0 < 10) return ("00" + ai_0);
   if (ai_0 < 100) return ("0" + ai_0);
   return ("" + ai_0);
}

double f0_7(double ad_0, double ad_8) {
   return (MathLog(ad_8) / MathLog(ad_0));
}

void f0_8(string as_0) {
   int li_12;
   int li_8 = -1;
   while (li_8 < StringLen(as_0)) {
      li_12 = li_8 + 1;
      li_8 = StringFind(as_0,
      "\n", li_12);
      if (li_8 == -1) {
         Print(StringSubstr(as_0, li_12));
         return;
      }
      Print(StringSubstr(as_0, li_12, li_8 - li_12));
   }
}
