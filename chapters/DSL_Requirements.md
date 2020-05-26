\newpage
# Requirements analysis

In this section, the example rules from section \ref{sec:compliance-rule-examples} are analyzed in order to derive requirements for the DSL.

## Analysis of example rules

### General

All the example rules refer to a position as having one or more *properties*. For example, a property may be a position's *value*, its *issuer*, or its *country*. Furthermore, all of these properties require a notion of equality — i.e. it must be possible to determine whether e.g. the *country* properties of two different positions are equal or not. In addition, some properties (e.g. *value* and *exposure*) require the ability to compare for *order* (less/greater than), as well as requiring the numeric operations *addition* (for calculating the sum of multiple values) and *division* (for calculating relative value).

### Rule constructs {#sec:rule-constructs}

The following constructs have been identified from analyzing the example rules:

* **Grouping:** by a given property *name* (e.g. *"country"*), so that a group is created for each distinct value of this property (e.g. "DK", "US", "GB"), and each group contains all the positions whose property value is equal to the group's value
* **Group filtering:** removing certain groups from a grouping by some condition (e.g. "*relative value < 5%*")
* **Position filtering**: removing certain positions from a grouping by some condition (e.g. "*is not either a government or public security*")
* **Group sum**: calculating the sum of the values of some property name (e.g. *"exposure"*) for all the positions in a group
* **Group count**: counting the number of groups in a grouping
* **Logical *and***: when a single rule is composed of two or more sub-rules then both sub-rules must apply
* **For all**: apply a rule for each group that results from a grouping (e.g. "*For each issuer-group …*"), with the effect that the given rule must apply for all groups
* **Relative:** calculating the relative value of one value compared to another value (e.g. "*exposure of the counterparty relative to the total portfolio exposure*")
* **Conditional**: apply a requirement only if some condition is true (e.g. *"if foreign-country value is at least 80% then foreign-country count must be at least 5"*)

Note the presence of both a *group filtering* and *position* filtering. In the second sub-rule of Rule I (sec. \ref{sec:bg-rule-i}) the groups in the *issuer*-grouping whose relative value is at most 5% are removed. Thus, the condition (*"relative value of group > 5%"*) applies to a group, and determines whether the entire group in question is removed. Compare this to the filtering in Rule III (\ref{sec:bg-rule-iii}) and Rule IV (\ref{sec:bg-rule-iv}), in which individual positions are removed from the portfolio before proceeding. For example, in Rule IV the positions whose type is not *OTC derivative* are removed. Here, the condition (*"is OTC derivative"*) applies to a single position, rather than to a group, and individual positions are removed from the grouping that the filter is applied to.

Table \ref{tab:rule-matrix} below summarizes which constructs are used by each example rule. Due to a lack of space, the constructs *group filtering* and *position filtering* are represented as a single construct named *filter*.

\begin{footnotesize}
    \begin{table}[H]
        \centering
        \begin{tabular}{| l | l | l | l | l | l | l | l | l |} \hline
                                                                                &
            \multicolumn{1}{|c|}{\footnotesize{\textbf{Grouping}}}               &
            \multicolumn{1}{c|}{\footnotesize{\textbf{Filter}}}    &
            \multicolumn{1}{c|}{\footnotesize{\textbf{\textit{and}}}}    &
            \multicolumn{1}{c|}{\footnotesize{\textbf{\textit{for all}}}}        &
            \multicolumn{1}{c|}{\footnotesize{\textbf{Group sum}}}        &
            \multicolumn{1}{c|}{\footnotesize{\textbf{Group count}}}        &
            \multicolumn{1}{c|}{\footnotesize{\textbf{Relative}}}        &
            \multicolumn{1}{c|}{\footnotesize{\textbf{Conditional}}}        \\ \hline
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %                 Group   Filter  AND      forall  sum     count   rel.    cond.
            Rule I           & \X    & \X    & \X     & \X    & \X    &       & \X    &       \\ \hline
            Rule II          & \X    &       & \X     & \X    & \X    & \X    & \X    &  \X   \\ \hline
            Rule III         & \X    & \X    & \X     & \X    & \X    & \X    & \X    &  \X   \\ \hline
            Rule IV          & \X    & \X    &        & \X    & \X    &       & \X    &  \X   \\ \hline
            Rule V           & \X    &       &        & \X    & \X    &       & \X    &  \X   \\ \hline
            Rule VI          & \X    & \X    &        &       & \X    & \X    & \X    &  \X   \\ \hline
        \end{tabular}
        \caption{Rule/construct matrix}\label{tab:rule-matrix}
    \end{table}
