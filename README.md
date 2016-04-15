# Wipe

a commanline program to securely delete files.

## Usage

~~~
wipe [-m <mode>] [-f] [-s] [-h|-?] <files...>
mode:
  delete, d: delete
  simple, s: simple overwrite
  dod: DOD overwrite
  gutmann, g: Gutmann overwrite
f: force
s: silent
files: File list
h, ?: Show help
Example:
  wipe -m gutmann -f delete.me
~~~

## Compiling

Get [FPC](http://www.freepascal.org/) and [Lazarus](http://www.lazarus-ide.org/) 
open `wipe.lpi` and click Start -> Compile or type:

~~~
lazbuild ./wipe.lpi --build-all --build-mode=Release
~~~