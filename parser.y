%code requires {
    #include <stdio.h>
    #include <stdlib.h>
    #include <iostream>
    #include <vector>
    #include <string>
    #include "Context.hpp"
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

//SymbolTables output file
FILE* fptr = nullptr;

// Buffers
std::vector<std::string> temp_vars;
std::vector<std::pair<std::string, std::string>> temp_params;
std::string current_type_name; // Holds "INT", "FLOAT" or "MyClass"
SymbolTable::VariableType current_type; 
%}

%start S

%union {
    int Int;
    std::string* String;
    float Float;
    bool Bool;
}

// Token definitions
%token<String> STRING STRING_CONST NUME
%token<Int> INT INT_CONST
%token<Float> FLOAT FLOAT_CONST
%token<Bool> BOOL TRUE FALSE

%token VAR IF WHILE RETURN MAIN_BLOCK PRINT CLASS FUNC VOID
%token AND OR NOT LT LE GT GE EQ NE ATRIBUIRE SAGEATA

%left OR
%left AND
%left EQ NE
%left LT LE GT GE
%left '+' '-'
%left '*' '/' '%'
%right NOT
%right UMINUS

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
               // numele variabilelor colecatate in lista_nume
               for(const auto& name : temp_vars) {
                   SymbolTable::VariableData default_val;
                   
                   // valorile default in dependenta de tip
                   if(current_type == SymbolTable::VariableType::INT) default_val = 0;
                   else if(current_type == SymbolTable::VariableType::FLOAT) default_val = 0.0f;
                   else if(current_type == SymbolTable::VariableType::BOOL) default_val = false;
                   else if(current_type == SymbolTable::VariableType::STRING) default_val = std::string("");
                   else default_val = 0; // Object (pointer initialization handled in add_var)

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
              // cream scopul functiei
              SymbolTable* func_scope = new SymbolTable(*$2, context.get_current_scope());
              
              // adaugam la scopul curent
              context.get_current_scope()->add_func(current_type_name, *$2, temp_params, func_scope);

              // intram in scopul functiei
              context.enter_scope(func_scope);

              // adaugam parametrii ca variabile locale
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
            std::cout<<"DEBUG:"<<*$1<<' '<<current_type_name<<'\n';
            temp_params.push_back({*$1, current_type_name});
        }
        ;
tip_return : /*epsilon for void type*/
        {
            current_type_name = "VOID";
        }
        |
        tip;

tip : INT   { current_type = SymbolTable::VariableType::INT;        current_type_name = "INT";      }
    | FLOAT { current_type = SymbolTable::VariableType::FLOAT;      current_type_name = "FLOAT";    }
    | BOOL  { current_type = SymbolTable::VariableType::BOOL;       current_type_name = "BOOL";     }
    | STRING{ current_type = SymbolTable::VariableType::STRING;     current_type_name = "STRING";   }
    | NUME  { current_type = SymbolTable::VariableType::OBJECT;     current_type_name = *$1;        }
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


functie_block : '{' f_stmt_list '}' ;

f_stmt_list : /* epsilon */
            | f_stmt_list f_stmt ;

f_stmt : var_list ';'
       | stmt ;

stmt : s_stmt ';'
     | if_stmt
     | while_stmt
     | instruction_block ;

s_stmt : assignment
       | func_call
       | method_call
       | return_stmt ;

if_stmt : IF expr instruction_block ;

while_stmt : WHILE expr instruction_block ;

stmt_list : /* epsilon */
          | stmt_list stmt ;

instruction_block: '{' stmt_list '}' ;


assignment : var_value ATRIBUIRE expr ;

var_value : NUME
          | var_value SAGEATA NUME ;

func_call : NUME '(' param_list ')'
          | PRINT '(' expr ')' ;

method_call : var_value SAGEATA NUME '(' param_list ')' ;

expr : expr OR expr
     | expr AND expr
     | expr EQ expr
     | expr NE expr
     | expr LT expr
     | expr LE expr
     | expr GT expr
     | expr GE expr
     | expr '+' expr
     | expr '-' expr
     | expr '*' expr
     | expr '/' expr
     | expr '%' expr
     | '-' expr %prec UMINUS
     | NOT expr
     | '(' expr ')'
     | INT_CONST
     | FLOAT_CONST
     | STRING_CONST
     | TRUE
     | FALSE
     | var_value
     | func_call
     | method_call ;

return_stmt: RETURN
           | RETURN expr ;


main: MAIN_BLOCK 
        {
            SymbolTable* main_scope = new SymbolTable("main", context.get_global_scope());
            context.enter_scope(main_scope);
        }
    instruction_block  
        {
            //to do 
            //logica pentru instructiuni
        };  


%%

void yyerror(const char *err) {
    std::cerr << "Error: " << err << " at line " << yylineno << "\n";
}

int main() {
    fptr = stdout; 
    //fopen("tables.txt","w");
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