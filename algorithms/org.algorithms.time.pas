{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.11.18
 * @Brief:
 * @References:
 * Hashed and Hierarchical Timing Wheels: Data Structures for the Efficient Implementation of a Timer Facility
 *}

unit org.algorithms.time;

interface

uses
  Winapi.Windows,
  org.algorithms,
  org.algorithms.queue,
  org.utilities.thread;

type
  TExpireRoutine<T> = procedure (Waiter: T) of object;
  TTimer<T> = class
    Waiter: T;
    ExpireTime: Int64;
    Canceled: Boolean;
    ExpireRoutine: TExpireRoutine<T>;
  end;

  TTimeWheel<T> = class(TSingleThread)
  public const
    DAY_MICROSECONDS: Int64 = 24 * 60 * 60 * 1000;
    HOUR_MICROSECONDS: Int64 = 60 * 60 * 1000;
    MINUTE_MICROSECONDS: Int64 = 60 * 1000;
    SECONDS_MICROSECONDS: Int64 = 1000;
  public type
    PTick = ^TTick;
    TTick = record
      Tick: Integer;
      Second: Integer;
      Minute: Integer;
      Hour: Integer;
      Day: Integer;
      Timer: TTimer<T>
    end;

    TArrayDay = array of TFlexibleQueue<PTick>;
    TArrayHour = array [0..23] of TFlexibleQueue<PTick>;
    TArrayMinute = array [0..59] of TFlexibleQueue<PTick>;
    TArraySecond = array [0..59] of TFlexibleQueue<PTick>;
    TArrayTick = array of TFlexibleQueue<PTick>;
  private
    FArrayDay: TArrayDay;
    FArrayHour: TArrayHour;
    FArrayMinute: TArrayMinute;
    FArraySecond: TArraySecond;
    FArrayTick: TArrayTick;

    FAvaliablePTick: TFlexibleQueue<PTick>;
    FAvaliableTimer: TFlexibleQueue<TTimer<T>>;

    FTick: Integer;  // 定时器精度，(FTick - Ftick div 2, FTick + Ftick div 2)
    FTicksPerSecond: Integer;
    FDays: Integer;
    FCurrentDay: Integer;
    FCurrentHour: Integer;
    FCurrentMinute: Integer;
    FCurrentSecond: Integer;
    FCurrentTick: Integer;

    procedure PerTickBookKeeping;
    procedure SetDays(const Value: Integer);
    procedure SetTick(const Value: Integer);
    procedure OnPTickNotify(const Value: PTick; Action: TActionType);
    procedure OnTimerNotify(const Value: TTimer<T>; Action: TActionType);
    function DequeuePTick: PTick;
    function DequeueTimer: TTimer<T>;
    procedure EnqueuePTick(ATick: PTick);
    procedure EnqueueTimer(ATimer: TTimer<T>);
  public
    constructor Create;
    destructor Destroy; override;
    function StartTimer(AWaiter: T; ExpireTime: Int64; ExpireRoutine: TExpireRoutine<T>): TTimer<T>;
    procedure StopTimer(ATimer: TTimer<T>);

    procedure Execute; override;

    procedure Start; override;
    procedure Stop; override;

    property Tick: Integer read FTick write SetTick;
    property Days: Integer read FDays write SetDays;
  end;

implementation

{ TTimeWheel<T> }

constructor TTimeWheel<T>.Create;
begin
  FTick := TIME_WHEEL_TICK;
  FTicksPerSecond := 1000 div FTick;
  FDays := TIME_WHEEL_DAY;
  FCurrentDay := 0;
  FCurrentHour := 0;
  FCurrentMinute := 0;
  FCurrentSecond := 0;
  FCurrentTick := 0;

  FAvaliablePTick := TFlexibleQueue<PTick>.Create(64);
  FAvaliablePTick.OnItemNotify := OnPTickNotify;
  FAvaliableTimer := TFlexibleQueue<TTimer<T>>.Create(64);
  FAvaliableTimer.OnItemNotify := OnTimerNotify;
  inherited;
end;

destructor TTimeWheel<T>.Destroy;
begin
  FAvaliablePTick.Free();
  FAvaliableTimer.Free();
  inherited;
end;

