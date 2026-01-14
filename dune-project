(lang dune 3.20)
(name aofpga)

(generate_opam_files true)

(package
 (name aofpga)
 (depends
  (ocaml (>= 5.3.0))
  dune
  base
  hardcaml
  hardcaml_waveterm
 ))
