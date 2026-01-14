open Base
open Hardcaml
open Signal
(* open Hardcaml_waveterm *)

let line_length = 100
let depth = 12
let data_width = 4
let sp_width = Int.ceil_log2 depth
let remaining_width = Int.ceil_log2 line_length
let ans_width =
    Int.of_float
      (Stdlib.Float.ceil (Float.of_int depth *. Float.log2 10.))
    + 8


let circuit =

  (* Inputs *)
  let clock = input "clock" 1 in
  let data_in = input "data_in" data_width in
  let input_not_done = input "input_not_done" 1 in

  let spec = Reg_spec.create ~clock () in

  (* Stack logic *)
  let remaining = Aofpga.Looping_down_counter.create
    ~clock
    ~reset:gnd
    ~enable:input_not_done
    ~width:remaining_width
    ~start_value:(line_length-1)
  in

  let set_sp = wire 1 in
  let sp_val = wire sp_width in

  let stack_has_place = wire 1 in
  let stack = Aofpga.Stack.create
    ~depth
    ~clock
    ~push:(input_not_done)
    ~pop:gnd
    ~data_in
    ~set_sp
    ~sp_val
  in

  stack_has_place <== ~:(stack.full);

  let gt_data_in =
    concat_msb (
      List.map stack.mem ~f:(fun m ->
        m <: data_in
      )
    )
  in

  let space_ok =
    concat_msb (
      List.init depth ~f:(fun i ->
        let need = depth - i in
        remaining >=:. need
      )
    )
  in

  let idx_gte_sp =
    concat_msb (
      List.init depth ~f:(fun i ->
        stack.sp <=:. i
      )
    )
  in

  let valid_pop = (gt_data_in &: space_ok) |: idx_gte_sp in

  let trailing_ones = Aofpga.Count_trailing_ones.create (uresize valid_pop 16) in

  let end_of_line = (remaining ==:. 0) &: ~:(stack.empty) in

  set_sp <== ((stack.top <: data_in &: ~:(stack.empty)) |: end_of_line);
  sp_val <== mux end_of_line
    [
      of_int ~width:sp_width depth -: (select trailing_ones 3 0);
      of_int ~width:sp_width 0
    ];


  (* BCD and accumelate logic *)
  let line_ans = Aofpga.Bcd_to_binary.create
    ~clock
    ~digits:stack.mem
    ~start:end_of_line
  in

  let prev_line_ans_valid =
    reg
      spec
      line_ans.valid
  in

  let accumelate_ans = ~:prev_line_ans_valid &: line_ans.valid in

  let ans =
    reg_fb
      spec
      ~enable:accumelate_ans
      ~width:ans_width
      ~f:(fun q ->
        q +: (uresize line_ans.result ans_width)
      )
  in


  (* Outputs: Most of them are for debugging *)
  let outputs =
    output "top" stack.top
    :: List.mapi stack.mem ~f:(fun i m ->
         output (Printf.sprintf "mem_%02d" i) m
       )
    @ [output "sp" stack.sp]
    @ [output "remaining" remaining]
    @ [output "ans" ans]
    @ [output "line_ans" line_ans.result]
    @ [output "end_of_line" end_of_line]
    @ [output "accumelate_ans" accumelate_ans]
  in


  Circuit.create_exn
      ~name:"aoc_day_3"
      outputs


let with_file_chars filename f =
  let ic = Stdlib.open_in filename in
  Stdlib.Fun.protect
    ~finally:(fun () -> Stdlib.close_in ic)
    (fun () ->
      try
        while true do
          let c = Stdlib.input_char ic in
          match c with
          | '0' .. '9' ->
              let d = Char.to_int c - Char.to_int '0' in
              f d
          | '\n' -> ()
          | _ -> ()
        done
      with End_of_file -> ()
    )


let () =

  let sim = Cyclesim.create circuit in
  (* let waves, sim = Waveform.create sim in *)

  let data_in = Cyclesim.in_port sim "data_in" in
  let input_not_done = Cyclesim.in_port sim "input_not_done" in

  let ans = Cyclesim.out_port sim "ans" in

  input_not_done := Bits.of_int ~width:1 1;

  let count = ref 0 in

  with_file_chars "day3.txt" (fun d ->
    Stdlib.incr count;

    data_in := Bits.of_int ~width:data_width d;
    Cyclesim.cycle sim;
  );


  input_not_done := Bits.of_int ~width:1 0;

  for _ = 0 to 15 do
    Cyclesim.cycle sim;
  done;

  Stdlib.Printf.printf "%d\n" (Bits.to_int !ans);


  (* Hardcaml_waveterm_interactive.run waves *)
