#!/bin/bash -exu

crystal build --release solver.cr
mkdir result
for (( i = 1; i <= 132; i++ )); do
	if [ $(( i % $ARRAY_SIZE )) -eq $AWS_BATCH_JOB_ARRAY_INDEX ]
	then
		seed=$(printf "%04d" $i)
		echo $seed
		./solver < $seed.json > result/$seed.json
		aws s3 cp result/$seed.json s3://marathon-tester/$RESULT_PATH/
	fi
done

