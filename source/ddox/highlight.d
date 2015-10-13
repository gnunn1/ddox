/**
	D syntax highlighting.

	Copyright: © 2015 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module ddox.highlight;

import std.algorithm : any;
import std.array : Appender, appender, replace;
import std.range;
import std.string : strip;
import std.uni : isLower, isUpper;


/**
	Takes a piece of D code and outputs a sequence of HTML elements useful for syntax highlighting.

	The output will contain $(LT)span$(GT) elements with the class attribute
	set to the kind of entity that it contains. The class names are kept
	compatible with the ones used for Google's prettify library: "typ", "kwd",
	"com", "str", "lit", "pun", "pln", "spc"

	The only addition is "spc", which denotes a special token sequence starting
	with a "#", such as "#line" or "#!/bin/sh".

	Note that this function will only perform actual syntax highlighting if
	the libdparse package is available as a DUB dependency.

	---
	void main(string[] args)
	{
		#line 2
		import std.stdio; // yeah
		writefln("Hello, "~"World!");
		Package pack;
		ddox.entities.Module mod;
	}
	---

	Params:
		dst = Output range where to write the HTML output
		code = The D source code to process
		ident_render = Optional delegate to customize how (qualified)
			identifiers are rendered
*/
void highlightDCode(R)(ref R dst, string code, scope IdentifierRenderCallback ident_render = null)
	if (isOutputRange!(R, char))
{
	version (Have_libdparse) {
		import std.d.lexer : DLexer, LexerConfig, StringBehavior, StringCache, WhitespaceBehavior,
			isBasicType, isKeyword, isStringLiteral, isNumberLiteral,
			isOperator, str, tok;
		import std.algorithm : endsWith;

		StringCache cache = StringCache(1024 * 4);

		LexerConfig config;
		config.stringBehavior = StringBehavior.source;
		config.whitespaceBehavior = WhitespaceBehavior.include;

		string last_class;
		void writeWithClass(string text, string cls)
		{
			import std.format : formattedWrite;
			if (last_class != cls) {
				if (last_class.length) dst.put("</span>");
				dst.formattedWrite("<span class=\"%s\">", cls);
				last_class = cls;
			}

			dst.put(text.replace("<", "&lt"));
		}


		auto symbol = appender!string;

		foreach (t; DLexer(cast(ubyte[])code, config, &cache)) {
			if (ident_render) {
				if (t.type == tok!"." && !symbol.data.endsWith(".")) {
					symbol ~= ".";
					continue;
				} else if (t.type == tok!"identifier" && (symbol.data.empty || symbol.data.endsWith("."))) {
					symbol ~= t.text;
					continue;
				} else if (symbol.data.length) {
					ident_render(symbol.data, { highlightDCode(dst, symbol.data); });
					symbol = appender!string();
				}
			}

			if (t.type == tok!".") dst.put("<wbr/>");

			if (isBasicType(t.type)) writeWithClass(str(t.type), "typ");
			else if (isKeyword(t.type)) writeWithClass(str(t.type), "kwd");
			else if (t.type == tok!"comment") writeWithClass(t.text, "com");
			else if (isStringLiteral(t.type) || t.type == tok!"characterLiteral") writeWithClass(t.text, "str");
			else if (isNumberLiteral(t.type)) writeWithClass(t.text, "lit");
			else if (isOperator(t.type)) writeWithClass(str(t.type), "pun");
			else if (t.type == tok!"specialTokenSequence" || t.type == tok!"scriptLine") writeWithClass(t.text, "spc");
			else if (t.text.strip == "string") writeWithClass(t.text, "typ");
			else if (t.type == tok!"identifier" && t.text.isCamelCase) writeWithClass(t.text, "typ");
			else if (t.type == tok!"identifier" || t.type == tok!"whitespace") writeWithClass(t.text, "pln");
			else writeWithClass(t.text, "pun");
		}

		if (last_class.length) dst.put("</span>");
	} else {
		dst.put(code.replace("<", "&lt"));
	}
}

/// ditto
string highlightDCode(string str, IdentifierRenderCallback ident_render = null)
{
	auto dst = appender!string();
	dst.highlightDCode(str, ident_render);
	return dst.data;
}

alias IdentifierRenderCallback = void delegate(string ident, scope void delegate() insert_ident);

private bool isCamelCase(string text)
{
	text = text.strip();
	if (text.length < 2) return false;
	if (!text[0].isUpper) return false;
	if (!text.any!(ch => ch.isLower)) return false;
	return true;
}
