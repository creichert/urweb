(* Copyright (c) 2008, Adam Chlipala
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - The names of contributors may not be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *)

(* Simplify a Core program algebraically *)

structure Reduce :> REDUCE = struct

open Core

structure IS = IntBinarySet
structure IM = IntBinaryMap

structure E = CoreEnv

fun multiLiftExpInExp n e =
    if n = 0 then
        e
    else
        multiLiftExpInExp (n - 1) (E.liftExpInExp 0 e)

val dangling =
    CoreUtil.Exp.existsB {kind = fn _ => false,
                          con = fn _ => false,
                          exp = fn (n, e) =>
                                   case e of
                                       ERel n' => n' >= n
                                     | _ => false,
                          bind = fn (n, b) =>
                                    case b of
                                        CoreUtil.Exp.RelE _ => n + 1
                                      | _ => n}

datatype env_item =
         UnknownK
       | KnownK of kind

       | UnknownC
       | KnownC of con

       | UnknownE
       | KnownE of exp

       | Lift of int * int * int

val edepth = foldl (fn (UnknownE, n) => n + 1
                     | (KnownE _, n) => n + 1
                     | (_, n) => n) 0

val edepth' = foldl (fn (UnknownE, n) => n + 1
                      | (KnownE _, n) => n + 1
                      | (Lift (_, _, n'), n) => n + n'
                      | (_, n) => n) 0

type env = env_item list

fun ei2s ei =
    case ei of
        UnknownK => "UK"
      | KnownK _ => "KK"
      | UnknownC => "UC"
      | KnownC _ => "KC"
      | UnknownE => "UE"
      | KnownE _ => "KE"
      | Lift (_, n1, n2) => "(" ^ Int.toString n1 ^ ", " ^ Int.toString n2 ^ ")"

fun e2s env = String.concatWith " " (map ei2s env)

(*val deKnown = List.filter (fn KnownC _ => false
                            | KnownE _ => false
                            | KnownK _ => false
                            | _ => true)*)

val deKnown = ListUtil.mapConcat (fn KnownC _ => []
                                   | KnownE _ => []
                                   | KnownK _ => []
                                   | Lift (nk, nc, ne) => List.tabulate (nk, fn _ => UnknownK)
                                                          @ List.tabulate (nc, fn _ => UnknownC)
                                                          @ List.tabulate (ne, fn _ => UnknownE)
                                   | x => [x])

datatype result = Yes of env | No | Maybe

fun match (env, p : pat, e : exp) =
    let
        val baseline = length env

        fun match (env, p, e) =
            case (#1 p, #1 e) of
                (PWild, _) => Yes env
              | (PVar (x, t), _) => Yes (KnownE (multiLiftExpInExp (length env - baseline) e) :: env)

              | (PPrim p, EPrim p') =>
                if Prim.equal (p, p') then
                    Yes env
                else
                    No

              | (PCon (_, PConVar n1, _, NONE), ECon (_, PConVar n2, _, NONE)) =>
                if n1 = n2 then
                    Yes env
                else
                    No

              | (PCon (_, PConVar n1, _, SOME p), ECon (_, PConVar n2, _, SOME e)) =>
                if n1 = n2 then
                    match (env, p, e)
                else
                    No

              | (PCon (_, PConFfi {mod = m1, con = con1, ...}, _, NONE),
                 ECon (_, PConFfi {mod = m2, con = con2, ...}, _, NONE)) =>
                if m1 = m2 andalso con1 = con2 then
                    Yes env
                else
                    No

              | (PCon (_, PConFfi {mod = m1, con = con1, ...}, _, SOME ep),
                 ECon (_, PConFfi {mod = m2, con = con2, ...}, _, SOME e)) =>
                if m1 = m2 andalso con1 = con2 then
                    match (env, p, e)
                else
                    No

              | (PRecord xps, ERecord xes) =>
                if List.exists (fn ((CName _, _), _, _) => false
                                 | _ => true) xes then
                    Maybe
                else
                    let
                        fun consider (xps, env) =
                            case xps of
                                [] => Yes env
                              | (x, p, _) :: rest =>
                                case List.find (fn ((CName x', _), _, _) => x' = x
                                                 | _ => false) xes of
                                    NONE => No
                                  | SOME (_, e, _) =>
                                    case match (env, p, e) of
                                        No => No
                                      | Maybe => Maybe
                                      | Yes env => consider (rest, env)
                    in
                        consider (xps, env)
                    end

              | _ => Maybe
    in
        match (env, p, e)
    end

fun kindConAndExp (namedC, namedE) =
    let
        fun kind env (all as (k, loc)) =
            case k of
                KType => all
              | KArrow (k1, k2) => (KArrow (kind env k1, kind env k2), loc)
              | KName => all
              | KRecord k => (KRecord (kind env k), loc)
              | KUnit => all
              | KTuple ks => (KTuple (map (kind env) ks), loc)

              | KRel n =>
                let
                    fun find (n', env, nudge, lift) =
                        case env of
                            [] => raise Fail "Reduce.kind: KRel"
                          | UnknownC :: rest => find (n', rest, nudge, lift)
                          | KnownC _ :: rest => find (n', rest, nudge, lift)
                          | UnknownE :: rest => find (n', rest, nudge, lift)
                          | KnownE _ :: rest => find (n', rest, nudge, lift)
                          | Lift (lift', _, _) :: rest => find (n', rest, nudge + lift', lift + lift')
                          | UnknownK :: rest =>
                            if n' = 0 then
                                (KRel (n + nudge), loc)
                            else
                                find (n' - 1, rest, nudge, lift + 1)
                          | KnownK k :: rest =>
                            if n' = 0 then
                                kind (Lift (lift, 0, 0) :: rest) k
                            else
                                find (n' - 1, rest, nudge - 1, lift)
                in
                    find (n, env, 0, 0)
                end
              | KFun (x, k) => (KFun (x, kind (UnknownK :: env) k), loc)

        fun con env (all as (c, loc)) =
            ((*Print.prefaces "con" [("c", CorePrint.p_con CoreEnv.empty all)];*)
            case c of
                TFun (c1, c2) => (TFun (con env c1, con env c2), loc)
              | TCFun (x, k, c2) => (TCFun (x, kind env k, con (UnknownC :: env) c2), loc)
              | TKFun (x, c2) => (TKFun (x, con (UnknownK :: env) c2), loc)
              | TRecord c => (TRecord (con env c), loc)

              | CRel n =>
                let
                    fun find (n', env, nudge, liftK, liftC) =
                        case env of
                            [] => raise Fail "Reduce.con: CRel"
                          | UnknownK :: rest => find (n', rest, nudge, liftK + 1, liftC)
                          | KnownK _ :: rest => find (n', rest, nudge, liftK, liftC)
                          | UnknownE :: rest => find (n', rest, nudge, liftK, liftC)
                          | KnownE _ :: rest => find (n', rest, nudge, liftK, liftC)
                          | Lift (liftK', liftC', _) :: rest => find (n', rest, nudge + liftC',
                                                                      liftK + liftK', liftC + liftC')
                          | UnknownC :: rest =>
                            if n' = 0 then
                                (CRel (n + nudge), loc)
                            else
                                find (n' - 1, rest, nudge, liftK, liftC + 1)
                          | KnownC c :: rest =>
                            if n' = 0 then
                                con (Lift (liftK, liftC, 0) :: rest) c
                            else
                                find (n' - 1, rest, nudge - 1, liftK, liftC)
                in
                    (*print (Int.toString n ^ ": " ^ e2s env ^ "\n");*)
                    find (n, env, 0, 0, 0)
                end
              | CNamed n =>
                (case IM.find (namedC, n) of
                     NONE => all
                   | SOME c => c)
              | CFfi _ => all
              | CApp (c1, c2) =>
                let
                    val c1 = con env c1
                    val c2 = con env c2
                in
                    case #1 c1 of
                        CAbs (_, _, b) =>
                        con (KnownC c2 :: deKnown env) b

                      | CApp ((CMap (dom, ran), _), f) =>
                        (case #1 c2 of
                             CRecord (_, []) => (CRecord (kind env ran, []), loc)
                           | CRecord (_, (x, c) :: rest) =>
                             con (deKnown env)
                                 (CConcat ((CRecord (ran, [(x, (CApp (f, c), loc))]), loc),
                                           (CApp (c1, (CRecord (kind env dom, rest), loc)), loc)), loc)
                           | _ => (CApp (c1, c2), loc))                           

                      | _ => (CApp (c1, c2), loc)
                end
              | CAbs (x, k, b) => (CAbs (x, kind env k, con (UnknownC :: env) b), loc)

              | CKApp (c1, k) =>
                let
                    val c1 = con env c1
                in
                    case #1 c1 of
                        CKAbs (_, b) =>
                        con (KnownK k :: deKnown env) b

                      | _ => (CKApp (c1, kind env k), loc)
                end
              | CKAbs (x, b) => (CKAbs (x, con (UnknownK :: env) b), loc)

              | CName _ => all

              | CRecord (k, xcs) => (CRecord (kind env k, map (fn (x, c) => (con env x, con env c)) xcs), loc)
              | CConcat (c1, c2) =>
                let
                    val c1 = con env c1
                    val c2 = con env c2
                in
                    case (#1 c1, #1 c2) of
                        (CRecord (k, xcs1), CRecord (_, xcs2)) =>
                        (CRecord (kind env k, xcs1 @ xcs2), loc)
                      | _ => (CConcat (c1, c2), loc)
                end
              | CMap (dom, ran) => (CMap (kind env dom, kind env ran), loc)

              | CUnit => all

              | CTuple cs => (CTuple (map (con env) cs), loc)
              | CProj (c, n) =>
                let
                    val c = con env c
                in
                    case #1 c of
                        CTuple cs => List.nth (cs, n - 1)
                      | _ => (CProj (c, n), loc)
                end)

        fun patCon pc =
            case pc of
                PConVar _ => pc
              | PConFfi {mod = m, datatyp, params, con = c, arg, kind} =>
                PConFfi {mod = m, datatyp = datatyp, params = params, con = c,
                         arg = Option.map (con (map (fn _ => UnknownC) params)) arg,
                         kind = kind}


        val k = (KType, ErrorMsg.dummySpan)
        fun doPart e (this as (x, t), rest) =
            ((x, (EField (e, x, {field = t, rest = (CRecord (k, rest), #2 t)}), #2 t), t),
             this :: rest)

        fun exp env (all as (e, loc)) =
            let
                (*val () = Print.prefaces "exp" [("e", CorePrint.p_exp CoreEnv.empty all),
                                               ("env", Print.PD.string (e2s env))]*)
                val () = if dangling (edepth env) all then
                             (Print.prefaces "exp" [("e", CorePrint.p_exp CoreEnv.empty all),
                                                    ("env", Print.PD.string (e2s env))];
                              raise Fail "!")
                         else
                             ()

                val r = case e of
                            EPrim _ => all
                          | ERel n =>
                            let
                                fun find (n', env, nudge, liftK, liftC, liftE) =
                                    case env of
                                        [] => raise Fail ("Reduce.exp: ERel (" ^ ErrorMsg.spanToString loc ^ ")")
                                      | UnknownK :: rest => find (n', rest, nudge, liftK + 1, liftC, liftE)
                                      | KnownK _ :: rest => find (n', rest, nudge, liftK, liftC, liftE)
                                      | UnknownC :: rest => find (n', rest, nudge, liftK, liftC + 1, liftE)
                                      | KnownC _ :: rest => find (n', rest, nudge, liftK, liftC, liftE)
                                      | Lift (liftK', liftC', liftE') :: rest =>
                                        find (n', rest, nudge + liftE',
                                              liftK + liftK', liftC + liftC', liftE + liftE')
                                      | UnknownE :: rest =>
                                        if n' = 0 then
                                            (ERel (n + nudge), loc)
                                        else
                                            find (n' - 1, rest, nudge, liftK, liftC, liftE + 1)
                                      | KnownE e :: rest =>
                                        if n' = 0 then
                                            ((*print "SUBSTITUTING\n";*)
                                             exp (Lift (liftK, liftC, liftE) :: rest) e)
                                        else
                                            find (n' - 1, rest, nudge - 1, liftK, liftC, liftE)
                            in
                                (*print (Int.toString n ^ ": " ^ e2s env ^ "\n");*)
                                find (n, env, 0, 0, 0, 0)
                            end
                          | ENamed n =>
                            (case IM.find (namedE, n) of
                                 NONE => all
                               | SOME e => e)
                          | ECon (dk, pc, cs, eo) => (ECon (dk, patCon pc,
                                                            map (con env) cs, Option.map (exp env) eo), loc)
                          | EFfi _ => all
                          | EFfiApp (m, f, es) => (EFfiApp (m, f, map (exp env) es), loc)

                          (*| EApp (
                           (EApp
                                ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _), t1), _), t2), _),
                                        (EFfi ("Basis", "transaction_monad"), _)), _),
                                 (ECase (ed, pes, {disc, ...}), _)), _),
                           trans2) =>
                           let
                               val e' = (EFfi ("Basis", "bind"), loc)
                               val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                               val e' = (ECApp (e', t1), loc)
                               val e' = (ECApp (e', t2), loc)
                               val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)

                               val pes = map (fn (p, e) =>
                                                 let
                                                     val e' = (EApp (e', e), loc)
                                                     val e' = (EApp (e',
                                                                     multiLiftExpInExp (E.patBindsN p)
                                                                                       trans2), loc)
                                                     val e' = exp env e'
                                                 in
                                                     (p, e')
                                                 end) pes
                           in
                               (ECase (exp env ed,
                                       pes,
                                       {disc = con env disc,
                                        result = (CApp ((CFfi ("Basis", "transaction"), loc), con env t2), loc)}),
                                loc)
                           end*)

                          | EApp (e1, e2) =>
                            let
                                val env' = deKnown env

                                fun reassoc e =
                                    case #1 e of
                                        EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _),
                                                                          t1),
                                                                   _), t2), _),
                                                          (EFfi ("Basis", "transaction_monad"), _)), _),
                                                   (EServerCall (n, es, (EAbs (_, _, _, ke), _), dom, ran), _)), _),
                                             trans3) =>
                                        let
                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                                            val e' = (ECApp (e', dom), loc)
                                            val e' = (ECApp (e', t2), loc)
                                            val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)
                                            val e' = (EApp (e', ke), loc)
                                            val e' = (EApp (e', E.liftExpInExp 0 trans3), loc)
                                            val e' = reassoc e'
                                            val e' = (EAbs ("x", dom, t2, e'), loc)
                                            val e' = (EServerCall (n, es, e', dom, t2), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _),
                                                                          t1),
                                                                   _), t2), _),
                                                          (EFfi ("Basis", "transaction_monad"), _)), _),
                                                   (EServerCall (n, es, ke, dom, ran), _)), _),
                                             trans3) =>
                                        let
                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                                            val e' = (ECApp (e', dom), loc)
                                            val e' = (ECApp (e', t2), loc)
                                            val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)
                                            val e' = (EApp (e', exp (UnknownE :: env')
                                                                    (EApp (E.liftExpInExp 0 ke, (ERel 0, loc)), loc)),
                                                      loc)
                                            val e' = (EApp (e', E.liftExpInExp 0 trans3), loc)
                                            val e' = reassoc e'
                                            val e' = (EAbs ("x", dom, t2, e'), loc)
                                            val e' = (EServerCall (n, es, e', dom, t2), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _),
                                                                          t1),
                                                                   _), t2), _),
                                                          (EFfi ("Basis", "transaction_monad"), _)), _),
                                                   (ETailCall (n, es, (EAbs (_, _, _, ke), _), dom, ran), _)), _),
                                             trans3) =>
                                        let
                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                                            val e' = (ECApp (e', dom), loc)
                                            val e' = (ECApp (e', t2), loc)
                                            val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)
                                            val e' = (EApp (e', ke), loc)
                                            val e' = (EApp (e', E.liftExpInExp 0 trans3), loc)
                                            val e' = reassoc e'
                                            val e' = (EAbs ("x", dom, t2, e'), loc)
                                            val e' = (ETailCall (n, es, e', dom, t2), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _),
                                                                          t1),
                                                                   _), t2), _),
                                                          (EFfi ("Basis", "transaction_monad"), _)), _),
                                                   (ETailCall (n, es, ke, dom, ran), _)), _),
                                             trans3) =>
                                        let
                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                                            val e' = (ECApp (e', dom), loc)
                                            val e' = (ECApp (e', t2), loc)
                                            val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)
                                            val e' = (EApp (e', exp (UnknownE :: env')
                                                                    (EApp (E.liftExpInExp 0 ke, (ERel 0, loc)), loc)),
                                                      loc)
                                            val e' = (EApp (e', E.liftExpInExp 0 trans3), loc)
                                            val e' = reassoc e'
                                            val e' = (EAbs ("x", dom, t2, e'), loc)
                                            val e' = (ETailCall (n, es, e', dom, t2), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), mt),
                                                                           _), _), _), t3), _),
                                                          me), _),
                                                   (EApp ((EApp
                                                               ((EApp ((ECApp ((ECApp ((ECApp (
                                                                                        (EFfi ("Basis", "bind"), _), _), _),
                                                                                       t1), _), t2), _),
                                                                       _), _),
                                                                trans1), _), (EAbs (_, _, _, trans2), _)), _)), _),
                                             trans3) =>
                                        let
                                            val e'' = (EFfi ("Basis", "bind"), loc)
                                            val e'' = (ECApp (e'', mt), loc)
                                            val e'' = (ECApp (e'', t2), loc)
                                            val e'' = (ECApp (e'', t3), loc)
                                            val e'' = (EApp (e'', me), loc)
                                            val e'' = (EApp (e'', trans2), loc)
                                            val e'' = (EApp (e'', E.liftExpInExp 0 trans3), loc)
                                            val e'' = reassoc e''
                                            val e'' = (EAbs ("xb", t1, (CApp (mt, t3), loc), e''), loc)

                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', mt), loc)
                                            val e' = (ECApp (e', t1), loc)
                                            val e' = (ECApp (e', t3), loc)
                                            val e' = (EApp (e', me), loc)
                                            val e' = (EApp (e', trans1), loc)
                                            val e' = (EApp (e', e''), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), mt),
                                                                           _), _), _), t3), _),
                                                          me), _),
                                                   (EApp ((EApp
                                                               ((EApp ((ECApp ((ECApp ((ECApp (
                                                                                        (EFfi ("Basis", "bind"), _), _), _),
                                                                                       t1), _), t2), _),
                                                                       _), _),
                                                                trans1), _), trans2), _)), _),
                                             trans3) =>
                                        let
                                            val e'' = (EFfi ("Basis", "bind"), loc)
                                            val e'' = (ECApp (e'', mt), loc)
                                            val e'' = (ECApp (e'', t2), loc)
                                            val e'' = (ECApp (e'', t3), loc)
                                            val e'' = (EApp (e'', me), loc)
                                            val () = print "In2\n"
                                            val e'' = (EApp (e'', exp (UnknownE :: env')
                                                                      (EApp (E.liftExpInExp 0 trans2, (ERel 0, loc)),
                                                                       loc)),
                                                       loc)
                                            val () = print "Out2\n"
                                            val e'' = (EApp (e'', E.liftExpInExp 0 trans3), loc)
                                            val e'' = reassoc e''
                                            val e'' = (EAbs ("xb", t1, (CApp (mt, t3), loc), e''), loc)

                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', mt), loc)
                                            val e' = (ECApp (e', t1), loc)
                                            val e' = (ECApp (e', t3), loc)
                                            val e' = (EApp (e', me), loc)
                                            val e' = (EApp (e', trans1), loc)
                                            val e' = (EApp (e', e''), loc)
                                        in
                                            e'
                                        end

                                      | EApp
                                            ((EApp
                                                  ((EApp ((ECApp ((ECApp ((ECApp ((EFfi ("Basis", "bind"), loc), _), _),
                                                                          t1),
                                                                   _), t2), _),
                                                          (EFfi ("Basis", "transaction_monad"), _)), _),
                                                   (ECase (e, pes, {disc, ...}), _)), _), trans) =>
                                        let
                                            val e' = (EFfi ("Basis", "bind"), loc)
                                            val e' = (ECApp (e', (CFfi ("Basis", "transaction"), loc)), loc)
                                            val e' = (ECApp (e', t1), loc)
                                            val e' = (ECApp (e', t2), loc)
                                            val e' = (EApp (e', (EFfi ("Basis", "transaction_monad"), loc)), loc)

                                            fun doCase (p, e) =
                                                let
                                                    val e' = (EApp (e', e), loc)
                                                    val e' = (EApp (e',
                                                                    multiLiftExpInExp (E.patBindsN p)
                                                                                      trans), loc)
                                                in
                                                    (p, reassoc e')
                                                end
                                        in
                                            (ECase (e, map doCase pes,
                                                    {disc = disc,
                                                     result = (CApp ((CFfi ("Basis", "transaction"), loc),
                                                                     t2), loc)}), loc)
                                        end

                                      | _ => e

                                val e1 = exp env e1
                                val e2 = exp env e2
                                val e12 = reassoc (EApp (e1, e2), loc)
                            in
                                case #1 e12 of
                                    EApp ((EAbs (_, _, _, b), _), e2) =>
                                    exp (KnownE e2 :: env') b
                                  | _ => e12
                            end

                          | EAbs (x, dom, ran, e) => (EAbs (x, con env dom, con env ran, exp (UnknownE :: env) e), loc)

                          | ECApp (e, c) =>
                            let
                                val e = exp env e
                                val c = con env c
                            in
                                case #1 e of
                                    ECAbs (_, _, b) => exp (KnownC c :: deKnown env) b
                                  | _ => (ECApp (e, c), loc)
                            end

                          | ECAbs (x, k, e) => (ECAbs (x, kind env k, exp (UnknownC :: env) e), loc)

                          | EKApp (e, k) =>
                            let
                                val e = exp env e
                            in
                                case #1 e of
                                    EKAbs (_, b) => exp (KnownK k :: deKnown env) b
                                  | _ => (EKApp (e, kind env k), loc)
                            end

                          | EKAbs (x, e) => (EKAbs (x, exp (UnknownK :: env) e), loc)

                          | ERecord xcs => (ERecord (map (fn (x, e, t) => (con env x, exp env e, con env t)) xcs), loc)
                          | EField (e, c, {field, rest}) =>
                            let
                                val e = exp env e
                                val c = con env c

                                fun default () = (EField (e, c, {field = con env field, rest = con env rest}), loc)
                            in
                                case (#1 e, #1 c) of
                                    (ERecord xcs, CName x) =>
                                    (case List.find (fn ((CName x', _), _, _) => x' = x | _ => false) xcs of
                                         NONE => default ()
                                       | SOME (_, e, _) => e)
                                  | _ => default ()
                            end

                          | EConcat (e1, c1, e2, c2) =>
                            let
                                val e1 = exp env e1
                                val e2 = exp env e2
                            in
                                case (#1 e1, #1 e2) of
                                    (ERecord xes1, ERecord xes2) => (ERecord (xes1 @ xes2), loc)
                                  | _ =>
                                    let
                                        val c1 = con env c1
                                        val c2 = con env c2
                                    in
                                        case (#1 c1, #1 c2) of
                                            (CRecord (k, xcs1), CRecord (_, xcs2)) =>
                                            let
                                                val (xes1, rest) = ListUtil.foldlMap (doPart e1) [] xcs1
                                                val (xes2, _) = ListUtil.foldlMap (doPart e2) rest xcs2
                                            in
                                                exp (deKnown env) (ERecord (xes1 @ xes2), loc)
                                            end
                                          | _ => (EConcat (e1, c1, e2, c2), loc)
                                    end
                            end

                          | ECut (e, c, {field, rest}) =>
                            let
                                val e = exp env e
                                val c = con env c

                                fun default () =
                                    let
                                        val rest = con env rest
                                    in
                                        case #1 rest of
                                            CRecord (k, xcs) =>
                                            let
                                                val (xes, _) = ListUtil.foldlMap (doPart e) [] xcs
                                            in
                                                exp (deKnown env) (ERecord xes, loc)
                                            end
                                          | _ => (ECut (e, c, {field = con env field, rest = rest}), loc)
                                    end
                            in
                                case (#1 e, #1 c) of
                                    (ERecord xes, CName x) =>
                                    if List.all (fn ((CName _, _), _, _) => true | _ => false) xes then
                                        (ERecord (List.filter (fn ((CName x', _), _, _) => x' <> x
                                                                | _ => raise Fail "Reduce: ECut") xes), loc)
                                    else
                                        default ()
                                  | _ => default ()
                            end

                          | ECutMulti (e, c, {rest}) =>
                            let
                                val e = exp env e
                                val c = con env c

                                fun default () =
                                    let
                                        val rest = con env rest
                                    in
                                        case #1 rest of
                                            CRecord (k, xcs) =>
                                            let
                                                val (xes, _) = ListUtil.foldlMap (doPart e) [] xcs
                                            in
                                                exp (deKnown env) (ERecord xes, loc)
                                            end
                                          | _ => (ECutMulti (e, c, {rest = rest}), loc)
                                    end
                            in
                                case (#1 e, #1 c) of
                                    (ERecord xes, CRecord (_, xcs)) =>
                                    if List.all (fn ((CName _, _), _, _) => true | _ => false) xes
                                       andalso List.all (fn ((CName _, _), _) => true | _ => false) xcs then
                                        (ERecord (List.filter (fn ((CName x', _), _, _) =>
                                                                  List.all (fn ((CName x, _), _) => x' <> x
                                                                             | _ => raise Fail "Reduce: ECutMulti [1]") xcs
                                                                | _ => raise Fail "Reduce: ECutMulti [2]") xes), loc)
                                    else
                                        default ()
                                  | _ => default ()
                            end

                          | ECase (_, [((PRecord [], _), e)], _) => exp env e
                          | ECase (_, [((PWild, _), e)], _) => exp env e

                          | ECase (e, pes, {disc, result}) =>
                            let
                                fun patBinds (p, _) =
                                    case p of
                                        PWild => 0
                                      | PVar _ => 1
                                      | PPrim _ => 0
                                      | PCon (_, _, _, NONE) => 0
                                      | PCon (_, _, _, SOME p) => patBinds p
                                      | PRecord xpts => foldl (fn ((_, p, _), n) => n + patBinds p) 0 xpts

                                fun pat (all as (p, loc)) =
                                    case p of
                                        PWild => all
                                      | PVar (x, t) => (PVar (x, con env t), loc)
                                      | PPrim _ => all
                                      | PCon (dk, pc, cs, po) =>
                                        (PCon (dk, patCon pc, map (con env) cs, Option.map pat po), loc)
                                      | PRecord xpts => (PRecord (map (fn (x, p, t) => (x, pat p, con env t)) xpts), loc)

                                fun push () =
                                    (ECase (exp env e,
                                            map (fn (p, e) => (pat p,
                                                               exp (List.tabulate (patBinds p,
                                                                                fn _ => UnknownE) @ env) e))
                                                pes, {disc = con env disc, result = con env result}), loc)

                                fun search pes =
                                    case pes of
                                        [] => push ()
                                      | (p, body) :: pes =>
                                        case match (env, p, e) of
                                            No => search pes
                                          | Maybe => push ()
                                          | Yes env' => exp env' body
                            in
                                search pes
                            end

                          | EWrite e => (EWrite (exp env e), loc)
                          | EClosure (n, es) => (EClosure (n, map (exp env) es), loc)

                          | ELet (x, t, e1, e2) =>
                            (ELet (x, con env t, exp env e1, exp (UnknownE :: env) e2), loc)

                          | EServerCall (n, es, e, t1, t2) => (EServerCall (n, map (exp env) es, exp env e,
                                                                            con env t1, con env t2), loc)
                          | ETailCall (n, es, e, t1, t2) => (ETailCall (n, map (exp env) es, exp env e,
                                                                        con env t1, con env t2), loc)
            in
                (*if dangling (edepth' (deKnown env)) r then
                    (Print.prefaces "exp" [("e", CorePrint.p_exp CoreEnv.empty all),
                                           ("r", CorePrint.p_exp CoreEnv.empty r)];
                     raise Fail "!!")
                else
                    ();*)
                r
            end
    in
        {kind = kind, con = con, exp = exp}
    end

fun kind namedC env k = #kind (kindConAndExp (namedC, IM.empty)) env k
fun con namedC env c = #con (kindConAndExp (namedC, IM.empty)) env c
fun exp (namedC, namedE) env e = #exp (kindConAndExp (namedC, namedE)) env e

fun reduce file =
    let
        val uses = CoreUtil.File.fold {kind = fn (_, m) => m,
                                       con = fn (_, m) => m,
                                       exp = fn (e, m) =>
                                                case e of
                                                    ENamed n => IM.insert (m, n, 1 + Option.getOpt (IM.find (m, n), 0))
                                                  | _ => m,
                                       decl = fn (_, m) => m}
                                      IM.empty file

        fun isPoly names = CoreUtil.Con.exists {kind = fn _ => false,
                                                con = fn TCFun _ => true
                                                       | TKFun _ => true
                                                       | CNamed n => IS.member (names, n)
                                                       | _ => false}

        val size = CoreUtil.Exp.fold {kind = fn (_, n) => n,
                                      con = fn (_, n) => n,
                                      exp = fn (_, n) => n + 1} 0

        fun mayInline (polyC, n, t, e) =
            case IM.find (uses, n) of
                NONE => false
              | SOME count => count <= 1
                              orelse isPoly polyC t
                              orelse size e <= Settings.getCoreInline ()

        fun doDecl (d as (_, loc), st as (polyC, namedC, namedE)) =
            case #1 d of
                DCon (x, n, k, c) =>
                let
                    val k = kind namedC [] k
                    val c = con namedC [] c
                in
                    ((DCon (x, n, k, c), loc),
                     (if isPoly polyC c then
                          IS.add (polyC, n)
                      else
                          polyC,
                      IM.insert (namedC, n, c),
                      namedE))
                end
              | DDatatype dts =>
                ((DDatatype (map (fn (x, n, ps, cs) =>
                                     let
                                         val env = map (fn _ => UnknownC) ps
                                     in
                                         (x, n, ps, map (fn (x, n, co) => (x, n, Option.map (con namedC env) co)) cs)
                                     end) dts), loc),
                 (if List.exists (fn (_, _, _, cs) => List.exists (fn (_, _, co) => case co of
                                                                                        NONE => false
                                                                                      | SOME c => isPoly polyC c) cs)
                                 dts then
                      foldl (fn ((_, n, _, _), polyC) => IS.add (polyC, n)) polyC dts
                  else
                      polyC,
                  namedC,
                  namedE))
              | DVal (x, n, t, e, s) =>
                let
                    val t = con namedC [] t
                    val e = exp (namedC, namedE) [] e
                in
                    ((DVal (x, n, t, e, s), loc),
                     (polyC,
                      namedC,
                      if mayInline (polyC, n, t, e) then
                          IM.insert (namedE, n, e)
                      else
                          namedE))
                end
              | DValRec vis =>
                ((DValRec (map (fn (x, n, t, e, s) => (x, n, con namedC [] t,
                                                       exp (namedC, namedE) [] e, s)) vis), loc),
                 st)
              | DExport _ => (d, st)
              | DTable (s, n, c, s', pe, pc, ce, cc) => ((DTable (s, n, con namedC [] c, s',
                                                                  exp (namedC, namedE) [] pe,
                                                                  con namedC [] pc,
                                                                  exp (namedC, namedE) [] ce,
                                                                  con namedC [] cc), loc), st)
              | DSequence _ => (d, st)
              | DView (s, n, s', e, c) => ((DView (s, n, s', exp (namedC, namedE) [] e, con namedC [] c), loc), st)
              | DDatabase _ => (d, st)
              | DCookie (s, n, c, s') => ((DCookie (s, n, con namedC [] c, s'), loc), st)
              | DStyle (s, n, s') => ((DStyle (s, n, s'), loc), st)

        val (file, _) = ListUtil.foldlMap doDecl (IS.empty, IM.empty, IM.empty) file
    in
        file
    end

end
