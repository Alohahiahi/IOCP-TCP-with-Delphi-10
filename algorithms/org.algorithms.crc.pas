{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2019.1
 * @Brief:
 * @References:
 * A PAINLESS GUIDE TO CRC ERROR DETECTION ALGORITHMS
 * @Remark:
 * TABLE ALGORITHM:
 * r = 0;
 * while (len--)
 *  r = ((r << 8) | *p++) ^ t[(r >> (W - 8)) & 0xFF];
 *
 * DIRECT TABLE ALGORITHM:
 * r = 0;
 * while (len--)
 *  r = (r << 8) ^ t[(r >> (W - 8)) ^ *p++];
 *
 * @Modifications:
 *
 *}

unit org.algorithms.crc;

interface

type
  TCrc<T> = class
  public type
    TCrcTable = array [0..255] of T;
  protected
    FPoly: T;
    FInit: T;
    FXorOut: T;
    FTable: TCrcTable;
    FHiMask: T;
  public
    property Init: T read FInit;
    property XorOut: T read FXorOut;
  end;

  TCrc8 = class(TCrc<Byte>)
  public type
    TCrc8Type = (
      crc_8_ATM,
      crc_8_ITU,
      crc_8_ICODE,
      crc_8_J1850
    );
  private
    procedure GenTable;
  public
    constructor Create(Crc8Type: TCrc8Type = crc_8_ATM); overload;
    constructor Create(Poly, Init, XorOut: Byte); overload;
    function Compute(Msg: Pointer; nBytes: Integer): Byte; overload;
    function Compute(Msg: Pointer; nBytes: Integer; Remander: Byte): Byte; overload;
  end;

  TCrc16 = class(TCrc<Word>)
  public type
    TCrc16Type = (
      crc_16_CCITT_FFFF,
      crc_16_CCITT_1D0F,
      crc_16_GENIBUS,
      crc_16_XMODEM,
      crc_16_BUYPASS,
      crc_16_DDS110,
      crc_16_DECT_R,
      crc_16_DECT_X,
      crc_16_EN_13757,
      crc_16_T10_DIF,
      crc_16_TELEDISK
    );
  private
    procedure GenTable;
  public
    constructor Create(Crc16Type: TCrc16Type = crc_16_CCITT_FFFF); overload;
    constructor Create(Poly, Init, XorOut: Word); overload;
    function Compute(Msg: Pointer; nBytes: Integer): Word; overload;
    function Compute(Msg: Pointer; nBytes: Integer; Remander: Word): Word; overload;
  end;

  TCrc32 = class(TCrc<Cardinal>)
  public type
    TCrc32Type = (
      crc_32_BZIP2,
      crc_32_MPEG_2,
      crc_32_POSIX,
      crc_32_Q,
      crc_32_XFER
    );
  private
    procedure GenTable;
  public
    constructor Create(Crc32Type: TCrc32Type = crc_32_POSIX); overload;
    constructor Create(Poly, Init, XorOut: Cardinal); overload;
    function Compute(Msg: Pointer; nBytes: Integer): Cardinal; overload;
    function Compute(Msg: Pointer; nBytes: Integer; Remander: Cardinal): Cardinal; overload;
  end;

  TCrc64 = class(TCrc<UInt64>)
  public type
    TCrc64Type = (
      crc_64,
      crc_64_WE
    );
  private
    procedure GenTable;
  public
    constructor Create(Crc64Type: TCrc64Type = crc_64); overload;
    constructor Create(Poly, Init, XorOut: UInt64); overload;
    function Compute(Msg: Pointer; nBytes: Integer): UInt64; overload;
    function Compute(Msg: Pointer; nBytes: Integer; Remander: UInt64): UInt64; overload;
  end;

implementation

{ TCrc8 }

function TCrc8.Compute(Msg: Pointer; nBytes: Integer): Byte;
var
  reg: Byte;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := FInit;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[reg xor buf^];
    Inc(buf);
  end;

  Result := reg xor FXorOut;
end;

