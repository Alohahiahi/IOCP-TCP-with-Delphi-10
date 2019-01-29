{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.11.15
 * @Brief:
 *}

unit org.tcpip.tcp.proxy;

interface

uses
  WinApi.Windows,
  Winapi.Winsock2,
  System.Classes,
  System.SysUtils,
  System.Math,
  AnsiStrings,
  org.utilities,
  org.utilities.buffer,
  org.algorithms.queue,
  org.tcpip,
  org.tcpip.tcp;

type
  TTCPProxyIOContext = class(TTCPIOContext)
  protected
    FCorrIOContext: TTCPProxyIOContext;
    function HasError(IOStatus: Int64): Boolean; override;
    function HasReadIO(IOStatus: Int64): Boolean; override;
    function HasWriteIO(IOStatus: Int64): Boolean; override;
    function HasErrorOrReadIO(IOStatus: Int64): Boolean; override;
    function HasIO(IOStatus: Int64): Boolean; override;
    function HasRead(IOStatus: Int64): Boolean; override;
    function HasReadOrReadIO(IOStatus: Int64): Boolean; override;
    function HasWrite(IOStatus: Int64): Boolean; override;
    function HasWriteOrWriteIO(IOStatus: Int64): Boolean; override;
    function HasWriteOrIO(IOStatus: Int64): Boolean; override;

    function HasCoupling(IOStatus: Int64): Boolean;
    function HasNotify(IOStatus: Int64): Boolean;
    //\\
    procedure DoRecved(IOBuffer: PTCPIOBuffer); override;
    procedure DoSent(IOBuffer: PTCPIOBuffer); override;
    procedure DoDisconnected(IOBuffer: PTCPIOBuffer); override;
    procedure DoNotify(IOBuffer: PTCPIOBuffer); override;
    //\\
    function SendBuffer: Integer; override;
    function SendBufferEx: Boolean; virtual;
    function RecvBuffer: Int64; override;
    function SendDisconnect: Int64; override;
    procedure DecouplingWithCorr(WithNotify: Boolean);
  public
    constructor Create(AOwner: TTCPIOManager); override;
  end;

  TTCPProxyClientSocket = class(TTCPProxyIOContext)
  protected
    procedure DoConnected; override;
    procedure DoNotify(IOBuffer: PTCPIOBuffer); override;
    procedure ParseAndProcessBody; override;
    procedure TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD); override;
  public
    constructor Create(AOwner: TTCPIOManager); override;
  end;

  TTCPProxyServerClientSocket = class(TTCPProxyIOContext)
  protected
    procedure DoConnected; override;
    procedure DoNotify(IOBuffer: PTCPIOBuffer); override;
    procedure ParseAndProcessBody; override;
    procedure TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD); override;
    function PrepareCorrIOContext(RemoteIP: string; RemotePort: Word): Boolean;
  public
    constructor Create(AOwner: TTCPIOManager); override;
  end;

  TTCPProxy = class(TTCPIOManager)
  private
    FIOContextClientClass: TTCPIOContextClass;
    FIOContextServerClass: TTCPIOContextClass;
    FFreeClientContexts: TFlexibleQueue<TTCPIOContext>;
    FFreeServerContexts: TFlexibleQueue<TTCPIOContext>;
    procedure SetMaxPreAcceptCount(const Value: Integer);
  protected
    FMaxPreAcceptCount: Integer;    // 最大预连接数
    procedure SetMultiIOBufferCount(const Value: Integer); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass); override;
    function DequeueFreeContext(IOType: DWORD): TTCPIOContext; override;
    procedure EnqueueFreeContext(AContext: TTCPIOContext); override;
    //\\
    procedure DoWaitTIMEWAIT(IOContext: TTCPIOContext); override;
    procedure DoWaitNotify(IOContext: TTCPIOContext); override;
    procedure Start; override;
    procedure Stop; override;
    property MaxPreAcceptCount: Integer read FMaxPreAcceptCount write SetMaxPreAcceptCount;
  end;

{=====================================================================================
 PROXY_IOSTATUS:
 常规情况: 1表示[有][是]，0表示[无][否]
 [x000,0000,0000,...,0000] [保留, 默认为1]
 [0x00,0000,0000,...,0000] [READ]
 [00x0,0000,0000,...,0000] [WRITE]
 [000x,0000,0000,...,0000] [ERROR, 0表示有错误, 1表示无错误, 与常规相反]

 [0000,x000,0000,...,0000] [WRITEIO]
 [0000,0x00,0000,...,0000] [COUPLING, 用于协调C端和S端, 0表示耦合, 1表示解耦, 与常规相反]
 [0000,00x0,0000,...,0000] [NOTIFY]
 [0000,000x,0000,...,0000] [CONNECT, 用于标识客户端投递的连接IO]

 [0000,0000,x000,...,0000] [READIO55]
 [....,....,...,....,....]
 [0000,0000,0000,...,000x] [READIO0]
=======================================================================================}

