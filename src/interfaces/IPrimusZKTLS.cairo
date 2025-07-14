use core::byte_array::ByteArray as String;
use starknet::EthAddress;

/// @dev Structure representing an attestation, which is a signed statement of fact.
#[derive(Clone, Drop, Serde)]
pub struct Attestation {
    pub recipient: EthAddress, // The recipient of the attestation.
    pub request: AttNetworkRequest, // The network request send to jsk and related to the attestation.
    pub reponseResolve: Array<
        AttNetworkResponseResolve,
    >, // The response details responsed from jdk.
    pub data: String, // Real data in the pending body provided in JSON string format.
    pub attConditions: String, // Attestation parameters in JSON string format.
    pub timestamp: u64, // The timestamp of when the attestation was created.
    pub additionParams: String, // Extra data for more inormation.
    pub attestors: Array<Attestor>, // List of attestors who signed the attestation.
    pub signatures: Array<Array<u8>> // signature from the attestor.
}

/// @dev Structure for representing a network request send to jsk and related to the attestation.
#[derive(Clone, Drop, Serde, starknet::Store)]
pub struct AttNetworkRequest {
    pub url: String, // The URL to which the request is sent.
    pub header: String, // The request headers in JSON string format.
    pub method: String, // HTTP method used in the request (e.g., GET, POST).
    pub body: String // The body of the request, typically in JSON format.
}

/// @dev Structure for resolving responses from a network request.
#[derive(Clone, Drop, Serde, starknet::Store)]
pub struct AttNetworkResponseResolve {
    pub keyName: String, // The key in the response data to be resolved.
    pub parseType: String, // The format of the response data to parse (e.g., JSON, HTML).
    pub parsePath: String // The path used to parse the response (e.g., JSONPath, XPath).
}

/// @dev Structure representing an attestor, who is responsible for signing the attestation.
#[derive(Clone, Drop, Serde, starknet::Store)]
pub struct Attestor {
    pub attestorAddr: EthAddress, // The address of the attestor.
    pub url: String // URL associated with the attestor, such as a profile or additional information.
}


/// @dev Interface of PrimusZKTLS, which defines functions for handling attestations and related
/// operations.
#[starknet::interface]
pub trait IPrimusZKTLS<TState> {
    fn setAttestor(ref self: TState, attestor: Attestor);
    fn removeAttestor(ref self: TState, attestorAddr: EthAddress);
    fn encodeAttestation(self: @TState, attestation: Attestation) -> u256;
    fn encodeRequest(self: @TState, request: AttNetworkRequest) -> u256;
    fn encodeResponse(self: @TState, reponse: Array<AttNetworkResponseResolve>) -> u256;

    ///  @dev Verifies the validity of a given attestation.
    /// This includes checking the signature of attestor,
    /// the integrity of the data, and the attestation's consistency.
    ///
    /// @param attestation The attestation data to be verified.
    /// It contains details about the recipient, request, response, and attestors.
    ///
    /// Requirements:
    /// - The attestation must have valid signatures from all listed attestors.
    /// - The data must match the provided request and response structure.
    /// - The attestation must not be expired (based on its timestamp).
    ///
    /// Emits no events.
    fn verifyAttestation(self: @TState, attestation: Attestation);
}