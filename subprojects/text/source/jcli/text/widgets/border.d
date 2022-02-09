module jcli.text.widgets.border;

import jcli.text;

enum BorderStyle
{
    none,
    top     = 1 << 0,
    right   = 1 << 1,
    bottom  = 1 << 2,
    left    = 1 << 3,
    
    all     = top | right | bottom | left
}

struct BorderWidget
{
    Rect blockArea;
    BorderStyle borders;
    AnsiColour fg;
    AnsiColour bg;
    string title;
    Alignment titleAlign;

    void render(const Layout layout, scope TextBuffer buffer)
    {
        const area = layout.blockRectToRealRect(this.blockArea);
        const style = AnsiStyleSet.init.bg(this.bg).fg(this.fg);

        buffer.fillCells(this.innerArea(layout), " ", style);

        if(borders & BorderStyle.top) buffer.fillCells(Rect(area.left, area.top, area.right, area.top+1), "─", style);
        if(borders & BorderStyle.bottom) buffer.fillCells(Rect(area.left, area.bottom-1, area.right, area.bottom), "─", style);
        if(borders & BorderStyle.left) buffer.fillCells(Rect(area.left, area.top, area.left+1, area.bottom), "│", style);
        if(borders & BorderStyle.right) buffer.fillCells(Rect(area.right-1, area.top, area.right, area.bottom), "│", style);

        if((borders & BorderStyle.left) && (borders & BorderStyle.top))
            buffer.setCell(Vector(area.left, area.top), "┌", style);
        if((borders & BorderStyle.right) && (borders & BorderStyle.top))
            buffer.setCell(Vector(area.right-1, area.top), "┐", style);
        if((borders & BorderStyle.left) && (borders & BorderStyle.bottom))
            buffer.setCell(Vector(area.left, area.bottom-1), "└", style);
        if((borders & BorderStyle.right) && (borders & BorderStyle.bottom))
            buffer.setCell(Vector(area.right-1, area.bottom-1), "┘", style);

        if(this.title)
        {
            const EXTRA_CHARS = 2;
            const SIDE_MARGIN = 2;
            Vector start;
            final switch(this.titleAlign) with(Alignment)
            {
                case left:
                    start = Vector(area.left + SIDE_MARGIN, area.top);
                    break;
                case right:
                    start = Vector(area.right - (SIDE_MARGIN + EXTRA_CHARS + cast(int)this.title.length), area.top);
                    break;
                case center:
                    start = Vector(area.left + (area.width / 2) - ((EXTRA_CHARS + cast(int)this.title.length) / 2), area.top);
                    break;
            }
            auto end = Vector(start.x + EXTRA_CHARS + cast(int)this.title.length, start.y + 1);
            start    = oobVector(OnOOB.constrain, Vector(buffer.width, buffer.height), start);
            end      = oobVector(OnOOB.constrain, Vector(buffer.width, buffer.height), end);

            Vector _1;
            const rect = Rect(start.x+1, start.y, end.x, end.y);
            buffer.setCell(start, " ", style);
            buffer.setString(rect, this.title, _1, style);
            buffer.setCell(Vector(start.x + 1 + cast(int)this.title.length, start.y), " ", style);
        }
    }

    @safe const:

    Rect innerArea(const Layout parent)
    {
        const area = parent.blockRectToRealRect(this.blockArea);
        return Rect(
            (this.borders & BorderStyle.left) ? area.left + 1 : area.left,
            (this.borders & BorderStyle.top) ? area.top + 1 : area.top,
            (this.borders & BorderStyle.right) ? area.right - 1 : area.right,
            (this.borders & BorderStyle.bottom) ? area.bottom - 1 : area.bottom,
        );
    }
}

struct BorderWidgetBuilder
{
    private BorderWidget _widget;

    @safe @nogc nothrow pure:

    BorderWidgetBuilder withBlockArea(Rect area)
    {
        this._widget.blockArea = area;
        return this;
    }

    BorderWidgetBuilder withBorderStyle(BorderStyle style)
    {
        this._widget.borders = style;
        return this;
    }

    BorderWidgetBuilder withForeground(AnsiColour fg)
    {
        this._widget.fg = fg;
        return this;
    }

    BorderWidgetBuilder withBackground(AnsiColour bg)
    {
        this._widget.bg = bg;
        return this;
    }

    BorderWidgetBuilder withTitle(string title)
    {
        this._widget.title = title;
        return this;
    }

    BorderWidgetBuilder withTitleAlignment(Alignment alignment)
    {
        this._widget.titleAlign = alignment;
        return this;
    }

    BorderWidget build()
    {
        return this._widget;
    }
}