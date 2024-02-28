/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "ID."+ StrPadLeft(instance.id, 3, "0");
}
