module irre.assembler.lexer;

enum CharType {
    UNKNOWN = 0,
    ALPHA = 1 << 0, // abc
    NUMERIC = 1 << 1, // 123
    SPACE = 1 << 2, // ' '
    ARGSEP = 1 << 3, // ','
    NUM_SPECIAL = 1 << 4, // '$'
    MARK = 1 << 5, // ':'
    QUOT = 1 << 6, // '''
    BIND = 1 << 7, // '@'
    OFFSET = 1 << 8, // '^'
    DIRECTIVE_PREFIX = 1 << 9, // '#'
    NUMERIC_HEX = 1 << 10, // beef
    PACK_START = 1 << 11, // '\'
    IDENTIFIER = ALPHA | NUMERIC,
    DIRECTIVE = DIRECTIVE_PREFIX | ALPHA,
    NUMERIC_CONSTANT = NUMERIC | NUMERIC_HEX | NUM_SPECIAL,
}

struct Token {
    string content;
    CharType kind;
}

struct LexResult {
    Token[] tokens;
}

class Lexer {
    public LexResult lex(string program) {
        auto tokens = new Token[0];

        // TODO: lexing logic

        return LexResult(tokens);
    }
}
