open Base
open Hardcaml

let depth = 8
let data_width = 4
let sp_width = Int.ceil_log2 depth


module Ref_stack = struct
  type t =
    {
      mutable sp  : int;
      mem         : int array;
    }

  let create depth =
    { sp = 0; mem = Array.create ~len:depth 0 }

  let push t x =
    t.mem.(t.sp) <- x;
    t.sp <- t.sp + 1

  let pop t =
    t.sp <- t.sp - 1

  let set_sp t v =
    t.sp <- v

  let top t =
    if t.sp = 0 then 0 else t.mem.(t.sp - 1)
end


let get_int sim name =
  !(Cyclesim.out_port sim name) |> Bits.to_int


let step ~sim ~ref ~push ~pop ~set_sp ~sp_val ~data_in =
  (* drive inputs *)
  Cyclesim.in_port sim "push"   := Bits.of_int ~width:1 push;
  Cyclesim.in_port sim "pop"    := Bits.of_int ~width:1 pop;
  Cyclesim.in_port sim "set_sp" := Bits.of_int ~width:1 set_sp;
  Cyclesim.in_port sim "sp_val" := Bits.of_int ~width:sp_width sp_val;
  Cyclesim.in_port sim "data_in":= Bits.of_int ~width:data_width data_in;

  Cyclesim.cycle sim;

  (* update reference *)
  if set_sp = 1 then Ref_stack.set_sp ref sp_val
  else begin
    if push = 1 then Ref_stack.push ref data_in;
    if pop  = 1 then Ref_stack.pop ref;
  end;

  (* check top *)
  let hw_top = get_int sim "top" in
  let sw_top = Ref_stack.top ref in

  if hw_top <> sw_top then
  failwith
    (Printf.sprintf
       "Mismatch: hw_top=%d sw_top=%d (sp=%d)"
       hw_top sw_top ref.sp)


let circuit =

  let clock = Signal.input "clock" 1 in
  let push = Signal.input "push" 1 in
  let pop = Signal.input "pop" 1 in
  let data_in = Signal.input "data_in" data_width in
  let set_sp = Signal.input "set_sp" 1 in
  let sp_val = Signal.input "sp_val" sp_width in

  let stack = Aofpga.Stack.create ~depth ~clock ~push ~pop ~data_in ~set_sp ~sp_val in

  let outputs =
    Signal.output "top" stack.top
    :: List.mapi stack.mem ~f:(fun i m ->
         Signal.output (Printf.sprintf "mem_%d" i) m
       )
  in

  Circuit.create_exn
      ~name:"stack"
      outputs


let () =
  let sim = Cyclesim.create circuit in
  let ref = Ref_stack.create depth in

  step ~sim ~ref ~push:1 ~pop:0 ~set_sp:0 ~sp_val:0 ~data_in:5;
  step ~sim ~ref ~push:1 ~pop:0 ~set_sp:0 ~sp_val:0 ~data_in:8;
  step ~sim ~ref ~push:0 ~pop:1 ~set_sp:0 ~sp_val:0 ~data_in:0;
  step ~sim ~ref ~push:0 ~pop:0 ~set_sp:1 ~sp_val:2 ~data_in:0;
  step ~sim ~ref ~push:1 ~pop:0 ~set_sp:0 ~sp_val:0 ~data_in:3;

  Stdlib.Printf.printf "Stack test passed\n"

