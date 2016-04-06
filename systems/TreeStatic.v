Require Import Verdi.
Require Import HandlerMonad.
Require Import NameOverlay.

Require Import TotalMapSimulations.
Require Import PartialMapSimulations.
Require Import PartialExtendedMapSimulations.

Require Import UpdateLemmas.
Local Arguments update {_} {_} _ _ _ _ : simpl never.

Require Import Sumbool.

Require Import mathcomp.ssreflect.ssreflect.
Require Import mathcomp.ssreflect.ssrbool.

Require Import Orders.
Require Import MSetFacts.
Require Import MSetProperties.
Require Import FMapInterface.

Require Import Sorting.Permutation.

Require Import FailureRecorderStatic.

Set Implicit Arguments.

Module Tree (Import NT : NameType)  
 (NOT : NameOrderedType NT) (NSet : MSetInterface.S with Module E := NOT) 
 (NOTC : NameOrderedTypeCompat NT) (NMap : FMapInterface.S with Module E := NOTC)
 (Import RNT : RootNameType NT) (Import ANT : AdjacentNameType NT).

Module A := Adjacency NT NOT NSet ANT.
Import A.

Module FR := FailureRecorder NT NOT NSet ANT.

Module NSetFacts := Facts NSet.
Module NSetProps := Properties NSet.
Module NSetOrdProps := OrdProperties NSet.

Definition lv := nat.
Definition lv_eq_dec := Nat.eq_dec.

Inductive Msg : Set := 
| Fail : Msg
| Level : option lv -> Msg.

Definition Msg_eq_dec : forall x y : Msg, {x = y} + {x <> y}.
decide equality.
case: o; case: o0.
- move => n m.
  case (lv_eq_dec n m) => H_dec; first by rewrite H_dec; left.
  right.
  move => H_eq.
  injection H_eq => H_eq'.
  by rewrite H_eq' in H_dec.
- by right.
- by right.
- by left.
Defined.

Inductive Input : Set :=
| LevelRequest : Input
| Broadcast : Input.

Definition Input_eq_dec : forall x y : Input, {x = y} + {x <> y}.
decide equality.
Defined.

Inductive Output : Set :=
| LevelResponse : option lv -> Output.

Definition Output_eq_dec : forall x y : Output, {x = y} + {x <> y}.
decide equality.
case: o; case: o0.
- move => n m.
  case (lv_eq_dec n m) => H_dec; first by rewrite H_dec; left.
  right.
  move => H_eq.
  injection H_eq => H_eq'.
  by rewrite H_eq' in H_dec.
- by right.
- by right.
- by left.
Defined.

Definition NL := NMap.t lv.

Record Data := mkData { 
  adjacent : NS ; 
  broadcast : bool ; 
  levels : NL
}.

Definition InitData (n : name) := 
if root_dec n then
  {| adjacent := adjacency n nodes ;
     broadcast := true ;
     levels := NMap.empty lv |}
else
  {| adjacent := adjacency n nodes ;
     broadcast := false ;
     levels := NMap.empty lv |}.

