import pytest
import pytest_asyncio
from conftest import ALICE, BOB, StarknetFactory, compile_diamond_contract
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.state import StarknetState
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException


@pytest_asyncio.fixture(scope='module')
async def starknet_factory():
    starknet = await StarknetState.empty()

    diamond_cut_facet_def = compile_diamond_contract('diamond/facets/diamond_cut_facet')
    diamond_cut_addr, diamond_cut_exec_info = await starknet.deploy(
        contract_definition=diamond_cut_facet_def,
        constructor_calldata=[],
    )

    diamond_def = compile_diamond_contract('diamond/diamond')
    alice_diamond_addr, alice_diamond_exec_info = await starknet.deploy(
        contract_definition=diamond_def,
        constructor_calldata=[ALICE, diamond_cut_addr],
    )
    bob_diamond_addr, bob_diamond_exec_info = await starknet.deploy(
        contract_definition=diamond_def,
        constructor_calldata=[BOB, diamond_cut_addr],
    )

    under_over_facet_def = compile_diamond_contract('facets/under_over')
    under_over_facet_addr, under_over_facet_exec_info = await starknet.deploy(
        contract_definition=under_over_facet_def,
        constructor_calldata=[],
    )

    def _f():
        state = starknet.copy()
        diamond_cut = StarknetContract(
            state=state,
            abi=diamond_cut_facet_def.abi,
            contract_address=diamond_cut_addr,
            deploy_execution_info=diamond_cut_exec_info,
        )

        alice_diamond = StarknetContract(
            state=state,
            abi=diamond_def.abi,
            contract_address=alice_diamond_addr,
            deploy_execution_info=alice_diamond_exec_info,
        )

        bob_diamond = StarknetContract(
            state=state,
            abi=diamond_def.abi,
            contract_address=bob_diamond_addr,
            deploy_execution_info=bob_diamond_exec_info,
        )

        under_over = StarknetContract(
            state=state,
            abi=under_over_facet_def.abi,
            contract_address=under_over_facet_addr,
            deploy_execution_info=under_over_facet_exec_info,
        )

        return state, [alice_diamond, bob_diamond, diamond_cut, under_over]

    return _f


@pytest.mark.asyncio
async def test_it_works(starknet_factory: StarknetFactory):
    starknet, [alice_diamond, bob_diamond, _diamond_cut, under_over] = starknet_factory()

    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=alice_diamond.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )
    
    await _add_under_over_facet(starknet, under_over, alice_diamond)

    exec_info = await starknet.invoke_raw(
        contract_address=alice_diamond.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # reference number is initialized to 0 by default
    assert exec_info.retdata == [0]

    # update number
    await starknet.invoke_raw(
        contract_address=alice_diamond.contract_address,
        selector='setReference',
        calldata=[42],
        caller_address=ALICE,
    )

    exec_info = await starknet.invoke_raw(
        contract_address=alice_diamond.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    assert exec_info.retdata == [42]

    # double check bob's contract is untouched
    with pytest.raises(StarkException):
        await starknet.invoke_raw(
            contract_address=bob_diamond.contract_address,
            selector='getReference',
            calldata=[],
            caller_address=ALICE,
        )

    await _add_under_over_facet(starknet, under_over, bob_diamond)

    exec_info = await starknet.invoke_raw(
        contract_address=bob_diamond.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # bob's reference number is initialized to 0 by default
    assert exec_info.retdata == [0]

    # update number
    await starknet.invoke_raw(
        contract_address=bob_diamond.contract_address,
        selector='setReference',
        calldata=[313],
        caller_address=ALICE,
    )

    exec_info = await starknet.invoke_raw(
        contract_address=bob_diamond.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    # bob's reference number was updated
    assert exec_info.retdata == [313]

    # double check alice's contract was not touched
    exec_info = await starknet.invoke_raw(
        contract_address=alice_diamond.contract_address,
        selector='getReference',
        calldata=[],
        caller_address=ALICE,
    )

    assert exec_info.retdata == [42]


async def _add_under_over_facet(starknet: StarknetState, under_over: StarknetContract, contract: StarknetContract):
    # add under_over facet to contract
    #
    # I'm not familiar with the api to convert from rich types down
    # to felt so I'm doing this manually

    calldata = [
        # Adding 3 functions
        3,
        # FacetCut(address, action, selector), action == 0 is add
        under_over.contract_address,
        0,
        get_selector_from_name('setReference'),
        under_over.contract_address,
        0,
        get_selector_from_name('getReference'),
        under_over.contract_address,
        0,
        get_selector_from_name('underOver'),
        # no initialization call
        0,
        0,
    ]

    exec_info = await starknet.invoke_raw(
        contract_address=contract.contract_address,
        selector='diamondCut',
        calldata=calldata,
        caller_address=ALICE,
    )

    # the event being emitted is a good sign
    assert len(exec_info.call_info.events) == 1