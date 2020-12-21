
### How to compile MQL programs without using MetaEditor?
For maximum backward compatibility the framework includes the compiler of MT4 build 224. The reliability of .ex4 files generated 
with that compiler outweights its minor restrictions compared to current compiler versions. The included compiler may be replaced 
by any other compiler version of MetaEditor builds &lt;= 509 without changes to the code base.

The compiler may be integrated in another development environment by registering custom CLI tools. It may also be called 
manually either directly or using the provided script `mqlc`:

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

For command line options of the compiler contained in MetaEditor build 600+ see [https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide#compiler](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide#compiler).
- - -

### How to fix the compiler error "cannot open &lt;include-file&gt;"?
To make the compiler find the framework's include files a junction or symlink `experts/include` pointing to 
`mql4/experts/include` must be created in this directory. A comfortable way to manage symlinks and junctions under Windows 
is the free [Link Shell Extension](http://schinagl.priv.at/nt/hardlinkshellext/linkshellextension.html) by Hermann Schinagl.
