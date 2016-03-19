/**
 * MT4 struct SYMBOL_GROUP (Dateiformat "symgroups.raw")
 *
 * @see  Definition in MT4Expander::Expander.h
 */

#import "Expander.dll"
   // Getter
   string sg_Name               (/*SYMBOL_GROUP*/int sg[]);
   string sg_Description        (/*SYMBOL_GROUP*/int sg[]);
   color  sg_BackgroundColor    (/*SYMBOL_GROUP*/int sg[]);

   string sgs_Name              (/*SYMBOL_GROUP*/int sg[], int i);
   string sgs_Description       (/*SYMBOL_GROUP*/int sg[], int i);
   color  sgs_BackgroundColor   (/*SYMBOL_GROUP*/int sg[], int i);

   // Setter
   bool   sg_SetName            (/*SYMBOL_GROUP*/int sg[],        string name           );
   bool   sg_SetDescription     (/*SYMBOL_GROUP*/int sg[],        string description    );
   bool   sg_SetBackgroundColor (/*SYMBOL_GROUP*/int sg[],        color  backgroundColor);

   bool   sgs_SetName           (/*SYMBOL_GROUP*/int sg[], int i, string name           );
   bool   sgs_SetDescription    (/*SYMBOL_GROUP*/int sg[], int i, string description    );
   bool   sgs_SetBackgroundColor(/*SYMBOL_GROUP*/int sg[], int i, color  backgroundColor);
#import
