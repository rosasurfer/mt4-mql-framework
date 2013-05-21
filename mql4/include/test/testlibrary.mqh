/**
 *
 */
#import "test/testlibrary.ex4"

   void GlobalPrimitives(bool st, bool in);
   void LocalPrimitives (         bool in);

   void GlobalArrays(bool st, bool si, bool in);
   void LocalArrays (bool st, bool si, bool in);


   // Library-Management
   int  testlib_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, bool logging, int lpICUSTOM, int initFlags, int uninitializeReason);

#import
