//2011-06-21 20:57  ����������һ����־������
//�ڲ�����˫�����㷨��д����Ϣ��ʱ����ֱ��д�뵽
//�ڴ��У�Ȼ���̸߳���һ����ʱ���������ڴ��е�����
//д�������ļ��У����濪�������黺���ڴ����,������
//������===��������ģʽ��WriteLog ��д����־���ݣ��������ݵ�������
//TFileStream���󣬽��ڴ��е�����д������������߽�ɫ��
//�����ڲ�����˫���巽ʽ�����������������Ѽ�ĸ���.
//Ҳ��ǿ���Ǹ�˫������е�ʵ��Ӧ��.
//2016/02/15 21:57 �޸��ļ����Զ��޸ģ��̳߳�ͻ����
unit sfLog;

interface

uses
  Windows, Messages,Classes,SysUtils,SyncObjs;

type
  TsfLog=class;
  TOnLogExportFile=procedure(OutFileName:string) of object;
  TOnLogException=procedure(Sender:TsfLog;const E:Exception) of object;

  TsfLog=class(TThread)
  private
    FLF:Ansistring;//#13#10;
    FS:TFileStream;
    FHWnd:THandle;
    FCurFileName:Ansistring;
    FFileName:Ansistring;
    FBegCount:DWord;
    FBuffA,FBuffB:TMemoryStream;
    FCS:TRTLCriticalSection;
    FCS_FileName:TRTLCriticalSection;
    FLogBuff:TMemoryStream;
    FFileSize:Int64;

    //FOnLogExportFile:TOnLogExportFile;
    FExportHWnd:THandle;
    FExportMsgID:Integer;
    FExportHanding:Boolean;
    FExprotFileName:Ansistring;
    FWriteInterval:DWORD;//��־д�ļ����ʱ��(ms)
    FEndPosition:Integer;//��ǰ�ļ�����ָ��λ��
    FTag:Integer;
    FAutoLogFileName:Boolean;
    FLogFilePrefix:string;
    FOnLogException:TOnLogException;

    procedure WriteToFile();
    function getLogFileName: Ansistring;
    procedure setLogFileName(const Value: Ansistring);
    //\\
    procedure  InnerExportFile(DestFileName:string);
    function getEndPosition: Integer;
    function getFileHandle: THandle;
    //��ʱ��������(ReadLog 2013-03-27 16:22)
    function ReadLog(FilePos:Integer;Buf:Pointer;ReadCount:Integer):Integer;
    procedure SetAutoLogFileName(const Value: Boolean);
    function GetFileSize: Int64;
  protected
    procedure Execute();override;
    procedure WndProc(var MsgRec:TMessage);
  public
    //��־�ļ���,д����(ms),����ߴ�(Byte)
    constructor Create(LogFileName:string;
      pvWriteInterval:DWORD=2000;
      pvBuffSize:DWORD=1024 * 1024;
      NewFile:Boolean=FALSE);virtual;
    destructor  Destroy();override;
      //����ֵ 0���ɹ����ļ�������ɺ󣬷���֪ͨ��Ϣ
    // 1:ϵͳæ����ǰ�и��ļ����Ʋ�����δ���
    // 2:Ҫ�������ļ��뵱ǰд�����־�ļ�ͬ��
    // �˺������̰߳�ȫ,����Ƕ��߳��е��ô˺�������Ҫ���ö˼�ͬ������
    // 2012-08-18 12:17
    //2016/02/15 17:58 ע�͵��˺���(ExportFile)
    //function ExportFile(OutFileName:Ansistring;MsgHandle:THandle;MsgID:Integer):Integer;

    procedure WriteLog(const InBuff:Pointer;InSize:Integer);overload;
    procedure WriteLog(const Msg:Ansistring);overload;
    //\\
    procedure WriteBin(const Msg:Ansistring);overload;
    procedure WriteBin(const InBuff:Pointer;InSize:Integer);overload;
    //\\
    procedure BegingWrite();
    procedure EndWrite();

    procedure WriteBinNoLock(const InBuff:Pointer;InSize:Integer);overload;
    procedure WriteLogNoLock(const InBuff:Pointer;InSize:Integer);

  public
    property FileSize:Int64 read GetFileSize;
    property AutoLogFileName:Boolean read FAutoLogFileName write SetAutoLogFileName;//ÿ���Զ������ļ���
    property FileName:Ansistring read getLogFileName write setLogFileName;
    property EndPosition:Integer read getEndPosition;
    property Tag:Integer read FTag write FTag;
    property FileHandle:THandle read getFileHandle;
    //AutoLogFileName = true ʱLogFilePrex ��Ч
    //LogFileName = Path + LogFilePrefix + YYYYMMDD.Log
    property LogFilePrefix:string read FLogFilePrefix write FLogFilePrefix; //��־�ļ���ǰ׺
    property OnLogException:TOnLogException read FOnLogException write FOnLogException;//2016/02/1517:58 ���
  end;


 (*
  TSrvLog=class(TInterfacedObject,ISrvLog)
  private
    FLog:TsfLog;
    function getLogFileName():PChar;
    procedure setLogFileName(AFileName:PChar);
    procedure WriteLog(const InBuff:Pointer;InSize:Integer);overload;
    procedure FlushBuff();
  public
    constructor Create(LogFileName:Ansistring);
    destructor  Destroy();override;
  end;
  *)

 // function getSrvLogObj(const LogFileName:PChar):ISrvLog;stdcall;
  procedure sfNowToBuf(const OutBuf:PAnsiChar;BufSize:Integer=23);stdcall;

  exports
     sfNowToBuf;
     //getSrvLogObj;

