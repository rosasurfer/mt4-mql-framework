/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>
//#include <iFunctions/iBarShiftNext.mqh>
//#include <iFunctions/iBarShiftPrevious.mqh>
//#include <iFunctions/iPreviousPeriodTimes.mqh>


#import "Expander.Release.dll"

   int   Test();

#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // (1) Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
   int orders = OrdersHistoryTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))        // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
         break;

      if (OrderType() == OP_BALANCE) {
         debug("onStart()  ticket="+ OrderTicket() +"  type="+ OrderTypeToStr(OrderType()) +"  symbol="+ StringToStr(OrderSymbol()) +"  openTime="+ TimeToStr(OrderOpenTime()) +"  closeTime="+ TimeToStr(OrderCloseTime()) +"  comment="+ StringToStr(OrderComment()));
      }
   }


   return(catch("onStart(1)"));


   int result = Test();
   debug("onStart()   result="+ result);
   return(catch("onStart(1)"));


   double a = MathLog(-1);
   double b = MathLog( 0);
   double c = -1* b;

   debug("onStart()  MathLog(-1)    = "+ a +" * -1 = "+ (-1*a) +"  (a!=a) => "+ BoolToStr(a != a), GetLastError());
   debug("onStart()  MathLog( 0)    = "+ b +" * -1 =  "+ (c)   +"  (b!=b) => "+ BoolToStr(b != b), GetLastError());
   debug("onStart()  MathSqrt(-1)   = "+ MathSqrt(-1)      , GetLastError());

   return(catch("onStart()"));
}

/*
TODO Build 600+:
----------------
UninitializeReason()
--------------------
- in EXECUTION_CONTEXT speichern
- in InitReason und DeinitReason auftrennen

int init();
int deinit();
int OnInit(int reason);
int OnDeinit(int reason);

int DebugMarketInfo(string location);
int FileReadLines(string filename, string lines[], bool skipEmptyLines);
*/
