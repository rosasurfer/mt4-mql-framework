/**
 * Erzeugt eine neue "Buy Limit"-RemoteOrder. Muß auf dem jeweiligen LFX-Chart ausgeführt werden.
 *
 *  TODO: Fehler in Counter, wenn zwei Orders gleichzeitig erzeugt werden (2 x CHF.3)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs
////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern string Help  = "Buy Limit Order";
extern double Units = 0.5;                                           // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice;
extern double StopLossPrice;
extern double TakeProfitPrice;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlib.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfxfunctions.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


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
   // Units
   if (NE(MathModFix(Units, 0.1), 0))    return(HandleScriptError("onInit(2)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMETER));
   if (Units < 0.1 || Units > 1)         return(HandleScriptError("onInit(3)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMETER));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   LimitPrice = NormalizeDouble(LimitPrice, SubPipDigits);
   if (LimitPrice <= 0)                  return(HandleScriptError("onInit(4)", "Illegal parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +"\n(must be positive)", ERR_INVALID_INPUT_PARAMETER));

   // StopLossPrice
   StopLossPrice = NormalizeDouble(StopLossPrice, SubPipDigits);
   if (StopLossPrice != 0) {
      if (StopLossPrice < 0)             return(HandleScriptError("onInit(5)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (StopLossPrice >= LimitPrice)   return(HandleScriptError("onInit(6)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, SubPipPriceFormat) +"\n(must be lower than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
   }

   // TakeProfitPrice
   TakeProfitPrice = NormalizeDouble(TakeProfitPrice, SubPipDigits);
   if (TakeProfitPrice != 0) {
      if (TakeProfitPrice < 0)           return(HandleScriptError("onInit(7)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +"\n(can't be negative)", ERR_INVALID_INPUT_PARAMETER));
      if (TakeProfitPrice <= LimitPrice) return(HandleScriptError("onInit(8)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be higher than the LimitPrice "+ NumberToStr(LimitPrice, SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
   }


   // (3) Orders des Symbols einlesen
   int size = LFX.GetOrders(lfxCurrency, NULL, lfxOrders);
   if (size < 0)
      return(last_error);
   return(catch("onInit(9)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopLfxSenders();
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
   if (LimitPrice >= Close[0]) {
      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"The limit of "+ NumberToStr(LimitPrice, SubPipPriceFormat) +" is already triggered (current price "+ NumberToStr(Close[0], SubPipPriceFormat) +").\n\n"
                        +"Do you really want to immediately execute the order?",
                        __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(1)"));
      if (StopLossPrice   && StopLossPrice   >= Close[0]) return(HandleScriptError("onStart(2)", "Illegal parameter StopLossPrice = "+ NumberToStr(StopLossPrice, SubPipPriceFormat) +"\n(must be lower than the current price "+ NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
      if (TakeProfitPrice && TakeProfitPrice <= Close[0]) return(HandleScriptError("onStart(3)", "Illegal parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat) +"\n(must be higher than the current price "+ NumberToStr(Close[0], SubPipPriceFormat) +")", ERR_INVALID_INPUT_PARAMETER));
      // TODO: Statt eine PendingOrder zu erzeugen die Order sofort ausführen, da sie sonst erst beim nächsten Tick geprüft und ggf. doch nicht ausgeführt wird.
   }
   else {
      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
                        +"Do you really want to place a Buy Limit order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                        +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                        + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
                        + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
                        __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(4)"));
   }


   // (2) neue Order erzeugen und speichern
   datetime now.fxt = TimeFXT(); if (!now.fxt) return(false);

   /*LFX_ORDER*/int lo[]; InitializeByteBuffer(lo, LFX_ORDER.size);
      lo.setTicket         (lo, CreateMagicNumber()          );      // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
      lo.setType           (lo, OP_BUYLIMIT                  );
      lo.setUnits          (lo, Units                        );
      lo.setOpenTime       (lo, now.fxt                      );
      lo.setOpenPrice      (lo, LimitPrice                   );
      lo.setStopLoss       (lo, StopLossPrice                );
      lo.setStopLossValue  (lo, EMPTY_VALUE                  );
      lo.setTakeProfit     (lo, TakeProfitPrice              );
      lo.setTakeProfitValue(lo, EMPTY_VALUE                  );
      lo.setComment        (lo, "#"+ (GetPositionCounter()+1));
   if (!LFX.SaveOrder(lo))
      return(last_error);


   // (3) Orderbenachrichtigung an den Chart schicken
   if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":pending=1"))
      return(false);


   // (4) Bestätigungsmeldung
   PlaySoundEx("OrderOk.wav");
   /*
   MessageBox(ifString(tradeAccount.type==ACCOUNT_TYPE_REAL, "- Real Account -\n\n", "")
            +"Buy Limit order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +" placed.\n\n"
            +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
            + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
            + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
            __NAME__, MB_ICONINFORMATION|MB_OK);
   */
   return(last_error);
}


/**
 * Generiert eine neue LFX-Ticket-ID (Wert für OrderMagicNumber().
 *
 * @return int - LFX-Ticket-ID oder NULL, falls ein Fehler auftrat
 */
int CreateMagicNumber() {
   int iStrategy = STRATEGY_ID & 0x3FF << 22;                        // 10 bit (Bits 23-32)
   int iCurrency = lfxCurrencyId & 0xF << 18;                        //  4 bit (Bits 19-22)
   int iInstance = CreateInstanceId() & 0x3FF << 4;                  // 10 bit (Bits  5-14)
   return(iStrategy + iCurrency + iInstance);
}


/**
 * Erzeugt eine neue Instanz-ID.
 *
 * @return int - Instanz-ID im Bereich 1-1023 (10 bit)
 */
int CreateInstanceId() {
   int size=ArrayRange(lfxOrders, 0), id, ids[];
   ArrayResize(ids, 0);

   for (int i=0; i < size; i++) {
      ArrayPushInt(ids, LFX.InstanceId(los.Ticket(lfxOrders, i)));
   }

   MathSrand(GetTickCount());
   while (!id) {
      id = MathRand();
      while (id > 1023) {
         id >>= 1;
      }
      if (IntInArray(ids, id))                                       // sicherstellen, daß die ID nicht gerade benutzt wird
         id = 0;
   }
   return(id);
}


/**
 * Gibt den Positionszähler der letzten offenen Order im aktuellen Instrument zurück.
 *
 * @return int - Zähler
 */
int GetPositionCounter() {
   int counter, size=ArrayRange(lfxOrders, 0);

   for (int i=0; i < size; i++) {
      if (los.CurrencyId(lfxOrders, i) != lfxCurrencyId)
         continue;
      if (!los.IsOpenPosition(lfxOrders, i))
         continue;

      string comment = los.Comment(lfxOrders, i);
      if      (StringStartsWith(comment, lfxCurrency +".")) comment = StringRightFrom(comment, ".");
      else if (StringStartsWith(comment, "#"))              comment = StringRight(comment, -1);
      else
         continue;
      counter = Max(counter, StrToInteger(comment));
   }
   return(counter);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


/*abstract*/bool QC.StopScriptParameterSender()  { return(!catch("QC.StopScriptParameterSender(1)", ERR_WRONG_JUMP)); }
