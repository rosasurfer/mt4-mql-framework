/**
 * Framework struct BAR. MQL-Darstellung des MT4 struct HISTORY_BAR_400. Der Datentyp der Elemente ist einheitlich,
 * die Kursreihenfolge ist wie in HISTORY_BAR_400 OLHC.
 *
 *                          size          offset
 * struct BAR {             ----          ------
 *   double time;             8        double[0]      // BarOpen-Time, immer Ganzzahl
 *   double open;             8        double[1]
 *   double low;              8        double[2]
 *   double high;             8        double[3]
 *   double close;            8        double[4]
 *   double volume;           8        double[5]      // immer Ganzzahl
 * };                      = 48 byte = double[6]
 *
 *
 * Note: Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */
#define BAR.time        0
#define BAR.open        1
#define BAR.low         2
#define BAR.high        3
#define BAR.close       4
#define BAR.volume      5


// Getter
datetime bar.Time      (/*BAR*/double bar[]         ) { return(bar[BAR.time  ]);                                       BAR.toStr(bar); }
double   bar.Open      (/*BAR*/double bar[]         ) { return(bar[BAR.open  ]);                                       BAR.toStr(bar); }
double   bar.Low       (/*BAR*/double bar[]         ) { return(bar[BAR.low   ]);                                       BAR.toStr(bar); }
double   bar.High      (/*BAR*/double bar[]         ) { return(bar[BAR.high  ]);                                       BAR.toStr(bar); }
double   bar.Close     (/*BAR*/double bar[]         ) { return(bar[BAR.close ]);                                       BAR.toStr(bar); }
int      bar.Volume    (/*BAR*/double bar[]         ) { return(bar[BAR.volume]);                                       BAR.toStr(bar); }

datetime bars.Time     (/*BAR*/double bar[][], int i) { return(bar[i][BAR.time  ]);                                    BAR.toStr(bar); }
double   bars.Open     (/*BAR*/double bar[][], int i) { return(bar[i][BAR.open  ]);                                    BAR.toStr(bar); }
double   bars.Low      (/*BAR*/double bar[][], int i) { return(bar[i][BAR.low   ]);                                    BAR.toStr(bar); }
double   bars.High     (/*BAR*/double bar[][], int i) { return(bar[i][BAR.high  ]);                                    BAR.toStr(bar); }
double   bars.Close    (/*BAR*/double bar[][], int i) { return(bar[i][BAR.close ]);                                    BAR.toStr(bar); }
int      bars.Volume   (/*BAR*/double bar[][], int i) { return(bar[i][BAR.volume]);                                    BAR.toStr(bar); }


// Setter
datetime bar.setTime   (/*BAR*/double &bar[],          datetime time  ) {    bar[BAR.time  ] = time;   return(time  ); BAR.toStr(bar); }
double   bar.setOpen   (/*BAR*/double &bar[],          double   open  ) {    bar[BAR.open  ] = open;   return(open  ); BAR.toStr(bar); }
double   bar.setLow    (/*BAR*/double &bar[],          double   low   ) {    bar[BAR.low   ] = low;    return(low   ); BAR.toStr(bar); }
double   bar.setHigh   (/*BAR*/double &bar[],          double   high  ) {    bar[BAR.high  ] = high;   return(high  ); BAR.toStr(bar); }
double   bar.setClose  (/*BAR*/double &bar[],          double   close ) {    bar[BAR.close ] = close;  return(close ); BAR.toStr(bar); }
int      bar.setVolume (/*BAR*/double &bar[],          int      volume) {    bar[BAR.volume] = volume; return(volume); BAR.toStr(bar); }

