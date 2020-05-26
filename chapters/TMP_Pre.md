---
title: "A domain-specific language for compliance rules"
author: Rune K. Svendsen
date: "2020-05-15"
keywords: [Portfolio compliance, DSL]
lang: "en"
...

# Introduction

Companies that invest money on behalf of customers — hereafter referred to as *asset managers* — are subject to restrictions on what they are allowed to invest in. For example — in order to reduce the risk of monetary loss for pension holders — a law might require that a pension fund invest no more than a certain fraction of its funds in a single business sector (e.g. *agriculture*, *manufacturing*, or *construction*). To the asset manager, a law of this nature becomes a *compliance rule*. A compliance rule is a rule that a given *portfolio* (the set of investments owned by the asset manager) must comply with. A large number of portfolio compliance rules apply to asset managers, who must keep track of whether or not their investments adhere to these rules.

SimCorp is a financial software-company, whose customers include asset managers, banks, central banks, pension funds, sovereign wealth funds and insurance companies[@SimCorpFactSheet]. SimCorp's core software product *SimCorp Dimension* includes — among many other features — the ability to automatically check portfolios against a set of compliance rules. This enables asset managers to spend less time dealing with compliance rules, as computer software can automatically perform the task of checking for compliance with rules and regulations.

Per Langseth Vester (Lead Product Owner at SimCorp) describes SimCorp's motivation for looking at new possibilities regarding compliance rule software in [Appendix A](#sec:per-motivation). In summary, SimCorp's current software solution for compliance rules works well, but there is room for improvement:

* From a usability point-of-view, some users prefer being able to type in rules using the keyboard — including e.g. auto-completion. SimCorp's current solution does not easily allow for adding this.
* When writing compliance rules using SimCorp's software, the rule author can make use of so-called *rule fragments*. A rule fragment is a small, re-usable rule condition. By combining together many of these  conditions, complex compliance rules can be created without having to write the entire rule from scratch.
  * SimCorp's intention is to promote the reuse of rule fragments across compliance rules. In reality however, only few fragments are used in more than one rule. 
  * Conceptually, fragments are very powerful, but also difficult to master. They allow for many logical constructions that do not make sense in a business context. SimCorp would like a more user-friendly solution with a less steep learning curve.

## Scope

The scope of this project is to design, and implement in Haskell, a domain-specific language (DSL) for expressing compliance rules. The DSL will make use of concepts from functional programming, and must support at least the six rules listed in section \ref{sec:compliance-rule-examples}. These rules are representative of the more complex rules in use, but we do not here strive to cover all rules used in practice.

\newpage
# Background

## Compliance rule

### Definitions

This section defines terms that will be used throughout the report. Note that these definitions do not necessarily correspond to how the terms are used in the industry — they merely specify how the terms are used in this report.

#### Security

The term *security* is used to refer to any asset that an investor can be in possession of. This includes, but is not limited to: cash (money in a bank account), bonds (long term debt obligations), company stock (company ownership), money market instruments (short term debt obligations). A single security — e.g. one share of IBM stock — is the smallest unit described in this paper. The term *instrument* may be used as a synonym for security. 

#### Position

The term *position* refers to one or more of the same type of security. For example, the ownership of five shares of Microsoft stock at a current market value of USD 150 each comprises a *position* in Microsoft stock with a current market value of USD 750. The position is the smallest unit that a portfolio compliance rule can apply to. Thus, no portfolio compliance rule distinguishes between owning e.g. ten shares of Google with a value of USD 1000 each versus eight shares of Google with a value of USD 1250 each — both comprise a position in Google shares with a value of USD 10000.

#### Portfolio

The term *portfolio* refers to a *set of positions*. A particular portfolio may contain positions of the same *type* from the same *region*, e.g. Asian stocks; it may contain all the positions of a particular *client* (a given customer of the asset manager); or it may contain all positions governed by a particular portfolio compliance rule. For the purpose of this paper the latter is assumed. That is, a portfolio — containing a number of positions — exists because the positions herein are governed by the same compliance rule(s).

### Compliance rule examples {#sec:compliance-rule-examples}

Compliance rules vary greatly in complexity. An example of a very simple compliance rule is "*invest only in bonds*". Evaluating whether a portfolio complies with this rule only requires looking at each position individually, checking whether this position is a bond, and failing if it is not.

A more complex rule may be a limit on the value of the positions that share a specific property. For example, a rule may require that the value of all positions that have the same *issuer* must be at most two million dollars. Oftentimes a rule will impose a *relative* limit — as opposed to an absolute limit of e.g. two million dollars — for example by requiring that the value of same-issuer positions relative to the total value of the portfolio must be no more than 5%.

