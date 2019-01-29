{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.11.25
 * @Brief:
 * @References:
 * Introduction to Algorithms, Second Edition
 * Jean-Philippe BEMPEL aka RDM, The Delphi Container Library
 *}

unit org.algorithms.hashmap;

interface

uses
  Winapi.Windows,
  org.algorithms,
  org.algorithms.tree;

type
  THashFunction = function (Key: Integer): Integer of object;
  THashNextFunction<TKey, TValue> = reference to function (var Node: TNode<TKey,TValue>): Boolean;
  THashMap<TKey, TValue> = class
  public type
    TBuckets = array of TRBTree<TKey,TValue>;
  private
    FCS: TRTLCriticalSection;
    FCapacity: Integer;
    FCount: Integer;
    FBuckets: TBuckets;
    FHashFunction: THashFunction;
    FKeyConvert: TValueConvert<TKey>;
    FKeyCompare: TValueCompare<TKey>;
    FValueCompare: TValueCompare<TValue>;
    FKeyNotify: TValueNotify<TKey>;
    FValueNotify: TValueNotify<TValue>;
    function GetCount: Integer;
    function HashMul(Key: Integer): Integer;
  public
    procedure Clear;
    function ContainsKey(Key: TKey): Boolean;
    function GetValue(Key: TKey): TValue;
    function IsEmpty: Boolean;
    procedure PutValue(Key: TKey; Value: TValue);
    function Remove(Key: TKey): TValue;
    function GetNexter: THashNextFunction<TKey, TValue>;
  public
    constructor Create(Capacity: Integer); overload;
    destructor Destroy; override;
    property HashFunction: THashFunction read FHashFunction write FHashFunction;
    property OnKeyConvert: TValueConvert<TKey> read FKeyConvert write FKeyConvert;
    property OnKeyCompare: TValueCompare<TKey> read FKeyCompare write FKeyCompare;
    property OnValueCompare: TValueCompare<TValue> read FValueCompare write FValueCompare;
    property OnKeyNotify: TValueNotify<TKey> read FKeyNotify write FKeyNotify;
    property OnValueNotify: TValueNotify<TValue> read FValueNotify write FValueNotify;
    property Count: Integer read GetCount;
{$IfDef TEST_ALGORITHMS}
    property Capacity: Integer read FCapacity;
    property Buckets: TBuckets read FBuckets;
{$Endif}
  end;

implementation

{ THashMap<TKey, TValue> }

procedure THashMap<TKey, TValue>.Clear;
var
  I: Integer;
begin
  EnterCriticalSection(FCS);
  try
    for I := 0 to FCapacity - 1 do begin
      if FBuckets[I] <> nil then begin
        FBuckets[I].Free();
        FBuckets[I] := nil;
      end;
    end;
    FCount := 0;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function THashMap<TKey, TValue>.ContainsKey(Key: TKey): Boolean;
var
  Index: Integer;
  Bucket: TRBTree<TKey, TValue>;
begin
  Result := False;
  EnterCriticalSection(FCS);
  try
    Index := FHashFunction(FKeyConvert(Key));
    if FBuckets[Index] <> nil then
      Result := FBuckets[Index].Search(Key) <> nil;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

constructor THashMap<TKey, TValue>.Create(Capacity: Integer);
begin
  FCapacity := Capacity;
  FCount := 0;
  SetLength(FBuckets, FCapacity);
  FHashFunction := HashMul;
  InitializeCriticalSection(FCS);
end;

destructor THashMap<TKey, TValue>.Destroy;
begin
  Clear();
  DeleteCriticalSection(FCS);
  inherited;
end;

function THashMap<TKey, TValue>.GetCount: Integer;
begin
  EnterCriticalSection(FCS);
  try
    Result := FCount;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function THashMap<TKey, TValue>.GetNexter: THashNextFunction<TKey, TValue>;
var
  I: Integer;
  NextNode: TNode<TKey, TValue>;
begin
  I := 0;
  NextNode := nil;
  while (FBuckets[I] = nil) and (I < FCapacity) do Inc(I);
  if I < FCapacity then
    NextNode := FBuckets[I].Minimum(FBuckets[I].Root);

  Result := function (var Node: TNode<TKey,TValue>): Boolean
  begin
    Node := NextNode;
    Result := Node <> nil;
    if Result then begin
      NextNode := FBuckets[I].Successor(NextNode);
      if (NextNode = nil) and (I + 1 < FCapacity) then begin
        Inc(I);
        while (FBuckets[I] = nil) and (I < FCapacity) do Inc(I);
        if I < FCapacity then
          NextNode := FBuckets[I].Minimum(FBuckets[I].Root);
      end;
    end;
  end;
end;

function THashMap<TKey, TValue>.GetValue(Key: TKey): TValue;
var
  Index: Integer;
  Node: TNode<TKey, TValue>;
begin
  Result := Default(TValue);
  EnterCriticalSection(FCS);
  try
    Index := FHashFunction(FKeyConvert(Key));
    if FBuckets[Index] <> nil then begin
      Node := FBuckets[Index].Search(Key);
      if Node <> nil then begin
        Result := Node.Value;
      end;
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function THashMap<TKey, TValue>.HashMul(Key: Integer): Integer;
const
  A = 0.6180339887; // (sqrt(5) - 1) / 2
begin
  Result := Trunc(FCapacity * (Frac(Key * A)));
end;

function THashMap<TKey, TValue>.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

procedure THashMap<TKey, TValue>.PutValue(Key: TKey; Value: TValue);
var
  Index: Integer;
begin
  if FKeyCompare(Key, Default(TKey)) = 0 then Exit;
  if FValueCompare(Value, Default(TValue)) = 0 then Exit;
  EnterCriticalSection(FCS);
  try
    Index := FHashFunction(FKeyConvert(Key));
    if FBuckets[Index] = nil then begin
      FBuckets[Index] := TRBTree<TKey,TValue>.Create();
      FBuckets[Index].OnKeyCompare := FKeyCompare;
      FBuckets[Index].OnKeyNotify := FKeyNotify;
      FBuckets[Index].OnValueNotify := FValueNotify;
    end;
    FBuckets[Index].Insert(Key, Value);
    Inc(FCount);
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function THashMap<TKey, TValue>.Remove(Key: TKey): TValue;
var
  Index: Integer;
  Node: TNode<TKey, TValue>;
begin
  Result := Default(TValue);
  EnterCriticalSection(FCS);
  try
    Index := FHashFunction(FKeyConvert(Key));
    if FBuckets[Index] <> nil then begin
      Node := FBuckets[Index].Search(Key);
      if Node <> nil then begin
        Result := Node.Value;
        FBuckets[Index].Delete(Node);
        if Assigned(FKeyNotify) then
          FKeyNotify(Node.Key, atDelete);
        Node.Free();
        Dec(FCount);
      end;
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

end.
