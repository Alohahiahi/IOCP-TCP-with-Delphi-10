{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 *}

unit org.tcpip;

interface

uses
  WinApi.Windows,
  WinApi.Winsock2,
  System.SysUtils;

type
//BOOL AcceptEx(
//    _In_ SOCKET sListenSocket,
//    _In_ SOCKET sAcceptSocket,
//    _In_ PVOID lpOutputBuffer,
//    _In_ DWORD dwReceiveDataLength,
//    _In_ DWORD dwLocalAddressLength,
//    _In_ DWORD dwRemoteAddressLength,
//    _Out_ LPDWORD lpdwBytesReceived,
//    _In_ LPOVERLAPPED lpOverlapped
//);

  lpfn_AcceptEx = function (sListenSocket, sAcceptSocket: TSocket;
    lpOutputBuffer: Pointer; dwReceiveDataLength, dwLocalAddressLength,
    dwRemoteAddressLength: DWORD; var lpdwBytesReceived: DWORD;
    lpOverlapped: POverlapped): BOOL; stdcall;
  {$EXTERNALSYM lpfn_AcceptEx}

//void GetAcceptExSockaddrs(
//	_In_ PVOID lpOutputBuffer,
//	_In_ DWORD dwReceiveDataLength,
//	_In_ DWORD dwLocalAddressLength,
//	_In_ DWORD dwRemoteAddressLength,
//	_Out_ LPSOCKADDR *LocalSockaddr,
//	_Out_ LPINT LOcalSockaddrLength,
//	_Out_ LPSOCKADDR *RemtoeSockaddr,
//	_Out_ LPINT RemoteSockaddrLength
//);

  lpfn_GetAcceptExSockaddrs =  procedure (lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var LocalSockaddr: PSockAddr; var LocalSockaddrLength: Integer;
    var RemoteSockaddr: PSockAddr; var RemoteSockaddrLength: Integer); stdcall;
  {$EXTERNALSYM lpfn_GetAcceptExSockaddrs}

