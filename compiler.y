%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Define data types
#define TYPE_INT 1
#define TYPE_FLOAT 2
#define TYPE_BOOL 3
#define TYPE_STRING 4

// A struct to hold the value and type of any expression or variable
struct Value {
    int type;
    union {
        int i_val;
        double f_val;
        int b_val;
        char *s_val;
    } val;
};

// The structure for our symbol table entries
struct Symbol {
    char *name;
    struct Value value;
};

#define MAX_SYMBOLS 100
struct Symbol sym_table[MAX_SYMBOLS];
int sym_count = 0;

// Function prototypes for symbol table management
struct Symbol* lookup(char* name);
void install(char* name, int type);

void yyerror(const char *s);
int yylex(void);
%}

%union {
    int i_val;
    double f_val;
    int b_val;
    char *s_val;
    char *id;
    struct Value *value_ptr;
}

// Define tokens for type keywords
%token INT_KWD FLOAT_KWD BOOL_KWD STRING_KWD

// --- Renaming old tokens for clarity ---
// We will change INT_NUM -> INT_LITERAL and FLOAT_NUM -> FLOAT_LITERAL in compiler.l next
%token <i_val> INT_LITERAL
%token <f_val> FLOAT_LITERAL
// --- New literal tokens ---
%token <b_val> BOOL_LITERAL
%token <s_val> STRING_LITERAL
%token <id> ID

// Define tokens for operators and other keywords
%token IF ELSE PRINT
%token ADD SUB MUL DIV ASSIGN
%token EQ NE LT GT LE GE

// Define operators and their precedence
%left ADD SUB
%left MUL DIV

// Define non-terminals and their types
%type <value_ptr> expression
%type <i_val> type_specifier

%%
program:
    /* empty */
    | program declaration
    | program statement ';'
    ;

declaration:
    type_specifier ID ';' { install($2, $1); free($2); }
    ;

type_specifier:
    INT_KWD    { $$ = TYPE_INT; }
    | FLOAT_KWD  { $$ = TYPE_FLOAT; }
    | BOOL_KWD   { $$ = TYPE_BOOL; }
    | STRING_KWD { $$ = TYPE_STRING; }
    ;

statement:
    assignment
    | expression  { 
        // Print based on the type of the expression
        struct Value* v = $1;
        if (v->type == TYPE_INT) printf("Result: %d\n", v->val.i_val);
        else if (v->type == TYPE_FLOAT) printf("Result: %f\n", v->val.f_val);
        else if (v->type == TYPE_BOOL) printf("Result: %s\n", v->val.b_val ? "true" : "false");
        else if (v->type == TYPE_STRING) printf("Result: \"%s\"\n", v->val.s_val);
        free(v);
    }
    | if_statement
    | PRINT expression { 
        // Print based on the type of the expression
        struct Value* v = $2;
        if (v->type == TYPE_INT) printf("Output: %d\n", v->val.i_val);
        else if (v->type == TYPE_FLOAT) printf("Output: %f\n", v->val.f_val);
        else if (v->type == TYPE_BOOL) printf("Output: %s\n", v->val.b_val ? "true" : "false");
        else if (v->type == TYPE_STRING) printf("Output: \"%s\"\n", v->val.s_val);
        free(v);
    }
    ;

assignment:
    ID ASSIGN expression {
        struct Symbol* sym = lookup($1);
        if (sym == NULL) {
            char err[256];
            sprintf(err, "Undeclared variable '%s'", $1);
            yyerror(err);
        } else {
            // Basic type checking
            if (sym->value.type != $3->type) {
                yyerror("Type mismatch in assignment.");
            } else {
                // Free old string value if necessary
                if (sym->value.type == TYPE_STRING && sym->value.val.s_val) {
                    free(sym->value.val.s_val);
                }
                // Assign new value
                sym->value = *$3; 
            }
        }
        free($1);
        free($3);
    }
    ;

expression:
    INT_LITERAL    { $$ = (struct Value*)malloc(sizeof(struct Value)); $$->type = TYPE_INT; $$->val.i_val = $1; }
    | FLOAT_LITERAL  { $$ = (struct Value*)malloc(sizeof(struct Value)); $$->type = TYPE_FLOAT; $$->val.f_val = $1; }
    | BOOL_LITERAL   { $$ = (struct Value*)malloc(sizeof(struct Value)); $$->type = TYPE_BOOL; $$->val.b_val = $1; }
    | STRING_LITERAL { $$ = (struct Value*)malloc(sizeof(struct Value)); $$->type = TYPE_STRING; $$->val.s_val = $1; }
    | ID             { 
        struct Symbol* sym = lookup($1);
        if (sym) {
            $$ = (struct Value*)malloc(sizeof(struct Value));
            $$->type = sym->value.type;
            // Copy the value
            if (sym->value.type == TYPE_STRING) {
                $$->val.s_val = strdup(sym->value.val.s_val);
            } else {
                $$->val = sym->value.val;
            }
        } else {
            char err[256];
            sprintf(err, "Undeclared variable '%s'", $1);
            yyerror(err);
            $$ = (struct Value*)malloc(sizeof(struct Value));
            $$->type = TYPE_INT; // Default error value
            $$->val.i_val = 0;
        }
        free($1);
    }
    | expression ADD expression { 
        // For simplicity, addition defaults to float for mixed int/float
        // A real compiler would have much more complex type promotion rules
        $$ = (struct Value*)malloc(sizeof(struct Value));
        $$->type = TYPE_FLOAT;
        double left = ($1->type == TYPE_INT) ? $1->val.i_val : $1->val.f_val;
        double right = ($3->type == TYPE_INT) ? $3->val.i_val : $3->val.f_val;
        $$->val.f_val = left + right;
        free($1); free($3);
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

// --- Symbol Table Implementation ---
struct Symbol* lookup(char* name) {
    for (int i = 0; i < sym_count; i++) {
        if (strcmp(sym_table[i].name, name) == 0) {
            return &sym_table[i];
        }
    }
    return NULL; // Not found
}

void install(char* name, int type) {
    if (lookup(name) != NULL) {
        char err[256];
        sprintf(err, "Variable '%s' already declared", name);
        yyerror(err);
        return;
    }
    if (sym_count >= MAX_SYMBOLS) {
        yyerror("Symbol table overflow");
        return;
    }
    sym_table[sym_count].name = strdup(name);
    sym_table[sym_count].value.type = type;
    // Initialize to zero/null based on type
    if (type == TYPE_STRING) {
        sym_table[sym_count].value.val.s_val = NULL;
    }
    sym_count++;
}


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
