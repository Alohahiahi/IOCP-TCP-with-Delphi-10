unit dm.tcpip.tcp.client;

interface

uses
  System.SysUtils,
  System.Classes,
  WinApi.Windows,
  superobject,
  org.utilities,
  org.algorithms.heap,
  org.tcpip.tcp,
  org.tcpip.tcp.client;

type
  TDMTCPClientSocket = class(TTCPClientSocket)
  protected
    procedure ParseProtocol; override;
    procedure FillProtocol(pHead: PTCPSocketProtocolHead); override;
    procedure ParseAndProcessBody; override;
    procedure ParseAndProcessBodyEx; override;
  end;

implementation

{ TDMTCPClientSocket }

procedure TDMTCPClientSocket.FillProtocol(pHead: PTCPSocketProtocolHead);
begin
  inherited;

end;

procedure TDMTCPClientSocket.ParseAndProcessBody;
var
  IOBuffer: PTCPIOBuffer;
  buf: TMemoryStream;
  PC: PAnsiChar;
  Unfilled: Int64;
  Length: DWORD;
  JO: ISuperObject;
  Cmd: string;

  ErrDesc: string;
begin
  if not FBodyInFile then begin
    Unfilled := FHead^.Length;
    buf := TMemoryStream.Create();
    while (Unfilled > 0) and FOutstandingIOs.Pop(IOBuffer) do begin
      PC := IOBuffer^.Buffers[0].buf;
      Inc(PC, IOBuffer^.Position);
      Length := IOBuffer^.BytesTransferred - IOBuffer^.Position;

      if Length <= Unfilled then begin
        buf.Write(PC^, Length);
        Dec(Unfilled, Length);
        FOwner.EnqueueIOBuffer(IOBuffer);
      end
      else begin
        buf.Write(PC^, Unfilled);
        IOBuffer^.Position := IOBuffer^.Position + Unfilled;
        Unfilled := 0;
        FOutstandingIOs.Push(IOBuffer^.SequenceNumber, IOBuffer);
      end;
    end;

    buf.Seek(0, soBeginning);
    JO := TSuperObject.ParseStream(buf, False);
    buf.Free();

    Cmd := JO.S['Cmd'];

{$IfDef DEBUG}
    ErrDesc := Format('[%d][%d]<%s.ParseAndProcessBody> Peer response Body: %s',
      [ FSocket,
        GetCurrentThreadId(),
        ClassName,
        JO.AsString()]);
    FOwner.WriteLog(llDebug, ErrDesc);
{$Endif}

    if (Cmd = 'Echo') or (Cmd = 'UploadFile')  then begin

    end
    else if Cmd = 'DownloadFile' then begin
      FBodyExInFile := True;
      FBodyExFileName := FOwner.TempDirectory + JO.S['FileName'];
    end;


    // dxm 2018.11.14
    // IO_OPTION_ONCEMORE
    // 1....
    // 2....
    if FHead^.Options and IO_OPTION_ONCEMORE = IO_OPTION_ONCEMORE then begin

    end;

  end
  else begin

  end;


  inherited;
end;

procedure TDMTCPClientSocket.ParseAndProcessBodyEx;
begin
  inherited;

end;

procedure TDMTCPClientSocket.ParseProtocol;
begin
  inherited;

end;

end.