constructor TCrc8.Create(Crc8Type: TCrc8Type);
begin
  FHiMask := $80;
  case Crc8Type of
    // crc_8_ATM
    crc_8_ATM: begin
      FPoly := $07;
      FInit := $00;
      FXorOut := $00;
    end;

    // crc_8_ITU
    crc_8_ITU: begin
      FPoly := $07;
      FInit := $00;
      FXorOut := $55;
    end;

    // crc_8_ICODE
    crc_8_ICODE: begin
      FPoly := $1D;
      FInit := $FD;
      FXorOut := $00;
    end;

    // crc_8_J1850
    crc_8_J1850: begin
      FPoly := $1D;
      FInit := $FF;
      FXorOut := $FF;
    end;
  end;

  GenTable();
end;

function TCrc8.Compute(Msg: Pointer; nBytes: Integer; Remander: Byte): Byte;
var
  reg: Byte;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := Remander;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[reg xor buf^];
    Inc(buf);
  end;

  Result := reg;
end;

constructor TCrc8.Create(Poly, Init, XorOut: Byte);
begin
  FHiMask := $80;
  FPoly := Poly;
  FInit := Init;
  FXorOut := XorOut;

  GenTable();
end;

procedure TCrc8.GenTable;
var
  I, J, reg: Byte;
begin
  for I := 0 to 255 do begin
    reg := I; //
    for J := 0 to 7 do begin
      if reg and FHiMask <> 0 then
        reg := (reg shl 1) xor FPoly
      else
        reg := reg shl 1;
    end;
    FTable[I] := reg;
  end;
end;

{ TCrc16 }

function TCrc16.Compute(Msg: Pointer; nBytes: Integer; Remander: Word): Word;
var
  reg: Word;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := Remander;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 8) xor buf^];
    Inc(buf);
  end;

  Result := reg;
end;

function TCrc16.Compute(Msg: Pointer; nBytes: Integer): Word;
var
  reg: Word;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := FInit;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 8) xor buf^];
    Inc(buf);
  end;

  Result := reg xor FXorOut;
end;

constructor TCrc16.Create(Poly, Init, XorOut: Word);
begin
  FHiMask := $8000;
  FPoly := Poly;
  FInit := Init;
  FXorOut := XorOut;

  GenTable();
end;

constructor TCrc16.Create(Crc16Type: TCrc16Type);
begin
  FHiMask := $8000;
  case Crc16Type of
    // crc_16_CCITT
    crc_16_CCITT_FFFF: begin
      FPoly := $1021;
      FInit := $FFFF;
      FXorOut := $0000;
    end;

    crc_16_CCITT_1D0F: begin
      FPoly := $1021;
      FInit := $1D0F;
      FXorOut := $0000;
    end;

    crc_16_GENIBUS: begin
      FPoly := $1021;
      FInit := $FFFF;
      FXorOut := $FFFF;
    end;

    crc_16_XMODEM: begin
      FPoly := $1021;
      FInit := $0000;
      FXorOut := $0000;
    end;

    // crc_16_BUYPASS
    crc_16_BUYPASS: begin
      FPoly := $8005;
      FInit := $0000;
      FXorOut := $0000;
    end;

    crc_16_DDS110: begin
      FPoly := $8005;
      FInit := $800D;
      FXorOut := $0000;
    end;

    crc_16_DECT_R: begin
      FPoly := $0589;
      FInit := $0000;
      FXorOut := $0001;
    end;

    crc_16_DECT_X: begin
      FPoly := $0589;
      FInit := $0000;
      FXorOut := $0000;
    end;

    crc_16_EN_13757: begin
      FPoly := $3D65;
      FInit := $0000;
      FXorOut := $FFFF;
    end;

    crc_16_T10_DIF: begin
      FPoly := $8BB7;
      FInit := $0000;
      FXorOut := $0000;
    end;

    crc_16_TELEDISK: begin
      FPoly := $A097;
      FInit := $0000;
      FXorOut := $0000;
    end;
  end;

  GenTable();
end;

procedure TCrc16.GenTable;
var
  I, J, reg: Word;
begin
  for I := 0 to 255 do begin
    reg := I shl 8; // 只关注有效位，或者说将有效位移到高8位
    for J := 0 to 7 do begin
      if reg and FHiMask <> 0 then
        reg := (reg shl 1) xor FPoly
      else
        reg := reg shl 1;
    end;
    FTable[I] := reg;
  end;
end;

{ TCrc32 }

function TCrc32.Compute(Msg: Pointer; nBytes: Integer; Remander: Cardinal): Cardinal;
var
  reg: Cardinal;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := Remander;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 24) xor buf^];
    Inc(buf);
  end;

  Result := reg;
end;

function TCrc32.Compute(Msg: Pointer; nBytes: Integer): Cardinal;
var
  reg: Cardinal;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := FInit;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 24) xor buf^];
    Inc(buf);
  end;

  Result := reg xor FXorOut;
end;

constructor TCrc32.Create(Poly, Init, XorOut: Cardinal);
begin
  FHiMask := $80000000;
  FPoly := Poly;
  FInit := Init;
  FXorOut := XorOut;

  GenTable();
end;

constructor TCrc32.Create(Crc32Type: TCrc32Type);
begin
  FHiMask := $80000000;
  case Crc32Type of
    crc_32_BZIP2: begin
      FPoly := $04C11DB7;
      FInit := $FFFFFFFF;
      FXorOut := $FFFFFFFF;
    end;

    crc_32_MPEG_2: begin
      FPoly := $04C11DB7;
      FInit := $FFFFFFFF;
      FXorOut := $00000000;
    end;

    // crc_32_POSIX
    crc_32_POSIX: begin
      FPoly := $04C11DB7;
      FInit := $00000000;
      FXorOut := $FFFFFFFF;
    end;

    crc_32_Q: begin
      FPoly := $814141AB;
      FInit := $00000000;
      FXorOut := $00000000;
    end;

    crc_32_XFER: begin
      FPoly := $000000AF;
      FInit := $00000000;
      FXorOut := $00000000;
    end;
  end;

  GenTable();
end;

procedure TCrc32.GenTable;
var
  I, J, reg: Cardinal;
begin
  for I := 0 to 255 do begin
    reg := I shl 24; // 只关注有效位，或者说将有效位移到高8位
    for J := 0 to 7 do begin
      if reg and FHiMask <> 0 then
        reg := (reg shl 1) xor FPoly
      else
        reg := reg shl 1;
    end;
    FTable[I] := reg;
  end;
end;

{ TCrc64 }

function TCrc64.Compute(Msg: Pointer; nBytes: Integer; Remander: UInt64): UInt64;
var
  reg: UInt64;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := Remander;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 56) xor buf^];
    Inc(buf);
  end;

  Result := reg;
end;

function TCrc64.Compute(Msg: Pointer; nBytes: Integer): UInt64;
var
  reg: UInt64;
  I: Integer;
  buf: PByte;
begin
  buf := Msg;
  reg := FInit;
  for I := 0 to nBytes - 1 do begin
    reg := (reg shl 8) xor FTable[(reg shr 56) xor buf^];
    Inc(buf);
  end;

  Result := reg xor FXorOut;
end;

constructor TCrc64.Create(Poly, Init, XorOut: UInt64);
begin
  FHiMask := $8000000000000000;
  FPoly := Poly;
  FInit := Init;
  FXorOut := XorOut;

  GenTable();
end;

constructor TCrc64.Create(Crc64Type: TCrc64Type);
begin
  FHiMask := $8000000000000000;

  case Crc64Type of
    crc_64: begin
      FPoly := $42F0E1EBA9EA3693;
      FInit := $0000000000000000;
      FXorOut := $0000000000000000;
    end;

    crc_64_WE: begin
      FPoly := $42F0E1EBA9EA3693;
      FInit := $FFFFFFFFFFFFFFFF;
      FXorOut := $FFFFFFFFFFFFFFFF;
    end;
  end;

  GenTable();
end;

procedure TCrc64.GenTable;
var
  I, J, reg: UInt64;
begin
  for I := 0 to 255 do begin
    reg := I shl 56; // 只关注有效位，或者说将有效位移到高8位
    for J := 0 to 7 do begin
      if reg and FHiMask <> 0 then
        reg := (reg shl 1) xor FPoly
      else
        reg := reg shl 1;
    end;
    FTable[I] := reg;
  end;
end;

end.
