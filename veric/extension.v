Load loadpath.
Require Import ListSet.

Require Import veric.sim.
Require Import veric.rg_sim.
Require Import veric.step_lemmas.
Require Import veric.extspec.
Require Import veric.Address.

Require Import AST. (*for typ*)
Require Import Values. (*for val*)
Require Import Integers.

Set Implicit Arguments.

Module TruePropCoercion.
Definition is_true (b: bool) := b=true.
Coercion is_true: bool >-> Sortclass.
End TruePropCoercion.
Import TruePropCoercion.

(** * Extensions *)

Module Extension. Section Extension.
 Variables
  (G: Type) (** global environments of extended semantics *)
  (D: Type) (** extension initialization data *)
  (xT: Type) (** corestates of extended semantics *)
  (gT: nat -> Type) (** global environments of core semantics *)
  (cT: nat -> Type) (** corestates of core semantics *)
  (M: Type) (** memories *)
  (dT: nat -> Type) (** initialization data *)
  (Z: Type) (** external states *)
  (Zint: Type) (** portion of Z implemented by extension *)
  (Zext: Type) (** portion of Z external to extension *)

  (esem: CoreSemantics G xT M D) (** extended semantics *)
  (csem: forall i:nat, CoreSemantics (gT i) (cT i) M (dT i)) (** a set of core semantics *)

  (csig: ef_ext_spec M Z) (** client signature *)
  (esig: ef_ext_spec M Zext) (** extension signature *)

  (handled: list AST.external_function). (** functions handled by this extension *)

 Local Open Scope nat_scope.

 Notation IN := (ListSet.set_mem extfunct_eqdec).
 Notation NOTIN := (fun ef l => ListSet.set_mem extfunct_eqdec ef l = false).
 Notation DIFF := (ListSet.set_diff extfunct_eqdec).

 Record Sig := Make {
 (** Generalized projection of genv, core [i] from state [s] *)
  threads_max: nat;
  proj_core: forall i:nat, xT -> option (cT i); 
  proj_threads_max: forall i s, i >= threads_max -> proj_core i s = None;
  active : xT -> nat; (** The active (i.e., currently scheduled) core *)
  active_proj_core : forall s, exists c, proj_core (active s) s = Some c;
  proj_zint: xT -> Zint; (** Type [xT] embeds [Zint]. *)
  proj_zext: Z -> Zext;
  zmult: Zint -> Zext -> Z;
  zmult_proj: forall zint zext, proj_zext (zmult zint zext)=zext;

 (** When a core is AtExternal but the extension is not, the function on which 
    the core is blocked is handled by the extension. *)
  notat_external_handled: forall s c ef args sig,
   proj_core (active s) s = Some c -> 
   at_external (csem (active s)) c = Some (ef, sig, args) -> 
   at_external esem s = None -> IN ef handled;

 (** Functions on which the extension is blocked are not handled. *)
  at_external_not_handled: forall s ef args sig,
   at_external esem s = Some (ef, sig, args) -> NOTIN ef handled;

 (** Implemented "external" state is unchanged after truly external calls. *)
  ext_upd_at_external : forall ef sig args ret s s',
   at_external esem s = Some (ef, sig, args) -> 
   after_external esem ret s = Some s' -> proj_zint s=proj_zint s';
   
 (** [esem] and [csem] are signature linkable *)
  esem_csem_linkable: linkable proj_zext handled csig esig
 }.

End Extension. End Extension.
Implicit Arguments Extension.Make [G xT cT M D Z Zint Zext].

(** * Safe Extensions *)

Section SafeExtension.
 Variables
  (G: Type) (** global environments *)
  (D: Type) (** initialization data *)
  (xT: Type) (** corestates of extended semantics *)
  (gT: nat -> Type) (** global environments of the core semantics *)
  (cT: nat -> Type) (** corestates of core semantics *)
  (M: Type) (** memories *)
  (dT: nat -> Type) (** initialization data *)
  (Z: Type) (** external states *)
  (Zint: Type) (** portion of Z implemented by extension *)
  (Zext: Type) (** portion of Z external to extension *)

  (esem: CoreSemantics G xT M D) (** extended semantics *)
  (csem: forall i:nat, CoreSemantics (gT i) (cT i) M (dT i)) (** a set of core semantics *)

  (csig: ef_ext_spec M Z) (** client signature *)
  (esig: ef_ext_spec M Zext) (** extension signature *)
  (handled: list AST.external_function). (** functions handled by this extension *)

 Variables (ge: G) (genv_map : forall i:nat, gT i).

 Import Extension.

 (** a global invariant characterizing "safe" extensions *)
 Definition all_safe (E: Sig gT cT dT Zint esem csem csig esig handled)
  (n: nat) (z: Z) (w: xT) (m: M) :=
     forall i c, proj_core E i w = Some c -> 
       safeN (csem i) csig (genv_map i) n z c m.

 (** All-safety implies safeN. *)
 Definition safe_extension (E: Sig gT cT dT Zint esem csem csig esig handled) :=
  forall n s m z, 
    all_safe E n (zmult E (proj_zint E s) z) s m -> 
    safeN esem (link_ext_spec handled esig) ge n z s m.

