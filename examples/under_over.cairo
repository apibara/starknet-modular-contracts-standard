%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le

@storage_var
func _reference() -> (reference : felt):
end

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        reference : felt) -> ():
    _reference.write(reference)
    return ()
end

@external
func setReference{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        reference : felt) -> ():
    _reference.write(reference)
    return ()
end

@view
func getReference{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        reference : felt):
    let (reference) = _reference.read()
    return (reference=reference)
end

@view
func underOver{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(n : felt) -> (
        is_over : felt):
    alloc_locals
    let (reference) = _reference.read()

    local syscall_ptr : felt* = syscall_ptr

    let (is_over) = is_le(reference, n)

    return (is_over=is_over)
end
