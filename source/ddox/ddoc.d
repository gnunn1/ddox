﻿/**
	DietDoc/DDOC support routines

	Copyright: © 2012-2015 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module ddox.ddoc;

import vibe.core.log;
import vibe.utils.string;

import std.algorithm : canFind, countUntil, map, min, remove;
import std.array;
import std.conv;
import std.string;
import std.uni : isAlpha;

// TODO: support escapes section


shared static this()
{
	s_standardMacros =
		[
		 `B`: `<b>$0</b>`,
		 `I`: `<i>$0</i>`,
		 `U`: `<u>$0</u>`,
		 `P` : `<p>$0</p>`,
		 `DL` : `<dl>$0</dl>`,
		 `DT` : `<dt>$0</dt>`,
		 `DD` : `<dd>$0</dd>`,
		 `TABLE` : `<table>$0</table>`,
		 `TR` : `<tr>$0</tr>`,
		 `TH` : `<th>$0</th>`,
		 `TD` : `<td>$0</td>`,
		 `OL` : `<ol>$0</ol>`,
		 `UL` : `<ul>$0</ul>`,
		 `LI` : `<li>$0</li>`,
		 `LINK` : `<a href="$0">$0</a>`,
		 `LINK2` : `<a href="$1">$+</a>`,
		 `LPAREN` : `(`,
		 `RPAREN` : `)`,

		 `RED` :   `<font color=red>$0</font>`,
		 `BLUE` :  `<font color=blue>$0</font>`,
		 `GREEN` : `<font color=green>$0</font>`,
		 `YELLOW` : `<font color=yellow>$0</font>`,
		 `BLACK` : `<font color=black>$0</font>`,
		 `WHITE` : `<font color=white>$0</font>`,

		 `D_CODE` : `<pre class="d_code">$0</pre>`,
		 `D_COMMENT` : `$(GREEN $0)`,
		 `D_STRING`  : `$(RED $0)`,
		 `D_KEYWORD` : `$(BLUE $0)`,
		 `D_PSYMBOL` : `$(U $0)`,
		 `D_PARAM` : `$(I $0)`,
		 `BACKTICK`: "`",
		 `DDOC_BACKQUOTED`: `$(D_INLINECODE $0)`,
		 //`D_INLINECODE`: `<pre style="display:inline;" class="d_inline_code">$0</pre>`,
		 `D_INLINECODE`: `<code class="prettyprint lang-d">$0</code>`,

		 `DDOC` : `<html>
  <head>
    <META http-equiv="content-type" content="text/html; charset=utf-8">
    <title>$(TITLE)</title>
  </head>
  <body>
  <h1>$(TITLE)</h1>
  $(BODY)
  </body>
</html>`,

		 `DDOC_COMMENT` : `<!-- $0 -->`,
		 `DDOC_DECL` : `$(DT $(BIG $0))`,
		 `DDOC_DECL_DD` : `$(DD $0)`,
		 `DDOC_DITTO` : `$(BR)$0`,
		 `DDOC_SECTIONS` : `$0`,
		 `DDOC_SUMMARY` : `$0$(BR)$(BR)`,
		 `DDOC_DESCRIPTION` : `$0$(BR)$(BR)`,
		 `DDOC_AUTHORS` : "$(B Authors:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_BUGS` : "$(RED BUGS:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_COPYRIGHT` : "$(B Copyright:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_DATE` : "$(B Date:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_DEPRECATED` : "$(RED Deprecated:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_EXAMPLES` : "$(B Examples:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_HISTORY` : "$(B History:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_LICENSE` : "$(B License:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_RETURNS` : "$(B Returns:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_SEE_ALSO` : "$(B See Also:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_STANDARDS` : "$(B Standards:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_THROWS` : "$(B Throws:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_VERSION` : "$(B Version:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_SECTION_H` : `$(B $0)$(BR)$(BR)`,
		 `DDOC_SECTION` : `$0$(BR)$(BR)`,
		 `DDOC_MEMBERS` : `$(DL $0)`,
		 `DDOC_MODULE_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_CLASS_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_STRUCT_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_ENUM_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_TEMPLATE_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_PARAMS` : "$(B Params:)$(BR)\n$(TABLE $0)$(BR)",
		 `DDOC_PARAM_ROW` : `$(TR $0)`,
		 `DDOC_PARAM_ID` : `$(TD $0)`,
		 `DDOC_PARAM_DESC` : `$(TD $0)`,
		 `DDOC_BLANKLINE` : `$(BR)$(BR)`,

		 `DDOC_ANCHOR` : `<a name="$1"></a>`,
		 `DDOC_PSYMBOL` : `$(U $0)`,
		 `DDOC_KEYWORD` : `$(B $0)`,
		 `DDOC_PARAM` : `$(I $0)`,
		 ];
	import std.datetime : Clock;
	auto now = Clock.currTime();
	s_standardMacros["DATETIME"] = "%s %s %s %s:%s:%s %s".format(
		now.dayOfWeek.to!string.capitalize, now.month.to!string.capitalize,
		now.day, now.hour, now.minute, now.second, now.year);
	s_standardMacros["YEAR"] = now.year.to!string;
}


/**
	Takes a DDOC string and outputs formatted HTML.

	The hlevel parameter specifies the header level used for section names (&lt;h2&gt by default).
	By specifying a display_section callback it is also possible to output only certain sections.
*/
string formatDdocComment(string ddoc_, int hlevel = 2, bool delegate(string) display_section = null)
{
	return formatDdocComment(ddoc_, new BareContext, hlevel, display_section);
}
/// ditto
string formatDdocComment(string text, DdocContext context, int hlevel = 2, bool delegate(string) display_section = null)
{
	auto dst = appender!string();
	filterDdocComment(dst, text, context, hlevel, display_section);
	return dst.data;
}
/// ditto
void filterDdocComment(R)(ref R dst, string text, DdocContext context, int hlevel = 2, bool delegate(string) display_section = null)
{
	auto comment = new DdocComment(text);
	comment.renderSectionsR(dst, context, display_section, hlevel);
}


