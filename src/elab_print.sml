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

(* Pretty-printing elaborated Laconic/Web *)

structure ElabPrint :> ELAB_PRINT = struct

open Print.PD
open Print

open Elab

structure E = ElabEnv

val debug = ref false

fun p_kind' par (k, _) =
    case k of
        KType => string "Type"
      | KArrow (k1, k2) => parenIf par (box [p_kind' true k1,
                                             space,
                                             string "->",
                                             space,
                                             p_kind k2])
      | KName => string "Name"
      | KRecord k => box [string "{", p_kind k, string "}"]

      | KError => string "<ERROR>"
      | KUnif (_, ref (SOME k)) => p_kind' par k
      | KUnif (s, _) => string ("<UNIF:" ^ s ^ ">")

and p_kind k = p_kind' false k

fun p_explicitness e =
    case e of
        Explicit => string "::"
      | Implicit => string ":::"

fun p_con' par env (c, _) =
    case c of
        TFun (t1, t2) => parenIf par (box [p_con' true env t1,
                                           space,
                                           string "->",
                                           space,
                                           p_con env t2])
      | TCFun (e, x, k, c) => parenIf par (box [string x,
                                                space,
                                                p_explicitness e,
                                                space,
                                                p_kind k,
                                                space,
                                                string "->",
                                                space,
                                                p_con (E.pushCRel env x k) c])
      | TRecord (CRecord (_, xcs), _) => box [string "{",
                                              p_list (fn (x, c) =>
                                                         box [p_con env x,
                                                              space,
                                                              string ":",
                                                              space,
                                                              p_con env c]) xcs,
                                              string "}"]
      | TRecord c => box [string "$",
                          p_con' true env c]

      | CRel n =>
        if !debug then
            string (#1 (E.lookupCRel env n) ^ "_" ^ Int.toString n)
        else
            string (#1 (E.lookupCRel env n))
      | CNamed n =>
        if !debug then
            string (#1 (E.lookupCNamed env n) ^ "__" ^ Int.toString n)
        else
            string (#1 (E.lookupCNamed env n))

      | CApp (c1, c2) => parenIf par (box [p_con env c1,
                                           space,
                                           p_con' true env c2])
      | CAbs (x, k, c) => parenIf par (box [string "fn",
                                            space,
                                            string x,
                                            space,
                                            string "::",
                                            space,
                                            p_kind k,
                                            space,
                                            string "=>",
                                            space,
                                            p_con (E.pushCRel env x k) c])

      | CName s => box [string "#", string s]

      | CRecord (k, xcs) =>
        if !debug then
            parenIf par (box [string "[",
                              p_list (fn (x, c) =>
                                         box [p_con env x,
                                              space,
                                              string "=",
                                              space,
                                              p_con env c]) xcs,
                              string "]::",
                              p_kind k])
        else
            parenIf par (box [string "[",
                              p_list (fn (x, c) =>
                                         box [p_con env x,
                                              space,
                                              string "=",
                                              space,
                                              p_con env c]) xcs,
                              string "]"])
      | CConcat (c1, c2) => parenIf par (box [p_con' true env c1,
                                              space,
                                              string "++",
                                              space,
                                              p_con env c2])

      | CError => string "<ERROR>"
      | CUnif (_, _, ref (SOME c)) => p_con' par env c
      | CUnif (k, s, _) => box [string ("<UNIF:" ^ s ^ "::"),
                               p_kind k,
                               string ">"]
        
and p_con env = p_con' false env

fun p_exp' par env (e, _) =
    case e of
        ERel n =>
        if !debug then
            string (#1 (E.lookupERel env n) ^ "_" ^ Int.toString n)
        else
            string (#1 (E.lookupERel env n))
      | ENamed n =>
        if !debug then
            string (#1 (E.lookupENamed env n) ^ "__" ^ Int.toString n)
        else
            string (#1 (E.lookupENamed env n))
      | EApp (e1, e2) => parenIf par (box [p_exp env e1,
                                           space,
                                           p_exp' true env e2])
      | EAbs (x, t, e) => parenIf par (box [string "fn",
                                            space,
                                            string x,
                                            space,
                                            string ":",
                                            space,
                                            p_con env t,
                                            space,
                                            string "=>",
                                            space,
                                            p_exp (E.pushERel env x t) e])
      | ECApp (e, c) => parenIf par (box [p_exp env e,
                                          space,
                                          string "[",
                                          p_con env c,
                                          string "]"])
      | ECAbs (exp, x, k, e) => parenIf par (box [string "fn",
                                                  space,
                                                  string x,
                                                  space,
                                                  p_explicitness exp,
                                                  space,
                                                  p_kind k,
                                                  space,
                                                  string "=>",
                                                  space,
                                                  p_exp (E.pushCRel env x k) e])

      | ERecord xes => box [string "{",
                            p_list (fn (x, e) =>
                                       box [p_con env x,
                                            space,
                                            string "=",
                                            space,
                                            p_exp env e]) xes,
                            string "}"]
      | EField (e, c, {field, rest}) =>
        if !debug then
            box [p_exp' true env e,
                 string ".",
                 p_con' true env c,
                 space,
                 string "[",
                 p_con env field,
                 space,
                 string " in ",
                 space,
                 p_con env rest,
                 string "]"]
        else
            box [p_exp' true env e,
                 string ".",
                 p_con' true env c]
            
      | EError => string "<ERROR>"

and p_exp env = p_exp' false env

fun p_decl env ((d, _) : decl) =
    case d of
        DCon (x, n, k, c) =>
        let
            val xp = if !debug then
                         box [string x,
                              string "__",
                              string (Int.toString n)]
                     else
                         string x
        in
            box [string "con",
                 space,
                 xp,
                 space,
                 string "::",
                 space,
                 p_kind k,
                 space,
                 string "=",
                 space,
                 p_con env c]
        end
      | DVal (x, n, t, e) =>
        let
            val xp = if !debug then
                         box [string x,
                              string "__",
                              string (Int.toString n)]
                     else
                         string x        
        in
            box [string "val",
                 space,
                 xp,
                 space,
                 string ":",
                 space,
                 p_con env t,
                 space,
                 string "=",
                 space,
                 p_exp env e]
        end

fun p_file env file =
    let
        val (_, pds) = ListUtil.mapfoldl (fn (d, env) =>
                                             (E.declBinds env d,
                                              p_decl env d))
                             env file
    in
        p_list_sep newline (fn x => x) pds
    end

end
