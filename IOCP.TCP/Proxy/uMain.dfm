object Form3: TForm3
  Left = 0
  Top = 0
  Caption = 'Form3'
  ClientHeight = 250
  ClientWidth = 869
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
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 297
    Height = 250
    Align = alLeft
    TabOrder = 0
    object btnStart: TButton
      Left = 24
      Top = 183
      Width = 75
      Height = 25
      Caption = 'Start'
      TabOrder = 0
      OnClick = btnStartClick
    end
    object btnStop: TButton
      Left = 24
      Top = 214
      Width = 75
      Height = 25
      Caption = 'Stop'
      TabOrder = 1
    end
    object GroupBox1: TGroupBox
      Left = 0
      Top = 8
      Width = 291
      Height = 169
      Caption = #22522#26412#35774#32622
      TabOrder = 2
      object Label1: TLabel
        Left = 94
        Top = 69
        Width = 43
        Height = 13
        Caption = 'AgentIP:'
      end
      object Label2: TLabel
        Left = 84
        Top = 94
        Width = 53
        Height = 13
        Caption = 'AgentPort:'
      end
      object Label3: TLabel
        Left = 92
        Top = 118
        Width = 45
        Height = 13
        Caption = 'localPort:'
      end
      object Label4: TLabel
        Left = 35
        Top = 19
        Width = 102
        Height = 13
        Caption = 'MaxPreAcceptCount:'
      end
      object Label5: TLabel
        Left = 40
        Top = 44
        Width = 97
        Height = 13
        Caption = 'MultiIOBufferCount:'
      end
      object Edit1: TEdit
        Left = 143
        Top = 66
        Width = 121
        Height = 21
        TabOrder = 0
        Text = '47.96.155.44'
      end
      object Edit2: TEdit
        Left = 143
        Top = 91
        Width = 121
        Height = 21
        TabOrder = 1
        Text = '9090'
      end
      object Edit3: TEdit
        Left = 143
        Top = 115
        Width = 121
        Height = 21
        TabOrder = 2
        Text = '8090'
      end
      object SpinEdit1: TSpinEdit
        Left = 143
        Top = 16
        Width = 121
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 3
        Value = 1
        OnChange = SpinEdit1Change
      end
      object SpinEdit2: TSpinEdit
        Left = 143
        Top = 41
        Width = 121
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 4
        Value = 8
        OnChange = SpinEdit2Change
      end
    end
  end
  object Panel2: TPanel
    Left = 297
    Top = 0
    Width = 572
    Height = 250
    Align = alClient
    Caption = 'Panel2'
    TabOrder = 1
    object Splitter1: TSplitter
      Left = 1
      Top = 1
      Height = 248
      ExplicitLeft = 240
      ExplicitTop = 136
      ExplicitHeight = 100
    end
    object Memo1: TMemo
      Left = 4
      Top = 1
      Width = 567
      Height = 248
      Align = alClient
      Lines.Strings = (
        'Memo1')
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object MainMenu1: TMainMenu
    Left = 592
    Top = 40
    object N1: TMenuItem
      Caption = #26085#24535
      object Fatal1: TMenuItem
        Caption = 'llFatal'
        OnClick = Fatal1Click
      end
      object Error1: TMenuItem
        Caption = 'llError'
        OnClick = Error1Click
      end
      object Warning1: TMenuItem
        Caption = 'llWarning'
        OnClick = Warning1Click
      end
      object Normal1: TMenuItem
        Caption = 'llNormal'
        OnClick = Normal1Click
      end
      object Debug1: TMenuItem
        Caption = 'llDebug'
        OnClick = Debug1Click
      end
    end
  end
end
