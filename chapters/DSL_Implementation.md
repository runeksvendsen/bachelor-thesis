\newpage
# Implementation

The implementation consists of the following parts:

1. Abstract syntax (sec. \ref{sec:impl-absyn} below)
2. Parser (sec. \ref{sec:impl-parser} below)
3. Pretty-printer (sec. \ref{sec:impl-pretty-printer} below)
4. Simple boolean evaluator (sec. \ref{sec:spec-eval})
5. Tree data type (sec. \ref{sec:eval-tree})

## Abstract syntax {#sec:impl-absyn}

### Haskell sum types {#sec:haskell-sum-types}

The following subsections describe the implementation's abstract syntax as Haskell *sum types*. A Haskell sum type defines a *type*, as well as one or more *values* (separated by `|`) that are all of the specified type. Thus, the definition `data Color = Red | Green | Blue`{#haskell} defines the *type* `Color` and the *values* `Red`, `Green`, `Blue` (which are all of type `Color`). The defined values can also contain other values, which is specified using one or more types after the value name. Thus, `data PersonInfo = AgeYears Int | WeightKilogram Float | FirstLastName String String`{#haskell} defines three values of type `PersonInfo` containing, respectively: age (integer); weight in kilograms (floating point value); first and last name (two strings).

Haskell sum types may be recursive, meaning that the values of a newly defined type may contain values of its own type, such that `data IntList = Empty | ItemAndRest Int IntList `{#haskell} defines a integer list type `IntList` that is either empty or contains a single integer plus another integer list (that, again, may be empty or contain a single integer plus another integer list).


### Literals {#abstract-literals}

Literals are constants entered by the user.  A `FieldName` is the name of a property in a position. A `FieldValue` is the value of a property. The `Percent` type is used for relative comparisons — a comparison between two value expressions (see \ref{sec:value-expression}).

A `FieldValue` can be one of three types: *number*, *string*, or *boolean*. The implementation uses `Double` to represent numbers, but other implementations are free to use a different type for numbers if, for example, precision is more important than speed.

```haskell
data Literal
    = Percent Number
    | FieldName Text
    | FieldValue FieldValue

data FieldValue
    = Number Double
    | String Text
    | Boolean Bool
```

### Value expression {#sec:value-expression}

A *value expression* (`ValueExpr`) is either a:

* `GroupCount`: a count of the number of groups in a grouping (`count` keyword)
* `FoldMap`: a combined fold and map on a group (e.g. `sum .Value of Portfolio`)
* `Relative`: a relative comparison between two value expressions (separated by the `relative to` keyword)

```haskell
data ValueExpr
    = GroupCount Expr
    | FoldMap Fold Expr
    | Relative Expr Expr

data Fold
    = Sum
    | Avg
    | Max
    | Min
```

For example, the concrete syntax `sum .Value of Country relative to Portfolio` —  the value of the group *Country* relative to the value of the group *Portfolio* — is represented as follows in abstract syntax. *NB: see the section* **Top-level expression** below *(\ref{sec:top-level-expression}) for a specification of `Map`*:

```haskell
Relative
    (ValueExpr (FoldMap Sum (Map (Literal (FieldName "Value")) (Var "Country"))))
    (ValueExpr (FoldMap Sum (Map (Literal (FieldName "Value")) (Var "Portfolio"))))
```

The abstract syntax is thus a bit more verbose in this case, with the benefit of allowing more complex relative comparisons, e.g. `average .Exposure of Issuer relative to .Value of Country`.

Note that — as mentioned in section \ref{sec:transformation-pass} — there is a difference between, on the one hand, the output of parsing e.g. `sum .Value of Country relative to Portfolio` and, on the other hand, the input expected by the evaluator. The parser will output simply `Var "Portfolio"` as the second argument to `Relative`, whereas the evaluator expects both arguments of `Relative` to be a `ValueExpr`.

### Boolean expression

A *boolean expression* (`BoolExpr`) is either a comparison of two value expressions (`Comparison`), a negation of another boolean expression (`Not`), or logical *and/or* between two boolean expressions (`And`, `Or`).

```haskell
data BoolExpr
    = Comparison Expr BoolCompare Expr
    | And Expr Expr
    | Or Expr Expr
    | Not Expr

data BoolCompare
    = Eq   -- equals
    | NEq  -- does not equal
    | Lt   -- less than
    | Gt   -- greater than
    | LtEq -- less than or equal
    | GtEq -- greater than or equal
```

In order to simplify the pretty-printer, the `BoolCompare` type contains all combinations of equality and order comparisons. In principle, it would be sufficient to have only `Eq` and either `Lt` or `Gt`, which could then be combined using `Or` and `Not` to produce the remaining comparisons. E.g. `a <= b` would be expressed as `Or (BoolExpr (Comparison (Var "a") Lt (Var "b"))) (BoolExpr (Comparison (Var "a") Eq (Var "b")))`{#haskell}.

### Grouping expression

A *grouping expression* is modelled as a `DataExpr`:

```haskell
data DataExpr
    = GroupBy Expr Expr
    | Filter Expr Expr
```

The first argument of both `GroupBy` and `Filter` is the input `DataExpr`. The second argument of `GroupBy` is a property name, by which the input `DataExpr` is to be grouped. The second argument of `Filter` is a `BoolExpr`. Below, two examples of abstract syntax for a `DataExpr` are given, the first containing a *position* condition and the next containing a *group* condition.

The grouping expression `Portfolio where (.InstrumentType == "OTC") grouped by .Counterparty` —  which contains the position comparison `.InstrumentType == "OTC"` — looks as follows in abstract syntax:

```haskell
DataExpr
  (GroupBy
     (DataExpr
        (Filter
           (Var "Portfolio")
           (BoolExpr
              (Comparison
                 (Literal (FieldName (FieldName "InstrumentType")))
                 Eq
                 (Literal (FieldValue (String "OTC")))))))
     (Literal (FieldName (FieldName "Counterparty"))))
```

The grouping expression `Portfolio grouped by .Country where (sum .Value of Country relative to Portfolio >= 10%)`{.color} — which contains the group comparison `sum .Value of Country relative to Portfolio >= 10%`{.color} — looks as follows in abstract syntax:

```haskell
DataExpr
  (Filter
     (DataExpr (GroupBy (Var "Portfolio") (Var "Country")))
     (BoolExpr
        (Comparison
           (ValueExpr
              (Relative
                 (ValueExpr
                    (FoldMap
                       Sum
                       (Map (Literal (FieldName (FieldName "Value"))) (Var "Country"))))
                 (ValueExpr
                    (FoldMap
                       Sum
                       (Map (Literal (FieldName (FieldName "Value"))) (Var "Portfolio"))))
           GtEq
           (Literal (Percent 10)))))
```



### Top-level expression {#sec:top-level-expression}

The `Expr` type has two purposes:

1. It wraps the four types defined above (`Literal`, `ValueExpr`, `BoolExpr`, `DataExpr`)
2. It adds two new expressions:
   1. `Map`: the second argument to `FoldMap`
   2. `Var`: a variable identifier

```haskell
data Expr
    = Literal Literal
    | ValueExpr ValueExpr
    | BoolExpr BoolExpr
    | DataExpr DataExpr
    | Map Expr Expr
    | Var Text
```

The wrapping is done in order to have a single type that can contain all expressions. The four wrapped types are defined as separate types in order to improve code readability.

The `Map` value represents a *map* over a tree of *positions* into a tree of *field values*. The concrete syntax `.Exposure of Country` parses into `Map (Literal (FieldName "Exposure")) (Var "Country")`. It represents the operation of taking the `Country` grouping, which evaluates to a tree with *positions* as leaf nodes, and converting into a tree with *property values* as leaf nodes (specifically, the value of the position's `Exposure` property).

The `Var` value represents a reference to variable name defined via `Let` (see \ref{sec:abstract-syntax-rule-expression} below).


### Rule expression {#sec:abstract-syntax-rule-expression}
The `RuleExpr` type represents the four types of statements described in section \ref{sec:spec-statement}: let-binding (`Let`), grouping iteration (`Forall`), *if*-statement (`If`), and rule requirement (`Rule`).

```haskell
data RuleExpr
    = Let Text Expr
    | Forall Expr [RuleExpr]
    | If Expr [RuleExpr]
    | Rule Expr
```

A single `RuleExpr`-value describes a single statement. Therefore, a compliance rule is described as a *sequence* of one or more `RuleExpr`-values. Similarly, a block statement (\ref{sec:spec-block-statement}) is a sequence of *zero or more* `RuleExpr`-values (the second argument to both `Forall` and `If`).

The `Let`-value describes a variable-definition. The first argument is the variable name and the second argument is the expression that the variable is bound to. Given a list of `RuleExpr` that defines a compliance rule, the let-binding has scope in the `RuleExpr` that follow. Thus, `[Let "a" (Literal (FieldValue (Bool True))), Rule (Var "a")]` defines a compliance rule which, first, binds the variable *a* to **true** (`let a = true`), and then uses this definition in a rule requirement (`require a`).

The `Forall`-value describes an iteration over a grouping. The first argument is the `DataExpr` to iterate over, and the second argument is the body of the iteration (see \ref{sec:spec-grouping-iteration}).

The `If`-value represents an *if*-statement. The first argument is the boolean condition, and the second argument is the block statement that is executed if the boolean condition evaluates to **true**.

Finally, the `Rule`-value represents a rule requirement (`require` keyword). Its only argument is the boolean condition of the rule requirement.

### Examples rule

The following code block shows Rule III (sec. \ref{sec:spec-rule-iii}) in abstract syntax. This particular rule has been chosen because it uses all the constructs enumerated in table \ref{tab:rule-matrix}. The abstract syntax is formatted so that arguments to the same constructor appear at equal indentation levels. For example, the two `BoolExpr`-values at line 8 and line 13, respectively, are both arguments to the `Or`-value on line 7.

```haskell
[ Let
    "govtSecurities"
    (DataExpr
       (Filter
          (Var "Portfolio")
          (BoolExpr
             (Or
                (BoolExpr
                   (Comparison
                      (Literal (FieldName (FieldName "InstrumentType")))
                      Eq
                      (Literal (FieldValue (String "GovernmentBond")))))
                (BoolExpr
                   (Comparison
                      (Literal (FieldName (FieldName "InstrumentType")))
                      Eq
                      (Literal (FieldValue (String "StateBond")))))))))
, Let
    "portfolioValue"
    (ValueExpr
       (FoldMap
          Sum
          (Map (Literal (FieldName (FieldName "Value"))) (Var "Portfolio"))))
, Forall
    (DataExpr
       (GroupBy
          (Var "govtSecurities") (Literal (FieldName (FieldName "Issuer")))))
    [ Let
        "issuerValue"
        (ValueExpr
           (Relative
              (ValueExpr
                 (FoldMap
                    Sum
                    (Map (Literal (FieldName (FieldName "Value"))) (Var "Issuer"))))
              (Var "portfolioValue")))
    , If
        (BoolExpr
           (Comparison (Var "issuerValue") Gt (Literal (Percent 35))))
        [ Let
            "issues"
            (DataExpr
               (GroupBy (Var "Issuer") (Literal (FieldName (FieldName "Issue")))))
        , Rule
            (BoolExpr
               (Comparison
                  (ValueExpr (GroupCount (Var "issues")))
                  GtEq
                  (Literal (FieldValue (Number 6)))))
        , Forall
            (Var "issues")
            [ Rule
                (BoolExpr
                   (Comparison
                      (ValueExpr
                         (Relative
                            (ValueExpr
                               (FoldMap
                                  Sum
                                  (Map (Literal (FieldName (FieldName "Value"))) (Var "Issue"))))
                            (Var "portfolioValue")))
                      LtEq
                      (Literal (Percent 30))))
            ]
        ]
    ]
]
```

## Parser {#sec:impl-parser}

The parser is implemented using *parser combinators*. The two main ideas behind parser combinators are: **(a)** representing a parser as a *value* and, **(b)** combining two or more of these parsers into a new parser using *combinators*.

### Parser combinators

As an educational example, consider a hypothetical DSL which consists of two commands: **(1)** `hello` which prints the text *hello*; and **(2)** `exit` which exits. We use the Haskell sum type `data Command = Hello | Exit` to represent one of these two commands as a value. Next, we define two parsers named: **(1)** `pHello`, which accepts the text string `"hello"` as input and returns the value `Hello`; and **(2)** `pExit`, which accepts the text string `"exit"` as input and returns the value `Exit`. Now, we may use the infix parser combinator `<|>` to combine `pHello` and `pExit` into a new parser ` pCommand = pHello <|> pExit` which parses *either* the string `"hello"` and returns `Hello`, *or* the string `"exit"` and returns `Exit`.

Now, assume that we want to parse a source file for this language — the format of which is: zero or more commands separated by a newline character. For this we may use two other combinators:

1. The infix parser combinator `<*`, which combines the two parsers given as the left and right argument into a new parser that first runs the left parser, then runs the right parser, and returns the value of the left parser. Given a parser `pNewline` (which parses a single newline character) we can construct a parser for a single line in the source file like so: `pLine = pCommand <* pNewline`.
2. The function `many`, which takes a parser as input and returns a new parser that parses zero or more occurrences of the given parser, returning a list of the parsed values. Using this combinator we can define a parser for a source file: `pSource = many pLine`

We can then run the parser `pSource` on the following input source file:

```
hello
hello
exit
hello
exit
```

which returns the sequence of commands `[Hello, Hello, Exit, Hello, Exit]`. We permit ourselves to leave as unspecified the semantics of this program.

### Overview

The parser implementation uses two Haskell libraries. Firstly, it uses the `megaparsec` library[@Megaparsec], which enables defining parsers that parse a text string into a Haskell value. Secondly, the implementation uses the library `parser-combinators`[@ParserCombinators], which offers a way to construct a parser for a top-level expression by combining a set of *operator*-parsers along with information about each operator's *fixity* (prefix/postfix/infix), precedence, and associativity.

The implementation can be divided into three main parts:

1. Parsing of *literals* and *variable names* — using primitives defined in the `megaparsec` library
2. Parsing of *expressions* (see \ref{sec:spec-expression}) — using the `parser-combinators` library and a table of operators
3. Parsing of *statements* — using a combination of the two parsers above

In the code below, names prefixed with `M.` are defined by the `megaparsec` library. The combinators `many` and `<|>` are defined in the module `Control.Applicative`, which is part of the Haskell standard library (`base`).

### Variable names

A variable name is either a reference to an existing variable, or the name of a new variable (after the `let` keyword). The parser for a reference to an existing variable is defined as:

```haskell
pVarReference :: Parser Text
pVarReference = do
    firstChar <- M.letterChar
    remainingChars <- many M.alphaNumChar
    let identifier = toS $ firstChar : remainingChars
    -- prevent keywords from being parsed as
    --  identifiers/variable references
    if not $ identifier `elem` keywords
        then return identifier
        else M.failure Nothing (Set.fromList [])
```

It first parses a single alphabetic character (upper/lower case), followed by zero or more alphanumeric characters (upper/lower case). `toS` is a generic function that converts to/from a list of characters and the `Text` string type. Notably, this parser refuses to parse keywords as variable names, by failing if the variable name parsed on the first two lines is present in the pre-defined list of keywords (`keywords`). A better solution to the problem of avoiding the parsing of keywords as variable references is desirable, primarily to avoid maintaining a separate list of keywords  — which is not guaranteed to agree with the actual keywords used inside various parsers.

The parser for the variable name on the left-hand side of a let-binding is defined as:

```haskell
pDefineVar = do
    word@(firstChar : remainingChars) <- toS <$> pVarReference
    if C.isLower firstChar
        then return (toS word)
        else failParse "Variable name must begin with lower case letter"
                [toS $ C.toLower firstChar : remainingChars]
```

This parser reuses the above parser for variable references (`pVarReference`), but fails unless the first character is lower case. In case of the first character being upper case, a suggestion — substituting the first character for its lower case counterpart — is provided to the user.

### Literals

Parsing literals starts with defining parsers for a boolean (`pBool`), a string literal (`pStringLiteral`) and a number (`pNumber`). And then — using the `<|>` parser combinator — combining these three parsers into a parser for field values (`pFieldValue`):

```haskell
pBool :: Parser Bool
pBool =
        pConstant "true" *> return True
    <|> pConstant "false" *> return False
  where
    pConstant str = M.try $ M.chunk str *> M.notFollowedBy M.alphaNumChar

pStringLiteral :: Parser Text
pStringLiteral = fmap toS $
    M.char '"' *> M.manyTill M.charLiteral (M.char '"')

pNumber :: Parser Number
pNumber = signed $
    M.try (fromReal <$> M.float) <|> fromIntegral <$> M.decimal
  where
    signed = M.signed (return ())

pFieldValue :: Parser FieldValue
pFieldValue =
        Bool <$> pBool
    <|> String <$> pStringLiteral
    <|> Number <$> pNumber
```

In `pBool`,  `M.chunk` matches a string (a sequence of characters). The combination of `M.notFollowedBy` and `M.try` makes sure that the `pConstant` parser does not match a longer string that simply *starts with* `str` — e.g. the string `"trueSomething"`. This is necessary for the `pBool` parser to not match e.g. variable names that are prefixed with `true` or `false`. See the paragraph regarding the `pNumber` parser below for an explanation of how `M.try` works. The `*>` combinator first runs the left parser, then the right parser, and returns the value of the right parser. Using `return`, a parser is defined which does not consume any input but only returns a value.

In `pStringLiteral`, a string literal is parsed by expecting a starting double quote character (`"`), followed by zero or more of the character defined by `M.charLiteral` until it reaches an ending `"`. `M.charLiteral` is defined by `megaparsec`, and allows parsing string literals containing escaped double quotes (prefixed with a backslash). For example, the input text `"he\"y"` will be parsed as the string `he"y`.

The `pNumber` parser parses either a floating point number or an integer, and in both cases converts this number into the internal representation used for a number (`Number`) using `fromReal` or `fromIntegral`. The `M.try` combinator is important. Given an input of e.g. `47`, the `pNumber` parser will first try to execute the floating point parser. The floating point parser will consume `47` and then fail, since it expects a `.` (followed by the fractional part of the floating point number). The `M.try` combinator makes the floating point parser *backtrack* on failure, meaning that — upon failure — it will set the current position in the input as if it hadn't consumed any input (even though it consumed `47` in the example). Continuing with the example, after the floating point parser fails, the `<|>` combinator will continue with the integer parser, which will succeed on the input `47`. If `M.try` *hadn't* been applied to the floating point parser, the right argument to `<|>` would not be executed, since the right argument to `<|>` is only tried if the left argument parser does not consume any input. Finally, `signed` (defined using `M.signed`) transforms any *number*-parser into the same number-parser that also accepts an optional minus (`-`) or plus (`+`) prefix, and modifies the output number accordingly (negating the number in case of a `-` prefix).

The final parser for literals (`pLiteral`) uses `pFieldValue` defined above, as well as a parser for a field name (`pFieldName`) and a percentage (`pPercentage`):

```haskell
pFieldName :: Parser FieldName
pFieldName = do
    varRef <- M.char '.' *> pVarReference
    let word@(firstChar : remainingChars) = toS varRef
    if C.isUpper firstChar
        then return (fromString word)
        else failParse "Field name must begin with upper case letter"
                [toS $ C.toUpper firstChar : remainingChars]

pPercentage :: Parser Number
pPercentage = pNumber <* M.char '%'

pLiteral :: Parser Literal
pLiteral =
        FieldName <$> pFieldName
    <|> percentOrFieldValue
  where
    percentOrFieldValue =
        (Percent <$> M.try pPercentage
        <|> FieldValue <$> pFieldValue) <* M.notFollowedBy M.alphaNumChar
```

The `pFieldName` parser is very similar to the `pDefineVar` parser. The only difference is that it expects a leading dot (`.`), and it rejects field names starting with a *lower case* character. The `fromString` function converts a list of characters into the internal representation for a field name (`FieldName`).

The `pPercentage` parser simply parses anything `pNumber` parses if it's followed by a percent (`%`) character. How it's used in the final `pLiteral` parser is important, however. Firstly, `M.try` must be applied to `pPercentage`, as `pPercentage` will consume any leading number, and fail unless a `%` follows (making `pLiteral` not try the alternatives). Secondly, `pPercentage` must be tried *before* the `pNumber` parser (part of `pFieldValue`), because otherwise the `pFieldValue` parser will succeed in parsing a percentage as simply a number (stopping before it reaches `%`).

The parser for `FieldValue` and `Percent` are required to not be immediately followed by an alphanumeric character. This prevents e.g. `5relative to 5` (notice the absence of whitespace between the first 5 and `relative`) from parsing, which would otherwise be accepted. Applying `M.notFollowedBy M.alphaNumChar` to the `pFieldName` parser would not make sense, as this parser does not stop until it has consumed all consecutive alphanumeric characters.

### Expressions

In order to parse expressions, four helper functions are defined: `lexeme`, `kw`, `ks`, and `parens`.

```haskell
lexeme :: Parser a -> Parser a
lexeme = M.lexeme spaceTab

kw :: Text -> Parser ()
kw input = lexeme . M.try $
    M.chunk input *> M.notFollowedBy M.alphaNumChar

ks :: Text -> Parser ()
ks input = lexeme . M.try $
    M.chunk input *> M.notFollowedBy symbolChar
  where
    symbolChar = M.oneOf ['=', '>', '<', '!']

parens :: Parser a -> Parser a
parens = M.between
    (lexeme $ M.chunk "(")
    (lexeme $ M.chunk ")")
```

The `lexeme` function transforms its input parser into a parser that discards trailing space and/or tab characters (`spaceTab` consumes zero or more tabs/and or spaces). Note that *leading* tabs/spaces are not discarded by `lexeme` — all parsers assume that leading whitespace has been consumed. Thus, `lexeme` is used to define parsers for input with optional trailing spaces/tabs.

The `kw` function defines a parser for a keyword — e.g. `let`, `count`, `where`, `NOT`. As with the parser for boolean constants (`pBool`), `kw` makes use of `M.notFollowedBy M.alphaNumChar` and `M.try` so that it doesn't match keyword-prefixed strings — thus making sure e.g. `counterParty` is parsed as a variable reference, rather than the `count` keyword followed by the variable name `erParty`.

The `ks` function defines a parser for a key-*symbol*, e.g. `==`, `>`, `<=`. It is very similar to `kw`. The difference is that while `kw`'s use of `M.notFollowedBy` ensures that keyword-prefixed variables are not parsed as a keyword followed by a variable, `ks`'s use of `M.notFollowedBy` ensures that `ks` does not parse e.g `>=` as only *greater than* (`>`), thus leaving the `=` in the input behind and causing parser failure. It is a way of specifying that any number of consecutive `symbolChar` characters must be parsed in their entirety, rather than only matching some valid prefix.

The helper function `parens` simply transforms a parser of something into a parser of that same something surrounded in parentheses — with optional whitespace after both the opening and closing paren.

With these helper functions the expression parser `pExpr` can be defined as follows:

```haskell
pExpr :: Parser Expr
pExpr =
    makeExprParser term exprOperatorTable
  where
    term = lexeme $ parens pExpr <|> pTerm
    pTerm = Literal <$> pLiteral <|> Var <$> pVarReference

exprOperatorTable :: [[Operator Parser Expr]]
exprOperatorTable =
    [ [ InfixL $ kw "where" *> return (\a -> DataExpr . Filter a)
      , InfixL $ kw "grouped" *> kw "by" *> return (\a -> DataExpr . GroupBy a)
      ]
    , [ InfixN $ kw "of" *> return Map ]
    , [ Prefix $ kw "count"   *> return (ValueExpr . GroupCount)
      , Prefix $ kw "sum"     *> return (ValueExpr . FoldMap Sum)
      , Prefix $ kw "average" *> return (ValueExpr . FoldMap Avg)
      , Prefix $ kw "minimum" *> return (ValueExpr . FoldMap Min)
      , Prefix $ kw "maximum" *> return (ValueExpr . FoldMap Max)
      ]
    , [ InfixL $ kw "relative" *> kw "to" *> return (\a -> ValueExpr . Relative a) ]
    , [ InfixN $ ks "==" *> return (mkComparison Eq)
      , InfixN $ ks "!=" *> return (mkComparison NEq)
      , InfixN $ ks ">"  *> return (mkComparison Gt)
      , InfixN $ ks "<"  *> return (mkComparison Lt)
      , InfixN $ ks ">=" *> return (mkComparison GtEq)
      , InfixN $ ks "<=" *> return (mkComparison LtEq)
      ]
    , [ Prefix $ kw "NOT" *> return (BoolExpr . Not) ]
    , [ InfixL $ kw "AND" *> return (\a -> BoolExpr . And a) ]
    , [ InfixL $ kw "OR"  *> return (\a -> BoolExpr . Or a) ] ]
  where
    mkComparison numComp a b = BoolExpr $ Comparison a numComp b
```

The expression parser is defined using the `makeExprParser` function from the module `Control.Monad.Combinators.Expr` in the `parser-combinators` package. The `makeExprParser` function takes two arguments: **(1)** a parser for a *term*, which in this case is either literal, a variable reference, or an expression enclosed in parens; **(2)** a table of *operators*.

The table of operators is a list of `[Operator Parser Expr]` — thus making it a list of lists. The outer list is ordered by descending precedence, so that the *first* list of operators have the *highest* precedence. For example, the operator table above defines the `where` and `group by` operators as both having the highest precedence because they are in a list that is the first item in the outer list. This is followed by the `of` keyword, which has the next-highest precedence, and so on.

The `Operator` type contains values (`InfixL`, `InfixN`, and `Prefix`) used to define a single operator, by wrapping a *parser* in an `Operator`-value that defines the operator's *fixity* (infix/prefix/postfix) and —  in case of infix operators — associativity (left/right). Thus, the parser for e.g. a left-associative infix operator is wrapped in the `InfixL` value, and the parser for a prefix operator is wrapped in the `Prefix` value. The parser, that is wrapped in an `Operator`-value, returns a *function* that either **(a)** takes a single argument (in the case of prefix and postfix operators); or **(b)** takes two arguments (in the case of infix operators). The type of these arguments must be the same as the type of the value returned by the term-parser (the first argument to `makeExprParser`) — which in our case is the `Expr` type (see \ref{sec:top-level-expression}).

Thus — as an example — given a parser of integers `pInt`, we can define a parser `pIntExpr` for a language that supports addition, subtraction and incrementing (using the `increment` keyword) like so:

```haskell
pIntExpr =
    makeExprParser (lexeme $ parens pIntExpr <|> pInt) table
  where
    table = [ [ Prefix $ kw "increment" *> return (+1) ]
            , [ InfixL $ kw "+" *> return (+) ]
            , [ InfixL $ kw "-" *> return (-) ]
            ]
```

Such that `pIntExpr` parses e.g. the input `5 - 2 + increment 2` to the integer value zero.

### Statements

In order to parse a statement, a parser for a block statement is needed (required by `forall` and `if`). The parser for a block statement `pRuleBlock` is defined as follows:

```haskell
pRuleBlock :: Parser [RuleExpr]
pRuleBlock = M.between
    (lexeme (M.chunk "{") *> M.eol *> spaceTabNewline)
    (lexeme (M.chunk "}"))
    pRules
```

This is very similar to the `parens` function defined above. The difference is that a newline character (`M.eol`) is mandatory after the opening brace, and zero or more newline/space/tab characters (`spaceTabNewline`) may follow it. The `pRules` parser — which parses zero or more newline-separated `RuleExpr` — is defined below.

The way in which newline characters are consumed by `pRuleBlock` results in the following requirements regarding newline-consumption for `pRules` and the parser that precedes `pRuleBlock`. Since `lexeme (M.chunk "{")` does not remove any preceding whitespace, the parser that precedes `pRuleBlock` must consume all whitespace, including newlines, before it runs `pRuleBlock` (such that the current position in the parser is at the opening brace). For `pRules` it is required that all trailing whitespace, including newlines, is consumed, such that the current position in the parser is at the closing brace after `pRules` has been run.

Using `pRuleBlock` — and the previously defined helper functions — parsers are defined for a let-binding (`pLet`), a grouping iteration (`pForall`), an *if*-statement (`pIf`), and a rule requirement (`pRequire`):

```haskell
pLet :: Parser RuleExpr
pLet = do
    varName <- kw "let" *> lexeme pDefineVar
    expr <- lexeme (M.chunk "=") *> lexeme pExpr
    return $ Let varName expr

pForall :: Parser RuleExpr
pForall = do
    dataExpr <- kw "forall" *> lexeme pExpr <* spaceTabNewline
    block <- pRuleBlock
    return $ Forall dataExpr block

pIf :: Parser RuleExpr
pIf = do
    varOrBoolExpr <- kw "if" *> lexeme pExpr <* spaceTabNewline
    block <- pRuleBlock
    return $ If varOrBoolExpr block

pRequire :: Parser RuleExpr
pRequire = kw "require" *> (Rule <$> pExpr)
```

In order to fulfil the above-stated requirements for `pRuleBlock` regarding whitespace, the `pForall` and `pIf` parser consume all whitespace including newlines (via `spaceTabNewline`) before running the `pRuleBlock` parser .

Using the above four parsers, the parser for a single `RuleExpr` can be defined simply as:

```haskell
pRuleExpr :: Parser RuleExpr
pRuleExpr =
    pLet <|> pForall <|> pIf <|> pRequire
```

Since a compliance rule is composed of one or more `RuleExpr` — essentially a block statement without the surrounding braces — the `pRules` parser parses zero or more `pRuleExpr` separated by at least one newline. Here the choice has been made to accept an empty input file (i.e., containing zero rules), but a non-empty input file could easily be required by using `some` instead of `many`.

```haskell
pRules :: Parser [RuleExpr]
pRules = many (lexeme pRuleExpr <* M.eol <* spaceTabNewline)
```

The definition of `pRuleBlock` and `pRules`, as well as how `pRuleBlock` is used inside `pIf` and `pForall`, results in a newline character being optional *before* the opening brace, mandatory *after* the opening brace, and mandatory both before and after the *closing* brace.

The final parser for a source file, `ruleParserDoc`, removes any leading whitespace before running `pRules`. It also requires that the end of the input file is reached after the last `RuleExpr` has been parsed by `pRules`, which makes the parser fail in case the file ends with something unparsable (rather than just succeeding with what *can* be parsed from the file and ignoring the rest).

```haskell
ruleParserDoc :: Parser [RuleExpr]
ruleParserDoc = spaceTabNewline *> pRules <* M.eof
```

### Notes

#### On the choice of `megaparsec`

A Haskell parser combinator library was chosen because it allows writing the parser in Haskell. This is in contrast to, for example, a parser generator like *happy*[@Happy], which requires learning new syntax. A Haskell library was thus seen as the quickest way to arrive at a working parser.  
The `megaparsec` library was chosen because, according to its authors, "*[it] tries to find a nice balance between speed, flexibility, and quality of parse errors.*"[@Megaparsec]

The first version of the parser was written entirely using `megaparsec` — without the use of the `parser-combinators` library. This version had several issues. Firstly, due to the recursive nature of the DSL's expressions — e.g. one of the arguments of a comparison operation can contain a `where` which, in turn, may contain another comparison operation — it was difficult to make sure that the parser terminated, and it often ended up in an infinite loop due to non-obvious reasons. In general, the interactions between the various different parsers was difficult to understand, and a change in one parser often broke a different parser that made use of the former parser.  
This was solved using the `parser-combinators` library, which constructs the recursive expression-parser through the table of operators. This only requires writing the two non-recursive parsers for a literal and a variable reference.

If the parser were to be rewritten, a parser generator like *happy* would be chosen. Both to avoid the problem of non-termination that the `parser-combinators` library helps avoid, and also to enable warnings in case of an ambiguous grammar. Furthermore, a lexer would be employed, primarily to improve parser errors such as `unexpected "(In", expecting "NOT"`, which happen because the parser does not understand the boundary between tokens (a token is a single character in the current implementation).

#### Performance characteristics

Due to the use of backtracking parser combinators, the worst-case theoretical running time of the resulting parser is exponential with respect to the input length. We argue, however, that this is not the case for our parser, because backtracking (use of the `M.try` combinator) is restricted to exactly three places:

1. In `pLiteral`: in which the `pPercentage` parser backtracks if the input is not immediately followed by a percentage sign
2. In `pNumber`: in which the floating-point parser backtracks if the consumed integer is not followed by a period
3. In the parsing of keywords and key-symbols: which backtracks if the keyword is followed immediately by an alphanumeric character (in which case it is parsed as an identifier instead)

and because these parsers call neither themselves nor other backtracking parsers.

## Transformation pass

An implementation of the transformation pass described in sec. \ref{sec:transformation-pass} was attempted, but it was discovered that type inference is needed in order to transform the short-hand `relative to`-expression into the longer form. For example, consider the following three statements:

```rulelang
let portfolioValue = sum .Value of Portfolio
require sum .Value of Country relative to portfolioValue
require sum .Value of Country relative to Portfolio
```

The first line requires no transformation, but simply defines a variable that is used in line 2. Importantly, line 2 does *not* require the described transformation, because the `portfolioValue` argument to `relative to` is a number. Line 3 *does* require the transformation, because the `Portfolio` argument to `relative to` is a grouping. In other words, line 2 is actually what we would like to transform line 3 into, but the only way to know that line 2 should *not* be transformed in the same manner as line 3 is by looking at the type of the right argument to `relative to`. If this type is a number, then the transformation must not be performed. Only if this type is a grouping (as in the example on line 3) should the expression be transformed. Consequently, due to type inference not being implemented, this transformation pass could not be implemented either.

Note, however, that this transformation is not central to the use of the DSL, as a let-binding can be used as the right-hand side of `relative to` (as in the above example) in order to avoid the long form — e.g. `sum .Value of Country relative to sum .Value of Portfolio`.

## Pretty-printer {#sec:impl-pretty-printer}

For the pretty-printer, a simple solution was chosen that does not use external libraries.

The pretty-printer for statements outputs a list of integer/string pairs, with each item in the list representing a single line in the output. The integer specifies the indentation level of the line while the string is the actual line contents. This indentation level is incremented for the lines inside a block statement. 

Pretty-printing of expressions is considered unfinished. The pretty-printer was implemented with the assistance of property-based testing — which generates a piece of abstract syntax, prints it using the pretty-printer, and checks that the parser outputs the original abstract syntax. Using this test, the pretty-printer was adjusted until the test did not output any errors. This method, however, proved insufficient, as the sheer number of different combinations of abstract syntax meant that problematic expressions were not tested within a reasonable time limit. For example, printing the abstract syntax that results from parsing `a AND (b AND c)` incorrectly as `a AND b AND c` — which leaves out the parentheses, thus changing the meaning to `(a AND b) AND c`) — was not detected.

## Bugs

The evaluator contains a bug that arises if a grouping is added to a tree that contains empty groups. If a filter-operation removes all positions from some group, then a subsequent grouping operation will not add a terminal node as child of this group/node, since there are no positions from which this node can be created. This will materialize as a "*Variable not found*"-error when this grouping is used as the argument to a grouping iteration, as the body of the grouping iteration references the group via a variable that has not been added to the environment for the iteration over the empty group.

For example the following example code might fail during evaluation with the error "*Variable 'Issuer' not found*":

```rulelang
forall Portfolio grouped by .Country where (.InstrumentType != "Bond") grouped by .Issuer {
   require sum .Value of Issuer <= 10%
}
```

If the filter-condition causes all positions to be removed from a country-terminal node, then the subsequent grouping by issuer will not create a new *issuer*-terminal node as a child of the given country node. As a consequence, when this particular combination of groups is iterated over, the evaluator will not add a `Issuer` variable to the environment (because the node doesn't exist), which will cause the body of the iteration to reference a variable that doesn't exist.



