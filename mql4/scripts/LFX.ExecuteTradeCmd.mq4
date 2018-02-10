/**
 * Script, daß zwischen den Terminals verschickte LfxTradeCommands ausführt. Ein manueller Aufruf ist nicht möglich.
 *
 *
 * TradeCommand-Hierarchie:
 * ------------------------
 *  abstract TradeCommand                            { string trigger; }
 *
 *  OrderOpenCommand         extends TradeCommand    { int type:OP_BUY|OP_SELL|OP_BUYLIMIT|OP_SELLLIMIT|OP_BUYSTOP|OP_SELLSTOP; ... }
 *  OrderCloseCommand        extends TradeCommand    { int ticket; ... }
 *  OrderCloseByCommand      extends TradeCommand    { int ticket1; int ticket2; ... }
 *  OrderModifyCommand       extends TradeCommand    { int ticket; ... }
 *  OrderDeleteCommand       extends TradeCommand    { int ticket; ... }
 *
 *  abstract LfxTradeCommand extends TradeCommand    {}
 *
 *  LfxOrderCreateCommand    extends LfxTradeCommand { int type:OP_BUY|OP_SELL|OP_BUYLIMIT|OP_SELLLIMIT|OP_BUYSTOP|OP_SELLSTOP; ... }
 *  LfxOrderOpenCommand      extends LfxTradeCommand { int ticket; ... }
 *  LfxOrderCloseCommand     extends LfxTradeCommand { int ticket; ... }
 *  LfxOrderCloseByCommand   extends LfxTradeCommand { int ticket1; int ticket2; ... }
 *  LfxOrderHedgeCommand     extends LfxTradeCommand { int ticket; ... }
 *  LfxOrderModifyCommand    extends LfxTradeCommand { int ticket; ... }
 *  LfxOrderDeleteCommand    extends LfxTradeCommand { int ticket; ... }
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <scriptrunner.mqh>
#include <structs/xtrade/LFXOrder.mqh>
#include <structs/xtrade/OrderExecution.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) TradeAccount initialisieren
   if (!InitTradeAccount())
      return(last_error);

   // (2) SMS-Konfiguration des Accounts einlesen
   string mqlDir     = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string configFile = TerminalPath() + mqlDir +"\\files\\"+ tradeAccount.company +"\\"+ tradeAccount.number +"_config.ini";

   string sValue = StringToLower(GetIniString(configFile, "EventTracker", "Signal.SMS"));    // "on | off | {phone}"
   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      sValue = GetConfigString("SMS", "Receiver");
      if (!StringIsPhoneNumber(sValue)) return(catch("onInit(1)  invalid global/local config value [SMS]->Receiver = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_PARAMVALUE));
      __SMS.alerts   = true;
      __SMS.receiver = sValue;
   }
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false" || sValue=="") {
      __SMS.alerts = false;
   }
   else if (StringIsPhoneNumber(sValue)) {
      __SMS.alerts          = true;
      __SMS.receiver = sValue;
   }
   else return(catch("onInit(2)  invalid account config value [EventTracker]->Signal.SMS = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_PARAMVALUE));

   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   ScriptRunner.StopParamReceiver();
   QC.StopChannels();
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int    command;
   int    ticket1;
   int    ticket2;
   string trigger = "";

   // Solange in der Message-Queue TradeCommands liegen, diese nacheinander ausführen.
   while (GetTradeCommand(command, ticket1, ticket2, trigger)) {
      switch (command) {
         case TC_LFX_ORDER_OPEN   : OpenLfxOrder (ticket1, trigger); break;
         case TC_LFX_ORDER_CLOSE  : CloseLfxOrder(ticket1, trigger); break;

         case TC_LFX_ORDER_CREATE : //CreateLfxOrder (); break;
         case TC_LFX_ORDER_CLOSEBY: //CloseLfxOrderBy(); break;
         case TC_LFX_ORDER_HEDGE  : //HedgeLfxOrder  (); break;
         case TC_LFX_ORDER_MODIFY : //ModifyLfxOrder (); break;
         case TC_LFX_ORDER_DELETE : warn("onStart(1)  execution of trade command "+ TradeCommandToStr(command) +" not implemented", ERR_NOT_IMPLEMENTED);
                                    break;
         default:
            warn("onStart(2)  invalid trade command = "+ command, ERR_INVALID_COMMAND);
      }
   }

   return(catch("onStart(3)"));
}


/**
 * Gibt das nächste in der Parameter-Queue des Scripts eingetroffene TradeCommand zurück.
 *
 * @param  _Out_ int    command - TradeCommand
 * @param  _Out_ int    ticket1 - erstes beteiligtes Ticket des TradeCommands  (falls zutreffend)
 * @param  _Out_ int    ticket2 - zweites beteiligtes Ticket des TradeCommands (falls zutreffend)
 * @param  _Out_ string trigger - Trigger-Message des TradeCommands            (falls zutreffend)
 *
 * @return bool - TRUE,  wenn ein TradeCommand eingetroffen ist
 *                FALSE, wenn kein TradeCommand eingetroffen ist und die Parameter-Queue des Scripts leer ist oder ein Fehler auftrat
 */
