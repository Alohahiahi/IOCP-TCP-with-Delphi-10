{**
 * @Author: Du xinming
 * @Contact: QQ<36511179>; Email<lndxm1979@163.com>
 * @Version: 0.0
 * @Date: 2018.10
 * @Brief:
 * @References: Introduction to Algorithms, Second Edition
 *}

unit org.algorithms.tree;

interface

uses
  WinApi.Windows,
  org.algorithms
{$IfDef TEST_ALGORITHMS}
  , Vcl.Graphics;
{$Else}
  ;
{$ENDIF}

type
  TRBColor = (rbRed, rbBlack);
  TAVLFactor = -2..2;
  TTreeType = (tBinary, tRedBlack, tTreap, tAVL);

  PNodeParameter = ^TNodeParameter;
  TNodeParameter = record
  case TTreeType of
    tRedBlack: (Color: TRBColor);
    tTreap: (Priority: Integer);
    tAVL: (Factor: TAVLFactor);
  end;

  TNode<TKey, TValue> = class
  private
    FKey: TKey;
    FValue: TValue;
    FParent: TNode<TKey, TValue>;
    FLeft: TNode<TKey, TValue>;
    FRight: TNode<TKey, TValue>;
    FSentinel: Boolean;
    FParameter: PNodeParameter;
    FKeyNotify: TValueNotify<TKey>;
    FValueNotify: TValueNotify<TValue>;
  public
{$IfDef TEST_ALGORITHMS}
    Index: Integer;
    Layer: Integer;
    X: Double;
    Y: Double;
{$ENDIF}
  public
    constructor Create(AKey: TKey; AValue: TValue);
    destructor Destroy; override;
    property Key: TKey read FKey;
    property Value: TValue read FValue;
    property OnKeyNotify: TValueNotify<TKey> read FKeyNotify write FKeyNotify;
    property OnValueNotify: TValueNotify<TValue> read FValueNotify write FValueNotify;
  end;

  //遍历树时用于指定对结点的操作，如打印、删除等
  TNodeMethod<TKey, TValue> = procedure (Node: TNode<TKey, TValue>) of object;

  TBinaryTree<TKey, TValue> = class
  private
    FRoot: TNode<TKey, TValue>;
    FCount: Integer;
    FHeight: Integer;
    //
    FKeyCompare: TValueCompare<TKey>;
    FKeyNotify: TValueNotify<TKey>;
    FValueNotify: TValueNotify<TValue>;
    // 动态获取树高
    function GetHeight: Integer;
    // 释放结点
    procedure FreeNode(Node: TNode<TKey, TValue>);
//{$IfDef TEST_ALGORITHMS}
  public
//{$Endif}
    // 判读结点是否为岗哨
    class function IsSentinel(Node: TNode<TKey, TValue>): Boolean;
    // 查找某子树中最小的Key对应的结点
    function Minimum(SubRoot: TNode<TKey, TValue>): TNode<TKey, TValue>;
    // 查找某子树中最大的Key对应的结点
    function Maximum(SubRoot: TNode<TKey, TValue>): TNode<TKey, TValue>;
    // 查找某结点的后序
    function Successor(Node: TNode<TKey, TValue>): TNode<TKey, TValue>;
    // 查找某结点的前序
    function Predecessor(Node: TNode<TKey, TValue>): TNode<TKey, TValue>;
    // 获取某子树的树高
    function GetSubHeight(SubRoot: TNode<TKey, TValue>): Integer;
    // 中序遍历某子树
    // @Root 子树
    // @Routine 处理例程
    procedure InOrder(SubRoot: TNode<TKey, TValue>; Routine: TNodeMethod<TKey, TValue>);
    // 后序遍历某子树
    procedure PostOrder(SubRoot: TNode<TKey, TValue>; Routine: TNodeMethod<TKey, TValue>);
    // 前序遍历某子树
    procedure PreOrder(SubRoot: TNode<TKey, TValue>; Routine: TNodeMethod<TKey, TValue>);
  protected
    // 拼接
    procedure Transplant(u, v: TNode<TKey, TValue>);
    // 左旋
    procedure LeftRotate(Node: TNode<TKey, TValue>);
    // 右旋
    procedure RightRotate(Node: TNode<TKey, TValue>);
  public
    destructor Destroy(); override;
    // 查找在某子树中指定Key对应的结点
    function Search(SubRoot: TNode<TKey, TValue>; const AKey: TKey): TNode<TKey, TValue>; overload;
    function Search(const AKey: TKey): TNode<TKey, TValue>; overload;
    // 向树中插入结点
    procedure Insert(AKey: TKey; AValue: TValue); overload;
    procedure Insert(Node: TNode<TKey, TValue>); overload; virtual;
    // 从树中删除结点
    procedure Delete(Node: TNode<TKey, TValue>); virtual;
    //
    property Root: TNode<TKey, TValue> read FRoot;
    property Count: Integer read FCount;
    property Height: Integer read GetHeight;
    property OnKeyCompare: TValueCompare<TKey> read FKeyCompare Write FKeyCompare;
    property OnKeyNotify: TValueNotify<TKey> read FKeyNotify write FKeyNotify;
    property OnValueNotify: TValueNotify<TValue> read FValueNotify write FValueNotify;

