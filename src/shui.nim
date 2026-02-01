import cssgrid
import cssgrid/[gridtypes, constraints, layout, parser, numberTypes]

import shui/[widgets, containers, ui]
export widgets, containers, ui

proc layout*(widget: Widget, parentBox: UiBox) =
  ## Compute layout for widget tree using cssgrid
  if widget of Container:
    let container = Container(widget)

    # Set container's box
    container.box = parentBox

    # Setup grid template
    setupGridTemplate(container)

    # Account for padding
    let pl = container.padding[0].float.UiScalar
    let pt = container.padding[1].float.UiScalar
    let pr = container.padding[2].float.UiScalar
    let pb = container.padding[3].float.UiScalar

    var contentBox = parentBox
    contentBox.x = contentBox.x + pl
    contentBox.y = contentBox.y + pt
    contentBox.w = contentBox.w - (pl + pr)
    contentBox.h = contentBox.h - (pb + pt)

    # Set up GridNode for cssgrid
    # We'll use Container directly as it has the required fields
    container.box = contentBox

    # Set container size constraints
    container.cxSize[dcol] = csFixed(contentBox.w.float)
    container.cxSize[drow] = csFixed(contentBox.h.float)

    # Create grid items for children and explicitly place them
    for i, child in container.children:
      child.gridItem = newGridItem()
      # Set parent reference
      child.parent = container

      # Explicitly place in the grid (not auto-placement)
      if container.direction == Horizontal:
        # Row: place in columns
        child.gridItem.span[dcol] = (i + 1).int16 .. (i + 2).int16
        child.gridItem.span[drow] = 1.int16 .. 2.int16
      else:
        # Column: place in rows
        child.gridItem.span[dcol] = 1.int16 .. 2.int16
        child.gridItem.span[drow] = (i + 1).int16 .. (i + 2).int16

    # Compute layout using cssgrid
    computeLayout(container)

    # Recursively layout child containers
    for child in container.children:
      if child of Container:
        layout(child, child.box)
  else:
    # Leaf widget - box already computed by parent
    widget.box = parentBox

proc renderTree*(widget: Widget) =
  ## Render widget tree depth-first
  widget.render()

  if widget of Container:
    for child in Container(widget).children:
      renderTree(child)

proc iterDepthFirst*(widget: Widget, call: proc(w: Widget): void) =
  call(widget)
  if widget of Container:
    for child in Container(widget).children:
      iterDepthFirst(child, call)