bool GetTradeCommand(int &command, int &ticket1, int &ticket2, string &trigger) {
   // (1) Parameter zurücksetzen
   int    _command;    command = NULL;
   int    _ticket;                     bool isTicket;
   int    _ticket1;    ticket1 = NULL; bool isTicket1;
   int    _ticket2;    ticket2 = NULL; bool isTicket2;
   string _trigger=""; trigger = "";


   // (2) Sind keine gespeicherten Commands vorhanden, Scriptparameter neu einlesen
   string commands[];
   if (!ArraySize(commands)) {
      bool stopReceiver = false;
      if (!ScriptRunner.GetParameters(commands, stopReceiver)) return(false);
      //debug("GetTradeCommand(1)  got "+ ArraySize(commands) +" parameter"+ ifString(ArraySize(commands)==1, "", "s"));
      if (!ArraySize(commands)) return(false);                           // bei leerer Queue mit FALSE zurückkehren
   }


   // (3) Das nächste Command parsen und syntaktisch validieren, Format: LfxOrderCreateCommand {type:[order_type],            trigger:"message"}
   //                                                                    LfxOrderOpenCommand   {ticket:12345,                 trigger:"message"}
   //                                                                    LfxOrderCloseCommand  {ticket:12345,                 trigger:"message"}
   //                                                                    LfxOrderCloseByCommand{ticket1:12345, ticket2:67890, trigger:"message"}
   //                                                                    LfxOrderHedgeCommand  {ticket:12345,                 trigger:"message"}
   //                                                                    LfxOrderModifyCommand {ticket:12345,                 trigger:"message"}
   //                                                                    LfxOrderDeleteCommand {ticket:12345,                 trigger:"message"}
   string sCommand = StringTrim(ArrayShiftString(commands));
   string sType    = StringTrim(StringLeftTo(sCommand, "{"));
   if      (sType == "LfxOrderCreateCommand" ) _command = TC_LFX_ORDER_CREATE;
   else if (sType == "LfxOrderOpenCommand"   ) _command = TC_LFX_ORDER_OPEN;
   else if (sType == "LfxOrderCloseCommand"  ) _command = TC_LFX_ORDER_CLOSE;
   else if (sType == "LfxOrderCloseByCommand") _command = TC_LFX_ORDER_CLOSEBY;
   else if (sType == "LfxOrderHedgeCommand"  ) _command = TC_LFX_ORDER_HEDGE;
   else if (sType == "LfxOrderModifyCommand" ) _command = TC_LFX_ORDER_MODIFY;
   else if (sType == "LfxOrderDeleteCommand" ) _command = TC_LFX_ORDER_DELETE;
   else                                                                        return(!catch("GetTradeCommand(2)  invalid trade command type = "+ DoubleQuoteStr(sType), ERR_INVALID_COMMAND));

   if (!StringEndsWith(sCommand, "}"))                                         return(!catch("GetTradeCommand(3)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (no closing curly brace)", ERR_INVALID_COMMAND));
   string sProperties = StringTrim(StringLeft(StringRightFrom(sCommand, "{"), -1));
   string properties[], propParts[], name, sValue;
   int size = Explode(sProperties, ",", properties, NULL);

   for (int i=0; i < size; i++) {
      if (Explode(properties[i], ":", propParts, 2) < 2)                       return(!catch("GetTradeCommand(4)  invalid trade command = "+ DoubleQuoteStr(sCommand), ERR_INVALID_COMMAND));
      name   = StringTrim(propParts[0]);
      sValue = StringTrim(propParts[1]);

      if (name == "ticket") {
         if (!StringIsDigit(sValue))                                           return(!catch("GetTradeCommand(5)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket)", ERR_INVALID_COMMAND));
         _ticket = StrToInteger(sValue);
         if (_ticket <= 0)                                                     return(!catch("GetTradeCommand(6)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket)", ERR_INVALID_COMMAND));
         isTicket = true;
      }
      else if (name == "ticket1") {
         if (!StringIsDigit(sValue))                                           return(!catch("GetTradeCommand(7)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket1)", ERR_INVALID_COMMAND));
         _ticket1 = StrToInteger(sValue);
         if (_ticket1 <= 0)                                                    return(!catch("GetTradeCommand(8)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket1)", ERR_INVALID_COMMAND));
         isTicket1 = true;
      }
      else if (name == "ticket2") {
         if (!StringIsDigit(sValue))                                           return(!catch("GetTradeCommand(9)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket2)", ERR_INVALID_COMMAND));
         _ticket2 = StrToInteger(sValue);
         if (_ticket2 <= 0)                                                    return(!catch("GetTradeCommand(10)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (ticket2)", ERR_INVALID_COMMAND));
         isTicket2 = true;
      }
      else if (name == "trigger") {
         if (StringLen(sValue) < 2)                                            return(!catch("GetTradeCommand(11)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (trigger)", ERR_INVALID_COMMAND));
         if (!StringStartsWith(sValue, "\"") || !StringEndsWith(sValue, "\"")) return(!catch("GetTradeCommand(12)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (trigger: enclosing quotes or comma)", ERR_INVALID_COMMAND));
         sValue = StringLeft(StringRight(sValue, -1), -1);
         if (StringContains(sValue, "\""))                                     return(!catch("GetTradeCommand(13)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (trigger: illegal characters)", ERR_INVALID_COMMAND));
         _trigger = StringReplace(StringReplace(sValue, HTML_COMMA, ","), HTML_DQUOTE, "\"");
      }
      else                                                                     return(!catch("GetTradeCommand(14)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (property name "+ DoubleQuoteStr(name) +")", ERR_INVALID_COMMAND));
   }


   // (4) Command logisch validieren und erst dann die übergebenen Variablen setzen
   switch (_command) {
      case TC_LFX_ORDER_OPEN  :
      case TC_LFX_ORDER_CLOSE :
      case TC_LFX_ORDER_HEDGE :
      case TC_LFX_ORDER_DELETE: if (!isTicket) return(!catch("GetTradeCommand(15)  invalid trade command = "+ DoubleQuoteStr(sCommand) +" (missing ticket)", ERR_INVALID_COMMAND));
         ticket1 = _ticket;
         break;
      case TC_LFX_ORDER_CREATE :
      case TC_LFX_ORDER_CLOSEBY:
      case TC_LFX_ORDER_MODIFY :
         return(!catch("GetTradeCommand(16)  execution of trade command "+ DoubleQuoteStr(TradeCommandToStr(_command)) +" not implemented", ERR_NOT_IMPLEMENTED));
   }
   command = _command;
   trigger = _trigger;

   return(true);
}


