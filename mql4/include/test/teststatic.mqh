
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

   static int    l.int.in    = 0;
   static double l.double.in = 0;
   static string l.string.in = "";

   if (in) {
      debug("LocalPrimitives(in=1)   l.int="+ l.int.in +"  l.double="+ DoubleToStr(l.double.in, 1) +"  l.string="+ StringToStr(l.string.in));
      l.int.in++;
      l.double.in = l.double.in + 1;
         if (!StringLen(l.string.in))
            l.string.in = "`";
      l.string.in = CharToStr(StringGetChar(l.string.in, 0) + 1);
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

int    g.ints.si   [1];
double g.doubles.si[1];
string g.strings.si[1];

int    g.ints.in   [] = { 0};
double g.doubles.in[] = { 0};
string g.strings.in[] = {""};

int    g.ints.si.in   [1] = { 0};
double g.doubles.si.in[1] = { 0};
string g.strings.si.in[1] = {""};

static int    g.ints.st   [];
static double g.doubles.st[];
static string g.strings.st[];

static int    g.ints.st.si   [1];
static double g.doubles.st.si[1];
static string g.strings.st.si[1];

static int    g.ints.st.in   [] = { 0};
static double g.doubles.st.in[] = { 0};
static string g.strings.st.in[] = {""};

static int    g.ints.st.si.in   [1] = { 0};
static double g.doubles.st.si.in[1] = { 0};
static string g.strings.st.si.in[1] = {""};


/**
 *
 */
void GlobalArrays(bool st, bool si, bool in) {
   if (st) {
      if (si) {
         if (in) {
            debug("GlobalArrays(static si=1, in=1)   g.ints="+ IntsToStr(g.ints.st.si.in, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.st.si.in, NULL) +"  g.strings="+ StringsToStr(g.strings.st.si.in, NULL));
            if (ArraySize(g.ints.st.si.in   ) != 2) ArrayResize(g.ints.st.si.in,    2);
            if (ArraySize(g.doubles.st.si.in) != 2) ArrayResize(g.doubles.st.si.in, 2);
            if (ArraySize(g.strings.st.si.in) != 2) ArrayResize(g.strings.st.si.in, 2);

            g.ints.st.si.in   [0]++;
            g.doubles.st.si.in[0] = g.doubles.st.si.in[0] + 1;
               if (!StringLen(g.strings.st.si.in[0]))
                  g.strings.st.si.in[0] = "`";
            g.strings.st.si.in[0] = CharToStr(StringGetChar(g.strings.st.si.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("GlobalArrays(static si=1, in=0)   g.ints="+ IntsToStr(g.ints.st.si, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.st.si, NULL) +"  g.strings="+ StringsToStr(g.strings.st.si, NULL));
            if (ArraySize(g.ints.st.si   ) != 2) ArrayResize(g.ints.st.si,    2);
            if (ArraySize(g.doubles.st.si) != 2) ArrayResize(g.doubles.st.si, 2);
            if (ArraySize(g.strings.st.si) != 2) ArrayResize(g.strings.st.si, 2);

            g.ints.st.si   [0]++;
            g.doubles.st.si[0] = g.doubles.st.si[0] + 1;
               if (!StringLen(g.strings.st.si[0]))
                  g.strings.st.si[0] = "`";
            g.strings.st.si[0] = CharToStr(StringGetChar(g.strings.st.si[0], 0) + 1);
         }
      }
      else/*(!si)*/{
         if (in) {
            debug("GlobalArrays(static si=0, in=1)   g.ints="+ IntsToStr(g.ints.st.in, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.st.in, NULL) +"  g.strings="+ StringsToStr(g.strings.st.in, NULL));
            if (ArraySize(g.ints.st.in   ) != 2) ArrayResize(g.ints.st.in,    2);
            if (ArraySize(g.doubles.st.in) != 2) ArrayResize(g.doubles.st.in, 2);
            if (ArraySize(g.strings.st.in) != 2) ArrayResize(g.strings.st.in, 2);

            g.ints.st.in   [0]++;
            g.doubles.st.in[0] = g.doubles.st.in[0] + 1;
               if (!StringLen(g.strings.st.in[0]))
                  g.strings.st.in[0] = "`";
            g.strings.st.in[0] = CharToStr(StringGetChar(g.strings.st.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("GlobalArrays(static si=0, in=0)   g.ints="+ IntsToStr(g.ints.st, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.st, NULL) +"  g.strings="+ StringsToStr(g.strings.st, NULL));
            if (ArraySize(g.ints.st   ) != 2) ArrayResize(g.ints.st,    2);
            if (ArraySize(g.doubles.st) != 2) ArrayResize(g.doubles.st, 2);
            if (ArraySize(g.strings.st) != 2) ArrayResize(g.strings.st, 2);

            g.ints.st   [0]++;
            g.doubles.st[0] = g.doubles.st[0] +1;
               if (!StringLen(g.strings.st[0])) g.strings.st[0] = "`";
            g.strings.st[0] = CharToStr(StringGetChar(g.strings.st[0], 0) + 1);
         }
      }
   }
   else/*(!st)*/{
      if (si) {
         if (in) {
            debug("GlobalArrays(si=1, in=1)   g.ints="+ IntsToStr(g.ints.si.in, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.si.in, NULL) +"  g.strings="+ StringsToStr(g.strings.si.in, NULL));
            if (ArraySize(g.ints.si.in   ) != 2) ArrayResize(g.ints.si.in,    2);
            if (ArraySize(g.doubles.si.in) != 2) ArrayResize(g.doubles.si.in, 2);
            if (ArraySize(g.strings.si.in) != 2) ArrayResize(g.strings.si.in, 2);

            g.ints.si.in   [0]++;
            g.doubles.si.in[0] = g.doubles.si.in[0] + 1;
               if (!StringLen(g.strings.si.in[0]))
                  g.strings.si.in[0] = "`";
            g.strings.si.in[0] = CharToStr(StringGetChar(g.strings.si.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("GlobalArrays(si=1, in=0)   g.ints="+ IntsToStr(g.ints.si, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.si, NULL) +"  g.strings="+ StringsToStr(g.strings.si, NULL));
            if (ArraySize(g.ints.si   ) != 2) ArrayResize(g.ints.si,    2);
            if (ArraySize(g.doubles.si) != 2) ArrayResize(g.doubles.si, 2);
            if (ArraySize(g.strings.si) != 2) ArrayResize(g.strings.si, 2);

            g.ints.si   [0]++;
            g.doubles.si[0] = g.doubles.si[0] + 1;
               if (!StringLen(g.strings.si[0]))
                  g.strings.si[0] = "`";
            g.strings.si[0] = CharToStr(StringGetChar(g.strings.si[0], 0) + 1);
         }
      }
      else/*(!si)*/{
         if (in) {
            debug("GlobalArrays(si=0, in=1)   g.ints="+ IntsToStr(g.ints.in, NULL) +"  g.doubles="+ DoublesToStr(g.doubles.in, NULL) +"  g.strings="+ StringsToStr(g.strings.in, NULL));
            if (ArraySize(g.ints.in   ) != 2) ArrayResize(g.ints.in,    2);
            if (ArraySize(g.doubles.in) != 2) ArrayResize(g.doubles.in, 2);
            if (ArraySize(g.strings.in) != 2) ArrayResize(g.strings.in, 2);

            g.ints.in   [0]++;
            g.doubles.in[0] = g.doubles.in[0] + 1;
               if (!StringLen(g.strings.in[0]))
                  g.strings.in[0] = "`";
            g.strings.in[0] = CharToStr(StringGetChar(g.strings.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("GlobalArrays(si=0, in=0)   g.ints="+ IntsToStr(g.ints, NULL) +"  g.doubles="+ DoublesToStr(g.doubles, NULL) +"  g.strings="+ StringsToStr(g.strings, NULL));
            if (ArraySize(g.ints   ) != 2) ArrayResize(g.ints,    2);
            if (ArraySize(g.doubles) != 2) ArrayResize(g.doubles, 2);
            if (ArraySize(g.strings) != 2) ArrayResize(g.strings, 2);

            g.ints   [0]++;
            g.doubles[0] = g.doubles[0] +1;
               if (!StringLen(g.strings[0])) g.strings[0] = "`";
            g.strings[0] = CharToStr(StringGetChar(g.strings[0], 0) + 1);
         }
      }
   }
}


/**
 *
 */
void LocalArrays(bool st, bool si, bool in) {
   int    l.ints   [];
   double l.doubles[];
   string l.strings[];

   int    l.ints.si   [1];
   double l.doubles.si[1];
   string l.strings.si[1];

   int    l.ints.in   [] = { 0};
   double l.doubles.in[] = { 0};
   string l.strings.in[] = {""};

   int    l.ints.si.in   [1] = { 0};
   double l.doubles.si.in[1] = { 0};
   string l.strings.si.in[1] = {""};

   static int    l.ints.st   [];
   static double l.doubles.st[];
   static string l.strings.st[];

   static int    l.ints.st.si   [1];
   static double l.doubles.st.si[1];
   static string l.strings.st.si[1];

   static int    l.ints.st.in   [] = { 0};
   static double l.doubles.st.in[] = { 0};
   static string l.strings.st.in[] = {""};

   static int    l.ints.st.si.in   [1] = { 0};
   static double l.doubles.st.si.in[1] = { 0};
   static string l.strings.st.si.in[1] = {""};

   if (st) {
      if (si) {
         if (in) {
            debug("LocalArrays(static si=1, in=1)   l.ints="+ IntsToStr(l.ints.st.si.in, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.st.si.in, NULL) +"  l.strings="+ StringsToStr(l.strings.st.si.in, NULL));
            if (ArraySize(l.ints.st.si.in   ) != 2) ArrayResize(l.ints.st.si.in,    2);
            if (ArraySize(l.doubles.st.si.in) != 2) ArrayResize(l.doubles.st.si.in, 2);
            if (ArraySize(l.strings.st.si.in) != 2) ArrayResize(l.strings.st.si.in, 2);

            l.ints.st.si.in   [0]++;
            l.doubles.st.si.in[0] = l.doubles.st.si.in[0] + 1;
               if (!StringLen(l.strings.st.si.in[0]))
                  l.strings.st.si.in[0] = "`";
            l.strings.st.si.in[0] = CharToStr(StringGetChar(l.strings.st.si.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("LocalArrays(static si=1, in=0)   l.ints="+ IntsToStr(l.ints.st.si, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.st.si, NULL) +"  l.strings="+ StringsToStr(l.strings.st.si, NULL));
            if (ArraySize(l.ints.st.si   ) != 2) ArrayResize(l.ints.st.si,    2);
            if (ArraySize(l.doubles.st.si) != 2) ArrayResize(l.doubles.st.si, 2);
            if (ArraySize(l.strings.st.si) != 2) ArrayResize(l.strings.st.si, 2);

            l.ints.st.si   [0]++;
            l.doubles.st.si[0] = l.doubles.st.si[0] + 1;
               if (!StringLen(l.strings.st.si[0]))
                  l.strings.st.si[0] = "`";
            l.strings.st.si[0] = CharToStr(StringGetChar(l.strings.st.si[0], 0) + 1);
         }
      }
      else/*(!si)*/{
         if (in) {
            debug("LocalArrays(static si=0, in=1)   l.ints="+ IntsToStr(l.ints.st.in, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.st.in, NULL) +"  l.strings="+ StringsToStr(l.strings.st.in, NULL));
            if (ArraySize(l.ints.st.in   ) != 2) ArrayResize(l.ints.st.in,    2);
            if (ArraySize(l.doubles.st.in) != 2) ArrayResize(l.doubles.st.in, 2);
            if (ArraySize(l.strings.st.in) != 2) ArrayResize(l.strings.st.in, 2);

            l.ints.st.in   [0]++;
            l.doubles.st.in[0] = l.doubles.st.in[0] + 1;
               if (!StringLen(l.strings.st.in[0]))
                  l.strings.st.in[0] = "`";
            l.strings.st.in[0] = CharToStr(StringGetChar(l.strings.st.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("LocalArrays(static si=0, in=0)   l.ints="+ IntsToStr(l.ints.st, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.st, NULL) +"  l.strings="+ StringsToStr(l.strings.st, NULL));
            if (ArraySize(l.ints.st   ) != 2) ArrayResize(l.ints.st,    2);
            if (ArraySize(l.doubles.st) != 2) ArrayResize(l.doubles.st, 2);
            if (ArraySize(l.strings.st) != 2) ArrayResize(l.strings.st, 2);

            l.ints.st   [0]++;
            l.doubles.st[0] = l.doubles.st[0] +1;
               if (!StringLen(l.strings.st[0])) l.strings.st[0] = "`";
            l.strings.st[0] = CharToStr(StringGetChar(l.strings.st[0], 0) + 1);
         }
      }
   }
   else/*(!st)*/{
      if (si) {
         if (in) {
            debug("LocalArrays(si=1, in=1)   l.ints="+ IntsToStr(l.ints.si.in, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.si.in, NULL) +"  l.strings="+ StringsToStr(l.strings.si.in, NULL));
            if (ArraySize(l.ints.si.in   ) != 2) ArrayResize(l.ints.si.in,    2);
            if (ArraySize(l.doubles.si.in) != 2) ArrayResize(l.doubles.si.in, 2);
            if (ArraySize(l.strings.si.in) != 2) ArrayResize(l.strings.si.in, 2);

            l.ints.si.in   [0]++;
            l.doubles.si.in[0] = l.doubles.si.in[0] + 1;
               if (!StringLen(l.strings.si.in[0]))
                  l.strings.si.in[0] = "`";
            l.strings.si.in[0] = CharToStr(StringGetChar(l.strings.si.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("LocalArrays(si=1, in=0)   l.ints="+ IntsToStr(l.ints.si, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.si, NULL) +"  l.strings="+ StringsToStr(l.strings.si, NULL));
            if (ArraySize(l.ints.si   ) != 2) ArrayResize(l.ints.si,    2);
            if (ArraySize(l.doubles.si) != 2) ArrayResize(l.doubles.si, 2);
            if (ArraySize(l.strings.si) != 2) ArrayResize(l.strings.si, 2);

            l.ints.si   [0]++;
            l.doubles.si[0] = l.doubles.si[0] + 1;
               if (!StringLen(l.strings.si[0]))
                  l.strings.si[0] = "`";
            l.strings.si[0] = CharToStr(StringGetChar(l.strings.si[0], 0) + 1);
         }
      }
      else/*(!si)*/{
         if (in) {
            debug("LocalArrays(si=0, in=1)   l.ints="+ IntsToStr(l.ints.in, NULL) +"  l.doubles="+ DoublesToStr(l.doubles.in, NULL) +"  l.strings="+ StringsToStr(l.strings.in, NULL));
            if (ArraySize(l.ints.in   ) != 2) ArrayResize(l.ints.in,    2);
            if (ArraySize(l.doubles.in) != 2) ArrayResize(l.doubles.in, 2);
            if (ArraySize(l.strings.in) != 2) ArrayResize(l.strings.in, 2);

            l.ints.in   [0]++;
            l.doubles.in[0] = l.doubles.in[0] + 1;
               if (!StringLen(l.strings.in[0]))
                  l.strings.in[0] = "`";
            l.strings.in[0] = CharToStr(StringGetChar(l.strings.in[0], 0) + 1);
         }
         else/*(!in)*/{
            debug("LocalArrays(si=0, in=0)   l.ints="+ IntsToStr(l.ints, NULL) +"  l.doubles="+ DoublesToStr(l.doubles, NULL) +"  l.strings="+ StringsToStr(l.strings, NULL));
            if (ArraySize(l.ints   ) != 2) ArrayResize(l.ints,    2);
            if (ArraySize(l.doubles) != 2) ArrayResize(l.doubles, 2);
            if (ArraySize(l.strings) != 2) ArrayResize(l.strings, 2);

            l.ints   [0]++;
            l.doubles[0] = l.doubles[0] +1;
               if (!StringLen(l.strings[0])) l.strings[0] = "`";
            l.strings[0] = CharToStr(StringGetChar(l.strings[0], 0) + 1);
         }
      }
   }
}
