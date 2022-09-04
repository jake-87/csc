Set Implicit Arguments.
Require Import Strings.String Strings.Ascii Numbers.Natural.Peano.NPeano Lists.List Program.Equality Recdef.
Require Import CSC.Sets CSC.Util CSC.Fresh.

(** * Syntax *)

(** The type used for variable names. *)
Definition vart := string.
Definition vareq := fun x y => (x =? y)%string.
Definition dontcare := "_"%string.

(** The only values we have in S are natural numbers. *)
Inductive value : Type :=
| Vnat : nat -> value
.
Coercion Vnat : nat >-> value.
(** Locerences are not values. In fact, they cannot be represented syntactically. *)
Inductive loc : Type :=
| addr : nat -> loc
.
Definition loc_eqb :=
  fun ℓ1 ℓ2 =>
    match ℓ1, ℓ2 with
    | addr n1, addr n2 => Nat.eqb n1 n2
    end
.
(** Final Result (without error) *)
Inductive fnoerr : Type :=
| Fval : value -> fnoerr
| Fvar : vart -> fnoerr
.
Coercion Fval : value >-> fnoerr.
(** Final Result (with error) *)
Inductive ferr : Type :=
| Fres : fnoerr -> ferr
| Fabrt : ferr
.
Coercion Fres : fnoerr >-> ferr.
(** Possible binary operations. *)
Variant binopsymb : Type :=
| BAdd : binopsymb
| BSub : binopsymb
| Bmul : binopsymb
| Bless : binopsymb
.
(** Pointer Type Qualifiers *)
Inductive qual : Type :=
| Qfull : qual
| Qhalf : qual
.
(** Types of S *)
Inductive ty : Type :=
| Tnat : ty
| Tnatptr : qual -> ty
.
Notation "'Tptr'" := (Tnatptr Qfull).
Notation "'Twptr'" := (Tnatptr Qhalf).
Inductive expr : Type :=
| Xres (f : ferr) : expr
| Xbinop (symb : binopsymb) (lhs rhs : expr) : expr
| Xget (x : vart) (e : expr) : expr
| Xset (x : vart) (e0 e1 : expr) : expr
| Xlet (x : vart) (e0 e1 : expr) : expr
| Xnew (x : vart) (e0 e1 : expr) : expr
| Xdel (x : vart) : expr
| Xreturning (e : expr) : expr
| Xcalling (e : expr) : expr
| Xifz (c e0 e1 : expr) : expr
| Xabort : expr
| Xhole (x : vart) (τ1 τ2 : ty) : expr
.
Coercion Xres : ferr >-> expr.

(** The following is a helper function to easily define functions over the syntax of S, e.g. substitution. *)
Definition exprmap (h : expr -> expr) (e : expr) :=
  match e with
  | Xbinop b lhs rhs => Xbinop b (h lhs) (h rhs)
  | Xget x e => Xget x (h e)
  | Xset x e0 e1 => Xset x (h e0) (h e1)
  | Xlet x e0 e1 => Xlet x (h e0) (h e1)
  | Xnew x e0 e1 => Xnew x (h e0) (h e1)
  | Xreturning e => Xreturning (h e)
  | Xcalling e => Xcalling (h e)
  | Xifz c e0 e1 => Xifz (h c) (h e0) (h e1)
  | _ => e
  end
.

(** * Freshness *)

(** In here, we define a helper judgement that gives us fresh variables. *)
Inductive fresh (A : Type) (eq : A -> A -> bool) (xs : list A) (x : A) : Prop :=
| Cfresh : List.find (eq x) xs = (None : option A) -> @fresh A eq xs x
.
Definition fresh_loc := @fresh loc loc_eqb.
Definition fresh_tvar := @fresh string String.eqb.

(** * Dynamics *)

(** Evaluation of binary expressions. Note that 0 means `true` in S, so `5 < 42` evals to `0`. *)
Definition eval_binop (b : binopsymb) (v0 v1 : value) :=
  let '(Vnat n0) := v0 in
  let '(Vnat n1) := v1 in
  Vnat(match b with
       | Bless => (if Nat.ltb n0 n1 then 0 else 1)
       | BAdd => (n0 + n1)
       | BSub => (n0 - n1)
       | BMul => (n0 * n1)
       end)
.
(** Poison used to mark locations in our operational state. *)
Inductive poison : Type :=
| poisonless : poison
| poisoned : poison
.
Notation "'◻'" := (poisonless).
Notation "'☣'" := (poisoned).

Definition dynloc : Type := loc * poison.
(* '⋅' is `\cdot` *)
Notation "ℓ '⋅' ρ" := (((ℓ : loc), (ρ : poison)) : dynloc) (at level 81).

(** Stores map variables to potentially poisoned locations. *)
Inductive store : Type :=
| Snil : store
| Scons (x : vart) (ℓ : dynloc) (Δ : store) : store
.
Fixpoint Δdom (Δ : store) : list vart :=
  match Δ with
  | Snil => nil
  | Scons x ℓ Δ' => cons x (Δdom Δ')
  end
.
Fixpoint Δimg (Δ : store) : list loc :=
  match Δ with
  | Snil => nil
  | Scons x (ℓ,_) Δ' => cons ℓ (Δimg Δ')
  end
.
(* '↦' is `\mapsto` and '◘' is `\inversebullet`*)
Notation "x '↦' dl '◘' Δ" := (Scons x (dl : dynloc) Δ) (at level 81, dl at next level).
Fixpoint append (Δ1 Δ2 : store) : store :=
  match Δ1 with
  | Snil => Δ2
  | Scons x ℓ Δ1' => x ↦ ℓ ◘ (append Δ1' Δ2)
  end