implementation

(*
 function getSrvLogObj(const LogFileName:PChar):ISrvLog;stdcall;
 begin
   Result := TSrvLog.Create(LogFileName) as ISrvLog;
 end;
*)
{ TsfLog }

procedure TsfLog.BegingWrite;
begin
  EnterCriticalSection(FCS);
end;

constructor TsfLog.Create(LogFileName:string;pvWriteInterval:DWORD;pvBuffSize:DWORD;NewFile:Boolean);
begin
  FAutoLogFileName := FALSE;

  if Trim(LogFileName) = '' then
    raise exception.Create('Log FileName not ""');

  inherited Create(TRUE);
  //\\
  FWriteInterval :=  pvWriteInterval;//д����

  InitializeCriticalSection(FCS);  //��ʼ��
  InitializeCriticalSection(FCS_FileName);//��־�ļ���

  Self.FBuffA := TMemoryStream.Create();
  Self.FBuffA.Size := pvBuffSize;//1024 * 1024; //��ʼֵ���Ը�����Ҫ���е���
  ZeroMemory(FBuffA.Memory,FBuffA.Size);

  Self.FBuffB := TMemoryStream.Create();
  Self.FBuffB.Size := pvBuffSize;//1024 * 1024; //��ʼֵ���Ը�����Ҫ���е���
  Self.FLogBuff := Self.FBuffA;
  ZeroMemory(FBuffA.Memory,FBuffA.Size);
  //\\
  if FileExists(LogfileName) and (not NewFile) then
  begin
    FS := TFileStream.Create(LogFileName,fmOpenWrite or fmShareDenyNone);
    FS.Position := FS.Size;
  end
  else begin
    FS := TFileStream.Create(LogFileName,fmCreate);
    FS.Free();
    FS := TFileStream.Create(LogFileName,fmOpenWrite or fmShareDenyNone);
    FS.Position := FS.Size;
  end;

  FFileSize := FS.Size;
  FCurFileName := LogFileName;
  FFileName    := LogFileName;

  FLF  := #13#10;

  //FEvent := TEvent.Create(nil,TRUE,FALSE,'');
  FExportHanding := FALSE;

  FHWnd := classes.AllocateHWnd(WndProc);
  Windows.SetTimer(FHwnd,1001,3000,nil);

  //����ִ��
  Self.Resume();
  //\\
end;

destructor TsfLog.Destroy;
begin
  Windows.KillTimer(FHwnd,1001);
  Terminate();
  Sleep(100);
  WriteToFile();
  FBuffA.Free();
  FBuffB.Free();
  FS.Free();
  DeleteCriticalSection(FCS);
  DeleteCriticalSection(FCS_FileName);
  inherited;
end;

procedure TsfLog.EndWrite;
begin
  LeaveCriticalSection(FCS);
end;

procedure TsfLog.Execute();
//var
//  IsOK:Boolean;
begin
  FBegCount := GetTickCount();
  while(not Terminated) do
  begin
    Sleep(50);
    //2000ms ���Ը����Լ�����Ҫ����������д����̵ļ��
    if (GetTickCount() - FBegCount) >= FWriteInterval then  //Į�� 2000ms
    begin
      try
        WriteToFile();
      except
        on E:Exception do
        begin
          if Assigned(OnLogException) then
            OnLogException(Self,E);
        end;
      end;
      FBegCount := GetTickCount();
    end;
  end;
