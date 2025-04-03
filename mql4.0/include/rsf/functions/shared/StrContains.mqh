/**
 * Whether a string contains a substring (case-sensitive).
 *
 * @param  string str    - string to inspect
 * @param  string substr - substring
 *
 * @return bool
 */
bool StrContains(string str, string substr) {
   if (!StringLen(substr))
      return(!catch("StrContains(1)  illegal parameter substr: \""+ substr +"\"", ERR_INVALID_PARAMETER));
   return(StringFind(str, substr) != -1);
}
