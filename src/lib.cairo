// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0-alpha.0

#[starknet::interface]
pub trait INSEscrowSwapContract<TContractState> {
    // write functions
    fn withdraw(ref self: TContractState, zk_proof: Span<u8>);
    fn deposit(ref self: TContractState, amount: u256);
    fn reverse_deposit(ref self: TContractState);

    // view functions
    fn swap_status(self: @TContractState, id: u8) -> felt252;
}

#[starknet::contract]
pub mod NSEscrowSwapContract {
    // use array::Span;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::IERC20Mixin;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    use super::INSEscrowSwapContract;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        is_completed: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        owner: ContractAddress,
    ) {
        self.buyer.write(buyer);
        self.seller.write(seller);
        self.token.write(token);
        self.amount.write(amount);
        self.is_completed.write(false);

        self.ownable.initializer(owner);
        // // Transfer tokens from buyer to this contract
    // self.erc20.transfer_from(self.address(), buyer, amount);
    }

    #[abi(embed_v0)]
    pub impl INSEscrowSwapContractImpl of INSEscrowSwapContract<ContractState> {
        // TODO: function to deposit tokens to the contract from buyer

        fn withdraw(ref self: ContractState, zk_proof: Span<u8>) {
            assert!(!self.is_completed.read(), "Transaction already completed");

            // Here you would verify the zk-proof offchain.
            // If valid, proceed to complete the transaction
            verify_zk_proof(zk_proof);

            // Transfer tokens to seller
            self.erc20.transfer(self.seller.read(), self.amount.read());
            self.is_completed.write(true);
        }

        fn deposit(ref self: ContractState, amount: u256) {}

        fn reverse_deposit(ref self: ContractState) {
            assert!(self.is_completed.read(), "Transaction not completed");
            // Refund buyer
            self.erc20.transfer(self.buyer.read(), self.amount.read());
            self.is_completed.write(false);
        }

        fn swap_status(self: @ContractState, id: u8) -> felt252{
            'done'
        }

    }

    fn verify_zk_proof(zk_proof: Span<u8>) { // Implement zk-proof verification logic here
    // This is a placeholder for demonstration
    }
}