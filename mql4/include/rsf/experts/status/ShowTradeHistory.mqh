/**
 * Display closed trades.
 *
 * @param  bool show - display status:
 *                      TRUE  - show history
 *                      FALSE - hide displayed history
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int ShowTradeHistory(bool show) {
   show = show!=0;
   int displayedTrades = 0;

   if (show) {
      int trades1 = _ShowTradeHistory(history);      if (IsEmpty(trades1)) return(EMPTY);
      int trades2 = _ShowTradeHistory(partialClose); if (IsEmpty(trades2)) return(EMPTY);
      displayedTrades = trades1 + trades2;
   }
   else {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_CLOSED_LONG && clr!=CLR_CLOSED_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_CLOSED) continue;
               }
            }
            else if (ObjectType(name) != OBJ_TREND) continue;
            ObjectDelete(name);
         }
      }
   }

   if (!catch("ShowTradeHistory(1)"))
      return(displayedTrades);
   return(EMPTY);
}


/**
 * Helper function. Displays closed trades from the specified trade array.
 *
 * @param  double array[] - closed trades
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int _ShowTradeHistory(double array[][]) {
   int trades = 0;

   string openLabel="", lineLabel="", closeLabel="", sOpenPrice="", sClosePrice="", sOperations[]={"buy", "sell"};
   int iOpenColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, iLineColors[]={Blue, Red};

   // process array[]
   int orders = ArrayRange(array, 0);
   for (int i=0; i < orders; i++) {
      int      ticket     = array[i][H_TICKET    ];
      int      toTicket   = array[i][H_TO_TICKET ];
      int      type       = array[i][H_TYPE      ];
      double   lots       = array[i][H_LOTS      ];
      double   part       = array[i][H_PART      ];
      datetime openTime   = array[i][H_OPENTIME  ];
      double   openPrice  = array[i][H_OPENPRICE ];
      datetime closeTime  = array[i][H_CLOSETIME ];
      double   closePrice = array[i][H_CLOSEPRICE];

      if (!closeTime)                    continue;       // skip open tickets (should not happen)
      if (type!=OP_BUY && type!=OP_SELL) continue;       // skip non-trades (should not happen)
      trades++;

      if (status.activeMetric == METRIC_SIG_UNITS) {
         openPrice  = array[i][H_OPENPRICE_SIG ];
         closePrice = array[i][H_CLOSEPRICE_SIG];
      }
      sOpenPrice  = NumberToStr(openPrice, PriceFormat);
      sClosePrice = NumberToStr(closePrice, PriceFormat);

      // open marker
      openLabel = StringConcatenate("#", ticket, " ", sOperations[type], " ", NumberToStr(lots, ".+"), " at ", sOpenPrice);
      if (part == 1) {                                // history[]
         if (ObjectFind(openLabel) == -1) ObjectCreate(openLabel, OBJ_ARROW, 0, 0, 0);
         ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (openLabel, OBJPROP_COLOR,  iOpenColors[type]);
         ObjectSet    (openLabel, OBJPROP_TIME1,  openTime);
         ObjectSet    (openLabel, OBJPROP_PRICE1, openPrice);
         ObjectSetText(openLabel, instance.name);

         if (toTicket > 0) continue;                     // aggregated trade: no trend line, no close marker
      }
      //else partialClose[]: no open marker

      // trend line
      lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == -1) ObjectCreate(lineLabel, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSet(lineLabel, OBJPROP_RAY,    false);
      ObjectSet(lineLabel, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(lineLabel, OBJPROP_COLOR,  iLineColors[type]);
      ObjectSet(lineLabel, OBJPROP_BACK,   true);
      ObjectSet(lineLabel, OBJPROP_TIME1,  openTime);
      ObjectSet(lineLabel, OBJPROP_PRICE1, openPrice);
      ObjectSet(lineLabel, OBJPROP_TIME2,  closeTime);
      ObjectSet(lineLabel, OBJPROP_PRICE2, closePrice);

      // close marker
      closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
      if (ObjectFind(closeLabel) == -1) ObjectCreate(closeLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
      ObjectSet    (closeLabel, OBJPROP_COLOR,  CLR_CLOSED);
      ObjectSet    (closeLabel, OBJPROP_TIME1,  closeTime);
      ObjectSet    (closeLabel, OBJPROP_PRICE1, closePrice);
      ObjectSetText(closeLabel, instance.name);
   }

   if (!catch("_ShowTradeHistory(1)"))
      return(trades);
   return(EMPTY);
}
