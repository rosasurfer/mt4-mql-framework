/**
 * Zeichnet die echten Equity-Werte des aktuellen Accounts auf. Diese Werte sind nicht wie vom Broker berechnet sondern Value-To-Market
 * (ohne mehrfache Gebühren, ohne ggf. außerordentlichen Spread).
 */
#include  <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>

#property indicator_chart_window


double   account.data     [2];                                       // Accountdaten
double   account.data.last[2];                                       // vorheriger Datenwert für RecordAccountData()
int      account.hSet     [2];                                       // HistorySet-Handles der Accountdaten

string   account.symbolSuffixes    [] = { ".EA"                           , ".EX"                                                 };
string   account.symbolDescriptions[] = { "Account {AccountNumber} equity", "Account {AccountNumber} equity with external assets" };

// Array-Indizes
#define I_ACCOUNT_EQUITY            0                                // echter Equity-Wert des Accounts (nicht wie vom Broker berechnet)
#define I_ACCOUNT_EQUITY_WITH_AUM   1                                // echter Equity-Wert inklusive externer Assets


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);

   int size = ArraySize(account.hSet);
   for (int i=0; i < size; i++) {
      if (account.hSet[i] != 0) {
         int tmp=account.hSet[i]; account.hSet[i]=NULL;
         if (!HistorySet.Close(tmp)) return(ERR_RUNTIME_ERROR);
      }
   }
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // alte Ticks abfangen (am oder nach dem Wochenende)
   bool isStale = (Tick.Time < GetServerTime()-2*MINUTES);
   if (isStale) return(last_error);

   // aktuelle Accountdaten ermitteln
   if (!CollectAccountData()) return(last_error);

   // Accountdaten speichern
   if (!RecordAccountData()) return(last_error);

   return(last_error);
}


/**
 * Ermittelt die aktuellen Accountdaten: Account-Balance und Account-Equity jeweils mit und ohne externe Assets
 *
 * @return bool - Erfolgsstatus
 */
