/**
 *
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
}
