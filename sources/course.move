module chat_edu::course {

    use std::signer;
    use std::string::{String};
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::smart_vector::{Self, SmartVector};
    
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::object;
    use chat_edu::video;
    use chat_edu::credits::Credits;

    use chat_edu::credits;
    use chat_edu::file;
    use chat_edu::study_set;

    // structs
    
    struct Courses has key {
        mapping: SimpleMap<String, address>
    }

    
    
    // error codes
    
    const E_NOT_ADMIN: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_COURSE_ALREADY_CREATED: u64 = 3;
    const E_COURSE_NOT_FOUND: u64 = 4;
    const E_ALREADY_JOINED: u64 = 5;
    const E_NOT_JOINED: u64 = 6;
    
    // constants
    
    const FILE_COST: u64 = 100;
    const STUDY_SET_FILE_COST: u64 = 50;
    const VIDEO_COST: u64 = 50;
    const CHAT_COST: u64 = 4;
    
    public entry fun init(chat_edu: &signer) {
        assert_is_admin(chat_edu);
        assert_module_not_initialized();
        move_to(chat_edu, Courses { 
            mapping: simple_map::new() 
        });
    }

    struct Course has key {
        id: String,
        owner: address,
        users: SmartVector<address>,
        credits: Coin<Credits>
    }
    
    public entry fun create_course(account: &signer, id: String) acquires Courses, Course {
        assert_module_initialized();
        let courses = borrow_global_mut<Courses>(@chat_edu);
        assert_course_not_created(courses, &id);
        let owner = signer::address_of(account);
        let constructor_ref = object::create_object(owner);
        
        let course_signer = object::generate_signer(&constructor_ref);
        
        move_to(&course_signer, Course {
            id,
            owner,
            users: smart_vector::new(),
            credits: coin::zero()
        });
        simple_map::add(&mut courses.mapping, id, object::address_from_constructor_ref(&constructor_ref));
        
        // join course for user
        join_course(account, id);
        
        // initializes the files struct
        file::init(&course_signer);
        
        // initializes the study sets struct
        study_set::init(&course_signer);
        
        video::init(&course_signer);
    }
    
    public entry fun join_course(account: &signer, course_id: String) acquires Courses, Course {
        assert_module_initialized();
        let courses = borrow_global_mut<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let course = borrow_global_mut<Course>(*course_address);
        let user = signer::address_of(account);
        assert!(!smart_vector::contains(&course.users, &user), E_ALREADY_JOINED);
        smart_vector::push_back(&mut course.users, user);
    }
    
    public entry fun leave_course(account: &signer, course_id: String) acquires Courses, Course {
        assert_module_initialized();
        let courses = borrow_global_mut<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let course = borrow_global_mut<Course>(*course_address);
        let user = signer::address_of(account);
        let (exists, index) = smart_vector::index_of(&course.users, &user);
        assert!(exists, E_NOT_JOINED);
        smart_vector::remove(&mut course.users, index);
    }
    
    public entry fun add_file(account: &signer, course_id: String, file_id: String) acquires Courses {
        assert_module_initialized();
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        credits::burn(coin::withdraw(account, FILE_COST));
        file::add_file(*course_address, file_id, signer::address_of(account));
    }
    
    public entry fun create_study_set(
        account: &signer, 
        course_id: String, 
        study_set_id: String, 
        file_ids: vector<String>
    ) 
    acquires Courses {
        assert_module_initialized();
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        vector::for_each(file_ids, |file_id| {
            let credits = coin::withdraw<Credits>(account, STUDY_SET_FILE_COST);
            credits::burn(coin::extract<Credits>(&mut credits, STUDY_SET_FILE_COST / 2));
            file::add_credits(*course_address, file_id, credits);
        });
        study_set::add_study_set(*course_address, study_set_id, signer::address_of(account), file_ids);
    }

    public entry fun create_video(
        account: &signer,
        course_id: String,
        video_id: String,
        file_id: String
    ) 
    acquires Courses {
        assert_module_initialized();
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let credits = coin::withdraw<Credits>(account, VIDEO_COST);
        credits::burn(coin::extract<Credits>(&mut credits, VIDEO_COST / 2));
        file::add_credits(*course_address, file_id, credits);
        video::add_video(*course_address, video_id, signer::address_of(account), file_id);
    }
    
    public entry fun prompt_chatbot(account: &signer, course_id: String) acquires Courses, Course {
        assert_module_initialized();
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let course = borrow_global_mut<Course>(*course_address);
        assert!(smart_vector::contains(&course.users, &signer::address_of(account)), E_NOT_JOINED);
        let credits = coin::withdraw<Credits>(account, CHAT_COST);
        credits::burn(coin::extract<Credits>(&mut credits, CHAT_COST / 2));
        coin::merge(&mut course.credits, credits);
    }
    
    public entry fun claim_credits(account: &signer, course_id: String) acquires Courses, Course {
        assert_module_initialized();
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        
        let study_set_credits = study_set::withdraw_all_credits(signer::address_of(account), *course_address);
        coin::deposit(signer::address_of(account), study_set_credits);
        
        let file_credits = file::withdraw_all_credits(signer::address_of(account), *course_address);
        coin::deposit(signer::address_of(account), file_credits);
        
        let video_credits = video::withdraw_all_credits(signer::address_of(account), *course_address);
        coin::deposit(signer::address_of(account), video_credits);
        
        let course = borrow_global_mut<Course>(*course_address);
        let credits = coin::extract_all(&mut course.credits);
        coin::deposit(signer::address_of(account), credits);
    }
    
    // getter functions
    
    #[view]
    public fun get_course_address(course_id: String): address acquires Courses {
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        *simple_map::borrow(&courses.mapping, &course_id)
    }
    
    #[view]
    public fun get_course_credits(course_id: String): u64 acquires Courses, Course {
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let course = borrow_global<Course>(*course_address);
        coin::value(&course.credits)
    }
    
    #[view]
    public fun get_user_in_course(course_id: String, user_address: address): bool acquires Courses, Course {
        let courses = borrow_global<Courses>(@chat_edu);
        assert_course_created(courses, &course_id);
        let course_address = simple_map::borrow(&courses.mapping, &course_id);
        let course = borrow_global<Course>(*course_address);
        smart_vector::contains(&course.users, &user_address)
    }
    
    // assert statements
    
    fun assert_is_admin(chat_edu: &signer) {
        assert!(signer::address_of(chat_edu) == @chat_edu, E_NOT_ADMIN);
    }
    
    fun assert_module_not_initialized() {
        assert!(!exists<Courses>(@chat_edu), E_ALREADY_INITIALIZED);
    }
    
    fun assert_module_initialized() {
        assert!(exists<Courses>(@chat_edu), E_NOT_INITIALIZED);
    }
    
    fun assert_course_not_created(courses: &Courses, id: &String) {
        assert!(!simple_map::contains_key(&courses.mapping, id), E_COURSE_ALREADY_CREATED);
    }
    
    fun assert_course_created(courses: &Courses, id: &String) {
        assert!(simple_map::contains_key(&courses.mapping, id), E_COURSE_NOT_FOUND);
    }
}