/**
	Sets a set of macros that will be available to all calls to formatDdocComment.
*/
void setDefaultDdocMacroFiles(string[] filenames)
{
	import vibe.core.file;
	import vibe.stream.operations;
	s_defaultMacros = null;
	foreach (filename; filenames) {
		auto text = readAllUTF8(openFile(filename));
		parseMacros(s_defaultMacros, splitLines(text));
	}
}


/**
	Sets a set of macros that will be available to all calls to formatDdocComment and override local macro definitions.
*/
void setOverrideDdocMacroFiles(string[] filenames)
{
	import vibe.core.file;
	import vibe.stream.operations;
	s_overrideMacros = null;
	foreach (filename; filenames) {
		auto text = readAllUTF8(openFile(filename));
		parseMacros(s_overrideMacros, splitLines(text));
	}
}


/**
	Holds a DDOC comment and formats it sectionwise as HTML.
*/
class DdocComment {
	private {
		Section[] m_sections;
		string[string] m_macros;
		bool m_isDitto = false;
		bool m_isPrivate = false;
	}

	this(string text)
	{

		if (text.strip.icmp("ditto") == 0) { m_isDitto = true; return; }
		if (text.strip.icmp("private") == 0) { m_isPrivate = true; return; }


//		parseMacros(m_macros, context.defaultMacroDefinitions);

		auto lines = splitLines(text);
		if( !lines.length ) return;

		int getLineType(int i)
		{
			auto ln = strip(lines[i]);
			if( ln.length == 0 ) return BLANK;
			else if( ln.length >= 3 && ln.allOf("-") ) return CODE;
			else if( ln.indexOf(':') > 0 && isIdent(ln[0 .. ln.indexOf(':')]) ) return SECTION;
			return TEXT;
		}

		int skipCodeBlock(int start)
		{
			do {
				start++;
			} while(start < lines.length && getLineType(start) != CODE);
			if (start >= lines.length) return start; // unterminated code section
			return start+1;
		}

		int skipSection(int start)
		{
			while (start < lines.length) {
				if (getLineType(start) == SECTION) break;
				if (getLineType(start) == CODE)
					start = skipCodeBlock(start);
				else start++;
			}
			return start;
		}

		int skipBlock(int start)
		{
			do {
				start++;
			} while(start < lines.length && getLineType(start) == TEXT);
			return start;
		}


		int i = 0;

		// special case short description on the first line
		while( i < lines.length && getLineType(i) == BLANK ) i++;
		if( i < lines.length && getLineType(i) == TEXT ){
			auto j = skipBlock(i);
			m_sections ~= Section("$Short", lines[i .. j]);
			i = j;
		}

		// first section is implicitly the long description
		{
			auto j = skipSection(i);
			if( j > i ){
				m_sections ~= Section("$Long", lines[i .. j]);
				i = j;
			}
		}

		// parse all other sections
		while( i < lines.length ){
			assert(getLineType(i) == SECTION);
			auto j = skipSection(i+1);
			assert(j <= lines.length);
			auto pidx = lines[i].indexOf(':');
			auto sect = strip(lines[i][0 .. pidx]);
			lines[i] = stripLeftDD(lines[i][pidx+1 .. $]);
			if (lines[i].empty && i < lines.length) i++;
			if (sect == "Macros") parseMacros(m_macros, lines[i .. j]);
			else {
				m_sections ~= Section(sect, lines[i .. j]);
			}
			i = j;
		}

//		parseMacros(m_macros, context.overrideMacroDefinitions);
	}

