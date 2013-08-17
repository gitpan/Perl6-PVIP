%{

#include "pvip.h"
#include <assert.h>

#define YYSTYPE PVIPNode*
#define YY_NAME(n) PVIP_##n
#define YY_XTYPE PVIPParserContext
#define NOP() PVIP_node_new_children(PVIP_NODE_NOP)
#define MAYBE(n) (n) ? (n) : NOP()

/*


    A  Level             Examples
    =  =====             ========
    N  Terms             42 3.14 "eek" qq["foo"] $x :!verbose @$array
    L  Method postfix    .meth .+ .? .* .() .[] .{} .<> .«» .:: .= .^ .:
    N  Autoincrement     ++ --
    R  Exponentiation    **
    L  Symbolic unary    ! + - ~ ? | || +^ ~^ ?^ ^
    L  Multiplicative    * / % %% +& +< +> ~& ~< ~> ?& div mod gcd lcm
    L  Additive          + - +| +^ ~| ~^ ?| ?^
    L  Replication       x xx
    X  Concatenation     ~
    X  Junctive and      & (&) ∩
    X  Junctive or       | ^ (|) (^) ∪ (-)
    L  Named unary       temp let
    N  Structural infix  but does <=> leg cmp .. ..^ ^.. ^..^
    C  Chaining infix    != == < <= > >= eq ne lt le gt ge ~~ === eqv !eqv (<) (elem)
    X  Tight and         &&
    X  Tight or          || ^^ // min max
    R  Conditional       ?? !! ff fff
    R  Item assignment   = => += -= **= xx= .=
    L  Loose unary       so not
    X  Comma operator    , :
    X  List infix        Z minmax X X~ X* Xeqv ...
    R  List prefix       print push say die map substr ... [+] [*] any Z=
    X  Loose and         and andthen
    X  Loose or          or xor orelse
    X  Sequencer         <== ==> <<== ==>>
    N  Terminator        ; {...} unless extra ) ] }

*/

static int node_all_children_are(PVIPNode * node, PVIP_node_type_t type) {
    int i;
    for (i=0; i<node->children.size; ++i) {
        if (node->children.nodes[i]->type != type) {
            return 0;
        }
    }
    return 1;
}

PVIPNode* maybe(PVIPNode *node) {
    return node ? node : PVIP_node_new_children(PVIP_NODE_NOP);
}

typedef struct {
    const char  *buf;
    size_t len;
    size_t pos;
} PVIPParserStringState;

typedef struct {
    int line_number;
    PVIPNode *root;
    int is_string;
    PVIPParserStringState *str;
    FILE *fp;
} PVIPParserContext;

static char PVIP_input(char *buf, YY_XTYPE D) {
    if (D.is_string) {
        if (D.str->len == D.str->pos) {
            return 0;
        } else {
            *buf = D.str->buf[D.str->pos];
            D.str->pos = D.str->pos+1;
            return 1;
        }
    } else {
        char c = fgetc(D.fp);
        *buf = c;
        return (c==EOF) ? 0 : 1;
    }
}

#define YY_INPUT(buf, result, max_size, D)		\
    result = PVIP_input(buf, D);

%}

comp_init = BOM? e:statementlist - end-of-file {
    $$ = (G->data.root = e);
}
    | BOM? end-of-file { $$ = (G->data.root = PVIP_node_new_children(PVIP_NODE_NOP)); }

BOM='\357' '\273' '\277'

statementlist =
    (
        s1:statement {
            $$ = PVIP_node_new_children(PVIP_NODE_STATEMENTS);
            PVIP_node_push_child($$, s1);
            s1 = $$;
        }
        (
            - s2:statement {
                PVIP_node_push_child(s1, s2);
                $$=s1;
            }
        )* eat_terminator?
    )
    | ws+ { $$=NOP(); }

# TODO
statement =
        - (
              while_stmt
            | use_stmt
            | enum_stmt
            | if_stmt
            | for_stmt
            | unless_stmt
            | module_stmt
            | multi_method_stmt
            | die_stmt
            | has_stmt
            | '...' { $$ = PVIP_node_new_children(PVIP_NODE_STUB); }
            | funcdef - ';'*
            | bl:block ';'*
            | 'END' - b:block { $$ = PVIP_node_new_children1(PVIP_NODE_END, b) }
            | 'BEGIN' - b:block { $$ = PVIP_node_new_children1(PVIP_NODE_BEGIN, b) }
            | b:normal_or_postfix_stmt { $$ = b; }
            | ';'+ {
                $$ = PVIP_node_new_children(PVIP_NODE_NOP);
            }
          )

normal_or_postfix_stmt =
    n:normal_stmt (
          ( ' '+ 'if' - cond_if:expr - eat_terminator ) { $$ = PVIP_node_new_children2(PVIP_NODE_IF, cond_if, n); }
        | ( ' '+ 'unless' - cond_unless:expr - eat_terminator ) { $$ = PVIP_node_new_children2(PVIP_NODE_UNLESS, cond_unless, n); }
        | ( ' '+ 'for' - cond_for:expr - eat_terminator ) { $$ = PVIP_node_new_children2(PVIP_NODE_FOR, cond_for, n); }
        | ( ' '+ 'while' - cond_for:expr - eat_terminator ) { $$ = PVIP_node_new_children2(PVIP_NODE_WHILE, cond_for, n); }
        | ( - eat_terminator ) { $$=n; }
    )

enum_stmt =
    'my' ws+ 'enum' ws+ i:ident - e:expr { $$ = PVIP_node_new_children1(PVIP_NODE_MY, PVIP_node_new_children2(PVIP_NODE_ENUM, i, e)); }
    | 'enum' ws+ i:ident - q:qw { $$ = PVIP_node_new_children2(PVIP_NODE_ENUM, i, q); }

last_stmt = 'last' { $$ = PVIP_node_new_children(PVIP_NODE_LAST); }

next_stmt = 'next' { $$ = PVIP_node_new_children(PVIP_NODE_NEXT); }

has_stmt =
    'has' ws+ v:attr_vars eat_terminator {
        $$ = PVIP_node_new_children1(PVIP_NODE_HAS, v);
    }

attr_vars =
    '$' (
          '.' <[a-z]+> { $$=PVIP_node_new_string(PVIP_NODE_PRIVATE_ATTRIBUTE, yytext, yyleng); }
        | '!' <[a-z]+> { $$=PVIP_node_new_string(PVIP_NODE_PUBLIC_ATTRIBUTE, yytext, yyleng); }
    )

