{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 * Windows Thread API Wrapper
 *}

unit org.utilities.thread;

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TThread = class
  protected
    FTerminated: Boolean;
  public
    procedure DoThreadBegin; virtual; abstract;
    procedure DoThreadEnd; virtual; abstract;
    procedure Execute; virtual; abstract;
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
  end;

  TSingleThread = class(TThread)
  private
    FThreadHandle: THandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure DoThreadBegin; override;
    procedure DoThreadEnd; override;
    procedure Start; override;
    procedure Stop; override;
  end;


  TThreadPool = class(TThread)
  private
    FThreadCount: Integer;
    FWaitThreadCount: Integer;
    FThreadHandles: TWOHandleArray;
    function InnerCreateThread: THandle;
  public
    constructor Create(AThreadCount: Integer = 0);
    destructor Destroy; override;
    procedure DoThreadBegin; override;
    procedure DoThreadEnd; override;
    procedure Start; override;
    procedure Stop; override;
    property ThreadCount: Integer read FThreadCount;
  end;

implementation

uses
  Vcl.Forms;

procedure ThreadProc(AThread: TThread);
begin
  AThread.DoThreadBegin();
  try
    AThread.Execute();
  finally
    AThread.DoThreadEnd();
  end;
end;

{ TThreadPool }

constructor TThreadPool.Create(AThreadCount: Integer);
var
  I: Integer;
begin
  FThreadCount := AThreadCount;
  FWaitThreadCount := AThreadCount;
  FTerminated := False;
//  SetLength(FThreadHandles, FThreadCount);
  for I := 0 to FThreadCount - 1 do
    FThreadHandles[I] := InnerCreateThread();
end;

destructor TThreadPool.Destroy;
begin

  inherited;
end;

procedure TThreadPool.DoThreadBegin;
begin
  InterlockedDecrement(FWaitThreadCount);
end;

procedure TThreadPool.DoThreadEnd;
begin
  InterlockedIncrement(FWaitThreadCount);
end;

function TThreadPool.InnerCreateThread: THandle;
var
  AThreadId: Cardinal;
begin
  Result := System.BeginThread(nil,
                        0,
                        @ThreadProc,
                        Self,
                        CREATE_SUSPENDED,
                        AThreadId);

  if Result = 0 then begin
    raise Exception.CreateFmt('<%s.InnerCreateThread> failed with LastErrCode=%d',[ClassName(), GetLastError()]);
  end;
end;

procedure TThreadPool.Start;
var
  I: Integer;
begin
  for I := 0 to FThreadCount - 1 do begin
    ResumeThread(FThreadHandles[I]);
//    Sleep(50);
  end;

  while FWaitThreadCount > 0 do begin
    Application.ProcessMessages();
    Sleep(10);
  end;
end;

procedure TThreadPool.Stop;
begin
  FTerminated := True;
  while FWaitThreadCount < FThreadCount do begin
    Application.ProcessMessages();
    Sleep(10);
  end;
end;

{ TSingleThread }

constructor TSingleThread.Create;
var
  AThreadId: Cardinal;
begin
  FThreadHandle := 0;
  FTerminated := False;
  FThreadHandle := System.BeginThread(nil,
                        0,
                        @ThreadProc,
                        Self,
                        CREATE_SUSPENDED,
                        AThreadId);

  if FThreadHandle = 0 then begin
    raise Exception.CreateFmt('<%s.Create.BeginThread> failed with LastErrCode=%d',[ClassName(), GetLastError()]);
  end;
end;

destructor TSingleThread.Destroy;
begin
  CloseHandle(FThreadHandle);
  inherited;
end;

procedure TSingleThread.DoThreadBegin;
begin

end;

procedure TSingleThread.DoThreadEnd;
begin

end;

procedure TSingleThread.Start;
begin
  ResumeThread(FThreadHandle);
end;

procedure TSingleThread.Stop;
begin
  FTerminated := True;
end;

end.
