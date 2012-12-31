/**
 *
 */
int    g.int;
double g.double;
string g.string;

int    g.int.i    = 0;
double g.double.i = 0;
string g.string.i = "";


/**
 *
 */
void GlobalPrimitives(bool init) {
   if (init) {
      debug("GlobalPrimitives(i="+ init +")   g.int="+ g.int.i +"   g.double="+ DoubleToStr(g.double.i, 1) +"   g.string="+ StringConcatenate("\"", g.string.i, "\""));
      g.int.i++;
      g.double.i = g.double.i + 1;
         if (!StringLen(g.string.i))
            g.string.i = "a";
      g.string.i = CharToStr(StringGetChar(g.string.i, 0) + 1);
   }
   else {
      debug("GlobalPrimitives(i="+ init +")   g.int="+ g.int +"   g.double="+ DoubleToStr(g.double, 1) +"   g.string="+ StringConcatenate("\"", g.string, "\""));
      g.int++;
      g.double = g.double +1;
         if (!StringLen(g.string))
            g.string = "a";
      g.string = CharToStr(StringGetChar(g.string, 0) + 1);
   }
}


/**
 *
 */
void LocalPrimitives(bool init) {
   static int    l.int;
   static double l.double;
   static string l.string;

   static int    l.int.i    = 0;
   static double l.double.i = 0;
   static string l.string.i = "";

   if (init) {
      debug("LocalPrimitives(i="+ init +")   l.int="+ l.int.i +"   l.double="+ DoubleToStr(l.double.i, 1) +"   l.string="+ StringConcatenate("\"", l.string.i, "\""));
      l.int.i++;
      l.double.i = l.double.i + 1;
         if (!StringLen(l.string.i))
            l.string.i = "a";
      l.string.i = CharToStr(StringGetChar(l.string.i, 0) + 1);
   }
   else {
      debug("LocalPrimitives(i="+ init +")   l.int="+ l.int +"   l.double="+ DoubleToStr(l.double, 1) +"   l.string="+ StringConcatenate("\"", l.string, "\""));
      l.int++;
      l.double = l.double +1;
         if (!StringLen(l.string))
            l.string = "a";
      l.string = CharToStr(StringGetChar(l.string, 0) + 1);
   }
}


int    g.ints   [];
double g.doubles[];
string g.strings[];

int    g.ints.s   [1];
double g.doubles.s[1];
string g.strings.s[1];

static int    g.ints.i   [] = { 0};
static double g.doubles.i[] = { 0};
static string g.strings.i[] = {""};


/**
 *
 */
void GlobalArrays(bool sized, bool init) {
   if (!sized && !init) {
      debug("GlobalArrays(s=0, i=0)   g.ints="+ IntsToStr(g.ints, NULL) +"   g.doubles="+ DoublesToStr(g.doubles, NULL) +"   g.strings="+ StringsToStr(g.strings, NULL));
      if (ArraySize(g.ints   ) != 2) ArrayResize(g.ints,    2);
      if (ArraySize(g.doubles) != 2) ArrayResize(g.doubles, 2);
      if (ArraySize(g.strings) != 2) ArrayResize(g.strings, 2);

      g.ints   [0]++;
      g.doubles[0] = g.doubles[0] +1;
         if (!StringLen(g.strings[0])) g.strings[0] = "a";
      g.strings[0] = CharToStr(StringGetChar(g.strings[0], 0) + 1);
   }

   if (sized && !init) {
      debug("GlobalArrays(s=1, i=0)   g.ints="+ IntsToStr(g.ints.s, NULL) +"   g.doubles="+ DoublesToStr(g.doubles.s, NULL) +"   g.strings="+ StringsToStr(g.strings.s, NULL));
      if (ArraySize(g.ints.s   ) != 2) ArrayResize(g.ints.s,    2);
      if (ArraySize(g.doubles.s) != 2) ArrayResize(g.doubles.s, 2);
      if (ArraySize(g.strings.s) != 2) ArrayResize(g.strings.s, 2);

      g.ints.s   [0]++;
      g.doubles.s[0] = g.doubles.s[0] + 1;
         if (!StringLen(g.strings.s[0]))
            g.strings.s[0] = "a";
      g.strings.s[0] = CharToStr(StringGetChar(g.strings.s[0], 0) + 1);
   }

   if (init) {
      debug("GlobalArrays(s=0, i=1)   g.ints="+ IntsToStr(g.ints.i, NULL) +"   g.doubles="+ DoublesToStr(g.doubles.i, NULL) +"   g.strings="+ StringsToStr(g.strings.i, NULL));
      if (ArraySize(g.ints.i   ) != 2) ArrayResize(g.ints.i,    2);
      if (ArraySize(g.doubles.i) != 2) ArrayResize(g.doubles.i, 2);
      if (ArraySize(g.strings.i) != 2) ArrayResize(g.strings.i, 2);

      g.ints.i   [0]++;
      g.doubles.i[0] = g.doubles.i[0] + 1;
         if (!StringLen(g.strings.i[0]))
            g.strings.i[0] = "a";
      g.strings.i[0] = CharToStr(StringGetChar(g.strings.i[0], 0) + 1);
   }
}


