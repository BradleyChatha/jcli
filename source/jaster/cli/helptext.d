/// Utilities for creating help text.
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

    // Utility functions
    protected final
    {
        string lineWrap(const HelpSectionOptions options, const(char)[] value)
        {
            import jaster.cli.text : lineWrap, LineWrapOptions;

            return value.lineWrap(LineWrapOptions(options.lineCharLimit, options.linePrefix));
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
    ref HelpSection addContent(IHelpSectionContent content) return
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
    static const DEFAULT_SECTION_OPTIONS = HelpSectionOptions("    ", 120);

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

        ///
        ref HelpSection getOrAddSection(string sectionName)
        {
            // If this is too slow then we can move to an AA
            // (p.s. std.algorithm doesn't see _sections as an input range, even if I import std.range for the array primitives)
            foreach(ref section; this._sections)
            {
                if(section.name == sectionName)
                    return section;
            }

            return this.addSection(sectionName);
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
            import std.algorithm : map, each, joiner;
            import std.exception : assumeUnique;
            import std.format    : format;

            char[] output;
            output.reserve(4096);

            // Usages
            this._usages.map!(u => "Usage: "~u)
                        .joiner("\n")
                        .each!(u => output ~= u);

            // Sections
            foreach(ref section; this._sections)
            {
                if(section.content.length == 0)
                    continue;

                // This could all technically be 'D-ified'/'rangeified' but I couldn't make it look nice.
                if(output.length > 0)
                    output ~= "\n\n";
                    
                output ~= section.name~":\n";
                section.content.map!(c => c.getContent(section.options))
                               .joiner("\n")
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
 + Please see the unittest for an example of its usage and output.
 + ++/
final class HelpTextBuilderSimple
{
    private
    {
        alias NamedArg = HelpSectionArgInfoContent.ArgInfo;

        struct PositionalArg
        {
            size_t position;
            HelpSectionArgInfoContent.ArgInfo info;
        }

        struct ArgGroup
        {
            string name;
            string description;
            NamedArg[] named;
            PositionalArg[] positional;

            bool isDefaultGroup()
            {
                return this.name is null;
            }
        }

        struct ArgGroupOrder
        {
            string name;
            int order;
        }

        string           _commandName;
        string           _description;
        ArgGroup[string] _groups;
        ArgGroupOrder[]  _groupOrders;

        ref ArgGroup groupByName(string name)
        {
            return this._groups.require(name, () 
            { 
                this._groupOrders ~= ArgGroupOrder(name, cast(int)this._groupOrders.length);
                return ArgGroup(name); 
            }());
        }
    }

    public final
    {
        ///
        HelpTextBuilderSimple addNamedArg(string group, string[] names, string description, ArgIsOptional isOptional)
        {
            this.groupByName(group).named ~= HelpSectionArgInfoContent.ArgInfo(names, description, isOptional);
            return this;
        }

        ///
        HelpTextBuilderSimple addNamedArg(string group, string name, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(group, [name], description, isOptional);
        }

        ///
        HelpTextBuilderSimple addNamedArg(string[] names, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(null, names, description, isOptional);
        }

        ///
        HelpTextBuilderSimple addNamedArg(string name, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(null, name, description, isOptional);
        }

        ///
        HelpTextBuilderSimple addPositionalArg(string group, size_t position, string description, ArgIsOptional isOptional, string displayName = null)
        {
            import std.conv : to;

            this.groupByName(group).positional ~= PositionalArg(
                position,
                HelpSectionArgInfoContent.ArgInfo(
                    (displayName is null) ? [] : [displayName],
                    description,
                    isOptional
                )
            );

            return this;
        }

        ///
        HelpTextBuilderSimple addPositionalArg(size_t position, string description, ArgIsOptional isOptional, string displayName = null)
        {
            return this.addPositionalArg(null, position, description, isOptional, displayName);
        }

        ///
        HelpTextBuilderSimple setGroupDescription(string group, string description)
        {
            this.groupByName(group).description = description;
            return this;
        }

        ///
        HelpTextBuilderSimple setDescription(string desc)
        {
            this.description = desc;
            return this;
        }

        ///
        HelpTextBuilderSimple setCommandName(string name)
        {
            this.commandName = name;
            return this;
        }

        ///
        @property
        ref string description()
        {
            return this._description;
        }
        
        ///
        @property
        ref string commandName()
        {
            return this._commandName;
        }

        override string toString()
        {
            import std.algorithm : map, joiner, sort, filter;
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

            void writePositionalArgs(ref HelpSection section, PositionalArg[] args)
            {
                section.addContent(new HelpSectionArgInfoContent(
                    args.tee!((p)
                        {
                            // Using git as a precedant for the angle brackets.
                            auto name = "%s".format(p.info.names.joiner("/"));
                            usageString ~= (p.info.isOptional)
                                            ? "["~name~"]"
                                            : "<"~name~">";
                            usageString ~= ' ';
                        })
                        .map!(p => p.info)
                        .array,
                        AutoAddArgDashes.no
                    )
                );
            }

            void writeNamedArgs(Range)(ref HelpSection section, Range args)
            {
                if(args.empty)
                    return;

                section.addContent(new HelpSectionArgInfoContent(
                    args.tee!((a)
                        {
                            auto name = "%s".format(
                                a.names
                                    .map!(n => (n.length == 1) ? "-"~n : "--"~n)
                                    .joiner("|")
                            );

                            usageString ~= (a.isOptional)
                                            ? "["~name~"]"
                                            : name;
                            usageString ~= ' ';
                        })
                        .array,
                        AutoAddArgDashes.yes
                    )
                );
            }

            ref HelpSection getGroupSection(ArgGroup group)
            {
                scope section = &builder.getOrAddSection(group.name);
                if(section.content.length == 0 && group.description !is null)
                {
                    // Section was just made, so add in the description.
                    section.addContent(new HelpSectionTextContent(group.description~"\n"));
                }

                return *section;
            }

            // Not overly efficient, but keep in mind in most programs this function will only ever be called once per run (if even that).
            // The speed is fast enough not to be annoying either.
            // O(3n) + whatever .sort is.
            //
            // The reason we're doing it this way is to ensure everything is shown in this order:
            //  Positional args
            //  Required named args
            //  Optional named args
            //
            // Otherwise you get a mess like: Usage: tool.exe complex <file> --iterations|-i [--verbose|-v] <output> --config|-c
            this._groupOrders.sort!"a.order < b.order"();
            auto groupsInOrder = this._groupOrders.map!(go => this._groups[go.name]);

            // Pre-make certain sections
            builder.addSection("Positional Args");
            builder.addSection("Named Args");

            // Pass #1: Write positional args first, since that puts the usage string in the right order.
            foreach(group; groupsInOrder)
            {
                if(group.positional.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Positional Args") : &getGroupSection(group);
                writePositionalArgs(*section, group.positional);
            }

            // Pass #2: Write required named args.
            foreach(group; groupsInOrder)
            {
                if(group.named.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Named Args") : &getGroupSection(group);
                writeNamedArgs(*section, group.named.filter!(arg => !arg.isOptional));
            }

            // Pass #3: Write optional named args.
            foreach(group; groupsInOrder)
            {
                if(group.named.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Named Args") : &getGroupSection(group);
                writeNamedArgs(*section, group.named.filter!(arg => arg.isOptional));
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
           .addPositionalArg("Utility", 2, "How much to compress the file.", ArgIsOptional.no, "CompressionLevel")
           .addNamedArg(["v","verbose"], "Verbose output", ArgIsOptional.yes)
           .addNamedArg("Utility", "encoding", "Sets the encoding to use.", ArgIsOptional.yes)
           .setCommandName("MyCommand")
           .setDescription("This is a command that transforms the InputFile into an OutputFile")
           .setGroupDescription("Utility", "Utility arguments used to modify the output.");

    assert(builder.toString() == 
        "Usage: MyCommand <InputFile> <OutputFile> <CompressionLevel> [-v|--verbose] [--encoding] \n"
       ~"\n"
       ~"Description:\n"
       ~"    This is a command that transforms the InputFile into an OutputFile\n"
       ~"\n"
       ~"Positional Args:\n"
       ~"    InputFile                    - The input file.\n"
       ~"    OutputFile                   - The output file.\n"
       ~"\n"
       ~"Named Args:\n"
       ~"    -v,--verbose                 - Verbose output\n"
       ~"\n"
       ~"Utility:\n"
       ~"    Utility arguments used to modify the output.\n"
       ~"\n"
       ~"    CompressionLevel             - How much to compress the file.\n"
       ~"    --encoding                   - Sets the encoding to use.",

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
    ///
    string text;

    ///
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
       ~"\tll",
    
        "\n"~content.getContent(options)
    );

    options.lineCharLimit = 200;
    assert(content.getContent(options) == "\tHey Hip Lell Loll");

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
       ~"\tl"
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
    /// The divisor used to determine how many characters to use for the arg's name(s)
    enum NAME_CHAR_LIMIT_DIVIDER = 4;

    /// The string used to split an arg's name(s) from its description.
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

    /// All registered args.
    ArgInfo[] args;

    /// Whether to add the dash prefix to the args' name(s). e.g. "--option" vs "option"
    AutoAddArgDashes addDashes;
    
    ///
    this(ArgInfo[] args, AutoAddArgDashes addDashes)
    {
        this.args = args;
        this.addDashes = addDashes;
    }

    string getContent(const HelpSectionOptions options)
    {
        import std.array     : array;
        import std.algorithm : map, reduce, filter, count, max, splitter, substitute;
        import std.conv      : to;
        import std.exception : assumeUnique;
        import std.utf       : byChar;

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
                         .filter!(n => n.length > 0)
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
                else
                    nameLength = 0;

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

        // Void the last new line, as it provides consistency with HelpSectionTextContent
        if(output.length > 0 && output[$-1] == '\n')
            output = output[0..$-1];

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
        "    ",
        80
    );

    assert(content.getContent(options) ==
        "    -v,--verbose       - Display detailed information about what the program is\n"
       ~"                         doing.\n"
       ~"    -f,--file          - The input file.\n"
       ~"    --super,--longer,  - Some unusuable command with long names and a long desc\n"
       ~"    --names              ription.",

        "\n"~content.getContent(options)
    );
}