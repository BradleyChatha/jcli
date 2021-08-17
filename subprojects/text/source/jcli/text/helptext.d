module jcli.text.helptext;

import jcli.text, std;

struct HelpTextDescription
{
    uint indent;
    string text;
}

struct HelpText
{
    enum ARG_NAME_PERCENT = 0.1;
    enum ARG_GUTTER_PERCENT = 0.05;
    enum ARG_DESC_PERCENT = 0.3;

    private
    {
        TextBuffer  _text;
        size_t      _argNameWidth;
        size_t      _argDescWidth;
        size_t      _argGutterWidth;
        size_t      _rowCursor;
        string      _cached;
    }

    static HelpText make(size_t width)
    {
        HelpText t;
        t._text = new TextBuffer(width, TextBuffer.AUTO_GROW);
        t._argNameWidth = cast(size_t)((cast(double)width) * ARG_NAME_PERCENT).round;
        t._argDescWidth = cast(size_t)((cast(double)width) * ARG_DESC_PERCENT).round;
        t._argGutterWidth = cast(size_t)((cast(double)width) * ARG_GUTTER_PERCENT).round;
        return t;
    }

    void addLine(string text)
    {
        size_t _1;
        this._text.setCellsString(
            0, this._rowCursor, TextBuffer.ALL, 1,
            text,
            _1, this._rowCursor
        );
        this._rowCursor += 1;
    }

    void addLineWithPrefix(string prefix, string text, Nullable!AnsiStyleSet prefixStyle = Nullable!AnsiStyleSet.init)
    {
        size_t x;
        this._text.setCellsString(
            0, this._rowCursor, prefix.length, 1,
            prefix,
            x, this._rowCursor,
            prefixStyle
        );
        this._text.setCellsString(
            x + 1, this._rowCursor, TextBuffer.ALL, 1,
            text,
            x, this._rowCursor
        );
    }

    void addHeaderWithText(string header, string text)
    {
        size_t _1;
        this._text.setCellsString(
            0, this._rowCursor, TextBuffer.ALL, 1, 
            header,
            _1, this._rowCursor,
            AnsiStyleSet.init.style(AnsiStyle.init.bold).nullable
        );
        this._rowCursor += 1;
        this._text.setCellsString(
            (this._text.width > 4) ? 4 : 0, this._rowCursor, TextBuffer.ALL, TextBuffer.AUTO_GROW, 
            text,
            _1, this._rowCursor,
        );
        this._rowCursor += 2;
    }

    void addHeader(string header)
    {
        size_t _1;
        this._text.setCellsString(
            0, this._rowCursor, TextBuffer.ALL, 1, 
            header,
            _1, this._rowCursor,
            AnsiStyleSet.init.style(AnsiStyle.init.bold).nullable
        );
        this._rowCursor += 1;
    }

    void addArgument(string name, HelpTextDescription[] description)
    {
        size_t _1;
        size_t nameRow;
        size_t descRow = this._rowCursor;
        this._text.setCellsString(
            4, this._rowCursor, this._argNameWidth, TextBuffer.AUTO_GROW,
            name,
            _1, nameRow
        );

        foreach(desc; description)
        {
            const indent = desc.indent * 4;
            this._text.setCellsString(
                this._argNameWidth + this._argGutterWidth + indent, descRow, this._argDescWidth - indent, TextBuffer.AUTO_GROW,
                desc.text,
                _1, descRow
            );
            descRow++;
        }
        this._rowCursor = max(nameRow, descRow);
    }

    string finish()
    {
        if(this._cached)
            return this._cached;

        Appender!(char[]) output;
        this._text.onRefresh = (row, cells)
        {
            AnsiStyleSet style;
            foreach(cell; cells)
            {
                if(cell.style != style && g_jcliTextUseColour)
                {
                    style = cell.style;
                    output.put(ANSI_COLOUR_RESET);
                    output.put(ANSI_CSI);

                    char[AnsiStyleSet.MAX_CHARS_NEEDED] chars;
                    output.put(style.toSequence(chars));
                    output.put(ANSI_COLOUR_END);
                }
                output.put(cell.ch[0..cell.chLen]);
            }
            output.put(ANSI_COLOUR_RESET);
            output.put('\n');
        };
        this._text.refresh();
        this._cached = output.data.assumeUnique;
        return this._cached;
    }
}