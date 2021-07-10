#!/bin/bash -exu

SEED_START=$((1 + "$AWS_BATCH_JOB_ARRAY_INDEX" * "$RANGE"))
SEED_END=$((1 + "$AWS_BATCH_JOB_ARRAY_INDEX" * "$RANGE" + "$RANGE"))
if [ $SEED_END -gt 89 ]
then
	SEED_END=89
fi

crystal build --release solver.cr
mkdir result
for (( i = $SEED_START; i < $SEED_END; i++ )); do
	seed=$(printf "%04d" $i)
	./solver < $seed.json > result/$seed.json
done

aws s3 cp --recursive result s3://marathon-tester/$RESULT_PATH/ --exclude "*" --include "*.json"
