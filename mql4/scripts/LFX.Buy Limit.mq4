/**
 * Erzeugt eine neue LFX-"Buy Limit"-Order, die überwacht und bei Erreichen des Limit-Preises automatisch ausgeführt wird.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

//#include <lfx.mqh>
//#include <win32api.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern double Units      = 1.0;                                      // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)
extern double LimitPrice = 0;                                        // Limit

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string lfxCurrency;
double leverage;


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


   // (2) Parametervalidierung
   // Units
   if (NE(MathModFix(Units, 0.1), 0))            return(catch("onInit(1)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   if (Units < 0.1 || Units > 1)                 return(catch("onInit(2)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);

   // LimitPrice
   if (LimitPrice >= Bid)                        return(catch("onInit(3)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be lower than the current LFX price)", ERR_INVALID_INPUT_PARAMVALUE));
   if (!LimitPrice)                              return(catch("onInit(4)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be non zero)", ERR_INVALID_INPUT_PARAMVALUE));
   if (LimitPrice < 0)                           return(catch("onInit(5)   Illegal input parameter LimitPrice = "+ NumberToStr(LimitPrice, ".+") +" (must be higher than zero)", ERR_INVALID_INPUT_PARAMVALUE));


   // (3) Leverage-Konfiguration einlesen und validieren
   if (!IsGlobalConfigKey("Leverage", "Basket")) return(catch("onInit(6)   Missing global MetaTrader config value [Leverage]->Basket", ERR_INVALID_CONFIG_PARAMVALUE));
   string value = GetGlobalConfigString("Leverage", "Basket", "");
   if (!StringIsNumeric(value))                  return(catch("onInit(7)   Invalid MetaTrader config value [Leverage]->Basket = \""+ value +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   leverage = StrToDouble(value);
   if (leverage < 1)                             return(catch("onInit(8)   Invalid MetaTrader config value [Leverage]->Basket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   return(catch("onInit(9)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(last_error);
}
