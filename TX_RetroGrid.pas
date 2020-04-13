unit TX_RetroGrid;
{
  Copyright 2020 Tom Taylor (tomxxi).
  This file is part of "TXDelphiLibrary" project.
  "TXDelphiLibrary" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  ----------------------------------------------------------------------------
}

interface

uses
  Math,
  Classes,
  Controls,
  Graphics,
  ExtCtrls,
  Contnrs,
  SysUtils,
  Windows;

const
  clRandom = $030303;
  TXDefaultColumnCount = 30;
  TXDefaultRowCount    = 30;

type
  TXGridConf = class
  private
    FColCount, FRowCount: integer;
    FColor: TColor;
    FInfiniteGrid: boolean;
  public
    constructor Create(AColor: TColor = clBlack; AInfiniteGrid: boolean = True; AColCount: integer = TXDefaultColumnCount; ARowCount: integer = TXDefaultRowCount); virtual;
    property ColumnCount: integer read FColCount write FRowCount;
    property RowCount: integer read FRowCount write FRowCount;
    property IsInfinite: boolean read FInfiniteGrid write FInfiniteGrid;
    property Color: TColor read FColor write FColor;
  end;

  TXCell = class
  protected
    FRow, FCol: integer;
    FRect: TRect;
    FActive: boolean;
    FColor, FRColor: TColor;
  public
    constructor Create(ACol: integer; ARow: integer; ARect: TRect; AStandardColor: TColor = clRandom; ARandomColor: TColor = clRandom; AActive: boolean = False); virtual;
    function Clone: TXCell;
    property Column: integer read FCol write FCol;
    property Row: integer read FRow write FRow;
    property Rect: TRect read FRect;
    property Active: boolean read FActive write FActive;
    property StandardColor: TColor read FColor write FColor;
    property RandomColor: TColor read FRColor write FRColor;
  end;

  TXCellList = class(TObjectList)
  private
    FGridConf: TXGridConf;
  public
    constructor Create(AOwnsObjects: boolean; AGridConf: TXGridConf); reintroduce;
    function GetCellAtPoint(APoint: TPoint): TXCell;
    function GetNeighboursForCellAtIndex(CellIndex: integer): TXCellList;
    function GetNeighboursForCell(SelectedCell: TXCell): TXCellList;
  end;

  TXRetroGrid = class(TPanel)
  private
    FCells: TXCellList;
    FLastMousePos: TPoint;
    FDefaultActiveCellColor: TColor;
    procedure SetColumnCount(AColCount: integer);
    procedure SetRowCount(ARowCount: integer);
    procedure SetActiveCellColor(AColor: TColor);
    function GetDefaultInactiveCellColor: TColor;
    procedure InitialiseCells;
  protected
    FGridConf: TXGridConf;
    FIsMouseDown: boolean;
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); reintroduce;
    destructor Destroy; override;
    procedure Reset;
    function ImportBoard(NewBoard: string): boolean; virtual;
    function ExportBoard: string; virtual;
    property Cells: TXCellList read FCells write FCells;
    property Config: TXGridConf read FGridConf;
    property DefaultActiveCellColor: TColor read FDefaultActiveCellColor write SetActiveCellColor;
    property ColumnCount: integer write SetColumnCount;
    property RowCount: integer write SetRowCount;
  end;

implementation

{-----------------------}
{ TXGridConf            }
{-----------------------}

{------------------------------------------------------------------------------}
constructor TXGridConf.Create(AColor: TColor = clBlack; AInfiniteGrid: boolean = True; AColCount: integer = TXDefaultColumnCount; ARowCount: integer = TXDefaultRowCount);
begin
  FInfiniteGrid := AInfiniteGrid;
  FColCount     := AColCount;
  FRowCount     := ARowCount;
  FColor        := AColor;
end;

{-----------------------}
{ TXCell                }
{-----------------------}

{------------------------------------------------------------------------------}
constructor TXCell.Create(ACol: integer; ARow: integer; ARect: TRect; AStandardColor: TColor = clRandom; ARandomColor: TColor = clRandom; AActive: boolean = False);
begin
  FCol  := ACol;
  FRow  := ARow;
  FRect := ARect;
  FActive := AActive;

  if ARandomColor = clRandom then
    FRColor := RGB(Random(255), Random(255), Random(255))
  else
    FRColor := ARandomColor;

  if AStandardColor = clRandom then
    FColor := FRColor
  else
    FColor := AStandardColor;
