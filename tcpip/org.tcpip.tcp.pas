{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10.15
 * @Thanks:
 * Liu weimin QQ<287413288>
 * Zhang gaofeng QQ<6117036>
 * @Brief:
 * TTCPIOHandle
 * 1. 提供所有重叠操作接口；
 * 2. 封装IOCP

 * TTCPIOContext
 * 1. 封装通信套接字
 * 2. 管理通信套接字上的所有重叠操作。包括重叠读、重叠写以及重叠断开连接等等

 * TTCPIOManager
 * 1. 管理所有重叠操作对应的IO缓冲
 * 2. 管理所有的通信套接字
 * 3. 管理监听套接字
 * 4. 提供用户接口

 * @Remarks:
 * 这是一个世界，一个高速运转的世界。
 * 每个人即是参与者，也是管理者。
 * 当你来到这个世界的时候，你要向大家问好，这是基本礼节，告诉这个世界的所有人，我来了。
 * 不过，也许别人并没有理会你，但是没关系，当他需要你的时候他自然会去找你的。
 * 当你准备离开的时候，别忘了向大家告别，这也是基本礼节。告诉这个世界的所有人，我走了。
 * 不过，你得留下点什么，也许是遗憾，也许是承载你愿望的继任者。
 * 什么？就这么走了，有点不甘心啊，我还没充当管理者角色呢！！
 * 别急，走的时候多看一眼，如果就剩你一个人，机会来了，你现在就是管理者，你的任务就是停止这个世界。
 * 似乎有点失望，我告诉你，你不是刽子手，你是在给它重生的机会。

 * @Modifications:
 *}

unit org.tcpip.tcp;

interface

uses
  WinApi.Windows,
  WinApi.Winsock2,

  System.SysUtils,
  System.Classes,
  System.Math,
  AnsiStrings,
  org.tcpip,
  org.algorithms,
  org.algorithms.heap,
  org.algorithms.queue,
  org.algorithms.time, // dxm 2018.12.17
  org.algorithms.crc,
  org.utilities,
  org.utilities.buffer,
  org.utilities.iocp;

