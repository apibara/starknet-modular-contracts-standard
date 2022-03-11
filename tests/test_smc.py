from typing import Optional

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.state import StarknetState
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException

from smc.testing import ModularContract

from conftest import ALICE, BOB, StarknetFactory, compile_examples_contract, compile_smc_contract


@pytest_asyncio.fixture(scope='module')
async def starknet_factory():
    starknet = await StarknetState.empty()

    module_registry_def = compile_smc_contract('modules/module_registry')
    module_registry_addr, module_registry_exec_info = await starknet.deploy(
        contract_definition=module_registry_def,
        constructor_calldata=[],
    )

    smc_main_def = compile_smc_contract('main')

    alice_main_addr, alice_main_exec_info = await starknet.deploy(
        contract_definition=smc_main_def,
        constructor_calldata=[ALICE, module_registry_addr],
    )
    bob_main_addr, bob_main_exec_info = await starknet.deploy(
        contract_definition=smc_main_def,
        constructor_calldata=[BOB, module_registry_addr],
    )

    under_over_module_def = compile_examples_contract('under_over')
    under_over_module_addr, under_over_module_exec_info = await starknet.deploy(
        contract_definition=under_over_module_def,
        constructor_calldata=[],
    )

    module_introspection_def = compile_smc_contract('modules/module_introspection')
    module_introspection_addr, module_introspection_exec_info = await starknet.deploy(
        contract_definition=module_introspection_def,
        constructor_calldata=[]
    )


    def _f():
        state = starknet.copy()
        module_registry = StarknetContract(
            state=state,
            abi=module_registry_def.abi,
            contract_address=module_registry_addr,
            deploy_execution_info=module_registry_exec_info,
        )

        alice_main = ModularContract(
            state=state,
            abi=module_registry_def.abi,
            contract_address=alice_main_addr,
            deploy_execution_info=alice_main_exec_info,
        )

        bob_main = ModularContract(
            state=state,
            abi=module_registry_def.abi,
            contract_address=bob_main_addr,
            deploy_execution_info=bob_main_exec_info,
        )

        under_over = StarknetContract(
            state=state,
            abi=under_over_module_def.abi,
            contract_address=under_over_module_addr,
            deploy_execution_info=under_over_module_exec_info,
        )

        module_introspection = StarknetContract(
            state=state,
            abi=module_introspection_def.abi,
            contract_address=module_introspection_addr,
            deploy_execution_info=module_introspection_exec_info,
        )

        return state, [alice_main, bob_main, module_registry, under_over, module_introspection]

    return _f


@pytest.mark.asyncio
async def test_it_works(starknet_factory: StarknetFactory):
    starknet, [alice_main, bob_main, _module_registry, under_over, _module_introspection] = starknet_factory()

    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=alice_main.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )
    
    await alice_main.add_module(under_over).invoke(caller_address=ALICE)

    exec_info = await alice_main.getReference().call(caller_address=ALICE)

    # reference number is initialized to 0 by default
    assert exec_info.result.reference == 0

    # update number
    await alice_main.setReference(42).invoke(caller_address=ALICE)

    exec_info = await alice_main.getReference().call(caller_address=ALICE)
    assert exec_info.result.reference == 42

    # double check bob's contract is untouched
    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=bob_main.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )

    await bob_main.add_module(under_over, initializer_args=[100]).invoke(caller_address=BOB)

    exec_info = await bob_main.getReference().call(caller_address=ALICE)
    # since we called the initializer, the reference number is initalized
    # to something else
    assert exec_info.result.reference == 100

    # update number
    await bob_main.setReference(313).invoke(caller_address=BOB)
    exec_info = await bob_main.getReference().call(caller_address=ALICE)

    # bob's reference number was updated
    assert exec_info.result.reference == 313

    # double check alice's contract was not touched
    exec_info = await alice_main.getReference().call(caller_address=ALICE)
    assert exec_info.result.reference == 42

    await bob_main.remove_module(under_over).invoke(caller_address=BOB)

    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=bob_main.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )


@pytest.mark.asyncio
async def test_module_introspection(starknet_factory: StarknetFactory):
    starknet, [alice_main, _bob_main, module_registry, _under_over, module_introspection] = starknet_factory()

    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=alice_main.contract_address,
            selector='moduleAddresses',
            calldata=[],
            caller_address=ALICE,
        )

    await alice_main.add_module(module_introspection).invoke(caller_address=ALICE)

    exec_info = await alice_main.moduleAddresses().call(caller_address=ALICE)
    assert set(exec_info.result.module_addresses) == {module_registry.contract_address, module_introspection.contract_address}

    exec_info = await alice_main.moduleFunctionSelectors(module_registry.contract_address).call(caller_address=ALICE)
    assert exec_info.result.selectors == [get_selector_from_name('changeModules')]

    exec_info = await alice_main.moduleAddress(get_selector_from_name('moduleAddresses')).call(caller_address=ALICE)
    assert exec_info.result.module_address == module_introspection.contract_address


@pytest.mark.asyncio
async def test_ownership(starknet_factory: StarknetFactory):
    starknet, [alice_main, _bob_main, _module_registry, under_over, _module_introspection] = starknet_factory()
    
    with pytest.raises(StarkException):
        await alice_main.add_module(under_over).invoke(caller_address=BOB)

    exec_info = await alice_main.add_module(under_over).invoke(caller_address=ALICE)
    assert len(exec_info.raw_events) == 1
