import cssgrid
import cssgrid/[gridtypes, constraints, layout, parser, numberTypes]
export cssgrid

type
  Sizing* = enum
    Fit
    Fill
    Grow
    Fixed

  Justify* = enum
    Start
    Center
    End
    Between
    Around
    Evenly

  Align* = enum
    Start
    Center
    End
    Stretch
    Between
    Around
    Evenly

  Direction* = enum
    Horizontal
    Vertical

  Widget* = ref object of RootObj
    # Layout output
    box*: UiBox
    bpad*: UiBox
    bmin*, bmax*: UiSize

    # Sizing configuration
    sizing*: Sizing
    growFactor*: float

    # Explicit constraints
    width*, height*: Constraint
    minWidth*, maxWidth*: Constraint
    minHeight*, maxHeight*: Constraint

    # cssgrid interface fields
    gridItem*: GridItem
    gridTemplate*: GridTemplate
    cxSize*: array[GridDir, Constraint]
    cxOffset*: array[GridDir, Constraint]
    cxMin*: array[GridDir, Constraint]
    cxMax*: array[GridDir, Constraint]
    cxPadOffset*: array[GridDir, Constraint]
    cxPadSize*: array[GridDir, Constraint]

    # Tree structure
    parent*: Widget
    children*: seq[Widget]
    frame*: Frame

  Frame* = ref object
    windowSize*: UiBox

  Spacer* = ref object of Widget
    ## Flexible empty space widget

method render*(widget: Widget) {.base.} =
  ## Base render method - override in concrete widgets
  ## At this point widget.box contains computed position/size
  discard

proc getParent*(widget: Widget): Widget =
  widget.parent

proc getSkipLayout*(widget: Widget): bool =
  false

proc getFrameBox*(widget: Widget): UiBox =
  if widget.frame.isNil:
    uiBox(0, 0, 0, 0)
  else:
    widget.frame.windowSize

proc generateConstraints*(widget: Widget) =
  ## Convert high-level sizing modes to cssgrid constraints
  case widget.sizing
  of Fit:
    # Auto-size to content
    widget.cxSize[dcol] = csAuto()
    widget.cxSize[drow] = csAuto()

  of Fill:
    # Item should auto-size to fill its grid cell
    # csAuto() makes the item take its intrinsic size or stretch based on alignment
    widget.cxSize[dcol] = csAuto()
    widget.cxSize[drow] = csAuto()
    # Store track size in width/height for setupGridTemplate
    widget.width = 1'fr
    widget.height = 1'fr

  of Grow:
    # Item should auto-size to fill its grid cell
    let fr = widget.growFactor
    widget.cxSize[dcol] = csAuto()
    widget.cxSize[drow] = csAuto()
    # Store track size
    widget.width = csFrac(fr)
    widget.height = csFrac(fr)

  of Fixed:
    # Use explicit width/height constraints
    if widget.width.kind != UiNone:
      widget.cxSize[dcol] = widget.width
    else:
      widget.cxSize[dcol] = csAuto()

    if widget.height.kind != UiNone:
      widget.cxSize[drow] = widget.height
    else:
      widget.cxSize[drow] = csAuto()

  # Apply min/max constraints
  if widget.minWidth.kind != UiNone:
    widget.cxMin[dcol] = widget.minWidth
  if widget.maxWidth.kind != UiNone:
    widget.cxMax[dcol] = widget.maxWidth
  if widget.minHeight.kind != UiNone:
    widget.cxMin[drow] = widget.minHeight
  if widget.maxHeight.kind != UiNone:
    widget.cxMax[drow] = widget.maxHeight

proc mapJustify*(j: Justify): ConstraintBehavior =
  ## Convert Justify enum to cssgrid ConstraintBehavior
  case j
  of Start: CxStart
  of Center: CxCenter
  of End: CxEnd
  of Between, Around, Evenly: CxStretch  # Use Stretch for now

proc mapAlign*(a: Align): ConstraintBehavior =
  ## Convert Align enum to cssgrid ConstraintBehavior
  case a
  of Start: CxStart
  of Center: CxCenter
  of End: CxEnd
  of Stretch: CxStretch
  of Between, Around, Evenly: CxStretch  # Use Stretch for now

proc sizing*(widget: Widget, mode: Sizing): Widget {.discardable.} =
  ## Set sizing mode
  widget.sizing = mode
  return widget

proc grow*(widget: Widget, factor: float = 1.0): Widget {.discardable.} =
  ## Set widget to grow with given factor
  widget.sizing = Grow
  widget.growFactor = factor
  return widget

proc width*(widget: Widget, w: int): Widget {.discardable.} =
  ## Set explicit width in pixels
  widget.width = csFixed(w.float)
  widget.sizing = Fixed
  return widget

proc height*(widget: Widget, h: int): Widget {.discardable.} =
  ## Set explicit height in pixels
  widget.height = csFixed(h.float)
  widget.sizing = Fixed
  return widget

proc size*(widget: Widget, w, h: int): Widget {.discardable.} =
  ## Set explicit width and height in pixels
  widget.width = csFixed(w.float)
  widget.height = csFixed(h.float)
  widget.sizing = Fixed
  return widget

proc minWidth*(widget: Widget, w: int): Widget {.discardable.} =
  ## Set minimum width constraint
  widget.minWidth = csFixed(w.float)
  return widget

proc maxWidth*(widget: Widget, w: int): Widget {.discardable.} =
  ## Set maximum width constraint
  widget.maxWidth = csFixed(w.float)
  return widget

proc minHeight*(widget: Widget, h: int): Widget {.discardable.} =
  ## Set minimum height constraint
  widget.minHeight = csFixed(h.float)
  return widget

proc maxHeight*(widget: Widget, h: int): Widget {.discardable.} =
  ## Set maximum height constraint
  widget.maxHeight = csFixed(h.float)
  return widget

proc newSpacer*(): Spacer =
  ## Create a flexible spacer that fills available space
  result = Spacer(
    sizing: Fill,
    growFactor: 1.0
  )

proc newSpacer*(size: int): Spacer =
  ## Create a fixed-size spacer
  result = Spacer(
    sizing: Fixed,
    width: csFixed(size.float),
    height: csFixed(size.float)
  )
