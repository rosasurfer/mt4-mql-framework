
int    g.int;
double g.double;
string g.string;

int    g.int.in    = 0;
double g.double.in = 0;
string g.string.in = "";

static int    g.int.st;
static double g.double.st;
static string g.string.st;

static int    g.int.st.in    = 0;
static double g.double.st.in = 0;
static string g.string.st.in = "";


/**
 *
 */
void GlobalPrimitives(bool st, bool in) {
   if (IsError(catch("GlobalPrimitives(0.1)")))
      return;

   if (st) {
      if (in) {
         debug("GlobalPrimitives(static in=1)  g.int="+ g.int.st.in +"  g.double="+ DoubleToStr(g.double.st.in, 1) +"  g.string="+ StringToStr(g.string.st.in));
         g.int.st.in++;
         g.double.st.in = g.double.st.in + 1;
            if (!StringLen(g.string.st.in))
               g.string.st.in = "`";
         g.string.st.in = CharToStr(StringGetChar(g.string.st.in, 0) + 1);
      }
      else /*(!in)*/ {
         debug("GlobalPrimitives(static in=0)   g.int="+ g.int.st +"  g.double="+ DoubleToStr(g.double.st, 1) +"  g.string="+ StringToStr(g.string.st));
         g.int.st++;
         g.double.st = g.double.st +1;
            if (!StringLen(g.string.st))
               g.string.st = "`";
         g.string.st = CharToStr(StringGetChar(g.string.st, 0) + 1);
      }
   }
   else /*(!st)*/ {
      if (in) {
         debug("GlobalPrimitives(in=1)  g.int="+ g.int.in +"  g.double="+ DoubleToStr(g.double.in, 1) +"  g.string="+ StringToStr(g.string.in));
         g.int.in++;
         g.double.in = g.double.in + 1;
            if (!StringLen(g.string.in))
               g.string.in = "`";
         g.string.in = CharToStr(StringGetChar(g.string.in, 0) + 1);
      }
      else /*(!in)*/ {
         debug("GlobalPrimitives(in=0)   g.int="+ g.int +"  g.double="+ DoubleToStr(g.double, 1) +"  g.string="+ StringToStr(g.string));
         g.int++;
         g.double = g.double +1;
            if (!StringLen(g.string))
               g.string = "`";
         g.string = CharToStr(StringGetChar(g.string, 0) + 1);
      }
   }
}


/**
 *
 */
