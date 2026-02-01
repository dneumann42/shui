import cssgrid
import cssgrid/[gridtypes, constraints, parser, numberTypes]

import widgets

type
  Container* = ref object of Widget
    direction*: Direction
    justify*: Justify
    align*: Align
    gap*: int
    padding*: array[4, int]  # [left, top, right, bottom]

proc Row*(justify: Justify = Start, align: Align = Stretch): Container =
  ## Create a horizontal container (children flow left to right)
  # When centering, use Fit (size to content) instead of Fill
  # This allows parent containers to properly center this container
  let sizing = if justify == Center or align == Center: Fit else: Fill
  result = Container(
    direction: Horizontal,
    justify: justify,
    align: align,
    sizing: sizing,
    growFactor: 1.0,
    gridTemplate: newGridTemplate()
  )

proc Column*(justify: Justify = Start, align: Align = Stretch): Container =
  ## Create a vertical container (children flow top to bottom)
  # When centering, use Fit (size to content) instead of Fill
  # This allows parent containers to properly center this container
  let sizing = if justify == Center or align == Center: Fit else: Fill
  result = Container(
    direction: Vertical,
    justify: justify,
    align: align,
    sizing: sizing,
    growFactor: 1.0,
    gridTemplate: newGridTemplate()
  )

proc add*(container: Container, child: Widget): Container {.discardable.} =
  ## Add a child widget to the container
  container.children.add(child)
  return container

proc gap*(container: Container, size: int): Container {.discardable.} =
  ## Set gap between children
  container.gap = size
  return container

proc justify*(container: Container, j: Justify): Container {.discardable.} =
  ## Set main axis alignment
  container.justify = j
  return container

proc align*(container: Container, a: Align): Container {.discardable.} =
  ## Set cross axis alignment
  container.align = a
  return container

proc padding*(container: Container, all: int): Container {.discardable.} =
  ## Set padding on all sides
  container.padding = [all, all, all, all]
  return container

proc padding*(container: Container, x, y: int): Container {.discardable.} =
  ## Set padding (horizontal, vertical)
  container.padding = [x, y, x, y]
  return container

proc padding*(container: Container, left, top, right, bottom: int): Container {.discardable.} =
  ## Set padding on each side individually
  container.padding = [left, top, right, bottom]
  return container

proc setupGridTemplate*(container: Container) =
  ## Configure cssgrid GridTemplate based on container and children
  var gt = container.gridTemplate

  # Generate constraints for all children first
  for child in container.children:
    generateConstraints(child)

  if container.direction == Horizontal:
    # Row container: children flow as columns
    gt.autoFlow = grColumn

    # Each child becomes a column track
    # Use width constraint for track size (cxSize is for cell filling)
    for child in container.children:
      let trackConstraint = if child.width.kind != UiNone: child.width else: child.cxSize[dcol]
      gt.lines[dcol].add(initGridLine(trackConstraint))

    # Single row that fills height
    gt.lines[drow].add(initGridLine(1'fr))

  else:
    # Column container: children flow as rows
    gt.autoFlow = grRow

    # Each child becomes a row track
    # Use height constraint for track size
    for child in container.children:
      let trackConstraint = if child.height.kind != UiNone: child.height else: child.cxSize[drow]
      gt.lines[drow].add(initGridLine(trackConstraint))

    # Single column that fills width
    gt.lines[dcol].add(initGridLine(1'fr))

  # Apply gaps
  gt.gaps[dcol] = container.gap.float.UiScalar
  gt.gaps[drow] = container.gap.float.UiScalar

  # Apply alignment
  # In CSS Grid, axes are always:
  # - justifyItems controls horizontal alignment (inline axis)
  # - alignItems controls vertical alignment (block axis)
  # NOTE: We handle Center manually in layout, so don't pass it to grid
  gt.justifyItems = if container.justify == Center: CxStart else: mapJustify(container.justify)
  gt.alignItems = if container.align == Center: CxStart else: mapAlign(container.align)
