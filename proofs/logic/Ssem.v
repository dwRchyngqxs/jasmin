(* ** License
 * -----------------------------------------------------------------------
 * Copyright 2016--2017 IMDEA Software Institute
 * Copyright 2016--2017 Inria
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * ----------------------------------------------------------------------- *)

(* * New semantic which is "unsafe" (may not fail on invalid code) but simplifies the Hoare logic *)

(* ** Imports and settings *)
Require Import strings word utils type var expr sem.
Require Import low_memory psem.
Import all_ssreflect all_algebra zmodp.
Import ZArith.

Require Import Utf8.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Open Scope string_scope.

(* ** Type interpretation
 * -------------------------------------------------------------------- *)

Variant sstype : Type := ssbool | ssint | ssarr of wsize | ssword of wsize.

Coercion sstype_of_stype (ty: stype) : sstype :=
  match ty with
  | sbool    => ssbool
  | sint     => ssint
  | sarr s _ => ssarr s
  | sword s  => ssword s
  end.

Definition ssem_t (t : sstype) : Type :=
  match t with
  | ssbool   => bool
  | ssint    => Z
  | ssarr s  => FArray.array (word s)
  | ssword s => word s
  end.

Definition sdflt_val st : ssem_t st :=
  match st with
  | ssbool   => false
  | ssint    => Z0
  | ssarr s  => FArray.cnst 0%R
  | ssword s => 0%R
  end.

(* ** Values
  * -------------------------------------------------------------------- *)

Variant svalue : Type :=
  | SVbool   :> bool                   -> svalue
  | SVint    :> Z                      -> svalue
  | SVarr  s : FArray.array (word s)   -> svalue
  | SVword s : (word s)                -> svalue.

Definition svalues := seq svalue.

Definition sto_bool v :=
  match v with
  | SVbool b => ok b
  | _        => type_error
  end.

Definition sto_int v :=
  match v with
  | SVint z => ok z
  | _       => type_error
  end.

Definition sto_arr sz (v: svalue) : exec (FArray.array (word sz)) :=
  if v is SVarr s t then
    if wsize_eq_dec s sz is left eqsz then ok (eq_rect s (λ s, FArray.array (word s)) t sz eqsz)
    else type_error
  else type_error.

Definition sto_word sz v :=
  match v with
  | SVword sz' w => truncate_word sz w
  | _            => type_error
  end.

Definition sto_pointer : svalue → exec pointer :=
  sto_word _.

Definition sval_sstype (v: svalue) : sstype :=
  match v with
  | SVbool _    => ssbool
  | SVint  _    => ssint
  | SVarr sz  _ => ssarr sz
  | SVword sz _ => ssword sz
  end.

Definition of_sval t : svalue -> exec (ssem_t t) :=
  match t return svalue -> exec (ssem_t t) with
  | ssbool      => sto_bool
  | ssint       => sto_int
  | ssarr sz    => sto_arr sz
  | ssword sz   => sto_word sz
  end.

Definition to_sval t : ssem_t t -> svalue :=
  match t return ssem_t t -> svalue with
  | ssbool      => SVbool
  | ssint       => SVint
  | ssarr sz    => @SVarr sz
  | ssword sz   => @SVword sz
  end.

(* ** Traduction of Arrays into Farrays & Truncation of Farrays
 * -------------------------------------------------------------------- *)

Definition word_array_to_farray {n} {s} (a : Array.array n (word s)) : FArray.array (word s):=
  FArray.of_fun 
    (fun i => match Array.get a i with
     | Ok z => z
     | _    => sdflt_val (ssword s)
     end).

