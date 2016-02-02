(* * Utility definition for dmasm *)

(* ** Imports and settings *)
Require Import ssreflect ssrfun ssrnat ssrbool seq choice eqtype finmap.
Require Import strings.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope fset.
Local Open Scope fmap.

(* ** LEM
 * -------------------------------------------------------------------- *)

Axiom LEM : forall {T : Type}, forall (x y : T), {x=y}+{x<>y}.

(* ** Admit
 * -------------------------------------------------------------------- *)

Definition admit {T: Type} : T.  Admitted.

(* ** Result monad
 * -------------------------------------------------------------------- *)

Inductive result (A : Type) : Type :=
| Ok of A
| Error of string.

Arguments Error {A} s.

Module Result.

Definition apply aT rT (f : aT -> rT) x u := if u is Ok y then f y else x.

Definition default T := apply (fun x : T => x).

Definition bind aT rT (f : aT -> result rT) g :=
  match g with
  | Ok x    => f x
  | Error s => Error s
  end.

Definition map aT rT (f : aT -> rT) := bind (fun x => Ok (f x)).

End Result.

Definition o2r aT (es : string) (o : option aT) :=
  match o with
  | None   => Error es
  | Some x => Ok x
  end.

Notation rapp  := Result.apply.
Notation rdflt := Result.default.
Notation rbind := Result.bind.
Notation rmap  := Result.map.
Notation ok    := (@Ok _) (only parsing).

Notation "m >>= f" := (rbind f m) (at level 25, left associativity).

Fixpoint mapM aT bT (f : aT -> result bT) (xs : seq aT) : result (seq bT) :=
  match xs with
  | [::] =>
      Ok [::]
  | [:: x & xs] =>
      f x >>= fun y =>
      mapM f xs >>= fun ys =>
      Ok [:: y & ys]
  end.

Fixpoint foldM aT bT (f : aT -> bT -> result bT) (acc : bT) (l : seq aT) :=
  match l with
  | [::]         => Ok acc
  | [:: a & la ] => f a acc >>= fun acc => foldM f acc la
  end.

(* ** Misc functions
 * -------------------------------------------------------------------- *)

Definition isSome aT (o : option aT) :=
  if o is Some _ then true else false.

Fixpoint list_to_rev (ub : nat) :=
  match ub with
  | O    => [::]
  | x.+1 => [:: x & list_to_rev x ]
  end.

Definition list_to ub := rev (list_to_rev ub).

Definition list_from_to (lb : nat) (ub : nat) :=
  map (fun x => x + lb)%nat (list_to (ub - lb)).

Definition conc_map aT bT (f : aT -> seq bT) (l : seq aT) :=
  flatten (map f l).

Fixpoint unions_seq (K : choiceType) (ss : seq {fset K}) : {fset K} :=
  match ss with
  | [::]         => fset0
  | [:: x & xs ] => x `|` unions_seq xs
  end.

Definition unions (K : choiceType) (ss : {fset {fset K}}) : {fset K} :=
  unions_seq (fset_keys ss).

Lemma unions_set_map_fset1 (aT : choiceType) (vs : seq aT):
  unions_seq (map fset1 vs) = seq_fset vs.
Proof.
elim: vs; last by move=> v vs; rewrite /= fset_cons => ->.
by rewrite /=; apply/fsetP => x; rewrite in_seq_fsetE in_fset0 in_nil.
Qed.

Definition oeq aT (f : aT -> aT -> Prop) (o1 o2 : option aT) :=
  match o1, o2 with
  | Some x1, Some x2 => f x1 x2
  | None,    None    => true
  | _ ,      _       => false
  end.

Definition req aT (f : aT -> aT -> Prop) (o1 o2 : result aT) :=
  match o1, o2 with
  | Ok x1,   Ok x2   => f x1 x2
  | Error _, Error _ => true
  | _ ,      _       => false
  end.

(* ** Fmap equality on subset of keys
 * -------------------------------------------------------------------- *)

Definition eq_on (K : choiceType) V (s : {fset K}) (m1 m2 : {fmap K -> V}) :=
  m1.[& s] = m2.[& s]. (* FIXME: maybe this should be just a notation? *)

Notation "m1 = m2 [& s ]" := (eq_on s m1 m2) (at level 70, m2 at next level,
  format "'[hv ' m1  '/' =  m2  '/' [&  s ] ']'").

Section EqOn.

Variable K : choiceType.
Variable V : Type.

Lemma eq_on_fsubset (s1 s2 : {fset K}) (m1 m2 : {fmap K -> V}):
  s1 `<=` s2 ->
  m1 = m2 [& s2] ->
  m1 = m2 [& s1].
