/**
 * Schließt die angegebenen LFX-Positionen.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <LFX/functions.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string LFX.Labels = "";                           // Label_1 [, Label_n [, ...]]: Prüfung per OrderComment().StringIStartsWith(value)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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
   int inputSize=ArraySize(inputLabels), orders=OrdersTotal();

   string foundLabels []; ArrayResize(foundLabels,  0);
   int    foundTickets[]; ArrayResize(foundTickets, 0);


   // (1) zu schließende Positionen selektieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      // FALSE: während des Auslesens wurde in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      if (LFX.IsMyOrder()) {
         if (OrderType() > OP_SELL)
            continue;

         for (int n=0; n < inputSize; n++) {
            if (StringIStartsWith(OrderComment(), inputLabels[n])) {
               string label = GetCurrency(LFX.GetCurrencyId(OrderMagicNumber())) +"."+ LFX.GetCounter(OrderMagicNumber());
               if (!StringInArray(foundLabels, label))
                  ArrayPushString(foundLabels, label);
               if (!IntInArray(foundTickets, OrderTicket()))
                  ArrayPushInt(foundTickets, OrderTicket());
               break;
            }
         }
      }
   }


   // (2) Positionen schließen
   int foundSize = ArraySize(foundLabels);
   if (foundSize > 0) {
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to close the specified "+ ifString(foundSize==1, "", foundSize +" ") +"LFX position"+ ifString(foundSize==1, "", "s") +"?", __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         int oeFlags = NULL;
         /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, ArraySize(foundTickets)); InitializeByteBuffer(oes, ORDER_EXECUTION.size);
         if (!OrderMultiClose(foundTickets, 0.1, Orange, oeFlags, oes))
            return(SetLastError(stdlib_GetLastError()));
         ArrayResize(oes, 0);

         // TODO: erzielten ClosePrice() berechnen und ausgeben

         // (3) Tickets aus ".\experts\files\LiteForex\remote_positions.ini" löschen
         string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
         string section = ShortAccountCompany() +"."+ AccountNumber();
         for (i=0; i < foundSize; i++) {
            int error = DeleteIniKey(file, section, foundLabels[i]);
            if (IsError(error))
               return(SetLastError(error));
         }
      }
   }
   else {
      PlaySound("notify.wav");
      MessageBox("No matching LFX positions found.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
   }

   return(last_error);
}
