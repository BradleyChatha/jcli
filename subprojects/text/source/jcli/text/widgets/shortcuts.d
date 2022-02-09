module jcli.text.widgets.shortcuts;

import jcli.text;

struct ShortcutsWidget(uint count)
{
    static struct Shortcut
    {
        string key;
        string desc;
    }

    Shortcut[count] shortcuts;
    AnsiColour bg;
    AnsiStyleSet keyStyle;
    AnsiStyleSet descStyle;

    void render(TextBuffer buffer)
    {
        auto area = Rect(0, buffer.height-1, buffer.width, buffer.height);
        buffer.setCells(area, " ", AnsiStyleSet.init.bg(this.bg));
        
        foreach(shortcut; this.shortcuts)
        {
            Vector lastChar;
            buffer.setCell(Vector(area.left, area.top), " ", this.keyStyle);
            area.left++;
            buffer.setString(area, shortcut.key, lastChar, this.keyStyle);
            area.left = lastChar.x + 1;
            buffer.setCell(Vector(area.left, area.top), " ", this.keyStyle);
            area.left += 2;
            buffer.setString(area, shortcut.desc, lastChar, this.descStyle);
            area.left = lastChar.x + 2;
        }
    }
}

struct ShortcutsWidgetBuilder(uint count)
{
    private ShortcutsWidget!count _widget;

    typeof(this) withShortcut(uint index, string key, string desc)
    {
        this._widget.shortcuts[index] = typeof(_widget).Shortcut(key, desc);
        return this;
    }

    typeof(this) withBackground(AnsiColour colour)
    {
        this._widget.bg = colour;
        return this;
    }

    typeof(this) withKeyStyle(AnsiStyleSet style)
    {
        this._widget.keyStyle = style;
        return this;
    }

    typeof(this) withDescriptionStyle(AnsiStyleSet style)
    {
        this._widget.descStyle = style;
        return this;
    }

    auto build()
    {
        return this._widget;
    }
}