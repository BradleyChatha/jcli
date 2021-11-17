module jcli.text.console;

import std, jansi, jcli.text;

version(Windows) import core.sys.windows.windows;
version(Posix) import core.sys.posix.termios, core.sys.posix.unistd, core.sys.posix.signal;

enum ConsoleKey
{
    unknown,

    a,  b,  c,  d,  e,  f,  g,
    h,  i,  j,  k,  l,  m,  n,
    o,  p,  q,  r,  s,  t,  u,
    v,  w,  x,  y,  z,

    printScreen, scrollLock, pause,
    insert,      home,       pageUp,
    pageDown,    del,        end,

    up, down, left, right,

    escape, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,

    enter, back, tab
}

struct ConsoleEventUnknown {}
struct ConsoleEventInterrupt {}
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
    ConsoleKey key;
    uint scancode;
    union
    {
        dchar charAsUnicode;
        char charAsAscii;
    }
    SpecialKey specialKeys;
}

alias ConsoleEvent = SumType!(
    ConsoleKeyEvent,
    ConsoleEventInterrupt,
    ConsoleEventUnknown
);

final class Console
{
    static:

    private bool _useAlternateBuffer;
    private bool _wasControlC;
    version(Windows) private
    {
        HANDLE _stdin = INVALID_HANDLE_VALUE;
        DWORD _oldMode;
        UINT _oldOutputCP;
        UINT _oldInputCP;
    }
    version(Posix) private
    {
        bool _attached;
        termios _oldIos;
    }

