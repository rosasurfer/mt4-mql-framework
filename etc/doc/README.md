
### Where can I find the original version of the MQL4 language reference?
The original file is stored at [commit #e30ebd8](https://github.com/rosasurfer/mt4-mql/tree/e30ebd8/doc) under the name `doc/MQL4 Reference.xml`.
- - -

### How can I use the MQL4 language reference?
Download the MetaEditor/Compiler ZIP file for build 225 from the link in the [main README file](https://github.com/rosasurfer/mt4-mql). Extract `metaeditor.exe` from the ZIP file and copy it to a directory of your choice. Create a subdirectory `languages` in that directory. Copy the file `MQL4 Language Reference.xml` from this directory to the created subdirectory `languages` and rename it to `metaeditor.xml`.

Start `metaeditor.exe`. In the main menu under `View` enable `Toolbox` and `Navigator`. Undock the `Navigator` subwindow and maximize the `Toolbox` window. Activate the `Toolbox` tab `Help`. For searching switch to the `Navigator` tab `Search`.
- - -

### Advanced setup
Advanced users may symlink the language reference file in this directory to `<metaeditor-dir>\languages\metaeditor.xml`. This way the file used by MetaEditor is always in sync with the version in the repository.