const
  PROXY_IO_STATUS_EMPTY: Int64                         = -$8000000000000000; //     1000,0000,...,0000;
  PROXY_IO_STATUS_FULL: Int64                          = -$0000000000000001; //     1111,1111,...,1111;
  //[NOERROR][COUPLING][NONOTIFY]
  PROXY_IO_STATUS_INIT: Int64                          = -$7000000000000000; //[   ]1001,0000,...,0000;$9000000000000000
  PROXY_IO_STATUS_NOERROR: Int64                       = -$7000000000000000; //[and]1001,0000,...,0000;$9000000000000000
  PROXY_IO_STATUS_NOCOUPLING: Int64                    = -$7C00000000000000; //[and]1000,0100,...,0000;$8400000000000000
  PROXY_IO_STATUS_ENCOUPLING: Int64                    = -$0400000000000001; //[and]1111,1011,...,1111;$FBFFFFFFFFFFFFFF
  PROXY_IO_STATUS_ADD_ERROR: Int64                     = -$1000000000000001; //[and]1110,1111,...,1111;$EFFFFFFFFFFFFFFF
  PROXY_IO_STATUS_DECOUPLING: Int64                    = -$7C00000000000000; //[ or]1000,0100,...,0000;$8400000000000000
  PROXY_IO_STATUS_ADD_NOTIFY: Int64                    = -$7E00000000000000; //[ or]1000,0010,...,0000;$8200000000000000
  PROXY_IO_STATUS_ADD_NOTIFY_DECOUPLING: Int64         = -$7A00000000000000; //[ or]1000,0110,...,0000;$8600000000000000
  PROXY_IO_STATUS_DEL_NOTIFY: Int64                    = -$0200000000000001; //[and]1111,1101,...,1111;$FDFFFFFFFFFFFFFF
  PROXY_IO_STATUS_DEL_NOTIFY_ADD_ERROR: Int64          = -$1200000000000001; //[and]1110,1101,...,1111;$EDFFFFFFFFFFFFFF
  PROXY_IO_STATUS_ADD_CONNECT: Int64                   = -$7F00000000000000; //[ or]1000,0001,...,0000;$8100000000000000
  PROXY_IO_STATUS_DEL_CONNECT: Int64                   = -$0100000000000001; //[and]1111,1110,...,1111;$FEFFFFFFFFFFFFFF
  PROXY_IO_STATUS_DEL_CONNECT_ADD_ERROR: Int64         = -$1100000000000001; //[and]1110,1110,...,1111;$EEFFFFFFFFFFFFFF

  PROXY_IO_STATUS_HAS_READ: Int64                      = -$4000000000000000; //[and]1100,0000,...,0000;$C000000000000000
  PROXY_IO_STATUS_HAS_READ_IO: Int64                   = -$7F00000000000001; //[and]1000,0000,...,1111;$80FFFFFFFFFFFFFF
  PROXY_IO_STATUS_HAS_READ_OR_READ_IO: Int64           = -$3F00000000000001; //[and]1100,0000,...,1111;$C0FFFFFFFFFFFFFF
  PROXY_IO_STATUS_HAS_WRITE: Int64                     = -$6000000000000000; //[and]1010,0000,...,0000;$A000000000000000
  PROXY_IO_STATUS_HAS_WRITE_IO: Int64                  = -$7800000000000000; //[and]1000,1000,...,0000;$8800000000000000
  PROXY_IO_STATUS_HAS_WRITE_OR_WRITE_IO: Int64         = -$5800000000000000; //[and]1010,1000,...,0000;$A800000000000000
  PROXY_IO_STATUS_HAS_IO: Int64                        = -$7700000000000001; //[and]1000,1000,...,1111;$88FFFFFFFFFFFFFF
  PROXY_IO_STATUS_HAS_WRITE_OR_IO: Int64               = -$5700000000000001; //[and]1010,1000,...,1111;$A8FFFFFFFFFFFFFF
  PROXY_IO_STATUS_HAS_NOTIFY: Int64                    = -$7E00000000000000; //[and]1000,0010,...,0000;$8200000000000000

  PROXY_IO_STATUS_ADD_WRITE_WRITE_IO: Int64            = -$5800000000000000; //[ or]1010,1000,...,0000;$A800000000000000
  PROXY_IO_STATUS_DEL_WRITE: Int64                     = -$2000000000000001; //[and]1101,1111,...,1111;$DFFFFFFFFFFFFFFF
  PROXY_IO_STATUS_DEL_WRITE_WRITE_IO: Int64            = -$2800000000000001; //[and]1101,0111,...,1111;$D7FFFFFFFFFFFFFF
  PROXY_IO_STATUS_DEL_WRITE_WRITE_IO_ADD_ERROR: Int64  = -$3800000000000001; //[and]1100,0111,...,1111;$C7FFFFFFFFFFFFFF

  PROXY_IO_STATUS_DEL_WRITE_IO: Int64                  = -$0800000000000001; //[and]1111,0111,...,1111;$F7FFFFFFFFFFFFFF
  PROXY_IO_STATUS_DEL_WRITE_IO_ADD_ERROR: Int64        = -$1800000000000001; //[and]1110,0111,...,1111;$E7FFFFFFFFFFFFFF

  PROXY_IO_STATUS_ADD_READ: Int64                      = -$4000000000000000; //[ or]1100,0000,...,0000;$C000000000000000
  PROXY_IO_STATUS_DEL_READ: Int64                      = -$4000000000000001; //[and]1011,1111,...,1111;$BFFFFFFFFFFFFFFF
  PROXY_IO_STATUS_READ_CAPACITY                        = 56;
  // 增加IO位 [or]
  PROXY_IO_STATUS_ADD_READ_IO: array [0..PROXY_IO_STATUS_READ_CAPACITY-1] of Int64 = (
    //1000,0000,...,0001;$8000000000000001
    -$7FFFFFFFFFFFFFFF, -$7FFFFFFFFFFFFFFE, -$7FFFFFFFFFFFFFFC, -$7FFFFFFFFFFFFFF8,
    -$7FFFFFFFFFFFFFF0, -$7FFFFFFFFFFFFFE0, -$7FFFFFFFFFFFFFC0, -$7FFFFFFFFFFFFF80,
    -$7FFFFFFFFFFFFF00, -$7FFFFFFFFFFFFE00, -$7FFFFFFFFFFFFC00, -$7FFFFFFFFFFFF800,
    -$7FFFFFFFFFFFF000, -$7FFFFFFFFFFFE000, -$7FFFFFFFFFFFC000, -$7FFFFFFFFFFF8000,
    -$7FFFFFFFFFFF0000, -$7FFFFFFFFFFE0000, -$7FFFFFFFFFFC0000, -$7FFFFFFFFFF80000,
    -$7FFFFFFFFFF00000, -$7FFFFFFFFFE00000, -$7FFFFFFFFFC00000, -$7FFFFFFFFF800000,
    -$7FFFFFFFFF000000, -$7FFFFFFFFE000000, -$7FFFFFFFFC000000, -$7FFFFFFFF8000000,
    -$7FFFFFFFF0000000, -$7FFFFFFFE0000000, -$7FFFFFFFC0000000, -$7FFFFFFF80000000,
    -$7FFFFFFF00000000, -$7FFFFFFE00000000, -$7FFFFFFC00000000, -$7FFFFFF800000000,
    -$7FFFFFF000000000, -$7FFFFFE000000000, -$7FFFFFC000000000, -$7FFFFF8000000000,
    -$7FFFFF0000000000, -$7FFFFE0000000000, -$7FFFFC0000000000, -$7FFFF80000000000,
    -$7FFFF00000000000, -$7FFFE00000000000, -$7FFFC00000000000, -$7FFF800000000000,
    -$7FFF000000000000, -$7FFE000000000000, -$7FFC000000000000, -$7FF8000000000000,
    -$7FF0000000000000, -$7FE0000000000000, -$7FC0000000000000, -$7F80000000000000
  );

  // 去除IO位 [and]
  PROXY_IO_STATUS_DEL_READ_IO: array [0..PROXY_IO_STATUS_READ_CAPACITY-1] of Int64 = (
    //1111,1111,...,1110;$FFFFFFFFFFFFFFFE
    -$0000000000000002, -$0000000000000003, -$0000000000000005, -$0000000000000009,
    -$0000000000000011, -$0000000000000021, -$0000000000000041, -$0000000000000081,
    -$0000000000000101, -$0000000000000201, -$0000000000000401, -$0000000000000801,
    -$0000000000001001, -$0000000000002001, -$0000000000004001, -$0000000000008001,
    -$0000000000010001, -$0000000000020001, -$0000000000040001, -$0000000000080001,
    -$0000000000100001, -$0000000000200001, -$0000000000400001, -$0000000000800001,
    -$0000000001000001, -$0000000002000001, -$0000000004000001, -$0000000008000001,
    -$0000000010000001, -$0000000020000001, -$0000000040000001, -$0000000080000001,
    -$0000000100000001, -$0000000200000001, -$0000000400000001, -$0000000800000001,
    -$0000001000000001, -$0000002000000001, -$0000004000000001, -$0000008000000001,
    -$0000010000000001, -$0000020000000001, -$0000040000000001, -$0000080000000001,
    -$0000100000000001, -$0000200000000001, -$0000400000000001, -$0000800000000001,
    -$0001000000000001, -$0002000000000001, -$0004000000000001, -$0008000000000001,
    -$0010000000000001, -$0020000000000001, -$0040000000000001, -$0080000000000001
  );

  // 去除IO位并增加错误位 [and]
  PROXY_IO_STATUS_DEL_READ_IO_ADD_ERROR: array [0..PROXY_IO_STATUS_READ_CAPACITY-1] of Int64 = (
    //1110,1111,...,1110;$EFFFFFFFFFFFFFFE
    -$1000000000000002, -$1000000000000003, -$1000000000000005, -$1000000000000009,
    -$1000000000000011, -$1000000000000021, -$1000000000000041, -$1000000000000081,
    -$1000000000000101, -$1000000000000201, -$1000000000000401, -$1000000000000801,
    -$1000000000001001, -$1000000000002001, -$1000000000004001, -$1000000000008001,
    -$1000000000010001, -$1000000000020001, -$1000000000040001, -$1000000000080001,
    -$1000000000100001, -$1000000000200001, -$1000000000400001, -$1000000000800001,
    -$1000000001000001, -$1000000002000001, -$1000000004000001, -$1000000008000001,
    -$1000000010000001, -$1000000020000001, -$1000000040000001, -$1000000080000001,
    -$1000000100000001, -$1000000200000001, -$1000000400000001, -$1000000800000001,
    -$1000001000000001, -$1000002000000001, -$1000004000000001, -$1000008000000001,
    -$1000010000000001, -$1000020000000001, -$1000040000000001, -$1000080000000001,
    -$1000100000000001, -$1000200000000001, -$1000400000000001, -$1000800000000001,
    -$1001000000000001, -$1002000000000001, -$1004000000000001, -$1008000000000001,
    -$1010000000000001, -$1020000000000001, -$1040000000000001, -$1080000000000001
  );

