%{
#include    "parser.tab.h"
#include    <stdio.h>    
#include    <iostream>
#include    <string>

void yyerror(const char *err);
%}

%option yylineno
%option noyywrap

cifra   [0-9]
/*nu poate incepe cu cifra*/
nume    [a-zA-Z_][a-zA-Z0-9_]*
spatiu  [ \t\r]+

%%

"int4" { cout<<"int4"<<'\n';return INT;}
"float4" {cout<<"float"<<'\n';return FLOAT;}
"pazvalit" {cout<<"string"<<'\n';return STRING;}
"dublaj" { cout<<"bool"<<'\n';return BOOL;}
"remote" {cout<<"var_declar"<<'\n';return VAR;}
"method" {cout<<"func"<<'\n';return FUNC;}

"type" {cout<<"class"<<'\n';return CLASS;}
"branch" {cout<<"if"<<'\n';return IF;}
"rulaj_pana" {cout<<"while"<<'\n';return WHILE;}
"stop" {cout<<"return"<<'\n';return RETURN;}
"main" {cout<<"main"<<'\n';return MAIN_BLOCK;}
"Print" {cout<<"print"<<'\n';return PRINT;}
"rosu" {cout<<"false"<<'\n';return FALSE;}
"negru" {cout<<"true"<<'\n';return TRUE;}

":<"        { cout<<"atribuire"<<'\n';return ATRIBUIRE;}
"->"        { cout<<"pointer_access"<<'\n';return SAGEATA; }
"&&"        { cout<<"and"<<'\n';return AND; }
"||"        { cout<<"or"<<'\n';return OR;  }
"=="        { cout<<"equal"<<'\n';return EQ;  }
"!="        { cout<<"not_equal"<<'\n';return NE;  }
"<="        { cout<<"less_equal"<<'\n';return LE;  }
">="        { cout<<"GE"<<'\n';return GE;  }
"<"         { cout<<"LT"<<'\n';return LT;  }
">"         { cout<<"GT"<<'\n';return GT;  }
"!"         { cout<<"NOT"<<'\n';return NOT; }

{cifra}+"."{cifra}+   {/*yylval.float_val = atof(yytext);*/cout<<"number_literal"<<'\n'; return FLOAT_CONST;}
{cifra}+              {/*yylval.int_val = atoi(yytext);*/ cout<<"number_literal"<<'\n';return INT_CONST;}

\"([^\\\"]|\\\")*\"   { /*yylval.String = new std::string(yytext);*/cout<<"string_literal"<<'\n'; return STRING_CONST; }

{nume}  { cout<<"var_identifier"<<'\n';return NUME; }

{spatiu} {  }

\n {yylineno++;}

"#".* { }

. { return yytext[0]; }

%%