{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10.15
 * @Brief:
 *}

unit org.tcpip.tcp.server;

interface

uses
  Winapi.Windows,
  Winapi.Winsock2,
  System.SysUtils,
  AnsiStrings,
//  System.JSON,
  System.Classes,
  System.Math,
  org.algorithms,
  org.algorithms.queue,
  org.utilities,
  org.utilities.buffer,
  org.tcpip,
  org.tcpip.tcp;

type
  TTCPServerClientSocket = class(TTCPIOContext)
  protected
    procedure DoConnected; override;
    procedure TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD); override;
  public
    constructor Create(AOwner: TTCPIOManager); override;
    destructor Destroy; override;
  end;

  TTCPServer = class(TTCPIOManager)
  private
    FIOContextClass: TTCPIOContextClass;
    FFreeContexts: TFlexibleQueue<TTCPIOContext>;
    procedure SetMaxPreAcceptCount(const Value: Integer);
  protected
    FMaxPreAcceptCount: Integer;     // 最大预连接数
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass); override;
    function DequeueFreeContext(IOType: DWORD): TTCPIOContext; override;
    procedure EnqueueFreeContext(AContext: TTCPIOContext); override;
    procedure Start; override;
    procedure Stop; override;
    property MaxPreAcceptCount: Integer read FMaxPreAcceptCount write SetMaxPreAcceptCount;
  end;

implementation

{ TTCPServerClientSocket }

constructor TTCPServerClientSocket.Create(AOwner: TTCPIOManager);
begin
  Inherited;
  FStatus := $00000000;
end;

destructor TTCPServerClientSocket.Destroy;
begin
  inherited;
end;

procedure TTCPServerClientSocket.DoConnected;
var
  Status: DWORD;
  IOStatus: Int64;
//{$IfDef DEBUG}
//  Msg: string;
//{$Endif}
begin
  if Assigned(FOwner.OnConnected) then
    FOwner.OnConnected(nil, Self);

  Status := FStatus;
  IOStatus := FIOStatus;

//{$IfDef DEBUG}
//  Msg := Format('[%d][%d]<%s.DoConnected>[INIT][FIOStatus] FIOStatus=%x',
//    [ FSocket,
//      GetCurrentThreadId(),
//      ClassName,
//      IOStatus]);
//  FOwner.WriteLog(llDebug, Msg);
//{$Endif}

  // dxm 2018.12.18
  // 防止只连接而不发数据
  InterlockedIncrement(FRefCount);
  FOwner.TimeWheel.StartTimer(Self, MAX_FIRSTDATA_TIME * 1000, FOwner.DoWaitFirstData);

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

procedure TTCPServerClientSocket.TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD);
var
  More: Boolean;
begin
  More := True;
  while (not HasErrorOrReadIO(Tea)) and (FStatus and $80000000 = $00000000) and More do begin
    if FStatus and $8000007F = $00000003 then begin //1000,...,0111,1111;
      if FRecvBytes < FHeadSize then begin // 首次读(或继续读)Protocol Head
        Tea := RecvProtocol();
      end
      else begin  // 此时应用层协议头读完
        FStatus := FStatus or $00000004; // 协议头接收完  0000,...,0100
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
    else if FStatus and $8000007F = $00000007 then begin //1000,...,0111,1111;
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
                Tea := RecvDisconnect();
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
    else if (FStatus and $8000007F = $0000000F) and (FHead^.LengthEx > 0) then begin //1000,...,0111,1111;
      if FBodyExInFile then // 写入BodyExFile
        WriteBodyExToFile(); // [这里可能产生非独立独立的$8000,0000错误]

      Cigarette := FStatus;

      // dxm 2018.11.16
      // 通知客户端BodyEx接收进度
      if (FStatus and $80000000 = $00000000) and (FHead^.Options and IO_OPTION_NOTIFY_BODYEX_PROGRESS = IO_OPTION_NOTIFY_BODYEX_PROGRESS) then begin
        NotifyBodyExProgress();
        Cigarette := FStatus;
      end;

      if FStatus and $80000000 = $00000000 then begin
        if FRecvBytes < FHeadSize + FHead^.Length + FHead^.LengthEx then begin // 继续接收BodyEx
          Tea := RecvBuffer();
        end
        else begin
          FStatus := FStatus or $00000010;

          ParseAndProcessBodyEx(); // [这里可能产生非独立独立的$8000,0000错误]
          Cigarette := FStatus;

          if FStatus and $80000000 = $00000000 then begin

            if FHead^.Options and IO_OPTION_ONCEMORE = $00000000 then begin
              Tea := RecvDisconnect();
            end
            else begin
              FRecvBytes := FRecvBytes - FHeadSize - FHead^.Length - FHead^.LengthEx;
              FStatus := FStatus and $E0000003; // 1110,0000,...,0000,0011
            end;
          end;
        end;
      end;
    end
    else if ((FStatus and $8000007F = $0000003F) and (FHead^.LengthEx > 0)) or
            ( FStatus and $8000007F = $0000002F) then begin //1000,...,0111,1111;
       Tea := SendDisconnect();
    end
    else if ((FStatus and $8000007F = $0000007F) and (FHead^.LengthEx > 0)) or
            ( FStatus and $8000007F = $0000006F) then begin //1000,...,0111,1111;
      // 正常情况下，上下文对应的连接的生命周期在此结束
      Cigarette := FStatus;
      More := False; // [dxm 2018.11.9 no more? maybe!]
    end
    else begin
      // nothing or unkown error
    end;
  end;