end;

{------------------------------------------------------------------------------}
function TXCell.Clone: TXCell;
begin
  Result := TXCell.Create(FCol, FRow, FRect, FColor, FRColor, FActive);
end;

{-----------------------}
{ TXCellList            }
{-----------------------}

{------------------------------------------------------------------------------}
constructor TXCellList.Create(AOwnsObjects: Boolean; AGridConf: TXGridConf);
begin
  inherited Create(AOwnsObjects);
  FGridConf := AGridConf;
end;

{------------------------------------------------------------------------------}
function TXCellList.GetCellAtPoint(APoint: TPoint): TXCell;
var
  Index: integer;
  ACell: TXCell;
begin
  Result := nil;
  for Index := 0 to pred(Count) do
  begin
    ACell := TXCell(Items[Index]);
    if ptinrect(ACell.Rect, APoint) then
    begin
      Result := ACell;
      Exit;
    end;
  end;
end;

{------------------------------------------------------------------------------}
function TXCellList.GetNeighboursForCellAtIndex(CellIndex: integer): TXCellList;
var
  SelectedCell: TXCell;
begin
  if (Count < 0) or (Count > CellIndex) then
    SelectedCell := nil
  else
    SelectedCell := TXCell(Items[CellIndex]);
  Result := GetNeighboursForCell(SelectedCell);
end;

{------------------------------------------------------------------------------}
function TXCellList.GetNeighboursForCell(SelectedCell: TXCell): TXCellList;
var
  LoopIndex, TopRow, BottomRow, LeftColumn, RightColumn: integer;
  ACell: TXCell;
begin
  Result := TXCellList.Create(False, FGridConf);

  if SelectedCell = nil then
    Exit;

  if not FGridConf.IsInfinite then
  begin
    // No calculation needed if grid is not infinite...
    TopRow      := pred(SelectedCell.Row);
    BottomRow   := succ(SelectedCell.Row);
    LeftColumn  := pred(SelectedCell.Column);
    RightColumn := succ(SelectedCell.Column);
  end
  else
  begin
    // Calculate neighbouring cols/rows, accounting for edges of screen...
    if SelectedCell.Row = 0 then
      TopRow := pred(FGridConf.RowCount)
    else
      TopRow := pred(SelectedCell.Row);

    if SelectedCell.Row = pred(FGridConf.RowCount) then
      BottomRow := 0
    else
      BottomRow := succ(SelectedCell.Row);

    if SelectedCell.Column = 0 then
      LeftColumn := pred(FGridConf.ColumnCount)
    else
      LeftColumn := pred(SelectedCell.Column);

    if SelectedCell.Column = pred(FGridConf.ColumnCount) then
      RightColumn := 0
    else
      RightColumn := succ(SelectedCell.Column);
  end;


  for LoopIndex := 0 to pred(Count) do
  begin
    ACell := TXCell(Items[LoopIndex]);
    //if (LiveOnly) and (not ACell.Alive) then
    //  continue;

    // If on the row above...
    if (ACell.Row = TopRow) then
    begin
      // If on a neighbouring column
      if (ACell.Column = LeftColumn) or (ACell.Column = SelectedCell.Column) or (ACell.Column = RightColumn) then
        Result.Add(ACell);
    end
    // If on the current row...
    else if (ACell.Row = SelectedCell.Row) then
    begin
      if (ACell.Column = LeftColumn) or (ACell.Column = RightColumn) then
        Result.Add(ACell);
    end
    // If on the row below...
    else if (ACell.Row = BottomRow) then
    begin
      if (ACell.Column = LeftColumn) or (ACell.Column = SelectedCell.Column) or (ACell.Column = RightColumn) then
        Result.Add(ACell);
    end;

    if (Result.Count = 8) then
      break;
  end;
end;

{-----------------------}
{ TXGrid                }
{-----------------------}

{------------------------------------------------------------------------------}
constructor TXRetroGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  ParentBackground := False;

  FIsMouseDown       := False;
  FDefaultActiveCellColor := clRandom;
  FGridConf  := TXGridConf.Create;
  FCells     := TXCellList.Create(True, FGridConf);
end;

{------------------------------------------------------------------------------}
destructor TXRetroGrid.Destroy;
begin
  FCells.Free;
  FGridConf.Free;
  inherited;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.Reset;
begin
  InitialiseCells;
