/**
 * Erzeugt eine neue LFX-"Buy Limit"-Order, die überwacht und bei Erreichen des Limit-Preises automatisch ausgeführt wird.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <lfx.mqh>
#include <win32api.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern double Units           = 1.0;                                 // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice;
extern double StopLossPrice;
extern double TakeProfitPrice;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    remoteAccount;                                                // aktueller Remote-Account
string remoteAccountCompany;
int    remoteAccountType;

string lfxCurrency;                                                  // aktuelle LFX-Währung
int    lfxCurrencyId;

int    openPosition.instanceIds[];                                   // Daten der aktuell offenen LFX-Positionen
int    openPosition.counter;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) LFX-Currency bestimmen
   if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
   else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);
   else {
      PlaySound("notify.wav");
      MessageBox("Cannot manage LFX orders on a non LFX chart (\""+ Symbol() +"\")", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   lfxCurrencyId = GetCurrencyId(lfxCurrency);


   // (2) Daten des Remote-Account bestimmen
   string section = "LFX";
   string key     = "MRURemoteAccount";
   remoteAccount  = GetLocalConfigInt(section, key, 0);
   if (remoteAccount <= 0) {
      PlaySound("notify.wav");
      string value = GetLocalConfigString(section, key, "");
      if (!StringLen(value)) MessageBox("Missing remote account setting ["+ section +"]->"+ key                      , __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      else                   MessageBox("Invalid remote account setting ["+ section +"]->"+ key +" = \""+ value +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   section = "Accounts";
   key     = remoteAccount +".company";
   remoteAccountCompany = GetGlobalConfigString(section, key, "");
   if (!StringLen(remoteAccountCompany)) {
      PlaySound("notify.wav");
      MessageBox("Missing account company setting for remote account \""+ remoteAccount +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   key   = remoteAccount +".type";
   value = StringToLower(GetGlobalConfigString(section, key, ""));
   if (!StringLen(value)) {
      PlaySound("notify.wav");
      MessageBox("Missing remote account setting ["+ section +"]->"+ key, __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }
   if      (value == "demo") remoteAccountType = ACCOUNT_TYPE_DEMO;
   else if (value == "real") remoteAccountType = ACCOUNT_TYPE_REAL;
   else {
      PlaySound("notify.wav");
      MessageBox("Invalid account type setting ["+ section +"]->"+ key +" = \""+ GetGlobalConfigString(section, key, "") +"\"", __NAME__ +"::init()", MB_ICONSTOP|MB_OK);
      return(SetLastError(ERR_RUNTIME_ERROR));
   }


   // (3) Parametervalidierung
   // Units
   if (NE(MathModFix(Units, 0.1), 0))    return(catch("onInit(1)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   if (Units < 0.1 || Units > 1)         return(catch("onInit(2)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   if (LimitPrice >= Bid)                return(catch("onInit(3)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be lower than the current LFX price)", ERR_INVALID_INPUT_PARAMVALUE));
   if (LimitPrice <= 0)                  return(catch("onInit(4)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be positive)", ERR_INVALID_INPUT_PARAMVALUE));

   // StopLossPrice
   if (StopLossPrice < 0)                return(catch("onInit(5)   Illegal input parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +" (can't be negative)", ERR_INVALID_INPUT_PARAMVALUE));
   if (StopLossPrice > 0)
      if (StopLossPrice >= LimitPrice)   return(catch("onInit(6)   Illegal input parameter StopLossPrice = "+ NumberToStr(StopLossPrice, ".+") +" (must be lower than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfitPrice
   if (TakeProfitPrice != 0)
      if (TakeProfitPrice <= LimitPrice) return(catch("onInit(7)   Illegal input parameter TakeProfitPrice = "+ NumberToStr(TakeProfitPrice, ".+") +" (must be higher than the limit price)", ERR_INVALID_INPUT_PARAMVALUE));

   return(catch("onInit(8)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // (1) Sicherheitsabfrage
   PlaySound("notify.wav");
   int button = MessageBox(ifString(remoteAccountType==ACCOUNT_TYPE_REAL, "- Live Account -\n\n", "")
                         +"Do you really want to place a limit order to Buy "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?\n\n"
                         +                                   "Limit: "+      NumberToStr(LimitPrice,      SubPipPriceFormat)
                         + ifString(!StopLossPrice  , "", "   StopLoss: "+   NumberToStr(StopLossPrice,   SubPipPriceFormat))
                         + ifString(!TakeProfitPrice, "", "   TakeProfit: "+ NumberToStr(TakeProfitPrice, SubPipPriceFormat)),
                         __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(1)"));


   // (2) Orderdetails definieren
   int    counter = GetPositionCounter() + 1;   if (!counter) return(catch("onStart(2)"));   // Abbruch, falls GetPositionCounter() oder
   int    ticket  = CreateMagicNumber(counter); if (!ticket)  return(catch("onStart(3)"));   // CreateMagicNumber() Fehler melden
   string label   = "#"+ counter;


   // (3) Order speichern
   if (!LFX.WriteTicket(remoteAccount, ticket, label, OP_BUYLIMIT, Units, TimeGMT(), NULL, LimitPrice, StopLossPrice, TakeProfitPrice, NULL, NULL, NULL, TimeGMT()))
      return(last_error);

   return(last_error);
}


/**
 * Gibt den Positionszähler der letzten offenen Position im aktuellen Instrument zurück.
 *
 * @return int - Zähler oder -1, falls ein Fehler auftrat
 */
