object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 351
  ClientWidth = 897
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 313
    Top = 0
    Height = 351
    ExplicitLeft = 0
    ExplicitTop = 80
    ExplicitHeight = 100
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 313
    Height = 351
    Align = alLeft
    TabOrder = 0
    ExplicitHeight = 268
    object btnEcho: TButton
      Left = 32
      Top = 177
      Width = 75
      Height = 25
      Caption = 'Echo'
      TabOrder = 0
      OnClick = btnEchoClick
    end
    object btnStart: TButton
      Left = 32
      Top = 146
      Width = 75
      Height = 25
      Caption = 'Start'
      TabOrder = 1
      OnClick = btnStartClick
    end
    object btnStop: TButton
      Left = 113
      Top = 146
      Width = 75
      Height = 25
      Caption = 'Stop'
      TabOrder = 2
      OnClick = btnStopClick
    end
    object btnUploadFile: TButton
      Left = 8
      Top = 208
      Width = 75
      Height = 25
      Caption = 'UploadFile'
      TabOrder = 3
      OnClick = btnUploadFileClick
    end
    object Edit4: TEdit
      Left = 4
      Top = 239
      Width = 307
      Height = 21
      TabOrder = 4
      Text = 'E:\bibliography\delphi\Delphi.In.A.Nutshell.pdf'
      OnChange = Edit4Change
    end
    object Edit3: TEdit
      Left = 113
      Top = 181
      Width = 80
      Height = 21
      TabOrder = 5
      Text = 'Hello world!'
    end
    object SpinEdit1: TSpinEdit
      Left = 208
      Top = 179
      Width = 81
      Height = 22
      MaxValue = 0
      MinValue = 0
      TabOrder = 6
      Value = 100
    end
    object GroupBox1: TGroupBox
      Left = 8
      Top = 1
      Width = 281
      Height = 139
      Caption = #22522#26412#35774#32622
      TabOrder = 7
      object Label1: TLabel
        Left = 93
        Top = 72
        Width = 51
        Height = 13
        Caption = 'RemoteIP:'
      end
      object Label2: TLabel
        Left = 83
        Top = 99
        Width = 61
        Height = 13
        Caption = 'RemotePort:'
      end
      object Label3: TLabel
        Left = 24
        Top = 16
        Width = 120
        Height = 13
        Caption = 'MaxPreIOContextCount:'
      end
      object Label4: TLabel
        Left = 47
        Top = 44
        Width = 97
        Height = 13
        Caption = 'MultiIOBufferCount:'
      end
      object Edit1: TEdit
        Left = 168
        Top = 69
        Width = 97
        Height = 21
        TabOrder = 0
        Text = '127.0.0.1'
      end
      object Edit2: TEdit
        Left = 168
        Top = 96
        Width = 97
        Height = 21
        TabOrder = 1
        Text = '9090'
      end
      object SpinEdit2: TSpinEdit
        Left = 168
        Top = 13
        Width = 97
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 2
        Value = 128
        OnChange = SpinEdit2Change
      end
      object SpinEdit3: TSpinEdit
        Left = 168
        Top = 41
        Width = 97
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 3
        Value = 8
        OnChange = SpinEdit3Change
      end
    end
    object btnDownload: TButton
      Left = 8
      Top = 266
      Width = 75
      Height = 25
      Caption = 'DownloadFile'
      TabOrder = 8
      OnClick = btnDownloadClick
    end
    object Edit5: TEdit
      Left = 4
      Top = 297
      Width = 303
      Height = 21
      TabOrder = 9
      Text = 'E:\GDY20180724.rar'
    end
  end
  object Panel2: TPanel
    Left = 316
    Top = 0
    Width = 581
    Height = 351
    Align = alClient
    Caption = 'Panel2'
    TabOrder = 1
    ExplicitHeight = 268
    object Memo1: TMemo
      Left = 1
      Top = 1
      Width = 579
      Height = 349
      Align = alClient
      Lines.Strings = (
        'Memo1')
      ScrollBars = ssVertical
      TabOrder = 0
      ExplicitHeight = 266
    end
  end
  object MainMenu1: TMainMenu
    Left = 384
    Top = 184
    object N1: TMenuItem
      Caption = #26085#24535
      object llFatal1: TMenuItem
        Caption = 'llFatal'
        OnClick = llFatal1Click
      end
      object llError1: TMenuItem
        Caption = 'llError'
        OnClick = llError1Click
      end
      object llWarnning1: TMenuItem
        Caption = 'llWarnning'
        OnClick = llWarnning1Click
      end
      object llNormal1: TMenuItem
        Caption = 'llNormal'
        OnClick = llNormal1Click
      end
      object llDebug1: TMenuItem
        Caption = 'llDebug'
        OnClick = llDebug1Click
      end
    end
  end
end