end;

(*
procedure TsfLog.Execute();
var
  IsOK:Boolean;
begin
  FBegCount := GetTickCount();
  while(not Terminated) do
  begin
    //2000ms ���Ը����Լ�����Ҫ����������д����̵ļ��
    if (GetTickCount() - FBegCount) >= FWriteInterval then  //Į�� 2000ms
    begin
      WriteToFile();
      FBegCount := GetTickCount();
    end
    else begin
      if Assigned(FOnLogExportFile) then //������ǰ����־�ļ�
      begin
        IsOK := TRUE;
        try
          try
            FOnLogExportFile(FExprotFileName);
          except
            IsOK := FALSE;
          end;
        finally
          FExportHanding := FALSE;
          FOnLogExportFile := nil;
          PostMessage(FExportHWnd,FExportMsgID,Integer(IsOK),0);
        end;
      end
      else
        Sleep(50);
    end;
  end;
end;
*)



(*
function TsfLog.ExportFile(OutFileName: Ansistring; MsgHandle: THandle;
  MsgID: Integer): Integer;
begin
  Result := 0;
  if FExportHanding then
  begin
    Result := 1; //ϵͳæ
    Exit;
  end;
  //\\
  if UpperCase(OutFileName) = UpperCase(FileName) then
  begin
    Result := 2; //������д�����־�ļ�ͬ��
    Exit;
  end;
  //\\
  FExprotFileName := Copy(OutFileName,1,Length(OutFileName));
  FExportHWnd  := MsgHandle;
  FExportMsgID := MsgID;
  FOnLogExportFile := InnerExportFile; //�߳��е���

end;
*)

function TsfLog.getEndPosition: Integer;
begin
  Windows.InterlockedExchange(Result,FEndPosition);
end;

function TsfLog.getFileHandle: THandle;
begin
  Result := FS.Handle;
end;

function TsfLog.GetFileSize: Int64;
begin
  //
end;

function TsfLog.getLogFileName: Ansistring;
begin
  EnterCriticalSection(FCS_FileName);
  try
    Result := Copy(FCurFileName,1,Length(FCurFileName));
  finally
    LeaveCriticalSection(FCS_FileName);
  end;
end;

procedure TsfLog.InnerExportFile(DestFileName: string);
var
  LogfileName:AnsiString;
begin
  LogfileName := Self.FileName;
  try
    FS.Free();
    //Windows.CopyFile(PWideChar(LogFileName),PWideChar(DestFileName),FALSE);
  finally
    if FileExists(LogfileName) then
    begin
      FS := TFileStream.Create(LogFileName,fmOpenWrite or fmShareDenyNone);
      FS.Position := FS.Size;
    end
    else
      FS := TFileStream.Create(LogFileName,fmCreate or fmShareDenyNone);
  end;
end;

function TsfLog.ReadLog(FilePos: Integer; Buf: Pointer;
  ReadCount: Integer): Integer;
var
  EndPos:Integer;
begin
  if FilePos >= EndPosition then
  begin
    Result := 0;
    Exit;
  end;
  //
  while(TRUE) do
  begin
    if Windows.LockFile(FS.Handle,0,0,FS.Size,0) then
    begin
      try
        FS.Position := FilePos;
        Result := FS.Read(Buf^,ReadCount);
      finally
        Windows.UnlockFile(FS.Handle,0,0,FS.Size,0);
      end;
      Break;
    end;
    Sleep(10);
  end;
end;

procedure TsfLog.SetAutoLogFileName(const Value: Boolean);
begin
  FAutoLogFileName := Value;
end;

procedure TsfLog.setLogFileName(const Value: Ansistring);
begin
  EnterCriticalSection(FCS_FileName);
  try
    FFileName := Copy(Value,1,Length(Value));
  finally
    LeaveCriticalSection(FCS_FileName);
  end;
end;

procedure TsfLog.WriteBin(const Msg: Ansistring);
begin
  WriteBin(Pointer(Msg),Length(Msg));
end;

procedure TsfLog.WndProc(var MsgRec: TMessage);
var
  AFileName:string;
