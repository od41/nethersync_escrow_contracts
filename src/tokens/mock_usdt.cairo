#[starknet::contract]
pub mod MockUsdt {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_token::erc20::interface;
    use starknet::ContractAddress;
    use starknet::storage::StoragePointerReadAccess;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        fixed_supply: u256,
        recipient: ContractAddress
    ) {
        let name = "MockUSDT";
        let symbol = "mUSDT";

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, fixed_supply);
    }

    impl ERC20MetadataImpl of interface::IERC20Metadata<ContractState> {
        fn decimals(self: @ContractState) -> u8 {
            6
        }

        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }
        
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_symbol.read()
        }
    }
}