procedure TTimeWheel<T>.EnqueuePTick(ATick: PTick);
begin
  ATick^.Tick := 0;
  ATick^.Second := 0;
  ATick^.Minute := 0;
  ATick^.Hour := 0;
  ATick^.Day := 0;
  ATick^.Timer := nil;
  FAvaliablePTick.Enqueue(ATick);
end;

procedure TTimeWheel<T>.EnqueueTimer(ATimer: TTimer<T>);
begin
  ATimer.Waiter := Default(T);
  ATimer.ExpireTime := 0;
  ATimer.Canceled := False;
  ATimer.ExpireRoutine := nil;

  FAvaliableTimer.Enqueue(ATimer);
end;

procedure TTimeWheel<T>.Execute;
begin
  Sleep(FTick);
  while not FTerminated do begin
    PerTickBookKeeping();
    Sleep(FTick);
  end;
end;

function TTimeWheel<T>.DequeuePTick: PTick;
begin
  Result := FAvaliablePTick.Dequeue();
  if Result = nil then begin
    Result := AllocMem(SizeOf(TTick));
    Result^.Tick := 0;
    Result^.Second := 0;
    Result^.Minute := 0;
    Result^.Hour := 0;
    Result^.Day := 0;
    Result^.Timer := nil;
  end;
end;

function TTimeWheel<T>.DequeueTimer: TTimer<T>;
begin
  Result := FAvaliableTimer.Dequeue();
  if Result = nil then begin
    Result := TTimer<T>.Create();
    Result.Waiter := Default(T);
    Result.ExpireTime := 0;
    Result.Canceled := False;
    Result.ExpireRoutine := nil;
  end;
end;

procedure TTimeWheel<T>.OnPTickNotify(const Value: PTick; Action: TActionType);
begin
  if Action = atDelete then
    FreeMem(Value);
end;

procedure TTimeWheel<T>.OnTimerNotify(const Value: TTimer<T>;
  Action: TActionType);
begin
  if Action = atDelete then
    Value.Free();
end;

procedure TTimeWheel<T>.PerTickBookKeeping;
var
  ATick: PTick;
  ATimer: TTimer<T>;