The goal is for the DSL to be able to express compliance rules of relatively high complexity. For this purpose, SimCorp has provided a document containing seven complex compliance rules (see [Appendix B](#sec:davids-rules)). Six of these rule have been chosen as the basis of the proposed DSL because of their similarity to each other. In order to restrict the scope of the DSL, the rule concerning *sector index-weights* — labeled as `IV` in Appendix B — has not been included in the example rules that the DSL must support. The six chosen rules are labeled as `I`, `IIa`, `IIb`, `III`, `V`, and `VI`  in Appendix B. They are presented below as Rule I, II, III, IV, V, and VI, respectively.

#### Rule I {#sec:bg-rule-i}

*Maximum 10% of assets in any single issuer. Positions of the same issuer whose value is greater than 5% of total assets may not in aggregate exceed 40% of total assets.* (Rule `I` in [Appendix B](#sec:davids-rules))

This rule is composed of two sub-rules. The overall rule requires compliance with both of the sub-rules.

We begin by separating the positions in the portfolio into groups, such that each group contains all positions that have the same issuer (hereafter referred to as *grouping by issuer*). After this initial step, the two sub-rules proceed as follows:

1. For each group: the sum value of the positions in the group must be at most 10% of the total portfolio value.

2. Remove all of the groups whose value relative to the portfolio is less than or equal to 5%. The aggregate value of the remaining groups must be at most 40% of the total portfolio value.

#### Rule II {#sec:bg-rule-ii}

*No more than 35% in securities of the same issuer, and if more than 30% in one then issuer must be made up of at least 6 different issues.* (Rule `IIa` in [Appendix B](#sec:davids-rules))

This rule is also composed of two sub-rules. As in the previous rule, the first step for both sub-rules is to group by issuer.

1. For each group: the sum value of the positions in the group must be at most 35% of the total portfolio value.
2. For each group whose relative value is greater than 30%: a *count* of the number of different *issues* for this group must be greater than or equal to *six* (where counting the number of different issues in a group amounts to grouping by issue and counting the resulting groups).

#### Rule III {#sec:bg-rule-iii}

*When holding >35% in a single issuer of government and public securities, then there can be no more than 30% in any single issue, and a minimum of 6 different issues is required.* (Rule `IIb` in [Appendix B](#sec:davids-rules))

The first step is to filter off positions that are *not* either a government or public security. Next we group by issuer, followed by:

1. For each *issuer*-group: only if the group value is greater than 35% of the total portfolio value: then group by *issue* and proceed to **2.**
2. a. The *issue*-group count must be at least 6, and
   b. For each *issue*-group: the value of the group must be at most 30% of total portfolio value

#### Rule IV {#sec:bg-rule-iv}

*The risk exposure to a counterparty to an OTC derivative may not exceed 5% of total portfolio exposure; the limit is raised to 10% for approved credit institutions.* (Rule `III` in [Appendix B](#sec:davids-rules))

First, filter off positions that are not an *OTC derivative*. Next, group by counterparty, and for each counterparty-group:

* If the counterparty **is not** an approved credit institution:
  * then the exposure of the counterparty relative to the total portfolio exposure must be at most **5%**
* If the counterparty **is** an approved credit institution:
  * then the exposure of the counterparty relative to the total portfolio exposure must be at most **10%**

#### Rule V {#sec:bg-rule-v}

*Max 5% in any single security rated better than BBB: otherwise the maximum is 1% of total portfolio value.* (Rule `V` in [Appendix B](#sec:davids-rules))

First, group by security, and for each security-group:

* If the security's rating is **AAA** or **AA** or **A** (i.e. better than **BBB**), then the value of the security must be at most 5% relative to total portfolio value
* Otherwise the value of the security must be at most 1% relative to total portfolio value

#### Rule VI {#sec:bg-rule-vi}

*The portfolio shall invest in at least 5 / 4 / 3 / 2 different foreign countries if aggregate value of foreign countries relative to portfolio >=80% / >=60% / >=40% / <40%, respectively.* (Rule `VI` in [Appendix B](#sec:davids-rules))

First, filter off domestic positions, in order to obtain only foreign-country positions. Next, calculate **(a)** the value of foreign-country positions relative to the *entire* portfolio (i.e. the portfolio including domestic positions), and **(b)** the number of different foreign countries. Then:

* If foreign-country value is at least **80%**: foreign-country count must be at least **5**
* If foreign-country value is at least **60%**: foreign-country count must be at least **4**
* If foreign-country value is at least **40%**: foreign-country count must be at least **3**
* If foreign-country value is less than **40%**: foreign-country count must be at least **2**

## Domain-specific language

A domain-specific language (DSL) is a programming language that is tailored to model a specific business domain. A DSL stands in contrast to a *general-purpose* programming language (GPPL), which is designed to model *any* business domain. A DSL is thus less expressive than a GPPL, in the sense that a DSL intentionally restricts the domain that can be modelled using the language.

DSL examples include: HTML (*Hypertext Markup Language*) for describing the structure of a web page; CSS (*Cascading Style Sheets*) for describing the presentation of a web page (e.g., layout, colors, fonts); and SQL (*Structured Query Language*) for describing queries against a relational database.

### Purpose

Due to the restriction in what a DSL must be capable of modeling, it is possible to design a DSL that is significantly simpler than a GPPL. And while this comes with the disadvantage of reducing what is possible to express using the DSL, it also comes with the advantage of a reduction in the time and effort needed to learn it. Consequently, if the goal is to get experts of a particular business domain to easily express their domain knowledge in code, which can be executed by a computer, a simple DSL can be a helpful tool.

### Terminology

#### *Abstract* versus *concrete* syntax

The *abstract syntax* of a programming language (whether domain-specific or general-purpose) is a data structure that describes an expression in that language. As an example, let us consider a very simple DSL that describes multiplication and addition of integers. This language has two *data constructors*: $Mul$ and $Add$, which describe multiplication and addition, respectively. Both of these data constructors take two arguments which may be either an integer or another expression — i.e. either a multiplication or addition or a combination hereof. The abstract syntax $Add\;3\;5$ thus describes three added to five, $Mul\;2\;7$ describes two multiplied by seven, and $Mul\;4\;(Add\;1\;6)$ describes multiplying by four the result of adding one to six. This syntax is called "abstract" because it refers to abstract objects. The objects $Add$ and $Mul$ are abstract in the sense that $Add$ and $Mul$ are simply *names* used to refer to the abstract operation of addition and multiplication, respectively — we could just as well refer to these objects as $A$ and $M$.

The *concrete syntax* of a programming language is **a representation** of the abstract syntax. For example, a common representation of $Mul\;4\;(Add\;1\;6)$ — i.e. multiplying by four the result of adding one to six — is `4 × (1 + 6)`. But we may also refer to this same operation in concrete syntax by adding a (redundant) pair of parentheses around each subexpression:  `(4) × ((1 + 6))` — both pieces of concrete syntax refer to exactly the same operation. Thus, as can be seen from this example, a single piece of abstract syntax can be represented in multiple ways using concrete syntax.

In programming jargon, concrete syntax is usually referred to simply as "program code" or "source code", whereas the abstract syntax is an internal data structure used by the compiler or interpreter of the language in question.

#### *Printer* versus *parser*

A *parser* converts concrete syntax into abstract syntax, while a *printer* converts abstract syntax into concrete syntax. A parser can fail because it can be given invalid input. Using the above example of multiplication and addition, a parser given the input `4×(1+6` will fail because an ending parenthesis is missing. A printer cannot fail — it should be able to convert any instance of abstract syntax into concrete syntax.

Given a parser and a printer for the same language, feeding to the parser the output of applying the printer to any piece of abstract syntax should yield the same piece of abstract syntax. The opposite, however, is not  necessarily the case, as the printer cannot know e.g. how many redundant parentheses there were in the original concrete syntax, and may thus output different concrete syntax.

### Comparison with general-purpose language

The two subsections below describe benefits and drawbacks of expressing domain knowledge in a DSL compared to using an existing GPPL for this purpose.

#### Benefits

* A restriction of the constructs available for recursion can guarantee termination. For example, restricting iteration to *"doing something for every item in a list"*, as well as not allowing infinite lists, guarantees that programs will terminate (i.e. not loop infinitely).
* Parallel evaluation made possible by absence of side effects

* Separation of the *language* from the *model described using the language* allows different interpretations of the same model:
  * *Formatting* the model for ease of readability, by printing out using syntax highlighting and standardized formatting
  * *Visualizing* the model, i.e. producing an image that represents the model
  * *Perform static checks* on the model, i.e. checking the model for inconsistencies and errors that may not be possible if the model were expressed in a GPPL
  * Different implementations of programs that evaluate the model — as opposed to being tied to the GPPL in which the model is formulated, e.g.:
    * One evaluator written in C for performance — while sacrificing memory safety (and thus risking security vulnerabilities)
    * Another evaluator written in Haskell for safety —  while sacrificing performance

#### Drawbacks

The drawbacks are related primarily to up-front cost and maintenance costs:

* User needs to learn a new language, including both syntax and semantics
* Higher cost of maintaining separate compiler and parser for custom DSL

