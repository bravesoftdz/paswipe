program wipe;

{$I wipe.inc}

{$IFDEF WINDOWS}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  {$IFDEF FPC}
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  {$ENDIF}
  SysUtils, Classes
  { you can add units after this }
  , paswipe;

const
  VERSION = '20160417';

var
  Mode: TWipeMode = wmDod;
  Files: array of string;
  FilesCount: integer = 0;
  LastFile: string = '';
  Force: boolean = false;
  Silent: boolean = false;

function GetFullName(const Path, Name: string): string;
begin
  if Path <> '' then
    Result := Path + DirectorySeparator + Name
  else
    Result := Name;
end;

procedure AddFiles(const Mask: string);
var
  r: TSearchRec;
  p: string;
begin
  if FileExists(Mask) then begin
    Inc(FilesCount);
    SetLength(Files, FilesCount);
    Files[FilesCount - 1] := Mask;
  end else if (Pos('*', Mask) <> 0) or (Pos('?', Mask) <> 0) then begin
    p := ExcludeTrailingPathDelimiter(ExtractFilePath(Mask));
    if FindFirst(Mask, faAnyFile, r) = 0 then begin
      repeat
        if (r.Name = '.') or (r.Name = '..') then
          Continue;
        Inc(FilesCount);
        SetLength(Files, FilesCount);
        Files[FilesCount - 1] := GetFullName(p, r.Name);
      until FindNext(r) <> 0;
      SysUtils.FindClose(r);
    end;
  end;
end;

procedure ShowVersion;
begin
  WriteLn('wipe v. ' + VERSION);
  WriteLn('by sa');
  WriteLn('Compiled ' + {$i %DATE%} + ' ' + {$i %TIME%});
  WriteLn('with FPC ' + {$i %FPCVERSION%} + ' for ' + {$I %FPCTARGETOS%} + ' on ' + {$I %FPCTARGETCPU%});
end;

procedure ShowHelp;
begin
  WriteLn('wipe [-m <mode>] [-f] [-s] [-h|-?] [-v] <files...>');
  WriteLn('mode:');
  WriteLn('  delete, d: delete');
  WriteLn('  simple, s: simple overwrite');
  WriteLn('  dod: DOD overwrite (default)');
  WriteLn('  gutmann, g: Gutmann overwrite');
  WriteLn('f: force');
  WriteLn('s: silent');
  WriteLn('h, ?: Show help');
  WriteLn('v: Show version');
  WriteLn('files: File list');
  WriteLn('Example:');
  WriteLn('  wipe -m gutmann -f delete.me');
end;

function GetOptions: boolean;
var
  i: integer;
  s: string;
begin
  i := 1;
  FilesCount := 0;
  Result := false;
  while i <= ParamCount do begin
    s := ParamStr(i);
    if s = '-m' then begin
      Inc(i);
      s := ParamStr(i);
      if (s = 'delete') or (s = 'd') then
        Mode := wmDelete
      else if (s = 'simple') or (s = 's') then
        Mode := wmSimple
      else if (s = 'dod') then
        Mode := wmDod
      else if (s = 'gutmann') or (s = 'g') then
        Mode := wmGutmann
      else begin
        Result := false;
        WriteLn(Format('Unknown mode %s', [s]));
        Exit;
      end;
    end else if s = '-f' then begin
      Force := true;
    end else if s = '-s' then begin
      Silent := true;
    end else if (s = '-h') or (s = '-?') then begin
      ShowHelp;
      Halt(0);
    end else if (s = '-v') then begin
      ShowVersion;
      Halt(0);
    end else if s <> '' then begin
      Result := true;
      AddFiles(s);
    end;
    Inc(i);
  end;
end;

procedure Progress(const Value, Total: Int64; const WipeType: TWipeType;
  const CurFile: string; var Skip, Abort: boolean);
begin
  Abort := false;
  Skip := false;
  if not Silent then begin
    if (LastFile <> CurFile) then begin
      LastFile := CurFile;
      case WipeType of
        wtDeleteFile:
          WriteLn(Format('Deleting file %s', [CurFile]));
        wtRemoveDir:
          WriteLn(Format('Removing directory %s', [CurFile]));
      end;
    end;
  end;
end;

var
  Answer: string;

begin
  if not GetOptions then begin
    ShowHelp;
    Halt(1);
  end;
  WipeSetProgressProc({$IFDEF FPC}@{$ENDIF}Progress);
  if FilesCount = 1 then begin
    if not Force then begin
      WriteLn(Format('Really delete file %s (y/n)?', [Files[0]]));
      ReadLn(Answer);
      if (Answer <> 'y') and (Answer <> 'Y') then
        Halt(1);
    end;
    WipeFile(Files[0], Mode)
  end else if FilesCount > 1 then begin
    if not Force then begin
      WriteLn(Format('Really delete %d files (y/n)?', [FilesCount]));
      ReadLn(Answer);
      if (Answer <> 'y') and (Answer <> 'Y') then
        Halt(1);
    end;
    WipeFiles(Files, Mode);
  end;
end.