begin
  Inc(FCurrentTick);
  FCurrentTick := FCurrentTick mod FTicksPerSecond;
  if FCurrentTick = 0 then begin // 下一秒
    Inc(FCurrentSecond);
    FCurrentSecond := FCurrentSecond mod 60;
    if FCurrentSecond = 0 then begin {$region 下一分}
      Inc(FCurrentMinute);
      FCurrentMinute := FCurrentMinute mod 60;
      if FCurrentMinute = 0 then begin {$Region 下一时}
        Inc(FCurrentHour);
        FCurrentHour := FCurrentHour mod 24;
        if FCurrentHour = 0 then begin {$Region 下一天}
          Inc(FCurrentDay);
          FCurrentDay := FCurrentDay mod FDays;
          // 1.将当天缓存的定时器分发到FArrayHour中去
          // 2.将FArrayHour[FCurrentHour]中的定时器分发到FArrayMinute中去
          // 3.将FArrayMinute[FCurrentMinute]中的定时器分发到FArraySecond中去
          // 4.将FArraySecond[FCurrentSecond]中的定时器分发到FArrayTick中去
          // 5.处理FArrayTick[FCurrentTick]中的定时器
          while not FArrayDay[FCurrentDay].Empty() do begin
            ATick := FArrayDay[FCurrentDay].DequeueEx();
            FArrayHour[ATick^.Hour].Enqueue(ATick);
          end;
          while not FArrayHour[FCurrentHour].Empty() do begin
            ATick := FArrayHour[FCurrentHour].DequeueEx();
            FArrayMinute[ATick^.Minute].Enqueue(ATick);
          end;
          while not FArrayMinute[FCurrentMinute].Empty() do begin
            ATick := FArrayMinute[FCurrentMinute].DequeueEx();
            FArraySecond[ATick^.Second].Enqueue(ATick);
          end;
          while not FArraySecond[FCurrentSecond].Empty() do begin
            ATick := FArraySecond[FCurrentSecond].DequeueEx();
            FArrayTick[ATick^.Tick].Enqueue(ATick);
          end;
          // 处理FArrayTick[FCurrentTick]
          //
        end
        {$endregion}
        else begin
          // 1.将FArrayHour[FCurrentHour]中的定时器分发到FArrayMinute中去
          // 2.将FArrayMinute[FCurrentMinute]中的定时器分发到FArraySecond中去
          // 3.将FArraySecond[FCurrentSecond]中的定时器分发到FArrayTick中去
          // 4.处理FArrayTick[FCurrentTick]中的定时器
          while not FArrayHour[FCurrentHour].Empty() do begin
            ATick := FArrayHour[FCurrentHour].DequeueEx();
            FArrayMinute[ATick^.Minute].Enqueue(ATick);
          end;
          while not FArrayMinute[FCurrentMinute].Empty() do begin
            ATick := FArrayMinute[FCurrentMinute].DequeueEx();
            FArraySecond[ATick^.Second].Enqueue(ATick);
          end;
          while not FArraySecond[FCurrentSecond].Empty() do begin
            ATick := FArraySecond[FCurrentSecond].DequeueEx();
            FArrayTick[ATick^.Tick].Enqueue(ATick);
          end;
          // 处理FArrayTick[FCurrentTick]
          //
        end;

      end
      {$endregion}
      else begin
        // 1. 将当前FArrayMinute[FCurrentMinute]中缓存的定时器分发到FArraySecond中
        // 2. 将当前FArraySecond[FCurrentSecond]中缓存的定时器分发到FArrayTick中
        // 3. 处理当前FArrayTick[FCurrentTick]
        while not FArrayMinute[FCurrentMinute].Empty() do begin
          ATick := FArrayMinute[FCurrentMinute].DequeueEx();
          FArraySecond[ATick^.Second].Enqueue(ATick);
        end;
        while not FArraySecond[FCurrentSecond].Empty() do begin
          ATick := FArraySecond[FCurrentSecond].DequeueEx();
          FArrayTick[ATick^.Tick].Enqueue(ATick);
        end;
          // 处理FArrayTick[FCurrentTick]
          //
      end;
    end
    {$endregion}
    else begin
      // 1.将FArraySecond[FCurrentSecond]中的定时器分发到FArrayTick中去
      // 2.处理FArrayTick[FCurrentTick]中的定时器
      while not FArraySecond[FCurrentSecond].Empty() do begin
        ATick := FArraySecond[FCurrentSecond].DequeueEx();
        FArrayTick[ATick^.Tick].Enqueue(ATick);
      end;
      // 处理FArrayTick[FCurrentTick]
      //
    end;
  end;

  begin
    // 处理FArrayTick[FCurrentTick]
    //
    while not FArrayTick[FCurrentTick].Empty() do begin
      ATick := FArrayTick[FCurrentTick].DequeueEx();
      ATimer := ATick^.Timer;
      EnqueuePTick(ATick);
      if not ATimer.Canceled then
        ATimer.ExpireRoutine(ATimer.Waiter);
      EnqueueTimer(ATimer);
    end;
  end;

end;

procedure TTimeWheel<T>.SetDays(const Value: Integer);
begin
  FDays := Value;
end;

procedure TTimeWheel<T>.SetTick(const Value: Integer);
begin
  FTick := Value;
end;

procedure TTimeWheel<T>.Start;
var
  I: Integer;
begin
  SetLength(FArrayDay, FDays);
  for I := 0 to FDays - 1 do begin
    FArrayDay[I] := TFlexibleQueue<PTick>.Create(64);
    FArrayDay[I].OnItemNotify := OnPTickNotify;
  end;
  for I := 0 to 24 - 1 do begin
    FArrayHour[I] := TFlexibleQueue<PTick>.Create(64);
    FArrayHour[I].OnItemNotify := OnPTickNotify;
  end;
  for I := 0 to 60 - 1 do begin
    FArrayMinute[I] := TFlexibleQueue<PTick>.Create(64);
    FArrayMinute[I].OnItemNotify := OnPTickNotify;
  end;
  for I := 0 to 60 - 1 do begin
    FArraySecond[I] := TFlexibleQueue<PTick>.Create(64);
    FArraySecond[I].OnItemNotify := OnPTickNotify;
  end;
  SetLength(FArrayTick, FTicksPerSecond);
  for I := 0 to FTicksPerSecond - 1 do begin
    FArrayTick[I] := TFlexibleQueue<PTick>.Create(64);
    FArrayTick[I].OnItemNotify := OnPTickNotify;
  end;
  inherited;
