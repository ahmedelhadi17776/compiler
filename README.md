# Simple Compiler Frontend

This is a project for a compilers course that implements the first three phases of a compiler for a simple procedural language. It is built using Flex and Bison.

## Language Features

- **Data Types**: `int`, `float`, `bool`, `string`
- **Variables**: Multi-character names (e.g., `my_var`, `counter_1`).
- **Declarations**: Variables must be declared with their type before use (e.g., `int x;`).
- **Assignments**: `variable = expression;`
- **Expressions**: Basic arithmetic (`+`) is supported for numeric types.
- **Printing**: The `print` statement can be used to output the value of any expression.
- **Comments**: Single-line comments starting with `//` are supported.

## Tools Used

- **Flex**: For generating the lexical analyzer.
- **Bison**: For generating the parser.
- **C**: For the semantic actions and the main driver code.
- **GCC**: To compile the final executable.

## How to Build and Run

1.  **Prerequisites**: Ensure you have Flex, Bison, and a C compiler (like GCC) installed and available in your system's PATH. On Windows, the `winflexbison` package is a good choice.

2.  **Compile the Compiler**: Run the following commands in your terminal:

    ```sh
    win_bison -d compiler.y
    win_flex compiler.l
    gcc compiler.tab.c lex.yy.c -o my_compiler.exe
    ```

3.  **Run the Compiler**: The program is configured to take a source file as a command-line argument.
    ```sh
    ./my_compiler.exe test.txt
    ```
    The output of the compilation will be printed to the console.
