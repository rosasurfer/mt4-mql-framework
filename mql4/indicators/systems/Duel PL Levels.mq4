/**
 * Duel PL Levels
 *
 * Visualizes breakeven, profit and stoploss levels of a Duel sequence. The indicator gets its values from the expert running
 * in the same chart (online and in tester).
 *
 * @see  mql4/experts/Duel.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  Color.Breakeven = LimeGreen;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.Width      = 1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_BE_LONG          0                    // indicator buffer ids
#define MODE_BE_SHORT         1

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE

double beLong [];
double beShort[];

int drawType;


/**
 * Initialization
 *
 * @param  bool accountChange [optional] - whether called due to an account change event (default: no)
 *
 * @return int - error status
 */
int onInit(bool accountChange = false) {
   // validate inputs
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.Breakeven == 0xFF000000) Color.Breakeven = CLR_NONE;

   // Draw.Type
   string sValues[], sValue=StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                return(catch("onInit(1)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0) return(catch("onInit(2)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // buffer management
   SetIndexBuffer(MODE_BE_LONG,  beLong);  SetIndexEmptyValue(MODE_BE_LONG,  0);
   SetIndexBuffer(MODE_BE_SHORT, beShort); SetIndexEmptyValue(MODE_BE_SHORT, 0);

   // names, labels and display options
   IndicatorShortName(ProgramName());                    // chart tooltips and context menu
   SetIndexLabel(MODE_BE_LONG,   "Duel BE long");        // chart tooltips and "Data" window
   SetIndexLabel(MODE_BE_SHORT,  "Duel BE short");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(beLong)) return(logInfo("onTick(1)  size(beLong) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(beLong,  0);
      ArrayInitialize(beShort, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(beLong,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(beShort, Bars, ShiftedBars, 0);
   }

   // draw breakeven line
   if (__isChart) {
      beLong [0] = GetWindowDoubleA(__ExecutionContext[EC.hChart], "Duel.breakeven.long");
      beShort[0] = GetWindowDoubleA(__ExecutionContext[EC.hChart], "Duel.breakeven.short");
   }
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_BE_LONG,  draw_type, EMPTY, Draw.Width, Color.Breakeven);
   SetIndexStyle(MODE_BE_SHORT, draw_type, EMPTY, Draw.Width, Color.Breakeven);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.Breakeven=", ColorToStr(Color.Breakeven), ";", NL,
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),   ";", NL,
                            "Draw.Width=",      Draw.Width,                  ";")
   );
}