void LocalPrimitives(bool in) {
   static int    l.int;
   static double l.double;
   static string l.string;

   static int    l.int.i    = 0;
   static double l.double.i = 0;
   static string l.string.i = "";

   if (in) {
      debug("LocalPrimitives(in=1)   l.int="+ l.int.i +"  l.double="+ DoubleToStr(l.double.i, 1) +"  l.string="+ StringToStr(l.string.i));
      l.int.i++;
      l.double.i = l.double.i + 1;
         if (!StringLen(l.string.i))
            l.string.i = "`";
      l.string.i = CharToStr(StringGetChar(l.string.i, 0) + 1);
   }
   else {
      debug("LocalPrimitives(in=0)   l.int="+ l.int +"  l.double="+ DoubleToStr(l.double, 1) +"  l.string="+ StringToStr(l.string));
      l.int++;
      l.double = l.double +1;
         if (!StringLen(l.string))
            l.string = "`";
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
void GlobalArrays(bool si, bool in) {
   if (!si && !in) {
      debug("GlobalArrays(si=0, in=0)   g.ints="+ IntsToStr(g.ints, NULL) +"  g.doubles="+ DoublesToStr(g.doubles, NULL) +"  g.strings="+ StringsToStr(g.strings, NULL));
      if (ArraySize(g.ints   ) != 2) ArrayResize(g.ints,    2);
      if (ArraySize(g.doubles) != 2) ArrayResize(g.doubles, 2);
      if (ArraySize(g.strings) != 2) ArrayResize(g.strings, 2);

      g.ints   [0]++;
      g.doubles[0] = g.doubles[0] +1;
         if (!StringLen(g.strings[0])) g.strings[0] = "`";
      g.strings[0] = CharToStr(StringGetChar(g.strings[0], 0) + 1);
   }

   if (si && !in) {
      debug("GlobalArrays(si=1, in=0)   g.ints="+ IntsToStr(g.ints.s, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.s, NULL) +"  g.strings="+ StringsToStr(g.strings.s, NULL));
      if (ArraySize(g.ints.s   ) != 2) ArrayResize(g.ints.s,    2);
      if (ArraySize(g.doubles.s) != 2) ArrayResize(g.doubles.s, 2);
      if (ArraySize(g.strings.s) != 2) ArrayResize(g.strings.s, 2);

      g.ints.s   [0]++;
      g.doubles.s[0] = g.doubles.s[0] + 1;
         if (!StringLen(g.strings.s[0]))
            g.strings.s[0] = "`";
      g.strings.s[0] = CharToStr(StringGetChar(g.strings.s[0], 0) + 1);
   }

   if (in) {
      debug("GlobalArrays(si="+ si +", in=1)   g.ints="+ IntsToStr(g.ints.i, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.i, NULL) +"  g.strings="+ StringsToStr(g.strings.i, NULL));
      if (ArraySize(g.ints.i   ) != 2) ArrayResize(g.ints.i,    2);
      if (ArraySize(g.doubles.i) != 2) ArrayResize(g.doubles.i, 2);
      if (ArraySize(g.strings.i) != 2) ArrayResize(g.strings.i, 2);

      g.ints.i   [0]++;
      g.doubles.i[0] = g.doubles.i[0] + 1;
         if (!StringLen(g.strings.i[0]))
            g.strings.i[0] = "`";
      g.strings.i[0] = CharToStr(StringGetChar(g.strings.i[0], 0) + 1);
   }
}


/**
 *
 */
void LocalArrays(bool st, bool si, bool in) {
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

   if (!si && !in) {
      debug("LocalArrays(si=0, in=0)   l.ints="+ IntsToStr(l.ints, NULL) +"  l.doubles="+ DoublesToStr(l.doubles, NULL) +"  l.strings="+ StringsToStr(l.strings, NULL));
      if (ArraySize(l.ints   ) != 2) ArrayResize(l.ints,    2);
      if (ArraySize(l.doubles) != 2) ArrayResize(l.doubles, 2);
      if (ArraySize(l.strings) != 2) ArrayResize(l.strings, 2);

      l.ints   [0]++;
      l.doubles[0] = l.doubles[0] +1;
         if (!StringLen(l.strings[0])) l.strings[0] = "`";
      l.strings[0] = CharToStr(StringGetChar(l.strings[0], 0) + 1);
   }

   if (si && !in) {
      debug("LocalArrays(si=1, in=0)   l.ints="+ IntsToStr(l.ints.s, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.s, NULL) +"  l.strings="+ StringsToStr(l.strings.s, NULL));
      if (ArraySize(l.ints.s   ) != 2) ArrayResize(l.ints.s,    2);
      if (ArraySize(l.doubles.s) != 2) ArrayResize(l.doubles.s, 2);
      if (ArraySize(l.strings.s) != 2) ArrayResize(l.strings.s, 2);

      l.ints.s   [0]++;
      l.doubles.s[0] = l.doubles.s[0] + 1;
         if (!StringLen(l.strings.s[0]))
            l.strings.s[0] = "`";
      l.strings.s[0] = CharToStr(StringGetChar(l.strings.s[0], 0) + 1);
   }

   if (in) {
      if (!st) {
         debug("LocalArrays(si="+ si +", in=1)   l.ints="+ IntsToStr(l.ints.i, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.i, NULL) +"  l.strings="+ StringsToStr(l.strings.i, NULL));
         if (ArraySize(l.ints.i   ) != 2) ArrayResize(l.ints.i,    2);
         if (ArraySize(l.doubles.i) != 2) ArrayResize(l.doubles.i, 2);
         if (ArraySize(l.strings.i) != 2) ArrayResize(l.strings.i, 2);

         l.ints.i   [0]++;
         l.doubles.i[0] = l.doubles.i[0] + 1;
            if (!StringLen(l.strings.i[0]))
               l.strings.i[0] = "`";
         l.strings.i[0] = CharToStr(StringGetChar(l.strings.i[0], 0) + 1);
      }
      else {
         debug("LocalArrays(static si="+ si +", in=1)   l.ints="+ IntsToStr(l.ints.s.i, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.s.i, NULL) +"  l.strings="+ StringsToStr(l.strings.s.i, NULL));
         if (ArraySize(l.ints.s.i   ) != 2) ArrayResize(l.ints.s.i,    2);
         if (ArraySize(l.doubles.s.i) != 2) ArrayResize(l.doubles.s.i, 2);
         if (ArraySize(l.strings.s.i) != 2) ArrayResize(l.strings.s.i, 2);

         l.ints.s.i   [0]++;
         l.doubles.s.i[0] = l.doubles.s.i[0] + 1;
            if (!StringLen(l.strings.s.i[0]))
               l.strings.s.i[0] = "`";
         l.strings.s.i[0] = CharToStr(StringGetChar(l.strings.s.i[0], 0) + 1);
      }
   }
}
