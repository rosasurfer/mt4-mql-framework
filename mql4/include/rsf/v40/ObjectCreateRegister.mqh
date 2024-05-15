
string __objects[];              // registered objects
int    __ojectsCounter = 0;      // sizeof(__objects)


/**
 * Create a chart object and register it for auto-removal on Program::deinit(). Function parameters are identical to the
 * built-in function ObjectCreate().
 *
 * @param  string   name              - unique object name (max. 63 chars, may contain line breaks)
 * @param  int      type              - object type identifier
 * @param  int      window [optional] - index of the chart window to create the object in (default: the main window)
 * @param  datetime time1  [optional] - time value of the first coordinate pair
 * @param  double   price1 [optional] - price value of the first coordinate pair
 * @param  datetime time2  [optional] - time value of the second coordinate pair
 * @param  double   price2 [optional] - price value of the second coordinate pair
 * @param  datetime time3  [optional] - time value of the third coordinate pair
 * @param  double   price3 [optional] - price value of the third coordinate pair
 *
 * @return bool - success status
 *
 *
 * TODO:
 *  - 106.000 initial calls on terminal start with 7 open charts
 *  - SuperBars in regular charts: permant non-stopping calls (after a few minutes more than 1.000.000)
 *  - SuperBars in offline charts: 271 calls on every tick
 *  - move elsewhere as the library is not a singleton (there can be multiple instances)
 */
bool ObjectCreateRegister(string name, int type, int window=0, datetime time1=NULL, double price1=NULL, datetime time2=NULL, double price2=NULL, datetime time3=NULL, double price3=NULL) {
   if (StringLen(name) > 63) return(!catch("ObjectCreateRegister(1)  invalid parameter name: \""+ name +"\" (max 63 chars)", ERR_INVALID_PARAMETER));

   // OBJ_VLINE         - Vertical line. Uses time of first coordinate pair.
   // OBJ_HLINE         - Horizontal line. Uses price of first coordinate pair.
   // OBJ_TREND         - Trend line. Uses 2 coordinate pairs.
   // OBJ_TRENDBYANGLE  - Trend by angle. Uses 1 coordinate pair.
   // OBJ_REGRESSION    - Regression. Uses times of first two coordinate pairs.
   // OBJ_CHANNEL       - Channel. Uses 3 coordinate pairs.
   // OBJ_STDDEVCHANNEL - Standard deviation channel. Uses times of first two coordinate pairs.
   // OBJ_GANNLINE      - Gann line. Uses 2 coordinate pairs, price of second pair is ignored.
   // OBJ_GANNFAN       - Gann fan. Uses 2 coordinate pairs, price of second pair is ignored.
   // OBJ_GANNGRID      - Gann grid. Uses 2 coordinate pairs, price of second pair is ignored.
   // OBJ_FIBO          - Fibonacci retracement. Uses 2 coordinate pairs.
   // OBJ_FIBOTIMES     - Fibonacci time zones. Uses 2 coordinate pairs.
   // OBJ_FIBOFAN       - Fibonacci fan. Uses 2 coordinate pairs.
   // OBJ_FIBOARC       - Fibonacci arcs. Uses 2 coordinate pairs.
   // OBJ_EXPANSION     - Fibonacci expansions. Uses 3 coordinate pairs.
   // OBJ_FIBOCHANNEL   - Fibonacci channel. Uses 3 coordinate pairs.
   // OBJ_RECTANGLE     - Rectangle. Uses 2 coordinate pairs.
   // OBJ_TRIANGLE      - Triangle. Uses 3 coordinate pairs.
   // OBJ_ELLIPSE       - Ellipse. Uses 2 coordinate pairs.
   // OBJ_PITCHFORK     - Andrews pitchfork. Uses 3 coordinate pairs.
   // OBJ_CYCLES        - Cycles. Uses 2 coordinate pairs.
   // OBJ_TEXT          - Text. Uses 1 coordinate pair.
   // OBJ_ARROW         - Arrows. Uses 1 coordinate pair.
   // OBJ_LABEL         - Text label. Uses 1 coordinate pair in pixels.

   // create the object
   bool success = ObjectCreate(name, type, window, time1, price1, time2, price2, time3, price3);
   if (!success) return(!catch("ObjectCreateRegister(2)  name=\""+ name +"\", type="+ ObjectTypeToStr(type, F_ERR_INVALID_PARAMETER) +", window="+ window, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

   // register the object for auto-removal
   int size = ArraySize(__objects);
   if (size <= __ojectsCounter) {
      if (!size) size = 512;
      size <<= 1;                                           // prevent re-allocation on every call (initial size 1024)
      ArrayResize(__objects, size);
      if (size >= 131072) debug("ObjectCreateRegister(3)  objects="+ (__ojectsCounter+1));
   }
   __objects[__ojectsCounter] = name;
   __ojectsCounter++;

   //debug("ObjectCreateRegister(4)  Tick="+ __ExecutionContext[EC.ticks] +"  objects="+ __objectsCounter +"  \""+ name +"\"");
   return(true);
}


/**
 * Delete all chart objects marked for auto-removal. Called on Program::deinit().
 *
 * @return int - error status
 */
int DeleteRegisteredObjects() {
   for (int i=0; i < __ojectsCounter; i++) {
      if (ObjectFind(__objects[i]) != -1) {
         ObjectDelete(__objects[i]);
      }
   }
   __ojectsCounter = ArrayResize(__objects, 0);
   return(catch("DeleteRegisteredObjects(1)"));
}
