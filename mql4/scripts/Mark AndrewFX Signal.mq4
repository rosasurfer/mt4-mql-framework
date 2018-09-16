/**
 * Markiert im Chart Entry- und Exit-Signale des "AndrewFX System" von Andrew Forex.
 *
 * @see  http://www.forexfactory.com/showthread.php?t=214635
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>


/**
 *
 */
int onTick() {
   return(catch("onTick(1)"));
}
