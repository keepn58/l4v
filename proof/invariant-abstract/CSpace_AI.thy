(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

(*
CSpace refinement
*)

theory CSpace_AI
imports CSpaceInv_AI
begin

definition
  capBadge_ordering :: "bool \<Rightarrow> (badge option \<times> badge option) set"
where
 "capBadge_ordering firstBadged \<equiv>
    (if firstBadged then {(None, None)} else Id) \<union> ({None, Some 0} \<times> range Some)"


lemma capBadge_ordefield_simps[simp]:
  "(None, y) \<in> capBadge_ordering fb"
  "((y, None) \<in> capBadge_ordering fb) = (y = None)"
  "((y, y) \<in> capBadge_ordering fb) = (fb \<longrightarrow> (y = None \<or> y = Some 0))"
  "((Some x, Some z) \<in> capBadge_ordering fb) = (x = 0 \<or> (\<not> fb \<and> x = z))"
  "(y, Some 0) \<in> capBadge_ordering fb = (y = None \<or> y = Some 0)"
  by (simp add: capBadge_ordering_def disj_ac
           | simp add: eq_commute image_def
           | fastforce)+


lemma capBadge_ordering_trans:
  "\<lbrakk> (x, y) \<in> capBadge_ordering v; (y, z) \<in> capBadge_ordering v2 \<rbrakk>
       \<Longrightarrow> (x, z) \<in> capBadge_ordering v2"
  by (auto simp: capBadge_ordering_def split: split_if_asm)

definition "irq_state_independent_A (P :: 'z state \<Rightarrow> bool) \<equiv>
  \<forall>(f :: nat \<Rightarrow> nat) (s :: 'z state). P s \<longrightarrow> P (s\<lparr>machine_state := machine_state s
                  \<lparr>irq_state := f (irq_state (machine_state s))\<rparr>\<rparr>)"

lemma irq_state_independent_AI[intro!, simp]:
  "\<lbrakk>\<And>s f. P (s\<lparr>machine_state := machine_state s
              \<lparr>irq_state := f (irq_state (machine_state s))\<rparr>\<rparr>) = P s\<rbrakk>
   \<Longrightarrow> irq_state_independent_A P"
  by (simp add: irq_state_independent_A_def)

  (* FIXME: Move. *)
lemma irq_state_independent_A_conjI[intro!]:
  "\<lbrakk>irq_state_independent_A P; irq_state_independent_A Q\<rbrakk> 
   \<Longrightarrow> irq_state_independent_A (P and Q)"
  "\<lbrakk>irq_state_independent_A P; irq_state_independent_A Q\<rbrakk> 
   \<Longrightarrow> irq_state_independent_A (\<lambda>s. P s \<and> Q s)"
  by (auto simp: irq_state_independent_A_def)

(* FIXME: move *)
lemma select_modify_comm:
  "(do b \<leftarrow> select S; _ \<leftarrow> modify f; use b od) =
   (do _ \<leftarrow> modify f; b \<leftarrow> select S; use b od)"
  by (simp add: bind_def split_def select_def simpler_modify_def image_def)

(* FIXME: move *)
lemma select_f_modify_comm:
  "(do b \<leftarrow> select_f S; _ \<leftarrow> modify f; use b od) =
   (do _ \<leftarrow> modify f; b \<leftarrow> select_f S; use b od)"
  by (simp add: bind_def split_def select_f_def simpler_modify_def image_def)

(* FIXME: move *)
lemma gets_machine_state_modify:
  "do x \<leftarrow> gets machine_state;
       u \<leftarrow> modify (machine_state_update (\<lambda>y. x));
       f x
   od =
   gets machine_state >>= f"
  by (simp add: bind_def split_def simpler_gets_def simpler_modify_def)

(* FIXME: move? *)
lemma getActiveIRQ_wp[wp]:
  "irq_state_independent_A P \<Longrightarrow>
   valid P (do_machine_op getActiveIRQ) (\<lambda>_. P)"
  apply (simp add: getActiveIRQ_def do_machine_op_def split_def exec_gets
                   select_f_select[simplified liftM_def]
                   select_modify_comm gets_machine_state_modify)
  apply wp
  apply (clarsimp simp: irq_state_independent_A_def in_monad return_def split: if_splits)
  done

lemma OR_choiceE_weak_wp:
  "\<lbrace>P\<rbrace> f \<sqinter> g \<lbrace>Q\<rbrace> \<Longrightarrow> \<lbrace>P\<rbrace> OR_choiceE b f g \<lbrace>Q\<rbrace>"
  apply (fastforce simp add: OR_choiceE_def alternative_def valid_def bind_def
                    select_f_def gets_def return_def get_def liftE_def lift_def bindE_def
          split: option.splits split_if_asm)
  done

lemma preemption_point_inv:
  "\<lbrakk>irq_state_independent_A P; \<And>f s. P (trans_state f s) = P s\<rbrakk> \<Longrightarrow> \<lbrace>P\<rbrace> preemption_point \<lbrace>\<lambda>_. P\<rbrace>"
  apply (intro impI conjI | simp add: preemption_point_def o_def
       | wp hoare_post_imp[OF _ getActiveIRQ_wp] OR_choiceE_weak_wp alternative_wp[where P=P]
       | wpc)+
  done 

lemma valid_cap_machine_state [iff]:
  "machine_state_update f s \<turnstile> c = s \<turnstile> c"
  by (fastforce intro: valid_cap_pspaceI)

lemma get_cap_valid [wp]:
  "\<lbrace> valid_objs \<rbrace> get_cap addr \<lbrace> valid_cap \<rbrace>"
  apply (wp get_cap_wp)
  apply (auto dest: cte_wp_at_valid_objs_valid_cap)
  done

lemma get_cap_wellformed:
  "\<lbrace>valid_objs\<rbrace> get_cap slot \<lbrace>\<lambda>cap s. wellformed_cap cap\<rbrace>"
  apply (rule hoare_strengthen_post, rule get_cap_valid)
  apply (simp add: valid_cap_def2)
  done

lemma update_cdt_cdt:
  "\<lbrace>\<lambda>s. valid_mdb (cdt_update (\<lambda>_. (m (cdt s))) s)\<rbrace> update_cdt m \<lbrace>\<lambda>_. valid_mdb\<rbrace>"
  by (simp add: update_cdt_def set_cdt_def) wp

(* FIXME: rename *)
lemma unpleasant_helper:
  "(\<forall>a b. (\<exists>c. a = f c \<and> b = g c \<and> P c) \<longrightarrow> Q a b) = (\<forall>c. P c \<longrightarrow> Q (f c) (g c))"
  by blast


lemma get_object_det:
  "(r,s') \<in> fst (get_object p s) \<Longrightarrow> get_object p s = ({(r,s)}, False)"
  by (auto simp: in_monad get_object_def bind_def gets_def get_def return_def)


lemma get_object_at_obj:
  "\<lbrakk> (r,s') \<in> fst (get_object p s); P r \<rbrakk> \<Longrightarrow> obj_at P p s"
  by (auto simp: get_object_def obj_at_def in_monad)


lemma get_cap_cte_at:
  "(r,s') \<in> fst (get_cap p s) \<Longrightarrow> cte_at p s"
  unfolding cte_at_def by (auto dest: get_cap_det)


lemma rab_cte_cap_to':
  "s \<turnstile> \<lbrace>\<lambda>s. (is_cnode_cap (fst args) \<longrightarrow> (\<forall>r\<in>cte_refs (fst args) (interrupt_irq_node s). ex_cte_cap_wp_to P r s))
               \<and> (\<forall>cap. is_cnode_cap cap \<longrightarrow> P cap)\<rbrace>
    resolve_address_bits args
   \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P (fst rv)\<rbrace>,\<lbrace>\<top>\<top>\<rbrace>"