{$IfDef TEST_ALGORITHMS}
    procedure RefreshCoordinate(Node: TNode<TKey, TValue>);
{$ENDIF}
  end;

  TRBTree<TKey, TValue> = class(TBinaryTree<TKey, TValue>)
  private
    FSentinel: TNode<TKey, TValue>;
    procedure InsertFixup(Node: TNode<TKey, TValue>);
    procedure DeleteFixup(Node: TNode<TKey, TValue>);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Insert(Node: TNode<TKey, TValue>); override;
    procedure Delete(Node: TNode<TKey, TValue>); override;
  end;

  TTreapTree<TKey, TValue> = class(TBinaryTree<TKey, TValue>)
  private
    FSentinel: TNode<TKey, TValue>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Insert(Node: TNode<TKey, TValue>); override;
    procedure Delete(Node: TNode<TKey, TValue>); override;
  end;

  TAVLTree<TKey, TValue> = class(TBinaryTree<TKey, TValue>)
  private
    procedure InsertBalance(Node: TNode<TKey, TValue>);
    procedure DeleteBalance(Node: TNode<TKey, TValue>);
  public
    procedure Insert(Node: TNode<TKey, TValue>); override;
    procedure Delete(Node: TNode<TKey, TValue>); override;
  end;

{$IfDef TEST_ALGORITHMS}
  function GetX(TreeHeight, Layer, Index: Integer): Double;
  procedure DrawTree(Root: TNode<Integer, Integer>; Canvas: TCanvas;
    Left, Top: Integer; XStep, YStep: Double; TreeType: TTreeType = tBinary);
{$ENDIF}

const
  TREE_TYPE_DESC: array [TTreeType] of string = (
    '二叉树',
    '红黑树',
    '随机树',
    '平衡树'
  );

implementation

{$IfDef TEST_ALGORITHMS}
uses
  System.SysUtils,
  System.Math;
{$ENDIF}

{ TBinaryTree<TKey, TValue> }

procedure TBinaryTree<TKey, TValue>.Delete(Node: TNode<TKey, TValue>);
var
  Y: TNode<TKey, TValue>;
begin
  if IsSentinel(Node.FLeft) then
    Transplant(Node, Node.FRight)
  else if IsSentinel(Node.FRight) then
    Transplant(Node, Node.FLeft)
  else begin
    Y := Minimum(Node.FRight);
    if Y.FParent <> Node then begin
      Transplant(Y, Y.FRight);
      Y.FRight := Node.FRight;
      Y.FRight.FParent := Y;
    end;
    Transplant(Node, Y);
    Y.FLeft := Node.FLeft;
    Y.FLeft.FParent := Y;
  end;
  FHeight := -1; // 树高需重新计算
  Dec(FCount);
end;

destructor TBinaryTree<TKey, TValue>.Destroy;
begin
  PostOrder(FRoot, FreeNode);
  inherited;
end;

procedure TBinaryTree<TKey, TValue>.FreeNode(
  Node: TNode<TKey, TValue>);
begin
  if Assigned(FKeyNotify) then
    FKeyNotify(Node.Key, atDelete);
  if Assigned(FValueNotify) then
    FValueNotify(Node.Value, atDelete);
  Node.Free();
end;

function TBinaryTree<TKey, TValue>.GetSubHeight(
  SubRoot: TNode<TKey, TValue>): Integer;
var
  LeftHeight, RightHeight: Integer;
begin
  if IsSentinel(SubRoot) then
    Result := 0
  else begin
    LeftHeight := 0;
    if not IsSentinel(SubRoot.FLeft) then
      LeftHeight := GetSubHeight(SubRoot.FLeft);
    RightHeight := 0;
    if not IsSentinel(SubRoot.FRight) then
      RightHeight := GetSubHeight(SubRoot.FRight);
    if LeftHeight > RightHeight then
      Result := LeftHeight + 1
    else
      Result := RightHeight + 1;
  end;
end;

function TBinaryTree<TKey, TValue>.GetHeight: Integer;
begin
  if FHeight = -1 then
    FHeight := GetSubHeight(FRoot);
  Result := FHeight;