/**
 * Öffnet eine Pending-LFX-Order.
 *
 * @param  _In_ int    ticket  - LFX-Ticket der Order
 * @param  _In_ string trigger - Trigger-Message der Order (default: keine)
 *
 * @return bool - Erfolgsstatus
 */
bool OpenLfxOrder(int ticket, string trigger="") {
   // Um die Implementierung übersichtlich zu halten, wird der Funktionsablauf in Teilschritte aufgeteilt und jeder Schritt
   // in eine eigene Funktion ausgelagert:
   //
   //  - Order ausführen
   //  - Order speichern (Erfolgs- oder Fehlerstatus), dabei ERR_CONCURRENT_MODIFICATION berücksichtigen
   //  - LFX-Terminal benachrichtigen (Erfolgs- oder Fehlerstatus)
   //  - SMS-Benachrichtigung verschicken (Erfolgs- oder Fehlerstatus)

   int order[LFX_ORDER.intSize];
   int result = LFX.GetOrder(ticket, order);
   if (result < 1) { if (!result) return(last_error); return(catch("OpenLfxOrder(1)  LFX ticket #"+ ticket +" not found", ERR_INVALID_INPUT_PARAMETER)); }

   log("OpenLfxOrder(2)  open #"+ lo.Ticket(order) +" on "+ tradeAccount.company +":"+ tradeAccount.number +" ("+ tradeAccount.currency +")");

   int  subPositions, error;

   bool success.open   = OpenLfxOrder.Execute        (order, subPositions); error = last_error;
   bool success.save   = OpenLfxOrder.Save           (order, !success.open);
   bool success.notify = OpenLfxOrder.NotifyListeners(order);
   bool success.sms    = OpenLfxOrder.SendSMS        (order, subPositions, trigger, error);

   ArrayResize(order, 0);
   return(success.open && success.save && success.notify && success.sms);
}


/**
 * Öffnet die Order.
 *
 * @param  _In_  LFX_ORDER lo[]         - LFX-Order
 * @param  _Out_ int       subPositions - Variable zur Aufnahme der Anzahl der geöffneten Subpositionen
 *
 * @return bool - Erfolgsstatus
 */
