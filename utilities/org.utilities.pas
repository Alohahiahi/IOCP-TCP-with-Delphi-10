{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 *}

unit org.utilities;

interface

type
  TLogLevel = (llFatal, llError, llWarning, llNormal, llDebug);
  TLogNotify = procedure (Sender: TObject; LogLevel: TLogLevel; LogContent: string) of object;

const
  LOG_LEVLE_DESC: array [TLogLevel] of string = (
    'ÖÂÃü',
    '´íÎó',
    '¾¯¸æ',
    'ÆÕÍ¨',
    'µ÷ÊÔ'
  );

implementation

end.
