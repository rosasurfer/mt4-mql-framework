/**
 * SendTestSMS
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string section  = "SMS";
   string key      = "Receiver";
   string receiver = GetGlobalConfigString(section, key);
   if (!StrIsPhoneNumber(receiver)) return(!catch("onStart(1)  invalid phone number: ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE));

   SendSMS(receiver, "Test message");
   return(catch("onStart(3)"));
}
