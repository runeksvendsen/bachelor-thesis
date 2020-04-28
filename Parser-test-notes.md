# `And`/`Let` associativity/precedence


And (Let "a" (Literal (Integer 0)) (Rule (Comparison (Literal (Integer 0)) Eq (Literal (Integer 0))))) (Rule (Comparison (Literal (Integer 0)) Eq (Literal (Integer 0))) :| [])

Let "a" (Literal (Integer 0)) (And (Rule (Comparison (Literal (Integer 0)) Eq (Literal (Integer 0)))) (Rule (Comparison (Literal (Integer 0)) Eq (Literal (Integer 0))) :| []))


    let a = 0
    rule: 0 == 0
    rule: 0 == 0

x + y * z

let (expr1 & expr2)

# `VarOr`

* Only adds a single additional option: a var
* Versus: `ValueExpr` which adds all value types (also a lot of invalid ones)
* Explosion in complexity (+1 versus +N complexity of possible values)

# `==` and `GroupOp` precedence

**False alarm** (not discarding whitespace before `relative` keyword)

```
Rule (NotVar (Comparison (Var "a") Eq (NotVar (GroupOp (Relative (Var "a") (Var "a"))))))
   this fails to parse:

       rule: a == a relative to a

       error:
       1:14:
         |
       1 | rule: a == a relative to a
         |              ^
       unexpected 'r'
       expecting "AND", "OR", or end of input
```

# TMP

```
Rule (NotVar (And (NotVar (And (NotVar (Comparison (NotVar (Literal (Percent (Number' 0.0)))) Eq (NotVar (Literal (Percent (Number' 0.0)))))) (NotVar (Comparison (NotVar (Literal (Percent (Number' 0.0)))) Eq (NotVar (Literal (Percent (Number' 0.0)))))))) (Var "a"))) 

       rule: 0.0% == 0.0% AND 0.0% == 0.0% AND a

Rule (NotVar (And (NotVar (Comparison (NotVar (Literal (Percent (Number' 0.0)))) Eq (NotVar (Literal (Percent (Number' 0.0)))))) (NotVar (And (NotVar (Comparison (NotVar (Literal (Percent (Number' 0.0)))) Eq (NotVar (Literal (Percent (Number' 0.0)))))) (Var "a")))))
```

