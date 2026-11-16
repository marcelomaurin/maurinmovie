unit ummpsha256;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSHA256Digest = array[0..31] of Byte;

function SHA256Bytes(const Data: Pointer; Len: NativeUInt): TSHA256Digest;
function SHA256String(const S: RawByteString): string;
function SHA256File(const FilePath: string): string;
function SHA256DigestToHex(const Digest: TSHA256Digest): string;

implementation

const
  K256: array[0..63] of DWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

type
  TSHA256Ctx = record
    State: array[0..7] of DWord;
    BitLen: QWord;
    Buf: array[0..63] of Byte;
    BufLen: SizeUInt;
  end;

function ROR32(X: DWord; N: Byte): DWord; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

procedure SHA256Init(out Ctx: TSHA256Ctx);
begin
  Ctx.State[0] := $6a09e667;
  Ctx.State[1] := $bb67ae85;
  Ctx.State[2] := $3c6ef372;
  Ctx.State[3] := $a54ff53a;
  Ctx.State[4] := $510e527f;
  Ctx.State[5] := $9b05688c;
  Ctx.State[6] := $1f83d9ab;
  Ctx.State[7] := $5be0cd19;
  Ctx.BitLen := 0;
  Ctx.BufLen := 0;
  FillChar(Ctx.Buf, SizeOf(Ctx.Buf), 0);
end;

procedure SHA256Transform(var Ctx: TSHA256Ctx; const Block: PByte);
var
  W: array[0..63] of DWord;
  A, B, C, D, E, F, G, H, S0, S1, Ch, Maj, Temp1, Temp2: DWord;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (DWord(Block[I * 4]) shl 24) or
            (DWord(Block[I * 4 + 1]) shl 16) or
            (DWord(Block[I * 4 + 2]) shl 8) or
            DWord(Block[I * 4 + 3]);

  for I := 16 to 63 do
  begin
    S0 := ROR32(W[I - 15], 7) xor ROR32(W[I - 15], 18) xor (W[I - 15] shr 3);
    S1 := ROR32(W[I - 2], 17) xor ROR32(W[I - 2], 19) xor (W[I - 2] shr 10);
    W[I] := W[I - 16] + S0 + W[I - 7] + S1;
  end;

  A := Ctx.State[0];
  B := Ctx.State[1];
  C := Ctx.State[2];
  D := Ctx.State[3];
  E := Ctx.State[4];
  F := Ctx.State[5];
  G := Ctx.State[6];
  H := Ctx.State[7];

  for I := 0 to 63 do
  begin
    S1 := ROR32(E, 6) xor ROR32(E, 11) xor ROR32(E, 25);
    Ch := (E and F) xor ((not E) and G);
    Temp1 := H + S1 + Ch + K256[I] + W[I];
    S0 := ROR32(A, 2) xor ROR32(A, 13) xor ROR32(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    Temp2 := S0 + Maj;

    H := G;
    G := F;
    F := E;
    E := D + Temp1;
    D := C;
    C := B;
    B := A;
    A := Temp1 + Temp2;
  end;

  Ctx.State[0] := Ctx.State[0] + A;
  Ctx.State[1] := Ctx.State[1] + B;
  Ctx.State[2] := Ctx.State[2] + C;
  Ctx.State[3] := Ctx.State[3] + D;
  Ctx.State[4] := Ctx.State[4] + E;
  Ctx.State[5] := Ctx.State[5] + F;
  Ctx.State[6] := Ctx.State[6] + G;
  Ctx.State[7] := Ctx.State[7] + H;
end;

procedure SHA256Update(var Ctx: TSHA256Ctx; const Data: Pointer; Len: NativeUInt);
var
  P: PByte;
  Offset, Space: NativeUInt;
begin
  if Len = 0 then Exit;
  P := PByte(Data);
  Ctx.BitLen := Ctx.BitLen + (QWord(Len) shl 3);
  Offset := 0;

  if Ctx.BufLen > 0 then
  begin
    Space := 64 - Ctx.BufLen;
    if Len < Space then
    begin
      Move(P^, Ctx.Buf[Ctx.BufLen], Len);
      Ctx.BufLen := Ctx.BufLen + Len;
      Exit;
    end;
    Move(P^, Ctx.Buf[Ctx.BufLen], Space);
    SHA256Transform(Ctx, @Ctx.Buf[0]);
    Ctx.BufLen := 0;
    Offset := Space;
  end;

  while Offset + 64 <= Len do
  begin
    SHA256Transform(Ctx, @P[Offset]);
    Inc(Offset, 64);
  end;

  if Offset < Len then
  begin
    Ctx.BufLen := Len - Offset;
    Move(P[Offset], Ctx.Buf[0], Ctx.BufLen);
  end;
end;

procedure SHA256Final(var Ctx: TSHA256Ctx; out Digest: TSHA256Digest);
var
  I: Integer;
begin
  Ctx.Buf[Ctx.BufLen] := $80;
  Inc(Ctx.BufLen);

  if Ctx.BufLen > 56 then
  begin
    while Ctx.BufLen < 64 do
    begin
      Ctx.Buf[Ctx.BufLen] := 0;
      Inc(Ctx.BufLen);
    end;
    SHA256Transform(Ctx, @Ctx.Buf[0]);
    Ctx.BufLen := 0;
  end;

  while Ctx.BufLen < 56 do
  begin
    Ctx.Buf[Ctx.BufLen] := 0;
    Inc(Ctx.BufLen);
  end;

  for I := 0 to 7 do
    Ctx.Buf[56 + I] := Byte((Ctx.BitLen shr ((7 - I) * 8)) and $FF);

  SHA256Transform(Ctx, @Ctx.Buf[0]);

  for I := 0 to 7 do
  begin
    Digest[I * 4] := Byte((Ctx.State[I] shr 24) and $FF);
    Digest[I * 4 + 1] := Byte((Ctx.State[I] shr 16) and $FF);
    Digest[I * 4 + 2] := Byte((Ctx.State[I] shr 8) and $FF);
    Digest[I * 4 + 3] := Byte(Ctx.State[I] and $FF);
  end;
end;

function SHA256Bytes(const Data: Pointer; Len: NativeUInt): TSHA256Digest;
var
  Ctx: TSHA256Ctx;
begin
  SHA256Init(Ctx);
  SHA256Update(Ctx, Data, Len);
  SHA256Final(Ctx, Result);
end;

function SHA256DigestToHex(const Digest: TSHA256Digest): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, 64);
  for I := 0 to 31 do
  begin
    Result[I * 2 + 1] := HexChars[Digest[I] shr 4];
    Result[I * 2 + 2] := HexChars[Digest[I] and $0F];
  end;
end;

function SHA256String(const S: RawByteString): string;
var
  D: TSHA256Digest;
begin
  if Length(S) = 0 then
    D := SHA256Bytes(nil, 0)
  else
    D := SHA256Bytes(@S[1], Length(S));
  Result := SHA256DigestToHex(D);
end;

function SHA256File(const FilePath: string): string;
var
  FS: TFileStream;
  Ctx: TSHA256Ctx;
  Buf: array[0..65535] of Byte;
  ReadBytes: LongInt;
  D: TSHA256Digest;
begin
  Result := '';
  FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    SHA256Init(Ctx);
    repeat
      ReadBytes := FS.Read(Buf[0], SizeOf(Buf));
      if ReadBytes > 0 then
        SHA256Update(Ctx, @Buf[0], ReadBytes);
    until ReadBytes = 0;
    SHA256Final(Ctx, D);
    Result := SHA256DigestToHex(D);
  finally
    FS.Free;
  end;
end;

end.

