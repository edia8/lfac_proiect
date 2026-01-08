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

//SymbolTables output file
FILE* fptr = nullptr;

// Buffers
std::vector<std::string> temp_vars;
std::vector<std::pair<std::string, std::string>> temp_params;
std::string current_type_name; // Holds "INT", "FLOAT" or "MyClass"
SymbolTable::VariableType current_type; 

// Visitor pentru afisare polimorfica a valorilor
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

%type<node> expr ebool var_value instruction_block condition
%type<node> func_call method_call

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

if_stmt : IF condition
        {
            // Evaluam conditia
            SymbolTable::VariableData condRes = $2->eval(context.get_current_scope());
            bool esteAdevarat = false;
            
            // Verificam daca e bool si e true
            if(std::holds_alternative<bool>(condRes)) {
                esteAdevarat = std::get<bool>(condRes);
            }
            
            if(!esteAdevarat) {
                // AICI E PARTEA GREA LA INTERPRETOARE IN YACC:
                // Yacc executa codul in timp ce parseaza. 
                // Daca vrem sa NU executam blocul de IF, avem nevoie de un flag global
                // "execute_flag" pe care il setam pe false.
                // Dar pentru acest exemplu, presupunem ca doar validam semantic sau evaluam tot (ceea ce nu e ideal pentru if).
            }
        } instruction_block 
        | IF condition         
        {
            // Evaluam conditia
            SymbolTable::VariableData condRes = $2->eval(context.get_current_scope());
            bool esteAdevarat = false;
            
            // Verificam daca e bool si e true
            if(std::holds_alternative<bool>(condRes)) {
                esteAdevarat = std::get<bool>(condRes);
            }
            
            if(!esteAdevarat) {
                // AICI E PARTEA GREA LA INTERPRETOARE IN YACC:
                // Yacc executa codul in timp ce parseaza. 
                // Daca vrem sa NU executam blocul de IF, avem nevoie de un flag global
                // "execute_flag" pe care il setam pe false.
                // Dar pentru acest exemplu, presupunem ca doar validam semantic sau evaluam tot (ceea ce nu e ideal pentru if).
            }
        }instruction_block ELSE instruction_block;

while_stmt : WHILE condition instruction_block ;

stmt_list : /* epsilon */
          | stmt_list stmt ;

instruction_block: '{' stmt_list '}' ;


assignment : var_value ATRIBUIRE expr 
            {
                ASTNode* assignNode = new ASTNode(":<", $1, $3);
                //execut arborele
                assignNode->eval(context.get_current_scope());
                
                delete assignNode;
            };

var_value : NUME 
            {
                $$ = new ASTNode(*$1); //nod de tip IDENTIFIER
            }
          | var_value SAGEATA NUME 
          {
            //Nod operator ->
            ASTNode *right = new ASTNode(*$3);
            $$ = new ASTNode("->",$1,right);
          };

func_call : NUME '(' param_list ')'
          | PRINT '(' expr ')' 
          {
            //eval expresie
            SymbolTable::VariableData res = $3->eval(context.get_current_scope());

            //afisam rezultatul folosind visitor-ul definit mai sus
            std::visit(Printer{}, res);

            delete $3;
            $$ = nullptr;
          };

method_call : var_value SAGEATA NUME '(' param_list ')' ;

/* Ebool rules - strictly boolean operations */
ebool : expr EQ expr {$$ = new ASTNode("==",$1, $3);}
      | expr NE expr {$$ = new ASTNode("!=",$1, $3);}
      | expr LT expr {$$ = new ASTNode("<",$1, $3);}
      | expr LE expr {$$ = new ASTNode("<=",$1, $3);}
      | expr GT expr {$$ = new ASTNode(">",$1, $3);}
      | expr GE expr {$$ = new ASTNode(">=",$1, $3);}
      | ebool AND ebool {$$ = new ASTNode("&&",$1, $3);}
      | ebool OR ebool {$$ = new ASTNode("||",$1, $3);}
      | NOT ebool {$$ = new ASTNode("!",$2 );} //sa bag constructor unar in AST.hpp
      | '(' ebool ')' { $$ = $2; }
      | TRUE { $$ = new ASTNode(true); } 
      | FALSE { $$ = new ASTNode(false); } ;

/* Condition allows boolean expressions or direct variable usage */
condition : ebool { $$ = $1; }
          | var_value { $$ = $1; }
          | func_call { $$ = $1; }
          | method_call { $$ = $1; }
          | '(' condition ')' { $$ = $2; };

/* Main expression rule - ebool is allowed here for assignments like b := true */
expr : ebool {$$ =  $1;}
     | expr '+' expr {$$ = new ASTNode("+",$1, $3);}
     | expr '-' expr {$$ = new ASTNode("-",$1, $3);}
     | expr '*' expr {$$ = new ASTNode("*",$1, $3);}
     | expr '/' expr {$$ = new ASTNode("/",$1, $3);}
     | expr '%' expr {$$ = new ASTNode("%",$1, $3);}
     | '-' expr %prec UMINUS { $$ = new ASTNode("-", $2); }
     | '(' expr ')' {$$ = $2;}
     | INT_CONST { $$ = new ASTNode($1);}
     | FLOAT_CONST { $$ = new ASTNode($1);}
     | STRING_CONST { 
        // FIX: Trebuie sa cream un ASTNode de tip CONSTANT, nu IDENTIFIER
        // Constructorul care primeste stringSimplu creeaza IDENTIFIER.
        // Constructorul care primeste VariableData creeaza CONSTANT.
        SymbolTable::VariableData val = *$1; 
        $$ = new ASTNode(val); 
     }
     | var_value {$$ = $1;}
     | func_call { $$ = $1; }
     | method_call { $$ = $1; } ;

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