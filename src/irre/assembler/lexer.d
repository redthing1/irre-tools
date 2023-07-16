module irre.assembler.lexer;

import std.stdio;
import std.array : Appender;
import std.conv;

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

class Lexer {
    string source;
    int pos;
    int line;
    int line_start;
    Appender!(char[]) working;

    public struct Result {
        Appender!(Token[]) tokens;
    }

    public Result lex(string program) {
        source = program;
        line = 1;

        auto res = Result();

        // lexer loop
        while (pos < source.length) {
            skip_chars(CharType.SPACE); // skip any leading whitespace
            while (peek_char() == ';') { // comments
                skip_until('\n'); // ignore the rest of the line
                skip_chars(CharType.SPACE); // skip any remaining space
            }
            if (pos >= source.length) {
                break;
            }
            // process character
            auto c = peek_char();
            working.clear();

            immutable auto c_type = classify_char(c);
            if ((c_type & CharType.ALPHA) > 0) { // start of identifier
                res.tokens ~= read_token_of(CharType.IDENTIFIER);
                // buf_push_Token(&tokens, make_token_of(working, CharType.IDENTIFIER));
            } else if ((c_type & CharType.NUMERIC) > 0) { // start of num literal
                res.tokens ~= read_token_of(CharType.NUMERIC);
            } else if ((c_type & CharType.ARGSEP) > 0) {
                res.tokens ~= read_token_of(CharType.ARGSEP);
            } else if ((c_type & CharType.MARK) > 0) {
                res.tokens ~= read_token_of(CharType.MARK);
            } else if ((c_type & CharType.QUOT) > 0) {
                res.tokens ~= read_token_of(CharType.QUOT);
            } else if ((c_type & CharType.BIND) > 0) {
                res.tokens ~= read_token_of(CharType.BIND);
            } else if ((c_type & CharType.OFFSET) > 0) {
                res.tokens ~= read_token_of(CharType.OFFSET);
            } else if ((c_type & CharType.NUM_SPECIAL) > 0) {
                res.tokens ~= read_token_of(CharType.NUMERIC_CONSTANT);
            } else if ((c_type & CharType.PACK_START) > 0) {
                // start of a pack, read in pack context
                res.tokens ~= read_token_of(CharType.PACK_START); // add the packstart
                // get the escape
                working.clear();
                immutable auto pack_type = peek_chartype();
                if (pack_type == CharType.QUOT) { // \'
                    // buf_push_Token(&tokens, make_token_of(working, QUOT));
                } else if (pack_type == CharType.ALPHA) { // \x
                    // buf_push_Token(&tokens, make_token_of(working, ALPHA));
                }
            } else if ((c_type & CharType.DIRECTIVE_PREFIX) > 0) {
                // buf_push_Token(&tokens, make_token_of(working, DIRECTIVE));
            } else {
                stderr.writefln("unrecognized character: %c, [%d:%d]\n", c,
                        line, cast(int)(pos - line_start) + 1);
                take_char(); // eat the character
            }
        }

        return res;
    }

    CharType classify_char(char c) {
        switch (c) {
        case ',':
            return CharType.ARGSEP;
        case ':':
            return CharType.MARK;
        case '\'':
            return CharType.QUOT;
        case '@':
            return CharType.BIND;
        case '^':
            return CharType.OFFSET;
        case '#':
            return CharType.DIRECTIVE_PREFIX;
        case '\\':
            return CharType.PACK_START;
        case '$':
        case '.':
            return CharType.NUM_SPECIAL;
        case ' ':
        case '\t':
        case '\r':
        case '\n':
            return CharType.SPACE;
        default:
            break;
        }
        // now categories
        auto type = CharType.UNKNOWN;
        if ((c >= 'a' && c <= 'f')) {
            type |= CharType.NUMERIC_HEX;
        }
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_')) {
            type |= CharType.ALPHA;
        } else if (c >= '0' && c <= '9') {
            type |= CharType.NUMERIC;
        }

        return type;
    }

    char peek_char() {
        return source[pos];
    }

    CharType peek_chartype() {
        return classify_char(peek_char());
    }

    char take_char() {
        char c = peek_char();
        if (c == '\n') {
            line++;
            line_start = pos + 1;
        }
        pos++;
        return c;
    }

    void take_chars(CharType readType) {
        while (pos < source.length && ((cast(int) peek_chartype() & cast(int) readType) > 0)) {
            immutable auto c = take_char();
            working ~= c;
        }
    }

    void take_chars_until(CharType stopType) {
        while (pos < source.length && ((cast(int) peek_chartype() & cast(int) stopType) == 0)) {
            immutable auto c = take_char();
            working ~= c;
        }
    }

    void skip_chars(CharType skip) {
        while (pos < source.length && (cast(int) peek_chartype() & cast(int) skip) > 0) {
            take_char();
        }
    }

    void skip_until(char until) {
        while (pos < source.length && peek_char() != until) {
            take_char();
        }
    }

    Token read_token_of(CharType type) {
        take_chars(type);
        return Token(to!string(working[]), type);
    }
}
