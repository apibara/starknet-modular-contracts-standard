%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero

from smc.interfaces.module_registry import (
    ModuleFunctionAction,
    ModuleFunctionChange,
    MODULE_FUNCTION_ADD,
    MODULE_FUNCTION_REPLACE,
    MODULE_FUNCTION_REMOVE
)

# Map function selectors to the modules that execute the function.
@storage_var
func _module_registry_modules(selector : felt) -> (module_address : felt):
end

# Module registry owner
@storage_var
func _module_registry_owner() -> (owner : felt):
end

# get_selector_from_name('changeModules')
const CHANGE_MODULES_SELECTOR = 1808683055422503325942160754016371337440997851558534157930265361990569747463

@external
func changeModules{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
    alloc_locals

    module_registry_change_modules(actions_len, actions, address, calldata_len, calldata)

    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    ModuleFunctionChange.emit(actions_len, actions, address, calldata_len, calldata)

    return ()
end

func module_registry_set_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt):
    # checks: if the owner is zero everyone is an owner.
    assert_not_zero(owner)

    # effects: update owner
    _module_registry_owner.write(owner)

    return ()
end

func module_registry_get_module_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(selector : felt) -> (address : felt):
    let (address) = _module_registry_modules.read(selector)
    return (address=address)
end

func module_registry_change_modules{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
    _change_modules_loop(actions_len, actions)

    # call address _init with calldata
    return ()
end

func _change_modules_loop{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*):
    if actions_len == 0:
        return ()
    end

    let module_action : ModuleFunctionAction = [actions]

    if module_action.action == MODULE_FUNCTION_ADD:
        # TODO: check selector does not exist already
        _module_registry_modules.write(module_action.selector, module_action.module_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if module_action.action == MODULE_FUNCTION_REPLACE:
        # TODO: no need to check if already exists?
        _module_registry_modules.write(module_action.selector, module_action.module_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if module_action.action == MODULE_FUNCTION_REMOVE:
        # Zero data for the given selector
        _module_registry_modules.write(module_action.selector, 0)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return _change_modules_loop(actions_len - 1, actions + ModuleFunctionAction.SIZE)
end