end;

{------------------------------------------------------------------------------}
function TXRetroGrid.ImportBoard(NewBoard: string): boolean;
var
  CurrentCell: TXCell;
  Index, Alive: integer;
  BoardComponents: TStringList;
begin
  Result := False;

  // TODO
  //GameState := gsStopped;

  BoardComponents := TStringList.Create;
  try
    BoardComponents.Delimiter := ':';
    BoardComponents.DelimitedText := NewBoard;

    if BoardComponents.Count < 3 then
      Exit;

    ColumnCount := StrToIntDef(BoardComponents[0], TXDefaultColumnCount);
    RowCount    := StrToIntDef(BoardComponents[1], TXDefaultRowCount);

    for Index := 2 to pred(BoardComponents.Count) do
    begin
      if Index >= FCells.Count then
        continue;

      CurrentCell := TXCell(FCells[Index]);
      Alive := StrToIntDef(BoardComponents[Index], 0);
      if Alive = 1 then
        CurrentCell.Active := True
      else
        CurrentCell.Active := False;
    end;

    Result := True;
  finally
    BoardComponents.Free;
    Invalidate;
  end;

  // TODO
  //if Result and PlayImmediately then
  //  GameState := gsStarted;
end;

{------------------------------------------------------------------------------}
function TXRetroGrid.ExportBoard: string;
var
  Cell: TXCell;
  Index, Active: integer;
begin
  Result := '';
  if FGridConf = nil then
    Exit;

  Result := format('%d:%d', [FGridConf.ColumnCount, FGridConf.RowCount]);
  for Index := 0 to pred(FCells.Count) do
  begin
    Cell := TXCell(FCells[Index]);
    if Cell.Active then
      Active := 1
    else
      Active := 0;

    Result := format('%s:%d', [Result, Active]);
  end;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.SetColumnCount(AColCount: integer);
begin
  FGridConf.ColumnCount := AColCount;
  Reset;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.SetRowCount(ARowCount: integer);
begin
  FGridConf.RowCount := ARowCount;
  Reset;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.SetActiveCellColor(AColor: TColor);
var
  Index: integer;
begin
  FDefaultActiveCellColor := AColor;
  for Index := 0 to pred(Cells.Count) do
    TXCell(Cells[Index]).StandardColor := AColor;
end;

{------------------------------------------------------------------------------}
function TXRetroGrid.GetDefaultInactiveCellColor: TColor;
begin
  Result := FGridConf.FColor;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.Paint;
var
  Index: integer;
  ACell: TXCell;
begin
  inherited;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FGridConf.Color;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  for Index := 0 to pred(FCells.Count) do
  begin
    ACell := TXCell(FCells.Items[Index]);

    if ACell.Active then
    begin
      if FDefaultActiveCellColor = clRandom then
        Canvas.Brush.Color := ACell.RandomColor
      else
        Canvas.Brush.Color := ACell.StandardColor;
    end
    else
      Canvas.Brush.Color := FGridConf.FColor;

    Canvas.FillRect(ACell.Rect);
  end;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.Resize;
begin
  inherited;
  Reset;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    FIsMouseDown := True;
    MouseMove(Shift, X, Y);
  end;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
    FIsMouseDown := False;
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  SelectedCell: TXCell;
begin
  inherited;
  FLastMousePos := Point(X,Y);
end;

{------------------------------------------------------------------------------}
procedure TXRetroGrid.InitialiseCells;
var
  ACell: TXCell;
  ALeft, ATop, ARight, ABottom: integer;
  RowIndex, ColIndex, CellWidth, CellHeight: integer;
begin
  // TODO
  //GameState := gsStopped;

  CellWidth  := floor(Width / FGridConf.RowCount);
  CellHeight := floor(Height / FGridConf.ColumnCount);

  FCells.Clear;
  for ColIndex := 0 to pred(FGridConf.ColumnCount) do
  begin
    for RowIndex := 0 to pred(FGridConf.RowCount) do
    begin
      ALeft   := CellWidth * RowIndex;
      ATop    := CellHeight * ColIndex;
      ARight  := ALeft + CellWidth;
      ABottom := ATop + CellHeight;
      ACell   := TXCell.Create(ColIndex, RowIndex, Rect(ALeft, ATop, ARight, ABottom), DefaultActiveCellColor);
      FCells.Add(ACell);
    end;
  end;

  Invalidate;
end;

end.