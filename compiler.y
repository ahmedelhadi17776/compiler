%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// --- Abstract Syntax Tree (AST) and Symbol Table Structures ---

// Forward declarations
struct AstNode; 
struct Value;
void execute_ast(struct AstNode* node);

// Define Node Types for the AST
typedef enum {
    NODE_TYPE_CONSTANT,     // A number, string, or boolean literal
    NODE_TYPE_VAR_REF,      // A reference to a variable
    NODE_TYPE_ASSIGN,       // An assignment statement
    NODE_TYPE_OP,           // A binary operation (+, -, *, /)
    NODE_TYPE_IF,           // An if-else statement
    NODE_TYPE_WHILE,        // A while loop
    NODE_TYPE_PRINT,        // The print statement
    NODE_TYPE_STMTS         // A sequence of statements (e.g., in a block)
} NodeType;

// Define data types our language supports
#define TYPE_INT 1
#define TYPE_FLOAT 2
#define TYPE_BOOL 3
#define TYPE_STRING 4
#define TYPE_VOID 5 // For statements that don't return a value

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

// The main AST Node structure
struct AstNode {
    NodeType node_type;
    struct AstNode *left;  // Left child (e.g., left side of '+', or condition of 'if')
    struct AstNode *right; // Right child (e.g., right side of '+', or 'then' block of 'if')
    // Sometimes a third child is needed (e.g., the 'else' block of 'if')
    struct AstNode *third; 
    struct Value value;    // For constant nodes
    char* var_name;        // For variable reference or assignment nodes
};

// The structure for our symbol table entries
struct Symbol {
    char *name;
    int type; // We only need to store the declared type here
};

#define MAX_SYMBOLS 100
struct Symbol sym_table[MAX_SYMBOLS];
int sym_count = 0;

// Symbol table / memory management during execution
struct Value memory_stack[MAX_SYMBOLS];

// Function prototypes
struct AstNode* new_node(NodeType type, struct AstNode* left, struct AstNode* right);
struct AstNode* new_const_node(struct Value val);
struct AstNode* new_var_ref_node(char* name);
struct Symbol* lookup(char* name);
void install(char* name, int type);

extern FILE* yyin;
extern int yylineno;
extern char* yytext;

void yyerror(const char *s);
int yylex(void);
%}

%union {
    int i_val;
    double f_val;
    int b_val;
    char *s_val;
    char *id;
    struct AstNode *node_ptr;
}

// Define tokens for type keywords
%token INT_KWD FLOAT_KWD BOOL_KWD STRING_KWD

// Literal tokens
%token <i_val> INT_LITERAL
%token <f_val> FLOAT_LITERAL
%token <b_val> BOOL_LITERAL
%token <s_val> STRING_LITERAL
%token <id> ID

// Operators and other keywords
%token IF ELSE PRINT WHILE
%token ADD SUB MUL DIV ASSIGN
%token EQ NE LT GT LE GE

// Define operator precedence and resolve ambiguity
%left ADD SUB
%left MUL DIV
%nonassoc IFX
%nonassoc ELSE

// Define non-terminals and their types
%type <node_ptr> program statements statement declaration assignment expression if_statement while_statement statement_block optional_statements
%type <i_val> type_specifier

%%
program:
    /* empty */ { $$ = NULL; }
    | statements { 
        // When parsing is done, execute the tree
        execute_ast($1); 
        printf("Execution complete!\n"); fflush(stdout);
    }
    ;

statements:
    statement { $$ = $1; }
    | statements statement { $$ = new_node(NODE_TYPE_STMTS, $1, $2); }
    ;

statement:
    declaration
    | assignment ';' { $$ = $1; }
    | PRINT expression ';' { $$ = new_node(NODE_TYPE_PRINT, $2, NULL); }
    | if_statement { $$ = $1; }
    | while_statement { $$ = $1; }
    | statement_block { $$ = $1; }
    ;

declaration:
    type_specifier ID ';' { install($2, $1); free($2); $$ = NULL; /* Declarations don't generate executable nodes */ }
    ;

type_specifier:
    INT_KWD    { $$ = TYPE_INT; }
    | FLOAT_KWD  { $$ = TYPE_FLOAT; }
    | BOOL_KWD   { $$ = TYPE_BOOL; }
    | STRING_KWD { $$ = TYPE_STRING; }
    ;

assignment:
    ID ASSIGN expression { $$ = new_node(NODE_TYPE_ASSIGN, $3, NULL); $$->var_name = $1; }
    ;

