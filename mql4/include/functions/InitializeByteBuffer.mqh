/**
 * Initialisiert einen Buffer zur Aufnahme der gewünschten Anzahl von Bytes.
 *
 * @param  int buffer[] - das für den Buffer zu verwendende Integer-Array
 * @param  int bytes    - Anzahl der im Buffer zu speichernden Bytes
 *
 * @return int - Fehlerstatus
 */
int InitializeByteBuffer(int buffer[], int bytes) {
   int dimensions = ArrayDimension(buffer);

   if (dimensions > 2) return(catch("InitializeByteBuffer(1)  too many dimensions of parameter buffer = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS));
   if (bytes < 0)      return(catch("InitializeByteBuffer(2)  invalid parameter bytes = "+ bytes, ERR_INVALID_PARAMETER));

   int dwords = bytes >> 2;
   if (bytes & 0x03 != 0) dwords++;                                  // bytes & 0x03 entspricht bytes % 4

   if (dimensions == 1) {
      if (ArraySize(buffer) != dwords)
         ArrayResize(buffer, dwords);
   }
   else if (ArrayRange(buffer, 1) != dwords) {                       // die 2. Dimension mehrdimensionaler Arrays kann nicht dynamisch angepaßt werden
      return(catch("InitializeByteBuffer(3)  cannot adjust size of second dimension at runtime (size="+ ArrayRange(buffer, 1) +")", ERR_INCOMPATIBLE_ARRAYS));
   }

   if (ArraySize(buffer) > 0)
      ArrayInitialize(buffer, 0);

   return(catch("InitializeByteBuffer(4)"));
}
