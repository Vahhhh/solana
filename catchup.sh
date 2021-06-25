#!/bin/bash
solana catchup /root/solana/validator-keypair.json --our-localhost ; while [[ $? > 0 ]]; do sleep 5 && solana catchup /root/solana/validator-keypair.json --our-localhost; done
