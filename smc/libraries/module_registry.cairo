%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import delegate_call

from smc.interfaces.module_registry import (
    ModuleFunctionAction, ModuleFunctionChange, MODULE_FUNCTION_ADD, MODULE_FUNCTION_REPLACE,
    MODULE_FUNCTION_REMOVE)

# Map function selectors to the modules that execute the function.
@storage_var
func _module_registry_modules(selector : felt) -> (module_address : felt):
end

# List of all selectors
@storage_var
func _module_registry_selectors(index : felt) -> (selector : felt):
end

# Length of _module_registry_selectors
@storage_var
func _module_registry_selectors_len() -> (len : felt):
end

# get_selector_from_name('changeModules')
const CHANGE_MODULES_SELECTOR = 1808683055422503325942160754016371337440997851558534157930265361990569747463

# get_selector_from_name('initializer')
const INITIALIZER_SELECTOR = 1295919550572838631247819983596733806859788957403169325509326258146877103642

# ---------------------------------------------------------------------------- #
#                                                                              #
#                          Manage Module Functions                             #
#                                                                              #
# ---------------------------------------------------------------------------- #

func module_registry_change_modules{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
    alloc_locals

    _module_registry_change_modules(actions_len, actions, address, calldata_len, calldata)

    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    ModuleFunctionChange.emit(actions_len, actions, address, calldata_len, calldata)

    return ()
end

func module_registry_get_module_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(selector : felt) -> (
        address : felt):
    let (address) = _module_registry_modules.read(selector)
    return (address=address)
end

func _module_registry_change_modules{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
    _change_modules_loop(actions_len, actions)

    if address != 0:
        assert_not_zero(calldata_len)

        let (retdata_size : felt, retdata : felt*) = delegate_call(
            contract_address=address,
            function_selector=INITIALIZER_SELECTOR,
            calldata_size=calldata_len,
            calldata=calldata)

        assert retdata_size = 0
        return ()
    else:
        return ()
    end
end

func _change_modules_loop{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*):
    if actions_len == 0:
        return ()
    end

    let module_action : ModuleFunctionAction = [actions]

    if module_action.action == MODULE_FUNCTION_ADD:
        _add_registry_module(module_action.selector, module_action.module_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if module_action.action == MODULE_FUNCTION_REPLACE:
        _replace_registry_module(module_action.selector, module_action.module_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if module_action.action == MODULE_FUNCTION_REMOVE:
        _remove_registry_module(module_action.selector, module_action.module_address)
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

func _add_registry_module{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, module_address : felt):
    # checks: selector is not already registered
    let (existing_module_address) = _module_registry_modules.read(selector)
    with_attr error_message("selector already exists"):
        assert existing_module_address = 0
    end

    # effects: add selector to module list
    _module_registry_modules.write(selector, module_address)

    # effects: update list of selectors
    let (selectors_len) = _module_registry_selectors_len.read()
    _module_registry_selectors_len.write(selectors_len + 1)
    _module_registry_selectors.write(selectors_len, selector)

    return ()
end

func _replace_registry_module{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, module_address : felt):
    # checks: selector is registered
    let (existing_module_address) = _module_registry_modules.read(selector)
    with_attr error_message("selector does not exists"):
        assert_not_zero(existing_module_address)
    end

    # effects: add selector to module list
    _module_registry_modules.write(selector, module_address)

    return ()
end

func _remove_registry_module{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, module_address : felt):
    alloc_locals

    # checks: selector is registered
    let (existing_module_address) = _module_registry_modules.read(selector)
    with_attr error_message("selector does not exists"):
        assert_not_zero(existing_module_address)
    end

    # effects: remove selector from module list
    _module_registry_modules.write(selector, 0)

    # effects: update list of selectors
    # fill the hole left by this selector by moving the last selector to it
    let (local selectors_len) = _module_registry_selectors_len.read()

    let (selector_index) = _find_selector_index_loop(selector, selectors_len, 0)
    # checks: selector found
    assert_not_equal(selector_index, selectors_len)

    # notice: selectors length is > 1
    let (last_selector) = _module_registry_selectors.read(selectors_len - 1)

    _module_registry_selectors.write(selector_index, last_selector)
    _module_registry_selectors_len.write(selectors_len - 1)

    return ()
end

func _find_selector_index_loop{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, selectors_len : felt, current_index : felt) -> (index : felt):
    if current_index == selectors_len:
        return (index=selectors_len)
    end

    let (current_selector) = _module_registry_selectors.read(current_index)

    if current_selector == selector:
        return (index=current_index)
    else:
        return _find_selector_index_loop(selector, selectors_len, current_index + 1)
    end
end

