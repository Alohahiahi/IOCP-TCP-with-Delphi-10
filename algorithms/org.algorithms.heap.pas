{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 * @References:
 * Introduction to Algorithms, Second Edition
 *}

unit org.algorithms.heap;

interface

uses
  WinApi.Windows,
  org.algorithms;

type
  THeapType = (htMaximum, htMinimum);

  TBinaryHeap<TKey, TValue> = class
  public type
    TArrayOfKey = array of TKey;
    TArrayOfValue = array of TValue;
  private
    FCS: TRTLCriticalSection;
    FCapacity: Integer;
    function GetCount: Integer;
  protected
    FArrayOfKey: TArrayOfKey;
    FArrayOfValue: TArrayOfValue;
    FCount: Integer;
    FKeyCompare: TValueCompare<TKey>;
    FKeyNotify: TValueNotify<TKey>;
    FValueNotify: TValueNotify<TValue>;
    function Parent(i: Integer): Integer;
    function Left(i: Integer): Integer;
    function Right(i: Integer): Integer;
    // ���±�i��Ӧ�Ľ������Ա������ܻᵼ�¶ѱ��ƻ�
    // �ú������ڻָ��ӶѵĶ����ʣ�ע�⣺�����Ӷѡ�����������϶���
    procedure Heapify(i: Integer); virtual; abstract;
    // �����±�i��Ӧ�Ľ������Ա������ܻᵼ�¶ѱ��ƻ�
    // �ú������ڻָ���(�������±�i��Ӧ���Ӷ�)�Ķ����ʣ�ע�⣺�������Ӷѡ�����������¶���
    procedure ModifyKey(i: Integer; ANewKey: TKey); virtual; abstract;
    // �������еĲ���������ͨ������������������Ա�֤�ѵ����ʣ��Ӿ����������
  public
    constructor Create(ACapacity: Integer);
    destructor Destroy; override;
    // ��������ѹ��һ��ֵAValue�����Ӧ�ļ�ΪAKey
    procedure Push(AKey: TKey; AValue: TValue);
    // �Ӷ�����е�����һ��Ԫ�أ�������������Ӧ��KeyΪ��ǰ��󣬷���Ϊ��ǰ��С
    function Pop(var Value: TValue): Boolean;

    procedure Clear;
//    function GetKey(const Index: Integer): TKey;
//    function GetValue(const Index: Integer): TValue;

    property Count: Integer read {FCount}GetCount;
    property Capacity: Integer read FCapacity;
    // ����ָ�������ԣ����ڱȽ�����Key�Ĵ�С��ϵ
    property OnKeyCompare: TValueCompare<TKey> read FKeyCompare write FKeyCompare;
    property OnKeyNotify: TValueNotify<TKey> read FKeyNotify write FKeyNotify;
    property OnValueNotify: TValueNotify<TValue> read FValueNotify write FValueNotify;
  end;

  TMaxiHeap<TKey, TValue> = class(TBinaryHeap<TKey, TValue>)
  protected
    procedure Heapify(i: Integer); override;
    procedure ModifyKey(i: Integer; ANewKey: TKey); override;
  end;

  TMiniHeap<TKey, TValue> = class(TBinaryHeap<TKey, TValue>)
  protected
    procedure Heapify(i: Integer); override;
    procedure ModifyKey(i: Integer; ANewKey: TKey); override;
  end;

const
  HEAP_TYPE_DESC: array [THeapType] of string = (
    '����',
    '��С��'
  );

implementation

{ TBinaryHeap<TKey, TValue> }

procedure TBinaryHeap<TKey, TValue>.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do begin
    if Assigned(FKeyNotify) then
      FKeyNotify(FArrayOfKey[I], atDelete);
    if Assigned(FValueNotify) then
      FValueNotify(FArrayOfValue[I], atDelete);
  end;
  FCount := 0;
end;

constructor TBinaryHeap<TKey, TValue>.Create(ACapacity: Integer);
begin
  FCapacity := ACapacity;
  SetLength(FArrayOfKey, FCapacity);
  SetLength(FArrayOfValue, FCapacity);
  FCount := 0;
  InitializeCriticalSection(FCS);
end;

destructor TBinaryHeap<TKey, TValue>.Destroy;
begin
  Clear();
  DeleteCriticalSection(FCS);
  inherited;
end;

function TBinaryHeap<TKey, TValue>.GetCount: Integer;
begin
  EnterCriticalSection(FCS);
  try
    Result := FCount;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

//function TBinaryHeap<TKey, TValue>.GetKey(const Index: Integer): TKey;
//begin
//  Result := FArrayOfKey[Index];
//end;

//function TBinaryHeap<TKey, TValue>.GetValue(const Index: Integer): TValue;
//begin
//  Result := FArrayOfValue[Index];
//end;

function TBinaryHeap<TKey, TValue>.Left(i: Integer): Integer;
begin
  Result := 2 * (i + 1) - 1;
end;

function TBinaryHeap<TKey, TValue>.Parent(i: Integer): Integer;
begin
  Result := (i + 1) div 2 - 1;
end;

