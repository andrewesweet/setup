# -*- coding: utf-8 -*-
"""Dracula Pro pygments style.

Palette derived from docs/design/theming.md § 1.3 and the authoritative
scripts/lib/dracula-pro-palette.sh in this repo. Structure is a palette
substitution of github.com/dracula/pygments (MIT); only hex values are
changed, the class is a new authorship.
"""

from pygments.style import Style
from pygments.token import (
    Comment, Error, Generic, Keyword, Literal, Name, Number, Operator,
    Other, Punctuation, String, Text, Whitespace,
)

# Pro Base palette (verbatim; single source of truth is
# scripts/lib/dracula-pro-palette.sh). Reproduced as Python constants so
# `pygmentize -L styles` doesn't need to shell out.
BACKGROUND   = "#22212C"
FOREGROUND   = "#F8F8F2"
COMMENT      = "#7970A9"
SELECTION    = "#454158"
RED          = "#FF9580"
ORANGE       = "#FFCA80"
YELLOW       = "#FFFF80"
GREEN        = "#8AFF80"
CYAN         = "#80FFEA"
PURPLE       = "#9580FF"
PINK         = "#FF80BF"


class DraculaProStyle(Style):
    name = "dracula-pro"
    background_color = BACKGROUND
    highlight_color = SELECTION
    default_style = ""

    styles = {
        Comment:            COMMENT,
        Comment.Hashbang:   COMMENT,
        Comment.Multiline:  COMMENT,
        Comment.Preproc:    PINK,
        Comment.PreprocFile: PINK,
        Comment.Single:     COMMENT,
        Comment.Special:    CYAN,

        Generic:            PINK,
        Generic.Deleted:    RED,
        Generic.Emph:       f"{YELLOW} underline",
        Generic.Error:      RED,
        Generic.Heading:    f"{PURPLE} bold",
        Generic.Inserted:   f"{GREEN} bold",
        Generic.Output:     COMMENT,
        Generic.Prompt:     GREEN,
        Generic.Strong:     ORANGE,
        Generic.Subheading: f"{PURPLE} bold",
        Generic.Traceback:  RED,

        Error:              RED,

        Keyword:            PINK,
        Keyword.Constant:   PURPLE,
        Keyword.Declaration: f"{PINK} italic",
        Keyword.Namespace:  PINK,
        Keyword.Pseudo:     PINK,
        Keyword.Reserved:   PINK,
        Keyword.Type:       CYAN,

        Literal:            ORANGE,
        Literal.Date:       ORANGE,

        Name:               FOREGROUND,
        Name.Attribute:     GREEN,
        Name.Builtin:       f"{PURPLE} italic",
        Name.Builtin.Pseudo: PURPLE,
        Name.Class:         CYAN,
        Name.Constant:      PURPLE,
        Name.Decorator:     GREEN,
        Name.Entity:        PINK,
        Name.Exception:     RED,
        Name.Function:      GREEN,
        Name.Function.Magic: PURPLE,
        Name.Label:         f"{CYAN} italic",
        Name.Namespace:     FOREGROUND,
        Name.Other:         FOREGROUND,
        Name.Tag:           PINK,
        Name.Variable:      f"{FOREGROUND} italic",
        Name.Variable.Class: f"{CYAN} italic",
        Name.Variable.Global: f"{FOREGROUND} italic",
        Name.Variable.Instance: f"{PURPLE} italic",
        Name.Variable.Magic: PURPLE,

        Number:             PURPLE,
        Number.Bin:         PURPLE,
        Number.Float:       PURPLE,
        Number.Hex:         PURPLE,
        Number.Integer:     PURPLE,
        Number.Integer.Long: PURPLE,
        Number.Oct:         PURPLE,

        Operator:           PINK,
        Operator.Word:      PINK,

        Other:              FOREGROUND,

        Punctuation:        FOREGROUND,

        String:             YELLOW,
        String.Backtick:    GREEN,
        String.Char:        YELLOW,
        String.Doc:         YELLOW,
        String.Double:      YELLOW,
        String.Escape:      PINK,
        String.Heredoc:     YELLOW,
        String.Interpol:    PINK,
        String.Other:       YELLOW,
        String.Regex:       RED,
        String.Single:      YELLOW,
        String.Symbol:      PURPLE,

        Text:               FOREGROUND,

        Whitespace:         FOREGROUND,
    }
