/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


#import "Expander.Release.dll"
   double round(double value, int digits);
#import




/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {

   round(NULL, NULL);

   return(catch("onStart(2)"));
}
