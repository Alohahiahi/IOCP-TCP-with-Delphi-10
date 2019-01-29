unit dm.tcpip.tcp.server;

interface

uses
  WinApi.Windows,
  WinApi.Winsock2,

  System.SysUtils,
  AnsiStrings,

  System.Classes,
  superobject,
  org.utilities,
  org.tcpip,
  org.tcpip.tcp,
  org.tcpip.tcp.server;

type
  TDMTCPServerClientSocket = class(TTCPServerClientSocket)
  protected
    procedure ParseProtocol; override;
    procedure FillProtocol(pHead: PTCPSocketProtocolHead); override;
    procedure ParseAndProcessBody; override;
    procedure ParseAndProcessBodyEx; override;
    procedure NotifyBodyExProgress; override;
  end;

  TDMTCPServer = class(TTCPServer)
  private
    FSocket: TSocket;
    FLocalIP: string;
    FLocalPort: Word;
    FOnlineCount: Integer;
    FPreAcceptCount: Integer;       // 当前预连接数
  protected
    function DoAcceptEx(IOBuffer: PTCPIOBuffer): Boolean; override;
  public
    constructor Create;
    procedure EnqueueFreeContext(AContext: TTCPIOContext); override;
    procedure Start; override;
    procedure Stop; override;
    property Socket: TSocket read FSocket;
    property LocalIP: string read FLocalIP write FLocalIP;
    property LocalPort: Word read FLocalPort write FLocalPort;
    property OnlineCount: Integer read FOnlineCount;
    property PreAcceptCount: Integer read FPreAcceptCount;
  end;

implementation

{ TDMTCPServerClientSocket }

procedure TDMTCPServerClientSocket.FillProtocol(pHead: PTCPSocketProtocolHead);
begin
  inherited;

end;

procedure TDMTCPServerClientSocket.NotifyBodyExProgress;
var
  buf: TMemoryStream;
  JO: ISuperObject;

  Length: DWORD;
  iRet: Integer;
  ErrDesc: string;

  Finished: Int64;
  Interval: Int64;
begin
  Interval := FHead^.LengthEx div 50;
  if Interval = 0 then Interval := 1;
  Finished := FRecvBytes - FHeadSize - FHead^.Length;

  if ((Finished div Interval in [1..50]) and (Finished mod Interval < 4096 * 4)) or
    (Finished = FHead^.LengthEx) then begin

    JO := TSuperObject.Create();
    JO.I['Finished'] := FRecvBytes - FHeadSize - FHead^.Length;
    JO.I['Total'] := FHead^.LengthEx;

    buf := TMemoryStream.Create();
    Length := JO.SaveTo(buf);

    iRet := SendToPeer(buf, Length, IO_OPTION_ONCEMORE);
    if (iRet <> 0) and (iRet <> ERROR_IO_PENDING) then begin
      ErrDesc := Format('[%d][%d]<%s.NotifyBodyExProgress> LastErrorCode=%d',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      FOwner.WriteLog(llError, ErrDesc);
      Set80000000Error();
    end;
  end;
end;

procedure TDMTCPServerClientSocket.ParseAndProcessBody;
var
  IOBuffer: PTCPIOBuffer;
  buf: TMemoryStream;
  PC: PAnsiChar;
  Unfilled: Int64;
  Length: DWORD;
  iRet: Integer;
  ErrDesc: string;

  JO: ISuperObject;
  FilePath: string;
  Cmd: string;
begin
  if not FBodyInFile then begin
    Unfilled := FHead^.Length;
    buf := TMemoryStream.Create();
    while (Unfilled > 0) and FOutstandingIOs.Pop(IOBuffer) do begin
      PC := IOBuffer^.Buffers[0].buf;
      Inc(PC, IOBuffer^.Position);
      Length := IOBuffer^.BytesTransferred - IOBuffer^.Position;

      if Length <= Unfilled then begin
        buf.Write(PC^, Length);
        Dec(Unfilled, Length);
        FOwner.EnqueueIOBuffer(IOBuffer);
      end
      else begin
        buf.Write(PC^, Unfilled);
        IOBuffer^.Position := IOBuffer^.Position + Unfilled;
        Unfilled := 0;
        FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
      end;
    end;

    buf.Seek(0, soBeginning);
    JO := TSuperObject.ParseStream(buf, False);
{$IfDef DEBUG}
    ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBody> Peer send Body: %s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        JO.AsJson()]);
    FOwner.WriteLog(llDebug, ErrDesc);
{$Endif}

    Cmd := JO.S['Cmd'];
    if Cmd = 'Echo' then begin
      iRet := SendToPeer(buf, FHead^.Length, FHead^.Options);
      if (iRet <> 0) and (iRet <> ERROR_IO_PENDING) then begin
        ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBody.SendToPeer> LastErrorCode=%d',
          [ FSocket,
            GetCurrentThread(),
            ClassName,
            iRet]);
        FOwner.WriteLog(llError, ErrDesc);
      end;
    end
    else if Cmd = 'UploadFile' then begin
      FBodyExInFile := True;
      FBodyExFileName := FOwner.TempDirectory + JO.S['DstLocation'];
      buf.Free();
    end
    else if Cmd = 'DownloadFile' then begin
      FilePath := JO.S['SrcLocation'];
      JO := TSuperObject.Create();
      JO.S['Cmd'] := 'DownloadFile';
      JO.S['FileName'] := ExtractFileName(FilePath);
      buf := TMemoryStream.Create();
      Length := JO.SaveTo(buf);
      iRet := SendToPeer(buf, Length, FilePath, IO_OPTION_EMPTY);
      if (iRet <> 0) and (iRet <> ERROR_IO_PENDING) then begin
        ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBody.SendToPeer> LastErrorCode=%d',
          [ FSocket,
            GetCurrentThread(),
            ClassName,
            iRet]);
        FOwner.WriteLog(llError, ErrDesc);
      end;
    end;
  end
  else begin

  end;


  inherited;
