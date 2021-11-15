# Overview

These examples show off specific functionality of JCLI. They also double as testing programs.

## Examples

| Name                              | Covers                                                                                        |
|-----------------------------------|-----------------------------------------------------------------------------------------------|
| 00-basic-usage-default-command    | Minimal example of how to use JCLI with arguments and a default command                       |
| 01-named-sub-commands             | Minimal example of creating a name command with multiple names                                |
| 02-shorthand-longhand-args        | Example showing named arguments that have a long hand (--) and short hand (-) name            |
| 03-inheritence-base-commands      | Example showing how JCLI supports inheritance in commands                                     |
| 04-custom-arg-binders             | Example showing how to create a custom arg binder by creating a File instance from a string   |
| 05-built-in-binders               | Example showing most of the built in argument binders                                         |
| 06-result-with-fail-code          | Example showing how the Result type can also contain a special error code                     |
| 08-arg-binder-validation          | Example showing how to create custom arg validation UDAs                                      |
| 09-raw-unparsed-arg-list          | Example showing how to gain access to the raw arg list                                        |
| 10-argument-options               | Example showing how to use `CommandArgOption`                                                 |