	@property bool isDitto() const { return m_isDitto; }
	@property bool isPrivate() const { return m_isPrivate; }

	bool hasSection(string name) const { return m_sections.canFind!(s => s.name == name); }

	void renderSectionR(R)(ref R dst, DdocContext context, string name, int hlevel = 2)
	{
		foreach (s; m_sections)
			if (s.name == name)
				parseSection(dst, name, s.lines, context, hlevel, m_macros);
	}

	void renderSectionsR(R)(ref R dst, DdocContext context, bool delegate(string) display_section, int hlevel)
	{
		foreach (s; m_sections) {
			if (display_section && !display_section(s.name)) continue;
			parseSection(dst, s.name, s.lines, context, hlevel, m_macros);
		}
	}

	string renderSection(DdocContext context, string name, int hlevel = 2)
	{
		auto dst = appender!string();
		renderSectionR(dst, context, name, hlevel);
		return dst.data;
	}

	string renderSections(DdocContext context, bool delegate(string) display_section, int hlevel)
	{
		auto dst = appender!string();
		renderSectionsR(dst, context, display_section, hlevel);
		return dst.data;
	}
}


/**
	Provides context information about the documented element.
*/
interface DdocContext {
	/// A line array with macro definitions
	@property string[] defaultMacroDefinitions();

	/// Line array with macro definitions that take precedence over local macros
	@property string[] overrideMacroDefinitions();

	/// Looks up a symbol in the scope of the documented element and returns a link to it.
	string lookupScopeSymbolLink(string name);
}


private class BareContext : DdocContext {
	@property string[] defaultMacroDefinitions() { return null; }
	@property string[] overrideMacroDefinitions() { return null; }
	string lookupScopeSymbolLink(string name) { return null; }
}

private enum {
	BLANK,
	TEXT,
	CODE,
	SECTION
}

private struct Section {
	string name;
	string[] lines;

	this(string name, string[] lines...)
	{
		this.name = name;
		this.lines = lines;
	}
}

private {
	immutable string[string] s_standardMacros;
	string[string] s_defaultMacros;
	string[string] s_overrideMacros;
}

