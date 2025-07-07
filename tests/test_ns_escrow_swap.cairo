use core::result::ResultTrait;

use nethersync_escrow_contracts::{events, NSEscrowSwapContract, INSEscrowSwapContractDispatcher, INSEscrowSwapContractDispatcherTrait, SwapStatus};
use nethersync_escrow_contracts::mock_usdt::{MockUsdt};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, spy_events, EventSpyAssertionsTrait, start_cheat_caller_address,
    stop_cheat_caller_address};
use starknet::{ContractAddress};

const DECIMALS: u8 = 6;

fn uint256_encode(val: u256) -> Array::<felt252> {
    let low_part: u128 = val.low;
    let high_part: u128 = val.high;
    let low_felt: felt252 = low_part.try_into().unwrap();
    let high_felt: felt252 = high_part.try_into().unwrap();

    let arr = array![low_felt, high_felt];
    arr
}

fn deploy_erc20() -> ContractAddress {
    let supply = uint256_encode(1230000 * 10 ** @DECIMALS.into());
    let calldata = array![*supply[0], *supply[1], buyer.try_into().unwrap()];
    let contract = declare("MockUsdt").unwrap().contract_class();
    let (address0, _) = contract.deploy(@calldata).unwrap();
    address0
}

fn deploy_contract() -> (ContractAddress, ContractAddress) {
    let amount = 100 * 10 ** @DECIMALS.into();
    let amount_u128 = uint256_encode(amount); 
    let owner = contract_address_const::<0x111>();

    let payment_erc20 = deploy_erc20();
    
    let calldata = array![
        buyer.try_into().unwrap(), 
        seller.try_into().unwrap(), 
        token.try_into().unwrap(), 
        *amount_u128[0],
        *amount_u128[1],
        owner.try_into().unwrap(),
        payment_erc20.try_into().unwrap()
    ];
    let contract = declare("NSEscrowSwapContract").unwrap().contract_class();
    let (address0, _) = contract.deploy(@calldata).unwrap();
    (address0, payment_erc20)
}

#[test]
fn test_deployment() {
    let (contract_address, _) = deploy_contract();
    let _contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };
    assert(
        contract_address != contract_address_const::<0x0>(),
        'contract not deployed',
    );
}

#[test]
fn test_full_swap_flow_success() {
    let (contract_address, payment_erc20) = deploy_contract();
    let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };
    let payment_erc20_dispatcher = IERC20Dispatcher { contract_address: payment_erc20 };

    let buyer: ContractAddress = 0x123.try_into().unwrap();
    let seller: ContractAddress = 0x456.try_into().unwrap();


    // 1. Initial state check
    assert(contract_dispatcher.swap_status() == SwapStatus::Pending, 'status not Pending');

    // 2. Verify credentials
    let zk_proof = array![1, 2, 3, 4]; // Mock valid proof
    contract_dispatcher.verify_credentials(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsVerified, 'status not CredentialsVerified');

    
    // set buyer as caller
    start_cheat_caller_address(contract_address, buyer);
    start_cheat_caller_address(payment_erc20, buyer);
    
    // 3. Deposit
    let amount = 100 * 10 ** @DECIMALS.into();

    // Set spend allowance for contract
    let amount_plus_fees = amount * 2; // Allow double the amount for fees
    payment_erc20_dispatcher.approve(contract_address, amount_plus_fees);
    println!("allowance: {}", payment_erc20_dispatcher.allowance(buyer, contract_address)); // debug
    println!("balance of buyer: {}", payment_erc20_dispatcher.balance_of(buyer)); // debug
    contract_dispatcher.deposit(amount);
    assert(contract_dispatcher.swap_status() == SwapStatus::PaymentConfirmed, 'status not PaymentConfirmed');

    // 4. Verify credentials shared
    contract_dispatcher.verify_credentials_shared(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsShared, 'status not CredentialsShared');

    // 5. Verify credentials changed
    contract_dispatcher.verify_credentials_changed(zk_proof.span());
    assert(contract_dispatcher.swap_status() == SwapStatus::CredentialsChanged, 'status not CredentialsChanged');

    // reset caller
    stop_cheat_caller_address(contract_address);
    stop_cheat_caller_address(payment_erc20);

    // set seller as caller
    start_cheat_caller_address(contract_address, seller);

    // 6. Withdraw
    contract_dispatcher.withdraw();
    assert(contract_dispatcher.swap_status() == SwapStatus::Completed, 'status not Completed');

    // reset caller
    stop_cheat_caller_address(contract_address);
    
    // 7. Verify amount is zero after withdrawal
    let contract_balance = payment_erc20_dispatcher.balance_of(contract_address);
    assert_eq!(contract_balance, 0, "balance is NOT zero after withdrawal");
}

