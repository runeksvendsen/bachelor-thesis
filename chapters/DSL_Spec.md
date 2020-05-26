\newpage
# Language specification

This section contains a specification of the syntax and semantics of the compliance rule-DSL, as well as a description of a simple, boolean evaluator for the language.

## Syntax and semantics {#sec:language-design-overview}

The constructs of the language can be divided into two kinds: **(1)** expressions, which evaluate to a value; and **(2)** statements, which *do not* evaluate to a value (but take values/expressions as input).

An expression is one of the following:

1. **Literal**
   1. Property value (number/string/boolean)
   2. Property name
   3. Percentage
2. **Grouping**
   1. Grouping by some property name
   2. Filtering of groups/positions based on a *comparison*
3. **Calculation**
   1. Calculating the sum/average/minimum/maximum for a particular property for all positions in a grouping
   2. Counting the number of groups in a grouping
   3. Calculating a percentage by relative comparison between two of the above (or a literal)
4. **Comparison**
   1. Boolean comparison of equality and/or order (greater/less than) between the result of a calculation and/or a constant
   2. *Boolean logic* comparison (*and/or/not*) between two comparisons

A statement is one of:

1. Variable binding of a *grouping*, *calculation*, *comparison*, or *literal*
2. Rule requirement
3. *If*-statement (for conditional rule requirements)
4. Iteration over a grouping (for applying rule requirements to all groups in a grouping)

### Expression {#sec:spec-expression}

This section describes the syntax and semantics of expressions.

#### Literal {#sec:expression-literal}

A literal is either a property *name*, a property *value*, or a percentage.

As described in section \ref{sec:input-data-format}, a position contains multiple named properties. Examples of property names — taken from the example rules in \ref{sec:compliance-rule-examples} —  include *value*, *issuer*, *issue*, *instrument type* (with a value of e.g. "public security" as in Rule III sec. \ref{sec:bg-rule-iii}), *counterparty*, *security id* (Rule V sec. \ref{sec:bg-rule-v}), and *country*. The syntax for a property name literal is a period (`.`) followed by a capital alphabetic letter followed by zero or more alphanumeric characters. Thus, written in the syntax of the DSL, the property names from the example rules become e.g. `.Value`, `.Issuer`, `.InstrumentType`, and `.SecurityID`.

A property value is either a number, a string, or a boolean.   The number type supports both floating point numbers and integers, so that the two number literals `42.0` and `42` are equivalent. Strings are surrounded by double quotes, and support escaping of a double quote or backslash character by prefixing with a backslash character. The two boolean literals are written as `true` and `false`.

A percentage is simply a number followed immediately by a percentage sign — e.g. `42%` or `42.0%`.

#### Table of operators

A *grouping*, *calculation* or *comparison* is performed using one of the operators listed in table \ref{tab:operators} below. All of the operators are either *prefix* or *infix*. A prefix-operator takes a single argument and appears *before* its argument, while an infix-operator take *two* arguments and appears *between* its two arguments.

Table \ref{tab:operators} lists operator-expressions in descending order of precedence. The operators in a group of rows delimited by a horizontal line have the same precedence, which is higher than that of the operators in the group below it. Thus, `grouped by` and `where` have the highest precedence, `of` has the next-highest precedence, and the `OR` operator has the lowest precedence. The precedence of an operator determines which operator-expression is evaluated first — with higher-precedence operators being evaluated before lower-precedence operators. For example, in the expression $2+4*3$ the multiplication operation is evaluated before the addition operation because the precedence of multiplication is higher than that of addition. Similarly, in the expression `count a > 7` the `count` operation is evaluated before the *greater than*-operation because the precedence of `count` is higher than that of the *greater than*-operator — as defined by the table below.

The third column in the table defines the associativity of each infix operator. The associativity of an operator is either *left*, *right* or *none*, and defines how to group a sequence of operators of the same precedence. For example, subtraction and addition have the same precedence, so there are two different ways to interpret the expression $1-2+3$. The interpretation $(1-2)+3$ is the case when subtraction and addition are *left*-associative, while the interpretation would be $1-(2+3)$ if subtraction and addition were *right*-associative. Thus, given that e.g. the `relative to` operator is left-associative, the expression `3 relative to 6 relative to 25%` is equivalent to `(3 relative to 6) relative to 25%` (which evaluates to $200\%$) and not `3 relative to (6 relative to 25%)` (which results in a runtime error because a number cannot be compared to a percentage). Operators with an associativity of *none* are non-associative, which means combining multiple such operators in sequence is not defined — as in e.g. `1 == 1 == 1` (which will cause a parser-error).

