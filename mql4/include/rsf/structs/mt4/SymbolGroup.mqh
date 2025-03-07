/**
 * MT4 struct SYMBOL_GROUP (Dateiformat "symgroups.raw")
 *
 * Die Gr��e der Datei ist fix und enth�lt Platz f�r exakt 32 Gruppen. Einzelne Gruppen k�nnen undefiniert sein.
 *
 * @link  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/SymbolGroup.h
 */
#import "rsfMT4Expander.dll"
   // getters
   string sg_Name              (/*SYMBOL_GROUP*/int sg[]);                   string sgs_Name              (/*SYMBOL_GROUP*/int sg[], int i);
   string sg_Description       (/*SYMBOL_GROUP*/int sg[]);                   string sgs_Description       (/*SYMBOL_GROUP*/int sg[], int i);
   color  sg_BackgroundColor   (/*SYMBOL_GROUP*/int sg[]);                   color  sgs_BackgroundColor   (/*SYMBOL_GROUP*/int sg[], int i);

   // setters
   string sg_SetName           (/*SYMBOL_GROUP*/int sg[], string name   );   string sgs_SetName           (/*SYMBOL_GROUP*/int sg[], int i, string name   );
   string sg_SetDescription    (/*SYMBOL_GROUP*/int sg[], string descr  );   string sgs_SetDescription    (/*SYMBOL_GROUP*/int sg[], int i, string descr  );
   color  sg_SetBackgroundColor(/*SYMBOL_GROUP*/int sg[], color  bgColor);   color  sgs_SetBackgroundColor(/*SYMBOL_GROUP*/int sg[], int i, color  bgColor);
#import
