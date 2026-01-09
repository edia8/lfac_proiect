%{
#include    "parser.tab.hpp"
#include    <stdio.h>    
#include    <iostream>
#include    <string>

void yyerror(const char *err);
%}

%option yylineno
%option noyywrap

cifra   [0-9]
//nu poate incepe cu cifra
nume    [a-zA-Z_][a-zA-Z0-9_]*
spatiu  [ \t\r]+

%%

"int4"          {return INT;}
"float4"        {return FLOAT;}
"pazvalit"      {return STRING;}
"dublaj"        {return BOOL;}
"remote"        {return VAR;}
"method"        {return FUNC;}

"type"          {return CLASS;}
"branch"        {return IF;}
"trunk"         {return ELSE;}
"rulaj_pana"    {return WHILE;}
"stop"          {return RETURN;}
"main"          {return MAIN_BLOCK;}
"Print"         {return PRINT;}
"rosu"          {return FALSE;}
"negru"         {return TRUE;}

":<"            { return ATRIBUIRE;}
"->"            { return SAGEATA; }
"&&"            { return AND; }
"||"            { return OR;  }
"=="            { return EQ;  }
"!="            { return NE;  }
"<="            { return LE;  }
">="            { return GE;  }
"<"             { return LT;  }
">"             { return GT;  }
"!"             { return NOT; }

{cifra}+"."{cifra}+   {yylval.Float = atof(yytext);  return FLOAT_CONST;}
{cifra}+              {yylval.Int = atoi(yytext); return INT_CONST;}

\"([^\\\"]|\\\")*\"   { 
                        std::string s(yytext);
                        // Eliminam ghilimelele de la inceput si sfarsit pentru a pastra doar valoarea
                        yylval.String = new std::string(s.substr(1, s.length()-2));
               
                        return STRING_CONST; 
                      }

{nume}  { yylval.String = new std::string(yytext); return NUME; }

{spatiu} {  }

\n { }

"#".* { }

. { return yytext[0]; }

%%