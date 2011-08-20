/**
 * Schließt die angegebenen Positionen. Ohne zusätzliche Parameter werden alle offenen Positionen geschlossen.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Close.Labels = "";                         // Label-1 [, Label-n [, ...]]      (Prüfung per OrderComment().StringIStartsWith(value))

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string orderSymbols[], orderComment;
int    orderTickets[], orderMagics[], orderType=OP_UNDEFINED;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // Parametervalidierung
   orderComment = StringTrim(Close.Labels);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);
   // ------------------------


   int orders = OrdersTotal();
   int tickets[]; ArrayResize(tickets, 0);


   // (1) zu schließende Positionen selektieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      if (StringIStartsWith(OrderComment(), orderComment)) /*&&*/ if (!IntInArray(OrderTicket(), tickets))
         ArrayPushInt(tickets, OrderTicket());
   }


   // (2) Positionen schließen
   int selected = ArraySize(tickets);
   if (selected > 0) {
      PlaySound("notify.wav");
      int button = MessageBox("Do you really want to close the specified "+ ArraySize(tickets) +" open positions?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         if (!OrderCloseMultiple(tickets, 0.1, Orange))
            return(processError(stdlib_PeekLastError()));
      }
   }
   else {
      PlaySound("notify.wav");
      MessageBox("No matching positions found.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
   }


   // (3) Positionen aus ...\SIG\external_positions.ini löschen

   return(catch("start()"));
}