end;

procedure TBinaryTree<TKey, TValue>.InOrder(
  SubRoot: TNode<TKey, TValue>;
  Routine: TNodeMethod<TKey, TValue>);
begin
  if not IsSentinel(SubRoot) then begin
    if not IsSentinel(SubRoot.FLeft) then
      InOrder(SubRoot.FLeft, Routine);
    Routine(SubRoot);
    if not IsSentinel(SubRoot.FRight) then
      InOrder(SubRoot.FRight, Routine);
  end;
end;

procedure TBinaryTree<TKey, TValue>.Insert(AKey: TKey; AValue: TValue);
var
  Node: TNode<TKey, TValue>;
begin
  Node := TNode<TKey,TValue>.Create(AKey, AValue);
  Insert(Node);
end;

procedure TBinaryTree<TKey, TValue>.Insert(Node: TNode<TKey, TValue>);
var
  Parent: TNode<TKey, TValue>;
  Tmp: TNode<TKey, TValue>;
begin
  Node.OnKeyNotify := FKeyNotify;
  Node.OnValueNotify := FValueNotify;

  Parent := FRoot;
  Tmp := FRoot;
  while not IsSentinel(Tmp) do begin
    Parent := Tmp;
    if FKeyCompare(Node.FKey, Tmp.FKey) < 0 then
      Tmp := Tmp.FLeft
    else
      Tmp := Tmp.FRight;
  end;
  Node.FParent := Parent;
  if IsSentinel(Parent) then
    FRoot := Node
  else if FKeyCompare(Node.FKey, Parent.FKey) < 0 then
    Parent.FLeft := Node
  else
    Parent.FRight := Node;

  FHeight := -1; // 需重新计算树高
  Inc(FCount);
end;

class function TBinaryTree<TKey, TValue>.IsSentinel(
  Node: TNode<TKey, TValue>): Boolean;
begin
  Result := False;
  if (Node = nil) or Node.FSentinel then
    Result := True;
end;

procedure TBinaryTree<TKey, TValue>.LeftRotate(Node: TNode<TKey, TValue>);
var
  Y: TNode<TKey, TValue>;
begin
  Y := Node.FRight;
  Node.FRight := Y.FLeft;
  if not IsSentinel(Y.FLeft) then
    Y.FLeft.FParent := Node;
  Y.FParent := Node.FParent;
  if IsSentinel(Node.FParent) then
    FRoot := Y
  else if Node = Node.FParent.FLeft then
    Node.FParent.FLeft := Y
  else
    Node.FParent.FRight := Y;
  Y.FLeft := Node;
  Node.FParent := Y;
end;

function TBinaryTree<TKey, TValue>.Maximum(
  SubRoot: TNode<TKey, TValue>): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  if not IsSentinel(SubRoot) then begin
    Tmp := SubRoot;
    while not IsSentinel(Tmp.FRight) do begin
      Tmp := Tmp.FRight
    end;
    Result := Tmp;
  end;
end;

function TBinaryTree<TKey, TValue>.Minimum(
  SubRoot: TNode<TKey, TValue>): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  if not IsSentinel(SubRoot) then begin
    Tmp := SubRoot;
    while not IsSentinel(Tmp.FLeft) do begin
      Tmp := Tmp.FLeft
    end;
    Result := Tmp;
  end;
end;

procedure TBinaryTree<TKey, TValue>.PostOrder(
  SubRoot: TNode<TKey, TValue>;
  Routine: TNodeMethod<TKey, TValue>);
begin
  if not IsSentinel(SubRoot) then begin
    if not IsSentinel(SubRoot.FLeft) then
      PostOrder(SubRoot.FLeft, Routine);
    if not IsSentinel(SubRoot.FRight) then
      PostOrder(SubRoot.FRight, Routine);
    Routine(SubRoot);
  end;
end;

function TBinaryTree<TKey, TValue>.Predecessor(
  Node: TNode<TKey, TValue>): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  if not IsSentinel(Node.FLeft) then
    Result := Maximum(Node.FLeft)
  else begin
    Tmp := Node;
    while not IsSentinel(Tmp.FParent) and (Tmp = Tmp.FParent.FLeft) do
      Tmp := Tmp.FParent;
    if not IsSentinel(Tmp.FParent) then
      Result := Tmp.FParent;
  end;
end;

procedure TBinaryTree<TKey, TValue>.PreOrder(
  SubRoot: TNode<TKey, TValue>;
  Routine: TNodeMethod<TKey, TValue>);
