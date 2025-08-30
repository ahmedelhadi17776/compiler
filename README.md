# Simple Language to C Compiler

This is a project for a compilers course that implements a source-to-source compiler. It takes programs written in a custom, simple language and translates them into equivalent, runnable C code. It is built using Flex and Bison.

## Language Features

- **Data Types**: `int`, `float`, `bool`, `string`
- **Variables**: Multi-character names (e.g., `my_var`, `counter_1`).
- **Declarations**: Variables must be declared with their type before use (e.g., `int x;`).
- **Assignments**: `variable = expression;`
- **Control Flow**:
  - `if (condition) { ... } else { ... }` statements.
  - `while (condition) { ... }` loops.
  - `for (init; condition; increment) { ... }` loops.
  - `spidey (expression) { ... }` statements (equivalent to `switch`).
    - `3mk value: { ... }` (equivalent to `case`).
    - `otherwise: { ... }` (equivalent to `default`).
    - `cut;` (equivalent to `break`).
- **Expressions**: Arithmetic (`+`, `-`, `*`, `/`) and relational (`==`, `!=`, `<`, `>`, `<=`, `>=`) operators are supported.
- **Statement Blocks**: Code can be grouped into blocks using curly braces `{ ... }`.
- **Printing**: The `print` statement can be used to output the value of any expression.
- **Comments**: Single-line comments starting with `//` are supported.

## How to Build and Use the Compiler

### Easy Mode (Recommended)

A PowerShell script `run_lang.ps1` is provided to automate the entire compilation and execution process. It will place all generated files in an `out/` directory.

1.  **Build the Compiler**: If you haven't already, build the compiler once:

    ```sh
    win_bison -d compiler.y
    win_flex compiler.l
    gcc compiler.tab.c lex.yy.c -o my_compiler.exe
    ```

2.  **Run Your Code**: Use the script to compile and run any of your `.txt` source files.
    ```powershell
    ./run_lang.ps1 test_spidey.txt
    ```

### Manual Compilation

If you prefer to run the steps manually:

1.  **Prerequisites**: Ensure you have Flex, Bison, and a C compiler (like GCC) installed.

2.  **Compile the Compiler**: Run the following commands in your terminal to build `my_compiler.exe`:

    ```sh
    win_bison -d compiler.y
    win_flex compiler.l
    gcc compiler.tab.c lex.yy.c -o my_compiler.exe
    ```

3.  **Translate Your Code to C**: Use the compiled compiler to translate a source file (e.g., `test.txt`) into C code. This will generate an `output.c` file.

    ```sh
    ./my_compiler.exe test.txt
    ```

4.  **Compile and Run the C Output**: Use a C compiler (like GCC) to compile the generated `output.c` into a final executable, and then run it.
    ```sh
    gcc output.c -o output.exe
    ./output.exe
    ```
