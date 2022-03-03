%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import delegate_call

from diamond.interfaces.diamond_cut import FacetCut, FACET_CUT_ADD
from diamond.facets.diamond_cut_facet import (
    diamond_cut_facet_set_owner, diamond_cut_facet_diamond_cut, diamond_cut_facet_get_facet_address, DIAMOND_CUT_SELECTOR)

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, diamon_cut_facet : felt):
    alloc_locals

    # effects: set owner of this diamond
    diamond_cut_facet_set_owner(owner)

    local facet : FacetCut
    facet.action = FACET_CUT_ADD
    facet.selector = DIAMOND_CUT_SELECTOR
    facet.facet_address = diamon_cut_facet

    let (diamond_cut : FacetCut*) = alloc()
    assert [diamond_cut] = facet

    let (calldata : felt*) = alloc()

    # effects: initialize diamond cut facet
    diamond_cut_facet_diamond_cut(1, diamond_cut, 0, 0, calldata)

    return ()
end


@external
@raw_input
@raw_output
func __default__{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        selector : felt, calldata_size : felt,
        calldata : felt*) -> (
        retdata_size : felt, retdata : felt*):
    let (address) = diamond_cut_facet_get_facet_address(selector)

    let (retdata_size : felt, retdata : felt*) = delegate_call(
        contract_address=address,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata)
    return (retdata_size=retdata_size, retdata=retdata)
end