//  NOTIFY_FLAG_DISCONNECT: DWORD = $00000001;
//  NOTIFY_FLAG_SWITCH: DWORD     = $00000002;
//  NOTIFY_FLAG_ABANDON: DWORD    = $00000004;

implementation

{ TTCPProxy }

constructor TTCPProxy.Create;
begin
  inherited;
  FMaxPreAcceptCount := MAX_PRE_ACCEPT_COUNT; // 默认最大预连接数
end;

function TTCPProxy.DequeueFreeContext(IOType: DWORD): TTCPIOContext;
begin
  if IOType = $00000000 then begin
    Result := FFreeServerContexts.Dequeue();
    if Result = nil then begin
      Result := FIOContextServerClass.Create(Self);
    end;
  end
  else begin
    Result := FFreeClientContexts.Dequeue();
    if Result = nil then begin
      Result := FIOContextClientClass.Create(Self);
    end;
  end;
end;

destructor TTCPProxy.Destroy;
begin
  inherited;
end;

procedure TTCPProxy.DoWaitNotify(IOContext: TTCPIOContext);
var
  IOStatus: Int64;
  ProxyIOContext: TTCPProxyIOContext;
{$IfDef DEBUG}
  Msg: string;
{$Endif}
begin
  inherited;
  ProxyIOContext := IOContext as TTCPProxyIOContext;
  IOStatus := InterlockedAdd64(ProxyIOContext.FIOStatus, 0);
  if ProxyIOContext.HasCoupling(IOStatus) then begin
    FTimeWheel.StartTimer(IOContext, 30 * 1000, DoWaitNotify);
  end
  else begin
{$IfDef DEBUG}
    Msg := Format('[%d][%d]<%s.DoWaitNotify> enqueue IOContext into FreeIOConetxt queue!',
      [ ProxyIOContext.FSocket,
        GetCurrentThreadId(),
        ClassName]);
    WriteLog(llDebug, Msg);
{$Endif}
    EnqueueFreeContext(IOContext);
  end;
end;

procedure TTCPProxy.DoWaitTIMEWAIT(IOContext: TTCPIOContext);
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
  FFreeClientContexts.Enqueue(IOContext);
end;

procedure TTCPProxy.EnqueueFreeContext(AContext: TTCPIOContext);
var
  IOContext: TTCPProxyIOContext;
//{$IfDef DEBUG}
//  Msg: string;
//{$Endif}
begin
  inherited;

  IOContext := AContext as TTCPProxyIOContext;
  IOContext.FCorrIOContext := nil;
  if IOContext.IsServerIOContext then begin
      // 仅当上下文状态中存在$8000,0000时强制关闭套接字对象
    if IOContext.FStatus and $C0000000 = $80000000 then begin
      if IOContext.FSocket <> INVALID_SOCKET then begin
        IOContext.HardCloseSocket();
      end;
    end;

    IOContext.FIOStatus := PROXY_IO_STATUS_INIT or PROXY_IO_STATUS_DECOUPLING;
    IOContext.FSendIOStatus := PROXY_IO_STATUS_INIT or PROXY_IO_STATUS_DECOUPLING;
    IOContext.FStatus := IOContext.FStatus and $20000000;

    FFreeServerContexts.Enqueue(IOContext);
  end
  else begin
    // 仅当上下文状态中存在$8000,0000时强制关闭套接字对象
    if IOContext.FStatus and $C0000000 = $80000000 then begin
      if IOContext.FSocket <> INVALID_SOCKET then begin
        IOContext.HardCloseSocket();
      end;
      IOContext.FIOStatus := PROXY_IO_STATUS_INIT;
      IOContext.FSendIOStatus := PROXY_IO_STATUS_INIT;
      IOContext.FStatus := IOContext.FStatus and $20000000;
      FFreeClientContexts.Enqueue(IOContext);
    end
    else begin
//{$IfDef DEBUG}
//      Msg := Format('[%d][%d]<%s.EnqueueFreeContext> be to enqueue TimeWheel for <TIMEWAITExpired>  ExpireTime=%ds, Status=%s',
//        [ IOContext.FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          4 * 60,
//          IOContext.StatusString()]);
//      WriteLog(llDebug, Msg);
//{$Endif}
      IOContext.FStatus := IOContext.FStatus and $20000000;
      FTimeWheel.StartTimer(IOContext, 4 * 60 * 1000, DoWaitTIMEWAIT);
    end;
  end;
end;

procedure TTCPProxy.RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass);
begin
  if IOType = $20000000 then
    FIOContextClientClass := AClass
  else
    FIOContextServerClass := AClass;
end;

procedure TTCPProxy.SetMaxPreAcceptCount(const Value: Integer);
begin
  if FMaxPreAcceptCount <> Value then
    FMaxPreAcceptCount := Value;
end;

procedure TTCPProxy.SetMultiIOBufferCount(const Value: Integer);
var
  AValue: Integer;
begin
  AValue := Value;
  if Value > PROXY_IO_STATUS_READ_CAPACITY then
    AValue := PROXY_IO_STATUS_READ_CAPACITY;
  if Value = 0 then
    AValue := MULTI_IO_BUFFER_COUNT;
  FMultiIOBufferCount := AValue;
end;

