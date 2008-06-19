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

(* Pretty-printing Laconic/Web *)

structure SourcePrint :> SOURCE_PRINT = struct

open Print.PD
open Print

open Source

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
      | KWild => string "_"

and p_kind k = p_kind' false k

fun p_explicitness e =
    case e of
        Explicit => string "::"
      | Implicit => string ":::"

fun p_con' par (c, _) =
    case c of
        CAnnot (c, k) => box [string "(",
                              p_con c,
                              space,
                              string "::",
                              space,
                              p_kind k,
                              string ")"]

      | TFun (t1, t2) => parenIf par (box [p_con' true t1,
                                           space,
                                           string "->",
                                           space,
                                           p_con t2])
      | TCFun (e, x, k, c) => parenIf par (box [string x,
                                                space,
                                                p_explicitness e,
                                                space,
                                                p_kind k,
                                                space,
                                                string "->",
                                                space,
                                                p_con c])
      | TRecord (CRecord xcs, _) => box [string "{",
                                         p_list (fn (x, c) =>
                                                    box [p_name x,
                                                         space,
                                                         string ":",
                                                         space,
                                                         p_con c]) xcs,
                                         string "}"]
      | TRecord c => box [string "$",
                          p_con' true c]

      | CVar (ss, s) => p_list_sep (string ".") string (ss @ [s])
      | CApp (c1, c2) => parenIf par (box [p_con c1,
                                           space,
                                           p_con' true c2])
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
                                            p_con c])

      | CName s => box [string "#", string s]

      | CRecord xcs => box [string "[",
                            p_list (fn (x, c) =>
                                       box [p_con x,
                                            space,
                                            string "=",
                                            space,
                                            p_con c]) xcs,
                            string "]"]
      | CConcat (c1, c2) => parenIf par (box [p_con' true c1,
                                              space,
                                              string "++",
                                              space,
                                              p_con c2])
      | CWild k => box [string "(_",
                        space,
                        string "::",
                        space,
                        p_kind k]
        
and p_con c = p_con' false c

and p_name (all as (c, _)) =
    case c of
        CName s => string s
      | _ => p_con all

fun p_exp' par (e, _) =
    case e of
        EAnnot (e, t) => box [string "(",
                              p_exp e,
                              space,
                              string ":",
                              space,
                              p_con t,
                              string ")"]        

      | EPrim p => Prim.p_t p
      | EVar (ss, s) => p_list_sep (string ".") string (ss @ [s])
      | EApp (e1, e2) => parenIf par (box [p_exp e1,
                                           space,
                                           p_exp' true e2])
      | EAbs (x, NONE, e) => parenIf par (box [string "fn",
                                               space,
                                               string x,
                                               space,
                                               string "=>",
                                               space,
                                               p_exp e])
      | EAbs (x, SOME t, e) => parenIf par (box [string "fn",
                                                 space,
                                                 string x,
                                                 space,
                                                 string ":",
                                                 space,
                                                 p_con t,
                                                 space,
                                                 string "=>",
                                                 space,
                                                 p_exp e])
      | ECApp (e, c) => parenIf par (box [p_exp e,
                                          space,
                                          string "[",
                                          p_con c,
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
                                                  p_exp e])

      | ERecord xes => box [string "{",
                            p_list (fn (x, e) =>
                                       box [p_name x,
                                            space,
                                            string "=",
                                            space,
                                            p_exp e]) xes,
                            string "}"]
      | EField (e, c) => box [p_exp' true e,
                              string ".",
                              p_con' true c]


and p_exp e = p_exp' false e

fun p_sgn_item (sgi, _) =
    case sgi of
        SgiConAbs (x, k) => box [string "con",
                                 space,
                                 string x,
                                 space,
                                 string "::",
                                 space,
                                 p_kind k]
      | SgiCon (x, NONE, c) => box [string "con",
                                    space,
                                    string x,
                                    space,
                                    string "=",
                                    space,
                                    p_con c]
      | SgiCon (x, SOME k, c) => box [string "con",
                                      space,
                                      string x,
                                      space,
                                      string "::",
                                      space,
                                      p_kind k,
                                      space,
                                      string "=",
                                      space,
                                      p_con c]
      | SgiVal (x, c) => box [string "val",
                              space,
                              string x,
                              space,
                              string ":",
                              space,
                              p_con c]
      | SgiStr (x, sgn) => box [string "structure",
                                space,
                                string x,
                                space,
                                string ":",
                                space,
                                p_sgn sgn]

and p_sgn (sgn, _) =
    case sgn of
        SgnConst sgis => box [string "sig",
                              newline,
                              p_list_sep newline p_sgn_item sgis,
                              newline,
                              string "end"]
      | SgnVar x => string x
      | SgnFun (x, sgn, sgn') => box [string "functor",
                                      space,
                                      string "(",
                                      string x,
                                      space,
                                      string ":",
                                      p_sgn sgn,
                                      string ")",
                                      space,
                                      string ":",
                                      space,
                                      p_sgn sgn']
      | SgnWhere (sgn, x, c) => box [p_sgn sgn,
                                     space,
                                     string "where",
                                     space,
                                     string "con",
                                     space,
                                     string x,
                                     space,
                                     string "=",
                                     space,
                                     p_con c]

fun p_decl ((d, _) : decl) =
    case d of
        DCon (x, NONE, c) => box [string "con",
                                  space,
                                  string x,
                                  space,
                                  string "=",
                                  space,
                                  p_con c]
      | DCon (x, SOME k, c) => box [string "con",
                                    space,
                                    string x,
                                    space,
                                    string "::",
                                    space,
                                    p_kind k,
                                    space,
                                    string "=",
                                    space,
                                    p_con c]
      | DVal (x, NONE, e) => box [string "val",
                                  space,
                                  string x,
                                  space,
                                  string "=",
                                  space,
                                  p_exp e]
      | DVal (x, SOME t, e) => box [string "val",
                                    space,
                                    string x,
                                    space,
                                    string ":",
                                    space,
                                    p_con t,
                                    space,
                                    string "=",
                                    space,
                                    p_exp e]

      | DSgn (x, sgn) => box [string "signature",
                              space,
                              string x,
                              space,
                              string "=",
                              space,
                              p_sgn sgn]
      | DStr (x, NONE, str) => box [string "structure",
                                    space,
                                    string x,
                                    space,
                                    string "=",
                                    space,
                                    p_str str]
      | DStr (x, SOME sgn, str) => box [string "structure",
                                        space,
                                        string x,
                                        space,
                                        string ":",
                                        space,
                                        p_sgn sgn,
                                        space,
                                        string "=",
                                        space,
                                        p_str str]

and p_str (str, _) =
    case str of
        StrConst ds => box [string "struct",
                            newline,
                            p_list_sep newline p_decl ds,
                            newline,
                            string "end"]
      | StrVar x => string x
      | StrProj (str, x) => box [p_str str,
                                 string ".",
                                 string x]
      | StrFun (x, sgn, NONE, str) => box [string "functor",
                                           space,
                                           string "(",
                                           string x,
                                           space,
                                           string ":",
                                           p_sgn sgn,
                                           string ")",
                                           space,
                                           string "=>",
                                           space,
                                           p_str str]
      | StrFun (x, sgn, SOME sgn', str) => box [string "functor",
                                                space,
                                                string "(",
                                                string x,
                                                space,
                                                string ":",
                                                p_sgn sgn,
                                                string ")",
                                                space,
                                                string ":",
                                                space,
                                                p_sgn sgn',
                                                space,
                                                string "=>",
                                                space,
                                                p_str str]
      | StrApp (str1, str2) => box [p_str str1,
                                    string "(",
                                    p_str str2,
                                    string ")"]

val p_file = p_list_sep newline p_decl

end