.
(* '◘' is `\inversebullet` *)
Notation "Δ1 '◘' Δ2" := (append Δ1 Δ2) (at level 82, Δ2 at next level).
(** Splitting a store in three parts. *)
Definition splitat (Δ : store) (x : vart) : option (store * vart * dynloc * store) :=
  let fix doo (accΔ : store) (Δ : store) :=
    match Δ with
    | Snil => None
    | Scons y dℓ Δ' => if vareq x y then
                        Some(accΔ, y, dℓ, Δ')
                      else
                        doo (y ↦ dℓ ◘ accΔ) Δ'
    end
  in doo Snil Δ
.
(** In this model, heaps are just a snoc-style list of natural numbers. *)
Inductive heap : Type :=
| Hnil : heap
| Hcons (H : heap) (n : nat) : heap
.
Fixpoint Hsize (H : heap) : nat :=
  match H with
  | Hnil => 0
  | Hcons H' _ => 1 + Hsize H'
  end
.
Fixpoint Hget (H : heap) (i : nat) : option nat :=
  match H with
  | Hnil => None
  | Hcons H' m =>
      match i with
      | 0 => Some m
      | S j => Hget H' j
      end
  end
.
Fixpoint Hset (H : heap) (i v : nat) : option heap :=
  match H with
  | Hnil => None
  | Hcons H' m =>
      match i with
      | 0 => Some(Hcons H' v)
      | S j => match Hset H' j v with
              | None => None
              | Some H'' => Some(Hcons H'' m)
              end
      end
  end
.
Fixpoint Hgrow (H : heap) (s : nat) : heap :=
  match s with
  | 0 => H
  | S s' => Hcons (Hgrow H s') 0
  end
.
Definition state : Type := CSC.Fresh.fresh_state * heap * store.
Notation "F ';' H ';' Δ" := ((F : CSC.Fresh.fresh_state), (H : heap), (Δ : store)) (at level 81, H at next level, Δ at next level).

Inductive context (e0 e1 : expr) : Type := Ccontext.
Inductive component (ep : expr) : Type := Ccomponent.
Inductive prog (e0 ep e1 : expr) : Type := Cprog.

(** Types of events that may occur in a trace. *)
Variant event : Type :=
| Sε : event
| Salloc (ℓ : loc) (n : nat) : event
| Sdealloc (ℓ : loc) : event
| Sget (ℓ : loc) (n : nat) : event
| Sset (ℓ : loc) (n : nat) (v : value) : event
| Scrash : event
| Scall (f : fnoerr) : event
| Sret (f : fnoerr) : event
.
Definition tracepref := CSC.Util.tracepref event.
Definition Tnil := CSC.Util.Tnil event.
Definition Tcons (a : event) (t : tracepref) := @CSC.Util.Tcons event a t.

(** The typecheck performed in the notations may seem redundant,
    but it seems to be necessary to discharge the coercsions. *)
(* '·' is `\cdotp` *)
Notation "As '·' Bs" := (@CSC.Util.Tappend event (As : tracepref) (Bs : tracepref)) (at level 81).

Definition event_to_tracepref (e : event) : tracepref := @CSC.Util.ev_to_tracepref event e.
Coercion event_to_tracepref : event >-> tracepref.

(** Pretty-printing function for better debuggability *)
Definition string_of_event (e : event) :=
  match e with
  | Sε => "ε"%string
  | Salloc (addr ℓ) n => String.append
                          (String.append ("Alloc ℓ"%string) (string_of_nat ℓ))
                          (String.append (" "%string) (string_of_nat n))
  | Sdealloc (addr ℓ) => String.append ("Dealloc ℓ"%string) (string_of_nat ℓ)
  | Sget (addr ℓ) n => String.append
                        (String.append ("Get ℓ"%string) (string_of_nat ℓ))
                        (String.append (" "%string) (string_of_nat n))
  | Sset (addr ℓ) n (Vnat m) => String.append
                                 (String.append
                                   (String.append ("Set ℓ"%string) (string_of_nat ℓ))
                                   (String.append (" "%string) (string_of_nat n)))
                                 (String.append (" "%string) (string_of_nat m))
  | Scrash => "↯"%string
  | Scall(Fval(Vnat n)) => String.append ("Call ?"%string) (string_of_nat n)
  | Scall(Fvar x) => String.append ("Call ?"%string) x
  | Sret(Fval(Vnat n)) => String.append ("Ret !"%string) (string_of_nat n)
  | Sret(Fvar x) => String.append ("Ret !"%string) x
  end
.
Fixpoint string_of_tracepref_aux (t : tracepref) (acc : string) : string :=
  match t with
  | @CSC.Util.Tnil _ => acc
  | @CSC.Util.Tcons _ a (@CSC.Util.Tnil _) => String.append acc (string_of_event a)
  | @CSC.Util.Tcons _ a As =>
      let acc' := String.append acc (String.append (string_of_event a) (" · "%string))
      in string_of_tracepref_aux As acc'
  end
.
Definition string_of_tracepref (t : tracepref) : string := string_of_tracepref_aux t (""%string).

(** A runtime program is a state plus an expression. *)
Definition rtexpr : Type := (option state) * expr.
(* '▷' is `\triangleright and '↯' is `\lightning`` *)
Notation "Ω '▷' e" := ((((Some (Ω)) : option state), (e : expr)) : rtexpr) (at level 81).
Notation "↯ '▷' 'stuck'" := (((None : option state), (Fabrt : expr)) : rtexpr).

(** Substitution, which assumes that the given expression is closed. *)
Definition subst (what : vart) (inn forr : expr) : expr :=
  let substid := match forr with
                 | Xres(Fres(Fvar y)) => Some y
                 | _ => None
                 end
  in
  let fix isubst e :=
    let R := isubst in
    match e with
    | Xlet x e0 e1 => if vareq what x then Xlet x (R e0) e1 else Xlet x (R e0) (R e1)
    | Xnew x e0 e1 => if vareq what x then Xnew x (R e0) e1 else Xnew x (R e0) (R e1)
    | Xget x e' => match substid with
                  | None => Xget x
                  | Some y => Xget y
                  end (R e')
    | Xset x e0 e1 => match substid with
                     | None => Xset x
                     | Some y => Xset y
                     end (R e0) (R e1)
    | Xdel x => match substid with
               | None => Xdel x
               | Some y => Xdel y
               end
    | Xres(Fres(Fvar x)) => if vareq what x then forr else e
    | Xhole x τ1 τ2 => match substid with
                      | None => Xhole x
                      | Some y => Xhole y
                      end τ1 τ2
    | Xbinop b e1 e2 => Xbinop b (R e1) (R e2)
    | Xifz c e1 e2 => Xifz (R c) (R e1) (R e2)
    | Xreturning e => Xreturning (R e)
    | Xcalling e => Xcalling (R e)
    | _ => e
    end
  in
  isubst inn
.

Reserved Notation "r0 '--[' a ']-->' r1" (at level 82, r1 at next level).
Inductive pstep : rtexpr -> event -> rtexpr -> Prop :=
| e_returning : forall (Ω : state) (f : fnoerr),
    Ω ▷ Xreturning f --[ Sret f ]--> Ω ▷ f
| e_calling : forall (Ω : state) (f : fnoerr),
    Ω ▷ Xcalling f  --[ Scall f ]--> Ω ▷ f
| e_binop : forall (Ω : state) (n1 n2 n3 : nat) (b : binopsymb),
    Vnat n3 = eval_binop b n1 n2 ->
    Ω ▷ Xbinop b n1 n2 --[ Sε ]--> Ω ▷ n3
| e_ifz_true : forall (Ω : state) (e1 e2 : expr),
    Ω ▷ Xifz 0 e1 e2 --[ Sε ]--> Ω ▷ e1
| e_ifz_false : forall (Ω : state) (e1 e2 : expr) (n : nat),
    Ω ▷ Xifz (S n) e1 e2 --[ Sε ]--> Ω ▷ e2
| e_abort : forall (Ω : state),
    Ω ▷ Xabort --[ Scrash ]--> ↯ ▷ stuck
| e_get : forall (F : CSC.Fresh.fresh_state) (H : heap) (Δ1 Δ2 : store) (x : vart) (ℓ n v : nat) (ρ : poison),
    forall (H0a : ℓ + n < Hsize H -> Some v = Hget H (ℓ + n))
      (H0b : ℓ + n >= Hsize H -> v = 1729),
    (F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2)) ▷ Xget x n --[ Sget (addr ℓ) n ]--> (F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2)) ▷ v