/// private
private void parseSection(R)(ref R dst, string sect, string[] lines, DdocContext context, int hlevel, string[string] macros)
{
	if( sect == "$Short" ) hlevel = -1;

	void putHeader(string hdr){
		if( hlevel <= 0 ) return;
		dst.put("<section>");
		if( sect.length > 0 && sect[0] != '$' ){
			dst.put("<h"~to!string(hlevel)~">");
			foreach( ch; hdr ) dst.put(ch == '_' ? ' ' : ch);
			dst.put("</h"~to!string(hlevel)~">\n");
		}
	}

	void putFooter(){
		if( hlevel <= 0 ) return;
		dst.put("</section>\n");
	}

	int getLineType(int i)
	{
		auto ln = strip(lines[i]);
		if( ln.length == 0 ) return BLANK;
		else if( ln.length >= 3 &&ln.allOf("-") ) return CODE;
		else if( ln.indexOf(':') > 0 && !ln[0 .. ln.indexOf(':')].anyOf(" \t") ) return SECTION;
		return TEXT;
	}

	int skipBlock(int start)
	{
		do {
			start++;
		} while(start < lines.length && getLineType(start) == TEXT);
		return start;
	}

	int skipCodeBlock(int start)
	{
		do {
			start++;
		} while(start < lines.length && getLineType(start) != CODE);
		return start;
	}

	switch( sect ){
		default:
			putHeader(sect);
			int i = 0;
			while( i < lines.length ){
				int lntype = getLineType(i);

				switch( lntype ){
					default: assert(false, "Unexpected line type "~to!string(lntype)~": "~lines[i]);
					case BLANK:
						dst.put('\n');
						i++;
						continue;
					case SECTION:
					case TEXT:
						if( hlevel >= 0 ) dst.put("<p>");
						auto j = skipBlock(i);
						bool first = true;
						// handle backtick inline-code
						foreach (ref l; lines[i .. j]) l = replaceBacktickCode(l);

						// handle macros
						auto text = renderMacros(lines[i .. j].join("\n"), context, macros);
						if (text.endsWith("\n")) text = text[0 .. $-1];

						renderTextLine(dst, text, context);
						dst.put('\n');
						if( hlevel >= 0 ) dst.put("</p>\n");
						i = j;
						break;
					case CODE:
						dst.put("<pre class=\"code\"><code class=\"prettyprint lang-d\">");
						auto j = skipCodeBlock(i);
						auto base_indent = baseIndent(lines[i+1 .. j]);
						auto text = renderMacros(lines[i+1 .. j].map!(ln => ln.unindent(base_indent)).join("\n"), context, macros);
						renderCodeLine(dst, text, context);
						dst.put("\n</code></pre>\n");
						i = j+1;
						break;
				}
			}
			putFooter();
			break;
		case "Params":
			putHeader("Parameters");
			dst.put("<table><col class=\"caption\"><tr><th>Name</th><th>Description</th></tr>\n");
			bool in_parameter = false;
			string desc;
			foreach( string ln; lines ){
				// check if the line starts a parameter documentation
				string name;
				auto eidx = ln.indexOf("=");
				if( eidx > 0 ) name = ln[0 .. eidx].strip();
				if( !isIdent(name) ) name = null;

				// if it does, start a new row
				if( name.length ){
					if( in_parameter ){
						renderTextLine(dst, desc, context);
						dst.put("</td></tr>\n");
					}

					dst.put("<tr><td id=\"");
					dst.put(name);
					dst.put("\">");
					dst.put(name);
					dst.put("</td><td>");

					desc = ln[eidx+1 .. $];
					in_parameter = true;
				} else if( in_parameter ) desc ~= "\n" ~ ln;
			}

			if( in_parameter ){
				auto text = renderMacros(desc, context, macros);
				renderTextLine(dst, text, context);
				dst.put("</td></tr>\n");
			}

			dst.put("</table>\n");
			putFooter();
			break;
	}

}

/// private
private void renderTextLine(R)(ref R dst, string line, DdocContext context)
{
	size_t inCode;
	while( line.length > 0 ){
		switch( line[0] ){
			default:
				dst.put(line[0]);
				line = line[1 .. $];
				break;
			case '<':
				auto res = skipHtmlTag(line);
				if (res.startsWith("<code"))
					++inCode;
				else if (res == "</code>")
					--inCode;
				dst.put(res);
				break;
			case '>':
				dst.put("&gt;");
				line.popFront();
				break;
			case '&':
				if (line.length >= 2 && (line[1].isAlpha || line[1] == '#')) dst.put('&');
				else dst.put("&amp;");
				line.popFront();
				break;
			case '_':
				line = line[1 .. $];
				auto ident = skipIdent(line);
				if( ident.length ) dst.put(ident);
				else dst.put('_');
				break;
			case '.':
				if (line.length > 1 && (line[1].isAlpha || line[1] == '_')) goto case;
				else goto default;
			case 'a': .. case 'z':
			case 'A': .. case 'Z':

				auto url = skipUrl(line);
				if( url.length ){
					/*dst.put("<a href=\"");
					dst.put(url);
					dst.put("\">");*/
					dst.put(url);
					//dst.put("</a>");
					break;
				}

				auto ident = skipIdent(line);
				auto link = context.lookupScopeSymbolLink(ident);
				if( link.length ){
					if( link != "#" ){
						dst.put("<a href=\"");
						dst.put(link);
						dst.put("\">");
					}
					if (!inCode) dst.put("<code class=\"prettyprint lang-d\">");
					dst.put(ident);
					if (!inCode) dst.put("</code>");
					if( link != "#" ) dst.put("</a>");
				} else dst.put(ident.replace("._", "."));
				break;
		}
	}
}

