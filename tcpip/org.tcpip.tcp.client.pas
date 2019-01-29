{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10.29
 * @Brief:
 *}

unit org.tcpip.tcp.client;

interface
uses
  Winapi.Windows,
  Winapi.Winsock2,
  System.SysUtils,
  System.Classes,
  System.Math,
  org.algorithms,
  org.algorithms.queue,
  org.utilities,
  org.utilities.buffer,
  org.tcpip,
  org.tcpip.tcp;

type
  PTCPRequestParameters = ^TTCPRequestParameters;
  TTCPRequestParameters = record
    RemoteIP: string;
    RemotePort: Word;
  end;

  TTCPClientSocket = class(TTCPIOContext)
  protected
    procedure DoConnected; override;
    procedure TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD); override;
  public
    constructor Create(AOwner: TTCPIOManager); override;
    destructor Destroy; override;
  end;

  TTCPClient = class(TTCPIOManager)
  private
    FMaxPreIOContextCount: Integer;    // 客户端开始工作前准备的已绑定、未连接的套接字数
    FIOContextClass: TTCPIOContextClass;
    FFreeContexts: TFlexibleQueue<TTCPIOContext>;
    //\\
    procedure SetMaxPreIOContextCount(const Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass); override;
    function DequeueFreeContext(IOType: DWORD): TTCPIOContext; override;
    procedure EnqueueFreeContext(AContext: TTCPIOContext); override;
    //\\
    procedure DoWaitTIMEWAIT(IOContext: TTCPIOContext); override;
    //\\
    function SendRequest(Parameters: PTCPRequestParameters; Body: PAnsiChar;
      Length: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: PAnsiChar;
      Length: DWORD; BodyEx: PAnsiChar; LengthEx: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: PAnsiChar;
      Length: DWORD; BodyEx: TStream; LengthEx: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: PAnsiChar;
      Length: DWORD; FilePath: string; Options: DWORD): Boolean; overload;

    function SendRequest(Parameters: PTCPRequestParameters; Body: TStream;
      Length: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: TStream;
      Length: DWORD; BodyEx: PAnsiChar; LengthEx: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: TStream;
      Length: DWORD; BodyEx: TStream; LengthEx: DWORD; Options: DWORD): Boolean; overload;
    function SendRequest(Parameters: PTCPRequestParameters; Body: TStream;
      Length: DWORD; FilePath: string; Options: DWORD): Boolean; overload;
    //\\
    procedure Start; override;
    procedure Stop; override;
    property MaxPreIOContextCount: Integer read FMaxPreIOContextCount write SetMaxPreIOContextCount;
  end;
implementation

{ TTCPClientSocket }

constructor TTCPClientSocket.Create(AOwner: TTCPIOManager);
begin
  inherited;
  FStatus := $20000000;
end;

destructor TTCPClientSocket.Destroy;
begin
  inherited;
end;

procedure TTCPClientSocket.DoConnected;
var
  Status: DWORD;
  IOStatus: Int64;
//{$IfDef DEBUG}
//  Msg: string;
//{$Endif}
begin
  if Assigned(FOwner.OnConnected) then
    FOwner.OnConnected(nil, Self);

//{$IfDef DEBUG}
//  Msg := Format('[%d][%d]<%s.DoConnected>[INIT][FIOStatus] FIOStatus=%x',
//    [ FSocket,
//      GetCurrentThreadId(),
//      ClassName,
//      FIOStatus]);
//  FOwner.WriteLog(llDebug, Msg);
//{$Endif}

  SendBuffer();
  Status := FStatus;
  IOStatus := FSendIOStatus;
  TeaAndCigaretteAndMore(IOStatus, Status);

  if Status and $80000040 = $00000040 then begin // [正常结束]
    if not HasWriteIO(IOStatus) then
      FOwner.EnqueueFreeContext(Self);
  end
  else if HasError(IOStatus) or (Status and $80000000 = $80000000) then begin
    if not HasWriteOrIO(IOStatus) then begin
      FOwner.EnqueueFreeContext(Self);
    end;
  end
  else begin
    // nothing?
  end;
end;

procedure TTCPClientSocket.TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD);
var
  More: Boolean;