datetime bars.setTime  (/*BAR*/double &bar[][], int i, datetime time  ) { bar[i][BAR.time  ] = time;   return(time  ); BAR.toStr(bar); }
double   bars.setOpen  (/*BAR*/double &bar[][], int i, double   open  ) { bar[i][BAR.open  ] = open;   return(open  ); BAR.toStr(bar); }
double   bars.setLow   (/*BAR*/double &bar[][], int i, double   low   ) { bar[i][BAR.low   ] = low;    return(low   ); BAR.toStr(bar); }
double   bars.setHigh  (/*BAR*/double &bar[][], int i, double   high  ) { bar[i][BAR.high  ] = high;   return(high  ); BAR.toStr(bar); }
double   bars.setClose (/*BAR*/double &bar[][], int i, double   close ) { bar[i][BAR.close ] = close;  return(close ); BAR.toStr(bar); }
int      bars.setVolume(/*BAR*/double &bar[][], int i, int      volume) { bar[i][BAR.volume] = volume; return(volume); BAR.toStr(bar); }


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer struct BAR zurück.
 *
 * @param  double bar[] - struct BAR
 *
 * @return string - lesbarer String oder Leerstring, falls ein Fehler auftrat
 */
string BAR.toStr(/*BAR*/double bar[]) {
   int dimensions = ArrayDimension(bar);
   if (dimensions > 2)                                  return(_EMPTY_STR(catch("BAR.toStr(1)  too many dimensions of parameter bar: "+ dimensions, ERR_INVALID_PARAMETER)));
   if (ArrayRange(bar, dimensions-1) != BAR_doubleSize) return(_EMPTY_STR(catch("BAR.toStr(2)  invalid size of parameter bar ("+ ArrayRange(bar, dimensions-1) +")", ERR_INVALID_PARAMETER)));

   string line="", lines[]; ArrayResize(lines, 0);


   if (dimensions == 1) {
      // bar ist einzelnes Struct BAR (eine Dimension)
      line = StringConcatenate("{time="  ,   ifString(!bar.Time  (bar), "0", "'"+ TimeToStr(bar.Time(bar), TIME_FULL) +"'"),
                              ", open="  , NumberToStr(bar.Open  (bar), ".+"),
                              ", high="  , NumberToStr(bar.High  (bar), ".+"),
                              ", low="   , NumberToStr(bar.Low   (bar), ".+"),
                              ", close=" , NumberToStr(bar.Close (bar), ".+"),
                              ", volume=",             bar.Volume(bar), "}");
      ArrayPushString(lines, line);
   }
   else {
      // bar ist Struct-Array BAR[] (zwei Dimensionen)
      int size = ArrayRange(bar, 0);

      for (int i=0; i < size; i++) {
         line = StringConcatenate("[", i, "]={time="  ,   ifString(!bars.Time  (bar, i), "0", "'"+ TimeToStr(bars.Time(bar, i), TIME_FULL) +"'"),
                                           ", open="  , NumberToStr(bars.Open  (bar, i), ".+"),
                                           ", high="  , NumberToStr(bars.High  (bar, i), ".+"),
                                           ", low="   , NumberToStr(bars.Low   (bar, i), ".+"),
                                           ", close=" , NumberToStr(bars.Close (bar, i), ".+"),
                                           ", volume=",             bars.Volume(bar, i), "}");
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("BAR.toStr(1)");
   return(output);

   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   bar.Time     (bar);       bars.Time     (bar, NULL);
   bar.Open     (bar);       bars.Open     (bar, NULL);
   bar.Low      (bar);       bars.Low      (bar, NULL);
   bar.High     (bar);       bars.High     (bar, NULL);
   bar.Close    (bar);       bars.Close    (bar, NULL);
   bar.Volume   (bar);       bars.Volume   (bar, NULL);

   bar.setTime  (bar, NULL); bars.setTime  (bar, NULL, NULL);
   bar.setOpen  (bar, NULL); bars.setOpen  (bar, NULL, NULL);
   bar.setLow   (bar, NULL); bars.setLow   (bar, NULL, NULL);
   bar.setHigh  (bar, NULL); bars.setHigh  (bar, NULL, NULL);
   bar.setClose (bar, NULL); bars.setClose (bar, NULL, NULL);
   bar.setVolume(bar, NULL); bars.setVolume(bar, NULL, NULL);
}