bool CollectAccountData() {
   // nach Symbol gruppierte Daten
   string symbols       []; ArrayResize(symbols       , 0);          // alle Symbole mit offenen Positionen
   double symbols.profit[]; ArrayResize(symbols.profit, 0);          // Gesamt-P/L eines Symbols


   // (1) offene Positionen einlesen
   int orders = OrdersTotal();
   int    symbols.idx[]; ArrayResize(symbols.idx, orders);           // Index des OrderSymbols in symbols[]
   int    tickets    []; ArrayResize(tickets    , orders);
   int    types      []; ArrayResize(types      , orders);
   double lots       []; ArrayResize(lots       , orders);
   double openPrices []; ArrayResize(openPrices , orders);
   double commissions[]; ArrayResize(commissions, orders);
   double swaps      []; ArrayResize(swaps      , orders);
   double profits    []; ArrayResize(profits    , orders);

   for (int n, si, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
      if (OrderType() > OP_SELL) continue;
      if (!n) {
         si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      else if (symbols[si] != OrderSymbol()) {
         si = SearchStringArray(symbols, OrderSymbol());
         if (si == -1)
            si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      symbols.idx[n] = si;
      tickets    [n] = OrderTicket();
      types      [n] = OrderType();
      lots       [n] = NormalizeDouble(OrderLots(), 2);
      openPrices [n] = OrderOpenPrice();
      commissions[n] = OrderCommission();
      swaps      [n] = OrderSwap();
      profits    [n] = OrderProfit();
      n++;
   }
   if (n < orders) {
      ArrayResize(symbols.idx, n);
      ArrayResize(tickets    , n);
      ArrayResize(types      , n);
      ArrayResize(lots       , n);
      ArrayResize(openPrices , n);
      ArrayResize(commissions, n);
      ArrayResize(swaps      , n);
      ArrayResize(profits    , n);
      orders = n;
   }


   // (2) P/L je Symbol ermitteln
   int symbolsSize = ArraySize(symbols);
   ArrayResize(symbols.profit, symbolsSize);

   for (i=0; i < symbolsSize; i++) {
      symbols.profit[i] = CalculateProfit(symbols[i], i, symbols.idx, tickets, types, lots, openPrices, commissions, swaps, profits);
      if (IsEmptyValue(symbols.profit[i]))
         return(false);
      symbols.profit[i] = NormalizeDouble(symbols.profit[i], 2);
   }


   // (3) resultierende Accountdaten berechnen und global speichern
   double fullPL          = SumDoubles(symbols.profit);
   double externalAssets  = GetExternalAssets(ShortAccountCompany(), GetAccountNumber()); if (IsEmptyValue(externalAssets)) return(false);

   account.data[I_ACCOUNT_EQUITY         ] = NormalizeDouble(AccountBalance()               + fullPL        , 2);
   account.data[I_ACCOUNT_EQUITY_WITH_AUM] = NormalizeDouble(account.data[I_ACCOUNT_EQUITY] + externalAssets, 2);

   //static bool done;
   //if (!done) done = !debug("CollectAccountData(2)  equity="+ DoubleToStr(account.data[I_ACCOUNT_EQUITY], 2) +"  withAuM="+ DoubleToStr(account.data[I_ACCOUNT_EQUITY_WITH_AUM], 2));

   return(!catch("CollectAccountData(3)"));
}


/**
 * Analysiert die übergebenen Daten, berechnet den effektiven Gesamt-P/L je Symbol und gibt die Ergebnisse zurück.
 *
 * @param  string symbol        - Symbol
 * @param  int    index         - Index des Symbols in symbols[]. Es werden nur Daten derjenigen Orders analysiert, deren Variable symbols.idx[] diesem Wert entspricht.
 *
 * @param  int    symbol.idx []
 * @param  int    tickets    []
 * @param  int    types      []
 * @param  double lots       []
 * @param  double openPrices []
 * @param  double commissions[]
 * @param  double swaps      []
 * @param  double profits    []
 *
 * @return double - P/L-Value oder EMPTY_VALUE, falls ein Fehler auftrat
 */
double CalculateProfit(string symbol, int index, int symbol.idx[], int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double longPosition, shortPosition, totalPosition, hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, fullProfit, hedgedProfit, vtmProfit, pipValue, pipDistance;
   int    ticketsSize = ArraySize(tickets);

   // (1) Gesamtposition des Symbols ermitteln: gehedgter Anteil (konstanter Profit) und direktionaler Anteil (variabler Profit)
   for (int i=0; i < ticketsSize; i++) {
      if (symbol.idx[i] != index) continue;

      if (types[i] == OP_BUY) longPosition  += lots[i];                          // Gesamtposition je Richtung aufaddieren
      else                    shortPosition += lots[i];
   }
   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition-shortPosition, 2);

   int    digits     = MarketInfo(symbol, MODE_DIGITS);                          // TODO: !!! digits ist u.U. falsch gesetzt !!!
   int    pipDigits  = digits & (~1);
   double pipSize    = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);
   double spreadPips = MarketInfo(symbol, MODE_SPREAD)/MathPow(10, digits & 1);  // SpreadPoints/PipPoints = Spread in Pip


   // (2) Konstanten Profit einer eventuellen Hedgeposition ermitteln
   if (longPosition && shortPosition) {
      hedgedLots     = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (i=0; i < ticketsSize; i++) {
         if (symbol.idx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
               swap         += swaps[i];                swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                        profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else /*types[i] == OP_SELL*/ {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               //commission  += commissions[i];                                        // Commission wird nur für Long-Leg übernommen
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lots[i];
               closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // Commission wird nur für Long-Leg übernommen
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(_EMPTY_VALUE(catch("CalculateProfit(1)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));
      if (remainingShort != 0) return(_EMPTY_VALUE(catch("CalculateProfit(2)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));

      // Breakeven-Distance und daraus Profit berechnen
      pipValue     = PipValueEx(symbol, hedgedLots); if (!pipValue) return(EMPTY_VALUE);
      pipDistance  = (closePrice-openPrice)/hedgedLots/pipSize + (commission+swap)/pipValue;
      hedgedProfit = pipDistance * pipValue;

      // ohne direktionalen Anteil nur Hedged-Profit zurückgeben
      if (!totalPosition) {
         fullProfit = NormalizeDouble(hedgedProfit, 2);
         return(ifDouble(!catch("CalculateProfit(3)"), fullProfit, EMPTY_VALUE));
      }
   }


   // (3) Variablen Profit einer eventuellen Longposition ermitteln
   if (totalPosition > 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbol.idx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }

      // Halben Spread und dessen Profitanteil berechnen und diesen zuschlagen
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition); if (!pipValue) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(4)"), fullProfit, EMPTY_VALUE));
   }


   // (4) Variablen Profit einer eventuellen Shortposition ermitteln
   if (totalPosition < 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbol.idx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_SELL) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // Halben Spread und dessen Profitanteil berechnen und diesen zuschlagen
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition); if (!pipValue) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(5)"), fullProfit, EMPTY_VALUE));
   }

   return(_EMPTY_VALUE(catch("CalculateProfit(6)  unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Zeichnet Balance und Equity des Accounts auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordAccountData() {
   if (IsTesting())
      return(true);

   datetime now.fxt = GetFxtTime();
   int      size    = ArraySize(account.hSet);

   for (int i=0; i < size; i++) {
      double tickValue     = account.data     [i];
      double lastTickValue = account.data.last[i];

      // Virtuelle Ticks werden nur aufgezeichnet, wenn sich der Datenwert geändert hat.
      if (Tick.isVirtual) {
         if (!lastTickValue || EQ(tickValue, lastTickValue, 2)) {
            if (account.symbolSuffixes[i]==".AB") debug("RecordAccountData(1)  Tick.isVirtual="+ Tick.isVirtual +"  skipping "+ account.symbolSuffixes[i] +" tick "+ DoubleToStr(tickValue, 2));
            continue;
         }
      }

      //if (account.symbolSuffixes[i]==".AB") debug("RecordAccountData(2)  Tick.isVirtual="+ Tick.isVirtual +"  recording "+ account.symbolSuffixes[i] +" tick "+ DoubleToStr(tickValue, 2));

      if (!account.hSet[i]) {
         string symbol      = GetAccountNumber() + account.symbolSuffixes[i];
         string description = StringReplace(account.symbolDescriptions[i], "{AccountNumber}", GetAccountNumber());
         int    digits      = 2;
         int    format      = 400;
         string server      = "XTrade-Synthetic";

         account.hSet[i] = HistorySet.Get(symbol, server);
         if (account.hSet[i] == -1)
            account.hSet[i] = HistorySet.Create(symbol, description, digits, format, server);
         if (!account.hSet[i]) return(false);
      }

      if (!HistorySet.AddTick(account.hSet[i], now.fxt, tickValue, NULL)) return(false);

      account.data.last[i] = tickValue;
   }
   return(true);
}
