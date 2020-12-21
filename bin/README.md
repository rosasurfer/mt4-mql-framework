
### How to compile MQL programs without using MetaEditor?
For backward compatibility the framework includes the compiler of MetaTrader 4 build 224. The reliability of .ex4 files generated 
with that compiler outweights the limitations compared to current compiler versions. The compiler may be replaced by any compiler 
version of MetaEditor 4 builds &lt;= 509 without changes to the code base.

The compiler can be called manually from the command line or it can be integrated in 3rd party development environments by registering 
custom CLI tools.

```bash
$ mqlc -?
MetaQuotes Language 4 compiler version 4.00 build 224 (14 May 2009)
Copyright notice

Usage:
  mqlc [options...] FILENAME

Arguments:
  FILENAME  The MQL file to compile.

Options:
   -q       Quite mode.
```

For the command line options of the compiler built into MetaEditor builds 600+ see [https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide#compiler](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide#compiler).
- - -

### How to fix the compiler error "cannot open &lt;include-file&gt;"?
To make the compiler find the framework's include files a junction `experts/include` pointing to `mql4/experts/include`
must be created in this very directory. A comfortable way to manage Windows symlinks and junctions is the free
[Link Shell Extension](http://schinagl.priv.at/nt/hardlinkshellext/linkshellextension.html) by Hermann Schinagl.
