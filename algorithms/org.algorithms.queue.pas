{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 *}

unit org.algorithms.queue;

interface

uses
  WinApi.Windows,
  org.algorithms;

type
  TQueueType = (qtLinked, qtFixed, qtFlexible);

  TLinkedItem<T> = class
  private
    FNext: TLinkedItem<T>;
    FValue: T;
    FValueNotify: TValueNotify<T>;
  public
    constructor Create;
    destructor Destroy; override;
    property Value: T read FValue write FValue;
{$IfDef TEST_ALGORITHMS}
    property Next: TLinkedItem<T> read FNext;
{$Endif}
  end;

  TLinkedQueue<T> = class
  private
    FCS: TRtlCriticalSection;
    FHead: TLinkedItem<T>;
    FTail: TLinkedItem<T>;
    FCount: Integer;
    FValueNotify: TValueNotify<T>;
  public
    constructor Create;
    destructor Destroy; override;
    function Dequeue: TLinkedItem<T>;
    function Empty: Boolean;
    procedure Enqueue(AItem: TLinkedItem<T>; FromHead: Boolean = False);
    procedure Clear;
    property Count: Integer read FCount;
    property OnValueNotify: TValueNotify<T> read FValueNotify write FValueNotify;

{$IfDef TEST_ALGORITHMS}
    property Head: TLinkedItem<T> read FHead;
{$Endif}
  end;

  TFixedQueue<T> = class
  public type
    TArryOfT = array of T;
  private
    FCS: TRtlCriticalSection;
    FCapacity: Integer;
    FCount: Integer;
    FItemArray: TArryOfT;
    FPushIndex: Integer;
    FPopIndex: Integer;
    FItemNotify: TValueNotify<T>;
    function GetCount: Integer;
  public
    constructor Create(Capacity: Integer);
    destructor Destroy; override;
    procedure Clear;
    procedure Lock;
    procedure Unlock;
    function Dequeue: T;
    function DequeueEx: T;
    procedure Enqueue(Item: T); virtual;
    procedure EnqueueEx(Item: T); virtual;
    function Empty: Boolean;
    function GetValue(Index: Integer): T;
    property Count: Integer read GetCount;
    property Capacity: Integer read FCapacity;
    property OnItemNotify: TValueNotify<T> read FItemNotify write FItemNotify;
{$IfDef TEST_ALGORITHMS}
    property PopIndex: Integer read FPopIndex;
    property PushIndex: Integer read FPushIndex;
    property ItemArray: TArryOfT read FItemArray;
{$Endif}

  end;

  TFlexibleQueue<T> = class(TFixedQueue<T>)
  public
    procedure Enqueue(Item: T); override;
    procedure EnqueueEx(Item: T); override;
  end;

const
  QUEUE_TYPE_DESC: array [TQueueType] of string = (
    '链式',
    '定长',
    '变长'
  );

implementation

{ TLinkedItem<T> }

constructor TLinkedItem<T>.Create;
begin

end;

destructor TLinkedItem<T>.Destroy;
begin
  if Assigned(FValueNotify) then
    FValueNotify(FValue, atDelete);
  inherited;
end;

{ TLinkedQueue<T> }

procedure TLinkedQueue<T>.Clear;
var
  AItem: TLinkedItem<T>;
begin
  while FCount > 0 do begin
    AItem := Dequeue();
    AItem.Free();
  end;
  FHead := nil;
  FTail := nil;
end;

constructor TLinkedQueue<T>.Create;
begin
  InitializeCriticalSection(FCS);
  FHead := nil;
  FTail := nil;
end;

function TLinkedQueue<T>.Dequeue: TLinkedItem<T>;
begin
  EnterCriticalSection(FCS);
  try
    if FCount = 0 then
      Result := nil
    else begin
      Result := FHead;
      FHead := FHead.FNext;
      Result.FNext := nil;
      if FHead = nil then
        FTail := nil;
      Dec(FCount);
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

destructor TLinkedQueue<T>.Destroy;
begin
  Clear();
  DeleteCriticalSection(FCS);
  inherited;
end;

function TLinkedQueue<T>.Empty: Boolean;
begin
  Result := FCount = 0;
end;

procedure TLinkedQueue<T>.Enqueue(AItem: TLinkedItem<T>; FromHead: Boolean);
begin
  AItem.FValueNotify := FValueNotify;
  EnterCriticalSection(FCS);
  try
    if FCount = 0 then begin
      FHead := AItem;
      FTail := AItem;
    end else begin
      if not FromHead then begin
        FTail.FNext := AItem;
        FTail := AItem;
      end else begin
        AItem.FNext := FHead;
        FHead := AItem;
      end;
    end;
    Inc(FCount);
  finally
    LeaveCriticalSection(FCS);
  end;
end;

{ TFixedQueue<T> }

procedure TFixedQueue<T>.Clear;
var
  Item: T;
begin
  while FCount > 0 do begin
    Item := Dequeue();
    if Assigned(FItemNotify) then
      FItemNotify(Item, atDelete);
  end;
end;

