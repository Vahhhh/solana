#!/bin/bash

result=$(timeout -k 50 45 python3 "/root/solana/monitoring/$1.py")

if [ -z "${result}" ]
then
        echo "{}"
else
        echo "$result"
fi




