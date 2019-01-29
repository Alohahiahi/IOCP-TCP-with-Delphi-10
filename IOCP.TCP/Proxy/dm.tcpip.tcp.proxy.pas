unit dm.tcpip.tcp.proxy;

interface

uses
  WinApi.Windows,
  WinApi.Winsock2,

  System.SysUtils,
  AnsiStrings,

  System.Classes,
  superobject,
  org.utilities,
  org.utilities.buffer,
  org.tcpip,
  org.tcpip.tcp,
  org.tcpip.tcp.proxy;

type
  TDMTCPProxyClientSocket = class(TTCPProxyClientSocket)
  protected
    procedure ParseProtocol; override;
    procedure FillProtocol(pHead: PTCPSocketProtocolHead); override;
    procedure ParseAndProcessBody; override;
    procedure ParseAndProcessBodyEx; override;
    procedure NotifyBodyExProgress; override;
  public
    constructor Create(AOwner: TTCPIOManager); override;
  end;

  TDMTCPProxyServerClientSocket = class(TTCPProxyServerClientSocket)
  protected
    procedure ParseProtocol; override;
    procedure FillProtocol(pHead: PTCPSocketProtocolHead); override;
    procedure ParseAndProcessBody; override;
    procedure ParseAndProcessBodyEx; override;
    procedure NotifyBodyExProgress; override;
  public
    constructor Create(AOwner: TTCPIOManager); override;
  end;

  TDMTCPProxy = class(TTCPProxy)
  private
    FSocket: TSocket;            // 监听套接字
    FLocalPort: Word;
    FLocalIP: string;
    FPreAcceptCount: Integer;    // 当前预连接数
  protected
    function DoAcceptEx(IOBuffer: PTCPIOBuffer): Boolean; override;
    function DoConnectEx(IOBuffer: PTCPIOBuffer): Boolean; override;
  public
    constructor Create;
    procedure Start; override;
    procedure Stop; override;
    property Socket: TSocket read FSocket;
    property LocalIP: string read FLocalIP write FLocalIP;
    property LocalPort: Word read FLocalPort write FLocalPort;
    property PreAcceptCount: Integer read FPreAcceptCount;
  end;

implementation

{ TDMTCPProxyClientSocket }

constructor TDMTCPProxyClientSocket.Create(AOwner: TTCPIOManager);
begin
  inherited;

end;

procedure TDMTCPProxyClientSocket.FillProtocol(pHead: PTCPSocketProtocolHead);
begin
  inherited;

end;

procedure TDMTCPProxyClientSocket.NotifyBodyExProgress;
begin
  inherited;

end;

procedure TDMTCPProxyClientSocket.ParseAndProcessBody;
begin
  inherited;

end;

procedure TDMTCPProxyClientSocket.ParseAndProcessBodyEx;
begin
  inherited;

end;

procedure TDMTCPProxyClientSocket.ParseProtocol;
begin
  inherited;

end;

{ TDMTCPProxyServerClientSocket }

constructor TDMTCPProxyServerClientSocket.Create(AOwner: TTCPIOManager);
begin
  inherited;

end;

procedure TDMTCPProxyServerClientSocket.FillProtocol(pHead: PTCPSocketProtocolHead);
begin
  inherited;

end;

procedure TDMTCPProxyServerClientSocket.NotifyBodyExProgress;
begin
  inherited;

end;

procedure TDMTCPProxyServerClientSocket.ParseAndProcessBody;
begin
  inherited;
end;

procedure TDMTCPProxyServerClientSocket.ParseAndProcessBodyEx;
begin
  inherited;

end;

procedure TDMTCPProxyServerClientSocket.ParseProtocol;
begin
  inherited;

end;

{ TDMTCPProxy }

constructor TDMTCPProxy.Create;
begin
  Inherited;
  FSocket := INVALID_SOCKET;
  FLocalIP := '0.0.0.0';
  FLocalPort := 0;
  FPreAcceptCount := 0;
end;