| e_set : forall (F : CSC.Fresh.fresh_state) (H H' : heap) (Δ1 Δ2 : store) (x : vart) (ℓ n v : nat) (ρ : poison),
    forall (H0a : ℓ + n < Hsize H -> Some H' = Hset H (ℓ + n) v)
      (H0b : ℓ + n >= Hsize H -> H' = H),
    (F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2)) ▷ Xset x n v --[ Sset (addr ℓ) n v ]--> (F ; H' ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2)) ▷ v
| e_delete : forall (F : CSC.Fresh.fresh_state) (H : heap) (Δ1 Δ2 : store) (x : vart) (ℓ : nat) (ρ : poison),
    (F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2)) ▷ Xdel x --[ Sdealloc (addr ℓ) ]--> (F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ☣) ◘ Δ2)) ▷ 0
| e_let : forall (Ω : state) (x : vart) (f : fnoerr) (e e' : expr),
    e' = subst x e f ->
    Ω ▷ Xlet x f e --[ Sε ]--> Ω ▷ e'
| e_alloc : forall (F F' F'' : CSC.Fresh.fresh_state) (H H' : heap) (Δ : store) (x z : vart) (ℓ n : nat) (e : expr),
    ℓ = Fresh.fresh F ->  F' = Fresh.advance F ->
    z = Fresh.freshv F' -> F'' = Fresh.advance F' ->
    (*TODO: fresh_loc (Δimg Δ) (addr ℓ) ->*)
    (*fresh_tvar (Δdom Δ) z ->*)
    H' = Hgrow H n ->
    (F ; H ; Δ) ▷ Xnew x n e --[ Salloc (addr ℓ) n ]--> (F'' ; H' ; (z ↦ ((addr ℓ) ⋅ ◻) ◘ Δ)) ▷ (subst x e (Fvar z))
where "r0 '--[' a ']-->' r1" := (pstep r0 a r1)
.
#[global]
Hint Constructors pstep : core.

(** functional version of the above *)
Definition pstepf (r : rtexpr) : option (event * rtexpr) :=
  let '(oΩ, e) := r in
  match oΩ with
  | None => None
  | Some Ω =>
    match e with
    | Xreturning F => (* e-returning *)
      match F with
      | Xres(Fres f) =>
        Some(Sret f, Ω ▷ F)
      | _ => None
      end
    | Xcalling F => (* e-calling *)
      match F with
      | Xres(Fres f) =>
        Some(Scall f, Ω ▷ F)
      | _ => None
      end
    | Xbinop b n1 n2 => (* e-binop *)
      match n1, n2 with
      | Xres(Fres(Fval(Vnat m1))), Xres(Fres(Fval(Vnat m2))) =>
        let n3 := eval_binop b m1 m2 in
        Some(Sε, Ω ▷ n3)
      | _, _ => None
      end
    | Xifz 0 e1 e2 => (* e-ifz-true *)
      Some(Sε, Ω ▷ e1)
    | Xifz (S _) e1 e2 => (* e-ifz-false *)
      Some(Sε, Ω ▷ e2)
    | Xabort => (* e-abort *)
      Some(Scrash, ↯ ▷ stuck)
    | Xget x en => (* e-get *)
      match en with
      | Xres(Fres(Fval(Vnat n))) =>
        let '(F, H, Δ) := Ω in
        match splitat Δ x with
        | None => None
        | Some(Δ1, x, (L, ρ), Δ2) =>
          let '(addr ℓ) := L in
          let v := match Hget H (ℓ + n) with
                  | None => 1729
                  | Some w => w
                  end
          in
            Some(Sget (addr ℓ) n, F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2) ▷ v)
        end
      | _ => None
      end
    | Xset x en ev => (* e-set *)
      match en, ev with
      | Xres(Fres(Fval(Vnat n))), Xres(Fres(Fval(Vnat v))) =>
        let '(F, H, Δ) := Ω in
        match splitat Δ x with
        | None => None
        | Some(Δ1, x, (L, ρ), Δ2) =>
          let '(addr ℓ) := L in
          match Hset H (ℓ + n) v with
          | Some H' =>
            Some(Sset (addr ℓ) n v, F ; H' ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2) ▷ v)
          | None =>
            Some(Sset (addr ℓ) n v, F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ρ) ◘ Δ2) ▷ v)
          end
        end
      | _, _ => None
      end
    | Xdel x => (* e-delete *)
      let '(F, H, Δ) := Ω in
      match splitat Δ x with
      | None => None
      | Some(Δ1, x, (L, ρ), Δ2) =>
        let '(addr ℓ) := L in
        Some(Sdealloc (addr ℓ), F ; H ; (Δ1 ◘ x ↦ ((addr ℓ) ⋅ ☣) ◘ Δ2) ▷ 0)
      end
    | Xlet x ef e' => (* e-let *)
      match ef with
      | Xres(Fres f) =>
        let e'' := subst x e' f in
        Some(Sε, Ω ▷ e'')
      | _ => None
      end
    | Xnew x ef e' => (* e-new *)
      match ef with
      | Xres(Fres(Fval(Vnat n))) =>
        let '(F, H, Δ) := Ω in
        let H' := Hgrow H n in
        let ℓ := CSC.Fresh.fresh F in
        let F' := Fresh.advance F in
        let z := CSC.Fresh.freshv F' in
        let e'' := subst x e' (Fvar z) in
        Some(Salloc (addr ℓ) n, Fresh.advance F' ; H' ; (z ↦ ((addr ℓ) ⋅ ◻) ◘ Δ) ▷ e'')
      | _ => None
      end
    | _ => None (* no matching rule *)
    end
  end
