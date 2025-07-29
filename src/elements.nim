type
  Box* = tuple[x, y, w, h: float]

  Direction* = enum
    Col
    Row

  SizingKind* = enum
    Fixed
    Grow
    Fit

  SizingAxis* = object
    case kind*: SizingKind
    of Fixed:
      fixed*: float
    else:
      discard

  Sizing* = array[Direction, SizingAxis]

  ElemId* = int

  Elem* = ref object
    id*: ElemId
    parent*: Elem
    children*: seq[Elem]

    box*: Box
    size*: Sizing
    dir*: Direction

proc isFixed*(elem: Elem, dir: Direction): bool =
  elem.size[dir].kind == Fixed

proc isGrow*(elem: Elem, dir: Direction): bool =
  elem.size[dir].kind == Grow

proc isFit*(elem: Elem, dir: Direction): bool =
  elem.size[dir].kind == Fit

proc addChild*(elem: Elem, child: Elem) =
  elem.children.add(child)
  child.parent = elem
