/**
 * Zeigt im Chart verschiedene aktuelle Informationen an.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>

#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>

#include <core/script.ParameterProvider.mqh>
#include <LFX/functions.mqh>
#include <LFX/quickchannel.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


// Label der einzelnen Anzeigen
string label.instrument      = "Instrument";
string label.ohlc            = "OHLC";
string label.price           = "Price";
string label.spread          = "Spread";
string label.unitSize        = "UnitSize";
string label.position        = "Position";
string label.time            = "Time";
string label.lfxTradeAccount = "LfxTradeAccount";
string label.stopoutLevel    = "StopoutLevel";


int    appliedPrice = PRICE_MEDIAN;                                  // Bid | Ask | Median (default)
double unleveragedLots;                                              // aktuelle Lotsize bei Hebel 1:1


// lokale Positionsdaten                                             // Die lokalen Positionsdaten werden bei jedem Tick zurückgesetzt und neu eingelesen.
bool   positionsAnalyzed;
bool   isLocalPosition;
double totalPosition;                                                // Gesamtposition total
double longPosition;                                                 // Gesamtposition long
double shortPosition;                                                // Gesamtposition short

double local.position.conf [][2];                                    // individuelle Konfiguration: = {LotSize, Ticket|DirectionType}
int    local.position.types[][2];                                    // Positionsdetails:           = {PositionType, DirectionType}
double local.position.data [][4];                                    //                             = {DirectionalLotSize, HedgedLotSize, BreakevenPrice|Pips, Profit}

#define TYPE_DEFAULT       0                                         // PositionTypes: normale Terminalposition (local oder remote)
#define TYPE_CUSTOM        1                                         //                manuell konfigurierte reale Position
#define TYPE_VIRTUAL       2                                         //                manuell konfigurierte imaginäre Position

#define TYPE_LONG          1                                         // DirectionTypes
#define TYPE_SHORT         2
#define TYPE_HEDGE         3

#define I_DIRECTLOTSIZE    0                                         // Arrayindizes von local.position.data[]
#define I_HEDGEDLOTSIZE    1
#define I_BREAKEVEN        2
#define I_PROFIT           3


// LFX-Positionsdaten
int    lfxOrders.iVolatile[][3];                                     // veränderliche Positionsdaten: = {Ticket, IsOpen, IsLocked}
double lfxOrders.dVolatile[][1];                                     //                               = {Profit}
int    lfxOrders.openPositions;                                      // Anzahl der offenen Positionen in den offenen Orders (IsOpen = 1)

#define I_TICKET           0                                         // Arrayindizes von lfxOrders.*Volatile[]
#define I_ISOPEN           1
#define I_ISLOCKED         2
#define I_VPROFIT          0


// Font-Settings der detaillierten Positionsanzeige (lokal und LFX)
string positions.fontName     = "MS Sans Serif";
int    positions.fontSize     = 8;
color  positions.fontColors[] = {Blue, DeepPink, Green};             // unterschiedliche PositionTypes: {TYPE_DEFAULT, TYPE_CUSTOM, TYPE_VIRTUAL}


#include <ChartInfos/init.mqh>
#include <ChartInfos/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   /*
   if (Symbol() == "GBPCHF") {
      static int changedBars, lastChangedBars; changedBars = Bars - IndicatorCounted();
      if (changedBars > 1 || changedBars != lastChangedBars) debug("onTick()   ChangedBars="+ changedBars);
      lastChangedBars = changedBars;
   }
   */

   positionsAnalyzed = false;

   if (!UpdatePrice())                       return(last_error);
   if (!UpdateOHLC())                        return(last_error);

   if (isLfxInstrument) {
      if (!QC.HandleLfxTerminalMessages())   return(last_error);     // Listener für beim LFX-Terminal eingehende Messages
      if (!UpdatePositions())                return(last_error);
      if (!CheckLfxLimits())                 return(last_error);
   }
   else {
      if (!QC.HandleTradeTerminalMessages()) return(last_error);     // Listener für beim Trade-Terminal eingehende Messages
      if (!UpdateSpread())                   return(last_error);
      if (!UpdateUnitSize())                 return(last_error);
      if (!UpdatePositions())                return(last_error);
      if (!UpdateStopoutLevel())             return(last_error);
   }

   if (IsVisualMode())                                               // nur im Tester
      UpdateTime();
   return(last_error);
}


#define LIMIT_NONE        -1
#define LIMIT_ENTRY        1
#define LIMIT_STOPLOSS     2
#define LIMIT_TAKEPROFIT   3


/**
 * Überprüft alle LFX-Orders auf erreichte Limite: Pending-Open, StopLoss, TakeProfit
 *
 * @return bool - Erfolgsstatus
 */