Definition truncate_farray {s} s' (a : FArray.array (word s)) : FArray.array (word s'):=
  FArray.of_fun 
    (fun i => match truncate_word s' (FArray.get a i) with
     | Ok z => z
     | _    => sdflt_val (ssword s')
     end).

(* ** Variable map
 * -------------------------------------------------------------------- *)
Delimit Scope svmap_scope with svmap.

Notation svmap    := (Fv.t ssem_t).
Notation svmap0   := (@Fv.empty ssem_t (fun x => sdflt_val x.(vtype))).

Definition sget_var (m:svmap) x :=
  @to_sval (vtype x) (m.[x]%vmap).

Definition sset_var (m: svmap) x v :=
  on_vu (λ v, m.[x <- v]%vmap)
        (if x.(vtype) is sword _ then type_error
         else ok m)
        (of_sval (vtype x) v).

(* ** Parameter expressions
 * -------------------------------------------------------------------- *)

Definition ssem_prod ts tr := lprod (map ssem_t ts) tr.

Definition mk_ssem_sop1 t1 tr (o:ssem_t t1 -> ssem_t tr) v1 :=
  Let v1 := of_sval t1 v1 in
  ok (@to_sval tr (o v1)).

Definition mk_ssem_sop2 t1 t2 tr (o:ssem_t t1 -> ssem_t t2 -> ssem_t tr) v1 v2 :=
  Let v1 := of_sval t1 v1 in
  Let v2 := of_sval t2 v2 in
  ok (@to_sval tr (o v1 v2)).

Definition ssem_op1_b    := @mk_ssem_sop1 sbool sbool.
Definition ssem_op1_i    := @mk_ssem_sop1 sint sint.
Definition ssem_op1_w sz := @mk_ssem_sop1 (sword sz) (sword sz).

Definition ssem_zeroext (sz: wsize) (v: svalue) : exec svalue :=
  match v with
  | SVword sz' w' => ok (SVword (@zero_extend sz sz' w'))
  | _             => type_error
  end.

Definition ssem_sop1 (o:sop1) :=
  match o with
  | Oword_of_int sz => @mk_ssem_sop1 ssint (ssword sz) (wrepr sz)
  | Oint_of_word sz => @mk_ssem_sop1 (ssword sz) ssint wunsigned
  | Osignext sz sz' => @mk_ssem_sop1 (ssword sz') (ssword sz) (@sign_extend sz sz')
  | Ozeroext sz sz' => @mk_ssem_sop1 (ssword sz') (ssword sz) (@zero_extend sz sz')
  | Onot           => ssem_op1_b negb
  | Olnot sz       => @ssem_op1_w sz wnot
  | Oneg Op_int    => ssem_op1_i Z.opp
  | Oneg (Op_w sz) => @ssem_op1_w sz -%R
  end%R.

Definition ssem_op2_b     := @mk_ssem_sop2 sbool sbool sbool.
Definition ssem_op2_i     := @mk_ssem_sop2 sint  sint  sint.
Definition ssem_op2_w sz  := @mk_ssem_sop2 (sword sz) (sword sz) (sword sz).
Definition ssem_op2_w8 sz := @mk_ssem_sop2 (sword sz) sword8 (sword sz).
Definition ssem_op2_ib    := @mk_ssem_sop2 sint  sint  sbool.
Definition ssem_op2_wb sz := @mk_ssem_sop2 (sword sz) (sword sz) sbool.

Definition ssem_sop2 (o:sop2) :=
  match o with
  | Oand           => ssem_op2_b andb     
  | Oor            => ssem_op2_b orb

  | Oadd Op_int    => ssem_op2_i Z.add
  | Oadd (Op_w sz) => @ssem_op2_w sz +%R
  | Osub Op_int    => ssem_op2_i Z.sub
  | Osub (Op_w sz) => ssem_op2_w (λ x y : word sz, x - y)%R
  | Omul Op_int    => ssem_op2_i Z.mul
  | Omul (Op_w sz) => @ssem_op2_w sz *%R

  | Odiv Cmp_int     => ssem_op2_i Z.div
  | Odiv (Cmp_w u s) => @ssem_op2_w s (signed wdiv wdivi u)
  | Omod Cmp_int     => ssem_op2_i Z.modulo
  | Omod (Cmp_w u s) => @ssem_op2_w s (signed wmod wmodi u)

  | Oland sz       => @ssem_op2_w sz wand
  | Olor sz        => @ssem_op2_w sz wor
  | Olxor sz       => @ssem_op2_w sz wxor
  | Olsr sz        => @ssem_op2_w8 sz sem_shr
  | Olsl sz        => @ssem_op2_w8 sz sem_shl
  | Oasr sz        => @ssem_op2_w8 sz sem_sar

  | Oeq Op_int     => ssem_op2_ib Z.eqb
  | Oeq (Op_w sz)  => @ssem_op2_wb sz eq_op
  | Oneq Op_int    => ssem_op2_ib (fun x y => negb (Z.eqb x y))
  | Oneq (Op_w sz) => ssem_op2_wb (λ x y : word sz, x != y)
  | Olt Cmp_int    => ssem_op2_ib Z.ltb
  | Ole Cmp_int    => ssem_op2_ib Z.leb
  | Ogt Cmp_int    => ssem_op2_ib Z.gtb
  | Oge Cmp_int    => ssem_op2_ib Z.geb
  | Olt (Cmp_w sg sz)   => @ssem_op2_wb sz (wlt sg)
  | Ole (Cmp_w sg sz)   => @ssem_op2_wb sz (wle sg)
  | Ogt (Cmp_w sg sz)   => ssem_op2_wb (λ x y : word sz, wlt sg y x)
  | Oge (Cmp_w sg sz)   => ssem_op2_wb (λ x y : word sz, wle sg y x)

  | Ovadd ve ws     => @ssem_op2_w  ws (sem_vadd ve)
  | Ovsub ve ws     => @ssem_op2_w  ws (sem_vsub ve)
  | Ovmul ve ws     => @ssem_op2_w  ws (sem_vmul ve)
  | Ovlsr ve ws     => @ssem_op2_w8 ws (sem_vshr ve)
  | Ovlsl ve ws     => @ssem_op2_w8 ws (sem_vshl ve)
  | Ovasr ve ws     => @ssem_op2_w8 ws (sem_vsar ve)
  end.

Definition value_of_svalue (v: svalue) : exec value :=
  match v with
  | SVbool b => ok (Vbool b)
  | SVint z => ok (Vint z)
  | SVarr _ _ => type_error
  | SVword sz w => ok (Vword w)
  end.

Definition svalue_of_value (v: value) : svalue :=
  match v with
  | Vbool b => SVbool b
  | Vint z => SVint z
  | Varr sz n t => SVarr (FArray.of_fun (λ x, match Array.get t x with Error _ => 0%R | Ok e => e end))
  | Vword sz w => SVword w
  | Vundef ty =>
    match ty with
    | sbool => SVbool (sdflt_val sbool)
    | sint => SVint (sdflt_val sint)
    | sarr sz _ => SVarr (FArray.of_fun (λ _, sdflt_val (sword sz)))
    | sword sz => SVword (sdflt_val (sword sz))
    end
  end.

Definition svalues_of_values (vs: values) : svalues := map svalue_of_value vs.

Definition ssem_sopn (op: sopn) (vs: svalues) : exec svalues :=
  mapM value_of_svalue vs >>= exec_sopn op >>= λ r, ok (svalues_of_values r).

Definition sem_opN (op: opN) (vs: svalues) : exec svalue :=
  Let ws := mapM value_of_svalue vs in
  Let r := app_sopn _ (sem_opN_typed op) ws in
  ok (svalue_of_value (to_val r)).

Import UnsafeMemory.

Record sestate := SEstate {
  semem : mem;
  sevm  : svmap
}.

Definition son_arr_var A (s: sestate) (x: var) (f: forall sz n, FArray.array (word sz) → exec A) :=
  match vtype x as t return ssem_t t → exec A with
  | sarr sz n => f sz n
  | _ => λ _, type_error
  end  (s.(sevm).[ x ]%vmap).

Notation "'SLet' ( sz , n , t ) ':=' s '.[' x ']' 'in' body" :=
  (@son_arr_var _ s x (fun sz n (t:FArray.array (word sz)) => body)) (at level 25, s at level 0).

Definition sget_global gd g : svalue :=
  if get_global_value gd g is Some z 
  then SVword (wrepr (size_of_global g) z)
  else SVword (sdflt_val (sword (size_of_global g))).

Section SSEM_PEXPR.

Context (gd: glob_decls).

Fixpoint ssem_pexpr (s:sestate) (e : pexpr) : exec svalue :=
  match e with
  | Pconst z    => ok (SVint z)
  | Pbool b     => ok (SVbool b)
  | Parr_init sz _ => ok (@SVarr sz (FArray.cnst 0%R))
  | Pvar v    => ok (sget_var s.(sevm) v)
  | Pglobal g => ok (sget_global gd g)
  | Pget x e  =>
    SLet (sz, n, t) := s.[x] in
    Let i := ssem_pexpr s e >>= sto_int in
    let w := FArray.get t i in
    ok (SVword w)
  | Pload sz x e => 
    Let w1 := ok (sget_var s.(sevm) x) >>= sto_pointer in
    Let w2 := ssem_pexpr s e >>= sto_pointer in
    let w := read_mem s.(semem) (w1 + w2) sz in
    ok (@to_sval (sword sz) w)
  | Papp1 o e =>
    Let v := ssem_pexpr s e in
    ssem_sop1 o v
  | Papp2 o e1 e2 =>
    Let v1 := ssem_pexpr s e1 in
    Let v2 := ssem_pexpr s e2 in
    ssem_sop2 o v1 v2
  | PappN op es =>
    Let vs := mapM (ssem_pexpr s) es in
    sem_opN op vs
  | Pif e e1 e2 =>
    Let b  := ssem_pexpr s e >>= sto_bool in
    Let v1 := ssem_pexpr s e1 in
    Let v2 := ssem_pexpr s e2 in
    Let _ := of_sval (sval_sstype v1) v1 in
    Let _ := of_sval (sval_sstype v1) v2 in
    ok (if b then v1 else v2)
  end.

Definition ssem_pexprs s := mapM (ssem_pexpr s).

Definition swrite_var (x:var_i) (v:svalue) (s:sestate) : exec sestate :=
  Let vm := sset_var s.(sevm) x v in
  ok {| semem := s.(semem); sevm := vm |}.

Definition swrite_vars xs vs s :=
  fold2 ErrType swrite_var xs vs s.

Definition swrite_lval (l:lval) (v:svalue) (s:sestate) : exec sestate :=
  match l with
  | Lnone _ _   => ok s
  | Lvar x      => swrite_var x v s
  | Lmem sz x e =>
    Let vx := sto_pointer (sget_var (sevm s) x) in
    Let ve := ssem_pexpr s e >>= sto_pointer in
    let p := (vx + ve)%R in  (* should we add the size of value, i.e vx + sz * se *)
    Let w := sto_word sz v in
    let m := write_mem s.(semem) p w in
    ok {|semem := m;  sevm := s.(sevm) |}
  | Laset x i   =>
    SLet (sz, n,t) := s.[x] in
    Let i := ssem_pexpr s i >>= sto_int in
    Let v := sto_word sz v in
    let t := FArray.set t i v in
    Let vm := sset_var s.(sevm) x (@to_sval (sarr sz n) t) in
    ok {| semem := s.(semem); sevm := vm |}
  end.

Definition swrite_lvals (s:sestate) xs vs :=
   fold2 ErrType swrite_lval xs vs s.

End SSEM_PEXPR.

(* ** Instructions
 * -------------------------------------------------------------------- *)

Section SEM.

Variable P:prog.
Notation gd := (p_globs P).

Definition truncate_sval (ty: sstype) (v: svalue) : exec svalue :=
  of_sval ty v >>= λ x, ok (to_sval x).

Definition sstypes_of_stypes := map sstype_of_stype.

Inductive ssem : sestate -> cmd -> sestate -> Prop :=
| SEskip s :
    ssem s [::] s

| SEseq s1 s2 s3 i c :
    ssem_I s1 i s2 -> ssem s2 c s3 -> ssem s1 (i::c) s3

with ssem_I : sestate -> instr -> sestate -> Prop :=
| SEmkI ii i s1 s2:
    ssem_i s1 i s2 ->
    ssem_I s1 (MkI ii i) s2

with ssem_i : sestate -> instr_r -> sestate -> Prop :=
| SEassgn s1 s2 (x:lval) tag ty e v v':
    ssem_pexpr gd s1 e = ok v ->
    truncate_sval (sstype_of_stype ty) v = ok v' ->
    swrite_lval gd x v' s1 = ok s2 ->
    ssem_i s1 (Cassgn x tag ty e) s2

| SEopn s1 s2 t o xs es:
    ssem_pexprs gd s1 es >>= ssem_sopn o >>= (swrite_lvals gd s1 xs) = ok s2 ->
    ssem_i s1 (Copn xs t o es) s2

| SEif_true s1 s2 e c1 c2 :
    ssem_pexpr gd s1 e >>= sto_bool = ok true ->
    ssem s1 c1 s2 ->
    ssem_i s1 (Cif e c1 c2) s2

| SEif_false s1 s2 e c1 c2 :
    ssem_pexpr gd s1 e >>= sto_bool = ok false ->
    ssem s1 c2 s2 ->
    ssem_i s1 (Cif e c1 c2) s2

| SEwhile_true s1 s2 s3 s4 c e c' :
    ssem s1 c s2 ->
    ssem_pexpr gd s2 e >>= sto_bool = ok true ->
    ssem s2 c' s3 ->
    ssem_i s3 (Cwhile c e c') s4 ->
    ssem_i s1 (Cwhile c e c') s4

| SEwhile_false s1 s2 c e c' :
    ssem s1 c s2 ->
    ssem_pexpr gd s2 e >>= sto_bool = ok false ->
    ssem_i s1 (Cwhile c e c') s2

| SEfor s1 s2 (i:var_i) d lo hi c vlo vhi :
    ssem_pexpr gd s1 lo >>= sto_int = ok vlo ->
    ssem_pexpr gd s1 hi >>= sto_int = ok vhi ->
    ssem_for i (wrange d vlo vhi) s1 c s2 ->
    ssem_i s1 (Cfor i (d, lo, hi) c) s2

| SEcall s1 m2 s2 ii xs f args vargs vs :
    ssem_pexprs gd s1 args = ok vargs ->
    ssem_call s1.(semem) f vargs m2 vs ->
    swrite_lvals gd {|semem:= m2; sevm := s1.(sevm) |} xs vs = ok s2 ->
    ssem_i s1 (Ccall ii xs f args) s2

with ssem_for : var -> seq Z -> sestate -> cmd -> sestate -> Prop :=
| SEForDone s i c :
    ssem_for i [::] s c s

| SEForOne s1 s1' s2 s3 i w ws c :
    swrite_var i (SVint w) s1 = ok s1' ->
    ssem s1' c s2 ->
    ssem_for i ws s2 c s3 ->
    ssem_for i (w :: ws) s1 c s3

with ssem_call : mem -> funname -> seq svalue -> mem -> seq svalue -> Prop := 
| SEcallRun m1 m2 fn f vargs vargs' s1 vm2 vres vres':
    get_fundef (p_funcs P) fn = Some f ->
    mapM2 ErrType truncate_sval (sstypes_of_stypes f.(f_tyin)) vargs' = ok vargs ->
    swrite_vars f.(f_params) vargs (SEstate m1 svmap0) = ok s1 ->
    ssem s1 f.(f_body) (SEstate m2 vm2) ->
    map (fun (x:var_i) => sget_var vm2 x) f.(f_res) = vres ->
    mapM2 ErrType truncate_sval (sstypes_of_stypes f.(f_tyout)) vres = ok vres' ->
    ssem_call m1 fn vargs' m2 vres'.

End SEM.

Definition MkI_inj {ii i ii' i'} (H: MkI ii i = MkI ii' i') :
  ii = ii' ∧ i = i' :=
  let 'Logic.eq_refl := H in conj Logic.eq_refl Logic.eq_refl.

Definition Some_inj {A} (a a': A) (H: Some a = Some a') : a = a' :=
  let 'Logic.eq_refl := H in Logic.eq_refl.

Lemma sval_sstype_to_sval sst (z : ssem_t sst) :
  sval_sstype (to_sval z) = sst.
Proof. by case: sst z. Qed.

Lemma sto_word_inv s x (w:word s) :
  sto_word s x = ok w →
  exists  {s'} (w': word s'), x = SVword w' /\ truncate_word s w' = ok w.
Proof.
  case: x => // s' w'. rewrite /sto_word /truncate_word.
  elim le_ss' : cmp_le => //= eq_ww';apply ok_inj in eq_ww'.
  by exists s'; exists  w';split => //=; rewrite le_ss' eq_ww'.
Qed.

Lemma sto_int_inv x i :
  sto_int x = ok i →
  x = i.
Proof. case: x => // i' H; apply ok_inj in H. congruence. Qed.

Lemma sto_bool_inv x b :
  sto_bool x = ok b →
  x = b.
Proof. case: x => // i' H; apply ok_inj in H. congruence. Qed.

Definition incl_ty t1 t2 :=
  match t1,t2 with
  |sbool, sbool          => true
  |sint, sint            => true
  |sarr s p , sarr s' p' => s == s'
  |sword s, sword s'     => (s <= s')%CMP
  |_, _ => false
  end.

Lemma of_val_addr_undef ty v :
  of_val ty v = Error ErrAddrUndef →
  exists ty', v = Vundef ty' /\ incl_ty ty ty'.
Proof.
  elim ty => // => [||s p|s]; elim v => //=; try (move =>  ty';by exists ty';move: H;case: ty' => //=).
  + move => s' n a. case: CEDecStype.pos_dec => //=.
    move => eq_an'.
    case: wsize_eq_dec => //=. move=>  _.
    case: wsize_eq_dec => //=.
    move => ty'. case: ty' => //=.
    move => s' p'.
    case:eqP => //=;case:eqP => //= eq_pp' eq_ss';subst => _.
    exists (sarr s' p') => //=.
    move => s' w'.
    rewrite /truncate_word.
    case:cmp_le => //=.
    move => ty'.
    case: ty' => //=.
    move => s'.
    case H : cmp_le  => //= _.
    exists (sword s') => //=.
Qed. 
