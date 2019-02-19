object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 243
  ClientWidth = 907
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 185
    Top = 0
    Width = 0
    Height = 224
    ExplicitHeight = 202
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 224
    Align = alLeft
    TabOrder = 0
    object btnStart: TButton
      Left = 3
      Top = 192
      Width = 75
      Height = 25
      Caption = 'Start'
      TabOrder = 0
      OnClick = btnStartClick
    end
    object GroupBox1: TGroupBox
      Left = 3
      Top = 0
      Width = 177
      Height = 145
      Caption = #22522#26412#35774#32622
      TabOrder = 1
      object Label1: TLabel
        Left = 5
        Top = 16
        Width = 102
        Height = 13
        Caption = 'MaxPreAcceptCount:'
      end
      object Label2: TLabel
        Left = 10
        Top = 41
        Width = 97
        Height = 13
        Caption = 'MultiIOBufferCount:'
      end
      object Label3: TLabel
        Left = 59
        Top = 68
        Width = 48
        Height = 13
        Caption = 'LocalPort:'
      end
      object SpinEdit1: TSpinEdit
        Left = 112
        Top = 13
        Width = 62
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 0
        Value = 1
        OnChange = SpinEdit1Change
      end
      object SpinEdit2: TSpinEdit
        Left = 112
        Top = 38
        Width = 62
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 1
        Value = 8
        OnChange = SpinEdit2Change
      end
      object SpinEdit3: TSpinEdit
        Left = 112
        Top = 66
        Width = 62
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 2
        Value = 9090
      end
    end
    object Button1: TButton
      Left = 3
      Top = 151
      Width = 75
      Height = 25
      Caption = 'Button1'
      TabOrder = 2
      OnClick = Button1Click
    end
  end
  object Panel2: TPanel
    Left = 185
    Top = 0
    Width = 722
    Height = 224
    Align = alClient
    TabOrder = 1
    object Memo1: TMemo
      Left = 1
      Top = 1
      Width = 720
      Height = 222
      Align = alClient
      Lines.Strings = (
        'Memo1')
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 224
    Width = 907
    Height = 19
    Panels = <
      item
        Text = 'Online:'
        Width = 60
      end
      item
        Text = '0'
        Width = 50
      end
      item
        Text = 'BuffersInUsed:'
        Width = 100
      end
      item
        Text = '0'
        Width = 50
      end>
  end
  object MainMenu1: TMainMenu
    Left = 800
    Top = 16
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
    object N2: TMenuItem
      Caption = #21047#26032
      OnClick = N2Click
    end
  end
end
