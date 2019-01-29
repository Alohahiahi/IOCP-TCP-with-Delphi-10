unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  WinApi.Winsock2, Vcl.Menus, Vcl.Samples.Spin,
  superobject,
  sfLog,
  org.utilities,
  org.tcpip.tcp,
  org.tcpip.tcp.client,
  org.algorithms.time;

type
  TForm2 = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Splitter1: TSplitter;
    Edit1: TEdit;
    Label1: TLabel;
    Edit2: TEdit;
    Label2: TLabel;
    Memo1: TMemo;
    btnEcho: TButton;
    btnStart: TButton;
    btnStop: TButton;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    llFatal1: TMenuItem;
    llError1: TMenuItem;
    llWarnning1: TMenuItem;
    llNormal1: TMenuItem;
    llDebug1: TMenuItem;
    btnUploadFile: TButton;
    Edit4: TEdit;
    Edit3: TEdit;
    SpinEdit1: TSpinEdit;
    GroupBox1: TGroupBox;
    Label3: TLabel;
    Label4: TLabel;
    SpinEdit2: TSpinEdit;
    SpinEdit3: TSpinEdit;
    btnDownload: TButton;
    Edit5: TEdit;
    procedure btnEchoClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure llDebug1Click(Sender: TObject);
    procedure llNormal1Click(Sender: TObject);
    procedure btnUploadFileClick(Sender: TObject);
    procedure Edit4Change(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
    procedure SpinEdit3Change(Sender: TObject);
    procedure llFatal1Click(Sender: TObject);
    procedure llError1Click(Sender: TObject);
    procedure llWarnning1Click(Sender: TObject);
    procedure btnDownloadClick(Sender: TObject);

  private
    FLog: TsfLog;
    FMaxPreIOContextCount: Integer;
    FMultiIOBufferCount: Integer;
    FLogLevel: TLogLevel;
    FTCPClient: TTCPClient;

    FTimeWheel: TTimeWheel<TForm2>;


    procedure DoTestEcho(AForm: TForm2);
    procedure DoTestUploadFile(AForm: TForm2);
    procedure OnLog(Sender: TObject; LogLevel: TLogLevel; LogContent: string);
    procedure OnConnected(Sender: TObject; Context: TTCPIOContext);
    procedure WriteToScreen(const Value: string);
    { Private declarations }
  protected
    procedure WndProc(var MsgRec: TMessage); override;
  public
    { Public declarations }
    procedure StartService;
    procedure StopService;
  end;

var
  Form2: TForm2;

const
  WM_WRITE_LOG_TO_SCREEN = WM_USER + 1;

implementation

uses
  dm.tcpip.tcp.client;

{$R *.dfm}

procedure TForm2.btnDownloadClick(Sender: TObject);
var
  bRet: Boolean;
  ErrDesc: string;
  Parameters: TTCPRequestParameters;
  FileName: string;
  FilePath: string;
  Body: TMemoryStream;
  Length: Integer;
  JO: ISuperObject;
begin
  btnDownload.Enabled := False;
  FilePath := Edit5.Text;
//  FileName := ExtractFileName(FilePath);

  Parameters.RemoteIP := Edit1.Text;
  Parameters.RemotePort := StrToInt(Edit2.Text);

  JO := TSuperObject.Create();
  JO.S['Cmd'] := 'DownloadFile';
  JO.S['SrcLocation'] := FilePath;

{$IfDef DEBUG}
  ErrDesc := Format('[%d]<%s.SendRequest> [DownloadFile] Body=%s, FilePath=%s',
      [ GetCurrentThreadId(),
        ClassName,
        JO.AsJSon(),
        FilePath]);
  OnLog(nil, llDebug, ErrDesc);
{$Endif}

  Body := TMemoryStream.Create();
  Length := JO.SaveTo(Body);

//  bRet := FTCPClient.SendRequest(@Parameters, Body, Length, FilePath, IO_OPTION_NOTIFY_BODYEX_PROGRESS);
  bRet := FTCPClient.SendRequest(@Parameters, Body, Length, IO_OPTION_EMPTY);
  if not bRet then begin
    ErrDesc := Format('[%d]<%s.SendRequest> failed',
      [ GetCurrentThreadId(),
        ClassName]);
    OnLog(nil, llNormal, ErrDesc);
  end;
end;

procedure TForm2.btnEchoClick(Sender: TObject);
var
  bRet: Boolean;
  ErrDesc: string;
  Parameters: TTCPRequestParameters;
  buf: TMemoryStream;
  Msg: string;

  JO: ISuperObject;
  Len: Integer;

  I, nCount: Integer;
begin
  Parameters.RemoteIP := Edit1.Text;
  Parameters.RemotePort := StrToInt(Edit2.Text);
  nCount := SpinEdit1.Value;
  if nCount = 0 then
    nCount := 10;

  for I := 0 to nCount - 1 do begin
    Msg := FormatDateTime('YYYY-MM-DD hh:mm:ss.zzz', Now);
    JO := TSuperObject.Create();
    JO.S['Cmd'] := 'Echo';
    JO.S['Time'] := Msg;
    JO.S['Msg'] := Edit3.Text;

{$IfDef DEBUG}
    ErrDesc := Format('[调试][][%d]<%s.SendRequest> Request=%s',
        [ GetCurrentThreadId(),
          ClassName,
          JO.AsJSon()]);
    OnLog(nil, llDebug, ErrDesc);
{$Endif}

    buf := TMemoryStream.Create();
    Len := JO.SaveTo(buf);

    bRet := FTCPClient.SendRequest(@Parameters, buf, Len, IO_OPTION_EMPTY);
    if not bRet then begin
      ErrDesc := Format('[错误][][%d]<%s.SendRequest> failed',
        [ GetCurrentThreadId(),
          ClassName]);
      OnLog(nil, llError, ErrDesc);
    end;
  end;
end;

procedure TForm2.btnStartClick(Sender: TObject);
begin
  StartService();
end;

procedure TForm2.btnStopClick(Sender: TObject);
begin
  StopService();
end;

procedure TForm2.btnUploadFileClick(Sender: TObject);
var
  bRet: Boolean;
  ErrDesc: string;
  Parameters: TTCPRequestParameters;
  FileName: string;
  FilePath: string;
  Body: TMemoryStream;
  Length: Integer;
  JO: ISuperObject;
begin
  btnUploadFile.Enabled := False;
  FilePath := Edit4.Text;
  FileName := ExtractFileName(FilePath);

  Parameters.RemoteIP := Edit1.Text;
  Parameters.RemotePort := StrToInt(Edit2.Text);

  JO := TSuperObject.Create();
  JO.S['Cmd'] := 'UploadFile';
  JO.S['DstLocation'] := FileName;

{$IfDef DEBUG}
  ErrDesc := Format('[%d]<%s.SendRequest> [UploadFile] Body=%s, FilePath=%s',
      [ GetCurrentThreadId(),
        ClassName,
        JO.AsJSon(),
        FilePath]);
  OnLog(nil, llDebug, ErrDesc);
{$Endif}

  Body := TMemoryStream.Create();
  Length := JO.SaveTo(Body);

  bRet := FTCPClient.SendRequest(@Parameters, Body, Length, FilePath, IO_OPTION_NOTIFY_BODYEX_PROGRESS);
  if not bRet then begin
    ErrDesc := Format('[%d]<%s.SendRequest> failed',
      [ GetCurrentThreadId(),
        ClassName]);
    OnLog(nil, llNormal, ErrDesc);
  end;
end;

procedure TForm2.DoTestEcho(AForm: TForm2);
begin
  AForm.btnEchoClick(nil);
  FTimeWheel.StartTimer(Self, 5 * 60 * 1000, DoTestEcho);
end;

procedure TForm2.DoTestUploadFile(AForm: TForm2);
begin
  AForm.btnUploadFileClick(nil);
  FTimeWheel.StartTimer(Self, 5 * 60 * 1000, DoTestUploadFile);
end;

procedure TForm2.Edit4Change(Sender: TObject);
begin
  btnUploadFile.Enabled := True;
end;

procedure TForm2.FormCreate(Sender: TObject);
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

  FTCPClient := TTCPClient.Create();
  FTCPClient.HeadSize := Sizeof(TTCPSocketProtocolHead);

  FTimeWheel := TTimeWheel<TForm2>.Create();
end;

procedure TForm2.llDebug1Click(Sender: TObject);
begin
  FLogLevel := llDebug;
  FTCPClient.LogLevel := llDebug;
end;

procedure TForm2.llError1Click(Sender: TObject);
begin
  FLogLevel := llError;
  FTCPClient.LogLevel := llError;
end;

procedure TForm2.llFatal1Click(Sender: TObject);
begin
  FLogLevel := llFatal;
  FTCPClient.LogLevel := llFatal;
end;

procedure TForm2.llNormal1Click(Sender: TObject);
begin
  FLogLevel := llNormal;
  FTCPClient.LogLevel := llNormal;
end;

procedure TForm2.llWarnning1Click(Sender: TObject);
begin
  FLogLevel := llWarning;
  FTCPClient.LogLevel := llWarning;
end;

procedure TForm2.OnConnected(Sender: TObject; Context: TTCPIOContext);
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

procedure TForm2.OnLog(Sender: TObject; LogLevel: TLogLevel;
  LogContent: string);
begin
  if LogLevel <= FLogLevel then
    WriteToScreen(LogContent);
  FLog.WriteLog(LogContent);
end;

procedure TForm2.SpinEdit2Change(Sender: TObject);
begin
  FMaxPreIOContextCount := SpinEdit2.Value;
end;

procedure TForm2.SpinEdit3Change(Sender: TObject);
begin
  FMultiIOBufferCount := SpinEdit3.Value;
end;

procedure TForm2.StartService;
var
  Msg: string;
  CurDir: string;
begin
  CurDir := ExtractFilePath(ParamStr(0));
  FMaxPreIOContextCount := SpinEdit2.Value;
  FMultiIOBufferCount := SpinEdit3.Value;
  FTCPClient.LogLevel := FLogLevel;
  FTCPClient.MaxPreIOContextCount := FMaxPreIOContextCount;
  FTCPClient.MultiIOBufferCount := FMultiIOBufferCount;
  FTCPClient.TempDirectory := CurDir + 'Temp\';
  ForceDirectories(FTCPClient.TempDirectory);
  FTCPClient.OnLog := OnLog;
  FTCPClient.OnConnected := OnConnected;
  FTCPClient.RegisterIOContextClass($20000000, TDMTCPClientSocket);
  //\\
  FTCPClient.Start();

  SpinEdit2.Enabled := False;
  SpinEdit3.Enabled := False;

  Msg := Format('基本配置:'#13#10'MaxPreIOContextCount: %d'#13#10'MultiIOBufferCount: %d'#13#10'BufferSize: %d',
    [ FMaxPreIOContextCount,
      FMultiIOBufferCount,
      FTCPClient.BufferSize]);
  Memo1.Lines.Add(Msg);

  FTimeWheel.Start();
//  FTimeWheel.StartTimer(Self, 10 * 1000, DoTestEcho);
//  FTimeWheel.StartTimer(Self, 10 * 1000, DoTestUploadFile);

end;

procedure TForm2.StopService;
begin

end;

procedure TForm2.WndProc(var MsgRec: TMessage);
var
  Msg: string;
begin
  if MsgRec.Msg = WM_WRITE_LOG_TO_SCREEN then begin
    Msg := FormatDateTime('YYYY-MM-DD hh:mm:ss.zzz',Now) + ':' + string(MsgRec.WParam);
    Memo1.Lines.Add(Msg);
  end else
    inherited;
end;

procedure TForm2.WriteToScreen(const Value: string);
begin
  SendMessage(Application.MainForm.Handle,
              WM_WRITE_LOG_TO_SCREEN,
              WPARAM(Value),
              0);
end;

end.
