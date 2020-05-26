\newpage
# Future work

## Minor DSL additions

### "If-elseif"-statement

In the implementation of Rule VI (sec. \ref{sec:spec-rule-vi}), note that the lack of an *if*-*then*-*else* construct means than the rule is less clear than could be. If e.g. `foreignCountryValue` is equal to 90%, then *all* of the three first rule requirements apply, since the condition of the *if*-statement is fulfilled in all three cases. This could be solved by adding an "*if-elseif*"-statement to the language, and using a series of "*if-elseif-elseif…*"-statements instead, as in:

```rulelang
...
if foreignCountryValue >= 80% {
    require foreignCountryCount >= 5
} else if foreignCountryValue >= 60% {
    require foreignCountryCount >= 4
} else if foreignCountryValue >= 40% {
    require foreignCountryCount >= 3
} else if foreignCountryValue <  40% {
    require foreignCountryCount >= 2
}
```

### Property value of group in grouping iteration

In the case of the implementation of Rule IV (sec. \ref{sec:spec-rule-iv}), note that creating two distinct groupings and using these two groupings in two separate grouping iterations — instead of a single grouping iteration that contains an *if*-statement — is the only way to implement this rule. This is necessary because the DSL does not have a way to look up a group's property value inside a grouping iteration (i.e. the value inside the node when depicted as a tree in e.g. fig. \ref{fig:grouping_issuer}). If this construct were added to the DSL, this rule could be implemented instead using a single grouping iteration (over `otcPositions grouped by .Counterparty`) which contains an *if*-statement that looks at the `Counterparty` value (e.g. `"SmallCompanyX"`) of the current `Counterparty` group, and applies one limit if this name is approved and another if it is not.

## Grouping iteration as a boolean expression

A grouping iteration (`forall`) is currently a statement that can be used to apply a rule requirement for all groups in a grouping. This means that the DSL does not allow using a `forall` as e.g. the condition of an *if*-statement because it requires an expression that evaluates to a boolean. If a `forall`-statement were an expression instead, a rule could be constructed in which a rule requirement applies only if e.g. the relative value of all groups in a grouping is greater than some value.  
In addition, if this ability were added, an `exists` expression (representing existential quantification) could also easily be added, simply by rewriting a hypothetical `exists`-expression of the form `exists grouping { a }` into the equivalent hypothetical `forall`-expression: `NOT (forall grouping { NOT a })`.

The challenge regarding adding this capability to the DSL is mostly syntactic, as a `forall`-statement spans multiple lines while expressions are restricted to a single line in the source code of the compliance rule.

## Type system

A type system can help reject invalid rules before evaluation is attempted. An informal type system is presented in table \ref{tab:operators}, but a more thorough analysis of the various constructs of the language is needed to establish a sound type system. For example, in the expression `.Value of Portfolio`, the `.Value` property name is used as a function that maps the positions inside `Portfolio` to each position's value. However, when used in e.g. the position condition `.InstrumentType != "Bond"` (see sec. \ref{sec:syntax-grouping}) the property name `.InstrumentType` is compared to a *property value*, thus giving special meaning to a property name when used as part of a position condition. These two different meanings would need to be reconciled in a potential type system.

## Let-binding of functions {#sec:fut-functions}

In Rule III (sec. \ref{sec:spec-rule-iii}), the definition of what constitutes e.g. a "government security" is composed of several logical *or*s between comparisons of the property `InstrumentType` and some string, e.g.: `.InstrumentType == "GovernmentBond" OR .InstrumentType == "StateBond" OR .InstrumentType == "TreasuryBill" OR .InstrumentType == "StateBill"`. Adding the ability to factor out this logic into a function `isGovernmentSecurity p = p.InstrumentType == "GovernmentBond" OR p.InstrumentType == "StateBond" OR p.InstrumentType == "TreasuryBill" OR p.InstrumentType == "StateBill"` reduces duplication in the rule definition, as this logic can be defined once and used multiple times in the rule.

In addition, combined with rule input arguments (sec. \ref{sec:input-arguments}), it separates the data format of positions (e.g. specific string names present in the property `IntrumentType`) from a compliance rule, thus making the rule more generic and increasing reusability.


## Rule input arguments {#sec:input-arguments}

All of the example rules contain one or more hardcoded constants — e.g. Rule II (sec. \ref{sec:bg-rule-ii}) specifies a relative limit of exactly 35%. With the goal of generalizing rules, the ability to add input arguments to rules could be added, so that e.g. Rule II keeps its basic structure — of requiring a maximum per-issuer value, as well as a certain issue-count — but accepts as arguments the exact limits, hereby easily changing the rule to have a limit of e.g. 25% and a minimum issue-count of e.g. 5.

