program IOCPTCPProxy;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {Form3},
  dm.tcpip.tcp.proxy in 'dm.tcpip.tcp.proxy.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
