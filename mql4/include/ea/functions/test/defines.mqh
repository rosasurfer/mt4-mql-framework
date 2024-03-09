/**
 * Global vars for test debug settings (configurable via framework config).
 */

bool test.reduceStatusWrites   = true;       // whether to reduce status file I/O in tester

bool test.onPositionOpenPause  = false;      // whether to pause a visual test after a position open signal
bool test.onPositionClosePause = false;      // whether to pause a visual test after a position close signal
bool test.onSessionBreakPause  = false;      // whether to pause a visual test after a session break signal
bool test.onStopPause          = true;       // whether to pause a visual test after a stop signal