bool OpenLfxOrder.Execute(/*LFX_ORDER*/int lo[], int &subPositions) {
   subPositions = 0;
   if (!lo.IsPendingOrder(lo)) return(!catch("OpenLfxOrder.Execute(1)  #"+ lo.Ticket(lo) +" cannot open "+ ifString(lo.IsOpenPosition(lo), "an already open position", "a closed order"), ERR_RUNTIME_ERROR));

   // (1) Trade-Parameter einlesen
   string lfxCurrency = lo.Currency(lo);
   int    direction   = IsShortTradeOperation(lo.Type(lo));
   double units       = lo.Units(lo);


   // (2) zu handelnde Pairs bestimmen
   string symbols    [7]; ArrayResize(symbols    , 0); ArrayResize(symbols    , 7);    // setzt die Größe und den Inhalt der Arrays zurück
   double exactLots  [7]; ArrayResize(exactLots  , 0); ArrayResize(exactLots  , 7);
   double roundedLots[7]; ArrayResize(roundedLots, 0); ArrayResize(roundedLots, 7);
   int    directions [7]; ArrayResize(directions , 0); ArrayResize(directions , 7);
   int    tickets    [7]; ArrayResize(tickets    , 0); ArrayResize(tickets    , 7);
   int    symbolsSize;
   double realUnits;

   if      (lfxCurrency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF";                        symbolsSize = 6; }
   else if (lfxCurrency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY";                        symbolsSize = 6; }
   else if (lfxCurrency == "NZD") { symbols[0] = "AUDNZD"; symbols[1] = "EURNZD"; symbols[2] = "GBPNZD"; symbols[3] = "NZDCAD"; symbols[4] = "NZDCHF"; symbols[5] = "NZDJPY"; symbols[6] = "NZDUSD"; symbolsSize = 7; }
   else if (lfxCurrency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY";                        symbolsSize = 6; }


   // (3) Leverage-Konfiguration einlesen und validieren
   double static.leverage;
   if (!static.leverage) {
      string section = "MoneyManagement";
      string key     = "BasketLeverage";
      if (!IsGlobalConfigKey(section, key)) return(!catch("OpenLfxOrder.Execute(2)  missing global MetaTrader config value ["+ section +"]->"+ key, ERR_INVALID_CONFIG_PARAMVALUE));
      string sValue = GetGlobalConfigString(section, key);
      if (!StringIsNumeric(sValue))         return(!catch("OpenLfxOrder.Execute(3)  invalid MetaTrader config value ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_PARAMVALUE));
      static.leverage = StrToDouble(sValue);
      if (static.leverage < 1)              return(!catch("OpenLfxOrder.Execute(4)  invalid MetaTrader config value ["+ section +"]->"+ key +" = "+ NumberToStr(static.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
   }
   double leverage = static.leverage;


   // (4) Lotsizes je Pair berechnen
   double externalAssets = GetExternalAssets(tradeAccount.company, tradeAccount.number);
   double visibleEquity  = AccountEquity()-AccountCredit();                            // bei negativer AccountBalance wird nur visibleEquity benutzt
      if (AccountBalance() > 0) visibleEquity = MathMin(AccountBalance(), visibleEquity);
   double equity = visibleEquity + externalAssets;

   string errorMsg, overLeverageMsg;

   for (int retry, i=0; i < symbolsSize; i++) {
      // (4.1) notwendige Daten ermitteln
      double bid       = MarketInfo(symbols[i], MODE_BID      );                       // TODO: bei ERR_SYMBOL_NOT_AVAILABLE Symbole laden
      double tickSize  = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue = MarketInfo(symbols[i], MODE_TICKVALUE);
      double minLot    = MarketInfo(symbols[i], MODE_MINLOT   );
      double maxLot    = MarketInfo(symbols[i], MODE_MAXLOT   );
      double lotStep   = MarketInfo(symbols[i], MODE_LOTSTEP  );
      if (IsError(catch("OpenLfxOrder.Execute(5)  \""+ symbols[i] +"\""))) return(false);

      // (4.2) auf ungültige MarketInfo()-Daten prüfen
      errorMsg = "";
      if      (LT(bid, 0.5)          || GT(bid, 300)      ) errorMsg = "Bid(\""      + symbols[i] +"\") = "+ NumberToStr(bid      , ".+");
      else if (LT(tickSize, 0.00001) || GT(tickSize, 0.01)) errorMsg = "TickSize(\"" + symbols[i] +"\") = "+ NumberToStr(tickSize , ".+");
      else if (LT(tickValue, 0.5)    || GT(tickValue, 20) ) errorMsg = "TickValue(\""+ symbols[i] +"\") = "+ NumberToStr(tickValue, ".+");
      else if (LT(minLot, 0.01)      || GT(minLot, 0.1)   ) errorMsg = "MinLot(\""   + symbols[i] +"\") = "+ NumberToStr(minLot   , ".+");
      else if (LT(maxLot, 50)                             ) errorMsg = "MaxLot(\""   + symbols[i] +"\") = "+ NumberToStr(maxLot   , ".+");
      else if (LT(lotStep, 0.01)     || GT(lotStep, 0.1)  ) errorMsg = "LotStep(\""  + symbols[i] +"\") = "+ NumberToStr(lotStep  , ".+");

      // (4.3) ungültige MarketInfo()-Daten behandeln
      if (StringLen(errorMsg) > 0) {
         if (retry < 3) {                                                              // 3 stille Versuche, korrekte Werte zu lesen
            Sleep(200);                                                                // bei Mißerfolg jeweils xxx Millisekunden warten
            i = -1;
            retry++;
            continue;
         }                                                                             // TODO: auf ERR_CONCURRENT_MODIFICATION prüfen
         return(!catch("OpenLfxOrder.Execute(6)  invalid MarketInfo() data: "+ errorMsg, ERR_INVALID_MARKET_DATA));
      }

      // (4.4) Lotsize berechnen
      double lotValue = bid/tickSize * tickValue;                                      // Value eines Lots in Account-Currency
      double unitSize = equity / lotValue * leverage / symbolsSize;                    // equity/lotValue ist die ungehebelte Lotsize (Hebel 1:1) und wird mit leverage gehebelt
      exactLots  [i]  = units * unitSize;                                              // exactLots zunächst auf Vielfaches von MODE_LOTSTEP runden
      roundedLots[i]  = NormalizeDouble(MathRound(exactLots[i]/lotStep) * lotStep, CountDecimals(lotStep));

      // Schrittweite mit zunehmender Lotsize über MODE_LOTSTEP hinaus erhöhen (entspricht Algorythmus in ChartInfos-Indikator)
      if      (roundedLots[i] <=    0.3 ) {                                                                                                       }   // Abstufung max. 6.7% je Schritt
      else if (roundedLots[i] <=    0.75) { if (lotStep <   0.02) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.02) *   0.02, 2); }   // 0.3-0.75: Vielfaches von   0.02
      else if (roundedLots[i] <=    1.2 ) { if (lotStep <   0.05) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.05) *   0.05, 2); }   // 0.75-1.2: Vielfaches von   0.05
      else if (roundedLots[i] <=    3.  ) { if (lotStep <   0.1 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.1 ) *   0.1 , 1); }   //    1.2-3: Vielfaches von   0.1
      else if (roundedLots[i] <=    7.5 ) { if (lotStep <   0.2 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.2 ) *   0.2 , 1); }   //    3-7.5: Vielfaches von   0.2
      else if (roundedLots[i] <=   12.  ) { if (lotStep <   0.5 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.5 ) *   0.5 , 1); }   //   7.5-12: Vielfaches von   0.5
      else if (roundedLots[i] <=   30.  ) { if (lotStep <   1.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  1   ) *   1      ); }   //    12-30: Vielfaches von   1
      else if (roundedLots[i] <=   75.  ) { if (lotStep <   2.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  2   ) *   2      ); }   //    30-75: Vielfaches von   2
      else if (roundedLots[i] <=  120.  ) { if (lotStep <   5.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  5   ) *   5      ); }   //   75-120: Vielfaches von   5
      else if (roundedLots[i] <=  300.  ) { if (lotStep <  10.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 10   ) *  10      ); }   //  120-300: Vielfaches von  10
      else if (roundedLots[i] <=  750.  ) { if (lotStep <  20.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 20   ) *  20      ); }   //  300-750: Vielfaches von  20
      else if (roundedLots[i] <= 1200.  ) { if (lotStep <  50.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 50   ) *  50      ); }   // 750-1200: Vielfaches von  50
      else                                { if (lotStep < 100.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/100   ) * 100      ); }   // 1200-...: Vielfaches von 100

      // (4.5) Lotsize validieren
      if (GT(roundedLots[i], maxLot)) return(!catch("OpenLfxOrder.Execute(7)  #"+ lo.Ticket(lo) +" too large trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(roundedLots[i], ".+") +" lot (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));

      // (4.6) bei zu geringer Equity Leverage erhöhen und Details für Warnung in (3.8) hinterlegen
      if (LT(roundedLots[i], minLot)) {
         roundedLots[i]  = minLot;
         overLeverageMsg = StringConcatenate(overLeverageMsg, ", ", symbols[i], " ", NumberToStr(roundedLots[i], ".+"), " instead of ", exactLots[i], " lot");
      }
      log("OpenLfxOrder.Execute(8)  lot size "+ symbols[i] +": calculated="+ DoubleToStr(exactLots[i], 4) +"  resulting="+ NumberToStr(roundedLots[i], ".+") +" ("+ NumberToStr(roundedLots[i]/exactLots[i]*100-100, "+.0R") +"%)");

      // (4.7) tatsächlich zu handelnde Units berechnen (nach Auf-/Abrunden)
      realUnits += (roundedLots[i] / exactLots[i] / symbolsSize);
   }
   realUnits = NormalizeDouble(realUnits * units, 1);
   log("OpenLfxOrder.Execute(9)  units: parameter="+ DoubleToStr(units, 1) +"  resulting="+ DoubleToStr(realUnits, 1));

   // (4.8) bei Leverageüberschreitung Info loggen, jedoch nicht abbrechen
   if (StringLen(overLeverageMsg) > 0)
      log("OpenLfxOrder.Execute(10)  #"+ lo.Ticket(lo) +" Not enough money! The following positions will over-leverage: "+ StringRight(overLeverageMsg, -2) +". Resulting position: "+ DoubleToStr(realUnits, 1) + ifString(EQ(realUnits, units), " units (unchanged)", " instead of "+ DoubleToStr(units, 1) +" units"+ ifString(LT(realUnits, units), " (not obtainable)", "")));


   // (5) Directions der Teilpositionen bestimmen
   for (i=0; i < symbolsSize; i++) {
      if (StringStartsWith(symbols[i], lfxCurrency)) directions[i] = direction;
      else                                           directions[i] = direction ^ 1;    // 0=>1, 1=>0
   }


   // (6) Teilorders ausführen und dabei Gesamt-OpenPrice berechnen
   string comment = lo.Comment(lo);
      if ( StringStartsWith(comment, lfxCurrency)) comment = StringRightFrom(comment, lfxCurrency);
      if ( StringStartsWith(comment, "."        )) comment = StringRight(comment, -1);
      if ( StringStartsWith(comment, "#"        )) comment = StringRight(comment, -1);
      if (!StringStartsWith(comment, lfxCurrency)) comment = lfxCurrency +"."+ comment;
   int    magicNumber = lo.Ticket(lo);
   double openPrice   = 1.0;

   for (i=0; i < symbolsSize; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;
      int      oeFlags     = NULL;

      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      tickets[i] = OrderSendEx(symbols[i], directions[i], roundedLots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor, oeFlags, oe);
      if (!tickets[i]) return(false);
      subPositions++;

      if (StringStartsWith(symbols[i], lfxCurrency)) openPrice *= oe.OpenPrice(oe);
      else                                           openPrice /= oe.OpenPrice(oe);
   }
   openPrice = MathPow(openPrice, 1/7.);
   if (lfxCurrency == "JPY")
      openPrice *= 100;                                                                // JPY wird normalisiert


   // (7) LFX-Order aktualisieren
   datetime now.fxt = TimeFXT(); if (!now.fxt) return(false);

   lo.setType      (lo, direction);
   lo.setUnits     (lo, realUnits);
   lo.setOpenTime  (lo, now.fxt  );
   lo.setOpenPrice (lo, openPrice);
   lo.setOpenEquity(lo, equity   );


   // (8) Logmessage ausgeben
   log("OpenLfxOrder.Execute(11)  "+ StringToLower(OrderTypeDescription(direction)) +" "+ DoubleToStr(realUnits, 1) +" "+ comment +" position opened at "+ NumberToStr(lo.OpenPrice(lo), ".4'"));


   ArrayResize(symbols    , 0);
   ArrayResize(exactLots  , 0);
   ArrayResize(roundedLots, 0);
   ArrayResize(directions , 0);
   ArrayResize(tickets    , 0);
   ArrayResize(oe         , 0);
   return(!catch("OpenLfxOrder.Execute(12)"));
}


