module jcli.text.common;

struct Vector
{
    int x;
    int y;
}

struct Rect
{
    int left;
    int top;
    int right;
    int bottom;

    @safe @nogc nothrow pure const:

    int width() { return this.right - this.left; }
    int height() { return this.bottom - this.top; }
}

enum Alignment
{
    left,
    center,
    right
}

enum Direction
{
    vertical,
    horizontal
}

enum Corner
{
    topLeft,
    topRight,
    botLeft,
    botRight
}