Another example is the approved and non-approved creditors in Rule IV (sec. \ref{sec:bg-rule-iv}). Not only does this rule specify the exact names of which creditors are approved and which are non-approved, it also assumes that each position contains a property by the name of `Counterparty` which contains a string-encoded name of the counterparty. A better solution to this would be to take a *function* as input (see \ref{sec:fut-functions}) — called e.g. `isApprovedCreditor` — which takes a position as input and returns **true** if the creditor is approved and **false** otherwise. How to determine whether a position is from an approved creditor or not would then be completely factored out of the rule, including both *which* creditors are approved but also *how* to determine this when given a position (thus not requiring a string name inside the `Counterparty` property).

## User-defined calculations

The operators `sum`, `average`, `maximum`, and `count` need not be built into the DSL. These could be defined by the customer using a separate DSL and imported by a rule. This allows experts to define calculation primitives, so that the language doesn't have to be changed if a rule needs to calculate e.g. the *median* of a set of values.

In practice these functions are all a form of structural recursion over sets[@CompSyntax] with optional preprocessing (e.g. calculating the average from a *(count, sum)*-pair). The advantage of defining calculation-functions in these terms is that it guarantees termination of the calculation.

## Deriving data schema from rule

The requirements for property names and property types defined by a compliance rule can be statically derived from looking at the source code of the compliance rule. By looking at **(1)** references to a particular property name, and **(2)** the operation performed on the given property value, the required data schema for a rule can be deduced statically. For example, Rule VI (sec. \ref{sec:spec-rule-vi}) performs a `sum` operation on the contents of the `Value` property. From this it can be deduced that **(1)** the data schema for positions must include a `Value` property, and **(2)** the `Value`-property must have a number-type, as sum only works on numbers.

## Property abstraction layer

Different customers may have the same position data under different property names. For example, what if a customer wants to use a rule that references e.g. the property `DirtyValue` but instead apply the rule to a property named e.g. `CleanValue`?

Since a property can be considered a function that takes a position as input and returns a property value — e.g. `Value` takes a position as input and returns a number — this ties into taking functions as input (sec. \ref{sec:input-arguments}) and let-bound functions (\ref{sec:fut-functions}). If properties are simply functions, and the use of a given property were to imply that a rule takes this property/function as input, then a customer could easily redefine which property names a rule should use by providing different input arguments (that is, properties) to the rule in question.

## Grouping visualizations

A Sunburst chart[@Sunburst] can be used to visualize a tree data structure. Since a grouping expression evaluates to a tree, these expressions can be visualized in this manner. For example the grouping expression `Portfolio grouped by .Country grouped by .Issuer where sum .Value of Issuer >= 1%` can be visualized as follows (using fictitious position-data):

![Sunburst chart of grouping by Country and Issuer](./figurer/grouping.png){ width=75% }

Here, the inner ring visualizes the first grouping (by country), while the outer ring visualizes the second grouping (by issuer). Notably, the size of each country/issuer-slice in the visualization is proportional to the `Value`-property of the positions, because this property was used in a filter condition.

A visualization of this form could be helpful when formulating rules, by allowing customers to look at a real-time visualization of their data. For example, the above example visualization reveals that the value of positions of the issuer *Real Kredit Danmark* is relatively high compared to other issuers in the portfolio. 



\newpage

