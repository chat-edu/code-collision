module chat_edu::study_set {

    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::SmartVector;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use chat_edu::credits;

    use chat_edu::credits::Credits;

    friend chat_edu::course;
    
    // constants
    
    const JOIN_COST: u64 = 50;
    
    // error codes

    const E_ALREADY_INITIALIZED: u64 = 0;
    const E_NOT_INITIALIZED: u64 = 1;
    const E_STUDY_SET_ALREADY_EXISTS: u64 = 2;
    const E_STUDY_SET_NOT_FOUND: u64 = 3;
    
    // structs
    
    struct StudySets has key {
        mapping: SimpleMap<String, StudySet>
    }

    struct StudySet has store {
        id: String,
        owner: address,
        user_ids: SmartVector<address>,
        file_ids: vector<String>,
        credits: Coin<Credits>
    }
    
    public(friend) fun init(course: &signer) {
        assert_study_sets_not_initialized(signer::address_of(course));
        move_to(course, StudySets {
            mapping: simple_map::new()
        });
    }
    
    public(friend) fun add_study_set(course_address: address, id: String, owner: address, file_ids: vector<String>) acquires StudySets {
        assert_study_sets_initialized(course_address);
        assert_study_set_doesnt_exist(course_address, id);
        let study_sets = borrow_global_mut<StudySets>(course_address);
        let user_ids = smart_vector::new<address>();
        smart_vector::push_back(&mut user_ids, owner);
        simple_map::add(&mut study_sets.mapping, id, StudySet {
            id,
            owner,
            user_ids,
            file_ids,
            credits: coin::zero()
        });
    }
    
    public entry fun join_study_set(account: &signer, course_address: address, id: String) acquires StudySets {
        assert_study_sets_initialized(course_address);
        assert_study_set_exists(course_address, id);
        let fee = coin::withdraw<Credits>(account, JOIN_COST);
        credits::burn(coin::extract(&mut fee, JOIN_COST / 2));
        add_credits(course_address, id, fee);
        let study_sets = borrow_global_mut<StudySets>(course_address);
        let study_set = simple_map::borrow_mut(&mut study_sets.mapping, &id);
        smart_vector::push_back(&mut study_set.user_ids, signer::address_of(account));
    }
    
    public(friend) fun add_credits(course_address: address, id: String, credits: Coin<Credits>) acquires StudySets {
        assert_study_sets_initialized(course_address);
        assert_study_set_exists(course_address, id);
        let study_sets = borrow_global_mut<StudySets>(course_address);
        let study_set = simple_map::borrow_mut(&mut study_sets.mapping, &id);
        coin::merge(&mut study_set.credits, credits);
    }
    
    public(friend) fun withdraw_credits(course_address: address, id: String): Coin<Credits> acquires StudySets {
        assert_study_sets_initialized(course_address);
        assert_study_set_exists(course_address, id);
        let study_sets = borrow_global_mut<StudySets>(course_address);
        let study_set = simple_map::borrow_mut(&mut study_sets.mapping, &id);
        coin::extract_all(&mut study_set.credits)
    }
    
    public(friend) fun withdraw_all_credits(user_address: address, course_address: address): Coin<Credits> acquires StudySets {
        assert_study_sets_initialized(course_address);
        let study_sets = borrow_global_mut<StudySets>(course_address);
        let total_credits = coin::zero();
        vector::for_each(simple_map::keys(&study_sets.mapping), |study_set_id| {
            let study_set = simple_map::borrow_mut(&mut study_sets.mapping, &study_set_id);
            if(study_set.owner == user_address) {
                coin::merge(&mut total_credits, coin::extract_all(&mut study_set.credits));
            }
        });
        total_credits
    }
    
    // getters
    
    #[view]
    public fun get_user_file_credits(course_address: address, user_address: address): u64 acquires StudySets {
        assert_study_sets_initialized(course_address);
        let study_sets = borrow_global<StudySets>(course_address);
        let total_credits = 0;
        vector::for_each(simple_map::keys(&study_sets.mapping), |study_set_id| {
            let study_set = simple_map::borrow(&study_sets.mapping, &study_set_id);
            if (study_set.owner == user_address) {
                total_credits = total_credits + coin::value(&study_set.credits);
            }
        });
        total_credits
    }
    
    #[view]
    public fun get_study_set_credits(course_address: address, id: String): u64 acquires StudySets {
        assert_study_sets_initialized(course_address);
        assert_study_set_exists(course_address, id);
        let study_sets = borrow_global<StudySets>(course_address);
        let study_set = simple_map::borrow(&study_sets.mapping, &id);
        coin::value(&study_set.credits)
    }   
    
    // asserts
    
    fun assert_study_sets_not_initialized(course_address: address) {
        assert!(!exists<StudySets>(course_address), E_ALREADY_INITIALIZED);
    }
    
    fun assert_study_sets_initialized(course_address: address) {
        assert!(exists<StudySets>(course_address), E_NOT_INITIALIZED);
    }

    fun assert_study_set_doesnt_exist(course_address: address, id: String) acquires StudySets {
        let study_sets = borrow_global<StudySets>(course_address);
        assert!(!simple_map::contains_key(&study_sets.mapping, &id), E_STUDY_SET_ALREADY_EXISTS);
    }
    
    fun assert_study_set_exists(course_address: address, id: String) acquires StudySets {
        let study_sets = borrow_global<StudySets>(course_address);
        assert!(simple_map::contains_key(&study_sets.mapping, &id), E_STUDY_SET_NOT_FOUND);
    }
}