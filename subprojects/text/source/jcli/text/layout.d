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

    @safe
    Rect blockRectToRealRect(Rect blockRect) const
    {
        blockRect = oobRect(OnOOB.constrain, Rect(0, 0, this._horizBlocks, this._vertBlocks), blockRect);
        return Rect(
            this._area.left + (this.blockWidth * blockRect.left).round.to!int,
            this._area.top  + (this.blockHeight * blockRect.top).round.to!int,
            this._area.left + (this.blockWidth * blockRect.right).round.to!int,
            this._area.top  + (this.blockHeight * blockRect.bottom).round.to!int,
        );
    }

    @safe
    private float blockWidth() const
    {
        return cast(float)this._area.width / cast(float)this._horizBlocks;
    }

    @safe
    private float blockHeight() const
    {
        return cast(float)this._area.height / cast(float)this._vertBlocks;
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