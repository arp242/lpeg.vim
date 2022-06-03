LPeg.vim adds syntax highlighting to Vim with [LPeg].

This replaces the built-in regexp-based syntax highlighting the PEG parser from
LPeg. You can find a [detailed rationale] on the why of it below, and see the
[Future work] section for things that aren't yet implemented and some
limitations.

This is heavily based on the LPeg integration in the [vis] editor, which in turn
is heavily based on [Scintillua].

This is pretty experimental; I wrote this last year, got a bit bored with it,
and haven't worked much on it since. It seems to work fairly decently, but
probably quite a few rough edges.

Installation
------------
Install with your favourite package manage or whatnot.

This requires:

- Vim 8.2.[probably something fairly recent]
  
  I didn't test with older versions, just latest master at the time of writing
  (July 2021). The VimScript parts are written in Vim9Script, but that's not a
  lot and I'll probably revert it back to regular VimScript for compatibility
  later (I just wanted to get some hands-on experience with Vim9Script to
  provide some feedback based on real-world usage).

- Vim with Lua integration (`has('lua')`) and Lua 5.3 or newer. Older Lua
  versions won't work right now. This can probably be made to work, but I'm new
  to Lua and would like to focus on actually getting the prototype out rather
  than mucking about with Lua versions.

- LPeg library for Lua. Many Linux package managers have this already, or you
  can use Luarocks.

[LPeg]: http://www.inf.puc-rio.br/~roberto/lpeg/
[vis]: https://github.com/martanne/vis
[Scintillua]: https://orbitalquark.github.io/scintillua/

Usage
-----
After installation nothing is done by default at the moment, to enable it use:

    :LPeg

Because the lexer names don't map 1-to-1 with Vim filetypes (some in Vim are not
supported, some in LPeg are not in Vim, and some have a different name) this
will use its own filetype detection – the value of `filetype` is not looked at.
The name of the lexer is stored in the `b:lpeg_syntax` variable:

    :echo &filetype
    c
    :echo b:lpeg_syntax
    ansi_c

You can disable it again with:

    :LPeg stop

To automatically start it, use:

    augroup lpeg-autostart
        au!
        " Only for Go and Python
        au Filetype go,python :LPeg

        " Or for all filetypes.
        " au Filetype * :LPeg
    augroup end

Lexers are looked up in the `lexer` directory in `runtimepath`; this is
essentially the same as `syntax`, except with a different directory name:

    lpeg.vim/lexer/?.lua                     Defaults bundled with the plugin
    ~/.vim/pack/../newlang.vim/lexer/?.lua   Lexer from a plugin
    ~/.vim/lexer/?.lua                       Your owner lexer, overrides any
                                             default

There is no support for the `after` directory yet, or modifying the lexer from
an autocmd.

### Color schemes
The standard Scintillua styles don't *quite* map 1-to-1 with the standard Vim
styles; the following styles are mapped:

    Style               Description                 Vim hi

    STYLE_COMMENT       Comments                    Comment
    STYLE_CONSTANT      Constants                   Constant
    STYLE_ERROR         Erroneous syntax            Error
    STYLE_KEYWORD       Language keywords           Keyword
    STYLE_IDENTIFIER    Identifier words            Identifier
    STYLE_LABEL         Labels                      Label
    STYLE_FUNCTION      Function definitions        Function
    STYLE_STRING        Strings                     String
    STYLE_NUMBER        Numbers                     Number
    STYLE_OPERATOR      Operators                   Operator
    STYLE_TYPE          Static types                Type
    STYLE_PREPROCESSOR  Preprocessor statements     PreProc

As you can see, they mostly use the same name with the exception of `PreProc`.

The following standard Scintillua styles are not in standard Vim colour schemes,
so we set some defaults for them:

    Style               Description         Vim hi      bg=light        bg=dark

    STYLE_CLASS         Class definitions   Class       
    STYLE_EMBEDDED      Embedded code
    STYLE_REGEX         Regexp strings
    STYLE_VARIABLE      Variables

You can customize them if add them to your colour scheme:

    hi Class guitermfg=red

Or from your vimrc:

    autocmd ColorScheme * hi Class guitermfg=red

Not used:

    STYLE_WHITESPACE    Whitespace          None 


To examine the styling used you can use my little [synfo.vim] plugin; `:Synfo
types` will list all the types that are defined for the current file, and just
`:Synfo` will show how whatever is under the cursor is highlighted.

[synfo.vim]: https://github.com/arp242/synfo.vim

### Debugging commands
Finally, there are two commands useful for debugging and development; `times`
shows the last 100 parse times:

    :LPeg times
    apply      1-649    → 32.75ms
    apply  19850-20418  → 6.30ms
    apply  19850-20417  → 6.27ms

The numbers are the start-end byte offsets of what was being parsed.