.
(** We show that the functional style semantics an dthe relational style are equivalent. *)
Ltac crush_interp :=
    match goal with
    | [H: match ?oΩ with | Some _ => _ | None => None end = Some _ |- _] =>
        let Ω := fresh "Ω" in destruct oΩ as [|]; inversion H
    end.
Ltac grab_value e :=
  (destruct e as [[[[e]|]|]| | | | | | | | | | |]; try congruence)
.
Ltac grab_value2 e1 e2 := (grab_value e1; grab_value e2).
Ltac grab_final e :=
  (destruct e as [[e|]| | | | | | | | | | | ]; try congruence)
.

Lemma splitat_elim Δ1 Δ2 x ℓ ρ :
  splitat (Δ1 ◘ Scons x (addr ℓ, ρ) Δ2) x = Some (Δ1, x, (addr ℓ, ρ), Δ2).
Proof. Admitted.
Lemma splitat_base Δ x :
  splitat Δ x <> None -> exists Δ1 ℓ ρ Δ2, Δ = (Δ1 ◘ x ↦ (ℓ ⋅ ρ) ◘ Δ2).
Proof. Admitted.
Lemma splitat_none_or_not_none Δ x :
  splitat Δ x = None \/ splitat Δ x <> None.
Proof. Admitted.
Lemma Hget_none H n :
  n >= Hsize H -> Hget H n = None.
Proof. Admitted.
Lemma Hget_some H n :
  n < Hsize H -> exists v, Hget H n = Some v.
Proof. Admitted.
Lemma Hset_none H n v :
  n >= Hsize H -> Hset H n v = None.
Proof. Admitted.
Lemma Hset_some H n v :
  n < Hsize H -> exists H', Hset H n v = Some H'.
Proof. Admitted.

Lemma equiv_pstep r0 a r1 :
  r0 --[ a ]--> r1 <-> pstepf r0 = Some(a, r1).
