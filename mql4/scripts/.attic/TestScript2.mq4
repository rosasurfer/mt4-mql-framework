/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   return(catch("onStart(1)"));
}
