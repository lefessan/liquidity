#!/bin/sh

DEFAULT='\033[0m'
RED='\033[0;31m'

test=$1
echo "\n[check.sh] test = $test"

LIQUIDITY=liquidity
LIQUIDITY_ENV=ocplib-liquidity-env
TEZOS=./tezos/_obuild/tezos-client/tezos-client.asm
LIQUIDITY_COMP=./_obuild/ocp-liquidity-comp/ocp-liquidity-comp.asm
LIQUIDITY_MISC=ocplib-liquidity-misc
LIQUIDITY_ENV=ocplib-liquidity-env

echo ./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq
./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq || exit 2

if [ -f ${TEZOS} ] ; then
    ${TEZOS} typecheck program tests/$test.liq.tz || exit 2
else
    echo "\n${RED}${TEZOS} not present ! typechecking of tests/$test.liq.tz skipped${DEFAULT}\n"
fi

echo ./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq.tz
./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq.tz || exit 2

echo ./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq.tz.liq 
./_obuild/${LIQUIDITY}/${LIQUIDITY}.asm tests/$test.liq.tz.liq || exit 2

if [ -f ${TEZOS} ] ; then
    ${TEZOS} typecheck program tests/$test.liq.tz.liq.tz || exit 2
else
    echo "\n${RED}${TEZOS} not present ! typechecking of tests/$test.liq.tz.liq.tz skipped${DEFAULT}\n"
fi

echo ${LIQUIDITY_COMP} unix.cma -I +../zarith zarith.cma -I _obuild/${LIQUIDITY_MISC} -I _obuild/${LIQUIDITY_ENV} ./_obuild/${LIQUIDITY_MISC}/${LIQUIDITY_MISC}.cma ./_obuild/${LIQUIDITY_ENV}/${LIQUIDITY_ENV}.cma -impl tests/$test.liq
 ${LIQUIDITY_COMP} unix.cma -I +../zarith zarith.cma -I _obuild/${LIQUIDITY_MISC} -I _obuild/${LIQUIDITY_ENV} ./_obuild/${LIQUIDITY_MISC}/${LIQUIDITY_MISC}.cma ./_obuild/${LIQUIDITY_ENV}/${LIQUIDITY_ENV}.cma -impl tests/$test.liq || exit 2
rm -f a.out
