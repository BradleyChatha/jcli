module jaster.cli.helptext;

private
{
    import std.typecons : Flag;
    import jaster.cli.udas;
}

/// A flag that should be used by content classes that have the ability to auto add argument dashes to arg names.
/// (e.g. "-" and "--")
alias AutoAddArgDashes = Flag!"addArgDashes";

alias ArgIsOptional = Flag!"isOptional";

/++
 + The interface for any class that can be used to generate content inside of a help
 + text section.
 + ++/
interface IHelpSectionContent
{
    /++
     + Generates a string to display inside of a help text section.
     +
     + Params:
     +  options = Options regarding how the text should be formatted.
     +            Please try to match these options as closely as possible.
     +
     + Returns:
     +  The generated content string.
     + ++/
    string getContent(const HelpSectionOptions options);

    /+ UTILITY FUNCTIONS +/
    protected final
    {
        /++
         + Wraps a piece of text into seperate lines, based on the given options.
         +
         + Throws:
         +  `Exception` if the char limit is too small to show any text.
         +
         + Notes:
         +  Currently, this performs character-wrapping instead of word-wrapping, so words
         +  can be split between multiple lines. There is no technical reason for this outside of I'm lazy.
         +
         +  For every line created from the given `text`, the starting and ending spaces (not whitespace, just spaces)
         +  are stripped off. This is so the user doesn't have to worry about random leading/trailling spaces, making it
         +  easier to format for the general case (though specific cases might find this undesirable, I'm sorry).
         +
         +  For every line created from the given `text`, the line prefix defined in the `options` is prefixed onto every newly made line.
         + ++/
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

/++
 + A help text section.
 +
 + A section is basically something like "Description:", or "Arguments:", etc.
 +
 + Notes:
 +  Instances of this struct aren't ever really supposed to be kept around outside of `HelpTextBuilderTechnical`, so it's
 +  non-copyable.
 + ++/
struct HelpSection
{
    /// The name of the section.
    string name;

    /// The content of this section.
    IHelpSectionContent[] content;

    /// The formatting options for this section.
    HelpSectionOptions options;

    /++
     + Adds a new piece of content to this section.
     +
     + Params:
     +  content = The content to add.
     +
     + Returns:
     +  `this`
     + ++/
    ref HelpSection addContent(IHelpSectionContent content)
    {
        assert(content !is null);
        this.content ~= content;

        return this;
    }

    @disable this(this){}
}

/++
 + Options on how the text of a section is formatted.
 +
 + Notes:
 +  It is up to the individual `IHelpSectionContent` implementors to follow these options.
 + ++/
struct HelpSectionOptions
{
    /// The prefix to apply to every new line of text inside the section.
    string linePrefix;

    /// How many chars there are per line. This should be seen as a hard limit.
    size_t lineCharLimit = 120;
}

/++
 + A class used to create help text, in an object oriented fashion.
 +
 + Technical_Versus_Simple:
 +  The Technical version of this class is meant to give the user full control of what's generated.
 +
 +  The Simple version (and any other versions the user may create) are meant to have more of a scope/predefined layout,
 +  and so are simpler to use.
 +
 + Isnt_This_Overcomplicated?:
 +  Kind of...
 +
 +  A goal of this library is to make it's foundational parts (such as this class, and the `ArgBinder` stuff) reusable on their own,
 +  so even if the user doesn't like how I've designed the core part of the library (Everything in `jaster.cli.core`, and the UDAs relating to it)
 +  they are given a small foundation to work off of to create their own version.
 +
 +  So I kind of need this to be a bit more complicated than it should be, so it's easy for me to provide built-in functionality that can be used
 +  or not used as wished by the user, while also allowing the user to create their own.
 + ++/
final class HelpTextBuilderTechnical
{
    /// The default options for a section.
    static const DEFAULT_SECTION_OPTIONS = HelpSectionOptions("\t", 120);

    private
    {
        string[]           _usages;
        HelpSection[]      _sections;
        HelpSectionOptions _sectionOptions = DEFAULT_SECTION_OPTIONS;
    }

    public final
    {
        /// Adds a new usage.
        void addUsage(string usageText)
        {
            this._usages ~= usageText;
        }

        /++
         + Adds a new section.
         +
         + Params:
         +  sectionName = The name of the section.
         +
         + Returns:
         +  A reference to the section, so that the `addContent` function can be called.
         + ++/
        ref HelpSection addSection(string sectionName)
        {
            this._sections.length += 1;
            this._sections[$-1].name = sectionName;
            this._sections[$-1].options = this._sectionOptions;

            return this._sections[$-1];
        }

        /++
         + Modifies an existing section (by returning it by reference).
         +
         + Assertions:
         +  `sectionName` must exist.
         +
         + Params:
         +  sectionName = The name of the section to modify.
         +
         + Returns:
         +  A reference to the section, so it can be modified by calling code.
         + ++/
        ref HelpSection modifySection(string sectionName)
        {
            foreach(ref section; this._sections)
            {
                if(section.name == sectionName)
                    return section;
            }

            assert(false, "No section called '"~sectionName~"' was found.");
        }

        /++
         + Generates the help text based on the given usages and sections.
         +
         + Notes:
         +  The result of this function aren't cached yet.
         +
         + Returns:
         +  The generated text.
         + ++/
        override string toString()
        {
            import std.array     : appender;
            import std.algorithm : map, each;
            import std.exception : assumeUnique;
            import std.format    : format;

            char[] output;
            output.reserve(4096);

            // Usages
            this._usages.map!(u => "Usage: "~u~"\n")
                        .each!(u => output ~= u);

            // Sections
            foreach(ref section; this._sections)
            {
                // This could all technically be 'D-ified'/'rangeified' but I couldn't make it look nice.
                output ~= "\n";
                output ~= section.name~":\n";
                section.content.map!(c => c.getContent(section.options))
                               .each!(c => output ~= c);
            }

            return output.assumeUnique;
        }
    }
}

/++
 + A simpler version of `HelpTextBuilerTechnical`, as it has a fixed layout, and handles all of the section and content generation.
 +
 + Description:
 +  This help text builder contains the following:
 +
 +      * A single 'Usage' line, which is generated automatically from the rest of the given data.
 +      * A description section.
 +      * A section for positional parameters, which are given a position, description, and an optional display name.
 +      * A section for named parameters, which can have multiple names, and a description.
 +
 + Please see the unittest for an example of it's usage and output.
 + ++/
final class HelpTextBuilderSimple
{
    private
    {
        struct PositionalArg
        {
            size_t position;
            HelpSectionArgInfoContent.ArgInfo info;
        }

        string                              _commandName;
        HelpSectionArgInfoContent.ArgInfo[] _namedArgs;
        PositionalArg[]                     _positionalArgs;
        string                              _description;
    }

    public final
    {
        HelpTextBuilderSimple addNamedArg(string[] names, string description, ArgIsOptional isOptional)
        {
            this._namedArgs ~= HelpSectionArgInfoContent.ArgInfo(names, description, isOptional);
            return this;
        }

        HelpTextBuilderSimple addNamedArg(string name, string description, ArgIsOptional isOptional)
        {
            this.addNamedArg([name], description, isOptional);
            return this;
        }

        HelpTextBuilderSimple addPositionalArg(size_t position, string description, ArgIsOptional isOptional, string displayName = null)
        {
            import std.conv : to;

            this._positionalArgs ~= PositionalArg(
                position,
                HelpSectionArgInfoContent.ArgInfo(
                    [position.to!string] ~ ((displayName is null) ? [] : [displayName]),
                    description,
                    isOptional
                )
            );

            return this;
        }

        HelpTextBuilderSimple setDescription(string desc)
        {
            this.description = desc;
            return this;
        }

        HelpTextBuilderSimple setCommandName(string name)
        {
            this.commandName = name;
            return this;
        }

        @property
        ref string description()
        {
            return this._description;
        }

        @property
        ref string commandName()
        {
            return this._commandName;
        }

        override string toString()
        {
            import std.algorithm : map, joiner;
            import std.array     : array;
            import std.range     : tee;
            import std.format    : format;
            import std.exception : assumeUnique;

            auto builder = new HelpTextBuilderTechnical();

            char[] usageString;
            usageString.reserve(512);
            usageString ~= this._commandName;
            usageString ~= ' ';

            if(this.description !is null)
            {
                builder.addSection("Description")
                       .addContent(new HelpSectionTextContent(this._description));
            }

            if(this._positionalArgs.length > 0)
            {
                builder.addSection("Positional Args")
                       .addContent(new HelpSectionArgInfoContent(
                           this._positionalArgs
                                .tee!((p)
                                {
                                    auto text = "{%s}".format(p.info.names.joiner("/"));

                                    usageString ~= (p.info.isOptional)
                                                    ? "<"~text~">"
                                                    : text;
                                    usageString ~= ' ';
                                })
                                .map!(p => p.info)
                                .array, 
                            AutoAddArgDashes.no
                        )
                );
            }

            if(this._namedArgs.length > 0)
            {
                builder.addSection("Named Args")
                       .addContent(new HelpSectionArgInfoContent(
                           this._namedArgs
                               .tee!((a)
                               {
                                    auto text = "[%s]".format(a.names.joiner("|"));

                                    usageString ~= (a.isOptional)
                                                    ? "<"~text~">"
                                                    : text;
                                    usageString ~= ' ';
                               })
                               .array,
                           AutoAddArgDashes.yes
                        )
                );
            }

            builder.addUsage(usageString.assumeUnique);
            return builder.toString();
        }
    }
}
///
unittest
{
    auto builder = new HelpTextBuilderSimple();

    builder.addPositionalArg(0, "The input file.", ArgIsOptional.no, "InputFile")
           .addPositionalArg(1, "The output file.", ArgIsOptional.no, "OutputFile")
           .addNamedArg(["v","verbose"], "Verbose output", ArgIsOptional.yes)
           .setCommandName("MyCommand")
           .setDescription("This is a command that transforms the InputFile into an OutputFile");

    assert(builder.toString() == 
        "Usage: MyCommand {0/InputFile} {1/OutputFile} <[v|verbose]> \n"
       ~"\n"
       ~"Description:\n"
       ~"\tThis is a command that transforms the InputFile into an OutputFile\n"
       ~"\n"
       ~"Positional Args:\n"
       ~"    0,InputFile                  - The input file.\n"
       ~"\n"
       ~"    1,OutputFile                 - The output file.\n"
       ~"\n"
       ~"\n"
       ~"Named Args:\n"
       ~"    -v,--verbose                 - Verbose output\n"
       ~"\n",

        "\n"~builder.toString()
    );
}

/+ BUILT IN SECTION CONTENT +/

/++
 + A simple content class the simply displays a given string.
 +
 + Notes:
 +  This class is fully compliant with the `HelpSectionOptions`.
 + ++/
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

/++
 + A content class for displaying information about a command line argument.
 +
 + Notes:
 +  Please see this class' unittest to see an example of it's output.
 + ++/
final class HelpSectionArgInfoContent : IHelpSectionContent
{
    enum NAME_CHAR_LIMIT_DIVIDER = 4;
    const MIDDLE_AFFIX = " - ";

    /// The information about the arg.
    struct ArgInfo
    {
        /// The different names that this arg can be used with (e.g 'v', 'verbose').
        string[] names;

        /// The description of the argument.
        string description;

        /// Whether the arg is optional or not.
        ArgIsOptional isOptional;
    }

    ArgInfo[] args;
    AutoAddArgDashes addDashes;

    this(ArgInfo[] args, AutoAddArgDashes addDashes)
    {
        this.args = args;
        this.addDashes = addDashes;
    }

    string getContent(const HelpSectionOptions badOptions)
    {
        import std.array     : array;
        import std.algorithm : map, reduce, count, max, splitter, substitute, filter;
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
            // Line wrap. (This line alone is like, O(3n), not even mentioning memory usage)
            auto nameText = lineWrap(
                nameOptions, 
                arg.names.map!(n => (this.addDashes) 
                                     ? (n.length == 1) ? "-"~n : "--"~n
                                     : n
                         )
                         .reduce!((a, b) => a~","~b)
                         .byChar
                         .array
            );

            auto descriptionText = lineWrap(
                descriptionOptions,
                arg.description
            );

            if(descriptionText.length > descriptionOptions.linePrefix.length)
                descriptionText = descriptionText[descriptionOptions.linePrefix.length..$]; // Remove the padding from the first line.

            // Then create our output line-by-line
            auto nameLines = nameText.splitter('\n');
            auto descriptionLines = descriptionText.splitter('\n').filter!(l => l.length > 0);

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
        ],

        AutoAddArgDashes.yes
    );
    auto options = HelpSectionOptions(
        "\t", // Tabs get converted into 4 spaces.
        80
    );

    assert(content.getContent(options) ==
        "    -v,--verbose       - Display detailed information about what the program is\n"
       ~"                         doing.\n"
       ~"    -f,--file          - The input file.\n"
       ~"\n"
       ~"    --super,--longer,  - Some unusuable command with long names and a long desc\n"
       ~"    --names              ription.\n"
       ~"\n",

        "\n"~content.getContent(options)
    );
}