end;

{ TTCPServer }

constructor TTCPServer.Create;
begin
  inherited;
  FMaxPreAcceptCount := MAX_PRE_ACCEPT_COUNT; // 默认最大预连接数
end;

function TTCPServer.DequeueFreeContext(IOType: DWORD): TTCPIOContext;
begin
  Result := FFreeContexts.Dequeue();
  if Result = nil then begin
    Result := FIOContextClass.Create(Self);
//    Result.FSocket := INVALID_SOCKET;
  end;
end;

destructor TTCPServer.Destroy;
begin
  FFreeContexts.Free();
  inherited;
end;

procedure TTCPServer.EnqueueFreeContext(AContext: TTCPIOContext);
var
  IOContext: TTCPServerClientSocket;
begin
  inherited;
  IOContext := AContext as TTCPServerClientSocket;
    // 仅当上下文状态中存在$8000,0000时强制关闭套接字对象
  if IOContext.FStatus and $C0000000 = $80000000 then begin
    if IOContext.FSocket <> INVALID_SOCKET then begin
      IOContext.HardCloseSocket();
    end;
  end;

  IOContext.FStatus := IOContext.FStatus and $20000000;
  FFreeContexts.Enqueue(AContext);
end;

procedure TTCPServer.RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass);
begin
  FIOContextClass := AClass;
end;

procedure TTCPServer.SetMaxPreAcceptCount(const Value: Integer);
begin
  if FMaxPreAcceptCount <> Value then
    FMaxPreAcceptCount := Value;
end;

procedure TTCPServer.Start;
begin
  inherited;
  // 初始化指定数量的通信实例
  if FIOContextClass = nil then
    raise Exception.Create('业务处理类尚未注册,启动前请调用 RegisterIOContextClass');
  // 初始化内存池
  FBufferPool := TBufferPool.Create();
  FBufferPool.Initialize(1000 * 10 * FMaxPreAcceptCount, 10 * FMaxPreAcceptCount, FBufferSize);
  // 创建并初始化IOBuffer池
  FIOBuffers := TFlexibleQueue<PTCPIOBuffer>.Create(FMaxPreAcceptCount * 100);
  FIOBuffers.OnItemNotify := DoIOBufferNotify;
  // 创建并初始化IOContext池
  FFreeContexts := TFlexibleQueue<TTCPIOContext>.Create(FMaxPreAcceptCount);
  FFreeContexts.OnItemNotify := DoIOContextNotify;
end;

procedure TTCPServer.Stop;
begin
  inherited;
  // 取消所有已投递但未出队的重叠操作 CancelIoEx
  // 等待
  // 释放FContextList及对应通信套接字
  // FIOHandle.Stop() -[TTCPServerSocket]-> 关闭监听套接字 -[TIOCP]-> 投递退出封包 -[TThreadPool]-> 等待线程退出
  // FIOHandle.Free() -[TTCPServerSocket]->  -[TIOCP]->  -[TThreadPool]->
  // FContextList.Free();
end;

end.