/**
 * Speichert die Order.
 *
 * @param  _In_ LFX_ORDER lo[]        - LFX-Order
 * @param  _In_ bool      isOpenError - ob bei der Orderausführung ein Fehler auftrat (dieser Fehler ist u.U. nicht in der Order selbst gesetzt)
 *
 * @return bool - Erfolgsstatus
 */
bool OpenLfxOrder.Save(/*LFX_ORDER*/int lo[], bool isOpenError) {
   isOpenError = isOpenError!=0;

   // (1) ggf. Open-Error setzen
   if (isOpenError) /*&&*/ if (!lo.IsOpenError(lo)) {
      datetime now.fxt = TimeFXT(); if (!now.fxt) return(false);
      lo.setOpenTime(lo, -now.fxt);
   }


   // (2) Order speichern
   if (!LFX.SaveOrder(lo, NULL, F_ERR_CONCUR_MODIFICATION)) {     // ERR_CONCURRENT_MODIFICATION abfangen
      if (last_error != ERR_CONCURRENT_MODIFICATION)
         return(false);

      // ERR_CONCURRENT_MODIFICATION behandeln
      // -------------------------------------
      //  - Kann nur dann behandelt werden, wenn diese Änderung das Setzen von LFX_ORDER.OpenError war.
      //  - Bedeutet, daß ein Trade-Delay auftrat, der woanders bereits als Timeout (also als OpenError) interpretiert wurde.

      // (2.1) Order neu einlesen und gespeicherten OpenError-Status auswerten
      /*LFX_ORDER*/int stored[];
      int result = LFX.GetOrder(lo.Ticket(lo), stored);
      if (result != 1) { if (!result) return(last_error); return(!catch("OpenLfxOrder.Save(1)->LFX.GetOrder()  #"+ lo.Ticket(lo) +" not found", ERR_RUNTIME_ERROR)); }
      if (!lo.IsOpenError(stored))                        return(!catch("OpenLfxOrder.Save(2)->LFX.SaveOrder()  concurrent modification of #"+ lo.Ticket(lo) +", expected version "+ lo.Version(lo) +" of '"+ TimeToStr(lo.ModificationTime(lo), TIME_FULL) +" FXT', found version "+ lo.Version(stored) +" of '"+ TimeToStr(lo.ModificationTime(stored), TIME_FULL) +" FXT'", ERR_CONCURRENT_MODIFICATION));

      // (2.2) gespeicherten OpenError immer überschreiben (auch bei fehlgeschlagener Ausführung), um ein evt. "Mehr" an Ausführungsdetails nicht zu verlieren
      if (!isOpenError) log("OpenLfxOrder.Save(3)  over-writing stored LFX_ORDER.OpenError");

      lo.setVersion(lo, lo.Version(stored));
      ArrayResize(stored, 0);

      if (!LFX.SaveOrder(lo))                                        // speichern, ohne diesmal irgendwelche Fehler abzufangen
         return(false);
   }
   return(true);
}