begin
  More := True;
  while (not HasErrorOrReadIO(Tea)) and (FStatus and $80000000 = $00000000) and More do begin
    if FStatus and $8000005F = $00000003 then begin // 1000,...,0101,1111,
      if FRecvBytes < FHeadSize then begin // 首次读(或继续读)Protocol Head
        Tea := RecvProtocol();
      end
      else begin  // 此时应用层协议头读完
        FStatus := FStatus or $00000004; // 协议头接收完
        ParseProtocol(); // 解析协议头 [这里可能产生独立的$8000,0000错误]
        Cigarette := FStatus;

        if FStatus and $80000000 = $00000000 then begin // 协议解析成功
          GetBodyFileHandle();
          Cigarette := FStatus;
          if FRecvBytes < FHeadSize + FHead^.Length then begin
            if FStatus and $80000000 = $00000000 then begin
              Tea := RecvBuffer();
            end;
          end;
        end;
      end;
    end
    else if FStatus and $8000005F = 00000007 then begin // 1000,...,0101,1111
      if FBodyInFile then // 将收到的Buffer写入临时文件
        WriteBodyToFile(); // [这里可能产生独立的$8000,0000错误]
      Cigarette := FStatus;

      if FStatus and $80000000 = $00000000 then begin
        if FRecvBytes < FHeadSize + FHead^.Length then begin // 继续接收Body
          Tea := RecvBuffer();
        end
        else begin
          FStatus := FStatus or $00000008;

          ParseAndProcessBody(); // [这里可能产生非独立独立的$8000,0000错误]
          Cigarette := FStatus;

          if FStatus and $80000000 = $00000000 then begin
            if FHead^.LengthEx = 0 then begin
              if FHead^.Options and IO_OPTION_ONCEMORE = $00000000 then begin
                Tea := SendDisconnect();
              end
              else begin
                FRecvBytes := FRecvBytes - FHeadSize - FHead^.Length;
                FStatus := FStatus and $E0000003; // 1110,0000,...,0000,0011
              end;
            end
            else begin
              GetBodyExFileHandle();
              Cigarette := FStatus;
              if FRecvBytes < FHeadSize + FHead^.Length + FHead^.LengthEx then begin
              // 开始接收BodyEx
                if FStatus and $80000000 = $00000000 then begin
                  Tea := RecvBuffer();
                end;
              end;
            end;
          end;
        end;
      end;
    end
    else if (FStatus and $8000005F = $0000000F) and (FHead^.LengthEx > 0) then begin //1000,...,0101,1111
      if FBodyExInFile then // 写入BodyExFile
        WriteBodyExToFile(); // [这里可能产生非独立独立的$8000,0000错误]
      Cigarette := FStatus;

      if FStatus and $80000000 = $00000000 then begin
        if FRecvBytes < FHeadSize + FHead^.Length + FHead^.LengthEx then begin // 继续接收BodyEx
          Tea := RecvBuffer();
        end
        else begin
          FStatus := FStatus or $00000010;
          ParseAndProcessBodyEx(); // [这里可能产生非独立独立的$8000,0000错误]
          Cigarette := FStatus;

          // dxm 2018.11.13
          // 1.对客户端来说，到此，收到了服务端发送的全部响应
          // 2.既然收到了服务端的全部响应，也证明客户端的数据全部发送完成
          // 因此，这里要投递优雅关闭重叠IO了

          if FStatus and $80000000 = $00000000 then begin
            if FHead^.Options and IO_OPTION_ONCEMORE = $00000000 then begin
              Tea := SendDisconnect();
            end
            else begin
              FRecvBytes := FRecvBytes - FHeadSize - FHead^.Length - FHead^.LengthEx;
              FStatus := FStatus and $E0000003; // 1110,0000,...,0000,0011
            end;
          end;
        end;
      end;
    end
//    else if FStatus and $00000060 = $00000020 then begin  // 1000,...,0101,1111
//      // nothing
//    end
    else if ((FStatus and $8000005F = $0000005F) and (FHead^.LengthEx > 0)) or
            ( FStatus and $8000005F = $0000004F) then begin // 1000,...,0101,1111
      Cigarette := FStatus;
      More := False; // [dxm 2018.11.9 no more? maybe!]
    end
    else begin
      // nothing or unkown error
    end;
  end;
end;

{ TTCPClient }

