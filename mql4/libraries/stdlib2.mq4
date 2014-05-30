/**
 * NOTE: Libraries use predefined variables of the module that called the library.
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdlib.mqh>


#import "kernel32.dll"
   // Diese Deklaration benutzt zur Rückgabe statt eines String-Buffers einen Byte-Buffer. Die Performance ist geringer, da der Buffer
   // selbst geparst werden muß. Dies ermöglicht jedoch die Rückgabe mehrerer Werte.
   int  GetPrivateProfileStringA(string lpSection, string lpKey, string lpDefault, int lpBuffer[], int bufferSize, string lpFileName);
#import


/**
 * Gibt alle Schlüssel eines Abschnitts einer .ini-Datei zurück.
 *
 * @param  string fileName - Name der .ini-Datei
 * @param  string section  - Name des Abschnitts
 * @param  string keys[]   - Array zur Aufnahme der gefundenen Schlüsselnamen
 *
 * @return int - Anzahl der gefundenen Schlüssel oder -1, falls ein Fehler auftrat
 */
int GetIniKeys.2(string fileName, string section, string keys[]) {
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

   if (catch("GetIniKeys.2()") != NO_ERROR)
      return(-1);
   return(length);
}


/**
 * Konvertiert ein String-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  string values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string StringsToStr(string values[][], string separator=", ") {
   return(__StringsToStr(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string __StringsToStr(string values2[][], string values3[][][], string separator) {
   if (separator == "0")      // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result;

   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      string copy[]; ArrayCopy(copy, values2);
      DoubleQuoteStrings(copy);

      result = StringConcatenate("{", JoinStrings(copy, separator), "}");
      ArrayResize(copy, 0);
      return(result);
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      string    valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];            // TODO: NPE abfangen
         }
         strValuesX[x] = StringsToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      string    valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];      // TODO: NPE abfangen
            }
            strValuesY[y] = StringsToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("__StringsToStr()   too many dimensions of parameter values = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Faßt jeden Wert eines String-Arrays in doppelte Anführungszeichen ein. Nicht initialisierte Werte (NULL-Pointer) bleiben unverändert.
 *
 * @param  string values[]
 *
 * @return int - Fehlerstatus
 */