end;

procedure TDMTCPServerClientSocket.ParseAndProcessBodyEx;
var
  iRet: Integer;
  ErrDesc: string;
  buf: TMemoryStream;
  JO: ISuperObject;
  Length: Integer;
begin
  if not FBodyExInFile then begin

  end
  else begin
    JO := TSuperObject.Create();
    JO.S['DstLocation'] := FBodyExFileName;
    JO.S['Success'] := 'OK';

{$IfDef DEBUG}
    ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBodyEx.SendToPeer> JsonString=%s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        JO.AsJSon()]);
    FOwner.WriteLog(llDebug, ErrDesc);
{$Endif}

    buf := TMemoryStream.Create();
    Length := JO.SaveTo(buf);
    iRet := SendToPeer(buf, Length, IO_OPTION_EMPTY);
    if (iRet <> 0) and (iRet <> ERROR_IO_PENDING) then begin
      ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBodyEx.SendToPeer> LastErrorCode=%d',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      FOwner.WriteLog(llError, ErrDesc);
    end;
  end;
end;

procedure TDMTCPServerClientSocket.ParseProtocol;
begin
  inherited;

end;

{ TDMTCPServer }

constructor TDMTCPServer.Create;
begin
  inherited;
  FSocket := INVALID_SOCKET;
  FLocalIP := '0.0.0.0';
  FLocalPort := 0;
  FOnlineCount := 0;
  FPreAcceptCount := 0;
end;

function TDMTCPServer.DoAcceptEx(IOBuffer: PTCPIOBuffer): Boolean;
var
  LocalSockaddr: TSockAddrIn;
  PLocalSockaddr: PSockAddr;

  RemoteSockaddr: TSockAddrIn;
  PRemoteSockaddr: PSockAddr;

  LocalSockaddrLength, RemoteSockaddrLength: Integer;
  RemoteIP: array[0..15] of AnsiChar;
  PC: PAnsiChar;
  Len: Integer;
  iRet: Integer;
  dwRet: DWORD;
  ErrDesc: string;

  IOContext: TDMTCPServerClientSocket;