multi_method_stmt =
    'multi' ws - m:method_stmt { $$ = PVIP_node_new_children1(PVIP_NODE_MULTI, m); }
    | method_stmt

method_stmt =
    { p=NULL; } 'method' ws - i:ident - '(' - p:params? - ')' - b:block { $$ = PVIP_node_new_children3(PVIP_NODE_METHOD, i, MAYBE(p), b); }

normal_stmt = return_stmt | last_stmt | next_stmt | expr

return_stmt = 'return' ws e:expr { $$ = PVIP_node_new_children1(PVIP_NODE_RETURN, e); }

module_stmt = 'module' ws pkg:pkg_name eat_terminator { $$ = PVIP_node_new_children1(PVIP_NODE_MODULE, pkg); }

# use Perl:ver<6.*>;
use_stmt =
    'use '
    - pkg:pkg_name { $$ = PVIP_node_new_children1(PVIP_NODE_USE, pkg); } 
    (
        ':ver<' < [^>]+ > {
            PVIP_node_push_child($$,
                PVIP_node_new_children2(PVIP_NODE_PAIR,
                    PVIP_node_new_string(PVIP_NODE_STRING, "ver", 3),
                    PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng)
                )
            );
        } '>'
    )?
    eat_terminator

pkg_name = < [a-zA-Z] [a-zA-Z0-9]* ( '::' [a-zA-Z0-9]+ )* > {
    $$ = PVIP_node_new_string(PVIP_NODE_IDENT, yytext, yyleng);
}

die_stmt = 'die' ws e:expr eat_terminator { $$ = PVIP_node_new_children1(PVIP_NODE_DIE, e); }

while_stmt = 'while' - cond:expr - (
            b:block {
                $$ = PVIP_node_new_children2(PVIP_NODE_WHILE, cond, b);
            }
            | l:lambda {
                $$ = PVIP_node_new_children2(PVIP_NODE_WHILE, cond, l);
            }
        )

for_stmt =
    'for' - src:expr - body:block { $$ = PVIP_node_new_children2(PVIP_NODE_FOR, src, body); }
    | 'for' - src:expr - body:lambda { $$ = PVIP_node_new_children2(PVIP_NODE_FOR, src, body); }

unless_stmt = 
        { body=NULL; } 'unless' - cond:expr - '{' - body:statementlist? - '}' {
            $$ = PVIP_node_new_children2(PVIP_NODE_UNLESS, cond, MAYBE(body));
        }
        # workaround for `unless Mu { }`
        | { body=NULL; } 'unless' - cond:ident - '{' - body:statementlist? - '}' {
            $$ = PVIP_node_new_children2(PVIP_NODE_UNLESS, cond, MAYBE(body));
        }

if_stmt = { if_body=NULL; } 'if' - if_cond:expr - '{' - if_body:statementlist? - '}' {
            $$ = PVIP_node_new_children2(PVIP_NODE_IF, if_cond, MAYBE(if_body));
            if_cond=$$;
        }
        (
            ws+ 'elsif' - elsif_cond:expr - '{' - elsif_body:statementlist - '}' {
                // elsif_body.change_type(PVIP_NODE_ELSIF);
                $$ = PVIP_node_new_children2(PVIP_NODE_ELSIF, elsif_cond, elsif_body);
                // if_cond.push_child(elsif_cond);
                PVIP_node_push_child(if_cond, $$);
            }
        )*
        (
            ws+ 'else' ws+ - '{' - else_body:statementlist - '}' {
                PVIP_node_change_type(else_body, PVIP_NODE_ELSE);
                PVIP_node_push_child(if_cond, else_body);
            }
        )? { $$=if_cond; }

paren_args = '(' - a:expr - ','? - ')' {
        if (a->type == PVIP_NODE_LIST) {
            $$ = a;
            PVIP_node_change_type($$, PVIP_NODE_ARGS);
        } else {
            $$ = PVIP_node_new_children1(PVIP_NODE_ARGS, a);
        }
    }
    | '(' - ')' { $$ = PVIP_node_new_children(PVIP_NODE_ARGS); }

bare_args = a:expr {
        if (a->type == PVIP_NODE_LIST) {
            $$ = a;
            PVIP_node_change_type($$, PVIP_NODE_ARGS);
        } else {
            $$ = PVIP_node_new_children1(PVIP_NODE_ARGS, a);
        }
    }

expr = sequencer_expr

# TODO
sequencer_expr = loose_or_expr

loose_or_expr =
    f1:loose_and_expr (
        - 'or' ![a-zA-Z0-9_] - f2:loose_and_expr { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_OR, f1, f2); f1=$$; }
        | - 'xor' ![a-zA-Z0-9_] - f2:loose_and_expr { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_XOR, f1, f2); f1=$$; }
    )* { $$=f1; }

loose_and_expr =
    f1:list_prefix_expr (
        - 'and' ![a-zA-Z0-9_]      - f2:list_prefix_expr { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_AND, f1, f2); f1=$$; }
        | - 'andthen' ![a-zA-Z0-9_]  - f2:list_prefix_expr { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_ANDTHEN, f1, f2); f1=$$; }
    )* { $$=f1; }

list_prefix_expr =
    '[' a:reduce_operator ']' - b:list_infix_expr { $$ = PVIP_node_new_children2(PVIP_NODE_REDUCE, a, b); }
    | (v:lvalue - ':'? '=' - e:list_infix_expr) { $$ = PVIP_node_new_children2(PVIP_NODE_BIND, v, e); }
    | list_infix_expr

list_infix_expr =
    a:comma_operator_expr {$$=a;} (
        - 'Z' - b:comma_operator_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_Z, a, b);
            a=$$;
        }
    )*

reduce_operator =
    < '*' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < '+' ![<>=] > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < '-' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < '<=' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < '>=' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < 'min' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | < 'max' > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }

lvalue =
    my
    | v:variable { $$=v; } (
        '[' - e:expr - ']' { $$=PVIP_node_new_children2(PVIP_NODE_ATPOS, v, e); }
    )?

