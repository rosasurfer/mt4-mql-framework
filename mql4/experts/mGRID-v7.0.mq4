/**
 * mGRID v7.0
 *
 *  <Jwentro>
 *  1. Maybe instead of having a fixed dollar amount of what we are willing to lose before the EA closes all trades we could have an option for
 *     a fixed percentage of your account you're willing to lose (15-20%).
 *  2. Maybe a mode to close all trades if your equity is a certain amount over your account balance. This setting could be useful if you were
 *     running the EA across multiple pairs and one pair was killing your account while another was saving it.
 *  3. Been playing around with the idea of putting 2 or 3 as the increment and 30-50 levels. That way we can capture relatively simple up and
 *     down price movements or "ride the waves".
 *
 *  <ForexFlash>
 *  Jwentro, here is your request. Loss is now based on margin %.  This EA is totaly recoded, the logic is different and more efficient.
 *
 * @see http://www.forexfactory.com/showthread.php?p=2280173#post2280173
 */


//---- EA input parameters
extern double lots             = 0.03;   // Starting levels pips

extern double MarginStop       = 200.0;  // Stop at margin level

extern int    pips             = 20;     // Number of pips between each level

extern int    Levels           = 3;      // Number of levels of the pending orders

extern int    ProfitTarget     = 40;     // Minimum profit target, in pips.

extern bool   ContinueTrading  = true;
extern bool   UseEntryTime     = false;
extern int    EntryTime        = 0;

int    First_Target            = 0;
int    Target_Increment        = 0;
bool   RunAsLoop               = false;

//+------------------------------------------------------------------+
//---- EA variables

int    Leverage, nextTP,
       NumBuys, NumSells, TotalTrades,
       NumBuyOrders, NumSellOrders, TotalOrders;

double templots, Investment, MarginLevel,
       BuyGoal, SellGoal, BuyGoalProfit, SellGoalProfit;

string MarginLevelStr, AccountTypeString;

bool   Enter = true, LotsTooSmall, AccountIsMini;

int    Magic=1803979;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+

int init()
{
nextTP = First_Target;
while (RunAsLoop)        // infinite loop for main program
{
if (IsConnected()) main();
PrintComments();
Sleep(1000);           // give your PC a breath
}
return(0);
}


//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+

int deinit()
{
return(0);
}
int start()
{
if (!RunAsLoop)
{
main();
PrintComments();
}
return(0);
}

//+------------------------------------------------------------------+
//| expert main function                                             |
//+------------------------------------------------------------------+

