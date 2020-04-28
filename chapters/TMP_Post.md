# Future work

## Type system

**TODO:** A type system can help reject invalid rules before evaluation is attempted.

## Input arguments

Generalize a rule by taking e.g. a, otherwise hardcoded, percentage as input, so tat rule becomes e.g. "no more than x% in bonds".

**Maybe:** hard-coded constants, also: approved versus non-approved creditors (anther possibility: define via function that's imported from elsewhere — input data vs. code)

## Let-binding of functions

The definition of what constitutes e.g. a "government security" is composed of several logical *or*s between comparisons of the field `InstrumentType` and some string, e.g.: `.InstrumentType == "GovernmentBond" OR .InstrumentType == "StateBond" OR .InstrumentType == "TreasuryBill" OR .InstrumentType == "StateBill"`. Adding the ability to factor out this logic into a function `isGovernmentSecurity p = p.InstrumentType == "GovernmentBond" OR p.InstrumentType == "StateBond" OR p.InstrumentType == "TreasuryBill" OR p.InstrumentType == "StateBill"` reduces duplication in the rule definition, as this logic can be defined once and used multiple times in the rule.

## User-defined folds

A *fold* (also called *reduce*) expression that takes as input:

1. A *collection* (e.g. list, set, tree) containing *item*s
2. An *initial state*
3. A *combining function*, that takes as input **a)** an item from the collection, and **b)** the current state, and returns a new state

Evaluating a fold expression starts by applying the combining function to the first item of the collection and the initial state, in order to obtain a new state. This is then repeated using the second item in the collection and the new state, and so on. The fold expression evaluates to the state that has been accumulated after applying the combining function to the last item in the collection.

For example, the sum of a list of numbers can be expressed as a fold, where the initial state is the number zero, and the combining function is the addition function. In this case the state and the collection item are of the same type (*number*).

E.g. `sum`, `average`, `maximum`, `count` should not be built into the language. These should be defined using a separate language (structural recursion over sets) and imported by rules.

This allows experts to define primitives, so that the language doesn't have to be changed if a rule needs to calculate e.g. the *median* value of a list of values.

In practice these functions are a fold over a tree that contains groupings of portfolio positions (Chapter 7 of [1]).

### Concrete syntax 

* Can/should we permit defining custom concrete syntax for the user-defined folds?
  * E.g. the `relative to` construct is a form of infix function that can compare two other folds
    * `relativeTo foldA foldB = ...` 
  * `sum <Fieldname> of <Input>`
    * [Agda Mixfix operators](https://agda.readthedocs.io/en/v2.5.2/language/mixfix-operators.html)?

## Deriving data schema from rule

The requirements for field names and field types can be statically derived from a rule, by looking at:

1. References to field names 
2. The operations performed on the field values
   3. 	E.g. a `sum` operation on the contents of a particular field means that the field value must have a number type

## Grouping visualizations

Visualisering af den underdel af det abstrakte syntaks som beskriver grupperinger/filtrering af data vha. en såkaldt *Sunburst* chart — se **Figure 3** i artiklen [An evaluation of space-filling information visualizations for depicting hierarchical structures](https://www.cc.gatech.edu/~john.stasko/papers/ijhcs00.pdf).

![Sunburst chart of grouping by Country and Issuer](./figurer/grouping.png)

# Conclusion
TODO

# Appendix

## A.1

**TODO** *David's rules*

## A.2

**TODO:** insert pretty printer Haskell code

**TODO:** refer to here in *Pretty-printer* section
