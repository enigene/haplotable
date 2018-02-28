#!/bin/bash

# First alignment with type A monomers
../haplotable.R -t 4 -s -i S1-master-HOR-manual-aln-171-with-div-cons-boxA-sorted-typeCons.fas -b boxA-J1-SF1-subs.tsv -o haplotable-S1-master-HOR-manual-aln-171-with-div-cons-boxA-sorted-typeCons.html

# Second alignment with type B monomers
../haplotable.R -t 4 -s -i S1-master-HOR-manual-aln-171-with-div-cons-boxB-sorted-typeCons.fas -b boxB-J2-SF1-subs.tsv -o haplotable-S1-master-HOR-manual-aln-171-with-div-cons-boxB-sorted-typeCons.html