Proof.
  split.
  - induction 1.
    + (* e-returning *) now cbn.
    + (* e-calling *) now cbn.
    + (* e-binop *) rewrite H; now cbn.
    + (* e-ifz-true *) now cbn.
    + (* e-ifz-false *) now cbn.
    + (* e-abort *) now cbn.
    + (* e-get *) cbn.
      destruct (Arith.Compare_dec.lt_dec (ℓ + n) (Hsize H)) as [H1a | H1b]; rewrite splitat_elim.
      * now specialize (H0a H1a) as H0a'; inv H0a'.
      * apply Arith.Compare_dec.not_lt in H1b; specialize (H0b H1b) as H1b'.
        now rewrite (@Hget_none H (ℓ + n) H1b); subst.
    + (* e-set *) cbn.
      destruct (Arith.Compare_dec.lt_dec (ℓ + n) (Hsize H)) as [H1a | H1b]; rewrite splitat_elim.
      * now rewrite <- (H0a H1a).
      * apply Arith.Compare_dec.not_lt in H1b; specialize (H0b H1b) as H1b'; subst.
        now rewrite (@Hset_none H (ℓ + n) v H1b).
    + (* e-delete *) now cbn; rewrite splitat_elim.
    + (* e-let *) now subst; cbn.
    + (* e-new *) now rewrite H3; subst; cbn.
  - intros H; destruct r0 as [oΩ e], r1 as [Ω' e']; destruct e; cbn in H; crush_interp; clear H.
    + (* e = e1 ⊕ e2 *)
      now grab_value2 e1 e2; inv H1; eapply e_binop.
    + (* e = x[e] *)
      grab_value e. destruct s as [[F H] Δ].
      destruct (splitat_none_or_not_none Δ x) as [H0|H0]; try (rewrite H0 in H1; congruence).
      apply splitat_base in H0 as [Δ1 [[ℓ] [ρ [Δ2 H0]]]]. rewrite H0 in H1.
      rewrite splitat_elim in H1. inv H1. eapply e_get; intros H0.
      * now apply Hget_some in H0 as [v ->].
      * now apply Hget_none in H0 as ->.
    + (* e = x[e1] <- e2 *)
      grab_value2 e1 e2. destruct s as [[F H] Δ].
      destruct (splitat_none_or_not_none Δ x) as [H0|H0]; try (rewrite H0 in H1; congruence).
      apply splitat_base in H0 as [Δ1 [[ℓ] [ρ [Δ2 H0]]]]. rewrite H0 in H1.
      rewrite splitat_elim in H1.
      destruct (Arith.Compare_dec.lt_dec (ℓ + e1) (Hsize H)) as [H2|H2].
      * apply (@Hset_some H (ℓ + e1) e2) in H2 as [H' H2]. rewrite H2 in H1.
        inv H1. eapply e_set; intros H0; subst; try easy.
        eapply (@Hset_none H (ℓ + e1) e2) in H0; congruence.
      * apply Arith.Compare_dec.not_lt in H2. apply (@Hset_none H (ℓ + e1) e2) in H2; subst; rewrite H2 in H1.
        inv H1. eapply e_set; intros H0; try easy. apply (@Hset_some H (ℓ + e1) e2) in H0 as [H' H0]; congruence.
    + (* e = let x = e1 in e2 *)
      grab_final e1; inv H1; now eapply e_let.
    + (* e = let x = new e1 in e2 *)
      grab_value e1; destruct s as [[F H] Δ]; inv H1; eapply e_alloc; eauto.
    + (* e = delete x *)
      destruct s as [[F H] Δ]; inv H1.
      destruct (splitat_none_or_not_none Δ x) as [H0|H0]; try (rewrite H0 in H2; congruence).
      apply splitat_base in H0 as [Δ1 [[ℓ] [ρ [Δ2 H0]]]]. rewrite H0 in H2.
      rewrite splitat_elim in H2; subst. inv H2. apply e_delete.
    + (* e = returning e *)
      grab_final e; inv H1; apply e_returning.
    + (* e = calling e *)
      grab_final e; inv H1; apply e_calling.
    + (* e = ifz c e0 e1 *)
      grab_value e1. destruct e1; inv H1; apply e_ifz_true || apply e_ifz_false.
    + (* e = abort *)
      apply e_abort.
Qed.

(** We proceed to define the dynamic semantics via evaluation contexts/environments. *)
Inductive evalctx : Type :=
| Khole : evalctx
| KbinopL (b : binopsymb) (K : evalctx) (e : expr) : evalctx
| KbinopR (b : binopsymb) (v : value) (K : evalctx) : evalctx
| Kget (x : vart) (K : evalctx) : evalctx
| KsetL (x : vart) (K : evalctx) (e : expr) : evalctx
| KsetR (x : vart) (v : value) (K : evalctx) : evalctx
| Klet (x : vart) (K : evalctx) (e : expr) : evalctx
| Knew (x : vart) (K : evalctx) (e : expr) : evalctx
| Kifz (K : evalctx) (e0 e1 : expr) : evalctx
| Kcalling (K : evalctx) : evalctx
| Kreturning (K : evalctx) : evalctx
.
(** convert an expression to evalctx in order to execute it functionally + "contextually" *)
(** this function returns an eval context K and an expr e' such that K[e'] = e given some e *)
Fixpoint evalctx_of_expr (e : expr) : option (evalctx * expr) :=
  match e with
  | Xres _ => Some(Khole, e)
  | Xhole _ _ _ => None
  | Xdel x => Some(Khole, Xdel x)
  | Xabort => Some(Khole, Xabort)
  | Xbinop b e1 e2 =>
    match e1, e2 with
    | Xres(Fres(Fval(Vnat n1))), Xres(Fres(Fval(Vnat n2))) =>
      Some(Khole, Xbinop b n1 n2)
    | Xres(Fres(Fval(Vnat n1))), en2 =>
      match evalctx_of_expr en2 with
      | Some(K, e2') => Some(KbinopR b n1 K, e2')
      | None => None
      end
    | _, _ =>
      match evalctx_of_expr e1 with
      | Some(K, e1') => Some(KbinopL b K e2, e1')
      | None => None
      end
    end
  | Xget x en =>
    match en with
    | Xres(Fres(Fval(Vnat n))) =>
      Some(Khole, Xget x n)
    | _ => match evalctx_of_expr en with
          | Some(K, en') => Some(Kget x K, en')
          | None => None
          end
    end
  | Xset x en ev =>
    match en, ev with
    | Xres(Fres(Fval(Vnat n))), Xres(Fres(Fval(Vnat v))) =>
      Some (Khole, Xset x n v)
    | Xres(Fres(Fval(Vnat n))), ev =>
      match evalctx_of_expr ev with
      | Some(K, ev') => Some(KsetR x n K, ev')
      | None => None
      end
    | en, ev =>
      match evalctx_of_expr en with
      | Some(K, en') => Some(KsetL x K ev, en')
      | None => None
      end
    end
  | Xlet x e1 e2 =>
    match e1 with
    | Xres(Fres(Fval(Vnat n))) =>
      Some(Khole, Xlet x n e2)
    | _ => match evalctx_of_expr e1 with
          | Some(K, e1') => Some(Klet x K e2, e1')
          | None => None
          end
    end
  | Xnew x e1 e2 =>
    match e1 with
    | Xres(Fres(Fval(Vnat n))) =>
      Some(Khole, Xnew x n e2)
    | _ => match evalctx_of_expr e1 with
          | Some(K, e1') => Some(Knew x K e2, e1')
          | None => None
          end
    end
  | Xreturning e =>
    match e with
    | Xres(Fres(Fval(Vnat n))) =>
      Some(Khole, Xreturning n)
    | _ => match evalctx_of_expr e with
          | Some(K, e') => Some(Kreturning K, e')
          | None => None
          end
    end
  | Xcalling e =>
    match e with
    | Xres(Fres(Fval(Vnat n))) =>
      Some(Khole, Xcalling n)
    | _ => match evalctx_of_expr e with
          | Some(K, e') => Some(Kcalling K, e')
          | None => None
          end
    end
  | Xifz c e0 e1 =>
    match c with
    | Xres(Fres(Fval(Vnat v))) =>
      Some(Khole, Xifz v e0 e1)
    | _ => match evalctx_of_expr c with
          | Some(K, c') => Some(Kifz K e0 e1, c')
          | None => None
          end
    end
  end
.
Fixpoint insert (K : evalctx) (withh : expr) : expr :=
  let R := fun k => insert k withh in
  match K with
  | Khole => withh
  | KbinopL b K' e => Xbinop b (R K') e
  | KbinopR b v K' => Xbinop b v (R K')
  | Kget x K' => Xget x (R K')
  | KsetL x K' e => Xset x (R K') e
  | KsetR x v K' => Xset x v (R K')
  | Klet x K' e => Xlet x (R K') e
  | Knew x K' e => Xnew x (R K') e
  | Kifz K' e0 e1 => Xifz (R K') e0 e1
  | Kcalling K' => Xcalling (R K')
  | Kreturning K' => Xreturning (R K')
  end
