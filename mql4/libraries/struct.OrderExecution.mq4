/**
 *
 */
#property library

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/myfx/OrderExecution.mqh>


/**
 * Wird in Expert::Library::init() bei Init-Cycle im Tester aufgerufen, um die verwendeten globalen Variablen vor dem nächsten
 * Test zurücksetzen zu können.
 */
void Tester.ResetGlobalLibraryVars() {
   ArrayResize(stack.orderSelections, 0);
}
