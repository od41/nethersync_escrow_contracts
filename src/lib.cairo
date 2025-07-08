// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0-alpha.0

pub mod events;
pub mod tokens {
    pub mod nft;
    pub mod mock_usdt;
}
pub mod interfaces {
    pub mod IPrimusZKTLS;
}

use interfaces::IPrimusZKTLS::Attestation;

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
struct NSAction {
    name: felt252,
    descriptions: felt252
}

#[starknet::interface]
pub trait INSVerifier<TContractState> {
    fn verify_attestation(self: @TContractState, attestation: Attestation) -> bool;

    fn register_action(self: @TContractState, token_id: u256, action: NSAction);
    fn get_actions(self: @TContractState, token_id: u256) -> Array<NSAction>;
}

#[starknet::contract]
pub mod NSVerifier {
    use super::{
        NSAction,
        interfaces::IERC721::{IERC721Dispatcher, IERC721DispatcherTrait},
        interfaces::IPrimusZKTLS::{
            Attestation, IPrimusZKTLSDispatcher, IPrimusZKTLSDispatcherTrait
        }
    };
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::{poseidon::PoseidonTrait};

    #[storage]
    struct Storage {
        primus_address: ContractAddress,
        nft_address: ContractAddress,
        token_counter_id: u256,
        token_actions: Map<u256, Array<NSAction>>,
    }


    #[constructor]
    fn constructor(ref self: ContractState, _primusAddress: ContractAddress, nft_address: ContractAddress) {
        self.primus_address.write(_primusAddress);
        self.nft_address.write(nft_address);
        self.token_counter_id.write(1);
    }

    #[abi(embed_v0)]
    impl INSVerifier of super::INSVerifier<ContractState> {
        fn verify_attestation(self: @ContractState, attestation: Attestation) -> bool {
            IPrimusZKTLSDispatcher { contract_address: self.primus_address.read() }
                .verifyAttestation(attestation);

            // Mint a new NFT to the caller
            let caller = get_caller_address();
            let token_id =  self.token_counter_id.read();
            let nft_contract = IERC721Dispatcher {
                contract_address: self.nft_address.read()
            };
            nft_contract.mint(caller, token_id);

            // Increment token id counter
            self.token_counter_id.write(token_id + 1);

            return true;
        }

        fn register_action(self: @ContractState, token_id: u256, action: NSAction) {
            // Check if caller is the owner of the token
            let caller = get_caller_address();
            let nft_contract = IERC721Dispatcher {
                contract_address: self.nft_address.read()
            };
            assert(nft_contract.owner_of(token_id) == caller, 'Not token owner');
            
            let mut actions = self.token_actions.read(token_id);
            actions.append(action);
            self.token_actions.write(token_id, actions);
        }

        fn get_actions(self: @ContractState, token_id: u256) -> Array<NSAction> {
            return self.token_actions.read(token_id);
        }
    }
}