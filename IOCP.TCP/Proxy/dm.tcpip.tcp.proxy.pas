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
    FSocket: TSocket;            // �����׽���
    FLocalPort: Word;
    FLocalIP: string;
    FPreAcceptCount: Integer;    // ��ǰԤ������
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
  // 1. �ж�IO�Ƿ����
  // 2. ��ʼ���׽���������
  // 3. ����ͨ���׽�����IO��ɶ˿�
  // 4. ����Ԥ����

  // dxm 2018.11.2
  // ��AcceptEx�ص�IO֪ͨ����ʱ��
  // 1. ERROR_IO_PENDING �ص�IO��ʼ���ɹ����Ժ�֪ͨ���          [------][����ʱ][����]
  // 2. WSAECONNRESET    �Զ��ύ����������漴����ֹ�˸�����  [֪ͨʱ][------][����][������][˵��һ���յ��������󣬺����Զ˼�ʹȡ��������Ҳֻ�Ǳ�Ƕ���]

  Result := False;
  IOContext := IOBuffer^.Context as TDMTCPProxyServerClientSocket;

  if IOBuffer^.LastErrorCode <> WSAECONNRESET then begin {$region [IO ����]}
    // ��ʼ����ַ��Ϣ
    org.tcpip.lpfnGetAcceptExSockaddrs(IOBuffer^.Buffers[0].buf,
                        0,                        // ����AccpetExʱԼ����������������
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
    // ����ͨ���׽�������ͬ�����׽���
    // dxm 2018.11.2
    // ��������Ӧ�ô��󣬷���Ҫô�ǲ������������⣬Ҫô�����ƫ��
    // ���������ʱ��Ϊ [����][�������� ]
    iRet := setsockopt(IOContext.FSocket,
                      SOL_SOCKET,
                      SO_UPDATE_ACCEPT_CONTEXT,
                      @FSocket,
                      SizeOf(TSocket));
    if iRet <> SOCKET_ERROR then begin {$region [�����׽������Գɹ�]}
      // ������ɶ˿�
      dwRet := FIOHandle.AssociateDeviceWithCompletionPort(IOContext.FSocket, 0);
      if dwRet = 0 then begin
        // �������մ�����
        Result := True;
        IOContext.FStatus := IOContext.FStatus or $00000002; // [������][������]
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
    // [�������]��ʱ�׽����ǿ����õ�
    // ������Ȼ�׽��ֿ����ã���ô�ڲ���Ԥ����ʱ�ǿɸ��õģ������ǵ���
    // 1. ���ӳɹ��󣬺�����������Ҳ���ܴ���
    // 2. ����Ԥ���Ӳ�����һ������
    // ���о�ֱ�ӽ�IOBuffer��Context�������ˣ���������Ҫ����Ԥ��������TTCPIOManagerҪ�����Դ

    ErrDesc := Format('[%d][%d]<%s.DoAcceptEx> IO�ڲ�����: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  // dxm 2018.11.24
  // ��ʱ����û�д����κκ���������ֱ�ӻ��������ļ���
  if not Result then
    EnqueueFreeContext(IOContext);

  // ����Ԥ����
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
  // 1. �ж�IO�Ƿ����
  // 2. ��ʼ���׽���������
  // 3. ����ͨ���׽�����IO��ɶ˿�

  // dxm 2018.11.13
  // ��ConnectEx�ص�IO֪ͨ����ʱ��
  // 1. WSAECONNREFUSED 10061 ͨ���ǶԶ˷�����δ����             [֪ͨʱ][����ʱ][����][������]
  // 2. WSAENETUNREACH  10051 ���粻�ɴͨ����·���޷�֪̽Զ�� [֪ͨʱ][����ʱ][����][������]
  // 3. WSAETIMEDOUT    10060 ���ӳ�ʱ                           [֪ͨʱ][------][����][������][�����������Ͷ�ݵ�Ԥ����̫�٣��趯̬����ԤͶ������]

  Result := True;
  IOContext := IOBuffer^.Context as TDMTCPProxyClientSocket;

  if IOBuffer^.LastErrorCode = 0 then begin {$region [IO ����]}
    // dxm 2018.11.13
    // �����׽���֮ǰ������
    // dxm 2018.11.13
    // ��������Ӧ�ô��󣬷���Ҫô�ǲ������������⣬Ҫô�����ƫ��
    // ���������ʱ��Ϊ [����][�������� ]
    iRet := setsockopt(IOContext.FSocket,
                      SOL_SOCKET,
                      SO_UPDATE_CONNECT_CONTEXT,
                      nil,
                      0);
    if iRet <> SOCKET_ERROR then begin
      IOContext.FStatus := IOContext.FStatus or $00000002; // [������][������]
    end
    else begin //if iRet = SOCKET_ERROR then begin // [�����׽�������ʧ��]
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
    // ��ConnectEx�ص�IO֪ͨ����ʱ��
    // 1. WSAECONNREFUSED 10061 ͨ���ǶԶ˷�����δ����             [֪ͨʱ][����ʱ][����][������]
    // 2. WSAENETUNREACH  10051 ���粻�ɴͨ����·���޷�֪̽Զ�� [֪ͨʱ][����ʱ][����][������]
    // 3. WSAETIMEDOUT    10060 ���ӳ�ʱ                           [֪ͨʱ][------][����][������]

    Result := False;
    iRet := IOBuffer^.LastErrorCode;
    if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
      IOContext.Set80000000Error();

    ErrDesc := Format('[%d][%d]<%s.DoConnectEx> IO�ڲ�����: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  if Result then begin // ��������
    // dxm 2018.11.28
    // ɾ��[CONNECT]����鷵�ص�IOStatus
    // [1].�����[ERROR]��ֻ������֪ͨIO����ʱ��ӣ���֪ͨIO���ڸ�֪����[CONNECT]����ֱ���˳���
    //     ��ˣ��˴�Ҫ����黹���������ģ���ͬS�˽�����ʱ��ǡ����Ӧ�黹S�������ģ�ͬʱ��Result��ΪFalse���жϺ�������
    // [2].���û��[ERROR]������[NOTIFY]��˵��S�˳���󣬷�����֪ͨIO����֪ͨIO��δ���أ��˴�ֻ���жϺ����߼�������������֪ͨIO����
    // [3].���û��[ERROR]��Ҳû��[NOTIFY]��˵��S������������Ҳ����

    // dxm 2018.11.28
    // [�龰1] CONNECT�ɹ�
    // [�龰1-1]
    // C��----<NOTIFY><NOCOUPLING>----<NOTIFY ����>----[CONNECT ����]-------
    // S��----[����]-[��ʱ��]-------------------------------------------------------
    // [�龰1-2]
    // C��----<NOTIFY><NOCOUPLING>----[CONNECT ����]---<NOTIFY ����>--------
    // S��----[����]-[��ʱ��]-------------------------------------------------------
    // [�龰1-3]
    // C��----[CONNECT ����]------------------------------------------------
    // S��------------------------------------------------------------------

    IOStatus := InterlockedAnd64(IOContext.FIOStatus, PROXY_IO_STATUS_DEL_CONNECT);
    if not IOContext.HasNotify(IOStatus) then begin // [�龰1-1][�龰1-3]
      if not IOContext.HasCoupling(IOStatus) then begin // [�龰1-1]
        Result := False;
        IOContext.DecouplingWithCorr(False);
        // dxm 2018.12.01
        // ��ΪC�˲ųɹ��������ӣ�û�к��������κβ������ʿ�ֱ�ӹر��׽���Ȼ��黹
        IOContext.HardCloseSocket();
        EnqueueFreeContext(IOContext);
      end
      else begin // [�龰1-3]
        // ����
      end;
    end
    else begin // [�龰1-2]
      Result := False;
    end;
  end
  else begin
    // [�龰2] CONNECTʧ��
    // [�龰2-1]
    // C��----<NOTIFY><NOCOUPLING>----<NOTIFY ����>----[CONNECT ����]----[����]---
    // S��----[����]--------------------------------------------------------------
    // [�龰2-2]
    // C��----<NOTIFY><NOCOUPLING>----[CONNECT ����]---<NOTIFY ����>-----[����]---
    // S��----[����]-[��ʱ��]-------------------------------------------------------------
    // [�龰2-3]
    // C��----[CONNECT ����]-----[����]-[��ʱ��]------------------------------------------
    // S��------------------------<NOTIFY>------------------------------------------------

    IOStatus := InterlockedAnd64(IOContext.FIOStatus, PROXY_IO_STATUS_DEL_CONNECT_ADD_ERROR);
    if not IOContext.HasNotify(IOStatus) then begin // [�龰2-1][�龰2-3]
      IOContext.DecouplingWithCorr(IOContext.HasCoupling(IOStatus));
      if IOContext.HasCoupling(IOStatus) then begin // [�龰2-3]
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
      else begin // [�龰2-1]
        EnqueueFreeContext(IOContext);
      end;
    end
    else begin //[�龰2-2]
      // ��֪ͨIO�����̸߳���黹����
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
    raise Exception.Create('��������ʧ��.');
  //Ͷ��Ԥ����
  iRet := PostMultiAccept(FSocket, FMaxPreAcceptCount);
  if iRet = 0 then begin
    raise Exception.Create('Ͷ��Ԥ����ʧ��');
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