/**
 *
 */
void LocalArrays(bool sized, bool init, bool stat) {
   int    l.ints   [];
   double l.doubles[];
   string l.strings[];

   int    l.ints.s   [1];
   double l.doubles.s[1];
   string l.strings.s[1];

   int    l.ints.i   [] = { 0};
   double l.doubles.i[] = { 0};
   string l.strings.i[] = {""};

   static int    l.ints.s.i   [] = { 0};
   static double l.doubles.s.i[] = { 0};
   static string l.strings.s.i[] = {""};

   if (!sized && !init) {
      debug("LocalArrays(s=0, i=0)   l.ints="+ IntsToStr(l.ints, NULL) +"   l.doubles="+ DoublesToStr(l.doubles, NULL) +"   l.strings="+ StringsToStr(l.strings, NULL));
      if (ArraySize(l.ints   ) != 2) ArrayResize(l.ints,    2);
      if (ArraySize(l.doubles) != 2) ArrayResize(l.doubles, 2);
      if (ArraySize(l.strings) != 2) ArrayResize(l.strings, 2);

      l.ints   [0]++;
      l.doubles[0] = l.doubles[0] +1;
         if (!StringLen(l.strings[0])) l.strings[0] = "a";
      l.strings[0] = CharToStr(StringGetChar(l.strings[0], 0) + 1);
   }

   if (sized && !init) {
      debug("LocalArrays(s=1, i=0)   l.ints="+ IntsToStr(l.ints.s, NULL) +"   l.doubles="+ DoublesToStr(l.doubles.s, NULL) +"   l.strings="+ StringsToStr(l.strings.s, NULL));
      if (ArraySize(l.ints.s   ) != 2) ArrayResize(l.ints.s,    2);
      if (ArraySize(l.doubles.s) != 2) ArrayResize(l.doubles.s, 2);
      if (ArraySize(l.strings.s) != 2) ArrayResize(l.strings.s, 2);

      l.ints.s   [0]++;
      l.doubles.s[0] = l.doubles.s[0] + 1;
         if (!StringLen(l.strings.s[0]))
            l.strings.s[0] = "a";
      l.strings.s[0] = CharToStr(StringGetChar(l.strings.s[0], 0) + 1);
   }

   if (init) {
      if (!stat) {
         debug("LocalArrays(s=0, i=1)   l.ints="+ IntsToStr(l.ints.i, NULL) +"   l.doubles="+ DoublesToStr(l.doubles.i, NULL) +"   l.strings="+ StringsToStr(l.strings.i, NULL));
         if (ArraySize(l.ints.i   ) != 2) ArrayResize(l.ints.i,    2);
         if (ArraySize(l.doubles.i) != 2) ArrayResize(l.doubles.i, 2);
         if (ArraySize(l.strings.i) != 2) ArrayResize(l.strings.i, 2);

         l.ints.i   [0]++;
         l.doubles.i[0] = l.doubles.i[0] + 1;
            if (!StringLen(l.strings.i[0]))
               l.strings.i[0] = "a";
         l.strings.i[0] = CharToStr(StringGetChar(l.strings.i[0], 0) + 1);
      }
      else {
         debug("LocalArrays(static s=0, i=1)   l.ints="+ IntsToStr(l.ints.s.i, NULL) +"   l.doubles="+ DoublesToStr(l.doubles.s.i, NULL) +"   l.strings="+ StringsToStr(l.strings.s.i, NULL));
         if (ArraySize(l.ints.s.i   ) != 2) ArrayResize(l.ints.s.i,    2);
         if (ArraySize(l.doubles.s.i) != 2) ArrayResize(l.doubles.s.i, 2);
         if (ArraySize(l.strings.s.i) != 2) ArrayResize(l.strings.s.i, 2);

         l.ints.s.i   [0]++;
         l.doubles.s.i[0] = l.doubles.s.i[0] + 1;
            if (!StringLen(l.strings.s.i[0]))
               l.strings.s.i[0] = "a";
         l.strings.s.i[0] = CharToStr(StringGetChar(l.strings.s.i[0], 0) + 1);
      }
   }
}
