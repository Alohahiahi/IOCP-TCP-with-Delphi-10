{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 * Windows IOCP API Wrapper
 *}

unit org.utilities.iocp;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  org.utilities,
  org.utilities.thread;

type
  TIOCP = class(TThreadPool)
  private
    FIOCPHandle: THandle;
    FLogLevel: TLogLevel;
    FLogNotify: TLogNotify;
    function CreateNewCompletionPort(dwNumberOfConcurrentThreads: DWORD = 0): THandle;
    procedure SetLogLevel(const Value: TLogLevel);
  protected
    procedure WriteLog(LogLevel: TLogLevel; LogContent: string); virtual;
    procedure ProcessCompletionPacket(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR; lpOverlapped: POverlapped); virtual; abstract;
    procedure DoThreadException(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR; lpOverlapped: POverlapped; E: Exception); virtual; abstract;
  public
    constructor Create(AThreadCount: Integer);
    destructor Destroy; override;
    function AssociateDeviceWithCompletionPort(hDevice: THandle; dwCompletionKey: DWORD): DWORD;
    function PostQueuedCompletionStatus(dwNumOfBytes: DWORD; dwCompletionKey: ULONG_PTR; lpOverlapped: POverlapped): Boolean;
    procedure DoThreadBegin; override;
    procedure DoThreadEnd; override;
    procedure Execute; override;
    procedure Start; override;
    procedure Stop; override;
    property LogLevel: TLogLevel read FLogLevel write SetLogLevel;
    property OnLogNotify: TLogNotify read FLogNotify write FLogNotify;
  end;

implementation

uses
  System.StrUtils,
  System.IniFiles,
  System.Classes,
  REST.Types,
  REST.Json;

{ TIOCP }

function TIOCP.AssociateDeviceWithCompletionPort(hDevice: THandle;
  dwCompletionKey: DWORD): DWORD;
var
  H: THandle;
  ErrDesc: string;
begin
  Result := 0;
  // ��������Ӧ�ô��󣬷���Ҫô�ǲ������������⣬Ҫô�����ƫ��
  // ���������ʱ��Ϊ [����][�������� ]

  // dxm 2018.11.10
  // ERROR_INVALID_PARAMETER[87]
  // ������SOCKETʱ����֣�ֱ�Ӻ��Լ���
  H := CreateIoCompletionPort(hDevice, FIOCPHandle, dwCompletionKey, 0);
  if H <> FIOCPHandle then begin
    Result := GetLastError();
    if Result <> ERROR_INVALID_PARAMETER then begin
      ErrDesc := Format('<%s.AssociateDeviceWithCompletionPort.CreateIoCompletionPort> LastErrorCode=%d', [ClassName, Result]);
      WriteLog(llFatal, ErrDesc);
    end else
      Result := 0;
  end;
end;

constructor TIOCP.Create(AThreadCount: Integer);
begin
  inherited;
  FLogLevel := llWarning;
  FIOCPHandle := CreateNewCompletionPort(AThreadCount div 2);
end;

function TIOCP.CreateNewCompletionPort(dwNumberOfConcurrentThreads: DWORD): THandle;
var
  dwErr: DWORD;
begin
  Result := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, dwNumberOfConcurrentThreads);
  dwErr := GetLastError();
  if Result = 0 then
    raise Exception.CreateFmt('%s.CreateNewCompletionPort.CreateIoCompletionPort> failed with error: %d',
      [ClassName, dwErr]);
end;

destructor TIOCP.Destroy;
begin
  CloseHandle(FIOCPHandle);
  inherited;
end;

procedure TIOCP.DoThreadBegin;
begin
  inherited;
end;

procedure TIOCP.DoThreadEnd;
begin
  inherited;
end;


procedure TIOCP.Execute;
var
  dwNumBytes: DWORD;
  CompletionKey: ULONG_PTR;
  lpOverlapped: POverlapped;
  bRet: LongBool;
  dwError: DWORD;
  ErrDesc: string;
begin
  while not FTerminated do begin
    dwNumBytes := 0;
    CompletionKey := 0;
    lpOverlapped := nil;
    bRet := GetQueuedCompletionStatus(
      FIOCPHandle,
      dwNumBytes,
      CompletionKey,
      lpOverlapped,
      INFINITE);

    dwError := GetLastError();
    // bRet: TRUE -->�ɹ���ȡһ����ɷ�����Ҹ���ɷ������
    //       FALSE-->1. GetQueuedCompletionStatus���ó�����ʱlpOverlapped��Ϊnil
    //               2. �ɹ���ȡһ����ɷ����������ɷ���쳣���쳣�����������lpOverlapped^.Internal��Ա��
    // ������ԣ�
    // GetQueuedCompletionStatus���ó����ɱ�������������������ϲ㴦��
    if bRet or (lpOverlapped <> nil) then begin
      if dwNumBytes <> $FFFFFFFF then begin // {-1}
        try
          ProcessCompletionPacket(dwNumBytes, CompletionKey, lpOverlapped)
        except
          on E:Exception do DoThreadException(dwNumBytes, CompletionKey, lpOverlapped, E);
        end;
      end
      else begin
        ErrDesc := Format('<%s.GetQueuedCompletionStatus> get a terminate completion packet', [ClassName]);
        WriteLog(llWarning, ErrDesc);
        FTerminated := True;
      end;
    end
    else begin
      ErrDesc := Format('<%s.GetQueuedCompletionStatus> failed with error: %d', [ClassName, dwError]);
      WriteLog(llFatal, ErrDesc);
    end;
  end;
end;

function TIOCP.PostQueuedCompletionStatus(dwNumOfBytes: DWORD;
  dwCompletionKey: ULONG_PTR; lpOverlapped: POverlapped): Boolean;
begin
  Result := Winapi.Windows.PostQueuedCompletionStatus(
    FIOCPHandle,
    dwNumOfBytes,
    dwCompletionKey,
    lpOverlapped);
end;

procedure TIOCP.SetLogLevel(const Value: TLogLevel);
begin
//  FLogLevel := Value;
  if Value < llWarning then
    FLogLevel := llWarning
  else
    FLogLevel := Value;
end;

procedure TIOCP.Start;
begin
  inherited;

end;

procedure TIOCP.Stop;
var
  I: Integer;
begin
  for I := 0 to Self.ThreadCount - 1 do begin
    PostQueuedCompletionStatus($FFFFFFFF, 0, nil);
  end;
  inherited;
end;

procedure TIOCP.WriteLog(LogLevel: TLogLevel; LogContent: string);
begin
  if Assigned(FLogNotify) then begin
    LogContent := '[' + LOG_LEVLE_DESC[LogLevel] + ']' + LogContent;
    FLogNotify(nil, LogLevel, LogContent);
  end;
end;

end.
