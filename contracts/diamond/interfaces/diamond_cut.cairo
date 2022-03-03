%lang starknet

const FACET_CUT_ADD = 0
const FACET_CUT_REPLACE = 1
const FACET_CUT_REMOVE = 2

struct FacetCut:
    member facet_address : felt
    member action : felt
    member selector : felt
end

@event
func DiamondCut(
        diamond_cut_len : felt, diamond_cut : FacetCut*, address : felt, calldata_len : felt,
        calldata : felt*):
end
