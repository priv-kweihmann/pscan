
%{
#include "pscan.h"
static void skip_strings(char literal);
extern int cur_lineno;
%}

%x comment
%x strings
  
reserved    "default"|"struct"|"void"|"for"|"if"|"else"|"while"|"do"|"return"|"case"|"switch"|"break"|"auto"|"continue"|"goto"|"sizeof"|"static"|"typedef"|"union"|"volatile"|"asm"

vartype "char"|"double"|"enum"|"extern"|"float"|"int"|"long"|"register"|"short"|"signed"|"unsigned"|"const"      

cprep "include"|"define"|"undef"|"if"|"else"|"elif"|"endif"|"ifdef"|"ifndef"|"error"|"line"|"pragma"
 

%%
{reserved}                            {// Ignore reserved words because issue arises
                                       // if reserved sizeof used as argument to a defined
                                       // problematic function such as snprintf
                                       // but we also do not want to attempt to check these
                                       // for defined issues in setup_checks function as we know
                                       // they are undefined
                                       // Default last_token state is NOT_PROBLEMATIC

                                       // state->last_token = NOT_PROBLEMATIC;
                                      }

{vartype}                             state->last_token = NOT_PROBLEMATIC;


"#"{cprep}                            state->last_token = NOT_PROBLEMATIC;

NULL				      { if ((state->last_token == PROBLEMATIC) &&
                                          (state->constant_string < 0)) {
                                         state->constant_string = state->args;
                                         }
                                       }

\"                                    {
                                          if (state->last_token == PROBLEMATIC) {
                                          if (state->constant_string < 0) {
                                          state->constant_string = state->args;
                                          }
}
                                          skip_strings('"');
                                      }

\'                                    skip_strings('\'');


\/\/[^\n]*                               /* skip C++ style comments */

[a-zA-Z_][_a-zA-Z0-9]*                state = setup_checks(yytext, state);

[ \t]+                                /* eat up whitespace */

\(                                    {
                                        if (state->args < 0) state->args = 0;
                                        state->braces++;
                                        if (state->braces > 1) {
                                          state = push_stack(state);
                                          state->last_token = NOT_PROBLEMATIC;
                                          state->braces = 1;
                                          state->args = -1;
                                        }
                                      }

\,                                    if (state->last_token == PROBLEMATIC) {
                                        if (state->braces != 0) {
                                          state->args++;
                                        } else {
                                          state->last_token = NOT_PROBLEMATIC;
                                        }
                                      }

\)                                    if (state->last_token == PROBLEMATIC) {
                                        check_function(state);
                                        state->last_token = NOT_PROBLEMATIC;
                                      } else if (state->braces != 0) {
                                        state->braces--;
                                        if (state->braces == 0) {
                                          state = pop_stack();
                                        }
                                      }

.                                     {
                                        if ((state->last_token == PROBLEMATIC) &&
                                             (state->braces == 0)) {
                                          state->last_token = NOT_PROBLEMATIC;
                                        }
                                      }

"/*"    BEGIN(comment);

<comment>[^*\n]*        /* eat anything that's not a '*' */
<comment>"*"+[^*/\n]*   /* eat up '*'s not followed by '/'s */
<comment>\n             {cur_lineno++;}
<comment>"*"+"/"        BEGIN(INITIAL);

"\n"                            { cur_lineno++;}

%%
/**********************************************************************
 * pscan: http://www.striker.ottawa.on.ca/~aland/pscan/
 *
 * Copyright (C) 2000 Alan DeKok <aland@ox.org>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *
 **********************************************************************/
static const char rcsid[] = "$Id: scanner.l,v 1.4 2000/07/17 18:51:45 aland Exp $";

/* static */
void skip_strings(char literal)
{
       int c,last_c=0,done=0;

       while (!done)
       {
         c=input();

         if (c==EOF)
           return;
  
         if ((last_c!='\\') && (c==literal)) // non escaped literal found
           done=1;
         else if ((last_c=='\\') && (c=='\\')) // avoid \\ issue
           last_c=0;
         else
           last_c=c; 
       }
}
