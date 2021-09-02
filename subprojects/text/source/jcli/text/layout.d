module jcli.text.layout;

import std, jcli.text;

struct Layout
{
    private
    {
        Rect _area;
        int _horizBlocks;
        int _vertBlocks;
    }

    @safe @nogc
    this(Rect area, int horizBlocks, int vertBlocks) nothrow pure
    {
        this._area = area;
        this._horizBlocks = horizBlocks;
        this._vertBlocks = vertBlocks;
    }

    @safe @nogc
    Rect blockRectToRealRect(Rect blockRect) nothrow pure const
    {
        blockRect = oobRect(OnOOB.constrain, Rect(0, 0, this._horizBlocks, this._vertBlocks), blockRect);
            
        return Rect(
            (this.blockWidth * blockRect.left),
            (this.blockHeight * blockRect.top),
            (this.blockWidth * blockRect.right),
            (this.blockHeight * blockRect.bottom),
        );
    }

    @safe @nogc
    private int blockWidth() nothrow pure const
    {
        return this._area.width / this._horizBlocks;
    }

    @safe @nogc
    private int blockHeight() nothrow pure const
    {
        return this._area.height / this._vertBlocks;
    }
}

struct LayoutBuilder
{
    private Layout _layout;

    @safe @nogc nothrow pure:

    LayoutBuilder withArea(int left, int top, int right, int bottom)
    {
        this._layout._area = Rect(left, top, right, bottom);
        return this;
    }

    LayoutBuilder withArea(Rect rect)
    {
        this._layout._area = rect;
        return this;
    }

    LayoutBuilder withHorizontalBlocks(int amount)
    {
        this._layout._horizBlocks = amount;
        return this;
    }

    LayoutBuilder withVerticalBlocks(int amount)
    {
        this._layout._vertBlocks = amount;
        return this;
    }

    Layout build()
    {
        return this._layout;
    }
}