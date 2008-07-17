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

structure MonoOpt :> MONO_OPT = struct

open Mono
structure U = MonoUtil

fun typ t = t
fun decl d = d

fun attrifyInt n =
    if n < 0 then
        "-" ^ Int64.toString (Int64.~ n)
    else
        Int64.toString n

fun attrifyFloat n =
    if n < 0.0 then
        "-" ^ Real.toString (Real.~ n)
    else
        Real.toString n

val attrifyString = String.translate (fn #"\"" => "&quot;"
                                       | ch => if Char.isPrint ch then
                                                   str ch
                                               else
                                                   "&#" ^ Int.toString (ord ch) ^ ";")

val urlifyInt = attrifyInt
val urlifyFloat = attrifyFloat

fun hexIt ch =
    let
        val s = Int.fmt StringCvt.HEX (ord ch)
    in
        case size s of
            0 => "00"
          | 1 => "0" ^ s
          | _ => s
    end

val urlifyString = String.translate (fn #" " => "+"
                                      | ch => if Char.isAlphaNum ch then
                                                  str ch
                                              else
                                                  "%" ^ hexIt ch)
                   
fun exp e =
    case e of
        EPrim (Prim.String s) =>
        let
            val (_, chs) =
                CharVector.foldl (fn (ch, (lastSpace, chs)) =>
                                     let
                                         val isSpace = Char.isSpace ch
                                     in
                                         if isSpace andalso lastSpace then
                                             (true, chs)
                                         else
                                             (isSpace, ch :: chs)
                                     end)
                                 (false, []) s
        in
            EPrim (Prim.String (String.implode (rev chs)))
        end
                                       
      | EStrcat ((EPrim (Prim.String s1), loc), (EPrim (Prim.String s2), _)) =>
        let
            val s =
                if size s1 > 0 andalso size s2 > 0
                   andalso Char.isSpace (String.sub (s1, size s1 - 1))
                   andalso Char.isSpace (String.sub (s2, 0)) then
                    s1 ^ String.extract (s2, 1, NONE)
                else
                    s1 ^ s2
        in
            EPrim (Prim.String s)
        end

      | EStrcat ((EPrim (Prim.String s1), loc), (EStrcat ((EPrim (Prim.String s2), _), rest), _)) =>
        let
            val s =
                if size s1 > 0 andalso size s2 > 0
                   andalso Char.isSpace (String.sub (s1, size s1 - 1))
                   andalso Char.isSpace (String.sub (s2, 0)) then
                    s1 ^ String.extract (s2, 1, NONE)
                else
                    s1 ^ s2
        in
            EStrcat ((EPrim (Prim.String s), loc), rest)
        end

      | EStrcat ((EStrcat (e1, e2), loc), e3) =>
        optExp (EStrcat (e1, (EStrcat (e2, e3), loc)), loc)

      | EWrite (EStrcat (e1, e2), loc) =>
        ESeq ((optExp (EWrite e1, loc), loc),
              (optExp (EWrite e2, loc), loc))

      | EFfiApp ("Basis", "attrifyInt", [(EPrim (Prim.Int n), _)]) =>
        EPrim (Prim.String (attrifyInt n))
      | EWrite (EFfiApp ("Basis", "attrifyInt", [(EPrim (Prim.Int n), _)]), loc) =>
        EWrite (EPrim (Prim.String (attrifyInt n)), loc)
      | EWrite (EFfiApp ("Basis", "attrifyInt", [e]), _) =>
        EFfiApp ("Basis", "attrifyInt_w", [e])

      | EFfiApp ("Basis", "attrifyFloat", [(EPrim (Prim.Float n), _)]) =>
        EPrim (Prim.String (attrifyFloat n))
      | EWrite (EFfiApp ("Basis", "attrifyFloat", [(EPrim (Prim.Float n), _)]), loc) =>
        EWrite (EPrim (Prim.String (attrifyFloat n)), loc)
      | EWrite (EFfiApp ("Basis", "attrifyFloat", [e]), _) =>
        EFfiApp ("Basis", "attrifyFloat_w", [e])

      | EFfiApp ("Basis", "attrifyString", [(EPrim (Prim.String s), _)]) =>
        EPrim (Prim.String (attrifyString s))
      | EWrite (EFfiApp ("Basis", "attrifyString", [(EPrim (Prim.String s), _)]), loc) =>
        EWrite (EPrim (Prim.String (attrifyString s)), loc)
      | EWrite (EFfiApp ("Basis", "attrifyString", [e]), _) =>
        EFfiApp ("Basis", "attrifyString_w", [e])

      | EFfiApp ("Basis", "urlifyInt", [(EPrim (Prim.Int n), _)]) =>
        EPrim (Prim.String (urlifyInt n))
      | EWrite (EFfiApp ("Basis", "urlifyInt", [(EPrim (Prim.Int n), _)]), loc) =>
        EWrite (EPrim (Prim.String (urlifyInt n)), loc)
      | EWrite (EFfiApp ("Basis", "urlifyInt", [e]), _) =>
        EFfiApp ("Basis", "urlifyInt_w", [e])

      | EFfiApp ("Basis", "urlifyFloat", [(EPrim (Prim.Float n), _)]) =>
        EPrim (Prim.String (urlifyFloat n))
      | EWrite (EFfiApp ("Basis", "urlifyFloat", [(EPrim (Prim.Float n), _)]), loc) =>
        EWrite (EPrim (Prim.String (urlifyFloat n)), loc)
      | EWrite (EFfiApp ("Basis", "urlifyFloat", [e]), _) =>
        EFfiApp ("Basis", "urlifyFloat_w", [e])

      | EFfiApp ("Basis", "urlifyString", [(EPrim (Prim.String s), _)]) =>
        EPrim (Prim.String (urlifyString s))
      | EWrite (EFfiApp ("Basis", "urlifyString", [(EPrim (Prim.String s), _)]), loc) =>
        EWrite (EPrim (Prim.String (urlifyString s)), loc)
      | EWrite (EFfiApp ("Basis", "urlifyString", [e]), _) =>
        EFfiApp ("Basis", "urlifyString_w", [e])

      | _ => e

and optExp e = #1 (U.Exp.map {typ = typ, exp = exp} e)

val optimize = U.File.map {typ = typ, exp = exp, decl = decl}

end