-- |
-- Module      :  Data.Foldable.Constrained
-- Copyright   :  (c) 2014 Justus Sagemüller
-- License     :  GPL v3 (see COPYING)
-- Maintainer  :  (@) sagemuej $ smail.uni-koeln.de
-- 
{-# LANGUAGE ConstraintKinds              #-}
{-# LANGUAGE TypeFamilies                 #-}
{-# LANGUAGE FunctionalDependencies       #-}
{-# LANGUAGE TypeOperators                #-}
{-# LANGUAGE FlexibleContexts             #-}
{-# LANGUAGE FlexibleContexts             #-}
{-# LANGUAGE KindSignatures               #-}
{-# LANGUAGE ScopedTypeVariables          #-}
{-# LANGUAGE TupleSections                #-}


module Data.Foldable.Constrained
           ( module Control.Category.Constrained 
           , Foldable(..)
           ) where


import Control.Category.Constrained
import Control.Functor.Constrained
import Control.Applicative.Constrained

import Prelude hiding (
     id, (.), ($)
   , Functor(..)
   , uncurry, curry
   , mapM_
   )
import Data.Monoid

import qualified Control.Category.Hask as Hask
import qualified Control.Arrow as A

import Control.Arrow.Constrained




-- forM_ :: (Monad m k, Function k, Object k a, Object k b, Object k (m b), Object k ())
--         => [a] -> a `k` m b -> m ()
-- forM_ [] f = pure ()
-- forM_ (x:xs) f = (f $ x) >> forM_ xs f
-- 
class (Functor t k l) => Foldable t k l where
  ffoldl :: ( Object k a, Object k b, PairObject k a b
            , Object l a, Object l (t b), PairObject l a (t b)
            ) => k (a,b) a -> l (a,t b) a
  foldMap :: ( Object k a, Object l (t a), Monoid m, Object k m, Object l m )
               => (a `k` m) -> t a `l` m
--  mapM_ :: ( Monoidal f l l, Monoidal f k k, Monoid (UnitObject k)
--           , Object k a, Object l (t a)
--           ) => a `k` f (UnitObject k) -> t a `l` f (UnitObject l)
--
fold :: (Foldable t k k, Monoid m, Object k m, Object k (t m)) => t m `k` m
fold = foldMap id

newtype Endo' k a = Endo' { runEndo' :: k a a }
instance (Category k, Object k a) => Monoid (Endo' k a) where
  mempty = Endo' id
  mappend (Endo' f) (Endo' g) = Endo' $ f . g

newtype Monoidal_ (r :: * -> * -> *) (s :: * -> * -> *) (f :: * -> *) (u :: *) 
      = Monoidal { runMonoidal :: f u }
instance ( Monoidal f k k, Function k
         , u ~ UnitObject k, Monoid u 
         , PairObject k u u, PairObject k (f u) (f u), Object k (f u,f u)
         ) => Monoid (Monoidal_ k k f u) where
  mempty = memptyMdl
  mappend = mappendMdl

memptyMdl :: forall r s f u v . ( Monoidal f r s, Function s
                                , PairObject s u u, Monoid v
                                , u~UnitObject r, v~UnitObject s )
               => Monoidal_ r s f u
memptyMdl = Monoidal ((pureUnit :: s v (f u)) $ mempty)
mappendMdl :: forall r s f u v . ( Monoidal f r s, Function s
                                , PairObject r u u, PairObject s (f u) (f u)
                                , Object s (f u, f u), Monoid v
                                , u~UnitObject r, v~UnitObject s )
               => Monoidal_ r s f u -> Monoidal_ r s f u -> Monoidal_ r s f u
mappendMdl (Monoidal x) (Monoidal y) 
      = Monoidal (combine $ (x, y))
 where combine :: s (f u, f u) (f u)
       combine = fzipWith detachUnit



instance Foldable [] (->) (->) where
  foldMap _ [] = mempty
  foldMap f (x:xs) = f x <> foldMap f xs
  -- mapM_ _ [] = pureUnit mempty
  -- mapM_ f (x:xs) = fzipWith detachUnit (f x, mapM_ f xs)
  ffoldl f = uncurry $ foldl (curry f)

instance Foldable Maybe (->) (->) where
  foldMap f Nothing = mempty
  foldMap f (Just x) = f x
  -- mapM_ _ Nothing = pureUnit mempty
  -- mapM_ f (Just x) = f x
  ffoldl _ (i,Nothing) = i
  ffoldl f (i,Just a) = f(i,a)


instance ( Foldable f s t, Arrow s (->), Arrow t (->)
         , Functor f (ConstrainedCategory s o) (ConstrainedCategory t o) 
         -- , UnitObject (ConstrainedCategory t o) ~ UnitObject s 
         ) => Foldable f (ConstrainedCategory s o) (ConstrainedCategory t o) where
  foldMap (ConstrainedMorphism f) = ConstrainedMorphism $ foldMap f
  ffoldl (ConstrainedMorphism f) = ConstrainedMorphism $ ffoldl f
--  mapM_ = mapM_Cs 
--
mapM_ :: forall t k l o f a uk ul .
           ( Foldable t k l, Arrow k (->), Arrow l (->)
           , Functor t k l, Monoidal f l l, Monoidal f k k
           , Object k a, Object l (t a)
           , PairObject l (f ul) (t a), PairObject k (f ul) a
           , Object l (f ul, t a), Object l (ul, t a), Object l (t a, ul)
           , PairObject l ul (t a), PairObject l (t a) ul
           , PairObject k (f ul) (f ul), PairObject k ul ul
           , Object k (f ul, f ul), Object k (f ul, a)
           , uk ~ UnitObject k, ul ~ UnitObject l, uk ~ ul
           ) => a `k` f uk -> t a `l` f ul
mapM_ f = ffoldl q . first pureUnit . swap . attachUnit
    where q :: k (f uk, a) (f uk)
          q = fzipWith detachUnit . second f
--   -- mapM_ f = arr runMonoidal . foldMap (arr Monoidal . f)
--   mapM_ (ConstrainedMorphism f) = arr mM_
--    where mM_ [] = pure `inCategoryOf` f $ mempty
--          mM_ (x:xs) = fzipWith (arr $ uncurry mappend) `inCategoryOf` f 
--                                                 $ (f $ x, mM_ xs)
-- 