end;

function TTimeWheel<T>.StartTimer(AWaiter: T; ExpireTime: Int64; ExpireRoutine: TExpireRoutine<T>): TTimer<T>;
var
  Day: Integer;
  Hour: Integer;
  Minute: Integer;
  Second: Integer;
  Tick: Integer;

  ATimer: TTimer<T>;
  ATick: PTick;
begin
  // 1. 检查超时限是否在指定范围内，FTick < ExpireTime < FDays * DAY_MICROSECONDS
  // 2. 计算CurrentTick + ExpireTimed对应的绝对时间[dd:hh:mm:ss]

  // dxm 2018.11.20
  // 如果Day = FCurrentDay，在满足1.的情况下，只能说明ExpireTime小于1天
  //    如果Hour = FCurrentHour，说明ExpireTime小于1小时
  //      如果Minute = FCurrentMinute，说明ExpireTime小于1分钟
  //        如果Second = FCurrentSecond，说明ExpireTime小于1秒钟
  //          //如果Tick = FCurrentTick，说明ExpireTime小于1个Tick // 不允许此种情形
  //          ATimer := FAvaliableTimer.Dequeue();
  //          ATick := FAvaliablePTick.Dequeue();
  //          ATick^.Tick := Tick;
  //          ATick^.Timer := ATick;
  //          FArrayTick[ATick] := ATick;
  // ......
  //
  //

  Result := nil;
  if (ExpireTime > FTick) and (ExpireTime < FDays * DAY_MICROSECONDS) then begin
    Day := (FCurrentDay + ExpireTime div DAY_MICROSECONDS) mod FDays;
    Hour := (FCurrentHour + ExpireTime div HOUR_MICROSECONDS) mod 24;
    Minute := (FCurrentMinute + ExpireTime div MINUTE_MICROSECONDS) mod 60;
    Second := (FCurrentSecond + ExpireTime div SECONDS_MICROSECONDS) mod 60;
    Tick := (FCurrentTick + ExpireTime div FTick) mod FTicksPerSecond;

    ATimer := DequeueTimer();
    ATimer.Waiter := AWaiter;
    ATimer.ExpireTime := ExpireTime;
    ATimer.Canceled := False;
    ATimer.ExpireRoutine := ExpireRoutine;

    ATick := DequeuePTick();
    ATick^.Tick := Tick;
    ATick^.Second := Second;
    ATick^.Minute := Minute;
    ATick^.Hour := Hour;
    ATick^.Day := Day;
    ATick^.Timer := ATimer;

    if (Day = FCurrentDay) or
      ((Day = ((FCurrentDay + 1) mod FDays)) and (Day < FCurrentDay)) then begin
      if (Hour = FCurrentHour) or
        ((Hour = ((FCurrentHour + 1) mod 24)) and (Minute < FCurrentMinute)) then begin
        if (Minute = FCurrentMinute) or
          ((Minute = ((FCurrentMinute + 1) mod 60)) and (Second < FCurrentSecond)) then begin
          if (Second = FCurrentSecond) or
            ((Second = ((FCurrentSecond + 1) mod 60)) and (Tick < FCurrentTick)) then begin
            FArrayTick[Tick].Enqueue(ATick);
          end
          else begin
            FArraySecond[Second].Enqueue(ATick);
          end;
        end
        else begin
          FArrayMinute[Minute].Enqueue(ATick);
        end;
      end
      else begin
        FArrayHour[Hour].Enqueue(ATick);
      end;
    end
    else begin
      FArrayDay[Day].Enqueue(ATick);
    end;

    Result := ATimer;
  end;
end;

procedure TTimeWheel<T>.Stop;
var
  I: Integer;
begin
  inherited;
  for I := 0 to FDays - 1 do
    FArrayDay[I].Free();
  for I := 0 to 24 - 1 do
    FArrayHour[I].Free();
  for I := 0 to 60 - 1 do
    FArrayMinute[I].Free();
  for I := 0 to 60 - 1 do
    FArraySecond[I].Free();
  for I := 0 to FTicksPerSecond - 1 do
    FArrayTick[I].Free();
end;

procedure TTimeWheel<T>.StopTimer(ATimer: TTimer<T>);
begin
  ATimer.Canceled := True;
end;

end.
