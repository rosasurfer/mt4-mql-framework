/**
 * MT4 struct SYMBOL (Dateiformat "symbols.raw")
 *
 * Die Symbole einer Datei sind alphabetisch nach Namen sortiert.
 *
 * @see  MT4Expander::header/mql/structs/mt4/Symbol.h
 */
#import "Expander.dll"
   // Getter
   string symbol_Name                 (/*SYMBOL*/int symbol[]);   string symbols_Name    (/*SYMBOL*/int symbols[], int i);
   string symbol_Description          (/*SYMBOL*/int symbol[]);
   string symbol_Origin               (/*SYMBOL*/int symbol[]);
   string symbol_AltName              (/*SYMBOL*/int symbol[]);
   string symbol_BaseCurrency         (/*SYMBOL*/int symbol[]);
   int    symbol_Group                (/*SYMBOL*/int symbol[]);
   int    symbol_Digits               (/*SYMBOL*/int symbol[]);
   int    symbol_TradeMode            (/*SYMBOL*/int symbol[]);
   int    symbol_BackgroundColor      (/*SYMBOL*/int symbol[]);
   int    symbol_ArrayKey             (/*SYMBOL*/int symbol[]);   int    symbols_ArrayKey(/*SYMBOL*/int symbols[], int i);
   int    symbol_Id                   (/*SYMBOL*/int symbol[]);   int    symbols_Id      (/*SYMBOL*/int symbols[], int i);
   int    symbol_Spread               (/*SYMBOL*/int symbol[]);
   bool   symbol_SwapEnabled          (/*SYMBOL*/int symbol[]);
   int    symbol_SwapType             (/*SYMBOL*/int symbol[]);
   double symbol_SwapLongValue        (/*SYMBOL*/int symbol[]);
   double symbol_SwapShortValue       (/*SYMBOL*/int symbol[]);
   int    symbol_SwapTripleRolloverDay(/*SYMBOL*/int symbol[]);
   double symbol_ContractSize         (/*SYMBOL*/int symbol[]);
   int    symbol_StopDistance         (/*SYMBOL*/int symbol[]);
   double symbol_MarginInit           (/*SYMBOL*/int symbol[]);
   double symbol_MarginMaintenance    (/*SYMBOL*/int symbol[]);
   double symbol_MarginHedged         (/*SYMBOL*/int symbol[]);
   double symbol_MarginDivider        (/*SYMBOL*/int symbol[]);
   double symbol_PointSize            (/*SYMBOL*/int symbol[]);
   double symbol_PointsPerUnit        (/*SYMBOL*/int symbol[]);
   string symbol_MarginCurrency       (/*SYMBOL*/int symbol[]);

   // Setter
   bool   symbol_SetName              (/*SYMBOL*/int symbol[], string name       );
   bool   symbol_SetDescription       (/*SYMBOL*/int symbol[], string description);
   bool   symbol_SetBaseCurrency      (/*SYMBOL*/int symbol[], string currency   );
   bool   symbol_SetGroup             (/*SYMBOL*/int symbol[], int    index      );
   bool   symbol_SetDigits            (/*SYMBOL*/int symbol[], int    digits     );
   bool   symbol_SetBackgroundColor   (/*SYMBOL*/int symbol[], color  bgColor    );
   bool   symbol_SetId                (/*SYMBOL*/int symbol[], int    id         );   bool symbols_SetId(/*SYMBOL*/int symbols[], int i, int id);
   bool   symbol_SetMarginCurrency    (/*SYMBOL*/int symbol[], string currency   );

   // Helper
   bool   SortSymbols(/*SYMBOL*/int symbols[], int size);
#import
