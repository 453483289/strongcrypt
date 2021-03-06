unit SDUBlocksPanel;


// NOTE: When the panel has *no* blocks, the control's Caption will be shown
//       instead

 
interface

uses
  ExtCtrls,
  Classes,
  Types,
  Messages,
  Graphics;

type
  // Note: Both Caption and SubCaption can have CRLFs (e.g. SDUCRLF) in them
  //       to insert newlines 
  TBlock = record
    Caption: string;
    SubCaption: string;
    Percentage: double;
    BkColor: TColor;

    Data: TObject;
  end;


  TSDUBlocksPanel = class(TPanel)
  protected
    FLastXY: TPoint;
    FBlocks: array of TBlock;
    FBlockRects: array of TRect;
    FSelected: integer;
    FOnChanged: TNotifyEvent;

    procedure Click; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;

    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure DoEnter; override;

    procedure DrawBlock(idx: integer);
    procedure RemoveAllBlocks();

    procedure SetSelected(idx: integer);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure Clear(); virtual;
    procedure Add(blk: TBlock); virtual;
    function  GetItem(idx: integer): TBlock; virtual;
    procedure SetItem(idx: integer; blk: TBlock); virtual;
    function  GetCount(): integer; virtual;

    procedure Paint(); override;

  public
    property Item[idx: Integer]: TBlock read GetItem write SetItem;
  published
    property Count: integer read GetCount;
    property Selected: integer read FSelected write SetSelected;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

procedure Register;

implementation

uses
  Controls,
  Windows,
  Math,
  GraphUtil;

procedure Register;
begin
  RegisterComponents('SDeanUtils', [TSDUBlocksPanel]);
end;

constructor TSDUBlocksPanel.Create(AOwner: TComponent);
begin
  inherited;

  FLastXY := Point(-1, -1);

  // Change TPanel default; we accept keypresses
  TabStop := TRUE;

  RemoveAllBlocks();
end;

destructor TSDUBlocksPanel.Destroy();
begin
  inherited;
end;

procedure TSDUBlocksPanel.RemoveAllBlocks();
begin
  SetLength(FBlocks, 0);
  SetLength(FBlockRects, 0);
end;


procedure TSDUBlocksPanel.Clear();
begin
  RemoveAllBlocks();
  // Flag as none selected
  FSelected := -1;
end;

procedure TSDUBlocksPanel.Add(blk: TBlock);
begin
  SetLength(FBlocks, (length(FBlocks) + 1));
  FBlocks[length(FBlocks)-1] := blk;

  SetLength(FBlockRects, (length(FBlockRects) + 1));
  FBlockRects[length(FBlockRects)-1] := Rect(0, 0, 0, 0);

  Invalidate();
end;

function TSDUBlocksPanel.GetItem(idx: integer): TBlock;
begin
  Result := FBlocks[idx];
end;

procedure TSDUBlocksPanel.SetItem(idx: integer; blk: TBlock);
begin
  FBlocks[idx] := blk;
  Invalidate();
end;

procedure TSDUBlocksPanel.Paint();
var
  i: integer;
  x: integer;
  useWidth: integer;
  currBlkWidth: integer;
  BevelPixels: integer;
  useRect: TRect;
  currRight: integer;
begin
  inherited;

  if (length(FBlocks) > 0) then
    begin
    BevelPixels := 0;
    if (BevelInner <> bvNone) then Inc(BevelPixels, BevelWidth);
    if (BevelOuter <> bvNone) then Inc(BevelPixels, BevelWidth);

    useRect := Rect(0, 0, ClientWidth, ClientHeight);
    InflateRect(useRect, -BevelPixels, -BevelPixels);
  
    // Purge display
    Canvas.Brush.Color := Color;
    Canvas.FillRect(useRect);

    x := useRect.Left;
    useWidth := useRect.Right - useRect.Left;
    for i:=low(FBlocks) to high(FBlocks) do
      begin
      currBlkWidth := trunc((useWidth/100) * FBlocks[i].Percentage);
    
      // Ensure we don't go over the bevel/edge of the control...
      currRight := min(x + currBlkWidth, useRect.Right);

      FBlockRects[i] := Rect(x, useRect.Top, currRight, useRect.Bottom);
      DrawBlock(i);

      // +1 to give a slight 
      x := x + currBlkWidth + 1;
      end;
    end;

end;

procedure TSDUBlocksPanel.DrawBlock(idx: integer);
var
  insideBounds: TRect;
  textHeight: integer;
  blk: TBlock;
  tmpBounds: TRect;
  normalFGColor: TColor;
  normalBKColor: TColor;
  stlTextLines: TStringList;
  i: integer;
  textTop: integer;
