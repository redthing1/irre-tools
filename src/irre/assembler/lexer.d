module irre.assembler.lexer;

import std.stdio;
import std.string;
import std.array;
import std.conv;

/**
represents the type of character (for tokens) 
*/
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

/**
represents a token
*/
struct Token {
    string content;
    CharType kind;

    /** just an informative line position indicator useful for giving more useful errors. */
    int line;
}

class LexerException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

/**
provides logic to lex a source file
*/
class Lexer {
    private string source;
    private int pos;
    private int line;
    private int line_start;
    private Appender!(char[]) working;

    /**
    represents a lexed source file
    */
    public struct Result {
        /**
        the tokens
        */
        Token[] tokens;
    }

    /**
    populate a Lex.Result with tokens read from the text of an input program
    */
    public Result lex(string program) {
        source = program;
        line = 1;

        auto tokens = appender!(Token[]);

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
                tokens ~= read_token_of(CharType.IDENTIFIER);
            } else if ((c_type & CharType.NUMERIC) > 0) { // start of num literal
                tokens ~= read_token_of(CharType.NUMERIC);
            } else if ((c_type & CharType.ARGSEP) > 0) {
                tokens ~= read_token_of(CharType.ARGSEP);
            } else if ((c_type & CharType.MARK) > 0) {
                tokens ~= read_token_of(CharType.MARK);
            } else if ((c_type & CharType.QUOT) > 0) {
                tokens ~= read_token_of(CharType.QUOT);
            } else if ((c_type & CharType.BIND) > 0) {
                tokens ~= read_token_of(CharType.BIND);
            } else if ((c_type & CharType.OFFSET) > 0) {
                tokens ~= read_token_of(CharType.OFFSET);
            } else if ((c_type & CharType.NUM_SPECIAL) > 0) {
                tokens ~= read_token_of(CharType.NUMERIC_CONSTANT);
            } else if ((c_type & CharType.PACK_START) > 0) {
                // start of a pack, read in pack context
                tokens ~= read_token_of(CharType.PACK_START); // add the packstart
                // get the escape
                working.clear();
                immutable auto pack_type = peek_chartype();
                if (pack_type == CharType.QUOT) { // \'
                    tokens ~= read_token_of(CharType.QUOT);
                } else if (pack_type == CharType.ALPHA) { // \x
                    tokens ~= read_token_of(CharType.ALPHA);
                }
            } else if ((c_type & CharType.DIRECTIVE_PREFIX) > 0) {
                tokens ~= read_token_of(CharType.DIRECTIVE);
            } else {
                take_char(); // eat the character
                auto message = format("unrecognized character: %c, [%d:%d]", c, line,
                        cast(int)(pos - line_start) + 1);
                throw new LexerException(message);
            }
        }

        auto res = Result(tokens.data);
        return res;
    }

    private CharType classify_char(char c) {
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

    private char peek_char() {
        if (pos >= source.length) {
            return '\n'; // empty
        }
        return source[pos];
    }

    private CharType peek_chartype() {
        return classify_char(peek_char());
    }

    private char take_char() {
        char c = peek_char();
        if (c == '\n') {
            line++;
            line_start = pos + 1;
        }
        pos++;
        return c;
    }

    private void take_chars(CharType readType) {
        while (pos < source.length && ((cast(int) peek_chartype() & cast(int) readType) > 0)) {
            immutable auto c = take_char();
            working ~= c;
        }
    }

    private void take_chars_until(CharType stopType) {
        while (pos < source.length && ((cast(int) peek_chartype() & cast(int) stopType) == 0)) {
            immutable auto c = take_char();
            working ~= c;
        }
    }

    private void skip_chars(CharType skip) {
        while (pos < source.length && (cast(int) peek_chartype() & cast(int) skip) > 0) {
            take_char();
        }
    }

    private void skip_until(char until) {
        while (pos < source.length && peek_char() != until) {
            take_char();
        }
    }

    private Token read_token_of(CharType type) {
        take_chars(type);
        return Token(to!string(working[]), type, line);
    }
}
