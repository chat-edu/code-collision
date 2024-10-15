module chat_edu::file {

    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    
    use chat_edu::credits::Credits;

    friend chat_edu::course;
    
    // constants
    
    const E_ALREADY_INITIALIZED: u64 = 0;
    const E_NOT_INITIALIZED: u64 = 1;
    const E_FILE_ALREADY_EXISTS: u64 = 2;
    const E_FILE_NOT_FOUND: u64 = 3;
    
    // error codes
    
    // structs
    
    struct Files has key {
        mapping: SimpleMap<String, File>
    }

    struct File has store {
        id: String,
        owner: address,
        credits: Coin<Credits>
    }
    
    public(friend) fun init(course: &signer) {
        assert_files_not_initialized(signer::address_of(course));
        move_to(course, Files {
            mapping: simple_map::new()
        });
    }
    
    public(friend) fun add_file(course_address: address, id: String, owner: address) acquires Files {
        assert_files_initialized(course_address);
        assert_file_doesnt_exist(course_address, id);
        let files = borrow_global_mut<Files>(course_address);
        simple_map::add(&mut files.mapping, id, File {
            id,
            owner,
            credits: coin::zero()
        });
    }
    
    public(friend) fun add_credits(course_address: address, id: String, credits: Coin<Credits>) acquires Files {
        assert_files_initialized(course_address);
        assert_file_exists(course_address, id);
        let files = borrow_global_mut<Files>(course_address);
        let file = simple_map::borrow_mut(&mut files.mapping, &id);
        coin::merge(&mut file.credits, credits);
    }
    
    public(friend) fun withdraw_credits(course_address: address, id: String): Coin<Credits> acquires Files {
        assert_files_initialized(course_address);
        assert_file_exists(course_address, id);
        let files = borrow_global_mut<Files>(course_address);
        let file = simple_map::borrow_mut(&mut files.mapping, &id);
        coin::extract_all(&mut file.credits)
    }

    public(friend) fun withdraw_all_credits(user_address: address, course_address: address): Coin<Credits> acquires Files {
        assert_files_initialized(course_address);
        let files = borrow_global_mut<Files>(course_address);
        let total_credits = coin::zero();
        vector::for_each(simple_map::keys(&files.mapping), |file_id| {
            let file = simple_map::borrow_mut(&mut files.mapping, &file_id);
            if(file.owner == user_address) {
                coin::merge(&mut total_credits, coin::extract_all(&mut file.credits));
            }
        });
        total_credits
    }
    
    // getters
    
    #[view]
    public fun get_user_file_credits(course_address: address, user_address: address): u64 acquires Files {
        assert_files_initialized(course_address);
        let files = borrow_global<Files>(course_address);
        let total_credits = 0;
        vector::for_each(simple_map::keys(&files.mapping), |fileId| {
            let file = simple_map::borrow(&files.mapping, &fileId);
            if (file.owner == user_address) {
                total_credits = total_credits + coin::value(&file.credits);
            }
        });
        total_credits
    }

    #[view]
    public fun get_file_credits(course_address: address, id: String): u64 acquires Files {
        assert_files_initialized(course_address);
        assert_file_exists(course_address, id);
        let files = borrow_global<Files>(course_address);
        let file = simple_map::borrow(&files.mapping, &id);
        coin::value(&file.credits)
    }

    // asserts
    
    fun assert_files_not_initialized(course_address: address) {
        assert!(!exists<Files>(course_address), E_ALREADY_INITIALIZED);
    }
    
    fun assert_files_initialized(course_address: address) {
        assert!(exists<Files>(course_address), E_NOT_INITIALIZED);
    }

    fun assert_file_doesnt_exist(course_address: address, id: String) acquires Files {
        let files = borrow_global<Files>(course_address);
        assert!(!simple_map::contains_key(&files.mapping, &id), E_FILE_ALREADY_EXISTS);
    }
    
    fun assert_file_exists(course_address: address, id: String) acquires Files {
        let files = borrow_global<Files>(course_address);
        assert!(simple_map::contains_key(&files.mapping, &id), E_FILE_NOT_FOUND);
    }
    
}
