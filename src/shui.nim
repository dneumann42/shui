import pixie
import std/[sequtils, algorithm]

{.experimental: "views".}

type
  Box* = tuple[x, y, w, h: float]

  SizingKind* = enum
    Fixed
    Grow
    Fit

  SizingAxis* = object
    case kind: SizingKind
    of Fixed:
      fixed: float
    else:
      discard

  Sizing* = object
    col: SizingAxis
    row: SizingAxis

  Direction* = enum
    Col
    Row

  ElemId = int

  Elem* = object
    box: Box
    size: Sizing
    dir: Direction
    color: ColorRGBA
    sized = false
    id: ElemId = 0
    parent: ElemId = 0
    depth = 0

  UI* = object
    elemId = 0
    parent = 0
    containers: seq[ElemId]
    elems: seq[Elem]

proc nextId(ui: var UI): int =
  inc(ui.elemId)
  result = ui.elemId

proc initElem(ui: var UI): Elem =
  result = Elem(id: ui.nextId())

proc add(ui: var UI, elem: Elem) =
  var el = elem
  el.parent = ui.parent
  ui.elems.add(el)

proc getElem(ui: UI, id: ElemId): Elem =
  for e in ui.elems:
    if e.id == id:
      return e

proc mgetElem(ui: UI, id: ElemId): var Elem =
  for e in ui.elems.mitems:
    if e.id == id:
      return e

proc beginContainer(ui: var UI) =
  var parent = ui.initElem()
  parent.depth = ui.getElem(ui.parent).depth + 1
  ui.parent = parent.id
  ui.containers.add(parent.id)

proc endContainer(ui: var UI) =
  ui.parent = 0

template withElem(ui: var UI, blk: untyped) =
  block:
    var elem {.inject.} = ui.initElem()
    blk
    ui.add(elem)

iterator mchildren(ui: var UI, id: ElemId): var Elem =
  for el in ui.elems.mitems:
    if el.parent = id:
      yield el

proc updateFixedSizes*(ui: var UI) =
  for e in ui.elems.mitems:
    if e.size.col.kind == Fixed:
      e.box.h = e.size.col.fixed
    if e.size.row.kind == Fixed:
      e.box.w = e.size.row.fixed

proc updatePositions*(ui: var UI) =
  var sortedUI = ui
  sort(
    sortedUI.containers,
    proc(a, b: ElemId): auto =
      sortedUI.getElem(a).depth.cmp(sortedUI.getElem(b).depth),
  )
  for c in sortedUI.containers:
    var parent = ui.mgetElem(c)
    var cursor = 0.0
    for child in ui.mchildren(parent):
      discard

proc updateLayout*(ui: var UI) =
  ui.updateFixedSizes()

  # start with containers of the highest depth to lowest

  ui.updatePositions()

proc beginUI(ui: var UI) =
  ui.elemId = 0

proc endUI(ui: var UI) =
  ui.updateLayout()

proc render*(ui: UI) =
  let img = newImage(800, 600)
  img.fill(rgba(0, 0, 0, 255))
  let ctx = newContext(img)
  for el in ui.elems:
    ctx.fillStyle = el.color
    ctx.fillRect(rect(vec2(el.box.x, el.box.y), vec2(el.box.w, el.box.h)))
  img.writeFile("demo.png")

when isMainModule:
  var ui = UI(elems: @[])
  ui.beginUI()

  ui.beginContainer()
  ui.withElem:
    elem.size = Sizing(
      col: SizingAxis(kind: Fixed, fixed: 100.0),
      row: SizingAxis(kind: Fixed, fixed: 100.0),
    )
    elem.color = rgba(255, 255, 0, 255)
  ui.withElem:
    elem.size = Sizing(
      col: SizingAxis(kind: Fixed, fixed: 100.0),
      row: SizingAxis(kind: Fixed, fixed: 100.0),
    )
    elem.color = rgba(255, 0, 0, 255)
  ui.endContainer()

  ui.endUI()
  ui.render()
