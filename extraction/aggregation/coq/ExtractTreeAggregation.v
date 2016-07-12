Require Import Verdi.
Require Import NPeano.
Require Import PeanoNat.
Require Import StructTact.Fin.

Require Import NameOverlay.
Require Import AggregationDefinitions.
Require Import AggregationAux.
Require Import TreeAggregationStatic.

Require Import mathcomp.ssreflect.ssreflect.
Require Import mathcomp.ssreflect.ssrfun.
Require Import mathcomp.ssreflect.fintype.

Require Import mathcomp.fingroup.fingroup.
Require Import mathcomp.algebra.zmodp.

Require Import ExtrOcamlBasic.
Require Import ExtrOcamlNatInt.
Require Import ExtrOcamlString.

Extract Inlined Constant Nat.max => "Pervasives.max".
Extract Inlined Constant Nat.min => "Pervasives.min".

Extract Inlined Constant length => "List.length".
Extract Inlined Constant negb => "not".
Extract Inlined Constant app => "List.append".
Extract Inlined Constant map => "List.map".
Extract Inlined Constant rev => "List.rev".
Extract Inlined Constant filter => "List.filter".
Extract Inlined Constant fold_left => "(fun a b c -> List.fold_left a c b)".
Extract Inlined Constant in_dec => "(fun h -> List.mem)".
Extract Inlined Constant leb => "(<=)".
Extract Inlined Constant Nat.ltb => "(<)".
Extract Inlined Constant Nat.pred => "(fun n -> if n <= 0 then 0 else n - 1)".

Extract Inlined Constant fin => int.

Extract Inlined Constant fin_eq_dec => "(fun _ -> (=))".
Extract Inlined Constant all_fin => "(fun n -> (Obj.magic (seq 1 n)))".

Extract Inlined Constant fin_compare => "(fun _ n m -> if n = m then EQ else if n < m then LT else GT)".
Extract Inlined Constant fin_comparison => "(fun _ n m -> if n = m then Eq else if n < m then Lt else Gt)".

Extract Inlined Constant fin_to_nat => "(fun _ n -> n)".

Module N5 : NatValue. Definition n := 5. End N5.

Module FN_N5 : FinNameType N5 := FinName N5.
Module NOT_N5 : NameOrderedType FN_N5 := FinNameOrderedType N5 FN_N5.
Module NOTC_N5 : NameOrderedTypeCompat FN_N5 := FinNameOrderedTypeCompat N5 FN_N5.
Module ANC_N5 := FinCompleteAdjacentNameType N5 FN_N5.

Require Import MSetList.
Module N5Set <: MSetInterface.S := MSetList.Make NOT_N5.

Require Import FMapList.
Module N5Map <: FMapInterface.S := FMapList.Make NOTC_N5.
Module RNT_N5 := FinRootNameType N5 FN_N5.

Module CFG <: CommutativeFinGroup.
Definition gT := [finGroupType of 'I_128].
Lemma mulgC : @commutative gT _ mulg. exact: Zp_mulgC. Qed.
End CFG.

Module TA := TreeAggregation FN_N5 NOT_N5 N5Set NOTC_N5 N5Map RNT_N5 CFG ANC_N5.
Import TA.

(*  
The default network has 5 nodes and is fully connected:
0 - root node
1 - nonroot node
2 - nonroot node
3 - nonroot node
4 - nonroot node
*)

(* first set up something to aggregate for each *)
Definition input_0_node_0 := Local (@Ordinal 128 10 erefl).
Definition input_0_node_1 := Local (@Ordinal 128 5 erefl).
Definition input_0_node_2 := Local (@Ordinal 128 3 erefl).
Definition input_0_node_3 := Local (@Ordinal 128 7 erefl).
Definition input_0_node_4 := Local (@Ordinal 128 2 erefl).

(* check that root has level 0, should return (TA.LevelResponse (Some 0)) *)
Definition input_1_node_0 := LevelRequest.

(* check that root has aggregate 10, should return (TA.AggregateResponse 10) *)
Definition input_2_node_0 := AggregateRequest.

(* make root node send its level to everyone *)
Definition input_3_node_0 := Broadcast.

(* check that nonroot node 2 has level 1, should return (TA.LevelResponse (Some 1)) *)
Definition input_1_node_2 := LevelRequest.

(* make nonroot node 2 send its aggregate to root *)
Definition input_2_node_2 := SendAggregate.

(* check root aggregate, should return (TA.AggregateResponse 13) *)
Definition input_4_node_0 := AggregateRequest.

Extraction "extraction/aggregation/coq/TreeAggregation.ml" List.seq TreeAggregation_BaseParams TreeAggregation_MultiParams.
Extraction "extraction/aggregation/coq/TreeAggregationSetup.ml" input_0_node_0 input_0_node_1 input_0_node_2 input_0_node_3 input_0_node_4 input_1_node_0 input_2_node_0 input_3_node_0 input_1_node_2 input_2_node_2 input_4_node_0.
