module chat_edu::credits {

    use std::signer;
    use std::string;
    use aptos_framework::coin;
    use aptos_framework::coin::{MintCapability, BurnCapability, FreezeCapability, Coin};
    
    // structs

    struct Credits {}
    
    struct Capabilities has key {
        mint_cap: MintCapability<Credits>,
        burn_cap: BurnCapability<Credits>,
        freeze_cap: FreezeCapability<Credits>
    }
    
    public entry fun init(admin: &signer) {
        assert!(signer::address_of(admin) == @chat_edu, 0);
        let (
            burn_cap, 
            freeze_cap, 
            mint_cap
        ) = coin::initialize<Credits>(
            admin,
            string::utf8(b"Chat EDU Credits"),
            string::utf8(b"CEDU"),
            0,
            true
        );
        move_to(admin, Capabilities {
            mint_cap,
            burn_cap,
            freeze_cap
        });
    }
    
    public entry fun faucet(account: &signer) acquires Capabilities {
        let account_address = signer::address_of(account);
        if(!coin::is_account_registered<Credits>(signer::address_of(account))) {
            coin::register<Credits>(account);
        };
        coin::deposit(account_address, mint(1000));
    }
    
    public fun mint(amount: u64): Coin<Credits> acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(@chat_edu);
        coin::mint(amount, &capabilities.mint_cap)
    }
    
    public fun burn(coins: Coin<Credits>) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(@chat_edu);
        coin::burn(coins, &capabilities.burn_cap)
    }
    
    
}
