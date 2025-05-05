// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0-alpha.0

pub mod events;
pub mod mock_usdt;

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
    use openzeppelin_token::erc20::interface::{IERC20CamelDispatcherTrait, IERC20CamelDispatcher};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use core::panic_with_felt252;

    use super::INSEscrowSwapContract;
    use super::SwapStatus;
    use super::events;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    const NS_FEE: u256 = 150; // 1.5%


    #[storage]
    struct Storage {
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        status: SwapStatus,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        payment_erc_20: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        SwapCreated: events::SwapCreated,
        CredentialsVerified: events::CredentialsVerified,
        PaymentDeposited: events::PaymentDeposited,
        CredentialsShared: events::CredentialsShared,
        CredentialsChanged: events::CredentialsChanged,
        SwapCompleted: events::SwapCompleted,
        SwapCancelled: events::SwapCancelled,
        CredentialsVerificationFailed: events::CredentialsVerificationFailed,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        owner: ContractAddress,
        payment_erc_20: ContractAddress,
    ) {
        self.buyer.write(buyer);
        self.seller.write(seller);
        self.token.write(token);
        self.amount.write(amount);
        self.payment_erc_20.write(payment_erc_20);

        self.ownable.initializer(owner);
        
        self.status.write(SwapStatus::Pending);

        // Emit SwapCreated event
        self.emit(Event::SwapCreated(events::SwapCreated { buyer, seller, token, amount }));
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
            if is_proof_valid { 
                self.status.write(SwapStatus::CredentialsVerified);
                self.emit(Event::CredentialsVerified(events::CredentialsVerified { status: 'CredentialsVerified' }));
            } else {
                self.status.write(SwapStatus::CredentialsVerificationFailed);
                self.emit(Event::CredentialsVerificationFailed(events::CredentialsVerificationFailed { status: 'CredentialsVerificationFailed' }));
            }

        }

        fn deposit(ref self: ContractState, amount: u256) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::CredentialsVerified, 'invalid swap status' );

            // assert that deposit amount is valid
            assert(amount > 0, 'amount must NOT be 0');
            self.amount.write(amount);            

            let amount_plus_fees = amount + get_fees(amount);

            let payment_erc_20 = IERC20CamelDispatcher {
                contract_address: self.payment_erc_20.read()
            };
            let caller = get_caller_address();
            let contract = get_contract_address();

            if !payment_erc_20.approve(contract, amount_plus_fees) {
                panic_with_felt252('approve failed');
            }
            if !payment_erc_20.transferFrom(caller, contract, amount_plus_fees) {
                panic_with_felt252('insufficient payment allowance');
            }

            // set status to payment confirmed
            self.status.write(SwapStatus::PaymentConfirmed);

            // Emit PaymentDeposited event
            self.emit(Event::PaymentDeposited(events::PaymentDeposited { amount }));
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

            // Emit CredentialsShared event
            self.emit(Event::CredentialsShared(events::CredentialsShared { status: 'CredentialsShared' }));
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

            // Emit CredentialsChanged event
            self.emit(Event::CredentialsChanged(events::CredentialsChanged { status: 'CredentialsChanged' }));
        }

        fn withdraw(ref self: ContractState) {
            // assert that previous step is complete
            let current_status = self.swap_status();
            assert(current_status == SwapStatus::CredentialsChanged, 'invalid swap status' );

            // TODO: Transfer tokens to seller
            // self.erc20.transfer(self.seller.read(), self.amount.read());
            // TEMPORARY
            let amount = self.amount.read();
            self.amount.write(0);
            
            // set status to completed
            self.status.write(SwapStatus::Completed); 

            // Emit SwapCompleted event
            self.emit(Event::SwapCompleted(events::SwapCompleted { final_amount: amount }));
        }

        fn reverse_deposit(ref self: ContractState) {
            let current_status = self.swap_status();
            assert((current_status != SwapStatus::CredentialsShared) 
                || (current_status != SwapStatus::Completed), 'invalid swap status' );

            // Refund buyer
            // self.erc20.transfer(self.buyer.read(), self.amount.read());
            // TEMPORARY
            let amount = self.amount.read();
            self.amount.write(0);
            
            // set status to cancelled
            self.status.write(SwapStatus::Cancelled);

            // Emit SwapCancelled event
            self.emit(Event::SwapCancelled(events::SwapCancelled { refund_amount: amount }));
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
        if zk_proof.len() == 0 {
            return false;
        }
        true
    }

    fn get_fees(amount: u256) -> u256 {
        let fee_amount = (amount * NS_FEE) / 10000;
        fee_amount
    }
}