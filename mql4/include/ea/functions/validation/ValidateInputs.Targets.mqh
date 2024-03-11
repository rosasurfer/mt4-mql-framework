/**
 * Target related constants and global vars.
 */

double targets[4][4];               // partial profit targets and stops

#define T_DISTANCE      0           // indexes of targets[][]
#define T_CLOSE_PCT     1
#define T_REMAINDER     2
#define T_MOVE_STOP     3


/**
 * Validate StopLoss and TakeProfit targets and convert inputs to an array. Called from ValidateInputs() only.
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs.Targets() {
   // Initial.TakeProfit
   if (Initial.TakeProfit < 0)                                 return(!onInputError("ValidateInputs.Targets(1)  "+ instance.name +" invalid input parameter Initial.TakeProfit: "+ Initial.TakeProfit +" (must be >= 0)"));
   // Initial.StopLoss
   if (Initial.StopLoss < 0)                                   return(!onInputError("ValidateInputs.Targets(2)  "+ instance.name +" invalid input parameter Initial.StopLoss: "+ Initial.StopLoss +" (must be >= 0)"));

   // Target1
   if (Target1 < 0)                                            return(!onInputError("ValidateInputs.Targets(3)  "+ instance.name +" invalid input parameter Target1: "+ Target1 +" (must be >= 0)"));
   if (Target1.ClosePercent < 0 || Target1.ClosePercent > 100) return(!onInputError("ValidateInputs.Targets(4)  "+ instance.name +" invalid input parameter Target1.ClosePercent: "+ Target1.ClosePercent +" (must be from 0..100)"));
   if (Target1 && Target1.MoveStopTo > Target1)                return(!onInputError("ValidateInputs.Targets(5)  "+ instance.name +" invalid input parameter Target1.MoveStopTo: "+ Target1.MoveStopTo +" (must be < Target1)"));

   // Target2
   if (Target2 < 0)                                            return(!onInputError("ValidateInputs.Targets(6)  "+ instance.name +" invalid input parameter Target2: "+ Target2 +" (must be >= 0)"));
   if (Target2 && Target2 <= Target1)                          return(!onInputError("ValidateInputs.Targets(7)  "+ instance.name +" invalid input parameter Target2: "+ Target2 +" (must be > Target1)"));
   if (Target2.ClosePercent < 0 || Target2.ClosePercent > 100) return(!onInputError("ValidateInputs.Targets(8)  "+ instance.name +" invalid input parameter Target2.ClosePercent: "+ Target2.ClosePercent +" (must be from 0..100)"));
   if (Target2 && Target2.MoveStopTo > Target2)                return(!onInputError("ValidateInputs.Targets(9)  "+ instance.name +" invalid input parameter Target2.MoveStopTo: "+ Target2.MoveStopTo +" (must be < Target2)"));

   // Target3
   if (Target3 < 0)                                            return(!onInputError("ValidateInputs.Targets(10)  "+ instance.name +" invalid input parameter Target3: "+ Target3 +" (must be >= 0)"));
   if (Target3 && Target3 <= Target1)                          return(!onInputError("ValidateInputs.Targets(11)  "+ instance.name +" invalid input parameter Target3: "+ Target3 +" (must be > Target1)"));
   if (Target3 && Target3 <= Target2)                          return(!onInputError("ValidateInputs.Targets(12)  "+ instance.name +" invalid input parameter Target3: "+ Target3 +" (must be > Target2)"));
   if (Target3.ClosePercent < 0 || Target3.ClosePercent > 100) return(!onInputError("ValidateInputs.Targets(13)  "+ instance.name +" invalid input parameter Target3.ClosePercent: "+ Target3.ClosePercent +" (must be from 0..100)"));
   if (Target3 && Target3.MoveStopTo > Target3)                return(!onInputError("ValidateInputs.Targets(14)  "+ instance.name +" invalid input parameter Target3.MoveStopTo: "+ Target3.MoveStopTo +" (must be < Target3)"));

   // Target4
   if (Target4 < 0)                                            return(!onInputError("ValidateInputs.Targets(15)  "+ instance.name +" invalid input parameter Target4: "+ Target4 +" (must be >= 0)"));
   if (Target4 && Target4 <= Target1)                          return(!onInputError("ValidateInputs.Targets(16)  "+ instance.name +" invalid input parameter Target4: "+ Target4 +" (must be > Target1)"));
   if (Target4 && Target4 <= Target2)                          return(!onInputError("ValidateInputs.Targets(17)  "+ instance.name +" invalid input parameter Target4: "+ Target4 +" (must be > Target2)"));
   if (Target4 && Target4 <= Target3)                          return(!onInputError("ValidateInputs.Targets(18)  "+ instance.name +" invalid input parameter Target4: "+ Target4 +" (must be > Target3)"));
   if (Target4.ClosePercent < 0 || Target4.ClosePercent > 100) return(!onInputError("ValidateInputs.Targets(19)  "+ instance.name +" invalid input parameter Target4.ClosePercent: "+ Target4.ClosePercent +" (must be from 0..100)"));
   if (Target4 && Target4.MoveStopTo > Target4)                return(!onInputError("ValidateInputs.Targets(20)  "+ instance.name +" invalid input parameter Target4.MoveStopTo: "+ Target4.MoveStopTo +" (must be < Target4)"));

   // pre-calculate partial profits
   int closedPercent  = ifInt(Target1, Target1.ClosePercent, 0);
   double t1Close     = MathMin(Lots, Lots * closedPercent/100);
   double t1Remainder = NormalizeLots(NormalizeDouble(Lots - t1Close, 2), "", MODE_CEIL);

   closedPercent     += ifInt(Target2, Target2.ClosePercent, 0);
   double t2Close     = MathMin(t1Remainder, Lots * closedPercent/100 - t1Close);
   double t2Remainder = NormalizeLots(NormalizeDouble(Lots - t1Close - t2Close, 2), "", MODE_CEIL);

   closedPercent     += ifInt(Target3, Target3.ClosePercent, 0);
   double t3Close     = MathMin(t2Remainder, Lots * closedPercent/100 - t1Close - t2Close);
   double t3Remainder = NormalizeLots(NormalizeDouble(Lots - t1Close - t2Close - t3Close, 2), "", MODE_CEIL);

   closedPercent     += ifInt(Target4, Target4.ClosePercent, 0);
   double t4Close     = MathMin(t3Remainder, Lots * closedPercent/100 - t1Close - t2Close - t3Close);
   double t4Remainder = NormalizeLots(NormalizeDouble(Lots - t1Close - t2Close - t3Close - t4Close, 2), "", MODE_CEIL);

   // convert targets to array to optimize later processing
   targets[0][T_DISTANCE ] = Target1;
   targets[0][T_CLOSE_PCT] = Target1.ClosePercent;
   targets[0][T_REMAINDER] = t1Remainder;
   targets[0][T_MOVE_STOP] = Target1.MoveStopTo;

   targets[1][T_DISTANCE ] = Target2;
   targets[1][T_CLOSE_PCT] = Target2.ClosePercent;
   targets[1][T_REMAINDER] = t2Remainder;
   targets[1][T_MOVE_STOP] = Target2.MoveStopTo;

   targets[2][T_DISTANCE ] = Target3;
   targets[2][T_CLOSE_PCT] = Target3.ClosePercent;
   targets[2][T_REMAINDER] = t3Remainder;
   targets[2][T_MOVE_STOP] = Target3.MoveStopTo;

   targets[3][T_DISTANCE ] = Target4;
   targets[3][T_CLOSE_PCT] = Target4.ClosePercent;
   targets[3][T_REMAINDER] = t4Remainder;
   targets[3][T_MOVE_STOP] = Target4.MoveStopTo;

   return(!catch("ValidateInputs.Targets(21)"));
}


// backed-up input parameters
int    prev.Initial.TakeProfit;
int    prev.Initial.StopLoss;
int    prev.Target1;
int    prev.Target1.ClosePercent;
int    prev.Target1.MoveStopTo;
int    prev.Target2;
int    prev.Target2.ClosePercent;
int    prev.Target2.MoveStopTo;
int    prev.Target3;
int    prev.Target3.ClosePercent;
int    prev.Target3.MoveStopTo;
int    prev.Target4;
int    prev.Target4.ClosePercent;
int    prev.Target4.MoveStopTo;

// backed-up runtime variables affected by changing input parameters
double prev.targets[][4];


/**
 * When input parameters are changed at runtime, input errors must be handled gracefully. To enable the EA to continue in
 * case of input errors, it must be possible to restore previous valid inputs. This also applies to programmatic changes to
 * input parameters which do not survive init cycles. The previous input parameters are therefore backed up in deinit() and
 * can be restored in init() if necessary.
 *
 * Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs.Targets() {
   if (!catch("BackupInputs.Targets(1)")) {
      // input parameters
      prev.Initial.TakeProfit   = Initial.TakeProfit;
      prev.Initial.StopLoss     = Initial.StopLoss;
      prev.Target1              = Target1;
      prev.Target1.ClosePercent = Target1.ClosePercent;
      prev.Target1.MoveStopTo   = Target1.MoveStopTo;
      prev.Target2              = Target2;
      prev.Target2.ClosePercent = Target2.ClosePercent;
      prev.Target2.MoveStopTo   = Target2.MoveStopTo;
      prev.Target3              = Target3;
      prev.Target3.ClosePercent = Target3.ClosePercent;
      prev.Target3.MoveStopTo   = Target3.MoveStopTo;
      prev.Target4              = Target4;
      prev.Target4.ClosePercent = Target4.ClosePercent;
      prev.Target4.MoveStopTo   = Target4.MoveStopTo;

      // affected runtime variables
      ArrayResize(prev.targets, ArrayCopy(prev.targets, targets));

      // we didn't check ArraySize(source), instead we handle a generated error
      int error = GetLastError();
      if (error && error!=ERR_INVALID_PARAMETER) catch("BackupInputs.Targets(2)", error);
   }
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs.Targets() {
   if (!catch("RestoreInputs.Targets(1)")) {
      // input parameters
      Initial.TakeProfit   = prev.Initial.TakeProfit;
      Initial.StopLoss     = prev.Initial.StopLoss;
      Target1              = prev.Target1;
      Target1.ClosePercent = prev.Target1.ClosePercent;
      Target1.MoveStopTo   = prev.Target1.MoveStopTo;
      Target2              = prev.Target2;
      Target2.ClosePercent = prev.Target2.ClosePercent;
      Target2.MoveStopTo   = prev.Target2.MoveStopTo;
      Target3              = prev.Target3;
      Target3.ClosePercent = prev.Target3.ClosePercent;
      Target3.MoveStopTo   = prev.Target3.MoveStopTo;
      Target4              = prev.Target4;
      Target4.ClosePercent = prev.Target4.ClosePercent;
      Target4.MoveStopTo   = prev.Target4.MoveStopTo;

      // affected runtime variables
      ArrayResize(targets, ArrayCopy(targets, prev.targets));

      // we didn't check ArraySize(source), instead we handle a generated error
      int error = GetLastError();
      if (error && error!=ERR_INVALID_PARAMETER) catch("RestoreInputs.Targets(2)", error);
   }
}
