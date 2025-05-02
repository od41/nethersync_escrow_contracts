#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct SwapCreated {
    #[key]
    pub buyer: starknet::ContractAddress,
    #[key]
    pub seller: starknet::ContractAddress,
    pub token: starknet::ContractAddress,
    pub amount: u256,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct CredentialsVerified {
    pub status: felt252,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct CredentialsVerificationFailed {
    pub status: felt252,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct PaymentDeposited {
    pub amount: u256,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct CredentialsShared {
    pub status: felt252,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct CredentialsChanged {
    pub status: felt252,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct SwapCompleted {
    pub final_amount: u256,
}

#[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
pub struct SwapCancelled {
    pub refund_amount: u256,
}
