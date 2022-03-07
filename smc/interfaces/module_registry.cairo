%lang starknet

const MODULE_FUNCTION_ADD = 0
const MODULE_FUNCTION_REPLACE = 1
const MODULE_FUNCTION_REMOVE = 2

struct ModuleFunctionAction:
    member module_address : felt
    member action : felt
    member selector : felt
end

@contract_interface
namespace IModuleRegistry:
    func changeModules(
            actions_len : felt, actions : ModuleFunctionAction*, address : felt,
            calldata_len : felt, calldata : felt*):
    end
end

@event
func ModuleFunctionChange(
        actions_len : felt, actions : ModuleFunctionAction*, address : felt, calldata_len : felt,
        calldata : felt*):
end