/// private
private void renderCodeLine(R)(ref R dst, string line, DdocContext context)
{
	import ddox.highlight;
	dst.highlightDCode(line, (string ident, scope void delegate() insert_ident) {
		auto link = context.lookupScopeSymbolLink(ident);
		if (link.length && link != "#") {
			dst.put("<a href=\"");
			dst.put(link);
			dst.put("\">");
			insert_ident();
			dst.put("</a>");
		} else insert_ident();
	});
}

/// private
private void renderMacros(R)(ref R dst, string line, DdocContext context, string[string] macros, string[] params = null, MacroInvocation[] callstack = null)
{
	while( !line.empty ){
		auto idx = line.indexOf('$');
		if( idx < 0 ){
			dst.put(line);
			return;
		}
		dst.put(line[0 .. idx]);
		line = line[idx .. $];
		renderMacro(dst, line, context, macros, params, callstack);
	}
}

/// private
private string renderMacros(string line, DdocContext context, string[string] macros, string[] params = null, MacroInvocation[] callstack = null)
{
	auto app = appender!string;
	renderMacros(app, line, context, macros, params, callstack);
	return app.data;
}

/// private
private void renderMacro(R)(ref R dst, ref string line, DdocContext context, string[string] macros, string[] params, MacroInvocation[] callstack)
{
	assert(line[0] == '$');
	line = line[1 .. $];
	if( line.length < 1) {
		dst.put("$");
		return;
	}

	if( line[0] >= '0' && line[0] <= '9' ){
		int pidx = line[0]-'0';
		if( pidx < params.length )
			dst.put(params[pidx]);
		line = line[1 .. $];
	} else if( line[0] == '+' ){
		if( params.length ){
			auto idx = params[0].indexOf(',');
			if( idx >= 0 ) dst.put(params[0][idx+1 .. $].stripLeftDD());
		}
		line = line[1 .. $];
	} else if( line[0] == '(' ){
		line = line[1 .. $];
		int l = 1;
		size_t cidx = 0;
		for( cidx = 0; cidx < line.length && l > 0; cidx++ ){
			if( line[cidx] == '(' ) l++;
			else if( line[cidx] == ')' ) l--;
		}
		if( l > 0 ){
			logDebug("Unmatched parenthesis in DDOC comment: %s", line[0 .. cidx]);
			return;
		}
		if( cidx < 1 ){
			logDebug("Empty macro parens.");
			return;
		}

		auto mnameidx = line[0 .. cidx-1].countUntilAny(" \t\r\n");
		if( mnameidx < 0 ) mnameidx = cidx-1;
		if( mnameidx == 0 ){
			logDebug("Macro call in DDOC comment is missing macro name.");
			return;
		}

		auto mname = line[0 .. mnameidx];
		string rawargtext;
		if (mnameidx+1 < cidx) rawargtext = line[mnameidx+1 .. cidx-1];

		string[] args;
		if (rawargtext.length) {
			auto rawargs = splitParams(rawargtext);
			foreach( arg; rawargs ){
				auto argtext = appender!string();
				renderMacros(argtext, arg, context, macros, params, callstack);
				args ~= splitParams(argtext.data);
			}
		}
		args = join(args, ",").stripLeftDD() ~ args.map!(s => s.stripLeftDD()).array;

		logTrace("PARAMS for %s: %s", mname, args);
		line = line[cidx .. $];

		// check for recursion termination conditions
		foreach_reverse (ref c; callstack) {
			if (c.name == mname && (args.length <= 1 || args == c.params)) {
				logTrace("Terminating recursive macro call of %s: %s", mname, params.length <= 1 ? "no argument text" : "same arguments as previous invocation");
				//line = line[cidx .. $];
				return;
			}
		}
		callstack.assumeSafeAppend();
		callstack ~= MacroInvocation(mname, args);


		const(string)* pm = mname in s_overrideMacros;
		if( !pm ) pm = mname in macros;
		if( !pm ) pm = mname in s_defaultMacros;
		if( !pm ) pm = mname in s_standardMacros;

		if( pm ){
			logTrace("MACRO %s: %s", mname, *pm);
			renderMacros(dst, *pm, context, macros, args, callstack);
		} else {
			logTrace("Macro '%s' not found.", mname);
			if( args.length ) dst.put(args[0]);
		}
	} else dst.put("$");
}

private struct MacroInvocation {
	string name;
	string[] params;
}

