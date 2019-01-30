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
    FMaxPreIOContextCount: Integer;    // �ͻ��˿�ʼ����ǰ׼�����Ѱ󶨡�δ���ӵ��׽�����
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

  if Status and $80000040 = $00000040 then begin // [��������]
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
      if FRecvBytes < FHeadSize then begin // �״ζ�(�������)Protocol Head
        Tea := RecvProtocol();
      end
      else begin  // ��ʱӦ�ò�Э��ͷ����
        FStatus := FStatus or $00000004; // Э��ͷ������
        ParseProtocol(); // ����Э��ͷ [������ܲ���������$8000,0000����]
        Cigarette := FStatus;

        if FStatus and $80000000 = $00000000 then begin // Э������ɹ�
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
      if FBodyInFile then // ���յ���Bufferд����ʱ�ļ�
        WriteBodyToFile(); // [������ܲ���������$8000,0000����]
      Cigarette := FStatus;

      if FStatus and $80000000 = $00000000 then begin
        if FRecvBytes < FHeadSize + FHead^.Length then begin // ��������Body
          Tea := RecvBuffer();
        end
        else begin
          FStatus := FStatus or $00000008;

          ParseAndProcessBody(); // [������ܲ����Ƕ���������$8000,0000����]
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
              // ��ʼ����BodyEx
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
      if FBodyExInFile then // д��BodyExFile
        WriteBodyExToFile(); // [������ܲ����Ƕ���������$8000,0000����]
      Cigarette := FStatus;

      if FStatus and $80000000 = $00000000 then begin
        if FRecvBytes < FHeadSize + FHead^.Length + FHead^.LengthEx then begin // ��������BodyEx
          Tea := RecvBuffer();
        end
        else begin
          FStatus := FStatus or $00000010;
          ParseAndProcessBodyEx(); // [������ܲ����Ƕ���������$8000,0000����]
          Cigarette := FStatus;

          // dxm 2018.11.13
          // 1.�Կͻ�����˵�����ˣ��յ��˷���˷��͵�ȫ����Ӧ
          // 2.��Ȼ�յ��˷���˵�ȫ����Ӧ��Ҳ֤���ͻ��˵�����ȫ���������
          // ��ˣ�����ҪͶ�����Źر��ص�IO��

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
  FMaxPreIOContextCount := MAX_PRE_IOCONTEXT_COUNT; // Ĭ�����Ԥ������
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
    // ����������״̬�д���$8000,0000ʱǿ�ƹر��׽��ֶ���
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
    // �ͻ���ͨ���ú����������Ӳ�׼���˵�һ������͵�����
    // ���Ǵ�ʱ���ܷ��ͣ�ֻ�����ݴ棬��Ϊ���ӻ�û����
    // �����ݴ�ͷ��Ͷ���ʱ����ģ��������ȵ���ȷ�س�ʼ�����Ʊ�����
    // ��������к�����������Ļ������ͺ���SendBuffer�����ᴥ��
    IOContext.FSendBusy := IOContext.FSendBusy + FHeadSize + Length;

    IOBuffer := DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := IOContext;

    // dxm 2018.11.13
    // ��ConnectEx�ص�IO֪ͨ����ʱ��
    // 1. WSAECONNREFUSED 10061 ͨ���ǶԶ˷�����δ����             [֪ͨʱ][����ʱ][����][������]
    // 2. WSAENETUNREACH  10051 ���粻�ɴͨ����·���޷�֪̽Զ�� [֪ͨʱ][����ʱ][����][������]
    // 3. WSAETIMEDOUT    10060 ���ӳ�ʱ                           [֪ͨʱ][------][����][������]

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
    raise Exception.Create('ҵ��������δע��,����ǰ����� RegisterIOContextClass');
  // ��������ʼ���ڴ��
  FBufferPool := TBufferPool.Create();
  FBufferPool.Initialize(1000 * 64, 100 * 64, FBufferSize);
  // ��������ʼ��IOBuffer��
  FIOBuffers := TFlexibleQueue<PTCPIOBuffer>.Create(64);
  FIOBuffers.OnItemNotify := DoIOBufferNotify;
  // ��������ʼ��IOContext��
  FFreeContexts := TFlexibleQueue<TTCPIOContext>.Create(64);
  FFreeContexts.OnItemNotify := DoIOContextNotify;
  // ׼���׽���������
  iRet := PrepareMultiIOContext(FIOContextClass, FMaxPreIOContextCount);
  if iRet = 0 then
    raise Exception.Create('׼���׽���������ʧ��');
end;

procedure TTCPClient.Stop;
begin
  inherited;

end;

end.

