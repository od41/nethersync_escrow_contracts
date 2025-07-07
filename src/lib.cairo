// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0-alpha.0

pub mod events;
pub mod mock_usdt;
pub mod interfaces {
    pub mod IPrimusZKTLS;
}


use interfaces::IPrimusZKTLS::Attestation;

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum NSAction {
    #[default]
    LeaseAction,
    EscrowAction,
    BuySellAction
}

#[starknet::interface]
pub trait INSVerifier<TContractState> {
    fn verify_attestation(self: @TContractState, attestation: Attestation) -> bool;

    fn register_action(self: @TContractState, action: NSAction);
    fn get_actions(self: @TContractState) -> Array<NSAction>;
}

#[starknet::contract]
pub mod NSVerifier {
    use super::interfaces::IPrimusZKTLS::{
        Attestation, IPrimusZKTLSDispatcher, IPrimusZKTLSDispatcherTrait,
    };
    use super::NSAction;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _primusAddress: ContractAddress) {
        // Replace with the network you are deploying on
        self.address.write(_primusAddress);
    }

    #[abi(embed_v0)]
    impl INSVerifier of super::INSVerifier<ContractState> {
        fn verify_attestation(self: @ContractState, attestation: Attestation) -> bool {
            IPrimusZKTLSDispatcher { contract_address: self.address.read() }
                .verifyAttestation(attestation);

            // Business logic checks, such as attestation content and timestamp checks
            // do your own business logic
            return true;
        }

        fn register_action(self: @ContractState, action: NSAction) {
            // TODO: Implement
        }

        fn get_actions(self: @ContractState) -> Array<NSAction> {
            // TODO: Implement
            return array![];
        }
    }
}