comma_operator_expr = a:loose_unary_expr { $$=a; } ( - ',' - b:loose_unary_expr {
        if (a->type==PVIP_NODE_LIST) {
            PVIP_node_push_child(a, b);
            $$=a;
        } else {
            $$ = PVIP_node_new_children2(PVIP_NODE_LIST, a, b);
            a=$$;
        }
    } )*

loose_unary_expr =
    'not' - f1:item_assignment_expr { $$ = PVIP_node_new_children1(PVIP_NODE_NOT, f1); }
    | f1:item_assignment_expr { $$=f1 }

item_assignment_expr =
    a:conditional_expr (
        - (
              '=>'  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_PAIR,             a, b); a=$$; }
            | '+='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_ADD,      a, b); a=$$; }
            | '-='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_SUB,      a, b); a=$$; }
            | '*='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_MUL,      a, b); a=$$; }
            | '/='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_DIV,      a, b); a=$$; }
            | '%='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_MOD,      a, b); a=$$; }
            | '**=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_POW,      a, b); a=$$; }
            | '+|=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_BIN_OR,   a, b); a=$$; }
            | '+&=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_BIN_AND,  a, b); a=$$; }
            | '+^=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_BIN_XOR,  a, b); a=$$; }
            | '+<=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_BLSHIFT,  a, b); a=$$; }
            | '+>=' - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_BRSHIFT,  a, b); a=$$; }
            | '~='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_CONCAT_S, a, b); a=$$; }
            | 'x='  - b:item_assignment_expr { $$ = PVIP_node_new_children2(PVIP_NODE_INPLACE_REPEAT_S, a, b); a=$$; }
        )
    )* { $$=a; }

conditional_expr = e1:tight_or - '??' - e2:tight_or - '!!' - e3:tight_or { $$ = PVIP_node_new_children3(PVIP_NODE_CONDITIONAL, e1, e2, e3); }
                | tight_or

tight_or = f1:tight_and (
        - '||' - f2:tight_and { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_OR, f1, f2); f1 = $$; }
        | - '^^' - f2:tight_and { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_XOR, f1, f2); f1 = $$; }
    )* { $$ = f1; }

tight_and = f1:chaining_infix_expr (
        - '&&' - f2:chaining_infix_expr { $$ = PVIP_node_new_children2(PVIP_NODE_LOGICAL_AND, f1, f2); f1 = $$; }
    )* { $$ = f1; }

#  C  Chaining infix    != == < <= > >= eq ne lt le gt ge ~~ === eqv !eqv (<) (elem)
chaining_infix_expr = f1:structural_infix_expr { $$ = PVIP_node_new_children1(PVIP_NODE_CHAIN, f1); f1=$$; } (
          - '==='  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_VALUE_IDENTITY,          f2); PVIP_node_push_child(f1, tmp); }
        | - '==' !'=' - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_EQ,          f2); PVIP_node_push_child(f1, tmp); }
        | - '!='  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_NE,          f2); PVIP_node_push_child(f1, tmp); }
        | - '<'   - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_LT,          f2); PVIP_node_push_child(f1, tmp); }
        | - '<='  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_LE,          f2); PVIP_node_push_child(f1, tmp); }
        | - '>'   - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_GT,          f2); PVIP_node_push_child(f1, tmp); }
        | - '>='  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_GE,          f2); PVIP_node_push_child(f1, tmp); }
        | - '~~'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_SMART_MATCH, f2); PVIP_node_push_child(f1, tmp); }
        | - '!~~' - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_NOT_SMART_MATCH, f2); PVIP_node_push_child(f1, tmp); }
        | - 'eqv' - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_EQV,         f2); PVIP_node_push_child(f1, tmp); }
        | - 'eq'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STREQ,       f2); PVIP_node_push_child(f1, tmp); }
        | - 'ne'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STRNE,       f2); PVIP_node_push_child(f1, tmp); }
        | - 'gt'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STRGT,       f2); PVIP_node_push_child(f1, tmp); }
        | - 'ge'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STRGE,       f2); PVIP_node_push_child(f1, tmp); }
        | - 'lt'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STRLT,       f2); PVIP_node_push_child(f1, tmp); }
        | - 'le'  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_STRLE,       f2); PVIP_node_push_child(f1, tmp); }
        | - '=:='  - f2:structural_infix_expr { PVIPNode* tmp = PVIP_node_new_children1(PVIP_NODE_CONTAINER_IDENTITY,       f2); PVIP_node_push_child(f1, tmp); }
    )* { if (f1->children.size==1) { $$=f1->children.nodes[0]; } else { $$=f1; } }

structural_infix_expr =
    a1:named_unary_expr (
        - '..' !'.' - a2:named_unary_expr { $$=PVIP_node_new_children2(PVIP_NODE_RANGE, a1, a2); a1=$$; }
        | - 'cmp' ![a-z] - a2:named_unary_expr { $$=PVIP_node_new_children2(PVIP_NODE_CMP, a1, a2); a1=$$; }
        | - '<=>' - a2:named_unary_expr { $$=PVIP_node_new_children2(PVIP_NODE_NUM_CMP, a1, a2); a1=$$; }
    )? { $$=a1; }

funcall =
    !reserved i:ident - a:paren_args {
        $$ = PVIP_node_new_children2(PVIP_NODE_FUNCALL, i, a);
    }
    | !reserved i:ident ws+ !'{' a:bare_args {
        $$ = PVIP_node_new_children2(PVIP_NODE_FUNCALL, i, a);
    }

#  L  Named unary       temp let
named_unary_expr =
    'my' ws+ a:junctive_or_expr { $$ = PVIP_node_new_children1(PVIP_NODE_MY, a); }
    | 'our' ws+ a:junctive_or_expr { $$ = PVIP_node_new_children1(PVIP_NODE_OUR, a); }
    | !reserved i:ident ws+ a:bare_args { $$ = PVIP_node_new_children2(PVIP_NODE_FUNCALL, i, a); }
    | junctive_or_expr

junctive_or_expr =
    a:junctive_and_expr (
        - (
            '|' ![|] - b:junctive_and_expr { a = PVIP_node_new_children2(PVIP_NODE_JUNCTIVE_OR, a, b); }
        )
    )* { $$ = a; }

junctive_and_expr =
    a:concatenation_expr (
        - (
            '&' ![&] - b:concatenation_expr { a = PVIP_node_new_children2(PVIP_NODE_JUNCTIVE_AND, a, b); }
            | 'S&' ![&] - b:concatenation_expr { a = PVIP_node_new_children2(PVIP_NODE_JUNCTIVE_SAND, a, b); }
        )
    )* { $$ = a; }

