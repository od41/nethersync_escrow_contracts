// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0-alpha.0

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum SwapStatus{
    #[default]
    Pending,
    CredentialsVerified,
    CredentialsVerificationFailed,
    PaymentConfirmed,
    CredentialsShared,
    CredentialsChanged,
    Completed,
    Cancelled,
}


#[starknet::interface]
pub trait INSEscrowSwapContract<TContractState> {
    // write functions
    fn deposit(ref self: TContractState, amount: u256);
    fn verify_credentials(ref self: TContractState, zk_proof: Span<u8>);
    fn verify_credentials_shared(ref self: TContractState, zk_proof: Span<u8>);
    fn verify_credentials_changed(ref self: TContractState, zk_proof: Span<u8>);
    fn withdraw(ref self: TContractState);
    fn reverse_deposit(ref self: TContractState);

    // view functions
    fn swap_status(self: @TContractState) -> SwapStatus;
}

#[starknet::contract]
pub mod NSEscrowSwapContract {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    use super::INSEscrowSwapContract;
    use super::SwapStatus;

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
        status: SwapStatus,
        is_completed: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        // TODO: seller should set the price and payment asset

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
        // TODO: Transfer tokens from buyer to this contract
        // self.erc20.transfer_from(self.address(), buyer, amount);

        // TODO: set swap status
        self.status.write(SwapStatus::Pending);
    }

    #[abi(embed_v0)]
    pub impl INSEscrowSwapContractImpl of INSEscrowSwapContract<ContractState> {
        fn verify_credentials(ref self: ContractState, zk_proof: Span<u8>) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(
                (current_status == SwapStatus::CredentialsVerificationFailed) 
                | (current_status == SwapStatus::Pending ), 'invalid swap status' );
            // assert that zk_proof is valid
            let is_proof_valid = verify_zk_proof(zk_proof);
            assert(is_proof_valid, 'ZK proof is invalid');

            // set status to credentials verified
            self.status.write(SwapStatus::CredentialsVerified);
        }

        fn deposit(ref self: ContractState, amount: u256) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::CredentialsVerified, 'invalid swap status' );

            // TODO: seller should set the price and payment asset
            // assert that deposit amount is valid
            assert(amount > 0, 'amount must be greater than 0');
            self.amount.write(amount);

            // set status to payment confirmed
            self.status.write(SwapStatus::PaymentConfirmed);
        }

        fn verify_credentials_shared(ref self: ContractState, zk_proof: Span<u8>) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::PaymentConfirmed, 'invalid swap status' );

            // assert that zk_proof is valid
            let is_proof_valid = verify_zk_proof(zk_proof);
            assert(is_proof_valid, 'ZK proof is invalid');

            // set status to credentials shared
            self.status.write(SwapStatus::CredentialsShared);
        }

        fn verify_credentials_changed(ref self: ContractState, zk_proof: Span<u8>) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::CredentialsShared, 'invalid swap status' );

            // assert that zk_proof is valid
            let is_proof_valid = verify_zk_proof(zk_proof);
            assert(is_proof_valid, 'ZK proof is invalid');

            // set status to credentials changed
            self.status.write(SwapStatus::CredentialsChanged);            
        }

        fn withdraw(ref self: ContractState) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::CredentialsChanged, 'invalid swap status' );

            // TODO: Transfer tokens to seller
            // self.erc20.transfer(self.seller.read(), self.amount.read());
            // TEMPORARY
            self.amount.write(0);
            
            // set status to completed
            self.status.write(SwapStatus::Completed); 
        }

        fn reverse_deposit(ref self: ContractState) {
            let current_status = self.swap_status();
            assert((current_status != SwapStatus::CredentialsShared) 
                || (current_status != SwapStatus::Completed), 'invalid swap status' );

            // Refund buyer
            // self.erc20.transfer(self.buyer.read(), self.amount.read());
            // TEMPORARY
            self.amount.write(0);
            
            // set status to cancelled
            self.status.write(SwapStatus::Cancelled);
        }

        fn swap_status(self: @ContractState) -> SwapStatus {
            let current_status = self.status.read();
            match current_status {
                SwapStatus::Pending => SwapStatus::Pending,
                SwapStatus::CredentialsVerified => SwapStatus::CredentialsVerified,
                SwapStatus::CredentialsVerificationFailed => SwapStatus::CredentialsVerificationFailed,
                SwapStatus::PaymentConfirmed => SwapStatus::PaymentConfirmed,
                SwapStatus::CredentialsShared => SwapStatus::CredentialsShared,
                SwapStatus::CredentialsChanged => SwapStatus::CredentialsChanged,
                SwapStatus::Completed => SwapStatus::Completed,
                SwapStatus::Cancelled => SwapStatus::Cancelled,
            }
        }

    }

    fn verify_zk_proof(zk_proof: Span<u8>) -> bool { 
        // TODO: Implement zk-proof verification logic here
        true
    }
}