.
(* Checks wether the thing that is filled into the hole is somehow structurually compatible with pstep *)
Definition pstep_compatible (e : expr) : option expr :=
  match e with
  | Xreturning f => Some (Xreturning f)
  | Xcalling f => Some (Xcalling f)
  | Xifz 0 e0 e1 => Some (Xifz 0 e0 e1)
  | Xifz (S n) e0 e1 => Some (Xifz (S n) e0 e1)
  | Xabort => Some (Xabort)
  | Xdel x => Some (Xdel x)
  | Xbinop b (Xres(Fres(Fval(Vnat n1)))) (Xres(Fres(Fval(Vnat n2)))) => Some (Xbinop b n1 n2)
  | Xget x (Xres(Fres(Fval(Vnat n)))) => Some(Xget x n)
  | Xset x (Xres(Fres(Fval(Vnat n1)))) (Xres(Fres(Fval(Vnat n2)))) => Some(Xset x n1 n2)
  | Xnew x (Xres(Fres(Fval(Vnat n)))) e => Some(Xnew x n e)
  | Xlet x (Xres(Fres f)) e => Some(Xlet x f e)
  | _ => None
  end
.

Reserved Notation "r0 '==[' a ']==>' r1" (at level 82, r1 at next level).
Inductive estep : rtexpr -> event -> rtexpr -> Prop :=
| E_ctx : forall (Ω Ω' : state) (e e' e0 e0' : expr) (a : event) (K : evalctx),
    (*Some(K,e) = evalctx_of_expr e0 ->*)
    Some e = pstep_compatible e ->
    e0 = insert K e ->
    e0' = insert K e' ->
    Ω ▷ e --[ a ]--> Ω' ▷ e' ->
    Ω ▷ e0 ==[ a ]==> Ω' ▷ e0'
| E_abrt_ctx : forall (Ω : state) (e e0 : expr) (K : evalctx),
    (*Some(K,e) = evalctx_of_expr e0 ->*)
    Some e = pstep_compatible e ->
    e0 = insert K e ->
    Ω ▷ e --[ Scrash ]--> ↯ ▷ stuck ->
    Ω ▷ e0 ==[ Scrash ]==> ↯ ▷ stuck
where "r0 '==[' a ']==>' r1" := (estep r0 a r1)
.
#[global]
Hint Constructors estep : core.

Definition estepf (r : rtexpr) : option (event * rtexpr) :=
  let '(oΩ, e) := r in
  match oΩ, evalctx_of_expr e with
  | Some Ω, Some(K, e0) =>
    match pstep_compatible e0 with
    | Some _ =>
      match pstepf (Ω ▷ e0) with
      | Some(_, (None, _)) => Some(Scrash, ↯ ▷ stuck)
      | Some(a, (Some Ω', e0')) => Some(a, Ω' ▷ insert K e0')
      | None => None
      end
    | None => None
    end
  | _, _ => None
  end
.

Lemma grab_ectx e K e0 :
  Some e0 = pstep_compatible e0 ->
  e = insert K e0 ->
  evalctx_of_expr e = Some(K, e0)
.
Proof.
  destruct e; intros H.
  - induction K; cbn in *; try congruence; try (destruct (insert K e0); congruence).
  - induction K; cbn in *; try congruence; try (destruct (insert K e0); congruence).
Admitted.

Lemma equiv_estep r0 a r1 :
  r0 ==[ a ]==> r1 <-> estepf r0 = Some(a, r1).
Proof.
  split.
  - induction 1.
    + apply (@grab_ectx e0 K e H) in H0 as H0'.
      cbn; rewrite H0'; rewrite equiv_pstep in H2; inv H.
      change (match pstepf (Ω ▷ e) with
              | Some(_, (None, _)) => Some(Scrash, ↯ ▷ stuck)
              | Some(a, (Some Ω', e0')) => Some(a, Ω' ▷ insert K e0')
              | None => None
              end = Some (a, (Some Ω', insert K e'))).
      now rewrite H2.
    + apply (@grab_ectx e0 K e H) in H0 as H0'.
      cbn; rewrite H0'; rewrite equiv_pstep in H1; inv H.
      change (match pstepf (Ω ▷ e) with
              | Some(_, (None, _)) => Some(Scrash, ↯ ▷ stuck)
              | Some(a, (Some Ω', e0')) => Some(a, Ω' ▷ insert K e0')
              | None => None
              end = Some(Scrash, ↯ ▷ stuck)).
      now rewrite H1.
  - destruct r0 as [Ω e], r1 as [Ω' e'].
    destruct e; intros H.
    + cbn in H. destruct Ω in H; congruence.
    (* rather annoying *)
Admitted.

Reserved Notation "r0 '==[' As ']==>*' r1" (at level 82, r1 at next level).
Inductive star_step : rtexpr -> tracepref -> rtexpr -> Prop :=
| ES_refl : forall (r1 : rtexpr),
    r1 ==[ Tnil ]==>* r1
| ES_trans_important : forall (r1 r2 r3 : rtexpr) (a : event) (As : tracepref),
    a <> Sε ->
    r1 ==[ a ]==> r2 ->
    r2 ==[ As ]==>* r3 ->
    r1 ==[ Tcons a As ]==>* r3
| ES_trans_unimportant : forall (r1 r2 r3 : rtexpr) (As : tracepref),
    r1 ==[ Sε ]==> r2 ->
    r2 ==[ As ]==>* r3 ->
    r1 ==[ As ]==>* r3
where "r0 '==[' As ']==>*' r1" := (star_step r0 As r1)
.
#[global]
Hint Constructors star_step : core.

(** Functional style version of star step from above. We need another parameter "fuel" to sidestep termination. *)
Definition star_stepf (fuel : nat) (r : rtexpr) : option (tracepref * rtexpr) :=
  let fix doo (fuel : nat) (r : rtexpr) :=
    match r with
    | (Some Ω, e) =>
      match fuel, e with
      | 0, Xres _ => (* refl *)
        Some(Tnil, r)
      | S fuel', _ => (* trans *)
        match estepf r with
        | Some(a, r') =>
          match doo fuel' r' with
          | Some(As, r'') => match a with
                            | Sε => Some(As, r'')
                            | _ => Some(Tcons a As, r'')
                            end
          | None => None
          end
        | None => None
        end
      | _, _ => None
      end
    | _ => None
    end
  in doo fuel r
.
(*TODO: prove correctness*)

(** Finds the amount of fuel necessary to run an expression. *)
Fixpoint get_fuel (e : expr) : option nat :=
  match e with
  | Xres _ => Some(0)
  | Xbinop symb lhs rhs => match get_fuel lhs, get_fuel rhs with Some(glhs), Some(grhs) => Some(1 + glhs + grhs) | _, _ => None end
  | Xget x e => match get_fuel e with Some(ge) => Some(1 + ge) | None => None end
  | Xset x e0 e1 => match get_fuel e0, get_fuel e1 with Some(ge0), Some(ge1) => Some(1 + ge0 + ge1) | _, _ => None end
  | Xlet x e0 e1 => match get_fuel e0, get_fuel e1 with Some(ge0), Some(ge1) => Some(1 + ge0 + ge1) | _, _ => None end
  | Xnew x e0 e1 => match get_fuel e0, get_fuel e1 with Some(ge0), Some(ge1) => Some(1 + ge0 + ge1) | _, _ => None end
  | Xdel x => Some(1)
  | Xreturning e => match get_fuel e with Some(ge) => Some(1 + ge) | None => None end
  | Xcalling e => match get_fuel e with Some(ge) => Some(1 + ge) | None => None end
  | Xifz c e0 e1 => match get_fuel c, get_fuel e0, get_fuel e1 with Some(gc), Some(ge0), Some(ge1) => Some(1 + gc + ge0 + ge1) | _, _, _ => None end
  | Xabort => Some(1)
  | Xhole _ _ _ => None
  end
.

Lemma get_fuel_works e n Ω :
  get_fuel e = Some n -> exists As Ω' e', star_stepf n (Ω ▷ e) = Some(As, Ω' ▷ e').
Proof.
  revert n; induction e; intros n H; cbn in H.
  - inv H; exists Tnil; exists Ω; exists f; cbn; easy.
  - destruct (get_fuel e1) as [ge1|]; destruct (get_fuel e2) as [ge2|]; try congruence.
    inv H. specialize (IHe1 ge1 eq_refl). specialize (IHe2 ge2 eq_refl).
    destruct IHe1 as [As1 [Ω1' [e1' IHe1]]]. destruct IHe2 as [As2 [Ω2' [e2' IHe2]]].
    exists (As1 · As2 · Sε). exists Ω2'.
