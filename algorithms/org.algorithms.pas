{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 *}

unit org.algorithms;

interface

type
  TActionType = (atInsert, atDelete, atAbstract);
  TValueNotify<T> = procedure(const Value: T; Action: TActionType) of object;

  //
  // 如果Value1大于Value2，返回正
  // 如果Value1小于Value2，返回负
  // 如果Value1等于Value2，返回零
  TValueCompare<T> = function (const Value1, Value2: T): Integer of object;
  // 用于HashMap对不同类型的Key进行整数化
  TValueConvert<T> = function (Value: T): Integer of object;

const
  TIME_WHEEL_DAY  = 30;
  TIME_WHEEL_TICK = 100; // ms

implementation

end.
