open Base
open Hardcaml
open Signal


let cto_ref ~width (x : int) : int =
  let rec loop i =
    if i >= width then width
    else if ((x lsr i) land 1) = 1 then loop (i + 1)
    else i
  in
  loop 0


let () =
  (* test powers of two: 2, 4, 8, 16 *)
  for k = 1 to 4 do
    let data_width = 1 lsl k in

    let data_in = input "data_in" data_width in

    let trailing_ones =
      Aofpga.Count_trailing_ones.create
        data_in
    in

    let outputs =
      [ output "count" trailing_ones ]
    in

    let circuit =
      Circuit.create_exn
        ~name:(Printf.sprintf "count_trailing_ones_%d" data_width)
        outputs
    in

    (* ----- simulate ----- *)
    let sim = Cyclesim.create circuit in
    let data_in_p = Cyclesim.in_port sim "data_in" in
    let count_p   = Cyclesim.out_port sim "count" in

    let max = (1 lsl data_width) - 1 in

    for i = 0 to max do
      data_in_p := Bits.of_int ~width:data_width i;
      Cyclesim.cycle sim;

      let hw = Bits.to_int !count_p in
      let sw = cto_ref ~width:data_width i in

      if hw <> sw then begin
        Stdlib.Printf.eprintf
          "CTO mismatch! width=%d input=0x%X expected=%d got=%d\n"
          data_width i sw hw;
        Stdlib.exit 1
      end
    done;

    Stdlib.Printf.printf
      "width=%d passed all tests\n\n"
      data_width
  done;

  Stdlib.Printf.printf "All Count_trailing_ones tests passed!\n"
