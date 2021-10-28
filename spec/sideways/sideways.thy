(*
 * Copyright 2021, UNSW (ABN 57 195 873 179),
 * and The University of Melbourne (ABN 84 002 705 224).
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *)

theory sideways
imports "Word_Lib.WordSetup"
begin

(* or something *)
type_synonym address = "machine_word"



(*
     cache(s)
     time
     other_state
     regs
*)

(*
  FLUSHABLE
  everything changes it somehow
  it affects everything

  PARTITIONABLE
  address \<Rightarrow> time

  the cache touch fn, given some 'a'


cache impact fn
inputs:
  - address
  - fch
  - pch
outputs:
  - new fch
  - new pch
  - time taken


*)


typedecl fch_cachedness
typedecl pch_cachedness
type_synonym fch = "address \<Rightarrow> fch_cachedness"
type_synonym pch = "address \<Rightarrow> pch_cachedness"

type_synonym time = nat

typedecl regs
typedecl other_state


record state =
  fch :: fch
  pch :: pch
  tm :: time
  regs :: regs
  other_state :: other_state




type_synonym cache_impact = "address \<Rightarrow> fch \<Rightarrow> pch \<Rightarrow> fch \<times> pch"

axiomatization collision_set :: "address \<Rightarrow> address set"

axiomatization read_impact :: cache_impact
  where pch_partitioned_read: "a2 \<notin> collision_set a1 \<Longrightarrow> p a2 = snd (read_impact a1 f p) a2"

axiomatization write_impact :: cache_impact
  where pch_partitioned_write: "a2 \<notin> collision_set a1 \<Longrightarrow> p a2 = snd (write_impact a1 f p) a2"

axiomatization read_time  :: "fch_cachedness \<Rightarrow> pch_cachedness \<Rightarrow> time"
axiomatization write_time :: "fch_cachedness \<Rightarrow> pch_cachedness \<Rightarrow> time"

axiomatization do_read :: "address \<Rightarrow> other_state \<Rightarrow> regs \<Rightarrow> regs"

(*
  read process:
  - time step from read_time
  - impact using read_impact
*)

(* now we make some basic isntructions, which contain addresses etc *)
datatype instr = IRead address
               | IWrite address
               | IRegs
               | IFlushL1
               | IFlushL2 "address set"
               | IReadTime
               | IPadToTime time


definition
  instr_step :: "instr \<Rightarrow> state \<Rightarrow> state" where
 "instr_step i s \<equiv> case i of
    IRead a \<Rightarrow> let (f2, p2) = read_impact a (fch s) (pch s) in
      s\<lparr>fch := f2,
        pch := p2,
        tm  := tm s + read_time (fch s a) (pch s a),
        regs := do_read a (other_state s) (regs s)\<rparr>"



type_synonym program = "instr list"

definition
  instrs_obeying_ta :: "address set \<Rightarrow> instr set" where
 "instrs_obeying_ta ta \<equiv> {i. case i of
                            IRead a  \<Rightarrow> a \<in> ta
                          | IWrite a \<Rightarrow> a \<in> ta
                          | _        \<Rightarrow> True }"

(* these are the programs that could have created this ta *)
definition
  programs_obeying_ta :: "address set \<Rightarrow> program set" where
 "programs_obeying_ta ta \<equiv> {p. list_all (\<lambda>i. i \<in> instrs_obeying_ta ta) p}"









end