function TDMTCPProxy.DoAcceptEx(IOBuffer: PTCPIOBuffer): Boolean;
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

  IOContext: TDMTCPProxyServerClientSocket;
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
  IOContext := IOBuffer^.Context as TDMTCPProxyServerClientSocket;

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
        IOContext.FStatus := IOContext.FStatus or $00000002; // [连接中][已连接]
        // dxm 2018.12.17
        if IOContext.RemoteIP <> '127.0.0.1' then begin
          ErrDesc := Format('[%d][%d]<%s.DoAcceptEx> Refuse [%s:%d]',
            [ FSocket,
              GetCurrentThreadId(),
              ClassName,
              IOContext.FRemoteIP,
              IOContext.FRemotePort]);
          WriteLog(llWarning, ErrDesc);
          IOContext.HardCloseSocket();
        end;
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
    // 所有就直接将IOBuffer和Context回收算了，如果真的需要补充预连接在向TTCPIOManager要相关资源

    ErrDesc := Format('[%d][%d]<%s.DoAcceptEx> IO内部错误: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  // dxm 2018.11.24
  // 此时，并没有触发任何后续操作，直接回收上下文即可
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

function TDMTCPProxy.DoConnectEx(IOBuffer: PTCPIOBuffer): Boolean;
var
  iRet: Integer;
  ErrDesc: string;
  IOStatus: Int64;
  IOContext: TDMTCPProxyClientSocket;
begin
  // dxm 2018.11.1
  // 1. 判断IO是否出错
  // 2. 初始化套接字上下文
  // 3. 关联通信套接字与IO完成端口

  // dxm 2018.11.13
  // 当ConnectEx重叠IO通知到达时：
  // 1. WSAECONNREFUSED 10061 通常是对端服务器未启动             [通知时][调用时][正常][可重用]
  // 2. WSAENETUNREACH  10051 网络不可达，通常是路由无法探知远端 [通知时][调用时][正常][可重用]
  // 3. WSAETIMEDOUT    10060 连接超时                           [通知时][------][正常][可重用][分析：服务端投递的预连接太少，需动态设置预投递上限]

  Result := True;
  IOContext := IOBuffer^.Context as TDMTCPProxyClientSocket;

  if IOBuffer^.LastErrorCode = 0 then begin {$region [IO 正常]}
    // dxm 2018.11.13
    // 激活套接字之前的属性
    // dxm 2018.11.13
    // 本函数不应该错误，否则要么是参数设置有问题，要么是理解偏差
    // 如果出错暂时定为 [致命][不可重用 ]
    iRet := setsockopt(IOContext.FSocket,
                      SOL_SOCKET,
                      SO_UPDATE_CONNECT_CONTEXT,
                      nil,
                      0);
    if iRet <> SOCKET_ERROR then begin
      IOContext.FStatus := IOContext.FStatus or $00000002; // [连接中][已连接]
    end
    else begin //if iRet = SOCKET_ERROR then begin // [更新套接字属性失败]
      Result := False;
      IOContext.Set80000000Error();
      iRet := WSAGetLastError();
      ErrDesc := Format('[%d][%d]<%s.DoConnectEx.setsockopt> LastErrorCode=%d, Status=%s',
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
    // dxm 2018.11.13
    // 当ConnectEx重叠IO通知到达时：
    // 1. WSAECONNREFUSED 10061 通常是对端服务器未启动             [通知时][调用时][正常][可重用]
    // 2. WSAENETUNREACH  10051 网络不可达，通常是路由无法探知远端 [通知时][调用时][正常][可重用]
    // 3. WSAETIMEDOUT    10060 连接超时                           [通知时][------][正常][可重用]

    Result := False;
    iRet := IOBuffer^.LastErrorCode;
    if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
      IOContext.Set80000000Error();

    ErrDesc := Format('[%d][%d]<%s.DoConnectEx> IO内部错误: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  if Result then begin // 连接正常
    // dxm 2018.11.28
    // 删除[CONNECT]并检查返回的IOStatus
    // [1].如果有[ERROR]，只可能是通知IO返回时添加，当通知IO由于感知到有[CONNECT]，故直接退出了
    //     因此，此处要负责归还本端上下文，并同S端解耦，如果时机恰当还应归还S端上下文，同时将Result置为False以切断后续流程
    // [2].如果没有[ERROR]但是有[NOTIFY]，说明S端出错后，发出了通知IO，但通知IO还未返回，此处只需切断后续逻辑，其它事情由通知IO处理
    // [3].如果没有[ERROR]，也没有[NOTIFY]，说明S端正常，本端也正常

    // dxm 2018.11.28
    // [情景1] CONNECT成功
    // [情景1-1]
    // C端----<NOTIFY><NOCOUPLING>----<NOTIFY 返回>----[CONNECT 返回]-------
    // S端----[解耦]-[定时器]-------------------------------------------------------
    // [情景1-2]
    // C端----<NOTIFY><NOCOUPLING>----[CONNECT 返回]---<NOTIFY 返回>--------
    // S端----[解耦]-[定时器]-------------------------------------------------------
    // [情景1-3]
    // C端----[CONNECT 返回]------------------------------------------------
    // S端------------------------------------------------------------------

    IOStatus := InterlockedAnd64(IOContext.FIOStatus, PROXY_IO_STATUS_DEL_CONNECT);
    if not IOContext.HasNotify(IOStatus) then begin // [情景1-1][情景1-3]
      if not IOContext.HasCoupling(IOStatus) then begin // [情景1-1]
        Result := False;
        IOContext.DecouplingWithCorr(False);
        // dxm 2018.12.01
        // 因为C端才成功建立连接，没有后续其它任何操作，故可直接关闭套接字然后归还
        IOContext.HardCloseSocket();
        EnqueueFreeContext(IOContext);
      end
      else begin // [情景1-3]
        // 正常
      end;
    end
    else begin // [情景1-2]
      Result := False;
    end;
  end
  else begin
    // [情景2] CONNECT失败
    // [情景2-1]
    // C端----<NOTIFY><NOCOUPLING>----<NOTIFY 返回>----[CONNECT 返回]----[解耦]---
    // S端----[解耦]--------------------------------------------------------------
    // [情景2-2]
    // C端----<NOTIFY><NOCOUPLING>----[CONNECT 返回]---<NOTIFY 返回>-----[解耦]---
    // S端----[解耦]-[定时器]-------------------------------------------------------------
    // [情景2-3]
    // C端----[CONNECT 返回]-----[解耦]-[定时器]------------------------------------------
    // S端------------------------<NOTIFY>------------------------------------------------

    IOStatus := InterlockedAnd64(IOContext.FIOStatus, PROXY_IO_STATUS_DEL_CONNECT_ADD_ERROR);
    if not IOContext.HasNotify(IOStatus) then begin // [情景2-1][情景2-3]
      IOContext.DecouplingWithCorr(IOContext.HasCoupling(IOStatus));
      if IOContext.HasCoupling(IOStatus) then begin // [情景2-3]
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d]<%s.DoConnectEx> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//        [ IOContext.FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          30,
//          IOContext.StatusString()]);
//        WriteLog(llDebug, ErrDesc);
//{$Endif}
        FTimeWheel.StartTimer(IOContext, 30 * 1000, DoWaitNotify);
      end
      else begin // [情景2-1]
        EnqueueFreeContext(IOContext);
      end;
    end
    else begin //[情景2-2]
      // 由通知IO处理线程负责归还本端
    end;
  end;
end;

procedure TDMTCPProxy.Start;
var
  iRet: Integer;
begin
  inherited;
  FSocket := ListenAddr(FLocalIP, FLocalPort);
  if FSocket = INVALID_SOCKET then
    raise Exception.Create('服务启动失败.');
  //投递预连接
  iRet := PostMultiAccept(FSocket, FMaxPreAcceptCount);
  if iRet = 0 then begin
    raise Exception.Create('投递预连接失败');
  end
  else begin
    InterlockedAdd(FPreAcceptCount, iRet);
  end;
end;

procedure TDMTCPProxy.Stop;
begin
  inherited;

end;

end.