/**
 * Schickt eine Benachrichtigung über Erfolg/Mißerfolg der Orderausführung an die interessierten Listener.
 *
 * @param  _In_ LFX_ORDER lo[] - LFX-Order
 *
 * @return bool - Erfolgsstatus
 */
bool OpenLfxOrder.NotifyListeners(/*LFX_ORDER*/int lo[]) {
   return(QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":open="+ (!lo.IsOpenError(lo))));
}


/**
 * Verschickt eine SMS über Erfolg/Mißerfolg der Orderausführung.
 *
 * @param  _In_ LFX_ORDER lo[]         - LFX-Order
 * @param  _In_ int       subPositions - Anzahl der geöffneten Subpositionen
 * @param  _In_ string    trigger      - Trigger-Message des Öffnens (falls zutreffend)
 * @param  _In_ int       error        - bei der Orderausführung aufgetretener Fehler (falls zutreffend)
 *
 * @return bool - Erfolgsstatus
 */
bool OpenLfxOrder.SendSMS(/*LFX_ORDER*/int lo[], int subPositions, string trigger, int error) {
   if (__SMS.alerts) {
      string comment=lo.Comment(lo), currency=lo.Currency(lo);
         if (StringStartsWith(comment, currency)) comment = StringSubstr(comment, 3);
         if (StringStartsWith(comment, "."     )) comment = StringSubstr(comment, 1);
         if (StringStartsWith(comment, "#"     )) comment = StringSubstr(comment, 1);
      int    counter  = StrToInteger(comment);
      string symbol.i = currency +"."+ counter;
      string message  = tradeAccount.alias +": "+ StringToLower(OrderTypeDescription(lo.Type(lo))) +" "+ DoubleToStr(lo.Units(lo), 1) +" "+ symbol.i;
      if (lo.IsOpenError(lo))     message = message +" opening at "+ NumberToStr(lo.OpenPrice(lo), ".4'") +" failed ("+ ErrorToStr(error) +"), "+ subPositions +" subposition"+ ifString(subPositions==1, "", "s") +" opened";
      else                        message = message +" position opened at "+ NumberToStr(lo.OpenPrice(lo), ".4'");
      if (StringLen(trigger) > 0) message = message +" ("+ trigger +")";

      if (!SendSMS(__SMS.receiver, TimeToStr(TimeLocalEx("OpenLfxOrder.SendSMS(1)"), TIME_MINUTES) +" "+ message))
         return(false);
   }
   return(true);
}