Proof.
rewrite /eq_on; move=> Hsub Hs2.
move: (f_equal (fun m => m.[& s1]) Hs2); rewrite !restrictf_comp.
by rewrite (_ : s2 `&` s1 = s1); [ | exact (fsetIidPr Hsub) ].
Qed.

Lemma eq_on_Ur(s1 s2 : {fset K}) (m1 m2 : {fmap K -> V}):
  m1 = m2 [& s1 `|` s2] ->
  m1 = m2 [& s2].
Proof. by apply eq_on_fsubset; apply /fsetUidPr; rewrite fsetUCA fsetUid /=. Qed.

Lemma eq_on_Ul(s1 s2 : {fset K}) (m1 m2 : {fmap K -> V}):
  m1 = m2 [& s1 `|`  s2]->
  m1 = m2 [& s1].
Proof. by apply eq_on_fsubset; apply /fsetUidPr; rewrite fsetUA fsetUid /=. Qed.

Lemma eq_on_U(s1 s2 : {fset K}) (m1 m2 : {fmap K -> V}):
  m1 = m2 [& s1 `|`  s2] ->
  m1 = m2 [& s1] /\ m1 = m2 [& s2].
Proof. by move=> HU; split; [ apply: eq_on_Ul HU | apply: eq_on_Ur HU ]. Qed.

Lemma eq_on_get_in (s : {fset K}) (m1 m2 : {fmap K -> V}) (k : K) :
  m1 = m2 [& s] ->
  k \in s ->
  m1.[? k] = m2.[? k].
Proof.
move=> Heq_on Hin.
rewrite (_: m1.[? k] = m1.[& s].[? k]). 
+ by rewrite Heq_on fnd_restrict Hin.
by rewrite fnd_restrict Hin.
Qed.

Lemma eq_on_get_fset1 (m1 m2 : {fmap K -> V}) (k : K) :
  m1 = m2 [& [fset k]] ->
  m1.[? k] = m2.[? k].
Proof. by move=> Heq_on; apply: (eq_on_get_in Heq_on); rewrite in_fset1. Qed.

Lemma eq_on_setf_same (s : {fset K}) (m1 m2 : {fmap K -> V}) k v:
  m1 = m2 [& s] ->
  m1.[k <- v] = m2.[k <- v] [& s].
Proof. by rewrite /eq_on !restrictf_set /= => ->. Qed.

End EqOn.

Definition req_on (K : choiceType) V (s : {fset K}) (m1 m2 : result {fmap K -> V}) :=
  req (eq_on s) m1 m2.

Notation "m1 = m2 [&& s ]" := (req_on s m1 m2) (at level 70, m2 at next level,
  format "'[hv ' m1  '/' =  m2  '/' [&&  s ] ']'").

Section ReqOn.

Variable K : choiceType.
Variable V : Type.

Lemma req_on_rbind (om1 om2 : {fmap K -> V} -> result {fmap K -> V})
    (m1 m2 : {fmap K -> V}) ks:
  m1 = m2 [& ks] ->
  om1 m1 = om1 m2 [&& ks] ->
  (forall m1_ m2_,
    m1_ = m2_ [& ks] ->
    om2 m1_ = om2 m2_ [&& ks]) ->
  (om1 m1 >>= fun m1_ => om2 m1_) = (om1 m2 >>= fun m2_ => om2 m2_) [&& ks].
Proof.
move=> Heq Hom1_eq Hom2_eq.
by move: Hom1_eq; case (om1 m2); case (om1 m1) => //=.
Qed.

Lemma req_on_ofold (aT : eqType) (step : aT -> {fmap K -> V} -> result {fmap K -> V})
    ks (ws : seq aT):
  forall (m1 m2 : {fmap K -> V}),
    m1 = m2 [& ks] ->
    (forall (m1_ m2_ : {fmap K -> V}) (w : aT),
      w \in ws ->
      m1_ = m2_ [& ks] ->
      step w m1_ = step w m2_ [&& ks]) ->
    foldM step m1 ws = foldM step m2 ws [&& ks].
Proof.
elim: ws => //= w ws IH m1 m2 Heq Hinv.
apply:
  (@req_on_rbind
     (fun m => step w m) (fun m => foldM step m ws)
     m1 m2 ks Heq).
+ by apply Hinv => //=; apply mem_head.
move=> m1_ m2_ Heq_.
apply: (IH m1_ m2_ Heq_).
move=> m1__ m2__ w__ Hin__ Heq__.
apply: Hinv => //=.
by rewrite in_cons; apply /orP; right.
Qed.

Lemma req_on_refl (m : result {fmap K -> V}) (ks : {fset K}):
  m = m [&& ks].
Proof. by rewrite /req_on /req; case m. Qed.

End ReqOn.