/**
 * FXTradePro Martingale EA
 *
 * @see FXTradePro Strategy:     http://www.forexfactory.com/showthread.php?t=43221
 *      FXTradePro Journal:      http://www.forexfactory.com/showthread.php?t=82544
 *      FXTradePro Swing Trades: http://www.forexfactory.com/showthread.php?t=87564
 *
 *      PowerSM EA:              http://www.forexfactory.com/showthread.php?t=75394
 *      PowerSM Journal:         http://www.forexfactory.com/showthread.php?t=159789
 */
#include <stdlib.mqh>

int EA.uniqueId = 101;           // eindeutige ID dieses EA's (im Bereich 0-1023)


#define STATUS_INITIALIZED       1
#define STATUS_WAIT_ENTRYLIMIT   2
#define STATUS_PROGRESSING       3
#define STATUS_FINISHED          4
#define STATUS_INACTIVE          5



//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
extern string Entry.Direction                = "L[ong] | S[hort]";
//extern string Entry.Direction                = "long";
extern double Entry.Limit                    = 0;

extern string _2____________________________ = "==== TP and SL Settings ==============";
extern int    TakeProfit                     = 40;
extern int    StopLoss                       = 10;

extern string _3____________________________ = "==== Lotsizes =======================";
extern double Lotsize.Level.1                = 0.1;
extern double Lotsize.Level.2                = 0.1;
extern double Lotsize.Level.3                = 0.2;
extern double Lotsize.Level.4                = 0.3;
extern double Lotsize.Level.5                = 0.4;
extern double Lotsize.Level.6                = 0.6;
extern double Lotsize.Level.7                = 0.8;
extern double Lotsize.Level.8                = 1.1;
extern double Lotsize.Level.9                = 1.5;
extern double Lotsize.Level.10               = 2.0;
extern double Lotsize.Level.11               = 2.7;
extern double Lotsize.Level.12               = 3.6;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double   Pip;
int      PipDigits;
string   PriceFormat;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;
int      entryDirection = OP_UNDEFINED;
int      status;

