%code requires {
    #include    <string>
    using namespace std;
}

%{
#include    <stdio.h>
#include    <iostream>
int yylex(void);
void yyerror(const char *err);

%}
%start S
%union {
    int Int;
    string* String;
    float Float;
    bool Bool;
}
//lista de tokeni din limbaj
%token<String> STRING STRING_CONST
%token<Int> INT INT_CONST
%token<Float> FLOAT FLOAT_CONST
%token<Bool> BOOL
%token VAR
%token IF WHILE RETURN MAIN_BLOCK PRINT CLASS
%token TRUE FALSE
%token NUME FUNC
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
                 |clasa ;

var_list : VAR lista_nume tip ;

lista_nume : nume 
           | lista_nume ',' nume ;

nume : NUME ;

functie : FUNC NUME '(' param_list ')' functie_block

param_list: //epsilon
          | non_empty_param_list ;

non_empty_param_list : param
                     | non_empty_param_list ',' param

param : NUME ':' tip ;

tip : INT
    | FLOAT
    | BOOL
    | STRING
    | NUME ;

clasa : CLASS NUME '{' membrii_clasa '}'

membrii_clasa : //epsilon
              | membrii_clasa membru_clasa ;

membru_clasa : var_list ';'
             | functie ;

functie_block : '{' f_stmt_list '}' ;

f_stmt_list : //epsilon
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

stmt_list : //epsilon
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

main: MAIN_BLOCK instruction_block {
    cout<<"Parsare functionala!\n";
};
%%

void yyerror(const char *err) {
    cerr<< "Nu prea vrea! "<<err<<'\n';
}

int main() {
    if(yyparse() == 0) {
        return 0;
    } else {
        return 1;
    }
}