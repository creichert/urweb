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

(* Laconic/Web main compiler interface *)

signature COMPILER = sig

    val compile : string -> unit

    val parse : string -> Source.file option
    val elaborate : ElabEnv.env -> string -> (Elab.file * ElabEnv.env) option
    val explify : ElabEnv.env -> string -> Expl.file option
    val corify : ElabEnv.env -> string -> Core.file option
    val shake' : ElabEnv.env  -> string -> Core.file option
    val reduce : ElabEnv.env -> string -> Core.file option
    val shake : ElabEnv.env  -> string -> Core.file option
    val monoize : ElabEnv.env -> CoreEnv.env -> string -> Mono.file option
    val cloconv : ElabEnv.env -> CoreEnv.env -> string -> Flat.file option
    val cjrize : ElabEnv.env -> CoreEnv.env -> string -> Cjr.file option

    val testParse : string -> unit
    val testElaborate : string -> unit
    val testExplify : string -> unit
    val testCorify : string -> unit
    val testShake' : string -> unit
    val testReduce : string -> unit
    val testShake : string -> unit
    val testMonoize : string -> unit
    val testCloconv : string -> unit
    val testCjrize : string -> unit

end
