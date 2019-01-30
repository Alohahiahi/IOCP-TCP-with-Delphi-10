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
  // ���Value1����Value2��������
  // ���Value1С��Value2�����ظ�
  // ���Value1����Value2��������
  TValueCompare<T> = function (const Value1, Value2: T): Integer of object;
  // ����HashMap�Բ�ͬ���͵�Key����������
  TValueConvert<T> = function (Value: T): Integer of object;

const
  TIME_WHEEL_DAY  = 30;
  TIME_WHEEL_TICK = 100; // ms

implementation

end.
