{
  paswipe.pas
  Copyright (C) 2002-2007 Ascher Stefan <sa@stievie.net>
  Copyright (C) 2000 Matt Gauthier <elleron@yahoo.com>
  Copyright (C) 2001, 2002 Timo Schulz <twoaday@freakmail.de>

  This code based on the sunlink.c file from the SRM project, but
  it was heavily modified to work with W32 and with added GCRYPT
  support for gathering random bytes.

  It has been translated from C to Pascal by Ascher Stefan. I've
  also removed GCRYPT support, maybe I'll translate it one time to
  Pascal. I replaced all Win32 dependent functions with native
  Pascal functions to make it easier to port it to other platforms.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

 $Id: paswipe.pas,v 1.1 2007/07/08 20:55:10 Administrator Exp $
}

unit paswipe;

{$I wipe.inc}

interface

uses
  SysUtils, Classes;

type
  TWipeMode = (wmDelete, wmSimple, wmDod, wmGutmann);
  TWipeType = (wtDeleteFile, wtRemoveDir);
  TProgressProc = procedure(const Value, Total: Int64; const WipeType: TWipeType;
    const CurFile: string; var Skip, Abort: boolean);

function WipeFiles(const Files: array of string; const Mode: TWipeMode): boolean;
function WipeFile(const Filename: string; const Mode: TWipeMode): boolean;
procedure WipeSetProgressProc(Proc: TProgressProc);

implementation

uses
  isaac;
  
const
  WipeBuffSize = 4095;    { 4 KB }

type
  TWipeFile = record
    Fi: File of byte;
    Path: string;
    Name: string;
    Size: integer;
    Buffer: array[0..WipeBuffSize] of Byte;
    BuffSize: integer;
  end;
  PWipeFile = ^TWipeFile;

var
  gProgressProc: TProgressProc = nil;
  gIsaac: TIsaac;
  gAbort: boolean = false;

function IsFileChar(const c: Char): boolean;
begin
  Result := c in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function GetFileSize(const AFilename: string): Int64;
var
  ts: TSearchRec;
begin
  if FindFirst(AFilename, faAnyFile, ts) = 0 then
    Result := ts.Size
  else
    Result := 0;
end;

procedure RandomizeBuffer(F: PWipeFile);
var
  i: integer;
begin
  // Fill the buffer with random data
  for i := Low(F^.Buffer) to High(F^.Buffer) do
    F^.Buffer[i] := gIsaac.ByteVal(255);
end;

var
  bytes_overwritten, progress_size: Int64;
  total_size, total_bytes_written: Int64;

procedure UpdateProgress(const Size: Int64; const WipeType: TWipeType;
  const ACurFile: string; var Skip: boolean);
var
  pf, pt: Int64;
  abort: boolean;
begin
  if Assigned(gProgressProc) then begin
    if Size > 0 then begin
      Inc(bytes_overwritten, Size);
      Inc(total_bytes_written, Size);
    end;
    if progress_size > 0 then
      pf := Trunc((bytes_overwritten / progress_size) * 100)
    else
      pf := 0;
    if total_size > 0 then
      pt := Trunc((total_bytes_written / total_size) * 100)
    else
      pt := 0;
    abort := false;
    gProgressProc(pf, pt, WipeType, ACurFile, abort, Skip);
    gAbort := abort;
  end;
end;

function WipeDeleteDir(const ADir: string): boolean;
var
  skip: boolean;
begin
  UpdateProgress(0, wtRemoveDir, ADir, skip);
  if gAbort then
    Exit;
  Result := RemoveDir(ADir);
  if not Result then begin
    Sleep(100);
    Result := RemoveDir(ADir);
  end;
end;

function WipeDeleteFile(F: PWipeFile): boolean;

  function MakeName: string;
  var
    l: integer;
    c: Char;
  begin
    SetLength(Result, 10);
    l := 1;
    while l < 11 do begin
      // Make new filename 10 Characters long
      c := Char(gIsaac.ByteVal(127));
      if IsFileChar(c) then begin
        Result[l] := c;
        Inc(l);
      end;
    end;
  end;

var
  snewname, path: string;
begin
  // Rename and delete the file
  path := IncludeTrailingPathDelimiter(F^.Path);
  repeat
    snewname := MakeName;
  until not FileExists(path + snewname);
  if RenameFile(path + F^.Name, path + snewname) then begin
    Result := SysUtils.DeleteFile(path + snewname);
  end else begin
    Result := SysUtils.DeleteFile(path + F^.Name);
  end;
