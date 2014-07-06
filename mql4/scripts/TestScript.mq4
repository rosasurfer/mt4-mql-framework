/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int i_1 = 5;

   string s = (i_1!=0);

   int i = (i_1!=0);

   debug("onStart()   s="+ s +"  i="+ i);

   return(last_error);
}