#[test]
fn test_credentials_verification_failed() {
    let (contract_address, _) = deploy_contract();
    let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

    let mut spy = spy_events();
    
    // Mock invalid proof
    let invalid_proof = array![];
    contract_dispatcher.verify_credentials(invalid_proof.span());

    spy.assert_emitted(@array![
        (contract_address, NSEscrowSwapContract::Event::CredentialsVerificationFailed(
            events::CredentialsVerificationFailed { status: 'CredentialsVerificationFailed' }
        ))
    ]);
}

// #[test]
// fn test_reverse_deposit_from_pending() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();
//     contract_dispatcher.reverse_deposit();

//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 1000_u256 }
//         ))
//     ]);
//     assert(contract_dispatcher.swap_status() == SwapStatus::Cancelled, 'not cancelled');
// }

// #[test]
// fn test_reverse_deposit_from_credentials_verified() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // First verify credentials
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials(zk_proof.span());
    
//     // Then reverse deposit
//     contract_dispatcher.reverse_deposit();

//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'CredentialsVerified' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 1000_u256 }
//         ))
//     ]);
//     assert(contract_dispatcher.swap_status() == SwapStatus::Cancelled, 'not cancelled');
// }

// #[test]
// fn test_reverse_deposit_from_payment_confirmed() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // First verify credentials
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials(zk_proof.span());
    
//     // Then deposit
//     let amount = 1000_u256;
//     contract_dispatcher.deposit(amount);
    
//     // Then reverse deposit
//     contract_dispatcher.reverse_deposit();

//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'CredentialsVerified' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: amount }
//         ))
//     ]);
//     assert(contract_dispatcher.swap_status() == SwapStatus::Cancelled, 'not cancelled');
// }

// #[test]
// fn test_reverse_deposit_invalid_after_shared() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // Progress to CredentialsShared
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials(zk_proof.span());
//     contract_dispatcher.deposit(1000_u256);
//     contract_dispatcher.verify_credentials_shared(zk_proof.span());

//     // Try to reverse deposit
//     contract_dispatcher.reverse_deposit();

//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'CredentialsVerified' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 1000_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'CredentialsShared' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 1000_u256 }
//         ))
//     ]);
// }

// #[test]
// #[should_panic(expected: 'invalid swap status')]
// fn test_deposit_invalid_status() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // Try to deposit before verify_credentials
//     contract_dispatcher.deposit(1000_u256);

//     // Should not emit any contract events
//     spy.assert_not_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCreated(
//             events::SwapCreated { buyer: contract_address_const::<0>(), seller: contract_address_const::<0>(), token: contract_address_const::<0>(), amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 0_u256 }
//         )),
//     ]);
// }

// #[test]
// #[should_panic(expected: 'amount must NOT be 0')]
// fn test_deposit_zero_amount() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // First verify credentials
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials(zk_proof.span());

//     // Try to deposit zero amount
//     contract_dispatcher.deposit(0_u256);

//     // Should only emit the credentials verified event
//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'CredentialsVerified' }
//         ))
//     ]);
//     spy.assert_not_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCreated(
//             events::SwapCreated { buyer: contract_address_const::<0>(), seller: contract_address_const::<0>(), token: contract_address_const::<0>(), amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 0_u256 }
//         )),
//     ]);
// }

// #[test]
// #[should_panic(expected: 'invalid swap status')]
// fn test_verify_credentials_shared_invalid_status() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // Try to verify credentials shared before deposit
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials_shared(zk_proof.span());

//     // Should not emit any contract events
//     spy.assert_not_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCreated(
//             events::SwapCreated { buyer: contract_address_const::<0>(), seller: contract_address_const::<0>(), token: contract_address_const::<0>(), amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 0_u256 }
//         )),
//     ]);
// }