int DoubleQuoteStrings(string &values[]) {
   if (ArrayDimension(values) > 1)
      return(catch("DoubleQuoteStrings(1)   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS));

   string value;
   int error, size=ArraySize(values);

   for (int i=0; i < size; i++) {
      value = values[i];                                             // NPE provozieren
      error = GetLastError();
      if (!error) {
         values[i] = StringConcatenate("\"", values[i], "\"");
         continue;
      }
      if (error != ERR_NOT_INITIALIZED_ARRAYSTRING)                  // NULL-Werte bleiben unverändert
         return(catch("DoubleQuoteStrings(2)", error));
   }
   return(0);
}


/**
 * Konvertiert ein Array mit Kursen in einen mit dem aktuellen PriceFormat formatierten String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string RatesToStr(double values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("RatesToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (size == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (!values[i]) strings[i] = "0";
      else            strings[i] = NumberToStr(values[i], PriceFormat);

      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Alias
 *
 * Konvertiert ein Array mit Kursen in einen mit dem aktuellen PriceFormat formatierten String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string PricesToStr(double values[], string separator=", ") {
   return(RatesToStr(values, separator));
}


/**
 * Konvertiert ein Array mit Geldbeträgen in einen lesbaren String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String mit 2 Nachkommastellen je Wert oder Leerstring, falls ein Fehler auftrat
 */
string MoneysToStr(double values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("MoneysToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = NumberToStr(values[i], ".2");
      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert einen Indikatorbuffer in einen lesbaren String. Ganzzahlige Werte werden als Integer, gebrochene Werte
 * mit dem aktuellen PriceFormat formatiert.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string iBufferToStr(double values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("iBufferToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (size == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (!MathModFix(values[i], 1)) strings[i] = DoubleToStr(values[i], 0);
      else                           strings[i] = NumberToStr(values[i], PriceFormat);
      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein Doubles-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  double values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string DoublesToStr(double values[][], string separator=", ") {
   return(__DoublesToStr(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string __DoublesToStr(double values2[][], double values3[][][], string separator) {
   if (separator == "0")      // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;

   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoubles(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      double    valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = DoublesToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      double    valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = DoublesToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("__DoublesToStr()   too many dimensions of parameter values = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein DateTime-Array in einen lesbaren String.
 *
 * @param  datetime values[]
 * @param  string   separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TimesToStr(datetime values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("TimesToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if      (values[i] <  0) strings[i] = "-1";
      else if (values[i] == 0) strings[i] =  "0";
      else                     strings[i] = StringConcatenate("'", TimeToStr(values[i], TIME_FULL), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein OperationType-Array in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string OperationTypesToStr(int values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("OperationTypesToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[]; ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = OperationTypeToStr(values[i]);
      if (!StringLen(strings[i]))
         return("");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein Char-Array in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string CharsToStr(int values[], string separator=", ") {
   if (ArrayDimension(values) > 1)
      return(_empty(catch("CharsToStr()   too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = StringConcatenate("'", CharToStr(values[i]), "'");
   }

   string joined = JoinStrings(strings, separator);
   if (!StringLen(joined))
      return("");
   return(StringConcatenate("{", joined, "}"));
}


/**
 * Konvertiert ein Integer-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  int    values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string IntsToStr(int values[][], string separator=", ") {
   return(__IntsToStr(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string __IntsToStr(int values2[][], int values3[][][], string separator) {
   if (separator == "0")      // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result;


   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinInts(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      int       valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = IntsToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      int       valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = IntsToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("__IntsToStr()   too many dimensions of parameter values = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String.
 *
 * @param  int    tickets[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_empty(catch("TicketsToStr(1)   illegal dimensions of parameter tickets = "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   if (ArraySize(tickets) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   return(StringConcatenate("{#", JoinInts(tickets, separator +"#"), "}"));
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.Lots(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_empty(catch("TicketsToStr.Lots(1)   illegal dimensions of parameter tickets = "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[]; ArrayResize(strings, ticketsSize);

   OrderPush("TicketsToStr.Lots(2)");

   for (int i=0; i < ticketsSize; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if (IsLongTradeOperation(OrderType())) {
               strings[i] = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"));
               continue;
            }
            if (IsShortTradeOperation(OrderType())) {
               strings[i] = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"));
               continue;
            }
         }
         else GetLastError();
      }
      strings[i] = StringConcatenate("#", tickets[i], ":error");
   }

   OrderPop("TicketsToStr.Lots(3)");

   string result = StringConcatenate("{", JoinStrings(strings, separator), "}");
   ArrayResize(strings, 0);
   return(result);
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize und das Symbol des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.LotsSymbols(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_empty(catch("TicketsToStr.LotsSymbols(1)   illegal dimensions of parameter tickets = "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[]; ArrayResize(strings, ticketsSize);

   OrderPush("TicketsToStr.LotsSymbols(2)");

   for (int i=0; i < ticketsSize; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if (IsLongTradeOperation(OrderType())) {
               strings[i] = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
               continue;
            }
            if (IsShortTradeOperation(OrderType())) {
               strings[i] = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
               continue;
            }
         }
         else GetLastError();
      }
      strings[i] = StringConcatenate("#", tickets[i], ":error");
   }

   OrderPop("TicketsToStr.LotsSymbols(3)");

   string result = StringConcatenate("{", JoinStrings(strings, separator), "}");
   ArrayResize(strings, 0);
   return(result);
}


/**
 * Konvertiert ein Boolean-Array mit bis zu 3 Dimensionen in einen lesbaren String.
 *
 * @param  bool   values[]
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string BoolsToStr(bool values[][], string separator=", ") {
   return(__BoolsToStr(values, values, separator));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
private*/string __BoolsToStr(bool values2[][], bool values3[][][], string separator) {
   if (separator == "0")      // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;

   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinBools(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValuesX[]; ArrayResize(strValuesX, dim1);
      bool      valuesY[]; ArrayResize(   valuesY, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            valuesY[y] = values2[x][y];
         }
         strValuesX[x] = BoolsToStr(valuesY, separator);
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
                           ArrayResize(strValuesX, dim1);
      string strValuesY[]; ArrayResize(strValuesY, dim2);
      bool      valuesZ[]; ArrayResize(   valuesZ, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               valuesZ[z] = values3[x][y][z];
            }
            strValuesY[y] = BoolsToStr(valuesZ, separator);
         }
         strValuesX[x] = StringConcatenate("{", JoinStrings(strValuesY, separator), "}");
      }
      return(StringConcatenate("{", JoinStrings(strValuesX, separator), "}"));
   }

   return(_empty(catch("__BoolsToStr()   too many dimensions of parameter values = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Speichert Remote-Positionsdaten in der Library oder restauriert sie aus bereits in der Library gespeicherten Daten.
 *
 * @param  bool   store     - Richtung: TRUE = kopiert aus den Parametern in die Library; FALSE = kopiert aus der Library in die Parameter
 * @param  string symbol [] - Symbol des Instruments der kopierten Daten
 * @param  int    tickets[]
 * @param  int    types  []
 * @param  double data   []
 *
 * @return int - Fehlerstatus
 */
int ChartInfos.CopyRemotePositions(bool store, string &symbol[], int tickets[], int types[][], double data[][]) {
   static string static.symbol [1];
   static int    static.tickets[];
   static int    static.types  [][2];
   static double static.data   [][4];

   if (store) {
      static.symbol[0] = symbol[0];
      ArrayResize(static.tickets, 0);
      ArrayResize(static.types,   0);
      ArrayResize(static.data,    0);
      if (ArrayRange(tickets, 0) > 0) {
         ArrayCopy(static.tickets, tickets);
         ArrayCopy(static.types,   types  );
         ArrayCopy(static.data,    data   );
      }
   }
   else {
      symbol[0] = static.symbol[0];
      ArrayResize(tickets, 0);
      ArrayResize(types,   0);
      ArrayResize(data,    0);
      if (ArrayRange(static.tickets, 0) > 0) {
         ArrayCopy(tickets, static.tickets);
         ArrayCopy(types,   static.types  );
         ArrayCopy(data,    static.data   );
      }
   }
   return(catch("ChartInfos.CopyRemotePositions()"));
}


/**
 * Speichert LFX-Orderdaten in der Library oder restauriert sie aus bereits in der Library gespeicherten Daten.
 *
 * @param  bool   store    - Richtung: TRUE = kopiert aus den Parametern in die Library; FALSE = kopiert aus der Library in die Parameter
 * @param  string symbol[] - Symbol des Instruments der kopierten Daten
 * @param  int    los   []
 *
 * @return int - Fehlerstatus
 */
int ChartInfos.CopyLfxOrders(bool store, string &symbol[], /*LFX_ORDER*/int los[][]) {
   static string static.symbol[1];
   static int    static.los [][LFX_ORDER.intSize];

   if (store) {
      static.symbol[0] = symbol[0];
      ArrayResize(static.los, 0);
      if (ArrayRange(los, 0) > 0)
         ArrayCopy(static.los, los);
   }
   else {
      symbol[0] = static.symbol[0];
      ArrayResize(los, 0);
      if (ArrayRange(static.los, 0) > 0)
         ArrayCopy(los, static.los);
   }
   return(catch("ChartInfos.CopyLfxOrders()"));
}


/**
 * Wird nur im Tester in library::init() aufgerufen, um alle verwendeten globalen Arrays zurücksetzen zu können (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);
}
