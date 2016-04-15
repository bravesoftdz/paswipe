unit isaac;

// These must be off, never ever turn it on!!!
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

{  This is ISAAC, a high-quality pseudo-random number generator.
   ISAAC is crypto-secure.
   ISAAC has no bias.
   ISAAC has a minimal garanteed period of 2^40.
   ISAAC average period is 2^8295.
   ISAAC algorithm is the property of Bob Jenkins.
   ISAAC is freely reusable.

   ISAAC can be used for encryption (mainly stream cipher).
   ISAAC has a 8192 bits seed (read: 8192 bits key for encryption).

   ISAAC Object-oriented Delphi implementation version 1.0.0
   by Sébastien SAUVAGE <sebsauvage at sebsauvage dot net>
   http://sebsauvage.net

   The ISAAC algorihm is freely reusable.
   This implementation of ISAAC is freely reusable.
   Please let me know if you make interesting uses of this implementation.
   Please mention:
      ISAAC algorithm by Bob Jenkins (http://burtleburtle.net/bob/)
      Delphi ISAAC implementation by Sébastien SAUVAGE <sebsauvage at sebsauvage dot net>
      http://sebsauvage.net

   This implementation was tested under Delphi 4, but should work with no
   great changes in other versions of Delphi.
   Works with Delphi 5 and Free Pascal as well, testet by Stefan Ascher

   This is a readable (not fast) implementation.
   Code is not optimized.

   To get exactly the same results as the C version, you will have to:
     - change FALSE to TRUE at line £££1 in code (look for £££1 in code).
     - use the following program:
           x : TIsaac;
           i : integer;
           x.InitZero;
           x.Isaac;    // This is needed to get the same results as readable.c
           for i:=0 to 20 write(IntToHex(x.val,8));

   Cause : the C implementation inits with a seed although the seed is zero.
   The C implementation makes an additional call to Isaac() before reading
   values (which is unneeded because Isaac() is called within Init()).

   For normal use, you should NOT call Isaac(). This will be done automatically
   when needed by val().  You also should leave the boolean value to FALSE
   at £££1. This will speedup initialisation at no cost for security.

   2 do list:
     - faster implementation (unfold loops, etc.)
     - even faster implementation (x86 ASM ?)
     - create a sample program using this class
     - create a utility program that generate an x bytes random data file
       with a good seed (time/date/keyboard/mouse?).
     - documentation
     - methods for gathering random data (time/date/keyboard/mouse/other ?)
     - methods to seed with a String, with an integer.
     - TIsaacStream ?
     - Self-test method, with exception raising on problem.
     - TIssacCrypt ? (encryption with a 'password' used as the key.)

I'm no programming God, so please let me know if you find any bug
in this implementation.

Any question regarding this implementation should be sent directly
to Sebastien Sauvage, *not* to Bob Jenkins.
Bob Jenkins is not responsible for this implementation.

Any question regarding the ISAAC algorithm should be sent directly
to Bob Jenkins, *not* Sebastien Sauvage.
I'm not responsible for the design of ISAAC.
Paper and C/C++/Modula-2/Java implementations available here:
http://burtleburtle.net/bob/rand/isaac.html

Quote from the author of the ISAAC algorithm:
> My random number generator, ISAAC.
> (c) Bob Jenkins, March 1996
> You may use this code in any way you wish, and it is free.  No warrantee.

History:

 May, 16th 2000, version 1.0.0
    - First implementation.

Usage example:

   var
       i: integer;
       x: TIsaac;
   begin
        x.Create;
        for i:=1 to 20 do Memo1.Lines.Add(IntToHex(x.val, 8));
        x.reSeed;  // reseed exactly as in Create()
        for i:=1 to 20 do Memo1.Lines.Add(IntToHex(x.val, 8));  // get the same values

   end;

 $Id: isaac.pas,v 1.1 2007/07/08 21:00:33 Administrator Exp $
}

interface

type
  TIsaac = class(TObject)
  private
    { private methods }
    rsl: array[0..255] of Cardinal; { the results given to the user }
    mem: array[0..255] of Cardinal; { the internal state }
    count: integer; { count through the results in rsl[] }
    aa: Cardinal; { accumulator }
    bb: Cardinal; { the last result }
    cc: Cardinal; { counter, guarantees cycle is at least 2^^40 }
  public
    { public methods }
    constructor Create; overload;
    constructor Create(const s: array of Cardinal); overload;
    constructor Create(const SeedFile: string); overload;
    procedure Seed; overload; { Re-seed with a zeroed seed }
    procedure Seed(const s: array of Cardinal); overload;
    procedure UpdateSeedFile(const SeedFile: string);
    { Re-seed with a given seed }
    procedure Isaac; { generate new numbers }
    function Val: Cardinal; { get 1 random value }
    function ByteVal(const AVal: Byte): Byte;
    function IntVal(const Max: integer): integer;
  end;

implementation

uses
  SysUtils;

{ initialize the objet with a zeroed seed }

constructor TIsaac.Create;
begin
  inherited;
  Seed;
end;

{ initialize the objet with a given seed.
  You can safely use an array of integers }

constructor TIsaac.Create(const s: array of Cardinal);
begin
  inherited Create;
  Seed(s);
end;

constructor TIsaac.Create(const SeedFile: string);
var
  s: array[0..255] of Cardinal;
  BytesRead: integer;
  f: file of Byte;
begin
  inherited Create;
  // Load a Seed file
  FillChar(s, 256, 0);
  if FileExists(SeedFile) then begin
    AssignFile(f, SeedFile);
    {$I-}Reset(F);{$I+}
    if IOResult = 0 then begin
      BlockRead(F, s[0], SizeOf(s), BytesRead);
      CloseFile(f);
      Seed(s);
    end else
      Seed(s);
  end else
    Seed(s);
end;

procedure TIsaac.UpdateSeedFile(const SeedFile: string);
var
  f: file of Byte;
  s: array[0..255] of Cardinal;
  i: integer;
begin
  // Get new random numbers, do not save current numbers
  for i := 0 to High(s) do
    s[i] := Val;

  // Save the Seed file
  AssignFile(f, SeedFile);
  {$I-}Rewrite(F);{$I+}
  if IOResult = 0 then begin
    BlockWrite(F, s[0], SizeOf(s));
    CloseFile(f);
  end;
end;

{ Re-seed the objet with a zeroed seed }

procedure TIsaac.Seed;
var
  s: array[0..255] of Cardinal;
begin
  FillChar(s, 256, 0);
  Seed(s);
end;

{ Re-seed the objet with a given seed.
  The array can have any size. The first 256 values will be used.
  If the array has less than 256 values, all the available values will be used.
  You can use either Cardinals or Integer with no problem. }

procedure TIsaac.Seed(const s: array of Cardinal);
var
  i, m: Word;
  a, b, c, d, e, f, g, h: Cardinal;
begin
  m := Succ(High(s) and 255);
  // make sure m doesn't exceed 255; succ(m) is the maximum number of elements in s
  Move(s[0], rsl[0], m * SizeOf(integer)); // move m elements from s to rsl
  if (m < 256) then
    // fill in remainder with zero
    FillChar(rsl[m], SizeOf(rsl) - (m * SizeOf(integer)), 0);

  aa := 0;
  bb := 0;
  cc := 0;

  // the golden ratio
  a := $9E3779B9;

  b := a;
  c := a;
  d := a;
  e := a;
  f := a;
  g := a;
  h := a;

  // scramble it
  for i := 0 to 3 do begin
    // mix a,b,c,d,e,f,g and h
    a := a xor (b shl 11);
    d := d + a;
    b := b + c;
    b := b xor (c shr 2);
    e := e + b;
    c := c + d;
    c := c xor (d shl 8);
    f := f + c;
    d := d + e;
    d := d xor (e shr 16);
    g := g + d;
    e := e + f;
    e := e xor (f shl 10);
    h := h + e;
    f := f + g;
    f := f xor (g shr 4);
    a := a + f;
    g := g + h;
    g := g xor (h shl 8);
    b := b + g;
    h := h + a;
    h := h xor (a shr 9);
    c := c + h;
    a := a + b;
  end;

  // fill in mem[] with messy stuff
  i := 0;
  while (i < 256) do begin

    // use all the information in the seed
    a := a + rsl[i];
    b := b + rsl[i + 1];
    c := c + rsl[i + 2];
    d := d + rsl[i + 3];
    e := e + rsl[i + 4];
    f := f + rsl[i + 5];
    g := g + rsl[i + 6];
    h := h + rsl[i + 7];

    // mix a,b,c,d,e,f,g and h
    a := a xor (b shl 11);
    d := d + a;
    b := b + c;
    b := b xor (c shr 2);
    e := e + b;
    c := c + d;
    c := c xor (d shl 8);
    f := f + c;
    d := d + e;
    d := d xor (e shr 16);
    g := g + d;
    e := e + f;
    e := e xor (f shl 10);
    h := h + e;
    f := f + g;
    f := f xor (g shr 4);
    a := a + f;
    g := g + h;
    g := g xor (h shl 8);
    b := b + g;
    h := h + a;
    h := h xor (a shr 9);
    c := c + h;
    a := a + b;
    mem[i] := a;
    mem[i + 1] := b;
    mem[i + 2] := c;
    mem[i + 3] := d;
    mem[i + 4] := e;
    mem[i + 5] := f;
    mem[i + 6] := g;
    mem[i + 7] := h;
    Inc(i, 8);
  end;

  // do a second pass to make all of the seed affect all of mem
  i := 0;
  while (i < 256) do begin

    // use all the information in the seed
    a := a + mem[i];
    b := b + mem[i + 1];
    c := c + mem[i + 2];
    d := d + mem[i + 3];
    e := e + mem[i + 4];
    f := f + mem[i + 5];
    g := g + mem[i + 6];
    h := h + mem[i + 7];

    // mix a,b,c,d,e,f,g and h
    a := a xor (b shl 11);
    d := d + a;
    b := b + c;
    b := b xor (c shr 2);
    e := e + b;
    c := c + d;
    c := c xor (d shl 8);
    f := f + c;
    d := d + e;
    d := d xor (e shr 16);
    g := g + d;
    e := e + f;
    e := e xor (f shl 10);
    h := h + e;
    f := f + g;
    f := f xor (g shr 4);
    a := a + f;
    g := g + h;
    g := g xor (h shl 8);
    b := b + g;
    h := h + a;
    h := h xor (a shr 9);
    c := c + h;
    a := a + b;
    mem[i] := a;
    mem[i + 1] := b;
    mem[i + 2] := c;
    mem[i + 3] := d;
    mem[i + 4] := e;
    mem[i + 5] := f;
    mem[i + 6] := g;
    mem[i + 7] := h;
    Inc(i, 8);
  end;

  // fill in the first set of results
  Isaac;
end;

{ Generate 256 results.  This implementation is not optimized.
 You do NOT need to call this method. It will be done automatically
 when needed when you call val() to get a value. }

procedure TIsaac.Isaac;
var
  i: Integer;
  x, y: Cardinal;
begin
  Inc(cc);
  Inc(bb, cc);
  for i := 0 to 255 do begin
    x := mem[i];
    case (i and 3) of
      0: aa := aa xor (aa shl 13);
      1: aa := aa xor (aa shr 6);
      2: aa := aa xor (aa shl 2);
      3: aa := aa xor (aa shr 16);
    end;
    aa := aa + mem[(i + 128) and 255];
    y := mem[(x shr 2) and 255] + aa + bb;
    mem[i] := y;
    bb := mem[(y shr 10) and 255] + x;
    rsl[i] := bb;
  end;
  count := 0;
end;

{ Call rand.val() to get a random value (32 bits).
  You can use the result as an Integer with no problem. }

function TIsaac.Val: Cardinal;
begin
  Result := rsl[count];
  Inc(count);
  if (count > 255) then
    Isaac;
end;

function TIsaac.ByteVal(const AVal: Byte): Byte;
begin
  // Return a value of type Byte between 0 and AVal
  Result := Trunc((Val / $FFFFFFFF) * AVal);
end;

function TIsaac.IntVal(const Max: integer): integer;
begin
  Result := Trunc((Val / $FFFFFFFF) * Max);
end;

end.
