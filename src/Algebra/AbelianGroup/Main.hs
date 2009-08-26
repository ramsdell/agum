-- A simple top-level loop for unification and matching in Abelian groups
-- John D. Ramsdell -- August 2009

module Main (main, test) where

import System.Console.Readline (readline)
import Algebra.AbelianGroup.UnificationMatching

-- Test Routine

-- Given an equation, display a unifier and a matcher.
test :: String -> IO ()
test prob =
    case readM prob of
      Err err -> putStrLn err
      Ans (Equation (t0, t1)) ->
          do
            putStr "Problem:   "
            print $ Equation (t0, t1)
            subst <- unify $ Equation (t0, t1)
            putStr "Unifier:   "
            print subst
            putStr "Matcher:   "
            case match $ Equation (t0, t1) of
              Err err -> putStrLn err
              Ans subst -> print subst
            putStrLn ""

readM :: (Read a, Monad m) => String -> m a
readM s =
    case [ x | (x, t) <- reads s, ("", "") <- lex t ] of
      [x] -> return x
      [] -> fail "no parse"
      _ -> fail "ambiguous parse"

data AnsErr a
    = Ans a
    | Err String

instance Monad AnsErr where
    (Ans x) >>= k = k x
    (Err s) >>= _ = Err s
    return        = Ans
    fail          = Err

-- Main loop

main :: IO ()
main =
    do
      putStrLn "Abelian group unification and matching -- :? for help"
      loop

loop :: IO ()
loop =
    do
      maybeLine <- readline "agum> "
      case maybeLine of
        Nothing ->
            do
              putStrLn ""
              return ()
        Just line | line == ":?" || line == ":help" ->
            do
              help
              loop
        Just ":quit" ->
            return ()
        Just line ->
            do
              test line
              loop

help :: IO ()
help =
    mapM_ putStrLn mesg

mesg :: [String]
mesg =
    [ "Pose a question as an equation such as",
      "    2x + y = 3z, or",
      "    2x = x + y, or",
      "    64x - 41y = 1a.",
      "The agum programs shows the result of unification and matching.",
      "",
      ":quit quits the program, :? and :help print this message."]
