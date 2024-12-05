/**
 * Leeres Script, dem der Hotkey Strg-P zugeordnet ist und den unbeabsichtigten Aufruf des "Drucken"-Dialog abfängt.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   return(last_error);
}
