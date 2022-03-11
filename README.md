# StarkNet Modular Contracts (SMC) Standard

This repository presents a way to build and deploy modular StarkNet contracts.
It is heavily inspired by the [Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535), but uses a different naming convention to avoid confusion.

## Running

You can use nile to compile the smart contracts:

```bash
nile compile
```

You can use pytest to runs the tests:

```bash
PYTHONPATH=. pytest tests
```

## Modular Contracts

The idea is to deploy a `main` contract and then add modules to it
to increase its functionality. Modules can be replaced to perform an
upgrade. The `main` module automatically registers the `ModuleRegistry`
module on deployment. You can make a contract immutable by removing the
`ModuleRegistry`.

## Built-ins modules

 * `ModuleRegistry`: provides a function to add, replace, and remove modules.
 * `ModuleIntrospection`: provides functions to inspect registered modules.


## Authoring modules

New modules are best implemented using the [extensibility
pattern](https://github.com/OpenZeppelin/cairo-contracts/blob/main/docs/Extensibility.md)
proposed by Open Zeppelin.

Modules should never import functions from other modules, they should instead
import functions from libraries. Importing from modules results in accidentally
exporting the module's external functions.

Modules are like contracts, but they don't have a
constructor, initialization is provided by defining an `@external` `initializer`
function.
