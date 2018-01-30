
<br>2018-01-30

- ```stdlib1::OrderMultiClose()```: new flag ```OE_MULTICLOSE_NOFLAT``` to skip hedging before close (for Tester)


<br>2018-01-29

- change return value of ```stdlib1::OrderSendEx()``` to ```NULL``` in case of errors


<br>2018-01-21

- new and improved implementation of the DEMA indicator
- new and improved implementation of the TEMA indicator


<br>2018-01-14

- ```stdfunctions::SetLastError()``` updates ```__STATUS_OFF``` if called in experts


<br>2018-01-07

- ```core/expert::CheckErrors()``` calls ```ShowStatus()``` only in case of detected errors
