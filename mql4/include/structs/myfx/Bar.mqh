/**
 * MQL-Structure BAR. MQL-Darstellung der MT4-Structure HISTORY_BAR_400. Der Datentyp der Elemente ist einheitlich,
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
#define I_BAR.time         0
#define I_BAR.open         1
#define I_BAR.low          2
#define I_BAR.high         3
#define I_BAR.close        4
#define I_BAR.volume       5


// Getter
datetime bar.Time      (/*BAR*/double bar[]         ) { return(bar[I_BAR.time  ]);                                       BAR.toStr(bar); }
double   bar.Open      (/*BAR*/double bar[]         ) { return(bar[I_BAR.open  ]);                                       BAR.toStr(bar); }
double   bar.Low       (/*BAR*/double bar[]         ) { return(bar[I_BAR.low   ]);                                       BAR.toStr(bar); }
double   bar.High      (/*BAR*/double bar[]         ) { return(bar[I_BAR.high  ]);                                       BAR.toStr(bar); }
double   bar.Close     (/*BAR*/double bar[]         ) { return(bar[I_BAR.close ]);                                       BAR.toStr(bar); }
int      bar.Volume    (/*BAR*/double bar[]         ) { return(bar[I_BAR.volume]);                                       BAR.toStr(bar); }

datetime bars.Time     (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.time  ]);                                    BAR.toStr(bar); }
double   bars.Open     (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.open  ]);                                    BAR.toStr(bar); }
double   bars.Low      (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.low   ]);                                    BAR.toStr(bar); }
double   bars.High     (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.high  ]);                                    BAR.toStr(bar); }
double   bars.Close    (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.close ]);                                    BAR.toStr(bar); }
int      bars.Volume   (/*BAR*/double bar[][], int i) { return(bar[i][I_BAR.volume]);                                    BAR.toStr(bar); }


// Setter
datetime bar.setTime   (/*BAR*/double &bar[],          datetime time  ) {    bar[I_BAR.time  ] = time;   return(time  ); BAR.toStr(bar); }
double   bar.setOpen   (/*BAR*/double &bar[],          double   open  ) {    bar[I_BAR.open  ] = open;   return(open  ); BAR.toStr(bar); }
double   bar.setLow    (/*BAR*/double &bar[],          double   low   ) {    bar[I_BAR.low   ] = low;    return(low   ); BAR.toStr(bar); }
double   bar.setHigh   (/*BAR*/double &bar[],          double   high  ) {    bar[I_BAR.high  ] = high;   return(high  ); BAR.toStr(bar); }
double   bar.setClose  (/*BAR*/double &bar[],          double   close ) {    bar[I_BAR.close ] = close;  return(close ); BAR.toStr(bar); }
int      bar.setVolume (/*BAR*/double &bar[],          int      volume) {    bar[I_BAR.volume] = volume; return(volume); BAR.toStr(bar); }

datetime bars.setTime  (/*BAR*/double &bar[][], int i, datetime time  ) { bar[i][I_BAR.time  ] = time;   return(time  ); BAR.toStr(bar); }
double   bars.setOpen  (/*BAR*/double &bar[][], int i, double   open  ) { bar[i][I_BAR.open  ] = open;   return(open  ); BAR.toStr(bar); }
double   bars.setLow   (/*BAR*/double &bar[][], int i, double   low   ) { bar[i][I_BAR.low   ] = low;    return(low   ); BAR.toStr(bar); }
double   bars.setHigh  (/*BAR*/double &bar[][], int i, double   high  ) { bar[i][I_BAR.high  ] = high;   return(high  ); BAR.toStr(bar); }
double   bars.setClose (/*BAR*/double &bar[][], int i, double   close ) { bar[i][I_BAR.close ] = close;  return(close ); BAR.toStr(bar); }
int      bars.setVolume(/*BAR*/double &bar[][], int i, int      volume) { bar[i][I_BAR.volume] = volume; return(volume); BAR.toStr(bar); }


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer BAR-Strukturen zurück.
 *
 * @param  double bar[]       - BAR
 * @param  bool   outputDebug - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string - lesbarer String oder Leerstring, falls ein Fehler auftrat
 */
string BAR.toStr(/*BAR*/double bar[], bool outputDebug=false) {
   outputDebug = outputDebug!=0;

   int dimensions = ArrayDimension(bar);
   if (dimensions > 2)                                  return(_EMPTY_STR(catch("BAR.toStr(1)  too many dimensions of parameter bar = "+ dimensions, ERR_INVALID_PARAMETER)));
   if (ArrayRange(bar, dimensions-1) != BAR.doubleSize) return(_EMPTY_STR(catch("BAR.toStr(2)  invalid size of parameter bar ("+ ArrayRange(bar, dimensions-1) +")", ERR_INVALID_PARAMETER)));

   string line, lines[]; ArrayResize(lines, 0);


   if (dimensions == 1) {
      // bar ist einzelnes Struct BAR (eine Dimension)
      line = StringConcatenate("{time="  ,   ifString(!bar.Time  (bar), "0", "'"+ TimeToStr(bar.Time(bar), TIME_FULL) +"'"),
                              ", open="  , NumberToStr(bar.Open  (bar), ".+"),
                              ", high="  , NumberToStr(bar.High  (bar), ".+"),
                              ", low="   , NumberToStr(bar.Low   (bar), ".+"),
                              ", close=" , NumberToStr(bar.Close (bar), ".+"),
                              ", volume=",             bar.Volume(bar), "}");
      if (outputDebug)
         debug("BAR.toStr()  "+ line);
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
         if (outputDebug)
            debug("BAR.toStr()  "+ line);
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("BAR.toStr(3)");
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


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "Expander.dll"
//   // Getter
//   datetime bar.Time      (/*BAR*/double bar[]);
//   double   bar.Open      (/*BAR*/double bar[]);
//   double   bar.Low       (/*BAR*/double bar[]);
//   double   bar.High      (/*BAR*/double bar[]);
//   double   bar.Close     (/*BAR*/double bar[]);
//   int      bar.Volume    (/*BAR*/double bar[]);

//   datetime bars.Time     (/*BAR*/double bar[][], int i);
//   double   bars.Open     (/*BAR*/double bar[][], int i);
//   double   bars.Low      (/*BAR*/double bar[][], int i);
//   double   bars.High     (/*BAR*/double bar[][], int i);
//   double   bars.Close    (/*BAR*/double bar[][], int i);
//   int      bars.Volume   (/*BAR*/double bar[][], int i);

//   // Setter
//   datetime bar.setTime   (/*BAR*/double bar[], datetime time  );
//   double   bar.setOpen   (/*BAR*/double bar[], double   open  );
//   double   bar.setLow    (/*BAR*/double bar[], double   low   );
//   double   bar.setHigh   (/*BAR*/double bar[], double   high  );
//   double   bar.setClose  (/*BAR*/double bar[], double   close );
//   int      bar.setVolume (/*BAR*/double bar[], int      volume);

//   datetime bars.setTime  (/*BAR*/double bar[][], int i, datetime time  );
//   double   bars.setOpen  (/*BAR*/double bar[][], int i, double   open  );
//   double   bars.setLow   (/*BAR*/double bar[][], int i, double   low   );
//   double   bars.setHigh  (/*BAR*/double bar[][], int i, double   high  );
//   double   bars.setClose (/*BAR*/double bar[][], int i, double   close );
//   int      bars.setVolume(/*BAR*/double bar[][], int i, int      volume);
//#import