expression:
    INT_LITERAL    { struct Value v = {.type=TYPE_INT, .val.i_val = $1}; $$ = new_const_node(v); }
    | FLOAT_LITERAL  { struct Value v = {.type=TYPE_FLOAT, .val.f_val = $1}; $$ = new_const_node(v); }
    | BOOL_LITERAL   { struct Value v = {.type=TYPE_BOOL, .val.b_val = $1}; $$ = new_const_node(v); }
    | STRING_LITERAL { struct Value v = {.type=TYPE_STRING, .val.s_val = $1}; $$ = new_const_node(v); }
    | ID             { $$ = new_var_ref_node($1); }
    | expression ADD expression { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = ADD; }
    | expression SUB expression { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = SUB; }
    | expression MUL expression { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = MUL; }
    | expression DIV expression { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = DIV; }
    | expression EQ expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = EQ; }
    | expression NE expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = NE; }
    | expression LT expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = LT; }
    | expression GT expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = GT; }
    | expression LE expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = LE; }
    | expression GE expression  { $$ = new_node(NODE_TYPE_OP, $1, $3); $$->value.val.i_val = GE; }
    | '(' expression ')' { $$ = $2; }
    ;

if_statement:
    IF '(' expression ')' statement %prec IFX { $$ = new_node(NODE_TYPE_IF, $3, $5); }
    | IF '(' expression ')' statement ELSE statement { $$ = new_node(NODE_TYPE_IF, $3, $5); $$->third = $7; }
    ;

while_statement:
    WHILE '(' expression ')' statement { $$ = new_node(NODE_TYPE_WHILE, $3, $5); }
    ;

statement_block:
    '{' optional_statements '}' { $$ = $2; }
    ;

optional_statements:
    /* empty */ { $$ = NULL; }
    | statements { $$ = $1; }
    ;
%%

// --- AST Helper Functions ---
struct AstNode* new_node(NodeType type, struct AstNode* left, struct AstNode* right) {
    struct AstNode* node = (struct AstNode*)malloc(sizeof(struct AstNode));
    node->node_type = type;
    node->left = left;
    node->right = right;
    node->third = NULL;
    node->var_name = NULL;
    return node;
}

struct AstNode* new_const_node(struct Value val) {
    struct AstNode* node = (struct AstNode*)malloc(sizeof(struct AstNode));
    node->node_type = NODE_TYPE_CONSTANT;
    node->value = val;
    node->left = node->right = node->third = NULL;
    node->var_name = NULL;
    return node;
}

struct AstNode* new_var_ref_node(char* name) {
    struct AstNode* node = (struct AstNode*)malloc(sizeof(struct AstNode));
    node->node_type = NODE_TYPE_VAR_REF;
    node->var_name = name;
    node->left = node->right = node->third = NULL;
    return node;
}

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
    sym_table[sym_count].type = type;
    sym_count++;
}

// --- Tree Execution Engine ---
// This function traverses the AST and returns a Value struct
struct Value eval_ast(struct AstNode* node) {
    if (!node) {
        return (struct Value){TYPE_VOID};
    }

