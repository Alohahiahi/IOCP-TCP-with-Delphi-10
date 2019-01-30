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
    FPreAcceptCount: Integer;       // ��ǰԤ������
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
  // 1. �ж�IO�Ƿ����
  // 2. ��ʼ���׽���������
  // 3. ����ͨ���׽�����IO��ɶ˿�
  // 4. ����Ԥ����

  // dxm 2018.11.2
  // ��AcceptEx�ص�IO֪ͨ����ʱ��
  // 1. ERROR_IO_PENDING �ص�IO��ʼ���ɹ����Ժ�֪ͨ���          [------][����ʱ][����]
  // 2. WSAECONNRESET    �Զ��ύ����������漴����ֹ�˸�����  [֪ͨʱ][------][����][������][˵��һ���յ��������󣬺����Զ˼�ʹȡ��������Ҳֻ�Ǳ�Ƕ���]

  Result := False;
  IOContext := IOBuffer^.Context as TDMTCPServerClientSocket;

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
        // dxm 2018.12.10
        InterlockedIncrement(FOnlineCount);
        IOContext.FStatus := IOContext.FStatus or $00000002; // [������][������]
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
    // ���о�ֱ�ӽ�IOBuffer��Context�������ˣ���������Ҫ����Ԥ��������TTCPServerҪ�����Դ

    ErrDesc := Format('[%d][%d]<%s.DoAcceptEx> IO�ڲ�����: LastErrorCode=%d, Status=%s',
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
    raise Exception.Create('��������ʧ��.');
  // Ͷ��Ԥ����
  iRet := PostMultiAccept(FSocket, FMaxPreAcceptCount);
  if iRet = 0 then begin
    raise Exception.Create('Ͷ��Ԥ����ʧ��');
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