begin
  // dxm 2018.11.1
  // 1. 判断IO是否出错
  // 2. 初始化套接字上下文
  // 3. 关联通信套接字与IO完成端口
  // 4. 补充预连接

  // dxm 2018.11.2
  // 当AcceptEx重叠IO通知到达时：
  // 1. ERROR_IO_PENDING 重叠IO初始化成功，稍后通知完成          [------][调用时][正常]
  // 2. WSAECONNRESET    对端提交连接请求后，随即又终止了该请求  [通知时][------][正常][可重用][说明一旦收到连接请求，后续对端即使取消，本地也只是标记而已]

  Result := False;
  IOContext := IOBuffer^.Context as TDMTCPServerClientSocket;

  if IOBuffer^.LastErrorCode <> WSAECONNRESET then begin {$region [IO 正常]}

    // 初始化地址信息
    org.tcpip.lpfnGetAcceptExSockaddrs(IOBuffer^.Buffers[0].buf,
                        0,                        // 调用AccpetEx时约定不传输连接数据
                        Sizeof(TSockAddrIn) + 16,
                        Sizeof(TSockAddrIn) + 16,
                        PLocalSockaddr,           // [out]
                        LocalSockaddrLength,      // [out]
                        PRemoteSockaddr,          // [out]
                        RemoteSockaddrLength);    // [out]

    Move(PLocalSockaddr^, LocalSockaddr, LocalSockaddrLength);
    Move(PRemoteSockaddr^, RemoteSockaddr, RemoteSockaddrLength);

    IOContext.FRemotePort := ntohs(RemoteSockaddr.sin_port);
    PC := inet_ntoa(in_addr(RemoteSockaddr.sin_addr));
    if PC <> nil then begin
      Len := AnsiStrings.StrLen(PC);
      if Len > 15 then Len := 15; // RemoteIP: array[0..15] of AnsiChar;
      Move(PC^, RemoteIP[0], Len);
      RemoteIP[Len] := #0;
      IOContext.FRemoteIP := string(AnsiStrings.StrPas(RemoteIP));
    end
    else begin
      IOContext.FRemoteIP := '';
    end;

    // dxm 2018.11.1
    // 设置通信套接字属性同监听套接字
    // dxm 2018.11.2
    // 本函数不应该错误，否则要么是参数设置有问题，要么是理解偏差
    // 如果出错暂时定为 [致命][不可重用 ]
    iRet := setsockopt(IOContext.FSocket,
                      SOL_SOCKET,
                      SO_UPDATE_ACCEPT_CONTEXT,
                      @FSocket,
                      SizeOf(TSocket));
    if iRet <> SOCKET_ERROR then begin {$region [更新套接字属性成功]}
      // 关联完成端口
      dwRet := FIOHandle.AssociateDeviceWithCompletionPort(IOContext.FSocket, 0);
      if dwRet = 0 then begin
        // 设置最终处理结果
        Result := True;
        // dxm 2018.12.10
        InterlockedIncrement(FOnlineCount);
        IOContext.FStatus := IOContext.FStatus or $00000002; // [连接中][已连接]
      end
      else begin
        IOContext.Set80000000Error();
        ErrDesc := Format('[%d][%d]<%s.DoAcceptEx.AssociateDeviceWithCompletionPort> LastErrorCode=%d, Status=%s',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            dwRet,
            IOContext.StatusString()]);
        WriteLog(llNormal, ErrDesc);
      end;
    {$endregion}
    end
    else begin
      IOContext.Set80000000Error();
      iRet := WSAGetLastError();
      ErrDesc := Format('[%d][%d]<%s.DoAcceptEx.setsockopt> LastErrorCode=%d, Status=%s',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          IOContext.StatusString()]);
      WriteLog(llFatal, ErrDesc);
    end;
  {$endregion}
  end
  else begin
    // dxm 2018.11.2
    // [个人理解]此时套接字是可重用的
    // 本来既然套接字可重用，那么在补充预连接时是可复用的，但考虑到：
    // 1. 连接成功后，后续其它操作也可能错误
    // 2. 补充预连接操作不一定发生
    // 所有就直接将IOBuffer和Context回收算了，如果真的需要补充预连接在向TTCPServer要相关资源

    ErrDesc := Format('[%d][%d]<%s.DoAcceptEx> IO内部错误: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  if not Result then
    EnqueueFreeContext(IOContext);

  // 补充预连接
  InterlockedDecrement(FPreAcceptCount);
  if FIOHandle.Status = tssRunning then begin
    iRet := PostSingleAccept(FSocket);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      ErrDesc := Format('[%d]<%s.DoAcceptEx.PostSingleAccept> LastErrorCode=%d',
        [ GetCurrentThreadId(),
          ClassName,
          iRet]);
      WriteLog(llNormal, ErrDesc);
    end else
      InterlockedIncrement(FPreAcceptCount);
  end;
end;

procedure TDMTCPServer.EnqueueFreeContext(AContext: TTCPIOContext);
begin
  inherited;
  InterlockedDecrement(FOnlineCount);
end;

procedure TDMTCPServer.Start;
var
  iRet: Integer;
begin
  inherited;
  FSocket := ListenAddr(FLocalIP, FLocalPort);
  if FSocket = INVALID_SOCKET then
    raise Exception.Create('服务启动失败.');
  // 投递预连接
  iRet := PostMultiAccept(FSocket, FMaxPreAcceptCount);
  if iRet = 0 then begin
    raise Exception.Create('投递预连接失败');
  end
  else begin
    InterlockedAdd(FPreAcceptCount, iRet);
  end;
end;

procedure TDMTCPServer.Stop;
begin
  inherited;

end;

end.
