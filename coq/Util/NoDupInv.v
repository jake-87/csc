Set Implicit Arguments.

Require Import Lists.List RelationClasses.

Require Import CSC.Util.HasEquality CSC.Util.Convenience.

Section Util.

Inductive mapind {A : Type} (H : HasEquality A) (B : Type) : Type :=
| mapNil : mapind H B
| mapCons : A -> B -> mapind H B -> mapind H B
.
Fixpoint length { A : Type } {H : HasEquality A} {B : Type} (x : mapind H B) : nat :=
  match x with
  | mapNil _ _ => 0
  | mapCons _a _b xs => 1 + (length xs)
  end
.

Definition dom { A : Type } {H : HasEquality A} {B : Type} (m : mapind H B) : list A :=
  let fix dom_aux (m : mapind H B) :=
    match m with
    | mapNil _ _ => @List.nil A
    | mapCons a _b m' => @List.cons A a (dom_aux m')
    end
  in dom_aux m
.
Lemma in_dom_dec { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  In x (dom m) \/ ~ In x (dom m)
.
Proof.
  induction m; cbn.
  - now right.
  - fold (dom m); destruct IHm as [IHm|IHm]; eauto;
    destruct (eq_dec a x); subst;
    (repeat left; easy) + right; intros [H1|H1]; contradiction.
Qed.
Inductive nodupinv {A : Type} {H : HasEquality A} {B : Type} : mapind H B -> Prop :=
| nodupmapNil : nodupinv (mapNil H B)
| nodupmapCons : forall (a : A) (b : B) (m : mapind H B),
    ~(List.In a (dom m)) ->
    nodupinv m ->
    nodupinv (mapCons a b m)
.
(** Returns None if m contains any duplicates. *)
Fixpoint undup {A : Type} {H : HasEquality A} { B : Type } (m : mapind H B) : option(mapind H B) :=
  match m with
  | mapNil _ _ => Some(mapNil _ _)
  | mapCons a b m' =>
    let thedom := dom m' in
    match List.find (fun x => eq a x) thedom, undup m' with
    | None, Some xs' => Some(mapCons a b xs')
    | _, _ => None
    end
  end
