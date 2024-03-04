/**
 * Instance id related constants and global vars.
 */

#define INSTANCE_ID_MIN       1        // range of valid instance ids
#define INSTANCE_ID_MAX     999        //


int      instance.id;                  // actual instance id
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;              // whether the instance is a test
int      instance.status;
double   instance.startEquity;
