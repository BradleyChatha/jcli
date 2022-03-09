// See the tests in the tokenizer module, or just try it out with different inputs.
void main(string[] args)
{
    /*
        Examples:

        tokenizer

        tokenizer 123

        tokenizer -- abc def

        tokenizer -help --name "value"

        tokenizer -named="value" orphan -named2 "valueorphan"

        tokenizer 1 - 2

        tokenizer -kek="w
    */
    // TODO: rename to argtokenizer.
    import jcli.argparser;
    import std.stdio;

    ArgTokenizer!(string[]) tokenizer = argTokenizer(args[1 .. $]);

    while (!tokenizer.empty)
    {
        ArgToken token = tokenizer.front;
        tokenizer.popFront();
        
        writeln(
            "kind: ", token.kind,
            ", full slice: ", token.fullSlice,
            ", name/value slice: ", token.nameSlice);


        alias Kind = ArgToken.Kind;

        if (token.kind & Kind.errorBit)
            writeln("That's an error!");

        else if (token.kind & Kind.argumentNameBit)
            writeln("That's a name!");

        else if (token.kind & Kind.valueBit)
            writeln("That's a value!");
        
        writeln();
    }
}