module initia_std::vip_vault {
    use std::error;
    use std::string;
    use std::signer;
    use std::option;

    use initia_std::object::{Self, Object, ExtendRef};
    use initia_std::fungible_asset::{Metadata, FungibleAsset};
    use initia_std::primary_fungible_store;
    use initia_std::coin;
    use initia_std::fungible_asset;
    use initia_std::vip_reward;

    friend initia_std::vip;

    //
    // Errors
    //
    
    const EVAULT_ALREADY_EXISTS: u64 = 1;
    const EINVALID_AMOUNT: u64 = 2;
    const EINVALID_STAGE: u64 = 3;
    const EUNAUTHORIZED: u64 = 4;
    const EINVALID_REWARD_PER_STAGE: u64 = 5;

    //
    // Constants
    //

    const VAULT_PREFIX: u8  = 0xf1;
    const REWARD_SYMBOL: vector<u8> = b"uinit";
    const DEFAULT_REWARD_PER_STAGE: u64 = 100_000_000_000;

    //
    // Resources
    //

    struct ModuleStore has key {
        extend_ref: ExtendRef,
        claimable_stage: u64,
        reward_per_stage: u64,
        vault_store_addr: address,
    }

    //
    // Implementations
    //

    fun init_module(chain: &signer) {
        let seed = generate_vault_store_seed();
        let vault_store_addr = object::create_object_address(signer::address_of(chain), seed);
        
        let constructor_ref = object::create_named_object(chain, seed, false);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        
        move_to(chain, ModuleStore {
            extend_ref,
            claimable_stage: 1,
            reward_per_stage: DEFAULT_REWARD_PER_STAGE,
            vault_store_addr
        });
    }

    fun check_chain_permission(chain: &signer) {
        assert!(signer::address_of(chain) == @initia_std, error::permission_denied(EUNAUTHORIZED));
    }

    fun generate_vault_store_seed(): vector<u8> {
        let seed = vector[VAULT_PREFIX];
        return seed
    }

    //
    // Friend Functions
    //
    
    public (friend) fun get_vault_store_address(): address acquires ModuleStore{
        let module_store = borrow_global<ModuleStore>(@initia_std);
        module_store.vault_store_addr
    }
    
    public (friend) fun claim(
        stage: u64,
    ): FungibleAsset acquires ModuleStore {
        let module_store = borrow_global_mut<ModuleStore>(@initia_std);
        assert!(stage == module_store.claimable_stage, error::invalid_argument(EINVALID_STAGE));
        
        module_store.claimable_stage = stage + 1;
        let vault_signer = object::generate_signer_for_extending(&module_store.extend_ref);
        let vault_store = primary_fungible_store::ensure_primary_store_exists(module_store.vault_store_addr, vip_reward::reward_metadata());
        fungible_asset::withdraw(&vault_signer, vault_store, module_store.reward_per_stage)
    }
    
    //
    // Entry Functions
    //

    public entry fun deposit(
        funder: &signer,
        amount: u64
    ) acquires ModuleStore {
        let vault_store_addr = get_vault_store_address();
        assert!(amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        primary_fungible_store::transfer(funder, vip_reward::reward_metadata(), vault_store_addr, amount);
    }

    public entry fun update_reward_per_stage(
        chain: &signer,
        reward_per_stage: u64
    ) acquires ModuleStore {
        check_chain_permission(chain);
        
        let vault_store = borrow_global_mut<ModuleStore>(@initia_std);
        assert!(reward_per_stage > 0, error::invalid_argument(EINVALID_REWARD_PER_STAGE));
        vault_store.reward_per_stage = reward_per_stage;
    }

    //
    // View Functions
    //

    #[view]
    public fun balance(): u64 acquires ModuleStore  {
        let vault_store_addr = get_vault_store_address();
        primary_fungible_store::balance(vault_store_addr, vip_reward::reward_metadata())
    }

    #[view]
    public fun reward_per_stage(): u64 acquires ModuleStore {
        let vault_store_addr = get_vault_store_address();
        primary_fungible_store::balance(vault_store_addr, vip_reward::reward_metadata())
    }


    //
    // Tests
    //

    #[test_only]
    public fun init_module_for_test(chain: &signer){
        init_module(chain);
    }

    #[test_only]
    fun initialize_coin(
        account: &signer,
        symbol: string::String,
    ): (coin::BurnCapability, coin::FreezeCapability, coin::MintCapability, Object<Metadata>) {
        let (mint_cap, burn_cap, freeze_cap) = coin::initialize(
            account,
            option::none(),
            string::utf8(b""),
            symbol,
            6,
            string::utf8(b""),
            string::utf8(b""),
        );
        let metadata = coin::metadata(signer::address_of(account), symbol);

        (burn_cap, freeze_cap, mint_cap, metadata)
    }

    
}