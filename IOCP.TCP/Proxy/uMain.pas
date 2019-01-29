unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Samples.Spin,
  sfLog,
  org.utilities,
  org.tcpip.tcp,
  org.tcpip.tcp.proxy,
  dm.tcpip.tcp.proxy;

type
  TForm3 = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Splitter1: TSplitter;
    Memo1: TMemo;
    Label1: TLabel;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Label3: TLabel;
    Edit3: TEdit;
    btnStart: TButton;
    btnStop: TButton;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    Fatal1: TMenuItem;
    Error1: TMenuItem;
    Warning1: TMenuItem;
    Normal1: TMenuItem;
    Debug1: TMenuItem;
    GroupBox1: TGroupBox;
    Label4: TLabel;
    SpinEdit1: TSpinEdit;
    Label5: TLabel;
    SpinEdit2: TSpinEdit;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure Normal1Click(Sender: TObject);
    procedure Debug1Click(Sender: TObject);
    procedure Warning1Click(Sender: TObject);
    procedure Error1Click(Sender: TObject);
    procedure Fatal1Click(Sender: TObject);
    procedure SpinEdit1Change(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
  private
    FLog: TsfLog;
    FLogLevel: TLogLevel;
    FMaxPreAcceptCount: Integer;
    FMultiIOBufferCount: Integer;

    FTCPProxy: TDMTCPProxy;
    procedure OnLog(Sender: TObject; LogLevel: TLogLevel; LogContent: string);
    procedure OnConnected(Sender: TObject; Context: TTCPIOContext);
    procedure WriteToScreen(const Value: string);
  protected
    procedure WndProc(var MsgRec: TMessage); override;
  public
    { Public declarations }
    procedure StartService;
    procedure StopService;
  end;

var
  Form3: TForm3;
const
  WM_WRITE_LOG_TO_SCREEN = WM_USER + 1;

implementation

{$R *.dfm}

procedure TForm3.btnStartClick(Sender: TObject);
begin
  StartService();
end;

procedure TForm3.Debug1Click(Sender: TObject);
begin
  FLogLevel := llDebug;
  FTCPProxy.LogLevel := llDebug;
end;

procedure TForm3.Error1Click(Sender: TObject);
begin
  FLogLevel := llError;
  FTCPProxy.LogLevel := llError;
end;

procedure TForm3.Fatal1Click(Sender: TObject);
begin
  FLogLevel := llFatal;
  FTCPProxy.LogLevel := llFatal;
end;

procedure TForm3.FormCreate(Sender: TObject);
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

  FTCPProxy := TDMTCPProxy.Create();
  FTCPProxy.HeadSize := Sizeof(TTCPSocketProtocolHead);
end;

procedure TForm3.Normal1Click(Sender: TObject);
begin
  FLogLevel := llNormal;
  FTCPProxy.LogLevel := llNormal;
end;

procedure TForm3.OnConnected(Sender: TObject; Context: TTCPIOContext);
var
  Msg: string;
begin
{$IfDef DEBUG}
  Msg := Format('[µ÷ÊÔ][%d][%d]<OnConnected> [%s:%d]',
    [ Context.Socket,
      GetCurrentThreadId(),
      Context.RemoteIP,
      Context.RemotePort]);
  OnLog(nil, llDebug, Msg);
{$Endif}
end;

procedure TForm3.OnLog(Sender: TObject; LogLevel: TLogLevel;
  LogContent: string);
begin
  if LogLevel <= FLogLevel then
    WriteToScreen(LogContent);
  FLog.WriteLog(LogContent);
end;

procedure TForm3.SpinEdit1Change(Sender: TObject);
begin
  FMaxPreAcceptCount := SpinEdit1.Value;
end;

procedure TForm3.SpinEdit2Change(Sender: TObject);
begin
  FMultiIOBufferCount := SpinEdit2.Value;
end;

procedure TForm3.StartService;
var
  Msg: string;
  CurDir: string;
begin
  CurDir := ExtractFilePath(ParamStr(0));
  FMaxPreAcceptCount := SpinEdit1.Value;
  FMultiIOBufferCount := SpinEdit2.Value;
//  FTCPProxy.LocalIP := '0.0.0.0';
  FTCPProxy.LocalPort := StrToInt(Edit3.Text);

  FTCPProxy.LogLevel := FLogLevel;
  FTCPProxy.MaxPreAcceptCount := FMaxPreAcceptCount;
  FTCPProxy.MultiIOBufferCount := FMultiIOBufferCount;
  FTCPProxy.TempDirectory := CurDir + 'Temp\';
  ForceDirectories(FTCPProxy.TempDirectory);
  FTCPProxy.OnLog := OnLog;
  FTCPProxy.OnConnected := OnConnected;
  FTCPProxy.RegisterIOContextClass($00000000, TDMTCPProxyServerClientSocket);
  FTCPProxy.RegisterIOContextClass($20000000, TDMTCPProxyClientSocket);
  FTCPProxy.Start();

  SpinEdit1.Enabled := False;
  SpinEdit2.Enabled := False;
  Edit3.Enabled := False;

  Msg := Format('»ù±¾ÅäÖÃ:'#13#10'MaxPreAcceptCount: %d'#13#10'MultiIOBufferCount: %d'#13#10'BufferSize: %d',
    [ FMaxPreAcceptCount,
      FMultiIOBufferCount,
      FTCPProxy.BufferSize]);
  Memo1.Lines.Add(Msg);
end;

procedure TForm3.StopService;
begin

end;

procedure TForm3.Warning1Click(Sender: TObject);
begin
  FLogLevel := llWarning;
  FTCPProxy.LogLevel := llWarning;
end;

procedure TForm3.WndProc(var MsgRec: TMessage);
var
  Msg: string;
begin
  if MsgRec.Msg = WM_WRITE_LOG_TO_SCREEN then begin
    Msg := FormatDateTime('YYYY-MM-DD hh:mm:ss.zzz',Now) + ':' + string(MsgRec.WParam);
    Memo1.Lines.Add(Msg);
  end else
    inherited;
end;

procedure TForm3.WriteToScreen(const Value: string);
begin
  SendMessage(Application.MainForm.Handle,
              WM_WRITE_LOG_TO_SCREEN,
              WPARAM(Value),
              0);
end;

end.