int main()
{
int ticket, cpt, profit, total = 0, PipsLot;
double spread = (Ask-Bid)/Point, InitialPrice = 0;

BuyGoal        = 0.0;
SellGoal       = 0.0;
BuyGoalProfit  = 0.0;
SellGoalProfit = 0.0;

if (AccountMargin() > 0.0)
MarginLevel = 100.0 * (AccountEquity() / AccountMargin());
else
MarginLevel = 0.0;
MarginLevelStr = DoubleToStr(MarginLevel, 2);
if(pips < MarketInfo(Symbol(), MODE_STOPLEVEL)+spread) pips = 1+MarketInfo(Symbol(), MODE_STOPLEVEL) + spread;
CountOrdersAndTrades();
{
for(cpt=1; cpt<Levels; cpt++) PipsLot += cpt*pips;
//+------------------------------------------------------------------+
//check Initial Price

for(cpt=0;cpt<OrdersTotal();cpt++)
{
OrderSelect(cpt,SELECT_BY_POS,MODE_TRADES);
if(OrderMagicNumber()==Magic && OrderSymbol()==Symbol())
{
total++;
if(!InitialPrice) InitialPrice=StrToDouble(OrderComment());
}}
if (MarginLevel > 0.0 && MarginLevel < MarginStop)
{
Print("Not enough free margin to place orders.");
return(0);
}
if(TotalTrades + TotalOrders == 0 &&
total < 1 && Enter && (!UseEntryTime || (UseEntryTime && Hour() == EntryTime)))
{

//+------------------------------------------------------------------+
// Set up a new grid

InitialPrice = Ask;
SellGoal = InitialPrice-(Levels+1)*pips*Point;
BuyGoal  = InitialPrice+(Levels+1)*pips*Point;
for(cpt = 1; cpt <= Levels; cpt++)
{
OrderSend(Symbol(),OP_BUYSTOP,lots,InitialPrice+cpt*pips*Point,2,SellGoal,BuyGoal,
DoubleToStr(InitialPrice,MarketInfo(Symbol(),MODE_DIGITS)),Magic,0,Blue);
Sleep(1000);

OrderSend(Symbol(),OP_SELLSTOP,lots,InitialPrice-cpt*pips*Point,2,
BuyGoal+spread*Point,SellGoal+spread*Point,
DoubleToStr(InitialPrice,MarketInfo(Symbol(),MODE_DIGITS)),Magic,0,Red);
Sleep(1000);
}}

//+------------------------------------------------------------------+
// Initial setup done

else
{
BuyGoal  = InitialPrice+pips*(Levels+1)*Point;
SellGoal = InitialPrice-pips*(Levels+1)*Point;
total    = OrdersHistoryTotal();

for (cpt = 0; cpt < total; cpt++)
{
OrderSelect(cpt,SELECT_BY_POS,MODE_HISTORY);
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol() &&
StrToDouble(OrderComment()) == InitialPrice)
{
EndSession();
return(0);
}}

BuyGoalProfit  = CheckProfits(lots,OP_BUY,false,InitialPrice);
SellGoalProfit = CheckProfits(lots,OP_SELL,false,InitialPrice);

if (BuyGoalProfit < ProfitTarget)
{
for (cpt = Levels; cpt >= 1 && BuyGoalProfit < ProfitTarget; cpt--)
{
if (Ask <= (InitialPrice+(cpt*pips-MarketInfo(Symbol(),MODE_STOPLEVEL))*Point))
{

//+------------------------------------------------------------------+

templots = lots*3;
ticket = OrderSend(Symbol(),OP_BUYSTOP,templots,InitialPrice+cpt*pips*Point,2,SellGoal,BuyGoal,
DoubleToStr(InitialPrice,MarketInfo(Symbol(),MODE_DIGITS)),Magic,0,Blue);
Sleep(1000);
}
if (ticket > 0)
BuyGoalProfit += lots*(BuyGoal-InitialPrice-cpt*pips*Point)/Point;
}}
if (SellGoalProfit < ProfitTarget)
{
for (cpt = Levels; cpt >= 1 && SellGoalProfit < ProfitTarget; cpt--)
{
if (Bid >= (InitialPrice-(cpt*pips-MarketInfo(Symbol(),MODE_STOPLEVEL))*Point))
{

//+------------------------------------------------------------------+

templots = lots*3;
ticket = OrderSend(Symbol(),OP_SELLSTOP,templots,InitialPrice-cpt*pips*Point,2,BuyGoal+spread*Point,SellGoal+spread*Point,
DoubleToStr(InitialPrice,MarketInfo(Symbol(),MODE_DIGITS)),Magic,0,Red);
Sleep(1000);
}
if (ticket > 0)
SellGoalProfit += lots*(InitialPrice-cpt*pips*Point-SellGoal-spread*Point)/Point;
}}}
return(0);
}}

//+------------------------------------------------------------------+

void PrintComments()
{
string sComment   = "";
string sep        = "----------------------------------------\n";
string nl         = "\n";

sComment = "S\R stdDev Math Grid" + nl;
sComment = sComment + "FX Acc Server:" + AccountServer()+ nl;
sComment = sComment + "Date: "+ Month()+"-"+Day()+"-"+Year()+" Server Time: "+Hour()+":"+Minute()+":"+Seconds() + nl;
sComment = sComment + "Buy Trades= " + NumBuys + ", Sell Trades= " + NumSells + nl;
sComment = sComment + "Buy Orders= " + NumBuyOrders + ", Sell Orders= " + NumSellOrders + nl;

if (MarginLevel > 0.0 && MarginLevel < MarginStop)
{
sComment = sComment + nl + "NO NEW ORDERS DUE TO MARGIN LEVEL " + MarginStop + "%" + nl + sep;
}
else
{
sComment = sComment + "Lots=" + DoubleToStr(lots,2) + nl;
sComment = sComment + "Buy Goal= " + DoubleToStr(BuyGoal,4) + nl;
sComment = sComment + "Buy Goal Profit (in pips)=" + BuyGoalProfit + nl + nl;
sComment = sComment + "Sell Goal= " + DoubleToStr(SellGoal,4) + nl;
sComment = sComment + "Sell Goal Profit (in pips)=" + SellGoalProfit + nl + nl;
sComment = sComment + "Pips of each level=" + pips + nl;
sComment = sComment + "Number of levels for each goal: " + Levels + nl;
sComment = sComment + sep;
}
Comment(sComment);
}

