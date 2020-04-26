---
title: "A domain-specific language for portfolio compliance rules"
author: Rune K. Svendsen
date: "2020-05-15"
keywords: [Portfolio compliance, DSL]
lang: "en"
...

# Introduction

TODO. Nævn:

* SimCorp's situation
  * Mange regler og porteføljer
* "Comprehension syntax"-sprog

## Motivation

**TODO:** integrer følgende udkast fra Per Vester omkring SimCorp's motivation for a deltage i projektet:

***Our Motivation to Participate***

*The current way to write complex compliance rules was designed around ten years ago. Overall it works well, but experience has shown us that there is room for improvement.*

*In terms of specific challenges in the current implementation, these are the main ones:*

* *Rule fragments are written separately from the compliance rules that use them. The intention is to promote the reuse of fragments across rules. In reality however, only few fragments are used in more than one rule. This leads to a cumbersome process, both upon initial creation and subsequent maintenance.*

* *Conceptually, fragments are very powerful, but also difficult to master. They allow for a lot of logical constructions that do not make sense in a business context. A more user-friendly solution with a less steep learning curve will be advantageous.*

* *From a usability point-of-view, some users prefer to be able to type in rules using the keyboard including e.g. auto completion. Our current solution does not easily allow for adding this.*

*The team of testers, developers and product management behind Compliance Manager has been very stable throughout the years. We see this as a great opportunity to get fresh eyes on our solution that can give us new inspiration and let us benefit from some of the latest technological advancements.*

*Finally, we see the collaboration as a good way to get more ITU students to see SimCorp as an attractive place to work after graduation.*

## Scope