procedure TTCPProxy.Start;
begin
  inherited;
  //初始化指定数量的通信实例
  if FIOContextServerClass = nil then
    raise Exception.Create('业务处理类尚未注册,启动前请调用 RegisterIOContextClass');
  if FIOContextClientClass = nil then
    raise Exception.Create('业务处理类尚未注册,启动前请调用 RegisterIOContextClass');
  // 创建并初始化内存池
  FBufferPool := TBufferPool.Create();
  FBufferPool.Initialize(1000 * 100 * FMaxPreAcceptCount, 10 * FMaxPreAcceptCount, FBufferSize);
  // 创建并初始化IOBuffer池
  FIOBuffers := TFlexibleQueue<PTCPIOBuffer>.Create(FMaxPreAcceptCount * 100);
  FIOBuffers.OnItemNotify := DoIOBufferNotify;
  // 创建初始化Server IOContext池
  FFreeServerContexts := TFlexibleQueue<TTCPIOContext>.Create(FMaxPreAcceptCount);
  FFreeServerContexts.OnItemNotify := DoIOContextNotify;
  // 创建初始化Client IOContext池
  FFreeClientContexts := TFlexibleQueue<TTCPIOContext>.Create(FMaxPreAcceptCount);
  FFreeClientContexts.OnItemNotify := DoIOContextNotify;
end;

procedure TTCPProxy.Stop;
begin
  inherited;

end;

{ TTCPProxyClientSocket }

constructor TTCPProxyClientSocket.Create(AOwner: TTCPIOManager);
begin
  inherited;
  FStatus := $20000000;
  FHead^.Length := 0;
  FHead^.LengthEx := 0;
  FIOStatus := PROXY_IO_STATUS_INIT;
  FSendIOStatus := PROXY_IO_STATUS_INIT;
end;

procedure TTCPProxyClientSocket.DoConnected;
var
  Status: DWORD;
  IOStatus: Int64;
{$IfDef DEBUG}
  Msg: string;
{$Endif}
begin
  if Assigned(FOwner.OnConnected) then
    FOwner.OnConnected(nil, Self);

{$IfDef DEBUG}
  Msg := Format('[%d][%d][%d]<%s.DoConnected>',
    [ FSocket,
      FCorrIOContext.FSocket,
      GetCurrentThreadId(),
      ClassName]);
  FOwner.WriteLog(llDebug, Msg);
{$Endif}

  SendBuffer();
  Status := FStatus;
  IOStatus := FSendIOStatus;
  TeaAndCigaretteAndMore(IOStatus, Status);

  // dxm 2018.11.27
  // 假设S端始终正常
  // C端只需专注做自己的事情
  // [解耦]
  // 仅当本端内部发生错误，且可以归还上下文时才和关联端解耦
  // 但是，当本端执行完解耦动作后，如果关联端(S端)依然和本端耦合在，本端不能执行上下文回收动作
  // 在本地出错到最终执行解耦期间，关联端(S端)可能多次调用本地的SendBufferEx函数，因此，SendBufferEx函数内部必须先检查
  // 本端是否正常，如果正常才能实际进行发送，否则什么也不做，如此保证S端正常工作

  if Status and $80000040 = $00000040 then begin // [正常结束]
    if not (HasWriteIO(IOStatus) or HasNotify(IOStatus)) then begin
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        Msg := Format('[%d][%d][%d]<%s.DoConnected> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//          [ FSocket,
//            FCorrIOContext.FSocket,
//            GetCurrentThreadId(),
//            ClassName,
//            30,
//            StatusString()]);
//        FOwner.WriteLog(llDebug, Msg);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end
  else if HasError(IOStatus) or (Status and $80000000 = $80000000) then begin
    // dxm 2018.11.28
    // 当本端发生错误时，仅当可以归还本端上下文时和S端解耦
    // 由于连接已成功建立，肯定没有[CONNECT]
    if not (HasWriteOrIO(IOStatus) or HasNotify(IOStatus)) then begin // 没有任何IO操作
      DecouplingWithCorr(HasCoupling(IOStatus));
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        Msg := Format('[%d][%d][%d]<%s.DoConnected> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//        [ FSocket,
//          FCorrIOContext.FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          30,
//          StatusString()]);
//        FOwner.WriteLog(llDebug, Msg);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end
  else begin
    // nothing or unkown error!
  end;
end;

procedure TTCPProxyClientSocket.DoNotify(IOBuffer: PTCPIOBuffer);
begin
  inherited;
end;

procedure TTCPProxyClientSocket.ParseAndProcessBody;
var
  bRet: Boolean;
  ErrDesc: string;
  SendBusy: Int64;
begin
  SendBusy := InterlockedAdd64(FCorrIOContext.FSendBusy, FRecvBytes);
  if SendBusy - FRecvBytes = 0 then begin
    bRet := FCorrIOContext.SendBufferEx();
    if not bRet then begin
     // TODO 只能打印一条消息
      ErrDesc := Format('[%d][%d][%d]<%s.ParseAndProcessBody.SendBufferEx> failed, Status=%s, IOStatus=%x',
        [ FSocket,
          FCorrIOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          StatusString(),
          FIOStatus]);
      FOwner.WriteLog(llNormal, ErrDesc);
    end;
  end;
end;

procedure TTCPProxyClientSocket.TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD);
var
  More: Boolean;
begin
  More := True;
  // dxm 2018.12.18
  // 这里似乎有点问题，可能与有符号64的位操作有关[仅仅是猜测，暂时没有证据][HasErrorOrReadIO(Tea)]
  // 尝试修改: PROXY_IO_STATUS_EMPTY 由$8000000000000000 --> -$8000000000000000
  while (not HasErrorOrReadIO(Tea)) and (FStatus and $80000000 = $00000000) and More do begin
    if FStatus and $8000004B = $00000003 then begin //1000,...,0100,1011
      if FRecvBytes = 0 then begin // 接收Body
        Tea := RecvBuffer();
      end
      else begin
        FStatus := FStatus or $00000008;
        ParseAndProcessBody(); // [这里可能产生非独立独立的$8000,0000错误]
        Cigarette := FStatus;

        if FStatus and $80000000 = $00000000 then begin
          FRecvBytes := 0;
          FStatus := FStatus and $E0000003; // 1110,0000,...,0000,0011
        end;
      end;
    end
    else if FStatus and $8000004B = $00000043 then begin //1000,...,0100,1011
      Cigarette := FStatus;
      More := False; // [dxm 2018.11.9 no more? maybe!]
    end
    else begin
      // nothing or unkown error
    end;
  end;
end;

{ TTCPProxyServerClientSocket }

constructor TTCPProxyServerClientSocket.Create(AOwner: TTCPIOManager);
begin
  inherited;
  FStatus := $00000000;
  FHead^.Length := 0;
  FHead^.LengthEx := 0;
  FIOStatus := PROXY_IO_STATUS_INIT or PROXY_IO_STATUS_DECOUPLING;
  FSendIOStatus := PROXY_IO_STATUS_INIT or PROXY_IO_STATUS_DECOUPLING;
end;

procedure TTCPProxyServerClientSocket.DoConnected;
var
  Status: DWORD;
  IOStatus: Int64;
//{$IfDef DEBUG}
//  ErrDesc: string;
//{$Endif}
begin
  if Assigned(FOwner.OnConnected) then
    FOwner.OnConnected(nil, Self);

  Status := FStatus;
  IOStatus := FIOStatus; // 1001,0100,...,0000 [NOERROR][NOCOUPLING][NONOTIFY][NOCONNECT]

//{$IfDef DEBUG}
//  ErrDesc := Format('[%d][%d]<%s.DoConnected>[INIT][FIOStatus] Status=%s, FIOStatus=%x',
//    [ FSocket,
//      GetCurrentThreadId(),
//      ClassName,
//      StatusString(),
//      IOStatus]);
//  FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}

  InterlockedIncrement(FRefCount);
  FOwner.TimeWheel.StartTimer(Self, MAX_FIRSTDATA_TIME * 1000, FOwner.DoWaitFirstData);

  TeaAndCigaretteAndMore(IOStatus, Status);

  if Status and $80000040 = $00000040 then begin // [正常结束]
    if not (HasWriteIO(IOStatus) or HasNotify(IOStatus)) then begin
      DecouplingWithCorr(HasCoupling(IOStatus));
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d]<%s.DoConnected> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//        [ FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          30,
//          StatusString()]);
//        FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end
  else if HasError(IOStatus) or (Status and $80000000 = $80000000) then begin
    if not (HasWriteOrIO(IOStatus) or HasNotify(IOStatus)) then begin
      DecouplingWithCorr(HasCoupling(IOStatus));
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d]<%s.DoConnected> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//        [ FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          30,
//          StatusString()]);
//        FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end
  else begin
    // nothing or unkown error!
  end;
