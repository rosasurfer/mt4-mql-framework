
<br>2018-02-15

- function ```CommissionValue(double lots)``` to calculate the current symbol's commission rate for the specified lot size


<br>2018-01-30

- ```stdlib1::OrderMultiClose()``` supports the  flag ```OE_MULTICLOSE_NOHEDGE``` to skip hedging positions before close (useful in Tester)


<br>2018-01-29

- change return value of ```stdlib1::OrderSendEx()``` to ```NULL``` in case of errors


<br>2018-01-21

- new and enhanced implementation of the DEMA indicator
- new and enhanced implementation of the TEMA indicator


<br>2018-01-14

- ```stdfunctions::SetLastError()``` updates ```__STATUS_OFF``` if called in experts


<br>2018-01-07

- ```core/expert::CheckErrors()``` calls ```ShowStatus()``` only in case of detected errors
