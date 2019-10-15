-- Unification and matching in an Abelian group
--
-- Copyright (C) 2009 John D. Ramsdell
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- |
-- Module      : Algebra.AbelianGroup.UnificationMatching
-- Copyright   : (C) 2009 John D. Ramsdell
-- License     : GPL
--
-- This module provides unification and matching in an Abelian group.
--
-- In this module, an Abelian group is a free algebra over a signature
-- with three function symbols:
--
--     * the binary symbol +, the group operator,
--
--     * a constant 0, the identity element, and
--
--     * the unary symbol -, the inverse operator.
--
-- The algebra is generated by a set of variables.  Syntactically, a
-- variable is an identifer such as x and y (see 'isVar').
--
-- The axioms associated with the algebra are:
--
-- [Communtativity] x + y = y + x
--
-- [Associativity] (x + y) + z = x + (y + z)
--
-- [Identity Element] x + 0 = x
--
-- [Cancellation] x + -x = 0
--
-- A substitution maps variables to terms.  A substitution s is
-- applied to a term as follows.
--
--      * s(0) = 0
--
--      * s(-t) = -s(t)
--
--      * s(t + t\') = s(t) + s(t\')
--
-- The unification problem is given the problem statement t =? t\',
-- find a most general substitution s such that s(t) = s(t\') modulo
-- the axioms of the algebra.  The matching problem is to find a most
-- general substitution s such that s(t) = t\' modulo the axioms.
-- Substitition s is more general than s\' if there is a substitition
-- s\" such that s\' = s\" o s.

module Algebra.AbelianGroup.UnificationMatching
    (
     -- * Terms
     Term, ide, isVar, var, mul, add, assocs,
     -- * Equations and Substitutions
     Equation(..), Substitution, subst, maplets, apply,
     -- * Unification and Matching
     unify, match) where

import Data.Char (isSpace, isAlpha, isAlphaNum, isDigit)
import Data.Map (Map)
import qualified Data.Map as Map
import Algebra.AbelianGroup.IntLinEq

-- Chapter 8, Section 5 of the Handbook of Automated Reasoning by
-- Franz Baader and Wayne Snyder describes unification and matching in
-- communtative/monoidal theories.  This module refines the described
-- algorithms for the special case of Abelian groups.

-- In this module, an Abelian group is a free algebra over a signature
-- with three function symbols:
--
-- * the binary symbol +, the group operator,
-- * a constant 0, the identity element, and
-- * the unary symbol -, the inverse operator.
--
-- The algebra is generated by a set of variables.  Syntactically, a
-- variable is an identifer such as x and y.

-- The axioms associated with the algebra are:
--
-- * x + y = y + x                 Commutativity
-- * (x + y) + z = x + (y + z)     Associativity
-- * x + 0 = x                     Identity Element
-- * x + -x = 0                    Cancellation

-- A substitution maps variables to terms.  A substitution s is
-- extended to a term as follows.
--
--     s(0) = 0
--     s(-t) = -s(t)
--     s(t + t') = s(t) + s(t')

-- The unification problem is given the problem statement t =? t',
-- find a most general substitution s such that s(t) = s(t') modulo
-- the axioms of the algebra.  The matching problem is to find a most
-- general substitution s such that s(t) = t' modulo the axioms.
-- Substitition s is more general than s' if there is a substitition
-- s" such that s' = s" o s.

-- A term is represented by the identity element, or as the sum of
-- factors.  A factor is the product of a non-zero integer coefficient
-- and a variable.  In this representation, no variable occurs twice.
-- Thus a term is represented by a finite map from variables to
-- non-zero integers.

-- | A term in an Abelian group is represented by the identity
-- element, or as the sum of factors.  A factor is the product of a
-- non-zero integer coefficient and a variable.  No variable occurs
-- twice in a term.  For the show and read methods, zero is the
-- identity element, the plus sign is the group operation, and the
-- minus sign is the group inverse.
newtype Term = Term (Map String Int) deriving Eq

-- Constructors

-- | 'ide' represents the identity element (zero).
ide :: Term
ide = Term Map.empty

-- | A variable is an alphabetic Unicode character followed by a
-- sequence of alphabetic or numeric digit Unicode characters.  The
-- show method for a term works correctly when variables satisfy
-- the 'isVar' predicate.
isVar :: String -> Bool
isVar [] = False
isVar (c:s) = isAlpha c && all isAlphaNum s

-- | Return a term that consists of a single variable.
var :: String -> Term
var x = Term $ Map.singleton x 1

-- | Multiply every coefficient in a term by an integer.
mul :: Int -> Term -> Term
mul 0 (Term _) = ide
mul 1 t = t
mul n (Term t) =
    Term $ Map.map (* n) t

-- Invert a term by negating its coefficients.  Same as multiplying
-- a term by -1.
neg :: Term -> Term
neg (Term t) =
    Term $ Map.map negate t

-- | Add two terms.
add :: Term -> Term -> Term
add (Term t) (Term t') =
    Term $ Map.foldrWithKey f t' t -- Fold over the mappings in t
    where
      f x c t =                 -- Alter the mapping of
          Map.alter (g c) x t   -- variable x in t
      g c Nothing =             -- Variable x not currently mapped
          Just c                -- so add a mapping
      g c (Just c')             -- Variable x maps to c'
          | c + c' == 0 = Nothing     -- Delete the mapping
          | otherwise = Just $ c + c' -- Adjust the mapping

-- | Return all variable-coefficient pairs in the term in ascending
-- variable order.
assocs :: Term -> [(String, Int)]
assocs (Term t) = Map.assocs t

-- | Convert a list of variable-coefficient pairs into a term.
term :: [(String, Int)] -> Term
term assoc =
    foldr f ide assoc
    where
      f (x, c) t = add t $ mul c $ var x

-- Equations and Substitutions

-- | An equation is a pair of terms.  For the show and read methods,
-- the two terms are separated by an equal sign.
newtype Equation = Equation (Term, Term) deriving Eq

-- | A substitution maps variables into terms.  For the show and read
-- methods, the substitution is a list of maplets, and the variable
-- and the term in each element of the list are separated by a colon.
newtype Substitution = Substitution (Map String Term) deriving Eq

-- | Construct a substitution from a list of variable-term pairs.
subst :: [(String, Term)] -> Substitution
subst assocs =
    Substitution $ foldl f Map.empty assocs
    where
      f t (x, n) = Map.insert x n t

-- | Return all variable-term pairs in ascending variable order.
maplets :: Substitution -> [(String, Term)]
maplets (Substitution s) = Map.assocs s

-- | Return the result of applying a substitution to a term.
apply :: Substitution -> Term -> Term
apply (Substitution s) (Term t) =
    Map.foldrWithKey f ide t
    where
      f x n t =
          add (mul n (Map.findWithDefault (var x) x s)) t

-- Unification and Matching

-- | Given 'Equation' (t0, t1), return a most general substitution s
-- such that s(t0) = s(t1) modulo the equational axioms of an Abelian
-- group.  Unification always succeeds.
unify :: Equation -> Substitution
unify (Equation (t0, t1)) =
    case match $ Equation (add t0 (neg t1), ide) of
      Nothing -> error "Internal error--unification failed"
      Just s -> s

-- Matching in Abelian groups is performed by finding integer
-- solutions to linear equations, and then using the solutions to
-- construct a most general unifier.
-- | Given 'Equation' (t0, t1), return a most general substitution s
-- such that s(t0) = t1 modulo the equational axioms of an Abelian
-- group.
match :: MonadFail m => Equation -> m Substitution
match (Equation (t0, t1)) =
    case (assocs t0, assocs t1) of
      ([], []) -> return $ Substitution Map.empty
      ([], _) -> fail "no solution"
      (t0, t1) ->
          do
            subst <- intLinEq (map snd t0, map snd t1)
            return $ mgu (map fst t0) (map fst t1) subst

-- Construct a most general unifier from a solution to a linear
-- equation.  The function adds the variables back into terms, and
-- generates fresh variables as needed.
mgu :: [String] -> [String] -> Subst -> Substitution
mgu vars syms subst =
    Substitution $ foldl f Map.empty (zip vars [0..])
    where
      f s (x, n) =
          case lookup n subst of
            Just (factors, consts) ->
                Map.insert x (g factors consts) s
            Nothing ->
                Map.insert x (var $ genSyms !! n) s
      g factors consts =
          term (zip genSyms factors ++ zip syms consts)
      genSyms = genSymsAvoiding vars syms

-- Generated variables start with this character.
genChar :: Char
genChar = 'g'

-- Generated symbols are the gen start char followed by a number.
genSym :: Int -> String
genSym i = genChar : show i

-- Produce a stream of generated identifiers avoiding what's in vars and syms.
genSymsAvoiding :: [String] -> [String] -> [String]
genSymsAvoiding vars syms =
    genSymStream 0
    where
      seen = filter genStr (syms ++ vars)
      genStr (c:_) = c == genChar
      genStr _ = False
      genSymStream n
          | elem (genSym n) seen = genSymStream (n + 1)
          | otherwise = genSym n : genSymStream (n + 1)

-- So why solve linear equations?  Consider the matching problem
--
--     c[0]*x[0] + c[1]*x[1] + ... + c[n-1]*x[n-1] =?
--         d[0]*a[0] + d[1]*a[1] + ... + d[m-1]*a[m-1]
--
-- with n variables and m constants.  We seek a most general unifier s
-- such that
--
--     s(c[0]*x[0] + c[1]*x[1] + ... + c[n-1]*x[n-1]) =
--         d[0]*a[0] + d[1]*a[1] + ... + d[m-1]*a[m-1]
--
-- which is the same as
--
--     c[0]*s(x[0]) + c[1]*s(x[1]) + ... + c[n-1]*s(x[n-1]) =
--         d[0]*a[0] + d[1]*a[1] + ... + d[m-1]*a[m-1]
--
-- Notice that the number of occurrences of constant a[0] in s(x[0])
-- plus s(x[1]) ... s(x[n-1]) must equal d[0].  Thus the mappings of
-- the unifier that involve constant a[0] respect integer solutions of
-- the following linear equation.
--
--     c[0]*x[0] + c[1]*x[1] + ... + c[n-1]*x[n-1] = d[0]
--
-- To compute a most general unifier, a most general integer solution
-- to a linear equation must be found.  See module
-- Algebra.AbelianGroup.IntLinEq.

-- Elementary Abelian group matching is equivalent to unification with
-- constants.  A proof of correctness of this algorithm, cast as
-- unification with constants, is in Chapter 3, Section 1 of
-- "Programming Languages and Dimensions", Andrew Kennedy's
-- Ph.D. thesis from St. Catharine's College in 1996.

-- Input and Output

instance Show Term where
    showsPrec _ t =
        case assocs t of
          [] -> showString "0"
          (t:ts) -> showFactor t . showl ts
        where
          showFactor (x, 1) = showString x
          showFactor (x, -1) = showChar '-' . showString x
          showFactor (x, c) = shows c . showString x
          showl [] = id
          showl ((s,n):ts)
              | n < 0 =
                  showString " - " . showFactor (s, negate n) . showl ts
          showl (t:ts) = showString " + " . showFactor t . showl ts

instance Read Term where
    readsPrec _ s0 =
        [ (t1, s2)       | (t0, s1) <- readSummand s0,
                           (t1, s2) <- readRest t0 s1 ]
        where
          readPrimary s0 =
              [ (t0, s1) | (x, s1) <- scan s0, isVarToken x,
                           let t0 = var x ] ++
              [ (t0, s1) | ("0", s1) <- scan s0,
                           let t0 = ide ] ++
              [ (t0, s3) | ("(", s1) <- scan s0,
                           (t0, s2) <- reads s1,
                           (")", s3) <- scan s2 ]
          readFactor s0 =
              [ (t0, s1) | (t0, s1) <- readPrimary s0 ] ++
              [ (t1, s2) | (n, s1) <- scan s0, isNumToken n,
                           (t0, s2) <- readPrimary s1,
                           let t1 = mul (read n) t0 ]
          readSummand s0 =
              [ (t0, s1) | (t0, s1) <- readFactor s0 ] ++
              [ (t1, s2) | ("-", s1) <- scan s0,
                           (t0, s2) <- readFactor s1,
                           let t1 = neg t0 ]
          readRest t0 s0 =
              [ (t2, s3) | ("+", s1) <- scan s0,
                           (t1, s2) <- readSummand s1,
                           (t2, s3) <- readRest (add t0 t1) s2 ] ++
              [ (t2, s3) | ("-", s1) <- scan s0,
                           (t1, s2) <- readFactor s1,
                           (t2, s3) <- readRest (add t0 (neg t1)) s2 ] ++
              [ (t0, s0) | (s, _) <- scan s0, s /= "+" && s /= "-" ]

isNumToken :: String -> Bool
isNumToken (c:_) = isDigit c
isNumToken _ = False

isVarToken :: String -> Bool
isVarToken (c:_) = isAlpha c
isVarToken _ = False

scan :: ReadS String
scan "" = [("", "")]
scan (c:s)
    | isSpace c = scan s
    | isAlpha c = [ (c:part, t) | (part,t) <- [span isAlphaNum s] ]
    | isDigit c = [ (c:part, t) | (part,t) <- [span isDigit s] ]
    | otherwise = [([c], s)]

instance Show Equation where
    showsPrec _ (Equation (t0, t1)) =
        shows t0 . showString " = " . shows t1

instance Read Equation where
    readsPrec _ s0 =
        [ (Equation (t0, t1), s3) | (t0, s1) <- reads s0,
                                    ("=", s2) <- scan s1,
                                    (t1, s3) <- reads s2 ]

-- This datatype is used only in the read and show methods for
-- substitutions.
newtype Maplet = Maplet (String, Term) deriving Eq

instance Show Maplet where
    showsPrec _ (Maplet (x, t)) =
        showString x . showString " : " . shows t

instance Read Maplet where
    readsPrec _ s0 =
        [ (Maplet (x, t), s3) | (x, s1) <- scan s0, isVarToken x,
                                (":", s2) <- scan s1,
                                (t, s3) <- reads s2 ]

instance Show Substitution where
    showsPrec _ s =
        shows $ map Maplet $ maplets s

instance Read Substitution where
    readsPrec _ s0 =
        [ (subst $ map pair ms, s1) | (ms, s1) <- reads s0 ]
        where
          pair (Maplet (x, t)) = (x, t)
