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

structure Explify :> EXPLIFY = struct

structure EM = ErrorMsg
structure L = Elab
structure L' = Expl

fun explifyKind (k, loc) =
    case k of
        L.KType => (L'.KType, loc)
      | L.KArrow (k1, k2) => (L'.KArrow (explifyKind k1, explifyKind k2), loc)
      | L.KName => (L'.KName, loc)
      | L.KRecord k => (L'.KRecord (explifyKind k), loc)

      | L.KError => raise Fail ("explifyKind: KError at " ^ EM.spanToString loc)
      | L.KUnif (_, ref (SOME k)) => explifyKind k
      | L.KUnif _ => raise Fail ("explifyKind: KUnif at " ^ EM.spanToString loc)

fun explifyCon (c, loc) =
    case c of
        L.TFun (t1, t2) => (L'.TFun (explifyCon t1, explifyCon t2), loc)
      | L.TCFun (_, x, k, t) => (L'.TCFun (x, explifyKind k, explifyCon t), loc)
      | L.TRecord c => (L'.TRecord (explifyCon c), loc)

      | L.CRel n => (L'.CRel n, loc)
      | L.CNamed n => (L'.CNamed n, loc)
      | L.CModProj (m, ms, x) => (L'.CModProj (m, ms, x), loc)

      | L.CApp (c1, c2) => (L'.CApp (explifyCon c1, explifyCon c2), loc)
      | L.CAbs (x, k, c) => (L'.CAbs (x, explifyKind k, explifyCon c), loc)

      | L.CName s => (L'.CName s, loc)

      | L.CRecord (k, xcs) => (L'.CRecord (explifyKind k, map (fn (c1, c2) => (explifyCon c1, explifyCon c2)) xcs), loc)
      | L.CConcat (c1, c2) => (L'.CConcat (explifyCon c1, explifyCon c2), loc)

      | L.CError => raise Fail ("explifyCon: CError at " ^ EM.spanToString loc)
      | L.CUnif (_, _, ref (SOME c)) => explifyCon c
      | L.CUnif _ => raise Fail ("explifyCon: CUnif at " ^ EM.spanToString loc)

fun explifyExp (e, loc) =
    case e of
        L.EPrim p => (L'.EPrim p, loc)
      | L.ERel n => (L'.ERel n, loc)
      | L.ENamed n => (L'.ENamed n, loc)
      | L.EModProj (m, ms, x) => (L'.EModProj (m, ms, x), loc)
      | L.EApp (e1, e2) => (L'.EApp (explifyExp e1, explifyExp e2), loc)
      | L.EAbs (x, dom, ran, e1) => (L'.EAbs (x, explifyCon dom, explifyCon ran, explifyExp e1), loc)
      | L.ECApp (e1, c) => (L'.ECApp (explifyExp e1, explifyCon c), loc)
      | L.ECAbs (_, x, k, e1) => (L'.ECAbs (x, explifyKind k, explifyExp e1), loc)

      | L.ERecord xes => (L'.ERecord (map (fn (c, e, t) => (explifyCon c, explifyExp e, explifyCon t)) xes), loc)
      | L.EField (e1, c, {field, rest}) => (L'.EField (explifyExp e1, explifyCon c,
                                                       {field = explifyCon field, rest = explifyCon rest}), loc)

      | L.EError => raise Fail ("explifyExp: EError at " ^ EM.spanToString loc)

fun explifySgi (sgi, loc) =
    case sgi of
        L.SgiConAbs (x, n, k) => (L'.SgiConAbs (x, n, explifyKind k), loc)
      | L.SgiCon (x, n, k, c) => (L'.SgiCon (x, n, explifyKind k, explifyCon c), loc)
      | L.SgiVal (x, n, c) => (L'.SgiVal (x, n, explifyCon c), loc)
      | L.SgiStr (x, n, sgn) => (L'.SgiStr (x, n, explifySgn sgn), loc)

and explifySgn (sgn, loc) =
    case sgn of
        L.SgnConst sgis => (L'.SgnConst (map explifySgi sgis), loc)
      | L.SgnVar n => (L'.SgnVar n, loc)
      | L.SgnFun _ => raise Fail "Explify functor signature"
      | L.SgnWhere _ => raise Fail "Explify where"
      | L.SgnError => raise Fail ("explifySgn: SgnError at " ^ EM.spanToString loc)

fun explifyDecl (d, loc : EM.span) =
    case d of
        L.DCon (x, n, k, c) => (L'.DCon (x, n, explifyKind k, explifyCon c), loc)
      | L.DVal (x, n, t, e) => (L'.DVal (x, n, explifyCon t, explifyExp e), loc)

      | L.DSgn (x, n, sgn) => (L'.DSgn (x, n, explifySgn sgn), loc)
      | L.DStr (x, n, sgn, str) => (L'.DStr (x, n, explifySgn sgn, explifyStr str), loc)

and explifyStr (str, loc) =
    case str of
        L.StrConst ds => (L'.StrConst (map explifyDecl ds), loc)
      | L.StrVar n => (L'.StrVar n, loc)
      | L.StrProj (str, s) => (L'.StrProj (explifyStr str, s), loc)
      | L.StrFun _ => raise Fail "Explify functor"
      | L.StrApp _ => raise Fail "Explify functor app"
      | L.StrError => raise Fail ("explifyStr: StrError at " ^ EM.spanToString loc)

val explify = map explifyDecl

end
