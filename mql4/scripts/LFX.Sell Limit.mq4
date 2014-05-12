/**
 * Erzeugt eine neue LFX-"Sell Limit"-Order, die überwacht und bei Erreichen des Limit-Preises ausgeführt wird.
 *
 *
 *  TODO: Fehler in Counter, wenn gleichzeitig zwei Orders erzeugt werden (2 x CHF.3)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>

#include <LFX/functions.mqh>
#include <LFX/quickchannel.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern double Units           = 1.0;                                 // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice;
extern double StopLossPrice;
extern double TakeProfitPrice;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) LFX-Currency und ID bestimmen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot place LFX orders on a non LFX chart (\""+ Symbol() +"\")", __NAME__, MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   lfxCurrencyId = GetCurrencyId(lfxCurrency);


   // (2) Parametervalidierung
   // Units
   if (NE(MathModFix(Units, 0.1), 0))    return(catch("onInit(1)   invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   if (Units < 0.1 || Units > 1)         return(catch("onInit(2)   invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   LimitPrice    = NormalizeDouble(LimitPrice, SubPipDigits);
   if (LimitPrice <= Bid)                return(catch("onInit(3)   illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be higher than the current LFX price)", ERR_INVALID_INPUT_PARAMVALUE));

   // StopLossPrice
   StopLossPrice       = NormalizeDouble(StopLossPrice, SubPipDigits);
   if (StopLossPrice != 0)
      if (StopLossPrice <= LimitPrice)   return(catch("onInit(4)   illegal input parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +" (must be higher than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfitPrice
   TakeProfitPrice       = NormalizeDouble(TakeProfitPrice, SubPipDigits);
   if (TakeProfitPrice < 0)              return(catch("onInit(5)   illegal input parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +" (can't be negative)", ERR_INVALID_INPUT_PARAMVALUE));
   if (TakeProfitPrice > 0)
      if (TakeProfitPrice >= LimitPrice) return(catch("onInit(6)   illegal input parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +" (must be lower than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));


   // (3) offene Orders einlesen
   int size = LFX.GetOrders(NULL, OF_OPEN, lfxOrders);
   if (size < 0)
      return(last_error);
   return(catch("onInit(7)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopTradeToLfxSenders();
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // (1) Sicherheitsabfrage
   PlaySound("notify.wav");
   int button = MessageBox(ifString(lfxAccountType==ACCOUNT_TYPE_REAL, "- Live Account -\n\n", "")
                         +"Do you really want to place a limit order to Sell "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                         +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                         + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
                         + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
                         __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(1)"));


   // (2) neue Order erzeugen und speichern
   double deviation = GetGlobalConfigDouble("LfxChartDeviation", lfxCurrency, 0);

   /*LFX_ORDER*/int lo[]; InitializeByteBuffer(lo, LFX_ORDER.size);
      lo.setTicket       (lo, CreateMagicNumber()          );        // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
      lo.setDeviation    (lo, deviation                    );        // LFX-Deviation immer vor allen Preisen
      lo.setType         (lo, OP_SELLLIMIT                 );
      lo.setUnits        (lo, Units                        );
      lo.setOpenTime     (lo, TimeGMT()                    );
      lo.setOpenPriceLfx (lo, LimitPrice                   );
      lo.setStopLossLfx  (lo, StopLossPrice                );
      lo.setTakeProfitLfx(lo, TakeProfitPrice              );
      lo.setComment      (lo, "#"+ (GetPositionCounter()+1));
   if (!LFX.SaveOrder(lo))
      return(last_error);


   // (3) Orderbenachrichtigung an den Chart schicken
   if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":pending=1"))
      return(false);


   // (4) Bestätigungsmeldung
   PlaySound("Entry order.wav");
   MessageBox(ifString(lfxAccountType==ACCOUNT_TYPE_REAL, "- Live Account -\n\n", "")
            +"Sell Limit order for "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +" placed.\n\n"
            +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
            + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
            + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
            __NAME__, MB_ICONINFORMATION|MB_OK);
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

      string label = los.Comment(lfxOrders, i);
      if (StringStartsWith(label, lfxCurrency +".")) label = StringRight(label, -4);
      if (StringStartsWith(label,              "#")) label = StringRight(label, -1);

      counter = Max(counter, StrToInteger(label));
   }
   return(counter);
}


/*abstract*/bool ProcessTradeToLfxTerminalMsg(string s1) { return(!catch("ProcessTradeToLfxTerminalMsg()", ERR_WRONG_JUMP)); }
/*abstract*/bool QC.StopScriptParameterSender()          { return(!catch("QC.StopScriptParameterSender()", ERR_WRONG_JUMP)); }
/*abstract*/bool RunScript(string s1, string s2)         { return(!catch("RunScript()",                    ERR_WRONG_JUMP)); }
