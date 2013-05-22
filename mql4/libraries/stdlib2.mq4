/**
 * NOTE: Libraries use predefined variables of the module that called the library.
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/library.mqh>


#import "kernel32.dll"
   // Diese Deklaration benutzt zur Rückgabe statt eines String-Buffers einen Byte-Buffer. Die Performance ist etwas niedriger, da wir
   // den Buffer selbst parsen müssen. Dies ermöglicht jedoch die Rückgabe mehrerer Werte.
   int  GetPrivateProfileStringA(string lpSection, string lpKey, string lpDefault, int lpBuffer[], int bufferSize, string lpFileName);
#import


/**
 * Gibt die Namen aller Einträge eines Abschnitts einer ini-Datei zurück.
 *
 * @param  string fileName - Name der ini-Datei
 * @param  string section  - Name des Abschnitts
 * @param  string keys[]   - Array zur Aufnahme der gefundenen Schlüsselnamen
 *
 * @return int - Anzahl der gefundenen Schlüssel oder -1, falls ein Fehler auftrat
 */
int GetPrivateProfileKeys.2(string fileName, string section, string keys[]) {
   string sNull;
   int bufferSize = 200;
   int buffer[]; InitializeByteBuffer(buffer, bufferSize);

   int chars = GetPrivateProfileStringA(section, sNull, "", buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeByteBuffer(buffer, bufferSize);
      chars = GetPrivateProfileStringA(section, sNull, "", buffer, bufferSize, fileName);
   }

   int length;

   if (!chars) length = ArrayResize(keys, 0);                        // keine Schlüssel gefunden (File/Section nicht gefunden oder Section ist leer)
   else        length = ExplodeStrings(buffer, keys);

   if (catch("GetPrivateProfileKeys.2()") != NO_ERROR)
      return(-1);
   return(length);
}


/**
 * Setzt die globalen Arrays zurück. Wird nur im Tester und in library::init() aufgerufen.
 */
void Tester.ResetGlobalArrays() {
   if (IsTesting()) {
      ArrayResize(stack.orderSelections, 0);
   }
}
