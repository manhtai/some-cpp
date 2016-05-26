/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_depth = 0;
int string_len = 0;
int er;

bool is_string_too_long();
void reset_string();
int string_len_err();
int try_add_to_string(char* str);

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT           [0-9]
ALNUM           [0-9a-zA-Z_]
WS              [ \r\v\f\t]

%x COMMENT
%x STRING
%x NEW_STRING

%%

 /*
  *  Nested comments
  */
<INITIAL,COMMENT>"(*"   {
                            comment_depth++;
                            BEGIN(COMMENT);
                        }
<COMMENT>\n             { curr_lineno++; }
<COMMENT>.              {}
<COMMENT>"*)"           {   comment_depth--;
                            if (comment_depth == 0) {
                                BEGIN(INITIAL);
                            }
                        }
<COMMENT><<EOF>>        {
                            BEGIN(INITIAL);
                            cool_yylval.error_msg = "EOF in comment";
                            return(ERROR);
                        }
<INITIAL>"*)"           {
                            cool_yylval.error_msg = "Unmatched *)";
                            return(ERROR);
                        }

"--".*\n                { curr_lineno++; }
"--".*                  { curr_lineno++; }

 /*
  *  The multiple-character operators.
  */
{DARROW}                { return (DARROW); }
"<-"                    { return (ASSIGN); }
"<="                    { return (LE); }
"/"                     { return '/'; }
"+"                     { return '+'; }
"-"                     { return '-'; }
"*"                     { return '*'; }
"("                     { return '('; }
")"                     { return ')'; }
"="                     { return '='; }
"<"                     { return '<'; }
"."                     { return '.'; }
"~"                     { return '~'; }
","                     { return ','; }
";"                     { return ';'; }
":"                     { return ':'; }
"@"                     { return '@'; }
"{"                     { return '{'; }
"}"                     { return '}'; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

(?i:class)              { return(CLASS); }
(?i:else)               { return(ELSE); }
(?i:fi)                 { return(FI); }
(?i:if)                 { return(IF); }
(?i:in)                 { return(IN); }
(?i:inherits)           { return(INHERITS); }
(?i:let)                { return(LET); }
(?i:loop)               { return(LOOP); }
(?i:pool)               { return(POOL); }
(?i:then)               { return(THEN); }
(?i:while)              { return(WHILE); }
(?i:case)               { return(CASE); }
(?i:esac)               { return(ESAC); }
(?i:of)                 { return(OF); }
(?i:new)                { return(NEW); }
(?i:isvoid)             { return(ISVOID); }
(?i:not)                { return(NOT); }

t(?i:rue)               {
                            cool_yylval.boolean = true;
                            return(BOOL_CONST);
                        }
f(?i:alse)              {
                            cool_yylval.boolean = false;
                            return(BOOL_CONST);
                        }

{DIGIT}+                {
                            cool_yylval.symbol = inttable.add_string(yytext);
                            return(INT_CONST);
                        }

[A-Z]{ALNUM}*           {
                            cool_yylval.symbol = idtable.add_string(yytext);
                            return(TYPEID);
                        }

[a-z]{ALNUM}*           {
                            cool_yylval.symbol = idtable.add_string(yytext);
                            return(OBJECTID);
                        }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

\"                      {
                              BEGIN(STRING);
                        }
<STRING>\"              {
                              cool_yylval.symbol = stringtable.add_string(string_buf);
                              reset_string();
                              BEGIN(INITIAL);
                              return(STR_CONST);
                        }
<STRING>(\0|\\\0)       {
                              cool_yylval.error_msg = "String contains null character";
                              BEGIN(NEW_STRING);
                              return(ERROR);
                        }
<NEW_STRING>.*[\"\n]    {
                              BEGIN(INITIAL);
                        }
<STRING>\\\n            {
                              er = try_add_to_string("\n");
                              if (er == ERROR) return er;
                              curr_lineno++;
                        }
<STRING>\n              {
                              BEGIN(INITIAL);
                              curr_lineno++;
                              reset_string();
                              cool_yylval.error_msg = "Unterminated string constant";
                              return(ERROR);
                        }
<STRING><<EOF>>         {
                              BEGIN(INITIAL);
                              cool_yylval.error_msg = "EOF in string constant";
                              return(ERROR);
                        }
<STRING>\\n             {
                              er = try_add_to_string("\n");
                              if (er == ERROR) return er;
                        }
<STRING>\\t             {
                              er = try_add_to_string("\t");
                              if (er == ERROR) return er;
                        }
<STRING>\\b             {
                              er = try_add_to_string("\b");
                              if (er == ERROR) return er;
                        }
<STRING>\\f             {
                              er = try_add_to_string("\f");
                              if (er == ERROR) return er;
                        }
<STRING>\\.             {
                              er = try_add_to_string(&strdup(yytext)[1]);
                              if (er == ERROR) return er;
                        }
<STRING>.               {
                              er = try_add_to_string(yytext);
                              if (er == ERROR) return er;
                        }

  /*
   * The rest
   */

\n                      { curr_lineno++; }

{WS}+                   {}

.                       {
                            cool_yylval.error_msg = yytext;
                            return(ERROR);
                        }

%%

int try_add_to_string(char* str) {
        if (is_string_too_long()) {
                return string_len_err();
        }
        strcat(string_buf, str);
        string_len++;
        return 0;
}


bool is_string_too_long() {
        if (string_len + 1 >= MAX_STR_CONST) {
                BEGIN(NEW_STRING);
                return true;
        }
        return false;
}


void reset_string() {
        string_len = 0;
        string_buf[0] = '\0';
}


int string_len_err() {
        reset_string();
        cool_yylval.error_msg = "String constant too long";
        return(ERROR);
}
