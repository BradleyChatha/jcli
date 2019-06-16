module jaster.cli.helptext;

private
{
    import jaster.cli.udas;
}

interface IHelpSectionContent
{
    string getContent(const HelpSectionOptions);

    /+ UTILITY FUNCTIONS +/
    protected final
    {
        string lineWrap(const HelpSectionOptions options, const(char)[] text) const
        {
            import std.exception : assumeUnique, enforce;

            char[] actualText;
            const charsPerLine = options.lineCharLimit - (options.linePrefix.length + 1); // '+ 1' is for the new line char.
            size_t offset      = 0;
            
            enforce(charsPerLine > 0, "The lineCharLimit is too low. There's not enough space for any text (after factoring the prefix and ending new line characters).");
            actualText.reserve(text.length + (options.linePrefix.length * (text.length / charsPerLine)));
            
            while(offset < text.length)
            {
                size_t end = (offset + charsPerLine);
                if(end > text.length)
                    end = text.length;
                
                // Strip off whitespace, so things format properly.
                while(text[offset] == ' ')
                {
                    offset++;
                    if(end < text.length)
                        end++;
                }

                while(end != 0 && text[end - 1] == ' ')
                    end--;

                actualText ~= options.linePrefix;
                actualText ~= text[offset..end];
                actualText ~= "\n";

                offset += charsPerLine;
            }

            return actualText.assumeUnique;
        }
    }
}

struct HelpSection
{
    string name;
    IHelpSectionContent[] content;

    @disable this(this){}
}

struct HelpSectionOptions
{
    string linePrefix;
    size_t lineCharLimit;
}

final class HelpTextBuilderTechnical
{
    static const DEFAULT_SECTION_OPTIONS = HelpSectionOptions("\t", 120);

    private
    {
        string[]           _usages;
        HelpSection[]      _sections;
        HelpSectionOptions _sectionOptions = DEFAULT_SECTION_OPTIONS;
    }

    public final
    {
        void addUsage(string usageText)
        {
            this._usages ~= usageText;
        }

        ref HelpSection addSection(string sectionName)
        {
            this._sections.length += 1;
            this._sections[$-1].name = sectionName;

            return this._sections[$-1];
        }

        ref HelpSection modifySection(string sectionName)
        {
            foreach(ref section; this._sections)
            {
                if(section.name == sectionName)
                    return section;
            }

            assert(false, "No section called '"~sectionName~"' was found.");
        }

        override string toString()
        {
            import std.array     : appender;
            import std.algorithm : map, each;
            import std.exception : assumeUnique;
            import std.format    : format;

            char[] output;
            output.reserve(4096);

            // Usages
            this._usages.map!(u => "USAGE: "~u~"\n")
                        .each!(u => output ~= u);

            // Sections
            foreach(ref section; this._sections)
            {
                // This could all technically be 'D-ified'/'rangeified' but I couldn't make it look nice.
                output ~= "\n";
                output ~= section.name~":\n";
                section.content.map!(c => c.getContent(this._sectionOptions))
                               .each!(c => output ~= c);
            }

            return output.assumeUnique;
        }
    }
}

final class HelpTextBuilderSimple
{
    private
    {
        // We have it as a field instead of inheriting from it, so that we can hide the technical functions.
        HelpTextBuilderTechnical _builder;
    }

    public final
    {
    }
}

/+ BUILT IN SECTION CONTENT +/
final class HelpSectionTextContent : IHelpSectionContent
{
    string text;

    this(string text)
    {
        this.text = text;
    }

    string getContent(const HelpSectionOptions options)
    {
        return this.lineWrap(options, this.text);
    }
}
///
unittest
{
    import std.exception : assertThrown;

    auto options = HelpSectionOptions("\t", 7 + 2); // '+ 2' is for the prefix + ending new line. 7 is the wanted char limit.
    auto content = new HelpSectionTextContent("Hey Hip Lell Loll");
    assert(content.getContent(options) == 
        "\tHey Hip\n"
       ~"\tLell Lo\n"
       ~"\tll\n",
    
        "\n"~content.getContent(options)
    );

    options.lineCharLimit = 200;
    assert(content.getContent(options) == "\tHey Hip Lell Loll\n");

    options.lineCharLimit = 2; // Enough for the prefix and ending new line, but not enough for any piece of text.
    assertThrown(content.getContent(options));

    options.lineCharLimit = 3; // Useable, but not readable.
    assert(content.getContent(options) ==
        "\tH\n"
       ~"\te\n"
       ~"\ty\n"

       ~"\tH\n"
       ~"\ti\n"
       ~"\tp\n"

       ~"\tL\n"
       ~"\te\n"
       ~"\tl\n"
       ~"\tl\n"

       ~"\tL\n"
       ~"\to\n"
       ~"\tl\n"
       ~"\tl\n",
    
        "\n"~content.getContent(options)
    );
}

final class HelpSectionArgInfoContent : IHelpSectionContent
{
    enum NAME_CHAR_LIMIT_DIVIDER = 4;
    const MIDDLE_AFFIX = " - ";

    struct ArgInfo
    {
        string[] names;
        string description;
    }

    ArgInfo[] args;

    this(ArgInfo[] args)
    {
        this.args = args;
    }