The fourth column defines the operator's input argument type(s) while the fifth column defines the operator's result type. The `PropName` type is the type of a property name, while `Bool`, `Number`, and `Percent` are the types of the respective literals described in \ref{sec:expression-literal} and also the result type of certain operator expressions. The `Pos` type is the type of a position.  
The types contained in these two columns also include *type variables*, which start with a lower case letter (e.g. `tPropVal`), and refer to a *set* of concrete types. The type variable `tPropVal` refers to any property value type (`Number`/`String`/`Bool`); the type variable `tGrouped` refers to any type that can be in a `Grouping` (`Pos`/ `tPropVal`); the type variable `tNum` includes types that support addition and division (`Number`/`Percent`); the type variable `tEq` includes the types that can be compared for equality (`tPropVal`/`Percent`); and finally the type variable `tOrd` includes the types that can be compared for order (`Number`/`Percent`).  
When reading the table below, all type variables of the same name must be substituted for a *single* type. Thus, e.g. the operator `==` can perform an equality-comparison between two `String`-values and two `Percent`-values, but not between one `String`-value and one `Percent`-value.  
Lastly, there is the generic type `Grouping` which describes a grouping of values of some type. The type of the grouped value is in angle brackets, e.g. `Grouping<Pos>` refers to a grouping of positions.


\begin{table}[H]
   \centering
   \begin{scriptsize}
   \begin{tabular}{ | l | l | l | l | l | } \hline
      \multicolumn{1}{|c|}{\footnotesize{\textbf{Expression}}}      &
      \multicolumn{1}{c|}{\footnotesize{\textbf{Meaning}}}          &
      \multicolumn{1}{c|}{\footnotesize{\textbf{Associativity}}}    &
      \multicolumn{1}{c|}{\footnotesize{\textbf{Input type(s)}}}    &
      \multicolumn{1}{c|}{\footnotesize{\textbf{Result type}}}      \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       \texttt{e1 \textbf{grouped by} e2}  & Group by property name                 & left & \texttt{Grouping<Pos>}, \texttt{PropName} & \texttt{Grouping<Pos>}   \\
       \texttt{e1 \textbf{where} e2}       & Filter by a condition                  & left & \texttt{Grouping<Pos>}, \texttt{Bool} & \texttt{Grouping<Pos>}  \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       \texttt{e1 \textbf{of} e2}          & \textit{map} by property name          & none & \texttt{PropName}, \texttt{Grouping<Pos>} & \texttt{Grouping<tPropVal>}  \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       \texttt{\textbf{count} e}           & Count the number of groups   &  & \texttt{Grouping<tGrouped>} & \texttt{Number}      \\
       \texttt{\textbf{sum} e}             & Sum of numbers in a grouping         &   & \texttt{Grouping<Number>} & \texttt{Number}     \\
       \texttt{\textbf{average} e}         & Average of numbers in a grouping     &   & \texttt{Grouping<Number>} & \texttt{Number}     \\
       \texttt{\textbf{minimum} e}         & Maximum of numbers in a grouping       &  & \texttt{Grouping<Number>} & \texttt{Number}      \\
       \texttt{\textbf{maximum} e}         & Minimum of numbers in a grouping       &  & \texttt{Grouping<Number>} & \texttt{Number}      \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       \texttt{e1 \textbf{relative to} e2} & Relative comparison          & left & \texttt{tNum}, \texttt{tNum} & \texttt{Percent}    \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       \texttt{e1 \textbf{==} e2}          & Equals                       & none & \texttt{tEq}, \texttt{tEq} & \texttt{Bool}  \\
       \texttt{e1 \textbf{!=} e2}          & Does not equal               & none & \texttt{tEq}, \texttt{tEq} & \texttt{Bool}     \\
       \texttt{e1 \textbf{>} e2}           & Greater than                 & none    & \texttt{tOrd}, \texttt{tOrd} & \texttt{Bool} \\
       \texttt{e1 \textbf{<} e2}           & Less than                    & none   & \texttt{tOrd}, \texttt{tOrd} & \texttt{Bool} \\
       \texttt{e1 \textbf{>=} e2}          & Greater than or equal        & none   & \texttt{tOrd}, \texttt{tOrd} & \texttt{Bool} \\
       \texttt{e1 \textbf{<=} e2}          & Less than or equal           & none   & \texttt{tOrd}, \texttt{tOrd} & \texttt{Bool} \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{\textbf{NOT} e}             & Logical negation             & & \texttt{Bool} & \texttt{Bool}    \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 \textbf{AND} e2}         & Logical \textit{and}        & left & \texttt{Bool}, \texttt{Bool} & \texttt{Bool}   \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      \texttt{e1 \textbf{OR} e2}          & Logical \textit{or}          & left & \texttt{Bool}, \texttt{Bool} & \texttt{Bool}   \\ \hline
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   \end{tabular}
   \end{scriptsize}
   \caption{Precedence, associativity, input type(s), and result type of operators}\label{tab:operators}
