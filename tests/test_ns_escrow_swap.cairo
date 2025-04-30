use core::result::ResultTrait;
use nethersync_escrow_contracts::{NSEscrowSwapContract, INSEscrowSwapContractDispatcher, INSEscrowSwapContractDispatcherTrait};
use snforge_std::{declare, load, ContractClassTrait, DeclareResultTrait};

use starknet::syscalls::deploy_syscall;
use starknet::{ContractAddress, contract_address_const};

fn uint256_encode(val: u256) -> Array::<felt252> {
    let low_part: u128 = val.low;
    let high_part: u128 = val.high;
    let low_felt: felt252 = low_part.try_into().unwrap();
    let high_felt: felt252 = high_part.try_into().unwrap();

    let arr = array![low_felt, high_felt];
    arr
}



fn deploy_contract() -> ContractAddress {
    let buyer = contract_address_const::<0x123>();
    let seller = contract_address_const::<0x456>();
    let token = contract_address_const::<0x789>();
    let amount = 1000_u256;
    let amount_u128 = uint256_encode(amount); 
    let owner = contract_address_const::<0x111>();
    
    let calldata = array![
        buyer.try_into().unwrap(), 
        seller.try_into().unwrap(), 
        token.try_into().unwrap(), 
        *amount_u128[0],
        *amount_u128[1],
        owner.try_into().unwrap()
    ];
    let contract = declare("NSEscrowSwapContract").unwrap().contract_class();
    let (address0, _) = contract.deploy(@calldata).unwrap();
    address0
}

#[test]
fn test_deployment() {
    let contract_address = deploy_contract();
    let _contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };
    assert(
        contract_address != contract_address_const::<0x0>(),
        'contract not deployed',
    );
}

#[test]
fn test_deposit() {
    let contract_address = deploy_contract();
    let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };
    let amount = 10_u256;
    contract_dispatcher.deposit(amount);
    let contract_balance = load(contract_address, selector!("amount"), 1);

    assert_eq!(contract_balance, array![10], "incorrect price amount");
}


#[test]
fn test_withdraw() {
    let contract_address = deploy_contract();
    let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

    let amount = 10_u256;
    contract_dispatcher.deposit(amount);

    // Create a mock zk proof
    let mut zk_proof = array![1, 2, 3, 4];

    // Start pranking as seller
    snforge_std::start_prank(contract_address, seller);

    let dispatcher = INSEscrowSwapContractDispatcher { contract_address };
    dispatcher.withdraw(zk_proof.span());

    // Verify is_completed is true
    assert(dispatcher.is_completed(), 'withdrawal not completed');

    snforge_std::stop_prank(contract_address);
}

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