begin
  if not IsSentinel(SubRoot) then begin
    Routine(SubRoot);
    if not IsSentinel(SubRoot.FLeft) then
      PreOrder(SubRoot.FLeft, Routine);
    if not IsSentinel(SubRoot.FRight) then
      PreOrder(SubRoot.FRight, Routine);
  end;
end;

{$IfDef TEST_ALGORITHMS}
function GetX(TreeHeight, Layer, Index: Integer): Double;
begin
  if Layer = TreeHeight - 1 then
    Result := Index
  else
    Result := (GetX(TreeHeight, Layer + 1, 2 * Index) + GetX(TreeHeight, Layer + 1, 2 * Index + 1)) / 2;
end;
{$Endif}

{$IfDef TEST_ALGORITHMS}
procedure TBinaryTree<TKey, TValue>.RefreshCoordinate(
  Node: TNode<TKey, TValue>);
begin
  if not IsSentinel(Node) then begin
    if IsSentinel(Node.FParent) then begin
      Node.Layer := 0;
      Node.Index := 0;
    end
    else begin
      Node.Layer := Node.FParent.Layer + 1;
      if Node = Node.FParent.FLeft then
        Node.Index := 2 * Node.FParent.Index
      else
        Node.Index := 2 * Node.FParent.Index + 1;
    end;

    RefreshCoordinate(Node.FLeft);
    RefreshCoordinate(Node.FRight);

    Node.Y := Node.Layer;
    if IsSentinel(Node.FLeft) and IsSentinel(Node.FRight) then begin
      if Node.Layer = Height - 1 then begin
        Node.X := Node.Index;
      end
      else begin
        Node.X := GetX(Height, Node.Layer + 1, 2 * Node.Index) + GetX(Height, Node.Layer + 1, 2 * Node.Index + 1);
        Node.X := Node.X / 2;
      end;
    end
    else if IsSentinel(Node.FLeft) then begin
      Node.X := GetX(Height, Node.Layer + 1, 2 * Node.Index) + Node.FRight.X;
      Node.X := Node.X / 2;
    end
    else if IsSentinel(Node.FRight) then begin
      Node.X :=  Node.FLeft.X + GetX(Height, Node.Layer + 1, 2 * Node.Index + 1);
      Node.X := Node.X / 2;
    end
    else begin
      Node.X := (Node.FLeft.X + Node.FRight.X) / 2;
    end;
  end;
end;
{$Endif}

procedure TBinaryTree<TKey, TValue>.RightRotate(
  Node: TNode<TKey, TValue>);
var
  X: TNode<TKey, TValue>;
begin
  X := Node.FLeft;
  Node.FLeft := X.FRight;
  if not IsSentinel(X.FRight) then
    X.FRight.FParent := Node;
  X.FParent := Node.FParent;
  if IsSentinel(Node.FParent) then
    FRoot := X
  else if Node = Node.FParent.FLeft then
    Node.FParent.FLeft := X
  else
    Node.FParent.FRight := X;
  X.FRight := Node;
  Node.FParent := X;
end;

function TBinaryTree<TKey, TValue>.Search(SubRoot: TNode<TKey, TValue>;
  const AKey: TKey): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  Tmp := SubRoot;
  while not IsSentinel(Tmp) and (FKeyCompare(AKey, Tmp.FKey) <> 0) do begin
    if FKeyCompare(AKey, Tmp.FKey) < 0  then
      Tmp := Tmp.FLeft
    else
      Tmp := Tmp.FRight;
  end;
  if not IsSentinel(Tmp) then
    Result := Tmp;
end;

function TBinaryTree<TKey, TValue>.Search(const AKey: TKey): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  Tmp := FRoot;
  while not IsSentinel(Tmp) and (FKeyCompare(AKey, Tmp.FKey) <> 0) do begin
    if FKeyCompare(AKey, Tmp.FKey) < 0  then
      Tmp := Tmp.FLeft
    else
      Tmp := Tmp.FRight;
  end;
  if not IsSentinel(Tmp) then
    Result := Tmp;
end;

function TBinaryTree<TKey, TValue>.Successor(
  Node: TNode<TKey, TValue>): TNode<TKey, TValue>;
var
  Tmp: TNode<TKey, TValue>;
begin
  Result := nil;
  if not IsSentinel(Node.FRight) then
    Result := Minimum(Node.FRight)
  else begin
    Tmp := Node;
    while not IsSentinel(Tmp.FParent) and (Tmp = Tmp.FParent.FRight) do
      Tmp := Tmp.FParent;
    if not IsSentinel(Tmp.FParent) then
      Result := Tmp.FParent;
  end;
end;

