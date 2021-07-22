/**
 *
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinInts.mqh>
#include <functions/JoinDoubles.mqh>
#include <functions/JoinDoublesEx.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLibs.mqh>


/**
 * Faßt die einzelnen Werte eines String-Arrays in doppelte Anführungszeichen ein. Nicht initialisierte Strings (NULL-Pointer) bleiben
 * unverändert.
 *
 * @param  string values[]
 *
 * @return bool - Erfolgsstatus
 */
bool DoubleQuoteStrings(string &values[]) {
   if (ArrayDimension(values) > 1) return(!catch("DoubleQuoteStrings(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS));

   int size = ArraySize(values);

   for (int i=0; i < size; i++) {
      if (!StrIsNull(values[i]))                                     // NULL-Werte bleiben unverändert
         values[i] = StringConcatenate("\"", values[i], "\"");
   }
   return(true);
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
      return(_EMPTY_STR(catch("RatesToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

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
      return(_EMPTY_STR(catch("MoneysToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(values);
   if (ArraySize(values) == 0)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string strings[];
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = DoubleToStr(values[i], 2);
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
      return(_EMPTY_STR(catch("iBufferToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @access private - Aufruf nur aus DoublesToStr()
 */
string __DoublesToStr(double values2[][], double values3[][][], string separator) {
   if (separator == "0")                                             // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result;


   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoubles(values2, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValues2.X[]; ArrayResize(strValues2.X, dim1);
      double    values2.Y[]; ArrayResize(   values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         strValues2.X[x] = DoublesToStr(values2.Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(strValues2.X, separator), "}");
      ArrayResize(strValues2.X, 0);
      ArrayResize(   values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
      string strValues3.X[]; ArrayResize(strValues3.X, dim1);
      string strValues3.Y[]; ArrayResize(strValues3.Y, dim2);
      double    values3.Z[]; ArrayResize(   values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            strValues3.Y[y] = DoublesToStr(values3.Z, separator);
         }
         strValues3.X[x] = StringConcatenate("{", JoinStrings(strValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(strValues3.X, separator), "}");
      ArrayResize(strValues3.X, 0);
      ArrayResize(strValues3.Y, 0);
      ArrayResize(   values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__DoublesToStr()  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein Doubles-Array mit bis zu 3 Dimensionen in einen lesbaren String. Die Werte können mit bis zu 16 Nachkommastellen
 * angezeigt werden.
 *
 * @param  double values[]  - zu konvertierende Werte
 * @param  string separator - Separator (default: NULL = ", ")
 * @param  int    digits    - Anzahl der Nachkommastellen (0-16)
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string DoublesToStrEx(double values[][], string separator, int digits) {
   return(__DoublesToStrEx(values, values, separator, digits));
}


/**
 * Interne Hilfsfunktion (Workaround um Dimension-Check des Compilers)
 *
 * @access private - Aufruf nur aus DoublesToStrEx()
 */
string __DoublesToStrEx(double values2[][], double values3[][][], string separator, int digits) {
   if (digits < 0 || digits > 16)
      return(_EMPTY_STR(catch("__DoublesToStrEx(1)  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER)));

   if (separator == "0")                                             // (string) NULL
      separator = ", ";

   int dimensions=ArrayDimension(values2), dim1=ArrayRange(values2, 0), dim2, dim3;
   string result;


   // 1-dimensionales Array
   if (dimensions == 1) {
      if (dim1 == 0)
         return("{}");
      return(StringConcatenate("{", JoinDoublesEx(values2, digits, separator), "}"));
   }
   else dim2 = ArrayRange(values2, 1);


   // 2-dimensionales Array
   if (dimensions == 2) {
      string strValues2.X[]; ArrayResize(strValues2.X, dim1);
      double    values2.Y[]; ArrayResize(   values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         strValues2.X[x] = DoublesToStrEx(values2.Y, separator, digits);
      }

      result = StringConcatenate("{", JoinStrings(strValues2.X, separator), "}");
      ArrayResize(strValues2.X, 0);
      ArrayResize(   values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
      string strValues3.X[]; ArrayResize(strValues3.X, dim1);
      string strValues3.Y[]; ArrayResize(strValues3.Y, dim2);
      double    values3.Z[]; ArrayResize(   values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            strValues3.Y[y] = DoublesToStrEx(values3.Z, separator, digits);
         }
         strValues3.X[x] = StringConcatenate("{", JoinStrings(strValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(strValues3.X, separator), "}");
      ArrayResize(strValues3.X, 0);
      ArrayResize(strValues3.Y, 0);
      ArrayResize(   values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__DoublesToStrEx(2)  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
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
      return(_EMPTY_STR(catch("TimesToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

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
      return(_EMPTY_STR(catch("OperationTypesToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

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
      return(_EMPTY_STR(catch("CharsToStr()  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

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
 * @access private - Aufruf nur aus IntsToStr()
 */
string __IntsToStr(int values2[][], int values3[][][], string separator) {
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
      string strValues2.X[]; ArrayResize(strValues2.X, dim1);
      int       values2.Y[]; ArrayResize(   values2.Y, dim2);

      for (int x=0; x < dim1; x++) {
         for (int y=0; y < dim2; y++) {
            values2.Y[y] = values2[x][y];
         }
         strValues2.X[x] = IntsToStr(values2.Y, separator);
      }

      result = StringConcatenate("{", JoinStrings(strValues2.X, separator), "}");
      ArrayResize(strValues2.X, 0);
      ArrayResize(   values2.Y, 0);
      return(result);
   }
   else dim3 = ArrayRange(values3, 2);


   // 3-dimensionales Array
   if (dimensions == 3) {
      string strValues3.X[]; ArrayResize(strValues3.X, dim1);
      string strValues3.Y[]; ArrayResize(strValues3.Y, dim2);
      int       values3.Z[]; ArrayResize(   values3.Z, dim3);

      for (x=0; x < dim1; x++) {
         for (y=0; y < dim2; y++) {
            for (int z=0; z < dim3; z++) {
               values3.Z[z] = values3[x][y][z];
            }
            strValues3.Y[y] = IntsToStr(values3.Z, separator);
         }
         strValues3.X[x] = StringConcatenate("{", JoinStrings(strValues3.Y, separator), "}");
      }

      result = StringConcatenate("{", JoinStrings(strValues3.X, separator), "}");
      ArrayResize(strValues3.X, 0);
      ArrayResize(strValues3.Y, 0);
      ArrayResize(   values3.Z, 0);
      return(result);
   }

   return(_EMPTY_STR(catch("__IntsToStr(1)  too many dimensions of parameter values: "+ dimensions, ERR_INCOMPATIBLE_ARRAYS)));
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[] - für Tickets ungültige Werte werden entsprechend dargestellt
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.Lots(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.Lots(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(tickets);
   if (!size)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string result, sValue;

   OrderPush("TicketsToStr.Lots(2)");

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"));
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"));
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.Lots(3)");

   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize und das Symbol des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[] - für Tickets ungültige Werte werden entsprechend dargestellt
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.LotsSymbols(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.LotsSymbols(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(tickets);
   if (!size)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string result, sValue;

   OrderPush("TicketsToStr.LotsSymbols(2)");

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.LotsSymbols(3)");

   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Ermittelt die Gesamtposition der Tickets eines Arrays und gibt sie als einen lesbaren String zurück.
 *
 * @param  int tickets[]
 *
 * @return string - String mit Gesamtposition oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.Position(int tickets[]) {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.Position(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return("(empty)");

   double long, short, total, hedged;

   OrderPush("TicketsToStr.Position(2)");

   for (int i=0; i < ticketsSize; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if (IsLongOrderType(OrderType())) long  += OrderLots();
            else                              short += OrderLots();
         }
         else GetLastError();
      }
   }

   OrderPop("TicketsToStr.Position(3)");

   long   = NormalizeDouble(long,  2);
   short  = NormalizeDouble(short, 2);
   total  = NormalizeDouble(long - short, 2);
   hedged = MathMin(long, short);
   bool isPosition = long || short;

   string result;
   if (!isPosition) result = "(none)";
   else if (!total) result = "±"+ NumberToStr(long,  ".+")                                                          +" lots (hedged)";
   else             result =      NumberToStr(total, ".+") + ifString(!hedged, "", " ±"+ NumberToStr(hedged, ".+")) +" lots";

   return(result);
}


/**
 * Speichert LFX-Orderdaten in der Library oder restauriert sie aus in der Library gespeicherten Daten.
 *
 * @param  _In_     bool   store    - Richtung: TRUE  = kopiert aus den Parametern in die Library;
 *                                              FALSE = kopiert aus der Library in die Parameter
 * @param  _InOut_ int    orders[] - LFX-Orders
 * @param  _InOut_ int    iData [] - Integer-Daten
 * @param  _InOut_ bool   bData [] - Boolean-Daten
 * @param  _InOut_ double dData [] - Double-Daten
 *
 * @return int - Anzahl der kopierten Orders oder EMPTY (-1), falls ein Fehler auftrat
 */
int ChartInfos.CopyLfxOrders(bool store, /*LFX_ORDER*/int orders[][], int iData[][], bool bData[][], double dData[][]) {
   store = store!=0;

   static int    static.orders[][LFX_ORDER.intSize];
   static int    static.iData [][1];
   static bool   static.bData [][3];
   static double static.dData [][7];

   if (store) {
      ArrayResize(static.orders, 0);
      ArrayResize(static.iData,  0);
      ArrayResize(static.bData,  0);
      ArrayResize(static.dData,  0);

      if (ArrayRange(orders, 0) > 0) ArrayCopy(static.orders, orders);
      if (ArrayRange(iData,  0) > 0) ArrayCopy(static.iData,  iData );
      if (ArrayRange(bData,  0) > 0) ArrayCopy(static.bData,  bData );
      if (ArrayRange(dData,  0) > 0) ArrayCopy(static.dData,  dData );

      if (IsError(catch("ChartInfos.CopyLfxOrders(1)")))
         return(EMPTY);
   }
   else {
      ArrayResize(orders, 0);
      ArrayResize(iData,  0);
      ArrayResize(bData,  0);
      ArrayResize(dData,  0);

      if (ArrayRange(static.orders, 0) > 0) ArrayCopy(orders, static.orders);
      if (ArrayRange(static.iData,  0) > 0) ArrayCopy(iData,  static.iData );
      if (ArrayRange(static.bData,  0) > 0) ArrayCopy(bData,  static.bData );
      if (ArrayRange(static.dData,  0) > 0) ArrayCopy(dData,  static.dData );

      if (IsError(catch("ChartInfos.CopyLfxOrders(2)")))
         return(EMPTY);
   }

   return(ArrayRange(orders, 0));
}


/**
 * Fügt an einem Offset eines zwei-dimensionalen Double-Arrays ein anderes Double-Array ein.
 *
 * @param  double array[][] - zu vergrößerndes zwei-dimensionales Ausgangs-Array
 * @param  int    offset    - Position im Ausgangs-Array, an dem das andere Array eingefügt werden soll
 * @param  double values[]  - einzufügendes Array (muß in seiner ersten Dimension der zweiten Dimension des Ausgangsarrays entsprechen)
 *
 * @return int - neue Größe des Ausgangsarrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertDoubleArray(double array[][], int offset, double values[]) {
   if (ArrayDimension(array) != 2)         return(catch("ArrayInsertDoubleArray(1)  illegal dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));
   if (ArrayDimension(values) != 1)        return(catch("ArrayInsertDoubleArray(2)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS));
   int array.dim1 = ArrayRange(array, 0);
   int array.dim2 = ArrayRange(array, 1);
   if (ArraySize(values) != array.dim2)    return(catch("ArrayInsertDoubleArray(3)  array size mis-match of parameters array and values: array["+ array.dim1 +"]["+ array.dim2 +"] / values["+ ArraySize(values) +"]", ERR_INCOMPATIBLE_ARRAYS));
   if (offset < 0 || offset >= array.dim1) return(catch("ArrayInsertDoubleArray(4)  illegal parameter offset: "+ offset, ERR_INVALID_PARAMETER));

   // Ausgangsarray vergrößern
   int newSize = array.dim1 + 1;
   ArrayResize(array, newSize);

   // Inhalt des Ausgangsarrays von offset nach hinten verschieben
   int array.dim2.size = array.dim2 * DOUBLE_VALUE;
   int src   = GetDoublesAddress(array) + offset * array.dim2.size;
   int dest  =                               src + array.dim2.size;
   int bytes =               (array.dim1-offset) * array.dim2.size;
   CopyMemory(dest, src, bytes);

   // Inhalt des anderen Arrays an den gewünschten Offset schreiben
   dest  = src;
   src   = GetDoublesAddress(values);
   bytes = array.dim2.size;
   CopyMemory(dest, src, bytes);

   return(newSize);
}


/**
 * Fügt ein Element an der angegebenen Position eines String-Arrays ein.
 *
 * @param  string array[] - String-Array
 * @param  int    offset  - Position, an dem das Element eingefügt werden soll
 * @param  string value   - einzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (nEMPTY), falls ein Fehler auftrat
 */
int ArrayInsertString(string &array[], int offset, string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayInsertString(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                return(_EMPTY(catch("ArrayInsertString(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int size = ArraySize(array);
   if (size < offset)             return(_EMPTY(catch("ArrayInsertString(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ size +")", ERR_INVALID_PARAMETER)));

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(ArrayUnshiftString(array, value));

   // Einfügen am Ende des Arrays
   if (offset == size)
      return(ArrayPushString(array, value));

   // Einfügen innerhalb des Arrays: ArrayCopy() "zerstört" bei String-Arrays den sich überlappenden Bereich, daher zusätzliche Kopie nötig
   string tmp[]; ArrayResize(tmp, 0);
   ArrayCopy(tmp, array, 0, offset, size-offset);                                // Kopie der Elemente hinterm Einfügepunkt machen
   ArrayCopy(array, tmp, offset+1);                                              // Elemente hinterm Einfügepunkt nach hinten schieben (Quelle: die Kopie)
   ArrayResize(tmp, 0);
   array[offset] = value;                                                        // Lücke mit einzufügendem Wert füllen
   return(size + 1);
}


/**
 * Fügt in ein String-Array die Elemente eines anderen String-Arrays ein.
 *
 * @param  string array[]  - Ausgangs-Array
 * @param  int    offset   - Position im Ausgangs-Array, an dem die Elemente eingefügt werden sollen
 * @param  string values[] - einzufügende Elemente
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 */
int ArrayInsertStrings(string array[], int offset, string values[]) {
   if (ArrayDimension(array) > 1)  return(_EMPTY(catch("ArrayInsertStrings(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));
   if (offset < 0)                 return(_EMPTY(catch("ArrayInsertStrings(2)  invalid parameter offset: "+ offset, ERR_INVALID_PARAMETER)));
   int sizeOfArray = ArraySize(array);
   if (sizeOfArray < offset)       return(_EMPTY(catch("ArrayInsertStrings(3)  invalid parameter offset: "+ offset +" (sizeOf(array) = "+ sizeOfArray +")", ERR_INVALID_PARAMETER)));
   if (ArrayDimension(values) > 1) return(_EMPTY(catch("ArrayInsertStrings(4)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));
   int sizeOfValues = ArraySize(values);

   // Einfügen am Anfang des Arrays
   if (offset == 0)
      return(MergeStringArrays(values, array, array));

   // Einfügen am Ende des Arrays
   if (offset == sizeOfArray)
      return(MergeStringArrays(array, values, array));

   // Einfügen innerhalb des Arrays
   int newSize = sizeOfArray + sizeOfValues;
   ArrayResize(array, newSize);

   // ArrayCopy() "zerstört" bei String-Arrays den sich überlappenden Bereich, wir müssen mit einer zusätzlichen Kopie arbeiten
   string tmp[]; ArrayResize(tmp, 0);
   ArrayCopy(tmp, array, 0, offset, sizeOfArray-offset);                         // Kopie der Elemente hinter dem Einfügepunkt erstellen
   ArrayCopy(array, tmp, offset+sizeOfValues);                                   // Elemente hinter dem Einfügepunkt nach hinten schieben
   ArrayCopy(array, values, offset);                                             // Lücke mit einzufügenden Werten überschreiben

   ArrayResize(tmp, 0);
   return(newSize);
}


/**
 * Sortiert die übergebenen Ticketdaten nach {OpenTime, Ticket}.
 *
 * @param  int tickets[] - Array mit Ticketdaten
 *
 * @return bool - Erfolgsstatus
 */
bool SortOpenTickets(int tickets[][/*{OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 2) return(!catch("SortOpenTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2)
      return(true);                                                  // weniger als 2 Zeilen

   // Zeilen nach OpenTime sortieren
   ArraySort(tickets);

   // Zeilen mit gleicher OpenTime zusätzlich nach Ticket sortieren
   int openTime, lastOpenTime, ticket, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);

   for (int i=0, n; i < rows; i++) {
      openTime = tickets[i][0];
      ticket   = tickets[i][1];

      if (openTime == lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // in sameOpenTimes[] angesammelte Zeilen von keys[] nach Ticket sortieren
         if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
            return(false);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in keys[]

      lastOpenTime = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
         return(false);
      n = 0;
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortOpenTickets(2)"));
}


/**
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach Ticket. Die OpenTime-Felder dieser Zeilen sind gleich
 * und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private
 */
bool __SOT.SameOpenTimes(int &ticketData[][/*{OpenTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   // Originaldaten mit den sortierten Werten überschreiben
   for (int i, n=0; n < rows; n++) {
      i                = rowsToSort[n][1];
      ticketData[i][1] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SOT.SameOpenTimes(1)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach {CloseTime, OpenTime, Ticket}.
 *
 * @param  int tickets[] - Array mit Ticketdaten
 *
 * @return bool - Erfolgsstatus
 */
bool SortClosedTickets(int tickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 3) return(!catch("SortClosedTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2)
      return(true);                                                  // single row, nothing to do


   // (1) alle Zeilen nach CloseTime sortieren
   ArraySort(tickets);


   // (2) Zeilen mit gleicher CloseTime zusätzlich nach OpenTime sortieren
   int closeTime, openTime, ticket, lastCloseTime, sameCloseTimes[][3];
   ArrayResize(sameCloseTimes, 1);

   for (int n, i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime == lastCloseTime) {
         n++;
         ArrayResize(sameCloseTimes, n+1);
      }
      else if (n > 0) {
         // in sameCloseTimes[] angesammelte Zeilen von tickets[] nach OpenTime sortieren
         __SCT.SameCloseTimes(tickets, sameCloseTimes);
         ArrayResize(sameCloseTimes, 1);
         n = 0;
      }
      sameCloseTimes[n][0] = openTime;
      sameCloseTimes[n][1] = ticket;
      sameCloseTimes[n][2] = i;                                      // Originalposition der Zeile in keys[]

      lastCloseTime = closeTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloseTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameCloseTimes(tickets, sameCloseTimes);
      n = 0;
   }
   ArrayResize(sameCloseTimes, 0);


   // (3) Zeilen mit gleicher Close- und OpenTime zusätzlich nach Ticket sortieren
   int lastOpenTime, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);
   lastCloseTime = 0;

   for (i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime==lastCloseTime && openTime==lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // in sameOpenTimes[] angesammelte Zeilen von tickets[] nach Ticket sortieren
         __SCT.SameOpenTimes(tickets, sameOpenTimes);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in tickets[]

      lastCloseTime = closeTime;
      lastOpenTime  = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameOpenTimes(tickets, sameOpenTimes);
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortClosedTickets(2)"));
}


/**
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach {OpenTime, Ticket}. Die CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private - Aufruf nur aus SortClosedTickets()
 */
bool __SCT.SameCloseTimes(int &ticketData[][/*{CloseTime, OpenTime, Ticket}*/], int rowsToSort[][/*{OpenTime, Ticket, i}*/]) {
   int rows.copy[][3]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach OpenTime sortieren
   ArraySort(rows.copy);

   // Original-Daten mit den sortierten Werten überschreiben
   int openTime, ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][2];
      ticketData[i][1] = rows.copy [n][0];
      ticketData[i][2] = rows.copy [n][1];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameCloseTimes(1)"));
}


/**
 * Sortiert die in rowsToSort[] angegebene Zeilen des Datenarrays ticketData[] nach {Ticket}. Die Open- und CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private - Aufruf nur aus SortClosedTickets()
 */
bool __SCT.SameOpenTimes(int &ticketData[][/*{OpenTime, CloseTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][1];
      ticketData[i][2] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameOpenTimes(1)"));
}


/**
 * Gibt die Laufzeit des Terminals seit Programmstart in Millisekunden zurück.
 *
 * @return int - Millisekunden seit Programmstart
 */
int GetTerminalRuntime() {
   /*FILETIME*/  int ft[], iNull[]; InitializeByteBuffer(ft, FILETIME.size  ); InitializeByteBuffer(iNull, FILETIME.size);
   /*SYSTEMTIME*/int st[];          InitializeByteBuffer(st, SYSTEMTIME.size);

   int creationTime[2], currentTime[2], hProcess=GetCurrentProcess();

   if (!GetProcessTimes(hProcess, ft, iNull, iNull, iNull)) return(catch("GetTerminalRuntime(1)->kernel32::GetProcessTimes()", ERR_WIN32_ERROR));
   if (!RtlTimeToSecondsSince1970(ft, creationTime))        return(catch("GetTerminalRuntime(2)->kernel32::RtlTimeToSecondsSince1970()", ERR_WIN32_ERROR));
   if (!FileTimeToSystemTime(ft, st))                       return(catch("GetTerminalRuntime(3)->kernel32::FileTimeToSystemTime()", ERR_WIN32_ERROR));
   creationTime[1] = st_Milliseconds(st);

   GetSystemTime(st);
   if (!SystemTimeToFileTime(st, ft))                       return(catch("GetTerminalRuntime(4)->kernel32::SystemTimeToFileTime()", ERR_WIN32_ERROR));
   if (!RtlTimeToSecondsSince1970(ft, currentTime))         return(catch("GetTerminalRuntime(5)->ntdll.dll::RtlTimeToSecondsSince1970()", ERR_WIN32_ERROR));
   currentTime[1] = st_Milliseconds(st);

   int secDiff  = currentTime[0] - creationTime[0];                  // Sekunden
   int mSecDiff = currentTime[1] - creationTime[1];                  // Millisekunden
   if (mSecDiff < 0)
      mSecDiff += 1000;
   int runtime  = secDiff * 1000 + mSecDiff;                         // Gesamtlaufzeit in Millisekunden

   return(runtime);
}


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
}


#import "rsfMT4Expander.dll"
   int  st_Milliseconds(/*SYSTEMTIME*/int st[]);

#import "kernel32.dll"
   bool FileTimeToSystemTime(int lpFileTime[], int lpSystemTime[]);
   int  GetCurrentProcess();
   bool GetProcessTimes(int hProcess, int lpCreationTime[], int lpExitTime[], int lpKernelTime[], int lpUserTime[]);
   void GetSystemTime(int lpSystemTime[]);
   bool SystemTimeToFileTime(int lpSystemTime[], int lpFileTime[]);

#import "ntdll.dll"
   bool RtlTimeToSecondsSince1970(int lpTime[], int lpElapsedSeconds[]);
#import