int      levels.ticket    [], last.ticket;
int      levels.type      [], last.type;
double   levels.openPrice [], last.openPrice;
double   levels.lotsize   [], last.lotsize;
double   levels.swap      [], last.swap,       all.swaps;
double   levels.commission[], last.commission, all.commissions;
double   levels.profit    [], last.profit,     all.profits;
datetime levels.closeTime [], last.closeTime;                     // Unterscheidung zwischen offenen und geschlossenen Positionen


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits - Digits%2;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // (1) Beginn Parametervalidierung
   // Entry.Direction
   string direction = StringToUpper(StringTrim(Entry.Direction));
   if (StringLen(direction) == 0)
      return(catch("init(1)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   switch (StringGetChar(direction, 0)) {
      case 'B':
      case 'L': entryDirection = OP_BUY;  break;
      case 'S': entryDirection = OP_SELL; break;
      default:
         return(catch("init(2)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   }

   // Entry.Limit
   if (LT(Entry.Limit, 0))
      return(catch("init(3)  Invalid input parameter Entry.Limit = "+ NumberToStr(Entry.Limit, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfit
   if (TakeProfit < 1)
      return(catch("init(4)  Invalid input parameter TakeProfit = "+ TakeProfit, ERR_INVALID_INPUT_PARAMVALUE));

   // StopLoss
   if (StopLoss < 1)
      return(catch("init(5)  Invalid input parameter StopLoss = "+ StopLoss, ERR_INVALID_INPUT_PARAMVALUE));

   // Lotsizes
   if (LE(Lotsize.Level.1, 0)) return(catch("init(6)  Invalid input parameter Lotsize.Level.1 = "+ NumberToStr(Lotsize.Level.1, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   if (LT(Lotsize.Level.2, 0)) return(catch("init(7)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   if (EQ(Lotsize.Level.2, 0)) sequenceLength = 1;
   else {
      if (LT(Lotsize.Level.3, 0)) return(catch("init(8)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      if (EQ(Lotsize.Level.3, 0)) sequenceLength = 2;
      else {
         if (LT(Lotsize.Level.4, 0)) return(catch("init(9)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
         if (EQ(Lotsize.Level.4, 0)) sequenceLength = 3;
         else {
            if (LT(Lotsize.Level.5, 0)) return(catch("init(10)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
            if (EQ(Lotsize.Level.5, 0)) sequenceLength = 4;
            else {
               if (LT(Lotsize.Level.6, 0)) return(catch("init(11)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
               if (EQ(Lotsize.Level.6, 0)) sequenceLength = 5;
               else {
                  if (LT(Lotsize.Level.7, 0)) return(catch("init(12)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                  if (EQ(Lotsize.Level.7, 0)) sequenceLength = 6;
                  else {
                     if (LT(Lotsize.Level.8, 0)) return(catch("init(13)  Invalid input parameter Lotsize.Level.8 = "+ NumberToStr(Lotsize.Level.8, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                     if (EQ(Lotsize.Level.8, 0)) sequenceLength = 7;
                     else {
                        if (LT(Lotsize.Level.9, 0)) return(catch("init(14)  Invalid input parameter Lotsize.Level.9 = "+ NumberToStr(Lotsize.Level.9, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                        if (EQ(Lotsize.Level.9, 0)) sequenceLength = 8;
                        else {
                           if (LT(Lotsize.Level.10, 0)) return(catch("init(15)  Invalid input parameter Lotsize.Level.10 = "+ NumberToStr(Lotsize.Level.10, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                           if (EQ(Lotsize.Level.10, 0)) sequenceLength = 9;
                           else {
                              if (LT(Lotsize.Level.11, 0)) return(catch("init(16)  Invalid input parameter Lotsize.Level.11 = "+ NumberToStr(Lotsize.Level.11, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                              if (EQ(Lotsize.Level.11, 0)) sequenceLength = 10;
                              else {
                                 if (LT(Lotsize.Level.12, 0)) return(catch("init(17)  Invalid input parameter Lotsize.Level.12 = "+ NumberToStr(Lotsize.Level.12, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                                 if (EQ(Lotsize.Level.12, 0)) sequenceLength = 11;
                                 else                         sequenceLength = 12;
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
   // Ende Parametervalidierung


   // (2) Sequenzdaten einlesen
   if (sequenceId == 0) {                                               // noch keine Sequenz definiert
      progressionLevel = 0;
      if (ArraySize(levels.ticket) > 0) {
         ArrayResize(levels.ticket    , 0);                             // alte Daten ggf. löschen (Arrays sind statisch)
         ArrayResize(levels.type      , 0);
         ArrayResize(levels.openPrice , 0);
         ArrayResize(levels.lotsize   , 0);
         ArrayResize(levels.swap      , 0);
         ArrayResize(levels.commission, 0);
         ArrayResize(levels.profit    , 0);
         ArrayResize(levels.closeTime , 0);
      }

      // erste aktive Sequenz finden und offene Positionen einlesen
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
            continue;

         if (IsMyOrder(sequenceId)) {
            int level = OrderMagicNumber() & 0x000F;                    //  4 Bits  1-4  => progressionLevel
            if (level > progressionLevel)
               progressionLevel = level;

            if (sequenceId == 0) {
               sequenceId     = OrderMagicNumber() << 10 >> 18;         // 14 Bits  9-22 => sequenceId
               sequenceLength = OrderMagicNumber() & 0x00F0 >> 4;       //  4 Bits  5-8  => sequenceLength

               ArrayResize(levels.ticket    , sequenceLength);
               ArrayResize(levels.type      , sequenceLength);
               ArrayResize(levels.openPrice , sequenceLength);
               ArrayResize(levels.lotsize   , sequenceLength);
               ArrayResize(levels.swap      , sequenceLength);
               ArrayResize(levels.commission, sequenceLength);
               ArrayResize(levels.profit    , sequenceLength);
               ArrayResize(levels.closeTime , sequenceLength);

               if (level%2==1) entryDirection =  OrderType();
               else            entryDirection = ~OrderType() & 1;       // 0=>1, 1=>0
            }
            level--;
            levels.ticket    [level] = OrderTicket();
            levels.type      [level] = OrderType();
            levels.openPrice [level] = OrderOpenPrice();
            levels.lotsize   [level] = OrderLots();
            levels.swap      [level] = 0;                               // Beträge offener Positionen werden in ReadStatus() ausgelesen
            levels.commission[level] = 0;
            levels.profit    [level] = 0;
            levels.closeTime [level] = 0;                               // closeTime == 0: offene Position
         }
      }

      // fehlende Positionen aus der History auslesen
      if (sequenceId != 0) /*&&*/ if (IntInArray(0, levels.ticket)) {
         int orders = OrdersHistoryTotal();
         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wird der Anzeigezeitraum der History geändert
               break;

            if (IsMyOrder(sequenceId)) {
               level = OrderMagicNumber() & 0x000F;                     //  4 Bits  1-4  => progressionLevel
               if (level > progressionLevel)
                  progressionLevel = level;
               level--;

               // TODO: möglich bei gehedgten Positionen
               if (levels.ticket[level] != 0)
                  return(catch("init(18)   multiple tickets found for progression level "+ (level+1) +": #"+ levels.ticket[level] +", #"+ OrderTicket(), ERR_RUNTIME_ERROR));

               levels.ticket    [level] = OrderTicket();
               levels.type      [level] = OrderType();
               levels.openPrice [level] = OrderOpenPrice();
               levels.lotsize   [level] = OrderLots();
               levels.swap      [level] = OrderSwap();
               levels.commission[level] = OrderCommission();
               levels.profit    [level] = OrderProfit();
               levels.closeTime [level] = OrderCloseTime();             // closeTime != 0: geschlossene Position
            }
         }
      }

      // Tickets auf Vollständigkeit prüfen
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0)
            return(catch("init(19)   order not found for progression level "+ (i+1) +", more history data needed.", ERR_RUNTIME_ERROR));
      }
   }


   // (3) ggf. Sequenz anlegen
   if (sequenceId == 0) {
      sequenceId = CreateSequenceId();
      ArrayResize(levels.ticket    , sequenceLength);
      ArrayResize(levels.type      , sequenceLength);
      ArrayResize(levels.openPrice , sequenceLength);
      ArrayResize(levels.lotsize   , sequenceLength);
      ArrayResize(levels.swap      , sequenceLength);
      ArrayResize(levels.commission, sequenceLength);
      ArrayResize(levels.profit    , sequenceLength);
      ArrayResize(levels.closeTime , sequenceLength);
   }


   // (4) aktuellen Status bestimmen
   if (progressionLevel == 0) {
      if (EQ(Entry.Limit, 0))    status = STATUS_INITIALIZED;
      else                       status = STATUS_WAIT_ENTRYLIMIT;
   }
   else if (last.closeTime == 0) status = STATUS_PROGRESSING;
   else                          status = STATUS_FINISHED;


   // (5) bei Start ggf. EA's aktivieren
   int reasons[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
   if (!IsExpertEnabled()) /*&&*/ if (IntInArray(UninitializeReason(), reasons))
      ToggleEAs(true);


   // (6) nach Reload sofort start() aufrufen und nicht auf den nächsten Tick warten
   ArrayPushInt(reasons, REASON_PARAMETERS);
   ArrayPushInt(reasons, REASON_RECOMPILE );
   if (IntInArray(UninitializeReason(), reasons))
      SendTick(false);

   return(catch("init(20)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   if (UninitializeReason() != REASON_CHARTCHANGE)
      Comment("");
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (last_error != NO_ERROR) return(last_error);

   if (sequenceId <= 1000)
      return(catch("start(1)   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));


   if (ReadStatus()) {
      if (status != STATUS_FINISHED) {
         if (progressionLevel == 0) {                                      // noch keine offene Position
            if (IsEntryLimitReached())             StartSequence();        // kein Limit definiert oder Limit erreicht
         }
         else if (IsStopLossReached()) {                                   // wenn StopLoss erreicht ...
            if (progressionLevel < sequenceLength) IncreaseProgression();  // auf nächsten Level wechseln ...
            else                                   FinishSequence();       // ... oder Sequenz beenden
         }
         else if (IsProfitTargetReached())         FinishSequence();       // wenn TakeProfit erreicht, Sequenz beenden
      }
   }

   ShowStatus();

   if (last_error != NO_ERROR)
      return(last_error);
   return(catch("start(2)"));
}


/**
 * Überprüft den Status der aktuellen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadStatus() {
   return(catch("ReadStatus()") == NO_ERROR);
}


/**
 * Ob die aktuell selektierte Order von diesem EA erzeugt wurde. Wird eine Sequenz-ID angegeben, wird zusätzlich überprüft,
 * ob die Order zur angegebeben Sequenz gehört.
 *
 * @param  int sequenceId - ID einer aktiven Sequenz (default: NULL)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol()==Symbol()) {
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         if (OrderMagicNumber() >> 22 == EA.uniqueId) {
            if (sequenceId == NULL)
               return(true);
            return(sequenceId == OrderMagicNumber() << 10 >> 18);       // 14 Bits  9-22 => sequenceId
         }
      }
   }
   return(false);
}


/**
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenze-ID im Bereich 1000-16383 (14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());

   int id;
   while (id < 2000) {                    // Das abschließende Shiften halbiert den Wert und wir wollen mindestens eine 4-stellige ID haben.
      id = MathRand();
   }
   return(id >> 1);
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber()
 *
 * @return int - magic number
 */
int CreateMagicNumber() {
   int ea       = EA.uniqueId << 22;                  // 10 bit (Bereich 0-1023)                              | in MagicNumber: Bits 23-32
   int sequence = sequenceId  << 18 >> 10;            // Bits größer 14 löschen und Wert auf 22 Bit erweitern | in MagicNumber: Bits  9-22
   int length   = sequenceLength   & 0x000F << 4;     // 4 bit (Bereich 1-12), auf 8 bit erweitern            | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0x000F;          // 4 bit (Bereich 1-12)                                 | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


/**
 * Ob das eingestellte EntryLimit erreicht oder überschritten wurde.  Wurde kein Limit definiert, gibt die Funktion ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsEntryLimitReached() {
   if (EQ(Entry.Limit, 0))
      return(true);

   // Limit definiert
   if (entryDirection == OP_BUY) {
      if (LE(Ask, Entry.Limit))           // Buy-Limit erreicht
         return(true);
   }
   else if (GE(Bid, Entry.Limit))         // Sell-Limit erreicht
      return(true);

   return(false);
}


/**
 * Ob der eingestellte StopLoss erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsStopLossReached() {
   if (last.type == OP_BUY)
      return(LE(Bid, last.openPrice - StopLoss*Pip));

   if (last.type == OP_SELL)
      return(GT(Ask, last.openPrice + StopLoss*Pip));

   catch("IsStopLossReached()   illegal value for variable last.type = "+ last.type, ERR_RUNTIME_ERROR);
   return(false);
}


/**
 * Ob der eingestellte TakeProfit-Level erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsProfitTargetReached() {
   if (last.type == OP_BUY)
      return(GE(Bid, last.openPrice + TakeProfit*Pip));

   if (last.type == OP_SELL)
      return(LE(Ask, last.openPrice - TakeProfit*Pip));

   catch("IsProfitTargetReached()   illegal value for variable last.type = "+ last.type, ERR_RUNTIME_ERROR);
   return(false);
}


/**
 * Beginnt eine neue Trade-Sequenz (Progression-Level 1).
 *
 * @return int - Fehlerstatus
 */
int StartSequence() {
   if (EQ(Entry.Limit, 0)) {                                               // kein Limit definiert, also Aufruf direkt nach Start
      PlaySound("notify.wav");
      int answer = MessageBox("Do you really want to start a new trade sequence?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (answer != IDOK) {
         ShowStatus(STATUS_INACTIVE);
         last_error = ERR_COMMON_ERROR;
         return(last_error);
      }
   }

   progressionLevel = 1;

   int ticket = SendOrder(entryDirection, CurrentLotSize());               // Position in Entry.Direction öffnen
   if (ticket == -1)
      return(last_error);

   if (!ReadStatus())                                                      // Status neu einlesen
      return(last_error);

   return(catch("StartSequence(2)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   debug("IncreaseProgression()   StopLoss für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   progressionLevel++;
   int    direction = ifInt(last.type==OP_SELL, OP_BUY, OP_SELL);
   double lotsize   = CurrentLotSize();

   // Je nach Hedging-Fähigkeit des Accounts die letzte Position schließen oder hedgen.
   bool hedgingEnabled = true;                                          // IsHedgingEnabled() implementieren

   if (hedgingEnabled) {
      int ticket = SendOrder(direction, last.lotsize + lotsize);        // nächste Position öffnen
      if (ticket == -1) {
         if (last_error != ERR_TRADE_HEDGE_PROHIBITED)
            return(last_error);
         hedgingEnabled = false;                                        // Fallback
      }
   }

   if (!hedgingEnabled) {
      //ClosePosition();
      ticket = SendOrder(direction, lotsize);                           // nächste Position öffnen
      if (ticket == -1)
         return(last_error);
   }

   if (!ReadStatus())                                                   // Status neu einlesen
      return(last_error);

   return(catch("IncreaseProgression()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   if (IsProfitTargetReached()) debug("FinishSequence()   TakeProfit für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, Bid-last.openPrice, last.openPrice-Ask)/Pip, 1) +" pip");
   else                         debug("FinishSequence()   Letzter StopLoss für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) {
         if (levels.closeTime[i] == 0) {
            if (!OrderCloseEx(levels.ticket[i], NULL, NULL, 1, Orange))
               return(last_error);                          // TODO: später durch stdlib_PeekLastError() ersetzen

            if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
               int error = GetLastError();
               if (error == NO_ERROR)
                  error = ERR_INVALID_TICKET;
               return(catch("FinishSequence(1)   error selecting ticket #"+ levels.ticket[i], error));
            }
            levels.swap      [i] = OrderSwap();
            levels.commission[i] = OrderCommission();
            levels.profit    [i] = OrderProfit();
            levels.closeTime [i] = OrderCloseTime();
         }
      }
   }

   ShowStatus(STATUS_FINISHED);

   return(catch("FinishSequence()"));
}


/**
 * @param  int    type    - Ordertyp: OP_BUY | OP_SELL
 * @param  double lotsize - Lotsize der Order (variiert je nach Progression-Level und Hedging-Fähigkeit des Accounts)
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int SendOrder(int type, double lotsize) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("SendOrder(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (LE(lotsize, 0))
      return(catch("SendOrder(2)   illegal parameter lotsize = "+ NumberToStr(lotsize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));

   int    magicNumber = CreateMagicNumber();
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   int    slippage    = 1;
   color  markerColor = ifInt(type==OP_BUY, Blue, Red);

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, markerColor);

   if (ticket!=-1) /*&&*/ if (catch("SendOrder(3)")!=NO_ERROR)
      ticket = -1;
   return(ticket);
}


/**
 * Gibt die Lotsize des aktuellen Progression-Levels zurück.
 *
 * @return double - Lotsize oder -1, wenn ein Fehler auftrat
 */
double CurrentLotSize() {
   switch (progressionLevel) {
      case  1: return(Lotsize.Level.1);
      case  2: return(Lotsize.Level.2);
      case  3: return(Lotsize.Level.3);
      case  4: return(Lotsize.Level.4);
      case  5: return(Lotsize.Level.5);
      case  6: return(Lotsize.Level.6);
      case  7: return(Lotsize.Level.7);
      case  8: return(Lotsize.Level.8);
      case  9: return(Lotsize.Level.9);
      case 10: return(Lotsize.Level.10);
      case 11: return(Lotsize.Level.11);
      case 12: return(Lotsize.Level.12);
   }

   catch("CurrentLotSize()   illegal progression level = "+ progressionLevel, ERR_RUNTIME_ERROR);
   return(-1);
}


/**
 * TODO: Nach Fertigstellung alles auf StringConcatenate() umstellen.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus(int id=NULL) {
   string status=__SCRIPT__, msg="";

   switch (id) {
      case NULL: if (sequenceId != 0)         msg = ":  trade sequence "+ sequenceId +", #"+ last.ticket;
                 else if (EQ(Entry.Limit, 0)) msg = ":  waiting";
                 else                         msg = ":  waiting for entry limit "+ NumberToStr(Entry.Limit, PriceFormat); break;
      case STATUS_INACTIVE:                   msg = ":  inactive";                                                        break;
      case STATUS_FINISHED:                   msg = ":  trade sequence "+ sequenceId +" finished";                        break;
      default:
         return(catch("ShowStatus(1)   illegal parameter id = "+ id, ERR_INVALID_FUNCTION_PARAMVALUE));
   }

      status = status + msg + NL + NL;

   if (progressionLevel == 0) {
      status = status
             +"Progression Level:  "+ progressionLevel +" / "+ sequenceLength + NL;
   }
   else {
      status = status
             +"Progression Level:  "+ progressionLevel +" / "+ sequenceLength +"  =  "+ NumberToStr(CurrentLotSize(), ".+") +" lot" + NL;
   }
      status = status
             +"TakeProfit:            "+ TakeProfit +" pip" + NL
             +"StopLoss:               "+ StopLoss +" pip"  + NL;

   if (sequenceId != 0) {
      status = status
             +"Breakeven:           "+ "-"                                 + NL
             +"Profit / Loss:          "+ DoubleToStr(all.profits + all.commissions + all.swaps, 2) + NL;
   }

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(NL + NL + status);

   return(catch("ShowStatus(2)"));
}