\end{table}

\newpage

#### Grouping {#sec:syntax-grouping}

A grouping/filtering operation takes as input an existing grouping and either groups it (by a property name) or removes positions based on a condition. For example, `Portfolio grouped by .Country where (sum .Value of Country relative to Portfolio >= 10%)`{.color} first groups the portfolio by the *country* property and then removes the countries whose value relative to the portfolio is less than 10%. Here, `Portfolio` is the variable that is implicitly defined for all rules (see \ref{sec:rule-input}); it has the type `Grouping<Pos>`.

As mentioned in sec. \ref{sec:grouping-data-structure}, a grouping is represented using a tree. The figure below depicts the input and output tree of each operation in the grouping expression `Portfolio grouped by .Country grouped by .Issuer`{.color}.

![Portfolio grouped first by Country then by Issuer](./figurer/grouping_expression.png){#fig:grouping_expression}

The leftmost tree is bound to the variable `Portfolio`. Next, the `grouped by .Country`{.color} operation takes `Portfolio` as input and produces the tree shown in the middle — which contains a group for each country: Great Britain (GB), Denmark (DK), and the United States (US). After that, `grouped by .Issuer`{.color} takes as input the middle tree and produces the rightmost tree — adding a terminal node for each distinct issuer for that country under each country node.

A filter operation (the `where` keyword) evaluates to its left-argument input tree with positions removed based on the right-argument condition. Thus, a filter operation removes zero or more positions from each terminal node in the input tree, and does not modify anything else about the tree. As mentioned in sec. \ref{sec:rule-constructs}, the condition inside a filter operation applies to either a position or a group:

* ***Position* condition: **`.InstrumentType != "Bond"`{.color} applies to a *position*. When used as the condition of a filter operation it removes from all terminal nodes the positions whose `InstrumentType` property equals `"Bond"`.
* ***Group* condition:** `sum .Value of Country < 10000000`{.color} applies to a *group* (in this example the *Country* group). When used as the condition of a filter operation, for each *Country*-level node it removes *all* positions that are children of this node if the sum of the `Value` property for these positions is less than 10 million.

Thus, a position condition evaluates to a boolean for each *position*, while a group comparison evaluates to a boolean for each *group*.

The condition in a filter operation is evaluated inside the same environment as the body of a grouping iteration, which is specified in section \ref{sec:spec-grouping-iteration} below. In effect this means that the condition is evaluated once for each terminal node in the input tree, and that positions are removed from the given terminal node based on what the condition evaluates to inside the environment for this particular terminal node.

#### Calculation

A calculation transforms a grouping into a number. For example: `sum .Value of Portfolio`{.color} calculates the sum of the `Value` property for all positions in the `Portfolio` grouping, while `count (Portfolio grouped by .Country)`{.color} calculates the number of distinct countries in the `Portfolio` grouping.

A calculation may be a reduction of a particular property of all the positions in a grouping into a value (*sum/average/minimum/maximum*). For example, the *sum* calculation on the `Exposure` property, performed on some grouping, takes the value of the `Exposure` property for all positions in that grouping and returns the sum. The syntax for this is `sum .Exposure of grouping`. In this expression `grouping` is a variable of type `Grouping<Pos>` which `.Exposure of` takes as argument and transforms into the type `Grouping<tPropVal>`. The `sum` operation then takes this value as input — failing at runtime if `tPropVal` is not the `Number` type — and reduces the grouping to a single `Number`.

A calculation may also be a count of the number of groups in a grouping. For example, a *count* on `Portfolio grouped by .Country`{.color} returns the total number of `Country` groups, while a count on `Portfolio grouped by .Country grouped by .Sector`{.color} returns the total number of `Sector` groups. Thus, the *count*-operation evaluates the input grouping to a tree and returns the number of terminal nodes in this tree (see fig. \ref{fig:grouping_expression}). For example, a *count* performed on the grouping in fig. \ref{fig:grouping_country} returns $3$, and for the grouping in fig. \ref{fig:grouping_issuer} it returns $5$.

Lastly, a relative comparison between two of the above can be performed, resulting in the relative size of the left argument to the right argument in percent. For example, comparing the two constants $7$ and $10$ — using the concrete syntax `7 relative to 10` — returns $70\%$.

#### Comparison

The result of a calculation and a constant can be compared to each other. A comparison consists of **(a)** the two values to be compared, and **(b)** the *comparison operation*, which tests for any combination of equality and greater/less than (`==`, `!=`, `<`, `>`, `<=`, `>=`). For example, the comparison `sum .Value of Country < 100000`{.color}) is a comparison between `sum .Value of Country`{.color} and the constant `100000` using the comparison operation *less than*. In the Grouping section above (\ref{sec:syntax-grouping}) the condition (`sum .Value of Country relative to Portfolio >= 10%`{.color}) is also a comparison — specifically between the two values `sum .Value of Country relative to Portfolio` and `10%` using the *greater than or equal* comparison operation.

