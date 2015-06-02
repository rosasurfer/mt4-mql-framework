/**
 * Leeres Script, dem der Hotkey Strg-P zugeordnet ist und den unbeabsichtigten Aufruf des "Drucken"-Dialog abfängt.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(last_error);
}
