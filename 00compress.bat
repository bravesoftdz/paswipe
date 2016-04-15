@echo off

if exist wipe.zip del wipe.zip
"%PROGRAMFILES%\7-ZIP\7z.exe" a -tzip -mx wipe.zip @ziplst