# Conclusion
A domain-specific language (DSL) for compliance rules enables users to define rules by typing in text using their keyboard. Additionally, a simple DSL makes it easier for non-technical employees to learn how to formulate rules that can be evaluated by a computer — compared to learning a general-purpose programming language. Driven by these advantages, a small DSL was developed, which consists of only four different statements and six different expression types, thus making it significantly simpler than any general-purpose programming language. The developed DSL expresses six out of seven complex compliance rules provided by SimCorp. Expressing the seventh rule would require adding the ability to define additional input to a compliance rule, which currently accepts only a portfolio (see \ref{sec:input-arguments} in the [Future work](#future-work) section). From writing the first version of the parser for the DSL, which used only parser-combinators, it was found that the unrestricted recursion resulted in unintended infinite loops in the top-level parser. The solution was to use a more restricted way to specify the top-level parser of expressions: by using an external library function that takes as input a non-recursive parser for a term, as well as the fixity and precedence for a series of non-recursive operator-parsers, and returns a recursive top-level expression parser. Lastly, the approach of letting property-based testing drive the development of the pretty-printer was deemed unsuccessful, as this approach did not detect e.g. the erroneous pretty-printing of `a AND (b AND c)` as `a AND b AND c`, due to the large number of possible combinations of abstract syntax leading to an explosion in the running time required to generate the relevant test cases.



\newpage
# References {.unnumbered}

<div id="refs" class="references"></div>

\newpage
# Appendix A {.unnumbered #sec:per-motivation}

Per Langseth Vester's description of SimCorp's motivation to participate in the project:

> **Our Motivation to Participate** 
>
> The current way to write complex compliance rules was designed around ten years ago. Overall it works well, but experience has shown us that there is room for improvement.
>
> In terms of specific challenges in the current implementation, these are the main ones:
>
> * Rule fragments are written separately from the compliance rules that use them. The intention is to promote the reuse of fragments across rules. In reality however, only few fragments are used in more than one rule. This leads to a cumbersome process, both upon initial creation and subsequent maintenance.
>
> * Conceptually, fragments are very powerful, but also difficult to master. They allow for a lot of logical constructions that do not make sense in a business context. A more user-friendly solution with a less steep learning curve will be advantageous.
>
> * From a usability point-of-view, some users prefer to be able to type in rules using the keyboard including e.g. auto completion. Our current solution does not easily allow for adding this.
>
> The team of testers, developers and product management behind Compliance Manager has been very stable throughout the years. We see this as a great opportunity to get fresh eyes on our solution that can give us new inspiration and let us benefit from some of the latest technological advancements.
>
> Finally, we see the collaboration as a good way to get more ITU students to see SimCorp as an attractive place to work after graduation.

\newpage
# Appendix B {.unnumbered #sec:davids-rules}

Document from SimCorp entitled *David's Combined Rule Examples with Solutions*, which describes complex compliance rules:

```
I

Maximum 10% of assets in any single issuer. Investments > 5% of assets for any single issuer, may not in aggregate exceed 40% of the assets of a UCITS.

Solution : This is essentially two different rules.


Required Fragements:
====================

NoCashPositions
===============
Instrument type <> Cash
=========================


IssuersExcludingCash
=====================
Grouping of NoCashPositions
  By Issuer
============================


IssuersAbove5%
================
Filtering of IssuersExcludingCash
  Where
    Dirty value
  Relative to
    Dirty value
      of NoCashPositions
  > 5%
====================================


Rule:
=====

Limit [<=10%]
  Dirty Value
    of IssuersExcludingCash
Relative To
   Dirty Value
     of NoCashPositions


Limit [<=40%]
  Dirty Value
    of IssuersAbove5%
Relative To
   Dirty Value
     of NoCashPositions


Summary: Limit Dirty value of IssuersExcludingCash relative to Dirty value of NoCashPositions and limit Dirty value of IssuersAbove5% relative to Dirty value of NoCashPositions.

===================================================
IIa

No more than 35% in securities and money mkt instruments of the same issuer, and if more than 30% in one issuer must be made up of at least 6 different issues. 

Solution : This is essentially two different rules. 

The second rule:
	If more than 30% in one issuer must be made up of at least 6 different issues,
can be re-phrased as: 
	Either 30% or less per issuer or at least 6 different issues.


Required Fragement:
====================

IssuesPerIssuer
===============
Grouping of Total Portfolio
  By Issuer
============================


Rule:
======

Limit [<=35%]
  Dirty Value
    of IssuesPerIssuer
Relative To
   Dirty Value


Only invest / Check
  Where     / If
    Or 
      Dirty Value of IssuesPerIssuer  [ <= 30% ]
            Relative To Dirty Value of Portfolio


      Number Of IssuesPerIssuer [ >= 6 ]

Summary: Limit Dirty value of IssuesPerIssuer relative to Dirty value and only invest where ( check if) Dirty value of IssuesPerIssuer relative to Dirty Value of the portfolio <= 30% or Number of IssuesPerIssuer >= 6.

===============================================================================================

II b

UCITS Article 23 (1) ñ 

When holding > 35% in a single issuer of government and public securities, 

Then there can be no more than 30% in any single issue 

And a minimum of 6 different issues is required.


Solution: This is again, two different rules, but far more complicated than solution II a.

Required Fragements:
====================


IssuesPerIssuer
===============
Grouping of Total Portfolio
  By Issuer
============================


IssuersAbove35%
================
Filtering of IssuesPerIssuer
  Where
    Dirty value
  Relative to
    Dirty value
  > 35%
====================================


Rule:
======

Limit [<=30%]
  Dirty Value
    of IssuersAbove35%
        foreach 
           Security ( Issue )
Relative To
   Dirty Value



Only invest / Check
  Where     / If
    Or 
      Dirty Value of IssuesPerIssuer  [ <= 35% ]
            Relative To Dirty Value of Portfolio


      Number Of IssuesPerIssuer [ >= 6 ]


Summary: Limit Dirty value of IssuersAbove35% foreach issue relative to Dirty value and only invest where ( check if) Dirty value of IssuesPerIssuer relative to Dirty Value of the portfolio <= 35% or Number of IssuesPerIssuer >= 6.

====================================================
III


The risk exposure of a UCITS to a counterparty to an OTC derivative may not exceed 5% NA; the limit is raised to 10% for approved credit institutions

Solution : This is essentially two different rules.

Rule:
======

Limit [<=5%]
 Exposure
   for each
      Counterparty
         Where
            And
              InstrumentType = OTC
              Counterparty NOTIN [approved list] 
Relative to
  Exposure
  
 
Limit [<=10%]
 Exposure
   for each
      Counterparty
         Where
            And
              InstrumentType = OTC
              Counterparyt IN [approved list] 
Relative to
  Exposure

Summary: Limit Exposure of each Counterparty where InstrumentType equals OTC and Counterparty not in [approved list] relative to Exposure and limit Exposure of each Counterparty where InstrumentType equals OTC and Counterparty in [approved list] relative to Exposure. 
 
=================================================
IV

Max of 15% per Sector or 200% of the index weight in the sector, whichever is greater.

Solution:

The rule can be re-phrased as: 
	Either 15% or less per Sector or 200% of the index weight in the sector.


Required Fragment:
==================

InvestmentPerSector
======================
Grouping of Total Portfolio
  by Sector
==============================


Rule:
=====

Only invest / Check
  Where     / If
    OR   
      Dirty Value of InvestmentPerSector [ <= 15 % ] 
           Relative to Dirty value of Portfolio   

      Compared % with Benchmark in freely defined benchmark [200%]
          Dirty value of InvestmentPerSector 
             Relative To Dirty value
       
    
Summary: Only invest where ( check if) Dirty value of InvestmentPerSector relative to Dirty value of the portfolio <= 15% or compared relative with benchmark in freely defined benchmark Dirty value of InvestmentPerSector relative to Dirty value = 200%. 
==========================================
V

Max 5% in any single security rated better than BBB: otherwise the maximum is 1% of fund net value.

Solution : This is essentially two different rules.

Rule:
======

Limit [<=5%]
 Dirty Value
   for each
      Security
         Where
            SecurityRating IN [better than BBB]               
Relative to
  Dirty Value
  
 
Limit [<=1%]
 Dirty Value
   for each
      Security
         Where
            SecurityRating NOTIN [better than BBB]               
Relative to
  Dirty Value

Summary: Limit Dirty value of each Security where SecurityRating in [better than BBB] relative to Dirty value and limit Dirty value of each Security where SecurityRating not in [better than BBB] relative to Dirty value. 
=================================================

VI

The portfolio shall invest in no fewer than 5 foreign countries, provided that:
1. If foreign securities comprise less than 80% of its net assets, then it shall invest in
no fewer than 4 foreign countries.
2. If foreign securities comprise less than 60%, then it shall invest in no fewer than 3
foreign countries.
3. If foreign securities comprise less than 40%, then it shall invest in no fewer than 2
foreign countries.


Solution : 
This is essentially four different rules with limits as follows : 

% in foreign securities 	| Number of foreign countries
	80 - 100 ( >= 80% )  	| 	>= 5
	60 - 80  ( >= 60% ) 	| 	>= 4
	40 - 60  ( >= 40% ) 	| 	>= 3
	0  - 40  ( < 40%  ) 	| 	>= 2


These rules can be rephrased as follows:

Rule 1: Either foreign securities comprise less than 80% of its net assets or the portfolio shall invest in
no fewer than 5 foreign countries.


Rule 2: Either foreign securities comprise less than 60% of its net assets or the portfolio shall invest in
no fewer than 4 foreign countries.


Rule 3: Either foreign securities comprise less than 40% of its net assets or the portfolio shall invest in
no fewer than 3 foreign countries.

Rule 4: The portfolio shall invest in no fewer than 2 foreign countries.


Required Fragment:
==================

ForeignSecurities
===============
Grouping of 
    Country <> Dk
      by Country
=================


Rule:
======

Only invest
  Where
    OR
      Dirty Value of ForeignSecurities  [ < 80% ]
               Relative To Dirty Value of Portfolio

      Number Of Countries of ForeignSecurities [ >= 5 ]


Only invest
  Where
    OR
      Dirty Value of ForeignSecurities  [ < 60% ]
               Relative To Dirty Value of Portfolio

      Number Of Countries of ForeignSecurities [ >= 4 ]


Only invest
  Where
    OR 
      Dirty Value of ForeignSecurities  [ < 40% ]
               Relative To Dirty Value of Portfolio

      Number Of Countries of ForeignSecurities [ >= 3 ]


Only invest
  Where
     Number Of Countries of ForeignSecurities [ >= 2 ]


Summary: Only invest where Dirty value of foreign securities relative to dirty value of the portfolio < 80% or number of Countries of ForeignSecurities >= 5 and only invest where Dirty value of foreign securities relative to dirty value of the portfolio < 60% or number of Countries of ForeignSecurities >= 4 and only invest where Dirty value of foreign securities relative to dirty value of the portfolio < 40% or number of Countries of ForeignSecurities >= 3 and only invest where number of Countries of ForeignSecurities >=2.
===================================================
```