bool CheckLfxLimits() {
   datetime triggerTime;
   int /*LFX_ORDER*/stored[], orders=ArrayRange(lfxOrders, 0);

   for (int i=0; i < orders; i++) {
      triggerTime = NULL;

      // (1) alle Limite einer Order prüfen
      int result = IsLfxLimitTriggered(i, triggerTime);
      if (!result)              return(false);
      if (result == LIMIT_NONE) continue;

      if (!triggerTime) {
         // (2) ein Limit wurde genau jetzt getriggert
         if (result == LIMIT_ENTRY     ) log("CheckLfxLimits(1)   #"+ los.Ticket(lfxOrders, i) +" "+ OperationTypeToStr(los.Type(lfxOrders, i))         +" at "+ NumberToStr(los.OpenPriceLfx (lfxOrders, i), SubPipPriceFormat) +" triggered (Bid="+ NumberToStr(Bid, PriceFormat) +")");
         if (result == LIMIT_STOPLOSS  ) log("CheckLfxLimits(2)   #"+ los.Ticket(lfxOrders, i) +" StopLoss"  + ifString(los.StopLossLfx  (lfxOrders, i), " at "+ NumberToStr(los.StopLossLfx  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLossLfx  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), "") +" triggered");
         if (result == LIMIT_TAKEPROFIT) log("CheckLfxLimits(3)   #"+ los.Ticket(lfxOrders, i) +" TakeProfit"+ ifString(los.TakeProfitLfx(lfxOrders, i), " at "+ NumberToStr(los.TakeProfitLfx(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfitLfx(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), "") +" triggered");

         // Auslösen speichern und TradeCommand verschicken
         if (result==LIMIT_ENTRY)       los.setOpenTriggerTime    (lfxOrders, i, TimeGMT());
         else {                         los.setCloseTriggerTime   (lfxOrders, i, TimeGMT());
            if (result==LIMIT_STOPLOSS) los.setStopLossTriggered  (lfxOrders, i, true     );
            else                        los.setTakeProfitTriggered(lfxOrders, i, true     );
         }
         if (!LFX.SaveOrder(lfxOrders, i))                                                                              return(false);
         if (!QC.SendTradeCommand("LFX:"+ los.Ticket(lfxOrders, i) + ifString(result==LIMIT_ENTRY, ":open", ":close"))) return(false);
      }
      else if (triggerTime + 30*SECONDS >= TimeGMT()) {
         // (3) ein Limit war bereits vorher getriggert, auf Ausführungsbestätigung warten
      }
      else {
         // (4) ein Limit war bereits vorher getriggert und die Ausführungsbestätigung ist überfällig
         if (LFX.GetOrder(los.Ticket(lfxOrders, i), stored) != 1)    // aktuell gespeicherte Version der Order holen
            return(!catch("CheckLfxLimits(4)->LFX.GetOrder(ticket="+ los.Ticket(lfxOrders, i) +") => "+ result, ERR_RUNTIME_ERROR));

         // prüfen, ob inzwischen ein Open- bzw. Close-Error gesetzt wurde und ggf. Fehler melden und speichern
         if (result == LIMIT_ENTRY) {
            if (!lo.IsOpenError(stored)) {
               warnSMS("CheckLfxLimits(5)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered "+ OperationTypeToStr(los.Type(lfxOrders, i)) +" at "+ NumberToStr(los.OpenPriceLfx(lfxOrders, i), SubPipPriceFormat));
               los.setOpenTime(lfxOrders, i, -TimeGMT());
            }
         }
         else if (!lo.IsCloseError(stored)) {
            if (result == LIMIT_STOPLOSS) warnSMS("CheckLfxLimits(6)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered StopLoss"  + ifString(los.StopLossLfx  (lfxOrders, i), " at "+ NumberToStr(los.StopLossLfx  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLossLfx  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), ""));
            else                          warnSMS("CheckLfxLimits(7)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered TakeProfit"+ ifString(los.TakeProfitLfx(lfxOrders, i), " at "+ NumberToStr(los.TakeProfitLfx(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfitLfx(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), ""));
            los.setCloseTime(lfxOrders, i, -TimeGMT());
         }

         // Order speichern und beim nächsten Tick offene Orders neu einlesen
         if (!LFX.SaveOrder(lfxOrders, i))                                                                                                      return(false);
         if (!QC.SendOrderNotification(lfxCurrencyId, "LFX:"+ los.Ticket(lfxOrders, i) + ifString(result==LIMIT_ENTRY, ":open=0", ":close=0"))) return(false);
      }
   }
   return(true);
}


/**
 * Ob die angegebene LFX-Order ein Limit erreicht hat. Alle Preise werden gegen das Bid geprüft (LFX-Chart).
 *
 * @param  int       i           - Index der zu überprüfenden Order im globalen LFX_ORDER[]-Array
 * @param  datetime &triggerTime - Variable zur Aufnahme des Zeitpunktes eines bereits als getriggert markierten Limits
 *
 * @return int - Ergebnis, LIMIT_NONE:       wenn kein Limit erreicht wurde
 *                         LIMIT_ENTRY:      wenn ein Entry-Limit erreicht wurde
 *                         LIMIT_STOPLOSS:   wenn ein StopLoss-Limit erreicht wurde
 *                         LIMIT_TAKEPROFIT: wenn ein TakeProfit-Limit erreicht wurde
 *                         0:                wenn ein Fehler auftrat
 *
 * Ist ein Limit bereits als getriggert markiert, wird zusätzlich der Triggerzeitpunkt in der Variable triggerTime gespeichert.
 */
int IsLfxLimitTriggered(int i, datetime &triggerTime) {
   triggerTime = NULL;
   if (los.IsClosed(lfxOrders, i))
      return(LIMIT_NONE);

   double slPrice, slValue, tpPrice, tpValue, profit;

   int type = los.Type(lfxOrders, i);

   switch (type) {
      case OP_BUYLIMIT :
      case OP_BUYSTOP  :
      case OP_SELLLIMIT:
      case OP_SELLSTOP :
         if (los.IsOpenError(lfxOrders, i))            return(LIMIT_NONE);
         triggerTime = los.OpenTriggerTime(lfxOrders, i);
         if (triggerTime != 0)                         return(LIMIT_ENTRY);
         break;

      case OP_BUY :
      case OP_SELL:
         if (los.IsCloseError(lfxOrders, i))           return(LIMIT_NONE);
         triggerTime = los.CloseTriggerTime(lfxOrders, i);
         if (triggerTime != 0) {
            if (los.StopLossTriggered  (lfxOrders, i)) return(LIMIT_STOPLOSS  );
            if (los.TakeProfitTriggered(lfxOrders, i)) return(LIMIT_TAKEPROFIT);
            triggerTime = NULL;                        return(_NULL(catch("IsLfxLimitTriggered(1)   data constraint violation in #"+ los.Ticket(lfxOrders, i) +": closeTriggerTime="+ los.CloseTriggerTime(lfxOrders, i) +", slTriggered=0, tpTriggered=0", ERR_RUNTIME_ERROR)));
         }
         break;

      default:
         return(LIMIT_NONE);
   }

   switch (type) {
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         if (LE(Bid, los.OpenPriceLfx(lfxOrders, i))) return(LIMIT_ENTRY);
                                                      return(LIMIT_NONE );
      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
         if (GE(Bid, los.OpenPriceLfx(lfxOrders, i))) return(LIMIT_ENTRY);
                                                      return(LIMIT_NONE );
      default:
         slPrice = los.StopLossLfx    (lfxOrders, i);
         slValue = los.StopLossValue  (lfxOrders, i);
         tpPrice = los.TakeProfitLfx  (lfxOrders, i);
         tpValue = los.TakeProfitValue(lfxOrders, i);
         profit  = lfxOrders.dVolatile[i][I_VPROFIT];
   }

   switch (type) {
      // Um Auslösefehler bei nicht initialisiertem P/L zu verhindern, wird dieser nur geprüft, wenn er ungleich 0.00 ist.
      case OP_BUY:
                                     if (slPrice != 0) if (LE(Bid,    slPrice)) return(LIMIT_STOPLOSS  );
         if (slValue != EMPTY_VALUE) if (profit  != 0) if (LE(profit, slValue)) return(LIMIT_STOPLOSS  );
                                     if (tpPrice != 0) if (GE(Bid,    tpPrice)) return(LIMIT_TAKEPROFIT);
         if (tpValue != EMPTY_VALUE) if (profit  != 0) if (GE(profit, tpValue)) return(LIMIT_TAKEPROFIT);
                                                                                return(LIMIT_NONE      );
      case OP_SELL:
                                     if (slPrice != 0) if (GE(Bid,    slPrice)) return(LIMIT_STOPLOSS  );
         if (slValue != EMPTY_VALUE) if (profit  != 0) if (LE(profit, slValue)) return(LIMIT_STOPLOSS  );
                                     if (tpPrice != 0) if (LE(Bid,    tpPrice)) return(LIMIT_TAKEPROFIT);
         if (tpValue != EMPTY_VALUE) if (profit  != 0) if (GE(profit, tpValue)) return(LIMIT_TAKEPROFIT);
                                                                                return(LIMIT_NONE      );
   }

   return(_NULL(catch("IsLfxLimitTriggered(2)   unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   // Label definieren
   label.instrument      = __NAME__ +"."+ label.instrument;
   label.ohlc            = __NAME__ +"."+ label.ohlc;
   label.price           = __NAME__ +"."+ label.price;
   label.spread          = __NAME__ +"."+ label.spread;
   label.unitSize        = __NAME__ +"."+ label.unitSize;
   label.position        = __NAME__ +"."+ label.position;
   label.time            = __NAME__ +"."+ label.time;
   label.lfxTradeAccount = __NAME__ +"."+ label.lfxTradeAccount;
   label.stopoutLevel    = __NAME__ +"."+ label.stopoutLevel;


   // Instrument-Label: Anzeige wird sofort und nur hier gesetzt
   if (ObjectFind(label.instrument) == 0)
      ObjectDelete(label.instrument);
   if (ObjectCreate(label.instrument, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
         int build = GetTerminalBuild();
      ObjectSet    (label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));
      ObjectSet    (label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));
      ObjectRegister(label.instrument);
   }
   else GetLastError();
   string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
   if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
   else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
   ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);


   // OHLC-Label
   if (ObjectFind(label.ohlc) == 0)
      ObjectDelete(label.ohlc);
   if (ObjectCreate(label.ohlc, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.ohlc, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label.ohlc, OBJPROP_XDISTANCE, 110);
      ObjectSet    (label.ohlc, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label.ohlc, " ", 1);
      ObjectRegister(label.ohlc);
   }
   else GetLastError();


   // Price-Label
   if (ObjectFind(label.price) == 0)
      ObjectDelete(label.price);
   if (ObjectCreate(label.price, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
      ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
      ObjectSetText(label.price, " ", 1);
      ObjectRegister(label.price);
   }
   else GetLastError();


   // Spread-Label: nicht in LFX-Charts
   if (!isLfxInstrument) {
      if (ObjectFind(label.spread) == 0)
         ObjectDelete(label.spread);
      if (ObjectCreate(label.spread, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.spread, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label.spread, OBJPROP_XDISTANCE, 33);
         ObjectSet    (label.spread, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label.spread, " ", 1);
         ObjectRegister(label.spread);
      }
      else GetLastError();
   }


   // UnitSize-Label: nicht in LFX-Charts
   if (!isLfxInstrument) {
      if (ObjectFind(label.unitSize) == 0)
         ObjectDelete(label.unitSize);
      if (ObjectCreate(label.unitSize, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.unitSize, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.unitSize, OBJPROP_XDISTANCE, 9);
         ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, 9);
         ObjectSetText(label.unitSize, " ", 1);
         ObjectRegister(label.unitSize);
      }
      else GetLastError();
   }


   // Gesamt-Position-Label: nicht in LFX-Charts
   if (!isLfxInstrument) {
      if (ObjectFind(label.position) == 0)
         ObjectDelete(label.position);
      if (ObjectCreate(label.position, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.position, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.position, OBJPROP_XDISTANCE,  9);
         ObjectSet    (label.position, OBJPROP_YDISTANCE, 29);
         ObjectSetText(label.position, " ", 1);
         ObjectRegister(label.position);
      }
      else GetLastError();
   }
   else {
      // LFX-Trade-Account-Label: nur in LFX-Charts, Anzeige wird sofort und nur hier gesetzt
      if (!lfxAccount) /*&&*/ if (!LFX.InitAccountData())
         return(last_error);
      name = lfxAccountName +": "+ lfxAccountCompany +", "+ lfxAccount +", "+ lfxAccountCurrency;

      if (ObjectFind(label.lfxTradeAccount) == 0)
         ObjectDelete(label.lfxTradeAccount);
      if (ObjectCreate(label.lfxTradeAccount, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.lfxTradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.lfxTradeAccount, OBJPROP_XDISTANCE, 6);
         ObjectSet    (label.lfxTradeAccount, OBJPROP_YDISTANCE, 4);
         ObjectSetText(label.lfxTradeAccount, name, 8, "Arial Fett", ifInt(lfxAccountType==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
         ObjectRegister(label.lfxTradeAccount);
      }
      else GetLastError();
   }


   // Time-Label: nur im Tester bei VisualMode = ON
   if (IsVisualMode()) {
      if (ObjectFind(label.time) == 0)
         ObjectDelete(label.time);
      if (ObjectCreate(label.time, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.time, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.time, OBJPROP_XDISTANCE,  9);
         ObjectSet    (label.time, OBJPROP_YDISTANCE, 49);
         ObjectSetText(label.time, " ", 1);
         ObjectRegister(label.time);
      }
      else GetLastError();
   }

   return(catch("CreateLabels()"));
}


/**
 * Aktualisiert die Kursanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePrice() {
   static string priceFormat;
   if (!StringLen(priceFormat))
      priceFormat = StringConcatenate(",,", PriceFormat);

   double price;

   if (!Bid) {                                                                // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      price = Close[0];
   }
   else {
      switch (appliedPrice) {
         case PRICE_BID   : price =  Bid;          break;
         case PRICE_ASK   : price =  Ask;          break;
         case PRICE_MEDIAN: price = (Bid + Ask)/2; break;
      }
   }
   ObjectSetText(label.price, NumberToStr(price, priceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error)                             return(true);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(true);                      // bei offenem Properties-Dialog oder Object::onDrag()

   return(!catch("UpdatePrice(2)", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSpread() {
   if (!Bid)                                                                  // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      return(true);

   string strSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, Digits<<31>>31);

   ObjectSetText(label.spread, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateSpread()", error));
   return(true);
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateUnitSize() {
   if (IsTesting())
      return(true);                                                              // Anzeige wird im Tester nicht benötigt

   // (1) Ausgangsdaten bestimmen
   bool   tradeAllowed   = (MarketInfo(Symbol(), MODE_TRADEALLOWED  ) && 1);
   double tickSize       =  MarketInfo(Symbol(), MODE_TICKSIZE      );
   double tickValue      =  MarketInfo(Symbol(), MODE_TICKVALUE     );
   double marginRequired =  MarketInfo(Symbol(), MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = 0;
   double equity         =  MathMin(AccountBalance(), AccountEquity()-AccountCredit());
      int error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL) return(true);
         return(!catch("UpdateUnitSize(1)", error));
      }
   unleveragedLots = 0;                                                          // global, wird auch in UpdatePositions() benötigt


   // (2) UnitSize berechnen
   string strATR, strUnitSize=" ";

   if (tradeAllowed && tickSize && tickValue && marginRequired && equity > 0) {  // bei Start oder Accountwechsel können einige Werte noch ungesetzt sein
      double leverage = 2.5;                                                     // Orientierungswert für eine einzelne neue Position
      double lotValue = Close[0]/tickSize * tickValue;                           // Value eines Lots in Account-Currency
      unleveragedLots = equity / lotValue;                                       // maximal mögliche Lotsize ohne Leverage (Hebel 1:1)
      double unitSize = unleveragedLots * leverage;                              // Equity wird mit 'leverage' gehebelt

      // UnitSize immer ab-, niemals aufrunden                                                                                            Abstufung max. 6.7% je Schritt
      if      (unitSize <=    0.03) unitSize = NormalizeDouble(MathFloor(unitSize/  0.001) *   0.001, 3);   //     0-0.03: Vielfaches von   0.001
      else if (unitSize <=   0.075) unitSize = NormalizeDouble(MathFloor(unitSize/  0.002) *   0.002, 3);   // 0.03-0.075: Vielfaches von   0.002
      else if (unitSize <=    0.1 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.005) *   0.005, 3);   //  0.075-0.1: Vielfaches von   0.005
      else if (unitSize <=    0.3 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.01 ) *   0.01 , 2);   //    0.1-0.3: Vielfaches von   0.01
      else if (unitSize <=    0.75) unitSize = NormalizeDouble(MathFloor(unitSize/  0.02 ) *   0.02 , 2);   //   0.3-0.75: Vielfaches von   0.02
      else if (unitSize <=    1.2 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.05 ) *   0.05 , 2);   //   0.75-1.2: Vielfaches von   0.05
      else if (unitSize <=    3.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.1  ) *   0.1  , 1);   //      1.2-3: Vielfaches von   0.1
      else if (unitSize <=    7.5 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.2  ) *   0.2  , 1);   //      3-7.5: Vielfaches von   0.2
      else if (unitSize <=   12.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.5  ) *   0.5  , 1);   //     7.5-12: Vielfaches von   0.5
      else if (unitSize <=   30.  ) unitSize =       MathRound(MathFloor(unitSize/  1    ) *   1       );   //      12-30: Vielfaches von   1
      else if (unitSize <=   75.  ) unitSize =       MathRound(MathFloor(unitSize/  2    ) *   2       );   //      30-75: Vielfaches von   2
      else if (unitSize <=  120.  ) unitSize =       MathRound(MathFloor(unitSize/  5    ) *   5       );   //     75-120: Vielfaches von   5
      else if (unitSize <=  300.  ) unitSize =       MathRound(MathFloor(unitSize/ 10    ) *  10       );   //    120-300: Vielfaches von  10
      else if (unitSize <=  750.  ) unitSize =       MathRound(MathFloor(unitSize/ 20    ) *  20       );   //    300-750: Vielfaches von  20
      else if (unitSize <= 1200.  ) unitSize =       MathRound(MathFloor(unitSize/ 50    ) *  50       );   //   750-1200: Vielfaches von  50
      else                          unitSize =       MathRound(MathFloor(unitSize/100    ) * 100       );   //   1200-...: Vielfaches von 100

      double atr = ixATR(NULL, PERIOD_W1, 14, 1);// throws ERS_HISTORY_UPDATE
         if (atr == EMPTY)                                                   return(false);
         if (last_error==ERS_HISTORY_UPDATE) /*&&*/ if (Period()!=PERIOD_W1) SetLastError(NO_ERROR);
      if (atr!=NULL) strATR = StringConcatenate("ATRw = ", DoubleToStr(atr/Close[0] * 100, 1), "%     ");

      strUnitSize = StringConcatenate(strATR, "1:", DoubleToStr(leverage, 1), "  =    ", NumberToStr(unitSize, ", .+"), " lot");
   }


   // (3) Anzeige aktualisieren
   ObjectSetText(label.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateUnitSize(2)", error));
   return(true);
}


/**
 * Aktualisiert die Positionsanzeigen: Gesamtposition unten rechts, Einzelpositionen unten links.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePositions() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions())
      return(false);


   // (1) Gesamtpositionsanzeige unten rechts
   string strPosition, strUsedLeverage;
   if      (!isLocalPosition) strPosition = " ";
   else if (!totalPosition  ) strPosition = StringConcatenate("Position:  ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else {
      if (unleveragedLots != 0)
         strUsedLeverage = StringConcatenate("1:", DoubleToStr(MathAbs(totalPosition)/unleveragedLots, 1), "  =  ");
      strPosition = StringConcatenate("Position:  " , strUsedLeverage, NumberToStr(totalPosition, "+, .+"), " lot");
   }
   ObjectSetText(label.position, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdatePositions(1)", error));


   // (2) Einzelpositionsanzeige unten links: ggf. mit Breakeven und Profit/Loss
   // Spalten:           Direction:, LotSize, BE:, BePrice, Profit:, ProfitAmount
   int col.xShifts[]  = {20,         59,      135, 160,     236,     268}, cols=ArraySize(col.xShifts), yDist=3;
   int localPositions = ArrayRange(local.position.types, 0);
   int positions      = localPositions + lfxOrders.openPositions;

   // (2.1) ggf. weitere Zeilen hinzufügen
   static int lines;
   while (lines < positions) {
      lines++;
      for (int col=0; col < cols; col++) {
         string label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, col.xShifts[col]              );
            ObjectSet    (label, OBJPROP_YDISTANCE, yDist + (lines-1)*(positions.fontSize+8));
            ObjectSetText(label, " ", 1);
            ObjectRegister(label);
         }
         else GetLastError();
      }
   }

   // (2.2) nicht benötigte Zeilen löschen
   while (lines > positions) {
      for (col=0; col < cols; col++) {
         label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectFind(label) != -1)
            ObjectDelete(label);
      }
      lines--;
   }

   // (2.3) Zeilen von unten nach oben schreiben: "{Type}: {LotSize}   BE|Dist: {BePrice}   Profit: {ProfitAmount}"
   string strLotSize, strTypes[]={"", "Long:", "Short:", "Hedge:"};  // DirectionTypes (1, 2, 3) werden als Indizes benutzt
   int line;

   // lokale Positionsdaten
   for (int i=localPositions-1; i >= 0; i--) {
      line++;
      if (local.position.types[i][1] == TYPE_HEDGE) {
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[local.position.types[i][1]],                                                                  positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(local.position.data [i][I_HEDGEDLOTSIZE], ".+") +" lot",                                      positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "Dist:",                                                                                                  positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", DoubleToStr(RoundFloor(local.position.data[i][I_BREAKEVEN], Digits-PipDigits), Digits-PipDigits) +" pip", positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                                positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_PROFIT])
         ObjectSetText(label.position +".line"+ line +"_col5", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col5", DoubleToStr(local.position.data[i][I_PROFIT], 2),                                                         positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
      }
      else {
         ObjectSetText(label.position +".line"+ line +"_col0",            strTypes[local.position.types[i][1]],                                                          positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_HEDGEDLOTSIZE]) strLotSize = NumberToStr(local.position.data [i][I_DIRECTLOTSIZE], ".+");
            else                                          strLotSize = NumberToStr(local.position.data [i][I_DIRECTLOTSIZE], ".+") +" ±"+ NumberToStr(local.position.data[i][I_HEDGEDLOTSIZE], ".+");
         ObjectSetText(label.position +".line"+ line +"_col1", strLotSize +" lot",                                                                                       positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else if (local.position.types[i][1] == TYPE_LONG)
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundCeil (local.position.data[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundFloor(local.position.data[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                                positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col5",            DoubleToStr(local.position.data[i][I_PROFIT], 2),                                              positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
      }
   }


   // LFX-Positionsdaten
   for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
      if (lfxOrders.iVolatile[i][I_ISOPEN] != 0) {
         line++;
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[los.Type        (lfxOrders, i)+1],                  positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(los.Units       (lfxOrders, i), ".+") +" units",    positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                          positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(los.OpenPriceLfx(lfxOrders, i), SubPipPriceFormat), positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                      positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
         ObjectSetText(label.position +".line"+ line +"_col5", DoubleToStr(lfxOrders.dVolatile[i][I_VPROFIT], 2),              positions.fontSize, positions.fontName, positions.fontColors[TYPE_DEFAULT]);
      }
   }
   return(!catch("UpdatePositions(2)"));
}


/**
 * Aktualisiert die Anzeige des aktuellen Stopout-Levels.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStopoutLevel() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions())
      return(false);

   if (!totalPosition) {                                                               // keine Position im Markt: vorhandene Marker löschen
      ObjectDelete(label.stopoutLevel);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                 // bei offenem Properties-Dialog oder Object::onDrag()
         return(!catch("UpdateStopoutLevel(1)", error));
      return(true);
   }


   // (1) Stopout-Preis berechnen
   double equity     = AccountEquity();
   double usedMargin = AccountMargin();
   int    soMode     = AccountStopoutMode();
   double soEquity   = AccountStopoutLevel(); if (soMode != ASM_ABSOLUTE) soEquity /= (100/usedMargin);
   double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE) * MathAbs(totalPosition);  // TickValue der aktuellen Position
      if (!tickSize || !tickValue)
         return(!SetLastError(ERR_UNKNOWN_SYMBOL));                                    // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
   double soDistance = (equity - soEquity)/tickValue * tickSize;
   double soPrice;
   if (totalPosition > 0) soPrice = NormalizeDouble(Bid - soDistance, Digits);
   else                   soPrice = NormalizeDouble(Ask + soDistance, Digits);


   // (2) Stopout-Preis anzeigen
   if (ObjectFind(label.stopoutLevel) == -1) {
      ObjectCreate (label.stopoutLevel, OBJ_HLINE, 0, 0, 0);
      ObjectSet    (label.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (label.stopoutLevel, OBJPROP_COLOR, OrangeRed);
      ObjectSet    (label.stopoutLevel, OBJPROP_BACK , true);
         if (soMode == ASM_PERCENT) string description = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%");
         else                              description = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency());
      ObjectSetText(label.stopoutLevel, description);
      ObjectRegister(label.stopoutLevel);
   }
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);


   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                    // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateStopoutLevel(2)", error));
   return(true);
}


/**
 * Aktualisiert die OHLC-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateOHLC() {
   // TODO: noch nicht zufriedenstellend implementiert
   return(true);


   // (1) Zeit des letzten Ticks holen
   datetime lastTickTime = MarketInfo(Symbol(), MODE_TIME);
   if (!lastTickTime) {                                                          // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      if (!SetLastError(GetLastError()))
         SetLastError(ERR_UNKNOWN_SYMBOL);
      return(false);
   }


   // (2) Beginn und Ende der aktuellen Session ermitteln
   datetime sessionStart = GetSessionStartTime.srv(lastTickTime);                // throws ERR_MARKET_CLOSED
   if (sessionStart == NaT) {
      if (SetLastError(stdlib.GetLastError()) != ERR_MARKET_CLOSED)              // am Wochenende die letzte Session verwenden
         return(false);
      sessionStart = GetPrevSessionStartTime.srv(lastTickTime);
   }
   datetime sessionEnd = sessionStart + 1*DAY;


   // (3) Baroffsets von Sessionbeginn und -ende ermitteln
   int openBar = iBarShiftNext(NULL, NULL, sessionStart);
      if (openBar == EMPTY_VALUE) return(!SetLastError(stdlib.GetLastError()));  // Fehler
      if (openBar ==          -1) return(true);                                  // sessionStart ist zu jung für den Chart
   int closeBar = iBarShiftPrevious(NULL, NULL, sessionEnd);
      if (closeBar == EMPTY_VALUE) return(!SetLastError(stdlib.GetLastError())); // Fehler
      if (closeBar ==          -1) return(true);                                 // sessionEnd ist zu alt für den Chart
   if (openBar < closeBar)
      return(!catch("UpdateOHLC(1)   illegal open/close bar offsets for session from="+ DateToStr(sessionStart, "w D.M.Y H:I") +" (bar="+ openBar +")  to="+ DateToStr(sessionEnd, "w D.M.Y H:I") +" (bar="+ closeBar +")", ERR_RUNTIME_ERROR));


   // (4) Baroffsets von Session-High und -Low ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);


   // (5) Anzeige aktualisieren
   string strOHLC = "O="+ NumberToStr(Open[openBar], PriceFormat) +"   H="+ NumberToStr(High[highBar], PriceFormat) +"   L="+ NumberToStr(Low[lowBar], PriceFormat);
   ObjectSetText(label.ohlc, strOHLC, 8, "", Black);


   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateOHLC(2)", error));
   return(true);
}


/**
 * Aktualisiert die Zeitanzeige (nur im Tester bei VisualMode = On).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateTime() {
   if (!IsVisualMode())
      return(true);

   static datetime lastTime;

   datetime now = TimeCurrent();
   if (now == lastTime)
      return(true);

   string date = TimeToStr(now, TIME_DATE),
          yyyy = StringSubstr(date, 0, 4),
          mm   = StringSubstr(date, 5, 2),
          dd   = StringSubstr(date, 8, 2),
          time = TimeToStr(now, TIME_MINUTES|TIME_SECONDS);

   ObjectSetText(label.time, StringConcatenate(dd, ".", mm, ".", yyyy, " ", time), 9, "Tahoma", SlateGray);

   lastTime = now;

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateTime()", error));
   return(true);
}


/**
 * Ermittelt die momentane Marktpositionierung im aktuellen Instrument.
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions() {
   if (positionsAnalyzed)
      return(true);

   longPosition  = 0;
   shortPosition = 0;
   totalPosition = 0;

   int orders = OrdersTotal();
   int sortKeys[][2];                                                // Sortierschlüssel der offenen Positionen: {OpenTime, Ticket}
   ArrayResize(sortKeys, orders);

   int pos, lfxMagics []={0}; ArrayResize(lfxMagics , 1);            // Die Arrays für die P/L-Daten detektierter LFX-Positionen werden mit Größe 1 initialisiert.
   double   lfxProfits[]={0}; ArrayResize(lfxProfits, 1);            // So sparen wir den ständigen Test auf einen ungültigen Index bei Arraygröße 0.


   // (1) Gesamtposition ermitteln
   for (int n, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
      if (OrderType() > OP_SELL) continue;
      if (LFX.IsMyOrder()) {                                         // dabei P/L gefundener LFX-Positionen aufaddieren
         if (OrderMagicNumber() != lfxMagics[pos]) {
            pos = SearchMagicNumber(lfxMagics, OrderMagicNumber());
            if (pos == -1)
               pos = ArrayResize(lfxProfits, ArrayPushInt(lfxMagics, OrderMagicNumber()))-1;
         }
         lfxProfits[pos] += OrderCommission() + OrderSwap() + OrderProfit();
      }
      if (OrderSymbol() != Symbol()) continue;

      if (OrderType() == OP_BUY) longPosition  += OrderLots();       // Gesamtposition aufaddieren
      else                       shortPosition += OrderLots();

      sortKeys[n][0] = OrderOpenTime();                              // Sortierschlüssel der Tickets auslesen
      sortKeys[n][1] = OrderTicket();
      n++;
   }
   if (n < orders) {
      ArrayResize(sortKeys, n);
      orders = n;
   }
   totalPosition   = NormalizeDouble(longPosition - shortPosition, 2);
   isLocalPosition = (longPosition || shortPosition);


   // (2) P/L gefundener LFX-Positionen ans LFX-Terminal schicken, wenn sich dieser Wert seit der letzten Nachricht geändert hat.
   double lastLfxProfit;
   string lfxMessages[]; ArrayResize(lfxMessages, 0); ArrayResize(lfxMessages, ArraySize(hQC.TradeToLfxSenders));    // 2 x ArrayResize() = ArrayInitialize(string array)
   string globalVarLfxProfit;
   int    error;

   for (i=ArraySize(lfxMagics)-1; i > 0; i--) {                      // Index 0 ist unbenutzt
      // (2.1) prüfen, ob sich der aktuelle vom letzten verschickten Wert unterscheidet
      globalVarLfxProfit = StringConcatenate("LFX.#", lfxMagics[i], ".profit");
      lastLfxProfit      = GlobalVariableGet(globalVarLfxProfit);
      if (!lastLfxProfit) {                                          // 0 oder Fehler
         error = GetLastError();
         if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
            return(!catch("AnalyzePositions(1)->GlobalVariableGet()", error));
      }

      // TODO: Prüfung auf Wertänderung nur innerhalb der Woche, nicht am Wochenende

      if (EQ(lfxProfits[i], lastLfxProfit)) {                        // Wert hat sich nicht geändert
         lfxMagics[i] = NULL;                                        // MagicNumber zurücksetzen, um in (2.4) Marker für Speichern in globaler Variable zu haben
         continue;
      }

      // (2.2) geänderten Wert zu Messages des entsprechenden Channels hinzufügen (Messages eines Channels werden gemeinsam, nicht einzeln verschickt)
      int cid = LFX.CurrencyId(lfxMagics[i]);
      if (!StringLen(lfxMessages[cid])) lfxMessages[cid] = StringConcatenate(                       "LFX:", lfxMagics[i], ":profit=", DoubleToStr(lfxProfits[i], 2));
      else                              lfxMessages[cid] = StringConcatenate(lfxMessages[cid], TAB, "LFX:", lfxMagics[i], ":profit=", DoubleToStr(lfxProfits[i], 2));
   }

   // (2.3) angesammelte Messages verschicken: Messages je Channel werden gemeinsam, nicht einzeln verschickt, um beim Empfänger unnötige Ticks zu vermeiden
   for (i=ArraySize(lfxMessages)-1; i > 0; i--) {                    // Index 0 ist unbenutzt
      if (StringLen(lfxMessages[i]) > 0) {
         if (!hQC.TradeToLfxSenders[i]) /*&&*/ if (!QC.StartTradeToLfxSender(i))
            return(false);
         if (!QC_SendMessage(hQC.TradeToLfxSenders[i], lfxMessages[i], QC_FLAG_SEND_MSG_IF_RECEIVER))
            return(!catch("AnalyzePositions(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      }
   }

   // (2.4) verschickte Werte jeweils in globaler Variable speichern
   for (i=ArraySize(lfxMagics)-1; i > 0; i--) {                      // Index 0 ist unbenutzt
      // Marker aus (2.1) verwenden: MagicNumbers unveränderter Werte wurden zurückgesetzt
      if (lfxMagics[i] != 0) {
         globalVarLfxProfit = StringConcatenate("LFX.#", lfxMagics[i], ".profit");
         if (!GlobalVariableSet(globalVarLfxProfit, lfxProfits[i])) {
            error = GetLastError();
            return(!catch("AnalyzePositions(3)->GlobalVariableSet(name=\""+ globalVarLfxProfit +"\", value="+ lfxProfits[i] +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }


   // (3) Positionsdetails analysieren und in *.position.types[] und *.position.data[] speichern
   if (ArrayRange(local.position.types, 0) > 0) {
      ArrayResize(local.position.types, 0);                          // lokale Positionsdaten werden bei jedem Tick zurückgesetzt und neu eingelesen
      ArrayResize(local.position.data,  0);
   }

   if (isLocalPosition) {
      // (3.1) offene lokale Position, individuelle Konfiguration einlesen (Remote-Positionen werden ignoriert)
      if (ArrayRange(local.position.conf, 0)==0) /*&&*/ if (!ReadLocalPositionConfig()) {
         positionsAnalyzed = !last_error;                            // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
         return(positionsAnalyzed);                                  // in diesem Fall nächster Versuch beim nächsten Tick.
      }

      // (3.2) offene Tickets sortieren und einlesen
      if (orders > 1) /*&&*/ if (!SortTickets(sortKeys))
         return(false);

      int    tickets    [], customTickets    []; ArrayResize(tickets    , orders);
      int    types      [], customTypes      []; ArrayResize(types      , orders);
      double lotSizes   [], customLotSizes   []; ArrayResize(lotSizes   , orders);
      double openPrices [], customOpenPrices []; ArrayResize(openPrices , orders);
      double commissions[], customCommissions[]; ArrayResize(commissions, orders);
      double swaps      [], customSwaps      []; ArrayResize(swaps      , orders);
      double profits    [], customProfits    []; ArrayResize(profits    , orders);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][1], "AnalyzePositions(4)"))
            return(false);
         tickets    [i] = OrderTicket();
         types      [i] = OrderType();
         lotSizes   [i] = OrderLots();
         openPrices [i] = OrderOpenPrice();
         commissions[i] = OrderCommission();
         swaps      [i] = OrderSwap();
         profits    [i] = OrderProfit();
      }
      double lotSize, customLongPosition, customShortPosition, customTotalPosition, local.longPosition=longPosition, local.shortPosition=shortPosition, local.totalPosition=totalPosition;
      int    ticket;
      bool   isVirtual;


      // (3.3) individuell konfigurierte Position extrahieren
      int confSize = ArrayRange(local.position.conf, 0);

      for (i=0; i < confSize; i++) {
         lotSize = local.position.conf[i][0];
         ticket  = local.position.conf[i][1];

         if (!i || !ticket) {
            // (3.4) individuell konfigurierte Position speichern
            if (ArraySize(customTickets) > 0)
               if (!StorePosition.Consolidate(isVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
                  return(false);
            isVirtual           = false;
            customLongPosition  = 0;
            customShortPosition = 0;
            customTotalPosition = 0;
            ArrayResize(customTickets    , 0);
            ArrayResize(customTypes      , 0);
            ArrayResize(customLotSizes   , 0);
            ArrayResize(customOpenPrices , 0);
            ArrayResize(customCommissions, 0);
            ArrayResize(customSwaps      , 0);
            ArrayResize(customProfits    , 0);
            if (!ticket)
               continue;
         }
         if (!ExtractPosition(lotSize, ticket, local.longPosition, local.shortPosition, local.totalPosition,       tickets,       types,       lotSizes,       openPrices,       commissions,       swaps,       profits,
                              isVirtual,       customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
            return(false);
      }

      // (3.5) verbleibende Position speichern
      if (!StorePosition.Separate(local.longPosition, local.shortPosition, local.totalPosition, tickets, types, lotSizes, openPrices, commissions, swaps, profits))
         return(false);
   }

   positionsAnalyzed = true;
   return(!catch("AnalyzePositions(5)"));
}


/**
 * Durchsucht das übergebene Integer-Array nach der angegebenen MagicNumber. Schnellerer Ersatz für SearchIntArray(int haystack[], int needle),
 * da kein Library-Aufruf.
 *
 * @param  int array[] - zu durchsuchendes Array
 * @param  int number  - zu suchende MagicNumber
 *
 * @return int - Index der MagicNumber oder -1 (EMPTY), wenn der Wert nicht im Array enthalten ist
 */
int SearchMagicNumber(int array[], int number) {
   int size = ArraySize(array);
   for (int i=0; i < size; i++) {
      if (array[i] == number)
         return(i);
   }
   return(EMPTY);
}


/**
 * Liest die individuell konfigurierten lokalen Positionsdaten neu ein.
 *
 * @return bool - Erfolgsstatus
 *
 *
 *  Notation:
 *  ---------
 *   0.1#123456 - O.1 Lot eines Tickets
 *      #123456 - komplettes Ticket oder verbleibender Rest eines Tickets
 *   0.2#L      - imaginäre Long-Position, muß an erster Stelle notiert sein (*)
 *   0.3#S      - imaginäre Short-Position, muß an erster Stelle notiert sein (*)
 *      L       - alle übrigen Long-Positionen
 *      S       - alle übrigen Short-Positionen
 *
 *  (*) Reale Positionen, die mit einer imaginären Position kombiniert werden, werden nicht von der verbleibenden Gesamtposition abgezogen.
 *
 *
 *  Beispiel:
 *  ---------
 *   [BreakevenCalculation]
 *   GBPAUD.1 = #111111, 0.1#222222      ; komplettes Ticket #111111 und 0.1 Lot von Ticket #222222
 *   GBPAUD.2 = 0.3#L, #222222           ; imaginäre 0.3 Lot Long-Position und Rest von #222222 (*)
 *   GBPAUD.3 = L,S                      ; alle verbleibenden Positionen (inkl. des Restes von #222222)
 */
bool ReadLocalPositionConfig() {
   if (ArrayRange(local.position.conf, 0) > 0)
      ArrayResize(local.position.conf, 0);

   string keys[], values[], value, details[], strLotSize, strTicket, sNull, section="BreakevenCalculation", stdSymbol=StdSymbol();
   double lotSize, minLotSize=MarketInfo(Symbol(), MODE_MINLOT), lotStep=MarketInfo(Symbol(), MODE_LOTSTEP);
   int    valuesSize, detailsSize, confSize, m, ticket;
   if (!minLotSize) return(false);                                   // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (!lotStep   ) return(false);

   string localConfigPath = GetLocalConfigPath();
   if (localConfigPath=="") return(!SetLastError(stdlib.GetLastError()));

   int keysSize = GetIniKeys(localConfigPath, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StringIStartsWith(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {
            value      = GetLocalConfigString(section, keys[i], "");
            valuesSize = Explode(value, ",", values, NULL);
            m = 0;
            for (int n=0; n < valuesSize; n++) {
               detailsSize = Explode(values[n], "#", details, NULL);
               if (detailsSize != 2) {
                  if (detailsSize == 1) {
                     if (!StringLen(StringTrim(values[n])))          // zwei aufeinanderfolgende Separatoren => Leervalue überspringen
                        continue;
                     ArrayResize(details, 2);
                     details[0] = "";
                     details[1] = values[n];
                  }
                  else return(!catch("ReadLocalPositionConfig(3)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }
               details[0] =               StringTrim(details[0]);  strLotSize = details[0];
               details[1] = StringToUpper(StringTrim(details[1])); strTicket  = details[1];

               // Lotsize validieren
               lotSize = 0;
               if (StringLen(strLotSize) > 0) {
                  if (!StringIsNumeric(strLotSize))      return(!catch("ReadLocalPositionConfig(4)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" (non-numeric lot size) in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  lotSize = StrToDouble(strLotSize);
                  if (LT(lotSize, minLotSize))           return(!catch("ReadLocalPositionConfig(5)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" (lot size smaller than MIN_LOTSIZE) in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(lotSize, lotStep) != 0) return(!catch("ReadLocalPositionConfig(6)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" (lot size not a multiple of LOTSTEP) in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               // Ticket validieren
               if (StringIsDigit(strTicket)) ticket = StrToInteger(strTicket);
               else if (strTicket == "L")    ticket = TYPE_LONG;
               else if (strTicket == "S")    ticket = TYPE_SHORT;
               else return(!catch("ReadLocalPositionConfig(7)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" (non-digits in ticket) in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Virtuelle Positionen müssen an erster Stelle notiert sein
               if (m && lotSize && ticket<=TYPE_SHORT) return(!catch("ReadLocalPositionConfig(8)   illegal configuration, virtual positions must be noted first in \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ localConfigPath +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               confSize = ArrayRange(local.position.conf, 0);
               ArrayResize(local.position.conf, confSize+1);
               local.position.conf[confSize][0] = lotSize;
               local.position.conf[confSize][1] = ticket;
               m++;
            }
            if (m > 0) {
               confSize = ArrayRange(local.position.conf, 0);
               ArrayResize(local.position.conf, confSize+1);
               local.position.conf[confSize][0] = NULL;
               local.position.conf[confSize][1] = NULL;
            }
         }
      }
   }
   confSize = ArrayRange(local.position.conf, 0);
   if (!confSize) {
      ArrayResize(local.position.conf, 1);
      local.position.conf[confSize][0] = NULL;
      local.position.conf[confSize][1] = NULL;
   }
   return(true);
}


/**
 * Extrahiert eine Teilposition aus den übergebenen Positionen.
 *
 * @param  double lotSize    - zu extrahierende LotSize
 * @param  int    ticket     - zu extrahierendes Ticket
 *
 * @param  mixed  vars       - Variablen, aus denen die Position extrahiert wird
 * @param  bool   isVirtual  - ob die extrahierte Position virtuell ist
 * @param  mixed  customVars - Variablen, denen die extrahierte Position hinzugefügt wird
 *
 * @return bool - Erfolgsstatus
 */
bool ExtractPosition(double lotSize, int ticket, double       &longPosition, double       &shortPosition, double       &totalPosition, int       &tickets[], int       &types[], double       &lotSizes[], double       &openPrices[], double       &commissions[], double       &swaps[], double       &profits[],
                                bool &isVirtual, double &customLongPosition, double &customShortPosition, double &customTotalPosition, int &customTickets[], int &customTypes[], double &customLotSizes[], double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[]) {
   int sizeTickets = ArraySize(tickets);

   if (ticket == TYPE_LONG) {
      if (!lotSize) {
         // alle Long-Positionen
         if (longPosition > 0) {
            for (int i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_BUY) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLotSizes,    lotSizes   [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isVirtual) {
                     longPosition  = NormalizeDouble(longPosition - lotSizes[i],   2);
                     totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customLongPosition  = NormalizeDouble(customLongPosition + lotSizes[i],         2);
                  customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
               }
            }
         }
      }
      else {
         // virtuelle Long-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         ArrayPushInt   (customTickets,     TYPE_LONG                                     );
         ArrayPushInt   (customTypes,       OP_BUY                                        );
         ArrayPushDouble(customLotSizes,    lotSize                                       );
         ArrayPushDouble(customOpenPrices,  Ask                                           );
         ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotSize, 2));
         ArrayPushDouble(customSwaps,       0                                             );
         ArrayPushDouble(customProfits,     (Bid-Ask)/Pips * PipValue(lotSize, true)      ); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         customLongPosition  = NormalizeDouble(customLongPosition + lotSize,             2);
         customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
         isVirtual           = true;
      }
   }
   else if (ticket == TYPE_SHORT) {
      if (!lotSize) {
         // alle Short-Positionen
         if (shortPosition > 0) {
            for (i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_SELL) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLotSizes,    lotSizes   [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isVirtual) {
                     shortPosition = NormalizeDouble(shortPosition - lotSizes[i],   2);
                     totalPosition = NormalizeDouble(longPosition  - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customShortPosition = NormalizeDouble(customShortPosition + lotSizes[i],         2);
                  customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 2);
               }
            }
         }
      }
      else {
         // virtuelle Short-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         ArrayPushInt   (customTickets,     TYPE_SHORT                                    );
         ArrayPushInt   (customTypes,       OP_SELL                                       );
         ArrayPushDouble(customLotSizes,    lotSize                                       );
         ArrayPushDouble(customOpenPrices,  Bid                                           );
         ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotSize, 2));
         ArrayPushDouble(customSwaps,       0                                             );
         ArrayPushDouble(customProfits,     (Bid-Ask)/Pips * PipValue(lotSize, true)      ); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         customShortPosition = NormalizeDouble(customShortPosition + lotSize,            2);
         customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
         isVirtual           = true;
      }
   }
   else {
      if (!lotSize) {
         // komplettes Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
               ArrayPushInt   (customTickets,     tickets    [i]);
               ArrayPushInt   (customTypes,       types      [i]);
               ArrayPushDouble(customLotSizes,    lotSizes   [i]);
               ArrayPushDouble(customOpenPrices,  openPrices [i]);
               ArrayPushDouble(customCommissions, commissions[i]);
               ArrayPushDouble(customSwaps,       swaps      [i]);
               ArrayPushDouble(customProfits,     profits    [i]);
               if (!isVirtual) {
                  if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lotSizes[i],   2);
                  else                    shortPosition       = NormalizeDouble(shortPosition - lotSizes[i],   2);
                                          totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                                          tickets[i]          = NULL;
               }
               if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lotSizes[i], 2);
               else                       customShortPosition = NormalizeDouble(customShortPosition + lotSizes[i], 2);
                                          customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
               break;
            }
         }
      }
      else {
         // partielles Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               if (GT(lotSize, lotSizes[i])) return(!catch("ExtractPosition(1)   illegal partial lotsize "+ NumberToStr(lotSize, ".+") +" for ticket #"+ tickets[i] +" ("+ NumberToStr(lotSizes[i], ".+") +" lot)", ERR_RUNTIME_ERROR));
               if (EQ(lotSize, lotSizes[i])) {
                  if (!ExtractPosition(0, ticket, longPosition,       shortPosition,       totalPosition,       tickets,       types,       lotSizes,       openPrices,       commissions,       swaps,       profits,
                                 isVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
                     return(false);
               }
               else {
                  // Daten anteilig nach custom.* übernehmen und Ticket ggf. reduzieren
                  double factor = lotSize/lotSizes[i];
                  ArrayPushInt   (customTickets,     tickets    [i]         );
                  ArrayPushInt   (customTypes,       types      [i]         );
                  ArrayPushDouble(customLotSizes,    lotSize                ); if (!isVirtual) lotSizes   [i]  = NormalizeDouble(lotSizes[i]-lotSize, 2); // reduzieren
                  ArrayPushDouble(customOpenPrices,  openPrices [i]         );
                  ArrayPushDouble(customSwaps,       swaps      [i]         ); if (!isVirtual) swaps      [i]  = NULL;                                    // komplett
                  ArrayPushDouble(customCommissions, commissions[i] * factor); if (!isVirtual) commissions[i] *= (1-factor);                              // anteilig
                  ArrayPushDouble(customProfits,     profits    [i] * factor); if (!isVirtual) profits    [i] *= (1-factor);                              // anteilig
                  if (!isVirtual) {
                     if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lotSize, 2);
                     else                    shortPosition       = NormalizeDouble(shortPosition - lotSize, 2);
                                             totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                  }
                  if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lotSize, 2);
                  else                       customShortPosition = NormalizeDouble(customShortPosition + lotSize, 2);
                                             customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 2);
               }
               break;
            }
         }
      }
   }
   return(!catch("ExtractPosition(2)"));
}


/**
 * Speichert die übergebene Teilposition zusammengefaßt in den globalen Variablen.
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition.Consolidate(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int &types[], double &lotSizes[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   isVirtual = isVirtual!=0;

   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, hedgedProfit, pipDistance, pipValue;
   int size, ticketsSize=ArraySize(tickets);

   // Die Gesamtposition besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance berechnen
   // - direktionaler Anteil:       Breakeven unter Berücksichtigung des Profits eines gehedgten Anteils berechnen


   // (1) BE-Distance und Profit einer eventuellen Hedgeposition ermitteln
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;
      openPrice      = 0;
      closePrice     = 0;
      swap           = 0;
      commission     = 0;
      pipDistance    = 0;
      hedgedProfit   = 0;

      for (int i=0; i < ticketsSize; i++) {
         if (!tickets[i]) continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
                                                               profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               closePrice    += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               //commission  += commissions[i];                                                          // Commission wird nur für Long-Leg übernommen
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor      = remainingShort/lotSizes[i];
               closePrice += remainingShort * openPrices[i];
               swap       +=                  swaps     [i]; swaps      [i]  = 0;
                                                             commissions[i] -= factor * commissions[i];  // Commission wird nur für Long-Leg übernommen
                                                             profits    [i] -= factor * profits    [i];
                                                             lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(!catch("StorePosition.Consolidate(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StorePosition.Consolidate(2)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLotSize, true);                      // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = (closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue;
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Position speichern und Rückkehr
      if (!totalPosition) {
         size = ArrayRange(local.position.types, 0);
         ArrayResize(local.position.types, size+1);
         ArrayResize(local.position.data,  size+1);

         local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
         local.position.types[size][1]               = TYPE_HEDGE;
         local.position.data [size][I_DIRECTLOTSIZE] = 0;
         local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         local.position.data [size][I_BREAKEVEN    ] = pipDistance;
         local.position.data [size][I_PROFIT       ] = hedgedProfit;
         return(!catch("StorePosition.Consolidate(3)"));
      }
   }


   // (2) Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils mit einschließen
   // (2.1) eventuelle Longposition ermitteln
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor        * profits    [i]; profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition.Consolidate(4)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
      local.position.types[size][1]               = TYPE_LONG;
      local.position.data [size][I_DIRECTLOTSIZE] = totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(totalPosition, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (hedgedProfit + commission + swap)/pipValue*Pips;
      local.position.data [size][I_PROFIT       ] = hedgedProfit + commission + swap + profit;
   }


   // (2.2) eventuelle Shortposition ermitteln
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lotSizes[i];
               openPrice     += remainingShort * openPrices [i];
               swap          +=                  swaps      [i]; swaps      [i]  = 0;
               commission    += factor         * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor         * profits    [i]; profits    [i] -= factor * profits    [i];
                                                                 lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition.Consolidate(5)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
      local.position.types[size][1]               = TYPE_SHORT;
      local.position.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(-totalPosition, true);                  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (hedgedProfit + commission + swap)/pipValue*Pips - openPrice/totalPosition;
      local.position.data [size][I_PROFIT       ] =  hedgedProfit + commission + swap + profit;
   }

   return(!catch("StorePosition.Consolidate(6)"));
}


/**
 * Speichert die übergebenen Teilpositionen getrennt nach Long/Short/Hedge in den globalen Variablen local.position.types[] und local.position.data[].
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition.Separate(double longPosition, double shortPosition, double totalPosition, int &tickets[], int &types[], double &lotSizes[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, pipValue;
   int ticketsSize = ArraySize(tickets);

   // (1) eventuelle Longposition selektieren
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (int i=ticketsSize-1; i >= 0; i--) {                       // jüngstes Ticket zuerst
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor        * profits    [i]; profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition.Separate(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of effective long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      int size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_LONG;
      local.position.data [size][I_DIRECTLOTSIZE] = totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(totalPosition, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (commission+swap)/pipValue*Pips;
      local.position.data [size][I_PROFIT       ] = commission + swap + profit;
   }


   // (2) eventuelle Shortposition selektieren
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                           // jüngstes Ticket zuerst
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lotSizes[i];
               openPrice     += remainingShort * openPrices [i];
               swap          +=                  swaps      [i]; swaps      [i]  = 0;
               commission    += factor         * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor         * profits    [i]; profits    [i] -= factor * profits    [i];
                                                                 lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition.Separate(2)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of effective short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_SHORT;
      local.position.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(-totalPosition, true);                  // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (commission+swap)/pipValue*Pips - openPrice/totalPosition;
      local.position.data [size][I_PROFIT       ] = commission + swap + profit;
   }


   // (3) verbleibende Hedgeposition selektieren
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;
      openPrice      = 0;
      closePrice     = 0;
      swap           = 0;
      commission     = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                           // jüngstes Ticket zuerst
         if (!tickets[i]) continue;
         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong < lotSizes[i]) return(!catch("StorePosition.Separate(3)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            openPrice    += lotSizes   [i] * openPrices[i];
            swap         += swaps      [i];
            commission   += commissions[i];
            remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            tickets[i]    = NULL;
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort < lotSizes[i]) return(!catch("StorePosition.Separate(4)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            closePrice    += lotSizes   [i] * openPrices[i];
            swap          += swaps      [i];
            //commission  += commissions[i];                         // Commissions nur für eine Seite übernehmen
            remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            tickets[i]     = NULL;
         }
      }

      // Position speichern
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_HEDGE;
      local.position.data [size][I_DIRECTLOTSIZE] = 0;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(hedgedLotSize, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue;
      local.position.data [size][I_PROFIT       ] = local.position.data[size][I_BREAKEVEN] * pipValue;
   }

   return(!catch("StorePosition.Separate(5)"));
}


/**
 * Handler für beim LFX-Terminal eingehende Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleLfxTerminalMessages() {
   if (!IsChart)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeToLfxReceiver) /*&&*/ if (!QC.StartTradeToLfxReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeToLfxChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.HandleLfxTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.HandleLfxTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")   channel doesn't exist",              ERR_WIN32_ERROR));
                                            return(!catch("QC.HandleLfxTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")   unexpected return value = "+ result, ERR_WIN32_ERROR));
   }
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);

   // (3) neue Messages abholen
   result = QC_GetMessages3(hQC.TradeToLfxReceiver, qc.TradeToLfxBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleLfxTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error",     ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleLfxTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleLfxTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten: Da hier sehr viele Messages eingehen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   string msgs = qc.TradeToLfxBuffer[0];
   int from=0, to=StringFind(msgs, TAB, from);
   while (to != -1) {                                                            // mind. ein TAB gefunden
      if (to != from)
         if (!ProcessLfxTerminalMessage(StringSubstr(msgs, from, to-from)))
            return(false);
      from = to+1;
      to = StringFind(msgs, TAB, from);
   }
   if (from < StringLen(msgs))
      if (!ProcessLfxTerminalMessage(StringSubstr(msgs, from)))
         return(false);

   return(true);
}


/**
 * Verarbeitet beim LFX-Terminal eingehende Messages.
 *
 * @param  string message - QuickChannel-Message, siehe Formatbeschreibung
 *
 * @return bool - Erfolgsstatus: Ob die Message erfolgreich verarbeitet wurde. Ein falsches Messageformat oder keine zur Message passende Order sind kein Fehler,
 *                               ein Programmabbruch von außen durch Schicken einer falschen Message ist nicht möglich. Für unerkannte Messages wird eine
 *                               Warnung ausgegeben.
 *
 *  Messageformat: "LFX:{iTicket]:pending={1|0}"   - die angegebene Pending-Order wurde platziert (immer erfolgreich, da im Fehlerfall keine Message generiert wird)
 *                 "LFX:{iTicket]:open={1|0}"      - die angegebene Pending-Order wurde ausgeführt/konnte nicht ausgeführt werden
 *                 "LFX:{iTicket]:close={0|1}"     - die angegebene Position wurde geschlossen/konnte nicht geschlossen werden
 *                 "LFX:{iTicket]:profit={dValue}" - der P/L-Wert der angegebenen Position hat sich geändert
 */
bool ProcessLfxTerminalMessage(string message) {
   // Da hier sehr viele Messages eingehen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   // LFX-Prefix
   if (StringSubstr(message, 0, 4) != "LFX:")                                        return(_true(warn("ProcessLfxTerminalMessage(1)   unknown message format \""+ message +"\"")));
   // LFX-Ticket
   int from=4, to=StringFind(message, ":", from);                   if (to <= from)  return(_true(warn("ProcessLfxTerminalMessage(2)   unknown message \""+ message +"\" (illegal order ticket)")));
   int ticket = StrToInteger(StringSubstr(message, from, to-from)); if (ticket <= 0) return(_true(warn("ProcessLfxTerminalMessage(3)   unknown message \""+ message +"\" (illegal order ticket)")));
   // LFX-Parameter
   double profit;
   bool   success;
   from = to+1;

   // :profit={dValue}
   if (StringSubstr(message, from, 7) == "profit=") {                         // die häufigste Message wird zuerst geprüft
      int size = ArrayRange(lfxOrders, 0);
      for (int i=0; i < size; i++) {
         if (lfxOrders.iVolatile[i][I_TICKET] == ticket) {                    // geladene LFX-Orders durchsuchen und P/L aktualisieren
            if (lfxOrders.iVolatile[i][I_ISOPEN] && !lfxOrders.iVolatile[i][I_ISLOCKED])
               lfxOrders.dVolatile[i][I_VPROFIT] = NormalizeDouble(StrToDouble(StringSubstr(message, from+7)), 2);
            break;
         }
      }
      return(true);
   }

   // :pending={1|0}
   if (StringSubstr(message, from, 8) == "pending=") {
      success = (StrToInteger(StringSubstr(message, from+8)) != 0);
      if (success) { if (__LOG) log("ProcessLfxTerminalMessage(4)   #"+ ticket +" pending order "+ ifString(success, "confirmation", "error"                           )); }
      else         {           warn("ProcessLfxTerminalMessage(5)   #"+ ticket +" pending order "+ ifString(success, "confirmation", "error (what use case is this???)")); }
      return(RestoreLfxStatusFromFiles());                                    // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :open={1|0}
   if (StringSubstr(message, from, 5) == "open=") {
      success = (StrToInteger(StringSubstr(message, from+5)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(6)   #"+ ticket +" open position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFiles());                                    // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :close={1|0}
   if (StringSubstr(message, from, 6) == "close=") {
      success = (StrToInteger(StringSubstr(message, from+6)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(7)   #"+ ticket +" close position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFiles());                                    // LFX-Status neu einlesen (auch bei Fehler)
   }

   // ???
   return(_true(warn("ProcessLfxTerminalMessage(8)   unknown message \""+ message +"\"")));
}


/**
 * Liest den aktuellen LFX-Status komplett neu ein.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreLfxStatusFromFiles() {
   // Sind wir nicht in einem init-Cycle, werden die vorhandenen volatilen Daten vorm Überschreiben gespeichert.
   if (ArrayRange(lfxOrders.iVolatile, 0) > 0) {
      if (!SaveVolatileLfxStatus())
         return(false);
   }
   ArrayResize(lfxOrders.iVolatile, 0);
   ArrayResize(lfxOrders.dVolatile, 0);
   lfxOrders.openPositions = 0;


   // offene Orders einlesen
   int size = LFX.GetOrders(lfxCurrency, OF_OPEN, lfxOrders);
   if (size == -1)
      return(false);
   ArrayResize(lfxOrders.iVolatile, size);
   ArrayResize(lfxOrders.dVolatile, size);


   // Zähler der offenen Positionen und volatile P/L-Daten aktualisieren
   for (int i=0; i < size; i++) {
      lfxOrders.iVolatile[i][I_TICKET] = los.Ticket(lfxOrders, i);
      lfxOrders.iVolatile[i][I_ISOPEN] = los.IsOpen(lfxOrders, i);
      if (lfxOrders.iVolatile[i][I_ISOPEN] == 0) {
         lfxOrders.dVolatile[i][I_VPROFIT] = 0;
         continue;
      }
      lfxOrders.openPositions++;

      string varName = StringConcatenate("LFX.#", lfxOrders.iVolatile[i][I_TICKET], ".profit");
      double value   = GlobalVariableGet(varName);
      if (!value) {                                                  // 0 oder Fehler
         int error = GetLastError();
         if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
            return(!catch("RestoreLfxStatusFromFiles(1)->GlobalVariableGet(name=\""+ varName +"\")", error));
      }
      lfxOrders.dVolatile[i][I_VPROFIT] = value;
   }
   return(true);
}


/**
 * Restauriert den LFX-Status aus den in der Library zwischengespeicherten Daten.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreLfxStatusFromLib() {
   int size = ChartInfos.CopyLfxStatus(false, lfxOrders, lfxOrders.iVolatile, lfxOrders.dVolatile);
   if (size == -1)
      return(!SetLastError(ERR_RUNTIME_ERROR));

   lfxOrders.openPositions = 0;

   // Zähler der offenen Positionen aktualisieren
   for (int i=0; i < size; i++) {
      if (lfxOrders.iVolatile[i][I_ISOPEN] != 0)
         lfxOrders.openPositions++;
   }
   return(true);
}


/**
 * Speichert die volatilen LFX-P/L-Daten in globalen Variablen.
 *
 * @return bool - Erfolgsstatus
 */
bool SaveVolatileLfxStatus() {
   string varName;
   int size = ArrayRange(lfxOrders.iVolatile, 0);

   for (int i=0; i < size; i++) {
      if (lfxOrders.iVolatile[i][I_ISOPEN] != 0) {
         varName = StringConcatenate("LFX.#", lfxOrders.iVolatile[i][I_TICKET], ".profit");

         if (!GlobalVariableSet(varName, lfxOrders.dVolatile[i][I_VPROFIT])) {
            int error = GetLastError();
            return(!catch("SaveVolatileLfxStatus(1)->GlobalVariableSet(name=\""+ varName +"\", value="+ DoubleToStr(lfxOrders.dVolatile[i][I_VPROFIT], 2) +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }
   return(true);
}


/**
 * Listener + Handler für beim Trade-Terminal eingehende Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleTradeTerminalMessages() {
   if (!IsChart)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeCmdReceiver) /*&&*/ if (!QC.StartTradeCmdReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeCmdChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.HandleTradeTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.HandleTradeTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")   channel doesn't exist",              ERR_WIN32_ERROR));
                                            return(!catch("QC.HandleTradeTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")   unexpected return value = "+ result, ERR_WIN32_ERROR));
   }
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);

   // (3) neue Messages abholen
   result = QC_GetMessages3(hQC.TradeCmdReceiver, qc.TradeCmdBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleTradeTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error",     ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleTradeTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleTradeTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten
   string msgs[];
   int size = Explode(qc.TradeCmdBuffer[0], TAB, msgs, NULL);

   for (int i=0; i < size; i++) {
      if (!StringLen(msgs[i]))
         continue;
      log("QC.HandleTradeTerminalMessages(7)   received \""+ msgs[i] +"\"");
      if (!RunScript("LFX.ExecuteTradeCmd", "command="+ msgs[i]))    // TODO: Scripte dürfen nicht in Schleife gestartet werden
         return(false);
   }
   return(true);
}


/**
 * Sortiert die übergebenen Ticketdaten nach OpenTime_asc, Ticket_asc.
 *
 * @param  int keys[] - Array mit Sortierschlüsseln
 *
 * @return bool - Erfolgsstatus
 */
bool SortTickets(int keys[][/*{OpenTime, Ticket}*/]) {
   int rows = ArrayRange(keys, 0);
   if (rows < 2)
      return(true);                                                  // weniger als 2 Zeilen

   // Zeilen nach OpenTime sortieren
   ArraySort(keys);

   // Zeilen mit derselben OpenTime zusätzlich nach Ticket sortieren
   int open, lastOpen, ticket, n, sameOpens[][2];
   ArrayResize(sameOpens, 1);

   for (int i=0; i < rows; i++) {
      open   = keys[i][0];
      ticket = keys[i][1];

      if (open == lastOpen) {
         n++;
         ArrayResize(sameOpens, n+1);
      }
      else if (n > 0) {
         // in sameOpens[] angesammelte Zeilen nach Ticket sortieren und zurück nach keys[] schreiben
         if (!SortSameOpens(sameOpens, keys))
            return(false);
         ArrayResize(sameOpens, 1);
         n = 0;
      }
      sameOpens[n][0] = ticket;
      sameOpens[n][1] = i;                                           // Originalposition der Zeile in keys[]

      lastOpen = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpens[] angesammelte Zeilen müssen auch verarbeitet werden
      if (!SortSameOpens(sameOpens, keys))
         return(false);
      n = 0;
   }
   return(!catch("SortTickets()"));
}


/**
 * Sortiert die in sameOpens[] übergebenen Daten und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameOpens[] - Array mit Ausgangsdaten
 * @param  int &data[]      - das zu aktualisierende Originalarray
 *
 * @return bool - Erfolgsstatus
 */
bool SortSameOpens(int sameOpens[][/*{Ticket, i}*/], int &data[][/*{OpenTime, Ticket}*/]) {
   int sameOpens.copy[][2]; ArrayResize(sameOpens.copy, 0);
   ArrayCopy(sameOpens.copy, sameOpens);                             // Originalreihenfolge der Indizes in Kopie speichern

   // Zeilen nach Ticket sortieren
   ArraySort(sameOpens);

   // Original-Daten mit den sortierten Werten überschreiben
   int ticket, i, rows=ArrayRange(sameOpens, 0);

   for (int n=0; n < rows; n++) {
      ticket = sameOpens     [n][0];
      i      = sameOpens.copy[n][1];
      data[i][1] = ticket;                                           // Originaldaten mit den sortierten Werten überschreiben
   }
   return(!catch("SortSameOpens()"));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   config: ",                     // 'config' statt 'inputs', da die Laufzeitparameter extern konfiguriert werden

                            "appliedPrice=", PriceTypeToStr(appliedPrice), "; ")
   );
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayPushDouble(double array[], double value);
   string   BoolToStr(bool value);
   string   DateToStr(datetime time, string mask);
   int      DeleteRegisteredObjects(string prefix);
   double   GetCommission();
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   string   GetLocalConfigPath();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   datetime GetPrevSessionStartTime.srv(datetime serverTime);
   datetime GetSessionStartTime.srv(datetime serverTime);
   string   GetSymbolName(string symbol);
   int      GetTerminalBuild();
   int      iBarShiftNext(string symbol, int period, datetime time);
   int      iBarShiftPrevious(string symbol, int period, datetime time);
   bool     IsCurrency(string value);
   bool     IsGlobalConfigKey(string section, string key);
   double   MathModFix(double a, double b);
   int      ObjectRegister(string label);
   string   PriceTypeToStr(int type);
   bool     ReleaseLock(string mutexName);
   int      SearchStringArrayI(string haystack[], string needle);
   bool     StringEndsWith(string object, string postfix);
   bool     StringIEndsWith(string object, string postfix);
   string   StringSubstrFix(string object, int start, int length);
   string   StringToUpper(string value);
   string   UninitializeReasonToStr(int reason);

#import "stdlib2.ex4"
   int      ChartInfos.CopyLfxStatus(bool direction, /*LFX_ORDER*/int orders[][], int iVolatile[][], double dVolatile[][]);
#import
