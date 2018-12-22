//
// MetaTrader structure FXT_TICK_405
//
// FXT-File Tickformat von Build ??? bis Build ???
//
// MetaQuotes hat trotz gleichbleibender Headerversion in Builds > 509 das Tickformat geändert.
//

template    "MT4 FXT Data"
description "Files '*.fxt'"

applies_to file
fixed_start  728
requires    -728  "95 01"               // Version = 405
multiple

begin
   { endsection
      UNIXDateTime "BarTime"
      double       "Open"
      move         8
      double       "High"
      move         -16
      double       "Low"
      move         8
      double       "Close"
      double       "Volume"
      UNIXDateTime "TickTime"
      uint32       "Bar State"
   }[3]
end