int GetPositionCounter() {
   // Sicherstellen, daß die vorhandenen offenen Positionen eingelesen wurden
   if (!LFX.ReadInstanceIdsCounter(remoteAccount, lfxCurrency, openPosition.instanceIds, openPosition.counter))
      return(-1);
   return(openPosition.counter);
}


/**
 * Generiert eine neue LFX-Ticket-ID (Wert für OrderMagicNumber().
 *
 * @param  int counter - Position-Zähler, für den eine ID erzeugt werden soll
 *
 * @return int - LFX-Ticket-ID oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int counter) {
   if (counter < 1)
      return(_NULL(catch("CreateMagicNumber()   invalid parameter counter = "+ counter, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int iStrategy = STRATEGY_ID & 0x3FF << 22;                        // 10 bit (Bits 23-32)
   int iCurrency = lfxCurrencyId & 0xF << 18;                        //  4 bit (Bits 19-22)
   int iUnits    = Round(Units * 10) & 0xF << 14;                    //  4 bit (Bits 15-18)
   int iInstance = GetCreateInstanceId() & 0x3FF << 4;               // 10 bit (Bits  5-14)
   int pCounter  = counter & 0xF;                                    //  4 bit (Bits  1-4 )

   if (!iInstance)
      return(NULL);
   return(iStrategy + iCurrency + iUnits + iInstance + pCounter);
}


/**
 * Gibt die aktuelle Instanz-ID zurück. Existiert noch keine, wird eine neue erzeugt.
 *
 * @return int - Instanz-ID im Bereich 1-1023 (10 bit) oder NULL, falls ein Fehler auftrat
 */
int GetCreateInstanceId() {
   static int id;

   if (!id) {
      // sicherstellen, daß die offenen Positionen eingelesen wurden
      if (!LFX.ReadInstanceIdsCounter(remoteAccount, lfxCurrency, openPosition.instanceIds, openPosition.counter))
         return(NULL);

      MathSrand(GetTickCount());
      while (!id) {
         id = MathRand();
         while (id > 1023) {
            id >>= 1;
         }
         if (IntInArray(openPosition.instanceIds, id))               // sicherstellen, daß alle aktuell benutzten Instanz-ID's eindeutig sind
            id = 0;
      }
   }
   return(id);
}
