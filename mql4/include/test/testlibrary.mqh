/**
 *
 */
#import "test/testlibrary.ex4"

   void GlobalPrimitives(bool st, bool in);
   void LocalPrimitives(bool st, bool in);

   void GlobalArrays(bool si, bool in);
   void LocalArrays(bool st, bool si, bool in);


   // Library-Management
   int  testlib_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, int _iCustom, int initFlags, int uninitializeReason);

#import
