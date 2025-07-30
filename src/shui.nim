import std/[strformat]

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
  if dir == Row:
    elem.box.w = size
  else:
    elem.box.h = size

proc updateFixedSize*(elem: Elem) =
  for child in elem.children:
    child.updateFixedSize()
  for dir in low(Direction) .. high(Direction):
    if elem.isFixed(dir):
      setBoxSize(elem, dir, elem.size[dir].fixed)

proc calculateFittedSize(elem: Elem, dir: Direction): float =
  # Calculate what the fitted size should be based on children
  result = 0.0
  for child in elem.children:
    if elem.dir == dir:
      # Children are laid out in this direction, so sum them
      if dir == Row:
        result += child.box.w
      else:
        result += child.box.h
    else:
      # Children are stacked perpendicular to this direction, so take max
      if dir == Row:
        result = max(result, child.box.w)
      else:
        result = max(result, child.box.h)

proc updateLayout*(elem: Elem) =
  # First pass: set all fixed sizes
  elem.updateFixedSize()

  # Multiple passes to resolve interdependent sizing
  for pass in 0 ..< 10:
    var changed = false

    # Process all elements in tree order (parent before children)
    proc processElement(e: Elem): bool =
      var elementChanged = false
      let oldW = e.box.w
      let oldH = e.box.h

      # Step 1: Update fitted sizes
      for dir in [Row, Col]:
        if e.isFit(dir):
          let newSize = calculateFittedSize(e, dir)
          setBoxSize(e, dir, newSize)
          if abs(newSize - (if dir == Row: oldW else: oldH)) > 0.001:
            elementChanged = true

      # Step 2: Distribute grow space to children
      for dir in [Row, Col]:
        # Calculate available space for growing children
        let totalSpace = if dir == Row: e.box.w else: e.box.h
        var usedSpace = 0.0
        var growCount = 0

        for child in e.children:
          if child.isGrow(dir):
            growCount += 1
          else:
            # Fixed or fitted children use their current space
            if dir == Row:
              usedSpace += child.box.w
            else:
              usedSpace += child.box.h

        if e.dir == dir and growCount > 0:
          # Same direction: distribute remaining space among grow children
          let availableSpace = max(0.0, totalSpace - usedSpace)
          let sizePerGrowChild = availableSpace / growCount.toFloat

          for child in e.children:
            if child.isGrow(dir):
              let oldChildSize = if dir == Row: child.box.w else: child.box.h
              setBoxSize(child, dir, sizePerGrowChild)
              if abs(sizePerGrowChild - oldChildSize) > 0.001:
                elementChanged = true
        elif e.dir != dir and growCount > 0:
          # Perpendicular direction: grow children fill entire available space
          for child in e.children:
            if child.isGrow(dir):
              let oldChildSize = if dir == Row: child.box.w else: child.box.h
              setBoxSize(child, dir, totalSpace)
              if abs(totalSpace - oldChildSize) > 0.001:
                elementChanged = true

      # Process children recursively
      for child in e.children:
        if processElement(child):
          elementChanged = true

      return elementChanged

    if processElement(elem):
      changed = true

    if not changed:
      break

  # Final pass: set positions
  proc updatePositions(e: Elem) =
    var cursor = 0.0
    for child in e.children:
      if e.dir == Row:
        child.box.x = e.box.x + cursor
        child.box.y = e.box.y
        cursor += child.box.w
      else:
        child.box.x = e.box.x
        child.box.y = e.box.y + cursor
        cursor += child.box.h
      updatePositions(child)

  updatePositions(elem)

const Colors = [
  rgba(255, 0, 0, 155),
  rgba(0, 255, 0, 155),
  rgba(0, 0, 255, 155),
  rgba(255, 255, 0, 155),
  rgba(0, 255, 255, 155),
  rgba(255, 0, 255, 155),
]

proc nextColor(): ColorRGBA =
  var i {.global.} = 0
  result = Colors[i]
  inc(i)
  if i == Colors.len:
    i = 0

proc debugRenderElem(elem: Elem, ctx: Context) =
  var color = nextColor().color()
  ctx.fillStyle = lighten(color, 0.3)
  ctx.fillRect(elem.box)
  ctx.strokeStyle = color
  ctx.lineWidth = 4.0
  ctx.strokeRect(elem.box)
  for child in elem.children:
    debugRenderElem(child, ctx)

  let txt =
    &"{elem.box.x:1} {elem.box.y:1} {elem.box.w:1} {elem.box.h:1} {elem.size[Row].kind} {elem.size[Col].kind}"
  ctx.fillStyle = rgba(0, 0, 0, 255)
  ctx.fillText(txt, elem.box.x + elem.box.w / 2.0, elem.box.y + elem.box.h / 2.0)

proc debugRender*(root: Elem, ctx: Context) =
  debugRenderElem(root, ctx)

when isMainModule:
  let image = newImage(640, 480)
  image.fill(rgba(0, 0, 0, 255))

  let ctx = newContext(image)
  ctx.font = "Roboto-Regular_1.ttf"
  ctx.fontSize = 12

  var root = Elem(
    dir: Col,
    size: [SizingAxis(kind: Fixed, fixed: 600), SizingAxis(kind: Fixed, fixed: 400)],
  )

  var z = Elem(dir: Row, size: [SizingAxis(kind: Fit), SizingAxis(kind: Grow)])
  var y =
    Elem(dir: Row, size: [SizingAxis(kind: Grow), SizingAxis(kind: Grow)])
  var x =
    Elem(dir: Row, size: [SizingAxis(kind: Grow), SizingAxis(kind: Grow)])

  var u =
    Elem(dir: Row, size: [SizingAxis(kind: Grow), SizingAxis(kind: Grow)])
  var v =
    Elem(dir: Row, size: [SizingAxis(kind: Fixed, fixed: 100), SizingAxis(kind: Grow)])

  var a = Elem(
    size: [SizingAxis(kind: Fixed, fixed: 100), SizingAxis(kind: Fixed, fixed: 100)]
  )
  var b = Elem(
    size: [ #
      SizingAxis(kind: Fixed, fixed: 140), SizingAxis(kind: Grow)
    ]
  )
  z.addChild(a)
  z.addChild(b)

  root.addChild(z)
  root.addChild(y)
  root.addChild(x)

  x.addChild(u)
  x.addChild(v)


  echo "Before layout:"
  echo &"root: {root.box}"
  echo &"z: {z.box}"
  echo &"y: {y.box}"
  echo &"a: {a.box}"
  echo &"b: {b.box}"

  root.updateLayout()

  echo "After layout:"
  echo &"root: {root.box}"
  echo &"z: {z.box}"
  echo &"y: {y.box}"
  echo &"a: {a.box}"
  echo &"b: {b.box}"

  root.debugRender(ctx)

  image.writeFile("demo.png")