// #[test]
// #[should_panic(expected: 'invalid swap status')]
// fn test_verify_credentials_changed_invalid_status() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // Try to verify credentials changed before shared
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials_changed(zk_proof.span());

//     // Should not emit any contract events
//     spy.assert_not_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCreated(
//             events::SwapCreated { buyer: contract_address_const::<0>(), seller: contract_address_const::<0>(), token: contract_address_const::<0>(), amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 0_u256 }
//         )),
//     ]);
// }

// #[test]
// #[should_panic(expected: 'invalid swap status')]
// fn test_withdraw_invalid_status() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // Try to withdraw before credentials changed
//     contract_dispatcher.withdraw();

//     // Should not emit any contract events
//     spy.assert_not_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::SwapCreated(
//             events::SwapCreated { buyer: contract_address_const::<0>(), seller: contract_address_const::<0>(), token: contract_address_const::<0>(), amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'dummy' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: 0_u256 }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCancelled(
//             events::SwapCancelled { refund_amount: 0_u256 }
//         )),
//     ]);
// }

// #[test]
// #[should_panic(expected: 'invalid swap status')]
// fn test_withdraw_twice() {
//     let (contract_address, payment_erc20) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };
//     let payment_erc20_dispatcher = IERC20Dispatcher { contract_address: payment_erc20 };

//     let mut spy = spy_events();

//     let amount = 100 * 10 ** @DECIMALS.into();

//     // Complete the full flow
//     let zk_proof = array![1, 2, 3, 4];
//     contract_dispatcher.verify_credentials(zk_proof.span());

//     // set buyer as caller
//     start_cheat_caller_address(contract_address, BUYER);
//     start_cheat_caller_address(payment_erc20, BUYER);
    
//     // Set spend allowance for contract
//     let amount_plus_fees = 2 * amount;
//     payment_erc20_dispatcher.approve(contract_address, amount_plus_fees);
    
//     // complete deposit
//     contract_dispatcher.deposit(amount);

//     // reset caller
//     stop_cheat_caller_address(contract_address);
//     stop_cheat_caller_address(payment_erc20);

//     // complete credentials shared
//     contract_dispatcher.verify_credentials_shared(zk_proof.span());
//     contract_dispatcher.verify_credentials_changed(zk_proof.span());
    
//     start_cheat_caller_address(contract_address, SELLER);
//     // first withdrawal
//     contract_dispatcher.withdraw();
//     println!("balance of contract: {}", payment_erc20_dispatcher.balance_of(contract_address)); // debug
//     // Try to withdraw again
//     contract_dispatcher.withdraw();
//     stop_cheat_caller_address(contract_address);

//     spy.assert_emitted(@array![
//         (contract_address, NSEscrowSwapContract::Event::CredentialsVerified(
//             events::CredentialsVerified { status: 'CredentialsVerified' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::PaymentDeposited(
//             events::PaymentDeposited { amount: amount }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsShared(
//             events::CredentialsShared { status: 'CredentialsShared' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::CredentialsChanged(
//             events::CredentialsChanged { status: 'CredentialsChanged' }
//         )),
//         (contract_address, NSEscrowSwapContract::Event::SwapCompleted(
//             events::SwapCompleted { final_amount: amount }
//         ))
//     ]);
// }

// #[test]
// #[should_panic(expected: 'caller must be buyer')]
// fn test_reverse_deposit_not_buyer() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // call reverse deposit
//     contract_dispatcher.reverse_deposit();
// }

// #[test]
// #[should_panic(expected: 'balance must NOT be 0')]
// fn test_reverse_deposit_twice() {
//     let (contract_address, _) = deploy_contract();
//     let contract_dispatcher = INSEscrowSwapContractDispatcher { contract_address: contract_address };

//     let mut spy = spy_events();

//     // set buyer as caller
//     start_cheat_caller_address(contract_address, BUYER);

//     // First reverse deposit
//     contract_dispatcher.reverse_deposit();

//     // Try to reverse deposit again
//     contract_dispatcher.reverse_deposit();

//     // end call as buyer
//     stop_cheat_caller_address(contract_address);
// }


