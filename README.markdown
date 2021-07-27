Lpeg.vim adds syntax highlighting to Vim with [LPeg].

This replaces the built-in regexp-based syntax highlighting the PEG parser from
LPeg. You can find a detailed rationale on why LPeg specifically was chosen
below.

This is heavily based on the LPeg integration in the [vis] editor: much code was
copied from it and adapted for use in Vim. Really, the bulk of the credit for
this should go to vis and Marc.

Right now this is a prototype, but it seems to work well. I've been using it for
the last few days in real-world usage, and haven't found any problems thus far.

This requires:

- Vim 8.2.[something fairly recent]
  
  I didn't test with older versions, just latest master at the time of writing
  (July 2021). The VimScript parts are written in Vim9Script, but that's not a
  lot and I'll probably revert it back to regular VimScript for compatibility
  later (I just wanted to get some hands-on experience with Vim9Script).

- Vim with Lua integration (`has('lua')`); I only tested Lua 5.3, but if
  other/earlier versions don't work then that's probably something that should
  be fixed. Lua versions are a bit of a mess though :-/

[LPeg]: http://www.inf.puc-rio.br/~roberto/lpeg/
[vis]: https://github.com/martanne/vis


Usage
-----
Nothing is done by default at the moment, to enable it use:

    :Lpeg

Because the used filetypes don't map 1-to-1 with Vim (some in Vim are not
supported, some in LPeg are not in Vim, and some have a different name) this
will use its own filetype detection – the value of `filetype` is not looked at.
The filetype that is used is stored in the `b:lpeg_syntax` variable:

    :echo &filetype
    c
    :echo b:lpeg_syntax
    ansi_c

You can disable it again with:

    :Lpeg stop

To automatically start it, use:

    augroup lpeg-autostart
        au!
        au Filetype python,go :Lpeg
    augroup end

Or to start for all supported filetypes:

    Lpeg autostart

Lexers are looked up in the `lexer` directory in `runtimepath`; this is
essentially the same as `syntax`, except with a different directory name.

    lpeg.vim/lexer                      Defaults bundled with the plugin
    ~/.vim/lexer                        Your owner lexer, overrides any default
    ~/.vim/pack/../newlang.vim/lexer    Lexer from a plugin

There is no support for the `after` directory yet, or modifying syntax from
autocmds.

---

Finally, there are two commands useful for debugging and development; `times`
shows the last 100 parse times:

    :Lpeg times
    apply file      → 80.10ms
    apply    1-33   → 2.29ms
    apply    2-34   → 2.68ms
    apply    2-34   → 2.73ms

And with `parse` you can manually parse some lines and see what the LPeg library
makes of it:

    :Lpeg parse 5       From line 5 until end

    :Lpeg parse 5 10    From line 5 until 10 (inclusive)


Modifying lexers
----------------
I need to write this...


Writing lexers
--------------
I need to write this...


Rationale and history
---------------------
I've wanted more structured syntax highlighting in Vim for a long time; I
prototyped a number of solutions over the years, but nothing *really* worked out
in a way that I liked.

The problems with the current syntax highlighting is that it's very easy to get
something basic working, but it quickly becomes complex and hard. Getting the
[Go syntax file][syn-go] for gopher.vim correct *and* fast was ridiculously hard
and time-consuming, and Go is not a syntactically complex language. And if you
look at some of the regexps in my [jumpy] plugin ... then yeah, it's it's not
pretty (it's easy for languages like Go with an explicit `func` keyword, but
e.g. C and JavaScript are quite hard).

And none of this is very maintainable either (although this is something that
could be improved if Vim would allow comments inside the regexps).

[syn-go]: https://github.com/arp242/gopher.vim/blob/master/syntax/go.vim
[jumpy]: https://github.com/arp242/jumpy.vim/

---

What would a better solution look like?

1. Reasonably fast, even for large files, and it doesn't break.

2. Reasonable easy to modify, including by "normal" users such as sysadmins,
   scientists (in fields other than comp-sci), and just regular hobbyists who
   are not professional developers.

3. Readability and maintenance is important. Right now syntax files are a bit of
   a "write only"-affair.

4. Easy to manage, it should "just work" after dropping a new file in you
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
because I felt it had the best combination of correctness and UX.

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
internally for some things, I don't know if it was considered – I very well may
have missed some discussions somewhere.

Either way, as far as I could find there aren't really any concrete advantages
to tree-sitter outside of "it's a structured parser", and I'm seeing a lot of
downsides.