end;

procedure TTCPProxyServerClientSocket.DoNotify(IOBuffer: PTCPIOBuffer);
begin
  inherited;
end;

procedure TTCPProxyServerClientSocket.ParseAndProcessBody;
var
  bRet: Boolean;
  ErrDesc: string;
  SendBusy: Int64;
begin
  if FCorrIOContext = nil then begin {$region S端的第一个RecvBuffer正常返回}
    // 1. 初始化一个C端并投递连接IO
    // 2. 更新C端的FSendBusy
    // 3. 在C端上投递连接IO
    FCorrIOContext := TTCPProxyIOContext(FOwner.DequeueFreeContext($20000000));
    FCorrIOContext.FCorrIOContext := Self;
    FCorrIOContext.FSendBusy := FCorrIOContext.FSendBusy + FRecvBytes;
    FIOStatus := FIOStatus and PROXY_IO_STATUS_ENCOUPLING;

//    PrepareCorrIOContext('101.37.148.48', 9090);
    PrepareCorrIOContext('127.0.0.1', 9090);
  end
  {$endregion}
  else begin
    // 1. 可能FCorrIOContext自身已产生错误
    // 2. 也可能调用SendBufferEx时错误
    // 总之，如果返回错误，这里也不能处理
    SendBusy := InterlockedAdd64(FCorrIOContext.FSendBusy, FRecvBytes);
    if SendBusy - FRecvBytes = 0 then begin
      bRet := FCorrIOContext.SendBufferEx();
      if not bRet then begin
       // TODO 只能打印一条消息
        ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBody.SendBufferEx> failed, Status=%s',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          StatusString()]);
        FOwner.WriteLog(llNormal, ErrDesc);
      end;
    end;
  end;
end;

function TTCPProxyServerClientSocket.PrepareCorrIOContext(RemoteIP: string; RemotePort: Word): Boolean;
var
  iRet: Integer;
  ErrDesc: string;
  IOBuffer: PTCPIOBuffer;
begin
  Result := FOwner.PrepareSingleIOContext(FCorrIOContext);
  if Result then begin
    FCorrIOContext.FRemoteIP := RemoteIP;
    FCorrIOContext.FRemotePort := RemotePort;

    IOBuffer := FOwner.DequeueIOBuffer();
    IOBuffer^.OpType := otConnect;
    IOBuffer^.Context := FCorrIOContext;

    FCorrIOContext.FIOStatus := FCorrIOContext.FIOStatus or PROXY_IO_STATUS_ADD_CONNECT;
    iRet := FOwner.IOHandle.PostConnect(FCorrIOContext.FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
      Result := False;
      ErrDesc := Format('[%d][%d][%d]<%s.PrepareCorrIOContext.PostConnect> LastErrorCode=%d, Status=%s',
        [ FSocket,
          FCorrIOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          FCorrIOContext.StatusString()]);
      FOwner.WriteLog(llNormal, ErrDesc);

      FCorrIOContext.FIOStatus := FCorrIOContext.FIOStatus and PROXY_IO_STATUS_DEL_CONNECT_ADD_ERROR;

      if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
        FCorrIOContext.Set80000000Error();

      FOwner.EnqueueIOBuffer(IOBuffer);
      FOwner.EnqueueFreeContext(FCorrIOContext);
    end;
  end;
end;

procedure TTCPProxyServerClientSocket.TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD);
var
  More: Boolean;
begin
  More := True;
  while (not HasErrorOrReadIO(Tea)) and (FStatus and $80000000 = $00000000) and More do begin
    if FStatus and $8000006B = $00000003 then begin // 1000,...,0110,1011
      if FRecvBytes = 0 then begin // 接收数据
        Tea := RecvBuffer();
      end
      else begin
        FStatus := FStatus or $00000008;
        // 转发数据
        ParseAndProcessBody(); // [这里可能产生非独立独立的$8000,0000错误]
        Cigarette := FStatus;

        if FStatus and $80000000 = $00000000 then begin
          FRecvBytes := 0;
          FStatus := FStatus and $E0000003; // 1110,0000,...,0000,0011
        end;
      end;
    end
    else if FStatus and $8000006B = $00000023 then begin // 1000,...,0110,1011
      Tea := SendDisconnect();
    end
    else if FStatus and $8000006B = $00000063 then begin // 1000,...,0110,1011
      // 正常情况下，上下文对应的连接的生命周期在此结束
      Cigarette := FStatus;
      More := False; // [dxm 2018.11.9 no more? maybe!]
    end
    else begin
      // nothing or unkown error
    end;
  end;
end;

{ TTCPProxyIOContext }

constructor TTCPProxyIOContext.Create(AOwner: TTCPIOManager);
begin
  inherited;
  FCorrIOContext := nil;
end;

procedure TTCPProxyIOContext.DecouplingWithCorr(WithNotify: Boolean);
var
  bRet: Boolean;
  IOStatus: Int64;
  IOBuffer: PTCPIOBuffer;
  ErrDesc: string;
begin
  if FCorrIOContext <> nil then begin
    if not WithNotify then begin
      InterlockedOr64(FCorrIOContext.FIOStatus, PROXY_IO_STATUS_DECOUPLING);
    end
    else begin
      IOStatus := InterlockedOr64(FCorrIOContext.FIOStatus,
                          System.Math.IfThen(
                            HasError(FCorrIOContext.FIOStatus),
                            PROXY_IO_STATUS_DECOUPLING,
                            PROXY_IO_STATUS_ADD_NOTIFY_DECOUPLING)
                          );

      if not HasError(IOStatus) then begin
        IOBuffer := FOwner.DequeueIOBuffer();
        IOBuffer^.OpType := otNotify;
        IOBuffer^.Context := FCorrIOContext;
        bRet := FOwner.IOHandle.PostNotify(IOBuffer);
        if not bRet then begin
          ErrDesc := Format('[%d][%d]<%s.DecouplingWithCorr.PostNotify> failed, Status=%s',
            [ FSocket,
              GetCurrentThreadId(),
              ClassName,
              StatusString()]);
          FOwner.WriteLog(llNormal, ErrDesc);
        end;
      end;
    end;
  end;
