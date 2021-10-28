package parser
import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Token_Type :: enum{
    Token_Identifier,
    Token_Paren,
    Token_OpenParen,
    Token_CloseParen,
    Token_Asterisk,
    Token_OpenBrace,
    Token_CloseBrace,
    Token_String,
    Token_SemiColon,
    Token_Colon,
    Token_Period,
    Token_Dash,
    Token_Underscore,
    Token_Comma,
    Token_EndOfStream,
    Token_Comment,
    Token_ReturnCarriage,
    Token_NewLine,
	Token_ForwardSlash,
	Token_BackwardSlash,
    Token_Unknown,   
}

Token :: struct{
	type : Token_Type,
	data : string,
	rune_index : u64,

}

Tokenizer :: struct{
	data : string,
	token : Token,
	at : ^rune,
}

init :: proc(s : string) -> Tokenizer{
	result : Tokenizer
	result.data = s
	//result.at = s[0:]
	return result
}

advance_token :: proc(t : ^Tokenizer){
	
}

eat_all_white_space :: proc(t : ^Tokenizer){
	for unicode.is_white_space(t.at^){
		advance_token(t)
	}
}