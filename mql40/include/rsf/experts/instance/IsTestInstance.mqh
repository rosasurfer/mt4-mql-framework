/**
 * Whether the current instance was created in the tester. Also returns TRUE if a finished test is loaded into an online chart.
 *
 * @return bool
 */
bool IsTestInstance() {
   return(instance.isTest || __isTesting);
}
