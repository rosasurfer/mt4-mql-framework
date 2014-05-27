/**
 * MQL structure BAR. Eingeführt in Anlehnung an und zur Vereinfachung von RATE_INFO. Die Typen sind einheitlich, die Kursreihenfolge ist OHLC.
 *
 *                          size         offset
 * struct BAR {             ----         ------
 *   double time;             8        double[0]      // BarOpen-Time, immer Ganzzahl
 *   double open;             8        double[1]
 *   double high;             8        double[2]
 *   double low;              8        double[3]
 *   double close;            8        double[4]
 *   double volume;           8        double[5]      // immer Ganzzahl
 * } bar;                  = 48 byte = double[6]
 *
 *
 * @see  Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */
