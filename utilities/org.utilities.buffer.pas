{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 *}

unit org.utilities.buffer;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  org.algorithms.queue;

type
  TBuffer = class
  public
    function GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD; virtual; abstract;
  end;



  TByteBuffer = class(TBuffer)
  private
    FAutoFree: Boolean;
    FBuffer: PAnsiChar;
    FLength: DWORD;
    FAvailable: DWORD;
  public
    destructor Destroy; override;
    procedure SetBuffer(Buffer: PAnsiChar; Len: DWORD; AutoFree: Boolean = True);
    function GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD; override;
  end;

  TFileBuffer = class(TBuffer)
  private
    FFileHandle: THandle;
    FFileLength: Int64;
    FFileAvailable: Int64;
  public
    destructor Destroy; override;
    procedure SetBuffer(FileHandle: THandle; FileLength: Int64);
    function GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD; override;
  end;

  TStreamBuffer = class(TBuffer)
  private
    FStream: TStream;
  public
    destructor Destroy; override;
    procedure SetBuffer(AStream: TStream);
    function GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD; override;
  end;

  TBufferPool = class
  private
    FBufferSize: UInt64;
    FBaseAddress: UInt64;
    FCurrAddress: UInt64;
    FAvailableBuffers: TFlexibleQueue<Pointer>;
  public
    destructor Destroy; override;
    procedure Initialize(ReserveBufferCount, InitBufferCount, BufferSize: UInt64);
    function AllocateBuffer: Pointer;
    procedure ReleaseBuffer(Buffer: Pointer);
    property BufferSize: UInt64 read FBufferSize;
  end;

implementation

{ TByteBuffer }

destructor TByteBuffer.Destroy;
begin
  if FAutoFree then begin
    FreeMem(FBuffer, FLength);
    FBuffer := nil;
  end;

  FLength := 0;
  FAvailable := 0;
  inherited;
end;

function TByteBuffer.GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD;
begin
  Result := Len;
  if FAvailable >= Len then begin
    Move(FBuffer^, Buffer^, Len);
    Inc(FBuffer, Len);
    Dec(FAvailable, Len);
  end
  else begin
    Result := FAvailable;
    Move(FBuffer^, Buffer^, FAvailable);
    Dec(FBuffer, FLength - FAvailable);
    FAvailable := 0;
  end;
end;

procedure TByteBuffer.SetBuffer(Buffer: PAnsiChar; Len: DWORD; AutoFree: Boolean);
begin
  FAutoFree := AutoFree;
  FBuffer := Buffer;
  FLength := Len;
  FAvailable := Len;
end;

{ TFileBuffer }

destructor TFileBuffer.Destroy;
begin
  FileClose(FFileHandle);
  inherited;
end;

function TFileBuffer.GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD;
begin
  Result := Len;
  if FFileAvailable >= Len then begin
    FileRead(FFileHandle, Buffer^, Len);
    Dec(FFileAvailable, Len);
  end
  else begin
    Result := FFileAvailable;
    FileRead(FFileHandle, Buffer^, FFileAvailable);
    FFileAvailable := 0;
  end;
end;

procedure TFileBuffer.SetBuffer(FileHandle: THandle; FileLength: Int64);
begin
  FFileHandle := FileHandle;
  FileSeek(FFileHandle, 0, 0);
  FFileLength := FileLength;
  FFileAvailable := FileLength;
end;

{ TBufferPool }

function TBufferPool.AllocateBuffer: Pointer;
begin
  Result := FAvailableBuffers.Dequeue();
  if Result = nil then begin
    Result := VirtualAlloc(Pointer(FCurrAddress), FBufferSize, MEM_COMMIT, PAGE_READWRITE);
    if Result <> nil then
      Inc(FCurrAddress, FBufferSize)
    else
      raise Exception.Create('no more buffer!!');
  end;
end;

destructor TBufferPool.Destroy;
begin
  VirtualFree(Pointer(FBaseAddress), 0, MEM_RELEASE);
  FAvailableBuffers.Free();
  inherited;
end;

procedure TBufferPool.Initialize(ReserveBufferCount, InitBufferCount, BufferSize: UInt64);
var
  I: Integer;
  Buffer: Pointer;
  Address: Pointer;
begin
  if BufferSize mod 4096 <> 0 then
    raise Exception.Create('缓冲大小必须是4KB的整数倍');
  FBufferSize := BufferSize;
  FAvailableBuffers := TFlexibleQueue<Pointer>.Create(InitBufferCount);
  Address := VirtualAlloc(nil, ReserveBufferCount * BufferSize, MEM_TOP_DOWN or MEM_RESERVE, PAGE_READWRITE);
  if Address = nil then
    raise Exception.CreateFmt('预定虚拟地址空间失败 LastErrorCode=%d', [GetLastError()]);
  FBaseAddress := UInt64(Address);
  FCurrAddress := FBaseAddress;
  for I := 0 to InitBufferCount - 1 do begin
    Buffer := VirtualAlloc(Pointer(FCurrAddress), BufferSize, MEM_COMMIT, PAGE_READWRITE);
    Inc(FCurrAddress, BufferSize);
    FAvailableBuffers.Enqueue(Buffer);
  end;
end;

procedure TBufferPool.ReleaseBuffer(Buffer: Pointer);
begin
  FAvailableBuffers.Enqueue(Buffer);
end;

{ TStreamBuffer }

destructor TStreamBuffer.Destroy;
begin
  FStream.Free();
  inherited;
end;

function TStreamBuffer.GetBuffer(Buffer: PAnsiChar; Len: DWORD): DWORD;
begin
  Result := FStream.Read(Buffer^, Len);
end;

procedure TStreamBuffer.SetBuffer(AStream: TStream);
begin
  FStream := AStream;
  FStream.Seek(0, soBeginning);
end;

end.
