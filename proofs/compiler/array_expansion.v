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

(* ** Imports and settings *)

From mathcomp Require Import all_ssreflect all_algebra.
From CoqWord Require Import ssrZ.
Require Import psem allocation.
Require Import compiler_util ZArith.
Import Utf8.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope vmap.

Local Open Scope seq_scope.

Module CmpIndex.

  Definition t := [eqType of (var * Z)%type].

  Definition cmp : t -> t -> comparison := 
    lex CmpVar.cmp Z.compare.

  Lemma cmpO : Cmp cmp.
  Proof. apply LexO;[apply CmpVar.cmpO|apply ZO]. Qed.

End CmpIndex.

Local Notation index:= (var * Z)%type.

Module Mi := gen_map.Mmake CmpIndex.

Module Ma := MakeMalloc Mi.

Definition type_in_array t :=
  match t with
  | sarr ws _ => sword ws
  | _         => sword W64
  end.

Module CBEA.

  Module M.
    
    Definition valid (alloc: Ma.t) (allocated:Sv.t) := 
      forall x n id, Ma.get alloc (x,n) = Some id -> 
        Sv.In x allocated /\ Sv.In ({|vtype := type_in_array (vtype x); vname := id |}) allocated. 

    Record expansion := mkExpansion {
      alloc     : Ma.t;
      allocated : Sv.t;
      Valid     : valid alloc allocated
    }.

    Definition t := expansion.

    Lemma valid_empty : valid Ma.empty Sv.empty.
    Proof. by move=> x n id;rewrite Ma.get0. Qed.

    Definition empty := mkExpansion (*Sv.empty *)valid_empty.

    Lemma valid_merge r1 r2 : 
       valid (Ma.merge (alloc r1) (alloc r2)) 
             (Sv.union (allocated r1) (allocated r2)).
    Proof.
      by move=> x n id => /Ma.mergeP [] /(@Valid r1)[??]/(@Valid r2)[??];SvD.fsetdec.
    Qed.

    Definition merge r1 r2 := 
       mkExpansion (@valid_merge r1 r2).

    Definition incl r1 r2 :=
      Ma.incl (alloc r1) (alloc r2) && Sv.subset (allocated r2) (allocated r1).

    Lemma incl_refl r: incl r r.
    Proof. rewrite /incl Ma.incl_refl /=;apply SvP.subset_refl. Qed.

    Lemma incl_trans r2 r1 r3: incl r1 r2 -> incl r2 r3 -> incl r1 r3.
    Proof. 
      rewrite /incl=> /andP[]Hi1 Hs1 /andP[] Hi2 Hs2.
      rewrite (Ma.incl_trans Hi1 Hi2) /=.
      apply: SvP.subset_trans Hs2 Hs1.
    Qed.

    Lemma merge_incl_l r1 r2: incl (merge r1 r2) r1.
    Proof. by rewrite /incl /merge /= Ma.merge_incl_l SvP.union_subset_1. Qed.

    Lemma merge_incl_r r1 r2: incl (merge r1 r2) r2.
    Proof. by rewrite /incl /merge /= Ma.merge_incl_r SvP.union_subset_2. Qed.

    Lemma valid_set_arr x nx id r:
      valid (Ma.set (alloc r) (x,nx) id) 
         (Sv.add {|vtype := type_in_array (vtype x); vname := id|} (Sv.add x (allocated r))).
    Proof.
      move=> y ny idy.
      case: ((x,nx) =P (y,ny)) => [[]<- <-|Hne]. 
      + by rewrite Ma.setP_eq=> -[] <-;SvD.fsetdec.
      move=> /Ma.setP_neq [];first by apply /eqP.
      by move=> /Valid []??;SvD.fsetdec.
    Qed.

    Definition set_arr x N id r := mkExpansion (@valid_set_arr x N id r).

  End M.

  Definition eq_alloc (r:M.t) (vm vm':vmap) :=
    (forall x, ~Sv.In x (M.allocated r) -> eval_uincl vm.[x] vm'.[x]) /\ 
    (forall x (n:Z) id, Ma.get (M.alloc r) (x, n) = Some id ->
     match x with
     | Var (sarr sw s) id' => 
       let x := Var (sarr sw s) id' in
       let x' := Var (sword sw) id in
       exists t, vm.[x] = ok t /\ 
       ((@Array.get _ s t n) >>= (fun w => ok (pword_of_word w))) = vm'.[x']
     | _ => False
     end).

  Lemma eq_alloc_empty : eq_alloc M.empty vmap0 vmap0.
  Proof. by done. Qed.

  Lemma eq_alloc_incl r1 r2 vm vm':
    M.incl r2 r1 -> 
    eq_alloc r1 vm vm' -> 
    eq_alloc r2 vm vm'. 
  Proof.
    move=> /andP[] Hincl /Sv.subset_spec Hsub [] Hv Ha;split.
    + move=> x Hx;apply: Hv;SvD.fsetdec.
    by move=> x n id /(Ma.inclP _ _ Hincl) /Ha.
  Qed.

  Definition check_var m (x1 x2:var) := 
    (x1 == x2) && ~~Sv.mem x1 (M.allocated m).
    
  Fixpoint check_eb m (e1 e2:pexpr) : bool := 
    match e1, e2 with
    | Pconst   n1, Pconst   n2 => n1 == n2
    | Pbool    b1, Pbool    b2 => b1 == b2
    | Parr_init sz1 n1, Parr_init sz2 n2 => (sz1 == sz2) && (n1 == n2)
    | Pvar     x1, Pvar     x2 => check_var m x1 x2
    | Pglobal g1, Pglobal g2 => g1 == g2
    | Pget  x1 e1, Pget  x2 e2 => check_var m x1 x2 && check_eb m e1 e2
    | Pget  x1 e1, Pvar  x2    => 
      match is_const e1 with
      | Some n1 => (Ma.get (M.alloc m) (x1.(v_var), n1) == Some (vname x2)) &&
                   (vtype x2 == type_in_array (vtype x1))
      | _ => false
      end
    | Pload sw1 x1 e1, Pload sw2 x2 e2 => (sw1 == sw2) && check_var m x1 x2 && check_eb m e1 e2
    | Papp1 o1 e1, Papp1 o2 e2 => (o1 == o2) && check_eb m e1 e2
    | Papp2 o1 e11 e12, Papp2 o2 e21 e22 =>    
      (o1 == o2) && check_eb m e11 e21 && check_eb m e12 e22
    | PappN o1 es1, PappN o2 es2 =>
      (o1 == o2) && all2 (check_eb m) es1 es2
    | Pif e e1 e2, Pif e' e1' e2' =>
      check_eb m e e' && check_eb m e1 e1' && check_eb m e2 e2'      
    | _, _ => false
    end.

  Definition check_e (e1 e2:pexpr) m := 
    if check_eb m e1 e2 then cok m else cerror (Cerr_arr_exp e1 e2). 

  Definition check_lval (_:option (stype * pexpr)) (r1 r2:lval) m := 
    match r1, r2 with 
    | Lnone _ t1, Lnone _ t2 => 
      if t1 == t2 then cok m
      else cerror (Cerr_arr_exp_v r1 r2)
    | Lvar x1, Lvar x2 => 
      if check_var m x1 x2 then cok m 
      else cerror (Cerr_arr_exp_v r1 r2)
    | Lmem sw1 x1 e1, Lmem sw2 x2 e2 =>
      if (sw1 == sw2) && check_var m x1 x2 && check_eb m e1 e2 then cok m
      else cerror (Cerr_arr_exp_v r1 r2)
    | Laset x1 e1, Lvar x2 =>
      if vtype x2 == type_in_array (vtype x1) then 
        match is_const e1 with 
        | Some n1 => cok (M.set_arr x1 n1 (vname x2) m)
        | None    => cerror (Cerr_arr_exp_v r1 r2)
        end
      else cerror (Cerr_arr_exp_v r1 r2)
    | Laset x1 e1, Laset x2 e2 =>
      if check_var m x1 x2 && check_eb m e1 e2 then cok m
      else cerror (Cerr_arr_exp_v r1 r2)
    | _, _ => cerror (Cerr_arr_exp_v r1 r2)
    end.

  Lemma check_varP r vm1 vm2 x1 x2 v1 : 
    eq_alloc r vm1 vm2 ->
    check_var r x1 x2 ->
    get_var vm1 x1 = ok v1 ->
    exists2 v2, get_var vm2 x2 = ok v2 & value_uincl v1 v2.
  Proof.
    move=> [Hee _] /andP[]/eqP <- /Sv_memP /Hee Hin Hget;move: Hin;rewrite /get_var.
    apply: on_vuP Hget => [z ->|->[]] ?;subst v1.
    + by case: vm2.[x1] => //= a Ha; exists (pto_val a).
    case: vm2.[x1] => [a Ha | e <-] /=.
    + exists (pto_val a) => //.
      by symmetry;apply subtype_eq_vundef_type;apply subtype_type_of_val.
    eexists; first reflexivity.
    by rewrite /type_of_val -vundef_type_idem.
  Qed.

  Section CHECK_EBP.
    Context (gd: glob_decls) (r: M.expansion) (m: mem) (vm1 vm2: vmap)
            (Hrn: eq_alloc r vm1 vm2).

    Let P e1 : Prop :=
      ∀ e2 v1,
        check_eb r e1 e2 →
        sem_pexpr gd {| emem := m ; evm := vm1 |} e1 = ok v1 →
        exists2 v2, sem_pexpr gd {| emem := m ; evm := vm2 |} e2 = ok v2 & value_uincl v1 v2.

    Let Q es1 : Prop :=
      ∀ es2 vs1,
        all2 (check_eb r) es1 es2 →
        sem_pexprs gd {| emem := m ; evm := vm1 |} es1 = ok vs1 →
        exists2 vs2, sem_pexprs gd {| emem := m ; evm := vm2 |} es2 = ok vs2 &
               List.Forall2 value_uincl vs1 vs2.

    Lemma check_e_esbP : (∀ e, P e) ∧ (∀ es, Q es).
    Proof.
      apply: pexprs_ind_pair; subst P Q; split => /=.
      - by case => // _ _ [<-]; exists [::]; eauto.
      - move => e rec es ih [] // e' es' q /andP [] he hes.
        t_xrbindP => v ok_v vs ok_vs <-{q} /=.
        move: rec => /(_ _ _ he ok_v) [] v' -> h.
        move: ih => /(_ _ _ hes ok_vs) [] vs' -> hs /=; eauto.
      - by move => z1 [] // z2 _ /eqP <- [<-] /=; exists z1.
      - by move => z1 [] // z2 _ /eqP <- [<-] /=; exists z1.
      - move => sz1 n1 [] // sz2 n2 _ /andP [] /eqP <- /eqP <- [<-] /=; eexists => //=.
        by split => //; exists erefl.
      - move => x1 [] // x2 v; exact: check_varP.
      - by move => g1 [] // g2 v /eqP <- /= ->; eauto.
      - move => x1 e1 ih1 [] // x2 e2.
        + case: Hrn => Hmem Mget; case: x1 => -[xt1 xn1] x1i /=.
          case: is_constP => //= ze/andP[/eqP /Mget Hget /eqP Htx2].
          apply: on_arr_varP => sw n t /= Htx1.
          move: Hget; rewrite Htx1 /get_var /= => -[t1 [-> /=]] Hget Heq.
          pose p := fun ov => if ov is Ok v then v = Varr t else True.
          have : p error (ok (Varr t)) by done.
          rewrite -Heq /= => /Varr_inj1 => {p Heq} ?;subst t1.
          t_xrbindP => w heq ?; subst.
          move: Hget;rewrite heq /=.
          by case: x2 Htx2 => -[xt2 xn2] x2i /= -> <-; exists (Vword w).
      move=> v1 /andP[Hcv /ih1 Hce];apply: on_arr_varP => sw n t Htx1 /=.
      rewrite /on_arr_var/= => /(check_varP Hrn Hcv) [vx2 ->].
      case:vx2=> //= sw0 n0 t' [] ? [ ? Htt'];subst.
      apply:rbindP=> i;apply: rbindP => ve /Hce [v2 ->].
      move=> /value_uincl_int H/H[_ ->] /=.
      by apply: rbindP => ? /Htt' -> /= [->];exists v1.
    - move => sz1 x1 e1 He1 [] // sz2 x2 e2 v1.
      move=> /andP[] /andP[] /eqP <- Hcv /He1 Hce;apply: rbindP => w1.
      t_xrbindP => vx1 /(check_varP Hrn Hcv) [] vx2 /= ->.
      move=> /value_uincl_word H/H{H} H.
      move => w2 ve1 /Hce [] ve2 -> /=. rewrite H /= => {H}.
      by move=>  /value_uincl_word H/H{H} -> /= h2 -> <- /=;exists (Vword h2) => //; exists erefl.
    - move => op1 e1 He1 [] //= op2 e2 v1.
      move=> /andP[]/eqP <- /He1 H; apply: rbindP => ve1 /H [ve2 ->].
      by move=> /vuincl_sem_sop1 U /U;exists v1.
    - move => op1 e11 He11 e12 He12 [] //= op2 e21 e22 v1.
      move=> /andP[]/andP[]/eqP <- /He11 He1 /He12 He2.
      apply: rbindP => ? /He1 [? -> U1] /=; apply: rbindP => ? /He2 [? -> U2].
      by move=> /(vuincl_sem_sop2 U1 U2); exists v1.
    - move => op1 es1 ih [] //= _ es2 v1 /andP [] /eqP <- rec.
      t_xrbindP => vs ok_vs ok_v1; rewrite -!/(sem_pexprs _ _).
      move: ih => /(_ _ _ rec ok_vs) [] vs' ->.
      exact: (vuincl_sem_opN ok_v1).
    move => e He e11 He11 e12 He12 [] //= e2 e21 e22 v1.
    move=> /andP[]/andP[]/He{He}He /He11{He11}He11 /He12{He12}He12.
    apply: rbindP => b;apply: rbindP => w /He [ve ->] /=.
    move=> /value_uincl_bool H/H [_ ->] /=.
    apply: rbindP=> v2 /He11 [] v2' -> Hv2'.
    apply: rbindP=> v3 /He12 [] v3' -> Hv3'.
    case: ifP => //=.
    rewrite (value_uincl_vundef_type_eq Hv2') (value_uincl_vundef_type_eq Hv3') => ->.
    case: andP => // - [] /(value_uincl_is_defined Hv2') -> /(value_uincl_is_defined Hv3') -> [<-].
    eexists; first by eauto.
    by case b.
  Qed.

  End CHECK_EBP.

  Definition check_ebP gd r m vm1 vm2 e h :=
    (@check_e_esbP gd r m vm1 vm2 h).1 e.

  Lemma check_eP gd e1 e2 r re vm1 vm2 :
    check_e e1 e2 r = ok re ->
    eq_alloc r vm1 vm2 ->
    eq_alloc re vm1 vm2 /\
    forall m v1,  sem_pexpr gd (Estate m vm1) e1 = ok v1 ->
    exists v2, sem_pexpr gd (Estate m vm2) e2 = ok v2 /\ value_uincl v1 v2.
  Proof.
    rewrite /check_e; case: ifP => //= h [<-] hr; split => // m v1 ok_v1.
    have [] := check_ebP hr h ok_v1.
    by eauto.
  Qed.

  Lemma eq_alloc_set x1 (v1 v2:exec (psem_t (vtype x1))) r vm1 vm2  : 
    ~ Sv.In x1 (M.allocated r) ->
    eq_alloc r vm1 vm2 ->
    eval_uincl v1 v2 ->
    eq_alloc r vm1.[x1 <- apply_undef v1] 
               vm2.[x1 <- apply_undef v2].
  Proof.
    move=> Hin [] Hu Hget Huv;split.
    + move=> x Hx; case:( x1 =P x) => [<-|/eqP Hne].
      + by rewrite !Fv.setP_eq;apply eval_uincl_apply_undef.
      by rewrite !Fv.setP_neq //;apply: Hu.
    move=> x n id H;have := Hget _ _ _ H;have [{H}]:= M.Valid H.
    case:x => //= -[] //= sw p xn ?? [t ?];exists t.
    by rewrite !Fv.setP_neq //;apply /eqP => H;subst;apply Hin.
  Qed.

  Lemma check_rvarP (x1 x2:var_i) r1 vm1 v1 v2 s1 s1' : 
    check_var r1 x1 x2 ->
    eq_alloc r1 (evm s1) vm1 ->
    value_uincl v1 v2 ->
    write_var x1 v1 s1 = ok s1' ->
    exists vm1' : vmap,
      write_var x2 v2 {| emem := emem s1; evm := vm1 |} =
         ok {| emem := emem s1'; evm := vm1' |} /\
     eq_alloc r1 (evm s1') vm1'.
  Proof.
    move=> /andP[]/eqP Heq /Sv_memP Hin [] Hu Hget Huv.
    rewrite /write_var /=;apply:rbindP => vm1'.
    apply: set_varP => [v1' | ];rewrite -Heq /set_var.
    + move=> /(pof_val_uincl Huv) [v2' [->]] /= Hv' <- [<-] /=.
      by eexists;split;eauto; apply: (@eq_alloc_set x1 (ok v1') (ok v2')).
    move=> /negbTE -> /pof_val_error [t [ht ?]];subst v1 => <- [] <-.
    have /= := value_uincl_vundef_type_eq Huv.
    rewrite -(subtype_vundef_type_eq ht) -vundef_type_idem.
    move=> /pof_val_type_of [[v'] | ] -> /=;
      eexists;split;eauto.
    + by apply (@eq_alloc_set x1 undef_error (ok v')).
    by apply (@eq_alloc_set x1 undef_error undef_error).
  Qed.

  Lemma check_lvalP gd r1 r1' x1 x2 oe2 s1 s1' vm1 v1 v2 :
    check_lval oe2 x1 x2 r1 = ok r1' ->
    eq_alloc r1 s1.(evm) vm1 ->
    value_uincl v1 v2 ->
    oapp (fun te2 => 
     sem_pexpr gd (Estate s1.(emem) vm1) te2.2 >>= truncate_val te2.1 = ok v2) true oe2 ->
    write_lval gd x1 v1 s1 = ok s1' ->
    exists vm1', 
      write_lval gd x2 v2 (Estate s1.(emem) vm1) = ok (Estate s1'.(emem) vm1') /\
      eq_alloc r1' s1'.(evm) vm1'.
  Proof.
    move=> H1 H2 H3 _; move: H1 H2 H3.
    case: x1 x2 => [vi1 t1 | x1 | sw1 x1 e1 | x1 e1] [vi2 t2 | x2 | sw2 x2 e2 | x2 e2] //=.
    + case:ifP => //= /eqP <- [<-].
      move=> Heqa Hv H; have [-> _]:= write_noneP H.
      by rewrite (uincl_write_none _ Hv H);exists vm1.
    + by case:ifP=>//= Hc [<-];apply check_rvarP.
    + case:ifP=>//= /andP[] /andP[] /eqP <- Hcx Hce [<-] Hea Hu.
      t_xrbindP => z1 vx1  /(check_varP Hea Hcx) [vx1' ->] /=.
      move=> /value_uincl_word H/H{H} -> we ve.
      case: s1 Hea=> sm1 svm1 Hea /(check_ebP Hea Hce) [ve2 ->].
      move=> /value_uincl_word H/H{H} /= -> w /(value_uincl_word Hu) -> /=.
      by move=> m -> <- /=;eexists;eauto.
    + case:ifP=>//= /eqP Htx2.
      case:is_constP => //= i [<-] Hea Huv.
      apply: on_arr_varP => sz n t Htx1 Hget.
      t_xrbindP=> w /(value_uincl_word Huv) H => {Huv} t' Ht' vm1' Hset <- /=.
      case: x1 x2 Htx1 Htx2 Hget Hset => -[xt1 xn1] ? [[xt2 xn2] ?]/= -> ->.
      rewrite /get_var/set_var/=;apply:on_vuP.
      + move=> t'' Hget Heq.
        pose p := fun ov => if ov is Ok v then v = Varr t else True.
        have : p error (ok (Varr t)) by done. 
        rewrite -Heq /= => /Varr_inj1 ?;subst t''.
        rewrite eq_dec_refl pos_dec_n_n.
        case => /= <-.
        case Hea => Hina Hgeta. 
        exists vm1.[{| vtype := sword sz; vname := xn2 |} <- ok (pword_of_word w)];split=>//.
        + by rewrite /write_var /= /set_var /= (to_word_to_pword H) /=.
        split.
        + by move=> x /= Hx;rewrite !Fv.setP_neq;
          [by apply Hina;SvD.fsetdec | |];apply /eqP; SvD.fsetdec. 
        move=> x n0 id.
        case: (({| vtype := sarr sz n; vname := xn1 |}, i) =P (x, n0)).
        + move=> [<- <-]; rewrite Ma.setP_eq => -[?] /=;subst id;exists t'.
          rewrite !Fv.setP_eq;split=>//.
          by move: Ht';rewrite /Array.set /Array.get;
            case:ifP=> // ? [<-];rewrite FArray.setP_eq.
        move=> Hne;move: (Hne) => {H} /eqP /Ma.setP_neq H/H [] Hgetx.
        case: ({| vtype := sarr sz n; vname := xn1 |} =P x).
        + move=> ?;subst;have /= [t2 [Ht2 Hget2]] := Hgeta _ _ _ Hgetx.
          exists t';rewrite Fv.setP_eq;split=>//;rewrite Fv.setP_neq;
          last by apply /eqP => -[] /b.
          move: Ht2 Ht';rewrite Hget -Hget2=> -[?];subst t2.
          rewrite /Array.set/Array.get;case:ifP=>// => _ -[<-];case:ifP =>// _.
          by rewrite FArray.setP_neq //;apply /eqP => Heq1;apply Hne;rewrite Heq1.
        have {Hgetx} := Hgeta _ _ _ Hgetx.
        case:x Hne {H} =>-[]//= ws p' xn Hne [t'' [??]] /eqP ?;exists t''.
        by rewrite !Fv.setP_neq //;apply /eqP => -[]. 
      by rewrite eq_dec_refl pos_dec_n_n /=. 
    case:ifP=>//=/andP[] Hca Hce [<-] Hea Hvu.
    apply: on_arr_varP;rewrite /on_arr_var => sz n t Htx1 /(check_varP Hea Hca) [v3 ->] /=.
    case: v3=> //= sz0 n0 t' [? [? Ht]];subst.
    apply: rbindP => z;apply: rbindP => ve. 
    case: s1 Hea=> sm1 svm1 Hea /(check_ebP Hea Hce) [v3 ->] /value_uincl_int H /H [_ ->].
    apply: rbindP => w /(value_uincl_word Hvu) -> /=.
    apply: rbindP => t'';rewrite /Array.set;case:ifP => //= _ [<-].
    have /(check_rvarP Hca Hea):
      value_uincl (@Varr _ n0 (FArray.set t z (ok w))) (@Varr _ n0 (FArray.set t' z (ok w))).
    + split=>//;exists erefl => i v.
      have := Ht i v;rewrite /Array.get !FArray.setP.
      by case:ifP=>// _; case:ifP.
    by rewrite /write_var /=;case: set_var => //= vm' H1 /H1.
  Qed.
 
End CBEA.

Module CheckExpansion :=  MakeCheckAlloc CBEA.