procedure TBinaryTree<TKey, TValue>.Transplant(u, v: TNode<TKey, TValue>);
begin
  if IsSentinel(u.FParent) then
    FRoot := v
  else if u = u.FParent.FLeft then
    u.FParent.FLeft := v
  else
    u.FParent.FRight := v;
  if v <> nil then
    v.FParent := u.FParent;
end;

{$IfDef TEST_ALGORITHMS}
procedure DrawTree(Root: TNode<Integer, Integer>; Canvas: TCanvas;
  Left, Top: Integer; XStep, YStep: Double; TreeType: TTreeType);
var
  X0, Y0, X1, Y1, X2, Y2, X, Y: Integer;
  Text: string;
  TextWidth, TextHeight: Integer;
  TextOffsetX, TextOffSetY: Integer;
begin
  if not TBinaryTree<Integer, Integer>.IsSentinel(Root) then begin

    X := Floor(Root.X * XStep) + Left;
    Y := Floor(Root.Y * YStep) + Top;

    // 绘制父结点
    if not TBinaryTree<Integer, Integer>.IsSentinel(Root.FParent) then begin
      X0 := Floor(Root.FParent.X * XStep) + Left;
      Y0 := Floor(Root.FParent.Y * YStep) + Top;

      Canvas.MoveTo(X0, Y0);
      Canvas.LineTo(X, Y);

      Text := Format('%d', [Root.FParent.FKey]);
      TextHeight := Canvas.TextHeight(Text);
      TextWidth := Canvas.TextWidth(Text);
      TextOffsetX := TextWidth div 2;
      TextOffSetY := TextHeight div 2;
      if TextWidth < TextHeight then
        TextWidth := TextHeight;
      X1 := X0 - TextWidth;
      X2 := X0 + TextWidth;
      Y1 := Y0 - TextHeight;
      Y2 := Y0 + TextHeight;

      if TreeType = tRedBlack then begin
        if Root.FParent.FParameter^.Color = rbRed then
          Canvas.Brush.Color := clRed
        else
          Canvas.Brush.Color := clGray;
      end;

      Canvas.Ellipse(X1, Y1, X2, Y2);
      Canvas.TextOut(X0 - TextOffsetX, Y0 - TextOffSetY, Text);
    end;

    // 绘制左子树
    DrawTree(Root.FLeft, Canvas, Left, Top, XStep, YStep, TreeType);
    // 绘制右子树
    DrawTree(Root.FRight, Canvas, Left, Top, XStep, YStep, TreeType);

    if TBinaryTree<Integer, Integer>.IsSentinel(Root.FLeft) and
      TBinaryTree<Integer, Integer>.IsSentinel(Root.FRight) then begin
      Text := Format('%d', [Root.FKey]);
      TextHeight := Canvas.TextHeight(Text);
      TextWidth := Canvas.TextWidth(Text);
      TextOffsetX := TextWidth div 2;
      TextOffSetY := TextHeight div 2;
      if TextWidth < TextHeight then
        TextWidth := TextHeight;

      X1 := X - TextWidth;
      X2 := X + TextWidth;
      Y1 := Y - TextHeight;
      Y2 := Y + TextHeight;

      if TreeType = tRedBlack then begin
        if Root.FParameter^.Color = rbRed then
          Canvas.Brush.Color := clRed
        else
          Canvas.Brush.Color := clGray;
      end;

      Canvas.Ellipse(X1, Y1, X2, Y2);
      Canvas.TextOut(X - TextOffsetX, Y - TextOffSetY, Text);
    end;
  end;
end;
{$Endif}

{ TNode<TKey, TValue> }

constructor TNode<TKey, TValue>.Create(AKey: TKey; AValue: TValue);
begin
  FKey := AKey;
  FValue := AValue;
  FParent := nil;
  FLeft := nil;
  FRight := nil;
  FSentinel := False;
  New(FParameter);
end;

destructor TNode<TKey, TValue>.Destroy;
begin
  if Assigned(FKeyNotify) then
    FKeyNotify(Fkey, atDelete);
  if Assigned(FValueNotify) then
    FValueNotify(FValue, atDelete);
  Dispose(FParameter);
  inherited;
end;

{ TRBTree<TKey, TValue> }

constructor TRBTree<TKey, TValue>.Create;
begin
  inherited Create;
  FSentinel := TNode<TKey, TValue>.Create(Default(TKey), Default(TValue));
  FSentinel.FSentinel := True;
  FSentinel.FParameter^.Color := rbBlack;
  FRoot := FSentinel;
end;

procedure TRBTree<TKey, TValue>.Delete(Node: TNode<TKey, TValue>);
var
  X, Y, Z: TNode<TKey, TValue>;
  YOriginalColor: TRBColor;
