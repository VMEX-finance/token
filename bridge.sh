#! /usr/bin/bash


forge script ./script/Counter.s.sol:BridgeToken -vvv --broadcast --rpc-url $AVAX_FUJI_RPC --sig "run(address,uint8,address)" -- $1 0 $2
