%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero

from diamond.interfaces.diamond_cut import (
    FacetCut, DiamondCut, FACET_CUT_ADD, FACET_CUT_REMOVE, FACET_CUT_REPLACE)

# Map function selectors to the facets that execute the function.
@storage_var
func _facets(selector : felt) -> (facet_address : felt):
end

# Diamond owner
@storage_var
func _owner() -> (owner : felt):
end

# get_selector_from_name('diamondCut')
const DIAMOND_CUT_SELECTOR = 430792745303880346585957116707317276189779144684897836036710359506025130056

@external
func diamondCut{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        diamond_cut_len : felt, diamond_cut : FacetCut*, address : felt, calldata_len : felt,
        calldata : felt*):
    alloc_locals

    diamond_cut_facet_diamond_cut(diamond_cut_len, diamond_cut, address, calldata_len, calldata)

    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    DiamondCut.emit(diamond_cut_len, diamond_cut, address, calldata_len, calldata)

    return ()
end

func diamond_cut_facet_set_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt):
    # checks: if the owner is zero everyone is an owner.
    assert_not_zero(owner)

    # effects: update owner
    _owner.write(owner)

    return ()
end

func diamond_cut_facet_get_facet_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(selector : felt) -> (address : felt):
    let (address) = _facets.read(selector)
    return (address=address)
end

func diamond_cut_facet_diamond_cut{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        diamond_cut_len : felt, diamond_cut : FacetCut*, address : felt, calldata_len : felt,
        calldata : felt*):
    _add_replace_remove_facet_selectors(diamond_cut_len, diamond_cut)

    # call address _init with calldata
    return ()
end

func _add_replace_remove_facet_selectors{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        diamond_cut_len : felt, diamond_cut : FacetCut*):
    if diamond_cut_len == 0:
        return ()
    end

    let facet : FacetCut = [diamond_cut]

    if facet.action == FACET_CUT_ADD:
        # TODO: check selector does not exist already
        _facets.write(facet.selector, facet.facet_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if facet.action == FACET_CUT_REPLACE:
        # TODO: no need to check if already exists?
        _facets.write(facet.selector, facet.facet_address)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if facet.action == FACET_CUT_REMOVE:
        # Zero data for the given selector
        _facets.write(facet.selector, 0)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return _add_replace_remove_facet_selectors(diamond_cut_len - 1, diamond_cut + FacetCut.SIZE)
end