End SafeExtension.

Module SafetyInvariant. Section SafetyInvariant.
 Variables
  (G: Type) (** global environments *)
  (D: Type) (** initialization data *)
  (xT: Type) (** corestates of extended semantics *)
  (gT: nat -> Type) (** global environments of the core semantics *)
  (cT: nat -> Type) (** corestates of core semantics *)
  (M: Type) (** memories *)
  (dT: nat -> Type) (** initialization data *)
  (Z: Type) (** external states *)
  (Zint: Type) (** portion of Z implemented by extension *)
  (Zext: Type) (** portion of Z external to extension *)

  (esem: CoreSemantics G xT M D) (** extended semantics *)
  (csem: forall i:nat, CoreSemantics (gT i) (cT i) M (dT i)) (** a set of core semantics *)

  (csig: ef_ext_spec M Z) (** client signature *)
  (esig: ef_ext_spec M Zext) (** extension signature *)
  (handled: list AST.external_function). (** functions handled by this extension *)

 Variables (ge: G) (genv_map : forall i:nat, gT i).
 Variable E: Extension.Sig gT cT dT Zint esem csem csig esig handled.

Definition proj_zint := E.(Extension.proj_zint). 
Coercion proj_zint : xT >-> Zint.

Definition proj_zext := E.(Extension.proj_zext).
Coercion proj_zext : Z >-> Zext.

Notation ALL_SAFE := (all_safe genv_map E). 
Notation PROJ_CORE := E.(Extension.proj_core).
Notation "zint \o zext" := (E.(Extension.zmult) zint zext) 
  (at level 66, left associativity). 
Notation ACTIVE := (E.(Extension.active)).
Notation active_proj_core := E.(Extension.active_proj_core).
Notation notat_external_handled := E.(Extension.notat_external_handled).
Notation at_external_not_handled := E.(Extension.at_external_not_handled).
Notation ext_upd_at_external := E.(Extension.ext_upd_at_external).

