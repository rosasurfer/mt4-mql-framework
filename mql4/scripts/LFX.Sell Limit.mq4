/**
 * Erzeugt eine neue LFX-SellLimit- oder StopSell-Order. Muß auf dem jeweiligen LFX-Chart ausgeführt werden.
 *
 *  TODO: Fehler in Counter, wenn zwei Orders gleichzeitig erzeugt werden (2 x CHF.3)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs
////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern string Type  = "Sell Limit* | Stop Sell";
extern double Units = 0.5;                                           // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice;
extern double TakeProfitPrice;
extern double StopLossPrice;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlib.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/myfx/LFX_ORDER.mqh>


int limitType;                                                       // OP_SELLLIMIT | OP_SELLSTOP


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) TradeAccount initialisieren
   if (!InitTradeAccount())              return(last_error);
   if (!StringEndsWith(Symbol(), "LFX")) return(HandleScriptError("onInit(1)", "Cannot place a LFX order on a non LFX chart (\""+ Symbol() +"\")", ERR_RUNTIME_ERROR));


   // (2) Parametervalidierung
   // Type
   string sValue;
   if (StringContains(Type, "*")) sValue = StringRightFrom(StringLeftTo(Type, "*"), "|", -1);
   else                           sValue = Type;
   sValue = StringReplace(StringToLower(sValue), " ", "");
   if      (sValue=="selllimit" || sValue=="limitsell") limitType = OP_SELLLIMIT;
   else if (sValue=="sellstop"  || sValue=="stopsell" ) limitType = OP_SELLSTOP;
   else                                  return(HandleScriptError("onInit(2)", "Invalid parameter Type = \""+ Type +"\"", ERR_INVALID_INPUT_PARAMETER));

   // Units
   if (NE(MathModFix(Units, 0.1), 0))    return(HandleScriptError("onInit(3)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMETER));
   if (Units < 0.1 || Units > 1)         return(HandleScriptError("onInit(4)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMETER));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   LimitPrice = NormalizeDouble(LimitPrice, SubPipDigits);
   if (LimitPrice <= 0)                  return(HandleScriptError("onInit(5)", "Illegal parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +"\n(must be positive)", ERR_INVALID_INPUT_PARAMETER));

   // TakeProfitPrice
   TakeProfitPrice = NormalizeDouble(TakeProfitPrice, SubPipDigits);
   if (TakeProfitPrice != 0) {
      if (TakeProfitPrice < 0)           return(HandleScriptError("onInit(6)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (TakeProfitPrice >= LimitPrice) return(HandleScriptError("onInit(7)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be lower than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
   }

   // StopLossPrice
   StopLossPrice = NormalizeDouble(StopLossPrice, SubPipDigits);
   if (StopLossPrice != 0) {
      if (StopLossPrice < 0)             return(HandleScriptError("onInit(8)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (StopLossPrice <= LimitPrice)   return(HandleScriptError("onInit(9)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, SubPipPriceFormat) +"\n(must be higher than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
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
   int button;

   // (1) Sicherheitsabfrage
   if ((limitType==OP_SELLLIMIT && LimitPrice <= Close[0]) || (limitType==OP_SELLSTOP && LimitPrice >= Close[0])) {
      if (TakeProfitPrice && TakeProfitPrice >= Close[0]) return(HandleScriptError("onStart(1)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be lower than the current price "+ NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
      if (StopLossPrice   && StopLossPrice   <= Close[0]) return(HandleScriptError("onStart(2)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, SubPipPriceFormat) +"\n(must be higher than the current price "+ NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));

      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"The limit of "+ NumberToStr(LimitPrice, SubPipPriceFormat) +" will be triggered immediately (current price "+ NumberToStr(Close[0], SubPipPriceFormat) +").\n\n"
                        +"Do you really want to immediately execute the order?",
                        __NAME__,
                        MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(3)"));
      // TODO: Statt eine PendingOrder zu erzeugen die Order sofort ausführen, da sie sonst erst beim nächsten Tick geprüft und ggf. doch nicht ausgeführt wird.
   }
   else {
      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"Do you really want to place a "+ OperationTypeDescription(limitType) +" order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                        +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                        + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat))
                        + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat)),
                        __NAME__,
                        MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(4)"));
   }


   // (2) neue Order erzeugen und speichern
   datetime now = TimeFXT(); if (!now) return(last_error);

   /*LFX_ORDER*/int lo[]; InitializeByteBuffer(lo, LFX_ORDER.size);
      lo.setTicket           (lo, LFX.CreateMagicNumber(lfxOrders, lfxCurrency));   // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
      lo.setType             (lo, limitType          );
      lo.setUnits            (lo, Units              );
      lo.setOpenTime         (lo, now                );
      lo.setOpenPrice        (lo, LimitPrice         );
      lo.setTakeProfitPrice  (lo, TakeProfitPrice    );
      lo.setTakeProfitValue  (lo, EMPTY_VALUE        );
      lo.setTakeProfitPercent(lo, EMPTY_VALUE        );
      lo.setStopLossPrice    (lo, StopLossPrice      );
      lo.setStopLossValue    (lo, EMPTY_VALUE        );
      lo.setStopLossPercent  (lo, EMPTY_VALUE        );                             // TODO: Fehler im Marker, wenn gleichzeitig zwei Orderdialoge aufgerufen und gehalten werden (2 x CHF.3)
      lo.setComment          (lo, "#"+ (LFX.GetMaxOpenOrderMarker(lfxOrders, lfxCurrencyId)+1));
   if (!LFX.SaveOrder(lo))
      return(last_error);


   // (3) Orderbenachrichtigung an den Chart schicken
   if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":pending=1"))
      return(false);


   // (4) Bestätigungsmeldung
   PlaySoundEx("OrderOk.wav");
   /*
   MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
            + OperationTypeDescription(limitType) +" order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +" placed.\n\n"
            +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
            + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat))
            + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat)),
            __NAME__,
            MB_ICONINFORMATION|MB_OK);
   */
   return(last_error);
}