begin
  Z := Node;
  Y := Z;
  YOriginalColor := Y.FParameter^.Color;
  if IsSentinel(Z.FLeft) then begin
    X := Z.FRight;
    Transplant(Z, Z.FRight);
  end
  else if IsSentinel(Z.FRight) then begin
    X := Z.FLeft;
    Transplant(Z, Z.FLeft);
  end
  else begin
    Y := Minimum(Z.FRight);
    YOriginalColor := Y.FParameter^.Color;
    X := Y.FRight;
    if Y.FParent = Z then
      X.FParent := Y
    else begin
      Transplant(Y, Y.FRight);
      Y.FRight := Z.FRight;
      Y.FRight.FParent := Y;
    end;

    Transplant(Z, Y);
    Y.FLeft := Z.FLeft;
    Y.FLeft.FParent := Y;
    Y.FParameter^.Color := Z.FParameter^.Color;
  end;
  if YOriginalColor = rbBlack then
    DeleteFixup(X);

  FHeight := -1;
  Dec(FCount);
end;

procedure TRBTree<TKey, TValue>.DeleteFixup(Node: TNode<TKey, TValue>);
var
  Y: TNode<TKey, TValue>;
begin
  while (Node <> FRoot) and (Node.FParameter^.Color = rbBlack) do begin
    if Node = Node.FParent.FLeft then begin
      Y := Node.FParent.FRight;
      if Y.FParameter^.Color = rbRed then begin
        Y.FParameter^.Color := rbBlack;
        Node.FParent.FParameter^.Color := rbRed;
        LeftRotate(Node.FParent);
        Y := Node.FParent.FRight;
      end;

      if (Y.FLeft.FParameter^.Color = rbBlack) and (Y.FRight.FParameter^.Color = rbBlack) then begin
        Y.FParameter^.Color := rbRed;
        Node := Node.FParent;
      end
      else begin
        if Y.FRight.FParameter^.Color = rbBlack then begin
          Y.FLeft.FParameter^.Color := rbBlack;
          Y.FParameter^.Color := rbRed;
          RightRotate(Y);
          Y := Node.FParent.FRight;
        end;
        Y.FParameter^.Color := Node.FParent.FParameter.Color;
        Node.FParent.FParameter^.Color := rbBlack;
        Y.FRight.FParameter^.Color := rbBlack;
        LeftRotate(Node.FParent);
        Node := FRoot;
      end;
    end
    else begin
      Y := Node.FParent.FLeft;
      if Y.FParameter^.Color = rbRed then begin
        Y.FParameter^.Color := rbBlack;
        Node.FParent.FParameter^.Color := rbRed;
        RightRotate(Node.FParent);
        Y := Node.FParent.FLeft;
      end;

      if (Y.FLeft.FParameter^.Color = rbBlack) and (Y.FRight.FParameter^.Color = rbBlack) then begin
        Y.FParameter^.Color := rbRed;
        Node := Node.FParent;
      end
      else begin
        if Y.FLeft.FParameter^.Color = rbBlack then begin
          Y.FRight.FParameter^.Color := rbBlack;
          Y.FParameter^.Color := rbRed;
          LeftRotate(Y);
          Y := Node.FParent.FLeft;
        end;
        Y.FParameter^.Color := Node.FParent.FParameter^.Color;
        Node.FParent.FParameter^.Color := rbBlack;
        Y.FLeft.FParameter^.Color := rbBlack;
        RightRotate(Node.FParent);
        Node := FRoot;
      end;
    end;
  end;

  Node.FParameter^.Color := rbBlack;
end;

destructor TRBTree<TKey, TValue>.Destroy;
begin
  inherited;
  FSentinel.Free();
end;

procedure TRBTree<TKey, TValue>.Insert(Node: TNode<TKey, TValue>);
var
  Z, Tmp: TNode<TKey, TValue>;
begin
  inherited;
  Z := Node;
  Z.FLeft := FSentinel;
  Z.FRight := FSentinel;
  Z.FParameter^.Color := rbRed;
  Tmp := Z;
  InsertFixup(Tmp);
end;

procedure TRBTree<TKey, TValue>.InsertFixup(Node: TNode<TKey, TValue>);
var
  Y: TNode<TKey, TValue>;