begin
  if MsgRec.Msg = WM_TIMER then
  begin
    if (not Terminated) and AutoLogFileName then
    begin
      EnterCriticalSection(FCS_FileName);
      try
        AFileName := ExtractFilePath(FileName) + LogFilePrefix +  FormatDateTime('YYYYMMDD',Now) + '.TXT';
        AFileName := StringReplace(AFileName,'\\','\',[rfReplaceAll,rfIgnoreCase]);
        FileName := AFileName;
      finally
        LeaveCriticalSection(FCS_FileName);
      end;
    end;
  end
  else inherited;
end;

procedure TsfLog.WriteBin(const InBuff: Pointer; InSize: Integer);
begin
  EnterCriticalSection(FCS);
  try
    FLogBuff.Write(InBuff^,InSize);
  finally
    LeaveCriticalSection(FCS);
  end;
end;


procedure TsfLog.WriteBinNoLock(const InBuff: Pointer; InSize: Integer);
begin
  FLogBuff.Write(InBuff^,InSize);
end;

procedure TsfLog.WriteLog(const Msg: Ansistring);
begin
  WriteLog(Pointer(Msg),Length(Msg));
end;

procedure TsfLog.WriteLogNoLock(const InBuff: Pointer; InSize: Integer);
var
  TimeBuf:array[0..23] of AnsiChar;
begin
  sfNowToBuf(TimeBuf);
  TimeBuf[23] := #32;
  FLogBuff.Write(TimeBuf,24);
  FLogBuff.Write(InBuff^,InSize);
  FLogBuff.Write(FLF[1],2);
end;

procedure TsfLog.WriteLog(const InBuff: Pointer; InSize: Integer);
var
  TimeBuf:array[0..23] of AnsiChar;
begin
  sfNowToBuf(TimeBuf);
  TimeBuf[23] := #32;
  EnterCriticalSection(FCS);
  try
    FLogBuff.Write(TimeBuf,24);
    FLogBuff.Write(InBuff^,InSize);
    FLogBuff.Write(FLF[1],2);
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TsfLog.WriteToFile;
  (*
  procedure WriteBuffToFile(Buf:Pointer;Len:Integer);
  var
    LockSize:Integer;
    dwPos:Integer;
  begin
    dwPos    := FS.Position;
    Windows.InterlockedExchange(FEndPosition,dwPos);
    LockSize := dwPos + Len;
    while(TRUE) do
    begin
      if LockFile(FS.Handle,dwPos,0,LockSize,0) then
      begin
        try
          FS.Write(Buf^,Len);
        finally
          UnLockFile(FS.Handle,dwPos,0,LockSize,0);
        end;
        Break;
      end;
      Sleep(10);
    end;
  end;
  *)
var
  MS:TMemoryStream;
  IsLogFileNameChanged:Boolean;
begin
  EnterCriticalSection(FCS);
  //����������
  try
    MS := nil;
    if FLogBuff.Position > 0 then
    begin
      MS := FLogBuff;
      if FLogBuff = FBuffA then FLogBuff := FBuffB
      else
        FLogBuff := FBuffA;
      FLogBuff.Position := 0;
    end;
  finally
     LeaveCriticalSection(FCS);
  end;
  //\\
  if MS = nil then
    Exit;

  //д���ļ�
  try
    if MS.Position > 0 then
    begin
      //WriteBuffToFile(MS.Memory,MS.Position);
      FS.Write(MS.Memory^,MS.Position);
    end;
  finally
    MS.Position := 0;
  end;

  //����ļ������Ƿ�仯
  EnterCriticalSection(FCS_FileName);
  try
    IsLogFileNameChanged := (Uppercase(FCurFileName) <> UpperCase(FFileName));
    //��־�ļ������޸���
    if IsLogFileNameChanged then
    begin
      FCurFileName :=  FFileName;
      FS.Free();
      if FileExists(FFileName) then
      begin
        FS := TFileStream.Create(FFileName,fmOpenWrite or fmShareDenyNone);
        FS.Position := FS.Size;
      end
      else begin
        //2015-03-12 09:32 �޸�
        FS := TFileStream.Create(FFileName,fmCreate);
        FS.Free();
        FS := TFileStream.Create(FFileName,fmOpenWrite or fmShareDenyNone);
        FS.Position := FS.Size;
      end;
    end;
  finally
    LeaveCriticalSection(FCS_FileName);
  end;
end;


(*
{ TSrvLog }

constructor TSrvLog.Create(LogFileName:string);
begin
  FLog := TsfLog.Create(LogFileName);
end;

destructor TSrvLog.Destroy;
begin
  FLog.Free();
  inherited;
end;

procedure TSrvLog.FlushBuff;
begin
  FLog.WriteToFile();
end;

function TSrvLog.getLogFileName: PChar;
begin
  Result := PChar(FLog.FileName);
end;

procedure TSrvLog.setLogFileName(AFileName: PChar);
begin
  FLog.FileName := AFileName;
end;

procedure TSrvLog.WriteLog(const InBuff: Pointer; InSize: Integer);
begin
  FLog.WriteLog(InBuff,InSize);
end;
*)


//YYYY-MM-DD hh:mm:ss zzz
//OutBuff��������������뱣֤���㹻�ĳ���(����23���ֽڿռ�)
//�����ڲ��������
//2012-02-12 17:15 �޸�
//2012-11-04 17:59 �޸�
procedure sfNowToBuf(const OutBuf:PAnsiChar;BufSize:Integer);

const
   strDay:AnsiString =
    '010203040506070809101112131415161718192021222324252627282930' +
    '313233343536373839404142434445464748495051525354555657585960' +
    '6162636465666768697071727374757677787980'  +
    '81828384858687888990919293949596979899';
   str10:AnsiString = '0123456789';
var
  Year,Month,Day,HH,MM,SS,ZZZ:WORD;
  P:PAnsiChar;
  I,J:Integer;
  SystemTime: TSystemTime;
  lvBuf:array[0..22] of AnsiChar;
begin
  if BufSize <= 0 then
    Exit;

  P := @lvBuf[0];// OutBuff;
  for I := 0 to BufSize - 1 do P[I] := '0';

  GetLocalTime(SystemTime);
   Year  := SystemTime.wYear;
   Month := SystemTime.wMonth;
   Day   := SystemTime.wDay;
   HH    := SystemTime.wHour;
   MM    := SystemTime.wMinute;
   SS    := SystemTime.wSecond;
   ZZZ   := SystemTime.wMilliseconds;

   (*  2012-11-04 17:59
     ZZZ := 0;
     HH  := 0;
     MM  := 0;
     SS := 0;
   *)

    //Year
    I := Year div 1000;
    J := Year mod 1000;
    P^ := str10[I + 1];Inc(P);
    I := J div 100;
    P^ := str10[I + 1];Inc(P);
    I := J mod 100;
    if I > 0 then
    begin
      P^ := strDay[(I - 1) * 2 + 1];Inc(P);
      P^ := strDay[(I - 1) * 2 + 2];Inc(P);
      P^ := '-';Inc(P);
    end
    else begin
       P^ := '0';Inc(P);
       P^ := '0';Inc(P);
      P^ := '-';Inc(P);
   end;

     //Month

    P^ := strDay[(Month - 1) * 2 + 1];Inc(P);
    P^ := strDay[(Month - 1) * 2 + 2];Inc(P);
    P^ := '-';Inc(P);


   //Day
     P^ := strDay[(Day - 1) * 2 + 1];Inc(P);
     P^ := strDay[(Day - 1) * 2 + 2];Inc(P);
     P^ := #32;Inc(P);

  //HH
     if HH > 0 then
     begin
       P^ := strDay[(HH - 1) * 2 + 1];Inc(P);
       P^ := strDay[(HH - 1) * 2 + 2];Inc(P);
     end
     else begin
       P^ := #48;Inc(P);
       P^ := #48;Inc(P);
     end;
     P^ := ':';Inc(P);

    //MM
     if MM > 0 then
     begin
       P^ := strDay[(MM - 1) * 2 + 1];Inc(P);
       P^ := strDay[(MM - 1) * 2 + 2];Inc(P);
     end
     else begin
       P^ := #48;Inc(P);
       P^ := #48;Inc(P);
     end;
     P^ := ':';Inc(P);

    //SS
     if SS > 0 then
     begin
      P^ := strDay[(SS - 1) * 2 + 1];Inc(P);
      P^ := strDay[(SS - 1) * 2 + 2];Inc(P);
     end
     else begin
       P^ := #48;Inc(P);
       P^ := #48;Inc(P);
     end;
     P^ := #32;Inc(P);

     //ZZZ
    Year  := ZZZ div 100;
    Month := ZZZ mod 100;
    P^ := str10[Year + 1];Inc(P);
    if Month > 0 then
    begin
       P^ := strDay[(Month - 1) * 2 + 1];Inc(P);
      P^ := strDay[(Month - 1) * 2 + 2];
    end
    else begin
      P^ := '0';Inc(P);
      P^ := '0';
    end;

  if BufSize >23 then BufSize := 23;
  P := OutBuf;
  for I := 0 to BufSize - 1 do P[I] :=  lvBuf[I]
end;

end.
