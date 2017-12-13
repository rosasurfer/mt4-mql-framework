
/**
 * Set lots.startSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetLotsStartSize(double value) {
   if (lots.startSize != value) {
      lots.startSize = value;

      if (__CHART) {
         if (!value) str.lots.startSize = "-";
         else        str.lots.startSize = NumberToStr(value, ".1+");
      }
   }
   return(value);
}


/**
 * Set grid.currentSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetGridCurrentSize(double value) {
   if (grid.currentSize != value) {
      grid.currentSize = value;

      if (__CHART) {
         if (!value) str.grid.currentSize = "-";
         else        str.grid.currentSize = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set grid.minSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetGridMinSize(double value) {
   if (grid.minSize != value) {
      grid.minSize = value;

      if (__CHART) {
         if (!value) str.grid.minSize = "-";
         else        str.grid.minSize = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.slPrice and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionSlPrice(double value) {
   if (position.slPrice != value) {
      position.slPrice = value;

      if (__CHART) {
         if (!value) str.position.slPrice = "-";
         else        str.position.slPrice = NumberToStr(value, SubPipPriceFormat);
      }
   }
   return(value);
}


/**
 * Set the string representation of input parameter TakeProfit.Pips.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionTpPip(double value) {
   if (__CHART) {
      if (!value) str.position.tpPip = "-";
      else        str.position.tpPip = DoubleToStr(value, 1) +" pip";
   }
   return(value);
}


/**
 * Set position.plPip and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPip(double value) {
   if (position.plPip != value) {
      position.plPip = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPip = "-";
         else                      str.position.plPip = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.plPipMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPipMin(double value) {
   if (position.plPipMin != value) {
      position.plPipMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPipMin = "-";
         else                      str.position.plPipMin = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.plPipMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPipMax(double value) {
   if (position.plPipMax != value) {
      position.plPipMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPipMax = "-";
         else                      str.position.plPipMax = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.plUPip and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPip(double value) {
   if (position.plUPip != value) {
      position.plUPip = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPip = "-";
         else                      str.position.plUPip = DoubleToStr(value, 1) +" upip";
      }
   }
   return(value);
}


/**
 * Set position.plUPipMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPipMin(double value) {
   if (position.plUPipMin != value) {
      position.plUPipMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPipMin = "-";
         else                      str.position.plUPipMin = DoubleToStr(value, 1) +" upip";
      }
   }
   return(value);
}


/**
 * Set position.plUPipMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPipMax(double value) {
   if (position.plUPipMax != value) {
      position.plUPipMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPipMax = "-";
         else                      str.position.plUPipMax = DoubleToStr(value, 1) +" upip";
      }
   }
   return(value);
}


/**
 * Set position.plPct and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPct(double value) {
   if (position.plPct != value) {
      position.plPct = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPct = "-";
         else                      str.position.plPct = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}


/**
 * Set position.plPctMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPctMin(double value) {
   if (position.plPctMin != value) {
      position.plPctMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPctMin = "-";
         else                      str.position.plPctMin = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}


/**
 * Set position.plPctMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPctMax(double value) {
   if (position.plPctMax != value) {
      position.plPctMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPctMax = "-";
         else                      str.position.plPctMax = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}