#  X  Concatenation     ~
concatenation_expr =
    replication_expr

#  L  Replication       x xx
# TODO: xx
replication_expr =
    l:additive_expr (
        - (
            'x'  ![a-zA-Z0-9_] - r:additive_expr {
                $$ = PVIP_node_new_children2(PVIP_NODE_REPEAT_S, l, r);
                l=$$;
            }
        )
    )* { $$=l; }

additive_expr =
    l:multiplicative_expr (
          - '+|' - r:exponentiation_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_BIN_OR, l, r);
            l = $$;
        }
        | - '+^' - r:exponentiation_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_BIN_XOR, l, r);
            l = $$;
        }
        | - '+' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_ADD, l, r1);
            l = $$;
          }
        | - '-' !'-' - r2:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_SUB, l, r2);
            l = $$;
          }
        | - '~'  !'~' - r2:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_STRING_CONCAT, l, r2);
            l = $$;
          }
        | - '~|' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_BITWISE_OR, l, r1);
            l = $$;
          }
        | - '~&' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_BITWISE_AND, l, r1);
            l = $$;
          }
        | - '~^' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_BITWISE_XOR, l, r1);
            l = $$;
          }
        | - '%%' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_IS_DIVISIBLE_BY, l, r1);
            l = $$;
          }
        # You may use !%% to mean "not divisible by", though % itself generally has the same effect.
        | - '!%%' ![<>=] - r1:multiplicative_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_NOT_DIVISIBLE_BY, l, r1);
            l = $$;
          }
    )* {
        $$ = l;
    }

multiplicative_expr =
    l:symbolic_unary (
        - '*' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_MUL, l, r);
            l = $$;
        }
        | - '/' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_DIV, l, r);
            l = $$;
        }
        | - '%' !'%' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_MOD, l, r);
            l = $$;
        }
        | - '+&' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_BIN_AND, l, r);
            l = $$;
        }
        | - '+>' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_BRSHIFT, l, r);
            l = $$;
        }
        | - '+<' - r:symbolic_unary {
            $$ = PVIP_node_new_children2(PVIP_NODE_BLSHIFT, l, r);
            l = $$;
        }
    )* {
        $$ = l;
    }

#  L  Symbolic unary    ! + - ~ ? | || +^ ~^ ?^ ^
symbolic_unary =
    '+' !'^' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_PLUS, f1); }
    | '-' !'-' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_MINUS, f1); }
    | '!' - f1:symbolic_unary { $$ = PVIP_node_new_children1(PVIP_NODE_NOT, f1); }
    | '+^' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_BITWISE_NEGATION, f1); }
    | '~' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_TILDE, f1); }
    | '?' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_BOOLEAN, f1); }
    | '^' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_UPTO, f1); }
    | '|' !'|' - f1:exponentiation_expr { $$ = PVIP_node_new_children1(PVIP_NODE_UNARY_FLATTEN_OBJECT, f1); }
    | exponentiation_expr

exponentiation_expr = 
    f1:autoincrement_expr (
        - '**' - f2:autoincrement_expr {
            $$ = PVIP_node_new_children2(PVIP_NODE_POW, f1, f2);
            f1=$$;
        }
    )* {
        $$=f1;
    }

# ++, -- is not supported yet
autoincrement_expr =
      '++' v:variable { $$ = PVIP_node_new_children1(PVIP_NODE_PREINC, v); }
    | '--' v:variable { $$ = PVIP_node_new_children1(PVIP_NODE_PREDEC, v); }
    | n:method_postfix_expr (
        '++' { $$ = PVIP_node_new_children1(PVIP_NODE_POSTINC, n); }
        | '--' { $$ = PVIP_node_new_children1(PVIP_NODE_POSTDEC, n); }
        | '' { $$=n; }
    )

method_postfix_expr =
          f1:term { $$=f1; } (
              '{' - k:term - '}' { $$ = PVIP_node_new_children2(PVIP_NODE_ATKEY, f1, k); f1=$$; }
            | '<' - k:atkey_key - '>' {  $$ = PVIP_node_new_children2(PVIP_NODE_ATKEY, f1, k); f1=$$; }
            | '.^' f2:ident { f3 = NULL; } f3:paren_args? {
                $$ = PVIP_node_new_children3(PVIP_NODE_META_METHOD_CALL, f1, f2, maybe(f3));
                f1=$$;
            }
            | '.'? '[' - f2:term - ']' {
                $$ = PVIP_node_new_children2(PVIP_NODE_ATPOS, f1, f2);
                f1=$$;
            }
            | '.' f2:ident (
                ':' - f3:bare_args {
                    /* @*INC.push: '/etc' */
                    $$ = PVIP_node_new_children3(PVIP_NODE_METHODCALL, f1, f2, f3);
                    f1=$$;
                }
                | f3:paren_args {
                    $$ = PVIP_node_new_children3(PVIP_NODE_METHODCALL, f1, f2, f3);
                    f1=$$;
                }
            )
            | '.' f2:ident { $$=PVIP_node_new_children2(PVIP_NODE_METHODCALL, f1, f2); f1=$$; }
            | '.' f2:string f3:paren_args {
                /* Rakudo says "Quoted method name requires parenthesized arguments" */
                $$ = PVIP_node_new_children3(PVIP_NODE_METHODCALL, f1, f2, f3);
                f1=$$;
            }
            | a:paren_args { $$ = PVIP_node_new_children2(PVIP_NODE_FUNCALL, f1, a); f1=$$; }
          )*

atkey_key = < [^>]+ > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }

