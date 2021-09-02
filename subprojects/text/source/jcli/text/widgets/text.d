module jcli.text.widgets.text;

import std, jcli.text;

struct TextWidget
{
    Rect blockArea;
    string text;
    AnsiStyleSet style;

    void render(const Layout layout, TextBuffer buffer)
    {
        const area = layout.blockRectToRealRect(this.blockArea);
        Vector _1;
        buffer.setString(
            area,
            this.text,
            _1,
            this.style
        );
    }
}

struct TextWidgetBuilder
{
    private TextWidget _widget;

    @safe @nogc nothrow pure:

    TextWidgetBuilder withBlockArea(Rect area)
    {
        this._widget.blockArea = area;
        return this;
    }

    TextWidgetBuilder withText(string text)
    {
        this._widget.text = text;
        return this;
    }

    TextWidgetBuilder withStyle(AnsiStyleSet style)
    {
        this._widget.style = style;
        return this;
    }

    TextWidget build()
    {
        return this._widget;
    }
}