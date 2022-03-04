import pytest
import pytest_asyncio
from conftest import ALICE, BOB, StarknetFactory, compile_smc_contract
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.state import StarknetState
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException


@pytest_asyncio.fixture(scope='module')
async def starknet_factory():
    starknet = await StarknetState.empty()

    module_registry_def = compile_smc_contract('smc/modules/module_registry')
    module_registry_addr, module_registry_exec_info = await starknet.deploy(
        contract_definition=module_registry_def,
        constructor_calldata=[],
    )

    smc_main_def = compile_smc_contract('smc/main')

    alice_main_addr, alice_main_exec_info = await starknet.deploy(
        contract_definition=smc_main_def,
        constructor_calldata=[ALICE, module_registry_addr],
    )
    bob_main_addr, bob_main_exec_info = await starknet.deploy(
        contract_definition=smc_main_def,
        constructor_calldata=[BOB, module_registry_addr],
    )

    under_over_module_def = compile_smc_contract('modules/under_over')
    under_over_module_addr, under_over_module_exec_info = await starknet.deploy(
        contract_definition=under_over_module_def,
        constructor_calldata=[],
    )

    module_introspection_def = compile_smc_contract('smc/modules/module_introspection')
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

        alice_main = StarknetContract(
            state=state,
            abi=smc_main_def.abi,
            contract_address=alice_main_addr,
            deploy_execution_info=alice_main_exec_info,
        )

        bob_main = StarknetContract(
            state=state,
            abi=smc_main_def.abi,
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
            deploy_execution_info=module_introspection_addr,
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
    
    await _add_under_over_module(starknet, under_over, alice_main)

    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # reference number is initialized to 0 by default
    assert exec_info.retdata == [0]

    # update number
    await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='setReference',
        calldata=[42],
        caller_address=ALICE,
    )

    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    assert exec_info.retdata == [42]

    # double check bob's contract is untouched
    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=bob_main.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )

    await _add_under_over_module(starknet, under_over, bob_main)

    exec_info = await starknet.invoke_raw(
        contract_address=bob_main.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # bob's reference number is initialized to 0 by default
    assert exec_info.retdata == [0]

    # update number
    await starknet.invoke_raw(
        contract_address=bob_main.contract_address,
        selector='setReference',
        calldata=[313],
        caller_address=ALICE,
    )

    exec_info = await starknet.invoke_raw(
        contract_address=bob_main.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # bob's reference number was updated
    assert exec_info.retdata == [313]

    # double check alice's contract was not touched
    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    assert exec_info.retdata == [42]

    await _remove_under_over_module(starknet, under_over, bob_main)

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

    await _add_module_introspection(starknet, module_introspection, alice_main)

    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='moduleAddresses',
        calldata=[],
        caller_address=ALICE,
    )

    assert exec_info.retdata[0] == 2
    assert set(exec_info.retdata[1:]) == {module_registry.contract_address, module_introspection.contract_address}

    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='moduleFunctionSelectors',
        calldata=[module_registry.contract_address],
        caller_address=ALICE,
    )

    assert exec_info.retdata[0] == 1
    assert exec_info.retdata[1:] == [get_selector_from_name('changeModules')]

    exec_info = await starknet.invoke_raw(
        contract_address=alice_main.contract_address,
        selector='moduleAddress',
        calldata=[get_selector_from_name('moduleAddresses')],
        caller_address=ALICE,
    )

    assert exec_info.retdata == [module_introspection.contract_address]


async def _add_under_over_module(starknet: StarknetState, under_over: StarknetContract, contract: StarknetContract):
    # add: action = 0
    await _update_under_over_module(starknet, under_over, contract, 0)


async def _remove_under_over_module(starknet: StarknetState, under_over: StarknetContract, contract: StarknetContract):
    # remove: action = 2
    await _update_under_over_module(starknet, under_over, contract, 2)


async def _update_under_over_module(starknet: StarknetState, under_over: StarknetContract, contract: StarknetContract, action: int):
    # add/remove under over module from contract
    #
    # I'm not familiar with the api to convert from rich types down
    # to felt so I'm doing this manually

    calldata = [
        # Adding 3 functions
        3,
        # ModuleFunctionAction(address, action, selector)
        under_over.contract_address,
        action,
        get_selector_from_name('setReference'),
        under_over.contract_address,
        action,
        get_selector_from_name('getReference'),
        under_over.contract_address,
        action,
        get_selector_from_name('underOver'),
        # no initialization call
        0,
        0,
    ]

    exec_info = await starknet.invoke_raw(
        contract_address=contract.contract_address,
        selector='changeModules',
        calldata=calldata,
        caller_address=ALICE,
    )

    # the event being emitted is a good sign
    assert len(exec_info.call_info.events) == 1


async def _add_module_introspection(starknet: StarknetState, module_introspection: StarknetContract, contract: StarknetContract):
    calldata = [
        # Adding 3 functions
        3,
        # ModuleFunctionAction(address, action, selector)
        module_introspection.contract_address,
        0,
        get_selector_from_name('moduleFunctionSelectors'),
        module_introspection.contract_address,
        0,
        get_selector_from_name('moduleAddresses'),
        module_introspection.contract_address,
        0,
        get_selector_from_name('moduleAddress'),
        # no initialization call
        0,
        0,
    ]

    exec_info = await starknet.invoke_raw(
        contract_address=contract.contract_address,
        selector='changeModules',
        calldata=calldata,
        caller_address=ALICE,
    )

    # the event being emitted is a good sign
    assert len(exec_info.call_info.events) == 1