end;

procedure TTCPProxyIOContext.DoDisconnected(IOBuffer: PTCPIOBuffer);
var
  ErrDesc: string;
  IOIndex: Integer;
  IOStatus: Int64;
begin
// dxm 2018.11.3
// 如果IO正常，则通信套接字可重用，否则不可重用

  IOIndex := IOBuffer^.SequenceNumber mod PROXY_IO_STATUS_READ_CAPACITY;
  if IOBuffer^.LastErrorCode <> 0 then begin
    ErrDesc := Format('[%d][%d]<%s.DoDisconnected> IO内部错误 LastErrorCode=%d, SequenceNumber=%d, Status=%s, IOStatus=%x',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IOBuffer^.SequenceNumber,
        StatusString(),
        FIOStatus]);
    FOwner.WriteLog(llError, ErrDesc);
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();
    IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
    IOStatus := IOStatus and PROXY_IO_STATUS_DEL_READ_IO[IOIndex];
  end
  else begin
    FStatus := FStatus or $00000040;
    FOwner.EnqueueIOBuffer(IOBuffer);

//{$IfDef DEBUG}
//    ErrDesc := Format('[%d][%d]<%s.DoDisconnected>[BEFORE DEL READ IO %d][FIOStatues] FIOStatus=%x',
//      [ FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        IOIndex,
//        FIOStatus]);
//    FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}

    IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO[IOIndex]);

//{$IfDef DEBUG}
//    ErrDesc := Format('[%d][%d]<%s.DoDisconnected>[AFTER DEL READ IO %d][FIOStatues] FIOStatus=%x',
//      [ FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        IOIndex,
//        FIOStatus]);
//    FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}

    IOStatus := IOStatus and PROXY_IO_STATUS_DEL_READ_IO[IOIndex];

//{$IfDef DEBUG}
//
//    ErrDesc := Format('[%d][%d]<%s.DoDisconnected>[LOCAL][IOStatues] IOStatus=%x',
//      [ FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        IOStatus]);
//    FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
  end;

  if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus) or HasNotify(IOStatus)) then begin
    DecouplingWithCorr(HasCoupling(IOStatus));
    if not HasCoupling(IOStatus) then begin
      FOwner.EnqueueFreeContext(Self);
    end
    else begin
      // 定时器
//{$IfDef DEBUG}
//      ErrDesc := Format('[%d][%d][%d]<%s.DoDisConnected> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//        [ FSocket,
//          FCorrIOContext.FSocket,
//          GetCurrentThreadId(),
//          ClassName,
//          30,
//          StatusString()]);
//      FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
      FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
    end;
  end;
end;

procedure TTCPProxyIOContext.DoNotify(IOBuffer: PTCPIOBuffer);
var
  bRet: Boolean;
  ErrDesc: string;
  IOStatus: Int64;
//{$IfDef DEBUG}
//  Msg: string;
//{$Endif}
begin
//{$IfDef DEBUG}
//  Msg := Format('[%d][%d]<%s.DoNotify> enter into <DoNotify> Status=%s, IOStatus=%x',
//    [ FSocket,
//      GetCurrentThreadId(),
//      ClassName,
//      StatusString(),
//      FIOStatus]);
//  FOwner.WriteLog(llDebug, Msg);
//{$Endif}

  FOwner.EnqueueIOBuffer(IOBuffer);
  // dxm 2018.12.19
  // 当客户端收到关联端的通知时：
  // 如果客户端自身没有错误
  // 如果当时环路上有未返回的IO，可直接投递DisconnectEx
  // 如果当时环路上没有IO，只能将该通知继续投递出去，不可以投递DisconnectEx
  // --<Notify>-------<DisconnectEx>----<DisconnectEx返回>----<归还上下文>----------
  // ----------------------------------------------------------------------<READ>---
  IOStatus := InterlockedAnd64(FIOStatus,
                      System.Math.IfThen(
                        HasError(FIOStatus) or (FStatus and $20000000 = $00000000),
                        PROXY_IO_STATUS_DEL_NOTIFY,
                        PROXY_IO_STATUS_FULL)
                      );

  if not HasError(IOStatus) then begin
    if FStatus and $20000000 = $00000000 then begin
      HardCloseSocket();
    end
    else begin
      if HasReadIO(IOStatus) and (not HasRead(IOStatus)) then begin
        SendDisconnect();
        IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_NOTIFY);
        if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
          DecouplingWithCorr(False);
          FOwner.EnqueueFreeContext(Self);
        end
      end
      else begin
        IOBuffer := FOwner.DequeueIOBuffer();
        IOBuffer^.OpType := otNotify;
        IOBuffer^.Context := Self;
        bRet := FOwner.IOHandle.PostNotify(IOBuffer);
        if not bRet then begin
          ErrDesc := Format('[%d][%d]<%s.DoNotify.PostNotify> failed, Status=%s',
            [ FSocket,
              GetCurrentThreadId(),
              ClassName,
              StatusString()]);
          FOwner.WriteLog(llNormal, ErrDesc);
        end;
      end;
    end;
  end
  else if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
    DecouplingWithCorr(False);
    FOwner.EnqueueFreeContext(Self);
  end;
end;

procedure TTCPProxyIOContext.DoRecved(IOBuffer: PTCPIOBuffer);
var
  IOIndex: Integer;
  Status: DWORD;
  IOStatus: Int64;
  ErrDesc: string;
begin
  IOIndex := IOBuffer^.SequenceNumber mod PROXY_IO_STATUS_READ_CAPACITY;
  if IOBuffer^.LastErrorCode <> 0 then begin
    ErrDesc := Format('[%d][%d]<%s.DoRecved> IO内部错误 LastErrorCode=%d, OpType=%s, BytesTransferred=%d, SequenceNumber=%d, Status=%s, IOStatus=%x',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        IOBuffer^.LastErrorCode,
        IO_OPERATION_TYPE_DESC[IOBuffer^.OpType],
        IOBuffer^.BytesTransferred,
        IOBuffer^.SequenceNumber,
        StatusString(),
        FIOStatus]);
    FOwner.WriteLog(llError, ErrDesc);
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();

    IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
    IOStatus := IOStatus and PROXY_IO_STATUS_DEL_READ_IO[IOIndex];

    if not (HasWriteOrWriteIO(IOStatus) or HasReadOrReadIO(IOStatus) or HasNotify(IOStatus)) then begin
      DecouplingWithCorr(HasCoupling(IOStatus));
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d][%d]<%s.DoRecved> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//          [ FSocket,
//            FCorrIOContext.FSocket,
//            GetCurrentThreadId(),
//            ClassName,
//            30,
//            StatusString()]);
//        FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end
  else begin
    if IOBuffer^.BytesTransferred = 0 then begin // 对端优雅关闭
      FStatus := FStatus or $00000020;
      FOwner.EnqueueIOBuffer(IOBuffer);
    end
    else begin
      InterlockedAdd64(FRecvBytes, IOBuffer^.BytesTransferred);
      FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    end;
    IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO[IOIndex]);
    IOStatus := IOStatus and PROXY_IO_STATUS_DEL_READ_IO[IOIndex];

    if HasError(IOStatus) then begin
      if not (HasWriteOrIO(IOStatus) or HasNotify(IOStatus)) then begin
        DecouplingWithCorr(HasCoupling(IOStatus));
        if not HasCoupling(IOStatus) then begin
          FOwner.EnqueueFreeContext(Self);
        end
        else begin
          // 定时器
