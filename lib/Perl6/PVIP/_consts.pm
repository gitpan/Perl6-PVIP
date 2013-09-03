package Perl6::PVIP::_consts;
use warnings;
use strict;

@Perl6::PVIP::EXPORT = qw(
    PVIP_NODE_UNDEF
    PVIP_NODE_RANGE
    PVIP_NODE_REDUCE
    PVIP_NODE_INT
    PVIP_NODE_NUMBER
    PVIP_NODE_STATEMENTS
    PVIP_NODE_DIV
    PVIP_NODE_MUL
    PVIP_NODE_ADD
    PVIP_NODE_SUB
    PVIP_NODE_IDENT
    PVIP_NODE_FUNCALL
    PVIP_NODE_ARGS
    PVIP_NODE_STRING
    PVIP_NODE_MOD
    PVIP_NODE_VARIABLE
    PVIP_NODE_MY
    PVIP_NODE_OUR
    PVIP_NODE_BIND
    PVIP_NODE_STRING_CONCAT
    PVIP_NODE_IF
    PVIP_NODE_EQV
    PVIP_NODE_EQ
    PVIP_NODE_NE
    PVIP_NODE_LT
    PVIP_NODE_LE
    PVIP_NODE_GT
    PVIP_NODE_GE
    PVIP_NODE_ARRAY
    PVIP_NODE_ATPOS
    PVIP_NODE_METHODCALL
    PVIP_NODE_FUNC
    PVIP_NODE_PARAMS
    PVIP_NODE_RETURN
    PVIP_NODE_ELSE
    PVIP_NODE_WHILE
    PVIP_NODE_DIE
    PVIP_NODE_ELSIF
    PVIP_NODE_LIST
    PVIP_NODE_FOR
    PVIP_NODE_UNLESS
    PVIP_NODE_NOT
    PVIP_NODE_CONDITIONAL
    PVIP_NODE_NOP
    PVIP_NODE_STREQ
    PVIP_NODE_STRNE
    PVIP_NODE_STRGT
    PVIP_NODE_STRGE
    PVIP_NODE_STRLT
    PVIP_NODE_STRLE
    PVIP_NODE_POW
    PVIP_NODE_CLARGS
    PVIP_NODE_HASH
    PVIP_NODE_PAIR
    PVIP_NODE_ATKEY
    PVIP_NODE_LOGICAL_AND
    PVIP_NODE_LOGICAL_OR
    PVIP_NODE_LOGICAL_XOR
    PVIP_NODE_BIN_AND
    PVIP_NODE_BIN_OR
    PVIP_NODE_BIN_XOR
    PVIP_NODE_BLOCK
    PVIP_NODE_LAMBDA
    PVIP_NODE_USE
    PVIP_NODE_MODULE
    PVIP_NODE_CLASS
    PVIP_NODE_METHOD
    PVIP_NODE_UNARY_PLUS
    PVIP_NODE_UNARY_MINUS
    PVIP_NODE_IT_METHODCALL
    PVIP_NODE_LAST
    PVIP_NODE_NEXT
    PVIP_NODE_REDO
    PVIP_NODE_POSTINC
    PVIP_NODE_POSTDEC
    PVIP_NODE_PREINC
    PVIP_NODE_PREDEC
    PVIP_NODE_UNARY_BITWISE_NEGATION
    PVIP_NODE_BRSHIFT
    PVIP_NODE_BLSHIFT
    PVIP_NODE_CHAIN
    PVIP_NODE_INPLACE_ADD
    PVIP_NODE_INPLACE_SUB
    PVIP_NODE_INPLACE_MUL
    PVIP_NODE_INPLACE_DIV
    PVIP_NODE_INPLACE_POW
    PVIP_NODE_INPLACE_MOD
    PVIP_NODE_INPLACE_BIN_OR
    PVIP_NODE_INPLACE_BIN_AND
    PVIP_NODE_INPLACE_BIN_XOR
    PVIP_NODE_INPLACE_BLSHIFT
    PVIP_NODE_INPLACE_BRSHIFT
    PVIP_NODE_INPLACE_CONCAT_S
    PVIP_NODE_REPEAT_S
    PVIP_NODE_INPLACE_REPEAT_S
    PVIP_NODE_STRINGIFY
    PVIP_NODE_TRY
    PVIP_NODE_REF
    PVIP_NODE_MULTI
    PVIP_NODE_UNARY_BOOLEAN
    PVIP_NODE_UNARY_UPTO
    PVIP_NODE_STDOUT
    PVIP_NODE_STDERR
    PVIP_NODE_SCALAR_DEREF
    PVIP_NODE_TW_INC
    PVIP_NODE_META_METHOD_CALL
    PVIP_NODE_REGEXP
    PVIP_NODE_SMART_MATCH
    PVIP_NODE_NOT_SMART_MATCH
    PVIP_NODE_PERL5_REGEXP
    PVIP_NODE_TRUE
    PVIP_NODE_FALSE
    PVIP_NODE_TW_VM
    PVIP_NODE_HAS
    PVIP_NODE_ATTRIBUTE_VARIABLE
    PVIP_NODE_FUNCREF
    PVIP_NODE_PATH
    PVIP_NODE_TW_PACKAGE
    PVIP_NODE_TW_CLASS
    PVIP_NODE_TW_MODULE
    PVIP_NODE_TW_OS
    PVIP_NODE_TW_PID
    PVIP_NODE_TW_PERLVER
    PVIP_NODE_TW_OSVER
    PVIP_NODE_TW_CWD
    PVIP_NODE_TW_EXECUTABLE_NAME
    PVIP_NODE_TW_ROUTINE
    PVIP_NODE_SLANGS
    PVIP_NODE_LOGICAL_ANDTHEN
    PVIP_NODE_VALUE_IDENTITY
    PVIP_NODE_CMP
    PVIP_NODE_SPECIAL_VARIABLE_REGEXP_MATCH
    PVIP_NODE_SPECIAL_VARIABLE_EXCEPTIONS
    PVIP_NODE_ENUM
    PVIP_NODE_NUM_CMP
    PVIP_NODE_UNARY_FLATTEN_OBJECT
    PVIP_NODE_COMPLEX
    PVIP_NODE_ROLE
    PVIP_NODE_IS
    PVIP_NODE_DOES
    PVIP_NODE_JUNCTIVE_AND
    PVIP_NODE_JUNCTIVE_SAND
    PVIP_NODE_JUNCTIVE_OR
    PVIP_NODE_UNICODE_CHAR
    PVIP_NODE_STUB
    PVIP_NODE_EXPORT
    PVIP_NODE_PARAM
    PVIP_NODE_BITWISE_OR
    PVIP_NODE_BITWISE_AND
    PVIP_NODE_BITWISE_XOR
    PVIP_NODE_VARGS
    PVIP_NODE_WHATEVER
    PVIP_NODE_TW_ENV
    PVIP_NODE_ARRAY_DEREF
    PVIP_NODE_RAND
    PVIP_NODE_END
    PVIP_NODE_BEGIN
    PVIP_NODE_IS_DIVISIBLE_BY
    PVIP_NODE_NOT_DIVISIBLE_BY
    PVIP_NODE_CONTAINER_IDENTITY
    PVIP_NODE_Z
    PVIP_NODE_SUBMETHOD
    PVIP_NODE_BINDAND_MAKE_READONLY
    PVIP_NODE_LIST_ASSIGNMENT
    PVIP_NODE_TW_A
    PVIP_NODE_TW_B
    PVIP_NODE_TW_C
    PVIP_NODE_SO
    PVIP_NODE_GCD
    PVIP_NODE_KEEP
    PVIP_NODE_UNDO
    PVIP_NODE_NOW
    PVIP_NODE_UNTIL
    PVIP_NODE_TIME
    PVIP_NODE_AUGMENT
    PVIP_NODE_IS_COPY
    PVIP_NODE_LEG
    PVIP_NODE_NEED
    PVIP_NODE_INTEGER_DIVISION
    PVIP_NODE_LCM
    PVIP_NODE_PACKAGE
    PVIP_NODE_MINMAX
    PVIP_NODE_SEQUENCE
    PVIP_NODE_CONTEXTUALIZER_SCALAR
    PVIP_NODE_CONTEXTUALIZER_ARRAY
    PVIP_NODE_CONTEXTUALIZER_HASH
    PVIP_NODE_TW_TMPDIR
    PVIP_NODE_IS_RW
    PVIP_NODE_IS_REF
    PVIP_NODE_PI
    PVIP_NODE_E
    PVIP_CATEGORY_UNKNOWN
    PVIP_CATEGORY_STRING
    PVIP_CATEGORY_INT
    PVIP_CATEGORY_NUMBER
    PVIP_CATEGORY_CHILDREN
);

1;
