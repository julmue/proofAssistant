-- {-# OPTIONS_GHC -Wall -Werror #-}

module Semantics
    ( Semantics (..)
    , Property(..)
    , makeDomain
    , makeSemantics
 --   , makeModels
 --   , makeModelsLookup
    )
where

import Prelude hiding (lookup)

import Control.Applicative ((<$>), (<*>), pure, ZipList(..))
import Data.Function (on)
import Data.List (groupBy)
import Data.Map (fromList, lookup)
import Data.Maybe (fromMaybe)

import Formula hiding (True, False)
import Misc

data Property
    = Valid
    | Sat
    | Unsat
    deriving (Show, Eq)

data TrVals a = TrVals
    { getTrVals :: [a]
    , getDesigTrVals :: [a]
    } deriving (Show, Eq)

-- | class of finite, many-values semantics
data Semantics a b = Semantics {
    trVals :: [b],
    desigTrVals :: [b],
    eval :: Formula b -> Formula b,
    domain :: Formula a -> [a -> b],
    models :: Formula a -> [a -> b],
    modelsLookup :: Formula a -> [(a,b)], -- this is possibly very wrong ...
    valid :: Formula a -> Bool,
    sat :: Formula a -> Bool,
    unsat :: Formula a -> Bool,
    entails :: [Formula a] -> Formula a -> Bool
}

makeSemantics :: (Ord a, Eq b) => TrVals b -> (Formula b -> Formula b) -> Semantics a b
makeSemantics tvs evalFn = Semantics
    { trVals = getTrVals tvs
    , desigTrVals = getDesigTrVals tvs
    , eval = evalFn
    , domain = makeDomain tvs
    , models = makeModels tvs evalFn
    , modelsLookup = makeModelsLookup tvs evalFn
    , unsat = not . (protoSat tvs evalFn)
    , sat = protoSat tvs evalFn
    , valid = protoValid tvs evalFn
    , entails = undefined
    }

protoSat tvs evalFn f = (not . null) (makeModels tvs evalFn f)
protoValid tvs evalFn f = length (makeModels tvs evalFn f) == length (makeDomain tvs f)




-- interpretation / assignment

-- set of possible assignment functions for a formula
-- assignments :: (Eq a, Ord a, Ord b) => [b] -> Formula a -> [a -> b]

-- | function generates the subset of the domain of functions V : P -> TV
--   where possible models of a formula can stem from.
makeDomain :: Ord a => TrVals b -> Formula a -> [a -> b]
makeDomain tvs fm =
    makeAssignmentFn <$> lookupTables
  where makeAssignmentFn :: Ord a => [(a,b)] -> a -> b
        makeAssignmentFn lookupTable a =
            let m = fromList lookupTable
            in fromMaybe (error "Error(Assignment): variable not in assignment function")
               (lookup a m)
        pairsAtomValue = cartProd (atomsSet fm) (getTrVals tvs)
        partitionsByAtom = groupBy ((==) `on` fst) pairsAtomValue
        lookupTables = combination partitionsByAtom
                    -- sequence partitionsByAtom

makeModels :: (Ord a, Eq b) => TrVals b -> (Formula b -> Formula b) -> Formula a -> [a -> b]
makeModels ts eval fm =
    let domain = makeDomain ts fm
        filt = (flip elem) (Atom <$> (getDesigTrVals ts))
        mask = map filt ((eval . ($ fm) . onAtoms) <$> domain)
    in [ m | (m, t) <- domain `zip` mask, t == True ]

makeModelsLookup :: (Ord b, Eq a) => TrVals a -> (Formula a -> Formula a) -> Formula b -> [(b, a)]
makeModelsLookup ts eval fm =
    (fmap (,) $ atomsSet fm) <*> ((makeModels ts eval fm) <*> (atomsSet fm))

{- Todo:
    are there some sensible defaults for valid, unsat and sat,
    that hold in all possible semantics? (not only PC, LPC, ...)
    example for PC:
    -- negation of a tautology yields a contradiction
    valid = F.Not unsat
    -- negation of a contradiciton yields a tautology
    -- -> so its a satisfiable formula
    unsat = sat . F.Not
    valid = unsat . F.Not
    sat = to be implemented
-}


