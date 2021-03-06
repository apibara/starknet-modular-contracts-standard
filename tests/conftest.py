import asyncio
from pathlib import Path
from typing import List, Protocol, Tuple

import pytest
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.state import StarknetState


ALICE = 1189998819991197253
BOB = 118999881999119725311


class StarknetFactory(Protocol):
    def __call__(self) -> Tuple[StarknetState, List[StarknetContract]]:
        ...


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()



_root_dir = Path(__file__).parent.parent
_examples_dir = _root_dir / 'examples'
_contracts_dir = _root_dir / 'smc'


def compile_examples_contract(contract_name):
    filename = str(_examples_dir / f'{contract_name}.cairo')
    return compile_starknet_files(
        [filename],
        debug_info=True,
        cairo_path=[
            str(_contracts_dir),
            str(_root_dir / 'vendor' / 'cairo-contracts'),
        ],
    )


def compile_smc_contract(contract_name):
    filename = contract_path(contract_name)
    return compile_starknet_files(
        [filename],
        debug_info=True,
        cairo_path=[
            str(_contracts_dir),
            str(_root_dir / 'vendor' / 'cairo-contracts'),
        ],
    )


def contract_path(contract_name):
    return str(_contracts_dir / f'{contract_name}.cairo')
