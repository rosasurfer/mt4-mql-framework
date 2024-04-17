/**
 * Instance id related constants and global vars.
 */

#define INSTANCE_ID_MIN       1        // range of valid instance ids
#define INSTANCE_ID_MAX     999        //


int      instance.id;                  // actual instance id (also used to generate magic order numbers)
string   instance.name = "";
datetime instance.created;             // local system time (also in tester)
datetime instance.started;             // trade server time (modeled in tester)
datetime instance.stopped;             // trade server time (modeled in tester)
bool     instance.isTest;              // whether the instance is a test
int      instance.status;
double   instance.startEquity;
