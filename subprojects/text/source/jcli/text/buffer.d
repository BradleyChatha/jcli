module jcli.text.buffer;

import std, jansi;

struct TextBufferCell
{
    char[4] ch = [' ', ' ', ' ', ' ']; // Unicode supports a max of 4 bytes to represent a char.
    ubyte chLen = 1;
    AnsiStyleSet style;
}

static bool g_jcliTextUseColour = true;

final class TextBuffer
{
    enum AUTO_GROW = size_t.max;
    enum ALL       = size_t.max-1;
    alias OnRefreshFunc = void delegate(size_t row, const TextBufferCell[] rowCells);

    private
    {
        TextBufferCell[] _cells;
        OnRefreshFunc    _onRefresh;
        ulong[]          _dirtyRowFlags;
        size_t           _width;
        size_t           _height;
        bool             _autoGrowHeight;
    }

    @safe nothrow pure
    this(size_t width, size_t height)
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

    @safe pure
    void setCell(size_t x, size_t y, const char[] ch, Nullable!AnsiStyleSet style = Nullable!AnsiStyleSet.init)
    {
        this.autoGrow(y);
        enforce(x < this._width, "X is too high.");
        enforce(y < this._height, "Y is too high.");
        enforce(ch.length, "No character was given.");
        this.setRowDirty(y);

        size_t index = 0;
        decode(ch, index);
        enforce(index == ch.length, "Too many characters were given, only 1 was expected.");

        scope cell = &this._cells[x+(this._width*y)];
        cell.ch = ch[0..index];
        cell.chLen = cast(ubyte)index;
        
        if(!style.isNull)
            cell.style = style.get;
    }

    @safe pure
    void setCellsSingleChar(
        size_t x, 
        size_t y, 
        size_t width, 
        size_t height, 
        const char[] ch,
        Nullable!AnsiStyleSet style = Nullable!AnsiStyleSet.init
    )
    {
        if(width == ALL) width = this._width - x;
        if(height == ALL) height = this._height - y;
        this.autoGrow(y + height);
        enforceSubRect(
            0, 0, this._width, this._height,
            x, y, width, height
        );
        enforce(ch.length, "No character was given.");
        
        size_t index = 0;
        decode(ch, index);
        enforce(index == ch.length, "Too many characters were given, only 1 was expected.");

        foreach(i; 0..height)
        {
            const rowy = y + i;
            this.setRowDirty(rowy);

            const rowStart = x + (this._width * rowy);
            const rowEnd   = rowStart + width;
            auto  row      = this._cells[rowStart..rowEnd];

            foreach(ref cell; row)
            {
                cell.ch = ch[0..index];
                cell.chLen = cast(ubyte)index;
                if(!style.isNull)
                    cell.style = style.get;
            }
        }
    }

    @safe pure
    void setCellsString(
        size_t x, 
        size_t y, 
        size_t width, 
        size_t height, 
        const char[] ch,
        out size_t stopX,
        out size_t stopY, 
        Nullable!AnsiStyleSet style = Nullable!AnsiStyleSet.init
    )
    {
        bool autoGrowHeight = false;

        if(width == ALL) width = this._width - x;
        if(height == ALL) height = this._height - y;
        if(height == AUTO_GROW) { height = 1; autoGrowHeight = true; }
        this.autoGrow(y + height);
        enforceSubRect(
            0, 0, this._width, this._height,
            x, y, width, height
        );

        stopX = x;
        stopY = y;

        size_t cursor;
        for(auto i = 0; i < height; i++)
        {
            const rowy = y + i;
            this.setRowDirty(rowy);

            const rowStart = x + (this._width * rowy);
            const rowEnd   = rowStart + width;
            auto  row      = this._cells[rowStart..rowEnd];

            foreach(j, ref cell; row)
            {
                NextChar:
                if(cursor < ch.length)
                {
                    const cursorStart = cursor;
                    auto chCopy = ch;
                    decode(chCopy, cursor);
                    const chSize = cursor - cursorStart;

                    if(ch[cursorStart..cursor] == "\n")
                    {
                        cell.ch[0] = ' ';
                        cell.chLen = 1;
                        stopY = rowy + 1;
                        stopX = rowStart + j;
                        break;
                    }
                    
                    if(j == 0 && ch[cursorStart..cursor] == " ")
                        goto NextChar; // ewwwwwwwwww

                    cell.ch[0..(cursor - cursorStart)] = ch[cursorStart..cursor];
                    cell.chLen = cast(ubyte)chSize;

                    stopY = rowy;
                    stopX = rowStart + j;
                }

                if(!style.isNull)
                    cell.style = style.get;
            }

            if(autoGrowHeight && cursor < ch.length)
            {
                this.height = (rowy + 2);
                height++;
            }
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
    size_t width() const
    {
        return this._width;
    }

    @property @safe @nogc nothrow
    size_t height() const
    {
        return this.height;
    }

    @property @safe pure
    void height(size_t h)
    {
        enforce(h > 0, "Height must be greater than 0.");
        this._cells.length = h * this._width;
        this._dirtyRowFlags.length = (h / 64) + 1;
        this._dirtyRowFlags[] = ulong.max;
        this._height = h;
    }

    @safe pure
    private void autoGrow(size_t y)
    {
        if(y >= this._height)
            this.height = y + 1;
    }

    @safe @nogc nothrow pure
    private bool isRowDirty(size_t row)
    {
        const byte_ = row / 64;
        const bit   = row % 64;
        const mask  = 1UL << bit;
        return (this._dirtyRowFlags[byte_] & mask) != 0;
    }

    @safe @nogc nothrow pure
    private void setRowDirty(size_t row)
    {
        const byte_ = row / 64;
        const bit   = row % 64;
        const mask  = 1UL << bit;
        this._dirtyRowFlags[byte_] |= mask;
    }
}

@safe pure
private void enforceSubRect(
    size_t px, size_t py, size_t pw, size_t ph,
    size_t cx, size_t cy, size_t cw, size_t ch
)
{
    enforce(cx >= px, "X is too low.");
    enforce(cy >= py, "Y is too low.");
    enforce(cx < pw, "X is too high.");
    enforce(cy < ph, "Y is too high.");
    enforce(cx + cw <= pw, "Width is too high.");
    enforce(cy + ch <= ph, "Height is too high.");
    enforce(cw > 0, "Width cannot be 0.");
    enforce(ch > 0, "Height cannot be 0.");
}