begin
  while Node.FParent.FParameter^.Color = rbRed do begin
    if Node.FParent = Node.FParent.FParent.FLeft then begin
      Y := Node.FParent.FParent.FRight;
      if Y.FParameter^.Color = rbRed then begin
        Node.FParent.FParameter^.Color := rbBlack;
        Y.FParameter^.Color := rbBlack;
        Node.FParent.FParent.FParameter^.Color := rbRed;
        Node := Node.FParent.FParent;
      end
      else begin
        if Node = Node.FParent.FRight then begin
          Node := Node.FParent;
          LeftRotate(Node);
        end;
        Node.FParent.FParameter^.Color := rbBlack;
        Node.FParent.FParent.FParameter^.Color := rbRed;
        RightRotate(Node.FParent.FParent);
      end;
    end
    else begin
      Y := Node.FParent.FParent.FLeft;
      if Y.FParameter^.Color = rbRed then begin
        Node.FParent.FParameter^.Color := rbBlack;
        Y.FParameter^.Color := rbBlack;
        Node.FParent.FParent.FParameter^.Color := rbRed;
        Node := Node.FParent.FParent;
      end
      else begin
        if Node = Node.FParent.FLeft then begin
          Node := Node.FParent;
          RightRotate(Node);
        end;
        Node.FParent.FParameter^.Color := rbBlack;
        Node.FParent.FParent.FParameter^.Color := rbRed;
        LeftRotate(Node.FParent.FParent);
      end;
    end;
  end;
  FRoot.FParameter^.Color := rbBlack;
end;

{ TTreapTree<TKey, TValue> }

constructor TTreapTree<TKey, TValue>.Create;
begin
  inherited Create;
  FSentinel := TNode<TKey, TValue>.Create(Default(TKey), Default(TValue));
  FSentinel.FSentinel := True;
  FSentinel.FParameter^.Priority := 0;
  FRoot := FSentinel;
end;

procedure TTreapTree<TKey, TValue>.Delete(Node: TNode<TKey, TValue>);
var
  Z: TNode<TKey, TValue>;
begin
  Z := Node;
  while not IsSentinel(Z.FLeft) or not IsSentinel(Z.FRight) do begin
    if Z.FLeft.FParameter^.Priority > Z.FRight.FParameter^.Priority then
      RightRotate(Z)
    else
      LeftRotate(Z);
  end;
  Transplant(Z, FSentinel);
  FHeight := -1;
  Dec(FCount);
end;

destructor TTreapTree<TKey, TValue>.Destroy;
begin
  inherited;
  FSentinel.Free();
end;

procedure TTreapTree<TKey, TValue>.Insert(Node: TNode<TKey, TValue>);
var
  Z: TNode<TKey, TValue>;
begin
  inherited;
  Z := Node;
  Z.FLeft := FSentinel;
  Z.FRight := FSentinel;
  Z.FParameter^.Priority := Random(1000);
  while (Z <> FRoot) and (Z.FParameter^.Priority > Z.FParent.FParameter^.Priority) do begin
    if Z = Z.FParent.FLeft then
      RightRotate(Z.FParent)
    else
      LeftRotate(Z.FParent);
  end;
end;

{ TAVLTree<TKey, TValue> }

procedure TAVLTree<TKey, TValue>.Delete(Node: TNode<TKey, TValue>);
var
  X, Y, Z: TNode<TKey, TValue>;
begin
  Z := Node;
  if IsSentinel(Z.FLeft) and IsSentinel(Z.FRight) then begin
    if Z = FRoot then
      //do nothing
    else if Z = Z.FParent.FLeft then
      Dec(Z.FParent.FParameter^.Factor)
    else
      Inc(Z.FParent.FParameter^.Factor);
    X := Z.FParent;
    Transplant(Z, nil);
  end
  else if IsSentinel(Z.FLeft) then begin
    Y := Z.FRight;
    Transplant(Z, Y);
    X := Y;
  end
  else if IsSentinel(Z.FRight) then begin
    Y := Z.FLeft;
    Transplant(Z, Y);
    X := Y;
  end
  else begin
    Y := Minimum(Z.FRight);
    if Y.FParent <> Z then begin
      Transplant(Y, Y.FRight);
      Y.FRight := Z.FRight;
      Y.FRight.FParent := Y;
      Y.FParameter^.Factor := Z.FParameter^.Factor;
      X := Y.FParent;
      Dec(X.FParameter^.Factor);
    end
    else begin
      Y.FParameter^.Factor := Z.FParameter^.Factor + 1;
      X := Y;
    end;
    Transplant(Z, Y);
    Y.FLeft := Z.FLeft;
    Y.FLeft.FParent := Y;
  end;

  while not IsSentinel(X) do begin
    if X.FParameter^.Factor = 0 then begin
      if not IsSentinel(X.FParent) then begin
        if X = X.FParent.FLeft then
          Dec(X.FParent.FParameter^.Factor)
        else
          Inc(X.FParent.FParameter^.Factor);
        X := X.FParent;
      end else
        Break;
    end
    else if (X.FParameter^.Factor = 1) or (X.FParameter^.Factor = -1) then begin
      Break
    end
    else begin
      DeleteBalance(X);
      X := X.FParent;
    end;
  end;

  FHeight := -1;
  Dec(FCount);