type
  PTCPSocketProtocolHead = ^TTCPSocketProtocolHead;
  TTCPSocketProtocolHead = record
    Version: Byte;
    R1: array [0..2] of Byte;
    Options: DWORD;
    Length: Int64;
    LengthEx: Int64;
    R2: array [0..5] of Byte;
    CRC16: Word;
  end;

  TTCPServiceStatus = (tssNone, tssStarting, tssRunning, tssStopping, tssStoped);
  TIOOperationType = (otNode, otConnect, otRead, otWrite, otGraceful, otDisconnect, otNotify);

  TTCPIOManager = class;
  TTCPIOContext = class;

  PTCPIOBuffer = ^TTCPIOBuffer;
  TTCPIOBuffer = record
    lpOverlapped: OVERLAPPED;
    LastErrorCode: Integer;
    CompletionKey: ULONG_PTR;
    BytesTransferred: DWORD;
    Buffers: array of WSABUF;
    BufferCount: Integer;
    Flags: DWORD;
    Position: DWORD;                 //
    SequenceNumber: Integer;         // 当同时在套接字s上执行多个IO操作时，用于标识IO顺序
    OpType: TIOOperationType;        // 该IO对应的操作类型，AcceptEx, WSASend, WSARecv等
    Context: TTCPIOContext;          // dxm 2018.12.14 [重构]
  end;

  TTCPIOHandle = class(TIOCP)
  protected
    FStatus: TTCPServiceStatus;
    //\\
    procedure DoThreadException(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR;
      lpOverlapped: POverlapped; E: Exception); override;
    procedure ProcessCompletionPacket(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR;
      lpOverlapped: POverlapped); override;
  public
    function PostAccept(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
    function PostRecv(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
    function PostSend(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
    function PostDisconnect(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
    function PostConnect(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
    //\\
    function PostNotify(IOBuffer: PTCPIOBuffer): Boolean;
  public
    constructor Create(AThreadCount: Integer);
    destructor Destroy; override;
    procedure DoThreadBegin; override;
    procedure DoThreadEnd; override;
    procedure Start; override;
    procedure Stop; override;
    //\\
    procedure HardCloseSocket(s: TSocket);
    //\\
    property Status: TTCPServiceStatus read FStatus;
  end;

  TTCPIOContextClass = class of TTCPIOContext;
  TTCPIOContext = class
  private
    function DoSequenceNumCompare(const Value1, Value2: Integer): Integer;
    procedure DoSendBufferNotify(const Buffer: TBuffer; Action: TActionType);
  protected
    FOwner: TTCPIOManager;
    FStatus: DWORD;
    FIOStatus: Int64;                                  // dxm 2018.11.7 描述当前虚拟环路中的IO状态
    FSendIOStatus: Int64;
    FSendBytes: Int64;
    FRecvBytes: Int64;
    FSendBusy: Int64;                                  // 用于同步发送
    FOutstandingIOs: TMiniHeap<Integer, PTCPIOBuffer>; // 缓存返回IO的最小堆
    FSendBuffers: TFlexibleQueue<TBuffer>;             // 缓存用户提交的待发送数据
    FNextSequence: Integer;
    //\\
    FRefCount: Integer; // dxm 2018.12.18
    //\\
    FSocket: TSocket;
    FRemoteIP: string;
    FRemotePort: Word;
    //\\
    FHeadSize: DWORD;
    FHead: PTCPSocketProtocolHead;
    //\\
    FBodyInFile: Boolean;
    FBodyFileName: string;
    FBodyFileHandle: THandle;
    FBodyUnfilledLength: Int64;
    //\\
    FBodyExInFile: Boolean;
    FBodyExFileName: string;
    FBodyExFileHandle: THandle;
    FBodyExUnfilledLength: Int64;
    FBodyExToBeDeleted: Boolean;
    //\\
    FCrc16: TCrc16;
    function HasError(IOStatus: Int64): Boolean; virtual;
    function HasReadIO(IOStatus: Int64): Boolean; virtual;
    function HasWriteIO(IOStatus: Int64): Boolean; virtual;
    function HasErrorOrReadIO(IOStatus: Int64): Boolean; virtual;
    function HasIO(IOStatus: Int64): Boolean; virtual;
    function HasRead(IOStatus: Int64): Boolean; virtual;
    function HasReadOrReadIO(IOStatus: Int64): Boolean; virtual;
    function HasWrite(IOStatus: Int64): Boolean; virtual;
    function HasWriteOrWriteIO(IOStatus: Int64): Boolean; virtual;
    function HasWriteOrIO(IOStatus: Int64): Boolean; virtual;
    //\\
    function RecvProtocol: Int64;
    function RecvBuffer: Int64; virtual;
    function RecvDisconnect: Int64;
    function SendDisconnect: Int64; virtual;
    function SendBuffer: Integer; virtual;
    //\\
    function GetTempFile: string;
    procedure WriteBodyToFile;
    procedure WriteBodyExToFile;
    procedure GetBodyFileHandle;
    procedure GetBodyExFileHandle;
    //\\
    procedure TeaAndCigaretteAndMore(var Tea: Int64; var Cigarette: DWORD); virtual; abstract;
    procedure DoConnected; virtual; abstract;
    procedure DoRecved(IOBuffer: PTCPIOBuffer); virtual;
    procedure DoSent(IOBuffer: PTCPIOBuffer); virtual;
    procedure DoDisconnected(IOBuffer: PTCPIOBuffer); virtual;
    procedure DoNotify(IOBuffer: PTCPIOBuffer); virtual; abstract;
    //\\
    procedure ParseProtocol; virtual;
    procedure FillProtocol(pHead: PTCPSocketProtocolHead); virtual;
    procedure ParseAndProcessBody; virtual;
    procedure ParseAndProcessBodyEx; virtual;
    procedure NotifyBodyExProgress; virtual; abstract;
    //\\
    function SendToPeer(Body: PAnsiChar; Length: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: PAnsiChar; Length: DWORD; BodyEx: PAnsiChar; LengthEx: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: PAnsiChar; Length: DWORD; BodyEx: TStream; LengthEx: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: PAnsiChar; Length: DWORD; FilePath: string; Options: DWORD): Integer; overload;

    function SendToPeer(Body: TStream; Length: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: TStream; Length: DWORD; BodyEx: PAnsiChar; LengthEx: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: TStream; Length: DWORD; BodyEx: TStream; LengthEx: DWORD; Options: DWORD): Integer; overload;
    function SendToPeer(Body: TStream; Length: DWORD; FilePath: string; Options: DWORD): Integer; overload;
  public
    constructor Create(AOwner: TTCPIOManager); virtual;
    destructor Destroy; override;
    //\\
    procedure HardCloseSocket;
    procedure Set80000000Error;
    function StatusString: string;
    function IsClientIOContext: Boolean;
    function IsServerIOContext: Boolean;
    //\\
    property Socket: TSocket read FSocket;
    property RemotePort: Word read FRemotePort;
    property RemoteIP: string read FRemoteIP;
  end;

  TTCPConnectedNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
  TTCPRecvedNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
  TTCPSentNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
  TTCPDisConnectingNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;

  TTCPIOManager = class
  private
    //\\ 用户事件
    FLogNotify: TLogNotify;
    FConnectedNotify: TTCPConnectedNotify;
    FRecvedNotify: TTCPRecvedNotify;
    FSentNotify: TTCPSentNotify;
    FDisconnectingNotify: TTCPDisConnectingNotify;
    FLogLevel: TLogLevel;        // 默认为llNormal，如果指定不能小于llError
    FTempDirectory: string;      // 对Body和BodyEx，如果接收内容超过FMultiIOBufferCount*FBufferSize，
                                 // 则直接写入临时文件，该成员指明临时文件目录
    FBuffersInUsed: Integer;     // 统计用
    procedure SetLogNotify(const Value: TLogNotify);
    procedure SetLogLevel(const Value: TLogLevel);
    procedure SetTempDirectory(const Value: string);
  protected
    FHeadSize: DWORD;
    FBufferSize: UInt64;            // 内存池中每个Buffer的大小，必须为页的整数倍
    FBufferPool: TBufferPool;       // 内存池，按页的整数倍分配
    FMultiIOBufferCount: Integer;   // 一次提交Buffer的最大个数
    FIOBuffers: TFlexibleQueue<PTCPIOBuffer>;  // 管理IO缓冲
    FIOHandle: TTCPIOHandle;
    FTimeWheel: TTimeWheel<TTCPIOContext>; // dxm 2018.12.17
    procedure SetMultiIOBufferCount(const Value: Integer); virtual;
    //\\ dxm 2018.11.6
    //\\ 关闭时释放IOBuffer和IOContext
    procedure DoIOBufferNotify(const IOBuffer: PTCPIOBuffer; Action: TActionType);
    procedure DoIOContextNotify(const IOContext: TTCPIOContext; Action: TActionType);
    //\\
    function AllocateIOBuffer: PTCPIOBuffer;
    procedure ReleaseIOBuffer(IOBuffer: PTCPIOBuffer);
    //\\
    function DoAcceptEx(IOBuffer: PTCPIOBuffer): Boolean; virtual; abstract;
    function DoConnectEx(IOBuffer: PTCPIOBuffer): Boolean; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    //\\
    function DequeueIOBuffer: PTCPIOBuffer;
    procedure EnqueueIOBuffer(IOBuffer: PTCPIOBuffer);
    function DequeueFreeContext(IOType: DWORD): TTCPIOContext; virtual; abstract;
    procedure EnqueueFreeContext(AContext: TTCPIOContext); virtual;
    procedure RegisterIOContextClass(IOType: DWORD; AClass: TTCPIOContextClass); virtual; abstract;
    //\\
    procedure DoWaitTIMEWAIT(IOContext: TTCPIOContext); virtual; abstract;
    procedure DoWaitNotify(IOContext: TTCPIOContext); virtual; abstract;
    procedure DoWaitFirstData(IOContext: TTCPIOContext); virtual;
    //\\
    function ListenAddr(LocalIP: string; LocalPort: Word): TSocket;
    function PostSingleAccept(IOSocket: TSocket): Integer;  // 返回表示错误码，其中0或WSA_IO_PENDING表示投递成功
    function PostMultiAccept(IOSocket: TSocket; Count: Integer): Integer; // 返回值表示成功投递的预连接数量
    //\\
    function PrepareSingleIOContext(IOContext: TTCPIOContext): Boolean;
    function PrepareMultiIOContext(AClass: TTCPIOContextClass; Count: Integer): Integer;
    //\\
    procedure Start; virtual;
    procedure Stop; virtual;
    procedure WriteLog(LogLevel: TLogLevel; LogContent: string);
    //\\
    property IOHandle: TTCPIOHandle read FIOHandle;
    property HeadSize: DWORD read FHeadSize write FHeadSize;
    property BufferPool: TBufferPool read FBufferPool;
    property BufferSize: UInt64 read FBufferSize;
    property MultiIOBufferCount: Integer read FMultiIOBufferCount write SetMultiIOBufferCount;
    property TempDirectory: string read FTempDirectory write SetTempDirectory;
    property LogLevel: TLogLevel read FLogLevel write SetLogLevel;
    property BuffersInUsed: Integer read FBuffersInUsed;
    property TimeWheel: TTimeWheel<TTCPIOContext> read FTimeWheel;
    //\\
    property OnLog: TLogNotify read FLogNotify write SetLogNotify;
    property OnConnected: TTCPConnectedNotify read FConnectedNotify write FConnectedNotify;
    property OnRecved: TTCPRecvedNotify read FRecvedNotify write FRecvedNotify;
    property OnSent: TTCPSentNotify read FSentNotify write FSentNotify;
    property OnDisconnecting: TTCPDisConnectingNotify read FDisconnectingNotify write FDisconnectingNotify;
  end;

const
  IO_OPTION_EMPTY: DWORD                  = $00000000;
  IO_OPTION_ONCEMORE: DWORD               = $00000001;
  IO_OPTION_NOTIFY_BODYEX_PROGRESS: DWORD = $00000002;

  IO_OPERATION_TYPE_DESC: array [TIOOperationType] of string = (
    '空闲',
    '连接',
    '接收',
    '发送',
    '接收GRACEFUL',
    '断开',
    '通知'
  );

{========================================================
1. Status(状态)
    00000000,00000000,00000000,00000000 [$00000000][闲置]
    00000000,00000000,00000000,00000001 [$00000001][连接中]
    00000000,00000000,00000000,00000010 [$00000002][已连接]
    00000000,00000000,00000000,00000100 [$00000004][协议头读取]
    00000000,00000000,00000000,00001000 [$00000008][Body已读取]
    00000000,00000000,00000000,00010000 [$00000010][BodyEx已读取]
    00000000,00000000,00000000,00100000 [$00000020][Graceful IO 已返回]
    00000000,00000000,00000000,01000000 [$00000040][DisconnectEx IO 已返回]
    ........,........,........,........
    00100000,00000000,00000000,00000000 [$20000000][客户端套接字:1; 服务端套接字:0]
    01000000,00000000,00000000,00000000 [$40000000][套接字已被关闭] [仅用于服务端关闭时设置，几乎不参与程序逻辑]
    10000000,00000000,00000000,00000000 [$80000000][出错]

 2. IOStatus(64位)
    10000000,00000000,........,00000001 [$8000,0000,0000,0001] [READ IO  0] [第0位到第58位表示虚拟环路中的一个读IO, 共59个]
    10000000,00000000,........,00000010
    ........,........,........,........
    10000100,00000000,........,00000000 [$8400,0000,0000,0000] [READ IO 58]
    10001000,00000000,........,00000000 [$8800,0000,0000,0000] [WRITE IO]
    10010000,00000000,........,00000000 [$9000,0000,0000,0000] [IO ERROR]
    10100000,00000000,........,00000000 [$A000,0000,0000,0000] [WRITE ]
    11000000,00000000,........,00000000 [$C000,0000,0000,0000] [READ]
    10000000,00000000,........,00000000 [] [保留]
========================================================}

  IO_STATUS_EMPTY: Int64                           = -$8000000000000000; //     1000,0000,...,0000;
  IO_STATUS_INIT: Int64                            = -$7000000000000000; //     1001,0000,...,0000;$9000000000000000
  IO_STATUS_NOERROR: Int64                         = -$7000000000000000; //[and]1001,0000,...,0000;$9000000000000000

  IO_STATUS_HAS_READ: Int64                        = -$4000000000000000;
  IO_STATUS_HAS_READ_IO: Int64                     = -$7800000000000001; //[and]1000,0111,...,1111;$87FFFFFFFFFFFFFF
  IO_STATUS_HAS_READ_OR_READ_IO: Int64             = -$3800000000000001; //[and]1100,0111,...,1111;$C7FFFFFFFFFFFFFF
  IO_STATUS_HAS_WRITE: Int64                       = -$6000000000000000;
  IO_STATUS_HAS_WRITE_IO: Int64                    = -$7800000000000000;
  IO_STATUS_HAS_WRITE_OR_WRITE_IO: Int64           = -$5800000000000000; //[and]1010,1000,...,0000;$A800000000000000
  IO_STATUS_HAS_IO: Int64                          = -$7000000000000001;
  IO_STATUS_HAS_WRITE_OR_IO: Int64                 = -$5000000000000001; //[and]1010,1111,...,1111;$AFFFFFFFFFFFFFFF

  IO_STATUS_ADD_WRITE_WRITE_IO: Int64              = -$5800000000000000; //[ or]1010,1000,...,0000;$A800000000000000
  IO_STATUS_DEL_WRITE: Int64                       = -$2000000000000001; //[and]1101,1111,...,1111;$DFFFFFFFFFFFFFFF
  IO_STATUS_DEL_WRITE_WRITE_IO: Int64              = -$2800000000000001; //[and]1101,0111,...,1111;$D7FFFFFFFFFFFFFF
  IO_STATUS_DEL_WRITE_WRITE_IO_ADD_ERROR: Int64    = -$3800000000000001; //[and]1100,0111,...,1111;$C7FFFFFFFFFFFFFF
  IO_STATUS_DEL_WRITE_IO: Int64                    = -$0800000000000001; //[and]1111,0111,...,1111;$F7FFFFFFFFFFFFFF
  IO_STATUS_DEL_WRITE_IO_ADD_ERROR: Int64          = -$1800000000000001;

  IO_STATUS_ADD_READ: Int64                        = -$4000000000000000; //[and]1100,0000,...,0000;$C000000000000000
  IO_STATUS_DEL_READ: Int64                        = -$4000000000000001; //[and]1011,1111,...,1111;$BFFFFFFFFFFFFFFF
  IO_STATUS_READ_CAPACITY                          = 59;
  // 增加IO位 [or]
  IO_STATUS_ADD_READ_IO: array [0..IO_STATUS_READ_CAPACITY-1] of Int64 = (
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
    -$7FF0000000000000, -$7FE0000000000000, -$7FC0000000000000, -$7F80000000000000,
    -$7F00000000000000, -$7E00000000000000, -$7C00000000000000
  );

  // 去除IO位 [and]
  IO_STATUS_DEL_READ_IO: array [0..IO_STATUS_READ_CAPACITY-1] of Int64 = (
    // 1111,...,1110; $FFFFFFFFFFFFFFFE
    // 1111,...,1101; $FFFFFFFFFFFFFFFD
    // 1111,...,1011; $FFFFFFFFFFFFFFFB
    // 1111,...,0111; $FFFFFFFFFFFFFFF7
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
    -$0010000000000001, -$0020000000000001, -$0040000000000001, -$0080000000000001,
    -$0100000000000001, -$0200000000000001, -$0400000000000001
  );

  // 去除IO位并增加错误位 [and]
  IO_STATUS_DEL_READ_IO_ADD_ERROR: array [0..IO_STATUS_READ_CAPACITY-1] of Int64 = (
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
    -$1010000000000001, -$1020000000000001, -$1040000000000001, -$1080000000000001,
    -$1100000000000001, -$1200000000000001, -$1400000000000001
  );

implementation

{ TTCPIOHandle }

constructor TTCPIOHandle.Create(AThreadCount: Integer);
begin
  inherited;
  FStatus := tssNone;
end;

destructor TTCPIOHandle.Destroy;
begin

  inherited;
end;

procedure TTCPIOHandle.DoThreadBegin;
var
  Msg: string;
begin
  Msg := Format('[%d]Start thread OK', [GetCurrentThreadId()]);
  WriteLog(llNormal, Msg);
  inherited;
end;

procedure TTCPIOHandle.DoThreadEnd;
var
  Msg: string;
begin
  inherited;
  Msg := Format('[%d]Stop thread OK', [GetCurrentThreadId()]);
  WriteLog(llNormal, Msg);
end;

procedure TTCPIOHandle.DoThreadException(dwNumOfBytes: DWORD;
  dwCompletionKey: ULONG_PTR; lpOverlapped: POverlapped; E: Exception);
var
  ErrDesc: string;
  IOBuffer: PTCPIOBuffer;
begin
  inherited;
  IOBuffer := PTCPIOBuffer(lpOverlapped);
  ErrDesc := Format('[%d][%d]<%s.DoThreadException> dwNumOfBytes=%d, dwCompletionKey=%d, Internal=%d, InternalHigh=%d, LastErrorCode=%d, OpType=%s, Status=%s, ExceptionMsg=%s',
    [ IOBuffer^.Context.FSocket,
      GetCurrentThreadId(),
      ClassName,
      dwNumOfBytes,
      dwCompletionKey,
      IOBuffer^.lpOverlapped.Internal,
      IOBuffer^.lpOverlapped.InternalHigh,
      IOBuffer^.LastErrorCode,
      IO_OPERATION_TYPE_DESC[IOBuffer^.OpType],
      IOBuffer^.Context.StatusString(),
      E.Message]);
  WriteLog(llFatal, ErrDesc);
end;

procedure TTCPIOHandle.HardCloseSocket(s: TSocket);
var
  Linger: TLinger;
  ErrDesc: string;
begin
  Linger.l_onoff  := 1;
  Linger.l_linger := 0;
  if (setsockopt(s,
               SOL_SOCKET,
               SO_LINGER,
               @Linger,
               SizeOf(Linger)) = SOCKET_ERROR) then
  begin
    ErrDesc := Format('[%d][%d]<%s.HardCloseSocket.setsockopt> LastErrorCode=%d',
      [ s,
        GetCurrentThreadId(),
        ClassName,
        WSAGetLastError()]);
    WriteLog(llFatal, ErrDesc);
  end;

  closesocket(s);
end;

function TTCPIOHandle.PostAccept(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
var
  ErrDesc: string;
begin
  Result := 0;
  if IOBuffer^.Context.FSocket = INVALID_SOCKET then begin
    // dxm 2018.11.2
    // WSAEMFILE  [10024]  没有可用套接字资源           [致命]
    // WSAENOBUFS [10055]  没有可用内存以创建套接字对象 [致命]

    // 上述2个错误显然是[致命]错误
    IOBuffer^.Context.FSocket := WSASocket(
                                    AF_INET,
                                    SOCK_STREAM,
                                    IPPROTO_TCP,
                                    nil,
                                    0,
                                    WSA_FLAG_OVERLAPPED);

    if IOBuffer^.Context.FSocket = INVALID_SOCKET then begin
      Result := WSAGetLastError();
      // 输出日志
      ErrDesc := Format('[][%d]<%s.PostAccept.WSASocket> LastErrorCode=%d',
        [ GetCurrentThreadId(),
          ClassName,
          Result]);
      WriteLog(llFatal, ErrDesc);
      Exit;
    end;
  end;

  // dxm 2018.11.1
  // 发起重叠建立连接操作
  // 当连接建立完成时，会带回已传输字节数，完成Key以及OVERLAPPED结构体
  // 当然，在关联监听套接字时并未指定完成Key
  // dxm 2018.11.2
  // ERROR_IO_PENDING [997]    重叠IO初始化成功，稍后通知完成          [------][调用时][正常]
  // WSAECONNRESET    [10054]  对端提交连接请求后，随即又终止了该请求  [通知时][------][正常][可重用][说明一旦收到连接请求，后续对端即使取消，本地也只是标记而已]
  //                           对端强制关闭了已建立的连接。例如，程序崩溃、主机重启、掉线；或者是对端执行了硬关闭
  //                           当出现这种情况是，正在执行中的操作返回WSAENETRESET[10052]错误，而后续操作则返回WSAECONNRESET

  // 可见本函数不应该有错误，如果出现了错误则说明个人理解问题或其它未知的错误，暂且定为[致命][不可重用]
  if not org.tcpip.lpfnAcceptEx(
           IOSocket,
           IOBuffer^.Context.FSocket,
           IOBuffer^.Buffers[0].buf, {data + local address + remote address}
           0, //为0时不接收连接数据
           Sizeof(TSockAddrIn) + 16,
           Sizeof(TSockAddrIn) + 16,
           IOBuffer^.BytesTransferred, //
           @IOBuffer^.lpOverlapped) then
  begin
    Result := WSAGetLastError();
    if Result <> WSA_IO_PENDING then begin
      // 输出日志
      ErrDesc := Format('[%d][%d]<%s.PostAccept.AcceptEx> LastErrorCode=%d',
        [ IOBuffer^.Context.FSocket,
          GetCurrentThreadId(),
          ClassName,
          Result]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

function TTCPIOHandle.PostConnect(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
var
  ErrDesc: string;
  SrvAddr: TSockAddr;
begin
  Result := 0;
  // dxm 2018.11.1
  // 发起重叠建立连接操作
  // 当连接建立完成时，会带回已传输字节数，完成Key以及OVERLAPPED结构体
  // 当然，在关联监听套接字时并未指定完成Key
  // dxm 2018.11.2
  // ERROR_IO_PENDING [997]   重叠IO初始化成功，稍后通知完成          [------][调用时][正常]
  // WSAECONNRESET    [10054] 对端提交连接请求后，随即又终止了该请求  [通知时][------][正常][可重用][说明一旦收到连接请求，后续对端即使取消，本地也只是标记而已]

  // 可见本函数不应该有错误，如果出现了错误则说明个人理解问题或其它未知的错误，暂且定为[致命][不可重用]

  IOBuffer^.Context.FStatus := IOBuffer^.Context.FStatus or $00000001;

  ZeroMemory(@SrvAddr, SizeOf(TSockAddrIn));
  TSockAddrIn(SrvAddr).sin_family := AF_INET;
  TSockAddrIn(SrvAddr).sin_addr.S_addr := inet_addr(PAnsiChar(Ansistring(IOBuffer.Context.FRemoteIP)));
  TSockAddrIn(SrvAddr).sin_port := htons(IOBuffer.Context.FRemotePort);
  // dxm 2018.11.15
  // WSAETIMEDOUT [10060] 连接超时 [通知时][------][错误][分析：服务端投递的预连接太少，需动态设置预投递上限]
  if not org.tcpip.lpfnConnectEx(
           IOSocket,
           @SrvAddr,
           SizeOf(TSockAddrIn),
           nil, {data}
           0, //为0时不发送连接数据
           IOBuffer^.BytesTransferred, //
           @IOBuffer^.lpOverlapped
           ) then
  begin
    Result := WSAGetLastError();
    if Result <> WSA_IO_PENDING then begin
      // 输出日志
      ErrDesc := Format('[%d][%d]<%s.PostConnect.ConnectEx> LastErrorCode=%d, Status=%s',
        [ IOBuffer^.Context.FSocket,
          GetCurrentThreadId(),
          ClassName,
          Result,
          IOBuffer^.Context.StatusString()]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

function TTCPIOHandle.PostDisconnect(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
var
  ErrDesc: string;
begin
  Result := 0;
  if not org.tcpip.lpfnDisconnectEx(
                            IOSocket,
                            @IOBuffer^.lpOverlapped,
                            IOBuffer^.Flags,
                            0) then
  begin
    Result := WSAGetLastError();
    if Result <> WSA_IO_PENDING then begin
      // 输出日志
      ErrDesc := Format('[%d][%d]<%s.PostDisconnect.DisconnectEx> LastErrorCode=%d, Status=%s',
        [ IOSocket,
          GetCurrentThreadId(),
          ClassName,
          Result,
          IOBuffer^.Context.StatusString()]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

function TTCPIOHandle.PostNotify(IOBuffer: PTCPIOBuffer): Boolean;
var
  dwRet: DWORD;
  ErrDesc: string;
begin
  Result := PostQueuedCompletionStatus(0, 0, @IOBuffer^.lpOverlapped);
  if not Result then begin
    dwRet := GetLastError();
    ErrDesc := Format('[%d][%d]<%s.PostNotify.PostQueuedCompletionStatus> LastErrorCode=%d, Status=%s',
      [ IOBuffer^.Context.FSocket,
        GetCurrentThreadId(),
        ClassName,
        dwRet,
        IOBuffer^.Context.StatusString()]);
    WriteLog(llFatal, ErrDesc);
  end;
end;

function TTCPIOHandle.PostRecv(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
var
  ErrDesc: string;
begin
  Result := 0;
  // dxm 2018.12.06
  // WSAECONNRESET [10054] [通知时][调用时][不可重用]
  // WSAENOTCONN   [10057] [][][]
  if (WinApi.Winsock2.WSARecv(
                        IOSocket,
                        @IOBuffer^.Buffers[0],
                        IOBuffer^.BufferCount,
                        IOBuffer^.BytesTransferred,
                        IOBuffer^.Flags,
                        @IOBuffer^.lpOverlapped,
                        nil) = SOCKET_ERROR) then
  begin
    Result := WSAGetLastError();
    if Result <> WSA_IO_PENDING then begin
      ErrDesc := Format('[%d][%d]<%s.PostRecv.WSARecv> LastErrorCode=%d, Status=%s',
        [ IOSocket,
          GetCurrentThreadId(),
          ClassName,
          Result,
          IOBuffer^.Context.StatusString()]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

function TTCPIOHandle.PostSend(IOSocket: TSocket; IOBuffer: PTCPIOBuffer): Integer;
var
  ErrDesc: string;
begin
  Result := 0;
  if (WinApi.Winsock2.WSASend(
                          IOSocket,
                          @IOBuffer^.Buffers[0],
                          IOBuffer^.BufferCount,
                          IOBuffer^.BytesTransferred,
                          IOBuffer^.Flags,
                          @IOBuffer^.lpOverlapped,
                          nil) = SOCKET_ERROR) then
  begin
    Result := WSAGetLastError();
    if Result <> WSA_IO_PENDING then begin
      ErrDesc := Format('[%d][%d]<%s.PostSend.WSASend> LastErrorCode=%d, Status=%s',
        [ IOSocket,
          GetCurrentThreadId(),
          ClassName,
          Result,
          IOBuffer^.Context.StatusString()]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

procedure TTCPIOHandle.ProcessCompletionPacket(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR;
  lpOverlapped: POverlapped);
var
  bRet: Boolean;
  IOBuffer: PTCPIOBuffer;
  IOContext: TTCPIOContext;
{$IfDef DEBUG}
  Msg: string;
{$Endif}
begin
  // dxm 2018.11.2
  // IOCP端只要出队了一个不为nil的lpOverlapped，就会调用此函数进行处理：
  //----------------------------------
  // 1. IOBuffer^.OpType = otConnect
  // 此封包是针对监听套接字的，可能的IO错误有：
  // <1>. ERROR_IO_PENDING [997]   重叠IO初始化成功，稍后通知完成          [------][调用时][正常]
  // <2>. WSAECONNRESET    [10054] 对端提交连接请求后，随即又终止了该请求  [通知时][------][正常][可重用][说明一旦收到连接请求，后续对端即使取消，本地也只是标记而已]
  // 1>. 如果IO正常，即lpOverlapped^.Internal=0，表示成功建立连接，后续交由DoAcceptEx处理
  // 2>. 如果IO异常，即lpOverlapped^.Internal=WSAECONNRESET，表示对端提交连接请求后，随即又终止了该请求，也交由DoAcceptEx处理
  //----------------------------------
  // 2. IOBuffer^.OpType = otRead
  // 此封包是针对通信套接字的重叠读IO，可能的IO错误有：
  // <1>. WSAECONNABORTED [10053] 由于超时或其他错误导致虚拟环路终止        [通知时][调用时][错误][不可重用][软件导致连接终止，可能是数据传输超时或协议错误]
  // <2>. WSAECONNRESET   [10054] 对端重置了虚拟环路                        [通知时][调用时][错误][不可重用][对端程序停止、主机重启、网络丢失、对端执行了硬关闭]
  // <3>. WSAENETRESET    [10052] 与keep-alive有关等等                      []
  // <4>. WSAETIMEDOUT    [10060] 由于网络错误或对端响应失败导致连接被丢弃  [通知时][------][错误][不可重用]
  // <5>. WSAEWOULDBLOCK  [10035] Windows NT 正在处理的重叠IO请求太多       [------][调用时][正常][稍后]
  // <6>. WSA_IO_PENDING  [997]   重叠IO已成功初始化，稍后通知完成          [------][调用时][正常][稍后]
  // <7>. WSA_OPERATION_ABORTED 由于套接字被关闭而导致重叠IO被取消        [通知时][------][错误][----]
  // 1>. 如果调用WSARecv时返回<1>,<2>错误，如果系统上有当前套接字的IO请求存在，个人认为其会以同样的错误码返回IO完成封包，
  // 但是，在调用WSARecv时返回<1>,<2>错误后，如果立即关闭(closesocket)套接字，该套接字上的其它IO请求是返回同样的错误码还是错误<7>？
  // 如果是第一种情况，则等待全部IO请求返回后关闭套接字
  // 如果是第二种情况，需进行验证
  // 2>. 个人认为错误<4>应该在IO通知时才能获取，感觉应该同1>的第一种情况
  // 3>. 当关闭套接字后，系统会取消该套接字上的Pending IO和Outstanding IO，这些IO最终都会以错误<7>返回，
  // 由于当前套接字上未返回的IO数量记录在Context中，因此，为了能够正确地回收为这些IO分配的应用程序资源，
  // 任何时候关闭套接字都必须等待上下文中的IO计数归零后在回收上下文资源
  //
  // 对1>,2>,3>情况出队的完成封包都必须交给上下文对象进行处理，依次将这些IOBuffer归还应用程序；
  // 对1>,2>情况当IO计数归零后应将上下文状态设置为FStatus := FStatus or $80000000以便回收函数(EnqueueContext)将出错的套接字关闭；
  // 对3>情况，由于套接字已被主动关闭，故不需为上下文增加$80000000位。
  //-----------------------------------------
  // 3. IOBuffer^.OpType = otWrite
  // 此封包是针对通信套接字的重叠写IO，其处理方式同otRead
  // ----------------------------------------
  // 4. IOBuffer^.OpType = otDisConnect

  IOBuffer := PTCPIOBuffer(lpOverlapped);
  IOBuffer^.CompletionKey := dwCompletionKey;
  IOContext := IOBuffer^.Context;
  if IOBuffer^.OpType <> otNotify then begin
    bRet := WSAGetOverlappedResult(
                              IOContext.FSocket,
                              @IOBuffer^.lpOverlapped,
                              IOBuffer^.BytesTransferred,
                              False,
                              IOBuffer^.Flags);
    if not bRet then
      IOBuffer^.LastErrorCode := WSAGetLastError();
  end;

{$IfDef DEBUG}
  Msg := Format('[%d][%d]<%s.ProcessCompletionPacket> dwNumBytes=%d, dwKey=%d, LastErrorCode=%d, SequenceNumber=%d, OpType=%s, Status=%s, IOStatus=%x',
    [ IOContext.FSocket,
      GetCurrentThreadId(),
      ClassName,
      dwNumOfBytes,
      dwCompletionKey,
      IOBuffer^.LastErrorCode,
      IOBuffer^.SequenceNumber,
      IO_OPERATION_TYPE_DESC[IOBuffer^.OpType],
      IOContext.StatusString(),
      IOContext.FIOStatus]);
  WriteLog(llDebug, Msg);
{$Endif}

  IOBuffer^.BytesTransferred := dwNumOfBytes;
  case IOBuffer^.OpType of
    otConnect: begin
      if IOContext.FStatus and $20000000 = $00000000 then begin
        if IOContext.FOwner.DoAcceptEx(IOBuffer) then IOContext.DoConnected();
      end
      else begin
        if IOContext.FOwner.DoConnectEx(IOBuffer) then IOContext.DoConnected();
      end;
    end;

    otRead, otGraceful: IOContext.DoRecved(IOBuffer);

    otWrite: IOContext.DoSent(IOBuffer);

    otDisconnect: IOContext.DoDisconnected(IOBuffer);

    otNotify: IOContext.DoNotify(IOBuffer);
  end;
end;

procedure TTCPIOHandle.Start;
var
  iRet: Integer;
  wsaData: TWsaData;
begin
  FStatus := tssStarting;
  iRet := WSAStartup(MakeWord(2, 2), wsaData);
  if iRet <> 0 then
    raise Exception.CreateFmt('[%d]<%s.Start.WSAStartup> failed with error: %d', [GetCurrentThreadId(), ClassName, iRet]);

  iRet := LoadWinsockEx();
  if iRet = 0 then
    raise Exception.CreateFmt('[%d]<%s.Start.LoadWinsockEx> failed', [GetCurrentThreadId(), ClassName]);

  //启动线程池
  inherited;

  FStatus := tssRunning;
end;

procedure TTCPIOHandle.Stop;
begin
  FStatus := tssStopping;
  WSACleanup();

  inherited;

  FStatus := tssStoped;
end;

{ TTCPIOContext }

constructor TTCPIOContext.Create(AOwner: TTCPIOManager);
begin
  FOwner := AOwner;
  //\\
  // FStatus := 延迟到派生类赋值。[不同的派生类FStatus的初始值可能不同]
  FIOStatus := IO_STATUS_INIT;
  FSendIOStatus := IO_STATUS_INIT;
  FSendBytes := 0;
  FRecvBytes := 0;
  FSendBusy := 0;
  FNextSequence := 0;
  FRefCount := 0;
  FOutstandingIOs := TMiniHeap<Integer, PTCPIOBuffer>.Create(128);
  FOutstandingIOs.OnKeyCompare := DoSequenceNumCompare;
  FSendBuffers := TFlexibleQueue<TBuffer>.Create(128);
  FSendBuffers.OnItemNotify := DoSendBufferNotify;
  //\\
  FSocket := INVALID_SOCKET;
  FRemoteIP := '';
  FRemotePort := 0;
  //\\
  FHeadSize := FOwner.HeadSize;
  FHead := AllocMem(FHeadSize);
  //\\
  FBodyInFile := False;
  FBodyFileName := '';
  FBodyFileHandle := INVALID_HANDLE_VALUE;
  FBodyUnfilledLength := 0;
  //\\
  FBodyExInFile := False;
  FBodyExFileName := '';
  FBodyExFileHandle := INVALID_HANDLE_VALUE;
  FBodyExUnfilledLength := 0;
  FBodyExToBeDeleted := False;
  //\\
  FCrc16 := TCrc16.Create();
end;

destructor TTCPIOContext.Destroy;
begin
  FOutstandingIOs.Free();
  FSendBuffers.Free();
  FreeMem(FHead, FHeadSize);
  FCrc16.Free();
  inherited;
end;

procedure TTCPIOContext.DoDisconnected(IOBuffer: PTCPIOBuffer);
var
  IOIndex: Integer;
  IOStatus: Int64;
  ErrDesc: string;
begin
// dxm 2018.11.3
// 如果IO正常，则通信套接字可重用，否则不可重用

  IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
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

    IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
    IOStatus := IOStatus and IO_STATUS_DEL_READ_IO[IOIndex];
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

    IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO[IOIndex]);

//{$IfDef DEBUG}
//    ErrDesc := Format('[%d][%d]<%s.DoDisconnected>[AFTER DEL READ IO %d][FIOStatues] FIOStatus=%x',
//      [ FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        IOIndex,
//        FIOStatus]);
//    FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}

    IOStatus := IOStatus and IO_STATUS_DEL_READ_IO[IOIndex];

//{$IfDef DEBUG}
//    ErrDesc := Format('[%d][%d]<%s.DoDisconnected>[LOCAL][IOStatues] IOStatus=%x',
//      [ FSocket,
//        GetCurrentThreadId(),
//        ClassName,
//        IOStatus]);
//    FOwner.WriteLog(llDebug, ErrDesc);
//{$Endif}

    // dxm 2018.11.28
    // 注释了这些代码
    // 该断开连接IO返回后不管是否有错误，只要没有[READ]即可归还了，
    // 只是如果有[ERROR]则不可重用，否则可重用
//    if HasError(IOStatus) then begin
//      if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
//        FOwner.EnqueueFreeContext(Self);
//      end;
//    end
//    else begin
//      if not HasReadOrReadIO(IOStatus) then begin
//        FOwner.EnqueueFreeContext(Self);
//      end;
//    end;
  end;

  if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
    FOwner.EnqueueFreeContext(Self);
  end;
end;

procedure TTCPIOContext.DoRecved(IOBuffer: PTCPIOBuffer);
var
  IOIndex: Integer;
  Status: DWORD;
  IOStatus: Int64;
  ErrDesc: string;
begin
  IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
  if (IOBuffer^.LastErrorCode <> 0) or
    ((IOBuffer^.OpType = otGraceful) and (IOBuffer^.BytesTransferred > 0)) or
    ((IOBuffer^.OpType = otRead) and (IOBuffer^.BytesTransferred = 0)) then begin
    ErrDesc := Format('[%d][%d]<%s.DoRecved> IO内部错误 [%s:%d] LastErrorCode=%d, OpType=%s, BytesTransferred=%d, SequenceNumber=%d, Status=%s, IOStatus=%x',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        FRemoteIP,
        FRemotePort,
        IOBuffer^.LastErrorCode,
        IO_OPERATION_TYPE_DESC[IOBuffer^.OpType],
        IOBuffer^.BytesTransferred,
        IOBuffer^.SequenceNumber,
        StatusString(),
        FIOStatus]);
    FOwner.WriteLog(llError, ErrDesc);

    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();

    IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
    IOStatus := IOStatus and IO_STATUS_DEL_READ_IO[IOIndex];

    if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
      FOwner.EnqueueFreeContext(Self);
    end;
  end
  else begin
    if IOBuffer^.OpType = otGraceful then begin // 对端优雅关闭
      FStatus := FStatus or $00000020;
      FOwner.EnqueueIOBuffer(IOBuffer);
    end
    else begin
      InterlockedAdd64(FRecvBytes, IOBuffer^.BytesTransferred);
      FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    end;

    IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO[IOIndex]);
    IOStatus := IOStatus and IO_STATUS_DEL_READ_IO[IOIndex];

    if HasError(IOStatus) then begin
      if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then begin
        FOwner.EnqueueFreeContext(Self);
      end;
    end
    else begin
      if not HasReadOrReadIO(IOStatus) then begin
        Status := FStatus;
        TeaAndCigaretteAndMore(IOStatus, Status);

        if Status and $80000040 = $00000040 then begin
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
    end;
  end;
end;

procedure TTCPIOContext.DoSendBufferNotify(const Buffer: TBuffer; Action: TActionType);
begin
  if Action = atDelete then
    Buffer.Free();
end;

procedure TTCPIOContext.DoSent(IOBuffer: PTCPIOBuffer);
var
  iRet: Integer;
//  Status: DWORD; // dxm 2018.12.11
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
    ErrDesc := Format('[%d][%d]<%s.DoSent> IO内部错误 LastErrorCode=%d, OpType=%s, BytesTransferred=%d, SequenceNumber=%d, Status=%s, IOStatus=%x',
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

    IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_WRITE_IO_ADD_ERROR);
    IOStatus := IOStatus and IO_STATUS_DEL_WRITE_IO;
  end
  else begin
    FOwner.EnqueueIOBuffer(IOBuffer);
    SendBusy := InterlockedAdd64(FSendBusy, -BytesTransferred);
    if SendBusy > 0 then begin
      iRet := SendBuffer();
      IOStatus := FSendIOStatus;
      if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin
        ErrDesc := Format('[%d][%d]<%s.DoSent.SendBuffer> LastErrorCode=%d, Status=%s, IOStatus=%x',
          [ FSocket,
            GetCurrentThreadId(),
            ClassName,
            iRet,
            StatusString(),
            FIOStatus]);
        FOwner.WriteLog(llNormal, ErrDesc);
      end;
    end
    else begin
      IOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_WRITE_IO);
      IOStatus := IOStatus and IO_STATUS_DEL_WRITE_IO;
    end;
  end;

  if HasError(IOStatus) or (FStatus and $80000040 = $00000040) then begin
    if not (HasReadOrReadIO(IOStatus) or HasWriteOrWriteIO(IOStatus)) then
      FOwner.EnqueueFreeContext(Self);
  end;
end;

procedure TTCPIOContext.FillProtocol(pHead: PTCPSocketProtocolHead);
begin
  pHead^.R1[0] := 68; // D
  pHead^.R1[1] := 89; // Y
  pHead^.R1[2] := 70; // F

  pHead^.R2[0] := 90; // Z
  pHead^.R2[1] := 81; // Q

//         Crc16 := FCrc16.Compute(FHead, SizeOf(TTCPSocketProtocolHead) - SizeOf(Word), FCrc16.Init);
  pHead^.CRC16 := FCrc16.Compute(pHead, SizeOf(TTCPSocketProtocolHead) - SizeOf(Word), FCrc16.Init);
  pHead^.CRC16 := pHead^.CRC16 xor FCrc16.XorOut;
end;

procedure TTCPIOContext.GetBodyExFileHandle;
var
  iRet: Integer;
  ErrDesc: string;
begin
  if FBodyExInFile then begin // 由Peer指定的保存地址
    if FBodyExFileName <> '' then begin
      if FileExists(FBodyExFileName) then
        FBodyExFileHandle := FileOpen(FBodyExFileName, fmOpenWrite or fmShareExclusive)
      else
        FBodyExFileHandle := FileCreate(FBodyExFileName, fmShareExclusive, 0);
      if FBodyExFileHandle <> INVALID_HANDLE_VALUE then begin
        FileSeek(FBodyExFileHandle, FHead^.LengthEx, 0);
        SetEndOfFile(FBodyExFileHandle);
        FileSeek(FBodyExFileHandle, 0, 0);
        FBodyExUnfilledLength := FHead^.LengthEx;
      end
      else begin
        iRet := GetLastError();
        ErrDesc := Format('[%d][%d]<%s.GetBodyExFileHandle.FileOpen or FileCreate> LastErrorCode=%d',
          [ FSocket,
            GetCurrentThreadId(),
            ClassName,
            iRet]);
        FOwner.WriteLog(llError, ErrDesc);
        Set80000000Error();
      end;
    end
    else begin
      ErrDesc := Format('[%d][%d]<%s.GetBodyExFileHandle> BodyExFileName=""',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName]);
      FOwner.WriteLog(llError, ErrDesc);
      Set80000000Error();
    end;
  end
  else if FHead^.LengthEx + FHeadSize + FHead^.Length > FRecvBytes + FOwner.MultiIOBufferCount * FOwner.BufferSize then begin
    FBodyExInFile := True;
    FBodyExFileName := GetTempFile();
    FBodyExFileHandle := FileCreate(FBodyExFileName, fmShareExclusive, 0);
    if FBodyExFileHandle <> INVALID_HANDLE_VALUE then begin
      FileSeek(FBodyExFileHandle, FHead^.LengthEx, 0);
      SetEndOfFile(FBodyExFileHandle);
      FileSeek(FBodyExFileHandle, 0, 0);
      FBodyExUnfilledLength := FHead^.LengthEx;
      FBodyExToBeDeleted := True;
    end
    else begin
      iRet := GetLastError();
      ErrDesc := Format('[%d][%d]<%s.GetBodyExFileHandle.FileOpen or FileCreate> LastErrorCode=%d',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      FOwner.WriteLog(llError, ErrDesc);
      Set80000000Error();
    end;
  end;
end;

procedure TTCPIOContext.GetBodyFileHandle;
var
  iRet: Integer;
  ErrDesc: string;
begin
  if FHead^.Length + FHeadSize > FRecvBytes + FOwner.MultiIOBufferCount * FOwner.BufferSize then begin
    FBodyInFile := True;
    FBodyFileName := GetTempFile();
    FBodyFileHandle := FileCreate(FBodyFileName, fmShareExclusive, 0);
    if FBodyFileHandle <> INVALID_HANDLE_VALUE then begin
      FileSeek(FBodyFileHandle, FHead^.LengthEx, 0);
      SetEndOfFile(FBodyFileHandle);
      FileSeek(FBodyFileHandle, 0, 0);
      FBodyUnfilledLength := FHead^.Length;
    end
    else begin
      iRet := GetLastError();
      ErrDesc := Format('[%d][%d]<%s.GetBodyFileHandle.FileCreate> LastErrorCode=%d',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      FOwner.WriteLog(llError, ErrDesc);
      Set80000000Error();
    end;
  end;
end;

function TTCPIOContext.GetTempFile: string;
begin

end;

procedure TTCPIOContext.HardCloseSocket;
begin
  FStatus := FStatus or $C0000000;
  FOwner.FIOHandle.HardCloseSocket(FSocket);
  FSocket := INVALID_SOCKET;
end;

function TTCPIOContext.HasError(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_NOERROR <> IO_STATUS_NOERROR;
end;

function TTCPIOContext.HasErrorOrReadIO(IOStatus: Int64): Boolean;
begin
  Result := HasError(IOStatus) or HasReadIO(IOStatus);
end;

function TTCPIOContext.HasIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasRead(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_READ <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasReadIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_READ_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasReadOrReadIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_READ_OR_READ_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasWrite(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_WRITE <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasWriteIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_WRITE_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasWriteOrIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_WRITE_OR_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.HasWriteOrWriteIO(IOStatus: Int64): Boolean;
begin
  Result := IOStatus and IO_STATUS_HAS_WRITE_OR_WRITE_IO <> IO_STATUS_EMPTY;
end;

function TTCPIOContext.IsClientIOContext: Boolean;
begin
  Result := FStatus and $20000000 = $20000000;
end;

function TTCPIOContext.IsServerIOContext: Boolean;
begin
  Result := FStatus and $20000000 = $00000000;
end;

procedure TTCPIOContext.ParseAndProcessBody;
begin

end;

procedure TTCPIOContext.ParseAndProcessBodyEx;
begin

end;

procedure TTCPIOContext.ParseProtocol;
var
  IOBuffer: PTCPIOBuffer;
  PC: PAnsiChar;
  buf: PAnsiChar;
  Length: DWORD;
  Unfilled: DWORD;
  ErrDesc: string;

  Crc16: Word;
begin
  // 初始化Protocol结构体
  Unfilled := FHeadSize;
  PC := PAnsiChar(FHead);
  while Unfilled > 0 do begin
    FOutstandingIOs.Pop(IOBuffer);
    buf := IOBuffer^.Buffers[0].buf;
    Inc(buf, IOBuffer^.Position);
    Length := IOBuffer^.BytesTransferred - IOBuffer^.Position;
    if Length <= Unfilled then begin
      Move(buf^, PC^, Length);
      Inc(PC, Length);
      Dec(Unfilled, Length);
      FOwner.EnqueueIOBuffer(IOBuffer);
    end
    else begin
      Move(buf^, PC^, Unfilled);
      IOBuffer^.Position := IOBuffer^.Position + Unfilled;
      // dxm 2018.11.13 忘了将此种情况下的Unfilled归零，从而导致了死循环
      Unfilled := 0;
      FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    end;
  end;

  if FHead^.Version <> VERSION then begin
    ErrDesc := Format('[%d][%d]<%s.ParseProtocol> 客户端版本不符, [%s:%d], [%d:%d]',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        FRemoteIP,
        FRemotePort,
        FHead^.Version,
        VERSION]);
    FOwner.WriteLog(llError, ErrDesc);
    Set80000000Error();
  end;

//  pHead^.R1[0] := 68;
//  pHead^.R1[1] := 89;
//  pHead^.R1[2] := 70;
//
//  pHead^.R2[0] := 90;
//  pHead^.R2[1] := 81;

  if (FHead^.R1[0] <> 68) or
     (FHead^.R1[1] <> 89) or
     (FHead^.R1[2] <> 70) or
     (FHead^.R2[0] <> 90) or
     (FHead^.R2[1] <> 81) then
  begin
    ErrDesc := Format('[%d][%d]<%s.ParseProtocol> 客户端不匹配, [%s:%d]',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        FRemoteIP,
        FRemotePort]);
    FOwner.WriteLog(llError, ErrDesc);
    Set80000000Error();
  end;

  Crc16 := FCrc16.Compute(FHead, SizeOf(TTCPSocketProtocolHead) - SizeOf(Word), FCrc16.Init);
  Crc16 := Crc16 xor FCrc16.XorOut;
  if Crc16 <> FHead^.CRC16 then begin
    ErrDesc := Format('[%d][%d]<%s.ParseProtocol> Crc16不匹配, [%s:%d], [%d~%d]',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        FRemoteIP,
        FRemotePort,
        FHead^.CRC16,
        Crc16]);
    FOwner.WriteLog(llError, ErrDesc);
    Set80000000Error();
  end;
end;

function TTCPIOContext.RecvBuffer: Int64;
var
  I: Integer;
  iRet: Integer;
  ErrDesc: string;
  IOCount: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
begin
  IOCount := Ceil((FHeadSize + FHead^.Length + FHead^.LengthEx - FRecvBytes) / FOwner.FBufferSize);
  IOCount := IfThen(IOCount > FOwner.FMultiIOBufferCount, FOwner.FMultiIOBufferCount, IOCount);

  InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ);
  for I := 0 to IOCount - 1 do begin
    IOBuffer := FOwner.DequeueIOBuffer();
    IOBuffer^.Context := Self;
    buf := FOwner.FBufferPool.AllocateBuffer();
    IOBuffer^.Buffers[0].buf := buf;
    IOBuffer^.Buffers[0].len := FOwner.FBufferSize;
    IOBuffer^.BufferCount := 1;

    IOBuffer^.OpType := otRead;
    if I = IOCount - 1 then
      IOBuffer^.Flags := 0
    else
      IOBuffer^.Flags := MSG_WAITALL;

    IOBuffer^.SequenceNumber := FNextSequence;
    Inc(FNextSequence);

    IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
    InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ_IO[IOIndex]);

    iRet := FOwner.IOHandle.PostRecv(FSocket, IOBuffer);
    if (iRet <> 0) and (iRet <> WSA_IO_PENDING)  then begin
      // 输出日志
      ErrDesc := Format('[%d][%d]<%s.RecvBuffer.PostRecv> LastErrorCode=%d, Status=%s',
        [ FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet,
          StatusString()]);
      FOwner.WriteLog(llError, ErrDesc);
      // 归还当前IOBuffer
      FOwner.EnqueueIOBuffer(IOBuffer);
      Set80000000Error();
      InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
      Break;
    end;
  end;

  Result := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ);
  Result := Result and IO_STATUS_DEL_READ;
end;

function TTCPIOContext.RecvDisconnect: Int64;
var
  iRet: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  // 投递读IO以等待客户端优雅关闭
  IOBuffer := FOwner.DequeueIOBuffer();
  IOBuffer^.Context := Self;
  buf := FOwner.FBufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FOwner.FBufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.OpType := {otRead}otGraceful;
  IOBuffer^.SequenceNumber := FNextSequence;
  Inc(FNextSequence);

  InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ);
  IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
  InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ_IO[IOIndex]);

  iRet := FOwner.IOHandle.PostRecv(FSocket, IOBuffer);
  if (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin // 失败，套接字应丢弃
    // 输出日志
    ErrDesc := Format('[%d][%d]<%s.RecvDisconnect.PostRecv> LastErrorCode=%d, Status=%s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        iRet,
        StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    // 归还IOBuffer
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();

    InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
  end;

  Result := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ);
  Result := Result and IO_STATUS_DEL_READ;
end;

function TTCPIOContext.RecvProtocol: Int64;
var
  iRet: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  IOBuffer := FOwner.DequeueIOBuffer();
  IOBuffer^.Context := Self;
  buf := FOwner.FBufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FOwner.FBufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.OpType := otRead;
  IOBuffer^.SequenceNumber := FNextSequence;
  Inc(FNextSequence);

  FIOStatus := FIOStatus or IO_STATUS_ADD_READ;
  IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
  FIOStatus := FIOStatus or IO_STATUS_ADD_READ_IO[IOIndex];

  iRet := FOwner.IOHandle.PostRecv(FSocket, IOBuffer);
  if  (iRet <> 0) and (iRet <> WSA_IO_PENDING) then begin // 失败，套接字应丢弃
    // 输出日志
    ErrDesc := Format('[%d][%d]<%s.RecvProtocol.PostRecv> LastErrorCode=%d, Status=%s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        iRet,
        StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    FOwner.EnqueueIOBuffer(IOBuffer);
    Set80000000Error();

    InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
  end;

  Result := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ);
  Result := Result and IO_STATUS_DEL_READ;
end;

function TTCPIOContext.SendBuffer: Integer;
var
  I: Integer;
  len: DWORD;
  IOBuffer: PTCPIOBuffer;
  ibuf: TBuffer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  I := 0;
  len := 0;
  IOBuffer := FOwner.DequeueIOBuffer();
  while (FSendBuffers.Count > 0) and (I < FOwner.FMultiIOBufferCount) do begin
    buf := FOwner.FBufferPool.AllocateBuffer();
    IOBuffer^.Buffers[I].buf := buf;
    IOBuffer^.Buffers[I].len := FOwner.FBufferSize;
    ibuf := FSendBuffers.GetValue(0);
    len := len + ibuf.GetBuffer(IOBuffer^.Buffers[I].buf + len, IOBuffer^.Buffers[I].len - len);
    while len < IOBuffer^.Buffers[I].len do begin
      ibuf := FSendBuffers.Dequeue();
      ibuf.Free();
      if FSendBuffers.Count > 0 then begin
        ibuf := FSendBuffers.GetValue(0);
        len := len + ibuf.GetBuffer(IOBuffer^.Buffers[I].buf + len, IOBuffer^.Buffers[I].len - len);
      end else
        break;
    end;

    IOBuffer^.Buffers[I].len := len;

    len := 0;
    Inc(I);
  end;
  IOBuffer^.BufferCount := I;
  IOBuffer^.Context := Self;
  IOBuffer^.Flags := 0;
  IOBuffer^.OpType := otWrite;

  InterlockedOr64(FIOStatus, IO_STATUS_ADD_WRITE_WRITE_IO);
  Result := FOwner.IOHandle.PostSend(FSocket, IOBuffer);
  if (Result <> 0) and (Result <> WSA_IO_PENDING) then begin
    // 输出日志
    ErrDesc := Format('[%d][%d]<%s.SendBuffer.PostSend> LastErrorCode=%d, Status=%s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        Result,
        StatusString()]);
    FOwner.WriteLog(llNormal, ErrDesc);
    // 归还当前IOBuffer
    FOwner.EnqueueIOBuffer(IOBuffer);

    Set80000000Error();
    FSendIOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_WRITE_WRITE_IO_ADD_ERROR);
    // dxm 2018.11.28
    FSendIOStatus := FSendIOStatus and IO_STATUS_DEL_WRITE_WRITE_IO;
  end
  else begin
    FSendIOStatus := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_WRITE);
    // dxm 2018.11.28
    FSendIOStatus := FSendIOStatus and IO_STATUS_DEL_WRITE;
  end;

  if HasError(FSendIOStatus) or (FStatus and $80000040 = $00000040) then begin
    if not (HasReadOrReadIO(FSendIOStatus) or HasWriteOrWriteIO(FSendIOStatus)) then begin
      FOwner.EnqueueFreeContext(Self);
    end;
  end;
end;

function TTCPIOContext.SendDisconnect: Int64;
var
  iRet: Integer;
  IOBuffer: PTCPIOBuffer;
  IOIndex: Integer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  IOBuffer := FOwner.DequeueIOBuffer();
  IOBuffer^.Context := Self;
  buf := FOwner.FBufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FOwner.FBufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.OpType := otDisconnect;
  // dxm 2018.11.10 居然忘了设置这个位，又是2小时过去了...
  IOBuffer^.Flags := TF_REUSE_SOCKET;
  IOBuffer^.SequenceNumber := FNextSequence;
  Inc(FNextSequence);

  InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ);
  IOIndex := IOBuffer^.SequenceNumber mod IO_STATUS_READ_CAPACITY;
  InterlockedOr64(FIOStatus, IO_STATUS_ADD_READ_IO[IOIndex]);

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

    InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ_IO_ADD_ERROR[IOIndex]);
  end;

  // dxm 2018.11.10 14:20 由于将InterlockedAnd64写成InterlockedAdd64，直接废掉半天，教训啊！！！
  Result := InterlockedAnd64(FIOStatus, IO_STATUS_DEL_READ);
  Result := Result and IO_STATUS_DEL_READ;
end;

function TTCPIOContext.SendToPeer(Body: PAnsiChar; Length: DWORD; BodyEx: TStream; LengthEx, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := LengthEx;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(ByteBuf);

    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(Body, Length);
    FSendBuffers.EnqueueEx(ByteBuf);

    StreamBuf := TStreamBuffer.Create();
    StreamBuf.SetBuffer(BodyEx);
    FSendBuffers.EnqueueEx(StreamBuf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + LengthEx);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.SendToPeer(Body: PAnsiChar; Length: DWORD; FilePath: string; Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  FileHandle: THandle;
  FileLength: Int64;
  FileBuf: TFileBuffer;
  SendBusy: Int64;
begin
  Result := 0;

  FileHandle := FileOpen(FilePath, fmOpenRead or fmShareDenyWrite);
  if FileHandle <> INVALID_HANDLE_VALUE then begin
    FileLength := FileSeek(FileHandle, 0, 2);

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := FileLength;

    FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    FSendBuffers.Lock();
    try
      ByteBuf := TByteBuffer.Create();
      ByteBuf.SetBuffer(pHead, FHeadSize);
      FSendBuffers.EnqueueEx(ByteBuf);

      ByteBuf := TByteBuffer.Create();
      ByteBuf.SetBuffer(Body, Length);
      FSendBuffers.EnqueueEx(ByteBuf);

      FileBuf := TFileBuffer.Create();
      FileBuf.SetBuffer(FileHandle, FileLength);
      FSendBuffers.EnqueueEx(FileBuf);
    finally
      FSendBuffers.Unlock();
    end;

    SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + FileLength);
    if SendBusy - FHeadSize - Length - FileLength = 0 then
      Result:= SendBuffer();
  end
  else begin
    FreeMem(Body, Length);
    Result := GetLastError();
  end;
end;

function TTCPIOContext.SendToPeer(Body: PAnsiChar; Length, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := 0;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    buf := TByteBuffer.Create();
    buf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(buf);

    buf := TByteBuffer.Create();
    buf.SetBuffer(Body, Length);
    FSendBuffers.EnqueueEx(buf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.SendToPeer(Body: PAnsiChar; Length: DWORD; BodyEx: PAnsiChar; LengthEx, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  buf: TByteBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := LengthEx;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    buf := TByteBuffer.Create();
    buf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(buf);

    buf := TByteBuffer.Create();
    buf.SetBuffer(Body, Length);
    FSendBuffers.EnqueueEx(buf);

    buf := TByteBuffer.Create();
    buf.SetBuffer(BodyEx, LengthEx);
    FSendBuffers.EnqueueEx(buf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + LengthEx);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.SendToPeer(Body: TStream; Length: DWORD; BodyEx: TStream;
  LengthEx, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := LengthEx;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(ByteBuf);

    StreamBuf := TStreamBuffer.Create();
    StreamBuf.SetBuffer(Body);
    FSendBuffers.EnqueueEx(StreamBuf);

    StreamBuf := TStreamBuffer.Create();
    StreamBuf.SetBuffer(BodyEx);
    FSendBuffers.EnqueueEx(StreamBuf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + LengthEx);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.SendToPeer(Body: TStream; Length: DWORD;
  FilePath: string; Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  FileHandle: THandle;
  FileLength: Int64;
  FileBuf: TFileBuffer;
  SendBusy: Int64;
begin
  Result := 0;

  FileHandle := FileOpen(FilePath, fmOpenRead or fmShareDenyWrite);
  if FileHandle <> INVALID_HANDLE_VALUE then begin
    FileLength := FileSeek(FileHandle, 0, 2);

    AHead.Version := VERSION;
    AHead.Options := Options;
    AHead.Length := Length;
    AHead.LengthEx := FileLength;

    FillProtocol(@AHead);

    pHead := AllocMem(FHeadSize);
    Move((@AHead)^, pHead^, FHeadSize);

    FSendBuffers.Lock();
    try
      ByteBuf := TByteBuffer.Create();
      ByteBuf.SetBuffer(pHead, FHeadSize);
      FSendBuffers.EnqueueEx(ByteBuf);

      StreamBuf := TStreamBuffer.Create();
      StreamBuf.SetBuffer(Body);
      FSendBuffers.EnqueueEx(StreamBuf);

      FileBuf := TFileBuffer.Create();
      FileBuf.SetBuffer(FileHandle, FileLength);
      FSendBuffers.EnqueueEx(FileBuf);
    finally
      FSendBuffers.Unlock();
    end;

    SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + FileLength);
    if SendBusy - FHeadSize - Length - FileLength = 0 then
      Result:= SendBuffer();
  end
  else begin
    Body.Free();
    Result := GetLastError();
  end;
end;

function TTCPIOContext.SendToPeer(Body: TStream; Length, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := 0;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(ByteBuf);

    StreamBuf := TStreamBuffer.Create();
    StreamBuf.SetBuffer(Body);
    FSendBuffers.EnqueueEx(StreamBuf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.SendToPeer(Body: TStream; Length: DWORD;
  BodyEx: PAnsiChar; LengthEx, Options: DWORD): Integer;
var
  AHead: TTCPSocketProtocolHead;
  pHead: PAnsiChar;
  ByteBuf: TByteBuffer;
  StreamBuf: TStreamBuffer;
  SendBusy: Int64;
begin
  Result := 0;
  AHead.Version := VERSION;
  AHead.Options := Options;
  AHead.Length := Length;
  AHead.LengthEx := LengthEx;

  FillProtocol(@AHead);

  pHead := AllocMem(FHeadSize);
  Move((@AHead)^, pHead^, FHeadSize);

  FSendBuffers.Lock();
  try
    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(pHead, FHeadSize);
    FSendBuffers.EnqueueEx(ByteBuf);

    StreamBuf := TStreamBuffer.Create();
    StreamBuf.SetBuffer(Body);
    FSendBuffers.EnqueueEx(StreamBuf);

    ByteBuf := TByteBuffer.Create();
    ByteBuf.SetBuffer(BodyEx, LengthEx);
    FSendBuffers.EnqueueEx(ByteBuf);
  finally
    FSendBuffers.Unlock();
  end;

  SendBusy := InterlockedAdd64(FSendBusy, FHeadSize + Length + LengthEx);
  if SendBusy - FHeadSize - Length = 0 then
    Result:= SendBuffer();
end;

function TTCPIOContext.DoSequenceNumCompare(const Value1, Value2: Integer): Integer;
begin
  Result := Value1 - Value2;
end;

procedure TTCPIOContext.Set80000000Error;
begin
  FStatus := FStatus or $80000000;
end;

function TTCPIOContext.StatusString: string;
begin
//00000000,00000000,00000000,00000000 [$00000000][闲置]
//00000000,00000000,00000000,00000001 [$00000001][连接中]
//00000000,00000000,00000000,00000010 [$00000002][已连接]
//00000000,00000000,00000000,00000100 [$00000004][协议头读取]
//00000000,00000000,00000000,00001000 [$00000008][Body已读取]
//00000000,00000000,00000000,00010000 [$00000010][BodyEx已读取]
//00000000,00000000,00000000,00100000 [$00000020][Graceful IO 已返回]
//00000000,00000000,00000000,01000000 [$00000040][DisconnectEx IO 已返回]
//........,........,........,........
//00100000,00000000,00000000,00000000 [$20000000][1:客户端通信套接字][0:服务端通信套接字]
//01000000,00000000,00000000,00000000 [$40000000][套接字已被关闭]
//10000000,00000000,00000000,00000000 [$80000000][出错]
//

  Result := '';
  if FStatus and $00000001 = $00000001 then
    Result := Result + '[连接中]';
  if FStatus and $00000002 = $00000002 then
    Result := Result + '[已连接]';
  if FStatus and $00000004 = $00000004 then
    Result := Result + '[协议头已读取]';
  if FStatus and $00000008 = $00000008 then
    Result := Result + '[Body已读取]';
  if FStatus and $00000010 = $00000010 then
    Result := Result + '[BodyEx已读取]';
  if FStatus and $00000020 = $00000020 then
    Result := Result + '[Graceful IO 已返回]';
  if FStatus and $00000040 = $00000040 then
    Result := Result + '[DisconnectEx IO 已返回]';

  if FStatus and $20000000 = $20000000 then
    Result := Result + '[客户端套接字]'
  else
    Result := Result + '[服务端套接字]';

  if FStatus and $40000000 = $40000000 then
    Result := Result + '[套接字已被关闭]';
  if FStatus and $80000000 = $80000000 then
    Result := Result + '[套接字上有错误]';

  if Result = '' then
    Result := '[闲置]';
end;

procedure TTCPIOContext.WriteBodyExToFile;
var
  IOBuffer: PTCPIOBuffer;
  PC: PAnsiChar;
  Length: DWORD;
begin
  while (FBodyExUnfilledLength > 0) and FOutstandingIOs.Pop(IOBuffer) do begin
    PC := IOBuffer^.Buffers[0].buf;
    Inc(PC, IOBuffer^.Position);
    Length := IOBuffer^.BytesTransferred - IOBuffer^.Position;

    if Length <= FBodyExUnfilledLength then begin
      FileWrite(FBodyExFileHandle, PC^, Length);
      Dec(FBodyExUnfilledLength, Length);
      FOwner.EnqueueIOBuffer(IOBuffer);
    end
    // dxm 2018.11.16
    // [old: 无此分支]
    else begin
      FileWrite(FBodyExFileHandle, PC^, FBodyExUnfilledLength);

      IOBuffer^.Position := IOBuffer^.Position + FBodyExUnfilledLength;
      FBodyExUnfilledLength := 0;
      FOwner.EnqueueIOBuffer(IOBuffer);
    end;
  end;

  if FBodyExUnfilledLength = 0 then begin
    FileClose(FBodyExFileHandle);
    FBodyExFileHandle := INVALID_HANDLE_VALUE;
  end;
end;

procedure TTCPIOContext.WriteBodyToFile;
var
  IOBuffer: PTCPIOBuffer;
  PC: PAnsiChar;
  Length: DWORD;
begin
  while (FBodyUnfilledLength > 0) and FOutstandingIOs.Pop(IOBuffer) do begin
    PC := IOBuffer^.Buffers[0].buf;
    Inc(PC, IOBuffer^.Position);
    Length := IOBuffer^.BytesTransferred - IOBuffer^.Position;

    if Length <= FBodyUnfilledLength then begin
      FileWrite(FBodyFileHandle, PC^, Length);
      Dec(FBodyUnfilledLength, Length);
      FOwner.EnqueueIOBuffer(IOBuffer);
    end
    else begin
      FileWrite(FBodyFileHandle, PC^, FBodyUnfilledLength);
      // dxm 2018.11.16
      // 可能一个buffer=protocol+body+part of bodyex  [old: IOBuffer^.Position := FBodyUnfilledLength;]
      IOBuffer^.Position := IOBuffer^.Position + FBodyUnfilledLength;
      FBodyUnfilledLength := 0;
      FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
    end;
  end;

  if FBodyUnfilledLength = 0 then begin
    FileClose(FBodyFileHandle);
    FBodyFileHandle := INVALID_HANDLE_VALUE;
  end;
end;

{ TTCPIOManager }

function TTCPIOManager.AllocateIOBuffer: PTCPIOBuffer;
begin
  Result := AllocMem(SizeOf(TTCPIOBuffer));
end;

constructor TTCPIOManager.Create;
begin
  FLogNotify := nil;
  FConnectedNotify := nil;
  FRecvedNotify := nil;
  FSentNotify := nil;
  FDisconnectingNotify := nil;
  //\\
  FLogLevel := llNormal;
  FTempDirectory := '';
  FBuffersInUsed := 0;
  //\\
  FHeadSize := SizeOf(TTCPSocketProtocolHead); // 默认值。切记当修改了协议头后一定要修改中这个属性
  FBufferSize := GetPageSize();
  FMultiIOBufferCount := MULTI_IO_BUFFER_COUNT;
  //\\
  FTimeWheel := TTimeWheel<TTCPIOContext>.Create();
// 延迟到派生类的Start函数中创建并初始化
//  FBufferPool := TBufferPool.Create();
//  FBufferPool.Initialize();
//  FIOBuffers := TFlexibleQueue<PTCPIOBuffer>.Create(64);
//  FIOBuffers.OnItemNotify := DoIOBufferNotify;

  FIOHandle := TTCPIOHandle.Create(2 * GetNumberOfProcessors());
end;

function TTCPIOManager.DequeueIOBuffer: PTCPIOBuffer;
begin
  InterlockedIncrement(FBuffersInUsed);
  Result := FIOBuffers.Dequeue();
  if Result = nil then begin
    Result := AllocateIOBuffer();
    ZeroMemory(@Result^.lpOverlapped, SizeOf(OVERLAPPED));
    //\\ dxm 2018.12.04
    SetLength(Result^.Buffers, FMultiIOBufferCount);
    //\\
    Result^.LastErrorCode := 0;
    Result^.CompletionKey := 0;
    Result^.BytesTransferred := 0;
    Result^.BufferCount := 0;
    Result^.Flags := 0;
    Result^.Position := 0;
    Result^.SequenceNumber := 0;
    Result^.OpType := otNode;
    Result^.Context := nil;
  end;
end;

destructor TTCPIOManager.Destroy;
begin
  FIOHandle.Free();
  FTimeWheel.Free();
  inherited;
end;

function TTCPIOManager.DoConnectEx(IOBuffer: PTCPIOBuffer): Boolean;
var
  iRet: Integer;
  ErrDesc: string;
  IOContext: TTCPIOContext;
begin
  // dxm 2018.11.1
  // 1. 判断IO是否出错
  // 2. 初始化套接字上下文
  // 3. 关联通信套接字与IO完成端口

  // dxm 2018.11.13
  // 当ConnectEx重叠IO通知到达时：
  // 1. WSAECONNREFUSED [10061] 通常是对端服务器未启动             [通知时][调用时][正常][可重用]
  // 2. WSAENETUNREACH  [10051] 网络不可达，通常是路由无法探知远端 [通知时][调用时][正常][可重用]
  // 3. WSAETIMEDOUT    [10060] 连接超时                           [通知时][------][正常][可重用][分析：服务端投递的预连接太少，需动态设置预投递上限]

  Result := True;
  IOContext := IOBuffer^.Context;

  if IOBuffer^.LastErrorCode = 0 then begin {$region [IO 正常]}
    // dxm 2018.11.13
    // 激活套接字之前的属性
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
    // 1. WSAECONNREFUSED [10061] 通常是对端服务器未启动             [通知时][调用时][正常][可重用]
    // 2. WSAENETUNREACH  [10051] 网络不可达，通常是路由无法探知远端 [通知时][调用时][正常][可重用]
    // 3. WSAETIMEDOUT    [10060] 连接超时                           [通知时][------][正常][可重用]

    Result := False;
    iRet := IOBuffer^.LastErrorCode;
    if (iRet <> WSAECONNREFUSED) or (iRet <> WSAENETUNREACH) or (iRet <> WSAETIMEDOUT) then
      IOContext.Set80000000Error();

    ErrDesc := Format('[%d][%d]<%s.DoConnectEx> IO内部错误: LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        iRet,
        IOContext.StatusString()]);
    WriteLog(llError, ErrDesc);
  end;

  EnqueueIOBuffer(IOBuffer);
  if not Result then
    EnqueueFreeContext(IOContext);
end;

procedure TTCPIOManager.DoIOBufferNotify(const IOBuffer: PTCPIOBuffer; Action: TActionType);
begin
  if Action = atDelete then
    ReleaseIOBuffer(IOBuffer);
end;

procedure TTCPIOManager.DoIOContextNotify(const IOContext: TTCPIOContext; Action: TActionType);
begin
  if Action = atDelete then
    IOContext.Free();
end;

procedure TTCPIOManager.DoWaitFirstData(IOContext: TTCPIOContext);
var
  iRet: Integer;
  RefCount: Integer;
  OptSeconds: Integer;
  OptLen: Integer;
  IOStatus: Int64;
  ErrDesc: string;
begin
  RefCount := InterlockedDecrement(IOContext.FRefCount);
  if (RefCount = 0) and (IOContext.FSocket <> INVALID_SOCKET) then begin
    OptSeconds := 0;
    OptLen := SizeOf(OptSeconds);
    iRet := getsockopt(IOContext.FSocket, SOL_SOCKET, SO_CONNECT_TIME, @OptSeconds, OptLen);
    if iRet <> 0 then begin
//      IOContext.HardCloseSocket();
    end
    else begin
      IOStatus := InterlockedAdd64(IOContext.FIOStatus, 0);
      if (IOContext.FStatus and $8000007F = $00000003) and // 1000,0000,...,0111,1111
        (IOContext.HasReadIO(IOStatus)) and
        (IOContext.FNextSequence = 1) and
        (OptSeconds >= MAX_FIRSTDATA_TIME - 1) then
      begin
        ErrDesc := Format('[%d][%d]<%s.DoWaitFirstData> [%s:%d] time=%ds',
          [ IOContext.FSocket,
            GetCurrentThreadId(),
            ClassName,
            IOContext.FRemoteIP,
            IOContext.FRemotePort,
            OptSeconds]);
        WriteLog(llWarning, ErrDesc);

        IOContext.HardCloseSocket();
      end;
    end;
  end;
end;

procedure TTCPIOManager.EnqueueFreeContext(AContext: TTCPIOContext);
var
  IOBuffer: PTCPIOBuffer;
{$IfDef DEBUG}
  Msg: string;
{$Endif}
begin
{$IfDef DEBUG}
  Msg := Format('[%d][%d]<%s.EnqueueFreeContext> be to enqueue a free context, Status=%s, IOStatux=%x',
    [ AContext.FSocket,
      GetCurrentThreadId(),
      ClassName,
      AContext.StatusString(),
      AContext.FIOStatus]);
  WriteLog(llDebug, Msg);
{$Endif}

  AContext.FSendBytes := 0;
  AContext.FRecvBytes := 0;
  AContext.FNextSequence := 0;
  AContext.FIOStatus := IO_STATUS_INIT;
  AContext.FSendIOStatus := IO_STATUS_INIT;
  AContext.FSendBusy := 0;

  while AContext.FOutstandingIOs.Pop(IOBuffer) do
    EnqueueIOBuffer(IOBuffer);

  AContext.FSendBuffers.Clear();

  if AContext.FBodyInFile then begin
    if AContext.FBodyFileHandle <> INVALID_HANDLE_VALUE then begin
      FileClose(AContext.FBodyFileHandle);
      AContext.FBodyFileHandle := INVALID_HANDLE_VALUE;
    end;
    DeleteFile(AContext.FBodyFileName);
    AContext.FBodyInFile := False;
  end;

  if AContext.FBodyExInFile then begin
    if AContext.FBodyExToBeDeleted or (AContext.FStatus and $80000000 = $80000000) then begin
      if AContext.FBodyExFileHandle <> INVALID_HANDLE_VALUE then begin
        FileClose(AContext.FBodyExFileHandle);
        AContext.FBodyExFileHandle := INVALID_HANDLE_VALUE;
      end;
      DeleteFile(AContext.FBodyExFileName);
    end;
    AContext.FBodyExInFile := False;
    AContext.FBodyExToBeDeleted := False;
  end;
end;

procedure TTCPIOManager.EnqueueIOBuffer(IOBuffer: PTCPIOBuffer);
var
  I: Integer;
begin
  InterlockedDecrement(FBuffersInUsed);
  // dxm 2018.11.5
  // 1.将IOBuffer携带的内存块归还FBufferPool
  // 2.IOBuffer各成员初始化为默认值
  // 3.将IOBuffer归还FIOBuffers
  for I := 0 to IOBuffer^.BufferCount - 1 do begin
    if IOBuffer^.Buffers[I].buf <> nil then begin
      FBufferPool.ReleaseBuffer(IOBuffer^.Buffers[I].buf);
      IOBuffer^.Buffers[I].buf := nil;
      IOBuffer^.Buffers[I].len := 0;
    end;
  end;

  IOBuffer^.BufferCount := 0;
  IOBuffer^.Context := nil;
  IOBuffer^.LastErrorCode := 0;
  IOBuffer^.CompletionKey := 0;
  IOBuffer^.BytesTransferred := 0;
  IOBuffer^.Position := 0;
  IOBuffer^.SequenceNumber := 0;
  IOBuffer^.Flags := 0;
  IOBuffer^.OpType := otNode;
  ZeroMemory(@IOBuffer^.lpOverlapped,  SizeOf(IOBuffer^.lpOverlapped));
  FIOBuffers.Enqueue(IOBuffer);
end;

function TTCPIOManager.ListenAddr(LocalIP: string; LocalPort: Word): TSocket;
var
  iRet: Integer;
  dwRet: DWORD;
  ErrDesc: string;
  ServerAddr: TSockAddrIn;
begin
  // 创建一个阻塞，重叠模式监听套接字
  Result := WSASocket(PF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
  if Result = INVALID_SOCKET then begin
    iRet := WSAGetLastError();
    ErrDesc := Format('[%d]<%s.ListenAddr.WSASocket> failed with error: %d',
      [ GetCurrentThreadId(),
        ClassName,
        iRet]);
    WriteLog(llFatal, ErrDesc);
    Exit;
  end;

  // set SO_REUSEADDR option

  FillChar(ServerAddr, SizeOf(ServerAddr), #0);
  ServerAddr.sin_family := AF_INET;

  if (LocalIP = '') or (LocalIP = '0.0.0.0') then
    ServerAddr.sin_addr.S_addr := htonl(INADDR_ANY)
  else
    ServerAddr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(LocalIP)));
  ServerAddr.sin_port := htons(LocalPort);

  // 关联本地地址
  if bind(Result, TSockAddr(ServerAddr), SizeOf(ServerAddr)) = SOCKET_ERROR then begin
    iRet := WSAGetLastError();
    CloseSocket(Result);
    Result := INVALID_SOCKET;
    ErrDesc := Format('[%d]<%s.ListenAddr.bind> failed with error: %d',
      [ GetCurrentThreadId(),
        ClassName,
        iRet]);
    WriteLog(llFatal, ErrDesc);
    Exit;
  end;

  // 关联完成端口
  dwRet := FIOHandle.AssociateDeviceWithCompletionPort(Result, 0);
  if dwRet <> 0 then begin
    closesocket(Result);
    Result := INVALID_SOCKET;
    ErrDesc := Format('[%d]<%s.ListenAddr.AssociateDeviceWithCompletionPort> failed with error: %d',
      [ GetCurrentThreadId(),
        ClassName,
        dwRet]);
    WriteLog(llFatal, ErrDesc);
    Exit;
  end;

  // 启动监听
  if listen(Result, 1024) = SOCKET_ERROR then begin
    iRet := WSAGetLastError();
    closesocket(Result);
    Result := INVALID_SOCKET;
    ErrDesc := Format('[%d]<%s.ListenAddr.listen> failed with error: %d',
      [ GetCurrentThreadId(),
        ClassName,
        iRet]);
    WriteLog(llFatal, ErrDesc);
  end;
end;

function TTCPIOManager.PostMultiAccept(IOSocket: TSocket; Count: Integer): Integer;
var
  iRet: Integer;
  ErrDesc: string;
begin
  Result := 0;
  while Count > 0 do begin
    iRet := PostSingleAccept(IOSocket);
    if (iRet = 0) or (iRet = WSA_IO_PENDING) then begin
      Inc(Result);
    end
    else begin
      ErrDesc := Format('[%d][%d]<%s.PostMultiAccept.PostSingleAccept> LastErrorCode=%d',
        [ IOSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      WriteLog(llNormal, ErrDesc);
    end;
    Dec(Count);
  end;
end;

function TTCPIOManager.PostSingleAccept(IOSocket: TSocket): Integer;
var
  IOContext: TTCPIOContext;
  IOBuffer: PTCPIOBuffer;
  buf: PAnsiChar;
  ErrDesc: string;
begin
  // dxm 2018.11.5
  // 如果投递预连接失败，IOBuffer和IOContext可直接回收

  IOContext := DequeueFreeContext($00000000);
  IOContext.FStatus := IOContext.FStatus or $00000001; // [连接中]

  IOBuffer := DequeueIOBuffer();
  buf := FBufferPool.AllocateBuffer();
  IOBuffer^.Buffers[0].buf := buf;
  IOBuffer^.Buffers[0].len := FBufferSize;
  IOBuffer^.BufferCount := 1;
  IOBuffer^.Context := IOContext;
  IOBuffer^.OpType := otConnect;

  Result := FIOHandle.PostAccept(IOSocket, IOBuffer);
  // dxm 2018.11.6
  // if (IOContext.FSocket = INVALID_SOCKET) or (IOContext.FStatus and $80000000 = $80000000) then begin
  // --> if (Result <> 0) and (Result <> WSA_IO_PENDING) then begin
  // 原则是Post系列函数，只做本质工作，其它事情交由调用方处理
  if (Result <> 0) and (Result <> WSA_IO_PENDING) then begin
    if IOContext.FSocket <> INVALID_SOCKET then
      IOContext.Set80000000Error();
    ErrDesc := Format('[%d][%d]<%s.PostSingleAccept.PostAccept> LastErrorCode=%d',
      [ IOSocket,
        GetCurrentThreadId(),
        ClassName,
        Result]);
    WriteLog(llNormal, ErrDesc);
    // 回收IOBuffer
    EnqueueIOBuffer(IOBuffer);
    // 回收通信上下文
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPIOManager.PrepareMultiIOContext(AClass: TTCPIOContextClass; Count: Integer): Integer;
var
  bRet: Boolean;
  ErrDesc: string;
  IOContext: TTCPIOContext;
begin
  Result := 0;
  while Count > 0 do begin
    IOContext := AClass.Create(Self);
    bRet := PrepareSingleIOContext(IOContext);
    if bRet then begin
      Inc(Result);
    end
    else begin
      ErrDesc := Format('[%d]<%s.PostMultiAccept.PrepareSingleIOContext> failed',
        [ GetCurrentThreadId(),
          ClassName]);
      WriteLog(llNormal, ErrDesc);
    end;
    Dec(Count);
    EnqueueFreeContext(IOContext);
  end;
end;

function TTCPIOManager.PrepareSingleIOContext(IOContext: TTCPIOContext): Boolean;
var
  TempAddr: TSockAddrIn;
  iRet: Integer;
  dwRet: DWORD;
  OptVal: Integer;
  ErrDesc: string;
begin
// dxm 2018.11.13
// 传入ConnectEx的通信套接字必须是绑定，非连接的。为此，在使用其进行通信之前，要先绑定，并关联到IOCP
  Result := True;
  if IOContext.FSocket = INVALID_SOCKET then begin
    // dxm 2018.11.2
    // WSAEMFILE  没有可用套接字资源           [致命]
    // WSAENOBUFS 没有可用内存以创建套接字对象 [致命]

    // 上述2个错误显然是[致命]错误
    IOContext.FSocket := WSASocket(
                              AF_INET,
                              SOCK_STREAM,
                              IPPROTO_TCP,
                              nil,
                              0,
                              WSA_FLAG_OVERLAPPED);

    if IOContext.FSocket = INVALID_SOCKET then begin
      Result := False;
      iRet := WSAGetLastError();
      // 输出日志
      ErrDesc := Format('[][%d]<%s.PrepareSingleIOContext.WSASocket> LastErrorCode=%d',
        [ GetCurrentThreadId(),
          ClassName,
          iRet]);
      WriteLog(llFatal, ErrDesc);
      Exit;
    end;

    OptVal := 1;
    iRet := setsockopt(IOContext.FSocket,
                      SOL_SOCKET,
                      SO_REUSEADDR,
                      @OptVal,
                      SizeOf(OptVal));
    if iRet = SOCKET_ERROR then begin
      Result := False;
      iRet := WSAGetLastError();
      // 输出日志
      ErrDesc := Format('[][%d]<%s.PrepareSingleIOContext.setsockopt> LastErrorCode=%d',
        [ GetCurrentThreadId(),
          ClassName,
          iRet]);
      WriteLog(llFatal, ErrDesc);
      IOContext.Set80000000Error();
      Exit;
    end;

    ZeroMemory(@TempAddr, SizeOf(TSockAddrIn));
    TempAddr.sin_family := AF_INET;
    TempAddr.sin_addr.S_addr := htonl(INADDR_ANY);
    TempAddr.sin_port := htons(Word(0));

    // 关联本地地址
    if bind(IOContext.FSocket, TSockAddr(TempAddr), SizeOf(TempAddr)) = SOCKET_ERROR then begin
      Result := False;
      iRet := WSAGetLastError();
      // 输出日志
      ErrDesc := Format('[%d][%d]<%s.PrepareSingleIOContext.bind> LastErrorCode=%d',
        [ IOContext.FSocket,
          GetCurrentThreadId(),
          ClassName,
          iRet]);
      WriteLog(llFatal, ErrDesc);
      IOContext.Set80000000Error();
      Exit;
    end;
  end;

  dwRet := FIOHandle.AssociateDeviceWithCompletionPort(IOContext.FSocket, 0);
  if dwRet <> 0 then begin
    Result := False;
    ErrDesc := Format('[%d][%d]<%s.PrepareSingleIOContext.AssociateDeviceWithCompletionPort> LastErrorCode=%d, Status=%s',
      [ IOContext.FSocket,
        GetCurrentThreadId(),
        ClassName,
        dwRet,
        IOContext.StatusString()]);
    WriteLog(llNormal, ErrDesc);
    IOContext.Set80000000Error();
  end;
end;

procedure TTCPIOManager.ReleaseIOBuffer(IOBuffer: PTCPIOBuffer);
begin
  FreeMem(IOBuffer, SizeOf(TTCPIOBuffer));
end;

procedure TTCPIOManager.SetLogLevel(const Value: TLogLevel);
begin
  FLogLevel := Value;
  FIOHandle.LogLevel := Value;
end;

procedure TTCPIOManager.SetLogNotify(const Value: TLogNotify);
begin
  FLogNotify := Value;
  FIOHandle.OnLogNotify := Value;
end;

procedure TTCPIOManager.SetMultiIOBufferCount(const Value: Integer);
var
  AValue: Integer;
begin
  AValue := Value;
  if Value > IO_STATUS_READ_CAPACITY then
    AValue := IO_STATUS_READ_CAPACITY;
  if Value = 0 then
    AValue := MULTI_IO_BUFFER_COUNT;
  FMultiIOBufferCount := AValue;
end;

procedure TTCPIOManager.SetTempDirectory(const Value: string);
begin
  FTempDirectory := Value;
end;

procedure TTCPIOManager.Start;
begin
  FTimeWheel.Start();
  FIOHandle.Start();
end;

procedure TTCPIOManager.Stop;
begin

end;

procedure TTCPIOManager.WriteLog(LogLevel: TLogLevel; LogContent: string);
begin
  if Assigned(FLogNotify) then begin
    LogContent := '[' + LOG_LEVLE_DESC[LogLevel] + ']' + LogContent;
    FLogNotify(nil, LogLevel, LogContent);
  end;
end;

end.
