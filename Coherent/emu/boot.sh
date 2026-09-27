#!/bin/sh
# boot.sh KERNEL -- reset the VM and boot KERNEL from the tboot prompt.
# Spaces stop the master boot (partition menu), 0 picks the Coherent
# partition, more spaces stop tboot's autoboot, then the name is typed.
Q="py ../tools/qmp.py"
$Q hmp system_reset >/dev/null
for i in $(seq 1 20); do $Q key spc; sleep 0.3; done
$Q key 0
for i in 1 2 3 4 5 6; do sleep 0.5; $Q key spc; done
sleep 1
for i in $(seq 1 16); do $Q key backspace; done
$Q type "$1\n"
