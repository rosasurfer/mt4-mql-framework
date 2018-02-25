
<br>2018-02-25

- History had to be rewritten, run:
  ```bash
  git checkout <branch-name>
  git reset --hard origin/<branch-name>
  ```
- Each non-master branch has a linked issue in the GitHub issue tracker for general discussion.


<br>2018-02-24

- TriEMA indicator (calculation base for Trix oscillator)


<br>2018-02-15

- function ```CommissionValue(double lots)``` to calculate the current symbol's commission rate for the specified lot size


<br>2018-01-30

- ```stdlib1::OrderMultiClose()``` supports the  flag ```OE_MULTICLOSE_NOHEDGE``` to skip hedging positions before close (useful in Tester)


<br>2018-01-29

- change return value of ```stdlib1::OrderSendEx()``` to ```NULL``` in case of errors


<br>2018-01-21

- new and improved implementation of the DEMA indicator
- new and improved implementation of the TEMA indicator


<br>2018-01-14

- ```stdfunctions::SetLastError()``` updates ```__STATUS_OFF``` if called in experts


<br>2018-01-07

- ```core/expert::CheckErrors()``` calls ```ShowStatus()``` only in case of detected errors