The scope of the project is to design, and implement in Haskell, a domain-specific language (DSL) for expressing portfolio compliance rules. The basis for this DSL is the *Comprehension syntax*-language[1]. The DSL must support at least the six rules listed in [Compliance rule examples](#compliance-rule-examples), which are representative of the more complex rules in use, but we do not strive to cover all rules used in practice.

# Background

## Portfolio compliance

Companies/institutions that invest money on behalf of customers — hereafter referred to as *institutional investors* — are subject to laws that govern what they are allowed to invest in. For example, a law might require that a pension fund invest no more than a certain fraction of its funds in the bonds of companies belonging to a single business sector — e.g. *the value of bonds from companies in agriculture may not exceed 5% of the value of total assets*. A large number of these *portfolio compliance rules* apply to institutional investors, who must keep track of whether or not their investments comply with these rules.

### Terms

#### Security

The term *security* refers to any asset that an institutional investor can be in possession of. This includes, but is not limited to: cash (money in a bank account), bonds (long term debt obligations), company stock (company ownership), money market instruments (short term debt obligations). A single security — e.g. one share of IBM stock — is the smallest unit described in this paper.

#### Position

The term *position* refers to one or more of the same type of security. For example, the ownership of five shares of Microsoft stock at a current market value of USD 150 each comprises a *position* in Microsoft stock with a current market value of USD 750. The position is the smallest unit that a portfolio compliance rule can apply to. Thus, no portfolio compliance rule distinguishes between owning e.g. ten shares of Google with a value of USD 1000 each versus eight shares of Google with a value of USD 1250 each — both comprise a position in Google shares with a value of USD 10000.

#### Portfolio

The term *portfolio* refers to a *set of positions*. A particular portfolio may contain positions of the same *type* from the same *region*, e.g. Asian stocks; it may contain all the positions of a particular *client* (a given customer of the institutional investor); or it may contain all positions governed by a particular portfolio compliance rule. For the purpose of this paper, the latter is assumed. That is, a portfolio — containing a number of positions — exists because the positions herein are governed by the same compliance rule(s).

### Compliance rule examples

In this section six different compliance rules are presented (REF: [David's rules](#a.1)). Common to all rules is that a position has one or more properties. A property is identified by a name — such as *value*, *issuer*, and *security type* — and an associated value.

#### Rule I

*Maximum 10% of assets in any single issuer. Positions with the same issuer whose value is greater than 5% of total assets may not in aggregate exceed 40% of total assets.*

This rule is composed of two sub-rules. In both cases we begin by separating the positions into groups, such that each group contains only positions that have the same issuer (hereafter referred to as *grouping by issuer*). After this initial step, the two sub-rules proceed as follows:

1. For each group: the value of the group must be at most 10% of the total portfolio value.

2. Remove all of the groups whose value relative to the portfolio is less than or equal to 5%. The total aggregate value of the remaining groups must be at most 40% of the total portfolio value.

#### Rule II

*No more than 35% in securities of the same issuer, and if more than 30% in one then issuer must be made up of at least 6 different issues.* 

This rule is also composed of two sub-rules. As in the previous rule, the first step for both sub-rules is to group by issuer.

1. For each group: the value of the group is less than or equal to 35% of the total portfolio value.
2. For each group whose relative value is greater than 30%: a *count* of the number of different *issues* must be greater than or equal to *six* (where counting the number of different issues in a group amounts to grouping by issuer and counting the number of resulting groups).

#### Rule III

*When holding >35% in a single issuer of government and public securities, then there can be no more than 30% in any single issue, and a minimum of 6 different issues is required.*

The first step is to filter off anything that is *not* either a government or public security. Next we group by issuer, followed by:

1. For each *issuer*-group: only if the group value is greater than 35% of the total portfolio value: then group by *issue* and proceed to **2.**
2. a. The *issue*-group count must be at least 6, and
   b. For each *issue*-group: the value of the *issue*-group must be less than or equal to 30% of total portfolio value

#### Rule IV

*The risk exposure to a counter-party to an OTC derivative may not exceed 5% NA; the limit is raised to 10% for approved credit institutions.*

First, filter off anything that is not an *OTC derivative*. Next, for each counter-party: **TODO**

#### Rule V

*Max 5% in any single security rated better than BBB: otherwise the maximum is 1% of fund net value.*

**TODO**

**Sprøgsmål til peter:** de konstruktioner, som denne regel bruger, er identiske med *IV*. Bør jeg overveje at fjerne denne regel, da den ikke tilføjer noget til sproget?

#### Rule VI

*The portfolio shall invest in minimum 5 / 4 / 3 / 2 different foreign countries if: aggregate value of foreign countries relative to portfolio >=80% / >=60% / >=40% / <40%, respectively.*

First, filter off domestic positions, in order to obtain only foreign-country positions. Next, calculate the value of foreign-country positions relative to the entire portfolio, as well as the number of foreign countries. Then:

* If foreign-country value is at least **80%**: foreign-country count must be at least **5**
* If foreign-country value is at least **60%**: foreign-country count must be at least **4**
* If foreign-country value is at least **40%**: foreign-country count must be at least **3**
* If foreign-country value is less than **40%**: foreign-country count must be at least **2**

## Domain-specific languages

A domain-specific language (DSL) is a programming language that is tailored to model a specific business domain. DSLs stand in contrast to *general-purpose* programming languages (GPL), which are designed to model *any* business domain. DSLs are thus less expressive than general purpose languages, in the sense that they intentionally restrict the domain that can be modelled using the language.

### Purpose

**TODO:**

* Domain experts can learn a simple DSL quicker than it takes them to learn a GPL
* This enables them to more quickly learn how to express domain knowledge in code

### Terms

#### *Abstract* versus *concrete* syntax

**TODO:** model versus a representation of that model

#### *Printer* versus *parser*

**TODO:** 

* converting between abstract and concrete syntax
* a parser can fail, a printer cannot

#### *Embedded* versus *external*

**TODO**

### Benefits

* Restriction of the constructs available for loops/recursion can guarantee termination. For example, restricting iteration to "doing something for every item in a list" as well as not allowing infinite lists guarantees that programs will terminate (i.e. not loop infinitely).
* Separation of the *language* from the *models* described using the language allows different interpretations of the same model:
  * *Formatting* the model for ease of readability, by printing out using syntax highlighting and standardized formatting
  * *Visualizing* the model, i.e. producing an image that represents the model
  * *Perform static checks* on the model, i.e. checking the model for inconsistencies and errors that may not be possible if the model were expressed in a GPL
  * Different *implementations* of programs that evaluate the model — as opposed to being tied to the GPL in which the model is formulated
    * e.g. one written in C for performance, and another implemented in Haskell for correctness

### Drawbacks

**TODO**

## Comprehension syntax

### What is it?

**TODO:** Operations "naturally associated with" *collection types* (i.e., lists, sets, multisets). Operations:

* Iterate over collection
* Conditional execution
* Pattern matching (*where x == y*)
