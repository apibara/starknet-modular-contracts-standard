%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import delegate_call

from openzeppelin.access.ownable import Ownable_initializer

from smc.interfaces.module_registry import ModuleFunctionAction, MODULE_FUNCTION_ADD
from smc.modules.module_registry import (
    module_registry_change_modules, module_registry_get_module_address,
    CHANGE_MODULES_SELECTOR)

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, module_registry_address : felt):
    alloc_locals

    # effects: set owner of this contract
    Ownable_initializer(owner)

    local module_action : ModuleFunctionAction
    module_action.action = MODULE_FUNCTION_ADD
    module_action.selector = CHANGE_MODULES_SELECTOR
    module_action.module_address = module_registry_address

    let (actions : ModuleFunctionAction*) = alloc()
    assert [actions] = module_action

    let (calldata : felt*) = alloc()

    # effects: initialize registry
    module_registry_change_modules(1, actions, 0, 0, calldata)

    return ()
end

@external
@raw_input
@raw_output
func __default__{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, calldata_size : felt, calldata : felt*) -> (
        retdata_size : felt, retdata : felt*):
    let (address) = module_registry_get_module_address(selector)

    with_attr error_message("selector not found"):
        assert_not_zero(address)
    end

    let (retdata_size : felt, retdata : felt*) = delegate_call(
        contract_address=address,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata)
    return (retdata_size=retdata_size, retdata=retdata)
end
