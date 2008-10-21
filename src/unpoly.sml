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

(* Simplify a Core program by repeating polymorphic function definitions *)

structure Unpoly :> UNPOLY = struct

open Core

structure E = CoreEnv
structure U = CoreUtil

structure IS = IntBinarySet
structure IM = IntBinaryMap


(** The actual specialization *)

val liftConInCon = E.liftConInCon
val subConInCon = E.subConInCon

val liftConInExp = E.liftConInExp
val subConInExp = E.subConInExp

val isOpen = U.Con.exists {kind = fn _ => false,
                           con = fn c =>
                                    case c of
                                        CRel _ => true
                                      | _ => false}

fun unpolyNamed (xn, rep) =
    U.Exp.map {kind = fn k => k,
               con = fn c => c,
               exp = fn e =>
                        case e of
                            ECApp (e', _) =>
                            let
                                fun isTheOne (e, _) =
                                    case e of
                                        ENamed xn' => xn' = xn
                                      | ECApp (e, _) => isTheOne e
                                      | _ => false
                            in
                                if isTheOne e' then
                                    rep
                                else
                                    e
                            end
                          | _ => e}

type state = {
     funcs : (kind list * (string * int * con * exp * string) list) IM.map,
     decls : decl list,
     nextName : int
}

fun kind (k, st) = (k, st)

fun con (c, st) = (c, st)

fun exp (e, st : state) =
    case e of
        ECApp _ =>
        let
            (*val () = Print.prefaces "exp" [("e", CorePrint.p_exp CoreEnv.empty (e, ErrorMsg.dummySpan))]*)

            fun unravel (e, cargs) =
                case e of
                    ECApp ((e, _), c) => unravel (e, c :: cargs)
                  | ENamed n => SOME (n, rev cargs)
                  | _ => NONE
        in
            case unravel (e, []) of
                NONE => (e, st)
              | SOME (n, cargs) =>
                if List.exists isOpen cargs then
                    (e, st)
                else
                    case IM.find (#funcs st, n) of
                        NONE => (e, st)
                      | SOME (ks, vis) =>
                        let
                            val (vis, nextName) = ListUtil.foldlMap
                                                      (fn ((x, n, t, e, s), nextName) =>
                                                          ((x, nextName, n, t, e, s), nextName + 1))
                                                      (#nextName st) vis

                            fun specialize (x, n, n_old, t, e, s) =
                                let
                                    fun trim (t, e, cargs) =
                                        case (t, e, cargs) of
                                            ((TCFun (_, _, t), _),
                                             (ECAbs (_, _, e), _),
                                             carg :: cargs) =>
                                            let
                                                val t = subConInCon (length cargs, carg) t
                                                val e = subConInExp (length cargs, carg) e
                                            in
                                                trim (t, e, cargs)
                                            end
                                          | (_, _, []) =>
                                            let
                                                val e = foldl (fn ((_, n, n_old, _, _, _), e) =>
                                                                  unpolyNamed (n_old, ENamed n) e)
                                                              e vis
                                            in
                                                SOME (t, e)
                                            end
                                          | _ => NONE
                                in
                                    (*Print.prefaces "specialize"
                                                     [("t", CorePrint.p_con CoreEnv.empty t),
                                                      ("e", CorePrint.p_exp CoreEnv.empty e),
                                                      ("|cargs|", Print.PD.string (Int.toString (length cargs)))];*)
                                    Option.map (fn (t, e) => (x, n, n_old, t, e, s))
                                               (trim (t, e, cargs))
                                end

                            val vis = List.map specialize vis
                        in
                            if List.exists (not o Option.isSome) vis orelse length cargs > length ks then
                                (e, st)
                            else
                                let
                                    val vis = List.mapPartial (fn x => x) vis
                                    val vis = map (fn (x, n, n_old, t, e, s) =>
                                                      (x ^ "_unpoly", n, n_old, t, e, s)) vis
                                    val vis' = map (fn (x, n, _, t, e, s) =>
                                                       (x, n, t, e, s)) vis

                                    val ks' = List.drop (ks, length cargs)
                                in
                                    case List.find (fn (_, _, n_old, _, _, _) => n_old = n) vis of
                                        NONE => raise Fail "Unpoly: Inconsistent 'val rec' record"
                                      | SOME (_, n, _, _, _, _) =>
                                        (ENamed n,
                                         {funcs = foldl (fn (vi, funcs) =>
                                                            IM.insert (funcs, #2 vi, (ks', vis')))
                                                        (#funcs st) vis',
                                          decls = (DValRec vis', ErrorMsg.dummySpan) :: #decls st,
                                          nextName = nextName})
                                end
                        end
        end
      | _ => (e, st)

fun decl (d, st : state) =
    case d of
        DValRec (vis as ((x, n, t, e, s) :: rest)) =>
        let
            fun unravel (e, cargs) =
                case e of
                    (ECAbs (_, k, e), _) =>
                    unravel (e, k :: cargs)
                  | _ => rev cargs

            val cargs = unravel (e, [])

            fun unravel (e, cargs) =
                case (e, cargs) of
                    ((ECAbs (_, k, e), _), k' :: cargs) =>
                    U.Kind.compare (k, k') = EQUAL
                    andalso unravel (e, cargs)
                  | (_, []) => true
                  | _ => false
        in
            if List.exists (fn vi => not (unravel (#4 vi, cargs))) rest then
                (d, st)
            else
                let
                    val ns = IS.addList (IS.empty, map #2 vis)
                    val nargs = length cargs

                    fun deAbs (e, cargs) =
                        case (e, cargs) of
                            ((ECAbs (_, _, e), _), _ :: cargs) => deAbs (e, cargs)
                          | (_, []) => e
                          | _ => raise Fail "Unpoly: deAbs"

                    (** Verifying lack of polymorphic recursion *)

                    fun kind _ = false
                    fun con _ = false

                    fun exp e =
                        case e of
                            ECApp (e, c) =>
                            let
                                fun isIrregular (e, pos) =
                                    case #1 e of
                                        ENamed n =>
                                        IS.member (ns, n)
                                        andalso
                                        (case #1 c of
                                             CRel i => i <> nargs - pos
                                           | _ => true)
                                      | ECApp (e, _) => isIrregular (e, pos + 1)
                                      | _ => false
                            in
                                isIrregular (e, 1)
                            end
                          | ECAbs _ => true
                          | _ => false

                    val irregular = U.Exp.exists {kind = kind, con = con, exp = exp}
                in
                    if List.exists (fn x => irregular (deAbs (#4 x, cargs))) vis then
                        (d, st)
                    else
                        (d, {funcs = foldl (fn (vi, funcs) =>
                                               IM.insert (funcs, #2 vi, (cargs, vis)))
                                           (#funcs st) vis,
                             decls = #decls st,
                             nextName = #nextName st})
                end
        end

      | _ => (d, st)

val polyDecl = U.Decl.foldMap {kind = kind, con = con, exp = exp, decl = decl}

fun unpoly file =
    let
        fun doDecl (d : decl, st : state) =
            let
                val (d, st) = polyDecl st d
            in
                (rev (d :: #decls st),
                 {funcs = #funcs st,
                  decls = [],
                  nextName = #nextName st})
            end

        val (ds, _) = ListUtil.foldlMapConcat doDecl
                      {funcs = IM.empty,
                       decls = [],
                       nextName = U.File.maxName file + 1} file
    in
        ds
    end

end