    switch (node->node_type) {
        case NODE_TYPE_CONSTANT:
            return node->value;

        case NODE_TYPE_VAR_REF: {
            struct Symbol* sym = lookup(node->var_name);
            int sym_index = sym - sym_table; // Get index from pointer arithmetic
            return memory_stack[sym_index];
        }

        case NODE_TYPE_ASSIGN: {
            struct Symbol* sym = lookup(node->var_name);
            int sym_index = sym - sym_table;
            struct Value rhs_val = eval_ast(node->left);
            
            // Type promotion: allow assigning an INT to a FLOAT
            if (sym->type == TYPE_FLOAT && rhs_val.type == TYPE_INT) {
                rhs_val.type = TYPE_FLOAT;
                rhs_val.val.f_val = rhs_val.val.i_val; // Promote
            }

            // Type check
            if (sym->type != rhs_val.type) {
                yyerror("Type mismatch in assignment.");
                return (struct Value){TYPE_VOID};
            }

            // Free old string value if necessary
            if (sym->type == TYPE_STRING && memory_stack[sym_index].val.s_val) {
                free(memory_stack[sym_index].val.s_val);
            }
            memory_stack[sym_index] = rhs_val;
            return (struct Value){TYPE_VOID};
        }

        case NODE_TYPE_OP: {
            struct Value left_val = eval_ast(node->left);
            struct Value right_val = eval_ast(node->right);
            struct Value result;

            // --- Arithmetic Operations ---
            if (node->value.val.i_val >= ADD && node->value.val.i_val <= DIV) {
                // Promote to float if either operand is a float
                if (left_val.type == TYPE_FLOAT || right_val.type == TYPE_FLOAT) {
                    double left_d = (left_val.type == TYPE_INT) ? left_val.val.i_val : left_val.val.f_val;
                    double right_d = (right_val.type == TYPE_INT) ? right_val.val.i_val : right_val.val.f_val;
                    result.type = TYPE_FLOAT;
                    if (node->value.val.i_val == ADD) result.val.f_val = left_d + right_d;
                    else if (node->value.val.i_val == SUB) result.val.f_val = left_d - right_d;
                    else if (node->value.val.i_val == MUL) result.val.f_val = left_d * right_d;
                    else if (node->value.val.i_val == DIV) {
                        result.type = TYPE_FLOAT;
                        if (right_d == 0) { yyerror("Division by zero"); result.val.f_val = 0; }
                        else { result.val.f_val = left_d / right_d; }
                    }
                } else { // Both are integers
                    result.type = TYPE_INT;
                    if (node->value.val.i_val == ADD) result.val.i_val = left_val.val.i_val + right_val.val.i_val;
                    else if (node->value.val.i_val == SUB) result.val.i_val = left_val.val.i_val - right_val.val.i_val;
                    else if (node->value.val.i_val == MUL) result.val.i_val = left_val.val.i_val * right_val.val.i_val;
                    else if (node->value.val.i_val == DIV) {
                        result.type = TYPE_INT;
                        if (right_val.val.i_val == 0) { yyerror("Division by zero"); result.val.i_val = 0; }
                        else { result.val.i_val = left_val.val.i_val / right_val.val.i_val; }
                    }
                }
            } 
            // --- Relational Operations ---
            else {
                double left_d = (left_val.type == TYPE_INT) ? left_val.val.i_val : left_val.val.f_val;
                double right_d = (right_val.type == TYPE_INT) ? right_val.val.i_val : right_val.val.f_val;
                result.type = TYPE_BOOL;
                if (node->value.val.i_val == EQ) result.val.b_val = (left_d == right_d);
                else if (node->value.val.i_val == NE) result.val.b_val = (left_d != right_d);
                else if (node->value.val.i_val == LT) result.val.b_val = (left_d < right_d);
                else if (node->value.val.i_val == GT) result.val.b_val = (left_d > right_d);
                else if (node->value.val.i_val == LE) result.val.b_val = (left_d <= right_d);
                else if (node->value.val.i_val == GE) result.val.b_val = (left_d >= right_d);
            }
            return result;
        }

        case NODE_TYPE_IF: {
            struct Value cond = eval_ast(node->left);
            if (cond.type != TYPE_BOOL) {
                yyerror("If condition must be a boolean.");
                return (struct Value){TYPE_VOID};
            }

            if (cond.val.b_val) { // If true
                eval_ast(node->right);
            } else if (node->third) { // If false, and there's an else block
                eval_ast(node->third);
            }
            return (struct Value){TYPE_VOID};
        }

        case NODE_TYPE_WHILE: {
            while (1) {
                struct Value cond = eval_ast(node->left);
                if (cond.type != TYPE_BOOL) {
                    yyerror("While condition must be a boolean.");
                    break;
                }
                if (!cond.val.b_val) {
                    break; // Exit loop
                }
                eval_ast(node->right);
            }
            return (struct Value){TYPE_VOID};
        }

        case NODE_TYPE_PRINT: {
            struct Value v = eval_ast(node->left);
            if (v.type == TYPE_INT) printf("Output: %d\n", v.val.i_val);
            else if (v.type == TYPE_FLOAT) printf("Output: %f\n", v.val.f_val);
            else if (v.type == TYPE_BOOL) printf("Output: %s\n", v.val.b_val ? "true" : "false");
            else if (v.type == TYPE_STRING) printf("Output: \"%s\"\n", v.val.s_val);
            fflush(stdout);
            return (struct Value){TYPE_VOID};
        }

        case NODE_TYPE_STMTS:
            eval_ast(node->left);
            eval_ast(node->right);
            return (struct Value){TYPE_VOID};

        default:
            yyerror("Internal error: Unknown AST node type in execution");
            return (struct Value){TYPE_VOID};
    }
}

// The old execute_ast is now just a wrapper for eval_ast
void execute_ast(struct AstNode* node) {
    eval_ast(node);
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
