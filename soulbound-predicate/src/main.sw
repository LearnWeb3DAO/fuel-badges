predicate;

configurable {
    ADDRESS: Address = Address::from(0x0000000000000000000000000000000000000000000000000000000000000000),
}

fn main() -> bool {
    asm (address: ADDRESS) { address: b256 };
    false
}