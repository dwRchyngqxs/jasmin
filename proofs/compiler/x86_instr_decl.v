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


(* -------------------------------------------------------------------- *)
From mathcomp Require Import all_ssreflect all_algebra.
From CoqWord Require Import ssrZ.
Require oseq.
Require Import ZArith utils strings low_memory word sem_type global oseq.
Import Utf8 Relation_Operators.
Import Memory.

Set   Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Require Import x86_decl.

(* -------------------------------------------------------------------- *)

Variant asm_op : Type :=
  (* Data transfert *)
| MOV    of wsize              (* copy *)
| MOVSX  of wsize & wsize      (* sign-extend *)
| MOVZX  of wsize & wsize      (* zero-extend *)
| CMOVcc of wsize              (* conditional copy *)

  (* Arithmetic *)
| ADD    of wsize                  (* add unsigned / signed *)
| SUB    of wsize                  (* sub unsigned / signed *)
| MUL    of wsize                  (* mul unsigned *)
| IMUL   of wsize                             (* mul signed with truncation *)
| IMULr  of wsize   (* oprd * oprd *)         (* mul signed with truncation *)
| IMULri of wsize   (* oprd * oprd * imm *)   (* mul signed with truncation *)

| DIV    of wsize                        (* div unsigned *)
| IDIV   of wsize                        (* div   signed *)
| CQO    of wsize                               (* CWD CDQ CQO: allows sign extention in many words *)
| ADC    of wsize                 (* add with carry *)
| SBB    of wsize                 (* sub with borrow *)

| NEG	   of wsize 	                      (* negation *)

| INC    of wsize                         (* increment *)
| DEC    of wsize                         (* decrement *)

  (* Flag *)
| SETcc                           (* Set byte on condition *)
| BT     of wsize                  (* Bit test, sets result to CF *)

  (* Pointer arithmetic *)
| LEA    of wsize              (* Load Effective Address *)

  (* Comparison *)
| TEST   of wsize                  (* Bit-wise logical and CMP *)
| CMP    of wsize                  (* Signed sub CMP *)


  (* Bitwise logical instruction *)
| AND    of wsize  (* bit-wise and *)
| ANDN   of wsize  (* bit-wise andn *)
| OR     of wsize  (* bit-wise or  *)
| XOR    of wsize  (* bit-wise xor *)
| NOT    of wsize  (* bit-wise not *)

  (* Bit shifts *)
| ROR    of wsize    (* rotation / right *)
| ROL    of wsize    (* rotation / left *)
| SHL    of wsize    (* unsigned / left  *)
| SHR    of wsize    (* unsigned / right *)
| SAL    of wsize    (*   signed / left; synonym of SHL *)
| SAR    of wsize    (*   signed / right *)
| SHLD   of wsize    (* unsigned (double) / left *)
| SHRD   of wsize    (* unsigned (double) / right *)

| BSWAP  of wsize                     (* byte swap *)

  (* SSE instructions *)