end;

procedure Overwrite(F: PWipeFile);
var
  blocks, remain: integer;
  written: Int64;
  skip: boolean;
begin
  // Overwrite the file with F.Buffer
  blocks := F^.Size div F^.BuffSize;
  remain := F^.Size mod F^.BuffSize;
  skip := false;
  Seek(F^.Fi, 0);
  while blocks > 0 do begin
    written := F^.BuffSize;
    UpdateProgress(written, wtDeleteFile, IncludeTrailingPathDelimiter(F^.Path) + F^.Name, skip);
    if gAbort then
      Exit;
    BlockWrite(F^.Fi, F^.Buffer, written);
    if written = 0 then
      Break;
    Dec(blocks);
  end;
  if (remain > 0) and (not gAbort) then begin
    UpdateProgress(remain, wtDeleteFile, IncludeTrailingPathDelimiter(F^.Path) + F^.Name, skip);
    if gAbort then
      Exit;
    BlockWrite(F^.Fi, F^.Buffer, remain);
  end;
end;

procedure OverwriteRandom(const NumPasses: integer; F: PWipeFile);
var
  i: integer;
begin
  for i := 0 to NumPasses - 1 do begin
    if gAbort then
      Exit;
    RandomizeBuffer(F);
    Overwrite(F);
  end;
end;

procedure OverwriteByte(const B: Byte; F: PWipeFile);
begin
  FillChar(F^.Buffer, F^.BuffSize, B);
  Overwrite(F);
end;

procedure OverwriteBytes(const B1, B2, B3: Byte; F: PWipeFile);
var
  i: integer;
begin
  i := 2;
  while i <= F^.BuffSize do begin
    F^.Buffer[i - 2] := B1;
    F^.Buffer[i - 1] := B2;
    F^.Buffer[i] := B3;
    Inc(i, 3);
  end;
  Overwrite(F);
end;

procedure WipeSetProgressProc(Proc: TProgressProc);
begin
  gProgressProc := Proc;
end;

function WipeFile(const Filename: string; const Mode: TWipeMode): boolean;
var
  wf: PWipeFile;
  skip: boolean;
begin
  Result := false;
  if gAbort then begin
    Exit;
  end;
  if FileExists(Filename) and (not DirectoryExists(Filename)) then begin
    UpdateProgress(0, wtDeleteFile, Filename, skip);
    if skip or gAbort then
      Exit;
    FileSetAttr(Filename, 0);
    New(wf);
    wf^.Name := ExtractFileName(Filename);
    wf^.Path := ExtractFileDir(Filename);
    wf^.Size := GetFileSize(Filename);
    AssignFile(wf^.Fi, Filename);
    if (wf^.Size = 0) or (Mode = wmDelete) then begin
      Result := WipeDeleteFile(wf);
      Dispose(wf);
      Exit;
    end;
    {$I-}Rewrite(wf^.Fi);{$I+}
    if IOResult <> 0 then begin
      Dispose(wf);
      Exit;
    end;
    bytes_overwritten := 0;
    wf^.BuffSize := WipeBuffSize + 1;   // 0..WipeBuffSize
    FillChar(wf^.Buffer, wf^.BuffSize, 0);
    case Mode of
      wmSimple:
        begin
          progress_size := Int64(wf^.Size) * 2;
          OverwriteRandom(2, wf);
        end;
      wmDod:
        begin
          progress_size := Int64(wf^.Size) * 5;
          OverwriteRandom(1, wf);
          OverwriteByte(not 1 and $FF, wf);
          OverwriteRandom(1, wf);
          OverwriteByte(not 4 and $FF, wf);
          OverwriteRandom(1, wf);
        end;
      wmGutmann:
        // modified by vitus in 201211    --- BEGIN ---
        //
        // Gutmann does not work for files greater than
        // 58 MBytes (58 x 1024 x 1024 = 60817408 )
        // so we do a workaround here and do an autoswitch
        // to DoD-algorithm.
        //
        if (wf^.Size > 60817408) then begin
          progress_size := Int64(wf^.Size) * 5;
          OverwriteRandom(1, wf);
          OverwriteByte(not 1 and $FF, wf);
          OverwriteRandom(1, wf);
          OverwriteByte(not 4 and $FF, wf);
          OverwriteRandom(1, wf);
        end else begin
        //begin
        // modified by vitus in 201211    ---- END ----
          progress_size := Int64(wf^.Size) * 35;
          OverwriteRandom(4, wf);
          OverwriteByte($55, wf);
          OverwriteByte($AA, wf);
          OverwriteBytes($92, $49, $24, wf);
          OverwriteBytes($49, $24, $92, wf);
          OverwriteBytes($24, $92, $49, wf);
          OverwriteByte($00, wf);
          OverwriteByte($11, wf);
          OverwriteByte($22, wf);
          OverwriteByte($33, wf);
          OverwriteByte($44, wf);
          OverwriteByte($55, wf);
          OverwriteByte($66, wf);
          OverwriteByte($77, wf);
          OverwriteByte($88, wf);
          OverwriteByte($99, wf);
          OverwriteByte($AA, wf);
          OverwriteByte($BB, wf);
          OverwriteByte($CC, wf);
          OverwriteByte($DD, wf);
          OverwriteByte($EE, wf);
          OverwriteByte($FF, wf);
          OverwriteBytes($92, $49, $24, wf);
          OverwriteBytes($49, $24, $92, wf);
          OverwriteBytes($24, $92, $49, wf);
          OverwriteBytes($6D, $B6, $DB, wf);
          OverwriteBytes($B6, $DB, $6D, wf);
          OverwriteBytes($DB, $6D, $B6, wf);
          OverwriteRandom(4, wf);
        end;
    end;
    if gAbort then begin
      Result := false;
      Dispose(wf);
      Exit;
    end;
    Seek(wf^.Fi, 0);                         // Set Filepointer to begin of file
    Truncate(wf^.Fi);                        // Truncate file
    CloseFile(wf^.Fi);
    Result := WipeDeleteFile(wf);            // Rename and Delete the file
    FillChar(wf^.Buffer, wf^.BuffSize, 0);   // Burn Memory
    Dispose(wf);
  end else if DirectoryExists(Filename) then begin
    Result := WipeDeleteDir(Filename);
  end;
