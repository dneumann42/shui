import std/[sequtils, algorithm]

import elements
import pixie

{.experimental: "views".}

type UI* = object
  elemId = 0

converter toRect*(box: Box): Rect =
  rect(vec2(box.x, box.y), vec2(box.w, box.h))

proc nextId(ui: var UI): int =
  inc(ui.elemId)
  result = ui.elemId

proc setBoxSize*(elem: Elem, dir: Direction, size: float) =
  if dir == Col:
    elem.box.w = size
  elif dir == Row:
    elem.box.h = size

proc updateFixedSize*(elem: Elem) =
  for child in elem.children:
    child.updateFixedSize()
  for dir in low(Direction) .. high(Direction):
    if elem.isFixed(dir):
      setBoxSize(elem, dir, elem.size[dir].fixed)

proc updatePositions*(elem: Elem) =
  # Depth last traversal
  var cursor = 0.0
  for child in elem.children:
    if elem.dir == Row:
      child.box.x = elem.box.x + cursor
      cursor += child.box.w
    else:
      child.box.y = elem.box.y + cursor
      cursor += child.box.h
  for child in elem.children:
    child.updatePositions()

proc updateLayout*(elem: Elem) =
  elem.updateFixedSize()
  elem.updatePositions()

proc debugRender*(root: Elem, ctx: Context) =
  ctx.strokeStyle = rgba(255, 100, 0, 255)
  ctx.lineWidth = 2.0
  ctx.strokeRect(root.box)

when isMainModule:
  let image = newImage(640, 480)
  image.fill(rgba(0, 0, 0, 255))

  let ctx = newContext(image)

  var root = Elem(
    size: [ #
      SizingAxis(kind: Fixed, fixed: 100), #
      SizingAxis(kind: Fixed, fixed: 100),
    ]
  )

  root.updateLayout()
  root.debugRender(ctx)

  image.writeFile("demo.png")
