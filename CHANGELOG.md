
<br>2018-03-04
- ```functions/@Trend.UpdateDirection()``` now has a parameter ```bool enableColoring``` to toggle trend line coloring
- improved implementation of the Trix indicator


<br>2018-02-24
- TriEMA indicator as calculation base for the Trix oscillator


<br>2018-02-15
- new function ```stdfunctions/CommissionValue(double lots)``` to calculate the current symbol's commission rate for the
  specified lot size


<br>2018-01-30
- ```stdlib1::OrderMultiClose()``` now supports flag ```OE_MULTICLOSE_NOHEDGE``` to skip hedging positions before close
  (mainly for use in Tester)


<br>2018-01-29
- ```stdlib1::OrderSendEx()``` now returns ```NULL``` in case of errors


<br>2018-01-21
- new and improved implementation of the DEMA indicator
- new and improved implementation of the TEMA indicator


<br>2018-01-14
- ```stdfunctions::SetLastError()``` now updates ```__STATUS_OFF``` if called in experts


<br>2018-01-07
- ```core/expert::CheckErrors()``` now calls ```ShowStatus()``` only in case of detected errors