Inductive level_in (fs : NS) (fl : NL) (n : name) (lv' : lv) : Prop :=
| in_level_in : NSet.In n fs -> NMap.find n fl = Some lv' -> level_in fs fl n lv'.

Inductive min_level (fs : NS) (fl : NL) (n : name) (lv' : lv) : Prop :=
| min_lv_min : level_in fs fl n lv' -> 
  (forall (lv'' : lv) (n' : name), level_in fs fl n' lv'' -> ~ lv'' < lv') ->
  min_level fs fl n lv'.

Record st_par := mk_st_par { st_par_set : NS ; st_par_map : NL }.

Record nlv := mk_nlv { nlv_n : name ; nlv_lv : lv }.

Definition st_par_lt (s s' : st_par) : Prop :=
NSet.cardinal s.(st_par_set) < NSet.cardinal s'.(st_par_set).

Lemma st_par_lt_well_founded : well_founded st_par_lt.
Proof.
apply (well_founded_lt_compat _ (fun s => NSet.cardinal s.(st_par_set))).
by move => x y; rewrite /st_par_lt => H.
Qed.

Definition par_t (s : st_par) := 
{ nlv' | min_level s.(st_par_set) s.(st_par_map) nlv'.(nlv_n) nlv'.(nlv_lv) }+
{ ~ exists nlv', level_in s.(st_par_set) s.(st_par_map) nlv'.(nlv_n) nlv'.(nlv_lv) }.

Definition par_F : forall s : st_par, 
  (forall s' : st_par, st_par_lt s' s -> par_t s') ->
  par_t s.
rewrite /par_t.
refine 
  (fun (s : st_par) par_rec => 
   match NSet.choose s.(st_par_set) as sopt return (_ = sopt -> _) with
   | Some n => fun (H_eq : _) => 
     match par_rec (mk_st_par (NSet.remove n s.(st_par_set)) s.(st_par_map)) _ with
     | inleft (exist nlv' H_min) =>
       match NMap.find n s.(st_par_map) as n' return (_ = n' -> _) with
       | Some lv' => fun (H_find : _) => 
         match lt_dec lv' nlv'.(nlv_lv)  with
         | left H_dec => inleft _ (exist _ (mk_nlv n lv') _)
         | right H_dec => inleft _ (exist _ nlv' _)
         end
       | None => fun (H_find : _) => inleft _ (exist _ nlv' _)
       end (refl_equal _)
     | inright H_min =>
       match NMap.find n s.(st_par_map) as n' return (_ = n' -> _) with
       | Some lv' => fun (H_find : _) => inleft _ (exist _ (mk_nlv n lv') _)
       | None => fun (H_find : _) => inright _ _
       end (refl_equal _)
     end
   | None => fun (H_eq : _) => inright _ _
   end (refl_equal _)) => /=.
- rewrite /st_par_lt /=.
  apply NSet.choose_spec1 in H_eq.
  set sr := NSet.remove _ _.
  have H_notin: ~ NSet.In n sr by move => H_in; apply NSetFacts.remove_1 in H_in.
  have H_add: NSetProps.Add n sr s.(st_par_set).
    rewrite /NSetProps.Add.
    move => n'.
    split => H_in.
      case (name_eq_dec n n') => H_eq'; first by left.
      by right; apply NSetFacts.remove_2.
    case: H_in => H_in; first by rewrite -H_in.
    by apply NSetFacts.remove_3 in H_in.
  have H_card := NSetProps.cardinal_2 H_notin H_add.
  rewrite H_card {H_notin H_add H_card}.
  by auto with arith.
- apply NSet.choose_spec1 in H_eq.
  rewrite /= {s0} in H_min.
  apply min_lv_min; first exact: in_level_in.
  move => lv'' n' H_lv.
  inversion H_lv => {H_lv}.
  inversion H_min => {H_min}.
  case (name_eq_dec n n') => H_eq'.
    rewrite -H_eq' in H0.
    rewrite H_find in H0.
    injection H0 => H_eq_lt.
    rewrite H_eq_lt.
    by auto with arith.
  suff H_suff: ~ lv'' < nlv'.(nlv_lv) by omega.
  apply: (H2 _ n').
  apply: in_level_in => //.
  by apply NSetFacts.remove_2.
- apply NSet.choose_spec1 in H_eq.
  rewrite /= {s0} in H_min.
  inversion H_min => {H_min}.
  inversion H => {H}.
  apply min_lv_min.
    apply: in_level_in => //.
    by apply NSetFacts.remove_3 in H1.
  move => lv'' n' H_lv.
  inversion H_lv => {H_lv}.
  case (name_eq_dec n n') => H_eq'.
    rewrite -H_eq' in H3.
    rewrite H_find in H3.
    injection H3 => H_eq_lv.
    by rewrite -H_eq_lv.
  apply: (H0 _ n').
  apply: in_level_in => //.
  exact: NSetFacts.remove_2.
- apply NSet.choose_spec1 in H_eq.
  rewrite /= {s0} in H_min.
  inversion H_min => {H_min}.
  inversion H => {H}.
  apply min_lv_min.
    apply: in_level_in => //.
    by apply NSetFacts.remove_3 in H1.
  move => lv' n' H_lv.
  inversion H_lv => {H_lv}.
  case (name_eq_dec n n') => H_eq'.
    rewrite -H_eq' in H3.
    by rewrite H_find in H3.
  apply: (H0 _ n').
  apply: in_level_in => //.
  exact: NSetFacts.remove_2.
- apply NSet.choose_spec1 in H_eq.
  rewrite /= in H_min.
  apply min_lv_min; first exact: in_level_in.
  move => lv'' n' H_lv.
  inversion H_lv.
  case (name_eq_dec n n') => H_eq'.
    rewrite -H_eq' in H0.
    rewrite H_find in H0.
    injection H0 => H_eq_lv.
    rewrite H_eq_lv.  
    by auto with arith.
  move => H_lt.
  case: H_min.
  exists (mk_nlv n' lv'') => /=.
  apply: in_level_in => //.
  exact: NSetFacts.remove_2.
- apply NSet.choose_spec1 in H_eq.
  rewrite /= in H_min.
  move => [nlv' H_lv].
  inversion H_lv => {H_lv}.
  case: H_min.
  exists nlv'.
  case (name_eq_dec n nlv'.(nlv_n)) => H_eq'.
    rewrite -H_eq' in H0.
    by rewrite H_find in H0.
  apply: in_level_in => //.
  exact: NSetFacts.remove_2.
- apply NSet.choose_spec2 in H_eq.
  move => [nlv' H_lv].
  inversion H_lv => {H_lv}.
  by case (H_eq nlv'.(nlv_n)).
Defined.

Definition par : forall (s : st_par), par_t s :=
  @well_founded_induction_type
  st_par
  st_par_lt
  st_par_lt_well_founded
  par_t
  par_F.

Definition lev : forall (s : st_par),
{ lv' | exists n, exists lv'', min_level s.(st_par_set) s.(st_par_map) n lv'' /\ lv' = lv'' + 1%nat }+
{ ~ exists n, exists lv', level_in s.(st_par_set) s.(st_par_map) n lv' }.
refine
  (fun (s : st_par) =>
   match par s with
   | inleft (exist nlv' H_min) => inleft _ (exist _ (1 + nlv'.(nlv_lv)) _)
   | inright H_ex => inright _ _
   end).
- rewrite /= in H_min.
  exists nlv'.(nlv_n); exists nlv'.(nlv_lv); split => //.
  by omega.
- move => [n [lv' H_lv] ].
  case: H_ex => /=.
  by exists (mk_nlv n lv').
Defined.

Definition parent (fs : NS) (fl : NL) : option name :=
match par (mk_st_par fs fl) with
| inleft (exist nlv' _) => Some nlv'.(nlv_n)
| inright _ => None
end.

Definition level (fs : NS) (fl : NL) : option lv :=
match lev (mk_st_par fs fl) with
| inleft (exist lv' _) => Some lv'
| inright _ => None
end.

Definition olv_eq_dec : forall (lvo lvo' : option lv), { lvo = lvo' }+{ lvo <> lvo' }.
decide equality.
exact: lv_eq_dec.
Defined.

Definition Handler (S : Type) := GenHandler (name * Msg) S Output unit.

Definition RootNetHandler (src : name) (msg : Msg) : Handler Data :=
st <- get ;;
match msg with 
| Level _ => nop 
| Fail => 
  put {| adjacent := NSet.remove src st.(adjacent) ;
         broadcast := st.(broadcast) ;
         levels := st.(levels) |}
end.

Definition NonRootNetHandler (me src: name) (msg : Msg) : Handler Data :=
st <- get ;;
match msg with
| Level None =>
  if olv_eq_dec (level st.(adjacent) st.(levels)) (level st.(adjacent) (NMap.remove src st.(levels))) then
    put {| adjacent := st.(adjacent) ;           
           broadcast := st.(broadcast) ;
           levels := NMap.remove src st.(levels) |}
  else 
    put {| adjacent := st.(adjacent) ;           
           broadcast := true ;
           levels := NMap.remove src st.(levels) |}
| Level (Some lv') =>
  if olv_eq_dec (level st.(adjacent) st.(levels)) (level st.(adjacent) (NMap.add src lv' st.(levels))) then
    put {| adjacent := st.(adjacent) ;
           broadcast := st.(broadcast) ;
           levels := NMap.add src lv' st.(levels) |}
  else
    put {| adjacent := st.(adjacent) ;
           broadcast := true ;
           levels := NMap.add src lv' st.(levels) |}
| Fail => 
  if olv_eq_dec (level st.(adjacent) st.(levels)) (level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels))) then
    put {| adjacent := NSet.remove src st.(adjacent) ;
           broadcast := st.(broadcast) ;
           levels := NMap.remove src st.(levels) |}
  else
    put {| adjacent := NSet.remove src st.(adjacent) ;
           broadcast := true ;
           levels := NMap.remove src st.(levels) |}
end.

Definition NetHandler (me src : name) (msg : Msg) : Handler Data :=
if root_dec me then RootNetHandler src msg 
else NonRootNetHandler me src msg.

Definition level_fold (lvo : option lv) (n : name) (partial : list (name * Msg)) : list (name * Msg) :=
(n, Level lvo) :: partial.

Definition level_adjacent (lvo : option lv) (fs : NS) : list (name * Msg) :=
NSet.fold (level_fold lvo) fs [].

Definition send_level_fold (lvo : option lv) (n : name) (res : Handler Data) : Handler Data :=
send (n, Level lvo) ;; res.

Definition send_level_adjacent (lvo : option lv) (fs : NS) : Handler Data :=
NSet.fold (send_level_fold lvo) fs nop.

Definition RootIOHandler (i : Input) : Handler Data :=
st <- get ;;
match i with
| Broadcast => 
  when st.(broadcast)
  (send_level_adjacent (Some 0) st.(adjacent) ;;
   put {| adjacent := st.(adjacent);
          broadcast := false;
          levels := st.(levels) |})
| LevelRequest => 
  write_output (LevelResponse (Some 0))
end.

Definition NonRootIOHandler (i : Input) : Handler Data :=
st <- get ;;
match i with
| Broadcast =>
  when st.(broadcast)
  (send_level_adjacent (level st.(adjacent) st.(levels)) st.(adjacent) ;; 
  put {| adjacent := st.(adjacent);
         broadcast := false;
         levels := st.(levels) |})
| LevelRequest =>   
  write_output (LevelResponse (level st.(adjacent) st.(levels)))
end.

Definition IOHandler (me : name) (i : Input) : Handler Data :=
if root_dec me then RootIOHandler i 
else NonRootIOHandler i.

Instance Tree_BaseParams : BaseParams :=
  {
    data := Data;
    input := Input;
    output := Output
  }.

Instance Tree_MultiParams : MultiParams Tree_BaseParams NT_NameParams :=
  {
    msg  := Msg ;
    msg_eq_dec := Msg_eq_dec ;
    init_handlers := InitData ;
    net_handlers := fun dst src msg s =>
                      runGenHandler_ignore s (NetHandler dst src msg) ;
    input_handlers := fun nm msg s =>
                        runGenHandler_ignore s (IOHandler nm msg)
  }.

Instance Tree_FailMsgParams : FailMsgParams Tree_MultiParams :=
  {
    msg_fail := Fail
  }.

Lemma net_handlers_NetHandler :
  forall dst src m st os st' ms,
    net_handlers dst src m st = (os, st', ms) ->
    NetHandler dst src m st = (tt, os, st', ms).
Proof.
intros.
simpl in *.
monad_unfold.
repeat break_let.
find_inversion.
destruct u. auto.
Qed.

Lemma NetHandler_cases : 
  forall dst src msg st out st' ms,
    NetHandler dst src msg st = (tt, out, st', ms) ->
    (root dst /\ msg = Fail /\ 
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ 
     level st.(adjacent) st.(levels) = level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ 
     level st.(adjacent) st.(levels) <> level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (root dst /\ exists lvo, msg = Level lvo /\ 
     st' = st /\
     out = [] /\ ms = []) \/
    (~ root dst /\ exists lv_msg, msg = Level (Some lv_msg) /\
     level st.(adjacent) st.(levels) = level st.(adjacent) (NMap.add src lv_msg st.(levels)) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.add src lv_msg st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ exists lv_msg, msg = Level (Some lv_msg) /\
     level st.(adjacent) st.(levels) <> level st.(adjacent) (NMap.add src lv_msg st.(levels)) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.add src lv_msg st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Level None /\
     level st.(adjacent) st.(levels) = level st.(adjacent) (NMap.remove src st.(levels)) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Level None /\
     level st.(adjacent) st.(levels) <> level st.(adjacent) (NMap.remove src st.(levels)) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []).
Proof.
move => dst src msg st out st' ms.
rewrite /NetHandler /RootNetHandler /NonRootNetHandler.
case: msg; monad_unfold.
- case root_dec => /= H_dec.
  * move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
    by left.
  * case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
      by right; left.
    by right; right; left.
- case root_dec => /= H_dec olv_msg.
    move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
    right; right; right; left.
    split => //.
    by exists olv_msg.
  case H_olv_dec: olv_msg => [lv_msg|]; case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
  * right; right; right; right; left.
    split => //.
    by exists lv_msg.
  * right; right; right; right; right; left.
    split => //.
    by exists lv_msg.
  * by right; right; right; right; right; right; left.
  * by right; right; right; right; right; right; right.
Qed.

Lemma input_handlers_IOHandler :
  forall h i d os d' ms,
    input_handlers h i d = (os, d', ms) ->
    IOHandler h i d = (tt, os, d', ms).
Proof.
intros.
simpl in *.
monad_unfold.
repeat break_let.
find_inversion.
destruct u. auto.
Qed.

Lemma fold_left_level_fold_eq :
forall ns nml olv,
fold_left (fun l n => level_fold olv n l) ns nml = fold_left (fun l n => level_fold olv n l) ns [] ++ nml.
Proof.
elim => //=.
move => n ns IH nml olv.
rewrite /level_fold /=.
rewrite IH.
have IH' := IH ([(n, Level olv)]).
rewrite IH'.
set bla := fold_left _ _ _.
rewrite -app_assoc.
by rewrite app_assoc.
Qed.

Lemma send_level_fold_app :
  forall ns st olv nm,
snd (fold_left 
       (fun (a : Handler Data) (e : NSet.elt) => send_level_fold olv e a) ns
       (fun s : Data => (tt, [], s, nm)) st) = 
snd (fold_left 
       (fun (a : Handler Data) (e : NSet.elt) => send_level_fold olv e a) ns
       (fun s : Data => (tt, [], s, [])) st) ++ nm.
Proof.
elim => //=.
move => n ns IH st olv nm.
rewrite {1}/send_level_fold /=.
monad_unfold.
rewrite /=.
rewrite IH.
rewrite app_assoc.
by rewrite -IH.
Qed.

Lemma send_level_adjacent_fst_eq : 
forall fs olv st,
  snd (send_level_adjacent olv fs st) = level_adjacent olv fs.
Proof.
move => fs olv st.
rewrite /send_level_adjacent /level_adjacent.
rewrite 2!NSet.fold_spec.
move: olv st.
elim: NSet.elements => [|n ns IH] //=.
move => olv st.
rewrite {2}/level_fold {2}/send_level_fold.
rewrite fold_left_level_fold_eq.
have IH' := IH olv st.
rewrite -IH'.
monad_unfold.
by rewrite -send_level_fold_app.
Qed.

Lemma fst_fst_fst_tt_send_level_fold : 
forall ns nm olv st,
fst
  (fst
     (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st))) = tt.
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma send_level_adjacent_fst_fst_eq : 
forall fs olv st,
  fst (fst (fst (send_level_adjacent olv fs st))) = tt.
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite fst_fst_fst_tt_send_level_fold.
Qed.

Lemma snd_fst_fst_out_send_level_fold : 
forall ns nm olv st,
snd
  (fst
     (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st))) = [].
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma snd_fst_st_send_level_fold : 
forall ns nm olv st,
snd (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st)) = st.
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma send_level_adjacent_snd_fst_fst : 
forall fs olv st,
  snd (fst (fst (send_level_adjacent olv fs st))) = [].
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite snd_fst_fst_out_send_level_fold.
Qed.

Lemma send_level_adjacent_snd_fst : 
forall fs olv st,
  snd (fst (send_level_adjacent olv fs st)) = st.
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite snd_fst_st_send_level_fold.
Qed.

Lemma send_level_adjacent_eq : 
  forall fs olv st,
  send_level_adjacent olv fs st = (tt, [], st, level_adjacent olv fs).
Proof.
move => fs olv st.
case H_eq: send_level_adjacent => [[[u o] s b]].
have H_eq'_1 := send_level_adjacent_fst_fst_eq fs olv st.
rewrite H_eq /= in H_eq'_1.
have H_eq'_2 := send_level_adjacent_fst_eq fs olv st.
rewrite H_eq /= in H_eq'_2.
have H_eq'_3 := send_level_adjacent_snd_fst_fst fs olv st.
rewrite H_eq /= in H_eq'_3.
have H_eq'_4 := send_level_adjacent_snd_fst fs olv st.
rewrite H_eq /= in H_eq'_4.
by rewrite H_eq'_1 H_eq'_2 H_eq'_3 H_eq'_4.
Qed.

Lemma IOHandler_cases :
  forall h i st u out st' ms,
      IOHandler h i st = (u, out, st', ms) ->
      (root h /\ i = Broadcast /\ st.(broadcast) = true /\
       st'.(adjacent) = st.(adjacent) /\
       st'.(broadcast) = false /\
       st'.(levels) = st.(levels) /\
       out = [] /\ ms = level_adjacent (Some 0) st.(adjacent)) \/
      (~ root h /\ i = Broadcast /\ st.(broadcast) = true /\
       st'.(adjacent) = st.(adjacent) /\
       st'.(broadcast) = false /\
       st'.(levels) = st.(levels) /\
       out = [] /\ ms = level_adjacent (level st.(adjacent) st.(levels)) st.(adjacent)) \/
      (i = Broadcast /\ st.(broadcast) = false /\
       st' = st /\
       out = [] /\ ms = []) \/
      (root h /\ i = LevelRequest /\
       st' = st /\
       out = [LevelResponse (Some 0)] /\ ms = []) \/
      (~ root h /\ i = LevelRequest /\
       st' = st /\
       out = [LevelResponse (level st.(adjacent) st.(levels))] /\ ms = []).
Proof.
move => h i st u out st' ms.
rewrite /IOHandler /RootIOHandler /NonRootIOHandler.
case: i => [|]; monad_unfold.
- case root_dec => /= H_dec H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=.
    by right; right; right; left.
  by right; right; right; right.
- case root_dec => /= H_dec; case H_b: broadcast => /=.
  * left.
    repeat break_let.
    injection Heqp => H_ms H_st H_out H_tt.
    subst.
    injection Heqp2 => H_ms H_st H_out H_tt.
    subst.
    injection H => H_ms H_st H_out H_tt.
    subst.
    rewrite /=.
    have H_eq := send_level_adjacent_eq st.(adjacent) (Some 0) st.
    rewrite Heqp5 in H_eq.
    injection H_eq => H_eq_ms H_eq_st H_eq_o H_eq_tt.
    rewrite H_eq_ms H_eq_o.
    by rewrite app_nil_l -2!app_nil_end.
  * right; right; left.
    injection H => H_ms H_st H_o H_tt.
    by rewrite H_st H_o H_ms.
  * right; left.
    repeat break_let.
    injection Heqp => H_ms H_st H_out H_tt.
    subst.
    injection Heqp2 => H_ms H_st H_out H_tt.
    subst.
    injection H => H_ms H_st H_out H_tt.
    subst.
    rewrite /=.
    have H_eq := send_level_adjacent_eq st.(adjacent) (level st.(adjacent) st.(levels)) st.
    rewrite Heqp5 in H_eq.
    injection H_eq => H_eq_ms H_eq_st H_eq_o H_eq_tt.
    rewrite H_eq_ms H_eq_o.
    by rewrite app_nil_l -2!app_nil_end.
  * right; right; left.
    injection H => H_ms H_st H_o H_tt.
    by rewrite H_st H_o H_ms.
Qed.

Ltac net_handler_cases := 
  find_apply_lem_hyp NetHandler_cases; 
  intuition idtac; try break_exists; 
  intuition idtac; subst; 
  repeat find_rewrite.

Ltac io_handler_cases := 
  find_apply_lem_hyp IOHandler_cases; 
  intuition idtac; try break_exists; 
  intuition idtac; subst; 
  repeat find_rewrite.

Instance Tree_FailureRecorder_base_params_pt_map : BaseParamsPartialMap Tree_BaseParams FR.FailureRecorder_BaseParams :=
  {
    pt_map_data := fun d => FR.mkData d.(adjacent) ;
    pt_map_input := fun _ => None ;
    pt_map_output := fun _ => None
  }.

Instance Tree_FailureRecorder_name_params_tot_map : NameParamsTotalMap NT_NameParams FR.A.NT_NameParams :=
  {
    tot_map_name := id ;
    tot_map_name_inv := id
  }.

Instance Tree_FailureRecorder_multi_params_pt_map : MultiParamsPartialMap Tree_FailureRecorder_base_params_pt_map Tree_FailureRecorder_name_params_tot_map Tree_MultiParams FR.FailureRecorder_MultiParams :=
  {
    pt_map_msg := fun m => match m with Fail => Some FR.Fail | _ => None end ;
  }.

Lemma tot_map_name_inv_inverse : forall n, tot_map_name_inv (tot_map_name n) = n.
Proof. by []. Qed.

Lemma tot_map_name_inverse_inv : forall n, tot_map_name (tot_map_name_inv n) = n.
Proof. by []. Qed.

Lemma pt_init_handlers_eq : forall n,
  pt_map_data (init_handlers n) = init_handlers (tot_map_name n).
Proof.
move => n.
rewrite /= /InitData /=.
by case root_dec => /= H_dec.
Qed.

Lemma pt_net_handlers_some : forall me src m st m',
  pt_map_msg m = Some m' ->
  pt_mapped_net_handlers me src m st = net_handlers (tot_map_name me) (tot_map_name src) m' (pt_map_data st).
Proof.
move => me src.
case => // d.
case => H_eq.
rewrite /pt_mapped_net_handlers.
repeat break_let.
apply net_handlers_NetHandler in Heqp.
net_handler_cases => //.
- by rewrite /= /runGenHandler_ignore /= H1.
- by rewrite /= /runGenHandler_ignore /id /= H2.
- by rewrite /= /runGenHandler_ignore /id /= H2.
Qed.

Lemma pt_net_handlers_none : forall me src m st out st' ps,    
  pt_map_msg m = None ->
  net_handlers me src m st = (out, st', ps) ->
  pt_map_data st' = pt_map_data st /\ pt_map_name_msgs ps = [] /\ pt_map_outputs out = [].
Proof.
move => me src.
case => //.
move => olv d out d' ps H_eq H_eq'.
apply net_handlers_NetHandler in H_eq'.
net_handler_cases => //.
- case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_add.
  by rewrite H_eq'.
- case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_add.
  by rewrite H_eq'.
- case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_add.
  by rewrite H_eq'.
- case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_add.
  by rewrite H_eq'.
Qed.

Lemma pt_input_handlers_some : forall me inp st inp',
  pt_map_input inp = Some inp' ->
  pt_mapped_input_handlers me inp st = input_handlers (tot_map_name me) inp' (pt_map_data st).
Proof. by []. Qed.

Lemma pt_input_handlers_none : forall me inp st out st' ps,
  pt_map_input inp = None ->
  input_handlers me inp st = (out, st', ps) ->
  pt_map_data st' = pt_map_data st /\ pt_map_name_msgs ps = [] /\ pt_map_outputs out = [].
Proof.
move => me.
case.
- move => d out d' ps H_eq H_inp.
  apply input_handlers_IOHandler in H_inp.
  by io_handler_cases.
- move => d out d' ps H_eq H_inp.
  apply input_handlers_IOHandler in H_inp.
  io_handler_cases => //.
  * case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_eq_l.
    by rewrite H_eq'.
  * rewrite /level_adjacent NSet.fold_spec /flip /=.
    elim: NSet.elements => //=.
    move => n l IH.
    rewrite /flip /= /level_fold.
    rewrite fold_left_level_fold_eq.
    by rewrite pt_map_name_msgs_app_distr /= IH.
  * case: d' H2 H3 H4 => /= adjacent0 broadcast0 levels0 H_eq' H_eq'' H_eq_l.
    by rewrite H_eq'.
 * rewrite /level_adjacent NSet.fold_spec /flip /=.
    elim: NSet.elements => //=.
    move => n l IH.
    rewrite /flip /= /level_fold.
    rewrite fold_left_level_fold_eq.
    by rewrite pt_map_name_msgs_app_distr /= IH.
Qed.

Lemma fail_msg_fst_snd : pt_map_msg msg_fail = Some (msg_fail).
Proof. by []. Qed.

Lemma adjacent_to_fst_snd : 
  forall n n', adjacent_to n n' <-> adjacent_to (tot_map_name n) (tot_map_name n').
Proof. by []. Qed.

Theorem Tree_Failed_pt_mapped_simulation_star_1 :
forall net failed tr,
    @step_o_f_star _ _ _ _ Tree_FailMsgParams step_o_f_init (failed, net) tr ->
    exists tr', @step_o_f_star _ _ _ _ FR.FailureRecorder_FailMsgParams step_o_f_init (failed, pt_map_onet net) tr' /\
    pt_trace_remove_empty_out (pt_map_trace tr) = pt_trace_remove_empty_out tr'.
Proof.
have H_sim := @step_o_f_pt_mapped_simulation_star_1 _ _ _  _ _ _ _ _ _ tot_map_name_inv_inverse tot_map_name_inverse_inv pt_init_handlers_eq pt_net_handlers_some pt_net_handlers_none pt_input_handlers_some pt_input_handlers_none ANT_NameOverlayParams FR.A.ANT_NameOverlayParams adjacent_to_fst_snd _ _ fail_msg_fst_snd.
rewrite /tot_map_name /= /id in H_sim.
move => onet failed tr H_st.
apply H_sim in H_st.
move: H_st => [tr' [H_st H_eq]].
rewrite map_id in H_st.
by exists tr'.
Qed.

End Tree.

(*
Require Import StructTact.Fin.

Module N3 : NatValue. Definition n := 3. End N3.
Module FN_N3 : FinNameType N3 := FinName N3.
Module NOT_N3 : NameOrderedType FN_N3 := FinNameOrderedType N3 FN_N3.
Module NOTC_N3 : NameOrderedTypeCompat FN_N3 := FinNameOrderedTypeCompat N3 FN_N3.
Module ANC_N3 := FinCompleteAdjacentNameType N3 FN_N3.
Require Import MSetList.
Module N3Set <: MSetInterface.S := MSetList.Make NOT_N3.
Require Import FMapList.
Module N3Map <: FMapInterface.S := FMapList.Make NOTC_N3.
Module RNT_N3 := FinRootNameType N3 FN_N3.
Module T := Tree FN_N3 NOT_N3 N3Set NOTC_N3 N3Map RNT_N3 ANC_N3.
Print T.Msg.
*)
