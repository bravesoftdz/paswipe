{
  GPGSX
  Copyright (C) 2007, Ascher Stefan. All rights reserved.
  sa@stievie.net, http://www.stievie.net/

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
  
 $Id: $
}

{
  Gather some "random" seed to make ISAAC a (more or less) "true" random number
  generator.

  It just collects some system informations. It is not as sophisticated as
  rndw32.c by Peter Gutman. It just implements the fast gathering method, see
  TSeedGatherer.SeedFast.
}

unit SeedGatherer;

{$i gsx.inc}
{$R-,Q-}

interface

uses
  SysUtils, Classes, Windows;

type
  TSeedArr = array[0..255] of Cardinal;

  TNetApiBufferFree = function(Buffer: Pointer): integer;
  TNetApiBufferSize = function(Buffer: Pointer; var ByteCount: DWORD): integer;
  TNetStatisticsGet = function(server, service: PWideChar; level, options: DWORD; buffer: Pointer): integer;

  TNetApi = class
  private
    fLib: HMODULE;
    fNetApiBufferFree: TNetApiBufferFree;
    fNetApiBufferSize: TNetApiBufferSize;
    fNetStatisticsGet: TNetStatisticsGet;
  public
    constructor Create;
    destructor Destroy; override;
    property NetApiBufferFree: TNetApiBufferFree read fNetApiBufferFree;
    property NetApiBufferSize: TNetApiBufferSize read fNetApiBufferSize;
    property NetStatisticsGet: TNetStatisticsGet read fNetStatisticsGet;
  end;
  TToolHelp = class
  private
    fLib: HMODULE;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TSeedGatherer = class
  private
    fSeed: TSeedArr;
    fFast: boolean;
    fSeedFile: string;
    fCurPos: integer;
    procedure LoadSeedFile;
    function Add(const v: Cardinal): boolean;
    procedure GatherFast;
    procedure GatherSlow;
    procedure GatherNT;
    procedure Gather9x;
    procedure RandomizeSeed;
  public
    constructor Create(const AFast, AAutoGather: boolean; const ASeedFile: string);
    destructor Destroy; override;
    procedure Gather;

    property Seed: TSeedArr read fSeed;
    property SeedFile: string read fSeedFile;
  end;

implementation

{ TNetApi }

constructor TNetApi.Create;
begin
  fLib := LoadLibrary('netapi32.dll');
  if fLib = 0 then
    Exit;
  fNetApiBufferFree := GetProcAddress(fLib, 'NetApiBufferFree');
  fNetApiBufferSize := GetProcAddress(fLib, 'NetApiBufferSize');
  fNetStatisticsGet := GetProcAddress(fLib, 'NetStatisticsGet');
end;

destructor TNetApi.Destroy;
begin
  FreeLibrary(fLib);
  inherited;
end;

{ TToolHelp }

constructor TToolHelp.Create;
begin
  fLib := LoadLibrary('kernel32.dll');
  if fLib = 0 then
    Exit;
end;

destructor TToolHelp.Destroy;
begin
  FreeLibrary(fLib);
  inherited;
end;

{ TSeedGatherer }

function TSeedGatherer.Add(const v: Cardinal): boolean;
begin
  if fCurPos <= High(fSeed) then begin
    if v > 0 then begin
      fSeed[fCurPos] := v;
      Inc(fCurPos);
    end;
    Result := true;
  end else
    Result := false;
end;

constructor TSeedGatherer.Create(const AFast, AAutoGather: boolean; const ASeedFile: string);
begin
  fFast := AFast;
  fSeedFile := ASeedFile;
  if AAutoGather then
    Gather;
end;

destructor TSeedGatherer.Destroy;
begin
  inherited;
end;

procedure TSeedGatherer.Gather;
begin
  fCurPos := 0;
  if fFast then
    GatherFast
  else
    GatherSlow;
  // Fill the rest with the seed file
  LoadSeedFile;
  RandomizeSeed;
end;

procedure TSeedGatherer.LoadSeedFile;
var
  s: array[0..255] of Cardinal;
  BytesRead: integer;
  f: file of Byte;
  i: integer;
begin
  // The seed file should be saved by ISAAC because we want to save the state
  // and not the initial seed. 
  if FileExists(fSeedFile) then begin
    // Fill the rest with the seed file
    FillChar(s, 256, 0);
    AssignFile(f, fSeedFile);
    {$I-}Reset(F);{$I+}
    if IOResult = 0 then begin
      BlockRead(F, s[0], SizeOf(s), BytesRead);
      CloseFile(f);
      i := 0;
      while Add(s[i]) do
        Inc(i);
    end;
  end;