constructor TFixedQueue<T>.Create(Capacity: Integer);
begin
  InitializeCriticalSection(FCS);
  FCapacity := Capacity;
  SetLength(FItemArray, FCapacity);
  FCount := 0;
  FPushIndex := 0;
  FPopIndex := 0;
end;

function TFixedQueue<T>.Dequeue: T;
begin
  Result := Default(T);
  EnterCriticalSection(FCS);
  try
    if FCount > 0 then begin
      Result := FItemArray[FPopIndex];
      Inc(FPopIndex);
      if FPopIndex = FCapacity then
        FPopIndex := 0;
      Dec(FCount);
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function TFixedQueue<T>.DequeueEx: T;
begin
  Result := Default(T);
  if FCount > 0 then begin
    Result := FItemArray[FPopIndex];
    Inc(FPopIndex);
    if FPopIndex = FCapacity then
      FPopIndex := 0;
    Dec(FCount);
  end;
end;

destructor TFixedQueue<T>.Destroy;
begin
  Clear();
  DeleteCriticalSection(FCS);
  inherited;
end;

function TFixedQueue<T>.Empty: Boolean;
begin
  Result := FCount = 0;
end;

procedure TFixedQueue<T>.Enqueue(Item: T);
begin
  EnterCriticalSection(FCS);
  try
    FItemArray[FPushIndex] := Item;
    Inc(FCount);
    Inc(FPushIndex);
    // 添加后未达当前容量
    if FCount < FCapacity then begin
      if FPushIndex = FCapacity then
        FPushIndex := 0;
    end
    // 添加前容量未满，添加后容量满。下次添加时将覆盖最先入队的元素
    else if FCount = FCapacity then begin
      FPushIndex := FPopIndex;
    end
    // 添加前容量已满。更新PopIndex和PushIndex
    else begin
      FCount := FCapacity;
      if FPushIndex = FCapacity then
        FPushIndex := 0;
      FPopIndex := FPushIndex;
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TFixedQueue<T>.EnqueueEx(Item: T);
begin
  FItemArray[FPushIndex] := Item;
  Inc(FCount);
  Inc(FPushIndex);
  // 添加后未达当前容量
  if FCount < FCapacity then begin
    if FPushIndex = FCapacity then
      FPushIndex := 0;
  end
  // 添加前容量未满，添加后容量满。下次添加时将覆盖最先入队的元素
  else if FCount = FCapacity then begin
    FPushIndex := FPopIndex;
  end
  // 添加前容量已满。更新PopIndex和PushIndex
  else begin
    FCount := FCapacity;
    if FPushIndex = FCapacity then
      FPushIndex := 0;
    FPopIndex := FPushIndex;
  end;
end;

function TFixedQueue<T>.GetCount: Integer;
begin
  EnterCriticalSection(FCS);
  try
    Result := FCount;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

function TFixedQueue<T>.GetValue(Index: Integer): T;
var
  I: Integer;
begin
  Result := Default(T);
  EnterCriticalSection(FCS);
  try
    if (Index >= 0) and (Index < FCount) then begin
      I := FPopIndex + Index;
      if I < FCapacity then
        Result := FItemArray[I]
      else
        Result := FItemArray[I - FCapacity];
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TFixedQueue<T>.Lock;
begin
  EnterCriticalSection(FCS);
end;

procedure TFixedQueue<T>.Unlock;
begin
  LeaveCriticalSection(FCS);
end;

{ TFlexibleQueue<T> }

procedure TFlexibleQueue<T>.Enqueue(Item: T);
var
  PrevCapacity: Integer;
begin
  EnterCriticalSection(FCS);
  try
    FItemArray[FPushIndex] := Item;
    Inc(FCount);
    Inc(FPushIndex);

    if FCount < FCapacity then begin
      if FPushIndex = FCapacity then
        FPushIndex := 0;
    end
    // 添加前容量未满，添加后容量满。需扩容
    else if FCount = FCapacity then begin
      PrevCapacity := FCapacity;
      FCapacity := FCapacity * 2;
      SetLength(FItemArray, FCapacity);
      if FPushIndex < PrevCapacity then begin
        Move(FItemArray[FPopIndex], FItemArray[FPopIndex + PrevCapacity], (PrevCapacity - FPopIndex) * SizeOf(T));
        FPopIndex := FPopIndex + PrevCapacity;
      end;
    end;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TFlexibleQueue<T>.EnqueueEx(Item: T);
var
  PrevCapacity: Integer;
begin
  FItemArray[FPushIndex] := Item;
  Inc(FCount);
  Inc(FPushIndex);

  if FCount < FCapacity then begin
    if FPushIndex = FCapacity then
      FPushIndex := 0;
  end
  // 添加前容量未满，添加后容量满。需扩容
  else if FCount = FCapacity then begin
    PrevCapacity := FCapacity;
    FCapacity := FCapacity * 2;
    SetLength(FItemArray, FCapacity);
    if FPushIndex < PrevCapacity then begin
      Move(FItemArray[FPopIndex], FItemArray[FPopIndex + PrevCapacity], (PrevCapacity - FPopIndex) * SizeOf(T));
      FPopIndex := FPopIndex + PrevCapacity;
    end;
  end;
end;

end.
