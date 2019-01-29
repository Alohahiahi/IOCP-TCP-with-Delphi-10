program IOCPTCPClient;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {Form2},
  dm.tcpip.tcp.client in 'dm.tcpip.tcp.client.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
