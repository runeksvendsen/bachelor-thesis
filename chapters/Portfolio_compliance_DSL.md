# Portfolio compliance DSL

## Requirements analysis

In this section the [example rules](#compliance-rule-examples) are analyzed in order to derive requirements for the portfolio compliance DSL.

### Example rules

#### General

**TODO:** *Comparison between property values:*

* All properties can be compared for *equality*
* Some properties (e.g. *value*) can be compared for *order* (less than, greater than) as well as supporting *addition*

**TODO:** table/"feature-matrix" list the features (below) required by each rule

#### Rule I

1. **Grouping:** by some property *name* so that each group contains all the positions that have the same property *value*
2. **Logical *and***: when a single rule is composed of two or more sub-rules then both sub-rules must apply
3. **For all**: apply a rule for each group that results from a grouping
4. **Group property/summing over groups**: the sum of the values of some property for all the positions in a group
5. **Group filtering:** removing certain *groups* by some condition ("*relative value < 5%*")
6. **Summing over multiple levels of groups**: same as *4.* but grouping of another grouping (*total aggregate value of remaining groups*)

#### Rule II

1. **Counting distinct property values** for some property name. This can be considered the same as first grouping by the given property name, and then counting the number of groups that result from this. In other words, here we can reuse the idea of *grouping by a property name*, and only introduce the new concept of *counting the number of groups*.
2. **Conditional rule application**: the part "*whose relative value is greater than 30%*" requires that a particular rule is applied only if the given condition is true

#### Rule III

1. **Double grouping**: first group by *issuer* then group all *issuer*-groups by *issue*

#### Rule IV

1. **Positions filtering:** removing certain *positions* by some condition ("*remove all but OTC-positions*")

#### Rule V

**TODO:** handle remaining rules

#### Rule VI

**TODO:** handle remaining rules

### Grouping data structure

**Spørgsmål til Peter:** *er dette afsnit det rette sted? Eller er valget af en træ-datastruktur implementations-specifik, og ikke som sådan et krav/requirement for sproget?*

From the above analysis it is clear that the concept of a *grouping* is required. In addition, [Rule III](#rule-iii) shows that — when grouping an *issuer*-group by *issue* — an existing grouping can be grouped once again, thus creating multiple levels of groupings. Due to these requirements *(**TODO:** nævn SimCorp/spørg Martin)* a tree has been chosen to describe a grouping.

The following figure shows the simplest grouping of them all — a portfolio. This portfolio contains the positions $P1$ through $P8$.

![Tree data structure for an ungrouped portfolio](./figurer/grouping_portfolio.png){#fig:grouping_portfolio}

This is represented as a tree with a single non-leaf node (depicted as round), under which a leaf node (depicted as square) is present for each position in the portfolio (named $P1$ through $P8$ in the above figure). A position is thus represented as a leaf node in a tree, where each non-leaf node represents a group.

The figure below depicts the tree that results from grouping the above portfolio ([@fig:grouping_portfolio]) by *country*.

![Tree data structure for a portfolio grouped by country](./figurer/grouping_country.png){#fig:grouping_country}

A node for each distinct value of the *country* field is created as children of the parent portfolio-node. This example portfolio contains positions from three different countries: Denmark (*DK*), United States (*US*), and Great Britain (*GB*). Under these new nodes, the positions — whose *country* field is equal to the value in the given node — are present as leaf nodes.

The figure below depicts the tree that results from grouping by *issuer* the above country-grouping ([@fig:grouping_country]).

![Tree data structure for a portfolio grouped by country and then by issuer](./figurer/grouping_isser.png){#fig:grouping_issuer}

When the existing country-grouping is grouped again by issuer, we see that another level of nodes is added below the country-level. This level contains a node for each issuer (named `I1` through ​`I5` in the above example).

## Language design

### Design choices

#### Input data format

The input data is preprocessed such that the rule language does not need to perform transformations, such as converting between different currencies (in order to have a common/reference measure of value). It is thus assumed that the input data contains a measure of value that is comparable between positions, even though these positions may be denominated in different currencies.

The input data format for a position is assumed to be a map *from* a **string** field name *to* one of: a **floating point number**, a **string**, or a **boolean**. *Null* values are not supported, but a position may omit fields. In this way, positions representing e.g. *commodity futures* can have a field called `UnderlyingCommodity` — whereas other position types (e.g. *bonds*) can omit this field.

#### Rule input

All example rules operate on a portfolio. That is, for the purpose of evaluating whether a portfolio complies with a rule, none of the example rules require any input other than the portfolio in question. Consequently, it has been chosen that all rules operate on an implicit input, present in a variable by the name of `Portfolio`. This simplification may need to be reconsidered in future versions of the language (see [Future work/input arguments](#input-arguments)).

### Overview {#sec:language-design-overview}

The DSL supports the following operations

1. **Grouping**
   1. Grouping by some property
   2. Filtering groups/positions based on a *comparison*
2. **Calculation on a grouping**
   1. Calculating the sum/average/minimum/maximum for a particular field for all positions in a grouping
   2. Counting the number of groups in a grouping
   3. Calculating a percentage by relative comparison of two of the above
3. **Comparison**
   1. Boolean comparison of equality and order (greater/less than) between the result of a calculation and/or a constant
   2. *Boolean logic* comparison (*and/or/not*) between two boolean comparisons
4. **Defining compliance rules**
   1. Variable binding of a *grouping*, *calculation*, *comparison*, or constant
   2. Defining a compliance rule using a boolean value
   3. *If*-statements
   4. Iteration over a grouping

#### Grouping {#syntax-grouping}

A grouping/filtering operation takes as input an existing grouping and either groups it (by a property name) or removes positions based on a condition. For example, `Portfolio grouped by Country where sum .Value of Country relative to Portfolio >= 10%` first groups a portfolio by country and then removes the countries whose value relative to the portfolio is less than 10%.

#### Calculation on a grouping

A calculation transforms a grouping into a number. For example: `sum .Value of Portfolio` calculates the sum of the `Value` field for all positions in the `Portfolio` grouping, while `count (Portfolio grouped by Country)` calculates the number of distinct countries in the `Portfolio`.

A calculation may be a reduction of a particular property of all the positions in a grouping to a value (*sum/average/minimum/maximum*). For example, the *sum* calculation using the `Exposure` property, performed on some grouping, takes the value of the `Exposure` property for all positions in the grouping and returns the sum.

A calculation may also be a count of the number of groups in a grouping. For example, a *count* on `Portfolio grouped by Country` returns the total number of `Country` groups, while a count on `Portfolio grouped by Country grouped by Sector` returns the total number of `Sector` groups. Thus, a count performed on the grouping in [@fig:grouping_country] returns $3$, and it returns $5$ for the grouping in [@fig:grouping_issuer].

Lastly, a relative comparison between two of the above can be performed, resulting in the relative size of the left argument to the right argument in percent. For example, comparing the two constants $7$ and $10$ — using the concrete syntax `7 relative to 10` — returns $70\%$.

#### Comparison

The result of a calculation and a constant can be compared against each other. A comparison consists of a) the two values to be compared, and b) the *comparison operation*, which tests for any combination of equality and greater/less than (`==`, `!=`, `<`, `>`, `<=`, `>=`). For example, the comparison `sum .Value of Country < 100000`) is a comparison between `sum .Value of Country` and the constant `100000` using the comparison operation *less than*. The *condition* in the example above in [Grouping](#syntax-grouping) (`Portfolio grouped by Country where sum .Value of Country relative to Portfolio >= 10%`) above is also a comparison, specifically between the two values `sum .Value of Country relative to Portfolio` and `10%` using the *greater than or equal* comparison operation.

The result of a comparison is a boolean value that can be used as input to any combination of logical *and/or/not*.

#### Defining compliance rules

Compliance rules are defined using a combination of variable definitions, if-statements, iterations and actual rule requirements:

```rulelang
let portfolioBonds = Portfolio where .InstrumentType == "Bond"
let countryBonds = portfolioBonds grouped by Country
forall countryBonds {
   let countryBondValue = sum .Value of Country relative to portfolioBonds
   require countryBondValue <= 10%
   if countryBondValue > 15% {
      require count (Country grouped by .Issuer) >= 8
   }
}
```

The above compliance rule that has two requirements for *bonds* in a portfolio. For each country: 1) the value of bonds from that country relative to all bonds in the portfolio must be at most 10%, 2) if this relative value is greater than 15% then the bond positions for that country must be composed of at least 8 different issuers.

The `let` keyword defines a variable, where the right-hand side may be either a grouping, a calculation, a comparison or a constant.

Groupings can be iterated over. Iterating over e.g. `Portfolio grouped by Country grouped by Issuer` (using the `forall` keyword) will execute the body of the iteration (inside the curly braces) for all country/issuer combinations, each time with the `Country` and `Issuer` variables bound to a different combination.

A rule requirement is preceded by the `require` keyword, followed by an expression that must be true.

*If*-statements work as in any other language. **Spørgsmål til Peter:** bør jeg uddybe *if*-statements?

### Concrete syntax

The constructs of the language can thus be divided into two kinds: **1)** expressions (*grouping*, *calculation*, and *comparison*) which evaluate to a value; and **2)** statements (`require`, `forall`, `if`) which *do not* evaluate to a value, but rather take values/expressions as input.

#### Expressions

Test blah blah. Table:

\begin{footnotesize}
\begin{center}
   \begin{tabular}{ | l l l | }
      \hline
​      \textbf{Expression}        & \textbf{Meaning} & \textbf{Associativity} \\
​      \hline
​      \textit{literal}           & A \textit{string}, \textit{number}, \textit{boolean}, \textit{percentage}, or \textit{field name}  &       \\
​      \textit{variable}          & A variable name                                                                                    &       \\
​      \hline
​      \texttt{e1 grouped by e2}  & Add a group to a grouping                                                                                & left  \\
​      \texttt{e1 where e2}       & Filter a grouping                                                                                    & left  \\
​      \hline
​      \texttt{e1 of e2}          & \textit{map} each position in a grouping into a field value                                                             & none  \\
​      \hline
​      \texttt{count e}           & Count the number of groups in a grouping   &        \\
​      \texttt{sum e}             & \textit{Sum} of field values in a grouping        &        \\
​      \texttt{average e}         & \textit{Average} of field values in a grouping    &        \\
​      \texttt{minimum e}         & \textit{Maximum} of field values in a grouping      &        \\
​      \texttt{maximum e}         & \textit{Minimum} of field values in a grouping      &        \\
​      \hline
​      \texttt{e1 relative to e2} & Relative comparison          & left    \\
​      \hline
​      \texttt{e1 > e2}           & Greater than                 & none    \\
​      \texttt{e1 < e2}           & Less than                    & none    \\
​      \texttt{e1 >= e2}          & Greater than or equal        & none    \\
​      \texttt{e1 <= e2}          & Less than or equal           & none    \\
​      \hline
​      \texttt{e1 == e2}          & Equals                        & none    \\
​      \texttt{e1 != e2}          & Does not equal                    & none    \\
​      \hline
   \end{tabular}
\end{center}
\end{footnotesize}


#### Statements

Statements are separated by one or more newlines. A statement is one of the following: *let-binding*, *rule requirement* (`require`), *grouping iteration* (`forall`), *if-statement*, or *block statement*.

##### Block statement

A *block statement* is composed of zero or more *statements* enclosed in curly braces:

```
{
   statementA
   statementB
   statementC
}
```

##### Let-binding

A let-binding has the form `let <ident> = <expr>`.  `<ident>` is the variable name, which is a text string starting with a single lower-case letter followed by zero or more numbers or upper/lower case letters. `<expr>` is an expression (see [@TODO] below).

##### Rule requirement

A rule requirement has the form `require <boolExpr>`, where `<boolExpr>` is an expression that evaluates to a boolean — that is, either a comparison expression (see [@TODO] ) or a variable assigned to a comparison expression.

##### Grouping iteration

A grouping iteration has the form `forall <groupingExpr> <blockStatement>`.

#### Example rules

##### Rule I

[Rule I](#rule-i) expressed in the proposed DSL looks as follows:

```java
let issuers = Portfolio grouped by .Issuer
forall issuers {
   require sum .Value of Issuer relative to Portfolio <= 10%
}
let issuersAbove5Pct = issuers where (sum .Value of Issuer relative to Portfolio > 5%)
require sum .Value of issuersAbove5Pct <= 40%
```

The first line groups the portfolio positions by issuer, and binds this grouping to the variable `issuers`, so that it can be reused in the two sub-rules (lines 2-4 and line 5-6, respectively) that comprise this rule.

The `forall` keyword on line 2 starts an iteration, with the effect that the single line within the curly braces (line 3) is executed for each *issuer*-group in the `issuers`-grouping — each time with a different group bound to the `Issuer` variable. The `require`-keyword establishes a condition that must be true.

Line 5 performs a filtering on the grouping inside the `issuers` variable, as required by the rule, and binds this to the variable named `issuersAbove5Pct`. Finally, on line 6, the requirement of the second sub-rule is asserted.

##### Rule II

[Rule II](#rule-ii) looks as follows:

```java
let issuers = Portfolio grouped by .IssuerName
forall issuers {
   let issuerValue = sum .Value of IssuerName relative to Portfolio
   require issuerValue <= 35.0%
   let issueCount = count IssuerName grouped by .IssueID
   if issuerValue > 30% {
      require issueCount >= 6
   }
}
```

As the first two lines are identical to the previous rule, we start at line three, in which the value of an issuer (relative to the portfolio value) is bound to the variable `issuerValue`. Line number four asserts that this is less than or equal to 35% for all issuers.

On line five the number of issues for the current issuer is bound to the variable `issueCount`. This variable is then used in the line below — line six — in a conditional statement that asserts that if the value of the issuer is *not* less than or equal to 30%, then the issue count must be greater than or equal to six.

##### Rule III

[Rule III](#rule-iii) looks as follows:

```java
let govtSecurities = Portfolio where (.InstrumentType == "GovernmentBond" OR .InstrumentType == "StateBond")
forall govtSecurities grouped by .Issuer {
   let issuerValue = sum .Value of Issuer relative to Portfolio
   if issuerValue > 35% {
      let issues = Issuer grouped by .Issue
      require count issues >= 6
      forall issues {
         require sum .Value of Issue relative to Portfolio <= 30%
      }
   }
}
```

The first line binds the positions from the portfolio that are not either government bonds or state bonds to the variable `govtSecurities`. Note that the data format here — namely, that positions which are state/government bonds have a field by the name of `InstrumentType` that is equal to `"StateBond"` and `"GovernmentBond"`, respectively — is used as an example only (the DSL does not specify the field names/contents for the input data).

On line number two, the above-created variable is grouped by Issuer and iterated over. Line three binds the relative value of the issuer to the variable `issuerValue`. Line four introduces the conditional that the rule requires: only if the relative value of the issuer is greater than 35% should the issue count and issue value be checked.

##### Rule IV

[Rule IV](#rule-iv) looks as follows:

```java
let otcPositions = Portfolio where (.InstrumentType == "OTC")
let nonApprovedCounterparties = otcPositions where (.Counterparty == "SmallCompanyX" OR .Counterparty == "SmallCompanyY" OR .Counterparty == "SmallCompanyZ")
let approvedCounterparties = otcPositions where (.Counterparty == "HugeCorpA" OR .Counterparty == "HugeCorpB" OR .Counterparty == "HugeCorpC")
forall nonApprovedCounterparties grouped by .Counterparty {
   require sum .Exposure of Counterparty relative to Portfolio <= 5.0%
}
forall approvedCounterparties grouped by .Counterparty {
   require sum .Exposure of Counterparty relative to Portfolio <= 10.0%
}
```

**TODO** explain


### Rule evaluation

This section describes how a portfolio compliance rule is evaluated to a boolean, with *false* meaning one or more requirements have been violated and *true* meaning no requirements have been violated. This evaluator is simplified, in order to lower complexity, and will fail in case of any of the following:

* Any form of type error, e.g.:
  * A comparison of two incompatible values: e.g. a *string* and a *number*
  * Applying an operator to a variable of an incorrect type, e.g.:
    * `if` or `require` applied to a non-boolean
    * `count` applied to anything but a grouping
* A reference to a variable that does not exist
* A position that does not contain the specified field name

#### Expression evaluation summary

The table below summarizes the type of the input argument(s) and the result type of the prefix and infix operators described in [@TODO].

\begin{footnotesize}
\begin{center}
   \begin{tabular}{ | l l l | }
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \textbf{Expression}        & \textbf{Argument type(s)}           & \textbf{Result type}         \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 grouped by e2}  & \textit{position-grouping}, \textit{field name}          & \textit{position-grouping}   \\
      \texttt{e1 where e2}       & \textit{position-grouping}, \textit{comparison}          & \textit{position-grouping}   \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 of e2}          & \textit{field name}, \textit{position-grouping}          & \textit{field value-grouping}  \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{count e}           & \textit{grouping}                               & \textit{number}       \\
      \texttt{sum e}             & \textit{number-grouping}                        & \textit{number}       \\
      \texttt{average e}         & \textit{number-grouping}                        & \textit{number}       \\
      \texttt{minimum e}         & \textit{number-grouping}                        & \textit{number}       \\
      \texttt{maximum e}         & \textit{number-grouping}                        & \textit{number}       \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 relative to e2} & \textit{number}, \textit{number} or \textit{percentage}, \textit{percentage}     & \textit{percentage}    \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 > e2}           & \textit{number}, \textit{number} or \textit{percentage}, \textit{percentage}     & \textit{boolean}    \\
      \texttt{e1 < e2}           & \textit{number}, \textit{number} or \textit{percentage}, \textit{percentage}     & \textit{boolean}    \\
      \texttt{e1 >= e2}          & \textit{number}, \textit{number} or \textit{percentage}, \textit{percentage}     & \textit{boolean}    \\
      \texttt{e1 <= e2}          & \textit{number}, \textit{number} or \textit{percentage}, \textit{percentage}     & \textit{boolean}    \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 == e2}          & \textit{string}, \textit{string}                                                 & \textit{boolean}    \\
      \texttt{e1 != e2}          & \textit{string}, \textit{string}                                                 & \textit{boolean}    \\
      \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   \end{tabular}