    string getContent(const HelpSectionOptions badOptions)
    {
        import std.array     : array;
        import std.algorithm : map, reduce, count, max, splitter, substitute;
        import std.conv      : to;
        import std.exception : assumeUnique;
        import std.utf       : byChar;

        // Treat tabs as 4 spaces, since otherwise terminal-specificness can ruin the formatting.
        HelpSectionOptions options = badOptions;
        options.linePrefix = badOptions.linePrefix.substitute("\t", "    ").byChar.array;

        // Calculate some variables.
        const USEABLE_CHARS     = (options.lineCharLimit - options.linePrefix.length) - MIDDLE_AFFIX.length; // How many chars in total we can use.
        const NAME_CHARS        = USEABLE_CHARS / NAME_CHAR_LIMIT_DIVIDER;                                   // How many chars per line we can use for the names.
        const DESCRIPTION_CHARS = USEABLE_CHARS - NAME_CHARS;                                                // How many chars per line we can use for the description.
        const DESCRIPTION_START = options.linePrefix.length + NAME_CHARS + MIDDLE_AFFIX.length;              // How many chars in that the description starts.

        // Creating the options and padding for the names and description.
        HelpSectionOptions nameOptions;
        nameOptions.linePrefix    = options.linePrefix;
        nameOptions.lineCharLimit = NAME_CHARS + options.linePrefix.length;

        auto padding = new char[DESCRIPTION_START];
        padding[] = ' ';

        HelpSectionOptions descriptionOptions;
        descriptionOptions.linePrefix    = padding.assumeUnique;
        descriptionOptions.lineCharLimit = DESCRIPTION_CHARS + DESCRIPTION_START; // For the first line, the padding needs to be removed manually.

        char[] output;
        output.reserve(4096);

        // Hello inefficient code, my old friend...
        foreach(arg; this.args)
        {
            // Line wrap. (This line alone is like, O(3n))
            auto nameText = lineWrap(
                nameOptions, 
                arg.names.map!(n => (n.length == 1) ? "-"~n : "--"~n)
                         .reduce!((a, b) => a~","~b)
                         .byChar
                         .array
            );

            auto descriptionText = lineWrap(
                descriptionOptions,
                arg.description
            );
            descriptionText = descriptionText[descriptionOptions.linePrefix.length..$]; // Remove the padding from the first line.

            // Then create our output line-by-line
            auto nameLines = nameText.splitter('\n');
            auto descriptionLines = descriptionText.splitter('\n');

            bool isFirstLine = true;
            size_t nameLength = 0;
            while(!nameLines.empty || !descriptionLines.empty)
            {
                if(!nameLines.empty)
                {
                    nameLength = nameLines.front.length; // Need to keep track of this for the next two ifs.

                    output ~= nameLines.front;
                    nameLines.popFront();
                }

                if(isFirstLine)
                {
                    // Push the middle affix into the middle, where it should be.
                    const ptrdiff_t missingChars = (NAME_CHARS - nameLength) + nameOptions.linePrefix.length;
                    if(missingChars > 0)
                        output ~= descriptionOptions.linePrefix[0..missingChars];

                    output ~= MIDDLE_AFFIX;
                }

                if(!descriptionLines.empty)
                {
                    auto description = descriptionLines.front;
                    if(!isFirstLine)
                        description = description[nameLength..$]; // The name might be multi-line, so we need to adjust the padding.

                    output ~= description;
                    descriptionLines.popFront();
                }

                output ~= "\n";
                isFirstLine = false; // IMPORTANT for it to be here, please don't move it.
            }
        }

        // debug
        // {
        //     char[] a;
        //     a.length = nameOptions.linePrefix.length;
        //     a[] = '1';
        //     output ~= a;

        //     a.length = NAME_CHARS;
        //     a[] = '2';
        //     output ~= a;

        //     a.length = MIDDLE_AFFIX.length;
        //     a[] = '3';
        //     output ~= a;

        //     a.length = DESCRIPTION_CHARS;
        //     a[] = '4';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = DESCRIPTION_START;
        //     a[] = '>';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = descriptionOptions.lineCharLimit;
        //     a[] = '*';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = options.lineCharLimit;
        //     a[] = '#';
        //     output ~= a;
        // }

        return output.assumeUnique;
    }
}
///
unittest
{
    auto content = new HelpSectionArgInfoContent(
        [
            HelpSectionArgInfoContent.ArgInfo(["v", "verbose"],           "Display detailed information about what the program is doing."),
            HelpSectionArgInfoContent.ArgInfo(["f", "file"],              "The input file."),
            HelpSectionArgInfoContent.ArgInfo(["super","longer","names"], "Some unusuable command with long names and a long description.")
        ]
    );
    auto options = HelpSectionOptions(
        "\t",
        80
    );

    assert(content.getContent(options) ==
        "    -v,--verbose       - Display detailed information about what the program is\n"
       ~"                         doing.\n"
       ~"\n"
       ~"    -f,--file          - The input file.\n"
       ~"\n"
       ~"    --super,--longer,  - Some unusuable command with long names and a long desc\n"
       ~"    --names              ription.\n"
       ~"\n",

        "\n"~content.getContent(options)
    );
}