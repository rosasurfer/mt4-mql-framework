/**
 * MT4 struct SYMBOL (Dateiformat "symbols.raw")
 *
 * Die Symbole einer Datei sind alphabetisch nach Namen sortiert.
 */
#import "Expander.dll"
   // Getter
   string symbol_AltName           (/*SYMBOL*/int symbol[]);
   int    symbol_BackgroundColor   (/*SYMBOL*/int symbol[]);
   string symbol_BaseCurrency      (/*SYMBOL*/int symbol[]);
   double symbol_ContractSize      (/*SYMBOL*/int symbol[]);
   string symbol_Description       (/*SYMBOL*/int symbol[]);
   int    symbol_Digits            (/*SYMBOL*/int symbol[]);
   int    symbol_Group             (/*SYMBOL*/int symbol[]);
   int    symbol_Id                (/*SYMBOL*/int symbol[]);
   string symbol_MarginCurrency    (/*SYMBOL*/int symbol[]);
   double symbol_MarginDivider     (/*SYMBOL*/int symbol[]);
   double symbol_MarginHedged      (/*SYMBOL*/int symbol[]);
   double symbol_MarginInit        (/*SYMBOL*/int symbol[]);
   double symbol_MarginMaintenance (/*SYMBOL*/int symbol[]);
   string symbol_Name              (/*SYMBOL*/int symbol[]);
   string symbol_Origin            (/*SYMBOL*/int symbol[]);
   double symbol_PointSize         (/*SYMBOL*/int symbol[]);
   double symbol_PointsPerUnit     (/*SYMBOL*/int symbol[]);
   int    symbol_Spread            (/*SYMBOL*/int symbol[]);
   int    symbol_StopDistance      (/*SYMBOL*/int symbol[]);
   double symbol_SwapLong          (/*SYMBOL*/int symbol[]);
   double symbol_SwapShort         (/*SYMBOL*/int symbol[]);
   int    symbol_TradeMode         (/*SYMBOL*/int symbol[]);

   int    symbols_Id               (/*SYMBOL*/int symbols[], int i);
   string symbols_Name             (/*SYMBOL*/int symbols[], int i);

   // Setter
   bool   symbol_SetBackgroundColor(/*SYMBOL*/int symbol[],         color  bgColor    );
   bool   symbol_SetBaseCurrency   (/*SYMBOL*/int symbol[],         string currency   );
   bool   symbol_SetDescription    (/*SYMBOL*/int symbol[],         string description);
   bool   symbol_SetDigits         (/*SYMBOL*/int symbol[],         int    digits     );
   bool   symbol_SetGroup          (/*SYMBOL*/int symbol[],         int    index      );
   bool   symbol_SetId             (/*SYMBOL*/int symbol[],         int    id         );
   bool   symbol_SetMarginCurrency (/*SYMBOL*/int symbol[],         string currency   );
   bool   symbol_SetName           (/*SYMBOL*/int symbol[],         string name       );

   bool   symbols_SetId            (/*SYMBOL*/int symbols[], int i, int    id         );

   // Helper
   bool   symbols_Sort             (/*SYMBOL*/int symbols[], int size);
#import
