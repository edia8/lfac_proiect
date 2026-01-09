%code requires {
    #include <stdio.h>
    #include <stdlib.h>
    #include <iostream>
    #include <vector>
    #include <string>
    #include "Context.hpp"
    #include "AST.hpp"
    using namespace std;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <vector>
#include <string>
#include <utility> //pentru pair
#include "Context.hpp"

int yydebug = 1;
extern int yylineno;
extern int yylex(void);
void yyerror(const char *err);

// Global context manager
Context context;
FILE* fptr = nullptr;

// Buffers
std::vector<std::string> temp_vars;
std::vector<std::pair<std::string, std::string>> temp_params;
std::string current_type_name; 
SymbolTable::VariableType current_type; 

// Visitor
struct Printer {
    void operator()(int v) const { std::cout << v << std::endl; }
    void operator()(float v) const { std::cout << v << std::endl; }
    void operator()(bool v) const { std::cout << (v ? "true" : "false") << std::endl; }
    void operator()(const std::string& v) const { std::cout << v << std::endl; }
    void operator()(SymbolTable::ClassInstance* v) const { std::cout << "[Object Instance]" << std::endl; }
};
%}

%start S

%union {
    int Int;
    std::string* String;
    float Float;
    bool Bool;
    class ASTNode *node;
}

// Token definitions
%token<String> STRING STRING_CONST NUME
%token<Int> INT INT_CONST
%token<Float> FLOAT FLOAT_CONST
%token<Bool> BOOL TRUE FALSE

%token VAR IF ELSE WHILE RETURN MAIN_BLOCK PRINT CLASS FUNC VOID
%token AND OR NOT LT LE GT GE EQ NE ATRIBUIRE SAGEATA

/* Typed non-terminals */
/* Removed instruction_block and condition from <node> because they don't return values in this logic */
%type<node> expr var_value 
%type<node> func_call method_call

/* Precedence (Lowest to Highest) */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%left OR
%left AND
%left EQ NE
%left LT LE GT GE
%left '+' '-'
%left '*' '/' '%'
%right NOT
%right UMINUS
%left SAGEATA 

%%

S : global_declarari main 
  | main ;

global_declarari : global_declarari global_declarare 
                 | global_declarare ;

global_declarare : var_list ';'
                 | functie 
                 | clasa ;

var_list : VAR lista_nume tip 
           {
               for(const auto& name : temp_vars) {
                   SymbolTable::VariableData default_val;
                   if(current_type == SymbolTable::VariableType::INT) default_val = 0;
                   else if(current_type == SymbolTable::VariableType::FLOAT) default_val = 0.0f;
                   else if(current_type == SymbolTable::VariableType::BOOL) default_val = false;
                   else if(current_type == SymbolTable::VariableType::STRING) default_val = std::string("");
                   else default_val = 0;

                   std::string n = name; 
                   context.get_current_scope()->add_var(current_type_name, n, default_val);
               }
               temp_vars.clear();
           }
           ;

lista_nume : nume 
             {
                temp_vars.push_back(*$<String>1); 
             }
           | lista_nume ',' nume 
             {
                 temp_vars.push_back(*$<String>3);
             }
           ;

nume : NUME ;

functie : FUNC NUME '(' param_list ')' tip_return
          {
              SymbolTable* func_scope = new SymbolTable(*$2, context.get_current_scope());
              context.get_current_scope()->add_func(current_type_name, *$2, temp_params, func_scope);
              context.enter_scope(func_scope);

              for(const auto& [nume, tip] : temp_params) {
                  SymbolTable::VariableData d = 0; 
                  context.get_current_scope()->add_var(tip, nume, d); 
              }
              temp_params.clear();
          }
          functie_block 
          {
              context.exit_scope();
          }
          ;

param_list: /* epsilon */
          | non_empty_param_list ;

non_empty_param_list : param
                     | non_empty_param_list ',' param ;

param : NUME ':' tip 
        {
            temp_params.push_back({*$1, current_type_name});
        }
        ;

tip_return : /*epsilon*/ { current_type_name = "VOID"; }
           | tip;

tip : INT   { current_type = SymbolTable::VariableType::INT;    current_type_name = "INT";      }
    | FLOAT { current_type = SymbolTable::VariableType::FLOAT;  current_type_name = "FLOAT";    }
    | BOOL  { current_type = SymbolTable::VariableType::BOOL;   current_type_name = "BOOL";     }
    | STRING{ current_type = SymbolTable::VariableType::STRING; current_type_name = "STRING";   }
    | NUME  { current_type = SymbolTable::VariableType::OBJECT; current_type_name = *$1;        }
    ;

clasa : CLASS NUME 
        {
            SymbolTable* class_scope = new SymbolTable(*$2, context.get_current_scope());
            context.get_current_scope()->add_class(*$2, class_scope);
            context.enter_scope(class_scope);
        }
        '{' membrii_clasa '}'
        {
            context.exit_scope();
        }
        ;

membrii_clasa : /* epsilon */
              | membrii_clasa membru_clasa ;

membru_clasa : var_list ';'
             | functie ;


/* Block Handling */
functie_block : '{' f_stmt_list '}' ;

f_stmt_list : /* epsilon */
            | f_stmt_list f_stmt ;

f_stmt : var_list ';'
       | stmt ;