private string[] splitParams(string ln)
{
	string[] ret;
	size_t i = 0, start = 0;
	while(i < ln.length){
		if( ln[i] == ',' ){
			ret ~= ln[start .. i];
			start = ++i;
		} else if( ln[i] == '(' ){
			i++;
			int l = 1;
			for( ; i < ln.length && l > 0; i++ ){
				if( ln[i] == '(' ) l++;
				else if( ln[i] == ')' ) l--;
			}
		} else i++;
	}
	if( i > start ) ret ~= ln[start .. i];
	return ret;
}

private string replaceBacktickCode(string line)
{
	auto ret = appender!string;

	while (line.length > 0) {
		auto idx = line.indexOf('`');
		if (idx < 0) break;

		auto eidx = line[idx+1 .. $].indexOf('`');
		if (eidx < 0) break;
		eidx += idx+1;

		ret.put(line[0 .. idx]);
		ret.put("$(DDOC_BACKQUOTED ");
		foreach (i; idx+1 .. eidx) {
			switch (line[i]) {
				default: ret.put(line[i]); break;
				case '<': ret.put("&lt;"); break;
				case '>': ret.put("&gt;"); break;
				case '(': ret.put("$(LPAREN)"); break;
				case ')': ret.put("$(RPAREN)"); break;
			}
		}
		ret.put(")");
		line = line[eidx+1 .. $];
	}

	if (ret.data.length == 0) return line;
	ret.put(line);
	return ret.data;
}

private string skipHtmlTag(ref string ln)
{
	assert(ln[0] == '<');

	// skip HTML comment
	if (ln.startsWith("<!--")) {
		auto idx = ln[4 .. $].indexOf("-->");
		if (idx < 0) {
			ln.popFront();
			return "&lt;";
		}
		auto ret = ln[0 .. idx+7];
		ln = ln[ret.length .. $];
		return ret;
	}

	// too short for a tag
	if (ln.length < 2 || (!ln[1].isAlpha && ln[1] != '#' && ln[1] != '/')) {
		// found no match, return escaped '<'
		logTrace("Found stray '<' in DDOC string.");
		ln.popFront();
		return "&lt;";
	}

	// skip over regular start/end tag
	auto idx = ln.indexOf(">");
	if (idx < 0) {
		ln.popFront();
		return "<";
	}
	auto ret = ln[0 .. idx+1];
	ln = ln[ret.length .. $];
	return ret;
}

private string skipUrl(ref string ln)
{
	if( !ln.startsWith("http://") && !ln.startsWith("http://") )
		return null;

	bool saw_dot = false;
	size_t i = 7;

	for_loop:
	while( i < ln.length ){
		switch( ln[i] ){
			default:
				break for_loop;
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '0': .. case '9':
			case '_', '-', '?', '=', '%', '&', '/', '+', '#', '~':
				break;
			case '.':
				saw_dot = true;
				break;
		}
		i++;
	}

	if( saw_dot ){
		auto ret = ln[0 .. i];
		ln = ln[i .. $];
		return ret;
	} else return null;
}

private string skipIdent(ref string str)
{
	string strcopy = str;

	if (str.length >= 2 && str[0] == '.' && (str[1].isAlpha || str[1] == '_'))
		str.popFront();

	bool last_was_ident = false;
	while( !str.empty ){
		auto ch = str.front;

		if( last_was_ident ){
			// dots are allowed if surrounded by identifiers
			if( ch == '.' ) last_was_ident = false;
			else if( ch != '_' && (ch < '0' || ch > '9') && !std.uni.isAlpha(ch) ) break;
		} else {
			if( ch != '_' && !std.uni.isAlpha(ch) ) break;
			last_was_ident = true;
		}
		str.popFront();
	}

	// if the identifier ended in a '.', remove it again
	if( str.length != strcopy.length && !last_was_ident )
		str = strcopy[strcopy.length-str.length-1 .. $];

	return strcopy[0 .. strcopy.length-str.length];
}

private bool isIdent(string str)
{
	skipIdent(str);
	return str.length == 0;
}

private void parseMacros(ref string[string] macros, in string[] lines)
{
	string name;
	foreach (string ln; lines) {
		// macro definitions are of the form IDENT = ...
		auto pidx = ln.indexOf('=');
		if( pidx > 0 ){
			auto tmpnam = ln[0 .. pidx].strip();
			if( isIdent(tmpnam) ){
				// got new macro definition
				name = tmpnam;
				macros[name] = stripLeftDD(ln[pidx+1 .. $]);
				continue;
			}
		}

		// append to previous macro definition, if any
		if (name.length) macros[name] ~= "\n" ~ ln;
	}
}

