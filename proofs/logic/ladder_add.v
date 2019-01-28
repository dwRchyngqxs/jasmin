From mathcomp Require Import all_ssreflect.
Require Import prog_notation sem.
Import ZArith type expr var seq.

Open Scope string_scope.
Open Scope Z_scope.


Notation i := ((VarI (Var sint "i") 1%positive)).
Notation y := ((VarI (Var (sarr 4) "y") 1%positive)).
Notation cf := ((VarI (Var sbool "cf") 1%positive)).
Notation add1 := ((VarI (Var sword "add1") 1%positive)).
Notation add0 := ((VarI (Var sword "add0") 1%positive)).
Notation x := ((VarI (Var (sarr 4) "x") 1%positive)).
Notation ya := ((VarI (Var (sarr 4) "ya") 1%positive)).


Definition program := [::
  ("add",
  MkFun 2%positive [:: x; ya] {
    For i from 0 to 4 do {
      y.[i] ::= ya.[i];
      If (i == 0) then {::
         [p cf, x.[0]] := ++(x.[0], y.[0], false)
      } else {::
         [p cf, x.[i]] := ++(x.[i], y.[i], cf)
      }
    };
    add0 ::= 0;
    add1 ::= 38;
     add1 := (~~ add1) ? add0 : cf;
    For i from 0 to 4 do {::
      If (i == 0) then {::
         [p cf, x.[0]] := ++(x.[0], add1, false)
      } else {::
         [p cf, x.[i]] := ++(x.[i], add0, cf)
      }
    };
     add0 := add0 ? add1 : cf;
     [p __, x.[0]] := ++(x.[0], add0, false)
  }%P
  [:: x])].