constructor TTCPClient.Create;
begin
  inherited;
  FMaxPreIOContextCount := MAX_PRE_IOCONTEXT_COUNT; // 默认最大预连接数
  FIOContextClass := nil;
end;

function TTCPClient.DequeueFreeContext(IOType: DWORD): TTCPIOContext;
begin
  Result := FFreeContexts.Dequeue();
  if Result = nil then begin
    Result := FIOContextClass.Create(Self);
//    Result.FSocket := INVALID_SOCKET;
  end;
end;

destructor TTCPClient.Destroy;
begin
  FFreeContexts.Free();
  inherited;
end;

procedure TTCPClient.DoWaitTIMEWAIT(IOContext: TTCPIOContext);
{$IfDef DEBUG}
var
  Msg: string;
{$Endif}
begin
{$IfDef DEBUG}
  Msg := Format('[%d][%d]<%s.DoWaitTIMEWAIT> enqueue IOContext into FreeIOConetxt queue!',
    [ IOContext.Socket,
      GetCurrentThreadId(),
      ClassName]);
  WriteLog(llDebug, Msg);
{$Endif}
  inherited;
  FFreeContexts.Enqueue(IOContext);
end;

procedure TTCPClient.EnqueueFreeContext(AContext: TTCPIOContext);
var
  IOContext: TTCPClientSocket;
//{$Ifdef DEBUG}
//  Msg: string;
//{$Endif}
begin
  inherited;
  IOContext := AContext as TTCPClientSocket;
    // 仅当上下文状态中存在$8000,0000时强制关闭套接字对象
  if IOContext.FStatus and $C0000000 = $80000000 then begin
    if IOContext.Socket <> INVALID_SOCKET then begin
      IOContext.HardCloseSocket();
    end;
    IOContext.FStatus := IOContext.FStatus and $20000000;
    FFreeContexts.Enqueue(AContext);
  end
  else begin
//{$IfDef DEBUG}
//    Msg := Format('[%d][%d]<%s.EnqueueFreeContext> enqueue IOContext into TimeWheel for <TIMEWAITExpired>, ExpireTime=%ds, Status=%s',
//      [ IOContext.FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        4 * 60,
//        IOContext.StatusString()]);
//    WriteLog(llDebug, Msg);
//{$Endif}
    IOContext.FStatus := IOContext.FStatus and $20000000;
    FTimeWheel.StartTimer(IOContext, 4 * 60 * 1000, DoWaitTIMEWAIT);
  end;
end;

