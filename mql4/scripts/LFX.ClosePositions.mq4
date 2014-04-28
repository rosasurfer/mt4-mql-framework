/**
 * Schließt die angegebenen LFX-Positionen.
 *
 * NOTE: Zur Zeit können die Positionen nur einzeln und nicht gleichzeitig geschlossen werden. Beim gleichzeitigen Schließen
 *       kann der ClosePrice der Gesamtposition noch nicht korrekt berechnet werden. Beim einzelnen Schließen mehrerer Positionen
 *       werden dadurch Commission und Spread mehrfach berechnet.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <lfx.mqh>
#include <win32api.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string LFX.Labels = "";                           // Label_1 [, Label_n [, ...]]: Prüfung per OrderComment().StartsWithIgnore(value)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string inputLabels[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Parametervalidierung
   LFX.Labels = StringTrim(LFX.Labels);
   if (!StringLen(LFX.Labels))
      return(catch("onInit(1)   Invalid input parameter LFX.Labels = \""+ LFX.Labels +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // Labels splitten und trimmen
   int size = Explode(LFX.Labels, ",", inputLabels, NULL);

   for (int i=0; i < size; i++) {
      inputLabels[i] = StringTrim(inputLabels[i]);
   }
   return(catch("onInit(2)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int magics       []; ArrayResize(magics,        0);      // alle zu schließenden LFX-'Tickets'
   int tickets      []; ArrayResize(tickets,       0);      // alle zu schließenden MT4-Tickets
   int tickets.magic[]; ArrayResize(tickets.magic, 0);      // MagicNumbers der zu schließenden MT4-Tickets: size(tickets) == size(tickets.magic)

   int inputSize=ArraySize(inputLabels), orders=OrdersTotal();


   // (1) zu schließende Positionen selektieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      // FALSE: während des Auslesens wurde in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;
      if (LFX.IsMyOrder()) {
         if (OrderType() > OP_SELL)
            continue;
         for (int n=0; n < inputSize; n++) {
            if (StringIStartsWith(OrderComment(), inputLabels[n])) {
               if (!IntInArray(magics, OrderMagicNumber())) {
                  ArrayPushInt(magics, OrderMagicNumber());
               }
               if (!IntInArray(tickets, OrderTicket())) {
                  ArrayPushInt(tickets,       OrderTicket()     );
                  ArrayPushInt(tickets.magic, OrderMagicNumber());
               }
               break;
            }
         }
      }
   }
   int magicsSize = ArraySize(magics);
   if (!magicsSize) {
      PlaySound("notify.wav");
      MessageBox("No matching LFX positions found.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(1)"));
   }


   // (2) Sicherheitsabfrage
   PlaySound("notify.wav");
   int button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to close the specified "+ ifString(magicsSize==1, "", magicsSize +" ") +"LFX position"+ ifString(magicsSize==1, "", "s") +"?", __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(2)"));


   // (3) Alle selektierten LFX-Positionen sperren, damit andere Indikatoren/Charts keine temporären Teilpositionen verarbeiten.
   for (i=0; i < magicsSize; i++) {
      // TODO: Deadlocks verhindern, falls einer der Mutexe bereits gesperrt ist.
      //if (!AquireLock("mutex.LFX.#"+ magics[i], true))
      //   return(SetLastError(stdlib_GetLastError()));
   }


   // (4) Positionen nacheinander schließen
   int ticketsSize = ArraySize(tickets);
   for (i=0; i < magicsSize; i++) {
      int positionSize, position[]; ArrayResize(position, 0);                          // Subset der in (1) gefundenen Tickets, Tickets jeweils einer LFX-Position
      for (n=0; n < ticketsSize; n++) {
         if (magics[i] == tickets.magic[n])
            positionSize = ArrayPushInt(position, tickets[n]);
      }


      // (5) Orderausführung
      double slippage    = 0.1;
      color  markerColor = CLR_NONE;
      int    oeFlags     = NULL;

      if (IsError(stdlib_GetLastError())) return(SetLastError(stdlib_GetLastError())); // vor Trade-Request alle evt. aufgetretenen Fehler abfangen
      if (IsError(catch("onStart(3)")))   return(last_error);

      /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, ArraySize(position)); InitializeByteBuffer(oes, ORDER_EXECUTION.size);
      if (!OrderMultiClose(position, slippage, markerColor, oeFlags, oes))
         return(SetLastError(stdlib_GetLastError()));


      // (6) Gesamt-ClosePrice und Profit der LFX-Position berechnen
      string currency = GetCurrency(LFX.CurrencyId(magics[i]));
      double closePrice=1.0, profit=0;
      for (n=0; n < positionSize; n++) {
         if (StringStartsWith(oes.Symbol(oes, n), currency)) closePrice *= oes.ClosePrice(oes, n);
         else                                                closePrice /= oes.ClosePrice(oes, n);
         profit += oes.Swap(oes, n) + oes.Commission(oes, n) + oes.Profit(oes, n);
      }
      closePrice = MathPow(closePrice, 1.0/7);
      if (currency == "JPY")
         closePrice = 1/closePrice;             // JPY ist invers notiert


      // (7) Logmessage ausgeben
      int    lfxDigits  =    ifInt(currency=="JPY",    3,     5 );
      string lfxFormat  = ifString(currency=="JPY", ".2'", ".4'");
             closePrice = NormalizeDouble(closePrice, lfxDigits);
      if (__LOG) log("onStart(4)   "+ currency +" position closed at "+ NumberToStr(closePrice, lfxFormat) +", profit: "+ DoubleToStr(profit, 2));


      // (8) LFX-Ticket in .ini-Datei aktualisieren
      int      t.operationType;
      string   t.symbol="", t.label ="";
      double   t.units, t.openEquity, t.openPrice, t.stopLoss, t.takeProfit, t.closePrice, t.profit;
      datetime t.openTime, t.openPriceTime, t.stopLossTime, t.takeProfitTime, t.closeTime, t.lastUpdate;

      int result = LFX.ReadTicket(magics[i], t.symbol, t.label, t.operationType, t.units, t.openTime, t.openEquity, t.openPrice, t.openPriceTime, t.stopLoss, t.stopLossTime, t.takeProfit, t.takeProfitTime, t.closeTime, t.closePrice, t.profit, t.lastUpdate);
      if (!result)     return(last_error);                           //  0, falls ein Fehler auftrat; -1, wenn das Ticket nicht gefunden wurde
      if (result != 1) return(catch("onStart(5)->LFX.ReadTicket(ticket="+ magics[i] +")   ticket not found", ERR_RUNTIME_ERROR));

      t.closeTime  = TimeGMT();
      t.closePrice = closePrice;
      t.profit     = profit;
      t.lastUpdate = t.closeTime;

      if (!LFX.WriteTicket(magics[i], "", t.operationType, t.units, t.openTime, t.openEquity, t.openPrice, t.openPriceTime, t.stopLoss, t.stopLossTime, t.takeProfit, t.takeProfitTime, t.closeTime, t.closePrice, t.profit, t.lastUpdate))
         return(last_error);
      ArrayResize(oes, 0);
   }


   // (9) Locks wieder freigeben
   for (i=0; i < magicsSize; i++) {
      //if (!ReleaseLock("mutex.LFX.#"+ magics[i]))
      //   return(SetLastError(stdlib_GetLastError()));
   }
   return(catch("onStart(6)"));
}
