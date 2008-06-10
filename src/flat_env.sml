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

structure FlatEnv :> FLAT_ENV = struct

open Flat

structure IM = IntBinaryMap


exception UnboundRel of int
exception UnboundNamed of int
exception UnboundF of int

type env = {
     namedT : (string * typ option) IM.map,

     relE : (string * typ) list,
     namedE : (string * typ) IM.map,

     F : (string * typ * typ) IM.map
}

val empty = {
    namedT = IM.empty,

    relE = [],
    namedE = IM.empty,

    F = IM.empty
}

fun pushTNamed (env : env) x n co =
    {namedT = IM.insert (#namedT env, n, (x, co)),

     relE = #relE env,
     namedE = #namedE env,

     F = #F env}

fun lookupTNamed (env : env) n =
    case IM.find (#namedT env, n) of
        NONE => raise UnboundNamed n
      | SOME x => x

fun pushERel (env : env) x t =
    {namedT = #namedT env,

     relE = (x, t) :: #relE env,
     namedE = #namedE env,

     F = #F env}

fun lookupERel (env : env) n =
    (List.nth (#relE env, n))
    handle Subscript => raise UnboundRel n

fun listERels (env : env) = #relE env

fun pushENamed (env : env) x n t =
    {namedT = #namedT env,

     relE = #relE env,
     namedE = IM.insert (#namedE env, n, (x, t)),

     F = #F env}

fun lookupENamed (env : env) n =
    case IM.find (#namedE env, n) of
        NONE => raise UnboundNamed n
      | SOME x => x

fun pushF (env : env) n x dom ran =
    {namedT = #namedT env,

     relE = #relE env,
     namedE = #namedE env,

     F = IM.insert (#F env, n, (x, dom, ran))}

fun lookupF (env : env) n =
    case IM.find (#F env, n) of
        NONE => raise UnboundF n
      | SOME x => x

fun declBinds env (d, _) =
    case d of
        DVal (x, n, t, _) => pushENamed env x n t
      | DFun (n, x, dom, ran, _) => pushF env n x dom ran

fun bbind env x =
    case ElabEnv.lookupC ElabEnv.basis x of
        ElabEnv.NotBound => raise Fail "FlatEnv.bbind: Not bound"
      | ElabEnv.Rel _ => raise Fail "FlatEnv.bbind: Rel"
      | ElabEnv.Named (n, _) => pushTNamed env x n NONE

val basis = empty
val basis = bbind basis "int"
val basis = bbind basis "float"
val basis = bbind basis "string"

end