.
Lemma undup_refl {A : Type} {H : HasEquality A} {B : Type} (m m' : mapind H B) :
  undup m = Some m' -> m = m'.
Proof.
  revert m'; induction m; intros m' H0; inv H0; trivial.
  destruct (option_dec (List.find (fun x : A => eq a x) (dom m))) as [Hx | Hy].
  apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H2; inv H2.
  rewrite Hy in H2.
  destruct (option_dec (undup m)) as [H__x | H__y]; try rewrite H__y in H2; inv H2.
  apply not_eq_None_Some in H__x as [m'' H__x]; rewrite H__x in H1.
  rewrite (IHm m'' H__x); now inv H1.
Qed.
Lemma nodupinv_equiv_undup {A : Type} {H : HasEquality A} { B : Type } (m : mapind H B) :
  undup m = Some m <-> nodupinv m.
Proof.
  induction m; cbn; split; try easy.
  - constructor.
  - intros H0; destruct (option_dec (List.find (fun x : A => eq a x) (dom m))) as [Hx | Hy].
    apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H0; inv H0.
    rewrite Hy in H0.
    destruct (option_dec (undup m)) as [Hx | Hy']; try rewrite Hy' in H0; inv H0.
    apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H2; inv H2.
    constructor; try apply IHm; eauto.
    intros Ha. eapply List.find_none in Hy; eauto. apply neqb_neq in Hy; contradiction.
  - intros H0; inv H0; destruct (option_dec (List.find (fun x : A => eq a x) (dom m))) as [Hx | Hy].
    apply not_eq_None_Some in Hx as [a' Hx].
    apply List.find_some in Hx as [Hx1 Hx2].
    rewrite eqb_eq in Hx2; subst; contradiction.
    rewrite Hy. destruct (option_dec (undup m)) as [Hx | Hy'].
    apply not_eq_None_Some in Hx as [m'' Hx]. rewrite Hx. f_equal. f_equal. apply undup_refl in Hx; easy.
    apply IHm in H5. congruence.
Qed.

(** Takes out x *)
Fixpoint delete {A : Type} {H : HasEquality A} { B : Type } (m : mapind H B) (x : A) : mapind H B :=
  match m with
  | mapNil _ _ => mapNil _ _
  | mapCons a b m' =>
    if a == x then
      delete m' x
    else
      mapCons a b (delete m' x)
  end
.
Definition push { A : Type } { H : HasEquality A } { B : Type } (a : A) (b : B) (m : mapind H B) : option (mapind H B) :=
  match undup (mapCons a b m) with
  | Some m' => Some m'
  | None => None
  end
.
Lemma push_ok { A : Type } { H : HasEquality A } { B : Type } (a : A) (b : B) (m m' : mapind H B) :
  push a b m = Some m' -> nodupinv m'.
Proof.
  intros H0. unfold push in H0.
  destruct (option_dec (undup (mapCons a b m))) as [Hx|Hy]; try (rewrite Hy in *; congruence);
  apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H0; inv H0;
  apply nodupinv_equiv_undup; cbn in Hx.
  destruct (option_dec (List.find (fun x : A => eq a x) (dom m))) as [Hx0|Hy0]; try (rewrite Hy0 in *; congruence).
  apply not_eq_None_Some in Hx0 as [m'' Hx0]; rewrite Hx0 in Hx; inv Hx.
  rewrite Hy0 in Hx. destruct (option_dec (undup m)) as [Hx1|Hy1].
  apply not_eq_None_Some in Hx1 as [m'' Hx1]. rewrite Hx1 in Hx.
  inv Hx. cbn. apply undup_refl in Hx1 as Hx1'. rewrite Hx1' in Hy0. rewrite Hy0.
  rewrite (undup_refl m Hx1) in Hx1. now rewrite Hx1.
  rewrite Hy1 in Hx. easy.
Qed.

Lemma push_ko { A : Type } { H : HasEquality A } { B : Type } (a : A) (b : B) (m : mapind H B) :
  nodupinv m ->
  ~ In a (dom m) ->
  push a b m = Some (mapCons a b m)
.
Proof.
  unfold push, undup; intros H0 H1.
  destruct (option_dec (List.find (fun x : A => eq a x) (dom m))) as [Hx | Hy].
  apply not_eq_None_Some in Hx as [m__x Hx].
  apply List.find_some in Hx as [Hx0 Hx1]. apply eqb_eq in Hx1; subst.
  contradiction.
  rewrite Hy in *. fold (undup m).
  destruct (option_dec (undup m)) as [Hx | Hy''].
  apply not_eq_None_Some in Hx as [m__x Hx].
  rewrite Hx in *. apply undup_refl in Hx; subst; easy.
  apply nodupinv_equiv_undup in H0; congruence.
Qed.

Definition img { A : Type } {H : HasEquality A} {B : Type} (m : mapind H B) : list B :=
  let fix img_aux (m : mapind H B) :=
    match m with
    | mapNil _ _ => @List.nil B
    | mapCons _a b m' => @List.cons B b (img_aux m')
    end
  in img_aux m
.
Definition append { A : Type } {H : HasEquality A} {B : Type} (m0 m1 : mapind H B) : mapind H B :=
  let fix append_aux (m0 : mapind H B) :=
    match m0 with
    | mapNil _ _ => m1
    | mapCons a b m' => mapCons a b (append_aux m')
    end
  in append_aux m0
.
(* '↦' is `\mapsto` and '◘' is `\inversebullet`*)
Notation "a '↦' b '◘' M" := (push a b M) (at level 81, b at next level).
Notation "M1 '◘' M2" := (append M1 M2) (at level 82, M2 at next level).
Notation "[⋅]" := (mapNil _ _) (at level 1).

Lemma append_nil { A : Type } {H : HasEquality A} {B : Type} (m : mapind H B) :
  append m (mapNil H B) = m
.
Proof. induction m; eauto; rewrite <- IHm at 2; now cbn. Qed.
Lemma append_assoc { A : Type } { H : HasEquality A } { B : Type } (m1 m2 m3 : mapind H B) :
  ((m1 ◘ m2) ◘ m3) = (m1 ◘ (m2 ◘ m3))
.
Proof.
  revert m2 m3; induction m1; intros.
  - now cbn.
  - change ((((mapCons a b m1) ◘ m2) ◘ m3) = (mapCons a b (m1 ◘ (m2 ◘ m3)))).
    now rewrite <- IHm1.
Qed.

Fixpoint splitat_aux { A : Type } {H : HasEquality A} {B : Type} (accM m : mapind H B) (x : A)
  : option((mapind H B) * A * B * (mapind H B)) :=
  match m with
  | mapNil _ _ => None
  | mapCons a b m' => if eq a x then
                        Some(accM, a, b, m')
                      else
                        splitat_aux (append accM (mapCons a b (mapNil H B))) m' x
  end
.
Definition splitat { A : Type } {H : HasEquality A} {B : Type} (m : mapind H B) (x : A)
  : option((mapind H B) * A * B * (mapind H B)) := splitat_aux (mapNil H B) m x.

Definition mget { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) : option B :=
  let fix doo (m : mapind H B) :=
    match m with
    | mapNil _ _=> None
    | mapCons a b m' => if eq a x then
                         Some b
                       else
                         doo m'
    end
  in doo m
.
Definition mset { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B)
  : option(mapind H B) :=
  let fix doo (m : mapind H B) :=
    match m with
    | mapNil _ _ => None
    | mapCons a b m'  => if eq a x then
                          Some(mapCons a v m')
                        else
                          match doo m' with
                          | None => None
                          | Some m'' => Some(mapCons a b m'')
                          end
    end
  in doo m
.

Lemma dom_append { A : Type } {H : HasEquality A} {B : Type} (m1 m2 : mapind H B) :
  dom (append m1 m2) = dom m1 ++ dom m2.
Proof.
  induction m1.
  - easy.
  - simpl.
    rewrite IHm1.
    reflexivity.
Qed.
Lemma splitat_elim_cons { A : Type } {H : HasEquality A} {B : Type} (m2 : mapind H B) (x : A) (v : B) :
  nodupinv (mapCons x v m2) ->
  splitat (mapCons x v m2) x = Some (mapNil _ _, x, v, m2).
Proof. cbn; now rewrite eq_refl. Qed.

Lemma splitat_aux_elim_cons { A : Type } {H : HasEquality A} {B : Type} (accM m2 : mapind H B) (x : A) (v : B) :
  nodupinv (accM ◘ mapCons x v m2) ->
  splitat_aux accM (mapCons x v m2) x = Some (accM, x, v, m2).
Proof. intros H0; cbn; now rewrite eq_refl. Qed.
Lemma splitat_aux_prop_cons { A : Type } {H : HasEquality A} {B : Type} (accM m2 : mapind H B) (x y : A) (v : B) :
  y <> x ->
  splitat_aux accM (mapCons y v m2) x = splitat_aux (accM ◘ mapCons y v (mapNil H B)) m2 x
.
Proof. cbn; intros H0; now apply neqb_neq in H0 as ->. Qed.
Lemma splitat_aux_prop { A : Type } {H : HasEquality A} {B : Type} (accM m1 m2 : mapind H B) (x y : A) (v : B) :
  ~ In x (dom m1) ->
  splitat_aux accM (m1 ◘ m2) x = splitat_aux (accM ◘ m1) m2 x
.
Proof.
  revert m1 accM; induction m1; intros.
  - cbn; now rewrite append_nil.
  - destruct (eq_dec a x); subst.
    + exfalso. apply H0. now left.
    + cbn; apply neqb_neq in H1 as ->. fold (m1 ◘ m2). fold (m1 ◘ accM).
      enough (~ In x (dom m1)).
      specialize (IHm1 (accM ◘ mapCons a b (mapNil H B)) H1) as ->.
      rewrite append_assoc; now cbn.
      revert H0; clear; intros H0 H1; apply H0; now right.
Qed.
Lemma splitat_elim { A : Type } {H : HasEquality A} {B : Type} (m1 m2 : mapind H B) (x : A) (v : B) :
  nodupinv (m1 ◘ mapCons x v m2) ->
  splitat (m1 ◘ mapCons x v m2) x = Some (m1, x, v, m2).
Proof.
  unfold splitat; intros H0. rewrite splitat_aux_prop; eauto. cbn; now rewrite eq_refl.
  induction m1; try now cbn.
  intros H1. inv H0. apply IHm1; eauto.
  destruct H1; try easy; subst. exfalso; apply H4; clear.
  induction m1; cbn; eauto.
Qed.
Lemma mset_notin { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  ~ In x (dom m) ->
  mset m x v = None
.
Proof.
  induction m; cbn; intros; trivial.
  destruct (eq_dec a x); fold (dom m) in H0.
  - exfalso; exact (H0 (or_introl H1)).
  - apply neqb_neq in H1; rewrite H1.
    fold (mset m x v); rewrite IHm; try easy.
    intros H2; exact (H0 (or_intror H2)).
Qed.
Lemma splitat_aux_notin { A : Type } { H : HasEquality A } { B : Type } (accM m : mapind H B) (x : A) :
  ~ In x (dom m) ->
  splitat_aux accM m x = None
.
Proof.
  revert accM; induction m; cbn; intros; trivial.
  destruct (eq_dec a x); fold (dom m) in H0.
  - exfalso; exact (H0 (or_introl H1)).
  - apply neqb_neq in H1; rewrite H1.
    fold (splitat m x); rewrite IHm; try easy.
    intros H2; exact (H0 (or_intror H2)).
Qed.
Lemma splitat_notin { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  ~ In x (dom m) ->
  splitat m x = None
.
Proof. now eapply splitat_aux_notin. Qed.
Lemma splitat_aux_in { A : Type } { H : HasEquality A } { B : Type } (accM m : mapind H B) (x : A) :
  In x (dom m) ->
  exists m1 v m2, splitat_aux accM m x = splitat_aux accM (m1 ◘ mapCons x v m2) x
.
Proof.
  revert accM; induction m; cbn; intros; try easy.
  destruct (eq_dec a x) as [H1 | H1].
  - subst; rewrite eq_refl. exists (mapNil H B). exists b. exists m. cbn. now rewrite eq_refl.
  - apply neqb_neq in H1 as H1'; rewrite H1'.
    fold (dom m) in H0; assert (In x (dom m)) by (destruct H0; congruence).
    specialize (IHm (accM ◘ mapCons a b (mapNil H B)) H2); deex.
    exists (mapCons a b m1). exists v. exists m2.
    rewrite IHm. cbn. rewrite H1'. now fold (append m1 (mapCons x v m2)).
Qed.
Lemma in_dom_split { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  nodupinv m ->
  In x (dom m) ->
  exists m1 m2 v, m = (m1 ◘ mapCons x v m2)
.
Proof.
  induction m; cbn; intros; try easy.
  destruct H1 as [H1 | H1]; fold (dom m) in H1; subst.
  - exists (mapNil H B). exists m. exists b. now cbn.
  - inv H0. specialize (IHm H6 H1); deex.
    exists (mapCons a b m1). exists m2. exists v. now rewrite IHm.
Qed.
Lemma splitat_not_none { A : Type } { H : HasEquality A } { B : Type } (accM m1 m2 : mapind H B) (x : A) (v : B) :
  splitat_aux accM (m1 ◘ mapCons x v m2) x <> None
.
Proof.
  revert accM; induction m1; cbn. now rewrite eq_refl.
  destruct (eq a x); easy.
Qed.

Lemma mset_in { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  In x (dom m) ->
  exists m__x, mset m x v = Some m__x
.
Proof.
  induction m; cbn; intros; try easy.
  destruct (eq_dec a x) as [H1 | H1].
  - subst; rewrite eq_refl; exists (mapCons x v m); easy.
  - fold (dom m) in H0; fold (mset m x v).
    apply neqb_neq in H1 as H1'; rewrite H1'.
    assert (In x (dom m)) by (destruct H0; congruence).
    specialize (IHm H2); deex. exists (mapCons a b m__x); now rewrite IHm.
Qed.
Lemma dom_in_ex { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  In x (dom m) ->
  exists m1 m2 v, m = (m1 ◘ (mapCons x v m2))
.
Proof.
  induction m; cbn; try easy.
  intros [H1|H1].
  - subst. exists (mapNil H B). do 2 eexists; cbn; eauto.
  - fold (dom m) in H1. specialize (IHm H1); deex; subst.
    exists (mapCons a b m1). exists m2. exists v. easy.
Qed.
Lemma dom_in_notin_split { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) (x : A) (v : B) :
  nodupinv (m1 ◘ (mapCons x v m2)) ->
  In x (dom (m1 ◘ mapCons x v m2)) ->
  ~ In x (dom m1) /\ ~ In x (dom m2)
.
Proof.
  induction m1; cbn; intros.
  - split; try easy. now inv H0.
  - fold (append m1 (mapCons x v m2)) in *. fold (dom m1). fold (dom (m1 ◘ mapCons x v m2)) in *.
    inv H0. destruct H1 as [H1|H1]; subst.
    exfalso. apply H4; clear. induction m1; cbn; eauto.
    specialize (IHm1 H6 H1) as [IHm1__a IHm1__b].
    split; try easy. intros H2. destruct H2; subst.
    exfalso. apply H4; clear. induction m1; cbn; eauto.
    easy.
Qed.

Lemma dom_split { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  nodupinv m ->
  In x (dom m) ->
  exists m1 m2 v, splitat m x = Some(m1, x, v, m2) /\ m = (m1 ◘ (mapCons x v m2))
.
Proof.
  intros H0 H1; apply dom_in_ex in H1 as H1'; deex.
  subst; cbn. exists m1. exists m2. exists v.
  apply dom_in_notin_split in H1 as [H2a H2b]; eauto.
  split; try now apply splitat_elim. easy.
Qed.
Lemma splitat_refl { A : Type } { H : HasEquality A } { B : Type } (m m1 m2 : mapind H B) (x : A) (v : B) :
  nodupinv m ->
  splitat m x = Some(m1, x, v, m2) ->
  m = (m1 ◘ mapCons x v m2)
.
Proof.
  destruct (in_dom_dec m x); try (apply splitat_notin in H0; intros; congruence); intros.
  apply dom_split in H0; eauto; deex. destruct H0 as [H0__a H0__b].
  subst. rewrite H0__a in H2. inv H2. easy.
Qed.

Lemma splitat_var_refl { A : Type } { H : HasEquality A } { B : Type } (m m1 m2 : mapind H B) (x y : A) (v : B) :
  nodupinv m ->
  splitat m x = Some(m1, y, v, m2) ->
  x = y
.
Proof.
  destruct (in_dom_dec m x); try (apply splitat_notin in H0; intros; congruence); intros.
  apply dom_split in H0; auto; deex.
  destruct H0 as [H0__a H0__b]; subst; rewrite H0__a in H2; inv H2; auto.
Qed.

Lemma mset_splitat { A : Type } { H : HasEquality A } { B : Type } (m1 m2 m : mapind H B) (x : A) (v b : B) :
  nodupinv(m1 ◘ (mapCons x v m2)) ->
  Some m = mset (m1 ◘ (mapCons x v m2)) x b ->
  m = (m1 ◘ (mapCons x b m2))
.
Proof.
  revert m m2; induction m1; cbn; intros.
  - rewrite eq_refl in H1. now inv H1.
  - fold (append m1 (mapCons x v m2)) in *; fold (append m1 (mapCons x b m2)) in *.
    fold (mset (m1 ◘ mapCons x v m2) x b) in H1.
    destruct (eq_dec a x) as [Hx | Hx]; subst.
    + rewrite eq_refl in H1. inv H1. inv H0. exfalso; apply H3; clear; induction m1; cbn; eauto.
    + apply neqb_neq in Hx as Hx'; rewrite Hx' in H1. inv H0.
      destruct (option_dec (mset (m1 ◘ mapCons x v m2) x b)) as [Hy | Hy]; try (rewrite Hy in H1; inv H1).
      apply not_eq_None_Some in Hy as [y__y Hy]. rewrite Hy in H1. symmetry in Hy.
      specialize (IHm1 y__y m2 H6 Hy). subst. inv H1. easy.
Qed.

Lemma dom_mset { A : Type } { H : HasEquality A } { B : Type } (m m' : mapind H B) (x : A) (v : B) :
  nodupinv m ->
  Some m' = mset m x v ->
  dom m = dom m'
.
Proof.
  destruct (in_dom_dec m x); intros.
  - apply dom_split in H0 as H3; deex; eauto; destruct H3 as [H3__a H3__b].
    subst. eapply mset_splitat in H1; eauto. rewrite H1.
    clear. induction m1; cbn; try easy; f_equal; easy.
  - eapply mset_notin in H0. rewrite H0 in H2. inv H2.
Qed.

Lemma dom_nodupinv { A : Type } { H : HasEquality A } { B : Type } (m m' : mapind H B) :
  nodupinv m ->
  dom m = dom m' ->
  nodupinv m'
.
Proof.
  revert m'; induction m; cbn; intros.
  - destruct m'; inv H1; constructor.
  - fold (dom m) in H1. assert (H1':=H1); destruct m'; inv H1; cbn in H1'.
    fold (dom m') in H1'. inv H0.
    specialize (IHm m' H6 H4).
    constructor; try easy. now rewrite <- H4.
Qed.

Lemma nodupinv_mset { A : Type } { H : HasEquality A } { B : Type } (m m' : mapind H B) (x : A) (v : B) :
  nodupinv m ->
  Some m' = mset m x v ->
  nodupinv m'
.
Proof. intros H0 H1; eauto using dom_mset, dom_nodupinv. Qed.

Ltac crush_undup M :=
  let Hx' := fresh "Hx'" in
  let Hx := fresh "Hx" in
  let x := fresh "x" in
  destruct (option_dec (undup M)) as [Hx | Hx];
  try (rewrite Hx in *; congruence);
  try (apply not_eq_None_Some in Hx as [x Hx]; eapply undup_refl in Hx as Hx'; rewrite <- Hx' in Hx; clear Hx'; rewrite Hx in *);
  match goal with
  | [H0: nodupinv ?M, H1: undup ?M = None |- context C[undup ?M]] =>
    apply nodupinv_equiv_undup in H0; congruence
  | _ => trivial
  end
.

Fixpoint Min { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (a : A) (b : B) :=
  match m with
  | mapNil _ _ => False
  | mapCons a0 b0 m' => a = a0 /\ b = b0 \/ Min m' a b
  end
.
Lemma cons_Min { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (a : A) (b : B) :
  Min (mapCons a b m) a b
.
Proof. now left. Qed.

Definition MSubset { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) : Prop :=
  forall (x : A) (v : B), Min m1 x v -> Min m2 x v
.
Definition meq { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) :=
  MSubset m1 m2 /\ MSubset m2 m1
.
Lemma meq_correct { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) :
  m1 = m2 -> meq m1 m2
.
Proof. intros H0; subst; easy. Qed.


#[global]
Instance refl_meq { A : Type } { H : HasEquality A } { B : Type } : Reflexive (@meq A H B).
Proof. intros m; split; intros Hx; auto. Qed.
#[global]
Instance trans_meq { A : Type } { H : HasEquality A } { B : Type } : Transitive (@meq A H B).
Proof. intros m1 m2 m3 [H0__a H0__b] [H1__a H1__b]; split; intros H2; auto. Qed.
#[global]
Instance symm_meq { A : Type } { H : HasEquality A } { B : Type } : Symmetric (@meq A H B).
Proof. intros m0 m1 [H0__a H0__b]; split; intros Hx; auto. Qed.
#[global]
Instance equiv_meq { A : Type } { H : HasEquality A } { B : Type } : Equivalence (@meq A H B).
Proof. split; try exact refl_meq; try exact trans_meq; exact symm_meq. Qed.

#[global]
Instance trans_msubset { A : Type } { H : HasEquality A } { B : Type } : Transitive (@MSubset A H B).
Proof. intros m1 m2 m3 H0 H1 x v F0; auto. Qed.
#[global]
Instance refl_msubset { A : Type } { H : HasEquality A } { B : Type } : Reflexive (@MSubset A H B).
Proof. intros m x v H0; auto. Qed.

Lemma Min_in { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  Min m x v -> In x (dom m) /\ In v (img m)
.
Proof.
  induction m; cbn; intros; try easy.
  destruct H0 as [[H0__a H0__b] | H0]; subst; fold (img m); fold (dom m).
  - split; now left.
  - split; right; apply IHm; auto.
Qed.
Lemma cons_msubset { A : Type } { H : HasEquality A } { B : Type } (m m' : mapind H B) (x : A) (v : B) :
  Some m' = (x ↦ v ◘ m) ->
  MSubset m m'.
Proof.
  intros H0 a b H1. symmetry in H0. apply push_ok in H0 as H0'.
  unfold "_ ↦ _ ◘ _" in H0.
  crush_undup (mapCons x v m); inv H0. now right.
Qed.

Lemma msubset_split { A : Type } { H : HasEquality A } { B : Type } (m1 m2 m' : mapind H B) :
  MSubset (m1 ◘ m2) m' <->
  MSubset m1 m' /\ MSubset m2 m'
.
Proof. 
  split.
  - induction m1, m2.
    + easy. 
    + easy. 
    + simpl.
      split.
      * rewrite append_nil in H0.
        easy.
      * easy.
    + admit.
  - induction m1, m2.
    + easy.
    + easy.
    + simpl.
      intros.
      rewrite append_nil.
      easy.
    + admit.       
Admitted.

Lemma mget_min {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  mget m x = Some v -> Min m x v
.
Proof.
  induction m; cbn; try easy.
  fold (mget m x). intros H0.
  destruct (eq_dec a x); subst.
  - rewrite eq_refl in H0; inv H0; now left.
  - apply neqb_neq in H1; rewrite H1 in H0. right; auto.
Qed.

Lemma delete_subsets {A : Type} { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) (x : A) :
  MSubset m1 m2 ->
  MSubset (delete m1 x) (delete m2 x)
.
Proof. Admitted.      
Lemma cons_delete_nodupinv {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  nodupinv m ->
  nodupinv (mapCons x v (delete m x))
.
Proof. Admitted.

Lemma delete_nodupinv {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  nodupinv m ->
  nodupinv (delete m x)
.
Proof. Admitted.

Lemma delete_delete {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  delete (delete m x) x = delete m x
.
Proof. Admitted.

Lemma delete_middle {A : Type} { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) (a : A) (b : B) :
  delete (append m1 (mapCons a b m2)) a = append m1 m2
.
Proof. Admitted.

Lemma delete_delete_sym {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x x0 : A) :
  delete (delete m x) x0 = delete (delete m x0) x
.
Proof. Admitted.

Lemma delete_min {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (a a0 : A) (b : B) :
  Min (delete m a) a0 b ->
  Min m a0 b
.
Proof. Admitted.

Lemma delete_works {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) :
  In x (dom (delete m x)) -> False
.
Proof. Admitted.
Lemma delete_notin {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x y : A) :
  x <> y ->
  ~ In x (dom m) ->
  ~ In x (dom (delete m y))
.
Proof. Admitted.

Lemma delete_subset_identity {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (a : A) (b : B) :
  MSubset m (mapCons a b (delete m a))
.
Proof. Admitted.

Lemma min_mget {A : Type} { H : HasEquality A } { B : Type } (m : mapind H B) (x : A) (v : B) :
  nodupinv m ->
  Min m x v ->
  mget m x = Some v
.
Proof.
  induction m; try easy; intros.
  inv H0. destruct (eq_dec a x).
  - subst. destruct H1 as [[H1a H1b] | H1].
    + subst. cbn. now rewrite eq_refl.
    + apply Min_in in H1 as [H1a H1b]. contradiction.
  - destruct H1 as [[H1a H1b] | H1]; try congruence.
    apply neqb_neq in H0; cbn; rewrite H0; auto.
Qed.

Lemma nodupinv_subset {A : Type} { H : HasEquality A } { B : Type } (m m' : mapind H B) :
  nodupinv m' ->
  MSubset m m' ->
  nodupinv m
.
Proof. Admitted.      
      
Lemma mget_subset {A : Type} { H : HasEquality A } { B : Type } (m m' : mapind H B) (x : A) (v : B) :
  nodupinv m' ->
  mget m x = Some v ->
  MSubset m m' ->
  mget m' x = Some v
.
Proof. intros Ha Hb Hc; specialize (Hc x v) as Hc'. apply mget_min in Hb. apply min_mget; eauto using nodupinv_subset. Qed.

Lemma nodupinv_cons {A : Type} { H : HasEquality A} {B : Type} (x : A) (b : B) (m : mapind H B) :
  Util.nodupinv (mapCons x b m) ->
  Util.nodupinv m.
Proof.
  intros.
  inversion H0.
  apply H5.
Qed.

Lemma splitat_aux_cons {A : Type} {H : HasEquality A} {B : Type} (m m1 m2 : mapind H B) (x a : A) (y b : B) :
  forall (m0 ma : mapind H B),
    Util.nodupinv (mapCons a b m) ->
    a <> x ->
    splitat_aux m0 (mapCons a b m) x = Some (m1, x, y, m2) ->
    splitat_aux m0 m x = Some (delete m1 a, x, y, m2).
Proof. Admitted.

Lemma nodupinv_cons_notin {A : Type} {H : HasEquality A} {B : Type} (m : mapind H B) (x : A) (y : B) :
  Util.nodupinv (mapCons x y m) ->
  ~ In x (dom m).
Proof. Admitted.    

Lemma dom_notin_delete {A : Type} {H : HasEquality A} {B : Type} (m : mapind H B) (a : A) :
    ~ In a (dom m) -> 
    delete m a = m.
Proof. Admitted.
  
Lemma mget_splitat_same_el {A : Type} { H : HasEquality A } { B : Type } (m m1 m2 : mapind H B) (x : A) (a b : B) :
  forall (m0 : mapind H B),
  Util.nodupinv m ->
  mget m x = Some a ->
  splitat_aux m0 m x = Some (m1, x, b, m2) ->
  a = b
.
Proof.
  intros.
  induction H0.
  - easy.
  - pose proof (@nodupmapCons A H B a0 b0 m) as G.
    apply G in H0.
    destruct (eq_dec a0 x).
    + cbn in *; rewrite H4 in *; rewrite eq_refl in *; cbn in *.
      inversion H1; rewrite <- H6; inversion H2.
      easy.
    + apply neqb_neq in H4.
      cbn in H1.
      rewrite H4 in *.
      destruct m.
      * easy.
      * apply splitat_aux_cons in H2; try easy.
        -- apply IHnodupinv; try easy.
           rewrite dom_notin_delete in H2.
           ++ easy.
           ++ admit.
        -- rewrite neqb_neq in H4. 
           easy.
    + easy.
Admitted.

End Util.

#[global]
Notation "a '↦' b '◘' M" := (mapCons a b M) (at level 81, b at next level).
#[global]
Notation "M1 '◘' M2" := (append M1 M2) (at level 82, M2 at next level).

Lemma notin_dom_split { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) (x : A) (v : B) :
  ~ In x (dom(m1 ◘ m2)) ->
  ~ In x (dom m1) /\ ~ In x (dom m2)
.
Proof.
  remember (m1 ◘ m2) as m0; revert m1 m2 Heqm0; induction m0; cbn; intros m1 m2 Heqm0 H0.
  - destruct m1, m2; inv Heqm0; split; intros [].
  - destruct (eq_dec a x); subst.
    + exfalso; exact (H0 (or_introl Logic.eq_refl)).
    + destruct m1, m2; cbn in Heqm0.
      * inv Heqm0.
      * inv Heqm0; cbn; split; easy.
      * fold (append m1 (mapNil _ _)) in Heqm0. fold (dom m0) in H0.
        rewrite append_nil in Heqm0. split; inv Heqm0; cbn; easy.
      * fold (append m1 (a1 ↦ b1 ◘ m2)) in Heqm0.
        fold (dom m0) in H0.
        inv Heqm0.
        assert (~ In x (dom(m1 ◘ a1 ↦ b1 ◘ m2))).
        intros X; specialize (H0 (or_intror X)); easy.
        specialize (IHm0 m1 (a1 ↦ b1 ◘ m2) Logic.eq_refl H2).
        destruct (IHm0) as [IHm0a IHm0b]; split; try easy.
        intros []; subst; easy.
Qed.
Lemma nodupinv_split { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) :
  nodupinv (m1 ◘ m2) ->
  nodupinv m1 /\ nodupinv m2
.
Proof.
  remember (m1 ◘ m2) as m0; revert m1 m2 Heqm0; induction m0; cbn; intros m m' Heqm0 H'; inv H'.
  - inv Heqm0; destruct m, m'; inv H1; split; constructor.
  - destruct m; inv Heqm0.
    + split; cbn in H0; inv H0; now constructor.
    + destruct (IHm0 m m' Logic.eq_refl H4) as [IHm0__a IHm0__b].
      split; trivial; constructor; trivial.
      apply notin_dom_split in H2 as [H2__a H2__b]; trivial.
Qed.
Lemma nodupinv_cons_snoc { A : Type } { H : HasEquality A } { B : Type } (m : mapind H B) (a : A) (b : B) :
  nodupinv (a ↦ b ◘ m) <-> nodupinv (m ◘ a ↦ b ◘ mapNil H B)
.
Proof.
  revert a b; induction m; intros; cbn; try easy.
  fold (append m (a0 ↦ b0 ◘ mapNil H B)).
  split; intros H0.
  - inv H0. constructor.
    + intros H1. inv H5. apply H4. revert H3 H1; clear; intros.
      destruct (eq_dec a0 a); subst.
      * exfalso; apply H3; now left.
      * clear H3. induction m; cbn in *.
        -- destruct H1; eauto.
        -- fold (dom m) in *. fold (m ◘ (a0 ↦ b0 ◘ mapNil H B)) in *.
           fold (dom (m ◘ a0 ↦ b0 ◘ mapNil H B)) in *.
           destruct H1; eauto.
    + apply IHm. inv H5. constructor; try easy. revert H3; clear; intros H0 H1; apply H0; now right.
  - inv H0. apply IHm in H5. inv H5. constructor.
    + intros H1. destruct (eq_dec a0 a); subst.
      * apply H3; clear; induction m; cbn; eauto.
      * destruct H1; congruence.
    + constructor; eauto. intros H1. apply H3; revert H1; clear; intros.
      induction m; cbn in *; eauto. fold (dom m) in *.
      fold (m ◘ (a0 ↦ b0 ◘ mapNil H B)). fold (dom (m ◘ (a0 ↦ b0 ◘ mapNil H B))).
      destruct H1; subst; eauto.
Qed.

Lemma nodupinv_swap { A : Type } { H : HasEquality A } { B : Type } (m1 m2 : mapind H B) :
  nodupinv (m1 ◘ m2) <-> nodupinv (m2 ◘ m1)
.
Proof.
  revert m2; induction m1; cbn; intros.
  - now rewrite append_nil.
  - fold (append m1 m2).
    change ((nodupinv ((a ↦ b ◘ m1) ◘ m2)) <-> (nodupinv (m2 ◘ a ↦ b ◘ m1))).
    split; intros H0.
    + change (nodupinv (m2 ◘ ((a ↦ b ◘ (mapNil H B)) ◘ m1))).
      rewrite <- append_assoc. apply IHm1. rewrite <- append_assoc. now apply nodupinv_cons_snoc.
    + change (nodupinv (m2 ◘ ((a ↦ b ◘ (mapNil H B)) ◘ m1))) in H0.
      rewrite <- append_assoc in H0. apply IHm1 in H0. rewrite <- append_assoc in H0. now apply nodupinv_cons_snoc.
Qed.

Module NoDupList.

Inductive nodupinv {A : Type} {H : HasEquality A} : list A -> Prop :=
| nodupinvNil : nodupinv (List.nil)
| nodupinvCons : forall (x : A) (xs : list A),
    ~(List.In x xs) ->
    nodupinv xs ->
    nodupinv (List.cons x xs)
.
Fixpoint undup {A : Type} {H : HasEquality A} (xs : list A) : option(list A) :=
  match xs with
  | List.nil => Some(List.nil)
  | List.cons x xs' =>
    match List.find (fun y => eq x y) xs', undup xs' with
    | None, Some xs' => Some(List.cons x xs')
    | _, _ => None
    end
  end
.
Fixpoint swap_nth_aux { A : Type } { H : HasEquality A } (xs : list A) (n : nat) (y : A) : option (list A) :=
  match n, xs with
  | 0, nil => None
  | S n, nil => None
  | 0, x :: xs => Some(y :: xs)
  | S n, x :: xs =>
    let* ys := swap_nth_aux xs n y in
    Some(x :: ys)
  end
.
Definition swap_nth {A : Type} { H : HasEquality A } (xs : list A) (n : nat) (y : A) : option (list A) :=
  let* result := swap_nth_aux xs n y in
  undup result
.

Lemma undup_refl {A : Type} {H : HasEquality A} (xs ys : list A) :
  undup xs = Some ys -> xs = ys.
Proof.
  revert ys; induction xs; intros ys H0.
  - now inv H0.
  - cbn in H0. destruct (option_dec (List.find (fun y : A => eq a y) xs)) as [Hx|Hy].
    + apply not_eq_None_Some in Hx as [zs Hx]; rewrite Hx in H0; congruence.
    + rewrite Hy in H0; destruct (option_dec (undup xs)) as [Ha|Hb].
      * apply not_eq_None_Some in Ha as [ys' Ha]; rewrite Ha in H0; rewrite (IHxs ys' Ha); now inv H0.
      * rewrite Hb in H0; congruence.
Qed.
Lemma nodupinv_equiv_undup {A : Type} {H : HasEquality A} (xs : list A) :
  undup xs = Some xs <-> nodupinv xs.
Proof.
  induction xs; cbn; split; try easy.
  - constructor.
  - intros H0; destruct (option_dec (List.find (fun y : A => eq a y) xs)) as [Hx | Hy].
    apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H0; inv H0.
    rewrite Hy in H0.
    destruct (option_dec (undup xs)) as [Hx | Hy']; try rewrite Hy' in H0; inv H0.
    apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H2; inv H2.
    constructor; try apply IHxs; eauto.
    intros Ha. eapply List.find_none in Hy; eauto. apply neqb_neq in Hy; contradiction.
  - intros H0; inv H0; destruct (option_dec (List.find (fun x : A => eq a x) xs)) as [Hx | Hy].
    apply not_eq_None_Some in Hx as [a' Hx].
    apply List.find_some in Hx as [Hx1 Hx2].
    rewrite eqb_eq in Hx2; subst; contradiction.
    rewrite Hy. destruct (option_dec (undup xs)) as [Hx | Hy'].
    apply not_eq_None_Some in Hx as [m'' Hx]. rewrite Hx. f_equal. f_equal. apply undup_refl in Hx; easy.
    apply IHxs in H4. congruence.
Qed.

Definition push { A : Type } { H : HasEquality A } (x : A) (xs : list A) : option (list A) :=
  match undup (List.cons x xs) with
  | Some xs' => Some xs'
  | None => None
  end
.
Lemma push_refl { A : Type } { H : HasEquality A } (x : A) (xs ys : list A) :
  push x xs = Some ys -> cons x xs = ys.
Proof.
  intros H0; unfold push in H0; destruct (option_dec (undup xs)) as [Hx|Hy].
  - apply not_eq_None_Some in Hx as [zs Hx]. cbn in H0. rewrite (undup_refl xs Hx) in *.
    destruct (option_dec (List.find (fun y : A => eq x y) zs)) as [Ha|Hb].
    + apply not_eq_None_Some in Ha as [ws Ha]. now rewrite Ha in H0.
    + rewrite Hb in H0. rewrite <- (undup_refl xs Hx) in H0. rewrite Hx in H0. now inv H0.
  - cbn in H0. destruct (option_dec (List.find (fun y : A => eq x y) xs)) as [Ha|Hb].
    + apply not_eq_None_Some in Ha as [ws Ha]. now rewrite Ha in H0.
    + now rewrite Hb, Hy in H0.
Qed.
Lemma push_ok' { A : Type } { H : HasEquality A } (x : A) (xs ys : list A) :
  push x xs = Some (ys) -> nodupinv (ys).
Proof.
  intros H0. unfold push in H0.
  destruct (option_dec (undup (x :: xs))) as [Hx|Hy]; try (rewrite Hy in *; congruence);
  apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H0; inv H0;
  apply nodupinv_equiv_undup; cbn in Hx.
  destruct (option_dec (List.find (fun y : A => eq x y) xs)) as [Ha|Hb].
  - apply not_eq_None_Some in Ha as [ys' Ha]; now rewrite Ha in Hx.
  - rewrite Hb in Hx.
    destruct (option_dec (undup xs)) as [Hc|Hd].
    + apply not_eq_None_Some in Hc as [ws Hc]; apply undup_refl in Hc as Hc'; rewrite Hc in *;
      inv Hx; cbn; rewrite Hb; now rewrite Hc.
    + now rewrite Hd in Hx.
Qed.
Lemma push_ok { A : Type } { H : HasEquality A } (x : A) (xs : list A) :
  push x xs = Some (List.cons x xs) -> nodupinv (List.cons x xs).
Proof.
  intros H0. unfold push in H0.
  destruct (option_dec (undup (List.cons x xs))) as [Hx|Hy]; try (rewrite Hy in *; congruence);
  apply not_eq_None_Some in Hx as [m'' Hx]; rewrite Hx in H0; inv H0;
  apply nodupinv_equiv_undup; cbn in Hx.
  destruct (option_dec (List.find (fun y : A => eq x y) xs)) as [Ha|Hb].
  - apply not_eq_None_Some in Ha as [ys Ha]; now rewrite Ha in Hx.
  - rewrite Hb in Hx.
    destruct (option_dec (undup xs)) as [Hc|Hd].
    + apply not_eq_None_Some in Hc as [ws Hc]; apply undup_refl in Hc as Hc'; rewrite Hc in *;
      inv Hx; cbn; rewrite Hb; now rewrite Hc.
    + now rewrite Hd in Hx.
Qed.
Lemma swap_ok { A : Type } { H : HasEquality A } (x : A) (n : nat) (xs ys : list A) :
  nodupinv xs ->
  swap_nth xs n x = Some ys ->
  nodupinv ys
.
Proof.
  revert x ys n; induction xs; cbn; intros.
  - now destruct n.
  - destruct n.
    + apply undup_refl in H1 as H1'; rewrite <- H1' in *; clear H1'. apply nodupinv_equiv_undup in H1.
      inv H0; inv H1. now constructor.
    + cbn in *. crush_option (swap_nth_aux xs n x). inv H0. specialize (IHxs x x0 n H5). rewrite Hx in IHxs.
      apply undup_refl in H1 as H1'. rewrite <- H1' in H1.
      apply nodupinv_equiv_undup in H1. inv H1. apply nodupinv_equiv_undup in H6. specialize (IHxs H6).
      constructor; easy.
Qed.
Lemma swap_split { A : Type } { H : HasEquality A } (x y : A) (n : nat) (xs ys : list A) :
  nodupinv xs ->
  swap_nth xs n x = Some ys ->
  exists ys1 ys2, ys = ys1 ++ y :: ys2 /\
             xs = ys1 ++ x :: ys2 /\
             List.length ys1 = n /\
             List.length ys2 = List.length xs - n + 1 /\
             nodupinv ys
.
Proof. Admitted.
    
End NoDupList.

#[global]
Ltac crush_undup M :=
  let Hx' := fresh "Hx'" in
  let Hx := fresh "Hx" in
  let x := fresh "x" in
  destruct (option_dec (undup M)) as [Hx | Hx];
  try (rewrite Hx in *; congruence);
  try (apply not_eq_None_Some in Hx as [x Hx]; eapply undup_refl in Hx as Hx'; rewrite <- Hx' in Hx; clear Hx'; rewrite Hx in *);
  match goal with
  | [H0: nodupinv ?M, H1: undup ?M = None |- context C[undup ?M]] =>
    apply nodupinv_equiv_undup in H0; congruence
  | _ => trivial
  end
.
#[global]
Ltac recognize_split :=
  match goal with
  | [H: context C[splitat ?M ?x] |- _] =>
    let Hy := fresh "Hy" in
    let H0 := fresh "H" in
    destruct (in_dom_dec M x) as [Hy | Hy];
    try (apply splitat_notin in Hy; rewrite Hy in H; inv H);
    try (apply in_dom_split in Hy as H0; eauto; deex; rewrite H0 in H)
  | [H: nodupinv ?Γ |- context C[splitat ?M ?x]] =>
    let Hy := fresh "Hy" in
    let H0 := fresh "H" in
    destruct (in_dom_dec M x) as [Hy | Hy];
    try (apply splitat_notin in Hy; apply splitat_elim in H; congruence);
    try (apply in_dom_split in Hy as H0; eauto; deex; rewrite H0)
  end.
#[global]
Ltac elim_split :=
  match goal with
  | [H0: context C[splitat ?M ?x],
     H1: ?M' = ?M,
     H2: nodupinv ?M'
     |- _] =>
     let H2' := fresh "H'" in
     assert (H2':=H2); rewrite H1 in H2'; apply splitat_elim in H2'; auto; rewrite H2' in H0
  | [H1: ?M' = ?M, H2: nodupinv ?M' |- context C[splitat ?M]] =>
     let H2' := fresh "H'" in
     assert (H2':=H2); rewrite H1 in H2'; apply splitat_elim in H2'; auto; rewrite H2'
  end
.
