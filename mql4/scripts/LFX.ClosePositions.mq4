/**
 * Schließt die angegebenen LFX-Positionen.
 *
 *
 * FEHLER !!!: Werden mehrere Positionen angegeben, wird nur die letzte geschlossen.
 *
 *
 * NOTE: Zur Zeit können die Positionen nur einzeln und nicht gleichzeitig geschlossen werden. Beim gleichzeitigen Schließen
 *       kann der ClosePrice der Gesamtposition noch nicht korrekt berechnet werden. Beim einzelnen Schließen mehrerer
 *       Positionen werden dadurch Commission und Spread mehrfach berechnet.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#property show_inputs
////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string LFX.Labels = "";                           // Label_1 [, Label_n [, ...]]: Prüfung per OrderComment().StrStartsWithI(value)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLib.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/rsf/LFXOrder.mqh>
#include <structs/rsf/OrderExecution.mqh>


string inputLabels[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // TradeAccount initialisieren
   if (!InitTradeAccount())
      return(last_error);

   // Parametervalidierung
   LFX.Labels = StrTrim(LFX.Labels);
   if (!StringLen(LFX.Labels)) return(HandleScriptError("onInit(1)", "invalid input parameter LFX.Labels: \""+ LFX.Labels +"\"", ERR_INVALID_INPUT_PARAMETER));

   // Labels splitten und trimmen
   int size = Explode(LFX.Labels, ",", inputLabels, NULL);
   for (int i=0; i < size; i++) {
      inputLabels[i] = StrTrim(inputLabels[i]);
   }
   return(catch("onInit(2)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopChannels();
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int magics       []; ArrayResize(magics,        0);      // alle zu schließenden LFX-Tickets
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
            if (StrStartsWithI(OrderComment(), inputLabels[n])) {
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
      PlaySoundEx("Windows Notify.wav");
      MessageBox("No matching LFX positions found.", ProgramName(), MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(1)"));
   }


   // (2) Sicherheitsabfrage
   PlaySoundEx("Windows Notify.wav");
   int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to close the specified "+ ifString(magicsSize==1, "", magicsSize +" ") +"LFX position"+ Pluralize(magicsSize) +"?", ProgramName(), MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(2)"));


   // (3) Alle selektierten LFX-Orders sperren, damit andere Indikatoren/Charts keine temporären Teilpositionen verarbeiten.
   for (i=0; i < magicsSize; i++) {
      // TODO: Deadlocks verhindern, falls einer der Mutexe bereits gesperrt ist.
      //if (!AquireLock("mutex.LFX.#"+ magics[i], true))
      //   return(ERR_RUNTIME_ERROR);
   }


   // (4) Positionen nacheinander schließen
   int ticketsSize = ArraySize(tickets);

   for (i=0; i < magicsSize; i++) {
      int positionSize, position[]; ArrayResize(position, 0);                          // Subset der in (1) gefundenen Tickets, Tickets jeweils einer LFX-Position
      for (n=0; n < ticketsSize; n++) {
         if (magics[i] == tickets.magic[n])
            positionSize = ArrayPushInt(position, tickets[n]);
      }

      if (IsError(catch("onStart(3)"))) return(last_error);                            // vor Trade-Request auf evt. aufgetretene Fehler prüfen


      // (5) Orderausführung
      int   slippage    = 1;
      color markerColor = CLR_NONE;
      int   oeFlags     = NULL;
      int   oes[][ORDER_EXECUTION_intSize];
      if (!OrdersClose(position, slippage, markerColor, oeFlags, oes)) return(ERR_RUNTIME_ERROR);


      // (6) Gesamt-ClosePrice und -Profit berechnen
      string currency = GetCurrency(LFX.CurrencyId(magics[i]));
      double closePrice=1.0, profit=0;
      for (n=0; n < positionSize; n++) {
         if (StrStartsWith(oes.Symbol(oes, n), currency)) closePrice *= oes.ClosePrice(oes, n);
         else                                             closePrice /= oes.ClosePrice(oes, n);
         profit += oes.Swap(oes, n) + oes.Commission(oes, n) + oes.Profit(oes, n);
      }
      closePrice = MathPow(closePrice, 1/7.);
      if (currency == "JPY")
         closePrice *= 100;                                          // JPY wird normalisiert


      // (7) LFX-Order aktualisieren und speichern
      /*LFX_ORDER*/int lo[];
      int result = LFX.GetOrder(magics[i], lo);
      if (result < 1) { if (!result) return(last_error); return(catch("onStart(5)  LFX order "+ magics[i] +" not found", ERR_RUNTIME_ERROR)); }
         datetime now.fxt = TimeFXT(); if (!now.fxt) return(last_error);
         lo.setCloseTime (lo, now.fxt   );
         lo.setClosePrice(lo, closePrice);
         lo.setProfit    (lo, profit    );
            string comment = lo.Comment(lo);
               if (StrStartsWith(comment, lo.Currency(lo))) comment = StringSubstr(comment, 3);
               if (StrStartsWith(comment, "."            )) comment = StringSubstr(comment, 1);
               if (StrStartsWith(comment, "#"            )) comment = StringSubstr(comment, 1);
               int counter = StrToInteger(comment);
            string sCounter = ifString(!counter, "", "."+ counter);  // letzten Counter ermitteln
         lo.setComment   (lo, ""        );
      if (!LFX.SaveOrder(lo))
         return(last_error);


      // (8) Logmessage ausgeben
      logDebug("onStart(4)  "+ currency + sCounter +" closed at "+ NumberToStr(lo.ClosePrice(lo), ".4'") +", profit: "+ DoubleToStr(lo.Profit(lo), 2));


      // (9) LFX-Terminal benachrichtigen
      if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":close=1"))
         return(last_error);
   }


   // (9) Orders wieder freigeben
   for (i=0; i < magicsSize; i++) {
      //if (!ReleaseLock("mutex.LFX.#"+ magics[i]))
      //   return(ERR_RUNTIME_ERROR);
   }
   return(catch("onStart(6)"));
}