procedure TTCPClient.RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass);
begin
  FIOContextClass := AClass;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: PAnsiChar; Length: DWORD; Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := 0;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      buf := TByteBuffer.Create();
      buf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(buf);

      buf := TByteBuffer.Create();
      buf.SetBuffer(Body, Length);
      IOContext.FSendBuffers.EnqueueEx(buf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    // dxm 2018.11.14
    // 客户端通过该函数进行连接并准备了第一块待发送的数据
    // 但是此时不能发送，只能先暂存，因为连接还没建立
    // 由于暂存和发送动作时分离的，这里首先得正确地初始化控制变量，
    // 否则，如果有后续发送需求的话，发送函数SendBuffer将不会触发
    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    // dxm 2018.11.13
    // 当ConnectEx重叠IO通知到达时：
    // 1. WSAECONNREFUSED 10061 通常是对端服务器未启动             [通知时][调用时][正常][可重用]
    // 2. WSAENETUNREACH  10051 网络不可达，通常是路由无法探知远端 [通知时][调用时][正常][可重用]
    // 3. WSAETIMEDOUT    10060 连接超时                           [通知时][------][正常][可重用]

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    FreeMem(Body, Length);
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: TStream; Length, Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := 0;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      ByteBuf := TByteBuffer.Create();
      ByteBuf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(ByteBuf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(Body);
      IOContext.FSendBuffers.EnqueueEx(StreamBuf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    Body.Free();
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: PAnsiChar; Length: DWORD; FilePath: string; Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  FileHandle: THandle;
  FileLength: Int64;
  FileBuf: TFileBuffer;

  ErrDesc: string;
begin
  Result := True;

  FileHandle := FileOpen(FilePath, fmOpenRead or fmShareDenyWrite);
  if FileHandle <> INVALID_HANDLE_VALUE then begin
    FileLength := FileSeek(FileHandle, 0, 2);
    IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

    if PrepareSingleIOContext(IOContext) then begin
      IOContext.FRemoteIP := Parameters^.RemoteIP;
      IOContext.FRemotePort := Parameters^.RemotePort;

      AHead.Version := VERSION;
      AHead.Options := Options;
      AHead.Length := Length;
      AHead.LengthEx := FileLength;

      IOContext.FillProtocol(@AHead);

      pHead := AllocMem(FHeadSize);
      Move((@AHead)^, pHead^, FHeadSize);

      IOContext.FSendBuffers.Lock();
      try
        buf := TByteBuffer.Create();
        buf.SetBuffer(pHead, FHeadSize);
        IOContext.FSendBuffers.EnqueueEx(buf);

        buf := TByteBuffer.Create();
        buf.SetBuffer(Body, Length);
        IOContext.FSendBuffers.EnqueueEx(buf);

        FileBuf := TFileBuffer.Create();
        FileBuf.SetBuffer(FileHandle, FileLength);
        IOContext.FSendBuffers.EnqueueEx(FileBuf);
      finally
        IOContext.FSendBuffers.Unlock();
      end;

      IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + FileLength;

      IOBuffer := DequeueIOBuffer();
      IOBuffer^.OpType := otConnect;
      IOBuffer^.Context := IOContext;

      iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
      if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
        Result := False;
        ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            iRet,
            IOContext.StatusString()]);
        WriteLog(llNormal, ErrDesc);

        if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
          IOContext.Set80000000Error();

        EnqueueIOBuffer(IOBuffer);
        EnqueueFreeContext(IOContext);
      end;
    end
    else begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);
      FreeMem(Body, Length);
      FileClose(FileHandle);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    FreeMem(Body, Length);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: PAnsiChar; Length: DWORD; BodyEx: TStream; LengthEx,
  Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := LengthEx;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      buf := TByteBuffer.Create();
      buf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(buf);

      buf := TByteBuffer.Create();
      buf.SetBuffer(Body, Length);
      IOContext.FSendBuffers.EnqueueEx(buf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(BodyEx);
      IOContext.FSendBuffers.EnqueueEx(StreamBuf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + LengthEx;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    FreeMem(Body, Length);
    BodyEx.Free();
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: PAnsiChar; Length: DWORD; BodyEx: PAnsiChar; LengthEx,
  Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := LengthEx;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      buf := TByteBuffer.Create();
      buf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(buf);

      buf := TByteBuffer.Create();
      buf.SetBuffer(Body, Length);
      IOContext.FSendBuffers.EnqueueEx(buf);

      buf := TByteBuffer.Create();
      buf.SetBuffer(BodyEx, LengthEx);
      IOContext.FSendBuffers.EnqueueEx(buf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + LengthEx;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    FreeMem(Body, Length);
    FreeMem(BodyEx, LengthEx);
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: TStream; Length: DWORD; FilePath: string; Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  FileHandle: THandle;
  FileLength: Int64;
  FileBuf: TFileBuffer;

  ErrDesc: string;
begin
  Result := True;

  FileHandle := FileOpen(FilePath, fmOpenRead or fmShareDenyWrite);
  if FileHandle <> INVALID_HANDLE_VALUE then begin
    FileLength := FileSeek(FileHandle, 0, 2);
    IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

    if PrepareSingleIOContext(IOContext) then begin
      IOContext.FRemoteIP := Parameters^.RemoteIP;
      IOContext.FRemotePort := Parameters^.RemotePort;

      AHead.Version := VERSION;
      AHead.Options := Options;
      AHead.Length := Length;
      AHead.LengthEx := FileLength;

      IOContext.FillProtocol(@AHead);

      pHead := AllocMem(FHeadSize);
      Move((@AHead)^, pHead^, FHeadSize);

      IOContext.FSendBuffers.Lock();
      try
        buf := TByteBuffer.Create();
        buf.SetBuffer(pHead, FHeadSize);
        IOContext.FSendBuffers.EnqueueEx(buf);

        Streambuf := TStreamBuffer.Create();
        Streambuf.SetBuffer(Body);
        IOContext.FSendBuffers.EnqueueEx(Streambuf);

        FileBuf := TFileBuffer.Create();
        FileBuf.SetBuffer(FileHandle, FileLength);
        IOContext.FSendBuffers.EnqueueEx(FileBuf);
      finally
        IOContext.FSendBuffers.Unlock();
      end;

      IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + FileLength;

      IOBuffer := DequeueIOBuffer();
      IOBuffer^.OpType := otConnect;
      IOBuffer^.Context := IOContext;

      iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
      if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
        Result := False;
        ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            iRet,
            IOContext.StatusString()]);
        WriteLog(llNormal, ErrDesc);

        if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
          IOContext.Set80000000Error();

        EnqueueIOBuffer(IOBuffer);
        EnqueueFreeContext(IOContext);
      end;
    end
    else begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);
      Body.Free();
      FileClose(FileHandle);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    Body.Free();
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: TStream; Length: DWORD; BodyEx: TStream; LengthEx,
  Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := LengthEx;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      buf := TByteBuffer.Create();
      buf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(buf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(Body);
      IOContext.FSendBuffers.EnqueueEx(StreamBuf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(BodyEx);
      IOContext.FSendBuffers.EnqueueEx(StreamBuf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + LengthEx;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    Body.Free();
    BodyEx.Free();
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPClient.SendRequest(Parameters: PTCPRequestParameters;
  Body: TStream; Length: DWORD; BodyEx: PAnsiChar; LengthEx,
  Options: DWORD): Boolean;
var
  iRet: Integer;
  IOContext: TTCPClientSocket;
  IOBuffer: PTCPIOBuffer;
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  ErrDesc: string;
begin
  Result := True;
  IOContext := TTCPClientSocket(DequeueFreeContext($20000000));

  if PrepareSingleIOContext(IOContext) then begin
    IOContext.FRemoteIP := Parameters^.RemoteIP;
    IOContext.FRemotePort := Parameters^.RemotePort;

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := LengthEx;

    IOContext.FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    IOContext.FSendBuffers.Lock();
    try
      buf := TByteBuffer.Create();
      buf.SetBuffer(pHead, FHeadSize);
      IOContext.FSendBuffers.EnqueueEx(buf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(Body);
      IOContext.FSendBuffers.EnqueueEx(StreamBuf);

      buf := TByteBuffer.Create();
      buf.SetBuffer(BodyEx, LengthEx);
      IOContext.FSendBuffers.EnqueueEx(buf);
    finally
      IOContext.FSendBuffers.Unlock();
    end;

    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length + LengthEx;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    iRet := FIOHandle.PostConnect(IOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d]<%s.SendRequest.PostConnect> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llNormal, ErrDesc);

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        IOContext.Set80000000Error();

      EnqueueIOBuffer(IOBuffer);
      EnqueueFreeContext(IOContext);
    end;
  end
  else begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.SendRequest.PrepareSingleIOContext> failed, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    Body.Free();
    FreeMem(BodyEx, LengthEx);
    EnqueueFreeContext(IOContext);
  end;
end;

procedure TTCPClient.SetMaxPreIOContextCount(const Value: Integer);
begin
  if FMaxPreIOContextCount <> Value then
    FMaxPreIOContextCount := Value;
end;

procedure TTCPClient.Start;
var
  iRet: Integer;
begin
  inherited;
  if FIOContextClass = nil then
    raise Exception.Create('业务处理类尚未注册,启动前请调用 RegisterIOContextClass');
  // 创建并初始化内存池
  FBufferPool := TBufferPool.Create();
  FBufferPool.Initialize(1000 * 64, 100 * 64, FBufferSize);
  // 创建并初始化IOBuffer池
  FIOBuffers := TFlexibleQueue<PTCPIOBuffer>.Create(64);
  FIOBuffers.OnItemNotify := DoIOBufferNotify;
  // 创建并初始化IOContext池
  FFreeContexts := TFlexibleQueue<TTCPIOContext>.Create(64);
  FFreeContexts.OnItemNotify := DoIOContextNotify;
  // 准备套接字上下文
  iRet := PrepareMultiIOContext(FIOContextClass, FMaxPreIOContextCount);
  if iRet = 0 then
    raise Exception.Create('准备套接字上下文失败');
end;

procedure TTCPClient.Stop;
begin
  inherited;

end;

end.

