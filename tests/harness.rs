use fuels::{
    accounts::predicate::Predicate,
    core::Configurables,
    prelude::*,
    tx::Bytes32,
    types::{Bits256, ContractId, Identity},
};
use sha2::{Digest, Sha256};
use std::str::FromStr;

// Load abi from json
abigen!(
    Contract(
        name = "LW3Badges",
        abi = "nft-contract/out/debug/fuel-badges-abi.json"
    ),
    Predicate(
        name = "SoulboundPredicate",
        abi = "soulbound-predicate/out/debug/soulbound-predicate-abi.json"
    )
);

const PREDICATE_BINARY: &str = "./soulbound-predicate/out/debug/soulbound-predicate.bin";
const CONTRACT_BINARY: &str = "./nft-contract/out/debug/fuel-badges.bin";

async fn get_contract_instance() -> (LW3Badges<WalletUnlocked>, ContractId, Vec<WalletUnlocked>) {
    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(2),             /* Two wallets */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        None,
        None,
    )
    .await
    .unwrap();
    let wallet = wallets.pop().unwrap();

    let id = Contract::load_from(CONTRACT_BINARY, LoadConfiguration::default())
        .unwrap()
        .deploy(&wallet, TxPolicies::default())
        .await
        .unwrap();

    let instance = LW3Badges::new(id.clone(), wallet);

    // Call the constructor
    let deployer_identity = Identity::Address(instance.account().address().into());
    instance
        .methods()
        .constructor(deployer_identity)
        .call()
        .await
        .unwrap();

    (instance, id.into(), wallets)
}

async fn calculate_predicate_address(addr: Address) -> Address {
    let configurables = SoulboundPredicateConfigurables::new().with_ADDRESS(addr);
    let predicate = Predicate::load_from(PREDICATE_BINARY)
        .unwrap()
        .with_configurables(configurables);

    predicate.address().into()
}

fn get_asset_id(sub_id: Bytes32, contract: ContractId) -> AssetId {
    let mut hasher = Sha256::new();
    hasher.update(*contract);
    hasher.update(*sub_id);
    AssetId::new(*Bytes32::from(<[u8; 32]>::from(hasher.finalize())))
}

#[tokio::test]
async fn test_sanity() {
    let (contract, contract_id, mut wallets) = get_contract_instance().await;

    let deployer_wallet = contract.account();
    let deployer_identity = Identity::Address(deployer_wallet.address().into());
    let recipient_wallet = wallets.pop().unwrap();
    let recipient_predicate = calculate_predicate_address(recipient_wallet.address().into()).await;
    let recipient_predicate_identity = Identity::Address(recipient_predicate.into());
    // Sanity Checks
    assert_eq!(contract_id, contract.contract_id().into());
    assert_eq!(
        contract
            .methods()
            .total_assets()
            .simulate()
            .await
            .unwrap()
            .value,
        0
    );
    assert_eq!(
        contract.methods().owner().simulate().await.unwrap().value,
        State::Initialized(deployer_identity)
    );

    let sub_id_1 = Bytes32::from([1u8; 32]);
    let sub_id_2 = Bytes32::from([2u8; 32]);
    let sub_id_3 = Bytes32::from([3u8; 32]);
    let asset1 = get_asset_id(sub_id_1, contract_id);
    let asset2 = get_asset_id(sub_id_2, contract_id);
    let asset3 = get_asset_id(sub_id_3, contract_id);

    contract
        .with_account(deployer_wallet)
        .unwrap()
        .methods()
        .mint(recipient_predicate_identity, Bits256(*sub_id_1), 1)
        .call()
        .await
        .unwrap();

    let total_assets = contract
        .methods()
        .total_assets()
        .simulate()
        .await
        .unwrap()
        .value;
    assert_eq!(total_assets, 1);

    let total_supply_of_asset = contract
        .methods()
        .total_supply(asset1)
        .simulate()
        .await
        .unwrap()
        .value;
    assert_eq!(total_supply_of_asset, Some(1));
}
