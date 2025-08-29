%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void yyerror(const char *s);
int yylex(void);
// Symbol table to store variables
double sym[26];
%}

%union {
    int ival;
    double fval;
    char *id;
}

// Define tokens and their types from the union
%token <ival> INT_NUM
%token <fval> FLOAT_NUM
%token <id> ID
%token IF ELSE PRINT
%token ADD SUB MUL DIV ASSIGN
%token EQ NE LT GT LE GE

// Define operators and their precedence
%left ADD SUB
%left MUL DIV

// Define non-terminals and their types
%type <fval> expression
%type <fval> assignment

%%
program:
    statement ';'
    | program statement ';'
    ;

statement:
    assignment
    | expression  { printf("Result: %f\n", $1); }
    | if_statement
    | PRINT expression { printf("Output: %f\n", $2); }
    ;

assignment:
    ID ASSIGN expression {
        // Semantic Action: Store the value in a symbol table
        if ($1[0] >= 'a' && $1[0] <= 'z') {
            sym[$1[0] - 'a'] = $3;
            $$ = $3;
            printf("Assigned %c = %f\n", $1[0], $3);
        } else {
            yyerror("Variable name must be a single lowercase letter.");
        }
        free($1);
    }
    ;

expression:
    INT_NUM         { $$ = $1; }
    | FLOAT_NUM       { $$ = $1; }
    | ID              { 
        if ($1[0] >= 'a' && $1[0] <= 'z') {
            $$ = sym[$1[0] - 'a']; 
        } else {
            yyerror("Variable name must be a single lowercase letter.");
            $$ = 0;
        }
        free($1);
    } // Semantic Action: Get value from symbol table
    | expression ADD expression { $$ = $1 + $3; }
    | expression SUB expression { $$ = $1 - $3; }
    | expression MUL expression { $$ = $1 * $3; }
    | expression DIV expression {
        // Semantic Check: Division by zero
        if ($3 == 0) {
            yyerror("Error: Division by zero");
            $$ = 0;
        } else {
            $$ = $1 / $3;
        }
    }
    | '(' expression ')' { $$ = $2; }
    ;

if_statement:
    IF '(' expression ')' statement {
        // This is a simplified interpreter action.
        // A real compiler would generate intermediate code.
        printf("An if statement was parsed.\n");
    }
    ;
%%
#include <stdio.h>

extern int yylex();
extern int yylineno;
extern char* yytext;
extern FILE* yyin;

void yyerror(const char* s);

int main(int argc, char** argv) {
    if (argc > 1) {
        FILE* file = fopen(argv[1], "r");
        if (!file) {
            fprintf(stderr, "Could not open %s\n", argv[1]);
            return 1;
        }
        yyin = file;
    }

    if (!yyparse()) {
        printf("Parsing complete!\n");
    } else {
        printf("Parsing failed.\n");
    }

    return 0;
}

void yyerror(const char* s) {
    fprintf(stderr, "Parse error on line %d: %s. Near token '%s'\n", yylineno, s, yytext);
}
