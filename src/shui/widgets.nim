import options, macros, fusion/matching, sequtils, sugar, typetraits, typeinfo
import std/enumerate

type
  WidgetState* = enum
    normal
    active
    disabled

  HAlign* = enum
    left
    center
    right
  
  VAlign* = enum
    top
    center
    bottom

  Align* = tuple[v: VAlign, h: HAlign]

  Widget* = ref object of RootObj
    isHot*: bool
    state*: WidgetState = normal
    lastState*: WidgetState = normal
    align*: Align
    base: Widget
    pos*, size*: (float, float)

  Layout* = ref object of Widget
    nodes*: seq[Widget]

  Dialog* = ref object of Widget
    id*: string
    layout*: Layout
    noBackdrop* = false

  Panel* = ref object of Layout
    fixedSize* = none((float, float))

  Horizontal* = ref object of Layout
  Vertical* = ref object of Layout

  Element* = ref object of Widget

  Text* = ref object of Element
    text*: string

  Button* = ref object of Text
    callback*: proc(): void

  Label* = ref object of Text

method spacing*(layout: Layout): float {.base.} = discard
method spacing*(layout: Vertical): float = layout.spacing
method spacing*(layout: Horizontal): float = layout.spacing
method spacing*(layout: Panel): float = layout.spacing

method measure*(elem: Element): (float, float) {.base.} = discard

proc x*(w: Widget): auto = w.pos[0]
proc y*(w: Widget): auto = w.pos[1]
proc w*(w: Widget): auto = w.size[0]
proc h*(w: Widget): auto = w.size[1]

converter toTuple*(w: Widget): (float, float, float, float) =
  (w.x, w.y, w.w, w.h)

proc name*(widget: Widget): string =
  if widget of Horizontal: "Horizontal"
  elif widget of Vertical: "Vertical"
  elif widget of Panel: "Panel"
  elif widget of Button: "Button"
  elif widget of Label: "Label"
  elif widget of Dialog: "Dialog"
  else: "Widget"

proc `$`*(widget: Widget): string =
  result = name(widget)
  if widget of Layout:
    result &= "("
    for i, node in enumerate(widget.Layout.nodes):
      result &= $node & (if i < widget.Layout.nodes.len - 1: ", " else: "")
    result &= ")"
  elif widget of Dialog:
    result = "("
    result &= " " & $widget.Dialog.layout
    result &= ")"

proc `+`*(a, b: (float, float)): (float, float) =
  (a[0] + b[0], a[1] + b[1])

proc `+=`*(a: var (float, float), b: (float, float)) =
  a[0] += b[0]
  a[1] += b[1]

proc `-`*(a, b: (float, float)): (float, float) =
  (a[0] - b[0], a[1] - b[1])

proc `-=`*(a: var (float, float), b: (float, float)) =
  a[0] -= b[0]
  a[1] -= b[1]

macro layoutOr*(w, a, b: untyped): untyped =
  quote do: (if `w` is Layout: `a` else: `b`)

proc base*[T: Widget](w: T): Option[T] =
  if not w.base.isNil:
    result = some(w.base)

proc `base=`*(w: var Widget, p: Widget) =
  w.base = p

proc text*(widget: Widget): Option[string] =
  if widget of Text:
    widget.Text.text.some
  else:
    none(string)

proc add*(l: Layout, nodes: varargs[Widget]) =
  for node in nodes:
    if node.isNil:
      continue
    node.base = l
    l.nodes.add(node)

proc getDialogById*(root: Widget, dialogId: string): Option[Dialog] =
  if root of Element:
    return none(Dialog)
  elif root of Layout:
    for node in root.Layout.nodes:
      if Some(@dialog) ?= getDialogById(node, dialogId):
        return dialog.some
  elif root of Dialog:
    if root.Dialog.id == dialogId:
      return root.Dialog.some()
    else:
      return getDialogById(root.Dialog.layout, dialogId)

proc getDialogs*(root: Widget): seq[Dialog] =
  result = @[]
  if root of Element:
    return
  elif root of Layout:
    for node in root.Layout.nodes:
      result = result.concat(node.getDialogs())
  elif root of Dialog:
    result = root.Dialog.layout.getDialogs()
    result.add(root.Dialog)

proc label*(text = ""): Label =
  result = Label(text: text)

proc button*(text = "", clicked: () -> void): Button =
  result = Button(text: text, callback: clicked)

template panel*(blk: untyped): Panel =
  let (w, h) = blk()
  Panel(nodes: @[], fixedSize: (w, h).some)

proc vertical*(nodes: varargs[Widget]): Layout =
  result = Vertical(nodes: @[])
  result.add(nodes)

proc horizontal*(nodes: varargs[Widget]): Layout =
  result = Horizontal(nodes: @[])
  result.add(nodes)