function TBinaryHeap<TKey, TValue>.Pop(var Value: TValue): Boolean;
begin
  Result := True;
  EnterCriticalSection(FCS);
  try
    if FCount = 0 then
      Result := False
    else begin
      if Assigned(FKeyNotify) then
        FKeyNotify(FArrayOfKey[0], atDelete);
      Value := FArrayOfValue[0];
      FArrayOfKey[0] := FArrayOfKey[FCount - 1];
      FArrayOfValue[0] := FArrayOfValue[FCount - 1];
      Dec(FCount);
      Heapify(0);
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TBinaryHeap<TKey, TValue>.Push(AKey: TKey; AValue: TValue);
begin
  EnterCriticalSection(FCS);
  try
    Inc(FCount);
    if FCount = FCapacity then begin
      FCapacity := 2 * FCapacity;
      SetLength(FArrayOfKey, FCapacity);
      SetLength(FArrayOfValue, FCapacity);
    end;

    FArrayOfKey[FCount - 1] := AKey;
    FArrayOfValue[FCount - 1] := AValue;
    ModifyKey(FCount - 1, AKey);
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function TBinaryHeap<TKey, TValue>.Right(i: Integer): Integer;
begin
  Result := 2 * (i + 1);
end;

{ TMaxiHeap<TKey, TValue> }

procedure TMaxiHeap<TKey, TValue>.Heapify(i: Integer);
var
  l, r: Integer;
  largest: Integer;
  tmpKey: TKey;
  tmpValue: TValue;
begin
  l := Left(i);
  r := Right(i);
  if (l < FCount) and (FKeyCompare(FArrayOfKey[l], FArrayOfKey[i]) > 0) then
    largest := l
  else
    largest := i;
  if (r < FCount) and (FKeyCompare(FArrayOfKey[r], FArrayOfKey[largest]) > 0) then
    largest := r;

  while largest <> i do begin
    tmpKey := FArrayOfKey[i];
    tmpValue := FArrayOfValue[i];
    FArrayOfKey[i] := FArrayOfKey[largest];
    FArrayOfValue[i] := FArrayOfValue[largest];
    FArrayOfKey[largest] := tmpKey;
    FArrayOfValue[largest] := tmpValue;

    i := largest;
    l := Left(i);
    r := Right(i);

    if (l < FCount) and (FKeyCompare(FArrayOfKey[l], FArrayOfKey[i]) > 0) then
      largest := l;
    if (r < FCount) and (FKeyCompare(FArrayOfKey[r], FArrayOfKey[largest]) > 0) then
      largest := r;
  end;
end;

procedure TMaxiHeap<TKey, TValue>.ModifyKey(i: Integer; ANewKey: TKey);
var
  p: Integer;
  tmpKey: TKey;
  tmpValue: TValue;
begin
  if FKeyCompare(ANewKey, FArrayOfKey[i]) >= 0 then begin
    if Assigned(FKeyNotify) then
      FKeyNotify(FArrayOfKey[i], atDelete);
    FArrayOfKey[i] := ANewKey;
    p := Parent(i);
    while (i > 0) and (FKeyCompare(FArrayOfKey[p], FArrayOfKey[i]) < 0) do begin
      tmpKey := FArrayOfKey[i];
      tmpValue := FArrayOfValue[i];
      FArrayOfKey[i] := FArrayofKey[p];
      FArrayOfValue[i] := FArrayOfValue[p];
      FArrayOfKey[p] := tmpKey;
      FArrayOfValue[p] := tmpValue;
      i := p;
      p := Parent(i);
    end;
  end;
end;

{ TMiniHeap<TKey, TValue> }

procedure TMiniHeap<TKey, TValue>.ModifyKey(i: Integer; ANewKey: TKey);
var
  p: Integer;
  tmpKey: TKey;
  tmpValue: TValue;
begin
  if FKeyCompare(ANewKey, FArrayOfKey[i]) <= 0 then begin
    if Assigned(FKeyNotify) then
      FKeyNotify(FArrayOfKey[i], atDelete);
    FArrayOfKey[i] := ANewKey;
    p := Parent(i);
    while (i > 0) and (FKeyCompare(FArrayOfKey[p], FArrayOfKey[i]) > 0) do begin
      tmpKey := FArrayOfKey[i];
      tmpValue := FArrayOfValue[i];
      FArrayOfKey[i] := FArrayofKey[p];
      FArrayOfValue[i] := FArrayOfValue[p];
      FArrayOfKey[p] := tmpKey;
      FArrayOfValue[p] := tmpValue;
      i := p;
      p := Parent(i);
    end;
  end;
end;

procedure TMiniHeap<TKey, TValue>.Heapify(i: Integer);
var
  l, r: Integer;
  smallest: Integer;
  tmpKey: TKey;
  tmpValue: TValue;
begin
  l := Left(i);
  r := Right(i);
  if (l < FCount) and (FKeyCompare(FArrayOfKey[l], FArrayOfKey[i]) < 0) then
    smallest := l
  else
    smallest := i;
  if (r < FCount) and (FKeyCompare(FArrayOfKey[r], FArrayOfKey[smallest]) < 0) then
    smallest := r;

  while smallest <> i do begin
    tmpKey := FArrayOfKey[i];
    tmpValue := FArrayOfValue[i];
    FArrayOfKey[i] := FArrayOfKey[smallest];
    FArrayOfValue[i] := FArrayOfValue[smallest];
    FArrayOfKey[smallest] := tmpKey;
    FArrayOfValue[smallest] := tmpValue;

    i := smallest;
    l := Left(i);
    r := Right(i);

    if (l < FCount) and (FKeyCompare(FArrayOfKey[l], FArrayOfKey[i]) < 0) then
      smallest := l;
    if (r < FCount) and (FKeyCompare(FArrayOfKey[r], FArrayOfKey[smallest]) < 0) then
      smallest := r;
  end;
end;

end.
