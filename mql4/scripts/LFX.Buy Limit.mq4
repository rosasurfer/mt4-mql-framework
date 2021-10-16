/**
 * Erzeugt eine neue LFX-BuyLimit- oder StopBuy-Order. Muß auf dem jeweiligen LFX-Chart ausgeführt werden.
 *
 *  TODO: Fehler in Counter, wenn zwei Orders gleichzeitig erzeugt werden (2 x CHF.3)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#property show_inputs
////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Type  = "Buy Limit* | Stop Buy";
extern double Units = 0.2;                                           // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 3.0)
extern double LimitPrice;
extern double TakeProfitPrice;
extern double StopLossPrice;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/rsf/LFXOrder.mqh>


int limitType;                                                       // OP_BUYLIMIT | OP_BUYSTOP


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) TradeAccount initialisieren
   if (!InitTradeAccount())              return(last_error);
   if (!StrEndsWith(Symbol(), "LFX"))    return(HandleScriptError("onInit(1)", "Cannot place a LFX order on a non LFX chart (\""+ Symbol() +"\")", ERR_RUNTIME_ERROR));


   // (2) Parametervalidierung
   // Type
   string sValue = "";
   if (StrContains(Type, "*")) sValue = StrRightFrom(StrLeftTo(Type, "*"), "|", -1);
   else                        sValue = Type;
   sValue = StrReplace(StrToLower(sValue), " ", "");
   if      (sValue=="buylimit" || sValue=="limitbuy") limitType = OP_BUYLIMIT;
   else if (sValue=="buystop"  || sValue=="stopbuy" ) limitType = OP_BUYSTOP;
   else                                  return(HandleScriptError("onInit(2)", "Invalid parameter Type: \""+ Type +"\"", ERR_INVALID_INPUT_PARAMETER));

   // Units
   if (!EQ(MathModFix(Units, 0.1), 0))   return(HandleScriptError("onInit(3)", "Invalid parameter Units: "+ NumberToStr(Units, ".+") +"\n(not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMETER));
   if (Units < 0.1 || Units > 3)         return(HandleScriptError("onInit(4)", "Invalid parameter Units: "+ NumberToStr(Units, ".+") +"\n(valid range is from 0.1 to 3.0)", ERR_INVALID_INPUT_PARAMETER));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   LimitPrice = NormalizeDouble(LimitPrice, SubPipDigits);
   if (LimitPrice <= 0)                  return(HandleScriptError("onInit(5)", "Illegal parameter LimitPrice: "+ NumberToStr(LimitPrice, ".+") +"\n(must be positive)", ERR_INVALID_INPUT_PARAMETER));

   // TakeProfitPrice
   TakeProfitPrice = NormalizeDouble(TakeProfitPrice, SubPipDigits);
   if (TakeProfitPrice != 0) {
      if (TakeProfitPrice < 0)           return(HandleScriptError("onInit(6)", "Illegal parameter TakeProfitPrice: "+ NumberToStr(TakeProfitPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (TakeProfitPrice <= LimitPrice) return(HandleScriptError("onInit(7)", "Illegal parameter TakeProfitPrice: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be higher than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
   }

   // StopLossPrice
   StopLossPrice = NormalizeDouble(StopLossPrice, SubPipDigits);
   if (StopLossPrice != 0) {
      if (StopLossPrice < 0)             return(HandleScriptError("onInit(8)", "Illegal parameter StopLossPrice: "+ NumberToStr(StopLossPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (StopLossPrice >= LimitPrice)   return(HandleScriptError("onInit(9)", "Illegal parameter StopLossPrice: "+ NumberToStr(StopLossPrice, SubPipPriceFormat) +"\n(must be lower than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
   }


   // (3) alle Orders des Symbols einlesen
   int size = LFX.GetOrders(lfxCurrency, NULL, lfxOrders);
   if (size < 0)
      return(last_error);
   return(catch("onInit(10)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopChannels();
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int  button;
   bool executeNow;

   // (1) Sicherheitsabfrage
   if ((limitType==OP_BUYLIMIT && LimitPrice >= Close[0]) || (limitType==OP_BUYSTOP && LimitPrice <= Close[0])) {
      if (TakeProfitPrice && TakeProfitPrice <= Close[0]) return(HandleScriptError("onStart(1)", "Illegal parameter TakeProfitPrice: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be higher than the current price "+ NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
      if (StopLossPrice   && StopLossPrice   >= Close[0]) return(HandleScriptError("onStart(2)", "Illegal parameter StopLossPrice: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat) +"\n(must be lower than the current price "+  NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));

      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"The limit of "+ NumberToStr(LimitPrice, SubPipPriceFormat) +" will be triggered immediately (current price "+ NumberToStr(Close[0], SubPipPriceFormat) +").\n\n"
                        +"Do you really want to buy "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?",
                        ProgramName(),
                        MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(3)"));
      executeNow = true;
   }
   else {
      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"Do you really want to place a "+ OperationTypeDescription(limitType) +" order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                        +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                        + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat))
                        + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat)),
                        ProgramName(),
                        MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(4)"));
   }


   // (2) Order erzeugen und speichern
   datetime now = TimeFXT(); if (!now) return(last_error);

   /*LFX_ORDER*/int order[]; InitializeByteBuffer(order, LFX_ORDER_size);
      lo.setTicket           (order, LFX.CreateMagicNumber(lfxOrders, lfxCurrency));   // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
      lo.setType             (order, limitType          );
      lo.setUnits            (order, Units              );
      lo.setOpenTime         (order, now                );
      lo.setOpenPrice        (order, LimitPrice         );
      lo.setTakeProfitPrice  (order, TakeProfitPrice    );
      lo.setTakeProfitValue  (order, EMPTY_VALUE        );
      lo.setTakeProfitPercent(order, EMPTY_VALUE        );
      lo.setStopLossPrice    (order, StopLossPrice      );
      lo.setStopLossValue    (order, EMPTY_VALUE        );
      lo.setStopLossPercent  (order, EMPTY_VALUE        );                             // TODO: Fehler im Marker, wenn gleichzeitig zwei Orderdialoge aufgerufen und gehalten werden (2 x CHF.3)
      lo.setClosePrice       (order, Close[0]           );
      lo.setComment          (order, "#"+ (LFX.GetMaxOpenOrderMarker(lfxOrders, lfxCurrencyId)+1));
   if (!LFX.SaveOrder(order))
      return(last_error);


   if (executeNow) {
      // (3) Order sofort ausführen...
      int size = ArrayPushInts(lfxOrders, order);                                      // LFX.SendTradeCommand() erwartet ein LFX_ORDER-Array
      if (!LFX.SendTradeCommand(lfxOrders, size-1, OPEN_LIMIT_TRIGGERED)) return(last_error);
   }
   else {
      // (4) ...oder Benachrichtigung an den Chart schicken und Order bestätigen
      if (!QC.SendOrderNotification(lo.CurrencyId(order), "LFX:"+ lo.Ticket(order) +":pending=1")) return(last_error);
      PlaySoundEx("OrderOk.wav");
   }

   return(last_error);
}
