(* -------------------------------------------------------------------- *)
open Prog

module T = Type
module E = Expr
module F = Format
module B = Bigint

(* -------------------------------------------------------------------- *)
let rec pp_list sep pp fmt xs =
  let pp_list = pp_list sep pp in
    match xs with
    | []      -> ()
    | [x]     -> Format.fprintf fmt "%a" pp x
    | x :: xs -> Format.fprintf fmt "%a%(%)%a" pp x sep pp_list xs

(* -------------------------------------------------------------------- *)
let pp_iloc fmt (l,ls) =
  Format.fprintf fmt "@[%a@]" (pp_list " from@ " L.pp_sloc) (l::ls)

(* -------------------------------------------------------------------- *)
let pp_string0 fmt str =
  F.fprintf fmt "%a" (pp_list "" F.pp_print_char) str

(* -------------------------------------------------------------------- *)
let pp_bool fmt b =
  if b then F.fprintf fmt "true"
  else F.fprintf fmt "false"

(* -------------------------------------------------------------------- *)
let pp_btype fmt = function
  | Bool -> F.fprintf fmt "bool"
  | U i  -> F.fprintf fmt "U%i" (int_of_ws i)
  | Int  -> F.fprintf fmt "int"

(* -------------------------------------------------------------------- *)
let pp_gtype (pp_size:F.formatter -> 'size -> unit) fmt = function
  | Bty ty -> pp_btype fmt ty
  | Arr(ws,e) -> F.fprintf fmt "%a[%a]" pp_btype (U ws) pp_size e

(* -------------------------------------------------------------------- *)
let pp_gvar_i pp_var fmt v = pp_var fmt (L.unloc v)

(* -------------------------------------------------------------------- *)

let string_of_cmp_ty = function
  | E.Cmp_w (Type.Unsigned, _) -> "u"
  | _        -> ""

(* -------------------------------------------------------------------- *)

let string_of_velem s ws ve = 
  let nws = int_of_ws ws in
  let nve = int_of_velem ve in
  let s   = if s = T.Unsigned then "u" else "s" in
  Format.sprintf "%d%s%d" (nws/nve) s nve

let string_of_op2 = function
  | E.Oand   -> "&&"
  | E.Oor    -> "||"
  | E.Oadd _ -> "+"
  | E.Omul _ -> "*"
  | E.Osub _ -> "-"
  | E.Odiv k -> "/"  ^ string_of_cmp_ty k
  | E.Omod k -> "%"  ^ string_of_cmp_ty k

  | E.Oland _ -> "&"
  | E.Olor _ -> "|"
  | E.Olxor _ -> "^"
  | E.Olsr _ -> ">>"
  | E.Olsl _ -> "<<"
  | E.Oasr _ -> ">>s"

  | E.Oeq  _ -> "=="
  | E.Oneq _ -> "!="
  | E.Olt  k -> "<"  ^ string_of_cmp_ty k
  | E.Ole  k -> "<=" ^ string_of_cmp_ty k
  | E.Ogt  k -> ">"  ^ string_of_cmp_ty k
  | E.Oge  k -> ">=" ^ string_of_cmp_ty k

  | Ovadd (ve,ws) -> Format.sprintf "+%s"  (string_of_velem T.Unsigned ws ve)
  | Ovsub (ve,ws) -> Format.sprintf "-%s"  (string_of_velem T.Unsigned ws ve)
  | Ovmul (ve,ws) -> Format.sprintf "*%s"  (string_of_velem T.Unsigned ws ve)
  | Ovlsr (ve,ws) -> Format.sprintf ">>%s" (string_of_velem T.Unsigned ws ve)
  | Ovasr (ve,ws) -> Format.sprintf ">>%s" (string_of_velem T.Unsigned ws ve)
  | Ovlsl (ve,ws) -> Format.sprintf "<<%s" (string_of_velem T.Signed   ws ve)


let string_of_op1 = function
  | E.Oint_of_word _ -> F.sprintf "(int)"
  | E.Osignext (szo, _) -> F.sprintf "(%ds)" (int_of_ws szo)
  | E.Oword_of_int szo
  | E.Ozeroext (szo, _) -> F.sprintf "(%du)" (int_of_ws szo)
  | E.Olnot _ -> "!"
  | E.Onot    -> "~"
  | E.Oneg _ -> "-"

let string_of_opN =
  function
  | E.Opack (sz, pe) ->
    F.sprintf "Opack<%d, %d>"
      (int_of_ws sz)
      (int_of_pe pe)

(* -------------------------------------------------------------------- *)
let pp_aa = function
  | Warray.AAscale -> "[", "]"
  | Warray.AAdirect -> "{", "}"

let pp_ge pp_var =
  let pp_var_i = pp_gvar_i pp_var in
  let pp_gvar fmt x = 
    let s = if is_gkvar x then "" else "##G" in
    Format.fprintf fmt "%s%a" s pp_var_i x.gv in
  let rec pp_expr fmt = function
  | Pconst i    -> B.pp_print fmt i
  | Pbool  b    -> F.fprintf fmt "%b" b
  | Parr_init n -> F.fprintf fmt "array_init(%a)" B.pp_print n
  | Pvar v      -> pp_gvar fmt v
  | Pget(aa, ws,x,e)   -> 
    let bl, br = pp_aa aa in
    F.fprintf fmt "%a%s%a %a%s"  pp_gvar x bl pp_btype (U ws) pp_expr e br
  | Pload(ws,x,e) ->
    F.fprintf fmt "@[(load %a@ %a@ %a)@]"
      pp_btype (U ws) pp_var_i x pp_expr e
  | Papp1(o, e) ->
    F.fprintf fmt "@[(%s@ %a)@]" (string_of_op1 o) pp_expr e
  | Papp2(op,e1,e2) ->
    F.fprintf fmt "@[(%a %s@ %a)@]"
      pp_expr e1 (string_of_op2 op) pp_expr e2
  | PappN (op, es) ->
    F.fprintf fmt "@[(%s [%a])@]" (string_of_opN op) (pp_list ",@ " pp_expr) es
  | Pif(_, e,e1,e2) ->
    F.fprintf fmt "@[(%a ?@ %a :@ %a)@]"
      pp_expr e pp_expr e1  pp_expr e2
  in
  pp_expr

(* -------------------------------------------------------------------- *)
let pp_glv pp_var fmt = function
  | Lnone (_, ty) -> F.fprintf fmt "_{%a}" (pp_gtype (fun fmt _ -> F.fprintf fmt "?")) ty
  | Lvar x  -> pp_gvar_i pp_var fmt x
  | Lmem (ws, x, e) ->
    F.fprintf fmt "@[store %a@ %a@ %a@]"
     pp_btype (U ws) (pp_gvar_i pp_var) x (pp_ge pp_var) e
  | Laset(aa, ws, x,e) ->
    let bl, br = pp_aa aa in
    F.fprintf fmt "%a%s%a %a%s" 
      (pp_gvar_i pp_var) x bl pp_btype (U ws) (pp_ge pp_var) e br

(* -------------------------------------------------------------------- *)
let pp_ges pp_var fmt es =
  Format.fprintf fmt "@[%a@]" (pp_list ",@ " (pp_ge pp_var)) es

(* -------------------------------------------------------------------- *)
let pp_glvs pp_var fmt lvs =
  match lvs with
  | [] -> F.fprintf fmt "()"
  | [x] -> pp_glv pp_var fmt x
  | _   -> F.fprintf fmt "(@[%a@])" (pp_list ",@ " (pp_glv pp_var)) lvs

(* -------------------------------------------------------------------- *)
let pp_opn =
  let open Expr in
  let f w s = F.sprintf "%s_%d" s (int_of_ws w) in
  let f2 w _w' s = F.sprintf "%s_%d" s (int_of_ws w) in (* TODO: concrete syntax for these intrinsics *)
  let v ve sz s = F.sprintf "%s_%s" s (string_of_velem T.Unsigned sz ve) in
  function
  | Omulu w -> f w "#mulu"
  | Oaddcarry w -> f w "#addc"
  | Osubcarry w -> f w "#subc"
  | Oset0 w -> f w "#set0"
  | Ox86_MOV w -> f w "#x86_MOV"
  | Ox86_MOVSX (w, w') -> f2 w w' "#x86_MOVSX"
  | Ox86_MOVZX (w, w') -> f2 w w' "#x86_MOVZX"
  | Ox86_MOVZX32 -> "#x86_MOVZX32"
  | Ox86_CMOVcc w -> f w "#x86_CMOVcc"
  | Ox86_ADD w -> f w "#x86_ADD"
  | Ox86_SUB w -> f w "#x86_SUB"
  | Ox86_MUL w -> f w "#x86_MUL"
  | Ox86_IMUL w -> f w "#x86_IMUL"
  | Ox86_IMULt w -> f w "#x86_IMULt"
  | Ox86_IMULtimm w -> f w "#x86_IMULtimm"
  | Ox86_DIV w -> f w "#x86_DIV"
  | Ox86_IDIV w -> f w "#x86_IDIV"
  | Ox86_CQO w  -> f w "#x86_CQO"
  | Ox86_ADC w -> f w "#x86_ADC"
  | Ox86_SBB w -> f w "#x86_SBB"
  | Ox86_NEG w -> f w "#x86_NEG"
  | Ox86_INC w -> f w "#x86_INC"
  | Ox86_DEC w -> f w "#x86_DEC"
  | Ox86_SETcc -> "#x86_SETcc"
  | Ox86_BT w -> f w "#x86_BT"
  | Ox86_LEA w -> f w "#x86_LEA"
  | Ox86_TEST w -> f w "#x86_TEST"
  | Ox86_CMP w -> f w "#x86_CMP"
  | Ox86_AND w -> f w "#x86_AND"
  | Ox86_ANDN w -> f w "#x86_ANDN"
  | Ox86_OR w -> f w "#x86_OR"
  | Ox86_XOR w -> f w "#x86_XOR"
  | Ox86_NOT w -> f w "#x86_NOT"
  | Ox86_ROL w -> f w "#x86_ROL"
  | Ox86_ROR w -> f w "#x86_ROR"
  | Ox86_SHL w -> f w "#x86_SHL"
  | Ox86_SHR w -> f w "#x86_SHR"
  | Ox86_SAR w -> f w "#x86_SAR"
  | Ox86_SHLD w -> f w "#x86_SHLD"
  | Ox86_SHRD w -> f w "#x86_SHRD"
  | Ox86_ADCX w -> f w "#x86_ADCX"
  | Ox86_ADOX w -> f w "#x86_ADOX"
  | Ox86_MULX w -> f w "#x86_MULX"
  | Ox86_BSWAP w -> f w "#x86_BSWAP"
  | Ox86_MOVD w -> f w "#x86_MOVD"
  | Ox86_VMOVDQU w -> f w "#x86_VMOVDQU"
  | Ox86_VPAND w -> f w "#x86_VPAND"
  | Ox86_VPANDN w -> f w "#x86_VPANDN"
  | Ox86_VPOR w -> f w "#x86_VPOR"
  | Ox86_VPXOR w -> f w "#x86_VPXOR"
  | Ox86_VPADD (ve, sz) -> v ve sz "#x86_VPADD"
  | Ox86_VPSUB (ve, sz) -> v ve sz "#x86_VPSUB"
  | Ox86_VPMULL (ve, sz) -> v ve sz "#x86_VPMULL"
  | Ox86_VPMULU w -> f w "#x86_VPMULU"
  | Ox86_VPEXTR w -> f w "#x86_VPEXTR"
  | Ox86_VPINSR ve -> v ve U128 "#x86_VPINSR"
  | Ox86_VPSLL (ve, sz) -> v ve sz "#x86_VPSLL"
  | Ox86_VPSRL (ve, sz) -> v ve sz "#x86_VPSRL"
  | Ox86_VPSRA (ve, sz) -> v ve sz "#x86_VPSRA"
  | Ox86_VPSLLV (ve, sz) -> v ve sz "#x86_VPSLLV"
  | Ox86_VPSRLV (ve, sz) -> v ve sz "#x86_VPSRLV"
  | Ox86_VPSLLDQ w -> f w "#x86_VPSLLDQ"
  | Ox86_VPSRLDQ w -> f w "#x86_VPSRLDQ"
  | Ox86_VPSHUFB w -> f w "#x86_VPSHUFB"
  | Ox86_VPSHUFHW w -> f w "#x86_VPSHUFHW"
  | Ox86_VPSHUFLW w -> f w "#x86_VPSHUFLW"
  | Ox86_VPSHUFD w -> f w "#x86_VPSHUFD"
  | Ox86_VPUNPCKH (ve, sz) -> v ve sz "#x86_VPUNPCKH"
  | Ox86_VPUNPCKL (ve, sz) -> v ve sz "#x86_VPUNPCKL"
  | Ox86_VPBLENDD w -> f w "#x86_VPBLENDD"
  | Ox86_VPBROADCAST (ve, sz) -> v ve sz "#x86_VPBROADCAST"
  | Ox86_VBROADCASTI128 -> "#x86_VPBROADCASTI_2u128"
  | Ox86_VEXTRACTI128 -> "#x86_VEXTRACTI128"
  | Ox86_VINSERTI128 -> "#x86_VINSERTI128"
  | Ox86_VPERM2I128 -> "#x86_VPERM2I128"
  | Ox86_VPERMQ -> "#x86_VPERMQ"

(* -------------------------------------------------------------------- *)
let pp_tag = function
  | AT_none    -> ""
  | AT_keep    -> ":k"
  | AT_rename  -> ":r"
  | AT_inline  -> ":i"
  | AT_phinode -> ":φ"

let pp_align fmt = function 
  | E.Align -> Format.fprintf fmt "align "
  | E.NoAlign -> ()

let rec pp_gi pp_info pp_ty pp_var fmt i =
  F.fprintf fmt "%a" pp_info i.i_info;
  match i.i_desc with
  | Cassgn(x , tg, ty, e) ->
    F.fprintf fmt "@[<hov 2>%a %s=(%a)@ %a;@]"
      (pp_glv pp_var) x (pp_tag tg)
      pp_ty ty
      (pp_ge pp_var) e

  | Copn(x, t, o, e) -> (* FIXME *)
    F.fprintf fmt "@[<hov 2>%a %s=@ %s(%a);@]"
       (pp_glvs pp_var) x (pp_tag t) (pp_opn o)
       (pp_ges pp_var) e

  | Cif(e, c, []) ->
    F.fprintf fmt "@[<v>if %a %a@]"
      (pp_ge pp_var) e (pp_cblock pp_info pp_ty pp_var) c

  | Cif(e, c1, c2) ->
    F.fprintf fmt "@[<v>if %a %a else %a@]"
      (pp_ge pp_var) e (pp_cblock pp_info pp_ty pp_var) c1
      (pp_cblock pp_info pp_ty pp_var) c2

  | Cfor(i, (dir, lo, hi), c) ->
    let dir, e1, e2 =
      if dir = UpTo then "to", lo, hi else "downto", hi, lo in
    F.fprintf fmt "@[<v>for %a = @[%a %s@ %a@] %a@]"
      (pp_gvar_i pp_var) i (pp_ge pp_var) e1 dir (pp_ge pp_var) e2
      (pp_gc pp_info pp_ty pp_var) c

  | Cwhile(a, [], e, c) ->
    F.fprintf fmt "@[<v>%awhile (%a) %a@]"
      pp_align a
      (pp_ge pp_var) e (pp_cblock pp_info pp_ty pp_var) c

  | Cwhile(a, c, e, []) ->
    F.fprintf fmt "@[<v>%awhile %a (%a)@]"
      pp_align a
      (pp_cblock pp_info pp_ty pp_var) c (pp_ge pp_var) e

  | Cwhile(a, c, e, c') ->
    F.fprintf fmt "@[<v>%awhile %a %a %a@]"
      pp_align a
      (pp_cblock pp_info pp_ty pp_var) c (pp_ge pp_var) e
      (pp_cblock pp_info pp_ty pp_var) c'

  | Ccall(_ii, x, f, e) -> (* FIXME ii *)
    F.fprintf fmt "@[<hov 2> %a =@ %s(%a);@]"
      (pp_glvs pp_var) x f.fn_name (pp_ges pp_var) e

(* -------------------------------------------------------------------- *)
and pp_gc pp_info pp_ty pp_var fmt c =
  F.fprintf fmt "@[<v>%a@]" (pp_list "@ " (pp_gi pp_info pp_ty pp_var)) c

(* -------------------------------------------------------------------- *)
and pp_cblock pp_info pp_ty pp_var fmt c =
  F.fprintf fmt "{@   %a@ }" (pp_gc pp_info pp_ty pp_var) c

(* -------------------------------------------------------------------- *)

let pp_kind fmt = function
  | Const  ->  F.fprintf fmt "Const"
  | Stack  ->  F.fprintf fmt "Stack"
  | Reg    ->  F.fprintf fmt "Reg"
  | Inline ->  F.fprintf fmt "Inline"
  | Global ->  F.fprintf fmt "Global" 

let pp_ty_decl (pp_size:F.formatter -> 'size -> unit) fmt v =
  F.fprintf fmt "%a %a" pp_kind v.v_kind (pp_gtype pp_size) v.v_ty

let pp_var_decl pp_var pp_size fmt v =
  F.fprintf fmt "%a %a" (pp_ty_decl pp_size) v pp_var v

let pp_gfun pp_info (pp_size:F.formatter -> 'size -> unit) pp_var fmt fd =
  let pp_vd =  pp_var_decl pp_var pp_size in
(*  let locals = locals fd in *)
  let ret = List.map L.unloc fd.f_ret in
  let pp_ret fmt () =
    F.fprintf fmt "return @[(%a)@];"
      (pp_list ",@ " pp_var) ret in

  F.fprintf fmt "@[<v>fn %s @[(%a)@] -> @[(%a)@] {@   @[<v>%a@ %a@]@ }@]"
   fd.f_name.fn_name
   (pp_list ",@ " pp_vd) fd.f_args
   (pp_list ",@ " (pp_ty_decl pp_size)) ret
(*   (pp_list ";@ " pp_vd) (Sv.elements locals) *)
   (pp_gc pp_info (pp_gtype pp_size) pp_var) fd.f_body
   pp_ret ()

let pp_noinfo _ _ = ()

let pp_gexpr pp_var fmt = function
  | GEword e -> pp_ge pp_var fmt e
  | GEarray es -> Format.fprintf fmt "{@[%a@]}" (pp_ges pp_var) es

let pp_pitem pp_var =
  let pp_size = pp_ge pp_var in
  let aux fmt = function
    | MIfun fd -> pp_gfun pp_noinfo pp_size pp_var fmt fd
    | MIparam (x,e) ->
      F.fprintf fmt "%a = %a"
        (pp_var_decl pp_var pp_size) x
        (pp_ge pp_var) e
    | MIglobal (x, e) ->
      F.fprintf fmt "%a = %a" 
        (pp_var_decl pp_var pp_size) x
        (pp_gexpr pp_var) e 
  in
  aux

let pp_pvar fmt x = F.fprintf fmt "%s" x.v_name 

let pp_ptype =
  let pp_size = pp_ge pp_pvar in
  pp_gtype pp_size

let pp_plval = 
  pp_glv pp_pvar 

let pp_pexpr =
  pp_ge pp_pvar 

let pp_pprog fmt p =
  Format.fprintf fmt "@[<v>%a@]"
    (pp_list "@ @ " (pp_pitem pp_pvar)) (List.rev p)


let pp_fun ?(pp_info=pp_noinfo) pp_var fmt fd =
  let pp_size fmt i = F.fprintf fmt "%i" i in
  let pp_vd =  pp_var_decl pp_var pp_size in
  let locals = locals fd in
  let ret = List.map L.unloc fd.f_ret in
  let pp_ret fmt () =
    F.fprintf fmt "return @[(%a)@];"
      (pp_list ",@ " pp_var) ret in

  F.fprintf fmt "@[<v>fn %s @[(%a)@] -> @[(%a)@] {@   @[<v>%a@ %a@ %a@]@ }@]"
   fd.f_name.fn_name
   (pp_list ",@ " pp_vd) fd.f_args
   (pp_list ",@ " (pp_ty_decl pp_size)) ret
   (pp_list ";@ " pp_vd) (Sv.elements locals)
   (pp_gc pp_info (pp_gtype pp_size) pp_var) fd.f_body
   pp_ret ()

let pp_var ~debug =
    if debug then
      fun fmt x -> F.fprintf fmt "%s.%i" x.v_name (int_of_uid x.v_id)
    else
      fun fmt x -> F.fprintf fmt "%s" x.v_name

let pp_expr ~debug fmt e =
  let pp_var = pp_var ~debug in
  pp_ge pp_var fmt e

let pp_ty fmt = pp_gtype (fun fmt -> F.fprintf fmt "%i") fmt

let pp_instr ~debug fmt i =
  let pp_var = pp_var ~debug in
  pp_gi pp_noinfo pp_ty pp_var fmt i

let pp_stmt ~debug fmt i =
  let pp_var = pp_var ~debug in
  pp_gc pp_noinfo pp_ty pp_var fmt i

let pp_ifunc ~debug pp_info fmt fd =
  let pp_var = pp_var ~debug in
  pp_fun ~pp_info pp_var fmt fd

let pp_func ~debug fmt fd =
  let pp_var = pp_var ~debug in
  pp_fun pp_var fmt fd

let pp_prog ~debug fmt p =
  let pp_var = pp_var ~debug in
  Format.fprintf fmt "@[<v>%a@]"
     (pp_list "@ @ " (pp_fun pp_var)) (List.rev p)

let pp_glob pp_var fmt (x, gd) = 
  let pp_size fmt i = F.fprintf fmt "%i" i in
  let pp_vd =  pp_var_decl pp_var pp_size in
  let pp_gd fmt gd = 
    match Prog.glob_of_cglob x.v_ty gd with
    | `GWord (_ws, i) -> 
      Format.fprintf fmt "%a" Bigint.pp_print_X i 
    | `GArray(_ws, t) ->
      Format.fprintf fmt "@[{%a};@]"
        (pp_list ",@ " Bigint.pp_print_X) 
        (Array.to_list t) in
  Format.fprintf fmt "@[%a =@ %a;@]"
    pp_vd x pp_gd gd

let pp_globs pp_var fmt gds = 
  Format.fprintf fmt "@[<v>%a@]"
    (pp_list "@ @ " (pp_glob pp_var)) gds

let pp_iprog ~debug pp_info fmt (gd, funcs) =
  let pp_var = pp_var ~debug in
  Format.fprintf fmt "@[<v>%a@ %a@]"
     (pp_globs pp_var) gd
     (pp_list "@ @ " (pp_fun ~pp_info pp_var)) (List.rev funcs)

let pp_prog ~debug fmt ((gd, funcs):'info Prog.prog) =
  let pp_var = pp_var ~debug in
  Format.fprintf fmt "@[<v>%a@ %a@]"
     (pp_globs pp_var) gd
     (pp_list "@ @ " (pp_fun pp_var)) (List.rev funcs)


(* ----------------------------------------------------------------------- *)

let pp_warning_msg fmt = function
  | Compiler_util.Use_lea -> Format.fprintf fmt "LEA instruction is used"

(* ----------------------------------------------------------------------- *)

let pp_datas fmt data = 
  let pp_w fmt w = 
    let w = Word0.wunsigned U8 w in
    let z = Prog.bi_of_z w in
    Format.fprintf fmt ".byte %s" (Bigint.to_string z) in
  Format.fprintf fmt "@[<v>%a@]" (pp_list "@ " pp_w) data
      