| MOVD     of wsize
| VMOVDQU  `(wsize)
| VPAND    `(wsize)
| VPANDN   `(wsize)
| VPOR     `(wsize)
| VPXOR    `(wsize)
| VPADD    `(velem) `(wsize)
| VPSUB    `(velem) `(wsize)
| VPMULL   `(velem) `(wsize)
| VPMULU   `(wsize)
| VPEXTR   `(wsize)
| VPINSR   `(velem)
| VPSLL    `(velem) `(wsize)
| VPSRL    `(velem) `(wsize)
| VPSRA    `(velem) `(wsize)
| VPSLLV   `(velem) `(wsize)
| VPSRLV   `(velem) `(wsize)
| VPSLLDQ  `(wsize)
| VPSRLDQ  `(wsize)
| VPSHUFB  `(wsize)
| VPSHUFD  `(wsize)
| VPSHUFHW `(wsize)
| VPSHUFLW `(wsize)
| VPBLENDD `(wsize)
| VPBROADCAST of velem & wsize
| VBROADCASTI128
| VPUNPCKH `(velem) `(wsize)
| VPUNPCKL `(velem) `(wsize)
| VEXTRACTI128
| VINSERTI128
| VPERM2I128
| VPERMQ
.

(* ----------------------------------------------------------------------------- *)
(* TODO move in wsize *)
Definition pp_s     (s: string)                         (_: unit) : string := s.
Definition pp_sz    (s: string) (sz: wsize)             (_: unit) : string := s ++ " " ++ string_of_wsize sz.
Definition pp_sz_sz (s: string) (sz sz': wsize)         (_: unit) : string := s ++ " " ++ string_of_wsize sz ++ " " ++ string_of_wsize sz'.
Definition pp_ve_sz (s: string) (ve: velem) (sz: wsize) (_: unit) : string := s ++ " " ++ string_of_velem ve ++ " " ++ string_of_wsize sz.
Definition pp_ve    (s: string) (ve: velem)             (_: unit)   : string := s ++ " " ++ string_of_velem ve.

(* ----------------------------------------------------------------------------- *)
Notation xword8   := (xword U8).
Notation xword16  := (xword U16).
Notation xword32  := (xword U32).
Notation xword64  := (xword U64).
Notation xword128 := (xword U128).
Notation xword256 := (xword U256).

Definition b_ty             := [:: xbool].
Definition b4_ty            := [:: xbool; xbool; xbool; xbool].
Definition b5_ty            := [:: xbool; xbool; xbool; xbool; xbool].

Definition bw_ty    sz      := [:: xbool; xword sz].
Definition bw2_ty   sz      := [:: xbool; xword sz; xword sz].
Definition b2w_ty   sz      := [:: xbool; xbool; xword sz].
Definition b4w_ty   sz      := [:: xbool; xbool; xbool; xbool; xword sz].
Definition b5w_ty   sz      := [:: xbool; xbool; xbool; xbool; xbool; xword sz].
Definition b5w2_ty  sz      := [:: xbool; xbool; xbool; xbool; xbool; xword sz; xword sz].

Definition w_ty     sz      := [:: xword sz].
Definition w2_ty    sz sz'  := [:: xword sz; xword sz'].
Definition w3_ty    sz      := [:: xword sz; xword sz; xword sz].
Definition w4_ty    sz      := [:: xword sz; xword sz; xword sz; xword sz].
Definition w8_ty            := [:: xword8].
Definition w32_ty           := [:: xword32].
Definition w64_ty           := [:: xword64].
Definition w128_ty          := [:: xword128].
Definition w256_ty          := [:: xword256].

Definition w2b_ty   sz sz'  := [:: xword sz; xword sz'; xbool].
Definition ww8_ty   sz      := [:: xword sz; xword8].
Definition w2w8_ty   sz     := [:: xword sz; xword sz; xword8].
Definition w128w8_ty        := [:: xword128; xword8].
Definition w128ww8_ty sz    := [:: xword128; xword sz; xword8].
Definition w256w8_ty        := [:: xword256; xword8].
Definition w256w128w8_ty    := [:: xword256; xword128; xword8].
Definition w256x2w8_ty      := [:: xword256; xword256; xword8].

(* -------------------------------------------------------------------- *)
(* ----------------------------------------------------------------------------- *)

Definition SF_of_word sz (w : word sz) :=
  msb w.

Definition PF_of_word sz (w : word sz) :=
  lsb w.

Definition ZF_of_word sz (w : word sz) :=
  w == 0%R.

(* -------------------------------------------------------------------- *)
  (*  OF; CF; SF;    PF;    ZF  *)
Definition rflags_of_bwop sz (w : word sz) : (sem_xtuple b5_ty) :=
  (*  OF;  CF;    SF;           PF;           ZF  *)
  (:: Some false, Some false, Some (SF_of_word w), Some (PF_of_word w) & Some (ZF_of_word w)).

(* -------------------------------------------------------------------- *)
(*  OF; CF ;SF; PF; ZF  *)
Definition rflags_of_aluop sz (w : word sz) (vu vs : Z) : (sem_xtuple b5_ty) :=
  (*  OF;             CF;                SF;           PF;           ZF  *)
  (:: Some (wsigned  w != vs), Some (wunsigned w != vu), Some (SF_of_word w), Some (PF_of_word w) & Some (ZF_of_word w )).

(* -------------------------------------------------------------------- *)
Definition rflags_of_mul (ov : bool) : (sem_xtuple b5_ty) :=
  (*  OF; CF; SF;    PF;    ZF  *)
  (:: Some ov, Some ov, None, None & None).

(* -------------------------------------------------------------------- *)

Definition rflags_of_div : (sem_xtuple b5_ty):=
  (*  OF;    CF;    SF;    PF;    ZF  *)
  (:: None, None, None, None & None).

(* -------------------------------------------------------------------- *)

Definition rflags_of_andn sz (w: word sz) : (sem_xtuple b5_ty) :=
  (* OF ; CF ; SF ; PF ; ZF *)
  (:: Some false , Some false , Some (SF_of_word w) , None & Some (ZF_of_word w) ).

(* -------------------------------------------------------------------- *)

Definition rflags_None_w {sz} w : (sem_xtuple (b5w_ty sz)):=
  (*  OF;    CF;    SF;    PF;    ZF  *)
  (:: None, None, None, None, None & w).


(* -------------------------------------------------------------------- *)
(*  OF; SF; PF; ZF  *)
Definition rflags_of_aluop_nocf sz (w : word sz) (vs : Z) : (sem_xtuple b4_ty) :=
  (*  OF                 SF          ; PF          ; ZF          ] *)
  (:: Some (wsigned   w != vs), Some (SF_of_word w), Some (PF_of_word w) & Some (ZF_of_word w)).

Definition flags_w {l1} (bs: ltuple l1) {sz} (w: word sz):=
  (merge_tuple bs (w : sem_xtuple (w_ty sz))).

Definition flags_w2 {l1} (bs: ltuple l1) {sz} w :=
  (merge_tuple bs (w : sem_xtuple (w2_ty sz sz))).

Definition rflags_of_aluop_w sz (w : word sz) (vu vs : Z) :=
  flags_w (rflags_of_aluop w vu vs) w.

Definition rflags_of_aluop_nocf_w sz (w : word sz) (vs : Z) :=
  flags_w (rflags_of_aluop_nocf w vs) w.

Definition rflags_of_bwop_w sz (w : word sz) :=
  flags_w (rflags_of_bwop w) w.

(* -------------------------------------------------------------------- *)

Notation "'ex_tpl' A" := (exec (sem_xtuple A)) (at level 200, only parsing).

Definition x86_MOV sz (x: word sz) : exec (word sz) :=
  Let _ := check_size_8_64 sz in
  ok x.

Definition x86_MOVSX szi szo (x: word szi) : ex_tpl (w_ty szo) :=
  Let _ :=
    match szi with
    | U8 => check_size_16_64 szo
    | U16 => check_size_32_64 szo
    | U32 => assert (szo == U64) ErrType
    | _ => type_error
    end in
  ok (sign_extend szo x).

Definition x86_MOVZX szi szo (x: word szi) : ex_tpl (w_ty szo) :=
  Let _ :=
    match szi with
    | U8 => check_size_16_64 szo
    | U16 => check_size_32_64 szo
    | _ => type_error
    end in
  ok (zero_extend szo x).

Definition x86_ADD sz (v1 v2 : word sz) : ex_tpl (b5w_ty sz) :=
  Let _ := check_size_8_64 sz in
  ok (rflags_of_aluop_w
    (v1 + v2)%R
    (wunsigned v1 + wunsigned v2)%Z
    (wsigned   v1 + wsigned   v2)%Z).

Definition x86_SUB sz (v1 v2 : word sz) : ex_tpl (b5w_ty sz) :=
  Let _ := check_size_8_64 sz in
  ok (rflags_of_aluop_w
    (v1 - v2)%R
    (wunsigned v1 - wunsigned v2)%Z
    (wsigned   v1 - wsigned   v2)%Z).

Definition x86_CMOVcc sz (b:bool) (w2 w3: word sz) : ex_tpl (w_ty sz) :=
  Let _ := check_size_16_64 sz in
  if b then (ok w2) else (ok w3).

Definition x86_MUL sz (v1 v2: word sz) : ex_tpl (b5w2_ty sz) :=
  Let _  := check_size_16_64 sz in
  let lo := (v1 * v2)%R in
  let hi := wmulhu v1 v2 in
  let ov := wdwordu hi lo in
  let ov := (ov >? wbase sz - 1)%Z in
  ok (flags_w2 (rflags_of_mul ov) (:: hi & lo)).

Definition x86_IMUL_overflow sz (hi lo: word sz) : bool :=
  let ov := wdwords hi lo in
  (ov <? -wbase sz)%Z || (ov >? wbase sz - 1)%Z.

Definition x86_IMUL sz (v1 v2: word sz) : ex_tpl (b5w2_ty sz) :=
  Let _  := check_size_16_64 sz in
  let lo := (v1 * v2)%R in
  let hi := wmulhs v1 v2 in
  let ov := x86_IMUL_overflow hi lo in
  ok (flags_w2 (rflags_of_mul ov) (:: hi & lo)).

Definition x86_IMULt sz (v1 v2: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_16_64 sz in
  let lo := (v1 * v2)%R in
  let hi := wmulhs v1 v2 in
  let ov := x86_IMUL_overflow hi lo in
  ok (flags_w (rflags_of_mul ov) lo).

Definition x86_DIV sz (hi lo dv: word sz) : ex_tpl (b5w2_ty sz) :=
  Let _  := check_size_16_64 sz in
  let dd := wdwordu hi lo in
  let dv := wunsigned dv in
  let q  := (dd  /  dv)%Z in
  let r  := (dd mod dv)%Z in
  let ov := (q >? wmax_unsigned sz)%Z in

  if (dv == 0)%Z || ov then type_error else
  ok (flags_w2 (rflags_of_div) (:: (wrepr sz q) & (wrepr sz r))).

Definition x86_IDIV sz (hi lo dv: word sz) : ex_tpl (b5w2_ty sz) :=
  Let _  := check_size_16_64 sz in
  let dd := wdwords hi lo in
  let dv := wsigned dv in
  let q  := (Z.quot dd dv)%Z in
  let r  := (Z.rem  dd dv)%Z in
  let ov := (q <? wmin_signed sz)%Z || (q >? wmax_signed sz)%Z in

  if (dv == 0)%Z || ov then type_error else
  ok (flags_w2 (rflags_of_div) (:: (wrepr sz q) & (wrepr sz r))).

Definition x86_CQO sz (w:word sz) : exec (word sz) := 
  Let _ := check_size_16_64 sz in
  let r : word sz := (if msb w then -1 else 0)%R in
  ok r.

Definition add_carry sz (x y c: Z) : word sz :=
  wrepr sz (x + y + c).

Definition x86_ADC sz (v1 v2 : word sz) (c: bool) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let c := Z.b2z c in
  ok (rflags_of_aluop_w
    (add_carry sz (wunsigned v1) (wunsigned v2) c)
    (wunsigned v1 + wunsigned v2 + c)%Z
    (wsigned   v1 + wsigned   v2 + c)%Z).

Definition sub_borrow sz (x y c: Z) : word sz :=
  wrepr sz (x - y - c).

Definition x86_SBB sz (v1 v2 : word sz) (c:bool) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let c := Z.b2z c in
  ok ( rflags_of_aluop_w
    (sub_borrow sz (wunsigned v1) (wunsigned v2) c)
    (wunsigned v1 - (wunsigned v2 + c))%Z
    (wsigned   v1 - (wsigned   v2 + c))%Z).

Definition x86_NEG sz (w: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let vs := (- wsigned w)%Z in
  let v := (- w)%R in
  ok (flags_w
  ((:: Some (wsigned   v != vs), Some ((w != 0)%R), Some (SF_of_word v), Some (PF_of_word v) & Some (ZF_of_word v)) : sem_xtuple b5_ty)
  v).

Definition x86_INC sz (w: word sz) : ex_tpl (b4w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_aluop_nocf_w
    (w + 1)
    (wsigned w + 1)%Z).

Definition x86_DEC sz (w: word sz) : ex_tpl (b4w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_aluop_nocf_w
    (w - 1)
    (wsigned w - 1)%Z).

Definition x86_SETcc (b:bool) : ex_tpl (w_ty U8) := ok (wrepr U8 (Z.b2z b)).

Definition x86_BT sz (x y: word sz) : ex_tpl (b_ty) :=
  Let _  := check_size_8_64 sz in
  ok (Some (wbit x y)).

Definition x86_LEA sz (disp base scale offset: word sz) : ex_tpl (w_ty sz) :=
  Let _  := check_size_32_64 sz in
  if check_scale (wunsigned scale) then
    ok ((disp + base + scale * offset)%R)
  else type_error.

Definition x86_TEST sz (x y: word sz) : ex_tpl  b5_ty :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_bwop (wand x y)).

Definition x86_CMP sz (x y: word sz) : ex_tpl b5_ty :=
  Let _  := check_size_8_64 sz in
  ok
    (rflags_of_aluop (x - y)
       (wunsigned x - wunsigned y)%Z (wsigned x - wsigned y)%Z).

Definition x86_AND sz (v1 v2: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_bwop_w (wand v1 v2)).

Definition x86_ANDN sz (v1 v2: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_32_64 sz in
  let w := wandn v1 v2 in
  ok (flags_w (rflags_of_andn w) (w)).

Definition x86_OR sz (v1 v2: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_bwop_w (wor v1 v2)).

Definition x86_XOR sz (v1 v2: word sz) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (rflags_of_bwop_w (wxor v1 v2)).

Definition x86_NOT sz (v: word sz)  : ex_tpl (w_ty sz) :=
  Let _  := check_size_8_64 sz in
  ok (wnot v).

Definition x86_ROR sz (v: word sz) (i: u8) : ex_tpl (b2w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (:: None , None & v)
  else
    let r := wror v (wunsigned i) in
    let CF := msb r in
    let OF := if i == 1%R then Some (CF != msb v) else None in
    ok (:: OF , Some CF & r ).

Definition x86_ROL sz (v: word sz) (i: u8) : ex_tpl (b2w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (:: None , None & v)
  else
    let r := wrol v (wunsigned i) in
    let CF := lsb r in
    let OF := if i == 1%R then Some (msb r != CF) else None in
    ok (:: OF, Some CF & r ).

Definition rflags_OF {s} sz (i:word s) (r:word sz) rc OF : ex_tpl (b5w_ty sz) :=
    let OF := if i == 1%R then Some OF else None in
    let CF := Some rc in
    let SF := Some (SF_of_word r) in
    let PF := Some (PF_of_word r) in
    let ZF := Some (ZF_of_word r) in
    ok (:: OF, CF, SF, PF, ZF & r).

Definition x86_SHL sz (v: word sz) (i: u8) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (rflags_None_w v)
  else
    let rc := msb (wshl v (wunsigned i - 1)) in
    let r  := wshl v (wunsigned i) in
    rflags_OF i r rc (msb r (+) rc).

Definition x86_SHLD sz (v1 v2: word sz) (i: u8) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_16_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (rflags_None_w v1)
  else
    let rc := msb (wshl v1 (wunsigned i - 1)) in
    let r1 := wshl v1 (wunsigned i) in
    let r2 := wsar v2 (wsize_bits sz - (wunsigned i)) in
    let r  := wor r1 r2 in
    rflags_OF i r rc (msb r (+) rc).

Definition x86_SHR sz (v: word sz) (i: u8) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_8_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (rflags_None_w v)
  else
    let rc := lsb (wshr v (wunsigned i - 1)) in
    let r  := wshr v (wunsigned i) in
    rflags_OF i r rc (msb r).

Definition x86_SHRD sz (v1 v2: word sz) (i: u8) : ex_tpl (b5w_ty sz) :=
  Let _  := check_size_16_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (rflags_None_w v1)
  else
    let rc := lsb (wshr v1 (wunsigned i - 1)) in
    let r1 := wshr v1 (wunsigned i) in
    let r2 := wshl v2 (wsize_bits sz - (wunsigned i)) in
    let r  := wor r1 r2 in
    rflags_OF i r rc (msb r (+) msb v1).

Definition x86_SAR sz (v: word sz) (i: u8) : ex_tpl (b5w_ty sz) :=
  Let _ := check_size_8_64 sz in
  let i := wand i (x86_shift_mask sz) in
  if i == 0%R then
    ok (rflags_None_w v)
  else
    let rc := lsb (wsar v (wunsigned i - 1)) in
    let r  := wsar v (wunsigned i) in
    rflags_OF i r rc false.

(* ---------------------------------------------------------------- *)
Definition x86_BSWAP sz (v: word sz) : ex_tpl (w_ty sz) :=
  Let _ := check_size_32_64 sz in
  ok (wbswap v).

(* ---------------------------------------------------------------- *)
Definition x86_MOVD sz (v: word sz) : ex_tpl (w_ty U128) :=
  Let _ := check_size_32_64 sz in
  ok (zero_extend U128 v).

(* ---------------------------------------------------------------- *)
Definition x86_VMOVDQU sz (v: word sz) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in ok v.

(* ---------------------------------------------------------------- *)
Definition x86_u128_binop sz (op: _ → _ → word sz) (v1 v2: word sz) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in
  ok (op v1 v2).

Definition x86_VPAND sz := x86_u128_binop (@wand sz).
Definition x86_VPANDN sz := x86_u128_binop (@wandn sz).
Definition x86_VPOR sz := x86_u128_binop (@wor sz).
Definition x86_VPXOR sz := x86_u128_binop (@wxor sz).

(* ---------------------------------------------------------------- *)
Definition x86_VPADD (ve: velem) sz := x86_u128_binop (lift2_vec ve +%R sz).
Definition x86_VPSUB (ve: velem) sz := 
  x86_u128_binop (lift2_vec ve (fun x y => x - y)%R sz).

Definition x86_VPMULL (ve: velem) sz v1 v2 := 
  Let _ := check_size_32_64 ve in
  x86_u128_binop (lift2_vec ve *%R sz) v1 v2.

Definition x86_VPMULU sz := x86_u128_binop (@wpmulu sz).

(* ---------------------------------------------------------------- *)
Definition x86_VPEXTR (ve: wsize) (v: u128) (i: u8) : ex_tpl (w_ty ve) :=
  (* This instruction is valid for smaller ve, but semantics is unusual,
      hence compiler correctness would not be provable. *)
  Let _ := check_size_32_64 ve in
  ok (nth (0%R: word ve) (split_vec ve v) (Z.to_nat (wunsigned i))).

(* ---------------------------------------------------------------- *)
Definition x86_VPINSR (ve: velem) (v1: u128) (v2: word ve) (i: u8) : ex_tpl (w_ty U128) :=
  ok (wpinsr v1 v2 i).

Arguments x86_VPINSR : clear implicits.

(* ---------------------------------------------------------------- *)
Definition x86_u128_shift sz' sz (op: word sz' → Z → word sz')
  (v: word sz) (c: u8) : ex_tpl (w_ty sz) :=
  Let _ := check_size_16_64 sz' in
  Let _ := check_size_128_256 sz in
  ok (lift1_vec sz' (λ v, op v (wunsigned c)) sz v).

Arguments x86_u128_shift : clear implicits.

Definition x86_VPSLL (ve: velem) sz := x86_u128_shift ve sz (@wshl _).
Definition x86_VPSRL (ve: velem) sz := x86_u128_shift ve sz (@wshr _).
Definition x86_VPSRA (ve: velem) sz := x86_u128_shift ve sz (@wsar _).

(* ---------------------------------------------------------------- *)
Definition x86_u128_shift_variable ve sz op v1 v2 : ex_tpl (w_ty sz) :=
  Let _ := check_size_32_64 ve in
  Let _ := check_size_128_256 sz in
  ok (lift2_vec ve (λ v1 v2, op v1 (wunsigned v2)) sz v1 v2).

Arguments x86_u128_shift_variable : clear implicits.

Definition x86_VPSLLV ve sz := x86_u128_shift_variable ve sz (@wshl _).
Definition x86_VPSRLV ve sz := x86_u128_shift_variable ve sz (@wshr _).

(* ---------------------------------------------------------------- *)
Definition x86_vpsxldq sz op (v1: word sz) (v2: u8) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in
  ok (op v1 v2).

Definition x86_VPSLLDQ sz := x86_vpsxldq (@wpslldq sz).
Definition x86_VPSRLDQ sz := x86_vpsxldq (@wpsrldq sz).

(* ---------------------------------------------------------------- *)
Definition x86_VPSHUFB sz := x86_u128_binop (@wpshufb sz).

(* ---------------------------------------------------------------- *)
Definition x86_vpshuf sz (op: word sz → Z → word sz) (v1: word sz) (v2: u8) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in
  ok (op v1 (wunsigned v2)).

Arguments x86_vpshuf : clear implicits.

Definition x86_VPSHUFHW sz := x86_vpshuf sz (@wpshufhw _).
Definition x86_VPSHUFLW sz := x86_vpshuf sz (@wpshuflw _).
Definition x86_VPSHUFD sz := x86_vpshuf sz (@wpshufd _).

(* ---------------------------------------------------------------- *)
Definition x86_VPUNPCKH ve sz := x86_u128_binop (@wpunpckh sz ve).
Definition x86_VPUNPCKL ve sz := x86_u128_binop (@wpunpckl sz ve).

(* ---------------------------------------------------------------- *)
Definition x86_VPBLENDD sz (v1 v2: word sz) (m: u8) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in
  ok (wpblendd v1 v2 m).

(* ---------------------------------------------------------------- *)
Definition x86_VPBROADCAST ve sz (v: word ve) : ex_tpl (w_ty sz) :=
  Let _ := check_size_128_256 sz in
  ok (wpbroadcast sz v).

(* ---------------------------------------------------------------- *)
Definition x86_VEXTRACTI128 (v: u256) (i: u8) : ex_tpl (w_ty U128) :=
  let r := if lsb i then wshr v U128 else v in
  ok (zero_extend U128 r).

Definition x86_VINSERTI128 (v1: u256) (v2: u128) (m: u8) : ex_tpl (w_ty U256) :=
  ok (winserti128 v1 v2 m).

(* ---------------------------------------------------------------- *)
Definition x86_VPERM2I128 (v1 v2: u256) (m: u8) : ex_tpl (w_ty U256) :=
  ok (wperm2i128 v1 v2 m).

Definition x86_VPERMQ (v: u256) (m: u8) : ex_tpl (w_ty U256) :=
  ok (wpermq v m).

(* ----------------------------------------------------------------------------- *)
Coercion F f := ADImplicit (IArflag f).
Coercion R r := ADImplicit (IAreg r).

Definition implicit_flags      := map F [::OF; CF; SF; PF; ZF].
Definition implicit_flags_noCF := map F [::OF; SF; PF; ZF].

Definition iCF := F CF.

Notation mk_instr str_jas tin tout ain aout msb semi check wsizei := {|
  id_msb_flag := msb;
  id_in       := zip ain tin;
  id_out      := zip aout tout;
  id_semi     := semi;
  id_check    := check;
  id_str_jas  := str_jas;
  id_wsize    := wsizei;
|}.

Notation mk_instr_w_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w_ty sz) (w_ty sz) ain aout msb (semi sz) check sz) (only parsing).

Notation mk_instr_w_w' name semi msb ain aout check := (fun szi szo =>
  mk_instr (pp_sz_sz name szo szi) (w_ty szi) (w_ty szo) ain aout msb (semi szi szo) check szi) (only parsing).

(*
Notation mk_instr_w2_w2 name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (w2_ty sz sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2b_bw name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) [::xword sz; xword sz; xbool] (xbool :: (w_ty sz))
   msb ain aout (fun x y c => let p := semi sz x y c in ok (Some p.1, p.2)) check sz)  (only parsing).

Notation mk_instr__b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) [::] (b5w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_b_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (b_ty) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).
*)

Notation mk_instr_bw2_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (bw2_ty sz) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).


Notation mk_instr_w_b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w_ty sz) (b5w_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).


Notation mk_instr_w_b4w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w_ty sz) (b4w_ty sz) ain (implicit_flags_noCF ++ aout) msb (semi sz) check sz)  (only parsing).


Notation mk_instr_w2_b name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (b_ty) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2_b5 name semi msb ain  check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (b5_ty) ain implicit_flags msb (semi sz) check sz)  (only parsing).


Notation mk_instr_w2_b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (b5w_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2b_b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2b_ty sz sz) (b5w_ty sz) (ain ++ [::iCF]) (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).


Notation mk_instr_w2_b5w2 name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (b5w2_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w3_b5w2 name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w3_ty sz) (b5w2_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2_ty sz sz) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w4_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w4_ty sz) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_ww8_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (ww8_ty sz) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_ww8_b2w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (ww8_ty sz) (b2w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_ww8_b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (ww8_ty sz) (b5w_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2w8_b5w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2w8_ty sz) (b5w_ty sz) ain (implicit_flags ++ aout) msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w2w8_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w2w8_ty sz) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).

Notation mk_instr_w_w128 name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w_ty sz) (w128_ty) ain aout msb (semi sz) check sz)  (only parsing).

(*
Notation mk_instr_w128w8_w name semi msb ain aout check := (fun sz => 
  mk_instr (pp_sz name sz) (w128w8_ty) (w_ty sz) ain aout msb (semi sz) check sz)  (only parsing).
*)
Notation mk_ve_instr_w_w name semi msb ain aout check := (fun (ve:velem) sz => 
  mk_instr (pp_ve_sz name ve sz) (w_ty ve) (w_ty sz) ain aout msb (semi ve sz) check sz)  (only parsing).


Notation mk_ve_instr_w2_w name semi msb ain aout check := (fun (ve:velem) sz => 
  mk_instr (pp_ve_sz name ve sz) (w2_ty sz sz) (w_ty sz) ain aout msb (semi ve sz) check sz)  (only parsing).

Notation mk_ve_instr_ww8_w name semi msb ain aout check := (fun ve sz => 
  mk_instr (pp_ve_sz name ve sz) (ww8_ty sz) (w_ty sz) ain aout msb (semi ve sz) check sz)  (only parsing).

Definition fake_check (_:list asm_arg) : bool := true.

Definition msb_dfl := MSB_CLEAR.

Definition Ox86_MOV_instr               := mk_instr_w_w "MOV" x86_MOV msb_dfl [:: E 1] [:: E 0] fake_check.
Definition Ox86_MOVSX_instr             := mk_instr_w_w' "MOVSX" x86_MOVSX msb_dfl [:: E 1] [:: E 0] fake_check. 
Definition Ox86_MOVZX_instr             := mk_instr_w_w' "MOVZX" x86_MOVZX msb_dfl [:: E 1] [:: E 0] fake_check.
Definition Ox86_CMOVcc_instr            := mk_instr_bw2_w "CMOVcc" x86_CMOVcc msb_dfl [:: E 0; E 2; E 1] [:: E 1] fake_check.

(*Definition Ox86_MOVZX32_instr           := mk_instr (pp_s "MOVZX32") w32_ty w64_ty (λ x : u32, ok (zero_extend U64 x)) U32. *)
Definition Ox86_ADD_instr               := mk_instr_w2_b5w "ADD" x86_ADD msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_SUB_instr               := mk_instr_w2_b5w "SUB" x86_SUB msb_dfl [:: E 0; E 1] [:: E 0] fake_check.

Definition Ox86_MUL_instr               := mk_instr_w2_b5w2 "MUL"  x86_MUL  msb_dfl [:: R RAX; E 0] [:: R RDX; R RAX] fake_check.
Definition Ox86_IMUL_instr              := mk_instr_w2_b5w2 "IMUL" x86_IMUL msb_dfl [:: R RAX; E 0] [:: R RDX; R RAX] fake_check.
Definition Ox86_IMULr_instr             := mk_instr_w2_b5w "IMULr" x86_IMULt msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_IMULri_instr            := mk_instr_w2_b5w "IMULri" x86_IMULt msb_dfl [:: E 1; E 2] [:: E 0] fake_check. (* /!\ same as above *)
Definition Ox86_DIV_instr               := mk_instr_w3_b5w2 "DIV" x86_DIV msb_dfl [:: R RDX; R RAX; E 0] [:: R RAX; R RDX] fake_check.
Definition Ox86_IDIV_instr              := mk_instr_w3_b5w2 "IDIV" x86_IDIV msb_dfl [:: R RDX; R RAX; E 0] [:: R RAX; R RDX] fake_check.
Definition Ox86_CQO_instr               := mk_instr_w_w "CQO" x86_CQO msb_dfl [:: R RAX] [:: R RDX] fake_check.
Definition Ox86_ADC_instr               := mk_instr_w2b_b5w "ADC" x86_ADC msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_SBB_instr               := mk_instr_w2b_b5w "SBB" x86_SBB msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_NEG_instr               := mk_instr_w_b5w "NEG" x86_NEG msb_dfl [:: E 0] [:: E 0] fake_check.
Definition Ox86_INC_instr               := mk_instr_w_b4w "INC" x86_INC msb_dfl [:: E 0] [:: E 0] fake_check.
Definition Ox86_DEC_instr               := mk_instr_w_b4w "DEC" x86_DEC msb_dfl [:: E 0] [:: E 0] fake_check.
Definition Ox86_SETcc_instr             := mk_instr (pp_s "SETcc") b_ty w8_ty [:: E 0] [:: E 1] msb_dfl x86_SETcc fake_check U8.
Definition Ox86_BT_instr                := mk_instr_w2_b "BT" x86_BT msb_dfl [:: E 0; E 1] [:: F CF] fake_check.
Definition Ox86_LEA_instr               := mk_instr_w4_w "LEA" x86_LEA msb_dfl [:: E 1; E 2; E 3; E 4] [:: E 0] fake_check.
Definition Ox86_TEST_instr              := mk_instr_w2_b5 "TEST" x86_TEST msb_dfl [:: E 0; E 1] fake_check.
Definition Ox86_CMP_instr               := mk_instr_w2_b5 "CMP" x86_CMP msb_dfl [:: E 0; E 1] fake_check.
Definition Ox86_AND_instr               := mk_instr_w2_b5w "AND" x86_AND msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_ANDN_instr              := mk_instr_w2_b5w "ANDN" x86_ANDN msb_dfl [:: E 1; E 2] [:: E 0] fake_check.
Definition Ox86_OR_instr                := mk_instr_w2_b5w "OR" x86_OR msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_XOR_instr               := mk_instr_w2_b5w "XOR" x86_XOR msb_dfl [:: E 0; E 1] [:: E 0] fake_check.
Definition Ox86_NOT_instr               := mk_instr_w_w "NOT" x86_NOT msb_dfl [:: E 0] [:: E 0] fake_check.
Definition Ox86_ROR_instr               := mk_instr_ww8_b2w "ROR" x86_ROR msb_dfl [::E 0; ADExplicit 1 (Some RCX)] [::F OF; F CF; E 0] fake_check.
Definition Ox86_ROL_instr               := mk_instr_ww8_b2w "ROL" x86_ROL msb_dfl [::E 0; ADExplicit 1 (Some RCX)] [::F OF; F CF; E 0] fake_check.
Definition Ox86_SHL_instr               := mk_instr_ww8_b5w "SHL" x86_SHL msb_dfl [:: E 0; ADExplicit 1 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_SHR_instr               := mk_instr_ww8_b5w "SHR" x86_SHR msb_dfl [:: E 0; ADExplicit 1 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_SAL_instr               := mk_instr_ww8_b5w "SAL" x86_SHL msb_dfl [:: E 0; ADExplicit 1 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_SAR_instr               := mk_instr_ww8_b5w "SAR" x86_SAR msb_dfl [:: E 0; ADExplicit 1 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_SHLD_instr              := mk_instr_w2w8_b5w "SHLD" x86_SHLD msb_dfl [:: E 0; E 1; ADExplicit 2 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_SHRD_instr              := mk_instr_w2w8_b5w "SHRD" x86_SHRD msb_dfl [:: E 0; E 1; ADExplicit 2 (Some RCX)] [:: E 0] fake_check.
Definition Ox86_BSWAP_instr             := mk_instr_w_w "BSWAP" x86_BSWAP msb_dfl [:: E 0] [:: E 0] fake_check.

(* Vectorized instruction *)
Definition Ox86_MOVD_instr              := mk_instr_w_w128 "MOVD" x86_MOVD MSB_MERGE [:: E 1] [:: E 0] fake_check.
Definition Ox86_VMOVDQU_instr           := mk_instr_w_w "VMOVDQU" x86_VMOVDQU MSB_CLEAR [:: E 1] [:: E 0] fake_check.
Definition Ox86_VPAND_instr             := mk_instr_w2_w "VPAND" x86_VPAND MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPANDN_instr            := mk_instr_w2_w "VPANDN" x86_VPANDN MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPOR_instr              := mk_instr_w2_w "VPOR" x86_VPOR MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPXOR_instr             := mk_instr_w2_w "VPXOR" x86_VPXOR MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPADD_instr             := mk_ve_instr_w2_w "VPADD" x86_VPADD MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSUB_instr             := mk_ve_instr_w2_w "VPSUB" x86_VPSUB MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.

Definition Ox86_VPMULL_instr            := mk_ve_instr_w2_w "VPMULL" x86_VPMULL MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPMULU_instr sz         := mk_instr (pp_s "VPMULU") (w2_ty sz sz) (w_ty sz) [:: E 1 ; E 2] [:: E 0] MSB_CLEAR (@x86_VPMULU sz) fake_check sz. 

(* 128 *)
Definition Ox86_VPEXTR_instr ve         := mk_instr (pp_sz "VPEXTR" ve) w128w8_ty (w_ty ve) [:: E 1 ; E 2] [:: E 0] msb_dfl (@x86_VPEXTR ve) fake_check U128.
Definition Ox86_VPINSR_instr (ve:velem) := mk_instr (pp_ve "VPINSR" ve) (w128ww8_ty ve) w128_ty [:: E 1 ; E 2 ; E 3] [:: E 0] MSB_CLEAR (x86_VPINSR ve) fake_check U128.

Definition Ox86_VPSLL_instr             := mk_ve_instr_ww8_w "VPSLL" x86_VPSLL MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSRL_instr             := mk_ve_instr_ww8_w "VPSRL" x86_VPSRL MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSRA_instr             := mk_ve_instr_ww8_w "VPSRA" x86_VPSRA MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSLLV_instr            := mk_ve_instr_w2_w "VPSLLV" x86_VPSLLV MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSRLV_instr            := mk_ve_instr_w2_w "VPSRLV" x86_VPSRLV MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSLLDQ_instr           := mk_instr_ww8_w "VPSLLDQ" x86_VPSLLDQ MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSRLDQ_instr           := mk_instr_ww8_w "VPSRLDQ" x86_VPSRLDQ MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSHUFB_instr           := mk_instr_w2_w "VPSHUFB" x86_VPSHUFB MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSHUFHW_instr          := mk_instr_ww8_w "VPSHUFHW" x86_VPSHUFHW MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSHUFLW_instr          := mk_instr_ww8_w "VPSHUFLW" x86_VPSHUFLW MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPSHUFD_instr           := mk_instr_ww8_w "VPSHUFD" x86_VPSHUFD MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPUNPCKH_instr          := mk_ve_instr_w2_w "VPUNPCKH" x86_VPUNPCKH MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPUNPCKL_instr          := mk_ve_instr_w2_w "VPUNPCKL" x86_VPUNPCKL MSB_CLEAR [:: E 1 ; E 2] [:: E 0] fake_check.
Definition Ox86_VPBLENDD_instr          := mk_instr_w2w8_w "VPBLENDD" x86_VPBLENDD MSB_CLEAR [:: E 1 ; E 2 ; E 3] [:: E 0] fake_check.
Definition Ox86_VPBROADCAST_instr       := mk_ve_instr_w_w "VPBROADCAST" x86_VPBROADCAST MSB_CLEAR [:: E 1] [:: E 0] fake_check.

(* 256 *)
Definition Ox86_VBROADCASTI128_instr    := mk_instr (pp_s "VBROADCASTI128")  w128_ty       w256_ty [:: E 1] [:: E 0] MSB_CLEAR (x86_VPBROADCAST U256) fake_check U256.
Definition Ox86_VEXTRACTI128_instr      := mk_instr (pp_s "VEXTRACTI128")    w256w8_ty     w128_ty [:: E 1; E 2] [:: E 0] MSB_CLEAR x86_VEXTRACTI128 fake_check U256.
Definition Ox86_VINSERTI128_instr       := mk_instr (pp_s "VINSERTI128")     w256w128w8_ty w256_ty [:: E 1; E 2; E 3] [:: E 0] MSB_CLEAR x86_VINSERTI128 fake_check U256.
Definition Ox86_VPERM2I128_instr        := mk_instr (pp_s "VPERM2I128")      w256x2w8_ty   w256_ty [:: E 1; E 2; E 3] [:: E 0] MSB_CLEAR x86_VPERM2I128 fake_check U256.
Definition Ox86_VPERMQ_instr            := mk_instr (pp_s "VPERMQ")          w256w8_ty     w256_ty [:: E 1; E 2] [:: E 0] MSB_CLEAR x86_VPERMQ fake_check U256.

Definition instr_desc o : instr_desc_t :=
  match o with
  | MOV sz             => Ox86_MOV_instr sz
  | MOVSX sz sz'       => Ox86_MOVSX_instr sz sz'
  | MOVZX sz sz'       => Ox86_MOVZX_instr sz sz'
  | CMOVcc sz          => Ox86_CMOVcc_instr sz
  | BSWAP sz           => Ox86_BSWAP_instr sz
  | CQO sz             => Ox86_CQO_instr sz
(*  | MOVZX32            => Ox86_MOVZX32_instr *)
  | ADD sz             => Ox86_ADD_instr sz
  | SUB sz             => Ox86_SUB_instr sz
  | MUL sz             => Ox86_MUL_instr sz
  | IMUL sz            => Ox86_IMUL_instr sz
  | IMULr sz           => Ox86_IMULr_instr sz
  | IMULri sz          => Ox86_IMULri_instr sz
  | DIV sz             => Ox86_DIV_instr sz
  | IDIV sz            => Ox86_IDIV_instr sz
  | ADC sz             => Ox86_ADC_instr sz
  | SBB sz             => Ox86_SBB_instr sz
  | NEG sz             => Ox86_NEG_instr sz
  | INC sz             => Ox86_INC_instr sz
  | DEC sz             => Ox86_DEC_instr sz
  | SETcc              => Ox86_SETcc_instr
  | BT sz              => Ox86_BT_instr sz
  | LEA sz             => Ox86_LEA_instr sz
  | TEST sz            => Ox86_TEST_instr sz
  | CMP sz             => Ox86_CMP_instr sz
  | AND sz             => Ox86_AND_instr sz
  | ANDN sz            => Ox86_ANDN_instr sz
  | OR sz              => Ox86_OR_instr sz
  | XOR sz             => Ox86_XOR_instr sz
  | NOT sz             => Ox86_NOT_instr sz
  | ROL sz             => Ox86_ROL_instr sz
  | ROR sz             => Ox86_ROR_instr sz
  | SHL sz             => Ox86_SHL_instr sz
  | SHR sz             => Ox86_SHR_instr sz
  | SAR sz             => Ox86_SAR_instr sz
  | SAL sz             => Ox86_SAL_instr sz
  | SHLD sz            => Ox86_SHLD_instr sz
  | SHRD sz            => Ox86_SHRD_instr sz
  | MOVD sz            => Ox86_MOVD_instr sz
  | VPINSR sz          => Ox86_VPINSR_instr sz
  | VEXTRACTI128       => Ox86_VEXTRACTI128_instr
  | VMOVDQU sz         => Ox86_VMOVDQU_instr sz
  | VPAND sz           => Ox86_VPAND_instr sz
  | VPANDN sz          => Ox86_VPANDN_instr sz
  | VPOR sz            => Ox86_VPOR_instr sz
  | VPXOR sz           => Ox86_VPXOR_instr sz
  | VPADD sz sz'       => Ox86_VPADD_instr sz sz'
  | VPSUB sz sz'       => Ox86_VPSUB_instr sz sz'
  | VPMULL sz sz'      => Ox86_VPMULL_instr sz sz'
  | VPMULU sz          => Ox86_VPMULU_instr sz
  | VPSLL sz sz'       => Ox86_VPSLL_instr sz sz'
  | VPSRL sz sz'       => Ox86_VPSRL_instr sz sz'
  | VPSRA sz sz'       => Ox86_VPSRA_instr sz sz'
  | VPSLLV sz sz'      => Ox86_VPSLLV_instr sz sz'
  | VPSRLV sz sz'      => Ox86_VPSRLV_instr sz sz'
  | VPSLLDQ sz         => Ox86_VPSLLDQ_instr sz
  | VPSRLDQ sz         => Ox86_VPSRLDQ_instr sz
  | VPSHUFB sz         => Ox86_VPSHUFB_instr sz
  | VPSHUFHW sz        => Ox86_VPSHUFHW_instr sz
  | VPSHUFLW sz        => Ox86_VPSHUFLW_instr sz
  | VPSHUFD sz         => Ox86_VPSHUFD_instr sz
  | VPUNPCKH sz sz'    => Ox86_VPUNPCKH_instr sz sz'
  | VPUNPCKL sz sz'    => Ox86_VPUNPCKL_instr sz sz'
  | VPBLENDD sz        => Ox86_VPBLENDD_instr sz
  | VPBROADCAST sz sz' => Ox86_VPBROADCAST_instr sz sz'
  | VBROADCASTI128     => Ox86_VBROADCASTI128_instr
  | VPERM2I128         => Ox86_VPERM2I128_instr
  | VPERMQ             => Ox86_VPERMQ_instr
  | VINSERTI128        => Ox86_VINSERTI128_instr
  | VPEXTR ve          => Ox86_VPEXTR_instr ve
  end.

(* -------------------------------------------------------------------- *)

(*Definition check_opdr a1 :=
  match a1 with
  | Imm _ _ | Glob _ | Reg _  | Adr _  => true
  | _ => false
  end.

Definition check_ri a1 :=
  match a1 with
  | Imm _ _  | Reg _  => true
  | _ => false
  end.

Definition check2_regmemi (args: list asm_arg) :=
  match args with
  | [::Reg _; a1] => check_opdr a1
  | [::Adr _; a1] => check_ri a1
  | _               => false
  end. *)