end;

procedure TSeedGatherer.Gather9x;
begin
  raise Exception.Create('Not implemented');
end;

procedure TSeedGatherer.GatherFast;
var
  p: TPoint;
  ms: TMemoryStatus;
  h: THandle;
  t1, t2, t3, t4: TFileTime;
  c1, c2: Cardinal;
  st: TSystemTime;
  dw1, dw2, dw3, dw4: DWORD;
begin
  Add(GetActiveWindow);
  Add(GetCapture);
  Add(GetClipboardOwner);
  Add(GetClipboardViewer);
  Add(GetCurrentProcess);
  Add(GetCurrentProcessId);
  Add(GetCurrentThread);
  Add(GetCurrentThreadId);
  Add(GetDesktopWindow);
  Add(GetFocus);
  Add(Cardinal(GetInputState));
  Add(GetMessagePos);
  Add(GetMessageTime);
  Add(GetOpenClipboardWindow);
  Add(GetProcessHeap);
  Add(GetProcessWindowStation);
  Add(GetQueueStatus(QS_ALLEVENTS));
  Add(GetTickCount);
  GetCaretPos(p);
  if (p.x < (MaxInt div 2)) and (p.y < (MaxInt div 2)) then
    Add((p.x shl 8) or p.y)
  else begin
    Add(p.x);
    Add(p.y);
  end;
  GetCursorPos(p);
  if (p.x < (MaxInt div 2)) and (p.y < (MaxInt div 2)) then
    Add((p.x shl 8) or p.y)
  else begin
    Add(p.x);
    Add(p.y);
  end;
  ms.dwLength := SizeOf(ms);
  GlobalMemoryStatus(ms);
  Add(ms.dwMemoryLoad);
  Add(ms.dwTotalPhys);
  Add(ms.dwAvailPhys);
  Add(ms.dwTotalPageFile);
  Add(ms.dwAvailPageFile);
  Add(ms.dwTotalVirtual);
  Add(ms.dwAvailVirtual);
  h := GetCurrentThread;
  GetThreadTimes(h, t1, t2, t3, t4);
  Add(t1.dwLowDateTime);
  Add(t1.dwHighDateTime);
  Add(t2.dwLowDateTime);
  Add(t2.dwHighDateTime);
  Add(t3.dwLowDateTime);
  Add(t3.dwHighDateTime);
  Add(t4.dwLowDateTime);
  Add(t4.dwHighDateTime);
  h := GetCurrentProcess;
  GetProcessTimes(h, t1, t2, t3, t4);
  Add(t1.dwLowDateTime);
  Add(t1.dwHighDateTime);
  Add(t2.dwLowDateTime);
  Add(t2.dwHighDateTime);
  Add(t3.dwLowDateTime);
  Add(t3.dwHighDateTime);
  Add(t4.dwLowDateTime);
  Add(t4.dwHighDateTime);
  GetProcessWorkingSetSize(h, c1, c2);
  Add(c1);
  Add(c2);
  Add(GetTickCount);

  GetSystemTime(st);
  Add((st.wYear shl 12) or (st.wMonth shl 8) or (st.wDay shl 4) or (st.wDayOfWeek));
  Add((st.wHour shl 12) or (st.wMinute shl 8) or (st.wSecond shl 4) or (st.wMilliseconds));
  GetDiskFreeSpace(nil, dw1, dw2, dw3, dw4);
  Add((dw1 shl 8) or dw2);
  Add((dw3 shl 8) or dw4);
end;

procedure TSeedGatherer.GatherNT;
begin
  raise Exception.Create('Not implemented');
end;

procedure TSeedGatherer.GatherSlow;
var
  vi: TOSVersionInfo;
begin
  vi.dwOSVersionInfoSize := SizeOf(vi);
  GetVersionEx(vi);
  if vi.dwPlatformId = VER_PLATFORM_WIN32_NT then
    GatherNT
  else
    Gather9x;
end;

procedure TSeedGatherer.RandomizeSeed;
var
  i: integer;
  ix: integer;
  tmp: Cardinal;
begin
  for i := 0 to High(fSeed) do begin
    ix := Random(256);
    tmp := fSeed[i];
    fSeed[i] := fSeed[ix];
    fSeed[ix] := tmp;
  end;
end;

initialization
  Randomize;

end.