end;

procedure FindFiles(const AName: string; Files: TStringList);
var
  r: TSearchRec;
begin
  if DirectoryExists(AName) then begin
    if FindFirst(IncludeTrailingPathDelimiter(AName) + '*.*', faAnyFile, r) = 0 then begin
      repeat
        if (r.Name = '.') or (r.Name = '..') then
          Continue;
        FindFiles(IncludeTrailingPathDelimiter(AName) + r.Name, Files);
      until FindNext(r) <> 0;
      SysUtils.FindClose(r);
      // if i'm a directory add me as last
      Files.Add(AName);
    end;
  end else begin
    Inc(total_size, GetFileSize(AName));
    Files.Add(AName);
  end;
end;

function WipeFiles(const Files: array of string; const Mode: TWipeMode): boolean;
var
  i: integer;
  r: boolean;
  sl: TStringList;
label
  leave;
begin
  Result := true;
  sl := TStringList.Create;
  total_size := 0;
  total_bytes_written := 0;
  for i := Low(Files) to High(Files) do begin
    FindFiles(Files[i], sl);
  end;
  case Mode of
    wmSimple:
      begin
        total_size := total_size * 2;
      end;
    wmDod:
      begin
        total_size := total_size * 5;
      end;
    wmGutmann:
        // modified by vitus in 201211    --- BEGIN ---
        //
        // Gutmann does not work for files greater than
        // 64 MBytes (64 x 1024 x 1024 = 67108864 )
        // so we do a workaround here and do an autoswitch
        // to DoD-algorithm.
        //
      if (total_size > 67108864) then begin
        total_size := total_size * 5;
      //begin
      end else begin
        // modified by vitus in 201211    ---- END ----
        total_size := total_size * 35;
     end;
  end;
  for i := 0 to sl.Count - 1 do begin
    if gAbort then
      goto leave;
    r := WipeFile(sl[i], Mode);
    Result := Result and r;
  end;
leave:
  sl.Free;
end;

procedure InitPRNG;
var
  seed: array[0..255] of Cardinal;
  i: integer;
begin
  Randomize;
  for i := 0 to 255 do begin
    seed[i] := Random(MAXINT);
  end;
  gIsaac := TIsaac.Create(seed);
end;


initialization
  InitPRNG;
  
finalization
  FreeAndNil(gIsaac);

end.

