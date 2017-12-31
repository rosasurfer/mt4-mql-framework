
/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int uninitReason = UninitializeReason();

   // clean-up created chart objects
   if (uninitReason!=UR_CHARTCHANGE && uninitReason!=UR_PARAMETERS) {
      if (!IsTesting()) DeleteRegisteredObjects(NULL);
   }

   // store runtime status
   if (uninitReason==UR_CLOSE || uninitReason==UR_CHARTCLOSE || uninitReason==UR_RECOMPILE) {
      if (!IsTesting()) StoreRuntimeStatus();
   }
   return(last_error);
}


/**
 * Save input parameters and runtime status in the chart to be able to continue a sequence after terminal re-start, profile
 * change or recompilation.
 *
 * @return bool - success status
 */
bool StoreRuntimeStatus() {
   // sequence id
   int sequenceId, size = ArraySize(position.tickets);
   if (size != 0)
      sequenceId = position.tickets[0];
   Chart.StoreInt   (__NAME__ +".id", sequenceId);

   // input parameters
   Chart.StoreDouble(__NAME__ +".input.Lots.StartSize",            Lots.StartSize           );
   Chart.StoreInt   (__NAME__ +".input.Lots.StartVola.Percent",    Lots.StartVola.Percent   );
   Chart.StoreDouble(__NAME__ +".input.Lots.Multiplier",           Lots.Multiplier          );
   Chart.StoreString(__NAME__ +".input.Start.Mode",                Start.Mode               );
   Chart.StoreDouble(__NAME__ +".input.TakeProfit.Pips",           TakeProfit.Pips          );
   Chart.StoreBool  (__NAME__ +".input.TakeProfit.Continue",       TakeProfit.Continue      );
   Chart.StoreInt   (__NAME__ +".input.StopLoss.Percent",          StopLoss.Percent         );
   Chart.StoreBool  (__NAME__ +".input.StopLoss.Continue",         StopLoss.Continue        );
   Chart.StoreDouble(__NAME__ +".input.Grid.Min.Pips",             Grid.Min.Pips            );
   Chart.StoreDouble(__NAME__ +".input.Grid.Max.Pips",             Grid.Max.Pips            );
   Chart.StoreBool  (__NAME__ +".input.Grid.Contractable",         Grid.Contractable        );
   Chart.StoreInt   (__NAME__ +".input.Grid.Range.Periods",        Grid.Range.Periods       );
   Chart.StoreInt   (__NAME__ +".input.Grid.Range.Divider",        Grid.Range.Divider       );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.Pips",           Exit.Trail.Pips          );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.MinProfit.Pips", Exit.Trail.MinProfit.Pips);

   // runtime status
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_INVALID_INPUT", __STATUS_INVALID_INPUT);
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_OFF",           __STATUS_OFF          );
   Chart.StoreInt   (__NAME__ +".runtime.__STATUS_OFF.reason",    __STATUS_OFF.reason   );
   Chart.StoreDouble(__NAME__ +".runtime.lots.calculatedSize",    lots.calculatedSize   );
   Chart.StoreDouble(__NAME__ +".runtime.lots.startSize",         lots.startSize        );
   Chart.StoreInt   (__NAME__ +".runtime.lots.startVola",         lots.startVola        );
   Chart.StoreInt   (__NAME__ +".runtime.grid.level",             grid.level            );
   Chart.StoreDouble(__NAME__ +".runtime.grid.currentSize",       grid.currentSize      );
   Chart.StoreDouble(__NAME__ +".runtime.grid.minSize",           grid.minSize          );
   Chart.StoreDouble(__NAME__ +".runtime.position.startEquity",   position.startEquity  );
   Chart.StoreDouble(__NAME__ +".runtime.position.maxDrawdown",   position.maxDrawdown  );
   Chart.StoreDouble(__NAME__ +".runtime.position.slPrice",       position.slPrice      );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPip",         position.plPip        );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMin",      position.plPipMin     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMax",      position.plPipMax     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPip",        position.plUPip       );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMin",     position.plUPipMin    );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMax",     position.plUPipMax    );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPct",         position.plPct        );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMin",      position.plPctMin     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMax",      position.plPctMax     );

   return(!catch("StoreRuntimeStatus(1)"));
}
