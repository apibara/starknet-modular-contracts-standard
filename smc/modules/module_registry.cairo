%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.access.ownable import Ownable_only_owner

from smc.interfaces.module_registry import ModuleFunctionAction
from smc.libraries.module_registry import module_registry_change_modules

# ---------------------------------------------------------------------------- #
#                                                                              #
#                    IModuleRegistry interface                                 #
#                                                                              #
# ---------------------------------------------------------------------------- #

@external
func changeModules{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
    Ownable_only_owner()
    return module_registry_change_modules(actions_len, actions, address, calldata_len, calldata)
end