term = 
    complex
    | integer
    | path
    | dec_number
    | string
    | '(' - e:expr  - ')' { $$ = e; }
    | variable
    | '$?LINE' { $$ = PVIP_node_new_int(PVIP_NODE_INT, G->data.line_number); }
    | array
    | class
    | role
    | funcall
    | qw
    | hash
    | lambda
    | it_method
    | enum
    | 'try' ws - b:block { $$ = PVIP_node_new_children1(PVIP_NODE_TRY, b); }
    | 'try' ws+ b:expr { $$ = PVIP_node_new_children1(PVIP_NODE_TRY, b); }
    | perl5_regexp
    | 'm:P5/./' { $$ = PVIP_node_new_children(PVIP_NODE_NOP); }
    | regexp
    | !reserved ident
    | '\\' t:term { $$ = PVIP_node_new_children1(PVIP_NODE_REF, t); }
    | '(' - ')' { $$ = PVIP_node_new_children(PVIP_NODE_LIST); }
    | ':' < key:ident > '<' value:ident '>' {
        PVIP_node_change_type(key, PVIP_NODE_STRING);
        PVIP_node_change_type(value, PVIP_NODE_STRING);
        $$ = PVIP_node_new_children2(PVIP_NODE_PAIR, key, value);
    }
    | ':' < [a-z]+ > { $$ = PVIP_node_new_children2(PVIP_NODE_PAIR, PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng), PVIP_node_new_children(PVIP_NODE_TRUE)); }
    | ':' v:variable {
        $$ = PVIP_node_new_children2(
            PVIP_NODE_PAIR,
            PVIP_node_new_string(PVIP_NODE_STRING, v->pv->buf, v->pv->len),
            v
        );
    }
    | funcref
    | < '$~' [A-Za-z] [A-Za-z0-9]* > { $$ = PVIP_node_new_string(PVIP_NODE_SLANGS, yytext, yyleng); }
    | '*' ![*=] { $$ = PVIP_node_new_children(PVIP_NODE_WHATEVER); }
    | attr_vars
    # 'rand' is resreved word.
    | 'rand' ![-a-zA-Z0-9] { $$ = PVIP_node_new_children(PVIP_NODE_RAND); }

enum =
    'enum' ws+ q:qw { $$ = PVIP_node_new_children2(PVIP_NODE_ENUM, PVIP_node_new_children(PVIP_NODE_NOP), q); }

path =
    'qp{' { $$ = PVIP_node_new_string(PVIP_NODE_PATH, "", 0); } (
        < [^}] + > { PVIP_node_append_string($$, yytext, yyleng); }
        | esc "}" { PVIP_node_append_string($$, "/", 1); }
    )+ '}'

funcref = '&' i:ident { $$ = PVIP_node_new_children1(PVIP_NODE_FUNCREF, i); }

twvars = 
    '$*OUT' { $$ = PVIP_node_new_children(PVIP_NODE_STDOUT); }
    | '$*ERR' { $$ = PVIP_node_new_children(PVIP_NODE_STDERR); }
    | '@*ARGS' { $$ = PVIP_node_new_children(PVIP_NODE_CLARGS); }
    | '@*INC' { $$ = PVIP_node_new_children(PVIP_NODE_TW_INC); }
    | '$*VM' { $$ = PVIP_node_new_children(PVIP_NODE_TW_VM); }
    | '$?PACKAGE' { $$ = PVIP_node_new_children(PVIP_NODE_TW_PACKAGE); }
    | '$?CLASS' { $$ = PVIP_node_new_children(PVIP_NODE_TW_CLASS); }
    | '$?MODULE' { $$ = PVIP_node_new_children(PVIP_NODE_TW_MODULE); }
    | '$*OS' { $$ = PVIP_node_new_children(PVIP_NODE_TW_OS); }
    | '$?OS' { $$ = PVIP_node_new_children(PVIP_NODE_TW_OS); }
    | '$*PID' { $$ = PVIP_node_new_children(PVIP_NODE_TW_PID); }
    | '$*PERLVER' { $$ = PVIP_node_new_children(PVIP_NODE_TW_PERLVER); }
    | '$?PERLVER' { $$ = PVIP_node_new_children(PVIP_NODE_TW_PERLVER); }
    | '$*OSVER' { $$ = PVIP_node_new_children(PVIP_NODE_TW_OSVER); }
    | '$?OSVER' { $$ = PVIP_node_new_children(PVIP_NODE_TW_OSVER); }
    | '$*CWD' { $$ = PVIP_node_new_children(PVIP_NODE_TW_CWD); }
    | '$*EXECUTABLE_NAME' { $$ = PVIP_node_new_children(PVIP_NODE_TW_EXECUTABLE_NAME); }
    | '&?ROUTINE' { $$ = PVIP_node_new_children(PVIP_NODE_TW_ROUTINE); }
    | '%*ENV' { $$ = PVIP_node_new_children(PVIP_NODE_TW_ENV); }

reserved = ( 'my' | 'our' | 'while' | 'unless' | 'if' | 'role' | 'class' | 'try' | 'has' | 'sub' | 'cmp' | 'enum' | 'rand' | 'END' | 'BEGIN' | 'Z' ) ![-A-Za-z0-9]

role =
    'role' ws+ i:ident - b:block { $$ = PVIP_node_new_children2(PVIP_NODE_ROLE, i, b); }

# TODO optimizable
class =
    { i=NULL; is=NULL; } 'class'  (
        ws+ i:ident
    )? - is:is_does_list? - b:block {
        $$ = PVIP_node_new_children3(
            PVIP_NODE_CLASS,
            MAYBE(i),
            MAYBE(is),
            b
        );
    }

# XXX Bad Code
is_does_list =
    'is' ws+ a:ident { a=PVIP_node_new_children1(PVIP_NODE_LIST, PVIP_node_new_children1(PVIP_NODE_IS, a)); } (
        - 'is' ws+ b:ident { PVIP_node_push_child(a, PVIP_node_new_children1(PVIP_NODE_IS, b)); }
        | - 'does' ws+ b:ident { PVIP_node_push_child(a, PVIP_node_new_children1(PVIP_NODE_DOES, b)); }
    )* { $$=a; }
    | 'does' ws+ a:ident { a=PVIP_node_new_children1(PVIP_NODE_LIST, PVIP_node_new_children1(PVIP_NODE_DOES, a)); } (
        - 'is' ws+ b:ident { PVIP_node_push_child(a, PVIP_node_new_children1(PVIP_NODE_IS, b)); }
        | - 'does' ws+ b:ident { PVIP_node_push_child(a, PVIP_node_new_children1(PVIP_NODE_DOES, b)); }
    )* { $$=a; }

it_method = (
        '.' i:ident { $$ = PVIP_node_new_children1(PVIP_NODE_IT_METHODCALL, i); i=$$; }
        (
            a:paren_args { PVIP_node_push_child(i, a); }
        )?
    ) { $$=i; }

