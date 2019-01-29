unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Samples.Spin, Vcl.ComCtrls,
  sfLog,
  org.utilities,
  org.algorithms.time,
  org.tcpip.tcp,
  org.tcpip.tcp.server,
  dm.tcpip.tcp.server;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Splitter1: TSplitter;
    Memo1: TMemo;
    btnStart: TButton;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    llFatal1: TMenuItem;
    llError1: TMenuItem;
    llWarnning1: TMenuItem;
    llNormal1: TMenuItem;
    llDebug1: TMenuItem;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    SpinEdit1: TSpinEdit;
    Label2: TLabel;
    SpinEdit2: TSpinEdit;
    Label3: TLabel;
    SpinEdit3: TSpinEdit;
    StatusBar1: TStatusBar;
    N2: TMenuItem;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure llNormal1Click(Sender: TObject);
    procedure llDebug1Click(Sender: TObject);
    procedure SpinEdit1Change(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
    procedure llError1Click(Sender: TObject);
    procedure llFatal1Click(Sender: TObject);
    procedure llWarnning1Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
//TLogNotify = procedure (Sender: TObject; LogLevel: TLogLevel; LogContent: string) of object;
//TTCPConnectedNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
//TTCPRecvedNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
//TTCPSentNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
//TTCPDisConnectingNotify = procedure (Sender: TObject; Context: TTCPIOContext) of object;
    FLog: TsfLog;
    FLogLevel: TLogLevel;
    FMaxPreAcceptCount: Integer;
    FMultiIOBufferCount: Integer;

    FTCPServer: TDMTCPServer;
    // 用于更新OnlineCount
    FTimeWheel: TTimeWheel<TForm1>;

    procedure OnLog(Sender: TObject; LogLevel: TLogLevel; LogContent: string);
    procedure OnConnected(Sender: TObject; Context: TTCPIOContext);
    procedure WriteToScreen(const Value: string);
    procedure RefreshOnlineCount(AForm: TForm1);
  protected
    procedure WndProc(var MsgRec: TMessage); override;
  public
    { Public declarations }
    procedure StartService;
    procedure StopService;
  end;

var
  Form1: TForm1;

const
  WM_WRITE_LOG_TO_SCREEN = WM_USER + 1;
  WM_REFRESH_ONLINE_COUNT = WM_USER + 2;
  WM_REFRESH_BUFFERS_IN_USED = WM_USER + 3;

implementation

{$R *.dfm}

{ TForm1 }

procedure TForm1.btnStartClick(Sender: TObject);
begin
  StartService();
end;

procedure TForm1.Button1Click(Sender: TObject);
//var
//  IOContext: TTCPIOContext;
//  Msg: string;
begin
//  FTCPServer.OnlineIOContexts.GetValue()
//  for IOContext in FTCPServer.OnlineIOContexts.Values do begin
//    Msg := Format('[%d] Status=%s, IOStatus=%x',
//      [ IOContext.Socket,
//        IOContext.StatusString(),
//        IOContext.IOStatus]);
//    Memo1.Lines.Add(Msg);
//  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  CurDir: string;
  LogFile: string;
begin
  CurDir := ExtractFilePath(ParamStr(0));

  ForceDirectories(CurDir + 'Log\');
  LogFile := CurDir + 'Log\Log_' + FormatDateTime('YYYYMMDD', Now()) + '.txt';

  FLog := TsfLog.Create(LogFile);
  FLog.AutoLogFileName := True;
  FLog.LogFilePrefix := 'Log_';
  FLogLevel := llNormal;

  FTCPServer := TDMTCPServer.Create();
  FTCPServer.HeadSize := Sizeof(TTCPSocketProtocolHead);

  FTimeWheel := TTimeWheel<TForm1>.Create();
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FTCPServer.Free();
end;

procedure TForm1.llDebug1Click(Sender: TObject);
begin
  FLogLevel := llDebug;
  FTCPServer.LogLevel := llDebug;
end;

procedure TForm1.llError1Click(Sender: TObject);
begin
  FLogLevel := llError;
  FTCPServer.LogLevel := llError;
end;

procedure TForm1.llFatal1Click(Sender: TObject);
begin
  FLogLevel := llFatal;
  FTCPServer.LogLevel := llFatal;
end;

procedure TForm1.llNormal1Click(Sender: TObject);
begin
  FLogLevel := llNormal;
  FTCPServer.LogLevel := llNormal;
end;

procedure TForm1.llWarnning1Click(Sender: TObject);
begin
  FLogLevel := llWarning;
  FTCPServer.LogLevel := llWarning;
end;

procedure TForm1.N2Click(Sender: TObject);
begin
//  StatusBar1.Panels[1].Text := IntToStr(FTCPServer.OnlineIOContexts.Count);
end;

procedure TForm1.SpinEdit1Change(Sender: TObject);
begin
  FMaxPreAcceptCount := SpinEdit1.Value;
end;

procedure TForm1.SpinEdit2Change(Sender: TObject);
begin
  FMultiIOBufferCount := SpinEdit2.Value;
end;

procedure TForm1.StartService;
var
  Msg: string;
  CurDir: string;
begin
  //\\ 初始化
  CurDir := ExtractFilePath(ParamStr(0));
  FMaxPreAcceptCount := SpinEdit1.Value;
  FMultiIOBufferCount := SpinEdit2.Value;
//  FTCPServer.LocalIP := '127.0.0.1';
  FTCPServer.LocalPort := SpinEdit3.Value;
  FTCPServer.LogLevel := FLogLevel;
  FTCPServer.MaxPreAcceptCount := FMaxPreAcceptCount;
  FTCPServer.MultiIOBufferCount := FMultiIOBufferCount;
  FTCPServer.TempDirectory := CurDir + 'Temp\';
  ForceDirectories(FTCPServer.TempDirectory);
  FTCPServer.OnLog := OnLog;
  FTCPServer.OnConnected := OnConnected;
  FTCPServer.RegisterIOContextClass($00000000, TDMTCPServerClientSocket);
  //\\ 启动服务端
  FTCPServer.Start();

  FTimeWheel.Start();

  SpinEdit1.Enabled := False;
  SpinEdit2.Enabled := False;
  SpinEdit3.Enabled := False;

  Msg := Format('基本配置:'#13#10'MaxPreAcceptCount: %d'#13#10'MultiIOBufferCount: %d'#13#10'BufferSize: %d',
    [ FMaxPreAcceptCount,
      FMultiIOBufferCount,
      FTCPServer.BufferSize]);
  Memo1.Lines.Add(Msg);

  FTimeWheel.StartTimer(Form1, 1 * 1000, RefreshOnlineCount);
end;

procedure TForm1.StopService;
begin
  FTCPServer.Stop();
end;

procedure TForm1.WndProc(var MsgRec: TMessage);
var
  Msg: string;
begin
  if MsgRec.Msg = WM_WRITE_LOG_TO_SCREEN then begin
    Msg := FormatDateTime('YYYY-MM-DD hh:mm:ss.zzz',Now) + ':' + string(MsgRec.WParam);
    Memo1.Lines.Add(Msg);
  end
  else if MsgRec.Msg = WM_REFRESH_ONLINE_COUNT then begin
    StatusBar1.Panels[1].Text := IntToStr(FTCPServer.OnlineCount);
    StatusBar1.Panels[3].Text := IntToStr(FTCPServer.BuffersInUsed);
  end else
    inherited;
end;

procedure TForm1.WriteToScreen(const Value: string);
begin
  SendMessage(Application.MainForm.Handle,
              WM_WRITE_LOG_TO_SCREEN,
              WPARAM(Value),
              0);
end;

procedure TForm1.OnConnected(Sender: TObject; Context: TTCPIOContext);
var
  Msg: string;
begin
{$IfDef DEBUG}
  Msg := Format('[调试][%d][%d]<OnConnected> [%s:%d]',
    [ Context.Socket,
      GetCurrentThreadId(),
      Context.RemoteIP,
      Context.RemotePort]);
  OnLog(nil, llDebug, Msg);
{$Endif}
end;

procedure TForm1.OnLog(Sender: TObject; LogLevel: TLogLevel; LogContent: string);
begin
  if LogLevel <= FLogLevel then
    WriteToScreen(LogContent);
  FLog.WriteLog(LogContent);
end;

procedure TForm1.RefreshOnlineCount(AForm: TForm1);
begin
  SendMessage(Application.MainForm.Handle,
              WM_REFRESH_ONLINE_COUNT,
              0,
              0);

  FTimeWheel.StartTimer(AForm, 1 * 1000, RefreshOnlineCount);
end;

end.
