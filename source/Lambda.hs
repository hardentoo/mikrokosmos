{-|
Module: Lambda
Description: DeBruijn lambda expressions.
License: GPL-3

This module deals with the parsing, reduction and printing of lambda
expressions using DeBruijn notation. The interpreter uses DeBruijn
notation as an internal representation and as output format. This is because
it is easier to do beta reduction with DeBruijn indexes.
-}

module Lambda
  ( Exp (Var, Lambda, App, Literal)
  , simplifyAll
  , simplifySteps
  , showReduction
  )
where

import Format

-- DeBruijn Expressions
-- | A lambda expression using DeBruijn indexes.
data Exp = Var Integer    -- ^ integer indexing the variable.
         | Lambda Exp     -- ^ lambda abstraction.
         | App Exp Exp    -- ^ function application.
         | Literal String -- ^ a literal of the language.
         deriving (Eq, Ord)

instance Show Exp where
  show = showexp


-- | Shows an expression with DeBruijn indexes.
showexp :: Exp -> String
showexp (Var n)     = show n
showexp (Lambda e)  = "λ" ++ showexp e ++ ""
showexp (App f g)   = "(" ++ showexp f ++ " " ++ showexp g ++ ")"
showexp (Literal s) = "\"" ++ s ++ "\""

-- | Shows an expression coloring the next reduction.
showReduction :: Exp -> String
showReduction (Lambda e)         = "λ" ++ showReduction e
showReduction (App (Lambda f) x) = betaColor (App (Lambda f) x)
showReduction (Var e)            = show e
showReduction (Literal s)        = "\"" ++ s ++ "\""
showReduction (App rs x)         = "(" ++ showReduction rs ++ " "
                                       ++ showReduction x ++ ")"

-- | Colors a beta reduction
betaColor :: Exp -> String
betaColor (App (Lambda e) x) =
  "(" ++
  formatSubs1 ++ "λ" ++ formatFormula ++
  indexColor 1 e ++
  " " ++
  formatSubs2 ++ showexp x ++ formatFormula
  ++ ")"
betaColor e = show e

-- | Colors all the appearances of a given index
indexColor :: Integer -> Exp -> String
indexColor n (Lambda e)  = "λ" ++ indexColor (succ n) e
indexColor n (App f g)   = "(" ++ indexColor n f ++ " " ++ indexColor n g ++ ")"
indexColor _ (Literal s) = show s
indexColor n (Var m)
  | n == m    = formatSubs1 ++ show m ++ formatFormula
  | otherwise = show m




-- Reductions of lambda expressions.

-- | Applies repeated simplification to the expression until it stabilizes and
-- returns the final simplified expression.
--
-- >>> simplifyAll $ App (Lambda (Var 1)) (Lambda (Var 1))
-- λ1
--
simplifyAll :: Exp -> Exp
simplifyAll = last . simplifySteps

-- | Applies repeated simplification to the expression until it stabilizes and
-- returns all the intermediate results.
--
-- >>> simplifySteps $ App (Lambda (Var 1)) (Lambda (Var 1))
-- [(λ1 λ1),λ1]
--
simplifySteps :: Exp -> [Exp]
simplifySteps e
  | e == s    = [e]
  | otherwise = e : simplifySteps s
  where s = simplify e

-- | Simplifies the expression recursively.
-- Applies only a beta reduction at each step.
simplify :: Exp -> Exp
simplify (Lambda e)          = Lambda (simplify e)
simplify (App (Lambda f) x)  = betared (App (Lambda f) x)
simplify (App (Var e) x)     = App (Var e) (simplify x)
simplify (App (App f g) x)   = App (simplify (App f g)) x
simplify (App (Literal s) (Literal t)) = Literal (s ++ t)
simplify (App (Literal s) x) = App (Literal s) (simplify x)
simplify (Var e)             = Var e
simplify (Literal s)         = Literal s

-- | Applies beta-reduction to a function application.
-- Leaves the rest of the operations untouched.
betared :: Exp -> Exp
betared (App (Lambda e) x) = substitute 1 x e
betared e = e

-- | Substitutes an index for a lambda expression
substitute :: Integer -- ^ deBruijn index of the desired target
           -> Exp     -- ^ replacement for the index
           -> Exp     -- ^ initial expression
           -> Exp
substitute n x (Lambda e)  = Lambda (substitute (succ n) (incrementFreeVars 0 x) e)
substitute n x (App f g)   = App (substitute n x f) (substitute n x g)
substitute _ _ (Literal s) = Literal s
substitute n x (Var m)
  -- The lambda is replaced directly
  | n == m    = x
  -- A more exterior lambda decreases a number
  | n <  m    = Var (m-1)
  -- An unrelated variable remains untouched
  | otherwise = Var m

-- | Increments free variables assuming they are bind to an
-- external lambda. This is done to substitute them correctly in
-- internal expressions.
incrementFreeVars :: Integer -> Exp -> Exp
incrementFreeVars n (App f g)  = App (incrementFreeVars n f) (incrementFreeVars n g)
incrementFreeVars n (Lambda e) = Lambda (incrementFreeVars (succ n) e)
incrementFreeVars _ (Literal s) = Literal s
incrementFreeVars n (Var m)
  | m > n     = Var (succ m)
  | otherwise = Var m
