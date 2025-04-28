


// use array::ArrayTrait;
// use core::array::SpanTrait;
use core::result::ResultTrait;
use core::traits::Into;
use nethersync_escrow_contracts::{NSEscrowSwapContract};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use starknet::syscalls::deploy_syscall;
use starknet::{ContractAddress, contract_address_const};


fn deploy_contract() -> ContractAddress {
    let buyer = contract_address_const::<0x123>();
    let seller = contract_address_const::<0x456>();
    let token = contract_address_const::<0x789>();
    let amount: u256 = 1000;
    let owner = contract_address_const::<0x111>();

    let mut calldata = ArrayTrait::new();
    calldata.append(buyer);
    calldata.append(seller);
    calldata.append(token);
    calldata.append(amount);
    calldata.append(owner);
    let (address0, _) = deploy_syscall(
        NSEscrowSwapContract::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false,
    )
        .unwrap();
    address0
}

#[test]
fn test_deployment() {
    let contract_address = deploy_contract();
    let contract_dispatcher = NSEscrowSwapContractDispatcher { contract_address: contract_address };
    assert(
        contract_dispatcher.ownable.get_owner() == contract_address_const::<0x111>(),
        'contract not deployed',
    );
}


// #[test]
// fn test_withdraw() {
//     let buyer = starknet::contract_address_const::<0x123>();
//     let seller = starknet::contract_address_const::<0x456>();
//     let token = starknet::contract_address_const::<0x789>();
//     let amount: u256 = 1000;
//     let owner = starknet::contract_address_const::<0x111>();

//     let contract_address = deploy_contract(buyer, seller, token, amount, owner);

//     // Create a mock zk proof
//     let mut zk_proof = array![1, 2, 3, 4];

//     // Start pranking as seller
//     snforge_std::start_prank(contract_address, seller);

//     let dispatcher = INSEscrowSwapContractDispatcher { contract_address };
//     dispatcher.withdraw(zk_proof.span());

//     // Verify is_completed is true
//     assert(dispatcher.is_completed(), 'withdrawal not completed');

//     snforge_std::stop_prank(contract_address);
// }

// #[test]
// fn test_withdraw_already_completed() {
//     let buyer = starknet::contract_address_const::<0x123>();
//     let seller = starknet::contract_address_const::<0x456>();
//     let token = starknet::contract_address_const::<0x789>();
//     let amount: u256 = 1000;
//     let owner = starknet::contract_address_const::<0x111>();

//     let contract_address = deploy_contract(buyer, seller, token, amount, owner);

//     // Create a mock zk proof
//     let mut zk_proof = array![1, 2, 3, 4];

//     snforge_std::start_prank(contract_address, seller);

//     let dispatcher = INSEscrowSwapContractDispatcher { contract_address };
//     // First withdrawal
//     dispatcher.withdraw(zk_proof.span());

//     // Second withdrawal should fail
//     match dispatcher.withdraw(zk_proof.span()) {
//         Result::Ok(_) => panic_with_felt252('Should have failed'),
//         Result::Err(data) => {
//             assert(*data.at(0) == 'Transaction already completed', *data.at(0));
//         },
//     }

//     snforge_std::stop_prank(contract_address);
// }

// #[test]
// fn test_reverse_deposit() {
//     let buyer = starknet::contract_address_const::<0x123>();
//     let seller = starknet::contract_address_const::<0x456>();
//     let token = starknet::contract_address_const::<0x789>();
//     let amount: u256 = 1000;
//     let owner = starknet::contract_address_const::<0x111>();

//     let contract_address = deploy_contract(buyer, seller, token, amount, owner);

//     let mut zk_proof = array![1, 2, 3, 4];

//     // First complete the withdrawal
//     snforge_std::start_prank(contract_address, seller);
//     let dispatcher = INSEscrowSwapContractDispatcher { contract_address };
//     dispatcher.withdraw(zk_proof.span());
//     snforge_std::stop_prank(contract_address);

//     // Then reverse the deposit
//     snforge_std::start_prank(contract_address, buyer);
//     dispatcher.reverse_deposit();
//     assert(!dispatcher.is_completed(), 'reverse deposit failed');
//     snforge_std::stop_prank(contract_address);
// }

// #[test]
// fn test_reverse_deposit_not_completed() {
//     let buyer = starknet::contract_address_const::<0x123>();
//     let seller = starknet::contract_address_const::<0x456>();
//     let token = starknet::contract_address_const::<0x789>();
//     let amount: u256 = 1000;
//     let owner = starknet::contract_address_const::<0x111>();

//     let contract_address = deploy_contract(buyer, seller, token, amount, owner);

//     snforge_std::start_prank(contract_address, buyer);
//     let dispatcher = INSEscrowSwapContractDispatcher { contract_address };

//     // Should fail as withdrawal hasn't happened
//     match dispatcher.reverse_deposit() {
//         Result::Ok(_) => panic_with_felt252('Should have failed'),
//         Result::Err(data) => {
//             assert(*data.at(0) == 'Transaction not completed', *data.at(0));
//         },
//     }

//     snforge_std::stop_prank(contract_address);
// }