\end{footnotesize}

## Grouping data structure {#sec:grouping-data-structure}

From the above analysis it is clear that the concept of a *grouping* is required. In addition, [Rule III](#rule-iii) shows  (when grouping an *issuer*-grouping by *issue*) that an existing grouping can be grouped once again, thus creating multiple levels of groupings. Due to these requirements, and inspired by SimCorp's use of a tree structure to visualize groupings, a tree has been chosen to describe a grouping.

The following figure shows the simplest grouping of them all — a portfolio. This portfolio contains the positions $P1$ through $P8$.

![Tree data structure for an ungrouped portfolio](./figurer/grouping_portfolio.png){#fig:grouping_portfolio}

This is represented as a tree with a single non-leaf node (depicted as round), under which a leaf node (depicted as square) is present for each position in the portfolio (named $P1$ through $P8$ in the above figure). A position is thus represented as a leaf node in a tree, where each non-leaf node represents a group.

The figure below depicts the tree that results from grouping the above portfolio (fig. \ref{fig:grouping_portfolio}) by *country*.

![Tree data structure for a portfolio grouped by country](./figurer/grouping_country.png){#fig:grouping_country}

A node for each distinct value of the *country* property is created as children of the parent portfolio-node. This example portfolio contains positions from three different countries: Denmark (*DK*), United States (*US*), and Great Britain (*GB*). Under these new nodes, the positions whose *country* property is equal to the value in the given node are present as leaf nodes.

The figure below depicts the tree that results from grouping by *issuer* the above country-grouping (fig. \ref{fig:grouping_country}).

![Tree data structure for a portfolio grouped by country and then by issuer](./figurer/grouping_isser.png){#fig:grouping_issuer}

When the existing country-grouping is grouped again by issuer, we see that another level of nodes is added below the country-level. This level contains a node for each distinct issuer under each country node (named `I1` through `I5` in the above example).

Note that any grouping can be represented as a tree, since any node will always have exactly one parent. If, for example, the portfolio used in above example had two positions with different values for the *country*-property (e.g. *JP* and *IT*) but the *same* value for the *issuer*-property (e.g `I6`), then *two* `I6`-nodes would be created — the first with the parent node *JP* and the second with the parent node *IT*. In other words, this would *not* result in a single `I6` node with two parents (*JP* and *IT*).

## Design choices

### Rule input {#sec:rule-input}

All example rules operate on a portfolio. That is, for the purpose of evaluating whether a portfolio complies with a rule, none of the example rules require any input other than the portfolio in question. Consequently, it has been chosen that all rules operate on an implicit input, present in a variable by the name of `Portfolio`. This simplification may need to be reconsidered in future versions of the language (see [Future work/input arguments](#sec:input-arguments) sec. \ref{sec:input-arguments}).

### Input data format {#sec:input-data-format}

A position is represented as a map *from* a **string** property name *to* a property value which is either a **floating point number**, a **string**, or a **boolean**. *Null*-values are not supported, but a position may omit a particular property. In this way, a position representing e.g. a *commodity future* can have a property called `UnderlyingCommodity`, whereas positions of another type (e.g. *bonds*) may omit this property.

Furthermore, the input data must be preprocessed so that the rule language does not need to perform transformations such as converting between different currencies (in order to have a common measure of value). It is thus required that the input data contains a measure of value that is comparable between positions, even though the underlying positions may be denominated in different currencies.