The result of a comparison is a boolean value that can be used as input to any combination of logical *and/or/not*.

### Statement {#sec:spec-statement}

A compliance rule is composed of one or more statements, with a single statement per line. A statement is either a variable definition (`let`), an *if*-statement (`if`), a grouping iteration (`forall`), or a rule requirement (`require`). The following example compliance rule uses all four of these constructs:

```rulelang
let portfolioBonds = Portfolio where .InstrumentType == "Bond"
let countryBonds = portfolioBonds grouped by .Country
forall countryBonds {
   let countryBondValue = sum .Value of Country relative to portfolioBonds
   require countryBondValue <= 20%
   if countryBondValue > 15% {
      require count (Country grouped by .Issuer) >= 8
   }
}
```

The above compliance rule has two requirements for *bonds*, i.e. the positions with an `InstrumentType` property equal to the string `"Bond"`. These two requirements are defined using the `require` keyword on line 5 and 7. The two requirements are: for each country **(1)** the value of bonds of that country relative to all bonds in the portfolio must be at most 20%, **(2)** if this relative value is greater than 15% then the bond positions for that country must be composed of at least 8 different issuers.

#### Block statement {#sec:spec-block-statement}

A *block statement* is composed of zero or more statements enclosed in curly braces:

```
{
   statementA
   statementB
   statementC
}
```

Block statements never occur in isolation. They are always part of another statement: either an *if*-statement or a grouping iteration.

#### Let-binding

The `let` keyword defines a variable. It has the form `let <ident> = <expr>`. Here  `<ident>` is the variable name, which is a text string starting with a single lower-case letter followed by zero or more alphanumeric characters. The `<expr>` is an expression, as defined above — i.e. either a grouping, a calculation, a comparison or a literal.

The lines below a variable's definition is the scope of the variable. However — as in languages such as C or Java — variables defined inside a block statement are visible only within this block; i.e. the block is the variable's scope.

A variable-definition shadows a previously defined variable of the same name. For example, in the following code the `require`-statement is evaluated inside an environment with `b` bound to **"hello"** and `a` bound to **false** (thus shadowing the definition of `a` on the first line).

```rulelang
let a = 7
let b = "hello"
let a = false
require …
```

#### Rule requirement

A rule requirement-statement has the form `require <boolExpr>`, where `<boolExpr>` is an expression of type `Bool`. A compliance rule may contain multiple rule requirement-statements (as in the example rule in sec. \ref{sec:spec-statement} above), in which case *all* the requirements must evaluate to **true** for the compliance rule to pass. Thus, there is an implicit logical *and* between two rule requirement-statements, which means the following two example rules are equivalent:

```rulelang
require a
require b
```

and

```rulelang
require a AND b
```

This also implies that the *order* of rule requirements has no effect on the semantics of the compliance rule. Thus, in the example rule above (sec. \ref{sec:spec-statement}), moving the first rule requirement (`require countryBondValue <= 20%`) down below the end of the *if*-statement (below line 8) does not change the semantics of the rule.

