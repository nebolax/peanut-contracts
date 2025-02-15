# Peanut Protocol

Repo for peanut smart contracts

Foundry reference: https://book.getfoundry.sh/getting-started/first-steps

## Deployments

See list of deployed contracts on `contracts.json`
See `deploy.py` for deploying more

## Install

```bash
forge install
```

## Test

```bash
forge test
```

Single test:
```bash
 forge test --match-path test/V5/testX** -vvvv
```

Test on Fork:
```bash
 forge test --fork-url "https://ethereum-goerli.publicnode.com" --match-path test/V5/testWithdrawDepositXChain** -vvvv
```

## Deploy

Use `deploy.py` for simplicity.
Alternatively: `forge create...` or `forge script`

## Run a script

e.g. (optional params)

```bash
forge script script/DeployEthRome.s.sol:DeployEthRome --rpc-url optimism-goerli --broadcast --verify -vvvv --legacy
```

## Other useful commands

e.g. verify contract:
    
```bash
    forge verify-contract 0x690481ce72b1080bd928a35a0ecf329be902cd6a src/V5/PeanutV5.sol:PeanutV5 --watch --chain base
```