begin
  inherited;

  blk := FBLocks[idx];

  // Clear any lines on the display
  // We surround the Canvas blanking with "parent<>nil" to avoid getting
  // "Control '' has no parent window" errors when the component is dropped
  // onto a form
  if (parent<>nil) then
    begin
    normalFGColor:= Font.Color;
    normalBKColor:= Color;
    if (blk.BkColor <> clNone) then
      begin
      normalBKColor := blk.BkColor;
      end;

    Canvas.Brush.Color := normalBKColor;
    Canvas.Brush.Style := bsSolid;

    insideBounds := FBlockRects[idx];
    Canvas.FillRect(insideBounds);
    InflateRect(insideBounds, -4, -4);

    Canvas.Pen.Color := normalFGColor;
    Canvas.Brush.Color := normalBKColor;
    Canvas.Brush.Style := bsClear;

    if (Selected = idx) then
      begin
      Canvas.Pen.Color := GetHighLightColor(normalFGColor);
      Canvas.Brush.Color := GetHighLightColor(normalBKColor);
      // Refill the reduced rect to give highlighted background
      Canvas.FillRect(insideBounds);
      end;

    Canvas.Brush.Style := bsClear;

    Canvas.Font.Style := Font.Style + [fsBold];
    textHeight := Canvas.TextHeight('X');

    // We use a TStringList to split the caption up into separate lines if it's
    // for SDUCRLF's in it, then TextRect(...) the strings out as TextRect(...)
    // doesn't honour CRLFs, or "\n" in strings 
    stlTextLines:= TStringList.Create();
    try
      stlTextLines.text := blk.Caption;
      textTop := insideBounds.top;
      for i:=0 to (stlTextLines.count - 1) do
        begin
        Canvas.TextRect(
                        insideBounds,
                        insideBounds.left,
                        textTop,
                        stlTextLines[i]
                       );
        textTop := textTop + textHeight;
        end;

      Canvas.Font.Style := Font.Style - [fsBold];
      // Changed style could have altered the height of the font
      textHeight := Canvas.TextHeight('X');

      stlTextLines.text := blk.SubCaption;
      // textTop already set appropriately at this point
      for i:=0 to (stlTextLines.count - 1) do
        begin
        Canvas.TextRect(
                        insideBounds,
                        insideBounds.left,
                        textTop,
                        stlTextLines[i]
                       );
        textTop := textTop + textHeight;
        end;

      finally
        stlTextLines.Free();
      end;

    // Cell frame...
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clBlack;
    Canvas.FrameRect(FBlockRects[idx]);

    // Selected dottec focus rect..
    if (Selected = idx) then
      begin
      tmpBounds := FBlockRects[idx];
      InflateRect(tmpBounds, -1, -1);
      Canvas.Brush.Color := color;
      Canvas.DrawFocusRect(tmpBounds);
      end;

    end;

end;

procedure TSDUBlocksPanel.Click();
var
  i: integer;
  currBlk: TRect;
begin
  SetFocus();

  FSelected := -1;
  for i:=low(FBlockRects) to high(FBlockRects) do
    begin
    currBlk := FBlockRects[i];

    if (
        (currBlk.left   <= FLastXY.X) and
        (currBlk.right  >= FLastXY.X) and
        (currBlk.top    <= FLastXY.Y) and
        (currBlk.bottom >= FLastXY.Y)
       ) then
      begin
      Selected := i;
      break;
      end;
    end;

  inherited;
end;

procedure TSDUBlocksPanel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  FLastXY := Point(X, Y);
  inherited;
end;

procedure TSDUBlocksPanel.SetSelected(idx: integer);
begin
  FSelected := idx;
  Invalidate();

  if Assigned(FOnChanged) then
    begin
    FOnChanged(self);
    end;
end;

function TSDUBlocksPanel.GetCount(): integer;
begin
  Result := length(FBlocks);
end;

procedure TSDUBlocksPanel.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;

  if (
      (Key = VK_LEFT) or
      (Key = VK_UP)
     ) then
    begin
    if (Selected < low(FBlockRects)) then
      begin
      // None selected; select first
      Selected := low(FBlockRects);
      end
    else if (Selected = low(FBlockRects)) then
      begin
      // Do nothing; 1st one already selected
      end
    else
      begin
      Selected := Selected - 1;
      end

    end
  else if (
           (Key = VK_RIGHT) or
           (Key = VK_DOWN)
          ) then
    begin
    if (
        (Selected < low(FBlockRects)) or
        (Selected > high(FBlockRects))
       )  then
      begin
      // None selected; select last
      Selected := high(FBlockRects);
      end
    else if (Selected = high(FBlockRects)) then
      begin
      // Do nothing; 1st one already selected
      end
    else
      begin
      Selected := Selected + 1;
      end

    end;

end;

procedure TSDUBlocksPanel.KeyPress(var Key: Char);
begin
//ko
end;

procedure TSDUBlocksPanel.DoEnter;
begin
  if (Selected < low(FBlockRects)) then
    begin
    Selected := low(FBlockRects);
    end;

  inherited;
end;

procedure TSDUBlocksPanel.WMGetDlgCode(var Message: TWMGetDlgCode); 
begin
  inherited;
  Message.Result := Message.Result or DLGC_WANTARROWS;
end;

END.