Admitted.

(** Fill hole expression. *)
Variant fill_placeholder : Type :=
| FP_Q : fill_placeholder
| FP_N (freshid : vart) : fill_placeholder
.
Definition fill (Q : fill_placeholder) (e0 e1 : expr) : expr :=
  let ifill := (fix ifill e :=
    let R := exprmap ifill in
    match e with
    | Xhole x τ1 τ2 =>
        match Q with
        | FP_Q => (* plug-hole *)
            Xlet x (Xcalling (Fvar x)) (Xreturning e0)
        | FP_N freshid => (* plug-hole' *)
            Xlet freshid (Xhole x τ1 τ2) (Xlet dontcare e0 (Fvar freshid))
        end
    | _ => R e
    end)
  in
  ifill e1
.
(*TODO: add typing*)
Inductive fill_j : list string -> fill_placeholder -> expr -> expr -> expr -> Prop :=
| fillQ : forall e0 e1 e2, fill FP_Q e0 e1 = e2 -> fill_j nil FP_Q e0 e1 e2
| fillN : forall q e0 e1 e2 z X, fresh_tvar X z -> q = FP_N z -> fill q e0 e1 = e2 -> fill_j X q e0 e1 e2
.
#[global]
Hint Constructors fill_j : core.

(** Evaluation of programs *)
(*TODO: add typing*)
Inductive wstep (e0 ep e1 : expr) : prog e0 ep e1 -> tracepref -> rtexpr -> Prop :=
| e_wprog : forall (y : vart)
              (e0' ep0 e0'' : expr)
              (f0 fp fp' f1 : fnoerr)
              (Ω0 Ωp0 Ω0' Ω1 : state)
              (As0 Asp As0' As1 : tracepref),
    fill_j nil FP_Q ep e0 e0' ->
    (* typing -> *)
    (Fresh.empty_fresh ; Hnil ; Snil ▷ e0' ==[ As0 · Scall f0 ]==>* Ω0 ▷ ep0) ->
    (Ω0 ▷ ep0 ==[ Asp · Sret fp ]==>* Ωp0 ▷ e0'') ->
    (Ωp0 ▷ e0'' ==[ As0' ]==>* Ω0' ▷ fp') ->
    (Ω0' ▷ (subst y e1 fp') ==[ As1 ]==>* Ω1 ▷ f1) ->
    wstep (Cprog e0 ep e1) (Sret 0 · As0 · Scall f0 · Asp · Sret fp · As0' · As1 · Scall f1) (Ω1 ▷ f1)
.
Notation "'PROG[' e0 '][' ep '][' e1 ']====[' As ']===>' r" := (wstep (Cprog e0 ep e1) As r) (at level 81, r at next level).

Definition wstepf {e0 ep e1 : expr} (p : prog e0 ep e1) : option (tracepref * rtexpr) :=
  let e0' := fill FP_Q ep e0 in
  match get_fuel e0' with
  | Some ge0' =>
    match star_stepf ge0' ((Fresh.empty_fresh; Hnil; Snil) ▷ e0') with
    | Some(As0, (Some Ω0', fp')) =>
      let e1' := subst ("y"%string) e1 fp' in
      match get_fuel e1' with
      | Some ge1' =>
        match star_stepf ge1' (Ω0' ▷ e1') with
        | Some(As1, (Some Ω1, Xres(Fres(f1)))) => Some(Sret 0 · As0 · As1 · Scall f1, Ω1 ▷ f1)
        | Some(As1, (None, Xres(Fabrt))) => Some(Sret 0 · As0 · As1, ↯ ▷ stuck)
        | _ => None
        end
      | None => None
      end
    | Some(As0, (None, Xres(Fabrt))) => Some(Sret 0 · As0, ↯ ▷ stuck)
    | _ => None
    end
  | None => None
  end
.

Definition cmptrpref {e0 ep e1 : expr} (p : prog e0 ep e1) :=
  exists As Ω f, PROG[e0][ep][e1]====[ As ]===> (Ω ▷ f)
.

(* let z = new x in let w = x[1337] in let _ = delete z in w*)
Definition smsunsafe_ep : expr :=
  Xnew "z"%string
       (Fvar "x"%string)
       (Xlet "w"%string
             (Xget "x"%string 1337)
             (Xlet "_"%string
                   (Xdel "z"%string)
                   (Fvar "w"%string))
       )
.
(* let x = 42 in hole : (x : nat) -> nat *)
Definition smsunsafe_e0 : expr :=
  Xlet "x"%string
       3
       (Xhole "x"%string Tnat Tnat)
.
(* y *)
Definition smsunsafe_e1 : expr :=
  Fvar "y"%string
.

Definition smsunsafe_prog := Cprog smsunsafe_e0 smsunsafe_ep smsunsafe_e1.

Definition smsunsafe_e0' := fill FP_Q smsunsafe_ep smsunsafe_e0.

Definition rest :=
          Xreturning
            (Xlet "z"%string (Fvar "x"%string)
               (Xlet "w"%string (Xget "x"%string 1337) (Xlet "_"%string (Xdel "z"%string) (Fvar "w"%string))))
.

Compute (wstepf smsunsafe_prog).
Definition debug_eval {e0 ep e1 : expr} (p : prog e0 ep e1) :=
  match wstepf p with
  | Some(As, _) => Some(string_of_tracepref As)
  | _ => None
  end
.
Compute (debug_eval smsunsafe_prog).

(*TODO: use functional-style interpreters to get concrete trace via simple `cbn` *)
Goal cmptrpref smsunsafe_prog.
Proof.
  unfold cmptrpref. do 3 eexists.
  eapply e_wprog; eauto; cbn.

Admitted.
