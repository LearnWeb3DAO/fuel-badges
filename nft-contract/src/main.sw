contract;

mod errors;

use standards::{src20::SRC20, src3::SRC3, src5::{SRC5, State}, src7::{Metadata, SRC7},};
use sway_libs::{
    asset::{
        base::{
            _name,
            _set_name,
            _set_symbol,
            _symbol,
            _total_assets,
            _total_supply,
            SetAssetAttributes,
        },
        metadata::*,
        supply::{
            _burn,
            _mint,
        },
    },
    ownership::{
        _owner,
        initialize_ownership,
        only_owner,
    },
    pausable::{
        _is_paused,
        _pause,
        _unpause,
        Pausable,
        require_not_paused,
    },
};
use std::{
    call_frames::get_contract_id_from_call_frame,
    hash::Hash,
    registers::frame_ptr,
    storage::storage_string::*,
    string::String,
};
use errors::*;

storage {
    total_assets: u64 = 0,
    total_supply: StorageMap<AssetId, u64> = StorageMap {},
    name: StorageMap<AssetId, StorageString> = StorageMap {},
    metadata: StorageMetadata = StorageMetadata {},
}

abi LW3Badges {
    #[storage(read, write)]
    fn constructor(owner: Identity);
}

impl LW3Badges for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        initialize_ownership(owner);
    }
}

// Native Asset Standard
impl SRC20 for Contract {
    /// Returns the total number of individual NFTs for this contract.
    #[storage(read)]
    fn total_assets() -> u64 {
        _total_assets(storage.total_assets)
    }

    /// Returns the total supply of coins for an asset.
    ///
    /// # Additional Information
    ///
    /// This must always be at most 1 for NFTs.
    #[storage(read)]
    fn total_supply(asset: AssetId) -> Option<u64> {
        _total_supply(storage.total_supply, asset)
    }

    /// Returns the name of the asset, such as “Ether”.
    #[storage(read)]
    fn name(asset: AssetId) -> Option<String> {
        _name(storage.name, asset)
    }
    /// Returns the symbol of the asset, such as “ETH”.
    #[storage(read)]
    fn symbol(asset: AssetId) -> Option<String> {
        Some(String::from_ascii_str("LW3-BADGES"))
    }
    /// Returns the number of decimals the asset uses.
    ///
    /// # Additional Information
    ///
    /// The standardized decimals for NFTs is 0u8.
    #[storage(read)]
    fn decimals(_asset: AssetId) -> Option<u8> {
        Some(0u8)
    }
}

// Minting and Burning Standard
impl SRC3 for Contract {
    /// Mints new assets using the `sub_id` sub-identifier.
    ///
    /// # Additional Information
    ///
    /// This conforms to the SRC-20 NFT portion of the standard for a maximum
    /// mint amount of 1 coin per asset.
    ///
    /// # Arguments
    ///
    /// * `recipient`: [Identity] - The user to which the newly minted assets are transferred to.
    /// * `sub_id`: [SubId] - The sub-identifier of the newly minted asset.
    /// * `amount`: [u64] - The quantity of coins to mint.
    ///
    /// # Reverts
    ///
    /// * When the caller is not the contract owner.
    /// * When amount is greater than one.
    /// * When the asset has already been minted.
    #[storage(read, write)]
    fn mint(recipient: Identity, sub_id: SubId, amount: u64) {
        // Owner only minting
        only_owner();

        // Checks to ensure this is a valid mint.
        let asset = AssetId::new(get_contract_id_from_call_frame(frame_ptr()), sub_id);
        require(amount == 1, MintError::CannotMintMoreThanOneNFTWithSubId);
        require(
            storage
                .total_supply
                .get(asset)
                .try_read()
                .is_none(),
            MintError::NFTAlreadyMinted,
        );

        // Mint the NFT
        let _ = _mint(
            storage
                .total_assets,
            storage
                .total_supply,
            recipient,
            sub_id,
            amount,
        );
    }

    /// Burns assets sent with the given `sub_id`.
    ///
    /// # Additional Information
    ///
    /// NOTE: The sha-256 hash of `(ContractId, SubId)` must match the `AssetId` where `ContractId` is the id of
    /// the implementing contract and `SubId` is the given `sub_id` argument.
    #[payable]
    #[storage(read, write)]
    fn burn(sub_id: SubId, amount: u64) {
        only_owner();
        _burn(storage.total_supply, sub_id, amount);
    }
}

// Retrieving metadata standard
impl SRC7 for Contract {
    /// Returns metadata for the corresponding `asset` and `key`.
    ///
    /// # Arguments
    ///
    /// * `asset`: [AssetId] - The asset of which to query the metadata.
    /// * `key`: [String] - The key to the specific metadata.
    ///
    /// # Returns
    ///
    /// * [Option<Metadata>] - `Some` metadata that corresponds to the `key` or `None`.
    #[storage(read)]
    fn metadata(asset: AssetId, key: String) -> Option<Metadata> {
        storage.metadata.get(asset, key)
    }
}

impl SRC5 for Contract {
    /// Returns the owner.
    ///
    /// # Return Values
    ///
    /// * [State] - Represents the state of ownership for this contract.
    #[storage(read)]
    fn owner() -> State {
        _owner()
    }
}

impl SetAssetAttributes for Contract {
    /// Sets the name of an asset.
    ///
    /// # Arguments
    ///
    /// * `asset`: [AssetId] - The asset of which to set the name.
    /// * `name`: [String] - The name of the asset.
    ///
    /// # Reverts
    ///
    /// * When the caller is not the owner of the contract.
    /// * When the name has already been set for an asset.
    ///
    /// Realistically, this function should never be called.
    #[storage(write)]
    fn set_name(asset: AssetId, name: String) {
        require(false, UnexpectedError::NotAllowed);
    }

    /// Sets the symbol of an asset.
    ///
    /// # Arguments
    ///
    /// * `asset`: [AssetId] - The asset of which to set the symbol.
    /// * `symbol`: [String] - The symbol of the asset.
    ///
    /// # Reverts
    ///
    /// * When the caller is not the owner of the contract.
    /// * When the symbol has already been set for an asset.
    ///
    /// Realistically, this function should never be called.
    #[storage(write)]
    fn set_symbol(asset: AssetId, symbol: String) {
        require(false, UnexpectedError::NotAllowed);
    }

    /// This function should never be called.
    ///
    /// # Additional Information
    ///
    /// NFT decimals are always `0u8` and thus must not be set.
    /// This function is an artifact of the SetAssetAttributes ABI definition,
    /// but does not have a use in this contract as the decimal value is hardcoded.
    ///
    /// # Reverts
    ///
    /// * When the function is called.
    #[storage(write)]
    fn set_decimals(_asset: AssetId, _decimals: u8) {
        require(false, SetError::ValueAlreadySet);
    }
}

impl SetAssetMetadata for Contract {
    /// Stores metadata for a specific asset and key pair.
    ///
    /// # Arguments
    ///
    /// * `asset`: [AssetId] - The asset for the metadata to be stored.
    /// * `key`: [String] - The key for the metadata to be stored.
    /// * `metadata`: [Metadata] - The metadata to be stored.
    ///
    /// # Reverts
    ///
    /// * When the metadata has already been set for an asset.
    #[storage(read, write)]
    fn set_metadata(asset: AssetId, key: String, metadata: Metadata) {
        require(
            storage
                .metadata
                .get(asset, key)
                .is_none(),
            SetError::ValueAlreadySet,
        );
        _set_metadata(storage.metadata, asset, key, metadata);
    }
}