    bool attach(bool useAlternativeBuffer = true)
    {
        _useAlternateBuffer = false;
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

            SetConsoleCtrlHandler((ctrlType)
            {
                if(ctrlType == CTRL_C_EVENT)
                {
                    Console._wasControlC = true;
                    return TRUE;
                }

                return FALSE;
            }, TRUE);

            if(_useAlternateBuffer)
                stdout.write("\033[?1049h");
            return true;
        }
        else version(Posix)
        {
            if(_useAlternateBuffer)
                stdout.write("\033[?1049h");
            tcgetattr(STDIN_FILENO, &_oldIos);
            auto newIos = _oldIos;

            newIos.c_lflag &= ~ECHO;
            newIos.c_lflag &= ~ICANON;
            newIos.c_cc[VMIN] = 0;
            newIos.c_cc[VTIME] = 1;

            tcsetattr(STDIN_FILENO, TCSAFLUSH, &newIos);
            signal(SIGINT, (_){ Console._wasControlC = true; });

            this._attached = true;
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
            SetConsoleCtrlHandler(null, FALSE);
            Console._stdin = INVALID_HANDLE_VALUE;
        }
        else version(Posix)
        {
            if(!Console.isAttached)
                return;
            this._attached = false;
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &_oldIos);
            signal(SIGINT, SIG_DFL);
        }

        if(_useAlternateBuffer)
            stdout.write("\033[?1049l");
    }

    bool isAttached()
    {
        version(Windows) return Console._stdin != INVALID_HANDLE_VALUE;
        else version(Posix) return Console._attached;
        else return false;
    }

    void processEvents(void delegate(ConsoleEvent) handler)
    {
        assert(handler !is null, "A null handler was provided.");

        if(_wasControlC)
        {
            _wasControlC = false;
            handler(ConsoleEvent(ConsoleEventInterrupt()));
        }

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
        else version(Posix)
        {
            import core.sys.posix.unistd : read;

            char ch;
            ssize_t bytesRead = read(STDIN_FILENO, &ch, 1);
            while(bytesRead > 0 && Console.isAttached)
            {
                handler(ConsoleEvent(Console.translateKeyEvent(ch)));

                if(Console.isAttached)
                    bytesRead = read(STDIN_FILENO, &ch, 1);
            }
        }
    }

    void waitForInput()
    {
        assert(Console.isAttached, "We're not attached to the console.");
        version(Windows)
        {
            WaitForSingleObject(Console._stdin, 0);
        }
    }

    void setCursor(uint x, uint y)
    {
        stdout.writef("\033[%s;%sH", y, x);
    }

    void hideCursor()
    {
        stdout.write("\033[?25l");
    }

    void showCursor()
    {
        stdout.write("\033[?25h");
    }

    Vector screenSize()
    {
        version(Windows)
        {
            CONSOLE_SCREEN_BUFFER_INFO csbi;
            GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);

            return Vector(
                csbi.srWindow.Right - csbi.srWindow.Left + 1,
                csbi.srWindow.Bottom - csbi.srWindow.Top + 1
            );
        }
        else version(Posix)
        {
            import core.sys.posix.sys.ioctl, core.sys.posix.unistd, core.sys.posix.stdio;
            winsize w;
            ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
            return Vector(w.ws_col, w.ws_row);
        }
        else return Vector(80, 20);
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

    private version(Windows)
    {
        ConsoleEvent translateEvent(INPUT_RECORD event)
        {
            switch(event.EventType)
            {
                case KEY_EVENT:
                    const k = event.KeyEvent;
                    auto e = ConsoleKeyEvent(
                        cast(bool)k.bKeyDown,
                        k.wRepeatCount,
                        Console.translateKey(k.wVirtualKeyCode),
                        k.wVirtualScanCode,
                    );
                    e.specialKeys = cast(ConsoleKeyEvent.SpecialKey)k.dwControlKeyState;
                    e.charAsUnicode = k.UnicodeChar.to!dchar;

                    return ConsoleEvent(e);

                default: return ConsoleEvent(ConsoleEventUnknown());
            }
        }

        // https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
        ConsoleKey translateKey(uint keycode)
        {
            switch(keycode) with(ConsoleKey)
            {
                case VK_TAB: return ConsoleKey.tab;
                case VK_SNAPSHOT: return ConsoleKey.printScreen;
                case VK_SCROLL: return ConsoleKey.scrollLock;
                case VK_PAUSE: return ConsoleKey.pause;
                case VK_INSERT: return ConsoleKey.insert;
                case VK_HOME: return ConsoleKey.home;
                case VK_DELETE: return ConsoleKey.del;
                case VK_END: return ConsoleKey.end;
                case VK_NEXT: return ConsoleKey.pageDown;
                case VK_PRIOR: return ConsoleKey.pageUp;

                case VK_ESCAPE: return ConsoleKey.escape;
                case VK_F1:..case VK_F12:
                    return cast(ConsoleKey)(cast(uint)ConsoleKey.f1 + (keycode - VK_F1));

                case VK_RETURN: return ConsoleKey.enter;
                case VK_BACK: return ConsoleKey.back;

                case VK_UP: return ConsoleKey.up;
                case VK_DOWN: return ConsoleKey.down;
                case VK_LEFT: return ConsoleKey.left;
                case VK_RIGHT: return ConsoleKey.right;

                // a-z
                case 0x41:..case 0x5A:
                    return cast(ConsoleKey)(cast(uint)ConsoleKey.a + (keycode - 0x41));

                default: return unknown;
            }
        }
    }

    private version(Posix)
    {
        ConsoleKeyEvent translateKeyEvent(char ch)
        {
            ConsoleKeyEvent event;
            event.key = Console.translateKey(ch, event.charAsUnicode);
            event.isDown = true;
            event.charAsAscii = ch;

            return event;
        }

        ConsoleKey translateKey(char firstCh, out dchar utf)
        {
            import core.sys.posix.unistd : read;

            // TODO: Unicode support.
            switch(firstCh) with(ConsoleKey)
            {
                case 0x1A: return ConsoleKey.pause;
                case '\t': return ConsoleKey.tab;

                case 0x0A: return ConsoleKey.enter;
                case 0x7F: return ConsoleKey.back;

                // a-z
                case 0x41:..case 0x5A:
                    utf = firstCh;
                    return cast(ConsoleKey)(cast(uint)ConsoleKey.a + (firstCh - 0x41));

                case '\033':
                    char ch;
                    auto bytesRead = read(STDIN_FILENO, &ch, 1);
                    if(bytesRead == 0)
                        return escape;
                    else if(ch == 'O' && read(STDIN_FILENO, &ch, 1) != 0 && ch >= 0x50 && ch <= 0x7E)
                        return cast(ConsoleKey)(cast(uint)ConsoleKey.f1 + (ch - 0x50));
                    else if(ch != '[')
                        return unknown;

                    bytesRead = read(STDIN_FILENO, &ch, 1);
                    if(bytesRead == 0)
                        return unknown;

                    switch(ch)
                    {
                        case 'A': return ConsoleKey.up; 
                        case 'B': return ConsoleKey.down; 
                        case 'C': return ConsoleKey.right; 
                        case 'D': return ConsoleKey.left;
                        case 'H': return ConsoleKey.home;
                        case 'F': return ConsoleKey.end;
                        case '2':
                            bytesRead = read(STDIN_FILENO, &ch, 1);
                            if(bytesRead == 0 || ch != '~')
                                return unknown;
                            return ConsoleKey.insert;
                        case '3':
                            bytesRead = read(STDIN_FILENO, &ch, 1);
                            if(bytesRead == 0 || ch != '~')
                                return unknown;
                            return ConsoleKey.del;
                        case '5':
                            bytesRead = read(STDIN_FILENO, &ch, 1);
                            if(bytesRead == 0 || ch != '~')
                                return unknown;
                            return ConsoleKey.pageUp;
                        case '6':
                            bytesRead = read(STDIN_FILENO, &ch, 1);
                            if(bytesRead == 0 || ch != '~')
                                return unknown;
                            return ConsoleKey.pageDown;



                        default: return unknown;
                    }

                default: return unknown;
            }
        }
    }
}