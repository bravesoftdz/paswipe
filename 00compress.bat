@echo off

if exist wipe-win32.zip del wipe-win32.zip
"%PROGRAMFILES%\7-ZIP\7z.exe" a -tzip -mx wipe-win32.zip @ziplst