/* General Statements */
stmt : s_stmt ';'
     | if_stmt
     | while_stmt
     | instruction_block ;

s_stmt : assignment
       | func_call
       {
           // Func call as statement (return value ignored)
           // We need to execute it if it's an ASTNode
           // But since AST logic is mixed, we assume func_call logic runs inside its rule
           if($1) delete $1; 
       }
       | method_call
       | return_stmt ;

/* IF STATEMENT - Simplified for parsing correctness */
/* Note: Evaluating logic inside parsing for IF/ELSE is tricky because 
   both branches are parsed. Standard approach is building AST node for IF 
   and evaluating later. Here we stick to structure. */
if_stmt : IF expr instruction_block %prec LOWER_THAN_ELSE
        {
             // Eval logic here would execute AFTER the block is parsed (which is too late to prevent execution)
             // or BEFORE (which cannot see the block).
             // For this hybrid parser, we usually just accept that both run or 
             // use a global flag "executing" that the block checks.
             SymbolTable::VariableData condRes = $2->eval(context.get_current_scope());
             // Logic handling...
             delete $2;
        }
        | IF expr instruction_block ELSE instruction_block 
        {
             delete $2;
        }
        ;

while_stmt : WHILE expr instruction_block { delete $2; };

stmt_list : /* epsilon */
          | stmt_list stmt ;

instruction_block: '{' stmt_list '}' ;

/* Assignment */
assignment : var_value ATRIBUIRE expr 
            {
                ASTNode* assignNode = new ASTNode(":<", $1, $3);
                assignNode->eval(context.get_current_scope());
                delete assignNode;
            };

var_value : NUME 
            {
                if(!context.get_current_scope()->get_var(*$1)){
                    std::cout<<"Variable not found\n";
                    YYABORT;
                }
                $$ = new ASTNode(*$1); 
            }
          | var_value SAGEATA NUME 
            {
                
                SymbolTable::VarSymbol* var = context.get_current_scope()->get_var(*$<String>1);
                ASTNode *right = new ASTNode(*$3);

                $$ = new ASTNode("->", $1, right);
            };

/* Function Calls */
func_call : NUME '(' param_list ')'
          {
              // Create AST node for generic function call
              // Since param_list logic fills a vector, you might need to handle args here
              // For now, creating a dummy node to satisfy type requirements
              $$ = new ASTNode("CALL", new ASTNode(*$1), nullptr); 
          }
          | PRINT '(' expr ')' 
          {
            SymbolTable::VariableData res = $3->eval(context.get_current_scope());
            std::visit(Printer{}, res);
            delete $3;
            $$ = nullptr; // Print returns nothing
          };

method_call : var_value SAGEATA NUME '(' param_list ')' { $$ = nullptr; } ;

/* UNIFIED EXPRESSION RULE (Removes Reduce/Reduce Conflicts) */
expr : expr EQ expr     { $$ = new ASTNode("==", $1, $3); }
     | expr NE expr     { $$ = new ASTNode("!=", $1, $3); }
     | expr LT expr     { $$ = new ASTNode("<", $1, $3); }
     | expr LE expr     { $$ = new ASTNode("<=", $1, $3); }
     | expr GT expr     { $$ = new ASTNode(">", $1, $3); }
     | expr GE expr     { $$ = new ASTNode(">=", $1, $3); }
     | expr AND expr    { $$ = new ASTNode("&&", $1, $3); }
     | expr OR expr     { $$ = new ASTNode("||", $1, $3); }
     | NOT expr         { $$ = new ASTNode("!", $2); }
     | expr '+' expr    { $$ = new ASTNode("+", $1, $3); }
     | expr '-' expr    { $$ = new ASTNode("-", $1, $3); }
     | expr '*' expr    { $$ = new ASTNode("*", $1, $3); }
     | expr '/' expr    { $$ = new ASTNode("/", $1, $3); }
     | expr '%' expr    { $$ = new ASTNode("%", $1, $3); }
     | '-' expr %prec UMINUS { $$ = new ASTNode("-", $2); }
     | '(' expr ')'     { $$ = $2; }
     | INT_CONST        { $$ = new ASTNode($1); }
     | FLOAT_CONST      { $$ = new ASTNode($1); }
     | STRING_CONST     { SymbolTable::VariableData val = *$1; $$ = new ASTNode(val); }
     | TRUE             { $$ = new ASTNode(true); }
     | FALSE            { $$ = new ASTNode(false); }
     | var_value        { $$ = $1; }
     | func_call        { $$ = $1; }
     | method_call      { $$ = $1; }
     ;

return_stmt: RETURN
           | RETURN expr ;

main: MAIN_BLOCK 
        {
            SymbolTable* main_scope = new SymbolTable("main", context.get_global_scope());
            context.enter_scope(main_scope);
        }
    instruction_block  
        {
            // Main block finished
        };  

%%

void yyerror(const char *err) {
    std::cerr << "Error: " << err << " at line " << yylineno << "\n";
}

int main() {
    fptr = stdout; 
    int exitno = yyparse();
    if(exitno == 0){
        std::cout << "Parsing Successful!\n";
        if(fptr) {
            fprintf(fptr, "\n=== SYMBOL TABLES ===\n");
            context.get_global_scope()->print(fptr);
        }
        return 0;
    }
    return 1;
}