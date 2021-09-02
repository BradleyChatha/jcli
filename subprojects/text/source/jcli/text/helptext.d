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
        uint        _argNameWidth;
        uint        _argDescWidth;
        uint        _argGutterWidth;
        uint        _rowCursor;
        string      _cached;
    }

    static HelpText make(uint width)
    {
        HelpText t;
        t._text = new TextBuffer(width, TextBuffer.AUTO_GROW);
        t._argNameWidth = cast(uint)((cast(double)width) * ARG_NAME_PERCENT).round;
        t._argDescWidth = cast(uint)((cast(double)width) * ARG_DESC_PERCENT).round;
        t._argGutterWidth = cast(uint)((cast(double)width) * ARG_GUTTER_PERCENT).round;
        return t;
    }

    void addLine(string text)
    {
        Vector _1;
        this._text.setString(
            Rect(0, this._rowCursor, this._text.width, this._rowCursor+1),
            text,
            _1,
        );
        this._rowCursor++;
    }

    void addLineWithPrefix(string prefix, string text, AnsiStyleSet prefixStyle = AnsiStyleSet.init)
    {
        Vector lastChar;
        this._text.setString(
            Rect(0, this._rowCursor, prefix.length.to!int, this._rowCursor + 1),
            prefix,
            lastChar,
            prefixStyle
        );
        this._text.setString(
            Rect(lastChar.x + 1, lastChar.y, this._text.width, this._rowCursor + 1),
            text,
            lastChar
        );
        this._rowCursor = lastChar.y + 1;
    }

    void addHeaderWithText(string header, string text)
    {
        Vector lastChar;
        this._text.setString(
            Rect(0, this._rowCursor, this._text.width, this._rowCursor + 1),
            header,
            lastChar,
            AnsiStyleSet.init.style(AnsiStyle.init.bold)
        );
        this._rowCursor++;
        this._text.setString(
            Rect(4, this._rowCursor, this._text.width, this._text.height),
            text,
            lastChar
        );
        this._rowCursor = lastChar.y + 2;
    }

    void addHeader(string header)
    {
        Vector _1;
        this._text.setString(
            Rect(0, this._rowCursor, this._text.width, this._rowCursor + 1),
            header,
            _1,
            AnsiStyleSet.init.style(AnsiStyle.init.bold)
        );
        this._rowCursor += 1;
    }

    void addArgument(string name, HelpTextDescription[] description)
    {
        Vector namePos;
        this._text.setString(
            Rect(4, this._rowCursor, this._argNameWidth, this._rowCursor + 1),
            name,
            namePos
        );
        
        Vector descPos = Vector(0, this._rowCursor);
        foreach(desc; description)
        {
            const indent = desc.indent * 4;
            this._text.setString(
                Rect(this._argNameWidth + this._argGutterWidth + indent, descPos.y, this._argNameWidth + this._argGutterWidth + this._argDescWidth, descPos.y + 1),
                desc.text,
                descPos
            );
        }
        this._rowCursor = max(namePos.y + 1, descPos.y + 1);
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