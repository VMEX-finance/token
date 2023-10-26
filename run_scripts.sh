#! /usr/bin/bash

#deploy eth and arb token contracts
forge script ./script/Counter.s.sol:TokenScript -vvv --broadcast --rpc-url $AVAX_FUJI_RPC --sig "run(uint8)" -- 2 &&
forge script ./script/Counter.s.sol:TokenScript -vvv --broadcast --rpc-url $ETH_SEPOLIA_RPC --sig "run(uint8)" -- 0
