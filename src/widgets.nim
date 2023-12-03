import options, macros

type
  Widget* = ref object of RootObj
    parent: Layout

  Layout* = ref object of Widget
    cursor*: tuple[x, y: float]
    children*: seq[Widget]

  Horizontal* = ref object of Layout
  Vertical* = ref object of Layout

  Element* = ref object of Widget

  Text* = ref object of Element
    text*: string

  Button* = ref object of Text
  Label* = ref object of Text

method spacing*(layout: Layout): float {.base.} = discard
method spacing*(layout: Vertical): float = layout.spacing
method spacing*(layout: Horizontal): float = layout.spacing

method measure*(elem: Element): (float, float) {.base.} = discard

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

converter toWidget*[T: Widget](t: T): T = t.T

macro layoutOr*(w, a, b: untyped): untyped =
  quote do: (if `w` is Layout: `a` else: `b`)

proc parent*[T: Widget](w: T): Option[T] =
  if not w.parent.isNil:
    result = some(w.parent.T)

proc text*(widget: Widget): Option[string] =
  if widget of Text:
    widget.Text.text.some
  else:
    none(string)

proc addChildren*(l: Layout, children: varargs[Widget]) =
  for child in children:
    child.parent = l
    l.children.add(child)
