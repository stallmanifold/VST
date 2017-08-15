Require Import floyd.base2.
Require Import floyd.client_lemmas.
Require Import floyd.efield_lemmas.
Require Import floyd.local2ptree_denote.
Require Import floyd.local2ptree_typecheck.
Local Open Scope logic.

Ltac unfold_for_go_lower :=
  cbv delta [PROPx LOCALx SEPx locald_denote
                       eval_exprlist eval_expr eval_lvalue cast_expropt
                       sem_cast eval_binop eval_unop force_val1 force_val2
                      tc_expropt tc_expr tc_exprlist tc_lvalue tc_LR tc_LR_strong
                      msubst_tc_expropt msubst_tc_expr msubst_tc_exprlist msubst_tc_lvalue msubst_tc_LR (* msubst_tc_LR_strong *) msubst_tc_efield msubst_simpl_tc_assert 
                      typecheck_expr typecheck_exprlist typecheck_lvalue typecheck_LR typecheck_LR_strong typecheck_efield
                      function_body_ret_assert frame_ret_assert
                      make_args' bind_ret get_result1 retval
                       classify_cast
                       (* force_val sem_cast_neutral ... NOT THESE TWO!  *)
                      denote_tc_assert (* tc_andp tc_iszero *)
    liftx LiftEnviron Tarrow Tend lift_S lift_T
    lift_prod lift_last lifted lift_uncurry_open lift_curry
     local lift lift0 lift1 lift2 lift3
   ] beta iota.

Lemma grab_tc_environ:
  forall Delta PQR S rho,
    (tc_environ Delta rho -> PQR rho |-- S) ->
    (local (tc_environ Delta) && PQR) rho |-- S.
Proof.
intros.
unfold PROPx,LOCALx in *; simpl in *.
normalize.
unfold local, lift1. normalize.
Qed.

Ltac go_lower0 :=
intros ?rho;
 try (simple apply grab_tc_environ; intro);
 repeat (progress unfold_for_go_lower; simpl).

Ltac old_go_lower :=
 go_lower0;
 autorewrite with go_lower;
 try findvars;
 simpl;
 autorewrite with go_lower;
 try match goal with H: tc_environ _ ?rho |- _ => clear H rho end.

