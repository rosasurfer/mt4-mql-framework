/**
 * Tickdata Checker
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int IgnoreGapsOfUpToMinutes = 0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);
}


/*
Tick data analysis for EURUSD,H1
for test starting at Fri, 01.02.2013 04:00:00
=============================================


Summary
-------
File:                         EURUSD60_0.fxt (every tick)  81,747 kB
First tick:                   Fri, 01.02.2013 04:00:00
Last tick:                    Fri, 24.05.2013 23:54:47
Total ticks:                  1,609,680
Total bars:                   1,940
Avg ticks per bar:            829.7
Avg ticks per minute:         13.8
Avg ticks per second:         0.2

First price:                  1.3611'2
High price:                   1.3708'6
Low price:                    1.2754'3
Last price:                   1.2933'5
Max bar range:                122.6 pip (Wed, 22.05.2013 17:00:00)
Max price gap between bars:   169.2 pip (Mon, 18.03.2013 00:00:00, exc. weekends)
Max price gap between ticks:  169.2 pip (Mon, 18.03.2013 00:00:00, exc. weekends)
Max time gap between ticks:   1:05:30 h (Mon, 18.03.2013 00:00:00, exc. weekends)


Time gaps (skipping gaps of up to 5 minutes)
--------------------------------------------
Mon, 01.02.2013 22:54  ->  Tue, 02.02.2013 01:03  (1:09 h)
Tue, 08.02.2013 22:54  ->                  23:00  (0:03 h)
Wed, 11.02.2013 00:00  ->                  00:14  (0:02 h)
Thu, 15.02.2013 22:52  ->                  23:00  (0:03 h)
Fri, 18.02.2013 01:00  ->                  01:15  (0:03 h)
Mon, 18.02.2013 20:27  ->                  20:33  (0:03 h)
Tue, 22.02.2013 22:54  ->                  23:00  (0:03 h)
Wed, 01.03.2013 22:54  ->                  23:00  (0:03 h)
Thu, 08.03.2013 04:21  ->                  04:27  (0:03 h)
Fri, 08.03.2013 22:51  ->                  23:00  (0:03 h)
Mon, 15.03.2013 22:53  ->                  23:00  (0:03 h)
Tue, 22.03.2013 22:53  ->                  23:00  (0:03 h)
Wed, 29.03.2013 06:37  ->                  06:43  (0:03 h)
Thu, 29.03.2013 22:54  ->                  23:00  (0:03 h)
Fri, 19.04.2013 01:59  ->                  02:06  (0:03 h)
Thu, 13.05.2013 01:23  ->                  01:32  (0:03 h)
Fri, 16.05.2013 11:59  ->                  12:08  (0:03 h)
*/
