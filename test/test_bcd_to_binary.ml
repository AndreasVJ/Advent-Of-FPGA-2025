open Base
open Hardcaml
open Signal
open Hardcaml_waveterm


let num_digits = 12
let digit_width = 4

let circuit =

  let clock = input "clock" 1 in

  let digits =
    List.init num_digits ~f:(fun i ->
      input (Printf.sprintf "d%02d" i) digit_width
    )
  in

  let start = input "start" 1 in

  let bcd_to_binary = Aofpga.Bcd_to_binary.create ~clock ~digits ~start in

  let outputs =
    [
      Signal.output "result" bcd_to_binary.result;
      Signal.output "valid" bcd_to_binary.valid;
    ]
  in

  Circuit.create_exn
      ~name:"bcd_to_binary"
      outputs


let () =
  let sim = Cyclesim.create circuit in
  let waves, sim = Waveform.create sim in

  let digits =
    List.init num_digits ~f:(fun i ->
      Cyclesim.in_port sim (Printf.sprintf "d%02d" i)
    )
  in

  let start = Cyclesim.in_port sim "start" in

  List.iteri ~f:(fun i x ->
    x := Bits.of_int ~width:digit_width ((i+1) % 10);
  ) digits;

  start := Bits.vdd;
  Cyclesim.cycle sim;
  start := Bits.gnd;

  for _ = 0 to num_digits do
    Cyclesim.cycle sim;
  done;

  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;

  List.iteri ~f:(fun i x ->
    x := Bits.of_int ~width:digit_width ((i+5) % 10);
  ) digits;

  start := Bits.vdd;
  Cyclesim.cycle sim;
  start := Bits.gnd;

  for _ = 0 to num_digits do
    Cyclesim.cycle sim;
  done;

  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;

  Hardcaml_waveterm_interactive.run waves
