/**
 * MT4 struct SYMBOL_GROUP (Dateiformat "symgroups.raw")
 *
 * @see  Definition in MT4Expander::Expander.h
 */

#import "Expander.dll"
   // Getter
   string   sg_Name               (/*SYMBOL_GROUP*/int sg[]);
   string   sg_Description        (/*SYMBOL_GROUP*/int sg[]);
   color    sg_BackgroundColor    (/*SYMBOL_GROUP*/int sg[]);

   string   sgs_Name              (/*SYMBOL_GROUP*/int sg[][], int i);
   string   sgs_Description       (/*SYMBOL_GROUP*/int sg[][], int i);
   color    sgs_BackgroundColor   (/*SYMBOL_GROUP*/int sg[][], int i);

   // Setter
   string   sg_setName            (/*SYMBOL_GROUP*/int sg[],          string name           );
   string   sg_setDescription     (/*SYMBOL_GROUP*/int sg[],          string description    );
   color    sg_setBackgroundColor (/*SYMBOL_GROUP*/int sg[],          color  backgroundColor);

   string   sgs_setName           (/*SYMBOL_GROUP*/int sg[][], int i, string name           );
   string   sgs_setDescription    (/*SYMBOL_GROUP*/int sg[][], int i, string description    );
   color    sgs_setBackgroundColor(/*SYMBOL_GROUP*/int sg[][], int i, color  backgroundColor);
#import
