Noter til rapport
=======

## "Wide" vs. "narrow" abstract syntax 

* "Wide":
  * Parser parses all expressions, instead of failing weirdly on e.g. `require sum .Value of Issuer relative to .Portfolio <= 10%` resulting in *Unexpected '.' in **.Value** keyword* (unrelated to the actual error)
* "Narrow":
  * Better readability of abstract syntax (easier to understand without looking at the evaluator)
  * Simpler generation of property test data

## Forall/foreach

Lav `Foreach` om til et `BoolExpr`, så det kan bruges i disse udtryk.

`If` er et alternativ til at lave `Forall` om til `BoolExpr` og udtrykke via dette.

## Varianter af sprog

### Ubegrænset nested iteration over samme input (`for each`?)

```
for Country in Portfolio:
   for PositionID in Portfolio:
      <compare all Country + all PositionID>
```

Max complexity: $O((count_{position})^{nestingLevel})$

## `where <x>`/`for all { if <x> }` equivalence

Consider that the following two expressions are equivalent. An `if` in a `for all` becomes a `where` in a `group by`:

### `for all`

```
let issuers = Portfolio grouped by IsserName
for all issuers:
    if DirtyValue of IsserName > 10% {
        count issuers >= 5
    }
```

### `group by`

```
let issuersGt10Pct = Portfolio grouped by IsserName: where DirtyValue of IsserName > 10%
for all issuersGt10Pct:
    count issuers >= 5
```



### Begrænset nested iteration (`group by`?)

```
for Country:
   for PositionID:
      <compare Country with PositionID of that country>
```

Max complexity: $O((count_{position})*{nestingLevel})$

## *Position* versus *group* comparisons

* *Comprehension syntax* support
* Problems with "group by" field in question and then filter off
  * Extra groupings may split relevant group in two

## Implementation improvements

### Parser

Tokenize input before parsing. Advantage: better error messages because the parser works on the "keyword"-level instead of character-level. Ex.:

```
pNot> IN: "(InstrumentType == "GovernmentBond" OR  <…>
pNot> unexpected "(In"
pNot> expecting "NOT"
```

### Variable shadowing not supported

Evaluator does not support it —> simplifying design choice