//BOOL PASCAL ConnectEx(
//    _In_ SOCKET s,
//    _In_ const struct sockaddr *name,
//    _In_ int namelen,
//    _In_opt_ PVOID lpSendBuffer,
//    _In_ DWORD dwSendDataLength,
//    _Out_ LPWORD lpdwBytesSent,
//    _In_ LPOVERLAPPED lpOverlapped
//);

  lpfn_ConnectEx = function(s: TSocket; const name: PSockAddr; namelen: Integer;
    lpSendBuffer: Pointer; dwSendDataLength: DWORD;
    var lpdwBytesSent: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
  {$EXTERNALSYM lpfn_ConnectEx}

//BOOL DisconnectEx(
//  _In_ SOCKET       hSocket,
//  _In_ LPOVERLAPPED lpOverlapped,
//  _In_ DWORD        dwFlags,
//  _In_ DWORD        reserved
//);

  lpfn_DisConnectEx = function (s: TSocket; lpOverlapped: POverlapped;
    dwFlags: DWORD; reserverd: DWORD): BOOL; stdcall;
  {$EXTERNALSYM lpfn_DisConnectEx}

procedure InitWinsock;
// 成功返回非零值，否则否返回0
function LoadWinsockEx: Integer;
function GetNumberOfProcessors: DWORD;
function GetPageSize: DWORD;

var
  lpfnAcceptEx: lpfn_AcceptEx = nil;
  lpfnGetAcceptExSockaddrs: lpfn_GetAcceptExSockaddrs = nil;
  lpfnConnectEx: lpfn_ConnectEx = nil;
  lpfnDisconnectEx: lpfn_DisConnectEx = nil;

const
//  #define WSAID_ACCEPTEX \
//        {0xb5367df1,0xcbac,0x11cf,{0x95,0xca,0x00,0x80,0x5f,0x48,0xa1,0x92}}

  WSAID_ACCEPTEX: TGUID = (
    D1: $B5367DF1; D2: $CBAC; D3: $11CF; D4: ($95, $CA, $00, $80, $5F, $48, $A1, $92));
  {$EXTERNALSYM WSAID_ACCEPTEX}
//  #define WSAID_GETACCEPTEXSOCKADDRS \
//        {0xb5367df2,0xcbac,0x11cf,{0x95,0xca,0x00,0x80,0x5f,0x48,0xa1,0x92}}

  WSAID_GETACCEPTEXSOCKADDRS: TGUID = (
    D1: $B5367DF2; D2: $CBAC; D3: $11CF; D4: ($95, $CA, $00, $80, $5F, $48, $A1, $92));
  {$EXTERNALSYM WSAID_GETACCEPTEXSOCKADDRS}
//  #define WSAID_CONNECTEX \
//    {0x25a207b9,0xddf3,0x4660,{0x8e,0xe9,0x76,0xe5,0x8c,0x74,0x06,0x3e}}

  WSAID_CONNECTEX: TGUID = (
    D1: $25A207B9; D2: $DDF3; D3: $4660; D4: ($8E, $E9, $76, $E5, $8C, $74, $06, $3E));
  {$EXTERNALSYM WSAID_CONNECTEX}
//  #define WSAID_DISCONNECTEX \
//    {0x7fda2e11,0x8630,0x436f,{0xa0, 0x31, 0xf5, 0x36, 0xa6, 0xee, 0xc1, 0x57}}

  WSAID_DISCONNECTEX: TGUID = (
    D1: $7FDA2E11; D2: $8630; D3: $436F; D4: ($A0, $31, $F5, $36, $A6, $EE, $C1, $57));
  {$EXTERNALSYM WSAID_DISCONNECTEX}

const
  TF_REUSE_SOCKET           = $02;
  {$EXTERNALSYM TF_REUSE_SOCKET}
  SO_UPDATE_ACCEPT_CONTEXT  = $700B;
  {$EXTERNALSYM SO_UPDATE_ACCEPT_CONTEXT}
  SO_UPDATE_CONNECT_CONTEXT = $7010;
  {$EXTERNALSYM SO_UPDATE_CONNECT_CONTEXT}
  SO_CONNECT_TIME           = $700C;
  {$EXTERNALSYM SO_CONNECT_TIME}

const
  VERSION                   = $00; // 0000,0000 如此组合可以产生100个版本
  MULTI_IO_BUFFER_COUNT     = 8;   // 默认一次提交的IOBuffer最大数   [服务端/客户端]
  MAX_PRE_ACCEPT_COUNT      = 64;  // 默认最大预投递连接数           [服务端]
  MAX_PRE_IOCONTEXT_COUNT   = 8;   // 默认客户端启动时准备的套接字数 [客户端]
  MAX_FIRSTDATA_TIME        = 5;   // 连接建立后等待第一次数据时间，单位:秒
implementation

var
  CS: RTL_CRITICAL_SECTION;
  SystemInfo: SYSTEM_INFO;

function GetNumberOfProcessors: DWORD;
begin
  Result := SystemInfo.dwNumberOfProcessors;
end;

function GetPageSize: DWORD;
begin
  Result := SystemInfo.dwPageSize;
end;

procedure InitWinsock;
var
  iRet: Integer;
  data: WSAData;
begin
  iRet := WSAStartup(MakeWord(2, 2), data);
  if iRet <> 0 then
    raise Exception.CreateFmt('WSAStartup failed with error: %d', [WSAGetLastError()]);
end;

function LoadWinsockEx: Integer;
var
  s: TSocket;
  dwBytes: DWORD;
{$J+}
const
  CALL_COUNT: Integer = 0;
{$J-}
begin
  Result := 0;
  EnterCriticalSection(CS);
  if CALL_COUNT = 0 then begin
    s := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
    if s <> INVALID_SOCKET then begin
      if (@lpfnAcceptEx = nil) then begin
        if (SOCKET_ERROR = WSAIoctl(
          s,
          SIO_GET_EXTENSION_FUNCTION_POINTER,
          @WSAID_ACCEPTEX,
          SizeOf(WSAID_ACCEPTEX),
          @@lpfnAcceptEx,
          SizeOf(@lpfnAcceptEx),
          dwBytes,
          nil,
          nil)) or
          (@lpfnAcceptEx = nil) then
        begin
          @lpfnAcceptEx:= nil;
          closesocket(s);
          LeaveCriticalSection(CS);
          Exit;
        end;
      end;

      if (@lpfnGetAcceptExSockAddrs = nil) then begin
        if (SOCKET_ERROR = WSAIoctl(
          s,
          SIO_GET_EXTENSION_FUNCTION_POINTER,
          @WSAID_GETACCEPTEXSOCKADDRS,
          SizeOf(WSAID_GETACCEPTEXSOCKADDRS),
          @@lpfnGetAcceptExSockaddrs,
          SizeOf(@lpfnGetAcceptExSockaddrs),
          dwBytes,
          nil,
          nil)) or
          (@lpfnGetAcceptExSockaddrs = nil) then
        begin
          @lpfnGetAcceptExSockaddrs := nil;
          closesocket(s);
          LeaveCriticalSection(CS);
          Exit;
        end;
      end;

      if (@lpfnConnectEx = nil) then begin
        if (SOCKET_ERROR = WSAIoctl(
          s,
          SIO_GET_EXTENSION_FUNCTION_POINTER,
          @WSAID_CONNECTEX,
          SizeOf(WSAID_CONNECTEX),
          @@lpfnConnectEx,
          SizeOf(@lpfnConnectEx),
          dwBytes,
          nil,
          nil)) or
          (@lpfnConnectEx = nil) then
        begin
          @lpfnConnectEx := nil;
          closesocket(s);
          LeaveCriticalSection(CS);
          Exit;
        end;
      end;

      if (@lpfnDisconnectEx = nil) then begin
        if (SOCKET_ERROR = WSAIoctl(
          s,
          SIO_GET_EXTENSION_FUNCTION_POINTER,
          @WSAID_DISCONNECTEX,
          SizeOf(WSAID_DISCONNECTEX),
          @@lpfnDisconnectEx,
          SizeOf(@lpfnDisconnectEx),
          dwBytes,
          nil,
          nil)) or
          (@lpfnDisconnectEx = nil) then
        begin
          @lpfnDisconnectEx := nil;
          closesocket(s);
          LeaveCriticalSection(CS);
          Exit;
        end;
      end;
    end;
    closesocket(s);
  end;
  Inc(CALL_COUNT);
  LeaveCriticalSection(CS);
  Result := CALL_COUNT;
end;

initialization
  GetSystemInfo(SystemInfo);
  InitializeCriticalSection(CS);

finalization
  DeleteCriticalSection(CS);

end.
