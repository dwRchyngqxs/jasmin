Require Import wp.
Require Import identity.

Import Utf8.
Import seq.
Import Integers.
Import expr.
Import Ssem.

Goal
  ∀ v,
  hoare program
    (λ _, True)
    [:: MkI xH (Ccall  DoNotInline [:: Lvar x] identity [:: Pcast (Pconst v)]) ]
    (λ s, s.(sevm).[x] = I64.repr v)%vmap.
Proof.
Abort.