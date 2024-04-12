
string __registeredObjects[];
int    __registeredOjectsCounter = 0;


/**
 * Create a chart object and register it for auto-removal on Program::deinit(). Function parameters are identical to the
 * built-in function ObjectCreate().
 *
 * @param  string   name   - unique object name (max. 63 chars, may contain line breaks)
 * @param  int      type   - object type identifier
 * @param  int      window - index of the chart window to create the object in
 * @param  datetime time1  - time value of the first coordinate pair
 * @param  double   price1 - price value of the first coordinate pair
 * @param  datetime time2  - time value of the second coordinate pair
 * @param  double   price2 - price value of the second coordinate pair
 * @param  datetime time3  - time value of the third coordinate pair
 * @param  double   price3 - price value of the third coordinate pair
 *
 * @return bool - success status
 *
 * TODO:
 *  - 106.000 initial calls on terminal start with 7 open charts
 *  - SuperBars in regular charts: permant non-stopping calls (after a few minutes more than 1.000.000)
 *  - SuperBars in offline charts: 271 calls on every tick
 *  - move elsewhere as the library is not a singleton (there can be multiple instances)
 */
bool ObjectCreateRegister(string name, int type, int window, datetime time1, double price1, datetime time2, double price2, datetime time3, double price3) {
   bool success = false;

   // create the object
   switch (type) {
      case OBJ_VLINE        :    // Vertical line. Uses time of first coordinate pair.
      case OBJ_HLINE        :    // Horizontal line. Uses price of first coordinate pair.
      case OBJ_TREND        :    // Trend line. Uses 2 coordinate pairs.
      case OBJ_TRENDBYANGLE :    // Trend by angle. Uses 1 coordinate pair.
      case OBJ_REGRESSION   :    // Regression. Uses times of first two coordinate pairs.
      case OBJ_CHANNEL      :    // Channel. Uses 3 coordinate pairs.
      case OBJ_STDDEVCHANNEL:    // Standard deviation channel. Uses times of first two coordinate pairs.
      case OBJ_GANNLINE     :    // Gann line. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_GANNFAN      :    // Gann fan. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_GANNGRID     :    // Gann grid. Uses 2 coordinate pairs, price of second pair is ignored.
      case OBJ_FIBO         :    // Fibonacci retracement. Uses 2 coordinate pairs.
      case OBJ_FIBOTIMES    :    // Fibonacci time zones. Uses 2 coordinate pairs.
      case OBJ_FIBOFAN      :    // Fibonacci fan. Uses 2 coordinate pairs.
      case OBJ_FIBOARC      :    // Fibonacci arcs. Uses 2 coordinate pairs.
      case OBJ_EXPANSION    :    // Fibonacci expansions. Uses 3 coordinate pairs.
      case OBJ_FIBOCHANNEL  :    // Fibonacci channel. Uses 3 coordinate pairs.
      case OBJ_RECTANGLE    :    // Rectangle. Uses 2 coordinate pairs.
      case OBJ_TRIANGLE     :    // Triangle. Uses 3 coordinate pairs.
      case OBJ_ELLIPSE      :    // Ellipse. Uses 2 coordinate pairs.
      case OBJ_PITCHFORK    :    // Andrews pitchfork. Uses 3 coordinate pairs.
      case OBJ_CYCLES       :    // Cycles. Uses 2 coordinate pairs.
      case OBJ_TEXT         :    // Text. Uses 1 coordinate pair.
      case OBJ_ARROW        :    // Arrows. Uses 1 coordinate pair.
      case OBJ_LABEL        :    // Text label. Uses 1 coordinate pair in pixels.
      default:
         success = ObjectCreate(name, type, window, time1, price1, time2, price2, time3, price3);
   }
   if (!success) return(!catch("ObjectCreateRegister(1)  name=\""+ name +"\"  type="+ ObjectTypeToStr(type) +"  window="+ window, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

   // register the object for auto-removal
   int size = ArraySize(__registeredObjects);
   if (size <= __registeredOjectsCounter) {
      if (!size) size = 512;
      size <<= 1;                                           // prevent re-allocation on every call (initial size 1024)
      ArrayResize(__registeredObjects, size);
      if (size >= 131072) debug("ObjectCreateRegister(2)  objects="+ (__registeredOjectsCounter+1));
   }
   __registeredObjects[__registeredOjectsCounter] = name;
   __registeredOjectsCounter++;

   //debug("ObjectCreateRegister(3)  Tick="+ __ExecutionContext[EC.ticks] +"  objects="+ __registeredOjectsCounter +"  \""+ name +"\"");
   return(true);
}


/**
 * Delete all chart objects marked for auto-removal. Called on Program::deinit().
 *
 * @return int - error status
 */
int DeleteRegisteredObjects() {
   for (int i=0; i < __registeredOjectsCounter; i++) {
      if (ObjectFind(__registeredObjects[i]) != -1) {
         if (!ObjectDelete(__registeredObjects[i])) logWarn("DeleteRegisteredObjects(1)->ObjectDelete(name=\""+ __registeredObjects[i] +"\")", intOr(GetLastError(), ERR_RUNTIME_ERROR));
      }
   }
   ArrayResize(__registeredObjects, 0);
   __registeredOjectsCounter = 0;
   return(catch("DeleteRegisteredObjects(2)"));
}
