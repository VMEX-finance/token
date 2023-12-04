#! /usr/bin/bash

forge script ./script/Counter.s.sol:WhitelistToken -vvv --broadcast --rpc-url $AVAX_FUJI_RPC --private-key b3e8bababde3083daeca3e2666427d225ea28c795a0c5d19f48afb5c26280768 --sig "whitelist(uint8, address)" -- 0 $2 && 
forge script ./script/Counter.s.sol:WhitelistToken -vvv --broadcast --rpc-url $ETH_SEPOLIA_RPC --private-key b3e8bababde3083daeca3e2666427d225ea28c795a0c5d19f48afb5c26280768 --sig "whitelist(uint8, address)" -- 2 $1