/**
 * Schließt eine offene LFX-Position.
 *
 * @param  _In_ int    ticket  - LFX-Ticket der Position
 * @param  _In_ string trigger - Trigger-Message des Schließens (default: keine)
 *
 * @return bool - Erfolgsstatus
 */
bool CloseLfxOrder(int ticket, string trigger) {
   // Um die Implementierung übersichtlich zu halten, wird der Funktionsablauf in Teilschritte aufgeteilt und jeder Schritt
   // in eine eigene Funktion ausgelagert:
   //
   //  - Position schließen
   //  - Order speichern (Erfolgs- oder Fehlerstatus), dabei ERR_CONCURRENT_MODIFICATION berücksichtigen
   //  - LFX-Terminal benachrichtigen (Erfolgs- oder Fehlerstatus)
   //  - SMS-Benachrichtigung verschicken (Erfolgs- oder Fehlerstatus)

   // Order holen
   int order[LFX_ORDER.intSize];
   int result = LFX.GetOrder(ticket, order);
   if (result < 1) { if (!result) return(last_error); return(catch("CloseLfxOrder(1)  LFX ticket #"+ ticket +" not found", ERR_INVALID_INPUT_PARAMETER)); }

   log("CloseLfxOrder(2)  close #"+ lo.Ticket(order) +" on "+ tradeAccount.company +":"+ tradeAccount.number +" ("+ tradeAccount.currency +")");

   string comment = lo.Comment(order);
   int    error;

   bool success.close  = CloseLfxOrder.Execute        (order); error = last_error;
   bool success.save   = CloseLfxOrder.Save           (order, !success.close);
   bool success.notify = CloseLfxOrder.NotifyListeners(order);
   bool success.sms    = CloseLfxOrder.SendSMS        (order, comment, trigger, error);

   ArrayResize(order, 0);
   return(success.close && success.save && success.notify && success.sms);
}


/**
 * Schließt die Position.
 *
 * @param  _In_ LFX_ORDER lo[] - LFX-Order
 *
 * @return bool - Erfolgsstatus
 */
bool CloseLfxOrder.Execute(/*LFX_ORDER*/int lo[]) {
   if (!lo.IsOpenPosition(lo)) return(!catch("CloseLfxOrder.Execute(1)  #"+ lo.Ticket(lo) +" cannot close "+ ifString(lo.IsPendingOrder(lo), "a pending", "an already closed") +" order", ERR_RUNTIME_ERROR));


   // (1) zu schließende Einzelpositionen selektieren
   int tickets[]; ArrayResize(tickets, 0);
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: in einem anderen Thread wurde eine aktive Order geschlossen oder gestrichen
         break;
      if (OrderType() > OP_SELL)
         continue;
      if (OrderMagicNumber() == lo.Ticket(lo))
         ArrayPushInt(tickets, OrderTicket());
   }
   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize) return(!catch("CloseLfxOrder.Execute(2)  #"+ lo.Ticket(lo) +" no matching open subpositions found ", ERR_RUNTIME_ERROR));


   // (2) Einzelpositionen schließen
   double slippage    = 0.1;
   color  markerColor = CLR_NONE;
   int    oeFlags     = NULL;

   /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, ticketsSize); InitializeByteBuffer(oes, ORDER_EXECUTION.size);
   if (!OrderMultiClose(tickets, slippage, markerColor, oeFlags, oes))
      return(false);


   // (3) Gesamt-ClosePrice und -Profit berechnen
   string currency = lo.Currency(lo);
   double closePrice=1.0, profit=0;
   for (i=0; i < ticketsSize; i++) {
      if (StringStartsWith(oes.Symbol(oes, i), currency)) closePrice *= oes.ClosePrice(oes, i);
      else                                                closePrice /= oes.ClosePrice(oes, i);
      profit += oes.Swap(oes, i) + oes.Commission(oes, i) + oes.Profit(oes, i);
   }
   closePrice = MathPow(closePrice, 1/7.);
   if (currency == "JPY")
      closePrice *= 100;                                             // JPY wird normalisiert


   // (4) LFX-Order aktualisieren
   datetime now.fxt  = TimeFXT(); if (!now.fxt) return(false);
   string oldComment = lo.Comment(lo);
   lo.setCloseTime (lo, now.fxt   );
   lo.setClosePrice(lo, closePrice);
   lo.setProfit    (lo, profit    );
   lo.setComment   (lo, ""        );


   // (5) Logmessage ausgeben                                        // letzten Counter ermitteln
   if (StringStartsWith(oldComment, lo.Currency(lo))) oldComment = StringRight(oldComment, -3);
   if (StringStartsWith(oldComment, "."            )) oldComment = StringRight(oldComment, -1);
   if (StringStartsWith(oldComment, "#"            )) oldComment = StringRight(oldComment, -1);
   int    counter  = StrToInteger(oldComment);
   string symbol.i = currency +"."+ counter;

   log("CloseLfxOrder.Execute(3)  "+ StringToLower(OrderTypeDescription(lo.Type(lo))) +" "+ DoubleToStr(lo.Units(lo), 1) +" "+ symbol.i +" closed at "+ NumberToStr(lo.ClosePrice(lo), ".4'") +", profit: "+ DoubleToStr(lo.Profit(lo), 2));

   ArrayResize(tickets, 0);
   ArrayResize(oes    , 0);
   return(true);
}