ident =
    < '::'? [A-Za-z] [-A-Za-z0-9_]* ( '::' [A-Za-z] [A-Za-z0-9_]* )* > { $$ = PVIP_node_new_string(PVIP_NODE_IDENT, yytext, yyleng); }
    | < [a-zA-Z] [a-zA-Z0-9]* ( [-_] [a-zA-Z0-9]+ )* > {
        $$ = PVIP_node_new_string(PVIP_NODE_IDENT, yytext, yyleng);
    }


hash = '{' -
    p1:pair { $$ = PVIP_node_new_children1(PVIP_NODE_HASH, p1); p1=$$; } ( -  ',' - p2:pair { PVIP_node_push_child(p1, p2); $$=p1; } )*
    ','?
    - '}' { $$=p1; }

pair = k:hash_key - '=>' - v:loose_unary_expr { $$ = PVIP_node_new_children2(PVIP_NODE_PAIR, k, v); }

hash_key =
    < [a-zA-Z0-9_]+ > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }
    | string

qw =
    '<<' - qw_list - '>>'
    | '<' - qw_list - '>'
    | '<' - '>' { $$ = PVIP_node_new_children(PVIP_NODE_LIST); }

qw_list =
        a:qw_item { $$ = PVIP_node_new_children1(PVIP_NODE_LIST, a); a = $$; }
        ( ws+ b:qw_item { PVIP_node_push_child(a, b); $$ = a; } )*
        { $$=a; }

# I want to use [^ ] but greg does not support it...
# https://github.com/nddrylliog/greg/issues/12
qw_item = < [^ >\n]+ > { $$ = PVIP_node_new_string(PVIP_NODE_STRING, yytext, yyleng); }

# TODO optimize
funcdef =
    'my' ws - f:funcdef { $$ = PVIP_node_new_children1(PVIP_NODE_MY, f); }
    | 'our' ws - f:funcdef { $$ = PVIP_node_new_children1(PVIP_NODE_OUR, f); }
    | 'sub' { p=NULL; e=NULL; } ws+ i:ident - '(' - p:params? - ')' - e:is_exportable? - b:block {
        if (!p) {
            p = PVIP_node_new_children(PVIP_NODE_PARAMS);
        }
        $$ = PVIP_node_new_children4(PVIP_NODE_FUNC, i, p, e ? e : NOP(), b);
    }
    | 'sub' ws+ i:ident - b:block {
        PVIPNode* pp = PVIP_node_new_children(PVIP_NODE_PARAMS);
        $$ = PVIP_node_new_children4(PVIP_NODE_FUNC, i, pp, NOP(), b);
    }

is_exportable = 'is' ws+ 'export' { $$ = PVIP_node_new_children(PVIP_NODE_EXPORT); }

lambda =
    {p=NULL; } '->' - ( !'{' p:params )? - b:block {
        if (!p) {
            p = PVIP_node_new_children(PVIP_NODE_PARAMS);
        }
        $$ = PVIP_node_new_children2(PVIP_NODE_LAMBDA, p, b);
    }
    | b:block { $$ = PVIP_node_new_children1(PVIP_NODE_LAMBDA, b); }
    | {p=NULL; } 'sub' ws+ (!'{' p:params)? - b:block {
        if (!p) {
            p = PVIP_node_new_children(PVIP_NODE_PARAMS);
        }
        $$ = PVIP_node_new_children4(PVIP_NODE_FUNC, PVIP_node_new_children(PVIP_NODE_NOP), p, NOP(), b);
    }

params =
    v:param { $$ = PVIP_node_new_children1(PVIP_NODE_PARAMS, v); v=$$; }
    ( - ',' - v1:param { PVIP_node_push_child(v, v1); $$=v; } )*
    { $$=v; }

# Str $x=""
param =
    '*' v:array_var {
        $$ = PVIP_node_new_children1(PVIP_NODE_PARAM, PVIP_node_new_children1(PVIP_NODE_VARGS, v));
    }
    | { i=NULL; d=NULL; }
    (
        ( i:ident ws+ )?
        v:term
        ( - d:param_defaults )?
    ) {
        $$ = PVIP_node_new_children3(PVIP_NODE_PARAM, MAYBE(i), v, MAYBE(d));
    }

param_defaults =
    '=' - e:expr { $$=e; }

block =
    {s=NULL; } ('{' - s:statementlist? - '}' !'.') {
        if (!s) {
            /* empty block */
            $$=PVIP_node_new_children(PVIP_NODE_BLOCK);
        } else if (s->children.nodes[0]->type == PVIP_NODE_PAIR) {
            PVIP_node_change_type(s, PVIP_NODE_HASH);
            $$=s;
        } else if (s->children.nodes[0]->type == PVIP_NODE_LIST && node_all_children_are(s->children.nodes[0], PVIP_NODE_PAIR)) {
            PVIP_node_change_type(s, PVIP_NODE_HASH);
            $$=s;
        } else {
            $$=PVIP_node_new_children1(PVIP_NODE_BLOCK, s);
        }
    }

# XXX optimizable
array =
    '[' - e:expr - ']' {
        if (PVIP_node_category(e->type) == PVIP_CATEGORY_CHILDREN && e->type == PVIP_NODE_LIST) {
            PVIP_node_change_type(e, PVIP_NODE_ARRAY);
            $$=e;
        } else {
            $$=PVIP_node_new_children1(PVIP_NODE_ARRAY, e);
        }
    }
    | '[' - ']' { $$ = PVIP_node_new_children(PVIP_NODE_ARRAY); }

my = 
    'my' ws+ v:variable { $$ = PVIP_node_new_children1(PVIP_NODE_MY, v); }
    | 'my' ws+ '(' - v:bare_variables - ')' { $$ = PVIP_node_new_children1(PVIP_NODE_MY, v); }
    | 'our' ws+ v:variable { $$ = PVIP_node_new_children1(PVIP_NODE_OUR, v); }

bare_variables =
    v1:variable { v1=PVIP_node_new_children1(PVIP_NODE_LIST, v1); } (
        - ',' - v2:variable { PVIP_node_push_child(v1, v2); }
    )* { $$=v1; }

variable = scalar | array_var | hash_var | twvars | funcref | attr_vars

array_var = < '@' varname > { $$ = PVIP_node_new_string(PVIP_NODE_VARIABLE, yytext, yyleng); }
    | '@' s:scalar { $$ = PVIP_node_new_children1(PVIP_NODE_ARRAY_DEREF, s); }