//{$IfDef DEBUG}
//          ErrDesc := Format('[%d][%d][%d]<%s.DoRecved> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//            [ FSocket,
//              FCorrIOContext.FSocket,
//              GetCurrentThreadId(),
//              ClassName,
//              30,
//              StatusString()]);
//          FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
          FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
        end;
      end;
    end
    else begin
      if not (HasReadOrReadIO(IOStatus) or HasNotify(IOStatus)) then begin
        Status := FStatus;
        TeaAndCigaretteAndMore(IOStatus, Status);

        if Status and $80000040 = $00000040 then begin // [正常结束]
          if not (HasWriteIO(IOStatus) or HasNotify(IOStatus)) then begin
            DecouplingWithCorr(HasCoupling(IOStatus));
            if not HasCoupling(IOStatus) then begin
              FOwner.EnqueueFreeContext(Self);
            end
            else begin
              // 定时器
//{$IfDef DEBUG}
//              ErrDesc := Format('[%d][%d][%d]<%s.DoRecved> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//                [ FSocket,
//                  FCorrIOContext.FSocket,
//                  GetCurrentThreadId(),
//                  ClassName,
//                  30,
//                  StatusString()]);
//              FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
              FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
            end;
          end;
        end
        else if HasError(IOStatus) or (Status and $80000000 = $80000000) then begin
          if not (HasWriteOrIO(IOStatus) or HasNotify(IOStatus)) then begin
            DecouplingWithCorr(HasCoupling(IOStatus));
            if not HasCoupling(IOStatus) then begin
              FOwner.EnqueueFreeContext(Self);
            end
            else begin
              // 定时器
//{$IfDef DEBUG}
//              ErrDesc := Format('[%d][%d][%d]<%s.DoRecved> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//                [ FSocket,
//                  FCorrIOContext.FSocket,
//                  GetCurrentThreadId(),
//                  ClassName,
//                  30,
//                  StatusString()]);
//              FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
              FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
            end;
          end;
        end
        else begin
          // nothing or unkown error!
        end;
      end;
    end;
  end;
end;

procedure TTCPProxyIOContext.DoSent(IOBuffer: PTCPIOBuffer);
var
  iRet: Integer;
  IOStatus: Int64;
  BytesTransferred: Int64;
  LastErrorCode: Integer;
  SendBusy: Int64;
  ErrDesc: string;
begin
  BytesTransferred := IOBuffer^.BytesTransferred;
  LastErrorCode := IOBuffer^.LastErrorCode;
  FSendBytes := FSendBytes + BytesTransferred;

  if LastErrorCode <> 0 then begin // [IO异常]
    ErrDesc := Format('[%d][%d]<%s.DoSent> [%s:%d] IO内部错误 LastErrorCode=%d, SequenceNumber=%d, Status=%s, IOStatus=%x',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        RemoteIP,
        RemotePort,
        IOBuffer^.LastErrorCode,
        IOBuffer^.SequenceNumber,
        StatusString(),
        FIOStatus]);
    FOwner.WriteLog(llError, ErrDesc);
    Set80000000Error();

    FCorrIOContext.FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_WRITE_IO_ADD_ERROR);
    IOStatus := IOStatus and PROXY_IO_STATUS_DEL_WRITE_IO;
  end
  else begin
    FOwner.EnqueueIOBuffer(IOBuffer);
    SendBusy := InterlockedAdd64(FSendBusy, -BytesTransferred);
    if SendBusy > 0 then begin
      iRet := SendBuffer();
      if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
//         TODO 日志
        ErrDesc := Format('[%d][%d]<%s.DoSent.SendBuffer> LastErrorCode=%d, Status=%s',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          StatusString()]);
        FOwner.WriteLog(llNormal, ErrDesc);
      end;
      IOStatus := FSendIOStatus;
    end
    else begin
      IOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_WRITE_IO);
      IOStatus := IOStatus and PROXY_IO_STATUS_DEL_WRITE_IO;
    end;
  end;

  if HasError(IOStatus) or (FStatus and $80000040 = $00000040) then begin
    if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus) or HasNotify(IOStatus)) then begin
      DecouplingWithCorr(HasCoupling(IOStatus));
      if not HasCoupling(IOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d][%d]<%s.DoSent> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//          [ FSocket,
//            FCorrIOContext.FSocket,
//            GetCurrentThreadId(),
//            ClassName,
//            30,
//            StatusString()]);
//        FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end;
end;

