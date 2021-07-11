#!/bin/bash -eu

AWS_ID=$1
RESULT_DIR="../result/$AWS_ID"
mkdir -p $RESULT_DIR
aws s3 cp --recursive s3://marathon-tester/ICFPC2021/$AWS_ID/00 $RESULT_DIR
crystal build validator.cr
for (( i = 1; i <= 106; i++ )); do
	id=$(printf "%04d" $i)
	echo $id
	echo -n "$id " >> $RESULT_DIR/scores.txt
	./validator ../../problems/$id.json $RESULT_DIR/$id.json >> $RESULT_DIR/scores.txt 
done