hash_var = < '%' !'%' varname > { $$ = PVIP_node_new_string(PVIP_NODE_VARIABLE, yytext, yyleng); }

scalar =
    '$' s:scalar { $$ = PVIP_node_new_children1(PVIP_NODE_SCALAR_DEREF, s); }
    | < '$' varname > { assert(yyleng > 0); $$ = PVIP_node_new_string(PVIP_NODE_VARIABLE, yytext, yyleng); }
    | '$!' ![a-zA-Z0-9_] { $$=PVIP_node_new_children(PVIP_NODE_SPECIAL_VARIABLE_EXCEPTIONS); }
    | '$/' { $$=PVIP_node_new_children(PVIP_NODE_SPECIAL_VARIABLE_REGEXP_MATCH); }

varname = [a-zA-Z_] ( [a-zA-Z0-9_]+ | '-' [a-zA-Z_] [a-zA-Z0-9_]* )*

#  <?MARKED('endstmt')>
#  <?terminator>
eat_terminator =
    (';' -) | end-of-file

dec_number =
    <[0-9]+ 'e' [0-9]+> {
    $$ = PVIP_node_new_number(PVIP_NODE_NUMBER, yytext, yyleng);
}
    | <([.][0-9]+)> {
    $$ = PVIP_node_new_number(PVIP_NODE_NUMBER, yytext, yyleng);
}
    | <([0-9]+ '.' [0-9]+)> {
    $$ = PVIP_node_new_number(PVIP_NODE_NUMBER, yytext, yyleng);
}
    | <([0-9_]+)> {
    $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 10);
}

complex = < [0-9]+ > 'i' { $$ = PVIP_node_new_intf(PVIP_NODE_COMPLEX, yytext, yyleng, 10); }

integer =
    '0b' <[01_]+> {
    $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 2);
}
    | '0d' <[0-9]+> {
    $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 10);
}
    | '0x' <[0-9a-f_]+> {
    $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 16);
}
    | '0o' <[0-7]+> {
    $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 8);
}
    | ':10<' <[0-9]+> '>' {
        $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 10);
    }
    | ':' i:integer_int '<' <[0-9a-fA-F]+> '>' {
        int base = i->iv;
        $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, base);
        PVIP_node_destroy(i);
    }

integer_int =
    <[0-9]+> { $$ = PVIP_node_new_intf(PVIP_NODE_INT, yytext, yyleng, 10); }

string = dq_string | sq_string

dq_string_start='"' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); }

dq_string = s:dq_string_start { s = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; s=PVIP_node_append_string(s, "\n", 1); }
        | "{" - e:statementlist - "}" { s=PVIP_node_append_string_node(s, e); }
        | "{" - "}" { s=PVIP_node_append_string(s, "", 0); }
        | < [^"{\\\n$]+ > { s=PVIP_node_append_string(s, yytext, yyleng); }
        | v:variable { s=PVIP_node_append_string_node(s, v); }
        | esc 'a' { s=PVIP_node_append_string(s, "\a", 1); }
        | esc 'b' { s=PVIP_node_append_string(s, "\b", 1); }
        | esc 't' { s=PVIP_node_append_string(s, "\t", 1); }
        | esc 'r' { s=PVIP_node_append_string(s, "\r", 1); }
        | esc 'n' { s=PVIP_node_append_string(s, "\n", 1); }
        | esc '"' { s=PVIP_node_append_string(s, "\"", 1); }
        | esc '$' { s=PVIP_node_append_string(s, "\"", 1); }
        | esc '0' { s=PVIP_node_append_string(s, "\0", 1); }
        | esc '{' { s=PVIP_node_append_string(s, "{", 1); /* } */ }
        | esc 'c[' < [^\]]+ > ']' { s=PVIP_node_append_string_node(s, PVIP_node_new_string(PVIP_NODE_UNICODE_CHAR, yytext, yyleng)); }
        # \c10
        | esc 'c' < [0-9] [0-9] > { s=PVIP_node_append_string_from_dec(s, yytext, yyleng); }
        | ( esc 'x' (
                  '0'? < ( [a-fA-F0-9] [a-fA-F0-9] ) >
            | '[' '0'? < ( [a-fA-F0-9] [a-fA-F0-9] ) > ']' )
        ) {
            s=PVIP_node_append_string_from_hex(s, yytext, yyleng);
        }
        | esc 'o' < '0'? [0-7] [0-7] > {
            s=PVIP_node_append_string_from_oct(s, yytext, yyleng);
        }
        | esc 'o['
             '0'? < [0-7] [0-7] > { s=PVIP_node_append_string_from_oct(s, yytext, yyleng); } (
            ',' '0'? < [0-7] [0-7] > { s=PVIP_node_append_string_from_oct(s, yytext, yyleng); }
        )* ']'
        | esc esc { s=PVIP_node_append_string(s, "\\", 1); }
    )* '"' { $$=s; }

perl5_regexp_start = 'm:P5/' { $$ = PVIP_node_new_string(PVIP_NODE_PERL5_REGEXP, "", 0); }

perl5_regexp =
    r:perl5_regexp_start (
        <[^/]+> { r=PVIP_node_append_string(r, yytext, yyleng); }
       | esc '/' { r=PVIP_node_append_string(r, "/", 1); }
    )+ '/' { $$=r; }

regexp_start = ( 'm/' | '/' ) { $$ = PVIP_node_new_string(PVIP_NODE_REGEXP, "", 0); }

regexp =
    r:regexp_start (
        <[^/]+> { r=PVIP_node_append_string(r, yytext, yyleng); }
       | esc '/' { r=PVIP_node_append_string(r, "/", 1); }
    )+ '/' { $$=r; }


esc = '\\'

