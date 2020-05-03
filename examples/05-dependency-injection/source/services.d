module services;

// Again, see JIOC's docs, or even ASP Core's docs on Dependency Injection.
interface IPasswordManager
{
    bool isValidPassword(string pass);
}

final class PasswordManager : IPasswordManager
{
    override bool isValidPassword(string pass)
    {
        return pass == "dman";
    }
}