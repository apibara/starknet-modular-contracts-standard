%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero

from smc.libraries.module_registry import (
    module_registry_get_module_address, _module_registry_selectors_len, _module_registry_selectors)

# ---------------------------------------------------------------------------- #
#                                                                              #
#                  IModuleIntrospection interface                              #
#                                                                              #
# ---------------------------------------------------------------------------- #

@view
func moduleFunctionSelectors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        module_address : felt) -> (selectors_len : felt, selectors : felt*):
    alloc_locals

    let (selectors_len) = _module_registry_selectors_len.read()
    let (local module_selectors : felt*) = alloc()

    let (module_selectors_len) = _collect_module_selectors_loop(
        module_address, selectors_len, 0, 0, module_selectors)

    return (selectors_len=module_selectors_len, selectors=module_selectors)
end

@view
func moduleAddresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        module_addresses_len : felt, module_addresses : felt*):
    alloc_locals

    let (selectors_len) = _module_registry_selectors_len.read()
    let (local module_addresses : felt*) = alloc()
    let (module_addresses_len) = _collect_module_addresses_loop(
        selectors_len, 0, 0, module_addresses)

    return (module_addresses_len=module_addresses_len, module_addresses=module_addresses)
end

@view
func moduleAddress{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt) -> (module_address : felt):
    let (module_address) = module_registry_get_module_address(selector)
    return (module_address=module_address)
end

# ---------------------------------------------------------------------------- #
#                                                                              #
#                            Private Functions                                 #
#                                                                              #
# ---------------------------------------------------------------------------- #

func _collect_module_selectors_loop{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        module_address : felt, selectors_len : felt, current_index : felt,
        module_selectors_len : felt, module_selectors : felt*) -> (module_selectors_len : felt):
    if current_index == selectors_len:
        return (module_selectors_len=module_selectors_len)
    end

    # checks: selector exists and has a module
    let (selector) = _module_registry_selectors.read(current_index)
    assert_not_zero(selector)
    let (selector_module_address) = module_registry_get_module_address(selector)
    assert_not_zero(selector_module_address)

    if selector_module_address == module_address:
        assert [module_selectors] = selector
        return _collect_module_selectors_loop(
            module_address,
            selectors_len,
            current_index + 1,
            module_selectors_len + 1,
            module_selectors + 1)
    else:
        return _collect_module_selectors_loop(
            module_address,
            selectors_len,
            current_index + 1,
            module_selectors_len,
            module_selectors)
    end
end

func _collect_module_addresses_loop{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selectors_len : felt, current_index : felt, module_addresses_len : felt,
        module_addresses : felt*) -> (module_addresses_len : felt):
    alloc_locals

    if current_index == selectors_len:
        return (module_addresses_len=module_addresses_len)
    end

    # checks: selector exists and has a module
    let (selector) = _module_registry_selectors.read(current_index)
    assert_not_zero(selector)
    let (local selector_module_address) = module_registry_get_module_address(selector)
    assert_not_zero(selector_module_address)

    # offset module_addresses by -1 because the last element does not contain
    # any address
    let (address_included) = _module_addresses_contains_loop(
        selector_module_address, module_addresses_len, module_addresses - 1)

    if address_included == 0:
        assert [module_addresses] = selector_module_address
        return _collect_module_addresses_loop(
            selectors_len, current_index + 1, module_addresses_len + 1, module_addresses + 1)
    else:
        return _collect_module_addresses_loop(
            selectors_len, current_index + 1, module_addresses_len, module_addresses)
    end
end

func _module_addresses_contains_loop{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        target_module_address : felt, module_addresses_len : felt, module_addresses : felt*) -> (
        contains : felt):
    # if it looped this far then it doesn't contain the target module address
    if module_addresses_len == 0:
        return (contains=0)
    end

    let current_address = [module_addresses]

    if current_address == target_module_address:
        return (contains=1)
    else:
        return _module_addresses_contains_loop(
            target_module_address, module_addresses_len - 1, module_addresses - 1)
    end
end
