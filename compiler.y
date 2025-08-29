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
    NODE_TYPE_STMTS,        // A sequence of statements
    NODE_TYPE_STMTS_BLOCK   // A block of statements enclosed in braces
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

// Global pointer to the root of the AST
struct AstNode *ast_root = NULL;

// Function prototypes
struct AstNode* new_node(NodeType type, struct AstNode* left, struct AstNode* right);
struct AstNode* new_const_node(struct Value val);
struct AstNode* new_var_ref_node(char* name);
struct Symbol* lookup(char* name);
void install(char* name, int type);
void generate_c_code(FILE* file, struct AstNode* node); // The new code gen function

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
    /* empty */ { ast_root = NULL; }
    | statements { 
        ast_root = $1; // Assign the completed tree to our global root
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
    '{' optional_statements '}' { $$ = new_node(NODE_TYPE_STMTS_BLOCK, $2, NULL); }
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

// --- C Code Generation Engine ---
void generate_c_statement(FILE* file, struct AstNode* node, int indent);
void generate_c_expression(FILE* file, struct AstNode* node);
char* get_c_type_string(int type);
int get_expression_type(struct AstNode* node);

void indent_line(FILE* file, int level) {
    for (int i = 0; i < level * 4; i++) {
        fprintf(file, " ");
    }
}

void generate_c_code(FILE* file, struct AstNode* node) {
    if (!file) return;

    // Print C boilerplate
    fprintf(file, "#include <stdio.h>\n");
    fprintf(file, "#include <stdbool.h>\n\n");
    fprintf(file, "int main() {\n");

    // Print variable declarations
    for (int i = 0; i < sym_count; i++) {
        indent_line(file, 1);
        fprintf(file, "%s %s;\n", get_c_type_string(sym_table[i].type), sym_table[i].name);
    }
    if (sym_count > 0) fprintf(file, "\n");

    // Generate code for the program body
    generate_c_statement(file, node, 1);

    // Print closing boilerplate
    indent_line(file, 1);
    fprintf(file, "return 0;\n");
    fprintf(file, "}\n");
}

void generate_c_statement(FILE* file, struct AstNode* node, int indent) {
    if (!node) return;

    switch (node->node_type) {
        case NODE_TYPE_ASSIGN:
            indent_line(file, indent);
            fprintf(file, "%s = ", node->var_name);
            generate_c_expression(file, node->left);
            fprintf(file, ";\n");
            break;

        case NODE_TYPE_PRINT: {
            int expr_type = get_expression_type(node->left);
            indent_line(file, indent);

            if (expr_type == TYPE_BOOL) {
                fprintf(file, "printf(\"Output: %%s\\n\", (");
                generate_c_expression(file, node->left);
                fprintf(file, ") ? \"true\" : \"false\");\n");
            } else {
                char* format = "%d";
                if (expr_type == TYPE_FLOAT) format = "%f";
                else if (expr_type == TYPE_STRING) format = "%s";

                fprintf(file, "printf(\"Output: %s\\n\", ", format);
                generate_c_expression(file, node->left);
                fprintf(file, ");\n");
            }
            break;
        }

        case NODE_TYPE_IF:
            indent_line(file, indent);
            fprintf(file, "if (");
            generate_c_expression(file, node->left);
            fprintf(file, ") ");
            generate_c_statement(file, node->right, indent); // Blocks handle their own indentation
            if (node->third) {
                fprintf(file, " else ");
                generate_c_statement(file, node->third, indent);
            }
            fprintf(file, "\n");
            break;

        case NODE_TYPE_WHILE:
            indent_line(file, indent);
            fprintf(file, "while (");
            generate_c_expression(file, node->left);
            fprintf(file, ") ");
            generate_c_statement(file, node->right, indent);
            fprintf(file, "\n");
            break;
        
        case NODE_TYPE_STMTS:
            generate_c_statement(file, node->left, indent);
            generate_c_statement(file, node->right, indent);
            break;
        
        case NODE_TYPE_STMTS_BLOCK: // A block of statements
            fprintf(file, "{\n");
            generate_c_statement(file, node->left, indent + 1);
            indent_line(file, indent);
            fprintf(file, "}\n");
            break;

        default:
            indent_line(file, indent);
            generate_c_expression(file, node);
            fprintf(file, ";\n");
            break;
    }
}

void generate_c_expression(FILE* file, struct AstNode* node) {
    if (!node) return;

    switch (node->node_type) {
        case NODE_TYPE_CONSTANT:
            if (node->value.type == TYPE_INT) fprintf(file, "%d", node->value.val.i_val);
            else if (node->value.type == TYPE_FLOAT) fprintf(file, "%f", node->value.val.f_val);
            else if (node->value.type == TYPE_BOOL) fprintf(file, "%s", node->value.val.b_val ? "true" : "false");
            else if (node->value.type == TYPE_STRING) fprintf(file, "\"%s\"", node->value.val.s_val);
            break;

        case NODE_TYPE_VAR_REF:
            fprintf(file, "%s", node->var_name);
            break;

        case NODE_TYPE_OP:
            fprintf(file, "(");
            generate_c_expression(file, node->left);
            char* op_str = "?";
            switch(node->value.val.i_val) {
                case ADD: op_str = "+"; break; case SUB: op_str = "-"; break;
                case MUL: op_str = "*"; break; case DIV: op_str = "/"; break;
                case EQ: op_str = "=="; break; case NE: op_str = "!="; break;
                case LT: op_str = "<"; break; case GT: op_str = ">"; break;
                case LE: op_str = "<="; break; case GE: op_str = ">="; break;
            }
            fprintf(file, " %s ", op_str);
            generate_c_expression(file, node->right);
            fprintf(file, ")");
            break;
        default:
            break;
    }
}

char* get_c_type_string(int type) {
    switch (type) {
        case TYPE_INT: return "int";
        case TYPE_FLOAT: return "float";
        case TYPE_BOOL: return "bool";
        case TYPE_STRING: return "char*";
        default: return "void";
    }
}

int get_expression_type(struct AstNode* node) {
    if (!node) return TYPE_VOID;

    switch(node->node_type) {
        case NODE_TYPE_CONSTANT:
            return node->value.type;
        case NODE_TYPE_VAR_REF:
            return lookup(node->var_name)->type;
        case NODE_TYPE_OP: {
            int ltype = get_expression_type(node->left);
            int rtype = get_expression_type(node->right);
            if (node->value.val.i_val >= ADD && node->value.val.i_val <= DIV) {
                if (ltype == TYPE_FLOAT || rtype == TYPE_FLOAT) return TYPE_FLOAT;
                return TYPE_INT;
            } else {
                return TYPE_BOOL;
            }
        }
        default:
            return TYPE_VOID;
    }
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
        printf("Parsing complete! Generating C code...\n");
        
        FILE* c_output_file = fopen("output.c", "w");
        if (!c_output_file) {
            fprintf(stderr, "Could not open output.c for writing\n");
            return 1;
        }

        generate_c_code(c_output_file, ast_root);
        fclose(c_output_file);

        printf("C code generated in output.c. You can now compile it with:\ngcc output.c -o output.exe\n");

    } else {
        printf("Parsing failed.\n");
    }

    return 0;
}

void yyerror(const char* s) {
    fprintf(stderr, "Parse error on line %d: %s. Near token '%s'\n", yylineno, s, yytext);
}