sq_string = "'" { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^'\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* "'"
    | 'q/' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^/\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc "/" { $$=PVIP_node_append_string($$, "/", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* '/'
    | 'q!' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^!\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc "/" { $$=PVIP_node_append_string($$, "/", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* '!'
    | 'q|' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^|\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc "/" { $$=PVIP_node_append_string($$, "/", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* '|'
    | 'q{' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^}\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc "/" { $$=PVIP_node_append_string($$, "/", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* '}'
    | 'q[' { $$ = PVIP_node_new_string(PVIP_NODE_STRING, "", 0); } (
        "\n" { G->data.line_number++; $$=PVIP_node_append_string($$, "\n", 1); }
        | < [^\]\\\n]+ > { $$=PVIP_node_append_string($$, yytext, yyleng); }
        | esc "'" { $$=PVIP_node_append_string($$, "'", 1); }
        | esc "]" { $$=PVIP_node_append_string($$, "/", 1); }
        | esc esc { $$=PVIP_node_append_string($$, "\\", 1); }
        | < esc . > { $$=PVIP_node_append_string($$, yytext, yyleng); }
    )* ']'

comment =
    '#`[' [^\]]* ']'
    | '#`(' [^)]* ')'
    | '#`（' [^）]* '）'
    | '#`『' [^』]* '』'
    | '#`《' [^》]* '》'
    | '#' [^\n]* end-of-line

# white space
ws = 
    '\n=begin ' [a-z]+ '\n' ( !'=end ' [^\n]* '\n')* '=end ' [a-z]+ '\n'
    | '\n=begin END\n' .* | ' ' | '\f' | '\v' | '\t' | '\205' | '\240'
    | '\n=END\n' .*
    | end-of-line
    | comment

- = ws*

end-of-line = ( '\r\n' | '\n' | '\r' ) {
    G->data.line_number++;
}
end-of-file = !'\0'

%%

PVIPNode * PVIP_parse_string(const char *string, int len, int debug, PVIPString **error) {
    PVIPNode *root = NULL;

    GREG g;
    YY_NAME(init)(&g);

#ifdef YY_DEBUG
    g.debug=debug;
#endif

    g.data.line_number = 1;
    g.data.is_string   = 1;
    g.data.str = malloc(sizeof(PVIPParserStringState));
    g.data.str->buf     = string;
    g.data.str->len     = len;
    g.data.str->pos     = 0;

    if (!YY_NAME(parse)(&g)) {
      if (error) {
        *error = PVIP_string_new();
        PVIP_string_concat(*error, "** Syntax error at line ", strlen("** Syntax error at line "));
        PVIP_string_concat_int(*error, g.data.line_number);
        PVIP_string_concat(*error, "\n", 1);
        if (g.text[0]) {
            PVIP_string_concat(*error, "** near ", strlen("** near "));
            PVIP_string_concat(*error, g.text, strlen(g.text));
        }
        if (g.pos < g.limit || g.data.str->len==g.data.str->pos) {
            g.buf[g.limit]= '\0';
            PVIP_string_concat(*error, " before text \"", strlen(" before text \""));
            while (g.pos < g.limit) {
                if ('\n' == g.buf[g.pos] || '\r' == g.buf[g.pos]) break;
                PVIP_string_concat_char(*error, g.buf[g.pos++]);
            }
            if (g.pos == g.limit) {
                while (g.data.str->len!=g.data.str->pos) {
                    char ch = g.data.str->buf[g.data.str->pos++];
                    if (!ch || '\n' == ch || '\r' == ch) {
                        break;
                    }
                    PVIP_string_concat_char(*error, ch);
                }
            }
            PVIP_string_concat_char(*error, '\"');
        }
        PVIP_string_concat(*error, "\n\n", 2);
        free(g.data.str);
      }
      goto finished;
    }
    if (g.limit!=g.pos) {
        if (error) {
            *error = PVIP_string_new();
            PVIP_string_concat(*error, "Syntax error! Around:\n", strlen("Syntax error! Around:\n"));
            int i;
            for (i=0; g.limit!=g.pos && i<24; i++) {
                char ch = g.data.str->buf[g.pos++];
                if (ch) {
                    PVIP_string_concat_char(*error, ch);
                }
            }
            PVIP_string_concat_char(*error, '\n');
        }
        goto finished;
    }
    root = g.data.root;

finished:

    free(g.data.str);
    assert(g.data.root);
    YY_NAME(deinit)(&g);
    return root;
}

/*
XXX Output error message to stderr is ugly.
XXX We need to add APIs for getting error message.
 */
PVIPNode * PVIP_parse_fp(FILE *fp, int debug, PVIPString **error) {
    GREG g;
    YY_NAME(init)(&g);

#ifdef YY_DEBUG
    g.debug=debug;
#endif

    g.data.line_number = 1;
    g.data.is_string   = 0;
    g.data.fp = fp;

    if (!YY_NAME(parse)(&g)) {
      if (error) {
        *error = PVIP_string_new();
        PVIP_string_concat(*error, "** Syntax error at line ", strlen("** Syntax error at line "));
        PVIP_string_concat_int(*error, g.data.line_number);
        PVIP_string_concat(*error, "\n", 1);
        if (g.text[0]) {
          PVIP_string_concat(*error, "** near ", strlen("** near "));
          PVIP_string_concat(*error, g.text, strlen(g.text));
        }
        if (g.pos < g.limit || !feof(fp)) {
          g.buf[g.limit]= '\0';
          PVIP_string_concat(*error, " before text \"", strlen(" before text \""));
          while (g.pos < g.limit) {
            if ('\n' == g.buf[g.pos] || '\r' == g.buf[g.pos]) break;
            PVIP_string_concat_char(*error, g.buf[g.pos++]);
          }
          if (g.pos == g.limit) {
            int c;
            while (EOF != (c= fgetc(fp)) && '\n' != c && '\r' != c)
            PVIP_string_concat_char(*error, c);
          }
          PVIP_string_concat_char(*error, '\"');
        }
        PVIP_string_concat(*error, "\n\n", 2);
      }
      return NULL;
    }
    if (!feof(fp)) {
      if (error) {
        *error = PVIP_string_new();
        PVIP_string_concat(*error, "Syntax error! At line ", strlen("Syntax error! At line "));
        PVIP_string_concat_int(*error, g.data.line_number);
        PVIP_string_concat(*error, ":\n", strlen(":\n"));
        int i;
        for (i=0; !feof(fp) && i<24; i++) {
          char ch = fgetc(fp);
          if (ch != EOF) {
            PVIP_string_concat_char(*error, ch);
          }
        }
        PVIP_string_concat_char(*error, '\n');
      }
      return NULL;
    }
    free(g.data.str);
    PVIPNode *root = g.data.root;
    assert(g.data.root);
    YY_NAME(deinit)(&g);
    return root;
}
