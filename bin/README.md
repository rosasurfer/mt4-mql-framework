
### How to compile MQL programs without using MetaEditor?
For maximum backward compatibility the framework comes with the compiler distributed with MetaTrader 4 build 225. The reliability of EX4 files generated with an old compiler outweights its minor restrictions compared to current compiler versions. The provided compiler may be replaced by any other compiler version of MetaEditor builds &lt;= 509 without changes to the code base.

The compiler can be integrated in any modern development environment by registering custom CLI tools. It may also be called manually using the provided script `bin/mqlc`:

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
- - -

### How to fix the compiler error "cannot open &lt;include-file&gt;"?
To let the compiler find the framework's include files a symbolic link in `bin/experts` pointing to `mql4/experts/include` must be created. At the moment the script cannot reliably create that symlink in all different Windows versions, therefore the user has to create that symlink manually. A comfortable way to manage Windows symlinks and junctions is the free [Link Shell Extension](http://schinagl.priv.at/nt/hardlinkshellext/linkshellextension.html) by Hermann Schinagl.
