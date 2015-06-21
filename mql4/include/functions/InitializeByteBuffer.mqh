/**
 * Initialisiert einen Buffer zur Aufnahme der gewünschten Anzahl von Bytes.
 *
 * @param  int buffer[] - das für den Buffer zu verwendende Integer-Array
 * @param  int size     - Anzahl der im Buffer zu speichernden Bytes
 *
 * @return int - Fehlerstatus
 */
int InitializeByteBuffer(int buffer[], int size) {
   int dimensions = ArrayDimension(buffer);

   if (dimensions > 2) return(catch("InitializeByteBuffer(1)  too many dimensions of parameter buffer = "+ dimensions, ERR_INCOMPATIBLE_ARRAYS));
   if (size < 0)       return(catch("InitializeByteBuffer(2)  invalid parameter size = "+ size, ERR_INVALID_PARAMETER));

   if (size & 0x03 == 0) size = size >> 2;                           // size & 0x03 entspricht size % 4
   else                  size = size >> 2 + 1;

   if (dimensions == 1) {
      if (ArraySize(buffer) != size)
         ArrayResize(buffer, size);
   }
   else if (ArrayRange(buffer, 1) != size) {                         // die 2. Dimension mehrdimensionaler Arrays kann nicht dynamisch angepaßt werden
      return(catch("InitializeByteBuffer(3)  cannot adjust size of second dimension at runtime (size="+ ArrayRange(buffer, 1) +")", ERR_INCOMPATIBLE_ARRAYS));
   }

   if (ArraySize(buffer) > 0)
      ArrayInitialize(buffer, 0);

   return(catch("InitializeByteBuffer(4)"));
}