Hint Rewrite eval_id_same : go_lower.
Hint Rewrite eval_id_other using solve [clear; intro Hx; inversion Hx] : go_lower.
(*Hint Rewrite Vint_inj' : go_lower.*)

(*** New go_lower stuff ****)

Lemma lower_one_temp:
 forall t rho Delta P i v Q R S,
  (temp_types Delta) ! i = Some t ->
  (tc_val t v -> eval_id i rho = v ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (temp i v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *. unfold_lift.
normalize.
rewrite prop_true_andp in H0 by auto.
apply H0; auto.
apply tc_eval'_id_i with Delta; auto.
Qed.

Lemma lower_one_temp_Vint:
 forall t rho Delta P i v Q R S,
  (temp_types Delta) ! i = Some t ->
  (tc_val t (Vint v) -> eval_id i rho = Vint v ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (temp i (Vint v) :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
eapply lower_one_temp; eauto.
Qed.

Lemma lower_one_lvar:
 forall t rho Delta P i v Q R S,
  (headptr v -> lvar_denote i t v rho ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (lvar i t v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *. unfold_lift.
normalize.
rewrite prop_true_andp in H by auto.
apply H; auto.
hnf in H1.
destruct (Map.get (ve_of rho) i); try contradiction.
destruct p. destruct H1; subst.
hnf; eauto.
Qed.

Lemma finish_compute_le:  Lt = Gt -> False.
Proof. congruence. Qed.

Lemma lower_one_gvar:
 forall t rho Delta P i v Q R S,
  (glob_types Delta) ! i = Some t ->
  (headptr v -> gvar_denote i v rho ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (gvar i v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *. unfold_lift.
normalize.
rewrite prop_true_andp in H0 by auto.
apply H0; auto.
hnf in H2; destruct (Map.get (ve_of rho) i) as [[? ?] |  ]; try contradiction.
destruct (ge_of rho i); try contradiction.
subst.
hnf; eauto.
Qed.

Lemma lower_one_sgvar:
 forall t rho Delta P i v Q R S,
  (glob_types Delta) ! i = Some t ->
  (headptr v -> sgvar_denote i v rho ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (sgvar i v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *. unfold_lift.
normalize.
rewrite prop_true_andp in H0 by auto.
apply H0; auto.
hnf in H2.
destruct (ge_of rho i); try contradiction.
subst.
hnf; eauto.
Qed.

Lemma lower_one_prop:
 forall  rho Delta P (P1: Prop) Q R S,
  (P1 ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (localprop P1 :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *.
normalize.
rewrite prop_true_andp in H by auto.
hnf in H1.
apply H; auto.
Qed.

Lemma finish_lower:
  forall rho D R S,
  fold_right_sepcon R |-- S ->
  (local D && PROP() LOCAL() (SEPx R)) rho |-- S.
Proof.
intros.
simpl.
apply andp_left2.
unfold_for_go_lower; simpl. normalize.
Qed.

Lemma lower_one_temp_Vint':
 forall sz sg rho Delta P i v Q R S,
  (temp_types Delta) ! i = Some (Tint sz sg noattr) ->
  ((exists j, v = Vint j /\ tc_val (Tint sz sg noattr) (Vint j) /\ eval_id i rho = (Vint j)) ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (temp i v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
eapply lower_one_temp; eauto.
intros.
apply H0; auto.
generalize H1; intro.
hnf in H3. destruct v; try contradiction.
exists i0. split3; auto.
Qed.
 
Ltac lower_one_temp_Vint' :=
 match goal with
 | a : name ?i |- (local _ && PROPx _ (LOCALx (temp ?i ?v :: _) _)) _ |-- _ =>
     simple eapply lower_one_temp_Vint';
     [ reflexivity | ];
     let tc := fresh "TC" in
     clear a; intros [a [? [tc ?EVAL]]]; unfold tc_val in tc; try subst v;
     revert tc; fancy_intro true
 | |- (local _ && PROPx _ (LOCALx (temp _ ?v :: _) _)) _ |-- _ =>
    is_var v;
     simple eapply lower_one_temp_Vint';
     [ reflexivity | ];
    let v' := fresh "v" in rename v into v';
     let tc := fresh "TC" in
     intros [v [? [tc ?EVAL]]]; unfold tc_val in tc; subst v';
     revert tc; fancy_intro true
 end.

Lemma lower_one_temp_trivial:
 forall t rho Delta P i v Q R S,
  (temp_types Delta) ! i = Some t ->
  (tc_val t v ->
   (local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R))) rho |-- S) ->
  (local (tc_environ Delta) && PROPx P (LOCALx (temp i v :: Q) (SEPx R))) rho |-- S.
Proof.
intros.
rewrite <- insert_local.
forget (PROPx P (LOCALx Q (SEPx R))) as PQR.
unfold local,lift1 in *.
simpl in *. unfold_lift.
normalize.
rewrite prop_true_andp in H0 by auto.
apply H0; auto.
apply tc_eval'_id_i with Delta; auto.
Qed.

Lemma quick_finish_lower:
  forall LHS,
  emp |-- !! True ->
  LHS |-- !! True.
Proof.
intros.
apply prop_right; auto.
Qed.

Fixpoint remove_localdef (x: localdef) (l: list localdef) : list localdef :=
  match l with
  | nil => nil
  | y :: l0 =>
     match x, y with
     | temp i u, temp j v =>
       if Pos.eqb i j
       then remove_localdef x l0
       else y :: remove_localdef x l0
     | lvar i ti u, lvar j tj v =>
       if Pos.eqb i j
       then remove_localdef x l0
       else y :: remove_localdef x l0
     | gvar i u, gvar j v =>
       if Pos.eqb i j
       then remove_localdef x l0
       else y :: remove_localdef x l0
     | sgvar i u, sgvar j v =>
       if Pos.eqb i j
       then remove_localdef x l0
       else y :: remove_localdef x l0
     | _, _ => y :: remove_localdef x l0
     end
  end.

Fixpoint extractp_localdef (x: localdef) (l: list localdef) : list Prop :=
  match l with
  | nil => nil
  | y :: l0 =>
     match x, y with
     | temp i u, temp j v =>
       if Pos.eqb i j
       then (v = u) :: extractp_localdef x l0
       else extractp_localdef x l0
     | lvar i ti u, lvar j tj v =>
       if Pos.eqb i j
       then (tj = ti) :: (v = u) :: extractp_localdef x l0
       else extractp_localdef x l0
     | gvar i u, gvar j v =>
       if Pos.eqb i j
       then (v = u) :: extractp_localdef x l0
       else extractp_localdef x l0
     | sgvar i u, sgvar j v =>
       if Pos.eqb i j
       then (v = u) :: extractp_localdef x l0
       else extractp_localdef x l0
     | _, _ => extractp_localdef x l0
     end
  end.

Definition localdef_tc (Delta: tycontext) (x: localdef): list Prop :=
  match x with
  | temp i v =>
      match (temp_types Delta) ! i with
      | Some t => tc_val t v :: nil
      | _ => nil
      end
  | lvar _ _ v =>
      isptr v :: headptr v :: nil
  | gvar i v
  | sgvar i v =>
      isptr v :: headptr v :: nil
  | _ => nil
  end.

Ltac pos_eqb_tac :=
  let H := fresh "H" in
  match goal with
  | |- context [Pos.eqb ?i ?j] => destruct (Pos.eqb i j) eqn:H; [apply Pos.eqb_eq in H | apply Pos.eqb_neq in H]
  end.

Lemma localdef_local_facts: forall Delta x,
  local (tc_environ Delta) && local (locald_denote x) |-- !! fold_right and True (localdef_tc Delta x).
Proof.
  intros.
  unfold local, lift1; unfold_lift.
  intros rho; simpl.
  rewrite <- prop_and.
  apply prop_derives.
  intros [? ?].
  destruct x; simpl in H0; unfold_lift in H0.
  + subst; simpl.
    destruct ((temp_types Delta) ! i) eqn:?; simpl; auto.
    destruct H0; subst.
    split; auto.
    revert H1.
    eapply tc_eval'_id_i; eauto.
  + simpl.
    assert (headptr v); [| split; [| split]; auto; apply headptr_isptr; auto].
    unfold lvar_denote in H0.
    destruct (Map.get (ve_of rho) i); [| inversion H0].
    destruct p, H0; subst.
    hnf; eauto.
  + simpl.
    assert (headptr v); [| split; [| split]; auto; apply headptr_isptr; auto].
    unfold gvar_denote in H0.
    destruct (Map.get (ve_of rho) i) as [[? ?] |]; [inversion H0 |].
    destruct (ge_of rho i); [| inversion H0].
    subst.
    hnf; eauto.
  + simpl.
    assert (headptr v); [| split; [| split]; auto; apply headptr_isptr; auto].
    unfold sgvar_denote in H0.
    destruct (ge_of rho i); [| inversion H0].
    subst.
    hnf; eauto.
  + simpl.
    auto.
Qed.

Lemma go_lower_localdef_one_step_canon_left: forall Delta Ppre l Qpre Rpre post,
  local (tc_environ Delta) && PROPx (Ppre ++ localdef_tc Delta l) (LOCALx (l :: Qpre) (SEPx Rpre)) |-- post ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx (l :: Qpre) (SEPx Rpre)) |-- post.
Proof.
  intros.
  apply derives_trans with (local (tc_environ Delta) && PROPx (Ppre ++ localdef_tc Delta l) (LOCALx (l :: Qpre) (SEPx Rpre))); auto.
  replace (PROPx (Ppre ++ localdef_tc Delta l)) with (PROPx (localdef_tc Delta l ++ Ppre)).
  Focus 2. {
    apply PROPx_Permutation.
    apply Permutation_app_comm.
  } Unfocus.
  rewrite <- !insert_local'.
  apply andp_right; [solve_andp |].
  apply andp_right; [solve_andp |].
  unfold PROPx. apply andp_right; [| solve_andp].
  rewrite <- andp_assoc.
  eapply derives_trans; [apply andp_derives; [apply localdef_local_facts | apply derives_refl] |].
  rewrite <- andp_assoc.
  apply andp_left1.
  remember (localdef_tc Delta l); clear.
  induction l0.
  + simpl fold_right.
    apply andp_left2; auto.
  + simpl fold_right.
    rewrite !prop_and, !andp_assoc.
    apply andp_derives; auto.
Qed.

Lemma go_lower_localdef_one_step_canon_canon: forall Delta Ppre l Qpre Rpre Ppost Qpost Rpost,
  local (tc_environ Delta) && PROPx (Ppre ++ localdef_tc Delta l) (LOCALx Qpre (SEPx Rpre)) |--
    PROPx (Ppost ++ extractp_localdef l Qpost) (LOCALx (remove_localdef l Qpost) (SEPx Rpost)) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx (l :: Qpre) (SEPx Rpre)) |--
    PROPx Ppost (LOCALx Qpost (SEPx Rpost)).
Proof.
  intros.
  apply go_lower_localdef_one_step_canon_left.
  replace (PROPx (Ppost ++ extractp_localdef l Qpost)) with (PROPx (extractp_localdef l Qpost ++ Ppost)) in H.
  Focus 2. {
    apply PROPx_Permutation.
    apply Permutation_app_comm.
  } Unfocus.
  induction Qpost.
  + rewrite <- insert_local'.
    eapply derives_trans; [| apply H].
    solve_andp.
  + rewrite <- (insert_local' a).
    eapply derives_trans; [| apply andp_derives; [apply derives_refl | apply IHQpost]];
    clear IHQpost.
    - apply andp_right; [| auto].
      rewrite <- (insert_local' l).
      rewrite <- andp_assoc, (andp_comm _ (local _)),
              <- (andp_dup (local (tc_environ Delta))), <- andp_assoc,
              (andp_assoc _ _ (PROPx _ _)).
      eapply derives_trans; [apply andp_derives; [apply derives_refl | apply H] | clear H].
      simpl extractp_localdef; simpl remove_localdef.
      destruct l, a; try pos_eqb_tac;
        try (rewrite <- insert_local'; solve_andp);
        try (rewrite (andp_comm _ (local _)), andp_assoc, insert_local';
             rewrite <- !app_comm_cons;
             repeat (simple apply derives_extract_PROP; intros);
             subst; rewrite <- insert_local'; solve_andp).
    - rewrite <- (andp_dup (local (tc_environ Delta))), andp_assoc.
      eapply derives_trans; [apply andp_derives; [apply derives_refl | apply H] | clear H].
      simpl extractp_localdef; simpl remove_localdef.
      destruct l, a; try pos_eqb_tac;
      rewrite <- ?app_comm_cons, <- ?app_comm_cons, <- ?insert_local';
      repeat (simple apply derives_extract_PROP; intros);
      solve_andp.
Qed.

Definition re_localdefs (Pre Post: list localdef): list (list Prop) * list localdef :=
  fold_left (fun (PQ: list (list Prop) * list localdef) l => let (P, Q) := PQ in (extractp_localdef l Q :: P, remove_localdef l Q)) Pre (nil, Post).

Definition remove_localdefs (Pre Post: list localdef): list localdef :=
  match re_localdefs Pre Post with
  | (_, Q) => Q
  end.

Definition extractp_localdefs (Pre Post: list localdef): list Prop :=
  match re_localdefs Pre Post with
  | (P, _) => concat (rev P)
  end.

Definition localdefs_tc (Delta: tycontext) (Pre: list localdef): list Prop :=
  concat (map (localdef_tc Delta) Pre).

Lemma remove_localdefs_cons: forall a Qpre Qpost,
  remove_localdefs (a :: Qpre) Qpost = remove_localdefs Qpre (remove_localdef a Qpost).
Proof.
  intros.
  unfold remove_localdefs, re_localdefs; simpl.
  forget (extractp_localdef a Qpost :: nil) as P'.
  forget (@nil (list Prop)) as Q'.
  revert P' Q' a Qpost; induction Qpre; intros.
  * auto.
  * simpl.
    apply IHQpre.
Qed.

Lemma extractp_localdefs_cons: forall a Qpre Qpost,
  Permutation (extractp_localdefs (a :: Qpre) Qpost)
    (extractp_localdef a Qpost ++ extractp_localdefs Qpre (remove_localdef a Qpost)).
Proof.
  intros.
  unfold extractp_localdefs, re_localdefs; simpl.
  forget (remove_localdef a Qpost) as Q.
  pose proof Permutation_refl (extractp_localdef a Qpost :: nil).
  revert H.
  generalize (extractp_localdef a Qpost :: nil) at 1 3; intros P1.
  generalize (@nil (list Prop)) at 1 2; intros P2.
  revert P1 P2 Q; induction Qpre; intros.
  + simpl.
    apply Permutation_rev' in H.
    rewrite <- (Permutation_rev (_ :: _)) in H.
    apply Permutation_concat in H.
    rewrite H; clear H.
    simpl.
    apply Permutation_app_head, Permutation_concat, Permutation_rev.
  + simpl.
    apply IHQpre.
    rewrite perm_swap.
    apply perm_skip.
    auto.
Qed.

Lemma go_lower_localdef_canon_left: forall Delta Ppre Qpre Rpre post,
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- post ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- post.
Proof.
  intros.
  revert Ppre post H; induction Qpre; intros.
  + cbv [localdefs_tc concat rev map] in H.
    rewrite !app_nil_r in H; auto.
  + apply go_lower_localdef_one_step_canon_left.
    rewrite <- insert_local, (andp_comm _ (PROPx _ _)), <- andp_assoc, -> imp_andp_adjoint.
    apply IHQpre.
    rewrite <- imp_andp_adjoint.
    apply andp_left1.
    rewrite <- !app_assoc.
    eapply derives_trans; [exact H | auto].
Qed.

Lemma go_lower_localdef_canon_canon: forall Delta Ppre Qpre Rpre Ppost Qpost Rpost,
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |--
    PROPx (Ppost ++ extractp_localdefs Qpre Qpost) (LOCALx (remove_localdefs Qpre Qpost) (SEPx Rpost)) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |--
    PROPx Ppost (LOCALx Qpost (SEPx Rpost)).
Proof.
  intros.
  revert Ppre Ppost Qpost H; induction Qpre; intros.
  + cbv [remove_localdefs extractp_localdefs localdefs_tc re_localdefs fold_left concat rev map] in H.
    rewrite !app_nil_r in H; auto.
  + apply go_lower_localdef_one_step_canon_canon.
    apply IHQpre.
    rewrite <- !app_assoc.
    eapply derives_trans; [exact H |].
    clear.
    rewrite <- remove_localdefs_cons.
    erewrite PROPx_Permutation; [apply derives_refl |].
    apply Permutation_app_head.
    apply extractp_localdefs_cons.
Qed.

Ltac unfold_localdef_name QQ Q :=
  match Q with
  | nil => idtac
  | cons ?Qh ?Qt =>
    match Qh with
    | temp ?n _ => unfold n in QQ
    | lvar ?n _ _ => unfold n in QQ
    | gvar ?n _ => unfold n in QQ
    | sgvar ?n _ => unfold n in QQ
    end;
    unfold_localdef_name QQ Qt
  end.

Ltac clean_LOCAL_canon_canon :=
  match goal with
  | |- local _ && (PROPx _ (LOCALx _ (SEPx _))) |-- PROPx _ (LOCALx _ (SEPx _)) =>
    apply go_lower_localdef_canon_canon
  end;
         (let el := fresh "el" in
         let rl := fresh "rl" in
         let PP := fresh "P" in
         let QQ := fresh "Q" in
         let PPr := fresh "Pr" in
         match goal with
         | |- context [?Pr ++ extractp_localdefs ?P ?Q] =>
                set (el := Pr ++ extractp_localdefs P Q);
                set (rl := remove_localdefs P Q);
                set (PPr := Pr) in el;
                set (PP := P) in el, rl;
                set (QQ := Q) in el, rl;
                cbv [re_localdefs extractp_localdefs remove_localdefs extractp_localdef remove_localdef concat rev fold_left app Pos.eqb] in el, rl;
                unfold_localdef_name PP P;
                unfold_localdef_name QQ Q;
                subst PPr PP QQ;
                cbv beta iota zeta in el, rl;
                subst el rl
         end);
         (let tl := fresh "tl" in
         let QQ := fresh "Q" in
         let PPr := fresh "Pr" in
         match goal with
         | |- context [?Pr ++ localdefs_tc ?Delta ?Q] =>
                set (tl := Pr ++ localdefs_tc Delta Q);
                set (PPr := Pr) in tl;
                set (QQ := Q) in tl;
                unfold Delta, abbreviate in tl;
                cbv [localdefs_tc localdef_tc temp_types tc_val concat map app Pos.eqb PTree.get] in tl;
                unfold_localdef_name QQ Q;
                subst PPr QQ;
                cbv beta iota zeta in tl;
                subst tl
         end).

Lemma go_lower_localdef_canon_tc_expr {cs: compspecs} : forall Delta Ppre Qpre Rpre e T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_expr Delta T1 T2 e) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_expr Delta e.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_expr_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Lemma go_lower_localdef_canon_tc_lvalue {cs: compspecs} : forall Delta Ppre Qpre Rpre e T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_lvalue Delta T1 T2 e) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_lvalue Delta e.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_lvalue_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Lemma go_lower_localdef_canon_tc_LR {cs: compspecs} : forall Delta Ppre Qpre Rpre e lr T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_LR Delta T1 T2 e lr) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_LR Delta e lr.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_LR_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Lemma go_lower_localdef_canon_tc_efield {cs: compspecs} : forall Delta Ppre Qpre Rpre efs T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_efield Delta T1 T2 efs) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_efield Delta efs.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_efield_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Lemma go_lower_localdef_canon_tc_exprlist {cs: compspecs} : forall Delta Ppre Qpre Rpre ts es T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_exprlist Delta T1 T2 ts es) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_exprlist Delta ts es.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_exprlist_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Lemma go_lower_localdef_canon_tc_expropt {cs: compspecs} : forall Delta Ppre Qpre Rpre e t T1 T2,
  local2ptree Qpre = (T1, T2, nil, nil) ->
  local (tc_environ Delta) && PROPx (Ppre ++ localdefs_tc Delta Qpre) (LOCALx nil (SEPx Rpre)) |-- `(msubst_tc_expropt Delta T1 T2 e t) ->
  local (tc_environ Delta) && PROPx Ppre (LOCALx Qpre (SEPx Rpre)) |-- tc_expropt Delta e t.
Proof.
  intros.
  erewrite local2ptree_soundness by eassumption.
  simpl app.
  apply msubst_tc_expropt_sound.
  change Ppre with (nil ++ Ppre).
  erewrite <- local2ptree_soundness by eassumption.  
  apply go_lower_localdef_canon_left.
  auto.
Qed.

Inductive clean_LOCAL_right {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc): (environ -> mpred) -> mpred -> Prop :=
| clean_LOCAL_right_local_lift: forall P, clean_LOCAL_right Delta T1 T2 (local `P) (!! P)
| clean_LOCAL_right_prop: forall P, clean_LOCAL_right Delta T1 T2 (!! P) (!! P)
| clean_LOCAL_right_tc_lvalue: forall e, clean_LOCAL_right Delta T1 T2 (tc_lvalue Delta e) (msubst_tc_lvalue Delta T1 T2 e)
| clean_LOCAL_right_tc_expr: forall e, clean_LOCAL_right Delta T1 T2 (tc_expr Delta e) (msubst_tc_expr Delta T1 T2 e)
| clean_LOCAL_right_tc_LR: forall e lr, clean_LOCAL_right Delta T1 T2 (tc_LR Delta e lr) (msubst_tc_LR Delta T1 T2 e lr)
| clean_LOCAL_right_tc_efield: forall efs, clean_LOCAL_right Delta T1 T2 (tc_efield Delta efs) (msubst_tc_efield Delta T1 T2 efs)
| clean_LOCAL_right_tc_exprlist: forall ts es, clean_LOCAL_right Delta T1 T2 (tc_exprlist Delta ts es) (msubst_tc_exprlist Delta T1 T2 ts es)
| clean_LOCAL_right_tc_expropt: forall e t, clean_LOCAL_right Delta T1 T2 (tc_expropt Delta e t) (msubst_tc_expropt Delta T1 T2 e t)
| clean_LOCAL_right_andp: forall P1 P2 Q1 Q2, clean_LOCAL_right Delta T1 T2 P1 Q1 -> clean_LOCAL_right Delta T1 T2 P2 Q2 -> clean_LOCAL_right Delta T1 T2 (P1 && P2) (Q1 && Q2).

Lemma clean_LOCAL_right_spec: forall {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) P Q R S S',
  local2ptree Q = (T1, T2, nil, nil) ->
  clean_LOCAL_right Delta T1 T2 S S' ->
  local (tc_environ Delta) && PROPx (P ++ localdefs_tc Delta Q) (LOCALx nil (SEPx R)) |-- ` S' ->
  local (tc_environ Delta) && PROPx P (LOCALx Q (SEPx R)) |-- S.
Proof.
  intros.
  induction H0.
  + apply go_lower_localdef_canon_left, H1.
  + apply go_lower_localdef_canon_left, H1.
  + eapply go_lower_localdef_canon_tc_lvalue; eauto.
  + eapply go_lower_localdef_canon_tc_expr; eauto.
  + eapply go_lower_localdef_canon_tc_LR; eauto.
  + eapply go_lower_localdef_canon_tc_efield; eauto.
  + eapply go_lower_localdef_canon_tc_exprlist; eauto.
  + eapply go_lower_localdef_canon_tc_expropt; eauto.
  + apply andp_right.
    - apply IHclean_LOCAL_right1.
      apply (derives_trans _ _ _ H1).
      unfold_lift; intros rho.
      apply andp_left1; auto.
    - apply IHclean_LOCAL_right2.
      apply (derives_trans _ _ _ H1).
      unfold_lift; intros rho.
      apply andp_left2; auto.
Qed.

Ltac clean_LOCAL_canon_mix :=
  eapply clean_LOCAL_right_spec; [prove_local2ptree | solve [repeat constructor] |];
         (let tl := fresh "tl" in
         let QQ := fresh "Q" in
         let PPr := fresh "Pr" in
         match goal with
         | |- context [?Pr ++ localdefs_tc ?Delta ?Q] =>
                set (tl := Pr ++ localdefs_tc Delta Q);
                set (PPr := Pr) in tl;
                set (QQ := Q) in tl;
                unfold Delta, abbreviate in tl;
                cbv [localdefs_tc localdef_tc temp_types tc_val concat map app Pos.eqb PTree.get] in tl;
                unfold_localdef_name QQ Q;
                subst PPr QQ;
                cbv beta iota zeta in tl;
                subst tl
         end).

Ltac go_lower :=
clear_Delta_specs;
intros;
match goal with
 | |- ENTAIL ?D, normal_ret_assert _ _ _ |-- _ =>
       apply ENTAIL_normal_ret_assert; fancy_intros true
 | |- local _ && _ |-- _ => idtac
 | |- ENTAIL _, _ |-- _ => idtac
 | _ => fail 10 "go_lower requires a proof goal in the form of (ENTAIL _ , _ |-- _)"
end;
first [clean_LOCAL_canon_canon | clean_LOCAL_canon_mix];
repeat (simple apply derives_extract_PROP; fancy_intro true);
let rho := fresh "rho" in
intro rho;
first
[ simple apply quick_finish_lower
|          
 (simple apply finish_lower ||
 match goal with
 | |- (_ && PROPx nil _) _ |-- _ => fail 1 "LOCAL part of precondition is not a concrete list (or maybe Delta is not concrete)"
 | |- _ => fail 1 "PROP part of precondition is not a concrete list"
 end);
unfold_for_go_lower;
simpl; rewrite ?sepcon_emp;
clear_Delta;
try clear dependent rho].