Inductive safety_invariant: Type := SafetyInvariant: forall 
  (** Coresteps preserve the all-safety invariant. *)
  (core_pres: forall n z (s: xT) c m s' c' m', 
    ALL_SAFE (S n) (s \o z) s m -> 
    PROJ_CORE (ACTIVE s) s = Some c -> 
    corestep (csem (ACTIVE s)) (genv_map (ACTIVE s)) c m c' m' -> 
    corestep esem ge s m s' m' -> 
    ALL_SAFE n (s' \o z) s' m')

  (** Corestates satisfying the invariant can corestep. *)
  (core_prog: forall n z s m (c: cT (ACTIVE s)),
    ALL_SAFE (S n) z s m -> 
    PROJ_CORE (ACTIVE s) s = Some c -> 
    runnable (csem (ACTIVE s)) c=true -> 
    exists c', exists s', exists m', 
      corestep (csem (ACTIVE s)) (genv_map (ACTIVE s)) c m c' m' /\ 
      corestep esem ge s m s' m' /\
      PROJ_CORE (ACTIVE s) s' = Some c')

  (** "Handled" steps respect function specifications. *)
  (handled_pres: forall s z m (c: cT (ACTIVE s)) s' m' 
        (c': cT (ACTIVE s)) ef sig args P Q x, 
    let i := ACTIVE s in PROJ_CORE i s = Some c -> 
    at_external (csem i) c = Some (ef, sig, args) -> 
    ListSet.set_mem extfunct_eqdec ef handled = true -> 
    spec_of ef csig = (P, Q) -> 
    P x (sig_args sig) args (s \o z) m -> 
    corestep esem ge s m s' m' -> 
    PROJ_CORE i s' = Some c' -> 
      ((at_external (csem i) c' = Some (ef, sig, args) /\ 
        P x (sig_args sig) args (s' \o z) m' /\
        (forall j, ACTIVE s' = j -> i <> j)) \/
      (exists ret, after_external (csem i) ret c = Some c' /\ 
        Q x (sig_res sig) ret (s' \o z) m')))

  (** "Handled" states satisfying the invariant can step or are safely halted;
     core states that remain "at_external" over handled steps are unchanged. *)
  (handled_prog: forall n (z: Zext) (s: xT) m c,
    ALL_SAFE (S n) (s \o z) s m -> 
    PROJ_CORE (ACTIVE s) s = Some c -> 
    runnable (csem (ACTIVE s)) c=false -> 
    at_external esem s = None -> 
    (exists s', exists m', corestep esem ge s m s' m' /\ 
      forall i c, PROJ_CORE i s = Some c -> 
        exists c', PROJ_CORE i s' = Some c' /\
          (forall ef args ef' args', 
            at_external (csem i) c = Some (ef, args) -> 
            at_external (csem i) c' = Some (ef', args') -> c=c')) \/
    (exists rv, safely_halted esem s = Some rv))

  (** Safely halted threads remain halted. *)
  (safely_halted_halted: forall s m s' m' i c rv,
    PROJ_CORE i s = Some c -> 
    safely_halted (csem i) c = Some rv -> 
    corestep esem ge s m s' m' -> PROJ_CORE i s' = Some c)

  (** Safety of other threads is preserved when handling one step of blocked
     thread [i]. *)
  (handled_rest: forall s m s' m' c,
    PROJ_CORE (ACTIVE s) s = Some c -> 
    ((exists ef, exists sig, exists args, 
        at_external (csem (ACTIVE s)) c = Some (ef, sig, args)) \/ 
      exists rv, safely_halted (csem (ACTIVE s)) c = Some rv) -> 
    at_external esem s = None -> 
    corestep esem ge s m s' m' -> 
    (forall j c0, ACTIVE s <> j ->  
      (PROJ_CORE j s' = Some c0 -> PROJ_CORE j s = Some c0) /\
      (forall n z z', PROJ_CORE j s = Some c0 -> 
        safeN (csem j) csig (genv_map j) (S n) (s \o z) c0 m -> 
        safeN (csem j) csig (genv_map j) n (s' \o z') c0 m')))

  (** If the extended machine is at external, then the active thread is at
     external (an extension only implements external functions, it doesn't
     introduce them). *)
  (at_extern_call: forall s ef sig args,
    at_external esem s = Some (ef, sig, args) -> 
    exists c, PROJ_CORE (ACTIVE s) s = Some c /\
      at_external (csem (ACTIVE s)) c = Some (ef, sig, args))

  (** Inject the results of an external call into the extended machine state. *)
  (at_extern_ret: forall z s (c: cT (ACTIVE s)) m z' m' tys args ty ret c' ef sig x 
      (P: ext_spec_type esig ef -> list typ -> list val -> Zext -> M -> Prop) 
      (Q: ext_spec_type esig ef -> option typ -> option val -> Zext -> M -> Prop),
    PROJ_CORE (ACTIVE s) s = Some c -> 
    at_external esem s = Some (ef, sig, args) -> 
    spec_of ef esig = (P, Q) -> 
    P x tys args (s \o z) m -> Q x ty ret z' m' -> 
    after_external (csem (ACTIVE s)) ret c = Some c' -> 
    exists s': xT, 
      z' = s' \o z' /\
      after_external esem ret s = Some s' /\ 
      PROJ_CORE (ACTIVE s) s' = Some c')

  (** Safety of other threads is preserved when returning from an external 
     function call. *)
  (at_extern_rest: forall z s (c: cT (ACTIVE s)) m z' s' m' tys args ty ret c' ef x sig
      (P: ext_spec_type esig ef -> list typ -> list val -> Zext -> M -> Prop) 
      (Q: ext_spec_type esig ef -> option typ -> option val -> Zext -> M -> Prop),
    PROJ_CORE (ACTIVE s) s = Some c -> 
    at_external esem s = Some (ef, sig, args) -> 
    spec_of ef esig = (P, Q) -> 
    P x tys args (s \o z) m -> Q x ty ret z' m' -> 
    after_external (csem (ACTIVE s)) ret c = Some c' -> 
    after_external esem ret s = Some s' -> 
    PROJ_CORE (ACTIVE s) s' = Some c' ->  
    (forall j (CS0: CoreSemantics (gT j) (cT j) M (dT j)) c0, ACTIVE s <> j -> 
      (PROJ_CORE j s' = Some c0 -> PROJ_CORE j s = Some c0) /\
      (forall ge n, PROJ_CORE j s = Some c0 -> 
        safeN CS0 csig ge (S n) (s \o z) c0 m -> 
        safeN CS0 csig ge n (s' \o z') c0 m'))),
  safety_invariant.

End SafetyInvariant. End SafetyInvariant.

Module EXTENSION_SAFETY. Section EXTENSION_SAFETY.
 Variables
  (G: Type) (** global environments *)
  (D: Type) (** initialization data *)
  (xT: Type) (** corestates of extended semantics *)
  (gT: nat -> Type) (** global environments of the core semantics *)
  (cT: nat -> Type) (** corestates of core semantics *)
  (M: Type) (** memories *)
  (dT: nat -> Type) (** initialization data *)
  (Z: Type) (** external states *)
  (Zint: Type) (** portion of Z implemented by extension *)
  (Zext: Type) (** portion of Z external to extension *)

  (esem: CoreSemantics G xT M D) (** extended semantics *)
  (csem: forall i:nat, CoreSemantics (gT i) (cT i) M (dT i)) (** a set of core semantics *)

  (csig: ef_ext_spec M Z) (** client signature *)
  (esig: ef_ext_spec M Zext) (** extension signature *)
  (handled: list AST.external_function). (** functions handled by this extension *)

 Variables (ge: G) (genv_map : forall i:nat, gT i).
 Variable E: Extension.Sig gT cT dT Zint esem csem csig esig handled.

Import SafetyInvariant.

Record Sig := Make {_: safety_invariant ge genv_map E -> safe_extension ge genv_map E}.

End EXTENSION_SAFETY. End EXTENSION_SAFETY.
