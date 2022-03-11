from typing import List, Optional
from enum import Enum

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.contract_utils import StructManager, EventManager


class ModuleAction(Enum):
    ADD = 0
    REPLACE = 1
    REMOVE = 2


class ModularContract(StarknetContract):
    """
    A high-level interface to a StarkNet contract that follows the
    Modular Contracts Standard.
    """
    def add_module(self, module: StarknetContract, initializer_args: Optional[List[int]] = None):
        res = self._change_module(module, ModuleAction.ADD, initializer_args)
        # add functions, structs, and events from module to this one
        _add_to_struct_manager(self.struct_manager, module.struct_manager)
        _add_to_event_manager(self.event_manager, module.event_manager)
        _add_functions(self, module)
        return res

    def remove_module(self, module: StarknetContract):
        res = self._change_module(module, ModuleAction.REMOVE)
        # keep structs and events, but remove functions
        _remove_functions(self, module)
        return res

    def _change_module(self, module: StarknetContract, action: ModuleAction, initializer_args: Optional[List[int]] = None):
        actions = []
        for func in module._abi_function_mapping.keys():
            if func == 'initializer':
                continue
            actions.append((
                module.contract_address,
                action.value,
                get_selector_from_name(func),
            ))

        if initializer_args is None:
            return self.changeModules(actions, 0, [])

        return self.changeModules(actions, module.contract_address, initializer_args)


def _add_to_struct_manager(dest: StructManager, src: StructManager):
    for k, v in src._struct_definition_mapping.items():
        dest._struct_definition_mapping[k] = v


def _add_to_event_manager(dest: EventManager, src: EventManager):
    for k, v in src._abi_event_mapping.items():
        dest._abi_event_mapping[k] = v

    for k, v in src._selector_to_name.items():
        dest._selector_to_name[k] = v


def _add_functions(dest: StarknetContract, src: StarknetContract):
    for k, v in src._abi_function_mapping.items():
        dest._abi_function_mapping[k] = v


def _remove_functions(dest: StarknetContract, src: StarknetContract):
    for k, _v in src._abi_function_mapping.items():
        del dest._abi_function_mapping[k]
