program IOCPTCPServer;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {Form1},
  dm.tcpip.tcp.server in 'dm.tcpip.tcp.server.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
