# Bugs/code

4. ~~`forall`: don't overwrite `Portfolio` with grouped tree~~
5. ~~Remove empty nodes from tree after filter~~

# Report (mandatory)

* *Double-check*
    * Does all `.color` expressions in the report parse correctly?
      * `cat chapters/*.md | egrep -o '``.*``{.color}'`
    * ~~Consistently use either "property" or "field" name/value~~
* **Implementation**

    * **Notes**
      * Potential grammar ambiguity using `parser-combinators`? Or non-ambiguous?

    * Abstract syntax
        * ~~Mention: Field is a synonym for property, e.g. `FieldValue` refers to a property value~~

* **Language specification**
    * Concrete syntax
        * `where` high precedence:
            * Mandatory parenthesis around `where` condition
        * ~~Make sure filter semantics are properly defined: `boolExpr` evaluated in a particular *environment* and TermNode position removed if result is `false`~~
            * ~~**NB:** This *environment* is the same as that of a `forall`-statement~~
    * Example rules
        * Consistently use either `relative to Portfolio` or `let portfolioValue = sum .Value of Portfolio`
* **Future work**
    * IDE features
        * Tooltip, e.g. what is "DirtyValue" property or "GICS Sector"?
        * Auto-complete
        * Suggestions
* *Layout/Pandoc/Latex*
  * `lstlistings`: prevent line break between `.` and field name
  * Inline code highlight/background color

# Report (optional)

* **NEW: Discussion**
  * ~~`Forall` as part of `BoolExpr`~~
  * ~~`forall`: bring into scope *value* of current group, e.g. `Country.Country = "DK"`~~
    * ~~**NB: the reason that Rule IV & V must be implemented using `where` instead of `if`**~~

**Implementation**

* Abstract syntax
  * If it weren't for `parser-combinators` I wouldn't allow e.g. `Expr` as argument to `And` (but rather only allow `BoolExpr`)
  * Table summarizing the connection between the concrete syntax in "Rule evaluation" and the corresponding abstract syntax, e.g.:

**Language specification**

* Evaluation
  * Correct environment arrow in figure `fig:eval-forall-env`