/**
 * Speichert die Order.
 *
 * @param  _In_ LFX_ORDER lo[]         - LFX-Order
 * @param  _In_ bool      isCloseError - ob bei der Orderausführung ein Fehler auftrat (dieser Fehler ist u.U. nicht in der Order selbst gesetzt)
 *
 * @return bool - Erfolgsstatus
 */
bool CloseLfxOrder.Save(/*LFX_ORDER*/int lo[], bool isCloseError) {
   isCloseError = isCloseError!=0;

   // (1) ggf. CloseError setzen
   if (isCloseError) /*&&*/ if (!lo.IsCloseError(lo)) {
      datetime now.fxt = TimeFXT(); if (!now.fxt) return(false);
      lo.setCloseTime(lo, -now.fxt);
   }


   // (2) Order speichern
   if (!LFX.SaveOrder(lo, NULL, F_ERR_CONCUR_MODIFICATION)) {     // ERR_CONCURRENT_MODIFICATION abfangen
      if (last_error != ERR_CONCURRENT_MODIFICATION)
         return(false);

      // ERR_CONCURRENT_MODIFICATION behandeln
      // -------------------------------------
      //  - Kann nur dann behandelt werden, wenn diese Änderung das Setzen von LFX_ORDER.CloseError war.
      //  - Bedeutet, daß ein Trade-Delay auftrat, der woanders bereits als Timeout (also als CloseError) interpretiert wurde.

      // (2.1) Order neu einlesen und gespeicherten CloseError-Status auswerten
      /*LFX_ORDER*/int stored[];
      int result = LFX.GetOrder(lo.Ticket(lo), stored);
      if (result != 1) { if (!result) return(last_error); return(!catch("CloseLfxOrder.Save(1)->LFX.GetOrder()  #"+ lo.Ticket(lo) +" not found", ERR_RUNTIME_ERROR)); }
      if (!lo.IsCloseError(stored))                       return(!catch("CloseLfxOrder.Save(2)->LFX.SaveOrder()  concurrent modification of #"+ lo.Ticket(lo) +", expected version "+ lo.Version(lo) +" of '"+ TimeToStr(lo.ModificationTime(lo), TIME_FULL) +" FXT', found version "+ lo.Version(stored) +" of '"+ TimeToStr(lo.ModificationTime(stored), TIME_FULL) +" FXT'", ERR_CONCURRENT_MODIFICATION));


      // (2.2) gespeicherten CloseError immer überschreiben (auch bei fehlgeschlagener Ausführung), um ein evt. "Mehr" an Ausführungsdetails nicht zu verlieren
      if (!isCloseError) log("CloseLfxOrder.Save(3)  over-writing stored LFX_ORDER.CloseError");

      lo.setVersion(lo, lo.Version(stored));
      ArrayResize(stored, 0);

      if (!LFX.SaveOrder(lo))                                        // speichern, ohne diesmal ohne irgendwelche Fehler abzufangen
         return(false);
   }
   return(true);
}


/**
 * Schickt eine Benachrichtigung über Erfolg/Mißerfolg der Orderausführung ans LFX-Terminal.
 *
 * @param  _In_ LFX_ORDER lo[] - LFX-Order
 *
 * @return bool - Erfolgsstatus
 */
bool CloseLfxOrder.NotifyListeners(/*LFX_ORDER*/int lo[]) {
   return(QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":close="+ (!lo.IsCloseError(lo))));
}


/**
 * Verschickt eine SMS über Erfolg/Mißerfolg der Orderausführung.
 *
 * @param  _In_ LFX_ORDER lo[]    - LFX-Order
 * @param  _In_ string    comment - das ursprüngliche Label bzw. der Comment der Order
 * @param  _In_ string    trigger - Trigger-Message des Schließen (falls zutreffend)
 * @param  _In_ int       error   - bei der Orderausführung aufgetretener Fehler (falls zutreffend)
 *
 * @return bool - Erfolgsstatus
 */
bool CloseLfxOrder.SendSMS(/*LFX_ORDER*/int lo[], string comment, string trigger, int error) {
   if (__SMS.alerts) {
      string currency = lo.Currency(lo);
      if (StringStartsWith(comment, currency)) comment = StringSubstr(comment, 3);
      if (StringStartsWith(comment, "."     )) comment = StringSubstr(comment, 1);
      if (StringStartsWith(comment, "#"     )) comment = StringSubstr(comment, 1);
      int    counter  = StrToInteger(comment);
      string symbol.i = currency +"."+ counter;
      string message  = tradeAccount.alias +": "+ StringToLower(OrderTypeDescription(lo.Type(lo))) +" "+ DoubleToStr(lo.Units(lo), 1) +" "+ symbol.i;
      if (lo.IsCloseError(lo))    message = message + " closing of position failed ("+ ErrorToStr(error) +")";
      else                        message = message + " position closed at "+ NumberToStr(lo.ClosePrice(lo), ".4'");
      if (StringLen(trigger) > 0) message = message +" ("+ trigger +")";

      if (!SendSMS(__SMS.receiver, TimeToStr(TimeLocalEx("CloseLfxOrder.SendSMS(1)"), TIME_MINUTES) +" "+ message))
         return(false);
   }
   return(true);
}