\end{center}
\end{footnotesize}


#### Runtime values

The evaluator needs to represent three kinds of values at runtime:

1. A constant: *number*, *string*, *boolean*, *property name*, and *percentage*
2. A `Position` type (since a rule is applied to a set of positions)
3. A `Tree` type, which describes the result of evaluating a grouping

##### Literals

A constant value is used to hold all literals present in the given rule. Also, a constant is the result of evaluating both a comparison and a calculation on a grouping. The evaluation of these two expression types is described below.

##### `Position`

A position is represented at runtime as a value of the `Position` type, which is a map from a property name to a value of type *number*, *string*, or *boolean*.

##### Tree

The `Tree` data type is an implementation of the [Grouping data structure](#grouping-data-structure). Its definition as a Haskell sum type looks as follows:

```haskell
data Tree leafLabel
    = Node (NodeData [Tree leafLabel])
    | TermNode (NodeData leafLabel)

data NodeData a = NodeData (FieldName, FieldValue) a
```

`NodeData` contains information about a particular group. It contains the *field name* of the group (e.g. *Country*) as well as the value of that field for this particular group (e.g. *"DK"*).

A `Tree` value is either a:

1. *terminal node* (`TermNode`) containing a single value of type `leafLabel` (and a `NodeData`), or
2. a *non-terminal node* (`Node`) containing zero or more sub-trees (and a `NodeData`)

Thus, the example portfolio grouped by country ([@fig:grouping_country]) — using strings in place of positions — represented using this tree type — is:

```
Node $ NodeData ("Portfolio","")
    [ TermNode $ NodeData ("Country", "DK") ["P7"]
    , TermNode $ NodeData ("Country", "US") ["P2", "P3", "P5", "P8"]
    , TermNode $ NodeData ("Country", "GB") ["P1", "P4", "P6"]
    ]
```

That is, the tree contains a root node with a *field name* of "Portfolio" and a field value of the empty string. And then, for each country, a terminal node containing the *field name* "Country" and the *field value* of that particular country, as well as a list of the positions under this terminal node.

The tree used by the evaluator to represent position groupings at runtime is thus of type `Tree [Position]`. That is, every terminal node in the tree contains zero or more positions. The type-variable `leafLabel` is present in order to more easily support the above example (using strings in place of positions), as well as coming in handy when the variable environment for a `forall`-iteration is created (see section [`forall`-evaluation](#forall-evaluation) below).

#### Let-binding/variable reference

The variable environment consists of a non-empty list of name/runtime value pairs. Variables are looked up starting from the first item in the list. Thus, the following code:

```
let a = 7
let b = "hello"
let a = false
require …
```

Executes `require …` inside an environment with `a` bound to **false** and `b` bound to **"hello"** (thus shadowing the definition of `a` on the first line).

The initial variable environment contains a single item which pairs the name "Portfolio" with the `Tree` that contains the positions of the portfolio. Thus, all expressions operate on the `Portfolio` variable, and/or user-defined constants and variables.


As in languages such as C or Java, variables defined inside a code block — surrounded by curly braces (`{}`) — only have scope within this block. This, then, applies to the body of a `forall` iteration and the body of an `if`-expression, since these are the only two expressions that contain a code block.

Lastly, a `forall` iteration creates in-scope variables for each grouping in the input grouping, and executes the body once for each of these groupings — each time with a different tree bound to the group names (e.g. `Country` and `Issuer`). See further details in the section [`Forall`-evaluation](#forall-evaluation) below.

#### Grouping expression

A *grouping expression* applies one or more groupings and/or filterings to an input tree. It evaluates to a new tree with either a new level of terminal nodes added to the bottom of the tree (in case of a grouping), or zero or more positions removed from the terminal nodes of the tree (in case of a filter).

##### Grouping {#eval-grouping}

The figure below depicts the input and output tree of each operation in the grouping expression `Portfolio grouped by Country grouped by Issuer`.

![Portfolio grouped first by Country then by Issuer](./figurer/grouping_expression.png){#fig:grouping_expression}

The leftmost tree is bound to the variable `Portfolio`. Next, the `grouped by Country` operation takes `Portfolio` as input and produces the tree shown in the middle — which contains a group for each country: Great Britain (GB), Denmark (DK), and the United States (US). After that, `grouped by Issuer` takes as input the middle tree and produces the rightmost tree — adding a terminal node for each distinct issuer for that country under each country node.

##### Filtering

A filter removes zero or more positions from each terminal node, and does not modify anything else about the tree. A comparison inside a filter operation applies to either a position or a group:

* **Position comparison: **`x where (.InstrumentType != "Bond")` removes from all terminal nodes in `x` the *positions* whose `InstrumentType` property equals `"Bond"`.
* **Group comparison:** `y where (sum .Value of Country < 10000000)` removes a *node* (group) from the *Country*-level of the tree if the sum of the `Value` field for all positions below this node is less than 10 million.

Thus, a position comparison evaluates to a boolean for each *position* (in a group), while a group comparison evaluates to a boolean for each *group*. As described above, when a position comparison is used as a filter condition (`where`) in a grouping expression, the positions for which the expression evaluates to **false** are removed, while the rest are kept. However, when used in either a rule (`require`) or the right-hand side of a let binding, a "for all" is implicit in a position comparison. Thus, e.g. `let a = .InstrumentType == "Bond"` evaluates to true only if the `InstrumentType` property equals `"Bond"` for all positions in the group with the innermost scope (**TODO: see scope definition**).

A standalone position comparison — i.e. one not used inside a logical *and/or* between a group comparison — can be moved out to the top-level, meaning it can be applied to the Portfolio that is used as input to the grouping expression that contains this standalone position comparison. For example, the grouping expression `z grouped by Country where (.Counterparty != "US Government")` is equivalent to `z where (.Counterparty != "US Government") grouped by Country`.

#### Calculation

**Spørgsmål til Peter:** jeg synes allerede jeg har beskrevet dette under Overview/Calculation on a grouping. Synes du der burde være noget her der uddyber dette?

#### Comparison

**Spørgsmål til Peter:** samme som ovenstående. Jeg føler ikke jeg har det store at tilføje sammenlignet med samme sektion i Overview.

#### Core rule language

##### `forall` evaluation

As mentioned in the [Overview](#language-design-overview) section ([@sec:language-design-overview]), a `forall` expression is evaluated by evaluating its body for all combinations of groups **TODO**.

In practice, this means that the evaluator needs to create one variable environment for each terminal node. Each of these variable environments will contain:

1. The terminal node's group name bound to the tree starting at that particular terminal node — e.g. the name *Issuer* bound to the tree starting at the $I5$ terminal node (see [@fig:eval-forall-env] below)
2. The group names of the nodes *above* the terminal node bound to the tree starting at that particular node (if any) — e.g. (in [@fig:eval-forall-env] below) *Country* bound to the tree starting at the $US$ node, and *Portfolio* bound to the tree starting at the root node

[@Fig:eval-forall-env] below adds a variable environment (depicted as a rounded, red rectangle) to all terminal nodes of [@fig:grouping_issuer]. The arrow describes a binding in the variable environment, with the left-hand side being the variable *name* and the right-hand side the *value* that this variable is bound to (which is a tree in the below example). Also, a tree is referred to as the label of its root node. Thus, for example, *Country* → **US** describes a binding of the variable name *Country* to the tree starting at the node with the label $US$.

![Tree with variable environments as leaf nodes](./figurer/eval-forall-env.png){#fig:eval-forall-env}

This variable environment is merged with the existing variable environment (for the code block that contains the `forall`), such that variable names in the existing variable environment are overwritten in case of duplicate variable names. Also, the binding of the *Portfolio* variable to the tree starting at the root node is not included in the environment, since this is already defined in the existing variable environment. ~~Note, however, that if this were the case it would make no difference, as the effect would be to overwrite~~



## Implementation

### Abstract syntax

#### Haskell sum types

The following subsections describe the abstract syntax of the language using Haskell *sum types*. A Haskell sum type defines a *type* as well as multiple values — possibly containing other values — that are all of the given type. Thus, the definition `data Color = Red | Green | Blue`{#haskell} defines the *type* `Color` and the values `Red`, `Green`, `Blue` (of type `Color`). The defined values can also contain data, which is specified using one or more *types* after the value name. Thus, `data PersonInfo = AgeYears Int | WeightKilogram Float | FirstLastName String String`{#haskell} defines three values of type `PersonInfo` containing, respectively, age (integer), weight in kilograms (floating point value), and first and last name (two strings).

Haskell sum types may be recursive, meaning that the values of a newly defined type may contain values of its own type, such that `data IntList = Empty | ItemAndRest Int IntList `{#haskell} defines a integer list type that is either empty or contains a single integer plus another integer list (that, again, may be empty or contain a single integer plus another integer list). Lastly, a sum type can contain values of any type if it adds this type as a *type parameter*. For example, `data Maybe a = Some a | Nothing` defines a type `Maybe a` that is either empty (in the case of the `Nothing` value) or contains a value of type `a` (in the case of the `Some` value). A value of type `Maybe Integer` can only contain a value of type `Integer`, a value of type `Maybe String` can only contain a `String`, and so on.

#### Literals {#abstract-literals}

Literals are constants entered by the user.  A `FieldName` is the name of a property in a position. A `FieldValue` is the value of a property. The `Percent` type is used for relative comparisons — a comparison between two [*value expressions*](#value-expression).

A `FieldValue` can be one of three types: *number*, *string*, or *boolean*. The implementation uses `Double` to represent numbers, but other types may be used if, for example, precision is more important than speed.

```
data Literal
    = Percent Number
    | FieldName Text
    | FieldValue FieldValue

data FieldValue
    = Number Double
    | String Text
    | Boolean Bool
```
#### Variable or expression (`VarOr`)

For many values in the abstract syntax, only a particular input value makes sense. For example, some expressions require a *grouping* as input, hence they do not make sense applied to any other input. However, since all values can be bound to variables, we need to also enable an expression to take a variable as input. This is what the `VarOr` data type is used for. A `VarOr a` is either a variable name (which points to a variable that must contain an expression of type `a`) or an actual expression of type `a`.

```
data VarOr a
    = Var Text
    | Expr a
```

#### Value expression

A *value expression* (`ValueExpr`) represents either:

* a count on a group (`count` keyword)
* a combined fold and map on a group (e.g. `sum .Value of …`)
* a relative comparison between two value expressions (separated by the `relative to` keyword)

For example, the concrete syntax `sum .Value of Country relative to Portfolio` —  the value of the group *Country* relative to the value of the portfolio — is represented as `Relative (Expr (FoldMap Sum (Expr ".Value") (Var "Country"))) (Expr (FoldMap Sum (Expr ".Value") (Var "Portfolio")))` in abstract syntax. The abstract syntax is thus a bit more verbose in some cases, with the benefit of allowing more complex relative comparisons (e.g. `average .Exposure of Issuer relative to .Value of Country`).

```haskell
data ValueExpr
    = GroupCount (VarOr DataExpr)
    | FoldMap Fold (VarOr FieldName) (VarOr DataExpr)
    | Relative (VarOr ValueExpr) (VarOr ValueExpr)

data Fold
    = Sum
    | Average
    | Max
    | Min
```
#### Boolean expression

A *boolean expression* (`BoolExpr`) is either two value expressions compared for equality or order (less/greater than), a negation of another boolean expression, or logical *and/or* between two boolean expressions.

In order to simplify the pretty-printer, the `BoolCompare` type contains all combinations of equality and order comparisons. In principle, it would be sufficient to have only `Eq` and either `Lt` or `Gt`, which could then be combined using `Or` and `Not` to produce the remaining comparisons — e.g. `a <= b` would be expressed as `Or (Comparison (Var "a") Lt (Var "b")) (Comparison (Var "a") Eq (Var "b"))`{#haskell}.

```haskell
data BoolExpr
    = Comparison (VarOr VarExpr) BoolCompare (VarOr VarExpr)
    | And (VarOr BoolExpr) (VarOr BoolExpr)
    | Or (VarOr BoolExpr) (VarOr BoolExpr)
    | Not (VarOr BoolExpr)

data BoolCompare
    = Eq   -- equals
    | NEq  -- does not equal
    | Lt   -- less than
    | Gt   -- greater than
    | LtEq -- less than or equal
    | GtEq -- greater than or equal
```
#### Grouping expression

A *grouping expression* is modelled as a `DataExpr`:

```
data DataExpr
    = GroupBy (VarOr FieldName) (VarOr DataExpr)
    | Filter BoolExpr (VarOr DataExpr)
```

The grouping expression `Portfolio where (.InstrumentType == "OTC") grouped by .Counterparty` thus looks as follows in abstract syntax:

```haskell
GroupBy
  (Expr ".Counterparty")
  (Expr
     (Filter
        (Comparison
           (Expr (Literal (FieldName ".InstrumentType")))
           Eq
           (Expr (Literal (FieldValue (String "OTC")))))
        (Var "Portfolio")))
```

#### Variable expression
**TODO**
```
data VarExpr
    = Literal Literal
    | ValueExpr ValueExpr
    | BoolExpr BoolExpr
    | DataExpr DataExpr
```
#### Rule expression
**TODO**

```
data RuleExpr
    = Let Text VarExpr
    | Forall (VarOr DataExpr) [RuleExpr]
    | If (VarOr BoolExpr) [RuleExpr]
    | Rule (VarOr BoolExpr)
```

#### Examples rules

**TODO:** example rules in abstract syntax

### Pretty-printer

#### Literals

**TODO:** *Percent*, *FieldName*, *FieldValue (Number, String, Bool)*

#### Variables

**TODO:** Let-bindings versus `forall`-loop

#### *Group operation* (fold/count)

**TODO**

#### *Value* expressions

**TODO:** Literal or GroupOp

#### Comparison

**TODO:** compare two value expressions using a *BoolCompare*

#### *Boolean* expression

Either a *comparison*, or NOT/AND/OR on a *boolean* expression (recursive)

#### *Data* expression

**TODO:** one or more successive GroupBy/Filter on initial *DataExpr*

### Parser

#### Keywords

**TODO**

* `let`
* `forall`
* `AND`
* ...

**TODO:** <indsæt `megaparsec`-parser kode>

#### Note: pros/cons of parser combinators

https://blog.josephmorag.com/posts/mcc1/#headline-7


### Testing of pretty-printer/parser

***NB: ikke færdiggjort endnu***

Brug af *property-based testing* til at checke at outputtet af pretty-printeren kan parses af parseren, og at outputtet fra parseren er det samme som inputtet til pretty-printeren. Altså at for en given abstrakt syntaks `absyn` så gælder det at `parse(prettyPrint(absyn)) == absyn`. Til dette bruges Haskell-biblioteket `smallcheck` (https://hackage.haskell.org/package/smallcheck).

### Limitations/not implemented

* Parser-error messages contain no source information
  * Fix: put source code + line/column span inside `RuleExpr` and subtypes.
