module jcli.text.buffer;

import std, jansi, jcli.text;

struct TextBufferCell
{
    char[4] ch = [' ', ' ', ' ', ' ']; // UTF8 supports a max of 4 bytes to represent a char.
    ubyte chLen = 1;
    AnsiStyleSet style;
}

static bool g_jcliTextUseColour = true;

enum OnOOB
{
    constrain
}

final class TextBuffer
{
    enum AUTO_GROW = uint.max;
    alias OnRefreshFunc = void delegate(uint row, const TextBufferCell[] rowCells);

    private
    {
        TextBufferCell[] _cells;
        OnRefreshFunc    _onRefresh;
        ulong[]          _dirtyRowFlags;
        uint             _width;
        uint             _height;
        bool             _autoGrowHeight;
    }

    @safe nothrow pure
    this(uint width, uint height)
    {
        assert(width > 0);
        assert(height > 0);
        this._width = width;
        this._height = height;

        if(height == AUTO_GROW)
        {
            this._height = 1;
            this._autoGrowHeight = true;
        }

        this._cells.length = width * this._height;
        this._dirtyRowFlags.length = (this._height / 64) + 1;
    }

    void setCell(
        Vector cell, 
        const scope char[] ch, 
        AnsiStyleSet style = AnsiStyleSet.init,
        OnOOB oob = OnOOB.constrain
    )
    {
        this.autoGrow(cell.y);
        const vect  = oobVector(oob, Vector(this._width, this._height), cell);
        const index = vect.x + (vect.y * this._width);
        
        const before            = this._cells[index];
        scope ptr               = &this._cells[index];
        ptr.chLen               = this.getCharLength(ch);
        ptr.ch[0..ptr.chLen]    = ch[0..ptr.chLen];
        ptr.style               = style;

        this.setRowDirtyIf(vect.y, true);
    }

    void fillCells(
        Rect area,
        const scope char[] ch,
        AnsiStyleSet style = AnsiStyleSet.init,
        OnOOB oob = OnOOB.constrain
    )
    {
        this.autoGrow(area.bottom);
        const rect = oobRect(oob, Rect(0, 0, this._width, this._height), area);
        const chLen = this.getCharLength(ch);

        foreach(y; rect.top..rect.bottom)
        {
            const rowStart = rect.left + (y * this._width);
            const rowEnd   = rect.right + (y * this._width);
            auto  row      = this._cells[rowStart..rowEnd];

            foreach(ref cell; row)
            {
                cell.ch[0..chLen]   = ch[0..chLen];
                cell.chLen          = chLen;
                cell.style          = style;
                this.setRowDirtyIf(y, true);
            }
        }
    }

    void setString(
        Rect area,
        const scope char[] str,
        out Vector lastWritten,
        AnsiStyleSet style = AnsiStyleSet.init,
        OnOOB oob = OnOOB.constrain
    )
    {
        this.autoGrow(area.bottom);
        auto rect = oobRect(oob, Rect(0, 0, this._width, this._height), area);
        size_t cursor = 0;

        foreach(y; rect.top..rect.bottom)
        {
            const rowStart = rect.left + (y * this._width);
            const rowEnd   = rect.right + (y * this._width);
            auto  row      = this._cells[rowStart..rowEnd];

            foreach(i, ref cell; row)
            {
                if(cursor >= str.length)
                    return;

                const oldCursor = cursor;
                const ch        = decode(str, cursor);
                lastWritten     = Vector(rowStart + i.to!int, y);

                if(ch == '\n')
                    break;

                const chLen         = cursor - oldCursor;
                cell.ch[0..chLen]   = str[oldCursor..cursor];
                cell.chLen          = chLen.to!ubyte;
                cell.style          = style;
                this.setRowDirtyIf(y, true);
            }

            if(this._autoGrowHeight && cursor < str.length)
                this.autoGrow(++rect.bottom);
        }
    }

    void refresh()
    {
        if(!this._onRefresh)
            return;

        foreach(i; 0..this._height)
        {
            if(!this.isRowDirty(i))
                continue;

            const rowStart = this._width * i;
            const rowEnd   = this._width * (i + 1);
            const row      = this._cells[rowStart..rowEnd];
            this._onRefresh(i, row);
        }

        this._dirtyRowFlags[] = 0;
    }

    @property @safe @nogc nothrow pure
    void onRefresh(OnRefreshFunc func)
    {
        this._onRefresh = func;
    }

    @property @safe @nogc nothrow
    uint width() const
    {
        return this._width;
    }

    @property @safe @nogc nothrow
    uint height() const
    {
        return this._height;
    }

    @property @safe pure
    void height(uint h)
    {
        enforce(h > 0, "Height must be greater than 0.");
        this._cells.length = h * this._width;
        this._dirtyRowFlags.length = (h / 64) + 1;
        this._dirtyRowFlags[] = ulong.max;
        this._height = h;
    }

    private ubyte getCharLength(const scope char[] ch)
    {
        size_t index;
        decode(ch, index);
        return index.to!ubyte;
    }

    @safe pure
    private void autoGrow(uint y)
    {
        if(y >= this._height && this._autoGrowHeight)
            this.height = y + 1;
    }

    @safe @nogc nothrow pure
    private bool isRowDirty(uint row)
    {
        const byte_ = row / 64;
        const bit   = row % 64;
        const mask  = 1UL << bit;
        return (this._dirtyRowFlags[byte_] & mask) != 0;
    }

    @safe @nogc nothrow pure
    private void setRowDirtyIf(uint row, bool cond)
    {
        const byte_ = row / 64;
        const bit   = row % 64;
        const mask  = 1UL << bit;
        this._dirtyRowFlags[byte_] |= mask * (cond ? 1 : 0);
    }
}

@safe @nogc nothrow pure:

Vector oobVector(OnOOB behaviour, const Vector bounds, Vector vector)
{
    final switch(behaviour) with(OnOOB)
    {
        case constrain:
            if(vector.x < 0) vector.x = 0;
            if(vector.y < 0) vector.y = 0;
            if(vector.x > bounds.x) vector.x = bounds.x - 1;
            if(vector.y > bounds.y) vector.y = bounds.y - 1;
            return vector;
    }
}

Rect oobRect(OnOOB behaviour, const Rect bounds, Rect rect)
{
    final switch(behaviour) with(OnOOB)
    {
        case constrain:
            if(rect.left < bounds.left) rect.left = bounds.left;
            if(rect.top < bounds.top) rect.top = bounds.top;
            if(rect.right > bounds.right) rect.right = bounds.right;
            if(rect.bottom > bounds.bottom) rect.bottom = bounds.bottom;
            return rect;
    }
}