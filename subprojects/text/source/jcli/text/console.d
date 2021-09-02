module jcli.text.console;

import std, jansi, jcli.text;

version(Windows) import core.sys.windows.windows;

struct ConsoleEventUnknown {}
struct ConsoleKeyEvent
{
    enum SpecialKey
    {
        capslock = 0x0080,
        leftAlt = 0x0002,
        leftCtrl = 0x0008,
        numlock = 0x0020,
        rightAlt = 0x0001,
        rightCtrl = 0x0004,
        scrolllock = 0x0040,
        shift = 0x0010
    }

    bool isDown;
    uint repeatCount;
    uint keycode;
    uint scancode;
    union
    {
        wchar charAsUnicode;
        char charAsAscii;
    }
    SpecialKey specialKeys;
}
alias ConsoleEvent = SumType!(
    ConsoleKeyEvent,
    ConsoleEventUnknown
);

final class Console
{
    static:

    version(Windows)
    {
        HANDLE _stdin = INVALID_HANDLE_VALUE;
        DWORD _oldMode;
        UINT _oldOutputCP;
        UINT _oldInputCP;
    }

    bool attach()
    {
        version(Windows)
        {
            Console._stdin = GetStdHandle(STD_INPUT_HANDLE);
            if(Console._stdin == INVALID_HANDLE_VALUE)
                return false;

            if(!GetConsoleMode(Console._stdin, &Console._oldMode))
                return false;

            if(!SetConsoleMode(Console._stdin, Console._oldMode | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING))
                return false;

            this._oldInputCP = GetConsoleCP();
            this._oldOutputCP = GetConsoleOutputCP(); 
            SetConsoleOutputCP(CP_UTF8);
            SetConsoleCP(CP_UTF8);
            stdout.write("\033[?1049h"); // Use alternative buffer.
            return true;
        }
        else return false;
    }

    void detach()
    {
        version(Windows)
        {
            if(!Console.isAttached)
                return;

            SetConsoleMode(Console._stdin, Console._oldMode);
            SetConsoleOutputCP(this._oldOutputCP);
            SetConsoleCP(this._oldInputCP);
            Console._stdin = INVALID_HANDLE_VALUE;

            stdout.write("\033[?1049l"); // Use main buffer.
        }
    }

    bool isAttached()
    {
        version(Windows) return Console._stdin != INVALID_HANDLE_VALUE;
        else return false;
    }

    void processEvents(void delegate(ConsoleEvent) handler)
    {
        assert(handler !is null, "A null handler was provided.");

        version(Windows)
        {
            INPUT_RECORD[8] events;
            DWORD eventsRead;

            assert(Console.isAttached, "We're not attached to the console.");
            if(!PeekConsoleInput(Console._stdin, &events[0], 1, &eventsRead))
                return;

            ReadConsoleInput(Console._stdin, &events[0], cast(DWORD)events.length, &eventsRead);
            foreach(event; events[0..eventsRead])
            {
                const e = Console.translateEvent(event);
                handler(e);
            }
        }
    }

    void setCursor(uint x, uint y)
    {
        stdout.writef("\033[%s;%sH", y, x);
    }

    Vector screenSize()
    {
        version(Windows)
        {
            assert(Console.isAttached, "We're not attached to the console.");

            CONSOLE_SCREEN_BUFFER_INFO csbi;
            GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);

            return Vector(
                csbi.srWindow.Right - csbi.srWindow.Left + 1,
                csbi.srWindow.Bottom - csbi.srWindow.Top + 1
            );
        }
        else return Vector(0, 0);
    }

    void refreshHandler(uint row, const TextBufferCell[] rowCells)
    {
        static Appender!(char[]) builder;

        Console.setCursor(0, row.to!uint + 1);
        builder.clear();

        foreach(i, cell; rowCells)
        {
            if(i == 0 || cell.style != rowCells[i-1].style)
            {
                builder.put(ANSI_COLOUR_RESET);
                char[AnsiStyleSet.MAX_CHARS_NEEDED] buffer;
                builder.put(ANSI_CSI);
                builder.put(cell.style.toSequence(buffer));
                builder.put(ANSI_COLOUR_END);
            }
            builder.put(cell.ch[0..cell.chLen]);
        }

        builder.put(ANSI_COLOUR_RESET);
        stdout.write(builder.data);
    }

    TextBuffer createTextBuffer()
    {
        assert(this.isAttached, "We're not attached to the console.");
        auto buffer = new TextBuffer(Console.screenSize.x, Console.screenSize.y);
        buffer.onRefresh((&Console.refreshHandler).toDelegate);
        return buffer;
    }

    private version(Windows):

    ConsoleEvent translateEvent(INPUT_RECORD event)
    {
        switch(event.EventType)
        {
            case KEY_EVENT:
                const k = event.KeyEvent;
                auto e = ConsoleKeyEvent(
                    cast(bool)k.bKeyDown,
                    k.wRepeatCount,
                    k.wVirtualKeyCode,
                    k.wVirtualScanCode,
                );
                e.specialKeys = cast(ConsoleKeyEvent.SpecialKey)k.dwControlKeyState;
                e.charAsUnicode = k.UnicodeChar;

                return ConsoleEvent(e);

            default: return ConsoleEvent(ConsoleEventUnknown());
        }
    }
}