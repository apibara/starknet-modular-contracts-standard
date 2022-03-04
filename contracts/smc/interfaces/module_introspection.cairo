%lang starknet

@contract_interface
namespace IModuleIntrospection:
    func moduleFunctionSelectors(module_address : felt) -> (
            selectors_len : felt, selectors : felt*):
    end

    func moduleAddresses() -> (module_addresses_len : felt, module_addresses : felt*):
    end

    func moduleAddess(selector : felt) -> (module_address : felt):
    end
end