However, the actual *effect* of a rule requirement-statement on the process of evaluation depends on the evaluator in question. For example, a "fail-fast" evaluator — whose purpose is to report back as quickly as possible whether a compliance rule has been violated —  might only evaluate a single requirement-statement and report back if this requirement evaluates to **false**. In this case, switching two requirement-statements may cause a change in behaviour during evaluation, but the semantics of the compliance rule is unchanged (*all* requirements must evaluate to **true**).

As explained in \ref{sec:syntax-grouping}, a position condition is one that applies to a position, rather than to a group. It should be noted that such a comparison is *only* valid as the condition of a `where`-operation, and not as the argument to e.g. `require`. Thus, the rule requirement `require (.InstrumentType != "Bond")` is not valid, since the expression evaluates to *multiple* boolean values (one for each position), as opposed to e.g. `require (sum .Value of Portfolio >= 100000)` which evaluates to a single boolean value.

#### Grouping iteration {#sec:spec-grouping-iteration}

A grouping iteration statement has the form `forall <groupingExpr> <blockStatement>`. The `<groupingExpr>` is a grouping expression as defined in sec. \ref{sec:syntax-grouping}, and the `<blockStatement>` is a block statement that is the scope of the iteration. This block statement is evaluated once for each root-node-to-terminal-node path in the tree that is the result of evaluating the grouping expression. For each root-node-to-terminal-node path, the block statement is evaluated in a variable-environment that binds the name of the level (e.g. *Country*, *Issuer*) to the node at that particular level in the given path.

For example, consider the tree that results from evaluating the grouping expression `Portfolio grouped by .Country grouped by .Issuer`{.color} (depicted as the right-most tree in fig. \ref{fig:grouping_expression}). This tree has three distinct levels (*Portfolio*, *Country*, and *Issuer*) and five distinct root-node-to-terminal-node paths:

1. *Portfolio* $\rightarrow$ *Country*/**GB** $\rightarrow$ *Issuer*/**I1**
2. *Portfolio* $\rightarrow$ *Country*/**GB** $\rightarrow$ *Issuer*/**I2**
3. *Portfolio* $\rightarrow$ *Country*/**DK** $\rightarrow$ *Issuer*/**I3**
4. *Portfolio* $\rightarrow$ *Country*/**US** $\rightarrow$ *Issuer*/**I4**
5. *Portfolio* $\rightarrow$ *Country*/**US** $\rightarrow$ *Issuer*/**I5**

The block statement in this example is thus evaluated five times. The first time with the variable `Country` bound to the tree starting at the **GB**-node, and the variable `Issuer` bound to the tree starting at the **I1**-node. The second time with the variable `Country` bound to the tree starting at the **GB**-node (same as the first time), and the variable `Issuer` bound to the tree starting at the **I2**-node. And so on and so forth, with the last evaluation binding the `Country`-variable to the tree starting at the **US**-node and the `Issuer`-variable bound to the tree starting at the **I5**-node.

Note that the tree bound to the `Portfolio`-variable is not changed inside the body of a grouping iteration. One option would be to bind the `Portfolio`-variable to the root node of the grouped tree (the right-most tree in fig. \ref{fig:grouping_expression}), while the other option is to leave the `Portfolio`-variable unchanged, so that it remains bound to an ungrouped tree (the left-most tree in fig. \ref{fig:grouping_expression}). The decision has been made to leave the `Portfolio`-binding unchanged, so that in the below example rule, `count Portfolio` evaluates to $1$ both inside the grouping iteration and outside it:

```rulelang
let a = count Portfolio // evaluates to 1
forall Portfolio grouped by .Country grouped by .Issuer {
    let b = count Portfolio // also evaluates to 1
}
```

This has been decided to avoid the confusion that may result from implicitly redefining an existing variable, and because counting the number of issuers can be done simply by binding the grouping `Portfolio grouped by .Country grouped by .Issuer`{.color} to a variable and applying `count` to this variable.

#### If-statement

An if-statement has the form `if <boolExpr> <blockStatement>`, where `<boolExpr>` is an expression of type `Bool` and `<blockStatement>` is a block statement. If the `<boolExpr>` evaluates to **true** then the contents of the block statement is evaluated when evaluating the compliance rule, otherwise it is ignored.

## Example rules

This section expresses the example rules from section \ref{sec:compliance-rule-examples} using the proposed DSL.

### Rule I