unfolding resolve_address_bits_def
proof (induct args arbitrary: s rule: resolve_address_bits'.induct)
  case (1 z cap cref s')
  have P:
    "\<And>P' Q args adm s.
      \<lbrakk> s \<turnstile> \<lbrace>P'\<rbrace> resolve_address_bits' z args \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P (fst rv)\<rbrace>,\<lbrace>\<top>\<top>\<rbrace>;
        \<And>rv s. ex_cte_cap_wp_to P (fst rv) s \<Longrightarrow> Q rv s \<rbrakk> \<Longrightarrow>
        s \<turnstile> \<lbrace>P'\<rbrace> resolve_address_bits' z args \<lbrace>Q\<rbrace>,\<lbrace>\<top>\<top>\<rbrace>"
    unfolding spec_validE_def
    apply (fold validE_R_def)
    apply (erule hoare_post_imp_R)
    apply simp
    done
  show ?case
    apply (subst resolve_address_bits'.simps)
    apply (cases cap, simp_all split del: split_if)
            defer 6 (* CNode *)
            apply wp[11]
    apply (simp add: split_def cong: if_cong split del: split_if)
    apply (rule hoare_pre_spec_validE)
     apply (wp P [OF "1.hyps"], (simp add: in_monad | rule conjI refl)+)
          apply (wp | simp | rule get_cap_wp)+ 
    apply (fastforce simp: ex_cte_cap_wp_to_def elim!: cte_wp_at_weakenE)
    done
qed


lemmas rab_cte_cap_to = use_spec(2) [OF rab_cte_cap_to']


lemma resolve_address_bits_real_cte_at:
  "\<lbrace> valid_objs and valid_cap (fst args) \<rbrace>
  resolve_address_bits args 
  \<lbrace>\<lambda>rv. real_cte_at (fst rv)\<rbrace>, -"
unfolding resolve_address_bits_def
proof (induct args rule: resolve_address_bits'.induct)
  case (1 z cap cref)
  show ?case
    apply (clarsimp simp add: validE_R_def validE_def valid_def split: sum.split)
    apply (subst (asm) resolve_address_bits'.simps)
    apply (cases cap)
              defer 6 (* cnode *)
          apply (auto simp: in_monad)[11]
    apply (rename_tac obj_ref nat list)
    apply (simp only: cap.simps)
    apply (case_tac "nat + length list = 0")
     apply (simp add: fail_def)
    apply (simp only: if_False)
    apply (simp only: K_bind_def in_bindE_R)
    apply (elim conjE exE)
    apply (simp only: split: split_if_asm)
     apply (clarsimp simp add: in_monad)
     apply (clarsimp simp add: valid_cap_def)
    apply (simp only: K_bind_def in_bindE_R)
    apply (elim conjE exE)
    apply (simp only: split: split_if_asm)
     apply (frule (8) "1.hyps")
     apply (clarsimp simp: in_monad validE_def validE_R_def valid_def)
     apply (frule in_inv_by_hoareD [OF get_cap_inv])
     apply simp
     apply (frule (1) post_by_hoare [OF get_cap_valid])
     apply (erule allE, erule impE, blast)
     apply (clarsimp simp: in_monad split: cap.splits)
     apply (drule (1) bspec, simp)+
    apply (clarsimp simp: in_monad)
    apply (frule in_inv_by_hoareD [OF get_cap_inv])
    apply (clarsimp simp add: valid_cap_def)
    done
qed


lemma resolve_address_bits_cte_at:
  "\<lbrace> valid_objs and valid_cap (fst args) \<rbrace> 
  resolve_address_bits args
  \<lbrace>\<lambda>rv. cte_at (fst rv)\<rbrace>, -"
  apply (rule hoare_post_imp_R, rule resolve_address_bits_real_cte_at)
  apply (erule real_cte_at_cte)
  done


lemma lookup_slot_real_cte_at_wp [wp]: 
  "\<lbrace> valid_objs \<rbrace> lookup_slot_for_thread t addr \<lbrace>\<lambda>rv. real_cte_at (fst rv)\<rbrace>,-"
  apply (simp add: lookup_slot_for_thread_def)
  apply wp
   apply (rule resolve_address_bits_real_cte_at)
  apply simp
  apply wp
  apply clarsimp
  apply (erule(1) objs_valid_tcb_ctable)
  done

lemma lookup_slot_cte_at_wp[wp]: 
  "\<lbrace> valid_objs \<rbrace> lookup_slot_for_thread t addr \<lbrace>\<lambda>rv. cte_at (fst rv)\<rbrace>,-"
  by (rule hoare_post_imp_R, wp, erule real_cte_at_cte)

lemma get_cap_success:
  fixes s cap ptr offset
  defines "s' \<equiv> s\<lparr>kheap := [ptr \<mapsto> CNode (length offset) (\<lambda>x. if length x = length offset then Some cap else None)]\<rparr>"
  shows "(cap, s') \<in> fst (get_cap (ptr, offset) s')"
  by (simp add: get_cap_def get_object_def 
                in_monad s'_def well_formed_cnode_n_def length_set_helper dom_def
           split: Structures_A.kernel_object.splits)



lemma len_drop_lemma:
  assumes drop: "drop (n - length ys) xs = ys"
  assumes l: "n = length xs" 
  shows "length ys \<le> n"
proof -
  from drop 
  have "length (drop (n - length ys) xs) = length ys"
    by simp
  with l
  have "length ys = n - (n - length ys)" 
    by simp
  thus ?thesis by arith
qed


lemma drop_postfixD:
  "(drop (length xs - length ys) xs = ys) \<Longrightarrow> (\<exists>zs. xs = zs @ ys)"
proof (induct xs arbitrary: ys)
  case Nil thus ?case by simp
next
  case (Cons x xs)
  from Cons.prems
  have "length ys \<le> length (x # xs)" 
    by (rule len_drop_lemma) simp
  moreover
  { assume "length ys = length (x # xs)"
    with Cons.prems
    have ?case by simp
  }
  moreover {
    assume "length ys < length (x # xs)"
    hence "length ys \<le> length xs" by simp
    hence "drop (length xs - length ys) xs = 
           drop (length (x # xs) - length ys) (x # xs)"
      by (simp add: Suc_diff_le)
    with Cons.prems
    have ?case by (auto dest: Cons.hyps)
  }
  ultimately
  show ?case by (auto simp: order_le_less) 
qed


lemma drop_postfix_eq:
  "n = length xs \<Longrightarrow> (drop (n - length ys) xs = ys) = (\<exists>zs. xs = zs @ ys)"
  by (auto dest: drop_postfixD)


lemma postfix_dropD:
  "xs = zs @ ys \<Longrightarrow> drop (length xs - length ys) xs = ys"
  by simp


lemmas is_cap_defs = is_arch_cap_def is_zombie_def


lemma guard_mask_shift:
  fixes cref' :: word32
  assumes postfix: "to_bl cref' = xs @ cref" 
  shows
  "(length guard \<le> length cref \<and> 
    (cref' >> length cref - length guard) && mask (length guard) = of_bl guard)
  =
  (guard \<le> cref)" (is "(_ \<and> ?l = ?r) = _ " is "(?len \<and> ?shift) = ?prefix") 
proof
  from postfix
  have "length (to_bl cref') = length xs + length cref" by simp
  hence 32: "32 = \<dots>" by simp
  
  assume "?len \<and> ?shift"
  hence shift: ?shift and c_len: ?len by auto

  from 32 c_len have "length guard \<le> 32" by simp
  with shift
  have "(replicate (32 - length guard) False) @ guard = to_bl ?l" 
    by (simp add: word_rep_drop)
  also
  have "\<dots> = replicate (32 - length guard) False @ 
        drop (32 - length guard) (to_bl (cref' >> length cref - length guard))"
    by (simp add: bl_and_mask)
  also 
  from c_len
  have "\<dots> = replicate (32 - length guard) False @ take (length guard) cref"
    by (simp add: bl_shiftr 32 word_size postfix)
  finally
  have "take (length guard) cref = guard" by simp
  thus ?prefix by (simp add: take_prefix)
next
  assume ?prefix
  then obtain zs where cref: "cref = guard @ zs" 
    by (auto simp: prefixeq_def less_eq_list_def)
  with postfix
  have to_bl_c: "to_bl cref' = xs @ guard @ zs" by simp
  hence "length (to_bl cref') = length \<dots>" by simp
  hence 32: "32 = \<dots>" by simp

  from cref have c_len: "length guard \<le> length cref" by simp

  from cref
  have "length cref - length guard = length zs" by simp
  hence "to_bl ?l = replicate (32-length guard) False @ 
                   drop (32-length guard) (to_bl (cref' >> length zs))"
    by (simp add: bl_and_mask)
  also 
  have "drop (32-length guard) (to_bl (cref' >> length zs)) = guard"
    by (simp add: bl_shiftr word_size 32 to_bl_c)
  finally
  have "to_bl ?l = to_bl ?r"
    by (simp add: word_rep_drop 32)
  with c_len
  show "?len \<and> ?shift" by simp
qed


lemma of_bl_take:
  "length xs < len_of TYPE('a) \<Longrightarrow> of_bl (take n xs) = ((of_bl xs) >> (length xs - n) :: ('a :: len) word)"
  apply (clarsimp simp: bang_eq and_bang test_bit_of_bl
                        rev_take conj_comms nth_shiftr)
  apply safe
        apply simp_all
   apply (clarsimp elim!: rsubst[where P="\<lambda>x. rev xs ! x"])+
  done


lemma gets_the_tcb_get_cap:
  "tcb_at t s \<Longrightarrow> liftM tcb_ctable (gets_the (get_tcb t)) s = get_cap (t, tcb_cnode_index 0) s"
  apply (clarsimp simp add: tcb_at_def liftM_def bind_def assert_opt_def
                            gets_the_def simpler_gets_def return_def)
  apply (clarsimp    dest!: get_tcb_SomeD
                  simp add: get_cap_def tcb_cnode_map_def
                            get_object_def bind_def simpler_gets_def
                            return_def assert_def fail_def assert_opt_def)
  done

lemma upd_other_cte_wp_at:
  "\<lbrakk> cte_wp_at P p s; fst p \<noteq> ptr \<rbrakk> \<Longrightarrow> 
  cte_wp_at P p (kheap_update (\<lambda>ps. (kheap s)(ptr \<mapsto> ko)) s)"
  by (auto elim!: cte_wp_atE intro: cte_wp_at_cteI cte_wp_at_tcbI)

lemma get_cap_cte_wp_at:
  "\<lbrace>\<top>\<rbrace> get_cap p \<lbrace>\<lambda>rv. cte_wp_at (\<lambda>c. c = rv) p\<rbrace>"
  apply (wp get_cap_wp)
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done


lemma wf_cs_nD:
  "\<lbrakk> f x = Some y; well_formed_cnode_n n f \<rbrakk> \<Longrightarrow> length x = n"
  unfolding well_formed_cnode_n_def by blast
 

lemma set_cdt_valid_pspace:
  "\<lbrace>valid_pspace\<rbrace> set_cdt m \<lbrace>\<lambda>_. valid_pspace\<rbrace>"
  unfolding set_cdt_def
  apply simp
  apply wp
  apply (erule valid_pspace_eqI)
  apply clarsimp
  done

lemma cte_at_pspace:
  "cte_wp_at P p s \<Longrightarrow> \<exists>ko. kheap s (fst p) = Some ko"
  by (auto simp: cte_wp_at_cases)

lemma tcb_cap_cases_length:
  "x \<in> dom tcb_cap_cases \<Longrightarrow> length x = 3"
  by (auto simp add: tcb_cap_cases_def tcb_cnode_index_def to_bl_1)

lemma cte_at_length_limit:
  "\<lbrakk> cte_at p s; valid_objs s \<rbrakk> \<Longrightarrow> length (snd p) < word_bits - cte_level_bits"
  apply (simp add: cte_at_cases)
  apply (erule disjE)
   apply clarsimp
   apply (erule(1) valid_objsE)
   apply (clarsimp simp: valid_obj_def well_formed_cnode_n_def valid_cs_def valid_cs_size_def
                         length_set_helper)
   apply (drule arg_cong[where f="\<lambda>S. snd p \<in> S"])
   apply (simp add: domI)
  apply (clarsimp simp add: tcb_cap_cases_length word_bits_conv cte_level_bits_def)
  done


lemma cte_at_cref_len:
  "\<lbrakk>cte_at (p, c) s; cte_at (p, c') s\<rbrakk> \<Longrightarrow> length c = length c'"
  apply (clarsimp simp: cte_at_cases)
  apply (erule disjE)
   prefer 2
   apply (clarsimp simp: tcb_cap_cases_length)
  apply clarsimp
  apply (drule (1) wf_cs_nD)
  apply (drule (1) wf_cs_nD)
  apply simp
  done


lemma well_formed_cnode_invsI:
  "\<lbrakk> valid_objs s; kheap s x = Some (CNode sz cs) \<rbrakk>
      \<Longrightarrow> well_formed_cnode_n sz cs"
  apply (erule(1) valid_objsE)
  apply (clarsimp simp: well_formed_cnode_n_def valid_obj_def valid_cs_def valid_cs_size_def
                        length_set_helper)
  done


lemma set_cap_def2:
  "set_cap cap = (\<lambda>(oref, cref). do
     obj \<leftarrow> get_object oref;
     obj' \<leftarrow> (case (obj, tcb_cap_cases cref) of
     (CNode sz cs, _) \<Rightarrow> if cref \<in> dom cs \<and> well_formed_cnode_n sz cs
         then return $ CNode sz $ cs(cref \<mapsto> cap)
         else fail
   | (TCB tcb, Some (getF, setF, restr)) \<Rightarrow> return $ TCB (setF (\<lambda>x. cap) tcb)
   | _ \<Rightarrow> fail);
     set_object oref obj'
   od)"
  apply (rule ext, simp add: set_cap_def split_def)
  apply (intro bind_cong bind_apply_cong refl)
  apply (simp split: Structures_A.kernel_object.split)
  apply (simp add: tcb_cap_cases_def)
  done


lemma set_cap_cte_eq:
  "(x,t) \<in> fst (set_cap c p' s) \<Longrightarrow> 
  cte_at p' s \<and> cte_wp_at P p t = (if p = p' then P c else cte_wp_at P p s)"
  apply (cases p)
  apply (cases p')
  apply (auto simp: set_cap_def2 split_def in_monad cte_wp_at_cases 
                    get_object_def set_object_def wf_cs_upd
             split: Structures_A.kernel_object.splits split_if_asm
                    option.splits,
         auto simp: tcb_cap_cases_def split: split_if_asm)
  done


lemma descendants_of_cte_at:
  "\<lbrakk> p \<in> descendants_of x (cdt s); valid_mdb s \<rbrakk> 
  \<Longrightarrow> cte_at p s"
  apply (simp add: descendants_of_def)
  apply (drule tranclD2)
  apply (clarsimp simp: cdt_parent_defs valid_mdb_def mdb_cte_at_def
                  simp del: split_paired_All)
  apply (fastforce elim: cte_wp_at_weakenE)
  done


lemma descendants_of_cte_at2:
  "\<lbrakk> p \<in> descendants_of x (cdt s); valid_mdb s \<rbrakk> 
  \<Longrightarrow> cte_at x s"
  apply (simp add: descendants_of_def)
  apply (drule tranclD)
  apply (clarsimp simp: cdt_parent_defs valid_mdb_def mdb_cte_at_def
                  simp del: split_paired_All)
  apply (fastforce elim: cte_wp_at_weakenE)
  done


lemma in_set_cap_cte_at:
  "(x, s') \<in> fst (set_cap c p' s) \<Longrightarrow> cte_at p s' = cte_at p s"
  by (fastforce simp: cte_at_cases set_cap_def split_def wf_cs_upd
                     in_monad get_object_def set_object_def
               split: Structures_A.kernel_object.splits split_if_asm)


lemma in_set_cap_cte_at_swp:
  "(x, s') \<in> fst (set_cap c p' s) \<Longrightarrow> swp cte_at s' = swp cte_at s"
  by (simp add: swp_def in_set_cap_cte_at)


(* FIXME: move *)
lemma take_to_bl_len:
  fixes a :: "'a::len word"
  fixes b :: "'a::len word"
  assumes t: "take x (to_bl a) = take y (to_bl b)"
  assumes x: "x \<le> size a" 
  assumes y: "y \<le> size b"
  shows "x = y"
proof -
  from t 
  have "length (take x (to_bl a)) = length (take y (to_bl b))"
    by simp
  also 
  from x have "length (take x (to_bl a)) = x"
    by (simp add: word_size)
  also
  from y have "length (take y (to_bl b)) = y"
    by (simp add: word_size)
  finally
  show ?thesis .
qed

definition
  final_matters :: "cap \<Rightarrow> bool"
where
 "final_matters cap \<equiv> case cap of
    Structures_A.NullCap \<Rightarrow> False
  | Structures_A.UntypedCap p b f \<Rightarrow> False
  | Structures_A.EndpointCap r badge rights \<Rightarrow> True
  | Structures_A.AsyncEndpointCap r badge rights \<Rightarrow> True
  | Structures_A.CNodeCap r bits guard \<Rightarrow> True
  | Structures_A.ThreadCap r \<Rightarrow> True
  | Structures_A.DomainCap \<Rightarrow> False
  | Structures_A.ReplyCap r master \<Rightarrow> False
  | Structures_A.IRQControlCap \<Rightarrow> False
  | Structures_A.IRQHandlerCap irq \<Rightarrow> True
  | Structures_A.Zombie r b n \<Rightarrow> True
  | Structures_A.ArchObjectCap ac \<Rightarrow> (case ac of
    ARM_Structs_A.ASIDPoolCap r as \<Rightarrow> True
  | ARM_Structs_A.ASIDControlCap \<Rightarrow> False
  | ARM_Structs_A.PageCap r rghts sz mapdata \<Rightarrow> False
  | ARM_Structs_A.PageTableCap r mapdata \<Rightarrow> True
  | ARM_Structs_A.PageDirectoryCap r mapdata \<Rightarrow> True)"


lemmas final_matters_simps[simp]
    = final_matters_def[split_simps cap.split arch_cap.split]


lemma cte_wp_at_eqD:
  "cte_wp_at P p s \<Longrightarrow> \<exists>c. cte_wp_at (op = c) p s \<and> P c"
  by (auto simp add: cte_wp_at_cases)


lemma no_True_set_nth:
  "(True \<notin> set xs) = (\<forall>n < length xs. xs ! n = False)"
  apply (induct xs)
   apply simp
  apply (case_tac a, simp_all)
   apply (rule_tac x=0 in exI)
   apply simp
  apply safe
    apply (case_tac n, simp_all)[1]
   apply (case_tac na, simp_all)[1]
  apply (erule_tac x="Suc n" in allE)
  apply clarsimp
  done


lemma map2_append1:
  "map2 f (as @ bs) cs = map2 f as (take (length as) cs) @ map2 f bs (drop (length as) cs)"
  by (simp add: map2_def zip_append1)


lemma set_cap_caps_of_state_monad:
  "(v, s') \<in> fst (set_cap cap p s) \<Longrightarrow> caps_of_state s' = (caps_of_state s (p \<mapsto> cap))"
  apply (drule use_valid)
    apply (rule set_cap_caps_of_state [where P="op = (caps_of_state s (p\<mapsto>cap))"])
   apply (rule refl)
  apply simp
  done


definition
  "revokable src_cap new_cap \<equiv>
   if is_ep_cap new_cap then cap_ep_badge new_cap \<noteq> cap_ep_badge src_cap
   else if is_aep_cap new_cap then cap_ep_badge new_cap \<noteq> cap_ep_badge src_cap 
   else if \<exists>irq. new_cap = cap.IRQHandlerCap irq then src_cap = cap.IRQControlCap
   else is_untyped_cap new_cap"


lemma descendants_of_empty:
  "(descendants_of d m = {}) = (\<forall>c. \<not>m \<turnstile> d cdt_parent_of c)"
  apply (simp add: descendants_of_def)
  apply (rule iffI)
   apply clarsimp
   apply (erule allE, erule allE)
   apply (erule notE)
   apply fastforce
  apply clarsimp
  apply (drule tranclD)
  apply clarsimp
  done

  

lemma descendants_of_None:
  "(\<forall>c. d \<notin> descendants_of c m) = (m d = None)"
  apply (simp add: descendants_of_def cdt_parent_defs)
  apply (rule iffI)
   prefer 2
   apply clarsimp
   apply (drule tranclD2)
   apply clarsimp
  apply (erule contrapos_pp)
  apply fastforce
  done  


lemma not_should_be_parent_Null [simp]:
  "should_be_parent_of cap.NullCap a b c = False"
  by (simp add: should_be_parent_of_def)


lemma mdb_None_no_parent:
  "m p = None \<Longrightarrow> m \<Turnstile> c \<leadsto> p = False"
  by (clarsimp simp: cdt_parent_defs)


lemma descendants_of_self:
  assumes "descendants_of dest m = {}"
  shows "descendants_of x (m(dest \<mapsto> dest)) = 
   (if x = dest then {dest} else descendants_of x m - {dest})" using assms
  apply (clarsimp simp: descendants_of_def cdt_parent_defs)
  apply (rule conjI)
   apply clarsimp
   apply (fastforce split: split_if_asm elim: trancl_into_trancl trancl_induct)
  apply clarsimp
  apply (rule set_eqI)
  apply clarsimp
  apply (rule iffI)
   apply (erule trancl_induct)
    apply fastforce
   apply clarsimp
   apply (erule trancl_into_trancl)
   apply clarsimp
  apply clarsimp
  apply (rule_tac P="(a,b) \<noteq> dest" in mp)
   prefer 2
   apply assumption
  apply (thin_tac "(a,b) \<noteq> dest")
  apply (erule trancl_induct)
   apply fastforce
  apply (fastforce split: split_if_asm elim: trancl_into_trancl)
  done


lemma descendants_of_self_None:
  assumes "descendants_of dest m = {}"
  assumes n: "m dest = None"
  shows "descendants_of x (m(dest \<mapsto> dest)) = 
   (if x = dest then {dest} else descendants_of x m)" 
  apply (subst descendants_of_self[OF assms(1)])
  apply clarsimp
  apply (subgoal_tac "dest \<notin> descendants_of x m")
   apply simp
  apply (insert n)
  apply (simp add: descendants_of_None [symmetric] del: split_paired_All)
  done


lemma descendants_insert_evil_trancl_induct:
  assumes "src \<noteq> dest"
  assumes d: "descendants_of dest m = {}" 
  assumes "src \<in> descendants_of x m" 
  shows "src \<in> descendants_of x (m (dest \<mapsto> src))"
proof -
  have r: "\<And>t. \<lbrakk> src \<in> descendants_of x m; t = src \<rbrakk> \<Longrightarrow> src \<noteq> dest \<longrightarrow> src \<in> descendants_of x (m (dest \<mapsto> t))"
  unfolding descendants_of_def cdt_parent_defs
  apply (simp (no_asm_use) del: fun_upd_apply)
  apply (erule trancl_induct)
   apply clarsimp
   apply (rule r_into_trancl)
   apply clarsimp
  apply (rule impI)
  apply (erule impE)
   apply (insert d)[1]
   apply (clarsimp simp: descendants_of_def cdt_parent_defs)
   apply fastforce
  apply (simp del: fun_upd_apply)
  apply (erule trancl_into_trancl)
  apply clarsimp
  done

  show ?thesis using assms
    apply -
    apply (rule r [THEN mp])
      apply assumption
     apply (rule refl)
    apply assumption
    done
qed
  

lemma descendants_of_insert_child:
  assumes d: "descendants_of dest m = {}" 
  assumes s: "src \<noteq> dest"
  shows
  "descendants_of x (m (dest \<mapsto> src)) = 
   (if src \<in> descendants_of x m \<or> x = src
    then descendants_of x m \<union> {dest} else descendants_of x m - {dest})"
  using assms
  apply (simp add: descendants_of_def cdt_parent_defs del: fun_upd_apply)
  apply (rule conjI)
   apply clarify
   apply (rule set_eqI)
   apply (simp del: fun_upd_apply)
   apply (rule iffI)
    apply (simp only: disj_imp)
    apply (erule_tac b="xa" in trancl_induct)
     apply fastforce
    apply clarsimp
    apply (erule impE)
     apply fastforce
    apply (rule trancl_into_trancl)
     prefer 2
     apply simp
    apply assumption
   apply (erule disjE) 
    apply (drule descendants_insert_evil_trancl_induct [OF _ d])
     apply (simp add: descendants_of_def cdt_parent_defs)
    apply (simp add: descendants_of_def cdt_parent_defs del: fun_upd_apply)
    apply (erule trancl_into_trancl)
    apply fastforce
   apply (case_tac "xa = dest")
    apply (simp del: fun_upd_apply)
    apply (drule descendants_insert_evil_trancl_induct [OF _ d])
     apply (simp add: descendants_of_def cdt_parent_defs)
    apply (simp add: descendants_of_def cdt_parent_defs del: fun_upd_apply)
    apply (erule trancl_into_trancl)
    apply fastforce
   apply (rule_tac P="xa \<noteq> dest" in mp)
    prefer 2
    apply assumption
   apply (erule_tac b=xa in trancl_induct)
    apply fastforce
   apply (clarsimp simp del: fun_upd_apply)
   apply (erule impE)
    apply fastforce
   apply (fastforce elim: trancl_into_trancl)
  apply (rule conjI)
   apply (clarsimp simp del: fun_upd_apply)
   apply (rule set_eqI)
   apply (simp del: fun_upd_apply)
   apply (rule iffI)
   apply (simp only: disj_imp)
    apply (erule_tac b="xa" in trancl_induct)
     apply fastforce
    apply clarsimp
    apply (erule impE)
     apply fastforce
    apply (rule trancl_into_trancl)
     prefer 2
     apply simp
    apply assumption
   apply (erule disjE)
    apply fastforce
   apply (case_tac "xa = dest")
    apply fastforce
   apply (rule_tac P="xa \<noteq> dest" in mp)
    prefer 2
    apply assumption
   apply (erule_tac b=xa in trancl_induct)
    apply fastforce
   apply (clarsimp simp del: fun_upd_apply)
   apply (erule impE)
    apply fastforce
   apply (fastforce elim: trancl_into_trancl)
  apply clarify
  apply (rule set_eqI)
  apply (simp del: fun_upd_apply)
  apply (rule iffI)
   apply (erule trancl_induct) 
    apply (fastforce split: split_if_asm)
   apply (clarsimp split: split_if_asm)
   apply (fastforce elim: trancl_into_trancl)
  apply (elim conjE)
  apply (rule_tac P="xa \<noteq> dest" in mp)
   prefer 2
   apply assumption
  apply (erule_tac b=xa in trancl_induct)
   apply fastforce
  apply (clarsimp simp del: fun_upd_apply)
  apply (erule impE)
   apply fastforce
  apply (erule trancl_into_trancl)
  apply fastforce
  done


lemma descendants_of_NoneD:
  "\<lbrakk> m p = None; p \<in> descendants_of x m \<rbrakk> \<Longrightarrow> False"
  by (simp add: descendants_of_None [symmetric] del: split_paired_All)


lemma descendants_of_insert_child':
  assumes d: "descendants_of dest m = {}" 
  assumes s: "src \<noteq> dest"
  assumes m: "m dest = None"
  shows
  "descendants_of x (m (dest \<mapsto> src)) = 
   (if src \<in> descendants_of x m \<or> x = src
    then descendants_of x m \<union> {dest} else descendants_of x m)" 
  apply (subst descendants_of_insert_child [OF d s])
  apply clarsimp
  apply (subgoal_tac "dest \<notin> descendants_of x m")
   apply clarsimp
  apply (rule notI)
  apply (rule descendants_of_NoneD, rule m, assumption)
  done


locale vmdb_abs =
  fixes s m cs
  assumes valid_mdb: "valid_mdb s"
  defines "m \<equiv> cdt s"
  defines "cs \<equiv> caps_of_state s"
begin
lemma no_mloop [intro!]: "no_mloop m"
  using valid_mdb by (simp add: valid_mdb_def m_def)


lemma no_loops [simp, intro!]: "\<not>m \<Turnstile> p \<rightarrow> p"
  using no_mloop by (cases p) (simp add: no_mloop_def)


lemma no_mdb_loop [simp, intro!]: "m p \<noteq> Some p"
proof
  assume "m p = Some p"
  hence "m \<Turnstile> p \<leadsto> p" by (simp add: cdt_parent_of_def)
  hence "m \<Turnstile> p \<rightarrow> p" ..
  thus False by simp
qed


lemma untyped_inc:
  "untyped_inc m cs"
  using valid_mdb by (simp add: valid_mdb_def m_def cs_def)


lemma untyped_mdb:
  "untyped_mdb m cs"
  using valid_mdb by (simp add: valid_mdb_def m_def cs_def)


lemma null_no_mdb:
  "cs p = Some cap.NullCap \<Longrightarrow> \<not> m \<Turnstile> p \<rightarrow> p' \<and> \<not> m \<Turnstile> p' \<rightarrow> p"
  using valid_mdb_no_null [OF valid_mdb]
  by (simp add: m_def cs_def)


end


definition
  "cap_vptr cap \<equiv> case cap of 
    Structures_A.ArchObjectCap (ARM_Structs_A.PageCap _ _ _ (Some (_, vptr))) \<Rightarrow> Some vptr
  | Structures_A.ArchObjectCap (ARM_Structs_A.PageTableCap _ (Some (_, vptr))) \<Rightarrow> Some vptr
  | _ \<Rightarrow> None"


lemmas cap_vptr_simps [simp] = 
  cap_vptr_def [split_simps cap.split arch_cap.split option.split prod.split]

definition
  is_derived :: "cdt \<Rightarrow> cslot_ptr \<Rightarrow> cap \<Rightarrow> cap \<Rightarrow> bool"
where
  "is_derived m p cap' cap \<equiv> 
  cap' \<noteq> cap.NullCap \<and>
  \<not> is_zombie cap \<and>
  cap' \<noteq> cap.IRQControlCap \<and>
  (if is_untyped_cap cap 
  then
    cap_master_cap cap = cap_master_cap cap' \<and> descendants_of p m = {}
  else 
    (cap_master_cap cap = cap_master_cap cap') \<and>
    (cap_badge cap, cap_badge cap') \<in> capBadge_ordering False) \<and>
    (is_master_reply_cap cap = is_reply_cap cap') \<and>
    ((is_pt_cap cap \<or> is_pd_cap cap) \<longrightarrow> 
         cap_asid cap = cap_asid cap' \<and> cap_asid cap \<noteq> None) \<and>
    (vs_cap_ref cap = vs_cap_ref cap' \<or> is_pg_cap cap') \<and>
    \<not> is_reply_cap cap \<and> \<not> is_master_reply_cap cap'"


lemma the_arch_cap_ArchObjectCap[simp]:
  "the_arch_cap (cap.ArchObjectCap cap) = cap"
  by (simp add: the_arch_cap_def)


lemma is_page_cap_PageCap[simp]:
  "is_page_cap (arch_cap.PageCap ref rghts pgsiz mapdata)"
  by (simp add: is_page_cap_def)


lemma pageBitsForSize_eq[simp]:
  "(pageBitsForSize sz = pageBitsForSize sz') = (sz = sz')"
by (case_tac sz) (case_tac sz', simp+)+


lemma cap_master_cap_simps:
  "cap_master_cap (cap.EndpointCap ref bdg rghts)      = cap.EndpointCap ref 0 UNIV"
  "cap_master_cap (cap.AsyncEndpointCap ref bdg rghts) = cap.AsyncEndpointCap ref 0 UNIV"
  "cap_master_cap (cap.CNodeCap ref bits gd)           = cap.CNodeCap ref bits []"
  "cap_master_cap (cap.ThreadCap ref)                  = cap.ThreadCap ref"
  "cap_master_cap (cap.ArchObjectCap (arch_cap.PageCap ref rghts sz mapdata)) =
         cap.ArchObjectCap (arch_cap.PageCap ref UNIV sz None)"
  "cap_master_cap (cap.ArchObjectCap (arch_cap.ASIDPoolCap pool asid)) =
         cap.ArchObjectCap (arch_cap.ASIDPoolCap pool 0)"
  "cap_master_cap (cap.ArchObjectCap (arch_cap.PageTableCap ptr x)) =
         cap.ArchObjectCap (arch_cap.PageTableCap ptr None)"
  "cap_master_cap (cap.ArchObjectCap (arch_cap.PageDirectoryCap ptr y)) =
         cap.ArchObjectCap (arch_cap.PageDirectoryCap ptr None)"
  "cap_master_cap (cap.ArchObjectCap arch_cap.ASIDControlCap) =
         cap.ArchObjectCap arch_cap.ASIDControlCap"
  "cap_master_cap (cap.NullCap)           = cap.NullCap"
  "cap_master_cap (cap.DomainCap)         = cap.DomainCap"
  "cap_master_cap (cap.UntypedCap r n f)  = cap.UntypedCap r n 0"
  "cap_master_cap (cap.ReplyCap r m)      = cap.ReplyCap r True"
  "cap_master_cap (cap.IRQControlCap)     = cap.IRQControlCap"
  "cap_master_cap (cap.IRQHandlerCap irq) = cap.IRQHandlerCap irq"
  "cap_master_cap (cap.Zombie r a b)      = cap.Zombie r a b"
  by (simp_all add: cap_master_cap_def)


lemma is_original_cap_set_cap:
  "(x,s') \<in> fst (set_cap p c s) \<Longrightarrow> is_original_cap s' = is_original_cap s"
  by (clarsimp simp: set_cap_def in_monad split_def get_object_def set_object_def
               split: split_if_asm Structures_A.kernel_object.splits)


lemma mdb_set_cap:
  "(x,s') \<in> fst (set_cap p c s) \<Longrightarrow> cdt s' = cdt s"
  by (clarsimp simp: set_cap_def in_monad split_def get_object_def set_object_def
               split: split_if_asm Structures_A.kernel_object.splits)

(* FIXME: rename *)
lemma yes_indeed [simp]:
  "(None \<in> range Some) = False"
  by auto

lemma aobj_ref_cases':
  "aobj_ref acap = (case acap of arch_cap.ASIDControlCap \<Rightarrow> aobj_ref acap
                                | _ \<Rightarrow> aobj_ref acap)"
  by (simp split: arch_cap.split)


lemma aobj_ref_cases:
  "aobj_ref acap = 
  (case acap of 
    arch_cap.ASIDPoolCap w1 w2 \<Rightarrow> Some w1 
  | arch_cap.ASIDControlCap \<Rightarrow> None
  | arch_cap.PageCap w s sz opt \<Rightarrow> Some w
  | arch_cap.PageTableCap w opt \<Rightarrow> Some w
  | arch_cap.PageDirectoryCap w opt \<Rightarrow> Some w)"
  apply (subst aobj_ref_cases')
  apply (clarsimp cong: arch_cap.case_cong)
  done


lemma master_cap_obj_refs:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> obj_refs c = obj_refs c'"
  by (simp add: cap_master_cap_def split: cap.splits arch_cap.splits)
 

lemma master_cap_untyped_range:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> untyped_range c = untyped_range c'"
  by (simp add: cap_master_cap_def split: cap.splits arch_cap.splits)


lemma master_cap_cap_range:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> cap_range c = cap_range c'"
  by (simp add: cap_range_def cong: master_cap_untyped_range master_cap_obj_refs)


lemma master_cap_ep:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> is_ep_cap c = is_ep_cap c'"
  by (simp add: cap_master_cap_def is_cap_simps split: cap.splits)


lemma master_cap_aep:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> is_aep_cap c = is_aep_cap c'"
  by (simp add: cap_master_cap_def is_cap_simps split: cap.splits)


lemma cap_master_cap_zombie:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> is_zombie c = is_zombie c'"
  by (simp add: cap_master_cap_def is_cap_simps split: cap.splits arch_cap.splits)  


lemma cap_master_cap_zobj_refs:
  "cap_master_cap c = cap_master_cap c' \<Longrightarrow> zobj_refs c = zobj_refs c'"
  by (simp add: cap_master_cap_def split: cap.splits arch_cap.splits)  


lemma caps_of_state_obj_refs:
  "\<lbrakk> caps_of_state s p = Some cap; r \<in> obj_refs cap; valid_objs s \<rbrakk> 
  \<Longrightarrow> \<exists>ko. kheap s r = Some ko"
  apply (subgoal_tac "valid_cap cap s")
   prefer 2
   apply (rule cte_wp_valid_cap)
    apply (erule caps_of_state_cteD)
   apply assumption
  apply (cases cap, auto simp: valid_cap_def obj_at_def
                         split: option.splits arch_cap.splits)
  done

locale mdb_insert_abs =
  fixes m src dest
  assumes neq: "src \<noteq> dest"
  assumes dest: "m dest = None"
  assumes desc: "descendants_of dest m = {}"


locale mdb_insert_abs_sib = mdb_insert_abs +
  fixes n
  defines "n \<equiv> m(dest := m src)"


context mdb_insert_abs
begin
lemma dest_no_parent_trancl [iff]:
  "(m \<Turnstile> dest \<rightarrow> p) = False" using desc
  by (simp add: descendants_of_def del: split_paired_All)


lemma dest_no_parent [iff]:
  "(m \<Turnstile> dest \<leadsto> p) = False" 
  by (fastforce dest: r_into_trancl)


lemma dest_no_parent_d [iff]:
  "(m p = Some dest) = False"
  apply clarsimp
  apply (fold cdt_parent_defs)
  apply simp
  done


lemma dest_no_child [iff]:
  "(m \<Turnstile> p \<leadsto> dest) = False" using dest
  by (simp add: cdt_parent_defs)


lemma dest_no_child_trancl [iff]:
  "(m \<Turnstile> p \<rightarrow> dest) = False" 
  by (clarsimp dest!: tranclD2)


lemma descendants_child:
  "descendants_of x (m(dest \<mapsto> src)) =
  (if src \<in> descendants_of x m \<or> x = src 
   then descendants_of x m \<union> {dest} else descendants_of x m)"
  apply (rule descendants_of_insert_child')
    apply (rule desc)
   apply (rule neq)  
  apply (rule dest)
  done


lemma descendants_inc:
  assumes dinc: "descendants_inc m cs"
  assumes src: "cs src = Some c"
  assumes type: "cap_class cap = cap_class c \<and> cap_range cap \<subseteq> cap_range c"
  shows "descendants_inc (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  using dinc src type
  apply (simp add:descendants_inc_def del:split_paired_All)
  apply (intro allI conjI)
   apply (intro impI allI)
   apply (simp add:descendants_child split:if_splits del:split_paired_All)
    apply (erule disjE)
     apply (drule spec)+
     apply (erule(1) impE)
      apply simp
      apply blast
    apply simp
   apply (simp add:descendants_of_def)
  apply (intro impI allI)
  apply (rule conjI)
   apply (intro impI)
   apply (simp add:descendants_child
     split:if_splits del:split_paired_All)
    apply (simp add: descendants_of_def)
    apply (cut_tac p = p in dest_no_parent_trancl,simp)
   apply (simp add:descendants_of_def)
  apply (intro impI)
  apply (simp add:descendants_child split:if_splits del:split_paired_All)
  done


end
context mdb_insert_abs_sib
begin
lemma dest_no_parent_d_n [iff]:
  "(n p = Some dest) = False"
  by (simp add: n_def)


lemma dest_no_parent_n [iff]:
  "n \<Turnstile> dest \<leadsto> z = False"
  by (simp add: cdt_parent_defs)


lemma dest_no_parent_n_trancl [iff]:
  "n \<Turnstile> dest \<rightarrow> z = False"
  by (clarsimp dest!: tranclD)


lemma n_to_dest [iff]:
  "(n \<Turnstile> p \<leadsto> dest) = (m \<Turnstile> p \<leadsto> src)"
  by (simp add: n_def cdt_parent_defs)


lemma parent_n:
  "n \<Turnstile> p \<rightarrow> p' \<Longrightarrow> if p' = dest then m \<Turnstile> p \<rightarrow> src else m \<Turnstile> p \<rightarrow> p'"
  apply (erule trancl_induct)
   apply simp
   apply (rule conjI)
    apply (rule impI) 
    apply simp
   apply (clarsimp simp: n_def cdt_parent_defs)
   apply fastforce
  apply (simp split: split_if_asm)
  apply (rule conjI)
   apply (rule impI)
   apply simp
  apply (rule impI)
  apply (erule trancl_into_trancl)
  apply (clarsimp simp: n_def cdt_parent_defs)
  done


lemma dest_neq_Some [iff]:
  "(m dest = Some p) = False" using dest
  by simp


lemma parent_m:
  "m \<Turnstile> p \<rightarrow> p' \<Longrightarrow> n \<Turnstile> p \<rightarrow> p'"
  apply (erule trancl_induct)
   apply (rule r_into_trancl)
   apply (simp add: n_def cdt_parent_defs)
   apply (rule impI)
   apply simp
  apply (erule trancl_into_trancl)
  apply (simp add: n_def cdt_parent_defs)
  apply (rule impI)
  apply simp
  done


lemma parent_m_dest:
  "m \<Turnstile> p \<rightarrow> src \<Longrightarrow> n \<Turnstile> p \<rightarrow> dest"
  apply (erule converse_trancl_induct)
   apply (rule r_into_trancl)
   apply (clarsimp simp: n_def cdt_parent_defs)
  apply (rule trancl_trans)
   prefer 2
   apply assumption
  apply (rule r_into_trancl)
  apply (simp add: n_def cdt_parent_defs)
  apply (rule impI)
  apply simp
  done


lemma parent_n_eq:
  "n \<Turnstile> p \<rightarrow> p' = (if p' = dest then m \<Turnstile> p \<rightarrow> src else m \<Turnstile> p \<rightarrow> p')"
  apply (rule iffI)
   apply (erule parent_n)
  apply (simp split: split_if_asm)
   apply (erule parent_m_dest)
  apply (erule parent_m)
  done
  

lemma descendants:
  "descendants_of p n = 
   descendants_of p m \<union> (if src \<in> descendants_of p m then {dest} else {})"
  by (rule set_eqI) (simp add: descendants_of_def parent_n_eq)

end

(* FIXME: remove copy_of and use cap_master_cap with weak_derived directly *)
definition
  copy_of :: "cap \<Rightarrow> cap \<Rightarrow> bool"
where
  "copy_of cap' cap \<equiv> 
  if (is_untyped_cap cap \<or> is_reply_cap cap \<or> is_master_reply_cap cap)
     then cap = cap' else same_object_as cap cap'"

definition
  "weak_derived cap cap' \<equiv> 
  (copy_of cap cap' \<and> 
   cap_asid cap = cap_asid cap' \<and> 
   cap_asid_base cap = cap_asid_base cap' \<and>
   cap_vptr cap = cap_vptr cap') \<or> 
  cap' = cap"


lemma (in mdb_insert_abs) untyped_mdb:  
  assumes u: "untyped_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "untyped_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"  
  unfolding untyped_mdb_def
  apply (intro allI impI)
  apply (simp add: descendants_child)
  apply (rule conjI)
   apply (rule impI)
   apply (rule disjCI2)
   apply simp
   apply (case_tac "ptr = dest")
    apply simp
    apply (insert u)[1]
    apply (unfold untyped_mdb_def)
    apply (erule allE)+
    apply (erule impE, rule src)
    apply (erule impE)
     apply (insert d)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: cap.splits arch_cap.splits)
     apply (drule cap_master_cap_eqDs)
     apply fastforce
    apply (erule (1) impE)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                   split: split_if_asm cap.splits arch_cap.split_asm)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (simp add: descendants_of_def)
   apply (insert u)[1]
   apply (unfold untyped_mdb_def)
   apply fastforce
  apply (rule conjI)
   apply (rule impI)
   apply (rule disjCI2)
   apply (simp add: neq)
   apply (insert u src)[1]
   apply simp
   apply (unfold untyped_mdb_def)
   apply (erule allE)+
   apply (erule impE, rule src)
   apply (erule impE)
    apply (clarsimp simp: is_cap_simps is_derived_def same_object_as_def
                   split: cap.splits)
   apply (erule (1) impE)
   apply simp
  apply (rule impI)
  apply (erule conjE)   
  apply (simp split: split_if_asm)
     apply (clarsimp simp: is_cap_simps)    
    apply (insert u)[1]
    apply (unfold untyped_mdb_def)
    apply (erule allE)+
    apply (erule impE, rule src)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: cap.splits arch_cap.splits)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (erule (1) impE)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: split_if_asm cap.splits arch_cap.splits)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                   split: split_if_asm cap.splits arch_cap.splits)
    apply (fastforce dest: cap_master_cap_eqDs)
   apply (insert u)[1]
   apply (unfold untyped_mdb_def)
   apply (erule allE)+
   apply (erule (1) impE)
   apply (erule (1) impE)
   apply (erule impE, rule src)
   apply (erule impE)
    apply (clarsimp simp:  is_derived_def 
                   split: split_if_asm) 
    apply (drule master_cap_obj_refs)
    apply (fastforce dest: master_cap_obj_refs)
    apply (clarsimp simp:is_cap_simps cap_master_cap_def split:cap.splits arch_cap.splits)
   apply simp
  apply (insert u)[1]
  apply (unfold untyped_mdb_def)
  apply fastforce
  done


lemma master_cap_class:
  "cap_master_cap a = cap_master_cap b
  \<Longrightarrow> cap_class a = cap_class b"
  apply (case_tac a)
   apply (clarsimp simp: cap_master_cap_simps dest!:cap_master_cap_eqDs)+
  apply (rename_tac arch_cap)
  apply (case_tac arch_cap)
   apply (clarsimp simp: cap_master_cap_simps dest!:cap_master_cap_eqDs)+
  done


lemma is_derived_cap_class_range:
  "is_derived m src cap capa
  \<Longrightarrow> cap_class cap = cap_class capa \<and> cap_range cap \<subseteq> cap_range capa"
  apply (clarsimp simp:is_derived_def split:if_splits)
   apply (frule master_cap_cap_range)
   apply (drule master_cap_class)
   apply simp
  apply (frule master_cap_cap_range)
  apply (drule master_cap_class)
  apply simp
  done


lemma (in mdb_insert_abs_sib) descendants_inc:  
  assumes dinc: "descendants_inc m cs"
  assumes src: "cs src = Some c"
  assumes d: "cap_class cap = cap_class c \<and> cap_range cap \<subseteq> cap_range c"
  shows "descendants_inc n (cs(dest \<mapsto> cap))"
  using dinc src d
  apply (simp add:descendants_inc_def del:split_paired_All)
  apply (intro allI conjI)
   apply (intro impI allI)
   apply (simp add:descendants_child descendants split:if_splits del:split_paired_All)
     apply (drule spec)+
     apply (erule(1) impE)
      apply simp
      apply blast
    apply simp
   apply (simp add:descendants_of_def)
  apply (intro impI allI)
  apply (rule conjI)
   apply (intro impI)
   apply (simp add:descendants_child descendants
     split:if_splits del:split_paired_All)
    apply (simp add: descendants_of_def)
   apply (simp add:descendants_of_def descendants)
  apply (intro impI)
  apply (simp add: descendants del:split_paired_All split:if_splits)
  done


lemma (in mdb_insert_abs_sib) untyped_mdb_sib:  
  assumes u: "untyped_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "untyped_mdb n (cs(dest \<mapsto> cap))"
  unfolding untyped_mdb_def
  apply (intro allI impI)
  apply (simp add: descendants)
  apply (rule conjI)
   apply (rule impI, rule disjCI)
   apply (simp split: split_if_asm)
    apply (insert u)[1]
    apply (unfold untyped_mdb_def)
    apply (erule allE)+
    apply (erule impE, rule src)
    apply (erule impE)
     apply (insert d)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: cap.splits arch_cap.split_asm)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (erule (1) impE)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: split_if_asm cap.splits arch_cap.split_asm)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (simp add: descendants_of_def)
   apply (insert u)[1]
   apply (unfold untyped_mdb_def)
   apply fastforce
  apply (rule impI)
  apply (simp split: split_if_asm)
     apply (clarsimp simp: is_cap_simps)
    apply (insert u)[1]
    apply (unfold untyped_mdb_def)
    apply (erule allE)+
    apply (erule impE, rule src)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: cap.splits arch_cap.split_asm)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (erule (1) impE)
    apply (erule impE)
     apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                    split: split_if_asm)
     apply (fastforce dest: cap_master_cap_eqDs)
    apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                   split: split_if_asm)
    apply (fastforce dest: cap_master_cap_eqDs)
   apply (insert u)[1]
   apply (unfold untyped_mdb_def)
   apply (erule allE)+
   apply (erule (1) impE)
   apply (erule (1) impE)
   apply (erule impE, rule src)
   apply (erule impE)
    apply (clarsimp simp: is_cap_simps is_derived_def cap_master_cap_simps
                   split: split_if_asm cap.splits dest!:cap_master_cap_eqDs)
    apply (blast dest: master_cap_obj_refs)
   apply simp
  apply (insert u)[1]
  apply (unfold untyped_mdb_def)
  apply fastforce
  done


lemma mdb_cte_at_Null_None:
  "\<lbrakk> cs p = Some cap.NullCap; 
     mdb_cte_at (\<lambda>p. \<exists>c. cs p = Some c \<and> cap.NullCap \<noteq> c) m \<rbrakk>
  \<Longrightarrow> m p = None"
  apply (simp add: mdb_cte_at_def)
  apply (rule classical)
  apply fastforce
  done


lemma mdb_cte_at_Null_descendants:
  "\<lbrakk> cs p = Some cap.NullCap; 
     mdb_cte_at (\<lambda>p. \<exists>c. cs p = Some c \<and> cap.NullCap \<noteq> c) m \<rbrakk>
  \<Longrightarrow> descendants_of p m = {}"
  apply (simp add: mdb_cte_at_def descendants_of_def)
  apply clarsimp
  apply (drule tranclD)
  apply (clarsimp simp: cdt_parent_of_def)
  apply (cases p)
  apply fastforce
  done


lemma (in mdb_insert_abs) parency:
  "(m (dest \<mapsto> src) \<Turnstile> p \<rightarrow> p') = 
  (if m \<Turnstile> p \<rightarrow> src \<or> p = src then p' = dest \<or> m \<Turnstile> p \<rightarrow> p' else m \<Turnstile> p \<rightarrow> p')"
  using descendants_child [where x=p]
  unfolding descendants_of_def
  by simp fastforce
 

context mdb_insert_abs
begin
lemmas mis_neq_simps [simp] = neq [symmetric]


lemma untyped_inc_simple:
  assumes u: "untyped_inc m cs"
  assumes src: "cs src = Some c"
  assumes al:  "cap_aligned c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes ut: "untyped_range cap = untyped_range c \<or> \<not>is_untyped_cap cap"
  assumes ut': "is_untyped_cap cap \<longrightarrow> is_untyped_cap c"
  assumes dsc: "is_untyped_cap cap \<longrightarrow> descendants_of src m = {}"
  assumes usable:"is_untyped_cap cap \<longrightarrow> is_untyped_cap c \<longrightarrow> usable_untyped_range c = {}"
  shows "untyped_inc (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
proof -
  have  no_usage:"\<And>p c'. is_untyped_cap cap \<longrightarrow> cs p = Some c' \<longrightarrow> untyped_range c = untyped_range c' \<longrightarrow> usable_untyped_range c' = {}"
    using src u
    unfolding untyped_inc_def
    apply (erule_tac x = src in allE)
    apply (intro impI)
    apply (erule_tac x = p in allE)
    apply (case_tac "is_untyped_cap c")
      apply simp
      apply (case_tac "is_untyped_cap c'")
        apply simp
        using dsc ut usable
        apply clarsimp
        apply (elim disjE)
          apply clarsimp+
    using al
    apply (case_tac c',simp_all add:is_cap_simps untyped_range_non_empty)
    using ut'
    apply (clarsimp simp:is_cap_simps)
    done
    
  from ut ut' dsc dst
  show ?thesis using u src desc
  unfolding untyped_inc_def
  apply (simp del: fun_upd_apply split_paired_All)
  apply (intro allI)
   apply (case_tac "p = dest")
     apply (case_tac "p' = dest")
       apply (clarsimp simp:src dst)
     apply (case_tac "p'=src")
       apply (erule_tac x=src in allE)
       apply (erule_tac x=p' in allE)
       apply (cut_tac p = src and c' = c in no_usage)
       apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
     apply (erule_tac x=src in allE)
     apply (erule_tac x=p' in allE)
       apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
   apply (erule_tac x=p in allE)
     apply (case_tac "p'=dest")
       apply (case_tac "p'=src")
         apply (erule_tac x=src in allE)
         apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
     apply (erule_tac x=src in allE)
       apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
     apply (cut_tac p = "(a,b)" and c' = ca in no_usage)
       apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
   apply (case_tac "p' = src")
     apply (erule_tac x = src in allE)
       apply (clarsimp simp del:split_paired_All split del:if_splits simp: descendants_child)
   apply (erule_tac x = p' in allE)
     apply (clarsimp simp del:split_paired_All simp: descendants_child)
   done
  qed


lemma untyped_inc:  
  assumes u: "untyped_inc m cs"
  assumes src: "cs src = Some c"
  assumes al:  "cap_aligned c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  assumes usable:"is_untyped_cap c \<longrightarrow> usable_untyped_range c = {}"
  shows "untyped_inc (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
proof -
  from d 
  have "untyped_range cap = untyped_range c"
    by (clarsimp simp: is_derived_def cap_master_cap_def is_cap_simps
                split: cap.split_asm arch_cap.split_asm split_if_asm)
  moreover
  from d 
  have "is_untyped_cap cap \<longrightarrow> descendants_of src m = {}"
    by (auto simp: is_derived_def cap_master_cap_def is_cap_simps
             split: split_if_asm cap.splits arch_cap.split_asm)
  moreover
  from d
  have "is_untyped_cap cap \<longrightarrow> is_untyped_cap c"
    by (auto simp: is_derived_def cap_master_cap_def is_cap_simps
             split: split_if_asm cap.splits arch_cap.split_asm)
  ultimately
  show ?thesis using assms
    by (auto intro!: untyped_inc_simple)
qed


end
lemma (in mdb_insert_abs) reply_caps_mdb:
  assumes r: "reply_caps_mdb m cs"
  assumes src: "cs src = Some c"
  assumes d: "is_derived m src cap c"
  shows "reply_caps_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  unfolding reply_caps_mdb_def
  using r d
  apply (intro allI impI)
  apply (simp add: desc neq split: split_if_asm del: split_paired_Ex)
   apply (clarsimp simp: src is_derived_def is_cap_simps cap_master_cap_def)
  apply (unfold reply_caps_mdb_def)[1]
  apply (erule allE)+
  apply (erule(1) impE)
  apply (erule exEI)
  apply blast
  done


lemma (in mdb_insert_abs) reply_masters_mdb:
  assumes r: "reply_masters_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "reply_masters_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  unfolding reply_masters_mdb_def
  using r d
  apply (intro allI impI)
  apply (simp add: descendants_child)
  apply (simp add: neq desc split: split_if_asm)
   apply (clarsimp simp: src is_derived_def is_cap_simps cap_master_cap_def)
  apply (unfold reply_masters_mdb_def)
  apply (intro conjI)
    apply (erule allE)+
    apply (erule(1) impE)
    apply simp
    apply (rule impI)
    apply (erule conjE)
    apply (drule_tac x=src in bspec, assumption)
    apply (clarsimp simp: src is_derived_def is_cap_simps)
   apply (erule allE)+
   apply (erule(1) impE)
   apply (rule impI, simp)
   apply (clarsimp simp: src is_derived_def is_cap_simps cap_master_cap_def)
  apply (erule allE)+
  apply (erule(1) impE)
  apply (rule impI, simp, rule impI)
  apply (erule conjE)
  apply (drule_tac x=dest in bspec, assumption)
  apply (simp add: dst)
  done


lemma (in mdb_insert_abs) reply_mdb:
  assumes r: "reply_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "reply_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  using r unfolding reply_mdb_def
  by (simp add: reply_caps_mdb reply_masters_mdb src dst d)


lemma (in mdb_insert_abs_sib) reply_caps_mdb_sib:
  assumes r: "reply_caps_mdb m cs"
  assumes p: "\<not>should_be_parent_of c r cap f"
  assumes rev: "is_master_reply_cap c \<longrightarrow> r"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "reply_caps_mdb n (cs(dest \<mapsto> cap))"
  unfolding reply_caps_mdb_def
  using r p d
  apply (intro allI impI)
  apply (simp add: desc neq split: split_if_asm del: split_paired_Ex)
   apply (clarsimp simp: should_be_parent_of_def is_derived_def is_cap_simps
                         cap_master_cap_def rev)
  apply (unfold reply_caps_mdb_def)[1]
  apply (erule allE)+
  apply (erule(1) impE)
  apply (erule exEI)
  apply (simp add: n_def)
  apply blast
  done


lemma (in mdb_insert_abs_sib) reply_masters_mdb_sib:
  assumes r: "reply_masters_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  shows "reply_masters_mdb n (cs(dest \<mapsto> cap))"
  unfolding reply_masters_mdb_def
  using r d
  apply (intro allI impI)
  apply (simp add: descendants)
  apply (simp add: neq desc split: split_if_asm)
   apply (clarsimp simp: is_derived_def is_cap_simps cap_master_cap_def)
  apply (unfold reply_masters_mdb_def)
  apply (intro conjI)
   apply (erule allE)+
   apply (erule(1) impE)
   apply simp
   apply (rule impI)
   apply (erule conjE)
   apply (drule_tac x=src in bspec, assumption)
   apply (clarsimp simp: src is_derived_def is_cap_simps)
  apply (erule allE)+
  apply (erule(1) impE)
  apply (rule impI, simp add: n_def)
  apply (rule impI, erule conjE)
  apply (drule_tac x=dest in bspec, assumption)
  apply (simp add: dst)
  done


lemma (in mdb_insert_abs_sib) reply_mdb_sib:
  assumes r: "reply_mdb m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes d: "is_derived m src cap c"
  assumes p: "\<not>should_be_parent_of c r cap f"
  assumes rev: "is_master_reply_cap c \<longrightarrow> r"
  shows "reply_mdb n (cs(dest \<mapsto> cap))"
  using r src dst d p rev unfolding reply_mdb_def
  by (simp add: reply_caps_mdb_sib reply_masters_mdb_sib)


lemma not_parent_not_untyped:
  assumes p: "\<not>should_be_parent_of c r c' f" "is_derived m p c' c" "cap_aligned c'" 
  assumes r: "is_untyped_cap c \<longrightarrow> r"
  shows "\<not>is_untyped_cap c" using p r 
  apply (clarsimp simp: cap_master_cap_def should_be_parent_of_def is_cap_simps is_derived_def
    split: split_if_asm cap.splits)
  apply (simp add: cap_aligned_def is_physical_def)
  apply (elim conjE)
   apply (drule is_aligned_no_overflow, simp)
  done


context mdb_insert_abs_sib
begin
lemma untyped_inc:  
  assumes u: "untyped_inc m cs"
  assumes d: "is_derived m src cap c"
  assumes p: "\<not>should_be_parent_of c r cap f" "cap_aligned cap"
  assumes r: "is_untyped_cap c \<longrightarrow> r"
  shows "untyped_inc n (cs(dest \<mapsto> cap))"
proof -
  from p d r
  have u1: "\<not>is_untyped_cap c" by - (rule not_parent_not_untyped) 
  moreover
  with d
  have u2: "\<not>is_untyped_cap cap" 
    by (auto simp: is_derived_def cap_master_cap_def is_cap_simps 
             split: split_if_asm cap.splits arch_cap.split_asm)
  ultimately  
  show ?thesis using u desc
    unfolding untyped_inc_def
    by (auto simp: descendants split: split_if_asm)
qed


end
lemma IRQ_not_derived [simp]:
  "\<not>is_derived m src cap.IRQControlCap cap"
  by (simp add: is_derived_def)


lemma update_original_mdb_cte_at:
  "mdb_cte_at (swp (cte_wp_at P) (s\<lparr>is_original_cap := x\<rparr>))
              (cdt (s\<lparr>is_original_cap := x\<rparr>)) =
   mdb_cte_at (swp (cte_wp_at P) s) (cdt s)"
  by (clarsimp simp:mdb_cte_at_def)


lemma update_cdt_mdb_cte_at:
  "\<lbrace>\<lambda>s. mdb_cte_at (swp (cte_wp_at P) s) (cdt s) \<and>
        (case (f (cdt s)) of Some p \<Rightarrow> cte_wp_at P p s \<and> cte_wp_at P c s
                           | None \<Rightarrow> True)\<rbrace>
   update_cdt (\<lambda>cdt. cdt(c := (f cdt))) 
   \<lbrace>\<lambda>xc s. mdb_cte_at (swp (cte_wp_at P) s) (cdt s)\<rbrace>"
  apply (clarsimp simp: update_cdt_def gets_def get_def set_cdt_def 
                        put_def bind_def return_def valid_def)
  apply (clarsimp simp: mdb_cte_at_def split:option.splits)+
  done


lemma set_cap_mdb_cte_at:
  "\<lbrace>\<lambda>s. mdb_cte_at (swp (cte_wp_at P) s) (cdt s) \<and>
        (dest \<in> dom (cdt s)\<union> ran (cdt s) \<longrightarrow> P new_cap)\<rbrace>
   set_cap new_cap dest
   \<lbrace>\<lambda>xc s. mdb_cte_at (swp (cte_wp_at P) s) (cdt s)\<rbrace>"
   apply (clarsimp simp:mdb_cte_at_def cte_wp_at_caps_of_state valid_def)
   apply (simp add:mdb_set_cap)
   apply (intro conjI)
     apply (erule use_valid[OF _ set_cap_caps_of_state])
     apply simp
     apply (rule impI)
     apply (erule_tac P = "x\<in> ran G" for x G in mp)
     apply (rule ranI,simp)
   apply (erule use_valid[OF _ set_cap_caps_of_state])
   apply (drule spec)+
   apply (drule_tac P = "cdt x y = z" for x y z in mp)
   apply simp+
  apply clarsimp
  done


lemma mdb_cte_at_cte_wp_at:
  "\<lbrakk>mdb_cte_at (swp (cte_wp_at P) s) (cdt s);
    src \<in> dom (cdt s) \<or> src \<in> ran (cdt s)\<rbrakk>
   \<Longrightarrow> cte_wp_at P src s"
  apply (case_tac src)
  apply (auto simp:mdb_cte_at_def ran_def)
  done


lemma no_mloop_weaken:
  "\<lbrakk>no_mloop m\<rbrakk> \<Longrightarrow> m a \<noteq> Some a"
  apply (clarsimp simp:no_mloop_def cdt_parent_rel_def)
  apply (subgoal_tac "(a,a)\<in> {(x, y). is_cdt_parent m x y}")
    apply (drule r_into_trancl')
  apply (drule_tac x = "fst a" in spec)
  apply (drule_tac x = "snd a" in spec)
    apply clarsimp
  apply(simp add:is_cdt_parent_def)
  done


lemma no_mloop_neq:
  "\<lbrakk>no_mloop m;m a = Some b\<rbrakk> \<Longrightarrow> a\<noteq> b"
  apply (rule ccontr)
  apply (auto simp:no_mloop_weaken)
  done


lemma is_derived_not_Null:
  "is_derived (cdt s) src cap capa \<Longrightarrow> cap \<noteq> cap.NullCap"
  by (simp add:is_derived_def)


lemma mdb_cte_at_cdt_null:
  "\<lbrakk>caps_of_state s p = Some cap.NullCap;
    mdb_cte_at (swp (cte_wp_at (op\<noteq> cap.NullCap)) s) (cdt s)\<rbrakk>
   \<Longrightarrow> (cdt s) p = None"
  apply (rule ccontr)
  apply (clarsimp)
  apply (drule_tac src=p in mdb_cte_at_cte_wp_at)
  apply (fastforce)
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  done


lemma set_untyped_cap_as_full_cdt[wp]:
  "\<lbrace>\<lambda>s. P (cdt s)\<rbrace> set_untyped_cap_as_full src_cap cap src \<lbrace>\<lambda>_ s'. P (cdt s')\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (wp set_cap_rvk_cdt_ct_ms)
  done



lemma mdb_cte_at_set_untyped_cap_as_full:
  assumes localcong:"\<And>a cap. P (cap\<lparr>free_index:= a\<rparr>) = P cap"
  shows " 
  \<lbrace>\<lambda>s. mdb_cte_at (swp (cte_wp_at P) s) (cdt s) \<and> cte_wp_at (op = src_cap) src s\<rbrace>
  set_untyped_cap_as_full src_cap cap src 
  \<lbrace>\<lambda>rv s'. mdb_cte_at (swp (cte_wp_at P) s') (cdt s') \<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def split del:if_splits)
  apply (rule hoare_pre)
  apply (wp set_cap_mdb_cte_at)
  apply clarsimp
  apply (unfold mdb_cte_at_def)
    apply (intro conjI impI,elim allE domE ranE impE,simp)
    apply (clarsimp simp:cte_wp_at_caps_of_state cong:local.localcong)
  apply (elim allE ranE impE,simp)
     apply (clarsimp simp:cte_wp_at_caps_of_state cong:local.localcong)
done


lemma set_untyped_cap_as_full_is_original[wp]:
  "\<lbrace>\<lambda>s. P (is_original_cap s)\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s'. P (is_original_cap s') \<rbrace>"
  apply (simp add:set_untyped_cap_as_full_def split del:if_splits)
  apply (rule hoare_pre)
  apply wp
  apply auto
done


(* FIXME: MOVE*)
lemma is_cap_free_index_update[simp]:
  "is_zombie (src_cap\<lparr>free_index := f \<rparr>) = is_zombie src_cap"
  "is_cnode_cap (src_cap\<lparr>free_index := f \<rparr>) = is_cnode_cap src_cap"
  "is_thread_cap (src_cap\<lparr>free_index := f \<rparr>) = is_thread_cap src_cap"
  "is_domain_cap (src_cap\<lparr>free_index := f \<rparr>) = is_domain_cap src_cap"
  "is_ep_cap (src_cap\<lparr>free_index := f \<rparr>) = is_ep_cap src_cap"
  "is_untyped_cap (src_cap\<lparr>free_index := f \<rparr>) = is_untyped_cap src_cap"
  "is_arch_cap (src_cap\<lparr>free_index := f \<rparr>) = is_arch_cap src_cap"
  "is_zombie (src_cap\<lparr>free_index := f \<rparr>) = is_zombie src_cap"
  "is_aep_cap (src_cap\<lparr>free_index := f \<rparr>) = is_aep_cap src_cap"
  "is_reply_cap (src_cap\<lparr>free_index := f \<rparr>) = is_reply_cap src_cap"
  "is_master_reply_cap (src_cap\<lparr>free_index := f \<rparr>) = is_master_reply_cap src_cap"
  "is_pd_cap (src_cap\<lparr>free_index := a\<rparr>) = is_pd_cap src_cap"
  "is_pt_cap (src_cap\<lparr>free_index := a\<rparr>) = is_pt_cap src_cap"
  by (simp add:is_cap_simps free_index_update_def split:cap.splits)+


lemma masked_as_full_simps[simp]:
  "masked_as_full (cap.EndpointCap r badge a) cap = (cap.EndpointCap r badge a)"
  "masked_as_full (cap.Zombie r bits n) cap = (cap.Zombie r bits n)"
  "masked_as_full (cap.ArchObjectCap x) cap = (cap.ArchObjectCap x)"
  "masked_as_full (cap.CNodeCap r n g) cap = (cap.CNodeCap r n g)"
  "masked_as_full (cap.ReplyCap r m) cap = (cap.ReplyCap r m)"
  "masked_as_full cap.NullCap cap = cap.NullCap"
  "masked_as_full cap.DomainCap cap = cap.DomainCap"
  "masked_as_full (cap.ThreadCap r) cap = cap.ThreadCap r"
  "masked_as_full cap (cap.EndpointCap r badge a) = cap"
  "masked_as_full cap (cap.Zombie r bits n) = cap"
  "masked_as_full cap (cap.ArchObjectCap x) = cap"
  "masked_as_full cap (cap.CNodeCap r n g) = cap"
  "masked_as_full cap (cap.ReplyCap r m) = cap"
  "masked_as_full cap cap.NullCap = cap"
  "masked_as_full cap cap.DomainCap = cap"
  "masked_as_full cap (cap.ThreadCap r) = cap"

  by (simp add:masked_as_full_def)+

lemma maksed_as_full_test_function_stuff[simp]:
  "obj_irq_refs (masked_as_full a cap) = obj_irq_refs a"
  "vs_cap_ref (masked_as_full a cap ) = vs_cap_ref a"
  "cap_asid (masked_as_full a cap ) = cap_asid a"
  "obj_refs (masked_as_full a cap ) = obj_refs a"
  "is_zombie (masked_as_full a cap ) = is_zombie a"
  "is_cnode_cap (masked_as_full a cap ) = is_cnode_cap a"
  "is_thread_cap (masked_as_full a cap ) = is_thread_cap a"
  "is_domain_cap (masked_as_full a cap ) = is_domain_cap a"
  "is_ep_cap (masked_as_full a cap ) = is_ep_cap a"
  "is_untyped_cap (masked_as_full a cap ) = is_untyped_cap a"
  "is_arch_cap (masked_as_full a cap ) = is_arch_cap a"
  "is_zombie (masked_as_full a cap ) = is_zombie a"
  "is_aep_cap (masked_as_full a cap ) = is_aep_cap a"
  "is_reply_cap (masked_as_full a cap ) = is_reply_cap a"
  "is_master_reply_cap (masked_as_full a cap ) = is_master_reply_cap a"
  "is_pd_cap (masked_as_full a cap ) = is_pd_cap a"
  "is_pt_cap (masked_as_full a cap ) = is_pt_cap a"
  by (auto simp:masked_as_full_def)

lemma free_index_update_ut_revocable[simp]:
  "ms src = Some src_cap \<Longrightarrow>
   ut_revocable P (ms (src \<mapsto> (src_cap\<lparr>free_index:=a\<rparr>))) = ut_revocable P ms"
  unfolding ut_revocable_def
  apply (rule iffI)
    apply clarify
    apply (drule_tac x = p in spec)
    apply (case_tac "p = src")
      apply clarsimp+
  done


lemma free_index_update_irq_revocable[simp]:
  "ms src = Some src_cap \<Longrightarrow> 
   irq_revocable P (ms(src \<mapsto> src_cap\<lparr>free_index:=a\<rparr>)) = irq_revocable P ms"
  unfolding irq_revocable_def
  apply (rule iffI)
    apply clarify
    apply (drule_tac x = p in spec)
      apply (case_tac "p = src")
       apply (clarsimp simp:free_index_update_def)+
  apply (simp add: free_index_update_def split:cap.splits)
done
  

lemma free_index_update_reply_master_revocable[simp]:
  "ms src = Some src_cap \<Longrightarrow>
   reply_master_revocable P (ms(src \<mapsto> src_cap\<lparr>free_index:=a\<rparr>)) =
   reply_master_revocable P ms"
  unfolding reply_master_revocable_def
  apply (rule iffI)
    apply clarify
    apply (drule_tac x = p in spec)
      apply (case_tac "p = src")
       apply (clarsimp simp:free_index_update_def is_master_reply_cap_def
         split:cap.splits)+
  done


lemma imp_rev: "\<lbrakk>a\<longrightarrow>b;\<not>b\<rbrakk> \<Longrightarrow> \<not> a" by auto


crunch cte_wp_at[wp]: update_cdt "\<lambda>s. cte_wp_at P p s"
  (wp: crunch_wps)


crunch cte_wp_at[wp]: set_original "\<lambda>s. cte_wp_at P p s"
  (wp: crunch_wps)



lemma cap_insert_weak_cte_wp_at:
  "\<lbrace>(\<lambda>s. if p = dest then P cap else p \<noteq> src \<and> cte_wp_at P p s)\<rbrace>
   cap_insert cap src dest 
   \<lbrace>\<lambda>uu. cte_wp_at P p\<rbrace>"
  unfolding cap_insert_def error_def set_untyped_cap_as_full_def
  apply (simp add: bind_assoc split del: split_if )
  apply (wp set_cap_cte_wp_at hoare_vcg_if_lift hoare_vcg_imp_lift get_cap_wp | simp | intro conjI impI allI)+
  apply (auto simp: cte_wp_at_def)
  done

lemma mdb_cte_at_more_swp[simp]: "mdb_cte_at
            (swp (cte_wp_at P)
              (trans_state f s)) = 
       mdb_cte_at
            (swp (cte_wp_at P)
              (s))"
  apply (simp add: swp_def)
  done

lemma cap_insert_mdb_cte_at:
  "\<lbrace>(\<lambda>s. mdb_cte_at (swp (cte_wp_at (op \<noteq> cap.NullCap)) s) (cdt s)) and (\<lambda>s. no_mloop (cdt s))
    and valid_cap cap and 
    (\<lambda>s. cte_wp_at (is_derived (cdt s) src cap) src s) and
    K (src \<noteq> dest) \<rbrace> 
    cap_insert cap src dest 
   \<lbrace>\<lambda>_ s.  mdb_cte_at (swp (cte_wp_at (op \<noteq> cap.NullCap)) s) (cdt s)\<rbrace>"
  unfolding cap_insert_def
  apply (wp | simp cong: update_original_mdb_cte_at split del: split_if)+
  apply (wp update_cdt_mdb_cte_at set_cap_mdb_cte_at[simplified swp_def] | simp split del: split_if)+
  apply wps
  apply (wp valid_case_option_post_wp hoare_vcg_if_lift hoare_impI mdb_cte_at_set_untyped_cap_as_full[simplified swp_def] 
    set_cap_cte_wp_at get_cap_wp)
  apply (clarsimp simp:free_index_update_def split:cap.splits)
  apply (wp)
  apply (clarsimp simp:if_True conj_comms split del:if_splits cong:split_weak_cong)
  apply (wps)
  apply (wp valid_case_option_post_wp get_cap_wp hoare_vcg_if_lift
    hoare_impI set_untyped_cap_as_full_cte_wp_at )
  apply (unfold swp_def)
  apply (intro conjI | clarify)+
    apply (clarsimp simp:free_index_update_def split:cap.splits)
    apply (drule mdb_cte_at_cte_wp_at[simplified swp_def])
      apply simp
    apply (simp add:cte_wp_at_caps_of_state)
    apply (clarsimp split del:if_splits split:option.splits
      simp: cte_wp_at_caps_of_state not_sym[OF is_derived_not_Null] neq_commute)+
  apply (drule imp_rev)
    apply (clarsimp split:if_splits cap.splits
      simp:free_index_update_def is_cap_simps masked_as_full_def)
    apply (subst (asm) mdb_cte_at_def,elim allE impE,simp,clarsimp simp:cte_wp_at_caps_of_state)+
  apply (clarsimp split:if_splits cap.splits
      simp:free_index_update_def is_cap_simps masked_as_full_def)
    apply (subst (asm) mdb_cte_at_def,elim allE impE,simp,clarsimp simp:cte_wp_at_caps_of_state)+
done


lemma mdb_cte_at_rewrite:
  "\<lbrakk>mdb_cte_at (swp (cte_wp_at (op \<noteq> cap.NullCap)) s) (cdt s)\<rbrakk>
   \<Longrightarrow> mdb_cte_at (\<lambda>p. \<exists>c. (caps_of_state s) p = Some c \<and> cap.NullCap \<noteq> c)
                  (cdt s)"
 apply (clarsimp simp:mdb_cte_at_def)
 apply (drule spec)+
 apply (erule impE)
 apply simp
 apply (clarsimp simp:cte_wp_at_caps_of_state)
done 


lemma untyped_mdb_update_free_index:
  "\<lbrakk>m src = Some capa;m' = m (src\<mapsto> capa\<lparr>free_index :=x\<rparr>) \<rbrakk> \<Longrightarrow>
   untyped_mdb c (m') = untyped_mdb c (m)"
  apply (rule iffI)
  apply (clarsimp simp:untyped_mdb_def)
    apply (drule_tac x = a in spec)
    apply (drule_tac x = b in spec)
    apply (drule_tac x = aa in spec)
    apply (drule_tac x = ba in spec)
    apply (case_tac "src = (a,b)")
      apply (case_tac "src = (aa,ba)")
      apply (clarsimp simp:is_cap_simps free_index_update_def)
      apply (drule_tac x = "capa\<lparr>free_index :=x\<rparr>" in spec)
      apply (clarsimp simp:is_cap_simps free_index_update_def)
      apply (drule_tac x = cap' in spec)
    apply (clarsimp split:split_if_asm)+
  apply (clarsimp simp:untyped_mdb_def)
    apply (case_tac "src = (a,b)")
  apply (clarsimp simp:is_cap_simps free_index_update_def split:cap.split_asm)+
  done


lemma usable_untyped_range_empty[simp]:
  "is_untyped_cap cap \<Longrightarrow> usable_untyped_range (max_free_index_update cap) = {}"
  by (clarsimp simp:is_cap_simps free_index_update_def cap_aligned_def max_free_index_def)


lemma untyped_inc_update_free_index:
  "\<lbrakk>m src = Some cap; m' = m (src \<mapsto> (max_free_index_update cap));
    untyped_inc c m\<rbrakk> \<Longrightarrow>
   untyped_inc c m'"
  apply (unfold untyped_inc_def)
  apply (intro allI impI)
    apply (drule_tac x = p in spec)
    apply (drule_tac x = p' in spec)
    apply (case_tac "p = src")
      apply (simp del:fun_upd_apply split_paired_All)
    apply (clarsimp split:if_splits)+
  done


lemma reply_mdb_update_free_index:
  "\<lbrakk>m src = Some capa; m' = m (src \<mapsto> capa\<lparr>free_index :=x\<rparr>)\<rbrakk> \<Longrightarrow>
   reply_mdb c m'  = reply_mdb c m"
  apply (rule iffI)
   apply (clarsimp simp:reply_mdb_def,rule conjI)
    apply (clarsimp simp:reply_caps_mdb_def)
    apply (drule_tac x = a in spec)
    apply (drule_tac x = b in spec)
    apply (drule_tac x = t in spec)
    apply (clarsimp simp:is_cap_simps free_index_update_def split:cap.splits if_splits)+
    apply fastforce
   apply (clarsimp simp:reply_masters_mdb_def)
    apply (drule_tac x = a in spec)
    apply (drule_tac x = b in spec)
    apply (drule_tac x = t in spec)
    apply (clarsimp simp:split:if_splits simp:free_index_update_def)
    apply (drule_tac x = "(aa,ba)" in bspec)
      apply clarsimp+
    apply (drule_tac x = "(aa,ba)" in bspec)
      apply (clarsimp split:cap.splits)+
   apply (clarsimp simp:reply_mdb_def,rule conjI)
   apply (simp add: reply_caps_mdb_def del:split_paired_All split del:if_splits)
    apply (intro allI impI)
    apply (drule_tac x = ptr in spec)
    apply (drule_tac x = t in spec)
    apply (erule impE)
      apply (clarsimp split:if_splits cap.splits simp:free_index_update_def)
    apply clarify
    apply (intro exI conjI)
      apply assumption
     apply (clarsimp simp:split:cap.splits split_if_asm)
     apply (simp add:free_index_update_def)+
   apply (unfold reply_masters_mdb_def)
   apply (intro allI impI)
    apply (drule_tac x = ptr in spec)
    apply (drule_tac x = t in spec)
   apply (erule impE)
     apply (clarsimp split:cap.splits if_splits)
   apply (auto intro:conjI impI)
   done


lemma set_untyped_cap_as_full_valid_mdb:
  "\<lbrace>valid_mdb and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap c src
   \<lbrace>\<lambda>rv. valid_mdb\<rbrace>"
  apply (simp add:valid_mdb_def set_untyped_cap_as_full_def split del:if_splits)
  apply (rule hoare_pre)
  apply (wp set_cap_mdb_cte_at)
    apply (wps set_cap_rvk_cdt_ct_ms)
  apply wp
  apply clarsimp
  apply (intro conjI impI)
    apply (clarsimp simp:is_cap_simps free_index_update_def split:cap.splits)+
  apply (simp_all add:cte_wp_at_caps_of_state)
  unfolding fun_upd_def[symmetric]
  apply (simp_all add: untyped_mdb_update_free_index reply_mdb_update_free_index
    untyped_inc_update_free_index)
  apply (erule descendants_inc_minor)
   apply (clarsimp simp:cte_wp_at_caps_of_state swp_def)
  apply (clarsimp simp: free_index_update_def cap_range_def split:cap.splits)
  done


lemma free_index_update_simps[simp]:
  "free_index_update g (cap.UntypedCap ref sz f) = cap.UntypedCap ref sz (g f)"
   by (simp add:free_index_update_def)


lemma set_free_index_valid_mdb:
  "\<lbrace>\<lambda>s. valid_objs s \<and> valid_mdb s \<and> cte_wp_at (op = cap ) cref s \<and>
        (free_index_of cap \<le> idx \<and> is_untyped_cap cap \<and> idx \<le> 2^cap_bits cap)\<rbrace>
   set_cap (free_index_update (\<lambda>_. idx) cap) cref 
   \<lbrace>\<lambda>rv s'. valid_mdb s'\<rbrace>"
  apply (simp add:valid_mdb_def)
  apply (rule hoare_pre)
  apply (wp set_cap_mdb_cte_at)
  apply (wps set_cap_rvk_cdt_ct_ms)
  apply wp
  apply (clarsimp simp:cte_wp_at_caps_of_state is_cap_simps free_index_of_def 
    reply_master_revocable_def irq_revocable_def reply_mdb_def
    simp del:untyped_range.simps usable_untyped_range.simps)
  unfolding fun_upd_def[symmetric]
  apply (simp)
  apply (frule(1) caps_of_state_valid)
  proof(intro conjI impI)
  fix s bits f r
  assume mdb:"untyped_mdb (cdt s) (caps_of_state s)"
  assume cstate:"caps_of_state s cref = Some (cap.UntypedCap r bits f)" (is "?m cref = Some ?srccap")
  show "untyped_mdb (cdt s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
  apply (rule untyped_mdb_update_free_index
     [where capa = ?srccap and m = "caps_of_state s" and src = cref,
       unfolded free_index_update_def,simplified,THEN iffD2])
   apply (simp add:cstate mdb)+
  done
  assume inc: "untyped_inc (cdt s) (caps_of_state s)"
  have untyped_range_simp: "untyped_range (cap.UntypedCap r bits f) = untyped_range (cap.UntypedCap r bits idx)"
    by simp
  assume valid: "s \<turnstile> cap.UntypedCap r bits f"
  assume cmp: "f \<le> idx" "idx \<le> 2 ^ bits"
  have subset_range: "usable_untyped_range (cap.UntypedCap r bits idx) \<subseteq> usable_untyped_range (cap.UntypedCap r bits f)"
    using cmp valid
   apply (clarsimp simp:valid_cap_def cap_aligned_def)
   apply (rule word_plus_mono_right)
    apply (rule of_nat_mono_maybe_le[THEN iffD1])
     apply (subst word_bits_def[symmetric])
     apply (erule less_le_trans[OF _  power_increasing])
      apply simp
     apply simp
   apply (subst word_bits_def[symmetric])
   apply (erule le_less_trans)
   apply (erule less_le_trans[OF _ power_increasing])
    apply simp+
  apply (erule is_aligned_no_wrap')
  apply (rule word_of_nat_less)
  apply (simp add: word_bits_def)
  done

  note blah[simp del] = untyped_range.simps usable_untyped_range.simps
  show "untyped_inc (cdt s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
  using inc cstate
  apply (unfold untyped_inc_def)
   apply (intro allI impI)
   apply (drule_tac x = p in spec)
   apply (drule_tac x = p' in spec)
   apply (case_tac "p = cref")
    apply (simp)
    apply (case_tac "p' = cref")
     apply simp
    apply (simp add:untyped_range_simp)
    apply (intro conjI impI)
     apply (simp)
     apply (elim conjE)
     apply (drule disjoint_subset2[OF subset_range,rotated])
     apply simp+
    using subset_range
    apply clarsimp
  apply (case_tac "p' = cref")
   apply simp
   apply (intro conjI)
      apply (elim conjE)
      apply (thin_tac "P\<longrightarrow>Q" for P Q)+
      apply (simp add:untyped_range_simp)+
     apply (intro impI)
     apply (elim conjE | simp)+
     apply (drule disjoint_subset2[OF subset_range,rotated])
     apply simp
    apply (intro impI)
    apply (elim conjE | simp add:untyped_range_simp)+
   apply (intro impI)
   apply (elim conjE | simp add:untyped_range_simp)+
   using subset_range
   apply clarsimp+
  done
  assume "ut_revocable (is_original_cap s) (caps_of_state s)"
  thus "ut_revocable (is_original_cap s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
  using cstate
  by (fastforce simp:ut_revocable_def)
  assume "reply_caps_mdb (cdt s) (caps_of_state s)"
  thus "reply_caps_mdb (cdt s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
  using cstate
  apply (simp add:reply_caps_mdb_def del:split_paired_All split_paired_Ex)
  apply (intro allI impI conjI)
   apply (drule spec)+
   apply (erule(1) impE)
  apply (erule exE)
  apply (rule_tac x = ptr' in exI)
  apply simp+
  apply clarsimp
  done
  assume "reply_masters_mdb (cdt s) (caps_of_state s)"
  thus "reply_masters_mdb (cdt s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
   apply (simp add:reply_masters_mdb_def del:split_paired_All split_paired_Ex)
   apply (intro allI impI ballI)
   apply (erule exE)
   apply (elim allE impE)
    apply simp
   using cstate
   apply clarsimp
   done
  assume mdb:"mdb_cte_at (swp (cte_wp_at (op \<noteq> cap.NullCap)) s) (cdt s)"
  and desc_inc:"descendants_inc (cdt s) (caps_of_state s)"
  and cte:"caps_of_state s cref = Some (cap.UntypedCap r bits f)"
  show "descendants_inc (cdt s) (caps_of_state s(cref \<mapsto> cap.UntypedCap r bits idx))"
   using mdb cte
   apply (clarsimp simp:swp_def cte_wp_at_caps_of_state)
   apply (erule descendants_inc_minor[OF desc_inc])
   apply (clarsimp simp:cap_range_def untyped_range.simps)
   done
 qed


lemma descendants_inc_upd_nullcap:
  "\<lbrakk> mdb_cte_at (\<lambda>p. \<exists>c. cs p = Some c \<and> cap.NullCap \<noteq> c) m;
  descendants_inc m cs; 
  cs slot = Some cap.NullCap\<rbrakk>
  \<Longrightarrow> descendants_inc m (cs(slot \<mapsto> cap))"
  apply (simp add:descendants_inc_def descendants_of_def del:split_paired_All)
  apply (intro allI impI)
  apply (rule conjI)
   apply (intro allI impI)
   apply (drule spec)+
   apply (erule(1) impE)
   apply (drule tranclD2)
   apply (clarsimp simp:cdt_parent_rel_def is_cdt_parent_def)
   apply (drule(1) mdb_cte_atD)
   apply clarsimp
  apply (intro allI impI)
  apply (drule spec)+
  apply (erule(1) impE)
  apply (drule tranclD)
  apply (clarsimp simp:cdt_parent_rel_def is_cdt_parent_def)
  apply (drule(1) mdb_cte_atD)
  apply clarsimp
  done


lemma cap_aligned_free_index_update[simp]:
  "cap_aligned capa \<Longrightarrow> cap_aligned (capa\<lparr>free_index :=x\<rparr>)"
  apply (case_tac capa)
  apply (clarsimp simp: cap_aligned_def free_index_update_def)+
  done


lemma upd_commute:
  "src \<noteq> dest \<Longrightarrow> (m(dest \<mapsto> cap, src \<mapsto> capa))
  = (m(src \<mapsto> capa, dest \<mapsto> cap))"
  apply (rule ext)
  apply clarsimp
  done


lemma cap_class_free_index_upd[simp]:
  "cap_class (free_index_update f cap) = cap_class cap"
  by (simp add:free_index_update_def split:cap.splits)


(* FIXME: Move To CSpace_I *)
lemma cap_range_free_index_update[simp]:
  "cap_range (capa\<lparr>free_index:=x\<rparr>) = cap_range capa"
  by(auto simp:cap_range_def free_index_update_def split:cap.splits)

(* FIXME: Move To CSpace_I *)
lemma cap_range_free_index_update2[simp]:
  "cap_range (free_index_update f cap) = cap_range cap"
  by (auto simp:cap_range_def free_index_update_def split:cap.splits)

lemma cap_insert_mdb [wp]:
  "\<lbrace>valid_mdb and valid_cap cap and valid_objs and
    (\<lambda>s. cte_wp_at (is_derived (cdt s) src cap) src s) 
    and K (src \<noteq> dest) \<rbrace> 
    cap_insert cap src dest 
   \<lbrace>\<lambda>_. valid_mdb\<rbrace>"
  apply (simp add:valid_mdb_def)
  apply (wp cap_insert_mdb_cte_at)
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def update_cdt_def set_cdt_def bind_assoc)
  apply (wp set_cap_caps_of_state2 get_cap_wp|simp del: fun_upd_apply split del: split_if)+
  apply (clarsimp simp: cte_wp_at_caps_of_state split del: split_if)
  apply (subgoal_tac "mdb_insert_abs (cdt s) src dest")
   prefer 2
   apply (rule mdb_insert_abs.intro,simp+)
   apply (erule mdb_cte_at_cdt_null,simp)
   apply (rule mdb_cte_at_Null_descendants)
   apply (assumption)
   apply (simp add:mdb_cte_at_rewrite)
  apply (subgoal_tac "mdb_insert_abs_sib (cdt s) src dest")
   prefer 2
   apply (erule mdb_insert_abs_sib.intro)
  apply (fold revokable_def)
  apply (case_tac "should_be_parent_of capa (is_original_cap s src) cap (revokable capa cap)")
     apply simp
     apply (frule (4) mdb_insert_abs.untyped_mdb)
     apply (frule (4) mdb_insert_abs.reply_mdb)
     apply (simp)
     apply (rule conjI)
      apply (simp add: no_mloop_def mdb_insert_abs.parency)
      apply (intro allI impI conjI)
            apply (rule_tac m1 = "caps_of_state s(dest\<mapsto> cap)" 
              and src1 = src in iffD2[OF untyped_mdb_update_free_index,rotated,rotated])
              apply (simp add:fun_upd_twist)+
             apply (drule_tac cs' = "caps_of_state s(src \<mapsto> max_free_index_update capa)" in descendants_inc_minor)
               apply (clarsimp simp:cte_wp_at_caps_of_state swp_def)
              apply clarsimp
             apply (subst upd_commute)
              apply simp
             apply (erule(1) mdb_insert_abs.descendants_inc)
              apply simp
             apply (clarsimp dest!:is_derived_cap_class_range)
           apply (rule notI)
           apply (simp add: mdb_insert_abs.dest_no_parent_trancl)
          apply (erule mdb_insert_abs.untyped_inc_simple)
                 apply (rule_tac m = "caps_of_state s" and src = src in untyped_inc_update_free_index)
                   apply (simp add:fun_upd_twist)+
               apply (frule_tac p = src in caps_of_state_valid,assumption)
               apply (clarsimp simp:valid_cap_def)
              apply clarsimp+
             apply (clarsimp simp:is_cap_simps)+
           apply (simp add:is_derived_def)
          apply (clarsimp simp:is_cap_simps)
        apply (clarsimp simp:ut_revocable_def is_cap_simps revokable_def)
       apply (clarsimp simp: irq_revocable_def)
       apply (intro impI conjI)
        apply (clarsimp simp:is_cap_simps free_index_update_def)+
       apply (clarsimp simp: reply_master_revocable_def is_derived_def is_master_reply_cap_def)
     apply clarsimp
     apply (rule_tac m1 = "caps_of_state s(dest\<mapsto> cap)" 
        and src1 = src in reply_mdb_update_free_index[THEN iffD2])
     apply ((simp add:fun_upd_twist)+)[3]
   apply (simp add: no_mloop_def mdb_insert_abs.parency)
   apply (intro impI conjI allI)
        apply (erule(1) mdb_insert_abs.descendants_inc)
         apply simp
        apply (clarsimp dest!:is_derived_cap_class_range)
       apply (rule notI)
       apply (simp add: mdb_insert_abs.dest_no_parent_trancl)
      apply (frule_tac p = src in caps_of_state_valid,assumption)
      apply (erule mdb_insert_abs.untyped_inc)
          apply simp+
        apply (simp add:valid_cap_def)
       apply simp+
       apply (clarsimp simp:is_derived_def is_cap_simps cap_master_cap_simps dest!:cap_master_cap_eqDs)
     apply (clarsimp simp:ut_revocable_def is_cap_simps,simp add:revokable_def)
    apply (clarsimp simp: irq_revocable_def)
   apply (clarsimp simp: reply_master_revocable_def is_derived_def is_master_reply_cap_def)
   apply (clarsimp)
   apply (intro impI conjI allI)
                   apply (rule_tac m1 = "caps_of_state s(dest\<mapsto> cap)" 
                     and src1 = src in iffD2[OF untyped_mdb_update_free_index,rotated,rotated])
                     apply (frule mdb_insert_abs_sib.untyped_mdb_sib)
                         apply (simp add:fun_upd_twist)+
                  apply (drule_tac cs' = "caps_of_state s(src \<mapsto> max_free_index_update capa)" in descendants_inc_minor)
                    apply (clarsimp simp:cte_wp_at_caps_of_state swp_def)
                   apply clarsimp
                  apply (subst upd_commute)
                   apply simp
                  apply (erule(1) mdb_insert_abs_sib.descendants_inc)
                   apply simp
                  apply (clarsimp dest!:is_derived_cap_class_range)
                 apply (simp add: no_mloop_def)
                 apply (simp add: mdb_insert_abs_sib.parent_n_eq)
                 apply (simp add: mdb_insert_abs.dest_no_parent_trancl)
                apply (rule_tac m = "caps_of_state s(dest\<mapsto> cap)" and src = src in untyped_inc_update_free_index)
                  apply (simp add:fun_upd_twist)+
                apply (frule(3) mdb_insert_abs_sib.untyped_inc)
                apply (frule_tac p = src in caps_of_state_valid,assumption)
                apply (simp add:valid_cap_def)
               apply (simp add:valid_cap_def,
                 clarsimp simp:ut_revocable_def,case_tac src,
                 clarsimp elim!: allE impE,simp)
             apply (clarsimp simp:ut_revocable_def is_cap_simps revokable_def)
            apply (clarsimp simp: irq_revocable_def)
            apply (intro impI conjI)
             apply (clarsimp simp:is_cap_simps free_index_update_def)+
           apply (clarsimp simp: reply_master_revocable_def is_derived_def is_master_reply_cap_def)
          apply (rule_tac m1 = "caps_of_state s(dest\<mapsto> cap)" 
            and src1 = src in iffD2[OF reply_mdb_update_free_index,rotated,rotated])
            apply (frule mdb_insert_abs_sib.reply_mdb_sib,simp+)
             apply (clarsimp simp:ut_revocable_def,case_tac src,clarsimp elim!: allE impE,simp)
           apply (simp add:fun_upd_twist)+
          apply (frule mdb_insert_abs_sib.untyped_mdb_sib)
             apply (simp add:fun_upd_twist)+
         apply (erule(1) mdb_insert_abs_sib.descendants_inc)
          apply simp
         apply (clarsimp dest!: is_derived_cap_class_range)
        apply (simp add: no_mloop_def)
        apply (simp add: mdb_insert_abs_sib.parent_n_eq)
        apply (simp add: mdb_insert_abs.dest_no_parent_trancl)
       apply (frule(3) mdb_insert_abs_sib.untyped_inc)
         apply (simp add:valid_cap_def)
        apply (case_tac src,clarsimp simp:ut_revocable_def elim!:allE impE) 
     apply simp
    apply (clarsimp simp:ut_revocable_def is_cap_simps,simp add: revokable_def)
    apply (clarsimp simp: irq_revocable_def)
    apply (clarsimp simp: reply_master_revocable_def is_derived_def is_master_reply_cap_def)
    apply (frule mdb_insert_abs_sib.reply_mdb_sib,simp+)
       apply (clarsimp simp:reply_master_revocable_def,case_tac src,clarsimp elim!: allE impE)
     apply simp
  apply clarsimp
  done


lemma swp_cte_at_cdt_update [iff]:
  "swp cte_at (cdt_update f s) = swp cte_at s"
  by (simp add: swp_def)


lemma swp_cte_at_mdb_rev_update [iff]:
  "swp cte_at (is_original_cap_update f s) = swp cte_at s"
  by (simp add: swp_def)


lemma derived_not_Null [simp]:
  "\<not>is_derived m p c cap.NullCap"
  "\<not>is_derived m p cap.NullCap c"
  by (auto simp: is_derived_def cap_master_cap_simps dest!: cap_master_cap_eqDs)


lemma set_untyped_cap_as_full_impact:
  "\<lbrace>cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap c src 
   \<lbrace>\<lambda>r. cte_wp_at (op = (masked_as_full src_cap c)) src\<rbrace>"
  apply (simp only: set_untyped_cap_as_full_def)
  apply (rule hoare_pre)
  apply (wp set_cap_cte_wp_at)
  apply (auto simp:masked_as_full_def elim:cte_wp_at_weakenE split:if_splits)
done


lemma is_derived_masked_as_full[simp]:
  "is_derived (cdt a) src c (masked_as_full src_cap c) =
   is_derived (cdt a) src c src_cap"
  apply (case_tac c)
   apply (simp_all add:masked_as_full_def)
  apply (clarsimp simp:is_cap_simps split:if_splits)
  apply (simp add:is_derived_def cap_master_cap_simps is_cap_simps vs_cap_ref_def)
  done


lemma cap_range_maskedAsFull[simp]:
  "cap_range (masked_as_full src_cap cap) = cap_range src_cap"
  apply (clarsimp simp:masked_as_full_def is_cap_simps split:cap.splits if_splits)
done


lemma connect_eqv_singleE:
  assumes single:"\<And>p p'. ((p,p') \<in> m) = ((p,p')\<in> m')"
  shows "((p,p')\<in> m\<^sup>+) = ((p,p')\<in> m'\<^sup>+)"
  apply (rule iffI)
  apply (erule trancl_induct)
    apply (rule r_into_trancl)
      apply (clarsimp simp:single)
    apply (drule iffD1[OF single])
   apply simp
  apply (erule trancl_induct)
    apply (rule r_into_trancl)
      apply (clarsimp simp:single)
    apply (drule iffD2[OF single])
   apply simp
done

lemma connect_eqv_singleE':
  assumes single:"\<And>p p'. ((p,p') \<in> m) = ((p,p')\<in> m')"
  shows "((p,p')\<in> m\<^sup>*) = ((p,p')\<in> m'\<^sup>*)"
  apply (case_tac "p = p'")
    apply simp
  apply (rule iffI)
  apply (drule rtranclD)
    apply clarsimp
    apply (rule trancl_into_rtrancl)
    apply (simp add:connect_eqv_singleE[OF single])
  apply (drule rtranclD)
  apply clarsimp
  apply (rule trancl_into_rtrancl)
  apply (simp add:connect_eqv_singleE[OF single])
done

lemma identity_eq :"(op = x) = (\<lambda>c. c = x)"
  apply (rule ext)
  apply auto
  done


lemma forall_eq: "(\<forall>x. P x = Q x) \<Longrightarrow> (\<forall>x. P x) = (\<forall>b. Q b)"
  by auto


lemma ran_dom:"(\<forall>x\<in> ran m. P x) = (\<forall>y\<in> dom m. P (the (m y)))"
  by (auto simp:ran_def dom_def)

lemma dom_in:
  "(\<exists>x. c a = Some x) = (a\<in> dom c)"
  by auto

lemma same_region_as_masked_as_full[simp]:
  "same_region_as (masked_as_full src_cap c) = same_region_as src_cap"
  apply (rule ext)+
  apply (case_tac src_cap)
    apply (clarsimp simp:masked_as_full_def is_cap_simps free_index_update_def split:if_splits)+
done


lemma should_be_parent_of_masked_as_full[simp]:
  "should_be_parent_of (masked_as_full src_cap c) = should_be_parent_of src_cap"
  apply (rule ext)+
  apply (clarsimp simp:should_be_parent_of_def)
  apply (case_tac src_cap)
    apply (simp_all add:masked_as_full_def is_cap_simps free_index_update_def split:if_splits)
done


lemma cte_at_get_cap:
  "cte_at p s \<Longrightarrow> \<exists>c. (c, s) \<in> fst (get_cap p s)"
  by (clarsimp simp add: cte_wp_at_def)


lemma cte_at_get_cap_wp:
  "cte_at p s \<Longrightarrow> \<exists>c. (c, s) \<in> fst (get_cap p s) \<and> cte_wp_at (op = c) p s"
  by (clarsimp simp: cte_wp_at_def)


definition
  "s_d_swap p src dest \<equiv> 
    if p = src then dest 
    else if p = dest then src
    else p"


lemma s_d_swap_0 [simp]: "\<lbrakk> a \<noteq>0; b \<noteq> 0 \<rbrakk> \<Longrightarrow> s_d_swap 0 a b = 0"
  by (simp add: s_d_swap_def)


lemma s_d_swap_inv [simp]: "s_d_swap (s_d_swap p a b) a b = p"
  by (simp add: s_d_swap_def)


lemma s_d_fst [simp]:
  "s_d_swap b a b = a" by (simp add: s_d_swap_def)


lemma s_d_snd [simp]:
  "s_d_swap a a b = b" by (simp add: s_d_swap_def)


lemma s_d_swap_0_eq [simp]: 
  "\<lbrakk> src \<noteq> 0; dest \<noteq> 0 \<rbrakk> \<Longrightarrow> (s_d_swap c src dest = 0) = (c = 0)"
  by (simp add: s_d_swap_def)
 

lemma s_d_swap_other:
  "\<lbrakk> p \<noteq> src; p \<noteq> dest \<rbrakk> \<Longrightarrow> s_d_swap p src dest = p"
  by (simp add: s_d_swap_def)


lemma s_d_swap_eq_src [simp]:
  "(s_d_swap p src dest = src) = (p = dest)"
  by (auto simp: s_d_swap_def)


lemma s_d_swap_eq_dest:
  "src \<noteq> dest \<Longrightarrow> (s_d_swap p src dest = dest) = (p = src)"
  by (simp add: s_d_swap_def)


lemma s_d_swap_inj [simp]:
  "(s_d_swap p src dest = s_d_swap p' src dest) = (p = p')"
  by (simp add: s_d_swap_def)

locale mdb_swap_abs =
  fixes m src dest s s'

  fixes n'
  defines "n' \<equiv> \<lambda>n. if m n = Some src then Some dest 
                    else if m n = Some dest then Some src 
                    else m n"

  fixes n
  defines "n \<equiv> n' (src := n' dest, dest := n' src)"

  assumes valid_mdb: "valid_mdb s"

  assumes src: "cte_at src s"
  assumes dest: "cte_at dest s"
  assumes m: "m = cdt s"

  assumes neq [simp]: "src \<noteq> dest"


context mdb_swap_abs
begin
lemmas neq' [simp] = neq [symmetric]


lemma no_mloop:
  "no_mloop m"
  using valid_mdb
  by (simp add: valid_mdb_def m)


lemma no_loops [iff]:
  "m \<Turnstile> p \<rightarrow> p = False"
  using no_mloop 
  by (cases p) (clarsimp simp add: no_mloop_def)
  

lemma no_loops_d [iff]:
  "m \<Turnstile> p \<leadsto> p = False"
  by (fastforce dest: r_into_trancl)


lemma no_loops_m [iff]:
  "(m p = Some p) = False"
  apply clarsimp
  apply (fold cdt_parent_defs)
  apply simp
  done


definition 
  "s_d_swp p \<equiv> s_d_swap p src dest"


declare s_d_swp_def [simp]


lemma parency_m_n:
  assumes "m \<Turnstile> p \<rightarrow> p'"
  shows "n \<Turnstile> s_d_swp p \<rightarrow> s_d_swp p'" using assms
proof induct
  case (base y)
  thus ?case
    apply (simp add: s_d_swap_def)
    apply safe
          apply (rule r_into_trancl,
                 simp add: n_def n'_def cdt_parent_defs)+
    done
next
  case (step x y)
  thus ?case
    apply -
    apply (erule trancl_trans)
    apply (simp add: s_d_swap_def split: split_if_asm)
    apply safe
          apply (rule r_into_trancl,
                 simp add: n_def n'_def cdt_parent_defs)+
    done
qed


lemma parency_n_m:
  assumes "n \<Turnstile> p \<rightarrow> p'"
  shows "m \<Turnstile> s_d_swp p \<rightarrow> s_d_swp p'" using assms
proof induct
  case (base y)
  thus ?case
    apply (simp add: s_d_swap_def)
    apply safe
            apply (rule r_into_trancl|
                   simp add: n_def n'_def cdt_parent_defs split: split_if_asm)+
    done
next
  case (step x y)
  thus ?case
    apply -
    apply (erule trancl_trans)
    apply (simp add: s_d_swap_def split: split_if_asm)
    apply safe
            apply (simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
           apply (rule r_into_trancl,
                  simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
          apply (rule r_into_trancl,
                 simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
         apply (rule r_into_trancl,
                simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
        apply (simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
       apply (rule r_into_trancl,
              simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
      apply (rule r_into_trancl,
             simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
     apply (rule r_into_trancl,
            simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
    apply (rule r_into_trancl,
           simp add: n_def n'_def cdt_parent_defs split: split_if_asm)
    done
qed
      

lemmas parency_m_n' = 
  parency_m_n [where p="s_d_swp p" and p'="s_d_swp p'", simplified, folded s_d_swp_def]


lemma parency:
  "n \<Turnstile> p \<rightarrow> p' = m \<Turnstile> s_d_swp p \<rightarrow> s_d_swp p'"
  by (blast intro: parency_n_m parency_m_n')


lemma descendants:
  "descendants_of p n = 
  (let swap = \<lambda>S. S - {src,dest} \<union>  
                (if src \<in> S then {dest} else {}) \<union> 
                (if dest \<in> S then {src} else {}) in
  swap (descendants_of (s_d_swp p) m))"
  apply (simp add: Let_def parency descendants_of_def s_d_swap_def)
  apply auto
  done


end

(* NOTE: the following lemmata are currently not used: >>> *)
lemma same_object_as_commute:
  "same_object_as c' c = same_object_as c c'"
  apply (subgoal_tac "!c c'. same_object_as c' c --> same_object_as c c'")
   apply (rule iffI)
    apply (erule_tac x=c in allE, erule_tac x=c' in allE, simp)
   apply (erule_tac x=c' in allE, erule_tac x=c in allE, simp)
  by (auto simp:same_object_as_def bits_of_def  split: cap.splits arch_cap.splits)

lemma copy_of_commute:
  "copy_of c' c = copy_of c c'"
  apply (subgoal_tac "!c c'. copy_of c' c --> copy_of c c'")
   apply (rule iffI)
    apply (erule_tac x=c in allE, erule_tac x=c' in allE, simp)
   apply (erule_tac x=c' in allE, erule_tac x=c in allE, simp)
  apply clarsimp
  apply (clarsimp simp: copy_of_def is_reply_cap_def is_master_reply_cap_def
                      same_object_as_commute
                split: if_splits cap.splits)
  by (simp_all add: same_object_as_def split: cap.splits)

lemma weak_derived_commute:
  "weak_derived c' c = weak_derived c c'"
  by (auto simp: weak_derived_def copy_of_commute split: if_splits)
  (* <<< END unused lemmata *)

lemma weak_derived_valid_cap:
  "\<lbrakk> s \<turnstile> c; wellformed_cap c'; weak_derived c' c\<rbrakk> \<Longrightarrow> s \<turnstile> c'"
  apply (case_tac "c = c'", simp)
  apply (clarsimp simp: weak_derived_def)
  apply (clarsimp simp: copy_of_def split: split_if_asm)
  apply (auto simp: is_cap_simps same_object_as_def wellformed_cap_simps
                    valid_cap_def cap_aligned_def bits_of_def
                     aobj_ref_cases Let_def cap_asid_def
               split: cap.splits arch_cap.splits option.splits)
  done


lemma weak_derived_Null:
  "weak_derived c' c \<Longrightarrow> (c' = cap.NullCap) = (c = cap.NullCap)"
  apply (clarsimp simp: weak_derived_def)
  apply (erule disjE)
   apply (clarsimp simp: copy_of_def split: split_if_asm)
   apply (auto simp: is_cap_simps same_object_as_def
              split: cap.splits arch_cap.splits)[1]
  apply simp
  done


lemma weak_derived_tcb_cap_valid:
  "\<lbrakk> tcb_cap_valid cap p s; weak_derived cap cap' \<rbrakk> \<Longrightarrow> tcb_cap_valid cap' p s"
  apply (clarsimp simp add: tcb_cap_valid_def weak_derived_def
                            obj_at_def is_tcb
                     split: option.split)
  apply (clarsimp simp: st_tcb_def2)
  apply (erule disjE, simp_all add: copy_of_def split: split_if_asm)
    apply clarsimp
   apply (clarsimp simp: tcb_cap_cases_def split: split_if_asm)
   apply (auto simp: is_cap_simps same_object_as_def
                     valid_ipc_buffer_cap_def
              split: cap.split_asm arch_cap.split_asm
                     Structures_A.thread_state.split_asm)[3]
  apply clarsimp
  done


lemma weak_derived_refl [intro!, simp]:
  "weak_derived c c"
  by (simp add: weak_derived_def)


lemma ensure_no_children_descendants:
  "ensure_no_children p = 
  (\<lambda>s. if descendants_of p (cdt s) = {} 
   then returnOk () s
   else throwError ExceptionTypes_A.RevokeFirst s)"
  apply (rule ext)
  apply (simp add: ensure_no_children_def bindE_def liftE_def gets_def 
                   get_def bind_def return_def lift_def whenE_def)
  apply (rule conjI)
   apply (clarsimp simp: descendants_of_def cdt_parent_defs)
   apply fastforce
  apply (clarsimp simp: descendants_of_def cdt_parent_defs)
  apply (drule tranclD)
  apply clarsimp
  done
  


locale mdb_move_abs =
  fixes src dest and m :: cdt and s' s
  fixes m''
  defines "m'' \<equiv> \<lambda>r. if r = src then None else (m(dest := m src)) r"
  fixes m'
  defines "m' \<equiv> \<lambda>r. if  m'' r = Some src 
                    then Some dest
                    else (m(dest := m src, src := None)) r"

  assumes valid_mdb: "valid_mdb s"

  assumes dest_null: "cte_wp_at (op = cap.NullCap) dest s" 

  assumes m: "m = cdt s"

  assumes neq [simp]: "src \<noteq> dest"
begin

lemma dest_None:
  "m dest = None"
  using valid_mdb dest_null 
  unfolding valid_mdb_def mdb_cte_at_def
  apply (clarsimp simp: m [symmetric])
  apply (cases dest)
  apply (rule classical)
  apply (clarsimp simp: cte_wp_at_def)
  apply fastforce
  done
   

lemma desc_dest [intro?, simp]: 
  "dest \<notin> descendants_of x m"
  using dest_None
  apply (clarsimp simp add: descendants_of_def)
  apply (drule tranclD2)
  apply (clarsimp simp: cdt_parent_of_def)
  done
  

lemma dest_desc: 
  "descendants_of dest m = {}"
  using valid_mdb dest_null 
  unfolding valid_mdb_def mdb_cte_at_def 
  apply (clarsimp simp add: descendants_of_def m[symmetric])
  apply (drule tranclD)
  apply (clarsimp simp: cdt_parent_of_def)
  apply (cases dest)
  apply (clarsimp simp: cte_wp_at_def)
  apply fastforce
  done


lemmas neq' [simp] = neq [symmetric]


lemma no_mloop:
  "no_mloop m"
  using valid_mdb by (simp add: m valid_mdb_def)


lemma no_loops [iff]:
  "m \<Turnstile> p \<rightarrow> p = False"
  using no_mloop by (cases p) (clarsimp simp add: no_mloop_def)
  

lemma no_src_parent' [iff]:
  "m' \<Turnstile> src \<leadsto> p = False"
  by (simp add: m'_def m''_def cdt_parent_defs)


lemma no_src_parent_trans' [iff]:
  "m' \<Turnstile> src \<rightarrow> p = False"
  by (clarsimp dest!: tranclD)
  

lemma no_dest_parent_trans [iff]:
  "m \<Turnstile> dest \<rightarrow> p = False"
  using dest_desc
  by (fastforce simp add: descendants_of_def cdt_parent_defs)


lemma no_dest_parent [iff]:
  "m \<turnstile> dest cdt_parent_of p = False"
  by (fastforce dest: r_into_trancl)


lemma no_dest_parent_unfold [iff]:
  "(m x = Some dest) = False"
  using no_dest_parent 
  unfolding cdt_parent_defs
  by simp
  

lemma no_src_child [iff]:
  "m' \<turnstile> p cdt_parent_of src = False"
  by (simp add: cdt_parent_defs m'_def m''_def)


lemma no_src_child_trans [iff]:
  "m' \<turnstile> p cdt_parent_of\<^sup>+ src = False"
  by (clarsimp dest!: tranclD2)


lemma direct_src_loop_unfolded [iff]:
  "(m src = Some src) = False"
  by (fold cdt_parent_defs) (fastforce dest: r_into_trancl)


lemma mdb_cte_at:
  "mdb_cte_at (swp (cte_wp_at (op \<noteq> cap.NullCap)) s) m"
  using valid_mdb by (simp add: valid_mdb_def m)


lemma dest_no_child [iff]:
  "(m dest = Some x) = False"
  using dest_None by simp


lemma to_dest_direct [simp]:
  "m' \<Turnstile> x \<leadsto> dest = m \<Turnstile> x \<leadsto> src"
  by (clarsimp simp add: m'_def m''_def cdt_parent_defs)


lemma from_dest_direct [simp]:
  "m' \<Turnstile> dest \<leadsto> x = m \<Turnstile> src \<leadsto> x"
  by (clarsimp simp add: m'_def m''_def cdt_parent_defs)


lemma parent_m_m':
  assumes p_neq: "p \<noteq> dest" "p \<noteq> src"
  assumes px: "m \<Turnstile> p \<rightarrow> x" 
  shows "if x = src then m' \<Turnstile> p \<rightarrow> dest else m' \<Turnstile> p \<rightarrow> x" using px
proof induct
  case (base y)
  thus ?case using p_neq
    apply simp
    apply (rule conjI)
     apply (fastforce simp add: cdt_parent_defs m'_def m''_def)
    apply clarsimp
    apply (rule r_into_trancl)
    apply (clarsimp simp add: cdt_parent_defs m'_def m''_def)
    done
next
  case (step y z)
  thus ?case
    apply simp
    apply (rule conjI)
     apply (clarsimp split: split_if_asm)
     apply (fastforce intro: trancl_trans)
    apply (clarsimp split: split_if_asm)
     apply (fastforce intro: trancl_trans)
    apply (erule trancl_trans)
    apply (rule r_into_trancl)
    apply (simp add: cdt_parent_defs m'_def m''_def)
    apply clarsimp
    done
qed


lemma parent_m'_m:
  assumes p_neq: "p \<noteq> dest" "p \<noteq> src"
  assumes px: "m' \<Turnstile> p \<rightarrow> x" 
  shows "if x = dest then m \<Turnstile> p \<rightarrow> src else m \<Turnstile> p \<rightarrow> x" using px
proof induct
  case (base y)
  thus ?case using p_neq
    apply simp
    apply (rule conjI)
     apply (fastforce simp add: cdt_parent_defs m'_def m''_def)
    apply clarsimp
    apply (rule r_into_trancl)
    apply (clarsimp simp add: cdt_parent_defs m'_def m''_def split: split_if_asm)
    done
next
  case (step y z)
  thus ?case  
    apply simp
    apply (rule conjI)
     apply (clarsimp split: split_if_asm)
     apply (fastforce intro: trancl_trans)
    apply (clarsimp split: split_if_asm)
     apply (fastforce intro: trancl_trans)
    apply (erule trancl_trans)
    apply (rule r_into_trancl)
    apply (simp add: cdt_parent_defs m'_def m''_def split: split_if_asm)
    done
qed


lemma src_dest:
  assumes d: "m' \<Turnstile> dest \<rightarrow> x"
  shows "m \<Turnstile> src \<rightarrow> x" using d
proof induct
  case (base y)
  thus ?case 
    by (fastforce simp add: cdt_parent_defs m'_def m''_def split: split_if_asm)
next
  fix y z
  assume dest: "m' \<Turnstile> dest \<rightarrow> y"
  assume y: "m' \<Turnstile> y \<leadsto> z"
  assume src: "m \<Turnstile> src \<rightarrow> y"

  from src 
  have "y \<noteq> src" by clarsimp
  moreover {
    assume "m z = Some src"
    with src
    have "m \<Turnstile> src \<rightarrow> z" by (fastforce simp add: cdt_parent_defs)
  }
  moreover {
    assume "m src = Some y"
    hence "m \<Turnstile> y \<rightarrow> src"
      by (fastforce simp add: cdt_parent_defs)
    with src
    have "m \<Turnstile> src \<rightarrow> src" by (rule trancl_trans)
    hence False ..
    hence "m \<Turnstile> src \<rightarrow> z" ..
  }
  moreover {
    assume "m z = Some y"
    hence "m \<Turnstile> y \<rightarrow> z" by (fastforce simp add: cdt_parent_defs)
    with src
    have "m \<Turnstile> src \<rightarrow> z" by (rule trancl_trans)
  } 
  ultimately
  show "m \<Turnstile> src \<rightarrow> z" using y
    by (simp add: cdt_parent_defs m'_def m''_def split: split_if_asm)
qed
    

lemma dest_src:
  assumes "m \<Turnstile> src \<rightarrow> x" 
  shows "m' \<Turnstile> dest \<rightarrow> x" using assms
proof induct
  case (base y)
  thus ?case 
    by (fastforce simp add: cdt_parent_defs m'_def m''_def)
next
  case (step y z)
  thus ?case
    apply -
    apply (erule trancl_trans)
    apply (rule r_into_trancl)
    apply (simp (no_asm) add: cdt_parent_defs m'_def m''_def)
    apply (rule conjI)
     apply (clarsimp simp: cdt_parent_defs)
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (drule trancl_trans, erule r_into_trancl)
     apply simp
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (subgoal_tac "y = src")
      apply simp
     apply (clarsimp simp: cdt_parent_defs)
    apply (clarsimp simp: cdt_parent_defs)
    done
qed


lemma descendants:
  "descendants_of p m' =
  (if p = src 
   then {} 
   else if p = dest 
   then descendants_of src m
   else descendants_of p m - {src} \<union> 
        (if src \<in> descendants_of p m then {dest} else {}))" (is "?d = ?d'")
proof  (rule set_eqI)
  fix x
  show "(x \<in> ?d) = (x \<in> ?d')" 
    apply (simp add: descendants_of_def)
    apply safe
          apply (fastforce simp: parent_m'_m)
         apply (fastforce simp: parent_m_m')
        apply (fastforce simp: parent_m_m')
       apply (erule src_dest)
      apply (erule dest_src)
     apply (fastforce dest!: parent_m'_m split: split_if_asm)
    apply (fastforce simp: parent_m_m')
    done
qed


lemma parency:
  "(m' \<Turnstile> p \<rightarrow> p') =
  (p \<noteq> src \<and> p' \<noteq> src \<and>
   (if p = dest then m \<Turnstile> src \<rightarrow> p' 
    else m \<Turnstile> p \<rightarrow> p' \<or> (m \<Turnstile> p \<rightarrow> src \<and> p' = dest)))"
  using descendants [where p=p]
  apply (simp add: descendants_of_def cong: if_cong)
  apply (drule eqset_imp_iff [where x=p'])
  apply clarsimp
  apply fastforce
  done  
end

lemma copy_untyped1:
  "\<lbrakk> copy_of cap cap'; is_untyped_cap cap' \<rbrakk> \<Longrightarrow> cap' = cap"
  by (simp add: copy_of_def)


lemma copy_untyped2:
  "\<lbrakk> copy_of cap cap'; is_untyped_cap cap \<rbrakk> \<Longrightarrow> cap' = cap"
  apply (cases cap)
  apply (auto simp: copy_of_def same_object_as_def is_cap_simps 
              split: split_if_asm cap.splits arch_cap.splits)
  done


lemma copy_obj_refs:
  "copy_of cap cap' \<Longrightarrow> obj_refs cap' = obj_refs cap"
  apply (cases cap)
  apply (auto simp: copy_of_def same_object_as_def is_cap_simps
                    aobj_ref_cases
             split: split_if_asm cap.splits arch_cap.splits)
  done
 

lemma copy_of_Null [simp]:
  "\<not>copy_of cap.NullCap c"
  by (auto simp add: copy_of_def same_object_as_def is_cap_simps
              split: cap.splits arch_cap.splits)


lemma copy_of_Null2 [simp]:
  "\<not>copy_of c cap.NullCap"
  by (auto simp add: copy_of_def same_object_as_def is_cap_simps)


lemma weak_derived_cap_class[simp]: 
  "weak_derived cap src_cap \<Longrightarrow> cap_class cap = cap_class src_cap"
  apply (simp add:weak_derived_def)
  apply (auto simp:copy_of_def same_object_as_def cap_asid_base_def is_cap_simps
    split:if_splits cap.splits arch_cap.splits)
  done


lemma weak_derived_untyped_range:
  "weak_derived dcap cap \<Longrightarrow> untyped_range dcap = untyped_range cap"
  by (cases dcap, auto simp: is_cap_simps weak_derived_def copy_of_def 
                             same_object_as_def 
                       split: split_if_asm cap.splits arch_cap.splits)


lemma weak_derived_obj_refs:
  "weak_derived dcap cap \<Longrightarrow> obj_refs dcap = obj_refs cap"
  by (cases dcap, auto simp: is_cap_simps weak_derived_def copy_of_def 
                             same_object_as_def aobj_ref_cases
                       split: split_if_asm cap.splits arch_cap.splits)


lemma weak_derived_cap_range:
  "weak_derived dcap cap \<Longrightarrow> cap_range dcap = cap_range cap"
  by (simp add:cap_range_def weak_derived_untyped_range weak_derived_obj_refs)


context mdb_move_abs
begin
lemma descendants_inc:
  notes  split_paired_All[simp del]
  assumes dc: "descendants_inc m cs"
  assumes s: "cs src = Some src_cap"
  assumes d: "cs dest = Some cap.NullCap"
  assumes c: "weak_derived cap src_cap"
  shows "descendants_inc m' (cs (dest \<mapsto> cap, src \<mapsto> cap.NullCap))"
  using dc s d c
  apply (simp add: descendants_inc_def descendants split)
  apply (intro allI conjI)
   apply (intro impI allI)
   apply (drule spec)+
   apply (erule(1) impE)
   apply (simp add:weak_derived_cap_range)
  apply (simp add:descendants_of_def)
  apply (intro impI)
  apply (drule spec)+
  apply (erule(1) impE)
  apply (simp add:weak_derived_cap_range)
  done


lemma untyped_inc:
  assumes ut: "untyped_inc m cs"
  assumes s: "cs src = Some src_cap"
  assumes d: "cs dest = Some cap.NullCap"
  assumes c: "weak_derived cap src_cap"
  shows "untyped_inc m' (cs (dest \<mapsto> cap, src \<mapsto> cap.NullCap))"
proof -
  from c
  have "is_untyped_cap cap = is_untyped_cap src_cap"
       "untyped_range cap = untyped_range src_cap"
       "is_untyped_cap cap \<longrightarrow> usable_untyped_range cap = usable_untyped_range src_cap"
    by (auto simp: copy_of_def same_object_as_def is_cap_simps weak_derived_def
             split: split_if_asm cap.splits arch_cap.splits)
  with ut s d 
  show ?thesis
    apply (simp add: untyped_inc_def descendants del: split_paired_All split del: if_splits)
    apply (intro allI)
    apply (case_tac "p = src")
     apply (simp  del: split_paired_All split del: if_splits)
    apply (simp  del: split_paired_All split del: if_splits)   
    apply (case_tac "p = dest")
     apply (simp del: split_paired_All split del: if_splits)
    apply (case_tac "p' = src")
     apply (simp del: split_paired_All split del: if_splits)+
    apply (case_tac "p' = dest")
     apply (simp del:split_paired_All split del:if_splits)+
    apply (intro impI allI conjI)
         apply ((erule_tac x=src in allE,erule_tac x=p' in allE,simp)+)[5]
      apply (erule_tac x=src in allE)
      apply (erule_tac x=p' in allE)
      apply simp
      apply (intro conjI impI)
     apply (simp del:split_paired_All split del:if_splits)+
    apply (case_tac "p' = src")
     apply (simp del: split_paired_All split del: if_splits)+
    apply (case_tac "p' = dest")
     apply (simp del:split_paired_All split del:if_splits)+
    apply (intro impI allI conjI)
     apply (erule_tac x=p in allE,erule_tac x=src in allE)
     apply simp
     apply (intro conjI impI)
     apply (simp del:split_paired_All split del:if_splits)+
  apply (intro conjI impI allI)
  apply (erule_tac x=p in allE,erule_tac x=p' in allE)
  apply simp
  done
qed


end
lemma weak_derived_untyped2:
  "\<lbrakk> weak_derived cap cap'; is_untyped_cap cap \<rbrakk> \<Longrightarrow> cap' = cap"
  by (auto simp: weak_derived_def copy_untyped2)


lemma weak_derived_Null_eq [simp]:
  "(weak_derived cap.NullCap cap) = (cap = cap.NullCap)"
  by (auto simp: weak_derived_def)


lemma weak_derived_eq_Null [simp]:
  "(weak_derived cap cap.NullCap) = (cap = cap.NullCap)"
  by (auto simp: weak_derived_def)


lemma weak_derived_is_untyped:
  "weak_derived dcap cap \<Longrightarrow> is_untyped_cap dcap = is_untyped_cap cap"
  by (cases dcap, auto simp: is_cap_simps weak_derived_def copy_of_def 
                             same_object_as_def 
                       split: split_if_asm cap.splits arch_cap.splits)


lemma weak_derived_irq [simp]:
  "weak_derived cap.IRQControlCap cap = (cap = cap.IRQControlCap)"
  by (auto simp add: weak_derived_def copy_of_def same_object_as_def 
           split: cap.splits arch_cap.splits)


lemmas weak_derived_ranges = 
  weak_derived_is_untyped 
  weak_derived_untyped_range 
  weak_derived_obj_refs


lemma weak_derived_is_reply:
  "weak_derived dcap cap \<Longrightarrow> is_reply_cap dcap = is_reply_cap cap"
  by (auto simp: weak_derived_def copy_of_def
                 same_object_as_def is_cap_simps
         split: split_if_asm cap.split_asm arch_cap.split_asm)


lemma weak_derived_is_reply_master:
  "weak_derived dcap cap \<Longrightarrow> is_master_reply_cap dcap = is_master_reply_cap cap"
  by (auto simp: weak_derived_def copy_of_def
                 same_object_as_def is_cap_simps
         split: split_if_asm cap.split_asm arch_cap.split_asm)


lemma weak_derived_obj_ref_of:
  "weak_derived dcap cap \<Longrightarrow> obj_ref_of dcap = obj_ref_of cap"
  by (cases dcap, auto simp: is_cap_simps weak_derived_def copy_of_def 
                             same_object_as_def aobj_ref_cases
                       split: split_if_asm cap.splits arch_cap.splits)


lemma weak_derived_Reply:
  "weak_derived (cap.ReplyCap t m) c = (c = cap.ReplyCap t m)"
  "weak_derived c (cap.ReplyCap t m) = (c = cap.ReplyCap t m)"
  by (auto simp: weak_derived_def copy_of_def
                 same_object_as_def is_cap_simps
          split: split_if_asm cap.split_asm arch_cap.split_asm)


lemmas weak_derived_replies =
  weak_derived_is_reply
  weak_derived_is_reply_master
  weak_derived_obj_ref_of


lemma weak_derived_reply_eq:
  "\<lbrakk> weak_derived c c'; is_reply_cap c \<rbrakk> \<Longrightarrow> c = c'"
  "\<lbrakk> weak_derived c c'; is_reply_cap c' \<rbrakk> \<Longrightarrow> c = c'"
  by (auto simp: weak_derived_def copy_of_def
                 same_object_as_def is_cap_simps
          split: split_if_asm cap.split_asm arch_cap.split_asm)


context mdb_move_abs
begin
lemma reply_caps_mdb:
  assumes r: "reply_caps_mdb m cs"
  assumes s: "cs src = Some src_cap"
  assumes c: "weak_derived cap src_cap"
  shows "reply_caps_mdb
        (\<lambda>r. if (if r = src then None else (m(dest := m src)) r) = Some src
             then Some dest else (m(dest := m src, src := None)) r)
        (cs (dest \<mapsto> cap, src \<mapsto> cap.NullCap))"
  unfolding reply_caps_mdb_def
  using r c s
  apply (intro allI impI)
  apply (simp split: split_if_asm del: split_paired_Ex)
   apply (simp add: weak_derived_Reply del: split_paired_Ex)
   apply (unfold reply_caps_mdb_def)[1]
   apply (erule allE)+
   apply (erule(1) impE)
   apply (erule exEI)
   apply simp 
   apply blast
  apply (rule conjI)
   apply (unfold reply_caps_mdb_def)[1]
   apply (erule allE)+
   apply (erule(1) impE)
   apply (clarsimp simp: weak_derived_Reply)
  apply (rule impI)
  apply (unfold reply_caps_mdb_def)[1]
  apply (erule allE)+
  apply (erule(1) impE)
  apply (erule exEI)
  apply blast
  done


lemma reply_masters_mdb:
  assumes r: "reply_masters_mdb m cs"
  assumes s: "cs src = Some src_cap"
  assumes d: "cs dest = Some cap.NullCap"
  assumes c: "weak_derived cap src_cap"
  shows "reply_masters_mdb
        (\<lambda>r. if (if r = src then None else (m(dest := m src)) r) = Some src
             then Some dest else (m(dest := m src, src := None)) r)
        (cs (dest \<mapsto> cap, src \<mapsto> cap.NullCap))"
  unfolding reply_masters_mdb_def
  using r c s d
  apply (intro allI impI) 
  apply (subst mdb_move_abs.descendants, rule mdb_move_abs.intro)
      apply (rule valid_mdb)
     apply (rule dest_null)
    apply (rule m)
   apply (rule neq)
  apply (simp split: split_if_asm)
   apply (simp add: weak_derived_Reply)
   apply (unfold reply_masters_mdb_def)[1]
   apply (elim allE)
   apply (erule(1) impE, elim conjE, simp)
   apply (rule ballI, drule(1) bspec)
   apply fastforce
  apply (intro conjI)
   apply (rule impI)
   apply (unfold reply_masters_mdb_def)[1]
   apply (elim allE)
   apply (erule(1) impE, elim conjE)
   apply (clarsimp simp: weak_derived_Reply)
  apply (rule impI)
  apply (unfold reply_masters_mdb_def)[1]
  apply (elim allE)
  apply (erule(1) impE, elim conjE, simp)
  apply (rule ballI, drule(1) bspec)
  apply fastforce
  done


lemma reply_mdb:
  assumes r: "reply_mdb m cs"
  assumes s: "cs src = Some src_cap"
  assumes d: "cs dest = Some cap.NullCap"
  assumes c: "weak_derived cap src_cap"
  shows "reply_mdb
        (\<lambda>r. if (if r = src then None else (m(dest := m src)) r) = Some src
             then Some dest else (m(dest := m src, src := None)) r)
        (cs (dest \<mapsto> cap, src \<mapsto> cap.NullCap))"
  using r c s d unfolding reply_mdb_def
  by (simp add: reply_caps_mdb reply_masters_mdb)


end
declare is_master_reply_cap_NullCap [simp]


lemma cap_move_mdb [wp]:
  "\<lbrace>valid_mdb and cte_wp_at (op = cap.NullCap) dest and 
    cte_wp_at (\<lambda>c. weak_derived cap c \<and> c \<noteq> cap.NullCap) src\<rbrace> 
  cap_move cap src dest 
  \<lbrace>\<lambda>_. valid_mdb\<rbrace>"
  apply (simp add: cap_move_def set_cdt_def valid_mdb_def2
                   pred_conj_def cte_wp_at_caps_of_state)
  apply (wp update_cdt_cdt)
   apply simp
   apply (wp set_cap_caps_of_state2 | simp split del: split_if)+
  apply (clarsimp simp: mdb_cte_at_def fun_upd_def[symmetric]
              simp del: fun_upd_apply)
  apply (rule conjI)
   apply (cases src, cases dest)
   apply (subgoal_tac "cap.NullCap \<noteq> cap")
    apply (intro allI conjI)
     apply fastforce
    apply (clarsimp split del: split_if)
    apply (rule conjI)
     apply fastforce
    apply clarsimp
   apply fastforce
  apply (subgoal_tac "mdb_move_abs src dest (cdt s) s")
   prefer 2
   apply (rule mdb_move_abs.intro)
      apply (simp add: valid_mdb_def swp_def cte_wp_at_caps_of_state
                       mdb_cte_at_def)
     apply (simp add: cte_wp_at_caps_of_state)
    apply (rule refl)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (rule conjI)
   apply (simp add: untyped_mdb_def mdb_move_abs.descendants)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (rule conjI)
    apply clarsimp
    apply (rule conjI, clarsimp simp: is_cap_simps)
    apply (clarsimp simp: descendants_of_def)
    apply (drule tranclD)
    apply (clarsimp simp: cdt_parent_of_def mdb_cte_at_def)
    apply fastforce
   apply clarsimp
   apply (rule conjI)
    apply clarsimp
    apply (rule conjI, clarsimp simp: is_cap_simps)
    apply clarsimp 
    apply (drule (1) weak_derived_untyped2)
    apply (cases src)
    apply clarsimp
   apply clarsimp 
   apply (drule weak_derived_obj_refs)
   apply clarsimp
   apply (cases src)
   apply clarsimp
  apply (rule conjI)
   apply (erule(4) mdb_move_abs.descendants_inc)
  apply (rule conjI)
   apply (simp add: no_mloop_def mdb_move_abs.parency)
   apply (simp add: mdb_move_abs.desc_dest [unfolded descendants_of_def, simplified])
  apply (rule conjI)
   apply (erule (4) mdb_move_abs.untyped_inc)
  apply (rule conjI)
   apply (simp add: ut_revocable_def weak_derived_is_untyped del: split_paired_All)
  apply (rule conjI)
   apply (simp add: irq_revocable_def del: split_paired_All)
   apply fastforce
  apply (rule conjI)
   apply (simp add: reply_master_revocable_def del: split_paired_All)
   apply (drule_tac x=src in spec, drule_tac x=capa in spec)
   apply (intro impI)
   apply (simp add: weak_derived_is_reply_master)
  apply (erule (4) mdb_move_abs.reply_mdb)
  done


lemma cap_move_typ_at:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace> cap_move cap ptr ptr' \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  apply (simp add: cap_move_def set_cdt_def)
  apply (wp set_cap_typ_at | simp)+
  done


lemma set_cdt_pspace:
  "\<lbrace>valid_pspace\<rbrace> set_cdt m \<lbrace>\<lambda>_. valid_pspace\<rbrace>"
  apply (simp add: set_cdt_def)
  apply wp
  apply (auto intro: valid_pspace_eqI)
  done


lemma set_cdt_cur:
  "\<lbrace>cur_tcb\<rbrace> set_cdt m \<lbrace>\<lambda>_. cur_tcb\<rbrace>"
  apply (simp add: set_cdt_def)
  apply wp
  apply (simp add: cur_tcb_def)
  done


lemma set_cdt_cte_at:
  "\<lbrace>cte_at x\<rbrace> set_cdt m \<lbrace>\<lambda>_. cte_at x\<rbrace>"
  by (simp add: valid_cte_at_typ set_cdt_typ_at [where P="\<lambda>x. x"])


lemma set_cdt_valid_cap:
  "\<lbrace>valid_cap c\<rbrace> set_cdt m \<lbrace>\<lambda>_. valid_cap c\<rbrace>"
  by (rule set_cdt_inv) simp


lemma set_cdt_iflive[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> set_cdt m \<lbrace>\<lambda>_. if_live_then_nonz_cap\<rbrace>"
  by (simp add: set_cdt_def, wp, simp add: if_live_then_nonz_cap_def ex_nonz_cap_to_def)


lemma set_untyped_cap_as_full_cap_to:
  "\<lbrace>\<lambda>s. if_live_then_nonz_cap s \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. if_live_then_nonz_cap s\<rbrace>"
  apply (clarsimp simp:if_live_then_nonz_cap_def set_untyped_cap_as_full_def | rule conjI | wp hoare_allI)+
   apply (wp hoare_vcg_imp_lift set_cap_cap_to)
   apply clarsimp
    apply (elim allE impE)
    apply simp
   apply (simp add:cte_wp_at_caps_of_state)
  apply (clarsimp|wp)+
done


lemma set_free_index_valid_pspace:
  "\<lbrace>\<lambda>s. valid_pspace s \<and> cte_wp_at (op = cap) cref s \<and>
        (free_index_of cap \<le> idx \<and> is_untyped_cap cap \<and>idx \<le> 2^ cap_bits cap)\<rbrace>
   set_cap (free_index_update (\<lambda>_. idx) cap) cref  
   \<lbrace>\<lambda>rv s'. valid_pspace s'\<rbrace>"
  apply (clarsimp simp:valid_pspace_def)
  apply (wp set_cap_valid_objs update_cap_iflive set_cap_zombies')
       apply (clarsimp simp:cte_wp_at_caps_of_state is_cap_simps)+
  apply (frule(1) caps_of_state_valid)
  apply (clarsimp simp:valid_cap_def cap_aligned_def
    free_index_update_def)
  apply (intro conjI)
   apply (clarsimp simp: valid_untyped_def)
   apply (elim impE allE)
     apply assumption+
   apply (clarsimp simp: free_index_of_def)
   apply (erule disjoint_subset[rotated])
   apply clarsimp
   apply (rule word_plus_mono_right)
    apply (rule of_nat_mono_maybe_le[THEN iffD1])
      apply (subst word_bits_def[symmetric])
      apply (erule less_le_trans[OF _  power_increasing])
       apply simp
      apply simp
     apply (subst word_bits_def[symmetric])
     apply (erule le_less_trans)
     apply (erule less_le_trans[OF _ power_increasing])
      apply simp+
   apply (erule is_aligned_no_wrap')
   apply (rule word_of_nat_less)
   apply (simp add: word_bits_def)
  apply (clarsimp simp add: pred_tcb_at_def tcb_cap_valid_def obj_at_def is_tcb
                            valid_ipc_buffer_cap_def
                     split: option.split)
  apply (rule exI)
  apply (intro conjI)
   apply fastforce
  apply (drule caps_of_state_cteD)
  apply (clarsimp simp:cte_wp_at_cases)
  apply (erule(1) valid_objsE)
  apply (drule_tac m = "tcb_cap_cases" in ranI)
  apply (clarsimp simp:valid_obj_def valid_tcb_def)
  apply (drule(1) bspec)
  apply clarsimp
  done

lemma set_free_index_invs:
  "\<lbrace>\<lambda>s. (free_index_of cap \<le> idx \<and> is_untyped_cap cap \<and> idx \<le> 2^cap_bits cap) \<and>
        invs s \<and> cte_wp_at (op = cap ) cref s\<rbrace>
   set_cap (free_index_update (\<lambda>_. idx) cap) cref 
   \<lbrace>\<lambda>rv s'. invs s'\<rbrace>"
  apply (rule hoare_grab_asm)+
  apply (simp add:invs_def valid_state_def)
  apply (rule hoare_pre)
  apply (wp set_free_index_valid_pspace[where cap = cap] set_free_index_valid_mdb
    set_cap_idle update_cap_ifunsafe)
  apply (simp add:valid_irq_node_def)
  apply wps
  
  apply (wp hoare_vcg_all_lift set_cap_irq_handlers set_cap_arch_objs set_cap_valid_arch_caps
    set_cap_valid_global_objs set_cap_irq_handlers cap_table_at_lift_valid set_cap_typ_at )
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  apply (rule conjI,simp add:valid_pspace_def)
  apply (rule conjI,clarsimp simp:is_cap_simps)
  apply (rule conjI,rule ext,clarsimp simp: is_cap_simps)
  apply (clarsimp simp:is_cap_simps appropriate_cte_cap_def)
  apply (intro conjI)
       apply (clarsimp split:cap.splits)
      apply (drule(1) if_unsafe_then_capD[OF caps_of_state_cteD])
       apply clarsimp
      apply (simp add:ex_cte_cap_wp_to_def appropriate_cte_cap_def)
     apply (clarsimp dest!:valid_global_refsD2 simp:cap_range_def)
    apply (simp add:valid_irq_node_def)
   apply clarsimp
   apply (clarsimp simp:valid_irq_node_def)
   apply (clarsimp simp:no_cap_to_obj_with_diff_ref_def cte_wp_at_caps_of_state vs_cap_ref_def)
   apply (case_tac capa)
    apply (simp_all add:table_cap_ref_def)
    apply (rename_tac arch_cap)
    apply (case_tac arch_cap)
    apply simp_all
  apply (clarsimp simp:cap_refs_in_kernel_window_def
              valid_refs_def simp del:split_paired_All)
  apply (drule_tac x = cref in spec)
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  apply (drule_tac x = ref in orthD2[rotated])
   apply (simp add:cap_range_def)
  apply simp
  done

lemma set_untyped_cap_as_full_cap_zombies_final:
  "\<lbrace>zombies_final and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s.  zombies_final s\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def
    split:split_if_asm | rule conjI | wp set_cap_zombies )+
  apply (clarsimp simp:cte_wp_at_caps_of_state)
    apply (rule zombies_finalD2)
      apply (simp add:get_cap_caps_of_state)
      apply (rule sym,simp)
      apply (simp add:get_cap_caps_of_state)
      apply (rule sym,simp)
    apply simp+
  apply (clarsimp simp:is_cap_simps free_index_update_def)+
  apply wp
  apply simp
  done

(* FIXME: MOVE *)
lemma set_untyped_cap_as_full_valid_pspace:
  "\<lbrace>valid_pspace and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. valid_pspace s \<rbrace>"
  apply (clarsimp simp:valid_pspace_def)
    apply (clarsimp | wp set_untyped_cap_full_valid_objs
      set_untyped_cap_as_full_cap_to set_untyped_cap_as_full_cap_zombies_final )+
done


lemma set_untyped_cap_as_full_cte_wp_at_neg:
  "\<lbrace>\<lambda>s. (dest \<noteq> src \<and> \<not> (cte_wp_at P dest s) \<or>
         dest = src \<and> \<not> cte_wp_at (\<lambda>a. P (masked_as_full a cap)) src s) \<and>
        cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>ya s. \<not> cte_wp_at P dest s\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def | rule conjI |wp set_cap_cte_wp_at_neg)+
    apply (clarsimp simp:cte_wp_at_caps_of_state masked_as_full_def)+
  apply wp
  apply clarsimp
done


lemma cap_insert_valid_pspace:
  "\<lbrace>valid_pspace and cte_wp_at (op = cap.NullCap) dest
                 and valid_cap cap and tcb_cap_valid cap dest
      and (\<lambda>s. \<forall>r\<in>obj_refs cap. \<forall>p'. dest \<noteq> p' \<and> cte_wp_at (\<lambda>cap'. r \<in> obj_refs cap') p' s
                                    \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>_. valid_pspace\<rbrace>"
  unfolding cap_insert_def 
  apply (simp add: update_cdt_def)
  apply (wp new_cap_valid_pspace set_cdt_valid_pspace set_cdt_cte_at
    set_untyped_cap_as_full_cte_wp_at set_untyped_cap_as_full_valid_cap
    set_cdt_valid_cap hoare_drop_imps set_untyped_cap_as_full_tcb_cap_valid
    set_untyped_cap_as_full_valid_pspace | simp split del: split_if)+
      apply (wp hoare_vcg_ball_lift hoare_vcg_all_lift hoare_vcg_imp_lift)
       apply clarsimp
       apply (wp hoare_vcg_disj_lift set_untyped_cap_as_full_cte_wp_at_neg
         set_untyped_cap_as_full_cte_wp_at)
   apply (wp get_cap_wp)
  apply (intro allI impI conjI)
   apply (clarsimp simp:cte_wp_at_caps_of_state )+
  apply (rule ccontr)
    apply clarsimp
 apply (drule bspec)
   apply simp
 apply (drule_tac x = xa in spec,drule_tac x = xb in spec)
 apply (subgoal_tac "(xa,xb) = src")
  apply (clarsimp simp: masked_as_full_def if_distrib split:if_splits)
 apply clarsimp
done


lemma set_cdt_idle [wp]:
  "\<lbrace>valid_idle\<rbrace> set_cdt m \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  by (simp add: set_cdt_def, wp,
      auto simp: valid_idle_def pred_tcb_at_def)

lemma global_refs_update_more[simp]:
  "global_refs (exst_update f s) = global_refs s"
  by (simp add: global_refs_def)


crunch refs [wp]: cap_insert "\<lambda>s. P (global_refs s)"
  (wp: crunch_wps)


crunch arch [wp]: cap_insert "\<lambda>s. P (arch_state s)"
  (wp: crunch_wps)


crunch it [wp]: cap_insert "\<lambda>s. P (idle_thread s)"
  (wp: crunch_wps)


lemmas cap_insert_typ_ats [wp] = abs_typ_at_lifts [OF cap_insert_typ_at]


lemma cap_insert_idle [wp]:
  "\<lbrace>valid_idle\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>_. valid_idle\<rbrace>"
  by (rule valid_idle_lift) wp


crunch reply[wp]: set_cdt "valid_reply_caps"


lemma set_untyped_cap_as_full_has_reply_cap:
  "\<lbrace>\<lambda>s. (has_reply_cap t s) \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. (has_reply_cap t s)\<rbrace>"
  apply (clarsimp simp:has_reply_cap_def)
  apply (wp hoare_ex_wp)
    apply (wp set_untyped_cap_as_full_cte_wp_at)
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  apply (rule_tac x = a in exI)
  apply (rule_tac x = b in exI)
  apply clarsimp
  done


lemma set_untyped_cap_as_full_has_reply_cap_neg:
  "\<lbrace>\<lambda>s. \<not> (has_reply_cap t s) \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. \<not> (has_reply_cap t s)\<rbrace>"
  apply (clarsimp simp:has_reply_cap_def)
  apply (wp hoare_vcg_all_lift)
    apply (wp set_untyped_cap_as_full_cte_wp_at_neg)
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  apply (drule_tac x = x in spec)
  apply (drule_tac x = xa in spec)
  apply (clarsimp simp:masked_as_full_def free_index_update_def is_cap_simps split:cap.splits if_splits)
  done


lemma caps_of_state_cte_wp_at_neq:
  "(caps_of_state s slot \<noteq> Some capa) = (\<not> cte_wp_at (op = capa) slot s)" 
  by (clarsimp simp:cte_wp_at_caps_of_state)


lemma set_untyped_cap_as_full_unique_reply_caps:
  "\<lbrace>\<lambda>s. unique_reply_caps (caps_of_state s) \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>rv s. unique_reply_caps (caps_of_state s)\<rbrace>"
  apply (simp add:unique_reply_caps_def )
     apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift)
    apply (clarsimp simp:caps_of_state_cte_wp_at_neq)
   apply (wp set_untyped_cap_as_full_cte_wp_at_neg)
    apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift)
    apply (clarsimp simp:caps_of_state_cte_wp_at_neq)
  apply (wp set_untyped_cap_as_full_cte_wp_at_neg)
  apply clarsimp
    apply (clarsimp simp:cte_wp_at_caps_of_state)
    apply (drule_tac x = x in spec,drule_tac x = xa in spec)
    apply (drule_tac x = xb in spec,drule_tac x = xc in spec)
  apply (case_tac "(x,xa) = src")
    apply simp
    apply (erule disjE)
    apply (clarsimp simp:masked_as_full_def if_distrib split:if_splits)
    apply (clarsimp simp:is_cap_simps masked_as_full_def free_index_update_def
        split:if_splits)
  apply clarsimp
  apply (case_tac "(xb,xc) = src")
    apply (clarsimp simp:is_cap_simps masked_as_full_def free_index_update_def
        split:if_splits)
  apply clarsimp
done


lemma set_untyped_cap_as_full_valid_reply_masters:
  "\<lbrace>\<lambda>s. valid_reply_masters s \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. valid_reply_masters s \<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
    apply (intro conjI impI)
    apply wp
    apply (clarsimp simp: cte_wp_at_caps_of_state free_index_update_def
      split:cap.splits)
  apply wp
  apply clarsimp
done


crunch global_refs[wp]: set_untyped_cap_as_full "\<lambda>s. P (global_refs s)" 


lemma set_untyped_cap_as_full_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>r. valid_global_refs\<rbrace>"
  apply (simp add:valid_global_refs_def valid_refs_def)
  apply (wp hoare_vcg_all_lift set_untyped_cap_as_full_cte_wp_at_neg| wps)+
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  done


lemma cap_insert_reply [wp]:
  "\<lbrace>valid_reply_caps and cte_at dest and
      (\<lambda>s. \<forall>t. cap = cap.ReplyCap t False \<longrightarrow>
           st_tcb_at awaiting_reply t s \<and> \<not> has_reply_cap t s)\<rbrace>
   cap_insert cap src dest \<lbrace>\<lambda>_. valid_reply_caps\<rbrace>"
  apply (simp add: cap_insert_def update_cdt_def)
  apply (wp
         | simp split del: split_if
         | rule hoare_drop_imp
         | clarsimp simp: valid_reply_caps_def)+
  apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift set_untyped_cap_as_full_has_reply_cap_neg
    set_untyped_cap_as_full_unique_reply_caps set_untyped_cap_as_full_cte_wp_at get_cap_wp)
  apply (clarsimp simp:cte_wp_at_caps_of_state valid_reply_caps_def)+
done


crunch reply_masters[wp]: set_cdt "valid_reply_masters"


lemma cap_insert_reply_masters [wp]:
  "\<lbrace>valid_reply_masters and cte_at dest and K (\<not> is_master_reply_cap cap) \<rbrace>
   cap_insert cap src dest \<lbrace>\<lambda>_. valid_reply_masters\<rbrace>"
  apply (simp add: cap_insert_def update_cdt_def)
  apply (wp hoare_drop_imp set_untyped_cap_as_full_valid_reply_masters
      set_untyped_cap_as_full_cte_wp_at get_cap_wp
    | simp add: is_cap_simps split del: split_if)+
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  done


lemma cap_insert_valid_arch [wp]:
  "\<lbrace>valid_arch_state\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>_. valid_arch_state\<rbrace>" 
  by (rule valid_arch_state_lift) wp


crunch caps [wp]: update_cdt "\<lambda>s. P (caps_of_state s)"


crunch irq_node [wp]: update_cdt "\<lambda>s. P (interrupt_irq_node s)"


lemma update_cdt_global [wp]:
  "\<lbrace>valid_global_refs\<rbrace> update_cdt m \<lbrace>\<lambda>_. valid_global_refs\<rbrace>"
  by (rule valid_global_refs_cte_lift) wp


lemma cap_insert_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs and (\<lambda>s. cte_wp_at (\<lambda>scap. cap_range cap \<subseteq> cap_range scap) src s)\<rbrace> 
  cap_insert cap src dest 
  \<lbrace>\<lambda>_. valid_global_refs\<rbrace>"
  apply (simp add: cap_insert_def)
  apply (rule hoare_pre)
   apply (wp get_cap_wp|simp split del: split_if)+
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (simp add: valid_global_refs_def valid_refs_def2)
  apply (drule bspec, blast intro: ranI)
  apply blast
  done


crunch irq_node[wp]: cap_insert "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps)

crunch arch_objs [wp]: cap_insert "valid_arch_objs"
  (wp: crunch_wps simp: crunch_simps)

crunch arch_caps[wp]: update_cdt "valid_arch_caps"


lemma is_derived_cap_asid:
  "is_derived m p cap cap' \<Longrightarrow> is_pt_cap cap' \<or> is_pd_cap cap' \<Longrightarrow> cap_asid cap = cap_asid cap'"
  by (clarsimp simp: is_derived_def)


lemma is_derived_is_pt_pd:
  "is_derived m p cap cap' \<Longrightarrow> (is_pt_cap cap = is_pt_cap cap') \<and> (is_pd_cap cap = is_pd_cap cap')"
  apply (clarsimp simp: is_derived_def split: split_if_asm)
  apply (clarsimp simp: cap_master_cap_def is_pt_cap_def is_pd_cap_def
    split: cap.splits arch_cap.splits)+
  done


lemma is_derived_obj_refs:
  "is_derived m p cap cap' \<Longrightarrow> obj_refs cap = obj_refs cap'"
  apply (clarsimp simp: is_derived_def is_cap_simps cap_master_cap_simps
    split: split_if_asm dest!:cap_master_cap_eqDs)
  apply (clarsimp simp: cap_master_cap_def)
  apply (auto split: cap.split_asm arch_cap.split_asm)
  done


lemma is_derived_cap_asid_issues:
  "is_derived m p cap cap'
      \<Longrightarrow> ((is_pt_cap cap \<or> is_pd_cap cap) \<longrightarrow> cap_asid cap \<noteq> None)
             \<and> (is_pg_cap cap \<or> (vs_cap_ref cap = vs_cap_ref cap'))"
  apply (frule is_derived_is_pt_pd)
  apply (clarsimp simp: is_derived_def is_cap_simps split: split_if_asm simp del: imp_disjL)
  apply auto
  done


lemma is_pt_pd_Null[simp]:
  "\<not> is_pt_cap cap.NullCap \<and> \<not> is_pd_cap cap.NullCap"
  by (simp add: is_pt_cap_def is_pd_cap_def)


lemma fun_upd_Some:
  "ms p = Some k \<Longrightarrow> (ms(a \<mapsto> b)) p = Some (if a = p then b else k)"
  by auto


lemma fun_upd_Some_rev:
  "\<lbrakk>ms a = Some k; (ms(a \<mapsto> b)) p = Some cap\<rbrakk>
   \<Longrightarrow> ms p = Some (if a = p then k else cap)"
  by auto


lemma unique_table_refs_upd_eqD: 
  "\<lbrakk>ms a = Some b; obj_refs b = obj_refs b'; table_cap_ref b = table_cap_ref b'\<rbrakk>
   \<Longrightarrow> unique_table_refs (ms (a \<mapsto> b')) = unique_table_refs (ms)"
  unfolding unique_table_refs_def
  apply (rule iffI)
   apply (intro allI impI)
   apply (case_tac "p=p'")
    apply simp
   apply (case_tac "a=p")
    apply (erule_tac x=p in allE)
    apply (erule_tac x=p' in allE)
    apply (erule_tac x=b' in allE)
    apply simp 
   apply (case_tac "a=p'")
   apply (erule_tac x=p in allE)
   apply (erule_tac x=p' in allE)
   apply (erule_tac x=cap in allE)
   apply simp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply (erule_tac x=cap in allE)
  apply simp
  apply (intro allI impI)
  apply (case_tac "p=p'")
   apply (thin_tac " \<forall>p. P p" for P)
   apply simp
  apply (case_tac "a=p")
   apply (erule_tac x=p in allE)
   apply (erule_tac x=p' in allE)
   apply (erule_tac x=b in allE)
   apply simp 
  apply (case_tac "a=p'")
   apply (erule_tac x=p in allE)
   apply (erule_tac x=p' in allE)
   apply (erule_tac x=cap in allE)
   apply simp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply (erule_tac x=cap in allE)
  apply simp
  done


lemma unique_table_caps_upd_eqD: 
  "\<lbrakk>ms a = Some b; cap_asid b = cap_asid b'; obj_refs b = obj_refs b';
    is_pd_cap b = is_pd_cap b'; is_pt_cap b = is_pt_cap b'\<rbrakk>
   \<Longrightarrow> unique_table_caps (ms (a \<mapsto> b')) = unique_table_caps (ms)"
  unfolding unique_table_caps_def
  apply (rule iffI)
  apply (intro allI impI,elim allE)
    apply (erule impE)
    apply (rule_tac p = p in fun_upd_Some)
    apply assumption
      apply (erule impE)
      apply (rule_tac p = p' in fun_upd_Some)
      apply simp
    apply (simp add: if_distrib split:if_splits)
  apply (intro allI impI,elim allE)
    apply (erule impE)
    apply (rule_tac p = p in fun_upd_Some_rev)
      apply simp+
  apply (erule impE)
    apply (rule_tac p = p' in fun_upd_Some_rev)
    apply simp+
  apply (simp add: if_distrib split:if_splits)
  done


lemma set_untyped_cap_as_full_valid_arch_caps:
  "\<lbrace>valid_arch_caps and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>ya. valid_arch_caps\<rbrace>"
  apply (clarsimp simp:valid_arch_caps_def set_untyped_cap_as_full_def)
  apply (intro conjI impI)
    apply (wp set_cap_valid_vs_lookup set_cap_valid_table_caps)
    apply (clarsimp simp del:fun_upd_apply simp:cte_wp_at_caps_of_state)
    apply (subst unique_table_refs_upd_eqD)
         apply ((simp add: is_cap_simps table_cap_ref_def)+)
      apply clarsimp
    apply (subst unique_table_caps_upd_eqD)
      apply simp+
    apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)+
  apply wp
  apply clarsimp
  done


lemma set_untyped_cap_as_full_is_final_cap':
  "\<lbrace>is_final_cap' cap' and cte_wp_at (op = src_cap) src\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. is_final_cap' cap' s\<rbrace>"
   apply (simp add:set_untyped_cap_as_full_def)
   apply (intro conjI impI)
     apply (wp set_cap_final_cap_at)
     apply (clarsimp simp:cte_wp_at_caps_of_state)
   apply wp
   apply simp
   done


lemma P_bool_lift':
  "\<lbrakk>\<lbrace>Q and Q'\<rbrace> f \<lbrace>\<lambda>r. Q\<rbrace>; \<lbrace>(\<lambda>s. \<not> Q s) and Q'\<rbrace> f \<lbrace>\<lambda>r s. \<not> Q s\<rbrace>\<rbrakk>
   \<Longrightarrow> \<lbrace>\<lambda>s. P (Q s) \<and> Q' s\<rbrace> f \<lbrace>\<lambda>r s. P (Q s)\<rbrace>"
  apply (clarsimp simp:valid_def)
  apply (elim allE)
  apply (case_tac "Q s")
    apply fastforce+
  done


lemma set_untyped_cap_as_full_is_final_cap'_neg:
  "\<lbrace>\<lambda>s. \<not> is_final_cap' cap' s \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. \<not> is_final_cap' cap' s\<rbrace>"
  apply (rule hoare_pre)
  apply (simp add:is_final_cap'_def2)
     apply (wp hoare_vcg_all_lift hoare_vcg_ex_lift)
       apply (rule_tac Q = "cte_wp_at Q slot" 
         and Q'="cte_wp_at (op = src_cap) src" for Q slot in P_bool_lift' )
       apply (wp set_untyped_cap_as_full_cte_wp_at)
       apply clarsimp
     apply (wp set_untyped_cap_as_full_cte_wp_at_neg)
     apply (clarsimp simp:cte_wp_at_caps_of_state masked_as_full_def)
   apply (clarsimp simp:is_final_cap'_def2)
  done


lemma set_untyped_cap_as_full_not_final_not_pg_cap:
  "\<lbrace>\<lambda>s. (\<exists>a b. (a, b) \<noteq> dest \<and> \<not> is_pg_cap cap' 
            \<and> cte_wp_at (\<lambda>cap. obj_irq_refs cap = obj_irq_refs cap' \<and> \<not> is_pg_cap cap) (a, b) s)
      \<and> cte_wp_at (op = src_cap) src s\<rbrace>
  set_untyped_cap_as_full src_cap cap src 
  \<lbrace>\<lambda>_ s.(\<exists>a b. (a, b) \<noteq> dest \<and> \<not> is_pg_cap cap' 
            \<and> cte_wp_at (\<lambda>cap. obj_irq_refs cap = obj_irq_refs cap' \<and> \<not> is_pg_cap cap) (a, b) s)\<rbrace>"
  apply (rule hoare_pre)
  apply (wp hoare_vcg_ex_lift)
   apply (rule_tac Q = "cte_wp_at Q slot"
               and Q'="cte_wp_at (op = src_cap) src" for Q slot in P_bool_lift' )
    apply (wp set_untyped_cap_as_full_cte_wp_at)
    apply (auto simp: cte_wp_at_caps_of_state is_cap_simps masked_as_full_def cap_bits_untyped_def)[1]
   apply (wp set_untyped_cap_as_full_cte_wp_at_neg)
   apply (auto simp: cte_wp_at_caps_of_state is_cap_simps masked_as_full_def cap_bits_untyped_def)
  done


lemma set_untyped_cap_as_full_access[wp]:
  "\<lbrace>(\<lambda>s. P (vs_lookup s))\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>r s. P (vs_lookup s)\<rbrace>"
  by (clarsimp simp:set_untyped_cap_as_full_def, wp)+


lemma set_untyped_cap_as_full_vs_lookup_pages[wp]:
  "\<lbrace>(\<lambda>s. P (vs_lookup_pages s))\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>r s. P (vs_lookup_pages s)\<rbrace>"
  by (clarsimp simp:set_untyped_cap_as_full_def, wp)+


lemma set_untyped_cap_as_full[wp]:
  "\<lbrace>\<lambda>s. no_cap_to_obj_with_diff_ref a b s \<and> cte_wp_at (op = src_cap) src s\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. no_cap_to_obj_with_diff_ref a b s\<rbrace>"
  apply (clarsimp simp:no_cap_to_obj_with_diff_ref_def)
  apply (wp hoare_vcg_ball_lift set_untyped_cap_as_full_cte_wp_at_neg)
  apply (clarsimp simp:cte_wp_at_caps_of_state)
  apply (drule_tac x=src in bspec, simp)
  apply (erule_tac x=src_cap in allE)
  apply (auto simp: table_cap_ref_def masked_as_full_def 
             split: Structures_A.cap.splits arch_cap.splits option.splits 
                    vmpage_size.splits)
  done


lemma set_untyped_cap_as_full_obj_at_impossible:
  "\<lbrace>\<lambda>s. P (obj_at P' p s) \<and> (\<forall>ko. P' ko \<longrightarrow> caps_of ko = {})\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>rv s. P (obj_at P' p s)\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (intro conjI impI)
  apply (wp set_cap_obj_at_impossible)
    apply clarsimp
  done


lemma caps_of_state_cteD':
  "(caps_of_state m p = Some x \<and> P x) = cte_wp_at (op = x and P) p m"
  by (clarsimp simp:cte_wp_at_caps_of_state)


lemma disj_subst: "(\<not> A \<longrightarrow> B) \<Longrightarrow> A \<or> B" by auto


(* FIXME: move up to where the vs_lookup one is *)
lemma set_untyped_cap_as_full_access2[wp]:
  "\<lbrace>(\<lambda>s. P (vs_lookup_pages s))\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>r s. P (vs_lookup_pages s)\<rbrace>"
  by (clarsimp simp:set_untyped_cap_as_full_def, wp)+


lemma is_derived_is_cap:
  "is_derived m p cap cap' \<Longrightarrow> 
    (is_pg_cap cap = is_pg_cap cap')
  \<and> (is_pt_cap cap = is_pt_cap cap')
  \<and> (is_pd_cap cap = is_pd_cap cap')
  \<and> (is_ep_cap cap = is_ep_cap cap')
  \<and> (is_aep_cap cap = is_aep_cap cap')
  \<and> (is_cnode_cap cap = is_cnode_cap cap')
  \<and> (is_thread_cap cap = is_thread_cap cap')
  \<and> (is_zombie cap = is_zombie cap')
  \<and> (is_arch_cap cap = is_arch_cap cap')"
  apply (clarsimp simp: is_derived_def split: split_if_asm)
  apply (clarsimp simp: cap_master_cap_def is_cap_simps
    split: cap.splits arch_cap.splits)+
  done


(* FIXME: move to CSpace_I near lemma vs_lookup1_tcb_update *)
lemma vs_lookup_pages1_tcb_update:
  "kheap s p = Some (TCB t) \<Longrightarrow>
   vs_lookup_pages1 (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = vs_lookup_pages1 s"
  by (clarsimp simp: vs_lookup_pages1_def obj_at_def vs_refs_pages_def
             intro!: set_eqI)


(* FIXME: move to CSpace_I near lemma vs_lookup_tcb_update *)
lemma vs_lookup_pages_tcb_update:
  "kheap s p = Some (TCB t) \<Longrightarrow>
   vs_lookup_pages (s\<lparr>kheap := kheap s(p \<mapsto> TCB t')\<rparr>) = vs_lookup_pages s"
  by (clarsimp simp add: vs_lookup_pages_def vs_lookup_pages1_tcb_update)


(* FIXME: move to CSpace_I near lemma vs_lookup1_cnode_update *)
lemma vs_lookup_pages1_cnode_update:
  "kheap s p = Some (CNode n cs) \<Longrightarrow>
   vs_lookup_pages1 (s\<lparr>kheap := kheap s(p \<mapsto> CNode m cs')\<rparr>) =
   vs_lookup_pages1 s"
  by (clarsimp simp: vs_lookup_pages1_def obj_at_def vs_refs_pages_def
             intro!: set_eqI)


(* FIXME: move to CSpace_I near lemma vs_lookup_cnode_update *)
lemma vs_lookup_pages_cnode_update:
  "kheap s p = Some (CNode n cs) \<Longrightarrow>
   vs_lookup_pages (s\<lparr>kheap := kheap s(p \<mapsto> CNode n cs')\<rparr>) = vs_lookup_pages s"
  by (clarsimp simp: vs_lookup_pages_def
              dest!: vs_lookup_pages1_cnode_update[where m=n and cs'=cs'])


lemma set_untyped_cap_as_full_not_reachable_pg_cap[wp]:
  "\<lbrace>\<lambda>s. \<not> reachable_pg_cap cap' s\<rbrace>
   set_untyped_cap_as_full src_cap cap src
   \<lbrace>\<lambda>rv s. \<not> reachable_pg_cap cap' s\<rbrace>"
  apply (clarsimp simp: set_untyped_cap_as_full_def set_cap_def split_def
                        set_object_def)
  apply (wp get_object_wp | wpc)+
  apply (clarsimp simp: obj_at_def simp del: fun_upd_apply)
  apply (auto simp: obj_at_def reachable_pg_cap_def is_cap_simps
                    vs_lookup_pages_cnode_update vs_lookup_pages_tcb_update)
  done


(* FIXME: move from Finalise_R *)
lemma vs_cap_ref_to_table_cap_ref:
  "\<not> is_pg_cap cap \<Longrightarrow> vs_cap_ref cap = table_cap_ref cap"
  by (simp add: is_pg_cap_def table_cap_ref_def vs_cap_ref_simps
         split: cap.splits arch_cap.splits)


lemma cap_master_cap_pg_cap: 
 "\<lbrakk>cap_master_cap cap = cap_master_cap capa\<rbrakk>
  \<Longrightarrow> is_pg_cap cap = is_pg_cap capa"
  by (clarsimp simp:cap_master_cap_def is_cap_simps 
    split:cap.splits arch_cap.splits dest!:cap_master_cap_eqDs)


lemma table_cap_ref_eq_rewrite:
  "\<lbrakk>cap_master_cap cap = cap_master_cap capa;(is_pg_cap cap \<or> vs_cap_ref cap = vs_cap_ref capa)\<rbrakk>
   \<Longrightarrow> table_cap_ref cap = table_cap_ref capa"
  apply (frule cap_master_cap_pg_cap)
  apply (case_tac "is_pg_cap cap")
    apply (clarsimp simp:is_cap_simps table_cap_ref_def vs_cap_ref_to_table_cap_ref cap_master_cap_pg_cap)+
  done


lemma derived_cap_master_cap_eq: "is_derived m n b c \<Longrightarrow> cap_master_cap b = cap_master_cap c"
  by (clarsimp simp:is_derived_def split:if_splits)


lemma cap_insert_valid_arch_caps:
  "\<lbrace>valid_arch_caps and (\<lambda>s. cte_wp_at (is_derived (cdt s) src cap) src s)\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. valid_arch_caps\<rbrace>"
  apply (simp add: cap_insert_def)
  apply (rule hoare_pre)
   apply (wp set_cap_valid_arch_caps get_cap_wp set_untyped_cap_as_full_valid_arch_caps
               | simp split del: split_if)+
      apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift set_untyped_cap_as_full_cte_wp_at_neg
                set_untyped_cap_as_full_is_final_cap'_neg set_untyped_cap_as_full_cte_wp_at hoare_vcg_ball_lift
                hoare_vcg_ex_lift hoare_vcg_disj_lift | wps)+
  apply (wp set_untyped_cap_as_full_obj_at_impossible)
  apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift set_untyped_cap_as_full_cte_wp_at_neg
    set_untyped_cap_as_full_is_final_cap'_neg hoare_vcg_ball_lift
    hoare_vcg_ex_lift | wps)+
  apply (wp set_untyped_cap_as_full_obj_at_impossible)
  apply (wp hoare_vcg_all_lift hoare_vcg_imp_lift set_untyped_cap_as_full_cte_wp_at_neg
    set_untyped_cap_as_full_is_final_cap'_neg hoare_vcg_ball_lift
    hoare_vcg_ex_lift | wps)+
  apply (rule hoare_strengthen_post)
    prefer 2
    apply (erule iffD2[OF caps_of_state_cteD'])
  apply (wp set_untyped_cap_as_full_cte_wp_at hoare_vcg_all_lift hoare_vcg_imp_lift
    set_untyped_cap_as_full_cte_wp_at_neg hoare_vcg_ex_lift | clarsimp)+
  apply (rule hoare_strengthen_post)
    prefer 2
    apply (erule iffD2[OF caps_of_state_cteD'])
  apply (wp set_untyped_cap_as_full_cte_wp_at hoare_vcg_all_lift hoare_vcg_imp_lift
    set_untyped_cap_as_full_cte_wp_at_neg hoare_vcg_ex_lift | clarsimp)+
  apply (wp get_cap_wp)
  apply (intro conjI allI impI disj_subst)
          apply simp
         apply clarsimp
         defer
        apply (clarsimp simp:valid_arch_caps_def cte_wp_at_caps_of_state)
        apply (drule(1) unique_table_refs_no_cap_asidD)
        apply (frule is_derived_obj_refs)
        apply (frule is_derived_cap_asid_issues)
        apply (frule is_derived_is_cap)
        apply (clarsimp simp:no_cap_to_obj_with_diff_ref_def  Ball_def
          del:disjCI dest!: derived_cap_master_cap_eq)
        apply (drule table_cap_ref_eq_rewrite)
         apply clarsimp
        apply (erule_tac x=a in allE, erule_tac x=b in allE)
        apply simp
       apply simp
      apply (clarsimp simp:obj_at_def is_cap_simps valid_arch_caps_def)
      apply (frule(1) valid_table_capsD)
        apply (clarsimp simp:cte_wp_at_caps_of_state)
        apply (drule is_derived_is_pt_pd)
        apply (clarsimp simp:is_derived_def is_cap_simps)
       apply (clarsimp simp:cte_wp_at_caps_of_state)
       apply (frule is_derived_cap_asid_issues)
       apply (clarsimp simp:is_cap_simps)
      apply (clarsimp simp:cte_wp_at_caps_of_state)
      apply (frule is_derived_obj_refs)
      apply (drule_tac x = p in bspec)
        apply fastforce
      apply (clarsimp simp:obj_at_def empty_table_caps_of)
     apply (clarsimp simp:empty_table_caps_of valid_arch_caps_def)
     apply (frule(1) valid_table_capsD)
       apply (clarsimp simp:cte_wp_at_caps_of_state is_derived_is_pt_pd)
      apply (clarsimp simp:cte_wp_at_caps_of_state)
      apply (frule is_derived_cap_asid_issues)
      apply (clarsimp simp:is_cap_simps)
     apply (clarsimp simp:cte_wp_at_caps_of_state)
     apply (frule is_derived_obj_refs)
     apply (drule_tac x = x in bspec)
       apply fastforce
     apply (clarsimp simp:obj_at_def empty_table_caps_of)
    apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)
    apply (frule is_derived_is_pt_pd)
    apply (frule is_derived_obj_refs)
    apply (frule is_derived_cap_asid_issues)
       apply (clarsimp simp:is_cap_simps valid_arch_caps_def cap_master_cap_def is_derived_def)
       apply (drule_tac ptr = src and ptr' = "(x,xa)" in unique_table_capsD)
    apply (simp add:is_cap_simps)+
   apply (clarsimp simp:is_cap_simps cte_wp_at_caps_of_state)
   apply (frule is_derived_is_pt_pd)
   apply (frule is_derived_obj_refs)
   apply (frule is_derived_cap_asid_issues)
   apply (clarsimp simp:is_cap_simps valid_arch_caps_def cap_master_cap_def is_derived_def)
   apply (drule_tac ptr = src and ptr' = "(x,xa)" in unique_table_capsD)
   apply (simp add:is_cap_simps)+
  apply (auto simp:cte_wp_at_caps_of_state)
done


crunch arch_obj_at[wp]: cap_insert "ko_at (ArchObj ao) p"
  (ignore: set_object set_cap wp: set_cap_obj_at_impossible crunch_wps
     simp: caps_of_def cap_of_def)


crunch empty_table_at[wp]: cap_insert "obj_at (empty_table S) p"
  (ignore: set_object set_cap wp: set_cap_obj_at_impossible crunch_wps
     simp: empty_table_caps_of)


crunch valid_global_objs[wp]: cap_insert "valid_global_objs"
  (wp: crunch_wps)


crunch v_ker_map[wp]: cap_insert "valid_kernel_mappings"
  (wp: crunch_wps)


crunch asid_map[wp]: cap_insert valid_asid_map
  (wp: get_cap_wp simp: crunch_simps)


crunch only_idle[wp]: cap_insert only_idle
  (wp: get_cap_wp simp: crunch_simps)


crunch equal_ker_map[wp]: cap_insert "equal_kernel_mappings"
  (wp: crunch_wps)


crunch global_pd_mappings[wp]: cap_insert "valid_global_pd_mappings"
  (wp: crunch_wps)


crunch pspace_in_kernel_window[wp]: cap_insert "pspace_in_kernel_window"
  (wp: crunch_wps)


crunch cap_refs_in_kernel_window[wp]: update_cdt "cap_refs_in_kernel_window"

lemma cap_insert_cap_refs_in_kernel_window[wp]:
  "\<lbrace>cap_refs_in_kernel_window
          and cte_wp_at (\<lambda>c. cap_range cap \<subseteq> cap_range c) src\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. cap_refs_in_kernel_window\<rbrace>"
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def)
  apply (wp get_cap_wp | simp split del: split_if)+
  apply (clarsimp simp: cte_wp_at_caps_of_state is_derived_def)
  apply (frule(1) cap_refs_in_kernel_windowD[where ptr=src])
  apply auto
  done

lemma is_derived_cap_range:
  "is_derived m srcptr cap cap'
    \<Longrightarrow> cap_range cap' = cap_range cap"
  by (clarsimp simp: is_derived_def cap_range_def is_cap_simps dest!: master_cap_cap_range
              split: split_if_asm)


lemma set_cdt_valid_ioc[wp]:
  "\<lbrace>valid_ioc\<rbrace> set_cdt t \<lbrace>\<lambda>_. valid_ioc\<rbrace>"
  by (simp add: set_cdt_def, wp) (simp add: valid_ioc_def)

crunch valid_ioc[wp]: update_cdt valid_ioc

crunch cte_wp_at[wp]: update_cdt "cte_wp_at P slot"

(* FIXME: we could weaken this. *)
lemma set_original_valid_ioc[wp]:
  "\<lbrace>valid_ioc and cte_wp_at (\<lambda>x. val \<longrightarrow> x \<noteq> cap.NullCap) slot\<rbrace>
    set_original slot val
   \<lbrace>\<lambda>_. valid_ioc\<rbrace>"
  by (simp add: set_original_def, wp) (clarsimp simp: valid_ioc_def)


lemma valid_ioc_NullCap_not_original:
  "\<lbrakk>valid_ioc s; cte_wp_at (op= cap.NullCap) slot s\<rbrakk>
   \<Longrightarrow> \<not> is_original_cap s slot"
  by (cases slot) (fastforce simp add: cte_wp_at_caps_of_state valid_ioc_def)


lemma cap_insert_valid_ioc[wp]:
  "\<lbrace>valid_ioc\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>_. valid_ioc\<rbrace>"
  apply (simp add: cap_insert_def set_untyped_cap_as_full_def)
  apply (wp set_object_valid_ioc_caps set_cap_cte_wp_at get_cap_wp 
    | clarsimp simp:is_cap_simps split del: split_if)+
  apply (auto simp: valid_ioc_NullCap_not_original elim: cte_wp_cte_at)
  done


lemma set_cdt_vms[wp]:
  "\<lbrace>valid_machine_state\<rbrace> set_cdt t \<lbrace>\<lambda>_. valid_machine_state\<rbrace>"
  by (simp add: set_cdt_def, wp) (simp add: valid_machine_state_def)

crunch vms[wp]: update_cdt valid_machine_state


lemma cap_insert_vms[wp]:
  "\<lbrace>valid_machine_state\<rbrace> cap_insert cap src dest \<lbrace>\<lambda>_. valid_machine_state\<rbrace>"
  apply (simp add: cap_insert_def set_object_def set_untyped_cap_as_full_def)
  apply (wp get_object_wp get_cap_wp| simp only: vms_ioc_update | rule hoare_drop_imp | simp split del: split_if)+
  done

lemma valid_irq_states_cdt_update[simp]:
  "valid_irq_states (s\<lparr>cdt := x\<rparr>) = valid_irq_states s"
  by(auto simp: valid_irq_states_def)

lemma valid_irq_states_is_original_cap_update[simp]:
  "valid_irq_states (s\<lparr>is_original_cap := x\<rparr>) = valid_irq_states s"
  by(auto simp: valid_irq_states_def)

lemma valid_irq_states_exst_update[simp]:
  "valid_irq_states (s\<lparr>exst := x\<rparr>) = valid_irq_states s"
  by(auto simp: valid_irq_states_def)

crunch valid_irq_states[wp]: cap_insert "valid_irq_states"
  (wp: crunch_wps simp: crunch_simps)

lemma cap_insert_invs[wp]:
 "\<lbrace>invs and cte_wp_at (\<lambda>c. c=Structures_A.NullCap) dest
        and valid_cap cap and tcb_cap_valid cap dest
        and ex_cte_cap_wp_to (appropriate_cte_cap cap) dest
        and (\<lambda>s. \<forall>r\<in>obj_refs cap. \<forall>p'. dest \<noteq> p' \<and> cte_wp_at (\<lambda>cap'. r \<in> obj_refs cap') p' s
                                       \<longrightarrow> (cte_wp_at (Not \<circ> is_zombie) p' s \<and> \<not> is_zombie cap))
        and (\<lambda>s. cte_wp_at (is_derived (cdt s) src cap) src s)
        and (\<lambda>s. cte_wp_at (\<lambda>cap'. \<forall>irq \<in> cap_irqs cap - cap_irqs cap'. irq_issued irq s) src s)
        and (\<lambda>s. \<forall>t. cap = cap.ReplyCap t False \<longrightarrow>
                 st_tcb_at awaiting_reply t s \<and> \<not> has_reply_cap t s)
        and K (\<not> is_master_reply_cap cap)\<rbrace>
  cap_insert cap src dest
  \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: invs_def valid_state_def)
  apply (rule hoare_pre)
   apply (wp cap_insert_valid_pspace cap_insert_ifunsafe cap_insert_idle
             valid_irq_node_typ cap_insert_valid_arch_caps)
  apply (clarsimp simp: cte_wp_at_caps_of_state
                        is_derived_cap_range valid_pspace_def)
  done

lemma prop_is_preserved_imp:
  "\<lbrace>P and Q\<rbrace> f \<lbrace>\<lambda>rv. P\<rbrace> \<Longrightarrow> \<lbrace>P and Q\<rbrace> f \<lbrace>\<lambda>rv. P\<rbrace>"
  by simp

lemma derive_cap_inv[wp]:
  "\<lbrace>P\<rbrace> derive_cap slot c \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (case_tac c, simp_all add: derive_cap_def ensure_no_children_def whenE_def is_zombie_def, wp)
  apply clarsimp
  apply (wp arch_derive_cap_inv | simp)+
  done

lemma cte_at_0:
  "cap_table_at bits oref s
  \<Longrightarrow> cte_at (oref, replicate bits False) s"
  by (clarsimp simp: obj_at_def is_cap_table
                     cte_at_cases well_formed_cnode_n_def length_set_helper)

lemma tcb_at_cte_at_0:
  "tcb_at tcb s \<Longrightarrow> cte_at (tcb, tcb_cnode_index 0) s"
  by (auto simp: obj_at_def cte_at_cases is_tcb)


lemma tcb_at_cte_at_1:
  "tcb_at tcb s \<Longrightarrow> cte_at (tcb, tcb_cnode_index 1) s"
  by (auto simp: obj_at_def cte_at_cases is_tcb)


lemma set_cdt_valid_objs:
  "\<lbrace>valid_objs\<rbrace> set_cdt m \<lbrace>\<lambda>_. valid_objs\<rbrace>"
  apply (simp add: set_cdt_def)
  apply wp
  apply (fastforce intro: valid_objs_pspaceI)
  done


lemma get_cap_cte:
  "\<lbrace>\<top>\<rbrace> get_cap y \<lbrace>\<lambda>rv. cte_at y\<rbrace>"
  apply (clarsimp simp: valid_def)
  apply (frule get_cap_cte_at)
  apply (drule state_unchanged [OF get_cap_inv])
  apply simp
  done


lemma cap_swap_typ_at:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace> cap_swap c x c' y \<lbrace>\<lambda>_ s. P (typ_at T p s)\<rbrace>"
  apply (simp add: cap_swap_def)
  apply (wp set_cdt_typ_at set_cap_typ_at
         |simp split del: split_if)+
  done


lemma cap_swap_valid_cap:
  "\<lbrace>valid_cap c\<rbrace> cap_swap cap x cap' y \<lbrace>\<lambda>_. valid_cap c\<rbrace>"
  by (simp add: cap_swap_typ_at valid_cap_typ)
     

lemma cap_swap_cte_at:
  "\<lbrace>cte_at p\<rbrace> cap_swap c x c' y \<lbrace>\<lambda>_. cte_at p\<rbrace>"
  by (simp add: valid_cte_at_typ cap_swap_typ_at [where P="\<lambda>x. x"])


lemma tcb_cap_valid_typ_st:
  assumes x: "\<And>P t. \<lbrace>\<lambda>s. P (typ_at ATCB t s)\<rbrace> f \<lbrace>\<lambda>rv s. P (typ_at ATCB t s)\<rbrace>"
  and     y: "\<And>P t. \<lbrace>st_tcb_at P t\<rbrace> f \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  and     z: "\<And>P t. \<lbrace>\<lambda>s. \<forall>tcb. ko_at (TCB tcb) t s \<longrightarrow> P (tcb_ipc_buffer tcb)\<rbrace>
                       f \<lbrace>\<lambda>rv s. \<forall>tcb. ko_at (TCB tcb) t s \<longrightarrow> P (tcb_ipc_buffer tcb)\<rbrace>"
  shows      "\<lbrace>\<lambda>s. tcb_cap_valid cap p s\<rbrace> f \<lbrace>\<lambda>rv s. tcb_cap_valid cap p s\<rbrace>"
  apply (simp add: tcb_cap_valid_def)
  apply (simp only: imp_conv_disj tcb_at_typ)
  apply (wp hoare_vcg_disj_lift x y)
  apply (simp add: z)
  done


lemma set_cap_tcb_ipc_buffer:
  "\<lbrace>\<lambda>s. \<forall>tcb. ko_at (TCB tcb) t s \<longrightarrow> P (tcb_ipc_buffer tcb)\<rbrace>
      set_cap cap p
   \<lbrace>\<lambda>rv s. \<forall>tcb. ko_at (TCB tcb) t s \<longrightarrow> P (tcb_ipc_buffer tcb)\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (wp get_object_wp | wpc)+
  apply (clarsimp simp: obj_at_def)
  done


lemmas set_cap_tcb_cap[wp] = tcb_cap_valid_typ_st [OF set_cap_typ_at set_cap_pred_tcb set_cap_tcb_ipc_buffer]


lemma cap_swap_valid_objs:
  "\<lbrace>valid_objs and valid_cap c and valid_cap c'
        and tcb_cap_valid c' x
        and tcb_cap_valid c y\<rbrace>
  cap_swap c x c' y
  \<lbrace>\<lambda>_. valid_objs\<rbrace>"
  apply (simp add: cap_swap_def)
  apply (wp set_cdt_valid_objs set_cap_valid_objs set_cap_valid_cap
         |simp split del: split_if)+
  done


lemma mask_cap_valid[simp]:
  "s \<turnstile> c \<Longrightarrow> s \<turnstile> mask_cap R c"
  apply (cases c, simp_all add: valid_cap_def mask_cap_def
                             cap_rights_update_def
                             cap_aligned_def
                             acap_rights_update_def)
  using valid_validate_vm_rights[simplified valid_vm_rights_def]
  apply (rename_tac arch_cap)
  by (case_tac arch_cap, simp_all)


lemma lookup_cap_valid:
  "\<lbrace>valid_objs\<rbrace> lookup_cap t c \<lbrace>\<lambda>rv. valid_cap rv\<rbrace>,-"
  apply (simp add: lookup_cap_def split_def)
  apply wp
  apply (rule hoare_post_impErr)
    apply (rule valid_validE)
    apply (rule lookup_slot_for_thread_inv)
  apply auto
  done


lemma mask_cap_objrefs[simp]:
  "obj_refs (mask_cap rs cap) = obj_refs cap"
  by (cases cap, simp_all add: mask_cap_def cap_rights_update_def
                               acap_rights_update_def
                        split: arch_cap.split)


lemma mask_cap_zobjrefs[simp]:
  "zobj_refs (mask_cap rs cap) = zobj_refs cap"
  by (cases cap, simp_all add: mask_cap_def cap_rights_update_def
                               acap_rights_update_def
                        split: arch_cap.split)


lemma mask_cap_is_zombie[simp]:
  "is_zombie (mask_cap rs cap) = is_zombie cap"
  by (cases cap, simp_all add: mask_cap_def cap_rights_update_def is_zombie_def)


lemma get_cap_exists[wp]:
  "\<lbrace>\<top>\<rbrace> get_cap sl \<lbrace>\<lambda>rv s. \<forall>r\<in>zobj_refs rv. ex_nonz_cap_to r s\<rbrace>"
  apply (wp get_cap_wp)
  apply (cases sl)
  apply (fastforce simp: ex_nonz_cap_to_def elim!: cte_wp_at_weakenE)
  done


lemma lookup_cap_ex_cap[wp]:
  "\<lbrace>\<top>\<rbrace> lookup_cap t ref \<lbrace>\<lambda>rv s. \<forall>r\<in>zobj_refs rv. ex_nonz_cap_to r s\<rbrace>,-"
  apply (simp add: lookup_cap_def split_def)
  apply wp
  done

lemma guarded_lookup_valid_cap:
  "\<lbrace>valid_objs\<rbrace> null_cap_on_failure (lookup_cap t c) \<lbrace>\<lambda>rv. valid_cap rv \<rbrace>"
  apply (simp add: null_cap_on_failure_def)
  apply wp
  apply (rule hoare_strengthen_post)
   apply (rule lookup_cap_valid [unfolded validE_R_def validE_def])
  apply (simp split: sum.splits)
  done
  
crunch inv[wp]: lookup_slot_for_cnode_op "P"
  (wp:  simp: crunch_simps)


lemma lsfco_cte_at[wp]:
  "\<lbrace>invs and valid_cap cap\<rbrace>
     lookup_slot_for_cnode_op bl cap ref depth
   \<lbrace>\<lambda>rv. cte_at rv\<rbrace>,-"
  apply (simp add: lookup_slot_for_cnode_op_def split_def unlessE_def whenE_def
        split del: split_if cong: if_cong)
  apply (rule hoare_pre)
   apply (wp | wpc | simp)+
      apply (wp hoare_drop_imps resolve_address_bits_cte_at)
  apply auto
  done

lemma lookup_slot_for_cnode_op_cap_to[wp]:
  "\<lbrace>\<lambda>s. \<forall>r\<in>cte_refs root (interrupt_irq_node s). ex_cte_cap_to r s\<rbrace>
    lookup_slot_for_cnode_op is_src root ptr depth
   \<lbrace>\<lambda>rv. ex_cte_cap_to rv\<rbrace>,-"
proof -
  have x: "\<And>x f g. (case x of [] \<Rightarrow> f | _ \<Rightarrow> g) = (if x = [] then f else g)"
    by (simp split: list.splits)
  show ?thesis
    apply (simp   add: lookup_slot_for_cnode_op_def split_def x
            split del: split_if cong: if_cong)
    apply (rule hoare_pre)
     apply (wp | simp)+
        apply (rule hoare_drop_imps)
        apply (unfold unlessE_def whenE_def)
        apply (wp rab_cte_cap_to)
    apply clarsimp
    done
qed


lemma ct_from_words_inv [wp]: 
  "\<lbrace>P\<rbrace> captransfer_from_words ws \<lbrace>\<lambda>rv. P\<rbrace>"
  by (simp add: captransfer_from_words_def | wp dmo_inv loadWord_inv)+

(* FIXME: move *)
crunch inv[wp]: stateAssert P

(* FIXME: move *)
lemma inter_UNIV_minus[simp]:
  "x \<inter> (UNIV - y) = x-y" by blast


lemma not_Null_valid_imp [simp]:
  "(cap \<noteq> cap.NullCap \<longrightarrow> s \<turnstile> cap) = (s \<turnstile> cap)"
  by (auto simp: valid_cap_def)


lemma enc_inv [wp]:
  "\<lbrace>P\<rbrace> ensure_no_children slot \<lbrace>\<lambda>rv. P\<rbrace>"
  unfolding ensure_no_children_def whenE_def
  apply wp
  apply simp
  done
  

lemma derive_cap_valid_cap:
  "\<lbrace>valid_cap cap\<rbrace> derive_cap slot cap \<lbrace>valid_cap\<rbrace>,-"
  apply (simp add: derive_cap_def)
  apply (rule hoare_pre)
   apply (wpc, (wp arch_derive_cap_valid_cap | simp)+)
  apply auto
  done


lemma badge_update_valid [iff]:
  "valid_cap (badge_update d cap) = valid_cap cap"
  by (rule ext, cases cap) 
     (auto simp: badge_update_def valid_cap_def cap_aligned_def)


lemma valid_cap_update_rights[simp]:
  "valid_cap cap s \<Longrightarrow> valid_cap (cap_rights_update cr cap) s"
  apply (case_tac cap,
         simp_all add: cap_rights_update_def valid_cap_def cap_aligned_def
                       acap_rights_update_def)
  using valid_validate_vm_rights[simplified valid_vm_rights_def]
  apply (rename_tac arch_cap)
  apply (case_tac arch_cap, simp_all)
  done


lemma update_cap_data_validI:
  "s \<turnstile> cap \<Longrightarrow> s \<turnstile> update_cap_data p d cap"
  apply (cases cap)
  apply (simp_all add: is_cap_defs update_cap_data_def Let_def split_def)
     apply (simp add: valid_cap_def cap_aligned_def)
    apply (simp add: valid_cap_def cap_aligned_def)
   apply (simp add: the_cnode_cap_def valid_cap_def cap_aligned_def)
  apply (rename_tac arch_cap)
  apply (case_tac arch_cap)
      apply (simp_all add: is_cap_defs arch_update_cap_data_def)
  done
  

lemma ensure_no_children_inv:
  "\<lbrace>P\<rbrace> ensure_no_children ptr \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (simp add: ensure_no_children_def whenE_def)
  apply wp
  apply simp
  done


lemma ensure_empty_inv[wp]:
  "\<lbrace>P\<rbrace> ensure_empty p \<lbrace>\<lambda>rv. P\<rbrace>"
  by (simp add: ensure_empty_def whenE_def | wp)+


lemma get_cap_cte_wp_at3:
  "\<lbrace>not cte_wp_at (not P) p\<rbrace> get_cap p \<lbrace>\<lambda>rv s. P rv\<rbrace>"
  apply (rule hoare_post_imp [where Q="\<lambda>rv. cte_wp_at (\<lambda>c. c = rv) p and not cte_wp_at (not P) p"])
   apply (clarsimp simp: cte_wp_at_def pred_neg_def)
  apply (wp get_cap_cte_wp_at)
  done


lemma ensure_empty_stronger:
  "\<lbrace>\<lambda>s. cte_wp_at (\<lambda>c. c = cap.NullCap) p s \<longrightarrow> P s\<rbrace> ensure_empty p \<lbrace>\<lambda>rv. P\<rbrace>,-"
  apply (simp add: ensure_empty_def whenE_def)
  apply wp
  apply simp
  apply (simp only: imp_conv_disj)
  apply (rule hoare_vcg_disj_lift)
   apply (wp get_cap_cte_wp_at3)
   apply (simp add: pred_neg_def)
  apply wp
  done


lemma set_cdt_ifunsafe[wp]:
  "\<lbrace>if_unsafe_then_cap\<rbrace> set_cdt m \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp add: set_cdt_def)
  apply wp
  apply (clarsimp elim!: ifunsafe_pspaceI)
  done


lemma ex_cte_cap_to_pres:
  assumes x: "\<And>P p. \<lbrace>cte_wp_at P p\<rbrace> f \<lbrace>\<lambda>rv. cte_wp_at P p\<rbrace>"
  assumes irq: "\<And>P. \<lbrace>\<lambda>s. P (interrupt_irq_node s)\<rbrace> f \<lbrace>\<lambda>rv s. P (interrupt_irq_node s)\<rbrace>"
  shows      "\<lbrace>ex_cte_cap_wp_to P p\<rbrace> f \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P p\<rbrace>"
  by (simp add: ex_cte_cap_wp_to_def,
      wp hoare_vcg_ex_lift hoare_use_eq[where f=interrupt_irq_node, OF irq, OF x])


lemma set_cdt_ex_cap[wp]:
  "\<lbrace>ex_cte_cap_to p\<rbrace> set_cdt m \<lbrace>\<lambda>rv. ex_cte_cap_to p\<rbrace>"
  by (wp ex_cte_cap_to_pres set_cdt_cte_wp_at)


lemma ex_cte_wp_revokable[simp]:
  "ex_cte_cap_wp_to P p (is_original_cap_update f s)
      = ex_cte_cap_wp_to P p s"
  by (simp add: ex_cte_cap_wp_to_def)


(* FIXME: move to StateRelation? *)
definition
  "cns_of_heap h \<equiv> \<lambda>p.
   case h p of Some (CNode sz cs) \<Rightarrow> if well_formed_cnode_n sz cs
                                     then Some sz else None
               | _ \<Rightarrow> None"


definition
  "ups_of_heap h \<equiv> \<lambda>p.
   case h p of Some (ArchObj (DataPage sz)) \<Rightarrow> Some sz | _ \<Rightarrow> None"


crunch irq_node[wp]: setup_reply_master "\<lambda>s. P (interrupt_irq_node s)"

crunch irq_states[wp]: setup_reply_master "\<lambda>s. P (interrupt_states s)"
  (wp: crunch_wps simp: crunch_simps)


lemma ups_of_heap_typ_at:
  "ups_of_heap (kheap s) p = Some sz \<longleftrightarrow> typ_at (AArch (AIntData sz)) p s"
  by (simp add: typ_at_eq_kheap_obj ups_of_heap_def
      split: option.splits Structures_A.kernel_object.splits
             arch_kernel_obj.splits)

lemma cns_of_heap_typ_at:
  "cns_of_heap (kheap s) p = Some n \<longleftrightarrow> typ_at (ACapTable n) p s"
  by (auto simp: typ_at_eq_kheap_obj(4) cns_of_heap_def 
                 wf_unique wf_cs_n_unique
           split: option.splits Structures_A.kernel_object.splits)


lemma ups_of_heap_typ_at_def:
  "ups_of_heap (kheap s) \<equiv> \<lambda>p.
   if \<exists>!sz. typ_at (AArch (AIntData sz)) p s
     then Some (THE sz. typ_at (AArch (AIntData sz)) p s)
   else None"
  apply (rule eq_reflection)
  apply (rule ext)
  apply (clarsimp simp: ups_of_heap_typ_at)
  apply (intro conjI impI)
   apply (frule (1) theI')
  apply safe
   apply (fastforce simp: ups_of_heap_typ_at)
  apply (clarsimp simp add: obj_at_def)
  done

lemma ups_of_heap_TCB_upd[simp]:
  "h x = Some (TCB tcb) \<Longrightarrow> ups_of_heap (h(x \<mapsto> TCB y)) = ups_of_heap h"
  by (rule ext) (simp add: ups_of_heap_def)


lemma ups_of_heap_CNode_upd[simp]:
  "h x = Some (CNode sz cs) \<Longrightarrow> ups_of_heap (h(x \<mapsto> CNode sz y)) = ups_of_heap h"
  by (rule ext) (simp add: ups_of_heap_def)


lemma set_cap_ups_of_heap[wp]:
 "\<lbrace>\<lambda>s. P (ups_of_heap (kheap s))\<rbrace> set_cap cap sl
  \<lbrace>\<lambda>_ s. P (ups_of_heap (kheap s))\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all)
   prefer 2
   apply (auto simp: valid_def in_monad obj_at_def)[1]
  apply (clarsimp simp add: valid_def in_monad obj_at_def)
  done


lemma cns_of_heap_TCB_upd[simp]:
  "h x = Some (TCB tcb) \<Longrightarrow> cns_of_heap (h(x \<mapsto> TCB y)) = cns_of_heap h"
  by (rule ext) (simp add: cns_of_heap_def)


lemma cns_of_heap_CNode_upd[simp]:
  "\<lbrakk>h a = Some (CNode sz cs); cs bl = Some cap; well_formed_cnode_n sz cs\<rbrakk>
   \<Longrightarrow> cns_of_heap (h(a \<mapsto> CNode sz (cs(bl \<mapsto> cap')))) = cns_of_heap h"
  apply (rule ext)
  apply (auto simp add: cns_of_heap_def wf_unique)
  apply (clarsimp simp add: well_formed_cnode_n_def dom_def Collect_eq)
  apply (frule_tac x=bl in spec)
  apply (erule_tac x=aa in allE)
  apply (clarsimp split: split_if_asm)
  done


lemma set_cap_cns_of_heap[wp]:
 "\<lbrace>\<lambda>s. P (cns_of_heap (kheap s))\<rbrace> set_cap cap sl
  \<lbrace>\<lambda>_ s. P (cns_of_heap (kheap s))\<rbrace>"
  apply (simp add: set_cap_def split_def set_object_def)
  apply (rule hoare_seq_ext [OF _ get_object_sp])
  apply (case_tac obj, simp_all)
   prefer 2
   apply (auto simp: valid_def in_monad obj_at_def)[1]
  apply (clarsimp simp add: valid_def in_monad obj_at_def)
  done


lemma of_nat_ucast:
  "is_down (ucast :: ('a :: len) word \<Rightarrow> ('b :: len) word)
    \<Longrightarrow> (of_nat n :: 'b word) = ucast (of_nat n :: 'a word)"
  apply (subst word_unat.inverse_norm)
  apply (simp add: ucast_def word_of_int[symmetric]
                   of_nat_nat[symmetric] unat_def[symmetric])
  apply (simp add: unat_of_nat)
  apply (rule nat_int.Rep_eqD)
  apply (simp only: zmod_int)
  apply (rule mod_mod_cancel)
  apply (subst zdvd_int[symmetric])
  apply (rule le_imp_power_dvd)
  apply (simp add: is_down_def target_size_def source_size_def word_size)
  done


lemma tcb_cnode_index_def2:
  "tcb_cnode_index n = nat_to_cref 3 n"
  apply (simp add: tcb_cnode_index_def nat_to_cref_def)
  apply (rule nth_equalityI)
   apply (simp add: word_bits_def)
  apply (clarsimp simp: to_bl_nth word_size word_bits_def)
  apply (subst of_nat_ucast[where 'a=32 and 'b=3])
   apply (simp add: is_down_def target_size_def source_size_def word_size)
  apply (simp add: nth_ucast)
  apply fastforce
  done

crunch idle[wp]: set_cap "valid_idle"

lemma no_reply_caps_for_thread:
  "\<lbrakk> invs s; tcb_at t s; cte_wp_at (\<lambda>c. c = cap.NullCap) (t, tcb_cnode_index 2) s \<rbrakk>
   \<Longrightarrow> \<forall>sl m. \<not> cte_wp_at (\<lambda>c. c = cap.ReplyCap t m) sl s"
  apply clarsimp
  apply (case_tac m, simp_all)
   apply (fastforce simp: invs_def valid_state_def valid_reply_masters_def
                         cte_wp_at_caps_of_state)
  apply (subgoal_tac "st_tcb_at halted t s")
   apply (fastforce simp: invs_def valid_state_def valid_reply_caps_def
                         has_reply_cap_def cte_wp_at_caps_of_state st_tcb_def2)
  apply (thin_tac "cte_wp_at _ (a, b) s")
  apply (fastforce simp: pred_tcb_at_def obj_at_def is_tcb valid_obj_def
                        valid_tcb_def cte_wp_at_cases tcb_cap_cases_def
                  dest: invs_valid_objs
                  elim: valid_objsE)
  done


crunch tcb[wp]: setup_reply_master "tcb_at t"
  (wp: set_cap_tcb)

crunch idle[wp]: setup_reply_master "valid_idle"

lemma tcb_at_st_tcb_at: "tcb_at = st_tcb_at \<top>"
  apply (rule ext)+
  apply (simp add: tcb_at_def pred_tcb_at_def obj_at_def is_tcb_def)
  apply (rule arg_cong[where f=Ex], rule ext)
  apply (case_tac ko, simp_all)
  done

lemma setup_reply_master_pspace[wp]:
  "\<lbrace>valid_pspace and tcb_at t\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. valid_pspace\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp get_cap_wp set_cap_valid_pspace)
  apply clarsimp
  apply (rule conjI, clarsimp elim!: cte_wp_at_weakenE)
  apply (rule conjI, simp add: valid_cap_def cap_aligned_def word_bits_def)
   apply (clarsimp simp: tcb_at_def valid_pspace_def pspace_aligned_def)
   apply (fastforce dest: get_tcb_SomeD elim: my_BallE [where y=t])
  apply (clarsimp simp: tcb_cap_valid_def is_cap_simps tcb_at_st_tcb_at)
  done

lemma setup_reply_master_mdb[wp]:
  "\<lbrace>valid_mdb\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. valid_mdb\<rbrace>"
  apply (simp add: setup_reply_master_def valid_mdb_def2 reply_mdb_def)
  apply (wp set_cap_caps_of_state2 get_cap_wp)
  apply (clarsimp simp add: cte_wp_at_caps_of_state simp del: fun_upd_apply)
  apply (rule conjI)
   apply (clarsimp simp: mdb_cte_at_def simp del: split_paired_All)
  apply (rule conjI, clarsimp simp: untyped_mdb_def)
  apply (rule conjI, rule descendants_inc_upd_nullcap)
   apply simp+
  apply (rule conjI, clarsimp simp: untyped_inc_def)
  apply (rule conjI, clarsimp simp: ut_revocable_def)
  apply (rule conjI, clarsimp simp: irq_revocable_def)
  apply (rule conjI, clarsimp simp: reply_master_revocable_def)
  apply (rule conjI)
   apply (fastforce simp: reply_caps_mdb_def
               simp del: split_paired_All split_paired_Ex
                  elim!: allEI exEI)
  apply (unfold reply_masters_mdb_def)[1]
  apply (fastforce split: split_if_asm
                   dest: mdb_cte_at_Null_None mdb_cte_at_Null_descendants
                  elim!: allEI)
  done


lemma ex_nonz_tcb_cte_caps:
  "\<lbrakk>ex_nonz_cap_to t s; tcb_at t s; valid_objs s;
    ref \<in> dom tcb_cap_cases\<rbrakk>
   \<Longrightarrow> ex_cte_cap_wp_to (appropriate_cte_cap cp) (t, ref) s"
  apply (clarsimp simp: ex_nonz_cap_to_def ex_cte_cap_wp_to_def
                        cte_wp_at_caps_of_state)
  apply (subgoal_tac "s \<turnstile> cap")
   apply (rule_tac x=a in exI, rule_tac x=ba in exI)
   apply (clarsimp simp: valid_cap_def obj_at_def is_tcb
                         is_obj_defs dom_def
                         appropriate_cte_cap_def
                  split: cap.splits arch_cap.split_asm)
  apply (clarsimp simp: caps_of_state_valid_cap)
  done


lemma setup_reply_master_ifunsafe[wp]:
  "\<lbrace>if_unsafe_then_cap and tcb_at t and ex_nonz_cap_to t and valid_objs\<rbrace>
    setup_reply_master t
   \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp new_cap_ifunsafe get_cap_wp)
  apply (fastforce elim: ex_nonz_tcb_cte_caps)
  done


lemma setup_reply_master_reply[wp]:
  "\<lbrace>valid_reply_caps and tcb_at t\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. valid_reply_caps\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp hoare_drop_imps | simp add: if_fun_split)+
  apply (fastforce elim: tcb_at_cte_at)
  done


lemma setup_reply_master_reply_masters[wp]:
  "\<lbrace>valid_reply_masters and tcb_at t\<rbrace>
    setup_reply_master t \<lbrace>\<lambda>rv. valid_reply_masters\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp hoare_drop_imps | simp add: if_fun_split)+
  apply (fastforce elim: tcb_at_cte_at)
  done


lemma setup_reply_master_globals[wp]:
  "\<lbrace>valid_global_refs and ex_nonz_cap_to t\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. valid_global_refs\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp hoare_drop_imps | simp add: if_fun_split)+
  apply (clarsimp simp: ex_nonz_cap_to_def cte_wp_at_caps_of_state
                        cap_range_def
                  dest: valid_global_refsD2)
  done


crunch arch[wp]: setup_reply_master "valid_arch_state"
  (simp: crunch_simps)

crunch arch_objs[wp]: setup_reply_master "valid_arch_objs"


lemma setup_reply_master_irq_handlers[wp]:
  "\<lbrace>valid_irq_handlers and tcb_at t\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. valid_irq_handlers\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp set_cap_irq_handlers hoare_drop_imps | simp add: if_fun_split)+
  apply (fastforce elim: tcb_at_cte_at)
  done


crunch typ_at[wp]: setup_reply_master "\<lambda>s. P (typ_at T p s)"

crunch cur[wp]: setup_reply_master "cur_tcb"


lemma no_cap_to_obj_with_diff_ref_triv:
  "\<lbrakk> valid_objs s; valid_cap cap s; \<not> is_pt_cap cap;
           \<not> is_pd_cap cap; table_cap_ref cap = None \<rbrakk>
      \<Longrightarrow> no_cap_to_obj_with_diff_ref cap S s"
  apply (clarsimp simp add: no_cap_to_obj_with_diff_ref_def)
  apply (drule(1) cte_wp_at_valid_objs_valid_cap)
  apply (clarsimp simp: table_cap_ref_def valid_cap_def
                        obj_at_def is_ep is_aep is_tcb is_cap_table
                        a_type_def is_cap_simps
                 split: cap.split_asm arch_cap.split_asm
                        split_if_asm option.split_asm)
        apply auto
  done


lemma setup_reply_master_arch_caps[wp]:
  "\<lbrace>valid_arch_caps and tcb_at t and valid_objs and pspace_aligned\<rbrace>
     setup_reply_master t
   \<lbrace>\<lambda>rv. valid_arch_caps\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp set_cap_valid_arch_caps get_cap_wp)
  apply (clarsimp simp: cte_wp_at_caps_of_state is_pd_cap_def
                        is_pt_cap_def vs_cap_ref_def)
  apply (rule no_cap_to_obj_with_diff_ref_triv,
         simp_all add: is_cap_simps table_cap_ref_def)
  apply (simp add: valid_cap_def cap_aligned_def word_bits_def)
  apply (clarsimp simp: obj_at_def is_tcb dest!: pspace_alignedD)
  done


crunch arch_state[wp]: setup_reply_master "\<lambda>s. P (arch_state s)"


crunch arch_ko_at: setup_reply_master "ko_at (ArchObj ao) p"
  (ignore: set_cap wp: set_cap_obj_at_impossible crunch_wps
     simp: if_apply_def2 caps_of_def cap_of_def)


crunch empty_table_at[wp]: setup_reply_master "obj_at (empty_table S) p"
  (ignore: set_cap wp: set_cap_obj_at_impossible crunch_wps
     simp: if_apply_def2 empty_table_caps_of)


lemmas setup_reply_master_valid_ao_at[wp]
    = valid_ao_at_lift [OF setup_reply_master_typ_at setup_reply_master_arch_ko_at]


crunch v_ker_map[wp]: setup_reply_master "valid_kernel_mappings"

crunch eq_ker_map[wp]: setup_reply_master "equal_kernel_mappings"


crunch asid_map[wp]: setup_reply_master valid_asid_map


crunch only_idle[wp]: setup_reply_master only_idle


crunch valid_global_objs[wp]: setup_reply_master "valid_global_objs"

crunch global_pd_mappings[wp]: setup_reply_master "valid_global_pd_mappings"
  (simp: crunch_simps wp: crunch_wps)


crunch pspace_in_kernel_window[wp]: setup_reply_master "pspace_in_kernel_window"

lemma setup_reply_master_cap_refs_in_kernel_window[wp]:
  "\<lbrace>cap_refs_in_kernel_window and tcb_at t and pspace_in_kernel_window\<rbrace>
      setup_reply_master t
   \<lbrace>\<lambda>rv. cap_refs_in_kernel_window\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp get_cap_wp)
  apply (clarsimp simp: pspace_in_kernel_window_def obj_at_def
                        cap_range_def)
  done

crunch cap_refs_in_kernel_window[wp]: setup_reply_master "cap_refs_in_kernel_window"

lemma set_original_set_cap_comm:
  "(set_original slot val >>= (\<lambda>_. set_cap cap slot)) =
   (set_cap cap slot >>= (\<lambda>_. set_original slot val))"
by (rule ext) (simp add: bind_def split_def set_cap_def set_original_def
                   get_object_def set_object_def get_def put_def
                   simpler_gets_def simpler_modify_def
                   assert_def return_def fail_def
                 split: Structures_A.kernel_object.splits)

lemma setup_reply_master_valid_ioc[wp]:
  "\<lbrace>valid_ioc\<rbrace> setup_reply_master t \<lbrace>\<lambda>_. valid_ioc\<rbrace>"
  apply (simp add: setup_reply_master_def set_original_set_cap_comm)
  apply (wp get_cap_wp set_cap_cte_wp_at)
  apply (simp add: valid_ioc_def cte_wp_cte_at)
  done


lemma setup_reply_master_vms[wp]:
  "\<lbrace>valid_machine_state\<rbrace> setup_reply_master t \<lbrace>\<lambda>_. valid_machine_state\<rbrace>"
  apply (simp add: setup_reply_master_def)
  apply (wp get_cap_wp)
  apply (simp add: valid_machine_state_def)
  done

crunch valid_irq_states[wp]: setup_reply_master "valid_irq_states"

lemma setup_reply_master_invs[wp]:
  "\<lbrace>invs and tcb_at t and ex_nonz_cap_to t\<rbrace> setup_reply_master t \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: invs_def valid_state_def)
  apply (wp valid_irq_node_typ
                 | simp add: valid_pspace_def)+
  done

definition
  "is_simple_cap cap \<equiv>
    cap \<noteq> cap.NullCap \<and> cap \<noteq> cap.IRQControlCap \<and> \<not>is_untyped_cap cap \<and>
    \<not>is_master_reply_cap cap \<and> \<not>is_reply_cap cap \<and> 
    \<not>is_ep_cap cap \<and> \<not>is_aep_cap cap \<and> 
    \<not>is_thread_cap cap \<and> \<not>is_cnode_cap cap \<and> \<not>is_zombie cap \<and>
    \<not>is_pt_cap cap \<and> \<not> is_pd_cap cap"


definition
  "safe_parent_for m p cap parent \<equiv> 
   same_region_as parent cap \<and> 
   ((\<exists>irq. cap = cap.IRQHandlerCap irq) \<and> parent = cap.IRQControlCap \<or> 
    is_untyped_cap parent \<and> descendants_of p m = {})"


(* FIXME: prove same_region_as_def2 instead or change def *)
lemma same_region_as_Untyped2:
  "\<lbrakk> is_untyped_cap pcap; same_region_as pcap cap \<rbrakk> \<Longrightarrow>
  (is_physical cap \<and> cap_range cap \<noteq> {} \<and> cap_range cap \<subseteq> cap_range pcap)"
  apply (clarsimp simp: is_cap_simps cap_range_def)
  apply (rule conjI)
   apply (clarsimp simp: is_physical_def arch_is_physical_def split: cap.splits split: arch_cap.splits)
  apply (fastforce simp: is_physical_def arch_is_physical_def split: cap.splits split: arch_cap.splits)
  done


lemma safe_parent_cap_range:
  "safe_parent_for m p cap pcap \<Longrightarrow> cap_range cap \<subseteq> cap_range pcap"
  apply (clarsimp simp: safe_parent_for_def)
  apply (erule disjE)
   apply (clarsimp simp: cap_range_def)
  apply clarsimp
  apply (drule (1) same_region_as_Untyped2)
  apply blast
  done


lemma safe_parent_not_Null [simp]:
  "safe_parent_for m p cap cap.NullCap = False"
  by (simp add: safe_parent_for_def)


lemma safe_parent_is_parent:
  "\<lbrakk> safe_parent_for m p cap pcap; caps_of_state s p = Some pcap; valid_mdb s \<rbrakk> 
  \<Longrightarrow> should_be_parent_of pcap (is_original_cap s p) cap f"
  apply (clarsimp simp: should_be_parent_of_def safe_parent_for_def valid_mdb_def)
  apply (erule disjE)
   apply clarsimp
   defer
  apply clarsimp
  apply (drule (2) ut_revocableD)
  apply (clarsimp simp: is_cap_simps)
  apply (erule (1) irq_revocableD)
  done


lemma safe_parent_ut_descendants:
  "\<lbrakk> safe_parent_for m p cap pcap; is_untyped_cap pcap \<rbrakk> \<Longrightarrow>
  descendants_of p m = {} \<and> obj_refs cap \<subseteq> untyped_range pcap"
  apply (rule conjI)
   apply (clarsimp simp: safe_parent_for_def)
  apply (drule safe_parent_cap_range)
  apply (clarsimp simp: is_cap_simps cap_range_def)
  apply (drule (1) subsetD)
  apply simp
  done


lemma safe_parent_refs_or_descendants:
  "safe_parent_for m p cap pcap \<Longrightarrow> 
  (obj_refs cap \<subseteq> obj_refs pcap) \<or>
  (descendants_of p m = {} \<and> obj_refs cap \<subseteq> untyped_range pcap)"
  apply (cases "is_untyped_cap pcap")
   apply (drule (1) safe_parent_ut_descendants)
   apply simp
  apply (rule disjI1)
  apply (drule safe_parent_cap_range)
  apply (simp add: cap_range_def)
  apply (drule not_is_untyped_no_range)
  apply simp
  done


lemma (in mdb_insert_abs) untyped_mdb_simple:  
  assumes u: "untyped_mdb m cs"
  assumes inc: "untyped_inc m cs"
  assumes src: "cs src = Some c"
  assumes dst: "cs dest = Some cap.NullCap"
  assumes ut: "\<not>is_untyped_cap cap"
  assumes cr: "(obj_refs cap \<subseteq> obj_refs c) \<or> 
               (descendants_of src m = {} \<and> obj_refs cap \<subseteq> untyped_range c)" 
  shows "untyped_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))" 
  unfolding untyped_mdb_def 
  using u ut cr src dst 
  apply (intro allI impI)
  apply (simp add: descendants_child)
  apply (case_tac "ptr = dest", simp)
  apply simp
  apply (case_tac "ptr' = dest")
   apply simp
   apply (rule impI)
   apply (elim conjE)
   apply (simp add: descendants_of_def del: split_paired_All)
   apply (erule disjE)
    apply (drule_tac ptr=ptr and ptr'=src in untyped_mdbD, assumption+)
      apply blast
     apply assumption
    apply (simp add: descendants_of_def)
   apply (elim conjE)
   apply (case_tac "untyped_range c = {}", simp)
   apply (frule_tac p=src and p'=ptr in untyped_incD [rotated -1, OF inc])
      apply fastforce
     apply assumption+
   apply (simp add: descendants_of_def del: split_paired_All)
   apply (elim conjE)
   apply (erule disjE, fastforce)
   apply (erule disjE, fastforce)
   apply blast
  apply (simp add: untyped_mdbD del: split_paired_All)
  apply (intro impI)  
  apply (frule_tac ptr=src and ptr'=ptr' in untyped_mdbD)
      apply clarsimp
     apply assumption
    apply clarsimp
   apply assumption
  apply simp
  done


lemma (in mdb_insert_abs) reply_caps_mdb_simple:
  assumes u: "reply_caps_mdb m cs"
  assumes src: "cs src = Some c"
  assumes sr: "\<not>is_reply_cap c \<and> \<not>is_master_reply_cap c"
  assumes nr: "\<not>is_reply_cap cap \<and> \<not>is_master_reply_cap cap"
  shows "reply_caps_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  unfolding reply_caps_mdb_def
  using u src sr nr
  apply (intro allI impI)
  apply (simp add: descendants_child del: split_paired_Ex)
  apply (case_tac "ptr = dest", simp add: is_cap_simps)
  apply (simp del: split_paired_Ex)
  apply (unfold reply_caps_mdb_def)
  apply (elim allE)
  apply (erule(1) impE)
  apply (erule exEI)
  apply simp
  apply blast
  done


lemma (in mdb_insert_abs) reply_masters_mdb_simple:
  assumes u: "reply_masters_mdb m cs"
  assumes src: "cs src = Some c"
  assumes sr: "\<not>is_reply_cap c \<and> \<not>is_master_reply_cap c"
  assumes nr: "\<not>is_reply_cap cap \<and> \<not>is_master_reply_cap cap"
  shows "reply_masters_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  unfolding reply_masters_mdb_def
  using u src sr nr
  apply (intro allI impI)
  apply (simp add: descendants_child del: split_paired_Ex)
  apply (case_tac "ptr = dest", simp add: is_cap_simps)
  apply (simp del: split_paired_Ex)
  apply (unfold reply_masters_mdb_def)
  apply (elim allE)
  apply (erule(1) impE)
  apply (elim conjE, simp add: neq is_cap_simps)
  apply (intro conjI impI)
    apply fastforce
   apply (rule ccontr, simp)
  apply (rule ballI, rule ccontr, simp add: descendants_of_def)
  done


lemma safe_parent_same_region:
  "safe_parent_for m p cap pcap \<Longrightarrow> same_region_as pcap cap"
  by (simp add: safe_parent_for_def)


lemma same_region_as_cap_class:
  shows "same_region_as a b \<Longrightarrow> cap_class a = cap_class b"
  apply (case_tac a)
   apply (fastforce simp: cap_range_def arch_is_physical_def is_cap_simps
     is_physical_def split:cap.splits arch_cap.splits)+
 apply (clarsimp split: arch_cap.splits cap.splits)
 apply (rename_tac arch_cap arch_capa)
 apply (case_tac arch_cap)
  apply (case_tac arch_capa,clarsimp+)+
 done


lemma (in mdb_insert_abs) reply_mdb_simple:
  assumes u: "reply_mdb m cs"
  assumes src: "cs src = Some c"
  assumes sr: "\<not>is_reply_cap c \<and> \<not>is_master_reply_cap c"
  assumes nr: "\<not>is_reply_cap cap \<and> \<not>is_master_reply_cap cap"
  shows "reply_mdb (m(dest \<mapsto> src)) (cs(dest \<mapsto> cap))"
  using u src sr nr unfolding reply_mdb_def
  by (simp add: reply_caps_mdb_simple reply_masters_mdb_simple)


lemma cap_insert_simple_mdb:
  "\<lbrace>valid_mdb and valid_objs and 
    cte_wp_at (\<lambda>c. c = cap.NullCap) dest and 
    (\<lambda>s. cte_wp_at (safe_parent_for (cdt s) src cap) src s) and
    K (is_simple_cap cap)\<rbrace>
  cap_insert cap src dest \<lbrace>\<lambda>rv. valid_mdb\<rbrace>"
  apply (simp add: cap_insert_def valid_mdb_def2 update_cdt_def set_cdt_def set_untyped_cap_as_full_def) 
  apply (wp set_cap_caps_of_state2 get_cap_wp|simp del: fun_upd_apply split del: split_if)+
  apply (clarsimp simp: cte_wp_at_caps_of_state safe_parent_is_parent valid_mdb_def2 
                  simp del: fun_upd_apply
                  split del: split_if)
  apply (rule conjI)
   apply (cases src, cases dest)
   apply (clarsimp simp: mdb_cte_at_def is_simple_cap_def split del: split_if)
  apply (subgoal_tac "mdb_insert_abs (cdt s) src dest")
   prefer 2
   apply (rule mdb_insert_abs.intro)
     apply clarsimp
    apply (erule (1) mdb_cte_at_Null_None)
   apply (erule (1) mdb_cte_at_Null_descendants)
  apply (intro conjI impI)
    apply (clarsimp simp:mdb_cte_at_def is_simple_cap_def split del:split_if)
    apply (fastforce split:split_if_asm)
   apply (erule (4) mdb_insert_abs.untyped_mdb_simple)
    apply (simp add: is_simple_cap_def)
   apply (erule safe_parent_refs_or_descendants)
   apply (erule(1) mdb_insert_abs.descendants_inc)
     apply simp
    apply (simp add:safe_parent_cap_range)
    apply (clarsimp simp:safe_parent_for_def same_region_as_cap_class)
   apply (frule mdb_insert_abs.neq)
   apply (simp add: no_mloop_def mdb_insert_abs.parency)
   apply (intro allI impI)
   apply (rule notI)
   apply (simp add: mdb_insert_abs.dest_no_parent_trancl)
   apply (erule(2)  mdb_insert_abs.untyped_inc_simple)
    apply (drule(1) caps_of_state_valid)+
    apply (simp add:valid_cap_aligned) 
   apply (simp add:is_simple_cap_def)+
   apply (clarsimp simp: ut_revocable_def is_simple_cap_def)
   apply (clarsimp simp: irq_revocable_def is_simple_cap_def)
   apply (clarsimp simp: reply_master_revocable_def is_simple_cap_def)
  apply (erule(2)  mdb_insert_abs.reply_mdb_simple)
   apply (fastforce simp: is_simple_cap_def safe_parent_for_def is_cap_simps)
  apply (clarsimp simp: is_simple_cap_def)
  done


lemma set_untyped_cap_as_full_caps_of_state_diff:
  "\<lbrace>\<lambda>s. src \<noteq> dest \<and> P (caps_of_state s dest)\<rbrace>
   set_untyped_cap_as_full src_cap cap src 
   \<lbrace>\<lambda>rv s. P (caps_of_state s dest)\<rbrace>"
  apply (clarsimp simp:set_untyped_cap_as_full_def)
  apply (intro conjI impI allI)
  apply (wp|clarsimp)+
  done


lemma cap_insert_simple_arch_caps_no_ap:
  "\<lbrace>valid_arch_caps and (\<lambda>s. cte_wp_at (safe_parent_for (cdt s) src cap) src s)
             and no_cap_to_obj_with_diff_ref cap {dest} and K (is_simple_cap cap \<and> \<not>is_ap_cap cap)\<rbrace>
     cap_insert cap src dest
   \<lbrace>\<lambda>rv. valid_arch_caps\<rbrace>"
  apply (simp add: cap_insert_def)
  apply (wp set_cap_valid_arch_caps set_untyped_cap_as_full_valid_arch_caps get_cap_wp
    | simp split del: split_if)+
  apply (wp hoare_vcg_all_lift hoare_vcg_conj_lift hoare_vcg_imp_lift hoare_vcg_ball_lift hoare_vcg_disj_lift
    set_untyped_cap_as_full_cte_wp_at_neg set_untyped_cap_as_full_is_final_cap'_neg
    set_untyped_cap_as_full_empty_table_at hoare_vcg_ex_lift
    set_untyped_cap_as_full_caps_of_state_diff[where dest=dest]
    | wps)+
  apply (wp get_cap_wp)
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (intro conjI impI allI)
  apply (auto simp:is_simple_cap_def is_cap_simps)
done

lemma cap_insert_simple_invs:
  "\<lbrace>invs and valid_cap cap and tcb_cap_valid cap dest and
    ex_cte_cap_wp_to (appropriate_cte_cap cap) dest and
    cte_wp_at (\<lambda>c. is_untyped_cap c \<longrightarrow> usable_untyped_range c = {}) src and
    cte_wp_at (\<lambda>c. c = cap.NullCap) dest and 
    no_cap_to_obj_with_diff_ref cap {dest} and
    (\<lambda>s. cte_wp_at (safe_parent_for (cdt s) src cap) src s) and
    K (is_simple_cap cap \<and> \<not>is_ap_cap cap) and (\<lambda>s. \<forall>irq \<in> cap_irqs cap. irq_issued irq s)\<rbrace>
  cap_insert cap src dest \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: invs_def valid_state_def valid_pspace_def)
  apply (rule hoare_pre)
   apply (wp cap_insert_simple_mdb cap_insert_iflive 
             cap_insert_zombies cap_insert_ifunsafe 
             cap_insert_valid_global_refs cap_insert_idle
             valid_irq_node_typ cap_insert_simple_arch_caps_no_ap)
  apply (clarsimp simp: is_simple_cap_def cte_wp_at_caps_of_state)
  apply (drule safe_parent_cap_range)
  apply simp
  apply (rule conjI)
   prefer 2
   apply (clarsimp simp: is_cap_simps)
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (drule_tac p="(a,b)" in caps_of_state_valid_cap, fastforce)
  apply (clarsimp dest!: is_cap_simps' [THEN iffD1])
  apply (auto simp add: valid_cap_def [where c="cap.Zombie a b x" for a b x]
              dest: obj_ref_is_tcb obj_ref_is_cap_table split: option.splits)
  done

lemma safe_parent_for_masked_as_full[simp]:
  "safe_parent_for m src a (masked_as_full src_cap b) =
   safe_parent_for m src a src_cap"
  apply (clarsimp simp:safe_parent_for_def)
  apply (rule iffI)
    apply (clarsimp simp:masked_as_full_def free_index_update_def split:if_splits cap.splits)+
done

lemma lookup_cnode_slot_real_cte [wp]:
  "\<lbrace>valid_objs and valid_cap root\<rbrace> lookup_slot_for_cnode_op s root ptr depth \<lbrace>\<lambda>rv. real_cte_at rv\<rbrace>, -"
  apply (simp add: lookup_slot_for_cnode_op_def split_def unlessE_whenE cong: if_cong split del: split_if)
  apply (rule hoare_pre)
   apply (wp hoare_drop_imps resolve_address_bits_real_cte_at whenE_throwError_wp
          |wpc|simp)+
  apply fastforce
  done


lemma cte_refs_rights_update [simp]:
  "cte_refs (cap_rights_update R cap) x = cte_refs cap x"
  by (simp add: cap_rights_update_def split: cap.splits)

lemmas set_cap_typ_ats [wp] = abs_typ_at_lifts [OF set_cap_typ_at]

lemma lookup_slot_for_cnode_op_cap_to2[wp]:
  "\<lbrace>\<lambda>s. (is_cnode_cap root \<longrightarrow>
          (\<forall>r\<in>cte_refs root (interrupt_irq_node s). ex_cte_cap_wp_to P r s))
       \<and> (\<forall>cp. is_cnode_cap cp \<longrightarrow> P cp)\<rbrace>
    lookup_slot_for_cnode_op is_src root ptr depth
   \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P rv\<rbrace>,-"
proof -
  have x: "\<And>x f g. (case x of [] \<Rightarrow> f | _ \<Rightarrow> g) = (if x = [] then f else g)"
    by (simp split: list.splits)
  show ?thesis
    apply (simp   add: lookup_slot_for_cnode_op_def split_def x
            split del: split_if cong: if_cong)
    apply (rule hoare_pre)
     apply (wp | simp)+
        apply (rule hoare_drop_imps)
        apply (unfold unlessE_def whenE_def)
        apply (wp rab_cte_cap_to)
    apply clarsimp
    done
qed

end
