use core::result::ResultTrait;
use nethersync_escrow_contracts::{NSEscrowSwapContract, INSEscrowSwapContractDispatcher, INSEscrowSwapContractDispatcherTrait, SwapStatus};
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
fn test_full_swap_flow_success() {
    let contract_address = deploy_contract();
    let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

    // 1. Initial state check
    assert(contract_dispatcher.swap_status() == SwapStatus::Pending, 'status not Pending');

    // 2. Verify credentials
    let zk_proof = array![1, 2, 3, 4]; // Mock valid proof
    contract_dispatcher.verify_credentials(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsVerified, 'status not CredentialsVerified');

    // 3. Deposit
    let amount = 1000_u256;
    contract_dispatcher.deposit(amount);
    assert(contract_dispatcher.swap_status() == SwapStatus::PaymentConfirmed, 'status not PaymentConfirmed');

    // 4. Verify credentials shared
    contract_dispatcher.verify_credentials_shared(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsShared, 'status not CredentialsShared');

    // 5. Verify credentials changed
    contract_dispatcher.verify_credentials_changed(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsChanged, 'status not CredentialsChanged');

    // 6. Withdraw
    contract_dispatcher.withdraw();
    assert(contract_dispatcher.swap_status() == SwapStatus::Completed, 'status not Completed');
    
    // 7. Verify amount is zero after withdrawal
    let contract_balance = load(contract_address, selector!("amount"), 1);
    assert_eq!(contract_balance, array![0], "amount not zero after withdrawal");
}