private int baseIndent(string[] lines)
{
	if( lines.length == 0 ) return 0;
	int ret = int.max;
	foreach( ln; lines ){
		int i = 0;
		while( i < ln.length && (ln[i] == ' ' || ln[i] == '\t') )
			i++;
		if( i < ln.length ) ret = min(ret, i);
	}
	return ret;
}

private string unindent(string ln, int amount)
{
	while( amount > 0 && ln.length > 0 && (ln[0] == ' ' || ln[0] == '\t') )
		ln = ln[1 .. $], amount--;
	return ln;
}

private string stripLeftDD(string s)
{
	while (!s.empty && (s.front == ' ' || s.front == '\t'))
		s.popFront();
	return s;
}


import std.stdio;
unittest {
	auto src = "$(M a b)\n$(M a\nb)\nMacros:\n	M =     -$0-\n";
	auto dst = "-a b-\n-a\nb-\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "\n  $(M a b)\n$(M a  \nb)\nMacros:\n	M =     -$0-  \n\nN=$0";
	auto dst = "  -a b-  \n\n-a  \nb-  \n";
	assert(formatDdocComment(src) == dst, to!string(cast(ubyte[])formatDdocComment(src)));
}

unittest {
	auto src = "$(M a, b)\n$(M a,\n    b)\nMacros:\n	M = -$1-\n\n	+$2+\n\n	N=$0";
	auto dst = "-a-\n\n	+b+\n\n-a-\n\n	+\n    b+\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "$(GLOSSARY a\nb)\nMacros:\n	GLOSSARY = $(LINK2 glossary.html#$0, $0)";
	auto dst = "<a href=\"glossary.html#a\nb\">a\nb</a>\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "a > b < < c > <a <# </ <br> <abc> <.abc> <-abc> <+abc> <0abc> <abc-> <> <!-- c --> <!--> <! > <!-- > >a.";
	auto dst = "a &gt; b &lt; &lt; c &gt; <a <# </ <br> <abc> &lt;.abc&gt; &lt;-abc&gt; &lt;+abc&gt; &lt;0abc&gt; <abc-> &lt;&gt; <!-- c --> &lt;!--&gt; &lt;! &gt; &lt;!-- &gt; &gt;a.\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "& &a &lt; &#lt; &- &03; &;";
	auto dst = "&amp; &a &lt; &#lt; &amp;- &amp;03; &amp;;\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "<a href=\"abc\">test $(LT)peter@parker.com$(GT)</a>\nMacros:\nLT = &lt;\nGT = &gt;";
	auto dst = "<a href=\"abc\">test &lt;peter@parker.com&gt;</a>\n";
//writeln(formatDdocComment(src).splitLines().map!(s => "|"~s~"|").join("\n"));
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "$(LIX a, b, c, d)\nMacros:\nLI = [$0]\nLIX = $(LI $1)$(LIX $+)";
	auto dst = "[a][b][c][d]\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "Testing `inline <code>`.";
	auto dst = "Testing <code class=\"prettyprint lang-d\">inline &lt;code&gt;</code>.\n";
	assert(formatDdocComment(src) == dst);
}

unittest {
	auto src = "Testing `inline $(CODE)`.";
	auto dst = "Testing <code class=\"prettyprint lang-d\">inline $(CODE)</code>.\n";
	assert(formatDdocComment(src));
}

unittest {
	auto src = "---\nthis is a `string`.\n---";
	auto dst = "<section><pre class=\"code\"><code class=\"prettyprint lang-d\">this is a `string`.\n</code></pre>\n</section>\n";
	assert(formatDdocComment(src) == dst);
}

unittest { // test for properly removed indentation in code blocks
	auto src = "  ---\n  this is a `string`.\n  ---";
	auto dst = "<section><pre class=\"code\"><code class=\"prettyprint lang-d\">this is a `string`.\n</code></pre>\n</section>\n";
	assert(formatDdocComment(src) == dst);
}

unittest { // inssue #99 - parse macros in parameter sections
	import std.algorithm : find;
	auto src = "Params:\n\tfoo = $(B bar)";
	auto dst = "<td> <b>bar</b></td></tr>\n</table>\n</section>\n";
	assert(formatDdocComment(src).find("<td> ") == dst, formatDdocComment(src).find("<td> "));
}