[Rule I](#rule-i) (sec. \ref{sec:bg-rule-i}) expressed in the DSL looks as follows:

```rulelang
let issuers = Portfolio grouped by .Issuer
forall issuers {
   require sum .Value of Issuer relative to Portfolio <= 10%
}
let issuersAbove5Pct = issuers where (sum .Value of Issuer relative to Portfolio > 5%)
require sum .Value of issuersAbove5Pct <= 40%
```

The first line groups the portfolio positions by issuer, and binds this grouping to the variable `issuers`, so that it can be reused in the two sub-rules (lines 2-4 and line 5-6, respectively) that comprise this rule.

The `forall` keyword on line 2 starts an iteration, with the effect that the single line within the curly braces (line 3) is executed for each *issuer*-group in the `issuers`-grouping — each time with a different group bound to the `Issuer` variable.

Line 5 performs a filtering on the grouping bound to the `issuers` variable, as required by the rule, and binds this to the variable named `issuersAbove5Pct`. Finally, on line 6, the requirement of the second sub-rule is asserted.

### Rule II

[Rule II](#rule-ii) (sec. \ref{sec:bg-rule-ii}) looks as follows:

```rulelang
let issuers = Portfolio grouped by .Issuer
forall issuers {
   let issuerValue = sum .Value of Issuer relative to Portfolio
   require issuerValue <= 35%
   let issueCount = count Issuer grouped by .Issue
   if issuerValue > 30% {
      require issueCount >= 6
   }
}
```

As the first two lines are identical to the previous rule, we start at line three, in which the value of an issuer (relative to the portfolio value) is bound to the variable `issuerValue`. Line number four requires that this be less than or equal to 35% for all issuers.

On line five the number of issues for the current issuer is bound to the variable `issueCount`. This variable is then used in the lines below — lines 6-8 — in a conditional statement that requires that if the value of the issuer is greater than 30%, then the issue count must be greater than or equal to six.

### Rule III {#sec:spec-rule-iii}

[Rule III](#rule-iii) (sec. \ref{sec:bg-rule-iii}) looks as follows:

```rulelang
let govtSecurities = Portfolio where (.InstrumentType == "GovernmentBond" OR .InstrumentType == "StateBond")
forall govtSecurities grouped by .Issuer {
   let issuerValue = sum .Value of Issuer relative to Portfolio
   if issuerValue > 35% {
      let issues = Issuer grouped by .Issue
      require count (issues >= 6)
      forall issues {
         require sum .Value of Issue relative to Portfolio <= 30%
      }
   }
}
```

The first line binds to the variable `govtSecurities` the positions from the portfolio that are either government bonds or state bonds. Note that the data format here — namely, that positions which are state/government bonds have a property by the name of `InstrumentType` that is equal to `"StateBond"` and `"GovernmentBond"`, respectively — is used as an example only (the DSL does not specify the property names/contents for the input data).

On line number two, the above-created variable is grouped by the *Issuer* property and iterated over. Line three binds the relative value of the issuer to the variable `issuerValue`. Line four introduces the conditional that the rule requires: only if the relative value of the issuer is greater than 35% should the issue count and issue value be checked.

### Rule IV {#sec:spec-rule-iv}

[Rule IV](#rule-iv) (sec. \ref{sec:bg-rule-iv}) looks as follows:

```rulelang
let otcPositions = Portfolio where (.InstrumentType == "OTC")
let nonApprovedCounterparties = otcPositions where (.Counterparty == "SmallCompanyX" OR .Counterparty == "SmallCompanyY" OR .Counterparty == "SmallCompanyZ")
let approvedCounterparties = otcPositions where (.Counterparty == "HugeCorpA" OR .Counterparty == "HugeCorpB" OR .Counterparty == "HugeCorpC")
forall nonApprovedCounterparties grouped by .Counterparty {
   require sum .Exposure of Counterparty relative to Portfolio <= 5%
}
forall approvedCounterparties grouped by .Counterparty {
   require sum .Exposure of Counterparty relative to Portfolio <= 10%
}
```

Line 1 filters off the positions whose `InstrumentType` property does not equal `"OTC"`.

Secondly, in order to implement this rule it must be known how to identify approved and non-approved counterparties. In the above interpretation, the property `Counterparty` contains the name of the counterparty, and certain names are approved while others are non-approved. Line 2 and 3 binds to two variables the positions with non-approved and approved counterparties, respectively. The two grouping iterations then require the respective limit for each `Counterparty`-group.

### Rule V

[Rule V](#rule-v) (sec. \ref{sec:bg-rule-v}) looks as follows:

```rulelang
let securities = Portfolio grouped by .SecurityID
let betterThanBBB = securities where (.Rating == "AAA" OR .Rating == "AA" OR .Rating == "A")
let notBetterThanBBB = securities where (NOT (.Rating == "AAA" OR .Rating == "AA" OR .Rating == "A"))
forall betterThanBBB {
   require sum .Value of SecurityID relative to Portfolio <= 5%
}
forall notBetterThanBBB {
   require sum .Value of SecurityID relative to Portfolio <= 1%
}
```

Line 1 groups the portfolio positions by the property name `SecurityID`. This property is assumed to be unique for each individual security, thus fulfilling the "*.. in any single security ...*"-part of this rule. Line 2 and 3 are similar to the same lines in the previous rule, except that line 3 simply applies a `NOT` to the condition used in line 2. Thus, all positions in the portfolio are either in `betterThanBBB` or `notBetterThanBBB` — whereas the previous rule ignores positions that don't have one of the specified counterparties. Lastly, the last two statements apply the respective limit to each security-group.

### Rule VI {#sec:spec-rule-vi}

[Rule VI](#rule-vi) (sec. \ref{sec:bg-rule-vi}) looks as follows:

```rulelang
let homeCountry = "DK"
let foreignCountryPositions = Portfolio where (.Country != homeCountry)
let foreignCountryValue = sum .Value of foreignCountryPositions relative to Portfolio
let foreignCountryCount = count (foreignCountryPositions grouped by .Country)
if foreignCountryValue >= 80% {
    require foreignCountryCount >= 5
}
if foreignCountryValue >= 60% {
    require foreignCountryCount >= 4
}
if foreignCountryValue >= 40% {
    require foreignCountryCount >= 3
}
if foreignCountryValue <  40% {
    require foreignCountryCount >= 2
}
```

This rule first binds all foreign-country positions to the variable `foreignCountryPositions`. Then it calculates the value of these foreign-country positions and binds the result to the variable `foreignCountryValue`. Line 4 counts the number of foreign countries, by grouping `foreignCountryPositions` by the `Country` property and applying *count* to it, and binds this result to `foreignCountryCount`. The foreign-country value and count are then used in a series of *if*-statements to implement the requirements of the rule.

## Transformation pass {#sec:transformation-pass}

In order to allow for simpler concrete syntax, while adding complexity to neither the parser nor the evaluator, the abstract syntax produced by the parser goes through a *transformation pass* before being given as input to the evaluator.

In the current version of the DSL, the only pass is a transformation of a relative comparison in which one of the arguments is a grouping calculation (e.g. `average .Exposure of Country`) and the other argument is simply a grouping (e.g. `Portfolio`). An expression of this form is transformed into the equivalent — but more verbose — form in which both arguments of the relative comparison is a grouping calculation, i.e. `average .Exposure of Country relative to average .Exposure of Portfolio`.

Other transformation passes that could be relevant to consider in future versions of the DSL include optimizations. E.g., moving a let-binding out of the body of `forall`-statement if its right-hand side only references variables in the outer scope. This generic mechanism, of applying one or more transformation passes, separates the complexity of each pass, and is inspired by the Glasgow Haskell Compiler [@PeytonJones1998].

## Rule evaluation {#sec:spec-eval}

This section describes how a portfolio compliance rule is evaluated to a single boolean value, with *false* meaning one or more requirements have been violated and *true* meaning no requirements have been violated. This evaluator is simplified, in order to lower complexity, and will fail in case of any of the following:

* Any form of type error, e.g.:
  * A comparison of two incompatible values: e.g. a *string* and a *number*
  * Applying an operator to a variable of an incorrect type, e.g.:
    * `if` or `require` applied to a non-boolean
    * `count` applied to anything but a grouping
* A reference to a variable that does not exist
* A position that does not contain the specified property name

### Runtime values

The evaluator needs to represent three kinds of values at runtime:

1. A constant: *number*, *string*, *boolean*, *property name*, or *percentage*
2. A `Position` type (`Pos` in table \ref{tab:operators})
3. A `Tree` type, which describes the result of evaluating a grouping

#### Literals

A constant is used to hold all literals present in the given rule. Also, a constant is the result of evaluating both a comparison and a calculation. The evaluation of these two expression types is described below.

#### `Position`

A position is represented at runtime as a value of the `Position` type, which is a map from a property name string to a value of type *number*, *string*, or *boolean*.

#### Tree {#sec:eval-tree}

The `Tree` data type is an implementation of the grouping data structure described in sec. \ref{sec:grouping-data-structure}. Its definition as a Haskell sum type looks as follows. Refer to section \ref{sec:haskell-sum-types} for an overview on Haskell sum types.

```haskell
data Tree termLabel =
      Node (NodeData [Tree termLabel])
    | TermNode (NodeData termLabel)

data NodeData a = NodeData (FieldName, FieldValue) a
```

The `NodeData` type contains information about a particular node. It contains the *property name* of the group that the node represents (e.g. *Country*) as well as the value of that property for this particular group (e.g. *"DK"*).  
Note: in the implementation the `FieldName` type is synonymous with the `PropName` type in table \ref{tab:operators}, and `FieldValue` is synonymous with `tPropVal` in the same table. In general, the implementation uses the word *field* instead of *property*, and these two terms should be considered synonymous.  
In the evaluator, the `a` type argument is instantiated to `[Position]`, thus making each terminal node contain zero or more positions.

A `Tree` value is either a:

1. *terminal node* (`TermNode`) containing a `NodeData` (which contains a single value of type `termLabel`); or
2. a *non-terminal node* (`Node`) containing zero or more sub-trees (inside a `NodeData`)

Thus, the example portfolio grouped by country (fig. \ref{fig:grouping_country}) represented using this tree type looks as follows. Here, the positions named $P1$ through $P8$ in fig. \ref{fig:grouping_country} are represented as the strings `"P1"` through `"P8"`. In practice, values of the `Position` type would be present instead of these strings, but the actual positions have been left out for brevity.

```haskell
Node $ NodeData ("Portfolio","")
    [ TermNode $ NodeData ("Country", "GB") ["P1", "P2", "P3"]
    , TermNode $ NodeData ("Country", "DK") ["P4"]
    , TermNode $ NodeData ("Country", "US") ["P5", "P6", "P7", "P8"]
    ,
    ]
```

The tree contains a root node (`Node $ NodeData ("Portfolio","")`{.haskell}) with a property name of "Portfolio" and a property value of the empty string. The children of the root node are present in the list that is the second argument to the root node's `NodeData`. These are the terminal node $GB$ (containing the positions $P1$, $P2$, $P3$), the terminal node $DK$ (containing the position $P4$), and the terminal node $US$ (containing the positions $P5$, $P6$, $P7$, $P8$) — as depicted in fig. \ref{fig:grouping_country}.

The tree used by the evaluator to represent position groupings at runtime is thus of type `Tree [Position]`. That is, every terminal node in the tree contains zero or more positions. The type-variable `termLabel` is present in order to more easily support the above example (using strings in place of positions), as well as coming in handy when the variable environment for a grouping-iteration is created (see sec \ref{sec:eval-grouping-iteration} below).

### Let-binding

The variable environment consists of a list of name/runtime value pairs. New variable definitions are added at the head of the list, and variable names are looked up starting from the head of the list as well. The effect is that more recently declared variables will shadow variables declared earlier in case of duplicate variable names. The initial variable environment contains a single item which pairs the name *Portfolio* with the `Tree` that contains the positions of the portfolio (see \ref{sec:rule-input}).

### Statements

#### Grouping iteration {#sec:eval-grouping-iteration}

As mentioned in sec. \ref{sec:spec-grouping-iteration}, the block statement of a grouping iteration is evaluated once for each root-node-to-terminal-node path in the tree that the input grouping expression evaluates to. In practice, this means that the evaluator needs to create one variable environment for each terminal node.

Fig. \ref{fig:eval-forall-env} below adds a variable environment (depicted as a rounded, red rectangle) to all terminal nodes of fig. \ref{fig:grouping_issuer} (the tree that `Portfolio grouped by .Country grouped by .Issuer` evaluates to). The arrow describes a binding in the variable environment, with the left-hand side being the variable *name* and the right-hand side the *value* that this variable is bound to (which is a tree in the below example). A tree is referred to as the label of its root node. Thus, for example, *Country* $\mapsto$ **US** describes a binding of the variable name *Country* to the tree starting at the node with the label $US$.

![Tree with variable environments as leaf nodes](./figurer/eval-forall-env.png){#fig:eval-forall-env}

This variable environment is merged with the existing variable environment (for the code block that contains the grouping iteration), such that variables in the existing variable environment are hidden in case of duplicate variable names.



