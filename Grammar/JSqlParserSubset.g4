grammar JSqlParserSubset;

parse
    : statement EOF
    ;

statement
    : selectStatement
    ;

selectStatement
    : SELECT selectItem (COMMA selectItem)* FROM identifier
    ;

selectItem
    : STAR
    | identifier
    ;

identifier
    : IDENTIFIER
    ;

SELECT: [sS] [eE] [lL] [eE] [cC] [tT];
FROM: [fF] [rR] [oO] [mM];
STAR: '*';
COMMA: ',';
IDENTIFIER: [a-zA-Z_] [a-zA-Z0-9_]*;
WS: [ \t\r\n]+ -> skip;