//+------------------------------------------------------------------+

void CountOrdersAndTrades()
{
int cpt;

NumBuys     = 0;
NumSells    = 0;
TotalTrades = 0;
NumBuyOrders  = 0;
NumSellOrders = 0;
TotalOrders   = 0;

for(cpt = 0; cpt < OrdersTotal(); cpt++)
{
OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
{
if (OrderType() == OP_BUY)
{
NumBuys++;
}
else if (OrderType() == OP_SELL)
{
NumSells++;
}
else if (OrderType() == OP_BUYSTOP)
{
NumBuyOrders++;
}
else if (OrderType() == OP_SELLSTOP)
{
NumSellOrders++;
}}}
TotalTrades = NumBuys + NumSells;
TotalOrders = NumBuyOrders + NumSellOrders;
}

//+------------------------------------------------------------------+

double CheckProfits(double lots, int Goal, bool Current, double InitialPrice)
{
double profit = 0.0;
int    cpt;

if (Current) //return current profit
{
for(cpt = 0; cpt < OrdersTotal(); cpt++)
{
OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
if(OrderSymbol() == Symbol() && StrToDouble(OrderComment()) == InitialPrice)
{
if (OrderType() == OP_BUY)
{
profit += (Bid-OrderOpenPrice())/Point*OrderLots()/lots;
}
if (OrderType() == OP_SELL)
{
profit += (OrderOpenPrice()-Ask)/Point*OrderLots()/lots;
}}}
return(profit);
}
else
{
if (Goal == OP_BUY)
{
for (cpt = 0; cpt < OrdersTotal(); cpt++)
{
OrderSelect (cpt, SELECT_BY_POS, MODE_TRADES);
if (OrderSymbol() == Symbol() && StrToDouble(OrderComment()) == InitialPrice)
{
if (OrderType() == OP_BUY)
{
profit += (OrderTakeProfit()-OrderOpenPrice())/Point*OrderLots()/lots;
}
if (OrderType() == OP_SELL)
{
profit -= (OrderStopLoss()-OrderOpenPrice())/Point*OrderLots()/lots;
}
if (OrderType() == OP_BUYSTOP)
{
profit += (OrderTakeProfit()-OrderOpenPrice())/Point*OrderLots()/lots;
}}}
return(profit);
}
else
{
for(cpt = 0; cpt < OrdersTotal(); cpt++)
{
OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
if (OrderSymbol() == Symbol() && StrToDouble(OrderComment()) == InitialPrice)
{
if (OrderType() == OP_BUY)
{
profit -= (OrderOpenPrice()-OrderStopLoss())/Point*OrderLots()/lots;
}
if (OrderType() == OP_SELL)
{
profit += (OrderOpenPrice()-OrderTakeProfit())/Point*OrderLots()/lots;
}
if (OrderType() == OP_SELLSTOP)
{
profit += (OrderOpenPrice()-OrderTakeProfit())/Point*OrderLots()/lots;
}}}
return(profit);
}}}

//+------------------------------------------------------------------+

bool EndSession()
{
int cpt, total = OrdersTotal();

for(cpt=0;cpt<total;cpt++)
{
OrderSelect(cpt,SELECT_BY_POS,MODE_TRADES);
if (OrderSymbol() == Symbol() && OrderType() > 1)
{
OrderDelete(OrderTicket());
}
else if (OrderSymbol() == Symbol() && OrderType() == OP_BUY)
{
OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red);
}
else if (OrderSymbol() == Symbol() && OrderType() == OP_SELL)
{
OrderClose(OrderTicket(), OrderLots(), Ask, 3, Red);
}}
if (!ContinueTrading)
{
Enter = false;
}
return(true);
}