With `parse` you can manually run parse and see what the LPeg library makes of
it:

    :LPeg parse
    name             byte pos      line:col          text
    type             1-3           1:1-3             │int│
    whitespace       4             1:4               │ │
    identifier       5-8           1:5-8             │main│
    operator         9             1:9               │(│
    operator         10            1:10              │)│
    whitespace       11            1:11              │ │
    operator         12            1:12              │{│
    whitespace       13-14         1:13-2:1          │↪↦│
    keyword          15-20         2:2-7             │return│
    whitespace       21            2:8               │ │
    number           22            2:9               │1│
    operator         23            2:10              │;│
    whitespace       24            2:11              │↪│
    operator         25-26         3:1-2             │}│

The text is elided if it's long: … will be shown in the middle. Tabs and
newlines are printed as '↦`, and `↪`.

Modifying lexers
----------------
TODO: I need to write this.


Writing lexers
--------------
As a small introduction to writing lexers let's write one for Go from scratch.
Why Go? Because the syntax is fairly simple, yet is still a "real" example
rather than a "toy example".

See: [writing-lexer.markdown].


Future work
-----------
Right now it's a functional and usable prototype, but a number of things could
be done:

- The heuristic of what to re-lex on updates is primitive: it just takes the
  current visible screen minus 32768 bytes and re-lexes that. This isn't really
  needed, and we can be a lot smarter about this. This is identical to how vis
  works by the way, and seems "fast enough", but it's obviously far from ideal.
  We can also take advantage of text properties being "smart" and moving with
  text as it moves.

- Many lexers aren't as detailed/good as Vim; while I'm not a fan of
  super-colourful highlights, many of the current lexers are kinda primitive.
  Specifically, in many of them all identifiers are highlighted as "Identifier",
  which I don't especially fancy.

  I spent some time on the Go lexer to improve it, so that one is about on-par
  (or actually, better).

- Modifying lexers from after/ and/or autocmd should be possible.

- Provide text objects and folding based on the parsing info. This information
  is actually in a lot of the lexers, we just don't use it yet.


Rationale and history
---------------------
I've wanted more structured syntax highlighting in Vim for a long time; I
prototyped a number of solutions over the years, but nothing *really* worked out
in a way that I liked.

The problems with the current syntax highlighting is that it's very easy to get
something basic working, but it quickly becomes complex and hard. Getting the
[Go syntax file][syn-go] for gopher.vim correct *and* fast was quite hard and
time-consuming, and Go is not a syntactically complex language. And if you look
at some of the regexps in my [jumpy] plugin ... then yeah, it's it's not pretty
(it's easy for languages like Go with an explicit `func` keyword, but e.g. C and
JavaScript are quite hard).

And none of this is very maintainable either, although this is something that
could be improved if Vim would allow comments inside the regexps, regexps in
general are not exactly well-known for their excellent readability, especially
not if you optimize things with some "tricks".

[syn-go]: https://github.com/arp242/gopher.vim/blob/master/syntax/go.vim
[jumpy]: https://github.com/arp242/jumpy.vim/

---

What would a better solution look like?

1. Reasonably fast, even for large files, and it doesn't break.

2. Reasonable easy to modify, including by "normal" users such as sysadmins,
   scientists (in fields other than comp-sci), and just regular hobbyists who
   are not professional developers.

3. Readability and maintenance is important. Right now syntax files are a bit of
   a "write only, hopefully never read"-affair.

4. Easy to manage, it should "just work" after dropping a new file in your
   ~/.vim/ without muckery.

There are a million-and-one parser generators, tools, and so forth out there.
It's literally people's entire career to research these kind of things and write
tools for them.

Many of then fit requirement 1 ("fast and correct"), but most of them are not
especially user-friendly. EBNF (and variants thereof) are more or less the
standard for describing languages, but do you really want this as the basis for
your syntax highlighting? Probably not.

This is actually a great feature of the current syntax system: you can add,
remove, and modify things fairly easy. "I don't like this highlight" or "I want
to add a new highlight for X" should be something a fairly experienced dev can
do in under an hour. LPeg mostly retains this feature: you can still say "yo
dawg, highlight this for me, kthxbye" or "eww, I don't like this, get rid of
it!" and be done with it.

Without detailing all the solutions I looked at, I eventually settled on LPeg
because of all the solutions I found I felt it had the best combination of
correctness and UX.

---

An obvious question people might have "why not tree-sitter like Neovim"? I spent
some time investigating this, actually I spent about two full days on
implementing it some months ago.

I came to the conclusion that tree-sitter doesn't really satisfy the UX
requirements:

- It's really hard to modify for end-users.
- There's an entire circus around managing it for end-users.
- It inflicts the NodeJS ecosystem on people. I'm not a sadist so I'd rather
  not.

Overall I do think the "tree-sitter approach" of more structured parsing is the
better approach, I just don't think that tree-sitter is an especially great fit
for Vim. I don't know why Neovim went with tree-sitter specifically: as near as
I can determine it's just because someone wrote a patch for that – I couldn't
really find any discussions about it. Interestingly Neovim does use LPeg
internally for some things, I don't know if it was considered – or maybe it was,
I very well may have missed some discussions somewhere.

Either way, as far as I could find there aren't really any concrete advantages
to tree-sitter specifically outside of "it's a structured parser", and I'm
seeing a lot of downsides.