end;

procedure TAVLTree<TKey, TValue>.DeleteBalance(Node: TNode<TKey, TValue>);
var
  NodeFactor, NodeLeftFactor, NodeRightFactor: TAVLFactor;
begin
  NodeFactor := 0;
  if Node.FParameter^.Factor = 2 then begin
    NodeLeftFactor := 0;
    if Node.FLeft.FParameter^.Factor = -1 then begin
      if Node.FLeft.FRight.FParameter^.Factor = 1 then begin
        Node.FLeft.FParameter^.Factor := 0;
        NodeFactor := -1;
      end
      else if node.FLeft.FRight.FParameter^.Factor = -1 then begin
        Node.FLeft.FParameter^.Factor := 1
      end else
        Node.FLeft.FParameter^.Factor := 0;
      LeftRotate(Node.FLeft);
    end
    else if Node.FLeft.FParameter^.Factor = 0 then begin
      NodeFactor := 1;
      NodeLeftFactor := -1;
    end;

    Node.FParameter^.Factor := NodeFactor;
    Node.FLeft.FParameter^.Factor := NodeLeftFactor;
    RightRotate(Node);
  end
  else begin
    NodeRightFactor := 0;
    if Node.FRight.FParameter^.Factor = 1 then begin
      if Node.FRight.FLeft.FParameter^.Factor = -1 then begin
        Node.FRight.FParameter^.Factor := 0;
        NodeFactor := 1;
      end
      else if Node.FRight.FLeft.FParameter^.Factor = 1 then begin
        Node.FRight.FParameter^.Factor := -1
      end else
        Node.FRight.FParameter^.Factor := 0;
      RightRotate(Node.FRight)
    end
    else if Node.FRight.FParameter^.Factor = 0 then begin
      NodeFactor := -1;
      NodeRightFactor := 1;
    end;

    Node.FParameter^.Factor := NodeFactor;
    Node.FRight.FParameter^.Factor := NodeRightFactor;
    LeftRotate(Node);
  end;
end;

procedure TAVLTree<TKey, TValue>.Insert(Node: TNode<TKey, TValue>);
var
  Tmp, Parent: TNode<TKey, TValue>;
begin
  inherited;
  Node.FParameter^.Factor := 0; // 初始平衡因子
  Tmp := Node;
  Parent := Tmp.FParent;
  while not IsSentinel(Parent) do begin
    if Tmp = Parent.FLeft then
      Inc(Parent.FParameter^.Factor)
    else
      Dec(Parent.FParameter^.Factor);
    if Parent.FParameter^.Factor = 0 then begin
      Break;
    end
    else if (Parent.FParameter^.Factor = -1) or (Parent.FParameter^.Factor = 1) then begin
      Tmp := Parent;
      Parent := Tmp.FParent;
    end
    else begin
      InsertBalance(Parent);
      Break;
    end;
  end;
end;

procedure TAVLTree<TKey, TValue>.InsertBalance(Node: TNode<TKey, TValue>);
var
  NodeFactor: TAVLFactor;
begin
  NodeFactor := 0;
  if Node.FParameter^.Factor = 2 then begin
    if Node.FLeft.FParameter^.Factor = -1 then begin
      if Node.FLeft.FRight.FParameter^.Factor = 1 then begin
        Node.FLeft.FParameter^.Factor := 0;
        NodeFactor := -1;
      end
      else if Node.FLeft.FRight.FParameter^.Factor = -1 then begin
        Node.FLeft.FParameter^.Factor := 1
      end else
        Node.FLeft.FParameter^.Factor := 0;
      LeftRotate(Node.FLeft);
    end;
    Node.FParameter^.Factor := NodeFactor;
    Node.FLeft.FParameter^.Factor := 0;
    RightRotate(Node);
  end
  else begin
    if Node.FRight.FParameter^.Factor = 1 then begin
      if Node.FRight.FLeft.FParameter^.Factor = -1 then begin
        Node.FRight.FParameter^.Factor := 0;
        NodeFactor := 1;
      end
      else if Node.FRight.FLeft.FParameter^.Factor = 1 then begin
        Node.FRight.FParameter^.Factor := -1
      end else
        Node.FRight.FParameter^.Factor := 0;
      RightRotate(Node.FRight);
    end;
    Node.FParameter^.Factor := NodeFactor;
    Node.FRight.FParameter^.Factor := 0;
    LeftRotate(Node);
  end;
end;

end.