function TTCPProxyIOContext.HasCoupling(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_NOCOUPLING <> PROXY_IO_STATUS_NOCOUPLING;
end;

function TTCPProxyIOContext.HasError(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_NOERROR <> PROXY_IO_STATUS_NOERROR;
end;

function TTCPProxyIOContext.HasErrorOrReadIO(IOStatus: Int64): Boolean;
begin
  Result := HasError(IOStatus) or HasReadIO(IOStatus);
end;

function TTCPProxyIOContext.HasIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasNotify(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_NOTIFY <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasRead(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_READ <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasReadIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_READ_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasReadOrReadIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_READ_OR_READ_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasWrite(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_WRITE <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasWriteIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_WRITE_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasWriteOrIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_WRITE_OR_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.HasWriteOrWriteIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and PROXY_IO_STATUS_HAS_WRITE_OR_WRITE_IO <> PROXY_IO_STATUS_EMPTY;
end;

function TTCPProxyIOContext.RecvBuffer: Int64;
var
  iRet: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  IOBuffer := FOwner.DequeueIOBuffer();
  IOBuffer^.Context := Self;
  buf := FOwner.BufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FOwner.BufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.OpType := otRead;
  IOBuffer^.SequenceNumber := FNextSequence;
  Inc(FNextSequence);

{$IfDef DEBUG}
  ErrDesc := Format('[%d][%d]<%s.RecvBuffer>[FIOStatus] FIOStatus=%x',
    [ FSocket,
      GetCurrentThreadId(),
      ClassName,
      FIOStatus]);
  FOwner.WriteLog(llDebug, ErrDesc);
{$Endif}

  InterlockedOr64(FIOStatus, PROXY_IO_STATUS_ADD_READ);
  IOIndex := IOBuffer^.SequenceNumber mod PROXY_IO_STATUS_READ_CAPACITY;
  InterlockedOr64(FIOStatus, PROXY_IO_STATUS_ADD_READ_IO[IOIndex]);

  iRet := FOwner.IOHandle.PostRecv(FSocket, IOBuffer);
  if  (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
    // 输出日志
    ErrDesc := Format('[%d][%d]<%s.RecvBuffer.PostRecv> LastErrorCode=%d, Status=%s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        iRet,
        StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();

    InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
  end;

  Result := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ);
  Result := Result and PROXY_IO_STATUS_DEL_READ;
end;

function TTCPProxyIOContext.SendBuffer: Integer;
var
  IOBuffer: PTCPIOBuffer;
  TempIOBuffer: PTCPIOBuffer;
  ErrDesc: string;
  SequenceNumber: Integer;
  I, J: Integer;
begin
  I := 0;
  SequenceNumber := 0;
  IOBuffer := FOwner.DequeueIOBuffer();
  while (I < FOwner.MultiIOBufferCount) and FCorrIOContext.FOutstandingIOs.Pop(TempIOBuffer) do begin
    SequenceNumber := TempIOBuffer^.SequenceNumber;
    if TempIOBuffer^.BufferCount = 1 then begin
      IOBuffer^.Buffers[I].buf := TempIOBuffer^.Buffers[0].buf;
      if TempIOBuffer^.OpType = otRead then
        IOBuffer^.Buffers[I].len := TempIOBuffer^.BytesTransferred
      else if TempIOBuffer^.OpType = otWrite then
        IOBuffer^.Buffers[I].len := TempIOBuffer^.Buffers[0].len
      else begin
        ErrDesc := Format('[%d][%d]<%s.SendBuffer> get a wrong type buffer, OpType=%s',
          [ FSocket,
            GetCurrentThreadId(),
            ClassName,
            IO_OPERATION_TYPE_DESC[TempIOBuffer^.OpType]]);
        FOwner.WriteLog(llError, ErrDesc);
      end;

      TempIOBuffer^.Buffers[0].buf := nil;
      TempIOBuffer^.Buffers[0].len := 0;
      FOwner.EnqueueIOBuffer(TempIOBuffer);
      Inc(I);
    end
    else begin
      ErrDesc := Format('[%d][%d]<%s.SendBuffer> get a multi buffer, buffercount=%d',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          TempIOBuffer^.BufferCount]);
      FOwner.WriteLog(llWarning, ErrDesc);
      for J := 0 to TempIOBuffer^.BufferCount - 1 do begin
        IOBuffer^.Buffers[I].buf := TempIOBuffer^.Buffers[J].buf;
        IOBuffer^.Buffers[I].len := TempIOBuffer^.Buffers[J].len;
        TempIOBuffer^.Buffers[J].buf := nil;
        TempIOBuffer^.Buffers[J].len := 0;
        Inc(I);
      end;
      FOwner.EnqueueIOBuffer(TempIOBuffer);
    end;
  end;

  IOBuffer^.SequenceNumber := SequenceNumber - 1;
  IOBuffer^.BufferCount := I;
  IOBuffer^.Context := Self;
  IOBuffer^.Flags := 0;
  IOBuffer^.OpType := otWrite;

  InterlockedOr64(FIOStatus, PROXY_IO_STATUS_ADD_WRITE_WRITE_IO);
  Result := FOwner.IOHandle.PostSend(FSocket, IOBuffer);
  if (Result <> 0) and (Result <> WSA_IO_PENDING) then begin
    // 输出日志
    ErrDesc := Format('[%d][%d][%d]<%s.SendBuffer.PostSend> LastErrorCode=%d, Status=%s',
      [ FSocket,
        FCorrIOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        Result,
        StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    Set80000000Error();
    FCorrIOContext.FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    FSendIOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_WRITE_WRITE_IO_ADD_ERROR);
    FSendIOStatus := FSendIOStatus and PROXY_IO_STATUS_DEL_WRITE_WRITE_IO;
  end
  else begin
    FSendIOStatus := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_WRITE);
    FSendIOStatus := FSendIOStatus and PROXY_IO_STATUS_DEL_WRITE;
  end;

  // dxm 2018.11.28
  // 如果内部的SendBuffer调用异常或写IO异常返回，给出去的IOStatus中不应包含本次产生的[ERROR]
  // 例如，当写IO异常返回时，如果之前的IOStatus中没有[ERROR]表示其它逻辑目前都正常因此留待后续东西处理
  // 但是如果之前的IOStatus中有[ERROR]则就必须处理

  if HasError(FSendIOStatus) or (FStatus and $80000040 = $00000040) then begin
    if not (HasReadOrReadIO(FSendIOStatus) or HasWriteOrWriteIO(FSendIOStatus) or HasNotify(FSendIOStatus)) then begin
      DecouplingWithCorr(HasCoupling(FSendIOStatus));
      if not HasCoupling(FSendIOStatus) then begin
        FOwner.EnqueueFreeContext(Self);
      end
      else begin
        // 定时器
//{$IfDef DEBUG}
//        ErrDesc := Format('[%d][%d][%d]<%s.DoSent> be to enqueue TimeWheel for <WaitToEnqueueFreeIOContext> ExpireTime=%ds, Status=%s',
//          [ FSocket,
//            FCorrIOContext.FSocket,
//            GetCurrentThreadId(),
//            ClassName,
//            30,
//            StatusString()]);
//        FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}
        FOwner.TimeWheel.StartTimer(Self, 30 * 1000, FOwner.DoWaitNotify);
      end;
    end;
  end;

end;

function TTCPProxyIOContext.SendBufferEx: Boolean;
var
  iRet: Integer;
begin
  Result := False;
  if FStatus and $80000000 = $00000000 then begin
    iRet := SendBuffer();
    Result := (iRet = 0) or (iRet = WSA_IO_PENDING);
  end;
end;

function TTCPProxyIOContext.SendDisconnect: Int64;
var
  iRet: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  IOBuffer := FOwner.DequeueIOBuffer();
  IOBuffer^.Context := Self;
  buf := FOwner.BufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FOwner.BufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.OpType := otDisconnect;
  IOBuffer^.Flags := TF_REUSE_SOCKET;
  IOBuffer^.SequenceNumber := FNextSequence;
  Inc(FNextSequence);

  InterlockedOr64(FIOStatus, PROXY_IO_STATUS_ADD_READ);
  IOIndex := IOBuffer^.SequenceNumber mod PROXY_IO_STATUS_READ_CAPACITY;
  InterlockedOr64(FIOStatus, PROXY_IO_STATUS_ADD_READ_IO[IOIndex]);

  iRet := FOwner.IOHandle.PostDisconnect(FSocket, IOBuffer);
  if iRet <> WSA_IO_PENDING then begin
    ErrDesc := Format('[%d][%d]<%s.SendDisconnect.PostDisconnect> LastErrorCode=%d, Status=%s',
    [ FSocket,
      GetCurrentThreadId(),
      ClassName,
      iRet,
      StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();
    InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
  end;

  Result := InterlockedAnd64(FIOStatus, PROXY_IO_STATUS_DEL_READ);
  Result := Result and PROXY_IO_STATUS_DEL_READ;
end;

end.
